// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/einvoice_gateway.dart';
import '../../providers/money_providers.dart';
import '../widgets/einvoice_inbox_section.dart';
import '../widgets/einvoice_provider_section.dart';

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
  // #2358 — the connector and its own fields.
  final _providerForm = EInvoiceProviderForm();
  final _endpoint = TextEditingController();
  final _token = TextEditingController();
  final _header = TextEditingController();
  final _field = TextEditingController();
  // Test environments (#393): rehearsal endpoints beside the real one.
  final _uatEndpoint = TextEditingController();
  final _uatToken = TextEditingController();
  final _devEndpoint = TextEditingController();
  final _devToken = TextEditingController();
  // The customer's delivery service (#568): the second leg, its own
  // endpoint and credential.
  final _customerEndpoint = TextEditingController();
  final _customerToken = TextEditingController();
  final _customerHeader = TextEditingController();
  final _customerField = TextEditingController();
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
    _customerEndpoint.dispose();
    _customerToken.dispose();
    _customerHeader.dispose();
    _customerField.dispose();
    _providerForm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    setState(() => _saving = true);
    final saved = await runGuarded(
      context,
      domain: 'money',
      message: 'e-invoice platform save failed',
      errorText: l10n.workspaceGenericError,
      action: () => ref.read(moneyRepositoryProvider).setEInvoiceCredentials(
            workspace.id,
            {
              ..._providerForm.values(),
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
              // #568 — the customer leg, same merge semantics.
              'customer_endpoint': _customerEndpoint.text.trim(),
              'customer_auth_value': _customerToken.text.trim(),
              'customer_auth_header': _customerHeader.text.trim(),
              'customer_field_name': _customerField.text.trim(),
            },
          ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!saved) return;
    _token.clear();
    _uatToken.clear();
    _devToken.clear();
    _customerToken.clear();
    _providerForm.clearSecrets();
    ref
      ..invalidate(eInvoiceStatusProvider)
      ..invalidate(eInvoiceGatewayProvider);
    if (!mounted) return;
    AppSnack.success(context, l10n.einvoiceConfigSaved);
  }

  Future<void> _clear() async {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    if (!await runGuarded(
      context,
      domain: 'money',
      message: 'e-invoice platform clear failed',
      errorText: l10n.workspaceGenericError,
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
    _customerEndpoint.clear();
    _customerToken.clear();
    _customerHeader.clear();
    _customerField.clear();
    _providerForm.load(const EInvoiceProviderStatus(configured: false));
    ref
      ..invalidate(eInvoiceStatusProvider)
      ..invalidate(eInvoiceGatewayProvider);
    if (!mounted) return;
    AppSnack.success(
      context,
      l10n.einvoiceConfigCleared,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final statusAsync = ref.watch(eInvoiceStatusProvider);
    final status = statusAsync.value;
    if (status != null && !_loaded) {
      _loaded = true;
      _providerForm.load(status);
      _endpoint.text = status.fields['endpoint'] ?? '';
      _header.text = status.fields['auth_header'] ?? '';
      _field.text = status.fields['field_name'] ?? '';
      // Pre-0074 the server reports suffixed endpoints as secrets instead
      // of echoing them; the fields then simply start blank. Saving still
      // works — degraded read-back, never broken config.
      _uatEndpoint.text = status.fields['endpoint_uat'] ?? '';
      _devEndpoint.text = status.fields['endpoint_dev'] ?? '';
      // Pre-0112 the customer keys are classified secret the same way.
      _customerEndpoint.text = status.fields['customer_endpoint'] ?? '';
      _customerHeader.text = status.fields['customer_auth_header'] ?? '';
      _customerField.text = status.fields['customer_field_name'] ?? '';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.einvoiceConfigTitle),
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
                text: l10n.einvoiceConfigUnavailable,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                key: const ValueKey('einvoice-config-retry'),
                onPressed: () => ref.invalidate(eInvoiceStatusProvider),
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        _ when status == null => const LoadingView(),
        _ => ListView(
              padding: AppSpacing.gutterAll,
              children: [
                Text(
                  l10n.einvoiceConfigIntro,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
                EInvoiceProviderSection(
                  key: const ValueKey('einvoice-provider-section'),
                  form: _providerForm,
                  secretsSet: status.secretsSet,
                  onChanged: (_) => setState(() {}),
                ),
                if (_providerForm.provider == 'generic') ...[
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const ValueKey('einvoice-endpoint'),
                  controller: _endpoint,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: l10n.einvoiceConfigEndpoint,
                    suffixIcon: HelpDot(
                      l10n.helpTopicEinvoice,
                      anchor: HelpAnchor.einvoiceEndpoint,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const ValueKey('einvoice-token'),
                  controller: _token,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText:
                        l10n.einvoiceConfigToken,
                    helperMaxLines: 2,
                    helperText: status.secretsSet.contains('auth_value')
                        ? (l10n.einvoiceConfigTokenSet)
                        : null,
                    suffixIcon: HelpDot(
                      l10n.helpTopicEinvoice,
                      anchor: HelpAnchor.einvoiceToken,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const ValueKey('einvoice-header'),
                  controller: _header,
                  decoration: InputDecoration(
                    labelText: l10n.einvoiceConfigHeader,
                    suffixIcon: HelpDot(
                      l10n.helpTopicEinvoice,
                      anchor: HelpAnchor.einvoiceAuthHeader,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const ValueKey('einvoice-field'),
                  controller: _field,
                  decoration: InputDecoration(
                    labelText: l10n.einvoiceConfigField,
                    suffixIcon: HelpDot(
                      l10n.helpTopicEinvoice,
                      anchor: HelpAnchor.einvoiceFileField,
                    ),
                  ),
                ),
                ],
                // #568 — the customer's own delivery service, beside the
                // government platform above. Behind its feature flag.
                if (ref
                    .watch(enabledFeaturesSyncProvider)
                    .contains(WorkspaceFeature.einvoiceCustomerDelivery)) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.einvoiceCustomerSectionTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.einvoiceCustomerSectionHelp,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const ValueKey('einvoice-customer-endpoint'),
                    controller: _customerEndpoint,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: l10n.einvoiceConfigEndpoint,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const ValueKey('einvoice-customer-token'),
                    controller: _customerToken,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText:
                          l10n.einvoiceConfigToken,
                      helperMaxLines: 2,
                      helperText:
                          status.secretsSet.contains('customer_auth_value')
                              ? (l10n.einvoiceConfigTokenSet)
                              : null,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const ValueKey('einvoice-customer-header'),
                    controller: _customerHeader,
                    decoration: InputDecoration(
                      labelText: l10n.einvoiceConfigHeader,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const ValueKey('einvoice-customer-field'),
                    controller: _customerField,
                    decoration: InputDecoration(
                      labelText:
                          l10n.einvoiceConfigField,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.einvoiceTestEnvsTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.einvoiceTestEnvsHelp,
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
                    labelText: l10n.einvoiceUatEndpoint,
                    suffixIcon: HelpDot(
                      l10n.helpTopicEinvoice,
                      anchor: HelpAnchor.einvoiceUat,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const ValueKey('einvoice-token-uat'),
                  controller: _uatToken,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText:
                        l10n.einvoiceUatToken,
                    helperText: status.secretsSet.contains('auth_value_uat')
                        ? (l10n.einvoiceConfigTokenSet)
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const ValueKey('einvoice-endpoint-dev'),
                  controller: _devEndpoint,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: l10n.einvoiceDevEndpoint,
                    suffixIcon: HelpDot(
                      l10n.helpTopicEinvoice,
                      anchor: HelpAnchor.einvoiceDev,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const ValueKey('einvoice-token-dev'),
                  controller: _devToken,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText:
                        l10n.einvoiceDevToken,
                    helperText: status.secretsSet.contains('auth_value_dev')
                        ? (l10n.einvoiceConfigTokenSet)
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  key: const ValueKey('einvoice-save'),
                  onPressed: _saving ? null : _save,
                  child: Text(l10n.commonSave),
                ),
                if (status.configured) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    key: const ValueKey('einvoice-clear'),
                    onPressed: _saving ? null : _clear,
                    child: Text(
                      l10n.einvoiceConfigClear,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
                // #2358 — the supplier invoices that reached the space.
                if (ref
                        .watch(enabledFeaturesSyncProvider)
                        .contains(WorkspaceFeature.einvoiceCustomerDelivery) &&
                    ref.watch(currentWorkspaceProvider).value != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  EInvoiceInboxSection(
                    workspaceId: ref.watch(currentWorkspaceProvider).value!.id,
                  ),
                ],
              ],
            ),
      },
    );
  }
}
