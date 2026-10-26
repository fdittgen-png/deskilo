// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2379 — SAF-T Financial: the general ledger of a local book as the OECD
// tree, written from the posting engine's entries (`compute_postings`). One
// builder, one tree; each national variant is a [SafTFinancialProfile] that
// fixes the namespace, the version and what the authority requires on top
// (Norway: a grouping code per account and a standard VAT code per tax
// code; Luxembourg: a standard account per account and postal addresses).
//
// What it is: the master files (accounts with their opening and closing
// balance for the fiscal year, customers and suppliers by their sub-ledger
// number, the tax table with its dated rates) and the general ledger
// entries, one transaction per posting, every line naming its source
// document. What it is not: the source documents section, and the entity's
// complete books unless every operation passes through this system — the
// file says so in its own header.
//
// Nothing is invented: a mapping the reference store does not hold, a rate
// it does not know, a company or party field the authority requires and the
// data lacks, or an identifier longer than the schema allows stops the file,
// and each one is named.
import 'package:xml/xml.dart';

import '../../../core/money/money_text.dart';
import '../../../core/text/number_text.dart';
import '../../../core/time/date_text.dart';
import '../../../core/vat/tax_reference.dart';
import '../../../core/vat/tax_reference_active.dart';
import 'accounting_amount.dart';
import 'book_chart.dart';
import 'fiscal_year.dart';
import 'invoice.dart';
import 'posting.dart';
import 'saf_t_ledger.dart';

/// Which SAF-T Financial declaration the file makes about itself.
enum SafTFinancialProfile {
  /// The OECD 2.0 tree, no national restriction: an exchange file.
  oecd(
    formatId: 'saft_oecd_full',
    country: '',
    namespace: 'urn:OECD:StandardAuditFile-Taxation/2.00',
    version: '2.00',
    accountingBasis: 'A',
    taxType: 'VAT',
    taxDescription: 'Value added tax',
  ),

  /// Skatteetaten's SAF-T Financial 1.30 (mandatory from the accounting
  /// period starting 1 January 2025).
  norway(
    formatId: 'saft_no',
    country: 'NO',
    namespace: 'urn:StandardAuditFile-Taxation-Financial:NO',
    version: '1.30',
    // The schema's only value: A, accounting.
    accountingBasis: 'A',
    // The schema's only values.
    taxType: 'MVA',
    taxDescription: 'Merverdiavgift',
  ),

  /// The Administration de l'enregistrement's FAIA 2.01 (the OECD 2.0
  /// tree as Luxembourg publishes it).
  luxembourg(
    formatId: 'faia_lu',
    country: 'LU',
    namespace: 'urn:OECD:StandardAuditFile-Taxation/2.00',
    version: '2.01',
    // One of the schema's documented values.
    accountingBasis: 'Invoice Accounting',
    // The schema's fixed value.
    taxType: 'TVA',
    taxDescription: 'Taxe sur la valeur ajoutée',
  );

  const SafTFinancialProfile({
    required this.formatId,
    required this.country,
    required this.namespace,
    required this.version,
    required this.accountingBasis,
    required this.taxType,
    required this.taxDescription,
  });

  /// The export format this profile writes.
  final String formatId;

  /// The country whose reference rows (`account_map`, `saf_t/…`) map the
  /// chart; empty for the OECD tree, which maps nothing.
  final String country;
  final String namespace;
  final String version;
  final String accountingBasis;
  final String taxType;

  /// The tax table's description of [taxType].
  final String taxDescription;

  static SafTFinancialProfile? ofFormat(String formatId) => [
    for (final p in values)
      if (p.formatId == formatId) p,
  ].firstOrNull;
}

/// The format ids the profiles write.
final Set<String> safTFinancialFormats = {
  for (final p in SafTFinancialProfile.values) p.formatId,
};

/// The person the authority may contact about the file: the one who made it.
class SafTContact {
  const SafTContact({
    required this.firstName,
    required this.lastName,
    this.phone = '',
  });

  final String firstName;
  final String lastName;
  final String phone;
}

/// A customer or a supplier as the master files describe it.
class SafTParty {
  const SafTParty({
    required this.name,
    this.street = '',
    this.city = '',
    this.postalCode = '',
    this.country = '',
    this.vatId = '',
  });

  final String name;
  final String street;
  final String city;
  final String postalCode;
  final String country;
  final String vatId;
}

/// The key of a party in [SafTFinancialRequest.partyDetails].
String safTPartyKey(String kind, String number) => '$kind:$number';

/// What one SAF-T Financial file is built from.
class SafTFinancialRequest {
  const SafTFinancialRequest({
    required this.profile,
    required this.period,
    required this.postings,
    required this.opening,
    required this.accountNames,
    required this.accountTypes,
    required this.parties,
    required this.partyDetails,
    required this.company,
    required this.contact,
    required this.currency,
    required this.softwareVersion,
    required this.createdAt,
    required this.reference,
  });

  final SafTFinancialProfile profile;

  /// The fiscal year the file covers.
  final FiscalYear period;

  /// The year's postings, in the engine's order.
  final List<Posting> postings;

  /// Every posting of the book before [period]: the opening balances.
  final List<Posting> opening;
  final Map<String, String> accountNames;
  final Map<String, AccountType> accountTypes;

  /// The third party of each posted document, by document id.
  final Map<String, PostingParty> parties;

  /// The address and tax number of each party, by [safTPartyKey].
  final Map<String, SafTParty> partyDetails;
  final InvoiceParty company;
  final SafTContact contact;

  /// The book's currency.
  final String currency;
  final String softwareVersion;
  final DateTime createdAt;

  /// The reference store: the rates and the profile's mappings.
  final TaxReferenceSet reference;
}

/// What a missing fact is about.
enum SafTGapKind {
  /// An account the profile's chart map does not cover.
  standardAccount,

  /// A tax code with no standard code of the profile.
  standardTaxCode,

  /// A tax line whose rate group the reference does not know on its day.
  taxRate,

  /// A field of the company the schema requires.
  company,

  /// A field of the contact person the schema requires.
  contact,

  /// A third party without its number, or without a field the profile
  /// requires.
  party,

  /// An identifier longer than the schema allows; it is never cut.
  tooLong,
}

class SafTGap {
  const SafTGap(this.kind, this.subject);
  final SafTGapKind kind;

  /// The account, tax, field, party or value the gap is about.
  final String subject;

  @override
  bool operator ==(Object other) =>
      other is SafTGap && other.kind == kind && other.subject == subject;

  @override
  int get hashCode => Object.hash(kind, subject);

  @override
  String toString() => 'SafTGap(${kind.name}: $subject)';
}

sealed class SafTFinancialResult {
  const SafTFinancialResult();
}

final class SafTFinancialFile extends SafTFinancialResult {
  const SafTFinancialFile(this.xml);
  final String xml;
}

/// Nothing was written; every gap is named.
final class SafTFinancialRefused extends SafTFinancialResult {
  const SafTFinancialRefused(this.gaps);
  final List<SafTGap> gaps;
}

/// The SAF-T Financial file of [request], or why there is none.
SafTFinancialResult buildSafTFinancial(SafTFinancialRequest request) =>
    _SafTFinancialWriter(request).write();

/// The schema's identifier lengths (SAFmiddle1textType / SAFmiddle2textType,
/// the same in the FAIA): a party id and a source document id take 35, an
/// account and a transaction id 70.
const int _shortIdLength = 35;
const int _longIdLength = 70;

/// The schemas' long text (SAFlongtextType): a description is cut to it.
const int _textLength = 256;

/// The share of the base a rate applies to (Norway's `BaseRate`): all of it.
const String _fullBase = '100';

enum _TaxDirection { output, input }

/// One tax code of the table: a direction, a rate group and the version of
/// the rate in force.
class _TaxCode {
  _TaxCode(this.direction, this.group, this.rate);
  final _TaxDirection direction;
  final String group;
  final TaxReferenceRow rate;
  String code = '';
  String standardCode = '';

  String get identity => '${direction.name}|$group|${rate.validFrom}';
}

class _SafTFinancialWriter {
  _SafTFinancialWriter(this.r);

  final SafTFinancialRequest r;
  final gaps = <SafTGap>[];
  final builder = XmlBuilder();

  SafTFinancialProfile get profile => r.profile;
  bool get norway => profile == SafTFinancialProfile.norway;
  bool get luxembourg => profile == SafTFinancialProfile.luxembourg;

  late final TaxReferenceSet rows = r.reference.resolved(isoDay(r.period.to));
  late final String taxCountry = r.company.country.trim().toUpperCase();

  void gap(SafTGapKind kind, String subject) {
    final g = SafTGap(kind, subject);
    if (!gaps.contains(g)) gaps.add(g);
  }

  String amount(int minor) => minorToText(minor, r.currency);

  String text(String value) =>
      value.length <= _textLength ? value : value.substring(0, _textLength);

  /// [value] as an identifier of at most [max] characters, or a gap.
  String id(String value, int max) {
    if (value.length > max) gap(SafTGapKind.tooLong, value);
    return value;
  }

  // ── What the file needs, gathered before anything is written ──────────

  late final List<Posting> all = [...r.opening, ...r.postings];

  /// Every account a posting touches, in code order.
  late final List<String> accounts = {
    for (final p in all)
      for (final l in p.lines) l.accountCode,
  }.toList()..sort();

  int _net(Iterable<Posting> postings, bool Function(PostingLine) where) {
    var net = 0;
    for (final p in postings) {
      for (final l in p.lines) {
        if (where(l)) net += l.debit.minor - l.credit.minor;
      }
    }
    return net;
  }

  int opening(String account) =>
      _net(r.opening, (l) => l.accountCode == account);
  int closing(String account) =>
      opening(account) + _net(r.postings, (l) => l.accountCode == account);

  String accountName(String code) {
    final name = r.accountNames[code] ?? '';
    return name.isEmpty ? code : name;
  }

  /// The profile's map row for [account]: through the roles its lines book,
  /// the qualified role first.
  AccountMapValue? standardOf(String account) {
    final found = <String, AccountMapValue>{};
    for (final p in all) {
      for (final l in p.lines) {
        if (l.accountCode != account) continue;
        final keys = [
          if (l.qualifier case final q? when q.isNotEmpty)
            'saf_t/${l.role.wire}:$q',
          'saf_t/${l.role.wire}',
        ];
        for (final key in keys) {
          final row = rows.lookup(TaxDomain.accountMap, profile.country, key);
          if (row case TaxReferenceRow(:final AccountMapValue value)
              when row.country == profile.country && value.account.isNotEmpty) {
            found['${value.account}|${value.label}'] = value;
            break;
          }
        }
      }
    }
    // Two lines of one account mapped two ways is no mapping either.
    return found.length == 1 ? found.values.single : null;
  }

  late final Map<String, AccountMapValue?> standards = {
    if (profile.country.isNotEmpty)
      for (final a in accounts) a: standardOf(a),
  };

  /// The tax codes of the year's tax lines, numbered in a stable order;
  /// gathered by [check].
  Map<String, _TaxCode> taxCodes = const {};

  Map<String, _TaxCode> _collectTaxCodes() {
    final found = <String, _TaxCode>{};
    for (final p in r.postings) {
      for (final l in p.lines) {
        if (_codeOf(p, l) case final code?) {
          found.putIfAbsent(code.identity, () => code);
        }
      }
    }
    final ordered = found.values.toList()
      ..sort(
        (a, b) => a.direction != b.direction
            ? a.direction.index.compareTo(b.direction.index)
            : a.group != b.group
            ? a.group.compareTo(b.group)
            : a.rate.validFrom.compareTo(b.rate.validFrom),
      );
    for (final (i, c) in ordered.indexed) {
      c.code = '${i + 1}';
      if (norway) {
        final row = rows.lookup(
          TaxDomain.accountMap,
          profile.country,
          'saf_t/tax:${c.direction.name}:${c.group}',
        );
        final standard = row?.country == profile.country
            ? (row?.value as AccountMapValue?)?.taxCode ?? ''
            : '';
        if (standard.isEmpty) {
          gap(SafTGapKind.standardTaxCode, '${c.direction.name}:${c.group}');
        }
        c.standardCode = standard;
      }
    }
    return {for (final c in ordered) c.identity: c};
  }

  _TaxDirection? _direction(PostingLine l) => switch (l.role) {
    BookRole.vatOutput => _TaxDirection.output,
    BookRole.vatInput => _TaxDirection.input,
    _ => null,
  };

  /// The tax code of a tax line [l] of [p]; null for any other line. A tax
  /// line without a rate group, or whose group has no rate on its day, is a
  /// gap.
  _TaxCode? _codeOf(Posting p, PostingLine l) {
    final direction = _direction(l);
    if (direction == null) return null;
    final group = l.qualifier ?? '';
    if (group.isEmpty) {
      gap(SafTGapKind.taxRate, p.documentNumber);
      return null;
    }
    final day = isoDay(p.date);
    final rate = r.reference
        .history(TaxDomain.rate, taxCountry, group)
        .where((row) => row.isInForceOn(day))
        .firstOrNull;
    if (rate == null) {
      gap(SafTGapKind.taxRate, group);
      return null;
    }
    return _TaxCode(direction, group, rate);
  }

  _TaxCode? taxCodeOf(Posting p, PostingLine l) {
    final code = _codeOf(p, l);
    return code == null ? null : taxCodes[code.identity];
  }

  /// The third party of [p] when [l] is a customers or suppliers line.
  PostingParty? partyOf(Posting p, PostingLine l) {
    if (l.role != BookRole.customers && l.role != BookRole.suppliers) {
      return null;
    }
    final party = r.parties[p.documentId];
    if (party == null) {
      gap(SafTGapKind.party, p.documentNumber);
      return null;
    }
    if (party.number.isEmpty) {
      gap(
        SafTGapKind.party,
        party.name.isEmpty ? p.documentNumber : party.name,
      );
      return null;
    }
    id(party.number, _shortIdLength);
    return party;
  }

  /// The parties of [kind] with the collective accounts their lines book
  /// to, by number.
  Map<String, ({PostingParty party, Set<String> accounts})> partiesOf(
    String kind,
  ) {
    final found = <String, ({PostingParty party, Set<String> accounts})>{};
    for (final p in all) {
      for (final l in p.lines) {
        final party = partyOf(p, l);
        if (party == null || party.kind != kind) continue;
        found
            .putIfAbsent(
              party.number,
              () => (party: party, accounts: <String>{}),
            )
            .accounts
            .add(l.accountCode);
      }
    }
    return Map.fromEntries(
      found.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  late final customers = partiesOf('member');
  late final suppliers = partiesOf('supplier');

  int _partyNet(
    Iterable<Posting> postings,
    String kind,
    String number,
    String account,
  ) => _net(
    [
      for (final p in postings)
        if (r.parties[p.documentId]
            case PostingParty(kind: final k, number: final n)
            when k == kind && n == number)
          p,
    ],
    (l) =>
        l.accountCode == account &&
        (l.role == BookRole.customers || l.role == BookRole.suppliers),
  );

  void check() {
    final company = r.company;
    if (company.legalId.trim().isEmpty) {
      gap(SafTGapKind.company, 'RegistrationNumber');
    }
    if (company.name.trim().isEmpty) gap(SafTGapKind.company, 'Name');
    if (r.contact.firstName.trim().isEmpty ||
        r.contact.lastName.trim().isEmpty) {
      gap(SafTGapKind.contact, 'ContactPerson');
    }
    if (luxembourg) {
      if (company.city.trim().isEmpty || company.postalCode.trim().isEmpty) {
        gap(SafTGapKind.company, 'Address');
      }
      if (r.contact.phone.trim().isEmpty) {
        gap(SafTGapKind.contact, 'Telephone');
      }
    }
    for (final a in accounts) {
      id(a, _longIdLength);
      if (profile.country.isNotEmpty && standards[a] == null) {
        gap(SafTGapKind.standardAccount, '$a ${accountName(a)}');
      }
    }
    taxCodes = _collectTaxCodes();
    for (final (kind, parties) in [
      ('member', customers),
      ('supplier', suppliers),
    ]) {
      for (final e in parties.entries) {
        // One AccountID per party outside Norway: a party on two
        // collective accounts has no single balance to state.
        if (!norway && e.value.accounts.length > 1) {
          gap(SafTGapKind.party, '${e.key} AccountID');
        }
        final details = r.partyDetails[safTPartyKey(kind, e.key)];
        if (luxembourg &&
            (details == null ||
                details.city.trim().isEmpty ||
                details.postalCode.trim().isEmpty)) {
          gap(SafTGapKind.party, '${e.key} Address');
        }
      }
    }
    for (final p in r.postings) {
      id(transactionIdOf(p), _longIdLength);
      id(p.documentNumber, _shortIdLength);
    }
  }

  // ── Transaction ids: the journal and the document, `-2` for a second ──

  late final Map<Posting, String> _transactionIds = () {
    final seen = <String, int>{};
    return {
      for (final p in r.postings)
        p: () {
          final base = '${p.journal.code}-${p.documentNumber}';
          final n = seen[base] = (seen[base] ?? 0) + 1;
          return n == 1 ? base : '$base-$n';
        }(),
    };
  }();

  String transactionIdOf(Posting p) => _transactionIds[p]!;

  /// The fiscal year's period of [day]: its month counted from the year's
  /// first month.
  int periodOf(DateTime day) =>
      (day.year - r.period.from.year) * 12 +
      day.month -
      r.period.from.month +
      1;

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
        _partyNet(postings, kind, number, account);
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

  String _taxDescription(_TaxCode c) =>
      '${c.direction == _TaxDirection.output ? 'Output' : 'Input'} '
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
                tag('TaxPercentage', _percent(c));
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

  String _percent(_TaxCode c) =>
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
      if (_direction(l) != null || l.role == BookRole.vatPending) continue;
      base += (l.debit.minor - l.credit.minor).abs();
    }
    return base;
  }

  void taxInformation(Posting p, PostingLine l, _TaxCode code) {
    final debit = l.debit.minor > 0;
    final value = debit ? l.debit : l.credit;
    final base = baseOf(p, l);
    builder.element(
      'TaxInformation',
      nest: () {
        tag('TaxType', profile.taxType);
        tag('TaxCode', code.code);
        tag('TaxPercentage', _percent(code));
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
