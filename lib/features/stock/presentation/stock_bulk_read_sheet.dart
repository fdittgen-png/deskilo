// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4364 (G15) -- "Read many tags". A UHF reader in keyboard mode types every tag it sees, often the same one many
// times a second: this sheet collects them locally (each tag once, never more than the limit), shows the tally as the
// server resolves it (so many pieces of each item, the unknown tags apart), and freezes it when the reading is stopped.
// Nothing is sent to change anything until the person confirms; the confirm is the host's own command with one request
// id (a count, a move, a delivery), and the sheet only hands it what was read.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/help/help_dot.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/refusal_text.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/form_kit.dart';
import '../domain/stock_bulk_read.dart';
import '../providers/stock_providers.dart';

/// What the host does with a read when the person confirms: it returns the words of a problem, or null when done.
typedef BulkReadConfirm = Future<String?> Function(BulkResolution resolution, List<String> codes);

/// How long after the last tag the tally is asked again (the reader types a burst; one question follows it).
const _quiet = Duration(milliseconds: 600);

class StockBulkReadSheet extends ConsumerStatefulWidget {
  const StockBulkReadSheet({
    required this.workspaceId,
    required this.confirmLabel,
    required this.onConfirm,
    this.expected,
    this.quiet = _quiet,
    super.key,
  });

  final String workspaceId;
  final String confirmLabel;
  final BulkReadConfirm onConfirm;

  /// A delivery to compare with the read (expected, read, missing, extra). Null for a count: a counter sees only what
  /// was read, never what was expected.
  final List<ExpectedLine>? expected;

  final Duration quiet;

  @override
  ConsumerState<StockBulkReadSheet> createState() => _State();
}

class _State extends ConsumerState<StockBulkReadSheet> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  late final BulkReadSession _session;
  Timer? _timer;
  BulkResolution? _resolution;
  bool _resolving = false;
  bool _confirming = false;
  String? _problem;

  @override
  void initState() {
    super.initState();
    _session = BulkReadSession(limit: ref.read(stockTagReadMaxProvider));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _typed(String text) {
    if (text.trim().isEmpty) return;
    setState(() => _session.addAll(text));
    _input.clear();
    _focus.requestFocus();
    _timer?.cancel();
    _timer = Timer(widget.quiet, _resolve);
  }

  Future<void> _resolve() async {
    if (_session.codes.isEmpty || !mounted) return;
    final l10n = context.l10n;
    setState(() {
      _resolving = true;
      _problem = null;
    });
    BulkResolution? resolved;
    String? problem;
    try {
      resolved = await ref.read(stockTagsStoreProvider).resolveCodes(widget.workspaceId, _session.codes);
    } on Object catch (e, st) {
      TraceLogger.instance.warn('stock', 'a bulk read could not be resolved', error: e, stackTrace: st);
      problem = knownRefusalText(l10n, e) ?? l10n.stockReadFailed;
    }
    if (!mounted) return;
    setState(() {
      _resolving = false;
      _resolution = resolved ?? _resolution;
      _problem = problem;
    });
  }

  /// Freezes the tally: the next question to the server is the last one, and the rebuild shows the frozen sheet.
  Future<void> _stop() async {
    _timer?.cancel();
    _session.stop();
    await _resolve();
  }

  Future<void> _confirm() async {
    final resolution = _resolution;
    if (resolution == null) return;
    setState(() {
      _confirming = true;
      _problem = null;
    });
    final problem = await widget.onConfirm(resolution, _session.codes);
    if (!mounted) return;
    if (problem == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _confirming = false;
      _problem = problem;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tally = _resolution == null ? null : BulkTally.of(_resolution!);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            shrinkWrap: true,
            children: [
              Row(
                children: [
                  Expanded(child: Text(l10n.stockBulkReadTitle, style: theme.textTheme.titleLarge)),
                  HelpDot(l10n.stockBulkReadTitle, anchor: HelpAnchor.moneyStockBulkRead),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.stockBulkReadHint, style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.md),
              if (!_session.stopped)
                AppTextField(
                  key: const ValueKey('stock-bulk-input'),
                  controller: _input,
                  focusNode: _focus,
                  autofocus: true,
                  maxLines: 3,
                  label: l10n.stockBulkReadField,
                  prefixIcon: const Icon(Icons.sensors),
                  onSubmitted: _typed,
                  // a reader that ends a tag with a line break types it into the field
                  onChanged: (t) {
                    if (t.contains('\n')) _typed(t);
                  },
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.stockBulkReadCount(_session.codes.length),
                key: const ValueKey('stock-bulk-count'),
                style: theme.textTheme.titleSmall,
              ),
              Text(l10n.stockBulkReadLimit(_session.limit), key: const ValueKey('stock-bulk-limit'), style: theme.textTheme.bodySmall),
              if (_session.repeats > 0) Text(l10n.stockBulkReadRepeats(_session.repeats), key: const ValueKey('stock-bulk-repeats'), style: theme.textTheme.bodySmall),
              if (_session.dropped > 0) Text(l10n.stockBulkReadDropped(_session.dropped), key: const ValueKey('stock-bulk-dropped'), style: theme.textTheme.bodySmall),
              if (_resolving) Padding(padding: const EdgeInsets.only(top: AppSpacing.xs), child: Text(l10n.stockBulkReadResolving, style: theme.textTheme.bodySmall)),
              if (tally != null) ...[
                const SizedBox(height: AppSpacing.sm),
                for (final line in tally.lines)
                  ListTile(
                    key: ValueKey('stock-bulk-line-${line.itemId}-${line.variantId ?? ''}-${line.lotId ?? ''}'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.stockBulkReadPieces([line.itemName, line.variantLabel, line.lotCode].where((t) => t != null && t.isNotEmpty).join(' · '), line.count)),
                  ),
                if (widget.expected != null)
                  _CompareTable(rows: compareDelivery(widget.expected!, tally), names: {for (final l in tally.lines) l.itemId: l.itemName}),
                _Apart(keyName: 'unknown', title: l10n.stockBulkReadUnknown, codes: tally.unknown),
                _Apart(keyName: 'not-in-stock', title: l10n.stockBulkReadNotInStock, codes: [for (final c in tally.notInStock) c.input]),
                _Apart(keyName: 'not-pieces', title: l10n.stockBulkReadNotPieces, codes: [for (final c in tally.notPieces) c.input]),
              ],
              if (_problem != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(_problem!, key: const ValueKey('stock-bulk-problem'), style: TextStyle(color: theme.colorScheme.error)),
                ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (!_session.stopped)
                    OutlinedButton(key: const ValueKey('stock-bulk-stop'), onPressed: _session.codes.isEmpty ? null : _stop, child: Text(l10n.stockBulkReadStop))
                  else
                    OutlinedButton(key: const ValueKey('stock-bulk-again'), onPressed: _confirming ? null : () => Navigator.of(context).pop(false), child: Text(l10n.stockBulkReadAgain)),
                  FilledButton(
                    key: const ValueKey('stock-bulk-confirm'),
                    onPressed: _session.stopped && _resolution != null && !_resolving && !_confirming ? _confirm : null,
                    child: Text(widget.confirmLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tags of one kind that are shown apart, with their codes.
class _Apart extends StatelessWidget {
  const _Apart({required this.keyName, required this.title, required this.codes});

  final String keyName;
  final String title;
  final List<String> codes;

  @override
  Widget build(BuildContext context) {
    if (codes.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: ValueKey('stock-bulk-apart-$keyName'),
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$title (${codes.length})', style: Theme.of(context).textTheme.titleSmall),
          Text(codes.take(20).join(', '), style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Expected, read, missing and extra: for whoever receives a delivery.
class _CompareTable extends StatelessWidget {
  const _CompareTable({required this.rows, required this.names});

  final List<BulkCompareRow> rows;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context) => Table(
    key: const ValueKey('stock-bulk-compare'),
    children: [
      for (final r in rows)
        TableRow(children: [Text(names[r.itemId] ?? r.itemId), Text('${r.expected}'), Text('${r.read}'), Text('${r.missing}'), Text('${r.extra}')]),
    ],
  );
}
