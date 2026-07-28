// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/vat_regime.dart';
import '../../providers/money_providers.dart';

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
  VatRegime _regime = VatRegime.notSubject;
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
      action: () => ref.read(workspaceRepositoryProvider).setLegalIdentity(
            workspace.id,
            vatRegime: vatRegimeWire(_regime),
            vatId: _vatId.text,
            legalId: _legalId.text,
            taxExemptionReason: _reason.text,
            street: _street.text,
            city: _city.text,
            postalCode: _postalCode.text,
            vatAccount: _vatAccount.text,
          ),
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
          DropdownButtonFormField<VatRegime>(
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
          // Only a workspace that charges VAT and has no rate to charge
          // it at is in trouble — the rest is a link, not a warning.
          if (_regime == VatRegime.vatRegistered && rates.isEmpty)
            InlineBanner(
              key: const ValueKey('legal-identity-vat-warning'),
              icon: Icons.warning_amber_outlined,
              text: l10n?.legalIdentityVatWarning ??
                  'This workspace charges VAT but no rate is set up: '
                      'invoices show no tax and the XML export stays '
                      'disabled until you add one.',
            ),
          ListTile(
            key: const ValueKey('legal-identity-vat-rates'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.percent),
            title: Text(l10n?.vatRatesTile ?? 'VAT rates'),
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
              ),
            )
          else
            TextField(
              key: const ValueKey('legal-identity-legal-id'),
              controller: _legalId,
              decoration: InputDecoration(
                labelText: l10n?.legalIdentityLegalId ??
                    'Company registration number',
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
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('legal-identity-street'),
            controller: _street,
            decoration: InputDecoration(
              labelText: l10n?.legalIdentityStreet ?? 'Street',
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
            title: Text(
              l10n?.einvoiceConfigTitle ?? 'E-invoicing platform',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/einvoice-config'),
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
