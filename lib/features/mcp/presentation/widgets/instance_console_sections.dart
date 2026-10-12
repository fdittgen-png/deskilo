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

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/mcp_onboarding_commands.dart';
import '../../domain/instance_operator.dart';
import '../../domain/mcp_onboarding.dart';

/// The probe in words.
String _endpointProbeText(AppLocalizations l10n, EndpointProbe p) =>
    switch (p.state) {
      EndpointProbeState.deployed when p.fresh =>
        l10n.instanceProbeDeployed,
      EndpointProbeState.deployed =>
        l10n.instanceProbeStale,
      EndpointProbeState.pending =>
        l10n.instanceProbePending,
      EndpointProbeState.endpointNotDeployed =>
        l10n.instanceProbeNotDeployed,
      EndpointProbeState.resourceMismatch =>
        l10n.instanceProbeMismatch,
      EndpointProbeState.unavailable =>
        l10n.instanceProbeUnavailable,
      EndpointProbeState.missing || EndpointProbeState.unknown =>
        l10n.instanceProbeMissing,
    };

/// Whether Turn on may be offered: a fresh probe that found the endpoint.
bool endpointReady(EndpointProbe p) =>
    p.state == EndpointProbeState.deployed && p.fresh;

/// The refusals the console's changes can meet, in plain words; null for
/// anything else (the caller keeps its generic text).
String? instanceRefusalText(AppLocalizations l10n, Object error) =>
    switch (instanceRefusalOf(error)) {
      InstanceRefusal.grantNeedsGoogle =>
        l10n.instanceGrantNeedsGoogle,
      InstanceRefusal.grantDays =>
        l10n.instanceGrantDays,
      InstanceRefusal.grantReason =>
        l10n.instanceGrantReasonNeeded,
      InstanceRefusal.otherAdministrator =>
        l10n.instanceGrantOtherAdmin,
      InstanceRefusal.noIdentity =>
        l10n.instanceGrantNoIdentity,
      InstanceRefusal.endpointNotConfirmed =>
        l10n.instanceTurnOnNeedsProbe,
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
    final l10n = context.l10n;
    final unread = notices.notices.where((n) => n.unread).toList();
    if (unread.isEmpty) return const SizedBox.shrink();
    String text(InstanceNotice n) => switch (n.kind) {
      'mcp_client_waiting' =>
        l10n.instanceNoticeClientWaiting(n.subject),
      'mcp_self_grant' =>
        l10n.instanceNoticeSelfGrant(n.subject),
      'mcp_operator_grant' =>
        l10n.instanceNoticeOperatorGrant(n.subject),
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
              child: Text(l10n.instanceNoticesMarkRead),
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
    final l10n = context.l10n;
    final probe = overview.endpointProbe;
    final resource = overview.endpoint.resource;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.instanceEndpointTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (resource != null)
          SelectableText(key: const ValueKey('instance-endpoint'), resource),
        Text(
          key: ValueKey('instance-probe-${probe.state.name}'),
          _endpointProbeText(l10n, probe),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton(
            key: const ValueKey('instance-probe'),
            onPressed: onCheck,
            child: Text(l10n.instanceProbeCheck),
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
    final l10n = context.l10n;
    final o = overview;
    final dates = MaterialLocalizations.of(context);
    final granted = {for (final u in o.eligibleUsers) u.userId};
    final people = {
      for (final p in [...o.administrators, ...o.candidates]) p.userId: p,
    }.values.where((p) => !granted.contains(p.userId)).toList();
    // ignore: avoid_positional_boolean_parameters — #2389, an existing API; named when it next changes
    String who(String name, bool me) =>
        me ? '$name (${l10n.instanceYou})' : name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.instanceAccessTitle,
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
                  l10n.instanceAccessUntil(dates.formatMediumDate(at)),
                if (u.selfGrant)
                  l10n.instanceSelfApproved
                else if (u.grantedByOperator)
                  l10n.instanceOperatorApproved,
              ].join(' · '),
            ),
          ),
        if (o.operatorGrantAvailable) ...[
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              l10n.instanceGrantHelp,
            ),
          ),
          if (!o.googleSession)
            Text(
              key: const ValueKey('instance-grant-google'),
              l10n.instanceGrantNeedsGoogle,
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
                child: Text(l10n.instanceGrant),
              ),
            ),
        ],
      ],
    );
  }
}
