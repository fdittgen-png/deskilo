// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The conversation list of the active workspace (#687), newest activity
/// first — the order the server already applied, never re-sorted here.
///
/// Derived from [currentWorkspace] like every other workspace-scoped
/// provider, so switching profiles recomputes it with no extra plumbing.

@ProviderFor(conversations)
final conversationsProvider = ConversationsProvider._();

/// The conversation list of the active workspace (#687), newest activity
/// first — the order the server already applied, never re-sorted here.
///
/// Derived from [currentWorkspace] like every other workspace-scoped
/// provider, so switching profiles recomputes it with no extra plumbing.

final class ConversationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Conversation>>,
          List<Conversation>,
          FutureOr<List<Conversation>>
        >
    with
        $FutureModifier<List<Conversation>>,
        $FutureProvider<List<Conversation>> {
  /// The conversation list of the active workspace (#687), newest activity
  /// first — the order the server already applied, never re-sorted here.
  ///
  /// Derived from [currentWorkspace] like every other workspace-scoped
  /// provider, so switching profiles recomputes it with no extra plumbing.
  ConversationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'conversationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$conversationsHash();

  @$internal
  @override
  $FutureProviderElement<List<Conversation>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Conversation>> create(Ref ref) {
    return conversations(ref);
  }
}

String _$conversationsHash() => r'65305a8ce697e27f48561b5b93ba71c7ec5f1848';

/// Total unread across every conversation — the badge on the Messages
/// destination.
///
/// Summed from the list rather than counted separately: two queries that
/// answer "how many unread" independently is how a badge ends up
/// disagreeing with the screen it points at.

@ProviderFor(unreadMessages)
final unreadMessagesProvider = UnreadMessagesProvider._();

/// Total unread across every conversation — the badge on the Messages
/// destination.
///
/// Summed from the list rather than counted separately: two queries that
/// answer "how many unread" independently is how a badge ends up
/// disagreeing with the screen it points at.

final class UnreadMessagesProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// Total unread across every conversation — the badge on the Messages
  /// destination.
  ///
  /// Summed from the list rather than counted separately: two queries that
  /// answer "how many unread" independently is how a badge ends up
  /// disagreeing with the screen it points at.
  UnreadMessagesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'unreadMessagesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$unreadMessagesHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return unreadMessages(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$unreadMessagesHash() => r'f555979b37ab9acff3fcef590881a5efe2e9caa0';

/// The messages of one conversation, oldest first.

@ProviderFor(conversationMessages)
final conversationMessagesProvider = ConversationMessagesFamily._();

/// The messages of one conversation, oldest first.

final class ConversationMessagesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MemberNote>>,
          List<MemberNote>,
          FutureOr<List<MemberNote>>
        >
    with $FutureModifier<List<MemberNote>>, $FutureProvider<List<MemberNote>> {
  /// The messages of one conversation, oldest first.
  ConversationMessagesProvider._({
    required ConversationMessagesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'conversationMessagesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$conversationMessagesHash();

  @override
  String toString() {
    return r'conversationMessagesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<MemberNote>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MemberNote>> create(Ref ref) {
    final argument = this.argument as String;
    return conversationMessages(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationMessagesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$conversationMessagesHash() =>
    r'2fb490a27ae57a9668eef8e53265b4d9f9196ab5';

/// The messages of one conversation, oldest first.

final class ConversationMessagesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<MemberNote>>, String> {
  ConversationMessagesFamily._()
    : super(
        retry: null,
        name: r'conversationMessagesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The messages of one conversation, oldest first.

  ConversationMessagesProvider call(String conversationId) =>
      ConversationMessagesProvider._(argument: conversationId, from: this);

  @override
  String toString() => r'conversationMessagesProvider';
}

/// The roster of one conversation.

@ProviderFor(conversationParticipants)
final conversationParticipantsProvider = ConversationParticipantsFamily._();

/// The roster of one conversation.

final class ConversationParticipantsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ConversationParticipant>>,
          List<ConversationParticipant>,
          FutureOr<List<ConversationParticipant>>
        >
    with
        $FutureModifier<List<ConversationParticipant>>,
        $FutureProvider<List<ConversationParticipant>> {
  /// The roster of one conversation.
  ConversationParticipantsProvider._({
    required ConversationParticipantsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'conversationParticipantsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$conversationParticipantsHash();

  @override
  String toString() {
    return r'conversationParticipantsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<ConversationParticipant>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ConversationParticipant>> create(Ref ref) {
    final argument = this.argument as String;
    return conversationParticipants(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationParticipantsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$conversationParticipantsHash() =>
    r'75bf3306e7ff0aaf37233f54e78d30d0898ec05f';

/// The roster of one conversation.

final class ConversationParticipantsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<ConversationParticipant>>,
          String
        > {
  ConversationParticipantsFamily._()
    : super(
        retry: null,
        name: r'conversationParticipantsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The roster of one conversation.

  ConversationParticipantsProvider call(String conversationId) =>
      ConversationParticipantsProvider._(argument: conversationId, from: this);

  @override
  String toString() => r'conversationParticipantsProvider';
}

/// The direct conversation with one member, resolved by the server
/// (#702) — `direct_conversation` returns the existing thread or opens
/// one on first use.
///
/// A read that can WRITE, deliberately: "the conversation with Ana" has
/// to name a row before a thread can render, and a pair who have never
/// spoken has no row yet. The alternative is a screen that shows an
/// empty thread with no id and cannot send anything from it.

@ProviderFor(directConversationId)
final directConversationIdProvider = DirectConversationIdFamily._();

/// The direct conversation with one member, resolved by the server
/// (#702) — `direct_conversation` returns the existing thread or opens
/// one on first use.
///
/// A read that can WRITE, deliberately: "the conversation with Ana" has
/// to name a row before a thread can render, and a pair who have never
/// spoken has no row yet. The alternative is a screen that shows an
/// empty thread with no id and cannot send anything from it.

final class DirectConversationIdProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// The direct conversation with one member, resolved by the server
  /// (#702) — `direct_conversation` returns the existing thread or opens
  /// one on first use.
  ///
  /// A read that can WRITE, deliberately: "the conversation with Ana" has
  /// to name a row before a thread can render, and a pair who have never
  /// spoken has no row yet. The alternative is a screen that shows an
  /// empty thread with no id and cannot send anything from it.
  DirectConversationIdProvider._({
    required DirectConversationIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'directConversationIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$directConversationIdHash();

  @override
  String toString() {
    return r'directConversationIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    final argument = this.argument as String;
    return directConversationId(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DirectConversationIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$directConversationIdHash() =>
    r'85be189fcdf7fc0692ca69584c1f24d7910c9528';

/// The direct conversation with one member, resolved by the server
/// (#702) — `direct_conversation` returns the existing thread or opens
/// one on first use.
///
/// A read that can WRITE, deliberately: "the conversation with Ana" has
/// to name a row before a thread can render, and a pair who have never
/// spoken has no row yet. The alternative is a screen that shows an
/// empty thread with no id and cannot send anything from it.

final class DirectConversationIdFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, String> {
  DirectConversationIdFamily._()
    : super(
        retry: null,
        name: r'directConversationIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The direct conversation with one member, resolved by the server
  /// (#702) — `direct_conversation` returns the existing thread or opens
  /// one on first use.
  ///
  /// A read that can WRITE, deliberately: "the conversation with Ana" has
  /// to name a row before a thread can render, and a pair who have never
  /// spoken has no row yet. The alternative is a screen that shows an
  /// empty thread with no id and cannot send anything from it.

  DirectConversationIdProvider call(String memberId) =>
      DirectConversationIdProvider._(argument: memberId, from: this);

  @override
  String toString() => r'directConversationIdProvider';
}

/// Full-text search over messages I can see (#687).
///
/// Keyed by the query string, so Riverpod caches per term and typing
/// backwards re-uses what was already fetched.

@ProviderFor(messageSearch)
final messageSearchProvider = MessageSearchFamily._();

/// Full-text search over messages I can see (#687).
///
/// Keyed by the query string, so Riverpod caches per term and typing
/// backwards re-uses what was already fetched.

final class MessageSearchProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MemberNote>>,
          List<MemberNote>,
          FutureOr<List<MemberNote>>
        >
    with $FutureModifier<List<MemberNote>>, $FutureProvider<List<MemberNote>> {
  /// Full-text search over messages I can see (#687).
  ///
  /// Keyed by the query string, so Riverpod caches per term and typing
  /// backwards re-uses what was already fetched.
  MessageSearchProvider._({
    required MessageSearchFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'messageSearchProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$messageSearchHash();

  @override
  String toString() {
    return r'messageSearchProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<MemberNote>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MemberNote>> create(Ref ref) {
    final argument = this.argument as String;
    return messageSearch(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MessageSearchProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$messageSearchHash() => r'ecfa1edb0c0efc473cd5844329ed1b9de9d11dd3';

/// Full-text search over messages I can see (#687).
///
/// Keyed by the query string, so Riverpod caches per term and typing
/// backwards re-uses what was already fetched.

final class MessageSearchFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<MemberNote>>, String> {
  MessageSearchFamily._()
    : super(
        retry: null,
        name: r'messageSearchProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Full-text search over messages I can see (#687).
  ///
  /// Keyed by the query string, so Riverpod caches per term and typing
  /// backwards re-uses what was already fetched.

  MessageSearchProvider call(String query) =>
      MessageSearchProvider._(argument: query, from: this);

  @override
  String toString() => r'messageSearchProvider';
}

/// `now` for relative timestamps in the list, read once per build rather
/// than per row — twenty rows asking the clock separately can straddle a
/// minute boundary and render two different "now"s.

@ProviderFor(conversationNow)
final conversationNowProvider = ConversationNowProvider._();

/// `now` for relative timestamps in the list, read once per build rather
/// than per row — twenty rows asking the clock separately can straddle a
/// minute boundary and render two different "now"s.

final class ConversationNowProvider
    extends $FunctionalProvider<DateTime, DateTime, DateTime>
    with $Provider<DateTime> {
  /// `now` for relative timestamps in the list, read once per build rather
  /// than per row — twenty rows asking the clock separately can straddle a
  /// minute boundary and render two different "now"s.
  ConversationNowProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'conversationNowProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$conversationNowHash();

  @$internal
  @override
  $ProviderElement<DateTime> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DateTime create(Ref ref) {
    return conversationNow(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime>(value),
    );
  }
}

String _$conversationNowHash() => r'546a174fe5cf7b075122743cca5919a046a673eb';
