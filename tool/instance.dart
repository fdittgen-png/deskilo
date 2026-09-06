// SPDX-License-Identifier: 0BSD
//
// The instance builder from a terminal (#977) — the same steps the
// in-app wizard runs, for people who prefer a shell:
//
//   dart run tool/instance.dart orgs     --token <personal access token>
//   dart run tool/instance.dart create   --token … --org <organisation id> --name <project name> [--region eu-west-3]
//   dart run tool/instance.dart install  --token … --ref <project ref> [--skip N]
//
// `create` makes the project, waits for it, installs the schema and the
// functions from the repository (not the asset — the repository is the
// source), applies the sign-in settings and prints the endpoint.
// `install` does the same on an existing project. The token is read
// from --token or the SUPABASE_ACCESS_TOKEN environment variable.
import 'dart:io';

import 'package:deskilo/core/instance/instance_builder.dart';
import 'package:deskilo/core/instance/instance_bundle.dart';
import 'package:deskilo/core/instance/management_api.dart';

import 'build_instance.dart';

Future<int> main(List<String> argv) async {
  final args = _Args(argv);
  final token = args.option('token') ?? Platform.environment['SUPABASE_ACCESS_TOKEN'];
  if (args.command.isEmpty || token == null || token.isEmpty) {
    stderr.writeln('usage: dart run tool/instance.dart orgs|create|install --token … [--org … --name … --region … --ref … --skip N]');
    return 2;
  }
  final api = DioSupabaseManagement(token);
  final builder = InstanceBuilder(api);
  try {
    switch (args.command) {
      case 'orgs':
        for (final o in await api.listOrganizations()) {
          stdout.writeln('${o.id}  ${o.name}');
        }
        for (final p in await api.listProjects()) {
          stdout.writeln('  project ${p.ref}  ${p.name}  ${p.region}  ${p.status}');
        }
        return 0;
      case 'create':
        final org = args.option('org');
        final name = args.option('name');
        if (org == null || name == null) {
          stderr.writeln('create needs --org and --name');
          return 2;
        }
        final password = generateDatabasePassword();
        stdout.writeln('database password (keep it): $password');
        final project = await builder.createProject(
          organizationId: org,
          name: name,
          region: args.option('region') ?? 'eu-west-1',
          databasePassword: password,
          onStatus: (s) => stdout.writeln('project: $s'),
        );
        return _install(builder, project.ref, 0);
      case 'install':
        final ref = args.option('ref');
        if (ref == null) {
          stderr.writeln('install needs --ref');
          return 2;
        }
        await builder.waitUntilReady(ref, onStatus: (s) => stdout.writeln('project: $s'));
        return _install(builder, ref, int.tryParse(args.option('skip') ?? '0') ?? 0);
      default:
        stderr.writeln('unknown command ${args.command}');
        return 2;
    }
  } on InstanceStepFailure catch (e) {
    stderr.writeln('stopped at ${e.item}: ${e.message}');
    return 1;
  } on ManagementApiException catch (e) {
    stderr.writeln('Supabase answered ${e.status}: ${e.message}');
    return 1;
  }
}

Future<int> _install(InstanceBuilder builder, String ref, int skip) async {
  final bundle = parseInstanceBundle(encodeInstanceBundle(buildInstanceBundle('.')));
  stdout.writeln('schema: ${bundle.schema.length} migrations (skipping $skip)');
  await builder.installSchema(ref, bundle, skip: skip, onProgress: (p) {
    if (p.current.isNotEmpty) stdout.writeln('  ${p.done + 1}/${p.total} ${p.current}');
  });
  stdout.writeln('functions: ${bundle.functions.length}');
  await builder.deployFunctions(ref, bundle, onProgress: (p) {
    if (p.current.isNotEmpty) stdout.writeln('  ${p.done + 1}/${p.total} ${p.current}');
  });
  await builder.configureAuth(ref);
  final endpoint = await builder.endpointOf(ref);
  stdout.writeln('ready: ${endpoint.url}');
  stdout.writeln('publishable key: ${endpoint.key}');
  stdout.writeln('deskilo://server?url=${Uri.encodeQueryComponent(endpoint.url)}&key=${Uri.encodeQueryComponent(endpoint.key)}');
  return 0;
}

class _Args {
  _Args(List<String> argv) {
    command = argv.firstOrNull ?? '';
    for (var i = 1; i < argv.length; i++) {
      final a = argv[i];
      if (a.startsWith('--')) {
        _options[a.substring(2)] = i + 1 < argv.length ? argv[++i] : '';
      }
    }
  }
  late final String command;
  final _options = <String, String>{};
  String? option(String name) => _options[name];
}
