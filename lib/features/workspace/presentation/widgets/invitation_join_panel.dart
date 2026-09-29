// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1652 — the one invitation journey: one field (code, link or whole
// message), then ONE compact review of what the server says, then the
// explicit Join, then the typed result. Reading, pasting, scanning and
// reviewing write nothing; only "Join workspace" does, once.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/backend/backend_settings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/wizard_navigation.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/providers/sign_out.dart';
import '../../../profile/providers/profile_providers.dart';
import '../../application/pending_invitation.dart';
import '../../application/start_workspace.dart';
import '../../domain/invitation_answer.dart';
import '../../domain/invite_uri.dart';
import '../../providers/workspace_providers.dart';
import '../onboarding_handoff.dart';
import 'onboarding_join_form.dart';

class InvitationJoinPanel extends ConsumerStatefulWidget {
  const InvitationJoinPanel({super.key, required this.code, this.navigation});

  /// Owned by the screen, so the text survives a mode switch.
  final TextEditingController code;
  final WizardNavigationController? navigation;

  @override
  ConsumerState<InvitationJoinPanel> createState() =>
      _InvitationJoinPanelState();
}

class _InvitationJoinPanelState extends ConsumerState<InvitationJoinPanel> {
  final _formKey = GlobalKey<FormState>();
  InvitationCheck? _check;
  InvitationAnswer? _outcome;
  String? _failure;
  bool _busy = false;

  BackendEndpoint? get _active => ref.read(activeBackendProvider).value;

  void _back() => setState(() {
    _check = null;
    _outcome = null;
    _failure = null;
  });

  Future<void> _review() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _failure = null;
      _outcome = null;
    });
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(activeBackendProvider.future);
      final check = await ref
          .read(workspaceStartProvider)
          .check(widget.code.text, active: _active);
      if (!mounted) return;
      setState(() => _check = check);
    } catch (e, st) {
      // Shown inline; nothing was written.
      TraceLogger.instance.warn('workspace', 'invitation check failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      setState(
        () => _failure = l10n?.invitationCheckFailed ?? 'The invitation could not be checked — status not updated. Nothing was changed; try again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (!mounted || text.trim().isEmpty) return;
    widget.code.text = text;
    await _review();
  }

  Future<void> _scan() async {
    final payload = await context.push<String>('/scan-join');
    if (!mounted || payload == null || payload.isEmpty) return;
    widget.code.text = payload;
    await _review();
  }

  /// Opens [workspaceId] through the onboarding hand-off: the context that
  /// asked is the one that finishes, and pending lands on the waiting
  /// screen by the router's own rule.
  Future<bool> _open(Future<String?> Function() action) => runOnboardingAction(
    context: context,
    ref: ref,
    navigation: widget.navigation,
    action: action,
  );

  Future<void> _join() async {
    final check = _check;
    if (_busy || check == null) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final l10n = AppLocalizations.of(context);
    InvitationAnswer? refused;
    final opened = await _open(() async {
      final answer = await ref
          .read(workspaceStartProvider)
          .join(check.invitation, active: _active);
      if (!answer.opensWorkspace) {
        refused = answer;
        return null;
      }
      await ref.read(pendingInvitationsProvider).clear();
      return answer.workspaceId;
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (refused != null) {
        _outcome = refused;
      } else if (!opened) {
        _failure = l10n?.invitationJoinUnconfirmed ?? 'The result could not be confirmed. Join again to check — the invitation is not used twice.';
      }
    });
  }

  Future<void> _continue(String workspaceId) async {
    if (_busy) return;
    setState(() => _busy = true);
    await _open(() async => workspaceId);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _useServer(InvitationDescriptor invitation) async {
    final target = invitation.target;
    if (target == null) return;
    await ref
        .read(pendingInvitationsProvider)
        .keep(invitation, widget.code.text);
    if (!mounted) return;
    await context.push('/server', extra: target);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final check = _check;
    final outcome = _outcome ?? check?.answer;
    final Widget body;
    if (check == null) {
      body = OnboardingJoinForm(
        formKey: _formKey,
        code: widget.code,
        busy: _busy,
        onJoin: _review,
        onScan: _scan,
        onPaste: _paste,
      );
    } else if (check.kind == InvitationCheckKind.unreadable) {
      body = _message(switch (check.invitation.problem) {
        InvitationProblem.unsupportedVersion => l10n?.invitationNewerVersion ?? 'This invitation was made by a newer version of DesKilo. Update the app, then open it again.',
        _ => l10n?.invitationBadServer ?? 'The server in this invitation is not valid. Ask for a new invitation.',
      }, const ValueKey('invitation-unreadable'));
    } else if (check.kind == InvitationCheckKind.otherServer) {
      body = _otherServer(l10n, check.invitation);
    } else if (outcome != null &&
        outcome.state == InvitationState.valid &&
        _outcome == null) {
      body = _reviewCard(l10n, check, outcome);
    } else {
      body = _result(
        l10n,
        outcome ?? const InvitationAnswer(InvitationState.unknown),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_failure != null) ...[
          Semantics(
            liveRegion: true,
            child: InlineBanner(
              key: const ValueKey('invitation-error'),
              icon: Icons.error_outline,
              text: _failure!,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        body,
      ],
    );
  }

  Widget _row(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text)),
      ],
    ),
  );

  String _host(InvitationDescriptor invitation) =>
      invitation.target?.endpoint.host ?? _active?.host ?? '';

  Widget _reviewCard(
    AppLocalizations? l10n,
    InvitationCheck check,
    InvitationAnswer answer,
  ) {
    final theme = Theme.of(context);
    final label = check.invitation.target?.label;
    final profile = ref.watch(myProfileProvider).value;
    final account = [
      profile?.identity.email ?? '',
      profile?.fullName ?? '',
    ].firstWhere((s) => s.trim().isNotEmpty, orElse: () => '');
    final environment = switch (answer.environment) {
      'dev' => l10n?.invitationEnvironmentTest ?? 'Test workspace',
      'prod' => l10n?.invitationEnvironmentProduction ?? 'Production workspace',
      _ => null,
    };
    return Card(
      key: const ValueKey('invitation-review'),
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n?.invitationReviewTitle ?? 'Check before you join',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              header: true,
              child: Text(
                answer.workspaceName ?? '',
                key: const ValueKey('invitation-workspace'),
                style: theme.textTheme.titleLarge,
              ),
            ),
            if (environment != null) _row(Icons.layers_outlined, environment),
            _row(
              Icons.dns_outlined,
              l10n?.invitationServerRow(_host(check.invitation)) ??
                  'Server: ${_host(check.invitation)}',
            ),
            if (label != null)
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  l10n?.invitationServerLabel(label) ??
                      'Named “$label” by whoever shared it',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (account.isNotEmpty)
              _row(
                Icons.person_outline,
                l10n?.invitationJoiningAs(account) ?? 'Joining as $account',
              ),
            _row(Icons.badge_outlined, switch (answer.offeredRole) {
              InviteRole.admin =>
                l10n?.invitationRoleAdmin ?? 'Offered role: administrator',
              InviteRole.user =>
                l10n?.invitationRoleMember ?? 'Offered role: member',
              null =>
                l10n?.invitationRoleUnknown ?? 'Offered role: not known yet',
            }),
            _row(
              Icons.how_to_reg_outlined,
              answer.requiresApproval == true
                  ? l10n?.invitationApprovalRequired ?? 'An administrator approves new members before the workspace opens.'
                  : l10n?.invitationApprovalUnknown ??
                        'Whether an administrator must approve is not known.',
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const ValueKey('invitation-join'),
              onPressed: _busy ? null : _join,
              child: Text(l10n?.invitationJoinButton ?? 'Join workspace'),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton(
                  key: const ValueKey('invitation-change-account'),
                  onPressed: _busy ? null : () => signOutAndForget(ref),
                  child: Text(
                    l10n?.invitationChangeAccount ?? 'Change account',
                  ),
                ),
                TextButton(
                  key: const ValueKey('invitation-cancel'),
                  onPressed: _busy ? null : _back,
                  child: Text(l10n?.commonCancel ?? 'Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _message(String text, Key key, {List<Widget> actions = const []}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: InlineBanner(key: key, icon: Icons.info_outline, text: text),
          ),
          const SizedBox(height: AppSpacing.md),
          ...actions,
          TextButton(
            key: const ValueKey('invitation-another'),
            onPressed: _busy ? null : _back,
            child: Text(
              AppLocalizations.of(context)?.invitationCheckAnother ??
                  'Use another invitation',
            ),
          ),
        ],
      );

  Widget _otherServer(AppLocalizations? l10n, InvitationDescriptor invitation) {
    final host = invitation.target!.endpoint.host;
    final active = _active?.host ?? '';
    final label = invitation.target!.label;
    return _message(
      [
        l10n?.invitationOtherServer(host) ??
            'This invitation is for another server: $host.',
        if (label != null)
          l10n?.invitationServerLabel(label) ??
              'Named “$label” by whoever shared it',
        l10n?.invitationThisDevice(active) ??
            'This device uses $active. An invitation is only checked on its own server.',
      ].join('\n'),
      const ValueKey('invitation-other-server'),
      actions: [
        FilledButton(
          key: const ValueKey('invitation-use-server'),
          onPressed: _busy ? null : () => _useServer(invitation),
          child: Text(l10n?.invitationUseServer ?? 'Use this server'),
        ),
      ],
    );
  }

  Widget _result(AppLocalizations? l10n, InvitationAnswer answer) {
    final name = answer.workspaceName ?? '';
    final host = _active?.host ?? '';
    return switch (answer.state) {
      InvitationState.alreadyMember ||
      InvitationState.joinedActive ||
      InvitationState.joinedPending when answer.opensWorkspace => _message(
        l10n?.invitationAlreadyMember(name) ??
            'You are already a member of $name.',
        const ValueKey('invitation-already-member'),
        actions: [
          FilledButton(
            key: const ValueKey('invitation-continue'),
            onPressed: _busy ? null : () => _continue(answer.workspaceId!),
            child: Text(
              l10n?.invitationContinue ?? 'Continue to this workspace',
            ),
          ),
        ],
      ),
      InvitationState.paused => _message(
        l10n?.invitationPaused(name) ??
            'Your membership in $name is paused. Only an administrator there can resume it.',
        const ValueKey('invitation-paused'),
      ),
      InvitationState.expired => _message(
        l10n?.invitationExpired ?? 'This invitation has expired. Ask the person who sent it for a new one.',
        const ValueKey('invitation-expired'),
      ),
      InvitationState.revoked => _message(
        l10n?.invitationRevoked ?? 'This workspace code was replaced. Ask the person who sent it for the current one.',
        const ValueKey('invitation-revoked'),
      ),
      InvitationState.wrongAccount => _message(
        l10n?.invitationWrongAccount ?? 'This invitation was already used by another account. If it was meant for you, sign in with that account.',
        const ValueKey('invitation-wrong-account'),
        actions: [
          FilledButton.tonal(
            key: const ValueKey('invitation-switch-account'),
            onPressed: _busy ? null : () => signOutAndForget(ref),
            child: Text(l10n?.invitationChangeAccount ?? 'Change account'),
          ),
        ],
      ),
      InvitationState.invalid => _message(
        l10n?.invitationInvalid(host) ??
            'No workspace on $host knows this invitation. Check it, or ask the organizer for their server link.',
        const ValueKey('invitation-invalid'),
      ),
      _ => _message(
        l10n?.invitationUnknownAnswer ?? 'The server gave an answer this version of the app cannot read. Nothing was changed.',
        const ValueKey('invitation-unknown'),
      ),
    };
  }
}
