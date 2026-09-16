// SPDX-License-Identifier: 0BSD
// Every process and subprocess has localized, business-readable copy.
import 'dart:io';
import '../../../tool/build_process_labels.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deskilo/features/workspace/domain/workspace_process.dart';
import 'package:deskilo/features/workspace/presentation/process_names.dart';
import 'package:deskilo/l10n/app_localizations.dart';

void main() {
  test('label lookup is generated from registry and English copy', () {
    expect(File('lib/features/workspace/presentation/process_names.dart').readAsStringSync(), buildProcessLabels());
  });
  test('all supported locales render every registry title and description', () async {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = await AppLocalizations.delegate.load(locale);
      for (final process in workspaceProcesses) {
        for (final key in [process.key, ...process.subprocesses.map((s) => s.key)]) {
          final copy = processCopy(l10n, key);
          expect(copy.title, isNotEmpty, reason: '$locale/$key');
          expect(copy.description, isNotEmpty, reason: '$locale/$key');
          expect(copy.description, isNot(copy.title));
          expect(processCopy(null, key).title, isNotEmpty);
        }
      }
    }
  });
}
