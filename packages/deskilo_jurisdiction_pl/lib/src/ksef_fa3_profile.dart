// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the Polish structured invoice, FA(3), the only schema the
// National e-Invoice System (KSeF) takes since February 2026, as an invoice
// profile behind the jurisdiction contract. It moved here from the invoice
// model with its bytes unchanged (the sample validators and the unit tests
// are the proof).
//
// Poland's mandate is a clearance one like Italy's: an invoice exists when KSeF
// has numbered it, so the EN 16931 files this app also writes are not a
// substitute.
//
// FA(3) is not a line-by-line mirror of EN 16931. It states the tax base and
// the tax per rate BAND in fixed fields (P_13_1/P_14_1 for the basic rate,
// P_13_2/P_14_2 for the first reduced one...) and a 0 % or untaxed supply in
// the field that names WHY it is untaxed. The bands are filled from the same
// VAT breakdown the other syntaxes read, so the documents of one invoice
// agree. A correction (KOR) states the CHANGE: its amounts stay negative,
// unlike the UBL credit note, which states what is credited.
import 'dart:convert' show utf8;

import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:xml/xml.dart';

const _namespace = 'http://crd.gov.pl/wzor/2025/06/25/13775/';

/// Bumped in the same commit as any change of the bytes this profile writes.
const plKsefFa3ImplementationVersion = '1';

/// The FA(3) schema version the profile follows.
const plKsefFa3FormatVersion = 'FA (3) 1-0E';

/// The id of the format, as `EInvoiceFormat.ksefFa3.name` spells it.
const ksefFa3FormatId = 'ksefFa3';

/// SystemInfo -- the producing system, as KSeF records it.
const _systemInfo = 'DesKilo';

/// The KSeF FA(3) invoice profile of Poland. Refuses nothing today: the writer
/// never refused, and the bytes are pinned (KSeF's own checks follow).
class PlKsefFa3Profile implements InvoiceProfileContribution {
  const PlKsefFa3Profile();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'pl.invoice_profile.ksef_fa3',
    implementationVersion: plKsefFa3ImplementationVersion,
    contractVersion: invoiceProfileContractVersion,
    formatVersion: plKsefFa3FormatVersion,
    capabilityId: 'invoice_profile.$ksefFa3FormatId',
  );

  @override
  ({ValidatedInvoiceDocument? document, ValidationResult result}) validate(
    InvoiceDocumentContext context,
  ) => (
    document: ValidatedInvoiceDocument(context),
    result: const ValidationResult.ok(),
  );

  @override
  GeneratedArtifact build(ValidatedInvoiceDocument document) {
    final context = document.context;
    if (!validate(context).result.isOk) {
      throw StateError('a document this profile would refuse');
    }
    return GeneratedArtifact(
      bytes: utf8.encode(_KsefWriter(context).write()),
      mediaType: 'application/xml',
      fileName: '${context.progressive}.xml',
      provenance: descriptor.toProvenance(),
    );
  }
}

/// The FA(3) document, one method per section of it.
class _KsefWriter {
  _KsefWriter(this.c) {
    // Band → (net, tax). Iterated in schema order below.
    for (final total in c.vatBreakdown) {
      final band = _band(total.percent, total.category, buyer);
      final before = bands[band] ?? (net: 0, tax: 0);
      bands[band] = (
        net: before.net + total.netMinor,
        tax: before.tax + total.vatMinor,
      );
    }
  }

  final InvoiceDocumentContext c;
  final XmlBuilder builder = XmlBuilder();
  final Map<String, ({int net, int tax})> bands = {};

  DocumentParty get seller => c.seller;
  DocumentParty get buyer => c.buyer;
  bool get correction => c.creditNote;

  String amount(int minor) => _decimal(minor, c.currencyExponent);

  void el(String name, String text) =>
      builder.element(name, nest: () => builder.text(text));

  String write() {
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'Faktura',
      nest: () {
        builder.namespace(_namespace);
        header();
        seller1();
        buyer2();
        invoiceBody();
      },
    );
    return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
  }

  void address(DocumentParty p) {
    builder.element(
      'Adres',
      nest: () {
        el('KodKraju', p.country.toUpperCase());
        el('AdresL1', _token(p.street.replaceAll('\n', ', '), 512, '-'));
        final line2 = [
          p.postalCode.trim(),
          p.city.trim(),
        ].where((s) => s.isNotEmpty).join(' ');
        if (line2.isNotEmpty) el('AdresL2', _token(line2, 512, '-'));
      },
    );
  }

  void header() {
    builder.element(
      'Naglowek',
      nest: () {
        builder.element(
          'KodFormularza',
          nest: () {
            builder
              ..attribute('kodSystemowy', 'FA (3)')
              ..attribute('wersjaSchemy', '1-0E')
              ..text('FA');
          },
        );
        el('WariantFormularza', '3');
        el('DataWytworzeniaFa', _dateTime(c.issuedAt));
        el('SystemInfo', _token(_systemInfo, 256, 'DesKilo'));
      },
    );
  }

  void seller1() {
    builder.element(
      'Podmiot1',
      nest: () {
        builder.element(
          'DaneIdentyfikacyjne',
          nest: () {
            el(
              'NIP',
              _nip(seller.vatId.isNotEmpty ? seller.vatId : seller.legalId),
            );
            el('Nazwa', _token(seller.name, 512, '-'));
          },
        );
        address(seller);
      },
    );
  }

  void buyer2() {
    builder.element(
      'Podmiot2',
      nest: () {
        builder.element(
          'DaneIdentyfikacyjne',
          nest: () {
            switch (_buyerId(buyer, c)) {
              case _Nip(:final nip):
                el('NIP', nip);
              case _EuVat(:final country, :final number):
                el('KodUE', country);
                el('NrVatUE', number);
              case _Foreign(:final country, :final number):
                el('KodKraju', country);
                el('NrID', number);
              case _NoId():
                el('BrakID', '1');
            }
            el('Nazwa', _token(buyer.name, 512, '-'));
          },
        );
        address(buyer);
        // JST / GV: 2 = the buyer is neither a local-government unit nor a
        // VAT group member — the fields FA(3) made mandatory.
        el('JST', '2');
        el('GV', '2');
      },
    );
  }

  void invoiceBody() {
    builder.element(
      'Fa',
      nest: () {
        el('KodWaluty', c.currency);
        el('P_1', _date(c.issuedAt));
        el('P_2', _token(c.number, 256, '-'));
        billingPeriod();
        bandTotals();
        annotations();
        el('RodzajFaktury', correction ? 'KOR' : 'VAT');
        correctedInvoice();
        for (final (i, line) in c.lines.indexed) {
          rowOf(i, line);
        }
        payment();
      },
    );
  }

  void billingPeriod() {
    final period = _periodDates(c.period);
    if (period == null) return;
    builder.element(
      'OkresFa',
      nest: () {
        el('P_6_Od', period.start);
        el('P_6_Do', period.end);
      },
    );
  }

  void bandTotals() {
    for (final band in ['1', '2', '3', '4']) {
      final figures = bands[band];
      if (figures == null) continue;
      el('P_13_$band', amount(figures.net));
      el('P_14_$band', amount(figures.tax));
    }
    for (final band in ['6_1', '6_2', '6_3', '7', '8', '9', '10']) {
      final figures = bands[band];
      if (figures != null) el('P_13_$band', amount(figures.net));
    }
    final grossCents = c.vatBreakdown.fold<int>(
      0,
      (sum, t) => sum + t.netMinor + t.vatMinor,
    );
    el('P_15', amount(grossCents));
  }

  void annotations() {
    final exempt = bands.containsKey('7');
    final domesticReverse = bands.containsKey('10');
    builder.element(
      'Adnotacje',
      nest: () {
        el('P_16', '2'); // no cash accounting
        el('P_17', '2'); // not self-billed
        el('P_18', domesticReverse ? '1' : '2'); // reverse charge
        el('P_18A', '2'); // no split payment
        builder
          ..element(
            'Zwolnienie',
            nest: () {
              if (exempt) {
                el('P_19', '1');
                el(
                  'P_19A',
                  _token(c.exemptionText, 256, 'Art. 43 ust. 1'),
                );
              } else {
                el('P_19N', '1');
              }
            },
          )
          ..element(
            'NoweSrodkiTransportu',
            nest: () {
              el('P_22N', '1');
            },
          );
        el('P_23', '2'); // not a simplified triangular procedure
        builder.element(
          'PMarzy',
          nest: () {
            el('P_PMarzyN', '1');
          },
        );
      },
    );
  }

  void correctedInvoice() {
    if (!correction || c.replacesNumber.isEmpty) return;
    builder.element(
      'DaneFaKorygowanej',
      nest: () {
        el(
          'DataWystFaKorygowanej',
          _date(c.correctedIssuedAt ?? c.issuedAt),
        );
        el('NrFaKorygowanej', _token(c.replacesNumber, 256, '-'));
        el('NrKSeFN', '1'); // the corrected invoice had no KSeF number
      },
    );
  }

  void rowOf(int index, DocumentLine line) {
    final lineNet = line.netMinor;
    final units = line.quantity > 1 && lineNet.abs() % line.quantity == 0
        ? line.quantity
        : 1;
    final lineCategory = line.vatCategory.isNotEmpty
        ? line.vatCategory
        : line.vatPercent > 0
        ? 'S'
        : c.category;
    builder.element(
      'FaWiersz',
      nest: () {
        el('NrWierszaFa', '${index + 1}');
        el('P_7', _token(line.text, 512, '-'));
        el('P_8A', 'szt.');
        el('P_8B', '$units');
        el('P_9A', amount(lineNet ~/ units));
        el('P_11', amount(lineNet));
        if (_rateCode(line.vatPercent, lineCategory, buyer) case final code?) {
          el('P_12', code);
        }
      },
    );
  }

  void payment() {
    final payable = c.payableMinor;
    final dueDate = c.dueDate;
    final account = c.iban.replaceAll(' ', '').toUpperCase();
    if (payable <= 0 || (dueDate == null && account.isEmpty)) return;
    builder.element(
      'Platnosc',
      nest: () {
        if (dueDate != null) {
          builder.element(
            'TerminPlatnosci',
            nest: () {
              el('Termin', _date(dueDate));
            },
          );
        }
        el('FormaPlatnosci', '6'); // credit transfer
        if (account.length >= 10 && account.length <= 34) {
          builder.element(
            'RachunekBankowy',
            nest: () {
              el('NrRB', account);
            },
          );
        }
      },
    );
  }
}

/// Which FA(3) field carries a breakdown entry: the rate bands 1–4 for
/// taxed supplies, otherwise the field that says why there is no tax.
String _band(double percent, String category, DocumentParty buyer) {
  if (percent > 0) {
    return switch (percent) {
      >= 22 => '1',
      >= 7 => '2',
      >= 5 => '3',
      _ => '4',
    };
  }
  return switch (category) {
    'Z' => '6_1',
    'K' => '6_2',
    'G' => '6_3',
    'E' => '7',
    'AE' => buyer.country.toUpperCase() == 'PL' ? '10' : '9',
    _ => '8',
  };
}

/// P_12 — the line's rate, or the code for why it carries none. Null for
/// a rate the enumeration does not know.
String? _rateCode(double percent, String category, DocumentParty buyer) {
  if (percent > 0) {
    final whole = percent.round();
    const known = {23, 22, 8, 7, 5, 4, 3};
    return whole == percent && known.contains(whole) ? '$whole' : null;
  }
  return switch (category) {
    'Z' => '0 KR',
    'K' => '0 WDT',
    'G' => '0 EX',
    'E' => 'zw',
    'AE' => buyer.country.toUpperCase() == 'PL' ? 'oo' : 'np II',
    _ => 'np I',
  };
}

sealed class _BuyerId {}

class _Nip extends _BuyerId {
  _Nip(this.nip);
  final String nip;
}

class _EuVat extends _BuyerId {
  _EuVat(this.country, this.number);
  final String country;
  final String number;
}

class _Foreign extends _BuyerId {
  _Foreign(this.country, this.number);
  final String country;
  final String number;
}

class _NoId extends _BuyerId {}

/// Northern Ireland's VAT prefix: not a member state, but KSeF files its
/// buyers' VAT numbers as an EU number, as the Union does for goods.
const _northernIreland = 'XI';

/// Whether KSeF files [code] as an EU VAT prefix: a member state of the
/// reference data in the context, an alias row of it resolved (Greece's `EL`
/// included), or Northern Ireland.
bool _isEuPrefix(String code, InvoiceDocumentContext c) =>
    code == _northernIreland ||
    c.euMemberStates.contains(c.euCodeAliases[code] ?? code);

/// A Polish buyer is identified by its NIP, another EU business by its
/// VAT number, anyone else by what they have — or BrakID.
_BuyerId _buyerId(DocumentParty buyer, InvoiceDocumentContext c) {
  final country = buyer.country.toUpperCase();
  final vat = buyer.vatId.replaceAll(RegExp(r'[\s.\-]'), '').toUpperCase();
  if (country == 'PL') {
    final nip = _nip(vat.isNotEmpty ? vat : buyer.legalId);
    return RegExp(r'^[1-9]((\d[1-9])|([1-9]\d))\d{7}$').hasMatch(nip)
        ? _Nip(nip)
        : _NoId();
  }
  if (vat.isNotEmpty) {
    final match = RegExp(r'^([A-Z]{2})([0-9A-Z+*]{1,12})$').firstMatch(vat);
    final code = match?.group(1) == 'GR' ? 'EL' : match?.group(1);
    if (match != null && code != null && _isEuPrefix(code, c)) {
      return _EuVat(code, match.group(2)!);
    }
    return _Foreign(country, vat.length > 50 ? vat.substring(0, 50) : vat);
  }
  return _NoId();
}

/// 'PL 526-000-12-46' → '5260001246'.
String _nip(String id) {
  final digits = id.toUpperCase().replaceFirst(RegExp(r'^PL'), '');
  return digits.replaceAll(RegExp(r'\D'), '');
}

String _date(DateTime value) => value.toIso8601String().split('T').first;

/// xsd:dateTime in UTC, seconds precision.
String _dateTime(DateTime value) =>
    '${value.toUtc().toIso8601String().split('.').first.replaceAll('Z', '')}Z';

/// 'yyyy-MM' → the month's first and last calendar day.
({String start, String end})? _periodDates(String? period) {
  final match = RegExp(r'^(\d{4})-(\d{2})').firstMatch(period ?? '');
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final first = DateTime(year, month);
  final last = DateTime(year, month + 1, 0);
  return (start: _date(first), end: _date(last));
}

/// An xsd:token value: one line, cut to [max], [empty] when blank.
String _token(String text, int max, String empty) {
  final line = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (line.isEmpty) return empty;
  return line.length > max ? line.substring(0, max) : line;
}

/// [minor] in a currency of [exponent] decimals, as the schema writes it.
String _decimal(int minor, int exponent) {
  final sign = minor < 0 ? '-' : '';
  final abs = minor.abs();
  if (exponent == 0) return '$sign$abs';
  var per = 1;
  for (var i = 0; i < exponent; i++) {
    per *= 10;
  }
  final fraction = (abs % per).toString().padLeft(exponent, '0');
  return '$sign${abs ~/ per}.$fraction';
}
