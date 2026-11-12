// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3675 — where badge sign-in works (security.badge_signin_where), for
// whoever may change the business's settings. While the business is on
// "any device" the recommendation stands, with what the stricter mode
// changes. Switching to "enrolled kiosks only" while no kiosk is enrolled
// is allowed and asks first: nobody signs in by badge until one is.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/settings/settings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../workspace/providers/settings_providers.dart';

/// The setting's key and its two values.
const kioskSigninWhereKey = 'security.badge_signin_where';
const _kiosksOnly = 'enrolled_kiosks';
const _anyDevice = 'any_device';

/// The choice of where badge sign-in works, with its recommendation.
class KioskSigninWhereCard extends ConsumerStatefulWidget {
  const KioskSigninWhereCard({
    required this.workspaceId,
    required this.settings,
    required this.enrolledDevices,
    super.key,
  });

  final String workspaceId;
  final SettingsSet settings;

  /// Enrolled devices not revoked.
  final int enrolledDevices;

  @override
  ConsumerState<KioskSigninWhereCard> createState() =>
      _KioskSigninWhereCardState();
}

class _KioskSigninWhereCardState extends ConsumerState<KioskSigninWhereCard> {
  bool _busy = false;

  Future<void> _choose(SettingDefinition definition, String value) async {
    final l10n = context.l10n;
    if (value == _kiosksOnly && widget.enrolledDevices == 0) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(l10n.kioskSigninWhereNoDeviceTitle),
          content: Text(l10n.kioskSigninWhereNoDevice),
          actions: [
            TextButton(
              key: const ValueKey('kiosk-where-cancel'),
              onPressed: () => Navigator.of(dialog).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              key: const ValueKey('kiosk-where-confirm'),
              onPressed: () => Navigator.of(dialog).pop(true),
              child: Text(l10n.kioskSigninWhereSwitch),
            ),
          ],
        ),
      );
      if (sure != true || !mounted) return;
    }
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      domain: 'kiosk',
      message: 'badge sign-in place failed',
      errorText: l10n.kioskSigninWhereFailed,
      action: () => ref
          .read(settingsCommandsProvider)
          .save(
            workspaceId: widget.workspaceId,
            definition: definition,
            text: value,
          ),
    );
    ref
      ..invalidate(settingsSetProvider(widget.workspaceId))
      ..invalidate(currentSettingsProvider);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) AppSnack.success(context, l10n.workspaceSettingsSaved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final definition = widget.settings.definitions[kioskSigninWhereKey];
    // A registry read from the app's own bundle holds defaults only: shown,
    // never written over (the settings editor does the same).
    final editable =
        definition != null &&
        definition.editable &&
        widget.settings.revision != 'defaults' &&
        !_busy;
    final value = definition == null
        ? _kiosksOnly
        : widget.settings.read<String>(kioskSigninWhereKey);
    return Card(
      child: Padding(
        padding: AppSpacing.gutterAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.sm,
          children: [
            Text(
              l10n.settingLabelSecurityBadgeSigninWhere,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SegmentedButton<String>(
              key: const ValueKey('kiosk-where'),
              segments: [
                ButtonSegment(
                  value: _kiosksOnly,
                  label: Text(l10n.kioskSigninWhereKiosks),
                ),
                ButtonSegment(
                  value: _anyDevice,
                  label: Text(l10n.kioskSigninWhereAnyDevice),
                ),
              ],
              selected: {value},
              onSelectionChanged: editable
                  ? (chosen) => _choose(definition, chosen.single)
                  : null,
            ),
            if (value == _anyDevice)
              InlineBanner(
                key: const ValueKey('kiosk-where-recommend'),
                icon: Icons.shield_outlined,
                severity: InlineBannerSeverity.info,
                text: l10n.kioskSigninWhereRecommend,
              ),
          ],
        ),
      ),
    );
  }
}
