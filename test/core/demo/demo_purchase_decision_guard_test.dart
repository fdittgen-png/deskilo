// SPDX-License-Identifier: AGPL-3.0-or-later
// A Demo decision refuses after access is removed and can recover without
// mutating the pending bill or creating a payable on refusal.
import 'package:deskilo/core/demo/demo_purchasing_overrides.dart';
import 'package:deskilo/core/demo/seed/demo_purchase_seed.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/providers/purchase_approval_provider.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

final _access = StateProvider<bool>((ref) => true);

void main() {
  test(
    'Demo stale decision refuses and succeeds after access returns',
    () async {
      final demo = seedDemoPurchasing(DateTime(2026, 11, 2));
      final container = ProviderContainer(
        overrides: [
          ...demoPurchasingOverrides((home: demo, leipzig: demo, london: demo,
            newYork: demo, zurich: demo, milan: demo, twin: demo)),
          purchaseApprovalAccessProvider.overrideWith(
            (ref, id) => ref.watch(_access),
          ),
        ],
      );
      addTearDown(container.dispose);
      final repository = container.read(purchaseRepositoryProvider);
      final before = await repository.fetchDetail('ws-1', 'demo-bill-approval');
      final payablesBefore = demo.purchases.payables.length;
      expect(before.summary.state, PurchaseState.pending);
      container.read(_access.notifier).state = false;
      await expectLater(
        repository.decideBill(
          'ws-1',
          before.summary.id,
          before.revision,
          approve: true,
          reason: '',
          requestId: 'refused',
        ),
        throwsStateError,
      );
      expect(
        (await repository.fetchDetail('ws-1', before.summary.id)).summary.state,
        PurchaseState.pending,
      );
      expect(demo.purchases.payables.length, payablesBefore);
      container.read(_access.notifier).state = true;
      expect(
        await repository.decideBill(
          'ws-1',
          before.summary.id,
          before.revision,
          approve: true,
          reason: '',
          requestId: 'recovered',
        ),
        PurchaseState.approved,
      );
      expect(demo.purchases.payables.length, payablesBefore + 1);
    },
  );
}
