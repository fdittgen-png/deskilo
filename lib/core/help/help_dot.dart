// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../../l10n/app_localizations.dart';

/// #763 — the little ? beside a parameter or entry field: one tap opens
/// the in-app guide at [topic] (the same `/help?topic=` jump the hint
/// carousels use, so a topic is always a substring of a guide heading,
/// localized). The SAME symbols exist on the setup questionnaire
/// (web/setup.html `helpIcon`) — the two are kept in sync by rule
/// (docs/AGENT_RULES.md).
///
/// Rides [WorkspaceFeature.formHelpHints] like the hint cards: gating
/// lives HERE, so every form just drops the widget in.
///
/// Visually 17 px and 48 dp to the finger. #1235 — the comment here used
/// to claim the 48 dp floor was kept "via the IconButton's default
/// constraints", and `visualDensity: VisualDensity.compact` had taken
/// it to 40 × 40. Flutter's own `androidTapTargetGuideline` found it on
/// three screens at once. An explicit constraint says the size rather
/// than inheriting it, so the next density tweak cannot quietly undo
/// it.
class HelpDot extends ConsumerWidget {
  const HelpDot(this.topic, {this.anchor, super.key});

  /// Localized needle for the guide jump — take it from an
  /// `AppLocalizations` topic getter, never a hard-coded literal, so it
  /// matches the reader's guide language.
  final String topic;

  /// #1016 — the exact object this symbol documents, from [HelpAnchor].
  /// With one, the guide opens at that object; without, at the first
  /// heading containing [topic], which is where the coarse topics land.
  final String? anchor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.formHelpHints)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      key: ValueKey('help-dot-$topic'),
      tooltip: l10n?.helpDotTooltip ?? 'Open the guide',
      // The FINGER gets 48; the ink and the glyph stay small.
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      padding: EdgeInsets.zero,
      iconSize: 17,
      color: scheme.primary.withValues(alpha: .75),
      icon: const Icon(Icons.help_outline),
      onPressed: () => context.push(
        Uri(path: '/help', queryParameters: {
          'topic': topic,
          'anchor': ?anchor,
        }).toString(),
      ),
    );
  }
}

/// A `ListTile`/`SwitchListTile` title with the ? at the end of the
/// text — `title: HelpDotTitle('Label', topic)` keeps `find.text`
/// working and never steals the row's own tap.
class HelpDotTitle extends StatelessWidget {
  const HelpDotTitle(
    this.text,
    this.topic, {
    this.anchor,
    this.style,
    super.key,
  });

  final String text;
  final String topic;

  /// #1016 — see [HelpDot.anchor].
  final String? anchor;

  /// #1022 — a section header carries its own type. Without this the
  /// widget could only ever replace a tile title, so a `titleSmall`
  /// header had to choose between its size and its help symbol.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Row(
        // #1185 — the symbol sits at the END of the title area, which on
        // a title that wraps means the far right of the row. Putting it
        // inline with the last word needs `Text.rich`, and that takes the
        // title out of reach of `find.text`, which two dozen tests (and
        // every `scrollUntilVisible`) use to locate a row. The cosmetic
        // gain is not worth making every titled row untestable; what is
        // fixed here is the ALIGNMENT — top, with the first line, rather
        // than centred against two.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // #1235 — `Expanded`, not `Flexible`. Loose, the title kept
          // its intrinsic width and the symbol sat immediately after
          // the last word: on a row 768 wide with a title of 313, that
          // put a 48 dp target across the row's own centre, and a tap
          // aimed at the row opened the guide instead. Four tests
          // caught it by tapping a tile's middle, which is exactly what
          // a finger does. The symbol belongs at the far right of the
          // title area — which is what #1185 said it was doing.
          Expanded(child: Text(text, style: style)),
          HelpDot(topic, anchor: anchor),
        ],
      );
}
