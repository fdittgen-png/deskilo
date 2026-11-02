// SPDX-License-Identifier: AGPL-3.0-or-later

import '../../../core/data/json_reader.dart';
import 'purchase.dart';

/// A stable keyset cursor; a non-null cursor means another page exists.
typedef SupplierPayablesCursor = ({String created, String id});

/// A single supplier's payable page with an explicit continuation.
class SupplierPayablesPage {
  const SupplierPayablesPage({required this.rows, required this.next});

  factory SupplierPayablesPage.fromJson(Object? raw) {
    final result = JsonReader.of(raw, context: 'supplier_payables_page_v1');
    final cursor = result.objectOrNull('next');
    return SupplierPayablesPage(
      rows: [for (final row in result.list('rows')) PayableRow.fromJson(row)],
      next: cursor == null
          ? null
          : (created: cursor.string('created'), id: cursor.string('id')),
    );
  }

  final List<PayableRow> rows;
  final SupplierPayablesCursor? next;
}
