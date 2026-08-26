// SPDX-License-Identifier: 0BSD
//
// The reusable rows of the Availability screen, lifted out when that
// screen outgrew its length budget (#649). Each one is a presentation
// detail of a single setting — a work-hours time, one of the three
// numeric booking limits, the simultaneous-reservations stepper, an
// hour count, a section header — so they belong together and nowhere
// else. They stay dumb: a value in, a callback out; every write goes
// through the screen.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/booking_policies.dart';

class WorkTimeTile extends StatelessWidget {
  const WorkTimeTile({
    super.key,
    required this.keySuffix,
    required this.title,
    required this.minutes,
    required this.onTap,
  });

  final String keySuffix;
  final String title;
  final int minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        key: ValueKey('work-hours-$keySuffix'),
        leading: const Icon(Icons.schedule_outlined),
        title: Text(title),
        trailing: Text(
          MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        onTap: onTap,
      );
}

/// Whole-hour count picker (1-16) for the half/full-day billing
/// equivalents under the hours granularity.
/// #628 — the workspace default for simultaneous reservations, 1..20.
/// 1 is the historical one-place-at-a-time (#412); a per-member
/// permission on the Members screen may raise it for individuals.
/// #649 — the horizon choices, in the granularity an owner actually
/// thinks in: a week, a fortnight, a month, a quarter, half a year, a
/// year, two. Bounded by BookingPolicies.minHorizonDays/maxHorizonDays.
const horizonOptions = <int>[7, 14, 30, 60, 90, 120, 180, 365, 730];

/// The duration choices, in minutes, from the 5-minute floor to a full
/// day — the ceiling, because a booking ends on the day it starts (#644).
const durationOptions = <int>[
  5, 10, 15, 30, 45, 60, 90, 120, 180, 240, 300, 360, 480, 600, 720, 1440,
];

/// Minutes read as hours once they divide evenly and reach one hour —
/// "4 hours" beats "240 minutes" on a settings row.
String formatDuration(AppLocalizations? l10n, int minutes) {
  if (minutes >= 60 && minutes % 60 == 0) {
    final hours = minutes ~/ 60;
    return l10n?.policyHoursValue(hours) ?? '$hours h';
  }
  return l10n?.policyMinutesValue(minutes) ?? '$minutes min';
}

/// One numeric booking limit as a dropdown of sensible values. A value
/// stored outside the list (hand-written into booking_rules, or a bound
/// this build does not offer) is added to its own copy of the options so
/// the dropdown can render it instead of asserting.
class LimitTile extends StatelessWidget {
  const LimitTile({
    super.key,
    required this.keySuffix,
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.options,
    required this.format,
    required this.onChanged,
  });

  final String keySuffix;
  final IconData icon;
  final String title;
  final String description;
  final int value;
  final List<int> options;
  final String Function(int) format;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = options.contains(value)
        ? options
        : (<int>[...options, value]..sort());
    return ListTile(
      key: ValueKey('policy-$keySuffix'),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(description),
      trailing: DropdownButton<int>(
        key: ValueKey('policy-$keySuffix-dropdown'),
        value: value,
        underline: const SizedBox.shrink(),
        items: [
          for (final option in items)
            DropdownMenuItem(value: option, child: Text(format(option))),
        ],
        onChanged: (v) {
          if (v != null && v != value) onChanged(v);
        },
      ),
    );
  }
}

class SimultaneousTile extends StatelessWidget {
  const SimultaneousTile({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      key: const Key('policy-simultaneous'),
      title: Text(l10n?.policySimultaneousTitle ??
          'Simultaneous reservations per member'),
      subtitle: Text(l10n?.policySimultaneousDesc ??
          'How many overlapping bookings one member may hold. '
              '1 keeps one place at a time.'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('policy-simultaneous-minus'),
            icon: const Icon(Icons.remove),
            onPressed: value > BookingPolicies.defaultSimultaneous
                ? () => onChanged(value - 1)
                : null,
          ),
          Text(
            NumberFormat.decimalPattern(
                    Localizations.localeOf(context).toLanguageTag())
                .format(value),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            key: const Key('policy-simultaneous-plus'),
            icon: const Icon(Icons.add),
            onPressed: value < BookingPolicies.maxSimultaneous
                ? () => onChanged(value + 1)
                : null,
          ),
        ],
      ),
    );
  }
}

class HourCountTile extends StatelessWidget {
  const HourCountTile({
    super.key,
    required this.keySuffix,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String keySuffix;
  final String title;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
        key: ValueKey('work-hours-$keySuffix'),
        leading: const Icon(Icons.timelapse_outlined),
        title: Text(title),
        trailing: DropdownButton<int>(
          value: value.clamp(1, 16),
          underline: const SizedBox.shrink(),
          items: [
            for (var h = 1; h <= 16; h++)
              DropdownMenuItem(
                value: h,
                child: Text(l10n?.availabilityHourOption(h) ?? '$h h'),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

/// Optional closure reason. Pops null on cancel (aborts the add) and the
/// (possibly empty) text on save.
