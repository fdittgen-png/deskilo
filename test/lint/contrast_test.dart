// SPDX-License-Identifier: 0BSD
//
// #721 — WCAG AA over the shipped schemes, measured, not hoped.
//
// Since #1289 the pairs and floors live in ONE place,
// `lib/core/theme/contrast_audit.dart`, which the runtime validator of a
// workspace's brand seed calls too. This lint asserts that list is empty
// for the three compiled-in schemes, and proves the checker can fail.
import 'package:deskilo/app/theme.dart';
import 'package:deskilo/core/theme/contrast_audit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final schemes = <String, ThemeData>{
    'light': DeskiloTheme.light(),
    'dark': DeskiloTheme.dark(),
    'warm': DeskiloTheme.warm(),
  };

  for (final entry in schemes.entries) {
    test('${entry.key}: every pair the app reads passes AA', () {
      final failures = auditThemeContrast(entry.value);
      expect(failures, isEmpty,
          reason: '${entry.key}: ${failures.join('; ')}');
    });
  }

  test('the checker fails on a scheme that cannot be read, naming the pair',
      () {
    // Mid-grey on mid-grey: nothing here reaches 4.5:1.
    const grey = Color(0xFF808080);
    final unreadable = ThemeData(
      colorScheme: const ColorScheme.light(
        surface: grey,
        onSurface: Color(0xFF9A9A9A),
        primary: grey,
        onPrimary: Color(0xFF9A9A9A),
      ),
      scaffoldBackgroundColor: grey,
      cardColor: grey,
    );
    final failures = auditThemeContrast(unreadable);
    expect(failures, isNotEmpty);
    expect(
      failures.map((f) => f.pair),
      containsAll(['onSurface on surface', 'onPrimary on primary']),
    );
    final worst = failures.firstWhere((f) => f.pair == 'onSurface on surface');
    expect(worst.ratio, lessThan(1.5));
    expect(worst.floor, contrastTextFloor);
    expect('$worst', contains('onSurface on surface'));
  });
}
