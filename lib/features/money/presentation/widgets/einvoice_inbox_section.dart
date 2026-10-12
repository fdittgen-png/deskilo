// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/files/file_picker.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/money/money_text.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../application/einvoice_inbox.dart';
import '../../domain/einvoice_inbox.dart';
import '../../domain/inbound_einvoice.dart';
import '../../providers/einvoice_inbox_providers.dart';

/// #2358 — the supplier invoices that reached the space: add a UBL or CII
/// file, then match each to an expense that was filed, or reject it with a
/// reason. The server decides who may (approveExpenses) and keeps the file.
class EInvoiceInboxSection extends ConsumerWidget {
  const EInvoiceInboxSection({required this.workspaceId, super.key});

  final String workspaceId;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final file = await ref.read(filePickerProvider)(
      XTypeGroup(
        label: l10n.workspaceXmlFileTypeLabel,
        extensions: const ['xml'],
        mimeTypes: const ['application/xml', 'text/xml'],
      ),
    );
    if (file == null) return;
    final xml = utf8.decode(await file.readAsBytes());
    if (!context.mounted) return;
    ReceivedEInvoice? received;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'supplier e-invoice receive failed',
      errorText: l10n.eInvoiceInboxRefused,
      action: () async => received = await ref
          .read(eInvoiceInboxCommandProvider)
          .receive(workspaceId, xml),
    );
    if (!context.mounted) return;
    final got = received;
    if (!ok || got == null) return;
    final problem = got.problem;
    if (problem != null) {
      AppSnack.error(
        context,
        problem.problem == InboundEInvoiceProblem.missingField
            ? l10n.eInvoiceInboxMissingField(problem.field)
            : l10n.eInvoiceInboxUnreadable,
      );
      return;
    }
    final invoice = got.invoice!;
    ref.invalidate(eInvoiceInboxProvider(workspaceId));
    AppSnack.success(
      context,
      l10n.eInvoiceInboxAdded(invoice.number, invoice.supplierName),
    );
  }

  Future<void> _match(
    BuildContext context,
    WidgetRef ref,
    InboxDocument doc,
  ) async {
    final l10n = context.l10n;
    final command = ref.read(eInvoiceInboxCommandProvider);
    List<InboxCandidate> found = const [];
    if (!await runGuarded(
      context,
      domain: 'money',
      message: 'supplier e-invoice candidates failed',
      errorText: l10n.eInvoiceInboxRefused,
      action: () async => found = await command.candidates(doc.id),
    )) {
      return;
    }
    if (!context.mounted) return;
    final chosen = await showDialog<InboxCandidate>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.eInvoiceInboxMatch),
        children: [
          if (found.isEmpty)
            Padding(
              padding: AppSpacing.gutterAll,
              child: Text(l10n.eInvoiceInboxNoCandidate),
            ),
          for (final c in found)
            SimpleDialogOption(
              key: ValueKey('inbox-candidate-${c.eventId}'),
              onPressed: () => Navigator.of(ctx).pop(c),
              child: Text(
                '${c.filedOn} · ${c.category}'
                '${c.note.isEmpty ? '' : ' · ${c.note}'}',
              ),
            ),
        ],
      ),
    );
    if (chosen == null || !context.mounted) return;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'supplier e-invoice match failed',
      errorText: l10n.eInvoiceInboxRefused,
      action: () => command.match(doc.id, chosen.eventId),
    );
    if (!ok || !context.mounted) return;
    ref.invalidate(eInvoiceInboxProvider(workspaceId));
    AppSnack.success(context, l10n.eInvoiceInboxMatched);
  }

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    InboxDocument doc,
  ) async {
    final l10n = context.l10n;
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectDialog(),
    );
    if (text == null || !context.mounted) return;
    var done = false;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'supplier e-invoice reject failed',
      errorText: l10n.eInvoiceInboxRefused,
      action: () async => done = await ref
          .read(eInvoiceInboxCommandProvider)
          .reject(doc.id, text),
    );
    if (!context.mounted) return;
    if (ok && !done) {
      AppSnack.error(context, l10n.eInvoiceInboxReasonNeeded);
      return;
    }
    if (!ok) return;
    ref.invalidate(eInvoiceInboxProvider(workspaceId));
    AppSnack.success(context, l10n.eInvoiceInboxRejected);
  }

  String _status(BuildContext context, InboxDocument d) {
    final l10n = context.l10n;
    return switch (d.status) {
      InboxStatus.received => l10n.eInvoiceInboxStatusReceived,
      InboxStatus.matched => l10n.eInvoiceInboxStatusMatched,
      InboxStatus.rejected =>
        d.rejectReason.isEmpty
            ? l10n.eInvoiceInboxStatusRejected
            : '${l10n.eInvoiceInboxStatusRejected}: ${d.rejectReason}',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final inbox = ref.watch(eInvoiceInboxProvider(workspaceId));
    return Column(
      key: const ValueKey('einvoice-inbox'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.eInvoiceInboxTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.eInvoiceInboxIntro,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          key: const ValueKey('inbox-add'),
          onPressed: () => _add(context, ref),
          icon: const Icon(Icons.upload_file_outlined),
          label: Text(l10n.eInvoiceInboxAdd),
        ),
        const SizedBox(height: AppSpacing.sm),
        switch (inbox) {
          AsyncData(:final value) when value.isEmpty => Text(
            l10n.eInvoiceInboxEmpty,
            style: theme.textTheme.bodySmall,
          ),
          AsyncData(:final value) => Column(
            children: [
              for (final d in value)
                ListTile(
                  key: ValueKey('inbox-${d.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text('${d.supplierName} · ${d.number}'),
                  subtitle: Text(
                    '${d.issueDate} · '
                    '${minorToText(d.grossCents, d.currency)} ${d.currency}'
                    ' · ${_status(context, d)}',
                  ),
                  trailing: d.status != InboxStatus.received
                      ? null
                      : Wrap(
                          children: [
                            TextButton(
                              key: ValueKey('inbox-match-${d.id}'),
                              onPressed: () => _match(context, ref, d),
                              child: Text(l10n.eInvoiceInboxMatch),
                            ),
                            TextButton(
                              key: ValueKey('inbox-reject-${d.id}'),
                              onPressed: () => _reject(context, ref, d),
                              child: Text(l10n.eInvoiceInboxReject),
                            ),
                          ],
                        ),
                ),
            ],
          ),
          AsyncError() => Text(l10n.eInvoiceInboxRefused),
          _ => const LinearProgressIndicator(),
        },
      ],
    );
  }
}

/// Owns the reason's controller, so it is disposed with the dialog and not
/// while the dialog is still animating out.
class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.eInvoiceInboxReject),
      content: AppTextField(
        key: const ValueKey('inbox-reject-reason'),
        controller: _reason,
        label: l10n.eInvoiceInboxReason,
        autofocus: true,
        maxLength: 500,
      ),
      actions: [
        TextButton(
          key: const ValueKey('inbox-reject-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('inbox-reject-confirm'),
          onPressed: () => Navigator.of(context).pop(_reason.text),
          child: Text(l10n.eInvoiceInboxReject),
        ),
      ],
    );
  }
}
