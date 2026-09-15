// SPDX-License-Identifier: 0BSD
//
// #1313 — the row-level policies the migrations create, as the replay
// built them.
//
// The doctor compares a live project with this list in both directions: a
// policy no migration created is an alarm (the hand-made `floor_plans_read`
// of #1316 was exactly that, and no replay can contain it), and a missing
// one is an alarm too.
import 'package:flutter/services.dart' show rootBundle;

/// Where the generated list lives.
const String instancePoliciesAssetPath = 'assets/instance/policies.txt';

/// `schema.table.policy` names from the generated file: comments (`#`) and
/// blank lines are not policies.
Set<String> parseInstancePolicies(String text) => {
      for (final line in text.split('\n'))
        if (line.trim().isNotEmpty && !line.trim().startsWith('#')) line.trim(),
    };

/// The list as the app carries it.
Future<Set<String>> loadInstancePoliciesAsset() async =>
    parseInstancePolicies(await rootBundle.loadString(instancePoliciesAssetPath));
