// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:deskilo/features/money/domain/supplier_balance.dart';
import 'package:deskilo/features/money/providers/supplier_balance_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Balances implements SupplierBalanceRepository {
  final calls = <String>[];

  @override
  Future<List<SupplierBalance>> fetchBalances(String workspaceId) async {
    calls.add(workspaceId);
    if (workspaceId == 'denied') throw StateError('refused');
    return [SupplierBalance(
      supplierId: workspaceId,
      currency: 'EUR',
      remainingCents: 125,
    )];
  }
}

void main() {
  test('workspace snapshots stay separate and refusal is not zero', () async {
    final repo = _Balances();
    final container = ProviderContainer(overrides: [
      supplierBalanceRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    final a = container.listen(supplierBalancesProvider('a'), (_, _) {});
    final b = container.listen(supplierBalancesProvider('b'), (_, _) {});
    final denied = container.listen(supplierBalancesProvider('denied'), (_, _) {});
    expect((await container.read(supplierBalancesProvider('a').future)).single.supplierId, 'a');
    expect((await container.read(supplierBalancesProvider('b').future)).single.supplierId, 'b');
    await expectLater(container.read(supplierBalancesProvider('denied').future), throwsStateError);
    expect(repo.calls, containsAll(['a', 'b', 'denied']));
    a.close();
    b.close();
    denied.close();
  });
}
