// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1277 S3 — the owner's wording editor.
//
// S1 gave the server the allow-list and the keyed writer; S2 made the
// 33 terms render through the workspace's own vocabulary. This is where
// an owner actually renames one.
//
// Three rules the earlier slices established, kept visible here:
//
//   * browse by SURFACE, not by key. Two terms share an English word
//     (`shellReserveButton`/`planReserveButton`, both "Reserve"), so a
//     list of words alone could not tell an owner which one they are
//     changing;
//   * the product's own word is always on screen beside the override,
//     for the locale being EDITED — which is not necessarily the one
//     the app runs in, hence the delegate load below;
//   * RESET REMOVES. Writing the default back would freeze that word
//     against every future product rewording, which is the one thing a
//     reset must not do (the server takes `null` for exactly this).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/lexicon.dart';
import '../../../../core/l10n/lexicon_defaults.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/workspace_providers.dart';

class WordingScreen extends ConsumerStatefulWidget {
  const WordingScreen({super.key});

  @override
  ConsumerState<WordingScreen> createState() => _WordingScreenState();
}

class _WordingScreenState extends ConsumerState<WordingScreen> {
  final _search = TextEditingController();
  String? _locale;
  bool _changedOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The workspace's own language first: an owner renaming words is
  /// almost always writing the language their members read.
  ///
  /// When the space has declared none, the language the OWNER is reading
  /// comes next — not `supportedLocales.first`, which is `de` by
  /// alphabet and would open the editor in German for everybody who
  /// never set a workspace language.
  List<String> _locales(String? workspaceLocale, String appLocale) {
    final codes = [
      for (final l in AppLocalizations.supportedLocales) l.languageCode,
    ];
    for (final preferred in [appLocale, workspaceLocale]) {
      if (preferred != null && codes.contains(preferred)) {
        codes
          ..remove(preferred)
          ..insert(0, preferred);
      }
    }
    return codes;
  }

  Future<void> _write(String locale, String key, String? text) async {
    // Everything context-dependent is read BEFORE the first await: the
    // rest of this method is an async gap.
    final l10n = AppLocalizations.of(context);
    final errorText =
        l10n?.workspaceGenericError ?? 'Something went wrong. Please try again.';
    // The DECISION, not the repository (#1234 / ADR 0024): this widget
    // says what the owner asked for and does not know what a repository
    // is. `rename` treats an emptied box as a reset, so the two cannot
    // drift apart.
    final terms = ref.read(wordingTermsProvider);
    final workspace = await ref.read(currentWorkspaceProvider.future);
    if (workspace == null || !mounted) return;
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'wording save failed',
      errorText: errorText,
      action: () => text == null
          ? terms.reset(workspaceId: workspace.id, locale: locale, key: key)
          : terms.rename(
              workspaceId: workspace.id,
              locale: locale,
              key: key,
              text: text,
            ),
    );
    if (!ok || !mounted) return;
    ref.invalidate(lexiconProvider);
    AppSnack.success(context, l10n?.wordingSavedOne ?? 'Saved');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final overrides = ref.watch(lexiconProvider);
    final locales = _locales(
      (workspace?.defaultLocale ?? '').isEmpty ? null : workspace!.defaultLocale,
      Localizations.localeOf(context).languageCode,
    );
    final locale = _locale ?? locales.first;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.wordingTitle ?? 'Wording'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: DropdownButton<String>(
              key: const ValueKey('wording-locale'),
              value: locale,
              underline: const SizedBox.shrink(),
              onChanged: (value) => setState(() => _locale = value),
              items: [
                for (final code in locales)
                  DropdownMenuItem(value: code, child: Text(code.toUpperCase())),
              ],
            ),
          ),
        ],
      ),
      body: switch (overrides) {
        AsyncData(value: final raw) => _body(context, l10n, raw, locale),
        AsyncError() => Center(
            child: Text(l10n?.workspaceGenericError ?? 'Something went wrong.'),
          ),
        _ => const LoadingView(),
      },
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations? l10n,
    Map<String, dynamic> raw,
    String locale,
  ) {
    final theme = Theme.of(context);
    final mine = (raw[locale] as Map?)?.cast<String, dynamic>() ?? const {};

    // The defaults must be the EDITED locale's, not the app's, so the
    // delegate is loaded for it. `AppLocalizations.of(context)` would
    // show French defaults while an owner edits the German words.
    return FutureBuilder<AppLocalizations>(
      future: AppLocalizations.delegate.load(Locale(locale)),
      builder: (context, snapshot) {
        final defaults = snapshot.data;
        if (defaults == null) return const LoadingView();
        final query = _search.text.trim().toLowerCase();

        bool matches(String key) {
          final override = mine[key] as String?;
          if (_changedOnly && (override == null || override.isEmpty)) {
            return false;
          }
          if (query.isEmpty) return true;
          final product = lexiconDefault(defaults, key).toLowerCase();
          return product.contains(query) ||
              (override ?? '').toLowerCase().contains(query);
        }

        final bySurface = <LexiconSurface, List<String>>{};
        for (final entry in lexiconAllowList.entries) {
          if (!matches(entry.key)) continue;
          bySurface.putIfAbsent(entry.value.surface, () => []).add(entry.key);
        }

        return ListView(
          padding: AppSpacing.lgAll,
          children: [
            Text(
              l10n?.wordingIntro ??
                  'Rename a small, approved set of product words. Everything '
                      'else keeps the product\'s own wording.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey('wording-search'),
              controller: _search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: l10n?.wordingSearch ?? 'Search a word',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilterChip(
              key: const ValueKey('wording-changed-only'),
              label: Text(l10n?.wordingChangedOnly ?? 'Changed only'),
              selected: _changedOnly,
              onSelected: (value) => setState(() => _changedOnly = value),
            ),
            const SizedBox(height: AppSpacing.md),
            if (bySurface.isEmpty)
              Text(
                l10n?.wordingNone ?? 'No term matches.',
                style: theme.textTheme.bodyMedium,
              ),
            for (final surface in LexiconSurface.values)
              if (bySurface[surface] != null) ...[
                Text(
                  _surfaceName(l10n, surface),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final key in bySurface[surface]!)
                  _TermTile(
                    termKey: key,
                    product: lexiconDefault(defaults, key),
                    word: mine[key] as String?,
                    l10n: l10n,
                    onSave: (text) => _write(locale, key, text),
                    onReset: () => _write(locale, key, null),
                  ),
                const SizedBox(height: AppSpacing.md),
              ],
          ],
        );
      },
    );
  }

  String _surfaceName(AppLocalizations? l10n, LexiconSurface surface) =>
      switch (surface) {
        LexiconSurface.legend => l10n?.wordingSurfaceLegend ?? 'Legend',
        LexiconSurface.plan => l10n?.wordingSurfacePlan ?? 'The space',
        LexiconSurface.navigation =>
          l10n?.wordingSurfaceNavigation ?? 'Navigation',
        LexiconSurface.booking => l10n?.wordingSurfaceBooking ?? 'Booking',
      };
}

/// One term: the workspace's word if it has one, the product's beneath,
/// and a reset that REMOVES rather than writes the default back.
class _TermTile extends StatelessWidget {
  const _TermTile({
    required this.termKey,
    required this.product,
    required this.word,
    required this.l10n,
    required this.onSave,
    required this.onReset,
  });

  final String termKey;
  final String product;
  /// The workspace's own word, or null when it uses the
  /// product's. NOT named `override`: that is the annotation.
  final String? word;
  final AppLocalizations? l10n;
  final ValueChanged<String> onSave;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final renamed = (word ?? '').isNotEmpty;
    return ListTile(
      key: ValueKey('wording-term-$termKey'),
      contentPadding: EdgeInsets.zero,
      title: Text(renamed ? word! : product),
      subtitle: Text(
        '${l10n?.wordingDefaultLabel ?? 'Product default'}: $product',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: renamed
          ? IconButton(
              key: ValueKey('wording-reset-$termKey'),
              tooltip: l10n?.wordingReset ?? 'Reset',
              icon: const Icon(Icons.undo),
              onPressed: onReset,
            )
          : const Icon(Icons.edit_outlined),
      onTap: () => _edit(context),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final controller = TextEditingController(text: word ?? product);
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product),
        content: TextField(
          key: const ValueKey('wording-field'),
          controller: controller,
          autofocus: true,
          maxLength: 120,
          decoration: InputDecoration(
            labelText: l10n?.wordingTitle ?? 'Wording',
            helperText: l10n?.wordingResetHint ??
                'Reset removes your word and brings the product\'s back.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('wording-save'),
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null) return;
    // An empty box means "no word of my own", which is the same
    // statement as Reset — and the server takes null for it.
    if (text.isEmpty || text == product) {
      onReset();
    } else {
      onSave(text);
    }
  }
}
