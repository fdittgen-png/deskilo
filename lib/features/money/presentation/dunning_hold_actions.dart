// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1913 — holding an invoice's reminders: the reasons the server knows,
// the dialog that asks for one, and the action that places or releases
// the hold. Its own file, so the invoice action list stays a list.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../application/dunning_hold.dart';
import '../domain/invoice.dart';
import '../providers/money_providers.dart';

/// #1913 — the reasons a reminder may be held, as the server knows them.
const _dunningHoldReasons = ['dispute', 'identity_error', 'insolvency', 'other'];

String dunningHoldReasonLabel(AppLocalizations l10n, String reason) =>
    switch (reason) {
      'dispute' => l10n.invoiceHoldReasonDispute,
      'identity_error' =>
        l10n.invoiceHoldReasonIdentity,
      'insolvency' =>
        l10n.invoiceHoldReasonInsolvency,
      _ => l10n.invoiceHoldReasonOther,
    };

/// #1913 — places a dunning hold with its reason, or releases the active
/// one. A held invoice is not reminded, by hand or by the daily sweep.
Future<void> toggleDunningHold(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final l10n = context.l10n;
  final held = ref.read(dunningHoldsProvider).value?[invoice.id];
  if (held != null) {
    if (!await runGuarded(
      context,
      domain: 'money',
      message: 'dunning hold release failed',
      errorText:
          l10n.invoiceHoldFailed,
      action: () => releaseDunningHold(ref, invoice.id),
    )) {
      return;
    }
    if (!context.mounted) return;
    AppSnack.success(
      context,
      l10n.invoiceHoldReleased,
    );
    return;
  }
  final chosen = await showDialog<({String reason, String note})>(
    context: context,
    builder: (context) => const _DunningHoldDialog(),
  );
  if (chosen == null || !context.mounted) return;
  if (!await runGuarded(
    context,
    domain: 'money',
    message: 'dunning hold failed',
    errorText:
        l10n.invoiceHoldFailed,
    action: () => placeDunningHold(
      ref,
      invoice.id,
      reason: chosen.reason,
      note: chosen.note,
    ),
  )) {
    return;
  }
  if (!context.mounted) return;
  AppSnack.success(
    context,
    l10n.invoiceHoldPlaced,
  );
}

class _DunningHoldDialog extends StatefulWidget {
  const _DunningHoldDialog();

  @override
  State<_DunningHoldDialog> createState() => _DunningHoldDialogState();
}

class _DunningHoldDialogState extends State<_DunningHoldDialog> {
  String _reason = _dunningHoldReasons.first;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.invoiceHoldTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.invoiceHoldExplain,
            ),
            RadioGroup<String>(
              key: const ValueKey('dunning-hold-actions-radio-group'),
              groupValue: _reason,
              onChanged: (value) => setState(() => _reason = value ?? _reason),
              child: Column(
                children: [
                  for (final reason in _dunningHoldReasons)
                    RadioListTile<String>(
                      key: ValueKey('dunning-hold-$reason'),
                      contentPadding: EdgeInsets.zero,
                      value: reason,
                      title: Text(dunningHoldReasonLabel(l10n, reason)),
                    ),
                ],
              ),
            ),
            TextField(
              key: const ValueKey('dunning-hold-note'),
              controller: _note,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: l10n.invoiceHoldNote,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('dunning-hold-actions-text-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('dunning-hold-confirm'),
          onPressed: () =>
              Navigator.of(context)
                  .pop((reason: _reason, note: _note.text.trim())),
          child: Text(l10n.invoiceHoldConfirm),
        ),
      ],
    );
  }
}
