// SPDX-License-Identifier: AGPL-3.0-or-later
// Inspect real shared controls without starting the application.
import 'package:deskilo/app/theme.dart';
import 'package:deskilo/core/l10n/context_l10n.dart';
import 'package:deskilo/core/theme/app_spacing.dart';
import 'package:deskilo/core/ui/form_kit.dart';
import 'package:deskilo/core/ui/inline_banner.dart';
import 'package:deskilo/core/ui/kit/kit_action_button.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

void main() => runApp(const DeskiloCatalog());

class DeskiloCatalog extends StatelessWidget {
  const DeskiloCatalog({super.key, this.initialRoute = '/'});

  final String initialRoute;

  @override
  Widget build(BuildContext context) => Widgetbook.material(
    initialRoute: initialRoute,
    directories: [
      WidgetbookComponent(
        name: 'KitActionButton',
        useCases: [WidgetbookUseCase(name: 'States', builder: _button)],
      ),
      WidgetbookComponent(
        name: 'AppTextField',
        useCases: [WidgetbookUseCase(name: 'States', builder: _field)],
      ),
      WidgetbookComponent(
        name: 'InlineBanner',
        useCases: [WidgetbookUseCase(name: 'States', builder: _banner)],
      ),
    ],
    addons: [
      // The viewport copies this theme before applying its platform override.
      MaterialThemeAddon(
        themes: [
          WidgetbookTheme(name: 'Light', data: DeskiloTheme.light()),
          WidgetbookTheme(name: 'Dark', data: DeskiloTheme.dark()),
        ],
      ),
      ViewportAddon([
        for (final width in [320.0, 390.0, 1280.0])
          ViewportData(
            name: '${width.toInt()} dp',
            width: width,
            height: 844,
            pixelRatio: 1,
            platform: width < 600
                ? TargetPlatform.android
                : TargetPlatform.windows,
          ),
      ]),
      TextScaleAddon(min: 1.0, max: 1.3, divisions: 1, initialScale: 1.0),
      LocalizationAddon(
        locales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        initialLocale: const Locale('en'),
      ),
    ],
  );
}

Widget _surface(Widget child) => Scaffold(
  body: SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Align(alignment: Alignment.topLeft, child: child),
    ),
  ),
);

Widget _button(BuildContext context) => _surface(
  KitActionButton(
    key: const ValueKey('catalog-button'),
    label: context.l10n.commonSave,
    busy: context.knobs.boolean(label: 'Busy'),
    tonal: context.knobs.boolean(label: 'Tonal'),
    onPressed: context.knobs.boolean(label: 'Enabled', initialValue: true)
        ? () async {}
        : null,
  ),
);

Widget _field(BuildContext context) => _surface(
  _FieldFixture(
    showError: context.knobs.boolean(label: 'Required error'),
    enabled: context.knobs.boolean(label: 'Enabled', initialValue: true),
  ),
);

class _FieldFixture extends StatefulWidget {
  const _FieldFixture({required this.showError, required this.enabled});

  final bool showError, enabled;

  @override
  State<_FieldFixture> createState() => _FieldFixtureState();
}

class _FieldFixtureState extends State<_FieldFixture> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppTextField(
    key: const ValueKey('catalog-field'),
    controller: _controller,
    label: context.l10n.authEmailLabel,
    error: widget.showError ? context.l10n.fieldProblemRequired : null,
    enabled: widget.enabled,
    keyboardType: TextInputType.emailAddress,
    autofillHints: const [AutofillHints.email],
  );
}

Widget _banner(BuildContext context) {
  final error = context.knobs.boolean(label: 'Error', initialValue: true);
  final action = context.knobs.boolean(label: 'Action', initialValue: true);
  return _surface(
    InlineBanner(
      key: const ValueKey('catalog-banner'),
      icon: error ? Icons.error_outline : Icons.info_outline,
      text: context.l10n.errorOffline,
      severity: error ? InlineBannerSeverity.error : InlineBannerSeverity.info,
      actionLabel: action ? context.l10n.commonRetry : null,
      onAction: action ? () {} : null,
    ),
  );
}
