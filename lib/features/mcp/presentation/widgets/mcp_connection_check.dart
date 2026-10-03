// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2145 — "did it work?" answered from the server's own record: the
// person's assistant usage (#1630, counts and the last call per assistant,
// never the content). Testing remembers the latest call it knows, asks the
// person to make their assistant call DesKilo, and polls until a newer
// call appears or it gives up and says what to check. Nothing is sent to
// the assistant from here.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/mcp_usage.dart';
import '../../providers/mcp_providers.dart';
import 'mcp_client_tabs.dart';

enum _Phase { idle, waiting, reached, timedOut }

/// The most recent call among [usage], or null when none was made.
McpClientUsage? latestMcpCall(List<McpClientUsage> usage) {
  McpClientUsage? latest;
  for (final u in usage) {
    final at = u.lastUsedAt;
    if (at == null) continue;
    if (latest == null || at.isAfter(latest.lastUsedAt!)) latest = u;
  }
  return latest;
}

class McpConnectionTest extends ConsumerStatefulWidget {
  const McpConnectionTest({
    super.key,
    this.pollEvery = const Duration(seconds: 5),
    this.maxPolls = 36,
  });

  final Duration pollEvery;
  final int maxPolls;

  @override
  ConsumerState<McpConnectionTest> createState() => _McpConnectionTestState();
}

class _McpConnectionTestState extends ConsumerState<McpConnectionTest> {
  _Phase _phase = _Phase.idle;
  DateTime? _baseline;
  McpClientUsage? _reached;
  Timer? _timer;
  int _polls = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    _timer?.cancel();
    final now = await _read();
    if (!mounted) return;
    setState(() {
      _baseline = now == null ? null : latestMcpCall(now)?.lastUsedAt;
      _phase = _Phase.waiting;
      _polls = 0;
      _reached = null;
    });
    _timer = Timer.periodic(widget.pollEvery, (_) => _poll());
  }

  Future<List<McpClientUsage>?> _read() async {
    ref.invalidate(myMcpUsageProvider);
    try {
      return await ref.read(myMcpUsageProvider.future);
    } catch (e, st) {
      // A failed read is one missed poll, not the end of the test.
      TraceLogger.instance.warn(
        'mcp',
        'connection test read failed',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  Future<void> _poll() async {
    _polls++;
    final usage = await _read();
    if (!mounted || _phase != _Phase.waiting) return;
    final latest = usage == null ? null : latestMcpCall(usage);
    final at = latest?.lastUsedAt;
    if (at != null && (_baseline == null || at.isAfter(_baseline!))) {
      _timer?.cancel();
      setState(() {
        _phase = _Phase.reached;
        _reached = latest;
      });
    } else if (_polls >= widget.maxPolls) {
      _timer?.cancel();
      setState(() => _phase = _Phase.timedOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final format = ref.watch(appFormatProvider);
    final last = latestMcpCall(ref.watch(myMcpUsageProvider).value ?? const []);
    String when(McpClientUsage u) => format.dateTime(u.lastUsedAt!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (last != null && _phase != _Phase.reached)
          Text(
            key: const ValueKey('mcp-connect-last-call'),
            l10n?.mcpConnectLastCall(last.clientName, when(last)) ??
                'Last call: ${last.clientName}, ${when(last)}.',
          ),
        switch (_phase) {
          _Phase.idle => const SizedBox.shrink(),
          _Phase.waiting => Column(
            key: const ValueKey('mcp-connect-test-waiting'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.sm),
              // A still icon, not a spinner: the wait can last minutes and
              // the page stays readable (and settles in tests).
              Row(
                children: [
                  const Icon(Icons.hourglass_top),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n?.mcpConnectTestWaiting ??
                          'Waiting for your assistant to call DesKilo. Ask it:',
                    ),
                  ),
                ],
              ),
              McpCopyBlock(
                id: 'test-prompt',
                text:
                    l10n?.mcpConnectTestPrompt ??
                    'Using DesKilo, what are my bookings this week?',
              ),
            ],
          ),
          _Phase.reached => InlineBanner(
            key: const ValueKey('mcp-connect-test-reached'),
            icon: Icons.check_circle_outline,
            severity: InlineBannerSeverity.info,
            text:
                l10n?.mcpConnectTestReached(
                  _reached!.clientName,
                  when(_reached!),
                ) ??
                'Connected: ${_reached!.clientName} reached DesKilo, '
                    '${when(_reached!)}.',
          ),
          _Phase.timedOut => InlineBanner(
            key: const ValueKey('mcp-connect-test-timeout'),
            icon: Icons.help_outline,
            severity: InlineBannerSeverity.error,
            text:
                l10n?.mcpConnectTestTimeout ??
                'No call arrived yet. Check that the connector is added, that '
                    'you approved this workspace, and that the steps above '
                    'are done; then test again.',
          ),
        },
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const ValueKey('mcp-connect-test'),
            icon: const Icon(Icons.network_check),
            label: Text(
              _phase == _Phase.idle
                  ? (l10n?.mcpConnectTest ?? 'Test the connection')
                  : (l10n?.mcpConnectTestAgain ?? 'Test again'),
            ),
            onPressed: _phase == _Phase.waiting ? null : _start,
          ),
        ),
      ],
    );
  }
}
