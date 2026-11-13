// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3290 — each Demo space's features, setup guide and values agree with the
// feature manifest, its country and its own records. Expectations come from
// the manifest (`featureManifest`, `effectiveFeatures` over the space's
// country, the server's `feature_effective`), the space's row and its
// invoices, never from the setup code under test. The inventory these rows
// pin is docs/testing/evidence/demo-audit-3290-features.md.
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/demo/data/workspace_repository.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/features/workspace/domain/local_setup.dart';
import 'package:deskilo/features/workspace/domain/setup_status.dart';
import 'package:deskilo/features/workspace/domain/setup_steps.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/local_setup_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Space = ({
  String id,
  FakeWorkspaceRepository rows,
  FakeMoneyRepository money,
});

List<_Space> _spaces(DemoFixture f) => [
  (id: 'ws-1', rows: f.workspaces, money: f.money),
  (id: 'ws-2', rows: f.secondSpace.workspaces, money: f.secondSpace.money),
  (id: 'ws-3', rows: f.london.workspaces, money: f.london.money),
  (id: 'ws-4', rows: f.newYork.workspaces, money: f.newYork.money),
  (id: 'ws-5', rows: f.zurich.workspaces, money: f.zurich.money),
  (id: 'ws-6', rows: f.milan.workspaces, money: f.milan.money),
];

Workspace _row(_Space s) => s.rows.workspaces.singleWhere((w) => w.id == s.id);

/// What the server would call effective in [w]: on, with its whole chain,
/// and offered in the space's country.
Set<WorkspaceFeature> _effective(Workspace w) => effectiveFeatures(
  resolveEnabledFeatures(w.featureFlags),
  country: w.countryCode,
);

LocalSetupRepository _guide(DemoFixture f) {
  final c = ProviderContainer(overrides: demoOverrides(f));
  addTearDown(c.dispose);
  return c.read(localSetupRepositoryProvider);
}

SetupStepState _state(SetupStatus s, String step) =>
    s.steps.singleWhere((x) => x.step == step).state;

void main() {
  final fixture = DemoFixture.build();

  for (final space in _spaces(fixture)) {
    group('${space.id}:', () {
      test('a step applies exactly when the manifest and the country make '
          'its feature effective', () async {
        final w = _row(space);
        final effective = _effective(w);
        final status = await _guide(fixture).setupStatus(space.id);
        for (final step in setupSteps) {
          final applies = step.feature == null ||
              effective.contains(step.feature);
          expect(
            _state(status, step.id) != SetupStepState.notApplicable,
            applies,
            reason: '${step.id} (${step.feature?.name}) in ${w.countryCode}',
          );
        }
      });

      test('every VAT rate its invoices charge is a rate it holds, and a '
          'space not subject to VAT has no VAT step', () async {
        final w = _row(space);
        final status = await _guide(fixture).setupStatus(space.id);
        final vatOn = _effective(w).contains(WorkspaceFeature.vatManagement);
        if (w.vatRegime != 'vat_registered') {
          expect(vatOn, isFalse, reason: 'regime ${w.vatRegime}');
          expect(_state(status, 'vat'), SetupStepState.notApplicable);
          return;
        }
        final charged = {
          for (final i in space.money.invoices)
            if (i.workspaceId == space.id)
              for (final l in i.lines) l.vatPercent,
        };
        final held = {for (final r in space.money.vatRates) r.percent};
        expect(held, containsAll(charged));
        expect(_state(status, 'vat'), SetupStepState.ready);
      });

      test('the row\'s values are its country\'s', () {
        final w = _row(space);
        final expected = const {
          'FR': ('EUR', 'Europe/Paris'),
          'DE': ('EUR', 'Europe/Berlin'),
          'GB': ('GBP', 'Europe/London'),
          'US': ('USD', 'America/New_York'),
          'CH': ('CHF', 'Europe/Zurich'),
          'IT': ('EUR', 'Europe/Rome'),
        }[w.countryCode];
        expect((w.currencyCode, w.timezone), expected);
        expect(
          {
            for (final i in space.money.invoices)
              if (i.workspaceId == space.id) i.currency,
          },
          {w.currencyCode},
        );
      });
    });
  }

  test('the development twin carries its production\'s configuration', () {
    final rows = fixture.workspaces.workspaces;
    final prod = rows.singleWhere((w) => w.id == 'ws-1');
    final dev = rows.singleWhere((w) => w.environment == 'dev');
    expect(prod.pairId, isNotEmpty);
    expect(dev.pairId, prod.pairId);
    expect(_effective(dev), _effective(prod));
    expect(
      (dev.countryCode, dev.currencyCode, dev.timezone, dev.vatRegime),
      (prod.countryCode, prod.currencyCode, prod.timezone, prod.vatRegime),
    );
  });

  test('a feature switched off in London stays London\'s, survives a persona '
      'switch, and a reset restores it', () async {
    final f = DemoFixture.build();
    final guide = _guide(f);
    final before = {
      for (final s in _spaces(f)) s.id: _state(await guide.setupStatus(s.id), 'kiosk'),
    };
    expect(before['ws-3'], isNot(SetupStepState.notApplicable));

    await f.london.workspaces.setFeatureFlags('ws-3', {
      WorkspaceFeature.kioskMode.dbKey: false,
    });
    f
      ..becomePersona(DemoPersona.member)
      ..becomePersona(DemoPersona.owner);
    final after = {
      for (final s in _spaces(f)) s.id: _state(await guide.setupStatus(s.id), 'kiosk'),
    };
    expect(after['ws-3'], SetupStepState.notApplicable);
    expect({...after}..remove('ws-3'), {...before}..remove('ws-3'));
    expect(
      _effective(_row(_spaces(f)[2])),
      isNot(contains(WorkspaceFeature.kioskMode)),
    );

    final fresh = DemoFixture.build();
    expect(
      _state(await _guide(fresh).setupStatus('ws-3'), 'kiosk'),
      before['ws-3'],
    );
  });
}
