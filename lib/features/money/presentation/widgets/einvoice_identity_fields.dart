// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/invoice_legal.dart';

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

  void load(InvoiceLegal legal) {
    endpointId.text = legal.einvoiceEndpointId;
    endpointScheme.text = legal.einvoiceEndpointScheme;
    subdivision.text = legal.subdivision;
    contactEmail.text = legal.contactEmail;
    contactPhone.text = legal.contactPhone;
  }

  InvoiceLegal applyTo(InvoiceLegal legal) => legal.withEInvoiceAddress(
    endpointId: endpointId.text,
    endpointScheme: endpointScheme.text.toUpperCase(),
    subdivision: subdivision.text.toUpperCase(),
    contactEmail: contactEmail.text,
    contactPhone: contactPhone.text,
  );

  void dispose() {
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
  const EInvoiceIdentityFields({super.key, required this.form});

  final EInvoiceIdentityForm form;

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
        AppTextField(
          key: const ValueKey('legal-identity-einvoice-endpoint'),
          controller: form.endpointId,
          label: l10n.eInvoiceEndpointIdField,
        ),
        const FormGap(),
        AppTextField(
          key: const ValueKey('legal-identity-einvoice-scheme'),
          controller: form.endpointScheme,
          label: l10n.eInvoiceEndpointSchemeField,
        ),
        const FormGap(),
        AppTextField(
          key: const ValueKey('legal-identity-subdivision'),
          controller: form.subdivision,
          label: l10n.eInvoiceSubdivisionField,
        ),
        const FormGap(),
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
