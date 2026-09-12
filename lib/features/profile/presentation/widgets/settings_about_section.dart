// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/app_info.dart';
import '../../../../core/links/link_launcher.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/providers/sign_out.dart';
import 'settings_section_header.dart';

// About-section facts (#560): proper nouns and URLs, identical in every
// UI language — consts like the endonyms, not l10n keys.
const _appName = 'DesKilo';
const _authorName = 'Florian DITTGEN';
const _authorEmail = 'fdittgen@gmail.com';
const _repoUrl = 'https://github.com/fdittgen-png/deskilo';
const _privacyUrl =
    'https://github.com/fdittgen-png/deskilo/blob/master/PRIVACY.md';
const _issuesUrl = 'https://github.com/fdittgen-png/deskilo/issues/new';
const _paypalName = 'PayPal';
const _paypalHandle = 'paypal.me/FlorianDITTGEN';
const _revolutName = 'Revolut';
const _revolutHandle = 'revolut.me/floriamcep';

  /// #1154 — the About section — version, licence, links, sign-out. One of the four slices of a build() that was 723
  /// lines long; the tiles are unchanged, only the list is cut.
List<Widget> aboutSettingsTiles(
    BuildContext context,
    WidgetRef ref, {
    required AppLocalizations? l10n,
    required ColorScheme colorScheme,
  }) =>
      [
          const Divider(),
          SettingsSectionHeader(l10n?.settingsSectionAbout ?? 'About'),
          ListTile(
            key: const ValueKey('about-version'),
            leading: const Icon(Icons.info_outline),
            title: const Text(_appName),
            subtitle: switch (ref.watch(appVersionProvider).value) {
              null || '' => null,
              final version => Text(
                l10n?.aboutVersion(version) ?? 'Version $version',
              ),
            },
          ),
          ListTile(
            key: const ValueKey('about-author'),
            leading: const Icon(Icons.person_outline),
            title: const Text(_authorName),
            subtitle: const Text(_authorEmail),
            onTap: () => ref.read(linkLauncherProvider)(
              Uri(scheme: 'mailto', path: _authorEmail),
            ),
          ),
          ListTile(
            key: const ValueKey('about-source'),
            leading: const Icon(Icons.code),
            title: Text(l10n?.aboutOpenSource ?? 'Open source (0BSD)'),
            subtitle: Text(
              l10n?.aboutOpenSourceDesc ?? 'Source code on GitHub',
            ),
            onTap: () => ref.read(linkLauncherProvider)(Uri.parse(_repoUrl)),
          ),
          ListTile(
            key: const ValueKey('about-privacy'),
            leading: const Icon(Icons.shield_outlined),
            title: Text(l10n?.aboutPrivacy ?? 'Privacy policy'),
            onTap: () => ref.read(linkLauncherProvider)(Uri.parse(_privacyUrl)),
          ),
          ListTile(
            key: const ValueKey('about-issues'),
            leading: const Icon(Icons.bug_report_outlined),
            title: Text(
              l10n?.aboutReportBug ?? 'Report a bug / suggest a feature',
            ),
            onTap: () => ref.read(linkLauncherProvider)(Uri.parse(_issuesUrl)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Column(
              children: [
                Text(
                  l10n?.aboutSupportTitle ?? 'Support this project',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n?.aboutSupportBody ??
                      'This app is free, open source and ad-free. If '
                          'you find it useful, support the developer.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          ListTile(
            key: const ValueKey('about-paypal'),
            leading: const Icon(Icons.payment_outlined),
            title: const Text(_paypalName),
            subtitle: const Text(_paypalHandle),
            onTap: () => ref.read(linkLauncherProvider)(
              Uri.parse('https://$_paypalHandle'),
            ),
          ),
          ListTile(
            key: const ValueKey('about-revolut'),
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text(_revolutName),
            subtitle: const Text(_revolutHandle),
            onTap: () => ref.read(linkLauncherProvider)(
              Uri.parse('https://$_revolutHandle'),
            ),
          ),
          // Sign out sits apart from the sections, with the destructive
          // foreground treatment used elsewhere (colorScheme.error, as in
          // the billing validation message).
          const Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: colorScheme.error),
            title: Text(
              l10n?.authSignOut ?? 'Sign out',
              style: TextStyle(color: colorScheme.error),
            ),
            onTap: () async {
              await signOutAndForget(ref);
              // The router's auth redirect takes over from here.
            },
          ),
      ];
