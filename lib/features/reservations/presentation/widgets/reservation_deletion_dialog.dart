// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';

/// #492 — the request dialog: explains that an owner/admin validates
/// (forgotten check-in vs unused booking) and takes an optional reason.
/// The reason when the person submits, null when they cancel. It files
/// nothing: the caller does, on the context the booking was shown in (#4157).
Future<String?> askDeletionReason(BuildContext context) async {
  final l10n = context.l10n;
  // Not disposed here: the dialog is still animating out when this returns.
  final reasonController = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: Text(l10n.reservationDeleteRequestButton),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.reservationDeleteRequestExplain),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('reservation-delete-reason'),
            controller: reasonController,
            maxLength: 300,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: l10n.reservationDeleteReasonLabel,
              counterText: '',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('reservation-detail-sheet-cancel'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('reservation-delete-submit'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.reservationDeleteSubmit),
        ),
      ],
    ),
  );
  return confirmed == true ? reasonController.text : null;
}
