// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

class ApplicationCommentDialog extends StatefulWidget {
  const ApplicationCommentDialog({super.key});
  @override
  State<ApplicationCommentDialog> createState() => _CommentState();
}

class _CommentState extends State<ApplicationCommentDialog> {
  final _comment = TextEditingController();
  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      scrollable: true,
      title: Text(l10n?.memberRejectJoin ?? 'Reject membership'),
      content: TextField(
        controller: _comment,
        maxLength: 4000,
        minLines: 2,
        maxLines: 5,
        key: const ValueKey('application-decision-comment'),
        decoration: InputDecoration(
          labelText:
              l10n?.applicationDecisionComment ??
              'Comment visible to the applicant',
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('application-comment-dialog-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          key: const ValueKey('application-comment-dialog-member-reject-join'),
          onPressed: () => Navigator.of(context).pop(_comment.text.trim()),
          child: Text(l10n?.memberRejectJoin ?? 'Reject membership'),
        ),
      ],
    );
  }
}
