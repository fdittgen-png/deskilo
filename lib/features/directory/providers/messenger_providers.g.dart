// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'messenger_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #1824 — the messenger on one server; '' is this one.

@ProviderFor(messengerRepository)
final messengerRepositoryProvider = MessengerRepositoryFamily._();

/// #1824 — the messenger on one server; '' is this one.

final class MessengerRepositoryProvider
    extends
        $FunctionalProvider<
          MessengerRepository,
          MessengerRepository,
          MessengerRepository
        >
    with $Provider<MessengerRepository> {
  /// #1824 — the messenger on one server; '' is this one.
  MessengerRepositoryProvider._({
    required MessengerRepositoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'messengerRepositoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$messengerRepositoryHash();

  @override
  String toString() {
    return r'messengerRepositoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<MessengerRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MessengerRepository create(Ref ref) {
    final argument = this.argument as String;
    return messengerRepository(ref, source: argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MessengerRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MessengerRepository>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MessengerRepositoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$messengerRepositoryHash() =>
    r'2253b2a9fbe5cc911bbe9538fc85b43906326c0a';

/// #1824 — the messenger on one server; '' is this one.

final class MessengerRepositoryFamily extends $Family
    with $FunctionalFamilyOverride<MessengerRepository, String> {
  MessengerRepositoryFamily._()
    : super(
        retry: null,
        name: r'messengerRepositoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// #1824 — the messenger on one server; '' is this one.

  MessengerRepositoryProvider call({String source = ''}) =>
      MessengerRepositoryProvider._(argument: source, from: this);

  @override
  String toString() => r'messengerRepositoryProvider';
}

@ProviderFor(messengerActions)
final messengerActionsProvider = MessengerActionsFamily._();

final class MessengerActionsProvider
    extends
        $FunctionalProvider<
          MessengerActions,
          MessengerActions,
          MessengerActions
        >
    with $Provider<MessengerActions> {
  MessengerActionsProvider._({
    required MessengerActionsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'messengerActionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$messengerActionsHash();

  @override
  String toString() {
    return r'messengerActionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<MessengerActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MessengerActions create(Ref ref) {
    final argument = this.argument as String;
    return messengerActions(ref, source: argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MessengerActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MessengerActions>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MessengerActionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$messengerActionsHash() => r'09141585f6e041b535e97bf86df40b94ee52dec1';

final class MessengerActionsFamily extends $Family
    with $FunctionalFamilyOverride<MessengerActions, String> {
  MessengerActionsFamily._()
    : super(
        retry: null,
        name: r'messengerActionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MessengerActionsProvider call({String source = ''}) =>
      MessengerActionsProvider._(argument: source, from: this);

  @override
  String toString() => r'messengerActionsProvider';
}

/// Every conversation I take part in, on this server and on every
/// server I connected, as ONE list (`mergeInboxes`).
///
/// A server that does not answer is named, not fatal: its rows are
/// missing and the list says so, while the others still show.

@ProviderFor(unifiedInbox)
final unifiedInboxProvider = UnifiedInboxProvider._();

/// Every conversation I take part in, on this server and on every
/// server I connected, as ONE list (`mergeInboxes`).
///
/// A server that does not answer is named, not fatal: its rows are
/// missing and the list says so, while the others still show.

final class UnifiedInboxProvider
    extends
        $FunctionalProvider<
          AsyncValue<UnifiedInbox>,
          UnifiedInbox,
          FutureOr<UnifiedInbox>
        >
    with $FutureModifier<UnifiedInbox>, $FutureProvider<UnifiedInbox> {
  /// Every conversation I take part in, on this server and on every
  /// server I connected, as ONE list (`mergeInboxes`).
  ///
  /// A server that does not answer is named, not fatal: its rows are
  /// missing and the list says so, while the others still show.
  UnifiedInboxProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'unifiedInboxProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$unifiedInboxHash();

  @$internal
  @override
  $FutureProviderElement<UnifiedInbox> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<UnifiedInbox> create(Ref ref) {
    return unifiedInbox(ref);
  }
}

String _$unifiedInboxHash() => r'045a4b4a92065d8b94b7931ed200dd3ce48b6587';

/// The display name of each connected server, by origin — the subtitle
/// a row carries only when it is not this server.

@ProviderFor(serverLabels)
final serverLabelsProvider = ServerLabelsProvider._();

/// The display name of each connected server, by origin — the subtitle
/// a row carries only when it is not this server.

final class ServerLabelsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, String>>,
          Map<String, String>,
          FutureOr<Map<String, String>>
        >
    with
        $FutureModifier<Map<String, String>>,
        $FutureProvider<Map<String, String>> {
  /// The display name of each connected server, by origin — the subtitle
  /// a row carries only when it is not this server.
  ServerLabelsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serverLabelsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serverLabelsHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, String>> create(Ref ref) {
    return serverLabels(ref);
  }
}

String _$serverLabelsHash() => r'c35e252b7807d965e029a979186f883b02a0910e';

@ProviderFor(contextMessages)
final contextMessagesProvider = ContextMessagesFamily._();

final class ContextMessagesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ContextMessage>>,
          List<ContextMessage>,
          FutureOr<List<ContextMessage>>
        >
    with
        $FutureModifier<List<ContextMessage>>,
        $FutureProvider<List<ContextMessage>> {
  ContextMessagesProvider._({
    required ContextMessagesFamily super.from,
    required (MessageContextKind, String, {String source}) super.argument,
  }) : super(
         retry: null,
         name: r'contextMessagesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$contextMessagesHash();

  @override
  String toString() {
    return r'contextMessagesProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<ContextMessage>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ContextMessage>> create(Ref ref) {
    final argument =
        this.argument as (MessageContextKind, String, {String source});
    return contextMessages(
      ref,
      argument.$1,
      argument.$2,
      source: argument.source,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ContextMessagesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$contextMessagesHash() => r'fd77b7a813bbd88b2c429d0eeda83abda6df2106';

final class ContextMessagesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<ContextMessage>>,
          (MessageContextKind, String, {String source})
        > {
  ContextMessagesFamily._()
    : super(
        retry: null,
        name: r'contextMessagesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ContextMessagesProvider call(
    MessageContextKind kind,
    String contextId, {
    String source = '',
  }) => ContextMessagesProvider._(
    argument: (kind, contextId, source: source),
    from: this,
  );

  @override
  String toString() => r'contextMessagesProvider';
}

@ProviderFor(messageHistory)
final messageHistoryProvider = MessageHistoryFamily._();

final class MessageHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MessageEvent>>,
          List<MessageEvent>,
          FutureOr<List<MessageEvent>>
        >
    with
        $FutureModifier<List<MessageEvent>>,
        $FutureProvider<List<MessageEvent>> {
  MessageHistoryProvider._({
    required MessageHistoryFamily super.from,
    required (MessageKind, String, {String source}) super.argument,
  }) : super(
         retry: null,
         name: r'messageHistoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$messageHistoryHash();

  @override
  String toString() {
    return r'messageHistoryProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<MessageEvent>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MessageEvent>> create(Ref ref) {
    final argument = this.argument as (MessageKind, String, {String source});
    return messageHistory(
      ref,
      argument.$1,
      argument.$2,
      source: argument.source,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MessageHistoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$messageHistoryHash() => r'd4f3d0dd9f5f430686e72e7873b6270e9c51cc79';

final class MessageHistoryFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<MessageEvent>>,
          (MessageKind, String, {String source})
        > {
  MessageHistoryFamily._()
    : super(
        retry: null,
        name: r'messageHistoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MessageHistoryProvider call(
    MessageKind kind,
    String messageId, {
    String source = '',
  }) => MessageHistoryProvider._(
    argument: (kind, messageId, source: source),
    from: this,
  );

  @override
  String toString() => r'messageHistoryProvider';
}

/// Who answers an inquiry to [workspace] — shown BEFORE writing.

@ProviderFor(hostRoster)
final hostRosterProvider = HostRosterFamily._();

/// Who answers an inquiry to [workspace] — shown BEFORE writing.

final class HostRosterProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<HostRosterEntry>>,
          List<HostRosterEntry>,
          FutureOr<List<HostRosterEntry>>
        >
    with
        $FutureModifier<List<HostRosterEntry>>,
        $FutureProvider<List<HostRosterEntry>> {
  /// Who answers an inquiry to [workspace] — shown BEFORE writing.
  HostRosterProvider._({
    required HostRosterFamily super.from,
    required (String, {String source}) super.argument,
  }) : super(
         retry: null,
         name: r'hostRosterProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$hostRosterHash();

  @override
  String toString() {
    return r'hostRosterProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<HostRosterEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<HostRosterEntry>> create(Ref ref) {
    final argument = this.argument as (String, {String source});
    return hostRoster(ref, argument.$1, source: argument.source);
  }

  @override
  bool operator ==(Object other) {
    return other is HostRosterProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$hostRosterHash() => r'0edc61bc9a53969f67c184bc5eb97317ddd1a54c';

/// Who answers an inquiry to [workspace] — shown BEFORE writing.

final class HostRosterFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<HostRosterEntry>>,
          (String, {String source})
        > {
  HostRosterFamily._()
    : super(
        retry: null,
        name: r'hostRosterProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Who answers an inquiry to [workspace] — shown BEFORE writing.

  HostRosterProvider call(String workspace, {String source = ''}) =>
      HostRosterProvider._(argument: (workspace, source: source), from: this);

  @override
  String toString() => r'hostRosterProvider';
}

/// The space's Inquiries view: what outside people wrote to it.

@ProviderFor(workspaceInquiries)
final workspaceInquiriesProvider = WorkspaceInquiriesFamily._();

/// The space's Inquiries view: what outside people wrote to it.

final class WorkspaceInquiriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<InquirySummary>>,
          List<InquirySummary>,
          FutureOr<List<InquirySummary>>
        >
    with
        $FutureModifier<List<InquirySummary>>,
        $FutureProvider<List<InquirySummary>> {
  /// The space's Inquiries view: what outside people wrote to it.
  WorkspaceInquiriesProvider._({
    required WorkspaceInquiriesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'workspaceInquiriesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workspaceInquiriesHash();

  @override
  String toString() {
    return r'workspaceInquiriesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<InquirySummary>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<InquirySummary>> create(Ref ref) {
    final argument = this.argument as String;
    return workspaceInquiries(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkspaceInquiriesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workspaceInquiriesHash() =>
    r'5d852c3940c310b65733b5137a5c7dbdc57bd9d7';

/// The space's Inquiries view: what outside people wrote to it.

final class WorkspaceInquiriesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<InquirySummary>>, String> {
  WorkspaceInquiriesFamily._()
    : super(
        retry: null,
        name: r'workspaceInquiriesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The space's Inquiries view: what outside people wrote to it.

  WorkspaceInquiriesProvider call(String workspace) =>
      WorkspaceInquiriesProvider._(argument: workspace, from: this);

  @override
  String toString() => r'workspaceInquiriesProvider';
}

/// #2216 — the signed-in account, which a group mention names.

@ProviderFor(myAccountId)
final myAccountIdProvider = MyAccountIdProvider._();

/// #2216 — the signed-in account, which a group mention names.

final class MyAccountIdProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// #2216 — the signed-in account, which a group mention names.
  MyAccountIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myAccountIdProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myAccountIdHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return myAccountId(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$myAccountIdHash() => r'c3770fae127cab8bf02e6381cb8a6388484b71cb';
