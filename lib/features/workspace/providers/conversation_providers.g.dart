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

String _$conversationsHash() => r'c2d1f1ea93b13526fad941fc17ea362f6edc5248';

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
    r'8ead431e0bb68cde0c04f19122d655d44e5fe1e9';

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
    r'b62197a4d796071cc52572743a708469586a82ec';

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

String _$messageSearchHash() => r'88d5a9e7bd8b7870703adfae6d30c50b3af36fde';

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
