// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Italian periodic return (Comunicazione liquidazioni periodiche IVA, LIPE)
// as the XML of the fornitura IVP18 the Agenzia delle Entrate publishes: one
// Modulo for the month (VP1 col. 1) or the quarter (col. 2), VP2-VP6 from the
// boxes the host filled, and VP14 (to pay or to carry) as VP6 leaves it: the
// file states no prior debt or credit, advance or interest (VP7-VP13), which
// the intermediary completes where they apply. Moved here unchanged from the
// application (#3333).
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_standards/deskilo_jurisdiction_standards.dart';
import 'package:xml/xml.dart';

/// Why the file cannot be written: the stable code the host words.
class LipeRefusal implements Exception {
  const LipeRefusal(this.code);

  final String code;

  @override
  String toString() => 'LipeRefusal: $code';
}

/// The namespace of the fornitura IVP18 (`fornituraIvp_2018_v1.xsd`).
const _ivpNamespace =
    'urn:www.agenziaentrate.gov.it:specificheTecniche:sco:ivp';

/// The XSD element each box of the quadro VP fills, in the schema's order. The
/// keys are the box keys of the form; IvaDovuta and IvaCredito are the two
/// columns of VP6.
const _vpElements = {
  'VP2': 'TotaleOperazioniAttive',
  'VP3': 'TotaleOperazioniPassive',
  'VP4': 'IvaEsigibile',
  'VP5': 'IvaDetratta',
  'VP6_1': 'IvaDovuta',
  'VP6_2': 'IvaCredito',
};

/// The codici carica of the schema (`CodiceCaricaDichiarante`).
const _declarantRoles = {
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  '11',
  '12',
  '13',
  '14',
  '15',
};

/// The LIPE of [context], or a [LipeRefusal] with the code of the first thing
/// that stops it, in the order the writer always checked them: period, partita
/// IVA, codice fiscale, declarant. The taxpayer's codice fiscale is the
/// party's registration number, its partita IVA the VAT id; a company files
/// through a declarant, who names their own codice fiscale and codice carica in
/// the facts. Amounts in euros with a decimal comma.
String lipeXml(FilingContext context) {
  final period = monthOrQuarter(context.periodStart, context.periodEnd);
  if (period == null) throw const LipeRefusal('period');
  final front = _frontespizio(context);
  final amounts = _vpAmounts(context.boxes);
  final balance = (amounts['VP6_1'] ?? 0) - (amounts['VP6_2'] ?? 0);
  final b = XmlBuilder()..processing('xml', 'version="1.0" encoding="UTF-8"');
  void el(String name, String text) => b.element('iv:$name', nest: text);
  void modulo() {
    el('NumeroModulo', '1');
    if (period.month case final month?) el('Mese', '$month');
    if (period.quarter case final q?) el('Trimestre', '$q');
    for (final MapEntry(:key, :value) in _vpElements.entries) {
      if (amounts[key] case final cents?) el(value, _euros(cents));
    }
    // VP14: the balance VP6 leaves, column 1 to pay, column 2 to carry; the
    // schema takes neither negative.
    if (balance >= 0) {
      el('ImportoDaVersare', _euros(balance));
    } else {
      el('ImportoACredito', _euros(-balance));
    }
  }

  b.element(
    'iv:Fornitura',
    namespaces: {_ivpNamespace: 'iv'},
    nest: () {
      b.element('iv:Intestazione', nest: () => el('CodiceFornitura', 'IVP18'));
      b.element(
        'iv:Comunicazione',
        attributes: {'identificativo': '00001'},
        nest: () {
          b.element('iv:Frontespizio', nest: () => front.forEach(el));
          b.element(
            'iv:DatiContabili',
            nest: () => b.element('iv:Modulo', nest: modulo),
          );
        },
      );
    },
  );
  return b.buildDocument().toXmlString(pretty: true, indent: '  ');
}

/// The frontespizio's elements in the schema's order, checked: the taxpayer's
/// codice fiscale and partita IVA, the declarant when one is named (both their
/// codice fiscale and a codice carica), the signature.
Map<String, String> _frontespizio(FilingContext context) {
  final partitaIva = _partitaIva(context.party.vatId);
  if (partitaIva == null) throw const LipeRefusal('vatNumber');
  final cf = _fiscalCode(context.party.legalId);
  if (cf == null) throw const LipeRefusal('fiscalCode');
  final facts = context.facts;
  final declarantCf = facts.declarantFiscalCode.trim().toUpperCase();
  final role = facts.declarantRole.trim();
  final hasDeclarant = declarantCf.isNotEmpty || role.isNotEmpty;
  if (hasDeclarant &&
      (_fiscalCode(declarantCf) == null || !_declarantRoles.contains(role))) {
    throw const LipeRefusal('declarant');
  }
  return {
    'CodiceFiscale': cf,
    'AnnoImposta': '${context.periodStart.year}',
    'PartitaIVA': partitaIva,
    if (hasDeclarant) 'CFDichiarante': declarantCf,
    if (hasDeclarant) 'CodiceCaricaDichiarante': role,
    'FirmaDichiarazione': '1',
  };
}

/// The cents of each box key the host filled.
Map<String, int> _vpAmounts(List<FilingBox> boxes) => {
  for (final box in boxes) ...{
    if (box.hasBase && box.baseKey.isNotEmpty) box.baseKey: box.netCents,
    if (box.hasTax && box.taxKey.isNotEmpty) box.taxKey: box.vatCents,
  },
};

/// The eleven digits of an Italian partita IVA (`DatoPI_Type`), with or without
/// its IT prefix; null for anything else.
String? _partitaIva(String vatId) {
  var id = vatId.toUpperCase().replaceAll(RegExp(r'[\s.\-]'), '');
  if (id.startsWith('IT')) id = id.substring(2);
  return RegExp(r'^[0-7]\d{10}$').hasMatch(id) ? id : null;
}

/// A codice fiscale as `DatoCF_Type` takes it: eleven digits (a company) or the
/// sixteen characters of a person; null for anything else.
String? _fiscalCode(String raw) {
  final id = raw.toUpperCase().replaceAll(RegExp(r'\s'), '');
  return RegExp(
        r'^(\d{11}|[A-Z]{6}[0-9LMNPQRSTUV]{2}[A-Z][0-9LMNPQRSTUV]{2}[A-Z]'
        r'[0-9LMNPQRSTUV]{3}[A-Z])$',
      ).hasMatch(id)
      ? id
      : null;
}

/// Euros with a decimal comma and no grouping (`DatoVN_Type`): `-12,05`.
String _euros(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  return '$sign${abs ~/ 100},${twoDigits(abs % 100)}';
}
