// SPDX-License-Identifier: 0BSD
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/files/file_names.dart';
import '../../../../core/files/file_saver.dart';
import '../../../../core/share/file_sharer.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/invoice.dart';
import '../../domain/invoice_pdf.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../providers/money_providers.dart';

/// The invoice ARCHIVE (0060): every member sees their own invoices,
/// admins see the workspace's. Each row downloads or shares the signed
/// PDF; issuing is owner-only (admins via the adminInvoicing
/// delegation). Invoices are immutable — there is no edit or delete
/// anywhere, by design.
class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

  Future<pw.Font> _font(String asset) async =>
      pw.Font.ttf(await rootBundle.load(asset));

  Future<({List<int> bytes, String fileName})> _pdf(
    BuildContext context,
    Invoice invoice,
  ) async {
    // Everything context-derived is captured BEFORE the awaits.
    final l10n = AppLocalizations.of(context);
    final currency = NumberFormat.simpleCurrency(name: invoice.currency);
    final dateLabel = DateFormat.yMMMd(
      Localizations.maybeLocaleOf(context)?.toString(),
    ).format(invoice.issuedAt);
    final bytes = await buildInvoicePdf(
      invoice: invoice,
      strings: InvoicePdfStrings(
        invoiceTitle: l10n?.invoicePdfTitle ?? 'Invoice',
        issuedOn: l10n?.invoicePdfIssuedOn ?? 'Issued on',
        issuedBy: l10n?.invoicePdfIssuedBy ?? 'Issued by',
        billedTo: l10n?.invoicePdfBilledTo ?? 'Billed to',
        total: l10n?.invoicePdfTotal ?? 'Total',
        signature:
            l10n?.invoicePdfSignature ?? 'Digital signature (SHA-256)',
      ),
      money: (cents) => currency.format(cents / 100),
      dateLabel: dateLabel,
      baseFont: await _font('assets/fonts/Roboto-Regular.ttf'),
      boldFont: await _font('assets/fonts/Roboto-Bold.ttf'),
    );
    return (
      bytes: bytes,
      fileName: '${safeFileSlug(invoice.number)}.pdf',
    );
  }

  Future<void> _download(
    BuildContext context,
    WidgetRef ref,
    Invoice invoice,
  ) async {
    final l10n = AppLocalizations.of(context);
    await runGuarded(
      context,
      domain: 'money',
      message: 'invoice download failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        final pdf = await _pdf(context, invoice);
        final path = await ref.read(fileSaverProvider)(
          bytes: Uint8List.fromList(pdf.bytes),
          fileName: pdf.fileName,
        );
        if (!context.mounted) return;
        if (path == null) {
          AppSnack.error(context, l10n?.commonSaveFailed ?? 'Could not save.');
        } else {
          AppSnack.success(
            context,
            l10n?.commonSavedTo(path) ?? 'Saved to $path',
          );
        }
      },
    );
  }

  Future<void> _share(
    BuildContext context,
    WidgetRef ref,
    Invoice invoice,
  ) async {
    final l10n = AppLocalizations.of(context);
    await runGuarded(
      context,
      domain: 'money',
      message: 'invoice share failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        final pdf = await _pdf(context, invoice);
        await ref.read(fileSharerProvider)(
          bytes: Uint8List.fromList(pdf.bytes),
          fileName: pdf.fileName,
          mimeType: 'application/pdf',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final invoicesAsync = ref.watch(invoicesProvider);
    final me = ref.watch(myMemberProvider).value;
    final features = ref.watch(enabledFeaturesSyncProvider);
    // Owner always; admins only with the delegation flag — the server
    // re-checks both.
    final canIssue = me != null &&
        (me.actsAsOwner ||
            (me.canAdminister &&
                features.contains(WorkspaceFeature.adminInvoicing)));
    final showMemberNames = me?.canAdminister ?? false;
    final dateFormat = DateFormat.yMMMd(
      Localizations.maybeLocaleOf(context)?.toString(),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.invoicesTitle ?? 'Invoices')),
      floatingActionButton: canIssue
          ? FloatingActionButton.extended(
              key: const ValueKey('invoice-create-button'),
              onPressed: () => _createSheet(context, ref),
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text(l10n?.invoiceCreate ?? 'New invoice'),
            )
          : null,
      body: switch (invoicesAsync) {
        AsyncData(value: final invoices) => invoices.isEmpty
            ? EmptyState(
                icon: Icons.receipt_long_outlined,
                title: l10n?.invoicesEmpty ?? 'No invoices yet.',
              )
            : ListView.builder(
                padding: AppSpacing.mdAll,
                itemCount: invoices.length,
                itemBuilder: (context, index) {
                  final invoice = invoices[index];
                  final currency =
                      NumberFormat.simpleCurrency(name: invoice.currency);
                  final rowTitle = '${invoice.number} · ${invoice.title}';
                  return Card(
                    child: ListTile(
                      key: ValueKey('invoice-${invoice.id}'),
                      title: Text(rowTitle),
                      subtitle: Text([
                        dateFormat.format(invoice.issuedAt),
                        if (showMemberNames) invoice.memberName,
                        currency.format(invoice.totalCents / 100),
                      ].join(' · ')),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: ValueKey('invoice-download-${invoice.id}'),
                            tooltip: l10n?.invoiceDownload ?? 'Download PDF',
                            icon: const Icon(Icons.download_outlined),
                            onPressed: () =>
                                _download(context, ref, invoice),
                          ),
                          IconButton(
                            key: ValueKey('invoice-share-${invoice.id}'),
                            tooltip: l10n?.invoiceShare ?? 'Share PDF',
                            icon: const Icon(Icons.share_outlined),
                            onPressed: () => _share(context, ref, invoice),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        AsyncError() => Center(
            child: Text(
              l10n?.workspaceGenericError ??
                  'Something went wrong. Please try again.',
            ),
          ),
        _ => const LoadingView(),
      },
    );
  }

  Future<void> _createSheet(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final members = (await ref.read(workspaceMembersProvider.future))
        .where((m) => m.status == MemberStatus.active && !m.isKiosk)
        .toList();
    final names = await ref.read(memberNamesProvider.future);
    if (!context.mounted) return;

    final result = await showModalBottomSheet<
        ({String memberId, String title, List<InvoiceLine> lines})>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _InvoiceForm(
        l10n: l10n,
        members: [
          for (final member in members)
            (id: member.id, name: names[member.id] ?? ''),
        ],
      ),
    );
    if (result == null || !context.mounted) return;

    if (!await runGuarded(
      context,
      domain: 'money',
      message: 'invoice issue failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => ref.read(moneyRepositoryProvider).createInvoice(
            workspaceId: workspace.id,
            memberId: result.memberId,
            title: result.title,
            lines: result.lines,
          ),
    )) {
      return;
    }
    ref.invalidate(invoicesProvider);
    if (!context.mounted) return;
    AppSnack.success(context, l10n?.invoiceIssued ?? 'Invoice issued.');
  }
}

/// The issue form: member, title, dynamic label+amount lines. Amounts
/// parse as major units ("12.50" → 1250 cents).
class _InvoiceForm extends StatefulWidget {
  const _InvoiceForm({required this.l10n, required this.members});

  final AppLocalizations? l10n;
  final List<({String id, String name})> members;

  @override
  State<_InvoiceForm> createState() => _InvoiceFormState();
}

class _InvoiceFormState extends State<_InvoiceForm> {
  String? _memberId;
  final _title = TextEditingController();
  final _lines = <({TextEditingController label, TextEditingController amount})>[
    (label: TextEditingController(), amount: TextEditingController()),
  ];

  @override
  void dispose() {
    _title.dispose();
    for (final line in _lines) {
      line.label.dispose();
      line.amount.dispose();
    }
    super.dispose();
  }

  int? _parseCents(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    final value = double.tryParse(normalized);
    if (value == null || value < 0) return null;
    return (value * 100).round();
  }

  void _submit() {
    final l10n = widget.l10n;
    final memberId = _memberId;
    final title = _title.text.trim();
    final lines = <InvoiceLine>[];
    for (final line in _lines) {
      final label = line.label.text.trim();
      final cents = _parseCents(line.amount.text);
      if (label.isEmpty && line.amount.text.trim().isEmpty) continue;
      if (label.isEmpty || cents == null) {
        AppSnack.error(
          context,
          l10n?.invoiceLineInvalid ?? 'Every line needs a label and amount.',
        );
        return;
      }
      lines.add(InvoiceLine(label: label, amountCents: cents));
    }
    if (memberId == null || title.isEmpty || lines.isEmpty) {
      AppSnack.error(
        context,
        l10n?.invoiceFormIncomplete ??
            'Pick a member, a title and at least one line.',
      );
      return;
    }
    Navigator.of(context)
        .pop((memberId: memberId, title: title, lines: lines));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return SheetShell(
      title: l10n?.invoiceCreate ?? 'New invoice',
      children: [
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: const ValueKey('invoice-member-dropdown'),
          initialValue: _memberId,
          items: [
            for (final member in widget.members)
              DropdownMenuItem(
                value: member.id,
                child: Text(member.name),
              ),
          ],
          onChanged: (value) => setState(() => _memberId = value),
          decoration: InputDecoration(
            labelText: l10n?.invoiceMemberLabel ?? 'Member',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('invoice-title-field'),
          controller: _title,
          decoration: InputDecoration(
            labelText: l10n?.invoiceTitleLabel ?? 'Title',
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _lines.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    key: ValueKey('invoice-line-label-$i'),
                    controller: _lines[i].label,
                    decoration: InputDecoration(
                      labelText: l10n?.invoiceLineLabel ?? 'Item',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: ValueKey('invoice-line-amount-$i'),
                    controller: _lines[i].amount,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      labelText: l10n?.invoiceLineAmount ?? 'Amount',
                    ),
                  ),
                ),
              ],
            ),
          ),
        TextButton.icon(
          key: const ValueKey('invoice-add-line'),
          onPressed: () => setState(() => _lines.add((
                label: TextEditingController(),
                amount: TextEditingController(),
              ))),
          icon: const Icon(Icons.add),
          label: Text(l10n?.invoiceAddLine ?? 'Add line'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey('invoice-submit'),
          onPressed: _submit,
          child: Text(l10n?.invoiceIssue ?? 'Issue invoice'),
        ),
      ],
    );
  }
}
