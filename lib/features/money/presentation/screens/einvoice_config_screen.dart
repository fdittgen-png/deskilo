// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../providers/money_providers.dart';

/// Where the workspace's invoices are POSTED (0073) — owner-only.
///
/// Deliberately generic: France has no free public channel any more, so a
/// workspace works through a *plateforme agréée*; elsewhere it is a Peppol
/// access point or a national platform. They all accept an upload with a
/// credential, so that is what the app asks for — an endpoint and a token,
/// not a vendor list that would go stale.
///
/// The token goes to a deny-all table through an owner-gated RPC and never
/// comes back out: the screen can only report that one is stored.
class EInvoiceConfigScreen extends ConsumerStatefulWidget {
  const EInvoiceConfigScreen({super.key});

  @override
  ConsumerState<EInvoiceConfigScreen> createState() =>
      _EInvoiceConfigScreenState();
}

class _EInvoiceConfigScreenState extends ConsumerState<EInvoiceConfigScreen> {
  final _endpoint = TextEditingController();
  final _token = TextEditingController();
  final _header = TextEditingController();
  final _field = TextEditingController();
  bool _saving = false;
  bool _loaded = false;

  @override
  void dispose() {
    _endpoint.dispose();
    _token.dispose();
    _header.dispose();
    _field.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    setState(() => _saving = true);
    final saved = await runGuarded(
      context,
      domain: 'money',
      message: 'e-invoice platform save failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => ref.read(moneyRepositoryProvider).setEInvoiceCredentials(
            workspace.id,
            {
              'endpoint': _endpoint.text.trim(),
              // Blank keeps the stored token — the owner can change the
              // endpoint without re-typing a secret they cannot read.
              'auth_value': _token.text.trim(),
              'auth_header': _header.text.trim(),
              'field_name': _field.text.trim(),
            },
          ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!saved) return;
    _token.clear();
    ref
      ..invalidate(eInvoiceStatusProvider)
      ..invalidate(eInvoiceGatewayProvider);
    if (!mounted) return;
    AppSnack.success(context, l10n?.einvoiceConfigSaved ?? 'Platform saved.');
  }

  Future<void> _clear() async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    if (!await runGuarded(
      context,
      domain: 'money',
      message: 'e-invoice platform clear failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => ref
          .read(moneyRepositoryProvider)
          .clearEInvoiceCredentials(workspace.id),
    )) {
      return;
    }
    _endpoint.clear();
    _token.clear();
    _header.clear();
    _field.clear();
    ref
      ..invalidate(eInvoiceStatusProvider)
      ..invalidate(eInvoiceGatewayProvider);
    if (!mounted) return;
    AppSnack.success(
      context,
      l10n?.einvoiceConfigCleared ?? 'Platform removed.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statusAsync = ref.watch(eInvoiceStatusProvider);
    final status = statusAsync.value;
    if (status != null && !_loaded) {
      _loaded = true;
      _endpoint.text = status.fields['endpoint'] ?? '';
      _header.text = status.fields['auth_header'] ?? '';
      _field.text = status.fields['field_name'] ?? '';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.einvoiceConfigTitle ?? 'E-invoicing platform'),
      ),
      body: status == null
          ? const LoadingView()
          : ListView(
              padding: AppSpacing.gutterAll,
              children: [
                Text(
                  l10n?.einvoiceConfigIntro ??
                      'Where DesKilo posts your invoices. The token is '
                          'stored server-side and never comes back out.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  key: const ValueKey('einvoice-endpoint'),
                  controller: _endpoint,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: l10n?.einvoiceConfigEndpoint ?? 'Upload URL',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const ValueKey('einvoice-token'),
                  controller: _token,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText:
                        l10n?.einvoiceConfigToken ?? 'Token or credential',
                    helperMaxLines: 2,
                    helperText: status.secretsSet.contains('auth_value')
                        ? (l10n?.einvoiceConfigTokenSet ??
                            'A token is stored (type a new one to replace '
                                'it).')
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const ValueKey('einvoice-header'),
                  controller: _header,
                  decoration: InputDecoration(
                    labelText: l10n?.einvoiceConfigHeader ?? 'Auth header',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const ValueKey('einvoice-field'),
                  controller: _field,
                  decoration: InputDecoration(
                    labelText: l10n?.einvoiceConfigField ?? 'File field name',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  key: const ValueKey('einvoice-save'),
                  onPressed: _saving ? null : _save,
                  child: Text(l10n?.commonSave ?? 'Save'),
                ),
                if (status.configured) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    key: const ValueKey('einvoice-clear'),
                    onPressed: _saving ? null : _clear,
                    child: Text(
                      l10n?.einvoiceConfigClear ?? 'Remove the platform',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
