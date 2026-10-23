// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup step "accounting": the legal identity screen's own books
// section — who keeps the books of each issuer, its chart of accounts, the
// versions — whose sheets save through the book profile commands
// ([BookProfiles]), and the door to the accounting periods when they are
// on. Beside it, what the books will show: for each issuer the version in
// force today (or the first one to come), who keeps the books, the fiscal
// year it gives, when income counts, the currency, and the accounts a
// local book still waits for. With no version the answer is
// pre-accounting, as the server reads it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/ui/setup_step_layout.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/book_chart.dart';
import '../../domain/book_profile.dart';
import '../../providers/book_profile_providers.dart';
import 'book_chart_sheet.dart';
import 'book_periods_sheet.dart';
import 'book_profile_sheet.dart';

class SetupAccountingStep extends ConsumerWidget {
  const SetupAccountingStep({
    super.key,
    required this.workspaceId,
    required this.sites,
    required this.periodsOn,
    required this.isOwner,
  });

  final String workspaceId;

  /// Site id → name, for naming each issuer in the preview.
  final Map<String, String> sites;

  /// Whether the accounting periods are on, and so offered here.
  final bool periodsOn;

  /// Whether the reader owns the space (closing a period is theirs).
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(bookProfilesProvider)) {
        AsyncValue(hasValue: true, :final value) => SetupStepLayout(
          form: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.l10n.setupStepHint('accounting')),
              const FormGap.large(),
              const BookProfileSection(),
              if (periodsOn) ...[
                const FormGap(),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: BookPeriodsButton(
                    workspaceId: workspaceId,
                    isOwner: isOwner,
                  ),
                ),
              ],
            ],
          ),
          preview: _BooksPreview(
            profiles: value ?? const [],
            mappings: ref.watch(bookChartProvider).value?.mappings ?? const [],
            sites: sites,
          ),
        ),
        AsyncError() => Padding(
          padding: AppSpacing.lgAll,
          child: InlineBanner(
            key: const ValueKey('setup-accounting-failed'),
            icon: Icons.error_outline,
            text: context.l10n.setupStepLoadFailed,
          ),
        ),
        _ => const LoadingView(),
      };
}

/// Who keeps the books, in one sentence.
String _authorityText(AppLocalizations l10n, BookProfile p) =>
    switch (p.authority) {
      BookAuthority.preAccounting => l10n.setupGrowBooksPre,
      BookAuthority.localBook => l10n.setupGrowBooksLocal,
      BookAuthority.externalBook => l10n.setupGrowBooksExternal(
        p.externalSystem,
      ),
    };

class _BooksPreview extends ConsumerWidget {
  const _BooksPreview({
    required this.profiles,
    required this.mappings,
    required this.sites,
  });

  final List<BookProfile> profiles;
  final List<BookMapping> mappings;
  final Map<String, String> sites;

  /// The version of [issuer] in force on [today], else its first one to come.
  BookProfile _versionOf(String issuer, DateTime today) =>
      profileOn(profiles, issuer, today) ??
      (profiles.where((p) => p.issuerSiteId == issuer).toList()
            ..sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom)))
          .first;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final today = ref.watch(clockProvider).now();
    if (profiles.isEmpty) {
      return Text(
        l10n.bookTileEmpty,
        key: const ValueKey('setup-accounting-pre'),
      );
    }
    final dates = DateFormat.yMMMd(Localizations.localeOf(context).toString());
    final issuers = {for (final p in profiles) p.issuerSiteId};
    return Column(
      key: const ValueKey('setup-accounting-preview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.setupGrowBooksPreviewNote),
        for (final issuer in issuers)
          _IssuerBooks(
            key: ValueKey('setup-accounting-issuer-$issuer'),
            name: sites[issuer] ?? issuer,
            profile: _versionOf(issuer, today),
            mappings: mappings,
            today: today,
            dates: dates,
          ),
      ],
    );
  }
}

class _IssuerBooks extends StatelessWidget {
  const _IssuerBooks({
    super.key,
    required this.name,
    required this.profile,
    required this.mappings,
    required this.today,
    required this.dates,
  });

  final String name;
  final BookProfile profile;
  final List<BookMapping> mappings;
  final DateTime today;
  final DateFormat dates;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final p = profile;
    final starts = p.effectiveFrom.isAfter(today);
    final year = fiscalYearOf(p, starts ? p.effectiveFrom : today);
    final unmapped = p.authority == BookAuthority.localBook
        ? missingForLocalBook(
            mappings,
            p.issuerSiteId,
            starts ? p.effectiveFrom : today,
          )
        : const <BookRole>[];
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(name, style: theme.textTheme.titleSmall),
          ),
          if (starts)
            Text(l10n.bookEffectiveFrom(dates.format(p.effectiveFrom))),
          Text(_authorityText(l10n, p)),
          Text(
            l10n.bookFiscalPreview(
              year.label,
              dates.format(year.start),
              dates.format(year.end),
            ),
          ),
          Text(
            p.basis == AccountingBasis.cash
                ? l10n.setupGrowBooksCash
                : l10n.setupGrowBooksAccrual,
          ),
          Text(l10n.setupGrowBooksCurrency(p.functionalCurrency)),
          if (unmapped.isNotEmpty)
            Text(
              l10n.bookProblemUnmapped(
                unmapped.map((r) => bookRoleLabel(l10n, r)).join(', '),
              ),
              key: const ValueKey('setup-accounting-unmapped'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
        ],
      ),
    );
  }
}
