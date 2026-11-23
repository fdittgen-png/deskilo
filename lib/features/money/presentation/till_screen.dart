// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 (CS4) -- the till: a full-screen basket served in seconds. The items are keys; a tap rings one up (a second tap
// one more); a line's quantity is an exact decimal typed on it; the server prices the basket and makes the sale in one
// command. Where the country does not allow the counter yet, the till says which operation and offers nothing: nothing
// is numbered and nothing is taken.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/form_kit.dart';
import '../../../core/ui/kit/page_title.dart';
import '../../../core/ui/loading_view.dart';
import '../../stock/domain/stock_page.dart';
import '../../stock/providers/stock_providers.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../application/till_session.dart';
import '../providers/till_providers.dart';
import 'till_basket.dart';
import 'till_cash_dialog.dart';
import 'till_text.dart';

/// The width from which the keys and the basket sit side by side.
const double _tillWide = 720;

class TillScreen extends ConsumerWidget {
  const TillScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceId = ref.watch(currentWorkspaceProvider).value?.id;
    return Scaffold(
      appBar: AppBar(title: PageTitle(context.l10n.tillTitle)),
      body: workspaceId == null ? const LoadingView() : _Readiness(workspaceId: workspaceId),
    );
  }
}

/// The till opens only where the country's operations are supported.
class _Readiness extends ConsumerWidget {
  const _Readiness({required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ref
        .watch(tillReadinessProvider(workspaceId))
        .when(
          loading: () => const LoadingView(),
          error: (e, _) => _Notice(text: tillProblemText(l10n, e)),
          data: (readiness) => readiness.ready
              ? _Till(workspaceId: workspaceId)
              : _Notice(
                  key: const ValueKey('till-not-ready'),
                  text: l10n.tillNotReady(
                    [for (final o in readiness.blocking) tillOperationName(l10n, o.operation)].join(', '),
                  ),
                  hint: l10n.tillNotReadyHint,
                ),
        );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.text, this.hint});

  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          if (hint != null) ...[const FormGap(), Text(hint!, textAlign: TextAlign.center)],
        ],
      ),
    ),
  );
}

class _Till extends ConsumerStatefulWidget {
  const _Till({required this.workspaceId});

  final String workspaceId;

  @override
  ConsumerState<_Till> createState() => _TillState();
}

class _TillState extends ConsumerState<_Till> {
  late final TillSession _session = TillSession(port: ref.read(tillPortProvider), workspaceId: widget.workspaceId);

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  Future<void> _pay(TillState state) async {
    final draft = state.draft;
    if (draft == null) return;
    final given = await showTillCashDialog(context, totalMinor: draft.totals.grossMinor, currency: draft.totals.currency);
    if (given != null) await _session.payCash(given);
  }

  Future<void> _setQuantity(int index) async {
    final l10n = context.l10n;
    final typed = await showTillQuantityDialog(context, current: _session.state.value.lines[index]);
    if (typed == null) return;
    final ok = await _session.setQuantity(index, typed);
    if (!ok && mounted) _session.reject(l10n.tillQuantityRefused);
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(stockItemsProvider(widget.workspaceId));
    return LayoutBuilder(
      builder: (context, box) {
        final keys = _Keys(
          items: items,
          onTap: (i) => unawaited(_session.add(itemId: i.id, name: i.name, unit: i.unit)),
        );
        final basket = ValueListenableBuilder<TillState>(
          valueListenable: _session.state,
          builder: (context, state, _) => TillBasket(
            state: state,
            onQuantity: _setQuantity,
            onRemove: (i) => unawaited(_session.remove(i)),
            onPay: () => unawaited(_pay(state)),
            onNext: _session.next,
          ),
        );
        if (box.maxWidth >= _tillWide) {
          return Row(
            children: [
              Expanded(flex: 3, child: keys),
              const VerticalDivider(width: 1),
              Expanded(flex: 2, child: basket),
            ],
          );
        }
        return Column(
          children: [
            Expanded(flex: 2, child: keys),
            const Divider(height: 1),
            Expanded(flex: 3, child: basket),
          ],
        );
      },
    );
  }
}

/// The items as keys.
class _Keys extends StatelessWidget {
  const _Keys({required this.items, required this.onTap});

  final AsyncValue<List<StockItem>> items;
  final void Function(StockItem) onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return items.when(
      loading: () => const LoadingView(),
      error: (e, _) => _Notice(text: tillProblemText(l10n, e)),
      data: (list) => list.isEmpty
          ? _Notice(text: l10n.tillKeysEmpty)
          : GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                mainAxisExtent: 64,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
              ),
              itemCount: list.length,
              itemBuilder: (context, i) => FilledButton.tonal(
                key: ValueKey('till-key-${list[i].id}'),
                onPressed: () => onTap(list[i]),
                child: Text(list[i].name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
              ),
            ),
    );
  }
}
