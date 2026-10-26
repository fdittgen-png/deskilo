// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The registers and the annual summary a Spanish or an Italian space saves
// beside its returns, as files: the libro registro de facturas expedidas
// (AEAT XLSX), the SII message, the registro fatture emesse (CSV), the
// Modelo 390 / dichiarazione IVA annuale as a sheet. Each answers null when
// the period holds nothing to write; nothing here transmits.
import 'dart:convert' show utf8;
import 'dart:typed_data';

import '../../../core/files/xlsx.dart';
import '../../../core/time/date_text.dart';
import '../../../core/vat/tax_reference.dart';
import '../domain/invoice.dart';
import '../domain/vat_annual_summary.dart';
import '../domain/vat_declaration.dart';
import '../domain/vat_filing_files.dart';
import '../domain/vat_register_es.dart';
import '../domain/vat_register_es_347.dart';
import '../domain/vat_register_es_sii.dart';
import '../domain/vat_register_it.dart';

typedef VatRegisterFile = ({String fileName, Uint8List bytes});

class VatRegisterFiles {
  const VatRegisterFiles({
    required this.party,
    required this.invoices,
    required this.declarations,
    required this.reference,
    this.monthly = false,
  });

  /// The space that keeps the registers, or null before it is loaded.
  final VatFilingParty? party;

  /// Reads the issued documents and the returns when a file is asked for.
  final Future<List<Invoice>> Function() invoices;
  final Future<List<VatDeclaration>> Function() declarations;

  /// The workspace's tax reference, or null before its context is ready.
  final TaxReferenceSet? reference;

  /// Whether the space files monthly (a REDEME filer): the libro's period
  /// is then the month, else the quarter.
  final bool monthly;

  VatFilingParty get _party =>
      party ?? (throw StateError('no workspace loaded'));

  /// The libro of the year up to [end] (its last day included): Pre303
  /// reads the book of the year so far, never one quarter. [activity] is
  /// the AEAT's code, type and IAE heading of the lines.
  Future<VatRegisterFile?> esLibro({
    required DateTime end,
    required String activity,
  }) async {
    final party = _party;
    final docs = registerDocuments(
      await invoices(),
      from: DateTime(end.year),
      to: _after(end),
    );
    if (docs.isEmpty) return null;
    final nif = party.vatId.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    return (
      // The AEAT's name: exercise, NIF, the book's type (E), the holder.
      fileName:
          '${end.year}${nif.startsWith('ES') ? nif.substring(2) : nif}E'
          '${party.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')}.xlsx',
      bytes: buildXlsx([
        esLibroExpedidas(docs, activity: activity, monthly: monthly),
      ]),
    );
  }

  /// The SII message of the documents of `[start, end]`. Throws
  /// [VatFilingFileException] when the space's NIF is not one.
  Future<VatRegisterFile?> esSii({
    required DateTime start,
    required DateTime end,
  }) async {
    final party = _party;
    final docs = registerDocuments(
      await invoices(),
      from: start,
      to: _after(end),
    );
    if (docs.isEmpty) return null;
    final xml = siiFacturasEmitidasXml(
      docs,
      vatId: party.vatId,
      name: party.name,
    );
    return (
      fileName: 'sii-facturas-emitidas-${isoDay(start)}.xml',
      bytes: Uint8List.fromList(utf8.encode(xml)),
    );
  }

  /// The modelo 347 list of [year]: the customers above the line. Throws
  /// [VatFilingFileException] for a space in SII ([immediateSupply]).
  Future<VatRegisterFile?> es347({
    required int year,
    required bool immediateSupply,
  }) async {
    final all = await invoices();
    final docs = registerDocuments(
      all,
      from: DateTime(year),
      to: DateTime(year + 1),
    );
    final data = reference;
    if (data == null) return null;
    final list = modelo347Lines(
      docs,
      year: year,
      reference: data,
      immediateSupply: immediateSupply,
    );
    if (list == null || list.lines.isEmpty) return null;
    return (
      fileName: 'modelo-347-$year.csv',
      bytes: Uint8List.fromList(
        utf8.encode(modelo347Csv(list.lines, currency: list.currency)),
      ),
    );
  }

  /// The registro fatture emesse of `[start, end]`.
  Future<VatRegisterFile?> itRegistro({
    required DateTime start,
    required DateTime end,
  }) async {
    final all = await invoices();
    final to = _after(end);
    if (registerDocuments(all, from: start, to: to).isEmpty) return null;
    return (
      fileName: 'registro-fatture-emesse-${isoDay(start)}.csv',
      bytes: Uint8List.fromList(
        utf8.encode(registroFattureEmesseCsv(all, from: start, to: to)),
      ),
    );
  }

  /// The annual summary of [year] as a sheet, its columns named [header].
  Future<VatRegisterFile?> annualSummary({
    required int year,
    required List<String> header,
  }) async {
    final party = _party;
    final returns = await declarations();
    final summary = vatAnnualSummary(party.countryCode, year, returns);
    if (summary == null) return null;
    return (
      fileName: 'vat-annual-summary-$year.xlsx',
      bytes: buildXlsx(
        vatAnnualSummarySheets(
          title: summary.title,
          boxes: summary.boxes,
          currency: summary.currency,
          header: header,
        ),
      ),
    );
  }
}

/// The day after [end]: registers read `[from, to)`.
DateTime _after(DateTime end) => DateTime(end.year, end.month, end.day + 1);
