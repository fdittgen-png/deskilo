// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4005 — how a house began: the head it was made from and when, what came
// with it (its priced rows inactive, to be priced), the head's owners added
// as co-owners, and what did not come (the document layout and links).
// Shown once on the house's home after it is made, and in Settings ›
// Organisation for as long as the house is one.
import 'package:flutter/material.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/organisation.dart';

class HouseBirthView extends StatelessWidget {
  const HouseBirthView({super.key, required this.birth, required this.head});

  final HouseBirth birth;

  /// The head's name, as the organisation lists it.
  final String head;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final date = birth.createdAt;
    return Column(
      key: const ValueKey('house-birth'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.houseBirthTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const FormGap.small(),
        if (date != null)
          Text(
            l10n.houseBirthCreated(
              head,
              appFormatOf(context).dates(DateShape.date).format(date),
            ),
          ),
        Text(
          l10n.houseBirthToPrice(
            [
              // #4042: plans are retired and no new house carries one; a
              // house born earlier still says how many it was given.
              if (birth.plans > 0) l10n.houseBirthPlans(birth.plans),
              l10n.houseBirthServices(birth.services),
              l10n.houseBirthPackages(birth.packages),
            ].join(', '),
          ),
        ),
        Text(l10n.houseBirthCoOwners(birth.coOwnersAdded)),
        Text(l10n.houseBirthNotCarried),
      ],
    );
  }

  /// Shows [birth] once, over the house's home.
  static Future<void> showOnce(
    BuildContext context, {
    required HouseBirth birth,
    required String head,
  }) => showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      content: SingleChildScrollView(
        child: HouseBirthView(birth: birth, head: head),
      ),
      actions: [
        FilledButton(
          key: const ValueKey('house-birth-ok'),
          onPressed: () => Navigator.of(dialog).pop(),
          child: Text(MaterialLocalizations.of(dialog).okButtonLabel),
        ),
      ],
    ),
  );
}
