// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1282 — expands each builtin template's `feature_profile` into its full
// `configuration.workspace.feature_flags`.
//
//   dart run tool/build_builtin_templates.dart          # rewrite the files
//   dart run tool/build_builtin_templates.dart --check  # exit 1 on drift
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/workspace/domain/template_feature_profile.dart';

void main(List<String> args) {
  final check = args.contains('--check');
  var drift = false;
  final files = Directory('supabase/templates')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final template =
        Map<String, dynamic>.from(jsonDecode(file.readAsStringSync()) as Map);
    final flags = expandTemplateProfile(template);
    if (flags == null) continue;
    final config = Map<String, dynamic>.from(
        template['configuration'] as Map? ?? <String, dynamic>{});
    final workspace = Map<String, dynamic>.from(
        config['workspace'] as Map? ?? <String, dynamic>{});
    workspace['feature_flags'] = {
      for (final k in flags.keys.toList()..sort()) k: flags[k],
    };
    config['workspace'] = workspace;
    template['configuration'] = config;
    final out = '${const JsonEncoder.withIndent('  ').convert(template)}\n';
    if (out != file.readAsStringSync()) {
      drift = true;
      if (check) {
        stderr.writeln('${file.path}: feature_flags do not match feature_profile');
      } else {
        file.writeAsStringSync(out);
        stdout.writeln('wrote ${file.path}');
      }
    }
  }
  if (check && drift) exit(1);
}
