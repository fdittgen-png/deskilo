// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3675 — this device as a kiosk of the business: enrolled under a name
// (the credential is answered once and kept only in this device's secure
// storage), or not. The words say what is trusted — the device — and what
// to do when it is lost: revoke it in the list below.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/kiosk_credential_store.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../providers/kiosk_device_providers.dart';

/// The device in hand: its enrolment, or the way to enrol it.
class KioskThisDeviceCard extends ConsumerStatefulWidget {
  const KioskThisDeviceCard({
    required this.workspaceId,
    required this.held,
    required this.onChanged,
    super.key,
  });

  final String workspaceId;

  /// This device's enrolment, of any business; null when it has none.
  final KioskCredential? held;

  /// The enrolment on this device changed: read it again.
  final VoidCallback onChanged;

  @override
  ConsumerState<KioskThisDeviceCard> createState() =>
      _KioskThisDeviceCardState();
}

class _KioskThisDeviceCardState extends ConsumerState<KioskThisDeviceCard> {
  final _name = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _enrol() async {
    final l10n = context.l10n;
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      domain: 'kiosk',
      message: 'kiosk enrolment failed',
      errorText: l10n.kioskEnrolFailed,
      action: () async {
        final enrolment = await ref
            .read(kioskDeviceRepositoryProvider)
            .enrol(widget.workspaceId, name);
        await ref
            .read(kioskCredentialStoreProvider)
            .write(
              KioskCredential(
                workspaceId: widget.workspaceId,
                deviceId: enrolment.deviceId,
                name: name,
                secret: enrolment.credential,
              ),
            );
      },
    );
    ref.invalidate(kioskDevicesProvider(widget.workspaceId));
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    _name.clear();
    widget.onChanged();
    AppSnack.success(context, l10n.kioskEnrolDone);
  }

  Future<void> _forget() async {
    final l10n = context.l10n;
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.kioskForgetHere),
        content: Text(l10n.kioskForgetConfirm),
        actions: [
          TextButton(
            key: const ValueKey('kiosk-forget-cancel'),
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const ValueKey('kiosk-forget-confirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l10n.kioskForgetHere),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await ref.read(kioskCredentialStoreProvider).forget();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final held = widget.held;
    final mine = held != null && held.workspaceId == widget.workspaceId;
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: AppSpacing.gutterAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.sm,
          children: [
            Text(l10n.kioskThisDeviceTitle, style: text.titleMedium),
            if (mine) ...[
              Text(
                l10n.kioskEnrolled(held.name),
                key: const ValueKey('kiosk-this-device-enrolled'),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: const ValueKey('kiosk-forget'),
                  onPressed: _forget,
                  child: Text(l10n.kioskForgetHere),
                ),
              ),
            ] else ...[
              if (held != null)
                Text(
                  l10n.kioskEnrolledElsewhere,
                  key: const ValueKey('kiosk-this-device-elsewhere'),
                ),
              Text(l10n.kioskEnrolTrust, style: text.bodySmall),
              if (kIsWeb)
                Text(l10n.kioskEnrolTrustBrowser, style: text.bodySmall),
              AppTextField(
                key: const ValueKey('kiosk-enrol-name'),
                controller: _name,
                label: l10n.kioskEnrolNameLabel,
                helper: l10n.kioskEnrolNameHint,
                enabled: !_busy,
              ),
              ListenableBuilder(
                listenable: _name,
                builder: (context, _) => FilledButton(
                  key: const ValueKey('kiosk-enrol'),
                  onPressed: _busy || _name.text.trim().isEmpty ? null : _enrol,
                  child: Text(l10n.kioskEnrolAction),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
