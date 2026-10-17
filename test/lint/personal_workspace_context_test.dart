// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 C1 -- the process-wide client is named in few places. Production code
// takes a context (or a role client from `context_client_providers.dart`)
// instead of reaching for `Supabase.instance.client`, so a later backend
// selection cannot retarget an operation under way.
//
// A RATCHET over comment-free source: the number of hand-written lib files
// that still name the singleton may only fall (#2564 moves the consumers).
// The files migrated so far are pinned clean; the bootstrap and client
// factories are the justified allowlist.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

const _singleton = 'Supabase.instance.client';

/// Files that legitimately name the process-wide client, each with its
/// reason. They do not count against the ratchet.
const _allowed = <String, String>{
  'lib/app/app_initializer.dart': 'initialises Supabase and the boot flows',
  'lib/core/backend/context_client_providers.dart':
      'the one factory of the context clients',
  'lib/core/backend/connected_installation_providers.dart':
      'the pool is built on the active client until the split resolver lands',
  'lib/core/backend/schema_version.dart': 'reads the schema of the active server',
};

/// Migrated consumers: these must stay free of the singleton.
const _clean = <String>[
  'lib/features/me/providers/me_providers.dart',
  'lib/features/reservations/data/context_reservation_repository.dart',
  'lib/features/workspace/providers/operation_context_providers.dart',
  'lib/core/backend/operation_context.dart',
  // #2564 O1: root-session (P) consumers and the selected workspace's
  // role/application sources; O2: reservations and place feedback.
  'lib/features/auth/providers/auth_providers.dart',
  'lib/features/auth/providers/oauth_consent_providers.dart',
  'lib/features/profile/providers/personal_preferences_providers.dart',
  'lib/features/workspace/providers/workspace_roles_providers.dart',
  'lib/features/workspace/providers/workspace_application_providers.dart',
  'lib/features/reservations/providers/reservation_providers.dart',
  'lib/features/reservations/providers/place_feedback_providers.dart',
];

/// Hand-written lib files outside the allowlist that still name the
/// singleton. RATCHET: this number only falls.
const _budget = 33;

bool _names(String line) => line.contains(_singleton);

void main() {
  final files = handWrittenDartFiles('lib').toList();

  test('migrated consumers do not name the process-wide client', () {
    for (final path in _clean) {
      expect(
        scanLines([File(path)], _names),
        isEmpty,
        reason: '$path takes a context or a role client',
      );
    }
  });

  test('the files naming the process-wide client only shrink', () {
    final naming = [
      for (final f in files)
        if (scanLines([f], _names).isNotEmpty) f.path,
    ]..sort();
    final outside = [
      for (final p in naming)
        if (!_allowed.containsKey(p)) p,
    ];
    expect(
      outside.length,
      lessThanOrEqualTo(_budget),
      reason: 'new production code takes a WorkspaceContext or a role client '
          '(context_client_providers.dart), it does not read $_singleton. '
          'Now: ${outside.length}. A lower number is progress: lower _budget.',
    );
    // A ratchet that cannot fire is deleted: the budget must be tight.
    expect(
      outside.length,
      greaterThanOrEqualTo(_budget),
      reason: 'lower _budget to ${outside.length} (progress is recorded)',
    );
  });

  test('every allowlisted file still exists and still needs its entry', () {
    for (final entry in _allowed.entries) {
      final file = File(entry.key);
      expect(file.existsSync(), isTrue, reason: '${entry.key} is gone');
      expect(
        scanLines([file], _names),
        isNotEmpty,
        reason: '${entry.key} no longer names the singleton: drop its entry',
      );
    }
  });
}
