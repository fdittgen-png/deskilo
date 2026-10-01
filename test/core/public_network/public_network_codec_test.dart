// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1847 — the public network adapter reads a record the way a mixed-version
// network needs: an additive optional field from a newer server is ignored,
// a required term or state this version cannot interpret refuses the
// record, and a private field that leaks into a response never survives the
// allow-listed projection. Management input the contract does not list is
// refused rather than dropped. The fixtures are synthetic newer-server
// answers, labelled as such: no released N-1 protocol exists yet.
import 'package:deskilo/core/public_network/public_network_codec.dart';
import 'package:deskilo/core/public_network/public_network_operations.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> card({
  Map<String, Object?> document = const {},
  Map<String, Object?> extra = const {},
}) => {
  'workspace_id': '00000000-0000-4000-8000-000000001847',
  'name': 'Quiet office',
  'updated_at': '2026-10-01T09:30:00.123456+00:00',
  'document': {
    'name': 'Quiet office',
    'host_type': 'company',
    'currency': 'EUR',
    'booking_unit': 'half_day',
    'address': '10 Main Street',
    'latitude': '48.86',
    'longitude': '2.35',
    'website': 'https://quiet.example',
    'contacts': [
      {
        'user_id': '00000000-0000-4000-8000-0000000018a1',
        'name': 'Alice',
        'owner': true,
        'available': true,
      },
    ],
    ...document,
  },
  ...extra,
};

Matcher refusedAt(String field) => throwsA(
  isA<PublicContractRefusal>().having((r) => r.field, 'field', field),
);

void main() {
  const schema = 'PublicWorkspaceCard';

  test('today\'s published card passes whole', () {
    final out = decodePublicRecord(schema, card());
    final doc = out['document']! as Map<String, Object?>;
    expect(out['name'], 'Quiet office');
    expect(doc['host_type'], 'company');
    expect(doc['booking_unit'], 'half_day');
    expect((doc['contacts']! as List).single, containsPair('owner', true));
  });

  group('synthetic newer server: additive optional fields', () {
    test('an unknown optional field is ignored and the card is kept', () {
      final out = decodePublicRecord(
        schema,
        card(
          document: {'opening_hours_note': 'Mon–Fri'},
          extra: {'rating': 4.5},
        ),
      );
      expect(out.containsKey('rating'), isFalse);
      expect(
        (out['document']! as Map).containsKey('opening_hours_note'),
        isFalse,
      );
      expect((out['document']! as Map)['name'], 'Quiet office');
    });

    test('an unknown value of an OPTIONAL state is dropped, not guessed', () {
      final out = decodePublicRecord(
        schema,
        card(document: {'booking_unit': 'minutes_10'}),
      );
      final doc = out['document']! as Map;
      expect(doc.containsKey('booking_unit'), isFalse);
      expect(doc['host_type'], 'company');
    });

    test('a must-understand list naming only known terms is accepted', () {
      final out = decodePublicRecord(
        schema,
        card(
          document: {
            'must_understand': ['host_type', 'currency'],
          },
        ),
      );
      expect((out['document']! as Map).containsKey('must_understand'), isFalse);
    });
  });

  group('synthetic newer server: what this version cannot interpret', () {
    test('an unknown REQUIRED term refuses the card', () {
      expect(
        () => decodePublicRecord(
          schema,
          card(
            document: {
              'price_terms': {'amount_minor': 1500, 'currency': 'EUR'},
              'must_understand': ['price_terms'],
            },
          ),
        ),
        refusedAt('price_terms'),
      );
    });

    test('an unknown value of a REQUIRED state refuses the card', () {
      expect(
        () => decodePublicRecord(
          schema,
          card(document: {'host_type': 'cooperative'}),
        ),
        refusedAt('host_type'),
      );
    });

    test('a missing required field refuses the card', () {
      final raw = card()..remove('workspace_id');
      expect(() => decodePublicRecord(schema, raw), refusedAt('workspace_id'));
    });

    test('an instant without an offset refuses the card', () {
      expect(
        () => decodePublicRecord(
          schema,
          card(extra: {'updated_at': '2026-10-01T09:30:00'}),
        ),
        refusedAt('updated_at'),
      );
    });

    test('a malformed must-understand list refuses the card', () {
      expect(
        () => decodePublicRecord(
          schema,
          card(document: {'must_understand': 'price_terms'}),
        ),
        refusedAt('must_understand'),
      );
    });
  });

  test('private canaries never survive the public projection', () {
    final out = decodePublicRecord(
      schema,
      card(
        document: {
          'invite_code': 'CANARY-INVITE',
          'draft_price_cents': 4200,
          'internal_note': 'CANARY-NOTE',
          'feature_flags': {'publicListings': true},
          'occupants': ['CANARY-PERSON'],
          'contacts': [
            {
              'user_id': '00000000-0000-4000-8000-0000000018a1',
              'name': 'Alice',
              'owner': true,
              'available': false,
              'email': 'canary@private.example',
              'salary_cents': 1,
            },
          ],
        },
        extra: {'company_id': 'CANARY-COMPANY', 'created_by': 'CANARY-USER'},
      ),
    );
    expect('$out', isNot(contains('CANARY')));
    expect('$out', isNot(contains('canary@private')));
    expect('$out', isNot(contains('draft_price_cents')));
    expect('$out', isNot(contains('salary_cents')));
    final doc = out['document']! as Map;
    expect(
      doc.keys.toSet().difference(
        publicNetworkSchemas['PublicWorkspaceDocument']!.fields.keys.toSet(),
      ),
      isEmpty,
    );
  });

  test('an insecure link or an out-of-range coordinate is dropped, the card '
      'kept', () {
    final out = decodePublicRecord(
      schema,
      card(
        document: {
          'website': 'http://plain.example',
          'image_url': 'https://user:pw@host.example/x.png',
          'latitude': '123.4',
        },
      ),
    );
    final doc = out['document']! as Map;
    expect(doc.containsKey('website'), isFalse);
    expect(doc.containsKey('image_url'), isFalse);
    expect(doc.containsKey('latitude'), isFalse);
    expect(doc['longitude'], '2.35');
  });

  test('a malformed contact is dropped; the others stay', () {
    final out = decodePublicRecord(
      schema,
      card(
        document: {
          'contacts': [
            {'name': 'No flags'},
            {'name': 'Bob', 'owner': false, 'available': true},
          ],
        },
      ),
    );
    expect(
      ((out['document']! as Map)['contacts']! as List).map(
        (c) => (c as Map)['name'],
      ),
      ['Bob'],
    );
  });

  test('a directory source must be an https origin', () {
    expect(
      decodePublicRecord('DirectorySource', {
        'origin': 'https://other.example',
        'publishable_key': 'sb_publishable_x',
        'registered_by': 'CANARY',
      }),
      {
        'origin': 'https://other.example',
        'publishable_key': 'sb_publishable_x',
      },
    );
    expect(
      () => decodePublicRecord('DirectorySource', {
        'origin': 'https://other.example/path',
        'publishable_key': 'k',
      }),
      refusedAt('origin'),
    );
  });

  group('management input', () {
    test('the editor\'s keys pass', () {
      expect(
        encodePublicInput('PublicationInput', {
          'host_type': 'person',
          'description': 'A welcoming office',
        }),
        hasLength(2),
      );
    });

    test('an unknown input key is refused, never silently discarded', () {
      expect(
        () => encodePublicInput('PublicationInput', {
          'host_type': 'person',
          'internal_note': 'not public',
        }),
        refusedAt('internal_note'),
      );
    });

    test('an unknown host type is refused before sending', () {
      expect(
        () => encodePublicInput('PublicationInput', {'host_type': 'guild'}),
        refusedAt('host_type'),
      );
    });
  });
}
