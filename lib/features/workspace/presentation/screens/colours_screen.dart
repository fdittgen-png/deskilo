// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1289 S2 — the screen where a space chooses its colour.
//
// One colour goes in and both themes come out, so this shows what the
// choice DOES rather than a hex field alone: the derived light and dark
// swatches, beside the product's, updating as the owner picks. A colour
// the app could not make readable is refused here, naming the pair, and
// nothing is written — the same measurement the accessibility lint runs
// over the shipped schemes (`DeskiloTheme.refusals`).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../application/workspace_colours.dart';
import '../../domain/workspace_branding.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/emblem_editor.dart';
import '../widgets/office_palette_editor.dart';
import '../widgets/pattern_picker.dart';
import '../widgets/symbol_editor.dart';

/// Colours an owner can reach in one tap. Not a restriction — the field
/// takes any `#RRGGBB` — but a colour wheel answers "which of the
/// sixteen million" with nothing, and these are the ones a coworking
/// space actually asks for.
const List<(String, String)> _suggestedBrandColours = [
  ('#C2410C', 'burnt orange'),
  ('#1F3A5F', 'navy'),
  ('#1B5E20', 'forest'),
  ('#00695C', 'teal'),
  ('#7B1E3A', 'bordeaux'),
  ('#6D28D9', 'purple'),
  ('#374151', 'charcoal'),
  ('#9A3412', 'brick'),
];

class ColoursScreen extends ConsumerStatefulWidget {
  const ColoursScreen({super.key});

  @override
  ConsumerState<ColoursScreen> createState() => _ColoursScreenState();
}

class _ColoursScreenState extends ConsumerState<ColoursScreen> {
  final _field = TextEditingController();
  bool _seeded = false;
  bool _busy = false;
  List<String>? _fills;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _apply(String text) async {
    final l10n = context.l10n;
    final errorText =
        l10n.coloursSaveFailed;
    final colours = ref.read(workspaceColoursProvider);
    final workspace = await ref.read(currentWorkspaceProvider.future);
    if (workspace == null || !mounted) return;
    setState(() => _busy = true);
    ColourOutcome? outcome;
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'workspace colour save failed',
      errorText: errorText,
      action: () async => outcome =
          await colours.choose(workspaceId: workspace.id, text: text),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    switch (outcome) {
      case ColourApplied(:final hex):
        ref.invalidate(myWorkspacesProvider);
        AppSnack.success(context, l10n.coloursApplied(hex));
      case ColourReset():
        ref.invalidate(myWorkspacesProvider);
        setState(() => _field.text = '');
        AppSnack.success(
            context, l10n.coloursResetDone);
      case ColourMalformed(:final text):
        AppSnack.error(
            context, l10n.coloursMalformed(text));
      case ColourRefused(:final pair):
        AppSnack.error(context,
            l10n.coloursRefused(pair));
      case ColourTooMany(:final most):
        AppSnack.error(
            context,
            l10n.coloursTooMany(most));
      case null:
        break;
    }
  }

  /// The room fills, written as one list: the order is what the plan
  /// reads, so a partial write would repaint the wrong rooms.
  Future<void> _saveFills(List<String> fills) async {
    final l10n = context.l10n;
    final errorText = l10n.coloursSaveFailed;
    final colours = ref.read(workspaceColoursProvider);
    final workspace = await ref.read(currentWorkspaceProvider.future);
    if (workspace == null || !mounted) return;
    setState(() => _busy = true);
    ColourOutcome? outcome;
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'workspace room colours save failed',
      errorText: errorText,
      action: () async => outcome = await colours.chooseOfficePalette(
        workspaceId: workspace.id,
        fills: fills,
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    ref.invalidate(myWorkspacesProvider);
    switch (outcome) {
      case ColourReset():
        setState(() => _fills = const []);
        AppSnack.success(
            context, l10n.coloursResetDone);
      case ColourApplied():
        AppSnack.success(context,
            l10n.coloursRoomsSaved(fills.length));
      case ColourMalformed(:final text):
        AppSnack.error(context,
            l10n.coloursMalformed(text));
      case ColourTooMany(:final most):
        AppSnack.error(
            context,
            l10n.coloursTooMany(most));
      case ColourRefused() || null:
        break;
    }
  }

  /// #2313 — the pattern the colour is drawn in where the space is told
  /// apart from the others.
  Future<void> _savePattern(BrandPattern pattern) async {
    final l10n = context.l10n;
    final colours = ref.read(workspaceColoursProvider);
    final workspace = await ref.read(currentWorkspaceProvider.future);
    if (workspace == null || !mounted) return;
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'workspace pattern save failed',
      errorText: l10n.coloursSaveFailed,
      action: () => colours.choosePattern(
        workspaceId: workspace.id,
        pattern: pattern == BrandPattern.solid ? null : pattern,
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    ref.invalidate(myWorkspacesProvider);
    AppSnack.success(context, l10n.coloursPatternSaved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final stored = WorkspaceBranding.fromJson(workspace?.branding ?? const {});
    if (!_seeded && workspace != null) {
      _seeded = true;
      _field.text = stored.seedArgb == null ? '' : hexOfColor(stored.seedArgb!);
      _fills = [for (final c in stored.officePalette) hexOfColor(c)];
    }
    final fills = _fills ?? const <String>[];
    final typed = parseHexColor(_field.text);
    final refusals = typed == null ? const <String>[] : [
      for (final f in DeskiloTheme.refusals(Color(typed))) f.pair,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.coloursTitle)),
      body: ListView(
        padding: AppSpacing.gutterAll,
        children: [
          Text(
            l10n.coloursIntro,
            key: const ValueKey('colours-intro'),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final (hex, name) in _suggestedBrandColours)
                _Swatch(
                  key: ValueKey('colours-pick-$hex'),
                  argb: parseHexColor(hex)!,
                  label: name,
                  selected: _field.text.toUpperCase() == hex,
                  onTap: _busy
                      ? null
                      : () => setState(() => _field.text = hex),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('colours-hex'),
            controller: _field,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: l10n.coloursHexLabel,
              hintText: '#C2410C',
              helperText: l10n.coloursHexHint,
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (refusals.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            InlineBanner(
              key: const ValueKey('colours-refusal'),
              icon: Icons.block,
              text: l10n.coloursRefused(refusals.first),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _Preview(
            key: const ValueKey('colours-preview'),
            brand: typed == null ? null : Color(typed),
            title: l10n.coloursPreview,
          ),
          const SizedBox(height: AppSpacing.md),
          // Wrap, not Row: "Product colours" is a long word in four of
          // the five languages and a 360 dp screen has no room for both
          // buttons on one line.
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton(
                key: const ValueKey('colours-apply'),
                onPressed: _busy || refusals.isNotEmpty
                    ? null
                    : () => _apply(_field.text),
                child: Text(l10n.commonSave),
              ),
              TextButton(
                key: const ValueKey('colours-reset'),
                onPressed: _busy || stored.seedArgb == null
                    ? null
                    : () => _apply(''),
                child: Text(l10n.coloursReset),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          PatternPicker(
            key: const ValueKey('colours-pattern'),
            color: Color(
              stored.seedArgb ?? Theme.of(context).colorScheme.primary.toARGB32(),
            ),
            selected: stored.pattern,
            busy: _busy,
            onPick: _savePattern,
          ),
          const SizedBox(height: AppSpacing.lg),
          OfficePaletteEditor(
            key: const ValueKey('colours-office-palette-editor'),
            fills: fills,
            busy: _busy,
            onChanged: (next) => setState(() => _fills = next),
            onSave: () => _saveFills(fills),
            onReset: () => _saveFills(const []),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (workspace != null) ...[
            SymbolEditor(workspaceId: workspace.id),
            const SizedBox(height: AppSpacing.lg),
            EmblemEditor(workspaceId: workspace.id),
            Text(
              l10n.coloursLogoHint,
              key: const ValueKey('colours-logo-hint'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.coloursNeverTheirs,
            key: const ValueKey('colours-never'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    super.key,
    required this.argb,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final int argb;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        key: const ValueKey('colours-check'),
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Color(argb),
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
              width: selected ? 3 : 1,
            ),
          ),
          child: selected
              ? Icon(Icons.check,
                  color: Color(
                      DeskiloTheme.light(brand: Color(argb)).colorScheme.onPrimary.toARGB32()))
              : null,
        ),
      );
}

/// The two schemes the seed derives, beside each other: a choice whose
/// effect is only visible after saving is a choice made blind.
class _Preview extends StatelessWidget {
  const _Preview({super.key, required this.brand, required this.title});

  final Color? brand;
  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _Sample(
                theme: DeskiloTheme.light(brand: brand),
                label: l10n.coloursLight,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _Sample(
                theme: DeskiloTheme.dark(brand: brand),
                label: l10n.coloursDark,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Sample extends StatelessWidget {
  const _Sample({required this.theme, required this.label});

  final ThemeData theme;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: cs.onSurface)),
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: AppRadius.smAll,
            ),
            child: Text(
              context.l10n.commonSave,
              style: TextStyle(color: cs.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
