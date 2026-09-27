// SPDX-License-Identifier: AGPL-3.0-or-later
// Pure Dart policy manifest parsing shared by the app and operator CLI.
/// Where the generated list lives.
const String instancePoliciesAssetPath = 'assets/instance/policies.txt';

/// `schema.table.policy` names from the generated file: comments (`#`) and
/// blank lines are not policies.
Set<String> parseInstancePolicies(String text) => {
  for (final line in text.split('\n'))
    if (line.trim().isNotEmpty && !line.trim().startsWith('#')) line.trim(),
};
