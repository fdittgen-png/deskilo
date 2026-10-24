// SPDX-License-Identifier: AGPL-3.0-or-later
//
// DISC-01 (#2555) at the socket: the origin-only client every public read
// is built on, over the platform HTTP client and two real loopback servers.
//
// Invariant: a redirect is answered to the caller, never followed, so the
// redirect's origin receives nothing -- no key, no bearer; a request for
// another origin is refused before anything is sent.
import 'dart:io';

import 'package:deskilo/core/backend/origin_only_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  late HttpServer source, elsewhere;
  late List<HttpHeaders> reachedElsewhere;

  setUp(() async {
    reachedElsewhere = [];
    elsewhere = (await HttpServer.bind(InternetAddress.loopbackIPv4, 0))
      ..listen((request) async {
        reachedElsewhere.add(request.headers);
        request.response
          ..statusCode = 200
          ..write('[]');
        await request.response.close();
      });
    source = (await HttpServer.bind(InternetAddress.loopbackIPv4, 0))
      ..listen((request) async {
        request.response
          ..statusCode = HttpStatus.found
          ..headers.set(
            HttpHeaders.locationHeader,
            'http://127.0.0.1:${elsewhere.port}/rest/v1/public_workspace_cards',
          );
        await request.response.close();
      });
  });

  tearDown(() async {
    await source.close(force: true);
    await elsewhere.close(force: true);
  });

  test('DISC-01: a redirect is returned, not followed; its origin receives '
      'nothing', () async {
    final origin = 'http://127.0.0.1:${source.port}';
    final client = OriginOnlyClient(origin, http.Client());
    addTearDown(client.close);
    final response = await client.get(
      Uri.parse('$origin/rest/v1/public_workspace_cards'),
      headers: {
        'apikey': 'sb_publishable_source_key',
        'Authorization': 'Bearer sb_publishable_source_key',
      },
    );
    expect(response.statusCode, HttpStatus.found);
    expect(reachedElsewhere, isEmpty);
  });

  test(
    'DISC-01: a request for another origin is refused before it is sent',
    () async {
      final client = OriginOnlyClient(
        'http://127.0.0.1:${source.port}',
        http.Client(),
      );
      addTearDown(client.close);
      await expectLater(
        client.get(Uri.parse('http://127.0.0.1:${elsewhere.port}/')),
        throwsStateError,
      );
      expect(reachedElsewhere, isEmpty);
    },
  );
}
