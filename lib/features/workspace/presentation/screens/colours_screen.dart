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
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/workspace_colours.dart';
import '../../domain/workspace_branding.dart';
import '../widgets/office_palette_editor.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/emblem_editor.dart';

/// Colours an owner can reach in one tap. Not a restriction — the field
/// takes any `#RRGGBB` — but a colour wheel answers "which of the
/// sixteen million" with nothing, and these are the ones a coworking
/// space actually asks for.
const List<(String, String)> suggestedBrandColours = [
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
    final l10n = AppLocalizations.of(context);
    final errorText =
        l10n?.coloursSaveFailed ?? 'The colour could not be saved. Nothing changed.';
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
        AppSnack.success(context, l10n?.coloursApplied(hex) ?? 'Colour $hex applied.');
      case ColourReset():
        ref.invalidate(myWorkspacesProvider);
        setState(() => _field.text = '');
        AppSnack.success(
            context, l10n?.coloursResetDone ?? 'The product colours are back.');
      case ColourMalformed(:final text):
        AppSnack.error(
            context, l10n?.coloursMalformed(text) ?? '$text is not a #RRGGBB colour.');
      case ColourRefused(:final pair):
        AppSnack.error(context,
            l10n?.coloursRefused(pair) ?? 'Refused: $pair would be unreadable.');
      case ColourTooMany(:final most):
        AppSnack.error(
            context,
            l10n?.coloursTooMany(most) ??
                'The plan paints at most $most room colours.');
      case null:
        break;
    }
  }

  /// The room fills, written as one list: the order is what the plan
  /// reads, so a partial write would repaint the wrong rooms.
  Future<void> _saveFills(List<String> fills) async {
    final l10n = AppLocalizations.of(context);
    final errorText = l10n?.coloursSaveFailed ??
        'The colour could not be saved. Nothing changed.';
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
            context, l10n?.coloursResetDone ?? 'The product colours are back.');
      case ColourApplied():
        AppSnack.success(context,
            l10n?.coloursRoomsSaved(fills.length) ?? '${fills.length} saved.');
      case ColourMalformed(:final text):
        AppSnack.error(context,
            l10n?.coloursMalformed(text) ?? '$text is not a #RRGGBB colour.');
      case ColourTooMany(:final most):
        AppSnack.error(
            context,
            l10n?.coloursTooMany(most) ??
                'The plan paints at most $most room colours.');
      case ColourRefused() || null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
      appBar: AppBar(title: Text(l10n?.coloursTitle ?? 'Colours')),
      body: ListView(
        padding: AppSpacing.gutterAll,
        children: [
          Text(
            l10n?.coloursIntro ??
                'One colour, and the app derives its light and dark themes '
                    'from it. Everything else keeps the product palette.',
            key: const ValueKey('colours-intro'),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final (hex, name) in suggestedBrandColours)
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
              labelText: l10n?.coloursHexLabel ?? 'Colour',
              hintText: '#C2410C',
              helperText: l10n?.coloursHexHint ??
                  'Six hexadecimal digits. Leave empty for the product colours.',
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (refusals.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            InlineBanner(
              key: const ValueKey('colours-refusal'),
              icon: Icons.block,
              text: l10n?.coloursRefused(refusals.first) ??
                  'Refused: ${refusals.first} would be unreadable.',
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _Preview(
            key: const ValueKey('colours-preview'),
            brand: typed == null ? null : Color(typed),
            title: l10n?.coloursPreview ?? 'What it looks like',
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
                child: Text(l10n?.commonSave ?? 'Save'),
              ),
              TextButton(
                key: const ValueKey('colours-reset'),
                onPressed: _busy || stored.seedArgb == null
                    ? null
                    : () => _apply(''),
                child: Text(l10n?.coloursReset ?? 'Product colours'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          OfficePaletteEditor(
            fills: fills,
            busy: _busy,
            onChanged: (next) => setState(() => _fills = next),
            onSave: () => _saveFills(fills),
            onReset: () => _saveFills(const []),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (workspace != null) EmblemEditor(workspaceId: workspace.id),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n?.coloursNeverTheirs ??
                'The DesKilo mark, the colours of the seat states and the '
                    'production banner are the product’s, in every space.',
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
    final l10n = AppLocalizations.of(context);
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
                label: l10n?.coloursLight ?? 'Light',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _Sample(
                theme: DeskiloTheme.dark(brand: brand),
                label: l10n?.coloursDark ?? 'Dark',
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
              AppLocalizations.of(context)?.commonSave ?? 'Save',
              style: TextStyle(color: cs.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
