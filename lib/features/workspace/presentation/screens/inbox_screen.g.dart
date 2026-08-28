// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inbox_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Which face is showing — a provider rather than local state so a deep
/// link (a notification tap, `/events`, "see who is in today") can put
/// the inbox on the right tab before it is built.
///
/// KeepAlive, like [PlanFocusController] and for the same reason: the
/// inbox lives in the shell's indexed stack, so a request made from
/// another tab has to survive until the switch delivers it.

@ProviderFor(InboxTabController)
final inboxTabControllerProvider = InboxTabControllerProvider._();

/// Which face is showing — a provider rather than local state so a deep
/// link (a notification tap, `/events`, "see who is in today") can put
/// the inbox on the right tab before it is built.
///
/// KeepAlive, like [PlanFocusController] and for the same reason: the
/// inbox lives in the shell's indexed stack, so a request made from
/// another tab has to survive until the switch delivers it.
final class InboxTabControllerProvider
    extends $NotifierProvider<InboxTabController, InboxTab> {
  /// Which face is showing — a provider rather than local state so a deep
  /// link (a notification tap, `/events`, "see who is in today") can put
  /// the inbox on the right tab before it is built.
  ///
  /// KeepAlive, like [PlanFocusController] and for the same reason: the
  /// inbox lives in the shell's indexed stack, so a request made from
  /// another tab has to survive until the switch delivers it.
  InboxTabControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inboxTabControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inboxTabControllerHash();

  @$internal
  @override
  InboxTabController create() => InboxTabController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InboxTab value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InboxTab>(value),
    );
  }
}

String _$inboxTabControllerHash() =>
    r'9741100e8db14f5a93cf704fd0e2090bc87dfce2';

/// Which face is showing — a provider rather than local state so a deep
/// link (a notification tap, `/events`, "see who is in today") can put
/// the inbox on the right tab before it is built.
///
/// KeepAlive, like [PlanFocusController] and for the same reason: the
/// inbox lives in the shell's indexed stack, so a request made from
/// another tab has to survive until the switch delivers it.

abstract class _$InboxTabController extends $Notifier<InboxTab> {
  InboxTab build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<InboxTab, InboxTab>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<InboxTab, InboxTab>,
              InboxTab,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
