// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/format/cents.dart';
import '../../../../core/trace/guarded.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../money/domain/vat_rate.dart';
import '../../../money/presentation/vat_price_label.dart';
import '../../../money/presentation/widgets/vat_rate_field.dart';
import '../../../money/providers/money_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/accessory.dart';
import '../../providers/accessory_providers.dart';

/// Owner/admin accessory-catalog editor (#167, epic #163): name and
/// per-half-day supplement are configurable; accessories are deactivated,
/// never deleted (seat assignments and future bill lines reference them).
/// Mirrors the services catalog editor (#123).
class AccessoriesScreen extends ConsumerWidget {
  const AccessoriesScreen({super.key});

  Future<void> _editSheet(
    BuildContext context,
    WidgetRef ref, {
    Accessory? accessory,
  }) async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final l10n = AppLocalizations.of(context);

    final result = await showModalBottomSheet<_AccessoryDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AccessorySheet(
        accessory: accessory,
        rates: ref.read(vatRatesProvider).value ?? const [],
      ),
    );
    if (result == null || !context.mounted) return;

    if (!await runGuarded(
      context,
      domain: 'plan',
      message: 'accessory save failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        final repo = ref.read(accessoryRepositoryProvider);
        if (accessory == null) {
          // New accessories append to the end of the catalog order.
          final existing = ref
                  .read(accessoriesProvider(includeInactive: true))
                  .value ??
              const <Accessory>[];
          final nextSortOrder = existing.fold<int>(
                -1,
                (max, a) => a.sortOrder > max ? a.sortOrder : max,
              ) +
              1;
          await repo.createAccessory(
            workspace.id,
            name: result.name,
            supplementCents: result.supplementCents,
            sortOrder: nextSortOrder,
            vatRateId: result.vatRateId,
          );
        } else {
          await repo.updateAccessory(
            accessory.id,
            name: result.name,
            supplementCents: result.supplementCents,
            active: result.active,
            vatRateId: result.vatRateId,
          );
        }
      },
    )) {
      return;
    }
    ref.invalidate(accessoriesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final accessoriesAsync =
        ref.watch(accessoriesProvider(includeInactive: true));
    final currency = NumberFormat.simpleCurrency(
      name: ref.watch(currentWorkspaceProvider).value?.currencyCode ?? 'EUR',
    );
    final inactiveColor = Theme.of(context).disabledColor;

    // #537/#542 — each row names the rate ITS supplement carries: the
    // accessory's own rate, or the workspace default when it has none.
    final chargesVat =
        ref.watch(currentWorkspaceProvider).value?.vatRegime ==
            'vat_registered';
    final vatRates = ref.watch(vatRatesProvider).value ?? const <VatRate>[];

    String supplementLabel(Accessory accessory) {
      if (accessory.supplementCents == 0) {
        return l10n?.accessoriesNoSupplement ?? 'No supplement';
      }
      final amount = currency.format(accessory.supplementCents / 100);
      final base =
          l10n?.accessoriesPerHalfDay(amount) ?? '$amount / half-day';
      final vatRate = vatRateSuffix(
        chargesVat: chargesVat,
        rates: vatRates,
        vatRateId: accessory.vatRateId,
      );
      if (vatRate == null) return base;
      return '$base · ${l10n?.priceVatIncluded(vatRate) ?? 'incl. VAT $vatRate'}';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.accessoriesTitle ?? 'Accessories'),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n?.accessoriesNew ?? 'New accessory',
        onPressed: () => _editSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: switch (accessoriesAsync) {
        AsyncData(value: final accessories) when accessories.isEmpty =>
          EmptyState(
            icon: Icons.chair_alt_outlined,
            title: l10n?.accessoriesEmpty ?? 'No accessories yet.',
          ),
        AsyncData(value: final accessories) => ListView(
            children: [
              for (final accessory in accessories)
                ListTile(
                  leading: Icon(
                    accessory.active
                        ? Icons.devices_other_outlined
                        : Icons.do_not_disturb_on_outlined,
                    color: accessory.active ? null : inactiveColor,
                  ),
                  title: Text(
                    accessory.name,
                    style: accessory.active
                        ? null
                        : TextStyle(color: inactiveColor),
                  ),
                  subtitle: Text(supplementLabel(accessory)),
                  trailing: accessory.active
                      ? null
                      : Text(l10n?.accessoriesInactive ?? 'Inactive'),
                  onTap: () =>
                      _editSheet(context, ref, accessory: accessory),
                ),
            ],
          ),
        AsyncError() => Center(
            child: Text(
              l10n?.workspaceGenericError ??
                  'Something went wrong. Please try again.',
            ),
          ),
        _ => const LoadingView(),
      },
    );
  }
}

class _AccessoryDraft {
  const _AccessoryDraft({
    required this.name,
    required this.supplementCents,
    required this.active,
    required this.vatRateId,
  });

  final String name;
  final int supplementCents;
  final bool active;
  final String vatRateId;
}

class _AccessorySheet extends StatefulWidget {
  const _AccessorySheet({this.accessory, this.rates = const []});

  final Accessory? accessory;
  final List<VatRate> rates;

  @override
  State<_AccessorySheet> createState() => _AccessorySheetState();
}

class _AccessorySheetState extends State<_AccessorySheet> {
  late final TextEditingController _name;
  late final TextEditingController _supplement;
  late bool _active;
  late String _vatRateId;

  @override
  void initState() {
    super.initState();
    final accessory = widget.accessory;
    _name = TextEditingController(text: accessory?.name ?? '');
    _supplement = TextEditingController(
      text: accessory == null ? '' : centsToMajor(accessory.supplementCents),
    );
    _active = accessory?.active ?? true;
    _vatRateId = accessory?.vatRateId ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _supplement.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final supplement = parseCentsInput(_supplement.text);
    if (name.isEmpty || supplement == null) return;
    Navigator.of(context).pop(
      _AccessoryDraft(
        name: name,
        supplementCents: supplement,
        active: _active,
        vatRateId: _vatRateId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      // #210: sheet gutter unified onto the xl token like every other
      // modal edit sheet (was 16).
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.accessory == null
                ? (l10n?.accessoriesNew ?? 'New accessory')
                : (l10n?.accessoriesEdit ?? 'Edit accessory'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            autofocus: widget.accessory == null,
            maxLength: 80,
            decoration: InputDecoration(
              labelText: l10n?.accessoriesName ?? 'Name',
            ),
          ),
          TextField(
            controller: _supplement,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText:
                  l10n?.accessoriesSupplement ?? 'Supplement per half-day',
              // #537 — gross, like every DesKilo price.
              helperText: l10n?.priceGrossHint ??
                  'Gross price — what the member pays; VAT is part of it.',
            ),
          ),
          // #542 — per-accessory rate, defaulted to the workspace default.
          VatRateField(
            rates: widget.rates,
            value: _vatRateId,
            onChanged: (id) => setState(() => _vatRateId = id),
          ),
          if (widget.accessory != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n?.accessoriesActive ?? 'Active'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _submit,
            child: Text(l10n?.commonSave ?? 'Save'),
          ),
        ],
      ),
    );
  }
}
