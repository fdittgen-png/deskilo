// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3674 — one kit. The invoicing parts and Me's are the same widgets, in
// `lib/core/ui/kit`, taking their colours from the ambient theme (under the
// personal theme that is the personal tokens). No second kit directory comes
// back, and no widget outside the kit is a twin of a kit widget (a
// `MeStatusChip` beside `StatusChip`, a `MeQuietLine` beside `QuietLine`):
// a look one surface needs is a variant of the kit part, or the kit part
// itself.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

const _kit = 'lib/core/ui/kit';

final _widget = RegExp(
  r'^class (\w+) extends (?:StatelessWidget|StatefulWidget|ConsumerWidget|'
  r'ConsumerStatefulWidget)\b',
  multiLine: true,
);

/// The widget classes declared in [files], with the file of each.
Map<String, String> widgetsIn(Iterable<File> files) => {
  for (final f in files)
    for (final m in _widget.allMatches(f.readAsStringSync()))
      m.group(1)!: f.path,
};

/// RATCHET: twins older than the one kit, each with the issue that resolves
/// it. Only shrinks.
const _olderTwins = {
  'InvoiceStatusChip': '#3999',
  '_DirectoryStatusChip': '#3999',
  'FeaturesFilterBar': '#3999',
  'EventsFilterBar': '#3999',
};

/// The widgets of [elsewhere] whose name is a kit widget's with a prefix.
List<String> twins(Set<String> kit, Map<String, String> elsewhere) => [
  for (final MapEntry(key: name, value: path) in elsewhere.entries)
    for (final part in kit)
      if (name != part && name.endsWith(part) && part.length >= 6)
        '$path: $name is a twin of the kit\'s $part',
];

void main() {
  test('the kit is one directory', () {
    final kits = {
      for (final f in handWrittenDartFiles('lib'))
        if (f.parent.path.replaceAll(Platform.pathSeparator, '/') case final dir
            when dir.endsWith('kit'))
          dir,
    };
    expect(kits, {_kit}, reason: 'a second kit is a second look');
  });

  test('no widget outside the kit is a twin of a kit widget', () {
    final kit = widgetsIn(handWrittenDartFiles(_kit)).keys.toSet();
    expect(kit, containsAll(['KitCard', 'StatusChip', 'QuietLine']));
    final elsewhere = widgetsIn([
      for (final f in handWrittenDartFiles('lib'))
        if (!f.path.replaceAll(Platform.pathSeparator, '/').startsWith(_kit)) f,
    ]);
    final found = twins(kit, elsewhere);
    expect([
      for (final t in found)
        if (!_olderTwins.keys.any((n) => t.contains(': $n is'))) t,
    ], isEmpty);
    expect(
      [
        for (final n in _olderTwins.keys)
          if (!found.any((t) => t.contains(': $n is'))) n,
      ],
      isEmpty,
      reason: 'a twin resolved leaves the list',
    );
  });

  test('the twin rule bites', () {
    expect(
      twins(
        {'StatusChip', 'QuietLine'},
        {
          'MeStatusChip': 'lib/a.dart',
          'QuietLine': 'lib/core/ui/kit/kit_card.dart',
        },
      ),
      ['lib/a.dart: MeStatusChip is a twin of the kit\'s StatusChip'],
    );
  });
}
