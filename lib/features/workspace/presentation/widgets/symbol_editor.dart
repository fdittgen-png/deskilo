// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A workspace's symbol: one or two letters on a colour, round like the
// profile photo. The pair is unique across workspaces; when it is taken the
// owner is told to pick another colour or use a photo instead.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/workspace_symbol.dart';
import '../../domain/workspace_branding.dart';
import '../../providers/workspace_providers.dart';
import '../../providers/workspace_symbol_provider.dart';
import 'workspace_avatar.dart';

class SymbolEditor extends ConsumerStatefulWidget {
  const SymbolEditor({super.key, required this.workspaceId});
  final String workspaceId;

  @override
  ConsumerState<SymbolEditor> createState() => _SymbolEditorState();
}

class _SymbolEditorState extends ConsumerState<SymbolEditor> {
  final _text = TextEditingController();
  String _colour = symbolColours.first;
  bool _seeded = false;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _run(Future<SymbolOutcome> Function(WorkspaceSymbols) act) async {
    final l10n = AppLocalizations.of(context);
    final symbols = ref.read(workspaceSymbolsProvider);
    setState(() => _busy = true);
    SymbolOutcome? outcome;
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'workspace symbol save failed',
      errorText: l10n?.symbolSaveFailed ??
          'The symbol could not be saved. Nothing changed.',
      action: () async => outcome = await act(symbols),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    switch (outcome) {
      case SymbolOutcome.malformed:
        AppSnack.error(
            context,
            l10n?.symbolLettersRule ??
                'Use one or two letters or digits for the symbol.');
      case SymbolOutcome.taken:
        AppSnack.error(
            context,
            l10n?.symbolTaken ??
                'Another workspace already uses these letters in this colour. '
                    'Choose another colour or letters — or use a photo instead.');
      case SymbolOutcome.saved || SymbolOutcome.removed:
        if (outcome == SymbolOutcome.removed) _text.clear();
        ref
          ..invalidate(myWorkspacesProvider)
          ..invalidate(workspaceEmblemOfProvider(widget.workspaceId))
          ..invalidate(workspaceEmblemProvider);
        if (outcome == SymbolOutcome.saved) {
          AppSnack.success(context, l10n?.symbolSaved ?? 'Symbol saved.');
        }
      case null:
        break;
    }
  }

  Future<void> _save() => _run(
        (s) => s.choose(
          workspaceId: widget.workspaceId,
          text: _text.text,
          colourHex: _colour,
        ),
      );

  Future<void> _remove() => _run((s) => s.remove(widget.workspaceId));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final workspace = ref
        .watch(myWorkspacesProvider)
        .value
        ?.where((w) => w.id == widget.workspaceId)
        .firstOrNull;
    final stored = workspace == null ? null : WorkspaceSymbol.of(workspace.branding);
    if (!_seeded && stored != null) {
      _seeded = true;
      _text.text = stored.text;
      _colour = stored.colourHex;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n?.symbolTitle ?? 'Symbol', style: theme.textTheme.titleSmall),
        Text(
          l10n?.symbolHint ??
              'A round mark of one or two letters on a colour, unique to this '
                  'workspace — or use a photo below instead.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            if (workspace != null)
              WorkspaceAvatar(workspace: workspace, radius: 24),
            const SizedBox(width: AppSpacing.md),
            SizedBox(
              width: 96,
              child: TextField(
                key: const ValueKey('symbol-letters'),
                controller: _text,
                maxLength: 2,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: l10n?.symbolLetters ?? 'Letters',
                  counterText: '',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final hex in symbolColours)
              Semantics(
                button: true,
                selected: hex == _colour,
                label: hex,
                child: InkWell(
                  key: ValueKey('symbol-colour-$hex'),
                  customBorder: const CircleBorder(),
                  onTap: () => setState(() => _colour = hex),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(parseHexColor(hex)!),
                      border: Border.all(
                        width: hex == _colour ? 3 : 1,
                        color: hex == _colour
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            FilledButton.tonal(
              key: const ValueKey('symbol-save'),
              onPressed: _busy ? null : _save,
              child: Text(l10n?.commonSave ?? 'Save'),
            ),
            TextButton(
              key: const ValueKey('symbol-remove'),
              onPressed: _busy || stored == null ? null : _remove,
              child: Text(l10n?.emblemRemove ?? 'Remove'),
            ),
          ],
        ),
      ],
    );
  }
}
