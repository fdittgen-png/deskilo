// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4514 (STK-10) -- the business's cash reasons, from the Master data page: the built-in ones, named by the app, and the
// business's own, each with what it is used for (cash in, cash out, a count that differs). Who configures the tills adds
// a reason, renames its own ones, changes what a reason is used for and archives one; an archived reason is no longer
// offered and the entries recorded with it keep it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/form_choice_controls.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/till_drawer_commands.dart';
import '../../domain/cash_reason.dart';
import '../../providers/till_drawer_providers.dart';
import 'cash_reason_text.dart';
import 'drawer_text.dart';

/// The cash reasons of [workspaceId].
class CashReasonsScreen extends ConsumerWidget {
  const CashReasonsScreen({super.key, required this.workspaceId});

  final String? workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final id = workspaceId;
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(l10n.cashReasonsTitle),
        actions: [
          HelpDot(l10n.cashReasonsTitle, anchor: HelpAnchor.moneyTillDrawer),
        ],
      ),
      floatingActionButton: id == null
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('cash-reason-add'),
              onPressed: () => _edit(context, ref, id, null),
              icon: const Icon(Icons.add),
              label: Text(l10n.cashReasonsAdd),
            ),
      body: id == null
          ? const LoadingView()
          : ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, kFabSafeBottom),
        children: [
          Text(l10n.cashReasonsSubtitle),
          const FormGap(),
          AsyncReadBody.part(
            value: ref.watch(cashReasonsProvider(id)),
            isEmpty: (rows) => rows.isEmpty,
            refusal: (e) => drawerRefusalWords(l10n, e),
            retryKey: const ValueKey('cash-reasons-retry'),
            onRetry: () => ref.invalidate(cashReasonsProvider(id)),
            data: (reasons) => Column(
              children: [for (final r in reasons) _tile(context, ref, id, r)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, WidgetRef ref, String id, CashReason r) {
    final l10n = context.l10n;
    final uses = [
      for (final p in CashReasonProcess.values)
        if (r.processes.contains(p)) cashReasonProcessLabel(l10n, p),
    ].join(', ');
    return ListTile(
      key: ValueKey('cash-reason-${r.code}'),
      title: Text(
        r.archived
            ? l10n.cashReasonsArchivedName(cashReasonLabel(l10n, r))
            : cashReasonLabel(l10n, r),
      ),
      subtitle: Text(uses),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _edit(context, ref, id, r),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    String id,
    CashReason? reason,
  ) async {
    final saved = await _showCashReasonSheet(
      context,
      ref.read(tillDrawerCommandsProvider(id)),
      reason: reason,
    );
    if (saved && context.mounted) {
      AppSnack.success(context, context.l10n.cashReasonsSaved);
    }
  }
}

/// Opens the sheet for a new reason of the business's own (null [reason]) or an existing one; true when it was saved.
Future<bool> _showCashReasonSheet(
  BuildContext context,
  TillDrawerCommands commands, {
  CashReason? reason,
}) {
  final l10n = context.l10n;
  final builtin = reason?.builtin ?? false;
  final fields = FormControllers({'name': reason?.name ?? ''});
  final uses = {...?reason?.processes};
  var archived = reason?.archived ?? false;
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: reason == null ? l10n.cashReasonsAdd : l10n.cashReasonsEdit,
      submitLabel: MaterialLocalizations.of(context).saveButtonLabel,
      submitKey: const ValueKey('cash-reason-save'),
      onDispose: fields.dispose,
      validate: () => _errors(
        l10n,
        checkCashReason(
          builtin: builtin,
          name: fields.text('name'),
          processes: uses,
        ),
      ),
      onSubmit: () async {
        try {
          await commands.saveCashReason(
            code: reason?.code,
            name: fields.text('name'),
            processes: uses,
            archived: reason == null ? null : archived,
          );
          return null;
        } on Object catch (e, st) {
          TraceLogger.instance.warn(
            'money',
            'the cash reason was refused',
            error: e,
            stackTrace: st,
          );
          return drawerProblemText(l10n, e);
        }
      },
      builder: (context, refresh) => [
        if (builtin)
          Column(
            key: const ValueKey('cash-reason-builtin'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(cashReasonLabel(l10n, reason!), style: Theme.of(context).textTheme.titleMedium), Text(l10n.cashReasonsBuiltinHint)],
          )
        else
          AppTextField(
            key: const ValueKey('cash-reason-name'),
            controller: fields[CashReasonField.name.name],
            fieldKey: 'name',
            label: l10n.cashReasonsName,
            maxLength: kCashReasonNameMaxLength,
            autofocus: true,
          ),
        const FormGap(),
        Text(
          l10n.cashReasonsProcesses,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        for (final p in CashReasonProcess.values)
          AppSwitchRow(
            key: ValueKey('cash-reason-use-${p.wire}'),
            title: cashReasonProcessLabel(l10n, p),
            value: uses.contains(p),
            onChanged: (on) {
              on ? uses.add(p) : uses.remove(p);
              refresh();
            },
          ),
        Builder(
          builder: (c) {
            final error = FormErrorsScope.maybeOf(c)?.errors[CashReasonField.processes.name];
            return error == null
                ? const SizedBox.shrink()
                : Text(
                    error,
                    key: const ValueKey('cash-reason-uses-error'),
                    style: TextStyle(color: Theme.of(c).colorScheme.error),
                  );
          },
        ),
        if (reason != null) ...[
          const FormGap(),
          AppSwitchRow(
            key: const ValueKey('cash-reason-archived'),
            title: l10n.cashReasonsArchived,
            value: archived,
            onChanged: (on) {
              archived = on;
              refresh();
            },
          ),
          Text(
            l10n.cashReasonsArchivedHelp,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    ),
  );
}

Map<String, String> _errors(
  AppLocalizations l10n,
  Set<CashReasonProblem> problems,
) => {
  if (problems.contains(CashReasonProblem.nameMissing))
    CashReasonField.name.name: l10n.cashReasonsNameMissing,
  if (problems.contains(CashReasonProblem.nameTooLong))
    CashReasonField.name.name: l10n.cashReasonsNameTooLong(kCashReasonNameMaxLength),
  if (problems.contains(CashReasonProblem.processMissing))
    CashReasonField.processes.name: l10n.cashReasonsProcessMissing,
};
