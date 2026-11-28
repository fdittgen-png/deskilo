// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4501 (FIN-09) -- the scheme of an e-invoicing address, picked by name from the invoice model's EAS schemes: the
// space's own address and a customer's show the same choice. A stored scheme no longer offered is shown as it is,
// as its own choice, until another is picked.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../l10n/context_l10n.dart';
import 'dropdown_field.dart';

/// The scheme stored as [value]; [onChanged] receives the picked code.
class EInvoiceSchemeField extends StatelessWidget {
  const EInvoiceSchemeField({required this.value, required this.onChanged, super.key});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final stored = value.trim().toUpperCase();
    final known = easSchemeOf(stored) != null;
    return AppDropdownField<String>(
      label: context.l10n.eInvoiceEndpointSchemeField,
      value: stored.isEmpty ? null : stored,
      items: [
        for (final s in easSchemes) (s.code, easSchemeLabel(s)),
        if (!known && stored.isNotEmpty) (stored, stored),
      ],
      onChanged: (code) {
        if (code != null) onChanged(code);
      },
    );
  }
}

/// '0009 · SIRET (FR)', 'EM · E-mail'.
String easSchemeLabel(EasScheme s) => '${s.code} · ${s.name}${s.country.isEmpty ? '' : ' (${s.country})'}';

/// What the person is told when an address cannot be stored.
String easRefusalText(AppLocalizations l10n, EasRefusal refusal, String scheme) => switch (refusal) {
  EasRefusal.scheme => l10n.eInvoiceAddressSchemeRefused,
  EasRefusal.identifier => l10n.eInvoiceAddressIdentifierRefused(easSchemeOf(scheme)?.name ?? scheme),
};
