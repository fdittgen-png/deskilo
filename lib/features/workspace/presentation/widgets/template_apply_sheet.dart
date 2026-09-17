// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/apply_template.dart';
import '../../domain/template_preview.dart';
import '../../domain/workspace_template.dart';

/// #1280 S2 — flow B: apply a template to a workspace that already runs.
///
/// "Apply template" in a configured workspace was one button that merged
/// everything the template carries. Now the sheet shows what the SERVER
/// says would change, one row per group:
///
///   * **New** is ticked;
///   * **Changes what you have** is offered but unticked, so the existing
///     configuration is kept unless somebody chooses otherwise;
///   * **Already the same** has nothing to apply;
///   * **Needs attention** is shown with the server's reason, never
///     selectable — and so is a group this build cannot name.
///
/// The button names the count, "Apply N changes", and prices or roles ask
/// once more, naming the groups, before anything is written.
///
/// Returns the number of changes applied, or null when nothing was.
Future<int?> showTemplateApplySheet(BuildContext context, WidgetRef ref,
    String workspaceId, WorkspaceTemplate template) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        TemplateApplySheet(workspaceId: workspaceId, template: template),
  );
}

class TemplateApplySheet extends ConsumerStatefulWidget {
  const TemplateApplySheet({
    super.key,
    required this.workspaceId,
    required this.template,
  });

  final String workspaceId;
  final WorkspaceTemplate template;

  @override
  ConsumerState<TemplateApplySheet> createState() => _TemplateApplySheetState();
}

class _TemplateApplySheetState extends ConsumerState<TemplateApplySheet> {
  late final Future<TemplatePreview> _preview =
      previewTemplate(ref, widget.workspaceId, widget.template);
  Set<String>? _selected;
  bool _busy = false;

  static String groupLabel(AppLocalizations? l10n, TemplateGroup group) =>
      switch (group) {
        TemplateGroup.space => l10n?.libraryGroupSpace ?? 'Space & plan',
        TemplateGroup.hoursBooking =>
          l10n?.libraryGroupHoursBooking ?? 'Hours & booking',
        TemplateGroup.pricingCredits =>
          l10n?.libraryGroupPricingCredits ?? 'Prices & credits',
        TemplateGroup.calendarNavigation =>
          l10n?.libraryGroupCalendarNavigation ?? 'Calendar & closures',
        TemplateGroup.wording => l10n?.libraryGroupWording ?? 'Wording',
        TemplateGroup.rolesAccess =>
          l10n?.libraryGroupRolesAccess ?? 'Roles & access',
        TemplateGroup.forms => l10n?.libraryGroupForms ?? 'Forms',
        TemplateGroup.appearance => l10n?.libraryGroupAppearance ?? 'Appearance',
        TemplateGroup.documentsOperations =>
          l10n?.libraryGroupDocumentsOperations ?? 'Documents & operations',
        TemplateGroup.unknown => l10n?.libraryGroupUnknown ??
            'Other — this version cannot apply it',
      };

  static String stateLabel(AppLocalizations? l10n, TemplateGroupState state) =>
      switch (state) {
        TemplateGroupState.isNew => l10n?.libraryStateNew ?? 'New',
        TemplateGroupState.change =>
          l10n?.libraryStateChange ?? 'Changes what you have',
        TemplateGroupState.matching =>
          l10n?.libraryStateMatching ?? 'Already the same',
        TemplateGroupState.needsAttention ||
        TemplateGroupState.unknown =>
          l10n?.libraryStateAttention ?? 'Needs attention',
      };

  static String? reasonText(AppLocalizations? l10n, String? reason) =>
      switch (reason) {
        null => null,
        'fee_schedule_replaced_whole' => l10n?.libraryReasonFeeSchedule ??
            'Your fee schedule would be replaced as a whole.',
        final other => other,
      };

  Future<void> _apply(AppLocalizations? l10n, TemplatePreview preview) async {
    final selected = _selected ?? const <String>{};
    final sensitive = [
      for (final g in preview.groups)
        if (selected.contains(g.wire) && g.group.needsConfirmation)
          groupLabel(l10n, g.group),
    ];
    if (sensitive.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(l10n?.libraryConfirmSensitive(sensitive.join(', ')) ??
              'This changes ${sensitive.join(', ')}. Apply?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel)),
            FilledButton(
                key: const ValueKey('library-apply-sensitive-confirm'),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(MaterialLocalizations.of(ctx).okButtonLabel)),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    final count = preview.changesFor(selected);
    setState(() => _busy = true);
    final done = await runGuarded(
      context,
      domain: 'workspace',
      message: 'apply template failed',
      action: () => applyTemplateGroups(
          ref, widget.workspaceId, widget.template, selected),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (done) Navigator.of(context).pop(count);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: FutureBuilder<TemplatePreview>(
        future: _preview,
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: AppSpacing.gutterAll,
              child: InlineBanner(
                icon: Icons.error_outline,
                text: l10n?.libraryPreviewFailed ??
                    'The changes could not be previewed. Nothing was applied.',
              ),
            );
          }
          final preview = snap.data;
          if (preview == null) {
            return const SizedBox(height: 200, child: LoadingView());
          }
          final selected = _selected ??= {
            for (final g in preview.groups)
              if (g.selectedByDefault) g.wire,
          };
          final count = preview.changesFor(selected);
          final anythingToApply = preview.groups.any((g) => g.selectable);
          return SingleChildScrollView(
            padding: AppSpacing.gutterAll,
            child: Column(
              key: const ValueKey('template-apply-sheet'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n?.libraryPreviewTitle(widget.template.name) ??
                      'What « ${widget.template.name} » would change',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (!preview.applicable)
                  InlineBanner(
                    key: const ValueKey('template-apply-not-supported'),
                    icon: Icons.block,
                    text: [
                      l10n?.libraryNotSupported ??
                          'This template cannot be applied here.',
                      if (preview.reason != null) preview.reason!,
                    ].join(' '),
                  )
                else ...[
                  if (preview.compatibility == TemplateCompatibility.partial)
                    InlineBanner(
                      key: const ValueKey('template-apply-partial'),
                      icon: Icons.info_outline,
                      severity: InlineBannerSeverity.info,
                      text: l10n?.libraryPartial ??
                          'Part of this template cannot be applied here and '
                              'is left out.',
                    ),
                  if (!anythingToApply)
                    Text(
                      l10n?.libraryNothingToApply ??
                          'Everything this template carries is already here.',
                      key: const ValueKey('template-apply-nothing'),
                    ),
                  for (final g in preview.groups)
                    _GroupRow(
                      key: ValueKey('template-group-${g.wire}'),
                      title: groupLabel(l10n, g.group),
                      state: stateLabel(l10n, g.state),
                      reason: reasonText(l10n, g.reason),
                      enabled: g.selectable && !_busy,
                      value: g.selectable ? selected.contains(g.wire) : null,
                      onChanged: (on) => setState(() => on
                          ? selected.add(g.wire)
                          : selected.remove(g.wire)),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    key: const ValueKey('library-apply-confirm'),
                    onPressed: count == 0 || _busy
                        ? null
                        : () => _apply(l10n, preview),
                    child: Text(l10n?.libraryApplyChanges(count) ??
                        'Apply $count changes'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    super.key,
    required this.title,
    required this.state,
    required this.reason,
    required this.enabled,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String state;
  final String? reason;
  final bool enabled;

  /// Null when the group is not selectable at all.
  final bool? value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final subtitle = [state, ?reason].join(' — ');
    if (value == null) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.remove_circle_outline),
        title: Text(title),
        subtitle: Text(subtitle),
        enabled: false,
      );
    }
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: enabled ? (v) => onChanged(v ?? false) : null,
    );
  }
}
