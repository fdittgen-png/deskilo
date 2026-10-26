// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2379 — the XML of a SAF-T Financial file, in the schema's section order:
// the header, the master files and the general ledger entries.
import 'package:xml/xml.dart';

import '../../../core/money/money_text.dart';
import '../../../core/text/number_text.dart';
import '../../../core/time/date_text.dart';
import '../../../core/vat/tax_reference.dart';
import 'accounting_amount.dart';
import 'book_chart.dart';
import 'posting.dart';
import 'saf_t_financial.dart';
import 'saf_t_financial_facts.dart';
import 'saf_t_ledger.dart';

/// The share of the base a rate applies to (Norway's `BaseRate`): all of it.
const String _fullBase = '100';

/// Writes the file once the facts hold; refuses it with every gap otherwise.
class SafTFinancialXml extends SafTFinancialFacts {
  SafTFinancialXml(super.r);

  final builder = XmlBuilder();

  // ── Writing ────────────────────────────────────────────────────────────

  SafTFinancialResult write() {
    check();
    if (gaps.isNotEmpty) return SafTFinancialRefused(List.unmodifiable(gaps));
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'AuditFile',
      nest: () {
        builder.namespace(profile.namespace);
        header();
        masterFiles();
        generalLedger();
      },
    );
    return SafTFinancialFile(
      builder.buildDocument().toXmlString(pretty: true, indent: '  '),
    );
  }

  void tag(String name, String value) =>
      builder.element(name, nest: () => builder.text(value));

  void address(String street, String city, String postalCode, String country) {
    builder.element(
      'Address',
      nest: () {
        if (street.isNotEmpty) {
          tag('StreetName', text(street.replaceAll('\n', ', ')));
        }
        if (city.isNotEmpty) tag('City', city);
        if (postalCode.isNotEmpty) tag('PostalCode', postalCode);
        if (country.isNotEmpty) tag('Country', country.toUpperCase());
      },
    );
  }

  bool hasAddress(String city, String postalCode) =>
      city.isNotEmpty || postalCode.isNotEmpty;

  void taxRegistration(String vatId) {
    if (vatId.isEmpty) return;
    builder.element(
      'TaxRegistration',
      nest: () => tag('TaxRegistrationNumber', vatId),
    );
  }

  void header() {
    final c = r.company;
    builder.element(
      'Header',
      nest: () {
        tag('AuditFileVersion', profile.version);
        tag('AuditFileCountry', taxCountry);
        tag('AuditFileDateCreated', isoDay(r.createdAt));
        tag('SoftwareCompanyName', 'DesKilo');
        tag('SoftwareID', 'DesKilo');
        tag('SoftwareVersion', r.softwareVersion);
        builder.element(
          'Company',
          nest: () {
            tag('RegistrationNumber', c.legalId);
            tag('Name', text(c.name));
            if (hasAddress(c.city, c.postalCode)) {
              address(c.street, c.city, c.postalCode, c.country);
            }
            builder.element(
              'Contact',
              nest: () {
                builder.element(
                  'ContactPerson',
                  nest: () {
                    tag('FirstName', r.contact.firstName);
                    tag('LastName', r.contact.lastName);
                  },
                );
                if (r.contact.phone.isNotEmpty) {
                  tag('Telephone', r.contact.phone);
                }
              },
            );
            taxRegistration(c.vatId);
          },
        );
        tag('DefaultCurrencyCode', r.currency);
        builder.element(
          'SelectionCriteria',
          nest: () {
            tag('SelectionStartDate', isoDay(r.period.from));
            tag('SelectionEndDate', isoDay(r.period.to));
          },
        );
        tag('HeaderComment', _headerComment);
        tag('TaxAccountingBasis', profile.accountingBasis);
      },
    );
  }

  /// What the file is and is not, within the schema's 256 characters.
  static const _headerComment =
      'General ledger of the local book: its posting engine\'s entries on the '
      'book\'s own chart, every journal, each account\'s opening and closing '
      'balance. No source documents. Complete books only if every operation '
      'of the entity passes through this system.';

  void masterFiles() {
    builder.element(
      'MasterFiles',
      nest: () {
        if (accounts.isNotEmpty) {
          builder.element(
            'GeneralLedgerAccounts',
            nest: () => accounts.forEach(account),
          );
        }
        if (customers.isNotEmpty) {
          builder.element(
            'Customers',
            nest: () => customers.forEach(
              (n, e) => party('Customer', 'CustomerID', 'member', n, e),
            ),
          );
        }
        if (suppliers.isNotEmpty) {
          builder.element(
            'Suppliers',
            nest: () => suppliers.forEach(
              (n, e) => party('Supplier', 'SupplierID', 'supplier', n, e),
            ),
          );
        }
        if (taxCodes.isNotEmpty) taxTable();
      },
    );
  }

  void balance(String prefix, int net) {
    tag(
      net >= 0 ? '${prefix}DebitBalance' : '${prefix}CreditBalance',
      amount(net.abs()),
    );
  }

  /// The schema's account type: Norway knows only `GL`; the FAIA reads the
  /// account's nature.
  String accountType(String code) => norway
      ? 'GL'
      : switch (r.accountTypes[code]) {
          AccountType.asset => 'Asset',
          AccountType.liability => 'Liability',
          AccountType.equity => 'Equity',
          AccountType.income => 'Sale',
          AccountType.expense => 'Expense',
          null => 'GL',
        };

  void account(String code) {
    builder.element(
      'Account',
      nest: () {
        tag('AccountID', code);
        tag('AccountDescription', text(accountName(code)));
        final standard = standards[code];
        if (standard != null) {
          if (norway) {
            tag('GroupingCategory', standard.label);
            tag('GroupingCode', standard.account);
          } else {
            tag('StandardAccountID', standard.account);
          }
        }
        tag('AccountType', accountType(code));
        balance('Opening', opening(code));
        balance('Closing', closing(code));
      },
    );
  }

  void party(
    String element,
    String idElement,
    String kind,
    String number,
    ({PostingParty party, Set<String> accounts}) entry,
  ) {
    final details = r.partyDetails[safTPartyKey(kind, number)];
    final name = entry.party.name.isNotEmpty
        ? entry.party.name
        : details?.name ?? number;
    final accounts = entry.accounts.toList()..sort();
    int netOf(Iterable<Posting> postings, String account) =>
        partyNet(postings, kind, number, account);
    builder.element(
      element,
      nest: () {
        tag('Name', text(name.isEmpty ? number : name));
        if (details != null && hasAddress(details.city, details.postalCode)) {
          address(
            details.street,
            details.city,
            details.postalCode,
            details.country,
          );
        }
        taxRegistration(details?.vatId ?? '');
        tag(idElement, number);
        if (norway) {
          for (final a in accounts) {
            builder.element(
              'BalanceAccount',
              nest: () {
                tag('AccountID', a);
                final open = netOf(r.opening, a);
                balance('Opening', open);
                balance('Closing', open + netOf(r.postings, a));
              },
            );
          }
        } else {
          final a = accounts.single;
          tag('AccountID', a);
          final open = netOf(r.opening, a);
          balance('Opening', open);
          balance('Closing', open + netOf(r.postings, a));
        }
      },
    );
  }

  String _taxDescription(SafTTaxCode c) =>
      '${c.direction == SafTTaxDirection.output ? 'Output' : 'Input'} '
      '${(c.rate.value as RateValue).label}';

  void taxTable() {
    builder.element(
      'TaxTable',
      nest: () => builder.element(
        'TaxTableEntry',
        nest: () {
          tag('TaxType', profile.taxType);
          tag('Description', profile.taxDescription);
          for (final c in taxCodes.values) {
            builder.element(
              'TaxCodeDetails',
              nest: () {
                tag('TaxCode', c.code);
                tag('EffectiveDate', c.rate.validFrom);
                if (c.rate.validTo case final to?) {
                  final end = DateTime.parse(to);
                  tag(
                    'ExpirationDate',
                    isoDay(DateTime(end.year, end.month, end.day - 1)),
                  );
                }
                tag('Description', text(_taxDescription(c)));
                tag('TaxPercentage', taxPercentOf(c));
                tag('Country', taxCountry);
                if (norway) {
                  tag('StandardTaxCode', c.standardCode);
                  tag('BaseRate', _fullBase);
                }
              },
            );
          }
        },
      ),
    );
  }

  String taxPercentOf(SafTTaxCode c) =>
      percentText((c.rate.value as RateValue).percent, fractionDigits: 2);

  void generalLedger() {
    final journals = [
      for (final journal in PostingJournal.values)
        (
          journal,
          [
            for (final p in r.postings)
              if (p.journal == journal) p,
          ],
        ),
    ].where((j) => j.$2.isNotEmpty).toList();
    var debit = 0;
    var credit = 0;
    for (final p in r.postings) {
      for (final l in p.lines) {
        debit += l.debit.minor;
        credit += l.credit.minor;
      }
    }
    builder.element(
      'GeneralLedgerEntries',
      nest: () {
        tag('NumberOfEntries', '${r.postings.length}');
        tag('TotalDebit', amount(debit));
        tag('TotalCredit', amount(credit));
        for (final (journal, postings) in journals) {
          builder.element(
            'Journal',
            nest: () {
              tag('JournalID', journal.code);
              tag('Description', safTJournalNames[journal]!);
              tag('Type', journal.code);
              postings.forEach(transaction);
            },
          );
        }
      },
    );
  }

  int _recordId = 0;

  void transaction(Posting p) {
    final party = r.parties[p.documentId];
    final day = isoDay(p.date);
    builder.element(
      'Transaction',
      nest: () {
        tag('TransactionID', transactionIdOf(p));
        tag('Period', '${periodOf(p.date)}');
        tag('PeriodYear', '${r.period.from.year}');
        tag('TransactionDate', day);
        tag('Description', text('${p.kind.wire} ${p.documentNumber}'));
        // Not recorded apart: the schema's guidance is the transaction date.
        tag('SystemEntryDate', day);
        tag('GLPostingDate', day);
        if (party != null && party.number.isNotEmpty) {
          tag(
            party.kind == 'supplier' ? 'SupplierID' : 'CustomerID',
            party.number,
          );
        }
        for (final l in p.lines) {
          line(p, l);
        }
      },
    );
  }

  void money(
    String element,
    AccountingAmount value,
    AccountingAmount? original,
  ) {
    builder.element(
      element,
      nest: () {
        tag('Amount', amount(value.minor));
        if (original != null) {
          tag('CurrencyCode', original.currency);
          tag('CurrencyAmount', minorToText(original.minor, original.currency));
        }
      },
    );
  }

  void line(Posting p, PostingLine l) {
    _recordId++;
    final debit = l.debit.minor > 0;
    final party = partyOf(p, l);
    builder.element(
      'Line',
      nest: () {
        tag('RecordID', '$_recordId');
        tag('AccountID', l.accountCode);
        tag('SourceDocumentID', p.documentNumber);
        if (party != null) {
          tag(
            l.role == BookRole.suppliers ? 'SupplierID' : 'CustomerID',
            party.number,
          );
        }
        tag('Description', text([l.role.wire, ?l.qualifier].join(':')));
        money(
          debit ? 'DebitAmount' : 'CreditAmount',
          debit ? l.debit : l.credit,
          l.original,
        );
        if (taxCodeOf(p, l) case final code?) taxInformation(p, l, code);
      },
    );
  }

  /// The base a tax line taxes: the posting's lines of the same rate group
  /// that are neither tax nor a settlement.
  int baseOf(Posting p, PostingLine tax) {
    var base = 0;
    for (final l in p.lines) {
      if (identical(l, tax) || l.qualifier != tax.qualifier) continue;
      if (directionOf(l) != null || l.role == BookRole.vatPending) continue;
      base += (l.debit.minor - l.credit.minor).abs();
    }
    return base;
  }

  void taxInformation(Posting p, PostingLine l, SafTTaxCode code) {
    final debit = l.debit.minor > 0;
    final value = debit ? l.debit : l.credit;
    final base = baseOf(p, l);
    builder.element(
      'TaxInformation',
      nest: () {
        tag('TaxType', profile.taxType);
        tag('TaxCode', code.code);
        tag('TaxPercentage', taxPercentOf(code));
        if (norway) tag('Country', taxCountry);
        if (base > 0) tag('TaxBase', amount(base));
        money(
          norway ? (debit ? 'DebitTaxAmount' : 'CreditTaxAmount') : 'TaxAmount',
          value,
          l.original,
        );
      },
    );
  }
}
