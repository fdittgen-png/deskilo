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
}

/// Data for the owner-only configuration snapshot. No financial values
/// or membership permissions are recomputed by rendering a template.
Map<String, Object?> workspaceConfigurationReportData({
  required WorkspaceConfigPdfStrings strings,
  required String workspaceName,
  required String generatedOnLabel,
  required String countryLabel,
  required String currencyCode,
  required String timezone,
  required String granularityLabel,
  required List<ConfigPdfMember> members,
  required List<String> featureLabels,
  required String openDaysLabel,
  required List<String> closureLabels,
  required List<ConfigPdfLevel> levels,

  /// Pre-formatted price per bookable level id ('' = bookable, free).
  /// Absent id = level not bookable as a whole (0050).
  required Map<String, String> levelPrices,

  /// Whether the owner replaced the built-in invitation message (0049).
  required bool hasCustomInvitationTemplate,
}) {
  Map<String, Object?> row(
    String label, [
    String value = '',
    String detail = '',
  ]) => {'label': label, 'value': value, 'detail': detail};
  Map<String, Object?> heading(String label) => {
    ...row(label),
    'heading': true,
  };
  return {
    'workspace': workspaceName,
    'issued': generatedOnLabel,
    'configuration_rows': [
      heading(strings.overview),
      row(strings.country, countryLabel),
      row(strings.currency, currencyCode),
      row(strings.timezone, timezone),
      row(strings.granularity, granularityLabel),
      heading(strings.members),
      {
        ...row(strings.colName, strings.colRole, strings.colStatus),
        'strong': true,
      },
      if (members.isEmpty) row(strings.none),
      for (final member in members) ...[
        row(member.name, member.role, member.status),
        if (member.details.isNotEmpty) row(member.details),
      ],
      heading(strings.features),
      if (featureLabels.isEmpty) row(strings.none),
      for (final feature in featureLabels) row(feature),
      heading(strings.availability),
      row(strings.openDays, openDaysLabel),
      row(strings.closures, closureLabels.isEmpty ? strings.none : ''),
      for (final closure in closureLabels) row(closure),
      heading(strings.invitations),
      row(strings.invitationSingleUse),
      row(
        hasCustomInvitationTemplate
            ? strings.invitationCustomTemplate
            : strings.invitationDefault,
      ),
      heading(strings.floorPlan),
      if (levels.isEmpty) row(strings.emptyLevel),
      for (final entry in levels) ...[
        heading(entry.level.name),
        if (levelPrices.containsKey(entry.level.id))
          row(strings.levelBookable(levelPrices[entry.level.id]!)),
        if (entry.plan.offices.isEmpty) row(strings.emptyLevel),
        for (final office in entry.plan.offices) ...[
          {
            ...row(
              office.name,
              office.bookableAsWhole ? strings.bookableWhole : '',
            ),
            'strong': true,
          },
          for (final desk in entry.plan.desksOf(office.id))
            row(
              desk.name,
              strings.seatsLabel,
              entry.plan.seatsOf(desk.id).isEmpty
                  ? '—'
                  : entry.plan
                        .seatsOf(desk.id)
                        .map((seat) => seat.name)
                        .join(', '),
            ),
        ],
      ],
    ],
  };
}
