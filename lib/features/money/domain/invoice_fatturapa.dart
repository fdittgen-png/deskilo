// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert' show utf8;

import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';

import '../../../core/money/money_text.dart';
import 'e_invoice_totals.dart';
import 'einvoice_input.dart';
import 'invoice.dart';
import 'vat_rate.dart';
import 'vat_regime.dart';

/// #2358 — the Italian invoice as FatturaPA XML (schema FPR12/FPA12,
/// version 1.2.3), the only document the Sistema di Interscambio
/// accepts. Italy's mandate is not EN 16931: since 2019 every invoice
/// between Italian parties clears through SdI in this national syntax,
/// so an Italian seller holding only the UBL or the Factur-X has no
/// valid invoice at all.
///
/// The figures come from [eInvoiceTotalsOf] — the rule the UBL and CII
/// documents read — so the three renderings of one invoice cannot
/// disagree. Prices are VAT-inclusive in the app; FatturaPA, like the
/// norm, states lines tax-exclusive, so each line is split with
/// [vatSplit] exactly as the UBL does.
///
/// A credit note is TD04 with every amount stated as what is credited
/// (positive), the same convention as the UBL credit note.
///
/// Element order follows the XSD sequences: SdI rejects a schema-invalid
/// file before any of its own checks run.
String buildInvoiceFatturaPa(
  EInvoiceInput input, {

  /// The intermediary that transmits the file ('IT01234567890'); the
  /// seller itself when it sends directly.
  String transmitterId = '',

  /// ProgressivoInvio — the sender's own unique id for this file.
  String progressive = '',
}) => _FatturaPaWriter(input, transmitterId, progressive).write();

/// The FatturaPA document, one method per section of it.
class _FatturaPaWriter {
  _FatturaPaWriter(this.input, this.transmitterId, this.progressive)
    : totals = eInvoiceTotalsOf(
        invoice: input.invoice,
        seller: input.seller,
        buyer: input.buyer,
      );

  final EInvoiceInput input;
  final String transmitterId;
  final String progressive;
  final EInvoiceTotals totals;
  final XmlBuilder builder = XmlBuilder();

  Invoice get invoice => input.invoice;
  InvoiceParty get seller => input.seller;
  InvoiceParty get buyer => input.buyer;
  List<InvoiceVatTotal> get supplyBreakdown => totals.supplyBreakdown;
  int get taxCents =>
      supplyBreakdown.fold<int>(0, (sum, t) => sum + t.vatCents);
  bool get creditNote => invoice.isCreditNote;
  int get sign => creditNote ? -1 : 1;
  bool get publicBuyer =>
      buyer.endpointScheme == 'IT:IPA' ||
      RegExp(r'^[A-Z0-9]{6}$').hasMatch(buyer.endpointId);
  String get format => publicBuyer ? 'FPA12' : 'FPR12';
  int get grossCents =>
      sign *
      supplyBreakdown.fold<int>(0, (sum, t) => sum + t.netCents + t.vatCents);

  String amount(int minor) =>
      _twoDecimals(minorToText(minor, invoice.currency));

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

  void sede(InvoiceParty p) {
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
          transmitterId.isNotEmpty
              ? transmitterId
              : seller.vatId.isNotEmpty
              ? seller.vatId
              : seller.legalId,
          seller.country,
        );
        el('ProgressivoInvio', _progressive(progressive, invoice.number));
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
              totals.regime == VatRegime.vatRegistered ? 'RF01' : 'RF19',
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
    final natures = {
      for (final t in supplyBreakdown) ?_natura(t.category, buyer),
    };
    builder.element(
      'DatiGenerali',
      nest: () {
        builder.element(
          'DatiGeneraliDocumento',
          nest: () {
            el('TipoDocumento', creditNote ? 'TD04' : 'TD01');
            el('Divisa', invoice.currency);
            el('Data', _date(invoice.issuedAt));
            el('Numero', _basic(invoice.number, 20));
            // Stamp duty: €2 on a document above €77.47 that carries no
            // VAT because the operation is exempt or outside its scope —
            // not on exports, intra-EU supplies or a reverse charge.
            if (taxCents == 0 &&
                grossCents > 7747 &&
                natures.any(_bolloNatures.contains)) {
              builder.element(
                'DatiBollo',
                nest: () {
                  el('BolloVirtuale', 'SI');
                  el('ImportoBollo', '2.00');
                },
              );
            }
            el('ImportoTotaleDocumento', amount(grossCents));
          },
        );
        if (invoice.replacesNumber.isNotEmpty) {
          builder.element(
            'DatiFattureCollegate',
            nest: () {
              el('IdDocumento', _basic(invoice.replacesNumber, 20));
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
        for (final (i, line) in totals.supplies.indexed) {
          detailLine(i, line);
        }
        for (final total in supplyBreakdown) {
          vatSummary(total);
        }
      },
    );
  }

  void detailLine(int index, InvoiceLine line) {
    final lineNet = sign * vatSplit(line.amountCents, line.vatPercent).netCents;
    // The same divisibility rule as the UBL: quantity × price must
    // be the line total SdI recomputes.
    final units = line.quantity > 1 && lineNet.abs() % line.quantity == 0
        ? line.quantity
        : 1;
    final lineCategory = line.vatCategory.isNotEmpty
        ? line.vatCategory
        : line.vatPercent > 0
        ? 'S'
        : totals.category;
    builder.element(
      'DettaglioLinee',
      nest: () {
        el('NumeroLinea', '${index + 1}');
        el('Descrizione', _latin(input.lineText(line), 1000, '-'));
        if (units > 1) el('Quantita', '$units.00');
        el('PrezzoUnitario', amount(lineNet ~/ units));
        el('PrezzoTotale', amount(lineNet));
        el('AliquotaIVA', _rate(line.vatPercent));
        if (line.vatPercent == 0) {
          el('Natura', _natura(lineCategory, buyer) ?? 'N2.2');
        }
      },
    );
  }

  void vatSummary(InvoiceVatTotal total) {
    final natura = total.percent == 0
        ? _natura(total.category, buyer) ?? 'N2.2'
        : null;
    builder.element(
      'DatiRiepilogo',
      nest: () {
        el('AliquotaIVA', _rate(total.percent));
        if (natura != null) el('Natura', natura);
        el('ImponibileImporto', amount(sign * total.netCents));
        el('Imposta', amount(sign * total.vatCents));
        if (natura == null) el('EsigibilitaIVA', 'I');
        if (natura != null && totals.exemptionText.isNotEmpty) {
          el('RiferimentoNormativo', _latin(totals.exemptionText, 100, '-'));
        }
      },
    );
  }

  /// Only an invoice is paid; a credit note settles by refund.
  void payment() {
    final payable = invoice.totalCents;
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
            final dueDate = input.dueDate;
            if (dueDate != null) {
              el('DataScadenzaPagamento', _date(dueDate));
            }
            el('ImportoPagamento', amount(payable));
            final account = input.iban.replaceAll(' ', '').toUpperCase();
            if (RegExp(r'^[A-Z]{2}\d{2}[A-Z0-9]{11,30}$').hasMatch(account)) {
              el('IBAN', account);
            }
          },
        );
      },
    );
  }
}

/// The Natura that stamp duty applies to: exempt or outside-scope
/// operations, not exports (N3.1), intra-EU supplies (N3.2) or a reverse
/// charge (N6.x, N2.1).
const _bolloNatures = {'N1', 'N2.2', 'N3.5', 'N4'};

/// Why a 0 % line carries no VAT, in SdI's codes. Null for a taxed line.
String? _natura(String category, InvoiceParty buyer) => switch (category) {
  'O' => 'N2.2',
  'E' => 'N4',
  'Z' => 'N3.5',
  'K' => 'N3.2',
  'G' => 'N3.1',
  'AE' => buyer.country.toUpperCase() == 'IT' ? 'N6.9' : 'N2.1',
  _ => null,
};

/// SdI's routing code: the recipient's own code, '0000000' when it is
/// reached by PEC or through its fiscal drawer, 'XXXXXXX' abroad.
String _recipientCode(InvoiceParty buyer, {required bool publicBuyer}) {
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

/// ProgressivoInvio: at most ten basic-latin characters, unique per
/// sender. The invoice number already is unique; a long one is hashed.
String _progressive(String given, String number) {
  final clean = (given.isNotEmpty ? given : number).replaceAll(
    RegExp(r'[^A-Za-z0-9]'),
    '',
  );
  if (clean.isNotEmpty && clean.length <= 10) return clean;
  // The SHA-256 of the number: stable across runs and identical on the
  // web, where integers above 2^53 do not exist.
  return sha256
      .convert(utf8.encode(number))
      .toString()
      .substring(0, 10)
      .toUpperCase();
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
