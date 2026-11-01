// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../features/money/domain/bank/bank_match.dart';
import '../../../features/money/domain/bank/bank_records.dart';
import '../../../features/money/domain/bank/bank_statement.dart';
import '../../../features/money/domain/ledger_entry.dart';
import '../../../features/money/domain/swiss_qr_bill.dart';
import '../../time/date_text.dart';
import 'money_repository.dart';

/// The bank statements in memory, with the server's rules the screens
/// show (import_bank_statement_v1 and the line decisions of #2380): the
/// same file imports nothing twice, a bank id already known for the
/// account is not created again, a movement without one that resembles
/// another statement's waits for a review, money in becomes one payment of
/// the invoice's member and is matched through the demo's own match, money
/// out reconciles a reported payment, and that reconciliation is undone
/// once, with a reason, giving the payment back to the candidates.
class FakeBankStatementRepository implements BankStatementRepository {
  FakeBankStatementRepository({required this.money, required this.today});

  final FakeMoneyRepository money;
  final DateTime today;

  /// The payments reported as made and not yet reconciled: what a movement
  /// out of the same amount and currency may reconcile.
  final reportedPayments = <({OutgoingCandidate payment, String currency})>[];
  final statements = <StoredBankStatement>[];
  final _lines = <String, List<StoredBankLine>>{};
  final _sources = <String, String>{};
  final _payments = <String, String>{};
  var _next = 1;

  String _id(String kind) => 'demo-$kind-${_next++}';

  static String _hash(String account, BankLine l) => sha256
      .convert(
        utf8.encode(
          [
            account,
            l.bookingDate.toIso8601String(),
            l.valueDate.toIso8601String(),
            l.amountCents,
            l.currency,
            l.reference,
            l.endToEndId,
            l.counterpartyIban,
            l.remittance,
          ].join('|'),
        ),
      )
      .toString();

  @override
  Future<List<StoredBankStatement>> fetchStatements(String workspaceId) async => [
    for (final s in statements)
      StoredBankStatement(
        id: s.id,
        format: s.format,
        account: s.account,
        currency: s.currency,
        from: s.from,
        to: s.to,
        lineCount: _lines[s.id]!.length,
        openCount: _lines[s.id]!.where((l) => l.status.isOpen).length,
        statementRef: s.statementRef,
        fileName: s.fileName,
        sourceSha256: s.sourceSha256,
        openingCents: s.openingCents,
        closingCents: s.closingCents,
      ),
  ]..sort((a, b) => b.to.compareTo(a.to));

  @override
  Future<List<StoredBankLine>> fetchLines(String statementId) async => [
    for (final l in _lines[statementId] ?? const <StoredBankLine>[])
      if (l.isMoneyIn || l.status != BankLineStatus.open) l else _withCandidates(l),
  ];

  StoredBankLine _withCandidates(StoredBankLine l) => StoredBankLine(
    id: l.id,
    position: l.position,
    bookingDate: l.bookingDate,
    valueDate: l.valueDate,
    amountCents: l.amountCents,
    currency: l.currency,
    status: l.status,
    transactionId: l.transactionId,
    counterpartyName: l.counterpartyName,
    counterpartyIban: l.counterpartyIban,
    reference: l.reference,
    endToEndId: l.endToEndId,
    remittance: l.remittance,
    outgoingCandidates: [
      for (final r in reportedPayments)
        if (r.currency == l.currency && r.payment.amountCents == -l.amountCents)
          r.payment,
    ],
  );

  /// #2380 — the originals kept, by workspace and digest.
  final originals = <String, Uint8List>{};

  /// How many times an original was stored (tests: once per file).
  int originalWrites = 0;

  @override
  Future<void> storeOriginal(
    String workspaceId, {
    required String sourceSha256,
    required List<int> bytes,
  }) async {
    originalWrites++;
    originals.putIfAbsent(
        '$workspaceId/$sourceSha256', () => Uint8List.fromList(bytes));
  }

  @override
  Future<Uint8List> fetchOriginal(
    String workspaceId,
    String sourceSha256,
  ) async {
    final bytes = originals['$workspaceId/$sourceSha256'];
    if (bytes == null) throw StateError('no original $sourceSha256');
    return bytes;
  }

  @override
  Future<BankImportResult> importStatement(
    String workspaceId, {
    required BankStatement statement,
    required String sourceSha256,
    required String fileName,
  }) async => _import(statement, sourceSha256, fileName);

  BankImportResult _import(
    BankStatement statement,
    String sourceSha256,
    String fileName,
  ) {
    final known = _sources[sourceSha256];
    if (known != null) {
      return BankImportResult(
        statementId: known,
        repeated: true,
        created: 0,
        known: statement.lines.length,
        review: 0,
      );
    }
    final id = _id('statement');
    final existing = [
      for (final s in statements)
        if (s.account == statement.account) ...?_lines[s.id],
    ];
    final ids = {
      for (final l in existing)
        if (l.transactionId.isNotEmpty) l.transactionId,
    };
    final hashes = {for (final l in existing) ?_hashes[l.id]};
    final stored = <StoredBankLine>[];
    var skipped = 0, review = 0;
    for (final l in statement.lines) {
      if (l.transactionId.isNotEmpty && !ids.add(l.transactionId)) {
        skipped++;
        continue;
      }
      final hash = _hash(statement.account, l);
      final resembles = l.transactionId.isEmpty && hashes.contains(hash);
      if (resembles) review++;
      final line = _stored(
        l,
        _id('line'),
        resembles ? BankLineStatus.review : BankLineStatus.open,
      );
      _hashes[line.id] = hash;
      stored.add(line);
    }
    _sources[sourceSha256] = id;
    _lines[id] = stored;
    statements.add(
      StoredBankStatement(
        id: id,
        format: statement.format,
        account: statement.account,
        currency: statement.currency,
        from: statement.from,
        to: statement.to,
        lineCount: stored.length,
        openCount: stored.length,
        statementRef: statement.statementId,
        fileName: fileName,
        sourceSha256: sourceSha256,
        openingCents: statement.openingCents,
        closingCents: statement.closingCents,
      ),
    );
    return BankImportResult(
      statementId: id,
      repeated: false,
      created: stored.length - review,
      known: skipped,
      review: review,
    );
  }

  final _hashes = <String, String>{};

  static StoredBankLine _stored(BankLine l, String id, BankLineStatus status) =>
      StoredBankLine(
        id: id,
        position: l.position,
        bookingDate: l.bookingDate,
        valueDate: l.valueDate,
        amountCents: l.amountCents,
        currency: l.currency,
        status: status,
        transactionId: l.transactionId,
        counterpartyName: l.counterpartyName,
        counterpartyIban: l.counterpartyIban,
        reference: l.reference,
        endToEndId: l.endToEndId,
        remittance: l.remittance,
      );

  (String, int) _find(String lineId) {
    for (final e in _lines.entries) {
      final i = e.value.indexWhere((l) => l.id == lineId);
      if (i >= 0) return (e.key, i);
    }
    throw StateError('unknown bank line');
  }

  BankLineStatus _set(
    String lineId,
    BankLineStatus status, {
    String? invoiceId,
    String? invoiceNumber,
  }) {
    final (statement, i) = _find(lineId);
    final l = _lines[statement]![i];
    _lines[statement]![i] = StoredBankLine(
      id: l.id,
      position: l.position,
      bookingDate: l.bookingDate,
      valueDate: l.valueDate,
      amountCents: l.amountCents,
      currency: l.currency,
      status: status,
      transactionId: l.transactionId,
      counterpartyName: l.counterpartyName,
      counterpartyIban: l.counterpartyIban,
      reference: l.reference,
      endToEndId: l.endToEndId,
      remittance: l.remittance,
      invoiceId: invoiceId ?? l.invoiceId,
      invoiceNumber: invoiceNumber ?? l.invoiceNumber,
    );
    return status;
  }

  StoredBankLine _line(String lineId) {
    final (statement, i) = _find(lineId);
    return _lines[statement]![i];
  }

  @override
  Future<BankLineStatus> matchLine(
    String lineId, {
    required String invoiceId,
    required String resolution,
    required String note,
  }) async {
    final line = _line(lineId);
    if (line.status == BankLineStatus.review) {
      throw StateError('review this movement first');
    }
    if (!line.isMoneyIn || line.status == BankLineStatus.duplicate) {
      throw StateError('this movement settles no invoice');
    }
    if (line.status == BankLineStatus.matched ||
        line.status == BankLineStatus.pending) {
      throw StateError('this movement already settles an invoice');
    }
    final invoice = money.invoices.firstWhere(
      (i) => i.id == invoiceId,
      orElse: () => throw StateError('unknown invoice'),
    );
    if (invoice.currency != line.currency) {
      throw StateError('the invoice is in another currency');
    }
    final payment = _payments.putIfAbsent(lineId, () {
      final id = _id('payment');
      money.ledger.add(
        LedgerEntry(
          id: id,
          memberId: invoice.memberId,
          kind: LedgerKind.credit,
          category: LedgerCategory.payment,
          amountCents: line.amountCents,
          description: line.reference.isNotEmpty ? line.reference : line.remittance,
          period: yearMonth(line.valueDate.year, line.valueDate.month),
          createdAt: today,
          occurredOn: line.valueDate,
        ),
      );
      return id;
    });
    await money.matchInvoice(
      invoiceId: invoiceId,
      paymentLedgerId: payment,
      resolution: resolution,
      note: note,
    );
    final pending = money.invoiceMatchesStore[invoiceId]?.pending ?? false;
    return _set(
      lineId,
      pending ? BankLineStatus.pending : BankLineStatus.matched,
      invoiceId: invoiceId,
      invoiceNumber: invoice.number,
    );
  }

  @override
  Future<BankLineStatus> reviewLine(
    String lineId, {
    required bool duplicate,
  }) async {
    if (_line(lineId).status != BankLineStatus.review) {
      throw StateError('this movement is not waiting for a review');
    }
    return _set(
      lineId,
      duplicate ? BankLineStatus.duplicate : BankLineStatus.open,
    );
  }

  @override
  Future<BankLineStatus> reconcileOut(
    String lineId, {
    required String outgoingPaymentId,
  }) async {
    final line = _withCandidates(_line(lineId));
    if (line.isMoneyIn || line.status != BankLineStatus.open) {
      throw StateError('only open money out reconciles a payment');
    }
    if (!line.outgoingCandidates.any((c) => c.id == outgoingPaymentId)) {
      throw StateError('unknown outgoing payment');
    }
    final i = reportedPayments.indexWhere(
      (r) => r.payment.id == outgoingPaymentId,
    );
    _reconciled[lineId] = reportedPayments.removeAt(i);
    return _set(lineId, BankLineStatus.reconciled);
  }

  /// The reported payment each reconciled movement out took.
  final _reconciled =
      <String, ({OutgoingCandidate payment, String currency})>{};

  /// The reconciliations undone, as the server records them: the line, the
  /// payment let go and why, by request id.
  final unreconciliations =
      <String, ({String lineId, String paymentId, String reason})>{};

  @override
  Future<BankLineStatus> unreconcileOut(
    String lineId, {
    required String reason,
    required String requestId,
  }) async {
    final done = unreconciliations[requestId];
    if (done != null) {
      if (done.lineId != lineId) {
        throw StateError(
          'this request id was already used for a different request',
        );
      }
      return BankLineStatus.open;
    }
    if (reason.trim().isEmpty) {
      throw StateError('state why the reconciliation is undone');
    }
    final payment = _reconciled.remove(lineId);
    if (payment == null) {
      throw StateError('this movement reconciles no payment');
    }
    reportedPayments.add(payment);
    unreconciliations[requestId] = (
      lineId: lineId,
      paymentId: payment.payment.id,
      reason: reason.trim(),
    );
    return _set(lineId, BankLineStatus.open);
  }
}

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
  BankLine line(int n, int cents, {String reference = '', String text = '', String payer = ''}) =>
      BankLine(
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
  String? qrr(OpenInvoice i) => qrrReferenceOf(i.number);
  final byQr = open
      .where((i) => qrr(i) != null && open.where((o) => qrr(o) == qrr(i)).length == 1)
      .firstOrNull;
  final byRf = open.where((i) => i != byQr && scorReferenceOf(i.number) != null).firstOrNull;
  final lines = <BankLine>[
    if (byQr != null)
      line(1, byQr.dueCents, reference: qrr(byQr)!, payer: byQr.memberName),
    if (byRf != null)
      line(2, byRf.dueCents,
          reference: scorReferenceOf(byRf.number)!, payer: byRf.memberName),
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
  repo._import(
    statement,
    sha256.convert(utf8.encode('demo-statement')).toString(),
    'demo-camt054.xml',
  );
  return repo;
}
