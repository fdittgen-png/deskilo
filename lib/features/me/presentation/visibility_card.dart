// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — who sees what of me, who can write to me, and a live "how
// others see me". It replaces the single per-server switch that used to
// sit at the top of the account messenger.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/loading_view.dart';
import '../domain/audience_space.dart';
import '../domain/visibility.dart';
import '../providers/audience_spaces_provider.dart';
import '../providers/me_providers.dart';
import 'about_dialog.dart';
import 'public_profile_tile.dart';
import 'visibility_flow.dart';
import 'visibility_labels.dart';
import 'visibility_preview.dart';

class VisibilityCard extends ConsumerWidget {
  const VisibilityCard({super.key});

  Future<void> _editAbout(
      BuildContext context, WidgetRef ref, MyVisibility current) async {
    final l10n = context.l10n;
    final about = await showDialog<(String, String)>(
      context: context,
      builder: (_) =>
          AboutMeDialog(profession: current.profession, bio: current.bio),
    );
    if (about == null || !context.mounted) return;
    final ok = await runGuarded(
      context,
      domain: 'me',
      message: 'save about failed',
      errorText: l10n.visibilityAboutSaveFailed,
      action: () => ref.read(meActionsProvider).saveAbout(about.$1, about.$2),
    );
    if (ok) ref.invalidate(myVisibilityProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // #2558 — what the personal home saved, or why it cannot be shown: a
    // failed read never falls back to the defaults as if they were saved,
    // and nothing is edited from a value that could not be read.
    final read = ref.watch(myVisibilityProvider);
    Widget row(MyVisibility visibility, VisibilityField field) {
      final choice = visibility.of(field);
      return ListTile(
        key: ValueKey('visibility-field-${field.wire}'),
        leading: Icon(visibilityFieldIcon(field)),
        title: Text(visibilityFieldLabel(l10n, field)),
        subtitle: Text(audienceSummary(l10n, choice)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => chooseAudience(
          context,
          field: field,
          current: choice,
          pick: () => showAppSheet<FieldAudience>(
            context: context,
            isScrollControlled: true,
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.85),
            builder: (_) => _AudienceSheet(field: field, current: choice),
          ),
          save: (picked) => ref.read(meActionsProvider).choose(field, picked),
          reread: () => ref.invalidate(myVisibilityProvider),
        ),
      );
    }

    return Card(
      key: const ValueKey('me-visibility-card'),
      margin: AppSpacing.gutterAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(l10n.visibilityTitle,
                style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text(l10n.visibilityIntro),
          ),
          if (read.hasError)
            InlineBanner(
              key: const ValueKey('visibility-unavailable'),
              icon: Icons.cloud_off_outlined,
              text: l10n.visibilityUnavailable,
              actionLabel: l10n.commonRetry,
              onAction: () => ref.invalidate(myVisibilityProvider),
            )
          else if (read.value case final visibility?) ...[
            ListTile(
              key: const ValueKey('visibility-about-edit'),
              leading: const Icon(Icons.edit_note_outlined),
              title: Text(l10n.visibilityAboutMe),
              subtitle: Text(
                visibility.profession.isEmpty && visibility.bio.isEmpty
                    ? (l10n.visibilityAboutEmpty)
                    : [visibility.profession, visibility.bio]
                        .where((t) => t.isNotEmpty)
                        .join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _editAbout(context, ref, visibility),
            ),
            for (final field in VisibilityField.seen) row(visibility, field),
            const Divider(),
            row(visibility, VisibilityField.reachability),
          ] else
            const LoadingView(),
          const Divider(),
          // #2211 — the one switch that shows anything to people who are
          // not signed in.
          const PublicProfileTile(),
          if (read.hasValue && !read.hasError) ...[
            const Divider(),
            const VisibilityPreview(),
          ],
        ],
      ),
    );
  }
}

/// Picks one audience; "chosen spaces" also picks the spaces.
/// #2558 — the spaces come from the personal home's list; a saved space
/// the list no longer names stays chosen and visible until it is unticked.
class _AudienceSheet extends ConsumerStatefulWidget {
  const _AudienceSheet({required this.field, required this.current});

  final VisibilityField field;
  final FieldAudience current;

  @override
  ConsumerState<_AudienceSheet> createState() => _AudienceSheetState();
}

class _AudienceSheetState extends ConsumerState<_AudienceSheet> {
  late VisibilityAudience _audience = widget.current.audience;
  late final Set<String> _chosen = {...widget.current.workspaces};

  FieldAudience get _choice => FieldAudience(_audience, {..._chosen});

  Widget _space(String id, String name) => CheckboxListTile(
        key: ValueKey('visibility-space-$id'),
        value: _chosen.contains(id),
        title: Text(name),
        onChanged: (on) => setState(
            () => on == true ? _chosen.add(id) : _chosen.remove(id)),
      );

  List<Widget> _spaces(BuildContext context) {
    final l10n = context.l10n;
    final listed = ref.watch(audienceSpacesProvider);
    if (listed.hasError) {
      return [
        InlineBanner(
          key: const ValueKey('visibility-spaces-unavailable'),
          icon: Icons.cloud_off_outlined,
          text: l10n.visibilitySpacesUnavailable,
          actionLabel: l10n.commonRetry,
          onAction: () => ref.invalidate(audienceSpacesProvider),
        ),
        for (final id in _chosen.toList()..sort())
          _space(id, l10n.visibilitySpaceUnlisted),
      ];
    }
    final spaces = listed.value;
    if (spaces == null) return const [LoadingView()];
    final unlisted = unlistedChoices(_chosen, spaces);
    return [
      if (spaces.isEmpty && unlisted.isEmpty)
        ListTile(
          key: const ValueKey('visibility-no-spaces'),
          title: Text(l10n.visibilityNoSpaces),
        ),
      for (final AudienceSpace(:id, :name) in spaces) _space(id, name),
      for (final id in unlisted) _space(id, l10n.visibilitySpaceUnlisted),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(visibilityFieldLabel(l10n, widget.field),
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                RadioGroup<VisibilityAudience>(
                  key: const ValueKey('visibility-card-radio-group'),
                  groupValue: _audience,
                  onChanged: (a) => setState(() => _audience = a ?? _audience),
                  child: Column(
                    children: [
                      for (final audience in widget.field.allowedAudiences)
                        RadioListTile<VisibilityAudience>(
                          key: ValueKey('visibility-audience-${audience.wire}'),
                          value: audience,
                          title: Text(audienceLabel(l10n, audience)),
                        ),
                    ],
                  ),
                ),
                if (_audience == VisibilityAudience.chosenSpaces)
                  ..._spaces(context),
              ],
            ),
          ),
          Padding(
            padding: AppSpacing.gutterAll,
            child: FilledButton(
              key: const ValueKey('visibility-save'),
              onPressed: _choice.incomplete
                  ? null
                  : () => Navigator.of(context).pop(_choice),
              child: Text(l10n.commonSave),
            ),
          ),
        ],
      ),
    );
  }
}
