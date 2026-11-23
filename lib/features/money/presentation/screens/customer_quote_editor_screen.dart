// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4166 (cut 2) -- the quote editor (`/money/quotes/:id/edit`, `new` for a new
// quote): the customer, the dates, the commercial terms and the lines of the
// working draft revision, saved at the version it was read. The lines are the
// composer's own (#4165): the server reads quantities and prices exactly and
// works the amounts out when the quote is sent, so the editor shows none. A
// draft is saved before it is sent; a stale save, an incomplete quote and a
// lost answer are each said, never swallowed.
import 'dart:async';

import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../../core/ui/loading_view.dart';
import '../../application/customer_quote_commands.dart';
import '../../domain/billing_customer.dart';
import '../../domain/customer_quote.dart';
import '../../domain/standalone_invoice.dart';
import '../../providers/billing_customer_providers.dart';
import '../../providers/customer_quote_providers.dart';
import '../../providers/money_providers.dart' show vatRatesProvider;
import '../quotes/quote_text.dart';
import '../standalone/standalone_line_form.dart';
import 'money_view_data.dart';

class CustomerQuoteEditorScreen extends ConsumerStatefulWidget {
  const CustomerQuoteEditorScreen({super.key, required this.quoteId});

  /// The quote being edited, or `new`.
  final String quoteId;

  @override
  ConsumerState<CustomerQuoteEditorScreen> createState() => _EditorState();
}

/// What the editor holds: the fields of the working draft, the quote and draft
/// version it edits (null until the first save of a new quote) and where the
/// save stands. A change tells its listeners; the screen rebuilds from it.
class _QuoteForm extends ChangeNotifier {
  _QuoteForm(this.quoteId);

  final reference = TextEditingController();
  final order = TextEditingController();
  final notes = TextEditingController();
  final List<StandaloneLineForm> lines = [StandaloneLineForm()];
  String? customer;
  DateTime? issuedOn;
  DateTime? validUntil;
  String? quoteId;
  int? version;
  int? revision;
  bool loaded = false;
  bool busy = false;
  String? said;

  /// Tells the screen something changed.
  void changed() => notifyListeners();

  /// Takes the working draft of [quote] into the form (once), without telling
  /// anyone: it runs while the screen builds.
  void load(CustomerQuote quote) {
    loaded = true;
    final draft = quote.draft;
    if (draft == null) return;
    customer = quote.subjectId;
    issuedOn = draft.issuedOn;
    validUntil = draft.validUntil;
    reference.text = draft.buyerReference;
    order.text = draft.purchaseOrder;
    notes.text = draft.notes;
    version = draft.draftVersion;
    revision = draft.revision;
    for (final l in lines) {
      l.dispose();
    }
    lines
      ..clear()
      ..addAll([
        for (final line in draft.lines) StandaloneLineForm(from: line),
        if (draft.lines.isEmpty) StandaloneLineForm(),
      ]);
  }

  QuoteDraftInput? input(BuildContext context) {
    final subject = customer;
    if (subject == null) return null;
    return QuoteDraftInput(
      subjectId: subject,
      issuedOn: issuedOn,
      validUntil: validUntil,
      buyerReference: reference.text.trim(),
      purchaseOrder: order.text.trim(),
      notes: notes.text.trim(),
      lines: [for (final l in lines) l.toLine(context)],
    );
  }

  @override
  void dispose() {
    reference.dispose();
    order.dispose();
    notes.dispose();
    for (final l in lines) {
      l.dispose();
    }
    super.dispose();
  }
}

class _EditorState extends ConsumerState<CustomerQuoteEditorScreen> {
  late final _QuoteForm _form = _QuoteForm(_isNew ? null : widget.quoteId);

  bool get _isNew => widget.quoteId == 'new';

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  /// Saves the draft; true when the server kept it. Its line identities are
  /// read back so the next save keeps them.
  Future<bool> _save(String workspaceId) async {
    final input = _form.input(context);
    if (input == null) return false;
    final commands = ref.read(customerQuoteCommandProvider);
    final outcome = await commands.saveDraft(
      workspaceId,
      input: input,
      quoteId: _form.quoteId,
      expectedVersion: _form.version,
    );
    if (!mounted) return false;
    final l10n = context.l10n;
    switch (outcome) {
      case QuoteDone(:final value):
        _form
          ..quoteId = value.quoteId
          ..version = value.version
          ..revision = value.revision;
        final read = await commands.read(workspaceId, value.quoteId);
        // The server answers the lines in the order they were sent: only an answer that lines up is attached.
        final answered = read?.draft?.lines ?? const <StandaloneLine>[];
        if (answered.length == _form.lines.length) {
          for (final (i, line) in answered.indexed) {
            _form.lines[i].lineId = line.lineId;
          }
        }
        ref.invalidate(customerQuotesProvider(workspaceId));
        return true;
      case QuoteRefused(:final refusal):
        _form
          ..said = quoteRefusalText(l10n, refusal)
          ..changed();
      case QuoteUnreached():
        _form
          ..said = l10n.quoteUnreached
          ..changed();
    }
    return false;
  }

  Future<void> _saveDraft(String workspaceId) async {
    _form
      ..busy = true
      ..said = null
      ..changed();
    final ok = await _save(workspaceId);
    if (!mounted) return;
    _form
      ..busy = false
      ..said = ok ? context.l10n.quoteDraftSaved : _form.said
      ..changed();
  }

  Future<void> _send(String workspaceId) async {
    _form
      ..busy = true
      ..said = null
      ..changed();
    final ok = await _save(workspaceId);
    final id = _form.quoteId;
    final revision = _form.revision;
    final version = _form.version;
    if (!ok || id == null || revision == null || version == null) {
      if (mounted) {
        _form
          ..busy = false
          ..changed();
      }
      return;
    }
    final outcome = await ref.read(customerQuoteCommandProvider).send(
      workspaceId,
      id,
      revision: revision,
      version: version,
    );
    if (!mounted) return;
    final l10n = context.l10n;
    ref
      ..invalidate(customerQuotesProvider(workspaceId))
      ..invalidate(customerQuoteProvider((workspaceId: workspaceId, quoteId: id)));
    switch (outcome) {
      case QuoteDone():
        context.go('/money/quotes/$id');
      case QuoteRefused(:final refusal):
        _form
          ..busy = false
          ..said = quoteRefusalText(l10n, refusal)
          ..changed();
      case QuoteUnreached():
        _form
          ..busy = false
          ..said = l10n.quoteUnreached
          ..changed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final id = MoneyViewData.gates(ref).workspace?.id;
    Widget body;
    if (id == null) {
      body = const SizedBox.shrink();
    } else if (!_isNew && !_form.loaded) {
      body = ref
          .watch(customerQuoteProvider((workspaceId: id, quoteId: widget.quoteId)))
          .when(
            loading: () => const LoadingView(),
            error: (e, _) => Center(child: Text(l10n.quotesLoadFailed)),
            // the working draft is read once; edits are the form's from here on
            data: (quote) => _body(context, id, quote),
          );
    } else {
      body = _body(context, id, null);
    }
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(_isNew ? l10n.quoteNewTitle : l10n.quoteEditTitle),
        leading: CloseButton(
          key: const ValueKey('quote-editor-close'),
          onPressed: () => context.go(
            _form.quoteId == null ? '/money/quotes' : '/money/quotes/${_form.quoteId}',
          ),
        ),
      ),
      body: body,
    );
  }

  Widget _body(BuildContext context, String workspaceId, CustomerQuote? quote) {
    if (quote != null && !_form.loaded) _form.load(quote);
    return ListenableBuilder(
      listenable: _form,
      builder: (context, _) => _fields(context, workspaceId),
    );
  }

  Widget _fields(BuildContext context, String workspaceId) {
    final l10n = context.l10n;
    final locked = _form.busy;
    // empty-ok: no customer list means nothing to choose and the form says so
    final customers = ref.watch(billingCustomersProvider(workspaceId)).value ?? const <BillingParty>[]; // empty-ok: no customer list means nothing to choose
    // empty-ok: the rates only offer a choice; none leaves the business's default
    final rates = ref.watch(vatRatesProvider).value ?? const <VatRate>[]; // empty-ok: the rates only offer a choice
    final today = ref.watch(clockProvider).now();
    final validity = ref.watch(quoteValidityProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (customers.isEmpty)
          Text(l10n.quoteNoCustomers, key: const ValueKey('quote-no-customers'))
        else
          DropdownButtonFormField<String>(
            key: const ValueKey('quote-customer'),
            isExpanded: true,
            initialValue: _form.customer,
            decoration: InputDecoration(labelText: l10n.invoicingColCustomer),
            hint: Text(l10n.quoteChooseCustomer),
            items: [
              for (final c in customers)
                DropdownMenuItem(
                  value: c.subjectId,
                  child: Text(c.displayName, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: locked
                ? null
                : (v) => _form
                    ..customer = v
                    ..changed(),
          ),
        const FormGap(),
        AppDateField(
          key: const ValueKey('quote-issued-on'),
          label: l10n.quoteFieldIssuedOn,
          value: _form.issuedOn ?? today,
          enabled: !locked,
          onChanged: (d) => _form
            ..issuedOn = d.date
            ..changed(),
        ),
        const FormGap(),
        AppDateField(
          key: const ValueKey('quote-valid-until'),
          label: l10n.quoteFieldValidUntil,
          value: _form.validUntil ?? validity.defaultEnd(_form.issuedOn ?? today),
          enabled: !locked,
          onChanged: (d) => _form
            ..validUntil = d.date
            ..changed(),
        ),
        const FormGap(),
        AppTextField(
          key: const ValueKey('quote-reference'),
          controller: _form.reference,
          label: l10n.quoteFieldReference,
          enabled: !locked,
        ),
        const FormGap(),
        AppTextField(
          key: const ValueKey('quote-order'),
          controller: _form.order,
          label: l10n.quoteFieldOrder,
          enabled: !locked,
        ),
        const FormGap(),
        AppTextField(
          key: const ValueKey('quote-notes'),
          controller: _form.notes,
          label: l10n.quoteFieldNotes,
          enabled: !locked,
        ),
        const FormGap(),
        Text(l10n.standaloneInvoiceLines, style: Theme.of(context).textTheme.titleMedium?.strong),
        for (final (i, line) in _form.lines.indexed)
          StandaloneLineEditor(
            key: ValueKey('quote-line-editor-$i'),
            index: i,
            form: line,
            rates: rates,
            enabled: !locked,
            onChanged: _form.changed,
            onRemove: _form.lines.length > 1
                ? () {
                    _form.lines.removeAt(i).dispose();
                    _form.changed();
                  }
                : null,
          ),
        TextButton.icon(
          key: const ValueKey('quote-add-line'),
          onPressed: locked
              ? null
              : () {
                  _form.lines.add(StandaloneLineForm());
                  _form.changed();
                },
          icon: const Icon(Icons.add),
          label: Text(l10n.standaloneInvoiceAddLine),
        ),
        Text(l10n.quoteAmountsOnSend, key: const ValueKey('quote-amounts-on-send')),
        if (_form.said != null) ...[
          const FormGap(),
          Text(_form.said!, key: const ValueKey('quote-said')),
        ],
        const FormGap(),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton(
              key: const ValueKey('quote-save-draft'),
              onPressed: locked || _form.customer == null
                  ? null
                  : () => unawaited(_saveDraft(workspaceId)),
              child: Text(l10n.quoteSaveDraft),
            ),
            FilledButton(
              key: const ValueKey('quote-send-now'),
              onPressed: locked || _form.customer == null
                  ? null
                  : () => unawaited(_send(workspaceId)),
              child: Text(l10n.quoteSend),
            ),
          ],
        ),
      ],
    );
  }
}
