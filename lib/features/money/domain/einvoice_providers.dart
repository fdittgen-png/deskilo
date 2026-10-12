// SPDX-License-Identifier: AGPL-3.0-or-later

/// #2358 — the connectors the send-e-invoice function speaks, and what
/// each needs before it can send. Mirrors `requiredFields` and `SANDBOX`
/// in supabase/functions/send-e-invoice/connectors.ts, which
/// test/lint/einvoice_providers_test.dart keeps in step: the screen asks
/// for exactly what the function will refuse without.
const Map<String, List<String>> eInvoiceProviderFields = {
  'generic': ['endpoint', 'auth_value'],
  'peppol': ['base_url', 'api_key', 'legal_entity_id'],
  'fr_pa': ['base_url', 'token_url', 'client_id', 'client_secret'],
  'it_sdi': ['base_url', 'login_url', 'username', 'password'],
  'pl_ksef': ['base_url', 'nip', 'ksef_token'],
  'ro_efactura': ['base_url', 'cif', 'access_token'],
};

/// The fields that are secrets: typed, stored in Vault (0414), never shown
/// again — the screen only says that one is set.
const eInvoiceSecretFields = {
  'auth_value',
  'api_key',
  'client_secret',
  'password',
  'ksef_token',
  'access_token',
};

/// The documented test environments, offered as the field's hint so an
/// owner trying a sandbox does not have to look the address up. A French
/// accredited platform has none shared: its URLs are its own.
const Map<String, Map<String, String>> eInvoiceSandboxDefaults = {
  'peppol': {'base_url': 'https://api.storecove.com'},
  'it_sdi': {
    'base_url': 'https://api-sandbox.acubeapi.com',
    'login_url': 'https://common-sandbox.api.acubeapi.com/login',
  },
  'pl_ksef': {'base_url': 'https://ksef-test.mf.gov.pl/api/v2'},
  'ro_efactura': {'base_url': 'https://api.anaf.ro/test/FCTEL/rest'},
};
