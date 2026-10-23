// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup step "legal identity": the details every invoice must carry,
// prefilled from the stored identity and saved through the legal identity
// screen's own command ([LegalIdentity]). What the owner does not edit here
// (the payment clauses, the e-invoicing address, the tax point...) is
// written back exactly as stored, and the full screen is one tap away.
// Beside the form, the top of the sample invoice as it prints, redrawn as
// the owner types; above it, what to ask an accountant first.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/setup_step_layout.dart';
import '../../domain/invoice_legal.dart';
import '../../domain/invoice_report.dart';
import '../../domain/report_facts.dart';
import '../../domain/vat_regime.dart';
import '../../providers/money_providers.dart';
import '../report_facts_of.dart';
import 'legal_identity_sections.dart';
import 'setup_sample_invoice.dart';

class SetupLegalIdentityStep extends ConsumerStatefulWidget {
  const SetupLegalIdentityStep({
    super.key,
    required this.workspaceId,
    required this.onSaved,
  });

  final String workspaceId;

  /// Reads the workspace row again: the identity lives on it.
  final VoidCallback onSaved;

  @override
  ConsumerState<SetupLegalIdentityStep> createState() =>
      _SetupLegalIdentityStepState();
}

class _SetupLegalIdentityStepState
    extends ConsumerState<SetupLegalIdentityStep> {
  /// The identity as stored: what an invoice prints today.
  late final _stored = sampleInvoiceFactsOf(ref).workspace;
  late final _regime = ValueNotifier(vatRegimeFromWire(_stored?.vatRegime));
  late final _fields = FormControllers({
    'vatId': _stored?.vatId ?? '',
    'legalId': _stored?.legalId ?? '',
    'legalForm': _legal.legalForm,
    'registration': _legal.registration,
    // The structured street starts from the free-text address, as on the
    // legal identity screen, so the owner completes rather than retypes.
    'street': (_stored?.street ?? '').isNotEmpty
        ? _stored?.street ?? ''
        : _stored?.address ?? '',
    'postalCode': _stored?.postalCode ?? '',
    'city': _stored?.city ?? '',
  });
  late final _changes = Listenable.merge([
    _regime,
    for (final key in const ['vatId', 'legalId', 'legalForm', 'registration'])
      _fields[key],
  ]);
  final _busy = ValueNotifier<bool>(false);

  InvoiceLegal get _legal =>
      InvoiceLegal.fromJson(_stored?.invoiceLegal ?? const {});

  SellerDraft get _draft => (
    vatRegime: vatRegimeWire(_regime.value),
    vatId: _fields.text('vatId'),
    legalId: _fields.text('legalId'),
    legalForm: _fields.text('legalForm'),
    registration: _fields.text('registration'),
  );

  @override
  void dispose() {
    _regime.dispose();
    _fields.dispose();
    _busy.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final stored = _stored;
    final template = ref.read(invoicePdfTemplateProvider).value;
    if (stored == null || template == null) return;
    _busy.value = true;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'setup legal identity failed',
      errorText: l10n.setupGrowSaveFailed,
      action: () => ref.read(legalIdentityProvider).save((
        workspaceId: widget.workspaceId,
        vatRegime: _draft.vatRegime,
        vatId: _draft.vatId,
        legalId: _draft.legalId,
        taxExemptionReason: stored.taxExemptionReason,
        street: _fields.text('street'),
        city: _fields.text('city'),
        postalCode: _fields.text('postalCode'),
        vatAccount: stored.vatAccount,
        invoiceLegal: withSellerLines(
          stored.invoiceLegal,
          legalForm: _draft.legalForm,
          registration: _draft.registration,
        ),
        addressWindow: template.addressWindow,
      ), currentTemplate: template),
    );
    widget.onSaved();
    if (!mounted) return;
    _busy.value = false;
    if (ok) AppSnack.success(context, l10n.legalIdentitySaved);
  }

  /// The header band of the sample invoice: the seller's block as it prints.
  InvoiceReport _top(BuildContext context) {
    final report = setupSampleReport(context, ref, seller: _draft);
    return InvoiceReport(
      header: report.header,
      body: const [],
      footer: const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // The save writes the template first: it waits until it is read.
    final templateRead = ref.watch(invoicePdfTemplateProvider).hasValue;
    return SetupStepLayout(
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.setupStepHint('legal_identity')),
          const FormGap.large(),
          const _AskYourAccountant(),
          const FormGap.large(),
          ValueListenableBuilder<VatRegime>(
            valueListenable: _regime,
            builder: (context, regime, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<VatRegime>(
                  key: const ValueKey('setup-legal-regime'),
                  isExpanded: true,
                  initialValue: regime,
                  items: [
                    for (final (value, label) in [
                      (
                        VatRegime.notSubject,
                        l10n.legalIdentityRegimeNotSubject,
                      ),
                      (VatRegime.exempt, l10n.legalIdentityRegimeExempt),
                      (
                        VatRegime.vatRegistered,
                        l10n.legalIdentityRegimeVatRegistered,
                      ),
                    ])
                      DropdownMenuItem(value: value, child: Text(label)),
                  ],
                  onChanged: (value) => _regime.value = value ?? regime,
                  decoration: InputDecoration(
                    labelText: l10n.legalIdentityRegime,
                    helperMaxLines: 3,
                    helperText: l10n.legalIdentityRegimeHint,
                  ),
                ),
                const FormGap(),
                // Only the number the regime needs, as on the full screen.
                if (regime.requiresVatId)
                  AppTextField(
                    key: const ValueKey('setup-legal-vat-id'),
                    controller: _fields['vatId'],
                    label: l10n.legalIdentityVatId,
                  )
                else
                  AppTextField(
                    key: const ValueKey('setup-legal-legal-id'),
                    controller: _fields['legalId'],
                    label: l10n.legalIdentityLegalId,
                  ),
              ],
            ),
          ),
          const FormGap(),
          AppTextField(
            key: const ValueKey('setup-legal-form'),
            controller: _fields['legalForm'],
            label: l10n.invoiceLegalFormField,
            helper: l10n.invoiceLegalFormHint,
          ),
          const FormGap(),
          AppTextField(
            key: const ValueKey('setup-legal-registration'),
            controller: _fields['registration'],
            label: l10n.invoiceLegalRegistrationField,
            helper: l10n.invoiceLegalRegistrationHint,
          ),
          const FormGap(),
          LegalAddressFields(
            street: _fields['street'],
            postalCode: _fields['postalCode'],
            city: _fields['city'],
          ),
          const FormGap(),
          InlineBanner(
            key: const ValueKey('setup-legal-lock'),
            icon: Icons.lock_outline,
            severity: InlineBannerSeverity.info,
            text: l10n.setupGrowLegalLock,
          ),
          const FormGap(),
          ValueListenableBuilder<bool>(
            valueListenable: _busy,
            builder: (context, busy, _) => Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton(
                key: const ValueKey('setup-legal-save'),
                onPressed: busy || !templateRead ? null : _save,
                child: Text(l10n.commonSave),
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const ValueKey('setup-legal-open-full'),
              onPressed: () => context.push('/legal-identity'),
              child: Text(l10n.setupGrowLegalOpenFull),
            ),
          ),
        ],
      ),
      preview: ListenableBuilder(
        listenable: _changes,
        builder: (context, _) => Column(
          key: const ValueKey('setup-legal-preview'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.setupGrowLegalPreviewNote),
            const FormGap.small(),
            SetupSampleSheet(report: _top(context)),
          ],
        ),
      ),
    );
  }
}

/// What to ask an accountant before filling the step in.
class _AskYourAccountant extends StatelessWidget {
  const _AskYourAccountant();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      key: const ValueKey('setup-legal-ask'),
      child: Padding(
        padding: AppSpacing.lgAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.setupGrowLegalAskTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const FormGap.small(),
            Text(l10n.setupGrowLegalAskIntro),
            for (final question in [
              l10n.setupGrowLegalAskRegime,
              l10n.setupGrowLegalAskNumber,
              l10n.setupGrowLegalAskForm,
              l10n.setupGrowLegalAskRegister,
            ])
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.help_outline),
                title: Text(question),
              ),
          ],
        ),
      ),
    );
  }
}
