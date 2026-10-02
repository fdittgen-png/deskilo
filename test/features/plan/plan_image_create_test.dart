// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2012 checkpoint B — creating a plan image over the real Supabase client
// against a scripted wire: the object is uploaded before the row exists
// (no `pending` row, ever), a failed upload writes no row, and a lost
// insert answer retried with the same operation id converges on ONE row
// pointing at ONE object.
import 'dart:convert';
import 'dart:typed_data';

import 'package:deskilo/core/demo/data/stores.dart';
import 'package:deskilo/features/plan/data/supabase_floor_plan_repository.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _json = {'content-type': 'application/json'};

class _Server {
  final objects = <String, int>{}; // path -> uploads
  final rows = <String, Map<String, dynamic>>{};
  final log = <String>[];
  bool failUpload = false;
  bool loseInsertAnswer = false;

  late final client = SupabaseClient(
    'https://plan.example',
    'anon',
    httpClient: MockClient(_handle),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  Future<http.Response> _handle(http.Request r) async {
    final path = r.url.path;
    if (path.startsWith('/storage/v1/object/floor-plans/')) {
      final key = path.substring('/storage/v1/object/floor-plans/'.length);
      log.add('upload');
      if (failUpload) return http.Response('{"error":"boom"}', 500);
      objects[key] = (objects[key] ?? 0) + 1;
      return http.Response(
        jsonEncode({'Key': 'floor-plans/$key'}),
        200,
        headers: _json,
        request: r,
      );
    }
    if (path == '/rest/v1/plan_images' && r.method == 'POST') {
      log.add('insert');
      final row = jsonDecode(r.body) as Map<String, dynamic>;
      // ignore-duplicates: a second insert of the same id changes nothing.
      rows.putIfAbsent(row['id'] as String, () => row);
      if (loseInsertAnswer) {
        loseInsertAnswer = false;
        throw http.ClientException('connection reset');
      }
      return http.Response('', 201, headers: _json, request: r);
    }
    if (path == '/rest/v1/plan_images' && r.method == 'GET') {
      final id = r.url.queryParameters['id']!.substring(3);
      return http.Response(
        jsonEncode(rows[id]),
        200,
        headers: _json,
        request: r,
      );
    }
    return http.Response('{}', 404);
  }
}

void main() {
  final bytes = Uint8List.fromList([1, 2, 3]);
  const rect = GridRect(x: 1, y: 2, w: 16, h: 12);

  Future<void> create(_Server s, {String? id}) =>
      SupabaseFloorPlanRepository(
        s.client,
        InMemoryCacheStore(),
      ).createPlanImage(
        workspaceId: 'ws-1',
        levelId: 'level-1',
        rect: rect,
        bytes: bytes,
        contentType: 'image/png',
        imageId: id,
      );

  test(
    'the object is uploaded before the row; the row is never pending',
    () async {
      final s = _Server();
      final image =
          await SupabaseFloorPlanRepository(
            s.client,
            InMemoryCacheStore(),
          ).createPlanImage(
            workspaceId: 'ws-1',
            levelId: 'level-1',
            rect: rect,
            bytes: bytes,
            contentType: 'image/png',
          );
      expect(s.log, ['upload', 'insert']);
      expect(s.rows.values.single['storage_path'], 'ws-1/img/${image.id}');
      expect(s.objects.keys, ['ws-1/img/${image.id}']);
    },
  );

  test('a failed upload writes no row', () async {
    final s = _Server()..failUpload = true;
    await expectLater(create(s), throwsA(anything));
    expect(s.log, ['upload']);
    expect(s.rows, isEmpty);
  });

  test(
    'a lost insert answer, retried with the same id, is one image',
    () async {
      final s = _Server()..loseInsertAnswer = true;
      const id = '00000000-0000-4000-8000-000000000001';
      await expectLater(create(s, id: id), throwsA(anything));
      expect(s.rows.keys, [id]); // the insert committed; the answer was lost
      await create(s, id: id);
      expect(s.rows.length, 1);
      expect(s.objects, {'ws-1/img/$id': 2}); // same path, overwritten
      expect(s.rows[id]!['storage_path'], 'ws-1/img/$id');
    },
  );
}
