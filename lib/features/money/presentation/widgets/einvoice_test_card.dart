// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3883 — opening the issuing gate of a workspace whose country routes every
// invoice through its national channel: the platform must accept one of its
// documents first, and nothing can be issued before that. The card sends a
// sandbox test document (the proforma of a member's month to invoice, with a
// test number: nothing issued or booked), says where the latest one stands,
// and asks the platform for its verdict. Shown only where the configured
// channel takes a test document.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/einvoice_receipt.dart';
import '../../domain/einvoice_gateway.dart';
import '../../providers/money_providers.dart';
import '../einvoice_test_document.dart';
import '../screens/money_view_data.dart';

class EInvoiceTestCard extends ConsumerStatefulWidget {
  const EInvoiceTestCard({super.key});

  @override
  ConsumerState<EInvoiceTestCard> createState() => _EInvoiceTestCardState();
}

class _EInvoiceTestCardState extends ConsumerState<EInvoiceTestCard> {
  Future<EInvoiceTestState>? _state;
  String? _memberId;
  bool _busy = false;

  Future<EInvoiceTestState> _read(String workspaceId) =>
      ref.read(eInvoiceTransmissionsProvider).fetchEInvoiceTest(workspaceId);

  /// Runs [action] with the card busy, then reads the latest test again.
  Future<void> _run(
    String workspaceId,
    String message,
    String errorText,
    Future<String?> Function() action,
  ) async {
    setState(() => _busy = true);
    String? said;
    await runGuarded(
      context,
      domain: 'money',
      message: message,
      errorText: errorText,
      action: () async => said = await action(),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _state = _read(workspaceId);
    });
    if (said != null) AppSnack.info(context, said!);
  }

  Future<String?> _send(String workspaceId, String period) async {
    final l10n = context.l10n;
    final file = await buildEInvoiceTestDocument(
      ref,
      memberId: _memberId!,
      period: period,
    );
    if (file == null) return l10n.einvoiceTestNothingToInvoice;
    final sent = await ref
        .read(eInvoiceTransmissionsProvider)
        .sendEInvoiceTest(
          workspaceId: workspaceId,
          fileName: file.fileName,
          bytes: file.bytes,
        );
    return _sentence(l10n, sent);
  }

  static String _sentence(AppLocalizations l10n, EInvoiceTestSent sent) =>
      switch (sent.refusal) {
        EInvoiceTestRefusal.none => l10n.einvoiceTestSent,
        EInvoiceTestRefusal.pending => l10n.einvoiceTestPending,
        EInvoiceTestRefusal.sandboxMissing => l10n.einvoiceTestSandboxMissing(
          sent.missing.join(', '),
        ),
        EInvoiceTestRefusal.sandboxNotDocumented =>
          l10n.einvoiceTestSandboxElsewhere,
        EInvoiceTestRefusal.unavailable => l10n.einvoiceTestUnavailable,
        EInvoiceTestRefusal.notAllowed => l10n.einvoiceTestNotAllowed,
        EInvoiceTestRefusal.failed => l10n.einvoiceTestFailed,
      };

  @override
  Widget build(BuildContext context) {
    final workspaceId = MoneyViewData.gates(ref).workspace?.id;
    if (workspaceId == null) return const SizedBox.shrink();
    final future = _state ??= _read(workspaceId);
    return FutureBuilder<EInvoiceTestState>(
      future: future,
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state == null || !state.available) return const SizedBox.shrink();
        final l10n = context.l10n;
        return Card(
          key: const ValueKey('einvoice-test-card'),
          child: Padding(
            padding: AppSpacing.lgAll,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.einvoiceTestTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const FormGap.small(),
                Text(l10n.einvoiceTestIntro),
                const FormGap.small(),
                Text(switch (state.verdict) {
                  EInvoiceTestVerdict.none => l10n.einvoiceTestNone,
                  EInvoiceTestVerdict.awaiting => l10n.einvoiceTestAwaiting,
                  EInvoiceTestVerdict.accepted => l10n.einvoiceTestAccepted,
                  EInvoiceTestVerdict.rejected => l10n.einvoiceTestRejected,
                }, key: ValueKey('einvoice-test-${state.verdict.name}')),
                if (state.verdict == EInvoiceTestVerdict.awaiting &&
                    state.transmissionId.isNotEmpty)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      key: const ValueKey('einvoice-test-ask'),
                      onPressed: _busy
                          ? null
                          : () => _run(
                              workspaceId,
                              'e-invoice test verdict request failed',
                              l10n.eInvoiceReceiptFailed,
                              () async {
                                await requestEInvoiceReceipt(
                                  ref,
                                  workspaceId: workspaceId,
                                  transmissionId: state.transmissionId,
                                );
                                return null;
                              },
                            ),
                      child: Text(l10n.eInvoiceReceiptAsk),
                    ),
                  ),
                if (state.canSend) ...[
                  const FormGap.small(),
                  _sender(context, workspaceId),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// The member picker and the send: the month's members with something to
  /// invoice (their proforma is never empty).
  Widget _sender(BuildContext context, String workspaceId) {
    final l10n = context.l10n;
    return switch (ref.watch(invoicingOverviewProvider)) {
      AsyncData(value: final overview) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            key: const ValueKey('einvoice-test-member'),
            initialValue: _memberId,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.einvoiceTestMember),
            items: [
              for (final entry in overview.toInvoice)
                DropdownMenuItem(
                  value: entry.memberId,
                  child: Text(entry.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (id) => setState(() => _memberId = id),
          ),
          const FormGap.small(),
          FilledButton(
            key: const ValueKey('einvoice-test-send'),
            onPressed: _busy || _memberId == null
                ? null
                : () => _run(
                    workspaceId,
                    'e-invoice test document failed',
                    l10n.einvoiceTestFailed,
                    () => _send(workspaceId, overview.period),
                  ),
            child: Text(l10n.einvoiceTestSend),
          ),
        ],
      ),
      AsyncError(:final error) => ReadFailureBanner(
        error: error,
        onRetry: () => ref.invalidate(invoicingOverviewProvider),
      ),
      _ => const LoadingView(),
    };
  }
}
