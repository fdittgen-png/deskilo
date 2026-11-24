// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup step "services": the catalogue as stored, and a service added
// or edited in the same sheet as the services screen (#3552: one editor,
// one write, [SaveService]). Stock and archiving stay on the services
// screen, one tap away. The preview is the list a
// member picks from when they add a consumption to their bill: the active
// services, each with what it costs them.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/ui/setup_step_layout.dart';
import '../../../../l10n/dictionary_labels.dart';
import '../../domain/service_item.dart';
import '../../providers/money_providers.dart';
import 'service_sheet.dart';

class SetupServicesStep extends ConsumerStatefulWidget {
  const SetupServicesStep({
    super.key,
    required this.workspaceId,
    required this.currencyCode,
    required this.hasPlaces,
  });

  final String workspaceId;
  final String currencyCode;

  /// Whether the business has bookable places (#3547): members add coffee,
  /// printing and lockers to a place; a business without one offers its
  /// customers services.
  final bool hasPlaces;

  @override
  ConsumerState<SetupServicesStep> createState() => _SetupServicesStepState();
}

class _SetupServicesStepState extends ConsumerState<SetupServicesStep> {
  /// #3552 — the same editor as the services screen: one sheet, one write.
  Future<void> _edit(List<ServiceItem> stored, [ServiceItem? service]) =>
      ServiceEditor.open(
        context,
        ref,
        workspaceId: widget.workspaceId,
        service: service,
        categories: [for (final s in stored) s.category],
      );

  @override
  Widget build(BuildContext context) {
    final money = appFormatOf(context).moneyIn(widget.currencyCode);
    return switch (ref.watch(allServicesProvider)) {
      AsyncValue(hasValue: true, :final value) => SetupStepLayout(
        form: _form(context, value ?? const [], money),
        preview: _Preview(
          services: [
            for (final s in value ?? const <ServiceItem>[])
              if (s.active) s,
          ],
          money: money,
        ),
      ),
      AsyncError(:final error) => Padding(
        padding: AppSpacing.lgAll,
        child: ReadFailureBanner(
          key: const ValueKey('setup-services-failed'),
          error: error,
          onRetry: () => ref.invalidate(allServicesProvider),
        ),
      ),
      _ => const LoadingView(),
    };
  }

  Widget _form(
    BuildContext context,
    List<ServiceItem> stored,
    MoneyFormat money,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.setupStepHintFor('services', hasPlaces: widget.hasPlaces)),
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.servicesTitle, style: theme.textTheme.titleSmall),
        if (stored.isEmpty)
          Text(l10n.servicesEmpty, key: const ValueKey('setup-services-none')),
        for (final s in stored)
          ListTile(
            key: ValueKey('setup-services-stored-${s.id}'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            onTap: () => _edit(stored, s),
            title: Text(s.name),
            subtitle: Text(
              [
                money.formatMinor(s.priceCents),
                if (!s.active) l10n.servicesInactive,
              ].join(' · '),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton(
              key: const ValueKey('setup-services-add'),
              onPressed: () => _edit(stored),
              child: Text(l10n.setupServicesAdd),
            ),
            TextButton(
              key: const ValueKey('setup-services-open'),
              onPressed: () => context.push('/services'),
              child: Text(l10n.setupServicesMore),
            ),
          ],
        ),
      ],
    );
  }
}

/// The services a member can add to their bill, as the consumption sheet
/// lists them: the name, then what it costs.
class _Preview extends StatelessWidget {
  const _Preview({required this.services, required this.money});

  final List<ServiceItem> services;
  final MoneyFormat money;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (services.isEmpty) {
      return Text(
        l10n.setupServicesPreviewEmpty,
        key: const ValueKey('setup-services-preview-empty'),
      );
    }
    return Column(
      key: const ValueKey('setup-services-preview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.setupServicesPreviewNote),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.consumptionAdd,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final s in services)
          ListTile(
            key: ValueKey('setup-services-preview-${s.id}'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.local_cafe_outlined),
            title: Text('${s.name} — ${money.formatMinor(s.priceCents)}'),
          ),
      ],
    );
  }
}
