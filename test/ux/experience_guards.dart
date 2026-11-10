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

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
/// and icons instead of boxes. Without it, nothing happens.
Future<void> loadSheetFonts() async {
  if (Platform.environment['SHEET'] != '1') return;
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
