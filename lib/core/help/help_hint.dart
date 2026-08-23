// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_spacing.dart';
import 'help_hint_providers.dart';
import 'help_tips.dart';

export 'help_tips.dart';

/// One compact, dismissible tip carousel at the top of a form/screen
/// (#606, #610): 3–5 tips for THAT surface, ordered from the basic
/// how-to to the deeper tricks, browsable with chevrons and by swiping,
/// each tip with a "Learn more" link into the in-app guide at its
/// matching section, and a 48dp dismiss target. The carousel remembers
/// the last tip shown per surface and opens the NEXT visit on the tip
/// after it, rotating — so every visit teaches something new. Dismissal
/// persists per hint id; Settings can restore all. Rides the
/// [WorkspaceFeature.formHelpHints] flag, so gating lives HERE — every
/// surface just drops the widget in.
class HelpHint extends ConsumerStatefulWidget {
  const HelpHint(this.id, {super.key});

  final HelpHintId id;

  /// Tip 1 — the surface's basic how-to sentence (#606).
  static String text(AppLocalizations? l10n, HelpHintId id) =>
      helpHintText(l10n, id);

  /// The surface's default "Learn more" topic — see [helpHintTopic].
  static String topic(AppLocalizations? l10n, HelpHintId id) =>
      helpHintTopic(l10n, id);

  /// The surface's carousel — see [helpHintTips] for the catalog.
  static List<HelpTip> tips(AppLocalizations? l10n, HelpHintId id) =>
      helpHintTips(l10n, id);

  /// Where a fresh visit opens — see [helpHintInitialTipIndex].
  static int initialTipIndex(int? lastShown, int tipCount) =>
      helpHintInitialTipIndex(lastShown, tipCount);

  @override
  ConsumerState<HelpHint> createState() => _HelpHintState();
}

/// Horizontal drag (logical px) that counts as a page swipe.
const double _swipeThreshold = 40;

class _HelpHintState extends ConsumerState<HelpHint> {
  /// Computed once per visit (rotated past the stored tip) — a rebuild
  /// (or the position write landing) must never re-advance.
  bool _visited = false;
  int _page = 0;

  /// +1 when the last navigation went forward, -1 backward — the slide
  /// animation enters from the side the tip "comes from".
  int _direction = 1;

  /// Accumulated horizontal drag of the swipe in flight.
  double _dragDx = 0;

  void _persist(int page) => ref
      .read(helpHintPositionsProvider.notifier)
      .setPosition(widget.id.name, page);

  /// Navigation wraps — the indicator keeps position obvious. Paging is
  /// a plain state change (no PageView: an extra Scrollable inside a
  /// screen breaks every `scrollUntilVisible` that assumes one).
  void _goTo(int target, int tipCount) {
    final next = ((target % tipCount) + tipCount) % tipCount;
    setState(() {
      _direction = target >= _page ? 1 : -1;
      _page = next;
    });
    _persist(next);
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    if (!ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.formHelpHints)) {
      return const SizedBox.shrink();
    }
    // Unknown while the one-time reads are in flight: stay hidden — a
    // hint that flashes, vanishes or jumps tips reads as a glitch.
    final dismissed = ref.watch(dismissedHelpHintsProvider).value;
    final positions = ref.watch(helpHintPositionsProvider).value;
    if (dismissed == null || positions == null || dismissed.contains(id.name)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tips = HelpHint.tips(l10n, id);
    if (!_visited) {
      // First build of this visit: open on the tip after the stored one
      // and remember it — this visit's tip becomes the new "last shown".
      _visited = true;
      _page = HelpHint.initialTipIndex(positions[id.name], tips.length);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _persist(_page);
      });
    }
    final tipStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: scheme.onSecondaryContainer);
    final position = '${_page + 1}/${tips.length}';
    return Card(
      key: ValueKey('help-hint-${id.name}'),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Icon(
                Icons.lightbulb_outline,
                size: 18,
                color: scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // sm, not md (#606): the chevron row below is ~8px
                  // taller than the old Learn-more row — trimming here
                  // keeps the card's total height at the #606 footprint
                  // that fixed-height screens were laid out against.
                  const SizedBox(height: AppSpacing.sm),
                  // Sized by the CURRENT tip (not the tallest), so on
                  // tip 1 the card keeps exactly the #606 footprint —
                  // fixed-height screens were built against it.
                  // AnimatedSize smooths the change when paging.
                  GestureDetector(
                    key: ValueKey('help-hint-pager-${id.name}'),
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (_) => _dragDx = 0,
                    onHorizontalDragUpdate: (details) =>
                        _dragDx += details.delta.dx,
                    onHorizontalDragEnd: (_) {
                      // Swiping left reveals the next tip, right the
                      // previous — same wrap as the chevrons.
                      if (_dragDx <= -_swipeThreshold) {
                        _goTo(_page + 1, tips.length);
                      } else if (_dragDx >= _swipeThreshold) {
                        _goTo(_page - 1, tips.length);
                      }
                    },
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      alignment: AlignmentDirectional.topStart,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: Offset(0.15 * _direction, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        layoutBuilder: (current, previous) => Stack(
                          alignment: AlignmentDirectional.topStart,
                          children: [...previous, ?current],
                        ),
                        child: SizedBox(
                          key: ValueKey('help-hint-tip-$_page'),
                          width: double.infinity,
                          child: Text(tips[_page].text, style: tipStyle),
                        ),
                      ),
                    ),
                  ),
                  // A Wrap, not a Row: in a narrow side panel the
                  // chevrons must never squeeze "Learn more" below the
                  // 48dp tap-target floor — the nav group drops to its
                  // own line instead.
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                        key: ValueKey('help-hint-learn-more-${id.name}'),
                        onPressed: () => context.push(
                          Uri(
                            path: '/help',
                            queryParameters: {
                              'topic':
                                  tips[_page].topic ?? HelpHint.topic(l10n, id),
                            },
                          ).toString(),
                        ),
                        child: Text(
                          l10n?.helpHintLearnMore ?? 'Learn more',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (tips.length > 1)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: ValueKey('help-hint-prev-${id.name}'),
                              tooltip: l10n?.helpHintPrevTip ?? 'Previous tip',
                              icon: const Icon(Icons.navigate_before, size: 20),
                              color: scheme.onSecondaryContainer,
                              onPressed: () => _goTo(_page - 1, tips.length),
                            ),
                            Text(
                              position,
                              key: ValueKey('help-hint-pos-${id.name}'),
                              style: tipStyle,
                            ),
                            IconButton(
                              key: ValueKey('help-hint-next-${id.name}'),
                              tooltip: l10n?.helpHintNextTip ?? 'Next tip',
                              icon: const Icon(Icons.navigate_next, size: 20),
                              color: scheme.onSecondaryContainer,
                              onPressed: () => _goTo(_page + 1, tips.length),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              key: ValueKey('help-hint-dismiss-${id.name}'),
              tooltip: l10n?.helpHintDismiss ?? 'Dismiss hint',
              icon: const Icon(Icons.close, size: 18),
              color: scheme.onSecondaryContainer,
              onPressed: () => ref
                  .read(dismissedHelpHintsProvider.notifier)
                  .dismiss(id.name),
            ),
          ],
        ),
      ),
    );
  }
}
