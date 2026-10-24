// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_pane_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The conversation the messenger's thread pane shows, or none. Nothing is
/// ever selected for the person: only a tap, or a person picked in the
/// directory, opens a thread — and only an opened thread marks anything
/// read. A new account starts with no conversation open.

@ProviderFor(ConversationSelection)
final conversationSelectionProvider = ConversationSelectionProvider._();

/// The conversation the messenger's thread pane shows, or none. Nothing is
/// ever selected for the person: only a tap, or a person picked in the
/// directory, opens a thread — and only an opened thread marks anything
/// read. A new account starts with no conversation open.
final class ConversationSelectionProvider
    extends $NotifierProvider<ConversationSelection, ConversationTarget?> {
  /// The conversation the messenger's thread pane shows, or none. Nothing is
  /// ever selected for the person: only a tap, or a person picked in the
  /// directory, opens a thread — and only an opened thread marks anything
  /// read. A new account starts with no conversation open.
  ConversationSelectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'conversationSelectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$conversationSelectionHash();

  @$internal
  @override
  ConversationSelection create() => ConversationSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConversationTarget? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConversationTarget?>(value),
    );
  }
}

String _$conversationSelectionHash() =>
    r'7f1fa0e5b0a45319e344b6854e66a4abccf678d3';

/// The conversation the messenger's thread pane shows, or none. Nothing is
/// ever selected for the person: only a tap, or a person picked in the
/// directory, opens a thread — and only an opened thread marks anything
/// read. A new account starts with no conversation open.

abstract class _$ConversationSelection extends $Notifier<ConversationTarget?> {
  ConversationTarget? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ConversationTarget?, ConversationTarget?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ConversationTarget?, ConversationTarget?>,
              ConversationTarget?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Unsent text per conversation, for this session only: kept while the
/// person moves between conversations, tabs and layouts, never written to
/// the device or the cloud, and dropped with the account that wrote it.
///
/// Every write names the account it was made under: a completion that
/// arrives after the account changed (a send that lands late) is refused,
/// so it can neither clear nor fill the next person's drafts.

@ProviderFor(ConversationDrafts)
final conversationDraftsProvider = ConversationDraftsProvider._();

/// Unsent text per conversation, for this session only: kept while the
/// person moves between conversations, tabs and layouts, never written to
/// the device or the cloud, and dropped with the account that wrote it.
///
/// Every write names the account it was made under: a completion that
/// arrives after the account changed (a send that lands late) is refused,
/// so it can neither clear nor fill the next person's drafts.
final class ConversationDraftsProvider
    extends $NotifierProvider<ConversationDrafts, Map<String, String>> {
  /// Unsent text per conversation, for this session only: kept while the
  /// person moves between conversations, tabs and layouts, never written to
  /// the device or the cloud, and dropped with the account that wrote it.
  ///
  /// Every write names the account it was made under: a completion that
  /// arrives after the account changed (a send that lands late) is refused,
  /// so it can neither clear nor fill the next person's drafts.
  ConversationDraftsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'conversationDraftsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$conversationDraftsHash();

  @$internal
  @override
  ConversationDrafts create() => ConversationDrafts();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, String>>(value),
    );
  }
}

String _$conversationDraftsHash() =>
    r'985f35df30d70fb53febf0c98ff9073dd2253831';

/// Unsent text per conversation, for this session only: kept while the
/// person moves between conversations, tabs and layouts, never written to
/// the device or the cloud, and dropped with the account that wrote it.
///
/// Every write names the account it was made under: a completion that
/// arrives after the account changed (a send that lands late) is refused,
/// so it can neither clear nor fill the next person's drafts.

abstract class _$ConversationDrafts extends $Notifier<Map<String, String>> {
  Map<String, String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Map<String, String>, Map<String, String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<String, String>, Map<String, String>>,
              Map<String, String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The sends still waiting on an answer, per conversation (the draft key),
/// for this session: a thread opened again while its send is in flight
/// shows neither the text nor a Send that could repeat it, and one whose
/// send went unconfirmed says so until the person reads it again.
///
/// Every write names the account it was made under: a send that answers
/// after the account changed marks nothing for the next person.

@ProviderFor(ConversationSends)
final conversationSendsProvider = ConversationSendsProvider._();

/// The sends still waiting on an answer, per conversation (the draft key),
/// for this session: a thread opened again while its send is in flight
/// shows neither the text nor a Send that could repeat it, and one whose
/// send went unconfirmed says so until the person reads it again.
///
/// Every write names the account it was made under: a send that answers
/// after the account changed marks nothing for the next person.
final class ConversationSendsProvider
    extends $NotifierProvider<ConversationSends, Map<String, SendPhase>> {
  /// The sends still waiting on an answer, per conversation (the draft key),
  /// for this session: a thread opened again while its send is in flight
  /// shows neither the text nor a Send that could repeat it, and one whose
  /// send went unconfirmed says so until the person reads it again.
  ///
  /// Every write names the account it was made under: a send that answers
  /// after the account changed marks nothing for the next person.
  ConversationSendsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'conversationSendsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$conversationSendsHash();

  @$internal
  @override
  ConversationSends create() => ConversationSends();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, SendPhase> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, SendPhase>>(value),
    );
  }
}

String _$conversationSendsHash() => r'cb31eee605de59f004d5c7360cbb054a411cbb22';

/// The sends still waiting on an answer, per conversation (the draft key),
/// for this session: a thread opened again while its send is in flight
/// shows neither the text nor a Send that could repeat it, and one whose
/// send went unconfirmed says so until the person reads it again.
///
/// Every write names the account it was made under: a send that answers
/// after the account changed marks nothing for the next person.

abstract class _$ConversationSends extends $Notifier<Map<String, SendPhase>> {
  Map<String, SendPhase> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<Map<String, SendPhase>, Map<String, SendPhase>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<String, SendPhase>, Map<String, SendPhase>>,
              Map<String, SendPhase>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
