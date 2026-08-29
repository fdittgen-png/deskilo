// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'money_focus_controller.g.dart';

/// One-shot "open the Money tab on this period" request (#718): the
/// calendar hub sets it before switching branches; the Money screen
/// consumes it and clears it. Same shape and reason as
/// [PlanFocusController] (#182) — the branch is kept alive by the
/// shell, so route params cannot reach it.
@Riverpod(keepAlive: true)
class MoneyFocusController extends _$MoneyFocusController {
  @override
  String? build() => null;

  /// `yyyy-MM`.
  void setPeriod(String period) => state = period;

  void clear() => state = null;
}
