// SPDX-License-Identifier: 0BSD
//
// #1304 S2 — each role IS a TextTheme style, so it inherits the theme's
// tuning and the reader's text scale; no role invents a size.
import 'package:deskilo/app/theme.dart';
import 'package:deskilo/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final text = DeskiloTheme.light().textTheme;

  test('roles map onto the theme, never onto a new size', () {
    expect(text.pageTitle, text.titleLarge);
    expect(text.primaryValue, text.titleMedium);
    expect(text.metadata, text.bodySmall);
    expect(text.actionLabel, text.labelLarge);
    expect(text.helper, text.bodySmall);
    expect(text.sectionTitle?.fontSize, text.titleSmall?.fontSize);
    expect(text.sectionTitle?.fontWeight, FontWeight.w700);
  });

  test('the page title is the theme\'s tuned title, not a local copy', () {
    expect(text.pageTitle?.fontWeight, FontWeight.w700);
  });

  test('two named weights, nothing in between', () {
    const base = TextStyle(fontSize: 14);
    expect(base.emphasised.fontWeight, FontWeight.w600);
    expect(base.strong.fontWeight, FontWeight.w700);
    expect(base.strong.fontSize, 14);
  });
}
