// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/instance/instance_doctor.dart';
import '../../../../core/instance/management_api.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import 'instance_doctor_panel.dart';

/// Where a personal access token is created, and revoked.
const String supabaseTokensUrl = 'https://supabase.com/dashboard/account/tokens';

/// A wizard paragraph.
class WizardText extends StatelessWidget {
  const WizardText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text, style: style),
      );
}

/// A value a person copies elsewhere: a URL, a generated password.
class CopyableLink extends StatelessWidget {
  const CopyableLink(this.value, {super.key, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: SelectableText(value)),
        IconButton(
          key: const ValueKey('instance-done-step-copy'),
          tooltip: label,
          icon: const Icon(Icons.copy_outlined),
          onPressed: () => Clipboard.setData(ClipboardData(text: value)),
        ),
      ]);
}

/// The wizard's last step (#977): the endpoint, the doctor that must pass
/// before the device uses it (#1308 S3), and the token's revocation (S4).
class InstanceDoneStep extends StatelessWidget {
  const InstanceDoneStep({
    super.key,
    required this.endpoint,
    required this.api,
    required this.projectRef,
    required this.onChecked,
  });

  final ({String url, String key})? endpoint;
  final SupabaseManagement? api;
  final String? projectRef;
  final ValueChanged<List<DoctorFinding>> onChecked;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final e = endpoint;
    final (api, ref) = (this.api, projectRef);
    final keyPreview =
        e == null ? '' : '${e.key.substring(0, e.key.length.clamp(0, 18))}…';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WizardText(l10n.instanceDoneIntro),
        if (e != null) ...[
          CopyableLink(e.url, label: l10n.commonCopy),
          WizardText(keyPreview, style: const TextStyle(fontFamily: 'monospace')),
        ],
        if (api != null && ref != null) ...[
          WizardText(l10n.instanceDoctorIntro),
          InstanceDoctorPanel(api: api, projectRef: ref, onChecked: onChecked),
        ],
        const SizedBox(height: AppSpacing.sm),
        // #1308 S4 — the token reaches the whole account until revoked.
        WizardText(l10n.instanceRevokeToken),
        CopyableLink(supabaseTokensUrl, label: l10n.commonCopy),
      ],
    );
  }
}
