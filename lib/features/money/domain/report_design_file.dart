// SPDX-License-Identifier: 0BSD
//
// #864 — a report design as a file that explains itself.
//
// A design used to live only inside the app: to change a layout you
// opened the designer and pushed things around. Nothing could be handed
// to a colleague, kept in a repository, diffed, reviewed — or edited by
// a tool.
//
// The obvious version of this feature is a JSON dump of three strings.
// That is a file nobody can safely edit: it says nothing about what the
// bands are, what the markup means, which placeholders exist, or which
// report it belongs to. So the file carries its own instructions. The
// `howToEdit` block is generated from the same constants the renderer
// uses, which means it cannot drift into describing a language the app
// does not speak.
//
// ROUND-TRIP IS EXACT. Export, import, export again gives byte-identical
// output. `howToEdit` is regenerated rather than read back, so editing
// it changes nothing and cannot corrupt a design; the only fields import
// consumes are `kind`, `language` and `design`.
import 'dart:convert';

import 'invoice_pdf_template.dart';
import 'invoice_report.dart';
import 'report_kind.dart';

/// The names in the file, written once so the writer and the reader can
/// never disagree about them.
abstract final class ReportDesignSchema {
  /// Bumped when the SHAPE changes in a way an older reader would
  /// misread. A file from the future is refused rather than guessed at.
  static const int version = 1;
  static const String id = 'deskilo.report-design';

  static const String keySchema = 'schema';
  static const String keyVersion = 'version';
  static const String keyKind = 'kind';
  static const String keyLanguage = 'language';
  static const String keyWorkspace = 'workspace';
  static const String keyExportedAt = 'exportedAt';
  static const String keyDesign = 'design';
  static const String keyHowToEdit = 'howToEdit';

  static const String keyHeader = 'header';
  static const String keyBody = 'body';
  static const String keyFooter = 'footer';
}

/// Why an import was refused. Each one is a separate sentence to the
/// person holding the file, never a generic failure.
enum ReportDesignError {
  /// Not JSON, or not an object.
  malformed,

  /// JSON, but not one of these files.
  notADesignFile,

  /// Written by a newer DesKilo than this one.
  unsupportedVersion,

  /// A design for a report this workspace does not have.
  unknownKind,

  /// A design for one report imported into another.
  wrongKind,

  /// The `design` block is missing or is not three strings.
  invalidDesign,
}

class ReportDesignException implements Exception {
  ReportDesignException(this.error, this.detail);
  final ReportDesignError error;
  final String detail;
  @override
  String toString() => 'ReportDesignException($error): $detail';
}

/// A design file that parsed. [howToEdit] is deliberately absent: it is
/// output only, and nothing downstream may depend on what a file said.
class ReportDesignFile {
  const ReportDesignFile({
    required this.kindId,
    required this.language,
    required this.bands,
  });

  final String kindId;

  /// '' for the base design, otherwise the language it overlays.
  final String language;
  final ReportBands bands;
}

/// The instructions that travel with a design.
///
/// Generated, never stored: every list here is read from the constant
/// the renderer itself uses, so the file cannot promise a placeholder or
/// a markup line the app would not understand.
Map<String, Object> reportDesignInstructions() => {
      'summary':
          'This file is one report design from DesKilo. Edit the three '
              'strings under "design" and import the file back into the '
              'same report. Everything under "howToEdit" is documentation '
              'regenerated on every export: changing it has no effect.',
      'bands': {
        'header': 'Printed at the top of the document, once.',
        'body': 'The middle of the document. On an invoice this is where '
            'the lines are laid out, usually inside a {% for line in '
            'lines %} loop.',
        'footer': 'Printed at the bottom, once. Legal mentions live here.',
        'note': 'A band may be empty. If all three are empty the document '
            'falls back to the built-in layout.',
      },
      'templateLanguage': {
        'name': 'Liquid',
        'values': '{{ field }} inserts a value.',
        'conditions': '{% if field %} … {% endif %}',
        'loops': '{% for line in lines %} … {% endfor %}',
      },
      'markup': {
        'note': 'Applied line by line to the text Liquid produces.',
        'lines': [
          {'syntax': '# text', 'means': 'document title'},
          {'syntax': '## text', 'means': 'section heading'},
          {'syntax': '> text', 'means': 'small muted text'},
          {'syntax': '---', 'means': 'accent divider'},
          {'syntax': 'a | b', 'means': 'table row; cells after the first '
              'are right-aligned'},
          {'syntax': '= a | b', 'means': 'bold table row, for headers and '
              'totals'},
          {'syntax': '(blank line)', 'means': 'vertical spacing'},
          {'syntax': 'anything else', 'means': 'body text'},
          {
            'syntax': '![name] or ![name|size|align]',
            'means': 'an image from the workspace image library. size is '
                's, m or l; align is left, center or right. An unknown '
                'name renders as nothing rather than breaking the document.'
          },
          {
            'syntax': '::: … ||| … :::',
            'means': 'side-by-side columns, split at |||, each column '
                'parsed with this same markup. An empty first column '
                'pushes the second to the right.'
          },
        ],
      },
      'placeholders': InvoicePdfTemplate.placeholders,
      'imageSizes': [for (final s in ReportImageSize.values) s.code],
      'imageAlignments': [for (final a in ReportImageAlign.values) a.name],
      'rules': [
        'Only "kind", "language" and "design" are read on import.',
        'A file exported from one report cannot be imported into '
            'another: the "kind" must match.',
        'A band that fails to render never breaks the document — the '
            'built-in layout is used instead. So a mistake here is '
            'recoverable, but it is silent.',
        'Placeholders not in the list above render as empty.',
      ],
    };

/// One design, as the bytes that get written to a file.
///
/// Pretty-printed with two spaces and a trailing newline so the result
/// diffs and reviews like source, which is most of the point.
String buildReportDesignFile({
  required ReportKind kind,
  required String language,
  required String workspaceName,
  required ReportBands bands,
  required DateTime exportedAt,
}) {
  final content = <String, Object>{
    ReportDesignSchema.keySchema: ReportDesignSchema.id,
    ReportDesignSchema.keyVersion: ReportDesignSchema.version,
    ReportDesignSchema.keyKind: kind.id,
    ReportDesignSchema.keyLanguage: language,
    ReportDesignSchema.keyWorkspace: workspaceName,
    ReportDesignSchema.keyExportedAt: exportedAt.toUtc().toIso8601String(),
    ReportDesignSchema.keyDesign: {
      ReportDesignSchema.keyHeader: bands.header,
      ReportDesignSchema.keyBody: bands.body,
      ReportDesignSchema.keyFooter: bands.footer,
    },
    ReportDesignSchema.keyHowToEdit: reportDesignInstructions(),
  };
  return '${const JsonEncoder.withIndent('  ').convert(content)}\n';
}

/// Reads a design file, or says exactly why it will not.
///
/// [expectedKind] is the report the person is importing INTO. A design
/// for another report is refused: silently retargeting it would rewrite
/// a document nobody asked about.
ReportDesignFile parseReportDesignFile(
  String content, {
  ReportKind? expectedKind,
  int reminderLevels = 0,
}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(content);
    // Rethrow-only: the message becomes the refusal a person reads, and
    // the caller logs it with its own stack.
    // ignore: catch_no_st
  } on FormatException catch (e) {
    throw ReportDesignException(ReportDesignError.malformed, e.message);
  }
  if (decoded is! Map<String, dynamic>) {
    throw ReportDesignException(
        ReportDesignError.malformed, 'the file is not a JSON object');
  }
  if (decoded[ReportDesignSchema.keySchema] != ReportDesignSchema.id) {
    throw ReportDesignException(ReportDesignError.notADesignFile,
        'schema is ${decoded[ReportDesignSchema.keySchema]}');
  }
  final version = decoded[ReportDesignSchema.keyVersion];
  if (version is! int || version > ReportDesignSchema.version) {
    throw ReportDesignException(
        ReportDesignError.unsupportedVersion, 'version $version');
  }

  final kindId = decoded[ReportDesignSchema.keyKind];
  if (kindId is! String || kindId.isEmpty) {
    throw ReportDesignException(
        ReportDesignError.unknownKind, 'kind is $kindId');
  }
  final kind = reportKindById(kindId, reminderLevels: reminderLevels);
  if (kind == null) {
    throw ReportDesignException(ReportDesignError.unknownKind, kindId);
  }
  if (expectedKind != null && expectedKind.id != kind.id) {
    throw ReportDesignException(ReportDesignError.wrongKind,
        '${kind.id} into ${expectedKind.id}');
  }

  final design = decoded[ReportDesignSchema.keyDesign];
  if (design is! Map) {
    throw ReportDesignException(
        ReportDesignError.invalidDesign, 'design is not an object');
  }
  String band(String key) {
    final value = design[key];
    if (value == null) return '';
    if (value is! String) {
      throw ReportDesignException(
          ReportDesignError.invalidDesign, '$key is not a string');
    }
    return value;
  }

  final language = decoded[ReportDesignSchema.keyLanguage];
  return ReportDesignFile(
    kindId: kind.id,
    language: language is String ? language : '',
    bands: ReportBands(
      header: band(ReportDesignSchema.keyHeader),
      body: band(ReportDesignSchema.keyBody),
      footer: band(ReportDesignSchema.keyFooter),
    ),
  );
}

/// `deskilo-report-invoice-fr-my-space.json`. Pure, so tests pin it.
String reportDesignFileName({
  required String kindId,
  required String language,
  required String workspaceName,
}) {
  final parts = [
    'deskilo-report',
    kindId,
    if (language.isNotEmpty) language,
    workspaceName,
  ];
  return '${_slug(parts.join(' '))}.json';
}

String _slug(String name) {
  final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  final trimmed = slug.replaceAll(RegExp(r'^-+|-+$'), '');
  return trimmed.isEmpty ? 'deskilo-report' : trimmed;
}
