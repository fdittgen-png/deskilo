// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3782 — the static net under the measured form guard
// (test/ux/form_layout_test.dart): in a list of children, two fields next to
// each other with nothing between them (no FormGap, no SizedBox) in a Column
// or Row that sets no `spacing:` stand on each other's border. The count
// over lib/ only falls; a form measured by the guard leaves it by getting
// its gaps. A field is a widget whose name ends in Field or Fields
// (AppTextField, DropdownButtonFormField, PurchasePlaceField, …).
//
// Known limits of this count (the measured guard is the real net):
// * any `spacing:` counts as a gap, `spacing: 0` too;
// * two fields with only an `if` element between them, or a field wrapped
//   in Expanded or Padding, are not seen as neighbours.
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// The pairs of fields without a gap when #3782 landed.
const _budget = 43;

final _field = RegExp(r'(Field|Fields)$');

String? _nameOf(Expression e) => switch (e) {
  InstanceCreationExpression(:final constructorName) =>
    constructorName.type.name.lexeme,
  MethodInvocation(:final methodName, target: null) => methodName.name,
  _ => null,
};

bool _isField(CollectionElement e) =>
    e is Expression && _field.hasMatch(_nameOf(e) ?? '');

class _Pairs extends RecursiveAstVisitor<void> {
  final found = <String>[];
  final String file;
  _Pairs(this.file);

  @override
  void visitNamedArgument(NamedArgument node) {
    // ignore: experimental_member_use
    final list = node.argumentExpression2;
    if (node.name.lexeme == 'children' && list is ListLiteral) {
      final owner = node.parent;
      final spaced = owner is ArgumentList &&
          owner.arguments.any(
            (a) => a is NamedArgument && a.name.lexeme == 'spacing',
          );
      if (!spaced) {
        final items = list.elements;
        for (var i = 0; i + 1 < items.length; i++) {
          if (_isField(items[i]) && _isField(items[i + 1])) {
            found.add('$file: ${_nameOf(items[i] as Expression)} → '
                '${_nameOf(items[i + 1] as Expression)}');
          }
        }
      }
    }
    super.visitNamedArgument(node);
  }
}

/// The fields without a gap in [source] (named [file]).
List<String> fieldsWithoutGap(String file, String source) {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;
  final v = _Pairs(file);
  unit.accept(v);
  return v.found;
}

void main() {
  test('a planted form with two fields next to each other is counted; a '
      'gap or a spacing between them is not', () {
    const planted = '''
Widget f() => Column(children: [
  AppTextField(label: 'a'),
  DropdownButtonFormField<String>(items: []),
]);
''';
    const gapped = '''
Widget f() => Column(children: [
  AppTextField(label: 'a'),
  const FormGap(),
  AppTextField(label: 'b'),
]);
Widget g() => Column(spacing: 12, children: [
  AppTextField(label: 'a'),
  AppTextField(label: 'b'),
]);
''';
    expect(fieldsWithoutGap('a.dart', planted), hasLength(1));
    expect(fieldsWithoutGap('b.dart', gapped), isEmpty);
  });

  test('the fields without a gap in lib/ only fall', () {
    final found = [
      for (final f in handWrittenDartFiles('lib'))
        ...fieldsWithoutGap(
          f.path.replaceAll(r'\', '/'),
          f.readAsStringSync(),
        ),
    ];
    expect(
      found.length,
      lessThanOrEqualTo(_budget),
      reason: 'put the form kit\'s gap between the fields:\n${found.join('\n')}',
    );
    if (found.length < _budget) {
      fail('lower _budget in test/lint/form_gap_test.dart to ${found.length}');
    }
  });
}
