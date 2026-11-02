// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2379 — JPK_KR_PD(1) v1-1 for the supplied frozen posting ledger and
// explicit supplementary Polish facts. It does not assert complete books
// or acceptance by the authority.
import 'package:xml/xml.dart';

import '../../../core/time/date_text.dart';
import 'jpk_kr_pd_validation.dart';
import 'posting.dart';

const _jpkNamespace = 'http://jpk.mf.gov.pl/wzor/2024/09/04/09041/';
const _entityNamespace =
    'http://crd.gov.pl/xml/schematy/dziedzinowe/mf/2022/01/05/eD/DefinicjeTypy/';

sealed class JpkKrPdResult {
  const JpkKrPdResult();
}

final class JpkKrPdFile extends JpkKrPdResult {
  const JpkKrPdFile(this.xml);
  final String xml;
}

final class JpkKrPdRefused extends JpkKrPdResult {
  const JpkKrPdRefused(this.gaps);
  final List<String> gaps;
}

/// Writes only after all supported mandatory facts have passed validation.
JpkKrPdResult buildJpkKrPd(JpkKrPdRequest r) {
  final gaps = jpkKrPdGaps(r);
  if (gaps.isNotEmpty) return JpkKrPdRefused(gaps);
  final facts = r.facts!;
  final b = XmlBuilder();
  void tag(String name, Object value, {String? namespace}) =>
      b.element(name, namespace: namespace, nest: () => b.text('$value'));
  String money(BigInt minor) {
    final n = minor.abs();
    return '${minor.isNegative ? '-' : ''}${n ~/ BigInt.from(100)}.${(n % BigInt.from(100)).toString().padLeft(2, '0')}';
  }

  BigInt total(Iterable<Posting> ps, String account, {required bool debit}) {
    var sum = BigInt.zero;
    for (final p in ps) {
      for (final line in p.lines) {
        if (line.accountCode == account) {
          sum += BigInt.from(debit ? line.debit.minor : line.credit.minor);
        }
      }
    }
    return sum;
  }

  final accounts = {
    ...r.accountNames.keys,
    for (final p in [...r.opening, ...r.postings])
      for (final l in p.lines) l.accountCode,
  }.toList()..sort();
  var journalTotal = BigInt.zero;
  var debitTotal = BigInt.zero;
  var creditTotal = BigInt.zero;
  var lines = 0;
  b.processing('xml', 'version="1.0" encoding="UTF-8"');
  b.element(
    'JPK',
    nest: () {
      b
        ..namespace(_jpkNamespace)
        ..namespace(_entityNamespace, 'etd');
      b.element(
        'Naglowek',
        nest: () {
          b.element(
            'KodFormularza',
            attributes: {
              'kodSystemowy': 'JPK_KR_PD (1)',
              'wersjaSchemy': '1-1',
            },
            nest: () => b.text('JPK_KR_PD'),
          );
          tag('WariantFormularza', 1);
          tag('CelZlozenia', facts.submissionPurpose);
          tag('DataWytworzeniaJPK', r.createdAt.toUtc().toIso8601String());
          tag('DataOd', isoDay(r.period.from));
          tag('DataDo', isoDay(r.period.to));
          tag('RokDataOd', isoDay(r.period.from));
          tag('RokDataDo', isoDay(r.period.to));
          if (facts.taxYear != r.period) {
            tag('RokPdDataOd', isoDay(facts.taxYear.from));
            tag('RokPdDataDo', isoDay(facts.taxYear.to));
          }
          tag('DomyslnyKodWaluty', 'PLN');
          tag('KodUrzedu', facts.taxOfficeCode);
        },
      );
      b.element(
        'Podmiot1',
        nest: () {
          b.element(
            'IdentyfikatorPodmiotu',
            nest: () {
              tag('NIP', facts.nip, namespace: _entityNamespace);
              tag('PelnaNazwa', facts.legalName, namespace: _entityNamespace);
            },
          );
          b.element(
            'Adres',
            nest: () => b.element(
              'AdresPol',
              nest: () {
                tag(
                  'KodKraju',
                  facts.addressCountry,
                  namespace: _entityNamespace,
                );
                tag(
                  'Wojewodztwo',
                  facts.voivodeship,
                  namespace: _entityNamespace,
                );
                tag('Powiat', facts.county, namespace: _entityNamespace);
                tag('Gmina', facts.municipality, namespace: _entityNamespace);
                if (facts.street.isNotEmpty) {
                  tag('Ulica', facts.street, namespace: _entityNamespace);
                }
                tag(
                  'NrDomu',
                  facts.buildingNumber,
                  namespace: _entityNamespace,
                );
                tag('Miejscowosc', facts.city, namespace: _entityNamespace);
                tag(
                  'KodPocztowy',
                  facts.postalCode,
                  namespace: _entityNamespace,
                );
              },
            ),
          );
        },
      );
      for (final party in facts.counterparties) {
        b.element(
          'Kontrahent',
          nest: () {
            tag('T_1', party.code);
            if (party.country != null) tag('T_2', party.country!);
            if (party.taxId != null) tag('T_3', party.taxId!);
          },
        );
      }
      b.element(
        'ZOiS',
        nest: () {
          for (final account in accounts) {
            final detail = facts.accountFacts[account]!;
            final debit = total(r.postings, account, debit: true);
            final credit = total(r.postings, account, debit: false);
            b.element(
              'ZOiS7',
              nest: () {
                tag('S_1', account);
                tag('S_2', r.accountNames[account]!);
                tag('S_3', facts.accountFacts[account]!.parent);
                tag('S_4', money(BigInt.from(detail.openingDebit.minor)));
                tag('S_5', money(BigInt.from(detail.openingCredit.minor)));
                tag('S_6', money(debit));
                tag('S_7', money(credit));
                tag('S_8', money(debit));
                tag('S_9', money(credit));
                tag('S_10', money(BigInt.from(detail.closingDebit.minor)));
                tag('S_11', money(BigInt.from(detail.closingCredit.minor)));
                tag('S_12_1', facts.accountFacts[account]!.reportingMarker);
              },
            );
          }
        },
      );
      for (var i = 0; i < r.postings.length; i++) {
        final p = r.postings[i];
        final entry = facts.entries[i];
        final documentAmount = BigInt.from(entry.documentAmount.minor);
        journalTotal += documentAmount;
        b.element(
          'Dziennik',
          nest: () {
            tag('D_1', entry.journalNumber);
            tag('D_2', entry.journalName);
            if (entry.counterpartyCode != null) {
              tag('D_3', entry.counterpartyCode!);
            }
            tag('D_4', p.documentNumber);
            tag('D_5', entry.documentType);
            tag('D_6', isoDay(entry.eventDate));
            tag('D_7', isoDay(entry.documentDate));
            tag('D_8', isoDay(entry.bookingDate));
            tag('D_9', entry.responsiblePerson);
            tag('D_10', entry.description);
            tag('D_11', money(documentAmount));
            if (entry.ksefNumber != null && entry.ksefNumber!.isNotEmpty) {
              tag('D_12', entry.ksefNumber!);
            }
            for (var j = 0; j < p.lines.length; j++) {
              final line = p.lines[j];
              lines++;
              debitTotal += BigInt.from(line.debit.minor);
              creditTotal += BigInt.from(line.credit.minor);
              b.element(
                'KontoZapis',
                nest: () {
                  tag('Z_1', entry.lineNumbers[j]);
                  tag('Z_2', entry.lineDescriptions[j]);
                  tag('Z_3', line.accountCode);
                  if (line.debit.minor != 0) {
                    tag('Z_4', money(BigInt.from(line.debit.minor)));
                  } else {
                    tag('Z_7', money(BigInt.from(line.credit.minor)));
                  }
                },
              );
            }
          },
        );
      }
      b
        ..element(
          'Ctrl',
          nest: () {
            tag('C_1', r.postings.length);
            tag('C_2', money(journalTotal));
            tag('C_3', lines);
            tag('C_4', money(debitTotal));
            tag('C_5', money(creditTotal));
          },
        )
        ..element(
          'RPD',
          nest: () {
            for (var i = 0; i < 8; i++) {
              tag(
                'K_${i + 1}',
                money(BigInt.from(facts.incomeTaxAdjustments[i].minor)),
              );
            }
          },
        );
    },
  );
  return JpkKrPdFile(b.buildDocument().toXmlString(pretty: true, indent: '  '));
}
