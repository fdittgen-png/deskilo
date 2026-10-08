// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_spacing.dart';
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
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: AppSpacing.md),
    child: ExpansionTile(key: ValueKey('workspace-group-${widget.id}'),
      controller: _controller, maintainState: true,
      onExpansionChanged: (open) { if (!open) FocusScope.of(context).unfocus(); setState(() {}); },
      initiallyExpanded: widget.initiallyExpanded,
      leading: Icon(widget.icon), title: Text(widget.title),
      childrenPadding: AppSpacing.gutterAll,
      children: [TickerMode(enabled: _controller.isExpanded,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
          children: widget.children))]),
  );
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
