// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/site.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/save_book_profile.dart';
import '../../domain/book_chart.dart';
import '../../domain/vat_regime.dart';
import '../../providers/book_profile_providers.dart';

String bookRoleLabel(AppLocalizations? l10n, BookRole r) => switch (r) {
  BookRole.customers => l10n?.bookRoleCustomers ?? 'Customers (receivable)',
  BookRole.revenue => l10n?.bookRoleRevenue ?? 'Revenue',
  BookRole.bank => l10n?.bookRoleBank ?? 'Bank',
  BookRole.vatOutput => l10n?.bookRoleVatOutput ?? 'Output VAT',
  BookRole.expenses => l10n?.bookRoleExpenses ?? 'Expenses',
};

String accountTypeLabel(AppLocalizations? l10n, AccountType t) => switch (t) {
  AccountType.asset => l10n?.bookTypeAsset ?? 'Asset',
  AccountType.liability => l10n?.bookTypeLiability ?? 'Liability',
  AccountType.equity => l10n?.bookTypeEquity ?? 'Equity',
  AccountType.income => l10n?.bookTypeIncome ?? 'Income',
  AccountType.expense => l10n?.bookTypeExpense ?? 'Expense',
};

/// #1869 B — one issuer's chart of accounts and the account each posting
/// role books to. The suggested national accounts are offered as drafts
/// to save one by one; a role lists only the posting accounts of the type
/// that fits it; choosing one saves a mapping version from today.
Future<void> showBookChartSheet(BuildContext context, Site issuer) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BookChartSheet(issuer: issuer),
    );

class _BookChartSheet extends ConsumerStatefulWidget {
  const _BookChartSheet({required this.issuer});

  final Site issuer;

  @override
  ConsumerState<_BookChartSheet> createState() => _BookChartSheetState();
}

class _BookChartSheetState extends ConsumerState<_BookChartSheet> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  var _type = AccountType.asset;
  var _posting = true;
  BookAccount? _editing;
  var _busy = false;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _run(Future<BookSaveOutcome> Function() action) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    var outcome = BookSaveOutcome.invalid;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'save book chart failed',
      errorText:
          l10n?.bookSaveFailed ??
          'The book was not saved. Check the connection and try again.',
      action: () async => outcome = await action(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ref.invalidate(bookChartProvider);
    if (!ok) return;
    if (outcome == BookSaveOutcome.stale) {
      AppSnack.info(
        context,
        l10n?.bookStale ??
            'Someone saved this book since you opened it. Close and reopen '
                'to see their version.',
      );
    }
  }

  BookAccount _draft(String workspaceId) => BookAccount(
    id: _editing?.id ?? '',
    workspaceId: workspaceId,
    issuerSiteId: widget.issuer.id,
    code: _code.text.trim(),
    name: _name.text,
    type: _type,
    isPosting: _posting,
    origin: _editing?.origin ?? AccountOrigin.manual,
    revision: _editing?.revision ?? 0,
  );

  void _edit(BookAccount a) => setState(() {
    _editing = a;
    _code.text = a.code;
    _name.text = a.name;
    _type = a.type;
    _posting = a.isPosting;
  });

  void _clear() => setState(() {
    _editing = null;
    _code.clear();
    _name.clear();
    _type = AccountType.asset;
    _posting = true;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final chart = ref.watch(bookChartProvider).value;
    final today = ref.watch(clockProvider).now();
    if (workspace == null || chart == null) return const SizedBox.shrink();
    final commands = ref.read(bookProfileCommandsProvider);
    final accounts = [
      for (final a in chart.accounts)
        if (a.issuerSiteId == widget.issuer.id) a,
    ];
    final draft = _draft(workspace.id);
    final problems = validateBookAccount(draft);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n?.bookChartTitle(widget.issuer.name) ??
                  'Chart of accounts · ${widget.issuer.name}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (accounts.isEmpty)
              OutlinedButton(
                key: const ValueKey('book-chart-suggest'),
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        var last = BookSaveOutcome.saved;
                        for (final a in suggestedAccounts(
                          workspaceId: workspace.id,
                          issuerSiteId: widget.issuer.id,
                          countryCode: widget.issuer.countryCode.isEmpty
                              ? workspace.countryCode
                              : widget.issuer.countryCode,
                          regime: vatRegimeFromWire(workspace.vatRegime),
                        )) {
                          last = await commands.saveAccount(a);
                        }
                        return last;
                      }),
                child: Text(
                  l10n?.bookChartSuggest ??
                      'Add the suggested accounts to review',
                ),
              ),
            for (final a in accounts)
              ListTile(
                key: ValueKey('book-account-${a.code}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${a.code} · ${a.name}'),
                subtitle: Text(accountTypeLabel(l10n, a.type)),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _edit(a),
              ),
            const Divider(),
            TextField(
              key: const ValueKey('book-account-code'),
              controller: _code,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n?.bookAccountCode ?? 'Account code',
              ),
            ),
            TextField(
              key: const ValueKey('book-account-name'),
              controller: _name,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n?.bookAccountName ?? 'Account name',
              ),
            ),
            DropdownButton<AccountType>(
              key: const ValueKey('book-account-type'),
              isExpanded: true,
              value: _type,
              items: [
                for (final t in AccountType.values)
                  DropdownMenuItem(
                    value: t,
                    child: Text(accountTypeLabel(l10n, t)),
                  ),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
            SwitchListTile(
              key: const ValueKey('book-account-posting'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n?.bookAccountPosting ?? 'Takes postings'),
              value: _posting,
              onChanged: (v) => setState(() => _posting = v),
            ),
            FilledButton(
              key: const ValueKey('book-account-save'),
              onPressed: problems.isNotEmpty || _busy
                  ? null
                  : () async {
                      await _run(() => commands.saveAccount(draft));
                      if (mounted) _clear();
                    },
              child: Text(l10n?.commonSave ?? 'Save'),
            ),
            const Divider(),
            Text(
              l10n?.bookMappingsTitle ?? 'Which account each entry books to',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final role in BookRole.values)
              _RoleRow(
                role: role,
                accounts: [
                  for (final a in accounts)
                    if (mappingProblem(role, a, widget.issuer.id) == null) a,
                ],
                current: mappingOn(
                  chart.mappings,
                  widget.issuer.id,
                  role,
                  today,
                ),
                onChosen: _busy
                    ? null
                    : (a) => _run(
                        () => commands.saveMapping(
                          role: role,
                          account: a,
                          effectiveFrom: today,
                          current: chart.mappings,
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({
    required this.role,
    required this.accounts,
    required this.current,
    required this.onChosen,
  });

  final BookRole role;
  final List<BookAccount> accounts;
  final BookMapping? current;
  final ValueChanged<BookAccount>? onChosen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = accounts.where((a) => a.id == current?.accountId);
    return DropdownButtonFormField<String>(
      key: ValueKey('book-role-${role.wire}'),
      initialValue: selected.isEmpty ? null : selected.first.id,
      isExpanded: true,
      decoration: InputDecoration(labelText: bookRoleLabel(l10n, role)),
      items: [
        for (final a in accounts)
          DropdownMenuItem(value: a.id, child: Text('${a.code} · ${a.name}')),
      ],
      onChanged: onChosen == null
          ? null
          : (id) => onChosen!(accounts.firstWhere((a) => a.id == id)),
    );
  }
}
