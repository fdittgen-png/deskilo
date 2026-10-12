// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1886 — the workbench's "use it offline" card: shown only in a browser,
// it says where the offline copy stands as the browser reports it, and
// lets the person keep it or stop keeping it.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import 'offline_tool.dart';

class OfflineToolCard extends ConsumerStatefulWidget {
  const OfflineToolCard({super.key});

  @override
  ConsumerState<OfflineToolCard> createState() => _OfflineToolCardState();
}

class _OfflineToolCardState extends ConsumerState<OfflineToolCard> {
  OfflineToolState? _state;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(offlineToolProvider).state().then((s) {
      if (mounted) setState(() => _state = s);
    }));
  }

  Future<void> _run(Future<OfflineToolState> Function() action) async {
    setState(() => _busy = true);
    final next = await action();
    if (mounted) {
      setState(() {
        _state = next;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (state == null || state == OfflineToolState.notNeeded) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final tool = ref.read(offlineToolProvider);
    final text = switch (state) {
      OfflineToolState.ready =>
        l10n.taskWorkbenchOfflineReady,
      OfflineToolState.off =>
        l10n.taskWorkbenchOfflineOff,
      OfflineToolState.unsupported =>
        l10n.taskWorkbenchOfflineUnsupported,
      OfflineToolState.failed =>
        l10n.taskWorkbenchOfflineFailed,
      OfflineToolState.notNeeded => '',
    };
    return Card(
      key: const ValueKey('workbench-offline'),
      child: Padding(
        padding: AppSpacing.lgAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.taskWorkbenchOfflineTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(text, key: const ValueKey('workbench-offline-state')),
            const SizedBox(height: AppSpacing.sm),
            if (_busy) const LinearProgressIndicator(),
            if (state == OfflineToolState.ready)
              TextButton(
                key: const ValueKey('workbench-offline-forget'),
                onPressed: _busy ? null : () => _run(tool.forget),
                child: Text(
                  l10n.taskWorkbenchOfflineForget,
                ),
              )
            else if (state != OfflineToolState.unsupported)
              OutlinedButton(
                key: const ValueKey('workbench-offline-keep'),
                onPressed: _busy ? null : () => _run(tool.keep),
                child: Text(
                  l10n.taskWorkbenchOfflineKeep,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
