// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4485 — Settings › Master data: every kind of master data the business
// keeps, grouped, each a card with its name, one line of what it is and how
// many records it holds; one tap opens the existing screen that edits it. A
// card is shown to whom that screen opens (master_data_kinds.dart); the
// search narrows the cards by name. One column on a phone, two or three as
// the room grows.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/help/help_anchors.dart';
import '../../core/help/help_dot.dart';
import '../../core/l10n/context_l10n.dart';
import '../../core/text/collation.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/ui/adaptive/window_class.dart';
import '../../core/ui/async_read_body.dart';
import '../../core/ui/form_kit.dart';
import '../../core/ui/kit/kit_card.dart';
import '../../core/ui/kit/kit_metrics.dart';
import '../../core/ui/kit/page_bar.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import 'master_data_counts.dart';
import 'master_data_kinds.dart';

class MasterDataPage extends ConsumerStatefulWidget {
  const MasterDataPage({super.key});

  @override
  ConsumerState<MasterDataPage> createState() => _MasterDataPageState();
}

class _MasterDataPageState extends ConsumerState<MasterDataPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final features = ref.watch(enabledFeaturesSyncProvider);
    final held = ref.watch(myPermissionsProvider);
    final workspaceId = ref.watch(currentWorkspaceProvider).value?.id;
    final query = foldForSearch(_query);
    final kinds = [
      for (final k in masterDataKindsFor(features.contains, held))
        if (query.isEmpty || foldForSearch(k.title(l10n)).contains(query)) k,
    ];
    return Scaffold(
      appBar: pageBar(
        context,
        title: l10n.deploymentKindMasterData,
        actions: [
          HelpDot(l10n.deploymentKindMasterData, anchor: HelpAnchor.masterData),
        ],
      ),
      body: ListView(
        key: const ValueKey('master-data-list'),
        padding: AppSpacing.gutterAll,
        children: [
          Text(l10n.masterDataIntro),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            key: const ValueKey('master-data-search'),
            controller: _search,
            label: l10n.invoicingSearch,
            prefixIcon: const Icon(Icons.search),
            textInputAction: TextInputAction.search,
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
          if (kinds.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xl),
              child: Text(
                l10n.masterDataNoMatch,
                key: const ValueKey('master-data-no-match'),
              ),
            ),
          for (final group in MasterDataGroup.values)
            if (kinds.any((k) => k.group == group))
              _Group(
                group: group,
                kinds: [
                  for (final k in kinds)
                    if (k.group == group) k,
                ],
                workspaceId: workspaceId,
              ),
        ],
      ),
    );
  }
}

/// One titled group and its cards, in as many columns as the room allows.
class _Group extends StatelessWidget {
  const _Group({
    required this.group,
    required this.kinds,
    required this.workspaceId,
  });

  final MasterDataGroup group;
  final List<MasterDataKind> kinds;
  final String? workspaceId;

  static int _columns(double room) => switch (WindowClass.ofWidth(room)) {
    WindowClass.compact => 1,
    WindowClass.medium || WindowClass.expanded => 2,
    WindowClass.large || WindowClass.extraLarge => 3,
  };

  @override
  Widget build(BuildContext context) {
    final title = group.title(context.l10n);
    return Padding(
      key: ValueKey('master-data-group-${group.name}'),
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              HelpDot(title, anchor: group.anchor),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, box) {
              final columns = _columns(box.maxWidth);
              final width =
                  (box.maxWidth - AppSpacing.md * (columns - 1)) / columns;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  for (final k in kinds)
                    SizedBox(
                      width: width,
                      child: _Card(kind: k, workspaceId: workspaceId),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One kind: its name, what it is and its count; a tap opens its screen. A
/// count that could not be read is said below, with its own Try again, never
/// inside the tap target.
class _Card extends ConsumerWidget {
  const _Card({required this.kind, required this.workspaceId});

  final MasterDataKind kind;
  final String? workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final workspaceId = this.workspaceId;
    final source = workspaceId == null
        ? null
        : masterDataSource(kind, workspaceId);
    final value = source == null ? null : ref.watch(source);
    final failed =
        value != null && !value.hasValue && value.hasError && !value.isLoading;
    return KitCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // one target for the whole card, its count included
          MergeSemantics(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: ValueKey('master-data-card-${kind.name}'),
                borderRadius: AppRadius.xlAll,
                onTap: () => context.push(kind.route),
                child: Padding(
                  padding: const EdgeInsets.all(KitMetrics.cardPadding),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(kind.icon, color: theme.colorScheme.primary),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kind.title(l10n),
                              style: theme.textTheme.titleSmall,
                            ),
                            Text(
                              kind.description(l10n),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            if (value != null && value.hasValue)
                              Text(
                                l10n.masterDataCount(value.requireValue.length),
                                key: ValueKey('master-data-count-${kind.name}'),
                                style: theme.textTheme.labelMedium,
                              )
                            else if (!failed)
                              const LinearProgressIndicator(
                                key: ValueKey('master-data-reading'),
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (failed)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KitMetrics.cardPadding,
                0,
                KitMetrics.cardPadding,
                KitMetrics.cardPadding,
              ),
              child: ReadFailureBanner(
                error: value.error!,
                onRetry: () => ref.invalidate(source!),
                retryKey: ValueKey('master-data-retry-${kind.name}'),
              ),
            ),
        ],
      ),
    );
  }
}
