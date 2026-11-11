// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3602 (desk F1) — the posture of the window comes from `WindowClass`
// (lib/core/ui/adaptive/); the fit of content comes from named local
// constraints marked `// content-fit: <why>`. This counts, outside
// lib/core/ui/adaptive/, every comparison of a width with a number — a
// literal, or a numeric constant (local or anywhere in lib/) that is not
// marked as a content fit. The count only falls; the message lists file:line.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The comparisons left after #3602, all of them content fits still to be
/// named or window postures still to move. Never raise it.
const int _ceiling = 0;

final _comparison = RegExp(
  r'([A-Za-z_][\w.]*|\d+(?:\.\d+)?)\s*(>=|<=|>|<)\s*([A-Za-z_][\w.]*|\d+(?:\.\d+)?)',
);
final _const = RegExp(
  r'(?:static\s+)?const\s+(?:double|int|num)?\s*([A-Za-z_]\w*)\s*=\s*(\d+(?:\.\d+)?)\s*;(.*)$',
);

const _measured = {
  'width',
  'height',
  'maxWidth',
  'minWidth',
  'maxHeight',
  'minHeight',
};

bool _isWidth(String side) => RegExp(r'(^|\.)(\w*[wW]idth)$').hasMatch(side);

/// The numeric constants of [sources] by name: their largest value, and
/// whether every declaration of the name is marked a content fit (on its
/// line or the line above).
Map<String, ({double value, bool contentFit})> numericConstants(
  Map<String, String> sources,
) {
  final out = <String, ({double value, bool contentFit})>{};
  for (final text in sources.values) {
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final m = _const.firstMatch(lines[i]);
      if (m == null) continue;
      final marked =
          lines[i].contains('content-fit:') ||
          (i > 0 && lines[i - 1].contains('content-fit:'));
      final value = double.parse(m.group(2)!);
      final before = out[m.group(1)!];
      out[m.group(1)!] = (
        value: before == null || value > before.value ? value : before.value,
        contentFit: (before?.contentFit ?? true) && marked,
      );
    }
  }
  return out;
}

/// A window-sized number: a literal or an unmarked constant of 100 or more.
bool _windowNumber(
  String side,
  Map<String, ({double value, bool contentFit})> constants,
) {
  final literal = double.tryParse(side);
  if (literal != null) return literal >= 100;
  final name = side.split('.').last;
  // A measured size (another box's width or height) is not a threshold.
  if (_measured.contains(name)) return false;
  final constant = constants[name];
  return constant != null && !constant.contentFit && constant.value >= 100;
}

/// The lines of [text] that compare a width with a window-sized number not
/// named as a content fit, given the constants of the whole tree.
List<int> windowComparisons(
  String text,
  Map<String, ({double value, bool contentFit})> constants,
) {
  final found = <int>[];
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trimLeft().startsWith('//') || line.contains('content-fit:')) {
      continue;
    }
    for (final m in _comparison.allMatches(line)) {
      final (a, b) = (m.group(1)!, m.group(3)!);
      if (a.startsWith('WindowClass') || b.startsWith('WindowClass')) continue;
      if ((_isWidth(a) && _windowNumber(b, constants)) ||
          (_isWidth(b) && _windowNumber(a, constants))) {
        found.add(i + 1);
        break;
      }
    }
  }
  return found;
}

Map<String, String> _lib() => {
  for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
    if (f.path.endsWith('.dart') &&
        !f.path.endsWith('.g.dart') &&
        !f.path.endsWith('.freezed.dart'))
      f.path.replaceAll(r'\', '/'): f.readAsStringSync(),
};

void main() {
  test('the four controls: a literal and a local breakpoint are refused, '
      'WindowClass and a named content fit are not', () {
    const source = '''
const double localBreakpoint = 840;
// content-fit: a table cell needs room for two amounts side by side
const double cellMinWidth = 280;
bool a(double width) => width < 840;
bool b(double width) => width < localBreakpoint;
bool c(double width) => WindowClass.ofWidth(width).atLeast(WindowClass.expanded);
bool d(double maxWidth) => maxWidth >= cellMinWidth;
''';
    final constants = numericConstants({'x': source});
    expect(windowComparisons(source, constants), [4, 5]);
  });

  test('outside lib/core/ui/adaptive/, no width is compared with a number', () {
    final sources = _lib();
    final constants = numericConstants(sources);
    final offenders = [
      for (final e in sources.entries)
        if (!e.key.contains('lib/core/ui/adaptive/'))
          for (final line in windowComparisons(e.value, constants))
            '${e.key}:$line',
    ];
    expect(
      offenders.length,
      lessThanOrEqualTo(_ceiling),
      reason:
          'the window posture comes from WindowClass; a content fit is a '
          'named constant marked `// content-fit: <why>`:\n'
          '${offenders.join('\n')}',
    );
    expect(
      offenders.length,
      _ceiling,
      reason: 'the count fell to ${offenders.length}: lower the ceiling',
    );
  });
}
