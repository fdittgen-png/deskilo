// SPDX-License-Identifier: 0BSD
//
// #875 — THE LOCAL REPORT RUNNER.
//
//   dart run tool/report.dart render  layout.xml [--data d.json] [--out out.pdf]
//   dart run tool/report.dart check   layout.xml [--data d.json] [--out out.pdf]
//   dart run tool/report.dart sample  [--kind invoice] [--out d.json]
//   dart run tool/report.dart describe
//
// A report is designed by a person or by Claude in an editor, run HERE
// against sample data, measured in millimetres against the window-envelope
// spec, opened and folded — and only then imported into the app. Nothing
// here needs Flutter or a running app: the engine is pure Dart, the fonts
// are files, the spec is a table of numbers. `check` exits 1 on any issue
// so it can gate a pipeline.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/features/money/domain/address_window.dart';
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/domain/report_conformance.dart';
import 'package:deskilo/features/money/domain/report_layout/layout_model.dart';
import 'package:deskilo/features/money/domain/report_layout/layout_render.dart';
import 'package:deskilo/features/money/domain/report_layout/layout_units.dart';
import 'package:deskilo/features/money/domain/report_layout/layout_xml.dart';
import 'package:deskilo/features/money/domain/report_layout/pdf_geometry.dart';
import 'package:pdf/widgets.dart' as pw;

Future<void> main(List<String> argv) async {
  final args = _Args(argv);
  try {
    final code = switch (args.command) {
      'render' => await _render(args, check: false),
      'check' => await _render(args, check: true),
      'sample' => _sample(args),
      'describe' => _describe(),
      _ => _usage(),
    };
    exit(code);
  } on LayoutException catch (e) {
    // The one failure a designer meets most: say where, say what, and
    // say what caused it — never a Dart stack for an XML mistake.
    stderr.writeln('LAYOUT ERROR (${e.error.name}): ${e.detail}');
    if (e.cause != null) stderr.writeln('  caused by: ${e.cause}');
    exit(2);
  }
}

int _usage() {
  stdout.writeln('''
usage: dart run tool/report.dart <command> [options]

  render   <layout.xml> [--data d.json] [--out out.pdf] [--fonts dir]
  check    <layout.xml> [--data d.json] [--out out.pdf] [--fonts dir]
           renders, then measures every zone in mm against the spec;
           exit 0 = CONFORMS, 1 = issues, 2 = the layout could not be read
  sample   [--kind invoice] [--out d.json]     the data a design renders against
  describe                                     units, elements, attributes, placeholders
''');
  return 64;
}

// ─── render / check ──────────────────────────────────────────────────

Future<int> _render(_Args args, {required bool check}) async {
  final path = args.positional.firstOrNull;
  if (path == null) return _usage();
  final xml = File(path).readAsStringSync();
  final data = args.option('data') == null
      ? _sampleData('invoice')
      : (jsonDecode(File(args.option('data')!).readAsStringSync()) as Map)
          .cast<String, Object?>();
  final fonts = args.option('fonts') ?? 'assets/fonts';
  pw.Font font(String file) => pw.Font.ttf(
      ByteData.sublistView(File('$fonts/$file').readAsBytesSync()));

  final document = renderLayoutDocument(xml, data);
  final bytes = await buildLayoutPdf(
    document: document,
    data: data,
    documentTitle: '${data['workspace'] ?? ''} ${data['number'] ?? ''}'.trim(),
    pageLabel: 'Page',
    baseFont: font('Roboto-Regular.ttf'),
    boldFont: font('Roboto-Bold.ttf'),
  );
  final out = args.option('out') ??
      '${path.replaceAll(RegExp(r'\.xml$'), '')}.pdf';
  File(out).writeAsBytesSync(bytes);
  stdout.writeln('wrote $out (${bytes.length} bytes)');
  if (!check) return 0;
  return _check(bytes, document);
}

/// Measures the produced sheet against the spec — the same numbers the
/// CI gate uses — and prints a table a designer can read with a ruler.
int _check(Uint8List bytes, LayoutDocument document) {
  final window = document.recipient?.window ??
      (document.recipient?.frame != null ? AddressWindow.right : AddressWindow.off);
  final ink = textPositions(bytes);
  final page1 = ink.where((i) => i.page == 1).toList();
  final issues = <ConformanceIssue>[];
  final pages = ink.map((i) => i.page).toSet().length;

  stdout.writeln('\n  ${"zone".padRight(15)} ${"band".padRight(12)} ink');
  for (final zone in reportZones(window)) {
    final inZone = page1.where((i) => zone.containsY(i.yMm)).toList();
    final left = zone.leftMm;
    for (final i in inZone) {
      if (left != null && i.xMm < left - 0.5) {
        issues.add(ConformanceIssue(
            zone.name, '${i.xMm.toStringAsFixed(1)} mm is left of $left mm'));
      }
      if (zone.widthMm != null && left != null && i.xMm > left + zone.widthMm!) {
        issues.add(ConformanceIssue(zone.name,
            '${i.xMm.toStringAsFixed(1)} mm overruns the ${zone.widthMm} mm field'));
      }
    }
    if (zone.name == 'address field' && window.isOn && inZone.isEmpty) {
      issues.add(ConformanceIssue(zone.name,
          'NO RECIPIENT — the envelope shows blank and the buyer is not named'));
    }
    stdout.writeln('  ${zone.name.padRight(15)} '
        '${"${zone.topMm.toStringAsFixed(0)}–${zone.bottomMm.toStringAsFixed(0)} mm".padRight(12)} '
        '${inZone.length} run(s)');
  }
  // Nothing but the recipient between the aperture and 90 mm.
  const fieldBottom = (addressWindowTop + addressWindowHeight) * 25.4 / 72;
  const resume = addressWindowFlowResume * 25.4 / 72;
  for (final i in page1) {
    if (i.yMm > fieldBottom && i.yMm < resume && i.xMm < 100) {
      issues.add(ConformanceIssue('tolerance band', '$i sits under the aperture'));
    }
  }
  if (window.isOn) {
    final fieldPages = addressFieldPages(bytes,
        leftEdgePt: window.leftEdge,
        topPt: addressWindowTop,
        heightPt: addressWindowHeight);
    if (fieldPages.toString() != '[1]') {
      issues.add(ConformanceIssue(
          'address field', 'painted on pages $fieldPages, must be [1]'));
    }
  }
  // The footer, on every page — and NOT the page number: that line sits
  // alone at the bottom right and is drawn by the engine itself, so it
  // must not vouch for a footer zone that vanished (which is exactly how
  // a footer one line too tall slipped past this check once).
  final footerDeclared = !document.footer.isEmpty;
  for (var p = 1; p <= pages; p++) {
    final onPage = ink.where((i) => i.page == p);
    final footerInk = onPage.where((i) => i.yMm > 235 && i.xMm < 150).toList();
    if (footerDeclared && footerInk.isEmpty) {
      issues.add(ConformanceIssue('footer',
          'page $p shows no footer content — a declared footer rendered '
          'nothing (content taller than its box?)'));
    } else if (!footerDeclared && onPage.every((i) => i.yMm < 240)) {
      issues.add(ConformanceIssue('footer', 'page $p has nothing at the bottom'));
    }
    final declared = document.footer.height;
    if (declared != null && footerInk.isNotEmpty) {
      final top = footerInk.map((i) => i.yMm).reduce((a, b) => a < b ? a : b);
      final allowedTop = 297 - document.margin.resolve(0) * 25.4 / 72 -
          declared.resolve(0) * 25.4 / 72 - 12;
      if (top < allowedTop) {
        issues.add(ConformanceIssue('footer',
            'page $p: footer content starts at ${top.toStringAsFixed(1)} mm, '
            'taller than its declared $declared — it grew; raise the '
            'height or shorten the content'));
      }
    }
  }
  stdout.writeln('  pages: $pages');
  if (issues.isEmpty) {
    stdout.writeln('\n  CONFORMS\n');
    return 0;
  }
  stdout.writeln('\n  ${issues.length} ISSUE(S):');
  for (final i in issues) {
    stdout.writeln('    $i');
  }
  stdout.writeln();
  return 1;
}

// ─── sample ──────────────────────────────────────────────────────────

int _sample(_Args args) {
  final kind = args.option('kind') ?? 'invoice';
  final out = args.option('out') ?? 'tool/report/samples/$kind.json';
  File(out)
    ..createSync(recursive: true)
    ..writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(_sampleData(kind))}\n');
  stdout.writeln('wrote $out');
  return 0;
}

/// Every placeholder the engine knows, filled with a French demo value —
/// so a design renders with every field present and the designer sees
/// what each looks like. Keys come from the engine's own list, so a
/// placeholder added later shows up here as an empty string rather than
/// silently missing.
Map<String, Object?> _sampleData(String kind) {
  final demo = <String, Object?>{
    'number': 'INV-2026-0050',
    'member': 'SASU KaloA',
    'workspace': 'COWORKONTI',
    'workspace_address': '4 avenue de Castelnau, 34120 Pézenas',
    'period': 'septembre 2026',
    'issued': '30 sept. 2026',
    'issued_by': 'Mathieu',
    'total': '100,00 €',
    'charges': '100,00 €',
    'payments': '0,00 €',
    'net_total': '100,00 €',
    'vat_total': '0,00 €',
    'refund_total': '0,00 €',
    'lines': [
      {'label': 'Participation 100 %', 'qty': '1', 'unit_price': '100,00 €',
       'net': '100,00 €', 'vat_rate': '', 'amount': '100,00 €', 'negative': false},
    ],
    'vat': <Object?>[],
    'seller_legal_form': 'Association loi 1901',
    'seller_registration': 'RNA W341015106 · SIREN 108251919 · SIRET 10825191900016',
    'seller_legal_id': '10825191900016',
    'exemption_reason': 'TVA non applicable, article 293 B du CGI',
    'client_address': '209 rue Jean Bart, Immeuble AGORA 1B\n31670 LABÈGE',
    'payment_terms': 'Paiement à réception de facture, à 30 jours.',
    'escompte': 'Aucun escompte consenti pour règlement anticipé.',
    'late_penalty': "Tout incident de paiement est passible d'intérêt de retard.",
    'recovery_indemnity': 'Indemnité forfaitaire pour frais de recouvrement : 40 €.',
    'special_mentions': 'Coworkonti est une association à but non lucratif (loi 1901).',
    'iban': 'FR76 1027 8090 5300 0206 7120 122',
    'account_holder': 'COWORKONTI',
    'payment_reference': 'INV-2026-0050',
  };
  return {
    ...InvoicePdfTemplate.placeholderDefaults,
    ...demo,
    if (kind == 'proforma') 'proforma': true,
  };
}

// ─── describe ────────────────────────────────────────────────────────

int _describe() {
  stdout.writeln('''
<report-layout version="1" page="A4" margin="20mm">   the root; margin is the page margin

ZONES (children of the root, in any order)
  <header height="…">        fixed at the top of page 1 only — the letterhead
  <continuation height="…">  fixed at the top of pages 2+ — a short strip naming the document
  <recipient window="fr|din|off" | x y w h/>   page-absolute; fr = 110 mm, din = 20 mm, 45 mm down, 85×40 mm
  <body y="…">               the ONLY flowing zone; y = where it resumes (90mm under a window)
  <footer height="…">        fixed at the bottom of EVERY page

ELEMENTS (inside a zone, a <box> or a <column>)
  ${LayoutXml.content.map((t) => '<$t>').join('  ')}
  <text style="heading|subheading|body|small" align="left|center|right" bold="true">…</text>
  <image name="library-name" fit="contain|cover|fill" align="…"/>
  <table><col w="55%" align="right"/>… <row bold="true"><cell align="…">…</cell></row></table>
  <box>…</box>   <columns><column>…</column>…</columns>   <rule/>   <spacer size="4mm"/>
  <markup>today's band markup, verbatim</markup>

FRAME ATTRIBUTES (any element): ${LayoutXml.frameAttributes.join(' ')}
  with x or y the element is placed absolutely inside its parent; without, it flows after its siblings

UNITS: ${LengthUnit.values.map((u) => u == LengthUnit.percent ? '%' : u.name).join(' ')}
  a bare number is millimetres; px is the CSS pixel (1/96 in); % is of the parent — width for x/w, height for y/h

LIQUID: {{ field }}, {% if field != "" %}…{% endif %}, {% for line in lines %}…{% endfor %}
  runs over the whole file first; values are XML-escaped; an absent field is empty

PLACEHOLDERS
  ${InvoicePdfTemplate.placeholders.join(', ')}
''');
  return 0;
}

// ─── args ────────────────────────────────────────────────────────────

/// `command positional… --key value` — small enough to not need a package.
class _Args {
  _Args(List<String> argv) {
    command = argv.firstOrNull ?? '';
    for (var i = 1; i < argv.length; i++) {
      final a = argv[i];
      if (a.startsWith('--')) {
        _options[a.substring(2)] = i + 1 < argv.length ? argv[++i] : '';
      } else {
        positional.add(a);
      }
    }
  }
  late final String command;
  final positional = <String>[];
  final _options = <String, String>{};
  String? option(String name) => _options[name];
}
