// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1916 — the payment clauses an invoice prints are qualified by the law
// of the transaction (the seller's country) and the customer's stated
// capacity, frozen at issue; never by the reader's language or the
// seller's legal form.
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_clauses.dart';
import 'package:deskilo/features/money/domain/invoice_legal.dart';
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/domain/payment_terms.dart';
import 'package:deskilo/features/money/domain/report_data.dart';
import 'package:deskilo/features/money/domain/report_data_letters.dart';
import 'package:deskilo/features/money/domain/report_facts.dart';
import 'package:deskilo/features/money/domain/report_strings.dart';
import 'package:deskilo/features/money/presentation/report_defaults.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:flutter_test/flutter_test.dart';

const _en = ReportStrings();

/// The French wording of the same defaults — a translation, not a
/// different rule.
const _fr = ReportStrings(
  paymentTermsDefault: 'Règlement à réception.',
  latePenaltyDefault:
      "Pénalités de retard : trois fois le taux d'intérêt légal.",
  recoveryDefault: 'Indemnité forfaitaire pour frais de recouvrement : 40 €.',
  escompteDefault: 'Aucun escompte pour paiement anticipé.',
);

Workspace _workspace(String country, [Map<String, dynamic> legal = const {}]) =>
    Workspace(
      id: 'ws-1',
      name: 'Espace',
      countryCode: country,
      currencyCode: country == 'US' ? 'USD' : 'EUR',
      timezone: 'Europe/Paris',
      inviteCode: 'CODE123456',
      invoiceLegal: legal,
    );

LegalClauseSnapshot _snap(
  String country,
  CustomerCapacity capacity, {
  PaymentTerms clauses = PaymentTerms.empty,
  String kind = '',
}) => LegalClauseSnapshot(
  sellerCountry: country,
  buyerCapacity: capacity,
  clauses: clauses,
  sellerKind: kind,
);

const _ownerTerms = PaymentTerms(
  paymentTerms: 'Payment within 30 days.',
  latePenalty: 'Late interest at the agreed rate.',
  recoveryIndemnity: 'Fixed recovery indemnity: €40.',
  escompte: 'No discount.',
);

Invoice _invoice({
  Map<String, Object?>? snapshot,
  String number = 'F-2026-0001',
}) => Invoice(
  id: 'inv-1',
  workspaceId: 'ws-1',
  memberId: 'm1',
  number: number,
  issuedAt: DateTime(2026, 7, 1),
  title: '2026-07',
  lines: const [InvoiceLine(label: 'Desk', amountCents: 12000)],
  totalCents: 12000,
  currency: 'EUR',
  memberName: 'Ana Martin',
  memberAddress: '',
  workspaceName: 'Espace',
  workspaceAddress: '',
  issuerName: 'Espace',
  signature: 'sig',
  legalSnapshot: snapshot,
);

void main() {
  group('the same reader language, four transactions', () {
    test('FR business: the L441-10 clauses print, defaulted when empty', () {
      final q = qualifyClauses(_snap('FR', CustomerCapacity.business), _en);
      expect(q.profile, LegalProfile.frBusiness);
      expect(q.latePenalty.basis, ClauseBasis.statutoryDefault);
      expect(q.latePenalty.text, _en.latePenaltyDefault);
      expect(q.recoveryIndemnity.text, _en.recoveryDefault);
      expect(q.escompte.text, _en.escompteDefault);
    });

    test('FR consumer: no automatic clause and never the €40 indemnity, '
        'even when the owner typed it', () {
      final q = qualifyClauses(
        _snap('FR', CustomerCapacity.consumer, clauses: _ownerTerms),
        _en,
      );
      expect(q.profile, LegalProfile.frConsumer);
      expect(q.recoveryIndemnity.text, isEmpty);
      expect(q.recoveryIndemnity.basis, ClauseBasis.notApplicable);
      expect(
        q.latePenalty.basis,
        ClauseBasis.requiresReview,
        reason: 'a consumer penalty may not override consumer protection',
      );
      expect(q.deficiencies, contains('recovery_indemnity_not_applicable'));

      final none = qualifyClauses(_snap('FR', CustomerCapacity.consumer), _en);
      expect(none.latePenalty.text, isEmpty);
      expect(none.recoveryIndemnity.text, isEmpty);
      expect(none.escompte.text, isEmpty);
    });

    test('DE business: German law makes no invoice mention of it, so '
        'nothing is printed automatically — and never the French rule', () {
      final q = qualifyClauses(_snap('DE', CustomerCapacity.business), _en);
      expect(q.profile, LegalProfile.deBusiness);
      expect(q.latePenalty.text, isEmpty);
      expect(q.recoveryIndemnity.text, isEmpty);
      expect(q.escompte.text, isEmpty);
      final owned = qualifyClauses(
        _snap('DE', CustomerCapacity.business, clauses: _ownerTerms),
        _en,
      );
      expect(
        owned.recoveryIndemnity,
        const QualifiedClause(
          'Fixed recovery indemnity: €40.',
          ClauseBasis.owner,
        ),
      );
    });

    test('US: unsupported — nothing automatic, no EU indemnity at all', () {
      for (final capacity in CustomerCapacity.values) {
        final q = qualifyClauses(
          _snap('US', capacity, clauses: _ownerTerms),
          _en,
        );
        expect(q.profile, LegalProfile.unsupported);
        expect(q.recoveryIndemnity.text, isEmpty);
        expect(q.deficiencies, contains('profile_unsupported'));
      }
      final bare = qualifyClauses(_snap('US', CustomerCapacity.business), _en);
      expect(bare.latePenalty.text, isEmpty);
      expect(bare.escompte.text, isEmpty);
    });

    test(
      'the document data follows the seller country, not the language: '
      'a German seller never prints the French penalty (red before #1916)',
      () {
        final de = legalMentionData(
          _en,
          _workspace('DE', const {'customer_capacity': 'business'}),
        );
        expect(de['late_penalty'], '');
        expect(de['recovery_indemnity'], '');
        final fr = legalMentionData(
          _en,
          _workspace('FR', const {'customer_capacity': 'business'}),
        );
        expect(fr['late_penalty'], _en.latePenaltyDefault);
      },
    );

    test('changing the reader language changes the words, never which '
        'clauses apply', () {
      for (final country in ['FR', 'DE', 'US']) {
        for (final capacity in CustomerCapacity.values) {
          final en = qualifyClauses(_snap(country, capacity), _en);
          final fr = qualifyClauses(_snap(country, capacity), _fr);
          for (final (a, b) in [
            (en.latePenalty, fr.latePenalty),
            (en.recoveryIndemnity, fr.recoveryIndemnity),
            (en.escompte, fr.escompte),
          ]) {
            expect(a.basis, b.basis, reason: '$country $capacity');
            expect(
              a.text.isEmpty,
              b.text.isEmpty,
              reason: '$country $capacity',
            );
          }
        }
      }
    });
  });

  group('capacity is the customer\'s, stated — not the seller\'s kind', () {
    test('an association selling to a business prints the B2B clauses', () {
      final q = qualifyClauses(
        _snap('FR', CustomerCapacity.business, kind: 'association'),
        _en,
      );
      expect(q.recoveryIndemnity.basis, ClauseBasis.statutoryDefault);
      final data = legalMentionData(
        _en,
        _workspace('FR', const {'seller_kind': 'association'}),
        memberCapacity: 'business',
      );
      expect(data['recovery_indemnity'], _en.recoveryDefault);
    });

    test('a company selling to a consumer prints no indemnity', () {
      final data = legalMentionData(
        _en,
        _workspace('FR'),
        memberTerms: _ownerTerms,
        memberCapacity: 'consumer',
      );
      expect(data['recovery_indemnity'], '');
    });

    test('a sole trader is a business only when stated; a VAT number does '
        'not make a consumer a business', () {
      final soleTrader = legalMentionData(
        _en,
        _workspace('FR'),
        buyer: const InvoiceParty(name: 'Jean Dupont'),
        memberCapacity: 'business',
      );
      expect(soleTrader['recovery_indemnity'], _en.recoveryDefault);
      final consumerWithVat = legalMentionData(
        _en,
        _workspace('FR'),
        buyer: const InvoiceParty(
          name: 'Jean Dupont',
          vatId: 'FR12345678901',
          company: 'JD',
        ),
        memberCapacity: 'consumer',
      );
      expect(consumerWithVat['recovery_indemnity'], '');
      final unstated = qualifyClauses(
        LegalClauseSnapshot.live(
          legal: const InvoiceLegal(),
          sellerCountry: 'FR',
        ),
        _en,
      );
      expect(unstated.profile, LegalProfile.capacityUnknown);
      expect(
        unstated.recoveryIndemnity.text,
        isEmpty,
        reason: 'no default is applied to an unstated capacity',
      );
      expect(unstated.deficiencies, contains('capacity_unknown'));
    });

    test('the member\'s own capacity wins over the workspace default', () {
      final live = LegalClauseSnapshot.live(
        legal: const InvoiceLegal(customerCapacity: 'business'),
        sellerCountry: 'FR',
        memberCapacity: 'consumer',
      );
      expect(live.buyerCapacity, CustomerCapacity.consumer);
      expect(live.capacitySource, 'member');
    });
  });

  group('an issued invoice reads its frozen snapshot', () {
    final frozen = <String, Object?>{
      'schema': 1,
      'seller_kind': '',
      'seller_country': 'FR',
      'buyer_country': 'FR',
      'buyer_capacity': 'business',
      'capacity_source': 'member',
      'terms_source': 'workspace',
      'clauses': {'payment_terms': 'Payment within 30 days.'},
      'legal_form': 'SARL au capital de 7 500 €',
      'registration': 'RCS Béziers 123',
      'insurance': '',
      'special_mentions': '',
      'vat_exigibility': 'invoice',
      'fingerprint': 'abc',
    };

    test('later settings, kind and capacity never rewrite it', () {
      final changed = _workspace('DE', const {
        'seller_kind': 'association',
        'customer_capacity': 'consumer',
        'payment_terms': 'Payment on receipt only.',
        'legal_form': 'e.V.',
      });
      final data = invoiceReportData(
        _en,
        _invoice(snapshot: frozen),
        proforma: false,
        copy: false,
        workspace: changed,
        memberCapacity: 'consumer',
      );
      expect(data['payment_terms'], 'Payment within 30 days.');
      expect(data['late_penalty'], _en.latePenaltyDefault);
      expect(data['recovery_indemnity'], _en.recoveryDefault);
      expect(data['seller_legal_form'], 'SARL au capital de 7 500 €');
    });

    test('Invoice.fromRow carries the snapshot; a legacy row has none', () {
      expect(
        _invoice(snapshot: frozen).legalClauses?.buyerCapacity,
        CustomerCapacity.business,
      );
      expect(_invoice().legalClauses, isNull);
      expect(isLegacyInvoice(_invoice()), isTrue);
      expect(
        isLegacyInvoice(_invoice(number: '')),
        isFalse,
        reason: 'an unnumbered preview qualifies live',
      );
    });

    test('a legacy invoice renders exactly as it did before the snapshot', () {
      final data = invoiceReportData(
        _en,
        _invoice(),
        proforma: false,
        copy: false,
        workspace: _workspace('FR'),
      );
      expect(data['late_penalty'], _en.latePenaltyDefault);
      final association = invoiceReportData(
        _en,
        _invoice(),
        proforma: false,
        copy: false,
        workspace: _workspace('FR', const {'seller_kind': 'association'}),
      );
      expect(association['late_penalty'], '');
    });
  });

  group('reminders', () {
    String letter(Map<String, Object?> data, String kind) {
      final report = renderReportBands(
        bands: defaultBandsForDoc(kind, null),
        data: data,
      )!;
      return [
        ...report.header,
        ...report.body,
        ...report.footer,
      ].map(_blockText).join('\n');
    }

    test('every reminder stage cites the one frozen indemnity, never one '
        'per stage', () {
      final invoice = _invoice(
        snapshot: {
          'seller_country': 'FR',
          'buyer_capacity': 'business',
          'clauses': const <String, Object?>{},
        },
      );
      final texts = <String>[];
      for (final (level, kind) in [(1, 'r1'), (2, 'r2'), (3, 'r3')]) {
        final data = reminderReportData(
          _en,
          ReminderFacts(now: DateTime(2026, 8, 1), workspace: _workspace('FR')),
          invoice,
          level: level,
        );
        expect(data['recovery_indemnity'], _en.recoveryDefault);
        final text = letter(data, kind);
        expect(
          '€40'.allMatches(text).length,
          lessThanOrEqualTo(1),
          reason: 'stage $level',
        );
        texts.add(data['recovery_indemnity']! as String);
      }
      expect(texts.toSet(), hasLength(1));
    });

    test('a consumer reminder carries no EU indemnity, typed or not', () {
      final invoice = _invoice(
        snapshot: {
          'seller_country': 'FR',
          'buyer_capacity': 'consumer',
          'clauses': {'recovery_indemnity': 'Fixed recovery indemnity: €40.'},
        },
      );
      final data = reminderReportData(
        _en,
        ReminderFacts(now: DateTime(2026, 8, 1), workspace: _workspace('FR')),
        invoice,
        level: 2,
      );
      expect(data['recovery_indemnity'], '');
      expect(letter(data, 'r2'), isNot(contains('€40')));
    });
  });
}

String _blockText(ReportBlock block) => switch (block) {
  ReportHeading(:final text) => text,
  ReportSubheading(:final text) => text,
  ReportText(:final text) => text,
  ReportMuted(:final text) => text,
  ReportTableRow(:final cells) => cells.join(' | '),
  ReportImage(:final name) => '[image:$name]',
  ReportColumns(:final columns) => [
    for (final column in columns) column.map(_blockText).join('\n'),
  ].join('\n'),
  ReportDivider() => '',
  ReportSpacer() => '',
};
