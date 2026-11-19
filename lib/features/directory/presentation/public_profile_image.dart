// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../domain/public_workspace.dart';

/// A published picture, or a neutral initial. Neither is an identity check.
class PublicProfileImage extends StatelessWidget {
  const PublicProfileImage({
    super.key,
    required this.workspace,
    this.compact = false,
  });

  final PublicWorkspace workspace;
  final bool compact;

  String get _prefix => compact
      ? 'directory-picture-${workspace.source}/${workspace.id}'
      : 'public-workspace';

  @override
  Widget build(BuildContext context) {
    final image = Uri.tryParse(workspace.text('image_url'));
    if (image == null ||
        image.scheme != 'https' ||
        image.host.isEmpty ||
        image.userInfo.isNotEmpty) {
      return _initial(context);
    }
    return ClipRRect(
      borderRadius: AppRadius.xlAll,
      child: Image.network(
        image.toString(),
        key: ValueKey('$_prefix-image'),
        width: compact ? 80 : null,
        height: compact ? 80 : 160,
        fit: compact ? BoxFit.cover : BoxFit.contain,
        excludeFromSemantics: true,
        errorBuilder: (_, error, stack) => _initial(context),
      ),
    );
  }

  Widget _initial(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      key: ValueKey('$_prefix-initial'),
      width: compact ? 80 : null,
      height: compact ? 80 : 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: AppRadius.xlAll,
      ),
      child: ExcludeSemantics(
        child: Text(
          workspace.name.characters.firstOrNull?.toUpperCase() ?? '',
          style:
              (compact
                      ? theme.textTheme.headlineMedium
                      : theme.textTheme.displaySmall)
                  ?.copyWith(color: scheme.onPrimaryContainer),
        ),
      ),
    );
  }
}
