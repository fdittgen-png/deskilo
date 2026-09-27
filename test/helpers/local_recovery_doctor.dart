// SPDX-License-Identifier: AGPL-3.0-or-later
// #1641: run the existing doctor against the disposable database and the
// running Auth container's configuration, never the adapter's canned config.
import 'package:deskilo/core/instance/instance_doctor.dart';
import 'package:deskilo/core/instance/schema_compatibility.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/instance_lifecycle/psql_management.dart';

class _LocalManagement extends PsqlSupabaseManagement {
  _LocalManagement(String container, this.config)
    : super(psql: ['docker', 'exec', container, 'psql', '-U', 'postgres']);

  final Map<String, Object?> config;

  @override
  Future<Map<String, Object?>> authConfig(String ref) async => config;
}

Future<void> checkRecoveryDoctor(Map<String, dynamic> fixture) async {
  final config = (fixture['auth_config'] as Map).cast<String, Object?>();
  final container = fixture['container'] as String;
  expect(
    RegExp(r'^supabase_db_deskilo-recovery-[0-9a-f]{12}$').hasMatch(container),
    isTrue,
  );
  final management = _LocalManagement(container, config);
  final findings = await InstanceDoctor(management).examine('postgres');
  expect(findings, isNotEmpty, reason: 'doctor_empty_report');
  expect(hasAlarm(findings), isFalse, reason: 'local_doctor_alarm');
  expect(
    hasProblem(InstanceDoctor.checkAuthConfig(config)),
    isFalse,
    reason: 'auth_redirect_config',
  );
  expect(
    hasProblem(
      InstanceDoctor.checkAuthConfig({
        ...config,
        'uri_allow_list': 'https://wrong.invalid/',
      }),
    ),
    isTrue,
    reason: 'corrupt_auth_config_detected',
  );

  // Actual schema corruption, restored even if an assertion fails. This
  // fixture exists only in the runner's owned disposable namespace.
  await management.runSql(
    'postgres',
    'update public.deskilo_schema_version set version = 1;',
  );
  try {
    final rows = await management.query(
      'postgres',
      InstanceDoctor.schemaHealthSql,
    );
    expect(
      hasAlarm(InstanceDoctor.checkSchema(rows)),
      isTrue,
      reason: 'wrong_schema_detected',
    );
  } finally {
    await management.runSql(
      'postgres',
      'select public.set_deskilo_schema_version($requiredSchemaVersion);',
    );
  }
}
