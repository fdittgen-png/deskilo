// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4166 (cut 3) -- invoicing an accepted quote. The issuer states the service and
// due dates and CHECKS the invoice: the real issuer's own preview, set against
// what was accepted. An invoice that differs (the date, the customer's details
// or the tax facts moved) needs the issuer to say they reviewed exactly that
// preview; what cannot be issued yet is named. Then it is issued once: one quote
// makes one initial invoice whatever the request, a second tap is the same
// attempt, and a lost answer is looked up in the quote before anything is offered.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/failure/app_failure.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/calendar_days.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/issue_attempt.dart';
import '../../domain/customer_quote.dart';
import '../../domain/previewed_document.dart';
import '../../providers/business_day_provider.dart';
import '../../providers/customer_quote_providers.dart';
import '../../providers/standalone_invoice_providers.dart';
import '../standalone/previewed_document_card.dart';
import '../standalone/standalone_missing_text.dart';
import 'quote_text.dart';

/// The conversion sheet of an accepted quote.
abstract final class QuoteConversion {
  /// Opens the sheet over [quote]; true when the quote was invoiced.
  static Future<bool> show(
    BuildContext context, {
    required String workspaceId,
    required CustomerQuote quote,
  }) async =>
      await showAppSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => _QuoteConversionSheet(workspaceId: workspaceId, quote: quote),
      ) ??
      false;
}

/// What the person has set on the sheet. Immutable: every step is a new state; the check, the issue and the answer that may not
/// come are the [IssueAttempt]'s.
@immutable
class _Conversion {
  const _Conversion({required this.serviceDate, required this.dueOn, this.reviewed = false, this.converted});

  final DateTime serviceDate;
  final DateTime dueOn;
  final bool reviewed;
  final QuoteConverted? converted;

  /// The same conversion for other dates: the checked invoice no longer stands.
  _Conversion withDates({DateTime? serviceDate, DateTime? dueOn}) =>
      _Conversion(serviceDate: serviceDate ?? this.serviceDate, dueOn: dueOn ?? this.dueOn);

  _Conversion copy({bool? reviewed, QuoteConverted? converted}) =>
      _Conversion(serviceDate: serviceDate, dueOn: dueOn, reviewed: reviewed ?? this.reviewed, converted: converted ?? this.converted);
}

class _QuoteConversionSheet extends ConsumerStatefulWidget {
  const _QuoteConversionSheet({ required this.workspaceId, required this.quote});

  final String workspaceId;
  final CustomerQuote quote;

  @override
  ConsumerState<_QuoteConversionSheet> createState() => _QuoteConversionState();
}

class _QuoteConversionState extends ConsumerState<_QuoteConversionSheet> {
  late final ValueNotifier<_Conversion> _state;

  /// The one issue attempt: the checked invoice, what is missing, the request, an answer that did not come.
  late final _attempt = IssueAttempt<QuoteConversionPrep, QuoteConverted>(
    onChanged: () {
      if (mounted) setState(() {});
    },
  );

  @override
  void initState() {
    super.initState();
    final today = ref.read(businessDayProvider);
    _state = ValueNotifier(_Conversion(serviceDate: today, dueOn: addCalendarDays(today, ref.read(invoiceDueDaysProvider))));
    // The business's calendar and the payment term can arrive after the sheet opens: a date the person has not set follows
    // them, one the person set is never overwritten.
    ref
      ..listenManual<DateTime>(businessDayProvider, (was, now) {
        final c = _state.value;
        final service = _serviceTouched ? c.serviceDate : now;
        final due = _dueTouched ? c.dueOn : addCalendarDays(service, ref.read(invoiceDueDaysProvider));
        _state.value = c.withDates(serviceDate: service, dueOn: due);
      })
      ..listenManual<int>(invoiceDueDaysProvider, (was, now) {
        final c = _state.value;
        if (!_dueTouched) _state.value = c.withDates(dueOn: addCalendarDays(c.serviceDate, now));
      });
  }

  /// Whether the person has chosen a date: a chosen date is theirs, whatever arrives later.
  bool _serviceTouched = false;
  bool _dueTouched = false;

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  void _set(_Conversion next) => _state.value = next;

  /// The revision the customer accepted: the lines the invoice is made of.
  QuoteRevision get _accepted {
    final accepted = widget.quote.decision?.revision;
    return widget.quote.revisions.firstWhere((r) => r.revision == accepted, orElse: () => widget.quote.revisions.last);
  }

  /// A change of date makes the checked invoice stale: it is checked again.
  void _edit(_Conversion next) {
    _set(next);
    _attempt.edited();
  }

  /// The invoice this conversion would make, as the attempt keeps it: the real issuer's own preview, set against what was accepted.
  Future<void> _check() async {
    final s = _state.value;
    final commands = ref.read(customerQuoteCommandProvider);
    await _attempt.check(() async {
      final outcome = await commands.prepareConversion(widget.workspaceId, widget.quote.id, serviceDate: s.serviceDate, dueOn: s.dueOn);
      return switch (outcome) {
        CommandDone(:final value) => CommandDone((basis: value, document: value.documentOf(_accepted))),
        CommandRefused(:final refusal) => CommandRefused(refusal),
        CommandUnreached(:final failure) => CommandUnreached(failure),
        CommandHeld(:final eventId) => CommandHeld(eventId),
      };
    });
    _set(_state.value.copy(reviewed: false));
  }

  /// Whether the invoice may be issued now: checked, nothing missing, and the review done when it differs from what was accepted.
  bool _canIssue(_Conversion s) {
    final prep = _attempt.basis;
    final document = _attempt.document;
    return prep != null &&
        prep.issuable &&
        (document?.missing.isEmpty ?? false) &&
        (!prep.contextChanged || s.reviewed) &&
        !_attempt.busy &&
        !_attempt.isUnknown;
  }

  Future<void> _issue() async {
    final prep = _attempt.basis;
    if (prep == null || !_canIssue(_state.value)) return;
    final commands = ref.read(customerQuoteCommandProvider);
    final outcome = await _attempt.issue(
      send: (requestId) => commands.convert(
        widget.workspaceId,
        widget.quote.id,
        draftRevision: prep.draftRevision,
        requestId: requestId,
        reviewedDigest: prep.contextChanged ? prep.reviewDigest : null,
      ),
      look: (requestId, unknown) => commands.lookConverted(widget.workspaceId, widget.quote.id, unknown),
    );
    _arrive(outcome);
  }

  Future<void> _look() async => _arrive(await _attempt.lookAgain());

  /// Where a settled answer leads: the invoice, or a word that a validation policy holds it.
  void _arrive(CommandOutcome<QuoteConverted>? outcome) {
    if (!mounted || outcome == null) return;
    ref
      ..invalidate(customerQuotesProvider(widget.workspaceId))
      ..invalidate(customerQuoteProvider((workspaceId: widget.workspaceId, quoteId: widget.quote.id)));
    switch (outcome) {
      case CommandDone(:final value):
        _set(_state.value.copy(converted: value));
      case CommandHeld():
        AppSnack.info(context, context.l10n.validationSentForApproval);
      // the invoice moved under the review: it is checked again, never issued unseen (the attempt dropped the checked one)
      case CommandRefused() || CommandUnreached():
        _set(_state.value.copy(reviewed: false));
    }
  }

  /// What the quote says about a check or an issue that did not go through, in its own words.
  String? _said(AppLocalizations l10n) => switch (_attempt.refusal?.cause) {
    final QuoteRefusal refusal => quoteRefusalText(l10n, refusal),
    _ => _attempt.checkUnreached ? l10n.quoteUnreached : null,
  };

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<_Conversion>(
    valueListenable: _state,
    builder: (context, s, _) => ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      shrinkWrap: true,
      children: s.converted == null ? _steps(context, s) : _done(context, s.converted!),
    ),
  );

  List<Widget> _steps(BuildContext context, _Conversion s) {
    final l10n = context.l10n;
    final said = _said(l10n);
    final prep = _attempt.basis;
    return [
      Text(l10n.quoteConvert, style: Theme.of(context).textTheme.titleMedium),
      const FormGap(),
      Text(l10n.quoteConvertIntro),
      const FormGap(),
      AppDateField(
        key: const ValueKey('quote-convert-service-date'),
        label: l10n.standaloneInvoiceServiceDate,
        value: s.serviceDate,
        enabled: !_attempt.busy,
        onChanged: (d) {
          _serviceTouched = true;
          _edit(s.withDates(serviceDate: d.date));
        },
      ),
      const FormGap(),
      AppDateField(
        key: const ValueKey('quote-convert-due-date'),
        label: l10n.standaloneInvoiceDueDate,
        value: s.dueOn,
        enabled: !_attempt.busy,
        onChanged: (d) {
          _dueTouched = true;
          _edit(s.withDates(dueOn: d.date));
        },
      ),
      const FormGap(),
      OutlinedButton(
        key: const ValueKey('quote-convert-check'),
        onPressed: _attempt.busy || _attempt.isUnknown ? null : _check,
        child: Text(l10n.quoteConvertCheck),
      ),
      if (said != null) ...[
        const FormGap(),
        Text(said, key: const ValueKey('quote-convert-said')),
      ],
      if (_attempt.isUnknown) ...[
        const FormGap(),
        Text(l10n.quoteUnreached, key: const ValueKey('quote-convert-unknown')),
        TextButton(
          key: const ValueKey('quote-convert-look'),
          onPressed: _attempt.busy ? null : _look,
          child: Text(l10n.standaloneInvoiceLookAgain),
        ),
      ],
      if (prep != null) ..._preview(context, s, prep),
    ];
  }

  List<Widget> _preview(BuildContext context, _Conversion s, QuoteConversionPrep prep) {
    final l10n = context.l10n;
    final money = personalFormatOf(context).moneyNamed(prep.currency);
    final document = _attempt.document;
    return [
      const FormGap(),
      Text(
        l10n.quoteConvertAccepted(money.formatMinor(prep.acceptedTotalCents)),
        key: const ValueKey('quote-convert-accepted'),
      ),
      if (prep.wouldBeTotalCents case final would?)
        Text(
          l10n.quoteConvertWouldBe(money.formatMinor(would)),
          key: const ValueKey('quote-convert-would-be'),
        ),
      if (document != null && document.missing.isNotEmpty) ...[
        const FormGap(),
        Text(
          l10n.quoteConvertMissing(standaloneMissingList(l10n, document.missing)),
          key: const ValueKey('quote-convert-missing'),
        ),
      ],
      if (document != null && document.ready && !prep.contextChanged) ...[
        const FormGap(),
        PreviewedDocumentCard(key: const ValueKey('quote-convert-document'), preview: document),
      ],
      if (prep.contextChanged) ...[
        const FormGap(),
        Text(l10n.quoteConvertDiffers, key: const ValueKey('quote-convert-differs')),
        CheckboxListTile(
          key: const ValueKey('quote-convert-reviewed'),
          contentPadding: EdgeInsets.zero,
          value: s.reviewed,
          title: Text(l10n.quoteConvertReviewed),
          onChanged: _attempt.busy ? null : (v) => _set(s.copy(reviewed: v ?? false)),
        ),
      ],
      const FormGap(),
      FilledButton(
        key: const ValueKey('quote-convert-issue'),
        onPressed: _canIssue(s) ? _issue : null,
        child: Text(l10n.quoteConvertIssue),
      ),
    ];
  }

  List<Widget> _done(BuildContext context, QuoteConverted done) {
    final l10n = context.l10n;
    final number = done.number;
    return [
      Text(
        number == null || number.isEmpty ? l10n.quoteStatusConverted : l10n.quoteConvertDone(number),
        key: const ValueKey('quote-convert-done'),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const FormGap(),
      FilledButton(
        key: const ValueKey('quote-convert-open'),
        onPressed: () {
          final router = GoRouter.of(context);
          Navigator.of(context).pop(true);
          router.go('/invoices/${done.invoiceId}');
        },
        child: Text(l10n.quoteConvertOpenInvoice),
      ),
    ];
  }
}
