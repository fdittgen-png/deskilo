// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/invoice_legal.dart';

/// #480 -- the statutory mention lines the documents print, one controller
/// per line.
class LegalMentionControllers {
  final legalForm = TextEditingController();
  final registration = TextEditingController();
  final paymentTerms = TextEditingController();
  final latePenalty = TextEditingController();
  final recovery = TextEditingController();
  final escompte = TextEditingController();
  final insurance = TextEditingController();
  final special = TextEditingController();

  void load(InvoiceLegal legal) {
    legalForm.text = legal.legalForm;
    registration.text = legal.registration;
    paymentTerms.text = legal.paymentTerms;
    latePenalty.text = legal.latePenalty;
    recovery.text = legal.recoveryIndemnity;
    escompte.text = legal.escompte;
    insurance.text = legal.insurance;
    special.text = legal.specialMentions;
  }

  void dispose() {
    for (final c in [
      legalForm,
      registration,
      paymentTerms,
      latePenalty,
      recovery,
      escompte,
      insurance,
      special,
    ]) {
      c.dispose();
    }
  }
}

/// The street, postal code and city of the seller.
class LegalAddressFields extends StatelessWidget {
  const LegalAddressFields({
    super.key,
    required this.street,
    required this.postalCode,
    required this.city,
  });

  final TextEditingController street;
  final TextEditingController postalCode;
  final TextEditingController city;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget help() =>
        HelpDot(l10n.helpTopicLegalIdentity, anchor: HelpAnchor.legalAddress);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('legal-identity-street'),
          controller: street,
          decoration: InputDecoration(
            labelText: l10n.legalIdentityStreet,
            suffixIcon: help(),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            SizedBox(
              width: 120,
              child: TextField(
                key: const ValueKey('legal-identity-postal-code'),
                controller: postalCode,
                decoration: InputDecoration(
                  labelText: l10n.legalIdentityPostalCode,
                  suffixIcon: help(),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: TextField(
                key: const ValueKey('legal-identity-city'),
                controller: city,
                decoration: InputDecoration(
                  labelText: l10n.legalIdentityCity,
                  suffixIcon: help(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The mention lines (#480), with the statutory default (or an example) as
/// the helper so the owner sees what an empty field prints; an association
/// (#484) gets its own hints.
class LegalMentionFields extends StatelessWidget {
  const LegalMentionFields({
    super.key,
    required this.controllers,
    required this.sellerKind,
  });

  final LegalMentionControllers controllers;
  final String sellerKind;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _mentionField(
          context,
          'legal-identity-legal-form',
          controllers.legalForm,
          l10n.invoiceLegalFormField,
          hint: sellerKind == 'association'
              ? (l10n.invoiceLegalFormHintAssociation)
              : l10n.invoiceLegalFormHint,
          anchor: HelpAnchor.legalForm,
        ),
        _mentionField(
          context,
          'legal-identity-registration',
          controllers.registration,
          l10n.invoiceLegalRegistrationField,
          hint: sellerKind == 'association'
              ? (l10n.invoiceLegalRegistrationHintAssociation)
              : l10n.invoiceLegalRegistrationHint,
          anchor: HelpAnchor.legalRegistration,
        ),
        _mentionField(
          context,
          'legal-identity-payment-terms',
          controllers.paymentTerms,
          l10n.invoiceLegalPaymentTermsField,
          hint: l10n.invoiceLegalPaymentTermsDefault,
          anchor: HelpAnchor.legalPaymentTerms,
        ),
        _mentionField(
          context,
          'legal-identity-late-penalty',
          controllers.latePenalty,
          l10n.invoiceLegalLatePenaltyField,
          hint: l10n.invoiceLegalLatePenaltyDefault,
          anchor: HelpAnchor.legalLatePenalty,
        ),
        _mentionField(
          context,
          'legal-identity-recovery',
          controllers.recovery,
          l10n.invoiceLegalRecoveryField,
          hint: l10n.invoiceLegalRecoveryDefault,
          anchor: HelpAnchor.legalRecovery,
        ),
        _mentionField(
          context,
          'legal-identity-escompte',
          controllers.escompte,
          l10n.invoiceLegalEscompteField,
          hint: l10n.invoiceLegalEscompteDefault,
          anchor: HelpAnchor.legalEscompte,
        ),
        _mentionField(
          context,
          'legal-identity-insurance',
          controllers.insurance,
          l10n.invoiceLegalInsuranceField,
          anchor: HelpAnchor.legalInsurance,
        ),
        _mentionField(
          context,
          'legal-identity-special',
          controllers.special,
          l10n.invoiceLegalSpecialField,
          anchor: HelpAnchor.legalSpecialMentions,
        ),
      ],
    );
  }
}

/// One mention line: capped, with the statutory default (or an
/// example) as the helper so the owner sees what an empty field
/// prints.
Widget _mentionField(
  BuildContext context,
  String key,
  TextEditingController controller,
  String label, {
  required String anchor,
  String? hint,
}) {
  final l10n = context.l10n;
  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: TextField(
      key: ValueKey(key),
      controller: controller,
      maxLength: InvoiceLegal.maxFieldLength,
      maxLines: 2,
      minLines: 1,
      decoration: InputDecoration(
        labelText: label,
        helperText: hint,
        helperMaxLines: 3,
        counterText: '',
        suffixIcon: HelpDot(l10n.helpTopicLegalIdentity, anchor: anchor),
      ),
    ),
  );
}
