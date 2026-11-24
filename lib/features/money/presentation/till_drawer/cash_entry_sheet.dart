// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4367 -- cash paid into or out of the drawer during a session, with a reason from the business's own list. A paid-out
// above the business's limit is the server's to refuse for someone who may not record outgoing payments.
import 'package:flutter/material.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/form_choice_controls.dart';
import '../../../../core/ui/form_kit.dart';
import '../../application/till_drawer_commands.dart';
import '../../domain/till_drawer.dart';
import '../../domain/till_drawer_rules.dart';
import 'drawer_inputs.dart';
import 'drawer_text.dart';

/// Opens the sheet over [session]; true when the entry was recorded.
Future<bool> showCashEntrySheet(
  BuildContext context,
  TillDrawerCommands commands, {
  required DrawerSession session,
  required String currency,
  required DrawerSettings settings,
}) {
  final l10n = context.l10n;
  final format = appFormatOf(context);
  final fields = FormControllers();
  final intent = SameIntent();
  var kind = 'paid_out';
  String? reason;
  int? amount() => format.readAmount(fields.text('amount'), currency: currency, allowNegative: false).minor;
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.tillDrawerEntryTitle,
      submitLabel: l10n.tillDrawerEntrySubmit,
      submitKey: const ValueKey('drawer-entry-submit'),
      onDispose: fields.dispose,
      validate: () => drawerFieldErrors(l10n, checkCashEntry(amountMinor: amount(), reason: reason)),
      onSubmit: () async {
        try {
          await commands.cashEntry(
            requestId: intent.idFor('${session.id}|$kind|${amount()}|$reason'),
            sessionId: session.id,
            entry: DrawerEntry(kind: kind, amountMinor: amount()!, reason: reason!),
          );
          return null;
        } on Object catch (e, st) {
      TraceLogger.instance.warn('money', 'the till drawer refused', error: e, stackTrace: st);
          return drawerProblemText(l10n, e);
        }
      },
      builder: (context, refresh) {
        return [
          AppChoiceChips<String>(
            choices: [
              for (final k in const ['paid_in', 'paid_out'])
                AppChoice(
                  value: k,
                  key: ValueKey('drawer-entry-$k'),
                  label: k == 'paid_in' ? l10n.tillDrawerEntryPaidIn : l10n.tillDrawerEntryPaidOut,
                ),
            ],
            selected: kind,
            onSelected: (k) {
              kind = k;
              refresh();
            },
          ),
          const FormGap(),
          AppAmountField(
            key: const ValueKey('drawer-entry-amount'),
            controller: fields['amount'],
            fieldKey: 'amount',
            label: l10n.tillDrawerEntryAmount,
            currency: currency,
            allowNegative: false,
            autofocus: true,
            helper: kind == 'paid_out' && settings.paidOutLimitMinor > 0
                ? l10n.tillDrawerEntryLimit(format.moneyIn(currency).formatMinor(settings.paidOutLimitMinor))
                : null,
          ),
          const FormGap(),
          Text(l10n.tillDrawerEntryReason, style: Theme.of(context).textTheme.titleSmall),
          const FormGap.small(),
          AppChoiceChips<String>(
            choices: [for (final r in settings.reasons) AppChoice(value: r, key: ValueKey('drawer-entry-reason-$r'), label: r)],
            selected: reason,
            onSelected: (r) {
              reason = r;
              refresh();
            },
          ),
          // read under the sheet's own scope: the builder's context sits above it
          Builder(
            builder: (c) {
              final reasonError = FormErrorsScope.maybeOf(c)?.errors['reason'];
              return reasonError == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(reasonError, key: const ValueKey('drawer-entry-reason-error'), style: TextStyle(color: Theme.of(c).colorScheme.error)),
                    );
            },
          ),
        ];
      },
    ),
  );
}
