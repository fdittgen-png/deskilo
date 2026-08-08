// SPDX-License-Identifier: 0BSD
//
// The setup questionnaire (web/setup.html) generates a schema-v2
// deskilo-workspace document with an extra `<setup>` extension block.
// This test pins the CONTRACT: the app's parser accepts exactly what
// the page emits — settings, accessory catalog and auto-laid-out floor
// plan parse; the <setup> block is ignored, never fatal.
import 'dart:io';

import 'package:deskilo/features/workspace/domain/workspace_xml.dart';
import 'package:flutter_test/flutter_test.dart';

/// A document shaped exactly like web/setup.html's exportXml() output:
/// 1 level, 1 office, 1 desk with 4 seats (2 columns × 2 rows, seat
/// footprint 6×4), one accessory, features, payment instructions, and
/// the full `<setup>` extension.
const _pageOutput = '''
<?xml version="1.0" encoding="UTF-8"?>
<deskilo-workspace version="2">
  <settings name="pezenas1" country="FR" currency="EUR" timezone="Europe/Paris">
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
    expect(page, contains('deskilo-workspace version="2"'));
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
}
