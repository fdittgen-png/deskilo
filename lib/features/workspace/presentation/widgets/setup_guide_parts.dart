// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The two plain pieces of the setup guide's page: a section's heading and the
// card shown when nothing is left to do.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// A section's heading, announced as one.
class SetupGuideHeader extends StatelessWidget {
  const SetupGuideHeader({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    ),
  );
}

/// The card shown when no step is left.
class SetupGuideAllDone extends StatelessWidget {
  const SetupGuideAllDone({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('setup-guide-all-done'),
    child: ListTile(
      leading: const Icon(Icons.celebration_outlined),
      title: Text(text),
    ),
  );
}
