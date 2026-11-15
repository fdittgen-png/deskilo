// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4018 — a messenger of its own (a full-screen dialog's, a sheet's) whose
// notices go with the context like the app's: when the person changes
// business or account, the shell says so here and every scoped messenger
// clears what it shows and what it queued. No timeout is touched.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How many times the context a notice belongs to has changed.
final noticeContextProvider = NotifierProvider<NoticeContext, int>(
  NoticeContext.new,
);

/// The context notices belong to.
class NoticeContext extends Notifier<int> {
  @override
  int build() => 0;

  /// The context changed: every scoped messenger clears.
  void changed() => state++;
}

/// A [ScaffoldMessenger] that clears its notices when the context changes.
class ScopedMessenger extends ConsumerStatefulWidget {
  const ScopedMessenger({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ScopedMessenger> createState() => _ScopedMessengerState();
}

class _ScopedMessengerState extends ConsumerState<ScopedMessenger> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    ref.listen(
      noticeContextProvider,
      (_, _) => _messenger.currentState?.clearSnackBars(),
    );
    return ScaffoldMessenger(key: _messenger, child: widget.child);
  }
}
