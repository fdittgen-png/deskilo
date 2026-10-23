// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../plan/domain/floor_plan.dart';
import '../../plan/domain/level.dart';

/// One member row in the configuration PDF — every string pre-resolved at
/// the call site (the domain layer stays l10n-free, ADR 0007).
typedef ConfigPdfMember = ({
  String name,
  String role,
  String status,

  /// Pre-resolved extras line ('' when none): over-consumption policy,
  /// reservation cap, whole-level right (0041/0044/0050).
  String details,
});

/// One level's plan, paired with its [Level] for the section header.
typedef ConfigPdfLevel = ({Level level, FloorPlan plan});

/// Pre-resolved labels for the workspace-configuration PDF (#…): the owner
/// exports a complete, human-readable snapshot of the workspace — settings,
/// every member and their role, and the whole floor plan — from the
/// owner-only settings screen. All strings arrive resolved so the builder
/// stays pure Dart (ADR 0007/0008, same shape as the money report builders).
class WorkspaceConfigPdfStrings {
  const WorkspaceConfigPdfStrings({
    required this.title,
    required this.overview,
    required this.country,
    required this.currency,
    required this.timezone,
    required this.granularity,
    required this.members,
    required this.colName,
    required this.colRole,
    required this.colStatus,
    required this.features,
    required this.none,
    required this.availability,
    required this.openDays,
    required this.closures,
    required this.floorPlan,
    required this.bookableWhole,
    required this.seatsLabel,
    required this.emptyLevel,
    required this.levelBookable,
    required this.invitations,
    required this.invitationCustomTemplate,
    required this.invitationDefault,
    required this.invitationSingleUse,
    required this.workingHours,
    required this.vatRates,
    required this.sites,
  });

  final String title;
  final String overview;
  final String country;
  final String currency;
  final String timezone;
  final String granularity;
  final String members;
  final String colName;
  final String colRole;
  final String colStatus;
  final String features;
  final String none;
  final String availability;
  final String openDays;
  final String closures;
  final String floorPlan;

  /// Suffix marking an office bookable as a whole room.
  final String bookableWhole;

  /// Prefix of the per-desk seat line, e.g. "Seats".
  final String seatsLabel;

  /// Placeholder for a level with no rooms yet.
  final String emptyLevel;

  /// Level bookable-as-a-whole line, price pre-formatted by the caller
  /// ('' when free), e.g. 'Bookable as a whole — €25.00 / half-day'.
  final String Function(String price) levelBookable;

  /// Invitations section title + its three states (0049/0051).
  final String invitations;
  final String invitationCustomTemplate;
  final String invitationDefault;
  final String invitationSingleUse;

  /// #2862 — the working hours, VAT rates and sites sections' titles.
  final String workingHours;
  final String vatRates;
  final String sites;
}

/// What the owner-only configuration snapshot renders from: the workspace's
/// settings, its members, its features, availability and floor plan, with
/// every string pre-resolved by the call site.
class WorkspaceConfigDocument {
  const WorkspaceConfigDocument({
    required this.strings,
    required this.workspaceName,
    required this.generatedOnLabel,
    required this.countryLabel,
    required this.currencyCode,
    required this.timezone,
    required this.granularityLabel,
    required this.members,
    required this.featureGroups,
    required this.openDaysLabel,
    required this.closureLabels,
    required this.levels,
    required this.levelPrices,
    required this.hasCustomInvitationTemplate,
    this.workingHoursLabel = '',
    this.vatRates = const [],
    this.sites = const [],
    this.readinessTitle = '',
    this.readiness = const [],
  });

  final WorkspaceConfigPdfStrings strings;
  final String workspaceName;
  final String generatedOnLabel;
  final String countryLabel;
  final String currencyCode;
  final String timezone;
  final String granularityLabel;
  final List<ConfigPdfMember> members;
  /// #2862 — the features that are on, grouped by process: one line per
  /// process instead of a page of single names.
  final List<ConfigFeatureGroup> featureGroups;
  final String openDaysLabel;
  final List<String> closureLabels;
  final List<ConfigPdfLevel> levels;

  /// Pre-formatted price per bookable level id ('' = bookable, free).
  /// Absent id = level not bookable as a whole (0050).
  final Map<String, String> levelPrices;

  /// Whether the owner replaced the built-in invitation message (0049).
  final bool hasCustomInvitationTemplate;

  /// #2862 — the day's hours as hh:mm, '' when not shown.
  final String workingHoursLabel;

  /// #2862 — one line per VAT rate in force, and per site.
  final List<String> vatRates;
  final List<String> sites;

  /// #2876 — the readiness report: each milestone, where it stands and
  /// its evidence; empty when the setup guide is off.
  final String readinessTitle;
  final List<ConfigReadinessLine> readiness;
}

/// A milestone of the readiness report, its standing and its evidence.
typedef ConfigReadinessLine = ({String label, String value, String detail});

/// One process and the names of its features that are on.
typedef ConfigFeatureGroup = ({String process, List<String> features});

Map<String, Object?> _row(
  String label, [
  String value = '',
  String detail = '',
]) => {'label': label, 'value': value, 'detail': detail};

Map<String, Object?> _heading(String label) => {
  ..._row(label),
  'heading': true,
};

/// Data for the owner-only configuration snapshot. No financial values
/// or membership permissions are recomputed by rendering a template.
Map<String, Object?> workspaceConfigurationReportData(
  WorkspaceConfigDocument doc,
) {
  final strings = doc.strings;
  return {
    'workspace': doc.workspaceName,
    'issued': doc.generatedOnLabel,
    'configuration_rows': [
      ..._overviewRows(doc),
      ..._memberRows(doc),
      ..._featureRows(doc),
      ..._availabilityRows(doc),
      ..._listRows(strings.vatRates, doc.vatRates),
      ..._listRows(strings.sites, doc.sites),
      ..._invitationRows(doc),
      _heading(strings.floorPlan),
      if (doc.levels.isEmpty) _row(strings.emptyLevel),
      for (final entry in doc.levels) ..._levelRows(doc, entry),
      if (doc.readiness.isNotEmpty) ...[
        _heading(doc.readinessTitle),
        for (final r in doc.readiness) _row(r.label, r.value, r.detail),
      ],
    ],
  };
}

List<Map<String, Object?>> _overviewRows(WorkspaceConfigDocument doc) {
  final strings = doc.strings;
  return [
    _heading(strings.overview),
    _row(strings.country, doc.countryLabel),
    _row(strings.currency, doc.currencyCode),
    _row(strings.timezone, doc.timezone),
    _row(strings.granularity, doc.granularityLabel),
  ];
}

List<Map<String, Object?>> _memberRows(WorkspaceConfigDocument doc) {
  final strings = doc.strings;
  return [
    _heading(strings.members),
    {..._row(strings.colName, strings.colRole, strings.colStatus), 'strong': true},
    if (doc.members.isEmpty) _row(strings.none),
    for (final member in doc.members) ...[
      _row(member.name, member.role, member.status),
      if (member.details.isNotEmpty) _row(member.details),
    ],
  ];
}

List<Map<String, Object?>> _featureRows(WorkspaceConfigDocument doc) {
  final strings = doc.strings;
  return [
    _heading(strings.features),
    if (doc.featureGroups.isEmpty) _row(strings.none),
    for (final group in doc.featureGroups)
      _row(group.process, group.features.join(', ')),
  ];
}

List<Map<String, Object?>> _availabilityRows(WorkspaceConfigDocument doc) {
  final strings = doc.strings;
  return [
    _heading(strings.availability),
    _row(strings.openDays, doc.openDaysLabel),
    if (doc.workingHoursLabel.isNotEmpty)
      _row(strings.workingHours, doc.workingHoursLabel),
    _row(strings.closures, doc.closureLabels.isEmpty ? strings.none : ''),
    for (final closure in doc.closureLabels) _row(closure),
  ];
}

/// A section of one line per item; nothing when there is none.
List<Map<String, Object?>> _listRows(String title, List<String> lines) => [
  if (lines.isNotEmpty) ...[
    _heading(title),
    for (final line in lines) _row(line),
  ],
];

List<Map<String, Object?>> _invitationRows(WorkspaceConfigDocument doc) {
  final strings = doc.strings;
  return [
    _heading(strings.invitations),
    _row(strings.invitationSingleUse),
    _row(
      doc.hasCustomInvitationTemplate
          ? strings.invitationCustomTemplate
          : strings.invitationDefault,
    ),
  ];
}

/// One level: its heading, its price, and every room with its desks.
List<Map<String, Object?>> _levelRows(
  WorkspaceConfigDocument doc,
  ConfigPdfLevel entry,
) {
  final strings = doc.strings;
  return [
    _heading(entry.level.name),
    if (doc.levelPrices.containsKey(entry.level.id))
      _row(strings.levelBookable(doc.levelPrices[entry.level.id]!)),
    if (entry.plan.offices.isEmpty) _row(strings.emptyLevel),
    for (final office in entry.plan.offices) ...[
      {
        ..._row(
          office.name,
          office.bookableAsWhole ? strings.bookableWhole : '',
        ),
        'strong': true,
      },
      for (final desk in entry.plan.desksOf(office.id))
        _row(
          desk.name,
          strings.seatsLabel,
          entry.plan.seatsOf(desk.id).isEmpty
              ? '—'
              : entry.plan.seatsOf(desk.id).map((seat) => seat.name).join(', '),
        ),
    ],
  ];
}
