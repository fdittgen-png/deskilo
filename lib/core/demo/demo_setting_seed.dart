// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3549 -- the setting values the Demo's spaces start with. The practice
// (#3863: Berlin, without places) is a practice beside the coworking spaces,
// so the business kinds show in the Demo; every other space, Leipzig
// included, keeps the registry default (coworking).
import '../../features/workspace/domain/business_profile.dart';
import '../settings/settings.dart';
import 'demo_space_ids.dart';

const List<SettingVersion> demoSettingSeed = [
  SettingVersion(
    scope: SettingScope.workspace,
    workspaceId: demoPracticeSpaceId,
    key: businessKindKey,
    value: 'practice',
    validFrom: 'v1',
  ),
  // #4168 — Kessler Conseil is explicitly a freelancer: Me names it.
  SettingVersion(
    scope: SettingScope.workspace,
    workspaceId: demoFreelancerSpaceId,
    key: businessKindKey,
    value: 'freelancer',
    validFrom: 'v1',
  ),
  // #4365 — the Épicerie du Marché is a shop, a grocery.
  SettingVersion(
    scope: SettingScope.workspace,
    workspaceId: demoShopSpaceId,
    key: businessKindKey,
    value: 'shop',
    validFrom: 'v1',
  ),
  SettingVersion(
    scope: SettingScope.workspace,
    workspaceId: demoShopSpaceId,
    key: businessShopTypeKey,
    value: 'grocery',
    validFrom: 'v1',
  ),
];
