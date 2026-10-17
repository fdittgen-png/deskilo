// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/money/domain/supplier.dart';

/// #2567 — suppliers in memory. The server verifies an identifier against
/// its jurisdiction's pattern; the demo only checks the prefix-and-body
/// shape, which is enough to show a merge key and a number sequence.
class FakeSupplierRepository implements SupplierRepository {
  final List<Supplier> suppliers = [];
  final List<SupplierReview> reviews = [];
  final Map<String, List<SupplierBankRevision>> bank = {};

  static String _canonical(String raw) {
    final v = raw.toUpperCase().replaceAll(RegExp(r'[ .\-]'), '');
    return RegExp(r'^[A-Z]{2}[A-Z0-9]+$').hasMatch(v) ? v : '';
  }

  String _nextNumber() {
    var max = 0;
    for (final s in suppliers) {
      final n = int.tryParse(s.number);
      if (n != null && n > max) max = n;
    }
    return '${max + 1}';
  }

  @override
  Future<List<Supplier>> fetchSuppliers(String workspaceId) async =>
      List.unmodifiable(suppliers);

  @override
  Future<List<SupplierReview>> fetchReviews(String workspaceId) async =>
      List.unmodifiable(reviews);

  @override
  Future<List<SupplierBankRevision>> fetchBankHistory(
    String workspaceId,
    String supplierId,
  ) async => List.unmodifiable(bank[supplierId] ?? const []);

  @override
  Future<String> save(String workspaceId, SupplierDraft draft) async {
    final canonical = _canonical(draft.taxId);
    if (canonical.isNotEmpty &&
        draft.taxIdKind == SupplierIdKind.vat &&
        suppliers.any(
          (s) =>
              s.id != draft.id &&
              s.taxIdKind == SupplierIdKind.vat &&
              s.taxIdentifier == canonical,
        )) {
      throw StateError('another supplier already has this tax identifier');
    }
    final number = draft.number.trim();
    if (number.isNotEmpty &&
        suppliers.any((s) => s.id != draft.id && s.number == number)) {
      throw StateError('this supplier number is already used');
    }
    final i = suppliers.indexWhere((s) => s.id == draft.id);
    final id = draft.id ?? 'demo-supplier-${suppliers.length + 1}';
    final next = Supplier(
      id: id,
      number: number.isNotEmpty
          ? number
          : (i >= 0 ? suppliers[i].number : _nextNumber()),
      name: draft.name.trim(),
      taxIdEntered: draft.taxId.trim(),
      taxIdentifier: canonical,
      taxIdKind: draft.taxIdKind,
      street: draft.street,
      postalCode: draft.postalCode,
      city: draft.city,
      countryCode: draft.countryCode.toUpperCase(),
      contact: draft.contact,
      status: i >= 0 ? suppliers[i].status : SupplierStatus.active,
      bankRevision: i >= 0 ? suppliers[i].bankRevision : 0,
    );
    if (i >= 0) {
      suppliers[i] = next;
    } else {
      suppliers.add(next);
    }
    return id;
  }

  Supplier _by(String id) => suppliers.firstWhere((s) => s.id == id);

  void _replace(Supplier s, {SupplierStatus? status, int? bankRevision}) {
    final i = suppliers.indexWhere((x) => x.id == s.id);
    suppliers[i] = Supplier(
      id: s.id,
      number: s.number,
      name: s.name,
      taxIdEntered: s.taxIdEntered,
      taxIdentifier: s.taxIdentifier,
      taxIdKind: s.taxIdKind,
      street: s.street,
      postalCode: s.postalCode,
      city: s.city,
      countryCode: s.countryCode,
      contact: s.contact,
      status: status ?? s.status,
      bankRevision: bankRevision ?? s.bankRevision,
    );
  }

  @override
  Future<void> setStatus(String supplierId, SupplierStatus status) async =>
      _replace(_by(supplierId), status: status);

  @override
  Future<int> setBank(
    String supplierId, {
    required String accountHolder,
    required String iban,
    required String bic,
  }) async {
    final s = _by(supplierId);
    final history = bank.putIfAbsent(supplierId, () => []);
    final clean = iban.replaceAll(RegExp(r'\s'), '').toUpperCase();
    final cleared = accountHolder.isEmpty && clean.isEmpty && bic.isEmpty;
    final revision = s.bankRevision + 1;
    history.insert(
      0,
      SupplierBankRevision(
        revision: revision,
        accountHolder: accountHolder,
        iban: clean,
        bic: bic.toUpperCase(),
        validation: cleared
            ? BankValidation.cleared
            : RegExp(r'^[A-Z]{2}\d{2}[A-Z0-9]{11,30}$').hasMatch(clean)
            ? BankValidation.valid
            : BankValidation.invalid,
        detail: '',
        changedAt: '',
      ),
    );
    _replace(s, bankRevision: revision);
    return revision;
  }

  @override
  Future<String> resolveReview(String reviewId, String? supplierId) async {
    final i = reviews.indexWhere((r) => r.id == reviewId);
    if (i < 0) throw StateError('unknown review candidate');
    final review = reviews.removeAt(i);
    return supplierId ??
        await save(
          '',
          SupplierDraft(
            name: review.sourceName,
            taxId: review.sourceIdentifier,
          ),
        );
  }
}
