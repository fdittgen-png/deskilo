// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3846 -- the spaces beside the main one, listed at the start (the switcher
// and the profiles need their rows and people) and built when first read.
import 'data/floor_plan_repository.dart';
import 'data/workspace_repository.dart';
import 'data/workspace_roles_repository.dart';
import 'demo_freelancer_space.dart';
import 'demo_house_space.dart';
import 'demo_lazy_spaces.dart';
import 'demo_london_space.dart';
import 'demo_new_york_space.dart';
import 'demo_practice_space.dart';
import 'demo_second_space.dart';
import 'demo_shop_space.dart';
import 'demo_trade_city_space.dart';
import 'demo_twin_space.dart';
import 'seed/demo_trade_city_seed.dart';

/// Lists every space beside the main one, each looked at as [memberId].
(DemoListings, DemoTwinSource) listDemoSpaces(
  FakeWorkspaceRepository home,
  FakeFloorPlanRepository floorPlan,
  FakeWorkspaceRoles roles,
  String memberId,
  DateTime today,
) {
  final listings = (
    leipzig: DemoSecondSpaceData.list(home: home, now: today),
    london: DemoLondonData.list(home: home),
    newYork: DemoNewYorkData.list(home: home),
    zurich: DemoTradeCityData.list(city: demoZurich, home: home),
    milan: DemoTradeCityData.list(city: demoMilan, home: home),
    practice: DemoPracticeData.list(home: home),
    house: DemoHouseData.list(home: home),
    freelancer: DemoFreelancerData.list(home: home),
    shop: DemoShopData.list(home: home),
  );
  final twin = DemoTwinData.list(home: home, productionPlan: floorPlan, productionRoles: roles);
  for (final listing in [listings.leipzig, listings.london, listings.newYork, listings.zurich, listings.milan, listings.practice, listings.house, listings.freelancer, listings.shop, twin.listing]) {
    listing.viewAs(memberId);
  }
  return (listings, twin);
}
