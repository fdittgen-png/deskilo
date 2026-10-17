// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/cents.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/invoice.dart';
import '../../domain/purchase.dart';
import '../../providers/money_providers.dart';
import '../../providers/purchase_providers.dart';

/// An open invoice of the claimant and what it still owes.
typedef OpenInvoice = ({Invoice invoice, int dueCents});

/// The claimant's invoices that can still take a settlement: issued, not
/// voided, positive, unmatched or with a standing partial.
List<OpenInvoice> openInvoicesOf(
  String memberId,
  List<Invoice> invoices,
  Map<String, InvoiceMatch> matches,
) {
  final open = <OpenInvoice>[];
  for (final i in invoices) {
    if (i.memberId != memberId || i.isVoided || i.totalCents <= 0) continue;
    final m = matches[i.id];
    if (m != null &&
        (m.status != 'confirmed' ||
            m.resolution != 'under_accepted' ||
            m.writeoffAt != null)) {
      continue;
    }
    open.add((invoice: i, dueCents: i.totalCents - (m?.paidCents ?? 0)));
  }
  return open..sort((a, b) => a.invoice.issuedAt.compareTo(b.invoice.issuedAt));
}

/// Settles an invoice of the claimant from [claim]. True once the server has
/// it; a refusal keeps the dialog, and a retry of the same entries reuses the
/// request id.
Future<bool?> showOffsetDialog(
  BuildContext context,
  String workspaceId,
  PurchaseObligation claim,
) => showDialog<bool>(
  context: context,
  builder: (_) => _OffsetDialog(workspaceId: workspaceId, claim: claim),
);

class _OffsetDialog extends ConsumerStatefulWidget {
  const _OffsetDialog({required this.workspaceId, required this.claim});

  final String workspaceId;
  final PurchaseObligation claim;

  @override
  ConsumerState<_OffsetDialog> createState() => _OffsetDialogState();
}

class _OffsetDialogState extends ConsumerState<_OffsetDialog> {
  final _amount = TextEditingController();
  String? _invoiceId;
  var _invalid = false;
  (String, int)? _attempted;
  var _requestId = newRequestId();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _pick(OpenInvoice open) {
    final cents = open.dueCents < widget.claim.remainingCents
        ? open.dueCents
        : widget.claim.remainingCents;
    setState(() {
      _invoiceId = open.invoice.id;
      _amount.text = centsToMajor(cents);
    });
  }

  Future<void> _save(List<OpenInvoice> open) async {
    final id = _invoiceId;
    final cents = parseCentsInput(_amount.text);
    final due = open.where((o) => o.invoice.id == id).firstOrNull?.dueCents;
    if (id == null || due == null || cents == null || cents <= 0) {
      setState(() => _invalid = true);
      return;
    }
    setState(() => _invalid = false);
    if (_attempted != (id, cents)) _requestId = newRequestId();
    _attempted = (id, cents);
    final requestId = _requestId;
    final navigator = Navigator.of(context);
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'claim offset failed',
      errorText: context.l10n.purchasesOffsetRefused,
      action: () async {
        final done = await ref
            .read(purchaseCommandProvider)
            .offset(
              widget.workspaceId,
              widget.claim,
              invoiceId: id,
              invoiceDueCents: due,
              amountCents: cents,
              requestId: requestId,
            );
        if (done == null) throw StateError('offset not sent');
      },
    );
    if (ok && mounted) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final money = moneyFormat(widget.claim.currency);
    final invoices = ref.watch(invoicesProvider).value ?? const <Invoice>[];
    final matches =
        ref.watch(invoiceMatchesProvider).value ??
        const <String, InvoiceMatch>{};
    final open = openInvoicesOf(widget.claim.creditorId, invoices, matches);
    return AlertDialog(
      title: Text(l10n.purchasesOffsetTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.purchasesOffsetHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (open.isEmpty)
              Text(l10n.purchasesOffsetNone, key: const ValueKey('offset-none'))
            else ...[
              DropdownButtonFormField<String>(
                key: const ValueKey('offset-invoice'),
                initialValue: _invoiceId,
                decoration: InputDecoration(
                  labelText: l10n.purchasesOffsetInvoice,
                ),
                items: [
                  for (final o in open)
                    DropdownMenuItem(
                      value: o.invoice.id,
                      child: Text(
                        '${o.invoice.number} · '
                        '${money.formatMinor(o.dueCents)}',
                      ),
                    ),
                ],
                onChanged: (v) {
                  final picked = open.where((o) => o.invoice.id == v);
                  if (picked.isNotEmpty) _pick(picked.first);
                },
              ),
              AppTextField(
                key: const ValueKey('offset-amount'),
                controller: _amount,
                label: l10n.purchasesPayAmount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ],
            if (_invalid)
              Text(
                l10n.purchasesPayInvalid(
                  money.formatMinor(widget.claim.remainingCents),
                ),
                key: const ValueKey('offset-invalid'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('offset-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('offset-save'),
          onPressed: open.isEmpty ? null : () => _save(open),
          child: Text(l10n.purchasesOffsetAction),
        ),
      ],
    );
  }
}
