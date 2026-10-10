// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1247 — one place that answers *does anything need me?*
//
// `docs/ux/DECISION_SURFACE.md` is the design pass this implements. Its
// rule decides what may appear:
//
//   A line appears here only when a person must decide or act. A number
//   nobody can act on is information, and information belongs to the
//   screen that owns it.
//
// So there is no occupancy here, no balance, no unread count. Eight
// signals went in and four stayed out, and that ratio is the design: a
// surface that ranks everything ranks nothing.
//
// **It sits beside the alerts face rather than replacing it.** The
// document asks the product whether replacing is right — two places
// that rank the same requests will disagree the week somebody adds a
// row to one of them — and says it is a decision to take deliberately
// rather than by implication. Behind a Platform flag that is OFF by
// default, nothing changes for anybody until an owner asks for it, and
// the question stays open.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/attention.dart';
import '../../providers/attention_providers.dart';
import '../widgets/local_setup_views.dart' show eventTypeWord;

class AttentionScreen extends ConsumerWidget {
  const AttentionScreen({super.key});

  static const emptyKey = Key('attention-empty');
  static const listKey = Key('attention-list');

  static Key rowKeyFor(int index) => ValueKey('attention-row-$index');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final items = ref.watch(attentionProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.featureDecisionSurfaceTitle ?? 'What needs you'),
      ),
      body: items.when(
        loading: () => const LoadingView(),
        // A refusal already reached the trace; a screen-sized sentence
        // here would be a second voice saying the same thing.
        error: (e, _) => const SizedBox.shrink(),
        data: (list) => list.isEmpty
            // The empty state is an ANSWER, not an absence: it says
            // nothing needs you and gets out of the way, rather than
            // leaving an empty list to interpret.
            ? EmptyState(
                key: emptyKey,
                icon: Icons.check_circle_outline,
                title: l10n?.decisionSurfaceEmpty ?? 'Nothing needs you',
                subtitle:
                    l10n?.decisionSurfaceEmptyDetail ?? 'Everything is answered.',
              )
            : ListView.builder(
                key: listKey,
                padding: AppSpacing.gutterAll,
                itemCount: list.length,
                itemBuilder: (context, index) => _Row(
                  key: rowKeyFor(index),
                  item: list[index],
                ),
              ),
      ),
    );
  }
}

/// One line: the decision as a sentence in the reader's language, and
/// since when (#2326 — the provider's keys are never printed).
///
/// The line IS the button — the design forbids a detail page between a
/// person and the decision — so a tap opens the screen where it is made.
class _Row extends StatelessWidget {
  const _Row({super.key, required this.item});

  final Attention item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // English only where no localization is installed (a bare test app).
    final l10n = AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('en'));
    final locale = Localizations.maybeLocaleOf(context)?.toLanguageTag();
    final since = DateFormat.yMMMd(locale).format(item.waitingSince.toLocal());
    return ListTile(
      key: const ValueKey('attention-chevron-right'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(_iconFor(item.kind)),
      title: Text(attentionTitle(l10n, item), style: theme.textTheme.bodyLarge),
      subtitle: Text(l10n.attentionWaitingSince(since)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(attentionRoute(item.action)),
    );
  }

  static IconData _iconFor(AttentionKind kind) => switch (kind) {
        AttentionKind.money => Icons.payments_outlined,
        AttentionKind.person => Icons.person_outline,
        AttentionKind.month => Icons.receipt_long_outlined,
        AttentionKind.instance => Icons.dns_outlined,
        AttentionKind.configuration => Icons.tune_outlined,
      };
}

/// The sentence a line reads, in the reader's language.
String attentionTitle(AppLocalizations l10n, Attention item) =>
    switch (item.action) {
      AttentionAction.decide =>
        l10n.attentionDecide(eventTypeWord(l10n, item.subject)),
      AttentionAction.admit => l10n.attentionAdmit(item.count),
      AttentionAction.issue => l10n.attentionIssue(item.count),
    };

/// Where a tap takes the person: the screen where that decision is made.
/// Each route's own redirect handles a feature or permission that is off.
String attentionRoute(AttentionAction action) => switch (action) {
      AttentionAction.decide => '/events',
      AttentionAction.admit => '/members',
      AttentionAction.issue => '/invoicing/wizard',
    };
