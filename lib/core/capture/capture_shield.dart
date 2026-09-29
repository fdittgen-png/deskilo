// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_spacing.dart';
import 'capture_protection.dart';
import 'capture_providers.dart';

/// #1824 — wraps one messenger thread in the platform's strongest
/// protection for as long as the thread is on screen.
///
/// Mounting it holds the window's protection ([CaptureProtection.enable]);
/// unmounting — leaving the thread — lets go. On iOS a screenshot cannot
/// be refused, so it is ANNOUNCED: [onScreenshot] posts the notice into
/// the conversation. While the screen is recorded or mirrored the thread
/// is replaced by a sentence saying why. On the web, which can block
/// nothing, the thread says so, carries a faint watermark with the
/// reader's name and blurs whenever the page is not being looked at.
class CaptureShield extends ConsumerStatefulWidget {
  const CaptureShield({
    super.key,
    required this.child,
    this.enabled = true,
    this.onScreenshot,
  });

  final Widget child;

  /// Off when the workspace switched `captureProtection` off — the
  /// thread then renders exactly as it always did.
  final bool enabled;

  final VoidCallback? onScreenshot;

  @override
  ConsumerState<CaptureShield> createState() => _CaptureShieldState();
}

class _CaptureShieldState extends ConsumerState<CaptureShield> {
  CaptureProtection? _held;
  StreamSubscription<CaptureSignal>? _signals;
  StreamSubscription<bool>? _obscured;
  bool _recording = false;
  bool _blurred = false;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _hold();
  }

  @override
  void didUpdateWidget(CaptureShield old) {
    super.didUpdateWidget(old);
    if (widget.enabled != old.enabled) {
      widget.enabled ? _hold() : _release();
    }
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  void _hold() {
    if (_held != null) return;
    final protection = ref.read(captureProtectionProvider);
    _held = protection;
    _recording = protection.captured;
    _signals = protection.signals.listen((signal) {
      switch (signal) {
        case CaptureSignal.screenshot:
          widget.onScreenshot?.call();
        case CaptureSignal.recordingStarted || CaptureSignal.recordingStopped:
          if (mounted) {
            setState(() => _recording = protection.captured);
          }
      }
    });
    _obscured = protection.obscured.listen((value) {
      if (mounted) setState(() => _blurred = value);
    });
    unawaited(protection.enable());
  }

  void _release() {
    final held = _held;
    if (held == null) return;
    _held = null;
    unawaited(_signals?.cancel());
    unawaited(_obscured?.cancel());
    _signals = null;
    _obscured = null;
    _recording = false;
    _blurred = false;
    unawaited(held.disable());
  }

  @override
  Widget build(BuildContext context) {
    final held = _held;
    if (!widget.enabled || held == null) return widget.child;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (_recording) {
      return Center(
        key: const ValueKey('capture-recording-hidden'),
        child: Padding(
          padding: AppSpacing.lgAll,
          child: Text(
            l10n?.captureRecordingHidden ??
                'Hidden while your screen is recorded or mirrored.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (held.canBlock) return widget.child;
    final reader = ref.watch(captureReaderNameProvider);
    return Column(
      children: [
        Container(
          key: const ValueKey('capture-web-notice'),
          width: double.infinity,
          color: theme.colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Text(
            l10n?.captureWebNotice ??
                'Your browser cannot block screenshots of this conversation.',
            style: theme.textTheme.labelSmall,
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: ImageFiltered(
                  key: ValueKey('capture-blur-$_blurred'),
                  enabled: _blurred,
                  imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: widget.child,
                ),
              ),
              if (reader.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Transform.rotate(
                        angle: -0.4,
                        child: Text(
                          reader,
                          key: const ValueKey('capture-watermark'),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: .06,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
