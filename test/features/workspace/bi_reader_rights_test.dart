// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2579 — a figure is never kept past the right or the feature that let it
// be read: when either changes, every BI reader asks again (the overview's
// own figures, the cost allocation, the saved views among them), so the
// server's answer under the new rights replaces the one read before.
import 'package:deskilo/features/workspace/domain/bi_saved_view.dart';
import 'package:deskilo/features/workspace/domain/bi_view_memory.dart';
import 'package:deskilo/features/workspace/domain/cost_allocation_rules.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/domain/kpi_overview.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/bi_providers.dart';
import 'package:deskilo/features/workspace/providers/cost_allocation_providers.dart';
import 'package:deskilo/features/workspace/providers/overview_kpi_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';

/// Five active memberships while the reader may see them; refused after.
class _Overview implements OverviewKpiRepository {
  int calls = 0;
  bool refuse = false;

  @override
  Future<OverviewFigure> figure(
    String workspaceId,
    String kpiId, {
    required String fromMonth,
    required String toMonth,
  }) async {
    calls++;
    if (refuse) throw const KpiForbidden();
    return overviewFigureFromJson({
      'value': 5,
      'count': 5,
      'currency': '',
      'quality': const <String>[],
      'reasons': const <String>[],
      'computed_at': '2026-05-02T10:00:00Z',
    });
  }
}

class _Allocation extends UnavailableCostAllocationRepository {
  int calls = 0;

  @override
  Future<CostAllocationKpi> summary(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) {
    calls++;
    return super.summary(workspaceId, fromMonth: fromMonth, toMonth: toMonth);
  }
}

class _Views extends InMemoryBiViewRepository {
  int lists = 0;

  @override
  Future<List<BiSavedView>> list(String workspaceId) {
    lists++;
    return super.list(workspaceId);
  }
}

/// A provider value that follows [live]: a change rebuilds its readers.
T _following<T>(Ref ref, ValueNotifier<T> live) {
  void changed() => ref.invalidateSelf();
  live.addListener(changed);
  ref.onDispose(() => live.removeListener(changed));
  return live.value;
}

void main() {
  late ValueNotifier<Set<WorkspacePermission>> rights;
  late ValueNotifier<Set<WorkspaceFeature>> features;
  late _Overview overview;
  late _Allocation allocation;
  late _Views views;
  late ProviderContainer container;

  setUp(() {
    rights = ValueNotifier({
      WorkspacePermission.viewAnalytics,
      WorkspacePermission.viewFinances,
    });
    features = ValueNotifier({
      WorkspaceFeature.workspaceOverview,
      WorkspaceFeature.purchaseAnalytics,
    });
    overview = _Overview();
    allocation = _Allocation();
    views = _Views();
    container = ProviderContainer(
      overrides: [
        myPermissionsProvider.overrideWith((ref) => _following(ref, rights)),
        enabledFeaturesSyncProvider.overrideWith(
          (ref) => _following(ref, features),
        ),
        overviewKpiRepositoryProvider.overrideWithValue(overview),
        costAllocationRepositoryProvider.overrideWithValue(allocation),
        biViewRepositoryProvider.overrideWithValue(views),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(rights.dispose);
    addTearDown(features.dispose);
  });

  /// Keeps [provider] alive and waits for its current answer.
  Future<Object?> settle<T>(ProviderListenable<AsyncValue<T>> provider) async {
    container.listen(provider, (_, _) {});
    await container.pump();
    for (var i = 0; i < 20 && container.read(provider).isLoading; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    final state = container.read(provider);
    return state.hasError ? state.error : state.value;
  }

  test('an overview figure read under a right is asked again when the right '
      'is revoked, and the refusal replaces it', () async {
    final figure = overviewFigureProvider(
      'ws',
      'people.active_memberships_current',
      '2026-05',
      '2026-05',
    );
    expect(await settle(figure), isA<OverviewFigure>());
    expect(overview.calls, 1);

    overview.refuse = true;
    rights.value = {WorkspacePermission.viewFinances};
    expect(await settle(figure), isA<KpiForbidden>());
    expect(overview.calls, 2);
    expect(
      container.read(figure),
      isA<AsyncError<OverviewFigure>>(),
      reason: 'the reader sees the refusal, not the figure read before; '
          'screens read only a current answer (asData)',
    );
  });

  test('a feature switched off asks the cost allocation again', () async {
    final allocated = costAllocationProvider('ws', '2026-05', '2026-05');
    await settle(allocated);
    expect(allocation.calls, 1);
    features.value = {WorkspaceFeature.workspaceOverview};
    await settle(allocated);
    expect(allocation.calls, 2);
  });

  test('the saved views are read again when a right changes, so a figure '
      'withheld since is withheld here too', () async {
    await settle(biViewsProvider('ws'));
    expect(views.lists, 1);
    rights.value = {WorkspacePermission.viewAnalytics};
    await settle(biViewsProvider('ws'));
    expect(views.lists, 2);
  });
}
