// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/trace/guarded.dart';
import '../../domain/bank/reconciliation_report.dart';
import '../bank_reconciliation_actions.dart';

/// A read-only report for a statement the caller may already read.
class BankReconciliationButton extends ConsumerWidget {
  const BankReconciliationButton({
    required this.workspaceId,
    required this.statementId,
    required this.title,
    required this.errorText,
    required this.words,
    super.key,
  });

  final String workspaceId;
  final String statementId;
  final String title;
  final String errorText;
  final BankReconciliationWords words;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OutlinedButton.icon(
    key: const ValueKey('bank-reconciliation-report'),
    icon: const Icon(Icons.description_outlined),
    label: Text(title),
    onPressed: () => runGuarded(
      context,
      domain: 'money',
      message: 'bank reconciliation report failed',
      errorText: errorText,
      action: () => BankReconciliationActions(context, ref).show(
        workspaceId: workspaceId,
        statementId: statementId,
        title: title,
        words: words,
      ),
    ),
  );
}
