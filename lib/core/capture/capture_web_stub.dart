// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Non-web half of the web capture seam (#1824): a native window is
// protected by its own platform (FLAG_SECURE, sharingType, display
// affinity, the iOS capture observers), so nothing here ever obscures.

Stream<bool> webObscuredChanges() => const Stream<bool>.empty();
