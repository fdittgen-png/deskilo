// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/format/cents.dart';
import '../../../../core/trace/guarded.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/service_item.dart';
import '../../providers/money_providers.dart';

/// Owner-only consumable-service catalog editor (#123): name and price
/// are configurable; services are deactivated, never deleted (bill lines
/// reference them).
class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  Future<void> _editSheet(
    BuildContext context,
    WidgetRef ref, {
    ServiceItem? service,
  }) async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final l10n = AppLocalizations.of(context);

    final result = await showModalBottomSheet<_ServiceDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ServiceSheet(service: service),
    );
    if (result == null || !context.mounted) return;

    if (!await runGuarded(
      context,
      domain: 'money',
      message: 'service save failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        final repo = ref.read(moneyRepositoryProvider);
        if (service == null) {
          await repo.createService(
            workspace.id,
            name: result.name,
            priceCents: result.priceCents,
          );
        } else {
          await repo.updateService(
            service.id,
            name: result.name,
            priceCents: result.priceCents,
            active: result.active,
          );
        }
      },
    )) {
      return;
    }
    ref
      ..invalidate(allServicesProvider)
      ..invalidate(servicesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final servicesAsync = ref.watch(allServicesProvider);
    final currency = NumberFormat.simpleCurrency(
      name: ref.watch(currentWorkspaceProvider).value?.currencyCode ?? 'EUR',
    );
    final inactiveColor = Theme.of(context).disabledColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.servicesTitle ?? 'Services'),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n?.servicesNew ?? 'New service',
        onPressed: () => _editSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: switch (servicesAsync) {
        AsyncData(value: final services) when services.isEmpty => Center(
            child: Text(l10n?.servicesEmpty ?? 'No services yet.'),
          ),
        AsyncData(value: final services) => ListView(
            children: [
              for (final service in services)
                ListTile(
                  leading: Icon(
                    service.active
                        ? Icons.local_cafe_outlined
                        : Icons.do_not_disturb_on_outlined,
                    color: service.active ? null : inactiveColor,
                  ),
                  title: Text(
                    service.name,
                    style: service.active
                        ? null
                        : TextStyle(color: inactiveColor),
                  ),
                  subtitle: Text(currency.format(service.priceCents / 100)),
                  trailing: service.active
                      ? null
                      : Text(l10n?.servicesInactive ?? 'Inactive'),
                  onTap: () => _editSheet(context, ref, service: service),
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

class _ServiceDraft {
  const _ServiceDraft({
    required this.name,
    required this.priceCents,
    required this.active,
  });

  final String name;
  final int priceCents;
  final bool active;
}

class _ServiceSheet extends StatefulWidget {
  const _ServiceSheet({this.service});

  final ServiceItem? service;

  @override
  State<_ServiceSheet> createState() => _ServiceSheetState();
}

class _ServiceSheetState extends State<_ServiceSheet> {
  late final TextEditingController _name;
  late final TextEditingController _price;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final service = widget.service;
    _name = TextEditingController(text: service?.name ?? '');
    _price = TextEditingController(
      text: service == null ? '' : centsToMajor(service.priceCents),
    );
    _active = service?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final price = parseCentsInput(_price.text);
    if (name.isEmpty || price == null) return;
    Navigator.of(context).pop(
      _ServiceDraft(
        name: name,
        priceCents: price,
        active: _active,
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
            widget.service == null
                ? (l10n?.servicesNew ?? 'New service')
                : (l10n?.servicesEdit ?? 'Edit service'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            autofocus: widget.service == null,
            maxLength: 80,
            decoration: InputDecoration(
              labelText: l10n?.servicesName ?? 'Name',
            ),
          ),
          TextField(
            controller: _price,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n?.servicesPrice ?? 'Price',
            ),
          ),
          if (widget.service != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n?.servicesActive ?? 'Active'),
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
