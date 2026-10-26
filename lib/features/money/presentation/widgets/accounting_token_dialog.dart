// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The API token an accounting connection is reached with: pasted once, kept
// encrypted on the server and never shown again. #2374 — for Business
// Central, the client id and secret of the company's Microsoft Entra
// application and the company it reaches (tenant, environment, company id).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/accounting_connection.dart';
import '../../domain/accounting_format.dart';
import '../../domain/business_central_connection.dart';
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
    'clientId': '',
    'environment': '',
    'company': '',
  });
  var _tooShort = false;

  /// The field whose value does not have its expected form (Entra only).
  EntraField? _invalid;

  bool get _entra =>
      widget.target.tokenShape == AccountingTokenShape.entraClientCredentials;

  @override
  void dispose() {
    _fields.dispose();
    super.dispose();
  }

  /// The token and remote company to send, or null when a field of the
  /// Entra form does not have its form (named on the field).
  ({String token, String tenant})? _credentials() {
    if (!_entra) {
      return (token: _fields['token'].text, tenant: _fields['tenant'].text);
    }
    final adding = widget.connection == null;
    final composed = EntraConnection.of(
      clientId: _fields['clientId'].text,
      secret: _fields['token'].text,
      tenant: adding ? _fields['tenant'].text : null,
      environment: adding ? _fields['environment'].text : null,
      company: adding ? _fields['company'].text : null,
    );
    switch (composed) {
      case EntraInvalid(:final field):
        setState(() => _invalid = field);
        return null;
      case EntraValid(:final token, :final remoteTenantId):
        return (token: token, tenant: remoteTenantId ?? '');
    }
  }

  Future<void> _save() async {
    final credentials = _credentials();
    if (credentials == null) return;
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
                token: credentials.token,
                remoteTenantId: credentials.tenant,
              )
            : await commands.replaceToken(existing, token: credentials.token);
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
    final adding = widget.connection == null;
    String? invalid(EntraField field) =>
        _invalid == field ? l10n.acctEntraInvalid : null;
    void clear() {
      if (_invalid != null) setState(() => _invalid = null);
    }

    Widget entraField(String key, EntraField field, String label) =>
        AppTextField(
          key: ValueKey('acct-entra-$key'),
          controller: _fields[key],
          label: label,
          maxLength: entraFieldLength[field],
          error: invalid(field),
          onChanged: (_) => clear(),
        );
    return AlertDialog(
      title: Text(_entra ? l10n.acctEntraTitle(name) : l10n.acctTokenTitle(name)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_entra ? l10n.acctEntraBody : l10n.acctTokenBody(name)),
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
            if (_entra) ...[
              entraField('clientId', EntraField.clientId, l10n.acctEntraClientId),
              const FormGap(),
            ],
            AppTextField(
              key: const ValueKey('acct-token-value'),
              controller: _fields['token'],
              label: _entra ? l10n.acctEntraSecret : l10n.acctTokenField,
              // Never offered to a password manager: the token is kept on
              // the server only, and a revoke must leave no copy behind.
              obscureText: true,
              keyboardType: TextInputType.visiblePassword,
              maxLength: accountingTokenLength.max,
              error: _tooShort
                  ? l10n.acctTokenTooShort
                  : invalid(EntraField.secret),
              onChanged: (_) {
                if (_tooShort) setState(() => _tooShort = false);
                clear();
              },
            ),
            if (adding && _entra) ...[
              const FormGap(),
              entraField('tenant', EntraField.tenant, l10n.acctEntraTenant),
              const FormGap(),
              entraField(
                'environment',
                EntraField.environment,
                l10n.acctEntraEnvironment,
              ),
              const FormGap(),
              entraField('company', EntraField.company, l10n.acctEntraCompany),
            ] else if (adding) ...[
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
