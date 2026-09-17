// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/workspace_providers.dart';
import 'template_gallery.dart';

/// #1120 — "Start from": the templates a person may read, one selected.
/// Null selection means an empty canvas.
///
/// #1280 S1 — the cards are the shared [TemplateGallery], in a window of
/// fixed height inside the onboarding form, so a hundred templates are
/// searched and built lazily instead of wrapped into one tall block.
///
/// No feature flag here on purpose: at onboarding there is no workspace
/// yet to hold a flag, and a new space starting with a room is the whole
/// point of #1120's first step. The server decides which rows are
/// readable; the picker shows what it returned, builtin first.
class TemplatePicker extends ConsumerWidget {
  const TemplatePicker({
    super.key,
    required this.selectedId,
    required this.onChanged,
  });

  final String? selectedId;
  final ValueChanged<String?> onChanged;

  /// The gallery's window inside the scrolling onboarding form.
  static const galleryHeight = 360.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final templates = ref.watch(workspaceTemplatesProvider).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n?.onboardingStartFrom ?? 'Start from',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: galleryHeight,
          child: TemplateGallery(
            sections: [
              TemplateGallerySection(
                title: l10n?.onboardingStartFrom ?? 'Start from',
                templates: templates,
              ),
            ],
            selectedId: selectedId,
            onSelected: onChanged,
            offerEmpty: true,
          ),
        ),
      ],
    );
  }
}
