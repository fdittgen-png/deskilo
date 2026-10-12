// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_hint.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_tab_bar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/money_face.dart';
import '../../providers/money_face_controller.dart';

/// The label of a face, as the tab and the help hint call it.
String _moneyFaceLabel(AppLocalizations l10n, MoneyFace face) => switch (face) {
      MoneyFace.statement => l10n.moneyFaceStatement,
      MoneyFace.payments => l10n.moneyFacePayments,
      MoneyFace.invoices => l10n.moneyFaceInvoices,
      MoneyFace.usage => l10n.moneyFaceUsage,
      MoneyFace.documents => l10n.moneyFaceDocuments,
    };

/// The #486 section label of the classic column: small caps, muted.
Widget moneySectionLabel(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.1,
            ),
      ),
    );

/// Action labels wrap at the user's chosen text size.
Widget fittedLabel(String text) => Text(
        text,
        textAlign: TextAlign.start,
    );

/// Actions use one column when width or enlarged text needs it.
class MoneyActionGrid extends StatelessWidget {
  const MoneyActionGrid(this.buttons, {super.key});

  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final singleColumn = constraints.maxWidth < 480 ||
              MediaQuery.textScalerOf(context).scale(100) > 130;
          final buttonWidth = singleColumn ? constraints.maxWidth
              : (constraints.maxWidth - AppSpacing.sm) / 2;
          return Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final b in buttons) SizedBox(width: buttonWidth, child: b),
            ],
          );
        },
      );
}

/// The workspace's existing commands, separate from the personal archive.
class MoneyWorkspaceTools extends StatelessWidget {
  const MoneyWorkspaceTools({super.key, required this.actions});
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Card(child: ExpansionTile(
    key: const ValueKey('money-workspace-tools'),
    title: Text(context.l10n.uxMoneyWorkspaceTools),
    leading: const Icon(Icons.business_outlined),
    childrenPadding: AppSpacing.gutterAll,
    children: actions,
  ));
}

/// #486 — the month's BOTTOM LINE, leading the landscape side panel and
/// the Payments face: the balance, red when owed.
class MoneyBalanceCard extends StatelessWidget {
  const MoneyBalanceCard({
    super.key,
    required this.balanceCents,
    required this.currency,
  });

  final int? balanceCents;
  final MoneyFormat currency;

  @override
  Widget build(BuildContext context) {
    final cents = balanceCents;
    if (cents == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('money-balance-card'),
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Row(children: [
          Expanded(
            child: Text(l10n.billBalance,
                style: theme.textTheme.titleMedium),
          ),
          Text(
            currency.formatMinor(cents),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: cents < 0 ? theme.colorScheme.error : null,
            ),
          ),
        ]),
      ),
    );
  }
}

HelpHintId _moneyFaceHint(MoneyFace face) => switch (face) {
      MoneyFace.statement => HelpHintId.moneyStatement,
      MoneyFace.payments => HelpHintId.moneyPayments,
      MoneyFace.invoices => HelpHintId.moneyInvoices,
      // The usage face answers the same question the statement does —
      // what this month costs — from the booking end, so it shares its
      // hint rather than inventing a second explanation of one thing.
      MoneyFace.usage => HelpHintId.moneyStatement,
      MoneyFace.documents => HelpHintId.moneyDocuments,
    };

/// Finances destinations: monthly views share a period chooser; invoices
/// cover all periods. The screen owns providers and actions; this widget
/// owns the tabs and one responsive reading flow.
///
/// WHY THE TAB LIVES IN A PROVIDER. A calendar row that lands on a
/// payment wants the Payments face; an invoice link the Invoices face.
/// The requested face is state the screen reads, not a tap it replays —
/// the inbox does it the same way.
class MoneyFacesView extends ConsumerStatefulWidget {
  const MoneyFacesView({
    super.key,
    required this.periodHeader,
    required this.cards,
    required this.actions,
  });

  final Widget periodHeader;
  final Map<MoneyFace, List<Widget>> cards;
  final Map<MoneyFace, List<Widget>> actions;

  @override
  ConsumerState<MoneyFacesView> createState() => _MoneyFacesViewState();
}

class _MoneyFacesViewState extends ConsumerState<MoneyFacesView>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(
    length: MoneyFace.values.length,
    initialIndex: ref.read(moneyFaceControllerProvider).index,
    vsync: this,
  )..addListener(_onTab);

  void _onTab() {
    if (_controller.indexIsChanging) return;
    final face = MoneyFace.values[_controller.index];
    if (ref.read(moneyFaceControllerProvider) != face) {
      ref.read(moneyFaceControllerProvider.notifier).show(face);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final face = ref.watch(moneyFaceControllerProvider);
    if (_controller.index != face.index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.index != face.index) {
          _controller.index = face.index;
        }
      });
    }
    final cards = widget.cards[face] ?? const <Widget>[];
    final actions = widget.actions[face] ?? const <Widget>[];
    final hint = HelpHint(_moneyFaceHint(face), key: ValueKey('money-hint-${face.name}'));

    final labels = l10n;
    final scope = switch (face) {
      MoneyFace.statement => labels.uxMoneyStatementScope,
      MoneyFace.payments => labels.uxMoneyPaymentsScope,
      MoneyFace.invoices => labels.uxMoneyInvoicesScope,
      MoneyFace.usage => labels.uxMoneyUsageScope,
      MoneyFace.documents => labels.uxMoneyDocumentsScope,
    };
    final scopeHeader = Padding(
      key: ValueKey('money-scope-${face.name}'),
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_moneyFaceLabel(l10n, face), style: theme.textTheme.headlineSmall?.strong),
        const SizedBox(height: AppSpacing.xs),
        Text(scope, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
      ]),
    );
    final monthly = face != MoneyFace.invoices;

    // #2313 — the app's one horizontal menu.
    final tabs = AppTabBar(
      barKey: const ValueKey('money-faces'),
      controller: _controller,
      tabs: [
        for (final f in MoneyFace.values)
          AppTab(_moneyFaceLabel(l10n, f), key: ValueKey('money-face-${f.name}')),
      ],
    );

    return Theme(
      data: theme.copyWith(
        outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 56), padding: AppSpacing.lgAll,
          alignment: Alignment.centerLeft,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        )),
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
          minimumSize: const Size(0, 56), padding: AppSpacing.lgAll,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        )),
      ),
      child: Column(
      children: [
        Padding(padding: AppSpacing.gutterAll, child: Material(
          color: scheme.surfaceContainerLow, borderRadius: AppRadius.lgAll, child: tabs,
        )),
        Expanded(
          child: ListView(
            key: ValueKey('money-face-body-${face.name}'),
            padding: AppSpacing.gutterAll,
            children: [
              scopeHeader,
              if (monthly) Padding(padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: Card(child: widget.periodHeader)),
              for (final item in [...cards, ...actions])
                if (item is! SizedBox) Padding(padding: const EdgeInsets.only(bottom: AppSpacing.md), child: item),
              hint,
            ],
          ),
        ),
      ],
      ),
    );
  }
}
