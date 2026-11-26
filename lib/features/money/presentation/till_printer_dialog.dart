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
import '../../../core/ui/loading_view.dart';
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

/// What the dialog holds while it is open: the choices, whether the settings were read, and what the last act said.
class _PrinterForm extends ChangeNotifier {
  int paper = 80;
  EscposCodePage page = EscposCodePage.cp858;
  bool drawer = false;
  TillPrintMode mode = TillPrintMode.ask;
  bool loaded = false;
  String? problem;
  String? status;

  void loadedFrom(TillPrinterSettings s) {
    paper = s.paperMm;
    page = s.codePage;
    drawer = s.drawer;
    mode = s.mode;
    loaded = true;
    notifyListeners();
  }

  void change({int? paper, EscposCodePage? page, bool? drawer, TillPrintMode? mode}) {
    this.paper = paper ?? this.paper;
    this.page = page ?? this.page;
    this.drawer = drawer ?? this.drawer;
    this.mode = mode ?? this.mode;
    notifyListeners();
  }

  void said({String? problem, String? status}) {
    this.problem = problem;
    this.status = status;
    notifyListeners();
  }
}

class _PrinterDialogState extends ConsumerState<_PrinterDialog> {
  final _host = TextEditingController();
  final _port = TextEditingController(text: '${TillPrinterSettings.defaultPort}');
  final _form = _PrinterForm();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final s = await ref.read(tillPrinterSettingsProvider.future);
    if (!mounted) return;
    _host.text = s.host;
    _port.text = '${s.port}';
    _form.loadedFrom(s);
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _form.dispose();
    super.dispose();
  }

  /// The settings as typed, or null (with the problem said) when they are not usable.
  TillPrinterSettings? _read() {
    final l10n = context.l10n;
    final port = int.tryParse(_port.text.trim());
    if (_host.text.trim().isEmpty) {
      _form.said(problem: l10n.tillPrinterHostRequired);
      return null;
    }
    if (port == null || port < 1 || port > 65535) {
      _form.said(problem: l10n.tillPrinterPortInvalid);
      return null;
    }
    final f = _form;
    return TillPrinterSettings(host: _host.text.trim(), port: port, paperMm: f.paper, codePage: f.page, drawer: f.drawer, mode: f.mode);
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
      if (mounted) _form.said(status: l10n.tillPrinterTestSent);
    } on ReceiptNotPrinted catch (e, st) {
      TraceLogger.instance.warn('money', 'the test page was not printed', error: e, stackTrace: st);
      if (mounted) _form.said(problem: l10n.tillNotPrinted);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: _form, builder: (context, _) => _dialog(context));

  Widget _dialog(BuildContext context) {
    final l10n = context.l10n;
    final f = _form;
    return AlertDialog(
      key: const ValueKey('till-printer-dialog'),
      title: Row(children: [Expanded(child: Text(l10n.tillPrinterTitle)), HelpDot(l10n.tillPrinterTitle, anchor: HelpAnchor.moneyTillPrinter)]),
      content: SizedBox(
        width: 420,
        child: !f.loaded
            ? const LoadingView()
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
                      value: f.paper,
                      items: [for (final mm in const [58, 80]) (mm, l10n.tillPrinterPaperWidth('$mm'))],
                      onChanged: (v) => f.change(paper: v),
                    ),
                    const FormGap(),
                    AppDropdownField<EscposCodePage>(
                      key: const ValueKey('till-printer-codepage'),
                      label: l10n.tillPrinterCodePage,
                      value: f.page,
                      items: [(EscposCodePage.cp858, l10n.tillPrinterCodePage858), (EscposCodePage.cp437, l10n.tillPrinterCodePage437)],
                      onChanged: (v) => f.change(page: v),
                    ),
                    const FormGap(),
                    AppDropdownField<TillPrintMode>(
                      key: const ValueKey('till-printer-mode'),
                      label: l10n.tillPrinterMode,
                      value: f.mode,
                      items: [
                        (TillPrintMode.never, l10n.tillPrinterModeNever),
                        (TillPrintMode.ask, l10n.tillPrinterModeAsk),
                        (TillPrintMode.always, l10n.tillPrinterModeAlways),
                      ],
                      onChanged: (v) => f.change(mode: v),
                    ),
                    SwitchListTile(
                      key: const ValueKey('till-printer-drawer'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.tillPrinterDrawer),
                      value: f.drawer,
                      onChanged: (v) => f.change(drawer: v),
                    ),
                    if (f.status case final status?) Text(status, key: const ValueKey('till-printer-status')),
                    if (f.problem case final problem?) Text(problem, key: const ValueKey('till-printer-problem'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(key: const ValueKey('till-printer-test'), onPressed: f.loaded ? _test : null, child: Text(l10n.tillPrinterTest)),
        TextButton(key: const ValueKey('till-printer-cancel'), onPressed: () => Navigator.of(context).pop(), child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
        FilledButton(key: const ValueKey('till-printer-save'), onPressed: f.loaded ? _save : null, child: Text(MaterialLocalizations.of(context).saveButtonLabel)),
      ],
    );
  }
}
