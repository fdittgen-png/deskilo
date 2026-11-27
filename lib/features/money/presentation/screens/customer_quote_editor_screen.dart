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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/failure/app_failure.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../domain/billing_customer.dart';
import '../../domain/customer_quote.dart';
import '../../domain/standalone_invoice.dart';
import '../../providers/billing_customer_providers.dart';
import '../../providers/business_day_provider.dart';
import '../../providers/customer_quote_providers.dart';
import '../quotes/quote_text.dart';
import '../standalone/document_composer.dart';
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

  final doc = CommercialDocumentDraft();
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
    doc
      ..subject = quote.subjectId
      ..startDate = draft.issuedOn
      ..endDate = draft.validUntil;
    doc.reference.text = draft.buyerReference;
    doc.order.text = draft.purchaseOrder;
    doc.notes.text = draft.notes;
    version = draft.draftVersion;
    revision = draft.revision;
    doc.replaceLines(draft.lines);
  }

  QuoteDraftInput? input(BuildContext context) {
    final subject = doc.subject;
    if (subject == null) return null;
    return QuoteDraftInput(
      subjectId: subject,
      issuedOn: doc.startDate,
      validUntil: doc.endDate,
      buyerReference: doc.referenceText,
      purchaseOrder: doc.orderText,
      notes: doc.notesText,
      lines: doc.toLines(context),
    );
  }

  @override
  void dispose() {
    doc.dispose();
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
      case CommandDone(:final value):
        _form
          ..quoteId = value.quoteId
          ..version = value.version
          ..revision = value.revision;
        final read = await commands.read(workspaceId, value.quoteId);
        _form.doc.takeLineIds(read?.draft?.lines ?? const <StandaloneLine>[]);
        ref.invalidate(customerQuotesProvider(workspaceId));
        return true;
      case CommandRefused(refusal: Refusal(cause: final QuoteRefusal refusal)):
        _form
          ..said = quoteRefusalText(l10n, refusal)
          ..changed();
      case _:
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
      case CommandDone():
        context.go('/money/quotes/$id');
      case CommandRefused(refusal: Refusal(cause: final QuoteRefusal refusal)):
        _form
          ..busy = false
          ..said = quoteRefusalText(l10n, refusal)
          ..changed();
      case _:
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
      body = AsyncReadBody(
        value: ref.watch(customerQuoteProvider((workspaceId: id, quoteId: widget.quoteId))),
        refusal: (e) => e is QuoteRefusal ? quoteRefusalText(l10n, e) : null,
        onRetry: () => ref.invalidate(
          customerQuoteProvider((workspaceId: id, quoteId: widget.quoteId)),
        ),
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
    final today = ref.watch(businessDayProvider);
    final validity = ref.watch(quoteValidityProvider);
    final doc = _form.doc;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DocumentComposer(
          key: const ValueKey('quote-composer'),
          workspaceId: workspaceId,
          draft: doc,
          words: DocumentComposerWords(
            keyPrefix: 'quote',
            customerHint: l10n.quoteChooseCustomer,
            startLabel: l10n.quoteFieldIssuedOn,
            startKey: 'quote-issued-on',
            endLabel: l10n.quoteFieldValidUntil,
            endKey: 'quote-valid-until',
            referenceLabel: l10n.quoteFieldReference,
            orderLabel: l10n.quoteFieldOrder,
            notesLabel: l10n.quoteFieldNotes,
            noCustomers: l10n.quoteNoCustomers,
          ),
          customers: [for (final c in customers) (id: c.subjectId, name: c.displayName)],
          startShown: doc.startOn(today),
          endShown: doc.endOn(today, validity.defaultEnd),
          locked: locked,
          onChanged: _form.changed,
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
              onPressed: locked || _form.doc.subject == null
                  ? null
                  : () => unawaited(_saveDraft(workspaceId)),
              child: Text(l10n.quoteSaveDraft),
            ),
            FilledButton(
              key: const ValueKey('quote-send-now'),
              onPressed: locked || _form.doc.subject == null
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
