// SPDX-License-Identifier: 0BSD
//
// #1365 — every user-facing literal the app could show, found by reading
// the source the way the rule is written.
//
// `no_hardcoded_strings_test` pins ONE shape: `Text('literal')` on one
// line. The audit this issue asks for is wider: a label, a hint, a
// tooltip, a semantic label, a snack, a dialog title, a chip — anywhere
// a string reaches a member's eyes. This finds those positions and
// reports what is NOT going through `AppLocalizations`.
//
// The repository's idiom is `l10n?.someKey ?? 'English fallback'`: the
// fallback literal is correct and stays. So a literal counts only when
// nothing hands it a localized value first.
import 'dart:io';

/// Where a string becomes something a member reads.
const Map<String, String> uiPositions = {
  'label': 'label',
  'labelText': 'field label',
  'hintText': 'field hint',
  'helperText': 'field helper',
  'errorText': 'field error',
  'counterText': 'field counter',
  'prefixText': 'field prefix',
  'suffixText': 'field suffix',
  'tooltip': 'tooltip',
  'semanticLabel': 'accessibility label',
  'semanticsLabel': 'accessibility label',
  'title': 'title',
  'subtitle': 'subtitle',
  'confirmDismissLabel': 'dismiss label',
};

/// Widgets and calls whose next positional argument is displayed text.
/// `AppSnack.x(context, …)` takes the context first, so the literal it
/// shows is matched through its own shape below.
const List<String> textWidgets = ['Text', 'SelectableText', 'TextSpan'];

/// Positions written as a call rather than a named argument: a tooltip's
/// `message:` (the bare name is a trace message elsewhere) and the four
/// snack helpers, which are how the app talks back after an action.
final _callPositions = <RegExp, String>{
  RegExp(r'Tooltip\(\s*message:\s*'): 'tooltip',
  RegExp(r'AppSnack\.\w+\(\s*context,\s*'): 'snack',
  RegExp(r'SemanticsProperties\(\s*label:\s*'): 'accessibility label',
};

/// An interpolation that already carries a localized value: the literal
/// around it is punctuation and spacing, not wording.
final _localizedInterpolation = RegExp(r'\$\{?\w*([lL]10n|strings)\b');

/// A literal made only of interpolations, punctuation and short tokens:
/// the words come from what is interpolated, so there is nothing here to
/// translate. `'$stateLabel · $count'` is the shape.
bool _onlyInterpolations(String literal) {
  final withoutSlots = literal.replaceAll(RegExp(r'\$\{[^}]*\}|\$\w+'), '');
  return !RegExp(r'[A-Za-zÀ-ÿ]{3}').hasMatch(withoutSlots);
}

/// The report designer's placeholder syntax (`{{ member }}`): a template
/// token the engine substitutes, never prose.
final _placeholderOnly = RegExp(r'^[\s{}|\w.—-]*\{\{[^}]*\}\}[\s{}|\w.—-]*$');

/// A colour written as its own code (`#EBDCC9`): the example beside a
/// colour field, and a thing no language spells differently.
final _colourCode = RegExp(r'^#[0-9A-Fa-f]{3,8}$');

/// A literal that is a key, a path, a wire value or a format — never
/// prose. Judged on the literal alone, so the rule can be read.
final _technical = RegExp(
  r'''^([a-z][A-Za-z0-9_]*|[A-Za-z0-9_.:/\\-]*[/.][A-Za-z0-9_.:/\\-]*|[#$%(),:;|+*=<>\[\]{}\s.\-_/\\]*|[A-Z_]+|\d[\d\s.,:-]*)$''',
);

/// The positions a string may sit in and never be shown: keys, wire
/// values, log and trace text, asset names.
final _neverShown = RegExp(
  r'''(Key\(|ValueKey|Semantics\(\s*identifier|debugPrint|TraceLogger|'''
  r'''\.log\(|package:|assets/|http|mailto:|'''
  r'''RegExp\(|DateFormat\(|NumberFormat\(|\.parse\(|jsonDecode|'''
  r'''\.rpc\(|\.from\(|\.select\(|\.eq\(|\.order\(|\btest\(|expect\()''',
);

/// Why a file's literals are not going through `AppLocalizations`.
///
/// Each entry is a decision, not an amnesty: the reason says what would
/// break if the words were translated, and the count is a ratchet — a
/// new literal in one of these files fails the lint until somebody
/// writes down why it belongs to the same class.
const Map<String, ({int allowed, String reason})> classifiedLiterals = {
  'lib/features/money/domain/vat_catalogue.dart': (
    allowed: 86,
    reason: 'statutory VAT rate names, each in the language its own tax '
        'authority uses (Normalsatz, Standaard, Snižena…). Translating '
        '«Ermäßigt 10 %» into French would name an Austrian rate in a '
        'language no Austrian form uses.',
  ),
  'lib/features/money/domain/coa_preview.dart': (
    allowed: 45,
    reason: 'the French chart of accounts (PCG): «Clients», «TVA '
        'collectée» are the legal names of the accounts a bookkeeper '
        'reads. A translated account name is the wrong account.',
  ),
  'lib/features/money/domain/vat_declaration.dart': (
    allowed: 10,
    reason: 'CA3 and UStVA box names, in French and German, as the forms '
        'print them.',
  ),
  'lib/core/instance/instance_builder.dart': (
    allowed: 13,
    reason: 'cloud region names as the provider spells them — a place '
        'name plus the identifier the console shows.',
  ),
  'lib/features/money/presentation/widgets/report_texts_panel.dart': (
    allowed: 1,
    reason: 'the field label IS the placeholder the owner types into a '
        'layout (`text.<their key>`); translating the token would stop '
        'it matching.',
  ),
};

class Finding {
  Finding({
    required this.path,
    required this.line,
    required this.position,
    required this.literal,
  });

  final String path;
  final int line;
  final String position;
  final String literal;

  /// Where in the app it lives: `features/money`, `core/instance`, …
  String get surface => path.split('/').skip(1).take(2).join('/');
}

/// The literal in [line] at [start] (the opening quote), or null when it
/// is not a simple single-line literal.
String? _literalAt(String line, int start) {
  final quote = line[start];
  final buffer = StringBuffer();
  for (var i = start + 1; i < line.length; i++) {
    final c = line[i];
    if (c == r'\') {
      i++;
      continue;
    }
    if (c == quote) return buffer.toString();
    buffer.write(c);
  }
  return null;
}

/// True when the literal at [index] is the fallback of a `??`, on this
/// line or continued from the previous one.
bool _isFallback(String line, int index, String? previous) {
  final before = line.substring(0, index).trimRight();
  if (before.endsWith('??')) return true;
  if (before.isEmpty && (previous?.trimRight().endsWith('??') ?? false)) {
    return true;
  }
  return false;
}

/// Every finding in [source], which is [path]'s content.
List<Finding> auditSource(String path, String source) {
  final out = <Finding>[];
  final lines = source.split('\n');
  final positions = RegExp(
    '(${uiPositions.keys.join('|')}):\\s*|'
    '(${textWidgets.join('|')})\\(\\s*',
  );
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('//')) continue;
    if (line.contains('l10n-exempt')) continue;
    if (_neverShown.hasMatch(line)) continue;
    for (final m in [
      ...positions.allMatches(line).map((m) => (m, uiPositions[m.group(1)] ?? 'displayed text')),
      for (final e in _callPositions.entries)
        ...e.key.allMatches(line).map((m) => (m, e.value)),
    ]) {
      final match = m.$1;
      final position = m.$2;
      final at = match.end;
      if (at >= line.length) continue;
      if (line[at] != "'" && line[at] != '"') continue;
      if (_isFallback(line, at, i == 0 ? null : lines[i - 1])) continue;
      final literal = _literalAt(line, at);
      if (literal == null || literal.trim().isEmpty) continue;
      if (_technical.hasMatch(literal)) continue;
      if (_colourCode.hasMatch(literal)) continue;
      if (_localizedInterpolation.hasMatch(literal)) continue;
      if (_placeholderOnly.hasMatch(literal)) continue;
      if (_onlyInterpolations(literal)) continue;
      out.add(Finding(
        path: path,
        line: i + 1,
        position: position,
        literal: literal,
      ));
    }
  }
  return out;
}

/// Every finding under [roots], sorted by path then line.
List<Finding> auditTree(List<String> roots) {
  final out = <Finding>[];
  for (final root in roots) {
    final files = Directory(root)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) =>
            !f.path.endsWith('.g.dart') &&
            !f.path.endsWith('.freezed.dart') &&
            !f.path.contains('lib/l10n/'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      out.addAll(auditSource(file.path, file.readAsStringSync()));
    }
  }
  return out;
}
