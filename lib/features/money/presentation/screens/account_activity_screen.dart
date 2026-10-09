// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/connected_activity.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../domain/account_activity.dart';
import '../../providers/account_activity_providers.dart';
import '../widgets/personal_payment_provider.dart';

/// Personal history is independent of whichever workspace happens to be open.
class AccountActivityScreen extends ConsumerStatefulWidget {
  const AccountActivityScreen({super.key});
  @override
  ConsumerState<AccountActivityScreen> createState() => _ActivityState();
}

class _ActivityState extends ConsumerState<AccountActivityScreen> {
  var _kind = AccountActivityKind.invoices;
  String? _account;
  final _pages = <ActivityCursor>[];
  @override
  Widget build(BuildContext context) {
    final account = ref.watch(authStateProvider).value;
    if (_account != account) {
      _account = account;
      _pages.clear();
    }
    final l10n = AppLocalizations.of(context);
    final provider = accountActivityProvider(_kind, before: _pages.lastOrNull);
    final rows = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            key: const ValueKey('account-activity-portal-connections'),
            tooltip: l10n?.portalConnections ?? 'Connected servers',
            onPressed: () => context.push('/connections'),
            icon: const Icon(Icons.dns_outlined),
          ),
        ],
        title: Text(
          l10n?.accountActivityTitle ?? 'My consumption and payments',
        ),
      ),
      body: account == null
          ? const SizedBox.shrink()
          : Column(
              children: [
                Padding(
                  padding: AppSpacing.mdAll,
                  child: DropdownButtonFormField<AccountActivityKind>(
                    key: const ValueKey('account-activity-invoices-title'),
                    initialValue: _kind,
                    items: [
                      for (final kind in AccountActivityKind.values)
                        DropdownMenuItem(
                          value: kind,
                          child: Text(switch (kind) {
                            AccountActivityKind.invoices =>
                              l10n?.invoicesTitle ?? 'Invoices',
                            AccountActivityKind.payments =>
                              l10n?.accountPaymentsTitle ?? 'Payments',
                            AccountActivityKind.usage =>
                              l10n?.usageTitle ?? 'Usage',
                          }),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _kind = value;
                          _pages.clear();
                        });
                      }
                    },
                  ),
                ),
                Expanded(
                  child: switch (rows) {
                    AsyncData(value: final entries) => RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(provider);
                        await ref.read(provider.future);
                      },
                      child: ListView(
                        padding: AppSpacing.mdAll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          ConnectedActivity(
                            key: ValueKey(account),
                            kind: _kind,
                          ),
                          Text(
                            l10n?.accountActivityScope ?? 'All your profiles on this server, including previous memberships. Currencies are shown separately.',
                          ),
                          if (_kind == AccountActivityKind.payments)
                            const PersonalPaymentProvider(),
                          if (entries.isEmpty)
                            Padding(
                              padding: AppSpacing.mdAll,
                              child: Text(
                                l10n?.accountActivityEmpty ??
                                    'No records to display.',
                              ),
                            ),
                          for (final entry in entries)
                            Card(
                              child: ListTile(
                                key: ValueKey('account-activity-${entry.id}'),
                                title: Text(entry.workspaceName),
                                subtitle: Text(
                                  [
                                        entry.reference,
                                        entry.description,
                                        _status(l10n, entry.status),
                                        DateFormat.yMMMd(
                                          Localizations.localeOf(context)
                                              .toLanguageTag(),
                                        ).format(entry.occurredAt.toLocal()),
                                        if (entry.amountCents
                                            case final amount?)
                                          moneyFormat(entry.currency)
                                              .formatMinor(amount),
                                        if (entry.minutes case final minutes?)
                                          l10n?.accountUsageMinutes(minutes) ??
                                              '$minutes minutes',
                                      ]
                                      .where((value) => value.isNotEmpty)
                                      .join(' · '),
                                ),
                              ),
                            ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                key: const ValueKey('account-activity-chevron-left'),
                                tooltip: MaterialLocalizations.of(context)
                                    .previousPageTooltip,
                                onPressed: _pages.isEmpty
                                    ? null
                                    : () => setState(() => _pages.removeLast()),
                                icon: const Icon(Icons.chevron_left),
                              ),
                              IconButton(
                                key: const ValueKey('account-activity-chevron-right'),
                                tooltip: MaterialLocalizations.of(context)
                                    .nextPageTooltip,
                                onPressed: entries.length < 50
                                    ? null
                                    : () => setState(
                                        () => _pages.add(entries.last.cursor),
                                      ),
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    AsyncError() => ListView(
                      children: [
                        ConnectedActivity(key: ValueKey(account), kind: _kind),
                        TextButton(
                          key: const ValueKey('account-activity-failed'),
                          onPressed: () => ref.invalidate(provider),
                          child: Text(
                            l10n?.accountActivityFailed ?? 'Could not load your financial history. Tap to retry.',
                          ),
                        ),
                      ],
                    ),
                    _ => ListView(
                      children: [
                        ConnectedActivity(key: ValueKey(account), kind: _kind),
                        const LoadingView(),
                      ],
                    ),
                  },
                ),
              ],
            ),
    );
  }

  String _status(AppLocalizations? l10n, String status) => switch (status) {
    'created' => l10n?.payOnlinePendingTitle ?? 'Online payment pending',
    'failed' => l10n?.payOnlineFailedTitle ?? 'Online payment failed',
    'confirmed' => l10n?.accountPaymentConfirmed ?? 'Payment confirmed',
    'voided' => l10n?.accountInvoiceVoided ?? 'Invoice voided',
    'regrouped' =>
      l10n?.accountInvoiceRegrouped ?? 'Included in a settlement invoice',
    'issued' => l10n?.accountInvoiceIssued ?? 'Invoice issued',
    'corrected' => l10n?.accountUsageCorrected ?? 'Corrected billable usage',
    _ => '',
  };
}
