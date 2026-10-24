// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/providers/auth_providers.dart';
import '../domain/conversation_delivery.dart';
import '../domain/conversation_target.dart';

part 'conversation_pane_providers.g.dart';

/// The conversation the messenger's thread pane shows, or none. Nothing is
/// ever selected for the person: only a tap, or a person picked in the
/// directory, opens a thread — and only an opened thread marks anything
/// read. A new account starts with no conversation open.
@Riverpod(keepAlive: true)
class ConversationSelection extends _$ConversationSelection {
  @override
  ConversationTarget? build() {
    ref.watch(authStateProvider);
    return null;
  }

  /// Shows [target] in the pane (a phone: the focused thread).
  void open(ConversationTarget target) => state = target;

  /// Back to the list.
  void close() => state = null;
}

/// Unsent text per conversation, for this session only: kept while the
/// person moves between conversations, tabs and layouts, never written to
/// the device or the cloud, and dropped with the account that wrote it.
///
/// Every write names the account it was made under: a completion that
/// arrives after the account changed (a send that lands late) is refused,
/// so it can neither clear nor fill the next person's drafts.
@Riverpod(keepAlive: true)
class ConversationDrafts extends _$ConversationDrafts {
  String? _account;

  @override
  Map<String, String> build() {
    _account = ref.watch(authStateProvider).value;
    return const {};
  }

  /// The unsent text of [key] for [account], '' when none.
  String draftOf(String? account, String key) =>
      account != null && account == _account ? state[key] ?? '' : '';

  /// Keeps [text] as [key]'s draft; an empty text forgets it.
  void keep(String? account, String key, String text) {
    if (account == null || account != _account) return;
    if ((state[key] ?? '') == text) return;
    state = {
      for (final e in state.entries)
        if (e.key != key) e.key: e.value,
      if (text.isNotEmpty) key: text,
    };
  }

  /// Forgets [key]'s draft: what it held went out.
  void clear(String? account, String key) => keep(account, key, '');

  /// Forgets [key]'s draft only while it still holds [sent]: a delivery
  /// that answers late never takes what was typed since.
  void clearIfStill(String? account, String key, String sent) {
    if (draftOf(account, key).trim() == sent) clear(account, key);
  }
}

/// The sends still waiting on an answer, per conversation (the draft key),
/// for this session: a thread opened again while its send is in flight
/// shows neither the text nor a Send that could repeat it, and one whose
/// send went unconfirmed says so until the person reads it again.
///
/// Every write names the account it was made under: a send that answers
/// after the account changed marks nothing for the next person.
@Riverpod(keepAlive: true)
class ConversationSends extends _$ConversationSends {
  String? _account;

  @override
  Map<String, SendPhase> build() {
    _account = ref.watch(authStateProvider).value;
    return const {};
  }

  /// Sets [key]'s phase for [account]; null settles it.
  void mark(String? account, String key, SendPhase? phase) {
    if (account == null || account != _account || state[key] == phase) return;
    state = {
      for (final e in state.entries)
        if (e.key != key) e.key: e.value,
      key: ?phase,
    };
  }
}
