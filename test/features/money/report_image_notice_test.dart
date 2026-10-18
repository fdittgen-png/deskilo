// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2586 — a report image whose read failed is named with the reason in the
// words of the language (denied, unavailable, not an image) and its own
// retry; a typed failure of each kind reads differently, and an untyped
// error reads as unavailable. The retry is a callback of exactly that read.
import 'package:deskilo/features/money/domain/report_image_failure.dart';
import 'package:deskilo/features/money/presentation/widgets/report_image_notice.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('each kind of failure names its own reason', (tester) async {
    final cases = {
      ReportImageFailureKind.forbidden: 'Not allowed to read this image',
      ReportImageFailureKind.unavailable: 'The image could not be read right now',
      ReportImageFailureKind.invalid: 'The file is not a usable image',
    };
    for (final MapEntry(key: kind, value: text) in cases.entries) {
      await tester.pumpWidget(_app(ReportImageNotice(
        name: 'logo',
        error: ReportImageFailure(kind, 'logo'),
        onRetry: () {},
      )));
      expect(find.text('logo: $text'), findsOneWidget, reason: kind.name);
    }
  });

  testWidgets('an error that is not a typed failure reads as unavailable', (tester) async {
    await tester.pumpWidget(_app(ReportImageNotice(
      name: 'logo',
      error: StateError('boom'),
      onRetry: () {},
    )));
    expect(find.textContaining('could not be read right now'), findsOneWidget);
  });

  testWidgets('the retry runs exactly the callback of that image', (tester) async {
    var retried = 0;
    await tester.pumpWidget(_app(ReportImageNotice(
      name: 'logo',
      error: const ReportImageFailure(ReportImageFailureKind.unavailable, 'logo'),
      onRetry: () => retried++,
    )));
    await tester.tap(find.byKey(const ValueKey('report-image-retry-logo')));
    expect(retried, 1);
  });

  testWidgets('the reason is localized', (tester) async {
    await tester.pumpWidget(_app(
      ReportImageNotice(
        name: 'logo',
        error: const ReportImageFailure(ReportImageFailureKind.forbidden, 'logo'),
        onRetry: () {},
      ),
      locale: const Locale('de'),
    ));
    expect(find.text('logo: Dieses Bild darf nicht gelesen werden'), findsOneWidget);
  });
}
