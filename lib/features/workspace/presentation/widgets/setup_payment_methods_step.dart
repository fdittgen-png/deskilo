// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup step "how members pay": the payment methods screen's own
// fields, prefilled from the workspace, saved through
// [SavePaymentInstructions]. Beside them the instructions exactly as a
// member reads them on an unpaid statement, redrawn as the owner types.
// What the owner typed and has not saved is kept as the step's draft on
// the server (#2869).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/setup_draft_form.dart';
import '../../../../core/ui/setup_step_layout.dart';
import '../../application/save_payment_instructions.dart';
import '../../domain/payment_instructions.dart';
import '../../domain/workspace.dart';
import '../../providers/workspace_providers.dart';
import 'payment_instructions_fields.dart';
import 'setup_draft_frame.dart';

class SetupPaymentMethodsStep extends ConsumerStatefulWidget {
  const SetupPaymentMethodsStep({
    super.key,
    required this.workspace,
    required this.checkout,
  });

  final Workspace workspace;

  /// How the money feature draws a member's checkout.
  final Widget Function(
    PaymentInstructions instructions, {
    required bool payOnline,
  })
  checkout;

  @override
  ConsumerState<SetupPaymentMethodsStep> createState() =>
      _SetupPaymentMethodsStepState();
}

class _SetupPaymentMethodsStepState
    extends ConsumerState<SetupPaymentMethodsStep> {
  late final _stored = PaymentInstructions.fromDb(
    widget.workspace.paymentInstructions,
  );
  late final _draft = PaymentInstructionsDraft(_stored);
  final _busy = ValueNotifier<bool>(false);

  /// The fields as the step's draft on the server.
  late final _kept = SetupDraftForm(
    edits: _draft.changes,
    answers: () => _draft.value.toDb(),
    fill: (answers) => _draft.fill(
      answers == null ? _stored : PaymentInstructions.fromDb(answers),
    ),
  );

  @override
  void dispose() {
    _draft.dispose();
    _busy.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    _busy.value = true;
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'setup payment instructions failed',
      errorText: l10n.setupPaymentsSaveFailed,
      action: () => ref
          .read(savePaymentInstructionsProvider)
          .save(widget.workspace.id, _draft.value),
    );
    // The instructions live on the workspace row: read it again either way.
    ref.invalidate(myWorkspacesProvider);
    if (!mounted) return;
    _busy.value = false;
    if (!ok) return;
    AppSnack.success(context, l10n.workspaceSettingsSaved);
    await _kept.applied();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SetupStepLayout(
      form: SetupDraftFrame(
        workspaceId: widget.workspace.id,
        step: 'payment_methods',
        form: _kept,
        child: ValueListenableBuilder<bool>(
          valueListenable: _busy,
          builder: (context, busy, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.setupStepHint('payment_methods')),
              const SizedBox(height: AppSpacing.lg),
              PaymentInstructionsFields(
                draft: _draft,
                countryCode: widget.workspace.countryCode,
                enabled: !busy,
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton(
                  key: const ValueKey('setup-payments-save'),
                  onPressed: busy ? null : _save,
                  child: Text(l10n.commonSave),
                ),
              ),
            ],
          ),
        ),
      ),
      preview: ListenableBuilder(
        listenable: _draft.changes,
        builder: (context, _) {
          final value = _draft.value;
          return Column(
            key: const ValueKey('setup-payments-preview'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                value.isEmpty
                    ? l10n.setupPaymentsPreviewEmpty
                    : l10n.setupPaymentsPreviewNote,
                key: ValueKey(
                  'setup-payments-preview-${value.isEmpty ? 'empty' : 'note'}',
                ),
              ),
              if (!value.isEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                // A picture of the statement's card: nothing in it acts.
                IgnorePointer(child: widget.checkout(value, payOnline: false)),
              ],
            ],
          );
        },
      ),
    );
  }
}
