// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/instance/instance_network.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import 'instance_done_step.dart';

/// #2561 L3 — the wizard's answer about the network, held beside the
/// owner-claim field until the sign-in step applies both.
class InstanceNetworkController extends ChangeNotifier {
  InstanceRoleChoice _role = InstanceRoleChoice.combined;
  final homeUrl = TextEditingController();
  final homeKey = TextEditingController();

  InstanceRoleChoice get role => _role;
  set role(InstanceRoleChoice value) {
    _role = value;
    notifyListeners();
  }

  InstanceNetworkChoice get choice => InstanceNetworkChoice(
    _role,
    personalHome: _role == InstanceRoleChoice.workspaceHost
        ? PersonalHomeEndpoint(homeUrl.text.trim(), homeKey.text.trim())
        : null,
  );

  @override
  void dispose() {
    homeUrl.dispose();
    homeKey.dispose();
    super.dispose();
  }
}

/// #2561 L3 — combined, personal home or workspace host, and for a
/// workspace host the explicit personal home of its people (URL and
/// publishable key). The wizard checks the home before it records it.
class InstanceNetworkField extends StatelessWidget {
  const InstanceNetworkField({
    super.key,
    required this.controller,
    required this.enabled,
  });

  final InstanceNetworkController controller;
  final bool enabled;

  /// The sentence for a refused network declaration, or null when [item]
  /// is another step's.
  static String? describe(AppLocalizations l10n, String item, String fault) {
    if (item != 'network') return null;
    return switch (InstanceNetworkFault.values
        .where((f) => f.name == fault)
        .firstOrNull) {
      InstanceNetworkFault.homeRequired => l10n.instanceNetworkHomeRequired,
      InstanceNetworkFault.homeEndpoint => l10n.instanceNetworkHomeEndpoint,
      InstanceNetworkFault.homeUnreachable =>
        l10n.instanceNetworkHomeUnreachable,
      InstanceNetworkFault.homeNotPersonal =>
        l10n.instanceNetworkHomeNotPersonal,
      InstanceNetworkFault.homeIsThisInstance =>
        l10n.instanceNetworkHomeIsThisInstance,
      null => null,
    };
  }

  String _label(AppLocalizations l10n, InstanceRoleChoice role) =>
      switch (role) {
        InstanceRoleChoice.combined => l10n.instanceNetworkCombined,
        InstanceRoleChoice.personalHome => l10n.instanceNetworkPersonalHome,
        InstanceRoleChoice.workspaceHost => l10n.instanceNetworkWorkspaceHost,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final host = controller.role == InstanceRoleChoice.workspaceHost;
        final shape = controller.choice.shapeFault;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WizardText(l10n.instanceNetworkIntro),
              DropdownButtonFormField<InstanceRoleChoice>(
                key: const ValueKey('instance-network-role'),
                initialValue: controller.role,
                decoration: InputDecoration(
                  labelText: l10n.instanceNetworkRoleLabel,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final r in InstanceRoleChoice.values)
                    DropdownMenuItem(value: r, child: Text(_label(l10n, r))),
                ],
                onChanged: enabled
                    ? (v) => controller.role = v ?? controller.role
                    : null,
              ),
              if (host) ...[
                const SizedBox(height: AppSpacing.sm),
                WizardText(l10n.instanceNetworkHomeIntro),
                AppTextField(
                  key: const ValueKey('instance-network-home-url'),
                  controller: controller.homeUrl,
                  label: l10n.instanceNetworkHomeUrl,
                  enabled: enabled,
                  keyboardType: TextInputType.url,
                  autofillHints: const [AutofillHints.url],
                  onChanged: (_) => controller.role = controller.role,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  key: const ValueKey('instance-network-home-key'),
                  controller: controller.homeKey,
                  label: l10n.instanceNetworkHomeKey,
                  enabled: enabled,
                  onChanged: (_) => controller.role = controller.role,
                  error: shape == null
                      ? null
                      : describe(l10n, 'network', shape.name),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
