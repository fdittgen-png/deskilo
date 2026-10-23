// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — Me › Me: who I am, who sees it, how the app speaks to me, and
// the doors to my own history — none of it any space's to decide.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/help/guide_site.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/app_spacing.dart';
import '../../auth/providers/sign_out.dart';
import '../../profile/presentation/screens/settings_screen.dart';
import '../../profile/presentation/widgets/settings_section_header.dart';
import '../../task_recorder/presentation/route_classification.dart'
    show taskWizardRoute;
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';
import 'blocked_people_card.dart';
import 'linked_visibility_card.dart';
import 'visibility_card.dart';

class MeAccountTab extends ConsumerStatefulWidget {
  const MeAccountTab({super.key});

  @override
  ConsumerState<MeAccountTab> createState() => _MeAccountTabState();
}

/// One section of the tab: the header the jump bar leads to, and what
/// follows it.
class _Section {
  const _Section(this.keyId, this.title, this.children);

  /// The jump button's key suffix (`me-section-<keyId>`): fixed per section,
  /// never its position, since recorded guides and tests name the button.
  final int keyId;
  final String title;
  final List<Widget> children;
}

class _MeAccountTabState extends ConsumerState<MeAccountTab> {
  /// How many sections [_sections] declares.
  static const _sectionCount = 6;

  final _anchors = List.generate(_sectionCount, (_) => GlobalKey());
  final _focus =
      List.generate(_sectionCount, (_) => FocusNode(skipTraversal: true));

  @override
  void dispose() {
    for (final node in _focus) { node.dispose(); }
    super.dispose();
  }

  Widget _header(_Section section, int index) => Focus(
    key: _anchors[index], focusNode: _focus[index],
    child: SettingsSectionHeader(section.title));

  void _jump(int index) {
    final target = _anchors[index].currentContext;
    if (target != null) {
      _focus[index].requestFocus();
      Scrollable.ensureVisible(target,
          duration: motionDuration(context, MotionTokens.standard));
    }
  }

  /// The sections in display order. #1846 — who others see, what is
  /// private to the account, the spaces it belongs to, the installations
  /// it uses, and last who sees what of me.
  List<_Section> _sections(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return [
      _Section(0, l10n.uxProfileSection, [
        ...accountSettingsTiles(context, ref, only: AccountTileGroup.profile),
      ]),
      _Section(2, l10n.uxPreferencesSection, [
        ...accountSettingsTiles(context, ref, only: AccountTileGroup.account),
        _Door('me-activity', Icons.account_balance_wallet_outlined,
            l10n.financesTitle, '/account-activity'),
      ]),
      _Section(3, l10n.uxAdvancedSection, [
        // The task wizard: recording, guides and tools in one place.
        if (ref
            .watch(enabledFeaturesSyncProvider)
            .contains(WorkspaceFeature.taskRecorder))
          _Door('me-task-wizard', Icons.assistant_navigation,
              l10n.taskWizardTitle, taskWizardRoute),
      ]),
      _Section(4, l10n.meGroupWorkspaces, [
        _Door('me-workspaces', Icons.workspaces_outline,
            l10n.meGroupWorkspaces, '/profiles'),
      ]),
      _Section(5, l10n.meGroupInstallations, [
        _Door('me-servers', Icons.dns_outlined,
            l10n.meWhereSpacesLive, '/connections'),
        ...accountSettingsTiles(context, ref,
            only: AccountTileGroup.installations),
        const Divider(),
        ListTile(
          key: const ValueKey('me-help'),
          leading: const Icon(Icons.help_outline),
          title: Text(l10n.helpTitle),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => openGuide(ref, context),
        ),
      ]),
      _Section(1, l10n.uxPrivacySection, [
        const VisibilityCard(),
        const LinkedVisibilityCard(),
        const BlockedPeopleCard(),
        _Door('me-privacy', Icons.shield_outlined,
            l10n.privacyTitle, '/privacy'),
        const Divider(),
        ListTile(
          key: const ValueKey('me-sign-out'),
          leading: Icon(Icons.logout, color: scheme.error),
          title: Text(
            l10n.authSignOut,
            style: TextStyle(color: scheme.error),
          ),
          onTap: () => signOutAndForget(ref),
        ),
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections(context);
    assert(sections.length == _sectionCount, 'one anchor per section');
    return Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
        key: const ValueKey('me-account-list'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // The jump bar heads the page and scrolls with it: one button per
          // section would take most of a phone's height at large text if it
          // stayed pinned above the list.
          Padding(
            padding: AppSpacing.smAll,
            child: Wrap(spacing: AppSpacing.xs, children: [
              for (final (index, section) in sections.indexed)
                TextButton(
                  key: ValueKey('me-section-${section.keyId}'),
                  onPressed: () => _jump(index),
                  child: Text(section.title),
                ),
            ]),
          ),
          for (final (index, section) in sections.indexed) ...[
            _header(section, index),
            ...section.children,
          ],
        ]),
      ),
        ),
      ),
    );
  }
}

/// A door out of the tab: a row that opens [path].
class _Door extends StatelessWidget {
  const _Door(this.tileKey, this.icon, this.title, this.path);

  final String tileKey;
  final IconData icon;
  final String title;
  final String path;

  @override
  Widget build(BuildContext context) => ListTile(
    key: ValueKey(tileKey),
    leading: Icon(icon),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => context.push(path),
  );
}
