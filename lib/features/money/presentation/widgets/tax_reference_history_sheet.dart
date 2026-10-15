// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2477 -- every version of one value, newest first. #2565 -- the platform
// owner confirms a planned version (the law passed) or withdraws it (it
// does not come into force); a version in force is history and offers
// neither.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../core/vat/tax_reference.dart';
import '../../application/tax_reference_commands.dart';
import 'tax_reference_labels.dart';

/// Opens the history of [row]'s value. With [commands] (the owner), an
/// unconfirmed version offers Confirm and an unconfirmed version that starts
/// after [today] offers Withdraw; [onDone] runs after either succeeded.
Future<void> showTaxReferenceHistorySheet(
  BuildContext context, {
  required TaxReferenceSet set,
  required TaxReferenceRow row,
  TaxReferenceCommands? commands,
  String today = '',
  VoidCallback? onDone,
}) {
  final versions = set.history(row.domain, row.country, row.key);
  return showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final l10n = context.l10n;

      Future<void> act(Future<void> Function() change) async {
        final navigator = Navigator.of(context);
        final messenger = ScaffoldMessenger.of(context);
        try {
          await change();
        } on Object catch (e, st) {
          TraceLogger.instance.error(
            'money',
            'tax reference change failed',
            error: e,
            stackTrace: st,
          );
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.taxRefActionFailed)),
          );
          return;
        }
        navigator.pop();
        onDone?.call();
      }

      Future<void> withdraw(TaxReferenceRow v) async {
        final text = await showDialog<String>(
          context: context,
          builder: (_) => const _WithdrawDialog(),
        );
        if (text == null || text.isEmpty) return;
        await act(() => commands!.withdrawVersion(v.id, text));
      }

      return SheetShell(
        title: l10n.taxRefHistory,
        children: [
          Text(
            '${row.country} · ${row.key}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final v in versions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                taxValueSummary(v.value).isEmpty
                    ? v.country
                    : taxValueSummary(v.value),
              ),
              subtitle: Text(
                '${l10n.taxRefValidFrom} ${v.validFrom}'
                '${v.validTo == null ? '' : ' · ${l10n.taxRefValidUntil} ${v.validTo}'}'
                ' · ${v.source}',
              ),
              trailing: commands == null || v.confirmed
                  ? Text(
                      v.confirmed
                          ? l10n.taxRefConfirmed
                          : l10n.taxRefUnconfirmed,
                    )
                  : Wrap(
                      spacing: 4,
                      children: [
                        TextButton(
                          key: ValueKey('tax-ref-confirm-${v.id}'),
                          onPressed: () =>
                              act(() => commands.confirmVersion(v.id)),
                          child: Text(l10n.taxRefConfirm),
                        ),
                        if (v.validFrom.compareTo(today) > 0)
                          TextButton(
                            key: ValueKey('tax-ref-withdraw-${v.id}'),
                            onPressed: () => withdraw(v),
                            child: Text(l10n.taxRefWithdraw),
                          ),
                      ],
                    ),
            ),
        ],
      );
    },
  );
}

/// Asks why a planned version is withdrawn; owns its field.
class _WithdrawDialog extends StatefulWidget {
  const _WithdrawDialog();

  @override
  State<_WithdrawDialog> createState() => _WithdrawDialogState();
}

class _WithdrawDialogState extends State<_WithdrawDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.taxRefWithdraw),
      content: AppTextField(
        key: const ValueKey('tax-ref-withdraw-reason'),
        controller: _reason,
        label: l10n.taxRefWithdrawReason,
      ),
      actions: [
        TextButton(
          key: const ValueKey('tax-ref-withdraw-cancel'),
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        TextButton(
          key: const ValueKey('tax-ref-withdraw-submit'),
          onPressed: () => Navigator.pop(context, _reason.text.trim()),
          child: Text(l10n.taxRefWithdraw),
        ),
      ],
    );
  }
}
