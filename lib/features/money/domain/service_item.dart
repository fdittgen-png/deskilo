// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'service_item.freezed.dart';

/// A consumable service of the workspace catalog (#123) — coffee,
/// printing, meeting room, ... Owner-priced; deactivated, never deleted.
@freezed
sealed class ServiceItem with _$ServiceItem implements SystemStamped {
  const factory ServiceItem({
    required String id,
    required String workspaceId,
    required String name,
    required int priceCents,
    required bool active,

    /// Which VAT rate this service is taxed at (0072); '' = the
    /// workspace's default rate. The price stays VAT-INCLUSIVE either way.
    @Default('') String vatRateId,
    /// #731 — units on the shelf; null = not tracked (a service, not a
    /// supply).
    int? stock,
    /// #2354 — where the service is supplied for VAT: connected with the
    /// premises (the default) or a general service.
    @Default(SupplyClass.property) SupplyClass supplyClass,
    /// #3552 — what a stranger reads about the service; '' = none.
    @Default('') String description,
    /// #3552 — how long it takes, in minutes; null = not time-based.
    int? durationMinutes,
    /// #3552 — the group it is listed under; '' = none.
    @Default('') String category,
    /// #3552 — shown on the public page only when the business says so.
    @Default(false) bool isPublic,
    /// #3552 — the order within its category.
    @Default(0) int sortOrder,
    /// #992 — the server's stamp on this row.
    @Default(SystemColumns.none) SystemColumns system,
  }) = _ServiceItem;
}
