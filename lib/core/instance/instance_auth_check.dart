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
  final command = expectedSite == InstanceAuthConfig.siteUrl
      ? 'dart run tool/instance.dart auth --ref <ref>'
      : 'dart run tool/instance.dart auth --ref <ref> --site-url <app-url>';
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
    );
  return findings;
}
