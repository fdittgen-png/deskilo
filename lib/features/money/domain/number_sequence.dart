// SPDX-License-Identifier: 0BSD
//
// #925 — one number series of a workspace: how a journal's documents are
// numbered. The NUMBERS are drawn in the database (`next_document_number`,
// 0164) inside the transaction that issues the document — gapless, O(1),
// and serialised only against writers of the same series. This is the
// owner's view of the format and the counter, never a way to take one.
enum NumberDatePart { none, year, yearMonth }

enum NumberReset { never, yearly, monthly }

class NumberSequence {
  const NumberSequence({
    required this.journal,
    this.prefix = '',
    this.suffix = '',
    this.datePart = NumberDatePart.year,
    this.digits = 4,
    this.reset = NumberReset.yearly,
    this.nextValue = 1,
    this.periodKey = '',
  });

  /// `invoice`, `credit_note`, … — what the series numbers.
  final String journal;
  final String prefix;
  final String suffix;
  final NumberDatePart datePart;

  /// Width of the counter, zero-padded. 1–9.
  final int digits;

  /// When the counter starts again at 1. A reset series is still
  /// gapless within each period.
  final NumberReset reset;

  /// The next number that will be TAKEN. Raised, never lowered.
  final int nextValue;

  /// The period [nextValue] belongs to ('' for a never-resetting series).
  final String periodKey;

  /// The journals every workspace has a series for; the settings screen
  /// lists them side by side so nobody can miss that two share one.
  static const List<String> journals = [
    'invoice',
    'credit_note',
    'vat_declaration',
    'member',
    'payment',
  ];

  /// #928 — what an untouched series looks like, journal by journal;
  /// mirrors `number_sequence_defaults` (0165) and is pinned equal to it
  /// by test. A member number never resets and carries no year.
  static NumberSequence defaultsFor(String journal) => NumberSequence(
    journal: journal,
    prefix: switch (journal) {
      'invoice' => 'INV-',
      'credit_note' => 'CN-',
      'vat_declaration' => 'DECL-',
      'member' => 'M-',
      'payment' => 'PAY-',
      _ => '',
    },
    datePart: journal == 'member' ? NumberDatePart.none : NumberDatePart.year,
    reset: journal == 'member' ? NumberReset.never : NumberReset.yearly,
  );

  static const String keyJournal = 'journal';
  static const String keyPrefix = 'prefix';
  static const String keySuffix = 'suffix';
  static const String keyDatePart = 'date_part';
  static const String keyDigits = 'digits';
  static const String keyReset = 'reset';
  static const String keyNextValue = 'next_value';
  static const String keyPeriodKey = 'period_key';

  factory NumberSequence.fromDb(Map<String, dynamic> row) => NumberSequence(
    journal: row[keyJournal] as String? ?? '',
    prefix: row[keyPrefix] as String? ?? '',
    suffix: row[keySuffix] as String? ?? '',
    datePart: switch (row[keyDatePart] as String? ?? 'year') {
      'none' => NumberDatePart.none,
      'year_month' => NumberDatePart.yearMonth,
      _ => NumberDatePart.year,
    },
    digits: ((row[keyDigits] as num?)?.toInt() ?? 4).clamp(1, 9),
    reset: switch (row[keyReset] as String? ?? 'yearly') {
      'never' => NumberReset.never,
      'monthly' => NumberReset.monthly,
      _ => NumberReset.yearly,
    },
    nextValue: (row[keyNextValue] as num?)?.toInt() ?? 1,
    periodKey: row[keyPeriodKey] as String? ?? '',
  );

  static String datePartWire(NumberDatePart p) => switch (p) {
    NumberDatePart.none => 'none',
    NumberDatePart.year => 'year',
    NumberDatePart.yearMonth => 'year_month',
  };

  static String resetWire(NumberReset r) => switch (r) {
    NumberReset.never => 'never',
    NumberReset.yearly => 'yearly',
    NumberReset.monthly => 'monthly',
  };

  /// What [value] would read, on [at] — mirrors `number_sequence_format`
  /// for the live preview while the owner types; the server's own
  /// preview is the truth once saved.
  String format(int value, DateTime at) {
    final y = at.year.toString().padLeft(4, '0');
    final m = at.month.toString().padLeft(2, '0');
    final date = switch (datePart) {
      NumberDatePart.none => '',
      NumberDatePart.year => '$y-',
      NumberDatePart.yearMonth => '$y-$m-',
    };
    return '$prefix$date${value.toString().padLeft(digits, '0')}$suffix';
  }

  NumberSequence copyWith({
    String? prefix,
    String? suffix,
    NumberDatePart? datePart,
    int? digits,
    NumberReset? reset,
    int? nextValue,
  }) => NumberSequence(
    journal: journal,
    prefix: prefix ?? this.prefix,
    suffix: suffix ?? this.suffix,
    datePart: datePart ?? this.datePart,
    digits: digits ?? this.digits,
    reset: reset ?? this.reset,
    nextValue: nextValue ?? this.nextValue,
    periodKey: periodKey,
  );

  @override
  bool operator ==(Object other) =>
      other is NumberSequence &&
      other.journal == journal &&
      other.prefix == prefix &&
      other.suffix == suffix &&
      other.datePart == datePart &&
      other.digits == digits &&
      other.reset == reset &&
      other.nextValue == nextValue &&
      other.periodKey == periodKey;

  @override
  int get hashCode => Object.hash(
    journal, prefix, suffix, datePart, digits, reset, nextValue, periodKey,
  );
}
