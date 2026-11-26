// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4368 (CS6) -- the settings of this device's receipt printer: where it is on the network, the paper, the code page,
// whether a drawer hangs on it and whether a sale prints by itself; and a test print, so the cashier knows it works
// before the first customer. The settings live on the device (the printer is wired to it).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/help/help_dot.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/dropdown_field.dart';
import '../../../core/ui/form_kit.dart';
import '../domain/escpos_receipt.dart';
import '../domain/receipt_sender.dart';
import '../domain/till_print_job.dart';
import '../domain/till_printer_settings.dart';
import '../providers/till_printer_providers.dart';

Future<void> showTillPrinterDialog(BuildContext context) => showDialog<void>(context: context, builder: (_) => const _PrinterDialog());

class _PrinterDialog extends ConsumerStatefulWidget {
  const _PrinterDialog();

  @override
  ConsumerState<_PrinterDialog> createState() => _PrinterDialogState();
}

class _PrinterDialogState extends ConsumerState<_PrinterDialog> {
  final _host = TextEditingController();
  final _port = TextEditingController(text: '${TillPrinterSettings.defaultPort}');
  int _paper = 80;
  EscposCodePage _page = EscposCodePage.cp858;
  bool _drawer = false;
  TillPrintMode _mode = TillPrintMode.ask;
  bool _loaded = false;
  String? _problem;
  String? _status;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final s = await ref.read(tillPrinterSettingsProvider.future);
    if (!mounted) return;
    setState(() {
      _host.text = s.host;
      _port.text = '${s.port}';
      _paper = s.paperMm;
      _page = s.codePage;
      _drawer = s.drawer;
      _mode = s.mode;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  /// The settings as typed, or null (with the problem said) when they are not usable.
  TillPrinterSettings? _read() {
    final l10n = context.l10n;
    final port = int.tryParse(_port.text.trim());
    if (_host.text.trim().isEmpty) {
      setState(() => _problem = l10n.tillPrinterHostRequired);
      return null;
    }
    if (port == null || port < 1 || port > 65535) {
      setState(() => _problem = l10n.tillPrinterPortInvalid);
      return null;
    }
    return TillPrinterSettings(host: _host.text.trim(), port: port, paperMm: _paper, codePage: _page, drawer: _drawer, mode: _mode);
  }

  Future<void> _save() async {
    final s = _read();
    if (s == null) return;
    await ref.read(tillPrinterStoreProvider).write(s);
    ref.invalidate(tillPrinterSettingsProvider);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _test() async {
    final s = _read();
    if (s == null) return;
    final l10n = context.l10n;
    try {
      final page = ReceiptPrint(
        business: l10n.tillPrinterTitle,
        title: l10n.tillPrinterTest,
        issuedAt: '',
        lines: const [],
        taxLabel: '',
        tax: '',
        totalLabel: '',
        total: '',
        tenders: const [],
        footer: 'é ß ñ à €',
      );
      await ref.read(receiptSenderProvider(s)).send(tillPrintJob(receipt: page, settings: s));
      if (mounted) {
        setState(() {
          _problem = null;
          _status = l10n.tillPrinterTestSent;
        });
      }
    } on ReceiptNotPrinted catch (e, st) {
      TraceLogger.instance.warn('money', 'the test page was not printed: $e', stackTrace: st);
      if (mounted) {
        setState(() {
          _problem = l10n.tillNotPrinted;
          _status = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      key: const ValueKey('till-printer-dialog'),
      title: Row(children: [Expanded(child: Text(l10n.tillPrinterTitle)), HelpDot(l10n.tillPrinterTitle, anchor: HelpAnchor.moneyTillPrinter)]),
      content: SizedBox(
        width: 420,
        child: !_loaded
            ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(key: const ValueKey('till-printer-host'), controller: _host, label: l10n.tillPrinterHost, helper: l10n.tillPrinterHostHint),
                    const FormGap(),
                    AppTextField(
                      key: const ValueKey('till-printer-port'),
                      controller: _port,
                      label: l10n.tillPrinterPort,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const FormGap(),
                    AppDropdownField<int>(
                      key: const ValueKey('till-printer-paper'),
                      label: l10n.tillPrinterPaper,
                      value: _paper,
                      items: [for (final mm in const [58, 80]) (mm, l10n.tillPrinterPaperWidth('$mm'))],
                      onChanged: (v) => setState(() => _paper = v ?? _paper),
                    ),
                    const FormGap(),
                    AppDropdownField<EscposCodePage>(
                      key: const ValueKey('till-printer-codepage'),
                      label: l10n.tillPrinterCodePage,
                      value: _page,
                      items: [(EscposCodePage.cp858, l10n.tillPrinterCodePage858), (EscposCodePage.cp437, l10n.tillPrinterCodePage437)],
                      onChanged: (v) => setState(() => _page = v ?? _page),
                    ),
                    const FormGap(),
                    AppDropdownField<TillPrintMode>(
                      key: const ValueKey('till-printer-mode'),
                      label: l10n.tillPrinterMode,
                      value: _mode,
                      items: [
                        (TillPrintMode.never, l10n.tillPrinterModeNever),
                        (TillPrintMode.ask, l10n.tillPrinterModeAsk),
                        (TillPrintMode.always, l10n.tillPrinterModeAlways),
                      ],
                      onChanged: (v) => setState(() => _mode = v ?? _mode),
                    ),
                    SwitchListTile(
                      key: const ValueKey('till-printer-drawer'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.tillPrinterDrawer),
                      value: _drawer,
                      onChanged: (v) => setState(() => _drawer = v),
                    ),
                    if (_status != null) Text(_status!, key: const ValueKey('till-printer-status')),
                    if (_problem != null) Text(_problem!, key: const ValueKey('till-printer-problem'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(key: const ValueKey('till-printer-test'), onPressed: _loaded ? _test : null, child: Text(l10n.tillPrinterTest)),
        TextButton(key: const ValueKey('till-printer-cancel'), onPressed: () => Navigator.of(context).pop(), child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
        FilledButton(key: const ValueKey('till-printer-save'), onPressed: _loaded ? _save : null, child: Text(MaterialLocalizations.of(context).saveButtonLabel)),
      ],
    );
  }
}
