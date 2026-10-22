// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/vat_regime.dart';

/// #2365 — moved here when the book chart started reading the rows itself:
/// the per-country goldens still read the charts through it.
///
/// A **preview** of the chart of accounts a bookkeeper would likely use
/// for this workspace (#671). Explicitly NOT an accounting solution, and
/// the app does not keep a ledger — this exists so that:
///
///  * an owner can SEE what a real chart looks like against their own
///    revenue, instead of meeting the concept for the first time in an
///    accountant's email; and
///  * the export sheets (FEC, DATEV) can PROPOSE account numbers that
///    fit the country, instead of leaving four blank fields whose
///    meaning only an accountant knows.
///
/// Every number below is a SUGGESTION drawn from the standard national
/// chart. The proposal is shown before anything is written, and the
/// accountant's correction always wins — that is the same bargain
/// `fec.dart` already strikes, and the reason neither file invents codes
/// silently.
///
/// Deliberately shallow: the handful of accounts a coworking space
/// actually touches. A chart has thousands; pretending to more than the
/// app can justify would make the preview look authoritative, which is
/// the one thing it must not be.
enum CoaAccountRole {
  /// What members owe — the receivable.
  customers,

  /// What the space sells: desks, rooms, services.
  revenue,

  /// Where the money lands.
  bank,

  /// Output VAT, only under a VAT-charging regime.
  vat,

  /// #936 — what the workspace spends: reimbursed expenses and shared
  /// costs, which the purchases journal books since the exporters
  /// carry it. Every chart proposes one, so the preview matches the file.
  expenses,
}

/// One suggested account.
class CoaAccount {
  const CoaAccount({
    required this.role,
    required this.number,
    required this.label,
    required this.note,
  });

  final CoaAccountRole role;

  /// The number in the country's standard chart.
  final String number;

  /// The name that chart gives it, in the chart's own language — an
  /// accountant recognises `Prestations de services`, not a translation
  /// of it.
  final String label;

  /// Why this account, in the reader's language: the preview is for
  /// someone who does not already know.
  final String note;
}

/// The national chart a country's bookkeepers actually use.
class CoaChart {
  const CoaChart({
    required this.code,
    required this.name,
    required this.accounts,
  });

  /// 'PCG', 'SKR03', 'PGC', … — shown so the accountant can say
  /// "we use SKR04" and the owner knows what that answers.
  final String code;
  final String name;
  final List<CoaAccount> accounts;

  String numberFor(CoaAccountRole role) =>
      accounts.firstWhere((a) => a.role == role).number;
}

/// The suggested chart for [countryCode], VAT accounts included only
/// when the workspace actually charges VAT — an exempt association
/// shown a `TVA collectée` line would be told to book something it never
/// owes.
///
/// #2481 -- the chart is the country's `account_map` rows (its `chart` row
/// names it, the others are its accounts in order), read from [reference]
/// or the installed snapshot. An unknown country falls back to the shared
/// generic numbering rather than to France: a wrong-country chart that LOOKS
/// national is more misleading than one that is obviously generic.
CoaChart coaChartFor({
  required String countryCode,
  required VatRegime regime,
  required String Function(CoaAccountRole role) noteFor,
  TaxReferenceSet? reference,
}) {
  final charging = regime == VatRegime.vatRegistered;
  final rows = (reference ?? ActiveTaxReference.current).chartOf(countryCode);
  final header = rows.where((r) => r.role == 'chart').firstOrNull;
  if (header == null) {
    throw TaxReferenceUnavailable('no chart of accounts for $countryCode');
  }
  return CoaChart(
    code: header.account,
    name: header.label,
    accounts: [
      for (final r in rows)
        if (r.role != 'chart')
          if (CoaAccountRole.values.where((x) => x.name == r.role).firstOrNull
              case final role?)
            if (role != CoaAccountRole.vat || charging)
              CoaAccount(
                role: role,
                number: r.account,
                label: r.label,
                note: noteFor(role),
              ),
    ],
  );
}
