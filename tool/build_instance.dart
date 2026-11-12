// SPDX-License-Identifier: AGPL-3.0-or-later
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
  // #2370 — the accounting target's sign-in redirect carries no JWT; the
  // state kept in Vault is its authority, and every POST action asks the
  // database with the caller's own token. Tested in
  // supabase/functions/accounting-connect/index_test.ts.
  'accounting-connect': false,
  'badge-signin': true,
  // #1616 — the MCP endpoint verifies every bearer itself (auth.getUser,
  // delegated tokens only) before any handler, and serves anonymous
  // protected-resource metadata; the gateway's legacy check would refuse
  // both. Tested in supabase/functions/deskilo-mcp/index_test.ts.
  'deskilo-mcp': false,
  // #2562 — another installation posts identity statuses; the envelope's
  // HMAC is the authority, checked by federation_inbox_accept.
  'federation-inbox': false,
  'create-payment-order': true,
  // #3504 — a manager's own session; the function checks manageBilling.
  'mollie-settlements': true,
  'mollie-webhook': false,
  'paypal-webhook': false,
  'send-e-invoice': true,
  // #3307 — a buyer's own session; begin_purchase_order_send_v1 decides
  // who may send before the provider is reached.
  'send-purchase-order': true,
  // #3673 — an issuer's own session; begin_invoice_email_v1 decides who
  // may send before the provider is reached.
  'send-invoice-email': true,
  'send-push': true,
  // #3673 — an issuer's own session; begin_reminder_email_v1 decides who
  // may send before the provider is reached.
  'send-reminder-email': true,
  'stripe-webhook': false,
  // #2863 — a billing manager's own session; the database answers who
  // may ask before the registry is reached.
  'supplier-lookup': true,
  'vies-check': true,
};

/// #3329 — every file below [dir], nested ones included, in path order:
/// a module moved into a sub-directory must not drop out of the bundle.
List<File> _filesBelow(Directory dir) => dir
    .listSync(recursive: true, followLinks: false)
    .whereType<File>()
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

/// [f]'s path under [dir], with `/` separators and no leading one.
String _relative(Directory dir, File f) {
  final base = dir.path.endsWith('/') ? dir.path : '${dir.path}/';
  return f.path.substring(base.length).replaceAll(r'\', '/');
}

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
      for (final f in _filesBelow(sharedDir))
        // Tests never deploy, shared ones included.
        if (!f.path.endsWith('_test.ts'))
        {
          'name': '_shared/${_relative(sharedDir, f)}',
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
              for (final f in _filesBelow(dir))
                // A function's tests never deploy.
                if (!f.path.endsWith('_test.ts'))
                {
                  'name':
                      '${dir.uri.pathSegments.where((s) => s.isNotEmpty).last}/${_relative(dir, f)}',
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
