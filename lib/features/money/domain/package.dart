// SPDX-License-Identifier: MIT
import 'package:freezed_annotation/freezed_annotation.dart';

part 'package.freezed.dart';

/// An owner-defined day package (migration 0042): a number of [days] a
/// member on the 'package' over-consumption policy can buy for
/// [priceCents] once their monthly entitlement is used up. Buying raises
/// the member's cap by `days × 2` half-days for the current period.
@freezed
sealed class Package with _$Package {
  const factory Package({
    required String id,
    required String workspaceId,
    required String name,
    required int days,
    required int priceCents,
    @Default(true) bool active,
  }) = _Package;

  factory Package.fromRow(Map<String, dynamic> row) => Package(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        name: row['name'] as String,
        days: row['days'] as int,
        priceCents: row['price_cents'] as int,
        active: row['active'] as bool? ?? true,
      );
}
