// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2869 — a setup step's form inside its draft. On opening, a draft the
// server holds goes back over the stored values ("Draft restored ·
// Discard"); every edit is saved as the owner pauses, "Saved" only once
// the server answered; a draft another configurer changed meanwhile offers
// Reload or Keep mine. The page's own save applies the answers and drops
// the draft ([SetupDraftForm.applied]). The page only says what its
// answers are and how to put them back; everything else is here, once.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/setup_draft_form.dart';
import '../../application/setup_draft_autosave.dart';
import '../../domain/setup_step_draft.dart';
import 'setup_draft_bar.dart';

/// The frame for [step] of [workspaceId], as a [SetupDraftFrameBuilder]
/// for pages of the features above this one.
SetupDraftFrameBuilder setupDraftFrameFor(String workspaceId, String step) =>
    ({required SetupDraftForm form, required Widget child}) => SetupDraftFrame(
      workspaceId: workspaceId,
      step: step,
      form: form,
      child: child,
    );

class SetupDraftFrame extends ConsumerStatefulWidget {
  const SetupDraftFrame({
    super.key,
    required this.workspaceId,
    required this.step,
    required this.form,
    required this.child,
  });

  final String workspaceId;

  /// The catalogue id of the step (`setup_steps.dart`).
  final String step;
  final SetupDraftForm form;

  /// The step's form.
  final Widget child;

  @override
  ConsumerState<SetupDraftFrame> createState() => _SetupDraftFrameState();
}

class _SetupDraftFrameState extends ConsumerState<SetupDraftFrame> {
  late final _draft = setupDraftAutosaveProvider(
    widget.workspaceId,
    widget.step,
  );

  /// The form shows answers restored from the draft.
  final _restored = ValueNotifier<bool>(false);

  /// Set while the frame itself fills the form: that is not an edit.
  var _filling = false;

  @override
  void initState() {
    super.initState();
    // The draft lives as long as the page; leaving sends what is pending.
    ref.listenManual(_draft, (_, _) {});
    widget.form.edits.addListener(_edited);
    widget.form.attach(_applied);
    unawaited(_restore());
  }

  @override
  void dispose() {
    widget.form.edits.removeListener(_edited);
    widget.form.attach(null);
    _restored.dispose();
    super.dispose();
  }

  void _edited() {
    if (_filling) return;
    ref.read(_draft.notifier).changed(widget.form.answers());
  }

  void _fill(Map<String, Object?>? answers) {
    _filling = true;
    try {
      widget.form.fill(answers);
    } finally {
      _filling = false;
    }
  }

  Future<void> _restore() async {
    final SetupStepDraft? draft;
    try {
      draft = await ref.read(_draft.notifier).load();
    } on Object catch (e, st) {
      // The stored values stay; the next save tells a conflict apart.
      TraceLogger.instance.warn(
        'workspace',
        'setup draft not read',
        error: e,
        stackTrace: st,
      );
      return;
    }
    if (draft == null || !mounted) return;
    _fill(draft.payload);
    _restored.value = true;
  }

  Future<void> _discard() async {
    _restored.value = false;
    _fill(null);
    await ref.read(_draft.notifier).discard();
  }

  /// After a conflict: the other configurer's answers, or the stored
  /// values when they discarded the draft.
  void _reload(SetupStepDraft? theirs) {
    _fill(theirs?.payload);
    _restored.value = theirs != null;
    ref.read(_draft.notifier).reloaded();
  }

  /// Applied by the page's own save: the answers are configuration now.
  Future<void> _applied() async {
    if (!mounted) return;
    _restored.value = false;
    await ref.read(_draft.notifier).discard();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SetupDraftBar(
        draft: _draft,
        restored: _restored,
        onDiscard: _discard,
        onReload: _reload,
      ),
      widget.child,
    ],
  );
}
