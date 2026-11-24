// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3649 -- the region of an address, as its country asks for it: nothing where
// the country's addresses have none, a list where it has codes, free text
// otherwise. The stored value is always the code.
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:flutter/material.dart';

import '../../core/text/collation.dart';
import '../../l10n/app_localizations.dart';
import '../jurisdiction/installed_postal_layouts.dart';
import '../l10n/context_l10n.dart';
import '../theme/app_spacing.dart';
import 'form_kit.dart';

/// The region field of an address in [country].
class AddressRegionField extends StatefulWidget {
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
  State<AddressRegionField> createState() => _AddressRegionFieldState();
}

class _AddressRegionFieldState extends State<AddressRegionField> {
  /// The free code, where the country has no list of its own.
  late final _text = TextEditingController(text: widget.value);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final field = postalLayoutOf(widget.country).region;
    if (field == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final label = _regionLabel(l10n, field.kind);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: field.names.isEmpty
          ? AppTextField(
              key: ValueKey(widget.fieldKey),
              controller: _text,
              label: label,
              error: widget.error,
              enabled: widget.enabled,
              maxLength: 10,
              onChanged: (v) => widget.onChanged(regionCode(v)),
            )
          : DropdownButtonFormField<String>(
              key: ValueKey(widget.fieldKey),
              initialValue: field.names.containsKey(widget.value)
                  ? widget.value
                  : '',
              isExpanded: true,
              decoration: InputDecoration(
                labelText: label,
                errorText: widget.error,
                border: const OutlineInputBorder(),
              ),
              items: _items(field),
              onChanged: widget.enabled
                  ? (v) => widget.onChanged(v ?? '')
                  : null,
            ),
    );
  }

  /// The country's regions by name, after an empty choice.
  static List<DropdownMenuItem<String>> _items(RegionField field) {
    final byName = field.names.entries.toList()
      ..sort((a, b) => compareNames(a.value, b.value));
    return [
      const DropdownMenuItem(value: '', child: Text('')),
      for (final e in byName)
        DropdownMenuItem(value: e.key, child: Text(e.value)),
    ];
  }
}

/// What the country calls the region of an address, in the reader's language.
String _regionLabel(AppLocalizations l10n, RegionKind kind) => switch (kind) {
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
