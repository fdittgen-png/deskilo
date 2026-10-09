// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/ui/section_jump_bar.dart';

class SettingsTaskSection extends StatelessWidget {
  const SettingsTaskSection({required this.id, required this.title,
    required this.children, this.initiallyExpanded = true, this.controller, super.key});
  final String id, title;
  final List<Widget> children;
  final bool initiallyExpanded;
  final ExpansibleController? controller;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: AppSpacing.md),
    child: ListTileTheme(
      data: const ListTileThemeData(minTileHeight: 56),
      child: ExpansionTile(key: PageStorageKey('settings-section-$id'),
        controller: controller,
        expansionAnimationStyle: AnimationStyle(duration: motionDuration(context, kThemeAnimationDuration)),
        maintainState: true, initiallyExpanded: initiallyExpanded,
        title: Text(title), children: children),
    ),
  );
}

class SettingsTaskPane extends StatefulWidget {
  const SettingsTaskPane({required this.pane, required this.children, super.key});
  final String pane;
  final List<Widget> children;
  @override
  State<SettingsTaskPane> createState() => _SettingsTaskPaneState();
}

class _SettingsTaskPaneState extends State<SettingsTaskPane> {
  final _controllers = <String, ExpansibleController>{};
  final _targets = <String, GlobalKey>{};
  final _focus = <String, FocusNode>{};
  @override
  void dispose() {
    for (final controller in _controllers.values) { controller.dispose(); }
    for (final node in _focus.values) { node.dispose(); }
    super.dispose();
  }
  Future<void> _jump(String id) async {
    final duration = motionDuration(context, kThemeAnimationDuration);
    _controllers[id]!.expand();
    _focus[id]!.requestFocus();
    if (duration != Duration.zero) { await Future<void>.delayed(duration); }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final target = _targets[id]?.currentContext;
    if (target != null && target.mounted) {
      await Scrollable.ensureVisible(target,
        duration: motionDuration(context, MotionTokens.standard));
    }
  }
  @override
  Widget build(BuildContext context) {
    final sections = widget.children.whereType<SettingsTaskSection>().toList();
    for (final section in sections) {
      _controllers.putIfAbsent(section.id, ExpansibleController.new);
      _targets.putIfAbsent(section.id, GlobalKey.new);
      _focus.putIfAbsent(section.id, () => FocusNode(skipTraversal: true));
    }
    return Column(children: [
      // #2313 — the shared section bar: one row, never wrapped.
      SectionJumpBar(items: [for (final section in sections) SectionJump(
        key: 'settings-link-${section.id}', label: section.title,
        onPressed: () => _jump(section.id))]),
      Expanded(child: SingleChildScrollView(
        key: PageStorageKey('settings-${widget.pane}'), padding: AppSpacing.gutterAll,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final child in widget.children)
            if (child is SettingsTaskSection) Focus(key: _targets[child.id],
              focusNode: _focus[child.id], child: SettingsTaskSection(
                id: child.id, title: child.title,
                initiallyExpanded: child.initiallyExpanded, controller: _controllers[child.id], children: child.children))
            else child,
        ]))),
    ]);
  }
}
