// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The workspace's VAT rates are written as one set: `set_vat_rates`
// replaces them whole, with exactly one default among them. The VAT screen
// and the setup guide's VAT step save through this one class.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/tax_reporting_repository.dart';
import '../domain/vat_rate.dart';
import '../providers/money_queries_providers.dart';

part 'save_vat_rates.g.dart';

class SaveVatRates {
  const SaveVatRates(this._repository);
  final TaxReportingRepository _repository;

  /// Replaces [workspaceId]'s rates with [rates]. Throws whatever the
  /// repository throws.
  Future<void> save(String workspaceId, List<VatRate> rates) =>
      _repository.setVatRates(workspaceId, rates);
}

/// The VAT rates' one write.
@riverpod
SaveVatRates saveVatRates(Ref ref) =>
    SaveVatRates(ref.watch(taxReportingRepositoryProvider));
