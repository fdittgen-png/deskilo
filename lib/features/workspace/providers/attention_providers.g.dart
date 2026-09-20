// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attention_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Everything waiting on this person, in the order they should meet it.
///
/// Three of the inventory's eight signals so far — the events awaiting
/// my decision (split by what the delay costs), the join requests, and
/// the month's members with billable data and no invoice. The rest —
/// reminders due, a schema behind the app, doctor findings, a
/// capability held back by a prerequisite — have providers of their own
/// and are the next checkpoint; each is one more entry in this list,
/// not a change to the ranking.

@ProviderFor(attention)
final attentionProvider = AttentionProvider._();

/// Everything waiting on this person, in the order they should meet it.
///
/// Three of the inventory's eight signals so far — the events awaiting
/// my decision (split by what the delay costs), the join requests, and
/// the month's members with billable data and no invoice. The rest —
/// reminders due, a schema behind the app, doctor findings, a
/// capability held back by a prerequisite — have providers of their own
/// and are the next checkpoint; each is one more entry in this list,
/// not a change to the ranking.

final class AttentionProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Attention>>,
          List<Attention>,
          FutureOr<List<Attention>>
        >
    with $FutureModifier<List<Attention>>, $FutureProvider<List<Attention>> {
  /// Everything waiting on this person, in the order they should meet it.
  ///
  /// Three of the inventory's eight signals so far — the events awaiting
  /// my decision (split by what the delay costs), the join requests, and
  /// the month's members with billable data and no invoice. The rest —
  /// reminders due, a schema behind the app, doctor findings, a
  /// capability held back by a prerequisite — have providers of their own
  /// and are the next checkpoint; each is one more entry in this list,
  /// not a change to the ranking.
  AttentionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'attentionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$attentionHash();

  @$internal
  @override
  $FutureProviderElement<List<Attention>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Attention>> create(Ref ref) {
    return attention(ref);
  }
}

String _$attentionHash() => r'2699e60771904e1dbe5edafd84e6e31e331a6791';
