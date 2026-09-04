// SPDX-License-Identifier: 0BSD
//
// Play will not serve a listing whose language has fewer than two phone
// screenshots, and an unservable listing in ONE language makes the app
// undistributable on EVERY track — internal testing included. There is
// no error anywhere: the store simply answers "item not found" to anyone
// whose device is in that language.
//
// That is what happened. Four locales shipped with texts, an icon and no
// screenshots, because the fallback that covers single images never
// covered the phoneScreenshots FOLDER, and an empty folder was skipped
// in silence.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _minScreenshots = 2;

void main() {
  final metadata = Directory('fastlane/metadata/android');
  final tool = File('tools/upload_listing.py').readAsStringSync();

  test('every listed locale resolves to enough phone screenshots', () {
    final locales = metadata
        .listSync()
        .whereType<Directory>()
        .where((d) => File('${d.path}/title.txt').existsSync())
        .map((d) => d.path.split('/').last)
        .toList()
      ..sort();
    expect(locales, isNotEmpty);

    final fallback = Directory(
        '${metadata.path}/en-US/images/phoneScreenshots');
    final fallbackCount = fallback.existsSync()
        ? fallback.listSync().where((f) => f.path.endsWith('.png')).length
        : 0;

    for (final locale in locales) {
      final own =
          Directory('${metadata.path}/$locale/images/phoneScreenshots');
      final ownCount = own.existsSync()
          ? own.listSync().where((f) => f.path.endsWith('.png')).length
          : 0;
      final resolved = ownCount > 0 ? ownCount : fallbackCount;
      expect(resolved, greaterThanOrEqualTo(_minScreenshots),
          reason: '$locale resolves to $resolved screenshot(s). Play will '
              'not serve this listing, and one unservable language makes '
              'the app undistributable on every track.');
    }
  });

  test('the uploader falls back for the folder, not only for single '
      'images, and refuses to leave a locale short', () {
    expect(tool, contains('def _screenshots('),
        reason: 'the folder needs the same en-US fallback single images '
            'have always had');
    expect(tool, contains('MIN_SCREENSHOTS'));
    expect(tool, contains('undistributable on'),
        reason: 'and a short locale must be a hard error, never the '
            'silent skip that caused this');
  });
}
