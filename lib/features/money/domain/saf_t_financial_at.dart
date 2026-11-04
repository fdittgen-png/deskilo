// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2379 — Austria's SAF-T AT 1.01 (Bundesministerium für Finanzen, schema
// pinned under test/fixtures/saft/saft_at/): the OECD 1.0 tree in the BMF's
// namespace. Where it departs from the OECD 2.0 writer of
// saf_t_financial_xml.dart:
//   - the header is the 1.0 header: the company's tax numbers (TaxID), its
//     address with the house number apart (BuildingNumber, required), a
//     contact person and telephone, how the profit is determined
//     (TaxAccountingBasis), the industry code (TaxEntity), the fiscal year,
//     the small-business flag (Kleinunternehmer_AT);
//   - an account (GeneralLedger) names its account of the Austrian
//     standard chart (AccountID_oeEKR) from the profile's map rows, and
//     states its opening balance only;
//   - a party carries its collective account, its number, its name and its
//     address (BillingAddress / Address, with the house number apart);
//   - a ledger line carries a posting text, a plain debit or credit amount
//     and, on a tax line, its Tax.
// A fact the schema requires and the data lacks stops the file, named.
import '../../../core/money/money_text.dart';
import '../../../core/time/date_text.dart';
import 'posting.dart';
import 'saf_t_financial.dart';
import 'saf_t_financial_facts.dart';
import 'saf_t_financial_xml.dart';
import 'saf_t_ledger.dart';

/// A street line split into its street and its house number (`Hauptstraße
/// 12/3`), or null when the line names no number.
({String street, String number})? _austrianStreet(String line) {
  final first = SafTFinancialFacts.streetLine(line).split(',').first.trim();
  final m = RegExp(r'^(.*\S)\s+(\d[\w/\-]*)$').firstMatch(first);
  if (m == null) return null;
  return (street: m.group(1)!, number: m.group(2)!);
}

class SafTAustriaXml extends SafTFinancialXml {
  SafTAustriaXml(super.r);

  @override
  void check() {
    super.check();
    final c = r.company;
    if (r.profitBasis.trim().isEmpty) {
      gap(SafTGapKind.company, 'TaxAccountingBasis');
    }
    if (r.industryCode.trim().isEmpty) gap(SafTGapKind.company, 'TaxEntity');
    if (c.street.trim().isNotEmpty && _austrianStreet(c.street) == null) {
      gap(SafTGapKind.company, 'BuildingNumber');
    }
    for (final (kind, parties) in [
      ('member', customers),
      ('supplier', suppliers),
    ]) {
      for (final e in parties.entries) {
        final d = r.partyDetails[safTPartyKey(kind, e.key)];
        if (d == null ||
            _austrianStreet(d.street) == null ||
            d.city.isEmpty ||
            d.postalCode.isEmpty) {
          gap(SafTGapKind.party, '${e.key} Address');
        }
      }
    }
  }

  void _address(
    String element,
    String street,
    String city,
    String postalCode,
    String country,
  ) {
    final s = _austrianStreet(street)!;
    builder.element(
      element,
      nest: () {
        tag('BuildingNumber', s.number);
        tag('StreetName', s.street);
        tag('City', city);
        tag('PostalCode', postalCode);
        tag('Country', country.toUpperCase());
      },
    );
  }

  @override
  void header() {
    final c = r.company;
    builder.element(
      'Header',
      nest: () {
        builder.element(
          'TaxID',
          nest: () {
            tag('TaxRegistrationNumber', c.legalId);
            if (c.vatId.isNotEmpty) tag('VATNumber', c.vatId);
          },
        );
        tag('CompanyName', c.name);
        _address('CompanyAddress', c.street, c.city, c.postalCode, c.country);
        builder.element(
          'ContactInformation',
          nest: () {
            tag(
              'Contact',
              '${r.contact.firstName} ${r.contact.lastName}'.trim(),
            );
            tag('Telephone', r.contact.phone);
          },
        );
        tag('TaxAccountingBasis', r.profitBasis);
        tag('TaxEntity', r.industryCode);
        tag('FiscalYear', '${r.period.from.year}');
        tag('StartDate', isoDay(r.period.from));
        tag('EndDate', isoDay(r.period.to));
        tag('Kleinunternehmer_AT', r.smallBusiness ? 'true' : 'false');
        tag('CurrencyCode', r.currency);
        tag('AuditFileVersion', profile.version);
        tag('DateCreated', isoDay(r.createdAt));
        tag('ProductID', 'DesKilo');
        tag('ProductVersion', r.softwareVersion);
      },
    );
  }

  @override
  void masterFiles() {
    builder.element(
      'MasterFiles',
      nest: () {
        for (final a in accounts) {
          builder.element(
            'GeneralLedger',
            nest: () {
              final standard = standards[a]!;
              tag('AccountID', a);
              tag('AccountDescription', text(accountName(a)));
              tag('AccountType', accountType(a));
              tag('AccountID_oeEKR', standard.account);
              if (standard.label.isNotEmpty) {
                tag('AccountDescription_oeEKR', standard.label);
              }
              balance('Opening', opening(a));
            },
          );
        }
        for (final (
              element,
              idElement,
              nameElement,
              addressElement,
              kind,
              parties,
            )
            in [
              (
                'Customer',
                'CustomerID',
                'CustomerName',
                'BillingAddress',
                'member',
                customers,
              ),
              (
                'Supplier',
                'SupplierID',
                'SupplierName',
                'Address',
                'supplier',
                suppliers,
              ),
            ]) {
          for (final e in parties.entries) {
            final d = r.partyDetails[safTPartyKey(kind, e.key)]!;
            builder.element(
              element,
              nest: () {
                tag('AccountID', e.value.accounts.single);
                tag(idElement, e.key);
                tag(nameElement, partyName(e.key, e.value.party, d));
                _address(
                  addressElement,
                  d.street,
                  d.city,
                  d.postalCode,
                  d.country,
                );
              },
            );
          }
        }
        if (taxCodes.isNotEmpty) {
          builder.element(
            'TaxTable',
            nest: () {
              tag('TaxType', profile.taxType);
              tag('Description', profile.taxDescription);
              for (final c in taxCodes.values) {
                builder.element(
                  'TaxCodeDetails',
                  nest: () {
                    tag('TaxCode', c.code);
                    tag('Description', taxDescriptionOf(c));
                    tag('TaxPercentage', taxPercentOf(c));
                    tag('EffectiveDate', c.rate.validFrom);
                  },
                );
              }
            },
          );
        }
      },
    );
  }

  @override
  void generalLedger() {
    var debit = 0;
    var credit = 0;
    for (final p in r.postings) {
      for (final l in p.lines) {
        debit += l.debit.minor;
        credit += l.credit.minor;
      }
    }
    var record = 0;
    builder.element(
      'GeneralLedgerEntries',
      nest: () {
        tag('NumberOfEntries', '${r.postings.length}');
        tag('TotalDebit', amount(debit));
        tag('TotalCredit', amount(credit));
        for (final journal in PostingJournal.values) {
          final postings = [
            for (final p in r.postings)
              if (p.journal == journal) p,
          ];
          if (postings.isEmpty) continue;
          builder.element(
            'Journal',
            nest: () {
              tag('JournalID', journal.code);
              tag('Description', safTJournalNames[journal]!);
              tag('Type', journal.code);
              for (final p in postings) {
                final party = r.parties[p.documentId];
                final day = isoDay(p.date);
                builder.element(
                  'Transaction',
                  nest: () {
                    tag('GLPostingDate', day);
                    tag('TransactionDate', day);
                    tag('Period', '${periodOf(p.date)}');
                    tag('TransactionID', transactionIdOf(p));
                    tag(
                      'Description',
                      text('${p.kind.wire} ${p.documentNumber}'),
                    );
                    if (party != null && party.number.isNotEmpty) {
                      tag(
                        party.kind == 'supplier' ? 'SupplierID' : 'CustomerID',
                        party.number,
                      );
                    }
                    for (final l in p.lines) {
                      record++;
                      final isDebit = l.debit.minor > 0;
                      final value = isDebit ? l.debit : l.credit;
                      builder.element(
                        'Line',
                        nest: () {
                          tag('RecordID', '$record');
                          tag('AccountID', l.accountCode);
                          tag(
                            'PostingText',
                            text([l.role.wire, ?l.qualifier].join(':')),
                          );
                          tag('SourceDocumentID', p.documentNumber);
                          tag(
                            isDebit ? 'DebitAmount' : 'CreditAmount',
                            amount(value.minor),
                          );
                          if (taxCodeOf(p, l) case final code?) {
                            builder.element(
                              'Tax',
                              nest: () {
                                tag('TaxType', profile.taxType);
                                tag('TaxCode', code.code);
                                tag('TaxPercentage', taxPercentOf(code));
                                tag('TaxAmount', amount(value.minor));
                              },
                            );
                          }
                          if (l.original case final o?) {
                            builder.element(
                              'Currency',
                              nest: () {
                                tag('CurrencyCode', o.currency);
                                tag(
                                  isDebit
                                      ? 'CurrencyDebitAmount'
                                      : 'CurrencyCreditAmount',
                                  minorToText(o.minor, o.currency),
                                );
                              },
                            );
                          }
                        },
                      );
                    }
                  },
                );
              }
            },
          );
        }
      },
    );
  }
}
