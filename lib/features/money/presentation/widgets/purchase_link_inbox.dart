// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2573 — the evidence of a purchase can be a supplier invoice the
// e-invoice inbox received: the person picks it from the inbox and the
// server links it (`link_purchase_source_v1`). A rejected invoice, or one
// the document already holds, is not offered; nothing is copied.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../domain/einvoice_inbox.dart';
import '../../domain/purchase.dart';
import '../../providers/einvoice_inbox_providers.dart';
import '../../providers/purchase_providers.dart';

/// Lets the person link a received invoice to [detail]; true once linked.
Future<bool?> showLinkInboxDialog(
  BuildContext context,
  String workspaceId,
  PurchaseDetail detail,
) => showDialog<bool>(
  context: context,
  builder: (_) => _LinkInboxDialog(workspaceId: workspaceId, detail: detail),
);

class _LinkInboxDialog extends ConsumerStatefulWidget {
  const _LinkInboxDialog({required this.workspaceId, required this.detail});

  final String workspaceId;
  final PurchaseDetail detail;

  @override
  ConsumerState<_LinkInboxDialog> createState() => _LinkInboxDialogState();
}

class _LinkInboxDialogState extends ConsumerState<_LinkInboxDialog> {
  // One intent per open dialog: a retry of the same pick replays.
  final _requestId = newRequestId();
  var _busy = false;

  Future<void> _link(InboxDocument document) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await ref
          .read(purchaseCommandProvider)
          .linkInboxDocument(
            widget.workspaceId,
            widget.detail,
            document.id,
            _requestId,
          );
    } on Object catch (e, st) {
      TraceLogger.instance.error(
        'money',
        'link received invoice failed',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnack.error(context, l10n.purchaseLinkInboxFailed);
      return;
    }
    ref
      ..invalidate(
        purchaseDetailProvider((
          workspaceId: widget.workspaceId,
          purchaseId: widget.detail.summary.id,
        )),
      )
      ..invalidate(purchasesProvider(widget.workspaceId));
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final linked = {
      for (final s in widget.detail.sources)
        if (s.kind == 'inbox') s.id,
    };
    final inbox = ref.watch(eInvoiceInboxProvider(widget.workspaceId));
    final offered = [
      for (final d in inbox.value ?? const <InboxDocument>[])
        if (d.status != InboxStatus.rejected && !linked.contains(d.id)) d,
    ];
    return AlertDialog(
      title: Text(l10n.purchaseLinkInboxTitle),
      content: SizedBox(
        width: 420,
        child: switch (inbox) {
          AsyncData() when offered.isEmpty => Text(
            l10n.purchaseLinkInboxEmpty,
            key: const ValueKey('purchase-link-inbox-empty'),
          ),
          AsyncData() => ListView(
            shrinkWrap: true,
            children: [
              for (final d in offered)
                ListTile(
                  key: ValueKey('purchase-link-inbox-${d.id}'),
                  enabled: !_busy,
                  title: Text(d.supplierName),
                  subtitle: Text('${d.number} · ${d.issueDate}'),
                  trailing: Text(
                    moneyFormat(d.currency).formatMinor(d.grossCents),
                  ),
                  onTap: () => _link(d),
                ),
            ],
          ),
          AsyncError() => Text(l10n.purchaseLinkInboxFailed),
          _ => const LinearProgressIndicator(),
        },
      ),
      actions: [
        TextButton(
          key: const ValueKey('purchase-link-inbox-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
    );
  }
}
