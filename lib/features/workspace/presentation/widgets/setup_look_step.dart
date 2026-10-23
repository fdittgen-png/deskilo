// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup step "look": the space's own colour, prefilled from the stored
// brand seed and saved through the colours screen's own decision
// ([WorkspaceColours.choose]), which refuses a colour the app could not
// make readable. The pattern, the room colours and the logo stay on the
// colours screen, one tap away. The preview is the app as members get it:
// the bar with the space's name and a button, in the light and the dark
// theme the colour derives, redrawn as the owner picks.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/setup_step_layout.dart';
import '../../application/workspace_colours.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_branding.dart';
import '../../providers/workspace_providers.dart';
import '../screens/colours_screen.dart';

class SetupLookStep extends ConsumerStatefulWidget {
  const SetupLookStep({super.key, required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<SetupLookStep> createState() => _SetupLookStepState();
}

class _SetupLookStepState extends ConsumerState<SetupLookStep> {
  late final _hex = TextEditingController(
    text: switch (WorkspaceBranding.fromJson(widget.workspace.branding)) {
      WorkspaceBranding(:final seedArgb?) => hexOfColor(seedArgb),
      _ => '',
    },
  );
  final _busy = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _hex.dispose();
    _busy.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    _busy.value = true;
    ColourOutcome? outcome;
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'setup workspace colour failed',
      errorText: l10n.coloursSaveFailed,
      action: () async => outcome = await ref
          .read(workspaceColoursProvider)
          .choose(workspaceId: widget.workspace.id, text: _hex.text),
    );
    if (!mounted) return;
    _busy.value = false;
    if (!ok) return;
    switch (outcome) {
      case ColourApplied(:final hex):
        ref.invalidate(myWorkspacesProvider);
        AppSnack.success(context, l10n.coloursApplied(hex));
      case ColourReset():
        ref.invalidate(myWorkspacesProvider);
        AppSnack.success(context, l10n.coloursResetDone);
      case ColourMalformed(:final text):
        AppSnack.error(context, l10n.coloursMalformed(text));
      case ColourRefused(:final pair):
        AppSnack.error(context, l10n.coloursRefused(pair));
      case ColourTooMany() || null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_hex, _busy]),
    builder: (context, _) {
      final typed = parseHexColor(_hex.text.trim());
      final brand = typed == null ? null : Color(typed);
      final refusals = brand == null
          ? const <String>[]
          : [for (final f in DeskiloTheme.refusals(brand)) f.pair];
      return SetupStepLayout(
        form: _form(context, refusals),
        preview: _Preview(name: widget.workspace.name, brand: brand),
      );
    },
  );

  Widget _form(BuildContext context, List<String> refusals) {
    final l10n = context.l10n;
    final busy = _busy.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.setupStepHint('look')),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.coloursIntro, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final (hex, _) in suggestedBrandColours)
              InkWell(
                key: ValueKey('setup-look-pick-$hex'),
                onTap: busy ? null : () => _hex.text = hex,
                borderRadius: AppRadius.mdAll,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Color(parseHexColor(hex)!),
                    borderRadius: AppRadius.mdAll,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                      width: _hex.text.trim().toUpperCase() == hex ? 3 : 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          key: const ValueKey('setup-look-hex'),
          controller: _hex,
          label: l10n.coloursHexLabel,
          helper: l10n.coloursHexHint,
          enabled: !busy,
        ),
        if (refusals.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          InlineBanner(
            key: const ValueKey('setup-look-refusal'),
            icon: Icons.block,
            text: l10n.coloursRefused(refusals.first),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton(
              key: const ValueKey('setup-look-save'),
              onPressed: busy || refusals.isNotEmpty ? null : _save,
              child: Text(l10n.commonSave),
            ),
            TextButton(
              key: const ValueKey('setup-look-more'),
              onPressed: () => context.push('/settings/colours'),
              child: Text(l10n.setupLookMore),
            ),
          ],
        ),
      ],
    );
  }
}

/// The space's bar and a button, in the light and the dark theme [brand]
/// derives; the product's own palette while there is none.
class _Preview extends StatelessWidget {
  const _Preview({required this.name, required this.brand});

  final String name;
  final Color? brand;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget sample(String key, ThemeData theme, String label) => Theme(
      data: theme,
      child: Material(
        key: ValueKey(key),
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBar(
              primary: false,
              automaticallyImplyLeading: false,
              title: Text(name, overflow: TextOverflow.ellipsis),
            ),
            Padding(
              padding: AppSpacing.mdAll,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                    ),
                  ),
                  // A picture of a button: nothing here acts.
                  IgnorePointer(
                    child: FilledButton(
                      key: ValueKey('$key-button'),
                      onPressed: () {},
                      child: Text(l10n.commonSave),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Column(
      key: const ValueKey('setup-look-preview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sample(
          'setup-look-preview-light',
          DeskiloTheme.light(brand: brand),
          l10n.coloursLight,
        ),
        const SizedBox(height: AppSpacing.sm),
        sample(
          'setup-look-preview-dark',
          DeskiloTheme.dark(brand: brand),
          l10n.coloursDark,
        ),
      ],
    );
  }
}
