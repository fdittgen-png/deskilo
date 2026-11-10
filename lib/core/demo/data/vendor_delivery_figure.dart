// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 step 5 -- the delivery figure of a Demo space (0699's rules): the
// orders SENT in the months, each in one cohort by whether its last goods
// receipt reached the space by the expected date; the days from sending to the
// last receipt and from the expected date to it over the received ones; by
// supplier.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../features/money/domain/purchase_order.dart';
import '../../../features/workspace/domain/kpi_vendor_delivery.dart';
import '../../text/collation.dart';
import 'purchase_order_repository.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

String _month(DateTime d) => yearMonth(d.year, d.month);

/// `percentile_disc`: the first value at or past the fraction.
int? _percentile(List<int> values, double fraction) {
  if (values.isEmpty) return null;
  final sorted = [...values]..sort();
  return sorted[((fraction * sorted.length).ceil() - 1).clamp(0, sorted.length - 1)];
}

/// The cohort of a sent order: [last] is its last receipt day, [expected] its
/// expected day, [today] the day the figure is read.
DeliveryCohort _cohortOf(
  PurchaseOrderState state,
  DateTime? last,
  DateTime? expected,
  DateTime today,
) {
  if (state == PurchaseOrderState.received) {
    if (expected == null || last == null) return DeliveryCohort.unknownExpected;
    return last.isAfter(expected) ? DeliveryCohort.late : DeliveryCohort.onTime;
  }
  if (state == PurchaseOrderState.partlyReceived) return DeliveryCohort.partial;
  return expected != null && expected.isBefore(today)
      ? DeliveryCohort.overdue
      : DeliveryCohort.open;
}

/// One sent order read: its supplier, cohort and the received days.
typedef _Sent = ({
  String supplierId,
  String supplierName,
  DeliveryCohort cohort,
  int? lead,
  int? delay,
});

_Sent _read(
  PurchaseOrder o,
  List<DateTime> receipts,
  DateTime today,
) {
  final last = receipts.isEmpty ? null : (receipts..sort()).last;
  final expected = o.expectedOn == null ? null : _day(o.expectedOn!);
  final cohort = _cohortOf(o.state, last, expected, today);
  final received = o.state == PurchaseOrderState.received && last != null;
  return (
    supplierId: o.supplierId,
    supplierName: o.supplierName,
    cohort: cohort,
    lead: received ? last.difference(_day(o.sentAt!)).inDays : null,
    delay: received && expected != null ? last.difference(expected).inDays : null,
  );
}

VendorDeliveryReading demoVendorDelivery({
  required FakePurchaseOrderRepository? orders,
  required String fromMonth,
  required String toMonth,
  required DateTime now,
}) {
  final sent = <_Sent>[
    for (final o in orders?.orders ?? const <PurchaseOrder>[])
      if (o.sentAt != null &&
          o.state != PurchaseOrderState.cancelled &&
          _month(o.sentAt!).compareTo(fromMonth) >= 0 &&
          _month(o.sentAt!).compareTo(toMonth) <= 0)
        _read(
          o,
          [
            for (final r in orders!.receipts)
              if (r.orderId == o.id) _day(r.receivedOn),
          ],
          _day(now),
        ),
  ];
  final leads = [for (final s in sent) ?s.lead];
  final delays = [for (final s in sent) ?s.delay];
  final rows = <VendorDelivery>[
    for (final id in {for (final s in sent) s.supplierId})
      _supplier(id, [for (final s in sent) if (s.supplierId == id) s]),
  ]..sort((a, b) {
      final byOrders = b.orders.compareTo(a.orders);
      if (byOrders != 0) return byOrders;
      final byName = compareNames(a.name, b.name);
      return byName != 0 ? byName : a.supplierId.compareTo(b.supplierId);
    });
  return (
    orders: sent.length,
    cohorts: {
      for (final c in DeliveryCohort.values)
        c: sent.where((s) => s.cohort == c).length,
    },
    medianLead: _percentile(leads, 0.5),
    p90Lead: _percentile(leads, 0.9),
    medianDelay: _percentile(delays, 0.5),
    p90Delay: _percentile(delays, 0.9),
    rows: rows,
  );
}

VendorDelivery _supplier(String id, List<_Sent> of) => (
  supplierId: id,
  name: of.first.supplierName,
  orders: of.length,
  onTime: of.where((s) => s.cohort == DeliveryCohort.onTime).length,
  late: of.where((s) => s.cohort == DeliveryCohort.late).length,
  medianLeadDays: _percentile([for (final s in of) ?s.lead], 0.5),
);
