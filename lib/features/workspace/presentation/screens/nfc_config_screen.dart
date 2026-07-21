// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  bool? _deviceAvailable;

  @override
  void initState() {
    super.initState();
    _checkDevice();
  }

  Future<void> _checkDevice() async {
    final available = await ref.read(nfcUidReaderProvider).isAvailable();
    if (mounted) setState(() => _deviceAvailable = available);
  }

  Future<void> _toggle(Workspace workspace, bool value) async {
    final l10n = AppLocalizations.of(context);
    final enabled = ref.read(enabledFeaturesSyncProvider);
    // Write the full flag map (features-screen pattern) so a later
    // registry-default change never silently flips the owner's choice.
    final flags = {
      for (final f in featureManifest.keys)
        f.dbKey: f == WorkspaceFeature.nfcBadges
            ? value
            : enabled.contains(f),
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
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final enabled = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.nfcBadges);
    final device = _deviceAvailable;
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
              title: Text(l10n?.nfcConfigEnable ?? 'Enable NFC badge check-in'),
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
                device == true
                    ? Icons.contactless_outlined
                    : Icons.mobile_off_outlined,
                color: device == true
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              title: Text(l10n?.nfcConfigDeviceStatus ?? 'This device'),
              subtitle: Text(
                device == null
                    ? (l10n?.nfcConfigChecking ?? 'Checking…')
                    : device
                        ? (l10n?.nfcConfigDeviceReady ??
                            'NFC available and enabled')
                        : (l10n?.nfcConfigDeviceUnavailable ??
                            'No NFC here — Android with NFC on is needed '
                                '(iPads have no NFC). QR badges still work.'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
