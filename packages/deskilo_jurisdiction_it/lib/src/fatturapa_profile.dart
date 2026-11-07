// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3337 (of #3328) -- the Italian invoice as FatturaPA XML (schema FPR12/FPA12,
// version 1.2.3), the only document the Sistema di Interscambio accepts, as an
// invoice profile behind the jurisdiction contract. It moved here from the
// application with its bytes unchanged (the sample validators and the unit
// tests are the proof).
//
// Italy's mandate is not EN 16931: since 2019 every invoice between Italian
// parties clears through SdI in this national syntax, so an Italian seller
// holding only the UBL or the Factur-X has no valid invoice at all.
//
// The figures come from the host's context -- the totals rule the UBL and CII
// documents read -- so the renderings of one invoice cannot disagree. A credit
// note is TD04 with every amount stated as what is credited (positive), the
// same convention as the UBL credit note. Element order follows the XSD
// sequences: SdI rejects a schema-invalid file before any of its own checks.
import 'dart:convert' show utf8;

import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:xml/xml.dart';

/// Bumped in the same commit as any change of the bytes this profile writes.
const itFatturaPaImplementationVersion = '1';

/// The FatturaPA schema version the profile follows.
const itFatturaPaFormatVersion = '1.2.3';

/// The id of the format, as `EInvoiceFormat.fatturaPa.name` spells it.
const fatturaPaFormatId = 'fatturaPa';

/// The FatturaPA invoice profile of Italy. Refuses nothing today: the writer
/// never refused, and the bytes are pinned (SdI's own checks follow).
class ItFatturaPaProfile implements InvoiceProfileContribution {
  const ItFatturaPaProfile();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'it.invoice_profile.fatturapa',
    implementationVersion: itFatturaPaImplementationVersion,
    contractVersion: invoiceProfileContractVersion,
    formatVersion: itFatturaPaFormatVersion,
    capabilityId: 'invoice_profile.$fatturaPaFormatId',
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
      bytes: utf8.encode(_FatturaPaWriter(context).write()),
      mediaType: 'application/xml',
      fileName: '${context.progressive}.xml',
      provenance: descriptor.toProvenance(),
    );
  }
}

/// The FatturaPA document, one method per section of it.
class _FatturaPaWriter {
  _FatturaPaWriter(this.c);

  final InvoiceDocumentContext c;
  final XmlBuilder builder = XmlBuilder();

  DocumentParty get seller => c.seller;
  DocumentParty get buyer => c.buyer;
  List<DocumentVatTotal> get supplyBreakdown => c.vatBreakdown;
  bool get creditNote => c.creditNote;
  int get sign => creditNote ? -1 : 1;
  bool get publicBuyer =>
      buyer.endpointScheme == 'IT:IPA' ||
      RegExp(r'^[A-Z0-9]{6}$').hasMatch(buyer.endpointId);
  String get format => publicBuyer ? 'FPA12' : 'FPR12';
  int get grossCents =>
      sign *
      supplyBreakdown.fold<int>(0, (sum, t) => sum + t.netMinor + t.vatMinor);

  String amount(int minor) => _twoDecimals(_decimal(minor, c.currencyExponent));

  void el(String name, String text) =>
      builder.element(name, nest: () => builder.text(text));

  String write() {
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'p:FatturaElettronica',
      nest: () {
        builder
          ..namespace(
            'http://ivaservizi.agenziaentrate.gov.it/docs/xsd/fatture/v1.2',
            'p',
          )
          ..namespace('http://www.w3.org/2000/09/xmldsig#', 'ds')
          ..attribute('versione', format);
        builder.element(
          'FatturaElettronicaHeader',
          nest: () {
            transmission();
            supplier();
            customer();
          },
        );
        builder.element(
          'FatturaElettronicaBody',
          nest: () {
            generalData();
            goodsAndServices();
            payment();
          },
        );
      },
    );
    return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
  }

  void idFiscale(String name, String vatId, String country) {
    final (paese, codice) = _splitVatId(vatId, country);
    builder.element(
      name,
      nest: () {
        el('IdPaese', paese);
        el('IdCodice', codice);
      },
    );
  }

  void sede(DocumentParty p) {
    final italian = p.country.toUpperCase() == 'IT';
    builder.element(
      'Sede',
      nest: () {
        el('Indirizzo', _latin(p.street.replaceAll('\n', ', '), 60, '-'));
        el(
          'CAP',
          RegExp(r'^\d{5}$').hasMatch(p.postalCode.trim())
              ? p.postalCode.trim()
              : '00000',
        );
        el('Comune', _latin(p.city, 60, '-'));
        final province = p.subdivision.toUpperCase();
        if (italian && RegExp(r'^[A-Z]{2}$').hasMatch(province)) {
          el('Provincia', province);
        }
        el('Nazione', p.country.toUpperCase());
      },
    );
  }

  void transmission() {
    builder.element(
      'DatiTrasmissione',
      nest: () {
        idFiscale(
          'IdTrasmittente',
          c.transmitterId.isNotEmpty
              ? c.transmitterId
              : seller.vatId.isNotEmpty
              ? seller.vatId
              : seller.legalId,
          seller.country,
        );
        el('ProgressivoInvio', c.progressive);
        el('FormatoTrasmissione', format);
        final pec = buyer.endpointId.contains('@');
        el('CodiceDestinatario', _recipientCode(buyer, publicBuyer: publicBuyer));
        if (pec) el('PECDestinatario', buyer.endpointId.trim());
      },
    );
  }

  void supplier() {
    builder.element(
      'CedentePrestatore',
      nest: () {
        builder.element(
          'DatiAnagrafici',
          nest: () {
            idFiscale(
              'IdFiscaleIVA',
              seller.vatId.isNotEmpty ? seller.vatId : seller.legalId,
              seller.country,
            );
            if (_fiscalCode(seller.legalId) case final cf?) {
              el('CodiceFiscale', cf);
            }
            builder.element(
              'Anagrafica',
              nest: () {
                el('Denominazione', _latin(seller.name, 80, '-'));
              },
            );
            // RF01 ordinary; RF19 the flat-rate regime (forfettario), the
            // Italian reading of a seller that charges no VAT.
            el(
              'RegimeFiscale',
              c.sellerVatRegistered ? 'RF01' : 'RF19',
            );
          },
        );
        sede(seller);
      },
    );
  }

  void customer() {
    builder.element(
      'CessionarioCommittente',
      nest: () {
        builder.element(
          'DatiAnagrafici',
          nest: () {
            if (buyer.vatId.isNotEmpty) {
              idFiscale('IdFiscaleIVA', buyer.vatId, buyer.country);
            }
            if (_fiscalCode(buyer.legalId) case final cf?) {
              el('CodiceFiscale', cf);
            }
            builder.element(
              'Anagrafica',
              nest: () {
                el('Denominazione', _latin(buyer.name, 80, '-'));
              },
            );
          },
        );
        sede(buyer);
      },
    );
  }

  void generalData() {
    builder.element(
      'DatiGenerali',
      nest: () {
        builder.element(
          'DatiGeneraliDocumento',
          nest: () {
            el('TipoDocumento', creditNote ? 'TD04' : 'TD01');
            el('Divisa', c.currency);
            el('Data', _date(c.issuedAt));
            el('Numero', _basic(c.number, 20));
            // Stamp duty on a document that carries no VAT because its
            // operation is exempt or outside the scope (`stamp_duty.dart`).
            if (c.stampDutyMinor case final duty?) {
              builder.element(
                'DatiBollo',
                nest: () {
                  el('BolloVirtuale', 'SI');
                  el('ImportoBollo', amount(duty));
                },
              );
            }
            el('ImportoTotaleDocumento', amount(grossCents));
          },
        );
        if (c.replacesNumber.isNotEmpty) {
          builder.element(
            'DatiFattureCollegate',
            nest: () {
              el('IdDocumento', _basic(c.replacesNumber, 20));
            },
          );
        }
      },
    );
  }

  void goodsAndServices() {
    builder.element(
      'DatiBeniServizi',
      nest: () {
        for (final (i, line) in c.lines.indexed) {
          detailLine(i, line);
        }
        for (final total in supplyBreakdown) {
          vatSummary(total);
        }
      },
    );
  }

  void detailLine(int index, DocumentLine line) {
    final lineNet = sign * line.netMinor;
    // The same divisibility rule as the UBL: quantity × price must
    // be the line total SdI recomputes.
    final units = line.quantity > 1 && lineNet.abs() % line.quantity == 0
        ? line.quantity
        : 1;
    final lineCategory = line.vatCategory.isNotEmpty
        ? line.vatCategory
        : line.vatPercent > 0
        ? 'S'
        : c.category;
    builder.element(
      'DettaglioLinee',
      nest: () {
        el('NumeroLinea', '${index + 1}');
        el('Descrizione', _latin(line.text, 1000, '-'));
        if (units > 1) el('Quantita', '$units.00');
        el('PrezzoUnitario', amount(lineNet ~/ units));
        el('PrezzoTotale', amount(lineNet));
        el('AliquotaIVA', _rate(line.vatPercent));
        if (line.vatPercent == 0) {
          el('Natura', fatturaPaNatura(lineCategory, buyerCountry: buyer.country) ?? 'N2.2');
        }
      },
    );
  }

  void vatSummary(DocumentVatTotal total) {
    final natura = total.percent == 0
        ? fatturaPaNatura(total.category, buyerCountry: buyer.country) ?? 'N2.2'
        : null;
    builder.element(
      'DatiRiepilogo',
      nest: () {
        el('AliquotaIVA', _rate(total.percent));
        if (natura != null) el('Natura', natura);
        el('ImponibileImporto', amount(sign * total.netMinor));
        el('Imposta', amount(sign * total.vatMinor));
        if (natura == null) el('EsigibilitaIVA', 'I');
        if (natura != null && c.exemptionText.isNotEmpty) {
          el('RiferimentoNormativo', _latin(c.exemptionText, 100, '-'));
        }
      },
    );
  }

  /// Only an invoice is paid; a credit note settles by refund.
  void payment() {
    final payable = c.payableMinor;
    if (payable <= 0) return;
    builder.element(
      'DatiPagamento',
      nest: () {
        // TP02 — payment in full; MP05 — credit transfer.
        el('CondizioniPagamento', 'TP02');
        builder.element(
          'DettaglioPagamento',
          nest: () {
            el('ModalitaPagamento', 'MP05');
            final dueDate = c.dueDate;
            if (dueDate != null) {
              el('DataScadenzaPagamento', _date(dueDate));
            }
            el('ImportoPagamento', amount(payable));
            final account = c.iban.replaceAll(' ', '').toUpperCase();
            if (RegExp(r'^[A-Z]{2}\d{2}[A-Z0-9]{11,30}$').hasMatch(account)) {
              el('IBAN', account);
            }
          },
        );
      },
    );
  }
}

/// Why a 0 % line carries no VAT, in SdI's codes (the FatturaPA and the
/// registro IVA read the same one). Null for a taxed line.
String? fatturaPaNatura(String category, {required String buyerCountry}) => switch (category) {
  'O' => 'N2.2',
  'E' => 'N4',
  'Z' => 'N3.5',
  'K' => 'N3.2',
  'G' => 'N3.1',
  'AE' => buyerCountry.toUpperCase() == 'IT' ? 'N6.9' : 'N2.1',
  _ => null,
};

/// SdI's routing code: the recipient's own code, '0000000' when it is
/// reached by PEC or through its fiscal drawer, 'XXXXXXX' abroad.
String _recipientCode(DocumentParty buyer, {required bool publicBuyer}) {
  final code = buyer.endpointId.trim().toUpperCase();
  if (publicBuyer) return code;
  if (buyer.country.toUpperCase() != 'IT') return 'XXXXXXX';
  if (RegExp(r'^[A-Z0-9]{7}$').hasMatch(code)) return code;
  return '0000000';
}

/// 'IT01234567890' → ('IT', '01234567890'); a bare number takes the
/// party's country.
(String, String) _splitVatId(String vatId, String country) {
  final id = vatId.replaceAll(RegExp(r'[\s.\-]'), '').toUpperCase();
  final prefixed = RegExp(r'^([A-Z]{2})(.+)$').firstMatch(id);
  if (prefixed != null) return (prefixed.group(1)!, prefixed.group(2)!);
  return (country.toUpperCase(), id.isEmpty ? '0' : id);
}

/// The codice fiscale when the legal id has its shape (11 digits for a
/// company, 16 characters for a person).
String? _fiscalCode(String legalId) {
  final id = legalId.replaceAll(RegExp(r'\s'), '').toUpperCase();
  return RegExp(r'^[A-Z0-9]{11,16}$').hasMatch(id) ? id : null;
}

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

String _date(DateTime value) => value.toIso8601String().split('T').first;

/// RateType: always two decimals ('22.00', '0.00').
String _rate(double percent) => percent.toStringAsFixed(2);

String _twoDecimals(String text) => text.contains('.') ? text : '$text.00';

/// Latin-1 text on one line, cut to [max]; [empty] when nothing is left
/// (the schema refuses an empty element).
String _latin(String text, int max, String empty) {
  final line = String.fromCharCodes(
    text
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .runes
        .map((r) => r <= 0xFF ? r : 0x3F),
  );
  if (line.isEmpty) return empty;
  return line.length > max ? line.substring(0, max) : line;
}

/// Basic-latin only (Numero, IdDocumento), cut to [max].
String _basic(String text, int max) {
  final line = String.fromCharCodes(
    text.trim().runes.map((r) => r < 0x80 && r >= 0x20 ? r : 0x3F),
  );
  return line.length > max ? line.substring(0, max) : line;
}
