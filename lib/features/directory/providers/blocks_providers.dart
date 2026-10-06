// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/messenger.dart';
import 'messenger_providers.dart';

/// The accounts I blocked on the server [source] ('' is this one).
final myBlocksProvider = FutureProvider.autoDispose
    .family<List<BlockedAccount>, String>(
  (ref, source) =>
      ref.watch(messengerActionsProvider(source: source)).myBlocks(),
);
