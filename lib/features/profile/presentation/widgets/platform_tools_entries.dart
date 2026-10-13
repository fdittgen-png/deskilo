// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The platform owner's tools, listed in the platform section of the profile
// list (#937): reference data and defaults that belong to the installation,
// not to one workspace. Server-gated (`is_platform_owner`), no feature flag
// (docs/AGENT_RULES.md, "The platform-owner overview has no feature flag").
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../money/presentation/screens/tax_reference_screen.dart';

class PlatformToolsEntries extends StatelessWidget {
  const PlatformToolsEntries({super.key});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          // #2477 — rates, statutory texts and VAT id patterns.
          ListTile(
            key: const ValueKey('profiles-tax-reference'),
            leading: const Icon(Icons.percent),
            title: Text(context.l10n.taxRefTitle),
            onTap: () => showTaxReferenceScreen(context, canEdit: true),
          ),
        ],
      );
}
