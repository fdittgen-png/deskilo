// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4363 (G14) -- the tags of one item or one place: the active ones, "Read a tag" (the phone's NFC) to bind one,
// and a way to retire one with a reason. Binding keeps ONE request id per tag read, so a retry after a lost
// answer, or the same chip read again, answers once and never binds a second tag. A refusal is said in words and
// changes nothing. It shows only where the business uses tags and the person may manage the stock.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/help/help_dot.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/stock_config.dart';
import '../domain/stock_tags.dart';
import '../providers/stock_providers.dart';
import 'stock_nfc_button.dart';
import 'stock_tag_text.dart';

/// Opens the tags of [owner]; [name] is what the title names.
Future<void> showStockTagsDialog(BuildContext context, {required String workspaceId, required TagOwner owner, required String name}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _TagsDialog(workspaceId: workspaceId, owner: owner, name: name),
    );

class _TagsDialog extends ConsumerStatefulWidget {
  const _TagsDialog({required this.workspaceId, required this.owner, required this.name});

  final String workspaceId;
  final TagOwner owner;
  final String name;

  @override
  ConsumerState<_TagsDialog> createState() => _TagsDialogState();
}

class _TagsDialogState extends ConsumerState<_TagsDialog> {
  late Future<List<StockTag>> _tags = _read();

  /// One request id per chip read in this dialog: the same chip again is the same request.
  final Map<String, String> _requests = {};
  String? _problem;

  /// What the last command did, said here and not in a snack (the dialog is where the eyes are).
  String? _status;

  Future<List<StockTag>> _read() => ref.read(stockTagsStoreProvider).tags(widget.workspaceId, widget.owner);

  void _reload() => setState(() => _tags = _read());

  Future<void> _bind(String uid) async {
    final l10n = context.l10n;
    final code = uid.toUpperCase();
    try {
      final answer = await ref.read(stockTagsStoreProvider).bind(
        widget.workspaceId,
        requestId: _requests.putIfAbsent(code, newRequestId),
        code: code,
        owner: widget.owner,
      );
      // answered: the next read of the same chip is a new request (and says "already bound here")
      _requests.remove(code);
      if (!mounted) return;
      setState(() {
        _problem = null;
        _status = answer.replayed ? l10n.stockTagsAlready(answer.tag.code) : l10n.stockTagsBound(answer.tag.code);
      });
      _reload();
    } on Object catch (e, st) {
      TraceLogger.instance.warn('stock', 'a tag was not bound: $e', stackTrace: st);
      // a refusal is an answer: a new attempt is a new request; an unknown outcome (the connection) keeps its
      // request id, so the retry answers once
      if (e is StockConfigFailure) _requests.remove(code);
      if (mounted) setState(() => _problem = stockTagProblem(l10n, e));
    }
  }

  Future<void> _retire(StockTag tag, String reason) async {
    final l10n = context.l10n;
    try {
      await ref.read(stockTagsStoreProvider).retire(widget.workspaceId, requestId: newRequestId(), code: tag.code, reason: reason);
      if (!mounted) return;
      setState(() {
        _problem = null;
        _status = l10n.stockTagsRetired(tag.code);
      });
      _reload();
    } on Object catch (e, st) {
      TraceLogger.instance.warn('stock', 'a tag was not retired: $e', stackTrace: st);
      if (mounted) setState(() => _problem = stockTagProblem(l10n, e));
    }
  }

  String _reasonLabel(AppLocalizations l10n, String reason) => switch (reason) {
    'lost' => l10n.stockTagReasonLost,
    'damaged' => l10n.stockTagReasonDamaged,
    _ => l10n.stockTagReasonReplaced,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      key: const ValueKey('stock-tags-dialog'),
      title: Row(
        children: [
          Expanded(child: Text(l10n.stockTagsTitle(widget.name))),
          HelpDot(l10n.stockTagsOpen, anchor: HelpAnchor.moneyStockNfc),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: FutureBuilder<List<StockTag>>(
          future: _tags,
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text(l10n.stockTagsFailed, key: const ValueKey('stock-tags-failed'));
            final tags = snapshot.data;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tags != null && tags.isEmpty) Text(l10n.stockTagsNone, key: const ValueKey('stock-tags-none')),
                if (tags != null && tags.isNotEmpty && tags.every((t) => t.isUhf))
                  Text(l10n.stockTagsUhfOnly, key: const ValueKey('stock-tags-uhf-only')),
                for (final t in tags ?? const <StockTag>[])
                  ListTile(
                    key: ValueKey('stock-tag-${t.code}'),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(t.isUhf ? Icons.sensors : Icons.nfc),
                    title: Text(t.code),
                    subtitle: Text(t.isUhf ? l10n.stockTagKindUhf : l10n.stockTagKindNfc),
                    trailing: PopupMenuButton<String>(
                      key: ValueKey('stock-tag-retire-${t.code}'),
                      tooltip: l10n.stockTagsRetireWhy,
                      icon: const Icon(Icons.link_off),
                      onSelected: (reason) => _retire(t, reason),
                      itemBuilder: (_) => [
                        for (final reason in stockTagRetireReasons) PopupMenuItem(value: reason, child: Text(_reasonLabel(l10n, reason))),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                StockNfcButton(onUid: _bind),
                if (_status != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(_status!, key: const ValueKey('stock-tags-status')),
                ],
                if (_problem != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(_problem!, key: const ValueKey('stock-tags-problem'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            );
          },
        ),
      ),
      actions: [TextButton(key: const ValueKey('stock-tags-close'), onPressed: () => Navigator.of(context).pop(), child: Text(l10n.stockTagsClose))],
    );
  }
}
