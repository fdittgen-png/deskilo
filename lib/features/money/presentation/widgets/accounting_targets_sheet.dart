// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Where the books of each issuer go: for every API target offered in the
// space's country, each issuer's connection with its state (connected,
// signed out, refused, revoked) and its doors (connect with a token, sign
// in, check, revoke, the mappings); below, the transfers of a period. The
// server decides who may act; the doors to act show to a billing manager.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/links/link_launcher.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/accounting_connection.dart';
import '../../domain/accounting_format.dart';
import '../../providers/accounting_connection_providers.dart';
import '../../providers/book_profile_providers.dart';
import 'accounting_connection_dialogs.dart';
import 'accounting_token_dialog.dart';
import 'accounting_transfers_list.dart';

Future<void> _showAccountingTargetsSheet(
  BuildContext context,
  String workspaceId,
) => showAppSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => AccountingTargetsView(workspaceId: workspaceId),
);

/// The door to the accounting systems and the transfers.
class AccountingTargetsButton extends StatelessWidget {
  const AccountingTargetsButton({required this.workspaceId, super.key});

  final String workspaceId;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const ValueKey('accounting-targets-button'),
    onPressed: () => _showAccountingTargetsSheet(context, workspaceId),
    icon: const Icon(Icons.sync_alt_outlined),
    label: Text(context.l10n.acctTargetsTitle),
  );
}

/// The state of a connection in words.
String _connectionStatusLabel(AppLocalizations l10n, ConnectionStatus s) =>
    switch (s) {
      ConnectionStatus.pending => l10n.acctConnStatusPending,
      ConnectionStatus.connected => l10n.acctConnStatusConnected,
      ConnectionStatus.expired => l10n.acctConnStatusExpired,
      ConnectionStatus.revoked => l10n.acctConnStatusRevoked,
      ConnectionStatus.error => l10n.acctConnStatusError,
    };

/// What a target is called on screen: its vendor and product.
String targetLabel(String targetId) {
  for (final t in accountingTargets) {
    if (t.id == targetId) {
      return t.vendor == t.product ? t.product : '${t.vendor} ${t.product}';
    }
  }
  return targetId;
}

@visibleForTesting
class AccountingTargetsView extends ConsumerWidget {
  const AccountingTargetsView({required this.workspaceId, super.key});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scope = ref.watch(accountingSystemsScopeProvider);
    final apiTargets = [
      for (final t in targetsFor(scope.countryCode))
        if (t.transport == AccountingTransport.api && t.capability.producible)
          t,
    ];
    final connections = ref.watch(accountingConnectionsProvider(workspaceId));
    return SheetShell(
      title: l10n.acctTargetsTitle,
      children: [
        Text(l10n.acctTargetsIntro, style: Theme.of(context).textTheme.bodySmall),
        const FormGap(),
        if (apiTargets.isEmpty)
          Text(l10n.acctTargetsNoApiTarget, key: const ValueKey('acct-no-api-target')),
        connections.when(
          loading: () => const LoadingView(),
          error: (_, _) => Text(
            l10n.acctTargetsLoadFailed,
            key: const ValueKey('acct-targets-failed'),
          ),
          data: (all) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final target in apiTargets)
                for (final issuer in scope.issuers.entries)
                  _ConnectionCard(
                    key: ValueKey('acct-connection-${target.id}-${issuer.key}'),
                    workspaceId: workspaceId,
                    target: target,
                    issuerId: issuer.key,
                    issuerName: issuer.value,
                    connection: _liveOf(all, target.id, issuer.key),
                    revoked: [
                      for (final c in all)
                        if (!c.live &&
                            c.targetId == target.id &&
                            c.issuerSiteId == issuer.key)
                          c,
                    ],
                    manage: scope.manage,
                    memberNames: scope.memberNames,
                  ),
            ],
          ),
        ),
        const FormGap.large(),
        AccountingTransfersList(
          workspaceId: workspaceId,
          memberNames: scope.memberNames,
        ),
      ],
    );
  }

  static AccountingConnection? _liveOf(
    List<AccountingConnection> all,
    String targetId,
    String siteId,
  ) {
    for (final c in all) {
      if (c.live && c.targetId == targetId && c.issuerSiteId == siteId) {
        return c;
      }
    }
    return null;
  }
}

class _ConnectionCard extends ConsumerWidget {
  const _ConnectionCard({
    required this.workspaceId,
    required this.target,
    required this.issuerId,
    required this.issuerName,
    required this.connection,
    required this.revoked,
    required this.manage,
    required this.memberNames,
    super.key,
  });

  final String workspaceId;
  final AccountingTarget target;
  final String issuerId;
  final String issuerName;
  final AccountingConnection? connection;
  final List<AccountingConnection> revoked;
  final bool manage;
  final Map<String, String> memberNames;

  void _changed(WidgetRef ref) =>
      ref.invalidate(accountingConnectionsProvider(workspaceId));

  Future<void> _token(BuildContext context, WidgetRef ref) async {
    final saved = await showTokenDialog(
      context,
      workspaceId: workspaceId,
      target: target,
      issuerId: issuerId,
      issuerName: issuerName,
      connection: connection,
    );
    if (saved != true || !context.mounted) return;
    _changed(ref);
    AppSnack.success(context, context.l10n.acctConnSaved);
  }

  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    SignInStart? start;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'accounting sign-in failed',
      errorText: l10n.acctConnSignInFailed,
      action: () async {
        start = await ref
            .read(accountingConnectionCommandProvider)
            .startSignIn(
              workspaceId,
              issuerSiteId: issuerId,
              targetId: target.id,
              displayName: '${targetLabel(target.id)} — $issuerName',
              connectionId: connection?.id,
            );
      },
    );
    if (!ok || !context.mounted) return;
    switch (start) {
      case SignInPage(:final url):
        final opened = await ref.read(linkLauncherProvider)(url);
        if (!context.mounted) return;
        _changed(ref);
        if (opened) {
          AppSnack.info(context, l10n.acctConnSignInOpened);
        } else {
          AppSnack.error(context, l10n.acctConnSignInFailed);
        }
      case SignInNotConfigured():
        AppSnack.info(
          context,
          l10n.acctConnSignInNotConfigured(targetLabel(target.id)),
        );
      case null:
        return;
    }
  }

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    final c = connection;
    if (c == null) return;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'accounting refresh failed',
      errorText: context.l10n.acctConnRefused,
      action: () => ref.read(accountingConnectionCommandProvider).refresh(c.id),
    );
    if (ok && context.mounted) _changed(ref);
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    final c = connection;
    if (c == null) return;
    final l10n = context.l10n;
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.acctConnRevoke),
        content: Text(l10n.acctConnRevokeConfirm),
        actions: [
          TextButton(
            key: const ValueKey('acct-revoke-cancel'),
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(MaterialLocalizations.of(dialog).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('acct-revoke-confirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l10n.acctConnRevoke),
          ),
        ],
      ),
    );
    if (sure != true || !context.mounted) return;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'accounting revoke failed',
      errorText: l10n.acctConnRefused,
      action: () => ref.read(accountingConnectionCommandProvider).revoke(c.id),
    );
    if (!ok || !context.mounted) return;
    _changed(ref);
    AppSnack.success(context, l10n.acctConnRevoked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    final c = connection;
    final name = targetLabel(target.id);
    final signIn = target.connectsBy.contains(AccountingAuthKind.oauth2);
    final byToken = target.connectsBy.contains(AccountingAuthKind.token);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$name · $issuerName', style: Theme.of(context).textTheme.titleMedium),
            Text(
              c == null ? l10n.acctTargetsNotConnected : _connectionStatusLabel(l10n, c.status),
              key: ValueKey('acct-connection-state-${target.id}-$issuerId'),
              style: c != null && c.needsAttention
                  ? TextStyle(color: Theme.of(context).colorScheme.error)
                  : null,
            ),
            if (c != null && c.displayName.isNotEmpty) Text(c.displayName),
            if (c != null && c.remoteTenantId.isNotEmpty)
              Text(l10n.acctConnTenant(c.remoteTenantId)),
            if (c?.connectedAt case final at?)
              Text(l10n.acctConnSince(material.formatMediumDate(at))),
            if (c != null && c.statusDetail.isNotEmpty)
              Text(l10n.acctConnDetail(c.statusDetail)),
            if (revoked.isNotEmpty)
              Text(
                l10n.acctConnRevokedBefore(revoked.length),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                if (manage && byToken && (c == null || c.authKind == AccountingAuthKind.token))
                  TextButton(
                    key: ValueKey('acct-connect-token-${target.id}-$issuerId'),
                    onPressed: () => _token(context, ref),
                    child: Text(c == null ? l10n.acctConnConnectToken : l10n.acctConnReplaceToken),
                  ),
                if (manage && signIn && (c == null || c.authKind == AccountingAuthKind.oauth2))
                  TextButton(
                    key: ValueKey('acct-sign-in-${target.id}-$issuerId'),
                    onPressed: () => _signIn(context, ref),
                    child: Text(c == null ? l10n.acctConnSignIn(name) : l10n.acctConnSignInAgain),
                  ),
                if (manage && c != null && c.authKind == AccountingAuthKind.oauth2)
                  TextButton(
                    key: ValueKey('acct-refresh-${target.id}-$issuerId'),
                    onPressed: () => _refresh(context, ref),
                    child: Text(l10n.acctConnRefresh),
                  ),
                if (c != null)
                  TextButton(
                    key: ValueKey('acct-maps-${target.id}-$issuerId'),
                    onPressed: () => showMappingsSheet(
                      context,
                      workspaceId: workspaceId,
                      connection: c,
                      manage: manage,
                      memberNames: memberNames,
                    ),
                    child: Text(l10n.acctMapsButton(c.maps.length)),
                  ),
                if (manage && c != null)
                  TextButton(
                    key: ValueKey('acct-revoke-${target.id}-$issuerId'),
                    onPressed: () => _revoke(context, ref),
                    child: Text(l10n.acctConnRevoke),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
