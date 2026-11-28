// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4518 -- what a new purchase order starts from when its supplier is chosen: the e-mail of the supplier's preferred purchasing contact as its
// recipient, and the day its goods are expected, the supplier's lead time after today. Each fills only an entry that is still empty, so
// what the person typed stays; and a read that fails leaves the draft as it was.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/time/clock.dart';
import '../../providers/supplier_contact_providers.dart';

/// What the supplier gave the order.
typedef SupplierOrderStart = ({String? email, String? contactName, DateTime? expectedOn});

abstract final class SupplierOrderDefaults {
  /// The recipient and the expected day of a new order to [supplierId]; null parts where the supplier states none.
  static Future<SupplierOrderStart> of(WidgetRef ref, String workspaceId, String supplierId) async {
    final key = (workspaceId: workspaceId, supplierId: supplierId);
    final contacts = await ref.read(supplierContactsProvider(key).future);
    final terms = await ref.read(supplierTermsProvider(key).future);
    final preferred = contacts.where((c) => c.preferred && !c.retired && c.email.isNotEmpty).firstOrNull;
    final lead = terms.orderLeadDays;
    final today = ref.read(clockProvider).now();
    return (
      email: preferred?.email,
      contactName: preferred?.name,
      expectedOn: lead == null ? null : DateTime(today.year, today.month, today.day + lead),
    );
  }
}
