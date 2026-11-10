// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3549 -- the setting values the Demo's spaces start with. The Leipzig
// space is a practice beside the coworking spaces, so the business kinds
// show in the Demo; every other space keeps the registry default.
import '../../features/workspace/domain/business_profile.dart';
import '../settings/settings.dart';
import 'seed/demo_second_space_seed.dart';

const List<SettingVersion> demoSettingSeed = [
  SettingVersion(
    scope: SettingScope.workspace,
    workspaceId: demoSecondSpaceId,
    key: businessKindKey,
    value: 'practice',
    validFrom: 'v1',
  ),
];
