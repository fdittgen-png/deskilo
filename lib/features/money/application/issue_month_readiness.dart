// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-e -- what stops each listed customer from being invoiced, read
// BEFORE the person ticks and issues: the existing per-member dry run of the
// very same issue (`invoice_issue_readiness`, 0365/0416), never a second rule.
// A customer's own missing details are named on their row; what is missing on
// the BUSINESS side is the same for everyone and is said once.
//
// A read that fails is "unknown", never "ready" and never "blocked": the row
// stays selectable and the server still refuses at issue time, in words.
import '../domain/invoice_queries.dart';

/// How many customers are read at once: a courtesy to the server, not a
/// setting.
const int monthReadinessConcurrency = 4;

/// What is known of one customer.
sealed class LineReadiness {
  const LineReadiness();
}

/// Nothing stops the invoice.
final class ReadinessReady extends LineReadiness {
  const ReadinessReady();
}

/// The read failed: not known, so not blocked.
final class ReadinessUnknown extends LineReadiness {
  const ReadinessUnknown();
}

/// The essentials still missing, as the server's stable keys.
final class ReadinessMissing extends LineReadiness {
  const ReadinessMissing(this.keys);
  final List<String> keys;
}

/// Whether the essential [key] is the business's own (its address, its tax
/// identity, its VAT treatment, the invoicing feature) and so the same for
/// every customer.
bool isBusinessEssential(String key) =>
    key.startsWith('seller_') ||
    key.startsWith('vat_') ||
    key == 'exemption_reason' ||
    key == 'invoice_feature_disabled';

/// What the review list knows of its customers.
class MonthReadiness {
  const MonthReadiness(this.lines);

  /// member id -> what is known; a customer not read yet is absent.
  final Map<String, LineReadiness> lines;

  /// The business-side essentials missing for EVERY customer that could be
  /// read; empty as soon as one customer is ready or none could be read.
  List<String> get businessMissing {
    final read = [
      for (final l in lines.values)
        if (l is! ReadinessUnknown) l,
    ];
    if (read.isEmpty || read.any((l) => l is! ReadinessMissing)) {
      return const [];
    }
    final sets = [
      for (final l in read.cast<ReadinessMissing>())
        {
          for (final k in l.keys)
            if (isBusinessEssential(k)) k,
        },
    ];
    return sets.reduce((a, b) => a.intersection(b)).toList()..sort();
  }

  /// What is missing for [memberId] that only they can supply.
  List<String> customerMissing(String memberId) {
    final l = lines[memberId];
    if (l is! ReadinessMissing) return const [];
    final shared = businessMissing.toSet();
    return [
      for (final k in l.keys)
        if (!shared.contains(k)) k,
    ];
  }

  /// Whether [memberId] cannot be issued until something is fixed.
  bool needsFix(String memberId) => customerMissing(memberId).isNotEmpty;

  /// How many customers cannot be issued yet.
  int get needsFixCount => [
    for (final id in lines.keys)
      if (needsFix(id)) id,
  ].length;

  MonthReadiness with_(String memberId, LineReadiness readiness) =>
      MonthReadiness({...lines, memberId: readiness});
}

/// Reads [memberIds]' readiness for [period], [concurrency] at a time,
/// telling [onEach] as every answer arrives (so rows fill in as they come).
Future<void> readMonthReadiness({
  required InvoiceQueries queries,
  required String workspaceId,
  required String period,
  required List<String> memberIds,
  required void Function(String memberId, LineReadiness readiness) onEach,
  int concurrency = monthReadinessConcurrency,
}) async {
  final queue = List.of(memberIds);
  Future<void> worker() async {
    while (queue.isNotEmpty) {
      final id = queue.removeAt(0);
      LineReadiness readiness;
      try {
        final missing = await queries.invoiceIssueReadiness(
          workspaceId: workspaceId,
          memberId: id,
          period: period,
        );
        readiness = missing.isEmpty
            ? const ReadinessReady()
            : ReadinessMissing(missing);
      } on Object {
        readiness = const ReadinessUnknown();
      }
      onEach(id, readiness);
    }
  }

  await Future.wait([for (var i = 0; i < concurrency; i++) worker()]);
}
