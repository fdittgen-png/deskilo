// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// App settings (theme, language, workspace switching — filled in later).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n?.settingsTitle ?? 'Settings')),
      body: Center(child: Text(l10n?.comingSoon ?? 'Coming soon')),
    );
  }
}
