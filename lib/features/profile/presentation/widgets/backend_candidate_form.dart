// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/backend_settings.dart';
import '../../../../core/backend/backend_uri.dart';
import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/scan/scan_camera_box.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../l10n/app_localizations.dart';

/// #1651 — the three ways a device gets its server, as one choice.
enum BackendConnectMode {
  /// DesKilo's own service: the default, and the way back.
  defaultService,

  /// A code the organization shared — scanned or pasted. No key typing.
  connect,

  /// An operator who runs the project types its URL and public key.
  operator,
}

/// #1651 — a probe result bound to the exact candidate it was run for.
class _Verified {
  const _Verified(this.fingerprint, this.report, this.at);
  final String fingerprint;
  final BackendProbeReport report;
  final DateTime at;
}

/// The candidate a person is building, tested, and saved only when the
/// test that answered was about THIS candidate and said it is usable.
///
/// Every edit bumps a generation; a probe that started before the edit
/// finishes into the void. The Save button is a consequence of the
/// evidence, not a second validation: without a matching usable probe
/// there is nothing to save, and the hint says so.
class BackendCandidateForm extends ConsumerStatefulWidget {
  const BackendCandidateForm({
    super.key,
    required this.topic,
    required this.isDefault,
    required this.initial,
    required this.onApply,
    required this.onVerified,
  });

  final String topic;
  final bool isDefault;

  /// The stored custom endpoint, prefilled for an operator.
  final BackendEndpoint? initial;

  /// Null = back to the app's own server.
  final Future<void> Function(BackendEndpoint? endpoint) onApply;

  /// A usable probe answered for the current candidate, at [at].
  final void Function(DateTime at) onVerified;

  @override
  ConsumerState<BackendCandidateForm> createState() =>
      _BackendCandidateFormState();
}

class _BackendCandidateFormState extends ConsumerState<BackendCandidateForm> {
  final _url = TextEditingController();
  final _key = TextEditingController();
  final _descriptor = TextEditingController();
  late BackendConnectMode _mode;
  String? _label;
  bool _descriptorInvalid = false;
  int _generation = 0;
  bool _testing = false;
  _Verified? _verified;
  BackendEndpointError? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _mode = initial == null
        ? BackendConnectMode.connect
        : BackendConnectMode.operator;
    if (initial != null) {
      _url.text = initial.url;
      _key.text = initial.key;
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    _descriptor.dispose();
    super.dispose();
  }

  String get _fingerprint =>
      BackendEndpoint(_url.text, _key.text).fingerprint;

  /// The evidence, if it is about the candidate on the form right now.
  _Verified? get _current {
    final v = _verified;
    return v != null && v.fingerprint == _fingerprint ? v : null;
  }

  /// Any change to the candidate invalidates whatever was known about
  /// the previous one, and orphans a probe still in flight.
  void _invalidate() {
    setState(() {
      _generation++;
      _testing = false;
      _verified = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            _chip(BackendConnectMode.defaultService, 'backend-mode-default',
                l10n?.backendModeDefault ?? "Use DesKilo's service"),
            _chip(BackendConnectMode.connect, 'backend-mode-connect',
                l10n?.backendModeConnect ?? 'Connect an existing organization'),
            _chip(BackendConnectMode.operator, 'backend-mode-operator',
                l10n?.backendModeOperator ?? 'Set up a server (operators)'),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        switch (_mode) {
          BackendConnectMode.defaultService => _defaultPanel(l10n),
          BackendConnectMode.connect => _connectPanel(l10n),
          BackendConnectMode.operator => _operatorPanel(l10n),
        },
      ],
    );
  }

  Widget _chip(BackendConnectMode mode, String key, String label) =>
      ChoiceChip(
        key: ValueKey(key),
        label: Text(label),
        selected: _mode == mode,
        onSelected: (_) => setState(() => _mode = mode),
      );

  Widget _defaultPanel(AppLocalizations? l10n) => Card(
        key: const ValueKey('backend-default-panel'),
        child: Padding(
          padding: AppSpacing.mdAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n?.backendModeDefaultHint ??
                  "DesKilo's own service needs no setup. Members of an "
                      'organization that runs its own server use its code '
                      'instead.'),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                key: const ValueKey('backend-use-default'),
                onPressed:
                    widget.isDefault ? null : () => widget.onApply(null),
                child: Text(widget.isDefault
                    ? (l10n?.backendServerInUse ?? 'In use on this device')
                    : (l10n?.backendServerReset ?? "Use the app's server")),
              ),
            ],
          ),
        ),
      );

  Widget _connectPanel(AppLocalizations? l10n) {
    final candidate = _url.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n?.backendModeConnectHint ??
              'Scan or paste the server code your organization gave you. '
                  'You never need an administrator key.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          key: const ValueKey('backend-scan'),
          onPressed: _scan,
          icon: const Icon(Icons.qr_code_scanner),
          label: Text(l10n?.backendScan ?? 'Scan a server QR'),
        ),
        const SizedBox(height: AppSpacing.sm),
        _field(
          key: const ValueKey('backend-descriptor-field'),
          controller: _descriptor,
          label: l10n?.backendDescriptorLabel ?? 'Server code',
          hint: 'deskilo://server?…',
          onChanged: _descriptorChanged,
          errorText: _descriptorInvalid
              ? (l10n?.backendDescriptorInvalid ??
                  'That is not a valid DesKilo server code.')
              : null,
        ),
        if (candidate) ...[
          const SizedBox(height: AppSpacing.sm),
          ListTile(
            key: const ValueKey('backend-destination'),
            leading: const Icon(Icons.dns_outlined),
            title: Text(l10n?.backendDestination(_hostOf(_url.text)) ??
                'Destination: ${_hostOf(_url.text)}'),
            subtitle: _label == null
                ? null
                : Text(
                    key: const ValueKey('backend-descriptor-named'),
                    l10n?.backendDescriptorNamed(_label!) ??
                        'Named "$_label" by whoever shared it — not verified.',
                  ),
          ),
          _testAndSave(l10n),
        ],
      ],
    );
  }

  Widget _operatorPanel(AppLocalizations? l10n) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(
            key: const ValueKey('backend-url-field'),
            controller: _url,
            label: l10n?.backendUrlLabel ?? 'Project URL',
            hint: 'https://xxxxxxxx.supabase.co',
            keyboard: TextInputType.url,
            onChanged: (_) => _invalidate(),
          ),
          const SizedBox(height: AppSpacing.sm),
          _field(
            key: const ValueKey('backend-key-field'),
            controller: _key,
            label: l10n?.backendKeyLabel ?? 'Publishable key',
            hint: 'sb_publishable_…',
            onChanged: (_) => _invalidate(),
          ),
          _testAndSave(l10n),
        ],
      );

  static String _hostOf(String url) => Uri.tryParse(url.trim())?.host ?? url;

  Widget _testAndSave(AppLocalizations? l10n) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final current = _current;
    final canSave = current != null && current.report.usable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          key: const ValueKey('backend-test'),
          onPressed: _testing ? null : _test,
          icon: _testing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.network_check),
          label: Text(_testing
              ? (l10n?.backendTesting ?? 'Testing…')
              : (l10n?.backendTest ?? 'Test the connection')),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              key: const ValueKey('backend-validation-error'),
              backendErrorText(l10n, _error!),
              style: text.bodyMedium?.copyWith(color: scheme.error),
            ),
          ),
        if (current != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              key: const ValueKey('backend-test-result'),
              backendProbeText(l10n, current.report.result),
              style: text.bodyMedium?.copyWith(
                color: current.report.usable ? scheme.primary : scheme.error,
              ),
            ),
          ),
          Text(
            key: const ValueKey('backend-test-facets'),
            backendProbeFacetsText(l10n, current.report),
            style: text.bodySmall,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n?.backendServerRestartHint ??
              'The app signs you out and applies the change on the next '
                  'start.',
          style: text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          key: const ValueKey('backend-save'),
          onPressed: canSave ? _save : null,
          child: Text(l10n?.commonSave ?? 'Save'),
        ),
        if (!canSave)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              key: const ValueKey('backend-save-hint'),
              l10n?.backendSaveNeedsTest ??
                  'Test the connection first. Only a verified server can be '
                      'saved.',
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    required String hint,
    required ValueChanged<String> onChanged,
    TextInputType? keyboard,
    String? errorText,
  }) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      key: key,
      controller: controller,
      keyboardType: keyboard,
      autocorrect: false,
      enableSuggestions: false,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: l10n?.backendPaste ?? 'Paste',
              icon: const Icon(Icons.content_paste, size: 20),
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                final pasted = data?.text?.trim();
                if (pasted == null || pasted.isEmpty) return;
                controller.text = pasted;
                onChanged(pasted);
              },
            ),
            HelpDot(widget.topic, anchor: HelpAnchor.backendServer),
          ],
        ),
      ),
    );
  }

  /// A code is accepted whole or not at all; a refused one leaves the
  /// previous candidate in place and says so beside the field.
  void _descriptorChanged(String value) {
    final descriptor = BackendUriCodec.decodeDescriptor(value);
    if (descriptor == null) {
      setState(() => _descriptorInvalid = value.trim().isNotEmpty);
      return;
    }
    _url.text = descriptor.endpoint.url;
    _key.text = descriptor.endpoint.key;
    _label = descriptor.label;
    _descriptorInvalid = false;
    _invalidate();
  }

  Future<void> _scan() async {
    final l10n = AppLocalizations.of(context);
    BackendDescriptor? found;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SheetShell(
        title: l10n?.backendScan ?? 'Scan a server QR',
        children: [
          const SizedBox(height: 12),
          ScanCameraBox(
            cameraKey: const ValueKey('backend-scan-camera'),
            defaultFront: false,
            onCode: (payload) {
              final descriptor = BackendUriCodec.decodeDescriptor(payload);
              if (descriptor == null) return;
              found = descriptor;
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (found == null) {
      AppSnack.info(
        context,
        l10n?.backendScanNothing ?? 'That QR is not a DesKilo server code.',
      );
      return;
    }
    _descriptor.text = BackendUriCodec.encode(found!.endpoint,
        label: found!.label);
    _descriptorChanged(_descriptor.text);
  }

  Future<void> _test() async {
    final error = validateBackendEndpoint(_url.text, _key.text);
    if (error != null) {
      // Refused before any request: nothing was sent, nothing stored.
      setState(() {
        _error = error;
        _verified = null;
      });
      return;
    }
    final candidate =
        BackendEndpoint(_url.text.trim(), _key.text.trim());
    final fingerprint = candidate.fingerprint;
    final generation = ++_generation;
    setState(() {
      _testing = true;
      _verified = null;
      _error = null;
    });
    final report = await probeBackend(
      candidate,
      transport: ref.read(backendProbeTransportProvider),
    );
    if (!mounted) return;
    // The candidate changed while this probe ran: its answer is about
    // something that is no longer on the form.
    if (generation != _generation) return;
    final at = ref.read(clockProvider).now();
    setState(() {
      _testing = false;
      _verified = _Verified(fingerprint, report, at);
    });
    if (report.usable) widget.onVerified(at);
  }

  Future<void> _save() async {
    final current = _current;
    if (current == null || !current.report.usable) return;
    await widget.onApply(
      BackendEndpoint(_url.text.trim(), _key.text.trim()),
    );
  }
}
