// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3470 — the business's accounting journals: the code and label of its
// sales, bank, purchases and miscellaneous journals, as its accountant's
// software knows them. Every accounting export the app writes uses them.
// Each problem is said under its field by the same rules the server holds;
// a value is kept whole or not at all.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/workspace.dart';
import '../../../workspace/domain/workspace_identity_repository.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/save_accounting_journals.dart';
import '../../domain/accounting_journals.dart';
import '../../domain/fec_accounts.dart';

/// The name of a journal's role, as the form says it.
String accountingJournalRole(AppLocalizations l10n, String role) =>
    switch (role) {
      'sales' => l10n.accountingJournalSales,
      'bank' => l10n.accountingJournalBank,
      'purchases' => l10n.accountingJournalPurchases,
      _ => l10n.accountingJournalMisc,
    };

String _problemText(AppLocalizations l10n, JournalProblem p) => switch (p) {
  JournalProblem.code => l10n.accountingJournalCodeRequired,
  JournalProblem.label => l10n.accountingJournalLabelRequired,
  JournalProblem.character => l10n.accountingJournalCharacter,
  JournalProblem.duplicate => l10n.accountingJournalDuplicate,
};

/// Opens the journals of [workspaceId], filled with [current]. True once
/// they are kept.
Future<bool> showAccountingJournalsSheet(
  BuildContext context,
  WidgetRef ref, {
  required String workspaceId,
  required FecJournals current,
}) {
  final l10n = context.l10n;
  final fields = FormControllers({
    for (final (role, j) in current.byRole) ...{
      '$role.code': j.code,
      '$role.label': j.label,
    },
  });
  FecJournal journal(String role) => FecJournal(
    code: fields['$role.code'].text,
    label: fields['$role.label'].text,
  );
  FecJournals draft() => FecJournals(
    sales: journal('sales'),
    bank: journal('bank'),
    purchases: journal('purchases'),
    misc: journal('misc'),
  );
  // The field a problem is about: a code, unless the label holds it.
  String fieldOf(String role, JournalProblem p) => switch (p) {
    JournalProblem.label => '$role.label',
    JournalProblem.character when journalTextAllowed(journal(role).code) =>
      '$role.label',
    _ => '$role.code',
  };
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.accountingJournalsTitle,
      submitLabel: l10n.commonSave,
      submitKey: const ValueKey('accounting-journals-save'),
      onDispose: fields.dispose,
      validate: () => switch (journalsProblem(draft())) {
        (:final role, :final problem) => {
          fieldOf(role, problem): _problemText(l10n, problem),
        },
        null => const {},
      },
      onSubmit: () async {
        try {
          await ref
              .read(saveAccountingJournalsProvider)
              .save(workspaceId, draft());
          ref.invalidate(currentWorkspaceProvider);
          return null;
        } on AccountingJournalsRefused catch (e, st) {
          TraceLogger.instance.warn(
            'money',
            'accounting journals refused',
            error: e,
            stackTrace: st,
          );
          if (e.notAllowed) return l10n.accountingJournalsNotAllowed;
          return l10n.accountingJournalsRefused(
            accountingJournalRole(l10n, e.role),
          );
        }
      },
      builder: (context, refresh) => [
        Row(
          children: [
            Expanded(child: Text(l10n.accountingJournalsIntro)),
            HelpDot(
              l10n.accountingJournalsTitle,
              anchor: HelpAnchor.moneyAccountingJournals,
            ),
          ],
        ),
        const FormGap(),
        for (final role in FecJournals.roles) ...[
          FormSection(
            title: accountingJournalRole(l10n, role),
            children: [
              AppTextField(
                key: ValueKey('accounting-journal-$role-code'),
                controller: fields['$role.code'],
                fieldKey: '$role.code',
                label: l10n.accountingJournalCode,
                maxLength: 20,
              ),
              AppTextField(
                key: ValueKey('accounting-journal-$role-label'),
                controller: fields['$role.label'],
                fieldKey: '$role.label',
                label: l10n.accountingJournalLabel,
                maxLength: 100,
              ),
            ],
          ),
        ],
        Text(l10n.accountingJournalsDeliveries),
        const FormGap.small(),
        Text(l10n.accountingJournalsRenumber),
        const FormGap.small(),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const ValueKey('accounting-journals-standard'),
            onPressed: () {
              for (final (role, j) in FecJournals.installed().byRole) {
                fields['$role.code'].text = j.code;
                fields['$role.label'].text = j.label;
              }
              refresh();
            },
            child: Text(l10n.accountingJournalsStandard),
          ),
        ),
      ],
    ),
  );
}

/// The accounting page's door to the journals of [workspace].
class AccountingJournalsDoor extends ConsumerWidget {
  const AccountingJournalsDoor({super.key, required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    key: const ValueKey('accounting-hub-journals'),
    leading: const Icon(Icons.menu_book_outlined),
    title: Text(context.l10n.accountingJournalsTitle),
    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    onTap: () => showAccountingJournalsSheet(
      context,
      ref,
      workspaceId: workspace.id,
      current: accountingJournalsOf(workspace.accountingJournals),
    ),
  );
}
