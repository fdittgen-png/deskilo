// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

import '../../../features/money/domain/bank/bank_file.dart';
import '../../../features/money/domain/bank/bank_match.dart';
import '../../../features/money/domain/bank/bank_records.dart';
import '../../../features/money/domain/bank/bank_statement.dart';
import '../../text/collation.dart';
import 'bank_reconciliation_fixture.dart';
import 'bank_statement_repository.dart';
import 'money_repository.dart';

/// The demo's account at its bank (a valid Swiss IBAN of the demo).
const _demoAccount = 'CH9300762011623852957';

/// The demo space's last statement: two open invoices paid with the
/// references printed on them (the QR reference and the RF creditor
/// reference), one transfer whose payer gave neither, and the bank's
/// monthly fee going out.
FakeBankStatementRepository seedDemoBankStatements(
  FakeMoneyRepository money,
  DateTime today,
) {
  final repo = FakeBankStatementRepository(money: money, today: today);
  final open = openInvoices(
    money.invoices.where((i) => i.workspaceId == 'ws-1'),
    money.invoiceMatchesStore,
  )..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
  final day = DateTime.utc(today.year, today.month, today.day);
  final currency = open.isEmpty ? 'EUR' : open.first.currency;
  BankLine line(
    int n,
    int cents, {
    String reference = '',
    String text = '',
    String payer = '',
  }) => BankLine(
    position: n,
    bookingDate: day,
    valueDate: day,
    amountCents: cents,
    currency: currency,
    transactionId: 'DEMO-$n',
    counterpartyName: payer,
    reference: reference,
    remittance: text,
  );
  // A QR reference keeps only the number's digits, so two numbers that
  // differ by their letters share one; the demo pays an invoice whose
  // reference is its own.
  String? qrr(OpenInvoice i) => i.frozenQrr ?? qrrReferenceOf(i.number);
  final byQr = open
      .where(
        (i) =>
            qrr(i) != null && open.where((o) => qrr(o) == qrr(i)).length == 1,
      )
      .firstOrNull;
  final byRf = open
      .where((i) => i != byQr && scorReferenceOf(i.number) != null)
      .firstOrNull;
  final lines = <BankLine>[
    if (byQr != null)
      line(1, byQr.dueCents, reference: qrr(byQr)!, payer: byQr.memberName),
    if (byRf != null)
      line(
        2,
        byRf.dueCents,
        reference: scorReferenceOf(byRf.number)!,
        payer: byRf.memberName,
      ),
    line(3, 4200, text: 'Thanks for the coffee corner', payer: 'Studio Lumen'),
    line(4, -1500, text: 'Reimbursement REIMB-1', payer: 'Studio Lumen'),
  ];
  // A reimbursement reported as made, which the movement out reconciles.
  repo.reportedPayments.add((
    payment: OutgoingCandidate(
      id: 'demo-outgoing-1',
      amountCents: 1500,
      paidOn: day,
      reference: 'REIMB-1',
      payee: 'Studio Lumen',
    ),
    currency: currency,
  ));
  final statement = BankStatement(
    format: BankFileFormat.camt054,
    account: _demoAccount,
    currency: currency,
    statementId: 'DEMO-NTFCTN-1',
    lines: lines,
  );
  // The seed is the import of one file, by the same rules as any other.
  repo.seedStatement(
    statement,
    sha256.convert(utf8.encode('demo-statement')).toString(),
    'demo-camt054.xml',
  );
  // Synthetic report source; these balances are fixture facts.
  final reportBytes = utf8.encode(demoReconciliationStatementXml);
  final reportDigest = sha256.convert(reportBytes).toString();
  final reportStatement = parseBankFile(
    reportBytes,
    format: BankFileFormat.camt053,
    limits: const BankFileLimits(maxBytes: 100000, maxLines: 100),
  );
  repo.originals['ws-1/$reportDigest'] = Uint8List.fromList(reportBytes);
  repo.seedStatement(reportStatement, reportDigest, 'demo-report-camt053.xml');
  return repo;
}

// #4496 -- the Demo's bank accounts, beside its statements: the account the Demo's notification files are of (the
// IBAN they name), so its statements are imported into it; the reconciliation report's account is under a name no
// account carries, so the Demo shows a name to attach. The same rules as the server's: every name an account is known
// by is its own, and an account known by a name takes on the statements under it.

/// The one account store of a space's statements.
final _stores = Expando<FakeBankAccountRepository>('demo bank accounts');
FakeBankAccountRepository demoBankAccountsOf(FakeBankStatementRepository bank) =>
    _stores[bank] ??= FakeBankAccountRepository(bank);

class FakeBankAccountRepository implements BankAccountRepository {
  FakeBankAccountRepository(this._bank, {List<BankAccount> accounts = const []}) {
    for (final a in accounts) {
      _accounts[a.id] = a;
    }
    final of = _bank.statements.where((s) => bankAccountKey(s.account) == _demoAccount);
    if (of.isNotEmpty) {
      _accounts['demo-bank-account-1'] = BankAccount(
        id: 'demo-bank-account-1',
        name: 'Postfinance',
        iban: _demoAccount,
        currency: of.first.currency,
      );
    }
  }

  final FakeBankStatementRepository _bank;
  final _accounts = <String, BankAccount>{};
  var _next = 2;

  @override
  Future<List<BankAccount>> accounts(String workspaceId) async =>
      [..._accounts.values]
        ..sort((a, b) => a.archived == b.archived ? compareNames(a.name, b.name) : (a.archived ? 1 : -1));

  @override
  Future<({String id, int attached})> save(String workspaceId, BankAccount account) async {
    if (account.name.trim().isEmpty || account.name.trim().length > bankAccountNameWidth) {
      throw const BankAccountRefused(BankAccountRefusal.name);
    }
    final iban = bankAccountKey(account.iban);
    if (iban.isNotEmpty && !RegExp(r'^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$').hasMatch(iban)) {
      throw const BankAccountRefused(BankAccountRefusal.iban);
    }
    final id = account.id.isEmpty ? 'demo-bank-account-${_next++}' : account.id;
    final saved = BankAccount(
      id: id,
      name: account.name.trim(),
      iban: iban,
      identifiers: account.identifiers,
      aliases: account.aliases,
      currency: account.currency,
      bookAccountId: account.bookAccountId,
      archived: account.archived,
    );
    for (final other in _accounts.values) {
      if (other.id == id || other.archived) continue;
      final taken = saved.keys.intersection(other.keys);
      if (taken.isNotEmpty) throw BankAccountRefused(BankAccountRefusal.taken, name: taken.first);
    }
    final before = (await unattached(workspaceId)).fold<int>(0, (n, u) => n + u.statements);
    _accounts[id] = saved;
    final after = (await unattached(workspaceId)).fold<int>(0, (n, u) => n + u.statements);
    return (id: id, attached: before - after);
  }

  @override
  Future<bool> archive(String workspaceId, String accountId) async {
    final a = _accounts[accountId];
    if (a == null || a.archived) return false;
    _accounts[accountId] = BankAccount(
      id: a.id,
      name: a.name,
      iban: a.iban,
      identifiers: a.identifiers,
      aliases: a.aliases,
      currency: a.currency,
      bookAccountId: a.bookAccountId,
      archived: true,
    );
    return true;
  }

  @override
  Future<List<UnattachedBankName>> unattached(String workspaceId) async {
    final counts = <(String, String), int>{};
    for (final s in _bank.statements) {
      final known = _accounts.values.any((a) => !a.archived && a.currency == s.currency && a.knownBy(s.account));
      if (!known) counts.update((s.account, s.currency), (n) => n + 1, ifAbsent: () => 1);
    }
    return [for (final e in counts.entries) UnattachedBankName(name: e.key.$1, currency: e.key.$2, statements: e.value)]
      ..sort((a, b) => compareNames(a.name, b.name));
  }
}
