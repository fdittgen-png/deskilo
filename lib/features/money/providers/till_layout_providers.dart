// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/till_layout.dart';
import '../domain/till_layout_port.dart';

/// #4448 -- where the till layouts live. The app wires the live one (`tillLayoutPortFromApp`); the Demo and the tests
/// replace it.
final tillLayoutPortProvider = Provider<TillLayoutPort>((ref) => throw UnimplementedError('the till layout port is wired by the app'));

/// The layout a till uses, read once per till screen: a running sale never sees it change; null keeps the generated keys.
final tillPublishedLayoutProvider = FutureProvider.autoDispose.family<TillLayout?, ({String workspaceId, String tillId})>(
  (ref, k) => ref.watch(tillLayoutPortProvider).published(k.workspaceId, k.tillId),
  retry: (_, _) => null,
);
