// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import 'member_note_actions.dart';
import 'member_note_composer.dart';

/// The compose DIALOG (#456) — since the messaging refactor it is a
/// thin shell around the shared [MemberNoteComposer]: the broadcast to
/// all admins composes here; person-to-person messaging lives in the
/// conversation sheet. [toMemberId] null = broadcast to all admins
/// incl. the owner (the server re-checks the sender's admin rights).
Future<void> showMemberNoteDialog(
  BuildContext context,
  WidgetRef ref, {
  required String? toMemberId,
  required String recipientName,
}) async {
  final l10n = AppLocalizations.of(context);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        l10n?.memberNoteTitle(recipientName) ?? 'Notify $recipientName',
      ),
      content: MemberNoteComposer(
        onSend: (body) async {
          final sent = await sendMemberNoteGuarded(
            context,
            ref,
            toMemberId: toMemberId,
            body: body,
          );
          if (sent && dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
          }
          return sent;
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
      ],
    ),
  );
}
