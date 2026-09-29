// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — "how others see me", live: the server's own answer for the
// audience picked (`preview_my_account`), re-asked after every change.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/visibility.dart';
import '../providers/me_providers.dart';
import 'visibility_labels.dart';

class VisibilityPreview extends ConsumerStatefulWidget {
  const VisibilityPreview({super.key});

  @override
  ConsumerState<VisibilityPreview> createState() => _VisibilityPreviewState();
}

class _VisibilityPreviewState extends ConsumerState<VisibilityPreview> {
  PreviewAudience _as = PreviewAudience.mySpaces;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final view = ref.watch(visibilityPreviewProvider(_as));
    return Padding(
      padding: AppSpacing.gutterAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n?.visibilityPreviewTitle ?? 'How others see me',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final as in PreviewAudience.values)
                ChoiceChip(
                  key: ValueKey('visibility-preview-as-${as.wire}'),
                  label: Text(previewAudienceLabel(l10n, as)),
                  selected: _as == as,
                  onSelected: (_) => setState(() => _as = as),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          switch (view) {
            AsyncData(:final value) => _Preview(view: value),
            AsyncError() => Text(l10n?.visibilityPreviewFailed ??
                'The preview could not be loaded.'),
            _ => const LoadingView(),
          },
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.view});

  final AccountView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget line(String key, IconData icon, String text) => ListTile(
          key: ValueKey(key),
          dense: true,
          leading: Icon(icon),
          title: Text(text),
        );
    return DecoratedBox(
      key: const ValueKey('visibility-preview'),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (view.isEmpty)
            Padding(
              padding: AppSpacing.gutterAll,
              child: Text(
                l10n?.visibilityPreviewNothing ?? 'They see nothing of you.',
                key: const ValueKey('visibility-preview-nothing'),
                style: TextStyle(color: muted),
              ),
            ),
          if (view.name case final name?)
            line('visibility-preview-name', Icons.badge_outlined, name),
          if (view.profession case final profession?)
            line('visibility-preview-profession', Icons.work_outline, profession),
          if (view.bio case final bio?)
            line('visibility-preview-bio', Icons.notes_outlined, bio),
          if (view.whatsapp case final whatsapp?)
            line('visibility-preview-whatsapp', Icons.chat_outlined, whatsapp),
          if (view.email case final email?)
            line('visibility-preview-email', Icons.alternate_email, email),
          if (view.presence case final presence?)
            line('visibility-preview-presence', Icons.location_on_outlined,
                presence),
          line(
            'visibility-preview-reach',
            view.canMessage ? Icons.forum_outlined : Icons.speaker_notes_off_outlined,
            view.canMessage
                ? (l10n?.visibilityPreviewCanWrite ?? 'Can start a conversation with you')
                : (l10n?.visibilityPreviewCannotWrite ??
                    'Cannot start a conversation with you'),
          ),
        ],
      ),
    );
  }
}
