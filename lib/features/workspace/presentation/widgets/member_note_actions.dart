// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/member_note.dart';
import '../../providers/workspace_providers.dart';

/// The ONE send path for member notes: every surface — the conversation
/// thread, the broadcast dialog — funnels here, so error handling,
/// snacks and cache invalidation stay identical everywhere.
/// Returns true when the note went out.
Future<bool> sendMemberNoteGuarded(
  BuildContext context,
  WidgetRef ref, {
  required String? toMemberId,
  required String body,
  bool confirmWithSnack = true,
}) async {
  final l10n = AppLocalizations.of(context);
  final workspace = ref.read(currentWorkspaceProvider).value;
  final trimmed = body.trim();
  if (workspace == null || trimmed.isEmpty) return false;
  try {
    await ref.read(workspaceRepositoryProvider).sendMemberNote(
          workspace.id,
          toMemberId: toMemberId,
          body: trimmed,
        );
  } catch (e, st) {
    TraceLogger.instance
        .error('workspace', 'send member note failed', error: e, stackTrace: st);
    if (!context.mounted) return false;
    AppSnack.error(
      context,
      l10n?.workspaceGenericError ?? 'Something went wrong. Please try again.',
    );
    return false;
  }
  ref.invalidate(myNotesProvider);
  if (!context.mounted) return true;
  if (confirmWithSnack) {
    AppSnack.info(
      context,
      l10n?.memberNoteSent ?? 'Notification sent.',
      replace: true,
    );
  }
  return true;
}

/// The ONE delete path (#523): asks for confirmation first, then
/// deletes and refreshes — the swipe, the sheet button and the
/// conversation long-press all share it.
Future<void> deleteMemberNoteGuarded(
  BuildContext context,
  WidgetRef ref,
  MemberNote note,
) async {
  final l10n = AppLocalizations.of(context);
  if (!await confirmMemberNoteDelete(context)) return;
  if (!context.mounted) return;
  try {
    await ref.read(workspaceRepositoryProvider).deleteMemberNote(note.id);
  } catch (e, st) {
    TraceLogger.instance.error('workspace', 'delete member note failed',
        error: e, stackTrace: st);
    if (!context.mounted) return;
    AppSnack.error(
      context,
      l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
    );
    ref.invalidate(myNotesProvider);
    return;
  }
  ref.invalidate(myNotesProvider);
  if (!context.mounted) return;
  AppSnack.info(
    context,
    l10n?.memberNoteDeleted ?? 'Message deleted.',
    replace: true,
  );
}

/// Deleting is destructive: every path asks first.
Future<bool> confirmMemberNoteDelete(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n?.memberNoteDelete ?? 'Delete'),
      content: Text(l10n?.memberNoteDeleteConfirm ??
          'Delete this message? This cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          key: const ValueKey('note-delete-confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n?.memberNoteDelete ?? 'Delete'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
