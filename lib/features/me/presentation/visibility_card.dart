// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — who sees what of me, who can write to me, and a live "how
// others see me". It replaces the single per-server switch that used to
// sit at the top of the account messenger.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_settings.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/loading_view.dart';
import '../domain/audience_space.dart';
import '../domain/visibility.dart';
import '../domain/visibility_write.dart';
import '../providers/audience_spaces_provider.dart';
import '../providers/me_providers.dart';
import '../providers/visibility_epoch_provider.dart';
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

  /// #2558 C2 — the checked write: [read] holds the value the person last
  /// read (or reviewed after a conflict) for [field]. A reply of an older
  /// account or home is ignored; a conflict rereads the card and goes on to
  /// the review.
  Future<void> _save(BuildContext context, WidgetRef ref,
      VisibilityField field, MyVisibility read, FieldAudience picked) async {
    try {
      final saved = await ref.read(meActionsProvider).choose(
            field,
            picked,
            saved: read,
            epoch: () =>
                context.mounted ? ref.read(visibilityEpochProvider) : '',
          );
      if (saved != null && context.mounted) {
        ref.invalidate(myVisibilityProvider);
      }
    } on VisibilityConflict {
      if (context.mounted) ref.invalidate(myVisibilityProvider);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // #2558 — what the personal home saved, or why it cannot be shown: a
    // failed read never falls back to the defaults as if they were saved,
    // and nothing is edited from a value that could not be read.
    final read = ref.watch(myVisibilityProvider);
    // The home's own address names it: the account, not a selected space.
    final home = ref.watch(activeBackendProvider).value?.host;
    // The spaces' names, for the widening question; kept while the card is.
    final listed = read.hasValue && !read.hasError
        ? ref.watch(audienceSpacesProvider).value ?? const <AudienceSpace>[]
        : const <AudienceSpace>[];
    String spaceName(String id) => audienceSpaceLabel(
        l10n, listed.where((space) => space.id == id).firstOrNull);

    Widget row(MyVisibility visibility, VisibilityField field,
        {String? question}) {
      final choice = visibility.of(field);
      return ListTile(
        key: ValueKey('visibility-field-${field.wire}'),
        leading: Icon(visibilityFieldIcon(field)),
        title: Text(question ?? visibilityFieldLabel(l10n, field)),
        subtitle: Text(audienceSummary(l10n, choice)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => chooseAudience(
          context,
          field: field,
          current: choice,
          pick: (start) => showAppSheet<FieldAudience>(
            context: context,
            isScrollControlled: true,
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.85),
            builder: (_) => _AudienceSheet(field: field, current: start),
          ),
          save: (picked, expected) =>
              _save(context, ref, field, visibility.withField(field, expected), picked),
          spaceName: spaceName,
        ),
      );
    }

    Widget question(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
          child: Text(text, style: Theme.of(context).textTheme.labelLarge),
        );

    final editor = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(l10n.visibilityTitle,
                style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text(l10n.visibilityIntro),
          ),
          if (home != null && home.isNotEmpty)
            ListTile(
              key: const ValueKey('visibility-home'),
              leading: const Icon(Icons.home_outlined),
              title: Text(l10n.visibilityHomeHeader(home)),
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
            // The three answers most people look for, saved values first.
            row(visibility, VisibilityField.contactChannels,
                question: l10n.visibilityAskContact),
            row(visibility, VisibilityField.reachability,
                question: l10n.visibilityAskWrite),
          ] else
            const LoadingView(),
          // #2211 — the one switch that shows anything to people who are
          // not signed in.
          question(l10n.visibilityAskPublic),
          const PublicProfileTile(),
          if (read.value case final visibility? when !read.hasError)
            ExpansionTile(
              key: const ValueKey('visibility-more'),
              title: Text(l10n.visibilityMoreSharing),
              children: [
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
                for (final field in VisibilityField.seen)
                  if (field != VisibilityField.contactChannels)
                    row(visibility, field),
              ],
            ),
        ],
      );
    final previewed = read.hasValue && !read.hasError;
    return Card(
      key: const ValueKey('me-visibility-card'),
      margin: AppSpacing.gutterAll,
      // #2558 — wide: the editor and the saved preview side by side, 60:40;
      // otherwise the preview follows the editor.
      child: LayoutBuilder(
        builder: (context, box) => previewed && box.maxWidth >= _wideCard
            ? Row(
                key: const ValueKey('visibility-wide'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: editor),
                  const Expanded(flex: 4, child: VisibilityPreview()),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  editor,
                  if (previewed) ...[
                    const Divider(),
                    const VisibilityPreview(),
                  ],
                ],
              ),
      ),
    );
  }
}

/// The card width from which the saved preview sits beside the editor.
const double _wideCard = 900;

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

  /// One space: its name, and when it needs it where it lives (a name
  /// another space shares) and whether the home can verify it. A space on
  /// another installation is chosen while its membership fact is in force.
  Widget _space(String id, AudienceSpace? space, {bool ambiguous = false}) {
    final l10n = context.l10n;
    final chosen = _chosen.contains(id);
    final notes = [
      if (space != null && !space.verified) l10n.visibilitySpaceUnverified,
      if (space != null && ambiguous)
        l10n.visibilitySpaceAmbiguous(audienceSpaceSource(l10n, space)),
    ];
    // A saved space can always be unticked (narrowing needs no
    // verification); only a selectable one added.
    final enabled = space == null ? chosen : space.selectable || chosen;
    return CheckboxListTile(
      key: ValueKey('visibility-space-$id'),
      value: chosen,
      title: Text(audienceSpaceLabel(l10n, space)),
      subtitle: notes.isEmpty ? null : Text(notes.join(' · ')),
      enabled: enabled,
      onChanged: enabled
          ? (on) => setState(
              () => on == true ? _chosen.add(id) : _chosen.remove(id))
          : null,
    );
  }

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
        for (final id in _chosen.toList()..sort()) _space(id, null),
      ];
    }
    final spaces = listed.value;
    if (spaces == null) return const [LoadingView()];
    // Offered: what can be chosen, what is chosen, and the spaces elsewhere
    // the home cannot verify yet; a space of this home I hold no active
    // membership in is not offered.
    final shown = [
      for (final space in spaces)
        if (space.selectable ||
            !space.hostedHere ||
            _chosen.contains(space.id))
          space,
    ];
    final ambiguous = ambiguousNames(shown);
    final unlisted = unlistedChoices(_chosen, spaces);
    return [
      if (!shown.any((space) => space.selectable) && _chosen.isEmpty)
        ListTile(
          key: const ValueKey('visibility-no-spaces'),
          title: Text(l10n.visibilityNoSpaces),
        ),
      for (final space in shown)
        _space(space.id, space, ambiguous: ambiguous.contains(space.id)),
      for (final id in unlisted) _space(id, null),
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
