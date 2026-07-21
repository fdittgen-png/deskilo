// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/payment_provider.dart';
import '../../providers/money_providers.dart';

/// Owner-only online-payment configuration (migration 0047): enter each
/// provider's server credentials from the app instead of the CLI. Secrets
/// go to the deny-all `payment_credentials` table via an owner-gated RPC
/// and are never read back — a set secret shows as "•••• set" and blank
/// means "keep". Each community configures its OWN provider account.
class PaymentConfigScreen extends ConsumerStatefulWidget {
  const PaymentConfigScreen({super.key});

  @override
  ConsumerState<PaymentConfigScreen> createState() =>
      _PaymentConfigScreenState();
}

class _PaymentConfigScreenState extends ConsumerState<PaymentConfigScreen> {
  Map<PaymentProvider, PaymentProviderStatus>? _status;

  @override
  void initState() {
    super.initState();
    // Post-frame: _load reads AppLocalizations (via runGuarded), which
    // needs an established inherited context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    Map<PaymentProvider, PaymentProviderStatus> status = const {};
    if (!await runGuarded(
      context,
      domain: 'payments',
      message: 'payment config load failed',
      errorText: AppLocalizations.of(context)?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        status = await ref
            .read(moneyRepositoryProvider)
            .fetchPaymentGatewayStatus(workspace.id);
      },
    )) {
      return;
    }
    if (mounted) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = _status;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.payConfigTitle ?? 'Online payments'),
      ),
      body: status == null
          ? const LoadingView()
          : ListView(
              padding: AppSpacing.gutterAll,
              children: [
                Text(
                  l10n?.payConfigIntro ??
                      'Enter each payment provider you want to offer. '
                          'Keys are stored securely on the server and never '
                          'shown again. See '
                          'docs/design/payments-integration.md.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                for (final provider in PaymentProvider.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _ProviderCard(
                      key: ValueKey('pay-config-${provider.wireName}'),
                      provider: provider,
                      status: status[provider] ??
                          const PaymentProviderStatus(),
                      onChanged: _load,
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ProviderCard extends ConsumerStatefulWidget {
  const _ProviderCard({
    super.key,
    required this.provider,
    required this.status,
    required this.onChanged,
  });

  final PaymentProvider provider;
  final PaymentProviderStatus status;
  final Future<void> Function() onChanged;

  @override
  ConsumerState<_ProviderCard> createState() => _ProviderCardState();
}

class _ProviderCardState extends ConsumerState<_ProviderCard> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    for (final field in paymentProviderFields[widget.provider]!) {
      // Non-secret fields are seeded with their current value (echoed by
      // the status); secret fields always start blank.
      // Non-secret fields seed with their current value; a choice field
      // (env) defaults to its first option so it always sends a value.
      final current = field.secret
          ? ''
          : widget.status.publicFields[field.key] ??
              (field.options?.first ?? '');
      _controllers[field.key] = TextEditingController(text: current);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _fieldLabel(AppLocalizations? l10n, String key) => switch (key) {
        'client_id' => l10n?.payFieldClientId ?? 'Client ID',
        'secret' => l10n?.payFieldSecret ?? 'Secret',
        'env' => l10n?.payFieldEnv ?? 'Environment',
        'webhook_id' => l10n?.payFieldWebhookId ?? 'Webhook ID',
        'return_url' => l10n?.payFieldReturnUrl ?? 'Return URL',
        'secret_key' => l10n?.payFieldSecretKey ?? 'Secret key',
        'webhook_secret' =>
          l10n?.payFieldWebhookSecret ?? 'Webhook signing secret',
        'api_key' => l10n?.payFieldApiKey ?? 'API key',
        _ => key,
      };

  String _providerLabel(AppLocalizations? l10n) => switch (widget.provider) {
        PaymentProvider.paypal => l10n?.paymentMethodPaypal ?? 'PayPal',
        PaymentProvider.stripe =>
          l10n?.paymentProviderStripe ?? 'Credit card (Stripe)',
        PaymentProvider.mollie =>
          l10n?.paymentProviderMollie ?? 'Mollie — iDEAL, Bancontact…',
        PaymentProvider.wero =>
          l10n?.paymentProviderWero ?? 'Wero (via Mollie)',
      };

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final config = {
      for (final e in _controllers.entries)
        if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
    };
    if (config.isEmpty) return;
    if (!await runGuarded(
      context,
      domain: 'payments',
      message: 'payment config save failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => ref.read(moneyRepositoryProvider).setPaymentCredentials(
            workspace.id,
            widget.provider,
            config,
          ),
    )) {
      return;
    }
    if (!mounted) return;
    AppSnack.success(context, l10n?.payConfigSaved ?? 'Saved.');
    // Clear the secret fields again (never re-shown) and reload the status.
    for (final field in paymentProviderFields[widget.provider]!) {
      if (field.secret) _controllers[field.key]!.clear();
    }
    await widget.onChanged();
  }

  Future<void> _remove() async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    if (!await runGuarded(
      context,
      domain: 'payments',
      message: 'payment config clear failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => ref
          .read(moneyRepositoryProvider)
          .clearPaymentProvider(workspace.id, widget.provider),
    )) {
      return;
    }
    if (!mounted) return;
    AppSnack.success(context, l10n?.payConfigRemoved ?? 'Removed.');
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: AppSpacing.gutterAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _providerLabel(l10n),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Chip(
                  label: Text(
                    widget.status.configured
                        ? (l10n?.payConfigConfigured ?? 'Configured')
                        : (l10n?.payConfigNotConfigured ?? 'Not configured'),
                    style: theme.textTheme.labelSmall,
                  ),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: widget.status.configured
                      ? theme.colorScheme.secondaryContainer
                      : null,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final field in paymentProviderFields[widget.provider]!)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: field.options != null
                    ? DropdownButtonFormField<String>(
                        initialValue: _controllers[field.key]!.text.isEmpty
                            ? field.options!.first
                            : _controllers[field.key]!.text,
                        decoration: InputDecoration(
                          labelText: _fieldLabel(l10n, field.key),
                        ),
                        items: [
                          for (final option in field.options!)
                            DropdownMenuItem(
                              value: option,
                              child: Text(option),
                            ),
                        ],
                        onChanged: (v) =>
                            _controllers[field.key]!.text = v ?? '',
                      )
                    : TextField(
                        key: ValueKey(
                          'pay-field-${widget.provider.wireName}-${field.key}',
                        ),
                        controller: _controllers[field.key],
                        obscureText: field.secret,
                        decoration: InputDecoration(
                          labelText: _fieldLabel(l10n, field.key),
                          helperText: field.secret &&
                                  widget.status.secretKeysSet
                                      .contains(field.key)
                              ? (l10n?.payConfigSecretSet ??
                                  'Set — leave blank to keep')
                              : null,
                        ),
                      ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (widget.status.configured)
                  TextButton(
                    onPressed: _remove,
                    child: Text(l10n?.payConfigRemove ?? 'Remove'),
                  ),
                const Spacer(),
                FilledButton(
                  key: ValueKey(
                    'pay-save-${widget.provider.wireName}',
                  ),
                  onPressed: _save,
                  child: Text(l10n?.commonSave ?? 'Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
