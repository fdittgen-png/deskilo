// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_widget/markdown_widget.dart';

import '../../../../core/links/link_launcher.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/help_providers.dart';

/// Locales the bundled help exists in; anything else falls back to English.
const helpLocales = {'en', 'fr', 'de', 'es', 'it'};

/// The asset holding the compiled help for [languageCode]. The files are
/// generated from the wiki user guides by `tool/build_help.dart` — the
/// wiki is the single source of truth, the app ships an offline copy.
String helpAssetFor(String languageCode) =>
    'assets/help/${helpLocales.contains(languageCode) ? languageCode : 'en'}.md';

/// In-app help: the wiki user guide, bundled at build time and rendered
/// natively — fully offline, identical on Android, iOS, and F-Droid.
/// The outline button opens a table of contents that jumps to a section.
class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  final _toc = TocController();

  @override
  void dispose() {
    _toc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.helpTitle ?? 'Help'),
        actions: [
          Builder(
            builder: (context) => IconButton(
              key: const ValueKey('help-toc-button'),
              icon: const Icon(Icons.toc),
              tooltip: l10n?.helpContents ?? 'Contents',
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: SafeArea(child: TocWidget(controller: _toc)),
      ),
      body: Builder(
        builder: (context) {
          final data = ref.watch(helpContentProvider(languageCode)).value;
          if (data == null) {
            // Asset loads in one frame; a spinner would only flash.
            return const SizedBox.shrink();
          }
          return MarkdownWidget(
            data: data,
            tocController: _toc,
            // Selection leaves a pending SelectionArea timer (and help is
            // read-only anyway) — keep the tree timer-free for tests.
            selectable: false,
            padding: AppSpacing.gutterAll,
            config: (dark ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig)
                .copy(configs: [
              LinkConfig(
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
                onTap: (url) {
                  final uri = Uri.tryParse(url);
                  if (uri != null) ref.read(linkLauncherProvider)(uri);
                },
              ),
            ]),
          );
        },
      ),
    );
  }
}
