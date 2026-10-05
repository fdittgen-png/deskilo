// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/public_workspace.dart';
import 'workspace_feedback.dart';

/// The workspaces of the map as cards to swipe through, under the map.
///
/// The card in front IS the selection: swiping moves the selection (and the
/// map glides to it), choosing a pin on the map brings its card to the
/// front. Tapping the card opens the workspace.
class DirectoryCarousel extends StatefulWidget {
  const DirectoryCarousel({
    super.key,
    required this.workspaces,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
  });

  final List<PublicWorkspace> workspaces;
  final PublicWorkspace? selected;
  final ValueChanged<PublicWorkspace> onSelect;
  final ValueChanged<PublicWorkspace> onOpen;

  @override
  State<DirectoryCarousel> createState() => _DirectoryCarouselState();
}

class _DirectoryCarouselState extends State<DirectoryCarousel> {
  late final PageController _pages = PageController(
    viewportFraction: 0.88,
    initialPage: _indexOf(widget.selected),
  );

  int _indexOf(PublicWorkspace? w) {
    if (w == null) return 0;
    final i = widget.workspaces
        .indexWhere((x) => x.id == w.id && x.source == w.source);
    return i < 0 ? 0 : i;
  }

  @override
  void didUpdateWidget(DirectoryCarousel old) {
    super.didUpdateWidget(old);
    final target = _indexOf(widget.selected);
    if (widget.selected != null &&
        _pages.hasClients &&
        (_pages.page?.round() ?? target) != target) {
      _pages.animateToPage(target,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.workspaces.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return SizedBox(
      height: 112,
      child: PageView.builder(
        key: const ValueKey('directory-carousel'),
        controller: _pages,
        itemCount: widget.workspaces.length,
        onPageChanged: (i) => widget.onSelect(widget.workspaces[i]),
        itemBuilder: (context, i) {
          final w = widget.workspaces[i];
          final selected = widget.selected != null &&
              widget.selected!.id == w.id &&
              widget.selected!.source == w.source;
          return Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
            child: Material(
              color: theme.colorScheme.surface,
              elevation: selected ? 6 : 2,
              borderRadius: AppRadius.lgAll,
              child: InkWell(
                key: ValueKey('directory-card-${w.source}/${w.id}'),
                borderRadius: AppRadius.lgAll,
                onTap: () => widget.onOpen(w),
                child: Padding(
                  padding: AppSpacing.mdAll,
                  child: Row(children: [
                    CircleAvatar(
                      backgroundColor: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primaryContainer,
                      foregroundColor: selected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onPrimaryContainer,
                      child: Text(w.name.isEmpty ? '?' : w.name[0].toUpperCase()),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(w.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(w.text('address'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    WorkspaceFeedback(workspace: w),
                    Icon(Icons.chevron_right,
                        color: theme.colorScheme.onSurfaceVariant),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
