// SPDX-License-Identifier: AGPL-3.0-or-later
// #4466 — Settings › Devices: a till board is connected by its QR code (the camera, where there is one) or by the
// readable code beside it (typed). The code is read and checked here, a typo refused in words, and the board found is
// shown (its id, model and fingerprint, to compare with its screen). Connecting it to the business is the enrollment's
// step, which comes later: nothing is sent. The boards already connected are listed first (the Demo has one).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/devices/connected_boards_provider.dart';
import '../../../../core/devices/device_code.dart';
import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/scan/qr_scan_widget.dart';
import '../../../../core/scan/scan_camera_box.dart';
import '../../../../core/scan/scan_no_camera.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/adaptive/page_measures.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../../l10n/app_localizations.dart';

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key, this.cameraAvailable});

  /// Whether the camera scanner is offered; the platform decides when null (tests set it).
  final bool? cameraAvailable;

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  final _form = _PairingForm();

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final camera = widget.cameraAvailable ?? qrScanSupported;
    final boards = ref.watch(connectedTillBoardsProvider).value ?? const <DeviceCode>[]; // empty-ok: no read until #4454 stores boards
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(l10n.devicePairingTitle),
        actions: [HelpDot(l10n.devicePairingTitle, anchor: HelpAnchor.settingsDevices)],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.gutterAll,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kFormColumnWidth),
            child: ListenableBuilder(
              listenable: _form,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (boards.isEmpty) Text(l10n.devicePairingNone, key: const ValueKey('device-pairing-none')),
                  for (final b in boards)
                    Card(
                      key: ValueKey('device-connected-${b.shortId}'),
                      child: ListTile(
                        leading: const Icon(Icons.developer_board_outlined),
                        title: Text(l10n.devicePairingBoard(b.shortId, b.profile.model)),
                        subtitle: Text(l10n.devicePairingFingerprint(b.fingerprintShown)),
                      ),
                    ),
                  const FormGap.large(),
                  FormSection(
                    title: l10n.devicePairingConnect,
                    children: [
                      if (camera) ...[
                        Text(l10n.devicePairingScanHint),
                        const FormGap.small(),
                        SizedBox(
                          height: 240,
                          child: ScanCameraBox(
                            cameraKey: const ValueKey('device-pairing-camera'),
                            defaultFront: false,
                            onCode: _form.read,
                          ),
                        ),
                      ] else
                        Text(scanNoCameraSentence(l10n), key: const ValueKey('device-pairing-no-camera')),
                      const FormGap(),
                      AppTextField(
                        key: const ValueKey('device-pairing-code'),
                        controller: _form.typed,
                        label: l10n.devicePairingType,
                        helper: l10n.devicePairingTypeHelper,
                        error: switch (_form.refusal) {
                          null => null,
                          final r => _refusalText(l10n, r),
                        },
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => _form.edited(),
                        onSubmitted: _form.read,
                      ),
                      const FormGap.small(),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: FilledButton(
                          key: const ValueKey('device-pairing-check'),
                          onPressed: () => _form.read(_form.typed.text),
                          child: Text(l10n.devicePairingCheck),
                        ),
                      ),
                    ],
                  ),
                  if (_form.found case final code?) ...[const FormGap.large(), _Found(code: code)],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _refusalText(AppLocalizations l10n, DeviceCodeRefusal r) => switch (r) {
  DeviceCodeRefusal.length => l10n.devicePairingRefusedLength,
  DeviceCodeRefusal.alphabet => l10n.devicePairingRefusedAlphabet,
  DeviceCodeRefusal.check => l10n.devicePairingRefusedCheck,
  DeviceCodeRefusal.profile => l10n.devicePairingRefusedProfile,
};

/// The code being read: the typed text, and what the last scan or check found.
class _PairingForm extends ChangeNotifier {
  final typed = TextEditingController();
  DeviceCode? found;
  DeviceCodeRefusal? refusal;

  void read(String text) {
    switch (readDeviceCode(text)) {
      case DeviceCodeOk(:final code):
        found = code;
        refusal = null;
      case DeviceCodeRefused(:final reason):
        found = null;
        refusal = reason;
    }
    notifyListeners();
  }

  /// A refusal stays until the code is changed.
  void edited() {
    if (refusal == null) return;
    refusal = null;
    notifyListeners();
  }

  @override
  void dispose() {
    typed.dispose();
    super.dispose();
  }
}

class _Found extends StatelessWidget {
  const _Found({required this.code});

  final DeviceCode code;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('device-pairing-found'),
      child: Padding(
        padding: AppSpacing.gutterAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.devicePairingFound, style: theme.textTheme.titleMedium),
            const FormGap.small(),
            Text(l10n.devicePairingBoard(code.shortId, code.profile.model)),
            Text(l10n.devicePairingFingerprint(code.fingerprintShown)),
            const FormGap(),
            Text(l10n.devicePairingLater, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
