// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1642 — the details someone may send when reporting a problem, built
// from an ALLOW-LIST rather than by scrubbing a log. Every field below is
// a version, a small enum, a count, a registry name or a code; nothing
// free-form survives the projection. A trace entry keeps its time, level,
// area and a safe code, and loses its message, error text and stack
// whole: a regular expression over arbitrary text is not the privacy
// boundary here, the schema is.
//
// Identifiers become aliases that mean something only inside one bundle
// ("workspace-1"), so two bundles cannot be joined into a directory of
// people or spaces. The backend address, which can identify a private
// installation, is left out unless the person includes it, and then only
// as scheme and host.
import 'dart:convert';

import '../trace/trace_logger.dart';

/// Bumped when a field is added, removed or changes meaning.
const int supportBundleVersion = 1;

/// The largest bundle, in bytes, once encoded. Oldest events are dropped
/// first to stay under it.
const int supportBundleMaxBytes = 64 * 1024;

/// The most events a bundle carries, newest kept.
const int supportBundleMaxEvents = 200;

/// A diagnostic check's result as the bundle may state it. Anything the
/// source says that is not one of these reads [unknown], never [ok].
enum SupportCheckStatus { ok, failing, unavailable, unknown }

/// What the person chose to report on.
class SupportBundleInput {
  const SupportBundleInput({
    required this.createdAt,
    required this.from,
    required this.to,
    this.appVersion = '',
    this.platform = '',
    this.installedSchema,
    this.requiredSchema,
    this.traces = const [],
    this.features = const {},
    this.checks = const {},
    this.backendUrl,
    this.includeBackendHost = false,
    this.workspaceId,
    this.demo = false,
  });

  final DateTime createdAt;
  final DateTime from;
  final DateTime to;
  final String appVersion;
  final String platform;
  final int? installedSchema;
  final int? requiredSchema;
  final List<TraceEntry> traces;

  /// Registry feature name → effective state.
  final Map<String, bool> features;

  /// Check id → the status word its source reported.
  final Map<String, String> checks;

  final String? backendUrl;
  final bool includeBackendHost;
  final String? workspaceId;

  /// Demo mode: nothing here came from a real backend.
  final bool demo;
}

final _version = RegExp(r'^\d{1,4}\.\d{1,4}\.\d{1,6}(\+\d{1,9})?$');
final _area = RegExp(r'^[a-z][a-z0-9_.\-]{0,31}$');
final _name = RegExp(r'^[a-zA-Z][a-zA-Z0-9]{0,63}$');
final _checkId = RegExp(r'^[a-z][a-z0-9_.\-]{0,47}$');
final _sqlState = RegExp(r'\bcode:\s*([0-9A-Z]{5})\b');
const _platforms = {'android', 'ios', 'web', 'macos', 'windows', 'linux'};

/// The categories that never enter a bundle, shown in the preview so the
/// person knows what was left out.
const supportBundleExclusions = [
  'messages',
  'error_text',
  'stack_traces',
  'names_and_emails',
  'amounts',
  'tokens_and_keys',
  'invite_codes',
  'urls_and_paths',
  'raw_payloads',
];

/// A safe code for an event: a transport failure, a five-character SQL
/// state quoted by the server, or plain `error`. Never text.
String supportEventCode(TraceEntry e) {
  if (isTransientNetworkFailure(e.error) ||
      isTransientNetworkFailure(e.message)) {
    return 'network';
  }
  final state = _sqlState.firstMatch(e.error ?? '')?.group(1);
  if (state != null) return 'sql_$state';
  return e.level == TraceLevel.warn ? 'warning' : 'error';
}

String? _backendHost(String? url) {
  final uri = Uri.tryParse(url ?? '');
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  if (uri.scheme != 'https' && uri.scheme != 'http') return null;
  return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
}

/// The bundle, as the exact bytes the preview shows and Save writes.
class SupportBundle {
  SupportBundle._(this.json, this.text, this.droppedEvents);

  final Map<String, Object?> json;

  /// The encoded bundle: what is previewed IS what is saved.
  final String text;

  /// Events in the window left out to respect the size bounds.
  final int droppedEvents;

  int get bytes => utf8.encode(text).length;
}

/// Projects [input] through the allow-list and encodes it.
SupportBundle buildSupportBundle(SupportBundleInput input) {
  final windowed = [
    for (final e in input.traces)
      if ((e.level == TraceLevel.warn || e.level == TraceLevel.error) &&
          !e.ts.isBefore(input.from) &&
          !e.ts.isAfter(input.to))
        e,
  ]..sort((a, b) => b.ts.compareTo(a.ts));
  var events = [
    for (final e in windowed.take(supportBundleMaxEvents))
      {
        't': e.ts.toUtc().toIso8601String(),
        'level': e.level.name,
        'area': _area.hasMatch(e.area) ? e.area : 'other',
        'code': supportEventCode(e),
      },
  ];

  Map<String, Object?> shape(List<Map<String, String>> kept) => {
    'bundle_version': supportBundleVersion,
    'created_at': input.createdAt.toUtc().toIso8601String(),
    'window': {
      'from': input.from.toUtc().toIso8601String(),
      'to': input.to.toUtc().toIso8601String(),
    },
    'mode': input.demo ? 'demo' : 'connected',
    'app': {
      'version': _version.hasMatch(input.appVersion)
          ? input.appVersion
          : 'unknown',
      'platform': _platforms.contains(input.platform)
          ? input.platform
          : 'unknown',
    },
    'schema': {
      'installed': input.installedSchema,
      'required': input.requiredSchema,
    },
    'context': {
      'workspace': input.workspaceId == null ? null : 'workspace-1',
      'backend': input.includeBackendHost
          ? (_backendHost(input.backendUrl) ?? 'unknown')
          : 'omitted',
    },
    'features': {
      for (final f in (input.features.keys.toList()..sort()))
        if (_name.hasMatch(f)) f: input.features[f],
    },
    'checks': {
      for (final c in (input.checks.keys.toList()..sort()))
        if (_checkId.hasMatch(c))
          c: SupportCheckStatus.values
              .firstWhere(
                (s) => s.name == input.checks[c],
                orElse: () => SupportCheckStatus.unknown,
              )
              .name,
    },
    'events': kept,
    'events_in_window': windowed.length,
    'excluded': supportBundleExclusions,
  };

  const encoder = JsonEncoder.withIndent('  ');
  var text = encoder.convert(shape(events));
  while (utf8.encode(text).length > supportBundleMaxBytes &&
      events.isNotEmpty) {
    events = events.sublist(0, events.length ~/ 2);
    text = encoder.convert(shape(events));
  }
  final json = shape(events);
  return SupportBundle._(json, text, windowed.length - events.length);
}
