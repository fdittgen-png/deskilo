// SPDX-License-Identifier: 0BSD
import '../../../../core/country/country_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_dot.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/payment_instructions.dart';
import '../../providers/workspace_providers.dart';

/// The workspace's manual PAYMENT METHODS (#155/#192, extracted to its
/// own screen in #486): what members see on an unpaid statement — IBAN,
/// PayPal, Wero, Lydia, Wise and the payment reference hint. All
/// optional; empty fields render nothing. Reached from Settings →
/// Administration and from Workspace settings → Payments & billing.
class PaymentMethodsScreen extends ConsumerStatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  ConsumerState<PaymentMethodsScreen> createState() =>
      _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState
    extends ConsumerState<PaymentMethodsScreen> {
  final _iban = TextEditingController();
  final _accountNumber = TextEditingController();
  final _bankCode = TextEditingController();
  final _bankName = TextEditingController();
  final _bic = TextEditingController();
  final _paypalMe = TextEditingController();
  final _reference = TextEditingController();
  final _wero = TextEditingController();
  final _lydia = TextEditingController();
  final _wise = TextEditingController();
  bool _seeded = false;
  bool _busy = false;

  @override
  void dispose() {
    _iban.dispose();
    _accountNumber.dispose();
    _bankCode.dispose();
    _bankName.dispose();
    _bic.dispose();
    _paypalMe.dispose();
    _reference.dispose();
    _wero.dispose();
    _lydia.dispose();
    _wise.dispose();
    super.dispose();
  }

  Future<void> _save(String workspaceId) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    await runGuarded(
      context,
      domain: 'workspace',
      message: 'payment instructions save failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        await ref.read(workspaceRepositoryProvider).setPaymentInstructions(
              workspaceId,
              PaymentInstructions(
                iban: _iban.text,
                accountNumber: _accountNumber.text,
                bankCode: _bankCode.text,
                bankName: _bankName.text,
                bic: _bic.text,
                paypalMe: _paypalMe.text,
                reference: _reference.text,
                wero: _wero.text,
                lydia: _lydia.text,
                wise: _wise.text,
              ),
            );
        ref.invalidate(myWorkspacesProvider);
        if (!mounted) return;
        AppSnack.success(
          context,
          l10n?.workspaceSettingsSaved ?? 'Workspace saved.',
        );
      },
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    if (workspace == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
              l10n?.paymentInstructionsTitle ?? 'Payment instructions'),
        ),
        body: const LoadingView(),
      );
    }
    if (!_seeded) {
      _seeded = true;
      final instructions =
          PaymentInstructions.fromDb(workspace.paymentInstructions);
      _iban.text = instructions.iban;
      _accountNumber.text = instructions.accountNumber;
      _bankCode.text = instructions.bankCode;
      _bankName.text = instructions.bankName;
      _bic.text = instructions.bic;
      _paypalMe.text = instructions.paypalMe;
      _reference.text = instructions.reference;
      _wero.text = instructions.wero;
      _lydia.text = instructions.lydia;
      _wise.text = instructions.wise;
    }
    Widget field(String key, TextEditingController controller,
            String label) =>
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: TextField(
            key: Key(key),
            controller: controller,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: label,
              suffixIcon: HelpDot(
                l10n?.helpHintMoneyPaymentsTopic ?? 'The Payments face',
              ),
            ),
          ),
        );
    return Scaffold(
      appBar: AppBar(
        title:
            Text(l10n?.paymentInstructionsTitle ?? 'Payment instructions'),
      ),
      body: ListView(
        padding: AppSpacing.gutterAll,
        children: [
          Text(
            l10n?.paymentInstructionsHelper ??
                'Shown to members on an unpaid statement. Leave empty '
                    'to show nothing.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          field('workspaceSettingsIban', _iban,
              l10n?.paymentInstructionsIbanTitle ?? 'IBAN'),
          // #711 — the fields a non-IBAN country needs, labelled by the
          // workspace's banking scheme: "Sort code" in London, "Routing
          // number" in New York, "Transit · institution" in Toronto.
          // All optional; the how-to-pay card prints what is filled.
          field('workspaceSettingsBankName', _bankName,
              l10n?.paymentBankNameLabel ?? 'Bank name'),
          field('workspaceSettingsAccountNumber', _accountNumber,
              l10n?.paymentAccountNumberLabel ?? 'Account number'),
          field(
              'workspaceSettingsBankCode',
              _bankCode,
              bankCodeLabelFor(
                CountryCatalog.byCode(
                        ref.watch(currentWorkspaceProvider).value?.countryCode ?? '')
                    .scheme,
                sortCode: l10n?.paymentSortCodeLabel ?? 'Sort code',
                routingNumber: l10n?.paymentRoutingNumberLabel ?? 'Routing number',
                transitNumber:
                    l10n?.paymentTransitNumberLabel ?? 'Transit · institution',
                bankCode: l10n?.paymentBankCodeLabel ?? 'Bank code',
              )),
          field('workspaceSettingsBic', _bic,
              l10n?.paymentBicLabel ?? 'BIC / SWIFT'),
          field('workspaceSettingsPaypalMe', _paypalMe,
              l10n?.paymentInstructionsPaypalLabel ??
                  'PayPal.me link or handle'),
          field('workspaceSettingsWero', _wero,
              l10n?.paymentInstructionsWeroLabel ?? 'Wero phone number'),
          field('workspaceSettingsLydia', _lydia,
              l10n?.paymentInstructionsLydiaLabel ??
                  'Lydia phone number or username'),
          field('workspaceSettingsWise', _wise,
              l10n?.paymentInstructionsWiseLabel ??
                  'Wisetag or Wise payment link'),
          field('workspaceSettingsReference', _reference,
              l10n?.paymentInstructionsReferenceLabel ??
                  'Payment reference hint'),
          FilledButton(
            key: const ValueKey('payment-methods-save'),
            onPressed: _busy ? null : () => _save(workspace.id),
            child: Text(l10n?.commonSave ?? 'Save'),
          ),
        ],
      ),
    );
  }
}
