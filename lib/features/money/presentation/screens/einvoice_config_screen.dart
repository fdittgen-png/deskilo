// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/inline_banner.dart';
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
  // Test environments (#393): rehearsal endpoints beside the real one.
  final _uatEndpoint = TextEditingController();
  final _uatToken = TextEditingController();
  final _devEndpoint = TextEditingController();
  final _devToken = TextEditingController();
  bool _saving = false;
  bool _loaded = false;

  @override
  void dispose() {
    _endpoint.dispose();
    _token.dispose();
    _header.dispose();
    _field.dispose();
    _uatEndpoint.dispose();
    _uatToken.dispose();
    _devEndpoint.dispose();
    _devToken.dispose();
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
              'endpoint_uat': _uatEndpoint.text.trim(),
              'auth_value_uat': _uatToken.text.trim(),
              'endpoint_dev': _devEndpoint.text.trim(),
              'auth_value_dev': _devToken.text.trim(),
            },
          ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!saved) return;
    _token.clear();
    _uatToken.clear();
    _devToken.clear();
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
    _uatEndpoint.clear();
    _uatToken.clear();
    _devEndpoint.clear();
    _devToken.clear();
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
      // Pre-0074 the server reports suffixed endpoints as secrets instead
      // of echoing them; the fields then simply start blank. Saving still
      // works — degraded read-back, never broken config.
      _uatEndpoint.text = status.fields['endpoint_uat'] ?? '';
      _devEndpoint.text = status.fields['endpoint_dev'] ?? '';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.einvoiceConfigTitle ?? 'E-invoicing platform'),
      ),
      // An unreachable probe used to leave the screen spinning for ever
      // (field report): a failing RPC is now something the owner can see
      // and retry, not a blank page.
      body: switch (statusAsync) {
        AsyncError() => ListView(
            padding: AppSpacing.gutterAll,
            children: [
              InlineBanner(
                key: const ValueKey('einvoice-config-error'),
                icon: Icons.cloud_off_outlined,
                text: l10n?.einvoiceConfigUnavailable ??
                    'The platform settings could not be loaded. Check your '
                        'connection and try again.',
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                key: const ValueKey('einvoice-config-retry'),
                onPressed: () => ref.invalidate(eInvoiceStatusProvider),
                child: Text(l10n?.commonRetry ?? 'Try again'),
              ),
            ],
          ),
        _ when status == null => const LoadingView(),
        _ => ListView(
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
                Text(
                  l10n?.einvoiceTestEnvsTitle ??
                      'Test environments (UAT / Dev)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n?.einvoiceTestEnvsHelp ??
                      'Separate endpoints and tokens for rehearsals. The '
                          'choice appears at send time only while developer '
                          'mode is on.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const ValueKey('einvoice-endpoint-uat'),
                  controller: _uatEndpoint,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: l10n?.einvoiceUatEndpoint ?? 'UAT upload URL',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const ValueKey('einvoice-token-uat'),
                  controller: _uatToken,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText:
                        l10n?.einvoiceUatToken ?? 'UAT token or credential',
                    helperText: status.secretsSet.contains('auth_value_uat')
                        ? (l10n?.einvoiceConfigTokenSet ??
                            'A token is stored (type a new one to replace '
                                'it).')
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const ValueKey('einvoice-endpoint-dev'),
                  controller: _devEndpoint,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: l10n?.einvoiceDevEndpoint ?? 'Dev upload URL',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const ValueKey('einvoice-token-dev'),
                  controller: _devToken,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText:
                        l10n?.einvoiceDevToken ?? 'Dev token or credential',
                    helperText: status.secretsSet.contains('auth_value_dev')
                        ? (l10n?.einvoiceConfigTokenSet ??
                            'A token is stored (type a new one to replace '
                                'it).')
                        : null,
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
      },
    );
  }
}
