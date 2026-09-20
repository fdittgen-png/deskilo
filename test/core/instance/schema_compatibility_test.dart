// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1312 — a server's schema marker against what this build needs: lower or
// absent blocks, equal and higher do not. A server predating the marker is
// `behind`, never `unknown`, because it answered.
import 'package:deskilo/core/instance/schema_compatibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one behind is behind', () {
    expect(compareSchema(225, required: 226), SchemaCompatibility.behind);
  });

  test('no marker at all is behind — the server predates 0226', () {
    expect(compareSchema(null, required: 226), SchemaCompatibility.behind);
  });

  test('equal is current', () {
    expect(compareSchema(226, required: 226), SchemaCompatibility.current);
  });

  test('a newer server is ahead, which is supported', () {
    expect(compareSchema(227, required: 226), SchemaCompatibility.ahead);
  });

  test('the default requirement is this build\'s', () {
    expect(compareSchema(requiredSchemaVersion), SchemaCompatibility.current);
  });
}
