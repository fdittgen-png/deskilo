// SPDX-License-Identifier: 0BSD
//
// #875 — a positioned layout as a file that explains itself.
//
// The JSON band exchange (#864) made a design portable: export, let a
// person or Claude edit it, import it back, with the rules for editing
// travelling inside the file. This is the same promise for a layout,
// in XML. The how-to block is GENERATED from the constants the reader
// itself accepts, so the documentation can never list an element, a
// unit or a placeholder the engine would refuse.
import 'package:xml/xml.dart';

import 'invoice_pdf_template.dart';
import 'report_design_file.dart' show ReportDesignError, ReportDesignException;
import 'report_kind.dart';
import 'report_layout/layout_model.dart';
import 'report_layout/layout_units.dart';
import 'report_layout/layout_xml.dart';

/// The envelope around a `<report-layout>`.
abstract final class ReportLayoutSchema {
  static const String id = 'deskilo.report-layout';
  static const int version = 1;

  static const String root = 'deskilo-report-layout';
  static const String attrSchema = 'schema';
  static const String attrVersion = 'version';
  static const String attrKind = 'kind';
  static const String attrLanguage = 'language';
  static const String attrWorkspace = 'workspace';
  static const String attrExportedAt = 'exported-at';
}

/// What a parsed file carries. The layout is kept as its XML text —
/// that is what the template stores and the Liquid pass reads — with
/// the parsed tree beside it as proof it is well-formed vocabulary.
class ReportLayoutFile {
  const ReportLayoutFile({
    required this.kindId,
    required this.language,
    required this.layoutXml,
    required this.document,
  });

  final String kindId;

  /// '' for the base design, otherwise the language it overlays.
  final String language;
  final String layoutXml;
  final LayoutDocument document;
}

/// The editing reference that travels with every export, as text for a
/// comment block. Built from the same constants `describe` prints.
String layoutHowToEdit() => '''
HOW TO EDIT THIS FILE

Only the <report-layout> element is read on import; this comment and
the envelope's attributes are documentation regenerated on export.

ZONES — children of <report-layout>, each fixed except the body:
  <header height="…">        top of page 1 only: the letterhead
  <continuation height="…">  top of pages 2+: a short strip naming the document
  <recipient window="fr|din|off" | x y w h/>
                             page-absolute; fr = 110 mm, din = 20 mm across,
                             45 mm down, inside an 85 x 40 mm aperture
  <body y="…">               the ONLY zone that flows and pages; y is where
                             it resumes (90mm under a window envelope)
  <footer height="…">        bottom of EVERY page

ELEMENTS — inside a zone, a <box> or a <column>:
  ${LayoutXml.content.map((t) => '<$t>').join(' ')}
  <text style="${LayoutStyle.values.map((v) => v.name).join('|')}" align="${LayoutAlign.values.map((v) => v.name).join('|')}" bold="true">…</text>
  <image name="library image" fit="${LayoutFit.values.map((v) => v.name).join('|')}" align="…"/>
  <table><col w="55%" align="right"/>… <row bold="true"><cell align="…">…</cell></row></table>
  <box>…</box>  <columns><column>…</column>…</columns>  <rule/>  <spacer size="4mm"/>
  <markup>a band in today's line markup, verbatim</markup>

FRAME — on any element: ${LayoutXml.frameAttributes.join(' ')}
  with x or y the element is placed ABSOLUTELY inside its parent;
  without, it FLOWS after its siblings. w and h apply to both.

UNITS: ${LengthUnit.values.map((u) => u == LengthUnit.percent ? '%' : u.name).join(' ')}
  a bare number is millimetres; px is the CSS pixel (1/96 inch);
  % is of the parent box — its width for x/w, its height for y/h.

LIQUID runs over the whole file before it is read as XML:
  {{ field }}  {% if field != "" %}…{% endif %}  {% for line in lines %}…{% endfor %}
  values are XML-escaped for you; an absent field is empty, never nil.

PLACEHOLDERS: ${InvoicePdfTemplate.placeholders.join(', ')}
  lines iterate {label, qty, unit_price, net, vat_rate, amount, negative};
  vat iterates {rate, net, amount}.

RULES
  A file exported from one report cannot be imported into another: the
  kind must match. An element or unit outside this vocabulary is refused
  on import with its path — never silently skipped. A layout that fails
  at render time falls back to the document's bands and is traced.
  Prove it before importing: dart run tool/report.dart check this-file.xml
''';

String buildReportLayoutFile({
  required ReportKind kind,
  required String language,
  required String workspaceName,
  required String layoutXml,
  required DateTime exportedAt,
}) {
  // Re-serialise through the model so the export is canonical — a bare
  // "12" comes back as "12mm" — and provably readable.
  final document = parseLayoutXml(layoutXml);
  final b = XmlBuilder();
  b.processing('xml', 'version="1.0" encoding="UTF-8"');
  b.element(ReportLayoutSchema.root, nest: () {
    b.attribute(ReportLayoutSchema.attrSchema, ReportLayoutSchema.id);
    b.attribute(ReportLayoutSchema.attrVersion, '${ReportLayoutSchema.version}');
    b.attribute(ReportLayoutSchema.attrKind, kind.id);
    b.attribute(ReportLayoutSchema.attrLanguage, language);
    b.attribute(ReportLayoutSchema.attrWorkspace, workspaceName);
    b.attribute(ReportLayoutSchema.attrExportedAt,
        exportedAt.toUtc().toIso8601String());
    b.comment('\n${layoutHowToEdit()}');
    b.xml(layoutToXml(document));
  });
  return '${b.buildDocument().toXmlString(pretty: true, indent: '  ')}\n';
}

/// Reads a file back. Errors reuse [ReportDesignError] so the import UI
/// speaks one language for both formats; a vocabulary error inside the
/// layout surfaces as [ReportDesignError.invalidDesign] with the
/// element path in the message.
ReportLayoutFile parseReportLayoutFile(
  String content, {
  ReportKind? expectedKind,
  int reminderLevels = 0,
}) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(content);
  } on XmlException catch (e, st) {
    // trace-exempt: re-thrown as ReportDesignException with the
    // original stack attached — a malformed export is usually a tool's
    // fault, and the trace says which one.
    Error.throwWithStackTrace(
        ReportDesignException(ReportDesignError.malformed, e.message), st);
  }
  final root = doc.rootElement;
  if (root.name.local != ReportLayoutSchema.root ||
      root.getAttribute(ReportLayoutSchema.attrSchema) !=
          ReportLayoutSchema.id) {
    throw ReportDesignException(
        ReportDesignError.notADesignFile, '<${root.name.local}>');
  }
  final version =
      int.tryParse(root.getAttribute(ReportLayoutSchema.attrVersion) ?? '');
  if (version == null || version > ReportLayoutSchema.version) {
    throw ReportDesignException(
        ReportDesignError.unsupportedVersion, 'version $version');
  }
  final kindId = root.getAttribute(ReportLayoutSchema.attrKind) ?? '';
  final kind = reportKindById(kindId, reminderLevels: reminderLevels);
  if (kind == null) {
    throw ReportDesignException(ReportDesignError.unknownKind, kindId);
  }
  if (expectedKind != null && expectedKind.id != kind.id) {
    throw ReportDesignException(
        ReportDesignError.wrongKind, '${kind.id} into ${expectedKind.id}');
  }
  final layout = root.childElements
      .where((e) => e.name.local == LayoutXml.root)
      .firstOrNull;
  if (layout == null) {
    throw ReportDesignException(
        ReportDesignError.invalidDesign, 'no <report-layout> inside');
  }
  final layoutXml = layout.toXmlString(pretty: true, indent: '  ');
  final LayoutDocument document;
  try {
    document = parseLayoutXml(layoutXml);
  } on LayoutException catch (e, st) {
    // trace-exempt: re-thrown as ReportDesignException; the layout's
    // own stack (or this one) travels with it.
    Error.throwWithStackTrace(
        ReportDesignException(
            ReportDesignError.invalidDesign, '${e.error.name}: ${e.detail}'),
        e.stackTrace ?? st);
  }
  return ReportLayoutFile(
    kindId: kind.id,
    language: root.getAttribute(ReportLayoutSchema.attrLanguage) ?? '',
    layoutXml: layoutXml,
    document: document,
  );
}

String reportLayoutFileName({
  required String kindId,
  required String language,
  required String workspaceName,
}) {
  final slug = workspaceName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return 'deskilo-report-layout-$kindId'
      '${language.isEmpty ? '' : '-$language'}'
      '${slug.isEmpty ? '' : '-$slug'}.xml';
}
