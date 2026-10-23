// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2868 (ADR 0047 §3) — the plain questions the owner answers about the
// space, and the rules that turn the answers into a level per process,
// each with its reason. Data rather than code: the levels screen and
// `web/setup.html` run the same rules (`tool/build_setup_l10n.dart` writes
// them out, and setup_levels_web_test drives the page through every
// answer). Legal obligations are not asked: they come from the tax
// reference data (`setup_obligations.dart`).
import '../../../core/data/json_reader.dart';
import 'setup_levels.dart';

/// The plain questions, in the order they are asked. Each is a fact the
/// owner states about the space (ADR 0047 §3); legal obligations are not
/// asked: they come from the tax reference data (`setup_obligations.dart`).
const List<String> setupQuestions = [
  'association',
  'approve_bookings',
  'members_owe_money',
  'issue_invoices',
  'pay_online',
  'vat_registered',
  'keep_books',
  'tracks_purchases',
  'several_rooms_or_sites',
  'door_tablet',
  'public_page',
  'organised',
];

/// The owner's answer to each of [setupQuestions].
class SetupAnswers {
  const SetupAnswers({
    this.association = false,
    this.approveBookings = false,
    this.membersOweMoney = false,
    this.issueInvoices = false,
    this.payOnline = false,
    this.vatRegistered = false,
    this.keepBooks = false,
    this.tracksPurchases = false,
    this.severalRoomsOrSites = false,
    this.doorTablet = false,
    this.publicPage = false,
    this.organised = false,
  });

  /// The answers as stored (`workspace_setup_journeys.answers`): a
  /// question missing is a no, and one this app does not ask is ignored.
  factory SetupAnswers.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'setup answers');
    bool yes(String q) => r.boolOr(q, fallback: false);
    return SetupAnswers(
      association: yes('association'),
      approveBookings: yes('approve_bookings'),
      membersOweMoney: yes('members_owe_money'),
      issueInvoices: yes('issue_invoices'),
      payOnline: yes('pay_online'),
      vatRegistered: yes('vat_registered'),
      keepBooks: yes('keep_books'),
      tracksPurchases: yes('tracks_purchases'),
      severalRoomsOrSites: yes('several_rooms_or_sites'),
      doorTablet: yes('door_tablet'),
      publicPage: yes('public_page'),
      organised: yes('organised'),
    );
  }

  /// The kind of organisation: an association, a cooperative or a club
  /// rather than a company.
  final bool association;

  /// Whether a booking waits for someone's approval; no means members
  /// book directly.
  final bool approveBookings;
  final bool membersOweMoney;
  final bool issueInvoices;
  final bool payOnline;
  final bool vatRegistered;
  final bool keepBooks;
  final bool tracksPurchases;
  final bool severalRoomsOrSites;
  final bool doorTablet;
  final bool publicPage;

  /// Committees, custom roles and questions, approvals by several people.
  final bool organised;

  /// The answer to [question], one of [setupQuestions].
  bool operator [](String question) => switch (question) {
    'association' => association,
    'approve_bookings' => approveBookings,
    'members_owe_money' => membersOweMoney,
    'issue_invoices' => issueInvoices,
    'pay_online' => payOnline,
    'vat_registered' => vatRegistered,
    'keep_books' => keepBooks,
    'tracks_purchases' => tracksPurchases,
    'several_rooms_or_sites' => severalRoomsOrSites,
    'door_tablet' => doorTablet,
    'public_page' => publicPage,
    'organised' => organised,
    _ => throw ArgumentError.value(question, 'question', 'not asked'),
  };

  /// These answers with [question] answered [yes] or no.
  SetupAnswers withAnswer(String question, {required bool yes}) =>
      SetupAnswers.fromJson({...toJson(), question: yes});

  /// Every question and its answer, as stored.
  Map<String, bool> toJson() => {for (final q in setupQuestions) q: this[q]};

  @override
  bool operator ==(Object other) =>
      other is SetupAnswers && setupQuestions.every((q) => this[q] == other[q]);

  @override
  int get hashCode => Object.hashAll(setupQuestions.map((q) => this[q]));
}

/// One rule of the recommendation: [level] for [reason] when the owner
/// answers yes to any of [anyOf]; a rule without questions always holds.
class SetupRule {
  const SetupRule(this.level, this.reason, {this.anyOf = const {}});

  final String level;

  /// The reason's key, read under `setupReason`.
  final String reason;
  final Set<String> anyOf;

  bool holdsFor(SetupAnswers answers) =>
      anyOf.isEmpty || anyOf.any((q) => answers[q]);
}

/// Each process's rules, the first that holds wins; the last one of each
/// process holds always. Data rather than code, so `web/setup.html` runs
/// the same rules (`tool/build_setup_l10n.dart` writes them out).
const Map<SetupProcess, List<SetupRule>> setupRecommendationRules = {
  SetupProcess.bookings: [
    SetupRule('measured', 'door_tablet', anyOf: {'door_tablet'}),
    SetupRule('resources', 'several_rooms', anyOf: {'several_rooms_or_sites'}),
    SetupRule('simple', 'shared_places'),
  ],
  SetupProcess.community: [
    SetupRule('organised', 'organised', anyOf: {'organised'}),
    // An association has its board (a treasurer, a secretary) and decides
    // together; a booking that waits for approval needs who approves.
    SetupRule('organised', 'association', anyOf: {'association'}),
    SetupRule('organised', 'approve_bookings', anyOf: {'approve_bookings'}),
    SetupRule('basic', 'small_community'),
  ],
  SetupProcess.money: [
    SetupRule(
      'invoices',
      'issues_invoices',
      anyOf: {'issue_invoices', 'vat_registered', 'keep_books'},
    ),
    // Tracking purchases shares their costs on invoices
    // (expenseRepartition).
    SetupRule('invoices', 'tracks_purchases', anyOf: {'tracks_purchases'}),
    SetupRule(
      'statements',
      'members_owe',
      anyOf: {'members_owe_money', 'pay_online'},
    ),
    SetupRule('none', 'no_money'),
  ],
  SetupProcess.payments: [
    SetupRule('online', 'pay_online', anyOf: {'pay_online'}),
    SetupRule('off', 'pay_by_transfer'),
  ],
  SetupProcess.tax: [
    SetupRule('books', 'keeps_books', anyOf: {'keep_books'}),
    SetupRule('vat', 'vat_registered', anyOf: {'vat_registered'}),
    SetupRule('none', 'no_vat'),
  ],
  SetupProcess.purchases: [
    SetupRule('full', 'tracks_purchases', anyOf: {'tracks_purchases'}),
    SetupRule('none', 'no_purchases'),
  ],
  SetupProcess.presentation: [
    SetupRule('public', 'public_page', anyOf: {'public_page'}),
    SetupRule('basic', 'members_only'),
  ],
  SetupProcess.operations: [SetupRule('basic', 'start_simple')],
  SetupProcess.assistant: [SetupRule('off', 'later')],
};

/// One recommended level and the reason it is recommended, by key.
typedef SetupRecommendation = ({String level, String reason});

/// The levels [answers] call for, each with its reason; every process is
/// named, and the result never has a gap ([setupVectorGaps] is empty).
Map<SetupProcess, SetupRecommendation> recommendSetupLevels(
  SetupAnswers answers,
) => {
  for (final MapEntry(key: process, value: rules)
      in setupRecommendationRules.entries)
    process: () {
      final rule = rules.firstWhere((r) => r.holdsFor(answers));
      return (level: rule.level, reason: rule.reason);
    }(),
};
