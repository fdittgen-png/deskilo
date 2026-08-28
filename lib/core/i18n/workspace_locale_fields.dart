// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../time/clock.dart';
import 'currencies.dart';
import 'money_format.dart';
import 'time_zone_picker.dart';
import 'time_zones.dart';

/// The workspace's currency and time zone, as PICKERS (#711).
///
/// Both were free-text fields: `EURO` reached invoices and
/// `Europe/Pairs` silently fell every booking window back to the device
/// clock. The currency list is what the app can format (each code with
/// its symbol and its own number of decimals); the zone search is over
/// the IANA database the clock installs from. The row refuses anything
/// else (0132), so these are the only way a valid value gets in.
///
/// Controllers stay with the caller, which owns the form and its save.
class WorkspaceLocaleFields extends ConsumerWidget {
  const WorkspaceLocaleFields({
    super.key,
    required this.currency,
    required this.timezone,
    required this.enabled,
    required this.onTimezonePicked,
  });

  final TextEditingController currency;
  final TextEditingController timezone;
  final bool enabled;
  final ValueChanged<String> onTimezonePicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Column(children: [
      // #711 — a PICKER, not a text field. The field
      // accepted `EURO` and shipped it to invoices; this
      // offers the codes the app can format, each with its
      // symbol, and the row refuses anything else (0132).
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: currency,
        // Re-keyed on the code, so a country pick that re-defaults the
        // controller shows up: a form field only reads initialValue once.
        builder: (context, value, _) => KeyedSubtree(
          key: ValueKey('workspace-currency-${value.text}'),
          child: DropdownButtonFormField<String>(
        key: const Key('workspaceSettingsCurrency'),
        initialValue: Currencies.selectable.contains(currency.text)
            ? currency.text
            : null,
        items: [
          for (final code in Currencies.selectable)
            DropdownMenuItem(
              value: code,
              child: Text(
                '$code · ${moneyFormat(code).currencySymbol}',
              ),
            ),
        ],
        onChanged: !enabled
            ? null
            : (code) {
                if (code != null) currency.text = code;
              },
        decoration: InputDecoration(
          labelText: l10n?.workspaceCurrencyLabel ?? 'Currency',
          helperText: l10n?.workspaceSettingsCurrencyHelper ??
              'Defaults from the country — override if your '
                  'community bills in another currency.',
        ),
        validator: (value) => value == null
            ? (l10n?.authFieldRequired ?? 'Required')
            : null,
      ),
        ),
      ),
      const SizedBox(height: 12),
      // #711 — searchable over the IANA database the clock
      // installs from. `Europe/Pairs` used to save fine and
      // silently fall every booking window back to the
      // device clock.
      TextFormField(
        key: const Key('workspaceSettingsTimezone'),
        controller: timezone,
        enabled: enabled,
        readOnly: true,
        onTap: () async {
          final picked = await showTimeZonePicker(
            context,
            current: timezone.text,
            now: ref.read(clockProvider).now(),
          );
          if (picked != null) onTimezonePicked(picked);
        },
        decoration: InputDecoration(
          labelText: l10n?.workspaceTimezoneLabel ?? 'Time zone',
          suffixIcon: const Icon(Icons.search),
        ),
        validator: (value) => TimeZones.isKnown(value?.trim() ?? '')
            ? null
            : (l10n?.workspaceTimezoneUnknown ??
                'Pick a time zone from the list'),
      ),
    ]);
  }
}
