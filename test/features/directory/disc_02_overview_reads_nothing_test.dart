// SPDX-License-Identifier: AGPL-3.0-or-later
//
// DISC-02 (#2555): the Overview asks the public directory nothing.
//
// Invariant: opening the personal Overview reads no directory source and no
// card; entering Discover is what reads the directory, and it opens on the
// list with no map, so no map provider and no geocoder is asked either.
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/features/directory/domain/directory_location.dart';
import 'package:deskilo/features/directory/domain/discovery_paging.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/presentation/directory_map.dart';
import 'package:deskilo/features/directory/providers/directory_location_providers.dart';
import 'package:deskilo/features/me/presentation/personal_overview.dart';
import 'package:deskilo/features/me/providers/personal_shell_providers.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../me/me_app.dart';

/// Counts every source list asked of it, beside the card pages it records.
class _CountingDirectory extends FakeDirectoryRepository {
  int sourceReads = 0;

  @override
  Future<DirectorySourcesPage> sources({int page = 0}) {
    sourceReads++;
    return super.sources(page: page);
  }
}

class _CountingGeocoder implements DirectoryGeocoder {
  final asked = <String>[];

  @override
  Future<DirectoryLocation?> locate(String address) async {
    asked.add(address);
    return null;
  }
}

void main() {
  testWidgets('DISC-02: the Overview reads no directory; Discover reads it '
      'on entering and opens on the list, with no map provider asked', (
    tester,
  ) async {
    final directory = _CountingDirectory()
      ..cards.add(
        const PublicWorkspace(
          'one',
          'https://host.example',
          'sb_publishable_test',
          {'name': 'Office one', 'address': '10 Main Street'},
        ),
      );
    final geocoder = _CountingGeocoder();
    final router = await pumpMeApp(
      tester,
      directory: directory,
      size: const Size(420, 2600),
      extraOverrides: [
        personalShellEnabledProvider.overrideWithValue(true),
        myReservationsSourcesProvider.overrideWith((ref) async => const []),
        directoryGeocoderProvider.overrideWithValue(geocoder),
      ],
    );
    expect(await goTo(tester, router, '/me'), '/me');
    expect(find.byType(PersonalOverview), findsOneWidget);
    expect(directory.sourceReads, 0, reason: 'the Overview asks no source');
    expect(directory.reads, isEmpty, reason: 'the Overview asks no card');

    await goTo(tester, router, '/me/discover');
    expect(directory.sourceReads, 1);
    expect(
      find.byKey(const ValueKey('directory-row-https://host.example/one')),
      findsOneWidget,
    );
    expect(find.byType(DirectoryMap), findsNothing);
    expect(geocoder.asked, isEmpty);
  });
}
