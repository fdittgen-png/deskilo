// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/motion/motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/workspace_process.dart';
import '../feature_names.dart';
import '../process_names.dart';

/// What the person chose in the browser: a capability id and whether it
/// is required (true) or only preferred (false).
typedef CapabilityChoice = ({String id, bool required});

/// #1660 — "Browse capabilities": every feature, grouped by the process
/// and subprocess it belongs to, each with Require and Prefer. Choosing
/// adds a chip to the search and changes nothing else; closing chooses
/// nothing. With reduced motion the sheet appears and leaves at once.
Future<CapabilityChoice?> showCapabilityBrowser(BuildContext context) =>
    showModalBottomSheet<CapabilityChoice>(
      context: context,
      sheetAnimationStyle: MotionSettings.enabledOf(context)
          ? null
          : AnimationStyle.noAnimation,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          builder: (context, controller) => ListView(
            key: const ValueKey('capability-browser'),
            controller: controller,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            children: [
              Text(
                l10n?.capabilityBrowserTitle ?? 'Browse capabilities',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final process in workspaceProcesses)
                ExpansionTile(
                  key: ValueKey('capability-process-${process.key}'),
                  title: Text(processLabel(l10n, process.key)),
                  children: [
                    for (final sub in process.subprocesses) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          processLabel(l10n, sub.key),
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      for (final f in sub.capabilities)
                        ListTile(
                          key: ValueKey('capability-row-${f.name}'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(featureName(l10n, f)),
                          trailing: Wrap(
                            spacing: AppSpacing.xs,
                            children: [
                              TextButton(
                                key: ValueKey('capability-prefer-${f.name}'),
                                onPressed: () => Navigator.of(context).pop((
                                  id: 'feature.${f.name}',
                                  required: false,
                                )),
                                child: Text(
                                  l10n?.capabilityBrowserPrefer ?? 'Prefer',
                                ),
                              ),
                              FilledButton.tonal(
                                key: ValueKey('capability-require-${f.name}'),
                                onPressed: () => Navigator.of(context).pop((
                                  id: 'feature.${f.name}',
                                  required: true,
                                )),
                                child: Text(
                                  l10n?.capabilityBrowserRequire ?? 'Require',
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
            ],
          ),
        );
      },
    );
