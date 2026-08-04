// SPDX-License-Identifier: 0BSD
//
// The badge on every platform (#444): the pure overlay mapping for
// Windows, and the committed .ico assets it points at — a mapping to a
// missing file would assert at runtime on Windows only, invisible to
// the rest of the suite.

import 'dart:io';

import 'package:deskilo/core/badge/app_badge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('overlay mapping: 1–9 numbered, 9+ capped, 0 clears', () {
    expect(overlayAssetFor(0), isNull);
    expect(overlayAssetFor(-3), isNull);
    expect(overlayAssetFor(1), 'assets/badges/badge_1.ico');
    expect(overlayAssetFor(9), 'assets/badges/badge_9.ico');
    expect(overlayAssetFor(10), 'assets/badges/badge_9plus.ico');
    expect(overlayAssetFor(240), 'assets/badges/badge_9plus.ico');
  });

  test('every overlay the mapping can name exists as a committed asset',
      () {
    for (final count in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]) {
      final asset = overlayAssetFor(count)!;
      expect(File(asset).existsSync(), isTrue, reason: '$asset missing');
    }
  });
}
