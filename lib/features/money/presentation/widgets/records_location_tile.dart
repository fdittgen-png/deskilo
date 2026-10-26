// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/settings/active_settings.dart';
import '../../domain/records_location.dart';

/// #2378 -- where this space's records are kept, as the operator of the
/// installation declared it (never inferred), and for a Canadian space
/// whose records are not declared in Canada, the rule that asks for them
/// there and the CRA authorisation it recorded. Read-only: the operator
/// declares the country in the platform settings, a billing manager the
/// authorisation in the workspace settings.
class RecordsLocationTile extends ConsumerWidget {
  const RecordsLocationTile({required this.country, super.key});

  /// The workspace's country code; null while it is not known.
  final String? country;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final country = this.country;
    if (country == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final location = RecordsLocation.fromSettings(
      ref.watch(activeSettingsProvider),
      issuerCountry: country,
    );
    final lines = [
      switch (location.hostingCountry) {
        final c? => l10n.recordsLocationHosted(c),
        null => l10n.recordsLocationUndeclared,
      },
      if (location.craNotice) ...[
        l10n.recordsLocationCraNotice,
        if (location.craReference.isEmpty)
          l10n.recordsLocationCraNone
        else
          l10n.recordsLocationCraReference(location.craReference),
      ],
    ];
    return ListTile(
      key: const ValueKey('records-location'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        location.craNotice ? Icons.warning_amber_outlined : Icons.dns_outlined,
      ),
      title: Text(l10n.recordsLocationTitle),
      subtitle: Text(
        lines.join('\n'),
        key: const ValueKey('records-location-text'),
      ),
    );
  }
}
