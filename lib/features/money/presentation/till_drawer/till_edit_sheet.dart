// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4367 -- adding a till of the business, or renaming and switching one off. Whoever manages the sites does it.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show cashValuesOf, tillCashValues;
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

/// Opens the sheet for a new till (null [till]) or an existing one; true when it was saved. #4511: an existing till of a
/// [currency] the reference lists picks the notes and coins its drawer carries.
Future<bool> showTillEditSheet(BuildContext context, TillDrawerCommands commands, {DrawerTill? till, String currency = ''}) {
  final l10n = context.l10n;
  final fields = FormControllers({'name': till?.name ?? ''});
  final intent = SameIntent();
  var active = till?.active ?? true;
  final all = cashValuesOf(currency);
  final before = till == null ? all : tillCashValues(currency, till.denominations);
  final carried = {...before};
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: till == null ? l10n.tillDrawerTillNewTitle : l10n.tillDrawerEditTill,
      submitLabel: l10n.tillDrawerTillSave,
      submitKey: const ValueKey('drawer-till-save'),
      onDispose: fields.dispose,
      validate: () => drawerFieldErrors(l10n, checkTillName(fields.text('name'))),
      onSubmit: () async {
        try {
          await commands.saveTill(
            requestId: intent.idFor('${fields.text('name')}|$active'),
            tillId: till?.id,
            name: fields.text('name'),
            siteId: till?.siteId,
            active: active,
          );
          if (till != null && all.isNotEmpty && !_same(carried, before)) {
            await commands.setTillDenominations(
              tillId: till.id,
              values: carried.length == all.length ? const [] : [for (final v in all) if (carried.contains(v)) v],
            );
          }
          return null;
        } on Object catch (e, st) {
      TraceLogger.instance.warn('money', 'the till drawer refused', error: e, stackTrace: st);
          return drawerProblemText(l10n, e);
        }
      },
      builder: (context, refresh) => [
        AppTextField(
          key: const ValueKey('drawer-till-name'),
          controller: fields['name'],
          fieldKey: 'name',
          label: l10n.tillDrawerTillName,
          maxLength: kTillNameMaxLength,
          autofocus: true,
        ),
        if (till != null)
          AppSwitchRow(
            key: const ValueKey('drawer-till-active'),
            title: l10n.tillDrawerTillActive,
            value: active,
            onChanged: (v) {
              active = v;
              refresh();
            },
          ),
        if (till != null && all.isNotEmpty) ..._carriedRows(context, currency, all, carried, refresh),
      ],
    ),
  );
}

bool _same(Set<int> a, List<int> b) => a.length == b.length && b.every(a.contains);

/// #4511 -- the notes and coins a till's drawer carries, one switch each; a drawer keeps at least one.
List<Widget> _carriedRows(BuildContext context, String currency, List<int> all, Set<int> carried, VoidCallback refresh) {
  final l10n = context.l10n;
  return [
    const FormGap(),
    Text(l10n.tillDrawerTillNotes, style: Theme.of(context).textTheme.titleSmall),
    Text(l10n.tillDrawerTillNotesHint, style: Theme.of(context).textTheme.bodySmall),
    for (final v in all)
      AppSwitchRow(
        key: ValueKey('drawer-till-note-$v'),
        title: appFormatOf(context).moneyIn(currency).formatMinor(v),
        value: carried.contains(v),
        onChanged: (on) {
          if (on) {
            carried.add(v);
          } else if (carried.length > 1) {
            carried.remove(v);
          }
          refresh();
        },
      ),
  ];
}
