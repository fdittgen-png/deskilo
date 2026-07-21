// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'text_sharer.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Injectable seam over `share_plus` text sharing so widget tests can
/// capture the exact message the app would share — the text twin of
/// [linkLauncherProvider] and [fileSaverProvider].

@ProviderFor(textSharer)
final textSharerProvider = TextSharerProvider._();

/// Injectable seam over `share_plus` text sharing so widget tests can
/// capture the exact message the app would share — the text twin of
/// [linkLauncherProvider] and [fileSaverProvider].

final class TextSharerProvider
    extends $FunctionalProvider<TextSharer, TextSharer, TextSharer>
    with $Provider<TextSharer> {
  /// Injectable seam over `share_plus` text sharing so widget tests can
  /// capture the exact message the app would share — the text twin of
  /// [linkLauncherProvider] and [fileSaverProvider].
  TextSharerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'textSharerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$textSharerHash();

  @$internal
  @override
  $ProviderElement<TextSharer> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TextSharer create(Ref ref) {
    return textSharer(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TextSharer value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TextSharer>(value),
    );
  }
}

String _$textSharerHash() => r'c960891f74ae2fe05f2c230c6ad681a7d899e061';
