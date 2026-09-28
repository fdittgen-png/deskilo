// SPDX-License-Identifier: AGPL-3.0-or-later
// #1661: actual independently authenticated local PostgREST -> repository ->
// workbook -> saved bytes. Started by test/helpers/workbook_provenance_runtime.py;
// opt-in, never a fake substitute for the two-installation check.
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deskilo/features/workspace/application/template_workbook.dart';
import 'package:deskilo/features/workspace/data/supabase_workspace_repository.dart';
import 'package:deskilo/features/workspace/data/supabase_workbook_origin_repository.dart';
import 'package:deskilo/features/workspace/domain/template_inspection.dart';

class HeldNativeRead extends SupabaseWorkspaceRepository {
  HeldNativeRead(super.client);
  final read = Completer<void>();
  final release = Completer<void>();
  @override
  Future<TemplateInspection> inspectWorkspaceTemplate(String id) async {
    final result = await super.inspectWorkspaceTemplate(id);
    read.complete();
    await release.future;
    return result;
  }
}

void main() {
  final fixture = Platform.environment['DESKILO_WORKBOOK_FIXTURE'];
  test('independent authenticated installations with equal template IDs save exact provenance', () async {
    final rows = jsonDecode(await File(fixture!).readAsString()) as List<dynamic>;
    final origins = <String>[];
    for (var i = 0; i < rows.length; i++) {
      final row = Map<String, dynamic>.from(rows[i] as Map);
      final uri = Uri.parse(row['url'] as String);
      expect(uri.scheme, 'http');
      expect(uri.host, '127.0.0.1');
      final client = SupabaseClient(row['url'] as String, row['key'] as String,
        authOptions: const AuthClientOptions(autoRefreshToken: false));
      try {
        await client.auth.signInWithPassword(email: ((row['session'] as Map)['user'] as Map)['email'] as String,
          password: row['password'] as String);
        final source = SupabaseWorkbookOriginRepository(client);
        final origin = await source.read();
        expect(origin.installationId, row['installation']);
        expect(origin.accountId, (row['session'] as Map)['user']['id']);
        await client.auth.refreshSession();
        expect(origin.sameContext(await source.read()), true,
          reason: 'refresh retains the same target, account and Auth session');
        origins.add(origin.scopedTemplate(row['template_id'] as String));
        var saves = 0;
        final export = TemplateWorkbookExport(SupabaseWorkspaceRepository(client),
          ({required bytes, required fileName}) async {
            saves++;
            final path = '${File(fixture).parent.path}/$i.xlsx';
            await File(path).writeAsBytes(bytes);
            return path;
          }, origin: source);
        await export.export([row['template_id'] as String], now: DateTime.utc(2026, 9, 28));
        expect(saves, 1);
        final held = HeldNativeRead(client);
        final staleExport = TemplateWorkbookExport(held,
          ({required bytes, required fileName}) async { saves++; return fileName; }, origin: source);
        final pending = staleExport.export([row['template_id'] as String], now: DateTime.utc(2026, 9, 28));
        final refused = expectLater(pending, throwsStateError);
        await held.read.future;
        await client.auth.signInWithPassword(email: ((row['session'] as Map)['user'] as Map)['email'] as String,
          password: row['password'] as String);
        expect(client.auth.currentUser?.id, origin.accountId, reason: 'same person, fresh Auth session');
        expect(origin.sameContext(await source.read()), false);
        held.release.complete();
        await refused;
        expect(saves, 1, reason: 'late bytes from the previous login cannot be saved');
        // A real authenticated stranger has a session but no template rights.
        await client.auth.recoverSession(jsonEncode(row['stranger']));
        await expectLater(export.export([row['template_id'] as String],
          now: DateTime.utc(2026, 9, 28)), throwsA(isA<Exception>()));
        expect(saves, 1, reason: 'a refusal must not write partial output');
      } finally { await client.dispose(); }
    }
    expect(origins.length, 2);
    expect(origins.toSet().length, 2);
  }, skip: fixture == null ? 'requires two disposable installations' : false);
}
