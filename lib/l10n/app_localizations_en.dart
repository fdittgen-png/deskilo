// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get authSignInTitle => 'Sign in';

  @override
  String get authSignUpTitle => 'Create account';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authDisplayNameLabel => 'Display name';

  @override
  String get authSignInButton => 'Sign in';

  @override
  String get authSignUpButton => 'Create account';

  @override
  String get authToggleToSignUp => 'New here? Create an account';

  @override
  String get authToggleToSignIn => 'Already have an account? Sign in';

  @override
  String get authFieldRequired => 'Required';

  @override
  String get authPasswordTooShort => 'At least 8 characters';

  @override
  String get authGenericError =>
      'Authentication failed. Check your credentials and try again.';

  @override
  String get authSignOut => 'Sign out';

  @override
  String get appTitle => 'DesKilo';

  @override
  String get tabPlan => 'Plan';

  @override
  String get tabCalendar => 'Calendar';

  @override
  String get tabEvents => 'Events';

  @override
  String get tabMoney => 'Money';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get comingSoon => 'Coming soon';
}
