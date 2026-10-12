// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2145 — how to add DesKilo to each assistant, with this server's own
// address already filled in: the steps for Claude and ChatGPT, the
// command for Claude Code, one-click links for Cursor and VS Code, and the
// configuration entry for any other client. Nothing here talks to the
// server; the sign-in and the workspace choice happen in the consent
// screen the assistant opens.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/links/link_launcher.dart';
import '../../../../core/mcp/mcp_endpoint.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';

/// The assistants the page explains, in the order the tabs show them.
enum _McpClientKind { claude, claudeCode, chatgpt, cursor, vscode, other }

String _mcpClientLabel(AppLocalizations l10n, _McpClientKind kind) =>
    switch (kind) {
      _McpClientKind.claude => l10n.mcpConnectTabClaude,
      _McpClientKind.claudeCode =>
        l10n.mcpConnectTabClaudeCode,
      _McpClientKind.chatgpt => l10n.mcpConnectTabChatgpt,
      _McpClientKind.cursor => l10n.mcpConnectTabCursor,
      _McpClientKind.vscode => l10n.mcpConnectTabVscode,
      _McpClientKind.other => l10n.mcpConnectTabOther,
    };

class McpClientTabs extends StatefulWidget {
  const McpClientTabs({super.key, required this.connector});

  /// This server's MCP address, the same for every assistant.
  final Uri connector;

  @override
  State<McpClientTabs> createState() => _McpClientTabsState();
}

class _McpClientTabsState extends State<McpClientTabs> {
  _McpClientKind _kind = _McpClientKind.claude;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final url = widget.connector;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.mcpConnectAddressLabel,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        McpCopyBlock(id: 'url', text: '$url'),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.mcpConnectWhich,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        // A Wrap, not a scrolling row: six short labels fit a phone in
        // two lines, and no chip is ever cut by the edge.
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final kind in _McpClientKind.values)
              ChoiceChip(
                key: ValueKey('mcp-connect-tab-${kind.name}'),
                label: Text(_mcpClientLabel(l10n, kind)),
                selected: _kind == kind,
                onSelected: (_) => setState(() => _kind = kind),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        KeyedSubtree(
          key: ValueKey('mcp-connect-panel-${_kind.name}'),
          child: switch (_kind) {
            _McpClientKind.claude => _claude(l10n),
            _McpClientKind.claudeCode => _claudeCode(l10n, url),
            _McpClientKind.chatgpt => _chatgpt(l10n),
            _McpClientKind.cursor => _cursor(l10n, url),
            _McpClientKind.vscode => _vscode(l10n, url),
            _McpClientKind.other => _other(l10n, url),
          },
        ),
      ],
    );
  }

  Widget _claude(AppLocalizations l10n) => _Panel(
    steps: [
      l10n.mcpConnectClaudeStep1,
      l10n.mcpConnectClaudeStep2,
      l10n.mcpConnectClaudeStep3,
    ],
    note:
        l10n.mcpConnectClaudeNote,
    action: _LinkButton(
      id: 'claude-open',
      label: l10n.mcpConnectClaudeOpen,
      uri: claudeConnectorsUri,
    ),
  );

  Widget _claudeCode(AppLocalizations l10n, Uri url) => _Panel(
    steps: [l10n.mcpConnectCodeStep1],
    block: McpCopyBlock(id: 'code-command', text: claudeCodeAddCommand(url)),
    after: [
      l10n.mcpConnectCodeStep2,
    ],
  );

  Widget _chatgpt(AppLocalizations l10n) => _Panel(
    steps: [
      l10n.mcpConnectChatgptStep1,
      l10n.mcpConnectChatgptStep2,
      l10n.mcpConnectChatgptStep3,
    ],
    note:
        l10n.mcpConnectChatgptNote,
  );

  Widget _cursor(AppLocalizations l10n, Uri url) => _Panel(
    action: _LinkButton(
      id: 'cursor-install',
      label: l10n.mcpConnectCursorInstall,
      uri: cursorInstallUri(url),
    ),
    steps: [
      l10n.mcpConnectCursorStep,
    ],
    block: McpCopyBlock(id: 'cursor-json', text: genericMcpConfig(url)),
  );

  Widget _vscode(AppLocalizations l10n, Uri url) => _Panel(
    action: _LinkButton(
      id: 'vscode-install',
      label: l10n.mcpConnectVscodeInstall,
      uri: vscodeInstallUri(url),
    ),
    steps: [
      l10n.mcpConnectVscodeStep,
    ],
  );

  Widget _other(AppLocalizations l10n, Uri url) => _Panel(
    steps: [
      l10n.mcpConnectOtherStep1,
    ],
    block: McpCopyBlock(id: 'other-json', text: genericMcpConfig(url)),
    after: [
      l10n.mcpConnectOtherStep2,
    ],
    afterBlock: McpCopyBlock(id: 'other-remote', text: mcpRemoteCommand(url)),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.steps,
    this.action,
    this.block,
    this.after = const [],
    this.afterBlock,
    this.note,
  });

  final List<String> steps;
  final Widget? action;
  final Widget? block;
  final List<String> after;
  final Widget? afterBlock;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final numbered = steps.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (action != null) ...[
          Align(alignment: Alignment.centerLeft, child: action),
          const SizedBox(height: AppSpacing.sm),
        ],
        for (final (i, s) in steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(numbered ? '${i + 1}. $s' : s),
          ),
        ?block,
        for (final s in after)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(s),
          ),
        ?afterBlock,
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(note!, style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    );
  }
}

class _LinkButton extends ConsumerWidget {
  const _LinkButton({required this.id, required this.label, required this.uri});

  final String id;
  final String label;
  final Uri uri;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FilledButton.tonalIcon(
    key: ValueKey('mcp-connect-$id'),
    icon: const Icon(Icons.open_in_new),
    label: Text(label),
    onPressed: () async {
      final l10n = context.l10n;
      final opened = await ref.read(linkLauncherProvider)(uri);
      if (!opened && context.mounted) {
        AppSnack.error(
          context,
          l10n.mcpConnectOpenFailed,
        );
      }
    },
  );
}

/// One value to paste somewhere else, shown whole and copied in one tap.
class McpCopyBlock extends StatelessWidget {
  const McpCopyBlock({super.key, required this.id, required this.text});

  final String id;
  final String text;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      padding: const EdgeInsets.only(left: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              key: ValueKey('mcp-connect-$id'),
              text,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
          IconButton(
            key: ValueKey('mcp-connect-copy-$id'),
            tooltip: l10n.commonCopy,
            icon: const Icon(Icons.copy_outlined),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                AppSnack.success(context, l10n.mcpConnectCopied);
              }
            },
          ),
        ],
      ),
    );
  }
}
