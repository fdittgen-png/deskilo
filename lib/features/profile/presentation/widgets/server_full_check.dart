// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/instance/instance_bundle_asset.dart';
import '../../../../core/instance/management_api.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import 'instance_doctor_panel.dart';

/// #1309 S2 — a full security check of this device's Supabase project, on
/// demand, with a token pasted for the check.
///
/// The same doctor the wizard's finish runs (#1308), not a second one. The
/// token lives in this widget's state and nowhere else: no preference, no
/// trace, gone when the screen closes. DesKilo keeps no access to the
/// customer's project, so a check it cannot do without being handed one.
class ServerFullCheck extends ConsumerStatefulWidget {
  const ServerFullCheck({super.key, required this.projectRef});

  final String projectRef;

  @override
  ConsumerState<ServerFullCheck> createState() => _ServerFullCheckState();
}

class _ServerFullCheckState extends ConsumerState<ServerFullCheck> {
  final _token = TextEditingController();
  SupabaseManagement? _api;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final api = _api;
    return ExpansionTile(
      key: const ValueKey('backend-full-check'),
      leading: const Icon(Icons.health_and_safety_outlined),
      title: Text(l10n?.backendFullCheckTitle ?? 'Run a full check'),
      childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
      children: [
        Text(l10n?.backendFullCheckHint ??
            'Paste a personal access token for this check. It is used for '
                'this check only and never stored.'),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const ValueKey('backend-full-check-token'),
          controller: _token,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (_) {
            if (_api != null) setState(() => _api = null);
          },
          decoration: InputDecoration(
            labelText: l10n?.instanceTokenLabel ?? 'Personal access token',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (api == null)
          FilledButton.tonalIcon(
            key: const ValueKey('backend-full-check-use-token'),
            icon: const Icon(Icons.key_outlined),
            label: Text(l10n?.backendFullCheckUseToken ?? 'Use this token'),
            onPressed: () {
              final token = _token.text.trim();
              if (token.isEmpty) return;
              setState(() =>
                  _api = ref.read(supabaseManagementFactoryProvider)(token));
            },
          )
        else
          InstanceDoctorPanel(api: api, projectRef: widget.projectRef),
      ],
    );
  }
}
