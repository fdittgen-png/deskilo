// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/backend_settings.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/i18n/time_zones.dart';
import '../../application/creation_intent.dart';
import '../../application/start_workspace.dart';
import '../../domain/template_outline.dart';
import '../../domain/template_preview.dart';
import 'template_group_label.dart';

/// #1636 — what a creation makes, as one explicit choice. One test
/// workspace is the default: the pair used to be pre-ticked, and an
/// owner who only wanted to look around left with a production twin.
class CreationShapeSelector extends StatelessWidget {
  const CreationShapeSelector({
    super.key,
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final CreationShape value;
  final ValueChanged<CreationShape> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    RadioListTile<CreationShape> tile(
            CreationShape shape, String title, String hint) =>
        RadioListTile<CreationShape>(
          key: ValueKey('onboarding-shape-${shape.name}'),
          value: shape,
          enabled: enabled,
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          subtitle: Text(hint),
        );
    return Column(
      key: const ValueKey('onboarding-shape'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n?.onboardingShapeLabel ?? 'What to create',
            style: Theme.of(context).textTheme.titleSmall),
        RadioGroup<CreationShape>(
          groupValue: value,
          onChanged: (shape) {
            if (enabled && shape != null) onChanged(shape);
          },
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            tile(
              CreationShape.test,
              l10n?.onboardingShapeTest ?? 'One test workspace',
              l10n?.onboardingShapeTestHint ??
                  'Safe for trying things out: every screen and document '
                      'says it is a test. No real billing.',
            ),
            tile(
              CreationShape.real,
              l10n?.onboardingShapeReal ?? 'One real workspace',
              l10n?.onboardingShapeRealHint ??
                  'For real operation: the invoices it issues are owed.',
            ),
            tile(
              CreationShape.pair,
              l10n?.onboardingShapePair ?? 'A linked test and real pair',
              l10n?.onboardingWithTwinHint ??
                  'Two workspaces with the same name: one to try things '
                      'out, one that is real. You own both.',
            ),
          ]),
        ),
      ],
    );
  }
}

/// #1636 — the facts Create commits to: how many workspaces, on which
/// server, and whether any of them bills for real.
class CreationSummary extends ConsumerWidget {
  const CreationSummary({super.key, required this.shape});

  final CreationShape shape;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final host = ref.watch(activeBackendProvider).value?.host;
    final count = shape.workspaceCount;
    return Column(
      key: const ValueKey('onboarding-summary'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: const ValueKey('onboarding-summary-count'),
          contentPadding: EdgeInsets.zero,
          leading: Icon(shape == CreationShape.pair
              ? Icons.copy_all_outlined
              : Icons.business_outlined),
          title: Text(l10n?.onboardingSummaryCount(count) ??
              (count == 1
                  ? 'Creates one workspace'
                  : 'Creates $count workspaces')),
          subtitle: Text(switch (shape) {
            CreationShape.test =>
              l10n?.onboardingShapeTest ?? 'One test workspace',
            CreationShape.real =>
              l10n?.onboardingShapeReal ?? 'One real workspace',
            CreationShape.pair =>
              l10n?.onboardingShapePair ?? 'A linked test and real pair',
          }),
        ),
        ListTile(
          key: const ValueKey('onboarding-summary-billing'),
          contentPadding: EdgeInsets.zero,
          leading: Icon(shape.realBilling
              ? Icons.receipt_long_outlined
              : Icons.science_outlined),
          title: Text(shape.realBilling
              ? (l10n?.onboardingSummaryBillingOn ??
                  'Real billing is possible: its invoices are owed.')
              : (l10n?.onboardingSummaryBillingOff ??
                  'No real billing: documents are marked as a test.')),
        ),
        if (host != null)
          ListTile(
            key: const ValueKey('onboarding-summary-server'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.dns_outlined),
            title: Text(l10n?.onboardingSummaryServer(host) ??
                'On the server $host'),
          ),
      ],
    );
  }
}

/// #1636 — a sent creation whose answer never arrived. Its payload is
/// frozen: the only way forward is to ask the server about the SAME
/// request, which either returns the workspace it made or makes it now.
class CreationPendingBanner extends StatelessWidget {
  const CreationPendingBanner({
    super.key,
    required this.changed,
    required this.onRetryAsSent,
  });

  /// The form no longer matches what was sent.
  final bool changed;
  final VoidCallback onRetryAsSent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InlineBanner(
      key: const ValueKey('onboarding-intent-pending'),
      icon: Icons.sync_problem_outlined,
      severity: InlineBannerSeverity.info,
      text: changed
          ? (l10n?.onboardingIntentChanged ??
              'Your earlier request may already have been created. Retry '
                  'it exactly as it was sent before changing anything.')
          : (l10n?.onboardingIntentResumed ??
              'An earlier creation may have gone through. Retry to check '
                  'the same request.'),
      actionLabel: l10n?.onboardingRetryAsSent ?? 'Retry as sent',
      // The banner asserts label and action come together; a press while
      // busy is ignored by the wizard's own single-flight guard.
      onAction: onRetryAsSent,
    );
  }
}

/// What the chosen template sets up, or why this server refuses it.
class TemplateOutlineView extends StatelessWidget {
  const TemplateOutlineView({super.key, required this.outline});

  final TemplateOutline? outline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final outline = this.outline;
    if (outline == null) return const SizedBox.shrink();
    if (outline.refused) {
      return InlineBanner(
        key: const ValueKey('onboarding-template-refused'),
        icon: Icons.block,
        text: [
          l10n?.libraryNotSupported ?? 'This template cannot be applied here.',
          ?outline.reason,
        ].join(' '),
      );
    }
    final groups =
        outline.groups.map((g) => templateGroupLabel(l10n, g)).join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (outline.compatibility == TemplateCompatibility.partial)
          InlineBanner(
            key: const ValueKey('onboarding-template-partial'),
            icon: Icons.info_outline,
            severity: InlineBannerSeverity.info,
            text: l10n?.libraryPartial ??
                'Part of this template cannot be applied here and is left out.',
          ),
        if (groups.isNotEmpty)
          Text(
            l10n?.onboardingTemplateSetsUp(groups) ?? 'Sets up: $groups',
            key: const ValueKey('onboarding-confirm-groups'),
          ),
      ],
    );
  }
}

/// #1636 — currency and time zone, each checked against what the app can
/// actually use rather than "three letters" and "not empty".
class PlaceFields extends StatelessWidget {
  const PlaceFields({
    super.key,
    required this.currency,
    required this.currencyFocus,
    required this.timezone,
    required this.timezoneFocus,
  });

  final TextEditingController currency, timezone;
  final FocusNode currencyFocus, timezoneFocus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
          TextFormField(
            key: const ValueKey('onboarding-currency'),
            controller: currency,
            focusNode: currencyFocus,
            decoration: InputDecoration(
              labelText: l10n?.workspaceCurrencyLabel ?? 'Currency',
            ),
            validator: (v) => isKnownCurrency(v ?? '')
                ? null
                : (l10n?.onboardingCurrencyUnknown ??
                    'Enter a currency code the app supports, such as EUR'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('onboarding-timezone'),
            controller: timezone,
            focusNode: timezoneFocus,
            decoration: InputDecoration(
              labelText: l10n?.workspaceTimezoneLabel ?? 'Time zone',
            ),
            validator: (v) => TimeZones.isKnown(v?.trim() ?? '')
                ? null
                : (l10n?.workspaceTimezoneUnknown ??
                    'Pick a time zone from the list'),
          ),
          const SizedBox(height: 12),
      ],
    );
  }
}
