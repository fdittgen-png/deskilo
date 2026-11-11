// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/files/file_names.dart';
import '../../../core/i18n/money_format.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../auth/providers/auth_providers.dart';
import '../domain/archive_bundle.dart' show textBytes;
import '../domain/bank/bank_records.dart' show bankStatementReaders;
import '../domain/bank/reconciliation_report.dart';
import '../providers/bank_statement_providers.dart';
import 'bank_reconciliation_pdf.dart';
import 'bank_reconciliation_words.dart';
import 'invoice_documents.dart';
import 'report_layout_actions.dart';

/// Archive members for statements whose recorded movement-date span overlaps
/// the year. This does not establish coverage of the year or a bank balance.
/// The caller checks the bank feature and reader permission; each server and
/// storage read also enforces its own authorization. Errors abort the archive.
class BankReconciliationArchive {
  const BankReconciliationArchive(this.context, this.ref);
  final BuildContext context;
  final WidgetRef ref;

  Future<Map<String, List<int>>> _members({
    required String workspaceId,
    required int year,
  }) async {
    final l10n = context.l10n;
    final title = l10n.bankReconTitle;
    final coverageNotice =
        [l10n.bankReconCoverage, l10n.bankReconBooksUnavailable, l10n.bankReconClearingUnavailable].join('\n');
    final words = bankReconciliationWordsOf(l10n);
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
    final limits = ref.read(bankImportSettingsProvider).limits;
    final reports = await reader.readYear(
      workspaceId: workspaceId,
      year: year,
      sourceLimits: limits,
    );
    if (!context.mounted) {
      throw StateError('report context no longer available');
    }
    if (!sameScope()) throw StateError('workspace or account changed');
    final files = <String, List<int>>{
      'bank-reconciliation/coverage.txt': textBytes(coverageNotice),
    };
    for (final report in reports) {
      final statement = report.statement;
      if (!context.mounted) {
        throw StateError('report context no longer available');
      }
      final workspaceState = ref.read(currentWorkspaceProvider);
      final workspace = workspaceState.value;
      if (!sameScope() || workspace == null) {
        throw StateError('workspace changed while building bank report');
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
      final pdf = await BankReconciliationPdf(context, ref).build(
        report: rendered,
        title: title,
        layoutXml: letterLayoutXml(ref, docId: 'bank_reconciliation'),
        data: data,
        mandatoryNotices: notices,
      );
      if (!context.mounted) {
        throw StateError('report context no longer available');
      }
      if (!sameScope()) {
        throw StateError('workspace changed while rendering bank report');
      }
      if (pdf.bytes.isEmpty) throw StateError('bank report did not render');
      final path = 'bank-reconciliation/${safeFileSlug(statement.id)}.pdf';
      if (files.containsKey(path)) {
        throw StateError('bank report name collision');
      }
      files[path] = pdf.bytes;
    }
    return files;
  }

  /// The same gate as the bank statements entry; the server rechecks reads.
  @visibleForTesting
  static bool mayIncludeBankReconciliation({
    required bool featureOn,
    required bool owner,
    required Set<String> permissions,
  }) =>
      featureOn &&
      (owner || permissions.intersection(bankStatementReaders).isNotEmpty);

  /// Includes bank reports only for existing bank readers and the bank feature.
  /// The server independently checks every bank and original-file read.
  Future<Map<String, List<int>>> build({
    required String workspaceId,
    required int year,
  }) async {
    final l10n = context.l10n;
    final member = ref.read(myMemberProvider).value;
    final held = {for (final p in ref.read(myPermissionsProvider)) p.wireName};
    final mayRead = mayIncludeBankReconciliation(
      featureOn: ref
          .read(enabledFeaturesSyncProvider)
          .contains(WorkspaceFeature.bankImport),
      owner: member?.isOwner ?? false,
      permissions: held,
    );
    if (!mayRead) {
      return {
        'bank-reconciliation/coverage.txt': textBytes(
          l10n.bankReconNotIncluded,
        ),
      };
    }
    return _members(workspaceId: workspaceId, year: year);
  }
}
