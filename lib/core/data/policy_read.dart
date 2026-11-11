// SPDX-License-Identifier: AGPL-3.0-or-later

/// #3742 — the retry of a business's own policy read (its reminder rules,
/// its document template, its billing and split rules): none. A screen or
/// an action that needs the policy says at once that it could not be read,
/// with Try again, instead of waiting through the automatic retries.
Duration? noPolicyRetry(int count, Object error) => null;
