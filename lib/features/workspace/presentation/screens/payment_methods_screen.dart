// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../application/save_payment_instructions.dart';
import '../../domain/payment_instructions.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/payment_instructions_fields.dart';

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
  /// Seeded once, from the first workspace row that arrives.
  PaymentInstructionsDraft? _draft;
  bool _busy = false;

  @override
  void dispose() {
    _draft?.dispose();
    super.dispose();
  }

  Future<void> _save(String workspaceId, PaymentInstructions value) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    await runGuarded(
      context,
      domain: 'workspace',
      message: 'payment instructions save failed',
      errorText: l10n.workspaceGenericError,
      action: () async {
        await ref
            .read(savePaymentInstructionsProvider)
            .save(workspaceId, value);
        ref.invalidate(myWorkspacesProvider);
        if (!mounted) return;
        AppSnack.success(
          context,
          l10n.workspaceSettingsSaved,
        );
      },
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final workspace = ref.watch(currentWorkspaceProvider).value;
    if (workspace == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
              l10n.paymentInstructionsTitle),
        ),
        body: const LoadingView(),
      );
    }
    final draft = _draft ??= PaymentInstructionsDraft(
      PaymentInstructions.fromDb(workspace.paymentInstructions),
    );
    return Scaffold(
      appBar: AppBar(
        title:
            Text(l10n.paymentInstructionsTitle),
        actions: [
          HelpDot(
            l10n.helpHintMoneyPaymentsTopic,
            anchor: HelpAnchor.paymentsMethods,
          ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.gutterAll,
        children: [
          Text(
            l10n.paymentInstructionsHelper,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PaymentInstructionsFields(
            draft: draft,
            countryCode: workspace.countryCode,
            enabled: !_busy,
          ),
          FilledButton(
            key: const ValueKey('payment-methods-save'),
            onPressed: _busy ? null : () => _save(workspace.id, draft.value),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }
}
