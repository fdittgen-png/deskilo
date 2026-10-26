// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2577 -- the software an external book is kept in, picked from the
// accounting targets offered in the space's country; "Other…" for one the
// catalogue does not know.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../domain/accounting_format.dart' show accountingTargets;

/// The list the book's external software is chosen from, with "Other…"
/// for a software the catalogue does not know; null means "Other…".
class BookSoftwareField extends StatelessWidget {
  const BookSoftwareField({
    required this.country,
    super.key,
    required this.value,
    required this.other,
    required this.onChanged,
  });

  final String country;
  final String value;
  final bool other;
  final ValueChanged<String?> onChanged;

  /// The dropdown's own value for "Other…".
  static const _otherChoice = '\u0000other';

  @override
  Widget build(BuildContext context) {
    final choices = _softwareChoices(country, value);
    final selected = other
        ? _otherChoice
        : choices.contains(value) ? value : null;
    return DropdownButtonFormField<String>(
      key: const ValueKey('book-external'),
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(labelText: context.l10n.bookExternalSystem),
      items: [
        for (final name in choices)
          DropdownMenuItem(value: name, child: Text(name)),
        DropdownMenuItem(
          key: const ValueKey('book-external-choice-other'),
          value: _otherChoice,
          child: Text(context.l10n.bookExternalOther),
        ),
      ],
      onChanged: (v) => onChanged(v == _otherChoice ? null : v),
    );
  }
}

/// The software a space can name as its book: every accounting software
/// the targets know in the space's country, by name (the app's own exports
/// and the authorities' file formats are no software), plus the one already
/// stored so an earlier choice never vanishes from the list.
List<String> _softwareChoices(String country, String stored) {
  final names = <String>{
    for (final t in accountingTargets)
      if (t.isSoftware && t.offeredIn(country)) '${t.vendor} ${t.product}'.trim(),
    if (stored.isNotEmpty) stored,
  };
  return names.toList()..sort();
}
