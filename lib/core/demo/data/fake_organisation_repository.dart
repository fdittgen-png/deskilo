// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4006 — the Demo's organisations: the ones it was given, none by default;
// #4009 — or the ones its source states each time it is read (the Demo's
// reference organisation follows the person's memberships). The owners'
// commands follow the server's rules: a name is needed, a business is in one
// organisation at most, the head is one of its houses and leaves last. Once
// a command changed something, the Demo keeps its own copy from then on.
import '../../../features/workspace/domain/organisation.dart';
import '../../../features/workspace/domain/organisation_overview.dart';

class FakeOrganisationRepository implements OrganisationRepository {
  /// [businesses] are the person's businesses that may become houses, as
  /// the houses they would be.
  FakeOrganisationRepository({
    List<Organisation> organisations = const [],
    List<OrganisationHouse> businesses = const [],
    this.createBusiness,
    this.onlyHouse,
    this.overviewOf,
  }) : _organisations = List.of(organisations),
       _source = null,
       _businessSource = null,
       _businesses = List.of(businesses);

  /// The organisations [source] states, and the person's [businesses].
  FakeOrganisationRepository.from(
    Future<List<Organisation>> Function() source, {
    Future<List<OrganisationHouse>> Function()? businesses,
    this.createBusiness,
    this.onlyHouse,
    this.overviewOf,
  }) : _organisations = [],
       _source = source,
       _businessSource = businesses,
       _businesses = [];

  /// #4005 — makes the house's business where the person's businesses are
  /// kept, and answers its id; the same request answers the same business.
  final Future<HouseBirth> Function(HouseRequest request)? createBusiness;

  /// #4005 — the one house the Demo can add (its country and currency); a
  /// request for another is refused in words, never swapped silently.
  final ({String country, String currency})? onlyHouse;

  final Map<String, HouseBirth> _births = {};

  List<Organisation> _organisations;
  Future<List<Organisation>> Function()? _source;
  final Future<List<OrganisationHouse>> Function()? _businessSource;
  final List<OrganisationHouse> _businesses;
  int _next = 0;

  /// #4007 — what the overview of an organisation answers for a month;
  /// without it, the organisation's houses with no figures.
  final Future<OrganisationOverview> Function(String organisationId, String month)?
  overviewOf;

  @override
  Future<OrganisationOverview> overview(
    String organisationId, {
    required String fromMonth,
    required String toMonth,
  }) async {
    if (overviewOf case final of?) return of(organisationId, fromMonth);
    final organisation = (await myOrganisations())
        .where((o) => o.id == organisationId)
        .firstOrNull;
    return OrganisationOverview.ofHouses(
      organisationId: organisationId,
      month: fromMonth,
      houses: [
        for (final h in [...?organisation?.houses])
          OverviewHouse(
            workspaceId: h.workspaceId,
            name: h.name,
            countryCode: h.countryCode,
            currencyCode: h.currencyCode,
            isHead: h.workspaceId == organisation?.headWorkspaceId,
            withheld: OverviewWithheld.notEnabled,
          ),
      ],
    );
  }

  @override
  Future<List<Organisation>> myOrganisations() async =>
      List.unmodifiable(await _source?.call() ?? _organisations);

  /// The organisations as they stand, kept from now on.
  Future<List<Organisation>> _kept() async {
    if (_source case final source?) {
      _organisations = List.of(await source());
      _source = null;
    }
    return _organisations;
  }

  Future<OrganisationHouse?> _business(String workspaceId) async {
    final all = [..._businesses, ...?await _businessSource?.call()];
    return all.where((b) => b.workspaceId == workspaceId).firstOrNull;
  }

  int _holding(String workspaceId) =>
      _organisations.indexWhere((o) => o.houseOf(workspaceId) != null);

  Organisation _with(
    Organisation o, {
    String? name,
    String? head,
    List<OrganisationHouse>? houses,
  }) => Organisation(
    id: o.id,
    name: name ?? o.name,
    headWorkspaceId: head ?? o.headWorkspaceId,
    houses: houses ?? o.houses,
  );

  @override
  Future<OrganisationRefusal?> create(
    String headWorkspaceId,
    String name,
  ) async {
    await _kept();
    if (name.trim().isEmpty) return OrganisationRefusal.noName;
    if (_holding(headWorkspaceId) >= 0) return OrganisationRefusal.alreadyInOne;
    final head = await _business(headWorkspaceId);
    if (head == null || head.role != HouseRole.owner) {
      return OrganisationRefusal.notOwner;
    }
    _organisations.add(
      Organisation(
        id: 'demo-organisation-${_next++}',
        name: name.trim(),
        headWorkspaceId: headWorkspaceId,
        houses: [head],
      ),
    );
    return null;
  }

  @override
  Future<OrganisationRefusal?> rename(
    String organisationId,
    String name,
  ) async {
    final all = await _kept();
    if (name.trim().isEmpty) return OrganisationRefusal.noName;
    final i = all.indexWhere((o) => o.id == organisationId);
    if (i < 0) return OrganisationRefusal.notOwner;
    all[i] = _with(all[i], name: name.trim());
    return null;
  }

  @override
  Future<OrganisationRefusal?> add(
    String organisationId,
    String workspaceId,
  ) async {
    final all = await _kept();
    final i = all.indexWhere((o) => o.id == organisationId);
    if (i < 0) return OrganisationRefusal.notOwner;
    if (_holding(workspaceId) >= 0) return OrganisationRefusal.alreadyInOne;
    final house = await _business(workspaceId);
    if (house == null || house.role != HouseRole.owner) {
      return OrganisationRefusal.notOwner;
    }
    all[i] = _with(all[i], houses: [...all[i].houses, house]);
    return null;
  }

  @override
  Future<OrganisationRefusal?> remove(String workspaceId) async {
    final all = await _kept();
    final i = _holding(workspaceId);
    if (i < 0) return OrganisationRefusal.inNone;
    final o = all[i];
    if (o.headWorkspaceId == workspaceId && o.houses.length > 1) {
      return OrganisationRefusal.headLeavesLast;
    }
    final left = [
      for (final h in o.houses)
        if (h.workspaceId != workspaceId) h,
    ];
    if (left.isEmpty) {
      all.removeAt(i);
    } else {
      all[i] = _with(o, houses: left);
    }
    return null;
  }

  @override
  Future<OrganisationRefusal?> setHead(
    String organisationId,
    String headWorkspaceId,
  ) async {
    final all = await _kept();
    final i = all.indexWhere((o) => o.id == organisationId);
    if (i < 0) return OrganisationRefusal.notOwner;
    final house = all[i].houseOf(headWorkspaceId);
    if (house == null) return OrganisationRefusal.notAHouse;
    if (house.role != HouseRole.owner) return OrganisationRefusal.notOwner;
    all[i] = _with(all[i], head: headWorkspaceId);
    return null;
  }

  @override
  Future<({String? workspaceId, OrganisationRefusal? refused})> createHouse(
    HouseRequest request,
  ) async {
    final all = await _kept();
    final i = all.indexWhere((o) => o.id == request.organisationId);
    if (i < 0) return (workspaceId: null, refused: OrganisationRefusal.notOwner);
    final o = all[i];
    if (o.houseOf(o.headWorkspaceId)?.role != HouseRole.owner) {
      return (workspaceId: null, refused: OrganisationRefusal.notOwner);
    }
    if (!const {'en', 'fr', 'de', 'es', 'it'}.contains(request.language)) {
      return (workspaceId: null, refused: OrganisationRefusal.language);
    }
    final create = createBusiness;
    if (create == null) {
      return (workspaceId: null, refused: OrganisationRefusal.other);
    }
    if (onlyHouse case final only?
        when only.country != request.country ||
            only.currency != request.currency) {
      return (workspaceId: null, refused: OrganisationRefusal.demoOneHouse);
    }
    final birth = await create(request);
    final id = birth.workspaceId;
    if (o.houseOf(id) == null) {
      final house = OrganisationHouse(
        workspaceId: id,
        name: request.name,
        countryCode: request.country,
        currencyCode: request.currency,
        role: HouseRole.owner,
      );
      _businesses.add(house);
      all[i] = _with(o, houses: [...o.houses, house]);
    }
    _births[id] = birth;
    return (workspaceId: id, refused: null);
  }

  @override
  Future<HouseBirth?> houseBirth(String workspaceId) async =>
      _births[workspaceId];

  @override
  Future<OrganisationRefusal?> clearPricesPending(String workspaceId) async {
    final birth = _births[workspaceId];
    if (birth == null) return OrganisationRefusal.notOwner;
    _births[workspaceId] = HouseBirth(
      workspaceId: birth.workspaceId,
      headWorkspaceId: birth.headWorkspaceId,
      plans: birth.plans,
      services: birth.services,
      packages: birth.packages,
      validationPolicies: birth.validationPolicies,
      features: birth.features,
      amountsKept: birth.amountsKept,
      coOwnersAdded: birth.coOwnersAdded,
      pricesPending: false,
      createdAt: birth.createdAt,
      rateHints: birth.rateHints,
    );
    return null;
  }
}
