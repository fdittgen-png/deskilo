// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/site.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/book_chart.dart';
import '../../domain/book_profile.dart';
import '../../application/save_book_profile.dart';
import '../../providers/book_profile_providers.dart';
import 'book_chart_sheet.dart';

String bookAuthorityLabel(AppLocalizations? l10n, BookAuthority a) =>
    switch (a) {
      BookAuthority.preAccounting => l10n?.bookAuthorityPre ?? 'Pre-accounting',
      BookAuthority.localBook =>
        l10n?.bookAuthorityLocal ?? 'DesKilo is the book',
      BookAuthority.externalBook =>
        l10n?.bookAuthorityExternal ?? 'External system',
    };

String bookProblemLabel(AppLocalizations? l10n, BookProfileProblem p) =>
    switch (p) {
      BookProfileProblem.externalSystemMissing =>
        l10n?.bookProblemExternal ??
            'Name the external system that keeps the official books.',
      BookProfileProblem.unsupportedCurrency =>
        l10n?.bookProblemCurrency ??
            'This currency has no reviewed number of decimals.',
      BookProfileProblem.invalidFiscalStart =>
        l10n?.bookProblemFiscal ??
            'A fiscal year starts on a day every year has (never 29 February).',
    };

/// #1869 — set who keeps the official books of one issuer: preview the
/// fiscal year the choice gives, then save it as a version from a date.
/// True when something was saved.
Future<bool> showBookProfileSheet(
  BuildContext context, {
  BookProfile? editing,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _BookProfileSheet(editing: editing),
  );
  return saved ?? false;
}

class _BookProfileSheet extends ConsumerStatefulWidget {
  const _BookProfileSheet({this.editing});

  final BookProfile? editing;

  @override
  ConsumerState<_BookProfileSheet> createState() => _BookProfileSheetState();
}

class _BookProfileSheetState extends ConsumerState<_BookProfileSheet> {
  String? _issuer;
  var _authority = BookAuthority.preAccounting;
  final _external = TextEditingController();
  final _currency = TextEditingController();
  var _month = 1;
  var _day = 1;
  var _basis = AccountingBasis.accrual;
  DateTime? _from;
  var _saving = false;
  List<BookMapping> _mappings = const [];

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _issuer = e.issuerSiteId;
      _authority = e.authority;
      _external.text = e.externalSystem;
      _currency.text = e.functionalCurrency;
      _month = e.fiscalYearStartMonth;
      _day = e.fiscalYearStartDay;
      _basis = e.basis;
      _from = e.effectiveFrom;
    }
  }

  @override
  void dispose() {
    _external.dispose();
    _currency.dispose();
    super.dispose();
  }

  BookProfile? _draft(String workspaceId, String currency, DateTime today) {
    final issuer = _issuer;
    if (issuer == null) return null;
    return BookProfile(
      id: widget.editing?.id ?? '',
      workspaceId: workspaceId,
      issuerSiteId: issuer,
      authority: _authority,
      externalSystem: _external.text,
      functionalCurrency: (_currency.text.isEmpty ? currency : _currency.text)
          .toUpperCase(),
      fiscalYearStartMonth: _month,
      fiscalYearStartDay: _day,
      basis: _basis,
      effectiveFrom: _from ?? today,
      revision: widget.editing?.revision ?? 0,
    );
  }

  Future<void> _save(BookProfile draft) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    var outcome = BookSaveOutcome.invalid;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'save book profile failed',
      errorText:
          l10n?.bookSaveFailed ??
          'The book was not saved. Check the connection and try again.',
      action: () async => outcome = await ref
          .read(bookProfileCommandsProvider)
          .save(draft, mappings: _mappings),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (outcome == BookSaveOutcome.stale) {
      AppSnack.info(
        context,
        l10n?.bookStale ??
            'Someone saved this book since you opened it. Close and reopen '
                'to see their version.',
      );
      return;
    }
    if (!ok || outcome != BookSaveOutcome.saved) return;
    ref.invalidate(bookProfilesProvider);
    AppSnack.success(context, l10n?.bookSaved ?? 'Book saved');
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final sites = ref.watch(sitesProvider).value ?? const <Site>[];
    final today = ref.watch(clockProvider).now();
    if (workspace == null) return const SizedBox.shrink();
    final draft = _draft(workspace.id, workspace.currencyCode, today);
    final problems = draft == null
        ? const <BookProfileProblem>[]
        : validateBookProfile(draft);
    _mappings = ref.watch(bookChartProvider).value?.mappings ?? const [];
    // #1869 B — a local book waits for its required roles to be mapped.
    final unmapped = draft == null || draft.authority != BookAuthority.localBook
        ? const <BookRole>[]
        : missingForLocalBook(
            _mappings,
            draft.issuerSiteId,
            draft.effectiveFrom,
          );
    final dates = DateFormat.yMMMd(locale);
    final year = draft == null || problems.isNotEmpty
        ? null
        : fiscalYearOf(draft, draft.effectiveFrom);
    final yearText = year == null
        ? null
        : (l10n?.bookFiscalPreview(
                year.label,
                dates.format(year.start),
                dates.format(year.end),
              ) ??
              'Fiscal year ${year.label}: ${dates.format(year.start)} – '
                  '${dates.format(year.end)}');
    final fromText =
        l10n?.bookEffectiveFrom(dates.format(draft?.effectiveFrom ?? today)) ??
        'Takes effect from ${dates.format(draft?.effectiveFrom ?? today)}';
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
              l10n?.bookSheetTitle ?? 'Accounting book',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              key: const ValueKey('book-issuer'),
              initialValue: _issuer,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n?.bookIssuer ?? 'Issuer',
              ),
              items: [
                for (final s in sites)
                  DropdownMenuItem(
                    value: s.id,
                    // Two issuers may share a name; the registration
                    // tells them apart.
                    child: Text(
                      s.legalId.isEmpty ? s.name : '${s.name} · ${s.legalId}',
                    ),
                  ),
              ],
              onChanged: widget.editing == null
                  ? (v) => setState(() => _issuer = v)
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            RadioGroup<BookAuthority>(
              key: const ValueKey('book-profile-sheet-radio-group'),
              groupValue: _authority,
              onChanged: (v) => setState(() => _authority = v!),
              child: Column(
                children: [
                  for (final a in BookAuthority.values)
                    RadioListTile<BookAuthority>(
                      key: ValueKey('book-authority-${a.wire}'),
                      contentPadding: EdgeInsets.zero,
                      value: a,
                      title: Text(bookAuthorityLabel(l10n, a)),
                    ),
                ],
              ),
            ),
            if (_authority == BookAuthority.externalBook)
              TextField(
                key: const ValueKey('book-external'),
                controller: _external,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n?.bookExternalSystem ?? 'Authoritative system',
                ),
              ),
            TextField(
              key: const ValueKey('book-currency'),
              controller: _currency,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n?.bookCurrency ?? 'Functional currency',
                hintText: workspace.currencyCode,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n?.bookFiscalStart ?? 'Fiscal year starts on'),
            Row(
              children: [
                Expanded(
                  child: DropdownButton<int>(
                    key: const ValueKey('book-fiscal-day'),
                    isExpanded: true,
                    value: _day,
                    items: [
                      for (var d = 1; d <= 31; d++)
                        DropdownMenuItem(value: d, child: Text('$d')),
                    ],
                    onChanged: (v) => setState(() => _day = v!),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: DropdownButton<int>(
                    key: const ValueKey('book-fiscal-month'),
                    isExpanded: true,
                    value: _month,
                    items: [
                      for (var m = 1; m <= 12; m++)
                        DropdownMenuItem(
                          value: m,
                          child: Text(
                            DateFormat.MMMM(locale).format(DateTime(2026, m)),
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _month = v!),
                  ),
                ),
              ],
            ),
            SegmentedButton<AccountingBasis>(
              key: const ValueKey('book-basis'),
              segments: [
                ButtonSegment(
                  value: AccountingBasis.accrual,
                  label: Text(l10n?.bookBasisAccrual ?? 'Accrual basis'),
                ),
                ButtonSegment(
                  value: AccountingBasis.cash,
                  label: Text(l10n?.bookBasisCash ?? 'Cash basis'),
                ),
              ],
              selected: {_basis},
              onSelectionChanged: (v) => setState(() => _basis = v.first),
            ),
            ListTile(
              key: const ValueKey('book-from'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(fromText),
              onTap: widget.editing != null
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _from ?? today,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _from = picked);
                    },
            ),
            if (yearText != null)
              Text(yearText, key: const ValueKey('book-preview')),
            for (final p in problems)
              Text(
                bookProblemLabel(l10n, p),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (unmapped.isNotEmpty)
              Text(
                l10n?.bookProblemUnmapped(
                      unmapped.map((r) => bookRoleLabel(l10n, r)).join(', '),
                    ) ??
                    'Map these accounts before a local book starts: '
                        '${unmapped.map((r) => bookRoleLabel(l10n, r)).join(', ')}.',
                key: const ValueKey('book-unmapped'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const ValueKey('book-save'),
              onPressed:
                  draft == null ||
                      problems.isNotEmpty ||
                      unmapped.isNotEmpty ||
                      _saving
                  ? null
                  : () => _save(draft),
              child: Text(l10n?.commonSave ?? 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}

/// #1869 — the books on the legal-identity screen: each saved version
/// (issuer, authority, fiscal year, from when), one tap to correct it,
/// and a new version. With no profile, the sentence says what DesKilo
/// then is: pre-accounting.
class BookProfileSection extends ConsumerWidget {
  const BookProfileSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final profiles = ref.watch(bookProfilesProvider).value ?? const [];
    final sites = {
      for (final s in ref.watch(sitesProvider).value ?? const <Site>[]) s.id: s,
    };
    final dates = DateFormat.yMMMd(locale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: const ValueKey('legal-identity-book'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.menu_book_outlined),
          title: Text(l10n?.bookSheetTitle ?? 'Accounting book'),
          subtitle: profiles.isEmpty
              ? Text(
                  l10n?.bookTileEmpty ??
                      'No book set: DesKilo keeps member balances and invoices '
                          '(pre-accounting).',
                )
              : null,
          trailing: const Icon(Icons.add),
          onTap: () => showBookProfileSheet(context),
        ),
        for (final site in sites.values)
          ListTile(
            key: ValueKey('book-chart-${site.id}'),
            dense: true,
            contentPadding: const EdgeInsets.only(left: AppSpacing.lg),
            leading: const Icon(Icons.account_tree_outlined),
            title: Text(
              l10n?.bookChartTitle(site.name) ??
                  'Chart of accounts · ${site.name}',
            ),
            onTap: () => showBookChartSheet(context, site),
          ),
        for (final p in profiles)
          ListTile(
            key: ValueKey(
              'book-version-${p.issuerSiteId}-${p.toJson()['effective_from']}',
            ),
            dense: true,
            contentPadding: const EdgeInsets.only(left: AppSpacing.lg),
            title: Text(
              '${sites[p.issuerSiteId]?.name ?? p.issuerSiteId} · '
              '${bookAuthorityLabel(l10n, p.authority)}'
              '${p.authority == BookAuthority.externalBook ? ' (${p.externalSystem})' : ''}',
            ),
            subtitle: Text(
              '${l10n?.bookEffectiveFrom(dates.format(p.effectiveFrom)) ?? 'Takes effect from ${dates.format(p.effectiveFrom)}'}'
              ' · ${p.functionalCurrency} · '
              '${fiscalYearOf(p, p.effectiveFrom).label}',
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => showBookProfileSheet(context, editing: p),
          ),
      ],
    );
  }
}
