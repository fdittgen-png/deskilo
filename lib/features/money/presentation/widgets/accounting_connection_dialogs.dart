// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The forms of an accounting connection: the API token it is reached with
// (kept encrypted on the server, never shown again) and the mappings a
// delivery reads, each key named as the target knows it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../workspace/domain/site.dart';
import '../../../workspace/providers/member_display_providers.dart';
import '../../application/accounting_connection_commands.dart';
import '../../domain/accounting_connection.dart';
import '../../domain/accounting_format.dart';
import '../../domain/book_chart.dart';
import '../../providers/accounting_connection_providers.dart';
import 'accounting_targets_sheet.dart';
import 'book_chart_sheet.dart';

/// Connects [issuer] to [target] with a pasted API token, or replaces the
/// token of [connection]. True when saved.
Future<bool?> showTokenDialog(
  BuildContext context, {
  required String workspaceId,
  required AccountingTarget target,
  required Site issuer,
  AccountingConnection? connection,
}) => showDialog<bool>(
  context: context,
  builder: (_) => _TokenDialog(
    workspaceId: workspaceId,
    target: target,
    issuer: issuer,
    connection: connection,
  ),
);

class _TokenDialog extends ConsumerStatefulWidget {
  const _TokenDialog({
    required this.workspaceId,
    required this.target,
    required this.issuer,
    required this.connection,
  });

  final String workspaceId;
  final AccountingTarget target;
  final Site issuer;
  final AccountingConnection? connection;

  @override
  ConsumerState<_TokenDialog> createState() => _TokenDialogState();
}

class _TokenDialogState extends ConsumerState<_TokenDialog> {
  late final _fields = FormControllers({
    'name': '${targetLabel(widget.target.id)} — ${widget.issuer.name}',
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
                issuerSiteId: widget.issuer.id,
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

/// The mappings of [connection], with the doors to add, change and remove
/// one for a billing manager.
Future<void> showMappingsSheet(
  BuildContext context, {
  required String workspaceId,
  required AccountingConnection connection,
  required bool manage,
}) => showAppSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => MappingsView(
    workspaceId: workspaceId,
    connectionId: connection.id,
    manage: manage,
  ),
);

/// The words of a mapping kind.
String mapKindLabel(BuildContext context, AccountingMapKind kind) {
  final l10n = context.l10n;
  return switch (kind) {
    AccountingMapKind.account => l10n.acctMapKindAccount,
    AccountingMapKind.tax => l10n.acctMapKindTax,
    AccountingMapKind.party => l10n.acctMapKindParty,
    AccountingMapKind.item => l10n.acctMapKindItem,
  };
}

@visibleForTesting
class MappingsView extends ConsumerWidget {
  const MappingsView({
    required this.workspaceId,
    required this.connectionId,
    required this.manage,
    super.key,
  });

  final String workspaceId;
  final String connectionId;
  final bool manage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final all = ref.watch(accountingConnectionsProvider(workspaceId)).value;
    final c = all?.where((x) => x.id == connectionId).firstOrNull;
    if (c == null) return const SizedBox.shrink();
    final names = ref.watch(memberNamesProvider).value ?? const {};
    Future<void> edit([AccountingMap? map]) async {
      final saved = await showDialog<bool>(
        context: context,
        builder: (_) => _MapDialog(
          workspaceId: workspaceId,
          connectionId: c.id,
          map: map,
        ),
      );
      if (saved == true) ref.invalidate(accountingConnectionsProvider(workspaceId));
    }

    Future<void> remove(AccountingMap map) async {
      final ok = await runGuarded(
        context,
        domain: 'money',
        message: 'accounting mapping removal failed',
        errorText: l10n.acctConnRefused,
        action: () => ref.read(accountingConnectionCommandProvider).deleteMap(map.id),
      );
      if (ok) ref.invalidate(accountingConnectionsProvider(workspaceId));
    }

    String keyText(AccountingMap m) {
      if (m.kind == AccountingMapKind.party) {
        final id = m.key.substring(m.key.indexOf(':') + 1);
        return names[id] ?? m.key;
      }
      if (m.kind == AccountingMapKind.account || m.kind == AccountingMapKind.item) {
        final role = m.key.split(':').first;
        final known = BookRole.values.where((r) => r.wire == role).firstOrNull;
        if (known != null) {
          final rest = m.key.length > role.length ? m.key.substring(role.length) : '';
          return '${bookRoleLabel(l10n, known)}$rest';
        }
      }
      return m.key;
    }

    return SheetShell(
      title: l10n.acctMapsTitle(targetLabel(c.targetId)),
      children: [
        Text(l10n.acctMapsIntro, style: Theme.of(context).textTheme.bodySmall),
        if (c.maps.isEmpty)
          Text(l10n.acctMapsEmpty, key: const ValueKey('acct-maps-empty')),
        for (final m in c.maps)
          ListTile(
            key: ValueKey('acct-map-${m.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.acctMapLine(keyText(m), m.remote)),
            subtitle: Text(
              m.remoteName.isEmpty
                  ? mapKindLabel(context, m.kind)
                  : '${mapKindLabel(context, m.kind)} · ${m.remoteName}',
            ),
            onTap: manage && c.live ? () => edit(m) : null,
            trailing: manage && c.live
                ? IconButton(
                    key: ValueKey('acct-map-delete-${m.id}'),
                    tooltip: l10n.acctMapDelete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => remove(m),
                  )
                : null,
          ),
        if (manage && c.live)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const ValueKey('acct-map-add'),
              onPressed: edit,
              icon: const Icon(Icons.add),
              label: Text(l10n.acctMapAdd),
            ),
          ),
      ],
    );
  }
}

class _MapDialog extends ConsumerStatefulWidget {
  const _MapDialog({
    required this.workspaceId,
    required this.connectionId,
    required this.map,
  });

  final String workspaceId;
  final String connectionId;
  final AccountingMap? map;

  @override
  ConsumerState<_MapDialog> createState() => _MapDialogState();
}

class _MapDialogState extends ConsumerState<_MapDialog> {
  late var _kind = widget.map?.kind ?? AccountingMapKind.account;
  late var _role = _roleOf(widget.map);
  late String? _member = _memberOf(widget.map);
  late final _fields = FormControllers({
    'qualifier': _qualifierOf(widget.map),
    'tax': widget.map?.kind == AccountingMapKind.tax ? widget.map!.key : '',
    'code': widget.map?.remoteCode ?? '',
    'id': widget.map?.remoteId ?? '',
    'name': widget.map?.remoteName ?? '',
  });
  MapDraftProblem? _problem;

  static BookRole _roleOf(AccountingMap? m) {
    if (m == null || m.kind == AccountingMapKind.tax || m.kind == AccountingMapKind.party) {
      return BookRole.revenue;
    }
    final wire = m.key.split(':').first;
    return BookRole.values.where((r) => r.wire == wire).firstOrNull ?? BookRole.revenue;
  }

  static String _qualifierOf(AccountingMap? m) {
    if (m == null || m.kind == AccountingMapKind.tax || m.kind == AccountingMapKind.party) {
      return '';
    }
    final at = m.key.indexOf(':');
    return at < 0 ? '' : m.key.substring(at + 1);
  }

  static String? _memberOf(AccountingMap? m) =>
      m != null && m.kind == AccountingMapKind.party && m.key.startsWith('member:')
          ? m.key.substring('member:'.length)
          : null;

  @override
  void dispose() {
    _fields.dispose();
    super.dispose();
  }

  String get _key => switch (_kind) {
    AccountingMapKind.account || AccountingMapKind.item =>
      _fields['qualifier'].text.trim().isEmpty
          ? _role.wire
          : '${_role.wire}:${_fields['qualifier'].text.trim()}',
    AccountingMapKind.tax => _fields['tax'].text.trim(),
    AccountingMapKind.party =>
      _member == null ? '' : partyMapKey(AccountingPartyKind.member, _member!),
  };

  AccountingMapDraft get _draft => AccountingMapDraft(
    kind: _kind,
    key: _key,
    remoteId: _fields['id'].text,
    remoteCode: _fields['code'].text,
    remoteName: _fields['name'].text,
  );

  Future<void> _save() async {
    final problem = mapDraftProblem(_draft);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    final navigator = Navigator.of(context);
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'accounting mapping failed',
      errorText: context.l10n.acctConnRefused,
      action: () => ref
          .read(accountingConnectionCommandProvider)
          .saveMap(widget.connectionId, _draft),
    );
    if (ok && mounted) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final names = ref.watch(memberNamesProvider).value ?? const {};
    final keyError = _problem == MapDraftProblem.key ? l10n.acctMapKeyInvalid : null;
    final editing = widget.map != null;
    return AlertDialog(
      title: Text(editing ? mapKindLabel(context, _kind) : l10n.acctMapAdd),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<AccountingMapKind>(
              key: const ValueKey('acct-map-kind'),
              initialValue: _kind,
              decoration: InputDecoration(labelText: l10n.acctMapKind),
              items: [
                for (final k in AccountingMapKind.values)
                  DropdownMenuItem(value: k, child: Text(mapKindLabel(context, k))),
              ],
              onChanged: editing
                  ? null
                  : (k) => setState(() {
                      _kind = k ?? _kind;
                      _problem = null;
                    }),
            ),
            const FormGap(),
            ...switch (_kind) {
              AccountingMapKind.account || AccountingMapKind.item => [
                DropdownButtonFormField<BookRole>(
                  key: const ValueKey('acct-map-role'),
                  initialValue: _role,
                  decoration: InputDecoration(labelText: l10n.acctMapRole),
                  items: [
                    for (final r in BookRole.values)
                      DropdownMenuItem(value: r, child: Text(bookRoleLabel(l10n, r))),
                  ],
                  onChanged: editing ? null : (r) => setState(() => _role = r ?? _role),
                ),
                const FormGap(),
                AppTextField(
                  key: const ValueKey('acct-map-qualifier'),
                  controller: _fields['qualifier'],
                  label: l10n.acctMapQualifier,
                  enabled: !editing,
                  error: keyError,
                ),
              ],
              AccountingMapKind.tax => [
                AppTextField(
                  key: const ValueKey('acct-map-tax'),
                  controller: _fields['tax'],
                  label: l10n.acctMapTaxKey,
                  helper: l10n.acctMapTaxKeyHelper,
                  enabled: !editing,
                  error: keyError,
                ),
              ],
              AccountingMapKind.party => [
                DropdownButtonFormField<String>(
                  key: const ValueKey('acct-map-member'),
                  initialValue: _member,
                  decoration: InputDecoration(
                    labelText: l10n.acctMapParty,
                    errorText: keyError,
                  ),
                  items: [
                    for (final e in (names.entries.toList()
                      ..sort((a, b) => a.value.compareTo(b.value))))
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: editing ? null : (id) => setState(() => _member = id),
                ),
              ],
            },
            const FormGap(),
            AppTextField(
              key: const ValueKey('acct-map-code'),
              controller: _fields['code'],
              label: l10n.acctMapRemoteCode,
              maxLength: 100,
              error: _problem == MapDraftProblem.remote ? l10n.acctMapRemoteMissing : null,
            ),
            AppTextField(
              key: const ValueKey('acct-map-id'),
              controller: _fields['id'],
              label: l10n.acctMapRemoteId,
              maxLength: 200,
            ),
            AppTextField(
              key: const ValueKey('acct-map-name'),
              controller: _fields['name'],
              label: l10n.acctMapRemoteName,
              maxLength: 200,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('acct-map-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('acct-map-save'),
          onPressed: _save,
          child: Text(MaterialLocalizations.of(context).saveButtonLabel),
        ),
      ],
    );
  }
}
