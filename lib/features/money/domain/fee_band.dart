// SPDX-License-Identifier: 0BSD
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../core/data/system_columns.dart';

part 'fee_band.freezed.dart';

/// One fee band of the percentage-subscription pricing (ADR 0008): the
/// monthly fee for every member whose subscription percentage falls into
/// `(fromPct, toPct]` (inclusive-upper). Bands tile (0, 100] contiguously —
/// enforced server-side and by the band editor.
@freezed
sealed class FeeBand with _$FeeBand implements SystemStamped {
  const factory FeeBand({
    required String id,
    required String workspaceId,
    required int fromPct,
    required int toPct,
    required int feeCents,
    required int overageFeeCents,
    /// #992 — the server's stamp on this row.
    @Default(SystemColumns.none) SystemColumns system,
  }) = _FeeBand;
}
