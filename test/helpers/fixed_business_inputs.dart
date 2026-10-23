// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 L4 -- for a rig of real clients over fake servers that is about
// something else than the calendar or the tax reference: the context reads
// them through these fixed readers instead of the servers, so the rig's
// fakes need not answer `workspaces.booking_rules`, `closure_days` and
// `tax_reference_history`. The calendar tests use servers that answer.
import 'package:deskilo/core/instance/data/installation_tax_reference.dart';
import 'package:deskilo/core/time/work_hours.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/workspace/domain/booking_rules_repository.dart';
import 'package:deskilo/features/workspace/domain/closure_day.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/misc.dart';

class _FixedRules implements BookingRulesRepository {
  @override
  Future<List<int>> fetchOpenWeekdays(String workspaceId) async =>
      const [1, 2, 3, 4, 5];

  @override
  Future<WorkHours> fetchWorkHours(String workspaceId) async =>
      WorkHours.defaults;

  @override
  Future<List<ClosureDay>> fetchClosureDays(String workspaceId) async =>
      const [];

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('not a calendar read: ${invocation.memberName}');
}

/// Weekdays, the product's working day, no closures and the tax reference
/// the test runs on.
List<Override> fixedBusinessInputs() => [
      workspaceCalendarReaderProvider.overrideWithValue((_) => _FixedRules()),
      workspaceTaxReferenceReaderProvider.overrideWithValue(
        (_, _) async => ActiveTaxReference.current,
      ),
    ];
