// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_gateway_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Which online-payment providers [workspaceId] has connected, as the
/// online-payments screen reads it: configured or not, the public fields,
/// and only the NAMES of the secrets that hold a value.

@ProviderFor(paymentGatewayStatus)
final paymentGatewayStatusProvider = PaymentGatewayStatusFamily._();

/// Which online-payment providers [workspaceId] has connected, as the
/// online-payments screen reads it: configured or not, the public fields,
/// and only the NAMES of the secrets that hold a value.

final class PaymentGatewayStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<PaymentProvider, PaymentProviderStatus>>,
          Map<PaymentProvider, PaymentProviderStatus>,
          FutureOr<Map<PaymentProvider, PaymentProviderStatus>>
        >
    with
        $FutureModifier<Map<PaymentProvider, PaymentProviderStatus>>,
        $FutureProvider<Map<PaymentProvider, PaymentProviderStatus>> {
  /// Which online-payment providers [workspaceId] has connected, as the
  /// online-payments screen reads it: configured or not, the public fields,
  /// and only the NAMES of the secrets that hold a value.
  PaymentGatewayStatusProvider._({
    required PaymentGatewayStatusFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'paymentGatewayStatusProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$paymentGatewayStatusHash();

  @override
  String toString() {
    return r'paymentGatewayStatusProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Map<PaymentProvider, PaymentProviderStatus>>
  $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<PaymentProvider, PaymentProviderStatus>> create(Ref ref) {
    final argument = this.argument as String;
    return paymentGatewayStatus(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PaymentGatewayStatusProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$paymentGatewayStatusHash() =>
    r'f8889959200291cce88fb16240c3d18c6bf9e3c2';

/// Which online-payment providers [workspaceId] has connected, as the
/// online-payments screen reads it: configured or not, the public fields,
/// and only the NAMES of the secrets that hold a value.

final class PaymentGatewayStatusFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<Map<PaymentProvider, PaymentProviderStatus>>,
          String
        > {
  PaymentGatewayStatusFamily._()
    : super(
        retry: null,
        name: r'paymentGatewayStatusProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Which online-payment providers [workspaceId] has connected, as the
  /// online-payments screen reads it: configured or not, the public fields,
  /// and only the NAMES of the secrets that hold a value.

  PaymentGatewayStatusProvider call(String workspaceId) =>
      PaymentGatewayStatusProvider._(argument: workspaceId, from: this);

  @override
  String toString() => r'paymentGatewayStatusProvider';
}

/// The online-payments test of [workspaceId]: what a member's checkout
/// would do with the keys it holds. Read only when the owner asks, and
/// again on each retry; nothing is paid or written by reading it. A
/// refusal is the answer, shown at once, never retried behind a spinner.

@ProviderFor(paymentTestCheck)
final paymentTestCheckProvider = PaymentTestCheckFamily._();

/// The online-payments test of [workspaceId]: what a member's checkout
/// would do with the keys it holds. Read only when the owner asks, and
/// again on each retry; nothing is paid or written by reading it. A
/// refusal is the answer, shown at once, never retried behind a spinner.

final class PaymentTestCheckProvider
    extends
        $FunctionalProvider<
          AsyncValue<PaymentTestCheck>,
          PaymentTestCheck,
          FutureOr<PaymentTestCheck>
        >
    with $FutureModifier<PaymentTestCheck>, $FutureProvider<PaymentTestCheck> {
  /// The online-payments test of [workspaceId]: what a member's checkout
  /// would do with the keys it holds. Read only when the owner asks, and
  /// again on each retry; nothing is paid or written by reading it. A
  /// refusal is the answer, shown at once, never retried behind a spinner.
  PaymentTestCheckProvider._({
    required PaymentTestCheckFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noRetry,
         name: r'paymentTestCheckProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$paymentTestCheckHash();

  @override
  String toString() {
    return r'paymentTestCheckProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<PaymentTestCheck> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PaymentTestCheck> create(Ref ref) {
    final argument = this.argument as String;
    return paymentTestCheck(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PaymentTestCheckProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$paymentTestCheckHash() => r'223b96930f04078933dad58d7bcb3604db6ae374';

/// The online-payments test of [workspaceId]: what a member's checkout
/// would do with the keys it holds. Read only when the owner asks, and
/// again on each retry; nothing is paid or written by reading it. A
/// refusal is the answer, shown at once, never retried behind a spinner.

final class PaymentTestCheckFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<PaymentTestCheck>, String> {
  PaymentTestCheckFamily._()
    : super(
        retry: _noRetry,
        name: r'paymentTestCheckProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The online-payments test of [workspaceId]: what a member's checkout
  /// would do with the keys it holds. Read only when the owner asks, and
  /// again on each retry; nothing is paid or written by reading it. A
  /// refusal is the answer, shown at once, never retried behind a spinner.

  PaymentTestCheckProvider call(String workspaceId) =>
      PaymentTestCheckProvider._(argument: workspaceId, from: this);

  @override
  String toString() => r'paymentTestCheckProvider';
}
