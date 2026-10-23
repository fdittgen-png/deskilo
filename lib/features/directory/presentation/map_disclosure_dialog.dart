// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/discovery_view.dart';

/// Said once per map provider before the map first loads: who draws it,
/// who places addresses, and what they receive. Answers true when the
/// person chooses the map; staying with the list, or dismissing, loads
/// nothing.
class MapDisclosureDialog extends StatelessWidget {
  const MapDisclosureDialog({
    super.key,
    required this.services,
    required this.remembered,
  });

  final MapServices services;

  /// Whether the choice is kept on this device (someone is signed in).
  final bool remembered;

  static Future<bool> ask(
    BuildContext context, {
    required MapServices services,
    required bool remembered,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) =>
            MapDisclosureDialog(services: services, remembered: remembered),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      key: const ValueKey('directory-map-disclosure'),
      title: Text(l.discoveryMapDisclosureTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.discoveryMapDisclosureBody(
                services.tilesHost,
                services.geocoderHost,
              ),
            ),
            if (remembered) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l.discoveryMapRemembered,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('directory-map-stay'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.discoveryMapStay),
        ),
        FilledButton(
          key: const ValueKey('directory-map-continue'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.discoveryMapContinue),
        ),
      ],
    );
  }
}
