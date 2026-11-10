// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3549/#3550 — "What kind of business is it?": the kinds (name and one
// line each, the primary first), the optional further kinds below a
// divider, and what the chosen kind proposes, in plain sentences with a
// "Show all" behind each. A feature that is not yet stable is switched on
// only when ticked (the Features screen's consent words). Save writes the
// kind and the confirmed features; Cancel changes nothing.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/business_kind.dart';
import '../../domain/business_kind_proposal.dart';
import '../../domain/feature_flags_write.dart';
import '../../domain/feature_lifecycle.dart';
import '../../domain/feature_operation.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_feature.dart';
import '../../domain/workspace_permission.dart';
import '../../providers/business_kind_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/workspace_providers.dart';
import '../feature_names.dart';
import 'feature_maturity_badge.dart';

/// The name of the kind [code] (the code itself for a kind this app does
/// not know yet).
String _businessKindName(AppLocalizations l10n, String code) => switch (code) {
  'coworking' => l10n.businessKindNameCoworking,
  'studio' => l10n.businessKindNameStudio,
  'practice' => l10n.businessKindNamePractice,
  'salon' => l10n.businessKindNameSalon,
  'service' => l10n.businessKindNameService,
  _ => code,
};

String _kindDescription(AppLocalizations l10n, String code) => switch (code) {
  'coworking' => l10n.businessKindDescCoworking,
  'studio' => l10n.businessKindDescStudio,
  'practice' => l10n.businessKindDescPractice,
  'salon' => l10n.businessKindDescSalon,
  'service' => l10n.businessKindDescService,
  _ => '',
};

/// The first three names, then "and N more".
String _shortList(AppLocalizations l10n, List<String> names) =>
    names.length <= 3
    ? names.join(', ')
    : l10n.businessKindAndMore(names.take(3).join(', '), names.length - 3);

/// What the owner has chosen so far, and what it proposes.
class _Choice {
  _Choice(
    this.kinds,
    this.workspace, {
    required this.kind,
    required List<String> more,
  }) : more = {...more},
       raw = resolveEnabledFeatures(workspace.featureFlags);

  final List<BusinessKind> kinds;
  final Workspace workspace;
  final Set<WorkspaceFeature> raw;
  String kind;
  final Set<String> more;
  final Set<WorkspaceFeature> ticked = {};

  void choose(String code) {
    kind = code;
    more.remove(code);
    ticked.clear();
  }

  BusinessKindProposal get proposal => proposalFor(
    profile: {
      for (final k in kinds)
        if (k.code == kind) ...k.profile,
    },
    raw: raw,
    country: workspace.countryCode,
  );

  /// The proposal's flags, less a feature needing consent left unticked.
  Map<String, bool> get flags => {
    for (final e in proposal.flags.entries)
      if (!_needsConsent(e.key, e.value) ||
          ticked.contains(WorkspaceFeature.values.byName(e.key)))
        e.key: e.value,
  };

  List<String> get moreKinds => [
    for (final k in kinds)
      if (more.contains(k.code)) k.code,
  ];
}

List<Widget> _fields(
  AppLocalizations l10n,
  _Choice choice,
  VoidCallback refresh,
) => [
  for (final k in choice.kinds)
    _KindTile(
      kind: k,
      selected: k.code == choice.kind,
      // recorder-key-exempt: forwarded to the ListTile keyed business-kind-<code>
      onTap: () {
        choice.choose(k.code);
        refresh();
      },
    ),
  const Divider(),
  FormSection(
    title: l10n.businessKindMoreTitle,
    children: [
      for (final k in choice.kinds)
        if (k.code != choice.kind)
          CheckboxListTile(
            key: ValueKey('business-kind-more-${k.code}'),
            value: choice.more.contains(k.code),
            title: Text(_businessKindName(l10n, k.code)),
            onChanged: (v) {
              if (!choice.more.remove(k.code)) choice.more.add(k.code);
              refresh();
            },
          ),
    ],
  ),
  const Divider(),
  _ProposalView(
    proposal: choice.proposal,
    ticked: choice.ticked,
    onTick: (f) {
      if (!choice.ticked.remove(f)) choice.ticked.add(f);
      refresh();
    },
  ),
];

/// Whether switching [key] to [value] asks for consent (#1851 A).
bool _needsConsent(String key, bool value) =>
    value && featureNeedsOptIn(WorkspaceFeature.values.byName(key));

class _KindTile extends StatelessWidget {
  const _KindTile({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final BusinessKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListTile(
      key: ValueKey('business-kind-${kind.code}'),
      selected: selected,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      ),
      title: Text(
        _businessKindName(l10n, kind.code),
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Text(_kindDescription(l10n, kind.code)),
      onTap: onTap,
    );
  }
}

class _ProposalView extends StatelessWidget {
  const _ProposalView({
    required this.proposal,
    required this.ticked,
    required this.onTick,
  });

  final BusinessKindProposal proposal;
  final Set<WorkspaceFeature> ticked;

  /// Flips whether [feature] is ticked.
  final void Function(WorkspaceFeature feature) onTick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (proposal.isEmpty) {
      return Text(
        l10n.businessKindNoChange,
        key: const ValueKey('business-kind-no-change'),
      );
    }
    final consent = [
      for (final f in proposal.switchesOn)
        if (featureNeedsOptIn(f)) f,
    ];
    final on = [
      for (final f in proposal.switchesOn)
        if (!consent.contains(f)) f,
    ];
    final off = proposal.switchesOff;
    final placesOff = off.contains(WorkspaceFeature.placeBooking);
    List<String> names(List<WorkspaceFeature> fs) => [
      for (final f in fs) featureName(l10n, f),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (on.isNotEmpty)
          _Sentence(
            id: 'on',
            text: l10n.businessKindSwitchesOn(_shortList(l10n, names(on))),
            all: names(on),
          ),
        if (off.isNotEmpty)
          _Sentence(
            id: 'off',
            text: l10n.businessKindSwitchesOff(
              placesOff
                  ? l10n.businessKindPlacesOff(off.length)
                  : _shortList(l10n, names(off)),
            ),
            all: names(off),
          ),
        if (consent.isNotEmpty) ...[
          const FormGap(),
          Text(
            l10n.businessKindConsentTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final f in consent)
            CheckboxListTile(
              key: ValueKey('business-kind-consent-${f.name}'),
              value: ticked.contains(f),
              title: Text(
                l10n.featureOptInStage(
                  featureName(l10n, f),
                  featureMaturityLabel(l10n, featureAssessmentOf(f).maturity),
                ),
              ),
              onChanged: (_) => onTick(f),
            ),
          Text(l10n.businessKindConsentLater),
        ],
      ],
    );
  }
}

/// One sentence of the proposal, with "Show all" listing every name.
class _Sentence extends StatelessWidget {
  const _Sentence({required this.id, required this.text, required this.all});

  /// 'on' or 'off': the sentence's key is `business-kind-<id>`.
  final String id;

  final String text;
  final List<String> all;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: ValueKey('business-kind-$id'),
    tilePadding: EdgeInsets.zero,
    title: Text(text),
    subtitle: Text(context.l10n.businessKindShowAll),
    children: [
      for (final name in all) ListTile(dense: true, title: Text(name)),
    ],
  );
}

/// The kind of business, one tap from changing it: shown to whoever may
/// change the workspace's configuration, in settings and on the setup
/// guide's first step.
class BusinessKindTile extends ConsumerWidget {
  const BusinessKindTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final may = ref
        .watch(myPermissionsProvider)
        .contains(WorkspacePermission.manageConfiguration);
    if (workspace == null || !may) return const SizedBox.shrink();
    final l10n = context.l10n;
    final profile = ref.watch(businessProfileProvider).value;
    return ListTile(
      key: const ValueKey('business-kind-tile'),
      leading: const Icon(Icons.storefront_outlined),
      title: Text(l10n.businessKindTitle),
      subtitle: profile == null
          ? null
          : Text(
              [for (final k in profile.kinds) _businessKindName(l10n, k)]
                  .join(' · '),
            ),
      trailing: HelpDot(
        l10n.businessKindTitle,
        anchor: HelpAnchor.workspaceBusinessKind,
      ),
      onTap: () => _open(context, ref, workspace: workspace),
    );
  }

  /// Opens the chooser for [workspace]. Returns whether it saved.
  Future<bool> _open(
    BuildContext context,
    WidgetRef ref, {
    required Workspace workspace,
  }) async {
    final l10n = context.l10n;
    final kinds = await ref.read(businessKindsProvider.future);
    final current = await ref.read(businessProfileProvider.future);
    if (!context.mounted) return false;
    final choice = _Choice(
      kinds,
      workspace,
      kind: current.kind,
      more: current.moreKinds,
    );
    return showAppFormSheet(
      context,
      AppFormSheet(
        title: l10n.businessKindTitle,
        submitLabel: l10n.commonSave,
        submitKey: const ValueKey('business-kind-save'),
        onSubmit: () => _save(ref, l10n, choice),
        builder: (context, refresh) => _fields(l10n, choice, refresh),
      ),
    );
  }

  /// Saves [choice]; null when saved, else what to say.
  Future<String?> _save(
    WidgetRef ref,
    AppLocalizations l10n,
    _Choice choice,
  ) async {
    try {
      await ref
          .read(businessKindCommandsProvider)
          .save(
            choice.workspace.id,
            kind: choice.kind,
            moreKinds: choice.moreKinds,
            flags: choice.flags,
            raw: choice.raw,
          );
    } on FeatureFlagsConflict catch (e, st) {
      TraceLogger.instance.warn(
        'workspace',
        'business kind features conflicted',
        error: e,
        stackTrace: st,
      );
      ref.invalidate(myWorkspacesProvider);
      return l10n.featureChangedMeanwhile;
    } on Exception catch (e, st) {
      TraceLogger.instance.error(
        'workspace',
        'business kind not saved',
        error: e,
        stackTrace: st,
      );
      return l10n.processChangeFailed;
    }
    ref
      ..invalidate(currentSettingsProvider)
      ..invalidate(businessProfileProvider)
      ..invalidate(myWorkspacesProvider);
    try {
      await ref.read(myWorkspacesProvider.future);
    } on Exception catch (e, st) {
      TraceLogger.instance.warn(
        'workspace',
        'business kind features unconfirmed',
        error: e,
        stackTrace: st,
      );
      return l10n.featureChangeUnconfirmed;
    }
    return null;
  }
}
