// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2557 C7 — Me › Finances › Payments, host by host: a connected host
// answers the first page of my payments with its overview; when that page
// is full, the host offers its next page, read on that host alone through
// its own verified client after the last row shown (the same per-host
// paging as the full history). A page that does not answer is named with
// its own Try again; the rows shown stay. A short page ends the host.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/loading_view.dart';
import '../../domain/account_activity.dart';
import '../../domain/finance_hosts.dart';
import '../../providers/finance_host_providers.dart';
import '../../providers/finance_overview_provider.dart';

class HostPaymentPages extends ConsumerStatefulWidget {
  const HostPaymentPages({super.key, required this.builder});

  /// The list, given every further page read so far, all hosts together.
  final Widget Function(List<AccountActivity> more) builder;

  @override
  ConsumerState<HostPaymentPages> createState() => _HostPaymentPagesState();
}

class _HostPaymentPagesState extends ConsumerState<HostPaymentPages> {
  /// Per installation, the cursors of the further pages asked for.
  final _pages = <String, List<ActivityCursor>>{};

  @override
  Widget build(BuildContext context) {
    final more = <AccountActivity>[];
    final controls = <Widget>[];
    // The connected hosts as Me › Finances read them.
    final hosts = ref.watch(financeOverviewProvider).value?.hosts ?? const [];
    for (final read in hosts) {
      final first = read.morePaymentsBefore;
      if (read.status != FinanceHostStatus.answered || first == null) continue;
      final control = _pagesOf(read.host, first, more);
      if (control != null) controls.add(control);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [widget.builder(more), ...controls],
    );
  }

  /// Adds [host]'s further pages to [more]; returns what follows them: its
  /// next page to ask for, its Try again, a spinner, or nothing at all.
  Widget? _pagesOf(
    FinanceHost host,
    ActivityCursor first,
    List<AccountActivity> more,
  ) {
    final l10n = context.l10n;
    final id = host.installationId;
    ActivityCursor? next = first;
    for (final before in _pages[id] ?? const <ActivityCursor>[]) {
      final provider = hostAccountActivityProvider(
        host,
        AccountActivityKind.payments,
        before: before,
      );
      switch (ref.watch(provider)) {
        case AsyncData(value: final rows):
          more.addAll(rows);
          next = rows.length < activityPageSize ? null : rows.last.cursor;
        case AsyncError():
          return Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: ValueKey('finances-payments-more-retry-$id'),
              onPressed: () => ref.invalidate(provider),
              child: Text(l10n.financesPaymentsMoreFailed(host.name)),
            ),
          );
        default:
          return const LoadingView();
      }
    }
    final after = next;
    if (after == null) return null;
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: ValueKey('finances-payments-more-$id'),
        icon: const Icon(Icons.expand_more),
        label: Text(l10n.financesPaymentsMoreFrom(host.name)),
        onPressed: () => setState(() => (_pages[id] ??= []).add(after)),
      ),
    );
  }
}
