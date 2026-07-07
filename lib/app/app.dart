// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import 'router.dart';
import 'theme.dart';

/// Composition root of DesKilo.
class DeskiloApp extends StatefulWidget {
  const DeskiloApp({super.key});

  @override
  State<DeskiloApp> createState() => _DeskiloAppState();
}

class _DeskiloAppState extends State<DeskiloApp> {
  late final GoRouter _router = createRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      theme: DeskiloTheme.light(),
      darkTheme: DeskiloTheme.dark(),
      routerConfig: _router,
    );
  }
}
