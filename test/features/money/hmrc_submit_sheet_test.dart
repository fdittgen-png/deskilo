// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2470 — "Submit through MTD": the sheet shows the nine boxes the bridging
// CSV writes and sends exactly those; one activation is one submission; every
// outcome is said in words (filed with the receipt, unconfirmed, refused, kept
// but not recorded); a non-web build says to use the web app; and the sheet
// sends nothing before HMRC is connected.
import 'dart:async';

import 'package:deskilo/core/links/link_launcher.dart';
import 'package:deskilo/features/money/data/supabase_hmrc_repository.dart';
import 'package:deskilo/features/money/domain/hmrc_submission.dart';
import 'package:deskilo/features/money/domain/mtd_boxes.dart';
import 'package:deskilo/features/money/domain/vat_declaration.dart';
import 'package:deskilo/features/money/domain/vat_filing_files.dart';
import 'package:deskilo/features/money/presentation/widgets/hmrc_submit_sheet.dart';
import 'package:deskilo/features/money/providers/hmrc_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _en = AppLocalizationsEn();

VatDeclaration _declaration() => VatDeclaration(
  id: 'd1',
  workspaceId: 'ws-1',
  periodStart: DateTime(2026),
  periodEnd: DateTime(2026, 3, 31),
  status: 'prepared',
  lines: [
    const VatDeclarationLine(percent: 20, category: 'S', grossCents: 126600, netCents: 105500, vatCents: 21100, invoiceCount: 4),
    const VatDeclarationLine(percent: 20, category: 'S', grossCents: 28800, netCents: 24000, vatCents: 4800, invoiceCount: 2, direction: 'input'),
  ],
  totalNetCents: 0,
  totalVatCents: 16300,
  currency: 'GBP',
  invoiceCount: 6,
  createdAt: DateTime.utc(2026, 4, 2),
);

const _values = HmrcClientValues(
  browserJsUserAgent: 'Mozilla/5.0',
  deviceId: 'device-1',
  timezone: 'UTC+01:00',
  screens: 'width=1920&height=1080&scaling-factor=1&colour-depth=24',
  windowSize: 'width=1256&height=803',
  doNotTrack: false,
);

class _FakeHmrc implements HmrcRepository {
  _FakeHmrc(this.stateNow, this.outcome);

  HmrcState stateNow;
  final Future<HmrcOutcome> Function() outcome;
  final submitted = <Map<String, num>>[];
  int connects = 0;

  @override
  Future<HmrcState> state(String workspaceId) async => stateNow;

  @override
  Future<Uri> startConnect(String workspaceId, String issuerSiteId) async {
    connects++;
    return Uri.parse('https://www.tax.service.gov.uk/oauth/authorize?x=1');
  }

  @override
  Future<HmrcOutcome> submit({
    required String declarationId,
    required String connectionId,
    required Map<String, num> boxes,
    required HmrcClientValues client,
  }) {
    submitted.add(boxes);
    return outcome();
  }
}

const _connected = HmrcState(
  vrn: '123456789',
  connection: HmrcConnection(id: 'c1', issuerSiteId: 's1', link: HmrcLink.connected),
);

Future<_FakeHmrc> _pump(
  WidgetTester tester, {
  HmrcState state = _connected,
  HmrcClientValues? client = _values,
  Future<HmrcOutcome> Function()? outcome,
  List<Uri>? launched,
}) async {
  final fake = _FakeHmrc(state, outcome ?? () async => const HmrcFiled(HmrcReceipt(formBundleNumber: '256660290587')));
  tester.view.physicalSize = const Size(800, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        hmrcRepositoryProvider.overrideWithValue(fake),
        hmrcClientValuesProvider.overrideWith((ref) async => client),
        linkLauncherProvider.overrideWithValue((uri) async {
          launched?.add(uri);
          return true;
        }),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => hmrcSubmitButton(
              context,
              _declaration(),
              issuerSiteId: 's1',
            ),
          ),
        ),
      ),
    ),
  );
  // The person opens the sheet from the declaration's own button.
  await tester.tap(find.byKey(const ValueKey('vat-decl-mtd-d1')));
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('the sheet shows the nine boxes the bridging CSV writes, and sends exactly those', (tester) async {
    final fake = await _pump(tester);
    final declaration = _declaration();
    final csv = mtdBridgingCsv(declaration: declaration, vatId: 'GB123456789').trim().split('\r\n');
    final header = csv[0].split(',');
    final row = csv[1].split(',');
    for (final field in mtdBoxFields) {
      final cell = row[header.indexOf(field)];
      expect(find.descendant(of: find.byKey(ValueKey('hmrc-box-$field')), matching: find.text(cell)), findsOneWidget, reason: field);
    }
    await tester.tap(find.byKey(const ValueKey('hmrc-submit')));
    await tester.pump();
    await tester.pump();
    expect(fake.submitted, hasLength(1));
    for (final field in mtdBoxFields) {
      final sent = fake.submitted.single[field]!;
      expect(mtdBoxText(field, (sent * 100).round()), row[header.indexOf(field)], reason: field);
    }
  });

  testWidgets('one activation is one submission, even when tapped twice', (tester) async {
    final gate = Completer<HmrcOutcome>();
    final fake = await _pump(tester, outcome: () => gate.future);
    final button = find.byKey(const ValueKey('hmrc-submit'));
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button, warnIfMissed: false);
    await tester.pump();
    expect(fake.submitted, hasLength(1));
    gate.complete(const HmrcFiled(HmrcReceipt(formBundleNumber: '1')));
    await tester.pump();
    expect(fake.submitted, hasLength(1));
  });

  testWidgets('filed: the receipt is said; a Demo receipt says it is simulated', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('hmrc-submit')));
    await tester.pump();
    await tester.pump();
    expect(find.text(_en.hmrcFiled('256660290587')), findsOneWidget);
    await _pump(tester, outcome: () async => const HmrcFiled(HmrcReceipt(formBundleNumber: 'D-1'), demo: true));
    await tester.tap(find.byKey(const ValueKey('hmrc-submit')));
    await tester.pump();
    await tester.pump();
    expect(find.text(_en.hmrcFiledDemo('D-1')), findsOneWidget);
  });

  testWidgets('every other outcome is said in words and none says filed', (tester) async {
    final cases = <HmrcOutcome, String>{
      const HmrcUnconfirmed(): _en.hmrcUnconfirmed,
      const HmrcRefused(HmrcRefusal.alreadySubmitted): _en.hmrcRefusalAlreadySubmitted,
      const HmrcRefused(HmrcRefusal.figuresDiffer): _en.hmrcRefusalFiguresDiffer,
      const HmrcRefused(HmrcRefusal.acquisitionNotSupported): _en.hmrcRefusalAcquisitionNotSupported,
      const HmrcRefused(HmrcRefusal.inFlight): _en.hmrcRefusalInFlight,
      const HmrcAcceptedNotRecorded(HmrcReceipt(formBundleNumber: 'K-9')): _en.hmrcAcceptedNotRecorded('K-9'),
    };
    for (final entry in cases.entries) {
      await _pump(tester, outcome: () async => entry.key);
      await tester.tap(find.byKey(const ValueKey('hmrc-submit')));
      await tester.pump();
      await tester.pump();
      expect(find.text(entry.value), findsOneWidget, reason: '${entry.key}');
      expect(find.textContaining('Filed with HMRC'), findsNothing);
    }
  });

  testWidgets('not connected: no submit, a connect that opens HMRC\'s page', (tester) async {
    final launched = <Uri>[];
    final fake = await _pump(
      tester,
      state: const HmrcState(vrn: '123456789'),
      launched: launched,
    );
    expect(find.byKey(const ValueKey('hmrc-submit')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('hmrc-connect')));
    await tester.pump();
    await tester.pump();
    expect(fake.connects, 1);
    expect(launched.single.host, 'www.tax.service.gov.uk');
    expect(fake.submitted, isEmpty);
  });

  testWidgets('no UK VAT number: nothing to connect or submit', (tester) async {
    await _pump(tester, state: const HmrcState());
    expect(find.byKey(const ValueKey('hmrc-no-vrn')), findsOneWidget);
    expect(find.byKey(const ValueKey('hmrc-connect')), findsNothing);
    expect(find.byKey(const ValueKey('hmrc-submit')), findsNothing);
  });

  testWidgets('off the web build the sheet says to use the web app and offers nothing', (tester) async {
    final fake = await _pump(tester, client: null);
    expect(find.byKey(const ValueKey('hmrc-web-only')), findsOneWidget);
    expect(find.byKey(const ValueKey('hmrc-submit')), findsNothing);
    expect(find.byKey(const ValueKey('hmrc-connect')), findsNothing);
    expect(fake.submitted, isEmpty);
  });

  test('the function\'s refusals map to outcomes by their error, never by status alone', () {
    HmrcRefusal? kind(int status, Map<String, Object?> body) => switch (hmrcOutcomeOfRefusal(status, body)) {
      HmrcRefused(:final refusal) => refusal,
      _ => null,
    };
    expect(kind(409, {'error': 'already_submitted'}), HmrcRefusal.alreadySubmitted);
    expect(kind(409, {'error': 'in_flight'}), HmrcRefusal.inFlight);
    expect(kind(409, {'error': 'accepted_for_other_figures'}), HmrcRefusal.acceptedForOtherFigures);
    expect(kind(409, {'error': 'figures_differ_from_return'}), HmrcRefusal.figuresDiffer);
    expect(kind(422, {'error': 'acquisition_not_supported'}), HmrcRefusal.acquisitionNotSupported);
    expect(kind(422, {'error': 'fraud_headers_missing', 'missing': ['Gov-Client-Device-ID']}), HmrcRefusal.fraudHeadersMissing);
    expect(kind(403, {}), HmrcRefusal.notAllowed);
    expect(kind(500, {'error': 'weird'}), HmrcRefusal.other);
    expect(hmrcOutcomeOfRefusal(504, {'error': 'unconfirmed'}), isA<HmrcUnconfirmed>());
    expect(hmrcOutcomeOfRefusal(500, {'error': 'accepted_not_recorded', 'receipt': {'formBundleNumber': 'R'}}), isA<HmrcAcceptedNotRecorded>());
  });
}
