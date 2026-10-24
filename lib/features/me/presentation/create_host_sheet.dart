// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2562 C2c -- Create, under My spaces: the person chooses where the new
// space lives, among this server (when it hosts spaces) and the workspace
// installations their personal home enrolled. A host that is closed to new
// spaces or where the person cannot be verified is shown with its reason
// and cannot be chosen. A chosen host is checked again before anything
// opens: revoked, not accepting or unverified is refused with its reason;
// no connection yet leads through "Continue with Deskilo" (C1b's adopted
// session) and is checked once more. Only then does the existing onboarding
// run, on that host's own client.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/backend/backend_settings.dart';
import '../../../core/backend/connected_installations.dart';
import '../../../core/backend/identity_connect.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../directory/presentation/connect_with_identity_sheet.dart';
import '../../directory/presentation/connection_outcome_text.dart';
import '../../workspace/domain/workspace_host.dart';
import '../../workspace/providers/workspace_host_providers.dart';
import '../providers/me_providers.dart';

/// Answers the onboarding route to push, or null.
class CreateHostSheet extends ConsumerStatefulWidget {
  const CreateHostSheet({super.key});

  /// Create: straight to this server's onboarding when no host is
  /// enrolled, otherwise the choice; back from it, what my home says now.
  static Future<void> start(BuildContext context, WidgetRef ref) async {
    final hosts = ref.read(workspaceHostsProvider).value;
    final route = hosts != null && hosts.hosts.isEmpty
        ? '/onboarding'
        : await showAppSheet<String>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const CreateHostSheet(),
          );
    if (route == null || !context.mounted) return;
    await context.push(route);
    if (!context.mounted) return;
    ref
      ..invalidate(personalWorkspaceRefsProvider)
      ..invalidate(workspaceHostsProvider);
  }

  @override
  ConsumerState<CreateHostSheet> createState() => _CreateHostSheetState();
}

class _CreateHostSheetState extends ConsumerState<CreateHostSheet> {
  String? _busy;
  String? _message;

  static String stateText(AppLocalizations l10n, WorkspaceHostState state) =>
      switch (state) {
        WorkspaceHostState.available => l10n.createHostAvailable,
        WorkspaceHostState.notAccepting => l10n.createHostNotAccepting,
        WorkspaceHostState.unverified => l10n.createHostUnverified,
      };

  static String refusalText(AppLocalizations l10n, HostRefusal reason) =>
      switch (reason) {
        HostRefusal.revoked => l10n.createHostRevoked,
        HostRefusal.notAccepting => l10n.createHostNotAccepting,
        HostRefusal.unverified => l10n.createHostUnverified,
      };

  Future<void> _choose(WorkspaceHost host) async {
    if (_busy != null) return;
    final l10n = context.l10n;
    setState(() {
      _busy = host.installationId;
      _message = null;
    });
    String? message;
    try {
      var readiness = await ref.read(createOnHostProvider).prepare(host.installationId);
      if (readiness is HostNeedsConnection && mounted) {
        final connected = await ConnectWithIdentitySheet.show(
          context,
          SecondaryConnectIntent(
            target: BackendEndpoint(host.origin, host.publishableKey),
            workspaceId: '',
            action: SecondaryConnectAction.create,
          ),
        );
        // Once: a second "not connected" is said, never another browser.
        if (!connected || !mounted) return;
        readiness = await ref.read(createOnHostProvider).prepare(host.installationId);
      }
      if (!mounted) return;
      switch (readiness) {
        case HostReady():
          Navigator.of(context)
              .pop('/onboarding?host=${Uri.encodeQueryComponent(host.installationId)}');
          return;
        case HostRefused(:final reason):
          message = refusalText(l10n, reason);
          ref.invalidate(workspaceHostsProvider);
        case HostNeedsConnection():
          message = l10n.createHostUnverified;
      }
    } on ConnectionFailure catch (failure, st) {
      TraceLogger.instance.warn('me', 'creation host not checked',
          error: failure.reason, stackTrace: st);
      message = connectionFailureText(l10n, failure);
    } on Object catch (e, st) {
      // The fresh read of the hosts itself failed.
      TraceLogger.instance.warn('me', 'creation host not checked',
          error: e, stackTrace: st);
      message = l10n.createHostUnavailable;
    } finally {
      if (mounted) {
        setState(() {
          _busy = null;
          _message = message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hosts = ref.watch(workspaceHostsProvider);
    final here = ListTile(
      key: const ValueKey('create-host-here'),
      leading: const Icon(Icons.home_work_outlined),
      title: Text(l10n.createHostHere),
      subtitle: Text(l10n.createHostHereDetail),
      enabled: _busy == null,
      onTap: () => Navigator.of(context).pop('/onboarding'),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: AppSpacing.lgAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.createHostTitle,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            if (_message case final message?)
              Semantics(
                liveRegion: true,
                child: InlineBanner(
                  key: const ValueKey('create-host-refused'),
                  icon: Icons.block_outlined,
                  text: message,
                ),
              ),
            ...switch (hosts) {
              AsyncData(:final value) => [
                  if (value.hereHosts) here,
                  for (final host in value.hosts) _tile(l10n, host),
                ],
              AsyncError() => [
                  InlineBanner(
                    key: const ValueKey('create-host-unavailable'),
                    icon: Icons.cloud_off_outlined,
                    text: l10n.createHostUnavailable,
                    actionLabel: l10n.commonRetry,
                    onAction: () => ref.invalidate(workspaceHostsProvider),
                  ),
                  here,
                ],
              _ => [const LoadingView()],
            },
          ],
        ),
      ),
    );
  }

  Widget _tile(AppLocalizations l10n, WorkspaceHost host) {
    final available = host.state == WorkspaceHostState.available;
    return ListTile(
      key: ValueKey('create-host-${host.installationId}'),
      leading: const Icon(Icons.dns_outlined),
      title: Text(host.host),
      subtitle: Text(stateText(l10n, host.state)),
      enabled: available && _busy == null,
      onTap: available ? () => unawaited(_choose(host)) : null,
    );
  }
}
