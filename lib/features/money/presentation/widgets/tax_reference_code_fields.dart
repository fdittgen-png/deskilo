// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4501 (MD-03) -- the tax reference sheet's text fields: a country, a currency and a time zone are picked from their
// lists (the country and currency lookups of the form kit, the IANA zone picker), never typed; every other field (a
// rate, a source, a legal wording) stays a text field. `every country` (*) stays as it is stored.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/time_zone_picker.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/country_field.dart';
import '../../../../core/ui/currency_field.dart';
import '../../../../core/ui/form_kit.dart';

/// The fields that hold a country code.
const _countryFields = {'country', 'alias_of'};

/// The field [k] of the sheet, held by [controller].
Widget taxReferenceField(
  TextEditingController controller,
  String k,
  String label, {
  bool enabled = true,
  TextInputType? type,
}) => Padding(
  padding: const EdgeInsets.only(bottom: AppSpacing.md),
  child: switch (k) {
    _ when _countryFields.contains(k) && controller.text.trim() != '*' => CountryField(
      key: ValueKey('tax-ref-$k'),
      controller: controller,
      fieldKey: k,
      label: label,
      enabled: enabled,
    ),
    'currency' => CurrencyField(
      key: ValueKey('tax-ref-$k'),
      controller: controller,
      fieldKey: k,
      label: label,
      enabled: enabled,
    ),
    'time_zone' => _TimeZoneField(controller: controller, label: label, enabled: enabled),
    _ => AppTextField(
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
  Widget build(BuildContext context, WidgetRef ref) => TextField(
    key: const ValueKey('tax-ref-time_zone'),
    controller: controller,
    readOnly: true, // field-locked: the zone is picked from the list, never typed
    enabled: enabled,
    onTap: () async {
      final picked = await showTimeZonePicker(context, current: controller.text, now: ref.read(clockProvider).now());
      if (picked != null) controller.text = picked;
    },
    decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.search)),
  );
}
