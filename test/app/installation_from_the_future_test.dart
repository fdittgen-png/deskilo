// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3730 (compatibility K3) — an installation from the future: one feature,
// one business kind, one status and one part of a proposal this build does
// not know. Every value goes through the parser the app reads it with; the
// main screens of a business and of Me then open without an error, the
// unknown status is said in words, and the proposal that names an unknown
// feature is shown but never applied.
import 'package:deskilo/core/demo/data/me_repository.dart';
import 'package:deskilo/features/me/domain/personal_workspace_refs.dart';
import 'package:deskilo/features/money/domain/customer_statement_period.dart';
import 'package:deskilo/features/money/domain/purchase_order.dart';
import 'package:deskilo/features/workspace/domain/business_kind.dart';
import 'package:deskilo/features/workspace/domain/business_kind_proposal.dart';
import 'package:deskilo/features/workspace/domain/business_profile.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/business_kind_providers.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/me/me_app.dart';

const _home = '0ea54888-a3d7-441f-a025-ee4576cf2fa9';
const _away = '00000000-0000-4000-8000-0000037300ff';
const _local = '00000000-0000-4000-8000-000003730001';
const _elsewhere = '00000000-0000-4000-8000-000003730002';

/// What the newer installation answers, as it would on the wire.
const _futureFeature = 'futureFeature';
const _futureKind = {
  'code': 'future_kind',
  'sort_order': 9,
  'profile_version': 2,
  'profile_digest': 'abc',
  'feature_profile': {_futureFeature: true, 'invoicing': true},
};
final _futureRefs = {
  'home': {'installation_id': _home},
  'refs': [
    {
      'network_id': '$_home:$_local',
      'hosted_here': true,
      'label': 'Here',
      'status': 'future_status',
      'freshness': 'local',
      'is_default': false,
      'is_favorite': false,
      'audience_fields': <String>[],
    },
    {
      'network_id': '$_away:$_elsewhere',
      'hosted_here': false,
      'label': 'Elsewhere',
      'status': 'active',
      'freshness': 'future_freshness',
      'is_default': false,
      'is_favorite': false,
      'audience_fields': <String>[],
    },
  ],
};

void main() {
  group('each parser reads the future value as unknown', () {
    test('an unknown feature key is ignored', () {
      final on = resolveEnabledFeatures({_futureFeature: true});
      expect(on, resolveEnabledFeatures(const {}));
    });

    test('a proposal naming an unknown feature is shown, never applied', () {
      final kind = BusinessKind.fromJson(_futureKind);
      final proposal = proposalFor(
        profile: kind.profile,
        raw: resolveEnabledFeatures(const {}),
      );
      expect(proposal.unknownKeys, [_futureFeature]);
      expect(proposal.applicable, isFalse);
      expect(proposal.isEmpty, isFalse);
      expect(proposal.flags.keys, isNot(contains(_futureFeature)));
    });

    test('an unknown status and freshness keep the row and grant nothing', () {
      final refs = PersonalWorkspaceRefs.fromJson(_futureRefs);
      expect(refs.refs, hasLength(2));
      expect(refs.refs.first.status, isNull);
      expect(refs.refs.first.statusUnknown, isTrue);
      expect(refs.refs.last.freshness, RefFreshness.unavailable);
    });

    test('an unknown order state is no draft and not open', () {
      final order = PurchaseOrder.fromJson({
        'id': 'po-1',
        'supplier_id': 's-1',
        'state': 'future_locked',
        'revision': 1,
      });
      expect(order.state, PurchaseOrderState.unknown);
      expect(order.stateWire, 'future_locked');
      expect(order.state.open, isFalse);
      expect(order.emailable, isFalse);
      expect(PurchaseOrderState.of('sent'), PurchaseOrderState.sent);
    });

    test('an unknown invoice kind is unknown, never a full invoice', () {
      expect(InvoiceKind.fromWire('future_kind'), InvoiceKind.unknown);
      expect(InvoiceKind.fromWire(null), InvoiceKind.full);
      expect(InvoiceKind.issuable, isNot(contains(InvoiceKind.unknown)));
    });

    test('an unknown statement movement is never "paid"', () {
      final movement = PeriodMovement.fromJson(
        JsonReader.of({
          'decided_on': '2026-11-02',
          'what': 'future_move',
          'amount_cents': 100,
        }, context: 'movement'),
      );
      expect(movement.what, PeriodMovementWhat.unknown);
      expect(PeriodMovementWhat.of('paid'), PeriodMovementWhat.paid);
    });
  });

  testWidgets('the main screens of a business and of Me open without an '
      'error', (tester) async {
    final workspace = twoSpaces();
    workspace.workspaces[0] = workspace.workspaces[0].copyWith(
      networkId: '$_home:$_local',
      featureFlags: {
        ...workspace.workspaces[0].featureFlags,
        _futureFeature: true,
      },
    );
    final me = FakeMeRepository()
      ..workspaceRefs = PersonalWorkspaceRefs.fromJson(_futureRefs);
    final router = await pumpMeApp(
      tester,
      workspace: workspace,
      me: me,
      extraOverrides: [
        businessKindsProvider.overrideWith(
          (ref) async => [BusinessKind.fromJson(_futureKind)],
        ),
        businessProfileProvider.overrideWith(
          (ref) async => const BusinessProfile(kind: 'future_kind'),
        ),
      ],
    );
    expect(tester.takeException(), isNull);
    expect(router.state.uri.path, '/reserve');

    for (final to in const [
      '/workspace-overview',
      '/workspace-settings',
      '/money',
      '/me',
    ]) {
      // A screen the workspace's own rules send elsewhere still lands on a
      // screen of the business: what is asserted is that none fails.
      final landed = await goTo(tester, router, to);
      expect(landed, isNot(startsWith('/auth')), reason: to);
      expect(tester.takeException(), isNull, reason: to);
      expect(find.byType(Scaffold), findsWidgets, reason: to);
    }
    expect(router.state.uri.path, startsWith('/me'));
  });
}
