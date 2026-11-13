// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3883 — opening the issuing gate of a workspace whose country routes every
// invoice through its national channel: the platform must accept one of its
// documents first, and nothing can be issued before that. The card sends a
// sandbox test document (a member's proforma of the current month with a
// test number, nothing issued or booked), says where the latest one stands,
// and asks the platform for its verdict. Shown only where the configured
// channel takes a test document.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/einvoice_receipt.dart';
import '../../domain/einvoice_test_document.dart';
import '../../providers/money_providers.dart';
import '../einvoice_test_document.dart';

class EInvoiceTestCard extends ConsumerStatefulWidget {
  const EInvoiceTestCard({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  ConsumerState<EInvoiceTestCard> createState() => _EInvoiceTestCardState();
}

class _EInvoiceTestCardState extends ConsumerState<EInvoiceTestCard> {
  late Future<EInvoiceTestState> _state = _read();
  String? _memberId;
  bool _busy = false;

  Future<EInvoiceTestState> _read() => ref
      .read(eInvoiceTransmissionsProvider)
      .fetchEInvoiceTest(widget.workspaceId);

  void _refresh() => setState(() => _state = _read());

  Future<void> _send(String memberId) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    String? message;
    await runGuarded(
      context,
      domain: 'money',
      message: 'e-invoice test document failed',
      errorText: l10n.einvoiceTestFailed,
      action: () async {
        final file = await buildEInvoiceTestDocument(ref, memberId: memberId);
        if (file == null) {
          message = l10n.einvoiceTestNothingToInvoice;
          return;
        }
        final sent = await ref
            .read(eInvoiceTransmissionsProvider)
            .sendEInvoiceTest(
              workspaceId: widget.workspaceId,
              fileName: file.fileName,
              bytes: file.bytes,
            );
        message = _sentence(l10n, sent);
      },
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (message != null) AppSnack.info(context, message!);
    _refresh();
  }

  Future<void> _ask(String transmissionId) async {
    setState(() => _busy = true);
    await runGuarded(
      context,
      domain: 'money',
      message: 'e-invoice test verdict request failed',
      errorText: context.l10n.eInvoiceReceiptFailed,
      action: () => requestEInvoiceReceipt(
        ref,
        workspaceId: widget.workspaceId,
        transmissionId: transmissionId,
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _refresh();
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
  Widget build(BuildContext context) => FutureBuilder<EInvoiceTestState>(
    future: _state,
    builder: (context, snapshot) {
      final state = snapshot.data;
      if (state == null || !state.available) return const SizedBox.shrink();
      final l10n = context.l10n;
      final members = [
        for (final m
            in ref.watch(workspaceMembersProvider).value ?? const <Member>[])
          if (m.status == MemberStatus.active) m,
      ];
      final names = ref.watch(memberNamesProvider).value ?? const {};
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
                    onPressed: _busy ? null : () => _ask(state.transmissionId),
                    child: Text(l10n.eInvoiceReceiptAsk),
                  ),
                ),
              if (state.canSend) ...[
                const FormGap.small(),
                DropdownButtonFormField<String>(
                  key: const ValueKey('einvoice-test-member'),
                  initialValue: _memberId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.einvoiceTestMember,
                  ),
                  items: [
                    for (final m in members)
                      DropdownMenuItem(
                        value: m.id,
                        child: Text(
                          names[m.id] ?? '',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (id) => setState(() => _memberId = id),
                ),
                const FormGap.small(),
                FilledButton(
                  key: const ValueKey('einvoice-test-send'),
                  onPressed: _busy || _memberId == null
                      ? null
                      : () => _send(_memberId!),
                  child: Text(l10n.einvoiceTestSend),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
