// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2562 C2c -- the onboarding route's guard of WHERE a creation runs.
//
// `/onboarding?host=<installation>` builds the onboarding only while that
// enrolled host is held (chosen and checked under My spaces); otherwise it
// says the choice is gone, creates nothing anywhere and leads back to
// choosing. Leaving it gives the host back. The onboarding of this server
// (no `host`) lets go of a host held earlier, so a creation there never
// runs on the chosen host, and a hosted one never on this server.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../providers/workspace_host_providers.dart';

class OnboardingHostGate extends ConsumerStatefulWidget {
  const OnboardingHostGate({super.key, required this.host, required this.builder});

  /// The enrolled installation chosen, or null for this server.
  final String? host;

  /// The onboarding, given the chosen host's name (null for this server).
  final Widget Function(String? hostLabel) builder;

  @override
  ConsumerState<OnboardingHostGate> createState() => _OnboardingHostGateState();
}

class _OnboardingHostGateState extends ConsumerState<OnboardingHostGate> {
  late final CreationHost _creation;
  CreationHostLease? _lease;

  @override
  void initState() {
    super.initState();
    _creation = ref.read(creationHostProvider.notifier);
    if (widget.host == null && _creation.isHeld()) {
      // Not while the tree builds: the providers that read it rebuild.
      WidgetsBinding.instance.addPostFrameCallback((_) => _creation.clear());
    }
  }

  @override
  void dispose() {
    final lease = _lease;
    if (lease != null) unawaited(Future.microtask(() => _creation.drop(lease)));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final host = widget.host;
    if (host == null) return widget.builder(null);
    final lease = ref.watch(creationHostProvider);
    if (lease == null || lease.host.installationId != host) return const _HostLost();
    _lease = lease;
    return widget.builder(lease.host.host);
  }
}

class _HostLost extends StatelessWidget {
  const _HostLost();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.onboardingTitle)),
      body: Center(
        child: Padding(
          padding: AppSpacing.xlAll,
          child: InlineBanner(
            key: const ValueKey('onboarding-host-lost'),
            icon: Icons.dns_outlined,
            text: l10n.createHostLost,
            actionLabel: l10n.createHostChooseAgain,
            onAction: () => Navigator.of(context).canPop()
                ? Navigator.of(context).pop()
                : GoRouter.of(context).go('/me'),
          ),
        ),
      ),
    );
  }
}
