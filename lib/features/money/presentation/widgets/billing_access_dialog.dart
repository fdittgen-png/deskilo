// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4164 B2 -- the seller's door to a billing customer's account access: the
// grants of ONE subject, an invitation that hands out its code once, and the
// revocation of each grant. A list that could not be read says so (it is never
// "no invitations"); a refusal is worded and nothing is claimed done. The code
// of an invitation is kept on this screen only: a later read never returns it.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/failure/app_failure.dart';
import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/loading_view.dart';
import '../../application/billing_access_commands.dart';
import '../../domain/billing_access.dart';
import '../../domain/billing_customer.dart';
import 'billing_access_texts.dart';

/// Opens the dialog for [customer] of [workspaceId]; [now] is the clock the
/// states are read at.
Future<void> showBillingAccessDialog(
  BuildContext context, {
  required BillingAccessCommands commands,
  required String workspaceId,
  required BillingParty customer,
  required DateTime Function() now,
}) => showDialog<void>(
  context: context,
  builder: (_) => _BillingAccessDialog(
    commands: commands,
    workspaceId: workspaceId,
    customer: customer,
    now: now,
  ),
);

class _BillingAccessDialog extends StatefulWidget {
  const _BillingAccessDialog({
    required this.commands,
    required this.workspaceId,
    required this.customer,
    required this.now,
  });

  final BillingAccessCommands commands;
  final String workspaceId;
  final BillingParty customer;
  final DateTime Function() now;

  @override
  State<_BillingAccessDialog> createState() => _BillingAccessDialogState();
}

class _BillingAccessDialogState extends State<_BillingAccessDialog> {
  List<BillingAccessGrant>? _grants;
  String? _problem;
  bool _loadFailed = false;
  bool _busy = false;

  /// One id per intention: a retry of a lost answer is the same invitation.
  String _requestId = newRequestId();

  /// The code just handed out; shown once and dropped with the dialog.
  BillingAccessInvitation? _invitation;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final outcome = await widget.commands.grantsOf(
      widget.workspaceId,
      widget.customer.subjectId,
    );
    if (!mounted) return;
    setState(() {
      switch (outcome) {
        case CommandDone(:final value):
          _grants = value;
          _loadFailed = false;
        default:
          _loadFailed = true;
          _problem = billingAccessProblemText(context.l10n, outcome);
      }
    });
  }

  Future<void> _invite() async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    final outcome = await widget.commands.invite(
      widget.workspaceId,
      widget.customer.subjectId,
      _requestId,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _problem = billingAccessProblemText(context.l10n, outcome);
      if (outcome case CommandDone(:final value)) {
        _invitation = value;
        // The next invitation is another intention.
        _requestId = newRequestId();
      }
    });
    if (outcome is CommandDone) await _load();
  }

  Future<void> _revoke(BillingAccessGrant grant) async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    final outcome = await widget.commands.revoke(grant.id);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _problem = billingAccessProblemText(context.l10n, outcome);
      if (outcome is CommandDone && _invitation?.grantId == grant.id) {
        _invitation = null;
      }
    });
    if (outcome is CommandDone) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dates = personalFormatOf(context).dates(DateShape.date);
    final now = widget.now();
    final grants = _grants;
    return AlertDialog(
      key: const ValueKey('billing-access-dialog'),
      title: Row(
        children: [
          Expanded(
            child: Text(l10n.billingAccessTitle(widget.customer.displayName)),
          ),
          HelpDot(
            l10n.billingAccessAction,
            anchor: HelpAnchor.moneyBillingAccess,
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.billingAccessIntro),
              const FormGap(),
              if (_invitation case final invitation?) ...[
                Text(
                  l10n.billingAccessCodeTitle,
                  style: theme.textTheme.labelLarge,
                ),
                SelectableText(
                  invitation.code,
                  key: const ValueKey('billing-access-code'),
                  style: theme.textTheme.headlineSmall,
                ),
                Text(
                  l10n.billingAccessCodeOnce(
                    dates.format(invitation.expiresAt),
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('billing-access-copy'),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: invitation.code),
                    );
                    if (context.mounted) {
                      AppSnack.success(context, l10n.billingAccessCodeCopied);
                    }
                  },
                  icon: const Icon(Icons.copy),
                  label: Text(l10n.billingAccessCodeCopy),
                ),
                const FormGap(),
              ],
              if (_problem case final problem?)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    problem,
                    key: const ValueKey('billing-access-problem'),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              if (_loadFailed)
                OutlinedButton(
                  key: const ValueKey('billing-access-retry'),
                  onPressed: _load,
                  child: Text(l10n.billingCustomersRetry),
                )
              else if (grants == null)
                const Padding(padding: AppSpacing.mdAll, child: LoadingView())
              else if (grants.isEmpty)
                Text(l10n.billingAccessNone)
              else
                for (final g in grants)
                  _GrantRow(
                    grant: g,
                    now: now,
                    busy: _busy,
                    onRevoke: () => _revoke(g),
                  ),
              if (grants?.any((g) => g.revokedAt == null) ?? false) ...[
                const FormGap.small(),
                Text(
                  l10n.billingAccessRevokeNote,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('billing-access-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('billing-access-invite'),
          onPressed: _busy || _loadFailed ? null : _invite,
          child: Text(l10n.billingAccessInvite),
        ),
      ],
    );
  }
}

class _GrantRow extends StatelessWidget {
  const _GrantRow({
    required this.grant,
    required this.now,
    required this.busy,
    required this.onRevoke,
  });

  final BillingAccessGrant grant;
  final DateTime now;
  final bool busy;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dates = personalFormatOf(context).dates(DateShape.date);
    final state = grant.stateAt(now);
    final text = switch (state) {
      BillingGrantState.invited => l10n.billingAccessInvited(
        dates.format(grant.invitedAt),
      ),
      BillingGrantState.active => l10n.billingAccessActive(
        dates.format(grant.acceptedAt ?? grant.invitedAt),
      ),
      BillingGrantState.expired => l10n.billingAccessExpired(
        dates.format(grant.expiresAt),
      ),
      BillingGrantState.revoked => l10n.billingAccessRevoked(
        dates.format(grant.revokedAt ?? now),
      ),
    };
    final live =
        state == BillingGrantState.invited || state == BillingGrantState.active;
    return ListTile(
      key: ValueKey('billing-access-grant-${grant.id}'),
      contentPadding: EdgeInsets.zero,
      title: Text(text),
      trailing: live
          ? TextButton(
              key: ValueKey('billing-access-revoke-${grant.id}'),
              onPressed: busy ? null : onRevoke,
              child: Text(l10n.billingAccessRevoke),
            )
          : null,
    );
  }
}
