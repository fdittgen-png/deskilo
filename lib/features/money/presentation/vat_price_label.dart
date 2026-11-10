// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

import '../../../core/i18n/app_format.dart';

/// The VAT annotation a GROSS price should carry on catalogue surfaces
/// (#537): "· TVA 20 % incl." — resolved from the item's own rate, or
/// the workspace default when the item has none. Null (no annotation)
/// when the workspace doesn't charge VAT or the effective rate is 0 —
/// a price that carries no tax should not claim one.
String? vatRateSuffix({
  required bool chargesVat,
  required List<VatRate> rates,
  required String vatRateId,
  required AppFormat format,
}) {
  if (!chargesVat) return null;
  final rate = vatRateId.isEmpty
      ? rates.where((r) => r.isDefault && r.active).firstOrNull
      : rates.where((r) => r.id == vatRateId).firstOrNull;
  if (rate == null || rate.percent <= 0) return null;
  return format.rate(rate.percent);
}
