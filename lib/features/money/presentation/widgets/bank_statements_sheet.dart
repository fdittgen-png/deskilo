// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2380 — the bank statements of the space: every imported file with its
// account, period and what is still waiting for a person, the door to
// import another, and to the movements of each.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../core/ui/loading_view.dart';
import '../../domain/bank/bank_records.dart';
import '../../providers/bank_statement_providers.dart';
import '../bank_labels.dart';
import '../invoice_actions.dart' show savePdfToDownloads;
import 'bank_import_flow.dart';
import 'bank_lines_sheet.dart';

/// The door to the bank statements, for those who match payments.
class BankStatementsButton extends StatelessWidget {
  const BankStatementsButton({
    required this.workspaceId,
    required this.currency,
    required this.canMatch,
    required this.canReconcile,
    super.key,
  });

  final String workspaceId;

  /// The space's currency: a spreadsheet's default.
  final String currency;

  /// Imports and matches money in (issueInvoices).
  final bool canMatch;

  /// Reconciles money out (recordOutgoingPayments).
  final bool canReconcile;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const ValueKey('bank-statements-button'),
    onPressed: () => showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BankStatementsView(
        workspaceId: workspaceId,
        currency: currency,
        canMatch: canMatch,
        canReconcile: canReconcile,
      ),
    ),
    icon: const Icon(Icons.account_balance_outlined),
    label: Text(context.l10n.bankStatementsTitle),
  );
}

@visibleForTesting
class BankStatementsView extends ConsumerWidget {
  const BankStatementsView({
    required this.workspaceId,
    required this.currency,
    required this.canMatch,
    required this.canReconcile,
    super.key,
  });

  final String workspaceId;
  final String currency;
  final bool canMatch;
  final bool canReconcile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final statements = ref.watch(bankStatementsProvider(workspaceId));
    final day = DateFormat.yMMMd(Localizations.localeOf(context).toString());
    return SheetShell(
      title: l10n.bankStatementsTitle,
      children: [
        Text(l10n.bankStatementsIntro, style: Theme.of(context).textTheme.bodySmall),
        const FormGap(),
        if (canMatch) FilledButton.icon(
          key: const ValueKey('bank-import'),
          onPressed: () => BankImportFlow(
            ref,
            workspaceId: workspaceId,
            currency: currency,
          ).run(context),
          icon: const Icon(Icons.upload_file_outlined),
          label: Text(l10n.bankImportAction),
        ),
        const FormGap(),
        statements.when(
          loading: () => const LoadingView(),
          error: (_, _) => Text(
            l10n.bankStatementsLoadFailed,
            key: const ValueKey('bank-statements-failed'),
          ),
          data: (all) => all.isEmpty
              ? Text(l10n.bankStatementsEmpty, key: const ValueKey('bank-statements-empty'))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final s in all)
                      ListTile(
                        key: ValueKey('bank-statement-${s.id}'),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.receipt_long_outlined),
                        title: Text(
                          l10n.bankStatementPeriod(
                            s.account,
                            day.format(s.from),
                            day.format(s.to),
                          ),
                        ),
                        subtitle: Text(
                          '${bankFormatLabel(l10n, s.format)} · '
                          '${l10n.bankStatementCounts(s.lineCount, s.openCount)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // #2380 — the file as it was imported.
                            if (s.sourceSha256.isNotEmpty)
                              IconButton(
                                key: ValueKey('bank-statement-original-${s.id}'),
                                tooltip: l10n.bankStatementOriginal,
                                icon: const Icon(Icons.download_outlined),
                                onPressed: () => _original(context, ref, s),
                              ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () => _open(context, s),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _original(
    BuildContext context,
    WidgetRef ref,
    StoredBankStatement s,
  ) async {
    final bytes =
        await ref.read(bankImportCommandsProvider).original(workspaceId, s);
    if (!context.mounted) return;
    await savePdfToDownloads(
      context,
      ref,
      bytes: bytes,
      fileName: s.fileName.isEmpty ? s.sourceSha256 : s.fileName,
    );
  }

  void _open(BuildContext context, StoredBankStatement s) => showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => BankLinesView(
      workspaceId: workspaceId,
      statement: s,
      canMatch: canMatch,
      canReconcile: canReconcile,
    ),
  );
}
