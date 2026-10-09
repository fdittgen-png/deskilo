// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — Me › Me: who I am, who sees it, how the app speaks to me, and
// the doors to my own history — none of it any space's to decide.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/motion/motion.dart';
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

class _MeAccountTabState extends ConsumerState<MeAccountTab> {
  final _sections = List.generate(4, (_) => GlobalKey());
  final _sectionFocus = List.generate(4, (_) => FocusNode(skipTraversal: true));

  @override
  void dispose() {
    for (final node in _sectionFocus) { node.dispose(); }
    super.dispose();
  }

  Widget _header(String title, int index) => Focus(
    key: _sections[index], focusNode: _sectionFocus[index],
    child: SettingsSectionHeader(title));

  void _jump(int index) {
    final target = _sections[index].currentContext;
    if (target != null) {
      _sectionFocus[index].requestFocus();
      Scrollable.ensureVisible(target,
          duration: motionDuration(context, MotionTokens.standard));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final words = l10n ?? AppLocalizationsEn();
    final labels = [(0, words.uxProfileSection), (2, words.uxPreferencesSection),
      (3, words.uxAdvancedSection), (1, words.uxPrivacySection)];
    final scheme = Theme.of(context).colorScheme;
    Widget door(String key, IconData icon, String title, String path) =>
        ListTile(
          key: ValueKey(key),
          leading: Icon(icon),
          title: Text(title),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(path),
        );
    return Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(children: [
            Padding(
              padding: AppSpacing.smAll,
              child: Wrap(spacing: AppSpacing.xs, children: [
                for (final (index, label) in labels)
                  TextButton(
                    key: ValueKey('me-section-$index'),
                    onPressed: () => _jump(index),
                    child: Text(label),
                  ),
              ]),
            ),
            Expanded(child: SingleChildScrollView(
        key: const ValueKey('me-account-list'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // #1846 — four groups: who others see, what is private to the
          // account, the spaces it belongs to, the installations it uses.
          _header(words.uxProfileSection, 0),
          ...accountSettingsTiles(context, ref, only: AccountTileGroup.profile),
          _header(words.uxPreferencesSection, 2),
          ...accountSettingsTiles(context, ref, only: AccountTileGroup.account),
          door('me-activity', Icons.account_balance_wallet_outlined,
              l10n?.financesTitle ?? 'Finances',
              '/account-activity'),
          _header(words.uxAdvancedSection, 3),
          // The task wizard: recording, guides and tools in one place.
          if (ref
              .watch(enabledFeaturesSyncProvider)
              .contains(WorkspaceFeature.taskRecorder))
            door('me-task-wizard', Icons.assistant_navigation,
                l10n?.taskWizardTitle ?? 'Task wizard', taskWizardRoute),
          SettingsSectionHeader(l10n?.meGroupWorkspaces ?? 'My workspaces'),
          door('me-workspaces', Icons.workspaces_outline,
              l10n?.meGroupWorkspaces ?? 'My workspaces', '/profiles'),
          SettingsSectionHeader(
              l10n?.meGroupInstallations ?? 'Connected installations'),
          door('me-servers', Icons.dns_outlined,
              l10n?.meWhereSpacesLive ?? 'Where my spaces live', '/connections'),
          ...accountSettingsTiles(context, ref,
              only: AccountTileGroup.installations),
          const Divider(),
          door('me-help', Icons.help_outline, l10n?.helpTitle ?? 'Help', '/help'),
          _header(words.uxPrivacySection, 1),
          const VisibilityCard(),
          const LinkedVisibilityCard(),
          const BlockedPeopleCard(),
          door('me-privacy', Icons.shield_outlined,
              l10n?.privacyTitle ?? 'Privacy & data', '/privacy'),
          const Divider(),
          ListTile(
            key: const ValueKey('me-sign-out'),
            leading: Icon(Icons.logout, color: scheme.error),
            title: Text(
              l10n?.authSignOut ?? 'Sign out',
              style: TextStyle(color: scheme.error),
            ),
            onTap: () => signOutAndForget(ref),
          ),
        ]),
      )),
          ]),
        ),
      ),
    );
  }
}
