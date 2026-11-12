// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-f — the reminder letter of a queue line on screen, laid out as the
// PDF will be, with Share in its bar (moved out of reminder_queue_screen.dart
// for #3673).
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/kit/bottom_action_bar.dart';
import '../../domain/invoice_report.dart';
import '../widgets/report_page_style.dart';
import '../widgets/report_preview.dart';

/// The reminder letter, laid out as the PDF will be, with Share in the bar.
class ReminderLetterPreviewPage extends StatelessWidget {
  const ReminderLetterPreviewPage({
    super.key,
    required this.title,
    required this.report,
    required this.images,
    required this.canShare,
  });

  final String title;
  final InvoiceReport report;
  final Map<String, Uint8List> images;

  /// False once the letter left: the preview is for reading only.
  final bool canShare;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: AppSpacing.mdAll,
              child: FittedBox(
                fit: BoxFit.fitWidth,
                child: Container(
                  width: ReportPage.width,
                  color: ReportPage.paper,
                  padding: ReportPage.margins,
                  child: ReportBlocksView(report: report, images: images),
                ),
              ),
            ),
          ),
          if (canShare)
            BottomActionBar(
              actions: [
                FilledButton(
                  key: const ValueKey('reminder-queue-preview-share'),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.reminderQueueShare),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
