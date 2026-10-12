// SPDX-License-Identifier: AGPL-3.0-or-later
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
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
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
    final l10n = context.l10n;
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
      errorText: l10n.emblemFailed,
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
            l10n.emblemNotAnImage);
      case EmblemOutcome.tooHeavy:
        AppSnack.error(
            context,
            l10n.emblemTooHeavy);
      case EmblemOutcome.stored:
        ref.invalidate(myWorkspacesProvider);
        _reload();
        AppSnack.success(context, l10n.emblemSaved);
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
    final l10n = context.l10n;
    final emblems = ref.read(emblemsProvider);
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'workspace emblem removal failed',
      errorText: l10n.emblemFailed,
      action: () => emblems.remove(widget.workspaceId),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    _reload();
    AppSnack.success(context, l10n.emblemRemoved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final stored = ref.watch(workspaceEmblemOfProvider(widget.workspaceId));
    final has = stored.value?.isNotEmpty ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.emblemTitle, style: theme.textTheme.titleSmall),
        Text(
          l10n.emblemHint,
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
              child: Text(l10n.emblemChoose),
            ),
            TextButton(
              key: const ValueKey('emblem-remove'),
              onPressed: _busy || !has ? null : _remove,
              child: Text(l10n.emblemRemove),
            ),
          ],
        ),
      ],
    );
  }
}
