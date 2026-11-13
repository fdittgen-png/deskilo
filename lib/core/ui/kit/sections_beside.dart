// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3619 (desk M6) — a long form of sections at the desk: the sections listed
// on the left, the chosen one beside the list in a form column. Every
// section stays mounted, so one form keeps its drafts and its one Save; a
// section that is not shown is not painted, not a Tab stop and not read by a
// screen reader. The page that uses it names the shown section in its
// address (`?section=<id>`, see [sectionInAddress]).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_spacing.dart';
import '../adaptive/page_measure.dart';

/// The width of the section list.
const double kSectionListWidth = 280;

/// One section: its id (in the address), its title and what it holds.
@immutable
class BesideSection {
  const BesideSection({
    required this.id,
    required this.title,
    required this.child,
    this.icon,
    this.destructive = false,
  });

  final String id;
  final String title;
  final IconData? icon;
  final bool destructive;
  final Widget child;
}

/// The sections listed beside the one shown. [selected] falls back to the
/// first section when it names none of them.
class SectionsBeside extends StatelessWidget {
  const SectionsBeside({
    super.key,
    required this.id,
    required this.sections,
    required this.selected,
    required this.onSelect,
    this.header = const [],
    this.footer,
  });

  /// Names the list's keys (`<id>-section-<section id>`).
  final String id;
  final List<BesideSection> sections;
  final String? selected;
  final ValueChanged<String> onSelect;

  /// Drawn above the shown section, in its column.
  final List<Widget> header;

  /// Pinned under the shown section (a Save bar).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = sections.any((s) => s.id == selected)
        ? selected
        : sections.firstOrNull?.id;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: kSectionListWidth,
          child: ListView(
            key: ValueKey('$id-sections'),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            children: [
              for (final s in sections)
                ListTile(
                  key: ValueKey('$id-section-${s.id}'),
                  leading: s.icon == null ? null : Icon(s.icon),
                  title: Text(s.title),
                  selected: s.id == shown,
                  textColor: s.destructive ? theme.colorScheme.error : null,
                  iconColor: s.destructive ? theme.colorScheme.error : null,
                  onTap: () => onSelect(s.id),
                ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  key: ValueKey('$id-shown'),
                  padding: AppSpacing.gutterAll,
                  child: FormColumn(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...header,
                        for (final s in sections)
                          _Hidden(
                            key: ValueKey('$id-body-${s.id}'),
                            hidden: s.id != shown,
                            child: s.child,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              ?footer,
            ],
          ),
        ),
      ],
    );
  }
}

/// [child] kept mounted; while [hidden] it is not painted, takes no room,
/// is no Tab stop and is not read.
class _Hidden extends StatelessWidget {
  const _Hidden({super.key, required this.hidden, required this.child});

  final bool hidden;
  final Widget child;

  @override
  Widget build(BuildContext context) => Offstage(
    offstage: hidden,
    child: ExcludeFocus(
      excluding: hidden,
      child: ExcludeSemantics(
        excluding: hidden,
        child: TickerMode(enabled: !hidden, child: child),
      ),
    ),
  );
}

/// The section the address names (`?section=<id>`); null when it names none
/// or the page is not under the app's router.
String? sectionInAddress(BuildContext context) {
  if (GoRouter.maybeOf(context) == null) return null;
  return GoRouterState.of(context).uri.queryParameters['section'];
}

/// Shows section [id]: the address names it, without a new history entry.
/// False when the page is not under the app's router (the caller keeps the
/// choice itself).
bool showSectionInAddress(BuildContext context, String id) {
  if (GoRouter.maybeOf(context) == null) return false;
  final uri = GoRouterState.of(context).uri;
  context.replace(
    uri
        .replace(queryParameters: {...uri.queryParameters, 'section': id})
        .toString(),
  );
  return true;
}

/// Asks the [SectionsBeside] host to show section [id] (a field of it needs
/// the reader: a validation problem).
class ShowSectionNotification extends Notification {
  ShowSectionNotification(this.id);
  final String id;
}

/// [SectionsBeside] whose shown section is the one the address names, or
/// the one last chosen where the page is not under the router; a field that
/// asks for the reader ([ShowSectionNotification]) brings its section.
class AddressedSections extends StatefulWidget {
  const AddressedSections({
    super.key,
    required this.id,
    required this.sections,
    this.header = const [],
    this.footer,
  });

  final String id;
  final List<BesideSection> sections;
  final List<Widget> header;
  final Widget? footer;

  @override
  State<AddressedSections> createState() => _AddressedSectionsState();
}

class _AddressedSectionsState extends State<AddressedSections> {
  String? _chosen;

  void _select(String id) {
    if (!showSectionInAddress(context, id)) setState(() => _chosen = id);
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ShowSectionNotification>(
        onNotification: (note) {
          _select(note.id);
          return true;
        },
        child: SectionsBeside(
          id: widget.id,
          sections: widget.sections,
          selected: sectionInAddress(context) ?? _chosen,
          onSelect: _select,
          header: widget.header,
          footer: widget.footer,
        ),
      );
}
