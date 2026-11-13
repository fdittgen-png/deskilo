// SPDX-License-Identifier: AGPL-3.0-or-later

import 'instance_builder.dart';
import 'instance_doctor.dart';

List<DoctorFinding> checkInstanceAuthConfig(
  Map<String, Object?> config, {
  Map<String, Object?>? expectedAuth,
}) {
  final expected = expectedAuth ?? InstanceAuthConfig.patch;
  final expectedSite = expected['site_url'] as String;
  final expectedRedirects = expected['uri_allow_list'] as String;
  final quotedSite = "'${expectedSite.replaceAll("'", "'\\''")}'";
  final command = expectedSite == InstanceAuthConfig.siteUrl
      ? 'dart run tool/instance.dart auth --ref <ref>'
      : 'dart run tool/instance.dart auth --ref <ref> --site-url $quotedSite';
  final findings = <DoctorFinding>[];
  final siteUrl = '${config['site_url'] ?? ''}';
  final allowList = '${config['uri_allow_list'] ?? ''}';
  final autoconfirm = config['mailer_autoconfirm'] == true;

  if (siteUrl != expectedSite) {
    findings.add(
      DoctorFinding(
        siteUrl.contains('localhost') ? DoctorLevel.alarm : DoctorLevel.warn,
        'Site URL is not the app',
        'is  "$siteUrl"\n        want "$expectedSite"\n'
            '        Every mail GoTrue sends carries this link. A localhost '
            'here is a link nobody can open.\n'
            '        Fix: $command',
      ),
    );
  } else {
    findings.add(
      const DoctorFinding(
        DoctorLevel.ok,
        'Site URL',
        'matches InstanceAuthConfig',
      ),
    );
  }

  final allowed = allowList.split(',').map((entry) => entry.trim()).toSet();
  final missing = [
    for (final entry in expectedRedirects.split(','))
      if (!allowed.contains(entry.trim())) entry.trim(),
  ];
  findings
    ..add(
      missing.isEmpty
          ? const DoctorFinding(
              DoctorLevel.ok,
              'Redirect allow-list',
              'carries every callback',
            )
          : DoctorFinding(
              DoctorLevel.alarm,
              'Redirect allow-list is missing a callback',
              'missing: ${missing.join(', ')}\n'
                  '        A redirect that is not listed is refused, and the '
                  'Site URL is substituted instead.\n'
                  '        Fix: $command',
            ),
    )
    // Not a fault either way — but it decides whether anybody has to click
    // anything, so it must be visible when it changes.
    ..add(
      DoctorFinding(
        DoctorLevel.ok,
        'Confirmation e-mail',
        autoconfirm
            ? 'mailer_autoconfirm is ON — accounts confirm themselves and no '
                  'mail is sent'
            : 'mailer_autoconfirm is OFF — every new account must click a '
                  'link, so the Site URL above has to be right',
      ),
    )
    ..addAll(_checkSignInBaseline(config, command));
  return findings;
}

/// #3904 — codes, passwords and a password change against the baseline the
/// builder sets ([InstanceAuthConfig.signInBaseline]). A setting this Auth
/// version does not report is not judged.
List<DoctorFinding> _checkSignInBaseline(Map<String, Object?> config, String command) {
  final otp = config['mailer_otp_exp'];
  final length = config['password_min_length'];
  final reauth = config['security_update_password_require_reauthentication'];
  DoctorFinding warn(DoctorWords words, Object? value) => DoctorFinding.typed(
      DoctorLevel.warn, words, facts: ['$value', command, InstanceAuthConfig.minPasswordLength]);
  final weak = [
    if (otp is int && otp > InstanceAuthConfig.otpLifetimeLimitSeconds)
      warn(DoctorWords.authCodesLong, otp),
    if (length is int && length < InstanceAuthConfig.minPasswordLength)
      warn(DoctorWords.authPasswordShort, length),
    if (reauth == false) warn(DoctorWords.authReauthOff, reauth),
  ];
  final judged = otp is int && length is int && reauth is bool;
  return [
    ...weak,
    if (weak.isEmpty && judged)
      const DoctorFinding.typed(DoctorLevel.ok, DoctorWords.authBaseline,
          facts: [InstanceAuthConfig.minPasswordLength]),
  ];
}
