// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Ledger, statements, expenses (Epics #7/#8). Placeholder until then.
class MoneyScreen extends StatelessWidget {
  const MoneyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(child: Text(l10n?.comingSoon ?? 'Coming soon'));
  }
}
