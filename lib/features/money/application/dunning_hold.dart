// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1913 — holding an invoice's reminders. The decision is the server's
// (`place_dunning_hold` / `release_dunning_hold` refuse anyone who does
// not issue the space's invoices); this is the one door the screens use,
// and it refreshes what the sheet shows.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/money_providers.dart';

Future<void> placeDunningHold(
  WidgetRef ref,
  String invoiceId, {
  required String reason,
  String note = '',
}) async {
  await ref
      .read(moneyRepositoryProvider)
      .placeDunningHold(invoiceId, reason: reason, note: note);
  ref.invalidate(dunningHoldsProvider);
}

Future<void> releaseDunningHold(WidgetRef ref, String invoiceId) async {
  await ref.read(moneyRepositoryProvider).releaseDunningHold(invoiceId);
  ref.invalidate(dunningHoldsProvider);
}
