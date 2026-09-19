// SPDX-License-Identifier: 0BSD
import 'package:deskilo/features/money/domain/credit_product.dart';

/// #1279 — carnets in memory: sales and balances as the server keeps them.
class FakeCreditRepository implements CreditRepository {
  final products = <CreditProduct>[];
  final balances = <String, int>{};
  final sales = <({String memberId, String productId})>[];

  @override
  Future<List<CreditProduct>> fetchCreditProducts(String workspaceId) async =>
      List.of(products);

  @override
  Future<void> createCreditProduct(
    String workspaceId, {
    required String name,
    required int halfDays,
    required int priceCents,
    int? validityMonths,
  }) async {
    products.add(CreditProduct(
      id: 'carnet-${products.length + 1}',
      name: name,
      halfDays: halfDays,
      priceCents: priceCents,
      validityMonths: validityMonths,
    ));
  }

  @override
  Future<void> setCreditProductActive(String productId, bool active) async {
    final i = products.indexWhere((p) => p.id == productId);
    final p = products[i];
    products[i] = CreditProduct(
      id: p.id,
      name: p.name,
      halfDays: p.halfDays,
      priceCents: p.priceCents,
      validityMonths: p.validityMonths,
      active: active,
    );
  }

  @override
  Future<String> sellCredit(
      String workspaceId, String memberId, String productId) async {
    final p = products.firstWhere((x) => x.id == productId && x.active);
    sales.add((memberId: memberId, productId: productId));
    balances[memberId] = (balances[memberId] ?? 0) + p.halfDays;
    return 'credit-${sales.length}';
  }

  @override
  Future<int> memberCreditBalance(String memberId) async =>
      balances[memberId] ?? 0;
}
