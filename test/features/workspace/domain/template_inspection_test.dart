// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1655 — the inspection DTO carries exactly the server's verdicts, and
// nothing a client should not hold.
//
// The fixture is the tiny builtin's inspection as the development project
// answered it (schema 266), cut to a few records; the wire words are the
// server's. A value is a scalar or a list of scalars, a map is a shape
// only, an unknown wire word is `unknown`, a rejected or unsupported
// inspection is not usable.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/workspace/domain/template_inspection.dart';
import 'package:deskilo/features/workspace/domain/template_preview.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _fixture() => Map<String, dynamic>.from(
    jsonDecode(File('test/fixtures/templates/tiny_inspection.json').readAsStringSync()) as Map);

void main() {
  final inspection = TemplateInspection.fromJson(_fixture());

  test('the head is the server\'s, and the outline inside is the outline', () {
    expect(inspection.key, 'tiny');
    expect(inspection.status, TemplateInspectionStatus.ok);
    expect(inspection.profile, TemplateProfile.legacy);
    expect(inspection.digest, 'c112a979665aaa030dd18b2d8884b6ba');
    expect(inspection.registryRevision, '098ca53ea9c3');
    expect(inspection.schemaRevision, 266);
    expect(inspection.supportedSchemaVersions, [1]);
    expect(inspection.compatibility, TemplateCompatibility.supported);
    expect(inspection.entities, ['floor_plan']);
    expect(inspection.usable, isTrue);
    expect(inspection.outline.groups, [TemplateGroup.space]);
    expect(inspection.outline.refused, isFalse);
  });

  test('a field keeps its path, id, disposition and a scalar value', () {
    final name = inspection.fields.singleWhere((f) => f.path == 'floor_plan[Ground floor].name');
    expect(name.id, 'floor_plan[].name');
    expect(name.disposition, TemplateFieldDisposition.present);
    expect(name.value, 'Ground floor');
    final x = inspection.fields.singleWhere((f) => f.path.endsWith('seats[B1].x'));
    expect(x.value, 24);
    final whole = inspection.fields.singleWhere((f) => f.path == 'floor_plan[Ground floor].bookable_as_whole');
    expect(whole.value, false, reason: 'an explicit false is a value, not an absence');
  });

  test('a list of scalars is a value; a map is a shape, never copied', () {
    final amenities = inspection.fields.singleWhere((f) => f.path.endsWith('seats[B1].amenities'));
    expect(amenities.value, ['lamp', 'screen']);
    final design = inspection.fields.singleWhere((f) => f.id == 'workspace.invoice_pdf_template');
    expect(design.value, isNull);
    expect(design.shape, 'object');
    expect(scalarOnly([1, {'a': 1}]), isNull, reason: 'a list holding a map is not a list of scalars');
  });

  test('absent, stripped and reference dispositions carry their meaning', () {
    final simultaneous = inspection.fields.singleWhere((f) => f.id == 'workspace.booking_rules.simultaneous_reservations');
    expect(simultaneous.disposition, TemplateFieldDisposition.absent);
    expect(simultaneous.absent, TemplateAbsentMeaning.productDefault);
    final carnets = inspection.fields.singleWhere((f) => f.id == 'workspace.feature_flags.carnets');
    expect(carnets.absent, TemplateAbsentMeaning.registryDefault,
        reason: 'an absent flag is the registry default, never enabled authority');
    final site = inspection.fields.singleWhere((f) => f.id == 'floor_plan[].site');
    expect(site.disposition, TemplateFieldDisposition.stripped);
    expect(site.reason, 'sites never travel');
    final accessories = inspection.fields.singleWhere((f) => f.path.endsWith('seats[B1].accessories'));
    expect(accessories.disposition, TemplateFieldDisposition.reference);
  });

  test('required inputs, exclusions and coverage are typed', () {
    expect([for (final r in inspection.requiredInputs) r.id],
        ['workspace.country_code', 'workspace.currency_code', 'workspace.name', 'workspace.timezone']);
    expect(inspection.requiredInputs.first.binding, 'target');
    expect(inspection.exclusions.first.id, 'floor_plan[].background_path');
    expect(inspection.exclusions.first.portability, 'never');
    expect(inspection.coverage.registered, 27);
    expect(inspection.coverage.present, 100);
    expect(inspection.coverage.requiredInputs, 4);
    expect(inspection.problems, isEmpty);
  });

  test('a wire word this build does not know is unknown, never usable', () {
    final json = _fixture()
      ..['status'] = 'something_new'
      ..['profile'] = 'other';
    (json['fields'] as List)[0] = {'id': 'x', 'path': 'x', 'disposition': 'teleported', 'absent': 'magic'};
    final odd = TemplateInspection.fromJson(json);
    expect(odd.status, TemplateInspectionStatus.unknown);
    expect(odd.profile, TemplateProfile.unknown);
    expect(odd.fields.first.disposition, TemplateFieldDisposition.unknown);
    expect(odd.fields.first.absent, TemplateAbsentMeaning.unknown);
    expect(odd.usable, isFalse);
  });

  test('a rejected or unsupported inspection is not usable, and says why', () {
    final rejected = TemplateInspection.fromJson(_fixture()
      ..['status'] = 'rejected'
      ..['profile'] = 'rejected'
      ..['problems'] = [
        {'path': 'workspace.nonsense', 'problem': 'unknown_field'},
        {'path': 'workspace.payment_instructions.iban', 'problem': 'carries_excluded', 'reason': "bank details are the source's own"},
      ]);
    expect(rejected.usable, isFalse);
    expect([for (final p in rejected.problems) p.problem], ['unknown_field', 'carries_excluded']);
    expect(rejected.problems.last.reason, contains('bank details'));
    final newer = TemplateInspection.fromJson(_fixture()
      ..['status'] = 'unsupported_version'
      ..['digest'] = null
      ..['fields'] = <Object?>[]);
    expect(newer.status, TemplateInspectionStatus.unsupportedVersion);
    expect(newer.digest, isNull);
    expect(newer.fields, isEmpty);
    expect(newer.usable, isFalse);
  });
}
