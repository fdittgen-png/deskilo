// SPDX-License-Identifier: MIT
import 'package:deskilo/app/theme.dart';
import 'package:deskilo/core/theme/app_radius.dart';
import 'package:deskilo/core/theme/seat_state_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppRadius pinning', () {
    test('token values are the spec §14 constants', () {
      expect(AppRadius.sm, 4);
      expect(AppRadius.md, 8);
      expect(AppRadius.lg, 12);
      expect(AppRadius.xl, 16);
      expect(AppRadius.xxl, 24);
    });
  });

  group('DeskiloTheme', () {
    test('light, dark and warm themes build with Material 3', () {
      for (final theme in [
        DeskiloTheme.light(),
        DeskiloTheme.dark(),
        DeskiloTheme.warm(),
      ]) {
        expect(theme.useMaterial3, isTrue);
      }
    });

    test('brand primary is the burnt-orange ramp', () {
      final light = DeskiloTheme.light();
      expect(light.colorScheme.brightness, Brightness.light);
      expect(light.colorScheme.primary, const Color(0xFFC2410C));

      final dark = DeskiloTheme.dark();
      expect(dark.colorScheme.brightness, Brightness.dark);
    });

    test('form fields are dense app-wide for compact professional forms', () {
      for (final theme in [
        DeskiloTheme.light(),
        DeskiloTheme.dark(),
        DeskiloTheme.warm(),
      ]) {
        expect(theme.inputDecorationTheme.isDense, isTrue);
        expect(theme.inputDecorationTheme.contentPadding, isNotNull);
      }
    });
  });

  group('SeatStateColors', () {
    test('all five states have distinct colors per brightness', () {
      for (final brightness in Brightness.values) {
        final colors = SeatState.values
            .map((s) => SeatStateColors.of(s, brightness: brightness))
            .toSet();
        expect(colors.length, SeatState.values.length);
      }
    });

    test('dark variants differ from light variants', () {
      for (final state in SeatState.values) {
        expect(
          SeatStateColors.of(state, brightness: Brightness.light),
          isNot(SeatStateColors.of(state, brightness: Brightness.dark)),
        );
      }
    });
  });
}
