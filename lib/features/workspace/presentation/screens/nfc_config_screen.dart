// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_dot.dart';
import '../../../../core/nfc/nfc_uid_reader.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/workspace_providers.dart';

/// Owner RFID/NFC configuration (0046): the workspace toggle for badge
/// check-in plus this device's NFC status. Card registration itself lives
/// per member in Members & plans — this is the on/off + diagnostics.
class NfcConfigScreen extends ConsumerStatefulWidget {
  const NfcConfigScreen({super.key});

  @override
  ConsumerState<NfcConfigScreen> createState() => _NfcConfigScreenState();
}

class _NfcConfigScreenState extends ConsumerState<NfcConfigScreen> {
  /// null = still checking this device's NFC.
  NfcStatus? _deviceStatus;

  @override
  void initState() {
    super.initState();
    _checkDevice();
  }

  Future<void> _checkDevice() async {
    final status = await ref.read(nfcUidReaderProvider).status();
    if (mounted) setState(() => _deviceStatus = status);
  }

  Future<void> _toggle(Workspace workspace, bool value) async {
    final l10n = AppLocalizations.of(context);
    // #963 — only this switch is written; the server merges it. The
    // former full map, built from the EFFECTIVE set, switched off every
    // feature a parent was holding back.
    final flags = {
      for (final entry in featureFlagsToggleDelta(
        feature: WorkspaceFeature.nfcBadges,
        value: value,
      ).entries)
        entry.key.dbKey: entry.value,
    };
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'nfc feature toggle failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => ref
          .read(workspaceRepositoryProvider)
          .setFeatureFlags(workspace.id, flags),
    )) {
      return;
    }
    ref.invalidate(myWorkspacesProvider);
    await ref.read(myWorkspacesProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final enabled = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.nfcBadges);
    final device = _deviceStatus;
    // Precomputed (lint: no literals inside Text with interpolation).
    final deviceLine = switch (device) {
      null => l10n?.nfcConfigChecking ?? 'Checking…',
      NfcStatus.ready =>
        l10n?.nfcConfigDeviceReady ?? 'NFC available and enabled',
      NfcStatus.off => l10n?.nfcConfigDeviceOff ??
          "NFC is turned off in this device's Android settings — turn it "
              'on to read RFID cards.',
      NfcStatus.unsupported => l10n?.nfcConfigDeviceUnavailable ??
          'No NFC here — Android with NFC on is needed (iPads have no '
              'NFC). QR badges still work.',
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.nfcConfigTitle ?? 'RFID / NFC badges'),
      ),
      body: ListView(
        padding: AppSpacing.gutterAll,
        children: [
          Text(
            l10n?.nfcConfigIntro ??
                'Members check in at a wall-mounted kiosk by tapping an '
                    'RFID/NFC card. Register each member\'s card in Members '
                    '& plans; at the kiosk they tap to reserve or check in.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: SwitchListTile(
              key: const ValueKey('nfc-feature-switch'),
              title: HelpDotTitle(
                l10n?.nfcConfigEnable ?? 'Enable NFC badge check-in',
                l10n?.helpHintBadgesTopic ?? 'NFC badges',
              ),
              subtitle: Text(
                l10n?.nfcConfigEnableDesc ??
                    'Show the card-tap option on kiosks and in the badge '
                        'manager.',
              ),
              value: enabled,
              onChanged: workspace == null
                  ? null
                  : (v) => _toggle(workspace, v),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // This device's NFC status — a diagnostic for the tablet the
          // owner is holding.
          Card(
            child: ListTile(
              leading: Icon(
                device == NfcStatus.ready
                    ? Icons.contactless_outlined
                    : Icons.mobile_off_outlined,
                color: device == NfcStatus.ready
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              title: Text(l10n?.nfcConfigDeviceStatus ?? 'This device'),
              subtitle: Text(deviceLine),
            ),
          ),
        ],
      ),
    );
  }
}
