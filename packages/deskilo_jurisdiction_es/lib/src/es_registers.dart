// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the Spanish registers of issued invoices behind the
// registers contract: the libro registro de facturas expedidas, the SII
// message and the modelo 347 list. The host hands a neutral
// `RegisterContext`; nothing here reads an application type.
import 'dart:convert' show utf8;

import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_standards/deskilo_jurisdiction_standards.dart'
    show ymd;
import 'package:deskilo_xlsx/deskilo_xlsx.dart' show buildXlsx;

import 'vat_register_es.dart';
import 'vat_register_es_347.dart';
import 'vat_register_es_sii.dart';

/// Bumped in the same commit as any change of what a register WRITES (a
/// column, a key, a layout): the application's parity goldens change with it.
/// 1 = the writers as they stood when they left the application.
const String esRegistersImplementationVersion = '1';

const _xlsx = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// The Spanish registers.
class EsRegisters extends RegisterContribution {
  const EsRegisters();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'es.registers',
    implementationVersion: esRegistersImplementationVersion,
    contractVersion: registersContractVersion,
    formatVersion: 'aeat-libro-sii-347',
    capabilityId: 'registers.ES',
  );

  @override
  Set<String> get kinds => const {'esLibro', 'esSii', 'es347'};

  @override
  String? thresholdKey(String kind) => kind == 'es347' ? 'modelo347' : null;

  @override
  bool acceptsActivity(String raw) => isEsActivity(raw);

  @override
  GeneratedArtifact? generate(String kind, RegisterContext context) {
    final last = DateTime(context.to.year, context.to.month, context.to.day - 1);
    switch (kind) {
      case 'esLibro':
        // The book of the year so far, never one quarter (Pre303 reads it so).
        final docs = registerDocuments(
          context.documents,
          from: DateTime(last.year),
          to: context.to,
        );
        if (docs.isEmpty) return null;
        final nif = context.sellerVatId.toUpperCase().replaceAll(
          RegExp('[^A-Z0-9]'),
          '',
        );
        return GeneratedArtifact(
          bytes: buildXlsx([
            esLibroExpedidas(
              docs,
              activity: context.activity,
              monthly: context.monthly,
              context: context,
            ),
          ]),
          mediaType: _xlsx,
          // The AEAT's name: exercise, NIF, the book's type (E), the holder.
          fileName:
              '${last.year}${nif.startsWith('ES') ? nif.substring(2) : nif}E'
              '${context.sellerName.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')}.xlsx',
          provenance: descriptor.toProvenance(),
        );
      case 'esSii':
        final docs = registerDocuments(
          context.documents,
          from: context.from,
          to: context.to,
        );
        if (docs.isEmpty) return null;
        return GeneratedArtifact(
          bytes: utf8.encode(
            siiFacturasEmitidasXml(
              docs,
              vatId: context.sellerVatId,
              name: context.sellerName,
              context: context,
            ),
          ),
          mediaType: 'application/xml',
          fileName:
              'sii-facturas-emitidas-${ymd(context.from, separator: '-')}.xml',
          provenance: descriptor.toProvenance(),
        );
      case 'es347':
        final list = modelo347Lines(
          registerDocuments(
            context.documents,
            from: DateTime(last.year),
            to: DateTime(last.year + 1),
          ),
          year: last.year,
          context: context,
        );
        if (list == null || list.lines.isEmpty) return null;
        return GeneratedArtifact(
          bytes: utf8.encode(
            modelo347Csv(list.lines, currency: list.currency),
          ),
          mediaType: 'text/csv',
          fileName: 'modelo-347-${last.year}.csv',
          provenance: descriptor.toProvenance(),
        );
    }
    throw ArgumentError.value(kind, 'kind', 'not a Spanish register');
  }
}
