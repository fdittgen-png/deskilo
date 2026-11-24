// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3978 — on the assistants page, the requests an assistant left for the
// person: each one still waiting, with what it asks, the assistant that
// asked and when, and the way to its confirmation page; below, the ones
// answered in the last days with their answer. Nothing waiting and nothing
// answered: the section is not shown.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/i18n/reference_when.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/navigation/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/kit/status_chip.dart';
import '../../../../core/ui/kit/todo_row.dart';
import '../../../../core/ui/kit/two_line_row.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/action_confirmation.dart';
import '../../providers/my_confirmations_provider.dart';
import '../mcp_operation_labels.dart';

class McpMyRequestsSection extends ConsumerWidget {
  const McpMyRequestsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final read = ref.watch(myActionConfirmationsProvider);
    if (read.hasError && !read.isLoading) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: ReadFailureBanner(
          error: read.error!,
          onRetry: () => ref.invalidate(myActionConfirmationsProvider),
        ),
      );
    }
    final all = read.value ?? const <ActionConfirmation>[];
    final waiting = [
      for (final c in all)
        if (c.status.answerable) c,
    ];
    final answered = [
      for (final c in all)
        if (!c.status.answerable) c,
    ];
    if (all.isEmpty) return const SizedBox.shrink();
    final reader = appFormatOf(context);
    final title = Theme.of(context).textTheme.titleMedium;
    Future<void> open(ActionConfirmation c) async {
      await context.push(Routes.mcpConfirm(c.id));
      ref.invalidate(myActionConfirmationsProvider);
    }

    return Column(
      key: const ValueKey('mcp-requests'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (waiting.isNotEmpty) ...[
          Text(l10n.mcpRequestsWaitingTitle, style: title),
          const SizedBox(height: AppSpacing.sm),
          for (final (i, c) in waiting.indexed)
            TodoRow(
              key: ValueKey('mcp-request-waiting-${c.id}'),
              icon: Icons.pending_actions_outlined,
              title: mcpOperationLabel(l10n, c.operation),
              caption: _asked(l10n, c, reader),
              buttonLabel: l10n.mcpRequestOpen,
              buttonKey: ValueKey('mcp-request-open-${c.id}'),
              primary: i == 0,
              onPressed: () => open(c),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (answered.isNotEmpty) ...[
          Text(l10n.mcpRequestsAnsweredTitle, style: title),
          const SizedBox(height: AppSpacing.sm),
          for (final c in answered)
            TwoLineRow(
              key: ValueKey('mcp-request-answered-${c.id}'),
              title: mcpOperationLabel(l10n, c.operation),
              caption: Text(_asked(l10n, c, reader)),
              amount: '',
              onTap: null,
              trailing: _answer(l10n, c.status),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }

  /// The assistant that asked, in which workspace, and when.
  static String _asked(
    AppLocalizations l10n,
    ActionConfirmation c,
    AppFormat reader,
  ) => l10n.mcpRequestAsked(
    c.clientName,
    c.workspaceName,
    c.askedAt == null
        ? ''
        : referenceWhen(c.askedAt!, reader.locale, reader: reader),
  );

  static StatusChip _answer(AppLocalizations l10n, ConfirmationStatus s) {
    final (label, tone) = switch (s) {
      ConfirmationStatus.acknowledged ||
      ConfirmationStatus.consumed => (l10n.mcpRequestConfirmed, StatusTone.ok),
      ConfirmationStatus.declined => (
        l10n.mcpRequestRefused,
        StatusTone.neutral,
      ),
      ConfirmationStatus.expired => (
        l10n.mcpRequestExpired,
        StatusTone.neutral,
      ),
      ConfirmationStatus.revoked || ConfirmationStatus.targetChanged => (
        l10n.mcpRequestRevoked,
        StatusTone.warn,
      ),
      _ => (l10n.mcpRequestUnknown, StatusTone.warn),
    };
    return StatusChip(label: label, tone: tone);
  }
}
