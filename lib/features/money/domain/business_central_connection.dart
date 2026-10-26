// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2374 — what a Business Central connection is made of: the client id and
// secret of the Microsoft Entra application the company's administrator
// registered (kept as the connection's token, in Vault), and the company
// it reaches, named by tenant, environment and company id (kept as the
// connection's remote company). The adapter reads both back in the same
// shapes (supabase/functions/_shared/accounting_business_central.ts,
// `CREDENTIAL_SEPARATOR` and `COMPANY_ADDRESS`; pinned by
// accounting_targets_business_central_test).
//
// Pure Dart.
import 'package:meta/meta.dart';

import 'accounting_connection.dart' show accountingTokenLength;

/// A field of the Business Central connection form.
enum EntraField { clientId, secret, tenant, environment, company }

const _guid =
    '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}';

/// The characters of a GUID written with its hyphens.
const _guidLength = 36;

/// The longest tenant domain and environment name the address takes.
/// spec: an environment name is at most 30 characters.
const _tenantLength = 100;
const _environmentLength = 30;

/// The longest value of each field of the form.
const Map<EntraField, int> entraFieldLength = {
  EntraField.clientId: _guidLength,
  EntraField.tenant: _tenantLength,
  EntraField.environment: _environmentLength,
  EntraField.company: _guidLength,
};

/// An Entra tenant: its id or a verified domain.
const _tenant = '[A-Za-z0-9][A-Za-z0-9.-]{0,${_tenantLength - 1}}';

/// A Business Central environment's name (production or a sandbox).
const _environment = '[A-Za-z0-9][A-Za-z0-9_-]{0,${_environmentLength - 1}}';

/// The tenant, the environment's name and the company's id, as one remote
/// company: the adapter's `COMPANY_ADDRESS`.
@visibleForTesting
const entraCompanyAddressPattern = '^($_tenant)\\/($_environment)\\/($_guid)\$';

/// What separates the client id from the secret in the kept credential:
/// the adapter's `CREDENTIAL_SEPARATOR`.
@visibleForTesting
const entraCredentialSeparator = ':';

final _guidOnly = RegExp('^$_guid\$');
final _tenantOnly = RegExp('^$_tenant\$');
final _environmentOnly = RegExp('^$_environment\$');
final _address = RegExp(entraCompanyAddressPattern);

/// The longest secret a connection keeps: the token's bound
/// (`accountingTokenLength.max`) less a client id and the separator.
final entraSecretMaxLength =
    accountingTokenLength.max - _guidLength - entraCredentialSeparator.length;

/// The token and the remote company of a Business Central connection, or
/// the first field that does not have its expected form.
sealed class EntraConnection {
  const EntraConnection();

  /// Composes the connection from its fields, trimmed. [tenant],
  /// [environment] and [company] are null when the company is kept (a
  /// replaced secret of an existing connection).
  static EntraConnection of({
    required String clientId,
    required String secret,
    String? tenant,
    String? environment,
    String? company,
  }) {
    final id = clientId.trim();
    final value = secret.trim();
    if (!_guidOnly.hasMatch(id)) return const EntraInvalid(EntraField.clientId);
    if (value.isEmpty || value.length > entraSecretMaxLength) {
      return const EntraInvalid(EntraField.secret);
    }
    if (tenant == null || environment == null || company == null) {
      return EntraValid('$id$entraCredentialSeparator$value', null);
    }
    final address = '${tenant.trim()}/${environment.trim()}/${company.trim()}';
    if (_address.hasMatch(address)) {
      return EntraValid('$id$entraCredentialSeparator$value', address);
    }
    // The address the adapter reads does not form: the first field that
    // does not have its own form is named.
    if (!_tenantOnly.hasMatch(tenant.trim())) {
      return const EntraInvalid(EntraField.tenant);
    }
    if (!_environmentOnly.hasMatch(environment.trim())) {
      return const EntraInvalid(EntraField.environment);
    }
    return const EntraInvalid(EntraField.company);
  }
}

/// The token to keep and the remote company (null: unchanged).
final class EntraValid extends EntraConnection {
  const EntraValid(this.token, this.remoteTenantId);
  final String token;
  final String? remoteTenantId;
}

/// [field] does not have its expected form; nothing is sent.
final class EntraInvalid extends EntraConnection {
  const EntraInvalid(this.field);
  final EntraField field;
}
