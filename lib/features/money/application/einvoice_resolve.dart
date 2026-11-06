// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3335 — settling an `uncertain` e-invoice submission by hand: the one door
// the screens use. The send-e-invoice function re-checks the send authority,
// records who settled it, why and on what evidence, and refuses a second
// resolution; this refreshes what the screens show.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/einvoice_resolution.dart';
import '../providers/money_providers.dart';

Future<EInvoiceResolveResult> resolveEInvoice(
  WidgetRef ref, {
  required String workspaceId,
  required String transmissionId,
  required EInvoiceResolution resolution,
  required String reason,
  required String evidence,
  bool documentRejected = false,
}) async {
  final result = await ref
      .read(eInvoiceTransmissionsProvider)
      .resolveEInvoiceTransmission(
        workspaceId: workspaceId,
        transmissionId: transmissionId,
        resolution: resolution,
        reason: reason.trim(),
        evidence: evidence.trim(),
        documentRejected: documentRejected,
      );
  ref.invalidate(invoiceTransmissionsProvider);
  return result;
}
