// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../l10n/app_localizations.dart';

String applicationStatusLabel(AppLocalizations l10n, String status) =>
    switch (status) {
      'confirmed' => l10n.applicationApproved,
      'rejected' => l10n.applicationRefused,
      _ => l10n.applicationPending,
    };
