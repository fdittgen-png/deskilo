// SPDX-License-Identifier: 0BSD
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
/// lives HERE, so every form just drops the widget in. Visually 20 px,
/// but the tap target keeps the 48 dp floor via the IconButton's
/// default constraints being restored on tap area (splash radius).
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
      visualDensity: VisualDensity.compact,
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
          Flexible(child: Text(text, style: style)),
          HelpDot(topic, anchor: anchor),
        ],
      );
}
