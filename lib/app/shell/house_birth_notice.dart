// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4005 — a house just made: once the person stands in it, its birth record
// is shown once over its home, and not again.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/workspace/presentation/widgets/house_birth_view.dart';
import '../../features/workspace/providers/organisation_providers.dart';
import '../../features/workspace/providers/workspace_providers.dart';

void watchHouseBirthNotice(WidgetRef ref) {
  Future<void> show(String? pending, String? current) async {
    if (pending == null || pending != current || !ref.context.mounted) return;
    ref.read(pendingHouseBirthProvider.notifier).set(null);
    final birth = await ref.read(houseBirthProvider(pending).future);
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

  ref
    ..listen(
      currentWorkspaceProvider,
      (_, next) => show(ref.read(pendingHouseBirthProvider), next.value?.id),
    )
    ..listen(
      pendingHouseBirthProvider,
      (_, next) => show(next, ref.read(currentWorkspaceProvider).value?.id),
    );
}
