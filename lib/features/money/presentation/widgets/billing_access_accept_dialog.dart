// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4164 B2 -- the account's door to a billing customer's access: the code a
// business handed out is previewed (who invites, in whose name the invoices are
// made out), then accepted. An unusable code gets ONE answer, whatever made it
// unusable (DKH01); a lost connection claims nothing. Accepting creates no
// membership: the documents appear apart in Me › Finances.
import 'package:flutter/material.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/form_kit.dart';
import '../../application/billing_access_commands.dart';
import '../../domain/billing_access.dart';
import 'billing_access_texts.dart';

/// Opens the dialog; true when a grant was accepted (the caller reloads).
Future<bool> showBillingAccessAcceptDialog(
  BuildContext context, {
  required BillingAccessCommands commands,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _AcceptDialog(commands: commands),
    ) ??
    false;

class _AcceptDialog extends StatefulWidget {
  const _AcceptDialog({required this.commands});

  final BillingAccessCommands commands;

  @override
  State<_AcceptDialog> createState() => _AcceptDialogState();
}

class _AcceptDialogState extends State<_AcceptDialog> {
  final _code = TextEditingController();
  BillingAccessPreview? _preview;
  String? _problem;
  bool _busy = false;
  bool _accepted = false;
  String _business = '';

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    final outcome = await widget.commands.preview(_code.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _problem = billingAccessProblemText(context.l10n, outcome);
      _preview = switch (outcome) {
        BillingAccessDone(:final value) => value,
        _ => null,
      };
    });
  }

  Future<void> _accept() async {
    final preview = _preview;
    if (preview == null) return;
    setState(() {
      _busy = true;
      _problem = null;
    });
    final outcome = await widget.commands.accept(_code.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _problem = billingAccessProblemText(context.l10n, outcome);
      if (outcome is BillingAccessDone) {
        _accepted = true;
        _business = preview.workspaceName;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final preview = _preview;
    return AlertDialog(
      key: const ValueKey('billing-access-accept-dialog'),
      title: Row(
        children: [
          Expanded(child: Text(l10n.billingAccessEnterTitle)),
          HelpDot(l10n.billingAccessEnter, anchor: HelpAnchor.moneyBilledToYou),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_accepted)
                Text(
                  l10n.billingAccessAccepted(_business),
                  key: const ValueKey('billing-access-done'),
                )
              else ...[
                Text(l10n.billingAccessEnterIntro),
                const FormGap(),
                AppTextField(
                  key: const ValueKey('billing-access-code-field'),
                  controller: _code,
                  label: l10n.spaceScanField,
                  enabled: preview == null && !_busy,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  onSubmitted: (_) => _check(),
                ),
                if (preview != null) ...[
                  const FormGap(),
                  Text(
                    preview.billedAs.isEmpty
                        ? l10n.billingAccessPreviewUnnamed(
                            preview.workspaceName,
                          )
                        : l10n.billingAccessPreviewLine(
                            preview.workspaceName,
                            preview.billedAs,
                          ),
                    key: const ValueKey('billing-access-preview'),
                  ),
                  if (preview.accepted) Text(l10n.billingAccessAlreadyHeld),
                ],
              ],
              if (_problem case final problem?) ...[
                const FormGap.small(),
                Text(
                  problem,
                  key: const ValueKey('billing-access-problem'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('billing-access-cancel'),
          onPressed: () => Navigator.of(context).pop(_accepted),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
        if (!_accepted && preview == null)
          FilledButton(
            key: const ValueKey('billing-access-check'),
            onPressed: _busy ? null : _check,
            child: Text(l10n.billingAccessCheck),
          ),
        if (!_accepted && preview != null)
          FilledButton(
            key: const ValueKey('billing-access-accept'),
            onPressed: _busy ? null : _accept,
            child: Text(l10n.billingAccessAccept),
          ),
      ],
    );
  }
}
