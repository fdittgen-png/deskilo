// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4120 -- the document an invoice's sending left with, downloaded again:
// exactly the stored bytes, for a person who may issue invoices. A stored file
// whose bytes no longer match their hash is said not intact, never handed out.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/codes/dk_code.dart';
import '../../../../core/files/file_delivery.dart';
import '../../../../core/files/file_delivery_notice.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/refusal_text.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../domain/einvoice_sent_from_stored.dart';
import '../../providers/money_providers.dart';

/// The download of what [invoiceId]'s sending left with.
class SentEInvoiceDownload extends ConsumerWidget {
  const SentEInvoiceDownload({super.key, required this.invoiceId});

  final String invoiceId;

  Future<void> _download(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final SentEInvoiceDocument sent;
    try {
      sent = await ref
          .read(eInvoiceTransmissionsProvider)
          .fetchSentDocument(invoiceId);
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'money',
        'sent e-invoice read refused',
        error: e,
        stackTrace: st,
      );
      if (!context.mounted) return;
      AppSnack.error(
        context,
        refusalCodeOf(e).code == DkCode.dki09
            ? l10n.eInvoiceSentNotIntact
            : l10n.eInvoiceSentNone,
      );
      return;
    }
    Future<void> deliver() async {
      final delivery = await deliverFile(
        context,
        ref,
        bytes: sent.bytes,
        fileName: sent.fileName,
      );
      if (!context.mounted) return;
      announceFileDelivery(context, delivery, retry: deliver);
    }

    if (!context.mounted) return;
    await deliver();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: TextButton.icon(
      key: const ValueKey('invoice-detail-sent-download'),
      icon: const Icon(Icons.download_outlined),
      label: Text(context.l10n.eInvoiceSentDownload),
      onPressed: () => _download(context, ref),
    ),
  );
}
