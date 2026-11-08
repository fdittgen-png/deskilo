// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2379 — before an Austrian SAF-T file, the person confirms the account of
// the österreichischer Einheitskontenrahmen each book account is written
// under (AccountID_oeEKR). The reference's row for the account's role is a
// suggestion, prefilled and labelled as such: a role's accounts need not
// all sit on one standard account (a foreign supplier's payables are not
// the domestic 3300). Nothing is written that nobody confirmed; an account
// left empty refuses the file, named.
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/form_kit.dart';

/// One book account to confirm, with the reference's suggestion.
typedef SafTStandardRow = ({String code, String name, AccountMapValue? suggestion});

/// The confirmed standard account per book account code, or null when the
/// person backed out.
Future<Map<String, AccountMapValue>?> showSafTStandardAccountsDialog(
  BuildContext context,
  List<SafTStandardRow> rows,
) =>
    showDialog<Map<String, AccountMapValue>>(
      context: context,
      builder: (context) => _SafTStandardAccountsDialog(rows),
    );

class _SafTStandardAccountsDialog extends StatefulWidget {
  const _SafTStandardAccountsDialog(this.rows);

  final List<SafTStandardRow> rows;

  @override
  State<_SafTStandardAccountsDialog> createState() =>
      _SafTStandardAccountsDialogState();
}

class _SafTStandardAccountsDialogState
    extends State<_SafTStandardAccountsDialog> {
  late final FormControllers _fields = FormControllers({
    for (final r in widget.rows) r.code: r.suggestion?.account ?? '',
  });

  @override
  void dispose() {
    _fields.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.saftStandardAccountsTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.saftStandardAccountsIntro,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            for (final r in widget.rows) ...[
              const FormGap(),
              AppTextField(
                key: ValueKey('saft-standard-${r.code}'),
                controller: _fields[r.code],
                label: '${r.code} ${r.name}',
                helper: r.suggestion == null
                    ? l10n.saftStandardAccountsNoSuggestion
                    : l10n.saftStandardAccountsSuggested(
                        '${r.suggestion!.account} ${r.suggestion!.label}',
                      ),
                keyboardType: TextInputType.number,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('saft-standard-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('saft-standard-confirm'),
          onPressed: () => Navigator.of(context).pop({
            for (final r in widget.rows)
              if (_fields.text(r.code) case final code when code.isNotEmpty)
                r.code: AccountMapValue(
                  format: 'saf_t',
                  role: r.suggestion?.role ?? '',
                  account: code,
                  // The suggestion's name only where its number was kept.
                  label: code == r.suggestion?.account ? r.suggestion!.label : '',
                ),
          }),
          child: Text(l10n.commonOk),
        ),
      ],
    );
  }
}
