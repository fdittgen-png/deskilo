// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/backend/backend_settings.dart';
import '../features/profile/presentation/screens/server_choice_screen.dart';
import '../features/workspace/domain/workspace_feature.dart';
import '../l10n/app_localizations.dart';
import 'theme.dart';

/// #2343 — the app a build without a default server shows until a server
/// is chosen. It is deliberately not [DeskiloApp]: that one's providers
/// read the Supabase client, and there is no client before the choice.
/// Nothing here contacts a server except the probe the person starts.
///
/// `main` runs it in a ProviderScope of its own whose feature set comes
/// from the registry ([features]), not a workspace. [onChosen] runs once
/// the endpoint is stored; `main` then performs
/// the essential start-up on it and replaces this app with the real one,
/// so the choice takes effect without a restart.
class ServerChoiceApp extends StatefulWidget {
  const ServerChoiceApp({
    super.key,
    required this.onChosen,
    this.store = const PrefsBackendSettingsStore(),
  });

  final VoidCallback onChosen;
  final BackendSettingsStore store;

  /// The features the choice screens may read: the registry defaults,
  /// without the help links — the guide is a route of the real app.
  static Set<WorkspaceFeature> get features =>
      effectiveFeatures(resolveEnabledFeatures(const {}))
        ..remove(WorkspaceFeature.formHelpHints);

  @override
  State<ServerChoiceApp> createState() => _ServerChoiceAppState();
}

class _ServerChoiceAppState extends State<ServerChoiceApp> {
  bool _chosen = false;

  Future<void> _choose(BackendEndpoint endpoint) async {
    if (_chosen) return;
    _chosen = true;
    await widget.store.write(endpoint);
    widget.onChosen();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
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
    home: ServerChoiceScreen(onChosen: _choose),
  );
}
