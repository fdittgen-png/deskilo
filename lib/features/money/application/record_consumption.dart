// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1449 — recording a consumption, where the SHELF and the MONTH decide
// whether there is a write at all.
//
// Both rules lived in the sheet, and neither was ever stated. The shelf
// was a disabled dropdown entry plus a disabled button, two conditions
// written apart from each other; the month was
// `if (!RegExp(...).hasMatch(period)) return;` after the sheet had
// already closed — a refusal with no sentence, so a mistyped period
// looked exactly like a successful recording that the other side had
// simply not confirmed yet.
//
// Here the command refuses, and says which refusal it was. A tracked
// supply may not go negative: the member would be billed for units
// nobody handed them, and the shelf would claim stock it does not have.
import '../domain/money_repository.dart';
import '../domain/service_item.dart';

/// What recording a consumption means.
enum ConsumptionOutcome {
  /// The service is off the catalogue. Nothing can be taken off a shelf
  /// that is not there.
  serviceInactive,

  /// The shelf does not hold that many (#731). REFUSED.
  insufficientStock,

  /// Outside 1–999 — the range the RPC itself enforces, refused here so
  /// the round trip is not spent finding out.
  quantityOutOfRange,

  /// The period is not a month. REFUSED — a service charge lands on ONE
  /// monthly bill, and 'yyyy-MM' is how that bill is named.
  periodNotAMonth,

  /// Filed as a PENDING service_charge: the ledger moves when the other
  /// side confirms, not now.
  filed,
}

/// Whether [service] can hand out [quantity] units.
///
/// A null stock is a service and not a supply — a meeting room does not
/// run out. The sheet asks this to decide what to OFFER, the command
/// asks it to decide whether to write: one sentence read twice rather
/// than two conditions that drift apart.
bool servesQuantity(ServiceItem service, int quantity) {
  final stock = service.stock;
  return stock == null || stock >= quantity;
}

/// Whether [period] names a billing month ('yyyy-MM').
bool isBillingMonth(String period) =>
    RegExp(r'^\d{4}-\d{2}$').hasMatch(period.trim());

/// What recording [quantity] of [service] for [period] means.
ConsumptionOutcome consumptionOutcome({
  required ServiceItem service,
  required int quantity,
  required String period,
}) {
  if (!service.active) return ConsumptionOutcome.serviceInactive;
  if (quantity < 1 || quantity > 999) {
    return ConsumptionOutcome.quantityOutOfRange;
  }
  if (!servesQuantity(service, quantity)) {
    return ConsumptionOutcome.insufficientStock;
  }
  if (!isBillingMonth(period)) return ConsumptionOutcome.periodNotAMonth;
  return ConsumptionOutcome.filed;
}

/// Consumed services, as the decisions behind them.
class Consumptions {
  const Consumptions(this._money);

  final MoneyRepository _money;

  /// Records [quantity] of [service] onto [period]'s bill, and says
  /// which outcome it was.
  ///
  /// Nothing is written for any outcome but [ConsumptionOutcome.filed]:
  /// the refusal is the command's, not the sheet's.
  Future<ConsumptionOutcome> record({
    required String workspaceId,
    required String subjectMemberId,
    required ServiceItem service,
    required int quantity,
    required String period,
  }) async {
    final outcome = consumptionOutcome(
      service: service,
      quantity: quantity,
      period: period,
    );
    if (outcome != ConsumptionOutcome.filed) return outcome;
    await _money.recordServiceCharge(
      workspaceId: workspaceId,
      subjectMemberId: subjectMemberId,
      serviceId: service.id,
      quantity: quantity,
      period: period.trim(),
    );
    return outcome;
  }
}
