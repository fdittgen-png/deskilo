// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The UStVA as ELSTER XML: Jahr, Zeitraum (01-12 a month, 41-44 a quarter), the
// Steuernummer and every Kennzahl the form filled, bases in whole euros, tax
// amounts with cents, Kz 83 always. Moved here unchanged from the application
// (#3333); the boxes are the ones the host filled from its tax reference.
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:xml/xml.dart';

/// The ELSTER Zeitraum of [context]: `01`..`12` for a month, `41`..`44` for a
/// quarter; null for anything else (the annual return is another form).
String? elsterPeriod(FilingContext context) {
  final p = monthOrQuarter(context.periodStart, context.periodEnd);
  if (p == null) return null;
  final month = p.month;
  if (month != null) return twoDigits(month);
  return '${41 + (p.quarter! - 1)}';
}

/// The digits of [text].
String digitsOf(String text) => text.replaceAll(RegExp('[^0-9]'), '');

/// The UStVA of [context] as ELSTER XML. [zeitraum] and [taxNumber] are the
/// validated period and Steuernummer.
String elsterUstvaXml(
  FilingContext context, {
  required String zeitraum,
  required String taxNumber,
}) {
  final party = context.party;
  final kz = <String, String>{};
  for (final box in context.boxes) {
    if (box.hasBase && box.baseKey.isNotEmpty) {
      kz[box.baseKey] = (box.netCents ~/ 100).toString();
    }
    if (box.hasTax && box.taxKey.isNotEmpty) {
      kz[box.taxKey] = _euros(box.vatCents);
    }
  }
  final keys = kz.keys.toList()
    ..sort(
      (a, b) => int.parse(a.substring(2)).compareTo(int.parse(b.substring(2))),
    );
  final b = XmlBuilder()..processing('xml', 'version="1.0" encoding="UTF-8"');
  b.element(
    'Elster',
    namespaces: {'http://www.elster.de/elsterxml/schema/v11': null},
    nest: () {
      b.element(
        'TransferHeader',
        attributes: {'version': '11'},
        nest: () {
          b
            ..element('Verfahren', nest: 'ElsterAnmeldung')
            ..element('DatenArt', nest: 'UStVA')
            ..element('Vorgang', nest: 'send-Auth');
        },
      );
      b.element(
        'DatenTeil',
        nest: () {
          b.element(
            'Nutzdatenblock',
            nest: () {
              b.element(
                'NutzdatenHeader',
                attributes: {'version': '11'},
                nest: () {
                  b.element('NutzdatenTicket', nest: '1');
                },
              );
              b.element(
                'Nutzdaten',
                nest: () {
                  b.element(
                    'Anmeldungssteuern',
                    attributes: {
                      'art': 'UStVA',
                      'version': '${context.periodEnd.year}_01',
                    },
                    nest: () {
                      b.element(
                        'DatenLieferant',
                        nest: () {
                          b
                            ..element('Name', nest: party.name)
                            ..element('Strasse', nest: party.street)
                            ..element('PLZ', nest: party.postalCode)
                            ..element('Ort', nest: party.city);
                        },
                      );
                      b.element(
                        'Erstellungsdatum',
                        nest: ymd(context.generatedAt),
                      );
                      b.element(
                        'Steuerfall',
                        nest: () {
                          b.element(
                            'Umsatzsteuervoranmeldung',
                            nest: () {
                              b
                                ..element(
                                  'Jahr',
                                  nest: '${context.periodStart.year}',
                                )
                                ..element('Zeitraum', nest: zeitraum)
                                ..element(
                                  'Steuernummer',
                                  nest: digitsOf(taxNumber),
                                );
                              for (final k in keys) {
                                b.element(k, nest: kz[k]);
                              }
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      );
    },
  );
  return b.buildDocument().toXmlString(pretty: true, indent: '  ');
}

/// Euros with cents and a dot, as ELSTER reads amounts: `-12.05`.
String _euros(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  return '$sign${abs ~/ 100}.${twoDigits(abs % 100)}';
}
