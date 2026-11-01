// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2578 — the payments behind the collected figure, one page at a time.
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
