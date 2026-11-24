// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4350 -- what the Stock page says when nothing is in stock yet: an owner who has just switched the goods
// ledger on finds no place and no item, so the page says where to start instead of showing a blank list:
// "Add your first place" and "Add your first item", each opening its editor, then how goods come in. Once
// there is a place and an item the page says only that nothing is in stock. Whoever may not manage the
// stock is told the stock is empty, with no button that would be refused.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/navigation/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/loading_view.dart';
import '../../workspace/domain/workspace_permission.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/stock_config.dart';
import '../domain/stock_page.dart';
import '../domain/stock_sites.dart';
import '../providers/stock_providers.dart';

class StockFirstRun extends ConsumerWidget {
  const StockFirstRun({required this.workspaceId, super.key});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final places = ref.watch(stockPlaceConfigsProvider(workspaceId));
    final items = ref.watch(stockItemsProvider(workspaceId));
    if (places.isLoading || items.isLoading) return const LoadingView();
    // a read that failed is not "no place": the plain empty text, never an invitation built on a guess
    if (places.hasError || items.hasError) return Center(key: const ValueKey('stock-empty'), child: Text(l10n.stockEmpty));
    final noPlace = stockRealPlaces(places.value ?? const <StockPlaceConfig>[]).isEmpty; // empty-ok: a failed read shows the plain empty text below
    final noItem = (items.value ?? const <StockItem>[]).isEmpty; // empty-ok: a failed read shows the plain empty text below
    final mayManage = ref.watch(myPermissionsProvider).contains(WorkspacePermission.manageStock);
    if (!(noPlace || noItem)) return Center(key: const ValueKey('stock-empty'), child: Text(l10n.stockEmpty));
    return Center(
      key: const ValueKey('stock-first-run'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.stockFirstRunTitle, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.stockFirstRunBody),
              const SizedBox(height: AppSpacing.md),
              if (mayManage) ...[
                if (noPlace)
                  FilledButton.icon(
                    key: const ValueKey('stock-first-place'),
                    icon: const Icon(Icons.place_outlined),
                    label: Text(l10n.stockFirstRunPlace),
                    onPressed: () => context.push(Routes.stockPlacesAdd),
                  ),
                if (noPlace && noItem) const SizedBox(height: AppSpacing.sm),
                if (noItem)
                  FilledButton.icon(
                    key: const ValueKey('stock-first-item'),
                    icon: const Icon(Icons.category_outlined),
                    label: Text(l10n.stockFirstRunItem),
                    onPressed: () => context.push(Routes.stockItemsAdd),
                  ),
                const SizedBox(height: AppSpacing.md),
              ],
              Text(l10n.stockFirstRunNext, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
