// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3915 — each page the web build publishes says what it may load and
// where it may connect, in a content policy that runs no inline script and
// no eval. The policies are pinned here: a change is a reviewed change of
// this file. The app page's policy is proven in a real browser by the web
// build's start-up step (tool/web/first_load_trace.mjs), which fails on any
// load the policy refuses.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app page: its own files, the engine's compiled code and the style
/// elements it inserts, and any server a person chooses at run time over
/// TLS (its requests and its images), or a local one being set up.
const _appPolicy =
    "default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; "
    "style-src 'self' 'unsafe-inline'; img-src 'self' data: blob: https:; "
    "font-src 'self'; "
    "connect-src 'self' https: wss: http://localhost:* http://127.0.0.1:* "
    'http://[::1]:* ws://localhost:* ws://127.0.0.1:* ws://[::1]:*; '
    "manifest-src 'self'; object-src 'none'; base-uri 'self'; "
    "form-action 'self'";

/// The setup questionnaire: its own files and no request at all (#3904).
const _setupPolicy =
    "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; "
    "img-src 'self' data: blob:; connect-src 'none'; object-src 'none'; "
    "base-uri 'none'; form-action 'none'";

String? _policyOf(String page) =>
    RegExp(r'<meta http-equiv="Content-Security-Policy" content="([^"]+)">')
        .firstMatch(page)
        ?.group(1);

void main() {
  final pages = {'web/index.html': _appPolicy, 'web/setup.html': _setupPolicy};

  for (final MapEntry(key: path, value: pinned) in pages.entries) {
    test('$path carries its pinned content policy', () {
      expect(_policyOf(File(path).readAsStringSync()), pinned);
    });
  }

  test('no page policy runs an inline script or eval', () {
    for (final pinned in pages.values) {
      final scripts = RegExp(r'script-src ([^;]+)').firstMatch(pinned)!;
      expect(scripts.group(1), isNot(contains("'unsafe-inline'")));
      expect(pinned, isNot(contains("'unsafe-eval'")));
    }
  });

  test('no page carries an inline script or a handler in its markup', () {
    for (final path in pages.keys) {
      final page = File(path).readAsStringSync();
      expect(
        RegExp(r'<script(\s[^>]*)?>\s*[^<\s]').hasMatch(page),
        isFalse,
        reason: '$path: a script is a file the page loads',
      );
      expect(
        RegExp(r'\son[a-z]+="').hasMatch(page),
        isFalse,
        reason: '$path: a handler is wired from a script file',
      );
    }
  });

  test('the web build starts the app under its policy and fails on a '
      'refused load', () {
    final trace = File('tool/web/first_load_trace.mjs').readAsStringSync();
    expect(trace, contains("'securitypolicyviolation'"));
    expect(trace, contains("failOnRefusal('before the first frame')"));
    final workflow = File('.github/workflows/web.yml').readAsStringSync();
    expect(workflow, contains('node tool/web/first_load_trace.mjs'));
  });
}
