// SPDX-License-Identifier: 0BSD
import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/files/file_names.dart';
import '../../../../core/files/file_saver.dart';
import '../../../../core/share/file_sharer.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/invoice.dart';
import '../../domain/invoice_pdf.dart';
import '../../domain/invoice_ubl.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../providers/money_providers.dart';
import '../invoice_line_text.dart';

/// The invoice ARCHIVE (0060): every member sees their own invoices,
/// admins see the workspace's. Each row downloads or shares the signed
/// PDF; issuing is owner-only (admins via the adminInvoicing
/// delegation). Invoices are immutable — there is no edit or delete
/// anywhere, by design.
class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

/// Archive sort orders (field request: sort and filter by member and
/// period).
enum _InvoiceSort { newest, member, period }

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  String? _filterMemberId;
  String? _filterPeriod;
  _InvoiceSort _sort = _InvoiceSort.newest;

  Future<pw.Font> _font(String asset) async =>
      pw.Font.ttf(await rootBundle.load(asset));

  Future<({List<int> bytes, String fileName})> _pdf(
    BuildContext context,
    Invoice invoice,
  ) async {
    // Everything context-derived is captured BEFORE the awaits.
    final l10n = AppLocalizations.of(context);
    final currency = NumberFormat.simpleCurrency(name: invoice.currency);
    final dateFormat = DateFormat.yMMMd(
      Localizations.maybeLocaleOf(context)?.toString(),
    );
    final dateLabel = dateFormat.format(invoice.issuedAt);
    final voidedAt = invoice.voidedAt;
    final voidedLabel = voidedAt == null
        ? ''
        : '${l10n?.invoicePdfVoided ?? 'ERRONEOUS — voided on'} '
            '${dateFormat.format(voidedAt)}';
    final bytes = await buildInvoicePdf(
      invoice: invoice,
      lineText: (line) => invoiceLineText(l10n, line),
      activityText: (entry) => annexEntryText(l10n, entry),
      strings: InvoicePdfStrings(
        invoiceTitle: l10n?.invoicePdfTitle ?? 'Invoice',
        issuedOn: l10n?.invoicePdfIssuedOn ?? 'Issued on',
        issuedBy: l10n?.invoicePdfIssuedBy ?? 'Issued by',
        billedTo: l10n?.invoicePdfBilledTo ?? 'Billed to',
        total: l10n?.invoiceBalance ?? 'Balance due',
        signature:
            l10n?.invoicePdfSignature ?? 'Digital signature (SHA-256)',
        voided: voidedLabel,
        replaces: l10n?.invoicePdfReplaces ?? 'Replaces',
        description: l10n?.invoicePdfDescription ?? 'Description',
        charges: l10n?.invoicePdfCharges ?? 'Charges',
        payments: l10n?.invoicePdfPayments ?? 'Payments',
        annex: l10n?.invoicePdfAnnex ?? 'Annex — details',
        attendance: l10n?.invoicePdfAttendance ?? 'Check-ins',
        activity: l10n?.invoicePdfActivity ?? 'Bookings & payments',
        reserved: l10n?.invoicePdfReserved ?? 'reserved',
        page: l10n?.invoicePdfPage ?? 'Page',
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

  /// Tags [invoice] erroneous (0061) after an explicit confirm — the
  /// stamp is one-way, so the dialog says so.
  Future<void> _void(
    BuildContext context,
    WidgetRef ref,
    Invoice invoice,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.invoiceVoidAction ?? 'Mark erroneous'),
        content: Text(
          l10n?.invoiceVoidConfirm(invoice.number) ??
              'Mark invoice ${invoice.number} as erroneous? '
                  'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n?.commonCancel ?? 'Cancel'),
          ),
          FilledButton(
            key: const ValueKey('invoice-void-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n?.invoiceVoidAction ?? 'Mark erroneous'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    if (!await runGuarded(
      context,
      domain: 'money',
      message: 'invoice void failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () =>
          ref.read(moneyRepositoryProvider).voidInvoice(invoice.id),
    )) {
      return;
    }
    ref.invalidate(invoicesProvider);
    if (!context.mounted) return;
    AppSnack.success(
      context,
      l10n?.invoiceVoided ?? 'Invoice marked as erroneous.',
    );
  }

  /// Records a payment reminder (0066) and hands the invoice PDF to
  /// the share sheet with a localized reminder message — mail,
  /// WhatsApp, whatever the device offers.
  Future<void> _remind(
    BuildContext context,
    WidgetRef ref,
    Invoice invoice,
  ) async {
    final l10n = AppLocalizations.of(context);
    final currency = NumberFormat.simpleCurrency(name: invoice.currency);
    final message = l10n?.invoiceReminderMessage(
          invoice.number,
          currency.format(invoice.totalCents / 100),
        ) ??
        'Friendly reminder: invoice ${invoice.number} — balance due '
            '${currency.format(invoice.totalCents / 100)}.';
    if (!await runGuarded(
      context,
      domain: 'money',
      message: 'invoice reminder failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        // PDF first — it captures its context-derived values before any
        // await (use_build_context_synchronously).
        final pdf = await _pdf(context, invoice);
        await ref.read(moneyRepositoryProvider).remindInvoice(invoice.id);
        await ref.read(fileSharerProvider)(
          bytes: Uint8List.fromList(pdf.bytes),
          fileName: pdf.fileName,
          mimeType: 'application/pdf',
          text: message,
        );
      },
    )) {
      return;
    }
    ref.invalidate(invoiceRemindersProvider);
    if (!context.mounted) return;
    AppSnack.success(
        context, l10n?.invoiceReminded ?? 'Reminder recorded.');
  }

  /// EN 16931 e-invoice (0066): UBL 2.1 XML for EU workspaces —
  /// downloaded to Downloads or handed to the share sheet.
  Future<void> _eInvoice(
    BuildContext context,
    WidgetRef ref,
    Invoice invoice, {
    required String countryCode,
    required bool share,
  }) async {
    final l10n = AppLocalizations.of(context);
    await runGuarded(
      context,
      domain: 'money',
      message: 'e-invoice export failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        final xml = buildInvoiceUbl(
          invoice: invoice,
          countryCode: countryCode,
          lineText: (line) => invoiceLineText(l10n, line),
        );
        final bytes = Uint8List.fromList(utf8.encode(xml));
        final fileName = '${safeFileSlug(invoice.number)}.xml';
        if (share) {
          await ref.read(fileSharerProvider)(
            bytes: bytes,
            fileName: fileName,
            mimeType: 'application/xml',
          );
          return;
        }
        final path = await ref.read(fileSaverProvider)(
          bytes: bytes,
          fileName: fileName,
        );
        if (!context.mounted) return;
        if (path == null) {
          AppSnack.error(
              context, l10n?.commonSaveFailed ?? 'Could not save.');
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final invoicesAsync = ref.watch(invoicesProvider);
    final reminders =
        ref.watch(invoiceRemindersProvider).value ?? const {};
    final countryCode =
        ref.watch(currentWorkspaceProvider).value?.countryCode ?? '';
    // 2014/55/EU: the e-invoice affordance shows for EU workspaces.
    final isEu = isEuCountry(countryCode);
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
            : Builder(builder: (context) {
                // An invoice already replaced cannot be replaced again —
                // corrections form a chain, never a fork (0061).
                final replacedIds = {
                  for (final invoice in invoices)
                    if (invoice.replacesInvoiceId != null)
                      invoice.replacesInvoiceId!,
                };
                // Filter options come from the ARCHIVE itself: member
                // names are the invoices' snapshots (departed members
                // keep working), periods the distinct issued months.
                final memberOptions = <String, String>{};
                for (final invoice in invoices) {
                  memberOptions.putIfAbsent(
                      invoice.memberId, () => invoice.memberName);
                }
                final periodOptions = {
                  for (final invoice in invoices) ?invoice.period,
                }.toList()
                  ..sort((a, b) => b.compareTo(a));
                final visible = [
                  for (final invoice in invoices)
                    if ((_filterMemberId == null ||
                            invoice.memberId == _filterMemberId) &&
                        (_filterPeriod == null ||
                            invoice.period == _filterPeriod))
                      invoice,
                ]..sort((a, b) => switch (_sort) {
                    _InvoiceSort.newest =>
                      b.issuedAt.compareTo(a.issuedAt),
                    _InvoiceSort.member => a.memberName
                                .toLowerCase()
                                .compareTo(b.memberName.toLowerCase()) !=
                            0
                        ? a.memberName
                            .toLowerCase()
                            .compareTo(b.memberName.toLowerCase())
                        : b.issuedAt.compareTo(a.issuedAt),
                    _InvoiceSort.period => (b.period ?? '')
                                .compareTo(a.period ?? '') !=
                            0
                        ? (b.period ?? '').compareTo(a.period ?? '')
                        : b.issuedAt.compareTo(a.issuedAt),
                  });
                final filterBar = Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(children: [
                    if (showMemberNames) ...[
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          key: const ValueKey('invoice-filter-member'),
                          initialValue: _filterMemberId,
                          isExpanded: true,
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text(l10n?.invoiceFilterAllMembers ??
                                  'All members'),
                            ),
                            for (final entry in memberOptions.entries)
                              DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value,
                                    overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _filterMemberId = value),
                          decoration: InputDecoration(
                            labelText:
                                l10n?.invoiceMemberLabel ?? 'Member',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        key: const ValueKey('invoice-filter-period'),
                        initialValue: _filterPeriod,
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(l10n?.invoiceFilterAllMonths ??
                                'All months'),
                          ),
                          for (final period in periodOptions)
                            DropdownMenuItem(
                              value: period,
                              child: Text(
                                _monthLabel(context, period),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _filterPeriod = value),
                        decoration: InputDecoration(
                          labelText:
                              l10n?.invoiceFilterMonthLabel ?? 'Month',
                        ),
                      ),
                    ),
                    PopupMenuButton<_InvoiceSort>(
                      key: const ValueKey('invoice-sort'),
                      tooltip: l10n?.invoiceSortTooltip ?? 'Sort',
                      icon: const Icon(Icons.sort),
                      initialValue: _sort,
                      onSelected: (value) =>
                          setState(() => _sort = value),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          key: const ValueKey('invoice-sort-newest'),
                          value: _InvoiceSort.newest,
                          child: Text(l10n?.invoiceSortNewest ??
                              'Newest first'),
                        ),
                        if (showMemberNames)
                          PopupMenuItem(
                            key: const ValueKey('invoice-sort-member'),
                            value: _InvoiceSort.member,
                            child: Text(l10n?.invoiceSortByMember ??
                                'By member'),
                          ),
                        PopupMenuItem(
                          key: const ValueKey('invoice-sort-period'),
                          value: _InvoiceSort.period,
                          child: Text(
                              l10n?.invoiceSortByMonth ?? 'By month'),
                        ),
                      ],
                    ),
                  ]),
                );
                return Column(children: [
                  filterBar,
                  Expanded(
                    child: visible.isEmpty
                        ? EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title:
                                l10n?.invoicesEmpty ?? 'No invoices yet.',
                          )
                        : ListView.builder(
                  padding: AppSpacing.mdAll,
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final invoice = visible[index];
                    final currency =
                        NumberFormat.simpleCurrency(name: invoice.currency);
                    final rowTitle =
                        '${invoice.number} · ${invoice.title}';
                    final colors = Theme.of(context).colorScheme;
                    return Card(
                      child: ListTile(
                        key: ValueKey('invoice-${invoice.id}'),
                        title: Row(children: [
                          Flexible(
                            child: Text(
                              rowTitle,
                              overflow: TextOverflow.ellipsis,
                              style: invoice.isVoided
                                  ? const TextStyle(
                                      decoration:
                                          TextDecoration.lineThrough)
                                  : null,
                            ),
                          ),
                          if (invoice.isVoided) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: colors.errorContainer,
                                borderRadius: AppRadius.smAll,
                              ),
                              child: Text(
                                l10n?.invoiceVoidedChip ?? 'Erroneous',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                        color: colors.onErrorContainer),
                              ),
                            ),
                          ],
                        ]),
                        subtitle: Text([
                          dateFormat.format(invoice.issuedAt),
                          if (showMemberNames) invoice.memberName,
                          currency.format(invoice.totalCents / 100),
                          if (invoice.replacesNumber.isNotEmpty)
                            '${l10n?.invoicePdfReplaces ?? 'Replaces'} '
                                '${invoice.replacesNumber}',
                          if (showMemberNames &&
                              reminders[invoice.id] != null)
                            l10n?.invoiceRemindedBadge(
                                    reminders[invoice.id]!.count) ??
                                'Reminded ×'
                                    '${reminders[invoice.id]!.count}',
                        ].join(' · ')),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: ValueKey(
                                  'invoice-download-${invoice.id}'),
                              tooltip:
                                  l10n?.invoiceDownload ?? 'Download PDF',
                              icon: const Icon(Icons.download_outlined),
                              onPressed: () =>
                                  _download(context, ref, invoice),
                            ),
                            IconButton(
                              key: ValueKey('invoice-share-${invoice.id}'),
                              tooltip: l10n?.invoiceShare ?? 'Share PDF',
                              icon: const Icon(Icons.share_outlined),
                              onPressed: () =>
                                  _share(context, ref, invoice),
                            ),
                            if (isEu ||
                                (canIssue &&
                                    (!invoice.isVoided ||
                                        !replacedIds
                                            .contains(invoice.id))))
                              PopupMenuButton<String>(
                                key: ValueKey('invoice-menu-${invoice.id}'),
                                onSelected: (action) => switch (action) {
                                  'void' => _void(context, ref, invoice),
                                  'remind' =>
                                    _remind(context, ref, invoice),
                                  'exml-down' => _eInvoice(
                                      context, ref, invoice,
                                      countryCode: countryCode,
                                      share: false),
                                  'exml-share' => _eInvoice(
                                      context, ref, invoice,
                                      countryCode: countryCode,
                                      share: true),
                                  _ => _createSheet(context, ref,
                                      replaces: invoice),
                                },
                                itemBuilder: (context) => [
                                  if (isEu) ...[
                                    PopupMenuItem(
                                      key: const ValueKey(
                                          'invoice-einvoice-download'),
                                      value: 'exml-down',
                                      child: Text(
                                          l10n?.invoiceEInvoiceDownload ??
                                              'Download e-invoice (XML)'),
                                    ),
                                    PopupMenuItem(
                                      key: const ValueKey(
                                          'invoice-einvoice-share'),
                                      value: 'exml-share',
                                      child: Text(
                                          l10n?.invoiceEInvoiceShare ??
                                              'Share e-invoice (XML)'),
                                    ),
                                  ],
                                  if (canIssue &&
                                      !invoice.isVoided &&
                                      invoice.totalCents > 0)
                                    PopupMenuItem(
                                      key: const ValueKey(
                                          'invoice-remind-action'),
                                      value: 'remind',
                                      child: Text(
                                          l10n?.invoiceRemindAction ??
                                              'Send a reminder'),
                                    ),
                                  if (canIssue && !invoice.isVoided)
                                    PopupMenuItem(
                                      key: const ValueKey(
                                          'invoice-void-action'),
                                      value: 'void',
                                      child: Text(l10n?.invoiceVoidAction ??
                                          'Mark erroneous'),
                                    ),
                                  if (canIssue &&
                                      !replacedIds.contains(invoice.id))
                                    PopupMenuItem(
                                      key: const ValueKey(
                                          'invoice-replace-action'),
                                      value: 'replace',
                                      child: Text(
                                          l10n?.invoiceReplaceAction ??
                                              'Issue replacement'),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                  ),
                ]);
              }),
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

  /// 'yyyy-MM' → localized month name for the filter dropdown.
  String _monthLabel(BuildContext context, String period) {
    final parts = period.split('-');
    final month = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    return DateFormat.yMMMM(
      Localizations.maybeLocaleOf(context)?.toString(),
    ).format(month);
  }

  /// Issue sheet — plain from the FAB, or a REPLACEMENT (0061)
  /// prefilled from [replaces]. Since 0062 nothing is typed here: the
  /// admin picks the member and the MONTH, the sheet previews the
  /// positions the server derives from that month's tracked data
  /// (subscription, overage, supplements, services, packages), and
  /// issuing snapshots exactly those — no new positions are created.
  Future<void> _createSheet(
    BuildContext context,
    WidgetRef ref, {
    Invoice? replaces,
  }) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final members = (await ref.read(workspaceMembersProvider.future))
        .where((m) => m.status == MemberStatus.active && !m.isKiosk)
        .toList();
    final names = await ref.read(memberNamesProvider.future);
    if (!context.mounted) return;

    final repo = ref.read(moneyRepositoryProvider);
    final result = await showModalBottomSheet<
        ({String memberId, String period, bool detailed})>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _InvoiceForm(
        l10n: l10n,
        members: [
          for (final member in members)
            (id: member.id, name: names[member.id] ?? ''),
        ],
        currency:
            NumberFormat.simpleCurrency(name: workspace.currencyCode),
        preview: (memberId, period) => repo.previewInvoice(
          workspaceId: workspace.id,
          memberId: memberId,
          period: period,
        ),
        // Only preselect a member the dropdown actually offers — the
        // wrong invoice may target a member who has left since.
        initialMemberId: members.any((m) => m.id == replaces?.memberId)
            ? replaces?.memberId
            : null,
        initialPeriod: replaces?.period,
        initialDetailed: replaces?.detailed ?? false,
        replacesNumber: replaces?.number,
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
            period: result.period,
            replacesId: replaces?.id,
            detailed: result.detailed,
          ),
    )) {
      return;
    }
    ref.invalidate(invoicesProvider);
    if (!context.mounted) return;
    AppSnack.success(context, l10n?.invoiceIssued ?? 'Invoice issued.');
  }
}

/// The issue form (0062): member + month, and a read-only PREVIEW of
/// the positions the server derives from that month's tracked data.
/// There is no way to type a position — that is the point.
class _InvoiceForm extends StatefulWidget {
  const _InvoiceForm({
    required this.l10n,
    required this.members,
    required this.currency,
    required this.preview,
    this.initialMemberId,
    this.initialPeriod,
    this.initialDetailed = false,
    this.replacesNumber,
  });

  final AppLocalizations? l10n;
  final List<({String id, String name})> members;
  final NumberFormat currency;
  final Future<({List<InvoiceLine> lines, int totalCents})> Function(
      String memberId, String period) preview;
  final String? initialMemberId;
  final String? initialPeriod;
  final bool initialDetailed;
  final String? replacesNumber;

  @override
  State<_InvoiceForm> createState() => _InvoiceFormState();
}

class _InvoiceFormState extends State<_InvoiceForm> {
  late String? _memberId = widget.initialMemberId;
  late String _period = widget.initialPeriod ?? currentPeriod();
  late bool _detailed = widget.initialDetailed;
  ({List<InvoiceLine> lines, int totalCents})? _preview;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime get _month {
    final parts = _period.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]));
  }

  Future<void> _load() async {
    final memberId = _memberId;
    if (memberId == null) return;
    final period = _period;
    setState(() => _loading = true);
    try {
      final result = await widget.preview(memberId, period);
      if (!mounted || _memberId != memberId || _period != period) return;
      setState(() {
        _preview = result;
        _loading = false;
      });
    } catch (e, st) {
      // The preview is advisory (issuing re-derives server-side), but a
      // failing fetch still leaves a breadcrumb.
      TraceLogger.instance
          .error('money', 'invoice preview failed', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() {
        _preview = (lines: const <InvoiceLine>[], totalCents: 0);
        _loading = false;
      });
    }
  }

  void _shiftMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    final now = DateTime.now();
    if (next.year > now.year ||
        (next.year == now.year && next.month > now.month)) {
      return;
    }
    setState(() {
      _period =
          '${next.year}-${next.month.toString().padLeft(2, '0')}';
      _preview = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final replacesNumber = widget.replacesNumber;
    final replacesBanner = replacesNumber == null
        ? null
        : '${l10n?.invoicePdfReplaces ?? 'Replaces'} $replacesNumber';
    final monthLabel = DateFormat.yMMMM(
      Localizations.maybeLocaleOf(context)?.toString(),
    ).format(_month);
    final now = DateTime.now();
    final atCurrent =
        _month.year == now.year && _month.month == now.month;
    final preview = _preview;
    final lines = preview?.lines ?? const <InvoiceLine>[];

    return SheetShell(
      title: l10n?.invoiceCreate ?? 'New invoice',
      children: [
        if (replacesBanner != null) ...[
          const SizedBox(height: 8),
          InlineBanner(
            key: const ValueKey('invoice-replaces-banner'),
            icon: Icons.published_with_changes_outlined,
            text: replacesBanner,
            severity: InlineBannerSeverity.info,
          ),
        ],
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
          onChanged: (value) {
            setState(() {
              _memberId = value;
              _preview = null;
            });
            _load();
          },
          decoration: InputDecoration(
            labelText: l10n?.invoiceMemberLabel ?? 'Member',
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          IconButton(
            key: const ValueKey('invoice-period-prev'),
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _shiftMonth(-1),
          ),
          Expanded(
            child: Text(
              monthLabel,
              key: const ValueKey('invoice-period-label'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            key: const ValueKey('invoice-period-next'),
            icon: const Icon(Icons.chevron_right),
            onPressed: atCurrent ? null : () => _shiftMonth(1),
          ),
        ]),
        const SizedBox(height: 8),
        // The derived positions — read-only by design (0062).
        if (_memberId == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              l10n?.invoiceMemberLabel ?? 'Member',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else if (_loading || preview == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (lines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              l10n?.invoiceNothingToInvoice ??
                  'Nothing tracked for this month — nothing to invoice.',
              key: const ValueKey('invoice-preview-empty'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else ...[
          for (final (i, line) in lines.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                key: ValueKey('invoice-preview-line-$i'),
                children: [
                  Expanded(child: Text(invoiceLineText(l10n, line))),
                  Text(widget.currency.format(line.amountCents / 100)),
                ],
              ),
            ),
          const Divider(),
          Row(
            key: const ValueKey('invoice-preview-total'),
            children: [
              Expanded(
                child: Text(
                  // 0063 — the invoice nets consumptions against
                  // payments: the total IS the balance due (solde).
                  l10n?.invoiceBalance ?? 'Balance due',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                widget.currency.format(preview.totalCents / 100),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
        const SizedBox(height: 4),
        // 0064 — snapshot the annex (check-ins, bookings, payments)
        // into the immutable document.
        SwitchListTile(
          key: const ValueKey('invoice-detailed-switch'),
          contentPadding: EdgeInsets.zero,
          value: _detailed,
          onChanged: (value) => setState(() => _detailed = value),
          title: Text(
            l10n?.invoiceDetailedToggle ??
                'Include the detailed annex (check-ins, services, '
                    'payments)',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 4),
        FilledButton(
          key: const ValueKey('invoice-submit'),
          onPressed: _memberId == null || lines.isEmpty
              ? null
              : () => Navigator.of(context).pop((
                    memberId: _memberId!,
                    period: _period,
                    detailed: _detailed,
                  )),
          child: Text(l10n?.invoiceIssue ?? 'Issue invoice'),
        ),
      ],
    );
  }
}
