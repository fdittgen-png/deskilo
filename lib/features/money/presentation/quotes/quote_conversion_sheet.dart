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
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/calendar_days.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/customer_quote.dart';
import '../../providers/business_day_provider.dart';
import '../../providers/customer_quote_providers.dart';
import '../../providers/standalone_invoice_providers.dart';
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

/// Where the conversion stands. Immutable: every step is a new state.
@immutable
class _Conversion {
  const _Conversion({
    required this.serviceDate,
    required this.dueOn,
    this.busy = false,
    this.prep,
    this.reviewed = false,
    this.said,
    this.requestId,
    this.converted,
  });

  final DateTime serviceDate;
  final DateTime dueOn;
  final bool busy;
  final QuoteConversionPrep? prep;
  final bool reviewed;
  final String? said;

  /// Drawn once per checked invoice: a second tap is the same attempt.
  final String? requestId;
  final QuoteConverted? converted;

  /// The same conversion for other dates: the checked invoice no longer stands.
  _Conversion withDates({DateTime? serviceDate, DateTime? dueOn}) => _Conversion(
    serviceDate: serviceDate ?? this.serviceDate,
    dueOn: dueOn ?? this.dueOn,
  );

  _Conversion copy({
    bool? busy,
    QuoteConversionPrep? Function()? prep,
    bool? reviewed,
    String? Function()? said,
    String? Function()? requestId,
    QuoteConverted? converted,
  }) => _Conversion(
    serviceDate: serviceDate,
    dueOn: dueOn,
    busy: busy ?? this.busy,
    prep: prep == null ? this.prep : prep(),
    reviewed: reviewed ?? this.reviewed,
    said: said == null ? this.said : said(),
    requestId: requestId == null ? this.requestId : requestId(),
    converted: converted ?? this.converted,
  );

  bool get canIssue {
    final p = prep;
    return p != null && p.issuable && (!p.contextChanged || reviewed) && !busy;
  }
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

  @override
  void initState() {
    super.initState();
    final today = ref.read(businessDayProvider);
    _state = ValueNotifier(
      _Conversion(
        serviceDate: today,
        dueOn: addCalendarDays(today, ref.read(invoiceDueDaysProvider)),
      ),
    );
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

  /// A change of date makes the checked invoice stale: it is checked again.
  void _edit(_Conversion next) => _set(next);

  Future<void> _check() async {
    _set(_state.value.copy(busy: true, said: () => null));
    final s = _state.value;
    final outcome = await ref.read(customerQuoteCommandProvider).prepareConversion(
      widget.workspaceId,
      widget.quote.id,
      serviceDate: s.serviceDate,
      dueOn: s.dueOn,
    );
    if (!mounted) return;
    final l10n = context.l10n;
    _set(switch (outcome) {
      CommandDone(:final value) => s.copy(
        busy: false,
        prep: () => value,
        reviewed: false,
        requestId: newRequestId,
      ),
      CommandRefused(refusal: Refusal(cause: final QuoteRefusal refusal)) => s.copy(busy: false, said: () => quoteRefusalText(l10n, refusal)),
      _ => s.copy(busy: false, said: () => l10n.quoteUnreached),
    });
  }

  Future<void> _issue() async {
    final s = _state.value;
    final prep = s.prep;
    final requestId = s.requestId;
    if (prep == null || requestId == null || !s.canIssue) return;
    _set(s.copy(busy: true, said: () => null));
    final outcome = await ref.read(customerQuoteCommandProvider).convert(
      widget.workspaceId,
      widget.quote.id,
      draftRevision: prep.draftRevision,
      requestId: requestId,
      reviewedDigest: prep.contextChanged ? prep.reviewDigest : null,
    );
    if (!mounted) return;
    final l10n = context.l10n;
    ref
      ..invalidate(customerQuotesProvider(widget.workspaceId))
      ..invalidate(customerQuoteProvider((workspaceId: widget.workspaceId, quoteId: widget.quote.id)));
    _set(switch (outcome) {
      CommandDone(:final value) => s.copy(busy: false, converted: value),
      // the invoice moved under the review: it is checked again, never issued unseen
      CommandRefused(refusal: Refusal(cause: final QuoteRefusal refusal)) when refusal.kind == QuoteRefusalKind.needsReview =>
        s.copy(busy: false, prep: () => null, reviewed: false, said: () => quoteRefusalText(l10n, refusal)),
      CommandRefused(refusal: Refusal(cause: final QuoteRefusal refusal)) => s.copy(busy: false, said: () => quoteRefusalText(l10n, refusal)),
      _ => s.copy(busy: false, said: () => l10n.quoteUnreached),
    });
  }

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
    return [
      Text(l10n.quoteConvert, style: Theme.of(context).textTheme.titleMedium),
      const FormGap(),
      Text(l10n.quoteConvertIntro),
      const FormGap(),
      AppDateField(
        key: const ValueKey('quote-convert-service-date'),
        label: l10n.standaloneInvoiceServiceDate,
        value: s.serviceDate,
        enabled: !s.busy,
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
        enabled: !s.busy,
        onChanged: (d) {
          _dueTouched = true;
          _edit(s.withDates(dueOn: d.date));
        },
      ),
      const FormGap(),
      OutlinedButton(
        key: const ValueKey('quote-convert-check'),
        onPressed: s.busy ? null : _check,
        child: Text(l10n.quoteConvertCheck),
      ),
      if (s.said != null) ...[
        const FormGap(),
        Text(s.said!, key: const ValueKey('quote-convert-said')),
      ],
      if (s.prep != null) ..._preview(context, s, s.prep!),
    ];
  }

  List<Widget> _preview(BuildContext context, _Conversion s, QuoteConversionPrep prep) {
    final l10n = context.l10n;
    final money = personalFormatOf(context).moneyNamed(prep.currency);
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
      if (!prep.issuable) ...[
        const FormGap(),
        Text(
          l10n.quoteConvertMissing(standaloneMissingList(l10n, prep.missing)),
          key: const ValueKey('quote-convert-missing'),
        ),
      ],
      if (prep.contextChanged) ...[
        const FormGap(),
        Text(l10n.quoteConvertDiffers, key: const ValueKey('quote-convert-differs')),
        CheckboxListTile(
          key: const ValueKey('quote-convert-reviewed'),
          contentPadding: EdgeInsets.zero,
          value: s.reviewed,
          title: Text(l10n.quoteConvertReviewed),
          onChanged: s.busy ? null : (v) => _set(s.copy(reviewed: v ?? false)),
        ),
      ],
      const FormGap(),
      FilledButton(
        key: const ValueKey('quote-convert-issue'),
        onPressed: s.canIssue ? _issue : null,
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
