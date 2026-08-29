// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_hint.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/money_face.dart';
import '../../providers/money_face_controller.dart';

/// The label of a face, as the tab and the help hint call it.
String moneyFaceLabel(AppLocalizations? l10n, MoneyFace face) => switch (face) {
      MoneyFace.payments => l10n?.moneyFacePayments ?? 'Payments',
      MoneyFace.consumption => l10n?.moneyFaceConsumption ?? 'Consumption',
      MoneyFace.invoices => l10n?.moneyFaceInvoices ?? 'Invoices',
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

Widget fittedLabel(String text) =>
    FittedBox(fit: BoxFit.scaleDown, child: Text(text));

/// Two buttons per row on a phone, wrapping; each cell half the width.
class MoneyActionGrid extends StatelessWidget {
  const MoneyActionGrid(this.buttons, {super.key});

  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final buttonWidth = (constraints.maxWidth - AppSpacing.sm) / 2;
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

HelpHintId moneyFaceHint(MoneyFace face) => switch (face) {
      MoneyFace.payments => HelpHintId.moneyPayments,
      MoneyFace.consumption => HelpHintId.moneyConsumption,
      MoneyFace.invoices => HelpHintId.moneyInvoices,
    };

/// #720 — the Finances tab as three faces under one shared period
/// chooser. The screen builds the pieces (it owns the sheets and the
/// providers); this widget owns the TAB and the layout: a column in
/// portrait, the #486 split in landscape (header, balance and the
/// face's actions left; the face's cards right).
///
/// WHY THE TAB LIVES IN A PROVIDER. A calendar row that lands on a
/// payment wants the Payments face; an invoice link the Invoices face.
/// The requested face is state the screen reads, not a tap it replays —
/// the inbox does it the same way.
class MoneyFacesView extends ConsumerStatefulWidget {
  const MoneyFacesView({
    super.key,
    required this.periodHeader,
    required this.balanceCard,
    required this.cards,
    required this.actions,
  });

  final Widget periodHeader;
  final Widget balanceCard;
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
    final l10n = AppLocalizations.of(context);
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
    final hint = HelpHint(moneyFaceHint(face), key: ValueKey('money-hint-${face.name}'));

    final tabs = TabBar(
      key: const ValueKey('money-faces'),
      controller: _controller,
      tabs: [
        for (final f in MoneyFace.values)
          Tab(
            key: ValueKey('money-face-${f.name}'),
            text: moneyFaceLabel(l10n, f),
          ),
      ],
    );

    return Column(
      children: [
        Material(color: Theme.of(context).colorScheme.surface, child: tabs),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > constraints.maxHeight) {
                return Row(
                  children: [
                    SizedBox(
                      width: (constraints.maxWidth * 0.32).clamp(280.0, 400.0),
                      child: SingleChildScrollView(
                        padding: AppSpacing.mdAll,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            hint,
                            widget.periodHeader,
                            if (face == MoneyFace.payments) widget.balanceCard,
                            ...actions,
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: ListView(
                        key: ValueKey('money-face-body-${face.name}'),
                        padding: AppSpacing.mdAll,
                        children: cards,
                      ),
                    ),
                  ],
                );
              }
              return ListView(
                key: ValueKey('money-face-body-${face.name}'),
                padding: AppSpacing.mdAll,
                children: [hint, widget.periodHeader, ...cards, ...actions],
              );
            },
          ),
        ),
      ],
    );
  }
}
