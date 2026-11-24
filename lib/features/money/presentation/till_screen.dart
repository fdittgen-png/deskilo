// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 (CS4) -- the till: a full-screen basket served in seconds. The items are keys; a tap rings one up (a second tap
// one more); a line's quantity is an exact decimal typed on it; the server prices the basket and makes the sale in one
// command. Where the country does not allow the counter yet, the till says which operation and offers nothing: nothing
// is numbered and nothing is taken.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/help/help_dot.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/scan/scan_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/adaptive/window_class.dart';
import '../../../core/ui/form_kit.dart';
import '../../../core/ui/kit/page_title.dart';
import '../../../core/ui/loading_view.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart' show enabledFeaturesSyncProvider;
import '../domain/counter_till.dart';
import '../domain/till_drawer.dart';
import '../providers/till_drawer_providers.dart';
import '../providers/till_providers.dart';
import 'till_basket.dart';
import 'till_cash_dialog.dart';
import 'till_session.dart';
import 'till_text.dart';

/// What a code scanned at the till rings up, as the route reads it from the stock (#4436).
typedef TillScanReader = Future<TillScan> Function(String code);

/// The till. [keys] are the items it offers, read by the route from the stock: the till does not know the stock.
class TillScreen extends ConsumerWidget {
  const TillScreen({super.key, required this.workspaceId, required this.keys, this.scan});

  /// The open business; null while it is being read.
  final String? workspaceId;
  final AsyncValue<List<TillKey>> keys;

  /// #4436 -- reads a scanned code (an item, or one piece by its tag); null where the business uses no scanner.
  final TillScanReader? scan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceId = this.workspaceId;
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(context.l10n.tillTitle),
        actions: [HelpDot(context.l10n.tillTitle, anchor: HelpAnchor.moneyTill)],
      ),
      body: workspaceId == null ? const LoadingView() : _Readiness(workspaceId: workspaceId, keys: keys, scan: scan),
    );
  }
}

/// The till opens only where the country's operations are supported.
class _Readiness extends ConsumerWidget {
  const _Readiness({required this.workspaceId, required this.keys, this.scan});

  final String workspaceId;
  final AsyncValue<List<TillKey>> keys;
  final TillScanReader? scan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ref
        .watch(tillReadinessProvider(workspaceId))
        .when(
          loading: () => const LoadingView(),
          error: (e, _) => _Notice(
            text: tillProblemText(l10n, e),
            onRetry: () => ref.invalidate(tillReadinessProvider(workspaceId)),
          ),
          data: (readiness) => readiness.ready
              ? _SessionGate(workspaceId: workspaceId, keys: keys, scan: scan)
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

/// #4367 -- a business that runs till sessions sells only on a till with an open session: the open tills are read, the one
/// that sells is chosen (the only one open, or the cashier's pick), and with none open the till offers to open one. A
/// business that does not run them sells as before, on no till.
class _SessionGate extends ConsumerWidget {
  const _SessionGate({required this.workspaceId, required this.keys, this.scan});

  final String workspaceId;
  final AsyncValue<List<TillKey>> keys;
  final TillScanReader? scan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sessions = ref.watch(enabledFeaturesSyncProvider).contains(WorkspaceFeature.counterTillSessions);
    if (!sessions) return _Till(key: ValueKey('till-$workspaceId'), workspaceId: workspaceId, keys: keys, scan: scan);
    return ref
        .watch(tillDrawerProvider(workspaceId))
        .when(
          loading: () => const LoadingView(),
          error: (e, _) => _Notice(text: tillProblemText(l10n, e), onRetry: () => ref.invalidate(tillDrawerProvider(workspaceId))),
          data: (tills) {
            final open = [for (final t in tills) if (t.isOpen && t.active) t];
            if (open.isEmpty) return _OpenFirst(workspaceId: workspaceId);
            final session = ref.read(tillSessionProvider(workspaceId));
            return ValueListenableBuilder<String?>(
              valueListenable: session.chosenTill,
              builder: (context, chosen, _) {
                final till = open.where((t) => t.id == chosen).firstOrNull ?? (open.length == 1 ? open.first : null);
                if (till == null) return _ChooseTill(tills: open, onPick: (t) => session.chosenTill.value = t.id);
                return _Till(key: ValueKey('till-$workspaceId-${till.id}'), workspaceId: workspaceId, keys: keys, till: till, scan: scan);
              },
            );
          },
        );
  }
}

/// No till is open: the till says so and goes to the drawer to open one.
class _OpenFirst extends ConsumerWidget {
  const _OpenFirst({required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Center(
      key: const ValueKey('till-open-first'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.tillDrawerOpenFirstTitle, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const FormGap(),
            Text(l10n.tillDrawerOpenFirstBody, textAlign: TextAlign.center),
            const FormGap(),
            FilledButton(
              key: const ValueKey('till-open-the-till'),
              onPressed: () async {
                await context.push('/till/drawer');
                ref.invalidate(tillDrawerProvider(workspaceId));
              },
              child: Text(l10n.tillDrawerOpenAction),
            ),
          ],
        ),
      ),
    );
  }
}

/// Several tills are open: the cashier says which one this sale is made on.
class _ChooseTill extends StatelessWidget {
  const _ChooseTill({required this.tills, required this.onPick});

  final List<DrawerTill> tills;
  final void Function(DrawerTill) onPick;

  @override
  Widget build(BuildContext context) => Center(
    key: const ValueKey('till-choose'),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l10n.tillDrawerChoose, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          const FormGap(),
          for (final t in tills)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: FilledButton.tonal(key: ValueKey('till-choose-${t.id}'), onPressed: () => onPick(t), child: Text(t.name)),
            ),
        ],
      ),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.text, this.hint, this.onRetry});

  final String text;
  final String? hint;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          if (hint != null) ...[const FormGap(), Text(hint!, textAlign: TextAlign.center)],
          if (onRetry != null) ...[
            const FormGap(),
            FilledButton(key: const ValueKey('till-retry'), onPressed: onRetry, child: Text(context.l10n.tillRetry)),
          ],
        ],
      ),
    ),
  );
}

class _Till extends ConsumerStatefulWidget {
  const _Till({super.key, required this.workspaceId, required this.keys, this.till, this.scan});

  final String workspaceId;
  final AsyncValue<List<TillKey>> keys;
  final TillScanReader? scan;

  /// The till this sale is made on; null for a business that does not run till sessions.
  final DrawerTill? till;

  @override
  ConsumerState<_Till> createState() => _TillState();
}

class _TillState extends ConsumerState<_Till> {
  late final TillSession _session = ref.read(tillSessionProvider(widget.workspaceId))..tillId = widget.till?.id;

  @override
  void dispose() {
    _session.leave();
    super.dispose();
  }

  /// Leaving with a sale that may have been made asks first: it stays waiting, and is not to be rung up again.
  Future<void> _asked(BuildContext context) async {
    final l10n = context.l10n;
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.tillLeaveTitle),
        content: Text(l10n.tillLeaveBody),
        actions: [
          TextButton(key: const ValueKey('till-leave-stay'), onPressed: () => Navigator.of(c).pop(false), child: Text(l10n.tillLeaveStay)),
          FilledButton(key: const ValueKey('till-leave-go'), onPressed: () => Navigator.of(c).pop(true), child: Text(l10n.tillLeaveGo)),
        ],
      ),
    );
    if (go == true && context.mounted) Navigator.of(context).pop();
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

  /// #4436 -- a scanned code: an item rings one up, a piece's tag rings up that piece, anything else is said.
  Future<void> _scanned(String code) async {
    final l10n = context.l10n;
    final scan = widget.scan;
    if (scan == null) return;
    final TillScan found;
    try {
      found = await scan(code);
    } on Object catch (e, st) {
      TraceLogger.instance.warn('money', 'a code scanned at the till could not be read', error: e, stackTrace: st);
      _session.reject(l10n.tillFailed);
      return;
    }
    switch (found) {
      case TillScanItem(:final key):
        await _session.add(itemId: key.id, name: key.name, unit: key.unit);
      case TillScanPiece(:final key, :final tag):
        await _session.addPiece(itemId: key.id, name: key.name, unit: key.unit, tag: tag, twice: l10n.tillPieceTwice(tag));
      case TillScanUnknown(:final code):
        _session.reject(l10n.tillScanUnknown(code));
    }
  }

  @override
  Widget build(BuildContext context) {
        return ValueListenableBuilder<TillState>(
      valueListenable: _session.state,
      builder: (context, state, child) => PopScope(
        canPop: !state.unconfirmed,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_asked(context));
        },
        child: ScanScope(enabled: widget.scan != null, onScan: (code) => unawaited(_scanned(code)), child: child!),
      ),
      child: LayoutBuilder(
      builder: (context, box) {
        final keys = _Keys(
          key: const ValueKey('till-keys'),
          items: widget.keys,
          onTap: (i) => unawaited(_session.add(itemId: i.id, name: i.name, unit: i.unit)),
        );
        final basket = ValueListenableBuilder<TillState>(
          valueListenable: _session.state,
          builder: (context, state, _) => TillBasket(
            key: const ValueKey('till-basket'),
            state: state,
            onQuantity: _setQuantity,
            onRemove: (i) => unawaited(_session.remove(i)),
            onPay: () => unawaited(_pay(state)),
            onNext: _session.next,
            onRetry: () => unawaited(_session.retry()),
            onConfirm: () => unawaited(_session.confirmSale()),
          ),
        );
        if (WindowClass.ofWidth(box.maxWidth).atLeast(WindowClass.medium)) {
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
    ),
    );
  }
}

/// The items as keys.
class _Keys extends StatelessWidget {
  const _Keys({super.key, required this.items, required this.onTap});

  final AsyncValue<List<TillKey>> items;
  final void Function(TillKey) onTap;

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
