// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2558 — the spaces the privacy editor offers for "chosen spaces": the
// qualified references of the personal home (#2563,
// `my_personal_workspace_refs_v1`), read with no workspace selected. A
// space is named by its network reference; one on another installation is
// listed as "verification unavailable" and cannot be chosen here.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../domain/audience_space.dart';
import 'me_providers.dart';
import 'me_read_retry.dart';

final audienceSpacesProvider = FutureProvider.autoDispose<List<AudienceSpace>>(
  retry: meReadRetry,
  (ref) async {
    if (ref.watch(authStateProvider).value == null) return const [];
    final refs = await ref.watch(meRepositoryProvider).myWorkspaceRefs();
    return [for (final item in refs.refs) AudienceSpace.fromRef(item)];
  },
);
