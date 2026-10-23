// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2862 — the configuration PDF says the hours as hh:mm, the VAT rates in
// force and the sites, and the report carries each section only when it
// has something to say.
import 'package:deskilo/core/time/work_hours.dart';
import 'package:deskilo/features/workspace/domain/site.dart';
import 'package:deskilo/features/workspace/domain/workspace_config_report.dart';
import 'package:deskilo/features/workspace/presentation/config_pdf_lines.dart';
import 'package:deskilo/features/workspace/presentation/workspace_configuration_report_strings.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceConfigDocument _doc({
  String hours = '',
  List<String> vat = const [],
  List<String> sites = const [],
}) => WorkspaceConfigDocument(
  strings: workspaceConfigurationStrings(
    lookupAppLocalizations(const Locale('en')),
  ),
  workspaceName: 'Pézenas',
  generatedOnLabel: '',
  countryLabel: 'France',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  granularityLabel: '',
  members: const [],
  featureGroups: const [],
  openDaysLabel: 'Monday',
  closureLabels: const [],
  levels: const [],
  levelPrices: const {},
  hasCustomInvitationTemplate: false,
  workingHoursLabel: hours,
  vatRates: vat,
  sites: sites,
);

List<Object?> _cells(WorkspaceConfigDocument doc) => [
  for (final row
      in workspaceConfigurationReportData(doc)['configuration_rows']!
          as List<Map<String, Object?>>)
    ...row.values,
];

void main() {
  test('the hours read as the two halves of the day, in hh:mm', () {
    expect(
      configWorkingHours(
        const WorkHours(
          startMinutes: 8 * 60,
          halfBoundaryMinutes: 12 * 60 + 30,
          endMinutes: 17 * 60 + 5,
          halfDayHours: 4,
          fullDayHours: 9,
        ),
      ),
      '08:00–12:30 · 12:30–17:05',
    );
  });

  test('a VAT rate reads its label and its percentage in the locale', () {
    expect(configVatRates('fr', [(label: 'Normal', percent: 20.0)]), [
      'Normal — 20 %',
    ]);
    expect(configVatRates('fr', [(label: 'Réduit', percent: 5.5)]), [
      'Réduit — 5,5 %',
    ]);
  });

  test('a site reads its name and its address, without empty parts', () {
    const site = Site(
      id: 's1',
      workspaceId: 'ws-1',
      name: 'Centre',
      street: '4 rue Silène',
      postalCode: '34120',
      city: 'Pézenas',
    );
    expect(configSites([site]), ['Centre — 4 rue Silène, 34120 Pézenas']);
  });

  test('the report carries the hours, the rates and the sites, and no '
      'section that has nothing to say', () {
    final full = _cells(
      _doc(
        hours: '08:00–12:30 · 12:30–17:00',
        vat: const ['Normal — 20 %'],
        sites: const ['Centre'],
      ),
    );
    expect(
      full,
      containsAll([
        'Working hours',
        '08:00–12:30 · 12:30–17:00',
        'VAT rates',
        'Normal — 20 %',
        'Sites',
        'Centre',
      ]),
    );
    final bare = _cells(_doc());
    expect(bare, isNot(contains('Working hours')));
    expect(bare, isNot(contains('VAT rates')));
    expect(bare, isNot(contains('Sites')));
  });
}
