// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 -- the till's quick keys: the items as a grid of keys, each in the colour its item settings give it, under the
// category chips the items' till categories make. The keys without a category are under "All" only.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/loading_view.dart';
import '../domain/counter_till.dart';
import 'till_text.dart';

/// A colour typed `#rrggbb` as the settings keep it, or null when it is not one.
Color? _tillKeyColour(String? hex) {
  final m = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(hex ?? '');
  if (m == null) return null;
  final rgb = int.parse(m[1]!, radix: 16);
  return Color.fromARGB(255, (rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF);
}

/// The categories of [keys], in the order of their names, each once.
List<String> _tillCategories(List<TillKey> keys) =>
    ({for (final k in keys) if (k.category != null && k.category!.trim().isNotEmpty) k.category!.trim()}.toList()..sort());

class TillKeys extends StatefulWidget {
  const TillKeys({super.key, required this.items, required this.onTap});

  final AsyncValue<List<TillKey>> items;
  final void Function(TillKey) onTap;

  @override
  State<TillKeys> createState() => _TillKeysState();
}

class _TillKeysState extends State<TillKeys> {
  /// The category shown; null is every key.
  String? _category;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return widget.items.when(
      loading: () => const LoadingView(),
      error: (e, _) => Center(child: Text(tillProblemText(l10n, e), textAlign: TextAlign.center)),
      data: (list) {
        if (list.isEmpty) return Center(child: Text(l10n.tillKeysEmpty, textAlign: TextAlign.center));
        final categories = _tillCategories(list);
        // a category that went away (the keys were read again) is not kept
        final shown = categories.contains(_category) ? _category : null;
        final keys = [for (final k in list) if (shown == null || k.category?.trim() == shown) k];
        return Column(
          children: [
            if (categories.isNotEmpty)
              SizedBox(
                height: 56,
                child: ListView(
                  key: const ValueKey('till-categories'),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  children: [
                    for (final c in [null, ...categories])
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: ChoiceChip(
                          key: ValueKey('till-category-${c ?? 'all'}'),
                          label: Text(c ?? l10n.tillCategoryAll),
                          selected: shown == c,
                          onSelected: (_) => setState(() => _category = c),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 160,
                  mainAxisExtent: 64,
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                ),
                itemCount: keys.length,
                itemBuilder: (context, i) => _Key(item: keys[i], onTap: widget.onTap),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.item, required this.onTap});

  final TillKey item;
  final void Function(TillKey) onTap;

  @override
  Widget build(BuildContext context) {
    final colour = _tillKeyColour(item.colour);
    final text = Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center);
    final key = ValueKey('till-key-${item.id}');
    if (colour == null) return FilledButton.tonal(key: key, onPressed: () => onTap(item), child: text);
    // the label stays readable on whatever colour the item was given
    final on = ThemeData.estimateBrightnessForColor(colour) == Brightness.dark ? Colors.white : Colors.black;
    return FilledButton(
      key: key,
      style: FilledButton.styleFrom(backgroundColor: colour, foregroundColor: on),
      onPressed: () => onTap(item),
      child: text,
    );
  }
}
