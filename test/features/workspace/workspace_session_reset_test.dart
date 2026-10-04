// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What a person chose inside one workspace — the floor they browse, the plan
// spot they jumped to, the money period, a wizard in progress — is not
// carried into another workspace they switch to.
import 'package:deskilo/features/money/providers/money_face_controller.dart';
import 'package:deskilo/features/money/providers/money_focus_controller.dart';
import 'package:deskilo/features/plan/providers/plan_focus_controller.dart';
import 'package:deskilo/features/reservations/providers/browsed_level.dart';
import 'package:deskilo/features/money/domain/money_face.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Ws extends ActiveWorkspaceId {
  @override
  Future<String?> build() async => 'ws-a';
}

void main() {
  test('a switch of workspace starts the session state over', () async {
    final container = ProviderContainer(
      overrides: [activeWorkspaceIdProvider.overrideWith(_Ws.new)],
    );
    addTearDown(container.dispose);
    await container.read(activeWorkspaceIdProvider.future);

    container.read(browsedLevelProvider.notifier).select('level-of-a');
    container.read(moneyFocusControllerProvider.notifier).setPeriod('2026-09');
    container.read(moneyFaceControllerProvider.notifier).show(MoneyFace.values.last);
    container.read(planFocusControllerProvider.notifier).setFocus(
        const PlanFocus(levelId: 'level-of-a', seatId: 'seat-of-a'));
    expect(container.read(browsedLevelProvider), 'level-of-a');

    container.read(activeWorkspaceIdProvider.notifier).activate('ws-b');
    await container.pump();

    expect(container.read(browsedLevelProvider), isNull);
    expect(container.read(moneyFocusControllerProvider), isNull);
    expect(container.read(moneyFaceControllerProvider), MoneyFace.statement);
    expect(container.read(planFocusControllerProvider), isNull);
  });
}
