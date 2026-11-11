// SPDX-License-Identifier: AGPL-3.0-or-later
// Catalogue controls must reach real widgets, in the requested locale,
// theme and viewport. Changing a state remounts and disposes its fixture.
import 'package:deskilo/core/ui/form_kit.dart';
import 'package:deskilo/core/ui/inline_banner.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_widgetbook/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widgetbook/widgetbook.dart';

Future<WidgetbookState> openCase(
  WidgetTester tester,
  String component, {
  Map<String, String> settings = const {},
}) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final route = Uri(
    path: '/',
    queryParameters: {'path': '$component/states', 'preview': '', ...settings},
  ).toString();
  await tester.pumpWidget(
    DeskiloCatalog(key: ValueKey(route), initialRoute: route),
  );
  await tester.pumpAndSettle();
  return WidgetbookState.of(tester.element(find.byType(Scaffold).last));
}

void main() {
  testWidgets('addons reach the real field at every configured setting', (
    t,
  ) async {
    for (final width in [320, 390, 1280]) {
      for (final scale in [1.0, 1.3]) {
        for (final theme in ['Light', 'Dark']) {
          for (final locale in ['en', 'fr', 'de', 'es', 'it']) {
            await openCase(
              t,
              'apptextfield',
              settings: {
                'viewport': FieldCodec.encodeQueryGroup({'name': '$width dp'}),
                'text-scale': FieldCodec.encodeQueryGroup({'factor': '$scale'}),
                'theme': FieldCodec.encodeQueryGroup({'name': theme}),
                'locale': FieldCodec.encodeQueryGroup({'name': locale}),
              },
            );
            final field = find.byKey(const ValueKey('catalog-field'));
            final context = t.element(field);
            expect(MediaQuery.sizeOf(context).width, width);
            expect(MediaQuery.textScalerOf(context).scale(10), scale * 10);
            expect(
              Theme.of(context).brightness,
              theme == 'Dark' ? Brightness.dark : Brightness.light,
            );
            expect(
              Theme.of(context).platform,
              width < 600 ? TargetPlatform.android : TargetPlatform.windows,
            );
            expect(Localizations.localeOf(context).languageCode, locale);
            expect(
              t.widget<AppTextField>(field).label,
              lookupAppLocalizations(Locale(locale)).authEmailLabel,
            );
            expect(t.takeException(), isNull);
          }
        }
      }
    }
  });

  testWidgets('button knobs change busy and disabled behavior', (t) async {
    final state = await openCase(t, 'kitactionbutton');
    final button = find.byType(FilledButton);
    await t.tap(button);
    await t.pumpAndSettle();
    expect(t.widget<FilledButton>(button).onPressed, isNotNull);
    state.updateQueryField(group: 'knobs', field: 'Busy', value: 'true');
    await t.pump();
    await t.pump();
    expect(t.widget<FilledButton>(button).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    state.updateQueryField(group: 'knobs', field: 'Busy', value: 'false');
    state.updateQueryField(group: 'knobs', field: 'Enabled', value: 'false');
    await t.pumpAndSettle();
    expect(t.widget<FilledButton>(button).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('field accepts input and remounts with a visible error', (
    t,
  ) async {
    final state = await openCase(t, 'apptextfield');
    await t.enterText(find.byType(TextField), 'demo@example.test');
    expect(find.text('demo@example.test'), findsOneWidget);
    state.updateQueryField(
      group: 'knobs',
      field: 'Required error',
      value: 'true',
    );
    await t.pumpAndSettle();
    expect(
      find.text(
        lookupAppLocalizations(const Locale('en')).fieldProblemRequired,
      ),
      findsOneWidget,
    );
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
    expect(t.takeException(), isNull);
  });

  testWidgets('banner knobs change severity and the available action', (
    t,
  ) async {
    final state = await openCase(t, 'inlinebanner');
    final action = find.byKey(const ValueKey('inline-banner-action'));
    await t.tap(action);
    await t.pumpAndSettle();
    state.updateQueryField(group: 'knobs', field: 'Error', value: 'false');
    state.updateQueryField(group: 'knobs', field: 'Action', value: 'false');
    await t.pumpAndSettle();
    expect(
      t.widget<InlineBanner>(find.byType(InlineBanner)).severity,
      InlineBannerSeverity.info,
    );
    expect(action, findsNothing);
    expect(t.takeException(), isNull);
  });
}
