// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3556 (part 2) — which of my groups an invoice is in: each group a switch
// (filed or not, at once), and a new group named and filed in one step. A
// group is my own filing; nothing about the invoice changes.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/finance_overview.dart';
import '../../domain/invoice_groups.dart';
import '../../providers/invoice_group_providers.dart';

/// The words of a refused name.
String invoiceGroupRefusalText(AppLocalizations l10n, InvoiceGroupRefusal r) =>
    switch (r) {
      InvoiceGroupRefusal.nameTaken => l10n.financesGroupNameTaken,
      InvoiceGroupRefusal.nameShape => l10n.financesGroupNameShape,
    };

Future<void> showInvoiceGroupSheet(
  BuildContext context,
  FinanceInvoice invoice,
  InvoiceRef ref,
) => showAppSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _InvoiceGroupSheet(invoice: invoice, invoiceRef: ref),
);

class _InvoiceGroupSheet extends ConsumerStatefulWidget {
  const _InvoiceGroupSheet({required this.invoice, required this.invoiceRef});

  final FinanceInvoice invoice;
  final InvoiceRef invoiceRef;

  @override
  ConsumerState<_InvoiceGroupSheet> createState() => _InvoiceGroupSheetState();
}

class _InvoiceGroupSheetState extends ConsumerState<_InvoiceGroupSheet> {
  final _name = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _write(Future<void> Function(InvoiceGroups groups) write) async {
    if (_busy) return;
    final l10n = context.l10n;
    setState(() => _busy = true);
    InvoiceGroupRefusal? refusal;
    await runGuarded(
      context,
      domain: 'money',
      message: 'invoice group write failed',
      errorText: l10n.financesGroupFailed,
      action: () async {
        try {
          await write(ref.read(invoiceGroupsProvider.notifier));
        } on InvoiceGroupRefused catch (r) {
          // trace-exempt: a refused name is shown under its field
          refusal = r.reason;
        }
      },
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = refusal == null ? null : invoiceGroupRefusalText(l10n, refusal!);
      if (refusal == null) _name.clear();
    });
  }

  Future<void> _create() {
    final checked = invoiceGroupName(_name.text);
    if (checked.name == null) {
      setState(
        () => _error = invoiceGroupRefusalText(context.l10n, checked.refusal!),
      );
      return Future.value();
    }
    return _write((groups) async {
      final id = await groups.create(checked.name!);
      await groups.add(id, widget.invoiceRef, widget.invoice.number);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final groups = ref.watch(invoiceGroupsProvider).value ?? const [];
    final media = MediaQuery.of(context);
    return Padding(
      key: const ValueKey('invoice-group-sheet'),
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: AppSpacing.lgAll,
          children: [
            Text(
              l10n.financesGroupAddTitle(widget.invoice.number),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final g in groups)
              CheckboxListTile(
                key: ValueKey('invoice-group-toggle-${g.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(g.name),
                value: g.holds(widget.invoiceRef),
                onChanged: _busy
                    ? null
                    : (on) => _write(
                        (groups) => on ?? false
                            ? groups.add(
                                g.id,
                                widget.invoiceRef,
                                widget.invoice.number,
                              )
                            : groups.remove(g.id, widget.invoiceRef),
                      ),
              ),
            const FormGap(),
            AppTextField(
              controller: _name,
              key: const ValueKey('invoice-group-new-name'),
              label: l10n.financesGroupNewName,
              error: _error,
              maxLength: invoiceGroupNameMax,
              textInputAction: TextInputAction.done,
              enabled: !_busy,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _create(),
            ),
            const FormGap.small(),
            FilledButton.icon(
              key: const ValueKey('invoice-group-create'),
              icon: const Icon(Icons.create_new_folder_outlined),
              label: Text(l10n.financesGroupCreate),
              onPressed: _busy ? null : _create,
            ),
          ],
        ),
      ),
    );
  }
}
