// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/app_localizations_en.dart';
import 'booking_window_summary.dart';

/// Keeps confirmation reachable while the draft and secondary details scroll.
class BookingSheetFrame extends StatelessWidget {
  const BookingSheetFrame({
    super.key,
    required this.children,
    required this.action,
  });
  final List<Widget> children;
  final Widget action;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            MediaQuery.viewInsetsOf(context).bottom + AppSpacing.sm,
          ),
          child: SizedBox(width: double.infinity, child: action),
        ),
      ],
    ),
  );
}

/// Reviews the current draft immediately before its primary action.
class BookingReviewSummary extends StatelessWidget {
  const BookingReviewSummary({
    super.key,
    required this.resource,
    required this.person,
    required this.window,
    required this.today,
    this.timezone,
    this.recurrence,
    this.walkUp = false,
  });
  final List<String> resource;
  final String person;
  final ({DateTime start, DateTime end}) window;
  final DateTime today;
  final String? timezone;
  final String? recurrence;
  final bool walkUp;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context) ?? AppLocalizationsEn();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              resource.where((s) => s.isNotEmpty).join(' · '),
              key: const ValueKey('booking-review-resource'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text('${words.uxBookingFor}: $person'),
          if (walkUp) Text(words.planStartNow),
            BookingWindowSummary(
              window: window,
              today: today,
              timezone: timezone,
            ),
            if (recurrence != null) Text('${words.planRepeatLabel}: $recurrence'),
            Text(
              words.uxBookingChargePending,
              key: const ValueKey('booking-charge-context'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Maintenance is a separate management decision, outside booking options.
class BookingManagementOptions extends StatelessWidget {
  const BookingManagementOptions({super.key, required this.onBlock});
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context) ?? AppLocalizationsEn();
    return ExpansionTile(
      key: const ValueKey('booking-manage-options'),
      tilePadding: EdgeInsets.zero,
      title: Text(words.uxManageResource),
      children: [
        TextButton.icon(
          icon: const Icon(Icons.block),
          label: Text(words.planMakeNotReservable),
          onPressed: onBlock,
        ),
      ],
    );
  }
}
