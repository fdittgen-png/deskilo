// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2459 — beside the demo, the public page that says what DesKilo is.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/workspace/domain/workspace_feature.dart';
import '../../../features/workspace/providers/workspace_providers.dart';
import '../../l10n/context_l10n.dart';
import '../../links/link_launcher.dart';

/// Opens the welcome page for a visitor who reached the sign-in form
/// without passing it. It is one of the visitor's offers with the demo,
/// so it sits behind the same flag: at the sign-in screen no workspace is
/// chosen, and both resolve to the registry default. It closes the form's
/// footer of ways in, below everything the form's tests tap.
class WelcomeLinkButton extends ConsumerWidget {
  const WelcomeLinkButton({super.key});

  static const Key buttonKey = Key('welcome-link');

  /// The landing page of the project's own site, opened at its top.
  static final Uri url = Uri.parse('https://deskilo.org/welcome/#top');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.demoMode)) {
      return const SizedBox.shrink();
    }
    return TextButton.icon(
      key: buttonKey,
      icon: const Icon(Icons.info_outline),
      label: Text(context.l10n.welcomeLinkAction),
      onPressed: () => ref.read(linkLauncherProvider)(url),
    );
  }
}
