// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';
import 'dart:typed_data';

import '../instance/schema_compatibility.dart';

enum SupportMode { local, demo, operator }

enum SupportPlatform { android, ios, macos, windows, linux, web, unknown }

enum SupportCheck { schema, siteUrl, redirects, emailConfirmation, doctor }

enum SupportStatus { ok, attention, unavailable }

enum SupportSeverity { debug, info, warn, error }

/// Privacy is enforced by construction: no raw logs, identities, endpoints,
/// provider messages or arbitrary field names enter this schema.
class SupportBundle {
  SupportBundle._(this.preview);
  static const maxBytes = 16384;
  final String preview;
  Uint8List get bytes => Uint8List.fromList(utf8.encode(preview));

  factory SupportBundle({
    required DateTime from,
    required DateTime until,
    required SupportMode mode,
    required SupportPlatform platform,
    String appVersion = '',
    int? schemaVersion,
    Map<SupportCheck, SupportStatus> checks = const {},
    Map<SupportSeverity, int>? eventCounts,
  }) {
    final window = until.difference(from);
    if (window.isNegative || window > const Duration(hours: 24)) {
      throw ArgumentError('Support window must be between zero and 24 hours');
    }
    final version = RegExp(r'^\d{1,5}\.\d{1,5}\.\d{1,5}(\+\d{1,12})?$');
    final value = {
      'format': 'deskilo.support',
      'version': 1,
      'mode': mode.name,
      'platform': platform.name,
      'appVersion':
          appVersion.length <= 30 &&
              version.stringMatch(appVersion) == appVersion
          ? appVersion
          : null,
      'requiredSchemaVersion': requiredSchemaVersion,
      'schemaVersion':
          schemaVersion != null && schemaVersion > 0 && schemaVersion <= 1000000
          ? schemaVersion
          : null,
      'window': {
        'from': from.toUtc().toIso8601String(),
        'until': until.toUtc().toIso8601String(),
      },
      'clientAlias': 'client-1',
      'checks': {
        for (final check in SupportCheck.values)
          check.name: (checks[check] ?? SupportStatus.unavailable).name,
      },
      'localEventCounts': eventCounts == null
          ? null
          : {
              for (final severity in SupportSeverity.values)
                severity.name: (eventCounts[severity] ?? 0).clamp(0, 500),
            },
      'excludes': [
        'identity',
        'installation',
        'credentials',
        'businessRecords',
        'rawLogs',
      ],
    };
    final preview = const JsonEncoder.withIndent('  ').convert(value);
    if (utf8.encode(preview).length > maxBytes) {
      throw StateError('Support bundle exceeds its limit');
    }
    return SupportBundle._(preview);
  }
}
