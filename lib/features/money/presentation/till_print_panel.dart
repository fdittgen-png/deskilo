// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4368 (CS6) -- the receipt of the sale just made, on the till's own receipt printer. The sale is final before anything
// is printed: a printer that cannot be reached says so, in words, and the receipt can be printed again (a reprint, marked
// as a copy) -- it never touches the sale. A cash drawer attached to the printer is kicked open once, with the first
// print or, when nothing prints by itself, on its own.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/help/help_dot.dart';
import '../../../core/i18n/format_controller.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/time/clock.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/counter_till.dart';
import '../domain/till_print_job.dart';
import '../domain/till_printer_settings.dart';
import '../providers/till_printer_providers.dart';
import '../providers/till_providers.dart';
import 'till_printer_dialog.dart';
import 'till_receipt.dart';

enum _Print { idle, printing, printed, failed }

class TillPrintPanel extends ConsumerStatefulWidget {
  const TillPrintPanel({super.key, required this.sold, required this.draft, required this.lines, required this.changeMinor, this.cash = true});

  /// The sale took cash: the drawer opens for it (a card sale opens no drawer).
  final bool cash;

  final TillSold sold;
  final TillDraft draft;
  final List<TillLine> lines;
  final int changeMinor;

  @override
  ConsumerState<TillPrintPanel> createState() => _TillPrintPanelState();
}

class _TillPrintPanelState extends ConsumerState<TillPrintPanel> {
  _Print _state = _Print.idle;

  /// How many times this receipt went to the printer: from the second on it is a copy the server counts (#4476).
  int _sent = 0;
  bool _drawerKicked = false;

  @override
  void initState() {
    super.initState();
    unawaited(_onSale());
  }

  /// A sale was just made: print it if the till is set to, and open the drawer if one is attached.
  Future<void> _onSale() async {
    if (!ref.read(tillPrinterOnProvider)) return;
    final settings = await ref.read(tillPrinterSettingsProvider.future);
    if (!mounted || !settings.configured) return;
    if (settings.mode == TillPrintMode.always) {
      await _print();
    } else if (settings.drawer && widget.cash) {
      await _kick(settings);
    }
  }

  Future<void> _kick(TillPrinterSettings settings) async {
    try {
      await ref.read(receiptSenderProvider(settings)).send(tillPrintJob(settings: settings, kickDrawer: true));
      _drawerKicked = true;
    } on Object catch (e, st) {
      TraceLogger.instance.warn('money', 'the cash drawer did not open', error: e, stackTrace: st);
    }
  }

  Future<void> _print() async {
    final settings = await ref.read(tillPrinterSettingsProvider.future);
    if (!mounted) return;
    if (!settings.configured) {
      await showTillPrinterDialog(context);
      return;
    }
    setState(() => _state = _Print.printing);
    final l10n = context.l10n;
    final format = appFormatOf(context);
    int? copy;
    if (_sent > 0) {
      // a print after the first is a copy: counted by the server, never numbered again (a retry after a failure too)
      final copies = ref.read(tillCopyPortProvider);
      try {
        final workspaceId = ref.read(tillBusinessProvider).id;
        copy = workspaceId.isEmpty ? null : await copies?.copy(workspaceId, requestId: newRequestId(), receiptId: widget.sold.receiptId);
      } on Object catch (e, st) {
        TraceLogger.instance.warn('money', 'a receipt copy was not counted', error: e, stackTrace: st);
        if (mounted) setState(() => _state = _Print.failed);
        return;
      }
      if (!mounted) return;
    }
    final receipt = tillReceiptOf(
      l10n: l10n,
      fmt: format,
      sale: (
        business: ref.read(tillBusinessProvider).name,
        sold: widget.sold,
        draft: widget.draft,
        lines: widget.lines,
        at: ref.read(clockProvider).now(),
        givenMinor: widget.sold.totals.grossMinor + widget.changeMinor,
        changeMinor: widget.changeMinor,
      ),
      copy: copy,
    );
    try {
      await ref.read(receiptSenderProvider(settings)).send(tillPrintJob(receipt: receipt, settings: settings, kickDrawer: widget.cash && !_drawerKicked));
      _drawerKicked = true;
      _sent++;
      if (mounted) setState(() => _state = _Print.printed);
    } on Object catch (e, st) {
      // the printer is not the sale: the sale stands, the receipt can be printed again
      TraceLogger.instance.warn('money', 'the receipt was not printed', error: e, stackTrace: st);
      _sent++;
      if (mounted) setState(() => _state = _Print.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(tillPrinterOnProvider)) return const SizedBox.shrink();
    final l10n = context.l10n;
    final settings = ref.watch(tillPrinterSettingsProvider).value ?? const TillPrinterSettings(); // empty-ok: no printer read yet is no printer set, and setting one up is offered
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          switch (_state) {
            _Print.idle => settings.configured
                ? OutlinedButton.icon(key: const ValueKey('till-print'), icon: const Icon(Icons.print_outlined), label: Text(l10n.tillPrintReceipt), onPressed: _print)
                : TextButton.icon(key: const ValueKey('till-printer-setup'), icon: const Icon(Icons.print_disabled_outlined), label: Text(l10n.tillPrinterSet), onPressed: () => showTillPrinterDialog(context)),
            _Print.printing => Text(l10n.tillPrinting, key: const ValueKey('till-printing')),
            _Print.printed => Row(
              children: [
                Expanded(child: Text(l10n.tillPrinted, key: const ValueKey('till-printed'))),
                TextButton(key: const ValueKey('till-print-copy'), onPressed: _print, child: Text(l10n.tillPrintCopy)),
              ],
            ),
            _Print.failed => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(l10n.tillNotPrinted, key: const ValueKey('till-not-printed'), style: TextStyle(color: Theme.of(context).colorScheme.error))),
                    HelpDot(l10n.tillPrinterTitle, anchor: HelpAnchor.moneyTillPrinter),
                  ],
                ),
                TextButton(key: const ValueKey('till-print-again'), onPressed: _print, child: Text(l10n.tillPrintCopy)),
              ],
            ),
          },
        ],
      ),
    );
  }
}
