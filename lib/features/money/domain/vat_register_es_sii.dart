// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Spanish register of issued invoices as the AEAT's SII message
// (Suministro Inmediato de Información 1.1, `SuministroLRFacturasEmitidas`),
// validated against the published SuministroLR.xsd. An export only: the
// submission is a web service authenticated with the seller's qualified
// certificate, which the app does not hold. A space that keeps its books
// through SII hands the file to its SII software or adviser.
import 'package:xml/xml.dart';

import '../../../core/money/money_text.dart';
import '../../../core/time/date_text.dart';
import 'invoice.dart';
import 'vat_filing_terms.dart';
import 'vat_rate.dart';
import 'vat_register_es.dart';

const _sii =
    'https://www2.agenciatributaria.gob.es/static_files/common/internet/dep/'
    'aplicaciones/es/aeat/ssii/fact/ws/SuministroInformacion.xsd';
const _siiLR =
    'https://www2.agenciatributaria.gob.es/static_files/common/internet/dep/'
    'aplicaciones/es/aeat/ssii/fact/ws/SuministroLR.xsd';

/// The schema's caps on one invoice's breakdown.
const _maxTaxedRates = 6;
const _maxExemptions = 7;

/// [documents] issued by the space named [name] with the NIF [vatId] as
/// one `SuministroLRFacturasEmitidas` of new records (`A0`), each in the
/// month it was issued (`PeriodoLiquidacion`). A buyer identified by a
/// Spanish NIF gets the breakdown by invoice; any other the breakdown by
/// type of operation (services). Throws [VatFilingFileException] when the
/// space's NIF is not one.
String siiFacturasEmitidasXml(
  List<Invoice> documents, {
  required String vatId,
  required String name,
}) {
  var nif = vatId.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
  if (nif.startsWith('ES')) nif = nif.substring(2);
  if (!RegExp(r'^([A-Z]\d{7}[A-Z]|\d{8}[A-Z]|[A-Z]\d{8})$').hasMatch(nif)) {
    throw const VatFilingFileException(VatFilingFileProblem.vatNumber);
  }
  final b = XmlBuilder()..processing('xml', 'version="1.0" encoding="UTF-8"');
  void el(String tag, String text) => b.element('sii:$tag', nest: text);
  b.element(
    'siiLR:SuministroLRFacturasEmitidas',
    namespaces: {_sii: 'sii', _siiLR: 'siiLR'},
    nest: () {
      b.element(
        'sii:Cabecera',
        nest: () {
          el('IDVersionSii', '1.1');
          b.element(
            'sii:Titular',
            nest: () {
              el('NombreRazon', _cut(name, 120));
              el('NIF', nif);
            },
          );
          el('TipoComunicacion', 'A0');
        },
      );
      for (final invoice in documents) {
        _Record(b, invoice, nif).write();
      }
    },
  );
  return b.buildDocument().toXmlString(pretty: true, indent: '  ');
}

/// One invoice's record, element by element in the schema's order.
class _Record {
  _Record(this.b, this.invoice, this.nif)
    : buyer = esBuyerIdOf(invoice),
      country = invoice.buyerParty?.country ?? '';

  final XmlBuilder b;
  final Invoice invoice;
  final String nif;
  final ({String type, String country, String id}) buyer;
  final String country;

  void el(String tag, String text) => b.element('sii:$tag', nest: text);
  String amount(int cents) => minorToText(cents, invoice.currency);
  EsOperation op(InvoiceVatTotal t) => esOperationOf(t.category, country);

  /// A buyer identified by a Spanish NIF.
  bool get domestic => buyer.id.isNotEmpty && buyer.type.isEmpty;

  void write() {
    final day = invoice.issuedAt;
    b.element(
      'siiLR:RegistroLRFacturasEmitidas',
      nest: () {
        b.element(
          'sii:PeriodoLiquidacion',
          nest: () {
            el('Ejercicio', '${day.year}');
            el('Periodo', twoDigits(day.month));
          },
        );
        b.element(
          'siiLR:IDFactura',
          nest: () {
            b.element('sii:IDEmisorFactura', nest: () => el('NIF', nif));
            el('NumSerieFacturaEmisor', invoice.number);
            el('FechaExpedicionFacturaEmisor', dmy(day, separator: '-'));
          },
        );
        b.element('siiLR:FacturaExpedida', nest: _invoice);
      },
    );
  }

  void _invoice() {
    final type = esInvoiceTypeOf(invoice);
    el('TipoFactura', type);
    // A credit note of this app states the difference (por diferencias).
    if (type.startsWith('R')) el('TipoRectificativa', 'I');
    final export = invoice.vatTotals.any((t) => op(t).key == '02');
    el('ClaveRegimenEspecialOTrascendencia', export ? '02' : '01');
    el('ImporteTotal', amount(invoice.totalCents));
    el(
      'DescripcionOperacion',
      _cut(invoice.title.isEmpty ? invoice.number : invoice.title, 500),
    );
    if (buyer.id.isNotEmpty) b.element('sii:Contraparte', nest: _counterpart);
    b.element('sii:TipoDesglose', nest: _desglose);
  }

  void _counterpart() {
    el('NombreRazon', _cut(buyerNameOf(invoice), 120));
    if (domestic) {
      el('NIF', buyer.id);
      return;
    }
    b.element(
      'sii:IDOtro',
      nest: () {
        if (buyer.country.isNotEmpty) el('CodigoPais', buyer.country);
        el('IDType', buyer.type);
        el('ID', _cut(buyer.id, 20));
      },
    );
  }

  /// By invoice for a Spanish buyer or none; by type of operation
  /// (services) for one identified abroad.
  void _desglose() {
    if (domestic || buyer.id.isEmpty) {
      b.element('sii:DesgloseFactura', nest: _breakdown);
    } else {
      b.element(
        'sii:DesgloseTipoOperacion',
        nest: () => b.element('sii:PrestacionServicios', nest: _breakdown),
      );
    }
  }

  /// Sujeta (the exempt causes, then the taxed rates) and NoSujeta.
  void _breakdown() {
    final exempt = [
      for (final t in invoice.vatTotals)
        if (op(t).exemption.isNotEmpty) t,
    ];
    final taxed = [
      for (final t in invoice.vatTotals)
        if (op(t).exemption.isEmpty && op(t).qualification.startsWith('S')) t,
    ];
    if (exempt.length > _maxExemptions || taxed.length > _maxTaxedRates) {
      throw const VatFilingFileException(VatFilingFileProblem.unmappedBox);
    }
    if (exempt.isNotEmpty || taxed.isNotEmpty) {
      b.element(
        'sii:Sujeta',
        nest: () {
          if (exempt.isNotEmpty) _exempt(exempt);
          if (taxed.isNotEmpty) _taxed(taxed);
        },
      );
    }
    int notSubject(String qualification) => invoice.vatTotals
        .where((t) => op(t).qualification == qualification)
        .fold(0, (sum, t) => sum + t.netCents);
    final art7 = notSubject('N1');
    final place = notSubject('N2');
    if (art7 == 0 && place == 0) return;
    b.element(
      'sii:NoSujeta',
      nest: () {
        if (art7 != 0) el('ImportePorArticulos7_14_Otros', amount(art7));
        if (place != 0) el('ImporteTAIReglasLocalizacion', amount(place));
      },
    );
  }

  void _exempt(List<InvoiceVatTotal> totals) => b.element(
    'sii:Exenta',
    nest: () {
      for (final t in totals) {
        b.element(
          'sii:DetalleExenta',
          nest: () {
            el('CausaExencion', op(t).exemption);
            el('BaseImponible', amount(t.netCents));
          },
        );
      }
    },
  );

  void _taxed(List<InvoiceVatTotal> totals) {
    // S1 without a reverse charge, S2 with one, S3 both on one invoice.
    final reversed = {for (final t in totals) op(t).qualification == 'S2'};
    b.element(
      'sii:NoExenta',
      nest: () {
        el(
          'TipoNoExenta',
          reversed.length > 1 ? 'S3' : (reversed.single ? 'S2' : 'S1'),
        );
        b.element(
          'sii:DesgloseIVA',
          nest: () {
            for (final t in totals) {
              b.element(
                'sii:DetalleIVA',
                nest: () {
                  el('TipoImpositivo', t.percent.toStringAsFixed(2));
                  el('BaseImponible', amount(t.netCents));
                  el('CuotaRepercutida', amount(t.vatCents));
                },
              );
            }
          },
        );
      },
    );
  }
}

String _cut(String text, int max) =>
    text.length <= max ? text : text.substring(0, max);
