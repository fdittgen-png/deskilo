// SPDX-License-Identifier: AGPL-3.0-or-later
// #4466 — Settings › Devices: a till board is read by its QR code (the camera, where there is one) or by the readable
// code beside it (typed). The code is read and checked here, a typo refused in words, and the board found is shown (its
// id, model and fingerprint, to compare with its screen).
// #4454 — the boards the business has, waiting for approval or connected, are listed first; for a board read from its
// QR code the owner chooses a till and is given the code that connects it (TillBoardList approves and removes).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/scan/qr_scan_widget.dart';
import '../../../../core/scan/scan_camera_box.dart';
import '../../../../core/scan/scan_no_camera.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/adaptive/page_measures.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/device_code.dart';
import '../../domain/till_board.dart';
import '../../domain/till_drawer.dart';
import '../../providers/till_board_providers.dart';
import '../../providers/till_drawer_providers.dart';
import 'till_board_list.dart';

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key, this.cameraAvailable, this.workspaceId, this.owner});

  /// Whether the camera scanner is offered; the platform decides when null (tests set it).
  final bool? cameraAvailable;

  /// The business and whether the person is its owner; the open business and its membership when null (tests set them).
  final String? workspaceId;
  final bool? owner;

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
    final workspaceId = widget.workspaceId ?? ref.watch(activeWorkspaceIdProvider).value;
    final owner = widget.owner ?? ref.watch(myMemberProvider).value?.isOwner ?? false;
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
                  if (workspaceId != null)
                    AsyncReadBody<List<TillBoard>>.part(
                      value: ref.watch(connectedTillBoardsProvider(workspaceId)),
                      onRetry: () => ref.invalidate(connectedTillBoardsProvider(workspaceId)),
                      data: (boards) => TillBoardList(workspaceId: workspaceId, boards: boards, owner: owner),
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
                  if (_form.found case final code?) ...[
                    const FormGap.large(),
                    _Found(code: code, workspaceId: owner ? workspaceId : null),
                  ],
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

class _Found extends ConsumerStatefulWidget {
  const _Found({required this.code, required this.workspaceId});

  final DeviceCode code;

  /// The business the owner connects the board to; null when the person is not its owner (nothing is offered).
  final String? workspaceId;

  @override
  ConsumerState<_Found> createState() => _FoundState();
}

class _FoundState extends ConsumerState<_Found> {
  String? _tillId;
  TillBoardCode? _given;
  bool _busy = false;

  Future<void> _run(Future<void> Function(TillBoardPort port) command) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await command(ref.read(tillBoardPortProvider));
    } on Object catch (e) {
      if (mounted) AppSnack.error(context, tillBoardFailureText(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final code = widget.code;
    final workspaceId = widget.workspaceId;
    return Card(
      key: const ValueKey('device-pairing-found'),
      child: Padding(
        padding: AppSpacing.gutterAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.devicePairingFound, style: theme.textTheme.titleMedium),
            const FormGap.small(),
            Text(l10n.devicePairingBoard(code.shortId, code.profile.model)),
            Text(l10n.devicePairingFingerprint(code.fingerprintShown)),
            const FormGap(),
            if (code.id == null)
              Text(l10n.devicePairingScanToConnect, key: const ValueKey('device-pairing-scan-to-connect'))
            else if (!code.connectable)
              Text(l10n.devicePairingNeedsFirmware, key: const ValueKey('device-pairing-needs-firmware'))
            else if (workspaceId != null)
              if (_given case final given?)
                _GivenCode(given: given, busy: _busy, onWithdraw: () => _run((port) async {
                  await port.cancelCode(given.id);
                  if (mounted) setState(() => _given = null);
                }))
              else
                _TillChoice(
                  workspaceId: workspaceId,
                  tillId: _tillId,
                  onTill: (id) => setState(() => _tillId = id),
                  onGetCode: _busy || _tillId == null
                      ? null
                      : () => _run((port) async {
                          final given = await port.code(workspaceId, _tillId!, code);
                          if (mounted) setState(() => _given = given);
                        }),
                ),
          ],
        ),
      ),
    );
  }
}

class _TillChoice extends ConsumerWidget {
  const _TillChoice({required this.workspaceId, required this.tillId, required this.onTill, required this.onGetCode});

  final String workspaceId;
  final String? tillId;
  final ValueChanged<String?> onTill;
  final VoidCallback? onGetCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return AsyncReadBody<List<DrawerTill>>.part(
      value: ref.watch(tillDrawerProvider(workspaceId)),
      onRetry: () => ref.invalidate(tillDrawerProvider(workspaceId)),
      data: (tills) {
        final active = [for (final t in tills) if (t.active) t];
        if (active.isEmpty) return Text(l10n.devicePairingNoTill, key: const ValueKey('device-pairing-no-till'));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: const ValueKey('device-pairing-till'),
              initialValue: tillId,
              decoration: InputDecoration(labelText: l10n.devicePairingTillPick),
              items: [for (final t in active) DropdownMenuItem(value: t.id, child: Text(t.name))],
              onChanged: onTill,
            ),
            const FormGap.small(),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                key: const ValueKey('device-pairing-get-code'),
                onPressed: onGetCode,
                child: Text(l10n.devicePairingGetCode),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GivenCode extends StatelessWidget {
  const _GivenCode({required this.given, required this.busy, required this.onWithdraw});

  final TillBoardCode given;
  final bool busy;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final time = DateFormat.Hm(Localizations.localeOf(context).toLanguageTag()).format(given.expiresAt.toLocal());
    return Column(
      key: const ValueKey('device-pairing-code-given'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(l10n.devicePairingCode(given.code), style: theme.textTheme.titleLarge),
        Text(l10n.devicePairingCodeHint(time), style: theme.textTheme.bodySmall),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            key: const ValueKey('device-pairing-withdraw'),
            onPressed: busy ? null : onWithdraw,
            child: Text(l10n.devicePairingWithdraw),
          ),
        ),
      ],
    );
  }
}
