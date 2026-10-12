// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/backend/connected_installation_providers.dart';
import '../../../../core/backend/connected_installations.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/loading_view.dart';
import '../../domain/account_activity.dart';
import '../../providers/account_activity_providers.dart';

class ConnectedActivity extends ConsumerWidget {
  const ConnectedActivity({super.key, required this.kind});
  final AccountActivityKind kind;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(connectedSourcesProvider);
    final l = context.l10n;
    return switch (sources) {
      AsyncData(value: final rows) => Column(
        children: [
          for (final source in rows)
            _SourceActivity(
              key: ValueKey('${source.endpoint.url}:${kind.name}'),
              source: source,
              kind: kind,
            ),
        ],
      ),
      AsyncError() => TextButton(
        key: const ValueKey('connected-activity-portal-source-unavailable'),
        onPressed: () => ref.invalidate(connectedSourcesProvider),
        child: Text(
          l.portalSourceUnavailable,
        ),
      ),
      _ => const LoadingView(),
    };
  }
}

class _SourceActivity extends ConsumerStatefulWidget {
  const _SourceActivity({super.key, required this.source, required this.kind});
  final ConnectedInstallation source;
  final AccountActivityKind kind;
  @override
  ConsumerState<_SourceActivity> createState() => _SourceState();
}

class _SourceState extends ConsumerState<_SourceActivity> {
  final _pages = <ActivityCursor>[];
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final provider = connectedAccountActivityProvider(
      widget.source.endpoint.url,
      widget.kind,
      before: _pages.lastOrNull,
    );
    final rows = ref.watch(provider);
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(widget.source.endpoint.host),
        children: [
          switch (rows) {
            AsyncData(value: final entries) => Column(
              children: [
                if (entries.isEmpty)
                  Text(l.accountActivityEmpty),
                for (final entry in entries)
                  ListTile(
                    title: Text(entry.workspaceName),
                    subtitle: Text(
                      [
                        entry.reference, entry.description,
                        // Preserve provider confirmation status. An issued invoice is not a paid invoice.
                        switch (entry.status) {
                          'created' =>
                            l.payOnlinePendingTitle,
                          'failed' =>
                            l.payOnlineFailedTitle,
                          'confirmed' =>
                            l.accountPaymentConfirmed,
                          'voided' =>
                            l.accountInvoiceVoided,
                          'regrouped' =>
                            l.accountInvoiceRegrouped,
                          _ => '',
                        },
                        DateFormat.yMMMd(
                          Localizations.localeOf(context).toLanguageTag(),
                        ).format(entry.occurredAt.toLocal()),
                        if (entry.amountCents case final amount?)
                          moneyFormat(entry.currency).formatMinor(amount),
                        if (entry.minutes case final minutes?)
                          l.accountUsageMinutes(minutes),
                      ].where((s) => s.isNotEmpty).join(' · '),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      key: const ValueKey('connected-activity-chevron-left'),
                      tooltip: MaterialLocalizations.of(context)
                          .previousPageTooltip,
                      onPressed: _pages.isEmpty
                          ? null
                          : () => setState(_pages.removeLast),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    IconButton(
                      key: const ValueKey('connected-activity-chevron-right'),
                      tooltip: MaterialLocalizations.of(context)
                          .nextPageTooltip,
                      onPressed: entries.length < 50
                          ? null
                          : () =>
                                setState(() => _pages.add(entries.last.cursor)),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            ),
            AsyncError() => TextButton(
              key: const ValueKey('connected-activity-portal-source-unavailable-2'),
              onPressed: () => ref.invalidate(provider),
              child: Text(
                l.portalSourceUnavailable,
              ),
            ),
            _ => const LoadingView(),
          },
        ],
      ),
    );
  }
}
