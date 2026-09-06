// SPDX-License-Identifier: 0BSD
//
// #916 — the <configuration> section: a typed, name-sorted tree that
// survives XML unchanged, so export → import → export is byte-identical.
import 'package:deskilo/features/workspace/domain/workspace_xml.dart';
import 'package:deskilo/features/workspace/domain/workspace_xml_configuration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// A tree shaped like export_workspace_configuration's answer, with the
/// values that break naive codecs: a multi-line template, a string with
/// surrounding spaces, an empty string, a null, nested objects and
/// arrays, an integral double from a numeric column.
final Map<String, Object?> _tree = {
  'workspace': {
    'address': '4 rue Silène, 34120 Pézenas',
    'invitation_template': 'Bonjour {name},\n\n  Bienvenue !\n',
    'vat_account': '  padded  ',
    'street': '',
    'subscription_vat_rate': null,
    'desk_opacity': 100,
    'booking_rules': {
      'granularity': 'half_day',
      'open_weekdays': [1, 2, 3, 4, 5],
      'max_series_days': 180,
    },
    'invoice_legal': {'reverse_charge': true, 'special_mentions': 'a & b <c>'},
  },
  'tables': {
    'vat_rates': [
      {'label': 'Standard 20 %', 'percent': 20.0, 'is_default': true},
      {'label': 'Réduit 5,5 %', 'percent': 5.5, 'is_default': false},
    ],
    'fee_bands': <Object?>[],
  },
};

String _xmlOf(Map<String, Object?> tree) {
  final builder = XmlBuilder();
  writeConfigurationXml(builder, tree);
  return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
}

Map<String, Object?> _treeOf(String xml) =>
    parseConfigurationXml(XmlDocument.parse(xml).rootElement);

void main() {
  test('every value comes back with its type and its exact text', () {
    final back = _treeOf(_xmlOf(_tree));
    final workspace = back['workspace'] as Map;
    expect(workspace['invitation_template'],
        'Bonjour {name},\n\n  Bienvenue !\n');
    expect(workspace['vat_account'], '  padded  ');
    expect(workspace['street'], '');
    expect(workspace['subscription_vat_rate'], isNull);
    expect(workspace['desk_opacity'], 100);
    expect((workspace['booking_rules'] as Map)['open_weekdays'],
        [1, 2, 3, 4, 5]);
    expect((workspace['invoice_legal'] as Map)['reverse_charge'], true);
    expect((workspace['invoice_legal'] as Map)['special_mentions'], 'a & b <c>');
    final rates = (back['tables'] as Map)['vat_rates'] as List;
    expect((rates[0] as Map)['percent'], 20,
        reason: 'an integral numeric prints and reads as an integer');
    expect((rates[1] as Map)['percent'], 5.5);
    expect((back['tables'] as Map)['fee_bands'], isEmpty);
  });

  test('export → import → export is byte-identical', () {
    final once = _xmlOf(_tree);
    final twice = _xmlOf(_treeOf(once));
    expect(twice, once);
  });

  test('object members are sorted, so key order never changes the bytes',
      () {
    final a = _xmlOf({'b': 1, 'a': 2});
    final b = _xmlOf({'a': 2, 'b': 1});
    expect(a, b);
    expect(a.indexOf('name="a"'), lessThan(a.indexOf('name="b"')));
  });

  test('numbers have one spelling', () {
    expect(canonicalConfigurationNumber(20.0), '20');
    expect(canonicalConfigurationNumber(20), '20');
    expect(canonicalConfigurationNumber(5.5), '5.5');
    expect(canonicalConfigurationNumber(-3.0), '-3');
  });

  test('a field without a type, a bad boolean, a bad number and a '
      'duplicate name are typed rejections', () {
    Object? parse(String body) => _treeOf('<configuration>$body</configuration>');
    expect(() => parse('<field name="x">1</field>'),
        throwsA(isA<WorkspaceXmlException>().having(
            (e) => e.error, 'error', WorkspaceXmlError.missingAttribute)));
    expect(() => parse('<field name="x" type="boolean">yes</field>'),
        throwsA(isA<WorkspaceXmlException>().having(
            (e) => e.error, 'error', WorkspaceXmlError.invalidValue)));
    expect(() => parse('<field name="x" type="number">1,5</field>'),
        throwsA(isA<WorkspaceXmlException>().having(
            (e) => e.error, 'error', WorkspaceXmlError.invalidValue)));
    expect(
        () => parse('<field name="x" type="string" value="a"/>'
            '<field name="x" type="string" value="b"/>'),
        throwsA(isA<WorkspaceXmlException>().having(
            (e) => e.error, 'error', WorkspaceXmlError.invalidValue)));
    expect(() => parse('<field type="string" value="no name"/>'),
        throwsA(isA<WorkspaceXmlException>().having(
            (e) => e.error, 'error', WorkspaceXmlError.missingAttribute)));
  });

  test('the confirm dialog counts settings, tables and rows', () {
    expect(configurationCounts(_tree),
        (settings: 8, tables: 2, rows: 2));
    expect(configurationCounts(const {}), (settings: 0, tables: 0, rows: 0));
  });
}
