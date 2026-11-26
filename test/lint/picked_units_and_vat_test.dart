// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4471 -- a unit and a VAT rate are picked from the master data, never typed. A text input whose label names a unit or a VAT
// rate is refused, except in the editors OF that master data. The two stock inputs still typed (an item's extra unit name, a
// group's purchase unit) were the ceiling until picked; none is left, so the ceiling is empty and stays so.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// The labels that name a unit or a VAT rate as the thing typed (`purchaseOrderUnit`, `itemGroupPurchaseUnit`, `purchaseOrderVatRate`...).
final _labelKey = RegExp(r'(Unit|UnitName|VatRate|VatPercent)$');

/// The editors of the master data itself, and the handling-unit code and label (a code and a name are what is typed there).
const _editors = {
  'lib/features/stock/presentation/measure_unit_sheet.dart',
  'lib/features/stock/presentation/handling_unit_sheets.dart',
  'lib/features/money/presentation/widgets/vat_rate_editor.dart',
};

/// Typed today: none. Every unit and VAT rate input is picked (#4471).
const _stillTyped = <String>{};

final _input = RegExp(r'\b(AppTextField|TextField|TextFormField)\(');
final _label = RegExp(r'\blabel(?:Text)?:\s*(?:\w+\.)?(\w+)');

/// The `file#label` of every text input in [source] whose label names a unit or a VAT rate.
Set<String> typedUnitOrRate(String path, String source) {
  final found = <String>{};
  for (final m in _input.allMatches(source)) {
    var i = m.end;
    var depth = 1;
    while (i < source.length && depth > 0) {
      final c = source[i++];
      if (c == '(') depth++;
      if (c == ')') depth--;
    }
    final label = _label.firstMatch(source.substring(m.start, i))?.group(1);
    if (label != null && _labelKey.hasMatch(label)) found.add('$path#$label');
  }
  return found;
}

void main() {
  test('the guard reads a typed unit and a typed rate, not a picked one or an id', () {
    expect(typedUnitOrRate('a.dart', "AppTextField(controller: c, label: l10n.purchaseOrderUnit)"), {'a.dart#purchaseOrderUnit'});
    expect(typedUnitOrRate('a.dart', "TextField(decoration: InputDecoration(labelText: l.purchaseOrderVatRate))"), {'a.dart#purchaseOrderVatRate'});
    expect(typedUnitOrRate('a.dart', "AppTextField(label: l10n.legalIdentityVatId)"), isEmpty);
    expect(typedUnitOrRate('a.dart', "UnitPickerField(label: l10n.purchaseOrderUnit)"), isEmpty);
  });

  test('no new free unit or VAT rate text input; the ones still typed only fall', () {
    final typed = <String>{};
    for (final f in handWrittenDartFiles('lib')) {
      final path = f.path.replaceAll(r'\', '/');
      if (_editors.contains(path)) continue;
      typed.addAll(typedUnitOrRate(path, f.readAsStringSync()));
    }
    expect(typed.difference(_stillTyped), isEmpty, reason: 'a unit or a VAT rate is picked from the master data (UnitPickerField, VatPercentPicker, VatRateField)');
    expect(_stillTyped.difference(typed), isEmpty, reason: 'picked now: take it off _stillTyped, the ceiling only falls');
  });
}
