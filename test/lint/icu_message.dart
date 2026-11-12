// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3743 -- one parser of an ICU message for the plural lint and the ICU test:
// nested braces and several plurals in one message are read as a tree, not
// searched by substring.

/// A node of a parsed message.
sealed class IcuNode {
  const IcuNode();
}

/// Literal text.
class IcuText extends IcuNode {
  const IcuText(this.text);
  final String text;
}

/// A plain `{name}` argument.
class IcuArg extends IcuNode {
  const IcuArg(this.name);
  final String name;
}

/// A `{name, plural|select|selectordinal, case{…} …}` construct.
class IcuChoice extends IcuNode {
  const IcuChoice(this.name, this.kind, this.cases);
  final String name;
  final String kind;

  /// The cases in written order: selector (`one`, `=0`, `other`) and body.
  final List<(String, List<IcuNode>)> cases;
}

final _choiceHead = RegExp(
  r'^\s*(\w+)\s*,\s*(plural|select|selectordinal)\s*,',
);
final _caseHead = RegExp(r'\s*(=?\w+)\s*\{');

int _closing(String s, int open) {
  var depth = 0;
  for (var i = open; i < s.length; i++) {
    if (s[i] == '{') depth++;
    if (s[i] == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return s.length - 1;
}

/// Parses [text] into nodes.
List<IcuNode> parseIcu(String text) {
  final out = <IcuNode>[];
  var literal = StringBuffer();
  void flush() {
    if (literal.isNotEmpty) out.add(IcuText(literal.toString()));
    literal = StringBuffer();
  }

  var i = 0;
  while (i < text.length) {
    if (text[i] != '{') {
      literal.write(text[i]);
      i++;
      continue;
    }
    final end = _closing(text, i);
    final inner = text.substring(i + 1, end);
    final head = _choiceHead.firstMatch(inner);
    flush();
    if (head == null) {
      out.add(IcuArg(inner.trim()));
    } else {
      final rest = inner.substring(head.end);
      final cases = <(String, List<IcuNode>)>[];
      var q = 0;
      while (q < rest.length) {
        final m = _caseHead.matchAsPrefix(rest, q);
        if (m == null) {
          q++;
          continue;
        }
        final open = m.end - 1;
        final close = _closing(rest, open);
        cases.add((m.group(1)!, parseIcu(rest.substring(open + 1, close))));
        q = close + 1;
      }
      out.add(IcuChoice(head.group(1)!, head.group(2)!, cases));
    }
    i = end + 1;
  }
  flush();
  return out;
}

/// Every choice of [nodes], nested ones included.
Iterable<IcuChoice> choicesOf(List<IcuNode> nodes) sync* {
  for (final n in nodes) {
    if (n is IcuChoice) {
      yield n;
      for (final c in n.cases) {
        yield* choicesOf(c.$2);
      }
    }
  }
}

/// The names of the arguments used bare: `{name}` outside a plural of
/// `name` itself (inside one, `{name}` is the number written in the form).
Set<String> bareArgs(List<IcuNode> nodes, {Set<String> inside = const {}}) {
  final out = <String>{};
  for (final n in nodes) {
    switch (n) {
      case IcuText():
        break;
      case IcuArg(:final name):
        if (!inside.contains(name)) out.add(name);
      case IcuChoice(:final name, :final kind, :final cases):
        final next = kind == 'plural' ? {...inside, name} : inside;
        for (final c in cases) {
          out.addAll(bareArgs(c.$2, inside: next));
        }
    }
  }
  return out;
}

/// The names of the plural arguments of [nodes], nested ones included.
Set<String> pluralArgs(List<IcuNode> nodes) => {
  for (final c in choicesOf(nodes))
    if (c.kind == 'plural') c.name,
};

/// Every argument name of [nodes] (plain, plural and select), nested included.
Set<String> allArgs(List<IcuNode> nodes) {
  final out = <String>{};
  for (final n in nodes) {
    switch (n) {
      case IcuText():
        break;
      case IcuArg(:final name):
        out.add(name);
      case IcuChoice(:final name, :final cases):
        out.add(name);
        for (final c in cases) {
          out.addAll(allArgs(c.$2));
        }
    }
  }
  return out;
}

/// Languages whose `one` category also covers 0 (CLDR): a form written for
/// exactly one there needs `=0` or the number in it.
const oneCoversZero = {'fr'};

/// The plural selectors a language's messages may use: its own categories and
/// `=0` for a deliberately different sentence. `=1` is never used.
const allowedPluralSelectors = {'one', 'other', '=0'};
