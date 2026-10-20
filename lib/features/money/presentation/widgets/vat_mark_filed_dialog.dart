// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';

/// #2357 — the mark-as-filed dialog: the owner confirms and types the
/// receipt reference the authority gave; the button waits for it.
class VatMarkFiledDialog extends StatefulWidget {
  const VatMarkFiledDialog({super.key, required this.l10n});

  final AppLocalizations l10n;

  @override
  State<VatMarkFiledDialog> createState() => _VatMarkFiledDialogState();
}

class _VatMarkFiledDialogState extends State<VatMarkFiledDialog> {
  final _receipt = TextEditingController();

  @override
  void dispose() {
    _receipt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.vatDeclMarkFiled),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.vatDeclMarkFiledConfirm),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            key: const ValueKey('vat-decl-receipt'),
            controller: _receipt,
            autofocus: true,
            label: l10n.vatDeclReceipt,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('vat-declarations-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('vat-decl-filed-confirm'),
          onPressed: _receipt.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_receipt.text.trim()),
          child: Text(l10n.vatDeclMarkFiled),
        ),
      ],
    );
  }
}
