// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4164 A2 -- the seller's editor of a billing customer: the name or company
// they are billed under, the postal identity, the tax numbers and a contact for
// the invoice. Domain-first: the pure rules run before anything is sent; the
// server's own refusals (a stale revision, no right) come back as a closed
// outcome of the command and are worded here, the sheet staying open.
import 'package:flutter/material.dart';

import '../../../../core/failure/app_failure.dart';
import '../../../../core/jurisdiction/installed_postal_layouts.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/address_region_field.dart';
import '../../../../core/ui/country_field.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/billing_customer_commands.dart';
import '../../domain/billing_customer.dart';

/// Opens the editor. [existing] edits a customer (at the revision it was read);
/// null creates one. [canSetCapacity] shows the business/person choice, which
/// needs the right to issue invoices. Returns true when something was saved.
Future<bool> showBillingCustomerSheet(
  BuildContext context, {
  required BillingCustomerCommands commands,
  required String workspaceId,
  BillingParty? existing,
  required bool canSetCapacity,
}) {
  final l10n = context.l10n;
  final form = _BillingCustomerForm(existing, canSetCapacity: canSetCapacity);
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: existing == null
          ? l10n.billingCustomerNewTitle
          : l10n.billingCustomerEditTitle,
      submitLabel: l10n.commonSave,
      submitKey: const ValueKey('billing-customer-save'),
      onDispose: form.fields.dispose,
      validate: () {
        final region = form.regionProblem();
        form._regionError = region == null ? null : regionRefusalText(l10n, region);
        return {
          for (final e in commands.check(form.read()).entries) e.key: _problemText(l10n, e.value),
          'billing-customer-region': ?form._regionError,
        };
      },
      onSubmit: () => form.submit(l10n, commands, workspaceId),
      builder: (context, refresh) => form.widgets(context, l10n, refresh),
    ),
  );
}

/// The state of one open editor: its fields and the capacity being chosen.
class _BillingCustomerForm {
  _BillingCustomerForm(this.existing, {required this.canSetCapacity})
    : _subdivision = existing?.draft.subdivision ?? '',
      capacity = existing?.capacity,
      fields = FormControllers({
        'courtesy': existing?.draft.courtesy ?? '',
        'firstName': existing?.draft.firstName ?? '',
        'lastName': existing?.draft.lastName ?? '',
        'company': existing?.draft.company ?? '',
        'street': existing?.draft.street ?? '',
        'postalCode': existing?.draft.postalCode ?? '',
        'city': existing?.draft.city ?? '',
        'country': existing?.draft.countryCode ?? '',
        'vat': existing?.draft.vatId ?? '',
        'legal': existing?.draft.legalId ?? '',
        'email': existing?.draft.email ?? '',
        'phone': existing?.draft.phone ?? '',
      });

  final BillingParty? existing;
  final bool canSetCapacity;
  final FormControllers fields;
  String _subdivision;
  String? _regionError;
  String? capacity;
  bool _capacityChanged = false;

  BillingPartyDraft read() => BillingPartyDraft(
    courtesy: fields.text('courtesy'),
    firstName: fields.text('firstName'),
    lastName: fields.text('lastName'),
    company: fields.text('company'),
    street: fields.text('street'),
    postalCode: fields.text('postalCode'),
    city: fields.text('city'),
    countryCode: fields.text('country'),
    vatId: fields.text('vat'),
    legalId: fields.text('legal'),
    email: fields.text('email'),
    phone: fields.text('phone'),
    subdivision: _subdivision,
  );

  /// #4501 (FIN-10) -- why the region does not fit the country, once the country or the region was edited: a customer stored
  /// before its country asked for one keeps saving as it is.
  RegionRefusal? regionProblem() {
    final draft = read();
    final saved = existing?.draft;
    final edited = saved == null || draft.countryCode != saved.countryCode || draft.subdivision != saved.subdivision;
    return edited ? postalLayoutOf(draft.countryCode.trim().toUpperCase()).regionRefusal(draft.subdivision) : null;
  }

  /// Sends the draft; null when saved, else the sentence to show.
  Future<String?> submit(
    AppLocalizations l10n,
    BillingCustomerCommands commands,
    String workspaceId,
  ) async {
    final stated = canSetCapacity && _capacityChanged ? capacity : null;
    final saved = existing;
    final outcome = saved == null
        ? await commands.create(workspaceId, read(), capacity: stated)
        : await commands.save(workspaceId, saved, read(), capacity: stated);
    return switch (outcome) {
      CommandDone() => null,
      CommandRefused(refusal: Refusal(cause: BillingDraftInvalid())) =>
        l10n.billingCustomerNameNeeded,
      CommandRefused(refusal: Refusal(cause: final BillingCustomerRefusal r)) =>
        _refusalText(l10n, r.kind),
      _ => l10n.billingCustomerSaveFailed,
    };
  }

  List<Widget> widgets(
    BuildContext context,
    AppLocalizations l10n,
    VoidCallback refresh,
  ) => [
    ..._name(l10n),
    const FormGap(),
    ..._address(l10n, refresh),
    const FormGap(),
    ..._tax(l10n),
    const FormGap(),
    ..._contact(l10n),
    if (canSetCapacity) ..._capacityChoice(context, l10n, refresh),
  ];

  List<Widget> _name(AppLocalizations l10n) => [
    AppTextField(
      key: const ValueKey('billing-customer-company'),
      controller: fields['company'],
      fieldKey: 'company',
      label: l10n.billingCustomerCompany,
      autofillHints: const [AutofillHints.organizationName],
    ),
    const FormGap.small(),
    Row(
      children: [
        SizedBox(
          width: 96,
          child: AppTextField(
            controller: fields['courtesy'],
            label: l10n.billingCustomerCourtesy,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: AppTextField(
            controller: fields['firstName'],
            label: l10n.personalInfoFirstName,
            autofillHints: const [AutofillHints.givenName],
          ),
        ),
      ],
    ),
    const FormGap.small(),
    AppTextField(
      controller: fields['lastName'],
      label: l10n.billingCustomerLastName,
      autofillHints: const [AutofillHints.familyName],
    ),
  ];

  List<Widget> _address(AppLocalizations l10n, VoidCallback refresh) => [
    AppTextField(
      controller: fields['street'],
      label: l10n.billingCustomerStreet,
      autofillHints: const [AutofillHints.fullStreetAddress],
    ),
    const FormGap.small(),
    Row(
      children: [
        SizedBox(
          width: 120,
          child: AppTextField(
            controller: fields['postalCode'],
            label: l10n.personalInfoPostalCode,
            autofillHints: const [AutofillHints.postalCode],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: AppTextField(
            controller: fields['city'],
            label: l10n.billingCustomerCity,
            autofillHints: const [AutofillHints.addressCity],
          ),
        ),
      ],
    ),
    const FormGap.small(),
    CountryField(
      controller: fields['country'],
      fieldKey: 'country',
      textKey: const ValueKey('billing-customer-country'),
      label: l10n.billingCustomerCountry,
      // the region is asked again for the country now chosen: one that country has no place for is dropped
      onChanged: (code) {
        if (postalLayoutOf(code.trim().toUpperCase()).regionRefusal(_subdivision) != null) _subdivision = '';
        _regionError = null;
        refresh();
      },
    ),
    if (fields.text('country').trim().isNotEmpty)
      AddressRegionField(
      key: ValueKey('billing-customer-region-${fields.text('country').trim().toUpperCase()}'),
      fieldKey: 'billing-customer-region',
      country: fields.text('country').trim().toUpperCase(),
      value: _subdivision,
      error: _regionError,
      onChanged: (v) {
        _subdivision = v;
        _regionError = null;
        refresh();
      },
    ),
  ];

  List<Widget> _tax(AppLocalizations l10n) => [
    AppTextField(
      controller: fields['vat'],
      fieldKey: 'vat',
      label: l10n.billingCustomerVatId,
    ),
    const FormGap.small(),
    AppTextField(
      controller: fields['legal'],
      label: l10n.billingCustomerLegalId,
    ),
  ];

  List<Widget> _contact(AppLocalizations l10n) => [
    AppTextField(
      controller: fields['email'],
      fieldKey: 'email',
      label: l10n.billingCustomerEmail,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
    ),
    const FormGap.small(),
    AppTextField(
      controller: fields['phone'],
      label: l10n.billingCustomerPhone,
      keyboardType: TextInputType.phone,
      autofillHints: const [AutofillHints.telephoneNumber],
    ),
  ];

  /// The business/person choice, a menu (a choice nobody has to re-state when
  /// they only edit an address).
  List<Widget> _capacityChoice(
    BuildContext context,
    AppLocalizations l10n,
    VoidCallback refresh,
  ) {
    String name(String? value) => switch (value) {
      'business' => l10n.billingCustomerBusiness,
      'consumer' => l10n.billingCustomerConsumer,
      _ => l10n.billingCustomerUnstated,
    };
    return [
      const FormGap(),
      PopupMenuButton<String>(
        key: const ValueKey('billing-customer-capacity'),
        initialValue: capacity ?? '',
        onSelected: (chosen) {
          capacity = chosen.isEmpty ? null : chosen;
          _capacityChanged = true;
          refresh();
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'business', child: Text(name('business'))),
          PopupMenuItem(value: 'consumer', child: Text(name('consumer'))),
          PopupMenuItem(value: '', child: Text(name(null))),
        ],
        child: InputDecorator(
          decoration: InputDecoration(labelText: l10n.billingCustomerCapacity),
          child: Text(name(capacity)),
        ),
      ),
      const FormGap.small(),
      Text(
        l10n.billingCustomerCapacityHelper,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ];
  }
}

String _problemText(AppLocalizations l10n, BillingPartyProblem problem) =>
    switch (problem) {
      BillingPartyProblem.nameMissing => l10n.billingCustomerNameNeeded,
      BillingPartyProblem.countryInvalid => l10n.billingCustomerCountryInvalid,
      BillingPartyProblem.vatIdInvalid => l10n.billingCustomerVatInvalid,
      BillingPartyProblem.emailInvalid => l10n.billingCustomerEmailInvalid,
    };

String _refusalText(AppLocalizations l10n, BillingCustomerRefusalKind kind) =>
    switch (kind) {
      BillingCustomerRefusalKind.stale => l10n.billingCustomerStale,
      BillingCustomerRefusalKind.notAllowed => l10n.billingCustomerNotAllowed,
      BillingCustomerRefusalKind.unknownCustomer => l10n.billingCustomerGone,
      BillingCustomerRefusalKind.nameNeeded => l10n.billingCustomerNameNeeded,
      BillingCustomerRefusalKind.other => l10n.billingCustomerSaveFailed,
    };
