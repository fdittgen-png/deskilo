// SPDX-License-Identifier: 0BSD
//
// The setup questionnaire (web/setup.html) generates a schema-v2
// deskilo-workspace document with an extra `<setup>` extension block.
// This test pins the CONTRACT: the app's parser accepts exactly what
// the page emits — settings, accessory catalog and auto-laid-out floor
// plan parse; the <setup> block is ignored, never fatal.
//
// #1559 — and the second group below pins what the page puts INSIDE
// `<configuration>`, by running the real page and interpreting its
// export with the app's own readers. A hand-written fixture cannot do
// that: it says what someone believed the page emitted, and it stays
// green while the page emits something else.
import 'dart:io';

import 'package:deskilo/core/time/work_hours.dart';
import 'package:deskilo/features/workspace/domain/booking_policies.dart';
import 'package:deskilo/features/workspace/domain/workspace_xml.dart';
import 'package:flutter_test/flutter_test.dart';

/// A document shaped exactly like web/setup.html's exportXml() output:
/// 1 level, 1 office, 1 desk with 4 seats (2 columns × 2 rows, seat
/// footprint 6×4), one accessory, features, payment instructions, and
/// the full `<setup>` extension.
const _pageOutput = '''
<?xml version="1.0" encoding="UTF-8"?>
<deskilo-workspace version="2">
  <settings name="pezenas1" country="FR" currency="EUR" timezone="Europe/Paris" brand-color="#1F3A5F">
    <feature key="calendarTab" enabled="true"/>
    <feature key="levelBooking" enabled="false"/>
    <payment-instruction key="iban" value="FR76 0000 1111"/>
  </settings>
  <accessories>
    <accessory name="Écran" supplement-cents="2000" active="true" sort-order="0"/>
  </accessories>
  <floor-plan>
    <level name="1er étage" sort-order="0">
      <office name="Bureau 1" color="4288585374" bookable-as-whole="false" x="1" y="1" w="14" h="10">
        <desk name="Table 1" x="2" y="2" w="12" h="8">
          <seat name="Place 1" x="2" y="2" orientation="s" chair=""/>
          <seat name="Place 2" x="8" y="2" orientation="s" chair=""/>
          <seat name="Place 3" x="2" y="6" orientation="n" chair="">
            <accessory name="Écran"/>
          </seat>
          <seat name="Place 4" x="8" y="6" orientation="n" chair=""/>
        </desk>
      </office>
    </level>
  </floor-plan>
  <setup>
    <availability granularity="half_day" day-start="08:00" half-boundary="12:00" day-end="17:00" open-weekdays="1,2,3,4,5">
      <closure day="2026-12-25"/>
    </availability>
    <identity language="fr" address="12 rue Exemple" whatsapp-group=""/>
    <billing>
      <tier from-pct="0" to-pct="100" fee-cents="25000" overage-cents="0"/>
      <subscription-levels values="25,50,75,100" free-value="false"/>
      <package name="test" days="2" price-cents="20000"/>
    </billing>
    <services>
      <service name="test" price-cents="2000"/>
    </services>
    <legal organization="association" vat-regime="not_subject" registration="W123" vat-id="" exemption-reason="TVA non applicable, art. 293 B du CGI" street="conti" postal-code="34120" city="pezenas">
      <mention key="legalForm" value="Association loi 1901"/>
      <reminders levels="2" first-days="14" between-days="14"/>
    </legal>
    <roles>
      <role name="co_owner" permissions="manageRoles,manageMembers"/>
      <role name="admin" permissions="manageMembers"/>
      <role name="member" permissions=""/>
      <validation required="1" owner-sign-off="false"/>
    </roles>
    <members>
      <member name="Flo" email="f@example.com" role="admin" subscription-pct="100"/>
    </members>
  </setup>
</deskilo-workspace>
''';

void main() {
  test('the app parser accepts the setup page output; <setup> is ignored',
      () {
    final data = parseWorkspaceXml(_pageOutput);
    expect(data.settings.name, 'pezenas1');
    expect(data.settings.featureFlags['levelBooking'], isFalse);
    // #1289 — the brand seed rides on <settings>, optional.
    expect(data.settings.brandColor, '#1F3A5F');
    expect(data.settings.paymentInstructions['iban'], 'FR76 0000 1111');
    expect(data.accessories.single.name, 'Écran');
    expect(data.accessories.single.supplementCents, 2000);
    final level = data.levels.single;
    final office = level.offices.single;
    final desk = office.desks.single;
    expect(desk.seats, hasLength(4));
    expect(desk.seats.first.name, 'Place 1');
    expect(desk.seats[2].accessoryNames, ['Écran']);
  });

  test('the page ships in web/ so the web deploy publishes it at '
      '/deskilo/setup.html', () {
    final page = File('web/setup.html').readAsStringSync();
    expect(page, contains('deskilo-workspace version="3"'));
    // The setup extension the configurator reads.
    expect(page, contains('<setup>'));
    // Every workspace feature key appears exactly as the enum names it.
    for (final key in [
      'calendarTab', 'invoicing', 'roleManagement', 'deletionRequests',
      'dunning', 'memberReports', 'documents',
    ]) {
      expect(page, contains("'$key'"),
          reason: '$key must be offered by the questionnaire');
    }
  });

  // #1559 — the eight answers that went nowhere.
  //
  // The page asked for the working day, the hour equivalents and three
  // booking policies, and wrote them ONLY into `<setup>`, which the
  // parser above ignores by design. The import replaces `booking_rules`
  // wholesale with what `<configuration>` carries, so each missing key
  // read as the app's fallback — and a workspace that already had
  // 07:30–19:00 configured got 08:00–17:00 back from a successful
  // import.
  //
  // Nothing caught it, because nothing asked the only question that
  // matters: what does the app END UP WITH. So these tests run the real
  // page (tool/setup/step_harness.mjs --export-xml), parse its real
  // document, and hand `booking_rules` to the very readers the app uses
  // — WorkHours.fromRules and BookingPolicies.fromRules.
  group('the page export carries the working day and the policies', () {
    Map<String, dynamic>? bookingRules(String mode) {
      final node = Process.runSync('node', ['--version']);
      if (node.exitCode != 0) {
        // Node is on every GitHub runner; a developer without it still
        // gets the rest of the suite. Same bargain as setup_runs_test.
        markTestSkipped('node is not on PATH');
        return null;
      }
      final r = Process.runSync(
          'node', ['tool/setup/step_harness.mjs', '--export-xml=$mode']);
      expect(r.exitCode, 0, reason: 'the page failed to export:\n${r.stderr}');
      final data = parseWorkspaceXml(r.stdout as String);
      final configuration = data.configuration;
      expect(configuration, isNotNull,
          reason: 'the questionnaire exported no <configuration> at all');
      final workspace = configuration!['workspace']! as Map<String, Object?>;
      return workspace['booking_rules'] as Map<String, dynamic>?;
    }

    test('the answers arrive — hours, equivalents and policies', () {
      final rules = bookingRules('answered');
      if (rules == null) return;
      // The harness answers 07:30 / 12:30 / 19:00, 4h and 9h.
      final hours = WorkHours.fromRules(rules);
      expect(hours.startMinutes, 7 * 60 + 30);
      expect(hours.halfBoundaryMinutes, 12 * 60 + 30);
      expect(hours.endMinutes, 19 * 60);
      expect(hours.halfDayHours, 4);
      expect(hours.fullDayHours, 9);
      // Not the fallback wearing the answers' clothes.
      expect(hours.startMinutes, isNot(WorkHours.defaults.startMinutes));

      // ...and past bookings on, admin check-out on, two at a time.
      final policies = BookingPolicies.fromRules(rules);
      expect(policies.allowPastBookings, isTrue);
      expect(policies.adminCheckOut, isTrue);
      expect(policies.simultaneousReservations, 2);
      expect(policies.outsideHoursMode, OutsideHoursMode.walkupOnly);
    });

    test('a first visit exports the defaults as values, not as omissions',
        () {
      final rules = bookingRules('defaults');
      if (rules == null) return;
      // The same numbers the app falls back to — but PRESENT, so an
      // import onto a workspace configured otherwise resets it on
      // purpose instead of by accident.
      for (final key in [
        WorkHours.keyStart,
        WorkHours.keyBoundary,
        WorkHours.keyEnd,
        WorkHours.keyHalfDayHours,
        WorkHours.keyFullDayHours,
        BookingPolicies.allowPastBookingsKey,
        BookingPolicies.adminCheckOutKey,
        BookingPolicies.simultaneousReservationsKey,
      ]) {
        expect(rules, contains(key),
            reason: '"$key" is absent, so the import leaves whatever the '
                'target workspace had — an answered question that does '
                'nothing');
      }
      expect(WorkHours.fromRules(rules), WorkHours.defaults);
      final policies = BookingPolicies.fromRules(rules);
      expect(policies.allowPastBookings, isFalse);
      expect(policies.adminCheckOut, isFalse);
      expect(policies.simultaneousReservations,
          BookingPolicies.defaultSimultaneous);
    });

    test('bookingPolicies off exports the off-values, not the answers', () {
      final rules = bookingRules('policies-off');
      if (rules == null) return;
      // Same answers as the first case (past bookings, admin check-out,
      // two at a time) with the feature switched OFF: the export must
      // carry the feature's documented off-behaviour...
      final policies = BookingPolicies.fromRules(rules);
      expect(policies.allowPastBookings, isFalse);
      expect(policies.adminCheckOut, isFalse);
      expect(policies.simultaneousReservations, 1);
      expect(policies.outsideHoursMode, OutsideHoursMode.charged);
      // ...while the working day, which is not that feature's to gate,
      // still travels.
      expect(WorkHours.fromRules(rules).startMinutes, 7 * 60 + 30);
    });
  });
}
