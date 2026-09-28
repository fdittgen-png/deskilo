// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'personal_appearance_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(personalLocale)
final personalLocaleProvider = PersonalLocaleProvider._();

final class PersonalLocaleProvider
    extends $FunctionalProvider<Locale?, Locale?, Locale?>
    with $Provider<Locale?> {
  PersonalLocaleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'personalLocaleProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$personalLocaleHash();

  @$internal
  @override
  $ProviderElement<Locale?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Locale? create(Ref ref) {
    return personalLocale(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Locale? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Locale?>(value),
    );
  }
}

String _$personalLocaleHash() => r'95a76058c8f9139b47dac39afc06fa214d45982e';

@ProviderFor(personalTheme)
final personalThemeProvider = PersonalThemeProvider._();

final class PersonalThemeProvider
    extends $FunctionalProvider<ThemeMode?, ThemeMode?, ThemeMode?>
    with $Provider<ThemeMode?> {
  PersonalThemeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'personalThemeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$personalThemeHash();

  @$internal
  @override
  $ProviderElement<ThemeMode?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ThemeMode? create(Ref ref) {
    return personalTheme(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeMode? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeMode?>(value),
    );
  }
}

String _$personalThemeHash() => r'81ef73a9aa55f0516200f62f2d04cef418407a0b';
