// SPDX-License-Identifier: 0BSD
//
// #1061 slice two — the five remaining builders are pure functions of a
// ReportStrings and their facts: no widget pump, no ProviderScope, no
// BuildContext. This is the acceptance the plan (#1048 task 3.1) asked
// for — "the builders are unit-tested with no widget pump".
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/fee_band.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/report_facts.dart';
import 'package:deskilo/features/money/domain/report_strings.dart';
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:deskilo/features/money/domain/statement.dart';
import 'package:deskilo/features/money/presentation/invoice_actions.dart';
import 'package:deskilo/features/money/presentation/report_strings_l10n.dart';
import 'package:deskilo/features/plan/domain/level.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/l10n/app_localizations_fr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _workspace = Workspace(
  id: 'ws-1',
  name: 'Test Space',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'CODE123456',
  invoiceLegal: {'is_association': false},
);

final _now = DateTime(2026, 7, 31);

const _band = FeeBand(
    id: 'b1', workspaceId: 'ws-1', fromPct: 0, toPct: 100,
    feeCents: 20000, overageFeeCents: 1500);
const _service = ServiceItem(
    id: 's1', workspaceId: 'ws-1', name: 'Coffee', priceCents: 150,
    active: true);

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  group('agreementReportData', () {
    final facts = AgreementFacts(
      now: _now,
      workspace: _workspace,
      bands: const [_band],
      services: const [_service],
      levels: const [
        Level(id: 'l1', workspaceId: 'ws-1', name: 'Loft', sortOrder: 1),
      ],
    );
    test('prices the member\'s band, the extra half-day and the catalogue',
        () {
      final data = agreementReportData(const ReportStrings(), facts,
          memberName: 'Ana', subscriptionPct: 50);
      final lines = (data['lines'] as List).cast<Map<String, Object?>>();
      expect(lines.map((l) => l['label']),
          ['Subscription 50%', 'Extra half-day', 'Coffee']);
      expect(data['total'], isNotEmpty);
      expect(data['member'], 'Ana');
      expect(data['issued'], 'Jul 31, 2026');
    });
    test('speaks the reader\'s language, dates included', () {
      final data = agreementReportData(
          reportStringsOf(AppLocalizationsFr(), dateLocale: 'fr'), facts,
          memberName: 'Ana', subscriptionPct: 50);
      final lines = (data['lines'] as List).cast<Map<String, Object?>>();
      expect(lines[1]['label'], AppLocalizationsFr().agreementExtraHalfDay);
      expect(data['issued'], '31 juil. 2026');
    });
    test('an unbanded percentage lists only the catalogue', () {
      final data = agreementReportData(const ReportStrings(),
          AgreementFacts(now: _now, services: const [_service]),
          memberName: 'Ana', subscriptionPct: 50);
      expect((data['lines'] as List).length, 1);
      expect(data['total'], '');
    });
  });

  group('paymentsReportData', () {
    const me = Member(
        id: 'm1', workspaceId: 'ws-1', userId: 'u1', isAdmin: false,
        isOwner: false, status: MemberStatus.active);
    final facts = PaymentsFacts(
      now: _now,
      workspace: _workspace,
      me: me,
      ledger: [
        LedgerEntry(
            id: 'e1', memberId: 'm1', kind: LedgerKind.credit,
            category: LedgerCategory.payment, amountCents: 5000,
            description: '', period: '2026-07', createdAt: _now),
        LedgerEntry(
            id: 'e2', memberId: 'm1', kind: LedgerKind.credit,
            category: LedgerCategory.payment, amountCents: 100,
            description: 'old', period: '2026-06', createdAt: _now),
      ],
      events: [
        WorkspaceEvent(
            id: 'ev1', workspaceId: 'ws-1', type: EventType.payment,
            action: EventAction.created, actorMemberId: 'm1',
            subjectMemberId: 'm1',
            payload: const {'amount_cents': 2500, 'period': '2026-07'},
            status: EventStatus.pending, createdAt: _now),
      ],
    );
    test('keeps the period\'s credits and the pending submissions', () {
      final data = paymentsReportData(const ReportStrings(), facts,
          period: '2026-07', memberName: 'Ana');
      final lines = (data['lines'] as List).cast<Map<String, Object?>>();
      expect(lines.length, 2, reason: 'June stays out');
      expect(lines[0]['label'], endsWith(' · Payments & credits'));
      expect(lines[1]['label'], 'Payment — pending validation');
      expect(data['pending_payments_total'], isNot(''));
      expect(data['total'], isNotEmpty);
    });
  });

  group('workspaceReportData', () {
    test('counts, hours, features and prices from the facts alone', () {
      final data = workspaceReportData(
        const ReportStrings(),
        WorkspaceFacts(
          now: _now,
          workspace: _workspace,
          featureLabels: const ['Kiosk mode', 'Services'],
          membersCount: 7,
          bands: const [_band],
          services: const [_service],
          openDays: const [1, 5],
        ),
      );
      expect(data['members_count'], 7);
      expect(data['open_days'], 'Mon, Fri');
      expect((data['features'] as List).length, 2);
      final lines = (data['lines'] as List).cast<Map<String, Object?>>();
      expect(lines.first['label'], 'Subscription 100% (1–100%)');
      expect(data['country'], 'FR');
    });
  });

  group('reminderReportData', () {
    final invoice = Invoice(
      id: 'inv-1', workspaceId: 'ws-1', memberId: 'm1',
      number: 'INV-2026-0007', issuedAt: DateTime(2026, 7, 1),
      title: '2026-07', lines: const [], totalCents: 12000,
      currency: 'EUR', memberName: 'Ana Martin', memberAddress: '',
      workspaceName: 'Test Space', workspaceAddress: '', issuerName: 'Flo',
      signature: 'f',
    );
    test('the level, the letter date and the days open', () {
      final data = reminderReportData(const ReportStrings(),
          ReminderFacts(now: _now, workspace: _workspace), invoice,
          level: 2);
      expect(data['reminder_level'], 2);
      expect(data['days_open'], 30);
      expect(data['reminder_date'], 'Jul 31, 2026');
      expect(data['payment_terms'], 'Payment on receipt.');
    });
  });

  group('statementReportData', () {
    test('every supplement that is owed becomes a line', () {
      const statement = Statement(
        period: '2026-07', subscriptionPct: 50, feeCents: 15000,
        includedHalfDays: 10, openDays: 22, usedHalfDays: 13,
        extraHalfDays: 3, overageCents: 4500, creditsCents: -10000,
        balanceCents: 9500, deskSupplementCents: 300,
      );
      final data = statementReportData(const ReportStrings(),
          statement: statement, workspaceName: 'Test Space',
          memberName: 'Ana', periodLabel: 'July 2026', currencyCode: 'EUR',
          workspace: _workspace);
      final lines = (data['lines'] as List).cast<Map<String, Object?>>();
      expect(lines.map((l) => l['label']), [
        'Subscription 50%', '3 extra half-days', 'Desk reservations',
        'Payments & credits',
      ]);
    });
  });
}
