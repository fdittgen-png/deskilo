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

/// A row whose verified source is unavailable cannot dispatch an action.
class UnavailableFinanceSource extends FinanceSource {
  const UnavailableFinanceSource(this.name);
  @override
  final String name;
}

extension FinanceSourceOf on FinanceOverview {
  /// Resolve the full workspace reference, never an equal local id on a
  /// different installation. Unknown references stay unavailable.
  FinanceSource sourceOf(String networkId) {
    for (final h in hosts) {
      if (h.status == FinanceHostStatus.answered &&
          networkId.startsWith('${h.host.installationId}:')) {
        return HostFinanceSource(h.host);
      }
    }
    for (final read in answered) {
      if (read.installationId != null && networkId.startsWith('${read.installationId}:')) {
        return read.origin == null ? const HomeFinanceSource()
            : SelectedFinanceSource(read.origin!);
      }
    }
    return UnavailableFinanceSource(networkId);
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
