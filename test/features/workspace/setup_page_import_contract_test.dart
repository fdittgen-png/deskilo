// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2331 — what the setup questionnaire says the import applies is what a
// fresh space ends up with.
//
// The page labels every answer: applied by the import, typed in the app,
// or kept in the file only. Before this test, "applied" was a belief. The
// role matrix and the default validation rule were written into `<setup>`,
// which the importer ignores by design; and four answers the page DID put
// into `<configuration>` were values the server refuses — 'registered' for
// the VAT regime, 'service' as an event type, a 'named' validator scope and
// null in two NOT NULL VAT columns — so for a VAT-registered owner the
// whole configuration failed to import.
//
// So this runs the REAL page (tool/setup/step_harness.mjs), parses its file
// with the app's parser, lays it onto a fresh space the way the import does
// (`import_workspace_configuration` in mirror mode onto a space that has no
// rows yet stores each row as given), and reads every applied answer back
// through the app's own readers. A second group pins the key and field
// names against the importer's source, and the values against the
// server's CHECK constraints, so a renamed key or a refused value fails
// here instead of on the owner's first import.
import 'dart:io';

import 'package:deskilo/core/time/work_hours.dart';
import 'package:deskilo/features/events/domain/validation_policy.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:deskilo/features/money/domain/invoice_clauses.dart';
import 'package:deskilo/features/money/domain/invoice_legal.dart';
import 'package:deskilo/features/money/domain/vat_tax_point.dart';
import 'package:deskilo/features/money/domain/number_sequence.dart';
import 'package:deskilo/features/money/domain/subscription_levels.dart';
import 'package:deskilo/features/money/domain/vat_regime.dart';
import 'package:deskilo/features/workspace/domain/booking_policies.dart';
import 'package:deskilo/features/workspace/domain/payment_instructions.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_import.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/domain/workspace_xml.dart';
import 'package:flutter_test/flutter_test.dart';

/// The page's export in [mode] (see the harness), parsed by the app — or
/// null when node is missing (same bargain as setup_runs_test).
WorkspaceXmlData? pageExport(String mode) {
  if (Process.runSync('node', ['--version']).exitCode != 0) {
    markTestSkipped('node is not on PATH');
    return null;
  }
  final r = Process.runSync('node', [
    'tool/setup/step_harness.mjs',
    '--export-xml=$mode',
  ]);
  expect(r.exitCode, 0, reason: 'the page failed to export:\n${r.stderr}');
  return parseWorkspaceXml(r.stdout as String);
}

/// A space right after the import: the settings writers, the plan RPC's
/// payload, and the configuration stored row for row.
class FreshSpace {
  FreshSpace.imported(WorkspaceXmlData data)
    : plan = workspaceXmlPlanToJson(data.levels),
      configuration = data.configuration!,
      workspace = _workspace(data);

  final List<Map<String, Object?>> plan;
  final Map<String, Object?> configuration;
  final Workspace workspace;

  Map<String, dynamic> get row =>
      Map<String, dynamic>.from(configuration['workspace']! as Map);

  List<Map<String, dynamic>> table(String name) => [
    for (final r in (configuration['tables']! as Map)[name] as List? ?? [])
      Map<String, dynamic>.from(r as Map),
  ];

  static Workspace _workspace(WorkspaceXmlData data) {
    final ws = Map<String, dynamic>.from(
      data.configuration!['workspace']! as Map,
    );
    return Workspace(
      id: 'fresh',
      // The import never renames a space: it keeps the name it was
      // created with — which is why the page labels the name "type in
      // the app".
      name: 'Created in the app',
      countryCode: data.settings.countryCode,
      currencyCode: data.settings.currencyCode,
      timezone: data.settings.timezone,
      inviteCode: 'FRESH00000',
      featureFlags: data.settings.featureFlags,
      paymentInstructions: data.settings.paymentInstructions,
      rolePermissions: Map<String, dynamic>.from(
        ws['role_permissions'] as Map? ?? const {},
      ),
      whatsappGroup: ws['whatsapp_group'] as String? ?? '',
      address: ws['address'] as String? ?? '',
      vatRegime: ws['vat_regime'] as String? ?? 'not_subject',
      vatId: ws['vat_id'] as String? ?? '',
      legalId: ws['legal_id'] as String? ?? '',
      street: ws['street'] as String? ?? '',
      city: ws['city'] as String? ?? '',
      postalCode: ws['postal_code'] as String? ?? '',
      deskOpacity: (ws['desk_opacity'] as num?)?.toInt() ?? 100,
      invoiceLegal: Map<String, dynamic>.from(
        ws['invoice_legal'] as Map? ?? const {},
      ),
      defaultLocale: ws['default_locale'] as String? ?? '',
      invitationTemplates: Map<String, dynamic>.from(
        ws['invitation_templates'] as Map? ?? const {},
      ),
    );
  }
}

ValidationPolicy policyFromRow(Map<String, dynamic> row) => ValidationPolicy(
  workspaceId: 'fresh',
  eventType: row['event_type'] as String?,
  requiredCount: (row['required_count'] as num).toInt(),
  adminsMayValidate: row['admins_may_validate'] as bool? ?? true,
  eligibleAdminIds: const [],
  ownerRequired: row['owner_required'] as bool? ?? false,
  autoValidateAdmin: row['auto_validate_admin'] as bool? ?? false,
  autoValidateOwner: row['auto_validate_owner'] as bool? ?? false,
  validatorScope: row['validator_scope'] as String? ?? 'admins',
);

/// Every source file of the migrations, joined: the importer is built by
/// anchored patches across many of them.
String migrations() => [
  for (final f in Directory(
    'supabase/migrations',
  ).listSync().whereType<File>().where((f) => f.path.endsWith('.sql')))
    f.readAsStringSync(),
].join('\n');

/// A JS literal of the page, by its `const NAME=` declaration.
String pageConst(String html, String name) {
  final start = html.indexOf('const $name=');
  expect(start, isNot(-1), reason: 'web/setup.html declares no $name');
  return html.substring(start, html.indexOf(';', start));
}

void main() {
  final html = File('web/setup.html').readAsStringSync();

  group('every answer the page labels "applied by import" arrives', () {
    test('identity, region, features, payment details and the plan', () {
      final data = pageExport('answered');
      if (data == null) return;
      final space = FreshSpace.imported(data);
      final ws = space.workspace;
      expect(ws.countryCode, 'FR');
      expect(ws.currencyCode, 'EUR');
      expect(ws.timezone, 'Europe/Paris');
      expect(ws.defaultLocale, 'de');
      expect(ws.address, '1 Harness Road');
      expect(data.settings.brandColor, '#1F3A5F');
      expect(ws.deskOpacity, 80);
      expect(ws.whatsappGroup, 'https://chat.whatsapp.com/harness');
      expect(ws.invitationTemplates, {
        'fr': 'Bonjour {firstName}',
        'en': 'Hello {firstName}',
      });
      expect(ws.featureFlags['invoicing'], isTrue);
      final pay = PaymentInstructions.fromDb(ws.paymentInstructions);
      expect(pay.iban, 'FR7630006000011234567890189');

      // The plan, and whole-space booking in it: the level's flag and
      // the bookable room's price (40.00).
      final ground = space.plan.first;
      expect(ground[WorkspaceImportPlanKeys.bookableAsWhole], isTrue);
      final room =
          (ground[WorkspaceImportPlanKeys.offices]! as List).first as Map;
      expect(room[WorkspaceImportPlanKeys.bookableAsWhole], isTrue);
      expect(room[WorkspaceImportPlanKeys.priceCents], 4000);
      expect(room[WorkspaceImportPlanKeys.name], 'Main room');
    });

    test('hours, policies and closures', () {
      final data = pageExport('answered');
      if (data == null) return;
      final space = FreshSpace.imported(data);
      final rules = Map<String, dynamic>.from(
        space.row['booking_rules'] as Map,
      );
      final hours = WorkHours.fromRules(rules);
      expect(hours.startMinutes, 7 * 60 + 30);
      expect(hours.endMinutes, 19 * 60);
      final policies = BookingPolicies.fromRules(rules);
      expect(policies.simultaneousReservations, 2);
      expect(policies.outsideHoursMode, OutsideHoursMode.walkupOnly);
      expect(space.table('closure_days').single['day'], '2026-12-25');
    });

    test('tariffs: bands, levels, packages, services, VAT rates', () {
      final data = pageExport('answered');
      if (data == null) return;
      final space = FreshSpace.imported(data);
      expect(space.table('fee_bands').map((b) => b['fee_cents']), [
        15000,
        25000,
      ]);
      final levels = SubscriptionLevels.fromDb(
        Map<String, dynamic>.from(space.row['subscription_levels'] as Map),
      );
      expect(levels.offeredLevels, [50, 100]);
      expect(space.table('packages').single['price_cents'], 20000);
      final service = space.table('services').single;
      expect(service['name'], 'Locker');
      expect(service['vat_rate'], 'Standard');
      expect(space.table('vat_rates').map((r) => r['label']), [
        'Standard',
        'Reduced',
      ]);
      expect(space.table('sites').single['name'], 'North');
    });

    test('legal identity, mentions, reminders and the two number series', () {
      final data = pageExport('answered');
      if (data == null) return;
      final space = FreshSpace.imported(data);
      final ws = space.workspace;
      expect(vatRegimeFromWire(ws.vatRegime), VatRegime.vatRegistered);
      expect(ws.vatId, 'FR12345678901');
      expect(ws.legalId, 'RCS 123');
      expect(
        [ws.street, ws.postalCode, ws.city],
        ['1 Harness Road', '34000', 'Montpellier'],
      );
      final legal = InvoiceLegal.fromJson(ws.invoiceLegal);
      expect(legal.legalForm, 'SAS');
      expect(legal.paymentTerms, '30 days');
      // #2355 — the harness answers 'payment', the pre-#2355 word for
      // cash: it arrives as the cash option, receipts in France.
      expect(legal.vatTaxPoint, VatTaxPointOption.cash);
      expect(legal.taxPointBasis(ws.countryCode).onReceipts, isTrue);
      expect(legal.isAssociation, isFalse);
      final dunning = DunningRules.fromJson(
        Map<String, dynamic>.from(space.row['dunning_rules'] as Map),
      );
      expect(
        [dunning.levels, dunning.firstAfterDays, dunning.betweenDays],
        [3, 10, 7],
      );
      final series = {
        for (final r in space.table('number_sequences'))
          r['journal']: NumberSequence.fromDb(r),
      };
      expect(
        series['invoice']!.format(1, DateTime(2026, 10)),
        'F-2026-10-00001',
      );
      expect(series['member']!.format(7, DateTime(2026, 10)), 'M-007');
    });

    test('the role matrix and the default validation rule', () {
      final data = pageExport('answered');
      if (data == null) return;
      final space = FreshSpace.imported(data);
      final member = permissionsForRole(PermissionRole.member, space.workspace);
      expect(member, contains(WorkspacePermission.makeReservations));
      final policies = space
          .table('validation_policies')
          .map(policyFromRow)
          .toList();
      // A domain without its own card reads the default rule: two
      // approvals, the owner's among them.
      final fallback = policyFor(EventType.expense.dbName, policies);
      expect(fallback.eventType, isNull);
      expect(fallback.requiredCount, 2);
      expect(fallback.ownerRequired, isTrue);
      expect(policyFor('payment', policies).validatorScope, 'members');
      expect(policyFor('service_charge', policies).requiredCount, 3);
      expect(
        policyFor('reservation_delete', policies).autoValidateAdmin,
        isTrue,
      );
    });

    test('a first visit: the defaults keep every member able to book', () {
      final data = pageExport('defaults');
      if (data == null) return;
      final matrix = FreshSpace.imported(data).workspace.rolePermissions;
      final everyday = everydayMatrix();
      expect(matrix['member'], everyday['member']);
      expect(
        Set.of(matrix['admin'] as List),
        Set.of(everyday['admin'] as List),
      );
      expect(matrix['co_owner'], [
        for (final p in WorkspacePermission.values) p.wireName,
      ]);
    });

    test('the configuration travels even with the transfer switched off', () {
      final data = pageExport('transfer-off');
      if (data == null) return;
      expect(data.settings.featureFlags['configurationTransfer'], isFalse);
      expect(
        data.configuration,
        isNotNull,
        reason:
            'the app asks before applying it; dropping it from the '
            'file left nothing to ask about',
      );
    });
  });

  group('the file speaks the importer\'s language', () {
    test('every key and row field is one import_workspace_configuration '
        'reads', () {
      final data = pageExport('answered');
      if (data == null) return;
      final sql = migrations();
      final config = data.configuration!;
      final unread = <String>[
        for (final k in (config['workspace']! as Map).keys)
          if (!sql.contains("v_ws ? '$k'")) 'workspace.$k',
        for (final MapEntry(:key, :value) in (config['tables']! as Map).entries)
          if (!sql.contains("v_t ? '$key'"))
            'tables.$key'
          else
            for (final row in value as List)
              for (final field in (row as Map).keys)
                // Plain, or quoted inside an anchored patch ('').
                if (!RegExp("->>?\\s*'{1,2}$field'").hasMatch(sql))
                  'tables.$key.$field',
      ];
      expect(
        unread.toSet(),
        isEmpty,
        reason: 'the page writes what the importer never reads',
      );
    });

    test('every value is inside the server\'s CHECK constraints', () {
      final data = pageExport('answered');
      if (data == null) return;
      final space = FreshSpace.imported(data);
      expect([
        'not_subject',
        'exempt',
        'vat_registered',
      ], contains(space.row['vat_regime']));
      expect(space.row['desk_opacity'], inInclusiveRange(20, 100));
      final eventTypes = {for (final t in EventType.values) t.dbName};
      for (final p in space.table('validation_policies')) {
        if (p['event_type'] != null) {
          expect(eventTypes, contains(p['event_type']));
        }
        expect(['admins', 'listed', 'members'], contains(p['validator_scope']));
        expect(p['required_count'], inInclusiveRange(1, 10));
      }
      for (final s in space.table('number_sequences')) {
        final seq = NumberSequence.fromDb(s);
        expect(seq.isValidPair, isTrue, reason: '${s['journal']}');
        expect((s['prefix'] as String).length, lessThanOrEqualTo(16));
      }
      for (final r in space.table('vat_rates')) {
        expect(r['group_key'], isA<String>());
        expect(r['exemption_reason'], isA<String>());
      }
    });

    test('the page offers every permission, in the roles screen order', () {
      final perms = RegExp(r"'(\w+)'")
          .allMatches(pageConst(html, 'PERMS'))
          .map((m) => m.group(1))
          .toList();
      expect(perms, [for (final p in WorkspacePermission.values) p.wireName]);
    });

    test('the countries marked "DesKilo issues invoices" are the ones the '
        'app issues for', () {
      final marked = RegExp(r"'([A-Z]{2})'")
          .allMatches(pageConst(html, 'INVOICING_COUNTRIES'))
          .map((m) => m.group(1)!)
          .toSet();
      final countries = RegExp(r"\['([A-Z]{2})'")
          .allMatches(pageConst(html, 'COUNTRIES'))
          .map((m) => m.group(1)!);
      for (final c in countries) {
        final issues =
            legalProfileOf(LegalClauseSnapshot(sellerCountry: c)) !=
            LegalProfile.unsupported;
        expect(marked.contains(c), issues, reason: c);
      }
    });

    test('the destination labels are the ones this test reads back', () {
      // Everything not listed is "applied by import" and is read back
      // above. Moving an answer between kinds is a decision: this test
      // and the page's review list change with it.
      final dest = {
        for (final m in RegExp(
          r"(\w+):'(\w+)'",
        ).allMatches(pageConst(html, 'DEST')))
          m.group(1)!: m.group(2)!,
      };
      expect(dest, {
        'name': 'app',
        'environment': 'app',
        'vatPeriod': 'app',
        'members': 'app',
        'einvoice': 'file',
      });
    });
  });
}
