// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4367 -- adding a till of the business, or renaming and switching one off. Whoever manages the sites does it.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/form_choice_controls.dart';
import '../../../../core/ui/form_kit.dart';
import '../../application/till_drawer_commands.dart';
import '../../domain/till_drawer.dart';
import '../../domain/till_drawer_rules.dart';
import 'drawer_inputs.dart';
import 'drawer_text.dart';

/// Opens the sheet for a new till (null [till]) or an existing one; true when it was saved.
Future<bool> showTillEditSheet(BuildContext context, TillDrawerCommands commands, {DrawerTill? till}) {
  final l10n = context.l10n;
  final fields = FormControllers({'name': till?.name ?? ''});
  final intent = SameIntent();
  var active = till?.active ?? true;
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
      ],
    ),
  );
}
