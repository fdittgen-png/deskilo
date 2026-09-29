// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — who sees what of me, who can write to me, and a live "how
// others see me". It replaces the single per-server switch that used to
// sit at the top of the account messenger.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../l10n/app_localizations.dart';
import '../../workspace/domain/workspace.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/visibility.dart';
import '../providers/me_providers.dart';
import 'about_dialog.dart';
import 'visibility_labels.dart';
import 'visibility_preview.dart';

class VisibilityCard extends ConsumerWidget {
  const VisibilityCard({super.key});

  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    VisibilityField field,
    FieldAudience current,
  ) async {
    final l10n = AppLocalizations.of(context);
    final spaces =
        ref.read(myWorkspacesProvider).value ?? const <Workspace>[];
    final choice = await showModalBottomSheet<FieldAudience>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      builder: (_) =>
          _AudienceSheet(field: field, current: current, spaces: spaces),
    );
    if (choice == null || choice == current || !context.mounted) return;
    final ok = await runGuarded(
      context,
      domain: 'me',
      message: 'save visibility failed',
      errorText: l10n?.visibilitySaveFailed ??
          'Could not save who sees this. Please try again.',
      action: () => ref.read(meActionsProvider).choose(field, choice),
    );
    if (ok) ref.invalidate(myVisibilityProvider);
  }

  Future<void> _editAbout(
      BuildContext context, WidgetRef ref, MyVisibility current) async {
    final l10n = AppLocalizations.of(context);
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
      errorText: l10n?.visibilityAboutSaveFailed ??
          'Could not save your profession and bio. Please try again.',
      action: () => ref.read(meActionsProvider).saveAbout(about.$1, about.$2),
    );
    if (ok) ref.invalidate(myVisibilityProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final visibility =
        ref.watch(myVisibilityProvider).value ?? MyVisibility.defaults;
    Widget row(VisibilityField field) {
      final choice = visibility.of(field);
      return ListTile(
        key: ValueKey('visibility-field-${field.wire}'),
        leading: Icon(visibilityFieldIcon(field)),
        title: Text(visibilityFieldLabel(l10n, field)),
        subtitle: Text(audienceSummary(l10n, choice)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _choose(context, ref, field, choice),
      );
    }

    return Card(
      key: const ValueKey('me-visibility-card'),
      margin: AppSpacing.gutterAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(l10n?.visibilityTitle ?? 'Who sees me',
                style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text(l10n?.visibilityIntro ??
                'Each part of your account picks its own audience. '
                    'Nothing is public unless you choose it.'),
          ),
          ListTile(
            key: const ValueKey('visibility-about-edit'),
            leading: const Icon(Icons.edit_note_outlined),
            title: Text(l10n?.visibilityAboutMe ?? 'About me'),
            subtitle: Text(
              visibility.profession.isEmpty && visibility.bio.isEmpty
                  ? (l10n?.visibilityAboutEmpty ??
                      'Add your profession and a few words')
                  : [visibility.profession, visibility.bio]
                      .where((t) => t.isNotEmpty)
                      .join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _editAbout(context, ref, visibility),
          ),
          for (final field in VisibilityField.seen) row(field),
          const Divider(),
          row(VisibilityField.reachability),
          const Divider(),
          const VisibilityPreview(),
        ],
      ),
    );
  }
}

/// Picks one audience; "chosen spaces" also picks the spaces.
class _AudienceSheet extends StatefulWidget {
  const _AudienceSheet({
    required this.field,
    required this.current,
    required this.spaces,
  });

  final VisibilityField field;
  final FieldAudience current;
  final List<Workspace> spaces;

  @override
  State<_AudienceSheet> createState() => _AudienceSheetState();
}

class _AudienceSheetState extends State<_AudienceSheet> {
  late VisibilityAudience _audience = widget.current.audience;
  late final Set<String> _chosen = {...widget.current.workspaces};

  FieldAudience get _choice => FieldAudience(_audience, [
        for (final space in widget.spaces)
          if (_chosen.contains(space.id)) space.id,
      ]);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                  groupValue: _audience,
                  onChanged: (a) => setState(() => _audience = a ?? _audience),
                  child: Column(
                    children: [
                      for (final audience in VisibilityAudience.values)
                        RadioListTile<VisibilityAudience>(
                          key: ValueKey('visibility-audience-${audience.wire}'),
                          value: audience,
                          title: Text(audienceLabel(l10n, audience)),
                        ),
                    ],
                  ),
                ),
                if (_audience == VisibilityAudience.chosenSpaces)
                  for (final space in widget.spaces)
                    CheckboxListTile(
                      key: ValueKey('visibility-space-${space.id}'),
                      value: _chosen.contains(space.id),
                      title: Text(space.name),
                      onChanged: (on) => setState(() => on == true
                          ? _chosen.add(space.id)
                          : _chosen.remove(space.id)),
                    ),
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
              child: Text(l10n?.commonSave ?? 'Save'),
            ),
          ),
        ],
      ),
    );
  }
}
