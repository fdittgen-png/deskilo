// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4205 -- what connecting an external assistant discloses, said once before the
// authorization (the connect screen and the consent screen): its answers are
// processed by the assistant's provider under its own terms, self-hosting does not
// make that local, and revoking stops future requests without recalling what was
// received. It links the privacy notice. It asks for no consent and grants nothing:
// the existing approval, workspace choice and revocation controls stay as they are.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/links/link_launcher.dart';
import '../../../core/privacy/privacy_policy.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/adaptive/page_measures.dart';

class AssistantDisclosureNote extends ConsumerWidget {
  const AssistantDisclosureNote({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // The note stays inside the reading measure whatever the window is: a line
    // of text wider than that is not read (the desk guards measure it).
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kReadingColumnWidth),
          child: Column(
            key: const ValueKey('assistant-disclosure'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.assistantFlowsBody,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton.icon(
                key: const ValueKey('assistant-disclosure-link'),
                onPressed: () => ref.read(linkLauncherProvider)(
                  Uri.parse(kPrivacyPolicyPageUrl),
                ),
                icon: const Icon(Icons.policy_outlined, size: 18),
                label: Text(l10n.assistantFlowsPolicyLink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
