// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2142 — the task recorder's generic vocabulary, read from the source:
//
//   * every string KEY written as a literal in lib/ (`ValueKey('x')`,
//     `Key('x')`, or a kebab-case literal a helper turns into a key, like
//     `door('me-workspaces', …)`), and every interpolated key as a pattern with its
//     dynamic parts as `{}` (`'perm-${a}-${b}'` → `perm-{}-{}`): a tapped
//     control is named only by one of these, so a key that carries an id
//     or a typed value is recorded as its pattern, never as itself;
//   * every literal `message:` of a `runGuarded(...)` call: the name a
//     command is recorded under;
//   * every ARB message without placeholders: the words a control may be
//     labelled with, stored as the message KEY and shown back in the
//     reader's language;
//   * every route of the coverage manifest.
//
// A list that lags the source is safe: an unlisted key, message or label
// is recorded as a gap ("an unnamed control"), never as raw text.
// `dart run tool/recorder_vocabulary.dart` regenerates;
// `dart run tool/recorder_vocabulary.dart --report` also prints how many
// controls in lib/ have no key, per feature.
import 'dart:convert';
import 'dart:io';

const String vocabularyOutput =
    'lib/features/task_recorder/domain/ui_vocabulary.g.dart';
const String labelsOutput =
    'lib/features/task_recorder/presentation/ui_labels.g.dart';

final RegExp _keyCall = RegExp(
  r"""\b(?:ValueKey|Key)(?:<String>)?\(\s*'((?:[^'\\]|\\.)*)'\s*\)""",
);

/// A kebab-case string literal — the shape of a key handed to a helper
/// that builds the `ValueKey` (`door('me-workspaces', …)`), with or
/// without interpolation.
final RegExp _kebabLiteral = RegExp(
  r"'([a-z][a-z0-9]*-(?:[a-z0-9-]|\$\{[A-Za-z0-9_.()]*\}|\$[A-Za-z_][A-Za-z0-9_]*)+)'",
);

/// The source files the vocabulary is read from: hand-written lib/ Dart.
List<File> sourceFiles() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('.dart') &&
              !f.path.endsWith('.g.dart') &&
              !f.path.endsWith('.freezed.dart') &&
              !f.path.contains('lib/l10n/'),
        )
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

/// A key literal as the recorder may name it: itself when static, its
/// pattern when interpolated, null when nothing static is left to name.
String? keyName(String literal) {
  if (!literal.contains(r'$')) return literal;
  final pattern = literal
      .replaceAll(RegExp(r'\$\{[^}]*\}'), '{}')
      .replaceAll(RegExp(r'\$[A-Za-z_][A-Za-z0-9_]*'), '{}');
  final letters = pattern
      .replaceAll('{}', '')
      .replaceAll(RegExp('[^A-Za-z]'), '');
  return letters.length < 3 ? null : pattern;
}

/// The literal `message:` strings of every runGuarded call.
Set<String> guardedMessages(Iterable<String> sources) {
  final out = <String>{};
  for (final text in sources) {
    var from = 0;
    while (true) {
      final at = text.indexOf('runGuarded(', from);
      if (at < 0) break;
      from = at + 1;
      final call = _callText(text, at + 'runGuarded'.length);
      final m = RegExp(r'\bmessage:\s*').firstMatch(call);
      if (m == null) continue;
      final arg = _argument(call, m.end);
      for (final lit in RegExp(r"'((?:[^'\\$]|\\.)*)'").allMatches(arg)) {
        if (!arg.substring(lit.start, lit.end).contains(r'$')) {
          out.add(lit.group(1)!);
        }
      }
    }
  }
  return out;
}

String _callText(String text, int open) {
  var depth = 0;
  for (var i = open; i < text.length; i++) {
    final c = text[i];
    if (c == '(') depth++;
    if (c == ')') {
      depth--;
      if (depth == 0) return text.substring(open, i + 1);
    }
  }
  return text.substring(open);
}

String _argument(String call, int start) {
  var depth = 0;
  var quote = '';
  for (var i = start; i < call.length; i++) {
    final c = call[i];
    if (quote.isNotEmpty) {
      if (c == quote && call[i - 1] != r'\') quote = '';
      continue;
    }
    if (c == "'" || c == '"') {
      quote = c;
    } else if (c == '(' || c == '[' || c == '{') {
      depth++;
    } else if (c == ')' || c == ']' || c == '}') {
      if (depth == 0) return call.substring(start, i);
      depth--;
    } else if (c == ',' && depth == 0) {
      return call.substring(start, i);
    }
  }
  return call.substring(start);
}

/// The ARB messages a label may be: no placeholders, no ICU syntax.
List<String> labelKeys() {
  final arb = jsonDecode(
    File('lib/l10n/app_en.arb').readAsStringSync(),
  ) as Map<String, Object?>;
  final keys = <String>[];
  for (final e in arb.entries) {
    if (e.key.startsWith('@')) continue;
    final meta = arb['@${e.key}'];
    final placeholders = meta is Map ? meta['placeholders'] : null;
    final value = e.value;
    if (placeholders != null || value is! String || value.contains('{')) {
      continue;
    }
    keys.add(e.key);
  }
  return keys..sort();
}

/// The routes of the coverage manifest, in its order.
List<String> manifestRoutes() => [
  for (final m in RegExp(r"RouteCoverage\(\s*'([^']+)'").allMatches(
    File('lib/features/task_recorder/domain/coverage_manifest.dart')
        .readAsStringSync(),
  ))
    m.group(1)!,
];

({List<String> keys, List<String> patterns, List<String> messages})
vocabularyOfTree() {
  final texts = [for (final f in sourceFiles()) f.readAsStringSync()];
  final keys = <String>{};
  final patterns = <String>{};
  for (final text in texts) {
    for (final m in [
      ..._keyCall.allMatches(text),
      ..._kebabLiteral.allMatches(text),
    ]) {
      final name = keyName(m.group(1)!);
      if (name == null) continue;
      (name.contains('{}') ? patterns : keys).add(name);
    }
  }
  return (
    keys: keys.toList()..sort(),
    patterns: patterns.toList()..sort(),
    messages: guardedMessages(texts).toList()..sort(),
  );
}

String _literal(String s) =>
    "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$')}'";

String vocabularyText() {
  final v = vocabularyOfTree();
  final b = StringBuffer()
    ..writeln('// GENERATED by tool/recorder_vocabulary.dart — do not edit.')
    ..writeln('// coverage:ignore-file')
    ..writeln('// ignore_for_file: lines_longer_than_80_chars')
    ..writeln()
    ..writeln('/// Every string key written as a literal in lib/.')
    ..writeln('const Set<String> uiKeys = {');
  for (final k in v.keys) {
    b.writeln('  ${_literal(k)},');
  }
  b
    ..writeln('};')
    ..writeln()
    ..writeln('/// Every interpolated key, its dynamic parts as `{}`.')
    ..writeln('const List<String> uiKeyPatterns = [');
  for (final p in v.patterns) {
    b.writeln('  ${_literal(p)},');
  }
  b
    ..writeln('];')
    ..writeln()
    ..writeln('/// The literal messages of every runGuarded call.')
    ..writeln('const Set<String> uiCommandMessages = {');
  for (final m in v.messages) {
    b.writeln('  ${_literal(m)},');
  }
  b
    ..writeln('};')
    ..writeln()
    ..writeln('/// The routes of the coverage manifest.')
    ..writeln('const Set<String> uiRoutes = {');
  for (final r in manifestRoutes()) {
    b.writeln('  ${_literal(r)},');
  }
  b
    ..writeln('};')
    ..writeln()
    ..writeln('/// The ARB messages a control may be labelled with.')
    ..writeln('const Set<String> uiLabelKeys = {');
  for (final k in labelKeys()) {
    b.writeln('  ${_literal(k)},');
  }
  b.writeln('};');
  return b.toString();
}

String labelsText() {
  final keys = labelKeys();
  const chunk = 400;
  final parts = (keys.length / chunk).ceil();
  final b = StringBuffer()
    ..writeln('// GENERATED by tool/recorder_vocabulary.dart — do not edit.')
    ..writeln('// coverage:ignore-file')
    ..writeln()
    ..writeln("import '../../../l10n/app_localizations.dart';")
    ..writeln()
    ..writeln('/// The words of ARB message [key] in [l]\'s language, or null.')
    ..writeln('String? uiLabel(AppLocalizations l, String key) =>')
    ..writeln('    _getters[key]?.call(l);')
    ..writeln()
    ..writeln('typedef _Getter = String Function(AppLocalizations l);')
    ..writeln()
    // Built once, from small parts: one function per few hundred keys, so
    // no single function is large enough to trouble an optimizing
    // compiler (a switch over every key once overflowed its stack).
    ..writeln('final Map<String, _Getter> _getters = {');
  for (var i = 0; i < parts; i++) {
    b.writeln('  ..._part$i(),');
  }
  b.writeln('};');
  for (var i = 0; i < parts; i++) {
    b
      ..writeln()
      ..writeln('Map<String, _Getter> _part$i() => {');
    for (final k in keys.skip(i * chunk).take(chunk)) {
      b.writeln('  ${_literal(k)}: (l) => l.$k,');
    }
    b.writeln('};');
  }
  return b.toString();
}

/// Interactive callbacks in lib/ whose widget call carries no `key:`,
/// per feature: the generic recorder can only name them as gaps.
Map<String, int> unkeyedByFeature() {
  final out = <String, int>{};
  final callback = RegExp(
    r'\b(onPressed|onTap|onChanged|onSelected|onSubmitted):\s*(?!null\b)',
  );
  for (final f in sourceFiles()) {
    if (!f.path.contains('/presentation/')) continue;
    final text = f.readAsStringSync();
    for (final m in callback.allMatches(text)) {
      if (_callHasKey(text, m.start)) continue;
      final parts = f.path.split('/');
      final at = parts.indexOf('features');
      final feature = at >= 0 && at + 1 < parts.length
          ? parts[at + 1]
          : parts.length > 1
          ? parts[1]
          : f.path;
      out[feature] = (out[feature] ?? 0) + 1;
    }
  }
  return out;
}

/// Whether the constructor call around [at] names a `key:`.
bool _callHasKey(String text, int at) {
  var depth = 0;
  for (var i = at; i >= 0; i--) {
    final c = text[i];
    if (c == ')' || c == ']' || c == '}') depth++;
    if (c == '(' || c == '[' || c == '{') {
      if (depth == 0) {
        final call = _callText(text, i);
        return RegExp(r'(^|[\s(,])key:\s').hasMatch(_topLevel(call));
      }
      depth--;
    }
  }
  return false;
}

/// [call] with every nested bracket's contents removed.
String _topLevel(String call) {
  final b = StringBuffer();
  var depth = 0;
  for (var i = 0; i < call.length; i++) {
    final c = call[i];
    if (c == '(' || c == '[' || c == '{') {
      depth++;
      if (depth == 1) b.write(c);
      continue;
    }
    if (c == ')' || c == ']' || c == '}') {
      depth--;
      if (depth == 0) b.write(c);
      continue;
    }
    if (depth == 1) b.write(c);
  }
  return b.toString();
}

void main(List<String> args) {
  File(vocabularyOutput).writeAsStringSync(vocabularyText());
  File(labelsOutput).writeAsStringSync(labelsText());
  if (args.contains('--report')) {
    final unkeyed = unkeyedByFeature();
    final total = unkeyed.values.fold(0, (a, b) => a + b);
    stdout.writeln('Controls without a key (named as gaps): $total');
    for (final e
        in unkeyed.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value))) {
      stdout.writeln('  ${e.key}: ${e.value}');
    }
  }
}
