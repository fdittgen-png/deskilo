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

/// The language the app is shown in (`MaterialApp`'s own resolution of the
/// account's language over the device's languages): the LANGUAGE of every
/// derived format locale.

@ProviderFor(shownLanguageCode)
final shownLanguageCodeProvider = ShownLanguageCodeProvider._();

/// The language the app is shown in (`MaterialApp`'s own resolution of the
/// account's language over the device's languages): the LANGUAGE of every
/// derived format locale.

final class ShownLanguageCodeProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  /// The language the app is shown in (`MaterialApp`'s own resolution of the
  /// account's language over the device's languages): the LANGUAGE of every
  /// derived format locale.
  ShownLanguageCodeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shownLanguageCodeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shownLanguageCodeHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return shownLanguageCode(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$shownLanguageCodeHash() => r'4f9c6a8fcaea6c5e97e1abb41f17befc1072431f';

/// The person's format preferences: the account's own when [accountOnly]
/// (a personal surface: no business's exception reaches it), else with the
/// open business's exception over them; the profile's copy while the
/// preferences load.

@ProviderFor(personalFormatPrefs)
final personalFormatPrefsProvider = PersonalFormatPrefsFamily._();

/// The person's format preferences: the account's own when [accountOnly]
/// (a personal surface: no business's exception reaches it), else with the
/// open business's exception over them; the profile's copy while the
/// preferences load.

final class PersonalFormatPrefsProvider
    extends $FunctionalProvider<FormatPrefs, FormatPrefs, FormatPrefs>
    with $Provider<FormatPrefs> {
  /// The person's format preferences: the account's own when [accountOnly]
  /// (a personal surface: no business's exception reaches it), else with the
  /// open business's exception over them; the profile's copy while the
  /// preferences load.
  PersonalFormatPrefsProvider._({
    required PersonalFormatPrefsFamily super.from,
    required bool super.argument,
  }) : super(
         retry: null,
         name: r'personalFormatPrefsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$personalFormatPrefsHash();

  @override
  String toString() {
    return r'personalFormatPrefsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<FormatPrefs> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FormatPrefs create(Ref ref) {
    final argument = this.argument as bool;
    return personalFormatPrefs(ref, accountOnly: argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FormatPrefs value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FormatPrefs>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PersonalFormatPrefsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$personalFormatPrefsHash() =>
    r'882cbee62c575cccb11d5784c8f71e372ee2bc52';

/// The person's format preferences: the account's own when [accountOnly]
/// (a personal surface: no business's exception reaches it), else with the
/// open business's exception over them; the profile's copy while the
/// preferences load.

final class PersonalFormatPrefsFamily extends $Family
    with $FunctionalFamilyOverride<FormatPrefs, bool> {
  PersonalFormatPrefsFamily._()
    : super(
        retry: null,
        name: r'personalFormatPrefsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The person's format preferences: the account's own when [accountOnly]
  /// (a personal surface: no business's exception reaches it), else with the
  /// open business's exception over them; the profile's copy while the
  /// preferences load.

  PersonalFormatPrefsProvider call({required bool accountOnly}) =>
      PersonalFormatPrefsProvider._(argument: accountOnly, from: this);

  @override
  String toString() => r'personalFormatPrefsProvider';
}

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
