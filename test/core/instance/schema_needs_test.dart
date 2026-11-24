// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3729 (K2) — what the installation runs, what the app needs at least and
// what it was built against give one verdict, and a feature's own `since`
// gives another, with its prerequisites. Both are plain tables.
import 'package:deskilo/core/instance/instance_doctor.dart';
import 'package:deskilo/core/instance/schema_compatibility.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

FeatureManifestEntry _entry(
  WorkspaceFeature f, {
  WorkspaceFeature? requires,
  int? since,
}) => FeatureManifestEntry(
  feature: f,
  tier: FeatureTier.platform,
  surface: FeatureSurface.money,
  requires: requires,
  since: since,
);

void main() {
  group('the installation against the app: (server, needs, built) -> verdict', () {
    // needs 700, built against 720.
    const cases = <(int?, SchemaCompatibility)>[
      (null, SchemaCompatibility.behind), // no marker: it predates 0226
      (699, SchemaCompatibility.behind), // below what the app needs
      (700, SchemaCompatibility.current), // exactly what it needs
      (710, SchemaCompatibility.current), // older than built-against, enough
      (720, SchemaCompatibility.current),
      (721, SchemaCompatibility.ahead),
    ];
    for (final (server, verdict) in cases) {
      test('server $server is $verdict', () {
        expect(compareSchema(server, required: 720, needs: 700), verdict);
      });
    }
  });

  group('a feature against the installation', () {
    // B since 718 requires A since 720 (the review's fixture), C under B.
    final manifest = {
      WorkspaceFeature.services: _entry(WorkspaceFeature.services, since: 720),
      WorkspaceFeature.stockManagement: _entry(
        WorkspaceFeature.stockManagement,
        requires: WorkspaceFeature.services,
        since: 718,
      ),
      WorkspaceFeature.stockReceiving: _entry(
        WorkspaceFeature.stockReceiving,
        requires: WorkspaceFeature.stockManagement,
      ),
      WorkspaceFeature.kioskMode: _entry(WorkspaceFeature.kioskMode),
    };
    FeatureSchemaReadiness at(WorkspaceFeature f, int? schema) =>
        featureSchemaReadiness(f, schema, manifest: manifest);

    test('719 withholds B as well as A, and names A', () {
      final b = at(WorkspaceFeature.stockManagement, 719);
      expect(b.state, FeatureSchemaState.withheld);
      expect(b.missing, WorkspaceFeature.services);
      expect(b.missingSince, 720);
      expect(at(WorkspaceFeature.services, 719).missing,
          WorkspaceFeature.services);
    });

    test('a chain: the grandchild is withheld with its grandparent', () {
      final c = at(WorkspaceFeature.stockReceiving, 719);
      expect(c.state, FeatureSchemaState.withheld);
      expect(c.missing, WorkspaceFeature.services);
    });

    test('720 offers all three', () {
      for (final f in [
        WorkspaceFeature.services,
        WorkspaceFeature.stockManagement,
        WorkspaceFeature.stockReceiving,
      ]) {
        expect(at(f, 720).state, FeatureSchemaState.available, reason: f.name);
      }
    });

    test('an unstated requirement means any schema, even none known', () {
      expect(at(WorkspaceFeature.kioskMode, 1).state,
          FeatureSchemaState.available);
      expect(at(WorkspaceFeature.kioskMode, null).state,
          FeatureSchemaState.available);
    });

    test('a schema that cannot be read is unknown, never withheld', () {
      final b = at(WorkspaceFeature.stockManagement, null);
      expect(b.state, FeatureSchemaState.unknown);
      expect(b.offered, isTrue);
    });

    test('a server without a marker (0) withholds everything that states one',
        () {
      expect(at(WorkspaceFeature.services, 0).state,
          FeatureSchemaState.withheld);
    });

    test('effectiveFeatures: the closure, an off parent and an old host', () {
      const raw = {
        WorkspaceFeature.services,
        WorkspaceFeature.stockManagement,
        WorkspaceFeature.stockReceiving,
        WorkspaceFeature.kioskMode,
      };
      Set<WorkspaceFeature> eff(Set<WorkspaceFeature> r, int? s) =>
          effectiveFeatures(r, schema: s, manifest: manifest);
      expect(eff(raw, 719), {WorkspaceFeature.kioskMode});
      expect(eff(raw, 720), raw);
      expect(eff(raw, null), raw, reason: 'unknown withholds nothing');
      expect(
        eff({...raw}..remove(WorkspaceFeature.services), 720),
        {WorkspaceFeature.kioskMode},
        reason: 'an explicitly disabled parent still takes its children',
      );
    });

    test('two installations are judged on their own', () {
      const raw = {WorkspaceFeature.services, WorkspaceFeature.stockManagement};
      final old = effectiveFeatures(raw, schema: 700, manifest: manifest);
      final current = effectiveFeatures(raw, schema: 720, manifest: manifest);
      expect(old, isEmpty);
      expect(current, raw);
    });
  });

  test('the real manifest: stock needs the stock migrations', () {
    for (final f in [
      WorkspaceFeature.stockManagement,
      WorkspaceFeature.stockReceiving,
    ]) {
      expect(featureSchemaReadiness(f, 747).offered, isFalse, reason: f.name);
      expect(featureSchemaReadiness(f, 748).offered, isTrue, reason: f.name);
    }
    final eff = effectiveFeatures({
      WorkspaceFeature.stockManagement,
      WorkspaceFeature.services,
    }, schema: 747);
    expect(eff, isNot(contains(WorkspaceFeature.stockManagement)));
  });

  group('the doctor reads the three numbers', () {
    DoctorFinding at(int marker) => InstanceDoctor.checkSchema(
      [
        {'marker': marker, 'tables': 40},
      ],
      required: 720,
      needs: 700,
    ).single;

    test('below what the app needs is behind, and says both numbers', () {
      final f = at(699);
      expect(f.level, DoctorLevel.alarm);
      expect(f.detail, contains('needs at least 700'));
      expect(f.detail, contains('built against 720'));
    });
    test('between needs and built-against is supported, not behind', () {
      final f = at(710);
      expect(f.level, DoctorLevel.ok);
      expect(f.detail, contains('at least what the app needs (700)'));
    });
    test('exactly built-against is current', () {
      expect(at(720).detail, contains('current'));
    });
  });
}
