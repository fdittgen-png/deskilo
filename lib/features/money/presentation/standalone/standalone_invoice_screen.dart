// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4165 (A2) -- the composer of a standalone customer invoice
// (`/invoicing/standalone/new`): choose the customer, enter the lines, check
// the invoice the SERVER would freeze, confirm and issue it, open the stored
// original. The draft is kept across a resize, a refusal and an unknown
// answer; an issue is sent once under its request id and a lost answer is
// looked up, never resent blindly. Nothing here computes an amount.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/failure/app_failure.dart';
import '../../../../core/features/enabled_feature_keys.dart';
import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/text/collation.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/time/calendar_days.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../stock/domain/workspace_units.dart';
import '../../../stock/providers/workspace_units_providers.dart';
import '../../application/issue_standalone_invoice.dart';
import '../../domain/invoice_goods.dart';
import '../../domain/standalone_invoice.dart';
import '../../providers/business_day_provider.dart';
import '../../providers/money_providers.dart'
    show invoicingBusinessProvider, memberLabelsProvider, vatRatesProvider;
import '../../providers/standalone_invoice_providers.dart';
import '../invoicing/invoicing_customer_actions.dart' show invoicesPath;
import 'standalone_line_form.dart';
import 'standalone_missing_text.dart';

class StandaloneInvoiceScreen extends ConsumerStatefulWidget {
  const StandaloneInvoiceScreen({super.key});

  @override
  ConsumerState<StandaloneInvoiceScreen> createState() => _State();
}

class _State extends ConsumerState<StandaloneInvoiceScreen> {
  final _reference = TextEditingController();
  final _order = TextEditingController();
  final List<StandaloneLineForm> _lines = [StandaloneLineForm()];
  String? _customer;
  DateTime? _serviceDate;
  DateTime? _dueOn;

  StandaloneSaved? _saved;
  StandalonePreview? _preview;
  bool _busy = false;
  List<String> _missing = const [];
  bool _refused = false;
  String? _requestId;
  // The attempt whose answer did not come, kept to look for its receipt.
  StandaloneIssueAttempt? _attempt;
  CommandUnreached<StandaloneIssued>? _unknown;

  @override
  void dispose() {
    _reference.dispose();
    _order.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  /// Any edit makes the checked invoice stale: the next check saves a new
  /// revision, and the confirmed one is the one issued.
  void _edited() => setState(() {
    _preview = null;
    _missing = const [];
    _refused = false;
  });

  DateTime _service(DateTime today) => _serviceDate ?? today;

  /// The due date proposed until a person sets one: the registered default term.
  DateTime _due(DateTime today) =>
      _dueOn ?? addCalendarDays(_service(today), ref.read(invoiceDueDaysProvider));

  StandaloneDraft? _draft(DateTime today) {
    final customer = _customer;
    if (customer == null) return null;
    return StandaloneDraft(
      draftId: _saved?.draftId,
      revision: _saved?.revision,
      subjectMemberId: customer,
      serviceDate: _service(today),
      dueOn: _due(today),
      buyerReference: _reference.text.trim(),
      purchaseOrder: _order.text.trim(),
      lines: [for (final l in _lines) l.toLine(context)],
    );
  }

  Future<void> _check(String workspaceId) async {
    final draft = _draft(ref.read(businessDayProvider));
    if (draft == null) return;
    final commands = ref.read(standaloneInvoiceCommandsProvider);
    setState(() => _busy = true);
    try {
      final saved = await commands.saveDraft(workspaceId: workspaceId, draft: draft);
      if (!mounted) return;
      attachLineIds(_lines, saved.lines);
      final preview = await commands.preview(
        workspaceId: workspaceId,
        draftId: saved.draftId,
        revision: saved.revision,
      );
      if (!mounted) return;
      setState(() {
        _saved = saved;
        _requestId = null;
        _preview = preview;
        _missing = preview.missing;
        _refused = false;
      });
    } on Object catch (e, st) {
      traceStandaloneFailure('standalone invoice check failed', e, st);
      if (!mounted) return;
      setState(() {
        _missing = standaloneRefusalKeys(e);
        _refused = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _issue(String workspaceId) async {
    final saved = _saved;
    if (saved == null || !(_preview?.ready ?? false)) return;
    // One identity per confirmed revision: a second tap is the same attempt.
    final attempt = StandaloneIssueAttempt(
      workspaceId: workspaceId,
      draftId: saved.draftId,
      revision: saved.revision,
      requestId: _requestId ??= newRequestId(),
    );
    setState(() => _busy = true);
    _attempt = attempt;
    final outcome = await ref.read(standaloneIssuanceProvider).issue(attempt);
    if (!mounted) return;
    _settle(outcome);
  }

  Future<void> _look() async {
    final unknown = _unknown;
    final attempt = _attempt;
    if (unknown == null || attempt == null) return;
    setState(() => _busy = true);
    final outcome =
        await ref.read(standaloneIssuanceProvider).look(attempt, unknown);
    if (!mounted) return;
    _settle(outcome);
  }

  void _settle(CommandOutcome<StandaloneIssued> outcome) {
    switch (outcome) {
      case CommandDone(:final value):
        setState(() => _busy = false);
        context.go('$invoicesPath/${value.invoiceId}');
      case CommandRefused(:final refusal):
        setState(() {
          _busy = false;
          _unknown = null;
          _refused = true;
          _missing = standaloneRefusalKeys(refusal);
          _preview = null;
        });
      case CommandHeld():
        // A validation policy holds the invoice: nothing is issued yet.
        setState(() => _busy = false);
        AppSnack.info(context, context.l10n.validationSentForApproval);
      case CommandUnreached():
        setState(() {
          _busy = false;
          _unknown = outcome;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final on = featureOn(
      ref.watch(enabledFeatureKeysProvider),
      'standaloneInvoicing',
      byDefault: false,
    );
    if (!on) {
      return Scaffold(
        appBar: _bar(context),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l.standaloneInvoiceUnavailable, textAlign: TextAlign.center),
          ),
        ),
      );
    }
    final workspaceId = ref.watch(invoicingBusinessProvider.select((b) => b.id));
    final locked = _busy || _unknown != null;
    return Scaffold(
      appBar: _bar(context),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ..._header(context, locked),
          ..._linesSection(context, workspaceId, locked),
          ..._status(context),
          const FormGap(),
          _actions(context, workspaceId, locked),
        ],
      ),
    );
  }

  /// The title, and the way out: back to the invoices, the draft left behind.
  AppBar _bar(BuildContext context) => AppBar(
    title: PageTitle(context.l10n.invoiceCreate),
    actions: [
      HelpDot(
        context.l10n.standaloneInvoiceMore,
        anchor: HelpAnchor.moneyStandaloneInvoice,
      ),
    ],
    leading: CloseButton(
      key: const ValueKey('standalone-close'),
      onPressed: () => context.go(invoicesPath),
    ),
  );

  List<Widget> _header(BuildContext context, bool locked) {
    final l = context.l10n;
    final names = ref.watch(memberLabelsProvider);
    final customers = names.entries.toList()
      ..sort((a, b) => compareNames(a.value, b.value));
    final today = ref.watch(businessDayProvider);
    ref.watch(invoiceDueDaysProvider); // the due date offered follows the payment term when it is read
    return [
      DropdownButtonFormField<String>(
        key: const ValueKey('standalone-customer'),
        isExpanded: true,
        initialValue: _customer,
        decoration: InputDecoration(labelText: l.invoicingColCustomer),
        hint: Text(l.standaloneInvoiceCustomerChoose),
        items: [
          for (final c in customers)
            DropdownMenuItem(
              value: c.key,
              child: Text(c.value, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: locked
            ? null
            : (v) {
                _customer = v;
                _edited();
              },
      ),
      const FormGap(),
      AppDateField(
        key: const ValueKey('standalone-service-date'),
        label: l.standaloneInvoiceServiceDate,
        value: _service(today),
        enabled: !locked,
        onChanged: (d) {
          _serviceDate = d.date;
          _edited();
        },
      ),
      const FormGap(),
      AppDateField(
        key: const ValueKey('standalone-due-date'),
        label: l.standaloneInvoiceDueDate,
        value: _due(today),
        enabled: !locked,
        onChanged: (d) {
          _dueOn = d.date;
          _edited();
        },
      ),
      const FormGap(),
      AppTextField(
        key: const ValueKey('standalone-reference'),
        controller: _reference,
        label: l.standaloneInvoiceBuyerReference,
        enabled: !locked,
        onChanged: (_) => _edited(),
      ),
      const FormGap(),
      AppTextField(
        key: const ValueKey('standalone-order'),
        controller: _order,
        label: l.standaloneInvoiceOrderNumber,
        enabled: !locked,
        onChanged: (_) => _edited(),
      ),
      const FormGap(),
    ];
  }

  List<Widget> _linesSection(BuildContext context, String workspaceId, bool locked) {
    final l = context.l10n;
    final rates = ref.watch(vatRatesProvider).value ?? const <VatRate>[]; // empty-ok: the rates only offer a choice; none leaves the business's default
    // #4433 -- with the goods ledger on, a line may sell an item kept in stock, and name its pieces where they are tagged
    final keys = ref.watch(enabledFeatureKeysProvider);
    final goods = featureOn(keys, 'stockManagement', byDefault: false)
        ? ref.watch(invoiceGoodsItemsProvider(workspaceId)).value ?? const <InvoiceGoodsItem>[] // empty-ok: the items only offer a choice; none leaves every line a service
        : const <InvoiceGoodsItem>[];
    final pieces = featureOn(keys, 'stockTags', byDefault: false);
    return [
      Text(l.standaloneInvoiceLines, style: Theme.of(context).textTheme.titleMedium?.strong),
      for (final (i, line) in _lines.indexed)
        StandaloneLineEditor(
          key: ValueKey('standalone-line-editor-$i'),
          index: i,
          form: line,
          rates: rates,
          goods: goods,
          pieces: pieces,
          units: ref.watch(lineUnitsProvider(workspaceId)).value ?? const <WorkspaceUnit>[], // empty-ok: the units only offer a choice
          enabled: !locked,
          onChanged: _edited,
          onRemove: _lines.length > 1
              ? () => setState(() {
                  _lines.removeAt(i).dispose();
                  _edited();
                })
              : null,
        ),
      TextButton.icon(
        key: const ValueKey('standalone-add-line'),
        onPressed: locked
            ? null
            : () => setState(() {
                _lines.add(StandaloneLineForm());
                _edited();
              }),
        icon: const Icon(Icons.add),
        label: Text(l.standaloneInvoiceAddLine),
      ),
    ];
  }

  /// The banner (unknown answer, or what is missing) and the checked invoice.
  List<Widget> _status(BuildContext context) {
    final l = context.l10n;
    final preview = _preview;
    return [
      const FormGap(),
      if (_unknown != null)
        InlineBanner(
          key: const ValueKey('standalone-unknown'),
          icon: Icons.help_outline,
          text: l.standaloneInvoiceUnknown,
          actionLabel: l.standaloneInvoiceLookAgain,
          onAction: _busy ? null : _look,
        )
      else if (_refused || _missing.isNotEmpty)
        InlineBanner(
          key: const ValueKey('standalone-missing'),
          icon: Icons.error_outline,
          text: _missing.isEmpty
              ? l.standaloneInvoiceRefused
              : standaloneMissingSentence(l, _missing),
        ),
      if (preview != null && preview.ready) _PreviewCard(preview: preview),
    ];
  }

  Widget _actions(BuildContext context, String workspaceId, bool locked) {
    final l = context.l10n;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            key: const ValueKey('standalone-check'),
            onPressed: locked || _customer == null ? null : () => _check(workspaceId),
            child: Text(l.standaloneInvoicePreview),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            key: const ValueKey('standalone-issue'),
            onPressed: locked || !(_preview?.ready ?? false) ? null : () => _issue(workspaceId),
            child: Text(l.standaloneInvoiceIssue),
          ),
        ),
      ],
    );
  }
}

/// What the server would freeze: each line with its exact quantity and unit,
/// the tax and the total, as it answered.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});

  final StandalonePreview preview;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final format = appFormatOf(context).moneyNamed(preview.currency);
    final net = preview.vatTotals.fold<int>(0, (s, t) => s + t.netCents);
    final tax = preview.vatTotals.fold<int>(0, (s, t) => s + t.vatCents);
    return Card(
      key: const ValueKey('standalone-preview'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in preview.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${line.label} · ${line.quantityText ?? ''} '
                        '${line.exactFacts?.unit.label ?? ''}',
                      ),
                    ),
                    Text(format.formatMinor(line.exactFacts?.amounts.netMinor ?? line.amountCents)),
                  ],
                ),
              ),
            const Divider(),
            _row(l.standaloneInvoicePreviewNet, format.formatMinor(net)),
            _row(l.standaloneInvoicePreviewTax, format.formatMinor(tax)),
            _row(l.standaloneInvoicePreviewTotal, format.formatMinor(preview.totalCents), bold: true),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: bold ? const TextStyle().strong : null),
      ],
    ),
  );
}
