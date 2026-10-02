// SPDX-License-Identifier: AGPL-3.0-or-later
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
}
