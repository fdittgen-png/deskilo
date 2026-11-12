// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3610 — a customer named by the invoicing page's address
// (`/invoices?customer=<id>`, a search result) opens as its row opens it,
// once. A customer the reader has no invoice of — one that does not exist,
// or that they may not read — is said in words; the list stays usable.
// #3614 gives customers an address of their own, and this goes.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../providers/money_providers.dart';

/// Opens [customerId] through [open] when the reader's invoices name it.
Future<void> openLinkedCustomer(
  BuildContext context,
  WidgetRef ref,
  String customerId,
  Future<void> Function(String customerId) open,
) async {
  var known = false;
  try {
    final invoices = await ref.read(invoicesProvider.future);
    known = invoices.any((i) => i.memberId == customerId);
  } on Object catch (e, st) {
    TraceLogger.instance.warn(
      'money',
      'the linked customer could not be read',
      error: e,
      stackTrace: st,
    );
  }
  if (!context.mounted) return;
  if (known) return open(customerId);
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      key: const ValueKey('search-record-unreadable'),
      content: Text(context.l10n.searchRecordUnreadable),
    ),
  );
}
