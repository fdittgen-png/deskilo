// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/backend/bounded_reads.dart';
import '../../../core/backend/context_client_providers.dart';
import '../../../core/session/session_source.dart';
import '../../../core/trace/trace_logger.dart';
import '../../auth/providers/auth_providers.dart';
import '../domain/account_activity.dart';
import '../domain/finance_hosts.dart';
import '../domain/finance_overview.dart';
import 'account_activity_providers.dart';
import 'finance_host_providers.dart';

part 'finance_overview_provider.g.dart';

/// Me › Finances: my invoices and reminders across every workspace (0380),
/// each read where its documents live. The personal home answers for the
/// installation the app is signed in to; when the selected workspace lives
/// on a connected installation, that host answers for its own documents on
/// the selected workspace's client; and (#2557 C5) every other connected
/// host my personal account names is read with its own verified client, at
/// most `personal.read_concurrency` at a time, each waited for
/// `personal.read_timeout_seconds`. A host that does not answer leaves the
/// others on screen and is named, with its own Try again, rather than
/// hiding them or posing as empty. An answer that arrives after the
/// signed-in account changed, or for a view rebuilt meanwhile, is dropped.
@Riverpod(name: 'financeOverviewProvider')
class FinanceOverviewComposer extends _$FinanceOverviewComposer {
  int _generation = 0;
  String? _principal;
  BoundedReads? _reads;
  Duration _timeout = Duration.zero;

  @override
  Future<FinanceOverview> build() async {
    final generation = ++_generation;
    _reads = null;
    if (ref.watch(authStateProvider).value == null) {
      return const FinanceOverview();
    }
    final principal = ref.watch(sessionStateProvider.select((s) => s.value));
    final home = ref.watch(accountActivityRepositoryProvider);
    final split = ref.watch(selectedWorkspaceHostProvider);
    // Watched before the first await; a failure of one while another is
    // awaited must not go unhandled.
    final hostsAnswer = ref.watch(financeHostsProvider.future)..ignore();
    final limitsAnswer = ref.watch(financeReadLimitsProvider.future)..ignore();
    final selected = split == null ? null : _selectedRepository(ref);
    final hosts = await _away(hostsAnswer);
    // A selected workspace on a host read below is answered there, once.
    final covered = split != null &&
        hosts.any((h) => h.workspaceIds.contains(split.workspaceId));
    // #2557 C4 — each host that answers is recorded, so the coverage above
    // the results names what was read as well as what was not.
    var mine = (await home.overview()).answeredBy(null);
    if (split != null && !covered) {
      mine = await _selected(mine, selected, split.source);
    }
    if (hosts.isEmpty) return mine;
    final FinanceReadLimits limits;
    try {
      limits = await limitsAnswer;
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'money',
        'the limits of my connected hosts\' reads are unavailable',
        error: e,
        stackTrace: st,
      );
      var failed = mine.reading(hosts);
      for (final h in hosts) {
        failed = failed.hostSettled(h, FinanceHostStatus.failed);
      }
      return failed;
    }
    // Rebuilt meanwhile: the newer build reads; this one's answer is moot.
    if (!ref.mounted || generation != _generation) return mine.reading(hosts);
    final reads = BoundedReads(limits.concurrency);
    ref.onDispose(reads.close);
    _principal = principal;
    _reads = reads;
    _timeout = limits.timeout;
    for (final host in hosts) {
      unawaited(_read(generation, host));
    }
    return mine.reading(hosts);
  }

  /// The connected hosts to read: those my account names that are not the
  /// personal home's own installation (its read already answers for them).
  Future<List<FinanceHost>> _away(Future<List<FinanceHost>> answer) async {
    try {
      return [for (final h in await answer) if (!h.hostedHere) h];
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'money',
        'the hosts my personal account names are unavailable',
        error: e,
        stackTrace: st,
      );
      return const [];
    }
  }

  Future<FinanceOverview> _selected(
    FinanceOverview mine,
    AccountActivityRepository? selected,
    String source,
  ) async {
    if (selected == null) return mine.withUnavailable(source);
    try {
      return mine.merge((await selected.overview()).answeredBy(source));
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'money',
        'own documents of the selected workspace unavailable',
        error: e,
        stackTrace: st,
      );
      return mine.withUnavailable(source);
    }
  }

  /// Whether a read started in [generation] may still change the view: the
  /// same build, the same signed-in account.
  bool _current(int generation) =>
      ref.mounted &&
      generation == _generation &&
      ref.read(sessionStateProvider).value == _principal;

  Future<void> _read(int generation, FinanceHost host) async {
    final reads = _reads;
    if (reads == null) return;
    final reader = ref.read(financeHostReaderProvider);
    FinanceOverview? answer;
    try {
      answer = await reads.run(() => reader.overview(host).timeout(_timeout));
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'money',
        'a host of my own documents did not answer',
        error: e,
        stackTrace: st,
      );
    }
    if (!_current(generation)) return;
    // The first state is emitted by build; an answer may come before it.
    try {
      await future;
    } on Object {
      // trace-exempt: the build's own failure is the view's state.
      return;
    }
    if (!_current(generation)) return;
    final overview = state.value;
    if (overview == null) return;
    state = AsyncData(
      answer == null
          ? overview.hostSettled(host, FinanceHostStatus.failed)
          : overview.hostSettled(host, FinanceHostStatus.answered, answer),
    );
  }

  /// Reads the connected host [installationId] again, when it failed; the
  /// other hosts' documents stay as they are.
  void retry(String installationId) {
    final overview = state.value;
    if (overview == null) return;
    if (_reads == null) {
      // The limits were not read: nothing to read with but a new build.
      ref.invalidateSelf();
      return;
    }
    for (final h in overview.hosts) {
      if (h.host.installationId != installationId ||
          h.status != FinanceHostStatus.failed) {
        continue;
      }
      state = AsyncData(
        overview.hostSettled(h.host, FinanceHostStatus.reading),
      );
      unawaited(_read(_generation, h.host));
      return;
    }
  }
}

/// The selected workspace's repository — or null while its client is
/// refused (the context still resolving, the connection ended), which is a
/// host that cannot answer right now, not an error of the whole overview.
AccountActivityRepository? _selectedRepository(Ref ref) {
  try {
    return ref.watch(selectedWorkspaceAccountActivityRepositoryProvider);
  } on Object catch (e, st) {
    TraceLogger.instance.warn(
      'money',
      'selected workspace client refused',
      error: e,
      stackTrace: st,
    );
    return null;
  }
}

/// A one-shot request to open one invoice in its own space's Money screen
/// (Me › Finances → the workspace, in the right environment). The screen
/// consumes it only when the request's space is the current one. Kept
/// alive: the request outlives the screen that made it.
@Riverpod(keepAlive: true)
class InvoiceFocus extends _$InvoiceFocus {
  @override
  ({String workspaceId, String invoiceId})? build() => null;

  void request(String workspaceId, String invoiceId) =>
      state = (workspaceId: workspaceId, invoiceId: invoiceId);

  void clear() => state = null;
}
