// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/pending_send_ids.dart';

/// #3745 — the request ids of the sends whose outcome is not known yet, per
/// conversation draft; kept for the whole session, so a thread reopened
/// after a lost answer repeats with the same id.
final pendingSendIdsProvider = Provider<PendingSendIds>(
  (ref) => PendingSendIds(),
);
