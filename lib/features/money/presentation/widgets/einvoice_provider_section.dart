// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/einvoice_gateway.dart';
import '../../domain/einvoice_providers.dart';

/// #2358 — the connector the space sends through, and the fields that
/// connector needs. Holds its own controllers so the screen only asks it
/// for [values] when it saves.
class EInvoiceProviderForm {
  String provider = 'generic';
  final Map<String, TextEditingController> _fields = {};

  TextEditingController controllerFor(String field) =>
      _fields.putIfAbsent(field, TextEditingController.new);

  /// Fills the non-secret fields the server echoes back.
  void load(EInvoiceProviderStatus status) {
    provider = eInvoiceProviderFields.containsKey(status.provider)
        ? status.provider
        : 'generic';
    for (final fields in eInvoiceProviderFields.values) {
      for (final field in fields) {
        if (eInvoiceSecretFields.contains(field)) continue;
        controllerFor(field).text = status.fields[field] ?? '';
        final test = eInvoiceTestKey(field);
        controllerFor(test).text = status.fields[test] ?? '';
      }
    }
  }

  /// The provider and its fields, for set_einvoice_credentials. A blank
  /// field keeps its stored value there (0071's merge), so a secret is
  /// never re-typed to change an address. The generic connector's own
  /// fields stay with the screen that always had them.
  Map<String, String> values() => {
    'provider': provider,
    if (provider != 'generic')
      for (final field in eInvoiceProviderFields[provider]!) ...{
        field: controllerFor(field).text.trim(),
        // #3882 — the test environment's twin, kept apart from production.
        eInvoiceTestKey(field): controllerFor(eInvoiceTestKey(field)).text.trim(),
      },
  };

  void clearSecrets() {
    for (final field in eInvoiceSecretFields) {
      _fields[field]?.clear();
      _fields[eInvoiceTestKey(field)]?.clear();
    }
  }

  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
  }
}

String eInvoiceProviderName(AppLocalizations l10n, String provider) =>
    switch (provider) {
      'peppol' => l10n.eInvoiceProviderPeppol,
      'fr_pa' => l10n.eInvoiceProviderFrPa,
      'it_sdi' => l10n.eInvoiceProviderItSdi,
      'pl_ksef' => l10n.eInvoiceProviderPlKsef,
      'ro_efactura' => l10n.eInvoiceProviderRoEfactura,
      _ => l10n.eInvoiceProviderGeneric,
    };

String eInvoiceFieldLabel(AppLocalizations l10n, String field) => switch (field) {
  'base_url' => l10n.eInvoiceFieldBaseUrl,
  'api_key' => l10n.eInvoiceFieldApiKey,
  'legal_entity_id' => l10n.eInvoiceFieldLegalEntityId,
  'token_url' => l10n.eInvoiceFieldTokenUrl,
  'client_id' => l10n.eInvoiceFieldClientId,
  'client_secret' => l10n.eInvoiceFieldClientSecret,
  'login_url' => l10n.eInvoiceFieldLoginUrl,
  'username' => l10n.eInvoiceFieldUsername,
  'password' => l10n.eInvoiceFieldPassword,
  'nip' => l10n.eInvoiceFieldNip,
  'ksef_token' => l10n.eInvoiceFieldKsefToken,
  'cif' => l10n.eInvoiceFieldCif,
  'access_token' => l10n.eInvoiceFieldAccessToken,
  _ => field,
};

/// The picker and, for a named connector, its fields. The generic
/// connector's fields are the screen's own (they predate this section).
class EInvoiceProviderSection extends StatelessWidget {
  const EInvoiceProviderSection({
    super.key,
    required this.form,
    required this.secretsSet,
    required this.onChanged,
  });

  final EInvoiceProviderForm form;
  final List<String> secretsSet;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final provider = form.provider;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: const ValueKey('einvoice-provider'),
          initialValue: provider,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.eInvoiceProviderLabel),
          items: [
            for (final name in eInvoiceProviderFields.keys)
              DropdownMenuItem(
                value: name,
                child: Text(
                  eInvoiceProviderName(l10n, name),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            form.provider = value;
            onChanged(value);
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.eInvoiceProviderHelp,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (provider != 'generic') ...[
          for (final field in eInvoiceProviderFields[provider]!) ...[
            const SizedBox(height: AppSpacing.md),
            _field(l10n, field, field),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.eInvoiceTestFieldsTitle,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.eInvoiceTestFieldsHelp,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          for (final field in eInvoiceProviderFields[provider]!) ...[
            const SizedBox(height: AppSpacing.md),
            _field(l10n, field, eInvoiceTestKey(field), test: true),
          ],
        ],
      ],
    );
  }

  /// One connector field: [field] its base name, [key] the key it is saved
  /// under. The test twin is obscured when its base is, and never logged.
  Widget _field(
    AppLocalizations l10n,
    String field,
    String key, {
    bool test = false,
  }) {
    final secret = eInvoiceSecretFields.contains(field);
    final label = eInvoiceFieldLabel(l10n, field);
    final String? sandbox = eInvoiceSandboxDefaults[form.provider]?[field];
    return AppTextField(
      key: ValueKey('einvoice-provider-$key'),
      controller: form.controllerFor(key),
      label: test ? l10n.eInvoiceTestFieldLabel(label) : label,
      obscureText: secret,
      keyboardType: field.endsWith('_url')
          ? TextInputType.url
          : TextInputType.text,
      // A stored secret says it is set. The documented sandbox address is
      // offered on the test twin only: typed in the production field it was
      // sent, and recorded, as production.
      helper: secret && secretsSet.contains(key)
          ? l10n.eInvoiceFieldSecretSet
          : (test ? sandbox : null),
    );
  }
}
