// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1659 — capabilities are read from a template's INSPECTED configuration.
// A description that says "approval" does not satisfy "two approvals";
// a flag switched off does not satisfy the flag; a flag on under a parent
// that is off is conditional; absence is the target's own value, never
// false. Words in five languages, accents folded, reach the same
// capability; an unknown word is suggested, never substituted. The
// comparison rows keep missing, unknown and other-currency apart from
// "different".
import 'package:deskilo/features/workspace/domain/template_capabilities.dart';
import 'package:deskilo/features/workspace/domain/template_inspection.dart';
import 'package:deskilo/features/workspace/domain/template_outline.dart';
import 'package:deskilo/features/workspace/domain/template_preview.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

TemplateFieldRecord present(String path, String id, Object? value) =>
    TemplateFieldRecord(
        path: path, id: id, disposition: TemplateFieldDisposition.present, value: value);

TemplateInspection template(
  String id,
  List<TemplateFieldRecord> fields, {
  String name = '',
  String description = '',
  TemplateInspectionStatus status = TemplateInspectionStatus.ok,
  List<TemplateRequiredInput> inputs = const [],
}) =>
    TemplateInspection(
      templateId: id,
      key: id,
      name: name.isEmpty ? id : name,
      description: description,
      status: status,
      profile: TemplateProfile.full,
      compatibility: TemplateCompatibility.supported,
      outline: const TemplateOutline(
          compatibility: TemplateCompatibility.supported, groups: []),
      fields: fields,
      requiredInputs: inputs,
    );

TemplateFieldRecord flag(WorkspaceFeature f, bool on) =>
    present(featureFieldId(f), featureFieldId(f), on);

List<TemplateFieldRecord> policy(String type, int count) => [
      present('tables.validation_policies[$type].event_type',
          'tables.validation_policies[].event_type', type),
      present('tables.validation_policies[$type].required_count',
          'tables.validation_policies[].required_count', count),
    ];

CapabilityState stateOf(String capability, TemplateInspection t) =>
    capabilityById[capability]!.evaluate(TemplateFacts(t)).state;

void main() {
  group('the evaluator reads configuration, not words', () {
    test('two approvals needs a policy asking for two', () {
      final wordy = template('wordy', policy('refund', 1),
          description: 'Every refund needs approval by two people');
      final real = template('real', policy('refund', 2));
      final other = template('other', policy('expense', 2));
      expect(stateOf('policy.multi_approval', wordy), CapabilityState.disabled);
      expect(stateOf('policy.multi_approval', real), CapabilityState.enabled);
      expect(stateOf('policy.multi_approval_refunds', real), CapabilityState.enabled);
      expect(stateOf('policy.multi_approval_refunds', other), CapabilityState.unspecified,
          reason: 'two approvals for expenses says nothing about refunds');
      expect(stateOf('policy.multi_approval', template('none', const [])),
          CapabilityState.unspecified);
    });

    test('a flag off is disabled, absent is unspecified, under an off parent '
        'it is conditional', () {
      expect(stateOf('feature.carnets', template('on', [flag(WorkspaceFeature.carnets, true)])),
          CapabilityState.enabled);
      expect(stateOf('feature.carnets', template('off', [flag(WorkspaceFeature.carnets, false)])),
          CapabilityState.disabled);
      expect(stateOf('feature.carnets', template('absent', const [])),
          CapabilityState.unspecified);
      final child = featureManifest.values.firstWhere((e) => e.requires != null);
      final blocked = template('blocked', [flag(child.feature, true), flag(child.requires!, false)]);
      expect(stateOf('feature.${child.feature.name}', blocked), CapabilityState.conditional);
    });

    test('credit packs need the flag AND an active product', () {
      final product = present('tables.credit_products[Ten].active', 'tables.credit_products[].active', true);
      expect(stateOf('model.credit_packs',
              template('both', [flag(WorkspaceFeature.carnets, true), product])),
          CapabilityState.enabled);
      expect(stateOf('model.credit_packs',
              template('flag-off', [flag(WorkspaceFeature.carnets, false), product])),
          CapabilityState.disabled);
      expect(stateOf('model.credit_packs',
              template('no-product', [flag(WorkspaceFeature.carnets, true)])),
          CapabilityState.unspecified);
    });

    test('opening hours need a local value when the template asks for one', () {
      final t = template('input', const [], inputs: const [
        TemplateRequiredInput(
            path: 'workspace.booking_rules.open_weekdays',
            id: 'workspace.booking_rules.open_weekdays',
            binding: 'target'),
      ]);
      expect(stateOf('setting.opening_hours', t), CapabilityState.localInputRequired);
    });

    test('an unusable or unreadable template never satisfies anything', () {
      final rejected = template('r', [flag(WorkspaceFeature.carnets, true)],
          status: TemplateInspectionStatus.rejected);
      final unknown = template('u', [flag(WorkspaceFeature.carnets, true)],
          status: TemplateInspectionStatus.unknown);
      expect(stateOf('feature.carnets', rejected), CapabilityState.incompatible);
      expect(stateOf('feature.carnets', unknown), CapabilityState.unknown);
      expect(CapabilityState.values.where((s) => s.satisfies), [CapabilityState.enabled]);
    });

    test('every feature flag is a capability', () {
      for (final f in WorkspaceFeature.values) {
        expect(capabilityById['feature.${f.name}'], isNotNull, reason: f.name);
      }
    });
  });

  group('words become capabilities', () {
    final vocabulary = CapabilityVocabulary({
      'feature.carnets': ['Carnets', 'Credit packs'],
    });

    test('five languages and folded accents reach the same capability', () {
      for (final q in [
        'two approvals for refunds',
        'deux validations pour les remboursements',
        'Zwei Freigaben für Erstattungen',
        'dos aprobaciones para reembolsos',
        'due approvazioni per i rimborsi',
      ]) {
        expect(vocabulary.parse(q).capabilities, ['policy.multi_approval_refunds'], reason: q);
      }
      expect(vocabulary.parse('paiement à l’usage').capabilities, ['model.pay_as_you_go']);
      expect(vocabulary.parse('Öffnungszeiten').capabilities, ['setting.opening_hours']);
    });

    test('the stable id works for experts, and free words stay free', () {
      final parsed = vocabulary.parse('feature.carnets near the station');
      expect(parsed.capabilities, ['feature.carnets']);
      expect(parsed.freeWords, ['near', 'the', 'station']);
    });

    test('a typo is suggested, never substituted', () {
      expect(vocabulary.parse('subscripton').capabilities, isEmpty);
      expect(vocabulary.suggest('subscripton'), 'subscription');
      expect(vocabulary.suggest('zzzzzzzz'), isNull);
    });
  });

  group('search', () {
    final a = template('a', [...policy('refund', 2), flag(WorkspaceFeature.carnets, true)],
        name: 'Alpha');
    final b = template('b', [...policy('refund', 1), flag(WorkspaceFeature.carnets, true)],
        name: 'Bravo', description: 'refund approval by two');
    final c = template('c', [...policy('refund', 2), flag(WorkspaceFeature.carnets, false)],
        name: 'Charlie');

    test('required is AND over configuration; the wordy template is out', () {
      final hits = matchTemplates([a, b, c], const CapabilityQuery(
          required: ['policy.multi_approval_refunds', 'feature.carnets']));
      expect(hits.map((m) => m.inspection.templateId), ['a']);
      expect(hits.single.evidence['feature.carnets']!.path, featureFieldId(WorkspaceFeature.carnets));
    });

    test('excluded drops, preferred ranks, ties sort by name then id', () {
      final hits = matchTemplates([c, b, a], const CapabilityQuery(
          preferred: ['policy.multi_approval_refunds'], excluded: ['feature.carnets']));
      expect(hits.map((m) => m.inspection.templateId), ['c']);
      final ranked = matchTemplates([b, c, a], const CapabilityQuery(
          preferred: ['policy.multi_approval_refunds']));
      expect(ranked.map((m) => m.inspection.templateId), ['a', 'c', 'b']);
    });

    test('a contradiction matches nothing', () {
      expect(matchTemplates([a], const CapabilityQuery(
          required: ['feature.carnets'], excluded: ['feature.carnets'])), isEmpty);
    });
  });

  group('comparison rows', () {
    test('same, different, missing, unknown and other currency are apart', () {
      final eur = template('eur', [
        present('workspace.currency_code', 'workspace.currency_code', 'EUR'),
        present('tables.plans[Flex].base_fee_cents', 'tables.plans[].base_fee_cents', 1000),
        present('workspace.timezone', 'workspace.timezone', 'Europe/Paris'),
        present('workspace.booking_rules.granularity', 'workspace.booking_rules.granularity', 'half_day'),
        flag(WorkspaceFeature.carnets, false),
      ]);
      final chf = template('chf', [
        present('workspace.currency_code', 'workspace.currency_code', 'CHF'),
        present('tables.plans[Flex].base_fee_cents', 'tables.plans[].base_fee_cents', 1000),
        present('workspace.timezone', 'workspace.timezone', 'Europe/Paris'),
        const TemplateFieldRecord(
            path: 'workspace.booking_rules.granularity',
            id: 'workspace.booking_rules.granularity',
            disposition: TemplateFieldDisposition.unknown),
      ]);
      final rows = {for (final r in compareTemplates([eur, chf])) r.path: r.difference};
      expect(rows['workspace.timezone'], ComparisonDifference.same);
      expect(rows['workspace.currency_code'], ComparisonDifference.different);
      expect(rows['tables.plans[Flex].base_fee_cents'], ComparisonDifference.notComparable,
          reason: '10.00 EUR is not 10.00 CHF');
      expect(rows[featureFieldId(WorkspaceFeature.carnets)], ComparisonDifference.missing,
          reason: 'absent is not false');
      expect(rows['workspace.booking_rules.granularity'], ComparisonDifference.unknown);
    });
  });
}
