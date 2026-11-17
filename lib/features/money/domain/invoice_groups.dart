// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3556 (part 2) — a person's own groups of invoices ("2026 taxes", "To
// reimburse"), across businesses, installations and currencies. A group is
// the person's filing on their personal home (0801): it never changes an
// invoice and no business sees it. It names each invoice by reference — the
// installation-qualified workspace Me already uses (`<installation>:<local>`)
// and the invoice's id — with the number it had when filed, and stores no
// amount. What a group holds is read from My finances each time, with the
// state its sources are in: an invoice that cannot be read now (its source
// does not answer, it was deleted, it is older than what the overview reads)
// is named by that number and left out of the totals, never shown with an
// old amount. Totals are per currency: nothing is added across currencies.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import 'finance_overview.dart';

/// One invoice, by the installation and workspace that hold it and its id.
class InvoiceRef {
  const InvoiceRef(this.networkId, this.invoiceId);

  /// `<installation id>:<workspace id>`.
  final String networkId;
  final String invoiceId;

  String get installationId => networkId.split(':').first;

  @override
  bool operator ==(Object other) =>
      other is InvoiceRef &&
      other.networkId == networkId &&
      other.invoiceId == invoiceId;

  @override
  int get hashCode => Object.hash(networkId, invoiceId);
}

/// One invoice a group names, with its number as it was last seen.
class InvoiceGroupItem {
  const InvoiceGroupItem(this.ref, this.number);

  factory InvoiceGroupItem.fromJson(JsonReader r) => InvoiceGroupItem(
    InvoiceRef(r.string('network_id'), r.string('invoice_id')),
    r.stringOr('label'),
  );

  final InvoiceRef ref;
  final String number;
}

/// A group of mine and the invoices it names.
class InvoiceGroup {
  const InvoiceGroup({
    required this.id,
    required this.name,
    this.items = const [],
  });

  factory InvoiceGroup.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'personal_invoice_groups');
    return InvoiceGroup(
      id: r.string('id'),
      name: r.string('name'),
      items: r.objects('items', InvoiceGroupItem.fromJson),
    );
  }

  final String id;
  final String name;
  final List<InvoiceGroupItem> items;

  bool holds(InvoiceRef ref) => items.any((i) => i.ref == ref);
}

/// The longest name a group may have (0801's constraint).
const int invoiceGroupNameMax = 80;

/// The longest number a reference keeps (0801's constraint).
const int invoiceGroupNumberMax = 80;

/// Why a group's name was refused.
enum InvoiceGroupRefusal {
  /// I already have a group of that name, whatever its case.
  nameTaken,

  /// Empty, or longer than [invoiceGroupNameMax].
  nameShape,
}

class InvoiceGroupRefused implements Exception {
  const InvoiceGroupRefused(this.reason);
  final InvoiceGroupRefusal reason;

  @override
  String toString() => 'InvoiceGroupRefused: ${reason.name}';
}

/// The name a group is saved under, or why it cannot be.
({String? name, InvoiceGroupRefusal? refusal}) invoiceGroupName(String typed) {
  final name = typed.trim();
  return name.isEmpty || name.length > invoiceGroupNameMax
      ? (name: null, refusal: InvoiceGroupRefusal.nameShape)
      : (name: name, refusal: null);
}

/// The groups of my personal account, on my personal home.
abstract interface class InvoiceGroupRepository {
  Future<List<InvoiceGroup>> groups();

  /// The new group's id. Throws [InvoiceGroupRefused].
  Future<String> create(String name);

  /// Throws [InvoiceGroupRefused].
  Future<void> rename(String groupId, String name);

  /// The group and its references go; the invoices stay as they are.
  Future<void> delete(String groupId);

  /// Files [ref] in the group; filing it twice changes nothing.
  Future<void> add(String groupId, InvoiceRef ref, String number);

  Future<void> remove(String groupId, InvoiceRef ref);
}

/// The reference stamped by the invoice's verified reader. An unresolved
/// row has no reference; another row's equal local id cannot supply it.
InvoiceRef? invoiceRefOf(
  FinanceOverview overview,
  FinanceInvoice invoice, {
  required String? homeInstallationId,
}) {
  final target = invoice.target;
  return target == null ? null : InvoiceRef(target.networkId, invoice.id);
}

/// A group as My finances reads it now.
class InvoiceGroupView {
  const InvoiceGroupView({
    required this.group,
    required this.invoices,
    required this.unreadable,
  });

  final InvoiceGroup group;

  /// The invoices it names that the overview holds now.
  final List<FinanceInvoice> invoices;

  /// The invoices it names that cannot be read now: named by their number,
  /// counted in no total.
  final List<InvoiceGroupItem> unreadable;

  int get count => group.items.length;

  bool shows(FinanceInvoice invoice) => invoices.any(
    (i) => i.networkId == invoice.networkId && i.id == invoice.id,
  );

  /// The face value of what it holds, one sum per currency, by currency
  /// code: never one figure across currencies.
  List<(String, int)> get totals {
    final sums = <String, int>{};
    for (final i in invoices) {
      final code = i.currency.toUpperCase();
      sums[code] = (sums[code] ?? 0) + i.totalCents;
    }
    return [for (final code in sums.keys.toList()..sort()) (code, sums[code]!)];
  }
}

/// [group] against [overview]: what it names and the overview holds, and
/// what it names and cannot be read now.
InvoiceGroupView invoiceGroupView(
  InvoiceGroup group,
  FinanceOverview overview, {
  required String? homeInstallationId,
}) {
  final byRef = <InvoiceRef, FinanceInvoice>{
    for (final i in overview.invoices)
      ?invoiceRefOf(overview, i, homeInstallationId: homeInstallationId): i,
  };
  return InvoiceGroupView(
    group: group,
    invoices: [for (final item in group.items) ?byRef[item.ref]],
    unreadable: [
      for (final item in group.items)
        if (!byRef.containsKey(item.ref)) item,
    ],
  );
}
