// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1633 — the Auth half of readiness: native access (sign-in, confirmation,
// recovery mail) and canonical federation (the Auth URL, the issuer, the
// upstream callback, the keys, the identity hook).
//
// Three URLs are kept apart on purpose:
//   * the Auth external URL — where Auth answers; CONFIRMED by its own
//     discovery document, never built by appending `/auth/v1`;
//   * the upstream OIDC callback — `<Auth URL>/callback`, where a canonical
//     identity provider sends the person back;
//   * the app's Site URL and redirect allow-list — where Auth sends the
//     person after that, into the app (web path or `deskilo://`).
//
// Mail is judged from configuration only. No mail is ever sent as a probe,
// and nothing here writes the Auth configuration: an unconfirmed-signup
// problem is reported, never "fixed" by switching confirmation off.
import 'mcp_readiness.dart';
import 'mcp_readiness_checks.dart';

/// The Custom Access Token hook the canonical project runs (#1648).
const canonicalIdentityHookUri =
    'pg-functions://postgres/public/identity_federation_token_hook';

List<ReadinessCheck> nativeAccessChecks(
  McpTargetEvidence e,
  int requiredSchema,
) {
  const area = ReadinessArea.nativeAccess;
  final checks = <ReadinessCheck>[];
  final marker = e.schemaMarker;
  checks.add(
    marker == null
        ? const ReadinessCheck(
            area,
            'native_schema_compatible',
            CheckOutcome.unknown,
            'the schema version could not be read',
          )
        : marker < requiredSchema
        ? ReadinessCheck(
            area,
            'native_schema_compatible',
            CheckOutcome.fail,
            'schema $marker is behind this release ($requiredSchema): '
                'dart run tool/instance.dart install --ref <ref>',
          )
        : ReadinessCheck(
            area,
            'native_schema_compatible',
            CheckOutcome.pass,
            'schema $marker',
          ),
  );

  final auth = e.authConfig;
  if (auth == null) {
    checks.add(
      const ReadinessCheck(
        area,
        'native_auth_config',
        CheckOutcome.unknown,
        'the Auth configuration could not be read',
      ),
    );
    return checks;
  }
  final site = '${auth['site_url'] ?? ''}';
  final siteUri = Uri.tryParse(site);
  final siteOk =
      siteUri != null &&
      siteUri.host.isNotEmpty &&
      siteUri.scheme == 'https' &&
      siteUri.host != 'localhost' &&
      siteUri.host != '127.0.0.1';
  checks.add(
    ReadinessCheck(
      area,
      'native_site_url',
      siteOk ? CheckOutcome.pass : CheckOutcome.fail,
      siteOk
          ? site
          : 'the Site URL "$site" is not a public https address of the app; '
                'every mail link points there',
    ),
  );

  final allow = '${auth['uri_allow_list'] ?? ''}'
      .split(',')
      .map((s) => s.trim())
      .toSet();
  final sitePrefix = site.endsWith('/') ? '$site**' : '$site/**';
  final missing = [
    if (!allow.contains('deskilo://**')) 'deskilo://**',
    if (siteOk && !allow.contains(sitePrefix)) sitePrefix,
  ];
  checks.add(
    ReadinessCheck(
      area,
      'native_redirect_allow_list',
      missing.isEmpty ? CheckOutcome.pass : CheckOutcome.fail,
      missing.isEmpty
          ? ''
          : 'missing: ${missing.join(', ')} (an unlisted return falls back to the Site URL)',
    ),
  );
  checks.addAll(emailChecks(auth));
  return checks;
}

/// Confirmation, recovery and delivery, from configuration only.
List<ReadinessCheck> emailChecks(Map<String, Object?> auth) {
  const area = ReadinessArea.nativeAccess;
  final checks = <ReadinessCheck>[];
  String? text(String key) =>
      auth.containsKey(key) ? '${auth[key] ?? ''}' : null;

  // The app confirms a sign-up through a link to its own callback.
  final confirmation = text('mailer_templates_confirmation_content');
  if (auth['mailer_autoconfirm'] == true) {
    checks.add(
      const ReadinessCheck(
        area,
        'email_confirmation_link',
        CheckOutcome.pass,
        'accounts confirm themselves; no confirmation mail is sent',
      ),
    );
  } else if (confirmation == null) {
    checks.add(
      const ReadinessCheck(
        area,
        'email_confirmation_link',
        CheckOutcome.unknown,
        'this Auth version does not report the confirmation template',
      ),
    );
  } else {
    final ok =
        confirmation.isEmpty ||
        confirmation.contains('{{ .ConfirmationURL }}') ||
        confirmation.contains('{{ .TokenHash }}');
    checks.add(
      ReadinessCheck(
        area,
        'email_confirmation_link',
        ok ? CheckOutcome.pass : CheckOutcome.fail,
        ok
            ? (confirmation.isEmpty
                  ? 'default template (link)'
                  : 'custom template with a link')
            : 'confirmation_template_without_link: the app confirms through the link',
      ),
    );
  }

  // The app's password reset asks for the CODE (verifyOTP type recovery),
  // so a link-only recovery template leaves nothing to type.
  final recovery = text('mailer_templates_recovery_content');
  checks.add(
    recovery == null
        ? const ReadinessCheck(
            area,
            'email_recovery_code',
            CheckOutcome.unknown,
            'this Auth version does not report the recovery template',
          )
        : recovery.contains('{{ .Token }}')
        ? const ReadinessCheck(area, 'email_recovery_code', CheckOutcome.pass)
        : const ReadinessCheck(
            area,
            'email_recovery_code',
            CheckOutcome.fail,
            'recovery_template_without_code: the default template is link-only and the app asks for '
                'the code; add {{ .Token }} to the recovery template',
          ),
  );

  final otpLength = auth['mailer_otp_length'];
  final otpExpiry = auth['mailer_otp_exp'];
  checks.add(
    otpLength is! int || otpExpiry is! int
        ? const ReadinessCheck(
            area,
            'email_otp_settings',
            CheckOutcome.unknown,
            'the OTP length or lifetime is not reported',
          )
        : otpLength >= 6 && otpExpiry > 0 && otpExpiry <= 86400
        ? ReadinessCheck(
            area,
            'email_otp_settings',
            CheckOutcome.pass,
            '$otpLength digits, ${otpExpiry}s',
          )
        : ReadinessCheck(
            area,
            'email_otp_settings',
            CheckOutcome.fail,
            '$otpLength digits for ${otpExpiry}s is outside 6+ digits and one day',
          ),
  );

  // The built-in service delivers to project members only, a few per hour.
  final host = text('smtp_host');
  checks.add(
    host == null
        ? const ReadinessCheck(
            area,
            'email_custom_smtp',
            CheckOutcome.unknown,
            'this Auth version does not report its mail server',
          )
        : host.isNotEmpty && '${auth['smtp_admin_email'] ?? ''}'.isNotEmpty
        ? const ReadinessCheck(
            area,
            'email_custom_smtp',
            CheckOutcome.pass,
            'custom SMTP configured (delivery itself is not tested: no mail is sent)',
          )
        : const ReadinessCheck(
            area,
            'email_custom_smtp',
            CheckOutcome.fail,
            'smtp_not_configured: the built-in mail service is not production delivery; '
                'configure custom SMTP (the operator does, in Auth settings)',
          ),
  );
  return checks;
}

List<ReadinessCheck> federationChecks(
  McpTargetEvidence e,
  Map<String, Object?>? federation,
) {
  const area = ReadinessArea.canonicalFederation;
  ReadinessCheck check(String code, CheckOutcome o, [String d = '']) =>
      ReadinessCheck(area, code, o, d);
  final checks = <ReadinessCheck>[];
  final kind = federation?['authority_kind'];
  final issuer = federation?['issuer'];

  checks.add(
    federation == null
        ? check(
            'identity_authority',
            CheckOutcome.unknown,
            'the database readiness read failed',
          )
        : kind is String
        ? check('identity_authority', CheckOutcome.pass, '$kind: $issuer')
        : check(
            'identity_authority',
            CheckOutcome.fail,
            'no canonical identity authority: the operator states it before anyone links',
          ),
  );

  final authUrl = e.authUrl?.toString();
  final discovered = e.authDiscovery?['issuer'];
  checks.add(
    authUrl == null || e.authDiscovery == null
        ? check(
            'auth_url_confirmed',
            CheckOutcome.unknown,
            'Auth discovery was not reachable at ${authUrl ?? 'an unknown URL'}',
          )
        : discovered == authUrl
        ? check('auth_url_confirmed', CheckOutcome.pass, authUrl)
        : check(
            'auth_url_confirmed',
            CheckOutcome.fail,
            'auth_url_mismatch: Auth at $authUrl answers as issuer $discovered',
          ),
  );

  if (kind == 'native') {
    checks.add(
      discovered is! String
          ? check(
              'canonical_issuer',
              CheckOutcome.unknown,
              'the Auth issuer was not discovered',
            )
          : discovered == issuer
          ? check(
              'canonical_issuer',
              CheckOutcome.pass,
              'this project is its own authority',
            )
          : check(
              'canonical_issuer',
              CheckOutcome.fail,
              'the stated issuer $issuer is not this Auth ($discovered)',
            ),
    );
  } else if (kind == 'oidc') {
    final canonical = e.canonicalDiscovery?['issuer'];
    checks.add(
      canonical == null
          ? check(
              'canonical_issuer',
              CheckOutcome.unknown,
              'the canonical issuer\'s discovery was not read',
            )
          : check(
              'canonical_issuer',
              canonical == issuer ? CheckOutcome.pass : CheckOutcome.fail,
              canonical == issuer
                  ? ''
                  : 'the canonical issuer answers as $canonical, not $issuer',
            ),
    );
    final provider = e.federationProvider;
    checks.add(
      provider == null
          ? check(
              'federation_provider',
              CheckOutcome.unknown,
              'the federation provider was not read back (needs DESKILO_TARGET_AUTH_ADMIN_KEY)',
            )
          : provider['enabled'] == true && provider['issuer'] == issuer
          ? check('federation_provider', CheckOutcome.pass)
          : check(
              'federation_provider',
              CheckOutcome.fail,
              'the provider is disabled or names another issuer',
            ),
    );
    final client = e.canonicalClient;
    checks.add(
      client == null
          ? check(
              'federation_callback',
              CheckOutcome.unknown,
              'the canonical project\'s client for this target was not read (--canonical-ref)',
            )
          : client['target_installation_id'] ==
                    e.database?['installation_id'] &&
                client['target_auth_url'] == authUrl &&
                client['enabled'] == true
          ? check(
              'federation_callback',
              CheckOutcome.pass,
              'returns to $authUrl/callback',
            )
          : check(
              'federation_callback',
              CheckOutcome.fail,
              'federation_callback_mismatch: the canonical client names another installation, '
                  'Auth URL, or is disabled',
            ),
    );
  }

  // Only a project other installations federate FROM runs the hook.
  final canonicalFor = federation?['federation_clients'];
  final auth = e.authConfig;
  if (canonicalFor is int && canonicalFor > 0) {
    checks.add(
      auth == null
          ? check(
              'identity_hook',
              CheckOutcome.unknown,
              'the Auth configuration could not be read',
            )
          : auth['hook_custom_access_token_enabled'] == true &&
                auth['hook_custom_access_token_uri'] == canonicalIdentityHookUri
          ? check('identity_hook', CheckOutcome.pass)
          : check(
              'identity_hook',
              CheckOutcome.fail,
              'the identity token hook is not installed: dart run tool/instance.dart federation-hook --ref <ref>',
            ),
    );
  }

  final keys = e.jwks?['keys'];
  checks.add(
    keys is! List
        ? check(
            'jwks_asymmetric',
            CheckOutcome.unknown,
            'the signing keys were not published or read',
          )
        : keys.any((k) => k is Map && {'RSA', 'EC', 'OKP'}.contains(k['kty']))
        ? check('jwks_asymmetric', CheckOutcome.pass)
        : check(
            'jwks_asymmetric',
            CheckOutcome.fail,
            'jwks_no_asymmetric_key: tokens cannot be verified by anyone but Auth',
          ),
  );

  final site = auth?['site_url'];
  if (authUrl != null && site is String) {
    final clash =
        site == authUrl || site == '$authUrl/' || site == '$authUrl/callback';
    checks.add(
      check(
        'site_url_distinct',
        clash ? CheckOutcome.fail : CheckOutcome.pass,
        clash
            ? 'the Site URL is the Auth URL or its callback; it must be the app'
            : '',
      ),
    );
  }
  return checks;
}
