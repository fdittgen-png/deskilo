// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4514 (STK-10) -- a reason of cash put into or taken out of a till drawer, or of a count's difference: a coded record
// of the business (`counter_cash_reasons`, 0999). A built-in reason is named by the app in the reader's language; a
// business's own reason carries the one name it was typed with. The server takes only an active reason of the right
// process, whatever door writes it.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;

/// What a reason serves: cash paid in, cash paid out, a count's difference.
enum CashReasonProcess {
  paidIn('paid_in'),
  paidOut('paid_out'),
  countDifference('count_difference');

  const CashReasonProcess(this.wire);

  /// The value the server keeps.
  final String wire;

  /// The process of a cash entry of [kind] (`paid_in` or `paid_out`, the entry's own wire value).
  static CashReasonProcess ofEntryKind(String kind) => fromWire(kind) ?? paidOut;

  static CashReasonProcess? fromWire(String wire) {
    for (final p in values) {
      if (p.wire == wire) return p;
    }
    return null;
  }
}

/// The reasons every business has (`counter_cash_reasons_builtin()`, 0999), named by the app: their codes, processes and
/// order.
const List<CashReason> kBuiltinCashReasons = [
  CashReason(
    code: 'change',
    builtin: true,
    processes: {CashReasonProcess.paidIn, CashReasonProcess.paidOut},
    position: 10,
  ),
  CashReason(
    code: 'expense',
    builtin: true,
    processes: {CashReasonProcess.paidOut},
    position: 20,
  ),
  CashReason(
    code: 'counting_error',
    builtin: true,
    processes: {CashReasonProcess.countDifference},
    position: 30,
  ),
  CashReason(
    code: 'other',
    builtin: true,
    processes: {
      CashReasonProcess.paidIn,
      CashReasonProcess.paidOut,
      CashReasonProcess.countDifference,
    },
    position: 40,
  ),
];

/// A built-in reason, by its code; [unknown] for any other (a business's own, or a text stored before).
enum BuiltinCashReason {
  change('change'),
  expense('expense'),
  countingError('counting_error'),
  other('other'),
  unknown('');

  const BuiltinCashReason(this.code);

  final String code;

  static BuiltinCashReason of(String code) {
    for (final b in values) {
      if (b != unknown && b.code == code) return b;
    }
    return unknown;
  }
}

/// The fields of a reason's sheet, as its errors are keyed.
enum CashReasonField { name, processes }

/// The code a business's own reason gets from its [name], as the server makes it (0999): lower case, a run of anything
/// but a letter or a digit becomes one underscore.
String cashReasonCodeOf(String name) {
  final code = name
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return code.isEmpty
      ? 'reason'
      : (code.length > 36 ? code.substring(0, 36) : code);
}

/// The longest name a business gives its own reason (`counter_cash_reasons.name`, 0999).
const int kCashReasonNameMaxLength = 60;

class CashReason {
  const CashReason({
    required this.code,
    required this.builtin,
    this.name,
    required this.processes,
    this.archived = false,
    this.position = 0,
  });

  factory CashReason.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'counter_cash_reasons');
    return CashReason(
      code: r.string('code'),
      builtin: r.boolOr('builtin', fallback: false),
      name: r.stringOrNull('name'),
      processes: {
        for (final p in r.strings('processes')) ?CashReasonProcess.fromWire(p),
      },
      archived: r.boolOr('archived', fallback: false),
      position: r.intOrNull('sort_order') ?? 0,
    );
  }

  /// Stable in the business; what the server stores on an entry.
  final String code;

  /// One the app names (change, expense, counting_error, other).
  final bool builtin;

  /// The business's own name; null for a built-in reason.
  final String? name;
  final Set<CashReasonProcess> processes;
  final bool archived;
  final int position;

  /// Whether a person may pick it for [process] now.
  bool offeredFor(CashReasonProcess process) =>
      !archived && processes.contains(process);

  CashReason copyWith({
    String? name,
    Set<CashReasonProcess>? processes,
    bool? archived,
  }) => CashReason(
    code: code,
    builtin: builtin,
    name: name ?? this.name,
    processes: processes ?? this.processes,
    archived: archived ?? this.archived,
    position: position,
  );
}

/// The reasons offered for [process], in the business's order.
List<CashReason> cashReasonsFor(
  Iterable<CashReason> reasons,
  CashReasonProcess process,
) => [
  for (final r in reasons)
    if (r.offeredFor(process)) r,
]..sort((a, b) => a.position.compareTo(b.position));

/// What a business's own reason is refused for, before the server sees it.
enum CashReasonProblem { nameMissing, nameTooLong, processMissing }

/// A reason as written: a name for the business's own one, and at least one process.
Set<CashReasonProblem> checkCashReason({
  required bool builtin,
  required String name,
  required Set<CashReasonProcess> processes,
}) => {
  if (!builtin && name.trim().isEmpty) CashReasonProblem.nameMissing,
  if (!builtin && name.trim().length > kCashReasonNameMaxLength)
    CashReasonProblem.nameTooLong,
  if (processes.isEmpty) CashReasonProblem.processMissing,
};
