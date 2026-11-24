// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4367 -- counting the drawer and closing the session. The person counts what is in the drawer, as a total or by
// denomination; when the business counts blind the expected cash is not given until the count is made, so the difference
// and its reason are asked for when the server says the count differs. Someone who may see the finances sees the expected
// cash and the difference as they type. The figures of the close are shown after it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/till_drawer.dart';
import '../../domain/till_drawer_rules.dart';
import '../../providers/till_drawer_providers.dart';
import 'drawer_inputs.dart';
import 'drawer_text.dart';

/// Opens the sheet over [session]; the figures of the close, or null when it was not closed. [expected] is what the
/// server gave for the session, null while the count is blind.
Future<DrawerClosed?> showCloseTillSheet(
  BuildContext context,
  WidgetRef ref, {
  required String workspaceId,
  required DrawerSession session,
  required String tillName,
  required String currency,
  required bool byDenomination,
  required DrawerCash? expected,
}) async {
  final l10n = context.l10n;
  final format = appFormatOf(context);
  final money = format.moneyIn(currency);
  final fields = FormControllers();
  final rows = DenominationRows();
  final intent = SameIntent();
  DrawerClosed? closed;
  var askReason = false;
  VoidCallback refreshSheet = () {};
  int? read(String key) => format.readAmount(fields.text(key), currency: currency, allowNegative: false).minor;
  Denominations? counted() => byDenomination ? rows.read(context) : null;
  int? countedMinor() => byDenomination ? counted()?.totalMinor : read('counted');
  int? bankedMinor() => fields.text('banked').isEmpty ? null : read('banked');
  int? known() => expected?.expectedMinor;
  bool differs() {
    final c = countedMinor();
    final e = known();
    return c != null && e != null && c != e;
  }

  final done = await showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.tillDrawerCloseTitle(tillName),
      submitLabel: l10n.tillDrawerCloseSubmit,
      submitKey: const ValueKey('drawer-close-submit'),
      onDispose: () {
        fields.dispose();
        rows.dispose();
      },
      validate: () => drawerFieldErrors(
        l10n,
        checkClose(
          countedMinor: countedMinor(),
          bankedMinor: fields.text('banked').isEmpty ? 0 : bankedMinor() ?? -1,
          byDenomination: byDenomination,
          denominations: counted(),
          expectedMinor: known(),
          differenceReason: fields.text('reason'),
        ),
      ),
      onSubmit: () async {
        final count = countedMinor()!;
        final reason = fields.text('reason');
        final denominations = counted();
        try {
          closed = await ref.read(tillDrawerPortProvider).closeSession(
            workspaceId,
            requestId: intent.idFor('${session.id}|$count|${denominations?.toJson()}|$reason|${bankedMinor()}'),
            sessionId: session.id,
            countedMinor: count,
            denominations: denominations,
            differenceReason: reason.isEmpty ? null : reason,
            bankedMinor: bankedMinor() ?? 0,
          );
          ref
            ..invalidate(drawerExpectedProvider)
            ..invalidate(tillDrawerProvider(workspaceId));
          return null;
        } on Object catch (e, st) {
      TraceLogger.instance.warn('money', 'the till drawer refused', error: e, stackTrace: st);
          if (drawerAsksDifferenceReason(e)) {
            askReason = true;
            refreshSheet();
          }
          return drawerProblemText(l10n, e);
        }
      },
      builder: (context, refresh) {
        refreshSheet = refresh;
        final counted = countedMinor();
        final difference = counted != null && known() != null ? counted - known()! : null;
        return [
          if (expected != null) ...[
            Text(l10n.tillDrawerExpected(money.formatMinor(expected.expectedMinor)), key: const ValueKey('drawer-close-expected'), style: Theme.of(context).textTheme.titleMedium),
            Text(
              l10n.tillDrawerBreakdown(
                money.formatMinor(expected.floatMinor),
                money.formatMinor(expected.cashSalesMinor - expected.cashRefundsMinor),
                money.formatMinor(expected.paidInMinor),
                money.formatMinor(expected.paidOutMinor),
              ),
              key: const ValueKey('drawer-close-breakdown'),
            ),
            const FormGap(),
          ],
          if (byDenomination)
            DenominationFields(rows: rows, currency: currency)
          else
            AppAmountField(
              key: const ValueKey('drawer-counted'),
              controller: fields['counted'],
              fieldKey: 'amount',
              label: l10n.tillDrawerCounted,
              helper: expected == null ? l10n.tillDrawerCountedHelpBlind : l10n.tillDrawerCountedHelp,
              currency: currency,
              allowNegative: false,
              autofocus: true,
              onChanged: (_) => refresh(),
            ),
          if (difference != null) ...[
            const FormGap.small(),
            Text(l10n.tillDrawerDifferenceLive(money.formatMinor(difference)), key: const ValueKey('drawer-close-difference')),
          ],
          if (askReason || differs()) ...[
            const FormGap(),
            AppTextField(
              key: const ValueKey('drawer-close-reason'),
              controller: fields['reason'],
              fieldKey: 'differenceReason',
              label: l10n.tillDrawerDifferenceReason,
              helper: askReason ? l10n.tillDrawerDifferenceAsked : null,
              maxLength: kDrawerReasonMaxLength,
            ),
          ],
          const FormGap(),
          AppAmountField(
            key: const ValueKey('drawer-banked'),
            controller: fields['banked'],
            fieldKey: 'banked',
            label: l10n.tillDrawerBanked,
            helper: l10n.tillDrawerBankedHelp,
            currency: currency,
            allowNegative: false,
          ),
        ];
      },
    ),
  );
  return done ? closed : null;
}

/// The figures of a close, said after it: what the drawer should have held, what was counted and the difference.
Future<void> showDrawerClosedDialog(BuildContext context, DrawerClosed closed, {required String currency}) {
  final l10n = context.l10n;
  final money = appFormatOf(context).moneyIn(currency);
  final difference = closed.differenceMinor;
  return showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      scrollable: true,
      title: Text(l10n.tillDrawerClosedTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.tillDrawerClosedCounts(money.formatMinor(closed.expectedMinor), money.formatMinor(closed.countedMinor)), key: const ValueKey('drawer-closed-counts')),
          Text(
            difference == 0
                ? l10n.tillDrawerClosedSame
                : difference < 0
                ? l10n.tillDrawerClosedShort(money.formatMinor(-difference))
                : l10n.tillDrawerClosedOver(money.formatMinor(difference)),
            key: const ValueKey('drawer-closed-difference'),
          ),
          if (closed.bankedMinor > 0) Text(l10n.tillDrawerClosedBanked(money.formatMinor(closed.bankedMinor))),
          if (closed.unresolvedCardMinor > 0) Text(l10n.tillDrawerClosedCard(money.formatMinor(closed.unresolvedCardMinor))),
        ],
      ),
      actions: [TextButton(key: const ValueKey('drawer-closed-ok'), onPressed: () => Navigator.of(c).pop(), child: Text(MaterialLocalizations.of(c).okButtonLabel))],
    ),
  );
}
