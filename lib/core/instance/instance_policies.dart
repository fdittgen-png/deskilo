// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1313 — the row-level policies the migrations create, as the replay
// built them.
//
// The doctor compares a live project with this list in both directions: a
// policy no migration created is an alarm (the hand-made `floor_plans_read`
// of #1316 was exactly that, and no replay can contain it), and a missing
// one is an alarm too.
import 'package:flutter/services.dart' show rootBundle;

import 'instance_policy_parser.dart';
export 'instance_policy_parser.dart';

/// The list as the app carries it.
Future<Set<String>> loadInstancePoliciesAsset() async =>
    parseInstancePolicies(await rootBundle.loadString(instancePoliciesAssetPath));
