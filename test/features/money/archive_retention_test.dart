// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2571 -- the archive bundle of a fiscal year carries the retention notice
// of the workspace country: the bytes are deterministic, the other entries
// are untouched, and the notice is in the zip.
import 'package:archive/archive.dart';
import 'package:deskilo/features/money/domain/archive_bundle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retention.txt joins the bundle and nothing else changes', () {
    final files = {'register.csv': textBytes('a;b'), 'audit-trail.csv': textBytes('c')};
    final bundle = withRetentionNotice(files, 'gb', 2026);
    expect(bundle.keys.toSet(), {...files.keys, 'retention.txt'});
    expect(bundle['register.csv'], files['register.csv']);
    expect(files.containsKey('retention.txt'), isFalse, reason: 'the input map is not mutated');
  });

  test('the zipped notice reads back and two bundles are byte-identical', () {
    final one = zipBundle(withRetentionNotice({'register.csv': textBytes('x')}, 'DE', 2026));
    final two = zipBundle(withRetentionNotice({'register.csv': textBytes('x')}, 'DE', 2026));
    expect(one, two);
    final notice = ZipDecoder().decodeBytes(one).findFile('retention.txt')!;
    expect(String.fromCharCodes(notice.content as List<int>), contains('8 years'));
  });
}
