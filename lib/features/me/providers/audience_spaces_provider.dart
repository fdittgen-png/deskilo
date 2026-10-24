// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2558 — the spaces the privacy editor offers for "chosen spaces". It reads
// the personal home's own list of my memberships, never the selected
// workspace, so it answers with zero spaces and with none selected. This is
// the one seam a later checkpoint switches to the qualified references of
// the personal home (#2563).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/audience_space.dart';
import 'me_read_retry.dart';

final audienceSpacesProvider = FutureProvider.autoDispose<List<AudienceSpace>>(
  retry: meReadRetry,
  (ref) async {
    if (ref.watch(authStateProvider).value == null) return const [];
    final spaces = await ref.watch(myWorkspacesProvider.future);
    return [
      for (final space in spaces) AudienceSpace(id: space.id, name: space.name),
    ];
  },
);
