// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2387 — the one row decoder: typed reads, and a shape error that names
// the RPC, the key, the expected type and what arrived.
import 'package:deskilo/core/data/json_reader.dart';
import 'package:flutter_test/flutter_test.dart';

Matcher _shape(String context, String key, String expected, String actual) =>
    isA<JsonShapeException>()
        .having((e) => e.context, 'context', context)
        .having((e) => e.key, 'key', key)
        .having((e) => e.expected, 'expected', expected)
        .having((e) => e.actual, 'actual', actual);

void main() {
  final r = JsonReader({
    'id': 'a',
    'n': 3.0,
    'avg': 2,
    'flag': true,
    'at': '2026-03-04T09:05:03Z',
    'tags': ['x', 'y'],
    'rows': [
      {'k': 'one'},
      {'k': 'two'},
    ],
    'nested': {'name': 'N'},
  }, context: 'some_rpc');

  test('typed reads', () {
    expect(r.string('id'), 'a');
    expect(r.stringOr('missing', 'fallback'), 'fallback');
    expect(r.stringOrNull('missing'), isNull);
    expect(r.intOrNull('n'), 3);
    expect(r.doubleOrNull('avg'), 2.0);
    expect(r.boolOr('flag', false), isTrue);
    expect(r.boolOr('missing', true), isTrue);
    expect(r.dateTime('at'), DateTime.utc(2026, 3, 4, 9, 5, 3));
    expect(r.dateTimeOrNull('missing'), isNull);
    expect(r.strings('tags'), ['x', 'y']);
    expect(r.strings('missing'), isEmpty);
    expect(r.objects('rows', (row) => row.string('k')), ['one', 'two']);
    expect(r.objectOrNull('nested')!.string('name'), 'N');
    expect(r.objectOrNull('missing'), isNull);
    expect(r.objectOrEmpty('missing'), isEmpty);
  });

  test('a missing required field names the RPC, the key and the type', () {
    expect(
      () => r.string('missing'),
      throwsA(_shape('some_rpc', 'missing', 'String', 'null')),
    );
    expect(
      () => r.dateTime('id'),
      throwsA(_shape('some_rpc', 'id', 'ISO-8601 String', 'String')),
    );
  });

  test('a mistyped optional field is an error, never the fallback', () {
    expect(
      () => r.stringOr('n'),
      throwsA(_shape('some_rpc', 'n', 'String?', 'double')),
    );
    expect(() => r.boolOr('id', false), throwsA(isA<JsonShapeException>()));
    expect(() => r.strings('rows'), throwsA(isA<JsonShapeException>()));
  });

  test('a nested reader carries the path in its context', () {
    expect(
      () => r.objectOrNull('nested')!.string('missing'),
      throwsA(_shape('some_rpc.nested', 'missing', 'String', 'null')),
    );
    expect(
      () => r.objects('rows', (row) => row.string('missing')),
      throwsA(_shape('some_rpc', 'missing', 'String', 'null')),
    );
  });

  test('a row that is not an object is a shape error of the row', () {
    expect(
      () => JsonReader.of([1], context: 'x'),
      throwsA(_shape('x', '', 'object', 'List<int>')),
    );
    expect(JsonReader.of({'a': 1}).intOrNull('a'), 1);
  });

  test('the message is the line a trace needs', () {
    expect(
      const JsonShapeException(
        'my_rights_requests',
        'id',
        'String',
        'null',
      ).toString(),
      'JsonShapeException: my_rights_requests.id expected String, got null',
    );
  });
}
