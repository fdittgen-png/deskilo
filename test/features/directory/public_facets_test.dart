// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Public facts accept only catalogue IDs, preserve patch/clear distinctions
// and follow the reference Demo business hours without inventing defaults.
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_spaces.dart';
import 'package:deskilo/core/public_network/public_network_codec.dart';
import 'package:deskilo/features/directory/application/directory_actions.dart';
import 'package:deskilo/features/directory/domain/public_facets.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/domain/publication_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'typed catalogue arrays survive a description-only editor patch',
    () async {
      final repository = FakeDirectoryRepository();
      final actions = PublicationActions(repository);
      await actions.savePage(
        'space',
        PublicationPatch.replace({
          'amenities': ['wifi', 'meeting_room'],
          'accessibility': ['step_free_entrance'],
          'description': 'Before',
        }),
        published: true,
      );
      final draft = (await actions.ownPage('space')).draft;
      await actions.savePage(
        'space',
        draft.diff(draft.copyWith(texts: {'description': 'After'})),
        published: true,
      );
      final saved = (await actions.ownPage('space')).draft;
      expect(saved.amenities, ['wifi', 'meeting_room']);
      expect(saved.accessibility, ['step_free_entrance']);
      expect(saved.text('description'), 'After');
    },
  );

  test(
    '#4409 one facet edited on a page holding a key the app does not know: '
    'the patch carries the facet only and the key survives the save',
    () async {
      final repository = FakeDirectoryRepository();
      repository.pages['space'] = {
        'published': true,
        'document': {
          'description': 'Desks',
          'amenities': ['wifi'],
          'future_field': {'kept': true},
        },
      };
      final actions = PublicationActions(repository);
      final draft = (await actions.ownPage('space')).draft;
      final patch = draft.diff(
        draft.withFacet(PublicFacets.amenities, ['wifi', 'meeting_room']),
      );
      expect(patch.fields, {
        'amenities': ['wifi', 'meeting_room'],
      });
      expect(patch.mode, PublicationWriteMode.patch);
      await actions.savePage('space', patch, published: true);
      final stored = repository.pages['space']!['document'] as Map;
      expect(stored['future_field'], {'kept': true});
      expect(stored['amenities'], ['wifi', 'meeting_room']);
      expect(stored['description'], 'Desks');
    },
  );

  test(
    'empty facts and omitted facts remain distinct from explicit clear',
    () async {
      final repository = FakeDirectoryRepository();
      await repository.savePage(
        'space',
        PublicationPatch.replace({
          'amenities': ['wifi'],
          'accessibility': ['accessible_toilet'],
        }),
        published: true,
      );
      await repository.savePage(
        'space',
        PublicationPatch.patch({'amenities': [], 'accessibility': null}),
        published: true,
      );
      final document = (await repository.ownPage('space'))['document'] as Map;
      expect(document['amenities'], isEmpty);
      expect(document.containsKey('accessibility'), isFalse);
    },
  );

  test('invalid catalogue values are refused before a write', () {
    for (final value in [
      'wifi',
      [1],
      ['unknown'],
      ['wifi', 'wifi'],
      List.filled(30, 'wifi'),
    ]) {
      expect(
        () => encodePublicInput('PublicationInput', {'amenities': value}),
        throwsA(isA<PublicContractRefusal>()),
      );
    }
  });

  test(
    'public projection retains supported optional facts and ignores extras',
    () {
      final result = decodePublicRecord('PublicWorkspaceDocument', {
        'name': 'Office',
        'host_type': 'company',
        'amenities': ['wifi'],
        'accessibility': ['step_free_entrance'],
        'opening_hours': {
          'weekdays': [1, 2, 3],
          'start_minutes': 540,
          'end_minutes': 1020,
          'timezone': 'Europe/Paris',
        },
        'private_note': 'not public',
      });
      expect(result['amenities'], ['wifi']);
      expect(result['accessibility'], ['step_free_entrance']);
      expect(result['opening_hours'], isA<Map<Object?, Object?>>());
      expect(result.containsKey('private_note'), isFalse);
    },
  );
  test(
    'equivalent arrays do not become edits and malformed facts stay unknown',
    () {
      final draft = PublicationDraft.fromPage({
        'document': {
          'amenities': ['wifi'],
          'accessibility': ['lift'],
        },
      });
      expect(
        draft.diff(draft.withFacet(PublicFacets.amenities, ['wifi'])).fields,
        isEmpty,
      );
      expect(PublicFacets.read('accessibility', null), isNull);
      expect(PublicFacets.read('accessibility', ['unknown']), isNull);
      expect(
        PublicOpeningHours.read({
          'timezone': 'Europe/Paris',
          'weekdays': [1],
          'start_minutes': 1080,
          'end_minutes': 480,
        }),
        isNull,
      );
    },
  );

  test('hours notes are only for businesses without place booking', () async {
    final repository = FakeDirectoryRepository()
      ..placeBooking = ((_) => false)
      ..timezoneOf = ((_) => 'Europe/Paris');
    final preview = await repository.savePage(
      'space',
      PublicationPatch.patch({'opening_hours': 'By appointment'}),
      published: true,
    );
    expect(
      PublicOpeningHours.read(preview['opening_hours'])?.note,
      'By appointment',
    );
    final draft = PublicationDraft.fromDocument(preview);
    expect(draft.hoursNote, 'By appointment');
    repository.placeBooking = (_) => true;
    await expectLater(
      repository.savePage(
        'space',
        PublicationPatch.patch({'opening_hours': 'Different hours'}),
        published: true,
      ),
      throwsStateError,
    );
  });

  test('Demo facts and hours read live from the owner data', () async {
    final fixture = DemoFixture.build();
    final directory = fixture.directory;
    final own = directory.cards.firstWhere((c) => c.id == 'ws-1');
    expect((await directory.detail(own))?.amenities, contains('wifi'));
    expect((await directory.detail(own))?.openingHours?.endMinutes, 18 * 60);
    final rules = fixture.space(DemoSpaceKey.home).workspaces;
    final hours = await rules.fetchWorkHours('ws-1');
    await rules.setWorkHours('ws-1', hours.copyWith(endMinutes: 17 * 60));
    expect((await directory.detail(own))?.openingHours?.endMinutes, 17 * 60);
    await directory.savePage(
      'ws-1',
      PublicationPatch.patch({
        'amenities': ['kitchen'],
        'accessibility': null,
      }),
      published: true,
    );
    expect((await directory.detail(own))?.amenities, ['kitchen']);
    expect((await directory.detail(own))?.accessibility, isNull);
    final incomplete = directory.cards.firstWhere((c) => c.id == 'demo-halles');
    expect((await directory.detail(incomplete))?.accessibility, isNull);
  });
}
