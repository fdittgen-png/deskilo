// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2387 — the profile rows as the RPCs send them. A full row decodes; a
// row missing a non-null column fails naming the RPC, the key and the
// expected type, so a column rename fails here and not on a phone.
import 'package:deskilo/core/data/json_reader.dart';
import 'package:deskilo/features/directory/domain/message_marks.dart';
import 'package:deskilo/features/profile/domain/privacy_notice.dart';
import 'package:deskilo/features/profile/domain/rights_request.dart';
import 'package:deskilo/features/reservations/domain/place_feedback.dart';
import 'package:flutter_test/flutter_test.dart';

const _rightsRow = {
  'id': 'r1',
  'kind': 'erasure',
  'status': 'received',
  'received_at': '2026-03-04T09:00:00Z',
  'due_on': '2026-04-03',
  'details': '',
  'extended_due_on': null,
  'outcome': {'removed': 3},
};

Matcher _missing(String rpc, String key, String expected) => throwsA(
  isA<JsonShapeException>()
      .having((e) => e.context, 'context', rpc)
      .having((e) => e.key, 'key', key)
      .having((e) => e.expected, 'expected', expected),
);

void main() {
  test('my_rights_requests: a full row decodes', () {
    final r = RightsRequest.fromJson(
      Map<String, dynamic>.of(_rightsRow),
      context: 'my_rights_requests',
    );
    expect(r.dueOn, DateTime(2026, 4, 3));
    expect(r.extendedDueOn, isNull);
    expect(r.outcome, {'removed': 3});
  });

  for (final (key, expected) in [
    ('id', 'String'),
    ('kind', 'String'),
    ('received_at', 'ISO-8601 String'),
    ('due_on', 'ISO-8601 String'),
  ]) {
    test('my_rights_requests: a row without $key names it', () {
      final row = Map<String, dynamic>.of(_rightsRow)..remove(key);
      expect(
        () => RightsRequest.fromJson(row, context: 'my_rights_requests'),
        _missing('my_rights_requests', key, expected),
      );
    });
  }

  test('preview_my_erasure: an element names the RPC too', () {
    expect(
      () => ErasurePreview.fromJson({
        'removed': [
          {'store': 'profile', 'count': 'three'},
        ],
      }),
      _missing('preview_my_erasure', 'count', 'int?'),
    );
  });

  test('current_privacy_notice: a notice without a version names the path', () {
    expect(
      () => PrivacyNotices.fromJson({
        'installation': {'manifest': <String, dynamic>{}},
      }),
      _missing('current_privacy_notice.installation', 'version', 'String'),
    );
    final notices = PrivacyNotices.fromJson({
      'installation': {
        'version': 'v1',
        'manifest': {
          'controller': {'name': 'C'},
          'recipients': [
            {'name': 'Host', 'essential': false},
          ],
        },
      },
      'acknowledged': [
        {'workspace_id': null, 'version': 'v1'},
      ],
    });
    expect(notices.installation!.controllerName, 'C');
    expect(notices.installation!.recipients.single.essential, isFalse);
    expect(notices.acknowledgedVersions, {':v1'});
  });

  test('message_marks_in: a reaction without its message names it', () {
    expect(
      () => MessageMarks.fromJson({
        'reactions': [
          {'emoji': '👍'},
        ],
      }),
      _missing('message_marks_in', 'message_id', 'String'),
    );
  });

  test('place_feedback: a mistyped count is an error, not a zero', () {
    expect(
      () => PlaceFeedback.fromJson({'count': '2'}),
      _missing('place_feedback', 'count', 'int?'),
    );
  });
}
