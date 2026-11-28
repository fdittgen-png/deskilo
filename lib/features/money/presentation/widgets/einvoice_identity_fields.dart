// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart' show RegionOnInvoice;
import 'package:flutter/material.dart';

import '../../../../core/jurisdiction/installed_postal_layouts.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/address_region_field.dart';
import '../../../../core/ui/einvoice_scheme_field.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';

/// #2358 — the space's e-invoicing address on its legal identity: where
/// the networks deliver to it (BT-34 and its EAS scheme), its county or
/// province (BT-39) and the invoicing contact (BG-6). Owns its
/// controllers; the screen hands it the stored identity and takes the
/// edited one back when it saves.
class EInvoiceIdentityForm {
  final endpointId = TextEditingController();
  final endpointScheme = TextEditingController();
  final subdivision = TextEditingController();
  final contactEmail = TextEditingController();
  final contactPhone = TextEditingController();

  /// #3649 -- why the region cannot be saved, under its field.
  final regionError = ValueNotifier<String?>(null);
  String _loadedRegion = '';

  /// #4501 -- why the address cannot be saved, under its identifier.
  final addressError = ValueNotifier<String?>(null);
  String _loadedScheme = '';
  String _loadedEndpoint = '';

  void load(InvoiceLegal legal) {
    _loadedRegion = regionCode(legal.subdivision);
    _loadedScheme = legal.einvoiceEndpointScheme;
    _loadedEndpoint = legal.einvoiceEndpointId;
    endpointId.text = legal.einvoiceEndpointId;
    endpointScheme.text = legal.einvoiceEndpointScheme;
    subdivision.text = legal.subdivision;
    contactEmail.text = legal.contactEmail;
    contactPhone.text = legal.contactPhone;
  }

  InvoiceLegal applyTo(InvoiceLegal legal) => legal.withEInvoiceAddress(
    endpointId: endpointId.text,
    endpointScheme: endpointScheme.text.toUpperCase(),
    subdivision: regionCode(subdivision.text),
    contactEmail: contactEmail.text,
    contactPhone: contactPhone.text,
  );

  /// #3649 -- whether the region may be saved for an address in [country]:
  /// the rule of every address editor, applied once the region is edited, so
  /// an identity stored before its country asked for one keeps saving.
  bool regionAccepted(String country, AppLocalizations l10n) {
    final code = regionCode(subdivision.text);
    final refusal = code == _loadedRegion
        ? null
        : postalLayoutOf(country).regionRefusal(code);
    regionError.value = refusal == null ? null : regionRefusalText(l10n, refusal);
    return refusal == null;
  }

  /// #4501 -- whether the address may be saved: a scheme of the list and an identifier of its form, or the address
  /// as it was stored.
  bool addressAccepted(AppLocalizations l10n) {
    final refusal = easAddressRefusal(
      endpointScheme.text,
      endpointId.text,
      storedScheme: _loadedScheme,
      storedIdentifier: _loadedEndpoint,
    );
    addressError.value = refusal == null ? null : easRefusalText(l10n, refusal, endpointScheme.text);
    return refusal == null;
  }

  void dispose() {
    regionError.dispose();
    addressError.dispose();
    for (final c in [
      endpointId,
      endpointScheme,
      subdivision,
      contactEmail,
      contactPhone,
    ]) {
      c.dispose();
    }
  }
}

class EInvoiceIdentityFields extends StatelessWidget {
  const EInvoiceIdentityFields({
    super.key,
    required this.form,
    required this.country,
  });

  final EInvoiceIdentityForm form;

  /// The space's country, whose layout says what its region is called.
  final String country;

  bool get _owedOnInvoices =>
      (postalLayoutOf(country).region?.requiredOnInvoice ?? RegionOnInvoice.none) !=
      RegionOnInvoice.none;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.eInvoiceIdentityTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.eInvoiceIdentityHelp,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const FormGap(),
        EInvoiceSchemeField(
          key: const ValueKey('legal-identity-einvoice-scheme'),
          value: form.endpointScheme.text,
          onChanged: (code) {
            form.endpointScheme.text = code;
            form.addressError.value = null;
          },
        ),
        const FormGap(),
        ValueListenableBuilder(
          valueListenable: form.addressError,
          builder: (context, error, _) => AppTextField(
            key: const ValueKey('legal-identity-einvoice-endpoint'),
            controller: form.endpointId,
            label: l10n.eInvoiceEndpointIdField,
            error: error,
          ),
        ),
        const FormGap(),
        ValueListenableBuilder(
          valueListenable: form.regionError,
          builder: (context, error, _) => AddressRegionField(
            fieldKey: 'legal-identity-subdivision',
            country: country,
            value: form.subdivision.text,
            // #4105 -- a region this country's invoices require is said
            // missing here, before the first issue refuses it.
            error: error ?? (_owedOnInvoices && form.subdivision.text.trim().isEmpty
                ? l10n.addressRegionMissing
                : null),
            onChanged: (v) {
              form.subdivision.text = v;
              form.regionError.value = null;
            },
          ),
        ),
        AppTextField(
          key: const ValueKey('legal-identity-contact-email'),
          controller: form.contactEmail,
          label: l10n.eInvoiceContactEmailField,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
        ),
        const FormGap(),
        AppTextField(
          key: const ValueKey('legal-identity-contact-phone'),
          controller: form.contactPhone,
          label: l10n.eInvoiceContactPhoneField,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
        ),
      ],
    );
  }
}
