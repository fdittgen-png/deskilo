// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4496 -- Master data › Bank accounts: the accounts bank statements are imported into, each opened to edit it, a new one
// added, an account no longer used archived. Below them, the names earlier statements were imported under that no
// account carries yet: each is added to the names of its account, and its statements are then of that account.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/bank/bank_account.dart';
import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/adaptive/page_measures.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../domain/book_chart.dart';
import '../../providers/bank_statement_providers.dart';
import '../../providers/book_profile_providers.dart';
import '../bank_account_words.dart';
import '../widgets/bank_account_sheet.dart';

class BankAccountsScreen extends ConsumerWidget {
  const BankAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspace = ref.watch(currentWorkspaceProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(l10n.bankAccountsTitle),
        actions: [HelpDot(l10n.bankAccountsTitle, anchor: HelpAnchor.moneyBankAccounts)],
      ),
      floatingActionButton: workspace == null
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('bank-account-add'),
              onPressed: () => _Editor.open(context, ref, workspace.id, workspace.currencyCode, null),
              icon: const Icon(Icons.add),
              label: Text(l10n.bankAccountAdd),
            ),
      body: workspace == null
          ? const SizedBox.shrink()
          : SingleChildScrollView(
              padding: AppSpacing.gutterAll,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: kFormColumnWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l10n.bankAccountsSubtitle),
                      const FormGap(),
                      AsyncReadBody<List<BankAccount>>.part(
                        value: ref.watch(bankAccountsProvider(workspace.id)),
                        onRetry: () => ref.invalidate(bankAccountsProvider(workspace.id)),
                        data: (accounts) =>
                            _Accounts(workspaceId: workspace.id, currency: workspace.currencyCode, accounts: accounts),
                      ),
                      const FormGap.large(),
                      AsyncReadBody<List<UnattachedBankName>>.part(
                        value: ref.watch(unattachedBankNamesProvider(workspace.id)),
                        onRetry: () => ref.invalidate(unattachedBankNamesProvider(workspace.id)),
                        data: (names) => names.isEmpty
                            ? const SizedBox.shrink()
                            : _Unattached(workspaceId: workspace.id, names: names),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

/// The posting asset accounts of the business's book, when it keeps one: what an account books to.
List<BookAccount> _ledgerOf(WidgetRef ref) => [
  for (final a
      in ref.read(bookChartProvider).value?.accounts ??
          const <BookAccount>[]) // empty-ok: no book, no ledger account to pick
    if (a.type == AccountType.asset && a.isPosting) a,
];

/// The editor of an account, opened from the page.
abstract final class _Editor {
  static Future<void> open(
    BuildContext context,
    WidgetRef ref,
    String workspaceId,
    String currency,
    BankAccount? account,
  ) async {
    final l10n = context.l10n;
    final commands = ref.read(bankAccountCommandsProvider);
    final attached = await showBankAccountSheet(
      context,
      account: account,
      currency: currency,
      ledger: _ledgerOf(ref),
      save: (a) => commands.save(workspaceId, a),
    );
    if (attached == null) return;
    ref
      ..invalidate(bankAccountsProvider(workspaceId))
      ..invalidate(unattachedBankNamesProvider(workspaceId))
      ..invalidate(bankStatementsProvider(workspaceId));
    if (context.mounted) AppSnack.success(context, l10n.bankAccountSaved(attached));
  }
}

class _Accounts extends ConsumerWidget {
  const _Accounts({required this.workspaceId, required this.currency, required this.accounts});

  final String workspaceId;
  final String currency;
  final List<BankAccount> accounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (accounts.isEmpty) return Text(l10n.bankAccountsNone, key: const ValueKey('bank-accounts-none'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final a in accounts)
          Card(
            key: ValueKey('bank-account-${a.id}'),
            child: ListTile(
              key: ValueKey('bank-account-open-${a.id}'),
              leading: const Icon(Icons.account_balance_outlined),
              title: Text(a.name),
              subtitle: Text(
                [if (a.iban.isNotEmpty) a.iban, a.currency, if (a.archived) l10n.bankAccountArchived].join(' · '),
              ),
              onTap: a.archived ? null : () => _Editor.open(context, ref, workspaceId, currency, a),
              trailing: a.archived
                  ? null
                  : IconButton(
                      key: ValueKey('bank-account-archive-${a.id}'),
                      tooltip: l10n.bankAccountArchive,
                      icon: const Icon(Icons.archive_outlined),
                      onPressed: () async {
                        await ref.read(bankAccountCommandsProvider).archive(workspaceId, a.id);
                        ref.invalidate(bankAccountsProvider(workspaceId));
                      },
                    ),
            ),
          ),
      ],
    );
  }
}

class _Unattached extends ConsumerWidget {
  const _Unattached({required this.workspaceId, required this.names});

  final String workspaceId;
  final List<UnattachedBankName> names;

  /// Adds [name] to the names of the account the person picks: its statements are then of that account.
  Future<void> _assign(BuildContext context, WidgetRef ref, UnattachedBankName name) async {
    final accounts = [
      for (final a in await ref.read(bankAccountsProvider(workspaceId).future))
        if (!a.archived && a.currency == name.currency) a,
    ];
    if (!context.mounted) return;
    if (accounts.isEmpty) {
      AppSnack.error(context, context.l10n.bankImportNeedsAccount);
      return;
    }
    final account = await showDialog<BankAccount>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.l10n.bankUnattachedAssign),
        children: [
          for (final a in accounts)
            SimpleDialogOption(
              key: ValueKey('bank-unattached-to-${a.id}'),
              onPressed: () => Navigator.of(context).pop(a),
              child: Text(a.name),
            ),
        ],
      ),
    );
    if (account == null || !context.mounted) return;
    // the account, known by one more name
    try {
      final attached = await ref.read(bankAccountCommandsProvider).addName(workspaceId, account, name.name);
      ref
        ..invalidate(bankAccountsProvider(workspaceId))
        ..invalidate(unattachedBankNamesProvider(workspaceId))
        ..invalidate(bankStatementsProvider(workspaceId));
      if (context.mounted) AppSnack.success(context, context.l10n.bankAccountSaved(attached));
    } on BankAccountRefused catch (e, st) {
      TraceLogger.instance.log(
        TraceLevel.info,
        'money',
        'a bank import name not added to an account',
        error: e,
        stackTrace: st,
      );
      if (context.mounted) AppSnack.error(context, bankAccountRefusalText(context.l10n, e, account: account));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('bank-unattached'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.bankUnattachedTitle, style: theme.textTheme.titleMedium),
        Text(l10n.bankUnattachedHint, style: theme.textTheme.bodySmall),
        const FormGap.small(),
        for (final n in names)
          ListTile(
            key: ValueKey('bank-unattached-${n.name}'),
            title: Text(l10n.bankUnattachedRow(n.name, n.currency, n.statements)),
            trailing: TextButton(
              key: ValueKey('bank-unattached-assign-${n.name}'),
              onPressed: () => _assign(context, ref, n),
              child: Text(l10n.bankUnattachedAssign),
            ),
          ),
      ],
    );
  }
}
