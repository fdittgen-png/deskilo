// SPDX-License-Identifier: AGPL-3.0-or-later
import 'workspace.dart';
import 'workspace_overview.dart';
import 'workspace_settings_save.dart';

/// Creating, switching, configuring and resetting a workspace; environment, dev mode and feature flags.
///
/// A part of [WorkspaceRepository] (#2597): that interface is the sum of
/// these, so no caller changes.
abstract class WorkspaceLifecycleRepository {
  /// Workspaces the signed-in user is a non-exited member of.
  Future<List<Workspace>> fetchMyWorkspaces();

  /// #937 — whether the caller operates the deployment (`platform_admins`).
  Future<bool> isPlatformOwner();

  /// #937 — every workspace in the database, for the platform owner only
  /// (RPC `list_all_workspaces`, refuses anyone else).
  Future<List<WorkspaceOverview>> fetchAllWorkspaces();

  /// #937 — the owners of a workspace, name and e-mail, for the platform
  /// owner only; the read is logged (RPC `workspace_owners`).
  Future<List<WorkspaceOwner>> fetchWorkspaceOwners(String workspaceId);

  /// Creates a workspace; the caller becomes its owner. Returns the id.
  Future<String> createWorkspace({
    required String name,
    required String countryCode,
    required String currencyCode,
    required String timezone,

    /// #917 — real, or a place to try things out. Development by
    /// default: the safe answer to "is this real?" is no until somebody
    /// says otherwise.
    WorkspaceEnvironment environment = WorkspaceEnvironment.development,

    /// #987 — create the other side of the pair at the same time.
    bool withTwin = true,

    /// #1303 — the id this creation is known by. Given, the server makes
    /// ONE workspace however often the same id is sent: a retry after a
    /// lost response returns the workspace the first attempt made. The
    /// caller generates it once per onboarding session.
    String? requestId,

    /// #1303 — the template the new space starts from, applied in the
    /// same transaction as the creation: both happen, or neither.
    String? templateId,
  });

  /// #987 (RPC `create_workspace_twin`, migration 0185): the missing side
  /// of a lone workspace — same name, country, currency and timezone,
  /// the caller owner of both, the configuration copied once. Owner only.
  Future<String> createWorkspaceTwin(String workspaceId);

  /// Owner-only: replace the workspace ID (= invite code, shown in the QR)
  /// with a memorable alphanumeric one (4–20 A-Z/0-9, unique). Returns the
  /// normalized code.
  Future<String> setWorkspaceCode(String workspaceId, String code);

  /// Merges [flags] into the workspace's stored feature flags (#963):
  /// only the keys named here change, every other key stays as it is.
  /// Owner-only.
  ///
  /// #1329 — [expected] is the read-set a preview rested on: key → the
  /// value it was read as. The server compares it under the row lock and
  /// throws [FeatureFlagsConflict] instead of writing when any of it
  /// moved. Null keeps the unconditional merge.
  Future<void> setFeatureFlags(
    String workspaceId,
    Map<String, bool> flags, {
    Map<String, bool>? expected,
  });

  /// Workspace-wide developer mode (#419, 0081): admin/owner only —
  /// the server enforces via set_dev_mode.
  Future<void> setDevMode(String workspaceId, {required bool enabled});

  /// #917 — declares the workspace real, or back to a development one.
  /// OWNER only, enforced by `set_workspace_environment` (0160): an
  /// admin cannot quietly take the development mark off the documents
  /// they issue.
  Future<void> setWorkspaceEnvironment(
    String workspaceId,
    WorkspaceEnvironment environment,
  );

  /// The signed-in USER's default workspace (#458, 0090) — stored on
  /// their profile so it survives reinstalls and follows them across
  /// platforms. Null = none chosen (or signed out).
  Future<String?> fetchDefaultWorkspaceId();

  /// Persists the default-workspace choice on the profile row
  /// (profiles_update RLS: self-only). Null clears it.
  Future<void> setDefaultWorkspaceId(String? workspaceId);

  /// #1451 — the Workspace settings Save, all or nothing, against the
  /// version the form was opened on. Returns the saved workspace; throws
  /// [WorkspaceSettingsConflict] when someone changed it meanwhile.
  Future<Workspace> saveWorkspaceSettings(
    String workspaceId,
    WorkspaceSettingsSave save,
  );

  /// Owner-only, irreversible (0039): wipe all transactions (reservations,
  /// events, ledger, quota extensions) and the entire floor plan (levels,
  /// offices, desks, seats, plan images) while keeping the workspace
  /// configuration and its members. The client gates this behind a typed
  /// confirmation.
  Future<void> resetWorkspace(String workspaceId);
}
