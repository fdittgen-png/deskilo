// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4165 (A2) -- the composer of a standalone customer invoice
// (`/invoicing/standalone/new`): choose the customer, enter the lines, check
// the invoice the SERVER would freeze, confirm and issue it, open the stored
// original. The draft is kept across a resize, a refusal and an unknown
// answer; an issue is sent once under its request id and a lost answer is
// looked up, never resent blindly. Nothing here computes an amount.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/failure/app_failure.dart';
import '../../../../core/features/enabled_feature_keys.dart';
import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/text/collation.dart';
import '../../../../core/time/calendar_days.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../application/issue_attempt.dart';
import '../../application/issue_standalone_invoice.dart';
import '../../domain/standalone_invoice.dart';
import '../../providers/business_day_provider.dart';
import '../../providers/money_providers.dart'
    show invoicingBusinessProvider, memberLabelsProvider;
import '../../providers/standalone_invoice_providers.dart';
import '../invoicing/invoicing_customer_actions.dart' show invoicesPath;
import 'document_composer.dart';
import 'previewed_document_card.dart';
import 'standalone_missing_text.dart';

class StandaloneInvoiceScreen extends ConsumerStatefulWidget {
  const StandaloneInvoiceScreen({super.key});

  @override
  ConsumerState<StandaloneInvoiceScreen> createState() => _State();
}

class _State extends ConsumerState<StandaloneInvoiceScreen> {
  final _doc = CommercialDocumentDraft();

  /// The one issue attempt: the checked invoice, what is missing, the request, an answer that did not come.
  late final _attempt = IssueAttempt<StandaloneSaved, StandaloneIssued>(
    // recorder-key-exempt: a repaint callback of a state holder, not a control
    onChanged: () {
      if (mounted) setState(() {});
    },
    keysOf: standaloneRefusalKeys,
  );

  @override
  void dispose() {
    _doc.dispose();
    super.dispose();
  }

  /// The due date proposed until a person sets one: the registered default term.
  DateTime _due(DateTime today) => _doc.endOn(today, (start) => addCalendarDays(start, ref.read(invoiceDueDaysProvider)));

  StandaloneDraft? _draft(DateTime today, StandaloneSaved? saved) {
    final customer = _doc.subject;
    if (customer == null) return null;
    return StandaloneDraft(
      draftId: saved?.draftId,
      revision: saved?.revision,
      subjectMemberId: customer,
      serviceDate: _doc.startOn(today),
      dueOn: _due(today),
      buyerReference: _doc.referenceText,
      purchaseOrder: _doc.orderText,
      lines: _doc.toLines(context),
    );
  }

  Future<void> _check(String workspaceId) async {
    final draft = _draft(ref.read(businessDayProvider), _attempt.basis);
    if (draft == null) return;
    await _attempt.check(() => ref.read(standaloneIssuanceProvider).check(workspaceId: workspaceId, draft: draft));
    // the identities the server kept for the lines, so the next save keeps them
    if (mounted) _doc.takeLineIds(_attempt.basis?.lines ?? const <StandaloneLine>[]);
  }

  Future<void> _issue(String workspaceId) async {
    final saved = _attempt.basis;
    if (saved == null || !(_attempt.document?.ready ?? false)) return;
    // One identity per confirmed revision: a second tap is the same attempt.
    StandaloneIssueAttempt attemptOf(String requestId) => StandaloneIssueAttempt(
      workspaceId: workspaceId,
      draftId: saved.draftId,
      revision: saved.revision,
      requestId: requestId,
    );
    final issuance = ref.read(standaloneIssuanceProvider);
    final outcome = await _attempt.issue(
      send: (requestId) => issuance.issue(attemptOf(requestId)),
      look: (requestId, unknown) => issuance.look(attemptOf(requestId), unknown),
    );
    _arrive(outcome);
  }

  Future<void> _look() async => _arrive(await _attempt.lookAgain());

  /// Where a settled answer leads: the invoice, or a word that a validation policy holds it.
  void _arrive(CommandOutcome<StandaloneIssued>? outcome) {
    if (!mounted || outcome == null) return;
    switch (outcome) {
      case CommandDone(:final value):
        context.go('$invoicesPath/${value.invoiceId}');
      case CommandHeld():
        // A validation policy holds the invoice: nothing is issued yet.
        AppSnack.info(context, context.l10n.validationSentForApproval);
      case CommandRefused() || CommandUnreached():
        break;
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
    final locked = _attempt.busy || _attempt.isUnknown;
    return Scaffold(
      appBar: _bar(context),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _composer(context, workspaceId, locked),
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

  Widget _composer(BuildContext context, String workspaceId, bool locked) {
    final l = context.l10n;
    final names = ref.watch(memberLabelsProvider);
    final customers = names.entries.toList()..sort((a, b) => compareNames(a.value, b.value));
    final today = ref.watch(businessDayProvider);
    ref.watch(invoiceDueDaysProvider); // the due date offered follows the payment term when it is read
    return DocumentComposer(
      key: const ValueKey('standalone-composer'),
      workspaceId: workspaceId,
      draft: _doc,
      words: DocumentComposerWords(
        keyPrefix: 'standalone',
        customerHint: l.standaloneInvoiceCustomerChoose,
        startLabel: l.standaloneInvoiceServiceDate,
        startKey: 'standalone-service-date',
        endLabel: l.standaloneInvoiceDueDate,
        endKey: 'standalone-due-date',
        referenceLabel: l.standaloneInvoiceBuyerReference,
        orderLabel: l.standaloneInvoiceOrderNumber,
      ),
      customers: [for (final c in customers) (id: c.key, name: c.value)],
      startShown: _doc.startOn(today),
      endShown: _due(today),
      locked: locked,
      pieces: true,
      onChanged: _attempt.edited,
      onReferenceChanged: _attempt.edited,
    );
  }

  /// The banner (unknown answer, or what is missing) and the checked invoice.
  List<Widget> _status(BuildContext context) {
    final l = context.l10n;
    final preview = _attempt.document;
    return [
      const FormGap(),
      if (_attempt.isUnknown)
        InlineBanner(
          key: const ValueKey('standalone-unknown'),
          icon: Icons.help_outline,
          text: l.standaloneInvoiceUnknown,
          actionLabel: l.standaloneInvoiceLookAgain,
          onAction: _attempt.busy ? null : _look,
        )
      else if (_attempt.refused || _attempt.checkUnreached)
        InlineBanner(
          key: const ValueKey('standalone-missing'),
          icon: Icons.error_outline,
          text: _attempt.missing.isEmpty
              ? l.standaloneInvoiceRefused
              : standaloneMissingSentence(l, _attempt.missing),
        ),
      if (preview != null && preview.ready) PreviewedDocumentCard(key: const ValueKey('standalone-preview'), preview: preview),
    ];
  }

  Widget _actions(BuildContext context, String workspaceId, bool locked) {
    final l = context.l10n;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            key: const ValueKey('standalone-check'),
            onPressed: locked || _doc.subject == null ? null : () => _check(workspaceId),
            child: Text(l.standaloneInvoicePreview),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            key: const ValueKey('standalone-issue'),
            onPressed: locked || !(_attempt.document?.ready ?? false) ? null : () => _issue(workspaceId),
            child: Text(l.standaloneInvoiceIssue),
          ),
        ),
      ],
    );
  }
}
