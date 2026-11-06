// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../application/einvoice_resolve.dart';
import '../../domain/einvoice_resolution.dart';

/// #3335 — the person who may issue invoices says what became of a submission
/// whose outcome is unknown: the platform has the document, refused the
/// upload, or never received it — with the reason and the platform record
/// they checked. Nothing is sent by it; the server records who, why and
/// on what evidence, and a second resolution changes nothing.
Future<void> showEInvoiceResolveDialog(
  BuildContext context, {
  required String workspaceId,
  required String transmissionId,
}) => showDialog<void>(
  context: context,
  builder: (_) => _ResolveDialog(
    workspaceId: workspaceId,
    transmissionId: transmissionId,
  ),
);

class _ResolveDialog extends ConsumerStatefulWidget {
  const _ResolveDialog({
    required this.workspaceId,
    required this.transmissionId,
  });

  final String workspaceId;
  final String transmissionId;

  @override
  ConsumerState<_ResolveDialog> createState() => _ResolveDialogState();
}

/// Everything the dialog edits, held in one value so one place changes it.
class _Draft {
  const _Draft({
    this.resolution = EInvoiceResolution.accepted,
    this.documentRejected = false,
    this.problem,
    this.saving = false,
  });

  final EInvoiceResolution resolution;
  final bool documentRejected;
  final EInvoiceResolutionProblem? problem;
  final bool saving;

  _Draft copyWith({
    EInvoiceResolution? resolution,
    bool? documentRejected,
    bool? saving,
    EInvoiceResolutionProblem? problem,
    bool clearProblem = false,
  }) => _Draft(
    resolution: resolution ?? this.resolution,
    documentRejected: documentRejected ?? this.documentRejected,
    problem: clearProblem ? null : (problem ?? this.problem),
    saving: saving ?? this.saving,
  );
}

class _ResolveDialogState extends ConsumerState<_ResolveDialog> {
  final _reason = TextEditingController();
  final _evidence = TextEditingController();
  _Draft _draft = const _Draft();

  void _edit(_Draft Function(_Draft) change) =>
      setState(() => _draft = change(_draft));

  @override
  void dispose() {
    _reason.dispose();
    _evidence.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final problem = einvoiceResolutionProblem(
      reason: _reason.text,
      evidence: _evidence.text,
    );
    if (problem != null) {
      _edit((d) => d.copyWith(problem: problem));
      return;
    }
    _edit((d) => d.copyWith(saving: true));
    EInvoiceResolveResult? result;
    await runGuarded(
      context,
      domain: 'money',
      message: 'e-invoice resolution failed',
      errorText: l10n.eInvoiceResolveError,
      action: () async {
        result = await resolveEInvoice(
          ref,
          workspaceId: widget.workspaceId,
          transmissionId: widget.transmissionId,
          resolution: _draft.resolution,
          reason: _reason.text,
          evidence: _evidence.text,
          documentRejected: _draft.documentRejected,
        );
      },
    );
    if (!mounted) return;
    final got = result;
    if (got == null) {
      _edit((d) => d.copyWith(saving: false));
      return;
    }
    // Close first, then tell: the dialog is not the place for a toast.
    Navigator.of(context).pop();
    if (!context.mounted) return;
    if (got.resolved) {
      AppSnack.success(context, l10n.eInvoiceResolveDone);
    } else if (got.error == 'already_settled') {
      AppSnack.info(context, l10n.eInvoiceResolveAlready);
    } else {
      AppSnack.error(context, l10n.eInvoiceResolveError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final choices = <(EInvoiceResolution, String)>[
      (EInvoiceResolution.accepted, l10n.eInvoiceResolveAccepted),
      (EInvoiceResolution.rejected, l10n.eInvoiceResolveRejected),
      (EInvoiceResolution.failed, l10n.eInvoiceResolveFailed),
    ];
    return AlertDialog(
      key: const ValueKey('einvoice-resolve-dialog'),
      title: Row(
        children: [
          Expanded(child: Text(l10n.eInvoiceResolveTitle)),
          HelpDot(
            l10n.helpTopicEinvoice,
            anchor: HelpAnchor.einvoiceSend,
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.eInvoiceResolveIntro),
            const FormGap(),
            RadioGroup<EInvoiceResolution>(
              key: const ValueKey('einvoice-resolve-choice'),
              groupValue: _draft.resolution,
              onChanged: (value) {
                if (value != null && !_draft.saving) {
                  _edit((d) => d.copyWith(resolution: value));
                }
              },
              child: Column(
                children: [
                  for (final (value, label) in choices)
                    RadioListTile<EInvoiceResolution>(
                      key: ValueKey('einvoice-resolve-${value.name}'),
                      value: value,
                      title: Text(label),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            if (_draft.resolution == EInvoiceResolution.accepted)
              SwitchListTile(
                key: const ValueKey('einvoice-resolve-document-rejected'),
                value: _draft.documentRejected,
                onChanged: _draft.saving
                    ? null
                    : (value) =>
                          _edit((d) => d.copyWith(documentRejected: value)),
                title: Text(l10n.eInvoiceResolveDocumentRejected),
                contentPadding: EdgeInsets.zero,
              ),
            const FormGap(),
            AppTextField(
              key: const ValueKey('einvoice-resolve-reason'),
              controller: _reason,
              label: l10n.eInvoiceResolveReason,
              maxLength: einvoiceReasonWidth,
              maxLines: 2,
              enabled: !_draft.saving,
              error: _draft.problem == EInvoiceResolutionProblem.reason
                  ? l10n.eInvoiceResolveReasonRequired
                  : null,
              onChanged: (_) => _edit((d) => d.copyWith(clearProblem: true)),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              key: const ValueKey('einvoice-resolve-evidence'),
              controller: _evidence,
              label: l10n.eInvoiceResolveEvidence,
              maxLength: einvoiceEvidenceWidth,
              maxLines: 3,
              enabled: !_draft.saving,
              error: _draft.problem == EInvoiceResolutionProblem.evidence
                  ? l10n.eInvoiceResolveEvidenceRequired
                  : null,
              onChanged: (_) => _edit((d) => d.copyWith(clearProblem: true)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('einvoice-resolve-cancel'),
          onPressed: _draft.saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('einvoice-resolve-submit'),
          onPressed: _draft.saving ? null : _submit,
          child: Text(l10n.eInvoiceResolveSubmit),
        ),
      ],
    );
  }
}
