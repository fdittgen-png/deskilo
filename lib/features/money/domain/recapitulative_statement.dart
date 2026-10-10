// SPDX-License-Identifier: AGPL-3.0-or-later
import 'invoice.dart';
import '../../../core/vat/place_of_supply.dart';

/// #2354 — one line of the recapitulative statement (EU sales list):
/// the services a seller reverse-charged (category AE, Directive art. 196)
/// to one customer VAT number in one month. Art. 262(1)(c) makes the list
/// mandatory whenever AE is used for services: the DES in France, the
/// Zusammenfassende Meldung in Germany, modelo 349 in Spain.
class RecapitulativeLine {
  const RecapitulativeLine({
    required this.period,
    required this.country,
    required this.vatNumber,
    required this.customer,
    required this.netCents,
    required this.invoices,
  });

  /// `yyyy-MM`, the month the invoice was issued in.
  final String period;

  /// The member-state prefix of the customer's VAT number (Greece `EL`).
  final String country;

  /// The number without its prefix, letters and digits only.
  final String vatNumber;
  final String customer;

  /// The reverse-charged amount (no VAT is charged: net = gross).
  final int netCents;

  /// How many documents contributed.
  final int invoices;
}

/// The customer's VAT number as the list wants it: the prefix (Greece
/// `EL`) and the number, letters and digits only — the twin of
/// `public.vies_vat_parts`.
({String country, String number}) vatNumberParts(String vatId, String country) {
  var v = vatId.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
  String prefix;
  if (RegExp('^[A-Z]{2}').hasMatch(v)) {
    prefix = v.substring(0, 2);
    v = v.substring(2);
  } else {
    prefix = euCountryCode(country);
  }
  return (country: prefix == 'GR' ? 'EL' : prefix, number: v);
}

/// The list for invoices issued in `[from, to)`: every issued, not voided
/// document's category-AE amount, summed per month and customer number.
/// A credit note's AE amount is negative and reduces its month's line.
List<RecapitulativeLine> recapitulativeStatement(
  Iterable<Invoice> invoices, {
  required DateTime from,
  required DateTime to,
}) {
  final sums = <String, ({RecapitulativeLine line, Set<String> ids})>{};
  for (final invoice in invoices) {
    if (invoice.isVoided) continue;
    if (invoice.issuedAt.isBefore(from) || !invoice.issuedAt.isBefore(to)) {
      continue;
    }
    final ae = invoice.vatTotals
        .where((t) => t.category == 'AE')
        .fold(0, (sum, t) => sum + t.netCents);
    if (ae == 0) continue;
    final buyer = invoice.buyerParty;
    final parts = vatNumberParts(buyer?.vatId ?? '', buyer?.country ?? '');
    final period =
        '${invoice.issuedAt.year.toString().padLeft(4, '0')}-'
        '${invoice.issuedAt.month.toString().padLeft(2, '0')}';
    final key = '$period|${parts.country}|${parts.number}';
    final before = sums[key];
    final customer = buyer == null
        ? invoice.memberName
        : (buyer.company.isNotEmpty ? buyer.company : buyer.name);
    final ids = {...?before?.ids, invoice.id};
    sums[key] = (
      line: RecapitulativeLine(
        period: period,
        country: parts.country,
        vatNumber: parts.number,
        customer: before?.line.customer ?? customer,
        netCents: (before?.line.netCents ?? 0) + ae,
        invoices: ids.length,
      ),
      ids: ids,
    );
  }
  final lines = [for (final e in sums.values) e.line]
    ..sort((a, b) {
      final p = a.period.compareTo(b.period);
      if (p != 0) return p;
      final c = a.country.compareTo(b.country);
      return c != 0 ? c : a.vatNumber.compareTo(b.vatNumber);
    });
  return lines;
}

/// The list as CSV (RFC 4180, `;`-free): period, the member state, the
/// customer's VAT number, the customer, the amount in the currency's
/// major unit with a dot, the number of documents. The header names are
/// fixed so an accountant's import can rely on them.
String recapitulativeCsv(
  List<RecapitulativeLine> lines, {
  int minorDigits = 2,
}) {
  String field(String v) =>
      v.contains(RegExp('[",\n]')) ? '"${v.replaceAll('"', '""')}"' : v;
  String amount(int cents) {
    final negative = cents < 0;
    final abs = cents.abs().toString().padLeft(minorDigits + 1, '0');
    final major = abs.substring(0, abs.length - minorDigits);
    final minor = abs.substring(abs.length - minorDigits);
    return '${negative ? '-' : ''}$major${minorDigits > 0 ? '.$minor' : ''}';
  }

  final b = StringBuffer(
    'period,country,vat_number,customer,amount,documents\r\n',
  );
  for (final l in lines) {
    b.write(
      [
        l.period,
        l.country,
        l.vatNumber,
        field(l.customer),
        amount(l.netCents),
        '${l.invoices}',
      ].join(','),
    );
    b.write('\r\n');
  }
  return b.toString();
}
