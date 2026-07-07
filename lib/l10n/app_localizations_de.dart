// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get authSignInTitle => 'Anmelden';

  @override
  String get authSignUpTitle => 'Konto erstellen';

  @override
  String get authEmailLabel => 'E-Mail';

  @override
  String get authPasswordLabel => 'Passwort';

  @override
  String get authDisplayNameLabel => 'Anzeigename';

  @override
  String get authSignInButton => 'Anmelden';

  @override
  String get authSignUpButton => 'Konto erstellen';

  @override
  String get authToggleToSignUp => 'Neu hier? Konto erstellen';

  @override
  String get authToggleToSignIn => 'Schon ein Konto? Anmelden';

  @override
  String get authFieldRequired => 'Pflichtfeld';

  @override
  String get authPasswordTooShort => 'Mindestens 8 Zeichen';

  @override
  String get authGenericError =>
      'Anmeldung fehlgeschlagen. Bitte Zugangsdaten prüfen und erneut versuchen.';

  @override
  String get authSignOut => 'Abmelden';

  @override
  String get appTitle => 'DesKilo';

  @override
  String get tabPlan => 'Plan';

  @override
  String get tabCalendar => 'Kalender';

  @override
  String get tabEvents => 'Ereignisse';

  @override
  String get tabMoney => 'Finanzen';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get comingSoon => 'Demnächst verfügbar';
}
