// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3407 -- the field checks both halves of the recording validator share:
// they record a finding and answer null, so a caller returns at the first.
import 'recording_issue.dart';

/// Control characters other than newline and tab: refused in prose.
final _controlChars = RegExp(r'[\u0000-\u0008\u000B-\u001F\u007F]');

class FieldChecks {
  final issues = <RecordingIssue>[];

  bool get failed => issues.any((i) => i.fatal);

  void fatal(RecordingIssueCode code, String path) =>
      issues.add(RecordingIssue(code, path));

  bool onlyKeys(Map<Object?, Object?> map, Set<String> allowed, String path) {
    for (final key in map.keys) {
      if (key is! String || !allowed.contains(key)) {
        fatal(RecordingIssueCode.unknownKey, path);
        return false;
      }
    }
    return true;
  }

  int? integer(Object? v, String path,
      {int min = 0, int? max, bool req = true}) {
    if (v == null && !req) return null;
    if (v is! int || v < min || (max != null && v > max)) {
      fatal(
        v == null
            ? RecordingIssueCode.missingField
            : RecordingIssueCode.badValue,
        path,
      );
      return null;
    }
    return v;
  }

  String? prose(Object? v, int maxLength, String path) {
    if (v == null) return null;
    if (v is! String) {
      fatal(RecordingIssueCode.badValue, path);
      return null;
    }
    if (v.length > maxLength) {
      fatal(RecordingIssueCode.tooLong, path);
      return null;
    }
    if (_controlChars.hasMatch(v)) {
      fatal(RecordingIssueCode.badValue, path);
      return null;
    }
    return v;
  }
}
