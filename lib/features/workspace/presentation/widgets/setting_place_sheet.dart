// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4495 -- the setting that names a place is picked from the places of the business, shown as site › place; nothing is typed. What the
// setting says now is worded here too: the place, the place a code found (to settle by picking it), a code several places carry, a code
// or a pick that no usable place answers.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/settings/settings.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/dropdown_field.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/settings_commands.dart';
import '../../domain/setting_place.dart';
import '../settings_labels.dart';

/// What the setting holding [value] says, in words.
String placeSettingText(AppLocalizations l10n, String value, List<SettingPlace> places) {
  final r = placeOfSetting(value, places);
  return switch (r.state) {
    PlaceSettingState.picked => r.place!.path,
    PlaceSettingState.fromCode => l10n.settingPlaceFromCode(r.place!.path, r.code),
    PlaceSettingState.ambiguous => l10n.settingPlaceAmbiguous(r.code),
    PlaceSettingState.missing => r.code.isEmpty ? l10n.settingPlaceGone : l10n.settingPlaceMissing(r.code),
  };
}

/// Opens the picker of the setting [definition] of [workspaceId] over [places]; true when a place was saved.
Future<bool> showSettingPlaceSheet(
  BuildContext context,
  SettingsCommands commands, {
  required SettingDefinition definition,
  required String workspaceId,
  required List<SettingPlace> places,
  required String current,
}) {
  final l10n = context.l10n;
  var picked = placeOfSetting(current, places).state == PlaceSettingState.picked ? current.trim().toLowerCase() : null;
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: settingLabel(l10n, definition.key),
      submitLabel: l10n.commonSave,
      submitKey: const ValueKey('setting-place-save'),
      validate: () => {if (picked == null) 'place': l10n.settingPlacePick},
      onSubmit: () async {
        try {
          await commands.save(workspaceId: workspaceId, definition: definition, text: picked!);
          return null;
        } on Object catch (e, st) {
          TraceLogger.instance.error('settings', 'save ${definition.key} failed', error: e, stackTrace: st);
          return l10n.settingCouldNotSave;
        }
      },
      builder: (context, refresh) => [
        Text(placeSettingText(l10n, current, places), key: const ValueKey('setting-place-now')),
        const FormGap(),
        AppDropdownField<String?>(
          key: const ValueKey('setting-place'),
          label: l10n.settingPlacePick,
          value: picked,
          items: [for (final p in places) (p.id.toLowerCase(), p.path)],
          onChanged: (v) {
            picked = v;
            refresh();
          },
        ),
      ],
    ),
  );
}
