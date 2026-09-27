// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Real disposable Auth sessions and native repositories must read recovered
// bytes, bookings and statements; another tenant and source tokens are refused.
// Driven only by scripts/restore_check.sh --application; never a hosted target.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:deskilo/core/demo/data/stores.dart';
import 'package:deskilo/core/instance/schema_compatibility.dart';
import 'package:deskilo/features/auth/data/supabase_auth_repository.dart';
import 'package:deskilo/features/auth/domain/auth_outcome.dart';
import 'package:deskilo/features/money/data/supabase_money_repository.dart';
import 'package:deskilo/features/reservations/data/supabase_reservation_repository.dart';
import 'package:deskilo/features/workspace/data/supabase_workspace_files.dart';
import 'package:deskilo/features/workspace/domain/workspace_export_bundle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/local_recovery_doctor.dart';

final _fixture = Platform.environment['DESKILO_RECOVERY_FIXTURE'];

void main() {
  test(
    'real local native recovery boundary',
    () async {
      final file = File(_fixture!);
      final fixture =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final url = Uri.parse(fixture['url'] as String);
      expect(url.scheme, 'http');
      expect(url.host, '127.0.0.1');
      expect(url.hasPort && url.port > 1024, isTrue);
      expect(fixture['disposable'], true);
      await checkRecoveryDoctor(fixture);
      final exporting = fixture['phase'] == 'source';
      final artifacts = fixture['artifacts'] as String;
      final captured = DateTime.parse(fixture['captured_at'] as String);
      final users = (fixture['users'] as List).cast<Map<String, dynamic>>();
      final snapshot = <String, dynamic>{};
      for (var index = 0; index < users.length; index++) {
        final user = users[index];
        final client = SupabaseClient(
          url.toString(),
          fixture['anon_key'] as String,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        try {
          final refused = await SupabaseAuthRepository(client)
              .signInWithPassword(
                email: user['email'] as String,
                password: 'deliberately-wrong-recovery-password',
              );
          expect(
            refused.outcome,
            AuthOutcome.refused,
            reason: 'failed_login_detected',
          );
          final result = await SupabaseAuthRepository(client)
              .signInWithPassword(
                email: user['email'] as String,
                password: user['password'] as String,
              );
          expect(
            result.outcome,
            AuthOutcome.authenticated,
            reason: 'fresh_login',
          );
          final workspace = user['workspace'] as String;
          final other = users[1 - index]['workspace'] as String;
          expect(
            await client.rpc<int>('deskilo_schema_version'),
            requiredSchemaVersion,
            reason: 'schema_compatibility',
          );
          final files = SupabaseWorkspaceFiles(client);
          final names = await files.listFiles(workspace);
          expect(names, [
            'nested/cafe.png',
            'same.png',
          ], reason: 'private_object_inventory');
          final exported = <ExportedFile>[];
          for (final name in names) {
            final bytes = await files.download(workspace, name);
            exported.add((path: name, bytes: bytes));
          }
          expect(
            await files.listFiles(other),
            isEmpty,
            reason: 'cross_tenant_listing',
          );
          await expectLater(
            files.download(other, 'same.png'),
            throwsA(isA<StorageException>()),
            reason: 'cross_tenant_download',
          );
          final reservations = SupabaseReservationRepository(
            client,
            InMemoryCacheStore(),
          );
          final mine = await reservations.fetchAllForExport(workspace);
          expect(
            mine.length,
            index == 0 ? 2 : 1,
            reason: 'native_booking_read',
          );
          expect(
            await reservations.fetchAllForExport(other),
            isEmpty,
            reason: 'cross_tenant_booking',
          );
          final money = SupabaseMoneyRepository(client);
          expect(await money.fetchInvoices(other), isEmpty,
              reason: 'cross_tenant_invoices');
          await expectLater(
            money.fetchStatement(users[1 - index]['member'] as String,
                user['period'] as String),
            throwsA(isA<PostgrestException>()),
            reason: 'cross_tenant_statement',
          );
          expect(
            (await money.fetchInvoices(workspace)).length,
            index == 0 ? 1 : 0,
          );
          final statement = await money.fetchStatement(
            user['member'] as String,
            user['period'] as String,
          );
          final value = {
            'files': {
              for (final f in exported)
                f.path: sha256.convert(f.bytes).toString(),
            },
            'bookings': mine.length,
            'statement': [
              statement.feeCents,
              statement.creditsCents,
              statement.balanceCents,
              statement.usedHalfDays,
            ],
          };
          if (exporting) {
            snapshot['$index'] = value;
            user['source_token'] = client.auth.currentSession!.accessToken;
            await File('$artifacts/workspace-$index.zip').writeAsBytes(
              buildWorkspaceExportZip(
                workspaceId: workspace,
                schemaVersion: requiredSchemaVersion,
                createdAt: captured,
                sheets: const [],
                files: exported,
              ),
            );
          } else {
            final previous = jsonDecode(
              await File('$artifacts/native-snapshot.json').readAsString(),
            ) as Map;
            expect(
              value,
              previous['$index'],
              reason: 'native_recovered_values',
            );
            final stale = await http.get(
              url.resolve('/auth/v1/user'),
              headers: {
                'apikey': fixture['anon_key'] as String,
                'Authorization': 'Bearer ${user['source_token']}',
              },
            );
            expect(
              stale.statusCode,
              anyOf(401, 403),
              reason: 'source_session_not_target_authority',
            );
            final staleData = await http.get(
              url.resolve('/rest/v1/reservations?select=id&limit=1'),
              headers: {
                'apikey': fixture['anon_key'] as String,
                'Authorization': 'Bearer ${user['source_token']}',
              },
            );
            expect(staleData.statusCode, anyOf(401, 403),
                reason: 'source_session_not_target_data_authority');
          }
        } finally {
          await client.dispose();
        }
      }
      if (exporting) {
        await File('$artifacts/native-snapshot.json')
            .writeAsString(jsonEncode(snapshot));
      }
      fixture['completed'] = fixture['phase'];
      await file.writeAsString(jsonEncode(fixture));
    },
    skip: _fixture == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
