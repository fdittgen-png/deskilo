// SPDX-License-Identifier: 0BSD
//
// #1289 — choosing the space's own mark.
//
// The file never reaches storage as it arrived: `emblemPngOf` decodes
// it, redraws it at most 512 px across and re-encodes it as PNG, which
// bounds the bytes and strips every metadata block — including, for a
// photograph, where it was taken.
import 'package:file_selector/file_selector.dart' show XTypeGroup;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/files/file_picker.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/set_workspace_emblem.dart';
import '../../providers/workspace_providers.dart';
import 'workspace_emblem.dart';

class EmblemEditor extends ConsumerStatefulWidget {
  const EmblemEditor({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  ConsumerState<EmblemEditor> createState() => _EmblemEditorState();
}

class _EmblemEditorState extends ConsumerState<EmblemEditor> {
  bool _busy = false;

  Future<void> _pick() async {
    final l10n = AppLocalizations.of(context);
    final picker = ref.read(filePickerProvider);
    final emblems = ref.read(emblemsProvider);
    final file = await picker(const XTypeGroup(
      label: 'image',
      extensions: ['png', 'jpg', 'jpeg', 'webp'],
    ));
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _busy = true);
    EmblemOutcome? outcome;
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'workspace emblem upload failed',
      errorText: l10n?.emblemFailed ??
          'The emblem could not be saved. Nothing changed.',
      action: () async => outcome = await emblems.choose(
        workspaceId: widget.workspaceId,
        bytes: bytes,
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    switch (outcome) {
      case EmblemOutcome.notAnImage:
        AppSnack.error(context,
            l10n?.emblemNotAnImage ?? 'That file is not an image.');
      case EmblemOutcome.tooHeavy:
        AppSnack.error(
            context,
            l10n?.emblemTooHeavy ??
                'That image is too heavy for a mark shown at 28 pixels.');
      case EmblemOutcome.stored:
        _reload();
        AppSnack.success(context, l10n?.emblemSaved ?? 'Emblem saved.');
      case EmblemOutcome.removed || null:
        break;
    }
  }

  /// Both providers hold the bytes, so both are stale after a write.
  void _reload() {
    ref
      ..invalidate(workspaceEmblemOfProvider(widget.workspaceId))
      ..invalidate(workspaceEmblemProvider);
  }

  Future<void> _remove() async {
    final l10n = AppLocalizations.of(context);
    final emblems = ref.read(emblemsProvider);
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'workspace emblem removal failed',
      errorText: l10n?.emblemFailed ??
          'The emblem could not be saved. Nothing changed.',
      action: () => emblems.remove(widget.workspaceId),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    _reload();
    AppSnack.success(context, l10n?.emblemRemoved ?? 'Emblem removed.');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final stored = ref.watch(workspaceEmblemOfProvider(widget.workspaceId));
    final has = stored.value?.isNotEmpty ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n?.emblemTitle ?? 'Emblem', style: theme.textTheme.titleSmall),
        Text(
          l10n?.emblemHint ??
              'A small image shown beneath the app’s own name in the menu. '
                  'It is redrawn at most 512 pixels wide and stored without '
                  'the file’s metadata.',
          key: const ValueKey('emblem-hint'),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        WorkspaceEmblem(
          key: const ValueKey('emblem-preview'),
          height: 40,
          workspaceId: widget.workspaceId,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            FilledButton.tonal(
              key: const ValueKey('emblem-pick'),
              onPressed: _busy ? null : _pick,
              child: Text(l10n?.emblemChoose ?? 'Choose an image'),
            ),
            TextButton(
              key: const ValueKey('emblem-remove'),
              onPressed: _busy || !has ? null : _remove,
              child: Text(l10n?.emblemRemove ?? 'Remove'),
            ),
          ],
        ),
      ],
    );
  }
}
