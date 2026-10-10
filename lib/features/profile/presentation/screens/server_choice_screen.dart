// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/backend/backend_settings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../widgets/backend_candidate_form.dart';
import 'new_instance_screen.dart';

/// #2343 — the first start of a build that ships no default server (the
/// F-Droid build). Nothing has been contacted yet; the person picks where
/// their spaces live, and only that choice is ever reached:
///
/// - the reference deployment, by name — one server among many;
/// - a server that already exists, from its code or its URL and
///   publishable key, tested before it can be saved;
/// - a new server, built by the instance wizard on the person's own
///   Supabase account.
///
/// [onChosen] stores the endpoint and starts the app on it.
class ServerChoiceScreen extends StatelessWidget {
  const ServerChoiceScreen({super.key, required this.onChosen});

  final Future<void> Function(BackendEndpoint endpoint) onChosen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    Widget section({
      required String key,
      required String title,
      required List<Widget> children,
    }) => Card(
      key: ValueKey(key),
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: text.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            ...children,
          ],
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.serverChoiceTitle)),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.gutterAll,
          children: [
            Text(l10n.serverChoiceIntro),
            const SizedBox(height: AppSpacing.lg),
            section(
              key: 'server-choice-reference',
              title: l10n.serverChoiceReferenceTitle,
              children: [
                Text(l10n.serverChoiceReferenceBody),
                const SizedBox(height: AppSpacing.xs),
                Text(referenceEndpoint.host, style: text.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  key: const ValueKey('server-choice-use-reference'),
                  onPressed: () => onChosen(referenceEndpoint),
                  child: Text(l10n.serverChoiceReferenceAction),
                ),
              ],
            ),
            section(
              key: 'server-choice-existing',
              title: l10n.serverChoiceExistingTitle,
              children: [
                BackendCandidateForm(
                  topic: l10n.helpTopicServer,
                  isDefault: false,
                  initial: null,
                  offerDefault: false,
                  onApply: (endpoint) =>
                      onChosen(endpoint ?? referenceEndpoint),
                  onVerified: (_) {},
                ),
              ],
            ),
            section(
              key: 'server-choice-new',
              title: l10n.serverChoiceNewTitle,
              children: [
                Text(l10n.serverChoiceNewBody),
                const SizedBox(height: AppSpacing.sm),
                FilledButton.tonalIcon(
                  key: const ValueKey('server-choice-new-instance'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => NewInstanceScreen(onFinish: onChosen),
                    ),
                  ),
                  icon: const Icon(Icons.auto_fix_high_outlined),
                  label: Text(l10n.instanceCreateButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
