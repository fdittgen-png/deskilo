// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/locale/locale_controller.dart';
import '../l10n/app_localizations.dart';
import 'router.dart';
import 'theme.dart';

/// Composition root of DesKilo.
class DeskiloApp extends ConsumerWidget {
  const DeskiloApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appTitle ?? 'DesKilo',
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // null keeps the standard system-locale resolution (#147).
      locale: ref.watch(localeControllerProvider).value,
      theme: DeskiloTheme.light(),
      darkTheme: DeskiloTheme.dark(),
      routerConfig: router,
    );
  }
}
