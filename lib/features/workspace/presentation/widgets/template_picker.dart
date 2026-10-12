// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
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
///
/// #1660 — a request that is still out, or that failed, is not an empty
/// library: it shows a spinner, or the failure with a retry, and never
/// leaves "Empty space" as the only thing on offer.
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
    final l10n = context.l10n;
    final async = ref.watch(workspaceTemplatesProvider);
    final templates = async.value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.onboardingStartFrom,
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: galleryHeight,
          child: async.hasError && !async.hasValue
              ? Align(
                  alignment: Alignment.topCenter,
                  child: InlineBanner(
                    key: const ValueKey('template-picker-failed'),
                    icon: Icons.cloud_off_outlined,
                    text: l10n.templatesLoadFailed,
                    actionLabel: l10n.commonRetry,
                    onAction: () => ref.invalidate(workspaceTemplatesProvider),
                  ),
                )
              : !async.hasValue
              ? const LoadingView(key: ValueKey('template-picker-loading'))
              : TemplateGallery(
            key: const ValueKey('template-picker-onboarding-start-from'),
            sections: [
              TemplateGallerySection(
                title: l10n.onboardingStartFrom,
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

/// #1660 — on the confirm step, when the templates never arrived: the
/// empty space is what the failure leaves, not what was picked.
class TemplatesFailedNotice extends ConsumerWidget {
  const TemplatesFailedNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workspaceTemplatesProvider);
    if (!async.hasError || async.hasValue) return const SizedBox.shrink();
    final l10n = context.l10n;
    return InlineBanner(
      key: const ValueKey('onboarding-confirm-templates-failed'),
      icon: Icons.cloud_off_outlined,
      text:
          l10n.onboardingTemplatesFailedEmpty,
    );
  }
}
