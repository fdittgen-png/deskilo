// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/money_format.dart';
import '../../auth/providers/auth_providers.dart';
import '../domain/bank/reconciliation_report.dart';
import '../providers/bank_statement_providers.dart';
import 'bank_reconciliation_words.dart';
import 'invoice_documents.dart';
import 'report_actions.dart';
import 'report_layout_actions.dart';

/// Fetches again through the authorized bank read path before opening a
/// report. Workspace changes and read refusals do not become empty reports.
class BankReconciliationActions {
  const BankReconciliationActions(this.context, this.ref);
  final BuildContext context;
  final WidgetRef ref;

  Future<void> show({
    required String workspaceId,
    required String statementId,
    required String title,
    required BankReconciliationWords words,
  }) async {
    final actorState = ref.read(authStateProvider);
    if (actorState.isLoading || actorState.hasError) {
      throw StateError('account unavailable');
    }
    final actor = actorState.value;
    bool sameScope() {
      final currentActor = ref.read(authStateProvider);
      final currentWorkspace = ref.read(currentWorkspaceProvider);
      return !currentActor.isLoading &&
          !currentActor.hasError &&
          currentActor.value == actor &&
          !currentWorkspace.isLoading &&
          !currentWorkspace.hasError &&
          currentWorkspace.value?.id == workspaceId;
    }

    final reader = ref.read(bankReconciliationReaderProvider);
    final report = await reader.read(
      workspaceId: workspaceId,
      statementId: statementId,
      sourceLimits: ref.read(bankImportSettingsProvider).limits,
    );
    if (!context.mounted) return;
    final workspaceState = ref.read(currentWorkspaceProvider);
    final workspace = workspaceState.value;
    if (!sameScope() || workspace == null) {
      throw StateError('workspace changed while reading bank statement');
    }
    final locale = Localizations.localeOf(context).toString();
    final date = DateFormat.yMMMd(locale);
    final data = <String, Object?>{
      'workspace': workspace.name,
      'workspace_address': workspace.address,
      ...bankReconciliationReportData(
        report,
        words: words,
        money: (minor, currency) =>
            moneyFormat(currency, locale: locale).formatMinor(minor),
        date: date.format,
      ),
    };
    final notices = bankReconciliationNotices(words, report);
    final rendered = renderLetterDoc(
      context,
      ref,
      docId: 'bank_reconciliation',
      data: data,
    );
    await runReportActions(
      context,
      ref,
      keyPrefix: 'bank-reconciliation-report',
      render: () {
        return sameScope()
            ? withBankReconciliationNotices(rendered, notices)
            : null;
      },
      buildPdf: () {
        if (!sameScope()) {
          throw StateError('workspace changed while opening bank report');
        }
        return letterDocPdf(
          context,
          ref,
          report: rendered,
          title: title,
          layoutXml: letterLayoutXml(ref, docId: 'bank_reconciliation'),
          data: data,
          mandatoryNotices: notices,
        );
      },
    );
  }
}
