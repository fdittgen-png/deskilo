// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_reminder_sweep.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #726 — the client-side clock for automatic payment reminders: the
/// first admin who opens Finances in a session runs the sweep for the
/// workspace. Idempotent (the dunning rules decide what is due), so a
/// second run in the same day records nothing. Kept alive so it runs
/// once per session, not once per rebuild; realtime invalidation of the
/// invoices refreshes what the sweep produced.

@ProviderFor(paymentReminderSweep)
final paymentReminderSweepProvider = PaymentReminderSweepFamily._();

/// #726 — the client-side clock for automatic payment reminders: the
/// first admin who opens Finances in a session runs the sweep for the
/// workspace. Idempotent (the dunning rules decide what is due), so a
/// second run in the same day records nothing. Kept alive so it runs
/// once per session, not once per rebuild; realtime invalidation of the
/// invoices refreshes what the sweep produced.

final class PaymentReminderSweepProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// #726 — the client-side clock for automatic payment reminders: the
  /// first admin who opens Finances in a session runs the sweep for the
  /// workspace. Idempotent (the dunning rules decide what is due), so a
  /// second run in the same day records nothing. Kept alive so it runs
  /// once per session, not once per rebuild; realtime invalidation of the
  /// invoices refreshes what the sweep produced.
  PaymentReminderSweepProvider._({
    required PaymentReminderSweepFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'paymentReminderSweepProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$paymentReminderSweepHash();

  @override
  String toString() {
    return r'paymentReminderSweepProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    final argument = this.argument as String;
    return paymentReminderSweep(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PaymentReminderSweepProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$paymentReminderSweepHash() =>
    r'c66d1e9f2c6959259276b0e887ae45ff0964eff5';

/// #726 — the client-side clock for automatic payment reminders: the
/// first admin who opens Finances in a session runs the sweep for the
/// workspace. Idempotent (the dunning rules decide what is due), so a
/// second run in the same day records nothing. Kept alive so it runs
/// once per session, not once per rebuild; realtime invalidation of the
/// invoices refreshes what the sweep produced.

final class PaymentReminderSweepFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<int>, String> {
  PaymentReminderSweepFamily._()
    : super(
        retry: null,
        name: r'paymentReminderSweepProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// #726 — the client-side clock for automatic payment reminders: the
  /// first admin who opens Finances in a session runs the sweep for the
  /// workspace. Idempotent (the dunning rules decide what is due), so a
  /// second run in the same day records nothing. Kept alive so it runs
  /// once per session, not once per rebuild; realtime invalidation of the
  /// invoices refreshes what the sweep produced.

  PaymentReminderSweepProvider call(String workspaceId) =>
      PaymentReminderSweepProvider._(argument: workspaceId, from: this);

  @override
  String toString() => r'paymentReminderSweepProvider';
}
