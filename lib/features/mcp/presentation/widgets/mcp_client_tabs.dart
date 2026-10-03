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

import '../../../../core/links/link_launcher.dart';
import '../../../../core/mcp/mcp_endpoint.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';

/// The assistants the page explains, in the order the tabs show them.
enum McpClientKind { claude, claudeCode, chatgpt, cursor, vscode, other }

String mcpClientLabel(AppLocalizations? l10n, McpClientKind kind) =>
    switch (kind) {
      McpClientKind.claude => l10n?.mcpConnectTabClaude ?? 'Claude',
      McpClientKind.claudeCode =>
        l10n?.mcpConnectTabClaudeCode ?? 'Claude Code',
      McpClientKind.chatgpt => l10n?.mcpConnectTabChatgpt ?? 'ChatGPT',
      McpClientKind.cursor => l10n?.mcpConnectTabCursor ?? 'Cursor',
      McpClientKind.vscode => l10n?.mcpConnectTabVscode ?? 'VS Code',
      McpClientKind.other => l10n?.mcpConnectTabOther ?? 'Other',
    };

class McpClientTabs extends StatefulWidget {
  const McpClientTabs({super.key, required this.connector});

  /// This server's MCP address, the same for every assistant.
  final Uri connector;

  @override
  State<McpClientTabs> createState() => _McpClientTabsState();
}

class _McpClientTabsState extends State<McpClientTabs> {
  McpClientKind _kind = McpClientKind.claude;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final url = widget.connector;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n?.mcpConnectAddressLabel ?? 'Your DesKilo address for assistants',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        McpCopyBlock(id: 'url', text: '$url'),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n?.mcpConnectWhich ?? 'Which assistant do you use?',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        // A Wrap, not a scrolling row: six short labels fit a phone in
        // two lines, and no chip is ever cut by the edge.
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final kind in McpClientKind.values)
              ChoiceChip(
                key: ValueKey('mcp-connect-tab-${kind.name}'),
                label: Text(mcpClientLabel(l10n, kind)),
                selected: _kind == kind,
                onSelected: (_) => setState(() => _kind = kind),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        KeyedSubtree(
          key: ValueKey('mcp-connect-panel-${_kind.name}'),
          child: switch (_kind) {
            McpClientKind.claude => _claude(l10n),
            McpClientKind.claudeCode => _claudeCode(l10n, url),
            McpClientKind.chatgpt => _chatgpt(l10n),
            McpClientKind.cursor => _cursor(l10n, url),
            McpClientKind.vscode => _vscode(l10n, url),
            McpClientKind.other => _other(l10n, url),
          },
        ),
      ],
    );
  }

  Widget _claude(AppLocalizations? l10n) => _Panel(
    steps: [
      l10n?.mcpConnectClaudeStep1 ?? 'In Claude, open Settings → Connectors.',
      l10n?.mcpConnectClaudeStep2 ??
          'Choose "Add custom connector", name it DesKilo and paste the '
              'address above.',
      l10n?.mcpConnectClaudeStep3 ??
          'Choose Connect, sign in with Google and pick this workspace and '
              'what Claude may do there.',
    ],
    note:
        l10n?.mcpConnectClaudeNote ??
        'Claude on the web, Claude Desktop and the Claude mobile app share '
            'the same connectors. On a Team or Enterprise plan, an owner of '
            'the Claude organisation adds the connector first.',
    action: _LinkButton(
      id: 'claude-open',
      label: l10n?.mcpConnectClaudeOpen ?? 'Open Claude connectors',
      uri: claudeConnectorsUri,
    ),
  );

  Widget _claudeCode(AppLocalizations? l10n, Uri url) => _Panel(
    steps: [l10n?.mcpConnectCodeStep1 ?? 'Run this in a terminal:'],
    block: McpCopyBlock(id: 'code-command', text: claudeCodeAddCommand(url)),
    after: [
      l10n?.mcpConnectCodeStep2 ??
          'In Claude Code, type /mcp, choose deskilo and then Authenticate. '
              'A browser opens to sign in and pick this workspace.',
    ],
  );

  Widget _chatgpt(AppLocalizations? l10n) => _Panel(
    steps: [
      l10n?.mcpConnectChatgptStep1 ??
          'In ChatGPT, turn on developer mode: Settings → Apps → Advanced '
              'settings.',
      l10n?.mcpConnectChatgptStep2 ??
          'Create an app named DesKilo, paste the address above and choose '
              'OAuth as the authentication.',
      l10n?.mcpConnectChatgptStep3 ??
          'Sign in with Google and pick this workspace and what ChatGPT may '
              'do there.',
    ],
    note:
        l10n?.mcpConnectChatgptNote ??
        'Developer mode needs a paid ChatGPT plan (Plus, Pro, Business, '
            'Enterprise or Edu).',
  );

  Widget _cursor(AppLocalizations? l10n, Uri url) => _Panel(
    action: _LinkButton(
      id: 'cursor-install',
      label: l10n?.mcpConnectCursorInstall ?? 'Add to Cursor',
      uri: cursorInstallUri(url),
    ),
    steps: [
      l10n?.mcpConnectCursorStep ??
          'Cursor asks to install DesKilo, then opens a browser to sign in '
              'and pick this workspace. Without the button, add this to '
              '~/.cursor/mcp.json:',
    ],
    block: McpCopyBlock(id: 'cursor-json', text: genericMcpConfig(url)),
  );

  Widget _vscode(AppLocalizations? l10n, Uri url) => _Panel(
    action: _LinkButton(
      id: 'vscode-install',
      label: l10n?.mcpConnectVscodeInstall ?? 'Add to VS Code',
      uri: vscodeInstallUri(url),
    ),
    steps: [
      l10n?.mcpConnectVscodeStep ??
          'VS Code asks to install DesKilo. Start it from the MCP servers '
              'list; a browser opens to sign in and pick this workspace.',
    ],
  );

  Widget _other(AppLocalizations? l10n, Uri url) => _Panel(
    steps: [
      l10n?.mcpConnectOtherStep1 ??
          'Most clients read a JSON file of servers. Add this entry; the '
              'client opens a browser to sign in the first time.',
    ],
    block: McpCopyBlock(id: 'other-json', text: genericMcpConfig(url)),
    after: [
      l10n?.mcpConnectOtherStep2 ??
          'A client that only starts local programs can reach DesKilo '
              'through mcp-remote (needs Node.js):',
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
      final l10n = AppLocalizations.of(context);
      final opened = await ref.read(linkLauncherProvider)(uri);
      if (!opened && context.mounted) {
        AppSnack.error(
          context,
          l10n?.mcpConnectOpenFailed ??
              'The app could not be opened from here. Use the steps below '
                  'instead.',
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
    final l10n = AppLocalizations.of(context);
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
            tooltip: l10n?.commonCopy ?? 'Copy',
            icon: const Icon(Icons.copy_outlined),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                AppSnack.success(context, l10n?.mcpConnectCopied ?? 'Copied.');
              }
            },
          ),
        ],
      ),
    );
  }
}
