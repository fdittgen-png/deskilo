// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4166 (cut 3) -- recording the customer's answer to a sent quote: accepted or
// declined, the date of the answer, how it reached the issuer and a reference.
// It is the ISSUER'S record of an answer received outside the app, said as such;
// never the customer's signature, and it invoices nothing. The server decides
// (an offer past its validity cannot be accepted, whatever date is typed).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/customer_quote_commands.dart';
import '../../domain/customer_quote.dart';
import '../../providers/business_day_provider.dart';
import '../../providers/customer_quote_providers.dart';
import 'quote_text.dart';

/// The sources the issuer can name, by the server's own words.
const List<String> _decisionSources = [
  'received_outside_app',
  'verbal',
  'email',
  'other',
];

/// What a source is called on screen.
String quoteSourceLabel(AppLocalizations l10n, String source) => switch (source) {
  'received_outside_app' => l10n.quoteSourceReceived,
  'verbal' => l10n.quoteSourceVerbal,
  'email' => l10n.quoteSourceEmail,
  _ => l10n.quoteSourceOther,
};

/// The sheet that records the customer's answer to a sent quote.
abstract final class QuoteDecisionSheet {
  /// Opens the sheet over [quote]'s current sent revision; true when the
  /// answer was recorded.
  static Future<bool> show(
    BuildContext context,
    WidgetRef ref, {
    required String workspaceId,
    required CustomerQuote quote,
  }) => _open(context, ref, workspaceId, quote);

  static Future<bool> _open(
    BuildContext context,
    WidgetRef ref,
    String workspaceId,
    CustomerQuote quote,
  ) {
    final revision = quote.current;
    if (revision == null) return Future.value(false);
    final l10n = context.l10n;
    final state = _Answer(ref.read(businessDayProvider));
    return showAppFormSheet(
      context,
      AppFormSheet(
        title: l10n.quoteRecordAnswer,
        submitLabel: l10n.quoteRecordAnswer,
        submitKey: const ValueKey('quote-decision-submit'),
        onDispose: state.evidence.dispose,
        onSubmit: () async {
          final outcome = await ref.read(customerQuoteCommandProvider).recordDecision(
            workspaceId,
            quote.id,
            QuoteDecisionInput(
              accepted: state.accepted,
              revision: revision.revision,
              decidedOn: state.decidedOn,
              source: state.source,
              evidence: state.evidence.text.trim(),
            ),
          );
          if (outcome is QuoteDone) {
            // the server kept the answer: the quote and the list are read again now
            ref
              ..invalidate(customerQuotesProvider(workspaceId))
              ..invalidate(customerQuoteProvider((workspaceId: workspaceId, quoteId: quote.id)));
          }
          return switch (outcome) {
            QuoteDone() => null,
            QuoteRefused(:final refusal) => quoteRefusalText(l10n, refusal),
            QuoteUnreached() => l10n.quoteUnreached,
          };
        },
        builder: (context, refresh) => _fields(context, state, refresh, revision),
      ),
    );
  }
}

/// What the issuer has entered so far.
class _Answer {
  _Answer(this.decidedOn);

  bool accepted = true;
  DateTime decidedOn;
  String source = 'received_outside_app';
  final evidence = TextEditingController();
}

List<Widget> _fields(
  BuildContext context,
  _Answer state,
  VoidCallback refresh,
  QuoteRevision revision,
) {
  final l10n = context.l10n;
  return [
    Text(l10n.quoteIssuerRecordsNote, key: const ValueKey('quote-decision-note')),
    const FormGap(),
    Wrap(
      key: const ValueKey('quote-decision-choice'),
      spacing: 8,
      children: [
        ChoiceChip(
          key: const ValueKey('quote-decision-accepted'),
          label: Text(l10n.quoteAnswerAccepted),
          selected: state.accepted,
          onSelected: (_) {
            state.accepted = true;
            refresh();
          },
        ),
        ChoiceChip(
          key: const ValueKey('quote-decision-declined'),
          label: Text(l10n.quoteAnswerDeclined),
          selected: !state.accepted,
          onSelected: (_) {
            state.accepted = false;
            refresh();
          },
        ),
      ],
    ),
    const FormGap(),
    AppDateField(
      key: const ValueKey('quote-decided-on'),
      label: l10n.quoteFieldDecidedOn,
      value: state.decidedOn,
      first: revision.issuedOn,
      onChanged: (d) {
        state.decidedOn = d.date ?? state.decidedOn;
        refresh();
      },
    ),
    const FormGap(),
    DropdownButtonFormField<String>(
      key: const ValueKey('quote-decision-source'),
      isExpanded: true,
      initialValue: state.source,
      decoration: InputDecoration(labelText: l10n.quoteFieldSource),
      items: [
        for (final s in _decisionSources)
          DropdownMenuItem(
            value: s,
            child: Text(quoteSourceLabel(l10n, s), overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) {
        state.source = v ?? state.source;
        refresh();
      },
    ),
    const FormGap(),
    AppTextField(
      key: const ValueKey('quote-decision-evidence'),
      controller: state.evidence,
      label: l10n.quoteFieldEvidence,
    ),
  ];
}
