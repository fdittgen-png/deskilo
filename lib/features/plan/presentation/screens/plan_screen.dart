// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Floor plan + time scroller (Epic #4). Placeholder until then.
class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(child: Text(l10n?.comingSoon ?? 'Coming soon'));
  }
}
