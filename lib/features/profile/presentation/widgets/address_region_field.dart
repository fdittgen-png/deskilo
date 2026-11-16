// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3649 -- the region of an address, as its country asks for it: nothing where
// the country's addresses have none, a list where it has codes, free text
// otherwise. The stored value is always the code.
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:flutter/material.dart';

import '../../../../core/jurisdiction/installed_postal_layouts.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';

/// The region field of an address in [country].
class AddressRegionField extends StatelessWidget {
  const AddressRegionField({
    super.key,
    required this.fieldKey,
    required this.country,
    required this.value,
    required this.onChanged,
    this.error,
    this.enabled = true,
  });

  final String fieldKey;

  /// The address's country (ISO 3166-1 alpha-2).
  final String country;

  /// The region's code, or '' for none.
  final String value;
  final ValueChanged<String> onChanged;
  final String? error;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final field = postalLayoutOf(country).region;
    if (field == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final decoration = InputDecoration(
      labelText: regionLabel(l10n, field.kind),
      errorText: error,
      border: const OutlineInputBorder(),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: field.names.isEmpty
          ? TextFormField(
              key: ValueKey(fieldKey),
              initialValue: value,
              enabled: enabled,
              maxLength: 10,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              decoration: decoration,
              onChanged: (v) => onChanged(regionCode(v)),
            )
          : DropdownButtonFormField<String>(
              key: ValueKey(fieldKey),
              initialValue: field.names.containsKey(value) ? value : '',
              isExpanded: true,
              decoration: decoration,
              items: _items(field),
              onChanged: enabled ? (v) => onChanged(v ?? '') : null,
            ),
    );
  }

  /// The country's regions by name, after an empty choice.
  static List<DropdownMenuItem<String>> _items(RegionField field) {
    final byName = field.names.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return [
      const DropdownMenuItem(value: '', child: Text('')),
      for (final e in byName)
        DropdownMenuItem(value: e.key, child: Text(e.value)),
    ];
  }
}

/// What the country calls the region of an address, in the reader's language.
String regionLabel(AppLocalizations l10n, RegionKind kind) => switch (kind) {
  RegionKind.state => l10n.addressRegionState,
  RegionKind.province => l10n.addressRegionProvince,
  RegionKind.county => l10n.addressRegionCounty,
  RegionKind.canton => l10n.addressRegionCanton,
  RegionKind.region => l10n.addressRegionRegion,
};

/// Why a region cannot be stored, in the reader's language.
String regionRefusalText(AppLocalizations l10n, RegionRefusal refusal) =>
    switch (refusal) {
      RegionRefusal.missing => l10n.addressRegionMissing,
      RegionRefusal.notACode => l10n.addressRegionNotACode,
      RegionRefusal.unknown => l10n.addressRegionUnknown,
    };
