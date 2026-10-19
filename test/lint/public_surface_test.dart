// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2384 — no over-exposed declaration in `lib/`. A public top-level
// declaration that no other production file names is `_private` to its
// file; one that tests also read carries `@visibleForTesting`. The scan is
// the dead-code scan's second mode (`tool/dead_code/surface.dart`;
// `dart run tool/dead_code.dart --surface` prints every finding); this
// file is the gate, and the analyzer's `library_private_types_in_public_api`
// keeps a private type out of a public signature.
//
// The list only shrinks: an entry the scan no longer reports fails too.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/dead_code/scan.dart';

/// `path::name` → why it stays public, naming the issue that resolves it.
const Map<String, String> _allowed = {
  'lib/features/reservations/domain/room_rental.dart::RoomFeeUnit':
      '#2575 — the rented-room screens read the fee unit',
  'lib/features/reservations/domain/room_rental.dart::RoomWindowRefusal':
      '#2575 — the booking sheet words the refusal from it',
  'lib/core/webmcp/webmcp_registry.dart::WebMcpConditions':
      '#2504 — the WorkspaceFeature.webMcp provider builds it',
  'lib/core/webmcp/webmcp_registry.dart::WebMcpToolRunner':
      '#2504 — the read and write runners implement it',
  'lib/features/money/presentation/widgets/invoice_form_sheet.dart::invoiceMissingLabel':
      '#2384 — on an open VAT branch, after it merges',
};

void main() {
  final findings = scanPublicSurface(Directory.current.path);

  test('no public declaration in lib/ is used only by its own file', () {
    final fresh = [
      for (final f in findings)
        if (!_allowed.containsKey(f.key)) f.toString(),
    ];
    expect(
      fresh,
      isEmpty,
      reason:
          'make an ownFile symbol private (_name); give a testsOnly '
          'symbol @visibleForTesting; or name the issue in _allowed:\n'
          '${fresh.join('\n')}',
    );
  });

  test('every allowed entry is still a finding — the list only shrinks', () {
    final found = {for (final f in findings) f.key};
    final stale = [
      for (final key in _allowed.keys)
        if (!found.contains(key)) key,
    ];
    expect(
      stale,
      isEmpty,
      reason: 'no longer over-exposed — remove the entry:\n${stale.join('\n')}',
    );
  });

  test('every allowed entry names the issue that resolves it', () {
    final unnamed = [
      for (final e in _allowed.entries)
        if (!RegExp(r'#\d+').hasMatch(e.value)) e.key,
    ];
    expect(unnamed, isEmpty);
  });

  group('the scan', () {
    late Directory root;
    late List<SurfaceFinding> found;

    void write(String path, String text) => File('${root.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);

    setUpAll(() {
      root = Directory.systemTemp.createTempSync('public_surface_');
      write('lib/a.dart', '''
import 'package:meta/meta.dart';

part 'a.g.dart';

const ownLimit = 3;
int clamp(int v) => v > ownLimit ? ownLimit : v;

const readByTest = 4;
int twice() => readByTest * 2;

@visibleForTesting
const annotated = 5;
int thrice() => annotated * 3;

class Row {
  const Row([this.cell = const Cell()]);
  final Cell cell;
}

class Cell {
  const Cell();
}

class Sheet {
  const Sheet();
}
Object showSheet() => const Sheet();

@riverpod
int counter(Ref ref) => ownLimit;
int readCounter() => counter(null);

int nobodyAtAll() => 0;
''');
      write('lib/a.g.dart', '''
part of 'a.dart';
final counterProvider = 0;
''');
      write('lib/b.dart', '''
import 'a.dart';
final rows = [const Row()];
int use() => clamp(1) + twice() + thrice() + showSheet().hashCode;
int read() => counterProvider + readCounter();
''');
      write('test/a_test.dart', '''
import 'package:x/a.dart';
void main() => [readByTest, annotated, use()];
''');
      found = scanPublicSurface(root.path);
    });

    tearDownAll(() => root.deleteSync(recursive: true));

    SurfaceKind? kindOf(String name) =>
        found.where((f) => f.name == name).firstOrNull?.kind;

    test('a declaration only its own file uses is found', () {
      expect(kindOf('ownLimit'), SurfaceKind.ownFile);
      expect(
        kindOf('Sheet'),
        SurfaceKind.ownFile,
        reason: 'a widget behind its show function is the shape #2384 names',
      );
    });

    test('one its file and a test use is found, until annotated', () {
      expect(kindOf('readByTest'), SurfaceKind.testsOnly);
      expect(kindOf('annotated'), isNull);
    });

    test('what is surface or dead is not listed', () {
      expect(
        kindOf('Cell'),
        isNull,
        reason: 'named in the public face of Row, which is used elsewhere',
      );
      expect(
        kindOf('counter'),
        isNull,
        reason: 'its generated part names it: the provider is built from it',
      );
      expect(
        kindOf('nobodyAtAll'),
        isNull,
        reason: 'unreferenced code is the dead-code gate',
      );
    });

    test('it reports exactly those', () {
      expect(found.map((f) => f.name).toSet(), {
        'ownLimit',
        'Sheet',
        'readByTest',
      });
    });
  });
}
