// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/motion/motion.dart';
import '../../../../l10n/app_localizations.dart';

/// Mounted fields keep their drafts and validation while a task is closed.
class WorkspaceFormGroup extends StatefulWidget {
  const WorkspaceFormGroup({required this.id, required this.title,
    required this.icon, required this.children, this.initiallyExpanded = false,
    super.key});
  final String id, title;
  final IconData icon;
  final List<Widget> children;
  final bool initiallyExpanded;

  static bool validate(FormState? form) {
    if (form == null) return false;
    final invalid = form.validateGranularly();
    final first = invalid.isEmpty ? null : invalid.first;
    final group = first?.context.findAncestorStateOfType<_WorkspaceFormGroupState>();
    final wasClosed = group != null && !group._controller.isExpanded;
    for (final field in invalid) {
      field.context.findAncestorStateOfType<_WorkspaceFormGroupState>()?._controller.expand();
    }
    if (first != null && group != null) unawaited(group.reveal(first, wasClosed));
    return invalid.isEmpty;
  }

  @override
  State<WorkspaceFormGroup> createState() => _WorkspaceFormGroupState();
}

class _WorkspaceFormGroupState extends State<WorkspaceFormGroup> {
  final _controller = ExpansibleController();
  final _headingFocus = FocusNode(skipTraversal: true);
  Future<void> open() async {
    final duration = motionDuration(context, kThemeAnimationDuration);
    _controller.expand();
    _headingFocus.requestFocus();
    if (duration != Duration.zero) { await Future<void>.delayed(duration); }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await Scrollable.ensureVisible(context,
      duration: motionDuration(context, MotionTokens.standard));
  }
  Future<void> reveal(FormFieldState<Object?> field, bool wasClosed) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !field.mounted) return;
    if (wasClosed) {
      await Future<void>.delayed(kThemeAnimationDuration);
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted || !field.mounted) return;
    await Scrollable.ensureVisible(field.context, duration: kThemeAnimationDuration,
      alignment: 0.1);
  }
  @override
  void dispose() { _controller.dispose(); _headingFocus.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: AppSpacing.md),
    child: ExpansionTile(key: ValueKey('workspace-group-${widget.id}'),
      controller: _controller, maintainState: true,
      expansionAnimationStyle: AnimationStyle(duration: motionDuration(context, kThemeAnimationDuration)),
      onExpansionChanged: (open) { if (!open) FocusScope.of(context).unfocus(); setState(() {}); },
      initiallyExpanded: widget.initiallyExpanded,
      leading: Icon(widget.icon), title: Focus(focusNode: _headingFocus, child: Text(widget.title)),
      childrenPadding: AppSpacing.gutterAll,
      children: [TickerMode(enabled: _controller.isExpanded,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
          children: widget.children))]),
  );
}

/// Shortcuts stay visible; content remains one draft-preserving form.
class WorkspaceFormSections extends StatefulWidget {
  const WorkspaceFormSections({required this.children, super.key});
  final List<Widget> children;
  @override
  State<WorkspaceFormSections> createState() => _WorkspaceFormSectionsState();
}

class _WorkspaceFormSectionsState extends State<WorkspaceFormSections> {
  final _groups = <String, GlobalKey<_WorkspaceFormGroupState>>{};
  @override
  Widget build(BuildContext context) {
    final groups = widget.children.whereType<WorkspaceFormGroup>().toList();
    for (final group in groups) {
      _groups.putIfAbsent(group.id, GlobalKey<_WorkspaceFormGroupState>.new);
    }
    return Column(children: [
      Padding(padding: AppSpacing.smAll, child: Wrap(spacing: AppSpacing.xs,
        children: [for (final group in groups) TextButton(
          key: ValueKey('workspace-section-${group.id}'),
          onPressed: () => _groups[group.id]?.currentState?.open(),
          child: Text(group.title))])),
      Expanded(child: SingleChildScrollView(padding: AppSpacing.gutterAll,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final child in widget.children)
            if (child is WorkspaceFormGroup) WorkspaceFormGroup(key: _groups[child.id],
              id: child.id, title: child.title, icon: child.icon,
              initiallyExpanded: child.initiallyExpanded, children: child.children)
            else child,
        ]))),
    ]);
  }
}

class WorkspaceSettingsSaveBar extends StatelessWidget {
  const WorkspaceSettingsSaveBar({required this.busy, required this.onSave, super.key});
  final bool busy;
  final VoidCallback onSave;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(top: false, child: Padding(padding: AppSpacing.gutterAll,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: double.infinity, child: FilledButton.icon(
          key: const Key('workspaceSettingsSave'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: busy ? null : () { FocusScope.of(context).unfocus(); onSave(); },
          icon: Icon(busy ? Icons.hourglass_top : Icons.save_outlined),
          label: Text(AppLocalizations.of(context)?.commonSave ?? 'Save'))),
      ]))),
  );
}
