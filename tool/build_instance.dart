// SPDX-License-Identifier: 0BSD
//
// Bundles everything a NEW instance needs into one asset the app (and
// the CLI) can install through the Supabase Management API (#977):
// every migration of supabase/migrations, in order, and every edge
// function of supabase/functions with its sources.
//
// Usage:
//   dart run tool/build_instance.dart          # writes assets/instance/bundle.json
//
// test/lint/instance_bundle_test.dart fails when the asset is older than
// the migrations or the functions, so a new migration cannot ship
// without the bundle that installs it.
import 'dart:convert';
import 'dart:io';

/// Webhooks are called by the payment providers, not by a signed-in
/// member: they verify their own signatures and must not demand a JWT.
const Map<String, bool> functionVerifyJwt = {
  'badge-signin': true,
  'create-payment-order': true,
  'mollie-webhook': false,
  'paypal-webhook': false,
  'send-e-invoice': true,
  'send-push': true,
  'send-whatsapp': true,
  'stripe-webhook': false,
};

/// The bundle, built from the repository at [root].
Map<String, Object?> buildInstanceBundle(String root) {
  final migrations = Directory('$root/supabase/migrations')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final functions = Directory('$root/supabase/functions')
      .listSync()
      .whereType<Directory>()
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  // #1137 — `_shared/` holds modules the functions import as
  // `../_shared/x.ts`. The deploy endpoint resolves imports against the
  // uploaded file paths, so every function carries the shared files
  // under their own path and its own files under `<slug>/` — the layout
  // the Supabase CLI uploads to the same endpoint. Before this the
  // bundle skipped `_shared/` (no index.ts) and a self-hosted deploy
  // would have failed on the first import.
  final sharedDir = Directory('$root/supabase/functions/_shared');
  final shared = [
    if (sharedDir.existsSync())
      for (final f in sharedDir.listSync().whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
        {
          'name': '_shared/${f.uri.pathSegments.last}',
          'content': f.readAsStringSync(),
        },
  ];
  return {
    'schema': [
      for (final file in migrations)
        {
          'name': file.uri.pathSegments.last,
          'sql': file.readAsStringSync(),
        },
    ],
    'functions': [
      for (final dir in functions)
        if (File('${dir.path}/index.ts').existsSync())
          {
            'slug': dir.uri.pathSegments.where((s) => s.isNotEmpty).last,
            'verifyJwt': functionVerifyJwt[
                    dir.uri.pathSegments.where((s) => s.isNotEmpty).last] ??
                true,
            'files': [
              for (final f in dir.listSync().whereType<File>().toList()
                ..sort((a, b) => a.path.compareTo(b.path)))
                {
                  'name':
                      '${dir.uri.pathSegments.where((s) => s.isNotEmpty).last}/${f.uri.pathSegments.last}',
                  'content': f.readAsStringSync(),
                },
              ...shared,
            ],
          },
    ],
  };
}

String encodeInstanceBundle(Map<String, Object?> bundle) =>
    const JsonEncoder.withIndent(' ').convert(bundle);

void main(List<String> args) {
  final root = args.isEmpty ? '.' : args.first;
  final out = File('$root/assets/instance/bundle.json');
  out.parent.createSync(recursive: true);
  final bundle = buildInstanceBundle(root);
  out.writeAsStringSync('${encodeInstanceBundle(bundle)}\n');
  final schema = bundle['schema'] as List;
  final functions = bundle['functions'] as List;
  stdout.writeln('wrote ${out.path}: ${schema.length} migrations, '
      '${functions.length} functions, ${out.lengthSync()} bytes');
}
