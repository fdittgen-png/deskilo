// SPDX-License-Identifier: 0BSD
//
// #1288 S4 — the owner's list of the questions their space asks.
//
// Everything a question needs is in the editor sheet; this is the list,
// the way in, and the save. A question is never deleted from here: 0248
// lets it be put aside, because deleting one would take the answers with
// it and somebody would find out months later.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/workspace_field.dart';
import '../../providers/workspace_fields_providers.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/question_editor_sheet.dart';

class QuestionsScreen extends ConsumerStatefulWidget {
  const QuestionsScreen({super.key});

  static const Key addKey = Key('questions-add');

  static Key rowKeyFor(String fieldKey) => ValueKey('questions-row-$fieldKey');

  @override
  ConsumerState<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends ConsumerState<QuestionsScreen> {
  bool _saving = false;

  Future<void> _edit(WorkspaceField? field) async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final locale = workspace.defaultLocale.isEmpty
        ? 'en'
        : workspace.defaultLocale;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => QuestionEditorSheet(
        initial: field,
        workspaceName: workspace.name,
        workspaceLocale: locale,
        saving: _saving,
        onSave: (draft) async {
          Navigator.of(sheetContext).pop();
          await _save(workspace.id, draft);
        },
      ),
    );
  }

  Future<void> _save(String workspaceId, WorkspaceField draft) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    final repository = ref.read(workspaceFieldsRepositoryProvider);
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'workspace question update failed',
      // Its own sentence: the server refuses a type change under
      // existing answers and a choice somebody has already made, and an
      // owner needs to know THAT rather than that something went wrong.
      //
      // It is also TRUE, which it was not until 0252. This used to be
      // two calls, and when the choices were refused the question had
      // already landed — live for members, a choice question with no
      // choices — under a message saying it had not been saved (#1532).
      errorText: l10n?.questionEditorSaveFailed ??
          'The question was not saved.',
      action: () => repository.saveField(
        workspaceId,
        draft,
        options: draft.type.isChoice ? draft.options : null,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return;
    ref.invalidate(workspaceFieldsProvider);
    AppSnack.success(context, l10n?.billingSaved ?? 'Saved.');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fields = ref.watch(workspaceFieldsProvider);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final locale = (workspace?.defaultLocale.isEmpty ?? true)
        ? 'en'
        : workspace!.defaultLocale;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.questionsTitle ?? 'Questions this space asks'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: QuestionsScreen.addKey,
        onPressed: _saving ? null : () => _edit(null),
        icon: const Icon(Icons.add),
        label: Text(l10n?.questionsAdd ?? 'Add a question'),
      ),
      body: fields.when(
        loading: () => const LoadingView(),
        // A refusal here already reached the trace and the snack through
        // runGuarded; repeating it as a screen-sized sentence adds a
        // second voice saying the same thing (#1305).
        error: (e, _) => const SizedBox.shrink(),
        data: (list) => ListView(
          padding: AppSpacing.gutterAll,
          children: [
            Text(
              l10n?.questionsSubtitle ??
                  "They appear inside personal information, under your "
                      "space's name.",
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (list.isEmpty)
              Text(
                l10n?.questionsEmpty ?? 'No questions yet.',
                style: theme.textTheme.bodyMedium,
              ),
            for (final field in list)
              ListTile(
                key: QuestionsScreen.rowKeyFor(field.key),
                contentPadding: EdgeInsets.zero,
                title: Text(field.labelIn(locale)),
                subtitle: Text(
                  [
                    questionTypeLabel(l10n, field.type),
                    if (!field.active)
                      l10n?.questionsInactive ?? 'Put aside',
                  ].join(' · '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _saving ? null : () => _edit(field),
              ),
            // Room below the last row for the floating button.
            const SizedBox(height: kFabSafeBottom),
          ],
        ),
      ),
    );
  }
}
