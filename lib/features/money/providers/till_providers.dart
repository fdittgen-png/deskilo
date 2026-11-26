// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/widgets.dart' show SizedBox, Widget;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ids/request_id.dart';
import '../domain/counter_receipt_document.dart';
import '../domain/counter_till.dart';
import '../domain/till_offline.dart';
import '../domain/till_offline_queue.dart';
import '../presentation/till_session.dart';

/// #4366 -- the till's server: readiness, a priced draft and the one command that makes the sale. The app wires the
/// live one (`tillPortFromApp`); the Demo and the tests replace it.
final tillPortProvider = Provider<TillPort>((ref) => throw UnimplementedError('the till port is wired by the app'));

/// #4476 -- the till's copies of a receipt: the till port itself where it prints them, null where it does not.
final tillCopyPortProvider = Provider<TillCopyPort?>((ref) => switch (ref.watch(tillPortProvider)) {
  final TillCopyPort copies => copies,
  _ => null,
});

/// #4366 -- the lots a till may sell an item from: the till port itself where it reads them, null where it does not.
final tillLotsPortProvider = Provider<TillLotsPort?>((ref) => switch (ref.watch(tillPortProvider)) {
  final TillLotsPort lots => lots,
  final TillLotsSource source => source.lotsPort,
  _ => null,
});

/// #4366 -- whether the country allows this business's till to sell, and why not when it does not. Read again when the
/// screen opens: a country's operation can move between two shifts.
final tillReadinessProvider = FutureProvider.autoDispose.family<TillReadiness, String>(
  (ref, workspaceId) => ref.watch(tillPortProvider).readiness(workspaceId),
  retry: (_, _) => null,
);

/// #4184 -- a finalized receipt as its frozen document, through the versioned reader.
final counterReceiptProvider = FutureProvider.autoDispose.family<CounterReceiptDocument, ({String workspaceId, String receiptId})>(
  (ref, key) => ref.watch(tillPortProvider).receipt(key.workspaceId, key.receiptId),
  retry: (_, _) => null,
);

/// #4366 -- one till session per business, kept for as long as the app runs: a sale whose answer was lost is still
/// there to be confirmed when the till is opened again, and a sale being made is not lost with the screen.
final tillSessionProvider = Provider.family<TillSession, String>((ref, workspaceId) {
  final session = TillSession(port: ref.read(tillPortProvider), workspaceId: workspaceId);
  ref.onDispose(session.dispose);
  return session;
});

/// #4373 -- the server side of the offline sales (`counter_offline_sync_v1`, `counter_offline_list_v1`). The app wires the live
/// one (`tillPortFromApp`'s sibling); the Demo and the tests replace it.
final tillOfflinePortProvider = Provider<TillOfflinePort>((ref) => throw UnimplementedError('the offline till port is wired by the app'));

/// #4373 -- where the offline state of a business's till is kept: the app wires the secure store (`tillOfflineStoreFromApp`); the
/// Demo and the tests keep it in memory.
final tillOfflineStoreFactoryProvider = Provider<OfflineStore Function(String workspaceId)>(
  (ref) => throw UnimplementedError('the offline store is wired by the app'),
);

/// #4373 -- the offline queue of one business's till: its prices, its device name and the sales waiting to be sent.
final tillOfflineQueueProvider = Provider.family<TillOfflineQueue, String>(
  (ref, workspaceId) => TillOfflineQueue(store: ref.read(tillOfflineStoreFactoryProvider)(workspaceId), newRequestId: newRequestId),
);

/// #4373 -- whether this business's till may go on selling for cash when the connection is lost (`counterOfflineCash` on, under
/// till sessions). Off until the app wires it from the business's features (`tillOfflineEnabledFromApp`).
final tillOfflineEnabledProvider = Provider<bool>((ref) => false);

/// #4184 -- how a counter receipt leaves the counter (`counter.document_channel`: `share`, `print` or `both`). The app wires it from
/// the business's settings (`counterDocumentChannelFromApp`); `share` stands where nothing is wired.
final counterDocumentChannelProvider = Provider.family<String, String>((ref, workspaceId) => 'share');

/// #4184 -- the editor of the counter's settings (`counter.*`), shown beside the readiness: the registry editor every setting is
/// changed in. The app wires it (`counterSettingsEditorFromApp`), so the money feature does not import the workspace.
final counterSettingsEditorProvider = Provider<Widget Function(String workspaceId)>((ref) => (_) => const SizedBox.shrink());
