// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2358 — asking a national channel what became of a document it took:
// the Peppol evidence, the PA lifecycle, the SdI notification, the KSeF
// number, the ANAF state. The send-e-invoice function asks with the
// space's credential and stores the answer on the transmission; this is
// the one door the screens use, and it refreshes what they show.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/einvoice_gateway.dart';
import '../providers/money_providers.dart';

Future<EInvoiceSubmission> requestEInvoiceReceipt(
  WidgetRef ref, {
  required String workspaceId,
  required String transmissionId,
}) async {
  final answer = await ref
      .read(moneyRepositoryProvider)
      .requestEInvoiceReceipt(
        workspaceId: workspaceId,
        transmissionId: transmissionId,
      );
  ref.invalidate(invoiceTransmissionsProvider);
  return answer;
}
