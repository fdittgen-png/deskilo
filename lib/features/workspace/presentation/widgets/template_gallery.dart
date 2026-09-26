// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/template_search.dart';
import '../../domain/template_capabilities.dart';
import '../../../../core/ui/inline_banner.dart';
import '../capability_labels.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/edge_fade_scroll.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/workspace_template.dart';

/// One titled group of templates in a [TemplateGallery].
class TemplateGallerySection {
  const TemplateGallerySection({
    required this.title,
    required this.templates,
    this.trailingFor,
  });

  final String title;
  final List<WorkspaceTemplate> templates;

  /// The card's action in this section (Apply, a menu), or null.
  final Widget? Function(WorkspaceTemplate template)? trailingFor;
}

/// #1280 S1 — the ONE template gallery, hosted by onboarding and by the
/// library, built for a hundred templates rather than three.
///
/// The picker was a `Wrap` of chips and the library a flat list; both built
/// every card up front and neither could be searched. Here:
///
///   * cards are built lazily (`ListView.builder`), so 100 templates cost
///     the handful on screen;
///   * a search field (debounced) matches name, description and tags, and
///     tag chips narrow further; the two compose;
///   * order is builtin → public → shared → private, then name;
///   * a card says what the template GIVES: its plan in numbers, and
///     whether settings travel with it.
///
/// It reads nothing itself: hosts pass the templates they were given by the
/// server, so the same widget serves a person with no workspace yet.
class TemplateGallery extends ConsumerStatefulWidget {
  const TemplateGallery({
    super.key,
    required this.sections,
    this.selectedId,
    this.onSelected,
    this.offerEmpty = false,
    this.padding = EdgeInsets.zero,
  });

  final List<TemplateGallerySection> sections;

  /// Selection mode (onboarding): the chosen template, null for the empty
  /// space when [offerEmpty] is set.
  final String? selectedId;
  final ValueChanged<String?>? onSelected;

  /// Adds the "Empty space" card after the templates (onboarding).
  final bool offerEmpty;

  /// Padding of the scrolling list (the library ends above its FAB).
  final EdgeInsets padding;

  /// How long typing settles before the list filters.
  static const debounce = Duration(milliseconds: 250);

  static int _visibilityRank(TemplateVisibility v) => switch (v) {
        TemplateVisibility.builtin => 0,
        TemplateVisibility.public => 1,
        TemplateVisibility.shared => 2,
        TemplateVisibility.private => 3,
        TemplateVisibility.unknown => 4,
      };

  /// Builtin → public → shared → private, then name.
  static List<WorkspaceTemplate> ordered(Iterable<WorkspaceTemplate> all) =>
      [...all]..sort((a, b) {
          final byRank = _visibilityRank(a.visibility)
              .compareTo(_visibilityRank(b.visibility));
          return byRank != 0
              ? byRank
              : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });

  /// Whether [t] matches the search [query] and carries every tag in
  /// [tags]. Both compose; an empty query and no tags match everything.
  static bool matches(
      WorkspaceTemplate t, String query, Set<String> tags) {
    if (!tags.every(t.tags.contains)) return false;
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return t.name.toLowerCase().contains(q) ||
        t.description.toLowerCase().contains(q) ||
        t.tags.any((tag) => tag.toLowerCase().contains(q));
  }

  @override
  ConsumerState<TemplateGallery> createState() => _TemplateGalleryState();
}

class _TemplateGalleryState extends ConsumerState<TemplateGallery> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  final Set<String> _tags = {};

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// #1659 — what the words asked for, and what the templates' settings
  /// answered. [_generation] discards an answer to an older query.
  TemplateSearchResult? _capability;
  String? _suggestion;
  int _generation = 0;
  bool _checking = false;

  void _onQuery(String value) {
    _debounce?.cancel();
    _debounce = Timer(TemplateGallery.debounce, () {
      if (!mounted) return;
      setState(() => _query = value);
      _searchCapabilities(value);
    });
  }

  Future<void> _searchCapabilities(String value) async {
    final generation = ++_generation;
    final vocabulary =
        CapabilityVocabulary(capabilityVocabularyLabels(AppLocalizations.of(context)));
    final parsed = vocabulary.parse(value);
    final unknown = parsed.freeWords.where((w) => !_anyTemplateText(w)).toList();
    setState(() {
      _suggestion = parsed.capabilities.isEmpty && unknown.isNotEmpty
          ? vocabulary.suggest(unknown.first)
          : null;
      _capability = null;
      _checking = parsed.capabilities.isNotEmpty;
    });
    if (parsed.capabilities.isEmpty) return;
    final result = await ref.read(templateSearchProvider).run(
          capabilities: parsed.capabilities,
          freeWords: parsed.freeWords,
          templates: [for (final s in widget.sections) ...s.templates],
        );
    if (!mounted || generation != _generation) return;
    setState(() {
      _capability = result;
      _checking = false;
    });
  }

  bool _anyTemplateText(String word) => widget.sections.any((s) => s.templates.any(
      (t) => normalizeSearch('${t.name} ${t.description} ${t.tags.join(' ')}')
          .contains(word)));

  /// Capability search answered: its matches decide; otherwise the words.
  bool _shows(WorkspaceTemplate t) {
    if (!t.tags.toSet().containsAll(_tags)) return false;
    final capability = _capability;
    if (_checking) return false;
    if (capability != null) {
      return !capability.unavailable && capability.matchedIds.contains(t.id);
    }
    return TemplateGallery.matches(t, _query, _tags);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final allTags = <String>{
      for (final s in widget.sections)
        for (final t in s.templates) ...t.tags,
    }.toList()
      ..sort();

    // Flattened rows: a header per non-empty section, then its cards.
    final rows = <Object>[];
    var anyTemplate = false;
    for (final section in widget.sections) {
      final shown = [
        for (final t in TemplateGallery.ordered(section.templates))
          if (_shows(t)) t,
      ];
      if (widget.sections.length > 1) rows.add(section);
      for (final t in shown) {
        rows.add((template: t, section: section));
      }
      anyTemplate = anyTemplate || shown.isNotEmpty;
    }
    if (widget.offerEmpty) rows.add(const _EmptySpace());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('template-search'),
          controller: _search,
          onChanged: _onQuery,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: l10n?.librarySearchHint ?? 'Search templates',
          ),
        ),
        ..._capabilityStatus(l10n),
        if (allTags.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          EdgeFadeScroll(
            child: Row(children: [
              for (final tag in allTags)
                Padding(padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: FilterChip(
                  key: ValueKey('template-tag-$tag'),
                  label: Text(tag),
                  selected: _tags.contains(tag),
                  onSelected: (on) => setState(
                      () => on ? _tags.add(tag) : _tags.remove(tag)),
                )),
            ]),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: !anyTemplate && !widget.offerEmpty
              ? EmptyState(
                  key: const ValueKey('template-gallery-empty'),
                  icon: Icons.grid_view_outlined,
                  title: l10n?.libraryEmpty ??
                      'Nothing here yet. Save this space as a template, or '
                          'wait for someone to share one with you.',
                )
              : ListView.builder(
                  key: const ValueKey('template-gallery'),
                  padding: widget.padding,
                  itemCount: rows.length,
                  itemBuilder: (context, i) => switch (rows[i]) {
                    final TemplateGallerySection s => Padding(
                        padding: const EdgeInsets.only(
                            top: AppSpacing.md, bottom: AppSpacing.sm),
                        child: Text(s.title, style: theme.textTheme.titleMedium),
                      ),
                    (
                      template: final WorkspaceTemplate t,
                      section: final TemplateGallerySection s
                    ) =>
                      TemplateCard(
                        template: t,
                        selected: widget.onSelected == null
                            ? null
                            : t.id == widget.selectedId,
                        onTap: widget.onSelected == null
                            ? null
                            : () => widget.onSelected!(t.id),
                        trailing: s.trailingFor?.call(t),
                      ),
                    _ => _EmptySpaceCard(
                        selected: widget.selectedId == null,
                        onTap: () => widget.onSelected?.call(null),
                      ),
                  },
                ),
        ),
      ],
    );
  }
}

class _EmptySpace {
  const _EmptySpace();
}

/// One template, as the gallery shows it: what it is for and what it gives.
class TemplateCard extends StatelessWidget {
  const TemplateCard({
    super.key,
    required this.template,
    this.selected,
    this.onTap,
    this.trailing,
  });

  final WorkspaceTemplate template;

  /// Null outside selection mode.
  final bool? selected;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = template.counts;
    final gives = [
      l10n?.libraryCounts(c.levels, c.desks, c.seats) ??
          '${c.levels} levels · ${c.desks} desks · ${c.seats} seats',
      if (template.carriesConfiguration)
        l10n?.libraryCarriesSettings ?? 'with its settings',
    ].join(' · ');
    final visibility = switch (template.visibility) {
      TemplateVisibility.builtin => l10n?.libraryVisibilityBuiltin ?? 'Built in',
      TemplateVisibility.private => l10n?.libraryVisibilityPrivate ?? 'Only me',
      TemplateVisibility.shared =>
        l10n?.libraryVisibilityShared ?? 'People I invite',
      TemplateVisibility.public =>
        l10n?.libraryVisibilityPublic ?? 'Everyone (the library)',
      TemplateVisibility.unknown => '',
    };
    final lines = [
      gives,
      if (template.description.isNotEmpty) template.description,
      [
        if (template.tags.isNotEmpty) template.tags.join(', '),
        if (visibility.isNotEmpty) visibility,
      ].join(' · '),
    ];
    final isSelected = selected ?? false;
    return Card(
      // The selection keys stay the ones onboarding tests pin; the
      // library's row key stays the library's.
      key: ValueKey(selected == null
          ? 'library-template-${template.key}'
          : 'template-${template.key}'),
      color: isSelected
          ? Theme.of(context).colorScheme.secondaryContainer
          : null,
      child: ListTile(
        leading: Icon(isSelected ? Icons.check : Icons.grid_view_outlined),
        title: Text(template.name),
        subtitle: Text(lines.where((l) => l.isNotEmpty).join('\n')),
        isThreeLine: lines.where((l) => l.isNotEmpty).length > 2,
        selected: isSelected,
        onTap: onTap,
        trailing: trailing,
      ),
    );
  }
}

class _EmptySpaceCard extends StatelessWidget {
  const _EmptySpaceCard({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      key: const ValueKey('template-empty'),
      color:
          selected ? Theme.of(context).colorScheme.secondaryContainer : null,
      child: ListTile(
        leading: Icon(selected ? Icons.check : Icons.crop_square_outlined),
        title: Text(l10n?.onboardingStartEmpty ?? 'Empty space'),
        subtitle: Text(l10n?.onboardingStartEmptyDesc ??
            'Draw your own plan from a blank canvas.'),
        selected: selected,
        onTap: onTap,
      ),
    );
  }
}

extension on _TemplateGalleryState {
  /// What the search understood, or why it could not answer.
  List<Widget> _capabilityStatus(AppLocalizations? l10n) {
    final capability = _capability;
    final suggestion = _suggestion;
    return [
      if (capability != null && !capability.unavailable)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Text(
            key: const ValueKey('template-search-capabilities'),
            l10n?.librarySearchCapabilities(capability.capabilities
                    .map((id) => capabilityLabel(l10n, id))
                    .join(', ')) ??
                'Set up for: ${capability.capabilities.join(', ')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      if (capability != null && capability.unavailable)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: InlineBanner(
            key: const ValueKey('template-search-unavailable'),
            icon: Icons.cloud_off_outlined,
            text: l10n?.librarySearchUnavailable ??
                'The templates\' settings could not be checked, so none is '
                    'shown as matching. Try again.',
          ),
        ),
      if (suggestion != null)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const ValueKey('template-search-suggestion'),
            onPressed: () {
              _search.text = suggestion;
              _onQuery(suggestion);
            },
            child: Text(l10n?.librarySearchSuggestion(suggestion) ??
                'Did you mean "$suggestion"?'),
          ),
        ),
    ];
  }
}
