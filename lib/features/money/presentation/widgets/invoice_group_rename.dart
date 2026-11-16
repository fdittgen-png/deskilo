// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3556 (part 2) — one of my groups named again; nothing else changes. A
// name the database refuses (taken, or not 1 to 80 characters) is shown
// under the field.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/invoice_groups.dart';
import '../../providers/invoice_group_providers.dart';
import 'invoice_group_sheet.dart' show invoiceGroupRefusalText;

/// Names [group] again; nothing else changes.
Future<void> showInvoiceGroupRename(BuildContext context, InvoiceGroup group) =>
    showDialog<void>(
      context: context,
      builder: (_) => _RenameDialog(group: group),
    );

class _RenameDialog extends ConsumerStatefulWidget {
  const _RenameDialog({required this.group});

  final InvoiceGroup group;

  @override
  ConsumerState<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends ConsumerState<_RenameDialog> {
  late final _name = TextEditingController(text: widget.group.name);
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final checked = invoiceGroupName(_name.text);
    if (checked.name == null) {
      setState(() => _error = invoiceGroupRefusalText(l10n, checked.refusal!));
      return;
    }
    setState(() => _busy = true);
    InvoiceGroupRefusal? refusal;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'invoice group rename failed',
      errorText: l10n.financesGroupFailed,
      action: () async {
        try {
          await ref
              .read(invoiceGroupsProvider.notifier)
              .rename(widget.group.id, checked.name!);
        } on InvoiceGroupRefused catch (r) {
          // trace-exempt: a refused name is shown under its field
          refusal = r.reason;
        }
      },
    );
    if (!mounted) return;
    if (ok && refusal == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      if (refusal != null) _error = invoiceGroupRefusalText(l10n, refusal!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      key: const ValueKey('invoice-group-rename-dialog'),
      title: Text(l10n.financesGroupRename),
      content: AppTextField(
        controller: _name,
        key: const ValueKey('invoice-group-rename-name'),
        label: l10n.financesGroupNewName,
        error: _error,
        maxLength: invoiceGroupNameMax,
        autofocus: true,
        enabled: !_busy,
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          key: const ValueKey('invoice-group-rename-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('invoice-group-rename-save'),
          onPressed: _busy ? null : _save,
          child: Text(MaterialLocalizations.of(context).saveButtonLabel),
        ),
      ],
    );
  }
}
