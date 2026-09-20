// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1514 — the strip that makes filming mode impossible to forget.
//
// The requirement is not "there is a switch somewhere". It is that
// nobody records for ten minutes believing the mode was on, and — the
// other way round, which is the dangerous one — that nobody works for a
// day on invented names believing they are real. So this is a permanent
// strip above the navigator, not a snackbar, not a badge on one screen
// and not a colour somebody has to notice.
//
// It renders INSIDE the MaterialApp's builder, next to the Demo bar
// (#1379), for the same reason that one does: above the navigator there
// is neither a theme nor a translation. Off, it returns its child
// untouched and costs one boolean read.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_spacing.dart';
import '../ui/app_snack.dart';
import 'recording_providers.dart';

/// #1514 — the other half of the seam: a form that is SHOWING an
/// invented person must not be allowed to save it.
///
/// Substituting on the way out would otherwise substitute on the way
/// back in: an identity form prefilled from the seam and saved would
/// write the pseudonym over somebody's real details, and the record
/// would be gone. The three identity forms call this first; it says so
/// and refuses, rather than saving something that looks like a success.
///
/// Returns true when the caller must stop.
bool refusedWhileRecording(BuildContext context, WidgetRef ref) {
  if (!ref.read(recordingPrivacyProvider)) return false;
  AppSnack.error(
    context,
    AppLocalizations.of(context)?.recordingPrivacyWriteRefused ??
        'Not while filming mode is on: this form is showing an invented '
            'person, and saving it would write that over somebody\'s '
            'real details. Switch filming mode off first.',
  );
  return true;
}

/// Wraps [child] with the filming-mode strip while the mode is on.
class RecordingBanner extends ConsumerWidget {
  const RecordingBanner({required this.child, super.key});

  static const Key bannerKey = Key('recording-privacy-banner');

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(recordingPrivacyProvider)) return child;
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final label = l10n?.recordingPrivacyBadge ??
        'Filming mode — invented people';
    final hint = l10n?.recordingPrivacyBadgeHint ??
        'Filming mode is on: every name, e-mail, telephone number, '
            'address and photograph on screen belongs to an invented '
            'person.';
    return Column(
      children: [
        Material(
          // The tertiary container, not the demo bar's secondary one: the
          // two can never be on together (Demo has no live data to
          // protect), but they must not be mistaken for one another in a
          // screenshot either.
          color: scheme.tertiaryContainer,
          child: SafeArea(
            key: bannerKey,
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Semantics(
                label: hint,
                child: Row(
                  children: [
                    Icon(
                      Icons.videocam_outlined,
                      size: 18,
                      color: scheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: scheme.onTertiaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
