// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2470 — the Demo's HMRC (the London space): the same port the live app
// uses, answered from London's own store. A return is filed only after the
// server's own checks and a receipt; every negative files nothing and leaves
// the return prepared; the French and German spaces are never touched.
import 'package:deskilo/core/demo/data/demo_hmrc_repository.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/demo_session.dart';
import 'package:deskilo/core/demo/seed/demo_london_seed.dart';
import 'package:deskilo/features/money/domain/hmrc_submission.dart';
import 'package:deskilo/features/money/domain/mtd_boxes.dart';
import 'package:deskilo/features/money/domain/vat_declaration.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _client = HmrcClientValues(
  browserJsUserAgent: 'Demo',
  deviceId: 'd',
  timezone: 'UTC+00:00',
  screens: 's',
  windowSize: 'w',
  doNotTrack: false,
);

VatDeclaration _prepared(DemoFixture f) => f.london.money.vatDeclarations.single;

Map<String, num> _boxes(VatDeclaration d) => mtdBoxPounds(d);

Future<HmrcConnection> _connect(DemoFixture f) async {
  final hmrc = f.london.hmrc;
  await hmrc.startConnect(demoLondonSpaceId, demoLondonSiteId);
  return (await hmrc.state(demoLondonSpaceId)).connection!;
}

void main() {
  _unknownSpace();
  test('the London space has a prepared return of the last closed quarter, made by the invoices', () {
    final f = DemoFixture.build();
    final d = _prepared(f);
    final quarter = demoLondonQuarter(f.seededAt);
    expect((d.periodStart, d.periodEnd), (quarter.start, quarter.end));
    expect(d.isPrepared, isTrue);
    expect(d.currency, 'GBP');
    // 20 % on three invoices: the box figures follow from the invoices.
    final cents = mtdBoxCents(d);
    expect(cents['vatDueSales'], (125000 + 96050 + 133399) * 20 ~/ 100 + _roundingOf(125000, 96050, 133399));
    expect(cents['totalValueSalesExVAT'], ((125000 + 96050 + 133399 + 33300) ~/ 100) * 100);
    expect(cents['vatDueAcquisitions'], 0);
  });

  test('the French and German spaces have no UK registration and no HMRC door', () async {
    final f = DemoFixture.build();
    for (final id in ['ws-1', 'ws-2']) {
      final s = await f.london.hmrc.state(id);
      expect(s.vrn, isNull, reason: id);
    }
    expect((await f.london.hmrc.state(demoLondonSpaceId)).vrn, demoLondonVrn);
  });

  test('connect, submit once: filed as HMRC\'s with a receipt that says Demo; the other spaces do not move', () async {
    final f = DemoFixture.build();
    final frBefore = f.money.vatDeclarations.map((d) => (d.id, d.status, d.submittedReceipt)).toList();
    final deBefore = f.secondSpace.money.vatDeclarations.map((d) => (d.id, d.status)).toList();
    final connection = await _connect(f);
    final d = _prepared(f);
    final marker = (await f.london.hmrc.state(demoLondonSpaceId)).recoveryMarkers[d.id];
    final outcome = await f.london.hmrc.submit(
      declarationId: d.id,
      connectionId: connection.id,
      boxes: _boxes(d),
      client: _client,
      recoveryMarker: marker,
    );
    expect(outcome, isA<HmrcFiled>());
    final filed = outcome as HmrcFiled;
    expect(filed.demo, isTrue);
    expect(filed.receipt.formBundleNumber, startsWith('DEMO-'));
    final after = _prepared(f);
    expect((after.status, after.submittedChannel, after.submittedReceipt), ('filed', 'hmrc_mtd', filed.receipt.formBundleNumber));
    expect(f.money.vatDeclarations.map((d) => (d.id, d.status, d.submittedReceipt)).toList(), frBefore);
    expect(f.secondSpace.money.vatDeclarations.map((d) => (d.id, d.status)).toList(), deBefore);
    // Once: the filed return is not submitted again.
    final again = await f.london.hmrc.submit(declarationId: d.id, connectionId: connection.id, boxes: _boxes(d), client: _client, recoveryMarker: marker);
    expect(again, isA<HmrcRefused>());
  });

  test('nothing is sent before HMRC is connected', () async {
    final f = DemoFixture.build();
    final d = _prepared(f);
    final marker = (await f.london.hmrc.state(demoLondonSpaceId)).recoveryMarkers[d.id];
    final outcome = await f.london.hmrc.submit(declarationId: d.id, connectionId: 'demo-hmrc-connection', boxes: _boxes(d), client: _client, recoveryMarker: marker);
    expect((outcome as HmrcRefused).refusal, HmrcRefusal.notConnected);
    expect(_prepared(f).isPrepared, isTrue);
  });

  test('a person who is not the owner can neither connect nor file', () async {
    final f = DemoFixture.build()..becomePersona(DemoPersona.admin);
    await expectLater(f.london.hmrc.startConnect(demoLondonSpaceId, demoLondonSiteId), throwsStateError);
    final d = _prepared(f);
    final marker = (await f.london.hmrc.state(demoLondonSpaceId)).recoveryMarkers[d.id];
    final outcome = await f.london.hmrc.submit(declarationId: d.id, connectionId: 'demo-hmrc-connection', boxes: _boxes(d), client: _client, recoveryMarker: marker);
    expect((outcome as HmrcRefused).refusal, HmrcRefusal.notAllowed);
    expect(_prepared(f).isPrepared, isTrue);
  });

  test('one box that differs, box 6 alone, is refused and nothing is filed', () async {
    final f = DemoFixture.build();
    final connection = await _connect(f);
    final d = _prepared(f);
    final marker = (await f.london.hmrc.state(demoLondonSpaceId)).recoveryMarkers[d.id];
    final sent = {..._boxes(d), 'totalValueSalesExVAT': _boxes(d)['totalValueSalesExVAT']! + 1};
    final outcome = await f.london.hmrc.submit(declarationId: d.id, connectionId: connection.id, boxes: sent, client: _client, recoveryMarker: marker);
    expect((outcome as HmrcRefused).refusal, HmrcRefusal.figuresDiffer);
    expect(_prepared(f).isPrepared, isTrue);
  });

  test('prepared data that changed before the confirmation is refused: prepare it again', () async {
    final f = DemoFixture.build();
    final connection = await _connect(f);
    final d = _prepared(f);
    final marker = (await f.london.hmrc.state(demoLondonSpaceId)).recoveryMarkers[d.id];
    final extra = f.london.money.invoices.first;
    f.london.money.invoices.add(extra.copyWith(id: 'uk-inv-late', number: 'CY-late'));
    final outcome = await f.london.hmrc.submit(declarationId: d.id, connectionId: connection.id, boxes: _boxes(d), client: _client, recoveryMarker: marker);
    expect((outcome as HmrcRefused).refusal, HmrcRefusal.figuresDiffer);
    expect(_prepared(f).isPrepared, isTrue);
  });

  test('a quarter that has not ended has no open obligation', () async {
    final f = DemoFixture.build();
    final connection = await _connect(f);
    final d = _prepared(f);
    final early = DemoHmrcRepository(money: f.london.money, workspaces: f.london.workspaces, today: d.periodStart);
    await early.startConnect(demoLondonSpaceId, demoLondonSiteId);
    final outcome = await early.submit(declarationId: d.id, connectionId: connection.id, boxes: _boxes(d), client: _client);
    expect((outcome as HmrcRefused).code, 'TAX_PERIOD_NOT_ENDED');
    expect(_prepared(f).isPrepared, isTrue);
  });

  test('a double activation is one submission: the second is in flight', () async {
    final f = DemoFixture.build();
    final connection = await _connect(f);
    final d = _prepared(f);
    final marker = (await f.london.hmrc.state(demoLondonSpaceId)).recoveryMarkers[d.id];
    final first = f.london.hmrc.submit(declarationId: d.id, connectionId: connection.id, boxes: _boxes(d), client: _client, recoveryMarker: marker);
    final second = f.london.hmrc.submit(declarationId: d.id, connectionId: connection.id, boxes: _boxes(d), client: _client, recoveryMarker: marker);
    expect(((await second) as HmrcRefused).refusal, HmrcRefusal.inFlight);
    expect(await first, isA<HmrcFiled>());
  });

  test('an unconfirmed answer files nothing and invents no receipt; a retry is a new decision', () async {
    final f = DemoFixture.build();
    final scripted = DemoHmrcRepository(
      money: f.london.money,
      workspaces: f.london.workspaces,
      today: f.seededAt,
      script: (attempt) => attempt == 1 ? const HmrcUnconfirmed(code: 'TIMEOUT') : null,
    );
    final connection = (await scripted.startConnect(demoLondonSpaceId, demoLondonSiteId), (await scripted.state(demoLondonSpaceId)).connection!).$2;
    final d = _prepared(f);
    final first = await scripted.submit(declarationId: d.id, connectionId: connection.id, boxes: _boxes(d), client: _client);
    expect(first, isA<HmrcUnconfirmed>());
    expect(_prepared(f).isPrepared, isTrue);
    expect(_prepared(f).submittedReceipt, isEmpty);
    final refused = await scripted.submit(declarationId: d.id, connectionId: connection.id, boxes: _boxes(d), client: _client);
    expect(refused, isA<HmrcUnconfirmed>());
    final marker = (await scripted.state(demoLondonSpaceId)).recoveryMarkers[d.id];
    final second = await scripted.submit(declarationId: d.id, connectionId: connection.id, boxes: _boxes(d), client: _client, recoveryMarker: marker);
    expect(second, isA<HmrcFiled>());
  });

  test('an old check cannot recover a later unconfirmed Demo attempt', () async {
    final f = DemoFixture.build();
    final scripted = DemoHmrcRepository(
      money: f.london.money, workspaces: f.london.workspaces, today: f.seededAt,
      script: (attempt) => attempt <= 2 ? const HmrcUnconfirmed(code: 'TIMEOUT') : null,
    );
    await scripted.startConnect(demoLondonSpaceId, demoLondonSiteId);
    final connection = (await scripted.state(demoLondonSpaceId)).connection!;
    final d = _prepared(f);
    Future<HmrcOutcome> submit([String? marker]) => scripted.submit(
      declarationId: d.id, connectionId: connection.id, boxes: _boxes(d), client: _client, recoveryMarker: marker);
    expect(await submit(), isA<HmrcUnconfirmed>());
    final firstMarker = (await scripted.state(demoLondonSpaceId)).recoveryMarkers[d.id];
    expect(await submit(firstMarker), isA<HmrcUnconfirmed>());
    final secondMarker = (await scripted.state(demoLondonSpaceId)).recoveryMarkers[d.id];
    expect(secondMarker, isNot(firstMarker));
    expect(await submit(firstMarker), isA<HmrcUnconfirmed>());
    expect(_prepared(f).isPrepared, isTrue);
    expect(await submit(secondMarker), isA<HmrcFiled>());
  });

  test('a submit that completes after the persona changed files nothing', () async {
    final f = DemoFixture.build();
    final connection = await _connect(f);
    final d = _prepared(f);
    final marker = (await f.london.hmrc.state(demoLondonSpaceId)).recoveryMarkers[d.id];
    final pending = f.london.hmrc.submit(declarationId: d.id, connectionId: connection.id, boxes: _boxes(d), client: _client, recoveryMarker: marker);
    f.becomePersona(DemoPersona.admin);
    expect(((await pending) as HmrcRefused).refusal, HmrcRefusal.notAllowed);
    expect(_prepared(f).isPrepared, isTrue);
  });

  test('a submit still running on a discarded fixture does not touch the fresh one', () async {
    final old = DemoFixture.build();
    final connection = await _connect(old);
    final d = _prepared(old);
    final marker = (await old.london.hmrc.state(demoLondonSpaceId)).recoveryMarkers[d.id];
    final pending = old.london.hmrc.submit(declarationId: d.id, connectionId: connection.id, boxes: _boxes(d), client: _client, recoveryMarker: marker);
    final fresh = DemoFixture.build();
    await pending;
    expect(_prepared(fresh).isPrepared, isTrue, reason: 'the reset store is its own');
    expect((await fresh.london.hmrc.state(demoLondonSpaceId)).connection, isNull);
  });

  test('the other spaces answer state without a registration and refuse to connect', () async {
    final f = DemoFixture.build();
    for (final id in ['ws-1', 'ws-2']) {
      expect((await f.london.hmrc.state(id)).vrn, isNull, reason: id);
      await expectLater(f.london.hmrc.startConnect(id, 'site'), throwsStateError, reason: id);
    }
  });

  test('London persona isolation: the kiosk does not see the space, the others are three different people', () {
    final f = DemoFixture.build();
    final mine = <DemoPersona, String>{};
    final listed = <DemoPersona, bool>{};
    for (final p in DemoPersona.values) {
      f.becomePersona(p);
      mine[p] = f.london.workspaces.myMember.id;
      listed[p] = f.workspaces.workspaces.any((w) => w.id == demoLondonSpaceId);
    }
    expect(listed[DemoPersona.kiosk], isFalse);
    for (final p in [DemoPersona.owner, DemoPersona.admin, DemoPersona.member]) {
      expect(listed[p], isTrue, reason: p.name);
    }
    expect({mine[DemoPersona.owner], mine[DemoPersona.admin], mine[DemoPersona.member]}, hasLength(3));
  });

  test('a Demo reset while a submit is pending: the pending one lands on the discarded store, the new session stays prepared', () async {
    final root = ProviderContainer();
    addTearDown(root.dispose);
    final controller = root.read(demoSessionControllerProvider.notifier);
    final old = root.read(demoSessionControllerProvider).fixture;
    final connection = await _connect(old);
    final d = _prepared(old);
    final marker = (await old.london.hmrc.state(demoLondonSpaceId)).recoveryMarkers[d.id];
    final pending = old.london.hmrc.submit(declarationId: d.id, connectionId: connection.id, boxes: _boxes(d), client: _client, recoveryMarker: marker);
    controller.reset();
    await pending;
    final fresh = root.read(demoSessionControllerProvider).fixture;
    expect(fresh, isNot(same(old)));
    expect(_prepared(fresh).isPrepared, isTrue);
    expect((await fresh.london.hmrc.state(demoLondonSpaceId)).connection, isNull);
  });
}

/// The rounding of three 20 % lines: each invoice's VAT is rounded alone.
int _roundingOf(int a, int b, int c) =>
    ((a * 20 / 100).round() + (b * 20 / 100).round() + (c * 20 / 100).round()) -
    ((a + b + c) * 20 ~/ 100);

void _unknownSpace() {
  test('a space the Demo does not know fails closed: no space repository is guessed', () async {
    final f = DemoFixture.build();
    final unknown = f.workspaces.workspaces.first.copyWith(id: 'ws-unknown');
    final container = ProviderContainer(
      overrides: [
        ...demoOverrides(f),
        currentWorkspaceProvider.overrideWith((ref) async => unknown),
      ],
    );
    addTearDown(container.dispose);
    await container.read(currentWorkspaceProvider.future);
    expect(() => container.read(moneyRepositoryProvider), throwsA(predicate((e) => e.toString().contains('unknown demo space: ws-unknown'))));
  });
}
