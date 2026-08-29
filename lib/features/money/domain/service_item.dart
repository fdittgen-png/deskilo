// SPDX-License-Identifier: 0BSD
import 'package:freezed_annotation/freezed_annotation.dart';

part 'service_item.freezed.dart';

/// A consumable service of the workspace catalog (#123) — coffee,
/// printing, meeting room, ... Owner-priced; deactivated, never deleted.
@freezed
sealed class ServiceItem with _$ServiceItem {
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
  }) = _ServiceItem;
}
