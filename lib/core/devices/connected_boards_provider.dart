// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_board.dart';

/// #4454 -- where the till boards live. The app wires the server's (`tillBoardPortFromApp`); the Demo its own.
final tillBoardPortProvider = Provider<TillBoardPort>((ref) => throw UnimplementedError('the till board port is wired by the app'));

/// #4466, #4454 -- the till boards of the business, waiting for approval or paired: what Settings › Devices lists and
/// the Master data card counts.
final connectedTillBoardsProvider = FutureProvider.autoDispose.family<List<TillBoard>, String>(
  (ref, workspaceId) => ref.watch(tillBoardPortProvider).boards(workspaceId),
  retry: (_, _) => null,
);
