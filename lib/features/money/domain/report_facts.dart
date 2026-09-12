// SPDX-License-Identifier: 0BSD
//
// #1061 slice two — what a document builder used to READ from a
// `WidgetRef`, as a value. The builders take these and a
// `ReportStrings`, nothing else: pure functions of their inputs, so a
// test hands them facts and a CLI could too. The gatherers that fill
// them from the providers live in presentation/report_facts_of.dart.
import '../../../core/time/work_hours.dart';
import '../../events/domain/workspace_event.dart';
import '../../plan/domain/accessory.dart';
import '../../plan/domain/desk.dart';
import '../../plan/domain/floor_plan.dart';
import '../../plan/domain/level.dart';
import '../../plan/domain/office.dart';
import '../../workspace/domain/member.dart';
import '../../workspace/domain/workspace.dart';
import 'fee_band.dart';
import 'ledger_entry.dart';
import 'package.dart';
import 'payment_terms.dart';
import 'service_item.dart';
import 'statement.dart';

/// The financial agreement (#494): every standing price of the space.
class AgreementFacts {
  const AgreementFacts({
    required this.now,
    this.workspace,
    this.bands = const [],
    this.services = const [],
    this.packages = const [],
    this.levels = const [],
    this.offices = const [],
    this.desks = const [],
    this.accessories = const [],
    this.association = false,
  });

  final DateTime now;
  final Workspace? workspace;
  final List<FeeBand> bands;
  final List<ServiceItem> services;

  /// Active packages only — the gatherer filters.
  final List<Package> packages;
  final List<Level> levels;
  final List<Office> offices;
  final List<Desk> desks;
  final List<Accessory> accessories;
  final bool association;
}

/// The monthly payments sheet (#494): what the member paid or declared.
class PaymentsFacts {
  const PaymentsFacts({
    required this.now,
    this.workspace,
    this.me,
    this.ledger = const [],
    this.events = const [],
    this.statement,
  });

  final DateTime now;
  final Workspace? workspace;
  final Member? me;

  /// The member's whole ledger; the builder keeps the period's credits.
  final List<LedgerEntry> ledger;

  /// Every event; the builder keeps the member's pending payments and
  /// expense submissions of the period.
  final List<WorkspaceEvent> events;
  final Statement? statement;
}

/// The workspace report (#494): identity, counts, availability, prices.
class WorkspaceFacts {
  const WorkspaceFacts({
    required this.now,
    this.workspace,
    this.association = false,
    this.levels = const [],
    this.plans = const [],
    this.featureLabels = const [],
    this.membersCount = 0,
    this.bands = const [],
    this.services = const [],
    this.openDays = const [],
    this.hours = WorkHours.defaults,
  });

  final DateTime now;
  final Workspace? workspace;
  final bool association;
  final List<Level> levels;
  final List<FloorPlan> plans;

  /// The enabled features by their DISPLAY name — the Features screen
  /// owns those words (`featureName`); a document lists them.
  final List<String> featureLabels;
  final int membersCount;
  final List<FeeBand> bands;
  final List<ServiceItem> services;
  final List<int> openDays;
  final WorkHours hours;
}

/// A reminder letter (#472/#474).
class ReminderFacts {
  const ReminderFacts({required this.now, this.workspace, this.memberTerms});

  final DateTime now;
  final Workspace? workspace;
  final PaymentTerms? memberTerms;
}
