// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3235 — `/demo`: the neutral public entry of the demonstration.
//
// One page for every visitor. It opens the same explanation the sign-in
// screen's button opens and, once the visitor agreed, the same visit; what
// differs is only the way out of it — a signed-in person goes back to their
// workspace, a signed-out one to sign-in. A signed-in person is never shown
// the sign-in form for a demo link, and a person already inside the demo is
// never given a second demo inside it.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_classes.dart' show kDefaultHome;
import '../../../features/auth/providers/auth_providers.dart';
import '../../../features/workspace/domain/workspace_feature.dart';
import '../../../features/workspace/providers/workspace_providers.dart';
import '../../l10n/context_l10n.dart';
import '../../theme/app_spacing.dart';
import '../demo_link.dart';
import 'demo_entry_sheet.dart';
import 'demo_workspace.dart';

class DemoEntryScreen extends ConsumerStatefulWidget {
  const DemoEntryScreen({super.key, required this.link});

  /// Where the demo starts once the visitor agreed.
  final DemoLink link;

  static const Key openKey = Key('demo-entry-open');
  static const Key leaveKey = Key('demo-entry-leave');

  @override
  ConsumerState<DemoEntryScreen> createState() => _DemoEntryScreenState();
}

class _DemoEntryScreenState extends ConsumerState<DemoEntryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (DemoEnvironment.maybeOf(context) != null) {
        // Already exploring: the entry has nothing to offer.
        context.go(kDefaultHome);
        return;
      }
      unawaited(_offer());
    });
  }

  Future<bool> _offer() =>
      offerDemoEntry(context, ref, link: widget.link);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final signedIn = ref.watch(authStateProvider).value != null;
    final available = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.demoMode);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.gutterAll,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.demoEntryTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    !available
                        ? l10n.demoEntryUnavailable
                        : signedIn
                            ? l10n.demoEntryBodySignedIn
                            : l10n.demoEntryBody,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      if (available)
                        FilledButton(
                          key: DemoEntryScreen.openKey,
                          onPressed: _offer,
                          child: Text(l10n.demoEntryAction),
                        ),
                      TextButton(
                        key: DemoEntryScreen.leaveKey,
                        onPressed: () => context.go(kDefaultHome),
                        child: Text(
                          signedIn ? l10n.demoEntryBack : l10n.demoEntrySignIn,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
