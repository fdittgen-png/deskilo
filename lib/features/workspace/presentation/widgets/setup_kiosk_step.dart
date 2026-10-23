// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup step "kiosk and badges": which account runs the tablet by the
// door, chosen among the active members and made the kiosk through
// [SetMemberKiosk], and whether members check in there with an NFC badge,
// the badge switch of the NFC screen (one feature write, the server merges
// it). The preview is the kiosk's own greeting, which the kiosk feature
// draws and the router hands in.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/ui/setup_step_layout.dart';
import '../../application/set_member_kiosk.dart';
import '../../application/toggle_workspace_feature.dart';
import '../../domain/member.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/workspace_providers.dart';

/// The kiosk's greeting for a space called [workspaceName].
typedef SetupKioskGreetingBuilder = Widget Function({
  required String workspaceName,
});

class SetupKioskStep extends ConsumerStatefulWidget {
  const SetupKioskStep({
    super.key,
    required this.workspace,
    required this.greeting,
  });

  final Workspace workspace;
  final SetupKioskGreetingBuilder greeting;

  @override
  ConsumerState<SetupKioskStep> createState() => _SetupKioskStepState();
}

class _SetupKioskStepState extends ConsumerState<SetupKioskStep> {
  final _picked = ValueNotifier<String?>(null);
  final _busy = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _picked.dispose();
    _busy.dispose();
    super.dispose();
  }

  Future<void> _make(Member member) async {
    final l10n = context.l10n;
    _busy.value = true;
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'setup kiosk account failed',
      errorText: l10n.setupKioskSaveFailed,
      action: () => ref.read(setMemberKioskProvider).make(member),
    );
    ref.invalidate(workspaceMembersProvider);
    if (!mounted) return;
    _busy.value = false;
    if (!ok) return;
    _picked.value = null;
    AppSnack.success(context, l10n.workspaceSettingsSaved);
  }

  Future<void> _badges({required bool value}) async {
    _busy.value = true;
    await runGuarded(
      context,
      domain: 'workspace',
      message: 'setup kiosk badges failed',
      errorText: context.l10n.setupKioskSaveFailed,
      action: () => toggleWorkspaceFeature(
        ref,
        workspace: widget.workspace,
        feature: WorkspaceFeature.nfcBadges,
        value: value,
      ),
    );
    if (mounted) _busy.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final emails = ref.watch(memberEmailsProvider).value ?? const {};
    String who(Member m) => emails[m.id] ?? m.managedName;
    return switch (ref.watch(workspaceMembersProvider)) {
      AsyncValue(hasValue: true, :final value) => SetupStepLayout(
        form: _form(context, value ?? const [], who),
        preview: Column(
          key: const ValueKey('setup-kiosk-preview'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // A picture of the tablet's first screen: nothing in it acts.
            IgnorePointer(
              child: widget.greeting(workspaceName: widget.workspace.name),
            ),
          ],
        ),
      ),
      AsyncError() => Padding(
        padding: AppSpacing.lgAll,
        child: InlineBanner(
          key: const ValueKey('setup-kiosk-failed'),
          icon: Icons.error_outline,
          text: l10n.setupStepLoadFailed,
        ),
      ),
      _ => const LoadingView(),
    };
  }

  Widget _form(
    BuildContext context,
    List<Member> members,
    String Function(Member) who,
  ) {
    final l10n = context.l10n;
    final active = [
      for (final m in members)
        if (m.status == MemberStatus.active) m,
    ];
    final kiosks = [
      for (final m in active)
        if (m.isKiosk) m,
    ];
    // An owner made a kiosk would lock themselves to the plan.
    final candidates = [
      for (final m in active)
        if (!m.isKiosk && !m.isOwner) m,
    ];
    final badgesOn = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.nfcBadges);
    return ListenableBuilder(
      listenable: Listenable.merge([_picked, _busy]),
      builder: (context, _) {
        final busy = _busy.value;
        final picked = candidates
            .where((m) => m.id == _picked.value)
            .firstOrNull;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.setupStepHint('kiosk')),
            const SizedBox(height: AppSpacing.md),
            if (kiosks.isEmpty)
              Text(
                l10n.setupKioskNone,
                key: const ValueKey('setup-kiosk-none'),
              ),
            for (final k in kiosks)
              ListTile(
                key: ValueKey('setup-kiosk-account-${k.id}'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.tablet_mac_outlined),
                title: Text(l10n.setupKioskCurrent(who(k))),
              ),
            const SizedBox(height: AppSpacing.sm),
            if (candidates.isEmpty)
              Text(
                l10n.setupKioskNoCandidate,
                key: const ValueKey('setup-kiosk-no-candidate'),
              )
            else ...[
              DropdownButtonFormField<String>(
                key: const ValueKey('setup-kiosk-pick'),
                isExpanded: true,
                initialValue: picked?.id,
                decoration: InputDecoration(labelText: l10n.setupKioskPick),
                items: [
                  for (final m in candidates)
                    DropdownMenuItem(
                      value: m.id,
                      child: Text(who(m), overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: busy ? null : (id) => _picked.value = id,
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton(
                  key: const ValueKey('setup-kiosk-make'),
                  onPressed: busy || picked == null
                      ? null
                      : () => _make(picked),
                  child: Text(l10n.setupKioskMake),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              key: const ValueKey('setup-kiosk-badges'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.nfcConfigEnable),
              subtitle: Text(l10n.nfcConfigEnableDesc),
              value: badgesOn,
              onChanged: busy ? null : (v) => _badges(value: v),
            ),
          ],
        );
      },
    );
  }
}
