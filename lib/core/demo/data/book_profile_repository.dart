// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/money/domain/book_chart.dart';
import '../../../features/money/domain/book_profile.dart';
import '../../../features/money/domain/book_profile_repository.dart';

/// #1869 — book profiles in memory, with the server's revision rule:
/// a save names the revision it read (0 for a new version).
class FakeBookProfileRepository implements BookProfileRepository {
  final List<BookProfile> profiles = [];

  /// Every profile handed to [saveBookProfile], in order.
  final List<BookProfile> saves = [];

  @override
  Future<List<BookProfile>> fetchBookProfiles(String workspaceId) async => [
    for (final p in profiles)
      if (p.workspaceId == workspaceId) p,
  ];

  @override
  Future<BookProfile?> saveBookProfile(BookProfile p) async {
    saves.add(p);
    final i = profiles.indexWhere(
      (x) =>
          x.issuerSiteId == p.issuerSiteId &&
          x.effectiveFrom == p.effectiveFrom,
    );
    final current = i < 0 ? 0 : profiles[i].revision;
    if (p.revision != current) return null;
    final saved = BookProfile(
      id: i < 0 ? 'book-${profiles.length + 1}' : profiles[i].id,
      workspaceId: p.workspaceId,
      issuerSiteId: p.issuerSiteId,
      authority: p.authority,
      externalSystem: p.externalSystem.trim(),
      functionalCurrency: p.functionalCurrency,
      fiscalYearStartMonth: p.fiscalYearStartMonth,
      fiscalYearStartDay: p.fiscalYearStartDay,
      basis: p.basis,
      effectiveFrom: p.effectiveFrom,
      revision: current + 1,
    );
    if (i < 0) {
      profiles.add(saved);
    } else {
      profiles[i] = saved;
    }
    return saved;
  }

  final List<BookAccount> accounts = [];
  final List<BookMapping> mappings = [];

  @override
  Future<({List<BookAccount> accounts, List<BookMapping> mappings})>
  fetchBookChart(String workspaceId) async => (
    accounts: [
      for (final a in accounts)
        if (a.workspaceId == workspaceId) a,
    ],
    mappings: [
      for (final m in mappings)
        if (m.workspaceId == workspaceId) m,
    ],
  );

  @override
  Future<BookAccount?> saveBookAccount(BookAccount a) async {
    final i = a.id.isEmpty ? -1 : accounts.indexWhere((x) => x.id == a.id);
    final current = i < 0 ? 0 : accounts[i].revision;
    if (a.revision != current) return null;
    final saved = BookAccount(
      id: i < 0 ? 'acc-${accounts.length + 1}' : a.id,
      workspaceId: a.workspaceId,
      issuerSiteId: a.issuerSiteId,
      code: a.code,
      name: a.name.trim(),
      type: a.type,
      isPosting: a.isPosting,
      origin: a.origin,
      revision: current + 1,
    );
    if (i < 0) {
      accounts.add(saved);
    } else {
      accounts[i] = saved;
    }
    return saved;
  }

  @override
  Future<BookMapping?> saveBookMapping({
    required String workspaceId,
    required String issuerSiteId,
    required BookRole role,
    required String accountId,
    required DateTime effectiveFrom,
    required int expectedRevision,
  }) async {
    final i = mappings.indexWhere(
      (m) =>
          m.issuerSiteId == issuerSiteId &&
          m.role == role &&
          m.effectiveFrom == effectiveFrom,
    );
    final current = i < 0 ? 0 : mappings[i].revision;
    if (expectedRevision != current) return null;
    final saved = BookMapping(
      id: i < 0 ? 'map-${mappings.length + 1}' : mappings[i].id,
      workspaceId: workspaceId,
      issuerSiteId: issuerSiteId,
      role: role,
      accountId: accountId,
      effectiveFrom: effectiveFrom,
      revision: current + 1,
    );
    if (i < 0) {
      mappings.add(saved);
    } else {
      mappings[i] = saved;
    }
    return saved;
  }
}
