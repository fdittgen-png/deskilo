// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4367 -- opening a till: the float the drawer starts with, typed as a total or, when the business counts by
// denomination, row by row. The server refuses a till that is already open or a count that does not add up.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/till_drawer.dart';
import '../../domain/till_drawer_rules.dart';
import '../../providers/till_drawer_providers.dart';
import 'drawer_inputs.dart';
import 'drawer_text.dart';

/// Opens the sheet for [till]; true when the session was opened.
Future<bool> showOpenTillSheet(
  BuildContext context,
  WidgetRef ref, {
  required String workspaceId,
  required DrawerTill till,
  required String currency,
  required bool byDenomination,
}) {
  final l10n = context.l10n;
  final format = appFormatOf(context);
  final fields = FormControllers();
  final rows = DenominationRows();
  final intent = SameIntent();
  int? typed() => format.readAmount(fields.text('amount'), currency: currency, allowNegative: false).minor;
  Denominations? counted() => byDenomination ? rows.read(context) : null;
  int? floatMinor() => byDenomination ? counted()?.totalMinor : typed();
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.tillDrawerOpenTitle(till.name),
      submitLabel: l10n.tillDrawerOpenAction,
      submitKey: const ValueKey('drawer-open-submit'),
      onDispose: () {
        fields.dispose();
        rows.dispose();
      },
      validate: () => drawerFieldErrors(
        l10n,
        checkFloat(amountMinor: floatMinor(), byDenomination: byDenomination, denominations: counted()),
      ),
      onSubmit: () async {
        final float = floatMinor()!;
        final denominations = counted();
        try {
          await ref.read(tillDrawerPortProvider).openSession(
            workspaceId,
            requestId: intent.idFor('${till.id}|$float|${denominations?.toJson()}'),
            tillId: till.id,
            floatMinor: float,
            denominations: denominations,
          );
          ref.invalidate(tillDrawerProvider(workspaceId));
          return null;
        } on Object catch (e) {
          return drawerProblemText(l10n, e);
        }
      },
      builder: (context, refresh) => [
        if (byDenomination)
          DenominationFields(rows: rows, currency: currency)
        else
          AppAmountField(
            key: const ValueKey('drawer-float'),
            controller: fields['amount'],
            fieldKey: 'amount',
            label: l10n.tillDrawerFloat,
            helper: l10n.tillDrawerFloatHelp,
            currency: currency,
            allowNegative: false,
            autofocus: true,
          ),
      ],
    ),
  );
}
