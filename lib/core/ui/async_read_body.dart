// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3061 — the one answer to "what does a list show while its read is in
// flight, failed or refused": the content when there is any, a quiet
// progress line while it is refreshed, and a failure that says what kind it
// is and offers the same read again. A failure is never drawn as an empty
// list.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cache/read_failure.dart';
import '../l10n/context_l10n.dart';
import '../theme/app_spacing.dart';
import 'inline_banner.dart';
import 'loading_view.dart';

/// The failed read of [error], in words a person can act on: no connection,
/// no access, or a plain failure; with "Try again" repeating the same read.
/// Announced once when it appears (a live region), never the list around it.
class ReadFailureBanner extends StatelessWidget {
  const ReadFailureBanner({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (icon, text) = switch (classifyReadFailure(error)) {
      ReadFailure.transient => (Icons.cloud_off_outlined, l10n.readStateOffline),
      ReadFailure.denied => (Icons.lock_outline, l10n.readStateDenied),
      ReadFailure.other => (Icons.error_outline, l10n.workspaceGenericError),
    };
    return Semantics(
      liveRegion: true,
      child: InlineBanner(
        key: const ValueKey('read-failure'),
        icon: icon,
        text: text,
        // A denial does not get better by asking again, but the person may
        // have just been given the access: the way forward stays.
        actionLabel: l10n.commonRetry,
        onAction: onRetry,
      ),
    );
  }
}

/// Loading, content, refresh and failure of one [AsyncValue].
///
/// - no value yet and no error: [LoadingView] (distinct from empty);
/// - a value: [data], with a thin progress line while it is refreshed and a
///   [ReadFailureBanner] above it when the refresh failed (the old content
///   stays);
/// - an error with nothing to show: [ReadFailureBanner] alone, replaced by
///   [LoadingView] while Try again is in flight.
class AsyncReadBody<T> extends StatelessWidget {
  const AsyncReadBody({
    super.key,
    required this.value,
    required this.onRetry,
    required this.data,
  });

  final AsyncValue<T> value;

  /// Repeats the same read (invalidates the provider behind [value]).
  final VoidCallback onRetry;

  final Widget Function(T value) data;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (value.isLoading)
            const LinearProgressIndicator(key: ValueKey('read-refreshing')),
          if (value.hasError)
            ReadFailureBanner(error: value.error!, onRetry: onRetry),
          Expanded(child: data(value.requireValue)),
        ],
      );
    }
    // Try again in flight: the failure gives way to the progress, not the
    // other way round, so the person sees the request was taken.
    if (value.hasError && !value.isLoading) {
      return ListView(
        padding: AppSpacing.mdAll,
        children: [ReadFailureBanner(error: value.error!, onRetry: onRetry)],
      );
    }
    return const LoadingView();
  }
}
