// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2557 C5 — Me › Finances reads every workspace host my personal account
// names, not only the selected one: each connected host with its own
// verified client, at most `personal.read_concurrency` hosts at a time,
// each waited for `personal.read_timeout_seconds`. Each host keeps its own
// state — reading, answered or failed — so one host down is named beside
// the others' documents, with its own Try again.
import 'package:meta/meta.dart';

import 'account_activity.dart';
import 'finance_overview.dart';

/// One workspace host my personal account names: the installation, the
/// local ids of my workspaces on it and their names where known.
@immutable
class FinanceHost {
  const FinanceHost({
    required this.installationId,
    required this.workspaceIds,
    this.hostedHere = false,
    this.labels = const [],
  });

  final String installationId;
  final List<String> workspaceIds;

  /// The host is the installation my personal home is: the home's own read
  /// already answers for it.
  final bool hostedHere;

  /// The names of its workspaces I may read; empty when none is known.
  final List<String> labels;

  /// What the page calls the host: its workspaces' names, else its id.
  String get name => labels.isEmpty ? installationId : labels.join(', ');

  @override
  bool operator ==(Object other) =>
      other is FinanceHost &&
      other.installationId == installationId &&
      other.hostedHere == hostedHere &&
      _same(other.workspaceIds, workspaceIds) &&
      _same(other.labels, labels);

  @override
  int get hashCode => Object.hash(
    installationId,
    hostedHere,
    Object.hashAll(workspaceIds),
    Object.hashAll(labels),
  );
}

bool _same(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Where one connected host's read stands.
enum FinanceHostStatus { reading, answered, failed }

/// One connected host and its own state; [workspaceIds] are the workspaces
/// it returned documents of once it answered.
@immutable
class FinanceHostRead {
  const FinanceHostRead(
    this.host,
    this.status, {
    this.workspaceIds = const {},
    this.morePaymentsBefore,
  });

  final FinanceHost host;
  final FinanceHostStatus status;
  final Set<String> workspaceIds;

  /// Where the next page of my payments on this host starts: the last row
  /// of a full first page. Null when that page was short (nothing more)
  /// or the host has not answered.
  final ActivityCursor? morePaymentsBefore;
}

/// The personal home's limits for these reads (its platform settings).
@immutable
class FinanceReadLimits {
  const FinanceReadLimits({required this.concurrency, required this.timeout});

  final int concurrency;
  final Duration timeout;
}

/// Reads my own documents on one host, through that host's own client.
abstract interface class FinanceHostReader {
  Future<FinanceOverview> overview(FinanceHost host);

  /// One page of my [kind] activity on [host], older than [before]: what
  /// the full history pages through, host by host.
  Future<List<AccountActivity>> activity(
    FinanceHost host,
    AccountActivityKind kind, {
    ActivityCursor? before,
  });
}

/// The host of a source could not be reached with its own verified client
/// here: not connected on this device, unverified, or it answered as
/// another installation.
class FinanceHostUnavailable implements Exception {
  const FinanceHostUnavailable(this.detail);

  final String detail;

  @override
  String toString() => 'FinanceHostUnavailable($detail)';
}
