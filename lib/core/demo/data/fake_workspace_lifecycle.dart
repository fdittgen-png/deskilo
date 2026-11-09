// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2597 -- the in-memory half of WorkspaceLifecycle: moved verbatim out of the part
// files; the state it reads is `FakeWorkspaceState`.
import 'dart:async';

import 'package:deskilo/features/workspace/domain/feature_flags_write.dart';
import 'package:deskilo/features/workspace/domain/membership_repository.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_identity_repository.dart';
import 'package:deskilo/features/workspace/domain/workspace_lifecycle_repository.dart';
import 'package:deskilo/features/workspace/domain/workspace_overview.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/domain/workspace_settings_save.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'fake_workspace_state.dart';

mixin FakeWorkspaceLifecycle on FakeWorkspaceState
    implements
        WorkspaceLifecycleRepository,
        WorkspaceIdentityRepository,
        MembershipRepository {
  /// Workspace-wide dev mode (#419): mirrors the 0081 column + RPC.
  /// Admin-gated like the server; [applyDevMode] seeds the initial state.
  void applyDevMode({required bool enabled}) {
    for (var i = 0; i < workspaces.length; i++) {
      workspaces[i] = workspaces[i].copyWith(devMode: enabled);
    }
  }

  @override
  Future<void> setDevMode(String workspaceId, {required bool enabled}) async {
    if (!myMember.canAdminister) {
      throw const PostgrestException(message: 'not an admin of this workspace');
    }
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i >= 0) workspaces[i] = workspaces[i].copyWith(devMode: enabled);
  }

  @override
  Future<List<Workspace>> fetchMyWorkspaces() async {
    if (fetchFailure case final failure?) throw failure;
    return List.of(workspaces);
  }

  @override
  Future<bool> isPlatformOwner() async => platformOwner;
  @override
  Future<List<WorkspaceOverview>> fetchAllWorkspaces() async {
    if (!platformOwner) throw StateError('platform owners only');
    return List.of(allWorkspaces);
  }

  @override
  Future<List<WorkspaceOwner>> fetchWorkspaceOwners(String workspaceId) async {
    if (!platformOwner) throw StateError('platform owners only');
    ownerReads.add(workspaceId);
    return List.of(ownersByWorkspace[workspaceId] ?? const []);
  }

  @override
  Future<String> createWorkspace({
    required String name,
    required String countryCode,
    required String currencyCode,
    required String timezone,
    WorkspaceEnvironment environment = WorkspaceEnvironment.development,
    bool withTwin = true,
    String? requestId,
    String? templateId,
  }) async {
    // #1303 — the server's replay rule: one workspace per request id.
    final replayed = requestId == null ? null : createdByRequest[requestId];
    if (replayed != null) return replayed;
    createRequests.add((
      requestId: requestId,
      templateId: templateId,
      withTwin: withTwin,
    ));
    final failure = createFailure;
    if (failure != null) {
      createFailure = null;
      throw failure;
    }
    final workspace = Workspace(
      id: 'ws-created-${nextId++}',
      rolePermissions: everydayMatrix(),
      name: name,
      countryCode: countryCode,
      currencyCode: currencyCode,
      timezone: timezone,
      inviteCode: 'NEWCODE$nextId',
      // #917 — what the server's default does, mirrored here.
      environment: environment.wire,
    );
    workspaces.add(workspace);
    if (requestId != null) createdByRequest[requestId] = workspace.id;
    return workspace.id;
  }

  @override
  Future<String> createWorkspaceTwin(String workspaceId) async {
    final index = workspaces.indexWhere((w) => w.id == workspaceId);
    if (index < 0) throw StateError('unknown workspace');
    final source = workspaces[index];
    if (source.pairId.isNotEmpty) {
      throw StateError('this workspace already has its twin');
    }
    final pair = 'pair-${twinsCreated.length + 1}';
    workspaces[index] = source.copyWith(pairId: pair);
    final twin = source.copyWith(
      id: '${source.id}-twin',
      pairId: pair,
      environment: source.environment == 'prod' ? 'dev' : 'prod',
    );
    workspaces.add(twin);
    twinsCreated.add(twin.id);
    return twin.id;
  }

  @override
  Future<void> setWorkspaceEnvironment(
    String workspaceId,
    WorkspaceEnvironment environment,
  ) async {
    lastEnvironment = environment.wire;
    final index = workspaces.indexWhere((w) => w.id == workspaceId);
    if (index >= 0) {
      workspaces[index] = workspaces[index].copyWith(
        environment: environment.wire,
      );
    }
  }

  @override
  Future<String> setWorkspaceCode(String workspaceId, String code) async {
    final normalized = code.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{4,20}$').hasMatch(normalized)) {
      throw StateError('workspace ID must be 4-20 letters or digits');
    }
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i >= 0) workspaces[i] = workspaces[i].copyWith(inviteCode: normalized);
    return normalized;
  }

  @override
  Future<void> setFeatureFlags(
    String workspaceId,
    Map<String, bool> flags, {
    Map<String, bool>? expected,
  }) async {
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i < 0) throw StateError('unknown workspace $workspaceId');
    flagExpectations.add(expected == null ? null : Map.of(expected));
    if (flagConflictNext) {
      flagConflictNext = false;
      throw FeatureFlagsConflict(expected?.keys.take(1).toList() ?? const []);
    }
    // #1329 — the server compares the read-set through the registry
    // defaults (feature_raw); the fake resolves the same way.
    if (expected != null) {
      final current = resolveEnabledFeatures(workspaces[i].featureFlags);
      final stale = [
        for (final e in expected.entries)
          if (current.any((WorkspaceFeature f) => f.dbKey == e.key) != e.value)
            e.key,
      ]..sort();
      if (stale.isNotEmpty) throw FeatureFlagsConflict(stale);
    }
    flagWrites.add(Map.of(flags));
    // A MERGE, like set_feature_flags (0176, #963).
    workspaces[i] = workspaces[i].copyWith(
      featureFlags: {...workspaces[i].featureFlags, ...flags},
    );
  }

  @override
  Future<String?> fetchDefaultWorkspaceId() async => serverDefaultWorkspaceId;
  @override
  Future<void> setDefaultWorkspaceId(String? workspaceId) async {
    serverDefaultWorkspaceId = workspaceId;
  }

  @override
  Future<void> resetWorkspace(String workspaceId) async {
    resetWorkspaceCalls.add(workspaceId);
    // #2571 — as on a server: books still under retention refuse the reset.
    final kept = booksKept?.call(workspaceId);
    if (kept != null) {
      throw PostgrestException(
        message:
            'retention: the books of this space are kept; nothing was deleted',
        code: 'DKE01',
        details: kept,
      );
    }
  }

  @override
  Future<Workspace> saveWorkspaceSettings(
    String workspaceId,
    WorkspaceSettingsSave save,
  ) async {
    settingsSaves.add(save);
    if (settingsConflictNext) {
      settingsConflictNext = false;
      throw const WorkspaceSettingsConflict();
    }
    if (settingsFailure case final failure?) throw failure;
    // One transaction on the server; here the setters the older tests pin.
    await updateWorkspaceLocale(
      workspaceId,
      countryCode: save.countryCode,
      currencyCode: save.currencyCode,
      timezone: save.timezone,
    );
    await setWhatsappGroup(workspaceId, save.whatsappGroup.trim());
    await setWorkspaceAddress(workspaceId, save.address.trim());
    await setInvitationTemplates(workspaceId, save.invitationTemplates);
    await setInvitationTemplate(workspaceId, '');
    await setWorkspaceLanguage(workspaceId, save.defaultLocale);
    await setDeskOpacity(workspaceId, save.deskOpacity);
    if (save.newMemberDefaults case final d?) {
      await setNewMemberDefaults(
        workspaceId,
        d,
      ); // #1563 — absent means "never loaded": the server leaves the key alone
    }
    return workspaces.firstWhere((w) => w.id == workspaceId);
  }
}
