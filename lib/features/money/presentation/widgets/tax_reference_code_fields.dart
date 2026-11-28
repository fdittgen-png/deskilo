// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4501 (MD-03) -- the tax reference sheet's text fields: a country, a currency and a time zone are picked from their
// lists (the country and currency lookups of the form kit, the IANA zone picker), never typed; every other field (a
// rate, a source, a legal wording) stays a text field. `every country` (taxReferenceAnyCountry) stays as it is stored.
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart' show taxReferenceAnyCountry;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/time_zone_picker.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/country_field.dart';
import '../../../../core/ui/currency_field.dart';
import '../../../../core/ui/form_kit.dart';

/// What a field of the sheet holds: a code picked from its list, or text.
enum _Holds { country, currency, timeZone, text }

/// The fields that hold a code.
const _codeFields = {
  'country': _Holds.country,
  'alias_of': _Holds.country,
  'currency': _Holds.currency,
  'time_zone': _Holds.timeZone,
};

/// The field [k] of the sheet, held by [controller].
Widget taxReferenceField(
  TextEditingController controller,
  String k,
  String label, {
  bool enabled = true,
  TextInputType? type,
}) => Padding(
  padding: const EdgeInsets.only(bottom: AppSpacing.md),
  child: switch (_codeFields[k] ?? _Holds.text) {
    _Holds.country when controller.text.trim() != taxReferenceAnyCountry => CountryField(
      key: ValueKey('tax-ref-$k'),
      controller: controller,
      fieldKey: k,
      label: label,
      enabled: enabled,
    ),
    _Holds.currency => CurrencyField(
      key: ValueKey('tax-ref-$k'),
      controller: controller,
      fieldKey: k,
      label: label,
      enabled: enabled,
    ),
    _Holds.timeZone => _TimeZoneField(controller: controller, label: label, enabled: enabled),
    _Holds.country || _Holds.text => AppTextField(
      key: ValueKey('tax-ref-$k'),
      controller: controller,
      fieldKey: k,
      label: label,
      enabled: enabled,
      keyboardType: type,
    ),
  },
);

/// A time zone, picked from the zones the clock knows (search by city or zone id).
class _TimeZoneField extends ConsumerWidget {
  const _TimeZoneField({required this.controller, required this.label, required this.enabled});

  final TextEditingController controller;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ValueListenableBuilder(
    valueListenable: controller,
    builder: (context, value, _) => InkWell(
      key: const ValueKey('tax-ref-time_zone'),
      onTap: !enabled
          ? null
          : () async {
              final picked = await showTimeZonePicker(context, current: value.text, now: ref.read(clockProvider).now());
              if (picked != null) controller.text = picked;
            },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.search), enabled: enabled),
        child: Text(value.text),
      ),
    ),
  );
}
