// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3652, #3744 — the scan behind `sentence_one_message_test.dart`: a Dart
// string EXPRESSION that puts a translated read (`l10n.x`, `strings.x`, or a
// local that holds one) beside another value. Word order, spacing before
// punctuation and agreement cannot be right in five languages when a sentence
// is built from pieces; the sentence is ONE ARB message with placeholders.
//
// The source is parsed with the analyzer, so a join is classified by its
// expression, not by its line: adjacent literals, an interpolation and a
// `+` chain are one sequence of text and values.
import 'dart:convert';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'lint_sources.dart';

/// A translated read: `l10n.key`, `l10n?.key`, `strings.key`,
/// `context.l10n.key`. `localeName` is the name of the language, not a
/// message: reading it beside a value builds no sentence.
final RegExp _read = RegExp(
  r'\b(?:l10n|strings|labels)\??\.(?!localeName\b)\w+',
);

/// A control tag of the report engine (Liquid): the tags a template uses to
/// CHOOSE between messages — `if`, `elsif`, `else`, `endif`, the loop pair,
/// `unless` and `case`. Text that merely contains `{%` is not a control tag.
final RegExp _controlTag = RegExp(
  r'\{%-?\s*(?:if|elsif|else|endif|for|endfor|unless|endunless|case|when|'
  r'endcase)\b[^%{}]*-?%\}',
);

/// The shared messages whose text puts nothing but a space between its
/// placeholders (`{first} {second}`): a join in another form. A call to one
/// with a translated piece as an argument hides the join from the string
/// scan, so it IS a join. Read from the English ARB fragments, so a new
/// pattern of the same shape is covered without an edit here.
final Set<String> _spaceOnlyPatterns = () {
  final out = <String>{};
  final placeholder = RegExp(r'\{\w+\}');
  for (final f in filesWithExtension('lib/l10n/_fragments', '_en.arb')) {
    final json = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    for (final MapEntry(:key, :value) in json.entries) {
      if (key.startsWith('@') || value is! String) continue;
      final meta = json['@$key'];
      final description = meta is Map ? '${meta['description']}' : '';
      // A message whose first placeholder is the workspace's own word (a
      // renamed term) is a value beside a value, not a sentence in pieces.
      if (description.contains('[workspace term:')) continue;
      if (placeholder.allMatches(value).length >= 2 &&
          value.replaceAll(placeholder, '').trim().isEmpty) {
        out.add(key);
      }
    }
  }
  return out;
}();

/// One piece of a string expression: literal text, or a value (then [expr]
/// is set and [text] is its source).
typedef _Part = ({String text, Expression? expr});

const _independentSeparators = {' · ', ' | ', '\n'};

/// What may stand between two values without the string being a sentence
/// built from pieces: the join of independent facts (` · `), the cells of a
/// table row (` | `), independent lines (a newline), and the control tags of
/// a report template, which CHOOSE one message.
bool isIndependentJoin(String between) {
  if (_independentSeparators.contains(between)) return true;
  return _controlTag.hasMatch(between);
}

bool _isPlus(Expression e) =>
    e is BinaryExpression && e.operator.type == TokenType.PLUS;

bool _isStringy(Expression e) =>
    e is StringLiteral ||
    (e is ParenthesizedExpression && _isStringy(e.expression)) ||
    (e is BinaryExpression &&
        _isPlus(e) &&
        (_isStringy(e.leftOperand) || _isStringy(e.rightOperand)));

void _flatten(Expression e, List<_Part> out) {
  if (e is ParenthesizedExpression && _isStringy(e.expression)) {
    _flatten(e.expression, out);
  } else if (e is AdjacentStrings) {
    for (final s in e.strings) {
      _flatten(s, out);
    }
  } else if (e is SimpleStringLiteral) {
    out.add((text: e.value, expr: null));
  } else if (e is StringInterpolation) {
    for (final el in e.elements) {
      if (el is InterpolationString) {
        out.add((text: el.value, expr: null));
      } else if (el is InterpolationExpression) {
        out.add((text: el.expression.toSource(), expr: el.expression));
      }
    }
  } else if (e is BinaryExpression && _isStringy(e)) {
    _flatten(e.leftOperand, out);
    _flatten(e.rightOperand, out);
  } else {
    out.add((text: e.toSource(), expr: e));
  }
}

/// The names bound, in the function around [node], to a translated read.
Set<String> _translatedLocals(AstNode node) {
  final body = node.thisOrAncestorOfType<FunctionBody>();
  if (body == null) return const {};
  final finder = _LocalFinder();
  body.accept(finder);
  return finder.names;
}

class _LocalFinder extends RecursiveAstVisitor<void> {
  final names = <String>{};

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final init = node.initializer;
    if (init != null && _read.hasMatch(init.toSource())) {
      names.add(node.name.lexeme);
    }
    super.visitVariableDeclaration(node);
  }
}

/// True when [node] is one piece of a larger string expression, which is
/// judged as a whole from its outermost node.
bool _isPartOfLarger(AstNode node) {
  final p = node.parent;
  return p is AdjacentStrings ||
      (p is ParenthesizedExpression && _isStringy(p) && _isPartOfLarger(p)) ||
      (p is BinaryExpression && _isStringy(p));
}

class _JoinFinder extends RecursiveAstVisitor<void> {
  _JoinFinder(this.lineInfo, this.spaceOnly);

  final LineInfo lineInfo;
  final Set<String> spaceOnly;
  final out = <String>[];

  void _check(Expression node) {
    if (_isPartOfLarger(node)) return;
    final parts = <_Part>[];
    _flatten(node, parts);
    final values = [
      for (var i = 0; i < parts.length; i++)
        if (parts[i].expr != null) i,
    ];
    if (values.length < 2) return;
    final locals = _translatedLocals(node);
    bool translated(_Part p) =>
        _read.hasMatch(p.text) ||
        (p.expr is SimpleIdentifier && locals.contains(p.text));
    if (!values.any((i) => translated(parts[i]))) return;
    for (var k = 1; k < values.length; k++) {
      final between = parts
          .sublist(values[k - 1] + 1, values[k])
          .map((p) => p.text)
          .join();
      if (!isIndependentJoin(between)) {
        final src = node.toSource().replaceAll('\n', ' ');
        final line = lineInfo.getLocation(node.offset).lineNumber;
        out.add('$line: ${src.length > 90 ? src.substring(0, 90) : src}');
        return;
      }
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (spaceOnly.contains(node.methodName.name)) {
      final locals = _translatedLocals(node);
      final translated = node.argumentList.arguments.any((a) {
        final src = a.toSource();
        return _read.hasMatch(src) ||
            (a is SimpleIdentifier && locals.contains(src));
      });
      if (translated) {
        final src = node.toSource().replaceAll('\n', ' ');
        final line = lineInfo.getLocation(node.offset).lineNumber;
        out.add('$line: ${src.length > 90 ? src.substring(0, 90) : src}');
      }
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    _check(node);
    super.visitStringInterpolation(node);
  }

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    _check(node);
    super.visitAdjacentStrings(node);
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    if (_isStringy(node)) _check(node);
    super.visitBinaryExpression(node);
  }
}

/// The places of [source] holding a joined sentence, as `line: text`.
/// [spaceOnly] names the shared messages that put only a space between their
/// placeholders; it defaults to the ones the English fragments hold (none,
/// since #3767 removed the last), a test passes its own to plant one.
List<String> sentenceJoins(String source, {Set<String>? spaceOnly}) {
  final result = parseString(content: source, throwIfDiagnostics: false);
  final finder = _JoinFinder(result.lineInfo, spaceOnly ?? _spaceOnlyPatterns);
  result.unit.accept(finder);
  return finder.out;
}
