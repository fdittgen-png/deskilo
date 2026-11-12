// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3610 — a customer named by the invoicing page's address
// (`/invoices?customer=<id>`, a search result) opens as its row opens it,
// once. A customer the reader has no invoice of — one that does not exist,
// or that they may not read — is said in words; the list stays usable.
// #3614 gives customers an address of their own, and this goes.
import 'dart:async';

import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/trace_logger.dart';

/// Opens [customerId] through [open] when the reader's [invoices] name it.
Future<void> _openLinkedCustomer(
  BuildContext context,
  Future<List<Invoice>> invoices,
  String customerId,
  Future<void> Function(String customerId) open,
) async {
  var known = false;
  try {
    known = (await invoices).any((i) => i.memberId == customerId);
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

/// [customerId] (when the address names one) opened over [state]'s page
/// once its frame is drawn.
void openLinkedCustomerAfterFrame(
  State state,
  String? customerId,
  Future<List<Invoice>> Function() invoices,
  Future<void> Function(String customerId) open,
) {
  if (customerId == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!state.mounted) return;
    unawaited(_openLinkedCustomer(state.context, invoices(), customerId, open));
  });
}
