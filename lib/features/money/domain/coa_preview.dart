// SPDX-License-Identifier: 0BSD
import 'vat_regime.dart';

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
/// An unknown country falls back to the OECD-ish generic numbering
/// rather than to France: a wrong-country chart that LOOKS national is
/// more misleading than one that is obviously generic.
CoaChart coaChartFor({
  required String countryCode,
  required VatRegime regime,
  required String Function(CoaAccountRole role) noteFor,
}) {
  final charging = regime == VatRegime.vatRegistered;

  List<CoaAccount> build(
    List<({CoaAccountRole role, String number, String label})> rows,
  ) =>
      [
        for (final r in rows)
          if (r.role != CoaAccountRole.vat || charging)
            CoaAccount(
              role: r.role,
              number: r.number,
              label: r.label,
              note: noteFor(r.role),
            ),
      ];

  return switch (countryCode.toUpperCase()) {
    // Plan comptable général. Already the FEC's defaults, so the preview
    // and the export agree by construction.
    'FR' => CoaChart(
        code: 'PCG',
        name: 'Plan comptable général',
        accounts: build(const [
          (role: CoaAccountRole.customers, number: '411000', label: 'Clients'),
          (
            role: CoaAccountRole.revenue,
            number: '706000',
            label: 'Prestations de services'
          ),
          (role: CoaAccountRole.bank, number: '512000', label: 'Banques'),
          (role: CoaAccountRole.vat, number: '445710', label: 'TVA collectée'),
        ]),
      ),
    // SKR03 — the commonest German chart for a small service business,
    // and the DATEV export's defaults.
    'DE' || 'AT' => CoaChart(
        code: 'SKR03',
        name: 'DATEV-Standardkontenrahmen 03',
        accounts: build(const [
          (
            role: CoaAccountRole.customers,
            number: '10000',
            label: 'Debitoren'
          ),
          (
            role: CoaAccountRole.revenue,
            number: '8400',
            label: 'Erlöse 19 % USt'
          ),
          (role: CoaAccountRole.bank, number: '1200', label: 'Bank'),
          (
            role: CoaAccountRole.vat,
            number: '1776',
            label: 'Umsatzsteuer 19 %'
          ),
        ]),
      ),
    'ES' => CoaChart(
        code: 'PGC',
        name: 'Plan General de Contabilidad',
        accounts: build(const [
          (role: CoaAccountRole.customers, number: '430', label: 'Clientes'),
          (
            role: CoaAccountRole.revenue,
            number: '705',
            label: 'Prestaciones de servicios'
          ),
          (role: CoaAccountRole.bank, number: '572', label: 'Bancos'),
          (
            role: CoaAccountRole.vat,
            number: '477',
            label: 'IVA repercutido'
          ),
        ]),
      ),
    'IT' => CoaChart(
        code: 'CC',
        name: 'Codice civile — schema di bilancio',
        accounts: build(const [
          (role: CoaAccountRole.customers, number: '1510', label: 'Clienti'),
          (
            role: CoaAccountRole.revenue,
            number: '5810',
            label: 'Ricavi per servizi'
          ),
          (role: CoaAccountRole.bank, number: '1820', label: 'Banca c/c'),
          (
            role: CoaAccountRole.vat,
            number: '2610',
            label: 'IVA a debito'
          ),
        ]),
      ),
    'BE' || 'LU' => CoaChart(
        code: 'PCMN',
        name: 'Plan comptable minimum normalisé',
        accounts: build(const [
          (role: CoaAccountRole.customers, number: '400', label: 'Clients'),
          (
            role: CoaAccountRole.revenue,
            number: '700',
            label: 'Prestations de services'
          ),
          (
            role: CoaAccountRole.bank,
            number: '550',
            label: 'Établissements de crédit'
          ),
          (role: CoaAccountRole.vat, number: '451', label: 'TVA à payer'),
        ]),
      ),
    'NL' => CoaChart(
        code: 'RGS',
        name: 'Referentie Grootboekschema',
        accounts: build(const [
          (role: CoaAccountRole.customers, number: '1300', label: 'Debiteuren'),
          (
            role: CoaAccountRole.revenue,
            number: '8000',
            label: 'Opbrengst diensten'
          ),
          (role: CoaAccountRole.bank, number: '1100', label: 'Bank'),
          (
            role: CoaAccountRole.vat,
            number: '1500',
            label: 'Af te dragen btw'
          ),
        ]),
      ),
    'PT' => CoaChart(
        code: 'SNC',
        name: 'Sistema de Normalização Contabilística',
        accounts: build(const [
          (role: CoaAccountRole.customers, number: '211', label: 'Clientes'),
          (
            role: CoaAccountRole.revenue,
            number: '721',
            label: 'Prestações de serviços'
          ),
          (
            role: CoaAccountRole.bank,
            number: '12',
            label: 'Depósitos à ordem'
          ),
          (role: CoaAccountRole.vat, number: '2433', label: 'IVA liquidado'),
        ]),
      ),
    'CH' => CoaChart(
        code: 'KMU',
        name: 'Kontenrahmen KMU',
        accounts: build(const [
          (
            role: CoaAccountRole.customers,
            number: '1100',
            label: 'Forderungen aus Lieferungen und Leistungen'
          ),
          (
            role: CoaAccountRole.revenue,
            number: '3400',
            label: 'Dienstleistungsertrag'
          ),
          (role: CoaAccountRole.bank, number: '1020', label: 'Bank'),
          (
            role: CoaAccountRole.vat,
            number: '2200',
            label: 'Geschuldete MWST'
          ),
        ]),
      ),
    // No national chart is imposed in these; the numbering below is the
    // conventional shape an accountant will recognise and re-point.
    _ => CoaChart(
        code: 'GEN',
        name: 'Generic',
        accounts: build(const [
          (
            role: CoaAccountRole.customers,
            number: '1200',
            label: 'Accounts receivable'
          ),
          (
            role: CoaAccountRole.revenue,
            number: '4000',
            label: 'Service revenue'
          ),
          (role: CoaAccountRole.bank, number: '1000', label: 'Bank'),
          (role: CoaAccountRole.vat, number: '2200', label: 'Sales tax payable'),
        ]),
      ),
  };
}
