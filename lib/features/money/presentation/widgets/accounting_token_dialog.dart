// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The API token an accounting connection is reached with: pasted once, kept
// encrypted on the server and never shown again.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/accounting_connection.dart';
import '../../domain/accounting_format.dart';
import '../../providers/accounting_connection_providers.dart';
import 'accounting_targets_sheet.dart';

/// Connects the issuer to [target] with a pasted API token, or replaces the
/// token of [connection]. True when saved.
Future<bool?> showTokenDialog(
  BuildContext context, {
  required String workspaceId,
  required AccountingTarget target,
  required String issuerId,
  required String issuerName,
  AccountingConnection? connection,
}) => showDialog<bool>(
  context: context,
  builder: (_) => _TokenDialog(
    workspaceId: workspaceId,
    target: target,
    issuerId: issuerId,
    issuerName: issuerName,
    connection: connection,
  ),
);

class _TokenDialog extends ConsumerStatefulWidget {
  const _TokenDialog({
    required this.workspaceId,
    required this.target,
    required this.issuerId,
    required this.issuerName,
    required this.connection,
  });

  final String workspaceId;
  final AccountingTarget target;
  final String issuerId;
  final String issuerName;
  final AccountingConnection? connection;

  @override
  ConsumerState<_TokenDialog> createState() => _TokenDialogState();
}

class _TokenDialogState extends ConsumerState<_TokenDialog> {
  late final _fields = FormControllers({
    'name': '${targetLabel(widget.target.id)} — ${widget.issuerName}',
    'token': '',
    'tenant': '',
  });
  var _tooShort = false;

  @override
  void dispose() {
    _fields.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    final commands = ref.read(accountingConnectionCommandProvider);
    AccountingConnection? saved;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'accounting token failed',
      errorText: context.l10n.acctConnRefused,
      action: () async {
        final existing = widget.connection;
        saved = existing == null
            ? await commands.connectWithToken(
                widget.workspaceId,
                issuerSiteId: widget.issuerId,
                targetId: widget.target.id,
                displayName: _fields['name'].text,
                token: _fields['token'].text,
                remoteTenantId: _fields['tenant'].text,
              )
            : await commands.replaceToken(existing, token: _fields['token'].text);
      },
    );
    if (!mounted || !ok) return;
    if (saved == null) {
      setState(() => _tooShort = true);
      return;
    }
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = targetLabel(widget.target.id);
    return AlertDialog(
      title: Text(l10n.acctTokenTitle(name)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.acctTokenBody(name)),
            const FormGap(),
            if (widget.connection == null) ...[
              AppTextField(
                key: const ValueKey('acct-token-name'),
                controller: _fields['name'],
                label: l10n.acctTokenName,
                maxLength: 120,
              ),
              const FormGap(),
            ],
            AppTextField(
              key: const ValueKey('acct-token-value'),
              controller: _fields['token'],
              label: l10n.acctTokenField,
              obscureText: true,
              keyboardType: TextInputType.visiblePassword,
              autofillHints: const [AutofillHints.password],
              error: _tooShort ? l10n.acctTokenTooShort : null,
              onChanged: (_) {
                if (_tooShort) setState(() => _tooShort = false);
              },
            ),
            if (widget.connection == null) ...[
              const FormGap(),
              AppTextField(
                key: const ValueKey('acct-token-tenant'),
                controller: _fields['tenant'],
                label: l10n.acctTokenTenant(name),
                maxLength: 200,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('acct-token-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('acct-token-save'),
          onPressed: _save,
          child: Text(l10n.acctTokenSave),
        ),
      ],
    );
  }
}
