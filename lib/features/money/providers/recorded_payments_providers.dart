// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2578 — the payments behind the collected figure, one page at a time.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/receivables_answers.dart';
import '../data/supabase_recorded_payments_repository.dart';
import '../domain/recorded_payments.dart';
import 'credit_providers.dart';

final recordedPaymentsRepositoryProvider = Provider<RecordedPaymentsRepository>(
  (ref) => SupabaseRecordedPaymentsRepository(ref.watch(moneyClientProvider)),
);

/// Which page: the space, the window (both days included) and where the
/// page starts (null = the first). A record, so equal pages share a read.
typedef RecordedPaymentsPageKey = ({
  String workspaceId,
  DateTime from,
  DateTime to,
  String? afterMatchedAt,
  String? afterId,
});

/// One bounded page. Retrying is invalidating THIS page: the pages before
/// it stay on screen.
final recordedPaymentsPageProvider = FutureProvider.autoDispose
    .family<RecordedPaymentsPage, RecordedPaymentsPageKey>((ref, key) {
      final at = key.afterMatchedAt;
      final id = key.afterId;
      return ref
          .watch(recordedPaymentsRepositoryProvider)
          .page(
            key.workspaceId,
            from: key.from,
            to: key.to,
            after: at == null || id == null
                ? null
                : RecordedPaymentsCursor(matchedAt: at, id: id),
          );
    });

/// #3587 — which window of match payments: the space and its days.
typedef _ReceivedWindow = ({String workspaceId, DateTime from, DateTime to});

/// #3587 — every payment a match consumed in [window], read page by page
/// to the last (a month can span several pages), each dated by its match on
/// [dayOf] (the business's calendar day). A page the server repeats ends the
/// read rather than looping.
Future<List<ReceivedPayment>> _receivedPaymentsIn(
  RecordedPaymentsRepository repository,
  _ReceivedWindow window, {
  required DateTime Function(DateTime instant) dayOf,
}) async {
  final out = <ReceivedPayment>[];
  RecordedPaymentsCursor? after;
  final seen = <String>{};
  do {
    final page = await repository.page(
      window.workspaceId,
      from: window.from,
      to: window.to,
      after: after,
    );
    for (final p in page.items) {
      out.add((
        currency: p.currency,
        minor: p.amountMinor,
        on: dayOf(p.matchedAt),
      ));
    }
    after = page.nextCursor;
  } while (after != null && seen.add('${after.matchedAt}|${after.id}'));
  return out;
}

/// #3587 — the money received in a window (the home's "Received in" figure).
final receivedPaymentsProvider = FutureProvider.autoDispose
    .family<List<ReceivedPayment>, _ReceivedWindow>(
      (ref, window) => _receivedPaymentsIn(
        ref.watch(recordedPaymentsRepositoryProvider),
        window,
        // The instant of each match; the screen dates it on the business's
        // calendar.
        dayOf: (instant) => instant,
      ),
    );
