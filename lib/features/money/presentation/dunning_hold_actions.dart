// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1913 — holding an invoice's reminders: the reasons the server knows,
// the dialog that asks for one, and the action that places or releases
// the hold. Its own file, so the invoice action list stays a list.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/invoice.dart';
import '../providers/money_providers.dart';
import '../application/dunning_hold.dart';

/// #1913 — the reasons a reminder may be held, as the server knows them.
const dunningHoldReasons = ['dispute', 'identity_error', 'insolvency', 'other'];

String dunningHoldReasonLabel(AppLocalizations? l10n, String reason) =>
    switch (reason) {
      'dispute' => l10n?.invoiceHoldReasonDispute ?? 'The member disputes it',
      'identity_error' =>
        l10n?.invoiceHoldReasonIdentity ?? 'Wrong person or identity error',
      'insolvency' =>
        l10n?.invoiceHoldReasonInsolvency ?? 'Insolvency proceedings',
      _ => l10n?.invoiceHoldReasonOther ?? 'Another reason',
    };

/// #1913 — places a dunning hold with its reason, or releases the active
/// one. A held invoice is not reminded, by hand or by the daily sweep.
Future<void> toggleDunningHold(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final l10n = AppLocalizations.of(context);
  final held = ref.read(dunningHoldsProvider).value?[invoice.id];
  if (held != null) {
    if (!await runGuarded(
      context,
      domain: 'money',
      message: 'dunning hold release failed',
      errorText:
          l10n?.invoiceHoldFailed ??
          'The reminder hold could not be changed. Please try again.',
      action: () => releaseDunningHold(ref, invoice.id),
    )) {
      return;
    }
    if (!context.mounted) return;
    AppSnack.success(
      context,
      l10n?.invoiceHoldReleased ?? 'Reminders can resume for this invoice.',
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
        l10n?.invoiceHoldFailed ??
        'The reminder hold could not be changed. Please try again.',
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
    l10n?.invoiceHoldPlaced ?? 'Reminders are on hold for this invoice.',
  );
}

class _DunningHoldDialog extends StatefulWidget {
  const _DunningHoldDialog();

  @override
  State<_DunningHoldDialog> createState() => _DunningHoldDialogState();
}

class _DunningHoldDialogState extends State<_DunningHoldDialog> {
  String _reason = dunningHoldReasons.first;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n?.invoiceHoldTitle ?? 'Why hold the reminders?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.invoiceHoldExplain ??
                  'No reminder is sent for this invoice, by hand or '
                      'automatically, until the hold is released.',
            ),
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (value) => setState(() => _reason = value ?? _reason),
              child: Column(
                children: [
                  for (final reason in dunningHoldReasons)
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
                labelText: l10n?.invoiceHoldNote ?? 'Note (optional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('dunning-hold-confirm'),
          onPressed: () =>
              Navigator.of(context)
                  .pop((reason: _reason, note: _note.text.trim())),
          child: Text(l10n?.invoiceHoldConfirm ?? 'Hold'),
        ),
      ],
    );
  }
}
