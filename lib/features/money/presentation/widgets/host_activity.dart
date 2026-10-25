// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The full history, host by host: every connected host my personal account
// names, each read through its own verified client, page after page. One
// host that does not answer is named with its own Try again while the
// others stay; the personal home's own installation is the home's list.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/account_activity.dart';
import '../../domain/finance_hosts.dart';
import '../../providers/finance_host_providers.dart';

class HostActivity extends ConsumerWidget {
  const HostActivity({super.key, required this.kind});

  final AccountActivityKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hosts = ref.watch(financeHostsProvider);
    return switch (hosts) {
      AsyncData(value: final all) => Column(
        children: [
          for (final host in all)
            if (!host.hostedHere)
              _HostSection(
                key: ValueKey('${host.installationId}:${kind.name}'),
                host: host,
                kind: kind,
              ),
        ],
      ),
      AsyncError() => TextButton(
        key: const ValueKey('host-activity-hosts-unavailable'),
        onPressed: () => ref.invalidate(financeHostsProvider),
        child: Text(context.l10n.portalSourceUnavailable),
      ),
      _ => const LoadingView(),
    };
  }
}

class _HostSection extends ConsumerStatefulWidget {
  const _HostSection({super.key, required this.host, required this.kind});

  final FinanceHost host;
  final AccountActivityKind kind;

  @override
  ConsumerState<_HostSection> createState() => _HostSectionState();
}

class _HostSectionState extends ConsumerState<_HostSection> {
  /// The cursors of the pages before this one.
  final _pages = <ActivityCursor>[];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final host = widget.host;
    final provider = hostAccountActivityProvider(
      host,
      widget.kind,
      before: _pages.lastOrNull,
    );
    final rows = ref.watch(provider);
    return Card(
      key: ValueKey('host-activity-${host.installationId}'),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(host.name),
        children: [
          switch (rows) {
            AsyncData(value: final entries) => Column(
              children: [
                if (entries.isEmpty) Text(l10n.accountActivityEmpty),
                for (final entry in entries)
                  ListTile(
                    // Identity across hosts: the workspace, then the id.
                    key: ValueKey(
                      'host-activity-${entry.workspaceId}-${entry.id}',
                    ),
                    title: Text(entry.workspaceName),
                    subtitle: Text(_line(context, l10n, entry)),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      key: ValueKey('host-activity-previous-${host.installationId}'),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).previousPageTooltip,
                      onPressed: _pages.isEmpty
                          ? null
                          : () => setState(_pages.removeLast),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    IconButton(
                      key: ValueKey('host-activity-next-${host.installationId}'),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).nextPageTooltip,
                      onPressed: entries.length < activityPageSize
                          ? null
                          : () =>
                                setState(() => _pages.add(entries.last.cursor)),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            ),
            // This host alone did not answer: its own Try again re-reads
            // this page of it, the other hosts stay as they are.
            AsyncError() => TextButton(
              key: ValueKey('host-activity-retry-${host.installationId}'),
              onPressed: () => ref.invalidate(provider),
              child: Text(l10n.portalSourceUnavailable),
            ),
            _ => const LoadingView(),
          },
        ],
      ),
    );
  }
}

/// One row's facts: reference, description, the provider's own status
/// (an issued invoice is not a paid one), the day, the amount in its own
/// currency, the minutes.
String _line(
  BuildContext context,
  AppLocalizations l10n,
  AccountActivity entry,
) => [
  entry.reference,
  entry.description,
  switch (entry.status) {
    'created' => l10n.payOnlinePendingTitle,
    'failed' => l10n.payOnlineFailedTitle,
    'confirmed' => l10n.accountPaymentConfirmed,
    'voided' => l10n.accountInvoiceVoided,
    'regrouped' => l10n.accountInvoiceRegrouped,
    _ => '',
  },
  DateFormat.yMMMd(
    Localizations.localeOf(context).toLanguageTag(),
  ).format(entry.occurredAt.toLocal()),
  if (entry.amountCents case final amount?)
    moneyFormat(entry.currency).formatMinor(amount),
  if (entry.minutes case final minutes?) l10n.accountUsageMinutes(minutes),
].where((s) => s.isNotEmpty).join(' · ');
