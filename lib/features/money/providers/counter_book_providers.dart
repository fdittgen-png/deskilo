// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/counter_book.dart';

/// #4185 -- the counter's book on the server: its receipts and the commands that correct them. The app wires the live
/// one (`counterBookPortFromApp`); the Demo and the tests replace it.
final counterBookPortProvider = Provider<CounterBookPort>((ref) => throw UnimplementedError('the counter book port is wired by the app'));

/// #4185 -- the receipts of a business, read again after every act on them.
final counterBookProvider = FutureProvider.autoDispose.family<CounterBook, String>(
  (ref, workspaceId) => ref.watch(counterBookPortProvider).book(workspaceId),
  retry: (_, _) => null,
);
