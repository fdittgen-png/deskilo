// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/auth_providers.dart';
import '../../../workspace/presentation/widgets/composer_frame.dart';
import '../../domain/conversation_delivery.dart';
import '../../providers/conversation_pane_providers.dart';
import 'context_thread_parts.dart';

/// A thread's composer under the messenger's rules (#2556): the unsent text
/// is kept per conversation for the session (ConversationDrafts), one send
/// at a time per conversation also across a thread opened again
/// (ConversationSends), a send with no answer after
/// [ConversationDelivery.unconfirmedAfter] is "Delivery not confirmed" and
/// never resent on its own, and text typed while a send goes out is never
/// taken by its answer: a delivery empties the field only while it still
/// holds what was sent, and a refusal gives the text back only to a field
/// nobody typed in since.
class GuardedComposer extends ConsumerStatefulWidget {
  const GuardedComposer({
    super.key,
    required this.draftKey,
    required this.attempt,
    required this.build,
    required this.onReview,
  });

  /// The conversation's draft key (conversationDraftKey).
  final String draftKey;
  final Future<bool> Function(String body) attempt;
  final ComposerBuild build;

  /// Reads the conversation again after an unconfirmed send.
  final VoidCallback onReview;

  @override
  ConsumerState<GuardedComposer> createState() => _GuardedComposerState();
}

class _GuardedComposerState extends ConsumerState<GuardedComposer> {
  late final _draft = ThreadDraft(
    ref.read(authStateProvider).value,
    ref,
    () => widget.draftKey,
  );

  /// The composer's seed and generation: a send that settles after the
  /// thread opened gives an untouched composer the draft as it is then.
  late String _seed = _draft.restored;
  int _gen = 0;

  /// What the field holds, as last reported.
  late String _typed = _draft.restored;
  bool _busy = false;

  void _changed(String text) {
    _typed = text;
    _draft.keep(text);
  }

  Future<bool> _send(String body) async {
    if (_busy || ref.read(conversationSendsProvider)[_draft.key] != null) {
      return false;
    }
    final sent = _typed.trim();
    setState(() => _busy = true);
    final ok = await _draft.deliver(sent, widget.attempt(body)) ?? false;
    if (!mounted) return ok;
    setState(() => _busy = false);
    // Only what went out leaves the field: text typed since stays.
    final empties = ok && _typed.trim() == sent;
    if (empties) _typed = '';
    return empties;
  }

  /// A send settled: an untouched composer shows the draft as it is now —
  /// the text back after a refusal, nothing after a late delivery.
  void _settled() {
    final draft = _draft.current;
    if (!mounted || _busy || draft == _typed) return;
    setState(() {
      _seed = _typed = draft;
      _gen++;
    });
  }

  void _review() {
    _draft.reviewed();
    widget.onReview();
  }

  @override
  Widget build(BuildContext context) {
    final key = _draft.key;
    ref
      ..listen(
        conversationSendsProvider.select((s) => s[key]),
        (before, now) => before != null && now == null ? _settled() : null,
      )
      ..listen(
        conversationDraftsProvider.select((d) => d[key]),
        (_, _) => _settled(),
      );
    final phase = ref.watch(conversationSendsProvider.select((s) => s[key]));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (phase != null && !(_busy && phase == SendPhase.inFlight))
          DeliveryNote(phase, onReview: _review),
        KeyedSubtree(
          key: ValueKey(_gen),
          child: widget.build(_seed, _changed, _send),
        ),
      ],
    );
  }
}
