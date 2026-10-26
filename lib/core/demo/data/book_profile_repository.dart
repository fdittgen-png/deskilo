// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/money/domain/accounting_amount.dart';
import '../../../features/money/domain/book_chart.dart';
import '../../../features/money/domain/book_profile.dart';
import '../../../features/money/domain/book_profile_repository.dart';
import '../../../features/money/domain/posting.dart';
import '../../../features/money/domain/posting_rules.dart';
import '../../../features/money/domain/posting_rules_purchases.dart';
import '../../../features/money/domain/purchase.dart';
import '../../../features/money/domain/retention_hold.dart';
import '../../vat/tax_reference_active.dart';
import 'money_repository.dart';
import 'purchase_exchange_rates.dart';

/// #1869 — book profiles in memory, with the server's revision rule:
/// a save names the revision it read (0 for a new version).
class FakeBookProfileRepository implements BookProfileRepository {
  FakeBookProfileRepository({this.money, this.purchases, this.country = 'FR'});

  /// #2365 — the demo's invoices and matches the books are posted from; none
  /// in tests that only read profiles and charts.
  final FakeMoneyRepository? money;

  /// The demo's supplier bills and what was paid on them (0519).
  final PurchaseRepository? purchases;

  /// The issuer's country, whose rate rows name the groups.
  final String country;

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
    String? qualifier,
  }) async {
    final i = mappings.indexWhere(
      (m) =>
          m.issuerSiteId == issuerSiteId &&
          m.role == role &&
          m.qualifier == qualifier &&
          m.effectiveFrom == effectiveFrom,
    );
    final current = i < 0 ? 0 : mappings[i].revision;
    if (expectedRevision != current) return null;
    final saved = BookMapping(
      id: i < 0 ? 'map-${mappings.length + 1}' : mappings[i].id,
      workspaceId: workspaceId,
      issuerSiteId: issuerSiteId,
      role: role,
      qualifier: qualifier,
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

  /// #2365 — the same rules as the server (`posting_rules.dart`,
  /// `posting_rules_purchases.dart`), over the demo's documents of the period.
  @override
  Future<PostingSet> fetchPostings(
    String workspaceId,
    String issuerSiteId,
    DateTime from,
    DateTime to,
  ) async {
    final m = money;
    if (m == null) return const PostingSet([], []);
    final chart = await fetchBookChart(workspaceId);
    final book = PostingBook(
      accounts: chart.accounts,
      mappings: chart.mappings,
      issuerSiteId: issuerSiteId,
    );
    bool inPeriod(DateTime day) => !day.isBefore(from) && !day.isAfter(to);
    final p = purchases;
    final details = p == null
        ? const <PurchaseDetail>[]
        : [
            for (final s in await p.fetchPurchases(workspaceId))
              await p.fetchDetail(workspaceId, s.id),
          ];
    // A purchase in another currency is booked at its recorded rate, as the
    // server books it.
    final rates = <String, FxRate>{
      for (final d in details)
        if (await p!.fetchExchangeRate(workspaceId, d.summary.id) case final r?)
          d.summary.id: r.fxRate,
    };
    final bought = [
      for (final x in purchasePostingsOf(
        purchases: details,
        book: book,
        groupOf: (percent) =>
            ActiveTaxReference.current.groupOfRate(country, percent, 'S'),
        functional: DemoPurchaseExchangeRates.spaceCurrency,
        rates: rates,
      ))
        if (inPeriod(x.date)) x,
    ];
    final sold = postingsOf(
      invoices: [
        for (final i in await m.fetchInvoices(workspaceId))
          if (inPeriod(i.issuedAt)) i,
      ],
      matches: await m.fetchInvoiceMatches(workspaceId),
      book: book,
      groupOf: (t) =>
          ActiveTaxReference.current.groupOfRate(country, t.percent, t.category),
    );
    return PostingSet(
      [...sold.postings, ...bought]..sort(comparePostings),
      book.blockers,
    );
  }

  /// #2376 — the demo's invoices name their member; its purchases none.
  @override
  Future<Map<String, PostingParty>> fetchPostingParties(
    String workspaceId,
    List<String> documentIds,
  ) async {
    final m = money;
    if (m == null) return const {};
    final wanted = documentIds.toSet();
    return {
      for (final i in await m.fetchInvoices(workspaceId))
        if (wanted.contains(i.id))
          i.id: PostingParty(
            kind: 'member',
            number: i.memberId,
            name: i.memberName,
          ),
    };
  }
}

/// #2571 — Retention holds in memory, released as the server releases them: the
/// row stays, with when and why.
class FakeRetentionHoldRepository implements RetentionHoldRepository {
  FakeRetentionHoldRepository({required this.now});

  /// The session's clock: a hold is placed and released at its time.
  final DateTime Function() now;

  final List<RetentionHold> holds = [];

  @override
  Future<List<RetentionHold>> fetchHolds(String workspaceId) async => [
    for (final h in holds)
      if (h.workspaceId == workspaceId && h.active) h,
    for (final h in holds)
      if (h.workspaceId == workspaceId && !h.active) h,
  ];

  @override
  Future<RetentionHold> placeHold({
    required String workspaceId,
    String? issuerSiteId,
    String? docClass,
    required String reason,
  }) async {
    final hold = RetentionHold(
      id: 'hold-${holds.length + 1}',
      workspaceId: workspaceId,
      issuerSiteId: issuerSiteId,
      docClass: docClass,
      reason: reason.trim(),
      placedAt: now(),
    );
    holds.add(hold);
    return hold;
  }

  @override
  Future<RetentionHold> releaseHold(String holdId, String reason) async {
    final i = holds.indexWhere((h) => h.id == holdId && h.active);
    if (i < 0) throw StateError('no active hold $holdId');
    final h = holds[i];
    return holds[i] = RetentionHold(
      id: h.id,
      workspaceId: h.workspaceId,
      issuerSiteId: h.issuerSiteId,
      docClass: h.docClass,
      reason: h.reason,
      placedAt: h.placedAt,
      releasedAt: now(),
      releaseReason: reason.trim(),
    );
  }
}
