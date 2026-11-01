// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3068 — the seat legend behind a button in the Reserve hub's view
// controls. The first screen of Reserve is spent on the plan, so the
// explanation of the colours opens on request, and once a person has
// opened it the inline copy stops taking room (the device remembers it
// through the dismissed hints, #606).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_hint_providers.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_sheet.dart';
import 'seat_legend.dart';

/// The hint id the device stores once the legend has been opened.
const reserveLegendHintId = 'reserve.legend';

/// Opens the legend in a sheet and remembers, on this device, that the
/// person has seen it.
Future<void> showSeatLegendSheet(
  BuildContext context,
  WidgetRef ref, {
  required bool showClosed,
}) {
  final opened = showAppSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                sheet.l10n.reserveLegendSheetTitle,
                style: Theme.of(sheet).textTheme.titleMedium,
              ),
            ),
            SeatLegend(showClosed: showClosed),
          ],
        ),
      ),
    ),
  );
  unawaited(
    ref.read(dismissedHelpHintsProvider.notifier).dismiss(reserveLegendHintId),
  );
  return opened;
}
