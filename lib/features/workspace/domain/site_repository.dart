// SPDX-License-Identifier: AGPL-3.0-or-later
import 'site.dart';

/// The workspace's sites (#945).
///
/// A part of [WorkspaceRepository] (#2597): that interface is the sum of
/// these, so no caller changes.
abstract class SiteRepository {
  /// #945 — the workspace's sites, default first.
  Future<List<Site>> fetchSites(String workspaceId);

  /// #945 — create (null id) or edit a site (RPC `upsert_site`, admins).
  Future<String> upsertSite(
    String workspaceId,
    Site site, {
    bool isNew = false,
  });

  /// #945 — delete a non-default site; its levels and members fall back
  /// to the default (RPC `delete_site`).
  Future<void> deleteSite(String siteId);

  /// #945 — a member's home site; null for the default.
  Future<void> setMemberHomeSite(String memberId, String? siteId);
}
