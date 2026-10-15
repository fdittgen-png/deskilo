// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2601 — the one place that knows ProviderScope + MaterialApp + the
// localisation delegates + the view size and its tear-down.
//
// It adds nothing the caller did not ask for: the overrides are exactly the
// ones passed (no `standardTestOverrides()` is implied, so a denied
// permission, a custom provider or a signed-out state reaches the screen
// unchanged), the locale is the one passed (or the MaterialApp default), and
// no workspace is manufactured. The view size and device pixel ratio are
// restored when the test ends.
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Pumps [home] (or the app of [router]) inside a `ProviderScope` and a
/// localised `MaterialApp`. Does not settle: the caller pumps as the
/// test needs.
///
/// - [overrides]: used verbatim.
/// - [locale]: forced; null leaves the MaterialApp default.
/// - [size] (logical) with [pixelRatio]: the test view; restored at teardown.
/// - [textScale]: wraps the app in a `TextScaler.linear`.
/// - [router]: pumps `MaterialApp.router`; then [home] must be null.
Future<void> pumpApp(
  WidgetTester tester,
  Widget? home, {
  List<Override> overrides = const [],
  Locale? locale,
  Size? size,
  double pixelRatio = 1,
  double? textScale,
  GoRouter? router,
}) async {
  assert(
    (home == null) != (router == null),
    'pass exactly one of home and router',
  );
  if (size != null) {
    tester.view.devicePixelRatio = pixelRatio;
    tester.view.physicalSize = size * pixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  Widget scaled(BuildContext context, Widget? child) => textScale == null
      ? child!
      : MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        );
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: router == null
          ? MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: scaled,
              home: home,
            )
          : MaterialApp.router(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: scaled,
              routerConfig: router,
            ),
    ),
  );
}
