// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2211 (4) — who sees me on my other servers.
//
// A connected installation is the app signed in to another server with
// that server's own account; nothing federates. What people there see of
// me is what that account allows, so it is set THERE, through the same
// my_visibility / set_visibility calls the home card uses, with the same
// caps (contact details and presence never leave my spaces). Chosen
// spaces are not offered: the spaces to choose from live on that server.
//
// #2558 — these are "Legacy personal accounts": an expandable section of
// their own, apart from the personal home, whose changes do not change
// them. One change at a time is held unsaved for the account shown; moving
// to another account first asks to save it, discard it or keep editing,
// so a change never moves to another account.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/connected_installation_providers.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/loading_view.dart';
import '../../../core/ui/server_label.dart';
import '../domain/visibility.dart';
import '../providers/legacy_visibility_draft.dart';
import '../providers/me_providers.dart';
import 'visibility_flow.dart';
import 'visibility_labels.dart';

/// The legacy accounts, one shown at a time; nothing when there is none.
class LinkedVisibilityCard extends ConsumerWidget {
  const LinkedVisibilityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(connectedSourcesProvider).value ?? const [];
    if (sources.isEmpty) return const SizedBox.shrink();
    final words = context.l10n;
    final draft = ref.watch(legacyVisibilityDraftProvider);
    final urls = [for (final source in sources) source.endpoint.url];
    final shown = urls.contains(draft.source) ? draft.source! : urls.first;
    return Card(
      key: const ValueKey('me-linked-visibility-card'),
      margin: AppSpacing.gutterAll,
      child: ExpansionTile(
        key: const ValueKey('visibility-legacy'),
        title: Text(words.visibilityLegacyTitle),
        subtitle: Text(words.visibilityLegacyIntro),
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: AppSpacing.gutterAll,
            child: Text(words.visibilityElsewhereIntro),
          ),
          if (sources.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final source in sources)
                    ChoiceChip(
                      key: ValueKey('legacy-account-${source.endpoint.host}'),
                      label: Text(serverLabel(words, source.endpoint.url)),
                      selected: source.endpoint.url == shown,
                      onSelected: (_) => _switchTo(
                          context, ref, draft, shown, source.endpoint.url),
                    ),
                ],
              ),
            ),
          _LegacyAccount(
            key: ValueKey('legacy-account-panel-$shown'),
            source: shown,
            label: serverLabel(words, shown),
          ),
        ],
      ),
    );
  }

  /// Shows [target]; an unsaved change of [shown] is saved, discarded or
  /// kept (staying on [shown]) as the person decides first.
  Future<void> _switchTo(BuildContext context, WidgetRef ref,
      LegacyDraft draft, String shown, String target) async {
    final drafts = ref.read(legacyVisibilityDraftProvider.notifier);
    if (target == shown) return;
    if (!draft.dirty || draft.source != shown) return drafts.select(target);
    final words = context.l10n;
    final answer = await showDialog<_Dirty>(
      context: context,
      builder: (dialog) => AlertDialog(
        key: const ValueKey('legacy-dirty'),
        title: Text(words.visibilityLegacyDirtyTitle),
        content: SingleChildScrollView(
          child: Text(words.visibilityLegacyDirtyBody(
              visibilityFieldLabel(words, draft.field!),
              serverLabel(words, shown))),
        ),
        actions: [
          TextButton(
            key: const ValueKey('legacy-dirty-keep'),
            onPressed: () => Navigator.of(dialog).pop(_Dirty.keep),
            child: Text(words.visibilityLegacyKeepEditing),
          ),
          TextButton(
            key: const ValueKey('legacy-dirty-discard'),
            onPressed: () => Navigator.of(dialog).pop(_Dirty.discard),
            child: Text(words.visibilityLegacyDiscard),
          ),
          FilledButton(
            key: const ValueKey('legacy-dirty-save'),
            onPressed: () => Navigator.of(dialog).pop(_Dirty.save),
            child: Text(words.commonSave),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    switch (answer) {
      case _Dirty.discard:
        drafts.select(target);
      case _Dirty.save:
        final saved = ref.read(linkedVisibilityProvider(shown)).value;
        if (saved != null &&
            await _saveDraft(context, ref, draft, saved) &&
            context.mounted) {
          ref.read(legacyVisibilityDraftProvider.notifier).select(target);
        }
      case _Dirty.keep || null:
        return;
    }
  }

  /// Saves [draft] on its own account, asking first when it widens; true
  /// when the account holds it. A refusal or a cancelled question keeps it.
  static Future<bool> _saveDraft(BuildContext context, WidgetRef ref,
      LegacyDraft draft, MyVisibility saved) async {
    final source = draft.source!;
    final field = draft.field!;
    var offered = false;
    var done = false;
    await chooseAudience(
      context,
      field: field,
      current: saved.of(field),
      pick: (_) async {
        if (offered) return null;
        offered = true;
        return draft.choice;
      },
      save: (choice, _) async {
        await ref.read(meActionsProvider).chooseOn(source, field, choice);
        done = true;
      },
    );
    if (done && context.mounted) {
      ref.read(legacyVisibilityDraftProvider.notifier).discard();
      ref.invalidate(linkedVisibilityProvider(source));
    }
    return done;
  }
}

/// What to do with an unsaved change before moving to another account.
enum _Dirty { save, discard, keep }

/// The fields of my account on one legacy server, each with its audience,
/// and the one unsaved change of it.
class _LegacyAccount extends ConsumerWidget {
  const _LegacyAccount({super.key, required this.source, required this.label});

  final String source;

  /// How the server is named to the person ([serverLabel]).
  final String label;

  /// The audiences this field may have on another server: chosen spaces
  /// are not offered, the spaces to choose from live there.
  Future<FieldAudience?> _pick(
    BuildContext context,
    VisibilityField field,
    FieldAudience current,
  ) async {
    final words = context.l10n;
    final picked = await showDialog<VisibilityAudience>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: Text(visibilityFieldLabel(words, field)),
        children: [
          for (final audience in field.allowedAudiences)
            if (audience != VisibilityAudience.chosenSpaces)
              ListTile(
                key: ValueKey('linked-visibility-audience-${audience.wire}'),
                leading: Icon(
                  audience == current.audience
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(audienceLabel(words, audience)),
                onTap: () => Navigator.of(dialog).pop(audience),
              ),
        ],
      ),
    );
    return picked == null ? null : FieldAudience(picked);
  }

  /// Holds the audience picked for [field] as this account's unsaved
  /// change; picking the saved one again drops the change.
  Future<void> _edit(BuildContext context, WidgetRef ref,
      VisibilityField field, FieldAudience saved, LegacyDraft draft) async {
    final start = draft.field == field ? draft.choice! : saved;
    final picked = await _pick(context, field, start);
    if (picked == null || !context.mounted) return;
    final drafts = ref.read(legacyVisibilityDraftProvider.notifier);
    picked == saved ? drafts.discard() : drafts.edit(source, field, picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final words = context.l10n;
    final read = ref.watch(linkedVisibilityProvider(source));
    final all = ref.watch(legacyVisibilityDraftProvider);
    final draft =
        all.dirty && all.source == source ? all : const LegacyDraft();
    return Column(
      key: const ValueKey('linked-visibility-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: Text(
            words.visibilityOnServer(label),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        if (read.hasError)
          InlineBanner(
            key: const ValueKey('linked-visibility-unavailable'),
            icon: Icons.cloud_off_outlined,
            text: words.visibilityOnServerUnavailable(label),
            actionLabel: words.commonRetry,
            onAction: () => ref.invalidate(linkedVisibilityProvider(source)),
          )
        else if (read.value case final visibility?) ...[
          for (final field in [
            ...VisibilityField.seen,
            VisibilityField.reachability,
          ])
            ListTile(
              key: ValueKey('linked-visibility-field-${field.wire}'),
              leading: Icon(visibilityFieldIcon(field)),
              title: Text(visibilityFieldLabel(words, field)),
              subtitle: Text(draft.field == field
                  ? words.visibilityLegacyUnsaved(
                      audienceSummary(words, draft.choice!))
                  : audienceSummary(words, visibility.of(field))),
              trailing: const Icon(Icons.chevron_right),
              // One field at a time: another waits for this change.
              enabled: draft.field == null || draft.field == field,
              onTap: () =>
                  _edit(context, ref, field, visibility.of(field), draft),
            ),
          if (draft.dirty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: AppSpacing.sm,
                children: [
                  TextButton(
                    key: const ValueKey('legacy-draft-discard'),
                    onPressed: () => ref
                        .read(legacyVisibilityDraftProvider.notifier)
                        .discard(),
                    child: Text(words.visibilityLegacyDiscard),
                  ),
                  FilledButton(
                    key: const ValueKey('legacy-draft-save'),
                    onPressed: () => LinkedVisibilityCard._saveDraft(
                        context, ref, draft, visibility),
                    child: Text(words.commonSave),
                  ),
                ],
              ),
            ),
        ] else
          const LoadingView(),
      ],
    );
  }
}
