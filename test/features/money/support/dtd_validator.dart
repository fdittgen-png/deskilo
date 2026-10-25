// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A validator for the element structure a DTD declares: every element of a
// document must be declared, its children must match the declared content
// model (sequence, choice, ?, *, +), an EMPTY element holds nothing and a
// #PCDATA element holds text only. Attributes and entities are not checked:
// the GDPdU DTD declares none. Each content model becomes a regular
// expression over the children's names, which is exactly what a content
// model is.
import 'package:xml/xml.dart';

/// The ways [document] breaks [dtd]; empty when it is valid.
List<String> dtdViolations(String dtd, String document) {
  final declarations = <String, String>{
    for (final m in RegExp(
      r'<!ELEMENT\s+(\w+)\s+([^>]+)>',
    ).allMatches(dtd.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')))
      m.group(1)!: m.group(2)!.trim(),
  };
  final doc = XmlDocument.parse(document);
  final doctype = doc.doctypeElement?.name;
  final out = <String>[];
  final root = doc.rootElement;
  if (doctype != null && doctype != root.name.local) {
    out.add('DOCTYPE $doctype, root ${root.name.local}');
  }
  void visit(XmlElement e, String path) {
    final name = e.name.local;
    final here = '$path/$name';
    final model = declarations[name];
    if (model == null) {
      out.add('$here is not declared');
      return;
    }
    final children = e.childElements.toList();
    final text = e.children
        .whereType<XmlText>()
        .map((t) => t.value)
        .join()
        .trim();
    if (model == 'EMPTY') {
      if (children.isNotEmpty || text.isNotEmpty) out.add('$here is not empty');
    } else if (model == '(#PCDATA)') {
      if (children.isNotEmpty) out.add('$here holds elements');
    } else {
      if (text.isNotEmpty) out.add('$here holds text');
      final names = children.map((c) => '<${c.name.local}>').join();
      if (!RegExp('^${_pattern(model)}\$').hasMatch(names)) {
        out.add(
          '$here: ${children.map((c) => c.name.local).join(', ')} '
          'does not match $model',
        );
      }
    }
    for (final c in children) {
      visit(c, here);
    }
  }

  visit(root, '');
  return out;
}

/// The content model [model] as a regular expression over `<name>` tokens.
String _pattern(String model) {
  final b = StringBuffer();
  for (final m in RegExp(
    r'(\w+)|([(),|?*+])',
  ).allMatches(model.replaceAll(RegExp(r'\s+'), ''))) {
    final word = m.group(1);
    if (word != null) {
      b.write('(?:<$word>)');
      continue;
    }
    switch (m.group(2)) {
      case '(':
        b.write('(?:');
      case ')':
        b.write(')');
      case ',':
        break;
      case final op?:
        b.write(op);
    }
  }
  return b.toString();
}
