// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2370 — the interchange envelope (`accounting_interchange_v1`): what one
// fiscal period of an issuer's book hands an accounting system, built from
// the posting engine's answer (`compute_postings`) and the parties of its
// documents (`posting_parties`) as they were read, never derived a second
// time. Its first consumer is the generic journal file; the vendor adapters
// serialise the same envelope.
//
// What the read carries and the envelope therefore carries: the issuer and
// the book profile's revision, the fiscal period, the book's currency, the
// postings with their lines (a tax line names its rate group), and one
// document reference per posted document with its events and its party.
// What it does not carry yet: the invoices' own lines and their tax
// components (the engine answers postings, not documents) and the
// attachments (no read loads them); [AccountingInterchangeV1.attachments]
// stays empty until one does.
//
// Pure Dart.
import 'fiscal_year.dart';
import 'posting.dart';

/// What makes an envelope unfit to write.
enum InterchangeBlock {
  /// The envelope names no issuer.
  missingIssuer,

  /// The book profile the postings were read on has no revision.
  missingRevision,

  /// An entry whose debits and credits differ, or that has no line.
  unbalancedEntry,

  /// A line in another currency than the book's: the engine converts a
  /// document at its recorded rate, so such a line has none.
  unconvertedCurrency,

  /// A posting books a document the envelope does not carry.
  unknownDocument,
}

/// One reason an envelope is refused, and what it is about.
class InterchangeProblem {
  const InterchangeProblem(this.block, this.subject);
  final InterchangeBlock block;

  /// The entry (`number kind`), the document (`number (currency)` or its
  /// id), the book profile; '' for the issuer.
  final String subject;

  @override
  bool operator ==(Object other) =>
      other is InterchangeProblem &&
      other.block == block &&
      other.subject == subject;

  @override
  int get hashCode => Object.hash(block, subject);

  @override
  String toString() => 'InterchangeProblem(${block.name}: $subject)';
}

/// A document the postings book: its id and number, the events posted for
/// it in the period (in posting order), and its third party when the read
/// named one.
class InterchangeDocument {
  const InterchangeDocument({
    required this.id,
    required this.number,
    required this.events,
    this.party,
  });

  final String id;
  final String number;
  final List<PostingKind> events;
  final PostingParty? party;
}

/// A voucher file of a document: the document and the file's sha256.
class InterchangeAttachment {
  const InterchangeAttachment({required this.documentId, required this.sha256});
  final String documentId;
  final String sha256;
}

/// Whose book the envelope is and on which profile it was read: the
/// issuer, the book profile and its revision, the book's currency.
class InterchangeBook {
  const InterchangeBook({
    required this.issuerSiteId,
    required this.profileId,
    required this.revision,
    required this.functionalCurrency,
  });

  final String issuerSiteId;
  final String profileId;
  final int revision;

  /// Every line of the envelope is in it.
  final String functionalCurrency;
}

/// One period of one issuer's book, as an accounting system receives it.
class AccountingInterchangeV1 {
  const AccountingInterchangeV1({
    required this.book,
    required this.period,
    required this.documents,
    required this.postings,
    this.attachments = const [],
  });

  /// The envelope of [postings] (the engine's answer for [period]) on
  /// [book], with the [parties] of their documents by document id. Every
  /// amount is the postings' own.
  factory AccountingInterchangeV1.fromPostings({
    required InterchangeBook book,
    required FiscalYear period,
    required List<Posting> postings,
    Map<String, PostingParty> parties = const {},
  }) {
    final events = <String, ({String number, List<PostingKind> kinds})>{};
    for (final p in postings) {
      events
          .putIfAbsent(
            p.documentId,
            () => (number: p.documentNumber, kinds: <PostingKind>[]),
          )
          .kinds
          .add(p.kind);
    }
    return AccountingInterchangeV1(
      book: book,
      period: period,
      postings: List.unmodifiable(postings),
      documents: List.unmodifiable([
        for (final e in events.entries)
          InterchangeDocument(
            id: e.key,
            number: e.value.number,
            events: List.unmodifiable(e.value.kinds),
            party: parties[e.key],
          ),
      ]),
    );
  }

  /// The schema this envelope follows.
  static const String schema = 'accounting_interchange_v1';

  final InterchangeBook book;
  final FiscalYear period;
  final List<InterchangeDocument> documents;
  final List<Posting> postings;
  final List<InterchangeAttachment> attachments;

  /// Why this envelope must not be written, each reason once, in the
  /// order met; empty when it is fit.
  List<InterchangeProblem> validate() {
    final out = <InterchangeProblem>{};
    if (book.issuerSiteId.trim().isEmpty) {
      out.add(const InterchangeProblem(InterchangeBlock.missingIssuer, ''));
    }
    if (book.revision < 1) {
      out.add(
        InterchangeProblem(InterchangeBlock.missingRevision, book.profileId),
      );
    }
    final known = {for (final d in documents) d.id};
    final currency = book.functionalCurrency.trim().toUpperCase();
    for (final p in postings) {
      if (!known.contains(p.documentId)) {
        out.add(
          InterchangeProblem(InterchangeBlock.unknownDocument, p.documentId),
        );
      }
      if (!p.balanced) {
        out.add(
          InterchangeProblem(
            InterchangeBlock.unbalancedEntry,
            '${p.documentNumber} ${p.kind.wire}',
          ),
        );
      }
      for (final l in p.lines) {
        for (final side in [l.debit.currency, l.credit.currency]) {
          if (side != currency) {
            out.add(
              InterchangeProblem(
                InterchangeBlock.unconvertedCurrency,
                '${p.documentNumber} ($side)',
              ),
            );
          }
        }
      }
    }
    return [...out];
  }
}
