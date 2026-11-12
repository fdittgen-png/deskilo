// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-a -- the experience guards as one reusable check, read from the
// Me guards (test/ux/me_experience_test.dart, #3545): after a surface is
// pumped, [guardProblems] names every rule it breaks -- an overflow or an
// exception, more than one filled button at phone width, a tappable control
// under 48 x 48 dp or without a name. The invoicing guard table and the kit
// gallery run it; the Me guards move onto it when the two kits become one.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// The widths the guards walk: two phones and a wide window.
const List<double> guardWidths = [320, 390, 1280];

/// The text scales the guards walk.
const List<double> guardScales = [1.0, 1.3];

bool _isFilled(Element element) {
  final button = element.widget as FilledButton;
  final scheme = Theme.of(element).colorScheme;
  // ignore: invalid_use_of_protected_member
  final background = button
      .defaultStyleOf(element)
      .backgroundColor
      ?.resolve({});
  final custom = button.style?.backgroundColor?.resolve({});
  return (custom ?? background) == scheme.primary;
}

/// The filled (not tonal) buttons a person can see.
int visibleFilledButtons() =>
    find.byType(FilledButton).hitTestable().evaluate().where(_isFilled).length;

/// Every tappable semantics node with its size and whether it is named.
List<({Size size, bool named})> tappableNodes(WidgetTester tester) {
  // ignore: deprecated_member_use
  final root = tester.binding.pipelineOwner.semanticsOwner?.rootSemanticsNode;
  final out = <({Size size, bool named})>[];
  void walk(SemanticsNode node) {
    final data = node.getSemanticsData();
    if (data.hasAction(SemanticsAction.tap) &&
        !data.flagsCollection.isHidden &&
        !node.isInvisible) {
      out.add((
        size: node.rect.size,
        named:
            data.label.trim().isNotEmpty ||
            data.value.trim().isNotEmpty ||
            data.tooltip.trim().isNotEmpty,
      ));
    }
    node.visitChildren((child) {
      walk(child);
      return true;
    });
  }

  if (root != null) walk(root);
  return out;
}

/// The rules the surface on screen breaks at [width] (semantics must be on).
Set<String> guardProblems(WidgetTester tester, {required double width}) {
  final problems = <String>{};
  var thrown = false;
  while (tester.takeException() != null) {
    thrown = true;
  }
  if (thrown) problems.add('overflow or exception');
  if (width < 600 && visibleFilledButtons() > 1) {
    problems.add('more than one filled button');
  }
  for (final node in tappableNodes(tester)) {
    if (node.size.width < 48 - 0.5 || node.size.height < 48 - 0.5) {
      problems.add('target under 48 dp');
    }
    if (!node.named) problems.add('unnamed control');
  }
  return problems;
}

/// With SHEET=1 in the environment, the first [RepaintBoundary] on screen is
/// written to `build/sheets/<sheet>/<name>.png`: the picture a pull request
/// attaches (never a committed golden). Without it, nothing happens.
Future<void> writeSheet(
  WidgetTester tester, {
  required String sheet,
  required String name,
}) async {
  if (Platform.environment['SHEET'] != '1') return;
  final target = tester.firstRenderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  final image = await tester.runAsync(target.toImage);
  final bytes = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  final dir = Directory('build/sheets/$sheet')..createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

File? _materialIcons() {
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    for (final path in [
      '${dir.path}/material_fonts/MaterialIcons-Regular.otf',
      '${dir.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ]) {
      final f = File(path);
      if (f.existsSync()) return f;
    }
    dir = dir.parent;
  }
  return null;
}

/// With SHEET=1, loads Roboto and the icon font so a sheet shows real text
/// and icons instead of boxes. Without it (and without [always]), nothing
/// happens.
///
/// [always]: measure with the real fonts even when no sheet is written —
/// the desk guards read text widths (a word cut across lines), which the
/// test font does not have.
Future<void> loadSheetFonts({bool always = false}) async {
  if (!always && Platform.environment['SHEET'] != '1') return;
  await loadRealFonts();
}

/// #3782 — loads Roboto and the icon font: a guard that measures text (a
/// cut label) measures it in the app's font, not in the test font, whose
/// every letter is a square.
Future<void> loadRealFonts() async {
  final icons = _materialIcons();
  if (icons != null) {
    await (FontLoader(
          'MaterialIcons',
        )..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync()))))
        .load();
  }
  await (FontLoader('Roboto')
        ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf')))
      .load();
}

// ---------------------------------------------------------------------------
// #3605 (desk F4) — the guards at desk sizes, through the app's builder.
// ---------------------------------------------------------------------------

/// The desk's window sizes, beside [guardWidths].
const List<Size> deskGuardSizes = [
  Size(1024, 768),
  Size(1440, 900),
  Size(1920, 1080),
];

/// What a page is, for the rules that depend on it (the four page kinds of
/// the desk epic).
enum PageKind { records, task, dashboard, document }

/// Who a target is measured for. At the desk a table ROW may be 36 px high,
/// because every row action is also reached by the keyboard and the row
/// menu; every other control stays at 48. Where the device reports touch in
/// the desk posture, rows are 48 too.
enum TargetPolicy { touch, desk }

/// The narrowest a desk table row may be under [TargetPolicy.desk].
const double deskRowMinHeight = 36;

/// The widest a block of body text may run outside a table cell.
const double bodyTextMaxWidth = 760;

/// The share of the window a records page's table takes at 1440 at least.
const double recordsTableMinShare = 0.6;

/// Pumps the app with [overrides] at [size] and opens [path] through its
/// own builder: the frame, the desk and the shell are in the tree, as a
/// person sees them.
Future<void> pumpRoute(
  WidgetTester tester,
  String path, {
  required Size size,
  required List<Override> overrides,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(overrides: overrides, child: const DeskiloApp()),
  );
  await tester.pumpAndSettle();
  ProviderScope.containerOf(
    tester.element(find.byType(DeskiloApp)),
  ).read(routerProvider).go(path);
  await tester.pumpAndSettle();
}

/// The rects of the table rows on screen: where a [TargetPolicy.desk] target
/// may be [deskRowMinHeight] high.
List<Rect> _rowRects(WidgetTester tester, Iterable<Type> rowTypes) => [
  for (final type in rowTypes)
    for (final e in find.byType(type).evaluate())
      if (e.renderObject case final RenderBox box when box.hasSize)
        box.localToGlobal(Offset.zero) & box.size,
];

bool _within(Rect inner, Rect outer) =>
    inner.left >= outer.left - 0.5 &&
    inner.top >= outer.top - 0.5 &&
    inner.right <= outer.right + 0.5 &&
    inner.bottom <= outer.bottom + 0.5;

/// The rules the page on screen breaks at the desk, at [size], as a page of
/// [kind]. [rowTypes] are the widgets that draw a table row, [tableTypes] the
/// widgets a records page's table is (their widest decides the share).
Set<String> deskGuardProblems(
  WidgetTester tester, {
  required PageKind kind,
  required Size size,
  TargetPolicy policy = TargetPolicy.desk,
  Iterable<Type> rowTypes = const [],
  Iterable<Type> tableTypes = const [],
  List<String>? details,
}) {
  final problems = <String>{};
  void note(String what) => details?.add(what);
  var thrown = false;
  while (tester.takeException() != null) {
    thrown = true;
  }
  if (thrown) problems.add('overflow or exception');
  problems.addAll(cutInformationProblems(details: details));
  final rows = _rowRects(tester, rowTypes);
  // Text: a block of body text, one that wraps, runs at most
  // [bodyTextMaxWidth] outside a table row. A one-line label in a wide box
  // is not a reading measure.
  for (final e in find.byType(RichText).evaluate()) {
    final box = e.renderObject;
    if (box is! RenderParagraph || !box.hasSize) continue;
    // The paragraph's own lines, laid out as it is.
    final painter = TextPainter(
      text: box.text,
      textDirection: box.textDirection,
      textScaler: box.textScaler,
      maxLines: box.maxLines,
    )..layout(maxWidth: box.size.width);
    final lines = painter.computeLineMetrics();
    painter.dispose();
    if (lines.length < 2) continue;
    // In a table row, one word over two lines is cut: a date or a column
    // title broken inside itself. Read from the paragraph's own layout.
    final plain = box.text.toPlainText().trim();
    final inRow = rows.any(
      (r) => _within(box.localToGlobal(Offset.zero) & box.size, r),
    );
    if (inRow && plain.isNotEmpty && !plain.contains(RegExp(r'\s'))) {
      final tops = {
        for (final b in box.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: plain.length),
        ))
          b.top.round(),
      };
      if (tops.length > 1) {
        problems.add('a word cut across lines');
        note('cut word: "$plain"');
      }
      continue;
    }
    var widest = 0.0;
    for (final line in lines) {
      if (line.width > widest) widest = line.width;
    }
    if (widest <= bodyTextMaxWidth) continue;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (rows.any((r) => _within(rect, r))) continue;
    problems.add('text wider than ${bodyTextMaxWidth.toInt()} px');
    final text = (e.widget as RichText).text.toPlainText();
    note('text ${widest.toInt()} px: "${text.length > 60 ? text.substring(0, 60) : text}"');
  }
  // A records page's table takes its share of a 1440 window.
  if (kind == PageKind.records && size.width >= 1440) {
    final widest = [
      for (final type in tableTypes)
        for (final e in find.byType(type).evaluate())
          (e.renderObject! as RenderBox).size.width,
    ].fold<double>(0, (a, b) => a > b ? a : b);
    if (widest < recordsTableMinShare * size.width) {
      problems.add('table under ${(recordsTableMinShare * 100).toInt()} %');
      note('table ${widest.toInt()} of ${size.width.toInt()}');
    }
  }
  // Targets: hit regions, by the policy.
  // A control a list has scrolled half out of view is cut at the list's
  // edge: it is measured where it is whole, not here.
  final viewports = [
    for (final e in find.byType(Scrollable).evaluate())
      if (e.renderObject case final RenderBox box when box.hasSize)
        box.localToGlobal(Offset.zero) & box.size,
  ];
  bool cut(Rect r) => viewports.any(
    (v) =>
        _within(r, v) &&
        ((r.top - v.top).abs() < 0.5 || (r.bottom - v.bottom).abs() < 0.5),
  );
  for (final node in tappableRects(tester)) {
    if (cut(node.rect)) continue;
    final row = policy == TargetPolicy.desk &&
        rows.any((r) => _within(node.rect, r));
    final minHeight = row ? deskRowMinHeight : 48;
    final minWidth = row ? 0 : 48;
    if (node.rect.width < minWidth - 0.5 ||
        node.rect.height < minHeight - 0.5) {
      problems.add(row ? 'row under 36 px' : 'target under 48 dp');
      note('target ${node.rect.size} at ${node.rect.topLeft}: ${node.label}');
    }
    if (!node.named) problems.add('unnamed control');
  }
  return problems;
}

// ---------------------------------------------------------------------------
// #3788 — a title or a line that carries information is never cut.
// ---------------------------------------------------------------------------

/// The lines a page marks as information, by their key: each is painted
/// whole wherever it is on screen. A page adds its line here, not in a test.
const List<Key> informationLineKeys = [
  // Reserve's day line: the day, the hours and their time zone.
  ValueKey('booking-window-summary'),
];

/// What stays outside the rule inside a title: names and free text people
/// typed (a business's name), which may be cut where they cannot fit.
const List<Key> typedTextKeys = [ValueKey('space-chip-name')];

/// Whether [box] did not paint all of its text: past its last line (an
/// ellipsis or a clip), or wider than itself on a line that does not wrap.
bool _textCut(RenderParagraph box) {
  if (box.didExceedMaxLines) return true;
  if (box.softWrap) return false;
  final painter = TextPainter(
    text: box.text,
    textDirection: box.textDirection,
    textScaler: box.textScaler,
  )..layout();
  final wide = painter.width;
  painter.dispose();
  return wide > box.size.width + 0.5;
}

/// The paragraphs the rule holds: those in an app bar's title and those of
/// an [informationLineKeys] line, less the [typedTextKeys] subtrees.
Iterable<Element> _informationParagraphs() sync* {
  final typed = {
    for (final key in typedTextKeys)
      ...find
          .descendant(of: find.byKey(key), matching: find.byType(RichText))
          .evaluate(),
  };
  final titles = [
    for (final e in find.byType(AppBar).evaluate())
      if ((e.widget as AppBar).title case final Widget title) title,
  ];
  final seen = <Element>{};
  for (final finder in [
    for (final title in titles) find.byWidget(title),
    for (final key in informationLineKeys) find.byKey(key),
  ]) {
    for (final e
        in find
            .descendant(of: finder, matching: find.byType(RichText))
            .evaluate()) {
      if (!typed.contains(e) && seen.add(e)) yield e;
    }
  }
}

/// The titles and information lines on screen that are cut (an ellipsis,
/// a clip, a line run past its box). [details] receives each cut text.
Set<String> cutInformationProblems({List<String>? details}) {
  final problems = <String>{};
  for (final e in _informationParagraphs()) {
    final box = e.renderObject;
    if (box is! RenderParagraph || !box.hasSize || !box.attached) continue;
    if (!_textCut(box)) continue;
    problems.add('information cut');
    details?.add('cut: "${box.text.toPlainText()}" in ${box.size.width}');
  }
  return problems;
}

/// Every tappable semantics node with its rect on screen and its name.
List<({Rect rect, bool named, String label})> tappableRects(WidgetTester tester) {
  // ignore: deprecated_member_use
  final root = tester.binding.pipelineOwner.semanticsOwner?.rootSemanticsNode;
  final out = <({Rect rect, bool named, String label})>[];
  void walk(SemanticsNode node, Matrix4 parent) {
    final transform = node.transform == null
        ? parent
        : (parent.clone()..multiply(node.transform!));
    final data = node.getSemanticsData();
    if (data.hasAction(SemanticsAction.tap) &&
        !data.flagsCollection.isHidden &&
        !node.isInvisible) {
      out.add((
        rect: MatrixUtils.transformRect(transform, node.rect),
        named:
            data.label.trim().isNotEmpty ||
            data.value.trim().isNotEmpty ||
            data.tooltip.trim().isNotEmpty,
        label: data.label.isNotEmpty ? data.label : data.tooltip,
      ));
    }
    node.visitChildren((child) {
      walk(child, transform);
      return true;
    });
  }

  if (root != null) walk(root, Matrix4.identity());
  return out;
}

/// The focus nodes a person can reach on screen: enabled, visible, not
/// excluded. [tabStops]: those the Tab key stops on; else those it skips
/// (rows inside a composite that arrows move through).
List<FocusNode> _focusables({required bool tabStops}) => [
  for (final n in FocusManager.instance.rootScope.descendants)
    if (n.canRequestFocus &&
        n.skipTraversal != tabStops &&
        n.context != null &&
        n.context!.mounted &&
        n is! FocusScopeNode &&
        // A container whose controls are inside it is not one itself.
        !n.descendants.any((d) => d.canRequestFocus) &&
        _onScreen(n))
      n,
];

bool _onScreen(FocusNode n) {
  final box = n.context!.findRenderObject();
  if (box is! RenderBox || !box.hasSize || !box.attached) return false;
  return box.size.width > 0 && box.size.height > 0;
}

/// The keyboard contract: Tab reaches every Tab stop exactly once in a
/// cycle; a control Tab skips (a row of a composite) is reached by an arrow
/// key from a Tab stop; nothing is left that no key reaches.
Future<Set<String>> keyboardProblems(WidgetTester tester) async {
  final problems = <String>{};
  final stops = _focusables(tabStops: true).toSet();
  final skipped = _focusables(tabStops: false).toSet();
  final seen = <FocusNode>[];
  for (var i = 0; i < stops.length * 2 + 4; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final now = FocusManager.instance.primaryFocus;
    if (now == null) continue;
    if (seen.isNotEmpty && now == seen.first) break;
    if (seen.contains(now)) problems.add('reached twice by Tab');
    seen.add(now);
  }
  if (stops.difference(seen.toSet()).isNotEmpty) {
    problems.add('unreachable by Tab');
  }
  // From each Tab stop, the arrows walk a composite's rows.
  final byArrow = <FocusNode>{};
  for (final stop in seen) {
    stop.requestFocus();
    await tester.pump();
    for (final key in [
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowRight,
    ]) {
      for (var i = 0; i < skipped.length + 1; i++) {
        await tester.sendKeyEvent(key);
        await tester.pump();
        final now = FocusManager.instance.primaryFocus;
        if (now != null && skipped.contains(now)) byArrow.add(now);
      }
    }
  }
  if (skipped.difference(byArrow).isNotEmpty) {
    problems.add('unreachable by any key');
  }
  return problems;
}

/// Escape on the surface on top: a clean one closes, a [dirty] one asks
/// before discarding (one more surface on top, the first still there).
/// [surfaces] finds the open surfaces.
Future<Set<String>> escapeProblems(
  WidgetTester tester, {
  required Finder surfaces,
  required bool dirty,
}) async {
  final before = surfaces.evaluate().length;
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
  final after = surfaces.evaluate().length;
  if (dirty) {
    return after > before ? {} : {'a dirty surface closed without asking'};
  }
  return after < before ? {} : {'Escape did not close the top surface'};
}

/// With SHEET=1, the page on screen at [width] in [brightness] is written
/// to `build/sheets/<module>/<screen>--<width>--<light|dark>.png`.
Future<void> writeDeskSheet(
  WidgetTester tester, {
  required String module,
  required String screen,
  required double width,
  required Brightness brightness,
}) => writeSheet(
  tester,
  sheet: module,
  name: '$screen--${width.toInt()}--${brightness.name}',
);

// ---------------------------------------------------------------------------
// #3782 — the layout of a form: no field touches another, no helper is cut.
// ---------------------------------------------------------------------------

/// The rules the form on screen breaks, within [form]: a field's box (its
/// label, its input and its helper or error line, as its decorator draws
/// them) touches or overlaps another's, or a helper or error text is cut
/// (its paragraph ran past its lines). [details] receives what was found.
///
/// Known limits, so a false alarm or a false pass finds its reason here:
/// * "value cut" flags any one-line value wider than its field. A free text
///   that scrolls inside its field by design is not a cut: if a fixture
///   with a long free text trips it, narrow the check to number and date
///   fields (`keyboardType`) rather than shortening the fixture.
/// * "form off the window" is for a dialog or a sheet, which must fit the
///   window. A full-screen form that scrolls is taller than the window by
///   design: measure its scroll viewport instead, not the form.
Set<String> formLayoutProblems(
  WidgetTester tester, {
  required Finder form,
  List<String>? details,
}) {
  final problems = <String>{};
  final fields = [
    for (final e in find
        .descendant(of: form, matching: find.byType(InputDecorator))
        .evaluate())
      if (e.renderObject case final RenderBox box
          when box.hasSize && box.size.height > 0)
        (rect: box.localToGlobal(Offset.zero) & box.size, label: _labelOf(e)),
  ];
  for (var i = 0; i < fields.length; i++) {
    for (var j = i + 1; j < fields.length; j++) {
      final a = fields[i].rect;
      final b = fields[j].rect;
      // Side by side on one row is a layout, not a crowding: only a field
      // that stands over another counts, and it must leave a gap.
      final overlapX = a.left < b.right && b.left < a.right;
      if (!overlapX) continue;
      final gap = a.top < b.top ? b.top - a.bottom : a.top - b.bottom;
      if (gap <= 0.5) {
        problems.add('fields without a gap');
        details?.add('"${fields[i].label}" and "${fields[j].label}": $gap');
      }
    }
  }
  for (final e in find
      .descendant(
        of: find.descendant(of: form, matching: find.byType(InputDecorator)),
        matching: find.byType(RichText),
      )
      .evaluate()) {
    final box = e.renderObject;
    if (box is RenderParagraph && box.hasSize && box.didExceedMaxLines) {
      problems.add('helper cut');
      details?.add('cut: "${box.text.toPlainText()}" in ${box.size.width}');
    }
  }
  // A value wider than its field is cut: a date or an amount shows its
  // whole self.
  for (final e in find
      .descendant(of: form, matching: find.byType(EditableText))
      .evaluate()) {
    final edit = e.findRenderObject();
    RenderEditable? editable;
    void seek(RenderObject o) {
      if (editable != null) return;
      if (o is RenderEditable) {
        editable = o;
        return;
      }
      o.visitChildren(seek);
    }
    if (edit != null) seek(edit);
    final r = editable;
    if (r == null || !r.hasSize || r.maxLines != 1) continue;
    final painter = TextPainter(
      text: r.text,
      textDirection: r.textDirection,
      textScaler: r.textScaler,
      maxLines: 1,
    )..layout();
    final wide = painter.width;
    painter.dispose();
    if (wide > r.size.width + 0.5) {
      problems.add('value cut');
      details?.add('value "${r.text?.toPlainText()}" $wide in ${r.size.width}');
    }
  }
  // The form stands inside the window: nothing of it is off the screen.
  final window = Offset.zero &
      (tester.view.physicalSize / tester.view.devicePixelRatio);
  for (final e in form.evaluate()) {
    if (e.renderObject case final RenderBox box when box.hasSize) {
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.intersect(window) != rect) {
        problems.add('form off the window');
        details?.add('form $rect in $window');
      }
    }
  }
  return problems;
}

String _labelOf(Element decorator) {
  final d = (decorator.widget as InputDecorator).decoration;
  return d.labelText ?? d.hintText ?? '';
}
