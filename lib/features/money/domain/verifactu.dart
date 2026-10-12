// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2358 — the Spanish Verifactu record (RD 1007/2023, Orden HAC/1177/2024).
//
// From 2027 a Spanish seller's invoicing software must keep, for every
// invoice it issues, a record chained to the previous one by a SHA-256
// "huella", print a QR code that lets the customer check the invoice at
// the AEAT, and either send each record to the AEAT ("VERI*FACTU" mode)
// or sign and keep them. This file builds the record, its huella, the QR
// URL and the record XML from the invoice's own snapshot.
//
// The submission (a SOAP call to the AEAT, authenticated with the
// seller's qualified certificate) is owner-blocked and lives in the
// connector, not here. The chain also needs the server: two records
// issued at the same moment must not both claim the same predecessor,
// so the previous huella is read under a lock where the record is
// stored, never on a phone.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';
import 'package:xml/xml.dart';

import 'invoice.dart';
import 'vat_rate.dart';

/// The legend a Verifactu invoice prints. It is fixed by the Order, in
/// Spanish, whatever language the reader uses, so it is not an l10n string.
const verifactuLegend = 'VERI*FACTU';

/// The long mention printed beside the QR code. Fixed Spanish text, like
/// [verifactuLegend].
const verifactuMention =
    'Factura verificable en la sede electrónica de la AEAT';

/// The AEAT schema the record elements belong to.
const _verifactuNamespace =
    'https://www2.agenciatributaria.gob.es/static_files/common/internet/'
    'dep/aplicaciones/es/aeat/tike/cont/ws/SuministroInformacion.xsd';

/// One alta record (RegistroAlta), the fields the huella covers plus the
/// link to its predecessor.
@visibleForTesting
class VerifactuRecord {
  const VerifactuRecord({
    required this.issuerNif,
    required this.number,
    required this.issueDate,
    required this.type,
    required this.taxTotal,
    required this.grandTotal,
    required this.previousHuella,
    required this.generatedAt,
    required this.huella,
    this.previousNumber = '',
    this.previousIssueDate = '',
    this.buyerName = '',
    this.buyerNif = '',
    this.breakdown = const [],
  });

  /// IDEmisorFactura — the seller's NIF, without the 'ES' prefix.
  final String issuerNif;

  /// NumSerieFactura.
  final String number;

  /// FechaExpedicionFactura, dd-MM-yyyy.
  final String issueDate;

  /// TipoFactura: F1 an invoice, F2 a simplified one (no buyer tax id),
  /// R1 a rectification.
  final String type;

  /// CuotaTotal and ImporteTotal, two decimals with a '.' — the AEAT's
  /// spelling, which the huella hashes as text.
  final String taxTotal;
  final String grandTotal;

  /// The predecessor's huella; '' for the first record of the chain.
  final String previousHuella;

  /// The predecessor's number and date, for the record's chaining block.
  final String previousNumber;
  final String previousIssueDate;

  /// FechaHoraHusoGenRegistro, ISO 8601 with the offset.
  final String generatedAt;

  /// SHA-256 of the fields above, upper-case hex.
  final String huella;

  /// The buyer, named only when it has a Spanish NIF.
  final String buyerName;
  final String buyerNif;

  /// One entry per VAT rate of the invoice.
  final List<InvoiceVatTotal> breakdown;

  bool get isFirst => previousHuella.isEmpty;

  /// The same record with its amounts replaced, the huella left as is — a
  /// tampered copy, which [verifactuChainHolds] must catch.
  VerifactuRecord withTotals({String? taxTotal, String? grandTotal}) =>
      VerifactuRecord(
        issuerNif: issuerNif,
        number: number,
        issueDate: issueDate,
        type: type,
        taxTotal: taxTotal ?? this.taxTotal,
        grandTotal: grandTotal ?? this.grandTotal,
        previousHuella: previousHuella,
        generatedAt: generatedAt,
        huella: huella,
        previousNumber: previousNumber,
        previousIssueDate: previousIssueDate,
        buyerName: buyerName,
        buyerNif: buyerNif,
        breakdown: breakdown,
      );
}

String _sha256Upper(String text) =>
    sha256.convert(utf8.encode(text)).toString().toUpperCase();

/// The huella of an alta record, as the AEAT's "Algoritmo de cálculo de
/// huella" defines it: the named fields joined with '&', values trimmed.
@visibleForTesting
String verifactuHuella({
  required String issuerNif,
  required String number,
  required String issueDate,
  required String type,
  required String taxTotal,
  required String grandTotal,
  required String previousHuella,
  required String generatedAt,
}) => _sha256Upper(
  [
    'IDEmisorFactura=${issuerNif.trim()}',
    'NumSerieFactura=${number.trim()}',
    'FechaExpedicionFactura=${issueDate.trim()}',
    'TipoFactura=${type.trim()}',
    'CuotaTotal=${taxTotal.trim()}',
    'ImporteTotal=${grandTotal.trim()}',
    'Huella=${previousHuella.trim()}',
    'FechaHoraHusoGenRegistro=${generatedAt.trim()}',
  ].join('&'),
);

/// The huella of a cancellation record (RegistroAnulacion).
String verifactuCancellationHuella({
  required String issuerNif,
  required String number,
  required String issueDate,
  required String previousHuella,
  required String generatedAt,
}) => _sha256Upper(
  [
    'IDEmisorFacturaAnulada=${issuerNif.trim()}',
    'NumSerieFacturaAnulada=${number.trim()}',
    'FechaExpedicionFacturaAnulada=${issueDate.trim()}',
    'Huella=${previousHuella.trim()}',
    'FechaHoraHusoGenRegistro=${generatedAt.trim()}',
  ].join('&'),
);

String _two(int n) => n.toString().padLeft(2, '0');

/// dd-MM-yyyy, the date spelling every Verifactu field uses.
String _verifactuDate(DateTime d) =>
    '${_two(d.day)}-${_two(d.month)}-${d.year.toString().padLeft(4, '0')}';

/// ISO 8601 with the offset of [d] ('2026-10-11T19:20:30+02:00'). The
/// offset is part of the hashed text, so a UTC instant and its local
/// spelling give different huellas: the record keeps the one it hashed.
@visibleForTesting
String verifactuTimestamp(DateTime d) {
  final offset = d.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final minutes = offset.inMinutes.abs();
  return '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-'
      '${_two(d.day)}T${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}'
      '$sign${_two(minutes ~/ 60)}:${_two(minutes % 60)}';
}

/// Minor units as the AEAT writes an amount: two decimals, '.', a leading
/// '-' when negative.
String _verifactuAmount(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  return '$sign${abs ~/ 100}.${_two(abs % 100)}';
}

String _nif(String id) {
  final trimmed = id.replaceAll(' ', '').toUpperCase();
  return trimmed.startsWith('ES') ? trimmed.substring(2) : trimmed;
}

/// The record for [invoice], chained to [previousHuella].
///
/// A credit note or a replacement is an R1 rectification stated "por
/// diferencias": its amounts carry the sign of what it changes, so a
/// credit note's are negative. A buyer without any tax id makes it an F2.
VerifactuRecord verifactuRecordFor({
  required Invoice invoice,
  required InvoiceParty seller,
  required InvoiceParty buyer,
  required String previousHuella,
  required DateTime generatedAt,
  String previousNumber = '',
  String previousIssueDate = '',
}) {
  final rectifies = invoice.isCreditNote || invoice.replacesNumber.isNotEmpty;
  final buyerId = buyer.vatId.isNotEmpty ? buyer.vatId : buyer.legalId;
  final type = rectifies
      ? 'R1'
      : buyerId.isEmpty
      ? 'F2'
      : 'F1';
  // The issued breakdown is the document's own truth; without one the
  // invoice states no tax and its total is the gross.
  final gross = invoice.vatTotals.isEmpty
      ? invoice.totalCents
      : invoice.vatTotals.fold(0, (sum, t) => sum + t.grossCents);
  final sign = invoice.isCreditNote && gross > 0 ? -1 : 1;
  final tax = invoice.isCreditNote ? -invoice.vatCents.abs() : invoice.vatCents;
  final issuerNif = _nif(
    seller.vatId.isNotEmpty ? seller.vatId : seller.legalId,
  );
  final issueDate = _verifactuDate(invoice.issuedAt);
  final taxTotal = _verifactuAmount(tax);
  final grandTotal = _verifactuAmount(sign * gross);
  final stamp = verifactuTimestamp(generatedAt);
  final spanishBuyer =
      buyer.country.toUpperCase() == 'ES' && buyerId.isNotEmpty;
  return VerifactuRecord(
    issuerNif: issuerNif,
    number: invoice.number,
    issueDate: issueDate,
    type: type,
    taxTotal: taxTotal,
    grandTotal: grandTotal,
    previousHuella: previousHuella,
    previousNumber: previousNumber,
    previousIssueDate: previousIssueDate,
    generatedAt: stamp,
    huella: verifactuHuella(
      issuerNif: issuerNif,
      number: invoice.number,
      issueDate: issueDate,
      type: type,
      taxTotal: taxTotal,
      grandTotal: grandTotal,
      previousHuella: previousHuella,
      generatedAt: stamp,
    ),
    buyerName: spanishBuyer ? buyer.name : '',
    buyerNif: spanishBuyer ? _nif(buyerId) : '',
    breakdown: invoice.vatTotals,
  );
}

/// Whether every record's huella still matches its fields and names its
/// predecessor's huella — the check an inspector runs on the stored chain.
bool verifactuChainHolds(List<VerifactuRecord> records) {
  var previous = '';
  for (final r in records) {
    if (r.previousHuella != previous) return false;
    final expected = verifactuHuella(
      issuerNif: r.issuerNif,
      number: r.number,
      issueDate: r.issueDate,
      type: r.type,
      taxTotal: r.taxTotal,
      grandTotal: r.grandTotal,
      previousHuella: r.previousHuella,
      generatedAt: r.generatedAt,
    );
    if (expected != r.huella) return false;
    previous = r.huella;
  }
  return true;
}

/// The URL the printed QR code encodes: the AEAT's check page for this
/// invoice. [test] points at the AEAT's pre-production host.
Uri verifactuQrUrl(VerifactuRecord r, {bool test = false}) {
  final host = test
      ? 'https://prewww2.aeat.es'
      : 'https://www2.agenciatributaria.gob.es';
  String param(String key, String value) =>
      '$key=${Uri.encodeComponent(value)}';
  return Uri.parse(
    '$host/wlpl/TIKE-CONT/ValidarQR?'
    '${[param('nif', r.issuerNif), param('numserie', r.number), param('fecha', r.issueDate), param('importe', r.grandTotal)].join('&')}',
  );
}

/// The software that produced the record (SistemaInformatico). The
/// producer's NIF is the software maker's, which an instance operator
/// states in its connector configuration.
class VerifactuSystem {
  const VerifactuSystem({
    this.producerName = 'DesKilo',
    this.producerNif = '',
    this.version = '1.0',
    this.installationNumber = '1',
  });

  final String producerName;
  final String producerNif;
  final String version;
  final String installationNumber;
}

/// The record as the AEAT's RegistroAlta element, in the schema's
/// element order (an out-of-order record is refused before any rule).
String verifactuRecordXml(
  VerifactuRecord r, {
  required String issuerName,
  String description = 'Servicios de espacio de trabajo',
  VerifactuSystem system = const VerifactuSystem(),
}) {
  final b = XmlBuilder();
  void el(String name, String text) =>
      b.element('sum1:$name', nest: () => b.text(text));
  void id(String nif, String number, String date) {
    el('IDEmisorFactura', nif);
    el('NumSerieFactura', number);
    el('FechaExpedicionFactura', date);
  }

  b.element(
    'sum1:RegistroAlta',
    nest: () {
      b.namespace(_verifactuNamespace, 'sum1');
      el('IDVersion', '1.0');
      b.element(
        'sum1:IDFactura',
        nest: () => id(r.issuerNif, r.number, r.issueDate),
      );
      el('NombreRazonEmisor', issuerName);
      el('TipoFactura', r.type);
      // A rectification "por diferencias" states the change itself.
      if (r.type.startsWith('R')) el('TipoRectificativa', 'I');
      el('DescripcionOperacion', description);
      if (r.buyerNif.isNotEmpty) {
        b.element(
          'sum1:Destinatarios',
          nest: () {
            b.element(
              'sum1:IDDestinatario',
              nest: () {
                el('NombreRazon', r.buyerName);
                el('NIF', r.buyerNif);
              },
            );
          },
        );
      }
      b.element(
        'sum1:Desglose',
        nest: () {
          for (final t in r.breakdown) {
            b.element(
              'sum1:DetalleDesglose',
              nest: () {
                el('Impuesto', '01');
                el('ClaveRegimen', '01');
                switch (t.category) {
                  case 'E':
                    // Exempt (art. 20 LIVA): no rate and no tax.
                    el('OperacionExenta', 'E1');
                    el(
                      'BaseImponibleOimporteNoSujeto',
                      _verifactuAmount(t.netCents),
                    );
                  case 'O':
                    // Outside the scope: the amount is "no sujeto".
                    el('CalificacionOperacion', 'N2');
                    el(
                      'BaseImponibleOimporteNoSujeto',
                      _verifactuAmount(t.netCents),
                    );
                  default:
                    // S1 taxed by the seller; S2 the customer reverse-charges.
                    el(
                      'CalificacionOperacion',
                      t.category == 'AE' ? 'S2' : 'S1',
                    );
                    el('TipoImpositivo', t.percent.toStringAsFixed(2));
                    el(
                      'BaseImponibleOimporteNoSujeto',
                      _verifactuAmount(t.netCents),
                    );
                    el('CuotaRepercutida', _verifactuAmount(t.vatCents));
                }
              },
            );
          }
        },
      );
      el('CuotaTotal', r.taxTotal);
      el('ImporteTotal', r.grandTotal);
      b.element(
        'sum1:Encadenamiento',
        nest: () {
          if (r.isFirst) {
            el('PrimerRegistro', 'S');
          } else {
            b.element(
              'sum1:RegistroAnterior',
              nest: () {
                id(r.issuerNif, r.previousNumber, r.previousIssueDate);
                el('Huella', r.previousHuella);
              },
            );
          }
        },
      );
      b.element(
        'sum1:SistemaInformatico',
        nest: () {
          el('NombreRazon', system.producerName);
          el('NIF', system.producerNif);
          el('NombreSistemaInformatico', 'DesKilo');
          el('IdSistemaInformatico', 'DK');
          el('Version', system.version);
          el('NumeroInstalacion', system.installationNumber);
          el('TipoUsoPosibleSoloVerifactu', 'S');
          el('TipoUsoPosibleMultiOT', 'N');
          el('IndicadorMultiplesOT', 'N');
        },
      );
      el('FechaHoraHusoGenRegistro', r.generatedAt);
      el('TipoHuella', '01');
      el('Huella', r.huella);
    },
  );
  return b.buildDocument().toXmlString(pretty: true, indent: '  ');
}
