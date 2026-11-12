// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3675 — the business's kiosks: this device (enrol it, or what it is
// enrolled as), where badge sign-in works (for whoever may change the
// settings), and every enrolled device with who enrolled it, when it was
// last used and a revoke. Holders of operateKiosk and owners (the route's
// guard; the server decides again).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/kiosk_credential_store.dart';
import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../domain/kiosk_device.dart';
import '../../domain/workspace_permission.dart';
import '../../providers/kiosk_device_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/kiosk_signin_where_card.dart';
import '../widgets/kiosk_this_device_card.dart';

class KioskDevicesScreen extends ConsumerStatefulWidget {
  const KioskDevicesScreen({super.key});

  @override
  ConsumerState<KioskDevicesScreen> createState() => _KioskDevicesScreenState();
}

class _KioskDevicesScreenState extends ConsumerState<KioskDevicesScreen> {
  /// This device's enrolment, read again after every change of it.
  late Future<KioskCredential?> _held = _readHeld();

  Future<KioskCredential?> _readHeld() =>
      ref.read(kioskCredentialStoreProvider).read();

  void _heldChanged() {
    final next = _readHeld();
    setState(() {
      _held = next;
    });
  }

  Future<void> _revoke(String workspaceId, KioskDevice device) async {
    final l10n = context.l10n;
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.badgeRevoke),
        content: Text(l10n.kioskDeviceRevokeConfirm(device.name)),
        actions: [
          TextButton(
            key: const ValueKey('kiosk-revoke-cancel'),
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const ValueKey('kiosk-revoke-confirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l10n.badgeRevoke),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    final ok = await runGuarded(
      context,
      domain: 'kiosk',
      message: 'kiosk revoke failed',
      errorText: l10n.kioskDeviceRevokeFailed,
      // The device in hand forgets its credential too.
      action: () => ref.read(kioskDeviceCommandsProvider).revoke(device.id),
    );
    ref.invalidate(kioskDevicesProvider(workspaceId));
    if (!mounted) return;
    _heldChanged();
    if (ok) AppSnack.success(context, l10n.kioskDeviceRevokeDone(device.name));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final mayConfigure = ref.watch(
      myPermissionsProvider.select(
        (p) => p.contains(WorkspacePermission.workspaceSettings),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.kioskDevicesTitle),
        actions: [
          HelpDot(l10n.helpHintBadgesTopic, anchor: HelpAnchor.badgesNfc),
        ],
      ),
      body: workspace == null
          ? const LoadingView()
          : FutureBuilder<KioskCredential?>(
              future: _held,
              builder: (context, held) {
                final devices = ref.watch(kioskDevicesProvider(workspace.id));
                final settings = mayConfigure
                    ? ref.watch(settingsSetProvider(workspace.id)).value
                    : null;
                final enrolled = (devices.value ?? const <KioskDevice>[])
                    .where((d) => !d.revoked)
                    .length;
                return ListView(
                  padding: AppSpacing.gutterAll,
                  children: [
                    Text(
                      l10n.kioskDevicesIntro,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    KioskThisDeviceCard(
                      key: const ValueKey('kiosk-this-device'),
                      workspaceId: workspace.id,
                      held: held.data,
                      onChanged: _heldChanged,
                    ),
                    if (settings != null && devices.hasValue) ...[
                      const SizedBox(height: AppSpacing.sm),
                      KioskSigninWhereCard(
                        workspaceId: workspace.id,
                        settings: settings,
                        enrolledDevices: enrolled,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.kioskDevicesListTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    ...switch (devices) {
                      AsyncData(:final value) when value.isEmpty => [
                        ListTile(
                          key: const ValueKey('kiosk-devices-empty'),
                          title: Text(l10n.kioskDevicesEmpty),
                        ),
                      ],
                      AsyncData(:final value) => [
                        for (final d in value)
                          _DeviceTile(
                            key: ValueKey('kiosk-device-row-${d.id}'),
                            device: d,
                            thisOne: held.data?.deviceId == d.id,
                            onRevoke: () => unawaited(_revoke(workspace.id, d)),
                          ),
                      ],
                      AsyncError() => [
                        ListTile(
                          key: const ValueKey('kiosk-devices-failed'),
                          title: Text(l10n.readStateFailed),
                          trailing: TextButton(
                            key: const ValueKey('kiosk-devices-retry'),
                            onPressed: () => ref.invalidate(
                              kioskDevicesProvider(workspace.id),
                            ),
                            child: Text(l10n.commonRetry),
                          ),
                        ),
                      ],
                      _ => [const LoadingView()],
                    },
                  ],
                );
              },
            ),
    );
  }
}

class _DeviceTile extends ConsumerWidget {
  const _DeviceTile({
    super.key,
    required this.device,
    required this.thisOne,
    required this.onRevoke,
  });

  final KioskDevice device;
  final bool thisOne;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final format = ref.watch(appFormatProvider);
    final enrolled = device.enrolledBy.isEmpty
        ? l10n.kioskDeviceEnrolledOn(format.date(device.enrolledAt))
        : l10n.kioskDeviceEnrolledBy(
            device.enrolledBy,
            format.date(device.enrolledAt),
          );
    final used = switch ((device.revokedAt, device.lastUsedAt)) {
      (final DateTime at, _) => l10n.kioskDeviceRevokedOn(format.date(at)),
      (null, final DateTime at) => l10n.kioskDeviceLastUsed(format.date(at)),
      (null, null) => l10n.kioskDeviceNeverUsed,
    };
    return ListTile(
      key: ValueKey('kiosk-device-${device.id}'),
      enabled: !device.revoked,
      leading: Icon(
        device.revoked ? Icons.tablet_outlined : Icons.tablet_android_outlined,
      ),
      title: Text(
        thisOne ? '${device.name} · ${l10n.nfcConfigDeviceStatus}' : device.name,
      ),
      subtitle: Text('$enrolled · $used'),
      trailing: device.revoked
          ? null
          : TextButton(
              key: ValueKey('kiosk-device-revoke-${device.id}'),
              onPressed: onRevoke,
              child: Text(l10n.badgeRevoke),
            ),
    );
  }
}
