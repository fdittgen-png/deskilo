// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2379 — what a SAF-T Financial file needs, gathered from the request and
// checked before anything is written (saf_t_financial.dart).
import '../../../core/money/money_text.dart';
import '../../../core/time/date_text.dart';
import '../../../core/vat/tax_reference.dart';
import '../../../core/vat/tax_reference_active.dart';
import 'book_chart.dart';
import 'posting.dart';
import 'saf_t_financial.dart';

/// The schema's identifier lengths (SAFmiddle1textType / SAFmiddle2textType,
/// the same in the FAIA): a party id and a source document id take 35, an
/// account and a transaction id 70.
const int _shortIdLength = 35;
const int _longIdLength = 70;

/// The schemas' long text (SAFlongtextType): a description is cut to it.
const int _textLength = 256;

/// Norway 1.30's lengths of the fields [SafTFinancialFacts.fits] checks.
const _norwayLengths = {
  'Name': _textLength,
  'StreetName': _textLength,
  'City': _textLength,
  'PostalCode': _longIdLength,
  'Telephone': 18,
  'FirstName': _shortIdLength,
  'LastName': _longIdLength,
  'RegistrationNumber': _shortIdLength,
  'TaxRegistrationNumber': _shortIdLength,
  'StandardCode': _shortIdLength,
  'GroupingCategory': _textLength,
};

/// The FAIA 2.01's, tighter (FAIAmiddle2 70, FAIAmiddle1 35, shorttext 18).
const _faiaLengths = {
  'Name': _longIdLength,
  'StreetName': _longIdLength,
  'City': _shortIdLength,
  'PostalCode': 18,
  'Telephone': 18,
  'FirstName': _shortIdLength,
  'LastName': _longIdLength,
  'RegistrationNumber': _shortIdLength,
  'TaxRegistrationNumber': _shortIdLength,
  'StandardCode': _shortIdLength,
  'GroupingCategory': _shortIdLength,
};

enum SafTTaxDirection { output, input }

/// One tax code of the table: a direction, a rate group and the version of
/// the rate in force.
class SafTTaxCode {
  SafTTaxCode(this.direction, this.group, this.rate);
  final SafTTaxDirection direction;
  final String group;
  final TaxReferenceRow rate;
  String code = '';
  String standardCode = '';

  String get identity => '${direction.name}|$group|${rate.validFrom}';
}

/// What one SAF-T Financial file needs, gathered and checked before any
/// of it is written; every missing fact becomes a [SafTGap].
class SafTFinancialFacts {
  SafTFinancialFacts(this.r);

  final SafTFinancialRequest r;
  final gaps = <SafTGap>[];

  SafTFinancialProfile get profile => r.profile;
  bool get norway => profile == SafTFinancialProfile.norway;

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
  Map<String, SafTTaxCode> taxCodes = const {};

  Map<String, SafTTaxCode> _collectTaxCodes() {
    final found = <String, SafTTaxCode>{};
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

  SafTTaxDirection? directionOf(PostingLine l) => switch (l.role) {
    BookRole.vatOutput => SafTTaxDirection.output,
    BookRole.vatInput => SafTTaxDirection.input,
    _ => null,
  };

  /// The tax code of a tax line [l] of [p]; null for any other line. A tax
  /// line without a rate group, or whose group has no rate on its day, is a
  /// gap.
  SafTTaxCode? _codeOf(Posting p, PostingLine l) {
    final direction = directionOf(l);
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
    return SafTTaxCode(direction, group, rate);
  }

  SafTTaxCode? taxCodeOf(Posting p, PostingLine l) {
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

  int partyNet(
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

  /// The FAIA tree (Luxembourg, and the OECD file read against it) requires
  /// postal addresses and the contact's telephone; Norway does not.
  bool get faiaShape => profile != SafTFinancialProfile.norway;

  /// The schema's length of each party and company field the file writes;
  /// a longer value is refused ([SafTGapKind.tooLong]), never cut.
  int lengthOf(String field) =>
      (faiaShape ? _faiaLengths : _norwayLengths)[field]!;

  void fits(String field, String value) {
    if (value.length > lengthOf(field)) {
      gap(SafTGapKind.tooLong, '$field: $value');
    }
  }

  /// A street as the file writes it: one line.
  static String streetLine(String street) => street.replaceAll('\n', ', ');

  void _address(
    String street,
    String city,
    String postalCode, {
    required void Function() missing,
  }) {
    if (faiaShape && (city.trim().isEmpty || postalCode.trim().isEmpty)) {
      missing();
    }
    fits('StreetName', streetLine(street));
    fits('City', city);
    fits('PostalCode', postalCode);
  }

  void check() {
    final company = r.company;
    if (company.legalId.trim().isEmpty) {
      gap(SafTGapKind.company, 'RegistrationNumber');
    }
    if (company.name.trim().isEmpty) gap(SafTGapKind.company, 'Name');
    // Denmark's company states its VAT registration (or a bank account,
    // which the book does not hold).
    if (profile.denmarkShape && company.vatId.trim().isEmpty) {
      gap(SafTGapKind.company, 'TaxRegistration');
    }
    // The file states the company's own taxes; a seller of another country
    // than the profile's is not the declaration it makes.
    if (profile.country.isNotEmpty && taxCountry != profile.country) {
      gap(SafTGapKind.company, 'Country');
    }
    fits('RegistrationNumber', company.legalId);
    fits('Name', company.name);
    fits('TaxRegistrationNumber', company.vatId);
    _address(
      company.street,
      company.city,
      company.postalCode,
      missing: () => gap(SafTGapKind.company, 'Address'),
    );
    if (r.contact.firstName.trim().isEmpty ||
        r.contact.lastName.trim().isEmpty) {
      gap(SafTGapKind.contact, 'ContactPerson');
    }
    if (faiaShape && r.contact.phone.trim().isEmpty) {
      gap(SafTGapKind.contact, 'Telephone');
    }
    fits('FirstName', r.contact.firstName);
    fits('LastName', r.contact.lastName);
    fits('Telephone', r.contact.phone);
    for (final a in accounts) {
      id(a, _longIdLength);
      if (profile.country.isNotEmpty &&
          profile.standardAccountRequired &&
          standards[a] == null) {
        gap(SafTGapKind.standardAccount, '$a ${accountName(a)}');
      }
      if (standards[a] case final standard?) {
        fits('StandardCode', standard.account);
        if (norway) fits('GroupingCategory', standard.label);
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
        fits('Name', partyName(e.key, e.value.party, details));
        fits('TaxRegistrationNumber', details?.vatId ?? '');
        _address(
          details?.street ?? '',
          details?.city ?? '',
          details?.postalCode ?? '',
          // Denmark's file carries no party address.
          missing: () {
            if (!profile.denmarkShape) {
              gap(SafTGapKind.party, '${e.key} Address');
            }
          },
        );
      }
    }
    for (final p in r.postings) {
      id(transactionIdOf(p), _longIdLength);
      id(p.documentNumber, _shortIdLength);
    }
  }

  /// The name a party is written under: its posted name, the registered
  /// one, its number.
  String partyName(String number, PostingParty party, SafTParty? details) =>
      party.name.isNotEmpty
      ? party.name
      : (details?.name ?? '').isNotEmpty
      ? details!.name
      : number;

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
}
