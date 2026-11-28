// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4501 (MD-01) -- the control a setting's value is edited with, read from the setting's own metadata: a yes/no is a switch, an enum is
// a choice among the setting's choices, anything else is typed. A stored value that is none of the choices stays visible, flagged, until
// it is changed.
import 'package:flutter/material.dart';

import '../../../../core/settings/settings.dart';
import '../../../../core/ui/dropdown_field.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../settings_labels.dart';

/// The key of the value in the sheet's form controllers.
const _valueField = 'value';

/// The control that holds the value of [definition]; [refresh] redraws the sheet after a pick.
Widget settingValueField(AppLocalizations l10n, SettingDefinition definition, FormControllers fields, VoidCallback refresh) {
  final d = definition;
  final text = fields.text(_valueField);
  return switch (d.type) {
    SettingType.boolean => SwitchListTile(
      key: const ValueKey('setting-value'),
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.biPrintColValue),
      value: bool.tryParse(text.trim()) ?? false,
      onChanged: (on) {
        fields[_valueField].text = '$on';
        refresh();
      },
    ),
    SettingType.choice => AppDropdownField<String>(
      key: const ValueKey('setting-value'),
      label: l10n.biPrintColValue,
      value: text,
      error: d.choices.contains(text) ? null : l10n.masterDataUnlisted,
      items: [
        if (!d.choices.contains(text)) (text, text),
        for (final c in d.choices) (c, c),
      ],
      onChanged: (v) {
        fields[_valueField].text = v ?? '';
        refresh();
      },
    ),
    _ => AppTextField(
      key: const ValueKey('setting-value'),
      controller: fields[_valueField],
      fieldKey: _valueField,
      label: l10n.biPrintColValue,
      suffixText: settingUnitLabel(l10n, d.unit),
      keyboardType: TextInputType.text,
      maxLength: d.type == SettingType.text ? d.max?.toInt() : null,
      helper: settingRangeLabel(l10n, d),
    ),
  };
}
