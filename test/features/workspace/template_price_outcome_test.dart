// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1656 group 2 — the apply result says what happened to a template's
// floor-plan prices; anything unrecognised is "none", never "applied".
import 'package:deskilo/features/workspace/domain/workspace_template.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

void main() {
  test('the server word decides; the unknown is none', () {
    expect(
      TemplatePriceOutcome.fromResult({'prices': 'applied'}),
      TemplatePriceOutcome.applied,
    );
    expect(
      TemplatePriceOutcome.fromResult({'prices': 'currency_mismatch'}),
      TemplatePriceOutcome.currencyMismatch,
    );
    expect(
      TemplatePriceOutcome.fromResult({'prices': 'weird'}),
      TemplatePriceOutcome.none,
    );
    expect(
      TemplatePriceOutcome.fromResult({'copy_jobs': <Object>[]}),
      TemplatePriceOutcome.none,
    );
    expect(TemplatePriceOutcome.fromResult(null), TemplatePriceOutcome.none);
  });

  test('the fake reports the outcome it is given', () async {
    final repo = FakeWorkspaceRepository()
      ..templates.add(const WorkspaceTemplate(id: 't', key: 't', name: 'T'))
      ..templateApplyResult = const TemplateApplyResult(
        prices: TemplatePriceOutcome.currencyMismatch,
        validationBlocked: ['expense'],
      );
    expect(
      (await repo.applyWorkspaceTemplate('ws', 't')).prices,
      TemplatePriceOutcome.currencyMismatch,
    );
  });

  test('the apply result names the policies left for local choice (#1657)', () {
    final r = TemplateApplyResult.fromResult({
      'prices': 'applied',
      'validation_blocked': ['expense', 'payment'],
    });
    expect(r.prices, TemplatePriceOutcome.applied);
    expect(r.validationBlocked, ['expense', 'payment']);
    expect(TemplateApplyResult.fromResult(null).validationBlocked, isEmpty);
  });
}
