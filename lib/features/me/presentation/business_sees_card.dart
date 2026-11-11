// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3594 -- Me › Privacy: what a business a person joins can see, said in
// plain words. When they ask: their name and photo. Once a member: the
// space sees their name and photo, and the rest only as their own settings
// allow. The administrators who invoice them or keep the member records see
// the billing details they need.
import 'package:flutter/material.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/help/help_dot.dart';
import '../../../core/l10n/context_l10n.dart';

class BusinessSeesCard extends StatelessWidget {
  const BusinessSeesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = Theme.of(context).textTheme.bodySmall;
    return ExpansionTile(
      key: const ValueKey('me-business-sees'),
      leading: const Icon(Icons.storefront_outlined),
      title: Text(l10n.meBusinessSeesTitle),
      trailing: HelpDot(
        l10n.meBusinessSeesTitle,
        anchor: HelpAnchor.privacyBusinessSees,
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in [
          l10n.meBusinessSeesAsk,
          l10n.meBusinessSeesSpace,
          l10n.meBusinessSeesAdmins,
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(line, style: style),
          ),
      ],
    );
  }
}
