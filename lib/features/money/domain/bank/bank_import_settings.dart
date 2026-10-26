// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The bounds a bank file is read under and the window an invoice is
// suggested in, as the space's settings say: `bank.import_max_bytes`,
// `bank.import_max_lines` (both the server's; import_bank_statement_v1
// refuses the same line count) and `bank.match_window_days`. A registry
// that predates a key (an older server) keeps its default. Pure Dart.
import 'package:meta/meta.dart';

import '../../../../core/settings/setting_defaults.g.dart';
import '../../../../core/settings/settings.dart';
import 'bank_statement.dart';

@immutable
class BankImportSettings {
  const BankImportSettings({
    this.maxBytes = SettingDefaults.bankImportMaxBytes,
    this.maxLines = SettingDefaults.bankImportMaxLines,
    this.matchWindowDays = SettingDefaults.bankMatchWindowDays,
  });

  factory BankImportSettings.fromSettings(SettingsSet? settings) {
    int read(String key, int fallback) =>
        settings != null && settings.definitions.containsKey(key)
        ? settings.read<int>(key)
        : fallback;
    return BankImportSettings(
      maxBytes: read('bank.import_max_bytes', SettingDefaults.bankImportMaxBytes),
      maxLines: read('bank.import_max_lines', SettingDefaults.bankImportMaxLines),
      matchWindowDays: read(
        'bank.match_window_days',
        SettingDefaults.bankMatchWindowDays,
      ),
    );
  }

  final int maxBytes;
  final int maxLines;
  final int matchWindowDays;

  BankFileLimits get limits =>
      BankFileLimits(maxBytes: maxBytes, maxLines: maxLines);
}
