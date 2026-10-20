// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2575 -- the roles a screen outside the workspace feature may name as an
// audience (a rented room is open to chosen roles). The workspace feature
// supplies them and the composition root puts them in its scope's overrides
// (`audienceRolesFromWorkspace`); until then there are none.
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One role a space defined, by id, with its name per locale.
class AudienceRole {
  const AudienceRole({required this.id, required this.names});

  final String id;
  final Map<String, String> names;

  String nameIn(String locale) =>
      names[locale] ?? names['en'] ?? names.values.firstOrNull ?? id;
}

/// The members of the workspace by id, with their display names: a rented
/// room may be opened to chosen members. Empty until the composition root
/// wires it.
final audienceMembersProvider = Provider<Map<String, String>>(
  (ref) => const {},
);

/// The roles a workspace may be addressed by; empty until wired.
final audienceRolesProvider = Provider<List<AudienceRole>>((ref) => const []);
