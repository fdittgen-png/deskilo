// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../domain/public_workspace.dart';
import '../providers/saved_places_providers.dart';

/// Bookmark / Saved on this device: the private, device-local mark on a
/// public page. It is not the membership heart, not a rating, not a
/// request. The button exists only while someone is signed in at the
/// personal home: an anonymous visitor has no list to save into.
class SavedPlaceButton extends ConsumerWidget {
  const SavedPlaceButton({
    super.key,
    required this.workspace,
    this.keyPrefix = 'directory-bookmark-',
    this.iconOnly = false,
    this.enabled = true,
  });

  final PublicWorkspace workspace;

  /// The control's key is `<keyPrefix><source>/<id>`: a list row and the
  /// page it opens carry different prefixes.
  final String keyPrefix;

  /// An icon with a tooltip (an app bar) instead of a labelled button.
  final bool iconOnly;

  /// Disabled on a preview, where there is nothing to save.
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(savedPlacesNamespaceProvider).value == null) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    final saved = ref
            .watch(savedPlacesProvider)
            .value
            ?.any((p) => p.matches(workspace)) ??
        false;
    final key = ValueKey('$keyPrefix${workspace.source}/${workspace.id}');
    final icon = Icon(saved ? Icons.bookmark : Icons.bookmark_outline);
    final onPressed = enabled
        ? () => unawaited(
              ref.read(savedPlacesProvider.notifier).toggle(workspace),
            )
        : null;
    if (iconOnly) {
      return IconButton(
        key: key,
        tooltip: saved ? l.discoveryRemoveBookmark : l.discoveryBookmark,
        isSelected: saved,
        icon: icon,
        onPressed: onPressed,
      );
    }
    return TextButton.icon(
      key: key,
      icon: icon,
      label: Text(saved ? l.discoverySaved : l.discoveryBookmark),
      onPressed: onPressed,
    );
  }
}
