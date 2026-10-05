// SPDX-License-Identifier: AGPL-3.0-or-later
// A complete, versioned offline snapshot of the browser build, not a list
// guessed from what the current browser happened to fetch.
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

void main(List<String> args) {
  final root = Directory(args.isEmpty ? 'build/web' : args.single);
  final entries = <Map<String, String>>[];
  for (final file in root.listSync(recursive: true).whereType<File>()) {
    final path = file.path.substring(root.path.length + 1).replaceAll('\\', '/');
    if (!(path.startsWith('assets/') || path.startsWith('canvaskit/') ||
        path.startsWith('icons/') || const {
          'index.html', 'flutter_bootstrap.js', 'flutter.js', 'main.dart.js',
          'manifest.json', 'favicon.png', 'version.json',
        }.contains(path))) {
      continue;
    }
    entries.add({'path': path, 'sha256': sha256.convert(file.readAsBytesSync()).toString()});
  }
  if (!entries.any((e) => e['path'] == 'main.dart.js') ||
      !entries.any((e) => e['path']!.endsWith('canvaskit.wasm'))) {
    throw StateError('Build the JavaScript app with local web resources first');
  }
  entries.sort((a, b) => a['path']!.compareTo(b['path']!));
  final version = sha256.convert(utf8.encode(jsonEncode(entries))).toString();
  File('${root.path}/task_tool_manifest.json').writeAsStringSync(
    jsonEncode({'version': version, 'files': entries}));
  stdout.writeln('Verified offline manifest: ${entries.length} files, $version');
}
