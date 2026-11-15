// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4005 — a house just made: once the person stands in it, its birth record
// is shown once over its home, and not again.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/workspace/presentation/widgets/house_birth_view.dart';
import '../../features/workspace/providers/organisation_providers.dart';
import '../../features/workspace/providers/workspace_providers.dart';

/// Watched from the shell's build: when the house just made is the one
/// open, its record is shown after this frame.
void watchHouseBirthNotice(WidgetRef ref) {
  final pending = ref.watch(pendingHouseBirthProvider);
  final current = ref.watch(currentWorkspaceProvider).value?.id;
  if (pending == null || pending != current) return;
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => unawaited(_show(ref, pending)),
  );
}

Future<void> _show(WidgetRef ref, String id) async {
  if (!ref.context.mounted || ref.read(pendingHouseBirthProvider) != id) {
    return;
  }
  // Once: cleared before anything is awaited.
  ref.read(pendingHouseBirthProvider.notifier).set(null);
  final birth = await ref.read(houseBirthProvider(id).future);
  final organisations = await ref.read(myOrganisationsProvider.future);
  if (birth == null || !ref.context.mounted) return;
  final head = [
    for (final o in organisations) ?o.houseOf(birth.headWorkspaceId ?? ''),
  ].firstOrNull;
  await HouseBirthView.showOnce(
    ref.context,
    birth: birth,
    head: head?.name ?? '',
  );
}
