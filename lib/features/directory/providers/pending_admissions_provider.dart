// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3696 -- the businesses the person has asked to join and that have not
// answered, read from the person's own account (every visit, every device),
// not from a page's memory. The directory owns the question; Me answers it:
// the composition root overrides this with `pendingAdmissionsFromMe`
// (`personalWorkspaceRefsProvider`'s pending references). Without that
// override (a test of the directory alone) the person has none pending.
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The ids of the businesses a request to join is waiting on.
final pendingAdmissionsProvider = FutureProvider.autoDispose<Set<String>>(
  (ref) async => const <String>{},
  // A failed read is said at once, with Try again, not after ten retries.
  retry: (retryCount, error) => null,
);
