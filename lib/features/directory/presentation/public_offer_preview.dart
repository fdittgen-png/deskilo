// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3553 — what the public page says the business is and offers, as the
// owner's page reads it back: its kinds, the services it marked public (each
// price in its own currency with what that price means for tax), whether it
// takes inquiries. Read only: a service is published from Services, where it
// is marked public; the kinds come from the business's settings.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/format_controller.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/navigation/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../workspace/presentation/business_kind_names.dart';
import '../domain/public_workspace.dart';
import 'public_service_line.dart';

/// One published service in a line, its price in the business's format.
String _serviceLine(BuildContext context, PublicService s) => publicServiceLine(
  context.l10n,
  s,
  appFormatOf(context).money(s.priceMinor, currency: s.currency),
);

class PublicOfferPreview extends StatelessWidget {
  const PublicOfferPreview({required this.offer, super.key});

  /// The owner's page as `publication.page.read` answers it; nothing is
  /// shown before it is read.
  final PublicWorkspace? offer;

  @override
  Widget build(BuildContext context) {
    final offer = this.offer;
    if (offer == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final kinds = [for (final k in offer.kinds) ?businessKindLabel(l10n, k)];
    final services = offer.services;
    final inquiries = offer.takesInquiries;
    return Padding(
      key: const ValueKey('public-page-offer'),
      padding: AppSpacing.smAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.portalOfferTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          if (kinds.isNotEmpty)
            Text(
              l10n.portalOfferKinds(kinds.join(', ')),
              key: const ValueKey('public-page-offer-kinds'),
            ),
          if (services.isEmpty)
            Text(
              l10n.portalOfferNoServices,
              key: const ValueKey('public-page-offer-none'),
              style: theme.textTheme.bodySmall,
            )
          else
            for (final (i, s) in services.indexed)
              Text(
                _serviceLine(context, s),
                key: ValueKey('public-page-offer-service-$i'),
              ),
          if (inquiries != null)
            Text(
              inquiries
                  ? l10n.portalOfferInquiriesYes
                  : l10n.portalOfferInquiriesNo,
              key: const ValueKey('public-page-offer-inquiries'),
              style: theme.textTheme.bodySmall,
            ),
          TextButton(
            key: const ValueKey('public-page-offer-edit'),
            onPressed: () => context.push(Routes.services),
            child: Text(l10n.portalOfferEdit),
          ),
        ],
      ),
    );
  }
}
