// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1629 — the MCP API reference. It documents the ACTUAL routes (one MCP
// JSON-RPC endpoint and the native RPCs) from contracts/mcp; nothing here
// is a second backend or a permission check. Safe defaults:
//  * no external validator (validatorUrl: null) — the spec never leaves;
//  * no ?url=/?configUrl= injection (queryConfigEnabled: false);
//  * authorization is not persisted across reloads;
//  * OAuth uses the authorization code flow with PKCE, and the redirect
//    lands on this folder's own page.
export const SWAGGER_OPTIONS = {
  url: './openapi.json',
  dom_id: '#swagger-ui',
  validatorUrl: null,
  queryConfigEnabled: false,
  persistAuthorization: false,
  deepLinking: false,
  tryItOutEnabled: false,
};

export const OAUTH_OPTIONS = {
  usePkceWithAuthorizationCodeGrant: true,
};

if (typeof window !== 'undefined' && typeof window.SwaggerUIBundle === 'function') {
  const ui = window.SwaggerUIBundle({
    ...SWAGGER_OPTIONS,
    oauth2RedirectUrl: new URL('oauth2-redirect.html', window.location.href).href,
  });
  ui.initOAuth(OAUTH_OPTIONS);
}
