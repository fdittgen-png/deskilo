// SPDX-License-Identifier: AGPL-3.0-or-later


import 'package:flutter/material.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/booking_policies.dart';
import '../widgets/availability_tiles.dart';
import '../widgets/legend_profile_tile.dart';
import 'availability_actions.dart';

/// The booking-behaviour matrix (#600, #628, #634, #649).
class AvailabilityPolicies extends StatelessWidget {
  const AvailabilityPolicies({
    super.key,
    required this.actions,
    required this.policies,
  });

  final AvailabilityActions actions;
  final BookingPolicies policies;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ..._switches(context, l10n),
        ..._outsideHours(context, l10n),
        ..._limits(context, l10n),
      ],
    );
  }

  /// The two on/off policies (#600).
  List<Widget> _switches(BuildContext context, AppLocalizations l10n) => [
    Row(
      children: [
        Flexible(child: SectionHeader(l10n.availabilityPoliciesTitle)),
        HelpDot(
          l10n.helpTopicBookingPolicies,
          anchor: HelpAnchor.availabilityPolicies,
        ),
      ],
    ),
    SwitchListTile(
      key: const Key('policy-allow-past'),
      title: HelpDotTitle(
        l10n.policyAllowPastTitle,
        l10n.helpTopicBookingPolicies,
        anchor: HelpAnchor.availabilityAllowPast,
      ),
      subtitle: Text(l10n.policyAllowPastDesc),
      value: policies.allowPastBookings,
      onChanged: (v) =>
          actions.setPolicy(BookingPolicies.allowPastBookingsKey, enabled: v),
    ),
    SwitchListTile(
      key: const Key('policy-admin-checkout'),
      title: HelpDotTitle(
        l10n.policyAdminCheckoutTitle,
        l10n.helpTopicBookingPolicies,
        anchor: HelpAnchor.availabilityAdminCheckout,
      ),
      subtitle: Text(l10n.policyAdminCheckoutDesc),
      value: policies.adminCheckOut,
      onChanged: (v) =>
          actions.setPolicy(BookingPolicies.adminCheckOutKey, enabled: v),
    ),
  ];

  /// The outside-hours answer (#634) and the simultaneous bookings (#628).
  List<Widget> _outsideHours(BuildContext context, AppLocalizations l10n) => [
    // #634 — ONE question, four mutually exclusive answers
    // (#600's grid switch folded in). Radio rows, not a
    // four-way SegmentedButton: four labels do not fit a
    // 360dp phone.
    LegendProfileTile(policies: policies),
    ListTile(
      title: HelpDotTitle(
        l10n.policyOutsideHoursTitle,
        l10n.helpTopicBookingPolicies,
        anchor: HelpAnchor.availabilityOutsideHours,
      ),
      subtitle: Text(l10n.policyOutsideHoursDesc),
    ),
    RadioGroup<OutsideHoursMode>(
      key: const Key('policy-outside-hours'),
      groupValue: policies.outsideHoursMode,
      onChanged: actions.setOutsideHoursMode,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<OutsideHoursMode>(
            key: const Key('policy-outside-hours-off'),
            value: OutsideHoursMode.off,
            title: Text(l10n.policyOutsideHoursOff),
            subtitle: Text(l10n.policyOutsideHoursOffDesc),
          ),
          RadioListTile<OutsideHoursMode>(
            key: const Key('policy-outside-hours-walkup'),
            value: OutsideHoursMode.walkupOnly,
            title: Text(l10n.policyOutsideHoursWalkUp),
            subtitle: Text(l10n.policyOutsideHoursWalkUpDesc),
          ),
          RadioListTile<OutsideHoursMode>(
            key: const Key('policy-outside-hours-free'),
            value: OutsideHoursMode.free,
            title: Text(l10n.policyOutsideHoursFree),
            subtitle: Text(l10n.policyOutsideHoursFreeDesc),
          ),
          RadioListTile<OutsideHoursMode>(
            key: const Key('policy-outside-hours-charged'),
            value: OutsideHoursMode.charged,
            title: Text(l10n.policyOutsideHoursCharged),
            subtitle: Text(l10n.policyOutsideHoursChargedDesc),
          ),
        ],
      ),
    ),
    // #628 — how many overlapping bookings a member may hold.
    SimultaneousTile(
      key: const ValueKey('availability-simultaneous-tile'),
      value: policies.simultaneousReservations,
      onChanged: actions.setSimultaneous,
    ),
  ];

  /// The three numeric limits (#649).
  List<Widget> _limits(BuildContext context, AppLocalizations l10n) => [
    // #649 — the three numeric limits the server has enforced
    // since 0006 but nothing could set. Shown with the values
    // the server coalesces to, so an untouched workspace
    // displays what it actually does.
    Row(
      children: [
        Flexible(child: SectionHeader(l10n.policyLimitsTitle)),
        HelpDot(
          l10n.helpTopicBookingLimits,
          anchor: HelpAnchor.availabilityLimits,
        ),
      ],
    ),
    Padding(
      padding: AppSpacing.lgH,
      child: Text(
        l10n.policyLimitsDesc,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ),
    LimitTile(
      key: const ValueKey('availability-policy-horizon-title'),
      keySuffix: 'horizon',
      icon: Icons.event_available_outlined,
      title: l10n.policyHorizonTitle,
      description: l10n.policyHorizonDesc,
      value: policies.advanceHorizonDays,
      options: horizonOptions,
      format: l10n.policyDaysValue,
      onChanged: (v) =>
          actions.setLimit(BookingPolicies.advanceHorizonDaysKey, v),
    ),
    LimitTile(
      key: const ValueKey('availability-policy-min-duration-title'),
      keySuffix: 'min-duration',
      icon: Icons.hourglass_bottom_outlined,
      title: l10n.policyMinDurationTitle,
      description: l10n.policyMinDurationDesc,
      value: policies.minDurationMinutes,
      options: durationOptions,
      format: (v) => formatDuration(l10n, v),
      onChanged: (v) =>
          actions.setLimit(BookingPolicies.minDurationMinutesKey, v),
    ),
    LimitTile(
      key: const ValueKey('availability-policy-max-duration-title'),
      keySuffix: 'max-duration',
      icon: Icons.hourglass_top_outlined,
      title: l10n.policyMaxDurationTitle,
      description: l10n.policyMaxDurationDesc,
      value: policies.maxDurationMinutes,
      options: durationOptions,
      format: (v) => formatDuration(l10n, v),
      onChanged: (v) =>
          actions.setLimit(BookingPolicies.maxDurationMinutesKey, v),
    ),
    // A minimum above the maximum refuses EVERY booking, and
    // the server compares each bound on its own, so it would
    // never complain — say so here instead.
    if (!policies.durationsAreCoherent)
      Padding(
        padding: AppSpacing.lgH,
        child: Text(
          l10n.policyDurationConflict,
          key: const Key('policy-duration-conflict'),
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.error),
        ),
      ),
  ];
}
