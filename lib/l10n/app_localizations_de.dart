// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get a11yClearDate => 'Datum löschen';

  @override
  String get a11yDecrease => 'Verringern';

  @override
  String get a11yFinishEditing => 'Bearbeitung beenden';

  @override
  String get a11yIncrease => 'Erhöhen';

  @override
  String get a11yMoveDown => 'Nach unten';

  @override
  String get a11yMoveUp => 'Nach oben';

  @override
  String get a11yRecentre => 'Plan an den Bildschirm anpassen';

  @override
  String get a11ySeatBlocked => 'nicht verfügbar';

  @override
  String get a11ySeatFree => 'frei';

  @override
  String get a11ySeatMine => 'Ihr Platz';

  @override
  String get a11ySeatOccupied => 'besetzt';

  @override
  String get a11ySeatReserved => 'reserviert';

  @override
  String get a11yZoomIn => 'Vergrößern';

  @override
  String get a11yZoomOut => 'Verkleinern';

  @override
  String get aboutAttribution =>
      'Based on DesKilo by Florian DITTGEN — https://github.com/fdittgen-png/deskilo';

  @override
  String get aboutAttributionNote =>
      'Dieser Hinweis muss in jeder Kopie und jeder geänderten Version sichtbar bleiben.';

  @override
  String get aboutOpenSource => 'Freie Software (AGPL-3.0)';

  @override
  String get aboutOpenSourceDesc => 'Quellcode auf GitHub';

  @override
  String get aboutPrivacy => 'Datenschutzerklärung';

  @override
  String get aboutReportBug => 'Fehler melden / Funktion vorschlagen';

  @override
  String get aboutSupportBody =>
      'Diese App ist kostenlos, Open Source und werbefrei. Wenn sie Ihnen nützt, unterstützen Sie den Entwickler.';

  @override
  String get aboutSupportTitle => 'Dieses Projekt unterstützen';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get accessKindNegotiations => 'Preisverhandlungen';

  @override
  String get accessKindProfile => 'Ihr Profil';

  @override
  String get accessLogEmpty =>
      'Niemand hat Ihre Finanzen oder Nachrichten eingesehen.';

  @override
  String accessLogRow(String actor, String category, String subject) {
    return '$actor hat $category von $subject eingesehen';
  }

  @override
  String get accessLogTitle => 'Wer auf Ihre Daten zugegriffen hat';

  @override
  String get accessNobodyElse => 'niemand sonst';

  @override
  String get accessRuleEvents => 'Sie, das handelnde Mitglied und die Admins.';

  @override
  String accessRuleFinances(String people) {
    return 'Sie und die mit der Finanz-Berechtigung: $people.';
  }

  @override
  String accessRuleManagedProfile(String people) {
    return 'Solange dieses Profil für Sie verwaltet wurde: $people. Jede Einsicht und jede Änderung durch eine dieser Personen steht unten.';
  }

  @override
  String get accessRuleMessages =>
      'Nur die Personen in der Unterhaltung — keine Rolle liest eine Unterhaltung, an der sie nicht teilnimmt.';

  @override
  String accessRuleNegotiations(String people) {
    return 'Sie, die Inhaber und die Finanz-Admins: $people. Jeder Zugriff durch jemand anderen steht unten im Protokoll.';
  }

  @override
  String get accessRuleReminders => 'Nur Sie.';

  @override
  String get accessRuleReservations =>
      'Jedes Mitglied des Bereichs — der Plan zeigt allen die Belegung.';

  @override
  String get accessoriesActive => 'Aktiv';

  @override
  String get accessoriesEdit => 'Zubehör bearbeiten';

  @override
  String get accessoriesEmpty => 'Noch kein Zubehör.';

  @override
  String get accessoriesInactive => 'Inaktiv';

  @override
  String get accessoriesName => 'Name';

  @override
  String get accessoriesNew => 'Neues Zubehör';

  @override
  String get accessoriesNoSupplement => 'Kein Aufpreis';

  @override
  String accessoriesPerHalfDay(String amount) {
    return '$amount / halber Tag';
  }

  @override
  String get accessoriesSupplement => 'Aufpreis pro halbem Tag';

  @override
  String get accessoriesTitle => 'Zubehör';

  @override
  String get accountActivityEmpty => 'Keine Einträge vorhanden.';

  @override
  String get accountActivityFailed =>
      'Ihr Finanzverlauf konnte nicht geladen werden. Zum Wiederholen antippen.';

  @override
  String get accountActivityScope =>
      'Alle Ihre Profile auf diesem Server, auch frühere Mitgliedschaften. Währungen werden getrennt angezeigt.';

  @override
  String get accountActivityTitle => 'Mein Verbrauch und meine Zahlungen';

  @override
  String get accountCardTitle => 'Ihr Konto';

  @override
  String get accountCredit => 'Guthaben auf dem Konto';

  @override
  String get accountImputationHint =>
      'Ihr Guthaben kann offene Rechnungen begleichen — der Space rechnet es beim Zuordnen der Zahlungen an.';

  @override
  String get accountInvoiceIssued => 'Rechnung ausgestellt';

  @override
  String get accountInvoiceRegrouped => 'In einer Sammelrechnung enthalten';

  @override
  String get accountInvoiceVoided => 'Rechnung storniert';

  @override
  String get accountNet => 'Nettoposition';

  @override
  String accountOpenPartial(String period, String paid) {
    return '$period · $paid bezahlt';
  }

  @override
  String get accountPaymentAsk => 'Beim Bezahlen wählen';

  @override
  String get accountPaymentConfirmed => 'Zahlung bestätigt';

  @override
  String get accountPaymentPreference => 'Bevorzugte Onlinezahlung';

  @override
  String get accountPaymentsTitle => 'Zahlungen';

  @override
  String get accountRefundDue => 'Erstattung vom Space ausstehend';

  @override
  String get accountUsageCorrected => 'Korrigierter abrechenbarer Verbrauch';

  @override
  String accountUsageMinutes(int minutes) {
    return '$minutes Minuten';
  }

  @override
  String get accountingExportDevelopment =>
      'Entwicklungs-Arbeitsbereich: die Datei ist als DEV markiert und nicht die echte Buchhaltung.';

  @override
  String get addressCountryLabel => 'Land';

  @override
  String get addressNone => 'Keine Adresse';

  @override
  String get addressSaved => 'Adresse gespeichert';

  @override
  String get addressTitle => 'Adresse';

  @override
  String get addressVatIdLabel =>
      'Umsatzsteuer-ID (wenn Sie als Unternehmen abrechnen)';

  @override
  String get addressWindowCountry => 'Dem Land folgen';

  @override
  String get addressWindowLeft => 'Links (DIN 5008)';

  @override
  String get addressWindowOff => 'Kein Fenster';

  @override
  String get addressWindowRight => 'Rechts (französisch)';

  @override
  String get addressWindowSubtitle =>
      'Wo der Empfänger gedruckt wird, damit er im Fensterumschlag erscheint. Das Anschriftfeld misst 85 × 45 mm, 45 mm von der Blattoberkante.';

  @override
  String get addressWindowTitle => 'Adressfenster';

  @override
  String get agreementExtraHalfDay => 'Zusätzlicher halber Tag';

  @override
  String get amenityDock => 'Dockingstation';

  @override
  String get amenityErgonomicChair => 'Ergonomischer Stuhl';

  @override
  String get amenityMonitor => 'Monitor';

  @override
  String get amenityStandingDesk => 'Stehpult';

  @override
  String get amenityWindow => 'Fensterplatz';

  @override
  String get appTitle => 'DesKilo';

  @override
  String get applicationAcceptedVote => 'Hat diese Anfrage genehmigt';

  @override
  String get applicationApproved => 'Genehmigt';

  @override
  String get applicationDecisionComment =>
      'Für die anfragende Person sichtbarer Kommentar';

  @override
  String get applicationDiscussionHint =>
      'Ihre Anfragen und Gespräche mit den prüfenden Personen bleiben auch nach einer Ablehnung verfügbar.';

  @override
  String get applicationNoMessages => 'Noch keine Nachrichten.';

  @override
  String get applicationPending => 'Genehmigung ausstehend';

  @override
  String get applicationRefused => 'Abgelehnt';

  @override
  String get applicationRefusedVote => 'Hat diese Anfrage abgelehnt';

  @override
  String get applicationReplyFailed =>
      'Ihre Nachricht wurde nicht gesendet. Ihr Entwurf bleibt erhalten; bitte versuchen Sie es erneut.';

  @override
  String get applicationsEmpty => 'Keine Arbeitsplatzanfragen.';

  @override
  String get applicationsLoadFailed =>
      'Ihre Arbeitsplatzanfragen konnten nicht geladen werden. Bitte versuchen Sie es erneut.';

  @override
  String get applicationsTitle => 'Arbeitsplatzanfragen';

  @override
  String get assistantPrefix => 'Assistent';

  @override
  String get assistantSetupActorConfigurer =>
      'Wer: jemand, der die Konfiguration dieses Arbeitsbereichs verwaltet';

  @override
  String get assistantSetupActorDatabaseAdministrator =>
      'Wer: ein Datenbankadministrator';

  @override
  String get assistantSetupActorInstanceOperator =>
      'Wer: der Instanzinhaber oder eine Vertretung';

  @override
  String get assistantSetupActorIntegrations =>
      'Wer: jemand, der die Integrationen dieses Arbeitsbereichs verwaltet';

  @override
  String get assistantSetupActorYou => 'Wer: Sie';

  @override
  String get assistantSetupAllDone =>
      'Für diesen Arbeitsbereich ist alles eingerichtet.';

  @override
  String get assistantSetupApply => 'Übernehmen';

  @override
  String get assistantSetupConnectHowTo =>
      '1. Fügen Sie in Ihrem Assistenten einen eigenen Connector mit dieser URL hinzu.\n2. Melden Sie sich auf Nachfrage mit Ihrem DesKilo-Konto an.\n3. Geben Sie diesen Arbeitsbereich und die erlaubten Vorgänge frei.';

  @override
  String get assistantSetupCopied => 'Connector-URL kopiert.';

  @override
  String get assistantSetupCopyUrl => 'Connector-URL kopieren';

  @override
  String get assistantSetupCustomise => 'Anpassen';

  @override
  String get assistantSetupFailed =>
      'Speichern fehlgeschlagen. Nichts wurde geändert; versuchen Sie es erneut.';

  @override
  String assistantSetupInstanceNames(String names) {
    return 'Verantwortlich für diese Datenbank: $names.';
  }

  @override
  String get assistantSetupInstanceNobody =>
      'Für diese Datenbank ist noch niemand verantwortlich.';

  @override
  String get assistantSetupInstanceYou =>
      'Sie sind für diese Datenbank verantwortlich: Schalten Sie Assistenten über die Instanzwerkzeuge ein.';

  @override
  String get assistantSetupIntro =>
      'Was Assistenten in diesem Arbeitsbereich brauchen, der Reihe nach. Jeder Schritt sagt, wer ihn erledigt.';

  @override
  String get assistantSetupLinkIdentity => 'Meine Identität bestätigen';

  @override
  String assistantSetupNextTodo(String step) {
    return 'Nächster Schritt: $step.';
  }

  @override
  String assistantSetupNextWaiting(String step, String actor) {
    return 'Nächster Schritt: $step. $actor.';
  }

  @override
  String get assistantSetupNoConnector =>
      'Diese App läuft ohne Server, daher gibt es keine Connector-URL.';

  @override
  String get assistantSetupNoWorkspace =>
      'Wählen Sie zuerst einen Arbeitsbereich.';

  @override
  String get assistantSetupPreviewAdds => 'Hinzugefügt';

  @override
  String get assistantSetupPreviewNone =>
      'Keine Änderung: Der Arbeitsbereich bietet genau diese Auswahl bereits an.';

  @override
  String get assistantSetupPreviewNote =>
      'Nur die eigenen Daten eines Mitglieds und die Verfügbarkeitsabfragen. Bereits verbundene Assistenten erhalten neue Vorgänge erst, wenn jede Person erneut zustimmt.';

  @override
  String get assistantSetupPreviewOwn =>
      'Assistenten sehen nur die eigenen Daten jedes Mitglieds.';

  @override
  String get assistantSetupPreviewRemoves => 'Entfernt';

  @override
  String get assistantSetupPreviewTitle => 'Empfohlene Auswahl';

  @override
  String get assistantSetupReasonConnect =>
      'Fügen Sie den Connector in Ihrem Assistenten hinzu, melden Sie sich an und geben Sie diesen Arbeitsbereich frei.';

  @override
  String get assistantSetupReasonEligibility =>
      'Die Administratoren dieser Datenbank geben jede Person einmal frei, für alle Arbeitsbereiche darauf.';

  @override
  String get assistantSetupReasonIdentity =>
      'Ein Assistent handelt in Ihrem Namen, daher muss diese Datenbank wissen, dass Sie es sind.';

  @override
  String get assistantSetupReasonInstallation =>
      'Der Instanzinhaber oder eine Vertretung schaltet Assistenten für alle Arbeitsbereiche dieser Datenbank ein.';

  @override
  String get assistantSetupReasonPolicy =>
      'Assistenten wird nichts angeboten, bis jemand die Vorgänge auswählt.';

  @override
  String get assistantSetupReasonWorkspace =>
      'Solange es aus ist, lehnt der Arbeitsbereich jeden Assistentenaufruf ab.';

  @override
  String get assistantSetupRecommended => 'Empfohlene Auswahl verwenden';

  @override
  String get assistantSetupRequest => 'Zugang anfragen';

  @override
  String get assistantSetupReview => 'Anfragen prüfen';

  @override
  String get assistantSetupSaved => 'Gespeichert.';

  @override
  String get assistantSetupStale =>
      'Jemand hat das Angebot inzwischen geändert. Prüfen Sie es und versuchen Sie es erneut.';

  @override
  String get assistantSetupStateBlocked => 'Nach den Schritten oben';

  @override
  String get assistantSetupStateDone => 'Erledigt';

  @override
  String get assistantSetupStateTodo => 'Offen';

  @override
  String get assistantSetupStateUnavailable => 'Konnte nicht abgefragt werden';

  @override
  String get assistantSetupStateWaiting => 'Wartet';

  @override
  String get assistantSetupStepConnect => 'Ihren Assistenten verbinden';

  @override
  String get assistantSetupStepEligibility =>
      'Ihren Assistentenzugang anfragen';

  @override
  String get assistantSetupStepIdentity => 'Ihre Identität verknüpfen';

  @override
  String get assistantSetupStepInstallation =>
      'Assistenten für diese Datenbank eingeschaltet';

  @override
  String get assistantSetupStepPolicy => 'Festlegen, was Assistenten dürfen';

  @override
  String get assistantSetupStepWorkspace =>
      'Assistenten für diesen Arbeitsbereich einschalten';

  @override
  String get assistantSetupTitle => 'Assistenten einrichten';

  @override
  String get assistantSetupTurnOn => 'Einschalten';

  @override
  String attentionAdmit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Beitrittsanfragen annehmen',
      one: '1 Beitrittsanfrage annehmen',
    );
    return '$_temp0';
  }

  @override
  String attentionDecide(String subject) {
    return 'Entscheiden: $subject';
  }

  @override
  String attentionIssue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Den Monat für $count Mitglieder abrechnen',
      one: 'Den Monat für 1 Mitglied abrechnen',
    );
    return '$_temp0';
  }

  @override
  String attentionSetUp(String area) {
    return 'Einzurichten: $area';
  }

  @override
  String attentionUnblock(int count, String feature) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eingeschaltete Funktionen warten auf „$feature“',
      one: '1 eingeschaltete Funktion wartet auf „$feature“',
    );
    return '$_temp0';
  }

  @override
  String attentionWaitingSince(String date) {
    return 'Wartet seit $date';
  }

  @override
  String get authAlreadyRegistered =>
      'Mit dieser Adresse kann kein Konto erstellt werden. Melden Sie sich an oder setzen Sie Ihr Passwort zurück.';

  @override
  String get authConnectServer => 'Mit dem Server einer Organisation verbinden';

  @override
  String get authContinueWith => 'oder weiter mit';

  @override
  String get authDisplayNameLabel => 'Anzeigename';

  @override
  String get authEmailLabel => 'E-Mail';

  @override
  String get authEmailNotConfirmed =>
      'Bestätigen Sie zuerst Ihre E-Mail-Adresse: Öffnen Sie die Nachricht, die wir Ihnen geschickt haben, und melden Sie sich dann an.';

  @override
  String get authFieldRequired => 'Pflichtfeld';

  @override
  String get authForgotPassword => 'Passwort vergessen?';

  @override
  String get authGenericError =>
      'Anmeldung fehlgeschlagen. Bitte Zugangsdaten prüfen und erneut versuchen.';

  @override
  String get authHidePassword => 'Passwort verbergen';

  @override
  String get authJoinByInvitation => 'Mit Einladung beitreten';

  @override
  String get authJoinHint =>
      'Erstellen Sie zuerst Ihr Konto oder melden Sie sich an — die Einladung fügen Sie gleich danach ein.';

  @override
  String authLinkAlreadyUsed(String provider) {
    return 'Diese $provider-Identität ist bereits mit einem anderen Konto verknüpft.';
  }

  @override
  String authLinkFailed(String provider, String code) {
    return 'Das Verknüpfen von $provider hat nicht funktioniert ($code). Versuchen Sie es erneut; falls es weiter scheitert, nennen Sie dem Server-Administrator diesen Code.';
  }

  @override
  String get authLinkManualDisabled =>
      'Das Verknüpfen von Konten ist auf diesem Server ausgeschaltet. Der Administrator muss „Manuelles Verknüpfen zulassen“ in den Authentifizierungs-Einstellungen aktivieren.';

  @override
  String get authNetworkError =>
      'Server nicht erreichbar. Prüfen Sie Ihre Verbindung und versuchen Sie es erneut.';

  @override
  String get authPasswordLabel => 'Passwort';

  @override
  String get authPasswordTooShort => 'Mindestens 8 Zeichen';

  @override
  String get authProviderDisabled =>
      'Diese Anmeldemethode ist auf diesem Server abgeschaltet.';

  @override
  String get authRateLimited =>
      'Zu viele Versuche. Warten Sie einen Moment und versuchen Sie es dann erneut.';

  @override
  String get authRecoveryNotSaved =>
      'Ihr Code wurde angenommen, aber das neue Passwort wurde nicht gespeichert. Versuchen Sie das Speichern erneut.';

  @override
  String get authRecoveryRetryUpdate => 'Neues Passwort erneut speichern';

  @override
  String get authRecoverySessionLost =>
      'Dieser Code gilt hier nicht mehr. Fordern Sie einen neuen an.';

  @override
  String get authResetCodeLabel => 'Code aus der E-Mail';

  @override
  String get authResetCodeSent => 'Code gesendet — prüfen Sie Ihre E-Mails.';

  @override
  String get authResetDone => 'Passwort aktualisiert — Sie sind angemeldet.';

  @override
  String get authResetExplainer =>
      'Wir senden Ihnen einen Einmal-Code per E-Mail. Setzen Sie damit hier ein neues Passwort.';

  @override
  String get authResetInvalidCode =>
      'Dieser Code ist ungültig oder abgelaufen.';

  @override
  String get authResetNewPasswordLabel => 'Neues Passwort';

  @override
  String get authResetSendCode => 'Code senden';

  @override
  String get authResetSubmit => 'Neues Passwort setzen';

  @override
  String get authResetTitle => 'Passwort zurücksetzen';

  @override
  String get authShowPassword => 'Passwort anzeigen';

  @override
  String get authSignInButton => 'Anmelden';

  @override
  String get authSignInTitle => 'Anmelden';

  @override
  String get authSignOut => 'Abmelden';

  @override
  String get authSignUpButton => 'Konto erstellen';

  @override
  String get authSignUpTitle => 'Konto erstellen';

  @override
  String authSocialUnavailable(String provider) {
    return 'Die $provider-Anmeldung ist noch nicht verfügbar — der Server hat sie nicht aktiviert.';
  }

  @override
  String get authToggleToSignIn => 'Schon ein Konto? Anmelden';

  @override
  String get authToggleToSignUp => 'Neu hier? Konto erstellen';

  @override
  String get authVerifyBackToSignIn => 'Zurück zur Anmeldung';

  @override
  String authVerifyBody(String email) {
    return 'Wir haben einen Bestätigungslink an $email geschickt. Öffnen Sie ihn auf diesem Gerät, um Ihr Konto fertig einzurichten.';
  }

  @override
  String get authVerifyChangeEmail => 'Andere Adresse verwenden';

  @override
  String get authVerifyHint =>
      'Noch nichts da? Sehen Sie im Spam-Ordner nach oder senden Sie die E-Mail erneut.';

  @override
  String get authVerifyResend => 'E-Mail erneut senden';

  @override
  String get authVerifyResendWait =>
      'In einer Minute können Sie sie erneut senden.';

  @override
  String get authVerifyResent => 'Erneut gesendet.';

  @override
  String get authVerifyTitle => 'Sehen Sie in Ihr E-Mail-Postfach';

  @override
  String get authWeakPassword => 'Wählen Sie ein stärkeres Passwort.';

  @override
  String get availabilityAddClosure => 'Schließtag hinzufügen';

  @override
  String get availabilityClosureDays => 'Schließtage';

  @override
  String get availabilityClosureReason => 'Grund (optional)';

  @override
  String get availabilityFullDayHours => 'Stunden, die als ganzer Tag gelten';

  @override
  String get availabilityGranularity15 => '15-Minuten-Slots';

  @override
  String get availabilityGranularity30 => '30-Minuten-Slots';

  @override
  String get availabilityGranularity5 => '5-Minuten-Slots';

  @override
  String get availabilityGranularity60 => '1-Stunden-Slots';

  @override
  String get availabilityGranularityDescription =>
      'Halbe Tage: Buchungen umfassen den Vormittag, den Nachmittag oder den ganzen Arbeitstag — die Fenster folgen den konfigurierten Arbeitszeiten.';

  @override
  String get availabilityGranularityFlexible => 'Freier Zeitraum';

  @override
  String get availabilityGranularityFullDay => 'Nur ganze Tage';

  @override
  String get availabilityGranularityHalfDay =>
      'Halbe Tage (Vormittag & Nachmittag)';

  @override
  String get availabilityGranularityHours =>
      'Echte Uhrzeiten (exakt von–bis, Halb-/Ganztage als Schnellwahl)';

  @override
  String get availabilityGranularityTitle => 'Buchungsraster';

  @override
  String get availabilityHalfBoundary => 'Halbtagsgrenze';

  @override
  String get availabilityHalfDayHours => 'Stunden, die als halber Tag gelten';

  @override
  String availabilityHourOption(int count) {
    return '$count h';
  }

  @override
  String get availabilityLastOpenDay =>
      'Mindestens ein Wochentag muss geöffnet bleiben.';

  @override
  String get availabilityNoClosures => 'Keine Schließtage.';

  @override
  String get availabilityOpenWeekdays => 'Geöffnete Wochentage';

  @override
  String get availabilityPoliciesTitle => 'Buchungsregeln';

  @override
  String get availabilityTitle => 'Verfügbarkeit';

  @override
  String get availabilityWorkEnd => 'Tagesende';

  @override
  String get availabilityWorkHoursDescription =>
      'Die Halbtags- und Ganztagsfenster überall — Reservierungen, Check-in und Abrechnung — folgen diesen Zeiten.';

  @override
  String get availabilityWorkHoursInvalid =>
      'Es muss gelten: Beginn < Halbtagsgrenze < Ende.';

  @override
  String get availabilityWorkHoursTitle => 'Arbeitszeiten';

  @override
  String get availabilityWorkStart => 'Tagesbeginn';

  @override
  String get backendCopyLink => 'Kopieren';

  @override
  String get backendCurrentTitle => 'Dieses Gerät nutzt';

  @override
  String get backendDescriptorInvalid =>
      'Das ist kein gültiger DesKilo-Server-Code.';

  @override
  String get backendDescriptorLabel => 'Server-Code';

  @override
  String backendDescriptorNamed(String label) {
    return 'Von der teilenden Person „$label“ genannt — nicht geprüft.';
  }

  @override
  String backendDestination(String host) {
    return 'Ziel: $host';
  }

  @override
  String get backendErrorKeyConnectionString =>
      'Das ist eine Datenbank-Verbindungszeichenfolge. Sie verlässt den Server nie — fügen Sie hier den veröffentlichbaren Schlüssel des Projekts ein.';

  @override
  String get backendErrorKeyEmpty => 'Tragen Sie den Publishable Key ein.';

  @override
  String get backendErrorKeyNotSupabase =>
      'Das ist kein Supabase Publishable Key (sb_publishable_…).';

  @override
  String get backendErrorKeyPersonalToken =>
      'Das ist ein persönliches Zugriffstoken. Es bleibt bei seinem Besitzer — fügen Sie hier den veröffentlichbaren Schlüssel des Projekts ein.';

  @override
  String get backendErrorKeySecret =>
      'Das ist ein geheimer Schlüssel, kein veröffentlichbarer. Teilen Sie ihn nie: rotieren Sie ihn unter Project Settings → API keys und fügen Sie dann hier den veröffentlichbaren Schlüssel ein.';

  @override
  String get backendErrorKeyUserToken =>
      'Das ist ein Sitzungs- oder Identitätstoken, kein Projektschlüssel. Fügen Sie hier den veröffentlichbaren Schlüssel des Projekts ein.';

  @override
  String get backendErrorUrlEmpty => 'Tragen Sie die Projekt-URL ein.';

  @override
  String get backendErrorUrlNoHost => 'Das ist keine vollständige Adresse.';

  @override
  String get backendErrorUrlNotCanonical =>
      'Geben Sie nur die Projektadresse an (https://host), ohne Pfad, Parameter oder Zugangsdaten.';

  @override
  String get backendErrorUrlNotHttps => 'Die URL muss mit https:// beginnen.';

  @override
  String get backendFacetNo => 'nein';

  @override
  String get backendFacetUnknown => 'unbekannt';

  @override
  String get backendFacetYes => 'ja';

  @override
  String backendFacets(
    String reachable,
    String key,
    String schema,
    String version,
  ) {
    return 'Erreicht: $reachable · Schlüssel akzeptiert: $key · Schema: $schema · Version: $version';
  }

  @override
  String get backendFullCheckHint =>
      'Fügen Sie für diese Prüfung ein persönliches Zugriffstoken ein. Es dient nur dieser Prüfung und wird nie gespeichert.';

  @override
  String get backendFullCheckTitle => 'Vollständige Prüfung starten';

  @override
  String get backendFullCheckUseToken => 'Dieses Token verwenden';

  @override
  String get backendHowTitle => 'Eigenen Server verwenden';

  @override
  String get backendKeyLabel => 'Publishable Key';

  @override
  String backendLastOk(String time) {
    return 'Letzter erfolgreicher Test: $time';
  }

  @override
  String get backendModeConnect => 'Mit bestehender Organisation verbinden';

  @override
  String get backendModeConnectHint =>
      'Scannen oder fügen Sie den Server-Code Ihrer Organisation ein. Ein Administratorschlüssel ist nie nötig.';

  @override
  String get backendModeDefault => 'DesKilo-Dienst verwenden';

  @override
  String get backendModeDefaultHint =>
      'Der DesKilo-Dienst braucht keine Einrichtung. Mitglieder einer Organisation mit eigenem Server verwenden stattdessen deren Code.';

  @override
  String get backendModeOperator => 'Server einrichten (Betreiber)';

  @override
  String get backendOpenDashboard => 'In Supabase öffnen';

  @override
  String get backendOwnServer => 'Ihr eigener Server';

  @override
  String get backendOwnership =>
      'Es gehört Ihrer Supabase-Organisation. DesKilo behält keinen Zugriff darauf.';

  @override
  String get backendOwnershipOther =>
      'Er gehört dem, der ihn betreibt. DesKilo behält keinen Zugriff darauf.';

  @override
  String get backendPaste => 'Einfügen';

  @override
  String backendPendingBody(String active, String saved) {
    return 'Diese Sitzung läuft noch auf $active. $saved übernimmt, wenn Sie die App schließen und wieder öffnen.';
  }

  @override
  String get backendPendingTitle => 'Gespeichert für den nächsten Start';

  @override
  String get backendPendingUndo => 'Rückgängig';

  @override
  String get backendPendingUndone =>
      'Rückgängig gemacht — der vorherige Server ist zurück.';

  @override
  String backendProjectRef(String ref) {
    return 'Ihr Supabase-Projekt $ref';
  }

  @override
  String get backendResetDeviceOnly =>
      'Das ändert nur dieses Gerät und berührt Ihr Supabase-Projekt nie.';

  @override
  String get backendSaveNeedsTest =>
      'Testen Sie zuerst die Verbindung. Nur ein geprüfter Server kann gespeichert werden.';

  @override
  String get backendScan => 'Server-QR scannen';

  @override
  String get backendScanNothing =>
      'Dieser QR-Code ist kein DesKilo-Servercode.';

  @override
  String backendServerCustom(Object host) {
    return 'Ihr eigener Server ($host)';
  }

  @override
  String backendServerDefault(Object host) {
    return 'Der eigene Server der App ($host)';
  }

  @override
  String get backendServerHint =>
      'Standardmäßig nutzt die App ihren eigenen Server. Wenn Ihre Community ein eigenes Supabase-Projekt betreibt, tragen Sie es hier ein — die App speichert dann alles dort.';

  @override
  String get backendServerInUse => 'Auf diesem Gerät in Gebrauch';

  @override
  String get backendServerReset => 'Server der App verwenden';

  @override
  String get backendServerRestartHint =>
      'Die App meldet Sie ab und übernimmt die Änderung beim nächsten Start.';

  @override
  String get backendServerSaved =>
      'Gespeichert. Schließen Sie die App und öffnen Sie sie erneut, um den neuen Server zu nutzen.';

  @override
  String get backendServerTitle => 'Server';

  @override
  String get backendShare => 'Diesen Server teilen';

  @override
  String get backendShareHint =>
      'Mitglieder scannen das in Einstellungen → Server, um ihre App auf dieselbe Instanz zu richten.';

  @override
  String get backendStep1 =>
      'Legen Sie ein Projekt auf supabase.com an (die kostenlose Stufe reicht zum Start).';

  @override
  String get backendStep2 =>
      'Installieren Sie das Schema der App: Führen Sie die SQL-Dateien aus supabase/migrations des Quell-Repositorys der Reihe nach aus.';

  @override
  String get backendStep3 =>
      'Öffnen Sie im Supabase-Dashboard Project Settings → API keys und kopieren Sie die Project URL und den Publishable Key.';

  @override
  String get backendStep4 =>
      'Fügen Sie sie unten ein, testen Sie die Verbindung und speichern Sie. Mitglieder kommen über den QR-Code oben auf dieselbe Instanz.';

  @override
  String get backendTest => 'Verbindung testen';

  @override
  String get backendTestAhead =>
      'Erreicht. Sein Schema ist neuer als diese App – es funktioniert, und eine neuere App ist verfügbar.';

  @override
  String get backendTestAttention =>
      'Erreicht, aber die Antwort ließ sich nicht einordnen. Prüfen Sie den Server, bevor Sie ihn verwenden.';

  @override
  String get backendTestBadKey =>
      'Erreicht, aber der Key wurde abgelehnt. Kopieren Sie den Publishable Key erneut aus Project Settings → API keys.';

  @override
  String get backendTestBehind =>
      'Erreicht, aber sein DesKilo-Schema ist älter, als diese App benötigt. Aktualisieren Sie den Server, bevor Sie ihn verwenden.';

  @override
  String get backendTestOk => 'Erreicht — das Schema der App ist vorhanden.';

  @override
  String get backendTestSchemaMissing =>
      'Erreicht, aber die DesKilo-Tabellen fehlen — führe zuerst die Migrationen aus supabase/migrations auf diesem Projekt aus.';

  @override
  String get backendTestUnreachable =>
      'Diese Adresse war nicht erreichbar. Prüfen Sie die URL und Ihr Netz.';

  @override
  String get backendTesting => 'Test läuft…';

  @override
  String get backendUrlLabel => 'Projekt-URL';

  @override
  String get backendVersionAhead =>
      'Der Server ist neuer als diese App — aktualisieren Sie die App, sobald Sie können';

  @override
  String backendVersionBehind(int version) {
    return 'Aktualisierung nötig: diese App braucht Schema $version';
  }

  @override
  String get backendVersionBehindHow =>
      'Sein Eigentümer aktualisiert ihn mit dem Einrichtungsassistenten oder `dart run tool/instance.dart install`, das nur Fehlendes anwendet.';

  @override
  String backendVersionCurrent(int version) {
    return 'Aktuell (Schema $version)';
  }

  @override
  String get backendVersionShortAhead => 'neuer';

  @override
  String get backendVersionShortBehind => 'älter';

  @override
  String get backendVersionShortCurrent => 'aktuell';

  @override
  String get backendVersionUnknown =>
      'Die Version konnte gerade nicht geprüft werden';

  @override
  String get badgeAuthEnabledHint =>
      'Standardmäßig aus: Ein Ausweis, der Sie eincheckt, meldet Sie nicht an, bis Sie es erlauben.';

  @override
  String get badgeAuthEnabledLabel => 'Meldet mich an';

  @override
  String get badgeAuthNeedsPin =>
      'Setzen Sie zuerst eine Anmelde-PIN — ein Ausweis allein darf nie genügen.';

  @override
  String get badgeCardAlreadyRegistered =>
      'Diese Karte ist bereits registriert.';

  @override
  String get badgeCardRegistered => 'Karte registriert.';

  @override
  String get badgeDefaultLabel => 'Badge';

  @override
  String get badgeDeleteConfirm =>
      'Dieses widerrufene Badge endgültig löschen?';

  @override
  String get badgeIssue => 'Neuer Badge';

  @override
  String badgeIssuedOn(String date) {
    return 'Ausgestellt am $date';
  }

  @override
  String get badgeNone => 'Noch keine Badges.';

  @override
  String get badgePinChangeAction => 'PIN ändern';

  @override
  String get badgePinClearAction => 'PIN entfernen';

  @override
  String get badgePinCleared =>
      'PIN entfernt. Ihre Ausweise melden Sie nicht mehr an.';

  @override
  String get badgePinConfirmLabel => 'Wiederholen';

  @override
  String get badgePinExplain =>
      'Mit Ihrer PIN melden Sie sich an, indem Sie Ihren Ausweis scannen, statt Ihre E-Mail zu tippen. Nur Sie können sie setzen, und niemand — auch kein Eigentümer — kann sie auslesen.';

  @override
  String get badgePinMismatch => 'Die beiden Eingaben stimmen nicht überein.';

  @override
  String get badgePinNewLabel => 'Neue PIN';

  @override
  String get badgePinNotSet => 'Noch keine PIN';

  @override
  String get badgePinSaveFailed =>
      'Server nicht erreichbar. Ihre PIN wurde nicht geändert — bitte erneut versuchen.';

  @override
  String get badgePinSaved => 'PIN gespeichert.';

  @override
  String get badgePinSectionTitle => 'Meine PIN';

  @override
  String get badgePinSet => 'PIN gesetzt';

  @override
  String get badgePinSetAction => 'PIN setzen';

  @override
  String badgePinTooShort(int min) {
    return 'Verwenden Sie mindestens $min Ziffern.';
  }

  @override
  String get badgeRegisterCard => 'Karte registrieren';

  @override
  String get badgeRevoke => 'Widerrufen';

  @override
  String get badgeRevoked => 'Widerrufen';

  @override
  String get badgeSavePdf => 'Als PDF speichern';

  @override
  String get badgeSignInButton => 'Anmelden';

  @override
  String get badgeSignInEntry => 'Mit Ausweis anmelden';

  @override
  String badgeSignInHello(String name) {
    return 'Hallo $name';
  }

  @override
  String get badgeSignInLocked =>
      'Zu viele Versuche. Warten Sie einige Minuten, oder melden Sie sich mit Ihrer E-Mail an.';

  @override
  String get badgeSignInNoReader =>
      'Auf diesem Gerät ist kein Ausweisleser verfügbar.';

  @override
  String get badgeSignInPinLabel => 'Ihre PIN';

  @override
  String get badgeSignInRefused =>
      'Das hat nicht geklappt. Prüfen Sie Ausweis und PIN, oder melden Sie sich mit Ihrer E-Mail an.';

  @override
  String get badgeSignInRetry => 'Erneut versuchen';

  @override
  String get badgeSignInTapPrompt => 'Halten Sie Ihren Ausweis an das Telefon.';

  @override
  String get badgeSignInTitle => 'Mit Ausweis anmelden';

  @override
  String get badgeSignInUnavailable =>
      'Die Ausweisanmeldung ist gerade nicht erreichbar. Melden Sie sich mit Ihrer E-Mail an.';

  @override
  String get badgeSignInUseEmail => 'Stattdessen meine E-Mail verwenden';

  @override
  String get badgeTapCardHint =>
      'Halten Sie die RFID/NFC-Karte an die Rückseite des Geräts.';

  @override
  String get badgeTapCardTitle => 'Karte registrieren';

  @override
  String get badgeTokenOnce =>
      'Speichern Sie diesen QR jetzt — er wird nur einmal angezeigt.';

  @override
  String get baseRoleNote =>
      'Jede Person hat genau eine Basisrolle: Benutzer, Administrator, Mit-Eigentümer oder Eigentümer. Weitere Rollen kommen hinzu; keine nimmt etwas weg.';

  @override
  String get baseRoleUser => 'Benutzer';

  @override
  String get biAreaCapacity => 'Flächen und Kapazität';

  @override
  String get biAreaFinance => 'Finanzen';

  @override
  String get biAreaOperations => 'Betrieb';

  @override
  String get biAreaOverview => 'Überblick';

  @override
  String get biAreaPeople => 'Personen und Geschäft';

  @override
  String get biAreaPlanning => 'Planung';

  @override
  String get biAreaSaved => 'Gespeicherte Analysen';

  @override
  String get biAreaTreasury => 'Liquidität';

  @override
  String get biBookingBasis =>
      'Reservierte Kapazität misst Buchungen, nicht die tatsächliche Anwesenheit.';

  @override
  String get biCardDown => 'Nach unten';

  @override
  String get biCardUp => 'Nach oben';

  @override
  String get biCards => 'Angezeigte Analysen';

  @override
  String biCardsUnavailable(String count) {
    return '$count Analysen dieser Ansicht sind für Sie nicht verfügbar und werden ausgelassen.';
  }

  @override
  String biChangePoints(String value) {
    return '$value Pp.';
  }

  @override
  String get biCollectionCentre => 'des Fakturierten';

  @override
  String get biCollectionCollected => 'Eingenommen';

  @override
  String get biCollectionNoComposition =>
      'Die hier eingenommenen Beträge enthalten frühere Rechnungen und sind daher kein Teil des in dieser Periode Fakturierten.';

  @override
  String get biCollectionOutstanding => 'Noch einzunehmen';

  @override
  String get biColumnChange => 'Veränderung';

  @override
  String get biColumnValue => 'Wert';

  @override
  String get biCompare => 'Vergleichen mit';

  @override
  String get biCompareCustom => 'Einem Zeitraum meiner Wahl';

  @override
  String get biCompareNone => 'Nichts';

  @override
  String get biComparePrevious => 'Dem Zeitraum davor';

  @override
  String get biComparePreviousYear => 'Demselben Zeitraum ein Jahr zuvor';

  @override
  String get biCompareTitle => 'Im Vergleich zur Vergangenheit';

  @override
  String biComparedLine(String period, String value, String change) {
    return '$period: $value ($change)';
  }

  @override
  String biComparedNotRecorded(String period, String since) {
    return '$period wurde nicht aufgezeichnet (die Historie beginnt am $since); es gibt keinen Vergleich.';
  }

  @override
  String biComparedPartial(String period) {
    return '$period ist nur teilweise aufgezeichnet.';
  }

  @override
  String get biComparisonUnqualified =>
      'Änderung nicht verfügbar: Ein Zeitraum enthält unvollständige oder veraltete Daten.';

  @override
  String get biCompositionTitle => 'Woraus es besteht';

  @override
  String biComputedWorkspaceTime(String date) {
    return 'Berechnet am $date · Ortszeit des Workspace';
  }

  @override
  String get biCurrentBasis =>
      'Der gesamte Zeitraum ist enthalten. Der Vergleich mit einem abgeschlossenen Zeitraum hat keine gleichwertige Basis.';

  @override
  String get biDataNotApplicable => 'Keine passende Kapazität';

  @override
  String get biDataNotRecorded => 'Nicht erfasst';

  @override
  String get biDataPartial => 'Unvollständige Daten';

  @override
  String get biDataStale => 'Veraltete Daten';

  @override
  String get biDataUnavailable => 'Nicht verfügbar';

  @override
  String get biDeltaNone => 'Noch kein Vergleich';

  @override
  String get biDimensionLevel => 'Ebene';

  @override
  String get biEvolutionTitle => 'Entwicklung';

  @override
  String get biExportPdf => 'Als PDF exportieren';

  @override
  String get biExposureDiffers =>
      'Die beiden Zeiträume haben nicht dieselbe Basis; die Quote berücksichtigt das, die Rohwerte sind nicht direkt vergleichbar.';

  @override
  String get biFinanceCollected => 'Eingenommen';

  @override
  String biFinanceCollectedBasis(String count) {
    return 'Aus $count Zahlungen, die Rechnungen zugeordnet sind';
  }

  @override
  String get biFinanceCollectedDefinition =>
      'Rechnungen zugeordnete Zahlungen, nach dem Monat der Zuordnung in der Zeit des Arbeitsbereichs.';

  @override
  String get biFinanceCollectedZero => 'Gemessen: Es wurde nichts eingenommen.';

  @override
  String biFinanceComputed(String date) {
    return 'Berechnet am $date';
  }

  @override
  String get biFinanceCurrencyMix =>
      'Dieser Zeitraum enthält Beträge in einer anderen Währung; verschiedene Währungen werden nicht addiert, daher wird kein Betrag gezeigt.';

  @override
  String get biFinanceInvoiced => 'Fakturiert';

  @override
  String biFinanceInvoicedBasis(String count, String credit) {
    return 'Aus $count Rechnungen; Gutschriften $credit, gesondert ausgewiesen';
  }

  @override
  String get biFinanceInvoicedDefinition =>
      'Rechnungen dieser Monate, ohne stornierte und Sammelabrechnungen (eine Sammelabrechnung fasst bereits gezählte Rechnungen zusammen); nur positive Summen.';

  @override
  String get biFinanceInvoicedZero => 'Gemessen: Es wurde nichts fakturiert.';

  @override
  String biFinanceLastChange(String date) {
    return 'Letzte Änderung der Quelle: $date';
  }

  @override
  String get biFinanceNotExact =>
      'Ein Betrag ist zu groß, um exakt angezeigt zu werden, und wird daher nicht gezeigt.';

  @override
  String get biFinanceNotProfit =>
      'Kein Gewinn: Diese Zahl enthält keine Kosten, und die beiden Zahlen werden nicht voneinander abgezogen.';

  @override
  String get biFinancePartial =>
      'Der Zeitraum ist nicht abgeschlossen: Diese Zahlen ändern sich noch.';

  @override
  String get biFinanceSameAsReport =>
      'Dieselben Regeln wie der Statusbericht des Arbeitsbereichs, einmal auf dem Server berechnet.';

  @override
  String get biForbidden =>
      'Sie dürfen diese Analyse in diesem Arbeitsbereich nicht lesen.';

  @override
  String get biFutureBasis =>
      'Vorhandene Buchungen und aktuelle Öffnungszeiten; keine Nachfrageprognose oder garantierte Nutzung.';

  @override
  String get biGrain => 'Zeitraumlänge';

  @override
  String get biGrainMonth => 'Monat';

  @override
  String get biGrainQuarter => 'Quartal';

  @override
  String get biGrainYear => 'Jahr';

  @override
  String get biGroupBy => 'Gruppieren nach';

  @override
  String get biGroupNone => 'Keine Gruppierung';

  @override
  String get biInvalidAddress =>
      'Diese Adresse verlangt eine Analyse, die es nicht gibt; es wurde nichts gelesen.';

  @override
  String get biKindCurrent => 'Jetzt';

  @override
  String get biKindPrevious => 'Vorherige Periode';

  @override
  String get biKindYearAgo => 'Gleiche Periode im Vorjahr';

  @override
  String biNarrativeDown(String label, String change) {
    return 'Niedriger als $label ($change).';
  }

  @override
  String biNarrativeFlat(String label) {
    return 'Etwa wie $label.';
  }

  @override
  String biNarrativeUp(String label, String change) {
    return 'Höher als $label ($change).';
  }

  @override
  String get biNoDataLabel => 'keine Daten';

  @override
  String get biNotOffered => 'von den angezeigten Analysen nicht angeboten';

  @override
  String get biOnPace => 'im aktuellen Tempo';

  @override
  String get biOpenSource => 'Quelle öffnen';

  @override
  String get biPastBasis =>
      'Aus den heute verfügbaren Daten neu berechnet, kein damaliger Wissensstand.';

  @override
  String get biPdfEstimateNote =>
      'Gestrichelte Linien und schattierte Bereiche sind Schätzungen aus vergangenen Perioden, keine Messungen.';

  @override
  String get biPdfFailed => 'Das PDF konnte nicht erstellt werden.';

  @override
  String biPdfProduced(String date) {
    return 'Erstellt am $date';
  }

  @override
  String get biPdfTitle => 'Geschäftsanalyse';

  @override
  String biProjectionBasis(int count) {
    return 'Eine Gerade durch die letzten $count vollständigen Perioden, fortgeführt. Der schattierte Bereich ist die wahrscheinliche Spanne. Eine Schätzung, kein Versprechen.';
  }

  @override
  String get biProjectionLabel => 'Schätzung';

  @override
  String biProjectionNotEnough(int have, int need) {
    return 'Noch nicht genug Verlauf für eine Prognose: bisher $have vollständige Perioden, $need nötig.';
  }

  @override
  String get biProjectionTitle => 'Wohin es sich entwickelt';

  @override
  String get biProvisionalNote =>
      'Vorläufig: Die Periode ist noch nicht vorbei, diese Veränderung ist eine Schätzung.';

  @override
  String biQuarter(String quarter, String year) {
    return 'Q$quarter $year';
  }

  @override
  String get biRecordedFuture => 'Zukünftiger Zeitraum · erfasste Buchungen';

  @override
  String get biRecordedPast => 'Vergangener Zeitraum · heutiger Datenstand';

  @override
  String get biRecordedPresent =>
      'Laufender Zeitraum · zukünftige Tage enthalten';

  @override
  String get biRefresh => 'Daten aktualisieren';

  @override
  String biRefusedBudget(String count) {
    return 'Es gibt mehr als $count Gruppen; wählen Sie „Keine Gruppierung“.';
  }

  @override
  String get biRefusedComparison =>
      'Diese Analyse kann diesen Vergleich nicht anstellen.';

  @override
  String get biRefusedGrain =>
      'Diese Analyse wird für diese Zeitraumlänge nicht angeboten.';

  @override
  String get biRefusedGrouping =>
      'Diese Analyse lässt sich so nicht gruppieren.';

  @override
  String get biRemainder => 'In keiner aktuellen Gruppe';

  @override
  String get biReset => 'Standardansicht zeigen';

  @override
  String biRunRate(String value) {
    return 'Im bisherigen Tempo würde diese Periode bei etwa $value enden.';
  }

  @override
  String get biRunningLabel => 'laufend';

  @override
  String get biSeatCentre => 'der gesamten Platzzeit';

  @override
  String get biSeatClosed => 'Außerhalb der Öffnungszeiten';

  @override
  String get biSeatFree => 'Frei während der Öffnungszeiten';

  @override
  String biSeatHoursBlocked(String hours) {
    return '$hours gesperrte Sitzstunden';
  }

  @override
  String biSeatHoursFree(String hours) {
    return '$hours nicht reservierte Sitzstunden';
  }

  @override
  String get biSeatReserved => 'Reserviert';

  @override
  String get biShareByLevel => 'Reservierte Zeit je Ebene';

  @override
  String get biSort => 'Reihenfolge';

  @override
  String get biSortAscending => 'Niedrigster zuerst';

  @override
  String get biSortDescending => 'Höchster zuerst';

  @override
  String get biSortNatural => 'Wie aufgeführt';

  @override
  String get biSortUngrouped => 'Reihenfolge (nur Gruppen)';

  @override
  String get biSourceRestricted =>
      'Die Quelldaten sehen nur diejenigen, die sie verwalten.';

  @override
  String get biTitle => 'Geschäftsanalyse';

  @override
  String get biTotal => 'Gesamt';

  @override
  String get biUnavailable => 'Diese Analyse konnte nicht berechnet werden.';

  @override
  String get biViewChart => 'Diagramm';

  @override
  String get biViewClearMyDefault => 'Meine Standardansicht nicht mehr öffnen';

  @override
  String get biViewClearTeamDefault => 'Standardansicht des Teams entfernen';

  @override
  String biViewCopyName(String name) {
    return '$name (Kopie)';
  }

  @override
  String get biViewDashboard => 'Dashboard';

  @override
  String get biViewDelete => 'Löschen';

  @override
  String biViewDeleteConfirm(String name) {
    return 'Ansicht „$name“ löschen?';
  }

  @override
  String get biViewDuplicate => 'Als meine Ansicht duplizieren';

  @override
  String get biViewForbidden => 'Sie dürfen diese Ansicht nicht ändern.';

  @override
  String get biViewInvalid =>
      'Dieser Name oder diese Ansicht kann nicht gespeichert werden.';

  @override
  String get biViewMakeMyDefault => 'Diese Ansicht standardmäßig öffnen';

  @override
  String get biViewMakeTeamDefault => 'Zur Standardansicht des Teams machen';

  @override
  String get biViewModified => 'seit dem Öffnen geändert';

  @override
  String get biViewName => 'Name';

  @override
  String get biViewNameTaken => 'Eine Ansicht mit diesem Namen gibt es schon.';

  @override
  String biViewPeriodFixed(String period) {
    return 'Immer $period';
  }

  @override
  String get biViewPeriodMoves =>
      'Der Zeitraum richtet sich nach dem Tag des Öffnens';

  @override
  String get biViewRename => 'Umbenennen…';

  @override
  String get biViewSave => 'Speichern';

  @override
  String get biViewSaveAs => 'Als neue Ansicht speichern…';

  @override
  String get biViewScopePrivate => 'Nur ich';

  @override
  String get biViewScopeTeam => 'Das Team';

  @override
  String get biViewStale =>
      'Jemand hat diese Ansicht gespeichert, seit Sie sie geöffnet haben. Die Liste wurde neu gelesen; versuchen Sie es noch einmal.';

  @override
  String get biViewStandard => 'Standardansicht';

  @override
  String get biViewTable => 'Tabelle';

  @override
  String get biViewUnreadable =>
      'Diese Ansicht lässt sich hier nicht öffnen: Sie wurde in einer Form gespeichert, die diese Version nicht liest, oder keine ihrer Analysen ist für Sie verfügbar.';

  @override
  String get biViews => 'Ansichten';

  @override
  String get biViewsMine => 'Meine Ansichten';

  @override
  String get biViewsTeam => 'Team-Ansichten';

  @override
  String get biVsPrevious => 'gg. Vorperiode';

  @override
  String get biVsYearAgo => 'gg. Vorjahr';

  @override
  String get billAccessorySupplements => 'Zubehör-Aufpreise';

  @override
  String get billBalance => 'Saldo';

  @override
  String billCreditNoteCard(String number) {
    return 'Gutschrift $number';
  }

  @override
  String get billCreditNoteDue =>
      'Der Space schuldet Ihnen diesen Betrag — Sie müssen nichts zahlen.';

  @override
  String get billCreditNoteRefunded =>
      'Der Space hat Ihnen diesen Betrag erstattet.';

  @override
  String billEntitlement(int used, int included, int openDays) {
    return '$used von $included halben Tagen abgerechnet ($openDays Öffnungstage)';
  }

  @override
  String billInvoiceCard(String number) {
    return 'Rechnung $number';
  }

  @override
  String get billInvoicePaid => 'Bereits bezahlt';

  @override
  String get billInvoiceRemaining => 'Restbetrag';

  @override
  String get billInvoiceTotal => 'Rechnungsbetrag';

  @override
  String get billOpenPositions => 'Offene Posten';

  @override
  String get billOutstanding => 'Offen';

  @override
  String billOverage(int extra) {
    return '$extra zusätzliche halbe Tage';
  }

  @override
  String get billPackages => 'Tagespakete';

  @override
  String billParticipation(int pct) {
    return 'Beitrag $pct %';
  }

  @override
  String billParticipationMonth(String month, int pct) {
    return '$month $pct %';
  }

  @override
  String get billPaymentsCredits => 'Zahlungen & Gutschriften';

  @override
  String get billPdfExport => 'Rechnung als PDF exportieren';

  @override
  String get billPdfTitle => 'Monatsrechnung';

  @override
  String get billPendingBadge => 'Bestätigung ausstehend';

  @override
  String get billServices => 'Bezogene Leistungen';

  @override
  String get billServicesTotal => 'Summe Leistungen';

  @override
  String get billSettled => 'Beglichen';

  @override
  String billSubscription(int pct) {
    return 'Abo $pct %';
  }

  @override
  String billSubscriptionMonth(String month, int pct) {
    return 'Abonnement $month $pct %';
  }

  @override
  String get billingAddBand => 'Band hinzufügen';

  @override
  String get billingAddLevel => 'Stufe hinzufügen';

  @override
  String get billingAddPackage => 'Paket hinzufügen';

  @override
  String get billingAdvanceDays => 'Tage vor Monatsbeginn';

  @override
  String get billingAllowCustom => 'Individuell verhandelten Wert erlauben';

  @override
  String get billingBandFee => 'Monatsgebühr';

  @override
  String billingBandFrom(int from) {
    return 'ab $from %';
  }

  @override
  String get billingBandOverage => 'Mehrverbrauch';

  @override
  String get billingBandTo => 'Bis %';

  @override
  String get billingBandsInvalid =>
      'Die Bänder müssen ansteigen und bei 100 % enden.';

  @override
  String get billingFeeBands => 'Gebührenbänder';

  @override
  String get billingLevelValue => 'Stufe (1–100)';

  @override
  String get billingLevels => 'Abo-Stufen';

  @override
  String get billingNewPackage => 'Neues Paket';

  @override
  String get billingPackageDays => 'Tage';

  @override
  String get billingPackageName => 'Name';

  @override
  String get billingPackagePrice => 'Preis';

  @override
  String billingPackageSummary(int days, String price) {
    return '$days Tage · $price';
  }

  @override
  String get billingPackages => 'Tagespakete';

  @override
  String get billingPackagesHint =>
      'Mitglieder im Paket-Tarif kaufen diese, wenn ihre Tage aufgebraucht sind.';

  @override
  String billingPricesVatHint(String rate) {
    return 'Preise sind brutto — die USt $rate (Standardsatz des Space) ist enthalten.';
  }

  @override
  String get billingRemoveBand => 'Band entfernen';

  @override
  String get billingRulesSaved => 'Rechnungsplan gespeichert.';

  @override
  String get billingRulesSubtitle =>
      'Wann Abo- und Monatsabschluss-Rechnungen rausgehen';

  @override
  String get billingRulesTitle => 'Rechnungsplan';

  @override
  String get billingSaved => 'Gespeichert.';

  @override
  String get billingSubscriptionAuto => 'Automatisch erstellen';

  @override
  String get billingSubscriptionOff =>
      'Schalten Sie „Abo-Rechnungen“ unter Funktionen ein, um das zu nutzen.';

  @override
  String get billingSubscriptionSection => 'Abo, im Voraus';

  @override
  String billingSubscriptionWhen(String day, String month) {
    return 'Erstellt am $day für $month';
  }

  @override
  String billingTariffVatHint(String rate) {
    return 'Preise sind brutto — USt $rate (Tarifsatz) ist enthalten.';
  }

  @override
  String get billingTitle => 'Abrechnung';

  @override
  String get billingUsageAuto => 'Automatisch erstellen';

  @override
  String get billingUsageOff =>
      'Schalten Sie „Monatsabschluss-Rechnungen“ unter Funktionen ein, um das zu nutzen.';

  @override
  String get billingUsageSection => 'Der gerade beendete Monat';

  @override
  String get billingUsageWhenZero => 'Auch wenn nichts zu zahlen ist';

  @override
  String get billingUsageWhenZeroHint =>
      'Sendet ein Dokument über null — als Bestätigung, dass das Abo den ganzen Monat abgedeckt hat.';

  @override
  String get blockPersonAction => 'Person blockieren';

  @override
  String blockPersonConfirm(String name) {
    return '$name blockieren? Sie sehen und erreichen einander nicht mehr. Sie können das unter Ich rückgängig machen.';
  }

  @override
  String get blockPersonDone => 'Blockiert.';

  @override
  String get blockedPeopleEmpty => 'Sie haben niemanden blockiert.';

  @override
  String get blockedPeopleHint =>
      'Eine blockierte Person kann Sie weder sehen noch Ihnen schreiben, und Sie können sie weder sehen noch erreichen.';

  @override
  String get blockedPeopleTitle => 'Blockierte Personen';

  @override
  String get bookAccountCode => 'Kontonummer';

  @override
  String get bookAccountName => 'Kontobezeichnung';

  @override
  String get bookAccountPosting => 'Bebuchbar';

  @override
  String get bookAuthorityExternal => 'Externes System';

  @override
  String get bookAuthorityLocal => 'DesKilo führt die Bücher';

  @override
  String get bookAuthorityPre => 'Vorkontierung';

  @override
  String get bookBasisAccrual => 'Soll-Versteuerung';

  @override
  String get bookBasisCash => 'Ist-Versteuerung';

  @override
  String get bookChartSuggest =>
      'Die vorgeschlagenen Konten zur Prüfung hinzufügen';

  @override
  String bookChartTitle(String site) {
    return 'Kontenplan · $site';
  }

  @override
  String get bookCurrency => 'Buchungswährung';

  @override
  String bookEffectiveFrom(String date) {
    return 'Gültig ab $date';
  }

  @override
  String get bookExternalSystem => 'Maßgebliches System';

  @override
  String bookFiscalPreview(String label, String start, String end) {
    return 'Geschäftsjahr $label: $start – $end';
  }

  @override
  String get bookFiscalStart => 'Das Geschäftsjahr beginnt am';

  @override
  String get bookIssuer => 'Rechnungssteller';

  @override
  String get bookMappingsTitle => 'Auf welches Konto jede Buchung geht';

  @override
  String get bookProblemCurrency =>
      'Für diese Währung ist keine geprüfte Zahl von Nachkommastellen hinterlegt.';

  @override
  String get bookProblemExternal =>
      'Nennen Sie das externe System, das die offiziellen Bücher führt.';

  @override
  String get bookProblemFiscal =>
      'Ein Geschäftsjahr beginnt an einem Tag, den jedes Jahr hat (nie am 29. Februar).';

  @override
  String bookProblemUnmapped(String roles) {
    return 'Ordnen Sie diese Konten zu, bevor eine lokale Buchführung beginnt: $roles.';
  }

  @override
  String get bookRoleBank => 'Bank';

  @override
  String get bookRoleCustomers => 'Kunden (Forderungen)';

  @override
  String get bookRoleExpenses => 'Aufwand';

  @override
  String get bookRoleRevenue => 'Erlöse';

  @override
  String get bookRoleVatOutput => 'Umsatzsteuer';

  @override
  String get bookSaveFailed =>
      'Die Buchführung wurde nicht gespeichert. Prüfen Sie die Verbindung und versuchen Sie es erneut.';

  @override
  String get bookSaved => 'Buchführung gespeichert';

  @override
  String get bookSheetTitle => 'Buchführung';

  @override
  String get bookStale =>
      'Jemand hat diese Buchführung gespeichert, seit Sie sie geöffnet haben. Schließen und neu öffnen, um seine Fassung zu sehen.';

  @override
  String get bookTileEmpty =>
      'Keine Buchführung festgelegt: DesKilo führt Mitgliedersalden und Rechnungen (Vorkontierung).';

  @override
  String get bookTypeAsset => 'Aktiva';

  @override
  String get bookTypeEquity => 'Eigenkapital';

  @override
  String get bookTypeExpense => 'Aufwand';

  @override
  String get bookTypeIncome => 'Ertrag';

  @override
  String get bookTypeLiability => 'Passiva';

  @override
  String bookingCheckedInAtUntil(String space, String until) {
    return 'Auf $space eingecheckt bis $until.';
  }

  @override
  String get bookingCheckedInElsewhere =>
      'Sie sind woanders eingecheckt — checken Sie dort zuerst aus.';

  @override
  String bookingCheckedInUntil(String until) {
    return 'Eingecheckt bis $until.';
  }

  @override
  String get bookingGateBlocked => 'So nicht buchbar';

  @override
  String bookingHorizonError(int days) {
    return 'Zu weit voraus — Buchungen sind $days Tage im Voraus möglich.';
  }

  @override
  String get bookingMembershipPaused =>
      'Ihre Mitgliedschaft ist pausiert — ein Admin reaktiviert sie unter Mitglieder.';

  @override
  String get bookingModeCheckInNow => 'Jetzt einchecken';

  @override
  String get bookingMoreOptions => 'Weitere Optionen';

  @override
  String get bookingNoLongerCheckedIn =>
      'Diese Reservierung ist nicht mehr eingecheckt — sie wurde inzwischen ausgecheckt oder abgeschlossen.';

  @override
  String get bookingNotAMember =>
      'Sie sind kein Mitglied dieses Raums mehr — bitten Sie einen Admin um eine Einladung.';

  @override
  String get bookingOnePlace =>
      'Sie haben in diesem Zeitraum bereits eine Buchung — ein Platz zur Zeit.';

  @override
  String get bookingOpenDetails => 'Details';

  @override
  String get bookingOutsideHoursError =>
      'Buchungen müssen innerhalb der Arbeitszeiten liegen.';

  @override
  String get bookingOutsideOffError =>
      'Buchungen außerhalb der Öffnungszeiten sind nicht erlaubt.';

  @override
  String get bookingOutsideWalkUpError =>
      'Außerhalb der Öffnungszeiten ist nur ein spontaner Check-in möglich — keine Vorausbuchung.';

  @override
  String get bookingOverlapsAnother =>
      'Der Platz ist in einem Teil dieser Zeit bereits gebucht.';

  @override
  String get bookingPastError =>
      'Diese Buchung liegt vollständig in der Vergangenheit.';

  @override
  String bookingRecordedPastSpaceWhen(String space, String when) {
    return '$space erfasst: $when. Dieser Zeitraum ist bereits vorbei, die Buchung bleibt als vergangener Besuch erhalten.';
  }

  @override
  String bookingRecordedPastWhen(String when) {
    return 'Erfasst: $when. Dieser Zeitraum ist bereits vorbei, die Buchung bleibt als vergangener Besuch erhalten.';
  }

  @override
  String get bookingRecoveryBanner =>
      'Eine Ihrer Buchungsanfragen ist noch unbeantwortet.';

  @override
  String get bookingRecoveryBannerAction => 'Prüfen';

  @override
  String get bookingRecoveryCheck => 'Ergebnis prüfen';

  @override
  String get bookingRecoveryCommitted =>
      'Die Buchung existiert – genau eine, aus Ihrer ursprünglichen Anfrage.';

  @override
  String get bookingRecoveryDiscard => 'Verwerfen';

  @override
  String get bookingRecoveryInProgress =>
      'Der Server bearbeitet diese Anfrage noch. Prüfen Sie es gleich noch einmal.';

  @override
  String get bookingRecoveryNotCommitted =>
      'Für diese Anfrage wurde nichts gebucht. Sie können sie unverändert fortsetzen oder verwerfen.';

  @override
  String get bookingRecoveryNotSaved =>
      'Dieses Gerät konnte Ihre Buchungsanfrage nicht speichern; es wurde nichts gesendet. Schaffen Sie Platz oder versuchen Sie es erneut.';

  @override
  String get bookingRecoveryResume => 'Dieselbe Anfrage fortsetzen';

  @override
  String get bookingRecoveryResumed =>
      'Fortgesetzt: Ihre ursprüngliche Anfrage wurde einmal gebucht.';

  @override
  String get bookingRecoverySpaceFallback => 'Der gewählte Platz';

  @override
  String get bookingRecoveryTitle => 'Ihre Buchungsanfrage';

  @override
  String get bookingRecoveryUnavailable =>
      'Der Server konnte nicht gefragt werden. Nichts wurde geändert; versuchen Sie es erneut.';

  @override
  String get bookingRecoveryUnknown =>
      'Die Verbindung brach ab, nachdem Ihre Anfrage gesendet wurde. Die Buchung existiert vielleicht, vielleicht nicht – prüfen Sie es, bevor Sie erneut buchen.';

  @override
  String get bookingRecoveryUnresolved =>
      'Der Server bewahrt zu dieser Anfrage nichts mehr auf und kann nichts sagen. Prüfen Sie Ihre Buchungen, bevor Sie erneut buchen.';

  @override
  String get bookingRecoveryView => 'Buchung ansehen';

  @override
  String bookingRecoveryWindow(String space, String from, String to) {
    return '$space · $from – $to';
  }

  @override
  String bookingReservedSpaceWhen(String space, String when) {
    return '$space reserviert: $when.';
  }

  @override
  String bookingReservedWhen(String when) {
    return 'Reserviert: $when.';
  }

  @override
  String get bookingSameDayError =>
      'Eine Buchung endet an dem Tag, an dem sie beginnt — den nächsten Tag separat buchen.';

  @override
  String get bookingSpaceChainTaken =>
      'Dieser Platz oder ein Bereich, zu dem er gehört, ist in diesem Zeitraum bereits reserviert.';

  @override
  String bookingTooLongError(int minutes) {
    return 'Zu lang — eine Buchung dauert höchstens $minutes Minuten.';
  }

  @override
  String bookingTooShortError(int minutes) {
    return 'Zu kurz — eine Buchung dauert mindestens $minutes Minuten.';
  }

  @override
  String get bookingWalkUpTodayError =>
      'Ein spontaner Check-in muss heute beginnen.';

  @override
  String get bootFailedBody =>
      'Der Server oder der sichere Speicher dieses Geräts hat nicht geantwortet. Nichts wurde geändert. Schließen Sie die App und öffnen Sie sie erneut; wenn das weiter passiert, prüfen Sie die Netzwerkverbindung.';

  @override
  String get bootFailedTitle => 'DesKilo konnte nicht starten';

  @override
  String get bootSlowBody =>
      'Es wird weiter versucht. Wenn nichts passiert, schließen Sie die App und öffnen Sie sie erneut.';

  @override
  String get bootSlowTitle => 'Der Start dauert länger als üblich';

  @override
  String brandColorRefused(String color, String pair) {
    return 'Die Farbe $color wurde nicht übernommen: $pair wäre unlesbar.';
  }

  @override
  String get buyPackageButton => 'Paket kaufen';

  @override
  String buyPackageDays(int days) {
    return '$days Tage';
  }

  @override
  String get buyPackageDone => 'Tage hinzugefügt — viel Spaß.';

  @override
  String get buyPackageNone => 'Noch keine Pakete verfügbar.';

  @override
  String get buyPackageTitle => 'Paket kaufen';

  @override
  String calendarAgendaEmpty(int days) {
    return 'Nichts geplant in den nächsten $days Tagen.';
  }

  @override
  String calendarAgendaRange(int days) {
    return 'Nächste $days Tage';
  }

  @override
  String get calendarAllLevels => 'Alle Etagen';

  @override
  String get calendarCancelFollowing => 'Diesen und folgende stornieren';

  @override
  String get calendarCancelOccurrence => 'Diesen Termin stornieren';

  @override
  String get calendarClosedDay => 'Geschlossen';

  @override
  String calendarClosedDayReason(String reason) {
    return 'Geschlossen — $reason';
  }

  @override
  String get calendarDay => 'Tag';

  @override
  String get calendarDayEmpty => 'Nichts an diesem Tag.';

  @override
  String calendarDueTitle(String number) {
    return 'Zahlung fällig · $number';
  }

  @override
  String get calendarEventActionApproved => 'genehmigt';

  @override
  String get calendarEventActionCancelled => 'storniert';

  @override
  String get calendarEventActionCreated => 'angelegt';

  @override
  String get calendarEventActionModified => 'geändert';

  @override
  String get calendarEventActionRefused => 'abgelehnt';

  @override
  String get calendarEventActionRejected => 'abgelehnt';

  @override
  String get calendarEventActionSubmitted => 'eingereicht';

  @override
  String get calendarEventActionValidated => 'freigegeben';

  @override
  String get calendarEventStatusExpired => 'abgelaufen';

  @override
  String get calendarEventStatusPending => 'wartet auf Bestätigung';

  @override
  String get calendarEventStatusRejected => 'abgelehnt';

  @override
  String calendarEventTitle(String label) {
    return 'Meldung: $label';
  }

  @override
  String get calendarEveryoneTab => 'Alle';

  @override
  String get calendarGroupActivity => 'Hinweise & Nachrichten';

  @override
  String get calendarGroupBookings => 'Buchungen & Anwesenheit';

  @override
  String get calendarGroupMoney => 'Finanzen';

  @override
  String calendarItemCount(int count) {
    return '$count Einträge';
  }

  @override
  String get calendarKindCheckIn => 'Check-ins';

  @override
  String get calendarKindCheckOut => 'Check-outs';

  @override
  String get calendarKindConsumption => 'Verbrauch';

  @override
  String get calendarKindDue => 'Fällige Zahlungen';

  @override
  String get calendarKindEvent => 'Meldungen';

  @override
  String get calendarKindInvoice => 'Rechnungen';

  @override
  String get calendarKindMessage => 'Nachrichten';

  @override
  String get calendarKindPayment => 'Zahlungen';

  @override
  String get calendarKindReminder => 'Erinnerungen';

  @override
  String get calendarKindReservation => 'Buchungen';

  @override
  String get calendarKindScheduled => 'Geplante Ausgaben';

  @override
  String get calendarKindValidation => 'Freigaben';

  @override
  String calendarLevelCollapsed(String level) {
    return '$level, eingeklappt';
  }

  @override
  String calendarLevelExpanded(String level) {
    return '$level, ausgeklappt';
  }

  @override
  String get calendarListView => 'Listenansicht';

  @override
  String calendarLockedKinds(String kinds) {
    return 'Für dieses Mitglied nicht sichtbar: $kinds';
  }

  @override
  String get calendarMemberMe => 'Ich';

  @override
  String get calendarMineTab => 'Meine';

  @override
  String get calendarNext => 'Weiter';

  @override
  String get calendarNextMonth => 'Nächster Monat';

  @override
  String get calendarNoReservations => 'Keine Reservierungen an diesem Tag.';

  @override
  String get calendarNothingHere => 'Nichts an diesen Tagen.';

  @override
  String get calendarPrevious => 'Zurück';

  @override
  String get calendarPreviousMonth => 'Vorheriger Monat';

  @override
  String get calendarRange => 'Zeitraum';

  @override
  String get calendarReservationActions => 'Aktionen zur Reservierung';

  @override
  String calendarScheduledTitle(String name) {
    return 'Geplante Ausgabe · $name';
  }

  @override
  String get calendarShowOnPlan => 'Auf dem Plan anzeigen';

  @override
  String get calendarTimelineAllEmpty =>
      'Auf keiner Etage gibt es an diesem Tag Reservierungen.';

  @override
  String get calendarTimelineEmpty =>
      'Keine Reservierungen auf dieser Etage an diesem Tag.';

  @override
  String get calendarTimelineView => 'Zeitleistenansicht';

  @override
  String get calendarToday => 'Heute';

  @override
  String get calendarTomorrow => 'Morgen';

  @override
  String calendarValidationRefused(String what) {
    return 'Abgelehnt: $what';
  }

  @override
  String calendarValidationValidated(String what) {
    return 'Freigegeben: $what';
  }

  @override
  String get calendarViewAgenda => 'Agenda';

  @override
  String get calendarViewAlerts => 'Hinweise';

  @override
  String get calendarViewMonth => 'Monat';

  @override
  String get calendarViewWeek => 'Woche';

  @override
  String get calendarWeekEmpty => 'Nichts in dieser Woche.';

  @override
  String get calendarWhoCanSee => 'Wer sieht das';

  @override
  String get calendarYesterday => 'Gestern';

  @override
  String get capabilityBrowserPrefer => 'Bevorzugen';

  @override
  String get capabilityBrowserRequire => 'Voraussetzen';

  @override
  String get capabilityBrowserTitle => 'Funktionen durchsuchen';

  @override
  String get capabilityCreditPacks => 'Guthabenpakete';

  @override
  String get capabilityCustomMemberForm => 'Eigenes Mitgliedsformular';

  @override
  String get capabilityMultiApproval => 'Zwei oder mehr Freigaben';

  @override
  String get capabilityOpeningHours => 'Öffnungszeiten';

  @override
  String get capabilityPayAsYouGo => 'Nutzungsbasierte Abrechnung';

  @override
  String get capabilityRefundApprovals => 'Zwei Freigaben für Erstattungen';

  @override
  String get capabilityStateConditional =>
      'Nur an, wenn die Voraussetzungen an sind';

  @override
  String get capabilityStateDisabled => 'Aus';

  @override
  String get capabilityStateEnabled => 'An';

  @override
  String get capabilityStateIncompatible => 'Hier nicht anwendbar';

  @override
  String get capabilityStateLocalInput => 'Braucht zuerst einen lokalen Wert';

  @override
  String get capabilityStateUnknown => 'Unbekannt';

  @override
  String get capabilityStateUnspecified =>
      'Von dieser Vorlage nicht festgelegt';

  @override
  String get capabilitySubscriptionPlans => 'Abonnements';

  @override
  String capacityKpiAsOf(String time) {
    return 'Berechnet $time';
  }

  @override
  String get capacityKpiDefinition =>
      'Reservierte Platzstunden innerhalb der Öffnungszeiten, geteilt durch angebotene Platzstunden: jeder Platz mal die Öffnungszeiten der offenen Tage, abzüglich Schließtage und Platzsperren. Ein ganzer Tisch, Raum oder eine ganze Etage zählt jeden seiner Plätze einmal; stornierte Buchungen zählen nicht.';

  @override
  String get capacityKpiExplain => 'Wie wird das berechnet?';

  @override
  String get capacityKpiForbidden =>
      'Sie dürfen die Kapazitätszahlen dieses Arbeitsbereichs nicht lesen.';

  @override
  String capacityKpiHistory(String date) {
    return 'Historie erfasst seit $date';
  }

  @override
  String capacityKpiHistorySince(String date) {
    return 'Gezählt ab $date, dem Beginn der Historie dieses Arbeitsbereichs; frühere Zeit ist unbekannt und wird nicht gezählt.';
  }

  @override
  String get capacityKpiKnownZero => 'Gemessen: Es wurde nichts reserviert.';

  @override
  String capacityKpiNotRecorded(String date) {
    return 'Dieser Zeitraum liegt vor dem Beginn der Historie am $date; es ist nichts erfasst, das gezählt werden könnte.';
  }

  @override
  String capacityKpiOutside(String hours) {
    return 'Außerhalb der angebotenen Zeiten reserviert: $hours Platzstunden, nicht im Verhältnis';
  }

  @override
  String capacityKpiOverlap(String hours) {
    return 'Gleichzeitig doppelt beansprucht: $hours Platzstunden, einmal gezählt';
  }

  @override
  String capacityKpiPhysical(String hours) {
    return 'Physische Kapazität: $hours Platzstunden';
  }

  @override
  String capacityKpiRatio(String reserved, String offered) {
    return '$reserved von $offered Platzstunden reserviert';
  }

  @override
  String get capacityKpiRetry => 'Erneut versuchen';

  @override
  String capacityKpiRooms(String count, String reserved, String offered) {
    return 'Räume ohne Plätze: $count, $reserved von $offered Raumstunden reserviert';
  }

  @override
  String get capacityKpiRoomsToday =>
      'Räume ohne Plätze werden so gelesen, wie sie heute sind.';

  @override
  String get capacityKpiTitle => 'Platzauslastung';

  @override
  String get capacityKpiUnattributed =>
      'Einige Reservierungen dieses Zeitraums verweisen auf einen Platz, den es nicht mehr gibt; sie werden nicht gezählt.';

  @override
  String get capacityKpiUnavailable =>
      'Die Platzauslastung konnte nicht berechnet werden.';

  @override
  String get capacityKpiUndefined =>
      'In diesem Zeitraum wurde keine Platzzeit angeboten, daher gibt es keine Auslastung.';

  @override
  String get captureRecordingHidden =>
      'Ausgeblendet, solange Ihr Bildschirm aufgezeichnet oder gespiegelt wird.';

  @override
  String get captureWebNotice =>
      'Ihr Browser kann Bildschirmfotos dieser Unterhaltung nicht verhindern.';

  @override
  String get carnetAdd => 'Mehrfachkarte hinzufügen';

  @override
  String carnetBalance(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Halbtage übrig',
      one: '1 Halbtag übrig',
      zero: 'Keine Halbtage übrig',
    );
    return '$_temp0';
  }

  @override
  String get carnetHalfDays => 'Halbtage';

  @override
  String get carnetName => 'Name';

  @override
  String get carnetPrice => 'Preis';

  @override
  String get carnetSell => 'Mehrfachkarte verkaufen';

  @override
  String get carnetSold =>
      'Mehrfachkarte verkauft — einmal auf der Monatsabrechnung berechnet.';

  @override
  String carnetSummary(int halfDays, String price) {
    return '$halfDays Halbtage · $price';
  }

  @override
  String get carnetValidity => 'Gültig (Monate, leer = läuft nie ab)';

  @override
  String get carnetsEmpty => 'Noch keine Mehrfachkarte.';

  @override
  String get carnetsTitle => 'Mehrfachkarten';

  @override
  String get coOwnerAction => 'Mit-Inhaberschaft';

  @override
  String get coOwnerActivate => 'Jetzt zum Inhaber machen';

  @override
  String get coOwnerActive =>
      'Aktiver Mitinhaber — Inhaber-Rechte sofort, automatische Nachfolge';

  @override
  String get coOwnerNone => 'Keine Mit-Inhaberschaft';

  @override
  String get coOwnerPassive =>
      'Nachfolge — wird Inhaber bei Aktivierung oder wenn der Inhaber geht';

  @override
  String coloursApplied(String hex) {
    return '$hex übernommen. Die App leitet daraus ihre Themen ab.';
  }

  @override
  String get coloursDark => 'Dunkel';

  @override
  String get coloursHexHint =>
      'Sechs Hexadezimalziffern. Leer lassen für die Produktfarben.';

  @override
  String get coloursHexLabel => 'Farbe';

  @override
  String get coloursIntro =>
      'Eine Farbe, und die App leitet daraus ihr helles und dunkles Thema ab. Alles Übrige behält die Produktpalette.';

  @override
  String get coloursLight => 'Hell';

  @override
  String get coloursLogoHint =>
      'Ihr Logo erscheint auch, während jemand diesen Bereich öffnet.';

  @override
  String coloursMalformed(String text) {
    return '$text ist keine Farbe: als #RRGGBB schreiben.';
  }

  @override
  String get coloursNeverTheirs =>
      'Die DesKilo-Marke, die Farben der Platzzustände und das Produktions-Banner gehören dem Produkt, in jedem Bereich.';

  @override
  String get coloursPatternDots => 'Punkte';

  @override
  String get coloursPatternGrid => 'Raster';

  @override
  String get coloursPatternHint =>
      'Wie Ihre Farbe auf der Karte dieses Bereichs unter Ich, auf seinem Chip und beim Öffnen gezeichnet wird – damit man ihn von anderen Bereichen unterscheidet.';

  @override
  String get coloursPatternSaved => 'Muster gespeichert.';

  @override
  String get coloursPatternSolid => 'Einfarbig';

  @override
  String get coloursPatternStripes => 'Streifen';

  @override
  String get coloursPatternTitle => 'Muster';

  @override
  String get coloursPatternWaves => 'Wellen';

  @override
  String get coloursPreview => 'So sieht es aus';

  @override
  String coloursRefused(String pair) {
    return 'Abgelehnt: $pair wäre mit dieser Farbe unlesbar.';
  }

  @override
  String get coloursReset => 'Produktfarben';

  @override
  String get coloursResetDone => 'Die Produktfarben sind zurück.';

  @override
  String get coloursRooms => 'Raumfarben';

  @override
  String get coloursRoomsAdd => 'Farbe hinzufügen';

  @override
  String coloursRoomsOwn(int n) {
    return '$n eigene Farben, in dieser Reihenfolge.';
  }

  @override
  String get coloursRoomsProduct =>
      'Die Produktpalette. Fügen Sie eine Farbe hinzu, um Ihre eigene zu verwenden.';

  @override
  String coloursRoomsSaved(int n) {
    return '$n Raumfarben gespeichert.';
  }

  @override
  String get coloursSaveFailed =>
      'Die Farbe konnte nicht gespeichert werden. Es hat sich nichts geändert.';

  @override
  String get coloursTitle => 'Farben';

  @override
  String coloursTooMany(int most) {
    return 'Der Plan malt höchstens $most Raumfarben.';
  }

  @override
  String get comingSoon => 'Demnächst verfügbar';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonClose => 'Schließen';

  @override
  String get commonCopy => 'Kopieren';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonDone => 'Fertig';

  @override
  String get commonOk => 'OK';

  @override
  String get commonRetry => 'Erneut versuchen';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonSaveFailed => 'Datei konnte nicht gespeichert werden.';

  @override
  String commonSavedTo(String path) {
    return 'Gespeichert unter $path';
  }

  @override
  String get commonShare => 'Teilen';

  @override
  String get commonStart => 'Starten';

  @override
  String get compareAdd => 'Zum Vergleich hinzufügen';

  @override
  String get compareAll => 'Alle Einstellungen';

  @override
  String compareCount(String shown, String total) {
    return '$shown von $total Einstellungen';
  }

  @override
  String get compareCurrencies => 'Verschiedene Währungen: nicht vergleichbar';

  @override
  String get compareDefault => 'Standard';

  @override
  String get compareDifferences => 'Unterschiede';

  @override
  String get compareEmpty => 'Leer';

  @override
  String get compareExport => 'Nach Excel exportieren';

  @override
  String get compareExported => 'Arbeitsmappe gespeichert.';

  @override
  String get compareInherits => 'Behält den des Arbeitsbereichs';

  @override
  String compareLimit(String count) {
    return 'Bis zu $count Vorlagen können verglichen werden. Entfernen Sie zuerst eine.';
  }

  @override
  String get compareLocal => 'Vor Ort festzulegen';

  @override
  String get compareMissing => 'Nicht in dieser Vorlage';

  @override
  String get compareNo => 'Nein';

  @override
  String get compareNotCarried => 'Nicht übertragen';

  @override
  String get compareNothing => 'Keine Einstellung unterscheidet sich.';

  @override
  String compareOpen(String count) {
    return 'Vergleichen ($count)';
  }

  @override
  String get compareRemove => 'Aus dem Vergleich entfernen';

  @override
  String get compareSearch => 'Einstellung suchen';

  @override
  String get compareTitle => 'Vorlagen vergleichen';

  @override
  String get compareUnavailable =>
      'Diese Vorlagen konnten zum Vergleich nicht gelesen werden. Es wird nichts behauptet.';

  @override
  String get compareUnknown => 'Unbekannt';

  @override
  String get compareYes => 'Ja';

  @override
  String get composerAttach => 'Verweis anhängen';

  @override
  String composerCharsLeft(int count) {
    return '$count Zeichen übrig';
  }

  @override
  String get composerDraftKept => 'Entwurf behalten';

  @override
  String get composerMention => 'Jemanden erwähnen';

  @override
  String get connectionCancelled =>
      'Das Konto hat sich inzwischen geändert; diese Antwort wurde verworfen.';

  @override
  String get connectionChangedIdentity =>
      'Dieser Server ist nicht mehr der, den Sie verbunden haben. Seine Aktionen sind angehalten, bis Sie ihn erneut bestätigen.';

  @override
  String get connectionChecking => 'Wird geprüft…';

  @override
  String get connectionCurrentServer =>
      'Das ist der Server, den diese App bereits verwendet.';

  @override
  String get connectionDenied =>
      'Dieser Server hat das Konto abgelehnt. Prüfen Sie die Anmeldedaten oder trennen Sie ihn.';

  @override
  String get connectionExpired =>
      'Ihre Anmeldung bei diesem Server ist abgelaufen. Melden Sie sich bei diesem Server erneut an.';

  @override
  String get connectionInvalidEndpoint =>
      'Diese Adresse oder dieser Schlüssel gehört zu keinem gültigen Server.';

  @override
  String get connectionMalformed =>
      'Dieser Server hat etwas geantwortet, das diese App nicht lesen kann.';

  @override
  String get connectionNotConnected =>
      'Dieser Server ist auf diesem Gerät nicht verbunden.';

  @override
  String get connectionRetry => 'Erneut versuchen';

  @override
  String get connectionSessionNotSaved =>
      'Die Aktion wurde ausgeführt, aber dieses Gerät konnte die Anmeldung beim Server nicht speichern. Möglicherweise müssen Sie sich erneut anmelden.';

  @override
  String get connectionSignInAgain => 'Erneut anmelden';

  @override
  String get connectionUnavailable =>
      'Dieser Server antwortet gerade nicht. Ihre anderen Server sind nicht betroffen.';

  @override
  String get connectionUnknownOutcome =>
      'Die Verbindung brach nach dem Senden ab. Die Anfrage wurde womöglich ausgeführt: Prüfen Sie das, bevor Sie es erneut versuchen.';

  @override
  String get connectionUnsupported =>
      'Diese Serverversion kann von dieser App nicht verbunden werden. Aktualisieren Sie die App oder bitten Sie den Betreiber, den Server zu aktualisieren.';

  @override
  String get connectionUsable => 'Verbunden';

  @override
  String get connectionVerifyAgain => 'Erneut bestätigen';

  @override
  String get consentAccept => 'Akzeptieren und weiter';

  @override
  String consentAcceptedOn(String date, String version) {
    return 'Akzeptiert am $date ($version)';
  }

  @override
  String get consentCheckbox =>
      'Ich habe das gelesen und akzeptiere, wie DesKilo meine Daten behandelt.';

  @override
  String get consentControllerBody =>
      'Jeder Workspace wird von seinem Inhaber betrieben — Ihrer Gemeinschaft —, der Mitglieder, Preise und Zahlungsanbieter bestimmt. Die App ist freie Software (AGPL-3.0-or-later) und wird von Florian Dittgen (Deutschland) veröffentlicht; das Backend ist Supabase in der EU. Online-Zahlungen laufen über den vom Inhaber aktivierten Anbieter (PayPal, Stripe, Mollie, Wero) zu dessen Bedingungen.';

  @override
  String get consentControllerTitle => 'Wer verantwortlich ist';

  @override
  String get consentIntro =>
      'Bevor Sie DesKilo nutzen: was die App mit Ihren Daten tut, wer sie sehen kann und was Sie tun können. Zwei Minuten; mehr ist es nicht.';

  @override
  String get consentNotBody =>
      'Kein Tracking, keine Analytik, keine Werbung, kein Verkauf oder Teilen von Daten. Push-Nachrichten tragen keinen Inhalt — nur „Sie haben eine neue Nachricht“; die App selbst schreibt den Text. Die F-Droid-Version hat gar keine Google-Dienste.';

  @override
  String get consentNotTitle => 'Was DesKilo nie tut';

  @override
  String get consentReadInHelp => 'In der Hilfe lesen';

  @override
  String get consentReadOnWiki => 'Im Wiki lesen';

  @override
  String get consentRetentionBody =>
      'Solange Sie Mitglied sind. Wenn Sie gehen und löschen, verschwinden Profil und Nachrichten; Buchhaltungsbelege (Rechnungen, Zahlungen) bleiben für die gesetzliche Aufbewahrungsfrist, nach Kennung und nicht nach Name.';

  @override
  String get consentRetentionTitle => 'Wie lange';

  @override
  String get consentReviewBody =>
      'Dieser Text bleibt in Einstellungen → Datenschutz & Daten, in der App-Hilfe (Datenschutz) und im Projekt-Wiki verfügbar. Eine Änderung des Textes fragt erneut nach Ihrer Zustimmung.';

  @override
  String get consentReviewHint =>
      'Der Text, den Sie akzeptiert haben, mit Datum — jederzeit nachlesbar.';

  @override
  String get consentReviewTitle => 'Jederzeit nachlesen';

  @override
  String get consentRightsBody =>
      'Auskunft, Berichtigung, Export (Art. 20), Löschung (Art. 17) und Widerspruch — jedes ein Knopf in Einstellungen → Datenschutz & Daten. Für alles andere: fdittgen@gmail.com. Sie können diese Einwilligung jederzeit widerrufen, indem Sie den Workspace verlassen und Ihre Daten löschen.';

  @override
  String get consentRightsTitle => 'Ihre Rechte';

  @override
  String get consentTitle => 'Ihre Daten, Ihre Rechte';

  @override
  String get consentUnavailable =>
      'Ihr Konto konnte nicht geladen werden, daher gibt es noch nichts zu akzeptieren.';

  @override
  String get consentVersion => 'Version';

  @override
  String get consentWhatBody =>
      'Ihr Konto (E-Mail, Anzeigename, gehashtes Passwort), Ihr Profil, wie Sie es ausfüllen (Foto, Status, Adresse, WhatsApp-Nummer — je optional), und was Sie in einem Workspace tun: Reservierungen und Check-ins, Nachrichten, Ausgaben und Verbräuche, Ihr Abonnement, Rechnungen und Zahlungen. Alles liegt in der EU (Supabase, eu-central-1).';

  @override
  String get consentWhatTitle => 'Was DesKilo verarbeitet';

  @override
  String get consentWhoBody =>
      'Der Zugriff folgt den Rollen und wird serverseitig durchgesetzt: Buchungen sieht der Workspace (der Plan zeigt die Belegung); Nachrichten nur die Personen der Unterhaltung, gleich welcher Rolle; Ihre Finanzen und Ihre Geschäftsvereinbarung nur Sie, die Inhaber und die Admins mit der passenden Berechtigung. Einstellungen → Datenschutz & Daten nennt die Personen und listet, wer tatsächlich nachgesehen hat.';

  @override
  String get consentWhoTitle => 'Wer was sehen kann';

  @override
  String get consumptionAdd => 'Verbrauch erfassen';

  @override
  String consumptionAddForMember(String name) {
    return 'Leistung für $name erfassen';
  }

  @override
  String get consumptionNoServices => 'Keine aktiven Leistungen vorhanden.';

  @override
  String get consumptionPeriodLabel => 'Abrechnungszeitraum (JJJJ-MM)';

  @override
  String get consumptionQuantity => 'Menge';

  @override
  String get consumptionRecorded =>
      'Verbrauch erfasst — wartet auf Bestätigung.';

  @override
  String get consumptionRefusedInactive =>
      'Dieser Dienst wird nicht mehr angeboten. Es wurde nichts erfasst.';

  @override
  String get consumptionRefusedPeriod =>
      'Der Abrechnungszeitraum muss ein Monat sein (JJJJ-MM). Es wurde nichts erfasst.';

  @override
  String get consumptionRefusedQuantity =>
      'Die Menge muss zwischen 1 und 999 liegen. Es wurde nichts erfasst.';

  @override
  String get consumptionRefusedStock =>
      'Nicht genug auf Lager. Es wurde nichts erfasst.';

  @override
  String get consumptionService => 'Leistung';

  @override
  String get conversationAddPeople => 'Mitglieder hinzufügen';

  @override
  String get conversationAdmin => 'Admin';

  @override
  String get conversationArchive => 'Archivieren';

  @override
  String get conversationArchived => 'Unterhaltung archiviert.';

  @override
  String get conversationEmpty => 'Noch keine Nachrichten — sagen Sie hallo!';

  @override
  String get conversationGroup => 'Gruppe';

  @override
  String get conversationGroupInfo => 'Gruppe';

  @override
  String get conversationLeave => 'Gruppe verlassen';

  @override
  String get conversationLeaveConfirm =>
      'Diese Gruppe verlassen? Sie erhalten keine Nachrichten mehr; Ihre bisherigen bleiben.';

  @override
  String get conversationLeft => 'Ausgetreten';

  @override
  String get conversationLoadEarlier => 'Frühere Nachrichten laden';

  @override
  String get conversationMarkUnread => 'Als ungelesen markieren';

  @override
  String conversationMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mitglieder',
      one: '1 Mitglied',
    );
    return '$_temp0';
  }

  @override
  String get conversationMute => 'Benachrichtigungen stumm';

  @override
  String get conversationMutedBadge => 'Stumm';

  @override
  String get conversationPin => 'Oben anheften';

  @override
  String get conversationRemove => 'Entfernen';

  @override
  String get conversationSeeProfile => 'Profil ansehen';

  @override
  String get conversationToday => 'Heute';

  @override
  String get conversationUnarchive => 'Aus dem Archiv holen';

  @override
  String get conversationUnknownMember => 'Mitglied';

  @override
  String get conversationUnmute => 'Stummschaltung aufheben';

  @override
  String get conversationUnpin => 'Loslösen';

  @override
  String get conversationYesterday => 'Gestern';

  @override
  String get conversationYou => 'Sie';

  @override
  String get countryNameAT => 'Österreich';

  @override
  String get countryNameAU => 'Australien';

  @override
  String get countryNameBE => 'Belgien';

  @override
  String get countryNameBG => 'Bulgarien';

  @override
  String get countryNameCA => 'Kanada';

  @override
  String get countryNameCH => 'Schweiz';

  @override
  String get countryNameCY => 'Zypern';

  @override
  String get countryNameCZ => 'Tschechien';

  @override
  String get countryNameDE => 'Deutschland';

  @override
  String get countryNameDK => 'Dänemark';

  @override
  String get countryNameEE => 'Estland';

  @override
  String get countryNameES => 'Spanien';

  @override
  String get countryNameFI => 'Finnland';

  @override
  String get countryNameFR => 'Frankreich';

  @override
  String get countryNameGB => 'Vereinigtes Königreich';

  @override
  String get countryNameGR => 'Griechenland';

  @override
  String get countryNameHR => 'Kroatien';

  @override
  String get countryNameHU => 'Ungarn';

  @override
  String get countryNameIE => 'Irland';

  @override
  String get countryNameIT => 'Italien';

  @override
  String get countryNameJP => 'Japan';

  @override
  String get countryNameLT => 'Litauen';

  @override
  String get countryNameLU => 'Luxemburg';

  @override
  String get countryNameLV => 'Lettland';

  @override
  String get countryNameMT => 'Malta';

  @override
  String get countryNameMX => 'Mexiko';

  @override
  String get countryNameNL => 'Niederlande';

  @override
  String get countryNameNO => 'Norwegen';

  @override
  String get countryNamePL => 'Polen';

  @override
  String get countryNamePT => 'Portugal';

  @override
  String get countryNameRO => 'Rumänien';

  @override
  String get countryNameSE => 'Schweden';

  @override
  String get countryNameSI => 'Slowenien';

  @override
  String get countryNameSK => 'Slowakei';

  @override
  String get countryNameUS => 'Vereinigte Staaten';

  @override
  String get courtesyHint =>
      'Wird auf Dokumenten vor Ihrem Namen gedruckt. „Keine“ druckt nur den Namen.';

  @override
  String get courtesyHintManaged =>
      'Wird auf Dokumenten vor ihrem Namen gedruckt. „Keine“ druckt nur den Namen.';

  @override
  String get courtesyLabel => 'Anrede';

  @override
  String get courtesyMr => 'Herr';

  @override
  String get courtesyMrs => 'Frau';

  @override
  String get courtesyNone => 'Keine';

  @override
  String get customerCapacityBusiness => 'Unternehmer';

  @override
  String get customerCapacityConsumer => 'Verbraucher';

  @override
  String get customerCapacityExplainer =>
      'Handelt dieser Kunde gewerblich oder beruflich (Gesellschaft, Einzelunternehmer, ein so handelnder Verein) oder als Verbraucher? Das entscheidet, welche Zahlungsklauseln eine Rechnung druckt; eine USt-IdNr. allein entscheidet es nicht. Nicht angegeben: Es gilt die Vorgabe des Arbeitsbereichs.';

  @override
  String get customerCapacityLabel => 'Kundeneigenschaft';

  @override
  String get customerCapacityNotStated => 'Nicht angegeben';

  @override
  String get customerCapacitySaveError =>
      'Die Kundeneigenschaft wurde nicht gespeichert.';

  @override
  String get datevAccountsIntro =>
      'Berater- und Mandantennummer bekommen Sie von Ihrer Steuerberatung. DATEV lehnt eine Datei mit abweichenden Nummern ab — genau das hält sie aus den Büchern der falschen Firma heraus.';

  @override
  String get datevAccountsTitle => 'DATEV-Export';

  @override
  String get datevClientNumber => 'Mandantennummer';

  @override
  String get datevConsultantNumber => 'Beraternummer';

  @override
  String get decisionSurfaceEmpty => 'Nichts wartet auf Sie';

  @override
  String get decisionSurfaceEmptyDetail => 'Alles ist erledigt.';

  @override
  String get defaultPeriodNone => 'Keine Präferenz (ganzer Tag)';

  @override
  String get defaultPeriodTitle => 'Standard-Buchungszeitraum';

  @override
  String get demoEntryAction => 'Den Demobereich erkunden';

  @override
  String get demoEntryBody =>
      'Alles darin ist erfunden: die Personen, die Buchungen und die Rechnungen sind für die Demonstration ausgedacht. Nichts davon erreicht einen echten Bereich, nichts verlässt dieses Gerät, und ein Konto ist nicht nötig. Das Zurücksetzen stellt alles wieder her, wann immer Sie möchten.';

  @override
  String get demoEntryStart => 'Loslegen';

  @override
  String get demoEntryTitle => 'Ein Bereich zum Umsehen';

  @override
  String get demoPersonaAdmin => 'Administrator:in';

  @override
  String get demoPersonaKiosk => 'Das Kiosk-Tablet';

  @override
  String get demoPersonaMember => 'Mitglied';

  @override
  String get demoPersonaOwner => 'Inhaber';

  @override
  String get demoSessionBadge => 'Demo';

  @override
  String get demoSessionBadgeHint =>
      'Sie erkunden einen Demonstrationsbereich. Nichts davon verlässt dieses Gerät.';

  @override
  String get demoSessionLeave => 'Demo verlassen';

  @override
  String get demoSessionReset => 'Demo zurücksetzen';

  @override
  String get demoSessionResetDone => 'Die Demo ist wieder im Ausgangszustand.';

  @override
  String get demoSessionViewAs => 'Ansicht als';

  @override
  String get deployEntityAccessories => 'Zubehör';

  @override
  String get deployEntityBookingRules => 'Buchungsregeln';

  @override
  String get deployEntityBranding => 'Farben';

  @override
  String get deployEntityClosureDays => 'Schließtage';

  @override
  String get deployEntityCreditProducts => 'Verkaufte Guthabenkarten';

  @override
  String get deployEntityDocumentDesign => 'Dokumentvorlagen';

  @override
  String get deployEntityDocumentLinks => 'Dokumentlinks';

  @override
  String get deployEntityFeatures => 'Funktionen';

  @override
  String get deployEntityFieldDefinitions => 'Fragen des Bereichs';

  @override
  String get deployEntityFloorPlan => 'Grundrisse (Ebenen, Plätze, Bilder)';

  @override
  String get deployEntityIdentity => 'Identität & Rechtliches';

  @override
  String get deployEntityInvitations => 'Einladungsvorlagen';

  @override
  String get deployEntityPackages => 'Pakete';

  @override
  String get deployEntityPaymentInstructions => 'Zahlungshinweise';

  @override
  String get deployEntityReminders => 'Mahnregeln';

  @override
  String get deployEntityRoles => 'Rollenmatrix';

  @override
  String get deployEntityServices => 'Services';

  @override
  String get deployEntitySites => 'Standorte';

  @override
  String get deployEntityTariffs => 'Tarife';

  @override
  String get deployEntityValidationRules => 'Freigaberegeln';

  @override
  String get deployEntityVat => 'USt';

  @override
  String get deployEntityWorkspaceRoles => 'Eigene Rollen des Bereichs';

  @override
  String get deploymentConfirm => 'Ausrollen';

  @override
  String get deploymentConfirmBody =>
      'Was dieser Raum für die angekreuzten Entitäten hält, wird durch das des Zwillings ersetzt. Das Journal behält den Weg zurück.';

  @override
  String get deploymentConfirmTitleDev => 'In diese DEV ausrollen?';

  @override
  String get deploymentConfirmTitleProd => 'In diese PROD ausrollen?';

  @override
  String get deploymentDirectionToDev => 'In die Entwicklung';

  @override
  String get deploymentDirectionToProd => 'In die Produktion';

  @override
  String get deploymentDone => 'Ausgerollt. Das Journal hat es.';

  @override
  String get deploymentFlowFromDev => 'Aus der DEV';

  @override
  String get deploymentFlowFromProd => 'Aus der PROD';

  @override
  String get deploymentFlowToDev => 'In die DEV';

  @override
  String get deploymentFlowToProd => 'In die PROD';

  @override
  String get deploymentIntroFromDev =>
      'Sie stehen auf der Produktionsseite. Was Sie unten ankreuzen, wird nach einer Vorschau aus dem Entwicklungszwilling in diesen Raum geholt.';

  @override
  String get deploymentIntroFromProd =>
      'Sie stehen auf der Entwicklungsseite. Was Sie unten ankreuzen, wird nach einer Vorschau aus dem Produktionszwilling in diesen Raum geholt.';

  @override
  String get deploymentIntroToDev =>
      'Sie stehen auf der Produktionsseite. Was Sie unten ankreuzen, wird nach einer Vorschau der Änderungen auf den Entwicklungszwilling ausgerollt.';

  @override
  String get deploymentIntroToProd =>
      'Sie stehen auf der Entwicklungsseite. Was Sie unten ankreuzen, wird nach einer Vorschau der Änderungen auf den Produktionszwilling ausgerollt.';

  @override
  String get deploymentJournal => 'Journal';

  @override
  String get deploymentJournalEmpty => 'Noch nichts ausgerollt.';

  @override
  String get deploymentKindConfiguration => 'Konfiguration';

  @override
  String get deploymentKindMasterData => 'Stammdaten';

  @override
  String get deploymentKindReports => 'Berichte';

  @override
  String get deploymentNeedsDevPermission =>
      'Für die Ausrollung in die Entwicklung braucht es die Berechtigung „In die Entwicklung ausrollen“.';

  @override
  String get deploymentNeedsProdPermission =>
      'Für die Ausrollung in die Produktion braucht es die Berechtigung „In die Produktion ausrollen“.';

  @override
  String get deploymentNoChange => 'Keine Änderung';

  @override
  String get deploymentNoTwin =>
      'Dieser Raum hat keinen Zwilling, dessen Mitglied Sie sind.';

  @override
  String get deploymentNothingToDo =>
      'Beide Seiten stimmen bei diesen Entitäten schon überein.';

  @override
  String get deploymentPreviewToDev =>
      'Was sich auf der Entwicklungsseite ändert';

  @override
  String get deploymentPreviewToProd =>
      'Was sich auf der Produktionsseite ändert';

  @override
  String get deploymentPullFromDev => 'Aus der DEV holen…';

  @override
  String get deploymentPullFromProd => 'Aus der PROD holen…';

  @override
  String get deploymentRequires => 'braucht';

  @override
  String get deploymentRollback => 'Zurückrollen';

  @override
  String get deploymentRolledBack => 'Zurückgerollt.';

  @override
  String get deploymentRolledBackLabel => 'zurückgerollt';

  @override
  String get deploymentTitle => 'Ausrollung';

  @override
  String get deploymentToDev => 'In die DEV ausrollen…';

  @override
  String get deploymentToProd => 'In die PROD ausrollen…';

  @override
  String get deskDetail => 'Ganzer Tisch';

  @override
  String get deskSupplementLabel => 'Tisch-Reservierungen';

  @override
  String get developerClear => 'Protokoll leeren';

  @override
  String get developerEmpty => 'Noch keine Protokolleinträge.';

  @override
  String get developerExport => 'Protokoll exportieren';

  @override
  String get developerExportReservations => 'Reservierungen exportieren';

  @override
  String get developerExportReservationsHint =>
      'Alle Buchungen und Check-ins — vergangene, laufende und künftige, in jedem Zustand — als CSV, für Analyse und Fehlersuche.';

  @override
  String get developerExportReservationsOwnHint =>
      'Ihre eigenen Buchungen und Check-ins, jeder Zustand, als CSV — der Export des ganzen Bereichs braucht die Datenexport-Berechtigung.';

  @override
  String get developerFilterAll => 'Alle';

  @override
  String get developerFilterErrors => 'Fehler';

  @override
  String get developerFilterWarnings => 'Warnungen+';

  @override
  String get developerMode => 'Entwicklermodus';

  @override
  String get developerModeWorkspaceHint =>
      'Gilt für alle Mitglieder dieses Workspace.';

  @override
  String get developerTitle => 'Entwickler';

  @override
  String get developmentBanner => 'Entwicklungs-Space — nichts hier ist echt';

  @override
  String get developmentWatermark => 'ENTWICKLUNG';

  @override
  String get directoryApproximate => 'Ungefähre Lage der Adresse';

  @override
  String get directoryCheckedIn => 'Eingecheckt';

  @override
  String directoryCheckedInSeat(String seat) {
    return 'Eingecheckt · $seat';
  }

  @override
  String get directoryClose => 'Schließen';

  @override
  String get directoryEmpty => 'Noch keine Mitglieder.';

  @override
  String directoryLastSeenDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Vor $days Tagen gesehen',
      one: 'Vor 1 Tag gesehen',
    );
    return '$_temp0';
  }

  @override
  String directoryLastSeenHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Vor $hours Stunden gesehen',
      one: 'Vor 1 Stunde gesehen',
    );
    return '$_temp0';
  }

  @override
  String directoryLastSeenMinutes(int minutes) {
    return 'Vor $minutes Min. gesehen';
  }

  @override
  String get directoryLinkAction => 'Verbinden';

  @override
  String get directoryLinkCheck => 'Prüfen';

  @override
  String get directoryLinkConnect => 'Referenzserver verbinden';

  @override
  String get directoryLinkDone =>
      'Verbunden. Die Spaces, die er veröffentlicht, sind jetzt unter Entdecken gelistet.';

  @override
  String get directoryLinkIntro =>
      'Das globale Verzeichnis liegt auf dem Referenzserver. Ist ein Server verbunden, wird jeder Space, den er veröffentlicht, für alle unter Entdecken gelistet.';

  @override
  String get directoryLinkNeedsAccount =>
      'Die Verbindung wird auf dem Referenzserver gespeichert: Verbinden Sie zuerst Ihr Konto dort.';

  @override
  String get directoryLinkStateDirectory =>
      'Dies ist der Referenzserver: Die Spaces, die er veröffentlicht, sind immer gelistet.';

  @override
  String get directoryLinkStateLinkable =>
      'Kann verbunden werden: Er antwortet und veröffentlicht Spaces, die diese App lesen kann.';

  @override
  String get directoryLinkStateLinked =>
      'Verbunden: Die Spaces, die er veröffentlicht, sind unter Entdecken gelistet.';

  @override
  String get directoryLinkStateUnreachable =>
      'Kann noch nicht verbunden werden: Er antwortet nicht, oder seine Version kann keine Spaces veröffentlichen.';

  @override
  String get directoryLocate => 'Auf der Karte anzeigen';

  @override
  String get directoryLocating => 'Öffentliche Adresse wird gesucht…';

  @override
  String get directoryLocationMissing =>
      'Standort nicht verfügbar. Der Eigentümer kann genaue Koordinaten veröffentlichen.';

  @override
  String get directoryNoUpcoming => 'Keine anstehenden Reservierungen';

  @override
  String get directoryOnline => 'Online';

  @override
  String get directoryOpenGroup => 'WhatsApp-Gruppe öffnen';

  @override
  String get directoryReservationsHeading => 'Reservierungen';

  @override
  String get directoryReservedNow => 'Jetzt reserviert';

  @override
  String directoryReservedNowSeat(String seat) {
    return 'Jetzt reserviert · $seat';
  }

  @override
  String get directoryReservedToday => 'Heute reserviert';

  @override
  String get directoryTitle => 'Mitglieder';

  @override
  String get directoryWhatsapp => 'Auf WhatsApp schreiben';

  @override
  String get documentsAdd => 'Dokument hinzufügen';

  @override
  String get documentsCategoryFinance => 'Finanzberichte';

  @override
  String get documentsCategoryGuides => 'Anleitungen & Handbücher';

  @override
  String get documentsCategoryLabel => 'Kategorie';

  @override
  String get documentsCategoryMinutes => 'Protokolle';

  @override
  String get documentsCategoryOther => 'Weitere Dokumente';

  @override
  String get documentsCategoryStatutes => 'Satzung & Rechtliches';

  @override
  String get documentsDelete => 'Dokument entfernen?';

  @override
  String get documentsEmpty =>
      'Noch kein Dokument. Verlinken Sie Satzung, Anleitungen und Berichte aus jedem Drive.';

  @override
  String get documentsInvalid =>
      'Ein Dokument braucht einen Titel und einen https://-Link.';

  @override
  String get documentsProviderLabel => 'Gespeichert auf';

  @override
  String get documentsRoleAdmin => 'Admins und Inhaber';

  @override
  String get documentsRoleLabel => 'Sichtbar für';

  @override
  String get documentsRoleMember => 'Alle Mitglieder';

  @override
  String get documentsRoleOwner => 'Nur Inhaber';

  @override
  String get documentsTitle => 'Dokumente';

  @override
  String get documentsTitleLabel => 'Titel';

  @override
  String get documentsUrlHelper =>
      'Fügen Sie den Freigabelink Ihres Drives ein — die Zugriffsrechte bleiben dort verwaltet.';

  @override
  String get documentsUrlLabel => 'Link (https://…)';

  @override
  String get dunningAutomatic => 'Automatische Mahnungen';

  @override
  String get dunningAutomaticHint =>
      'Einmal täglich erhalten Rechnungen, deren erfasste Zahlungsfrist abgelaufen ist, von selbst die nächste Mahnstufe — für den noch offenen Betrag, nie während eine Zahlung geprüft wird oder die Rechnung angehalten ist. Rechnungen ohne erfasste Frist bleiben Ihnen überlassen. Aus: Sie versenden jede Mahnung selbst.';

  @override
  String get dunningBetweenDays => 'Tage zwischen den Mahnungen';

  @override
  String dunningDueChip(int level) {
    return 'Mahnstufe $level fällig';
  }

  @override
  String get dunningFirstAfterDays => 'Tage bis zur ersten Erinnerung';

  @override
  String get dunningLevels => 'Anzahl der Mahnstufen';

  @override
  String get dunningSaved => 'Mahnregeln gespeichert.';

  @override
  String get dunningSettingsTitle => 'Mahnregeln';

  @override
  String get eInvoiceGapBuyerLegalIdAdvisable =>
      'Die SIREN des Käufers fehlt. Eine französische Plattform leitet danach weiter: tragen Sie sie vor der Übermittlung im Profil des Mitglieds ein. Keine Ablehnung — die Datei ist auch ohne sie gültig.';

  @override
  String get eInvoiceGapMissingBuyerLegalId =>
      'Der Käufer ist ein französisches Unternehmen ohne SIREN — tragen Sie die Registernummer im Profil des Mitglieds ein.';

  @override
  String get eInvoiceGapMixedNotSubjectLines =>
      'Eine nicht steuerbare Zeile (Pfand) steht neben besteuerten Zeilen — EN 16931 lehnt die Mischung ab; stellen Sie das Pfand gesondert in Rechnung.';

  @override
  String get editorAccessoriesLabel => 'Zubehör';

  @override
  String get editorAddLevel => 'Etage hinzufügen';

  @override
  String get editorAmenitiesLabel => 'Ausstattung';

  @override
  String get editorBackgroundImage => 'Hintergrundbild';

  @override
  String get editorBackgroundRemove => 'Hintergrundbild entfernen';

  @override
  String get editorBackgroundReplace => 'Hintergrundbild ersetzen';

  @override
  String get editorBackgroundSet => 'Hintergrundbild festlegen';

  @override
  String get editorBlockedLabel => 'Gesperrt (Wartung)';

  @override
  String get editorBookableAsWhole => 'Als Ganzes buchbar';

  @override
  String get editorBookableAsWholeHint =>
      'Jemand kann ihn ganz reservieren, mit allem darin.';

  @override
  String get editorCanvasSemantics => 'Zeichenfläche des Grundrisses';

  @override
  String get editorChairLabel => 'Stuhltyp';

  @override
  String get editorDeleteElementConfirm =>
      'Dieses Element löschen? Alles darauf wird ebenfalls entfernt.';

  @override
  String get editorDeleteElementConfirmAudit =>
      'Dieses Element löschen? Alles darauf Platzierte wird ebenfalls entfernt. Buchungen, die darauf verweisen, behalten einen Text-Schnappschuss für Audits; offene Buchungen werden storniert.';

  @override
  String get editorDeleteLevelConfirm =>
      'Diese Etage löschen? Alle Büros, Tische und Plätze darauf werden entfernt.';

  @override
  String get editorDeleteLevelConfirmAudit =>
      'Diese Ebene löschen? Alle Büros, Tische und Sitzplätze darauf werden entfernt. Buchungen, die darauf verweisen, behalten einen Text-Schnappschuss für Audits; offene Buchungen werden storniert.';

  @override
  String get editorDeskFull => 'Auf diesem Tisch ist kein Platz mehr.';

  @override
  String get editorDeskNameDefault => 'Tisch';

  @override
  String get editorDeskNameLabel => 'Name des Tisches';

  @override
  String get editorDeskProperties => 'Tisch';

  @override
  String get editorDuplicate => 'Duplizieren';

  @override
  String get editorEmptyFloorAction => 'Ersten Raum zeichnen';

  @override
  String get editorEmptyFloorBody =>
      'Alles liegt in einem Raum: zeichnen Sie einen, stellen Sie Tische hinein und dann Plätze auf die Tische.';

  @override
  String get editorEmptyFloorTitle => 'Diese Etage ist leer';

  @override
  String get editorHintDesk =>
      'In einem Raum ziehen, um einen Tisch zu zeichnen';

  @override
  String get editorHintImage => 'Tippen, wo das Bild hin soll';

  @override
  String get editorHintOffice => 'Ziehen, um einen Raum zu zeichnen';

  @override
  String get editorHintSeat =>
      'Auf einen Tisch tippen, um einen Platz hinzuzufügen';

  @override
  String get editorLevelActions => 'Etagen-Aktionen';

  @override
  String get editorLevelBookableOff => 'Nicht als Ganzes buchbar';

  @override
  String get editorLevelBookableOn => 'Als Ganzes buchbar';

  @override
  String get editorLevelNameLabel => 'Name der Etage';

  @override
  String get editorMediaSaving => 'Bild wird gespeichert…';

  @override
  String get editorMediaWriteFailed =>
      'Das Speichern des Bildes konnte nicht bestätigt werden. Erneutes Versuchen fügt es nie doppelt hinzu.';

  @override
  String get editorNewOffice => 'Neues Büro';

  @override
  String get editorNoAccessories =>
      'Noch kein Zubehör — legen Sie es unter Einstellungen → Zubehör an.';

  @override
  String get editorNoAccessoriesAction =>
      'Noch keine Ausstattung — jetzt einrichten';

  @override
  String get editorNoLevels =>
      'Noch keine Etagen. Fügen Sie die erste Etage Ihres Workspace hinzu.';

  @override
  String get editorOfficeNameDefault => 'Büro';

  @override
  String get editorOfficeNameLabel => 'Name des Büros';

  @override
  String get editorOfficeProperties => 'Büro';

  @override
  String get editorOpenTooltip => 'Workspace bearbeiten';

  @override
  String get editorOrientationHint => 'Wohin der Stuhl auf dem Plan schaut.';

  @override
  String get editorOrientationLabel => 'Sitzrichtung';

  @override
  String get editorPlacementOutside =>
      'Muss vollständig innerhalb eines Büros liegen.';

  @override
  String get editorPlacementOverlap => 'Überschneidet ein vorhandenes Element.';

  @override
  String get editorProperties => 'Eigenschaften';

  @override
  String get editorRenameLevel => 'Umbenennen';

  @override
  String get editorSeatNameDefault => 'Platz';

  @override
  String get editorSeatNameLabel => 'Name des Platzes';

  @override
  String get editorSeatNfcDuplicate =>
      'Dieser Tag ist bereits mit einem anderen Stuhl verknüpft.';

  @override
  String get editorSeatNfcHelp =>
      'Tag-UID in Hex — leer lassen für keinen Tag.';

  @override
  String get editorSeatNfcLabel => 'NFC/RFID-Tag';

  @override
  String get editorSeatNfcRead => 'Jetzt einen Tag lesen';

  @override
  String get editorSeatNfcReadFailed =>
      'Der Tag-Leser konnte nicht gestartet werden.';

  @override
  String get editorSeatNoDesk =>
      'Plätze können nur auf einem Tisch platziert werden.';

  @override
  String get editorSeatProperties => 'Platz';

  @override
  String get editorTitle => 'Workspace-Editor';

  @override
  String get editorToolDesk => 'Tisch';

  @override
  String get editorToolErase => 'Löschen';

  @override
  String get editorToolImage => 'Bild';

  @override
  String get editorToolOffice => 'Büro';

  @override
  String get editorToolSeat => 'Platz';

  @override
  String get editorToolSelect => 'Auswahl';

  @override
  String get einvoiceConfigClear => 'Plattform entfernen';

  @override
  String get einvoiceConfigCleared => 'Plattform entfernt.';

  @override
  String get einvoiceConfigEndpoint => 'Upload-URL';

  @override
  String get einvoiceConfigField => 'Feldname der Datei (Standard file)';

  @override
  String get einvoiceConfigHeader => 'Auth-Header (Standard Authorization)';

  @override
  String get einvoiceConfigIntro =>
      'Wohin DesKilo Ihre Rechnungen sendet. Jede Plattform, die einen Upload mit Token annimmt, funktioniert — eine zugelassene Plattform, ein Peppol Access Point, eine nationale Plattform. Das Token liegt serverseitig und kommt nie zurück.';

  @override
  String get einvoiceConfigSaved => 'Plattform gespeichert.';

  @override
  String get einvoiceConfigTitle => 'E-Rechnungs-Plattform';

  @override
  String get einvoiceConfigToken => 'Token oder Zugangsdaten';

  @override
  String get einvoiceConfigTokenSet =>
      'Ein Token ist gespeichert (neues eingeben, um es zu ersetzen).';

  @override
  String get einvoiceConfigUnavailable =>
      'Die Plattform-Einstellungen konnten nicht geladen werden. Verbindung prüfen und erneut versuchen.';

  @override
  String get einvoiceCustomerSectionHelp =>
      'Wohin Rechnungen für den Kunden gehen: sein Peppol-Zugangspunkt, Portal oder die vereinbarte Upload-API — getrennt von der staatlichen Plattform.';

  @override
  String get einvoiceCustomerSectionTitle => 'Zustelldienst des Kunden';

  @override
  String get einvoiceDevEndpoint => 'Dev-Upload-URL';

  @override
  String get einvoiceDevToken => 'Dev-Token oder Zugangsdaten';

  @override
  String get einvoiceEnvDev => 'Dev (Testplattform)';

  @override
  String get einvoiceEnvProd => 'Produktion';

  @override
  String get einvoiceEnvProdHint => 'Die echte Übermittlung.';

  @override
  String get einvoiceEnvTestHint =>
      'Eine Probe — als Testversand protokolliert.';

  @override
  String get einvoiceEnvTitle => 'An welche Plattform senden?';

  @override
  String get einvoiceEnvUat => 'UAT (Testplattform)';

  @override
  String get einvoiceTestEnvsHelp =>
      'Eigene Endpunkte und Token für Proben. Die Auswahl erscheint beim Senden nur bei aktivem Entwicklermodus.';

  @override
  String get einvoiceTestEnvsTitle => 'Testumgebungen (UAT / Dev)';

  @override
  String get einvoiceUatEndpoint => 'UAT-Upload-URL';

  @override
  String get einvoiceUatToken => 'UAT-Token oder Zugangsdaten';

  @override
  String get emblemChoose => 'Bild auswählen';

  @override
  String get emblemFailed =>
      'Das Emblem konnte nicht gespeichert werden. Es hat sich nichts geändert.';

  @override
  String get emblemHint =>
      'Ein kleines Bild unter dem Namen der App im Menü. Es wird auf höchstens 512 Pixel neu gezeichnet und ohne die Metadaten der Datei gespeichert.';

  @override
  String get emblemNotAnImage => 'Diese Datei ist kein Bild.';

  @override
  String get emblemRemove => 'Entfernen';

  @override
  String get emblemRemoved => 'Emblem entfernt.';

  @override
  String get emblemSaved => 'Emblem gespeichert.';

  @override
  String get emblemTitle => 'Emblem';

  @override
  String get emblemTooHeavy =>
      'Dieses Bild ist zu schwer für ein Zeichen, das mit 28 Pixeln angezeigt wird.';

  @override
  String get entitlementBlockedFull =>
      'Sie haben diesen Monat alle Tage aufgebraucht. Bitten Sie einen Admin um mehr oder beantragen Sie zusätzliche Halbtage.';

  @override
  String entitlementDaysLeft(String left) {
    return 'Noch $left Tage';
  }

  @override
  String entitlementDaysUsed(String used, String total) {
    return '$used von $total Tagen genutzt';
  }

  @override
  String get entitlementPackageFull =>
      'Sie haben diesen Monat alle Tage aufgebraucht. Kaufen Sie ein Paket, um weiter zu buchen.';

  @override
  String entitlementPaygRate(String rate) {
    return 'Tage über Ihren Tarif hinaus kosten je $rate.';
  }

  @override
  String get entitlementTitle => 'Diesen Monat';

  @override
  String get environmentDev => 'Entwicklung — zum Ausprobieren';

  @override
  String get environmentHint =>
      'Ein Entwicklungs-Space sagt das auf jedem Bildschirm und versieht jedes Dokument mit einem Wasserzeichen. Erklären Sie ihn erst dann zur Produktion, wenn die Rechnungen daraus wirklich geschuldet sind.';

  @override
  String get environmentLabel => 'Art des Space';

  @override
  String get environmentPairsCreateTwin => 'Zwilling anlegen';

  @override
  String get environmentPairsCreateTwinDesc =>
      'Ein Entwicklungs- und ein Produktionsraum gleichen Namens; die Konfiguration wird einmal kopiert.';

  @override
  String get environmentPairsPairedDev =>
      'Gepaart mit seinem Entwicklungszwilling';

  @override
  String get environmentPairsPairedProd =>
      'Gepaart mit seinem Produktionszwilling';

  @override
  String get environmentPairsTwinCreated => 'Der Zwilling ist angelegt.';

  @override
  String get environmentProd => 'Produktion — die Rechnungen sind geschuldet';

  @override
  String get environmentProdConfirmAction => 'Zur Produktion erklären';

  @override
  String get environmentProdConfirmBody =>
      'Das Band verschwindet und Dokumente verlieren ihr Wasserzeichen. Bereits ausgestellte Rechnungen ändern sich nicht: Sie behalten das Wasserzeichen, das sie bei der Ausstellung trugen.';

  @override
  String get environmentProdConfirmTitle =>
      'Diesen Space zur Produktion erklären?';

  @override
  String get environmentSaved => 'Art des Space gespeichert.';

  @override
  String get erasurePreviewKept => 'Aufbewahrt, und warum';

  @override
  String get erasurePreviewOutside => 'Außerhalb dieser Installation';

  @override
  String get erasurePreviewRemoved => 'Gelöscht';

  @override
  String get erasurePreviewTitle => 'Was die Löschung hier bewirkt';

  @override
  String get erasureStoreAccounts =>
      'Rechnungen und Buchungen — Buchhaltungsbelege, für die gesetzliche Frist aufbewahrt; ausgestellte Dokumente werden nicht geändert';

  @override
  String get erasureStoreAnswers =>
      'Ihre Antworten auf die Fragen des Bereichs';

  @override
  String get erasureStoreBackups =>
      'Sicherungen des Betreibers — laufen nach ihrem Turnus ab';

  @override
  String get erasureStoreDeviceCaches =>
      'Kopien auf Ihren Geräten — beim Abmelden auf jedem gelöscht';

  @override
  String get erasureStoreHeldAnswers =>
      'Antworten unter einer vom Bereich dokumentierten Aufbewahrungspflicht';

  @override
  String get erasureStoreMembership =>
      'Die Mitgliedschaftszeile — verknüpft die aufbewahrten Daten; pseudonym, nicht anonym';

  @override
  String get erasureStoreMessages => 'Von Ihnen gesendete Nachrichten';

  @override
  String get erasureStoreOpenBookings => 'Offene Buchungen — storniert';

  @override
  String get erasureStoreOtherInstallations =>
      'Eine andere DesKilo-Installation ist ein eigener Verantwortlicher — wenden Sie sich direkt an sie';

  @override
  String get erasureStorePastBookings =>
      'Vergangene Buchungen — der Belegungsnachweis des Bereichs';

  @override
  String get erasureStoreProfile =>
      'Ihr Profil (wenn dies Ihr letzter Bereich ist)';

  @override
  String get errorOffline =>
      'Keine Verbindung — es wurde nichts gesendet. Versuchen Sie es erneut, sobald Sie wieder online sind.';

  @override
  String get eventAccept => 'Annehmen';

  @override
  String get eventAutoValidated => 'Automatisch bestätigt';

  @override
  String eventExpenseDeviation(Object reason, Object scheduled) {
    return 'validiert $scheduled — $reason';
  }

  @override
  String eventExpenseRepartitionLine(
    String actor,
    String title,
    String amount,
    int count,
  ) {
    return '$actor verteilt „$title“ — $amount auf $count Mitglieder';
  }

  @override
  String eventExpenseScheduleLine(Object actor, Object amount, Object title) {
    return '$actor plant „$title“ — $amount wiederkehrend';
  }

  @override
  String eventExpenseSubmitted(String actor, String amount) {
    return '$actor hat eine Ausgabe von $amount eingereicht';
  }

  @override
  String eventForSubject(String name) {
    return 'für $name';
  }

  @override
  String eventInvoicePaid(String number, String amount) {
    return 'Rechnung $number bezahlt — $amount';
  }

  @override
  String eventInvoiceReminderLine(String number, int level, String amount) {
    return 'Mahnstufe $level: Rechnung $number — $amount noch offen';
  }

  @override
  String eventInvoiceWriteoffLine(String actor, String number, String amount) {
    return '$actor bittet um Stornierung des Restbetrags von $number — $amount';
  }

  @override
  String eventPaymentSubmitted(String actor, String amount) {
    return '$actor hat eine Zahlung von $amount erfasst';
  }

  @override
  String eventPaymentTermsChangeLine(String actor, String terms) {
    return '$actor beantragt Zahlungsbedingungen: $terms';
  }

  @override
  String eventPriceNegotiationItems(int count) {
    return '$count Artikel';
  }

  @override
  String eventPriceNegotiationLine(String actor, String member, String terms) {
    return '$actor schlägt Konditionen für $member vor: $terms';
  }

  @override
  String eventQuotaRequested(String actor, int halfDays, String period) {
    return '$actor beantragt $halfDays zusätzliche halbe Tage für $period';
  }

  @override
  String get eventReject => 'Ablehnen';

  @override
  String eventRejectedBy(String name, String when) {
    return 'Abgelehnt von $name · $when';
  }

  @override
  String eventReservationCancelled(String actor, String target) {
    return '$actor hat die Reservierung von $target storniert';
  }

  @override
  String eventReservationCreated(String actor, String target) {
    return '$actor hat $target reserviert';
  }

  @override
  String get eventReservationDeleteCheckedIn => 'eingecheckt';

  @override
  String eventReservationDeleteLine(String actor, String date, String state) {
    return '$actor bittet um Löschung der Buchung vom $date ($state)';
  }

  @override
  String get eventReservationDeleteUnused => 'nie genutzt';

  @override
  String eventReservationModified(String actor, String target) {
    return '$actor hat die Reservierung von $target geändert';
  }

  @override
  String eventRoleDemote(String actor) {
    return '$actor beantragt, die Rolle Administrator:in zu entziehen';
  }

  @override
  String eventRoleGiven(String actor, String role, String member) {
    return '$actor gibt $member die Rolle $role';
  }

  @override
  String eventRolePromote(String actor) {
    return '$actor beantragt die Rolle Administrator:in';
  }

  @override
  String eventRoleTakenBack(String actor, String role, String member) {
    return '$actor entzieht $member die Rolle $role';
  }

  @override
  String eventServiceChargeTitle(String name, int quantity, String amount) {
    return '$name ×$quantity — $amount';
  }

  @override
  String get eventSystemDecider => 'System';

  @override
  String get eventTypeAdjustment => 'Korrektur';

  @override
  String get eventTypeExpense => 'Ausgabe';

  @override
  String get eventTypeExpenseRepartition => 'Gemeinsame Ausgabe';

  @override
  String get eventTypeExpenseSchedule => 'Geplante Ausgabe';

  @override
  String get eventTypeInvoiceIssue => 'Rechnungsstellung';

  @override
  String get eventTypeInvoicePayment => 'Rechnungszahlung';

  @override
  String get eventTypeInvoiceReminder => 'Zahlungserinnerung';

  @override
  String get eventTypeInvoiceVoid => 'Rechnungsstorno';

  @override
  String get eventTypeInvoiceWriteoff => 'Restbetrag-Stornierung';

  @override
  String get eventTypeMatrixChange => 'Änderung der Berechtigungsmatrix';

  @override
  String get eventTypeMemberJoin => 'Neues Mitglied';

  @override
  String get eventTypeMemberStatusChange => 'Mitgliedschaftsänderung';

  @override
  String get eventTypePayment => 'Zahlung';

  @override
  String get eventTypePaymentTermsChange => 'Zahlungsbedingungen';

  @override
  String get eventTypePriceNegotiation => 'Preisverhandlung';

  @override
  String get eventTypeQuota => 'Zusätzliche halbe Tage';

  @override
  String get eventTypeRefund => 'Erstattung';

  @override
  String get eventTypeReservation => 'Reservierung';

  @override
  String get eventTypeReservationDelete => 'Buchungslöschung';

  @override
  String get eventTypeRoleChange => 'Rollenwechsel';

  @override
  String get eventTypeServiceCharge => 'Leistung';

  @override
  String get eventTypeSpaceReservation => 'Ganzraum-Reservierungen';

  @override
  String get eventTypeSubscriptionChange => 'Abonnementänderung';

  @override
  String get eventTypeUnknown => 'Aktivität';

  @override
  String get eventTypeUsageCorrection => 'Früher gegangen';

  @override
  String get eventTypeUsageRecordDelete => 'Nutzungssatz entfernen';

  @override
  String eventUsageCorrectionLine(String actor, String from, String to) {
    return '$actor bittet um $to statt $from';
  }

  @override
  String eventUsageRecordDeleteLine(String actor, String space) {
    return '$actor möchte einen Nutzungssatz entfernen ($space)';
  }

  @override
  String eventValidatedBy(String name, String when) {
    return 'Bestätigt von $name · $when';
  }

  @override
  String eventValidationStage(int stage, int required) {
    return 'Freigabe $stage von $required angefragt';
  }

  @override
  String eventValidations(int current, int required) {
    return '$current/$required Bestätigungen';
  }

  @override
  String get eventsEmpty => 'Noch keine Ereignisse.';

  @override
  String get eventsFilterAll => 'Alle';

  @override
  String get eventsMessagesHeader => 'Nachrichten';

  @override
  String get eventsPendingHeader => 'Wartet auf Ihre Bestätigung';

  @override
  String get expenseCategoryCoffee => 'Kaffee & Küche';

  @override
  String get expenseCategoryEquipment => 'Ausstattung';

  @override
  String get expenseCategoryOther => 'Sonstiges';

  @override
  String get expenseCategorySupplies => 'Verbrauchsmaterial';

  @override
  String get expenseInvalidAmount => 'Geben Sie einen Betrag über null ein.';

  @override
  String get expenseInvalidSupplyQuantity =>
      'Geben Sie mindestens eine Einheit ein.';

  @override
  String get expenseInvalidUnitPrice =>
      'Geben Sie einen gültigen Stückpreis ein oder lassen Sie ihn leer.';

  @override
  String get expenseMissingSupplyName => 'Benennen Sie den neuen Artikel.';

  @override
  String get expenseSupplyHint =>
      'Kaffeekapseln, Staubsaugerbeutel… Nach der Genehmigung steht der Artikel als verbrauchbare Leistung im Regal: wer ihn nutzt, zahlt dafür.';

  @override
  String get expenseSupplyItem => 'Artikel';

  @override
  String get expenseSupplyNewItem => 'Neuer Artikel';

  @override
  String get expenseSupplyQuantity => 'Menge';

  @override
  String get expenseSupplyToggle => 'Das ist ein Vorrat für den Raum';

  @override
  String get expenseSupplyUnitPrice => 'Stückpreis (was ein Verbrauch kostet)';

  @override
  String get expenseSupplyUnitPriceHint =>
      'Vorbelegt mit Betrag ÷ Menge; runden Sie nach Belieben.';

  @override
  String get exportClaimExchange =>
      'Für Ihre Steuerberatung zum Importieren und Prüfen — keine Meldung an eine Behörde.';

  @override
  String get exportClaimRegulatory => 'Das Format, das Ihr Finanzamt verlangt.';

  @override
  String get exportClaimSubset =>
      'Nur Rechnungen und Zahlungen, kein Hauptbuch. Die Datei sagt das in ihrem Kopf.';

  @override
  String get exportNoCompleteBooks =>
      'Aus Rechnungen und Zahlungen rekonstruiert — DesKilo führt keine doppelte Buchführung, dies sind also nicht Ihre vollständigen Bücher. Ihre Steuerberatung ergänzt sie.';

  @override
  String get exportUncertifiedSoftware =>
      'Nach der veröffentlichten Spezifikation erstellt, aber DesKilo ist in diesem Land keine zertifizierte Software — klären Sie mit Ihrer Steuerberatung, ob das für Sie Pflicht ist.';

  @override
  String get featureAccessorySupplements => 'Zubehör-Aufpreise';

  @override
  String get featureAccessorySupplementsDesc =>
      'Bepreistes Platz-Zubehör pro gebuchtem Halbtag berechnen. Gilt für Buchungen ab der Aktivierung.';

  @override
  String get featureAccountingBookDesc =>
      'Wer die offiziellen Bücher jedes Rechnungsstellers führt: Deskilo als Vorkontierung, ein lokales Buch oder ein externes Buchhaltungssystem, das maßgeblich bleibt. Jeder Rechnungssteller nennt Währung, Geschäftsjahr und Buchungsgrundlage. Aus: Mitgliedersalden und Rechnungen funktionieren wie bisher.';

  @override
  String get featureAccountingBookTitle => 'Buchführung';

  @override
  String get featureAdminInvoicing => 'Admins stellen Rechnungen aus';

  @override
  String get featureAdminInvoicingDesc =>
      'Auch Admins stellen Rechnungen aus. Der Inhaber kann es immer.';

  @override
  String get featureAdminLevelAssign => 'Admins können Etagen zuweisen';

  @override
  String get featureAdminLevelAssignDesc =>
      'Admins weisen Mitgliedern Etagen-Reservierungen zu. Der Inhaber kann es immer.';

  @override
  String get featureAdminSeatBlocking => 'Admins können Plätze sperren';

  @override
  String get featureAdminSeatBlockingDesc =>
      'Admins markieren Plätze als nicht reservierbar für Wartung. Der Inhaber kann es immer.';

  @override
  String featureAlsoEnabled(String features) {
    return 'Ebenfalls eingeschaltet: $features';
  }

  @override
  String featureAlsoEnables(String features) {
    return 'Das schaltet außerdem $features ein';
  }

  @override
  String get featureAutoCheckInOut => 'Auto-Check-in/-out am Tagesende';

  @override
  String get featureAutoCheckInOutDesc =>
      'Reservierungen ohne Check-in oder Check-out schließen sich selbst, sobald ihre Zeit vorbei ist.';

  @override
  String get featureBadgeSignInDesc =>
      'Mitglieder melden sich an, indem sie ihren Ausweis scannen und ihre PIN eingeben, statt eine E-Mail-Adresse auf einem gemeinsam genutzten Tablet zu tippen. Jedes Mitglied setzt seine eigene PIN und aktiviert seinen eigenen Ausweis.';

  @override
  String get featureBadgeSignInTitle => 'Anmeldung per Ausweis';

  @override
  String get featureBookForOthers => 'Für andere buchen';

  @override
  String get featureBookForOthersDesc =>
      'Admins und Inhaber buchen Plätze für andere Mitglieder.';

  @override
  String get featureBookingGateDesc =>
      'Jede Buchungsfläche — Plan, Tages-, Wochen- und Monatsansicht, Buchungsblatt, Kiosk, QR- oder NFC-Scan — prüft die Verfügbarkeitsparameter, bevor sie ein Zeitfenster anbietet, und nennt den Grund, wenn sie es nicht kann; geschlossene Tage erscheinen in jeder Ansicht geschlossen, eine Legende benennt die Platzzustände, und Admins dürfen Mitglieder auschecken, wo die Regel es erlaubt.';

  @override
  String get featureBookingGateTitle => 'Buchungsprüfung';

  @override
  String get featureBookingPoliciesDesc =>
      'Konfigurierbares Buchungsverhalten: vergangene Buchungen, Minutenbuchungen außerhalb der Arbeitszeiten, Admin-Check-out.';

  @override
  String get featureBookingPoliciesTitle => 'Buchungsregeln';

  @override
  String get featureCalendarFileExportDesc =>
      'Erlaubt einem Mitglied, eine seiner eigenen Buchungen als Standard-Kalenderdatei (.ics) für den Kalender zu speichern, den es bereits nutzt. Die Datei enthält nur Zeit, gebuchten Platz und den Namen des Coworking-Spaces — keinen Betrag, keinen Namen, keine Notiz, keinen Link — und sie ist eine Momentaufnahme: Eine spätere Änderung der Buchung aktualisiert eine bereits gespeicherte Datei nicht. In keinen Kalender wird geschrieben, nichts wird synchronisiert. Aus blendet die Schaltfläche aus.';

  @override
  String get featureCalendarFileExportTitle => 'Kalenderdatei einer Buchung';

  @override
  String get featureCalendarHubDesc =>
      'Der Kalender zeigt alles Datierte — Buchungen, Check-ins, Meldungen, Nachrichten, Rechnungen, Zahlungen, Verbrauch, Erinnerungen — für einen Tag oder Zeitraum, jede Zeile öffnet ihre Quelle. Aus: nur Reservierungen.';

  @override
  String get featureCalendarHubTitle => 'Kalender-Hub';

  @override
  String get featureCalendarTab => 'Kalender-Tab';

  @override
  String get featureCalendarTabDesc =>
      'Monatsübersicht über Buchungen und Schließtage.';

  @override
  String get featureCalendarValidationsDesc =>
      'Jede Entscheidung zu einem Ereignis erscheint im Kalender zum Zeitpunkt der Entscheidung, nicht des Ereignisses: wer was freigegeben oder abgelehnt hat, und wann. Ein Tippen öffnet den Verlauf. Aus: der Kalender trägt keine Entscheidungen.';

  @override
  String get featureCalendarValidationsTitle => 'Freigaben im Kalender';

  @override
  String get featureCalendarViewsDesc =>
      'Der Kalender-Tab als Agenda, Woche und Monat: Tagesmarker nach Art, geschlossene Tage als geschlossen, Kopfzeilen Heute / Morgen, Zahlungsfälligkeiten und geplante Ausgaben im Feed. Aus: der schlichte Tag-oder-Zeitraum-Wähler über dem Feed.';

  @override
  String get featureCalendarViewsTitle => 'Kalenderansichten';

  @override
  String get featureCapacityKpiDesc =>
      'Zeigt Eigentümern und Reservierungsverwaltern, wie viel der angebotenen Platzzeit eines Monats reserviert wurde, wie das berechnet wird und was die Zahl nicht wissen kann.';

  @override
  String get featureCapacityKpiTitle => 'Platzauslastung';

  @override
  String get featureCaptureProtectionDesc =>
      'Nachrichtenbildschirme verweigern Bildschirmfotos und Bildschirmaufnahmen, wo das Gerät es erlaubt, verbergen ihren Inhalt während einer Aufnahme und melden ein Bildschirmfoto im Gespräch, wo es nur erkannt werden kann. Ein Browser kann Bildschirmfotos nicht verhindern; dort wird das Gespräch unscharf, sobald der Tab den Fokus verliert.';

  @override
  String get featureCaptureProtectionTitle => 'Schutz vor Bildschirmaufnahmen';

  @override
  String get featureCarnetsDesc =>
      'Mehrfachkarten mit Halbtagen verkaufen, die über Monate verbraucht werden, wenn ein Mitglied über sein Abo hinaus bucht — einmal beim Verkauf berechnet.';

  @override
  String get featureCarnetsTitle => 'Mehrfachkarten';

  @override
  String get featureChangeUnconfirmed =>
      'Die Änderung wurde gesendet, aber die Funktionen konnten zur Bestätigung nicht neu geladen werden. Öffnen Sie den Bildschirm erneut, um den Stand zu sehen.';

  @override
  String get featureChangedMeanwhile =>
      'Die Funktionen haben sich inzwischen geändert, daher wurde nichts gespeichert. Prüfen Sie die Liste und schalten Sie erneut.';

  @override
  String get featureCoOwner => 'Mitinhaber';

  @override
  String get featureCoOwnerDesc =>
      'Mit-Inhaber ernennen: Inhaber-Rechte sofort (aktiv) oder wartende Nachfolge (passiv).';

  @override
  String get featureConfigurationTransfer => 'Konfiguration in der Raumdatei';

  @override
  String get featureConfigurationTransferDesc =>
      'Die Raumdatei (XML) trägt die gesamte Konfiguration — Tarife, rechtliche Identität, Buchungs- und Freigaberegeln, Rollen, Dokumentvorlagen, Standorte, Schließtage — und der Import wendet sie an, auch auf einen Raum, der schon Buchungen hat. Aus: die Datei trägt nur Einstellungen und Grundriss.';

  @override
  String get featureCustomFieldsDesc =>
      'Der Bereich kann im Identitätsformular eigene Fragen stellen — eine Funktion im Vorstand, ein Eintrittsdatum, ein Notfallkontakt. Die Antworten gehören zur Mitgliedschaft, eine hier gestellte Frage folgt also niemandem anderswohin.';

  @override
  String get featureCustomFieldsTitle => 'Fragen dieses Bereichs';

  @override
  String get featureCustomRolesDesc =>
      'Der Arbeitsbereich kann eigene Rollen festlegen — Kassenwart, Schriftführer — die Berechtigungen zur Rolle eines Mitglieds hinzufügen. Sie nehmen nie eine weg, und ein Eigentümer behält immer alle.';

  @override
  String get featureCustomRolesTitle => 'Rollen, die dieser Bereich festlegt';

  @override
  String get featureDataAccessLogDesc =>
      'Mitglieder sehen, wer wann ihre Finanzen eingesehen hat (vom Server geschrieben, nie umgehbar). Aus: die Zeile ist verborgen, das Protokoll bleibt.';

  @override
  String get featureDataAccessLogTitle => 'Datenzugriffsprotokoll';

  @override
  String get featureDataExport => 'Datenexport (Excel)';

  @override
  String get featureDataExportDesc =>
      'Alle Daten des Spaces als Excel-Arbeitsmappe herunterladen.';

  @override
  String get featureDecisionSurfaceDesc =>
      'Ein Ort, der beantwortet: „Wartet etwas auf mich?“ — sortiert danach, was die Verzögerung kostet: zuerst Geld, das abfließt, dann jemand, der auf eine Antwort wartet. Eine Zeile erscheint nur, wenn jemand entscheiden oder handeln muss; eine Zahl, mit der niemand etwas anfangen kann, bleibt auf ihrem eigenen Bildschirm.';

  @override
  String get featureDecisionSurfaceTitle => 'Was auf Sie wartet';

  @override
  String get featureDeletionRequests => 'Lösch-Anträge für Buchungen';

  @override
  String get featureDeletionRequestsDesc =>
      'Mitglieder können die Löschung einer vergangenen oder eingecheckten Buchung BEANTRAGEN; Inhaber/Admin validieren. Aus: solche Buchungen sind gar nicht löschbar.';

  @override
  String get featureDemoMode => 'Der Demobereich';

  @override
  String get featureDemoModeDesc =>
      'Ein erfundener Bereich, den jede Person vom Anmeldebildschirm aus öffnen kann, mit eigenen Personen, Buchungen und Rechnungen. Nichts davon erreicht einen echten Bereich oder verlässt das Gerät, und ein Konto ist nicht nötig. Aus: das Angebot erscheint nicht.';

  @override
  String get featureDeployments => 'Ausrollungen';

  @override
  String get featureDeploymentsDesc =>
      'Konfiguration und Stammdaten zwischen den beiden Seiten eines Paars ausgerollt, Entität für Entität, mit einer Vorschau der Änderungen und einem Journal, das zurückrollen kann. Aus: die Zwillinge werden von Hand gepflegt, jeder für sich.';

  @override
  String get featureDetailChange => 'Bei den Schaltern ändern';

  @override
  String featureDetailGrantsPermission(String permission) {
    return 'Gewährt Administratoren die Berechtigung „$permission“.';
  }

  @override
  String featureDetailHeldBack(String feature) {
    return 'Eingeschaltet, aber blockiert: sie benötigt $feature, das ausgeschaltet ist.';
  }

  @override
  String get featureDetailKey => 'Technischer Schlüssel';

  @override
  String get featureDetailNone => 'Nichts.';

  @override
  String get featureDetailOff => 'Ausgeschaltet.';

  @override
  String get featureDetailOn => 'Eingeschaltet.';

  @override
  String featureDetailOnNeededBy(String names) {
    return 'Eingeschaltet und benötigt von $names.';
  }

  @override
  String get featureDetailProvides => 'Bietet';

  @override
  String get featureDetailRequires => 'Benötigt';

  @override
  String get featureDetailTechnical => 'Technische Details';

  @override
  String get featureDetailUsedBy => 'Verwendet von';

  @override
  String get featureDocuments => 'Dokumentbibliothek';

  @override
  String get featureDocumentsDesc =>
      'Die Dokumentbibliothek des Arbeitsbereichs: Satzung, Anleitungen, Finanzberichte, Protokolle — aus jedem Drive verlinkt, sichtbar je nach Rolle.';

  @override
  String get featureDunning => 'Mahnwesen';

  @override
  String get featureDunningDesc =>
      'Konfigurierbare Mahnstufen und Fristen, ein Mahnschreiben pro Stufe und „Mahnung fällig“-Hinweise auf verspäteten Rechnungen. Das Senden bleibt ein manueller Tipp, außer mit den Automatischen Zahlungserinnerungen.';

  @override
  String get featureEinvoiceCustomerDeliveryDesc =>
      'Ein zweiter Sendekanal neben der staatlichen Plattform: die ausgestellte Rechnung direkt an den E-Rechnungsdienst des Kunden übermitteln.';

  @override
  String get featureEinvoiceCustomerDeliveryTitle =>
      'E-Rechnungszustellung an Kunden';

  @override
  String get featureEnvironmentPairs => 'Umgebungspaare';

  @override
  String get featureEnvironmentPairsDesc =>
      'Ein Raum und sein Zwilling — die Entwicklungs- und die Produktionsseite — als ein Paar: eine Karte in Profile mit Umschalter, und der Zwilling auf Wunsch mit kopierter Konfiguration. Aus: zwei Einträge ohne Bezug.';

  @override
  String get featureEventsTab => 'Ereignis-Tab';

  @override
  String get featureEventsTabDesc =>
      'Aktivitätsverlauf und ausstehende Bestätigungen.';

  @override
  String get featureExpenseRepartitionDesc =>
      'Eine gemeinsame Ausgabe (Reinigung, schnelleres Internet, ein kaputter Stuhl) auf die Mitglieder verteilt — gleiche Anteile, anteilig zum Abonnement, anteilig zur Nutzung oder ein Schlüssel je Mitglied — jeder Anteil vor der Buchung in der Vorschau. Die Anteile werden Positionen der nächsten Nutzungsrechnung; eine Umkehrung bucht Gutschriften. Läuft über die Bestätigungsregeln. Aus: keine Verteilung.';

  @override
  String get featureExpenseRepartitionTitle => 'Gemeinsame Ausgaben';

  @override
  String get featureExpenseRepartitionWizard => 'Umlage-Assistent';

  @override
  String get featureExpenseRepartitionWizardDesc =>
      'Eine geführte Umlage: gemeinsame Kosten anteilig zum Abonnement vorgeschlagen, jeder Anteil anpassbar, die angepasste Regel für den nächsten Monat gemerkt. Aus: nur das Umlage-Formular für eine Ausgabe.';

  @override
  String get featureFinanceFacesDesc =>
      'Der Finanzen-Tab hat vier Ansichten — Abrechnung, Zahlungen, Rechnungen, Dokumente — unter einem Monatswähler, jede mit eigener Hilfe. Aus: eine einzige Spalte.';

  @override
  String get featureFinanceFacesTitle => 'Finanzen in vier Ansichten';

  @override
  String get featureFormHelpHintsDesc =>
      'Ein ausblendbares Tipp-Karussell auf jedem Hauptbildschirm und ein kleines ? neben jedem Parameter und Eingabefeld — ein Tipp öffnet das Handbuch am richtigen Abschnitt. In den Einstellungen wiederherstellbar.';

  @override
  String get featureFormHelpHintsTitle => 'Hilfe-Hinweise';

  @override
  String get featureGuestParticipationDesc =>
      'Erlaubt einer Person, die kein Mitglied ist, um einen Besuch dieses Spaces zu bitten, und jemandem, der Reservierungen verwaltet, sie zuzulassen oder abzulehnen. Ein Besuch erzeugt weder Mitgliedschaft noch Abonnement noch Rolle. Aus: niemand fragt an oder wird hier zugelassen.';

  @override
  String get featureGuestParticipationTitle => 'Gastbesuche';

  @override
  String get featureHeldBack =>
      'Wartet auf die Funktion darüber — schalten Sie sie ein, dann wirkt auch diese wieder.';

  @override
  String get featureHolidayImportDesc =>
      'Ein Eigentümer importiert die Feiertage des Landes und einer Region aus einer Open-Data-Quelle, wählt die Tage ab, an denen der Raum geöffnet bleibt, und importiert die übrigen als Schließtage. Bereits abgerechnete Monate werden übersprungen und genannt.';

  @override
  String get featureHolidayImportTitle => 'Feiertage importieren';

  @override
  String get featureInstanceWizard => 'Instanz-Assistent';

  @override
  String get featureInstanceWizardDesc =>
      'Auf dem Server-Bildschirm ein Assistent, der ein neues Supabase-Projekt anlegt, das Schema der App installiert, ihre Funktionen bereitstellt und dieses Gerät darauf zeigen lässt — ein Zugriffstoken, kein Terminal. Aus: nur die manuellen Schritte.';

  @override
  String get featureIntakeStoppedNote =>
      'Aus: nichts Neues beginnt; was schon offen ist, kann noch beantwortet und geschlossen werden.';

  @override
  String get featureIntakeUnconfirmedNote =>
      'Aus: nichts Neues beginnt. Dieser Server konnte nicht bestätigen, dass Offenes weiter bearbeitet werden kann; verlassen Sie sich nicht darauf.';

  @override
  String get featureInvoiceAddressWindow => 'Adressfenster';

  @override
  String get featureInvoiceAddressWindowDesc =>
      'Platziert den Empfänger dort, wo ihn ein Fensterumschlag zeigt, damit eine gedruckte Rechnung gefaltet und versandt werden kann. Die Seite folgt dem Land und ist überschreibbar.';

  @override
  String get featureInvoiceJourneyDesc =>
      'Jede Rechnung zeigt, wo sie steht — Ausgestellt, Zahlung, Bestätigung, Abgeschlossen — und wer am Zug ist: das Mitglied zahlt, ein Admin bestätigt die gemeldete Zahlung, der Aussteller ordnet sie zu, die Prüfer entscheiden. Das Hub der Aussteller erhält eine Stufenleiste mit Zählern und eine Erklärung „So funktioniert es“.';

  @override
  String get featureInvoiceJourneyTitle => 'Der Weg einer Rechnung';

  @override
  String get featureInvoicePdfTemplate => 'Rechnungs-PDF-Vorlage';

  @override
  String get featureInvoicePdfTemplateDesc =>
      'Vom Inhaber verfasste Einleitung und Fußtext auf dem Rechnungs-PDF. Das E-Rechnungs-XML bleibt unberührt.';

  @override
  String get featureInvoiceSettlementDesc =>
      'Mehrere offene Rechnungen eines Mitglieds lassen sich zu einer zusammenfassen, die es bezahlt. Die Originale bleiben im Archiv, Position für Position nachvollziehbar, und werden nicht mehr einzeln angemahnt.';

  @override
  String get featureInvoiceSettlementTitle => 'Rechnungen zusammenfassen';

  @override
  String get featureInvoicing => 'Rechnungen';

  @override
  String get featureInvoicingDesc =>
      'Unveränderliche, signierte Rechnungen im Archiv — als PDF herunterladen oder teilen.';

  @override
  String get featureInvoicingWizardDesc =>
      'Ein geführter Monatsabschluss für die Finanzperson: ein Monatsanfangslauf für die im Voraus bezahlten Abonnements und ein Monatsendlauf für Nutzung und Zusatzkosten — Prüfung, Ausstellung im Stapel, Versand, fällige Mahnungen, Erfassen und Bestätigen von Zahlungen, Zuordnen zu Rechnungen, Zusammenfassen, Abschreiben oder Erstatten, und eine Zusammenfassung mit dem, was offen bleibt und wer am Zug ist. Aus: die einzelnen Bildschirme.';

  @override
  String get featureInvoicingWizardTitle => 'Rechnungsassistent';

  @override
  String get featureKioskMemberPhotosDesc =>
      'Der Kiosk-Beleg zeigt das Profilfoto des Mitglieds — die visuelle Falsch-Badge-Kontrolle.';

  @override
  String get featureKioskMemberPhotosTitle => 'Mitgliederfotos am Kiosk';

  @override
  String get featureKioskMode => 'Kiosk-Modus';

  @override
  String get featureKioskModeDesc =>
      'Wandtablet-Konten, verriegelt auf den Live-Plan; Mitglieder handeln per Badge.';

  @override
  String get featureLess => 'Weniger';

  @override
  String get featureLetterStandard => 'Briefstandard für jedes Dokument';

  @override
  String get featureLetterStandardDesc =>
      'Rechnungen, Proformas, Abrechnungen, Vereinbarungen, Zahlungs- und Verbrauchsberichte und Mahnungen ohne Vorlage drucken als Normbrief: Briefkopf, Empfänger im Fensterfeld, Text ab 90 mm, fester Fuß.';

  @override
  String get featureLevelBooking => 'Tisch-, Büro- & Etagen-Reservierungen';

  @override
  String get featureLevelBookingDesc =>
      'Einen ganzen Tisch, ein Büro oder eine Etage als eine Buchung reservieren, je Halbtag bepreist. Das Recht wird pro Mitglied vergeben.';

  @override
  String get featureLifecycleActive => 'Aktiv';

  @override
  String get featureLifecycleDeprecated => 'Veraltet';

  @override
  String get featureLifecycleRetired => 'Eingestellt';

  @override
  String get featureManagedProfileAccess => 'Wer ein Profil verwaltet';

  @override
  String get featureManagedProfileAccessDesc =>
      'Jedes verwaltete Profil nennt, wer es verwalten darf — nach Rolle, nach benannten Personen oder beides. Aus: jeder Inhaber und jeder Admin darf, wie bisher. Die Identität selbst ist in beiden Fällen geschützt, und jeder Zugriff wird für die Person festgehalten, die das Profil übernimmt.';

  @override
  String get featureManagedProfiles => 'Verwaltete Profile';

  @override
  String get featureManagedProfilesDesc =>
      'Admins legen Mitglieder ohne Konto an, buchen und fakturieren für sie und übergeben das Profil mit einem persönlichen Code, den die Person beim Beitritt einlöst.';

  @override
  String get featureMaturityAlpha => 'Alpha';

  @override
  String get featureMaturityBeta => 'Beta';

  @override
  String get featureMaturityFilterAll => 'Alle Stufen';

  @override
  String get featureMaturityFilterLabel => 'Reife';

  @override
  String featureMaturitySemantics(String maturity, String lifecycle) {
    return 'Reife $maturity, $lifecycle';
  }

  @override
  String get featureMaturityStable => 'Stabil';

  @override
  String get featureMaturityUnreviewed => 'Nicht bewertet';

  @override
  String get featureMcpAccessDesc =>
      'Stellt die MCP-Schnittstelle für diesen Arbeitsbereich bereit, damit ein KI-Assistent mit DesKilo verbunden werden kann. Nur Verfügbarkeit: das Einschalten gewährt niemandem etwas. Jede Person braucht weiterhin eine Freigabe, die der Eigentümer konfiguriert und der Instanzadministrator genehmigt, und jeder Vorgang unterliegt weiterhin den Berechtigungen und Regeln, die die App ohnehin anwendet. Ausgeschaltet verbirgt sie die MCP-Einstiegspunkte und weist Aufrufe ab; bestehende Freigaben bleiben sichtbar und widerrufbar.';

  @override
  String get featureMcpAccessTitle => 'MCP-Schnittstelle';

  @override
  String get featureMemberAccountMenuDesc =>
      'Ein Mitglied, das nichts verwaltet, findet Mein Konto statt Einstellungen — denselben Bildschirm, der ihm ohnehin nur sein Konto, seine Mitgliedschaft und seine Einstellungen zeigt, unter dem Namen, der das sagt. Wer durch seine Rolle etwas verwalten darf, behält Einstellungen und alles, was sich darin öffnet. Dies benennt einen Eintrag um; es gewährt und entzieht nichts.';

  @override
  String get featureMemberAccountMenuTitle => 'Mitglieder sehen Mein Konto';

  @override
  String get featureMemberDataExportDesc =>
      'Jedes Mitglied kann seine Daten als eine Datei exportieren (DSGVO Art. 20) und den Bereich mit gelöschten persönlichen Daten verlassen (Art. 17), unter Einstellungen → Datenschutz & Daten.';

  @override
  String get featureMemberDataExportTitle => 'Export & Löschung';

  @override
  String get featureMemberEnvironmentsDesc =>
      'Wenn Sie jemanden einladen, wählen Sie, ob er auch den Produktionsraum erreicht. Dem Testraum tritt er in jedem Fall bei, und die Rolle muss den Produktionszugang trotzdem erlauben.';

  @override
  String get featureMemberEnvironmentsTitle =>
      'Die Umgebungen wählen, für die eine Person freigeschaltet wird';

  @override
  String get featureMemberGettingStartedDesc =>
      'Nach dem Beitritt oder dem Anlegen eines Workspace sieht ein Mitglied eine kompakte Karte im Reservieren-Hub: in welchem Workspace es ist und einen vorgeschlagenen nächsten Schritt — eine Zeit zum Buchen wählen, die eigene Mitgliedschaft ansehen oder die Hilfe öffnen — nur dort, wo Funktionen und Berechtigungen es erlauben. „Jetzt nicht“ blendet sie aus; die Einstellungen zeigen sie wieder an. Sie bucht, zahlt und genehmigt nie etwas. Wer den Workspace einrichtet, sieht in den Einstellungen außerdem Bereich für Bereich, was bis zu einer ersten Buchung fehlt. Aus blendet die Karte und diese Liste aus und ändert sonst nichts.';

  @override
  String get featureMemberGettingStartedTitle => 'Karte „Erste Schritte“';

  @override
  String get featureMemberNotifications => 'Mitglieder-Benachrichtigungen';

  @override
  String get featureMemberNotificationsDesc =>
      'Nachrichten zwischen Mitgliedern: private und Gruppenunterhaltungen, Lesebestätigungen, Links zu einer Reservierung oder einem Raum; Admins können alle Admins benachrichtigen, Inhaber eingeschlossen.';

  @override
  String get featureMemberOriginDesc =>
      'Eine dezente Zeile an einem Mitglied, die sagt, wie die Mitgliedschaft begann: hat den Raum gegründet, per Einladung beigetreten, oder das Profil wurde von einem Admin angelegt. Es ist kein Status.';

  @override
  String get featureMemberOriginTitle => 'Wie jedes Mitglied hierherkam';

  @override
  String get featureMemberPageDesc =>
      'Eine Seite pro Mitglied: Foto und Präsenz, zuletzt gesehen, aktuelle und kommende Buchungen, Schnellaktionen (Nachricht, WhatsApp, E-Mail), Kontakt- und Finanzkarten und für Admins jede Einstellung nach Thema gruppiert mit ihrem aktuellen Wert. Aus: das Profilblatt und das Aktionsblatt von Mitglieder & Tarife.';

  @override
  String get featureMemberPageTitle => 'Mitgliedsseite';

  @override
  String get featureMemberPaymentTerms => 'Zahlungsbedingungen je Mitglied';

  @override
  String get featureMemberPaymentTermsDesc =>
      'Der Space legt die Standard-Zahlungsbedingungen fest; ein Mitglied kann eigene haben, für es sichtbar, geändert nur über einen bestätigten Antrag eines berechtigten Admins.';

  @override
  String get featureMemberReports => 'Mitgliederberichte';

  @override
  String get featureMemberReportsDesc =>
      'Die Finanzvereinbarung und der monatliche Zahlungsbericht — Self-Service für Mitglieder, pro Mitglied versendbar.';

  @override
  String get featureMembersDirectory => 'Mitgliederverzeichnis';

  @override
  String get featureMembersDirectoryDesc =>
      'Der Community-Tab: wer da ist, Status, Präsenz.';

  @override
  String get featureMessageForwardingDesc =>
      'Eine Nachricht kann in ein anderes Gespräch weitergeleitet werden, an dem die weiterleitende Person teilnimmt. Die Kopie nennt Herkunft und Verfasser, das ursprüngliche Gespräch erfährt, wer sie wohin weitergeleitet hat, und Verfasser können eine Nachricht gegen Weiterleitung sperren. Aus verhindert Weiterleitungen aus diesem Bereich.';

  @override
  String get featureMessageForwardingTitle => 'Nachrichten weiterleiten';

  @override
  String get featureMessageGesturesDesc =>
      'Wischen Sie eine Nachricht nach rechts, um sie in Ihrer Antwort zu zitieren; nach links, um Ihre eigene Nachricht zurückzunehmen, solange sie niemand gelesen hat — nach einer Bestätigung. Aus: Nachrichten werden durch langes Drücken gelöscht.';

  @override
  String get featureMessageGesturesTitle =>
      'Wischen zum Zitieren oder Zurücknehmen';

  @override
  String get featureMessageMentionsDesc =>
      'In einer Gruppe kann eine Person mit Namen erwähnt werden. Erwähnt werden können nur Personen aus der Unterhaltung, und die erwähnte Person wird benachrichtigt, auch wenn sie die Unterhaltung stummgeschaltet hat. Aus bleibt ein Name nach @ einfacher Text und benachrichtigt niemanden.';

  @override
  String get featureMessageMentionsTitle => 'Erwähnungen in Gruppen';

  @override
  String get featureMessagesHubDesc =>
      'Eine Posteingangsleiste (Alle / Ungelesen / Archiviert und Suche), anheften, stumm, archivieren und als ungelesen markieren auf einem Thread, die Unterhaltung als ganze Seite mit Datumstrennern, ein Anhängen-Menü und ein behaltener Entwurf im Editor, eine Person mit einem Tipp geöffnet. Aus: der Posteingang mit zwei Leisten und der Thread als Blatt.';

  @override
  String get featureMessagesHubTitle => 'Nachrichten, überarbeitet';

  @override
  String get featureMoneyTab => 'Finanzen-Tab';

  @override
  String get featureMoneyTabDesc => 'Monatsrechnungen, Zahlungen und Ausgaben.';

  @override
  String get featureMore => 'Mehr';

  @override
  String get featureMultiSite => 'Standorte';

  @override
  String get featureMultiSiteDesc =>
      'Mehrere Adressen: Ebenen werden nach Standort gruppiert, jeder Standort hat eigene Adresse und Registrierung, jedes Mitglied einen Heimatstandort, und Belege nennen den betroffenen Standort. Aus: eine Adresse für den ganzen Arbeitsbereich.';

  @override
  String get featureNavigationStyle => 'Navigationswahl';

  @override
  String get featureNavigationStyleDesc =>
      'Jedes Mitglied wählt in seinen Einstellungen, wie die App navigiert: die klassische untere Leiste mit dem runden Reservieren-Knopf oder das Menü wie im Web. Aus: jedes Gerät behält den Standard seiner Plattform.';

  @override
  String get featureNfcBadges => 'RFID-/NFC-Badges';

  @override
  String get featureNfcBadgesDesc =>
      'Mitglieder checken an einem Kiosk per RFID/NFC-Karte ein. Erfordert ein Android-Gerät mit NFC.';

  @override
  String get featureNfcSeatTagsDesc =>
      'Ein physischer NFC/RFID-Tag an einem Stuhl führt zu seinem Platz wie die gedruckte QR-Karte; das Feld füllt sich durch Antippen des Chips.';

  @override
  String get featureNfcSeatTagsTitle => 'NFC/RFID-Tags an Stühlen';

  @override
  String get featureNotificationGroupingDesc =>
      'Mitglieder können den Benachrichtigungs-Feed nach Typ, Tag oder Mitglied gruppieren; ein Tipp auf das Gruppensymbol führt zurück zur flachen Liste.';

  @override
  String get featureNotificationGroupingTitle =>
      'Gruppierung der Benachrichtigungen';

  @override
  String get featureNumberSequences => 'Nummernkreise';

  @override
  String get featureNumberSequencesDesc =>
      'Wie jedes Journal seine Belege nummeriert — Präfix, Jahr oder Monat, Stellen, Neustart des Zählers — ein Bildschirm für alle Kreise. Die Nummern werden in der Datenbank vergeben, lückenlos, ob ein- oder ausgeschaltet; eingeschaltet ändert der Inhaber das Format für alles Kommende.';

  @override
  String get featureOnlinePayments => 'Online-Zahlungen';

  @override
  String get featureOnlinePaymentsDesc =>
      'Mitglieder zahlen ihre Rechnung online (PayPal). Erfordert die Einrichtung des Zahlungsanbieters auf dem Server.';

  @override
  String featureOptInAlsoOn(int count, String features) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Werden ebenfalls eingeschaltet, weil benötigt ($count): $features',
      one: 'Wird ebenfalls eingeschaltet, weil benötigt: $features',
    );
    return '$_temp0';
  }

  @override
  String featureOptInBody(String features) {
    return 'Noch nicht als stabil bewertet: $features. Sie kann sich ändern und hat bekannte Grenzen. Nur einschalten, wenn dieser Space das akzeptiert.';
  }

  @override
  String get featureOptInConfirm => 'Einschalten';

  @override
  String featureOptInStage(String feature, String stage) {
    return '$feature: $stage';
  }

  @override
  String get featureOptInTitle => 'Experimentelle Funktion einschalten?';

  @override
  String get featurePaymentRemindersDesc =>
      'Offene Rechnungen nach Ablauf der eingestellten Frist erhalten ihre Mahnstufen automatisch — ein Hinweis im Feed des Mitglieds und eine Push-Nachricht, einmal täglich. Aus: Mahnen bleibt ein manueller Schritt.';

  @override
  String get featurePaymentRemindersTitle =>
      'Automatische Zahlungserinnerungen';

  @override
  String get featurePdfExport => 'PDF-Export';

  @override
  String get featurePdfExportDesc => 'Die Monatsrechnung als PDF exportieren.';

  @override
  String get featurePersonalInfo => 'Persönliche Angaben';

  @override
  String get featurePersonalInfoDesc =>
      'Mitglieder tragen Name, Postanschrift, Telefon, E-Mail und Kennungen in den Einstellungen ein; Rechnungen und Briefe drucken sie im genormten Anschriftenblock.';

  @override
  String get featurePlaceFeedbackDesc =>
      'Mitglieder markieren Plätze, Tische, Büros und Etagen als Favoriten und bewerten sie mit 0 bis 5 Sternen. Ein Favorit gehört dem Mitglied; eine Bewertung zeigt den Durchschnitt und die Anzahl, nie wer. Ein Assistent kann die Favoriten auflisten, einen buchen und eine Bewertung eintragen. Aus blendet Herzen und Sterne aus und weist das Schreiben ab; sonst hängt nichts daran.';

  @override
  String get featurePlaceFeedbackTitle => 'Favoriten und Bewertungen';

  @override
  String get featurePlanMemberPhotosDesc =>
      'Belegte Plätze im Plan-Tab und im Reservieren-Hub zeigen das Profilfoto statt der Initiale.';

  @override
  String get featurePlanMemberPhotosTitle => 'Mitgliederfotos auf dem Plan';

  @override
  String get featurePlanObjectDeleteDesc =>
      'Inhaber können Ebenen, Büros, Tische und Sitzplätze auch dann löschen, wenn frühere Reservierungen darauf verweisen — die Buchungen behalten einen Text-Schnappschuss für Audits und Berichte.';

  @override
  String get featurePlanObjectDeleteTitle => 'Räume mit Historie löschen';

  @override
  String get featurePriceNegotiationsDesc =>
      'Der Tarif ist der Standard; ein Mitglied kann eigene Konditionen haben — Monatsgebühr, Überschreitungssatz, Rabatt auf Zuschläge, Stückpreise je Leistung und Paket, Belegungsprozentsatz —, vorgeschlagen von wer „Geschäftsvereinbarungen verwalten“ hält, und nach den Regeln validiert. Sichtbar für das Mitglied, die Inhaber und die Träger von „Geschäftsvereinbarungen einsehen“; jeder Zugriff wird protokolliert.';

  @override
  String get featurePriceNegotiationsTitle => 'Preisverhandlungen';

  @override
  String get featurePublicHolidaysDesc =>
      'Der Inhaber wählt ein Jahr, sieht die Feiertage, die zu Schließtagen würden, und bestätigt. Ein erneuter Lauf fügt nichts hinzu, und ein Monat mit bereits erstellter Rechnung wird übersprungen und benannt — erzeugte Feiertage ändern nie eine bereits gestellte Rechnung.';

  @override
  String get featurePublicHolidaysTitle => 'Feiertage';

  @override
  String get featurePublicListings => 'Öffentlicher Workspace-Eintrag';

  @override
  String get featurePublicListingsDesc =>
      'Veröffentlichen Sie ausgewählte Informationen und Pläne mit sichtbaren Eigentümern und freiwilligen Administratorkontakten.';

  @override
  String get featurePushNotifications => 'Push-Benachrichtigungen';

  @override
  String get featurePushNotificationsDesc =>
      'Ausstehende Bestätigungen auf die Geräte der Mitglieder zustellen.';

  @override
  String get featureQrBadgesDesc =>
      'Druckbare QR-Badge-Karten für den Kiosk, neben den NFC/RFID-Karten.';

  @override
  String get featureQrBadgesTitle => 'QR-Badges';

  @override
  String get featureRecordingPrivacyDesc =>
      'Zum Filmen oder Fotografieren dieses Arbeitsraums. Jeder Name, jede E-Mail-Adresse, Telefonnummer, Anschrift und jedes Foto wird durch eine erfundene Person ersetzt, bevor es auf den Bildschirm gelangt; der Plan, die Buchungen und die Beträge bleiben die echten. Ein Banner weist auf jedem Bildschirm darauf hin, und die Identitätsformulare verweigern das Speichern, solange er aktiv ist.';

  @override
  String get featureRecordingPrivacyTitle => 'Aufnahmemodus';

  @override
  String get featureRegionalFormatsDesc =>
      'Mitglieder wählen, wie Zahlen, Daten, Uhr und Zeitzone ihnen angezeigt werden. Aus: alle lesen in der Heimatregion der App-Sprache, 24-Stunden, Bereichszeit.';

  @override
  String get featureRegionalFormatsTitle => 'Region & Formate';

  @override
  String get featureReportDesignExchangeDesc =>
      'Jede Berichtsvorlage lässt sich als eine selbsterklärende Datei ausgeben und wieder einlesen. Die Datei enthält die Vorlage sowie die Bedeutung ihrer Felder, das erlaubte Markup und die vorhandenen Platzhalter — so kann sie außerhalb der App bearbeitet und zurückgegeben werden. Eine Datei für einen anderen Bericht oder aus einer neueren Version wird mit Begründung abgelehnt. Aus: Vorlagen sind nur im Designer änderbar.';

  @override
  String get featureReportDesignExchangeTitle =>
      'Berichtsvorlagen exportieren und importieren';

  @override
  String get featureReportDesignerDesc =>
      'Der Berichtseditor als Vollbild-Designer: Elemente an Ort und Stelle in ihrer echten Typografie bearbeitet, Ziehen zum Umsortieren, eine Einfügepalette, eine durchsuchbare Feldauswahl, Rückgängig und Wiederholen, Bildgröße und -ausrichtung, ein Schutz vor dem Verwerfen, Vorlagen und Zurücksetzen hinter einer Bestätigung, der Vorlagenfehler im Klartext, Entwurf und Vorschau nebeneinander auf breitem Bildschirm. Aus: der Editor als Blatt.';

  @override
  String get featureReportDesignerTitle => 'Berichtsdesigner';

  @override
  String get featureReportLayouts => 'Positionierte Berichtslayouts';

  @override
  String get featureReportLayoutsDesc =>
      'Ein Bericht wird entworfen, indem jedes Element seine Position in mm, cm, px oder % nennt; das PDF druckt genau das. Ein Dokument mit Layout nutzt es, die übrigen behalten ihre Bänder.';

  @override
  String get featureReportTexts => 'Berichtstexte';

  @override
  String get featureReportTextsDesc =>
      'Der Eigentümer schreibt Texte (Gruß, Hinweis, Rechtsabsatz) je Sprache und setzt sie in jeden Bericht als text.schluessel — der Wortlaut ändert sich, ohne das Design anzufassen.';

  @override
  String featureRequires(String feature) {
    return 'Benötigt $feature';
  }

  @override
  String get featureRichMessageRefsDesc =>
      'Eine Nachricht kann auf einen Hinweis zeigen, auf den Freigabeverlauf dahinter und auf eine Rechnung, eine Zahlung oder eine Erstattung — jeder Verweis ist ein Link, der öffnet, was er nennt. Jede Auswahl filtert beim Tippen. Aus: nur Buchungen und Plätze sind verweisbar.';

  @override
  String get featureRichMessageRefsTitle => 'Verweise in Nachrichten';

  @override
  String get featureRoleAssignmentDesc =>
      'Zeigt auf der Seite jedes Mitglieds einen Bereich Rollen, um eine Rolle zu geben oder zu entziehen, die Mitglieder jeder Rolle, und lässt jedes Mitglied sehen, was es hier tun kann.';

  @override
  String get featureRoleAssignmentTitle => 'Rollen vergeben';

  @override
  String get featureRoleManagement => 'Rollenverwaltung';

  @override
  String get featureRoleManagementDesc =>
      'Die zentrale Rolle→Berechtigung-Matrix: Der Inhaber entscheidet, welche Rolle welche Berechtigung hält; alle anderen lesen ihre eigenen. Aus: Es gelten einfach die Standardwerte.';

  @override
  String get featureScheduledExpensesDesc =>
      'Wiederkehrende Ausgaben (Internet, Telefon, Strom): jedes Mitglied plant sie mit ihrer Regel (alle X Tage/Wochen/Monate/Jahre, X Mal oder bis zu einem Datum); der Plan wird einmal validiert, und jede Fälligkeit wird dem Mitglied vorgelegt — der validierte Betrag zählt sofort, ein abweichender erklärt sich und durchläuft die Ausgaben-Validierung.';

  @override
  String get featureScheduledExpensesTitle => 'Geplante Ausgaben';

  @override
  String get featureSeatDayTimeline => 'Tagesverlauf eines Platzes';

  @override
  String get featureSeatDayTimelineDesc =>
      'Ein Platz, der nur einen Teil des Tages gebucht ist, wird auf dem Plan teilweise gefüllt gezeichnet; ein von mehreren geteilter Platz öffnet den Tagesverlauf: wer ihn hat, wann, und welche Spannen frei sind.';

  @override
  String get featureSeriesBooking => 'Serienbuchung';

  @override
  String get featureSeriesBookingDesc =>
      'Eine Reservierung täglich, wöchentlich oder an Werktagen wiederholen.';

  @override
  String get featureServices => 'Leistungen';

  @override
  String get featureServicesDesc => 'Leistungskatalog und Verbrauchserfassung.';

  @override
  String get featureSettlementFoldDesc =>
      'Zu einer zusammengefasste Rechnungen verschwinden als eigene Zeilen aus den Listen und ordnen sich unter der Sammelrechnung ein, die alle ihre Positionen trägt. Auf einer zusammengefassten Rechnung ist jede Aktion aus; es bleibt nur ihr PDF, gestempelt mit der Nummer, in der sie aufging. Aus: die zusammengefassten Rechnungen bleiben neben der Sammelrechnung gelistet.';

  @override
  String get featureSettlementFoldTitle =>
      'Zusammengefasste Rechnungen eingeklappt';

  @override
  String get featureSingleRoomLevelNamesDesc =>
      'Hat eine Etage nur einen Raum, nennen die Buchungsansichten die Etage statt des Raums — „2. Etage · Tisch 3“ statt „Büro 1 · Tisch 3“. Ein zweiter Raum bringt beide Namen zurück; der Planeditor zeigt immer die Räume.';

  @override
  String get featureSingleRoomLevelNamesTitle =>
      'Einraum-Etagen nach der Etage benennen';

  @override
  String get featureSiteDocuments => 'Standorte auf Belegen';

  @override
  String get featureSiteDocumentsDesc =>
      'Belege nennen den betroffenen Standort: Adresse und Registrierung des Heimatstandorts des Mitglieds als Verkäufer, und die anderen im Monat genutzten Standorte im Detail. Aus: die Adresse des Arbeitsbereichs auf jedem Beleg.';

  @override
  String get featureSpaceInquiriesDesc =>
      'Eine angemeldete Person, die die veröffentlichte Seite findet, kann den Gastgebern schreiben: den Eigentümern und den Administratoren, die öffentliche Kontakte sein wollen. Die Gastgeber werden vor dem Schreiben genannt, und nur diese Person und die Gastgeber lesen das Gespräch. Aus entfernt die Schaltfläche und die Ansicht Anfragen, sodass niemand eine neue Anfrage beginnt; offene bleiben im Posteingang der Gastgeber, um sie zu beantworten und zu schließen.';

  @override
  String get featureSpaceInquiriesTitle => 'Den Gastgebern schreiben';

  @override
  String get featureSpaceQrCodes => 'Raum-QR-Codes';

  @override
  String get featureSpaceQrCodesDesc =>
      'Druckbare QR-Karten je Platz, Tisch, Büro und Etage — scannen zum Reservieren oder Einchecken.';

  @override
  String get featureSubscriptionInvoicesDesc =>
      'Der Mitgliedsbeitrag wird vor dem Monat berechnet, den er bezahlt, an einem Datum Ihrer Wahl. Aus: Der Beitrag bleibt auf der Monatsrechnung.';

  @override
  String get featureSubscriptionInvoicesTitle => 'Abo-Rechnungen';

  @override
  String get featureSupplyExpensesDesc =>
      'Eine Ausgabe kann ein Vorrat für den Raum sein (Kaffeekapseln, Staubsaugerbeutel…): genehmigt, füllt sie eine verbrauchbare Leistung mit Stückpreis auf oder legt sie an; Verbräuche zählen den Bestand herunter.';

  @override
  String get featureSupplyExpensesTitle => 'Vorräte aus Ausgaben';

  @override
  String get featureSurfaceCalendarHint =>
      'Was ansteht, nach Tag und nach Monat.';

  @override
  String get featureSurfaceDocumentsHint =>
      'Die Dateien, die der Raum aufbewahrt und teilt.';

  @override
  String get featureSurfaceEverywhere => 'Die ganze App';

  @override
  String get featureSurfaceEverywhereHint =>
      'Ändert das Verhalten der App, überall.';

  @override
  String get featureSurfaceKioskHint =>
      'Das Tablet an der Tür, Ausweise und Scans.';

  @override
  String get featureSurfaceMembersHint =>
      'Wer im Raum ist, ihre Profile und ihre Rollen.';

  @override
  String get featureSurfaceMessagesHint =>
      'Gespräche, Hinweise und was auf dem Telefon ankommt.';

  @override
  String get featureSurfaceMoneyHint =>
      'Abrechnungen, Zahlungen, Rechnungen und woraus sie bestehen.';

  @override
  String get featureSurfaceReports => 'Dokumente zum Drucken';

  @override
  String get featureSurfaceReportsHint =>
      'Rechnungen, Abrechnungen und Briefe — und wie sie auf Papier aussehen.';

  @override
  String get featureSurfaceReserveHint =>
      'Platz buchen, der Grundriss, das Einchecken.';

  @override
  String get featureSurfaceSettingsHint =>
      'Wie der Raum selbst eingerichtet ist.';

  @override
  String get featureTaskRecorderDesc =>
      'Erlaubt, die Schritte einer Aufgabe auf den Bildschirmen dieses Arbeitsbereichs auf dem eigenen Gerät aufzuzeichnen, sie zu prüfen und eine Datei ohne eingegebene Werte zu exportieren. Nichts wird hochgeladen. Aus: Hier zeichnet niemand auf.';

  @override
  String get featureTaskRecorderTitle => 'Aufgabenrekorder';

  @override
  String get featureTierCore => 'Kern';

  @override
  String get featureTierCoreDesc =>
      'Was jeder Raum braucht. Ab dem ersten Tag an.';

  @override
  String get featureTierPlatform => 'Plattform';

  @override
  String get featureTierPlatformDesc =>
      'Angefragt, nie vorausgesetzt. Schalten Sie ein, was dieser Raum wirklich betreibt.';

  @override
  String get featureUiAnimationsDesc =>
      'Sanfte Übergänge und Zustandsanimationen in der ganzen App. Aus bedeutet: Jede Änderung erfolgt sofort; die Bewegung-reduzieren-Einstellung des Geräts hat immer Vorrang.';

  @override
  String get featureUiAnimationsTitle => 'Oberflächen-Animationen';

  @override
  String get featureUniqueMonogramsDesc =>
      'Ein Avatar ohne Foto zeigt Initialen, die zu genau einem Mitglied gehören: Anfangsbuchstabe von Vor- und Nachname, bei einer Kollision ein weiterer Buchstabe, Zahlen erst als letzter Ausweg. Aus: nur der erste Buchstabe, gleich für alle, die ihn teilen.';

  @override
  String get featureUniqueMonogramsTitle => 'Eindeutige Avatar-Initialen';

  @override
  String get featureUsageInvoicesDesc =>
      'Ist ein Monat vorbei, wird getrennt berechnet, was er über das Abo hinaus gekostet hat — Mehrverbrauch, Zubehör, Leistungen. Aus: Das bleibt auf der Monatsrechnung.';

  @override
  String get featureUsageInvoicesTitle => 'Monatsabschluss-Rechnungen';

  @override
  String get featureUsageRecordsDesc =>
      'Jede gezählte Buchung hinterlässt einen Satz: das gebuchte Fenster, die tatsächliche Anwesenheit und was davon berechnet wird. Eine Buchung, zu der niemand kam, wird voll berechnet. Wer früher geht, kann darum bitten, die ungenutzte Zeit nicht zu berechnen — entschieden wird das von jemand anderem. Aus: keine Sätze, keine Korrektur.';

  @override
  String get featureUsageRecordsTitle => 'Nutzungssätze';

  @override
  String get featureUsageReport => 'Verbrauchsbericht';

  @override
  String get featureUsageReportDesc =>
      'Zum Monatsende erhält ein Mitglied, was seine Teilnahme bezahlt hat, was es tatsächlich verbraucht hat und was übrig ist oder überschritten wurde — aus den Nutzungseinträgen, als Brief.';

  @override
  String get featureValidationChainDesc =>
      'Eine Freigaberegel kann ihre Freigaben nacheinander einholen — jede Stufe erst, wenn die vorige durch ist — und kann der Inhaberin oder dem Inhaber, nie einem Admin, die Freigabe der eigenen Handlung erlauben. Aus: alles wird auf einmal angefragt, und niemand gibt das Eigene frei.';

  @override
  String get featureValidationChainTitle => 'Verkettete Freigaben';

  @override
  String get featureValidationScopesDesc =>
      'Jede Prüfregel nennt, wer prüft: die Admins, benannte Personen jeder Rolle oder alle Mitglieder — und wie viele. Aus: Inhaber und Admins wie bisher.';

  @override
  String get featureValidationScopesTitle => 'Prüfer nach Rolle oder Person';

  @override
  String get featureVatCounterparty => 'USt nach Kunde';

  @override
  String get featureVatCounterpartyDesc =>
      'Wer der Käufer für die USt ist, je Mitglied: Inlands-USt, Steuerschuldnerschaft des Empfängers, außerhalb der EU oder befreit mit gedrucktem Grund. Aus: nur die automatische Regel.';

  @override
  String get featureVatDeclarationsDesc =>
      'Die periodische USt-Voranmeldung aus den Rechnungen erzeugen, auf das amtliche Formular abbilden und übermitteln oder exportieren.';

  @override
  String get featureVatDeclarationsTitle => 'USt-Voranmeldungen';

  @override
  String get featureVatGroups => 'USt-Gruppen';

  @override
  String get featureVatGroupsDesc =>
      'Jeder USt-Satz trägt die steuerliche Gruppe dessen, was er besteuert — Regel-, Zwischen-, ermäßigter, stark ermäßigter, Null-Satz, steuerfrei, nicht steuerbar, Pfand, verbrauchsteuerpflichtig — mit der Kategorie und dem Befreiungsvermerk, den die Gruppe impliziert. Aus: bloße Prozentsätze.';

  @override
  String get featureVatManagementDesc =>
      'Der USt-Satz-Editor und die Satz-Auswahl bei Services, Paketen, Ausstattungen und Tarif. Aus blendet die Konfiguration aus; gespeicherte Sätze gelten weiter. Ein umsatzsteuerpflichtiger Space braucht sie, samt Standardsatz, um eine Rechnung auszustellen: Ohne sie wird die Ausstellung abgelehnt.';

  @override
  String get featureVatManagementTitle => 'USt-Verwaltung';

  @override
  String get featureVatRateHistory => 'USt-Satzversionen';

  @override
  String get featureVatRateHistoryDesc =>
      'Ein Satz ist eine Familie datierter Versionen: eine Änderung per Gesetz fügt den neuen Wert ab seinem Datum hinzu, der alte bleibt auf jeder Leistung davor, nichts wird umgehängt. Aus: ein Wert je Satz.';

  @override
  String get featureVatReport => 'MwSt-Bericht';

  @override
  String get featureVatReportDesc =>
      'Jede steuerbare Position eines Monats oder Zeitraums — Beleg, Kunde, netto, Satz, MwSt, brutto, Kategorie — mit Zwischensummen je Satz, als Brief und als CSV für die Buchhaltung.';

  @override
  String get featureWhatsappIntegration => 'WhatsApp-Integration';

  @override
  String get featureWhatsappIntegrationDesc =>
      'Mitglieder teilen ihre WhatsApp-Nummer im Profil; ein Tipp auf ein Mitglied öffnet den Chat; der Gruppenlink im Verzeichnis. Keine serverseitige WhatsApp-Integration.';

  @override
  String get featureWorkingHours => 'Arbeitszeiten';

  @override
  String get featureWorkingHoursDesc =>
      'Arbeitstag konfigurieren und Buchung nach exakten Uhrzeiten anbieten; aus = Standard 8–17 Uhr.';

  @override
  String get featureWorkspaceBrandingDesc =>
      'Der Arbeitsbereich wählt eine Markenfarbe, aus der die App ihr helles und dunkles Thema ableitet, sowie die Füllfarben seiner Räume. Eine Farbe, die die App unlesbar machen würde, wird mit Begründung abgelehnt; die Palette des Produkts bleibt der Standard.';

  @override
  String get featureWorkspaceBrandingTitle => 'Farben des Arbeitsbereichs';

  @override
  String get featureWorkspaceLibraryDesc =>
      'Speichern Sie den Grundriss dieses Raums und wie er arbeitet als Vorlage, wählen Sie, wer sie sehen darf, laden Sie Personen per E-Mail ein und beginnen Sie mit dem, was andere anbieten.';

  @override
  String get featureWorkspaceLibraryTitle => 'Raumbibliothek';

  @override
  String get featureWorkspaceStatus => 'Lage des Arbeitsbereichs';

  @override
  String get featureWorkspaceStatusDesc =>
      'Was der Arbeitsbereich über einen Zeitraum in Rechnung gestellt, eingenommen, erstattet und umgelegt hat, Mitglied für Mitglied — am Bildschirm für Inhaber und Admins und als druckbarer Bericht. Aus: keine Lageansicht.';

  @override
  String get featureWorkspaceVocabularyDesc =>
      'Der Arbeitsbereich darf je Sprache eine kleine, freigegebene Auswahl an Produktbegriffen umbenennen — einen Platz, die Beschriftungen der Legende, die Tabs. Alles Übrige behält die Formulierung des Produkts, und ein Arbeitsbereich, der nichts umbenennt, sieht genau so aus wie zuvor.';

  @override
  String get featureWorkspaceVocabularyTitle => 'Wortwahl des Arbeitsbereichs';

  @override
  String get featuresFilterChanged => 'Geändert';

  @override
  String get featuresNoMatch => 'Keine Funktion passt dazu.';

  @override
  String get featuresSearchLabel => 'Funktionen durchsuchen';

  @override
  String get featuresTitle => 'Funktionen';

  @override
  String get featuresViewProcesses => 'Prozesse';

  @override
  String get featuresViewSwitches => 'Schalter';

  @override
  String get fecAccountBank => 'Bank';

  @override
  String get fecAccountCustomers => 'Kunden';

  @override
  String get fecAccountExpenses => 'Aufwendungen';

  @override
  String get fecAccountRevenue => 'Erlöse';

  @override
  String get fecAccountVat => 'Vereinnahmte Steuer';

  @override
  String get fecAccountVatPending => 'Umsatzsteuer, noch nicht fällig';

  @override
  String get fecAccountsIntro =>
      'Ein FEC besteht aus Buchungen und braucht daher Kontonummern. Dies sind die Standardkonten des französischen Kontenrahmens — ersetzen Sie sie durch die Ihrer Buchhaltung.';

  @override
  String get fecAccountsTitle => 'Zu buchende Konten';

  @override
  String get fecMissingSiren =>
      'Der FEC-Dateiname enthält die Registernummer — tragen Sie sie zuerst unter Rechtliche Identität ein.';

  @override
  String get federationActionExistingAccount =>
      'Bei meinem bestehenden Konto anmelden';

  @override
  String get federationActionReviewServer => 'Server prüfen';

  @override
  String get federationCancel => 'Abbrechen';

  @override
  String get federationClose => 'Schließen';

  @override
  String get federationContinue => 'Weiter mit Deskilo';

  @override
  String federationDetailAuthority(String host) {
    return 'Identitätsanbieter: $host';
  }

  @override
  String federationDetailServer(String host) {
    return 'Server: $host';
  }

  @override
  String get federationDetails => 'Technische Details';

  @override
  String get federationFailureBrowser =>
      'Der Browser konnte nicht geöffnet werden. Prüfen Sie, ob ein Browser verfügbar ist, und versuchen Sie es erneut.';

  @override
  String get federationFailureExpired =>
      'Diese Anmeldung hat zu lange gedauert und ist abgelaufen. Starten Sie sie neu.';

  @override
  String get federationFailureIncompatible =>
      'Dieser Server akzeptiert diese Deskilo-Anmeldung nicht. Prüfen Sie die Serveradresse oder fragen Sie die Administration.';

  @override
  String get federationFailureNetwork =>
      'Der Server war nicht erreichbar, daher wurde die Anmeldung nicht abgeschlossen. Prüfen Sie Ihre Verbindung und versuchen Sie es erneut.';

  @override
  String get federationFailureProviderMissing =>
      'Die Deskilo-Anmeldung ist auf diesem Server nicht eingerichtet. Bitten Sie die Administration, sie zu aktivieren.';

  @override
  String get federationFailureRefused =>
      'Die Anmeldung wurde im Browser abgebrochen oder abgelehnt. Nichts wurde geändert; Sie können es erneut versuchen.';

  @override
  String get federationFailureUnlinked =>
      'Dieses Deskilo-Konto passt zu einem Konto hier, das noch nicht damit verknüpft ist. Melden Sie sich bei diesem Konto an und verknüpfen Sie Deskilo unter Verknüpfte Konten. Nichts wird zusammengeführt, bevor der Server es bestätigt.';

  @override
  String get federationFailureWrongAccount =>
      'Ihr Browser hat sich mit einem anderen Deskilo-Konto angemeldet. Wechseln Sie das Konto im Browser und versuchen Sie es erneut.';

  @override
  String federationPurpose(String server) {
    return 'Ihr Browser bestätigt Ihr Deskilo-Konto und bringt Sie dann zurück zu $server. Ihre Mitgliedschaften und Ihr Verlauf hier bleiben unverändert.';
  }

  @override
  String get federationRetry => 'Erneut versuchen';

  @override
  String get federationStageCompleting => 'Anmeldung wird abgeschlossen…';

  @override
  String get federationStageOpening => 'Anmeldung wird geöffnet…';

  @override
  String get federationStageWaiting => 'Warten auf die Anmeldung im Browser…';

  @override
  String get fieldProblemNotAChoice => 'Bitte aus der Liste wählen.';

  @override
  String get fieldProblemNotADate => 'Bitte ein Datum.';

  @override
  String get fieldProblemNotANumber => 'Bitte eine Zahl.';

  @override
  String get fieldProblemNotAPhone => 'Das ist keine Telefonnummer.';

  @override
  String get fieldProblemNotAUrl => 'Das ist keine Webadresse.';

  @override
  String get fieldProblemNotAnEmail => 'Das ist keine E-Mail-Adresse.';

  @override
  String get fieldProblemNotWhole => 'Bitte eine ganze Zahl.';

  @override
  String get fieldProblemRequired => 'Bitte beantworten.';

  @override
  String fieldProblemTooEarly(String date) {
    return 'Nicht vor dem $date.';
  }

  @override
  String fieldProblemTooLarge(String max) {
    return 'Höchstens $max.';
  }

  @override
  String fieldProblemTooLate(String date) {
    return 'Nicht nach dem $date.';
  }

  @override
  String fieldProblemTooLong(int count) {
    return 'Höchstens $count Zeichen.';
  }

  @override
  String fieldProblemTooShort(int count) {
    return 'Mindestens $count Zeichen.';
  }

  @override
  String fieldProblemTooSmall(String min) {
    return 'Mindestens $min.';
  }

  @override
  String get financesAllSpaces => 'Alle Spaces';

  @override
  String get financesAutomatic => 'automatisch';

  @override
  String get financesAwaitingValidation => 'Zahlung wird geprüft';

  @override
  String get financesDevSection =>
      'Entwicklungs-Spaces — Testdaten, oben nicht mitgezählt';

  @override
  String financesDueOn(String date) {
    return 'Fällig am $date';
  }

  @override
  String get financesFullHistory =>
      'Vollständiger Verlauf, Nutzung und andere Server';

  @override
  String financesLinkAction(String space) {
    return 'Für $space öffnen';
  }

  @override
  String get financesLinkBody =>
      'Ihre Rechnungen, Mahnungen und Zahlungen aus allen Spaces sind gesammelt unter Ich › Finanzen.';

  @override
  String get financesLinkTitle => 'Ihre Finanzen in allen Workspaces';

  @override
  String get financesNoReminders => 'Keine Erinnerung erhalten.';

  @override
  String get financesNothingOwed => 'Nichts zu zahlen — alles beglichen.';

  @override
  String get financesNothingPaid => 'Noch keine beglichene Rechnung.';

  @override
  String get financesOutstanding => 'Ausstehend';

  @override
  String financesOverdueCount(int count) {
    return '$count überfällig';
  }

  @override
  String financesOverdueSince(String date) {
    return 'Überfällig seit $date';
  }

  @override
  String get financesPaid => 'Bezahlt';

  @override
  String get financesPartlyPaid => 'Teilweise bezahlt';

  @override
  String get financesPayments => 'Zahlungen';

  @override
  String financesRemindedTimes(int count) {
    return 'Erinnert ×$count';
  }

  @override
  String financesReminderLevel(int level) {
    return 'Erinnerung $level';
  }

  @override
  String get financesReminders => 'Erinnerungen';

  @override
  String get financesStateClosed => 'Abgeschlossen';

  @override
  String get financesStatePaid => 'Bezahlt';

  @override
  String get financesStateRefunded => 'Erstattet';

  @override
  String get financesTitle => 'Finanzen';

  @override
  String get financesToPay => 'Zu zahlen';

  @override
  String get gettingStartedActionChooseDay => 'Anderen Tag wählen';

  @override
  String get gettingStartedActionChooseTime => 'Zeit zum Buchen wählen';

  @override
  String get gettingStartedActionFinishSetup => 'Einrichtung abschließen';

  @override
  String get gettingStartedActionHelp => 'Hilfe zu diesem Workspace';

  @override
  String get gettingStartedActionMembership => 'Meine Mitgliedschaft ansehen';

  @override
  String gettingStartedAllowance(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sie können $count Buchungen gleichzeitig halten.',
      one: 'Sie können eine Buchung gleichzeitig halten.',
    );
    return '$_temp0';
  }

  @override
  String get gettingStartedAvailabilityUnknown =>
      'Die Verfügbarkeit konnte nicht geladen werden. Die Hilfe erklärt, wie Buchen hier funktioniert.';

  @override
  String gettingStartedBooked(String state) {
    return 'Ihre Buchung ist $state. Ihre Mitgliedschaft zeigt, was sonst noch enthalten ist.';
  }

  @override
  String get gettingStartedClosedToday =>
      'Der Workspace ist am gewählten Tag geschlossen. Wählen Sie einen anderen Tag, um zu sehen, was frei ist.';

  @override
  String get gettingStartedEnvDev => 'Entwicklungs-Workspace';

  @override
  String get gettingStartedEnvProd => 'Produktions-Workspace';

  @override
  String get gettingStartedMembershipUnknown =>
      'Ihre Mitgliedschaft konnte gerade nicht geladen werden. Die Hilfe erklärt, wie dieser Workspace funktioniert.';

  @override
  String get gettingStartedNoSpaces =>
      'Hier kann noch nichts gebucht werden. Ihre Mitgliedschaft zeigt, was Ihr Zugang umfasst.';

  @override
  String get gettingStartedNotNow => 'Jetzt nicht';

  @override
  String get gettingStartedReadyToBook =>
      'Der Workspace ist an diesem Tag geöffnet. Wählen Sie eine Zeit und einen Platz auf dem Plan — gebucht wird erst, wenn Sie bestätigen.';

  @override
  String get gettingStartedReopen => 'Erste Schritte';

  @override
  String get gettingStartedSemantics =>
      'Erste Schritte: ein vorgeschlagener nächster Schritt';

  @override
  String gettingStartedSetupIncomplete(String step) {
    return 'Bevor hier jemand buchen kann: $step.';
  }

  @override
  String get gettingStartedStandingAdmin => 'Sie sind hier Administrator:in.';

  @override
  String get gettingStartedStandingMember => 'Sie sind hier Mitglied.';

  @override
  String get gettingStartedStandingOwner =>
      'Sie sind Inhaber dieses Workspace.';

  @override
  String get gettingStartedStateCancelled => 'storniert';

  @override
  String get gettingStartedStateCheckedIn => 'eingecheckt';

  @override
  String get gettingStartedStateCompleted => 'abgeschlossen';

  @override
  String get gettingStartedStateReleased => 'freigegeben';

  @override
  String get gettingStartedStateReserved => 'reserviert';

  @override
  String gettingStartedTitle(String workspace) {
    return 'Erste Schritte in $workspace';
  }

  @override
  String get groupAnnounceOnly => 'Nur Admins dürfen schreiben';

  @override
  String get groupAnnounceOnlyHint => 'Alle lesen; nur Admins schreiben.';

  @override
  String get groupCreate => 'Gruppe erstellen';

  @override
  String get groupDescription => 'Beschreibung';

  @override
  String get groupDescriptionAdd => 'Beschreibung hinzufügen';

  @override
  String get groupDescriptionTitle => 'Gruppenbeschreibung';

  @override
  String get groupMakeAdmin => 'Zum Admin machen';

  @override
  String get groupName => 'Gruppenname';

  @override
  String get groupNeedsPeople => 'Fügen Sie mindestens eine Person hinzu.';

  @override
  String get groupNew => 'Neue Gruppe';

  @override
  String get groupNewTitle => 'Neue Gruppe';

  @override
  String get groupPeople => 'Personen der Gruppe';

  @override
  String get groupPickPeople => 'Personen hinzufügen';

  @override
  String get groupPostingClosed =>
      'In dieser Gruppe dürfen nur Admins schreiben.';

  @override
  String get groupRemoveAdmin => 'Admin entfernen';

  @override
  String get groupRename => 'Gruppe umbenennen';

  @override
  String get groupRenameTitle => 'Gruppenname';

  @override
  String get guideActionConfirmBooking =>
      'die Buchung bestätigen und auf die Antwort warten';

  @override
  String get guideActionOpenReserve => 'Reservieren öffnen';

  @override
  String get guideActionSelectDate => 'den Tag wählen';

  @override
  String get guideActionSelectPeriod => 'den Zeitraum wählen';

  @override
  String get guideActionSelectResource =>
      'einen Platz auf dem Plan oder in der Liste wählen';

  @override
  String get guideBookingRefusedRecovery =>
      'Die Buchung wurde abgelehnt (Platz belegt oder eine Regel verbietet es). Wählen Sie einen anderen Platz oder Zeitraum und bestätigen Sie erneut.';

  @override
  String get guideBuiltinBooking => 'Einen Platz buchen';

  @override
  String get guideBuiltinBookingIntro =>
      'Diese Anleitung zeigt, wie Sie einen Platz buchen: Tag und Zeitraum wählen, einen Platz auswählen, dann bestätigen. Nichts wird gebucht, bevor Sie bestätigen.';

  @override
  String get guideHostBack => 'Zurück';

  @override
  String get guideHostBlocked =>
      'Klären Sie zuerst die Meldung auf dem Bildschirm; die Anleitung wartet.';

  @override
  String get guideHostClose => 'Schließen';

  @override
  String get guideHostCommand =>
      'Bestätigen Sie und warten Sie auf das Ergebnis.';

  @override
  String get guideHostCompleted => 'Anleitung abgeschlossen.';

  @override
  String get guideHostDestination => 'Ziel des Schritts';

  @override
  String get guideHostDestinationMissing =>
      'Wählen Sie die Seite dieses Schritts im Guide-Editor.';

  @override
  String guideHostDoAction(String action) {
    return 'Als Nächstes: $action.';
  }

  @override
  String get guideHostDone => 'Erledigt';

  @override
  String get guideHostFillField =>
      'Füllen Sie das hervorgehobene Feld aus und verlassen Sie es.';

  @override
  String guideHostFillLabel(String label) {
    return 'Füllen Sie „$label“ aus und verlassen Sie dann das Feld.';
  }

  @override
  String get guideHostGoToPage => 'Zur Seite';

  @override
  String get guideHostInstruction =>
      'Lesen Sie dies und markieren Sie es als erledigt.';

  @override
  String get guideHostManual =>
      'Erledigen Sie diesen Schritt selbst und markieren Sie ihn als erledigt.';

  @override
  String guideHostManualAt(String form) {
    return 'Führen Sie diesen Schritt auf „$form“ aus und markieren Sie ihn dann als erledigt.';
  }

  @override
  String guideHostManualProtected(String category) {
    return 'Dieser Teil findet auf einem geschützten Bildschirm statt ($category). Erledigen Sie ihn selbst und markieren Sie ihn als erledigt.';
  }

  @override
  String get guideHostMinimize => 'Anleitung verkleinern';

  @override
  String get guideHostNotOnScreen =>
      'Öffnen Sie die Seite des Schritts und folgen Sie den vorherigen Schritten, um dieses Bedienelement anzuzeigen.';

  @override
  String guideHostOpenLabel(String label) {
    return 'Öffnen Sie „$label“.';
  }

  @override
  String get guideHostOpenScreen => 'Öffnen Sie den nächsten Bildschirm.';

  @override
  String get guideHostPausedFeature =>
      'Pausiert: Der Aufgabenrekorder ist in diesem Workspace ausgeschaltet.';

  @override
  String get guideHostPausedScope =>
      'Pausiert: Konto oder Workspace hat sich geändert. Die Anleitung geht nur dort weiter, wo sie begann.';

  @override
  String get guideHostRecovery =>
      'Das wurde abgelehnt. Folgen Sie diesen Schritten und versuchen Sie es dann erneut.';

  @override
  String guideHostRestore(int current, int total) {
    return 'Anleitung anzeigen (Schritt $current von $total)';
  }

  @override
  String get guideHostResume => 'Fortsetzen';

  @override
  String get guideHostShowMe => 'Öffnen und hervorheben';

  @override
  String get guideHostSkip => 'Überspringen';

  @override
  String get guideHostStatusAcknowledged => 'Bestätigt';

  @override
  String get guideHostStatusDone => 'Erledigt';

  @override
  String get guideHostStatusPending => 'Offen';

  @override
  String get guideHostStatusSkipped => 'Übersprungen';

  @override
  String get guideHostStatusWaiting => 'Wartet';

  @override
  String guideHostStepOf(int current, int total) {
    return 'Schritt $current von $total';
  }

  @override
  String get guideHostSteps => 'Alle Schritte';

  @override
  String get guideHostStop => 'Anleitung beenden';

  @override
  String get guideHostStopped =>
      'Anleitung beendet. Nichts wurde rückgängig gemacht.';

  @override
  String get guideHostTapControl =>
      'Tippen Sie auf das hervorgehobene Bedienelement.';

  @override
  String guideHostTapLabel(String label) {
    return 'Tippen Sie auf „$label“.';
  }

  @override
  String get guideHostTitle => 'Geführte Aufgabe';

  @override
  String get guideHostUncertain =>
      'Die Antwort kam nicht an. Prüfen Sie, ob es geklappt hat, bevor Sie es erneut versuchen.';

  @override
  String get guideHostWaiting => 'Auf das Ergebnis wird gewartet …';

  @override
  String get guideStart => 'Anleitung starten';

  @override
  String get guideStartNotRunnable =>
      'Diese Anleitung enthält Schritte, die diese App-Version nicht kennt; sie kann gelesen, aber nicht befolgt werden.';

  @override
  String get guideStartRefused =>
      'Diese Anleitung kann hier nicht starten: Melden Sie sich an und schalten Sie den Aufgabenrekorder in diesem Workspace ein.';

  @override
  String handoffAmountOutOfRange(String number) {
    return '$number: eine Summe, die zu groß ist, um exakt übertragen zu werden';
  }

  @override
  String get handoffBlocked =>
      'Diese Datei kann erst übergeben werden, wenn die Quelle korrigiert ist.';

  @override
  String get handoffChanged =>
      'Die Rechnungen haben sich während Ihrer Prüfung geändert. Exportieren Sie erneut, um den aktuellen Stand zu sehen.';

  @override
  String handoffDuplicate(String number) {
    return '$number: erscheint zweimal in der Quelle';
  }

  @override
  String handoffExcludedSettlements(String count) {
    return '$count Sammelabrechnung(en) ausgelassen: ihre Rechnungen stehen bereits in der Datei';
  }

  @override
  String handoffIncluded(String count) {
    return '$count Beleg(e) in der Datei';
  }

  @override
  String get handoffIssued => 'Ausgestellt';

  @override
  String handoffMissingCurrency(String number) {
    return '$number: keine Währung';
  }

  @override
  String handoffOrphanMatch(String key) {
    return 'Eine Zahlung ($key) gehört zu keinem Beleg dieses Exports';
  }

  @override
  String handoffOverpaid(String number) {
    return '$number: mehr bezahlt als berechnet';
  }

  @override
  String handoffPayments(String confirmed, String pending) {
    return 'Bezahlt: $confirmed bestätigt, $pending ausstehend';
  }

  @override
  String handoffRowMismatch(String detail) {
    return 'Die Zeilen der Datei passen nicht zu den Belegen ($detail)';
  }

  @override
  String get handoffSave => 'Datei und Bericht speichern';

  @override
  String get handoffTitle => 'Vor dem Speichern';

  @override
  String handoffUnsupportedCurrency(String number) {
    return '$number: für ihre Währung ist keine geprüfte Zahl von Nachkommastellen hinterlegt';
  }

  @override
  String get handoffVoided => 'Storniert';

  @override
  String get helpContents => 'Inhalt';

  @override
  String get helpDotTooltip => 'Handbuch öffnen';

  @override
  String get helpGuidedTasks => 'Geführte Aufgaben';

  @override
  String get helpHintAvailability =>
      'Öffnungstage und Arbeitszeiten festlegen und Schließtage eintragen, die niemand buchen kann.';

  @override
  String get helpHintAvailabilityTopic => 'Verfügbarkeit';

  @override
  String get helpHintBadges =>
      'Druckbares QR-Badge ausstellen oder NFC-Karte registrieren; verlorene Badges jederzeit sperren.';

  @override
  String get helpHintBadgesTopic => 'NFC-Badge';

  @override
  String get helpHintCalendar =>
      'Einen Tag oder Zeitraum wählen: alles Datierte, das Sie sehen dürfen, in einer Liste, jede Zeile öffnet ihre Quelle.';

  @override
  String get helpHintCalendarTopic => 'Kalender';

  @override
  String get helpHintDismiss => 'Hinweis ausblenden';

  @override
  String get helpHintEditor =>
      'Räume und Schreibtische zeichnen, Plätze aufstempeln — einen Platz zweimal antippen, um seine Eigenschaften zu bearbeiten.';

  @override
  String get helpHintEditorTopic => 'Space-Editor';

  @override
  String get helpHintEvents =>
      'Alles, was passiert ist, in einem Feed. Ausstehende Entscheidungen stehen oben; die Chips filtern den Rest.';

  @override
  String get helpHintEventsTopic => 'Ereignisse';

  @override
  String get helpHintFeatures =>
      'Workspace-Funktionen ein- oder ausschalten — die App jedes Mitglieds folgt sofort.';

  @override
  String get helpHintFeaturesTopic => 'Funktionen';

  @override
  String get helpHintLearnMore => 'Mehr erfahren';

  @override
  String get helpHintMembers =>
      'Mitglieder einladen, Plan-Prozentsatz und Rolle festlegen und ihre Badges verwalten.';

  @override
  String get helpHintMembersTip4Topic => 'Rollenverwaltung';

  @override
  String get helpHintMembersTipNegotiationTopic => 'Preisverhandlungen';

  @override
  String get helpHintMembersTopic => 'Mitglieder & Tarife';

  @override
  String get helpHintMessages =>
      'Alle Unterhaltungen in einer Liste, die neueste oben. Tippen Sie auf den Stift, um jemandem zu schreiben oder eine Gruppe zu erstellen.';

  @override
  String get helpHintMessagesTip2 =>
      'Wählen Sie eine Person für einen privaten Chat oder mehrere für eine Gruppe — das Namensfeld erscheint ab zwei, und der Gruppenname ist hier eindeutig: niemand muss raten, welches „Team“ gemeint ist.';

  @override
  String get helpHintMessagesTip3 =>
      'Tippen Sie oben in einem Chat auf den Namen, um das Profil zu sehen: die heutige Buchung, ob jemand eingecheckt ist, und wie man ihn erreicht.';

  @override
  String get helpHintMessagesTip4 =>
      'Die Suche findet Mitglieder, Gruppen und Wörter in Nachrichten — ein Treffer bringt Sie direkt dorthin.';

  @override
  String get helpHintMessagesTip5 =>
      'Verlinken Sie eine Reservierung oder einen Bereich, statt ihn zu beschreiben; ein Tippen führt zum richtigen.';

  @override
  String get helpHintMessagesTopic => 'Nachrichten';

  @override
  String get helpHintMoney =>
      'Die Monatsabrechnung: mit den Pfeilen durch die Monate blättern; von hier zahlen, exportieren oder teilen.';

  @override
  String get helpHintMoneyDocuments =>
      'Ihre Unterlagen: Ihre Konditionen, der Zahlungsbericht, die Monatsabrechnung als PDF, die Dokumentbibliothek.';

  @override
  String get helpHintMoneyDocumentsTopic => 'Dokumente';

  @override
  String get helpHintMoneyInvoices =>
      'Ihre Rechnungen: was offen ist und bis wann, jede an Sie gestellte Rechnung mit Status, ein Tipp zum Detail und zum Bezahlen.';

  @override
  String get helpHintMoneyInvoicesTip2Topic =>
      'Automatische Zahlungserinnerungen';

  @override
  String get helpHintMoneyInvoicesTopic => 'Rechnungen';

  @override
  String get helpHintMoneyPayments =>
      'Begleichen und anfragen: der Saldo, wie Sie ihn begleichen oder online zahlen, eine Zahlung erfassen — und eine Ausgabe einreichen, halbe Tage anfragen oder einen Verbrauch hinzufügen.';

  @override
  String get helpHintMoneyPaymentsTip3Topic => 'Online-Zahlungen';

  @override
  String get helpHintMoneyPaymentsTipSupplyTopic => 'Services und Zubehör';

  @override
  String get helpHintMoneyPaymentsTopic => 'Zahlung';

  @override
  String get helpHintMoneyStatement =>
      'Der Monat, wie er steht: Ihr Konto, genutzte und verbleibende Tage, Abonnement, Leistungen, Pakete, offene Posten, Gutschriften und der Saldo. Monate mit den Pfeilen durchblättern.';

  @override
  String get helpHintMoneyStatementTopic => 'Abrechnung';

  @override
  String get helpHintMoneyTopic => 'Geld';

  @override
  String get helpHintNextTip => 'Nächster Tipp';

  @override
  String get helpHintPlan =>
      'Der Live-Grundriss: freien Platz antippen zum Buchen, die eigene Buchung antippen zum Einchecken.';

  @override
  String get helpHintPlanTopic => 'Grundriss';

  @override
  String get helpHintPrevTip => 'Vorheriger Tipp';

  @override
  String get helpHintPrivacy =>
      'Sehen, wer Ihre Daten lesen kann und wer es tat, alles als eine Datei exportieren oder den Bereich mit gelöschten persönlichen Daten verlassen.';

  @override
  String get helpHintPrivacyTopic => 'Datenschutz';

  @override
  String get helpHintReserve =>
      'Tag und Zeitfenster wählen, dann einen freien Platz antippen, um ihn zu buchen.';

  @override
  String get helpHintReserveTip4Topic => 'Wie sich Buchungen verhalten';

  @override
  String get helpHintReserveTopic => 'Reservierungsübersicht';

  @override
  String get helpHintRestoreTitle => 'Hilfe-Hinweise wieder anzeigen';

  @override
  String get helpHintRestored => 'Die Hilfe-Hinweise werden wieder angezeigt.';

  @override
  String get helpHintValidation =>
      'Festlegen, welche Aktionen eine Bestätigung brauchen, wer bestätigt und wie viele Zustimmungen nötig sind.';

  @override
  String get helpHintValidationTopic => 'Bestätigungen';

  @override
  String get helpHintWorkspace =>
      'Land, Währung, Sprache und Rechnungsdaten — Dokumente und Steuern folgen diesen Einstellungen.';

  @override
  String get helpHintWorkspaceTopic => 'Workspace-Einstellungen';

  @override
  String get helpTitle => 'Hilfe';

  @override
  String get helpTopicAccounting => 'Buchhaltungsexporte';

  @override
  String get helpTopicBilling => 'Abrechnung';

  @override
  String get helpTopicBookingLimits => 'Buchungsgrenzen';

  @override
  String get helpTopicBookingPolicies => 'Buchungsregeln';

  @override
  String get helpTopicDeployment => 'Deployen';

  @override
  String get helpTopicDocumentLibrary => 'Dokumentenbibliothek';

  @override
  String get helpTopicEinvoice => 'E-Rechnung';

  @override
  String get helpTopicEnvironments => 'Umgebungen';

  @override
  String get helpTopicInstances => 'Instanzen';

  @override
  String get helpTopicKiosk => 'Kiosk-Modus';

  @override
  String get helpTopicLegalIdentity => 'Rechtliche Identität';

  @override
  String get helpTopicReadiness => 'Bereitschaftsprüfung';

  @override
  String get helpTopicReportEditor => 'Berichtseditor';

  @override
  String get helpTopicReportLayout => 'Positionierte Layouts';

  @override
  String get helpTopicScheduledExpenses => 'Geplante Ausgaben';

  @override
  String get helpTopicServer => 'eigener Server';

  @override
  String get helpTopicSettings => 'Einstellungen & Profil';

  @override
  String get helpTopicTrace => 'Das Protokoll';

  @override
  String get helpTopicVat => 'MwSt';

  @override
  String get helpTopicWindowEnvelope => 'Der Vertrag des Fensterkuverts';

  @override
  String get helpTopicWorkingHours => 'Arbeitszeiten';

  @override
  String get helpTopicWorkspaceId => 'Workspace-ID';

  @override
  String get holidayAllSaints => 'Allerheiligen';

  @override
  String get holidayArmistice => 'Waffenstillstand 1918';

  @override
  String get holidayAscension => 'Christi Himmelfahrt';

  @override
  String get holidayAssumption => 'Mariä Himmelfahrt';

  @override
  String get holidayBoxingDay => 'Zweiter Weihnachtsfeiertag';

  @override
  String get holidayChristmas => 'Weihnachten';

  @override
  String get holidayEasterMonday => 'Ostermontag';

  @override
  String get holidayGermanUnity => 'Tag der Deutschen Einheit';

  @override
  String get holidayGoodFriday => 'Karfreitag';

  @override
  String get holidayImportAction => 'Feiertage importieren (Open Data)';

  @override
  String holidayImportConfirm(int count) {
    return '$count Schließtage importieren';
  }

  @override
  String get holidayImportFailed =>
      'Die Feiertage konnten nicht geprüft oder importiert werden. Es wurde nichts geändert.';

  @override
  String get holidayImportNationwide => 'Nur bundesweite Feiertage';

  @override
  String get holidayImportRegion => 'Region';

  @override
  String get holidayImportRetry => 'Erneut versuchen';

  @override
  String holidayImportSource(String source) {
    return 'Quelle: $source';
  }

  @override
  String get holidayImportUnavailable =>
      'Die Feiertagsquelle ist gerade nicht erreichbar. Versuchen Sie es später erneut oder verwenden Sie „Feiertage hinzufügen“.';

  @override
  String get holidayLabourDay => 'Tag der Arbeit';

  @override
  String get holidayNationalDay => 'Französischer Nationalfeiertag';

  @override
  String get holidayNewYear => 'Neujahr';

  @override
  String get holidayVictory1945 => 'Tag des Sieges 1945';

  @override
  String get holidayWhitMonday => 'Pfingstmontag';

  @override
  String get identityConnectBrowser =>
      'Der Browser konnte nicht geöffnet werden.';

  @override
  String identityConnectConfirmApply(String name) {
    return 'Ihre Mitgliedsanfrage an $name senden?';
  }

  @override
  String get identityConnectConfirmApplyBody =>
      'Sie sind jetzt verbunden. Der Space prüft Ihre Anfrage; sonst wird nichts geteilt.';

  @override
  String get identityConnectContinue => 'Mit Deskilo fortfahren';

  @override
  String get identityConnectCurrentServer =>
      'Mit diesem Server sind Sie bereits angemeldet.';

  @override
  String get identityConnectDifferentAuthority =>
      'Dieser Server akzeptiert einen anderen Identitätsanbieter.';

  @override
  String identityConnectDone(String host) {
    return 'Mit $host verbunden.';
  }

  @override
  String get identityConnectExistingAccount =>
      'Ein Konto verwenden, das ich auf diesem Server bereits habe';

  @override
  String get identityConnectExpired =>
      'Die Anmeldung hat zu lange gedauert. Beginnen Sie erneut.';

  @override
  String identityConnectExplain(String host) {
    return '$host erfährt über Ihre Deskilo-Identität, dass Sie es sind. Das Verbinden macht Sie weder zum Mitglied, noch gibt es Ihnen eine Rolle oder verbindet einen Assistenten: Über jede Anfrage entscheidet weiterhin der Space.';
  }

  @override
  String get identityConnectNetwork =>
      'Der Server hat nicht geantwortet. Versuchen Sie es erneut.';

  @override
  String get identityConnectNoDeskiloSignIn =>
      'Dieser Server bietet keine Anmeldung mit Deskilo an.';

  @override
  String get identityConnectNoSharedIdentity =>
      'Ihr Konto hier hat keine Deskilo-Identität, die ein anderer Server akzeptieren könnte.';

  @override
  String identityConnectNotSaved(String host) {
    return '$host hat Sie akzeptiert, aber dieses Gerät konnte die Verbindung nicht speichern. Es wurde nichts gesendet. Versuchen Sie es erneut.';
  }

  @override
  String get identityConnectRefused =>
      'Die Verbindung wurde nicht abgeschlossen. Es wurde nichts gesendet.';

  @override
  String get identityConnectRetry => 'Erneut versuchen';

  @override
  String get identityConnectSend => 'Anfrage senden';

  @override
  String get identityConnectServerUnsupported =>
      'Dieser Server kann mit dieser App-Version nicht verbunden werden.';

  @override
  String identityConnectTitle(String host) {
    return 'Mit $host verbinden';
  }

  @override
  String get identityConnectUnavailable =>
      'Dieser Server hat nicht geantwortet.';

  @override
  String get identityConnectUnlinked =>
      'Ein Konto auf diesem Server verwendet diese Identität oder E-Mail-Adresse bereits, ohne damit verknüpft zu sein. Verwenden Sie stattdessen dieses Konto.';

  @override
  String get identityConnectWaiting =>
      'Schließen Sie die Anmeldung im Browser ab und kehren Sie dann hierher zurück.';

  @override
  String get identityConnectWrongAccount =>
      'Der Browser hat sich als jemand anderes angemeldet. Es wurde nichts verbunden.';

  @override
  String identityConsentAsks(String host) {
    return 'Melden Sie sich mit Ihrer Deskilo-Identität bei $host an.';
  }

  @override
  String get identityConsentCompleting => 'Ihre Auswahl wird gespeichert…';

  @override
  String get identityConsentPurpose =>
      'Der Zugriff auf Arbeitsbereiche und Assistenten wird separat genehmigt.';

  @override
  String get identityConsentReturnFailed =>
      'Das Ziel konnte nicht geöffnet werden.';

  @override
  String get identityConsentReturning => 'Zurück zur Anmeldung…';

  @override
  String get identityConsentTitle => 'Mit Deskilo fortfahren';

  @override
  String get identityConsentUnavailable =>
      'Diese Anmeldeanfrage ist nicht verfügbar. Kehren Sie zum Ziel zurück und beginnen Sie erneut.';

  @override
  String get inboxAlertsTab => 'Hinweise';

  @override
  String get inboxChatsTab => 'Chats';

  @override
  String get inboxFilterAll => 'Alle';

  @override
  String get inboxFilterArchived => 'Archiviert';

  @override
  String get inboxFilterUnread => 'Ungelesen';

  @override
  String get inboxMessengerDoor => 'Meine Nachrichten öffnen';

  @override
  String get inboxNoArchived => 'Keine archivierten Unterhaltungen.';

  @override
  String get inboxNoUnread =>
      'Nichts Ungelesenes — Sie sind auf dem Laufenden.';

  @override
  String get inboxRetry => 'Erneut versuchen';

  @override
  String get instanceAccessTitle => 'Assistenten-Zugang';

  @override
  String instanceAccessUntil(String date) {
    return 'Bis $date';
  }

  @override
  String get instanceAccountIntro =>
      'Legen Sie ein kostenloses Konto auf supabase.com an, erstellen Sie dann ein persönliches Zugriffstoken (Account → Access Tokens) und fügen Sie es hier ein. Der Assistent nutzt es, um das Projekt anzulegen und einzurichten; es wird nie gespeichert.';

  @override
  String get instanceAdminsHelp =>
      'Sie entscheiden, wer Assistenten nutzen darf. Wählbar ist nur, wer seine Identität für Assistenten bestätigt hat.';

  @override
  String get instanceAdminsTitle => 'Datenbankadministratoren';

  @override
  String get instanceApplySignIn => 'Anmeldeeinstellungen anwenden';

  @override
  String get instanceApprove => 'Freigeben';

  @override
  String instanceAttentionForeign(String tables) {
    return 'Sein public-Schema enthält Tabellen, die DesKilo nicht anlegt ($tables). Dort wird nicht installiert; verwenden Sie ein leeres Projekt.';
  }

  @override
  String get instanceAttentionNotHealthy =>
      'Supabase meldet das Projekt nicht als betriebsbereit. Warten Sie, bis es das ist, oder stellen Sie es im Dashboard wieder her.';

  @override
  String get instanceAttentionOtherTooling =>
      'Seine Migrationen wurden von anderen Werkzeugen erfasst; wo DesKilo fortsetzen würde, lässt sich nicht lesen. Verwenden Sie ein leeres Projekt.';

  @override
  String instanceAttentionPostgres(int found, int supported) {
    return 'Es läuft mit Postgres $found; DesKilo ist für Postgres $supported gebaut.';
  }

  @override
  String get instanceAttentionUnrecorded =>
      'DesKilo-Tabellen sind vorhanden, aber keine Migration wurde erfasst. Erfassen Sie zuerst den Stand mit `dart run tool/instance.dart record`.';

  @override
  String get instanceBlock => 'Sperren';

  @override
  String get instanceBlockerNoAdmin => 'ein Datenbankadministrator';

  @override
  String get instanceBlockers => 'Es fehlt noch:';

  @override
  String get instanceCheckToken => 'Token prüfen';

  @override
  String get instanceChooseAnother => 'Anderes Projekt wählen';

  @override
  String get instanceClaimBody =>
      'Sie haben diese Instanz erstellt und es ist kein Eigentümer festgelegt. Mit der Übernahme sind Sie dafür verantwortlich.';

  @override
  String get instanceClaimButton => 'Eigentum übernehmen';

  @override
  String get instanceClaimDone => 'Sie sind jetzt der Instanzeigentümer.';

  @override
  String get instanceClaimFailed =>
      'Das Eigentum konnte nicht übernommen werden.';

  @override
  String get instanceClaimTitle => 'Eigentum übernehmen';

  @override
  String get instanceClientApproved => 'Freigegeben';

  @override
  String get instanceClientBlocked => 'Gesperrt';

  @override
  String get instanceClientWaiting => 'Wartet auf Freigabe';

  @override
  String get instanceClientsHelp =>
      'Ein Assistent registriert sich bei der ersten Verbindung selbst; er funktioniert erst nach der Freigabe hier.';

  @override
  String get instanceClientsTitle => 'Assistenten-Clients';

  @override
  String get instanceConfirmSecondFactor =>
      'Mit meinem Authenticator bestätigen';

  @override
  String get instanceCreateButton => 'Neue Instanz anlegen';

  @override
  String get instanceCreateProject => 'Projekt anlegen';

  @override
  String get instanceDatabasePassword =>
      'Datenbank-Passwort, für Sie gewählt — kopieren Sie es an einen sicheren Ort; die App braucht es nie wieder.';

  @override
  String get instanceDelegateAdd => 'Rolle delegieren';

  @override
  String get instanceDelegateAlreadyOwner =>
      'Der Eigentümer braucht keine Delegation.';

  @override
  String get instanceDelegateFieldLabel => 'E-Mail-Adresse eines Kontos';

  @override
  String get instanceDelegateNoAccount =>
      'Kein Konto verwendet diese E-Mail-Adresse.';

  @override
  String get instanceDelegateUnavailable =>
      'Dieser Server kann noch nicht delegieren.';

  @override
  String get instanceDelegateUnchanged =>
      'Diese Person ist bereits Stellvertreter.';

  @override
  String get instanceDelegateUnconfirmed =>
      'Dieses Konto hat seine E-Mail-Adresse noch nicht bestätigt.';

  @override
  String get instanceDelegateWithdraw => 'Delegation entziehen';

  @override
  String get instanceDelegateWithdrawBody =>
      'Die Person verliert sofort den Zugriff auf die installationsweite Einrichtung.';

  @override
  String get instanceDelegateWithdrawConfirm => 'Entziehen';

  @override
  String get instanceDelegateWithdrawTitle => 'Diese Delegation entziehen?';

  @override
  String get instanceDelegated => 'Delegiert.';

  @override
  String get instanceDelegatesHelp =>
      'Ein Stellvertreter kann die installationsweite Einrichtung der Assistenten durchführen. Er kann nicht weiter delegieren und sieht keinen anderen Arbeitsbereich.';

  @override
  String get instanceDelegatesNone => 'Keine Stellvertreter.';

  @override
  String get instanceDelegatesTitle => 'Stellvertreter';

  @override
  String get instanceDelegationWithdrawn => 'Delegation entzogen.';

  @override
  String instanceDeployFunctions(int count) {
    return 'Funktionen bereitstellen: Zahlungen, E-Rechnungen, Push, Badges ($count).';
  }

  @override
  String get instanceDoctorAttention => 'Handlungsbedarf';

  @override
  String get instanceDoctorIntro =>
      'Bevor dieses Gerät sie nutzt, muss die Sicherheitsprüfung bestehen: ein Alarm hält die Schaltfläche gesperrt, bis er behoben ist.';

  @override
  String instanceDoctorPassed(int count) {
    return '$count Prüfungen bestanden';
  }

  @override
  String get instanceDoctorProtected => 'Geschützt';

  @override
  String get instanceDoctorRun => 'Sicherheitsprüfung starten';

  @override
  String get instanceDoctorRunAgain => 'Erneut prüfen';

  @override
  String get instanceDoneIntro =>
      'Die Instanz ist bereit. Verwenden Sie sie auf diesem Gerät und teilen Sie dann den Server-QR vom Server-Bildschirm, damit Mitglieder derselben beitreten.';

  @override
  String get instanceEndpointTitle => 'Assistenten-Endpunkt';

  @override
  String get instanceFamilyChatgpt => 'ChatGPT';

  @override
  String get instanceFamilyClaude => 'Claude';

  @override
  String get instanceFamilyLoopback => 'Desktop- oder Kommandozeilen-Assistent';

  @override
  String get instanceGrant => 'Zugang freigeben';

  @override
  String get instanceGrantDays => 'Wählen Sie zwischen 1 und 30 Tagen.';

  @override
  String instanceGrantDaysLabel(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tage',
      one: '1 Tag',
    );
    return 'Für $_temp0';
  }

  @override
  String get instanceGrantHelp =>
      'Solange kein anderer Datenbank-Administrator existiert, geben Sie Zugänge selbst frei — Ihren eigenen eingeschlossen — für höchstens 30 Tage und mit Begründung. Jede Freigabe wird protokolliert.';

  @override
  String get instanceGrantNeedsGoogle =>
      'Zum Freigeben muss diese Sitzung mit Google angemeldet sein.';

  @override
  String get instanceGrantNoIdentity =>
      'Diese Person hat ihre Identität noch nicht bestätigt.';

  @override
  String get instanceGrantOtherAdmin =>
      'Hier entscheidet ein Datenbank-Administrator über den Zugang; fragen Sie ihn.';

  @override
  String get instanceGrantReason => 'Begründung';

  @override
  String get instanceGrantReasonNeeded =>
      'Schreiben Sie, warum dieser Zugang freigegeben wird (bis zu 500 Zeichen).';

  @override
  String instanceGrantTitle(String name) {
    return 'Assistenten-Zugang für $name freigeben';
  }

  @override
  String instanceInstallSchema(int count) {
    return 'Schema installieren: jede Migration der App, in Reihenfolge ($count).';
  }

  @override
  String get instanceIntro =>
      'Einstellungen für alle Arbeitsbereiche dieser Installation. Nur der Instanzbetreiber sieht diese Seite; jede Änderung erfordert Ihren zweiten Faktor und wird protokolliert.';

  @override
  String get instanceLoopbackHelp =>
      'Claude Code, Cursor, VS Code und andere Assistenten, die auf dem eigenen Computer einer Person laufen. Jede Person gibt ihre eigene Verbindung weiterhin selbst frei.';

  @override
  String get instanceLoopbackTitle =>
      'Desktop- und Kommandozeilen-Assistenten erlauben';

  @override
  String get instanceMakeAdmin => 'Zum Administrator machen';

  @override
  String get instanceNoCandidates =>
      'Noch niemand sonst hat seine Identität bestätigt.';

  @override
  String get instanceNotOperator =>
      'Nur der Instanzbetreiber verwaltet die Assistenten der Installation.';

  @override
  String instanceNoticeClientWaiting(String name) {
    return '$name wartet auf Ihre Freigabe.';
  }

  @override
  String instanceNoticeOperatorGrant(String name) {
    return 'Der Betreiber hat den Assistenten-Zugang für $name freigegeben.';
  }

  @override
  String instanceNoticeSelfGrant(String name) {
    return '$name hat den eigenen Assistenten-Zugang freigegeben.';
  }

  @override
  String get instanceNoticesMarkRead => 'Als gelesen markieren';

  @override
  String get instanceOperatorApproved => 'Vom Betreiber freigegeben';

  @override
  String get instanceOrganisationLabel => 'Organisation';

  @override
  String get instanceOwnerClaimIntro =>
      'Wem gehört diese Instanz? Geben Sie die E-Mail-Adresse ein, mit der Sie sich dort registrieren werden. Nachdem Sie diese Adresse bestätigt haben, beanspruchen Sie die Inhaberschaft unter Einstellungen → Instanzeigentümer.';

  @override
  String get instanceOwnerClaimLabel => 'E-Mail des Inhabers';

  @override
  String get instanceOwnerCopied => 'E-Mail-Adresse kopiert.';

  @override
  String get instanceOwnerCopyEmail => 'E-Mail-Adresse kopieren';

  @override
  String get instanceOwnerHelp =>
      'Diese Installation wird von allen ihren Arbeitsbereichen gemeinsam genutzt. Der Instanzeigentümer ist dafür verantwortlich: Wenden Sie sich an ihn bei allem, was die ganze Installation betrifft, etwa Assistenten.';

  @override
  String get instanceOwnerNone =>
      'Es ist noch kein Instanzeigentümer festgelegt.';

  @override
  String get instanceOwnerTitle => 'Instanzeigentümer';

  @override
  String get instanceProbeCheck => 'Server prüfen';

  @override
  String get instanceProbeDeployed =>
      'Der Assistenten-Endpunkt antwortet wie erwartet.';

  @override
  String get instanceProbeMismatch =>
      'Der Endpunkt antwortet mit einer anderen Adresse als der, die Assistenten erhalten.';

  @override
  String get instanceProbeMissing => 'Der Server wurde noch nicht geprüft.';

  @override
  String get instanceProbeNotDeployed =>
      'Der Assistenten-Endpunkt ist auf diesem Server noch nicht bereitgestellt.';

  @override
  String get instanceProbePending => 'Server wird geprüft…';

  @override
  String get instanceProbeStale =>
      'Die letzte Prüfung ist älter als 15 Minuten. Prüfen Sie erneut, bevor Sie die Assistenten einschalten.';

  @override
  String get instanceProbeUnavailable =>
      'Der Server war nicht erreichbar. Versuchen Sie es gleich noch einmal.';

  @override
  String instanceProgress(int done, int total, String current) {
    return '$done / $total · $current';
  }

  @override
  String get instanceProjectName => 'Projektname';

  @override
  String instanceProjectReady(String ref) {
    return 'Projekt bereit: $ref';
  }

  @override
  String instanceProjectStatus(String status) {
    return 'Projektstatus: $status';
  }

  @override
  String get instanceReadyAttention =>
      'Dieses Projekt braucht Aufmerksamkeit — nichts wurde installiert.';

  @override
  String instanceReadyCurrent(int version) {
    return 'DesKilo-Version $version ist installiert und aktuell: das Schema braucht nichts.';
  }

  @override
  String get instanceReadyInstall =>
      'Das Projekt ist leer: alles wird installiert.';

  @override
  String instanceReadyResume(int pending) {
    return 'Eine DesKilo-Installation brach mittendrin ab: $pending Migrationen fehlen noch, und nur diese laufen.';
  }

  @override
  String instanceReadyUpgrade(int version, int pending) {
    return 'DesKilo-Version $version ist installiert: nur die $pending fehlenden Migrationen laufen.';
  }

  @override
  String get instanceRegion => 'Region (die nächste zum Raum)';

  @override
  String get instanceRemoveAdmin => 'Entfernen';

  @override
  String get instanceRetry => 'Dort weitermachen, wo es stoppte';

  @override
  String get instanceRevokeToken =>
      'Sie können das Zugriffstoken jetzt widerrufen: DesKilo hat keine Kopie behalten.';

  @override
  String get instanceRuntimeOff => 'Ausgeschaltet';

  @override
  String get instanceRuntimeOn => 'Eingeschaltet';

  @override
  String get instanceRuntimeTitle => 'Assistenten auf dieser Installation';

  @override
  String get instanceSecondFactorNeeded =>
      'Änderungen hier erfordern Ihren zweiten Faktor in dieser Sitzung.';

  @override
  String get instanceSelfApproved => 'Vom Betreiber selbst freigegeben';

  @override
  String get instanceSignInExplain =>
      'Anmeldeeinstellungen: E-Mail-Bestätigung an (eine Registrierung muss den Link in der Mail anklicken), und die Links der App für Passwort-Resets und Magic Links erlaubt.';

  @override
  String get instanceStepAccount => 'Konto';

  @override
  String get instanceStepDone => 'Fertig';

  @override
  String instanceStepFailed(String item, String message) {
    return 'Gestoppt bei $item: $message';
  }

  @override
  String get instanceStepFunctions => 'Funktionen';

  @override
  String get instanceStepProject => 'Projekt';

  @override
  String get instanceStepSchema => 'Schema';

  @override
  String get instanceStepSignIn => 'Anmeldung';

  @override
  String get instanceTitle => 'Installation: Assistenten';

  @override
  String get instanceTokenLabel => 'Persönliches Zugriffstoken';

  @override
  String get instanceTokenReach =>
      'Ein persönliches Zugriffstoken öffnet Ihr ganzes Supabase-Konto, solange es besteht. Der Assistent hält es nur im Speicher und sagt Ihnen, wann Sie es widerrufen können.';

  @override
  String get instanceTokenRefused =>
      'Supabase hat das Token abgelehnt. Erstellen Sie eines unter Account → Access Tokens und fügen Sie es vollständig ein.';

  @override
  String get instanceTurnOff => 'Ausschalten';

  @override
  String get instanceTurnOn => 'Für alle Arbeitsbereiche einschalten';

  @override
  String get instanceTurnOnConfirm =>
      'Assistenten werden in jedem Arbeitsbereich nutzbar, der sie anbietet. Sie können sie jederzeit wieder ausschalten.';

  @override
  String get instanceTurnOnNeedsProbe =>
      'Der Assistenten-Endpunkt ist nicht bestätigt. Prüfen Sie zuerst den Server.';

  @override
  String get instanceUseExisting => 'Oder ein bestehendes Projekt verwenden:';

  @override
  String get instanceUseHere => 'Diese Instanz auf diesem Gerät verwenden';

  @override
  String get instanceWizardTitle => 'Neue Instanz anlegen';

  @override
  String get instanceYou => 'Sie';

  @override
  String get instanceYouAreDelegate =>
      'Sie sind Stellvertreter des Instanzeigentümers.';

  @override
  String get instanceYouAreOwner => 'Sie sind der Instanzeigentümer.';

  @override
  String invitationAlreadyMember(String workspace) {
    return 'Sie sind bereits Mitglied von $workspace.';
  }

  @override
  String get invitationApprovalRequired =>
      'Ein Administrator gibt neue Mitglieder frei, bevor sich der Bereich öffnet.';

  @override
  String get invitationApprovalUnknown =>
      'Ob ein Administrator freigeben muss, ist nicht bekannt.';

  @override
  String get invitationBadServer =>
      'Der Server in dieser Einladung ist ungültig. Bitten Sie um eine neue Einladung.';

  @override
  String get invitationChangeAccount => 'Konto wechseln';

  @override
  String get invitationCheckAnother => 'Andere Einladung verwenden';

  @override
  String get invitationCheckFailed =>
      'Die Einladung konnte nicht geprüft werden — Status nicht aktualisiert. Nichts wurde geändert; versuchen Sie es erneut.';

  @override
  String get invitationContinue => 'Weiter zu diesem Bereich';

  @override
  String invitationDefaultTemplate(
    String firstName,
    String workspaceName,
    String workspaceId,
    String downloadUrl,
    String inviteLink,
  ) {
    return 'Hallo$firstName! Sie sind eingeladen, unserem Coworking-Space „$workspaceName“ auf DesKilo beizutreten.\n\n1. Laden Sie die App herunter:\n$downloadUrl\n\n2. Öffnen Sie sie, legen Sie Ihr Konto an (E-Mail + Passwort) und melden Sie sich an.\n\n3. Wählen Sie „Workspace beitreten“ und geben Sie Ihren persönlichen Einladungscode ein:\n$workspaceId\n(Einladungslink: $inviteLink)\n\nTipp: Kopieren Sie einfach diese ganze Nachricht und fügen Sie sie in der App ein — der Code wird automatisch erkannt. Ihr Code ist persönlich, einmalig nutzbar und 14 Tage gültig.\n\nBis bald bei $workspaceName!';
  }

  @override
  String get invitationEnvironmentProduction => 'Produktivbereich';

  @override
  String get invitationEnvironmentTest => 'Testbereich';

  @override
  String get invitationExpired =>
      'Diese Einladung ist abgelaufen. Bitten Sie die Person, die sie geschickt hat, um eine neue.';

  @override
  String invitationInvalid(String host) {
    return 'Kein Bereich auf $host kennt diese Einladung. Prüfen Sie sie oder bitten Sie die Organisation um ihren Server-Link.';
  }

  @override
  String get invitationJoinButton => 'Bereich beitreten';

  @override
  String get invitationJoinUnconfirmed =>
      'Das Ergebnis konnte nicht bestätigt werden. Treten Sie erneut bei, um es zu prüfen — die Einladung wird nicht doppelt verwendet.';

  @override
  String invitationJoiningAs(String account) {
    return 'Beitritt als $account';
  }

  @override
  String get invitationNewerVersion =>
      'Diese Einladung stammt aus einer neueren DesKilo-Version. Aktualisieren Sie die App und öffnen Sie sie dann erneut.';

  @override
  String invitationOtherServer(String host) {
    return 'Diese Einladung gehört zu einem anderen Server: $host.';
  }

  @override
  String get invitationPasteButton => 'Einfügen';

  @override
  String invitationPaused(String workspace) {
    return 'Ihre Mitgliedschaft in $workspace ist pausiert. Nur ein Administrator dort kann sie fortsetzen.';
  }

  @override
  String get invitationReviewButton => 'Einladung prüfen';

  @override
  String get invitationReviewTitle => 'Vor dem Beitritt prüfen';

  @override
  String get invitationRevoked =>
      'Dieser Bereichscode wurde ersetzt. Bitten Sie die Person, die ihn geschickt hat, um den aktuellen.';

  @override
  String get invitationRoleAdmin => 'Angebotene Rolle: Administrator';

  @override
  String get invitationRoleMember => 'Angebotene Rolle: Mitglied';

  @override
  String get invitationRoleUnknown => 'Angebotene Rolle: noch nicht bekannt';

  @override
  String invitationServerLabel(String label) {
    return 'Von der teilenden Person „$label“ genannt';
  }

  @override
  String invitationServerRow(String host) {
    return 'Server: $host';
  }

  @override
  String get invitationTemplateHelp =>
      'Wird gesendet, wenn Sie jemanden per WhatsApp, SMS oder Teilen einladen. Leer lassen für die eingebaute Nachricht in der gewählten Sprache. Verfügbare Tags:';

  @override
  String get invitationTemplateHint =>
      'Eigene Einladungsnachricht mit den Tags oben…';

  @override
  String get invitationTemplateLanguage => 'Sprache der Nachricht';

  @override
  String get invitationTemplateTitle => 'Einladungsnachricht';

  @override
  String invitationThisDevice(String host) {
    return 'Dieses Gerät nutzt $host. Eine Einladung wird nur auf ihrem eigenen Server geprüft.';
  }

  @override
  String get invitationUnknownAnswer =>
      'Der Server hat eine Antwort gegeben, die diese App-Version nicht lesen kann. Nichts wurde geändert.';

  @override
  String get invitationUseServer => 'Diesen Server verwenden';

  @override
  String get invitationWrongAccount =>
      'Diese Einladung wurde bereits von einem anderen Konto verwendet. Wenn sie für Sie war, melden Sie sich mit diesem Konto an.';

  @override
  String get inviteAdminExplainer =>
      'Dieser Code ist einmalig nutzbar: Er lässt EINE Person als Admin beitreten und verfällt dann. Geben Sie ihn nur der Person, für die er bestimmt ist.';

  @override
  String get inviteAdminNewCode => 'Neuer Code für Administrator:innen';

  @override
  String get inviteAlsoProdSubtitle =>
      'Die Person tritt dem Testraum in jedem Fall bei. Die Rolle muss den Produktionszugang trotzdem erlauben.';

  @override
  String get inviteAlsoProdTitle => 'Auch Zugang zur Produktion geben';

  @override
  String get inviteCreateFailed =>
      'Die Einladung konnte nicht erstellt werden. Prüfen Sie Ihre Verbindung und versuchen Sie es erneut.';

  @override
  String get inviteFirstNameLabel => 'Vorname (optional)';

  @override
  String get inviteLanguageLabel => 'Sprache der Nachricht';

  @override
  String get inviteLastNameLabel => 'Nachname (optional)';

  @override
  String get inviteOwnerNote =>
      'Es gibt keine Eigentümer-Einladung — nur ein Eigentümer kann Eigentum vergeben, unter Mitglieder & Tarife.';

  @override
  String get invitePhoneLabel => 'Telefon (optional, mit Ländervorwahl)';

  @override
  String get inviteRoleAdmin => 'Einladung als Administrator:in';

  @override
  String get inviteRoleMember => 'Mitglieder-Einladung';

  @override
  String get inviteRolesHint =>
      'Vergeben beim Beitritt, sobald die Mitgliedschaft aktiv ist.';

  @override
  String get inviteRolesTitle => 'Rollen bei der Ankunft';

  @override
  String get inviteSectionTitle => 'Jemanden einladen';

  @override
  String get inviteSendFailed =>
      'Die Sende-App ließ sich nicht öffnen. Die Nachricht wurde stattdessen kopiert.';

  @override
  String get inviteViaShare => 'Teilen…';

  @override
  String get inviteViaSms => 'SMS';

  @override
  String get inviteViaWhatsapp => 'WhatsApp';

  @override
  String get invoiceAccountingExport => 'Buchhaltungsexport';

  @override
  String get invoiceAccountingExportEmpty =>
      'Für diesen Zeitraum gibt es nichts zu exportieren.';

  @override
  String get invoiceAllCaughtUp => 'Alles erledigt — nichts zu berechnen.';

  @override
  String get invoiceAlreadyInvoiced =>
      'Dieser Monat ist für dieses Mitglied bereits berechnet.';

  @override
  String invoiceAnnexSummary(int movements, int checkIns) {
    return 'Anhang: $movements Bewegungen, $checkIns Check-ins';
  }

  @override
  String get invoiceBalance => 'Saldo';

  @override
  String get invoiceBuyerReference => 'Dienststellencode';

  @override
  String get invoiceBuyerReferenceHint =>
      'Öffentlicher Auftraggeber (Chorus Pro): der code service exécutant.';

  @override
  String invoiceCountShown(int count) {
    return '$count Rechnungen';
  }

  @override
  String get invoiceCreate => 'Neue Rechnung';

  @override
  String get invoiceDetailedToggle =>
      'Detaillierten Anhang aufnehmen (Check-ins, Services, Zahlungen)';

  @override
  String get invoiceDownload => 'PDF herunterladen';

  @override
  String get invoiceEInvoiceAction => 'E-Rechnung (XML)';

  @override
  String get invoiceEInvoiceBlockedTitle =>
      'Ein Validator würde diese Datei ablehnen:';

  @override
  String invoiceEInvoiceBusinessRoute(String channel, String format) {
    return 'Geschäftskunden: über $channel als $format übermitteln.';
  }

  @override
  String get invoiceEInvoiceDownload => 'E-Rechnung herunterladen (XML)';

  @override
  String get invoiceEInvoiceExplain =>
      'Die maschinenlesbare EN-16931-Rechnung — die Datei, die Finanzverwaltungen und Geschäftskunden verlangen.';

  @override
  String get invoiceEInvoiceFixIdentity =>
      'Rechtliche Identität vervollständigen';

  @override
  String invoiceEInvoiceFormatMismatch(String channel, String format) {
    return '$channel akzeptiert nur $format: Diese EN-16931-Datei dient für Peppol, öffentliche Auftraggeber und ausländische Kunden — den Rest konvertiert die Plattform.';
  }

  @override
  String get invoiceEInvoiceIncompleteTitle =>
      'Gültig, doch die strengen nationalen Profile wollen zusätzlich:';

  @override
  String invoiceEInvoicePublicRoute(String channel) {
    return 'Öffentliche Auftraggeber: $channel.';
  }

  @override
  String get invoiceEInvoiceReady => 'Bereit — diese Datei erfüllt EN 16931.';

  @override
  String get invoiceEInvoiceShare => 'E-Rechnung teilen (XML)';

  @override
  String get invoiceEInvoiceStaleIdentity =>
      'Ihre rechtliche Identität ist jetzt vollständig, diese Rechnung wurde aber vorher signiert und behält, womit sie ausgestellt wurde. Als fehlerhaft markieren und eine Ersatzrechnung ausstellen, damit sie die neue Identität trägt.';

  @override
  String get invoiceEInvoiceTransportAccredited =>
      'Eine zugelassene Plattform übermittelt die Rechnung und meldet die Daten an die Finanzverwaltung.';

  @override
  String get invoiceEInvoiceTransportBilateral =>
      'Kein Kanal ist vorgeschrieben: E-Mail, Portal oder Peppol — wie mit dem Kunden vereinbart.';

  @override
  String get invoiceEInvoiceTransportClearance =>
      'Die nationale Plattform erhält die Rechnung zuerst und leitet sie weiter — ein direkter Versand an den Kunden ist nicht möglich.';

  @override
  String get invoiceEInvoiceTransportPeppol =>
      'Ein Access Point liefert sie an den Kunden — keine staatliche Plattform dazwischen.';

  @override
  String get invoiceEssentialsRefused =>
      'Die Rechnung wurde nicht ausgestellt: Pflichtangaben fehlen.';

  @override
  String get invoiceExportAccountantCsv => 'Buchhaltungs-CSV';

  @override
  String get invoiceExportAuditTrail => 'Prüfpfad';

  @override
  String get invoiceExportBundle => 'Jahresarchiv (zip)';

  @override
  String get invoiceExportChoose => 'Buchhaltungs-Export';

  @override
  String get invoiceExportDatev => 'DATEV (Buchungsstapel)';

  @override
  String get invoiceExportFec => 'FEC (Frankreich, im Prüfungsfall verlangt)';

  @override
  String get invoiceExportSafT => 'SAF-T (XML, international)';

  @override
  String get invoiceExportSafTPt => 'SAF-T (Portugal)';

  @override
  String get invoiceExportSage => 'Sage 50 (Audit-Journal)';

  @override
  String get invoiceExternalIssuingTitle =>
      'Diese Rechnung außerhalb der App ausstellen';

  @override
  String get invoiceFacturXDownload => 'Factur-X (PDF) herunterladen';

  @override
  String get invoiceFacturXExplain =>
      'Eine Datei: die Rechnung für Menschen, mit dem maschinenlesbaren XML darin. Das erwarten die meisten Plattformen.';

  @override
  String get invoiceFacturXShare => 'Factur-X (PDF) teilen';

  @override
  String get invoiceFeatureDisabled =>
      'Diese Rechnungsart ist in diesem Workspace deaktiviert. Bestehende Rechnungen und Kontoauszüge bleiben verfügbar.';

  @override
  String get invoiceFilterAllMembers => 'Alle Mitglieder';

  @override
  String get invoiceFilterAllMonths => 'Alle Monate';

  @override
  String get invoiceFilterClear => 'Filter zurücksetzen';

  @override
  String get invoiceFilterMonthLabel => 'Monat';

  @override
  String get invoiceFilterNoMatch =>
      'Keine Rechnung entspricht diesen Filtern.';

  @override
  String get invoiceGapBuyerVatIdFormat =>
      'Die USt-IdNr. des Kunden hat nicht die Form ihres Landes — bitte prüfen.';

  @override
  String get invoiceGapCreditNoteWithPayments =>
      'Diese Gutschrift verrechnet auch Zahlungen, was eine EN-16931-Gutschrift nicht ausdrücken kann. Stellen Sie die Gutschrift als eigenes Dokument aus.';

  @override
  String get invoiceGapMissingBuyerCountry => 'Das Land des Kunden fehlt.';

  @override
  String get invoiceGapMissingBuyerVatId =>
      'Die USt-IdNr. des Kunden fehlt — eine Reverse-Charge-Rechnung muss sie nennen.';

  @override
  String get invoiceGapMissingExemptionReason =>
      'Der Grund für die Steuerbefreiung fehlt.';

  @override
  String get invoiceGapMissingLegalId =>
      'Die Registernummer fehlt (SIREN, HRB, CIF…) — nichts identifiziert Sie auf der Rechnung.';

  @override
  String get invoiceGapMissingSellerCity => 'die Stadt der Workspace-Adresse';

  @override
  String get invoiceGapMissingSellerCountry => 'Das Land des Workspace fehlt.';

  @override
  String get invoiceGapMissingSellerPostalCode =>
      'die Postleitzahl der Workspace-Adresse';

  @override
  String get invoiceGapMissingVatId =>
      'Die Umsatzsteuer-Identifikationsnummer fehlt — ein steuerbefreiter Verkäufer muss sie angeben.';

  @override
  String get invoiceGapNoChargeLines =>
      'Diese Rechnung hat keine Belastungsposition — ihr Monat war vollständig durch Zahlungen gedeckt, es gibt nichts zu übermitteln.';

  @override
  String get invoiceGapPublicSectorRefs =>
      'Für eine öffentliche Plattform bestimmt, ohne Auftragsnummer und ohne Dienststellencode — Chorus Pro lehnt die meisten Einreichungen ohne eines von beiden ab.';

  @override
  String get invoiceGapVatNotSupported =>
      'Der Space verlangt Mehrwertsteuer, diese Rechnung trägt aber keinen Satz — Sätze anlegen und die Rechnung neu ausstellen.';

  @override
  String invoiceHeldNote(String reason) {
    return 'Mahnungen angehalten: $reason';
  }

  @override
  String get invoiceHoldAction => 'Mahnungen anhalten';

  @override
  String get invoiceHoldConfirm => 'Anhalten';

  @override
  String get invoiceHoldExplain =>
      'Für diese Rechnung wird keine Mahnung versendet, weder von Hand noch automatisch, bis der Mahnstopp aufgehoben ist.';

  @override
  String get invoiceHoldFailed =>
      'Der Mahnstopp konnte nicht geändert werden. Bitte versuchen Sie es erneut.';

  @override
  String get invoiceHoldNote => 'Notiz (optional)';

  @override
  String get invoiceHoldPlaced =>
      'Die Mahnungen für diese Rechnung sind angehalten.';

  @override
  String get invoiceHoldReasonDispute => 'Das Mitglied bestreitet sie';

  @override
  String get invoiceHoldReasonIdentity =>
      'Falsche Person oder Identitätsfehler';

  @override
  String get invoiceHoldReasonInsolvency => 'Insolvenzverfahren';

  @override
  String get invoiceHoldReasonOther => 'Ein anderer Grund';

  @override
  String get invoiceHoldReleaseAction => 'Mahnstopp aufheben';

  @override
  String get invoiceHoldReleased =>
      'Die Mahnungen für diese Rechnung können fortgesetzt werden.';

  @override
  String get invoiceHoldTitle => 'Warum die Mahnungen anhalten?';

  @override
  String get invoiceIntegrityAltered => 'Seit Ausstellung verändert';

  @override
  String get invoiceIntegrityUnverifiable =>
      'Vor den Integritätsprüfungen ausgestellt';

  @override
  String get invoiceIntegrityVerified => 'Integrität geprüft';

  @override
  String get invoiceIssue => 'Rechnung ausstellen';

  @override
  String get invoiceIssueAll => 'Alle berechnen';

  @override
  String invoiceIssueAllConfirm(int count, String month, String total) {
    return '$count Rechnungen für $month über insgesamt $total ausstellen? Eine ausgestellte Rechnung lässt sich nicht mehr ändern — ein Fehler wird durch eine Ersatzrechnung korrigiert.';
  }

  @override
  String get invoiceIssueOne => 'Berechnen';

  @override
  String get invoiceIssued => 'Rechnung ausgestellt.';

  @override
  String invoiceIssuedCount(int count) {
    return '$count Rechnungen ausgestellt.';
  }

  @override
  String invoiceIssuedPartial(int issued, int failed) {
    return '$issued ausgestellt, $failed fehlgeschlagen.';
  }

  @override
  String get invoiceIssuingUnavailable => 'Rechnungserstellung nicht verfügbar';

  @override
  String get invoiceKindFull => 'Ganzer Monat';

  @override
  String get invoiceKindSettlement => 'Zusammengefasste Rechnungen';

  @override
  String get invoiceKindSubscription => 'Abo, im Voraus';

  @override
  String get invoiceKindUsage => 'Zusätze des Monats';

  @override
  String get invoiceLegalAssociationReasonHint =>
      'z. B. „TVA non applicable, art. 293 B du CGI“ — oder „Exonération de TVA, art. 261, 7-1° du CGI“ für Leistungen an Mitglieder';

  @override
  String get invoiceLegalCustomerCapacityField => 'Standard-Kundeneigenschaft';

  @override
  String get invoiceLegalCustomerCapacityHint =>
      'Entscheidet, welche Zahlungsklauseln eine Rechnung druckt. Die gesetzlichen Vorgaben für Verzugszinsen, Beitreibungspauschale und Skonto gelten nur für Unternehmer als Kunden; ein Verbraucher erhält nie die Beitreibungspauschale. Die eigene Angabe eines Mitglieds hat Vorrang vor dieser Vorgabe. Jede Rechnung behält die Klauseln, mit denen sie ausgestellt wurde.';

  @override
  String get invoiceLegalEscompteDefault =>
      'Kein Skonto bei vorzeitiger Zahlung.';

  @override
  String get invoiceLegalEscompteField => 'Skonto';

  @override
  String get invoiceLegalFormField => 'Rechtsform & Kapital';

  @override
  String get invoiceLegalFormHint => 'z. B. SARL au capital de 7 500 €';

  @override
  String get invoiceLegalFormHintAssociation =>
      'z. B. Association loi 1901 / e. V.';

  @override
  String get invoiceLegalInsuranceField => 'Berufshaftpflicht';

  @override
  String get invoiceLegalIntro =>
      'Die Pflichtangaben auf Rechnungen und Mahnungen. Leere Zahlungsklauseln verwenden die gesetzlichen Standardtexte.';

  @override
  String get invoiceLegalKindAssociation => 'Verein (gemeinnützig)';

  @override
  String get invoiceLegalKindCompany => 'Unternehmen';

  @override
  String get invoiceLegalKindField => 'Organisationsform';

  @override
  String get invoiceLegalLatePenaltyDefault =>
      'Verzugszinsen: dreifacher gesetzlicher Zinssatz.';

  @override
  String get invoiceLegalLatePenaltyField => 'Verzugszinsen';

  @override
  String get invoiceLegalPaymentTermsDefault => 'Zahlbar sofort nach Erhalt.';

  @override
  String get invoiceLegalPaymentTermsField => 'Zahlungsbedingungen';

  @override
  String get invoiceLegalRecoveryDefault =>
      'Pauschale für Beitreibungskosten: 40 €.';

  @override
  String get invoiceLegalRecoveryField => 'Pauschale für Beitreibungskosten';

  @override
  String get invoiceLegalRegistrationField => 'Handelsregister';

  @override
  String get invoiceLegalRegistrationHint =>
      'z. B. RCS Saint-Brieuc 680 357 910';

  @override
  String get invoiceLegalRegistrationHintAssociation =>
      'z. B. RNA W123456789 · SIRET falls vergeben';

  @override
  String get invoiceLegalSection => 'Rechnungsangaben';

  @override
  String get invoiceLegalSpecialField => 'Besondere Angaben';

  @override
  String get invoiceLineAdjustment => 'Anpassung';

  @override
  String get invoiceMatchAction => 'Als bezahlt markieren';

  @override
  String get invoiceMatchCreditNote =>
      'Gutschrift über den Überschuss erstellen';

  @override
  String get invoiceMatchForce => 'Trotzdem akzeptieren (mit Begründung)';

  @override
  String get invoiceMatchNoPayments =>
      'Keine registrierte Zahlung zum Abgleich — zuerst erfassen oder bestätigen.';

  @override
  String get invoiceMatchNoteLabel => 'Notiz';

  @override
  String get invoiceMatchNoteRequired => 'Eine Notiz ist erforderlich.';

  @override
  String invoiceMatchOver(String excess) {
    return 'Das Mitglied hat $excess mehr gezahlt.';
  }

  @override
  String get invoiceMatchPendingBadge => 'Wartet auf Validierung';

  @override
  String get invoiceMatchPickPayment => 'Registrierte Zahlung auswählen';

  @override
  String invoiceMatchSummary(String amount, String date) {
    return 'Bezahlt $amount am $date';
  }

  @override
  String invoiceMatchUnder(String missing) {
    return 'Das Mitglied hat $missing weniger gezahlt — Akzeptieren erfordert eine Notiz.';
  }

  @override
  String get invoiceMatched => 'Rechnung abgeglichen.';

  @override
  String get invoiceMatchedBadge => 'Bezahlt';

  @override
  String get invoiceMaturityReview =>
      'Für diese Rechnung wurde keine vereinbarte Zahlungsfrist erfasst: Es werden keine automatischen Mahnungen versendet, bis Sie sie prüfen.';

  @override
  String get invoiceMemberLabel => 'Mitglied';

  @override
  String get invoiceMissingBuyerAddress =>
      'Die Postanschrift des Mitglieds (bei Unternehmen erforderlich)';

  @override
  String get invoiceMissingBuyerName => 'Der Name oder die Firma des Mitglieds';

  @override
  String get invoiceMissingBuyerVatId =>
      'Die USt-IdNr. des Mitglieds (für das Reverse-Charge-Verfahren erforderlich)';

  @override
  String get invoiceMissingExemptionReason =>
      'Die Rechtsgrundlage der Umsatzsteuerbefreiung';

  @override
  String get invoiceMissingSellerAddress =>
      'Die Postanschrift des Arbeitsbereichs (Straße oder Ort)';

  @override
  String get invoiceMissingSellerCountry =>
      'Das Land des Arbeitsbereichs muss Frankreich oder Deutschland sein, um hier auszustellen — andere Länder werden außerhalb der App ausgestellt';

  @override
  String get invoiceMissingSellerVatId =>
      'Die Umsatzsteuer-Identifikationsnummer des Arbeitsbereichs';

  @override
  String get invoiceMissingTitle => 'Vor der Ausstellung bitte ergänzen';

  @override
  String get invoiceMissingVatNotRegistered =>
      'Keine MwSt. auf den Positionen: der Raum berechnet keine MwSt., aber für das Abonnement oder ein Zubehör ist ein Satz eingestellt';

  @override
  String get invoiceMissingVatRate =>
      'Ein gültiger Steuersatz für den Standardsatz des Arbeitsbereichs (sonst würde 0 % berechnet)';

  @override
  String get invoiceMissingVatTreatment =>
      'Grenzüberschreitende Rechnungen sowie Rechnungen mit Reverse Charge, Ausfuhr oder Steuerbefreiung müssen mit Ihrer Buchhaltung außerhalb der App geprüft und ausgestellt werden. Kontoauszüge bleiben verfügbar.';

  @override
  String get invoiceMissingVatZeroLine =>
      'Ein MwSt.-Satz für jede Leistung: eine Leistung wird mit 0 % berechnet, ohne Export, Befreiung oder Reverse Charge als Grund';

  @override
  String get invoiceNoOpen => 'Keine offenen Rechnungen.';

  @override
  String get invoiceNothingToInvoice =>
      'Für diesen Monat wurde nichts erfasst — nichts zu berechnen.';

  @override
  String invoiceOpenAge(int days) {
    return '$days Tage';
  }

  @override
  String get invoicePdfActivity => 'Buchungen & Zahlungen';

  @override
  String get invoicePdfAnnex => 'Anhang — Details';

  @override
  String get invoicePdfAttendance => 'Check-ins';

  @override
  String get invoicePdfBilledTo => 'Rechnung an';

  @override
  String get invoicePdfBuyerReference => 'Dienststelle';

  @override
  String get invoicePdfCharges => 'Posten';

  @override
  String get invoicePdfCopy => 'Kopie';

  @override
  String get invoicePdfCreditNote => 'Gutschrift';

  @override
  String get invoicePdfDescription => 'Beschreibung';

  @override
  String get invoicePdfDueOn => 'Fällig am';

  @override
  String get invoicePdfIssuedBy => 'Ausgestellt von';

  @override
  String get invoicePdfIssuedOn => 'Ausgestellt am';

  @override
  String get invoicePdfPage => 'Seite';

  @override
  String get invoicePdfPayments => 'Zahlungen';

  @override
  String get invoicePdfProforma => 'Proforma';

  @override
  String get invoicePdfPurchaseOrder => 'Auftragsreferenz';

  @override
  String get invoicePdfReplaces => 'Ersetzt';

  @override
  String get invoicePdfReserved => 'reserviert';

  @override
  String invoicePdfSettledIn(String number) {
    return 'Zusammengefasst in $number';
  }

  @override
  String get invoicePdfSignature => 'Digitale Signatur (SHA-256)';

  @override
  String get invoicePdfTitle => 'Rechnung';

  @override
  String get invoicePdfVoided => 'FEHLERHAFT — storniert am';

  @override
  String get invoicePickMember =>
      'Ein Mitglied wählen, um zu sehen, was dieser Monat erfasst hat.';

  @override
  String get invoiceProformaAction => 'Proforma-Rechnung';

  @override
  String get invoiceProformaNothing =>
      'Für diesen Monat wurde nichts erfasst — keine Proforma zu senden.';

  @override
  String get invoiceProformaShared => 'Proforma geteilt.';

  @override
  String get invoicePublicBuyer => 'Öffentlicher Auftraggeber (Chorus Pro)';

  @override
  String get invoicePurchaseOrder => 'Auftragsnummer';

  @override
  String get invoicePurchaseOrderHint =>
      'Öffentlicher Auftraggeber (Chorus Pro): die numéro d\'engagement.';

  @override
  String get invoiceRefundButton => 'Erstattung erfassen';

  @override
  String invoiceRefundExplain(String amount) {
    return 'Diese Gutschrift bedeutet: der ARBEITSBEREICH schuldet dem Mitglied $amount. Erfassen Sie die ausgezahlte Erstattung — der Betrag wird gegen das Mitgliedskonto gebucht und das Dokument schließt als Erstattet.';
  }

  @override
  String get invoiceRefundLabel => 'Zu erstatten';

  @override
  String get invoiceRefunded => 'Erstattung erfasst.';

  @override
  String get invoiceRegisterAllYears => 'Alle Jahre';

  @override
  String get invoiceRegisterAmount => 'Betrag';

  @override
  String get invoiceRegisterDate => 'Datum';

  @override
  String get invoiceRegisterName => 'Name';

  @override
  String get invoiceRegisterTitle => 'Rechnungsregister';

  @override
  String get invoiceRegisterTotal => 'Gesamt';

  @override
  String get invoiceRegisterYear => 'Jahr';

  @override
  String get invoiceRemainingLabel => 'Restbetrag';

  @override
  String get invoiceRemindAction => 'Zahlungserinnerung senden';

  @override
  String get invoiceReminded => 'Erinnerung erfasst.';

  @override
  String invoiceRemindedBadge(int count) {
    return 'Erinnert ×$count';
  }

  @override
  String invoiceRemindedLast(String date) {
    return 'letzte Mahnung $date';
  }

  @override
  String invoiceReminderMessage(String number, String amount) {
    return 'Freundliche Erinnerung: Rechnung $number — offener Saldo $amount.';
  }

  @override
  String get invoiceReminderNotSent =>
      'Es wurde nichts versendet, also auch nichts vermerkt.';

  @override
  String get invoiceReplaceAction => 'Ersatzrechnung ausstellen';

  @override
  String invoiceReplacedBy(String number) {
    return 'Ersetzt durch $number';
  }

  @override
  String get invoiceRunningMonth =>
      'Dieser Monat läuft noch — seine Positionen können sich noch ändern, und ein Monat lässt sich nur einmal abrechnen.';

  @override
  String get invoiceSendAccepted =>
      'Gesendet — die Plattform hat sie angenommen.';

  @override
  String invoiceSendAcceptedTest(String env) {
    return 'Testversand angenommen ($env).';
  }

  @override
  String get invoiceSendAction => 'An die staatliche Plattform senden';

  @override
  String get invoiceSendCustomerAccepted =>
      'Gesendet — der Dienst des Kunden hat sie angenommen.';

  @override
  String get invoiceSendCustomerAction => 'An den Dienst des Kunden senden';

  @override
  String get invoiceSendRejected => 'Die Plattform hat sie abgelehnt.';

  @override
  String get invoiceSendStatusAccepted => 'angenommen';

  @override
  String get invoiceSendStatusFailed => 'nicht übermittelt';

  @override
  String get invoiceSendStatusRejected => 'abgelehnt';

  @override
  String invoiceSentOn(String date, String status) {
    return 'Gesendet am $date · $status';
  }

  @override
  String get invoiceSentTestChip => 'Test';

  @override
  String get invoiceShare => 'PDF teilen';

  @override
  String get invoiceShowCancelled => 'Stornierte anzeigen';

  @override
  String get invoiceSortByMember => 'Nach Mitglied';

  @override
  String get invoiceSortByMonth => 'Nach Monat';

  @override
  String get invoiceSortNewest => 'Neueste zuerst';

  @override
  String get invoiceSortTooltip => 'Sortieren';

  @override
  String get invoiceStatusOpen => 'Offen';

  @override
  String get invoiceStatusPartiallyPaid => 'Teilweise bezahlt';

  @override
  String get invoiceStatusRefunded => 'Erstattet';

  @override
  String get invoiceStatusRemainderCancelled =>
      'Teilweise bezahlt · Restbetrag storniert';

  @override
  String invoiceSummaryOpen(int count, String amount) {
    return '$count offen · $amount ausstehend';
  }

  @override
  String invoiceSummaryToInvoice(int count) {
    return '$count zu berechnen';
  }

  @override
  String invoiceSummaryToRefund(int count, String amount) {
    return '$count zu erstatten · $amount';
  }

  @override
  String get invoiceTabArchive => 'Archiv';

  @override
  String get invoiceTabOpen => 'Offen';

  @override
  String get invoiceTabToInvoice => 'Zu berechnen';

  @override
  String get invoiceTemplateBodyLabel => 'Rumpfband (die Rechnungszeilen)';

  @override
  String get invoiceTemplateDocInvoice => 'Rechnung';

  @override
  String invoiceTemplateDocReminder(int level) {
    return 'Mahnung $level';
  }

  @override
  String get invoiceTemplateDocStatement => 'Abrechnung';

  @override
  String get invoiceTemplateDownload => 'PDF herunterladen';

  @override
  String get invoiceTemplateFooterLabel =>
      'Fußtext (unter den Summen — Zahlungsbedingungen, Pflichtangaben)';

  @override
  String get invoiceTemplateHeaderLabel => 'Kopfband';

  @override
  String get invoiceTemplateHint =>
      'Drei Berichtsbänder auf dem PDF — das E-Rechnungs-XML bleibt unangetastet. Liquid-Bedingungen und -Schleifen, dann Zeilen-Markup:';

  @override
  String get invoiceTemplateIntroLabel =>
      'Einleitung (über dem Empfängerblock)';

  @override
  String get invoiceTemplateNoPreview =>
      'Stellen Sie zuerst eine Rechnung aus — die Vorschau rendert die neueste.';

  @override
  String get invoiceTemplatePresets => 'Vorlagen';

  @override
  String get invoiceTemplatePreview => 'Vorschau';

  @override
  String get invoiceTemplateQuickPreview => 'Schnellvorschau';

  @override
  String get invoiceTemplateReset => 'Auf Standard zurücksetzen';

  @override
  String get invoiceTemplateSaved => 'Rechnungsvorlage gespeichert.';

  @override
  String get invoiceTemplateShare => 'PDF teilen';

  @override
  String get invoiceTemplateTitle => 'Rechnungs-PDF-Vorlage';

  @override
  String get invoiceVoidAction => 'Als fehlerhaft markieren';

  @override
  String invoiceVoidConfirm(String number) {
    return 'Rechnung $number als fehlerhaft markieren? Das kann nicht rückgängig gemacht werden.';
  }

  @override
  String get invoiceVoided => 'Rechnung als fehlerhaft markiert.';

  @override
  String get invoiceVoidedChip => 'Fehlerhaft';

  @override
  String get invoiceWizardAction => 'Monatsabschluss-Assistent';

  @override
  String get invoiceWriteoffButton => 'Restbetrag stornieren';

  @override
  String get invoiceWriteoffExplain =>
      'Der offene Restbetrag dieser Rechnung wird storniert und die Rechnung als teilweise bezahlt archiviert — sobald die Validierung bestätigt. Bis dahin bleibt sie offen und geschuldet.';

  @override
  String get invoiceWriteoffRequested =>
      'Stornierung beantragt — wartet auf Validierung.';

  @override
  String get invoicesEmpty => 'Noch keine Rechnungen.';

  @override
  String get invoicesManage => 'Rechnungen verwalten';

  @override
  String get invoicesTitle => 'Rechnungen';

  @override
  String get invoicingBanner =>
      'Sie stellen Rechnungen für den gesamten Arbeitsbereich aus und mahnen sie an. Ihre eigenen Rechnungen und Zahlungen finden Sie unter Ich › Finanzen.';

  @override
  String get invoicingHubTitle => 'Rechnungsstellung';

  @override
  String get invoicingMyFinances => 'Meine Finanzen';

  @override
  String get invoicingTools => 'Werkzeuge der Rechnungsstellung';

  @override
  String journeyClosedPaid(String date) {
    return 'Bezahlt am $date — abgeschlossen';
  }

  @override
  String journeyClosedRefunded(String date) {
    return 'Erstattet am $date — abgeschlossen';
  }

  @override
  String journeyClosedRemainder(String date) {
    return 'Abgeschlossen — Restbetrag am $date ausgebucht';
  }

  @override
  String journeyClosedReplaced(String number) {
    return 'Storniert — ersetzt durch $number';
  }

  @override
  String get journeyClosedSettled =>
      'In eine andere Rechnung zusammengefasst — diese wird geschuldet und angemahnt';

  @override
  String get journeyHowButton => 'So funktioniert es';

  @override
  String get journeyHowClosedMember =>
      'Der Monat gilt als beglichen und die Rechnung bleibt für immer lesbar: Schnellansicht, PDF, Teilen.';

  @override
  String get journeyHowClosedWorkspace =>
      'Bezahlt, Restbetrag ausgebucht oder erstattet: die Rechnung wandert ins Archiv. Eine falsche Rechnung wird als fehlerhaft markiert und ersetzt — vor der Zahlung, nie danach.';

  @override
  String get journeyHowConfirmationMember =>
      'Nichts zu tun — außer der Space hat die Zahlung für das Mitglied erfasst: dann bestätigt es sie unter Ereignisse.';

  @override
  String get journeyHowConfirmationWorkspace =>
      'Ein anderer Admin bestätigt die gemeldete Zahlung; der Aussteller ordnet die verbuchte Zahlung dann der Rechnung zu (Als bezahlt markieren) — eine Validierungsregel kann die Zuordnung den Prüfern übergeben. Zu viel gezahlt? Eine Gutschrift. Zu wenig? Teilweise bezahlt, der Rest bleibt geschuldet bis zur Zahlung oder Ausbuchung.';

  @override
  String get journeyHowIntro =>
      'Vier Schritte, für jede Rechnung dieselben. Jeder sagt, wer am Zug ist.';

  @override
  String get journeyHowIssuedMember =>
      'Findet sie in der Ansicht Rechnungen: Positionen, Saldo, Fälligkeit.';

  @override
  String get journeyHowIssuedWorkspace =>
      'Stellt die Rechnung aus den erfassten Monatsdaten aus — nummeriert, signiert, unveränderlich — und teilt das PDF oder sendet die E-Rechnung.';

  @override
  String get journeyHowMemberLabel => 'Mitglied';

  @override
  String get journeyHowPaymentMember =>
      'Zahlt online (sofort beglichen) oder per Überweisung und erfasst dann die Zahlung, damit der Space Bescheid weiß.';

  @override
  String get journeyHowPaymentWorkspace =>
      'Wartet auf das Geld. Nach der Frist sendet er die konfigurierten Mahnstufen — von Hand oder automatisch.';

  @override
  String get journeyHowTitle => 'So funktioniert die Fakturierung';

  @override
  String get journeyHowWorkspaceLabel => 'Space';

  @override
  String journeyIssuerAdminConfirms(String name, String amount) {
    return '$name hat eine Zahlung von $amount gemeldet — ein anderer Admin bestätigt sie unter Ereignisse';
  }

  @override
  String journeyIssuerMatches(String amount) {
    return 'Eine Zahlung von $amount ist verbucht — ordnen Sie sie dieser Rechnung zu';
  }

  @override
  String journeyIssuerMemberConfirms(String name, String amount) {
    return 'Eine Zahlung von $amount wurde erfasst — $name bestätigt sie unter Ereignisse';
  }

  @override
  String journeyIssuerMemberPays(String name, String amount, String date) {
    return 'Warten auf die Zahlung von $name: $amount — fällig $date';
  }

  @override
  String journeyIssuerMemberPaysOverdue(String name, String amount, int days) {
    return '$name schuldet $amount — $days Tage überfällig';
  }

  @override
  String journeyIssuerMemberPaysRemainder(String name, String amount) {
    return '$name schuldet nach einer Teilzahlung noch $amount';
  }

  @override
  String journeyIssuerRefunds(String name, String amount) {
    return 'Gutschrift — $amount an $name erstatten und erfassen';
  }

  @override
  String get journeyIssuerReplaces => 'Storniert — Ersatzrechnung ausstellen';

  @override
  String journeyMemberConfirms(String amount) {
    return 'Sie sind dran: die für Sie erfasste Zahlung von $amount unter Ereignisse bestätigen';
  }

  @override
  String journeyMemberDeclared(String amount) {
    return 'Sie haben $amount gemeldet — der Space bestätigt es';
  }

  @override
  String journeyMemberPays(String amount, String date) {
    return 'Sie sind dran: $amount bis $date zahlen';
  }

  @override
  String journeyMemberPaysOverdue(String amount, int days) {
    return 'Sie sind dran: $amount zahlen — $days Tage überfällig';
  }

  @override
  String journeyMemberPaysRemainder(String amount) {
    return 'Sie sind dran: den Restbetrag von $amount zahlen';
  }

  @override
  String journeyMemberRefund(String amount) {
    return 'Der Space schuldet Ihnen $amount — nichts zu zahlen';
  }

  @override
  String journeyMemberRegistered(String amount) {
    return 'Ihre Zahlung von $amount ist verbucht — der Space ordnet sie dieser Rechnung zu';
  }

  @override
  String get journeyMemberReplaces => 'Storniert — eine Ersatzrechnung folgt';

  @override
  String get journeyMemberValidators =>
      'Zahlung zugeordnet — Validierung steht aus';

  @override
  String get journeyMemberWriteoff =>
      'Der Space hat die Ausbuchung des Restbetrags beantragt — Validierung steht aus';

  @override
  String journeyOutstanding(String amount) {
    return '$amount offen';
  }

  @override
  String journeyOverdueCount(int count) {
    return '$count überfällig';
  }

  @override
  String get journeyPrimaryConfirmInEvents => 'Ereignisse öffnen';

  @override
  String journeyPrimaryRemind(int level) {
    return 'Mahnung $level senden';
  }

  @override
  String get journeyStageClosed => 'Abgeschlossen';

  @override
  String get journeyStageCollect => 'Einzuziehen';

  @override
  String get journeyStageConfirm => 'Zu bestätigen';

  @override
  String get journeyStageIssue => 'Auszustellen';

  @override
  String get journeyStageStripLabel =>
      'Der Fakturierungsprozess: ausstellen, einziehen, bestätigen, abschließen';

  @override
  String get journeyStepClosed => 'Abgeschlossen';

  @override
  String get journeyStepConfirmation => 'Bestätigung';

  @override
  String get journeyStepIssued => 'Ausgestellt';

  @override
  String get journeyStepPayment => 'Zahlung';

  @override
  String get journeyTimelineTitle => 'Verlauf';

  @override
  String get journeyValidatorsMatch =>
      'Zahlung zugeordnet — Entscheidung der Prüfer steht aus';

  @override
  String get journeyValidatorsWriteoff =>
      'Ausbuchung des Restbetrags beantragt — Prüfer entscheiden';

  @override
  String get kioskBadgeConfirm => 'Bestätigen';

  @override
  String get kioskBadgeFieldLabel => 'Badge-Code';

  @override
  String get kioskBadgeHint =>
      'Scannen Sie den QR Ihres Badges oder tippen Sie seinen Code ein.';

  @override
  String get kioskBadgeHintNfc =>
      'Karte auflegen, QR scannen oder Code eintippen.';

  @override
  String get kioskBadgeRejected => 'Badge nicht erkannt.';

  @override
  String kioskBasis(String granularity, String hours) {
    return 'Regel: $granularity · heute $hours';
  }

  @override
  String kioskBlockedContactHint(String name) {
    return 'Belegt von $name — Sie können der Person über die App auf Ihrem Handy schreiben.';
  }

  @override
  String get kioskCheckIn => 'Einchecken';

  @override
  String get kioskCheckInRightAway => 'Sofort einchecken';

  @override
  String get kioskCheckInRightAwayHint =>
      'Sie sind da — die Reservierung startet eingecheckt.';

  @override
  String get kioskCheckOut => 'Auschecken';

  @override
  String get kioskClosedToday =>
      'Der Workspace ist heute geschlossen — Check-in und Reservierungen sind nicht möglich.';

  @override
  String get kioskConfirmAction => 'Bestätigen';

  @override
  String get kioskDone => 'Fertig — alles erledigt.';

  @override
  String get kioskGateBody =>
      'Dieses Konto ist als Kiosk des Workspace eingerichtet. Im Kiosk-Modus zeigt das Tablet nur den Raumplan für das Einchecken per Badge — sonst lässt sich nichts öffnen. Zum Verlassen des Kiosk-Modus das Tablet neu starten.';

  @override
  String get kioskGateReject => 'Jetzt nicht — App normal öffnen';

  @override
  String get kioskGateStart => 'Kiosk-Modus starten';

  @override
  String get kioskGateTitle => 'Kiosk-Modus starten?';

  @override
  String get kioskLevelButton => 'Diese Etage';

  @override
  String get kioskNfcFailed =>
      'Der RFID-Leser ist nicht gestartet — App neu starten und erneut versuchen.';

  @override
  String get kioskNfcOff =>
      'NFC ist in den Android-Einstellungen dieses Tablets ausgeschaltet — zum Lesen von RFID-Karten einschalten.';

  @override
  String get kioskNfcUnsupported =>
      'Dieses Tablet hat keinen NFC-Leser — stattdessen den QR-Badge scannen.';

  @override
  String get kioskNotCheckedIn =>
      'Kein aktiver Check-in gefunden — der Plan hat sich womöglich gerade aktualisiert.';

  @override
  String get kioskPeriodCheckInHint =>
      'Bis wann bleiben Sie? Das Einchecken beginnt jetzt.';

  @override
  String get kioskPeriodReserveHint => 'Wählen Sie den Zeitraum — nur heute.';

  @override
  String get kioskPresentBadge => 'Badge vorzeigen';

  @override
  String get kioskPresentBadgeNext => 'Badge vorzeigen';

  @override
  String get kioskRejectAction => 'Ablehnen';

  @override
  String get kioskReserve => 'Reservieren';

  @override
  String get kioskReserveAndCheckIn => 'Reservieren & einchecken';

  @override
  String get kioskRestOfDay => 'Rest des Tages';

  @override
  String get kioskRevertDesc =>
      'Dieses Profil ist als Kiosk des Workspace eingerichtet. Als reguläres Mitglied zurücksetzen, damit die Kiosk-Frage beim Start nicht mehr erscheint.';

  @override
  String get kioskRevertDone =>
      'Dieses Profil ist wieder ein reguläres Mitglied.';

  @override
  String get kioskRevertTitle => 'Kiosk-Gerät';

  @override
  String get kioskScanQr => 'QR-Badge scannen';

  @override
  String get kioskTapHint => 'Tippen Sie auf einen Platz zum Einchecken';

  @override
  String get languageNameCS => 'Tschechisch';

  @override
  String get languageNameDA => 'Dänisch';

  @override
  String get languageNameDE => 'Deutsch';

  @override
  String get languageNameEL => 'Griechisch';

  @override
  String get languageNameEN => 'Englisch';

  @override
  String get languageNameES => 'Spanisch';

  @override
  String get languageNameFI => 'Finnisch';

  @override
  String get languageNameFR => 'Französisch';

  @override
  String get languageNameHU => 'Ungarisch';

  @override
  String get languageNameIT => 'Italienisch';

  @override
  String get languageNameJA => 'Japanisch';

  @override
  String get languageNameNB => 'Norwegisch';

  @override
  String get languageNameNL => 'Niederländisch';

  @override
  String get languageNamePL => 'Polnisch';

  @override
  String get languageNamePT => 'Portugiesisch';

  @override
  String get languageNameRO => 'Rumänisch';

  @override
  String get languageNameSV => 'Schwedisch';

  @override
  String get languageSystemDefault => 'Systemstandard';

  @override
  String get languageTitle => 'Sprache';

  @override
  String get ledgerCategoryAdjustment => 'Korrektur';

  @override
  String get ledgerCategoryExpense => 'Auslagenerstattung';

  @override
  String get ledgerCategoryOverage => 'Mehrnutzung';

  @override
  String get ledgerCategoryPayment => 'Zahlung';

  @override
  String get ledgerCategoryService => 'Leistung';

  @override
  String get ledgerCategorySubscription => 'Abo';

  @override
  String get legalIdentityAssociationRegime =>
      'Ein gemeinnütziger Verein ohne wirtschaftliche Tätigkeit unterliegt nicht der Umsatzsteuer: Wählen Sie „Nicht steuerbar“, nicht „Steuerbefreit“. Die Befreiung verlangt eine USt-IdNr., die Sie nicht haben, und die E-Rechnung würde abgelehnt. Nicht steuerbar identifiziert Ihre Registernummer den Verein.';

  @override
  String get legalIdentityCity => 'Stadt';

  @override
  String get legalIdentityExemptionReason => 'Grund der Steuerbefreiung';

  @override
  String get legalIdentityIntro =>
      'Was eine EN-16931-E-Rechnung über Sie aussagen muss. Bereits ausgestellte Rechnungen behalten die Identität, mit der sie signiert wurden.';

  @override
  String get legalIdentityLegalId => 'Registernummer';

  @override
  String get legalIdentityPostalCode => 'Postleitzahl';

  @override
  String get legalIdentityRegime => 'Steuerregime';

  @override
  String get legalIdentityRegimeExempt =>
      'Umsatzsteuerfrei (Kleinunternehmerregelung)';

  @override
  String get legalIdentityRegimeHint =>
      'Das Regime entscheidet, welche Nummer die Norm verlangt: eine Registernummer außerhalb der Umsatzsteuer, eine USt-IdNr. bei Steuerbefreiung.';

  @override
  String get legalIdentityRegimeNotSubject =>
      'Nicht der Umsatzsteuer unterliegend';

  @override
  String get legalIdentityRegimeVatRegistered =>
      'Umsatzsteuerpflichtig (berechnet USt.)';

  @override
  String get legalIdentitySaved => 'Rechtliche Identität gespeichert.';

  @override
  String get legalIdentityStreet => 'Straße';

  @override
  String get legalIdentitySubtitle =>
      'USt-Regime, Registernummern und die Standard-Zahlungsbedingungen des Space';

  @override
  String get legalIdentityTitle => 'Rechtliche Identität & E-Rechnung';

  @override
  String get legalIdentityVatId => 'Umsatzsteuer-ID';

  @override
  String get legalIdentityVatWarning =>
      'Dieser Space verlangt Mehrwertsteuer, es gilt aber kein Standardsatz: Es kann keine Rechnung ausgestellt werden, bis Sie einen anlegen. Sätze bearbeiten Sie bei eingeschalteter „USt-Verwaltung“.';

  @override
  String get legendBlocked => 'Gesperrt';

  @override
  String get legendClosed => 'Geschlossen';

  @override
  String get legendFree => 'Frei';

  @override
  String get legendMine => 'Meine';

  @override
  String get legendOccupied => 'Eingecheckt';

  @override
  String get legendProfileFull => 'Alle Zustände';

  @override
  String get legendProfileFullDesc =>
      'Frei · Reserviert · Anwesend · Meiner · Gesperrt — Sie sehen, wer da ist.';

  @override
  String get legendProfileSimple => 'Weniger Zustände';

  @override
  String get legendProfileSimpleDesc =>
      'Frei · Reserviert · Meiner · Nicht verfügbar. Ein reservierter Platz und einer, an dem jemand eingecheckt ist, sehen gleich aus.';

  @override
  String get legendProfileTitle => 'Was der Plan unterscheidet';

  @override
  String get legendReserved => 'Reserviert';

  @override
  String get legendUnavailable => 'Nicht verfügbar';

  @override
  String get levelAssignMember => 'Für Mitglied';

  @override
  String get levelAssignMyself => 'Mich selbst';

  @override
  String get levelBookableDesc =>
      'Die ganze Etage kann als eine Buchung reserviert werden.';

  @override
  String get levelBookableToggle => 'Als Ganzes reservierbar';

  @override
  String get levelConflict =>
      'Die Etage hat Reservierungen in diesem Zeitraum.';

  @override
  String get levelDetail => 'Ganze Etage';

  @override
  String get levelFeatureOff =>
      'Büro- & Etagen-Reservierungen sind in den Funktionen ausgeschaltet.';

  @override
  String get levelNotAllowed =>
      'Sie dürfen keinen ganzen Tisch, kein Büro und keine ganze Etage reservieren.';

  @override
  String get levelPermissionAllowed =>
      'Darf einen ganzen Tisch, ein Büro oder eine Etage reservieren';

  @override
  String get levelPermissionDenied =>
      'Darf keinen ganzen Tisch, kein Büro und keine Etage reservieren';

  @override
  String get levelPermissionTile => 'Etagen-Reservierungen';

  @override
  String get levelPriceLabel => 'Preis je Halbtag';

  @override
  String get levelReorderStale =>
      'Die Ebenen wurden inzwischen geändert. Nichts wurde gespeichert; die aktuelle Reihenfolge wird angezeigt.';

  @override
  String get levelReserveButton => 'Etage reservieren';

  @override
  String get levelReserveTitle => 'Die ganze Etage reservieren';

  @override
  String get levelSupplementLabel => 'Etagen-Reservierungen';

  @override
  String get libraryApplied => 'Vorlage angewendet.';

  @override
  String libraryAppliedChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Änderungen angewendet.',
      one: '1 Änderung angewendet.',
    );
    return '$_temp0';
  }

  @override
  String get libraryApply => 'Auf diesen Raum anwenden';

  @override
  String libraryApplyChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Änderungen anwenden',
      one: '1 Änderung anwenden',
      zero: 'Nichts ausgewählt',
    );
    return '$_temp0';
  }

  @override
  String get libraryApplyConfirmBody =>
      'Der Grundriss wird nach Namen hinzugefügt oder aktualisiert, und die Einstellungen der Vorlage werden zusammengeführt. Nichts Vorhandenes wird entfernt.';

  @override
  String libraryApplyConfirmTitle(String name) {
    return '« $name » anwenden?';
  }

  @override
  String get libraryCarriesSettings => 'mit ihren Einstellungen';

  @override
  String libraryConfirmSensitive(String groups) {
    return 'Das ändert: $groups. Anwenden?';
  }

  @override
  String libraryCounts(int levels, int desks, int seats) {
    return '$levels Ebenen · $desks Tische · $seats Plätze';
  }

  @override
  String get libraryCustomizedHere => 'Hier angepasst';

  @override
  String get libraryDelete => 'Vorlage löschen';

  @override
  String libraryDeleteConfirm(String name) {
    return '« $name » löschen? Personen, mit denen Sie sie geteilt haben, verlieren den Zugang.';
  }

  @override
  String get libraryEmpty =>
      'Noch nichts hier. Speichern Sie diesen Raum als Vorlage oder warten Sie, bis jemand eine mit Ihnen teilt.';

  @override
  String libraryFeatureNeeds(String feature, String prerequisite) {
    return '$feature braucht $prerequisite, das ausgeschaltet bleibt: Es funktioniert noch nicht.';
  }

  @override
  String get libraryGroupAppearance => 'Erscheinungsbild';

  @override
  String get libraryGroupCalendarNavigation => 'Kalender und Schließtage';

  @override
  String get libraryGroupDocumentsOperations => 'Dokumente und Betrieb';

  @override
  String get libraryGroupForms => 'Formulare';

  @override
  String get libraryGroupHoursBooking => 'Zeiten und Buchung';

  @override
  String get libraryGroupPricingCredits => 'Preise und Guthaben';

  @override
  String get libraryGroupRolesAccess => 'Rollen und Zugriff';

  @override
  String get libraryGroupSpace => 'Raum und Plan';

  @override
  String get libraryGroupUnknown =>
      'Anderes — diese Version kann es nicht anwenden';

  @override
  String get libraryGroupWording => 'Wortwahl';

  @override
  String get libraryInvitationTexts => 'Einladungstexte';

  @override
  String libraryInvitationTextsHint(String tag) {
    return 'Nur Texte mit Platzhaltern wie $tag; ein Text, der Ihren Arbeitsbereich oder seine Personen nennt, wird abgelehnt.';
  }

  @override
  String get libraryInvitationTextsRefused =>
      'Ein Einladungstext nennt noch Ihren Arbeitsbereich oder seine Personen. Ersetzen Sie sie in den Einladungseinstellungen durch Platzhalter oder wählen Sie die Einladungstexte ab.';

  @override
  String get libraryNeverDocumentDesign => 'Dokumentgestaltung';

  @override
  String get libraryNeverDocumentLinks => 'Links zu Ihren Dokumenten';

  @override
  String get libraryNeverIdentity =>
      'Ihre Adresse, Rechtskennungen, Pflichtangaben und WhatsApp-Gruppe';

  @override
  String get libraryNeverInvitations => 'Einladungstexte';

  @override
  String get libraryNeverPayment => 'Bankdaten';

  @override
  String get libraryNeverPublished => 'Nie veröffentlicht';

  @override
  String get libraryNeverSites => 'Standorte und ihre Adressen';

  @override
  String get libraryNotSupported =>
      'Diese Vorlage kann hier nicht angewendet werden.';

  @override
  String get libraryNothingToApply =>
      'Alles, was diese Vorlage mitbringt, ist schon da.';

  @override
  String get libraryPartial =>
      'Ein Teil dieser Vorlage kann hier nicht angewendet werden und bleibt außen vor.';

  @override
  String libraryPlanNames(String names) {
    return 'Diese Namen reisen mit dem Plan: $names';
  }

  @override
  String get libraryPreviewChanges => 'Änderungen ansehen';

  @override
  String get libraryPreviewFailed =>
      'Die Änderungen konnten nicht angezeigt werden. Es wurde nichts angewendet.';

  @override
  String libraryPreviewTitle(String name) {
    return 'Was « $name » ändern würde';
  }

  @override
  String libraryProcessOff(String feature) {
    return '$feature aus';
  }

  @override
  String libraryProcessOn(String feature) {
    return '$feature an';
  }

  @override
  String get libraryProcessTechnical => 'Technisch';

  @override
  String get libraryPublishGroups => 'Was mitreist';

  @override
  String get libraryPublishNothing => 'Wählen Sie mindestens eine Gruppe.';

  @override
  String get libraryReasonFeeSchedule =>
      'Ihre Gebührenstaffel würde als Ganzes ersetzt.';

  @override
  String get librarySave => 'Diesen Raum als Vorlage speichern';

  @override
  String get librarySaveDescription => 'Beschreibung (optional)';

  @override
  String get librarySaveName => 'Name der Vorlage';

  @override
  String get librarySaveTags => 'Schlagwörter, durch Kommas getrennt';

  @override
  String get librarySaved => 'In Ihren Vorlagen gespeichert.';

  @override
  String librarySearchCapabilities(String capabilities) {
    return 'Vorlagen eingerichtet für: $capabilities';
  }

  @override
  String get librarySearchHint => 'Vorlagen durchsuchen';

  @override
  String librarySearchSuggestion(String word) {
    return 'Meinten Sie „$word“?';
  }

  @override
  String get librarySearchUnavailable =>
      'Die Einstellungen der Vorlagen konnten nicht geprüft werden, daher wird keine als passend angezeigt. Versuchen Sie es erneut.';

  @override
  String get libraryShare => 'Teilen…';

  @override
  String get libraryShareAdd => 'Einladen';

  @override
  String get libraryShareEmail => 'E-Mail-Adresse';

  @override
  String get libraryShareHint =>
      'Per E-Mail einladen. Die Einladung wirkt, sobald sich diese Adresse anmeldet — ob dort schon ein Konto besteht, wird nicht verraten.';

  @override
  String get libraryShareNobody => 'Noch niemand eingeladen.';

  @override
  String libraryShareTitle(String name) {
    return '« $name » teilen';
  }

  @override
  String get libraryStartFrom => 'Aus der Bibliothek beginnen';

  @override
  String get libraryStateAttention => 'Braucht Aufmerksamkeit';

  @override
  String get libraryStateChange => 'Ändert Bestehendes';

  @override
  String get libraryStateMatching => 'Schon gleich';

  @override
  String get libraryStateNew => 'Neu';

  @override
  String get libraryTitle => 'Raumbibliothek';

  @override
  String get libraryVisibility => 'Wer sie sehen darf';

  @override
  String get libraryVisibilityBuiltin => 'Eingebaut';

  @override
  String get libraryVisibilityPrivate => 'Nur ich';

  @override
  String get libraryVisibilityPublic => 'Alle (die Bibliothek)';

  @override
  String get libraryVisibilityShared => 'Von mir eingeladene Personen';

  @override
  String get libraryYours => 'Ihre Vorlagen';

  @override
  String get linkedAccountsIntro =>
      'Melden Sie sich mit einer verknüpften Identität bei diesem Konto an. Die verfügbaren Anbieter hängen von Ihrem Server ab.';

  @override
  String get linkedAccountsLink => 'Verknüpfen';

  @override
  String get linkedAccountsLinkStarted =>
      'Fahre im Browser fort, um die Verknüpfung abzuschließen.';

  @override
  String get linkedAccountsLinked => 'Verknüpft';

  @override
  String get linkedAccountsTitle => 'Verknüpfte Konten';

  @override
  String get linkedAccountsUnlink => 'Trennen';

  @override
  String listCoversSeats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Plätze',
      one: '1 Platz',
    );
    return '$_temp0';
  }

  @override
  String listCoversTables(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tische',
      one: '1 Tisch',
    );
    return '$_temp0';
  }

  @override
  String get listWholeReservable => 'Als Ganzes reservierbar';

  @override
  String get localGapsTitle => 'Um diesen Arbeitsbereich fertig einzurichten';

  @override
  String get localNeedsTitle =>
      'Diese fügen Sie selbst hinzu; eine Vorlage überträgt sie nie:';

  @override
  String get localSlotEinvoicePlatform =>
      'Ihr Konto bei der E-Rechnungsplattform';

  @override
  String get localSlotLegalIdentity =>
      'Ihre rechtliche Identität und Adresse (für Rechnungen)';

  @override
  String localSlotNamedValidators(String type) {
    return 'Wer freigibt: $type';
  }

  @override
  String get localSlotOpen => 'Einrichten';

  @override
  String get localSlotPaymentDetails =>
      'Wie Mitglieder Sie bezahlen (Bankverbindung)';

  @override
  String get localSlotPaymentProvider => 'Ein Online-Zahlungsanbieter';

  @override
  String get localSlotRecommended => 'Empfohlen';

  @override
  String get localSlotSite => 'Mindestens ein Standort';

  @override
  String get managedAccessAdmins => 'Admins';

  @override
  String get managedAccessDefault => 'Jeder Inhaber und jeder Admin';

  @override
  String get managedAccessHint =>
      'Standard: jeder Inhaber und jeder Admin. Grenzen Sie nach Rolle, nach Person oder beidem ein. Der Inhaber darf diese Regel immer ändern — sonst könnte ein Profil unverwaltbar werden — erreicht die Daten aber nur, wenn die Regel ihn nennt.';

  @override
  String get managedAccessOwners => 'Inhaber';

  @override
  String get managedAccessPeople => 'Benannte Personen';

  @override
  String get managedAccessSaved => 'Regel gespeichert.';

  @override
  String get managedAccessTitle => 'Wer dieses Profil verwalten darf';

  @override
  String get managedProfileAdd => 'Verwaltetes Profil anlegen';

  @override
  String get managedProfileChip => 'Verwaltet';

  @override
  String get managedProfileCreated => 'Verwaltetes Profil angelegt';

  @override
  String get managedProfileEdit => 'Identität bearbeiten';

  @override
  String get managedProfileHandOver => 'An die Person übergeben';

  @override
  String get managedProfileHandOverHint =>
      'Erzeugt einen persönlichen Code für dieses Profil. Wer ihn einlöst, übernimmt das Profil — Reservierungen, Rechnungen, Abo — sobald Sie die Mitgliedschaft bestätigen.';

  @override
  String get managedProfileIdentityUnavailable =>
      'Diese Angaben konnten nicht gelesen werden, es gibt also noch nichts zu bearbeiten. Es wurde nichts geändert.';

  @override
  String get managedProfileIntro =>
      'Diese Person hat noch kein Konto. Sie buchen, fakturieren und verwalten für sie; übergeben Sie das Profil, wenn sie beitritt.';

  @override
  String get managedProfileRevoke => 'Übergabe zurückziehen';

  @override
  String get managedProfileRevoked => 'Übergabe zurückgezogen';

  @override
  String get managedProfileSaved => 'Identität gespeichert';

  @override
  String get managedProfileTitle => 'Verwaltetes Profil';

  @override
  String get mcpApiReference => 'API-Referenz';

  @override
  String get mcpApiReferenceHint =>
      'Was ein Assistent aufrufen kann und wie es autorisiert wird';

  @override
  String get mcpAssistantsTitle => 'Assistenten';

  @override
  String get mcpAssistantsUnavailable =>
      'Ihr Assistentenzugang konnte nicht geladen werden. Versuchen Sie es später erneut.';

  @override
  String get mcpCancel => 'Abbrechen';

  @override
  String get mcpConfirmAccept => 'Bestätigen';

  @override
  String get mcpConfirmApprove => 'Ihre Antwort: freigeben';

  @override
  String mcpConfirmClient(String client) {
    return 'Angefragt von: $client';
  }

  @override
  String get mcpConfirmConsequence =>
      'Die Bestätigung erlaubt dem Assistenten, genau diese Anfrage einmal zu senden. Die Freigaberegeln des Arbeitsbereichs gelten weiterhin.';

  @override
  String get mcpConfirmDecline => 'Ablehnen';

  @override
  String get mcpConfirmDeclined => 'Abgelehnt. Es wurde nichts ausgeführt.';

  @override
  String get mcpConfirmDone =>
      'Bestätigt. Der Assistent kann die Anfrage jetzt senden.';

  @override
  String get mcpConfirmExpired =>
      'Diese Anfrage ist abgelaufen. Bitten Sie den Assistenten, sie erneut zu senden.';

  @override
  String mcpConfirmNewShare(String pct) {
    return 'Neuer Abonnementanteil: $pct %';
  }

  @override
  String mcpConfirmNewStatus(String status) {
    return 'Neuer Status: $status';
  }

  @override
  String get mcpConfirmNotFound => 'Für Sie gibt es keine solche Anfrage.';

  @override
  String mcpConfirmPeriod(String period) {
    return 'Zeitraum: $period';
  }

  @override
  String get mcpConfirmRefuse => 'Ihre Antwort: ablehnen';

  @override
  String get mcpConfirmStale =>
      'Diese Anfrage passt nicht mehr zu den aktuellen Daten oder Ihrem Zugriff. Es wurde nichts ausgeführt.';

  @override
  String get mcpConfirmTitle => 'Anfrage eines Assistenten bestätigen';

  @override
  String get mcpConfirmUnavailable =>
      'Diese Anfrage konnte nicht geladen werden. Versuchen Sie es über den Link erneut.';

  @override
  String mcpConfirmWorkspace(String workspace) {
    return 'Arbeitsbereich: $workspace';
  }

  @override
  String mcpConnectAccessExpiresIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tage',
      one: '1 Tag',
    );
    return 'Freigegeben — noch $_temp0.';
  }

  @override
  String mcpConnectAccessExpiresSoon(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tagen',
      one: '1 Tag',
    );
    return 'Freigegeben — läuft in $_temp0 ab. Fragen Sie danach erneut nach Freigabe.';
  }

  @override
  String get mcpConnectAddTitle => 'DesKilo zu Ihrem Assistenten hinzufügen';

  @override
  String get mcpConnectAddressLabel => 'Ihre DesKilo-Adresse für Assistenten';

  @override
  String get mcpConnectAllDone =>
      'Alles ist bereit. Testen Sie die Verbindung unten.';

  @override
  String get mcpConnectBeforeTitle => 'Bevor Sie verbinden';

  @override
  String get mcpConnectChatgptNote =>
      'Der Entwicklermodus erfordert einen kostenpflichtigen ChatGPT-Tarif (Plus, Pro, Business, Enterprise oder Edu).';

  @override
  String get mcpConnectChatgptStep1 =>
      'Schalten Sie in ChatGPT den Entwicklermodus ein: Einstellungen → Apps → Erweiterte Einstellungen.';

  @override
  String get mcpConnectChatgptStep2 =>
      'Erstellen Sie eine App namens DesKilo, fügen Sie die Adresse oben ein und wählen Sie OAuth als Authentifizierung.';

  @override
  String get mcpConnectChatgptStep3 =>
      'Melden Sie sich mit Google an und wählen Sie diesen Arbeitsbereich und was ChatGPT dort darf.';

  @override
  String get mcpConnectClaudeNote =>
      'Claude im Web, Claude Desktop und die Claude-App teilen dieselben Konnektoren. Bei einem Team- oder Enterprise-Tarif fügt zuerst ein Inhaber der Claude-Organisation den Konnektor hinzu.';

  @override
  String get mcpConnectClaudeOpen => 'Claude-Konnektoren öffnen';

  @override
  String get mcpConnectClaudeStep1 =>
      'Öffnen Sie in Claude Einstellungen → Konnektoren.';

  @override
  String get mcpConnectClaudeStep2 =>
      'Wählen Sie „Benutzerdefinierten Konnektor hinzufügen“, nennen Sie ihn DesKilo und fügen Sie die Adresse oben ein.';

  @override
  String get mcpConnectClaudeStep3 =>
      'Wählen Sie Verbinden, melden Sie sich mit Google an und wählen Sie diesen Arbeitsbereich und was Claude dort darf.';

  @override
  String get mcpConnectCodeStep1 => 'Führen Sie dies in einem Terminal aus:';

  @override
  String get mcpConnectCodeStep2 =>
      'Geben Sie in Claude Code /mcp ein, wählen Sie deskilo und dann Authenticate. Ein Browser öffnet sich zur Anmeldung und zur Wahl dieses Arbeitsbereichs.';

  @override
  String get mcpConnectCopied => 'Kopiert.';

  @override
  String get mcpConnectCopyRequest => 'Anfrage zum Senden kopieren';

  @override
  String get mcpConnectCursorInstall => 'Zu Cursor hinzufügen';

  @override
  String get mcpConnectCursorStep =>
      'Cursor bietet an, DesKilo zu installieren, und öffnet dann einen Browser zur Anmeldung und zur Wahl dieses Arbeitsbereichs. Ohne die Schaltfläche fügen Sie dies zu ~/.cursor/mcp.json hinzu:';

  @override
  String get mcpConnectDone => 'Erledigt';

  @override
  String get mcpConnectIntro =>
      'Lassen Sie Claude, ChatGPT oder einen anderen Assistenten in DesKilo für Sie nachsehen und buchen. Er handelt in Ihrem Namen, nur in den Arbeitsbereichen und für die Aktionen, die Sie freigeben.';

  @override
  String mcpConnectLastCall(String client, String when) {
    return 'Letzter Aufruf: $client, $when.';
  }

  @override
  String get mcpConnectManageHint =>
      'Um zu sehen, was ein Assistent getan hat, oder um ihn zu trennen, öffnen Sie Assistenten.';

  @override
  String get mcpConnectOpenFailed =>
      'Die App konnte von hier aus nicht geöffnet werden. Folgen Sie stattdessen den Schritten unten.';

  @override
  String get mcpConnectOpenGuide => 'Verbindungsanleitung öffnen';

  @override
  String get mcpConnectOpenInstallation => 'Installationskonsole öffnen';

  @override
  String get mcpConnectOpenSetup => 'Assistenten-Einrichtung öffnen';

  @override
  String get mcpConnectOperatorRequest =>
      'Hallo, könnten Sie die Assistenten auf unserem DesKilo-Server einschalten? Das geht unter Einstellungen → Installation: Assistenten. Danke.';

  @override
  String get mcpConnectOtherStep1 =>
      'Die meisten Clients lesen eine JSON-Datei mit Servern. Fügen Sie diesen Eintrag hinzu; der Client öffnet beim ersten Mal einen Browser zur Anmeldung.';

  @override
  String get mcpConnectOtherStep2 =>
      'Ein Client, der nur lokale Programme startet, erreicht DesKilo über mcp-remote (benötigt Node.js):';

  @override
  String get mcpConnectRoleDenied =>
      'Ihrer Rolle wird hier nichts angeboten. Ein Administrator des Arbeitsbereichs entscheidet, was jede Rolle darf.';

  @override
  String get mcpConnectStepAccess => 'Ihr Zugang zu Assistenten';

  @override
  String get mcpConnectStepConnect =>
      'DesKilo zu Ihrem Assistenten hinzugefügt';

  @override
  String get mcpConnectStepGoogle => 'Anmeldung mit Google';

  @override
  String get mcpConnectStepIdentity => 'Ihre Identität auf diesem Server';

  @override
  String get mcpConnectStepServer =>
      'Assistenten auf diesem Server eingeschaltet';

  @override
  String get mcpConnectStepWorkspace =>
      'Dieser Arbeitsbereich bietet Assistenten an';

  @override
  String get mcpConnectSwitchWorkspace => 'Zu diesem Arbeitsbereich wechseln';

  @override
  String get mcpConnectTabChatgpt => 'ChatGPT';

  @override
  String get mcpConnectTabClaude => 'Claude';

  @override
  String get mcpConnectTabClaudeCode => 'Claude Code';

  @override
  String get mcpConnectTabCursor => 'Cursor';

  @override
  String get mcpConnectTabOther => 'Andere';

  @override
  String get mcpConnectTabVscode => 'VS Code';

  @override
  String get mcpConnectTest => 'Verbindung testen';

  @override
  String get mcpConnectTestAgain => 'Erneut testen';

  @override
  String get mcpConnectTestPrompt =>
      'Welche Buchungen habe ich diese Woche in DesKilo?';

  @override
  String mcpConnectTestReached(String client, String when) {
    return 'Verbunden: $client hat DesKilo erreicht, $when.';
  }

  @override
  String get mcpConnectTestTimeout =>
      'Noch kein Aufruf eingegangen. Prüfen Sie, ob der Konnektor hinzugefügt ist, ob Sie diesen Arbeitsbereich freigegeben haben und ob die Schritte oben erledigt sind; testen Sie dann erneut.';

  @override
  String get mcpConnectTestTitle => 'Prüfen, ob es funktioniert';

  @override
  String get mcpConnectTestWaiting =>
      'Wartet darauf, dass Ihr Assistent DesKilo aufruft. Fragen Sie ihn:';

  @override
  String get mcpConnectTitle => 'Assistenten verbinden';

  @override
  String get mcpConnectTodoConnect =>
      'Zu tun — Sie: Folgen Sie unten den Schritten für Ihren Assistenten.';

  @override
  String get mcpConnectTodoYou => 'Zu tun — Sie.';

  @override
  String get mcpConnectUnavailable => 'Konnte gerade nicht geprüft werden.';

  @override
  String get mcpConnectVscodeInstall => 'Zu VS Code hinzufügen';

  @override
  String get mcpConnectVscodeStep =>
      'VS Code bietet an, DesKilo zu installieren. Starten Sie es aus der Liste der MCP-Server; ein Browser öffnet sich zur Anmeldung und zur Wahl dieses Arbeitsbereichs.';

  @override
  String get mcpConnectWaitingDatabaseAdmin =>
      'Wartet auf einen Datenbank-Administrator, der Ihre Anfrage freigibt.';

  @override
  String mcpConnectWaitingOperator(String names) {
    return 'Wartet auf den Betreiber des Servers: $names.';
  }

  @override
  String get mcpConnectWaitingOperatorUnknown =>
      'Wartet auf den Betreiber des Servers, der noch nicht benannt ist.';

  @override
  String get mcpConnectWaitingWorkspaceAdmin =>
      'Wartet auf einen Administrator des Arbeitsbereichs, der hier Assistenten anbietet.';

  @override
  String get mcpConnectWhich => 'Welchen Assistenten verwenden Sie?';

  @override
  String get mcpConnectWorkspaceSelected => 'Ausgewählter Arbeitsbereich';

  @override
  String get mcpConnectWorkspacesHint =>
      'Jeder Arbeitsbereich entscheidet selbst. Wenn Ihr Assistent fragt, wählen Sie unter den bereiten aus.';

  @override
  String get mcpConnectWorkspacesTitle => 'Ihre Arbeitsbereiche';

  @override
  String get mcpConnectWsConnected =>
      'Verbunden — ein Assistent darf hier für Sie handeln.';

  @override
  String get mcpConnectWsNotOffered =>
      'Assistenten sind eingeschaltet, aber Ihrer Rolle wird noch nichts angeboten. Ein Administrator des Arbeitsbereichs entscheidet.';

  @override
  String get mcpConnectWsOff =>
      'Assistenten sind in diesem Arbeitsbereich ausgeschaltet. Ein Administrator des Arbeitsbereichs schaltet sie in der Assistenten-Einrichtung ein.';

  @override
  String get mcpConnectWsReady =>
      'Bereit — wählen Sie ihn, wenn Ihr Assistent fragt.';

  @override
  String get mcpConnectWsUnknown =>
      'Wird angezeigt, sobald Ihr Zugang zu Assistenten freigegeben ist.';

  @override
  String get mcpConnectedNoWorkspace =>
      'Kein Arbeitsbereich: Dieser Assistent kann hier nichts tun.';

  @override
  String get mcpConnectedNone =>
      'Kein Assistent ist verbunden. Verbinden Sie einen direkt im Assistenten.';

  @override
  String get mcpConnectedTitle => 'Verbundene Assistenten';

  @override
  String get mcpConsentAlready =>
      'Dieser Assistent ist bereits verbunden. Zurück zu ihm.';

  @override
  String get mcpConsentApprove => 'Verbinden';

  @override
  String mcpConsentAsks(String client) {
    return '$client möchte in Deskilo für Sie handeln.';
  }

  @override
  String get mcpConsentChoose =>
      'Wählen Sie jeden Arbeitsbereich und was der Assistent dort tun darf. Nichts ist vorausgewählt.';

  @override
  String mcpConsentClientBlocked(String name) {
    return 'Der Betreiber hat $name auf diesem Server gesperrt. Er kann nicht verbunden werden.';
  }

  @override
  String mcpConsentClientWaiting(String name) {
    return '$name ist auf diesem Server noch nicht freigegeben. Der Betreiber gibt jeden Assistenten einmal frei; verbinden Sie danach erneut aus dem Assistenten.';
  }

  @override
  String get mcpConsentConnected => 'Verbunden. Zurück zum Assistenten.';

  @override
  String mcpConsentDeciderAsk(String name) {
    return 'Bitten Sie $name um eine Entscheidung.';
  }

  @override
  String get mcpConsentDeciderMe =>
      'Das entscheiden Sie selbst, in der Installationskonsole.';

  @override
  String get mcpConsentDeciderNobody =>
      'Für diesen Server ist noch niemand zuständig.';

  @override
  String get mcpConsentDenied => 'Abgelehnt. Der Assistent erhält nichts.';

  @override
  String get mcpConsentDeny => 'Ablehnen';

  @override
  String get mcpConsentFamilyChatgpt =>
      'Für alle ChatGPT-Verbindungen freigegeben.';

  @override
  String get mcpConsentFamilyClaude =>
      'Für alle Claude-Verbindungen freigegeben.';

  @override
  String get mcpConsentFamilyLoopback =>
      'Für Desktop- und Kommandozeilen-Assistenten auf diesem Computer freigegeben.';

  @override
  String get mcpConsentFieldsExplain =>
      'Angaben, die er hier zusätzlich sehen darf. Lassen Sie sie aus, damit seine Antworten minimiert bleiben.';

  @override
  String get mcpConsentNoWorkspace =>
      'Keiner Ihrer Arbeitsbereiche lässt Assistenten zu. Es kann nichts verbunden werden.';

  @override
  String get mcpConsentNotEligible =>
      'Diese Datenbank hat Assistenten für Sie noch nicht freigegeben. Bitten Sie um Freigabe und verbinden Sie sich dann erneut.';

  @override
  String get mcpConsentPartial =>
      'Der Assistent wurde genehmigt, aber die Verbindung ist noch nicht nutzbar. Verbinden Sie sich erneut im Assistenten.';

  @override
  String mcpConsentRedirectHost(String host) {
    return 'Die Antwort wird an $host gesendet.';
  }

  @override
  String get mcpConsentRequestEligibility => 'Freigabe anfragen';

  @override
  String get mcpConsentRequested =>
      'Freigabe angefragt. Ein Datenbankadministrator prüft sie.';

  @override
  String get mcpConsentTitle => 'Assistenten verbinden';

  @override
  String get mcpConsentUnavailable =>
      'Diese Verbindungsanfrage konnte nicht geladen werden. Beginnen Sie erneut im Assistenten.';

  @override
  String get mcpDisclosureMaximumExplain =>
      'Das Höchstmaß, das Eigentümer in dieser Datenbank Assistenten zeigen dürfen. Es erweitert nie die Richtlinie eines Workspaces oder die Einwilligung einer Person.';

  @override
  String get mcpDisclosureMaximumLocked =>
      'Bestätigen Sie mit Ihrem zweiten Faktor, um das Höchstmaß zu sehen und zu ändern.';

  @override
  String get mcpDisclosureMaximumRefused =>
      'Das Höchstmaß wurde nicht gespeichert. Dafür ist Ihr zweiter Faktor nötig.';

  @override
  String get mcpDisclosureMaximumSave => 'Höchstmaß speichern';

  @override
  String get mcpDisclosureMaximumSaved => 'Höchstmaß gespeichert.';

  @override
  String get mcpDisclosureNoneAllowed =>
      'Diese Datenbank erlaubt keine optionalen Angaben für Assistenten.';

  @override
  String get mcpDisclosurePolicyExplain =>
      'Assistenten erhalten minimierte Antworten. Wählen Sie, welche Angaben sie hier zusätzlich sehen dürfen; jede Person entscheidet weiterhin selbst.';

  @override
  String get mcpDisclosurePreviewDetailed => 'Ausführliche Antwort';

  @override
  String get mcpDisclosurePreviewMinimised => 'Minimierte Antwort';

  @override
  String get mcpDisclosurePreviewNote =>
      'Eine erfundene Antwort, die zeigt, was Assistenten sehen würden.';

  @override
  String get mcpDisclosureTitle => 'Optionale Angaben';

  @override
  String get mcpDisclosureUnlock => 'Bestätigen';

  @override
  String get mcpDisconnect => 'Trennen';

  @override
  String get mcpDisconnectBody =>
      'Der Assistent verliert den Zugriff auf alle Arbeitsbereiche dieser Datenbank. Bereits Gelesenes wird nicht zurückgenommen.';

  @override
  String mcpDisconnectTitle(String client) {
    return '$client trennen?';
  }

  @override
  String get mcpEligibleExpired =>
      'Ihre Freigabe ist abgelaufen. Fragen Sie erneut an, um Assistenten weiter zu nutzen.';

  @override
  String get mcpEligibleNoIdentity =>
      'Ihre Identität ist für Assistenten auf dieser Datenbank noch nicht bestätigt.';

  @override
  String get mcpEligibleNot =>
      'Diese Datenbank hat Assistenten für Sie nicht freigegeben.';

  @override
  String get mcpEligibleRequested =>
      'Sie haben um Freigabe gebeten. Ein Datenbankadministrator prüft sie.';

  @override
  String get mcpEligibleWithdraw =>
      'Assistentenzugang auf dieser Datenbank aufgeben';

  @override
  String get mcpEligibleYes =>
      'Diese Datenbank erlaubt Ihnen, Assistenten zu nutzen.';

  @override
  String get mcpFieldName => 'Namen von Workspaces und Plätzen';

  @override
  String get mcpFieldNameSample => 'Fensterplatz 12';

  @override
  String get mcpGroupFinancial => 'Finanzanfragen';

  @override
  String get mcpGroupMembership => 'Mitgliedschaftsanfragen';

  @override
  String get mcpGroupOwn => 'Eigene Buchungen und Konto';

  @override
  String get mcpGroupValidations => 'Freigaben';

  @override
  String get mcpIdentityConflict =>
      'Ein anderes Konto hält diese Identität hier bereits — ein Datenbankadministrator kann das klären.';

  @override
  String get mcpIdentityIneligible =>
      'Dieses Konto kann noch nicht bestätigt werden — bestätigen Sie zuerst Ihre E-Mail-Adresse oder melden Sie sich mit einem Anbieter an.';

  @override
  String get mcpNextAwaitEligibility =>
      'Als Nächstes: Ein Datenbank-Administrator entscheidet über Ihre Anfrage.';

  @override
  String get mcpNextConsent =>
      'Als Nächstes: Verbinden Sie einen Assistenten aus dem Assistenten selbst und geben Sie diesen Arbeitsbereich frei.';

  @override
  String get mcpNextLinkGoogle =>
      'Assistenten verwenden Ihre Google-Anmeldung. Verknüpfen Sie zuerst Google mit diesem Konto; ohne Google kann das Konto keine Assistenten nutzen.';

  @override
  String get mcpNextLinkIdentity =>
      'Nächster Schritt: Bestätigen Sie Ihre Identität für Assistenten auf dieser Datenbank — ein Tippen unten.';

  @override
  String get mcpNextOwnerExposes =>
      'Als Nächstes: Die Inhaberin oder der Inhaber des Arbeitsbereichs bietet Assistenten Vorgänge an.';

  @override
  String get mcpNextReady =>
      'Bereit: Ein verbundener Assistent darf in diesem Arbeitsbereich für Sie handeln, im Rahmen Ihrer Freigabe.';

  @override
  String get mcpNextRequestEligibility =>
      'Als Nächstes: Sie bitten die Administratoren dieser Datenbank um Freigabe.';

  @override
  String get mcpNextRoleDenied =>
      'Ihre Rolle lässt hier keinen Vorgang zu. Die Inhaberin oder der Inhaber des Arbeitsbereichs entscheidet, was jede Rolle darf.';

  @override
  String get mcpNextSignInGoogle =>
      'Assistenten verwenden Ihre Google-Anmeldung. Melden Sie sich mit Google an, um fortzufahren.';

  @override
  String get mcpNextUnavailable =>
      'Der Server konnte nicht antworten. Es wird nichts angenommen; versuchen Sie es später erneut.';

  @override
  String get mcpOpAvailability => 'Freie Plätze sehen';

  @override
  String get mcpOpCancelReservation =>
      'Ihre noch nicht begonnenen Buchungen stornieren';

  @override
  String get mcpOpCapabilities => 'Sehen, was er dort tun darf';

  @override
  String get mcpOpCheckIn => 'Sie einchecken';

  @override
  String get mcpOpCheckOut => 'Sie auschecken';

  @override
  String get mcpOpCreateReservation => 'Einen Platz für Sie buchen';

  @override
  String get mcpOpGetPlace => 'Einen Ort beschreiben und auf Wunsch zeigen';

  @override
  String get mcpOpGetValidation => 'Eine Freigabeanfrage lesen';

  @override
  String get mcpOpInvoiceIssue => 'Rechnung ausstellen';

  @override
  String get mcpOpInvoiceVoid => 'Rechnung stornieren';

  @override
  String get mcpOpListMyFavorites => 'Ihre Lieblingsplätze';

  @override
  String get mcpOpListWorkspaces =>
      'Sehen, welche Arbeitsbereiche er nutzen darf';

  @override
  String get mcpOpMemberStatus => 'Status eines Mitglieds ändern';

  @override
  String get mcpOpMyInvoices => 'Ihre Rechnungen sehen';

  @override
  String get mcpOpMyReservations => 'Ihre Reservierungen sehen';

  @override
  String get mcpOpMyStatement => 'Ihren Kontoauszug sehen';

  @override
  String get mcpOpPendingValidations => 'Offene Freigabeanfragen sehen';

  @override
  String get mcpOpRatePlace => 'Plätze bewerten';

  @override
  String get mcpOpRefund => 'Rechnung erstatten';

  @override
  String get mcpOpReservationDeletion =>
      'Löschung einer bereits begonnenen Buchung beantragen';

  @override
  String get mcpOpRespond => 'Auf eine Freigabeanfrage antworten';

  @override
  String get mcpOpSetFavorite => 'Plätze als Favoriten markieren';

  @override
  String get mcpOpSubscription => 'Abonnementanteil eines Mitglieds ändern';

  @override
  String get mcpOpUpdateReservation => 'Ihre Reservierungen ändern';

  @override
  String get mcpOverviewTitle => 'Weitere verbundene Datenbanken';

  @override
  String get mcpOverviewUnavailable => 'Konnte gerade nicht abgefragt werden.';

  @override
  String get mcpPolicyBroadening =>
      'Bereits verbundene Assistenten erhalten die neuen Dienste nicht: Jede Person muss sie beim erneuten Verbinden hinzufügen.';

  @override
  String get mcpPolicyCeiling => 'Daten, auf die ein Assistent zugreifen darf';

  @override
  String get mcpPolicyCeilingOwn => 'Nur eigene Daten';

  @override
  String get mcpPolicyCeilingWorkspace => 'Ganzer Arbeitsbereich';

  @override
  String get mcpPolicyConflict =>
      'Dieses Speichern wurde abgelehnt. Prüfen Sie den aktuellen Stand und speichern Sie erneut.';

  @override
  String get mcpPolicyEnabled => 'Assistentendienste anbieten';

  @override
  String get mcpPolicyExplain =>
      'Wählen Sie, was Assistenten in diesem Arbeitsbereich tun dürfen. Ein Mitglied braucht weiterhin die Freigabe dieser Datenbank, die passende Rolle und muss diesen Arbeitsbereich beim Verbinden seines Assistenten wählen.';

  @override
  String get mcpPolicyFeatureOff =>
      'Assistenten sind in den Funktionen dieses Arbeitsbereichs ausgeschaltet. Sie können die Dienste unten weiterhin einschränken oder abschalten.';

  @override
  String get mcpPolicySave => 'Speichern';

  @override
  String get mcpPolicySaved => 'Gespeichert.';

  @override
  String get mcpPolicyStale =>
      'Jemand hat diese Einstellungen inzwischen geändert. Prüfen Sie den aktuellen Stand und speichern Sie erneut.';

  @override
  String get mcpPolicySwitched =>
      'Sie haben den Arbeitsbereich gewechselt. Öffnen Sie diese Seite erneut, um den anderen zu bearbeiten.';

  @override
  String get mcpPolicyTitle => 'Zugriff für Assistenten';

  @override
  String get mcpPolicyUnavailable =>
      'Die Assistenten-Einstellungen konnten nicht geladen werden. Versuchen Sie es später erneut.';

  @override
  String get mcpRefusalClientNotApproved =>
      'Dieser Assistent ist auf diesem Server noch nicht freigegeben. Der Betreiber gibt jeden Assistenten einmal frei; fragen Sie ihn und verbinden Sie dann erneut aus dem Assistenten.';

  @override
  String get mcpRefusalNoIdentity =>
      'Bestätigen Sie zuerst Ihre Identität in DesKilo unter Assistenten und verbinden Sie dann erneut aus dem Assistenten.';

  @override
  String get mcpRefusalNotEligible =>
      'Ihr Zugang zu Assistenten ist noch nicht freigegeben. Beantragen Sie ihn in DesKilo unter Assistenten und verbinden Sie dann erneut aus dem Assistenten.';

  @override
  String get mcpRefusalOfferChanged =>
      'Das Angebot dieses Arbeitsbereichs hat sich während Ihrer Auswahl geändert. Verbinden Sie erneut aus dem Assistenten, um das aktuelle Angebot zu sehen.';

  @override
  String get mcpRefusalRequestExpired =>
      'Diese Verbindungsanfrage ist abgelaufen oder wurde bereits verwendet. Beginnen Sie erneut im Assistenten.';

  @override
  String get mcpRemoveWorkspace => 'Diesen Arbeitsbereich entfernen';

  @override
  String get mcpReviewApprove => 'Freigeben';

  @override
  String get mcpReviewChanged =>
      'Diese Anfrage hat sich geändert oder ein anderer Administrator hat zuerst entschieden. Es wurde nichts getan.';

  @override
  String get mcpReviewDone => 'Entscheidung gespeichert.';

  @override
  String get mcpReviewEmpty => 'Keine Anfrage wartet.';

  @override
  String get mcpReviewExplain =>
      'Eine Freigabe erlaubt einer Person, Assistenten auf dieser Datenbank zu verbinden, in den Arbeitsbereichen, deren Eigentümer es zulassen. Sie gewährt keine Mitgliedschaft und keine Rolle.';

  @override
  String get mcpReviewNotAdmin =>
      'Nur die Administratoren dieser Datenbank prüfen Freigaben.';

  @override
  String get mcpReviewRefused => 'Die Entscheidung wurde abgelehnt.';

  @override
  String get mcpReviewReject => 'Ablehnen';

  @override
  String get mcpReviewSecondFactor =>
      'Diese Datenbank verlangt Ihren zweiten Faktor in ihrer eigenen Sitzung. Es wurde nichts entschieden.';

  @override
  String get mcpReviewTitle => 'Freigaben für Assistenten';

  @override
  String get mcpReviewUnavailable =>
      'Die Anfragen konnten nicht geladen werden. Eine Prüfung braucht Ihren zweiten Faktor; versuchen Sie es erneut.';

  @override
  String get mcpStateAfterPrevious => 'Nach dem vorherigen Schritt';

  @override
  String get mcpStateAllowed => 'Erlaubt';

  @override
  String get mcpStateApproved => 'Freigegeben';

  @override
  String get mcpStateAvailable => 'Erreichbar';

  @override
  String get mcpStateCurrent => 'Erteilt';

  @override
  String get mcpStateDenied => 'Nichts für Ihre Rolle';

  @override
  String get mcpStateDisabled => 'Nichts angeboten';

  @override
  String get mcpStateExposed => 'Vorgänge angeboten';

  @override
  String get mcpStateGoogleMissing => 'Google nicht verknüpft';

  @override
  String get mcpStateGoogleOtherSession => 'Anders angemeldet';

  @override
  String get mcpStateGoogleReady => 'Mit Google angemeldet';

  @override
  String get mcpStateIncompatible => 'Inkompatible Version';

  @override
  String get mcpStateMissing => 'Nicht erteilt';

  @override
  String get mcpStateNotRequested => 'Nicht beantragt';

  @override
  String get mcpStatePending => 'Wartet auf eine Entscheidung';

  @override
  String get mcpStateRevoked => 'Abgelaufen oder zurückgezogen';

  @override
  String get mcpStateUnavailable => 'Unbekannt';

  @override
  String get mcpStateUnlinked => 'Nicht bestätigt';

  @override
  String get mcpStateVerified => 'Bestätigt';

  @override
  String get mcpStatusBackend => 'Server';

  @override
  String get mcpStatusConfirmIdentity => 'Meine Identität bestätigen';

  @override
  String get mcpStatusConsent => 'Ihre Zustimmung';

  @override
  String get mcpStatusEligibility => 'Freigabe der Datenbank';

  @override
  String get mcpStatusExposure => 'Angebot des Arbeitsbereichs';

  @override
  String get mcpStatusGoogle => 'Google-Anmeldung';

  @override
  String get mcpStatusIdentity => 'Identität für Assistenten';

  @override
  String get mcpStatusLinkGoogle => 'Google verknüpfen';

  @override
  String get mcpStatusOpenLinkedAccounts => 'Verknüpfte Konten öffnen';

  @override
  String get mcpStatusRole => 'Ihre Rolle';

  @override
  String get mcpStatusSignInGoogle => 'Mit Google anmelden';

  @override
  String get mcpStatusTitle => 'Wo Sie hier stehen';

  @override
  String get mcpUsageApplied => 'Ausgeführt';

  @override
  String mcpUsageLastUsed(String when) {
    return 'Zuletzt genutzt $when';
  }

  @override
  String get mcpUsageMineTitle => 'Ihre Nutzung durch Assistenten heute';

  @override
  String get mcpUsageNone => 'Noch kein Assistent hat Ihren Zugang genutzt.';

  @override
  String get mcpUsagePending => 'Warten auf Freigabe';

  @override
  String get mcpUsageRefusals => 'Abgelehnt';

  @override
  String get mcpUsageRequests => 'Anfragen';

  @override
  String get mcpUsageUnavailable => 'Die Nutzung konnte nicht geladen werden.';

  @override
  String get mcpUsageWorkspaceTitle =>
      'Nutzung durch Assistenten, letzte 30 Tage';

  @override
  String get meAccountInMe => 'Mein Konto ist unter Ich';

  @override
  String get meAccountInMeBody =>
      'Foto, Sprache, Design und Anmeldungen gehören Ihnen – in jedem Space.';

  @override
  String get meAddressSaveFailed =>
      'Ihre Adresse konnte nicht gespeichert werden. Bitte versuchen Sie es erneut.';

  @override
  String get meCreateSpace => 'Space gründen';

  @override
  String meFinanceGlanceOwed(String amount) {
    return 'Zu zahlen: $amount';
  }

  @override
  String get meFindSpace => 'Space finden';

  @override
  String get meGroupAdd => 'Neue Gruppe';

  @override
  String get meGroupDelete => 'Gruppe löschen';

  @override
  String get meGroupEmptyFavorites =>
      'Geben Sie einem Space ein Herz, dann wartet er hier.';

  @override
  String get meGroupEmptyOwn => 'Verschieben Sie Spaces über ihr Menü hierher.';

  @override
  String get meGroupFavorites => 'Favoriten';

  @override
  String get meGroupInstallations => 'Verbundene Installationen';

  @override
  String get meGroupMove => 'In Gruppe verschieben…';

  @override
  String get meGroupName => 'Gruppenname';

  @override
  String get meGroupOther => 'Andere';

  @override
  String get meGroupProfile => 'Mein Profil';

  @override
  String get meGroupRename => 'Umbenennen';

  @override
  String get meGroupWorkspaces => 'Meine Arbeitsbereiche';

  @override
  String get meHeaderOwned => 'Ihr Konto · es gehört nur Ihnen';

  @override
  String get meHomeTitle => 'Start';

  @override
  String get meJoinSpace => 'Mit Code beitreten';

  @override
  String get meLeaveAction => 'Diesen Space verlassen';

  @override
  String get meLeaveBody =>
      'Sie sind dann kein Mitglied mehr. Ihre Buchungen, Rechnungen und Nachrichten bleiben beim Space. Um auch Ihre Daten zu löschen, nutzen Sie Datenschutz.';

  @override
  String meLeaveDone(String name) {
    return 'Sie haben $name verlassen.';
  }

  @override
  String get meLeaveFailed =>
      'Der Space konnte nicht verlassen werden. Bitte versuchen Sie es erneut.';

  @override
  String get meLeaveOwner =>
      'Eigentümer übergeben den Space, bevor sie ihn verlassen';

  @override
  String meLeaveSide(String side) {
    return '$side verlassen';
  }

  @override
  String meLeaveTitle(String name) {
    return '$name verlassen?';
  }

  @override
  String meLinkedOpen(String host) {
    return 'Auf $host öffnen';
  }

  @override
  String meLinkedOpenBody(String host) {
    return 'Dieser Space liegt auf $host. Die App arbeitet mit einem Server zur Zeit: Öffnen wechselt zu diesem Server und fragt dort nach Ihrer Anmeldung.';
  }

  @override
  String meLinkedPendingOn(String host) {
    return 'Wartet auf Freigabe · $host';
  }

  @override
  String meLinkedUnavailable(String host) {
    return '$host hat nicht geantwortet: Diese Liste ist womöglich unvollständig.';
  }

  @override
  String get meManageSpaces => 'Meine Spaces verwalten';

  @override
  String get meMySpaces => 'Meine Spaces';

  @override
  String get meNoSpaceBody =>
      'Finden Sie einen in Ihrer Nähe, treten Sie mit einem Einladungscode bei oder gründen Sie Ihren eigenen.';

  @override
  String get meNoSpaceTitle => 'Sie sind noch in keinem Space';

  @override
  String get meSectionMine => 'Mein Verlauf und meine Daten';

  @override
  String get meSortAlphabet => 'A–Z';

  @override
  String get meSortHand => 'Meine Reihenfolge';

  @override
  String get meSortRating => 'Am besten bewertet';

  @override
  String get meSortRecent => 'Zuletzt genutzt';

  @override
  String get meSortTooltip => 'Sortieren';

  @override
  String get meSpaceException => 'In diesem Space';

  @override
  String get meSpaceLastUsed => 'Zuletzt genutzt';

  @override
  String meSpaceNotifications(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Benachrichtigungen warten hier',
      one: '1 Benachrichtigung wartet hier',
    );
    return '$_temp0';
  }

  @override
  String get meSpaceOpen => 'Öffnen';

  @override
  String get meSpacePending => 'Wartet auf Freigabe';

  @override
  String get meSpacesNoMatch => 'Kein Space passt.';

  @override
  String get meSpacesSearch => 'Meine Spaces durchsuchen';

  @override
  String get meTabDiscover => 'Entdecken';

  @override
  String get meTabHome => 'Start';

  @override
  String get meTabMe => 'Ich';

  @override
  String get meTabMessages => 'Nachrichten';

  @override
  String get meWhereSpacesLive => 'Wo meine Spaces liegen';

  @override
  String get memberAccountTitle => 'Mein Konto';

  @override
  String get memberAllAdmins => 'alle Admins';

  @override
  String get memberApprove => 'Mitgliedschaft bestätigen';

  @override
  String memberBadgesTitle(String name) {
    return 'Badges — $name';
  }

  @override
  String get memberBadgesTooltip => 'Badges';

  @override
  String get memberCoOwnerChip => 'Mitinhaber';

  @override
  String get memberCoOwnerPassiveChip => 'Nachfolge';

  @override
  String get memberContactHeading => 'Kontakt';

  @override
  String get memberHomeSiteDefault => 'Adresse des Arbeitsbereichs';

  @override
  String get memberHomeSiteLabel => 'Heimatstandort';

  @override
  String memberInvoiceOpen(String amount) {
    return '$amount offen';
  }

  @override
  String get memberInvoicePaid => 'Bezahlt';

  @override
  String get memberInvoiceVoided => 'Storniert';

  @override
  String get memberInvoicesBanner =>
      'Alle Ihre Rechnungen und Zahlungen aus allen Arbeitsbereichen finden Sie unter Ich › Finanzen.';

  @override
  String get memberKioskLabel => 'Kiosk';

  @override
  String get memberMakeAdmin => 'Rolle Administrator:in geben';

  @override
  String get memberMakeKiosk => 'Zum Kiosk-Gerät machen';

  @override
  String get memberMakeMember => 'Rolle Administrator:in entziehen';

  @override
  String get memberMessagesAction => 'Nachrichten';

  @override
  String get memberMoneySettled => 'Nichts offen.';

  @override
  String get memberMoneyUnavailable =>
      'Finanzen konnten nicht geladen werden. Zum Aktualisieren ziehen.';

  @override
  String get memberMonthInProgress => 'Dieser Monat';

  @override
  String memberMoreInvoices(int count) {
    return '+$count weitere';
  }

  @override
  String get memberNoActions =>
      'Nur der Inhaber des Workspace kann dieses Mitglied ändern.';

  @override
  String get memberNoSubscription => 'Kein Abo';

  @override
  String get memberNoSubscriptionPaygHint =>
      'Kein Abo ist mit Bezahlung nach Verbrauch nicht möglich: zuerst Sperren oder ein Paket wählen.';

  @override
  String get memberNoteDelete => 'Löschen';

  @override
  String get memberNoteDeleteConfirm =>
      'Diese Nachricht löschen? Das lässt sich nicht rückgängig machen.';

  @override
  String get memberNoteDeleteNotMine =>
      'Nur der Absender kann eine Nachricht zurücknehmen.';

  @override
  String get memberNoteDeleteRead =>
      'Schon gelesen — diese Nachricht kann nicht mehr zurückgenommen werden.';

  @override
  String get memberNoteDeleted => 'Nachricht gelöscht.';

  @override
  String get memberNoteHint => 'Ihre Nachricht';

  @override
  String memberNoteReceived(String name) {
    return 'Nachricht von $name';
  }

  @override
  String get memberNoteReply => 'Antworten';

  @override
  String get memberNoteSend => 'Senden';

  @override
  String get memberNoteSent => 'Benachrichtigung gesendet.';

  @override
  String memberNoteTitle(String name) {
    return '$name benachrichtigen';
  }

  @override
  String memberNoteTo(String name) {
    return 'An $name';
  }

  @override
  String get memberNoteToAllAdmins => 'An alle Admins';

  @override
  String get memberNotifyAction => 'Benachrichtigung senden';

  @override
  String get memberNotifyAllAdmins => 'Alle Admins benachrichtigen';

  @override
  String get memberNumberLabel => 'Mitgliedsnummer';

  @override
  String get memberOriginDelegated => 'Profil von einem Admin angelegt';

  @override
  String get memberOriginFounder => 'Hat diesen Raum gegründet';

  @override
  String get memberOriginHeading => 'Wie diese Mitgliedschaft begann';

  @override
  String get memberOriginInvited => 'Per Einladung beigetreten';

  @override
  String get memberOveragePolicyLabel => 'Wenn die Tage aufgebraucht sind';

  @override
  String get memberOveragePolicyTooltip => 'Mehrverbrauch';

  @override
  String get memberPageAddService => 'Leistung hinzufügen';

  @override
  String memberPageCheckedIn(String seat, String time) {
    return 'Eingecheckt · $seat · seit $time';
  }

  @override
  String get memberPageEmailAction => 'E-Mail';

  @override
  String get memberPageGroupAccess => 'Ausweise & Zugang';

  @override
  String get memberPageGroupBilling => 'Abrechnung';

  @override
  String get memberPageGroupBooking => 'Buchungsregeln';

  @override
  String get memberPageGroupMembership => 'Mitgliedschaft';

  @override
  String get memberPageLevelTitle => 'Buchungen ganzer Bereiche';

  @override
  String get memberPageManageHeading => 'Verwalten';

  @override
  String get memberPageNeverSeen => 'Noch nie gesehen';

  @override
  String memberPageNext(String label) {
    return 'Nächste: $label';
  }

  @override
  String get memberPageNone => 'Keine';

  @override
  String get memberPageNowHeading => 'Gerade jetzt';

  @override
  String memberPageReservedNow(String seat, String time) {
    return 'Jetzt reserviert · $seat · bis $time';
  }

  @override
  String memberPageSince(String date) {
    return 'Mitglied seit $date';
  }

  @override
  String get memberPageStatusActive => 'Aktiv';

  @override
  String memberPageWorkspaceDefaultValue(int count) {
    return 'Workspace-Standard ($count)';
  }

  @override
  String memberPageYou(String name) {
    return '$name (Sie)';
  }

  @override
  String get memberPause => 'Mitgliedschaft pausieren';

  @override
  String get memberPayments => 'Zahlungen';

  @override
  String memberPlanShare(String pct) {
    return 'Tarif $pct %';
  }

  @override
  String get memberReactivate => 'Mitgliedschaft reaktivieren';

  @override
  String get memberRejectJoin => 'Mitgliedschaft ablehnen';

  @override
  String memberReservationLimitChip(int n) {
    return 'max. $n';
  }

  @override
  String get memberReservationLimitCustom => 'Individuell (1–100)';

  @override
  String get memberReservationLimitExplainer =>
      'Wie viele offene Reservierungen dieses Mitglied gleichzeitig halten darf.';

  @override
  String get memberReservationLimitLabel => 'Reservierungslimit';

  @override
  String get memberReservationLimitNone => 'Kein Limit';

  @override
  String get memberReservationLimitTooltip => 'Reservierungslimit';

  @override
  String get memberRoleAdmin => 'Administrator:in';

  @override
  String get memberRoleChangeRequested =>
      'Rollenwechsel zur Freigabe gesendet.';

  @override
  String get memberRoleMember => 'Mitglied';

  @override
  String get memberRoleOwner => 'Inhaber';

  @override
  String get memberRolesAdd => 'Rolle hinzufügen';

  @override
  String get memberRolesNone => 'Keine Rolle: alles, was ein Mitglied kann.';

  @override
  String get memberRolesTitle => 'Rollen';

  @override
  String get memberRolesWhatTheyCanDo => 'Was diese Person hier tun kann';

  @override
  String get memberSendAgreement => 'Finanzvereinbarung senden';

  @override
  String memberSimultaneousLimitChip(int n) {
    return '$n gleichzeitig';
  }

  @override
  String get memberSimultaneousLimitDefault => 'Vorgabe des Arbeitsraums';

  @override
  String get memberSimultaneousLimitExplainer =>
      'Wie viele Buchungen dieses Mitglied im selben Zeitraum halten darf. Ohne Angabe gilt die Vorgabe des Arbeitsraums.';

  @override
  String get memberSimultaneousLimitLabel => 'Gleichzeitige Reservierungen';

  @override
  String get memberStatusActive => 'Aktiv';

  @override
  String get memberStatusExited => 'Ausgetreten';

  @override
  String get memberStatusPaused => 'Pausiert';

  @override
  String get memberStatusPending => 'Ausstehend';

  @override
  String get memberSubscriptionCustom => 'Individuell (1–100)';

  @override
  String get memberSubscriptionLabel => 'Abo';

  @override
  String get memberUnmakeKiosk => 'Kiosk zu Mitglied zurücksetzen';

  @override
  String get memberVatTreatmentExplainer =>
      'Wer dieses Mitglied für die USt ist: die automatische Regel (Steuerschuldnerschaft des Empfängers für ein Unternehmen in einem anderen EU-Staat), Inlands-USt in jedem Fall, Steuerschuldnerschaft des Empfängers, außerhalb der EU oder ein befreiter Käufer mit dem auf der Rechnung gedruckten Grund.';

  @override
  String get memberVatTreatmentLabel => 'USt-Behandlung';

  @override
  String get membersInvite => 'Mitglied einladen';

  @override
  String get membersPlanNone => 'Kein Tarif';

  @override
  String get membersTitle => 'Mitglieder & Tarife';

  @override
  String get messageInfo => 'Nachrichteninfo';

  @override
  String get messageNotReadYet => 'Noch nicht gelesen';

  @override
  String get messageReadBy => 'Gelesen von';

  @override
  String get messageRequestsHint =>
      'Diese Personen gehören nicht zu denen, von denen Sie erreichbar sein wollten. Sie erfahren Ihre Entscheidung nicht.';

  @override
  String get messageRequestsTitle => 'Nachrichtenanfragen';

  @override
  String get messageSearchGroups => 'Gruppen';

  @override
  String get messageSearchHint => 'Mitglieder, Gruppen, Nachrichten';

  @override
  String get messageSearchMessages => 'Nachrichten';

  @override
  String get messageSearchNothing => 'Nichts gefunden.';

  @override
  String get messageSearchPeople => 'Mitglieder';

  @override
  String get messageSearchPrompt =>
      'Suchen Sie nach Mitgliedern, Gruppen und Gesagtem.';

  @override
  String get messageSearchTitle => 'Suchen';

  @override
  String get messagesEmpty => 'Noch keine Unterhaltungen.';

  @override
  String get messagesTitle => 'Nachrichten';

  @override
  String get messengerContextAccount => 'Von Person zu Person';

  @override
  String get messengerContextGroup => 'Gruppe';

  @override
  String messengerContextInquiryIn(String space) {
    return 'Anfrage an $space';
  }

  @override
  String messengerContextInquiryOut(String space) {
    return 'Ihre Anfrage an $space';
  }

  @override
  String messengerContextSpace(String space) {
    return 'In $space';
  }

  @override
  String get messengerCopied => 'Kopiert.';

  @override
  String get messengerCopy => 'Text kopieren';

  @override
  String get messengerDelete => 'Nachricht löschen';

  @override
  String get messengerDeleteConfirm =>
      'Diese Nachricht für alle in der Unterhaltung löschen?';

  @override
  String get messengerDeleted => 'Nachricht gelöscht.';

  @override
  String get messengerDelivered => 'Zugestellt';

  @override
  String get messengerEdit => 'Bearbeiten';

  @override
  String get messengerEditFailed =>
      'Die Nachricht konnte nicht bearbeitet werden — die 15 Minuten sind vielleicht vorbei.';

  @override
  String get messengerEditTitle => 'Nachricht bearbeiten';

  @override
  String get messengerEditWindow =>
      'Eine Nachricht kann 15 Minuten nach dem Senden korrigiert werden.';

  @override
  String get messengerEdited => 'bearbeitet';

  @override
  String messengerEventCaptured(String actor) {
    return 'Bildschirmfoto von $actor';
  }

  @override
  String messengerEventDeleted(String actor) {
    return 'Gelöscht von $actor';
  }

  @override
  String messengerEventForwarded(String actor, String target) {
    return 'Von $actor an $target weitergeleitet';
  }

  @override
  String messengerEventForwardedFrom(String actor, String context) {
    return 'Ursprünglich von $actor in $context geschrieben';
  }

  @override
  String messengerEventForwardedPrivate(String actor) {
    return 'Von $actor in eine persönliche Unterhaltung weitergeleitet';
  }

  @override
  String messengerEventOther(String event, String actor) {
    return '$event · $actor';
  }

  @override
  String messengerEventRead(String actor) {
    return 'Gelesen von $actor';
  }

  @override
  String messengerEventSent(String actor) {
    return 'Gesendet von $actor';
  }

  @override
  String get messengerForward => 'Weiterleiten';

  @override
  String get messengerForwardExplain =>
      'Alle in der ursprünglichen Unterhaltung, zuerst die Verfasserin oder der Verfasser, erfahren, wer sie wann und wohin weitergeleitet hat.';

  @override
  String get messengerForwardLocked =>
      'Die Verfasserin oder der Verfasser hat das Weiterleiten dieser Nachricht gesperrt.';

  @override
  String get messengerForwardNoTargets =>
      'Keine andere Unterhaltung auf diesem Server, in die weitergeleitet werden kann.';

  @override
  String get messengerForwardTitle => 'Weiterleiten an';

  @override
  String messengerForwarded(String target) {
    return 'An $target weitergeleitet.';
  }

  @override
  String messengerForwardedFrom(String context, String author) {
    return 'Weitergeleitet aus $context · geschrieben von $author';
  }

  @override
  String get messengerHistory => 'Was geschah';

  @override
  String get messengerHistoryEmpty =>
      'Zu dieser Nachricht ist noch nichts verzeichnet.';

  @override
  String get messengerHostsIntro =>
      'Ihre Nachricht lesen diese Gastgeber des Ortes:';

  @override
  String get messengerHostsNone =>
      'An diesem Ort beantwortet gerade niemand Nachrichten.';

  @override
  String messengerInboxUnavailable(String servers) {
    return 'Gerade nicht erreichbar: $servers. Deren Unterhaltungen fehlen in dieser Liste.';
  }

  @override
  String get messengerInquiriesEmpty => 'Noch keine Anfragen.';

  @override
  String get messengerInquiriesTitle => 'Anfragen';

  @override
  String get messengerInquiryClose => 'Anfrage abschließen';

  @override
  String get messengerInquiryClosed => 'Anfrage abgeschlossen.';

  @override
  String messengerInquiryFrom(String name) {
    return 'Von $name';
  }

  @override
  String get messengerInquirySend => 'Anfrage senden';

  @override
  String get messengerLock => 'Weiterleiten sperren';

  @override
  String get messengerMessageActions => 'Nachrichtenaktionen';

  @override
  String get messengerNoStarred => 'Noch keine markierte Nachricht.';

  @override
  String messengerNoticeCaptured(String actor) {
    return '$actor hat ein Bildschirmfoto dieser Unterhaltung aufgenommen.';
  }

  @override
  String messengerNoticeForwarded(String actor, String target) {
    return '$actor hat eine Nachricht dieser Unterhaltung an $target weitergeleitet.';
  }

  @override
  String messengerNoticeForwardedPrivate(String actor) {
    return '$actor hat eine Nachricht dieser Unterhaltung in eine persönliche Unterhaltung weitergeleitet.';
  }

  @override
  String messengerOnServer(String server) {
    return 'auf $server';
  }

  @override
  String get messengerRead => 'Gelesen';

  @override
  String get messengerRefusedClosed => 'Diese Anfrage ist abgeschlossen.';

  @override
  String get messengerRefusedForwardingOff =>
      'Dieser Ort erlaubt kein Weiterleiten seiner Nachrichten.';

  @override
  String get messengerRefusedLimit =>
      'Zu viele auf einmal. Bitte eine Minute warten.';

  @override
  String get messengerRefusedRequestPending =>
      'Ihre erste Nachricht wartet auf eine Antwort.';

  @override
  String get messengerRefusedTooLong =>
      'Diese Nachricht ist für diese Unterhaltung zu lang.';

  @override
  String get messengerRefusedUnavailable =>
      'Dieser Ort nimmt gerade keine Anfragen an.';

  @override
  String get messengerStar => 'Markieren';

  @override
  String get messengerStarred => 'Markiert';

  @override
  String get messengerUnlock => 'Weiterleiten erlauben';

  @override
  String get messengerUnstar => 'Markierung entfernen';

  @override
  String get messengerWriteToHosts => 'An die Gastgeber schreiben';

  @override
  String get mfaCode => 'Sechsstelliger Code';

  @override
  String get mfaEnroll =>
      'Scannen Sie diesen Code mit einer Authenticator-App oder geben Sie den Schlüssel ein, dann tippen Sie die sechs angezeigten Ziffern.';

  @override
  String get mfaTitle => 'Mit Ihrer Authenticator-App bestätigen';

  @override
  String get mfaVerify => 'Bestätigen';

  @override
  String get mfaWrong =>
      'Dieser Code wurde nicht akzeptiert. Versuchen Sie den aktuellen.';

  @override
  String get moneyAmountLabel => 'Betrag';

  @override
  String get moneyBalance => 'Saldo';

  @override
  String get moneyBaseFee => 'Basis-Abo';

  @override
  String get moneyCredits => 'Zahlungen & Gutschriften';

  @override
  String get moneyDescriptionLabel => 'Beschreibung';

  @override
  String get moneyDocumentLibrary => 'Dokumentbibliothek';

  @override
  String moneyDueIn(int days) {
    return 'Fällig in $days Tagen';
  }

  @override
  String get moneyExpenseCategoryLabel => 'Kategorie';

  @override
  String get moneyExpensePending =>
      'Ausgabe eingereicht — wartet auf Freigabe.';

  @override
  String get moneyFaceDocuments => 'Dokumente';

  @override
  String get moneyFaceInvoices => 'Rechnungen';

  @override
  String get moneyFacePayments => 'Zahlungen';

  @override
  String get moneyFaceStatement => 'Abrechnung';

  @override
  String get moneyFaceUsage => 'Nutzung';

  @override
  String get moneyLedgerEmpty => 'Noch keine Buchungen.';

  @override
  String get moneyLedgerHeader => 'Kontobuch';

  @override
  String get moneyMyAgreement => 'Meine Konditionen';

  @override
  String get moneyNoInvoicesYet =>
      'Noch keine Rechnung — der Monat wird nach Abschluss vom Workspace abgerechnet.';

  @override
  String get moneyNoteLabel => 'Notiz (optional)';

  @override
  String get moneyNothingOpen => 'Nichts offen — Sie sind auf dem Laufenden.';

  @override
  String moneyOpenInvoicesSummary(int count, String amount) {
    return '$count offen · $amount fällig';
  }

  @override
  String get moneyOpenInvoicesTitle => 'Offene Rechnungen';

  @override
  String moneyOverage(int count) {
    return 'Mehrnutzung ($count zusätzliche halbe Tage)';
  }

  @override
  String moneyOverdueBanner(int count, String amount) {
    return '$count überfällig — $amount zu begleichen';
  }

  @override
  String moneyOverdueBy(int days) {
    return 'Überfällig seit $days Tagen';
  }

  @override
  String get moneyPayNow => 'Jetzt zahlen';

  @override
  String get moneyPaymentDateLabel => 'Zahlungsdatum';

  @override
  String get moneyPaymentPending =>
      'Zahlung eingereicht — wartet auf Bestätigung.';

  @override
  String get moneyPaymentPeriodLabel => 'Gilt für';

  @override
  String get moneyRecordPayment => 'Zahlung erfassen';

  @override
  String moneyRemindedTimes(int count) {
    return 'Gemahnt ×$count';
  }

  @override
  String get moneySectionDocuments => 'Dokumente';

  @override
  String get moneySectionPay => 'Zahlen';

  @override
  String get moneySectionRequests => 'Anträge';

  @override
  String get moneyStatementOpen => 'Offen';

  @override
  String get moneyStatementPdf => 'Monatsabrechnung (PDF)';

  @override
  String get moneyStatementSettled => 'Beglichen';

  @override
  String get moneySubmitExpense => 'Ausgabe einreichen';

  @override
  String get moneySubmitPayment => 'Zur Bestätigung einreichen';

  @override
  String moneySubscriptionPct(int pct) {
    return 'Abo $pct %';
  }

  @override
  String moneyUsage(int used, int included) {
    return '$used von $included halben Tagen genutzt';
  }

  @override
  String moneyUsageUnlimited(int used) {
    return '$used halbe Tage genutzt';
  }

  @override
  String monthFreeCount(int free, int total) {
    return '$free/$total';
  }

  @override
  String get myBadgeTitle => 'Mein Badge';

  @override
  String get myInvoicesTitle => 'Meine Rechnungen';

  @override
  String get myVisitsHelp =>
      'Besuche, die Sie als Gast angefragt haben oder zu denen Sie zugelassen wurden. Ein Besuch ist keine Mitgliedschaft.';

  @override
  String get myVisitsTitle => 'Meine Besuche';

  @override
  String get navigationClassic =>
      'Klassisch: die untere Leiste und der runde Knopf';

  @override
  String get navigationDefault => 'Standard für dieses Gerät';

  @override
  String get navigationMenu => 'Menü: das Hamburger-Menü wie im Web';

  @override
  String get navigationTitle => 'Navigation';

  @override
  String negotiationActiveSince(String month) {
    return 'Ihre Konditionen gelten seit $month.';
  }

  @override
  String get negotiationCardTitle => 'Meine verhandelten Preise';

  @override
  String get negotiationDefaultColumn => 'Tarif';

  @override
  String get negotiationDiscount => 'Rabatt auf Zuschläge';

  @override
  String get negotiationFee => 'Monatsbeitrag';

  @override
  String get negotiationItems => 'Leistungen und Pakete';

  @override
  String get negotiationItemsHint =>
      'Ein Stückpreis für dieses Mitglied; leer behält den Katalog.';

  @override
  String get negotiationKeepCurrent => 'Aktuelle behalten';

  @override
  String get negotiationMineColumn => 'Meine';

  @override
  String get negotiationNote => 'Notiz';

  @override
  String get negotiationOccupation => 'Auslastung';

  @override
  String get negotiationOccupationHint =>
      'Der Anteil der Öffnungstage, der monatlich enthalten ist; nach Prüfung auf das Mitglied angewendet.';

  @override
  String get negotiationOnTariff => 'Sie sind auf dem Tarif des Workspace.';

  @override
  String get negotiationOverage => 'Überschreitung je halben Tag';

  @override
  String get negotiationPending => 'Konditionen warten auf Prüfung.';

  @override
  String get negotiationPendingBadge => 'wartet auf Prüfung';

  @override
  String negotiationPercent(int value) {
    return '$value %';
  }

  @override
  String get negotiationProposeHint =>
      'Ein leeres Feld behält den Tarif. Die Konditionen durchlaufen die Prüfung, bevor sie gelten.';

  @override
  String get negotiationProposeTitle => 'Preisverhandlung';

  @override
  String get negotiationProposed =>
      'Konditionen vorgeschlagen — warten auf Prüfung.';

  @override
  String get negotiationReadOnly => 'Nur lesen';

  @override
  String get negotiationSubmit => 'Zur Prüfung vorschlagen';

  @override
  String get negotiationValidFrom => 'Gilt ab';

  @override
  String get negotiationWhoCanSee => 'Wer das sehen kann';

  @override
  String get newConversationGroupSwitch => 'Gruppe';

  @override
  String get newConversationNoMembers => 'Noch niemand sonst hier.';

  @override
  String get newConversationSearch => 'Mitglieder suchen';

  @override
  String get newConversationStart => 'Chat starten';

  @override
  String get newConversationTapToOpen =>
      'Tippen Sie auf eine Person, um den Chat zu öffnen; schalten Sie Gruppe ein, um mehrere zu wählen.';

  @override
  String get newConversationTitle => 'Neue Unterhaltung';

  @override
  String get newGroupCreate => 'Gruppe erstellen';

  @override
  String get newGroupName => 'Gruppenname';

  @override
  String get newGroupNameTaken =>
      'Eine Gruppe mit diesem Namen gibt es hier schon. Wählen Sie einen anderen.';

  @override
  String get newMemberDefaultsConfigured =>
      'Womit jemand startet, der beitritt.';

  @override
  String get newMemberDefaultsTitle => 'Neue Mitglieder';

  @override
  String get newMemberDefaultsUnavailable =>
      'Diese konnten gerade nicht gelesen werden. Das Speichern lässt sie unverändert.';

  @override
  String get newMemberDefaultsUnset =>
      'Nichts gewählt — neue Mitglieder starten mit 100 %, Buchungen werden gesperrt, sobald das Kontingent aufgebraucht ist.';

  @override
  String get newMemberOverageBlocked => 'Gesperrt, sobald aufgebraucht';

  @override
  String get newMemberOveragePackage => 'Muss ein Paket kaufen';

  @override
  String get newMemberOveragePayg => 'Nutzungsabhängig zahlen';

  @override
  String get newMemberSubscription => 'Abonnement';

  @override
  String get newMemberSubscriptionLess => 'Kleineres Abonnement';

  @override
  String get newMemberSubscriptionMore => 'Größeres Abonnement';

  @override
  String newMemberSubscriptionValue(int percent) {
    return '$percent %';
  }

  @override
  String get nfcConfigChecking => 'Wird geprüft…';

  @override
  String get nfcConfigDeviceOff =>
      'NFC ist in den Android-Einstellungen dieses Geräts ausgeschaltet — zum Lesen von RFID-Karten einschalten.';

  @override
  String get nfcConfigDeviceReady => 'NFC verfügbar und aktiviert';

  @override
  String get nfcConfigDeviceStatus => 'Dieses Gerät';

  @override
  String get nfcConfigDeviceUnavailable =>
      'Hier kein NFC — ein Android-Gerät mit aktiviertem NFC ist nötig (iPads haben kein NFC). QR-Badges funktionieren weiter.';

  @override
  String get nfcConfigEnable => 'NFC-Badge-Check-in aktivieren';

  @override
  String get nfcConfigEnableDesc =>
      'Zeigt die Karten-Antipp-Option an Kiosken und im Badge-Manager.';

  @override
  String get nfcConfigIntro =>
      'Mitglieder checken an einem Wandtablet per RFID/NFC-Karte ein. Registrieren Sie die Karte jedes Mitglieds unter Mitglieder & Tarife; am Kiosk halten sie die Karte an, um zu reservieren oder einzuchecken.';

  @override
  String get nfcConfigTitle => 'RFID-/NFC-Badges';

  @override
  String get noteRefAlert => 'Hinweis';

  @override
  String noteRefFilterCount(int shown, int total) {
    return '$shown von $total';
  }

  @override
  String get noteRefFilterEmpty => 'Keine Treffer.';

  @override
  String get noteRefFilterLabel => 'Filtern';

  @override
  String get noteRefGone => 'Diese Reservierung existiert nicht mehr.';

  @override
  String get noteRefInvoice => 'Rechnung';

  @override
  String get noteRefNoReservations =>
      'Keine kommenden Reservierungen zum Verknüpfen.';

  @override
  String get noteRefNone => 'Noch nichts zum Verweisen.';

  @override
  String get noteRefPayment => 'Zahlung';

  @override
  String get noteRefPickAlert => 'Welcher Hinweis?';

  @override
  String get noteRefPickInvoice => 'Welche Rechnung?';

  @override
  String get noteRefPickPayment => 'Welche Zahlung?';

  @override
  String get noteRefPickValidation => 'Welche Freigabe?';

  @override
  String get noteRefRefund => 'Erstattung';

  @override
  String get noteRefReservation => 'Reservierung verknüpfen';

  @override
  String get noteRefSpace => 'Raum verknüpfen';

  @override
  String get noteRefValidation => 'Freigabe';

  @override
  String get noteRefWholeLevel => 'ganze Etage';

  @override
  String get notesFilterEmpty =>
      'Keine ungelesenen Nachrichten — alles gelesen.';

  @override
  String get notesFilterRead => 'Gelesen';

  @override
  String get notesFilterUnread => 'Ungelesen';

  @override
  String get notifCategoryCheckIns => 'Check-ins';

  @override
  String get notifCategoryMembers => 'Mitglieder';

  @override
  String get notifCategoryMoney => 'Finanzen';

  @override
  String get notifGroupBy => 'Gruppieren nach';

  @override
  String get notifGroupByDate => 'Datum';

  @override
  String get notifGroupByType => 'Typ';

  @override
  String get notifGroupByUser => 'Mitglied';

  @override
  String get notifSortByDate => 'Nach Datum sortieren';

  @override
  String get notifUngroup => 'Gruppierung aufheben';

  @override
  String get notificationsSystemOff =>
      'Android blockiert DesKilo-Benachrichtigungen';

  @override
  String get notificationsSystemOffHint =>
      'Erlauben Sie sie unter System-Einstellungen → Apps → DesKilo → Benachrichtigungen — das Icon-Badge braucht sie.';

  @override
  String get numberSequenceDateNone => 'Keins';

  @override
  String get numberSequenceDatePart => 'Datum';

  @override
  String get numberSequenceDateRemovalBlocked =>
      'Mit dem Datum wurden bereits Nummern vergeben. Es zu entfernen könnte eine wiederholen – ändern Sie auch Präfix oder Suffix.';

  @override
  String get numberSequenceDateYear => 'Jahr';

  @override
  String get numberSequenceDateYearMonth => 'Jahr-Monat';

  @override
  String get numberSequenceDigits => 'Stellen';

  @override
  String get numberSequenceGapless => 'Lückenlos — garantiert';

  @override
  String get numberSequenceJournalCreditNote => 'Gutschriften';

  @override
  String get numberSequenceJournalInvoice => 'Rechnungen';

  @override
  String get numberSequenceJournalMember => 'Mitglieder';

  @override
  String get numberSequenceJournalPayment => 'Zahlungen';

  @override
  String get numberSequenceJournalVatDeclaration => 'USt-Voranmeldungen';

  @override
  String get numberSequenceNext => 'Nächste Nummer';

  @override
  String get numberSequencePrefix => 'Präfix';

  @override
  String get numberSequenceReset => 'Neustart';

  @override
  String get numberSequenceResetLimited =>
      'Eine Nummer beginnt höchstens so oft neu, wie sie ihr Datum zeigt – sonst würde sie eine frühere Nummer erneut vergeben.';

  @override
  String get numberSequenceResetMonthly => 'Monatlich';

  @override
  String get numberSequenceResetNever => 'Nie';

  @override
  String get numberSequenceResetWasInvalid =>
      'Diese Serie begann öfter neu, als sie ihr Datum zeigt. Speichern Sie, um einen Neustart zu behalten, der keine Nummer wiederholt.';

  @override
  String get numberSequenceResetYearly => 'Jährlich';

  @override
  String get numberSequenceSaved => 'Nummernkreis gespeichert.';

  @override
  String get numberSequenceSuffix => 'Suffix';

  @override
  String get numberSequencesIntro =>
      'Ein Kreis je Journal, lückenlos: Die Nummer wird in der Datenbank genommen, sobald der Beleg ausgestellt wird, und ein Beleg, der scheitert, verbraucht nichts. Eine Formatänderung berührt nie einen bereits ausgestellten Beleg.';

  @override
  String get numberSequencesSubtitle =>
      'Wie Rechnungen und Gutschriften nummeriert werden.';

  @override
  String get numberSequencesTitle => 'Nummernkreise';

  @override
  String get occurrenceAdded => 'Zu Ihren Ausgaben hinzugefügt.';

  @override
  String get occurrenceConfirm => 'Diese Ausgabe bestätigen';

  @override
  String get occurrenceReasonLabel => 'Warum es abweicht (Pflicht)';

  @override
  String get occurrenceReasonMissing =>
      'Ein abweichender Betrag braucht eine Erklärung.';

  @override
  String get occurrenceRejected =>
      'Die Validierer haben sie abgelehnt — Betrag oder Beschreibung anpassen und erneut senden.';

  @override
  String get occurrenceResend => 'Erneut zur Validierung senden';

  @override
  String occurrenceScheduledAmount(Object amount) {
    return 'Validiert: $amount';
  }

  @override
  String get occurrenceSentForValidation =>
      'An die Validierer gesendet — es zählt nach ihrer Bestätigung.';

  @override
  String get officeSupplementLabel => 'Büro-Reservierungen';

  @override
  String get onboardingConfirmIntro => 'Das wird erstellt:';

  @override
  String get onboardingCreateButton => 'Workspace erstellen';

  @override
  String get onboardingCreateTab => 'Workspace erstellen';

  @override
  String get onboardingCreateWithoutTemplate => 'Ohne Vorlage erstellen';

  @override
  String get onboardingCurrencyUnknown =>
      'Geben Sie einen unterstützten Währungscode ein, z. B. EUR';

  @override
  String get onboardingDiscardDraft =>
      'Die Eingaben gehen verloren. Eine bereits gesendete Anfrage wird dadurch nicht storniert.';

  @override
  String get onboardingIntentChanged =>
      'Ihre frühere Anfrage wurde möglicherweise bereits ausgeführt. Wiederholen Sie sie genau wie gesendet, bevor Sie etwas ändern.';

  @override
  String get onboardingIntentResumed =>
      'Eine frühere Erstellung ist möglicherweise durchgegangen. Wiederholen Sie, um dieselbe Anfrage zu prüfen.';

  @override
  String get onboardingJoinButton => 'Beitreten';

  @override
  String get onboardingJoinTab => 'Workspace beitreten';

  @override
  String get onboardingRetryAsSent => 'Wie gesendet wiederholen';

  @override
  String get onboardingScanButton => 'QR-Code scannen';

  @override
  String get onboardingShapeLabel => 'Was erstellt wird';

  @override
  String get onboardingShapePair => 'Ein verknüpftes Test- und Echt-Paar';

  @override
  String get onboardingShapeReal => 'Ein echter Arbeitsbereich';

  @override
  String get onboardingShapeRealHint =>
      'Für den echten Betrieb: Die ausgestellten Rechnungen sind geschuldet.';

  @override
  String get onboardingShapeTest => 'Ein Test-Arbeitsbereich';

  @override
  String get onboardingShapeTestHint =>
      'Sicher zum Ausprobieren: Jeder Bildschirm und jedes Dokument zeigt, dass es ein Test ist. Keine echte Abrechnung.';

  @override
  String get onboardingStartEmpty => 'Leerer Raum';

  @override
  String get onboardingStartEmptyDesc =>
      'Zeichnen Sie Ihren eigenen Plan auf einer leeren Fläche.';

  @override
  String get onboardingStartFrom => 'Beginnen mit';

  @override
  String get onboardingStepConfirm => 'Bestätigen';

  @override
  String get onboardingStepName => 'Name';

  @override
  String get onboardingStepWhere => 'Wo';

  @override
  String get onboardingSummaryBillingOff =>
      'Keine echte Abrechnung: Dokumente sind als Test markiert.';

  @override
  String get onboardingSummaryBillingOn =>
      'Echte Abrechnung ist möglich: Die Rechnungen sind geschuldet.';

  @override
  String onboardingSummaryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Erstellt $count Arbeitsbereiche',
      one: 'Erstellt einen Arbeitsbereich',
    );
    return '$_temp0';
  }

  @override
  String onboardingSummaryServer(String host) {
    return 'Auf dem Server $host';
  }

  @override
  String onboardingTemplateSetsUp(String groups) {
    return 'Richtet ein: $groups';
  }

  @override
  String get onboardingTemplatesFailedEmpty =>
      'Die Vorlagen konnten nicht geladen werden, daher würde dieser Bereich leer beginnen. Gehen Sie zurück, um es erneut zu versuchen.';

  @override
  String get onboardingTitle => 'Willkommen bei DesKilo';

  @override
  String get onboardingUnconfirmed =>
      'Das Ergebnis konnte nicht bestätigt werden. Die Eingaben bleiben erhalten. Erneut versuchen prüft dieselbe Anfrage.';

  @override
  String get onboardingUseSuggested => 'Vorgeschlagene Einstellungen verwenden';

  @override
  String get onboardingWithTwin =>
      'Das Paar Entwicklung und Produktion anlegen';

  @override
  String get onboardingWithTwinHint =>
      'Zwei Räume gleichen Namens: einer zum Ausprobieren, einer, der echt ist. Beide gehören Ihnen.';

  @override
  String get overagePolicyBlocked => 'Weitere Buchung sperren';

  @override
  String get overagePolicyPackage => 'Paketkauf verlangen';

  @override
  String get overagePolicyPayg => 'Mehrverbrauch berechnen (nach Verbrauch)';

  @override
  String get payConfigConfigured => 'Eingerichtet';

  @override
  String get payConfigIntro =>
      'Geben Sie jeden Zahlungsanbieter ein, den Sie anbieten wollen. Schlüssel werden sicher auf dem Server gespeichert und nie wieder angezeigt.';

  @override
  String get payConfigNotConfigured => 'Nicht eingerichtet';

  @override
  String get payConfigOpen => 'Einrichten';

  @override
  String get payConfigRemove => 'Entfernen';

  @override
  String get payConfigRemoved => 'Entfernt.';

  @override
  String get payConfigSaved => 'Gespeichert.';

  @override
  String get payConfigSecretSet => 'Gesetzt — leer lassen zum Behalten';

  @override
  String get payConfigTitle => 'Online-Zahlungen';

  @override
  String get payFieldApiKey => 'API-Schlüssel';

  @override
  String get payFieldClientId => 'Client-ID';

  @override
  String get payFieldEnv => 'Umgebung';

  @override
  String get payFieldReturnUrl => 'Rückkehr-URL';

  @override
  String get payFieldSecret => 'Secret';

  @override
  String get payFieldSecretKey => 'Secret Key';

  @override
  String get payFieldWebhookId => 'Webhook-ID';

  @override
  String get payFieldWebhookSecret => 'Webhook-Signaturgeheimnis';

  @override
  String get payOnlineButton => 'Online bezahlen';

  @override
  String get payOnlineChooseTitle => 'Online bezahlen';

  @override
  String get payOnlineDiagHint => 'Auf dem Server fehlt diese Konfiguration:';

  @override
  String get payOnlineDiagTitle => 'Online-Zahlungen — nicht konfiguriert';

  @override
  String payOnlineFailedDetail(
    String reference,
    String amount,
    String provider,
  ) {
    return 'Die Zahlung $reference ($amount über $provider) wurde nicht abgeschlossen — nichts wurde gutgeschrieben; der Saldo bleibt offen.';
  }

  @override
  String get payOnlineFailedTitle => 'Online-Zahlung fehlgeschlagen';

  @override
  String get payOnlineNotConfigured =>
      'Online-Zahlungen sind noch nicht eingerichtet. Fragen Sie den Inhaber des Workspace.';

  @override
  String payOnlinePendingDetail(
    String reference,
    String amount,
    String provider,
  ) {
    return 'Die Zahlung $reference ($amount über $provider) wurde vom Anbieter noch nicht bestätigt, daher zeigt der Saldo weiterhin den offenen Betrag. Nennen Sie diese Referenz, falls sie nicht eingeht.';
  }

  @override
  String get payOnlinePendingTitle => 'Online-Zahlung ausstehend';

  @override
  String get paymentAccountNumberLabel => 'Kontonummer';

  @override
  String get paymentBankCodeLabel => 'Bankleitzahl';

  @override
  String get paymentBankNameLabel => 'Bankname';

  @override
  String get paymentBicLabel => 'BIC / SWIFT';

  @override
  String get paymentCopied => 'Kopiert.';

  @override
  String get paymentInstructionsHelper =>
      'Wird Mitgliedern auf einer offenen Abrechnung angezeigt. Leer lassen, um nichts anzuzeigen.';

  @override
  String get paymentInstructionsIbanCopied => 'IBAN kopiert.';

  @override
  String get paymentInstructionsIbanTitle => 'IBAN';

  @override
  String get paymentInstructionsLydiaLabel =>
      'Lydia-Telefonnummer oder -Nutzername';

  @override
  String get paymentInstructionsPaypalLabel => 'PayPal.me-Link oder -Name';

  @override
  String get paymentInstructionsReferenceLabel =>
      'Hinweis zum Verwendungszweck';

  @override
  String get paymentInstructionsTitle => 'Zahlungshinweise';

  @override
  String get paymentInstructionsValueCopied => 'In die Zwischenablage kopiert.';

  @override
  String get paymentInstructionsWeroLabel => 'Wero-Telefonnummer';

  @override
  String get paymentInstructionsWiseLabel => 'Wisetag oder Wise-Zahlungslink';

  @override
  String get paymentMethodBankTransfer => 'Überweisung';

  @override
  String get paymentMethodCard => 'Karte';

  @override
  String get paymentMethodCash => 'Bar';

  @override
  String get paymentMethodLydia => 'Lydia';

  @override
  String get paymentMethodOther => 'Sonstiges';

  @override
  String get paymentMethodPaypal => 'PayPal';

  @override
  String get paymentMethodTwint => 'TWINT';

  @override
  String get paymentMethodWero => 'Wero';

  @override
  String get paymentMethodWise => 'Wise';

  @override
  String get paymentMethodsSubtitle =>
      'IBAN, PayPal, Wero, Lydia, Wise und der Verwendungszweck';

  @override
  String get paymentProviderMollie => 'Mollie — iDEAL, Bancontact…';

  @override
  String get paymentProviderStripe => 'Kreditkarte (Stripe)';

  @override
  String get paymentProviderWero => 'Wero (über Mollie)';

  @override
  String get paymentRemindersWhen =>
      'Wann es läuft: jeden Morgen auf dem Server, sofern die Installation Aufgaben plant (pg_cron); sonst, wenn eine Verwaltungsperson Finanzen öffnet. Der Betreiber Ihres Servers weiß, was zutrifft.';

  @override
  String get paymentRoutingNumberLabel => 'Routing number';

  @override
  String get paymentSortCodeLabel => 'Sort code';

  @override
  String get paymentTermsEdit => 'Änderung beantragen';

  @override
  String get paymentTermsFieldEscompte => 'Skonto';

  @override
  String get paymentTermsFieldLatePenalty => 'Verzugszinsen';

  @override
  String get paymentTermsFieldRecovery => 'Mahnpauschale';

  @override
  String get paymentTermsFieldTerms => 'Zahlungsziel';

  @override
  String get paymentTermsInherit => 'die Standardbedingungen des Space';

  @override
  String get paymentTermsInherited => 'Standard des Space';

  @override
  String get paymentTermsMemberNote =>
      'Diese Bedingungen legt der Space fest; eine Änderung durchläuft seine Bestätigung.';

  @override
  String get paymentTermsNone => 'Noch keine Bedingungen';

  @override
  String get paymentTermsOverridden => 'Eigene des Mitglieds';

  @override
  String get paymentTermsReason => 'Grund (optional)';

  @override
  String get paymentTermsRequestHint =>
      'Ein leeres Feld behält den Wortlaut des Space. Die Änderung gilt nach der Bestätigung.';

  @override
  String get paymentTermsRequestTitle =>
      'Änderung der Zahlungsbedingungen beantragen';

  @override
  String get paymentTermsRequested =>
      'Änderung beantragt — Bestätigung ausstehend';

  @override
  String get paymentTermsSubmit => 'Antrag senden';

  @override
  String get paymentTermsTitle => 'Zahlungsbedingungen';

  @override
  String get paymentTermsUseDefault =>
      'Wieder den Standard des Space verwenden';

  @override
  String get paymentTransitNumberLabel => 'Transit · Institution';

  @override
  String get paymentsPendingTag => 'wartet auf Validierung';

  @override
  String pendingApprovalBody(String workspace) {
    return 'Sie sind $workspace beigetreten. Ein Admin muss Ihre Mitgliedschaft bestätigen, bevor Sie den Workspace nutzen können — Sie erhalten Zugriff, sobald sie bestätigt ist.';
  }

  @override
  String get pendingApprovalRefresh => 'Erneut prüfen';

  @override
  String get pendingApprovalTitle =>
      'Mitgliedschaft im Bereich wartet auf Freigabe';

  @override
  String get pendingAvailable =>
      'Während Sie warten, bleiben Ihre anderen Bereiche, Ihr Konto und die Hilfe verfügbar.';

  @override
  String get pendingHelp => 'Hilfe';

  @override
  String pendingLastChecked(String time) {
    return 'Zuletzt geprüft $time';
  }

  @override
  String get pendingNotUpdated =>
      'Status nicht aktualisiert — der Server ist nicht erreichbar. Ihre Anfrage bleibt unverändert.';

  @override
  String get pendingStillWaiting => 'Wartet weiter auf Freigabe.';

  @override
  String get pendingSwitchWorkspace => 'Bereich wechseln';

  @override
  String percentValue(int value) {
    return '$value %';
  }

  @override
  String get permAccessProd => 'Den Produktionsraum betreten';

  @override
  String get permApproveExpenses => 'Ausgaben genehmigen';

  @override
  String get permDeployToDev => 'In die Entwicklung ausrollen';

  @override
  String get permDeployToProd => 'In die Produktion ausrollen';

  @override
  String get permDesignDocuments => 'Dokumente gestalten';

  @override
  String get permExportData => 'Buchhaltung und Daten exportieren';

  @override
  String get permIssueInvoices => 'Rechnungen ausstellen & Zahlungen zuordnen';

  @override
  String get permMakeReservations => 'Buchen und Reservierungen nutzen';

  @override
  String get permManageBilling => 'Tarife und Abrechnungsregeln verwalten';

  @override
  String get permManageConfiguration => 'Konfiguration verwalten';

  @override
  String get permManageDocuments => 'Dokumentbibliothek verwalten';

  @override
  String get permManageIntegrations => 'Integrationen verwalten';

  @override
  String get permManageMembers => 'Mitglieder verwalten';

  @override
  String get permManageNegotiations => 'Geschäftsvereinbarungen verwalten';

  @override
  String get permManageReservations => 'Reservierungen anderer verwalten';

  @override
  String get permManageRoles => 'Rollen & Berechtigungen verwalten';

  @override
  String get permManageServices => 'Services & Pakete verwalten';

  @override
  String get permManageSites =>
      'Standorte verwalten und den Grundriss bearbeiten';

  @override
  String get permManageValidation => 'Validierungsregeln konfigurieren';

  @override
  String get permOperateKiosk => 'Kiosk und Badges bedienen';

  @override
  String get permPaymentTermsEdit =>
      'Änderung der Zahlungsbedingungen beantragen';

  @override
  String get permUseMessages => 'Den Messenger nutzen';

  @override
  String get permViewAnalytics => 'Kennzahlen des Arbeitsbereichs lesen';

  @override
  String get permViewCalendar => 'Den Kalender sehen';

  @override
  String get permViewDirectory => 'Das Mitgliederverzeichnis sehen';

  @override
  String get permViewDocuments => 'Die geteilten Dokumente sehen';

  @override
  String get permViewFinances => 'Workspace-Finanzen einsehen';

  @override
  String get permViewMyMoney =>
      'Das eigene Konto und die eigenen Rechnungen sehen';

  @override
  String get permViewNegotiations => 'Geschäftsvereinbarungen einsehen';

  @override
  String get permViewPersonalData => 'Persönliche Daten der Mitglieder lesen';

  @override
  String get permWorkspaceSettings => 'Workspace-Einstellungen bearbeiten';

  @override
  String get personalInfoCity => 'Ort';

  @override
  String get personalInfoCompany => 'Firma (optional)';

  @override
  String get personalInfoCountry => 'Land';

  @override
  String get personalInfoEmail => 'E-Mail für Dokumente';

  @override
  String get personalInfoFirstName => 'Vorname';

  @override
  String get personalInfoLastName => 'Nachname';

  @override
  String get personalInfoLegalId => 'Handelsregister / Kennung (optional)';

  @override
  String get personalInfoNone => 'Noch nicht ausgefüllt';

  @override
  String get personalInfoPhone => 'Telefon';

  @override
  String get personalInfoPostalCode => 'Postleitzahl';

  @override
  String get personalInfoPreview => 'Auf Ihren Dokumenten';

  @override
  String get personalInfoSave => 'Speichern';

  @override
  String get personalInfoSaved => 'Persönliche Angaben gespeichert';

  @override
  String get personalInfoStreet => 'Straße und Hausnummer';

  @override
  String get personalInfoSubtitle =>
      'Werden auf Ihren Rechnungen und Briefen gedruckt. Der Nachname erscheint in Großbuchstaben wie auf amtlicher Post.';

  @override
  String get personalInfoTitle => 'Persönliche Angaben';

  @override
  String get personalInfoVatId => 'USt-IdNr. (optional)';

  @override
  String placeFeedbackAverage(String average, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Bewertungen',
      one: '1 Bewertung',
    );
    return '$average · $_temp0';
  }

  @override
  String get placeFeedbackFailed =>
      'Speichern nicht möglich. Bitte erneut versuchen.';

  @override
  String get placeFeedbackFavorite => 'Zu Favoriten hinzufügen';

  @override
  String get placeFeedbackNoRating => 'Noch keine Bewertung';

  @override
  String placeFeedbackStars(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Sterne',
      one: '1 Stern',
    );
    return '$_temp0';
  }

  @override
  String get placeFeedbackUnfavorite => 'Aus Favoriten entfernen';

  @override
  String get placeFeedbackZero => '0 Sterne';

  @override
  String get planAccessorySupplementHint => 'Aufpreise gelten pro halbem Tag.';

  @override
  String get planActiveLabel => 'Aktiv';

  @override
  String get planAfternoonChip => 'Nachmittag';

  @override
  String get planAvailabilityLoading => 'Öffnungstage werden geprüft…';

  @override
  String get planBaseFeeLabel => 'Monatliche Grundgebühr';

  @override
  String get planBookForLabel => 'Buchen für';

  @override
  String planBookedForPending(String name) {
    return 'Zur Bestätigung an $name gesendet.';
  }

  @override
  String get planCancelReservationButton => 'Reservierung stornieren';

  @override
  String planCappedByNext(String time) {
    return 'Der Platz ist ab $time reserviert.';
  }

  @override
  String get planCheckInButton => 'Einchecken';

  @override
  String get planCheckInFailed =>
      'Einchecken nicht möglich — der Platz wurde eventuell gerade belegt.';

  @override
  String planCheckInFor(String name) {
    return '$name einchecken';
  }

  @override
  String get planCheckInNotYetError =>
      'Einchecken ist ab 15 Minuten vor Beginn möglich.';

  @override
  String planCheckInOpensAt(String time) {
    return 'Einchecken ab $time möglich';
  }

  @override
  String planCheckInOpensOn(String date) {
    return 'Check-in öffnet am $date';
  }

  @override
  String get planCheckInOverError =>
      'Diese Reservierung ist vorbei — Einchecken ist nicht mehr möglich.';

  @override
  String get planCheckInTitle => 'Einchecken';

  @override
  String get planCheckOutButton => 'Auschecken';

  @override
  String planCheckOutFor(String name) {
    return '$name auschecken';
  }

  @override
  String get planClosedDay => 'An diesem Tag geschlossen';

  @override
  String get planClosedDayError =>
      'Der Workspace ist an diesem Tag geschlossen.';

  @override
  String planClosedDayShowNext(String day) {
    return '$day anzeigen';
  }

  @override
  String get planDurationLabel => 'Dauer';

  @override
  String get planEndBeforeStart => 'Das Ende muss nach dem Beginn liegen.';

  @override
  String get planFromLabel => 'Von';

  @override
  String get planFullDayChip => 'Ganzer Tag';

  @override
  String get planFullDayError => 'Buchungen umfassen hier den ganzen Tag.';

  @override
  String get planHalfDayError => 'Buchungen erfolgen hier pro halbem Tag.';

  @override
  String get planIncludedHelper => 'Leer lassen für unbegrenzt';

  @override
  String get planIncludedLabel => 'Enthaltene Halbtage';

  @override
  String get planLevelLabel => 'Etage';

  @override
  String get planLevelTooltip => 'Etage';

  @override
  String get planListViewTooltip => 'Listenansicht';

  @override
  String get planMakeNotReservable => 'Nicht reservierbar machen';

  @override
  String get planMakeReservable => 'Reservierbar machen';

  @override
  String get planMapViewTooltip => 'Planansicht';

  @override
  String get planMorningChip => 'Vormittag';

  @override
  String get planNameLabel => 'Name';

  @override
  String get planNoLevels => 'Der Workspace hat noch keinen Plan.';

  @override
  String get planNoSeats => 'Diese Etage hat noch keine Plätze.';

  @override
  String get planNowButton => 'Jetzt';

  @override
  String planOccupiedBy(String name) {
    return 'Besetzt von $name';
  }

  @override
  String get planOverageLabel => 'Preis pro zusätzlichem Halbtag';

  @override
  String planOverruleDone(String name) {
    return 'Reservierung entfernt — $name wurde benachrichtigt.';
  }

  @override
  String planOverruleHint(String name) {
    return '$name und alle Admins werden benachrichtigt.';
  }

  @override
  String get planOverruleRemove => 'Reservierung entfernen (übersteuern)';

  @override
  String get planRepeatLabel => 'Wiederholen';

  @override
  String get planReservationsEmpty => 'Keine Reservierungen für diesen Tag.';

  @override
  String get planReserveButton => 'Reservieren';

  @override
  String planReservedBy(String name) {
    return 'Reserviert von $name';
  }

  @override
  String get planSeatBlocked => 'Dieser Platz ist wegen Wartung gesperrt.';

  @override
  String get planSendForConfirmation => 'Zur Bestätigung senden';

  @override
  String planSlotError(int minutes) {
    return 'Buchungen müssen im $minutes-Minuten-Raster beginnen und enden.';
  }

  @override
  String get planStartNow => 'Beginnt jetzt';

  @override
  String planStartsAt(String time) {
    return 'Beginnt um $time';
  }

  @override
  String get planStateFree => 'Frei';

  @override
  String get planStateYours => 'Ihrer';

  @override
  String get planToLabel => 'Bis';

  @override
  String planUntil(String time) {
    return 'bis $time';
  }

  @override
  String get planUntilDateLabel => 'Wiederholen bis';

  @override
  String get planUntilLabel => 'Bis';

  @override
  String get planYourSeat => 'Ihr Platz';

  @override
  String get plansEditorEdit => 'Tarif bearbeiten';

  @override
  String get plansEditorInactive => 'Inaktiv';

  @override
  String get plansEditorNew => 'Neuer Tarif';

  @override
  String plansEditorPerExtra(String price) {
    return '$price/zusätzl. Halbtag';
  }

  @override
  String plansEditorQuota(int count) {
    return '$count Halbtage';
  }

  @override
  String get plansEditorTitle => 'Tarife';

  @override
  String get plansEditorUnlimited => 'unbegrenzte Halbtage';

  @override
  String get policyAdminCheckoutDesc =>
      'Ein Admin kann den laufenden Check-in eines Mitglieds beenden.';

  @override
  String get policyAdminCheckoutTitle => 'Admins dürfen Mitglieder auschecken';

  @override
  String get policyAllowPastDesc =>
      'Mitglieder können eine bereits beendete Buchung nachtragen.';

  @override
  String get policyAllowPastTitle => 'Vergangene Buchungen erlauben';

  @override
  String policyDaysValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get policyDurationConflict =>
      'Das Minimum darf das Maximum nicht überschreiten — es käme keine Buchung mehr durch.';

  @override
  String get policyHorizonDesc =>
      'Wie viele Tage im Voraus eine Buchung beginnen darf. Darüber hinaus wird sie abgelehnt.';

  @override
  String get policyHorizonTitle => 'Vorausbuchungs-Horizont';

  @override
  String policyHoursValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stunden',
      one: '1 Stunde',
    );
    return '$_temp0';
  }

  @override
  String get policyLimitsDesc =>
      'Wie weit im Voraus gebucht werden darf und welche Dauer akzeptiert wird. Beides gilt bei jeder Granularität.';

  @override
  String get policyLimitsTitle => 'Buchungsgrenzen';

  @override
  String get policyMaxDurationDesc =>
      'Die längste akzeptierte Buchung. Eine Buchung endet an dem Tag, an dem sie beginnt — ein ganzer Tag ist also die Obergrenze.';

  @override
  String get policyMaxDurationTitle => 'Höchstdauer';

  @override
  String get policyMinDurationDesc =>
      'Die kürzeste akzeptierte Buchung. Deshalb wird eine Ankunft um 11:45 für die 12:00-Grenze als zu kurz abgelehnt.';

  @override
  String get policyMinDurationTitle => 'Mindestdauer';

  @override
  String policyMinutesValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Minuten',
      one: '1 Minute',
    );
    return '$_temp0';
  }

  @override
  String get policyOutsideHoursCharged => 'Berechnet';

  @override
  String get policyOutsideHoursChargedDesc =>
      'Erlaubt und wie normale Nutzung gezählt — außer an einem Tag, an dem das Mitglied bereits eine reguläre Buchung hat.';

  @override
  String get policyOutsideHoursDesc =>
      'Was außerhalb des Arbeitstags möglich ist — eine Antwort, für alle Granularitäten. Eine Buchung, die die Arbeitszeiten berührt, ist eine ganz normale Buchung.';

  @override
  String get policyOutsideHoursFree => 'Gratis';

  @override
  String get policyOutsideHoursFreeDesc =>
      'Erlaubt, nie gezählt und nie berechnet — reine Anwesenheitsinformation.';

  @override
  String get policyOutsideHoursOff => 'Aus';

  @override
  String get policyOutsideHoursOffDesc =>
      'Nichts außerhalb der Zeiten: keine Vorausbuchung, kein spontaner Check-in — und eine Buchung über das Tagesende hinaus wird ebenfalls abgelehnt.';

  @override
  String get policyOutsideHoursTitle => 'Außerhalb der Öffnungszeiten';

  @override
  String get policyOutsideHoursWalkUp => 'Nur spontan';

  @override
  String get policyOutsideHoursWalkUpDesc =>
      'Spontane Check-ins bleiben möglich, Abend-Überstunden eingeschlossen; im Voraus außerhalb der Zeiten zu buchen wird abgelehnt.';

  @override
  String get policySimultaneousDesc =>
      'Wie viele sich überschneidende Buchungen ein Mitglied halten darf. 1 bedeutet ein Platz zur selben Zeit.';

  @override
  String get policySimultaneousTitle =>
      'Gleichzeitige Reservierungen pro Mitglied';

  @override
  String get portalActionFailed =>
      'Die Änderung konnte nicht gespeichert werden. Bitte erneut versuchen.';

  @override
  String get portalActionNotNegotiated =>
      'Diese Aktion ist zwischen dieser App und diesem Server nicht verfügbar. Ein App-Update kann helfen.';

  @override
  String get portalAddress => 'Öffentliche Adresse';

  @override
  String get portalAdmin => 'Administrator';

  @override
  String get portalAdminVisible =>
      'Mich als öffentlichen Administrator anzeigen';

  @override
  String get portalAssociation => 'Verein';

  @override
  String get portalAvailable =>
      'Mein Konto für Suche und Nachrichten freigeben';

  @override
  String get portalChat => 'Chat';

  @override
  String get portalCompany => 'Unternehmen';

  @override
  String get portalConnect => 'Server verbinden';

  @override
  String get portalConnectionFailed =>
      'Verbindung fehlgeschlagen. Server und Anmeldedaten prüfen.';

  @override
  String get portalConnections => 'Verbundene Server';

  @override
  String get portalConnectionsHint =>
      'Jeder Server verwendet eine eigene Anmeldung. Trennen entfernt den gespeicherten Zugang dieses Kontos auf diesem Gerät.';

  @override
  String get portalCopyEmail => 'E-Mail kopieren';

  @override
  String get portalCustomised => 'Angepasst';

  @override
  String get portalDescription => 'Beschreibung';

  @override
  String get portalDirectoryIncompatible =>
      'Einige Workspaces benötigen eine neuere Version der App und werden nicht angezeigt.';

  @override
  String get portalDirectoryUnavailable =>
      'Einige Verzeichnisse sind nicht erreichbar. Die Ergebnisse sind unvollständig.';

  @override
  String get portalDisconnect => 'Trennen';

  @override
  String get portalDiscover => 'Arbeitsplatz finden';

  @override
  String get portalEmail => 'Öffentliche E-Mail';

  @override
  String get portalEmailCode => 'Anmeldecode per E-Mail';

  @override
  String get portalEmailCopied => 'E-Mail kopiert';

  @override
  String get portalEmployed => 'Bei diesem Workspace angestellt';

  @override
  String get portalEmploymentHint =>
      'Eine Anstellung ändert weder Zugriffsrechte noch Abonnements. Gehaltszahlungen sind nicht aktiviert.';

  @override
  String get portalEnterSpace => 'Eintreten';

  @override
  String get portalFindPeople => 'Erreichbare Personen suchen';

  @override
  String get portalFollowsWorkspace => 'Aus den Arbeitsbereichsangaben';

  @override
  String get portalImage => 'URL des Workspace-Bildes';

  @override
  String get portalLatitude => 'Breitengrad';

  @override
  String get portalList => 'Liste';

  @override
  String get portalLongitude => 'Längengrad';

  @override
  String get portalMap => 'Karte';

  @override
  String get portalMessenger => 'Kontonachrichten';

  @override
  String get portalMoreDirectories => 'Weitere Verzeichnisse';

  @override
  String get portalNoLongerPublished =>
      'Dieser Workspace ist nicht mehr veröffentlicht.';

  @override
  String get portalNoWorkspaces =>
      'Keine veröffentlichten Workspaces gefunden.';

  @override
  String get portalOpenMe => 'Ich: mein Konto und meine Spaces';

  @override
  String get portalOwner => 'Eigentümer';

  @override
  String get portalPerson => 'Privater Anbieter';

  @override
  String get portalPhone => 'Öffentliche Telefonnummer';

  @override
  String get portalPlans => 'Angebote und Preise';

  @override
  String get portalPreview => 'Externe Ansicht';

  @override
  String get portalPublicPlan => 'Öffentlicher Grundriss';

  @override
  String get portalPublication => 'Öffentliche Workspace-Seite';

  @override
  String get portalPublished => 'Im öffentlichen Verzeichnis sichtbar';

  @override
  String get portalRegisterDirectory =>
      'Server mit dem globalen Verzeichnis verbinden';

  @override
  String get portalRequestProfile => 'Workspace-Profil beantragen';

  @override
  String get portalRequestSent =>
      'Anfrage gesendet. Der Workspace prüft Ihr Profil.';

  @override
  String get portalResetAll =>
      'Alle öffentlichen Daten auf die Arbeitsbereichsangaben zurücksetzen';

  @override
  String get portalResetAllBody =>
      'Die öffentlichen Werte aller Felder, für die es Arbeitsbereichsangaben gibt, werden durch diese ersetzt. Felder ohne Entsprechung im Arbeitsbereich behalten Ihre Eingabe.';

  @override
  String get portalResetAllConfirm => 'Zurücksetzen';

  @override
  String get portalSavePreview => 'Speichern und externe Ansicht öffnen';

  @override
  String get portalSearch => 'Workspaces suchen';

  @override
  String get portalSendCode => 'Anmeldecode senden';

  @override
  String get portalSourceUnavailable =>
      'Ein Server ist nicht erreichbar. Diese Übersicht ist unvollständig. Zum Wiederholen antippen.';

  @override
  String get portalThisServer => 'Dieser Server';

  @override
  String get portalUseCode => 'E-Mail-Code verwenden';

  @override
  String get portalUseWorkspaceInfo => 'Arbeitsbereichsangaben verwenden';

  @override
  String get portalVisibilityLink => 'Wer mich finden und mir schreiben darf';

  @override
  String get portalVisibilityLinkBody =>
      'Festgelegt unter Ich › Wer mich sieht.';

  @override
  String get portalWebsite => 'Website';

  @override
  String get preferencesSaveFailed =>
      'Ihre Einstellungen konnten nicht gespeichert werden. Bitte versuchen Sie es erneut.';

  @override
  String get preferencesScopeHint =>
      'Sprache, Darstellung und regionale Formate. Aus: meine Standardwerte bearbeiten.';

  @override
  String get preferencesUseDefaults => 'Meine Standardwerte verwenden';

  @override
  String get preferencesWorkspaceOnly => 'Nur für diesen Arbeitsbereich';

  @override
  String get priceGrossHint =>
      'Bruttopreis — was das Mitglied zahlt; die USt steckt darin.';

  @override
  String priceVatIncluded(String rate) {
    return 'inkl. $rate USt';
  }

  @override
  String get privacyErase => 'Diesen Bereich verlassen und meine Daten löschen';

  @override
  String get privacyEraseConfirmButton => 'Löschen';

  @override
  String privacyEraseConfirmHint(String phrase) {
    return 'Nicht rückgängig zu machen. Geben Sie $phrase zur Bestätigung ein.';
  }

  @override
  String get privacyEraseConfirmPhrase => 'LÖSCHEN';

  @override
  String get privacyEraseHint =>
      'Storniert Ihre Buchungen, leert Ihre Nachrichten, löscht Ihr Profil. Buchhaltungsbelege bleiben für die gesetzliche Frist, per ID, nicht per Name (Art. 17).';

  @override
  String get privacyEraseOwner =>
      'Ein Eigentümer übergibt den Bereich zuerst (Mitglieder & Tarife → Miteigentum).';

  @override
  String get privacyErased => 'Ihre Daten wurden gelöscht.';

  @override
  String get privacyExport => 'Meine Daten exportieren';

  @override
  String get privacyExportHint =>
      'Alles, dessen betroffene Person Sie sind, als eine JSON-Datei (Art. 20).';

  @override
  String get privacyExportShareText => 'Mein DesKilo-Datenexport';

  @override
  String get privacyIntro =>
      'Ihre Daten werden nie verfolgt oder verkauft und sind nur für die Rollen lesbar, die die Regeln unten nennen; wo sie gespeichert sind, steht in den Datenschutzhinweisen dieser Installation. Das sind Ihre Rechte nach der DSGVO — jedes ist eine Schaltfläche.';

  @override
  String privacyNoticeController(String name, String contact) {
    return 'Verantwortlicher: $name — $contact';
  }

  @override
  String get privacyNoticeEssential => 'Für Konto und Bereich erforderlich';

  @override
  String get privacyNoticeNotRecorded => 'vom Betreiber nicht angegeben';

  @override
  String get privacyNoticeOptional =>
      'Optional — die App funktioniert auch ohne';

  @override
  String privacyNoticeRegion(String region) {
    return 'Region: $region';
  }

  @override
  String privacyNoticeRights(String contact) {
    return 'Ihre Rechte: $contact';
  }

  @override
  String get privacyNoticeRightsRoute => 'Ihre Rechte und der Kontakt';

  @override
  String get privacyNoticeTitle => 'Wer Ihre Daten verarbeitet';

  @override
  String privacyNoticeTransfer(String mechanism) {
    return 'Garantie für die Übermittlung: $mechanism';
  }

  @override
  String get privacyPolicy => 'Datenschutzerklärung';

  @override
  String get privacyPushOnDevice => 'Push-Benachrichtigungen auf diesem Gerät';

  @override
  String get privacyPushOnDeviceFailed =>
      'Die Auswahl konnte nicht gespeichert werden. Bitte versuchen Sie es erneut.';

  @override
  String get privacyPushOnDeviceHint =>
      'Optional. Ein: Die Adresse dieses Geräts und jede Benachrichtigung gehen an den Push-Dienst; aus: Die App funktioniert weiter und an dieses Gerät wird nichts gesendet.';

  @override
  String get privacySpaceNotice => 'Die Datenschutzhinweise dieses Bereichs';

  @override
  String get privacySpaceNoticeAcknowledge => 'Ich habe diese Hinweise gelesen';

  @override
  String get privacySpaceNoticeFailed =>
      'Die Kenntnisnahme konnte nicht gespeichert werden. Bitte versuchen Sie es erneut.';

  @override
  String get privacySpaceNoticeRead =>
      'Sie haben diese Fassung zur Kenntnis genommen.';

  @override
  String get privacySpaceNoticeUnread =>
      'Noch nicht zur Kenntnis genommen — hier lesen.';

  @override
  String get privacyTitle => 'Datenschutz & Daten';

  @override
  String get privacyWhoCanSee => 'Wer meine Daten sehen kann';

  @override
  String get privacyWhoCanSeeHint =>
      'Die Regel je Kategorie, die Personen, die sie heute nennt, und wer tatsächlich hingesehen hat.';

  @override
  String processAlsoNeeds(String features) {
    return 'Alles einzuschalten braucht auch: $features';
  }

  @override
  String processApplied(int count) {
    return '$count Funktionen geändert.';
  }

  @override
  String get processBillingPayments => 'Abrechnung und Zahlungen';

  @override
  String get processBillingPaymentsDesc =>
      'Aktivitäten abrechnen und offene Beträge abstimmen.';

  @override
  String processBlockedIntro(String feature, String features) {
    return '$feature wird noch benötigt von: $features';
  }

  @override
  String get processChangeFailed =>
      'Die Funktionen konnten nicht geändert werden. Nichts wurde geschrieben; versuchen Sie es erneut.';

  @override
  String processConfirmOff(int count) {
    return '$count Funktionen ausschalten';
  }

  @override
  String processConfirmOn(int count) {
    return '$count Funktionen einschalten';
  }

  @override
  String get processConflict =>
      'Jemand hat die Funktionen inzwischen geändert. Dies ist die aktualisierte Vorschau — prüfen Sie sie erneut.';

  @override
  String get processCoordination => 'Kalender und Koordination';

  @override
  String get processCoordinationDesc =>
      'Aktivitäten, Nachrichten und Entscheidungen koordinieren.';

  @override
  String get processDocumentsInformation => 'Dokumente und Informationen';

  @override
  String get processDocumentsInformationDesc =>
      'Informationen des Arbeitsbereichs erstellen, teilen und exportieren.';

  @override
  String processFeatureCount(int enabled, int total) {
    return '$enabled von $total Funktionen an';
  }

  @override
  String get processFeatureOff => 'Aus';

  @override
  String get processFeatureOn => 'An';

  @override
  String processFeatureWaiting(String feature) {
    return 'An, wartet auf $feature';
  }

  @override
  String get processFilterAll => 'Alle';

  @override
  String get processFilterEmpty => 'Kein Prozess passt zu diesem Filter.';

  @override
  String processHeldBack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Funktionen sind an, warten aber auf eine ausgeschaltete Voraussetzung',
      one: '1 Funktion ist an, wartet aber auf eine ausgeschaltete Voraussetzung',
    );
    return '$_temp0';
  }

  @override
  String processInProcess(String process) {
    return 'in $process';
  }

  @override
  String get processIntegrations => 'Integrationen und Automatisierung';

  @override
  String get processIntegrationsDesc =>
      'Benachrichtigungen und Dokumente über externe Dienste versenden.';

  @override
  String get processKeepDependants =>
      'Trotzdem ausschalten, Einstellungen behalten';

  @override
  String get processMembershipCommerce => 'Mitgliedschaftsangebote';

  @override
  String get processMembershipCommerceDesc =>
      'Leistungspreise und Mitgliedsvereinbarungen festlegen.';

  @override
  String processNeededBy(String features) {
    return 'benötigt von $features';
  }

  @override
  String get processNothingToDo => 'Ist bereits so — nichts zu ändern.';

  @override
  String get processOperations => 'Betrieb und Verwaltung';

  @override
  String get processOperationsDesc =>
      'Konfiguration und App-Bedienung verwalten.';

  @override
  String processRemoveDependants(int count) {
    return 'Auch die $count abhängigen Funktionen ausschalten';
  }

  @override
  String get processReservationsUsage => 'Buchungen und Nutzung';

  @override
  String get processReservationsUsageDesc =>
      'Plätze buchen und ihre Nutzung erfassen.';

  @override
  String get processSearchLabel => 'Prozesse und Funktionen suchen';

  @override
  String get processSectionAlreadyOn => 'Bereits an';

  @override
  String get processSectionAlsoNeeded => 'Ebenfalls nötig';

  @override
  String get processSectionAlsoOff => 'Ebenfalls ausgeschaltet';

  @override
  String get processSectionKeptWaiting =>
      'Funktionieren nicht mehr; die Einstellung bleibt';

  @override
  String get processSectionSwitchedOff => 'Ausgeschaltet';

  @override
  String get processSectionSwitchedOn => 'Eingeschaltet';

  @override
  String get processSectionWorksAgain => 'Funktionieren wieder';

  @override
  String processSheetTitleOff(String name) {
    return '$name ausschalten';
  }

  @override
  String processSheetTitleOn(String name) {
    return '$name einschalten';
  }

  @override
  String get processSpaceManagement => 'Raumverwaltung';

  @override
  String get processSpaceManagementDesc =>
      'Nutzbare Räume und ihre Öffnungszeiten organisieren.';

  @override
  String get processStateActive => 'Aktiv';

  @override
  String get processStateAvailable => 'Verfügbar';

  @override
  String get processStateNeedsAttention => 'Handlungsbedarf';

  @override
  String get processStatePartial => 'Teilweise';

  @override
  String processSubprocessCount(int active, int total) {
    return '$active von $total Teilprozessen aktiv';
  }

  @override
  String get processSwitchHint =>
      'Tippen Sie auf eine Funktion, um sie bei den Schaltern zu ändern.';

  @override
  String get processSwitchOff => 'Ausschalten';

  @override
  String get processSwitchOn => 'Einschalten';

  @override
  String get processUnconfirmed =>
      'Die Änderung wurde geschrieben, aber die App konnte sie nicht bestätigen. Schließen und öffnen Sie die Funktionen erneut, um den aktuellen Stand zu sehen.';

  @override
  String get processWorkspaceAccess => 'Arbeitsbereich und Zugang';

  @override
  String get processWorkspaceAccessDesc =>
      'Mitgliedschaften, Rollen und Zugang zum Arbeitsbereich verwalten.';

  @override
  String get profilePhotoChoose => 'Foto auswählen';

  @override
  String get profilePhotoFileType => 'Bild';

  @override
  String get profilePhotoNone => 'Zum Hinzufügen eines Fotos tippen';

  @override
  String get profilePhotoRemove => 'Foto entfernen';

  @override
  String get profilePhotoRemoved => 'Foto entfernt';

  @override
  String get profilePhotoSaveFailed => 'Foto konnte nicht aktualisiert werden';

  @override
  String get profilePhotoSaved => 'Foto aktualisiert';

  @override
  String get profilePhotoSet => 'Zum Ändern tippen';

  @override
  String get profilePhotoTitle => 'Foto';

  @override
  String get profileStatusFieldLabel => 'Status';

  @override
  String get profileStatusHelper =>
      'Optional. Für Mitglieder Ihrer Workspaces im Mitgliederverzeichnis sichtbar. Leer lassen, um den Status zu löschen.';

  @override
  String get profileStatusHint => 'Im Call · zurück um 14:00';

  @override
  String get profileStatusNone => 'Kein Status';

  @override
  String get profileStatusSaveFailed =>
      'Status konnte nicht gespeichert werden';

  @override
  String get profileStatusSaved => 'Status gespeichert';

  @override
  String get profileStatusTitle => 'Status';

  @override
  String get profilesActive => 'Aktives Profil';

  @override
  String get profilesAdd => 'Profil hinzufügen';

  @override
  String get profilesAllWorkspaces =>
      'Alle Arbeitsbereiche (Plattformbetreiber)';

  @override
  String get profilesCopyEmail => 'E-Mail kopieren';

  @override
  String get profilesDefault => 'Standard beim Start';

  @override
  String get profilesEmailCopied => 'E-Mail kopiert.';

  @override
  String get profilesMakeDefault => 'Beim Start als Standard verwenden';

  @override
  String profilesNotMember(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mitglieder',
      one: '1 Mitglied',
    );
    return 'Kein Mitglied · $_temp0';
  }

  @override
  String get profilesOwnersNone => 'Kein Inhaber.';

  @override
  String profilesOwnersOf(String name) {
    return 'Inhaber von $name';
  }

  @override
  String get profilesPairDev => 'DEV';

  @override
  String get profilesPairProd => 'PROD';

  @override
  String profilesSiteLine(String site) {
    return 'Standort: $site';
  }

  @override
  String get profilesSitePick => 'Standort wechseln';

  @override
  String get profilesTitle => 'Profile';

  @override
  String get profilesUnavailable =>
      'Ihre Arbeitsbereiche konnten nicht geladen werden.';

  @override
  String provenanceFromTemplate(String name) {
    return 'Aus Vorlage „$name“';
  }

  @override
  String get provenanceProductDefault => 'Produktstandard';

  @override
  String get provenanceResetToDefault => 'Auf Produktstandard zurücksetzen';

  @override
  String get provenanceResetToTemplate => 'Auf Vorlage zurücksetzen';

  @override
  String get provenanceWorkspaceSetting => 'Einstellung des Raums';

  @override
  String get publicHolidaysAction => 'Feiertage hinzufügen';

  @override
  String publicHolidaysConfirm(int count) {
    return '$count Schließtage erstellen';
  }

  @override
  String get publicHolidaysCountry => 'Land';

  @override
  String publicHolidaysCreated(int count) {
    return '$count Schließtage erstellt';
  }

  @override
  String get publicHolidaysLocked => 'Abgerechneter Monat — nicht erstellt';

  @override
  String publicHolidaysLockedMonths(String months) {
    return 'Übersprungen, bereits abgerechnet: $months';
  }

  @override
  String get publicHolidaysNothingToCreate =>
      'Nichts zu erstellen — alle Tage sind bereits vorhanden.';

  @override
  String get publicHolidaysPresent => 'Bereits ein Schließtag';

  @override
  String get publicHolidaysPreviewNone => 'Keine Feiertage für dieses Jahr.';

  @override
  String get publicHolidaysSheetTitle => 'Feiertage';

  @override
  String get publicHolidaysYear => 'Jahr';

  @override
  String get publicPersonUnavailable => 'Dieses Profil ist nicht öffentlich.';

  @override
  String get publicProfileCopied => 'Link kopiert.';

  @override
  String get publicProfileCopy => 'Link kopieren';

  @override
  String get publicProfileOff =>
      'Aus: Nicht angemeldete Personen sehen nichts von Ihnen.';

  @override
  String get publicProfileOn =>
      'Wer den Link hat, liest Ihren Namen, Ihren Beruf und Ihre Vorstellung.';

  @override
  String get publicProfilePublishAction => 'Veröffentlichen';

  @override
  String get publicProfilePublishBody =>
      'Jede Person im Internet, angemeldet oder nicht, kann über Ihren Link Ihren Namen, Ihren Beruf und Ihre Vorstellung lesen. Kontaktdaten, Anwesenheit und Spaces bleiben privat.';

  @override
  String get publicProfilePublishTitle =>
      'Öffentliches Profil veröffentlichen?';

  @override
  String get publicProfileTitle => 'Öffentliches Profil';

  @override
  String get pushCancelledBody =>
      'Eine Reservierung wurde von einem Admin entfernt.';

  @override
  String get pushCancelledTitle => 'Reservierung entfernt';

  @override
  String get pushPendingBody => 'Jemand wartet auf Ihre Bestätigung.';

  @override
  String get pushPendingTitle => 'DesKilo';

  @override
  String get pushStatusNoTransport =>
      'Diese Version hat keine Push-Benachrichtigungen';

  @override
  String get pushStatusNoTransportHint =>
      'Benachrichtigungen kommen in der App und als lokale Benachrichtigungen auf diesem Gerät an.';

  @override
  String get pushStatusNotConfigured =>
      'Push-Benachrichtigungen sind noch nicht eingerichtet';

  @override
  String get pushStatusNotConfiguredHint =>
      'Der Inhaber schließt die Firebase-Einrichtung ab (push-setup-Anleitung).';

  @override
  String get pushStatusRegistered => 'Push-Benachrichtigungen sind aktiv';

  @override
  String get questionEditorActive => 'Wird gestellt';

  @override
  String get questionEditorChoices => 'Auswahlmöglichkeiten, eine pro Zeile';

  @override
  String get questionEditorContextJoin => 'Beim Beitritt';

  @override
  String get questionEditorContextManaged =>
      'Die Angaben eines verwalteten Mitglieds';

  @override
  String get questionEditorContextProfile => 'Die Angaben des Mitglieds';

  @override
  String get questionEditorContexts => 'Wo sie gestellt wird';

  @override
  String get questionEditorKey => 'Schlüssel';

  @override
  String get questionEditorKeyHelp =>
      'Kleinbuchstaben, Ziffern und Unterstriche. Er ändert sich nie: die Antworten hängen daran.';

  @override
  String questionEditorLabelFor(String locale) {
    return 'Beschriftung ($locale)';
  }

  @override
  String get questionEditorMax => 'Größte Zahl';

  @override
  String get questionEditorMaxLength => 'Längste Antwort (Zeichen)';

  @override
  String get questionEditorMin => 'Kleinste Zahl';

  @override
  String get questionEditorNotPersonalWarning =>
      'Trotzdem personenbezogen: Die Antwort ist einem Mitglied zugeordnet und wird unabhängig von diesem Schalter mit der Mitgliedschaft exportiert und gelöscht. Nur eine dokumentierte Aufbewahrungspflicht kann sie behalten.';

  @override
  String get questionEditorPersonal => 'Das ist eine personenbezogene Angabe';

  @override
  String get questionEditorPersonalHelp =>
      'Jede Antwort ist einem Mitglied zugeordnet und damit personenbezogen: Sie liegt seinem Datenexport bei und wird beim Austritt gelöscht.';

  @override
  String get questionEditorPreview => 'So wird es aussehen';

  @override
  String get questionEditorRequired => 'Muss beantwortet werden';

  @override
  String get questionEditorSave => 'Frage speichern';

  @override
  String get questionEditorSaveFailed => 'Die Frage wurde nicht gespeichert.';

  @override
  String get questionEditorType => 'Antworttyp';

  @override
  String get questionEditorVisibility => 'Wer die Antwort sieht';

  @override
  String get questionEditorVisibilityManagers =>
      'Das Mitglied und wer personenbezogene Daten sehen darf';

  @override
  String get questionEditorVisibilityMembers => 'Alle Mitglieder des Bereichs';

  @override
  String get questionEditorVisibilitySelf => 'Nur das Mitglied';

  @override
  String get questionTypeBoolean => 'Ja oder nein';

  @override
  String get questionTypeDate => 'Ein Datum';

  @override
  String get questionTypeDecimal => 'Eine Zahl';

  @override
  String get questionTypeInteger => 'Eine ganze Zahl';

  @override
  String get questionTypeLongText => 'Eine lange Antwort';

  @override
  String get questionTypeMultiChoice => 'Mehrere aus einer Liste';

  @override
  String get questionTypeSingleChoice => 'Eines aus einer Liste';

  @override
  String get questionTypeText => 'Eine kurze Antwort';

  @override
  String get questionsAdd => 'Frage hinzufügen';

  @override
  String get questionsEmpty => 'Noch keine Fragen.';

  @override
  String get questionsInactive => 'Zurückgestellt';

  @override
  String get questionsSubtitle =>
      'Sie erscheinen in den persönlichen Angaben, unter dem Namen Ihres Bereichs.';

  @override
  String get questionsTitle => 'Fragen dieses Bereichs';

  @override
  String get quotaExceededError =>
      'Monatliches Halbtage-Kontingent erreicht — beantragen Sie zusätzliche halbe Tage im Finanzen-Tab.';

  @override
  String get quotaRequestButton => 'Zusätzliche halbe Tage beantragen';

  @override
  String get quotaRequestCountLabel => 'Anzahl halber Tage';

  @override
  String quotaRequestExplainer(String period) {
    return 'Ihre Reservierungen sind durch Ihr Abo begrenzt. Zusätzliche halbe Tage für $period gelten nach der Freigabe.';
  }

  @override
  String get quotaRequestPending => 'Antrag gesendet — wartet auf Freigabe.';

  @override
  String get quotaRequestTitle => 'Zusätzliche halbe Tage beantragen';

  @override
  String readinessActor(String who) {
    return 'Wer: $who';
  }

  @override
  String get readinessActorAdministrator => 'Eine Datenbankadministration';

  @override
  String get readinessActorOperator => 'Der Serverbetreiber';

  @override
  String get readinessActorOwner => 'Sie';

  @override
  String readinessAll(String ready, String total) {
    return 'Alle Bereiche ($ready von $total bereit)';
  }

  @override
  String get readinessAreaAssistant => 'Assistentenzugang (optional)';

  @override
  String get readinessAreaBackend => 'Server und Datenbankversion';

  @override
  String get readinessAreaFirstBooking => 'Eine erste Buchung';

  @override
  String get readinessAreaInvitations => 'Die ersten Mitglieder einladen';

  @override
  String get readinessAreaLegalIdentity =>
      'Rechtliche Identität und Adresse des Space';

  @override
  String get readinessAreaLocalSetup =>
      'Angaben, die Ihre Funktionen brauchen (Identität, Bank, Plattformen)';

  @override
  String get readinessAreaMemberPermissions => 'Was Mitglieder dürfen';

  @override
  String get readinessAreaPayments => 'Wie Mitglieder bezahlen';

  @override
  String get readinessAreaPricing => 'Mitgliedschaftsmodelle und Tarife';

  @override
  String get readinessAreaRecovery => 'Export und Wiederherstellung';

  @override
  String get readinessAreaRegionRules => 'Öffnungstage, Zeitzone und Währung';

  @override
  String get readinessAreaResources => 'Buchbare Plätze im Grundriss';

  @override
  String get readinessAreaRolesValidation =>
      'Rollen und wer Anfragen bestätigt';

  @override
  String readinessBlocked(String step) {
    return 'Vor einer ersten Buchung: $step';
  }

  @override
  String readinessBlockedInvoicing(String area) {
    return 'Vor der Rechnungsstellung: $area';
  }

  @override
  String get readinessFirstBookingReady => 'Bereit für eine erste Buchung';

  @override
  String get readinessLater => 'Später nötig';

  @override
  String get readinessNeededFirst => 'Nötig für eine erste Buchung';

  @override
  String get readinessNeededInvoicing => 'Vor der Rechnungsstellung nötig';

  @override
  String readinessNext(String step) {
    return 'Als Nächstes: $step';
  }

  @override
  String get readinessReasonEligibilityExpired =>
      'Ihre Freigabe für Assistenten ist abgelaufen';

  @override
  String get readinessReasonEligibilityMissing =>
      'Keine Datenbankadministration hat Sie für Assistenten freigegeben';

  @override
  String get readinessReasonEligibilityNoIdentity =>
      'Melden Sie sich zuerst mit Ihrer bestätigten Identität an';

  @override
  String get readinessReasonEligibilityRequested =>
      'Ihre Anfrage wartet auf die Datenbankadministration';

  @override
  String get readinessReasonInvoicingNeedsIdentity =>
      'Ohne sie kann keine Rechnung ausgestellt werden';

  @override
  String get readinessReasonMembersCannotBook =>
      'Mitglieder können noch nicht buchen: Erteilen Sie ihnen unter Rollen „Buchen und Reservierungen nutzen“';

  @override
  String get readinessReasonNoEvidence =>
      'Noch kein Export und keine Wiederherstellung erfasst';

  @override
  String get readinessReasonNoPolicies =>
      'Keine Anfrage wartet auf eine Bestätigung';

  @override
  String get readinessReasonNotExposed =>
      'Dieser Bereich gibt Assistenten noch nichts frei';

  @override
  String get readinessReasonRecentExport => 'Ein aktueller Export ist erfasst';

  @override
  String get readinessReasonStaleExport =>
      'Der letzte erfasste Export ist älter als 90 Tage';

  @override
  String get readinessReasonTooFewValidators =>
      'Eine Regel verlangt mehr Prüfer, als dieser Bereich hat';

  @override
  String get readinessSetAside => 'Für später zurückgestellt';

  @override
  String get readinessSetAsideAction => 'Später';

  @override
  String get readinessSetAsideFailed =>
      'Das konnte nicht gespeichert werden. Bitte erneut versuchen.';

  @override
  String get readinessSetAsideUndo => 'Rückgängig';

  @override
  String get readinessStateNeeds => 'Einzurichten';

  @override
  String get readinessStateNeedsOperator => 'Wartet auf jemand anderen';

  @override
  String get readinessStateNotApplicable => 'Hier nicht nötig';

  @override
  String get readinessStateReady => 'Bereit';

  @override
  String get readinessStateUnavailable => 'Konnte nicht gelesen werden';

  @override
  String get readinessStateUnverified => 'Noch nicht geprüft';

  @override
  String get readinessTitle => 'Einrichtung dieses Workspace';

  @override
  String get recordingPrivacyBadge => 'Aufnahmemodus — erfundene Personen';

  @override
  String get recordingPrivacyBadgeHint =>
      'Der Aufnahmemodus ist aktiv: Jeder angezeigte Name, jede E-Mail-Adresse, Telefonnummer, Anschrift und jedes Foto gehört einer erfundenen Person. Plan, Buchungen und Beträge sind die dieses Arbeitsraums. Schalten Sie ihn nach den Aufnahmen in den Einstellungen wieder aus.';

  @override
  String get recordingPrivacyWriteRefused =>
      'Nicht, solange der Aufnahmemodus aktiv ist: Dieses Formular zeigt eine erfundene Person, und Speichern würde damit die echten Angaben einer Person überschreiben. Schalten Sie den Aufnahmemodus zuerst aus.';

  @override
  String get refFacetMonth => 'Monat';

  @override
  String get refFacetPerson => 'Person';

  @override
  String get refFacetStatus => 'Status';

  @override
  String get refFacetType => 'Art';

  @override
  String get refFacetWorkspace => 'Arbeitsbereich';

  @override
  String get refFilterAll => 'Alle';

  @override
  String get refFilterAmount => 'Betrag';

  @override
  String get refFilterClear => 'Filter löschen';

  @override
  String refFilterFindIn(String facet) {
    return 'In $facet suchen';
  }

  @override
  String get refFilterMore => 'Filter';

  @override
  String get refFilterReset => 'Zurücksetzen';

  @override
  String refFilterShow(int count) {
    return '$count Ergebnisse anzeigen';
  }

  @override
  String get refFilterSort => 'Sortieren';

  @override
  String get refSortAmountHigh => 'Höchster Betrag';

  @override
  String get refSortAmountLow => 'Niedrigster Betrag';

  @override
  String get refSortNewest => 'Neueste zuerst';

  @override
  String get refSortOldest => 'Älteste zuerst';

  @override
  String get refStatusCancelled => 'Storniert';

  @override
  String get refStatusDecided => 'Entschieden';

  @override
  String get refStatusOpen => 'Offen (unbezahlt)';

  @override
  String get refStatusPaid => 'Bezahlt';

  @override
  String get refStatusPending => 'Ausstehend';

  @override
  String get refStatusRefunded => 'Erstattet';

  @override
  String get refTypeCreditNote => 'Gutschrift';

  @override
  String get refTypeInvoice => 'Rechnung';

  @override
  String get refusalAlreadyDecided =>
      'Jemand hat bereits darüber entschieden. Die Liste zeigt das Ergebnis.';

  @override
  String get refusalChangedMeanwhile =>
      'Das hat sich inzwischen geändert. Öffnen Sie es erneut, um den aktuellen Stand zu sehen.';

  @override
  String get refusalMoneyLocaleLocked =>
      'Währung und Land stehen fest, sobald dieser Space ein Dokument ausgestellt oder Geld erfasst hat. Es wurde nichts gespeichert.';

  @override
  String get refusalPermission =>
      'Dafür haben Sie keine Berechtigung. Ein Inhaber des Space kann sie in der Rollenverwaltung erteilen.';

  @override
  String get refusalSession =>
      'Ihre Sitzung ist abgelaufen. Melden Sie sich erneut an und versuchen Sie es dann noch einmal.';

  @override
  String get regionalClock => 'Uhr';

  @override
  String get regionalClock12h => '12h';

  @override
  String get regionalClock24h => '24h';

  @override
  String get regionalClockAuto => 'Auto';

  @override
  String get regionalDeviceZone => 'Zeiten in meiner Zeitzone anzeigen';

  @override
  String get regionalDeviceZoneHint =>
      'Aus: Zeiten in der Zone des Bereichs, in der gebucht wird. An: die Ihres Geräts, gekennzeichnet, wo sie abweicht.';

  @override
  String get regionalFollowLanguage => 'Automatisch';

  @override
  String get regionalFormatLocale => 'Zahlen & Daten';

  @override
  String regionalFormatLocaleAuto(String locale) {
    return 'Folgt der App-Sprache ($locale)';
  }

  @override
  String get regionalFormatsTitle => 'Region & Formate';

  @override
  String get registerPaymentAmount => 'Betrag';

  @override
  String get registerPaymentDate => 'Bezahlt am';

  @override
  String get registerPaymentDone =>
      'Zahlung erfasst — das Mitglied bestätigt sie von seiner Seite.';

  @override
  String get registerPaymentHint =>
      'Eine Zahlung, die beim Workspace eingegangen ist — das Mitglied bestätigt sie, dann kann sie einer Rechnung zugeordnet werden.';

  @override
  String get registerPaymentMember => 'Mitglied';

  @override
  String get registerPaymentMethod => 'Zahlungsart';

  @override
  String get registerPaymentNote => 'Notiz';

  @override
  String get registerPaymentSubmit => 'Erfassen';

  @override
  String get registerPaymentTitle => 'Zahlung erfassen';

  @override
  String reminderBody(String target, String time) {
    return '$target beginnt um $time';
  }

  @override
  String reminderHistoryLine(int level, String origin, String date) {
    return 'Stufe $level · $origin · $date';
  }

  @override
  String get reminderHistoryRefresh => 'Zustellung erneut prüfen';

  @override
  String get reminderHistoryTitle => 'Mahnverlauf';

  @override
  String get reminderOriginAutomatic => 'automatisch';

  @override
  String get reminderOriginLegacy => 'früher';

  @override
  String get reminderOriginManual => 'von Hand';

  @override
  String get reminderPdfClosing =>
      'Sollten Sie bereits gezahlt haben, betrachten Sie dieses Schreiben bitte als gegenstandslos.';

  @override
  String get reminderPdfDays => 'Tagen';

  @override
  String get reminderPdfDaysOpen => 'Offen seit';

  @override
  String get reminderPdfLevelLabel => 'Mahnstufe';

  @override
  String get reminderPdfOpeningFirm =>
      'trotz unserer vorherigen Mahnung ist die untenstehende Rechnung weiterhin unbezahlt. Bitte begleichen Sie den Betrag umgehend.';

  @override
  String get reminderPdfOpeningFriendly =>
      'dies ist eine freundliche Erinnerung: die untenstehende Rechnung ist noch offen. Sicher nur übersehen — kein Problem.';

  @override
  String get reminderPdfTitleFirm => 'Mahnung';

  @override
  String get reminderPdfTitleFriendly => 'Zahlungserinnerung';

  @override
  String get reminderStatusAccepted =>
      'Vom Benachrichtigungsdienst angenommen — kein Nachweis, dass sie gelesen wurde';

  @override
  String get reminderStatusDeclared =>
      'Vom Absender geteilt — seine Angabe, keine Empfangsbestätigung';

  @override
  String get reminderStatusFailed => 'Nicht zugestellt';

  @override
  String get reminderStatusLegacy =>
      'Vor der Zustellverfolgung erfasst — unbekannt';

  @override
  String get reminderStatusPrepared => 'Vorbereitet';

  @override
  String get reminderStatusQueued => 'An den Benachrichtigungsdienst übergeben';

  @override
  String get reminderStatusUnknown =>
      'Keine Antwort des Benachrichtigungsdienstes';

  @override
  String get reminderTitle => 'Bald einchecken';

  @override
  String get repartitionAction => 'Ausgabe verteilen';

  @override
  String get repartitionAmount => 'Gesamtbetrag';

  @override
  String get repartitionAmountLabel => 'Betrag';

  @override
  String get repartitionBooked => 'Umlage gebucht.';

  @override
  String get repartitionExclude => 'Ausnehmen';

  @override
  String get repartitionFiled =>
      'Anteile gebucht — sie erscheinen auf der nächsten Nutzungsrechnung.';

  @override
  String get repartitionFiledPending =>
      'Anteile eingereicht — sie werden nach der Bestätigung gebucht.';

  @override
  String get repartitionHint =>
      'Verteilen Sie gemeinsame Kosten auf die Mitglieder. Die Anteile werden Positionen der nächsten Nutzungsrechnung jedes Mitglieds; eine Umkehrung gibt das Geld als Gutschriften zurück.';

  @override
  String get repartitionHistory => 'Verteilungen';

  @override
  String get repartitionHistoryEmpty => 'Noch keine Verteilung.';

  @override
  String get repartitionMethod => 'Verteilen nach';

  @override
  String get repartitionMethodCustom => 'Eigener Schlüssel';

  @override
  String get repartitionMethodEqual => 'Gleich';

  @override
  String get repartitionMethodSubscription => 'Abonnement';

  @override
  String get repartitionMethodUsage => 'Nutzung';

  @override
  String get repartitionNoShares =>
      'Niemand trägt einen Anteil — prüfen Sie den Schlüssel.';

  @override
  String get repartitionPeriod => 'Gebucht auf';

  @override
  String get repartitionPeriodLabel => 'Monat';

  @override
  String get repartitionPreview => 'Anteile';

  @override
  String get repartitionRememberRule => 'Diese Regel merken';

  @override
  String get repartitionReverse => 'Umkehrung — als Gutschriften zurückgeben';

  @override
  String get repartitionRuleHint =>
      'Jeder Anteil wird anteilig zum Abonnement vorgeschlagen. Ein Mitglied abwählen, um es auszunehmen; bei der Methode „Schlüssel“ das Gewicht eintragen. Die angepasste Regel wird nächsten Monat wieder vorgeschlagen.';

  @override
  String get repartitionRuleNotSaved =>
      'Die Regel konnte nicht gespeichert werden, also wurde nichts verteilt. Bitte erneut versuchen.';

  @override
  String get repartitionSharesTotal => 'Summe der Anteile';

  @override
  String get repartitionStatusConfirmed => 'Gebucht';

  @override
  String get repartitionStatusExpired => 'Abgelaufen';

  @override
  String get repartitionStatusPending => 'Wartet auf Bestätigung';

  @override
  String get repartitionStatusRejected => 'Abgelehnt';

  @override
  String get repartitionStepBook => 'Buchen';

  @override
  String get repartitionStepCost => 'Die Kosten';

  @override
  String get repartitionStepExpense => 'Die Ausgabe';

  @override
  String get repartitionStepRule => 'Die Regel';

  @override
  String get repartitionSubmit => 'Anteile buchen';

  @override
  String repartitionSum(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mitglieder · $amount',
      one: '1 Mitglied · $amount',
    );
    return '$_temp0';
  }

  @override
  String get repartitionTitle => 'Ausgabe verteilen';

  @override
  String get repartitionTitleField => 'Wofür';

  @override
  String get repartitionTitleLabel => 'Bezeichnung';

  @override
  String get repartitionWeight => 'Schlüssel';

  @override
  String get repartitionWizardSubtitle =>
      'Anteilig zum Abonnement vorschlagen, anpassen, buchen';

  @override
  String get repartitionWizardTitle => 'Kosten umlegen';

  @override
  String get repartitionWizardWeight => 'Gewicht';

  @override
  String get repeatDaily => 'Täglich';

  @override
  String get repeatNone => 'Keine Wiederholung';

  @override
  String get repeatWeekdays => 'Jeden Werktag';

  @override
  String get repeatWeekly => 'Wöchentlich';

  @override
  String get reportBadgesFooter =>
      'Ein verlorenes Badge wird in Mitglieder & Tarife widerrufen, nicht bloß ersetzt.';

  @override
  String get reportBadgesIntro =>
      'An den Linien schneiden. Jede Karte trägt den Badge-Code eines Mitglieds — am Kiosk vorzeigen zum Einchecken.';

  @override
  String get reportBadgesTitle => 'Mitglieder-Badges';

  @override
  String get reportCoaAccounts => 'Vorgeschlagene Konten';

  @override
  String get reportCoaDisclaimer =>
      'Nur eine Vorschau. DesKilo führt kein Hauptbuch und macht Ihre Buchhaltung nicht — der Kontenrahmen Ihrer Steuerberatung gilt.';

  @override
  String get reportCoaIntro =>
      'Ein Vorschlag, nicht Ihre Buchhaltung. Das sind die Konten, die man in Ihrem Land für einen Space wie Ihren üblicherweise nimmt.';

  @override
  String get reportCoaLabel => 'Bezeichnung';

  @override
  String get reportCoaNumber => 'Konto';

  @override
  String get reportCoaTitle => 'Kontenrahmen — Vorschau';

  @override
  String get reportColQty => 'Menge';

  @override
  String get reportColTotal => 'Gesamt';

  @override
  String get reportColUnitPrice => 'Einzelpreis';

  @override
  String get reportDesignEmpty =>
      'Leeres Band — fügen Sie unten ein Element hinzu.';

  @override
  String get reportDesignErrorInvalidDesign =>
      'Diese Datei enthält keine lesbare Vorlage.';

  @override
  String get reportDesignErrorMalformed =>
      'Diese Datei ist kein lesbares JSON.';

  @override
  String get reportDesignErrorNotADesign =>
      'Diese Datei ist keine DesKilo-Berichtsvorlage.';

  @override
  String get reportDesignErrorUnknownKind =>
      'Diese Vorlage gehört zu einem Bericht, den dieser Space nicht hat.';

  @override
  String get reportDesignErrorVersion =>
      'Diese Vorlage stammt aus einer neueren DesKilo-Version.';

  @override
  String get reportDesignErrorWrongKind =>
      'Diese Vorlage gehört zu einem anderen Bericht. Öffnen Sie diesen und importieren Sie sie dort.';

  @override
  String get reportDesignExport => 'Diese Vorlage exportieren';

  @override
  String get reportDesignFileTypeLabel => 'JSON';

  @override
  String get reportDesignImport => 'Vorlage importieren';

  @override
  String get reportDesignImported =>
      'Vorlage importiert. Zum Behalten speichern.';

  @override
  String get reportDesignerDesign => 'Entwurf';

  @override
  String get reportDesignerDiscard => 'Verwerfen';

  @override
  String get reportDesignerDiscardBody =>
      'Ihre Änderungen an den Vorlagen sind nicht gespeichert.';

  @override
  String get reportDesignerDiscardTitle => 'Ohne Speichern verlassen?';

  @override
  String get reportDesignerDrag => 'Ziehen zum Umsortieren';

  @override
  String reportDesignerError(String message) {
    return 'Die Vorlage lässt sich nicht erzeugen — $message';
  }

  @override
  String get reportDesignerFields => 'Felder';

  @override
  String get reportDesignerFieldsSearch => 'Feld suchen';

  @override
  String get reportDesignerInsert => 'Element einfügen';

  @override
  String get reportDesignerKeepEditing => 'Weiter bearbeiten';

  @override
  String get reportDesignerMoveTo => 'In Band verschieben';

  @override
  String reportDesignerPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Seiten',
      one: '1 Seite',
    );
    return '$_temp0';
  }

  @override
  String get reportDesignerPreview => 'Vorschau';

  @override
  String get reportDesignerRedo => 'Wiederholen';

  @override
  String get reportDesignerReplace => 'Ersetzen';

  @override
  String get reportDesignerReplaceBody =>
      'Die Bänder dieses Dokuments werden ersetzt. Rückgängig holt sie zurück.';

  @override
  String get reportDesignerReplaceTitle => 'Aktuelles Layout ersetzen?';

  @override
  String get reportDesignerSideBySide => 'Entwurf und Vorschau nebeneinander';

  @override
  String get reportDesignerUndo => 'Rückgängig';

  @override
  String get reportDesignerZoom => 'Zoom';

  @override
  String get reportDesignerZoomFit => 'An Breite anpassen';

  @override
  String get reportDocAgreement => 'Finanzvereinbarung';

  @override
  String get reportDocBadges => 'Mitgliedsausweise';

  @override
  String get reportDocCoa => 'Kontenrahmen';

  @override
  String get reportDocPayments => 'Zahlungsbericht';

  @override
  String get reportDocSpaceCodes => 'QR-Karten der Plätze';

  @override
  String get reportDocStatus => 'Lage des Arbeitsbereichs';

  @override
  String get reportDocUsage => 'Verbrauchsbericht';

  @override
  String get reportDocVat => 'MwSt-Bericht';

  @override
  String get reportDocWorkspace => 'Arbeitsbereichsbericht';

  @override
  String get reportDocWorkspaceSubtitle =>
      'Alles über den Arbeitsbereich — über die Arbeitsbereichsvorlage des Berichtseditors';

  @override
  String get reportEditorMarkup => 'Markup';

  @override
  String get reportEditorTitle => 'Berichtseditor';

  @override
  String get reportEditorVisual => 'Visuell';

  @override
  String get reportFieldGroupBank => 'Bankverbindung';

  @override
  String get reportFieldGroupDocument => 'Dokument';

  @override
  String get reportFieldGroupLegal => 'Pflichtangaben';

  @override
  String get reportFieldGroupLoops => 'Schleifen Positionen & MwSt.';

  @override
  String get reportFieldGroupMember => 'Mitglied & Workspace';

  @override
  String get reportFieldGroupMoney => 'Beträge';

  @override
  String get reportFieldGroupSeller => 'Verkäufer';

  @override
  String get reportFieldGroupSites => 'Standorte';

  @override
  String get reportFieldGroupStatus => 'Raumstatus';

  @override
  String get reportFieldGroupTexts => 'Ihre Texte';

  @override
  String get reportFieldGroupUsage => 'Verbrauchsbericht';

  @override
  String get reportFieldGroupVat => 'MwSt.-Bericht';

  @override
  String get reportFieldMeaningAccountHolder => 'Der Kontoinhaber';

  @override
  String get reportFieldMeaningBankAccount => 'Die Kontonummer';

  @override
  String get reportFieldMeaningBankCode => 'Die Bankleitzahl';

  @override
  String get reportFieldMeaningBankName => 'Der Name der Bank';

  @override
  String get reportFieldMeaningBic => 'Die BIC der Bank';

  @override
  String get reportFieldMeaningBuyerReference =>
      'Die eigene Referenz des Käufers (öffentlicher Sektor)';

  @override
  String get reportFieldMeaningCharges => 'Die Kosten vor Zahlungen';

  @override
  String get reportFieldMeaningClientAddress => 'Der Adressblock des Kunden';

  @override
  String get reportFieldMeaningClientCompany => 'Die Firma des Kunden';

  @override
  String get reportFieldMeaningClientEmail => 'Die E-Mail des Kunden';

  @override
  String get reportFieldMeaningClientLegalId =>
      'Die rechtliche Kennung des Kunden';

  @override
  String get reportFieldMeaningClientMemberNumber =>
      'Die Mitgliedsnummer des Kunden';

  @override
  String get reportFieldMeaningClientName => 'Der vollständige Name des Kunden';

  @override
  String get reportFieldMeaningClientPhone => 'Das Telefon des Kunden';

  @override
  String get reportFieldMeaningClientVatId => 'Die USt-IdNr. des Kunden';

  @override
  String get reportFieldMeaningCopy => 'Wahr auf einem Duplikat';

  @override
  String get reportFieldMeaningCreditNote => 'Wahr auf einer Gutschrift';

  @override
  String get reportFieldMeaningDueDate => 'Das Fälligkeitsdatum';

  @override
  String get reportFieldMeaningEscompte => 'Der Hinweis zum Skonto';

  @override
  String get reportFieldMeaningExemptionReason =>
      'Der Hinweis auf die MwSt.-Befreiung';

  @override
  String get reportFieldMeaningHasVat => 'Wahr, wenn MwSt. anfällt';

  @override
  String get reportFieldMeaningIban => 'Die IBAN des Kontos';

  @override
  String get reportFieldMeaningInsurance => 'Der Hinweis zur Berufshaftpflicht';

  @override
  String get reportFieldMeaningIssued => 'Das Ausstellungsdatum';

  @override
  String get reportFieldMeaningIssuedBy => 'Wer das Dokument ausgestellt hat';

  @override
  String get reportFieldMeaningLatePenalty => 'Der Hinweis zu Verzugszinsen';

  @override
  String get reportFieldMeaningLines => 'Die Rechnungszeilen — eine Schleife';

  @override
  String get reportFieldMeaningMember => 'Der Anzeigename des Mitglieds';

  @override
  String get reportFieldMeaningNetTotal => 'Die Summe ohne MwSt.';

  @override
  String get reportFieldMeaningNumber => 'Die Nummer des Dokuments';

  @override
  String get reportFieldMeaningPaymentReference => 'Der Verwendungszweck';

  @override
  String get reportFieldMeaningPaymentTerms =>
      'Der Hinweis zu den Zahlungsbedingungen';

  @override
  String get reportFieldMeaningPaymentTermsSource =>
      'Woher die Zahlungsbedingungen stammen (Mitglied oder Raum)';

  @override
  String get reportFieldMeaningPayments => 'Bereits erhaltene Zahlungen';

  @override
  String get reportFieldMeaningPendingExpensesTotal =>
      'Noch freizugebende Ausgaben';

  @override
  String get reportFieldMeaningPendingPaymentsTotal =>
      'Noch zu bestätigende Zahlungen';

  @override
  String get reportFieldMeaningPeriod => 'Der Monat, den das Dokument abdeckt';

  @override
  String get reportFieldMeaningPeriodMonth =>
      'Der Monat der Periode, mit Namen („September“)';

  @override
  String get reportFieldMeaningPeriodYear => 'Das Jahr der Periode';

  @override
  String get reportFieldMeaningProforma => 'Wahr auf einer Proforma';

  @override
  String get reportFieldMeaningPurchaseOrder => 'Die Bestellnummer des Käufers';

  @override
  String get reportFieldMeaningRecoveryIndemnity =>
      'Der Hinweis zur Inkassopauschale';

  @override
  String get reportFieldMeaningRefundTotal => 'Der erstattete Betrag';

  @override
  String get reportFieldMeaningReplaces => 'Die Nummer der ersetzten Rechnung';

  @override
  String get reportFieldMeaningSellerLegalForm =>
      'Die Rechtsform des Verkäufers';

  @override
  String get reportFieldMeaningSellerLegalId =>
      'Die rechtliche Kennung des Verkäufers';

  @override
  String get reportFieldMeaningSellerRegistration =>
      'Die Registrierung des Verkäufers';

  @override
  String get reportFieldMeaningSellerVatId => 'Die USt-IdNr. des Verkäufers';

  @override
  String get reportFieldMeaningSiteAddress =>
      'Die Adresse des Dokument-Standorts';

  @override
  String get reportFieldMeaningSiteName => 'Der Name des Dokument-Standorts';

  @override
  String get reportFieldMeaningSpecialMentions =>
      'Die besonderen Hinweise des Raums';

  @override
  String get reportFieldMeaningStatusCreditNotes =>
      'Die ausgestellten Gutschriften';

  @override
  String get reportFieldMeaningStatusCredits => 'Die gewährten Gutschriften';

  @override
  String get reportFieldMeaningStatusFrom =>
      'Der erste Tag des Statuszeitraums';

  @override
  String get reportFieldMeaningStatusInvoiced =>
      'Was der Raum in Rechnung stellte';

  @override
  String get reportFieldMeaningStatusMembers =>
      'Die Zeilen je Mitglied — eine Schleife';

  @override
  String get reportFieldMeaningStatusNet => 'Einnahmen minus Ausgaben';

  @override
  String get reportFieldMeaningStatusPayments => 'Was eingenommen wurde';

  @override
  String get reportFieldMeaningStatusReimbursed => 'Was erstattet wurde';

  @override
  String get reportFieldMeaningStatusRepartitioned => 'Was umgelegt wurde';

  @override
  String get reportFieldMeaningStatusTo => 'Der letzte Tag des Statuszeitraums';

  @override
  String get reportFieldMeaningTotal => 'Der fällige Betrag, alles inklusive';

  @override
  String get reportFieldMeaningUsageExtraHalfDays =>
      'Halbe Tage über das Abo hinaus';

  @override
  String get reportFieldMeaningUsageIncludedHalfDays =>
      'Im Abo enthaltene halbe Tage';

  @override
  String get reportFieldMeaningUsageOverage => 'Der berechnete Mehrverbrauch';

  @override
  String get reportFieldMeaningUsagePaid =>
      'Was der Verbrauch des Monats kostete';

  @override
  String get reportFieldMeaningUsageRecords =>
      'Jeder Verbrauchseintrag — eine Schleife';

  @override
  String get reportFieldMeaningUsageRemainingHalfDays =>
      'Verbleibende halbe Tage';

  @override
  String get reportFieldMeaningUsageSites => 'Die anderen Standorte des Monats';

  @override
  String get reportFieldMeaningUsageSupplements => 'Die Zubehör-Zuschläge';

  @override
  String get reportFieldMeaningUsageUsedHalfDays => 'Verbrauchte halbe Tage';

  @override
  String get reportFieldMeaningVat => 'MwSt. je Satz — eine Schleife';

  @override
  String get reportFieldMeaningVatBasisNote =>
      'Ob der Zeitraum das Bezahlte oder das Ausgestellte zählt';

  @override
  String get reportFieldMeaningVatExigibilityMention =>
      'Wann die MwSt. fällig wird, in Worten';

  @override
  String get reportFieldMeaningVatPeriod => 'Der gemeldete MwSt.-Zeitraum';

  @override
  String get reportFieldMeaningVatPeriodGross =>
      'Die Bruttosumme des Zeitraums';

  @override
  String get reportFieldMeaningVatPeriodNet => 'Die Nettosumme des Zeitraums';

  @override
  String get reportFieldMeaningVatPeriodVat => 'Die MwSt. des Zeitraums';

  @override
  String get reportFieldMeaningVatPositions =>
      'Jede Rechnung des MwSt.-Zeitraums — eine Schleife';

  @override
  String get reportFieldMeaningVatRateTotals =>
      'Die Zeitraumsummen je Satz — eine Schleife';

  @override
  String get reportFieldMeaningVatTotal => 'Die gesamte MwSt.';

  @override
  String get reportFieldMeaningVoided =>
      'Wahr, wenn die Rechnung storniert ist';

  @override
  String get reportFieldMeaningWorkspace => 'Der Name des Raums';

  @override
  String get reportFieldMeaningWorkspaceAddress =>
      'Die Adresse des Raums oder des Dokument-Standorts';

  @override
  String get reportGuideInsertField => 'Feld einfügen…';

  @override
  String reportGuideInsertedInto(String band) {
    return 'Eingefügt in $band';
  }

  @override
  String get reportGuideIntro =>
      'Drei Bänder ergeben das PDF: Kopf, Rumpf, Fuß. Schreiben Sie Text, setzen Sie ein Feld, wo ein Wert hingehört, und ein Markup-Zeichen am Zeilenanfang für den Stil. Das E-Rechnungs-XML bleibt unberührt.';

  @override
  String get reportGuideMarkupTitle => 'Zeilen-Markup';

  @override
  String get reportGuideSnippetIf => 'Eine Zeile nur, wenn der Wert existiert';

  @override
  String get reportGuideSnippetLoop => 'Eine Zeile je Rechnungsposition';

  @override
  String get reportGuideSnippetTitle =>
      'Der Titel: Rechnung, Gutschrift oder Proforma';

  @override
  String get reportGuideSnippetsTitle => 'Fertige Bausteine';

  @override
  String get reportGuideTitle => 'Platzhalter und Markup';

  @override
  String get reportImageAlign => 'Ausrichtung';

  @override
  String get reportImageAlignCenter => 'Mitte';

  @override
  String get reportImageAlignLeft => 'Links';

  @override
  String get reportImageAlignRight => 'Rechts';

  @override
  String get reportImageSize => 'Größe';

  @override
  String get reportImageSizeLarge => 'Groß';

  @override
  String get reportImageSizeMedium => 'Mittel';

  @override
  String get reportImageSizeSmall => 'Klein';

  @override
  String get reportImageUpload => 'Bild hochladen';

  @override
  String get reportImagesEmpty =>
      'Noch kein Bild — laden Sie Ihr Logo, einen Stempel oder eine Unterschrift hoch und referenzieren Sie es mit ![name].';

  @override
  String get reportImagesLoadFailed =>
      'Berichtsbilder konnten nicht geladen werden. Erneut versuchen.';

  @override
  String get reportImagesTitle => 'Berichtsbilder';

  @override
  String get reportInsertImage => 'Bild einfügen';

  @override
  String get reportLanguageAmbiguous =>
      'Dieses Land hat mehrere Sprachen — legen Sie zuerst die Arbeitsbereichssprache in den Einstellungen fest.';

  @override
  String get reportLayoutActive => 'Layout aktiv';

  @override
  String get reportLayoutBands => 'Bänder';

  @override
  String get reportLayoutExport => 'XML exportieren';

  @override
  String get reportLayoutFileTypeLabel => 'XML';

  @override
  String get reportLayoutImport => 'XML importieren';

  @override
  String get reportLayoutImported =>
      'Layout importiert. Zum Behalten speichern.';

  @override
  String get reportLayoutPreview => 'Seitenvorschau';

  @override
  String get reportLayoutRemove => 'Layout entfernen (Bänder)';

  @override
  String get reportLayoutSubtitle =>
      'Ein Layout legt fest, wo jedes Element sitzt – in mm, cm, px oder %. Exportieren, bearbeiten, mit `dart run tool/report.dart check` prüfen, wieder importieren. Gibt es ein Layout, wird es gedruckt; wird es entfernt, drucken wieder die Bänder.';

  @override
  String get reportLayoutTitle => 'Positioniertes Layout (XML)';

  @override
  String get reportLineBoldRow => 'Fette Zeile';

  @override
  String get reportLineColumns => 'Spalten Anfang/Ende';

  @override
  String get reportLineColumnsSplit => 'Spaltenumbruch';

  @override
  String get reportLineDivider => 'Trenner';

  @override
  String get reportLineImage => 'Bild';

  @override
  String get reportLineLogic => 'Logik';

  @override
  String get reportLineRow => 'Tabellenzeile';

  @override
  String get reportLineSection => 'Abschnitt';

  @override
  String get reportLineSmall => 'Kleingedrucktes';

  @override
  String get reportLineSpacer => 'Abstand';

  @override
  String get reportLineText => 'Text';

  @override
  String get reportLineTitle => 'Titel';

  @override
  String get reportMarkupBoldRow => 'Eine fette Tabellenzeile';

  @override
  String get reportMarkupColumns => 'Spalten nebeneinander, getrennt durch |||';

  @override
  String get reportMarkupHeading => 'Ein großer Titel';

  @override
  String get reportMarkupImage =>
      'Ein Bild aus der Bibliothek: Größe s/m/l, Ausrichtung left/center/right';

  @override
  String get reportMarkupRule => 'Eine Trennlinie';

  @override
  String get reportMarkupSection => 'Eine Abschnittsüberschrift';

  @override
  String get reportMarkupSmall => 'Kleiner, gedämpfter Text';

  @override
  String get reportMarkupTable => 'Eine Tabellenzeile, eine Zelle je |';

  @override
  String get reportPaymentsPeriodTotal => 'Zahlungen im Zeitraum';

  @override
  String get reportPendingExpenses => 'Ausstehende Auslagen';

  @override
  String get reportPendingPayments => 'Ausstehende Zahlungen';

  @override
  String get reportPresetClassic => 'Klassisch';

  @override
  String get reportPresetFormalLetter => 'Formeller Brief';

  @override
  String get reportPresetProfessional => 'Professionell';

  @override
  String get reportPresetSimple => 'Einfach';

  @override
  String get reportPresetVerbose => 'Ausführlich';

  @override
  String get reportPreviewFit => 'An die Breite anpassen';

  @override
  String get reportPreviewSimulated => 'Schnellvorschau — Beispieldaten';

  @override
  String get reportPreviewTitle => 'Schnellvorschau — Ihre neueste Rechnung';

  @override
  String get reportPreviewZoomIn => 'Vergrößern';

  @override
  String get reportPreviewZoomOut => 'Verkleinern';

  @override
  String get reportQuickView => 'Schnellansicht';

  @override
  String get reportRegards => 'Mit freundlichen Grüßen';

  @override
  String get reportSectionFeatures => 'Funktionen';

  @override
  String get reportSectionPrices => 'Preise';

  @override
  String get reportSpaceCodesFooter =>
      'Eine Karte, die nicht mehr zu ihrem Bereich passt, führt jeden in die Irre, der sie scannt — drucken Sie den Bogen nach dem Verschieben oder Umbenennen neu.';

  @override
  String get reportSpaceCodesIntro =>
      'Eine Karte je Platz, Tisch, Büro und Etage. Jede Karte auf ihren Raum kleben: Scannen öffnet dasselbe Blatt wie der Kiosk.';

  @override
  String get reportSpaceCodesTitle => 'Raum-Codes';

  @override
  String get reportSubject => 'Betreff';

  @override
  String get reportTemplateClearOverlay =>
      'Für diese Sprache den Standard verwenden';

  @override
  String get reportTemplateLangDefault => 'Standard (alle Sprachen)';

  @override
  String get reportTemplateLangInherits => 'Erbt den Standard';

  @override
  String get reportTemplateLangOverridden => 'Eigene Vorlage';

  @override
  String get reportTextsAdd => 'Text hinzufügen';

  @override
  String get reportTextsHint =>
      'Eigene Formulierungen, in jeder Band oder Vorlage als text.schluessel platziert. Jede Sprache kann ihren Wert tragen; ein leerer fällt auf die Standardsprache zurück.';

  @override
  String get reportTextsInherited => 'Standardsprache';

  @override
  String get reportTextsKey => 'Schlüssel';

  @override
  String get reportTextsKeyExists => 'Dieser Schlüssel existiert bereits.';

  @override
  String get reportTextsKeyHint =>
      'Buchstaben, Ziffern und Unterstriche, z. B. gruss';

  @override
  String get reportTextsKeyInvalid =>
      'Nur Buchstaben, Ziffern und Unterstriche, beginnend mit einem Buchstaben.';

  @override
  String get reportTextsRemove => 'Text entfernen';

  @override
  String get reportTextsTitle => 'Texte';

  @override
  String get reportVisualAddLine => 'Zeile hinzufügen';

  @override
  String get requestAccept => 'Annehmen';

  @override
  String get requestBlock => 'Blockieren';

  @override
  String get requestIgnore => 'Ignorieren';

  @override
  String get reservationCalendarFileButton => 'Kalenderdatei speichern';

  @override
  String get reservationCalendarFileContents => 'Dateiinhalt';

  @override
  String get reservationCalendarFileEvent => 'Termin';

  @override
  String get reservationCalendarFileLocation => 'Ort';

  @override
  String get reservationCalendarFileName => 'Datei';

  @override
  String get reservationCalendarFileRefused =>
      'Diese Buchung kann nicht exportiert werden: Sie gehört nicht Ihnen, oder sie existiert nicht mehr.';

  @override
  String get reservationCalendarFileSnapshotNote =>
      'Diese Datei ist eine Momentaufnahme der Buchung, wie sie jetzt ist. Wird die Buchung später verschoben oder storniert, ändert sich eine bereits gespeicherte oder geteilte Datei nicht — und eine geteilte Datei lässt sich nicht zurückholen.';

  @override
  String get reservationCalendarFileStale =>
      'Die Buchung hat sich seit dieser Vorschau geändert. Prüfen Sie sie erneut, bevor Sie speichern.';

  @override
  String get reservationCalendarFileStatus => 'Status';

  @override
  String get reservationCalendarFileStatusCancelled => 'Storniert';

  @override
  String get reservationCalendarFileStatusConfirmed => 'Bestätigt';

  @override
  String get reservationCalendarFileTitle => 'Kalenderdatei';

  @override
  String get reservationCalendarFileWhen => 'Wann';

  @override
  String get reservationCancelledSnack => 'Reservierung storniert.';

  @override
  String get reservationDeleteReasonLabel => 'Grund (optional)';

  @override
  String get reservationDeleteRequestButton => 'Löschung beantragen';

  @override
  String get reservationDeleteRequestExplain =>
      'Vergangene oder eingecheckte Buchungen werden nicht direkt gelöscht. Inhaber oder Admin entscheiden: wurde der Check-in nur vergessen (die Buchung bleibt), oder wurde sie nie genutzt (sie wird entfernt)?';

  @override
  String get reservationDeleteSubmit => 'Anfrage senden';

  @override
  String get reservationDeleteSubmitted =>
      'Löschung beantragt — Inhaber oder Admin entscheiden.';

  @override
  String get reservationEditTimes => 'Zeit ändern';

  @override
  String get reservationEndEarlyAheadOnly =>
      'Wählen Sie eine Zeit, die noch bevorsteht und vor dem aktuellen Ende liegt.';

  @override
  String get reservationEndEarlyButton => 'Früher beenden';

  @override
  String get reservationExtendButton => 'Länger bleiben';

  @override
  String get reservationExtendLaterOnly =>
      'Wählen Sie eine Zeit nach dem aktuellen Ende.';

  @override
  String get reservationLimitError =>
      'Reservierungslimit erreicht — Sie halten bereits die maximale Zahl offener Reservierungen.';

  @override
  String reservationNoteCheckedOutAt(String time) {
    return 'Abgeschlossen: ausgecheckt um $time.';
  }

  @override
  String get reservationNoteOverNotCheckedIn =>
      'Dieser Zeitraum ist ohne Check-in vorbei.';

  @override
  String get reservationNoteRecordedAfterEnd =>
      'Nach dem Ende dieses Zeitraums erfasst, daher als vergangener Besuch erhalten.';

  @override
  String get reservationRecurring => 'Wiederkehrende Reservierung';

  @override
  String get reservationUpdatedSnack => 'Reservierung aktualisiert.';

  @override
  String get reserveAvailabilityUnavailable =>
      'Die Verfügbarkeit konnte nicht vollständig geladen werden, deshalb wird kein Platz als frei angezeigt. Erneut versuchen.';

  @override
  String get reserveBackToNow => 'Zurück zu jetzt';

  @override
  String get reserveBookingFailed =>
      'Reservieren nicht möglich — der Platz wurde eventuell gerade belegt.';

  @override
  String get reserveClosedShort => 'Geschl.';

  @override
  String get reserveDayView => 'Tag';

  @override
  String get reserveFullDayChip => 'Ganzer Tag';

  @override
  String get reserveMonthView => 'Monat';

  @override
  String get reservePickDateTooltip => 'Datum wählen';

  @override
  String reserveStaleAvailability(String time) {
    return 'Offline — Verfügbarkeit von $time. Ein frei angezeigter Platz kann inzwischen belegt sein.';
  }

  @override
  String get reserveStaleRetry => 'Erneut versuchen';

  @override
  String get reserveViewMenu => 'Ansicht';

  @override
  String get reserveWeekView => 'Woche';

  @override
  String get reverseChargeSubtitle =>
      'Ein Kunde mit USt-IdNr. in einem anderen Mitgliedstaat wird ohne Steuer fakturiert und schuldet sie selbst (Art. 196). Ausschalten, wenn Sie nie Unternehmen im Ausland fakturieren.';

  @override
  String get reverseChargeTitle => 'Reverse-Charge für EU-Unternehmen';

  @override
  String get rightsKindAccess => 'Eine Kopie meiner Daten erhalten';

  @override
  String get rightsKindErasure => 'Meine Daten löschen';

  @override
  String get rightsKindObjection =>
      'Einer Verwendung meiner Daten widersprechen';

  @override
  String get rightsKindPortability => 'Meine Daten mitnehmen (maschinenlesbar)';

  @override
  String get rightsKindRectification => 'Meine Daten berichtigen';

  @override
  String get rightsKindRestriction =>
      'Die Verarbeitung meiner Daten einschränken';

  @override
  String get rightsRequestAsk => 'Was beantragen Sie beim Bereich?';

  @override
  String get rightsRequestDetails => 'Einzelheiten (optional)';

  @override
  String get rightsRequestFailed =>
      'Der Antrag konnte nicht gesendet werden. Bitte versuchen Sie es erneut.';

  @override
  String get rightsRequestNew => 'Antrag stellen';

  @override
  String get rightsRequestSend => 'Antrag senden';

  @override
  String rightsRequestSent(String date) {
    return 'Antrag gesendet — der Bereich antwortet bis zum $date.';
  }

  @override
  String get rightsRequestsEmpty => 'Noch kein Antrag.';

  @override
  String get rightsRequestsHint =>
      'Bitten Sie den Bereich um eine Kopie, Berichtigung, Einschränkung oder Löschung — Antwort innerhalb eines Kalendermonats.';

  @override
  String get rightsRequestsTitle => 'Meine Anträge auf Betroffenenrechte';

  @override
  String get rightsStatusCompleted =>
      'Beantwortet — der Bereich hat festgehalten, was er getan hat';

  @override
  String rightsStatusExtended(String date, String reason) {
    return 'Verlängert bis $date: $reason';
  }

  @override
  String rightsStatusReceived(String date) {
    return 'Eingegangen — Antwort fällig bis $date';
  }

  @override
  String rightsStatusRefused(String reason) {
    return 'Abgelehnt: $reason';
  }

  @override
  String get roleAdmin => 'Administrator:in';

  @override
  String get roleAssignImmediateHint => 'Wirkt sofort.';

  @override
  String get roleAssignNothing => 'Es gibt keine Rolle mehr zu vergeben.';

  @override
  String get roleAssignQuorumHint => 'Wirkt, sobald es freigegeben ist.';

  @override
  String roleAssignSheetTitle(String name) {
    return '$name eine Rolle geben';
  }

  @override
  String get roleBuiltInNote =>
      'Eingebaut. Was sie darf, wird unter Rollen festgelegt; sie wird auf der Seite jedes Mitglieds vergeben und wirkt nach der Freigabe.';

  @override
  String get roleBuiltInSubtitle =>
      'Eingebaut. Was sie darf, wird unter Rollen festgelegt.';

  @override
  String get roleEditorActive => 'In Gebrauch';

  @override
  String get roleEditorHolders => 'Mitglieder mit dieser Rolle';

  @override
  String get roleEditorKey => 'Schlüssel';

  @override
  String get roleEditorKeyHelp =>
      'Kleinbuchstaben, Ziffern und Unterstriche. Er ändert sich nie: die Personen mit der Rolle hängen daran.';

  @override
  String roleEditorNameFor(String locale) {
    return 'Name ($locale)';
  }

  @override
  String get roleEditorNobody => 'Noch niemand.';

  @override
  String get roleEditorNotYourself =>
      'Sie können sich selbst keine Rolle geben.';

  @override
  String get roleEditorPermissions => 'Was sie ergänzt';

  @override
  String get roleEditorSave => 'Rolle speichern';

  @override
  String get roleEditorSaveFailed => 'Die Rolle wurde nicht gespeichert.';

  @override
  String get roleGiveFailed => 'Die Rolle wurde nicht vergeben.';

  @override
  String get roleGiven => 'Rolle vergeben.';

  @override
  String get roleHoldersAdd => 'Mitglied hinzufügen';

  @override
  String get roleMember => 'Alle Mitglieder';

  @override
  String get roleOwner => 'Inhaber';

  @override
  String get roleRefusalExceedsYours =>
      'Diese Rolle darf mehr als Sie, deshalb vergibt sie nur der Inhaber.';

  @override
  String get roleRefusalNotAssignable =>
      'Dieses Mitglied kann diese Rolle nicht haben.';

  @override
  String get roleRefusalNotPermitted =>
      'Nur wer Rollen verwaltet, kann diese vergeben.';

  @override
  String get roleRefusalOwnerOnly =>
      'Nur der Inhaber vergibt eine Rolle, die Rollen verwaltet.';

  @override
  String get roleRenameAdministrator => 'Umbenennen';

  @override
  String get roleTakeBackFailed => 'Die Rolle wurde nicht entzogen.';

  @override
  String get roleTakenBack => 'Rolle entzogen.';

  @override
  String get rolesIntroEditor =>
      'Jede Person hat genau eine Basisrolle — Benutzer, Administrator, Mit-Eigentümer oder Eigentümer. Jede weitere Rolle fügt hinzu, was ihre Inhaber dürfen, und nimmt nie etwas weg. Der Eigentümer hat immer alle Berechtigungen; ein Mit-Eigentümer kann weniger haben.';

  @override
  String get rolesIntroReadOnly =>
      'Nur lesen: Das sind die Berechtigungen jeder Rolle. Ihre Rolle ist hervorgehoben.';

  @override
  String get rolesOfSpaceAdd => 'Rolle hinzufügen';

  @override
  String get rolesOfSpaceEmpty => 'Noch keine Rollen.';

  @override
  String get rolesOfSpaceInactive => 'Zurückgestellt';

  @override
  String get rolesOfSpaceSubtitle =>
      'Jede ergänzt Rechte zu dem, was ihre Inhaber schon dürfen. Keine nimmt etwas weg, und der Inhaber des Space behält immer alle Rechte.';

  @override
  String get rolesOfSpaceTitle => 'Rollen dieses Bereichs';

  @override
  String get rolesOwnRolesLink => 'Die Rollen dieses Bereichs';

  @override
  String get rolesTitle => 'Rollen';

  @override
  String get rolesYourRole => 'Ihre Rolle';

  @override
  String get saftDocumentsOnly => 'Nur Belege';

  @override
  String get saftLedgerIntro =>
      'Mit Kontonummern enthält die Datei doppelte Buchungen, die Ihre Steuerberatung importieren statt eintippen kann. Sie decken Ihre Umsätze und die zugehörigen Zahlungen ab — nicht Ihre gesamte Buchführung.';

  @override
  String get saftLedgerTitle => 'Buchungen aufnehmen?';

  @override
  String get saftWithPostings => 'Mit Buchungen';

  @override
  String get sageAccountsIntro =>
      'Die Vorgaben sind Sages eigene Sachkonten. Der Steuerschlüssel entscheidet, auf welcher Umsatzsteuervoranmeldung die Buchungen landen — prüfen Sie ihn, wenn Sie nicht dem Regelsatz unterliegen.';

  @override
  String get sageAccountsTitle => 'Sage-Export';

  @override
  String get sageTaxCode => 'Steuerschlüssel (T1 / T0 / T9)';

  @override
  String get scanCameraWebUnavailable =>
      'Kamera-Scan ist im Browser nicht verfügbar — Code eingeben oder ein NFC-Tag ans Gerät halten (Chrome auf Android).';

  @override
  String get scanJoinHelp =>
      'Richten Sie die Kamera auf den Einladungs-QR — Sie sehen den Bereich, bevor Sie beitreten.';

  @override
  String get scanJoinNotAnInvite =>
      'Dieser QR ist keine DesKilo-Einladung — scannen Sie den aus der Einladungsnachricht.';

  @override
  String get scanJoinTitle => 'Workspace-QR scannen';

  @override
  String get scheduleCancel => 'Diesen Plan beenden';

  @override
  String get scheduleDaily => 'täglich';

  @override
  String get scheduleEndsOn => 'Bis (optional)';

  @override
  String scheduleEveryDays(Object count) {
    return 'alle $count Tage';
  }

  @override
  String get scheduleEveryLabel => 'Alle';

  @override
  String scheduleEveryMonths(Object count) {
    return 'alle $count Monate';
  }

  @override
  String scheduleEveryWeeks(Object count) {
    return 'alle $count Wochen';
  }

  @override
  String get scheduleMissingFields => 'Name und Betrag sind nötig.';

  @override
  String get scheduleMonthly => 'monatlich';

  @override
  String get scheduleNew => 'Wiederkehrende Ausgabe planen';

  @override
  String scheduleNextDue(Object date) {
    return 'nächste: $date';
  }

  @override
  String get scheduleNoEnd => 'Kein Enddatum';

  @override
  String get schedulePending =>
      'Geplant — wartet auf die Bestätigung der Validierer.';

  @override
  String get scheduleStartsOn => 'Erste Fälligkeit';

  @override
  String get scheduleStatusActive => 'Aktiv';

  @override
  String get scheduleStatusEnded => 'Beendet';

  @override
  String get scheduleStatusPending => 'Wartet auf Validierung';

  @override
  String get scheduleStatusRejected => 'Abgelehnt';

  @override
  String get scheduleSubmit => 'Planen';

  @override
  String scheduleTimes(Object count) {
    return '$count Mal';
  }

  @override
  String get scheduleTimesLabel => 'Wiederholungen (leer = bis zum Enddatum)';

  @override
  String get scheduleTitleLabel => 'Was (z. B. Internet)';

  @override
  String get scheduleUnitDays => 'Tage';

  @override
  String get scheduleUnitLabel => 'Einheit';

  @override
  String get scheduleUnitMonths => 'Monate';

  @override
  String get scheduleUnitWeeks => 'Wochen';

  @override
  String get scheduleUnitYears => 'Jahre';

  @override
  String scheduleUntil(Object date) {
    return 'bis $date';
  }

  @override
  String get scheduleValidationHint =>
      'Der Plan geht zuerst an die Validierer. Jede Fälligkeit wird Ihnen dann vorgelegt: zu diesem Betrag bestätigt zählt sie sofort; ein anderer Betrag erklärt sich und wird erneut validiert.';

  @override
  String get scheduleWeekly => 'wöchentlich';

  @override
  String get scheduleYearly => 'jährlich';

  @override
  String get scheduledAwaitingTitle => 'Geplante Ausgaben zur Bestätigung';

  @override
  String get scheduledExpensesEmpty => 'Noch keine geplante Ausgabe.';

  @override
  String scheduledExpensesFinished(int count) {
    return 'Beendet und abgelehnt ($count)';
  }

  @override
  String get scheduledExpensesIntro =>
      'Abos, die der Space bezahlt — Internet, Telefon, Strom. Der Plan wird einmal validiert; jede Fälligkeit wird Ihnen vorgelegt, bevor sie zählt.';

  @override
  String get scheduledExpensesTitle => 'Geplante Ausgaben';

  @override
  String schemaUpdateBody(int version) {
    return 'Diese App benötigt Version $version des DesKilo-Schemas, und der Server, mit dem sie sich verbindet, hat eine ältere. Bis der Server aktualisiert ist, würde die App auf eine Weise scheitern, die sie nicht erklären könnte – deshalb hält sie hier an.';
  }

  @override
  String get schemaUpdateMember =>
      'Andernfalls: Sagen Sie der Person Bescheid, die Ihren Space betreibt. Nichts von dem, was Sie eingegeben haben, geht verloren.';

  @override
  String get schemaUpdateOperator =>
      'Wenn Sie diesen Server betreiben: Spielen Sie die fehlenden Migrationen mit `dart run tool/instance.dart install --ref <projekt>` ein. Es läuft nur, was fehlt.';

  @override
  String get schemaUpdateRetry => 'Erneut prüfen';

  @override
  String get schemaUpdateServer => 'Server-Einstellungen';

  @override
  String get schemaUpdateTitle => 'Dieser Server muss aktualisiert werden';

  @override
  String get seatDayAhead => 'Später';

  @override
  String get seatDayFree => 'Frei — buchen';

  @override
  String get seatDayMine => 'Sie';

  @override
  String get seatDayNow => 'Jetzt';

  @override
  String get seatDayPast => 'Vorbei';

  @override
  String get seatDaySomeone => 'Ein Mitglied';

  @override
  String get seatDaySubtitle =>
      'Wer diesen Platz hat, und wann. Tippen Sie auf eine Buchung, um sie zu öffnen, oder auf eine freie Spanne, um sie zu nehmen.';

  @override
  String seatDayTitle(String seat) {
    return 'Platz $seat heute';
  }

  @override
  String seriesBookedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Reservierungen erstellt',
      one: '1 Reservierung erstellt',
    );
    return '$_temp0';
  }

  @override
  String get seriesSkippedTitle => 'Übersprungen (bereits belegt):';

  @override
  String get serverChoiceExistingTitle => 'Ein bestehender Server';

  @override
  String get serverChoiceIntro =>
      'Diese Version von DesKilo kommt ohne Server. Wählen Sie, wo Ihre Spaces liegen. Sie können das später unter Einstellungen → Erweitert → Server ändern.';

  @override
  String get serverChoiceNewBody =>
      'Legen Sie ein kostenloses Supabase-Projekt an und lassen Sie die App alles installieren, was DesKilo braucht: das Schema, die Funktionen und die Anmelderegeln.';

  @override
  String get serverChoiceNewTitle => 'Ein eigener neuer Server';

  @override
  String get serverChoiceReferenceAction => 'Referenzserver verwenden';

  @override
  String get serverChoiceReferenceBody =>
      'Betrieben vom Autor von DesKilo mit derselben freien Software wie jeder andere Server. Er trägt auch das globale Verzeichnis der Spaces.';

  @override
  String get serverChoiceReferenceTitle => 'Der Referenzserver';

  @override
  String get serverChoiceTitle => 'Server wählen';

  @override
  String get serverConnectIntro =>
      'Treten Sie einem Server bei, auf dem Sie bereits ein Konto haben, oder legen Sie einen neuen an.';

  @override
  String get serverConnectNoAccount =>
      'Noch kein Konto dort? Verwenden Sie diesen Server auf diesem Gerät und registrieren Sie sich dort.';

  @override
  String get serverConnectNoCode =>
      'Die Zwischenablage enthält keinen Servercode.';

  @override
  String get serverConnectPasteCode => 'Servercode einfügen';

  @override
  String get serverConnectReference => 'Referenzserver';

  @override
  String get serverConnectUseHere => 'Auf diesem Gerät verwenden';

  @override
  String serverReferenceLabel(String host) {
    return 'Referenzserver ($host)';
  }

  @override
  String get serviceOutOfStock => 'Ausverkauft';

  @override
  String get serviceOutOfStockHint =>
      'Nichts mehr im Regal — der nächste Vorrat füllt es auf.';

  @override
  String serviceStockCount(int count) {
    return '$count auf Lager';
  }

  @override
  String get servicesActive => 'Aktiv';

  @override
  String get servicesEdit => 'Leistung bearbeiten';

  @override
  String get servicesEmpty => 'Noch keine Leistungen.';

  @override
  String get servicesInactive => 'Inaktiv';

  @override
  String get servicesName => 'Name';

  @override
  String get servicesNew => 'Neue Leistung';

  @override
  String get servicesPrice => 'Preis';

  @override
  String get servicesTitle => 'Leistungen';

  @override
  String get settingsBillingReports => 'Abrechnung & Berichte';

  @override
  String get settingsFrontCamera => 'Mit der Frontkamera scannen';

  @override
  String get settingsFrontCameraDesc =>
      'Badges werden mit der Kamera auf der Bildschirmseite gelesen — ausschalten für die Rückkamera.';

  @override
  String get settingsSectionAccount => 'Mein Konto';

  @override
  String get settingsSectionAdministration => 'Verwaltung';

  @override
  String get settingsSectionAdvanced => 'Erweitert';

  @override
  String get settingsSectionGovernance => 'Governance';

  @override
  String get settingsSectionHelpAbout => 'Hilfe & Info';

  @override
  String get settingsSectionMembership => 'Meine Mitgliedschaft';

  @override
  String get settingsSectionWorkspace => 'Dieser Space';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settlementAction => 'Zu einer Rechnung zusammenfassen';

  @override
  String get settlementAnnexAlone => 'Nur diese Rechnung';

  @override
  String settlementAnnexBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Die $count Rechnungen, die diese ersetzt, können ihr folgen, jede auf eigenen Seiten und als zusammengefasst gestempelt.',
      one: 'Die Rechnung, die diese ersetzt, kann ihr folgen, auf eigenen Seiten und als zusammengefasst gestempelt.',
    );
    return '$_temp0';
  }

  @override
  String get settlementAnnexTitle =>
      'Die zusammengefassten Rechnungen anhängen?';

  @override
  String get settlementAnnexWith => 'Anhängen';

  @override
  String settlementConfirm(int count, String amount) {
    return '$count Rechnungen zu einer über $amount zusammenfassen?';
  }

  @override
  String get settlementDocumentationOnly =>
      'Nur Dokumentation — jede Aktion erfolgt auf der Sammelrechnung.';

  @override
  String settlementDone(String number) {
    return 'Zusammengefasst in $number.';
  }

  @override
  String settlementFoldedIn(String number) {
    return 'Zusammengefasst in $number';
  }

  @override
  String get settlementNeedsTwo =>
      'Wählen Sie mindestens zwei offene Rechnungen desselben Mitglieds.';

  @override
  String settlementPaidThrough(String number) {
    return 'Bezahlt über $number';
  }

  @override
  String get settlementRegroups => 'Diese Rechnung fasst zusammen';

  @override
  String settlementRegroupsNumbers(String numbers) {
    return 'Fasst $numbers zusammen';
  }

  @override
  String get settlementSettledBy =>
      'In eine andere Rechnung zusammengefasst — diese ist das, was geschuldet und angemahnt wird.';

  @override
  String get settlementSourcePdf => 'PDF (zusammengefasst)';

  @override
  String get settlementStepPick => 'Rechnungen wählen';

  @override
  String get settlementSummaryHint =>
      'Diese Rechnungen werden in einem Abrechnungsbeleg zusammengefasst; jede bleibt dahinter lesbar.';

  @override
  String get settlementVatNote =>
      'Die Positionen und ihre MwSt. sind aus den zusammengefassten Rechnungen übernommen; die Umsatzsteuererklärung zählt die Originale einmal.';

  @override
  String get shellBarHiddenAnnounce => 'Navigationsleiste ausgeblendet';

  @override
  String get shellBarHideHint => 'Lange drücken für die Vollbildansicht';

  @override
  String get shellBarShowHint =>
      'Lange drücken, um die Navigationsleiste einzublenden';

  @override
  String get shellBarShownAnnounce => 'Navigationsleiste eingeblendet';

  @override
  String shellPendingDecisions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Entscheidungen warten auf Sie',
      one: '1 Entscheidung wartet auf Sie',
    );
    return '$_temp0';
  }

  @override
  String get shellReserveButton => 'Reservieren';

  @override
  String get shellSwipeCoachMark =>
      'Wischen Sie die Leiste nach unten für die Vollbildansicht. Nach oben wischen oder die Reservieren-Taste lange drücken, um sie zurückzuholen.';

  @override
  String get siteCity => 'Ort';

  @override
  String get siteCountry => 'Land (Code)';

  @override
  String get siteDelete => 'Diesen Standort löschen';

  @override
  String get siteDeleteHint =>
      'Seine Ebenen und Mitglieder fallen an den Standard-Standort zurück.';

  @override
  String get siteExemptionReason => 'Befreiungsvermerk (diese Einheit)';

  @override
  String get siteLegalId => 'Registrierung der Betriebsstätte';

  @override
  String get siteName => 'Name des Standorts';

  @override
  String get sitePostalCode => 'Postleitzahl';

  @override
  String get siteRegistrationHint =>
      'Nur wenn der Standort eine eigene juristische Person ist — das ist meist ein eigener Arbeitsbereich. Leer: die Nummern des Arbeitsbereichs gelten.';

  @override
  String get siteSaved => 'Standort gespeichert.';

  @override
  String get siteStreet => 'Straße';

  @override
  String get siteVatId => 'USt-IdNr. (diese Einheit)';

  @override
  String get sitesAdd => 'Standort hinzufügen';

  @override
  String get sitesDefault => 'Standard-Standort';

  @override
  String get sitesIntro =>
      'Jede Ebene gehört zu einem Standort; der Standard-Standort trägt die Adresse des Arbeitsbereichs. Ein Mitglied hat einen Heimatstandort: das ist die Adresse auf seinen Belegen.';

  @override
  String get sitesLevels => 'Ebenen';

  @override
  String get sitesSubtitle =>
      'Adressen, die Ebenen je Standort, und wer wo zu Hause ist';

  @override
  String get sitesTitle => 'Standorte';

  @override
  String get spaceAlreadyCheckedInHere =>
      'Sie sind hier bereits eingecheckt. Wählen Sie « Auschecken », um den Platz freizugeben.';

  @override
  String get spaceBackToMe => 'Zurück zu Ich';

  @override
  String get spaceBlockedByYou =>
      'Sie halten diesen Bereich für diesen Zeitraum bereits.';

  @override
  String get spaceCardInfoLabel => 'Informationen auf der Karte';

  @override
  String get spaceCardInfoWorkspace => 'Workspace';

  @override
  String get spaceCardSizeLabel => 'Kartengröße';

  @override
  String get spaceCardSizeLarge => 'Groß';

  @override
  String get spaceCardSizeMedium => 'Mittel';

  @override
  String get spaceCardSizeSmall => 'Klein';

  @override
  String get spaceChipTooltip => 'Space wechseln';

  @override
  String get spaceCodesDesc =>
      'Eine druckbare QR-Karte je Platz, Tisch, Büro und Etage — Mitglieder scannen sie zum Reservieren oder Einchecken.';

  @override
  String get spaceCodesTitle => 'Raum-QR-Codes (PDF)';

  @override
  String get spaceFavoriteAdd => 'Zu den Favoriten hinzufügen';

  @override
  String get spaceFavoriteRemove => 'Aus den Favoriten entfernen';

  @override
  String spaceHostedOn(String server) {
    return 'Server: $server';
  }

  @override
  String get spaceKindDesk => 'Tisch';

  @override
  String get spaceKindLevel => 'Etage';

  @override
  String get spaceKindOffice => 'Büro';

  @override
  String get spaceKindSeat => 'Platz';

  @override
  String get spaceManageMyBooking => 'Meine Buchung verwalten';

  @override
  String spaceMessageReserver(String name) {
    return 'Nachricht an $name';
  }

  @override
  String get spaceMoveDown => 'Nach unten';

  @override
  String get spaceMoveUp => 'Nach oben';

  @override
  String get spaceNotBookable =>
      'Dieser Raum ist nicht für Ganzraum-Reservierungen eingerichtet.';

  @override
  String get spaceNotWholeBookable =>
      'Dieser Bereich ist nicht für Ganzbuchung eingerichtet — der Inhaber aktiviert dafür „Als Ganzes buchbar“ im Editor.';

  @override
  String spaceOptions(String name) {
    return 'Optionen für $name';
  }

  @override
  String get spaceQrSizeLabel => 'Größe des QR-Codes';

  @override
  String get spaceRatingClear => 'Keine Bewertung';

  @override
  String get spaceScanField => 'Code';

  @override
  String get spaceScanHint =>
      'Kamera auf die Karte eines Platzes, Tischs, Büros oder einer Etage richten — oder den Code eintippen.';

  @override
  String get spaceScanInvalid => 'Kein Raumcode dieses Workspace.';

  @override
  String get spaceScanNfcHint =>
      '…oder das Telefon an den NFC-Tag eines Stuhls halten.';

  @override
  String get spaceScanTitle => 'Raumcode scannen';

  @override
  String get spaceScanUnknown => 'Dieser Code passt zu keinem Raum mehr.';

  @override
  String get spaceScanUnknownTag =>
      'Dieser Tag ist mit keinem Stuhl verknüpft.';

  @override
  String get spaceSeatTaken => 'Belegt';

  @override
  String get spaceYoursCheckedIn =>
      'Sie sind hier für diesen Zeitraum eingecheckt.';

  @override
  String get spaceYoursNow => 'Von Ihnen für dieses Zeitfenster reserviert.';

  @override
  String get statusAwaiting => 'Offen';

  @override
  String get statusCreditNotes => 'Gutschriften';

  @override
  String get statusCredits => 'Gewährte Gutschriften';

  @override
  String get statusFrom => 'Von';

  @override
  String get statusInvoiced => 'In Rechnung gestellt';

  @override
  String get statusMembers => 'Mitglieder';

  @override
  String get statusNet => 'Netto';

  @override
  String get statusNetExplanation =>
      'Diese Zwischensumme entspricht Rechnungsbeträgen abzüglich Gutschriften, Erstattungen und Guthaben. Sie ist weder Gewinn noch Bankguthaben. Zugeordnete und eingegangene Zahlungen überschneiden sich und dürfen nicht addiert werden.';

  @override
  String get statusPaymentsMatched => 'Zugeordnete Zahlungen';

  @override
  String get statusPaymentsReceived => 'Eingegangene Zahlungen';

  @override
  String get statusPrint => 'Lage drucken';

  @override
  String get statusReimbursed => 'Erstattete Ausgaben';

  @override
  String get statusRepartitioned => 'Umgelegte Ausgaben';

  @override
  String get statusSubtitle =>
      'Einnahmen, Ausgaben und Mitglieder über einen Zeitraum';

  @override
  String get statusTitle => 'Lage des Arbeitsbereichs';

  @override
  String get statusTo => 'Bis';

  @override
  String get subprocessAttendance => 'Anwesenheit und Nutzung';

  @override
  String get subprocessAttendanceDesc =>
      'Anwesenheit erfassen und Check-ins am Tagesende abschließen.';

  @override
  String get subprocessAvailability => 'Öffnungstage und Zeiten';

  @override
  String get subprocessAvailabilityDesc =>
      'Arbeitszeiten festlegen und Schließtage erzeugen.';

  @override
  String get subprocessCalendar => 'Kalenderansichten';

  @override
  String get subprocessCalendarDesc =>
      'Buchungen und offene Entscheidungen im Zeitverlauf sehen.';

  @override
  String get subprocessCollection => 'Zahlungseingang';

  @override
  String get subprocessCollectionDesc =>
      'Zahlungen einziehen und überfällige Rechnungen nachverfolgen.';

  @override
  String get subprocessCommunication => 'Mitgliederkommunikation';

  @override
  String get subprocessCommunicationDesc =>
      'Nachrichten austauschen und Änderungen verfolgen.';

  @override
  String get subprocessConfiguration => 'Konfiguration und Bereitstellung';

  @override
  String get subprocessConfigurationDesc =>
      'Konfiguration übertragen, Vorlagen nutzen und Instanzen verwalten.';

  @override
  String get subprocessDecisions => 'Entscheidungen und Freigaben';

  @override
  String get subprocessDecisionsDesc =>
      'Aktionen prüfen und erforderliche Freigaben erfassen.';

  @override
  String get subprocessDelivery => 'Externer Versand';

  @override
  String get subprocessDeliveryDesc =>
      'Push, WhatsApp und den elektronischen Rechnungsversand anbinden.';

  @override
  String get subprocessDocuments => 'Dokumentbereitstellung';

  @override
  String get subprocessDocumentsDesc =>
      'Dokumente bereitstellen und druckbare Dateien erzeugen.';

  @override
  String get subprocessExpenses => 'Gemeinsame Ausgaben';

  @override
  String get subprocessExpensesDesc =>
      'Kosten verteilen, Vorräte auffüllen und wiederkehrende Ausgaben planen.';

  @override
  String get subprocessExperience => 'App-Bedienung';

  @override
  String get subprocessExperienceDesc =>
      'Hilfe, Navigation und Anzeigeeinstellungen anpassen.';

  @override
  String get subprocessInvoicing => 'Rechnungsstellung';

  @override
  String get subprocessInvoicingDesc =>
      'Unveränderliche Rechnungen erstellen und bis zum Ausgleich verfolgen.';

  @override
  String get subprocessPeople => 'Personen und Mitgliedschaften';

  @override
  String get subprocessPeopleDesc =>
      'Mitglieder identifizieren sowie Mitgliedschaften und Rechte verwalten.';

  @override
  String get subprocessPhysicalAccess => 'Zutritt';

  @override
  String get subprocessPhysicalAccessDesc =>
      'Ausweise, Platz-Tags und das gemeinsame Check-in-Terminal nutzen.';

  @override
  String get subprocessPresentation => 'Raumdarstellung';

  @override
  String get subprocessPresentationDesc =>
      'Personen und Plätze auf dem Plan erkennbar machen.';

  @override
  String get subprocessPricing => 'Leistungen und Preise';

  @override
  String get subprocessPricingDesc =>
      'Leistungen und Zubehör bepreisen und Mitgliedskonditionen vereinbaren.';

  @override
  String get subprocessPrivacy => 'Datenzugriff und Exporte';

  @override
  String get subprocessPrivacyDesc =>
      'Zugriffe auf personenbezogene Daten prüfen und Daten exportieren.';

  @override
  String get subprocessRecords => 'Finanzübersicht';

  @override
  String get subprocessRecordsDesc =>
      'Salden, Zahlungen und Mitgliedsabrechnungen nachvollziehen.';

  @override
  String get subprocessReportDesign => 'Berichtsgestaltung';

  @override
  String get subprocessReportDesignDesc =>
      'Berichte gestalten sowie Texte und Layouts pflegen.';

  @override
  String get subprocessReservations => 'Plätze und Räume buchen';

  @override
  String get subprocessReservationsDesc =>
      'Plätze oder ganze Räume nach den geltenden Regeln buchen.';

  @override
  String get subprocessStructure => 'Raumstruktur';

  @override
  String get subprocessStructureDesc =>
      'Standorte und die Verfügbarkeit von Planobjekten verwalten.';

  @override
  String get subprocessTax => 'Umsatzsteuerverwaltung';

  @override
  String get subprocessTaxDesc =>
      'Umsatzsteuergruppen, Steuersätze und Meldungen verwalten.';

  @override
  String get supportChanged =>
      'Der Kontext hat sich geändert. Erstellen Sie eine neue Vorschau.';

  @override
  String get supportDay => 'Letzte 24 Stunden';

  @override
  String get supportDemo => 'Demo: simulierter lokaler Kontext';

  @override
  String get supportFailed =>
      'Supportdetails konnten nicht vorbereitet werden. Erneut versuchen.';

  @override
  String get supportHour => 'Letzte Stunde';

  @override
  String get supportPrepare => 'Vorschau vorbereiten';

  @override
  String get supportPrivacy =>
      'Enthalten sind nur begrenzte Ereigniszähler dieses Geräts und bekannte Prüfergebnisse. Identitäten, Serveradressen, Zugangsdaten, Geschäftsdaten und Rohprotokolle sind ausgeschlossen. Unbekannte Prüfungen sind nicht verfügbar; ein Betreiber kann doctor --support-json separat ausführen. Geteilte Dateien können nicht zurückgerufen werden.';

  @override
  String get supportSaved => 'Lokal gespeichert';

  @override
  String supportSize(int bytes) {
    final intl.NumberFormat bytesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String bytesString = bytesNumberFormat.format(bytes);

    return 'Vorschau: $bytesString Bytes';
  }

  @override
  String get supportTitle => 'Supportdetails';

  @override
  String get symbolHint =>
      'Ein rundes Zeichen aus einem oder zwei Buchstaben auf einer Farbe, einmalig für diesen Arbeitsbereich — oder stattdessen unten ein Foto verwenden.';

  @override
  String get symbolLetters => 'Buchstaben';

  @override
  String get symbolLettersRule =>
      'Verwenden Sie ein oder zwei Buchstaben oder Ziffern für das Symbol.';

  @override
  String get symbolSaveFailed =>
      'Das Symbol konnte nicht gespeichert werden. Nichts wurde geändert.';

  @override
  String get symbolSaved => 'Symbol gespeichert.';

  @override
  String get symbolTaken =>
      'Ein anderer Arbeitsbereich nutzt diese Buchstaben bereits in dieser Farbe. Wählen Sie eine andere Farbe oder andere Buchstaben — oder verwenden Sie ein Foto.';

  @override
  String get symbolTitle => 'Symbol';

  @override
  String get tabCalendar => 'Kalender';

  @override
  String get tabEvents => 'Ereignisse';

  @override
  String get tabMoney => 'Finanzen';

  @override
  String get tabPlan => 'Plan';

  @override
  String get taskExportActionBack => 'Gehen Sie zurück.';

  @override
  String get taskExportActionCancelReview =>
      'Brechen Sie die Prüfung ab, ohne zu buchen.';

  @override
  String taskExportActionChangeField(String field) {
    return 'Ändern Sie das Feld: $field.';
  }

  @override
  String get taskExportActionConfirmBooking => 'Bestätigen Sie die Buchung.';

  @override
  String get taskExportActionOpenReserve =>
      'Öffnen Sie den Bildschirm Reservieren.';

  @override
  String get taskExportActionSelectDate => 'Wählen Sie das Datum.';

  @override
  String get taskExportActionSelectPeriod => 'Wählen Sie den Zeitraum.';

  @override
  String get taskExportActionSelectResource => 'Wählen Sie einen Platz.';

  @override
  String get taskExportActionSwitchView => 'Wechseln Sie die Ansicht.';

  @override
  String get taskExportActionUnknown =>
      'Eine Aktion, die diese Version nicht beschreiben kann.';

  @override
  String get taskExportActionViewDetails =>
      'Öffnen Sie die Reservierungsdetails.';

  @override
  String get taskExportAuthored =>
      'Beim Bearbeiten hinzugefügt: nicht vom Rekorder beobachtet.';

  @override
  String get taskExportCompletenessComplete =>
      'Vollständig: Die Aufzeichnung wurde von der Person beendet und jeder Befehl wurde beantwortet.';

  @override
  String get taskExportCompletenessInterrupted =>
      'Unterbrochen: Die App wurde während der Aufzeichnung beendet.';

  @override
  String get taskExportCompletenessPartial =>
      'Teilweise: Die Aufzeichnung endete vorzeitig oder ein Befehl blieb ohne Antwort.';

  @override
  String taskExportDetail(String field, String value) {
    return '$field: $value';
  }

  @override
  String get taskExportDocFallbackTitle => 'Aufgabenablauf';

  @override
  String taskExportDuration(int minutes, int seconds) {
    return 'Dauer: $minutes min $seconds s';
  }

  @override
  String get taskExportEndInterrupted => 'Beendet, weil die App beendet wurde.';

  @override
  String get taskExportEndLimitReached =>
      'Beendet, weil eine Schritt-, Größen- oder Zeitgrenze erreicht wurde.';

  @override
  String get taskExportEndScopeChanged =>
      'Beendet, weil sich Konto, Arbeitsbereich oder Installation geändert haben.';

  @override
  String get taskExportEndStopped => 'Von der aufzeichnenden Person beendet.';

  @override
  String get taskExportEndStorageFailed =>
      'Beendet, weil das Schreiben der Aufzeichnung fehlgeschlagen ist.';

  @override
  String taskExportExcluded(String category) {
    return 'Ein geschützter Bildschirm wurde besucht ($category); darauf wurde nichts aufgezeichnet.';
  }

  @override
  String get taskExportFieldAccessories => 'Zubehör';

  @override
  String get taskExportFieldCheckIn => 'Check-in';

  @override
  String get taskExportFieldDateRelation => 'Datum';

  @override
  String get taskExportFieldForWhom => 'Für wen';

  @override
  String get taskExportFieldPeriod => 'Zeitraum';

  @override
  String get taskExportFieldRefusal => 'Grund';

  @override
  String get taskExportFieldRepeat => 'Wiederholung';

  @override
  String get taskExportFieldResourceKind => 'Art des Platzes';

  @override
  String get taskExportFieldSeriesResult => 'Serie';

  @override
  String get taskExportFieldTime => 'Uhrzeit';

  @override
  String get taskExportFieldUnknown =>
      'ein Feld, das diese Version nicht beschreiben kann';

  @override
  String get taskExportFieldViewMode => 'Ansicht';

  @override
  String taskExportFooter(String page, String pages) {
    return 'Seite $page von $pages';
  }

  @override
  String get taskExportIllustrationNotApproved =>
      'Abbildung nicht eingefügt: Sie wurde nicht freigegeben.';

  @override
  String get taskExportIncludeIllustrations =>
      'Freigegebene Abbildungen einfügen';

  @override
  String get taskExportIntro =>
      'Dieses Dokument beschreibt Schritt für Schritt eine in DesKilo aufgezeichnete Aufgabe. Es ist eine Dokumentation: Es spielt die Aufgabe nicht ab und beweist nicht, dass sie gelungen ist. Nur was die Aufzeichnung beobachtet hat, wird als beobachtet angegeben.';

  @override
  String get taskExportKindEdited =>
      'Bearbeiteter Ablauf: aus einer Aufzeichnung abgeleitet und von einer Person geändert.';

  @override
  String get taskExportKindSource =>
      'Originalaufzeichnung: Die Schritte wurden vom Rekorder beobachtet.';

  @override
  String get taskExportLimitEdited =>
      'Als beim Bearbeiten hinzugefügt markierte Schritte wurden von einer Person geschrieben, nicht beobachtet.';

  @override
  String get taskExportLimitIncomplete =>
      'Die Aufzeichnung ist unvollständig: Was nach dem letzten gezeigten Schritt geschah, ist nicht bekannt.';

  @override
  String get taskExportLimitNoIllustrations =>
      'Dieses Dokument enthält keine Abbildungen.';

  @override
  String get taskExportLimitNotRunnable =>
      'Einige Schritte stammen aus einer neueren Version und können hier nicht beschrieben werden.';

  @override
  String get taskExportLimitRecreated =>
      'Die Abbildungen sind aus den sicheren Fakten der Aufzeichnung mit erfundenen Platznamen nachgebildet; sie sind keine Bildschirmfotos.';

  @override
  String get taskExportLimitValues =>
      'Eingegebene oder gewählte Werte werden nie aufgezeichnet: Nur ihre Art erscheint, und „nicht aufgezeichnet“ steht für alles andere.';

  @override
  String get taskExportNoResult =>
      'Für diesen Befehl wurde kein Ergebnis aufgezeichnet.';

  @override
  String taskExportNote(String note) {
    return 'Notiz der aufzeichnenden Person (ihre eigenen Worte): $note';
  }

  @override
  String get taskExportNoteOmitted =>
      'Eine persönliche Notiz wurde aus diesem Dokument weggelassen.';

  @override
  String taskExportOnScreen(String screen) {
    return 'Bildschirm: $screen';
  }

  @override
  String get taskExportOutcomeConfirmed => 'die Buchung wurde bestätigt';

  @override
  String get taskExportOutcomeRefused => 'die Buchung wurde abgelehnt';

  @override
  String get taskExportOutcomeRequested =>
      'die Buchung wurde angefragt und wartet auf eine Entscheidung';

  @override
  String get taskExportOutcomeSeriesBooked => 'die Serie wurde gebucht';

  @override
  String get taskExportOutcomeUnknown =>
      'keine Antwort konnte bestätigt werden; das Ergebnis ist unbekannt';

  @override
  String get taskExportOutcomeUnregistered =>
      'ein Ergebnis, das diese Version nicht beschreiben kann';

  @override
  String taskExportPauses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count-mal pausiert',
      one: 'Einmal pausiert',
      zero: 'Keine Pause',
    );
    return '$_temp0';
  }

  @override
  String taskExportPlatform(String platform) {
    return 'Aufgezeichnet auf: $platform';
  }

  @override
  String get taskExportPrereqBookablePlace =>
      'Mindestens ein Platz ist buchbar.';

  @override
  String get taskExportPrereqSignedIn => 'Sie sind angemeldet.';

  @override
  String taskExportPrereqStartsOn(String screen) {
    return 'Beginnen Sie hier: $screen.';
  }

  @override
  String get taskExportPrereqUnknown =>
      'Eine Bedingung, die diese Version nicht beschreiben kann.';

  @override
  String get taskExportPrereqWorkspaceMember =>
      'Sie sind Mitglied des Arbeitsbereichs.';

  @override
  String get taskExportProtectedAuthentication => 'Anmeldung';

  @override
  String get taskExportProtectedIdentity => 'Identität';

  @override
  String get taskExportProtectedMessenger => 'Nachrichten';

  @override
  String get taskExportProtectedOperator => 'Betreiber';

  @override
  String get taskExportProtectedPayment => 'Zahlung';

  @override
  String get taskExportProtectedProvider => 'Anbieter';

  @override
  String get taskExportProtectedSecrets => 'Geheimnisse';

  @override
  String get taskExportRefused =>
      'Diese Aufzeichnung kann nicht als Word-Dokument exportiert werden.';

  @override
  String taskExportResult(String outcome) {
    return 'Ergebnis: $outcome';
  }

  @override
  String taskExportRevision(String revision) {
    return 'Inhaltsrevision: $revision';
  }

  @override
  String get taskExportSaveFailed =>
      'Das Word-Dokument konnte nicht gespeichert werden. Die Aufzeichnung ist unverändert.';

  @override
  String taskExportSaved(String file) {
    return 'Word-Dokument gespeichert: $file';
  }

  @override
  String taskExportSceneAlt(String screen, String step) {
    return 'Abbildung: $screen – $step';
  }

  @override
  String get taskExportSceneBookingTitle => 'Platz buchen';

  @override
  String get taskExportSceneCancel => 'Abbrechen';

  @override
  String get taskExportSceneConfirm => 'Bestätigen';

  @override
  String get taskExportSceneDetailTitle => 'Reservierung';

  @override
  String get taskExportSceneLater => 'Später';

  @override
  String get taskExportSceneProvenance =>
      'Aus der Aufzeichnung nachgebildete Abbildung, kein Bildschirmfoto';

  @override
  String get taskExportSectionAbout => 'Über diese Aufzeichnung';

  @override
  String get taskExportSectionBefore => 'Bevor Sie beginnen';

  @override
  String get taskExportSectionLimits => 'Einschränkungen';

  @override
  String get taskExportSectionSteps => 'Schritte';

  @override
  String get taskExportStale =>
      'Das Storyboard gehört zu einer anderen Version dieser Aufzeichnung. Prüfen Sie es vor dem Export erneut.';

  @override
  String get taskExportStoryboardApprove => 'Abbildung freigeben';

  @override
  String get taskExportStoryboardGap =>
      'Lücke: hier wurde nichts aufgezeichnet';

  @override
  String get taskExportStoryboardInclude => 'Aufnehmen';

  @override
  String get taskExportStoryboardLeftOut =>
      'Schritt bei der Prüfung weggelassen.';

  @override
  String get taskExportStoryboardMoveDown => 'Nach unten';

  @override
  String get taskExportStoryboardMoveUp => 'Nach oben';

  @override
  String get taskExportStoryboardOrderRefused =>
      'Ein Ergebnis kann nicht vor dem Befehl stehen, den es beantwortet.';

  @override
  String get taskExportStoryboardRenderFailed =>
      'Die Abbildung konnte nicht gezeichnet werden; dieser Schritt bleibt Text.';

  @override
  String get taskExportStoryboardSourceExcluded =>
      'Geschützter Bildschirm: nicht abgebildet';

  @override
  String get taskExportStoryboardSourceScene =>
      'Nachgebildete Abbildung (kein Bildschirmfoto)';

  @override
  String get taskExportStoryboardSourceText => 'Textfolie';

  @override
  String get taskExportSurfaceAny => 'ein beliebiger Bildschirm';

  @override
  String get taskExportSurfaceBookingSheet => 'das Buchungsblatt';

  @override
  String get taskExportSurfaceReservationDetail => 'die Reservierungsdetails';

  @override
  String get taskExportSurfaceReserve => 'der Bildschirm Reservieren';

  @override
  String get taskExportSurfaceUnknown =>
      'ein Bildschirm, den diese Version nicht beschreiben kann';

  @override
  String get taskExportUnrecorded =>
      'Ein Schritt, den diese Version nicht beschreiben kann.';

  @override
  String get taskExportValueAfternoon => 'Nachmittag';

  @override
  String get taskExportValueAllBooked => 'alle gebucht';

  @override
  String get taskExportValueClosed => 'der Arbeitsbereich war geschlossen';

  @override
  String get taskExportValueConflict => 'der Platz war bereits belegt';

  @override
  String get taskExportValueCustom => 'benutzerdefiniert';

  @override
  String get taskExportValueDesk => 'ein Schreibtisch';

  @override
  String get taskExportValueFullDay => 'ganzer Tag';

  @override
  String get taskExportValueHours => 'stundenweise';

  @override
  String get taskExportValueLater => 'später';

  @override
  String get taskExportValueLaterThisWeek => 'später in dieser Woche';

  @override
  String get taskExportValueList => 'Liste';

  @override
  String get taskExportValueMorning => 'Vormittag';

  @override
  String get taskExportValueNo => 'nein';

  @override
  String get taskExportValueOff => 'aus';

  @override
  String get taskExportValueOffline => 'keine Verbindung';

  @override
  String get taskExportValueOn => 'an';

  @override
  String get taskExportValueOnce => 'einmalig';

  @override
  String get taskExportValueOtherMember => 'ein anderes Mitglied';

  @override
  String get taskExportValueOtherPlace => 'eine andere Art von Platz';

  @override
  String get taskExportValueOtherReason => 'ein anderer Grund';

  @override
  String get taskExportValuePartiallyBooked => 'teilweise gebucht';

  @override
  String get taskExportValuePast => 'ein vergangener Tag';

  @override
  String get taskExportValuePermission => 'eine fehlende Berechtigung';

  @override
  String get taskExportValuePlan => 'Raumplan';

  @override
  String get taskExportValuePolicy => 'eine Buchungsregel';

  @override
  String get taskExportValueQuota => 'ein Kontingent';

  @override
  String taskExportValueRedacted(int length) {
    return 'nicht gespeichert ($length Zeichen)';
  }

  @override
  String get taskExportValueRoom => 'ein Raum';

  @override
  String get taskExportValueSelf => 'ich selbst';

  @override
  String get taskExportValueSeries => 'als Serie';

  @override
  String get taskExportValueToday => 'heute';

  @override
  String get taskExportValueTomorrow => 'morgen';

  @override
  String get taskExportValueWithheld => 'nicht aufgezeichnet';

  @override
  String get taskExportValueYes => 'ja';

  @override
  String taskExportVersion(int schema, int contract) {
    return 'Aufzeichnungsformat $schema, Aktionsvertrag $contract';
  }

  @override
  String get taskExportWordButton => 'Als Word-Dokument exportieren';

  @override
  String get taskGuideCreate => 'Leitfaden-Entwurf erstellen';

  @override
  String get taskGuideEditText => 'Text schreiben';

  @override
  String get taskGuideIntro =>
      'Jeder Schritt so, wie ihn eine Person befolgen wird. Ein buchender Schritt wartet auf die echte Antwort; nichts wird für die Person erledigt.';

  @override
  String get taskGuideManual => 'Diesen Schritt selbst ausführen';

  @override
  String taskGuideManualProtected(String category) {
    return 'Diesen Schritt selbst ausführen, auf einem geschützten Bildschirm: $category';
  }

  @override
  String get taskGuideNoText => 'Eine noch zu schreibende Anweisung';

  @override
  String get taskGuideOptional => 'Darf übersprungen werden';

  @override
  String get taskGuideRecovery =>
      'Bei Ablehnung: einen anderen Platz, Tag oder Zeitraum wählen und erneut bestätigen.';

  @override
  String get taskGuideSave => 'Leitfaden speichern';

  @override
  String get taskGuideTitle => 'Leitfaden-Entwurf';

  @override
  String taskGuideWaitsFor(String outcomes) {
    return 'Wartet auf: $outcomes';
  }

  @override
  String get taskOutputBusy => 'Diese Ausgabe wird bereits erstellt.';

  @override
  String get taskOutputDocument => 'Word-Dokument';

  @override
  String get taskOutputFailed => 'Die Ausgabe konnte nicht erstellt werden.';

  @override
  String get taskOutputMake => 'Erstellen';

  @override
  String get taskOutputMissingMedia =>
      'Diese Aufgabe hat keine Bilder, die genutzt werden können.';

  @override
  String get taskOutputStale =>
      'Die Illustrationen wurden für eine frühere Fassung geprüft.';

  @override
  String get taskOutputStoryboard => 'Storyboard';

  @override
  String get taskOutputTooLong =>
      'Diese Aufgabe ist für diese Ausgabe zu lang.';

  @override
  String get taskOutputUnsupportedPlatform =>
      'Auf diesem Gerät nicht verfügbar.';

  @override
  String get taskRecorderActionBack => 'Zurückgegangen';

  @override
  String get taskRecorderActionCalendarCancel =>
      'Eine Reservierung im Kalender storniert';

  @override
  String get taskRecorderActionCalendarFilterKind =>
      'Geändert, was der Kalender zeigt';

  @override
  String get taskRecorderActionCalendarMove => 'Im Kalender geblättert';

  @override
  String get taskRecorderActionCalendarOpenItem =>
      'Einen Eintrag aus dem Kalender geöffnet';

  @override
  String get taskRecorderActionCalendarSelectDay =>
      'Einen Tag im Kalender gewählt';

  @override
  String get taskRecorderActionCalendarView => 'Kalenderansicht gewechselt';

  @override
  String get taskRecorderActionCalendarWhose =>
      'Gewählt, wessen Kalender angezeigt wird';

  @override
  String get taskRecorderActionCancelReservation =>
      'Die Reservierung storniert';

  @override
  String get taskRecorderActionCancelReview =>
      'Die Buchung ohne Buchen geschlossen';

  @override
  String get taskRecorderActionCancelRoleEdit =>
      'Die Rolle ohne Speichern geschlossen';

  @override
  String get taskRecorderActionCancelValidationRule =>
      'Die Regel ohne Speichern geschlossen';

  @override
  String get taskRecorderActionChangeField => 'Ein Buchungsdetail geändert';

  @override
  String get taskRecorderActionCheckIn => 'Eingecheckt';

  @override
  String get taskRecorderActionCheckOut => 'Ausgecheckt';

  @override
  String get taskRecorderActionCloseMyReservation =>
      'Meine Reservierung ohne Änderung geschlossen';

  @override
  String get taskRecorderActionConfirmBooking => 'Die Buchung bestätigt';

  @override
  String get taskRecorderActionDecideEvent =>
      'Auf eine Entscheidungsanfrage geantwortet';

  @override
  String get taskRecorderActionDeclineOptIn =>
      'Eine Testfunktion nicht eingeschaltet';

  @override
  String get taskRecorderActionGiveRole => 'Eine Rolle vergeben oder entzogen';

  @override
  String get taskRecorderActionOpenReserve => 'Reservieren geöffnet';

  @override
  String get taskRecorderActionOpenRoleMatrix => 'Rollenmatrix geöffnet';

  @override
  String get taskRecorderActionOpenSpaceRoles =>
      'Die Rollen dieses Bereichs geöffnet';

  @override
  String get taskRecorderActionOpenValidationRules =>
      'Die Freigaberegeln geöffnet';

  @override
  String get taskRecorderActionOpenWhatYouCanDo =>
      '„Was Sie tun können“ geöffnet';

  @override
  String get taskRecorderActionSaveRole => 'Eine Rolle gespeichert';

  @override
  String get taskRecorderActionSaveValidationRule =>
      'Eine Freigaberegel gespeichert';

  @override
  String get taskRecorderActionSelectDate => 'Den Tag gewählt';

  @override
  String get taskRecorderActionSelectLevel => 'Eine Ebene gewählt';

  @override
  String get taskRecorderActionSelectPeriod => 'Den Zeitraum gewählt';

  @override
  String get taskRecorderActionSelectResource => 'Einen Platz gewählt';

  @override
  String get taskRecorderActionSwitchFeature => 'Eine Funktion umgeschaltet';

  @override
  String get taskRecorderActionSwitchView => 'Die Ansicht gewechselt';

  @override
  String get taskRecorderActionTogglePermission =>
      'Eine Berechtigung umgeschaltet';

  @override
  String get taskRecorderActionUiCloseWindow => 'Ein Fenster geschlossen';

  @override
  String get taskRecorderActionUiCommand => 'Einen Befehl ausgeführt';

  @override
  String get taskRecorderActionUiCommitField => 'Ein Feld ausgefüllt';

  @override
  String get taskRecorderActionUiOpenScreen => 'Einen Bildschirm geöffnet';

  @override
  String get taskRecorderActionUiOpenWindow => 'Ein Fenster geöffnet';

  @override
  String get taskRecorderActionUiTap => 'Getippt';

  @override
  String get taskRecorderActionViewDetails => 'Die Reservierung geöffnet';

  @override
  String get taskRecorderAddNote => 'Notiz hinzufügen';

  @override
  String get taskRecorderCaptureValues => 'Werte erfassen (für Fehlerberichte)';

  @override
  String get taskRecorderCaptureValuesHint =>
      'Behält zusätzlich, was Sie eingeben und auswählen — Text, Zahlen, Daten, Schalter —, damit ein Entwickler das Problem anhand der Datei nachstellen kann. Passwörter, Zahlungsdaten, E-Mail-Adressen, Telefonnummern und andere persönliche Kontaktdaten werden nie gespeichert. Geben Sie die Datei nur an Personen weiter, die sehen dürfen, was Sie eingegeben haben.';

  @override
  String get taskRecorderCompletenessComplete => 'Vollständig';

  @override
  String get taskRecorderCompletenessInterrupted => 'Unterbrochen';

  @override
  String get taskRecorderCompletenessPartial => 'Unvollständig';

  @override
  String get taskRecorderDelete => 'Von diesem Gerät löschen';

  @override
  String get taskRecorderDeleteConfirm =>
      'Diese Aufzeichnung von diesem Gerät löschen? Exportierte Dateien sind nicht betroffen, und im Arbeitsbereich ändert sich nichts.';

  @override
  String get taskRecorderDiscard => 'Verwerfen';

  @override
  String get taskRecorderDisclosureBody =>
      'Der Rekorder notiert die Schritte, die Sie auf den Bildschirmen dieses Arbeitsbereichs ausführen — welcher Bildschirm, welche Aktion, was die App geantwortet hat — nur auf diesem Gerät. Er speichert nie, was Sie eingeben, keine Namen, Beträge, Nachrichten, Codes oder Passwörter. Anmeldung, Zahlung, Nachrichten und andere geschützte Bildschirme hinterlassen nur eine Markierung. Nichts wird hochgeladen: Sie entscheiden, was Sie exportieren.';

  @override
  String get taskRecorderDisclosureTitle => 'Bevor Sie aufzeichnen';

  @override
  String taskRecorderEditedNote(int count) {
    return 'Bearbeitete Kopie: $count Schritte ausgenommen. Die Aufzeichnung auf diesem Gerät bleibt unverändert.';
  }

  @override
  String get taskRecorderEndInterrupted =>
      'Unterbrochen: die App wurde während der Aufzeichnung beendet';

  @override
  String get taskRecorderEndLimitReached =>
      'Beendet: ein Grenzwert wurde erreicht';

  @override
  String get taskRecorderEndReferenceMissing =>
      'Gestoppt: Das aktuelle Formular konnte nicht erkannt werden. Öffnen Sie eine unterstützte Seite und starten Sie erneut.';

  @override
  String get taskRecorderEndScopeChanged =>
      'Beendet: Konto oder Arbeitsbereich hat gewechselt';

  @override
  String get taskRecorderEndStopped => 'Von Ihnen beendet';

  @override
  String get taskRecorderEndStorageFailed =>
      'Beendet: konnte auf diesem Gerät nicht gespeichert werden';

  @override
  String get taskRecorderExport => 'Datei exportieren';

  @override
  String get taskRecorderExportPackage => 'Aufgabenpaket exportieren';

  @override
  String get taskRecorderExportPreview => 'Was die Datei enthalten wird';

  @override
  String get taskRecorderExportValuesBody =>
      'Sie enthält, was während der Aufnahme eingegeben und ausgewählt wurde. Prüfen Sie sie vor dem Teilen und geben Sie sie nur an Personen weiter, die das sehen dürfen.';

  @override
  String get taskRecorderExportValuesConfirm => 'Trotzdem speichern';

  @override
  String get taskRecorderExportValuesTitle => 'Diese Aufnahme enthält Werte';

  @override
  String get taskRecorderFieldAccessories => 'Zubehör';

  @override
  String get taskRecorderFieldCheckIn => 'Check-in';

  @override
  String get taskRecorderFieldForWhom => 'für wen';

  @override
  String get taskRecorderFieldRepeat => 'Wiederholung';

  @override
  String get taskRecorderFieldTime => 'Uhrzeit';

  @override
  String taskRecorderIndicator(int count) {
    return 'Aufgabe wird aufgezeichnet: $count Schritte';
  }

  @override
  String get taskRecorderLeaveOut => 'Vom Export ausnehmen';

  @override
  String taskRecorderLimits(int steps, int minutes, int days) {
    return 'Bis zu $steps Schritte oder $minutes Minuten pro Aufzeichnung. Aufzeichnungen werden nach $days Tagen von diesem Gerät gelöscht; eine exportierte Datei gehört Ihnen und bleibt, wo Sie sie gespeichert haben.';
  }

  @override
  String get taskRecorderMyRecordings =>
      'Meine Aufzeichnungen auf diesem Gerät';

  @override
  String get taskRecorderNoOutcome => 'Keine Antwort aufgezeichnet';

  @override
  String get taskRecorderNoRecordings =>
      'Keine Aufzeichnungen auf diesem Gerät.';

  @override
  String get taskRecorderNoteHint =>
      'Ihre eigenen Worte, so gespeichert, wie Sie sie schreiben';

  @override
  String get taskRecorderOpenRecorder => 'Aufgabenrekorder öffnen';

  @override
  String get taskRecorderOutcomeCancelled => 'Storniert';

  @override
  String get taskRecorderOutcomeCheckedIn => 'Eingecheckt';

  @override
  String get taskRecorderOutcomeCheckedOut => 'Ausgecheckt';

  @override
  String get taskRecorderOutcomeCommandDone => 'Erledigt';

  @override
  String get taskRecorderOutcomeCommandPending => 'Zur Freigabe gesendet';

  @override
  String get taskRecorderOutcomeConfirmed => 'Gebucht';

  @override
  String get taskRecorderOutcomeEventDecided => 'Antwort gespeichert';

  @override
  String get taskRecorderOutcomeEventNotConfirmed =>
      'Die Antwort wurde nicht bestätigt';

  @override
  String get taskRecorderOutcomeRefused => 'Abgelehnt';

  @override
  String get taskRecorderOutcomeRequested => 'Zur Bestätigung gesendet';

  @override
  String get taskRecorderOutcomeSeries => 'Serie gebucht';

  @override
  String get taskRecorderOutcomeSettingNotSaved => 'Nicht gespeichert';

  @override
  String get taskRecorderOutcomeSettingPending => 'Zur Freigabe gesendet';

  @override
  String get taskRecorderOutcomeSettingSaved => 'Gespeichert';

  @override
  String get taskRecorderOutcomeUnknown => 'Keine Antwort erhalten';

  @override
  String get taskRecorderPause => 'Pausieren';

  @override
  String get taskRecorderPaused => 'Pausiert';

  @override
  String get taskRecorderProtectedAuthentication => 'Anmeldung';

  @override
  String get taskRecorderProtectedIdentity => 'Identität';

  @override
  String get taskRecorderProtectedMessenger => 'Nachrichten';

  @override
  String get taskRecorderProtectedOperator => 'Betreiber der Installation';

  @override
  String get taskRecorderProtectedPayment => 'Zahlung';

  @override
  String get taskRecorderProtectedProvider => 'Bildschirm eines Anbieters';

  @override
  String get taskRecorderProtectedSecrets => 'Schlüssel und Geheimnisse';

  @override
  String get taskRecorderPutBack => 'Wieder aufnehmen';

  @override
  String get taskRecorderRecordATask => 'Eine Aufgabe aufzeichnen';

  @override
  String get taskRecorderRecordThisTask => 'Diese Aufgabe aufzeichnen';

  @override
  String get taskRecorderRecording => 'Aufzeichnung läuft';

  @override
  String get taskRecorderResume => 'Fortsetzen';

  @override
  String get taskRecorderSaveFailed =>
      'Die Datei konnte nicht gespeichert werden.';

  @override
  String get taskRecorderSaveNoPath =>
      'Die Datei wurde an Ihren Browser oder Ihr Gerät übergeben; dieses hat nicht gesagt, wo sie gelandet ist.';

  @override
  String taskRecorderSaved(String path) {
    return 'Gespeichert: $path';
  }

  @override
  String taskRecorderSavedPrivately(String path) {
    return 'Nur in der App gespeichert: $path';
  }

  @override
  String get taskRecorderSegmentGap => 'Hier pausiert';

  @override
  String get taskRecorderSignedOut =>
      'Melden Sie sich an, um eine Aufgabe aufzuzeichnen.';

  @override
  String get taskRecorderStart => 'Aufzeichnung starten';

  @override
  String get taskRecorderStartFailed =>
      'Die Aufzeichnung konnte auf diesem Gerät nicht starten.';

  @override
  String taskRecorderStepCount(int count) {
    return '$count Schritte';
  }

  @override
  String get taskRecorderStepExcluded =>
      'Ein geschützter Bildschirm — nicht aufgezeichnet';

  @override
  String get taskRecorderStepNote => 'Ihre Notiz';

  @override
  String get taskRecorderStepUnrecorded =>
      'Ein Schritt, den der Rekorder nicht beschreiben kann';

  @override
  String get taskRecorderStop => 'Beenden';

  @override
  String get taskRecorderTargetAllKinds => 'alle Arten';

  @override
  String get taskRecorderTargetDefaultRule => 'die Standardregel';

  @override
  String get taskRecorderTargetUnkeyed => 'ein unbenanntes Bedienelement';

  @override
  String get taskRecorderTitle => 'Aufgabenrekorder';

  @override
  String get taskRecorderUnavailable =>
      'Die Aufzeichnung ist in diesem Arbeitsbereich nicht eingeschaltet.';

  @override
  String get taskRecorderUnreadable =>
      'Diese Aufzeichnung ist nicht lesbar. Sie können sie löschen.';

  @override
  String get taskRecorderUntitled => 'Aufgabe ohne Titel';

  @override
  String get taskRecorderValueAccept => 'angenommen';

  @override
  String get taskRecorderValueAfternoon => 'Nachmittag';

  @override
  String get taskRecorderValueAgenda => 'Agenda';

  @override
  String get taskRecorderValueAlert => 'eine Benachrichtigung';

  @override
  String get taskRecorderValueAllBooked => 'alle Termine gebucht';

  @override
  String get taskRecorderValueCheckIn => 'mit Check-in';

  @override
  String get taskRecorderValueClosed => 'geschlossen';

  @override
  String get taskRecorderValueConflict => 'bereits belegt';

  @override
  String get taskRecorderValueConversation => 'eine Unterhaltung';

  @override
  String get taskRecorderValueCreated => 'angelegt';

  @override
  String get taskRecorderValueCustom => 'eigene Zeiten';

  @override
  String get taskRecorderValueDay => 'Tag';

  @override
  String get taskRecorderValueDecision => 'eine Entscheidung';

  @override
  String get taskRecorderValueDecline => 'abgelehnt';

  @override
  String get taskRecorderValueDesk => 'ein Schreibtisch';

  @override
  String get taskRecorderValueEdited => 'bearbeitet';

  @override
  String get taskRecorderValueEveryone => 'der aller';

  @override
  String get taskRecorderValueFullDay => 'ganzer Tag';

  @override
  String get taskRecorderValueHours => 'stundenweise';

  @override
  String get taskRecorderValueInvoice => 'eine Rechnung';

  @override
  String get taskRecorderValueLater => 'ein späterer Tag';

  @override
  String get taskRecorderValueLaterThisWeek => 'später in dieser Woche';

  @override
  String get taskRecorderValueList => 'Liste';

  @override
  String get taskRecorderValueMine => 'meiner';

  @override
  String get taskRecorderValueMonth => 'Monat';

  @override
  String get taskRecorderValueMorning => 'Vormittag';

  @override
  String get taskRecorderValueNext => 'vor';

  @override
  String get taskRecorderValueNoCheckIn => 'ohne Check-in';

  @override
  String get taskRecorderValueOff => 'aus';

  @override
  String get taskRecorderValueOffline => 'offline';

  @override
  String get taskRecorderValueOn => 'ein';

  @override
  String get taskRecorderValueOnce => 'einmalig';

  @override
  String get taskRecorderValueOther => 'anderes';

  @override
  String get taskRecorderValueOtherMember => 'für ein anderes Mitglied';

  @override
  String get taskRecorderValuePartiallyBooked => 'einige Termine abgelehnt';

  @override
  String get taskRecorderValuePast => 'ein vergangener Tag';

  @override
  String get taskRecorderValuePayment => 'eine Zahlung';

  @override
  String get taskRecorderValuePermission => 'eine Berechtigung';

  @override
  String get taskRecorderValuePlan => 'Plan';

  @override
  String get taskRecorderValuePolicy => 'eine Buchungsregel';

  @override
  String get taskRecorderValuePrevious => 'zurück';

  @override
  String get taskRecorderValueQuota => 'ein Kontingent';

  @override
  String get taskRecorderValueRange => 'Zeitraum';

  @override
  String get taskRecorderValueRenamed => 'umbenannt';

  @override
  String get taskRecorderValueRoleAdmin => 'Administratoren';

  @override
  String get taskRecorderValueRoleCoOwner => 'ein Mitinhaber';

  @override
  String get taskRecorderValueRoleMember => 'jedes Mitglied';

  @override
  String get taskRecorderValueRoleOwner => 'der Inhaber';

  @override
  String get taskRecorderValueRoom => 'ein Raum';

  @override
  String get taskRecorderValueSelf => 'für mich';

  @override
  String get taskRecorderValueSeries => 'wiederholt';

  @override
  String get taskRecorderValueSomeoneElse => 'der eines anderen Mitglieds';

  @override
  String get taskRecorderValueTimeline => 'Zeitleiste';

  @override
  String get taskRecorderValueToday => 'heute';

  @override
  String get taskRecorderValueTomorrow => 'morgen';

  @override
  String get taskRecorderValueWeek => 'Woche';

  @override
  String get taskRecorderValueWithheld => 'nicht aufgezeichnet';

  @override
  String get taskRecorderValuesOn => 'Werte werden erfasst';

  @override
  String get taskWizardAddGuide => 'Anleitung hinzufügen';

  @override
  String get taskWizardAddToGuides => 'Zu meinen Anleitungen hinzufügen';

  @override
  String get taskWizardBuiltIn => 'Anleitungen, die mit der App kommen';

  @override
  String get taskWizardDeleteGuide => 'Diese Anleitung löschen';

  @override
  String get taskWizardDeleteGuideBody =>
      'Die Anleitung wird von diesem Gerät entfernt. Die Aufzeichnung, aus der sie stammt, bleibt unberührt.';

  @override
  String get taskWizardEdit => 'Bearbeiten';

  @override
  String get taskWizardFromFile => 'Aus einer Aufgabendatei oder einem Paket';

  @override
  String get taskWizardFromFileHint =>
      'Eine Aufzeichnung, ein Aufgabenpaket oder eine Anleitungsdatei von jemand anderem.';

  @override
  String get taskWizardFromRecording => 'Aus einer meiner Aufzeichnungen';

  @override
  String get taskWizardFromRecordingHint =>
      'Wählen Sie eine Aufzeichnung; sie wird sofort zur Anleitung.';

  @override
  String get taskWizardGuideAdded => 'Zu „Meine Anleitungen“ hinzugefügt.';

  @override
  String get taskWizardGuideName => 'Name der Anleitung';

  @override
  String get taskWizardGuideNotSaved =>
      'Die Anleitung konnte nicht gespeichert werden.';

  @override
  String get taskWizardGuides => 'Anleitungen';

  @override
  String get taskWizardIntro =>
      'Zeichnen Sie auf, was Sie tun, machen Sie daraus eine Anleitung und folgen Sie Anleitungen Schritt für Schritt in der echten App.';

  @override
  String get taskWizardMakeGuide => 'Anleitung erstellen';

  @override
  String get taskWizardNoGuides =>
      'Noch keine eigene Anleitung. Fügen Sie eine aus einer Aufzeichnung oder Aufgabendatei hinzu.';

  @override
  String get taskWizardOpenFileHint =>
      'Eine Aufzeichnung oder ein Aufgabenpaket ohne Konto lesen, bearbeiten und exportieren.';

  @override
  String get taskWizardRecordings => 'Aufzeichnungen';

  @override
  String get taskWizardSaveChanges => 'Änderungen speichern';

  @override
  String get taskWizardTitle => 'Aufgaben-Assistent';

  @override
  String get taskWizardTools => 'Werkzeuge';

  @override
  String get taskWizardUnavailable =>
      'Der Aufgaben-Recorder ist in diesem Arbeitsbereich ausgeschaltet: Anleitungen können hier gelesen und bearbeitet, aber nicht befolgt werden.';

  @override
  String taskWorkbenchAccepted(int megabytes) {
    return 'Akzeptiert: .json und .deskilo-task.zip, bis $megabytes MB.';
  }

  @override
  String get taskWorkbenchChoose => 'Aufgabendatei wählen';

  @override
  String taskWorkbenchClaim(String key, String value) {
    return 'Die Datei gibt an $key: $value';
  }

  @override
  String get taskWorkbenchEdited =>
      'Eine bearbeitete Kopie einer Aufzeichnung.';

  @override
  String get taskWorkbenchFileType => 'Aufgabendatei';

  @override
  String get taskWorkbenchIntro =>
      'Öffnen Sie eine gespeicherte Aufgabendatei. Sie wird nur auf diesem Gerät gelesen; nichts wird hochgeladen und keine Anmeldung ist nötig.';

  @override
  String get taskWorkbenchOfflineFailed =>
      'Der Browser hat das Behalten abgelehnt.';

  @override
  String get taskWorkbenchOfflineForget => 'Nicht mehr behalten';

  @override
  String get taskWorkbenchOfflineKeep => 'Auf diesem Gerät behalten';

  @override
  String get taskWorkbenchOfflineOff =>
      'Nicht behalten: ohne Verbindung öffnet sich diese Seite nicht.';

  @override
  String get taskWorkbenchOfflineReady =>
      'In diesem Browser gespeichert: Die geprüfte Aufgabenwerkstatt lässt sich offline öffnen. Aktionen im Arbeitsbereich benötigen weiterhin eine Verbindung.';

  @override
  String get taskWorkbenchOfflineTitle => 'Werkbank offline nutzen';

  @override
  String get taskWorkbenchOfflineUnsupported =>
      'Dieser Browser kann es nicht behalten (ein privates Fenster meist nicht).';

  @override
  String get taskWorkbenchOpen => 'Aufgabendatei öffnen';

  @override
  String get taskWorkbenchRefusedDamaged =>
      'Diese Datei ist beschädigt oder wurde nach dem Erstellen verändert.';

  @override
  String get taskWorkbenchRefusedInvalid =>
      'Diese Datei enthält keine gültige Aufgabe.';

  @override
  String get taskWorkbenchRefusedNewer =>
      'Diese Datei wurde mit einer neueren App-Version erstellt.';

  @override
  String get taskWorkbenchRefusedTooLarge =>
      'Diese Datei ist größer, als die Werkbank liest.';

  @override
  String get taskWorkbenchRefusedUnsafe =>
      'Diese Datei ist so aufgebaut, dass das Öffnen nicht sicher ist.';

  @override
  String get taskWorkbenchRefusedUnsupported => 'Das ist keine Aufgabendatei.';

  @override
  String get taskWorkbenchReviewIllustrations => 'Illustrationen prüfen';

  @override
  String get taskWorkbenchStoryboardRestored =>
      'Die geprüften Illustrationen wurden aus der Datei wiederhergestellt.';

  @override
  String get taskWorkbenchTitle => 'Aufgaben-Werkbank';

  @override
  String get taskWorkbenchTranscriptOnly =>
      'Einige Schritte stammen aus einer neueren Version: nur als Mitschrift angezeigt.';

  @override
  String get taskWorkbenchUntrusted =>
      'Ein privater Entwurf aus einer Datei: nichts darin gilt als vertrauenswürdig oder wird gesendet.';

  @override
  String get templateApplyConflict =>
      'Diese Anfrage wurde bereits für etwas anderes verwendet. Es wurde nichts übernommen.';

  @override
  String get templateChangedSinceReview =>
      'Diese Vorlage hat sich seit Ihrer Prüfung geändert. Es wurde nichts übernommen; öffnen Sie sie erneut, um die neue Version zu prüfen.';

  @override
  String get templateClearFilters => 'Suche zurücksetzen';

  @override
  String get templateDetailNone => 'Keine Einstellung passt.';

  @override
  String get templateDetailSearch =>
      'Eine Einstellung in dieser Vorlage finden';

  @override
  String get templateDetails => 'Was sie enthält';

  @override
  String templateExportResults(String count) {
    return 'Diese Ergebnisse exportieren ($count)';
  }

  @override
  String templateExportTooMany(String max) {
    return 'Höchstens $max Vorlagen pro Arbeitsmappe. Grenzen Sie die Suche zuerst ein.';
  }

  @override
  String get templateNoMatch =>
      'Keine Vorlage passt. Ändern Sie die Wörter, ein Schlagwort oder eine Voraussetzung.';

  @override
  String templatePrefer(String capability) {
    return 'Bevorzugen: $capability';
  }

  @override
  String templatePreferredChip(String capability) {
    return 'Bevorzugt: $capability';
  }

  @override
  String get templatePricesOtherCurrency =>
      'Die Preise der Vorlage sind in einer anderen Währung, daher wurden die Preise hier nicht geändert.';

  @override
  String get templateProfileFull => 'Vollständiges Konfigurationsprofil';

  @override
  String templateProfileSelected(String chosen, String total) {
    return 'Ausgewählte Gruppen: $chosen von $total';
  }

  @override
  String get templatePublishLocalNeeds =>
      'Ein Workspace, der sie anwendet, richtet dies selbst ein:';

  @override
  String templateRegionSuggested(String values) {
    return 'Diese Vorlage wurde für $values erstellt. Ihre Wahl bleibt, außer Sie übernehmen ihre Werte.';
  }

  @override
  String get templateRegionUse => 'Region der Vorlage übernehmen';

  @override
  String templateRequire(String capability) {
    return 'Voraussetzen: $capability';
  }

  @override
  String get templateRequirementRemove => 'Voraussetzung entfernen';

  @override
  String get templateRequirementsReset => 'Zurücksetzen';

  @override
  String templateResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Vorlagen angezeigt',
      one: '1 Vorlage angezeigt',
      zero: 'Keine Vorlage angezeigt',
    );
    return '$_temp0';
  }

  @override
  String templateValidatorsToChoose(String types) {
    return 'Wählen Sie in den Freigabeeinstellungen, wer $types freigibt; diese Regeln blieben unverändert.';
  }

  @override
  String get templateWhy => 'Warum diese Vorlage passt';

  @override
  String get templateWhyHide => 'Begründung ausblenden';

  @override
  String get templateWidenConfirm => 'Lesbar machen';

  @override
  String templateWidenCount(String count) {
    return '$count Einstellungen werden lesbar, genau so, wie die Vorlage sie jetzt enthält.';
  }

  @override
  String templateWidenExcluded(String count) {
    return '$count Arten von Werten verlassen den Workspace nie mit ihr (Bankdaten, Standorte, Adressen…).';
  }

  @override
  String templateWidenTitle(String audience) {
    return 'Diese Vorlage lesbar machen für: $audience?';
  }

  @override
  String get templatesLoadFailed =>
      'Die Vorlagen konnten nicht geladen werden.';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeSystem => 'Systemstandard';

  @override
  String get themeTitle => 'Design';

  @override
  String get threadNoRefs =>
      'Verweise werden nur mit Personen desselben Arbeitsbereichs geteilt.';

  @override
  String get threadRefsIn => 'Verweise in';

  @override
  String get tipAvailabilityClosure =>
      'Einen Tag schließen, den niemand buchen kann: auf „Schließtag hinzufügen“ tippen und bei Bedarf einen Grund angeben.';

  @override
  String get tipAvailabilityDays =>
      'Die Öffnungstage festlegen: die Wochentage unter „Geöffnete Wochentage“ an- oder abwählen.';

  @override
  String get tipAvailabilityGrid =>
      'Festlegen, wie Buchungen geteilt werden: eine „Buchungsraster“ wählen – freie Zeiträume, Slots, halbe oder ganze Tage.';

  @override
  String get tipAvailabilityHolidays =>
      'An Feiertagen schließen: auf „Feiertage hinzufügen“ tippen.';

  @override
  String get tipAvailabilityHours =>
      'Den Arbeitstag einstellen: „Tagesbeginn“, „Halbtagsgrenze“ und „Tagesende“ anpassen.';

  @override
  String get tipAvailabilityPolicies =>
      'Regeln verschärfen oder lockern – vergangene Buchungen, außerhalb der Öffnungszeiten, Buchungsgrenzen: „Buchungsregeln“ verwenden.';

  @override
  String get tipBadgesLost =>
      'Einen verlorenen Ausweis sperren: auf „Widerrufen“ tippen; einen gesperrten nach rechts wischen, um ihn zu löschen.';

  @override
  String get tipBadgesNfc =>
      'Eine NFC-Karte verwenden: auf „Karte registrieren“ tippen und die Karte an das Gerät halten.';

  @override
  String get tipBadgesQr =>
      'Jemandem einen QR-Ausweis geben: auf „Neuer Badge“ und dann „Als PDF speichern“ tippen, um ihn zu drucken.';

  @override
  String get tipBadgesSignIn =>
      'Sich mit dem eigenen Ausweis anmelden: „Meldet mich an“ am eigenen Ausweis einschalten.';

  @override
  String get tipCalendarAlerts =>
      'Benachrichtigungen und wartende Entscheidungen bearbeiten: „Hinweise“ öffnen.';

  @override
  String get tipCalendarKinds =>
      'Nur eine Art von Einträgen sehen: auf ihren Chip tippen – Buchungen, Rechnungen, Zahlungen …; „Filter zurücksetzen“ zeigt wieder alles.';

  @override
  String get tipCalendarMine =>
      'Nur die eigenen Buchungen sehen: auf „Meine Buchungen“ tippen.';

  @override
  String get tipCalendarMoney =>
      'Das Geld hinter einer Zahlung sehen: auf die Zeile tippen – die Finanzen öffnen sich bei dieser Zahlung.';

  @override
  String get tipCalendarViews =>
      'Eine Woche oder einen Monat auf einen Blick: auf „Woche“ oder „Monat“ tippen; „Heute“ führt zurück.';

  @override
  String get tipEditorAccessories =>
      'Zubehör an Plätzen anbieten: zuerst einrichten, dann in den „Eigenschaften“ jedes Platzes auswählen.';

  @override
  String get tipEditorBackground =>
      'Über einem echten Grundriss zeichnen: ihn unter „Hintergrundbild“ festlegen.';

  @override
  String get tipEditorDraw =>
      'Einen Raum oder Tisch zeichnen: in der Werkzeugleiste „Büro“ oder „Tisch“ wählen und auf dem Plan ziehen.';

  @override
  String get tipEditorLevel =>
      'Eine Etage hinzufügen: auf „Etage hinzufügen“ tippen; „Etagen-Aktionen“ benennt sie um oder löscht sie.';

  @override
  String get tipEditorNfc =>
      'Check-in per Tag ermöglichen: in den „Eigenschaften“ eines Platzes „NFC/RFID-Tag“ › „Jetzt einen Tag lesen“ verwenden.';

  @override
  String get tipEditorQr =>
      'QR-Karten für die Bereiche drucken: die Arbeitsbereichsdokumente öffnen und „Raum-QR-Codes (PDF)“ wählen.';

  @override
  String get tipEditorSeat =>
      'Einen Platz benennen oder zur Wartung sperren: auswählen und auf „Eigenschaften“ tippen.';

  @override
  String get tipEditorSeats =>
      'Plätze hinzufügen: das Werkzeug „Platz“ wählen und auf einen Tisch tippen.';

  @override
  String get tipEventsDecide =>
      'Eine wartende Anfrage beantworten: auf „Annehmen“ oder „Ablehnen“ tippen – sie steht oben im Verlauf.';

  @override
  String get tipEventsGroup =>
      'Den Verlauf gruppieren: „Gruppieren nach“ öffnen und Typ, Datum oder Mitglied wählen; „Gruppierung aufheben“ hebt es wieder auf.';

  @override
  String get tipEventsMessages =>
      'Ihre Unterhaltungen beantworten: den Messenger öffnen.';

  @override
  String get tipEventsTopic =>
      'Nur ein Thema sehen: auf seinen Chip tippen – Nachrichten, Reservierungen, Check-ins, Geld oder Mitglieder.';

  @override
  String get tipEventsUnread =>
      'Sehen, was noch ungelesen ist: auf „Ungelesen“ tippen.';

  @override
  String get tipFeaturesChanged =>
      'Sehen, was Sie gegenüber den Standards geändert haben: auf den Filter „Geändert“ tippen.';

  @override
  String get tipFeaturesProcess =>
      'Von dem ausgehen, was Sie tun wollen: „Prozesse“ wählen und danach suchen.';

  @override
  String get tipFeaturesRequires =>
      'Eine ausgegraute Funktion einschalten: zuerst die einschalten, die ihre Zeile „Benötigt“ nennt.';

  @override
  String get tipFeaturesSwitch =>
      'Eine Funktion ein- oder ausschalten: „Schalter“ wählen, sie suchen und den Schalter umlegen – die App jedes Mitglieds folgt sofort.';

  @override
  String get tipMembersApprove =>
      'Jemanden aufnehmen, der beitreten möchte: die Person öffnen und auf „Mitgliedschaft bestätigen“ tippen.';

  @override
  String get tipMembersBadge =>
      'Einen Ausweis ausstellen: das Mitglied öffnen und „Ausweise & Zugang“ › „Badges“ wählen.';

  @override
  String get tipMembersInvite =>
      'Jemanden einladen: die Arbeitsbereichs-ID oder ihren QR-Code teilen – „Mitglied einladen“ öffnet sie.';

  @override
  String get tipMembersManaged =>
      'Eine Person ohne Konto hinzufügen: „Verwaltetes Profil anlegen“.';

  @override
  String get tipMembersNotify =>
      'Allen Admins auf einmal schreiben: auf „Alle Admins benachrichtigen“ tippen.';

  @override
  String get tipMembersPlan =>
      'Den Tarif eines Mitglieds ändern: das Mitglied öffnen und unter „Abrechnung“ das „Abo“ einstellen.';

  @override
  String get tipMembersPrices =>
      'Preise und Tarife des Arbeitsbereichs festlegen: die Abrechnungseinstellungen öffnen.';

  @override
  String get tipMembersRole =>
      'Festlegen, was jede Rolle darf: die Rollen bearbeiten; ein Mitglied erhält eine mit „Rolle hinzufügen“ auf seiner Seite.';

  @override
  String get tipMessagesAlerts =>
      'Benachrichtigungen und wartende Entscheidungen bearbeiten: im Kalender „Hinweise“ öffnen.';

  @override
  String get tipMessagesUnread =>
      'Sehen, was noch ungelesen ist: im Messenger auf „Ungelesen“ tippen.';

  @override
  String get tipMessagesWrite =>
      'Jemandem schreiben oder eine Gruppe starten: den Messenger öffnen und auf den Stift tippen.';

  @override
  String get tipMoneyDays =>
      'Mehr Tage in diesem Monat bekommen: auf „Zusätzliche halbe Tage beantragen“ tippen.';

  @override
  String get tipMoneyDocumentsConditions =>
      'Die vereinbarten Bedingungen lesen: „Meine Konditionen“ öffnen.';

  @override
  String get tipMoneyDocumentsLibrary =>
      'Die geteilten Dokumente des Arbeitsbereichs finden: „Dokumentbibliothek“ öffnen.';

  @override
  String get tipMoneyDocumentsPayments =>
      'Auflisten, was Sie bezahlt haben: „Zahlungsbericht“ öffnen.';

  @override
  String get tipMoneyDocumentsStatement =>
      'Den Monat auf Papier behalten: „Monatsabrechnung (PDF)“ öffnen.';

  @override
  String get tipMoneyDocumentsUsage =>
      'Sehen, was Sie genutzt haben: „Verbrauchsbericht“ öffnen.';

  @override
  String get tipMoneyExpense =>
      'Eine Ausgabe erstattet bekommen: auf „Ausgabe einreichen“ tippen.';

  @override
  String get tipMoneyInvoicesAcross =>
      'Die Rechnungen aller Arbeitsbereiche zusammen sehen: „Ihre Finanzen in allen Workspaces“ öffnen.';

  @override
  String get tipMoneyInvoicesPay =>
      'Eine offene Rechnung bezahlen: darauf „Jetzt zahlen“ tippen.';

  @override
  String get tipMoneyInvoicesRead =>
      'Eine Rechnung lesen: darauf tippen – die Details öffnen sich, mit dem noch offenen Betrag.';

  @override
  String get tipMoneyMonth =>
      'Einen anderen Monat sehen: die Pfeile neben dem Monat verwenden.';

  @override
  String get tipMoneyPaymentsAcross =>
      'Ihr Geld über alle Arbeitsbereiche sehen: „Ihre Finanzen in allen Workspaces“ öffnen.';

  @override
  String get tipMoneyPaymentsConsumption =>
      'Etwas Verbrauchtes notieren – einen Kaffee, einen Ausdruck: auf „Verbrauch erfassen“ tippen.';

  @override
  String get tipMoneyPaymentsDays =>
      'Mehr Tage in diesem Monat bekommen: auf „Zusätzliche halbe Tage beantragen“ tippen.';

  @override
  String get tipMoneyPaymentsExpense =>
      'Eine Ausgabe erstattet bekommen: auf „Ausgabe einreichen“ tippen.';

  @override
  String get tipMoneyPaymentsOnline =>
      'Sofort bezahlen: auf „Online bezahlen“ tippen.';

  @override
  String get tipMoneyPaymentsRecord =>
      'Dem Arbeitsbereich mitteilen, dass Sie bezahlt haben: auf „Zahlung erfassen“ tippen.';

  @override
  String get tipMoneyPaymentsScheduled =>
      'Eine wiederkehrende Ausgabe planen: „Geplante Ausgaben“ öffnen.';

  @override
  String get tipMoneyPaymentsTransfer =>
      'Per Überweisung bezahlen: „Zahlungshinweise“ öffnen und die IBAN kopieren.';

  @override
  String get tipMoneyPdf =>
      'Ihre Abrechnung aufbewahren: auf „Rechnung als PDF exportieren“ tippen.';

  @override
  String get tipMoneyRecord =>
      'Dem Arbeitsbereich mitteilen, dass Sie bezahlt haben: auf „Zahlung erfassen“ tippen.';

  @override
  String get tipMoneyStatementAcross =>
      'Ihr Geld über alle Arbeitsbereiche sehen: „Ihre Finanzen in allen Workspaces“ öffnen.';

  @override
  String get tipMoneyStatementMonth =>
      'Einen anderen Monat sehen: die Pfeile verwenden; „Saldo“ zeigt, was noch offen ist.';

  @override
  String get tipMoneyStatementOut =>
      'Weiter buchen, wenn die Tage aufgebraucht sind: auf der Zahlungsseite „Zusätzliche halbe Tage beantragen“ oder „Paket kaufen“ tippen.';

  @override
  String get tipPrivacyConsent =>
      'Nachlesen, wozu Sie zugestimmt haben: Ihre Rechte und Einwilligung öffnen.';

  @override
  String get tipPrivacyErase =>
      'Mit gelöschten persönlichen Daten gehen: auf „Diesen Bereich verlassen und meine Daten löschen“ tippen.';

  @override
  String get tipPrivacyExport =>
      'Alles herunterladen, was der Arbeitsbereich über Sie speichert: auf „Meine Daten exportieren“ tippen.';

  @override
  String get tipPrivacyWho =>
      'Sehen, wer Ihre Daten lesen kann: auf „Wer meine Daten sehen kann“ tippen.';

  @override
  String get tipReserveAhead =>
      'Einen freien Tag im Voraus finden: „Ansicht“ öffnen, „Woche“ oder „Monat“ wählen und auf ein freies Feld oder einen freien Tag tippen.';

  @override
  String get tipReserveBook =>
      'Einen Platz buchen: Tag wählen, „Vormittag“, „Nachmittag“ oder „Ganzer Tag“ wählen, auf einen freien Platz tippen, dann „Reservieren“.';

  @override
  String get tipReserveChange =>
      'Eine Buchung ändern oder stornieren: darauf tippen und „Zeit ändern“, „Länger bleiben“, „Früher beenden“ oder „Reservierung stornieren“ wählen.';

  @override
  String get tipReserveCheckIn =>
      'Ein- oder auschecken: auf den eigenen Platz tippen und „Einchecken“ oder „Auschecken“ wählen – oder beim Buchen „Sofort einchecken“ einschalten.';

  @override
  String get tipReserveDefault =>
      'Damit Ihr üblicher Zeitraum vorausgewählt ist: „Standard-Buchungszeitraum“ in den Einstellungen festlegen.';

  @override
  String get tipReserveFavourite =>
      'Lieblingsplätze wiederfinden: auf „Zu Favoriten hinzufügen“ tippen und den Platz im Buchungsblatt mit den Sternen bewerten.';

  @override
  String get tipReserveLevel =>
      'Eine ganze Ebene buchen: in der Zeile der Ebene auf „Etage reservieren“ tippen.';

  @override
  String get tipReserveList =>
      'Aus einer Liste statt vom Plan buchen: auf „Listenansicht“ tippen; „Planansicht“ holt den Plan zurück.';

  @override
  String get tipReserveRepeat =>
      'Denselben Platz regelmäßig buchen: im Buchungsblatt „Weitere Optionen“ öffnen, dann „Wiederholen“ und „Wiederholen bis“ einstellen.';

  @override
  String get tipReserveScan =>
      'Über die QR-Karte eines Bereichs handeln: auf „Raumcode scannen“ tippen, die Kamera auf die Karte richten und die Aktion wählen.';

  @override
  String get tipValidationChain =>
      'Freigaben der Reihe nach erteilen lassen: „Nacheinander“ einschalten.';

  @override
  String get tipValidationCount =>
      'Mehr Freigaben verlangen: „Erforderliche Validierungen“ erhöhen oder sie mit „Nur über diesem Betrag“ erst ab einem Betrag verlangen.';

  @override
  String get tipValidationDefault =>
      'Die Regel ändern, die jede Aktion erbt: auf „Standardregel“ tippen.';

  @override
  String get tipValidationOverride =>
      'Eine Aktion anders behandeln: auf ihre Karte tippen und sie ändern – dann steht dort „Angepasst“.';

  @override
  String get tipValidationRoles =>
      'Festlegen, wer welche Rolle hat: die Rollen bearbeiten.';

  @override
  String get tipValidationWho =>
      'Wählen, wer freigibt – Admins, gelistete Personen oder alle Mitglieder: „Wer prüft“ einstellen.';

  @override
  String get tipWorkspaceSettingsBackup =>
      'Den Arbeitsbereich sichern oder kopieren: „Workspace exportieren (XML)“ verwenden.';

  @override
  String get tipWorkspaceSettingsColours =>
      'Der App Ihre Farben geben: sie auswählen.';

  @override
  String get tipWorkspaceSettingsDocuments =>
      'Die Dokumente des Arbeitsbereichs drucken – QR-Karten, Preislisten, Regeln: die Arbeitsbereichsdokumente öffnen.';

  @override
  String get tipWorkspaceSettingsGeneral =>
      'Land, Währung, Zeitzone und Sprache einstellen: „Allgemeine Angaben“ öffnen – Dokumente und Steuern richten sich danach.';

  @override
  String get tipWorkspaceSettingsLegal =>
      'Konforme Rechnungen und E-Rechnungen ausstellen: die rechtliche Identität vervollständigen.';

  @override
  String get tipWorkspaceSettingsNewMembers =>
      'Festlegen, womit neue Mitglieder starten: unter „Neue Mitglieder“ ihr Abo und das Verhalten bei aufgebrauchten Tagen wählen.';

  @override
  String get tipWorkspaceSettingsPay =>
      'Mitgliedern sagen, wie sie bezahlen: die Zahlungsanweisungen ausfüllen.';

  @override
  String get tipWorkspaceSettingsSave =>
      'Ihre Änderungen behalten: vor dem Verlassen unten auf „Speichern“ tippen.';

  @override
  String get tipWorkspaceSettingsWording =>
      'Dinge auf Ihre Art benennen – Plätze, Ebenen, Buchungen: die Begriffe ändern.';

  @override
  String get unblockAction => 'Blockierung aufheben';

  @override
  String get unblockDone => 'Blockierung aufgehoben.';

  @override
  String get usageAsk => 'Die Zeit berechnen, in der ich da war';

  @override
  String usageAskExplain(String booked, String present, String saved) {
    return 'Sie haben $booked gebucht und waren $present da. Bitten Sie darum, die nicht genutzten $saved nicht zu berechnen. Jemand anderes entscheidet — nie Sie.';
  }

  @override
  String get usageAskSubmit => 'Anfragen';

  @override
  String get usageAskSubmitted => 'Angefragt. Jemand anderes entscheidet.';

  @override
  String get usageBilled => 'Berechnet';

  @override
  String get usageBooked => 'Gebucht';

  @override
  String get usageCorrected => 'Korrigiert';

  @override
  String get usageDelete => 'Diesen Satz entfernen';

  @override
  String get usageDeleteSubmitted => 'Entfernung angefragt.';

  @override
  String get usageEmpty => 'Keine Nutzung in diesem Monat.';

  @override
  String get usageLeftEarly => 'Früher gegangen';

  @override
  String get usageMember => 'Mitglied';

  @override
  String get usageMemberAll => 'Alle';

  @override
  String get usageNoShow => 'Niemand kam — die Buchung wird voll berechnet';

  @override
  String get usagePresent => 'Anwesend';

  @override
  String get usageReasonLabel => 'Warum (optional)';

  @override
  String get usageReportButton => 'Verbrauchsbericht des Monats';

  @override
  String get usageReportExtra => 'Zusätzliche Halbtage';

  @override
  String get usageReportIncluded => 'Enthaltene Halbtage';

  @override
  String get usageReportOverage =>
      'Überziehung, auf die nächste Rechnung übertragen';

  @override
  String get usageReportPaid => 'Vorausbezahlt (Teilnahme)';

  @override
  String get usageReportRecordsHeading => 'Was verbraucht wurde';

  @override
  String get usageReportRemaining => 'Verbleibende Halbtage';

  @override
  String get usageReportSupplements => 'Zuschläge (Zubehör, Tische, Büros)';

  @override
  String get usageReportUsed => 'Verbrauchte Halbtage';

  @override
  String get usageTitle => 'Nutzung';

  @override
  String usageWas(String before) {
    return 'war $before';
  }

  @override
  String get uxAdvancedSection => 'Erweitert';

  @override
  String get uxAlertsFilterEmpty =>
      'Keine Meldungen entsprechen diesen Filtern.';

  @override
  String uxAttentionSummary(int updates, int pending) {
    return '$updates neue Meldungen · $pending ausstehende Entscheidungen';
  }

  @override
  String get uxBookingChargePending =>
      'Kosten und Kontingentverbrauch werden gemäß dem Tarif des Mitglieds berechnet. Ein endgültiger Betrag ist hier nicht verfügbar.';

  @override
  String get uxBookingCheckInHelp =>
      'Bei Bestätigung dieser Reservierung auch meine Anwesenheit melden.';

  @override
  String get uxBookingFor => 'Buchung für';

  @override
  String get uxBookingModesHelp =>
      'Reservieren behält den gewählten Zeitraum. Jetzt einchecken wechselt zum aktuellen Zeitraum und meldet Sie als anwesend.';

  @override
  String get uxBookingResourceUnavailable => 'Ressource nicht verfügbar';

  @override
  String get uxDeviceTime => 'Ihre Ortszeit';

  @override
  String get uxFinanceAlerts => 'Finanzmeldungen';

  @override
  String get uxFinanceAlertsFailed =>
      'Finanzmeldungen konnten nicht geöffnet werden. Bitte erneut versuchen.';

  @override
  String get uxLinkedReference => 'Verknüpfte Ressource';

  @override
  String get uxManageResource => 'Ressource verwalten';

  @override
  String get uxMoneyAllPeriods =>
      'Alle Zeiträume · Guthaben, offene Rechnungen und Erstattungen.';

  @override
  String get uxMoneyDocumentsScope =>
      'Monatsberichte und Ihre aktuelle Vereinbarung.';

  @override
  String get uxMoneyInvoicesScope =>
      'Ihre Rechnungen in diesem Workspace · Alle Zeiträume.';

  @override
  String get uxMoneyPaymentsScope =>
      'Monatssaldo · Überfällige Rechnungen aus allen Zeiträumen.';

  @override
  String get uxMoneyStatementScope =>
      'Monatsübersicht für den gewählten Zeitraum.';

  @override
  String get uxMoneyUsageScope => 'Buchungen und Verbrauch im gewählten Monat.';

  @override
  String get uxMoneyWorkspaceTools => 'Finanzverwaltung des Workspaces';

  @override
  String get uxMyBookings => 'Meine Buchungen';

  @override
  String get uxNavFinance => 'Abrechnung & Zahlungen';

  @override
  String get uxNavPeople => 'Mitglieder und Zugang';

  @override
  String get uxNavReporting => 'Reporting';

  @override
  String get uxNavWorkspace => 'Workspace einrichten';

  @override
  String get uxOpenWorkspace => 'Arbeitsbereich öffnen';

  @override
  String get uxPreferencesSection => 'Einstellungen';

  @override
  String get uxPrivacySection => 'Datenschutz';

  @override
  String get uxProfileAccount => 'Profil und Konto';

  @override
  String get uxProfileChooseEnvironment => 'Umgebung wählen';

  @override
  String get uxProfileSection => 'Profil';

  @override
  String get uxRealSpaceHint => 'Echte Buchungen und Rechnungen';

  @override
  String get uxRealWorkspace => 'Arbeitsbereich';

  @override
  String get uxReportsFinance => 'Finanzberichte';

  @override
  String get uxReportsHint => 'Finanzberichte, Workspace-Dokumente und Exporte';

  @override
  String get uxReportsTemplates => 'Vorlagen';

  @override
  String get uxReportsTitle => 'Berichte';

  @override
  String get uxReportsWorkspace => 'Workspace-Dokumente';

  @override
  String get uxResetFilters => 'Filter zurücksetzen';

  @override
  String get uxSettingsPersonal => 'Meine Einstellungen';

  @override
  String get uxSettingsSpace => 'Workspace verwalten';

  @override
  String get uxTestSpace => 'Testbereich';

  @override
  String get uxTestSpaceHint =>
      'Testbereich: Buchungen und Rechnungen zum Ausprobieren';

  @override
  String get uxWorkspaceAppearance => 'Darstellung und Bezeichnungen';

  @override
  String get uxWorkspaceCommunity => 'Gemeinschaft und Einladungen';

  @override
  String get uxWorkspaceGeneral => 'Allgemeine Angaben';

  @override
  String get uxWorkspaceTime => 'Ortszeit des Arbeitsbereichs';

  @override
  String get uxWorkspaceTools => 'Vorlagen und Daten';

  @override
  String get validationAdminsMay => 'Admins dürfen validieren';

  @override
  String get validationAllAdmins => 'Alle Admins';

  @override
  String get validationAutoValidateAdmin => 'Admins löschen ohne Validierung';

  @override
  String get validationAutoValidateDesc =>
      'Ihr eigener Löschantrag erledigt sich selbst und bleibt als automatisch validiert markiert.';

  @override
  String get validationAutoValidateOwner => 'Inhaber löschen ohne Validierung';

  @override
  String get validationCustomized => 'Angepasst';

  @override
  String get validationDefaultPolicy => 'Standardregel';

  @override
  String get validationInherited => 'Erbt den Standard';

  @override
  String get validationMinAmount => 'Nur über diesem Betrag';

  @override
  String get validationMinAmountDesc =>
      'Darunter wirkt der Vorgang sofort. Leer: jeder Betrag.';

  @override
  String get validationNoSelfDesc =>
      'Wer ein Ereignis auslöst, gibt es nie selbst frei. Es wartet auf jemand anderen oder verfällt unentschieden.';

  @override
  String get validationNoSelfShort => 'Nie das Eigene';

  @override
  String get validationNoSelfTitle => 'Niemand gibt das Eigene frei';

  @override
  String get validationNotEnough => 'Nicht genügend berechtigte Validierer.';

  @override
  String get validationOwnerOnly => 'Nur Inhaber';

  @override
  String get validationOwnerRequired => 'Inhaber muss immer validieren';

  @override
  String get validationOwnerSelf =>
      'Die Inhaberschaft darf das Eigene freigeben';

  @override
  String get validationOwnerSelfDesc =>
      'Die einzige Ausnahme, und sie gehört der Inhaberschaft allein: ein Admin gibt die eigene Handlung nie frei.';

  @override
  String get validationOwnerSelfShort =>
      'Inhaberschaft darf das Eigene freigeben';

  @override
  String get validationPickPersons => 'Personen wählen';

  @override
  String get validationRequiredCount => 'Erforderliche Validierungen';

  @override
  String get validationSaved => 'Validierungsregel gespeichert.';

  @override
  String get validationScopeAdmins => 'Admins';

  @override
  String get validationScopeHint =>
      'Der Inhaber darf immer. Admins: alle Admins oder die aufgeführten. Benannte: genau diese Personen, gleich welcher Rolle. Alle Mitglieder: jede aktive Person.';

  @override
  String get validationScopeLabel => 'Wer prüft';

  @override
  String get validationScopeListed => 'Benannte Personen';

  @override
  String get validationScopeMembers => 'Alle Mitglieder';

  @override
  String get validationSentForApproval =>
      'Zur Freigabe gesendet — wirkt nach der Genehmigung.';

  @override
  String get validationSequential => 'Nacheinander';

  @override
  String get validationSequentialDesc =>
      'Die nächste Freigabe wird erst angefragt, wenn die vorige durch ist, und der Verlauf nummeriert jede Stufe.';

  @override
  String get validationSpecificAdmins => 'Bestimmte Admins';

  @override
  String get validationStepApplies => 'es wird wirksam';

  @override
  String get validationStepOwnerToo => 'und der Inhaber, immer';

  @override
  String validationStepQuorum(int count, String who) {
    return '$who — beliebige $count';
  }

  @override
  String get validationStepRaised => 'Jemand fragt';

  @override
  String validationStepSequential(int count, String who) {
    return '$who — $count nacheinander';
  }

  @override
  String get validationThresholdNote => 'Kleinere Beträge gelten sofort.';

  @override
  String get validationTitle => 'Validierungsregeln';

  @override
  String validationTrailAwaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Noch $count Freigaben ausstehend.',
      one: 'Noch eine Freigabe ausstehend.',
    );
    return '$_temp0';
  }

  @override
  String get validationTrailNone => 'Noch keine Entscheidung.';

  @override
  String validationTrailStep(int order) {
    return 'Stufe $order';
  }

  @override
  String get validationTrailTitle => 'Freigabeverlauf';

  @override
  String get validationWorkflowBookings => 'Buchungen';

  @override
  String get validationWorkflowBookingsStake =>
      'Bis es angenommen ist, bleibt der Platz, wie er war.';

  @override
  String get validationWorkflowMoneyStake =>
      'Bis es angenommen ist, zählt der Betrag auf keiner Abrechnung.';

  @override
  String get validationWorkflowPeople => 'Personen und Rollen';

  @override
  String get validationWorkflowPeopleStake =>
      'Bis es angenommen ist, behält die Person ihre jetzigen Zugriffe.';

  @override
  String get vatAccountField => 'Steuerkonto';

  @override
  String get vatAccountHint =>
      'Konto, auf das der Buchhaltungsexport die vereinnahmte Steuer bucht. Leer = 445710.';

  @override
  String get vatAddRate => 'Satz hinzufügen';

  @override
  String get vatChangeByLaw => 'Änderung per Gesetz';

  @override
  String get vatChangeByLawExplainer =>
      'Ein neuer Wert ab einem Datum: der alte bleibt auf jeder Leistung davor, der neue gilt ab diesem Tag. Nichts wird umgehängt.';

  @override
  String get vatChangeInvalid =>
      'Nötig sind ein Prozentsatz zwischen 0 und 99,99 und ein Datum nach dem Beginn des Satzes.';

  @override
  String get vatChangeNeedsSave =>
      'Speichern Sie den Satz zuerst; dann ändern Sie ihn per Gesetz.';

  @override
  String get vatDeclBox => 'Kz';

  @override
  String get vatDeclBoxes => 'Kennzahlen des amtlichen Formulars';

  @override
  String get vatDeclDisclaimer =>
      'Aus den ausgestellten Rechnungen des Zeitraums erzeugt. Vor der Abgabe mit der Buchhaltung abgleichen — eine Abgabehilfe, keine Steuerberatung.';

  @override
  String get vatDeclDraft => 'Entwurf';

  @override
  String get vatDeclEmpty =>
      'Noch keine Voranmeldungen — Zeitraum wählen und die erste erstellen.';

  @override
  String get vatDeclGenerate => 'Erstellen';

  @override
  String get vatDeclInvoices => 'Rechnungen';

  @override
  String get vatDeclMarkFiled => 'Als abgegeben markieren';

  @override
  String get vatDeclMarkFiledConfirm =>
      'Bestätigen Sie, dass Sie diese Voranmeldung selbst abgegeben haben (ELSTER/Portal oder Steuerberater). Sie wird unveränderlich.';

  @override
  String get vatDeclNet => 'Bemessungsgrundlage';

  @override
  String get vatDeclPdf => 'PDF';

  @override
  String get vatDeclPeriod => 'Zeitraum';

  @override
  String get vatDeclRate => 'Steuersatz';

  @override
  String get vatDeclRegimeGate =>
      'Voranmeldungen gibt es nur unter dem umsatzsteuerpflichtigen Regime — in den USt-Einstellungen konfigurieren.';

  @override
  String get vatDeclRejected => 'Die Plattform hat die Voranmeldung abgelehnt.';

  @override
  String get vatDeclSeller => 'Verkäufer';

  @override
  String get vatDeclSent => 'Voranmeldung übermittelt.';

  @override
  String get vatDeclStatus => 'Status';

  @override
  String get vatDeclSubmitted => 'Übermittelt';

  @override
  String get vatDeclTitle => 'Umsatzsteuer-Voranmeldung';

  @override
  String get vatDeclTotals => 'Summen';

  @override
  String get vatDeclTransmit => 'Übermitteln';

  @override
  String get vatDeclVat => 'USt';

  @override
  String get vatDeclVatId => 'USt-IdNr.';

  @override
  String get vatDeclXml => 'XML-Export';

  @override
  String get vatDeclarationBasisEarlierOf =>
      'Grundlage: Rechnung oder Zahlung, je nachdem, was zuerst erfolgte (Steuer zum früheren der beiden Daten).';

  @override
  String get vatDeclarationBasisInvoice =>
      'Grundlage: vereinbarte Entgelte (Steuer auf im Zeitraum gestellte Rechnungen).';

  @override
  String get vatDeclarationBasisPayment =>
      'Grundlage: vereinnahmte Entgelte (Steuer auf im Zeitraum erhaltene Zahlungen).';

  @override
  String get vatDeclarationBasisServicePeriod =>
      'Grundlage: Leistungszeitraum (Steuer im Monat der Leistung; Anzahlungen im Monat des Zahlungseingangs).';

  @override
  String get vatEffectiveDate => 'Wirksam ab (JJJJ-MM-TT)';

  @override
  String get vatEmpty =>
      'Noch kein Satz — Rechnungen weisen keine Mehrwertsteuer aus.';

  @override
  String get vatExemptionReasonField => 'Befreiungsvermerk';

  @override
  String get vatExigibilityInvoice => 'Nach vereinbarten Entgelten (Soll)';

  @override
  String get vatExigibilityPayment => 'Nach vereinnahmten Entgelten (Ist)';

  @override
  String get vatExigibilitySubtitle =>
      'Die gesetzliche Regel hängt vom Land ab: Zahlungseingang in Frankreich, Leistungsmonat in Deutschland und Spanien, Rechnung oder Zahlung (was zuerst erfolgt) in Italien, im Vereinigten Königreich und in Kanada, die Rechnung in der Schweiz. Sie bestimmt, was ein Zeitraum meldet, und steht auf jeder Rechnung.';

  @override
  String get vatExigibilityTitle => 'Entstehung der Umsatzsteuer';

  @override
  String get vatGroupDeposit => 'Pfand (außerhalb der USt)';

  @override
  String get vatGroupExamples => 'Was in welche Gruppe fällt';

  @override
  String get vatGroupExcise => 'Verbrauchsteuerpflichtig';

  @override
  String get vatGroupExempt => 'Steuerfrei';

  @override
  String get vatGroupIntermediate => 'Zwischensatz';

  @override
  String get vatGroupLabel => 'Gruppe';

  @override
  String get vatGroupNotSubject => 'Nicht steuerbar';

  @override
  String get vatGroupReduced => 'Ermäßigt';

  @override
  String get vatGroupStandard => 'Regelsatz';

  @override
  String get vatGroupSuperReduced => 'Stark ermäßigt';

  @override
  String get vatGroupZero => 'Nullsatz';

  @override
  String get vatIntro =>
      'Preise in DesKilo sind Bruttopreise. Sätze anzulegen ändert nichts daran, was Mitglieder zahlen — die Steuer wird aus dem bestehenden Preis herausgerechnet und auf der Rechnung ausgewiesen.';

  @override
  String get vatKeptRate =>
      'Ein Satz, den eine Rechnung oder eine Leistung noch nutzt, bleibt erhalten und wird deaktiviert.';

  @override
  String get vatNeedsDefault => 'Genau einen Satz als Standard markieren.';

  @override
  String get vatNewPercent => 'Neuer Satz %';

  @override
  String get vatPdfNet => 'Netto';

  @override
  String get vatPdfVat => 'MwSt.';

  @override
  String get vatRateDefaultTooltip =>
      'Standardsatz — gilt für Abos und alles ohne eigenen Satz';

  @override
  String get vatRateIncomplete =>
      'Jeder Satz braucht einen Namen und einen Prozentwert zwischen 0 und 99,99.';

  @override
  String get vatRateLabelField => 'Name';

  @override
  String get vatRatePercentField => 'Satz %';

  @override
  String get vatRateRemoveTooltip => 'Entfernen';

  @override
  String get vatRatesTile => 'Steuersätze';

  @override
  String get vatRegimeHint =>
      'Dieser Space ist nicht als umsatzsteuerpflichtig deklariert, Rechnungen weisen daher keine Steuer aus. Das ändert sich unter Rechtliche Identität.';

  @override
  String get vatReportByRate => 'Summen je Satz';

  @override
  String get vatReportCsv => 'MwSt-Bericht (CSV)';

  @override
  String get vatReportPdf => 'MwSt-Bericht (PDF)';

  @override
  String get vatReportPositions => 'Positionen';

  @override
  String get vatReportTotals => 'Summen des Zeitraums';

  @override
  String get vatSaved => 'Steuersätze gespeichert.';

  @override
  String get vatSeed => 'Übliche Sätze übernehmen';

  @override
  String get vatServiceRate => 'Steuersatz';

  @override
  String get vatServiceRateDefault => 'Standard des Spaces';

  @override
  String vatShareAmount(String amount) {
    return 'inkl. USt $amount';
  }

  @override
  String get vatSince => 'ab';

  @override
  String get vatTaxPointEarlierOf =>
      'Mit Rechnung oder Zahlung, je nachdem, was zuerst erfolgt';

  @override
  String vatTaxPointLegalDefault(String rule) {
    return '$rule — gesetzliche Regel';
  }

  @override
  String get vatTaxPointNoticeFr =>
      'In Frankreich werden Dienstleistungen nach Zahlungseingang besteuert, sofern das Unternehmen nicht zur Besteuerung nach Rechnungsstellung (débits) optiert hat. Dieser Bereich hat nie gewählt; seine Erklärungen folgen jetzt den Zahlungseingängen. Wenn Sie optiert haben, wählen Sie dies unter Rechtliche Identität & E-Rechnung.';

  @override
  String get vatTaxPointServicePeriod =>
      'Mit Ausführung der Leistung (Anzahlungen bei Zahlungseingang)';

  @override
  String get vatTitle => 'Mehrwertsteuer';

  @override
  String get vatTreatmentAuto => 'Automatisch';

  @override
  String get vatTreatmentDomestic => 'Inlands-USt';

  @override
  String get vatTreatmentExempt => 'Befreiter Käufer';

  @override
  String get vatTreatmentExport => 'Außerhalb der EU';

  @override
  String get vatTreatmentReasonField =>
      'Befreiungsgrund (auf der Rechnung gedruckt)';

  @override
  String get vatTreatmentReverseCharge =>
      'Steuerschuldnerschaft des Empfängers';

  @override
  String get vatUntil => 'bis';

  @override
  String get visibilityAbout => 'Beruf und Kurzprofil';

  @override
  String get visibilityAboutEmpty => 'Beruf und ein paar Worte hinzufügen';

  @override
  String get visibilityAboutMe => 'Über mich';

  @override
  String get visibilityAboutSaveFailed =>
      'Beruf und Kurzprofil konnten nicht gespeichert werden. Bitte versuchen Sie es erneut.';

  @override
  String get visibilityBio => 'Ein paar Worte über Sie';

  @override
  String visibilityChosenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mitglieder von $count ausgewählten Spaces',
      one: 'Mitglieder von 1 ausgewählten Space',
    );
    return '$_temp0';
  }

  @override
  String get visibilityChosenSpaces => 'Mitglieder ausgewählter Spaces';

  @override
  String get visibilityContact => 'WhatsApp und E-Mail';

  @override
  String get visibilityElsewhereIntro =>
      'Auf einem verbundenen Server haben Sie das Konto dieses Servers. Wer dort keinen Raum mit Ihnen teilt, sieht, was Sie allen angemeldeten Personen erlauben; Kontaktdaten und Anwesenheit verlassen nie Ihre Räume.';

  @override
  String get visibilityElsewhereTitle => 'Auf meinen anderen Servern';

  @override
  String get visibilityIdentity => 'Name und Foto';

  @override
  String get visibilityIntro =>
      'Jeder Teil Ihres Kontos wählt sein eigenes Publikum. Nichts ist öffentlich, solange Sie es nicht wählen.';

  @override
  String get visibilityMySpaces => 'Mitglieder meiner Spaces';

  @override
  String get visibilityNobody => 'Niemand';

  @override
  String visibilityOnServer(String host) {
    return 'Wer mich auf $host sieht';
  }

  @override
  String visibilityOnServerUnavailable(String host) {
    return '$host hat nicht geantwortet. Versuchen Sie es später erneut.';
  }

  @override
  String get visibilityPresence => 'Heute im Space';

  @override
  String get visibilityPreviewCanWrite =>
      'Kann ein Gespräch mit Ihnen beginnen';

  @override
  String get visibilityPreviewCannotWrite =>
      'Kann kein Gespräch mit Ihnen beginnen';

  @override
  String get visibilityPreviewFailed =>
      'Die Vorschau konnte nicht geladen werden.';

  @override
  String get visibilityPreviewMySpaces => 'Ein Mitglied meiner Spaces';

  @override
  String get visibilityPreviewNobody => 'Nur ich';

  @override
  String get visibilityPreviewNothing =>
      'Diese Personen sehen nichts von Ihnen.';

  @override
  String get visibilityPreviewSignedIn => 'Alle Angemeldeten';

  @override
  String get visibilityPreviewTitle => 'Wie andere mich sehen';

  @override
  String get visibilityProfession => 'Beruf';

  @override
  String get visibilityReachability => 'Wer ein Gespräch mit mir beginnen darf';

  @override
  String get visibilitySaveFailed =>
      'Konnte nicht speichern, wer das sieht. Bitte versuchen Sie es erneut.';

  @override
  String get visibilitySignedIn => 'Alle Angemeldeten';

  @override
  String get visibilityTitle => 'Wer mich sieht';

  @override
  String get visibilityWidenAction => 'Erweitern';

  @override
  String visibilityWidenConfirm(String field, String audience) {
    return '$field zeigen für: $audience? Diese Personen können es sehen.';
  }

  @override
  String get visitCancel => 'Diesen Besuch absagen';

  @override
  String get visitCancelFailed =>
      'Der Besuch konnte nicht abgesagt werden. Nichts wurde geändert; versuchen Sie es erneut.';

  @override
  String get visitGuestNote => 'Gastbesuch — keine Mitgliedschaft';

  @override
  String get visitStatusCancelled => 'Abgesagt';

  @override
  String get visitStatusConfirmed => 'Bestätigt';

  @override
  String get visitStatusDeclined => 'Abgelehnt';

  @override
  String get visitStatusExpired => 'Abgelaufen';

  @override
  String get visitStatusRequested => 'Angefragt';

  @override
  String whatTheyCanDoTitle(String name) {
    return 'Was $name hier tun kann';
  }

  @override
  String get whatYouCanDoFromAdministrator => 'Aus der Rolle Administrator:in';

  @override
  String get whatYouCanDoFromCoOwner => 'Als Mitinhaber';

  @override
  String get whatYouCanDoFromEveryMember => 'Wie alle Mitglieder';

  @override
  String get whatYouCanDoFromOwner => 'Als Inhaber: alles';

  @override
  String whatYouCanDoFromRole(String role) {
    return 'Aus der Rolle $role';
  }

  @override
  String get whatYouCanDoIntro =>
      'Hier ist jede Person Mitglied; was Sie tun können — Nachrichten, Reservierungen und der Rest — kommt allein aus den Rollen, die Sie haben.';

  @override
  String get whatYouCanDoNothingMore => 'Nicht mehr als ein Mitglied.';

  @override
  String get whatYouCanDoTitle => 'Was Sie hier tun können';

  @override
  String get whatsappFieldLabel => 'WhatsApp-Nummer';

  @override
  String get whatsappHelper =>
      'Optional. Für Mitglieder Ihrer Workspaces sichtbar, damit sie Sie über WhatsApp erreichen. Leer lassen, um die Nummer nicht mehr zu teilen.';

  @override
  String get whatsappHint => '+49 151 23456789';

  @override
  String get whatsappNotShared => 'Nicht geteilt';

  @override
  String get whatsappSaveFailed =>
      'WhatsApp-Nummer konnte nicht gespeichert werden';

  @override
  String get whatsappSaved => 'WhatsApp-Nummer gespeichert';

  @override
  String get whatsappTitle => 'WhatsApp';

  @override
  String get wizardBack => 'Zurück';

  @override
  String get wizardCardHint =>
      'Ausstellen, versenden, mahnen, Zahlungen erfassen und bestätigen, zuordnen und abschließen — ein geführter Prozess.';

  @override
  String get wizardCloseHint =>
      'Ein Mitglied mit mehreren offenen Rechnungen kann EINE bezahlen; bei einer teilweise bezahlten kann der Rest abgeschrieben werden; eine Gutschrift wird erstattet. Jedes läuft über die Bestätigung.';

  @override
  String get wizardCloseNone =>
      'Nichts zusammenzufassen, abzuschreiben oder zu erstatten.';

  @override
  String get wizardFinish => 'Fertig';

  @override
  String wizardIssueAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Rechnungen ausstellen',
      one: '1 Rechnung ausstellen',
    );
    return '$_temp0';
  }

  @override
  String wizardIssueFailed(String name) {
    return 'Ausstellung für $name nicht möglich.';
  }

  @override
  String get wizardIssueHint =>
      'Ein abgewähltes Mitglied bleibt in diesem Stapel außen vor. Bereits abgedeckte Mitglieder erscheinen als erledigt.';

  @override
  String get wizardIssueNothing =>
      'Für diesen Zeitraum ist nichts auszustellen.';

  @override
  String wizardIssuedChip(String number) {
    return 'Ausgestellt $number';
  }

  @override
  String get wizardMatchAction => 'Zuordnen';

  @override
  String wizardMatchCredit(String amount) {
    return 'Verfügbares Guthaben: $amount';
  }

  @override
  String get wizardMatchHint =>
      'Eine Rechnung ist bezahlt, sobald eine echte Zahlung zugeordnet ist. Zeilen mit Guthaben auf dem Mitgliedskonto sind bereit.';

  @override
  String get wizardMatchNoCredit => 'Noch keine Zahlung auf dem Konto';

  @override
  String get wizardMatchNone => 'Jede Rechnung ist bezahlt oder abgeschlossen.';

  @override
  String get wizardMatchPending => 'Wartet auf Bestätigung';

  @override
  String get wizardNext => 'Weiter';

  @override
  String get wizardPaymentAccept => 'Bestätigen';

  @override
  String get wizardPaymentReject => 'Ablehnen';

  @override
  String get wizardPaymentsHint =>
      'Was Mitglieder gemeldet haben, wartet unten auf Ihre Bestätigung. Eine Zahlung, die ohne Meldung auf dem Konto eintraf, wird hier erfasst — das Mitglied bestätigt sie dann.';

  @override
  String get wizardPaymentsNone => 'Keine gemeldete Zahlung wartet auf Sie.';

  @override
  String wizardPeriodLabel(String period) {
    return 'Zeitraum: $period';
  }

  @override
  String get wizardRefund => 'Erstatten';

  @override
  String wizardRemindAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mahnungen senden',
      one: '1 Mahnung senden',
    );
    return '$_temp0';
  }

  @override
  String get wizardRemindHint =>
      'Überfällig nach Ihren Mahnregeln. Ein Tipp erfasst jede Mahnung und benachrichtigt die Mitglieder; der Brief öffnet sich je Zeile.';

  @override
  String wizardRemindLevel(int level) {
    return 'Mahnung $level';
  }

  @override
  String get wizardRemindNone => 'Nach Ihren Regeln ist keine Mahnung fällig.';

  @override
  String get wizardRemindOne => 'Mahnbrief';

  @override
  String get wizardReviewIssued => 'Bereits ausgestellt';

  @override
  String get wizardReviewOpen => 'Offene Rechnungen';

  @override
  String get wizardReviewOverdue => 'Fällige Mahnungen';

  @override
  String get wizardReviewPending => 'Zu bestätigende Zahlungen';

  @override
  String get wizardReviewToIssue => 'Auszustellen';

  @override
  String get wizardRunEnd => 'Monatsende';

  @override
  String get wizardRunEndHint =>
      'Was der abgelaufene Monat gekostet hat: Nutzung, Verbrauch und Zusatzkosten. Ausstellen, versenden, mahnen — dann Zahlungen erfassen, bestätigen und zuordnen, und abschließen.';

  @override
  String get wizardRunStart => 'Monatsanfang';

  @override
  String get wizardRunStartHint =>
      'Die im Voraus bezahlten Abonnements: für den kommenden Monat ausstellen, versenden, Mahnungen planen — dann die Zahlungsseite.';

  @override
  String get wizardSendDownload => 'PDF herunterladen';

  @override
  String get wizardSendHint =>
      'Jede Rechnung an ihr Mitglied übergeben — das PDF teilen oder herunterladen und auf eigenem Weg senden.';

  @override
  String get wizardSendNone => 'Noch keine Rechnung dieses Laufs zu versenden.';

  @override
  String get wizardSendShare => 'PDF teilen';

  @override
  String wizardSettle(int count) {
    return '$count zusammenfassen';
  }

  @override
  String get wizardStepClose => 'Abschließen';

  @override
  String get wizardStepCompleted => 'Abgeschlossen';

  @override
  String get wizardStepIssue => 'Ausstellen';

  @override
  String get wizardStepMatch => 'Zuordnen';

  @override
  String get wizardStepPayments => 'Zahlungen';

  @override
  String get wizardStepRemind => 'Mahnen';

  @override
  String get wizardStepReview => 'Prüfen';

  @override
  String get wizardStepSend => 'Versenden';

  @override
  String get wizardStepSkipped => 'Übersprungen — vorgeschlagene Einstellungen';

  @override
  String get wizardStepSummary => 'Zusammenfassung';

  @override
  String get wizardStepUnavailable => 'Noch nicht verfügbar';

  @override
  String get wizardSubmitting => 'Wird gesendet';

  @override
  String get wizardSummaryHint => 'Was dieser Lauf getan hat';

  @override
  String get wizardTallyDecided => 'Bestätigte oder abgelehnte Zahlungen';

  @override
  String get wizardTallyIssued => 'Ausgestellte Rechnungen';

  @override
  String get wizardTallyMatched => 'Zugeordnete Rechnungen';

  @override
  String get wizardTallyNothing => 'Nichts wurde geändert.';

  @override
  String get wizardTallyRefunds => 'Erstattungen';

  @override
  String get wizardTallyRegistered => 'Erfasste Zahlungen';

  @override
  String get wizardTallyReminded => 'Gesendete Mahnungen';

  @override
  String get wizardTallySettled => 'Zusammenfassungen';

  @override
  String get wizardTallyShared => 'Geteilte oder heruntergeladene PDFs';

  @override
  String get wizardTallyWriteoffs => 'Beantragte Abschreibungen';

  @override
  String get wizardTitle => 'Rechnungsassistent';

  @override
  String get wizardTodoHeading => 'Noch offen — wer ist am Zug';

  @override
  String get wizardTodoNone => 'Nichts mehr offen.';

  @override
  String get wizardWhoValidators => 'Prüfer';

  @override
  String get wizardWhoYou => 'Sie';

  @override
  String get wizardWriteoff => 'Abschreiben';

  @override
  String get wordingChangedOnly => 'Nur geänderte';

  @override
  String get wordingDefaultLabel => 'Produktbegriff';

  @override
  String get wordingIntro =>
      'Benennen Sie eine kleine, freigegebene Auswahl an Produktbegriffen um. Alles Übrige behält die Formulierung des Produkts, und ein nicht umbenannter Begriff erscheint genau wie zuvor.';

  @override
  String get wordingLocale => 'Sprache';

  @override
  String get wordingNone => 'Kein Begriff passt.';

  @override
  String get wordingReset => 'Zurücksetzen';

  @override
  String get wordingResetHint =>
      'Zurücksetzen entfernt Ihr Wort und stellt das des Produkts wieder her.';

  @override
  String get wordingRow => 'Wortwahl';

  @override
  String get wordingRowHint =>
      'Die Wörter, die dieser Bereich für einen Platz, die Legende und die Tabs verwendet.';

  @override
  String get wordingSavedOne => 'Gespeichert';

  @override
  String get wordingSearch => 'Wort suchen';

  @override
  String get wordingSurfaceBooking => 'Buchung';

  @override
  String get wordingSurfaceLegend => 'Legende';

  @override
  String get wordingSurfaceNavigation => 'Navigation';

  @override
  String get wordingSurfacePlan => 'Der Bereich';

  @override
  String get wordingTitle => 'Wortwahl';

  @override
  String get workbookExportBuilding => 'Arbeitsmappe wird erstellt…';

  @override
  String get workbookExportCancelled =>
      'Export abgebrochen. Nichts wurde gespeichert.';

  @override
  String workbookExportReading(String done, String total) {
    return 'Vorlagen werden gelesen: $done von $total';
  }

  @override
  String get workbookExportSaving => 'Wählen Sie den Speicherort…';

  @override
  String get workbookExportTitle => 'Arbeitsmappe wird exportiert';

  @override
  String get workbookNote =>
      'Eine Momentaufnahme von Vorlagendefinitionen. Änderungen an dieser Datei ändern nichts in DesKilo, und sie ist keine Sicherung eines Workspace: Sie enthält keine Mitglieder, Buchungen, Rechnungen oder Zugangsdaten.';

  @override
  String get workbookStateDefault =>
      'die Vorlage sagt nichts; der Standard gilt';

  @override
  String get workbookStateExcluded => 'bewusst nie veröffentlicht';

  @override
  String get workbookStateInherit =>
      'die Vorlage sagt nichts; das Ziel behält seinen eigenen';

  @override
  String get workbookStateLocal => 'lokal festzulegen';

  @override
  String get workbookStatePresent => 'die Vorlage legt diesen Wert fest';

  @override
  String get workbookStateUnknown => 'nicht lesbar; es wird nichts behauptet';

  @override
  String get workbookWide =>
      'Catalogs, RolePermissions, Validations und Fields zeigen einen Wert, wo die Vorlage ihn festlegt, sonst seinen Zustand';

  @override
  String get workspaceAddressLabel => 'Adresse des Workspace';

  @override
  String get workspaceCodeCopied => 'Kopiert';

  @override
  String get workspaceCodeCopy => 'ID kopieren';

  @override
  String get workspaceCodeEdit => 'Workspace-ID ändern';

  @override
  String get workspaceCodeExplainer =>
      'Coworker scannen diesen QR-Code — oder tippen die ID ein — um diesem Workspace beizutreten.';

  @override
  String get workspaceCodeHint => '4–20 Buchstaben oder Ziffern, eindeutig';

  @override
  String get workspaceCodeLabel => 'Workspace-ID';

  @override
  String get workspaceCodeRejected =>
      'ID abgelehnt — sie muss 4–20 Buchstaben oder Ziffern haben und darf nicht vergeben sein.';

  @override
  String get workspaceCodeSharePng => 'Als PNG teilen';

  @override
  String get workspaceCodeTitle => 'Workspace-ID & QR';

  @override
  String get workspaceConfigAvailability => 'Verfügbarkeit';

  @override
  String get workspaceConfigBookableWhole => 'als Ganzes buchbar';

  @override
  String get workspaceConfigClosures => 'Schließtage';

  @override
  String get workspaceConfigColName => 'Name';

  @override
  String get workspaceConfigColRole => 'Rolle';

  @override
  String get workspaceConfigColStatus => 'Status';

  @override
  String get workspaceConfigEmptyLevel => 'Keine Räume';

  @override
  String get workspaceConfigFeatures => 'Aktivierte Funktionen';

  @override
  String get workspaceConfigFloorPlan => 'Grundriss';

  @override
  String get workspaceConfigGranularity => 'Buchungsgranularität';

  @override
  String get workspaceConfigInvitationCustom =>
      'Eigene Einladungsnachricht konfiguriert';

  @override
  String get workspaceConfigInvitationDefault =>
      'Eingebaute Einladungsnachricht (alle Sprachen)';

  @override
  String get workspaceConfigInvitationSingleUse =>
      'Persönliche Einladungscodes sind einmalig nutzbar und verfallen nach 14 Tagen; neue Mitglieder brauchen die Freigabe eines Admins';

  @override
  String get workspaceConfigInvitations => 'Einladungen';

  @override
  String get workspaceConfigMembersSection => 'Mitglieder';

  @override
  String get workspaceConfigNone => 'Keine';

  @override
  String get workspaceConfigOpenDays => 'Öffnungstage';

  @override
  String get workspaceConfigOverview => 'Übersicht';

  @override
  String get workspaceConfigPdfExport => 'Konfiguration exportieren (PDF)';

  @override
  String get workspaceConfigPdfExportSubtitle =>
      'Vollständige Momentaufnahme: Einstellungen, alle Mitglieder und der Plan.';

  @override
  String workspaceConfigPdfGeneratedOn(String date) {
    return 'Erstellt am $date';
  }

  @override
  String get workspaceConfigPdfTitle => 'Workspace-Konfiguration';

  @override
  String get workspaceConfigSeats => 'Plätze';

  @override
  String get workspaceCountryLabel => 'Land';

  @override
  String get workspaceCurrencyLabel => 'Währung';

  @override
  String get workspaceDangerZone => 'Gefahrenzone';

  @override
  String workspaceDeskOpacityValue(int percent) {
    return 'Deckkraft: $percent %';
  }

  @override
  String get workspaceDeskTransparencyHelper =>
      'Verringere die Deckkraft der Tische, damit das Hintergrundfoto der Etage durchscheint.';

  @override
  String get workspaceDeskTransparencyTitle => 'Tisch-Transparenz';

  @override
  String get workspaceExcelExport => 'Daten exportieren (Excel)';

  @override
  String get workspaceExcelExportSubtitle =>
      'Ein ZIP: alle Daten in einer Arbeitsmappe (Buchungen, Zahlungen, Rechnungen, Mitglieder, Plan — je ein Tab), ein Manifest, das ihre Zeilen zählt, und die gespeicherten Dateien des Space.';

  @override
  String get workspaceFieldsOptional => 'optional';

  @override
  String get workspaceFieldsPersonalNote =>
      'Ihre Antworten sind personenbezogene Daten: Sie sind Teil Ihres Datenexports und werden gelöscht, wenn Sie diesen Bereich verlassen, außer der Bereich dokumentiert eine gesetzliche Aufbewahrungspflicht.';

  @override
  String get workspaceFieldsSaveFailed =>
      'Ihre Antworten auf die Fragen dieses Bereichs wurden nicht gespeichert. Ihre übrigen Angaben schon.';

  @override
  String workspaceFieldsTitle(String workspace) {
    return 'Fragen von $workspace';
  }

  @override
  String get workspaceGenericError =>
      'Etwas ist schiefgelaufen. Bitte erneut versuchen.';

  @override
  String get workspaceInviteCodeInvalid =>
      'Keine Workspace-ID gefunden — Einladung einfügen oder ID eintippen.';

  @override
  String get workspaceInviteCodeLabel => 'Einladungscode';

  @override
  String get workspaceInvitePasteHint =>
      'Fügen Sie die ganze Einladungsnachricht ein — die ID wird automatisch erkannt.';

  @override
  String get workspaceLanguageHelper =>
      'Einladungen werden standardmäßig in dieser Sprache verfasst. Ihre eigene App-Sprache stellen Sie in den Einstellungen ein.';

  @override
  String get workspaceLanguageLabel => 'Sprache des Arbeitsbereichs';

  @override
  String get workspaceLanguageUnset => 'App-Sprache des Absenders';

  @override
  String get workspaceNameLabel => 'Name des Workspace';

  @override
  String get workspacePaymentsBillingTitle => 'Zahlungen & Abrechnung';

  @override
  String get workspaceResetConfirmButton => 'Workspace zurücksetzen';

  @override
  String workspaceResetConfirmLabel(String phrase) {
    return 'Geben Sie „$phrase“ zum Bestätigen ein';
  }

  @override
  String get workspaceResetConfirmPhrase => 'Ich stimme zu';

  @override
  String get workspaceResetDialogTitle => 'Diesen Workspace zurücksetzen?';

  @override
  String get workspaceResetDone => 'Workspace zurückgesetzt.';

  @override
  String get workspaceResetSubtitle =>
      'Löscht alle Buchungen, Finanzen und den Grundriss. Einstellungen und Mitglieder bleiben.';

  @override
  String get workspaceResetTitle => 'Workspace zurücksetzen';

  @override
  String get workspaceResetWarning =>
      'Dies löscht dauerhaft alle Reservierungen, sämtliche Finanz- und Buchungsdaten, den Aktivitätsverlauf und den gesamten Grundriss — Etagen, Räume, Tische, Plätze und Bilder. Workspace-Einstellungen, Gebührenstufen, Verfügbarkeit, Funktionen, Kataloge und Mitglieder bleiben erhalten. Nicht rückgängig zu machen.';

  @override
  String get workspaceSettingsConflict =>
      'Jemand hat diese Einstellungen geändert, während Sie sie bearbeitet haben. Nichts wurde gespeichert; Ihre Änderungen sind noch da.';

  @override
  String get workspaceSettingsCurrencyHelper =>
      'Wird vom Land vorbelegt — überschreiben, falls Ihre Community in einer anderen Währung abrechnet.';

  @override
  String get workspaceSettingsSaved => 'Workspace gespeichert.';

  @override
  String get workspaceSettingsTitle => 'Workspace';

  @override
  String get workspaceTimezoneHint => 'Europe/Berlin';

  @override
  String get workspaceTimezoneLabel => 'Zeitzone';

  @override
  String get workspaceTimezoneUnknown =>
      'Wählen Sie eine Zeitzone aus der Liste';

  @override
  String get workspaceWhatsappGroupHelper =>
      'Wird Mitgliedern angezeigt, damit sie der WhatsApp-Gruppe der Community beitreten können. Einladungslink der Gruppe einfügen (https://chat.whatsapp.com/…). Leer lassen, um nichts anzuzeigen.';

  @override
  String get workspaceWhatsappGroupInvalid =>
      'Muss ein chat.whatsapp.com-Einladungslink sein';

  @override
  String get workspaceWhatsappGroupLabel => 'Link zur WhatsApp-Gruppe';

  @override
  String get workspaceWhatsappGroupTitle => 'WhatsApp-Gruppe';

  @override
  String get workspaceXmlErrorInvalidPlan =>
      'Der Raumplan in der Datei ist ungültig: Räume, Tische oder Plätze überlappen sich oder liegen außerhalb ihres Bereichs.';

  @override
  String get workspaceXmlErrorInvalidValue =>
      'Die Datei enthält einen ungültigen Wert und kann nicht importiert werden.';

  @override
  String get workspaceXmlErrorMalformed => 'Die Datei ist kein lesbares XML.';

  @override
  String get workspaceXmlErrorMissingAttribute =>
      'Die Datei ist unvollständig — ein erforderlicher Wert fehlt.';

  @override
  String get workspaceXmlErrorMissingElement =>
      'Die Datei ist unvollständig — ein erforderlicher Abschnitt fehlt.';

  @override
  String get workspaceXmlErrorUnsupportedVersion =>
      'Die Datei wurde von einer neueren DesKilo-Version exportiert und kann nicht importiert werden.';

  @override
  String get workspaceXmlErrorWrongRoot =>
      'Das ist keine DesKilo-Workspace-Datei.';

  @override
  String get workspaceXmlExport => 'Workspace exportieren (XML)';

  @override
  String get workspaceXmlExportSubtitle =>
      'Einstellungen und Raumplan als teilbare Datei. Ohne Mitglieder, Buchungen oder Finanzdaten.';

  @override
  String get workspaceXmlFileTypeLabel => 'XML';

  @override
  String get workspaceXmlImport => 'Workspace importieren (XML)';

  @override
  String workspaceXmlImportConfigurationOffBody(String feature) {
    return 'Die Datei enthält Tarife, die rechtliche Identität, Buchungs- und Bestätigungsregeln sowie Rollen. In diesem Raum ist „$feature“ deaktiviert, daher würde der Import sie nicht übernehmen. Aktivieren Sie die Funktion, um sie jetzt zu übernehmen.';
  }

  @override
  String workspaceXmlImportConfigurationOffNoRight(String feature) {
    return 'Die Datei enthält Tarife, die rechtliche Identität, Buchungs- und Bestätigungsregeln sowie Rollen. In diesem Raum ist „$feature“ deaktiviert, und nur wer seine Konfiguration ändern darf, kann die Funktion aktivieren. Der Import kann ohne sie fortfahren.';
  }

  @override
  String get workspaceXmlImportConfigurationOffTitle =>
      'Diese Datei enthält eine Konfiguration';

  @override
  String get workspaceXmlImportConfigurationOnly =>
      'Die Konfiguration wurde übernommen. Der Grundriss blieb erhalten: dieser Raum hat bereits Buchungen, sein Grundriss kann nicht ersetzt werden.';

  @override
  String get workspaceXmlImportConfigurationSkip =>
      'Ohne Konfiguration importieren';

  @override
  String get workspaceXmlImportConfigurationSwitchOn =>
      'Aktivieren und übernehmen';

  @override
  String get workspaceXmlImportConfirm => 'Ersetzen und importieren';

  @override
  String get workspaceXmlImportPartial =>
      'Ein Teil des Imports wurde übernommen, bevor er abbrach — prüfen Sie die Einstellungen und den Plan unten.';

  @override
  String workspaceXmlImportPreviewAccessories(int count) {
    return 'Zubehör: $count';
  }

  @override
  String workspaceXmlImportPreviewConfiguration(
    int settings,
    int tables,
    int rows,
  ) {
    return 'Konfiguration: $settings Einstellungen, $rows Zeilen in $tables Tabellen';
  }

  @override
  String get workspaceXmlImportPreviewConfigurationSkipped =>
      'Konfiguration: nicht übernommen.';

  @override
  String workspaceXmlImportPreviewCounts(
    int levels,
    int offices,
    int desks,
    int seats,
  ) {
    return 'Etagen: $levels · Räume: $offices · Tische: $desks · Plätze: $seats';
  }

  @override
  String get workspaceXmlImportPreviewTitle => 'Raumplan ersetzen?';

  @override
  String get workspaceXmlImportPreviewWarning =>
      'Der aktuelle Raumplan wird gelöscht und ersetzt, die Workspace-Einstellungen werden überschrieben. Das kann nicht rückgängig gemacht werden.';

  @override
  String get workspaceXmlImportReservationsError =>
      'Dieser Workspace hat bereits Reservierungen, daher kann sein Raumplan nicht ersetzt werden. Ein Import ist nur vor der ersten Buchung möglich.';

  @override
  String get workspaceXmlImportSubtitle =>
      'Einstellungen und Raumplan aus einer exportierten Datei wiederherstellen. Ersetzt den aktuellen Raumplan.';

  @override
  String get workspaceXmlImportSuccess => 'Workspace importiert.';
}
