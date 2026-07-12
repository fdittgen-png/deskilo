// SPDX-License-Identifier: MIT
//
// #210: spacing tokens pinned like AppRadius — the token VALUES are part
// of the visual contract, not free-floating magic numbers.
import 'package:deskilo/core/theme/app_spacing.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSpacing pinning', () {
    test('token values are the #210 constants', () {
      expect(AppSpacing.xs, 4);
      expect(AppSpacing.sm, 8);
      expect(AppSpacing.md, 12);
      expect(AppSpacing.lg, 16);
      expect(AppSpacing.xl, 24);
      expect(AppSpacing.screenGutter, AppSpacing.lg);
    });

    test('ready-made EdgeInsets derive from the tokens', () {
      expect(AppSpacing.gutterAll, const EdgeInsets.all(AppSpacing.lg));
      expect(
        AppSpacing.gutterH,
        const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      );

      expect(AppSpacing.xsAll, const EdgeInsets.all(4));
      expect(AppSpacing.smAll, const EdgeInsets.all(8));
      expect(AppSpacing.mdAll, const EdgeInsets.all(12));
      expect(AppSpacing.lgAll, const EdgeInsets.all(16));
      expect(AppSpacing.xlAll, const EdgeInsets.all(24));

      expect(AppSpacing.xsH, const EdgeInsets.symmetric(horizontal: 4));
      expect(AppSpacing.smH, const EdgeInsets.symmetric(horizontal: 8));
      expect(AppSpacing.mdH, const EdgeInsets.symmetric(horizontal: 12));
      expect(AppSpacing.lgH, const EdgeInsets.symmetric(horizontal: 16));
      expect(AppSpacing.xlH, const EdgeInsets.symmetric(horizontal: 24));
    });
  });
}
