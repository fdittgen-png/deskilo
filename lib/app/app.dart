// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';

/// Composition root of DesKilo.
///
/// Theme (#14) and router/shell (#15) are wired in here by their respective
/// Epic-#1 children; until then this boots a placeholder.
class DeskiloApp extends StatelessWidget {
  const DeskiloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appTitle ?? 'DesKilo',
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(useMaterial3: true),
      home: const _PlaceholderScreen(),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(child: Text(l10n?.appTitle ?? 'DesKilo')),
    );
  }
}
