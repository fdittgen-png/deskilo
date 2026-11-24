// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4367 (CS5) -- the cash drawer of the tills: every till with its state, the session open on it (its float and, to
// someone who may see it, the cash it should hold), the doors to open it, to record cash paid in or out, and to count and
// close it. The expected cash is the server's: while the drawer is counted blind the counter is not given it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../../core/ui/loading_view.dart';
import '../../application/till_drawer_commands.dart';
import '../../domain/till_drawer.dart';
import '../../providers/till_drawer_providers.dart';
import 'cash_entry_sheet.dart';
import 'close_sheet.dart';
import 'drawer_text.dart';
import 'open_sheet.dart';
import 'till_edit_sheet.dart';

/// The drawer screen. [canManage] is whether the person may add and edit tills (the sites' managers).
class TillDrawerScreen extends ConsumerWidget {
  const TillDrawerScreen({super.key, required this.workspaceId, required this.currency, required this.canManage, this.canCloseDay = false});

  /// The open business; null while it is being read.
  final String? workspaceId;
  final String currency;
  final bool canManage;

  /// Whether the person may see the finances, and so close the day.
  final bool canCloseDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspaceId = this.workspaceId;
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(l10n.tillDrawerTitle),
        actions: [
          if (canCloseDay)
            TextButton(key: const ValueKey('drawer-day-close'), onPressed: () => context.push('/till/day'), child: Text(l10n.tillDayTitle)),
          HelpDot(l10n.tillDrawerTitle, anchor: HelpAnchor.moneyTillDrawer)],
      ),
      floatingActionButton: canManage && workspaceId != null
          ? FloatingActionButton.extended(
              key: const ValueKey('drawer-add-till'),
              onPressed: () => showTillEditSheet(context, ref.read(tillDrawerCommandsProvider(workspaceId))),
              icon: const Icon(Icons.add),
              label: Text(l10n.tillDrawerAddTill),
            )
          : null,
      body: workspaceId == null ? const LoadingView() : _Tills(workspaceId: workspaceId, currency: currency, canManage: canManage),
    );
  }
}

class _Tills extends ConsumerWidget {
  const _Tills({required this.workspaceId, required this.currency, required this.canManage});

  final String workspaceId;
  final String currency;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ref
        .watch(tillDrawerProvider(workspaceId))
        .when(
          loading: () => const LoadingView(),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(drawerProblemText(l10n, e), textAlign: TextAlign.center),
                  const FormGap(),
                  FilledButton(key: const ValueKey('drawer-retry'), onPressed: () => ref.invalidate(tillDrawerProvider(workspaceId)), child: Text(l10n.tillRetry)),
                ],
              ),
            ),
          ),
          data: (tills) => tills.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      canManage ? l10n.tillDrawerNoTills : l10n.tillDrawerNoTillsPerson,
                      key: const ValueKey('drawer-no-tills'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                )
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, kFabSafeBottom),
                      children: [
                        for (final t in tills) _TillCard(workspaceId: workspaceId, currency: currency, till: t, canManage: canManage),
                      ],
                    ),
                  ),
                ),
        );
  }
}

class _TillCard extends ConsumerWidget {
  const _TillCard({required this.workspaceId, required this.currency, required this.till, required this.canManage});

  final String workspaceId;
  final String currency;
  final DrawerTill till;
  final bool canManage;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final settings = await ref.read(drawerSettingsProvider.future);
    if (!context.mounted) return;
    await showOpenTillSheet(context, ref.read(tillDrawerCommandsProvider(workspaceId)), till: till, currency: currency, byDenomination: settings.byDenomination);
  }

  Future<void> _entry(BuildContext context, WidgetRef ref, DrawerSession session) async {
    final settings = await ref.read(drawerSettingsProvider.future);
    if (!context.mounted) return;
    final done = await showCashEntrySheet(context, ref.read(tillDrawerCommandsProvider(workspaceId)), session: session, currency: currency, settings: settings);
    if (done && context.mounted) AppSnack.success(context, context.l10n.tillDrawerEntryDone);
  }

  Future<void> _close(BuildContext context, WidgetRef ref, DrawerSession session) async {
    final settings = await ref.read(drawerSettingsProvider.future);
    final expected = await ref.refresh(drawerExpectedProvider((workspaceId: workspaceId, sessionId: session.id)).future);
    if (!context.mounted) return;
    final closed = await showCloseTillSheet(
      context,
      ref.read(tillDrawerCommandsProvider(workspaceId)),
      CloseSheetInput(session: session, tillName: till.name, currency: currency, byDenomination: settings.byDenomination, expected: expected),
    );
    if (closed != null && context.mounted) await showDrawerClosedDialog(context, closed, currency: currency);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final money = appFormatOf(context).moneyIn(currency);
    final session = till.session;
    final state = !till.active
        ? l10n.tillDrawerStateOff
        : session == null
        ? l10n.tillDrawerStateClosed
        : l10n.tillDrawerStateOpen(money.formatMinor(session.floatMinor));
    return Card(
      key: ValueKey('drawer-till-${till.id}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(till.name, style: Theme.of(context).textTheme.titleMedium)),
                if (canManage)
                  IconButton(
                    key: ValueKey('drawer-edit-${till.id}'),
                    tooltip: l10n.tillDrawerEditTill,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => showTillEditSheet(context, ref.read(tillDrawerCommandsProvider(workspaceId)), till: till),
                  ),
              ],
            ),
            Text(state, key: ValueKey('drawer-state-${till.id}')),
            if (session != null) _Expected(workspaceId: workspaceId, sessionId: session.id, currency: currency),
            const FormGap(),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (session == null && till.active)
                  FilledButton(key: ValueKey('drawer-open-${till.id}'), onPressed: () => _open(context, ref), child: Text(l10n.tillDrawerOpenAction)),
                if (session != null) ...[
                  OutlinedButton(key: ValueKey('drawer-entry-${till.id}'), onPressed: () => _entry(context, ref, session), child: Text(l10n.tillDrawerCashAction)),
                  FilledButton(key: ValueKey('drawer-close-${till.id}'), onPressed: () => _close(context, ref, session), child: Text(l10n.tillDrawerCloseAction)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// What the open session should hold, when the server gives it; the words that it comes after the count, when not.
class _Expected extends ConsumerWidget {
  const _Expected({required this.workspaceId, required this.sessionId, required this.currency});

  final String workspaceId;
  final String sessionId;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final money = appFormatOf(context).moneyIn(currency);
    return ref
        .watch(drawerExpectedProvider((workspaceId: workspaceId, sessionId: sessionId)))
        .when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => Text(drawerProblemText(l10n, e)),
          data: (cash) => cash == null
              ? Text(l10n.tillDrawerExpectedHidden, key: ValueKey('drawer-hidden-$sessionId'))
              : Text(l10n.tillDrawerExpected(money.formatMinor(cash.expectedMinor)), key: ValueKey('drawer-expected-$sessionId')),
        );
  }
}
