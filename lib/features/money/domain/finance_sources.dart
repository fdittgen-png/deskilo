// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Where one workspace's documents were read on Me › Finances, and every
// payment of that workspace read there again for a file: the personal home,
// a connected host my personal account names, or the selected workspace's
// own host. A workspace lives on one installation, so its payments are
// asked of the same source as its invoices, never of another one.
import 'account_activity.dart';
import 'finance_hosts.dart';
import 'finance_overview.dart';

/// The source that answered for a workspace's documents.
sealed class FinanceSource {
  const FinanceSource();

  /// What a file calls it: `home`, the host's name, or the origin's host.
  String get name;
}

/// The personal home's own installation.
class HomeFinanceSource extends FinanceSource {
  const HomeFinanceSource();

  @override
  String get name => 'home';
}

/// A connected host my personal account names.
class HostFinanceSource extends FinanceSource {
  const HostFinanceSource(this.host);

  final FinanceHost host;

  @override
  String get name => host.name;
}

/// The selected workspace's own host, by origin, when no host my account
/// names covers it.
class SelectedFinanceSource extends FinanceSource {
  const SelectedFinanceSource(this.origin);

  final String origin;

  @override
  String get name {
    final host = Uri.tryParse(origin)?.host ?? '';
    return host.isEmpty ? origin : host;
  }
}

extension FinanceSourceOf on FinanceOverview {
  /// The source that answered [workspaceId]'s documents: a connected host
  /// that returned them (or names the workspace), else the selected
  /// workspace's host that returned them, else the personal home.
  FinanceSource sourceOf(String workspaceId) {
    for (final h in hosts) {
      if (h.status == FinanceHostStatus.answered &&
          (h.workspaceIds.contains(workspaceId) ||
              h.host.workspaceIds.contains(workspaceId))) {
        return HostFinanceSource(h.host);
      }
    }
    for (final read in answered) {
      final origin = read.origin;
      if (origin != null && read.workspaceIds.contains(workspaceId)) {
        return SelectedFinanceSource(origin);
      }
    }
    return const HomeFinanceSource();
  }
}

/// Every payment of one workspace, read on its [source] for a file, or the
/// [source] named as not answering ([complete] false): the file then says
/// its payments are missing rather than posing as having none.
class OwnPayments {
  const OwnPayments(this.source, this.payments) : complete = true;

  const OwnPayments.unavailable(this.source)
    : payments = const [],
      complete = false;

  final FinanceSource source;
  final List<AccountActivity> payments;
  final bool complete;
}
