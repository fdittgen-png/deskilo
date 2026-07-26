// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_radius.dart';
import '../core/ui/motion.dart';
import '../l10n/app_localizations.dart';
import 'boot.dart';

/// The branded boot splash (field request): shown from the very first
/// Flutter frame until [bootReadyProvider] has warmed the data the home
/// screen needs, then cross-faded away — the user sees the logo, then
/// the finished screen, never the form assembling itself.
///
/// Sits in [MaterialApp.builder], so it covers every route (including
/// the router's own startup redirects) and inherits the app theme.
class BootSplash extends ConsumerWidget {
  const BootSplash({super.key, required this.child});

  /// The routed app, handed in by [MaterialApp.builder].
  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Error counts as ready — the warm-up is best-effort by contract
    // (boot.dart caps and tolerates everything).
    final ready = !ref.watch(bootReadyProvider).isLoading;
    return AnimatedSwitcher(
      duration: AppMotion.viewSwitch,
      child: ready
          ? (child ?? const SizedBox.shrink())
          : const _SplashScreen(),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      key: const ValueKey('boot-splash'),
      color: scheme.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: AppRadius.xxlAll,
              child: Image.asset(
                'assets/icon/icon_full.png',
                width: 96,
                height: 96,
                // The asset ships with the app; if it ever goes missing,
                // boot must not crash over a logo.
                errorBuilder: (_, _, _) => const SizedBox.square(
                  dimension: 96,
                  child: Icon(Icons.event_seat_outlined, size: 64),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)?.appTitle ?? 'DesKilo',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 96,
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
