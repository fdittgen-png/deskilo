// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderBase, Refreshable;

/// #3742 — the retry of a business's own policy read (its reminder rules,
/// its document template, its billing and split rules): none. A screen or
/// an action that needs the policy says at once that it could not be read,
/// with Try again, instead of waiting through the automatic retries.
Duration? noPolicyRetry(int count, Object error) => null;

/// #3742 — a policy an action needs, read now. A failure the provider
/// remembers (it does not retry on its own) is asked again first, so a
/// second tap or a Retry can succeed; a read still running is awaited, so
/// the first action of a session never meets "not read yet". Throws when
/// the policy cannot be read. Called as
/// `readPolicy(ref, dunningRulesProvider, dunningRulesProvider.future)`.
Future<T> readPolicy<T>(
  WidgetRef ref,
  ProviderBase<AsyncValue<T>> policy,
  Refreshable<Future<T>> future,
) {
  if (ref.read(policy).hasError) ref.invalidate(policy);
  return ref.read(future);
}
