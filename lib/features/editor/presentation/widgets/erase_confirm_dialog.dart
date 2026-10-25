// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';

/// Asks whether to delete the selected element, saying [text]; true only
/// when the member confirms.
Future<bool> confirmElementErase(BuildContext context, String text) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.commonDelete),
      content: Text(text),
      actions: [
        TextButton(
          key: const ValueKey('level-canvas-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('level-canvas-delete'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.commonDelete),
        ),
      ],
    ),
  );
  return confirmed == true;
}
