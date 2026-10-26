// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Spanish register of issued invoices (libro registro de facturas
// expedidas, art. 63 RIVA) in the AEAT's normalised XLSX layout, the one
// the Sede reads in a request and Pre303 imports to fill the Modelo 303
// (LSIJ.xlsx, the design for legal persons outside SII, shipped verbatim
// under test/fixtures/vat_filing/es_libro/). One line per rate of each
// issued document (validation 7), the IRPF columns left empty: a separate
// VAT book (validation 12).
import 'package:meta/meta.dart';

import '../../../core/files/xlsx.dart';
import '../../../core/i18n/currencies.dart';
import '../../../core/time/date_text.dart';
import '../../../core/vat/place_of_supply.dart';
import 'invoice.dart';
import 'vat_rate.dart';

/// What the AEAT's keys say of one rate of an issued document: the
/// calificación (S1 taxed, S2 reverse-charged, N1/N2 not subject), the
/// cause of an exemption (E1-E6) and the clave de operación (01 the
/// régimen general, 02 an export). The 303's boxes read the same
/// categories (`es.dart`: AE in [59], Z in [60], G and O in [120]).
typedef EsOperation = ({String qualification, String exemption, String key});

/// The keys of an EN 16931 [category] for a buyer in [buyerCountry].
EsOperation esOperationOf(String category, String buyerCountry) =>
    switch (category) {
      // a reverse charge: inside Spain the buyer owes it (art. 84), across
      // a border the service is not subject here (art. 69)
      'AE' => (
        qualification: buyerCountry.toUpperCase() == 'ES' ? 'S2' : 'N2',
        exemption: '',
        key: '01',
      ),
      // exempt under art. 20 (interior operations)
      'E' => (qualification: '', exemption: 'E1', key: '01'),
      // an export, exempt under art. 21
      'Z' => (qualification: '', exemption: 'E2', key: '02'),
      // an intra-EU supply of goods, exempt under art. 25
      'K' => (qualification: '', exemption: 'E5', key: '01'),
      // not subject by the place-of-supply rules
      'G' || 'O' => (qualification: 'N2', exemption: '', key: '01'),
      _ => (qualification: 'S1', exemption: '', key: '01'),
    };

/// The documents a register lists for `[from, to)`: issued, not voided
/// (an erroneous document is replaced, and the return counts the
/// replacement), in issue order.
List<Invoice> registerDocuments(
  Iterable<Invoice> invoices, {
  required DateTime from,
  required DateTime to,
}) => [
  for (final i in invoices)
    if (!i.isVoided && !i.issuedAt.isBefore(from) && i.issuedAt.isBefore(to)) i,
]..sort((a, b) => a.issuedAt.compareTo(b.issuedAt));

/// How the buyer of [invoice] is identified: the AEAT's type (blank for a
/// Spanish NIF, 02 an EU VAT number, 06 another document), its country and
/// the number; all blank for a buyer without one.
({String type, String country, String id}) esBuyerIdOf(Invoice invoice) {
  final buyer = invoice.buyerParty;
  final raw = (buyer?.vatId ?? '').toUpperCase().replaceAll(
    RegExp('[^A-Z0-9]'),
    '',
  );
  final country = (buyer?.country ?? '').toUpperCase();
  if (raw.isEmpty) return (type: '', country: '', id: '');
  if (country == 'ES' || (country.isEmpty && raw.startsWith('ES'))) {
    return (
      type: '',
      country: '',
      id: raw.startsWith('ES') ? raw.substring(2) : raw,
    );
  }
  if (isEuCountry(country)) return (type: '02', country: country, id: raw);
  return (type: '06', country: country, id: raw);
}

/// The name of [invoice]'s buyer: the company, else the person.
String buyerNameOf(Invoice invoice) {
  final buyer = invoice.buyerParty;
  if (buyer == null) return invoice.memberName;
  return buyer.company.isNotEmpty ? buyer.company : buyer.name;
}

/// The tipo de factura (validation 9): F1 with an identified buyer, F2
/// without; a credit note takes its rectification reason (R1-R4, R5 when
/// the buyer is not identified), R4 ("resto") where none was frozen.
String esInvoiceTypeOf(Invoice invoice) {
  final identified = esBuyerIdOf(invoice).id.isNotEmpty;
  if (!invoice.isCreditNote) return identified ? 'F1' : 'F2';
  if (!identified) return 'R5';
  final reason = invoice.correctionReason.toUpperCase();
  return RegExp(r'^R[1-4]$').hasMatch(reason) ? reason : 'R4';
}

/// The libro's columns as the design's two header rows name them (rows 7
/// and 8 of the sheet), by position A..AJ: the group, then the column
/// inside it.
@visibleForTesting
const esLibroGroups = <int, String>{
  0: 'Autoliquidación',
  2: 'Actividad',
  5: 'Tipo de Factura',
  6: 'Concepto de Ingreso',
  7: 'Ingreso Computable',
  8: 'Fecha Expedición',
  9: 'Fecha Operación',
  10: 'Identificación de la Factura',
  13: 'NIF Destinatario',
  16: 'Nombre Destinatario',
  17: 'Clave de Operación',
  18: 'Calificación de la Operación',
  19: 'Operación Exenta',
  20: 'Total Factura',
  21: 'Base Imponible',
  22: 'Tipo de IVA',
  23: 'Cuota IVA Repercutida',
  24: 'Tipo de Recargo Eq.',
  25: 'Cuota Recargo Eq.',
  26: 'Cobro',
  30: 'Tipo Retención del IRPF',
  31: 'Importe Retenido del IRPF',
  32: 'Registro Acuerdo Facturación',
  33: 'Inmueble',
  35: 'Referencia Externa',
};

@visibleForTesting
const esLibroColumns = <int, String>{
  0: 'Ejercicio',
  1: 'Periodo',
  2: 'Código',
  3: 'Tipo',
  4: 'Grupo o Epígrafe del IAE',
  10: 'Serie',
  11: 'Número',
  12: 'Número-Final',
  13: 'Tipo',
  14: 'Código País',
  15: 'Identificación',
  26: 'Fecha',
  27: 'Importe',
  28: 'Medio Utilizado',
  29: 'Identificación Medio Utilizado',
  33: 'Situación',
  34: 'Referencia Catastral',
};

/// The design's width: columns A to AJ.
const _columns = 36;

/// The activity a line belongs to (validation 16): the code (A-D), the
/// type and the IAE heading, as one string (`A036533`); split into its
/// three columns. Asked when the book is saved.
({String code, String type, String heading}) _activity(String raw) {
  final a = raw.toUpperCase().replaceAll(RegExp(r'\s'), '');
  if (!isEsActivity(a) || a.isEmpty) return (code: '', type: '', heading: '');
  return (
    code: a.substring(0, 1),
    type: a.substring(1, 3),
    heading: a.substring(3),
  );
}

/// Whether [raw] has the shape of an activity: the code A-D, two digits of
/// type and up to four characters of IAE heading; empty is allowed (the
/// book then leaves the columns to the owner).
bool isEsActivity(String raw) =>
    RegExp(r'^([A-D]\d{2}[0-9A-Z]{0,4})?$')
        .hasMatch(raw.toUpperCase().replaceAll(RegExp(r'\s'), ''));

/// The book of [documents] (already narrowed to the year so far) as the
/// sheet `EXPEDIDAS`.
XlsxSheet esLibroExpedidas(
  List<Invoice> documents, {
  required String activity,
  bool monthly = false,
}) {
  final act = _activity(activity);
  List<Object?> header(Map<int, String> names) => [
    for (var c = 0; c < _columns; c++) names[c],
  ];
  return XlsxSheet(
    name: 'EXPEDIDAS',
    rows: [
      header(esLibroGroups),
      header(esLibroColumns),
      for (final invoice in documents)
        for (final total in invoice.vatTotals)
          _line(invoice, total, act, monthly: monthly),
    ],
  );
}

List<Object?> _line(
  Invoice invoice,
  InvoiceVatTotal total,
  ({String code, String type, String heading}) act, {
  required bool monthly,
}) {
  final day = invoice.issuedAt;
  final buyer = esBuyerIdOf(invoice);
  final op = esOperationOf(total.category, invoice.buyerParty?.country ?? '');
  final perMajor = Currencies.minorPerMajor(invoice.currency);
  XlsxAmount amount(int cents) => XlsxAmount(cents / perMajor);
  final taxed = op.qualification == 'S1';
  return [
    day.year,
    // the period of the return the line falls in: the month for a monthly
    // filer, else the quarter (validation 11)
    if (monthly) twoDigits(day.month) else '${(day.month - 1) ~/ 3 + 1}T',
    act.code,
    act.type,
    act.heading,
    esInvoiceTypeOf(invoice),
    null, // concepto de ingreso: IRPF
    null, // ingreso computable: IRPF
    dmy(day),
    null, // the operation's date is the issue date
    null, // serie: the number carries it
    invoice.number,
    null,
    buyer.type,
    buyer.country,
    buyer.id,
    _cut(buyerNameOf(invoice), 40),
    op.key,
    op.qualification,
    op.exemption,
    amount(taxed ? total.netCents + total.vatCents : total.netCents),
    amount(total.netCents),
    if (taxed) total.percent else 0,
    amount(taxed ? total.vatCents : 0),
    for (var c = 24; c < _columns; c++) null,
  ];
}

String _cut(String text, int max) =>
    text.length <= max ? text : text.substring(0, max);
