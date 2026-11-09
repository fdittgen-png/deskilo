// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2597 -- the in-memory half of Sites: moved verbatim out of the part
// files; the state it reads is `FakeWorkspaceState`.
import 'dart:async';

import 'package:deskilo/features/workspace/domain/site.dart';
import 'package:deskilo/features/workspace/domain/site_repository.dart';

import 'fake_workspace_state.dart';

mixin FakeSites on FakeWorkspaceState implements SiteRepository {
  @override
  Future<List<Site>> fetchSites(String workspaceId) async => [
    ...sites.where((s) => s.workspaceId == workspaceId && s.isDefault),
    ...sites.where((s) => s.workspaceId == workspaceId && !s.isDefault),
  ];
  @override
  Future<String> upsertSite(
    String workspaceId,
    Site site, {
    bool isNew = false,
  }) async {
    final id = isNew ? 'site-${sites.length + 1}' : site.id;
    sites.removeWhere((s) => s.id == id);
    sites.add(
      Site(
        id: id,
        workspaceId: workspaceId,
        name: site.name,
        street: site.street,
        postalCode: site.postalCode,
        city: site.city,
        countryCode: site.countryCode,
        legalId: site.legalId,
        vatId: site.vatId,
        taxExemptionReason: site.taxExemptionReason,
        isDefault: site.isDefault,
        sortOrder: site.sortOrder,
      ),
    );
    siteWrites.add('${isNew ? 'new' : 'edit'}:${site.name}');
    return id;
  }

  @override
  Future<void> deleteSite(String siteId) async {
    sites.removeWhere((s) => s.id == siteId && !s.isDefault);
    siteWrites.add('delete:$siteId');
  }

  @override
  Future<void> setMemberHomeSite(String memberId, String? siteId) async {
    homeSites[memberId] = siteId;
  }
}
