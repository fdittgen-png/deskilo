// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Reservations calendar (Epic #5). Placeholder until then.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(child: Text(l10n?.comingSoon ?? 'Coming soon'));
  }
}
