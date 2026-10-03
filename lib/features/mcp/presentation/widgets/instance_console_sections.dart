// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2145 — what the instance operator configures in the console beyond
// #1827 B, so assistants can be set up entirely in the app: the
// installation notices (an assistant waiting for approval, a grant), the
// endpoint assistants are given and a check of the deployed server (Turn
// on needs a fresh, deployed probe, 0360), and the operator's bounded
// approval of assistant access — themselves included while nobody else
// can decide, with a reason and a length, shown as such afterwards.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/mcp_onboarding_commands.dart';
import '../../domain/instance_operator.dart';
import '../../domain/mcp_onboarding.dart';

/// The probe in words.
String endpointProbeText(AppLocalizations? l10n, EndpointProbe p) =>
    switch (p.state) {
      EndpointProbeState.deployed when p.fresh =>
        l10n?.instanceProbeDeployed ??
            'The assistant endpoint answers as it should.',
      EndpointProbeState.deployed =>
        l10n?.instanceProbeStale ??
            'The last check is more than 15 minutes old. Check again before '
                'turning assistants on.',
      EndpointProbeState.pending =>
        l10n?.instanceProbePending ?? 'Checking the server…',
      EndpointProbeState.endpointNotDeployed =>
        l10n?.instanceProbeNotDeployed ??
            'The assistant endpoint is not deployed on this server yet.',
      EndpointProbeState.resourceMismatch =>
        l10n?.instanceProbeMismatch ??
            'The endpoint answers with another address than the one '
                'assistants are given.',
      EndpointProbeState.unavailable =>
        l10n?.instanceProbeUnavailable ??
            'The server could not be reached. Try again in a moment.',
      EndpointProbeState.missing || EndpointProbeState.unknown =>
        l10n?.instanceProbeMissing ?? 'The server has not been checked yet.',
    };

/// Whether Turn on may be offered: a fresh probe that found the endpoint.
bool endpointReady(EndpointProbe p) =>
    p.state == EndpointProbeState.deployed && p.fresh;

/// The refusals the console's changes can meet, in plain words; null for
/// anything else (the caller keeps its generic text).
String? instanceRefusalText(AppLocalizations? l10n, Object error) =>
    switch (instanceRefusalOf(error)) {
      InstanceRefusal.grantNeedsGoogle =>
        l10n?.instanceGrantNeedsGoogle ??
            'Approving access needs this session to be signed in with Google.',
      InstanceRefusal.grantDays =>
        l10n?.instanceGrantDays ?? 'Choose between 1 and 30 days.',
      InstanceRefusal.grantReason =>
        l10n?.instanceGrantReasonNeeded ??
            'Write why this access is approved (up to 500 characters).',
      InstanceRefusal.otherAdministrator =>
        l10n?.instanceGrantOtherAdmin ??
            'A database administrator decides access here; ask them.',
      InstanceRefusal.noIdentity =>
        l10n?.instanceGrantNoIdentity ??
            'That person has not confirmed their identity yet.',
      InstanceRefusal.endpointNotConfirmed =>
        l10n?.instanceTurnOnNeedsProbe ??
            'The assistant endpoint is not confirmed. Check the server first.',
      null => null,
    };

class InstanceNoticesBanner extends StatelessWidget {
  const InstanceNoticesBanner({
    super.key,
    required this.notices,
    required this.onMarkAllRead,
  });

  final InstanceNotices notices;
  final VoidCallback? onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unread = notices.notices.where((n) => n.unread).toList();
    if (unread.isEmpty) return const SizedBox.shrink();
    String text(InstanceNotice n) => switch (n.kind) {
      'mcp_client_waiting' =>
        l10n?.instanceNoticeClientWaiting(n.subject) ??
            '${n.subject} is waiting for your approval.',
      'mcp_self_grant' =>
        l10n?.instanceNoticeSelfGrant(n.subject) ??
            '${n.subject} approved their own assistant access.',
      'mcp_operator_grant' =>
        l10n?.instanceNoticeOperatorGrant(n.subject) ??
            'The operator approved assistant access for ${n.subject}.',
      _ => n.subject,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        key: const ValueKey('instance-notices'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final n in unread)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: InlineBanner(
                key: ValueKey('instance-notice-${n.id}'),
                icon: Icons.notifications_active_outlined,
                severity: InlineBannerSeverity.info,
                text: text(n),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const ValueKey('instance-notices-read'),
              onPressed: onMarkAllRead,
              child: Text(l10n?.instanceNoticesMarkRead ?? 'Mark as read'),
            ),
          ),
        ],
      ),
    );
  }
}

/// The endpoint assistants are given, and the check of the deployed one.
class InstanceEndpointSection extends StatelessWidget {
  const InstanceEndpointSection({
    super.key,
    required this.overview,
    required this.onCheck,
  });

  final InstanceMcpOverview overview;
  final VoidCallback? onCheck;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final probe = overview.endpointProbe;
    final resource = overview.endpoint.resource;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n?.instanceEndpointTitle ?? 'Assistant endpoint',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (resource != null)
          SelectableText(key: const ValueKey('instance-endpoint'), resource),
        Text(
          key: ValueKey('instance-probe-${probe.state.name}'),
          endpointProbeText(l10n, probe),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton(
            key: const ValueKey('instance-probe'),
            onPressed: onCheck,
            child: Text(l10n?.instanceProbeCheck ?? 'Check the server'),
          ),
        ),
      ],
    );
  }
}

/// Who may use assistants, and the operator's bounded approval.
class InstanceAccessSection extends StatelessWidget {
  const InstanceAccessSection({
    super.key,
    required this.overview,
    required this.onGrant,
  });

  final InstanceMcpOverview overview;

  /// Null while nothing can be changed (second factor, busy).
  final void Function(InstanceMember person)? onGrant;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final o = overview;
    final dates = MaterialLocalizations.of(context);
    final granted = {for (final u in o.eligibleUsers) u.userId};
    final people = {
      for (final p in [...o.administrators, ...o.candidates]) p.userId: p,
    }.values.where((p) => !granted.contains(p.userId)).toList();
    String who(String name, bool me) =>
        me ? '$name (${l10n?.instanceYou ?? 'you'})' : name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n?.instanceAccessTitle ?? 'Assistant access',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final u in o.eligibleUsers)
          ListTile(
            key: ValueKey('instance-eligible-${u.userId}'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.verified_user_outlined),
            title: Text(who(u.name, u.me)),
            subtitle: Text(
              [
                if (u.expiresAt case final at?)
                  l10n?.instanceAccessUntil(dates.formatMediumDate(at)) ??
                      'Until ${dates.formatMediumDate(at)}',
                if (u.selfGrant)
                  l10n?.instanceSelfApproved ?? 'Self-approved by operator'
                else if (u.grantedByOperator)
                  l10n?.instanceOperatorApproved ?? 'Approved by the operator',
              ].join(' · '),
            ),
          ),
        if (o.operatorGrantAvailable) ...[
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              l10n?.instanceGrantHelp ??
                  'While no other database administrator exists, you approve '
                      'access yourself — yours included — for up to 30 days, '
                      'with a reason. Each approval is recorded.',
            ),
          ),
          if (!o.googleSession)
            Text(
              key: const ValueKey('instance-grant-google'),
              l10n?.instanceGrantNeedsGoogle ??
                  'Approving access needs this session to be signed in with '
                      'Google.',
            ),
          for (final p in people)
            ListTile(
              key: ValueKey('instance-grantee-${p.userId}'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text(who(p.name, p.me)),
              trailing: OutlinedButton(
                key: ValueKey('instance-grant-${p.userId}'),
                onPressed: onGrant == null || !o.googleSession
                    ? null
                    : () => onGrant!(p),
                child: Text(l10n?.instanceGrant ?? 'Approve access'),
              ),
            ),
        ],
      ],
    );
  }
}

/// The reason and the length of an operator's approval; null on cancel.
class InstanceGrantDialog extends StatefulWidget {
  const InstanceGrantDialog({super.key, required this.name});

  final String name;

  @override
  State<InstanceGrantDialog> createState() => _InstanceGrantDialogState();
}

class _InstanceGrantDialogState extends State<InstanceGrantDialog> {
  final _reason = TextEditingController();
  double _days = 30;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final days = _days.round();
    final reason = _reason.text.trim();
    return AlertDialog(
      title: Text(
        l10n?.instanceGrantTitle(widget.name) ??
            'Approve assistant access for ${widget.name}',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('instance-grant-reason'),
            controller: _reason,
            maxLength: 500,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n?.instanceGrantReason ?? 'Reason',
            ),
          ),
          Text(
            l10n?.instanceGrantDaysLabel(days) ?? 'For $days days',
            key: const ValueKey('instance-grant-days'),
          ),
          Slider(
            key: const ValueKey('instance-grant-days-slider'),
            value: _days,
            min: 1,
            max: 30,
            divisions: 29,
            label: '$days',
            onChanged: (v) => setState(() => _days = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('instance-grant-cancel'),
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('instance-grant-confirm'),
          onPressed: reason.isEmpty
              ? null
              : () => Navigator.pop(context, (reason: reason, days: days)),
          child: Text(l10n?.instanceGrant ?? 'Approve access'),
        ),
      ],
    );
  }
}
