// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3619 — every workspace route has its own measure (the decision on #3619):
// each route whose measure this leaf declared opens through the app's
// builder at 1024, 1440 and 1920 with the standard test overrides, in its
// declared measure, without an exception and without overflowing. A route
// this test cannot open is listed by name with the reason, never skipped
// silently. Full desk guards for these routes are the follow-up's.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/route_classes.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/ui/adaptive/page_measures.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_providers.dart';

const _work = PageMeasure.work;
const _form = PageMeasure.form;
const _reading = PageMeasure.reading;

/// The routes this leaf gave a measure, with it, and the path opened.
const _measured = <(String, PageMeasure, String)>[
  ('/settings', _work, '/settings'),
  ('/settings/public-page', _form, '/settings/public-page'),
  ('/money/repartition', _work, '/money/repartition'),
  ('/money/settlement', _work, '/money/settlement'),
  ('/assistants/connect', _form, '/assistants/connect'),
  ('/settings/assistants', _form, '/settings/assistants'),
  ('/settings/assistant-setup', _form, '/settings/assistant-setup'),
  ('/kiosk-gate', _work, ''),
  ('/kiosk', _work, ''),
  ('/pending', _reading, ''),
  ('/messages', _work, ''),
  ('/directory', _work, '/directory'),
  ('/money', _work, '/money'),
  ('/reserve', _work, '/reserve'),
  ('/formats', _form, '/formats'),
  ('/events', _work, ''),
  ('/plan', _work, ''),
  ('/conversation/:conversationId', _work, ''),
  ('/res/:id', _reading, ''),
  ('/space/:kind/:id', _reading, ''),
  ('/library', _work, '/library'),
  ('/workspace-code', _reading, '/workspace-code'),
  ('/nfc-config', _form, '/nfc-config'),
  ('/payment-config', _form, '/payment-config'),
  ('/einvoice-config', _form, '/einvoice-config'),
  ('/documents', _work, '/documents'),
  ('/invoicing/wizard', _work, '/invoicing/wizard'),
  ('/member/:memberId', _reading, '/member/member-1'),
  ('/report-editor', _work, '/report-editor'),
  ('/roles', _work, '/roles'),
  ('/settings/personal-info', _form, '/settings/personal-info'),
  ('/settings/payment-terms', _form, '/settings/payment-terms'),
  ('/settings/sites', _form, '/settings/sites'),
  ('/money/status', _work, '/money/status'),
  ('/money/purchase-orders', _work, '/money/purchase-orders'),
  ('/suppliers', _work, ''),
  ('/money/sales', _work, ''),
  ('/money/cash', _work, ''),
  ('/money/repartition-wizard', _form, '/money/repartition-wizard'),
  ('/settings/wording', _form, '/settings/wording'),
  ('/settings/colours', _form, '/settings/colours'),
  ('/settings/roles-of-this-space', _reading, '/settings/roles-of-this-space'),
  ('/settings/what-you-can-do', _reading, '/settings/what-you-can-do'),
  ('/settings/questions', _form, '/settings/questions'),
  ('/attention', _work, '/attention'),
  ('/reservations/period', _work, '/reservations/period'),
  ('/setup', _work, '/setup'),
  ('/setup/levels', _work, '/setup/levels'),
  ('/setup/launch', _work, '/setup/launch'),
  ('/setup/step/:id', _work, '/setup/step/basics'),
  ('/settings/number-sequences', _form, '/settings/number-sequences'),
  ('/members/managed', _form, '/members/managed'),
  ('/members/privacy', _work, '/members/privacy'),
  ('/payment-methods', _form, '/payment-methods'),
  ('/legal-identity', _form, '/legal-identity'),
  ('/deployment', _form, ''),
  ('/vat-declarations', _work, '/vat-declarations'),
  ('/vat', _form, '/vat'),
  ('/accessories', _work, '/accessories'),
  ('/features', _work, '/features'),
  ('/workspace-settings', _work, '/workspace-settings'),
  ('/reports', _work, '/reports'),
  ('/validation', _work, '/validation'),
  ('/availability', _form, '/availability'),
  ('/bi/report/:id', _work, ''),
  ('/members', _work, '/members'),
  ('/editor', _work, '/editor'),
  ('/editor/level/:levelId', _work, ''),
];

/// The routes the test cannot open, and why: each needs a record the
/// standard overrides do not seed.
const _notOpened = {
  '/conversation/:conversationId': 'needs a conversation the fakes hold',
  '/res/:id': 'needs a reservation id',
  '/space/:kind/:id': 'needs a place of a kind',
  '/bi/report/:id': 'needs a saved report',
  '/editor/level/:levelId': 'needs a level of the floor plan',
  '/kiosk-gate': 'a kiosk account\'s page: the fixture\'s owner is sent home',
  '/kiosk': 'a kiosk account\'s page: the fixture\'s owner is sent home',
  '/pending': 'shown only to a membership waiting for approval',
  '/messages': 'with the calendar hub on (every feature), it opens the calendar',
  '/events': 'with the calendar hub on (every feature), it opens the calendar',
  '/plan': 'an old address that forwards to /reserve',
  '/suppliers': 'an old address that forwards to /money/suppliers',
  '/money/sales': 'an old address that forwards to /invoices',
  '/money/cash': 'at the desk it opens its first door, /money/status (#3926)',
  '/deployment': 'needs deployToDev, which the fixture\'s owner does not hold',
};

void main() {
  test('each route declares the measure listed, and every one not opened '
      'says why', () {
    for (final (pattern, measure, path) in _measured) {
      expect(measureOf(pattern), measure, reason: pattern);
      expect(path.isEmpty, _notOpened.containsKey(pattern), reason: pattern);
    }
  });

  for (final (pattern, _, path) in _measured) {
    if (path.isEmpty) continue;
    for (final width in [1024.0, 1440.0, 1920.0]) {
      testWidgets('$path at ${width.toInt()} opens without an exception', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final features = WorkspaceFeature.values.toSet();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...standardTestOverrides(
                workspace: FakeWorkspaceRepository.withWorkspace(
                  featureFlags: {for (final f in features) f.name: true},
                ),
              ),
              enabledFeaturesSyncProvider.overrideWithValue(features),
            ],
            child: const DeskiloApp(),
          ),
        );
        await tester.pumpAndSettle();
        final router = ProviderScope.containerOf(
          tester.element(find.byType(DeskiloApp)),
        ).read(routerProvider)..go(path);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: path);
        expect(
          router.routeInformationProvider.value.uri.path,
          path,
          reason: '$pattern opened elsewhere',
        );
      });
    }
  }
}
