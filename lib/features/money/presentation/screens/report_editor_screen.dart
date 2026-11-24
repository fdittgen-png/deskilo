// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/async_read_body.dart';
import '../../providers/money_providers.dart';
import '../widgets/invoice_template_sheet.dart';

/// #822 — the report editor as a ROUTE (`/report-editor`): the whole
/// screen for the designer, a persistent toolbar, a back gesture that
/// asks before dropping unsaved work. The stored template loads first;
/// the editor then owns it exactly as the sheet did.
class ReportEditorScreen extends ConsumerWidget {
  const ReportEditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final template = ref.watch(invoicePdfTemplateProvider);
    return switch (template) {
      AsyncData(:final value) => ReportTemplateEditor(
          key: const ValueKey('report-editor-page'),
          initial: value,
          asPage: true,
        ),
      AsyncError(:final error) => Scaffold(
          appBar: AppBar(),
          body: ReadFailureBanner(
            error: error,
            onRetry: () => ref.invalidate(invoicePdfTemplateProvider),
          ),
        ),
      _ => Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator()),
        ),
    };
  }
}
