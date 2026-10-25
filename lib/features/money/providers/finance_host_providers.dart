// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2557 C5 — the hosts Me › Finances reads besides the personal home, how
// one is read, and the personal limits of those reads. Composed in
// finance_overview_provider.dart.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/backend/bounded_reads.dart';
import '../../../core/backend/connected_installation_providers.dart';
import '../../../core/backend/connected_pool_host_resolver.dart';
import '../../../core/backend/context_client_providers.dart';
import '../../../core/backend/context_clients.dart'
    show ActiveInstallationHostResolver;
import '../../../core/session/session_source.dart';
import '../../../core/settings/active_settings.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/host_finance_reader.dart';
import '../domain/account_activity.dart';
import '../domain/finance_hosts.dart';

part 'finance_host_providers.g.dart';

/// The workspace hosts my personal account names. None by default (the
/// personal home and the selected workspace answer alone); the composition
/// root replaces it with every host my personal account names
/// (`financeHostsFromMe`, lib/app).
@riverpod
Future<List<FinanceHost>> financeHosts(Ref ref) async => const [];

/// One host read through its own verified client. Demo overrides it with
/// the fixture's spaces.
@riverpod
FinanceHostReader financeHostReader(Ref ref) => HostFinanceReader(
  hostOf: (host) => resolveFinanceHost(
    host,
    connected: () => ref.read(connectedSourcesProvider.future),
    resolverFor: (origin) => ConnectedPoolHostResolver(
      active: ActiveInstallationHostResolver(
        ref.read(personalClientProvider),
        ref.read(installationIdReaderProvider),
      ),
      root: ref.read(personalClientProvider),
      pool: () => ref.read(connectedInstallationsProvider),
      sourceOf: (_) => origin,
    ),
  ),
);

/// How many hosts are read at once and how long one is waited for: the
/// personal home's `personal.read_concurrency` and
/// `personal.read_timeout_seconds`, the same limits My reservations reads
/// under. A registry without the rows fails typed, once.
@Riverpod(retry: financeLimitsRetry)
Future<FinanceReadLimits> financeReadLimits(Ref ref) async {
  final settings = await ref.watch(platformSettingsProvider.future);
  if (settings == null) {
    throw const FinanceHostUnavailable('no personal settings');
  }
  return FinanceReadLimits(
    concurrency: settings.read<int>('personal.read_concurrency'),
    timeout: Duration(
      seconds: settings.read<int>('personal.read_timeout_seconds'),
    ),
  );
}

/// No retry: missing limits leave the connected hosts named as not read,
/// at once.
Duration? financeLimitsRetry(int retryCount, Object error) => null;

/// The full history's reads of my connected hosts: at most
/// `personal.read_concurrency` at once, as on Me › Finances. Closed with
/// the last page that uses it, so nothing waits behind a gone view.
@Riverpod(retry: financeLimitsRetry)
Future<BoundedReads> financeHistoryReads(Ref ref) async {
  final limits = await ref.watch(financeReadLimitsProvider.future);
  final reads = BoundedReads(limits.concurrency);
  ref.onDispose(reads.close);
  return reads;
}

/// #2557 C7 — one page of my [kind] history on the connected host [host],
/// through that host's own verified client ([financeHostReader]), waited
/// for `personal.read_timeout_seconds`. Signed out there is none; a new
/// account rebuilds the page, so an answer for the previous one is
/// dropped. A failure is this host's alone and is not retried behind the
/// person's back: the page offers its own Try again.
@Riverpod(retry: financeLimitsRetry)
Future<List<AccountActivity>> hostAccountActivity(
  Ref ref,
  FinanceHost host,
  AccountActivityKind kind, {
  ActivityCursor? before,
}) async {
  if (ref.watch(authStateProvider).value == null) return const [];
  ref.watch(sessionStateProvider.select((s) => s.value));
  final limitsAnswer = ref.watch(financeReadLimitsProvider.future)..ignore();
  final readsAnswer = ref.watch(financeHistoryReadsProvider.future)..ignore();
  final reader = ref.watch(financeHostReaderProvider);
  final limits = await limitsAnswer;
  final reads = await readsAnswer;
  return reads.run(
    () => reader.activity(host, kind, before: before).timeout(limits.timeout),
  );
}
