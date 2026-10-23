// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The personal layer's tokens are the normative table, measured: every text
// pair reads at 4.5:1 and every interactive border at 3:1 in both schemes,
// the ThemeData derived from them passes the same contrast audit the
// shipped schemes pass, the type scale is the size/line/weight table, the
// dimensions are the shell's, and a window is classified by its width,
// its keyboard-closed height and the reader's text scale.
import 'package:deskilo/app/theme.dart';
import 'package:deskilo/core/theme/contrast.dart';
import 'package:deskilo/core/theme/contrast_audit.dart';
import 'package:deskilo/core/theme/personal_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tokens', () {
    test('light and dark are the normative table', () {
      const l = PersonalTheme.light;
      expect(l.canvas, const Color(0xFFF5F7FB));
      expect(l.surface, const Color(0xFFFFFFFF));
      expect(l.subtle, const Color(0xFFEDF2F8));
      expect(l.text, const Color(0xFF17233B));
      expect(l.secondaryText, const Color(0xFF58677D));
      expect(l.primary, const Color(0xFF3454D1));
      expect(l.onPrimary, const Color(0xFFFFFFFF));
      expect(l.primaryTint, const Color(0xFFEAF0FF));
      expect(l.decorativeBorder, const Color(0xFFDCE3ED));
      expect(l.interactiveBorder, const Color(0xFF79879A));
      expect((l.success, l.successTint),
          (const Color(0xFF15715C), const Color(0xFFE6F4EE)));
      expect((l.warning, l.warningTint),
          (const Color(0xFF8A4B08), const Color(0xFFFFF3DF)));
      expect((l.danger, l.dangerTint),
          (const Color(0xFFB3263A), const Color(0xFFFDECEF)));
      const d = PersonalTheme.dark;
      expect(d.canvas, const Color(0xFF101827));
      expect(d.surface, const Color(0xFF182336));
      expect(d.subtle, const Color(0xFF233047));
      expect(d.text, const Color(0xFFF0F4FC));
      expect(d.secondaryText, const Color(0xFFB5C2D5));
      expect(d.primary, const Color(0xFFAABEFF));
      expect(d.onPrimary, const Color(0xFF10204D));
      expect(d.primaryTint, const Color(0xFF253862));
      expect(d.decorativeBorder, const Color(0xFF34455E));
      expect(d.interactiveBorder, const Color(0xFF8798B1));
      expect((d.success, d.successTint),
          (const Color(0xFF83DABC), const Color(0xFF193C33)));
      expect((d.warning, d.warningTint),
          (const Color(0xFFFFD08B), const Color(0xFF45331B)));
      expect((d.danger, d.dangerTint),
          (const Color(0xFFFFB1BD), const Color(0xFF472735)));
    });

    for (final (name, tokens) in [
      ('light', PersonalTheme.light),
      ('dark', PersonalTheme.dark),
    ]) {
      test('$name: text reads at 4.5:1 and interactive borders at 3:1', () {
        for (final (pair, fg, bg) in tokens.textPairs) {
          expect(Contrast.ratio(fg, bg), greaterThanOrEqualTo(4.5),
              reason: '$name $pair');
        }
        for (final (pair, fg, bg) in tokens.componentPairs) {
          expect(Contrast.ratio(fg, bg), greaterThanOrEqualTo(3.0),
              reason: '$name $pair');
        }
      });
    }

    test('lerp blends the whole table; the copy is the table itself', () {
      final mid = PersonalTheme.light.lerp(PersonalTheme.dark, 0.5);
      expect(mid.canvas,
          Color.lerp(PersonalTheme.light.canvas, PersonalTheme.dark.canvas, 0.5));
      expect(mid.dangerTint,
          Color.lerp(PersonalTheme.light.dangerTint, PersonalTheme.dark.dangerTint, 0.5));
      expect(PersonalTheme.light.lerp(null, 0.3), PersonalTheme.light);
      expect(PersonalTheme.light.copyWith(), same(PersonalTheme.light));
    });
  });

  group('the derived theme', () {
    final themes = <String, ThemeData>{
      'light': personalThemeFrom(
          DeskiloTheme.light(brand: PersonalTheme.light.primary)),
      'dark': personalThemeFrom(
          DeskiloTheme.dark(brand: PersonalTheme.light.primary)),
    };

    for (final entry in themes.entries) {
      test('${entry.key}: every pair the app reads passes AA', () {
        final failures = auditThemeContrast(entry.value);
        expect(failures, isEmpty,
            reason: '${entry.key}: ${failures.join('; ')}');
      });

      test('${entry.key}: the scheme and the surfaces are the tokens', () {
        final t = PersonalTheme.forBrightness(entry.value.brightness);
        final cs = entry.value.colorScheme;
        expect(cs.primary, t.primary);
        expect(cs.onPrimary, t.onPrimary);
        expect(cs.surface, t.surface);
        expect(cs.onSurface, t.text);
        expect(cs.onSurfaceVariant, t.secondaryText);
        expect(cs.outline, t.interactiveBorder);
        expect(cs.outlineVariant, t.decorativeBorder);
        expect(cs.error, t.danger);
        expect(entry.value.scaffoldBackgroundColor, t.canvas);
        expect(entry.value.cardColor, t.surface);
        expect(entry.value.extension<PersonalTheme>(), t);
        expect(entry.value.appBarTheme.backgroundColor, t.surface);
      });
    }

    test('the type scale is the size / line / weight table', () {
      final text = themes['light']!.textTheme;
      ({double size, double line, FontWeight weight}) of(TextStyle? s) => (
            size: s!.fontSize!,
            line: s.fontSize! * s.height!,
            weight: s.fontWeight!,
          );
      expect(of(text.displaySmall), (size: 32, line: 40, weight: FontWeight.w700));
      expect(of(text.headlineSmall), (size: 26, line: 34, weight: FontWeight.w700));
      expect(of(text.titleLarge), (size: 20, line: 28, weight: FontWeight.w600));
      expect(of(text.titleMedium), (size: 18, line: 26, weight: FontWeight.w600));
      expect(of(text.bodyLarge), (size: 16, line: 24, weight: FontWeight.w400));
      expect(of(text.bodyMedium), (size: 14, line: 20, weight: FontWeight.w400));
      expect(of(text.bodySmall), (size: 13, line: 18, weight: FontWeight.w400));
      expect(of(text.labelLarge), (size: 14, line: 20, weight: FontWeight.w600));
      expect(of(text.labelMedium).size, 15);
      expect(of(text.labelMedium).line, 22);
      expect(of(text.labelSmall).size, 12);
      expect(of(text.labelSmall).line, 16);
    });

    testWidgets('PersonalTheme.of answers the ambient brightness without the '
        'extension', (tester) async {
      late PersonalTheme seen;
      await tester.pumpWidget(Theme(
        data: ThemeData(brightness: Brightness.dark),
        child: Builder(builder: (context) {
          seen = PersonalTheme.of(context);
          return const SizedBox();
        }),
      ));
      expect(seen, PersonalTheme.dark);
    });
  });

  group('dimensions and layout', () {
    test('the shell metrics are the logical dimensions', () {
      expect(PersonalShellMetrics.sidebarMinWidth, 1200);
      expect(PersonalShellMetrics.railMinWidth, 840);
      expect(PersonalShellMetrics.sidebarWidth, 248);
      expect(PersonalShellMetrics.railWidth, 80);
      expect(PersonalShellMetrics.contentMaxWidth, 1280);
      expect(PersonalShellMetrics.gutterFor(PersonalLayout.sidebar), 32);
      expect(PersonalShellMetrics.gutterFor(PersonalLayout.rail), 24);
      expect(PersonalShellMetrics.gutterFor(PersonalLayout.bar), 16);
      expect(PersonalShellMetrics.gutterFor(PersonalLayout.menu), 16);
      expect(PersonalShellMetrics.cardRadius, 20);
      expect(PersonalShellMetrics.controlRadius, 12);
      expect(PersonalShellMetrics.minTarget, 48);
      expect(PersonalShellMetrics.menuMinHeight, 480);
    });

    test('the header is 72 beside the content, 64 compact, 56 on an iPhone',
        () {
      expect(PersonalShellMetrics.headerHeightFor(
          PersonalLayout.sidebar, TargetPlatform.iOS), 72);
      expect(PersonalShellMetrics.headerHeightFor(
          PersonalLayout.rail, TargetPlatform.android), 72);
      expect(PersonalShellMetrics.headerHeightFor(
          PersonalLayout.bar, TargetPlatform.android), 64);
      expect(PersonalShellMetrics.headerHeightFor(
          PersonalLayout.menu, TargetPlatform.iOS), 56);
    });

    test('the bar is 72 on the web first, 80 on Android, 56 on an iPhone', () {
      expect(PersonalShellMetrics.barHeightFor(TargetPlatform.iOS, web: true),
          72);
      expect(PersonalShellMetrics.barHeightFor(TargetPlatform.android,
          web: false), 80);
      expect(PersonalShellMetrics.barHeightFor(TargetPlatform.iOS, web: false),
          56);
    });

    PersonalLayout at(double width,
            {double height = 900, double scale = 100, bool menu = false}) =>
        personalLayoutOf(
            width: width,
            height: height,
            textScalePercent: scale,
            menuPreferred: menu);

    test('width decides sidebar, rail and compact', () {
      expect(at(1440), PersonalLayout.sidebar);
      expect(at(1200), PersonalLayout.sidebar);
      expect(at(1199), PersonalLayout.rail);
      expect(at(840), PersonalLayout.rail);
      expect(at(839), PersonalLayout.bar);
      expect(at(390), PersonalLayout.bar);
      expect(at(320), PersonalLayout.bar);
    });

    test('a short window or the chosen menu replaces the bar with the menu',
        () {
      expect(at(800, height: 479), PersonalLayout.menu);
      expect(at(800, height: 480), PersonalLayout.bar);
      expect(at(390, menu: true), PersonalLayout.menu);
      expect(at(1200, menu: true), PersonalLayout.sidebar,
          reason: 'the sidebar already is the menu, permanently');
    });

    test('past the side-navigation text scale a wide window is compact', () {
      expect(at(1440, scale: 150), PersonalLayout.sidebar);
      expect(at(1440, scale: 151), PersonalLayout.bar);
      expect(at(1000, scale: 200), PersonalLayout.bar);
    });
  });
}
