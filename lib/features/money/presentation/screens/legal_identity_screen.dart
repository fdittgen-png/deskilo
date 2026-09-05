// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/help/help_dot.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/address_window.dart';
import '../../domain/invoice_legal.dart';
import '../../domain/invoice_pdf_template.dart';
import '../../domain/vat_regime.dart';
import '../../providers/money_providers.dart';
import '../widgets/address_window_field.dart';

/// The workspace's LEGAL IDENTITY (0069) — owner-only, and the reason the
/// e-invoice export can be valid at all.
///
/// EN 16931 has no default for any of this: BR-CO-26 wants an identifier,
/// and which one depends on the VAT regime (BR-O-02 forbids the VAT id
/// outside the scope of VAT; BR-E-02 requires it when exempt). So the
/// screen asks for the regime first and then only for the field that
/// regime actually needs.
class LegalIdentityScreen extends ConsumerStatefulWidget {
  const LegalIdentityScreen({super.key});

  @override
  ConsumerState<LegalIdentityScreen> createState() =>
      _LegalIdentityScreenState();
}

class _LegalIdentityScreenState extends ConsumerState<LegalIdentityScreen> {
  final _vatId = TextEditingController();
  final _legalId = TextEditingController();
  final _reason = TextEditingController();
  final _street = TextEditingController();
  final _city = TextEditingController();
  final _postalCode = TextEditingController();
  final _vatAccount = TextEditingController();
  // #480 — the legal invoice mentions, one controller per printed line.
  final _legalForm = TextEditingController();
  final _registration = TextEditingController();
  final _paymentTerms = TextEditingController();
  final _latePenalty = TextEditingController();
  final _recovery = TextEditingController();
  final _escompte = TextEditingController();
  final _insurance = TextEditingController();
  final _special = TextEditingController();
  // #484 — '' = company/business, 'association' = non-profit.
  String _sellerKind = '';
  VatRegime _regime = VatRegime.notSubject;
  // #895 — intra-EU B2B supplies are reverse-charged unless a workspace
  // that never invoices businesses abroad turns it off.
  bool _reverseCharge = true;
  // #896 — when the tax falls due: 'invoice' (débits) or 'payment'
  // (encaissements). Services are on payment by default in France, but
  // the choice is the seller's declared one, so it is asked, not guessed.
  String _exigibility = 'invoice';

  /// #869 — null means follow the country.
  AddressWindow? _addressWindow;
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _vatId.dispose();
    _legalId.dispose();
    _reason.dispose();
    _street.dispose();
    _city.dispose();
    _postalCode.dispose();
    _vatAccount.dispose();
    _legalForm.dispose();
    _registration.dispose();
    _paymentTerms.dispose();
    _latePenalty.dispose();
    _recovery.dispose();
    _escompte.dispose();
    _insurance.dispose();
    _special.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    setState(() => _saving = true);
    final saved = await runGuarded(
      context,
      domain: 'money',
      message: 'legal identity save failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        final repository = ref.read(workspaceRepositoryProvider);
        await repository.setLegalIdentity(
          workspace.id,
          vatRegime: vatRegimeWire(_regime),
          vatId: _vatId.text,
          legalId: _legalId.text,
          taxExemptionReason: _reason.text,
          street: _street.text,
          city: _city.text,
          postalCode: _postalCode.text,
          vatAccount: _vatAccount.text,
        );
        // #869 — the envelope choice lives in the document template
        // beside the bands; read-modify-write so a design saved from
        // the editor is never clobbered by this screen.
        await ref.read(moneyRepositoryProvider).setInvoicePdfTemplate(
              workspace.id,
              (ref.read(invoicePdfTemplateProvider).value ??
                      InvoicePdfTemplate.empty)
                  .copyWith(addressWindow: _addressWindow),
            );
        await repository.setInvoiceLegal(
          workspace.id,
          InvoiceLegal(
            sellerKind: _sellerKind,
            legalForm: _legalForm.text,
            registration: _registration.text,
            paymentTerms: _paymentTerms.text,
            latePenalty: _latePenalty.text,
            recoveryIndemnity: _recovery.text,
            escompte: _escompte.text,
            insurance: _insurance.text,
            specialMentions: _special.text,
            reverseChargeOptIn: _reverseCharge,
            vatExigibility: _exigibility,
          ).toJson(),
        );
      },
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!saved) return;
    ref.invalidate(myWorkspacesProvider);
    if (!mounted) return;
    AppSnack.success(
      context,
      l10n?.legalIdentitySaved ?? 'Legal identity saved.',
    );
  }

  /// One mention line: capped, with the statutory default (or an
  /// example) as the helper so the owner sees what an empty field
  /// prints.
  Widget _mentionField(
    String key,
    TextEditingController controller,
    String label, {
    String? hint,
  }) {
    final l10n = AppLocalizations.of(context);
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
          suffixIcon: HelpDot(l10n?.helpTopicLegalIdentity ?? 'Legal identity'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final rates = ref.watch(vatRatesProvider).value ?? const [];
    if (workspace == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n?.legalIdentityTitle ?? 'Legal identity'),
        ),
        body: const LoadingView(),
      );
    }
    if (!_loaded) {
      _loaded = true;
      _regime = vatRegimeFromWire(workspace.vatRegime);
      _addressWindow =
          ref.read(invoicePdfTemplateProvider).value?.addressWindow;
      _vatId.text = workspace.vatId;
      _legalId.text = workspace.legalId;
      _reason.text = workspace.taxExemptionReason;
      // The structured street starts from the free-text address so the
      // owner completes rather than retypes.
      _street.text =
          workspace.street.isNotEmpty ? workspace.street : workspace.address;
      _city.text = workspace.city;
      _postalCode.text = workspace.postalCode;
      _vatAccount.text = workspace.vatAccount;
      final legal = InvoiceLegal.fromJson(workspace.invoiceLegal);
      _sellerKind = legal.sellerKind;
      _reverseCharge = legal.reverseCharge;
      _exigibility = legal.vatExigibility;
      _legalForm.text = legal.legalForm;
      _registration.text = legal.registration;
      _paymentTerms.text = legal.paymentTerms;
      _latePenalty.text = legal.latePenalty;
      _recovery.text = legal.recoveryIndemnity;
      _escompte.text = legal.escompte;
      _insurance.text = legal.insurance;
      _special.text = legal.specialMentions;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n?.legalIdentityTitle ?? 'Legal identity & e-invoicing',
        ),
      ),
      body: ListView(
        padding: AppSpacing.gutterAll,
        children: [
          Text(
            l10n?.legalIdentityIntro ??
                'What an EN 16931 e-invoice must state about you. Invoices '
                    'already issued keep the identity they were signed with.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<VatRegime>(
                key: const ValueKey('legal-identity-regime'),
                initialValue: _regime,
                items: [
                  DropdownMenuItem(
                    value: VatRegime.notSubject,
                    child: Text(
                      l10n?.legalIdentityRegimeNotSubject ??
                          'Outside the scope of VAT',
                    ),
                  ),
                  DropdownMenuItem(
                    value: VatRegime.exempt,
                    child: Text(
                      l10n?.legalIdentityRegimeExempt ??
                          'VAT-exempt (small-business scheme)',
                    ),
                  ),
                  DropdownMenuItem(
                    value: VatRegime.vatRegistered,
                    child: Text(
                      l10n?.legalIdentityRegimeVatRegistered ??
                          'VAT-registered (charges VAT)',
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _regime = value ?? _regime),
                decoration: InputDecoration(
                  labelText: l10n?.legalIdentityRegime ?? 'VAT regime',
                  helperMaxLines: 3,
                  helperText: l10n?.legalIdentityRegimeHint ??
                      'The regime decides which number the norm requires.',
                ),
              ),
            ),
            HelpDot(l10n?.helpTopicVat ?? 'VAT'),
          ]),
          // Only a workspace that charges VAT and has no rate to charge
          // it at is in trouble — the rest is a link, not a warning.
          // #895 — the customer's tax, across the border.
          if (_regime == VatRegime.vatRegistered)
            SwitchListTile(
              key: const ValueKey('legal-identity-reverse-charge'),
              contentPadding: EdgeInsets.zero,
              value: _reverseCharge,
              title: Text(l10n?.reverseChargeTitle ??
                  'Reverse charge for EU businesses'),
              subtitle: Text(l10n?.reverseChargeSubtitle ??
                  'A customer with a VAT number in another member state '
                      'is invoiced without tax and self-assesses it '
                      '(art. 196). Turn it off if you never invoice '
                      'businesses abroad.'),
              onChanged: (v) => setState(() => _reverseCharge = v),
            ),
          // #896 — WHEN the tax falls due decides which period a
          // declaration covers, and it is printed on every invoice.
          if (_regime == VatRegime.vatRegistered)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: DropdownButtonFormField<String>(
                key: const ValueKey('legal-identity-exigibility'),
                initialValue: _exigibility,
                items: [
                  DropdownMenuItem(
                    value: 'invoice',
                    child: Text(l10n?.vatExigibilityInvoice ??
                        'On invoices (débits)'),
                  ),
                  DropdownMenuItem(
                    value: 'payment',
                    child: Text(l10n?.vatExigibilityPayment ??
                        'On receipts (encaissements)'),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => _exigibility = v ?? _exigibility),
                decoration: InputDecoration(
                  labelText: l10n?.vatExigibilityTitle ?? 'VAT falls due',
                  helperMaxLines: 4,
                  helperText: l10n?.vatExigibilitySubtitle ??
                      'On receipts, a period declares what customers paid '
                          'inside it; on invoices, what you issued. '
                          'The choice is printed on every invoice.',
                ),
              ),
            ),
          // #919 — an ASSOCIATION that charges no VAT is out of the
          // SCOPE of it, not exempt within the scope. The two look
          // interchangeable on this screen and are not: 'exempt' demands
          // a seller VAT identifier (BR-E-02) that a non-profit does not
          // have, so its e-invoice is refused by the validator with a
          // message about a missing number nobody can supply. Out of
          // scope, BR-O-02 forbids that number and the registration one
          // identifies the seller instead — which the association has.
          if (_sellerKind == 'association' && _regime == VatRegime.exempt)
            InlineBanner(
              key: const ValueKey('legal-identity-association-regime'),
              icon: Icons.info_outline,
              text: l10n?.legalIdentityAssociationRegime ??
                  'A non-profit association with no trading activity is '
                      'not subject to VAT: choose "Outside the scope of '
                      'VAT", not "Exempt". The exempt scheme requires a '
                      'VAT number you do not have, and the e-invoice '
                      'would be rejected.',
            ),
          if (_regime == VatRegime.vatRegistered && rates.isEmpty)
            InlineBanner(
              key: const ValueKey('legal-identity-vat-warning'),
              icon: Icons.warning_amber_outlined,
              text: l10n?.legalIdentityVatWarning ??
                  'This workspace charges VAT but no rate is set up: '
                      'invoices show no tax and the XML export stays '
                      'disabled until you add one.',
            ),
          if (_regime == VatRegime.vatRegistered &&
              ref
                  .watch(enabledFeaturesSyncProvider)
                  .contains(WorkspaceFeature.vatManagement))
          ListTile(
            key: const ValueKey('legal-identity-vat-rates'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.percent),
            title: HelpDotTitle(
              l10n?.vatRatesTile ?? 'VAT rates',
              l10n?.helpTopicVat ?? 'VAT',
            ),
            subtitle: rates.isEmpty
                ? Text(l10n?.vatEmpty ?? 'No rate yet — invoices show no VAT.')
                : Text(rates
                    .map((rate) => '${rate.label} '
                        '(${rate.percent == rate.percent.roundToDouble() ? rate.percent.toStringAsFixed(0) : rate.percent})')
                    .join(' · ')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/vat'),
          ),
          if (_regime == VatRegime.vatRegistered)
            TextField(
              key: const ValueKey('legal-identity-vat-account'),
              controller: _vatAccount,
              decoration: InputDecoration(
                labelText: l10n?.vatAccountField ?? 'VAT account',
                helperMaxLines: 3,
                helperText: l10n?.vatAccountHint ??
                    'Where the accounting export books collected VAT. '
                        'Empty = 445710.',
                suffixIcon: HelpDot(l10n?.helpTopicVat ?? 'VAT'),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          // Only the identifier the declared regime needs — the other one
          // would make the document invalid, not merely redundant.
          if (_regime.requiresVatId)
            TextField(
              key: const ValueKey('legal-identity-vat-id'),
              controller: _vatId,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: l10n?.legalIdentityVatId ?? 'VAT number',
                suffixIcon: HelpDot(l10n?.helpTopicVat ?? 'VAT'),
              ),
            )
          else
            TextField(
              key: const ValueKey('legal-identity-legal-id'),
              controller: _legalId,
              decoration: InputDecoration(
                labelText: l10n?.legalIdentityLegalId ??
                    'Company registration number',
                suffixIcon:
                    HelpDot(l10n?.helpTopicLegalIdentity ?? 'Legal identity'),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('legal-identity-reason'),
            controller: _reason,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: l10n?.legalIdentityExemptionReason ??
                  'Why no VAT is charged',
              helperMaxLines: 4,
              helperText: _sellerKind == 'association'
                  ? (l10n?.invoiceLegalAssociationReasonHint ??
                      'e.g. "TVA non applicable, art. 293 B du CGI" — or '
                          '"Exonération de TVA, art. 261, 7-1° du CGI" '
                          'for services to members')
                  : null,
              suffixIcon: HelpDot(l10n?.helpTopicVat ?? 'VAT'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('legal-identity-street'),
            controller: _street,
            decoration: InputDecoration(
              labelText: l10n?.legalIdentityStreet ?? 'Street',
              suffixIcon:
                  HelpDot(l10n?.helpTopicLegalIdentity ?? 'Legal identity'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(children: [
            SizedBox(
              width: 120,
              child: TextField(
                key: const ValueKey('legal-identity-postal-code'),
                controller: _postalCode,
                decoration: InputDecoration(
                  labelText: l10n?.legalIdentityPostalCode ?? 'Post code',
                  suffixIcon: HelpDot(
                    l10n?.helpTopicLegalIdentity ?? 'Legal identity',
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: TextField(
                key: const ValueKey('legal-identity-city'),
                controller: _city,
                decoration: InputDecoration(
                  labelText: l10n?.legalIdentityCity ?? 'City',
                  suffixIcon: HelpDot(
                    l10n?.helpTopicLegalIdentity ?? 'Legal identity',
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: AppSpacing.md),
          // The other half of the same question: who receives the file.
          ListTile(
            key: const ValueKey('legal-identity-platform'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cloud_upload_outlined),
            title: HelpDotTitle(
              l10n?.einvoiceConfigTitle ?? 'E-invoicing platform',
              l10n?.helpTopicEinvoice ?? 'e-invoice',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/einvoice-config'),
          ),
          const SizedBox(height: AppSpacing.lg),
          // #480 — the statutory mention lines the documents print.
          Text(
            l10n?.invoiceLegalSection ?? 'Invoice mentions',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n?.invoiceLegalIntro ??
                'The statutory lines printed on invoices and reminders. '
                    'The payment clauses fall back to legal defaults when '
                    'left empty.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          // #484 — associations invoice differently: no B2B clause
          // defaults, RNA instead of a trade register, an exemption
          // mention instead of VAT.
          Row(children: [
            Expanded(
              child: SegmentedButton<String>(
                key: const ValueKey('legal-identity-kind'),
                segments: [
                  ButtonSegment(
                    value: '',
                    label: Text(
                        l10n?.invoiceLegalKindCompany ?? 'Company / business'),
                  ),
                  ButtonSegment(
                    value: 'association',
                    label: Text(l10n?.invoiceLegalKindAssociation ??
                        'Association (non-profit)'),
                  ),
                ],
                selected: {_sellerKind},
                onSelectionChanged: (selection) =>
                    setState(() => _sellerKind = selection.first),
              ),
            ),
            HelpDot(l10n?.helpTopicLegalIdentity ?? 'Legal identity'),
          ]),
          if (_sellerKind == 'association') ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n?.invoiceLegalAssociationHint ??
                  'The late-penalty, recovery-indemnity and discount '
                      'clauses are printed only when filled — they are '
                      'mandatory only between professionals.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _mentionField(
            'legal-identity-legal-form',
            _legalForm,
            l10n?.invoiceLegalFormField ?? 'Legal form & capital',
            hint: _sellerKind == 'association'
                ? (l10n?.invoiceLegalFormHintAssociation ??
                    'e.g. Association loi 1901')
                : l10n?.invoiceLegalFormHint,
          ),
          _mentionField(
            'legal-identity-registration',
            _registration,
            l10n?.invoiceLegalRegistrationField ?? 'Trade register',
            hint: _sellerKind == 'association'
                ? (l10n?.invoiceLegalRegistrationHintAssociation ??
                    'e.g. RNA W123456789 · SIRET if assigned')
                : l10n?.invoiceLegalRegistrationHint,
          ),
          _mentionField(
            'legal-identity-payment-terms',
            _paymentTerms,
            l10n?.invoiceLegalPaymentTermsField ?? 'Payment terms',
            hint: l10n?.invoiceLegalPaymentTermsDefault,
          ),
          _mentionField(
            'legal-identity-late-penalty',
            _latePenalty,
            l10n?.invoiceLegalLatePenaltyField ?? 'Late-payment penalty',
            hint: l10n?.invoiceLegalLatePenaltyDefault,
          ),
          _mentionField(
            'legal-identity-recovery',
            _recovery,
            l10n?.invoiceLegalRecoveryField ?? 'Recovery indemnity',
            hint: l10n?.invoiceLegalRecoveryDefault,
          ),
          _mentionField(
            'legal-identity-escompte',
            _escompte,
            l10n?.invoiceLegalEscompteField ?? 'Early-payment discount',
            hint: l10n?.invoiceLegalEscompteDefault,
          ),
          _mentionField(
            'legal-identity-insurance',
            _insurance,
            l10n?.invoiceLegalInsuranceField ?? 'Professional insurance',
          ),
          _mentionField(
            'legal-identity-special',
            _special,
            l10n?.invoiceLegalSpecialField ?? 'Special mentions',
          ),
          const SizedBox(height: AppSpacing.md),
          // #869 — where the sheet is addressed. It sits with the legal
          // identity rather than the band editor because it applies
          // whether or not the workspace writes its own template.
          if (ref
              .watch(enabledFeaturesSyncProvider)
              .contains(WorkspaceFeature.invoiceAddressWindow))
            AddressWindowField(
              value: _addressWindow,
              countryCode: workspace.countryCode,
              onChanged: (window) =>
                  setState(() => _addressWindow = window),
            ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const ValueKey('legal-identity-save'),
            onPressed: _saving ? null : _save,
            child: Text(l10n?.commonSave ?? 'Save'),
          ),
        ],
      ),
    );
  }
}
