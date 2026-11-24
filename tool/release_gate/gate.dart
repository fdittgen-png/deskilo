// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The release train's installation gate: before a candidate is published to
// a track, the installation that track ships to is read, and the candidate
// is published only when that installation is PROVEN ready for it.
//
// Three answers, and only the first publishes:
//   * sufficient   -- the installation runs at least the schema the candidate
//                     needs, and its app floor accepts the candidate;
//   * insufficient -- it answered, and what it said is that it is behind (the
//                     missing migrations are named) or that it refuses this
//                     app (its floor is above the candidate's number);
//   * unverified   -- nothing usable answered: a timeout, a refusal, a body
//                     that is not a number. The app's forgiving offline state
//                     never stands in for evidence here.
//
// Pure Dart with dart: imports only, so the train runs it with a bare Dart SDK
// and no package resolution.
import 'dart:convert';
import 'dart:io';

/// What the gate concludes.
enum ReleaseVerdict {
  sufficient(0),
  insufficient(1),
  unverified(2);

  const ReleaseVerdict(this.exitCode);

  /// The process exit of the CLI: zero only when the train may publish.
  final int exitCode;
}

/// One read of an installation function, as the gate sees it.
sealed class ProbeAnswer {
  const ProbeAnswer();
}

/// The function answered with this decoded JSON value.
final class Answered extends ProbeAnswer {
  const Answered(this.value);
  final Object? value;
}

/// The installation answered that the function does not exist.
final class MissingFunction extends ProbeAnswer {
  const MissingFunction();
}

/// Nothing usable came back.
final class Unreadable extends ProbeAnswer {
  const Unreadable(this.reason);
  final String reason;
}

/// One migration file of the candidate.
typedef Migration = ({int number, String file});

/// What the pinned candidate needs, read from its own tree.
typedef CandidateNeeds = ({int schema, int app, List<Migration> migrations});

/// The gate's conclusion with its reasons, in the order they were found.
typedef GateResult = ({
  ReleaseVerdict verdict,
  List<String> reasons,
  List<Migration> missing,
});

/// Judges an installation's two answers against what the candidate needs.
GateResult judgeInstallation({
  required CandidateNeeds needs,
  required ProbeAnswer schema,
  required ProbeAnswer floor,
}) {
  final reasons = <String>[];
  var insufficient = false;
  var unverified = false;
  var missing = <Migration>[];

  switch (schema) {
    case Answered(value: final int version):
      if (version < needs.schema) {
        insufficient = true;
        missing = [
          for (final m in needs.migrations)
            if (m.number > version && m.number <= needs.schema) m,
        ];
      }
      reasons.add(
        'the installation runs schema $version; the candidate needs ${needs.schema}',
      );
    case Answered(value: null):
      unverified = true;
      reasons.add(
        'the installation has a version function but recorded no version',
      );
    case Answered(:final value):
      unverified = true;
      reasons.add('the schema version is not a number: ${_short(value)}');
    case MissingFunction():
      insufficient = true;
      missing = [
        for (final m in needs.migrations)
          if (m.number <= needs.schema) m,
      ];
      reasons.add(
        'the installation has no schema version: it predates the version marker',
      );
    case Unreadable(:final reason):
      unverified = true;
      reasons.add('the schema version could not be read: $reason');
  }

  switch (floor) {
    case Answered(value: null):
    case MissingFunction():
      reasons.add('the installation states no app floor');
    case Answered(value: final int number):
      if (needs.app < number) insufficient = true;
      reasons.add(
        'the installation accepts apps from $number; the candidate is ${needs.app}',
      );
    case Answered(:final value):
      unverified = true;
      reasons.add('the app floor is not a number: ${_short(value)}');
    case Unreadable(:final reason):
      unverified = true;
      reasons.add('the app floor could not be read: $reason');
  }

  final verdict = insufficient
      ? ReleaseVerdict.insufficient
      : unverified
      ? ReleaseVerdict.unverified
      : ReleaseVerdict.sufficient;
  return (verdict: verdict, reasons: reasons, missing: missing);
}

String _short(Object? value) {
  final text = '$value';
  return text.length > 80 ? '${text.substring(0, 80)}…' : text;
}

final _schemaNeed = RegExp(
  r'^const int requiredSchemaVersion = (\d+);',
  multiLine: true,
);
final _appNumber = RegExp(
  r'^const int appCompatibilityNumber = (\d+);',
  multiLine: true,
);
final _migrationFile = RegExp(r'^(\d{4})_[a-z0-9_]+\.sql$');

/// Reads what the candidate checked out at [root] needs: the schema number
/// and the app compatibility number it declares, and its migrations. Throws
/// [FormatException] when either declaration is not where the app keeps it:
/// a requirement that cannot be read is never assumed.
CandidateNeeds readCandidateNeeds(Directory root) {
  int declared(String path, RegExp pattern) {
    final file = File('${root.path}/$path');
    if (!file.existsSync()) throw FormatException('$path is missing');
    final match = pattern.firstMatch(file.readAsStringSync());
    if (match == null)
      throw FormatException('$path declares no ${pattern.pattern}');
    return int.parse(match.group(1)!);
  }

  final schema = declared(
    'lib/core/instance/schema_compatibility.dart',
    _schemaNeed,
  );
  final app = declared('lib/core/instance/app_compatibility.dart', _appNumber);
  final dir = Directory('${root.path}/supabase/migrations');
  final migrations = <Migration>[
    if (dir.existsSync())
      for (final f in dir.listSync().whereType<File>())
        if (_migrationFile.firstMatch(f.uri.pathSegments.last) case final m?)
          (number: int.parse(m.group(1)!), file: f.uri.pathSegments.last),
  ]..sort((a, b) => a.number.compareTo(b.number));
  return (schema: schema, app: app, migrations: migrations);
}

/// The installation a track ships to, named explicitly.
typedef Installation = ({String name, String url, String key});

/// Reads the track's installation from the committed map. Throws
/// [FormatException] for a track the map does not name: a train never
/// guesses where it ships.
Installation installationFor(String mapJson, String track) {
  final map = jsonDecode(mapJson);
  final tracks = map is Map ? map['tracks'] : null;
  final entry = tracks is Map ? tracks[track] : null;
  if (entry is! Map)
    throw FormatException('no installation is named for the track "$track"');
  final name = entry['installation'], url = entry['url'], key = entry['key'];
  if (name is! String ||
      url is! String ||
      key is! String ||
      !_acceptedUrl(url)) {
    throw FormatException(
      'the installation of "$track" needs a name, an https url and a key',
    );
  }
  return (name: name, url: url, key: key);
}

/// An installation is reached over https; plain http only on this machine's
/// loopback, where the gate's own tests stand up an installation.
bool _acceptedUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return false;
  return uri.scheme == 'https' ||
      (uri.scheme == 'http' &&
          (uri.host == '127.0.0.1' || uri.host == 'localhost'));
}

/// Calls one argument-less function of [installation] with its publishable
/// key, as anon: the version reads need no secret.
Future<ProbeAnswer> callInstallation(
  Installation installation,
  String function, {
  required Duration timeout,
}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final uri = Uri.parse('${installation.url}/rest/v1/rpc/$function');
    final (status, body) = await () async {
      final request = await client.postUrl(uri);
      request.headers
        ..set('apikey', installation.key)
        ..contentType = ContentType.json;
      request.write('{}');
      final response = await request.close();
      return (
        response.statusCode,
        await response.transform(utf8.decoder).join(),
      );
    }().timeout(timeout);
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return Unreadable('HTTP $status, a body that is not JSON');
    }
    if (status == 200) return Answered(decoded);
    final code = decoded is Map ? decoded['code'] : null;
    if (status == 404 && (code == 'PGRST202' || code == '42883')) {
      return const MissingFunction();
    }
    return Unreadable('HTTP $status${code is String ? ' ($code)' : ''}');
  } on Exception catch (e) {
    return Unreadable(e.runtimeType.toString());
  } finally {
    client.close(force: true);
  }
}

/// The report the train prints in its summary.
String renderGate({
  required String track,
  required Installation installation,
  required CandidateNeeds needs,
  required GateResult result,
}) {
  final b = StringBuffer()
    ..writeln('## Installation gate')
    ..writeln()
    ..writeln(
      '- **Track:** $track → installation **${installation.name}** (${installation.url})',
    )
    ..writeln(
      '- **Candidate needs:** schema ${needs.schema}, app compatibility ${needs.app}',
    )
    ..writeln(
      '- **Verdict:** ${switch (result.verdict) {
        ReleaseVerdict.sufficient => 'ready: the train publishes',
        ReleaseVerdict.insufficient => 'behind: nothing is published',
        ReleaseVerdict.unverified => 'not verified: nothing is published',
      }}',
    )
    ..writeln();
  for (final r in result.reasons) {
    b.writeln('- $r');
  }
  if (result.missing.isNotEmpty) {
    b
      ..writeln()
      ..writeln(
        'Migrations the installation is missing (apply them, then run the train again):',
      )
      ..writeln();
    for (final m in result.missing) {
      b.writeln('- `${m.file}`');
    }
  }
  return b.toString();
}
