// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2477 -- the platform owner's editor of the tax reference store: values
// by domain and country with their validity, source and `confirmed` badge;
// a change is a new version (never an edit); every value has a history.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/vat/tax_reference.dart';
import '../../providers/tax_reference_providers.dart';
import '../widgets/tax_reference_history_sheet.dart';
import '../widgets/tax_reference_sheets.dart';

/// Opens the editor as a full-height sheet: the platform owner's tools are
/// reached from the profile list and need no route of their own.
Future<void> showTaxReferenceScreen(BuildContext context, {required bool canEdit}) =>
    showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TaxReferenceScreen(canEdit: canEdit),
    );

@visibleForTesting
class TaxReferenceScreen extends ConsumerStatefulWidget {
  const TaxReferenceScreen({super.key, this.canEdit = false});

  /// Whether the signed-in person is the platform owner (the server decides
  /// again): without it the screen shows nothing and offers nothing.
  final bool canEdit;

  @override
  ConsumerState<TaxReferenceScreen> createState() => _TaxReferenceScreenState();
}

class _TaxReferenceScreenState extends ConsumerState<TaxReferenceScreen> {
  TaxDomain _domain = TaxDomain.rate;
  String _country = '';
  final _filter = TextEditingController();

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  String _today() => ref.read(clockProvider).now().toIso8601String().substring(0, 10);

  Future<bool> _openForm(TaxDomain domain, {TaxReferenceRow? from}) =>
      showTaxReferenceVersionSheet(
        context,
        commands: ref.read(taxReferenceCommandsProvider),
        today: _today(),
        onSaved: () => ref.invalidate(taxReferenceSetProvider),
        domain: domain,
        from: from,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final owner = widget.canEdit;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.taxRefTitle)),
      floatingActionButton: owner
          ? FloatingActionButton.extended(
              key: const ValueKey('tax-reference-add'),
              icon: const Icon(Icons.add),
              label: Text(l10n.taxRefAdd),
              onPressed: () => _openForm(_domain),
            )
          : null,
      body: !owner
          ? Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.taxRefNotAllowed, textAlign: TextAlign.center),
            ))
          : _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(taxReferenceSetProvider);
    final today = ref.watch(clockProvider).now().toIso8601String().substring(0, 10);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, st) => Center(child: Text(l10n.taxRefLoadFailed)),
      data: (set) {
        final rows = set
            .on(today)
            .where(_domain)
            .where((r) => _country.isEmpty || r.country == _country)
            .toList()
          ..sort((a, b) {
            final byCountry = a.country.compareTo(b.country);
            return byCountry != 0 ? byCountry : a.key.compareTo(b.key);
          });
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, kFabSafeBottom),
          children: [
            Text(l10n.taxRefIntro),
            if (set.origin == TaxReferenceOrigin.bundle)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l10n.taxRefOfflineCopy),
              ),
            const SizedBox(height: AppSpacing.md),
            Wrap(spacing: 8, children: [
              for (final d in TaxDomain.values)
                ChoiceChip(
                  key: ValueKey('tax-reference-domain-${d.wire}'),
                  label: Text(taxDomainLabel(context, d)),
                  selected: d == _domain,
                  onSelected: (_) => setState(() => _domain = d),
                ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              key: const ValueKey('tax-reference-country-filter'),
              controller: _filter,
              label: l10n.taxRefCountry,
              onChanged: (v) => setState(() => _country = v.trim().toUpperCase()),
            ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(l10n.taxRefEmpty),
              ),
            for (final r in rows)
              ListTile(
                key: ValueKey('tax-reference-${r.domain.wire}-${r.country}-${r.key}'),
                contentPadding: EdgeInsets.zero,
                title: Text(taxValueSummary(r.value).isEmpty
                    ? r.country
                    : taxValueSummary(r.value)),
                subtitle: Text('${r.country} · ${r.key} · '
                    '${l10n.taxRefValidFrom} ${r.validFrom} · ${r.source}'),
                leading: Icon(
                  r.confirmed ? Icons.verified_outlined : Icons.help_outline,
                  semanticLabel:
                      r.confirmed ? l10n.taxRefConfirmed : l10n.taxRefUnconfirmed,
                ),
                trailing: IconButton(
                  key: ValueKey('tax-reference-history-${r.domain.wire}-${r.country}-${r.key}'),
                  tooltip: l10n.taxRefHistory,
                  icon: const Icon(Icons.history),
                  onPressed: () => showTaxReferenceHistorySheet(
                    context,
                    set: set,
                    row: r,
                    commands: ref.read(taxReferenceCommandsProvider),
                    today: today,
                    onDone: () => ref.invalidate(taxReferenceSetProvider),
                  ),
                ),
                onTap: () => _openForm(r.domain, from: r),
              ),
          ],
        );
      },
    );
  }
}
