// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1914 — a published privacy notice, as the server holds it: who the
// controller is, how to reach them, and every recipient with its role,
// purpose, legal basis, region and transfer mechanism. What the operator
// has not recorded reads as "not recorded", never as a guess.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/privacy_notice.dart';

String _orUnrecorded(AppLocalizations? l10n, String value) =>
    value.trim().isEmpty || value.trim().toLowerCase().startsWith('unknown')
    ? (l10n?.privacyNoticeNotRecorded ?? 'not recorded by the operator')
    : value;

class PrivacyNoticeView extends StatelessWidget {
  const PrivacyNoticeView({
    super.key,
    required this.notice,
    this.showVersion = true,
  });

  final PrivacyNotice notice;

  /// False where the screen prints the version itself.
  final bool showVersion;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      key: ValueKey('privacy-notice-${notice.version}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n?.privacyNoticeController(
                _orUnrecorded(l10n, notice.controllerName),
                _orUnrecorded(l10n, notice.controllerContact),
              ) ??
              'Controller: ${_orUnrecorded(l10n, notice.controllerName)} — '
                  '${_orUnrecorded(l10n, notice.controllerContact)}',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n?.privacyNoticeRights(
                _orUnrecorded(l10n, notice.rightsContact),
              ) ??
              'Your rights: ${_orUnrecorded(l10n, notice.rightsContact)}',
          style: theme.textTheme.bodyMedium,
        ),
        for (final r in notice.recipients) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(r.name, style: theme.textTheme.titleSmall),
          Text(
            '${r.purpose} · '
            '${l10n?.privacyNoticeRegion(_orUnrecorded(l10n, r.region)) ?? 'Region: ${_orUnrecorded(l10n, r.region)}'} · '
            '${l10n?.privacyNoticeTransfer(_orUnrecorded(l10n, r.transferMechanism == 'unknown' ? '' : r.transferMechanism)) ?? 'Transfer safeguard: ${_orUnrecorded(l10n, r.transferMechanism == 'unknown' ? '' : r.transferMechanism)}'}',
            style: muted,
          ),
          Text(
            r.essential
                ? (l10n?.privacyNoticeEssential ??
                      'Needed to run the account and the space')
                : (l10n?.privacyNoticeOptional ??
                      'Optional — you can use the app without it'),
            style: muted,
          ),
        ],
        if (showVersion) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${l10n?.consentVersion ?? 'Version'} ${notice.version}',
            style: muted,
          ),
        ],
      ],
    );
  }
}
