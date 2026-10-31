// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2379 — Romania's D406 (ANAF, schema Ro_SAFT 2.4.9, pinned under
// test/fixtures/saft/saft_ro/): the OECD tree as ANAF restricts it. Where
// it departs from the writer of saf_t_financial_xml.dart:
//   - the header ends with the declaration's kind and its segment;
//   - every master-file and source-document section is present, empty when
//     the book holds nothing for it;
//   - an account names its national chart account and its function
//     (Activ, Pasiv, Bifunctional) from the profile's map rows;
//   - a party's name and address sit in a CompanyStructure, written only
//     for a party with a registration number;
//   - a transaction and each of its lines name a customer AND a supplier,
//     `0` for the one they do not concern;
//   - every line carries its tax: ANAF's code of its rate for a VAT line,
//     `000`/`000000` with a zero amount for any other.
import '../../../core/time/date_text.dart';
import 'accounting_amount.dart';
import 'book_chart.dart';
import 'posting.dart';
import 'saf_t_financial.dart';
import 'saf_t_financial_facts.dart';
import 'saf_t_financial_xml.dart';

/// ANAF's codes for a line that carries no tax, and for a party a
/// transaction does not concern (the D406 guidance).
const String _noTaxType = '000';
const String _noTaxCode = '000000';
const String _noParty = '0';

/// The declaration's kind: `C`, a file the authority requests for a
/// period, as against the monthly (`L`) or quarterly (`T`) return.
const String _onRequest = 'C';

/// One file, not split into segments.
const String _singleSegment = '1';

/// The share of the base a rate applies to: all of it.
const String _fullBase = '100';

class SafTRomaniaXml extends SafTFinancialXml {
  SafTRomaniaXml(super.r);

  @override
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
            tag('Name', c.name);
            address(c.street, c.city, c.postalCode, c.country);
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
            builder.element(
              'BankAccount',
              nest: () => tag('IBANNumber', r.companyIban),
            );
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
        tag('HeaderComment', _onRequest);
        tag('SegmentIndex', _singleSegment);
        tag('TotalSegmentsInsequence', _singleSegment);
        tag('TaxAccountingBasis', profile.accountingBasis);
      },
    );
  }

  /// A section the schema requires, written empty.
  void empty(String name) => builder.element(name);

  @override
  void masterFiles() {
    builder.element(
      'MasterFiles',
      nest: () {
        builder.element(
          'GeneralLedgerAccounts',
          nest: () => accounts.forEach(account),
        );
        builder.element(
          'Customers',
          nest: () => customers.forEach(
            (n, e) => party('Customer', 'CustomerID', 'member', n, e),
          ),
        );
        builder.element(
          'Suppliers',
          nest: () => suppliers.forEach(
            (n, e) => party('Supplier', 'SupplierID', 'supplier', n, e),
          ),
        );
        taxTable();
        for (final name in const [
          'UOMTable',
          'AnalysisTypeTable',
          'MovementTypeTable',
          'Products',
          'Owners',
          'Assets',
        ]) {
          empty(name);
        }
      },
    );
  }

  /// The account's function on the national chart: its map row's label,
  /// else read from the account's nature.
  String function(String code) {
    final label = standards[code]?.label ?? '';
    if (label.isNotEmpty) return label;
    return switch (r.accountTypes[code]) {
      AccountType.asset || AccountType.expense => 'Activ',
      AccountType.liability ||
      AccountType.equity ||
      AccountType.income => 'Pasiv',
      null => 'Bifunctional',
    };
  }

  @override
  void account(String code) {
    builder.element(
      'Account',
      nest: () {
        tag('AccountID', code);
        tag('AccountDescription', text(accountName(code)));
        if (standards[code] case final standard?) {
          tag('StandardAccountID', standard.account);
        }
        tag('AccountType', function(code));
        balance('Opening', opening(code));
        balance('Closing', closing(code));
      },
    );
  }

  @override
  void party(
    String element,
    String idElement,
    String kind,
    String number,
    ({PostingParty party, Set<String> accounts}) entry,
  ) {
    final details = r.partyDetails[safTPartyKey(kind, number)];
    final a = entry.accounts.single;
    final open = partyNet(r.opening, kind, number, a);
    builder.element(
      element,
      nest: () {
        if (details != null && details.vatId.isNotEmpty) {
          builder.element(
            'CompanyStructure',
            nest: () {
              tag('RegistrationNumber', details.vatId);
              tag('Name', partyName(number, entry.party, details));
              address(
                details.street,
                details.city,
                details.postalCode,
                details.country,
              );
            },
          );
        }
        tag(idElement, number);
        tag('AccountID', a);
        balance('Opening', open);
        balance('Closing', open + partyNet(r.postings, kind, number, a));
      },
    );
  }

  @override
  void taxTable() {
    builder.element(
      'TaxTable',
      nest: () => builder.element(
        'TaxTableEntry',
        nest: () {
          tag('TaxType', profile.taxType);
          tag('Description', profile.taxDescription);
          // Two versions of one rate carry ANAF's one code: written once.
          final written = <String>{};
          for (final c in taxCodes.values) {
            if (!written.add(c.standardCode)) continue;
            builder.element(
              'TaxCodeDetails',
              nest: () {
                tag('TaxCode', c.standardCode);
                tag('EffectiveDate', c.rate.validFrom);
                tag('Description', text(taxDescriptionOf(c)));
                tag('TaxPercentage', taxPercentOf(c));
                tag('BaseRate', _fullBase);
                tag('Country', taxCountry);
              },
            );
          }
        },
      ),
    );
  }

  /// The customer and the supplier [p] concerns, `0` for the other.
  (String, String) partiesOfPosting(Posting p) {
    final party = r.parties[p.documentId];
    if (party == null || party.number.isEmpty) return (_noParty, _noParty);
    return party.kind == 'supplier'
        ? (_noParty, party.number)
        : (party.number, _noParty);
  }

  @override
  void transaction(Posting p) {
    final day = isoDay(p.date);
    final (customer, supplier) = partiesOfPosting(p);
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
        tag('CustomerID', customer);
        tag('SupplierID', supplier);
        for (final l in p.lines) {
          line(p, l);
        }
      },
    );
  }

  int _lineId = 0;

  @override
  void line(Posting p, PostingLine l) {
    _lineId++;
    final debit = l.debit.minor > 0;
    final party = partyOf(p, l);
    final supplierLine = l.role == BookRole.suppliers;
    builder.element(
      'TransactionLine',
      nest: () {
        tag('RecordID', '$_lineId');
        tag('AccountID', l.accountCode);
        tag('SourceDocumentID', p.documentNumber);
        tag(
          'CustomerID',
          party != null && !supplierLine ? party.number : _noParty,
        );
        tag(
          'SupplierID',
          party != null && supplierLine ? party.number : _noParty,
        );
        tag('Description', text([l.role.wire, ?l.qualifier].join(':')));
        money(
          debit ? 'DebitAmount' : 'CreditAmount',
          debit ? l.debit : l.credit,
          l.original,
        );
        if (taxCodeOf(p, l) case final code?) {
          taxInformation(p, l, code);
        } else {
          noTax(l.debit.minor > 0 ? l.debit : l.credit);
        }
      },
    );
  }

  @override
  void taxInformation(Posting p, PostingLine l, SafTTaxCode code) {
    final value = l.debit.minor > 0 ? l.debit : l.credit;
    final base = baseOf(p, l);
    builder.element(
      'TaxInformation',
      nest: () {
        tag('TaxType', profile.taxType);
        tag('TaxCode', code.standardCode);
        tag('TaxPercentage', taxPercentOf(code));
        if (base > 0) tag('TaxBase', amount(base));
        money('TaxAmount', value, l.original);
      },
    );
  }

  /// A line without tax: ANAF's no-tax codes and a zero amount in the
  /// line's own currency.
  void noTax(AccountingAmount of) {
    builder.element(
      'TaxInformation',
      nest: () {
        tag('TaxType', _noTaxType);
        tag('TaxCode', _noTaxCode);
        builder.element(
          'TaxAmount',
          nest: () {
            tag('Amount', amount(0));
            tag('CurrencyCode', of.currency);
            tag('CurrencyAmount', amount(0));
          },
        );
      },
    );
  }

  @override
  void sourceDocuments() {
    builder.element(
      'SourceDocuments',
      nest: () {
        for (final name in const [
          'SalesInvoices',
          'PurchaseInvoices',
          'Payments',
          'MovementOfGoods',
        ]) {
          empty(name);
        }
      },
    );
  }
}
