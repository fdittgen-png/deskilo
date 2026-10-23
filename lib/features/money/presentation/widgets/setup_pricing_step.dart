// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup step "prices and plans": the preset levels members may choose,
// offered through the billing screen's own write
// ([OfferSubscriptionLevels]), beside the fee bands, day packages and
// carnets that price them, as stored; those are edited in Billing, one tap
// away. The preview is what a member pays at each offered level, found
// the way the agreement letter finds it ([memberPriceList]), and follows
// the chips before anything is saved. Levels picked and not offered are
// kept as the step's draft on the server (#2869), through the frame the
// guide hands in.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/ui/setup_draft_form.dart';
import '../../../../core/ui/setup_step_layout.dart';
import '../../application/offer_subscription_levels.dart';
import '../../domain/credit_product.dart';
import '../../domain/fee_band.dart';
import '../../domain/package.dart';
import '../../domain/subscription_levels.dart';
import '../../providers/credit_providers.dart';
import '../../providers/money_providers.dart';
import 'setup_price_list.dart';

class SetupPricingStep extends ConsumerWidget {
  const SetupPricingStep({
    super.key,
    required this.workspaceId,
    required this.currencyCode,
    required this.carnetsOn,
    required this.draft,
  });

  final String workspaceId;
  final String currencyCode;

  /// Whether the workspace sells carnets: off, none is read or listed.
  final bool carnetsOn;

  /// Keeps the levels picked and not offered as the step's draft.
  final SetupDraftFrameBuilder draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bands = ref.watch(feeBandsProvider);
    final levels = ref.watch(subscriptionLevelsProvider);
    final packages = ref.watch(allPackagesProvider);
    final carnets = carnetsOn
        ? ref.watch(creditProductsProvider)
        : const AsyncData(<CreditProduct>[]);
    final all = [bands, levels, packages, carnets];
    if (all.any((v) => v.hasError && !v.hasValue)) {
      return Padding(
        padding: AppSpacing.lgAll,
        child: InlineBanner(
          key: const ValueKey('setup-pricing-failed'),
          icon: Icons.error_outline,
          text: context.l10n.setupStepLoadFailed,
        ),
      );
    }
    if (all.any((v) => !v.hasValue)) return const LoadingView();
    return _PricingPage(
      draft: draft,
      workspaceId: workspaceId,
      currencyCode: currencyCode,
      stored: levels.requireValue,
      bands: bands.requireValue,
      packages: [
        for (final p in packages.requireValue)
          if (p.active) p,
      ],
      carnets: carnetsOn
          ? [
              for (final c in carnets.requireValue)
                if (c.active) c,
            ]
          : null,
    );
  }
}

class _PricingPage extends ConsumerStatefulWidget {
  const _PricingPage({
    required this.draft,
    required this.workspaceId,
    required this.currencyCode,
    required this.stored,
    required this.bands,
    required this.packages,
    required this.carnets,
  });

  final String workspaceId;
  final String currencyCode;
  final SubscriptionLevels stored;
  final List<FeeBand> bands;
  final List<Package> packages;

  /// Null while carnets are off.
  final List<CreditProduct>? carnets;
  final SetupDraftFrameBuilder draft;

  @override
  ConsumerState<_PricingPage> createState() => _PricingPageState();
}

class _PricingPageState extends ConsumerState<_PricingPage> {
  late final _presets = ValueNotifier<Set<int>>({
    ...widget.stored.enabledPresets,
  });
  final _busy = ValueNotifier<bool>(false);

  late final _kept = SetupDraftForm(
    edits: _presets,
    answers: () => {
      'presets': [..._presets.value]..sort(),
    },
    fill: (answers) => _presets.value = switch (answers?['presets']) {
      final List<Object?> picked => {...picked.whereType<int>()},
      _ => {...widget.stored.enabledPresets},
    },
  );

  @override
  void dispose() {
    _presets.dispose();
    _busy.dispose();
    super.dispose();
  }

  void _toggle(int preset, {required bool on}) => _presets.value = {
    for (final p in _presets.value)
      if (p != preset) p,
    if (on) preset,
  };

  Future<void> _offer() async {
    final l10n = context.l10n;
    _busy.value = true;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'setup pricing levels failed',
      errorText: l10n.setupPricingSaveFailed,
      action: () => ref
          .read(offerSubscriptionLevelsProvider)
          .offer(widget.workspaceId, widget.stored, _presets.value),
    );
    // The page reads the stored levels again whether or not it landed.
    ref.invalidate(subscriptionLevelsProvider);
    if (!mounted) return;
    _busy.value = false;
    if (!ok) return;
    AppSnack.success(context, l10n.billingSaved);
    await _kept.applied();
  }

  @override
  Widget build(BuildContext context) {
    final money = moneyFormat(widget.currencyCode);
    return SetupStepLayout(
      form: widget.draft(
        form: _kept,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l10n.setupStepHint('pricing')),
            const SizedBox(height: AppSpacing.lg),
            ListenableBuilder(
              listenable: Listenable.merge([_presets, _busy]),
              builder: (context, _) => _LevelsPreset(
                presets: _presets.value,
                busy: _busy.value,
                onToggle: _toggle,
                onOffer: _offer,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _Catalogue(
              bands: widget.bands,
              packages: widget.packages,
              carnets: widget.carnets,
              money: money.formatMinor,
            ),
          ],
        ),
      ),
      preview: ValueListenableBuilder<Set<int>>(
        valueListenable: _presets,
        builder: (context, presets, _) => SetupPriceList(
          levels: {...presets, ...widget.stored.extraLevels},
          bands: widget.bands,
          money: money.formatMinor,
        ),
      ),
    );
  }
}

class _LevelsPreset extends StatelessWidget {
  const _LevelsPreset({
    required this.presets,
    required this.busy,
    required this.onToggle,
    required this.onOffer,
  });

  final Set<int> presets;
  final bool busy;
  final void Function(int preset, {required bool on}) onToggle;
  final VoidCallback onOffer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.billingLevels,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(l10n.setupPricingLevelsBody),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final preset in SubscriptionLevels.presets)
              FilterChip(
                key: ValueKey('setup-pricing-level-$preset'),
                label: Text(l10n.percentValue(preset)),
                selected: presets.contains(preset),
                onSelected: busy ? null : (on) => onToggle(preset, on: on),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          key: const ValueKey('setup-pricing-offer'),
          onPressed: busy ? null : onOffer,
          child: Text(l10n.setupPricingOffer),
        ),
      ],
    );
  }
}

/// The bands, packages and carnets as stored, and the way to Billing.
class _Catalogue extends StatelessWidget {
  const _Catalogue({
    required this.bands,
    required this.packages,
    required this.carnets,
    required this.money,
  });

  final List<FeeBand> bands;
  final List<Package> packages;
  final List<CreditProduct>? carnets;
  final String Function(int cents) money;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = Theme.of(context).textTheme.titleMedium;
    final carnets = this.carnets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.billingFeeBands, style: title),
        if (bands.isEmpty)
          Text(
            l10n.setupPricingNoBands,
            key: const ValueKey('setup-pricing-no-bands'),
          ),
        for (final b in bands)
          _Line(
            key: ValueKey('setup-pricing-band-${b.toPct}'),
            text: l10n.setupPricingBand(
              b.fromPct,
              b.toPct,
              money(b.feeCents),
              money(b.overageFeeCents),
            ),
          ),
        if (packages.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(l10n.billingPackages, style: title),
          for (final p in packages)
            _Line(
              key: ValueKey('setup-pricing-package-${p.id}'),
              text: p.name,
              detail: l10n.billingPackageSummary(p.days, money(p.priceCents)),
            ),
        ],
        if (carnets != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(l10n.carnetsTitle, style: title),
          if (carnets.isEmpty) Text(l10n.carnetsEmpty),
          for (final c in carnets)
            _Line(
              key: ValueKey('setup-pricing-carnet-${c.id}'),
              text: c.name,
              detail: l10n.carnetSummary(c.halfDays, money(c.priceCents)),
            ),
        ],
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          key: const ValueKey('setup-pricing-open-billing'),
          onPressed: () => context.push('/billing'),
          child: Text(l10n.setupPricingOpenBilling),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({super.key, required this.text, this.detail});
  final String text;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(text),
      subtitle: detail == null ? null : Text(detail),
    );
  }
}
