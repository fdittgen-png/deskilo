// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1867 — the one codec and validator for guides.
//
// An imported guide is untrusted. Refused: oversized or non-JSON text,
// another format, a newer schema, unknown keys anywhere, too many steps,
// a duplicate or malformed step id, overlong text or control
// characters, an outcome its action does not declare, an expectation on
// a non-command, recovery anywhere but under a command, recovery inside
// recovery (no depth, so no cycle), and an unknown protected category.
// A step naming an action this build does not know keeps the guide
// readable but not runnable: an older client may show the words, never
// guide through unknown semantics.

import 'dart:convert';

import '../../../core/trace/trace_logger.dart';
import '../domain/action_registry.dart';
import 'task_guide.dart';

enum GuideIssueCode {
  tooLarge,
  notJson,
  wrongFormat,
  unsupportedSchema,
  unknownKey,
  badValue,
  tooMany,
  tooLong,
  duplicateId,
  inconsistent,
  unknownAction,
}

class GuideIssue {
  const GuideIssue(this.code, this.path, {this.fatal = true});
  final GuideIssueCode code;
  final String path;
  final bool fatal;

  @override
  String toString() => '${code.name} at $path';
}

class GuideDecodeResult {
  const GuideDecodeResult(this.guide, this.issues);
  final TaskGuide? guide;
  final List<GuideIssue> issues;

  bool get accepted => guide != null;
  bool get runnable => accepted && issues.isEmpty;
}

Map<String, Object?> encodeGuide(TaskGuide g) => {
  'format': taskGuideFormat,
  'schema_version': taskGuideSchemaVersion,
  'action_contract_version': g.actionContractVersion,
  if (g.title != null) 'title': g.title,
  if (g.sourceDigest != null) 'source_digest': g.sourceDigest,
  'steps': [for (final s in g.steps) encodeGuideStep(s)],
};

Map<String, Object?> encodeGuideStep(GuideStep s) => {
  'id': s.id,
  'kind': s.kind.wire,
  if (s.action != null) 'action': s.action,
  if (s.expectedOutcomes.isNotEmpty)
    'expected_outcomes': (s.expectedOutcomes.toList()..sort()),
  if (s.text != null) 'text': s.text,
  if (s.optional) 'optional': true,
  if (s.manualCategory != null) 'manual_category': s.manualCategory!.wire,
  if (s.recovery.isNotEmpty)
    'recovery': [for (final r in s.recovery) encodeGuideStep(r)],
};

String encodeGuideText(TaskGuide g) =>
    const JsonEncoder.withIndent('  ').convert(encodeGuide(g));

final _id = RegExp(r'^g[1-9][0-9]{0,2}(r[1-9])?$');
final _digest = RegExp(r'^[0-9a-f]{64}$');
final _control = RegExp(r'[\u0000-\u0008\u000B-\u001F\u007F]');

GuideDecodeResult decodeGuideText(
  String text, {
  ActionRegistry registry = recorderRegistry,
  GuideLimits limits = const GuideLimits(),
}) {
  if (utf8.encode(text).length > limits.maxBytes) {
    return const GuideDecodeResult(null, [
      GuideIssue(GuideIssueCode.tooLarge, r'$'),
    ]);
  }
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException {
    return const GuideDecodeResult(null, [
      GuideIssue(GuideIssueCode.notJson, r'$'),
    ]);
  }
  return _GuideDecoder(registry, limits).root(json);
}

class _GuideDecoder {
  _GuideDecoder(this.registry, this.limits);
  final ActionRegistry registry;
  final GuideLimits limits;
  final issues = <GuideIssue>[];
  final ids = <String>{};

  GuideDecodeResult _refuse(GuideIssueCode code, String path) {
    issues.add(GuideIssue(code, path));
    return GuideDecodeResult(null, issues);
  }

  String? _text(Object? v, int max, String path) {
    if (v == null) return null;
    if (v is! String || _control.hasMatch(v)) {
      throw _Refusal(GuideIssueCode.badValue, path);
    }
    if (v.length > max) throw _Refusal(GuideIssueCode.tooLong, path);
    return v;
  }

  GuideDecodeResult root(Object? json) {
    if (json is! Map) return _refuse(GuideIssueCode.badValue, r'$');
    if (json['format'] != taskGuideFormat) {
      return _refuse(GuideIssueCode.wrongFormat, 'format');
    }
    final v = json['schema_version'];
    if (v is! int || v < 1 || v > taskGuideSchemaVersion) {
      return _refuse(GuideIssueCode.unsupportedSchema, 'schema_version');
    }
    const keys = {
      'format',
      'schema_version',
      'action_contract_version',
      'title',
      'source_digest',
      'steps',
    };
    if (!json.keys.every(keys.contains)) {
      return _refuse(GuideIssueCode.unknownKey, r'$');
    }
    try {
      final contract = json['action_contract_version'];
      if (contract is! int || contract < 1) {
        throw const _Refusal(
          GuideIssueCode.badValue,
          'action_contract_version',
        );
      }
      final digest = json['source_digest'];
      if (digest != null && (digest is! String || !_digest.hasMatch(digest))) {
        throw const _Refusal(GuideIssueCode.badValue, 'source_digest');
      }
      final title = _text(json['title'], limits.maxTitleLength, 'title');
      final raw = json['steps'];
      if (raw is! List) throw const _Refusal(GuideIssueCode.badValue, 'steps');
      if (raw.length > limits.maxSteps) {
        throw const _Refusal(GuideIssueCode.tooMany, 'steps');
      }
      final steps = [
        for (var i = 0; i < raw.length; i++)
          _step(raw[i], 'steps[$i]', inRecovery: false),
      ];
      return GuideDecodeResult(
        TaskGuide(
          actionContractVersion: contract,
          title: title,
          sourceDigest: digest as String?,
          steps: steps,
        ),
        issues,
      );
    } on _Refusal catch (r, st) {
      TraceLogger.instance.warn(
        'recorder',
        'guide refused: ${r.code.name}',
        stackTrace: st,
      );
      return _refuse(r.code, r.path);
    }
  }

  GuideStep _step(Object? raw, String path, {required bool inRecovery}) {
    if (raw is! Map) throw _Refusal(GuideIssueCode.badValue, path);
    const keys = {
      'id',
      'kind',
      'action',
      'expected_outcomes',
      'text',
      'optional',
      'manual_category',
      'recovery',
    };
    if (!raw.keys.every(keys.contains)) {
      throw _Refusal(GuideIssueCode.unknownKey, path);
    }
    final id = raw['id'];
    if (id is! String || !_id.hasMatch(id) || id.contains('r') != inRecovery) {
      throw _Refusal(GuideIssueCode.badValue, '$path.id');
    }
    if (!ids.add(id)) throw _Refusal(GuideIssueCode.duplicateId, '$path.id');
    final kind = GuideStepKind.fromWire(raw['kind']);
    if (kind == null) throw _Refusal(GuideIssueCode.badValue, '$path.kind');
    final text = _text(raw['text'], limits.maxTextLength, '$path.text');
    final optional = raw['optional'] ?? false;
    if (optional is! bool) {
      throw _Refusal(GuideIssueCode.badValue, '$path.optional');
    }

    final categoryRaw = raw['manual_category'];
    final category = ProtectedSurface.fromWire(categoryRaw);
    if (categoryRaw != null &&
        (category == null || kind != GuideStepKind.manual)) {
      throw _Refusal(GuideIssueCode.inconsistent, '$path.manual_category');
    }

    final actionRaw = raw['action'];
    final expectedRaw = raw['expected_outcomes'] ?? const <Object?>[];
    final recoveryRaw = raw['recovery'] ?? const <Object?>[];
    if (expectedRaw is! List || recoveryRaw is! List) {
      throw _Refusal(GuideIssueCode.badValue, path);
    }
    if (kind != GuideStepKind.perform) {
      if (actionRaw != null ||
          expectedRaw.isNotEmpty ||
          recoveryRaw.isNotEmpty) {
        throw _Refusal(GuideIssueCode.inconsistent, path);
      }
      return GuideStep(
        id: id,
        kind: kind,
        text: text,
        optional: optional,
        manualCategory: category,
      );
    }
    if (actionRaw is! String) {
      throw _Refusal(GuideIssueCode.badValue, '$path.action');
    }
    final spec = registry.action(actionRaw);
    if (spec == null) {
      // Readable, not runnable: the words stay, the semantics do not run.
      issues.add(
        GuideIssue(GuideIssueCode.unknownAction, '$path.action', fatal: false),
      );
      return GuideStep(id: id, kind: GuideStepKind.manual, text: text);
    }
    final expected = <String>{};
    for (final o in expectedRaw) {
      if (o is! String || !spec.outcomes.contains(o)) {
        throw _Refusal(GuideIssueCode.inconsistent, '$path.expected_outcomes');
      }
      expected.add(o);
    }
    if (spec.isCommand != expected.isNotEmpty) {
      throw _Refusal(GuideIssueCode.inconsistent, '$path.expected_outcomes');
    }
    if (recoveryRaw.isNotEmpty && (inRecovery || !spec.isCommand)) {
      throw _Refusal(GuideIssueCode.inconsistent, '$path.recovery');
    }
    if (recoveryRaw.length > limits.maxRecoverySteps) {
      throw _Refusal(GuideIssueCode.tooMany, '$path.recovery');
    }
    return GuideStep(
      id: id,
      kind: kind,
      action: spec.id,
      expectedOutcomes: expected,
      text: text,
      optional: optional,
      recovery: [
        for (var i = 0; i < recoveryRaw.length; i++)
          _step(recoveryRaw[i], '$path.recovery[$i]', inRecovery: true),
      ],
    );
  }
}

class _Refusal implements Exception {
  const _Refusal(this.code, this.path);
  final GuideIssueCode code;
  final String path;
}
