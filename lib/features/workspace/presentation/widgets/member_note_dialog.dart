// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/member_note.dart';
import '../../providers/workspace_providers.dart';

/// Compose-and-send dialog for a member note (#456). [toMemberId] null =
/// broadcast to all admins incl. the owner (the server re-checks the
/// sender's admin rights). [recipientName] labels the dialog.
Future<void> showMemberNoteDialog(
  BuildContext context,
  WidgetRef ref, {
  required String? toMemberId,
  required String recipientName,
}) async {
  final l10n = AppLocalizations.of(context);
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (workspace == null) return;
  final body = await showDialog<String>(
    context: context,
    builder: (context) => _NoteDialog(recipientName: recipientName),
  );
  if (body == null || body.trim().isEmpty || !context.mounted) return;
  try {
    await ref.read(workspaceRepositoryProvider).sendMemberNote(
          workspace.id,
          toMemberId: toMemberId,
          body: body.trim(),
        );
  } catch (e, st) {
    TraceLogger.instance
        .error('workspace', 'send member note failed', error: e, stackTrace: st);
    if (!context.mounted) return;
    AppSnack.error(
      context,
      l10n?.workspaceGenericError ?? 'Something went wrong. Please try again.',
    );
    return;
  }
  if (!context.mounted) return;
  AppSnack.info(
    context,
    l10n?.memberNoteSent ?? 'Notification sent.',
    replace: true,
  );
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.recipientName});

  final String recipientName;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _body = TextEditingController();

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
        l10n?.memberNoteTitle(widget.recipientName) ??
            'Notify ${widget.recipientName}',
      ),
      content: TextField(
        key: const ValueKey('member-note-body'),
        controller: _body,
        autofocus: true,
        minLines: 2,
        maxLines: 5,
        maxLength: MemberNoteRules.maxLength,
        decoration: InputDecoration(
          labelText: l10n?.memberNoteHint ?? 'Your message',
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          key: const ValueKey('member-note-send'),
          onPressed: () => Navigator.of(context).pop(_body.text),
          child: Text(l10n?.memberNoteSend ?? 'Send'),
        ),
      ],
    );
  }
}
