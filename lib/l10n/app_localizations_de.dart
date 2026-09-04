// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get accessoriesTitle => 'Zubehör';

  @override
  String get accessoriesEmpty => 'Noch kein Zubehör.';

  @override
  String get accessoriesNew => 'Neues Zubehör';

  @override
  String get accessoriesEdit => 'Zubehör bearbeiten';

  @override
  String get accessoriesName => 'Name';

  @override
  String get accessoriesSupplement => 'Aufpreis pro halbem Tag';

  @override
  String accessoriesPerHalfDay(String amount) {
    return '$amount / halber Tag';
  }

  @override
  String get accessoriesNoSupplement => 'Kein Aufpreis';

  @override
  String get accessoriesInactive => 'Inaktiv';

  @override
  String get accessoriesActive => 'Aktiv';

  @override
  String get featureInvoiceAddressWindow => 'Adressfenster';

  @override
  String get featureInvoiceAddressWindowDesc =>
      'Platziert den Empfänger dort, wo ihn ein Fensterumschlag zeigt, damit eine gedruckte Rechnung gefaltet und versandt werden kann. Die Seite folgt dem Land und ist überschreibbar.';

  @override
  String get addressWindowTitle => 'Adressfenster';

  @override
  String get addressWindowSubtitle =>
      'Wo der Empfänger gedruckt wird, damit er im Fensterumschlag erscheint. Das Anschriftfeld misst 85 × 45 mm, 45 mm von der Blattoberkante.';

  @override
  String get addressWindowCountry => 'Dem Land folgen';

  @override
  String get addressWindowLeft => 'Links (DIN 5008)';

  @override
  String get addressWindowRight => 'Rechts (französisch)';

  @override
  String get addressWindowOff => 'Kein Fenster';

  @override
  String get authSignInTitle => 'Anmelden';

  @override
  String get authSignUpTitle => 'Konto erstellen';

  @override
  String get authEmailLabel => 'E-Mail';

  @override
  String get authPasswordLabel => 'Passwort';

  @override
  String get authShowPassword => 'Passwort anzeigen';

  @override
  String get authHidePassword => 'Passwort verbergen';

  @override
  String get authDisplayNameLabel => 'Anzeigename';

  @override
  String get authForgotPassword => 'Passwort vergessen?';

  @override
  String get authResetTitle => 'Passwort zurücksetzen';

  @override
  String get authResetExplainer =>
      'Wir senden dir einen Einmal-Code per E-Mail. Setze damit hier ein neues Passwort.';

  @override
  String get authResetSendCode => 'Code senden';

  @override
  String get authResetCodeSent => 'Code gesendet — prüfe deine E-Mails.';

  @override
  String get authResetCodeLabel => 'Code aus der E-Mail';

  @override
  String get authResetNewPasswordLabel => 'Neues Passwort';

  @override
  String get authResetSubmit => 'Neues Passwort setzen';

  @override
  String get authResetDone => 'Passwort aktualisiert — du bist angemeldet.';

  @override
  String get authResetInvalidCode =>
      'Dieser Code ist ungültig oder abgelaufen.';

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
  String get authNetworkError =>
      'Server nicht erreichbar. Prüfe deine Verbindung und versuche es erneut.';

  @override
  String get availabilityTitle => 'Verfügbarkeit';

  @override
  String get availabilityOpenWeekdays => 'Geöffnete Wochentage';

  @override
  String get availabilityClosureDays => 'Schließtage';

  @override
  String get availabilityAddClosure => 'Schließtag hinzufügen';

  @override
  String get availabilityClosureReason => 'Grund (optional)';

  @override
  String get availabilityLastOpenDay =>
      'Mindestens ein Wochentag muss geöffnet bleiben.';

  @override
  String get availabilityNoClosures => 'Keine Schließtage.';

  @override
  String get availabilityGranularityTitle => 'Buchungsraster';

  @override
  String get availabilityGranularityDescription =>
      'Halbe Tage: Buchungen umfassen den Vormittag, den Nachmittag oder den ganzen Arbeitstag — die Fenster folgen den konfigurierten Arbeitszeiten.';

  @override
  String get availabilityGranularityFlexible => 'Freier Zeitraum';

  @override
  String get availabilityGranularityHalfDay =>
      'Halbe Tage (Vormittag & Nachmittag)';

  @override
  String get availabilityGranularity5 => '5-Minuten-Slots';

  @override
  String get availabilityGranularity15 => '15-Minuten-Slots';

  @override
  String get availabilityGranularity30 => '30-Minuten-Slots';

  @override
  String get availabilityGranularity60 => '1-Stunden-Slots';

  @override
  String get availabilityGranularityFullDay => 'Nur ganze Tage';

  @override
  String planSlotError(int minutes) {
    return 'Buchungen müssen im $minutes-Minuten-Raster beginnen und enden.';
  }

  @override
  String get planFullDayError => 'Buchungen umfassen hier den ganzen Tag.';

  @override
  String get availabilityGranularityHours =>
      'Echte Uhrzeiten (exakt von–bis, Halb-/Ganztage als Schnellwahl)';

  @override
  String get availabilityWorkHoursTitle => 'Arbeitszeiten';

  @override
  String get availabilityWorkHoursDescription =>
      'Die Halbtags- und Ganztagsfenster überall — Reservierungen, Check-in und Abrechnung — folgen diesen Zeiten.';

  @override
  String get availabilityWorkStart => 'Tagesbeginn';

  @override
  String get availabilityHalfBoundary => 'Halbtagsgrenze';

  @override
  String get availabilityWorkEnd => 'Tagesende';

  @override
  String get availabilityHalfDayHours => 'Stunden, die als halber Tag gelten';

  @override
  String get availabilityFullDayHours => 'Stunden, die als ganzer Tag gelten';

  @override
  String availabilityHourOption(int count) {
    return '$count h';
  }

  @override
  String get availabilityWorkHoursInvalid =>
      'Es muss gelten: Beginn < Halbtagsgrenze < Ende.';

  @override
  String get availabilityPoliciesTitle => 'Buchungsregeln';

  @override
  String get policyAllowPastTitle => 'Vergangene Buchungen erlauben';

  @override
  String get policyAllowPastDesc =>
      'Mitglieder können eine bereits beendete Buchung nachtragen.';

  @override
  String get policyAdminCheckoutTitle => 'Admins dürfen Mitglieder auschecken';

  @override
  String get policyAdminCheckoutDesc =>
      'Ein Admin kann den laufenden Check-in eines Mitglieds beenden.';

  @override
  String get policyOutsideHoursTitle => 'Außerhalb der Öffnungszeiten';

  @override
  String get policyOutsideHoursDesc =>
      'Was außerhalb des Arbeitstags möglich ist — eine Antwort, für alle Granularitäten. Eine Buchung, die die Arbeitszeiten berührt, ist eine ganz normale Buchung.';

  @override
  String get policyOutsideHoursOff => 'Aus';

  @override
  String get policyOutsideHoursOffDesc =>
      'Nichts außerhalb der Zeiten: keine Vorausbuchung, kein spontaner Check-in — und eine Buchung über das Tagesende hinaus wird ebenfalls abgelehnt.';

  @override
  String get policyOutsideHoursWalkUp => 'Nur spontan';

  @override
  String get policyOutsideHoursWalkUpDesc =>
      'Spontane Check-ins bleiben möglich, Abend-Überstunden eingeschlossen; im Voraus außerhalb der Zeiten zu buchen wird abgelehnt.';

  @override
  String get policyOutsideHoursFree => 'Gratis';

  @override
  String get policyOutsideHoursFreeDesc =>
      'Erlaubt, nie gezählt und nie berechnet — reine Anwesenheitsinformation.';

  @override
  String get policyOutsideHoursCharged => 'Berechnet';

  @override
  String get policyOutsideHoursChargedDesc =>
      'Erlaubt und wie normale Nutzung gezählt — außer an einem Tag, an dem das Mitglied bereits eine reguläre Buchung hat.';

  @override
  String get policySimultaneousTitle =>
      'Gleichzeitige Reservierungen pro Mitglied';

  @override
  String get policySimultaneousDesc =>
      'Wie viele sich überschneidende Buchungen ein Mitglied halten darf. 1 bedeutet ein Platz zur selben Zeit.';

  @override
  String get policyLimitsTitle => 'Buchungsgrenzen';

  @override
  String get policyLimitsDesc =>
      'Wie weit im Voraus gebucht werden darf und welche Dauer akzeptiert wird. Beides gilt bei jeder Granularität.';

  @override
  String get policyHorizonTitle => 'Vorausbuchungs-Horizont';

  @override
  String get policyHorizonDesc =>
      'Wie viele Tage im Voraus eine Buchung beginnen darf. Darüber hinaus wird sie abgelehnt.';

  @override
  String get policyMinDurationTitle => 'Mindestdauer';

  @override
  String get policyMinDurationDesc =>
      'Die kürzeste akzeptierte Buchung. Deshalb wird eine Ankunft um 11:45 für die 12:00-Grenze als zu kurz abgelehnt.';

  @override
  String get policyMaxDurationTitle => 'Höchstdauer';

  @override
  String get policyMaxDurationDesc =>
      'Die längste akzeptierte Buchung. Eine Buchung endet an dem Tag, an dem sie beginnt — ein ganzer Tag ist also die Obergrenze.';

  @override
  String get policyDurationConflict =>
      'Das Minimum darf das Maximum nicht überschreiten — es käme keine Buchung mehr durch.';

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
  String get myBadgeTitle => 'Mein Badge';

  @override
  String get badgeSignInTitle => 'Mit Ausweis anmelden';

  @override
  String get badgeSignInTapPrompt => 'Halten Sie Ihren Ausweis an das Telefon.';

  @override
  String get badgeSignInNoReader =>
      'Auf diesem Gerät ist kein Ausweisleser verfügbar.';

  @override
  String get badgeSignInRetry => 'Erneut versuchen';

  @override
  String badgeSignInHello(String name) {
    return 'Hallo $name';
  }

  @override
  String get badgeSignInPinLabel => 'Ihre PIN';

  @override
  String get badgeSignInButton => 'Anmelden';

  @override
  String get badgeSignInUseEmail => 'Stattdessen meine E-Mail verwenden';

  @override
  String get badgeSignInRefused =>
      'Das hat nicht geklappt. Prüfen Sie Ausweis und PIN, oder melden Sie sich mit Ihrer E-Mail an.';

  @override
  String get badgeSignInLocked =>
      'Zu viele Versuche. Warten Sie einige Minuten, oder melden Sie sich mit Ihrer E-Mail an.';

  @override
  String get badgeSignInUnavailable =>
      'Die Ausweisanmeldung ist gerade nicht erreichbar. Melden Sie sich mit Ihrer E-Mail an.';

  @override
  String get badgeSignInEntry => 'Mit Ausweis anmelden';

  @override
  String get badgePinSectionTitle => 'Mein Ausweis';

  @override
  String get badgePinSet => 'PIN gesetzt';

  @override
  String get badgePinNotSet => 'Noch keine PIN';

  @override
  String get badgePinExplain =>
      'Mit Ihrer PIN melden Sie sich an, indem Sie Ihren Ausweis scannen, statt Ihre E-Mail zu tippen. Nur Sie können sie setzen, und niemand — auch kein Eigentümer — kann sie auslesen.';

  @override
  String get badgePinSetAction => 'PIN setzen';

  @override
  String get badgePinChangeAction => 'PIN ändern';

  @override
  String get badgePinClearAction => 'PIN entfernen';

  @override
  String get badgePinNewLabel => 'Neue PIN';

  @override
  String get badgePinConfirmLabel => 'Wiederholen';

  @override
  String get badgePinMismatch => 'Die beiden Eingaben stimmen nicht überein.';

  @override
  String badgePinTooShort(int min) {
    return 'Verwenden Sie mindestens $min Ziffern.';
  }

  @override
  String get badgePinSaved => 'PIN gespeichert.';

  @override
  String get badgePinCleared =>
      'PIN entfernt. Ihre Ausweise melden Sie nicht mehr an.';

  @override
  String get badgeAuthEnabledLabel => 'Meldet mich an';

  @override
  String get badgeAuthEnabledHint =>
      'Standardmäßig aus: Ein Ausweis, der Sie eincheckt, meldet Sie nicht an, bis Sie es erlauben.';

  @override
  String get badgeAuthNeedsPin =>
      'Setzen Sie zuerst eine Anmelde-PIN — ein Ausweis allein darf nie genügen.';

  @override
  String billSubscription(int pct) {
    return 'Abo $pct %';
  }

  @override
  String billEntitlement(int used, int included, int openDays) {
    return '$used von $included halben Tagen genutzt ($openDays Öffnungstage)';
  }

  @override
  String billOverage(int extra) {
    return '$extra zusätzliche halbe Tage';
  }

  @override
  String get billServices => 'Bezogene Leistungen';

  @override
  String get billServicesTotal => 'Summe Leistungen';

  @override
  String get billOpenPositions => 'Offene Posten';

  @override
  String get billPendingBadge => 'Bestätigung ausstehend';

  @override
  String get billPaymentsCredits => 'Zahlungen & Gutschriften';

  @override
  String get billBalance => 'Saldo';

  @override
  String get billSettled => 'Beglichen';

  @override
  String get billOutstanding => 'Offen';

  @override
  String get billAccessorySupplements => 'Zubehör-Aufpreise';

  @override
  String get entitlementTitle => 'Diesen Monat';

  @override
  String entitlementDaysUsed(String used, String total) {
    return '$used von $total Tagen genutzt';
  }

  @override
  String entitlementDaysLeft(String left) {
    return 'Noch $left Tage';
  }

  @override
  String get entitlementBlockedFull =>
      'Du hast diesen Monat alle Tage aufgebraucht. Bitte eine Administratorin um mehr oder beantrage unten zusätzliche Halbtage.';

  @override
  String entitlementPaygRate(String rate) {
    return 'Tage über deinen Tarif hinaus kosten je $rate.';
  }

  @override
  String get entitlementPackageFull =>
      'Du hast diesen Monat alle Tage aufgebraucht. Kaufe ein Paket, um weiter zu buchen.';

  @override
  String get billPackages => 'Tagespakete';

  @override
  String get payOnlineButton => 'Online bezahlen';

  @override
  String get payOnlineNotConfigured =>
      'Online-Zahlungen sind noch nicht eingerichtet. Frag die Workspace-Inhaberin.';

  @override
  String get payOnlineChooseTitle => 'Online bezahlen';

  @override
  String get paymentProviderStripe => 'Kreditkarte (Stripe)';

  @override
  String get paymentProviderMollie => 'Mollie — iDEAL, Bancontact…';

  @override
  String get payOnlineDiagTitle => 'Online-Zahlungen — nicht konfiguriert';

  @override
  String get payOnlineDiagHint =>
      'Auf dem Server fehlt diese Konfiguration (docs/design/payments-integration.md):';

  @override
  String billInvoiceCard(String number) {
    return 'Rechnung $number';
  }

  @override
  String billCreditNoteCard(String number) {
    return 'Gutschrift $number';
  }

  @override
  String get billInvoiceTotal => 'Rechnungsbetrag';

  @override
  String get billInvoicePaid => 'Bereits bezahlt';

  @override
  String get billInvoiceRemaining => 'Restbetrag';

  @override
  String get billCreditNoteDue =>
      'Der Space schuldet dir diesen Betrag — du musst nichts zahlen.';

  @override
  String get billCreditNoteRefunded =>
      'Der Space hat dir diesen Betrag erstattet.';

  @override
  String get accountCardTitle => 'Dein Konto';

  @override
  String get accountCredit => 'Guthaben auf dem Konto';

  @override
  String get accountRefundDue => 'Erstattung vom Space ausstehend';

  @override
  String get accountNet => 'Nettoposition';

  @override
  String accountOpenPartial(String period, String paid) {
    return '$period · $paid bezahlt';
  }

  @override
  String get accountImputationHint =>
      'Dein Guthaben kann offene Rechnungen begleichen — der Space rechnet es beim Zuordnen der Zahlungen an.';

  @override
  String get invoiceExportSafTPt => 'SAF-T (Portugal)';

  @override
  String get invoiceExportDatev => 'DATEV (Buchungsstapel)';

  @override
  String get invoiceExportSage => 'Sage 50 (Audit-Journal)';

  @override
  String get invoiceExportAccountantCsv => 'Buchhaltungs-CSV';

  @override
  String get invoiceExportAuditTrail => 'Prüfpfad';

  @override
  String get exportClaimRegulatory => 'Das Format, das Ihr Finanzamt verlangt.';

  @override
  String get exportClaimExchange =>
      'Für Ihre Steuerberatung zum Importieren und Prüfen — keine Meldung an eine Behörde.';

  @override
  String get exportClaimSubset =>
      'Nur Rechnungen und Zahlungen, kein Hauptbuch. Die Datei sagt das in ihrem Kopf.';

  @override
  String get exportUncertifiedSoftware =>
      'Nach der veröffentlichten Spezifikation erstellt, aber DesKilo ist in diesem Land keine zertifizierte Software — klären Sie mit Ihrer Steuerberatung, ob das für Sie Pflicht ist.';

  @override
  String get datevAccountsTitle => 'DATEV-Export';

  @override
  String get datevAccountsIntro =>
      'Berater- und Mandantennummer bekommen Sie von Ihrer Steuerberatung. DATEV lehnt eine Datei mit abweichenden Nummern ab — genau das hält sie aus den Büchern der falschen Firma heraus.';

  @override
  String get datevConsultantNumber => 'Beraternummer';

  @override
  String get datevClientNumber => 'Mandantennummer';

  @override
  String get sageAccountsTitle => 'Sage-Export';

  @override
  String get sageAccountsIntro =>
      'Die Vorgaben sind Sages eigene Sachkonten. Der Steuerschlüssel entscheidet, auf welcher Umsatzsteuervoranmeldung die Buchungen landen — prüfen Sie ihn, wenn Sie nicht dem Regelsatz unterliegen.';

  @override
  String get sageTaxCode => 'Steuerschlüssel (T1 / T0 / T9)';

  @override
  String get saftLedgerTitle => 'Buchungen aufnehmen?';

  @override
  String get saftLedgerIntro =>
      'Mit Kontonummern enthält die Datei doppelte Buchungen, die Ihre Steuerberatung importieren statt eintippen kann. Sie decken Ihre Umsätze und die zugehörigen Zahlungen ab — nicht Ihre gesamte Buchführung.';

  @override
  String get saftDocumentsOnly => 'Nur Belege';

  @override
  String get saftWithPostings => 'Mit Buchungen';

  @override
  String get billPdfTitle => 'Monatsrechnung';

  @override
  String get billPdfExport => 'Rechnung als PDF exportieren';

  @override
  String get reportCoaTitle => 'Kontenrahmen — Vorschau';

  @override
  String get reportCoaIntro =>
      'Ein Vorschlag, nicht deine Buchhaltung. Das sind die Konten, die eine Buchhalterin in deinem Land für einen Space wie deinen üblicherweise nimmt.';

  @override
  String get reportCoaAccounts => 'Vorgeschlagene Konten';

  @override
  String get reportCoaNumber => 'Konto';

  @override
  String get reportCoaLabel => 'Bezeichnung';

  @override
  String get reportCoaDisclaimer =>
      'Nur eine Vorschau. DesKilo führt kein Hauptbuch und macht deine Buchhaltung nicht — der Kontenrahmen deiner Steuerberatung gilt.';

  @override
  String get reportBadgesTitle => 'Mitglieder-Badges';

  @override
  String get reportBadgesIntro =>
      'An den Linien schneiden. Jede Karte trägt den Badge-Code eines Mitglieds — am Kiosk vorzeigen zum Einchecken.';

  @override
  String get reportBadgesFooter =>
      'Ein verlorenes Badge wird in Mitglieder & Tarife widerrufen, nicht bloß ersetzt.';

  @override
  String get reportSpaceCodesTitle => 'Raum-Codes';

  @override
  String get reportSpaceCodesIntro =>
      'Eine Karte je Platz, Tisch, Büro und Etage. Jede Karte auf ihren Raum kleben: Scannen öffnet dasselbe Blatt wie der Kiosk.';

  @override
  String get reportSpaceCodesFooter =>
      'Eine Karte, die nicht mehr zu ihrem Bereich passt, führt jeden in die Irre, der sie scannt — drucken Sie den Bogen nach dem Verschieben oder Umbenennen neu.';

  @override
  String get billingTitle => 'Abrechnung';

  @override
  String get billingFeeBands => 'Gebührenbänder';

  @override
  String billingBandFrom(int from) {
    return 'ab $from %';
  }

  @override
  String get billingBandTo => 'Bis %';

  @override
  String get billingBandFee => 'Monatsgebühr';

  @override
  String get billingBandOverage => 'Mehrverbrauch';

  @override
  String get billingAddBand => 'Band hinzufügen';

  @override
  String get billingRemoveBand => 'Band entfernen';

  @override
  String get billingBandsInvalid =>
      'Die Bänder müssen ansteigen und bei 100 % enden.';

  @override
  String get billingSaved => 'Gespeichert.';

  @override
  String get billingLevels => 'Abo-Stufen';

  @override
  String get billingAddLevel => 'Stufe hinzufügen';

  @override
  String get billingLevelValue => 'Stufe (1–100)';

  @override
  String get billingAllowCustom => 'Individuell verhandelten Wert erlauben';

  @override
  String get memberSubscriptionLabel => 'Abo';

  @override
  String get memberSubscriptionCustom => 'Individuell (1–100)';

  @override
  String moneySubscriptionPct(int pct) {
    return 'Abo $pct %';
  }

  @override
  String percentValue(int value) {
    return '$value %';
  }

  @override
  String get memberOveragePolicyLabel => 'Wenn die Tage aufgebraucht sind';

  @override
  String get memberOveragePolicyTooltip => 'Mehrverbrauch';

  @override
  String get overagePolicyBlocked => 'Weitere Buchung sperren';

  @override
  String get overagePolicyPayg => 'Mehrverbrauch berechnen (nach Verbrauch)';

  @override
  String get overagePolicyPackage => 'Paketkauf verlangen';

  @override
  String get billingPackages => 'Tagespakete';

  @override
  String get billingPackagesHint =>
      'Mitglieder im Paket-Tarif kaufen diese, wenn ihre Tage aufgebraucht sind.';

  @override
  String billingPackageSummary(int days, String price) {
    return '$days Tage · $price';
  }

  @override
  String get billingPackageName => 'Name';

  @override
  String get billingPackageDays => 'Tage';

  @override
  String get billingPackagePrice => 'Preis';

  @override
  String get billingAddPackage => 'Paket hinzufügen';

  @override
  String get buyPackageButton => 'Paket kaufen';

  @override
  String get buyPackageTitle => 'Paket kaufen';

  @override
  String buyPackageDays(int days) {
    return '$days Tage';
  }

  @override
  String get buyPackageNone => 'Noch keine Pakete verfügbar.';

  @override
  String get buyPackageDone => 'Tage hinzugefügt — viel Spaß.';

  @override
  String get payConfigTitle => 'Online-Zahlungen';

  @override
  String get payConfigOpen => 'Einrichten';

  @override
  String get payConfigIntro =>
      'Gib jeden Zahlungsanbieter ein, den du anbieten willst. Schlüssel werden sicher auf dem Server gespeichert und nie wieder angezeigt. Siehe docs/design/payments-integration.md.';

  @override
  String get payConfigConfigured => 'Eingerichtet';

  @override
  String get payConfigNotConfigured => 'Nicht eingerichtet';

  @override
  String get payConfigSecretSet => 'Gesetzt — leer lassen zum Behalten';

  @override
  String get payConfigSaved => 'Gespeichert.';

  @override
  String get payConfigRemove => 'Entfernen';

  @override
  String get payConfigRemoved => 'Entfernt.';

  @override
  String get payFieldClientId => 'Client-ID';

  @override
  String get payFieldSecret => 'Secret';

  @override
  String get payFieldEnv => 'Umgebung';

  @override
  String get payFieldWebhookId => 'Webhook-ID';

  @override
  String get payFieldReturnUrl => 'Rückkehr-URL';

  @override
  String get payFieldSecretKey => 'Secret Key';

  @override
  String get payFieldWebhookSecret => 'Webhook-Signaturgeheimnis';

  @override
  String get payFieldApiKey => 'API-Schlüssel';

  @override
  String get paymentProviderWero => 'Wero (über Mollie)';

  @override
  String get billingRulesTitle => 'Rechnungsplan';

  @override
  String get billingRulesSubtitle =>
      'Wann Abo- und Monatsabschluss-Rechnungen rausgehen';

  @override
  String get billingRulesSaved => 'Rechnungsplan gespeichert.';

  @override
  String get billingSubscriptionSection => 'Abo, im Voraus';

  @override
  String get billingSubscriptionAuto => 'Automatisch erstellen';

  @override
  String get billingSubscriptionOff =>
      'Schalte „Abo-Rechnungen“ unter Funktionen ein, um das zu nutzen.';

  @override
  String get billingAdvanceDays => 'Tage vor Monatsbeginn';

  @override
  String billingSubscriptionWhen(String day, String month) {
    return 'Erstellt am $day für $month';
  }

  @override
  String get billingUsageSection => 'Der gerade beendete Monat';

  @override
  String get billingUsageAuto => 'Automatisch erstellen';

  @override
  String get billingUsageOff =>
      'Schalte „Monatsabschluss-Rechnungen“ unter Funktionen ein, um das zu nutzen.';

  @override
  String get billingUsageWhenZero => 'Auch wenn nichts zu zahlen ist';

  @override
  String get billingUsageWhenZeroHint =>
      'Sendet ein Dokument über null — als Bestätigung, dass das Abo den ganzen Monat abgedeckt hat.';

  @override
  String get invoiceKindSubscription => 'Abo, im Voraus';

  @override
  String get invoiceKindUsage => 'Zusätze des Monats';

  @override
  String get invoiceKindSettlement => 'Zusammengefasste Rechnungen';

  @override
  String get invoiceKindFull => 'Ganzer Monat';

  @override
  String get settlementRegroups => 'Diese Rechnung fasst zusammen';

  @override
  String get settlementVatNote =>
      'Die Positionen und ihre MwSt. sind aus den zusammengefassten Rechnungen übernommen; die Umsatzsteuererklärung zählt die Originale einmal.';

  @override
  String get settlementSettledBy =>
      'In eine andere Rechnung zusammengefasst — diese ist das, was geschuldet und angemahnt wird.';

  @override
  String get settlementAction => 'Zu einer Rechnung zusammenfassen';

  @override
  String settlementConfirm(int count, String amount) {
    return '$count Rechnungen zu einer über $amount zusammenfassen?';
  }

  @override
  String settlementDone(String number) {
    return 'Zusammengefasst in $number.';
  }

  @override
  String get settlementNeedsTwo =>
      'Wähle mindestens zwei offene Rechnungen desselben Mitglieds.';

  @override
  String settlementFoldedIn(String number) {
    return 'Zusammengefasst in $number';
  }

  @override
  String get settlementDocumentationOnly =>
      'Nur Dokumentation — jede Aktion erfolgt auf der Sammelrechnung.';

  @override
  String get settlementSourcePdf => 'PDF (zusammengefasst)';

  @override
  String settlementRegroupsNumbers(String numbers) {
    return 'Fasst $numbers zusammen';
  }

  @override
  String invoicePdfSettledIn(String number) {
    return 'Zusammengefasst in $number';
  }

  @override
  String settlementPaidThrough(String number) {
    return 'Bezahlt über $number';
  }

  @override
  String get settlementAnnexTitle =>
      'Die zusammengefassten Rechnungen anhängen?';

  @override
  String get settlementAnnexAlone => 'Nur diese Rechnung';

  @override
  String get settlementAnnexWith => 'Anhängen';

  @override
  String settlementAnnexBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Die $count Rechnungen, die diese ersetzt, können ihr folgen, jede auf eigenen Seiten und als zusammengefasst gestempelt.',
      one:
          'Die Rechnung, die diese ersetzt, kann ihr folgen, auf eigenen Seiten und als zusammengefasst gestempelt.',
    );
    return '$_temp0';
  }

  @override
  String get reservationExtendButton => 'Länger bleiben';

  @override
  String get reservationExtendLaterOnly =>
      'Wähle eine Zeit nach dem aktuellen Ende.';

  @override
  String get reservationEndEarlyButton => 'Früher beenden';

  @override
  String get reservationEndEarlyAheadOnly =>
      'Wähle eine Zeit, die noch bevorsteht und vor dem aktuellen Ende liegt.';

  @override
  String get calendarMineTab => 'Meine';

  @override
  String get calendarEveryoneTab => 'Alle';

  @override
  String get calendarNoReservations => 'Keine Reservierungen an diesem Tag.';

  @override
  String get calendarCancelOccurrence => 'Diesen Termin stornieren';

  @override
  String get calendarCancelFollowing => 'Diesen und folgende stornieren';

  @override
  String get calendarPreviousMonth => 'Vorheriger Monat';

  @override
  String get calendarNextMonth => 'Nächster Monat';

  @override
  String get calendarReservationActions => 'Aktionen zur Reservierung';

  @override
  String get calendarShowOnPlan => 'Auf dem Plan anzeigen';

  @override
  String get calendarListView => 'Listenansicht';

  @override
  String get calendarTimelineView => 'Zeitleistenansicht';

  @override
  String get calendarTimelineEmpty =>
      'Keine Reservierungen auf dieser Etage an diesem Tag.';

  @override
  String get calendarAllLevels => 'Alle Etagen';

  @override
  String get calendarTimelineAllEmpty =>
      'Auf keiner Etage gibt es an diesem Tag Reservierungen.';

  @override
  String calendarLevelCollapsed(String level) {
    return '$level, eingeklappt';
  }

  @override
  String calendarLevelExpanded(String level) {
    return '$level, ausgeklappt';
  }

  @override
  String get calendarWhoCanSee => 'Wer sieht das';

  @override
  String get calendarPrevious => 'Zurück';

  @override
  String get calendarNext => 'Weiter';

  @override
  String get calendarDay => 'Tag';

  @override
  String get calendarRange => 'Zeitraum';

  @override
  String get calendarMemberMe => 'Ich';

  @override
  String get calendarNothingHere => 'Nichts an diesen Tagen.';

  @override
  String calendarLockedKinds(String kinds) {
    return 'Für dieses Mitglied nicht sichtbar: $kinds';
  }

  @override
  String calendarEventTitle(String label) {
    return 'Meldung: $label';
  }

  @override
  String get calendarKindReservation => 'Buchungen';

  @override
  String get calendarKindCheckIn => 'Check-ins';

  @override
  String get calendarKindCheckOut => 'Check-outs';

  @override
  String get calendarKindEvent => 'Meldungen';

  @override
  String get calendarKindMessage => 'Nachrichten';

  @override
  String get calendarKindInvoice => 'Rechnungen';

  @override
  String get calendarKindPayment => 'Zahlungen';

  @override
  String get calendarKindConsumption => 'Verbrauch';

  @override
  String get calendarKindReminder => 'Erinnerungen';

  @override
  String get accessNobodyElse => 'niemand sonst';

  @override
  String get accessRuleReservations =>
      'Jedes Mitglied des Bereichs — der Plan zeigt allen die Belegung.';

  @override
  String get accessRuleEvents => 'Du, das handelnde Mitglied und die Admins.';

  @override
  String get accessRuleMessages =>
      'Nur die Personen in der Unterhaltung — keine Rolle liest eine Unterhaltung, an der sie nicht teilnimmt.';

  @override
  String accessRuleFinances(String people) {
    return 'Du und die mit der Finanz-Berechtigung: $people.';
  }

  @override
  String get accessRuleReminders => 'Nur du.';

  @override
  String get accessLogTitle => 'Wer auf deine Daten zugegriffen hat';

  @override
  String get accessLogEmpty =>
      'Niemand hat deine Finanzen oder Nachrichten eingesehen.';

  @override
  String accessLogRow(String actor, String category, String subject) {
    return '$actor hat $category von $subject eingesehen';
  }

  @override
  String get calendarEventActionCreated => 'angelegt';

  @override
  String get calendarEventActionModified => 'geändert';

  @override
  String get calendarEventActionCancelled => 'storniert';

  @override
  String get calendarEventActionSubmitted => 'eingereicht';

  @override
  String get calendarEventActionApproved => 'genehmigt';

  @override
  String get calendarEventActionRejected => 'abgelehnt';

  @override
  String get calendarEventStatusPending => 'wartet auf Bestätigung';

  @override
  String get calendarEventStatusRejected => 'abgelehnt';

  @override
  String get calendarEventStatusExpired => 'abgelaufen';

  @override
  String get accessKindNegotiations => 'Preisverhandlungen';

  @override
  String accessRuleNegotiations(String people) {
    return 'Sie, die Inhaber und die Finanz-Admins: $people. Jeder Zugriff durch jemand anderen steht unten im Protokoll.';
  }

  @override
  String get calendarViewAgenda => 'Agenda';

  @override
  String get calendarViewWeek => 'Woche';

  @override
  String get calendarViewMonth => 'Monat';

  @override
  String get calendarToday => 'Heute';

  @override
  String get calendarTomorrow => 'Morgen';

  @override
  String get calendarYesterday => 'Gestern';

  @override
  String get calendarKindDue => 'Fällige Zahlungen';

  @override
  String get calendarKindScheduled => 'Geplante Ausgaben';

  @override
  String calendarDueTitle(String number) {
    return 'Zahlung fällig · $number';
  }

  @override
  String calendarScheduledTitle(String name) {
    return 'Geplante Ausgabe · $name';
  }

  @override
  String get calendarClosedDay => 'Geschlossen';

  @override
  String calendarClosedDayReason(String reason) {
    return 'Geschlossen — $reason';
  }

  @override
  String get calendarGroupBookings => 'Buchungen & Anwesenheit';

  @override
  String get calendarGroupActivity => 'Hinweise & Nachrichten';

  @override
  String get calendarGroupMoney => 'Finanzen';

  @override
  String calendarAgendaEmpty(int days) {
    return 'Nichts geplant in den nächsten $days Tagen.';
  }

  @override
  String calendarAgendaRange(int days) {
    return 'Nächste $days Tage';
  }

  @override
  String get calendarWeekEmpty => 'Nichts in dieser Woche.';

  @override
  String get calendarDayEmpty => 'Nichts an diesem Tag.';

  @override
  String calendarItemCount(int count) {
    return '$count Einträge';
  }

  @override
  String get calendarKindValidation => 'Freigaben';

  @override
  String calendarValidationValidated(String what) {
    return 'Freigegeben: $what';
  }

  @override
  String calendarValidationRefused(String what) {
    return 'Abgelehnt: $what';
  }

  @override
  String get calendarEventActionValidated => 'freigegeben';

  @override
  String get calendarEventActionRefused => 'abgelehnt';

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
  String get settingsSectionAdministration => 'Verwaltung';

  @override
  String get settingsSectionPreferences => 'Präferenzen';

  @override
  String get settingsSectionAdvanced => 'Erweitert';

  @override
  String get comingSoon => 'Demnächst verfügbar';

  @override
  String get shellReserveButton => 'Reservieren';

  @override
  String commonSavedTo(String path) {
    return 'Gespeichert unter $path';
  }

  @override
  String get commonSaveFailed => 'Datei konnte nicht gespeichert werden.';

  @override
  String get commonRetry => 'Erneut versuchen';

  @override
  String get settingsSectionAbout => 'Über';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutOpenSource => 'Open Source (0BSD-Lizenz)';

  @override
  String get aboutOpenSourceDesc => 'Quellcode auf GitHub';

  @override
  String get aboutPrivacy => 'Datenschutzerklärung';

  @override
  String get aboutReportBug => 'Fehler melden / Funktion vorschlagen';

  @override
  String get aboutSupportTitle => 'Dieses Projekt unterstützen';

  @override
  String get aboutSupportBody =>
      'Diese App ist kostenlos, Open Source und werbefrei. Wenn sie dir nützt, unterstütze den Entwickler.';

  @override
  String get consumptionAdd => 'Verbrauch erfassen';

  @override
  String consumptionAddForMember(String name) {
    return 'Leistung für $name erfassen';
  }

  @override
  String get consumptionService => 'Leistung';

  @override
  String get consumptionQuantity => 'Menge';

  @override
  String get consumptionPeriodLabel => 'Abrechnungszeitraum (JJJJ-MM)';

  @override
  String get consumptionNoServices => 'Keine aktiven Leistungen vorhanden.';

  @override
  String get consumptionRecorded =>
      'Verbrauch erfasst — wartet auf Bestätigung.';

  @override
  String get eventTypeServiceCharge => 'Leistung';

  @override
  String eventServiceChargeTitle(String name, int quantity, String amount) {
    return '$name ×$quantity — $amount';
  }

  @override
  String get coOwnerAction => 'Mit-Inhaberschaft';

  @override
  String get coOwnerNone => 'Keine Mit-Inhaber-Rolle';

  @override
  String get coOwnerActive =>
      'Aktive Mit-Inhaberin — Inhaber-Rechte sofort, automatische Nachfolge';

  @override
  String get coOwnerPassive =>
      'Passive Mit-Inhaberin — wird Inhaberin bei Aktivierung oder wenn der Inhaber geht';

  @override
  String get coOwnerActivate => 'Jetzt zur Inhaberin machen';

  @override
  String get memberCoOwnerChip => 'Mit-Inhaberin';

  @override
  String get memberCoOwnerPassiveChip => 'Mit-Inhaberin (passiv)';

  @override
  String get developerMode => 'Entwicklermodus';

  @override
  String get developerModeWorkspaceHint =>
      'Gilt für alle Mitglieder dieses Workspace.';

  @override
  String get developerTitle => 'Entwickler';

  @override
  String get developerExport => 'Protokoll exportieren';

  @override
  String get developerClear => 'Protokoll leeren';

  @override
  String get developerEmpty => 'Noch keine Protokolleinträge.';

  @override
  String get developerFilterAll => 'Alle';

  @override
  String get developerFilterErrors => 'Fehler';

  @override
  String get developerFilterWarnings => 'Warnungen+';

  @override
  String get pushStatusRegistered => 'Push-Benachrichtigungen sind aktiv';

  @override
  String get pushStatusNotConfigured =>
      'Push-Benachrichtigungen sind noch nicht eingerichtet';

  @override
  String get pushStatusNotConfiguredHint =>
      'Die Inhaberin schließt die Firebase-Einrichtung ab (push-setup-Anleitung).';

  @override
  String get notificationsSystemOff =>
      'Android blockiert DesKilo-Benachrichtigungen';

  @override
  String get notificationsSystemOffHint =>
      'Erlaube sie unter System-Einstellungen → Apps → DesKilo → Benachrichtigungen — das Icon-Badge braucht sie.';

  @override
  String get developerExportReservations => 'Reservierungen exportieren';

  @override
  String get developerExportReservationsHint =>
      'Alle Buchungen und Check-ins — vergangene, laufende und künftige, in jedem Zustand — als CSV, für Analyse und Fehlersuche.';

  @override
  String get pushStatusNoTransport =>
      'Diese Version hat keine Push-Benachrichtigungen';

  @override
  String get pushStatusNoTransportHint =>
      'Benachrichtigungen kommen in der App und als lokale Benachrichtigungen auf diesem Gerät an.';

  @override
  String get directoryTitle => 'Mitglieder';

  @override
  String get directoryEmpty => 'Noch keine Mitglieder.';

  @override
  String get directoryCheckedIn => 'Eingecheckt';

  @override
  String directoryCheckedInSeat(String seat) {
    return 'Eingecheckt · $seat';
  }

  @override
  String get directoryOnline => 'Online';

  @override
  String get directoryReservedToday => 'Heute reserviert';

  @override
  String directoryLastSeenMinutes(int minutes) {
    return 'Vor $minutes Min. gesehen';
  }

  @override
  String directoryLastSeenHours(int hours) {
    return 'Vor $hours Std. gesehen';
  }

  @override
  String directoryLastSeenDays(int days) {
    return 'Vor $days Tagen gesehen';
  }

  @override
  String get directoryWhatsapp => 'Auf WhatsApp schreiben';

  @override
  String get directoryOpenGroup => 'WhatsApp-Gruppe öffnen';

  @override
  String get directoryClose => 'Schließen';

  @override
  String get directoryReservedNow => 'Jetzt reserviert';

  @override
  String directoryReservedNowSeat(String seat) {
    return 'Jetzt reserviert · $seat';
  }

  @override
  String get directoryReservationsHeading => 'Reservierungen';

  @override
  String get directoryNoUpcoming => 'Keine anstehenden Reservierungen';

  @override
  String get memberPageEmailAction => 'E-Mail';

  @override
  String get memberPageAddService => 'Leistung hinzufügen';

  @override
  String get memberPageNone => 'Keine';

  @override
  String memberPageWorkspaceDefaultValue(int count) {
    return 'Workspace-Standard ($count)';
  }

  @override
  String get memberPageLevelTitle => 'Buchungen ganzer Ebenen';

  @override
  String get memberPageGroupMembership => 'Mitgliedschaft';

  @override
  String get memberPageGroupBooking => 'Buchungsregeln';

  @override
  String get memberPageGroupBilling => 'Abrechnung';

  @override
  String get memberPageGroupAccess => 'Ausweise & Zugang';

  @override
  String get memberPageManageHeading => 'Verwalten';

  @override
  String get memberPageStatusActive => 'Aktiv';

  @override
  String get memberPageNeverSeen => 'Noch nie gesehen';

  @override
  String memberPageYou(String name) {
    return '$name (Sie)';
  }

  @override
  String memberPageSince(String date) {
    return 'Mitglied seit $date';
  }

  @override
  String memberPageCheckedIn(String seat, String time) {
    return 'Eingecheckt · $seat · seit $time';
  }

  @override
  String memberPageReservedNow(String seat, String time) {
    return 'Jetzt reserviert · $seat · bis $time';
  }

  @override
  String memberPageNext(String label) {
    return 'Nächste: $label';
  }

  @override
  String get memberPageNowHeading => 'Gerade jetzt';

  @override
  String get editorBackgroundImage => 'Hintergrundbild';

  @override
  String get editorBackgroundSet => 'Hintergrundbild festlegen';

  @override
  String get editorBackgroundReplace => 'Hintergrundbild ersetzen';

  @override
  String get editorBackgroundRemove => 'Hintergrundbild entfernen';

  @override
  String get editorTitle => 'Workspace-Editor';

  @override
  String get editorOpenTooltip => 'Workspace bearbeiten';

  @override
  String get editorAddLevel => 'Etage hinzufügen';

  @override
  String get editorNoLevels =>
      'Noch keine Etagen. Füge die erste Etage deines Workspace hinzu.';

  @override
  String get editorLevelNameLabel => 'Name der Etage';

  @override
  String get editorRenameLevel => 'Umbenennen';

  @override
  String get editorLevelActions => 'Etagen-Aktionen';

  @override
  String get editorDeleteLevelConfirm =>
      'Diese Etage löschen? Alle Büros, Tische und Plätze darauf werden entfernt.';

  @override
  String get editorToolSelect => 'Auswahl';

  @override
  String get editorToolOffice => 'Büro';

  @override
  String get editorToolDesk => 'Tisch';

  @override
  String get editorToolImage => 'Bild';

  @override
  String get editorToolErase => 'Löschen';

  @override
  String get editorNewOffice => 'Neues Büro';

  @override
  String get editorOfficeNameLabel => 'Name des Büros';

  @override
  String get editorOfficeNameDefault => 'Büro';

  @override
  String get editorDeskNameDefault => 'Tisch';

  @override
  String get editorDeskNameLabel => 'Name des Tisches';

  @override
  String get editorPlacementOverlap => 'Überschneidet ein vorhandenes Element.';

  @override
  String get editorPlacementOutside =>
      'Muss vollständig innerhalb eines Büros liegen.';

  @override
  String get editorOfficeProperties => 'Büro';

  @override
  String get editorDeskProperties => 'Tisch';

  @override
  String get editorBookableAsWhole => 'Als Ganzes buchbar';

  @override
  String get editorDeleteElementConfirm =>
      'Dieses Element löschen? Alles darauf wird ebenfalls entfernt.';

  @override
  String get editorToolSeat => 'Platz';

  @override
  String get editorSeatProperties => 'Platz';

  @override
  String get editorSeatNameLabel => 'Name des Platzes';

  @override
  String get editorSeatNameDefault => 'Platz';

  @override
  String get editorOrientationLabel => 'Sitzrichtung';

  @override
  String get editorChairLabel => 'Stuhltyp';

  @override
  String get editorAmenitiesLabel => 'Ausstattung';

  @override
  String get editorBlockedLabel => 'Gesperrt (Wartung)';

  @override
  String get editorSeatNoDesk =>
      'Plätze können nur auf einem Tisch platziert werden.';

  @override
  String get amenityMonitor => 'Monitor';

  @override
  String get amenityStandingDesk => 'Stehpult';

  @override
  String get amenityWindow => 'Fensterplatz';

  @override
  String get amenityDock => 'Dockingstation';

  @override
  String get amenityErgonomicChair => 'Ergonomischer Stuhl';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get editorAccessoriesLabel => 'Zubehör';

  @override
  String get editorNoAccessories =>
      'Noch kein Zubehör — lege es unter Einstellungen → Zubehör an.';

  @override
  String get editorSeatNfcLabel => 'NFC/RFID-Tag';

  @override
  String get editorSeatNfcHelp =>
      'Tag-UID in Hex — leer lassen für keinen Tag.';

  @override
  String get editorSeatNfcRead => 'Jetzt einen Tag lesen';

  @override
  String get editorSeatNfcReadFailed =>
      'Der Tag-Leser konnte nicht gestartet werden.';

  @override
  String get editorSeatNfcDuplicate =>
      'Dieser Tag ist bereits mit einem anderen Stuhl verknüpft.';

  @override
  String get editorDeleteElementConfirmAudit =>
      'Dieses Element löschen? Alles darauf Platzierte wird ebenfalls entfernt. Buchungen, die darauf verweisen, behalten einen Text-Schnappschuss für Audits; offene Buchungen werden storniert.';

  @override
  String get editorDeleteLevelConfirmAudit =>
      'Diese Ebene löschen? Alle Büros, Tische und Sitzplätze darauf werden entfernt. Buchungen, die darauf verweisen, behalten einen Text-Schnappschuss für Audits; offene Buchungen werden storniert.';

  @override
  String get eventsPendingHeader => 'Wartet auf deine Bestätigung';

  @override
  String get eventAccept => 'Annehmen';

  @override
  String get eventReject => 'Ablehnen';

  @override
  String get eventsEmpty => 'Noch keine Ereignisse.';

  @override
  String get eventsFilterAll => 'Alle';

  @override
  String get eventTypeReservation => 'Reservierung';

  @override
  String get eventTypePayment => 'Zahlung';

  @override
  String get eventTypeExpense => 'Ausgabe';

  @override
  String get eventTypeAdjustment => 'Korrektur';

  @override
  String eventReservationCreated(String actor, String target) {
    return '$actor hat $target reserviert';
  }

  @override
  String eventReservationModified(String actor, String target) {
    return '$actor hat die Reservierung von $target geändert';
  }

  @override
  String eventReservationCancelled(String actor, String target) {
    return '$actor hat die Reservierung von $target storniert';
  }

  @override
  String eventPaymentSubmitted(String actor, String amount) {
    return '$actor hat eine Zahlung von $amount erfasst';
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
  String get pushPendingTitle => 'DesKilo';

  @override
  String get pushPendingBody => 'Jemand wartet auf deine Bestätigung.';

  @override
  String get pushCancelledTitle => 'Reservierung entfernt';

  @override
  String get pushCancelledBody =>
      'Eine Reservierung wurde von einem Admin entfernt.';

  @override
  String get eventTypeReservationDelete => 'Buchungslöschung';

  @override
  String eventReservationDeleteLine(String actor, String date, String state) {
    return '$actor bittet um Löschung der Buchung vom $date ($state)';
  }

  @override
  String get eventReservationDeleteCheckedIn => 'eingecheckt';

  @override
  String get eventReservationDeleteUnused => 'nie genutzt';

  @override
  String get eventAutoValidated => 'Automatisch bestätigt';

  @override
  String get reservationDeleteRequestButton => 'Löschung beantragen';

  @override
  String get reservationDeleteRequestExplain =>
      'Vergangene oder eingecheckte Buchungen werden nicht direkt gelöscht. Inhaber oder Admin entscheiden: wurde der Check-in nur vergessen (die Buchung bleibt), oder wurde sie nie genutzt (sie wird entfernt)?';

  @override
  String get reservationDeleteReasonLabel => 'Grund (optional)';

  @override
  String get reservationDeleteSubmit => 'Anfrage senden';

  @override
  String get reservationDeleteSubmitted =>
      'Löschung beantragt — Inhaber oder Admin entscheiden.';

  @override
  String get notifCategoryCheckIns => 'Check-ins';

  @override
  String get notifCategoryMoney => 'Finanzen';

  @override
  String get notifCategoryMembers => 'Mitglieder';

  @override
  String get notesFilterRead => 'Gelesen';

  @override
  String get notifSortByDate => 'Nach Datum sortieren';

  @override
  String get notifGroupBy => 'Gruppieren nach';

  @override
  String get notifGroupByType => 'Typ';

  @override
  String get notifGroupByDate => 'Datum';

  @override
  String get notifGroupByUser => 'Mitglied';

  @override
  String get notifUngroup => 'Gruppierung aufheben';

  @override
  String get validationScopeLabel => 'Wer prüft';

  @override
  String get validationScopeAdmins => 'Admins';

  @override
  String get validationScopeListed => 'Benannte Personen';

  @override
  String get validationScopeMembers => 'Alle Mitglieder';

  @override
  String get validationScopeHint =>
      'Der Inhaber darf immer. Admins: alle Admins oder die aufgeführten. Benannte: genau diese Personen, gleich welcher Rolle. Alle Mitglieder: jede aktive Person.';

  @override
  String get validationPickPersons => 'Personen wählen';

  @override
  String get eventTypeExpenseSchedule => 'Geplante Ausgabe';

  @override
  String eventExpenseScheduleLine(Object actor, Object amount, Object title) {
    return '$actor plant „$title“ — $amount wiederkehrend';
  }

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
  String get eventTypeExpenseRepartition => 'Gemeinsame Ausgabe';

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
  String get featuresTitle => 'Funktionen';

  @override
  String get featureCalendarTab => 'Kalender-Tab';

  @override
  String get featureCalendarTabDesc =>
      'Monatsübersicht über Buchungen und Schließtage.';

  @override
  String get featureEventsTab => 'Ereignis-Tab';

  @override
  String get featureEventsTabDesc =>
      'Aktivitätsverlauf und ausstehende Bestätigungen.';

  @override
  String get featureMoneyTab => 'Finanzen-Tab';

  @override
  String get featureMoneyTabDesc => 'Monatsrechnungen, Zahlungen und Ausgaben.';

  @override
  String get featureServices => 'Leistungen';

  @override
  String get featureServicesDesc => 'Leistungskatalog und Verbrauchserfassung.';

  @override
  String get featurePdfExport => 'PDF-Export';

  @override
  String get featurePdfExportDesc => 'Die Monatsrechnung als PDF exportieren.';

  @override
  String get featureSeriesBooking => 'Serienbuchung';

  @override
  String get featureSeriesBookingDesc =>
      'Eine Reservierung täglich, wöchentlich oder an Werktagen wiederholen.';

  @override
  String get featureBookForOthers => 'Für andere buchen';

  @override
  String get featureBookForOthersDesc =>
      'Admins und Inhaber buchen Plätze für andere Mitglieder.';

  @override
  String get featurePushNotifications => 'Push-Benachrichtigungen';

  @override
  String get featurePushNotificationsDesc =>
      'Ausstehende Bestätigungen auf die Geräte der Mitglieder zustellen.';

  @override
  String get featureAdminSeatBlocking => 'Admins können Plätze sperren';

  @override
  String get featureAdminSeatBlockingDesc =>
      'Admins markieren Plätze als nicht reservierbar für Wartung. Der Inhaber kann es immer.';

  @override
  String get featureAccessorySupplements => 'Zubehör-Aufpreise';

  @override
  String get featureAccessorySupplementsDesc =>
      'Bepreistes Platz-Zubehör pro gebuchtem Halbtag berechnen. Gilt für Buchungen ab der Aktivierung.';

  @override
  String get featureOnlinePayments => 'Online-Zahlungen';

  @override
  String get featureOnlinePaymentsDesc =>
      'Mitglieder zahlen ihre Rechnung online (PayPal). Erfordert die Einrichtung des Zahlungsanbieters auf dem Server.';

  @override
  String get featureNfcBadges => 'RFID-/NFC-Badges';

  @override
  String get featureNfcBadgesDesc =>
      'Mitglieder checken an einem Kiosk per RFID/NFC-Karte ein. Erfordert ein Android-Gerät mit NFC.';

  @override
  String get featureLevelBooking => 'Tisch-, Büro- & Etagen-Reservierungen';

  @override
  String get featureLevelBookingDesc =>
      'Einen ganzen Tisch, ein Büro oder eine Etage als eine Buchung reservieren, je Halbtag bepreist. Das Recht wird pro Mitglied vergeben.';

  @override
  String get featureAdminLevelAssign => 'Admins können Etagen zuweisen';

  @override
  String get featureAdminLevelAssignDesc =>
      'Admins weisen Mitgliedern Etagen-Reservierungen zu. Die Inhaberin kann es immer.';

  @override
  String get featureKioskMode => 'Kiosk-Modus';

  @override
  String get featureKioskModeDesc =>
      'Wandtablet-Konten, verriegelt auf den Live-Plan; Mitglieder handeln per Badge.';

  @override
  String get featureMembersDirectory => 'Mitgliederverzeichnis';

  @override
  String get featureMembersDirectoryDesc =>
      'Der Community-Tab: wer da ist, Status, Präsenz.';

  @override
  String get featureWhatsappIntegration => 'WhatsApp-Integration';

  @override
  String get featureWhatsappIntegrationDesc =>
      'Mitglieder teilen ihre WhatsApp-Nummer im Profil; ein Tipp auf ein Mitglied öffnet den Chat; der Gruppenlink im Verzeichnis. Keine serverseitige WhatsApp-Integration.';

  @override
  String get featureSpaceQrCodes => 'Raum-QR-Codes';

  @override
  String get featureSpaceQrCodesDesc =>
      'Druckbare QR-Karten je Platz, Tisch, Büro und Etage — scannen zum Reservieren oder Einchecken.';

  @override
  String featureRequires(String feature) {
    return 'Benötigt $feature';
  }

  @override
  String get featureCoOwner => 'Mit-Inhaberinnen';

  @override
  String get featureCoOwnerDesc =>
      'Mit-Inhaber ernennen: Inhaber-Rechte sofort (aktiv) oder wartende Nachfolge (passiv).';

  @override
  String get featureAutoCheckInOut => 'Auto-Check-in/-out am Tagesende';

  @override
  String get featureDataExport => 'Datenexport (Excel)';

  @override
  String get featureAutoCheckInOutDesc =>
      'Reservierungen ohne Check-in oder Check-out schließen sich selbst, sobald ihre Zeit vorbei ist.';

  @override
  String get featureDataExportDesc =>
      'Alle Daten des Spaces als Excel-Arbeitsmappe herunterladen.';

  @override
  String get featureWorkingHours => 'Arbeitszeiten';

  @override
  String get featureWorkingHoursDesc =>
      'Arbeitstag konfigurieren und Buchung nach exakten Uhrzeiten anbieten; aus = Standard 8–17 Uhr.';

  @override
  String get featureInvoicePdfTemplate => 'Rechnungs-PDF-Vorlage';

  @override
  String get featureInvoicePdfTemplateDesc =>
      'Vom Inhaber verfasste Einleitung und Fußtext auf dem Rechnungs-PDF. Das E-Rechnungs-XML bleibt unberührt.';

  @override
  String get featureMemberNotifications => 'Mitglieder-Benachrichtigungen';

  @override
  String get featureMemberNotificationsDesc =>
      'Nachrichten zwischen Mitgliedern: private und Gruppenunterhaltungen, Lesebestätigungen, Links zu einer Reservierung oder einem Raum; Admins können alle Admins benachrichtigen, Inhaber eingeschlossen.';

  @override
  String get featureDunning => 'Mahnwesen';

  @override
  String get featureDunningDesc =>
      'Konfigurierbare Mahnstufen und Fristen, ein Mahnschreiben pro Stufe und „Mahnung fällig“-Hinweise auf verspäteten Rechnungen. Das Senden bleibt ein manueller Tipp, außer mit den Automatischen Zahlungserinnerungen.';

  @override
  String get featureMemberReports => 'Mitgliederberichte';

  @override
  String get featureMemberReportsDesc =>
      'Die Finanzvereinbarung und der monatliche Zahlungsbericht — Self-Service für Mitglieder, pro Mitglied versendbar.';

  @override
  String get featureDeletionRequests => 'Lösch-Anträge für Buchungen';

  @override
  String get featureDeletionRequestsDesc =>
      'Mitglieder können die Löschung einer vergangenen oder eingecheckten Buchung BEANTRAGEN; Inhaber/Admin validieren. Aus: solche Buchungen sind gar nicht löschbar.';

  @override
  String get featurePlanObjectDeleteTitle => 'Räume mit Historie löschen';

  @override
  String get featurePlanObjectDeleteDesc =>
      'Inhaber können Ebenen, Büros, Tische und Sitzplätze auch dann löschen, wenn frühere Reservierungen darauf verweisen — die Buchungen behalten einen Text-Schnappschuss für Audits und Berichte.';

  @override
  String get featureNotificationGroupingTitle =>
      'Gruppierung der Benachrichtigungen';

  @override
  String get featureNotificationGroupingDesc =>
      'Mitglieder können den Benachrichtigungs-Feed nach Typ, Tag oder Mitglied gruppieren; ein Tipp auf das Gruppensymbol führt zurück zur flachen Liste.';

  @override
  String get featureBookingPoliciesTitle => 'Buchungsregeln';

  @override
  String get featureBookingPoliciesDesc =>
      'Konfigurierbares Buchungsverhalten: vergangene Buchungen, Minutenbuchungen außerhalb der Arbeitszeiten, Admin-Check-out.';

  @override
  String get featureNfcSeatTagsTitle => 'NFC/RFID-Tags an Stühlen';

  @override
  String get featureNfcSeatTagsDesc =>
      'Ein physischer NFC/RFID-Tag an einem Stuhl führt zu seinem Platz wie die gedruckte QR-Karte; das Feld füllt sich durch Antippen des Chips.';

  @override
  String get featureQrBadgesTitle => 'QR-Badges';

  @override
  String get featureQrBadgesDesc =>
      'Druckbare QR-Badge-Karten für den Kiosk, neben den NFC/RFID-Karten.';

  @override
  String get featureFormHelpHintsTitle => 'Hilfe-Hinweise';

  @override
  String get featureFormHelpHintsDesc =>
      'Ein ausblendbares Tipp-Karussell auf jedem Hauptbildschirm und ein kleines ? neben jedem Parameter und Eingabefeld — ein Tipp öffnet das Handbuch am richtigen Abschnitt. In den Einstellungen wiederherstellbar.';

  @override
  String get featureUiAnimationsTitle => 'Oberflächen-Animationen';

  @override
  String get featureUiAnimationsDesc =>
      'Sanfte Übergänge und Zustandsanimationen in der ganzen App. Aus bedeutet: Jede Änderung erfolgt sofort; die Bewegung-reduzieren-Einstellung des Geräts hat immer Vorrang.';

  @override
  String get featureKioskMemberPhotosTitle => 'Mitgliederfotos am Kiosk';

  @override
  String get featureKioskMemberPhotosDesc =>
      'Der Kiosk-Beleg zeigt das Profilfoto des Mitglieds — die visuelle Falsch-Badge-Kontrolle.';

  @override
  String get featurePlanMemberPhotosTitle => 'Mitgliederfotos auf dem Plan';

  @override
  String get featurePlanMemberPhotosDesc =>
      'Belegte Plätze im Plan-Tab und im Reservieren-Hub zeigen das Profilfoto statt der Initiale.';

  @override
  String get featureBadgeSignInTitle => 'Anmeldung per Ausweis';

  @override
  String get featureBadgeSignInDesc =>
      'Mitglieder melden sich an, indem sie ihren Ausweis scannen und ihre PIN eingeben, statt eine E-Mail-Adresse auf einem gemeinsam genutzten Tablet zu tippen. Jedes Mitglied setzt seine eigene PIN und aktiviert seinen eigenen Ausweis.';

  @override
  String get featureRegionalFormatsTitle => 'Region & Formate';

  @override
  String get featureRegionalFormatsDesc =>
      'Mitglieder wählen, wie Zahlen, Daten, Uhr und Zeitzone ihnen angezeigt werden. Aus: alle lesen in der Heimatregion der App-Sprache, 24-Stunden, Bereichszeit.';

  @override
  String get featureCalendarHubTitle => 'Kalender-Hub';

  @override
  String get featureCalendarHubDesc =>
      'Der Kalender zeigt alles Datierte — Buchungen, Check-ins, Meldungen, Nachrichten, Rechnungen, Zahlungen, Verbrauch, Erinnerungen — für einen Tag oder Zeitraum, jede Zeile öffnet ihre Quelle. Aus: nur Reservierungen.';

  @override
  String get featureDataAccessLogTitle => 'Datenzugriffsprotokoll';

  @override
  String get featureDataAccessLogDesc =>
      'Mitglieder sehen, wer wann ihre Finanzen eingesehen hat (vom Server geschrieben, nie umgehbar). Aus: die Zeile ist verborgen, das Protokoll bleibt.';

  @override
  String get featureMemberDataExportTitle => 'Export & Löschung';

  @override
  String get featureMemberDataExportDesc =>
      'Jedes Mitglied kann seine Daten als eine Datei exportieren (DSGVO Art. 20) und den Bereich mit gelöschten persönlichen Daten verlassen (Art. 17), unter Einstellungen → Datenschutz & Daten.';

  @override
  String get featureFinanceFacesTitle => 'Finanzen in vier Ansichten';

  @override
  String get featureFinanceFacesDesc =>
      'Der Finanzen-Tab hat vier Ansichten — Abrechnung, Zahlungen, Rechnungen, Dokumente — unter einem Monatswähler, jede mit eigener Hilfe. Aus: eine einzige Spalte.';

  @override
  String get featurePaymentRemindersTitle =>
      'Automatische Zahlungserinnerungen';

  @override
  String get featurePaymentRemindersDesc =>
      'Offene Rechnungen nach Ablauf der eingestellten Frist erhalten ihre Mahnstufen automatisch — ein Hinweis im Feed des Mitglieds und eine Push-Nachricht, einmal täglich. Aus: Mahnen bleibt ein manueller Schritt.';

  @override
  String get featureSupplyExpensesTitle => 'Vorräte aus Ausgaben';

  @override
  String get featureSupplyExpensesDesc =>
      'Eine Ausgabe kann ein Vorrat für den Raum sein (Kaffeekapseln, Staubsaugerbeutel…): genehmigt, füllt sie eine verbrauchbare Leistung mit Stückpreis auf oder legt sie an; Verbräuche zählen den Bestand herunter.';

  @override
  String get featureValidationScopesTitle => 'Prüfer nach Rolle oder Person';

  @override
  String get featureValidationScopesDesc =>
      'Jede Prüfregel nennt, wer prüft: die Admins, benannte Personen jeder Rolle oder alle Mitglieder — und wie viele. Aus: Inhaber und Admins wie bisher.';

  @override
  String get featurePriceNegotiationsTitle => 'Preisverhandlungen';

  @override
  String get featurePriceNegotiationsDesc =>
      'Der Tarif ist der Standard; ein Mitglied kann eigene Konditionen haben — Monatsgebühr, Überschreitungssatz, Rabatt auf Zuschläge, Stückpreise je Leistung und Paket, Belegungsprozentsatz —, vorgeschlagen von wer „Geschäftsvereinbarungen verwalten“ hält, und nach den Regeln validiert. Sichtbar für das Mitglied, die Inhaber und die Träger von „Geschäftsvereinbarungen einsehen“; jeder Zugriff wird protokolliert.';

  @override
  String get featureScheduledExpensesTitle => 'Geplante Ausgaben';

  @override
  String get featureUniqueMonogramsTitle => 'Eindeutige Avatar-Initialen';

  @override
  String get featureMessageGesturesTitle =>
      'Wischen zum Zitieren oder Zurücknehmen';

  @override
  String get featureSubscriptionInvoicesTitle => 'Abo-Rechnungen';

  @override
  String get featureSubscriptionInvoicesDesc =>
      'Der Mitgliedsbeitrag wird vor dem Monat berechnet, den er bezahlt, an einem Datum deiner Wahl. Aus: Der Beitrag bleibt auf der Monatsrechnung.';

  @override
  String get featureUsageInvoicesTitle => 'Monatsabschluss-Rechnungen';

  @override
  String get featureUsageInvoicesDesc =>
      'Ist ein Monat vorbei, wird getrennt berechnet, was er über das Abo hinaus gekostet hat — Mehrverbrauch, Zubehör, Leistungen. Aus: Das bleibt auf der Monatsrechnung.';

  @override
  String get featureInvoiceSettlementTitle => 'Rechnungen zusammenfassen';

  @override
  String get featureInvoiceSettlementDesc =>
      'Mehrere offene Rechnungen eines Mitglieds lassen sich zu einer zusammenfassen, die es bezahlt. Die Originale bleiben im Archiv, Position für Position nachvollziehbar, und werden nicht mehr einzeln angemahnt.';

  @override
  String featureAlsoEnabled(String features) {
    return 'Ebenfalls eingeschaltet: $features';
  }

  @override
  String featureAlsoEnables(String features) {
    return 'Das schaltet außerdem $features ein';
  }

  @override
  String get featureHeldBack =>
      'Wartet auf die Funktion darüber — schalte sie ein, dann wirkt auch diese wieder.';

  @override
  String get featureMessageGesturesDesc =>
      'Wische eine Nachricht nach rechts, um sie in deiner Antwort zu zitieren; nach links, um deine eigene Nachricht zurückzunehmen, solange sie niemand gelesen hat — nach einer Bestätigung. Aus: Nachrichten werden durch langes Drücken gelöscht.';

  @override
  String get featureUniqueMonogramsDesc =>
      'Ein Avatar ohne Foto zeigt Initialen, die zu genau einem Mitglied gehören: Anfangsbuchstabe von Vor- und Nachname, bei einer Kollision ein weiterer Buchstabe, Zahlen erst als letzter Ausweg. Aus: nur der erste Buchstabe, gleich für alle, die ihn teilen.';

  @override
  String get featureScheduledExpensesDesc =>
      'Wiederkehrende Ausgaben (Internet, Telefon, Strom): jedes Mitglied plant sie mit ihrer Regel (alle X Tage/Wochen/Monate/Jahre, X Mal oder bis zu einem Datum); der Plan wird einmal validiert, und jede Fälligkeit wird dem Mitglied vorgelegt — der validierte Betrag zählt sofort, ein abweichender erklärt sich und durchläuft die Ausgaben-Validierung.';

  @override
  String get featureInvoiceJourneyTitle => 'Der Weg einer Rechnung';

  @override
  String get featureInvoiceJourneyDesc =>
      'Jede Rechnung zeigt, wo sie steht — Ausgestellt, Zahlung, Bestätigung, Abgeschlossen — und wer am Zug ist: das Mitglied zahlt, ein Admin bestätigt die gemeldete Zahlung, der Aussteller ordnet sie zu, die Prüfer entscheiden. Das Hub der Aussteller erhält eine Stufenleiste mit Zählern und eine Erklärung „So funktioniert es“.';

  @override
  String get featureBookingGateTitle => 'Buchungsprüfung';

  @override
  String get featureBookingGateDesc =>
      'Jede Buchungsfläche — Plan, Tages-, Wochen- und Monatsansicht, Buchungsblatt, Kiosk, QR- oder NFC-Scan — prüft die Verfügbarkeitsparameter, bevor sie ein Zeitfenster anbietet, und nennt den Grund, wenn sie es nicht kann; geschlossene Tage erscheinen in jeder Ansicht geschlossen, eine Legende benennt die Platzzustände, und Admins dürfen Mitglieder auschecken, wo die Regel es erlaubt.';

  @override
  String get featureCalendarViewsTitle => 'Kalenderansichten';

  @override
  String get featureCalendarViewsDesc =>
      'Der Kalender-Tab als Agenda, Woche und Monat: Tagesmarker nach Art, geschlossene Tage als geschlossen, Kopfzeilen Heute / Morgen, Zahlungsfälligkeiten und geplante Ausgaben im Feed. Aus: der schlichte Tag-oder-Zeitraum-Wähler über dem Feed.';

  @override
  String get featureMessagesHubTitle => 'Nachrichten, überarbeitet';

  @override
  String get featureMessagesHubDesc =>
      'Eine Posteingangsleiste (Alle / Ungelesen / Archiviert und Suche), anheften, stumm, archivieren und als ungelesen markieren auf einem Thread, die Unterhaltung als ganze Seite mit Datumstrennern, ein Anhängen-Menü und ein behaltener Entwurf im Editor, eine Person mit einem Tipp geöffnet. Aus: der Posteingang mit zwei Leisten und der Thread als Blatt.';

  @override
  String get featureReportDesignerTitle => 'Berichtsdesigner';

  @override
  String get featureReportDesignerDesc =>
      'Der Berichtseditor als Vollbild-Designer: Elemente an Ort und Stelle in ihrer echten Typografie bearbeitet, Ziehen zum Umsortieren, eine Einfügepalette, eine durchsuchbare Feldauswahl, Rückgängig und Wiederholen, Bildgröße und -ausrichtung, ein Schutz vor dem Verwerfen, Vorlagen und Zurücksetzen hinter einer Bestätigung, der Vorlagenfehler im Klartext, Entwurf und Vorschau nebeneinander auf breitem Bildschirm. Aus: der Editor als Blatt.';

  @override
  String get featureMemberPageTitle => 'Mitgliedsseite';

  @override
  String get featureMemberPageDesc =>
      'Eine Seite pro Mitglied: Foto und Präsenz, zuletzt gesehen, aktuelle und kommende Buchungen, Schnellaktionen (Nachricht, WhatsApp, E-Mail), Kontakt- und Finanzkarten und für Admins jede Einstellung nach Thema gruppiert mit ihrem aktuellen Wert. Aus: das Profilblatt und das Aktionsblatt von Mitglieder & Tarife.';

  @override
  String get featureInvoicingWizardTitle => 'Rechnungsassistent';

  @override
  String get featureInvoicingWizardDesc =>
      'Ein geführter Monatsabschluss für die Finanzperson: ein Monatsanfangslauf für die im Voraus bezahlten Abonnements und ein Monatsendlauf für Nutzung und Zusatzkosten — Prüfung, Ausstellung im Stapel, Versand, fällige Mahnungen, Erfassen und Bestätigen von Zahlungen, Zuordnen zu Rechnungen, Zusammenfassen, Abschreiben oder Erstatten, und eine Zusammenfassung mit dem, was offen bleibt und wer am Zug ist. Aus: die einzelnen Bildschirme.';

  @override
  String get featureExpenseRepartitionTitle => 'Gemeinsame Ausgaben';

  @override
  String get featureExpenseRepartitionDesc =>
      'Eine gemeinsame Ausgabe (Reinigung, schnelleres Internet, ein kaputter Stuhl) auf die Mitglieder verteilt — gleiche Anteile, anteilig zum Abonnement, anteilig zur Nutzung oder ein Schlüssel je Mitglied — jeder Anteil vor der Buchung in der Vorschau. Die Anteile werden Positionen der nächsten Nutzungsrechnung; eine Umkehrung bucht Gutschriften. Läuft über die Bestätigungsregeln. Aus: keine Verteilung.';

  @override
  String get featureSettlementFoldTitle =>
      'Zusammengefasste Rechnungen eingeklappt';

  @override
  String get featureSettlementFoldDesc =>
      'Zu einer zusammengefasste Rechnungen verschwinden als eigene Zeilen aus den Listen und ordnen sich unter der Sammelrechnung ein, die alle ihre Positionen trägt. Auf einer zusammengefassten Rechnung ist jede Aktion aus; es bleibt nur ihr PDF, gestempelt mit der Nummer, in der sie aufging. Aus: die zusammengefassten Rechnungen bleiben neben der Sammelrechnung gelistet.';

  @override
  String get featureValidationChainTitle => 'Verkettete Freigaben';

  @override
  String get featureValidationChainDesc =>
      'Eine Freigaberegel kann ihre Freigaben nacheinander einholen — jede Stufe erst, wenn die vorige durch ist — und kann der Inhaberin oder dem Inhaber, nie einem Admin, die Freigabe der eigenen Handlung erlauben. Aus: alles wird auf einmal angefragt, und niemand gibt das Eigene frei.';

  @override
  String get featureRichMessageRefsTitle => 'Verweise in Nachrichten';

  @override
  String get featureRichMessageRefsDesc =>
      'Eine Nachricht kann auf einen Hinweis zeigen, auf den Freigabeverlauf dahinter und auf eine Rechnung, eine Zahlung oder eine Erstattung — jeder Verweis ist ein Link, der öffnet, was er nennt. Jede Auswahl filtert beim Tippen. Aus: nur Buchungen und Plätze sind verweisbar.';

  @override
  String get featureCalendarValidationsTitle => 'Freigaben im Kalender';

  @override
  String get featureCalendarValidationsDesc =>
      'Jede Entscheidung zu einem Ereignis erscheint im Kalender zum Zeitpunkt der Entscheidung, nicht des Ereignisses: wer was freigegeben oder abgelehnt hat, und wann. Ein Tippen öffnet den Verlauf. Aus: der Kalender trägt keine Entscheidungen.';

  @override
  String get featureUsageRecordsTitle => 'Nutzungssätze';

  @override
  String get featureUsageRecordsDesc =>
      'Jede gezählte Buchung hinterlässt einen Satz: das gebuchte Fenster, die tatsächliche Anwesenheit und was davon berechnet wird. Eine Buchung, zu der niemand kam, wird voll berechnet. Wer früher geht, kann darum bitten, die ungenutzte Zeit nicht zu berechnen — entschieden wird das von jemand anderem. Aus: keine Sätze, keine Korrektur.';

  @override
  String get featureReportDesignExchangeTitle =>
      'Berichtsvorlagen exportieren und importieren';

  @override
  String get featureReportDesignExchangeDesc =>
      'Jede Berichtsvorlage lässt sich als eine selbsterklärende Datei ausgeben und wieder einlesen. Die Datei enthält die Vorlage sowie die Bedeutung ihrer Felder, das erlaubte Markup und die vorhandenen Platzhalter — so kann sie außerhalb der App bearbeitet und zurückgegeben werden. Eine Datei für einen anderen Bericht oder aus einer neueren Version wird mit Begründung abgelehnt. Aus: Vorlagen sind nur im Designer änderbar.';

  @override
  String get helpTitle => 'Hilfe';

  @override
  String get helpContents => 'Inhalt';

  @override
  String get helpHintMessages =>
      'Alle Unterhaltungen in einer Liste, die neueste oben. Tippen Sie auf den Stift, um jemandem zu schreiben oder eine Gruppe zu erstellen.';

  @override
  String get helpHintMessagesTopic => 'Nachrichten';

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
  String get helpHintLearnMore => 'Mehr erfahren';

  @override
  String get helpHintDismiss => 'Hinweis ausblenden';

  @override
  String get helpHintPrevTip => 'Vorheriger Tipp';

  @override
  String get helpHintNextTip => 'Nächster Tipp';

  @override
  String get helpHintRestoreTitle => 'Hilfe-Hinweise wieder anzeigen';

  @override
  String get helpHintRestored => 'Die Hilfe-Hinweise werden wieder angezeigt.';

  @override
  String get helpHintReserve =>
      'Tag und Zeitfenster wählen, dann einen freien Platz antippen, um ihn zu buchen.';

  @override
  String get helpHintReserveTopic => 'Reservieren-Hub';

  @override
  String get helpHintReserveTip2 =>
      'Die Wochen- und Monatsansicht finden einen freien halben Tag auf einen Blick — freie Zelle oder freien Tag antippen und direkt buchen.';

  @override
  String get helpHintReserveTip3 =>
      'Den Scan-Knopf antippen und die Kamera auf die QR-Karte eines Raums richten — das Blatt zeigt genau, was dort möglich ist.';

  @override
  String get helpHintReserveTip3Topic => 'Einen Raumcode scannen';

  @override
  String get helpHintReserveTip4 =>
      'Die Chips Vormittag, Nachmittag und ganzer Tag legen das Zeitfenster fest, bevor der Platz gewählt wird — ein gebuchter Vormittag zählt als halber Tag.';

  @override
  String get helpHintReserveTip4Topic => 'Wie sich Buchungen verhalten';

  @override
  String get helpHintReserveTip5 =>
      'Die Standard-Buchungsperiode in den Einstellungen festlegen — der Hub wählt sie bei jedem Besuch vor.';

  @override
  String get helpHintReserveTip5Topic => 'Einstellungen & Profil';

  @override
  String get helpHintPlan =>
      'Der Live-Grundriss: freien Platz antippen zum Buchen, die eigene Buchung antippen zum Einchecken.';

  @override
  String get helpHintPlanTopic => 'Grundriss';

  @override
  String get helpHintPlanTip2 =>
      'Direkt am freien Platz? Antippen — das Blatt schlägt jetzt bis Feierabend vor, und Bestätigen checkt sofort ein.';

  @override
  String get helpHintPlanTip3 =>
      'Mit dem Datums-Chip und dem Zeitregler einen anderen Moment ansehen — der Grundriss zeigt die Belegung zu jedem künftigen Zeitpunkt.';

  @override
  String get helpHintPlanTip4 =>
      'Einen Schreibtisch, einen Raum oder die Etage doppelt antippen — oder das Ebenen-Symbol der Etagenleiste — und den ganzen Bereich auf einmal reservieren.';

  @override
  String get helpHintPlanTip5 =>
      'Den eigenen Platz antippen für sein Blatt: Einchecken ab 15 Minuten vor dem Start, Auschecken beim Gehen.';

  @override
  String get helpHintPlanTip5Topic => 'Wie sich Buchungen verhalten';

  @override
  String get helpHintCalendar =>
      'Wähle einen Tag oder Zeitraum: alles Datierte, das du sehen darfst, in einer Liste, jede Zeile öffnet ihre Quelle.';

  @override
  String get helpHintCalendarTopic => 'Kalender';

  @override
  String get helpHintCalendarTip2 =>
      'Wechsle von Tag zu Zeitraum für eine ganze Woche oder einen Monat — die Pfeile springen um die Größe deiner Auswahl.';

  @override
  String get helpHintCalendarTip3 =>
      'Tippe einen Art-Chip, um nur das zu sehen: Buchungen, Meldungen, Nachrichten, Rechnungen, Zahlungen, Verbrauch, Erinnerungen.';

  @override
  String get helpHintCalendarTip4 =>
      'Jede Zeile öffnet ihre Quelle — die Buchung, die Unterhaltung, die Meldung, die Rechnung oder den Monat in Finanzen.';

  @override
  String get helpHintCalendarTip4Topic => 'Wie sich Buchungen verhalten';

  @override
  String get helpHintEvents =>
      'Alles, was passiert ist, in einem Feed. Ausstehende Entscheidungen stehen oben; die Chips filtern den Rest.';

  @override
  String get helpHintEventsTopic => 'Ereignisse';

  @override
  String get helpHintEventsTip2 =>
      'Die Filter-Chips merken sich die Auswahl über Besuche hinweg — und der Chip Ungelesen zeigt nur die ungelesenen Nachrichten.';

  @override
  String get helpHintEventsTip3 =>
      'Den Feed über das Menü Gruppieren nach Typ, Tag oder Mitglied falten; das Gruppensymbol antippen führt zur flachen Liste zurück.';

  @override
  String get helpHintEventsTip4 =>
      'Ausstehende Entscheidungen stehen oben angepinnt mit Annehmen und Ablehnen — und niemand bestätigt je das eigene Ereignis.';

  @override
  String get helpHintEditor =>
      'Räume und Schreibtische zeichnen, Plätze aufstempeln — einen Platz zweimal antippen, um seine Eigenschaften zu bearbeiten.';

  @override
  String get helpHintEditorTopic => 'Space-Editor';

  @override
  String get helpHintEditorTip2 =>
      'Büro oder Tisch in der Werkzeugleiste wählen und auf dem Raster aufziehen; Auswählen verschiebt und skaliert Vorhandenes.';

  @override
  String get helpHintEditorTip3 =>
      'Das Platz-Werkzeug stempelt Plätze auf die Tische; das Blatt eines Platzes regelt Ausrichtung, Stuhltyp, Zubehör und eine Wartungssperre.';

  @override
  String get helpHintEditorTip4 =>
      'Einem Platz seinen NFC/RFID-Tag im Platz-Blatt geben — den Chip ans Telefon halten und das Feld füllt sich von selbst.';

  @override
  String get helpHintEditorTip5 =>
      'Für jeden Platz, Tisch, Raum und jede Etage eine QR-Karte drucken — Kartengröße und Karteninhalt vor dem Export wählen.';

  @override
  String get helpHintEditorTip5Topic => 'Raum-QR-Codes';

  @override
  String get helpHintAvailability =>
      'Öffnungstage und Arbeitszeiten festlegen und Schließtage eintragen, die niemand buchen kann.';

  @override
  String get helpHintAvailabilityTopic => 'Verfügbarkeit';

  @override
  String get helpHintAvailabilityTip2 =>
      'Die Buchungsgranularität bestimmt, wie ein Zeitfenster aussehen darf: halbe Tage, ganze Tage, Minutenraster oder freie Zeiten.';

  @override
  String get helpHintAvailabilityTip3 =>
      'Tagesbeginn, Halbtagsgrenze und Tagesende steuern jeden Halbtags- und Ganztagsslot — Buchung, Check-in und Abrechnung folgen ihnen.';

  @override
  String get helpHintAvailabilityTip4 =>
      'Drei Buchungsrichtlinien lockern oder verschärfen die Regeln: vergangene Buchungen, Minutenbuchungen nur in der Arbeitszeit, Admin-Check-out.';

  @override
  String get helpHintFeatures =>
      'Workspace-Funktionen ein- oder ausschalten — die App jedes Mitglieds folgt sofort.';

  @override
  String get helpHintFeaturesTopic => 'Funktionen';

  @override
  String get helpHintFeaturesTip2 =>
      'Die Liste ist hierarchisch — eine Funktion, die eine andere braucht, steht eingerückt darunter und ist ausgegraut, solange der Elternschalter aus ist.';

  @override
  String get helpHintFeaturesTip3 =>
      'Einen Elternschalter auszuschalten nimmt den ganzen Teilbaum aus der App; die gespeicherten Einstellungen der Kinder kehren mit dem Elternteil unverändert zurück.';

  @override
  String get helpHintFeaturesTip4 =>
      'Der Einstellungs-Eintrag einer Funktion erscheint nur, solange sie an ist — der Funktionen-Bildschirm selbst bleibt immer erreichbar.';

  @override
  String get helpHintMembers =>
      'Mitglieder einladen, Plan-Prozentsatz und Rolle festlegen und ihre Badges verwalten.';

  @override
  String get helpHintMembersTopic => 'Mitglieder & Tarife';

  @override
  String get helpHintMembersTip2 =>
      'Ein Mitglied antippen für sein Verwaltungsblatt — Abonnement, Reservierungslimit, Badges, Services und mehr an einem Ort.';

  @override
  String get helpHintMembersTip3 =>
      'Badges gehören zum Mitglied: ein druckbares QR-Badge ausstellen oder die NFC-Karte registrieren, indem man sie ans Gerät hält.';

  @override
  String get helpHintMembersTip3Topic => 'NFC-Badges';

  @override
  String get helpHintMembersTip4 =>
      'Zum Admin ernennen vergibt Adminrechte nach Bestätigung; die Rollenmatrix unter Rollenverwaltung entscheidet, was jede Rolle darf.';

  @override
  String get helpHintMembersTip4Topic => 'Rollenverwaltung';

  @override
  String get helpHintMoney =>
      'Die Monatsabrechnung: mit den Pfeilen durch die Monate blättern; von hier zahlen, exportieren oder teilen.';

  @override
  String get helpHintMoneyTopic => 'Geld';

  @override
  String get helpHintMoneyTip2 =>
      'Jedes Dokument bietet dieselben drei Aktionen: Schnellansicht auf dem Bildschirm, Download als PDF und Teilen an jede App.';

  @override
  String get helpHintMoneyTip2Topic => 'Schnellansicht, Speichern, Teilen';

  @override
  String get helpHintMoneyTip3 =>
      'Eine Zahlung mit dem Datum der Überweisung und dem Monat erfassen, den sie ausgleicht — die Gegenseite bestätigt.';

  @override
  String get helpHintMoneyTip4 =>
      'Sobald der Monat fakturiert ist, entscheidet die Rechnung: der Monat gilt als beglichen, sobald seine Rechnung bezahlt ist.';

  @override
  String get helpHintMoneyTip4Topic => 'entscheidet die Rechnung';

  @override
  String get helpHintValidation =>
      'Festlegen, welche Aktionen eine Bestätigung brauchen, wer bestätigt und wie viele Zustimmungen nötig sind.';

  @override
  String get helpHintValidationTopic => 'Bestätigungen';

  @override
  String get helpHintValidationTip2 =>
      'Eine Karte pro Ereignistyp, jede erbt von der Standardregel, bis sie bearbeitet wird — Zahlungen, Ausgaben, Rollenwechsel und mehr.';

  @override
  String get helpHintValidationTip3 =>
      'Niemand bestätigt je das eigene Ereignis, und unbeantwortete Anfragen verfallen nach 7 Tagen — nichts wird stillschweigend gewährt.';

  @override
  String get helpHintWorkspace =>
      'Land, Währung, Sprache und Rechnungsdaten — Dokumente und Steuern folgen diesen Einstellungen.';

  @override
  String get helpHintWorkspaceTopic => 'Workspace-Einstellungen';

  @override
  String get helpHintWorkspaceTip2 =>
      'Die Raum-QR-Karten unter Exporte drucken — Kartengröße und Karteninhalt wählen, zehn pro A4-Seite.';

  @override
  String get helpHintWorkspaceTip2Topic => 'Raum-QR-Codes';

  @override
  String get helpHintWorkspaceTip3 =>
      'Den Workspace als XML exportieren, um ihn zu sichern oder als Vorlage zu nutzen; der Einrichtungs-Fragebogen füllt einen neuen Workspace von A bis Z.';

  @override
  String get helpHintWorkspaceTip4 =>
      'Workspace zurücksetzen löscht Reservierungen, Buchhaltung und Grundriss — Einstellungen und Mitglieder bleiben, eine getippte Bestätigung schützt davor.';

  @override
  String get helpHintBadges =>
      'Druckbares QR-Badge ausstellen oder NFC-Karte registrieren; verlorene Badges jederzeit sperren.';

  @override
  String get helpHintBadgesTopic => 'NFC-Badges';

  @override
  String get helpHintBadgesTip2 =>
      'Eine Karte registrieren, indem man sie ans Gerät hält — jeder lesbare Chip funktioniert, und der Dialog nennt den Workspace, für den sie gilt.';

  @override
  String get helpHintBadgesTip3 =>
      'Ein QR-Badge als PDF speichern und zehn Exemplare im Scheckkartenformat auf einer A4-Seite drucken — Ersatz inklusive.';

  @override
  String get helpHintBadgesTip4 =>
      'Ein verlorenes Badge jederzeit sperren; ein gesperrtes Badge nach rechts wischen, um es endgültig zu löschen.';

  @override
  String get helpHintCalendarTip5 =>
      'Der Schild zeigt, wer jede Art sehen kann und wer tatsächlich deine Finanzen eingesehen hat.';

  @override
  String get helpHintCalendarTip5Topic => 'Datenschutz';

  @override
  String get helpHintPrivacy =>
      'Sieh, wer deine Daten lesen kann und wer es tat, exportiere alles als eine Datei oder verlasse den Bereich mit gelöschten persönlichen Daten.';

  @override
  String get helpHintPrivacyTopic => 'Datenschutz';

  @override
  String get helpHintPrivacyTip2 =>
      'Nachrichten lesen nur die Personen der Unterhaltung, unabhängig von der Rolle; Geld nur du und die Finanz-Berechtigung.';

  @override
  String get helpHintPrivacyTip3 =>
      'Jede Einsicht in deine Finanzen durch andere wird vom Server protokolliert — das Protokoll lässt sich weder umgehen noch ändern.';

  @override
  String get helpHintMoneyPayments =>
      'Begleichen und anfragen: der Saldo, wie Sie ihn begleichen oder online zahlen, eine Zahlung erfassen — und eine Ausgabe einreichen, halbe Tage anfragen oder einen Verbrauch hinzufügen.';

  @override
  String get helpHintMoneyPaymentsTopic => 'Die Ansicht Zahlungen';

  @override
  String get helpHintMoneyPaymentsTip2 =>
      'Erfassen Sie eine Zahlung mit dem Datum der Buchung und dem Monat, den sie ausgleicht — die Gegenseite bestätigt.';

  @override
  String get helpHintMoneyPaymentsTip3 =>
      'Online zahlen begleicht den offenen Betrag sofort; die Hinweiskarte zeigt den manuellen Weg mit der anzugebenden Referenz.';

  @override
  String get helpHintMoneyPaymentsTip3Topic => 'Online-Zahlungen';

  @override
  String get helpHintMoneyStatement =>
      'Der Monat, wie er steht: Ihr Konto, genutzte und verbleibende Tage, Abonnement, Leistungen, Pakete, offene Posten, Gutschriften und der Saldo. Monate mit den Pfeilen durchblättern.';

  @override
  String get helpHintMoneyStatementTopic => 'Die Ansicht Abrechnung';

  @override
  String get helpHintMoneyStatementTip2 =>
      'Ein gebuchter Vormittag zählt als halber Tag; Tage außerhalb der Öffnungszeiten folgen der Außerhalb-Regel des Workspace.';

  @override
  String get helpHintMoneyStatementTip2Topic => 'Wie sich Buchungen verhalten';

  @override
  String get helpHintMoneyStatementTip3 =>
      'Keine Tage mehr? Halbe Tage anfragen, ein Paket kaufen oder nach Verbrauch weiterbuchen — je nach Tarif.';

  @override
  String get helpHintMoneyInvoices =>
      'Ihre Rechnungen: was offen ist und bis wann, jede an Sie gestellte Rechnung mit Status, ein Tipp zum Detail und zum Bezahlen.';

  @override
  String get helpHintMoneyInvoicesTopic => 'Die Ansicht Rechnungen';

  @override
  String get helpHintMoneyInvoicesTip2 =>
      'Nach Ablauf der Zahlungsfrist des Workspace liest sich eine offene Rechnung hier als überfällig, und die vom Inhaber eingestellten Mahnstufen kommen von selbst — im Feed und als Push.';

  @override
  String get helpHintMoneyInvoicesTip2Topic =>
      'Automatische Zahlungserinnerungen';

  @override
  String get helpHintMoneyDocuments =>
      'Ihre Unterlagen: Ihre Konditionen, der Zahlungsbericht, die Monatsabrechnung als PDF, die Dokumentbibliothek.';

  @override
  String get helpHintMoneyDocumentsTopic => 'Die Ansicht Dokumente';

  @override
  String get helpHintMoneyDocumentsTip3 =>
      'Meine Konditionen ist Ihre geltende Finanzvereinbarung — Tarif, Satz, Extras — als Dokument zum Aufbewahren.';

  @override
  String get helpHintValidationTipScopes =>
      'Wer prüft, ist der Geltungsbereich der Regel: die Admins, benannte Personen jeder Rolle oder alle Mitglieder — und wie viele. Der Inhaber darf immer; niemand prüft das eigene Ereignis.';

  @override
  String get helpHintValidationTipScopesTopic => 'Rollenverwaltung';

  @override
  String get helpHintMoneyPaymentsTipSupply =>
      'Kapseln oder Staubsaugerbeutel für den Raum gekauft? Reichen Sie die Ausgabe als Vorrat ein: genehmigt, steht sie als Verbrauchsartikel im Regal, den andere bezahlen, und Sie werden erstattet.';

  @override
  String get helpHintMoneyPaymentsTipSupplyTopic => 'Services und Zubehör';

  @override
  String get helpHintMoneyStatementTipNegotiation =>
      'Konditionen verhandelt? Die Karte zeigt Ihre Preise neben dem Tarif, seit wann, und wer sie sehen kann — die Inhaber und Finanz-Admins, jeder Zugriff protokolliert.';

  @override
  String get helpHintMoneyStatementTipNegotiationTopic => 'Preisverhandlungen';

  @override
  String get helpHintMembersTipNegotiation =>
      'Die eigenen Preise eines Mitglieds: sein Blatt öffnen → Preisverhandlung, Beitrag, Überschreitung oder Rabatt eintragen, und die Prüfer der Regel bestätigen.';

  @override
  String get helpHintMembersTipNegotiationTopic => 'Preisverhandlungen';

  @override
  String get helpDotTooltip => 'Handbuch öffnen';

  @override
  String get helpTopicLegalIdentity => 'Rechtliche Identität';

  @override
  String get helpTopicEinvoice => 'E-Rechnung';

  @override
  String get helpTopicReportEditor => 'Report-Editor';

  @override
  String get helpTopicDocumentLibrary => 'Dokumentbibliothek';

  @override
  String get helpTopicWorkspaceId => 'Workspace-ID';

  @override
  String get helpTopicVat => 'MwSt';

  @override
  String get helpTopicSettings => 'Einstellungen & Profil';

  @override
  String get helpTopicKiosk => 'Kiosk-Modus';

  @override
  String get helpTopicBilling => 'Abrechnung';

  @override
  String get helpTopicWorkingHours => 'Arbeitszeiten';

  @override
  String get helpTopicBookingPolicies => 'Buchungsregeln';

  @override
  String get helpTopicBookingLimits => 'Buchungsgrenzen';

  @override
  String get helpTopicScheduledExpenses => 'Geplante Ausgaben';

  @override
  String get helpTopicServer => 'dein eigener Server';

  @override
  String get inviteSectionTitle => 'Jemanden einladen';

  @override
  String get inviteViaWhatsapp => 'WhatsApp';

  @override
  String get inviteViaSms => 'SMS';

  @override
  String get inviteViaShare => 'Teilen…';

  @override
  String get inviteFirstNameLabel => 'Vorname (optional)';

  @override
  String get inviteLastNameLabel => 'Nachname (optional)';

  @override
  String get invitePhoneLabel => 'Telefon (optional, mit Ländervorwahl)';

  @override
  String get inviteLanguageLabel => 'Sprache der Nachricht';

  @override
  String get inviteSendFailed =>
      'Die Sende-App ließ sich nicht öffnen. Die Nachricht wurde stattdessen kopiert.';

  @override
  String get inviteCreateFailed =>
      'Die Einladung konnte nicht erstellt werden. Prüfe deine Verbindung und versuche es erneut.';

  @override
  String invitationDefaultTemplate(
    String firstName,
    String workspaceName,
    String workspaceId,
    String downloadUrl,
    String inviteLink,
  ) {
    return 'Hallo$firstName! Du bist eingeladen, unserem Coworking-Space „$workspaceName“ auf DesKilo beizutreten.\n\n1. Lade die App herunter:\n$downloadUrl\n\n2. Öffne sie, lege dein Konto an (E-Mail + Passwort) und melde dich an.\n\n3. Wähle „Workspace beitreten“ und gib deinen persönlichen Einladungscode ein:\n$workspaceId\n(Einladungslink: $inviteLink)\n\nTipp: Kopiere einfach diese ganze Nachricht und füge sie in der App ein — der Code wird automatisch erkannt. Dein Code ist persönlich, einmalig nutzbar und 14 Tage gültig.\n\nBis bald bei $workspaceName!';
  }

  @override
  String get invitationTemplateTitle => 'Einladungsnachricht';

  @override
  String get invitationTemplateHelp =>
      'Wird gesendet, wenn du jemanden per WhatsApp, SMS oder Teilen einlädst. Leer lassen für die eingebaute Nachricht in der gewählten Sprache. Verfügbare Tags:';

  @override
  String get invitationTemplateHint =>
      'Eigene Einladungsnachricht mit den Tags oben…';

  @override
  String get workspaceInvitePasteHint =>
      'Füge die ganze Einladungsnachricht ein — die ID wird automatisch erkannt.';

  @override
  String get workspaceInviteCodeInvalid =>
      'Keine Workspace-ID gefunden — Einladung einfügen oder ID eintippen.';

  @override
  String get invoicesTitle => 'Rechnungen';

  @override
  String get invoicesEmpty => 'Noch keine Rechnungen.';

  @override
  String get invoiceCreate => 'Neue Rechnung';

  @override
  String get invoiceMemberLabel => 'Mitglied';

  @override
  String get invoiceIssue => 'Rechnung ausstellen';

  @override
  String get invoiceIssued => 'Rechnung ausgestellt.';

  @override
  String get invoiceDownload => 'PDF herunterladen';

  @override
  String get invoiceShare => 'PDF teilen';

  @override
  String get invoicePdfTitle => 'Rechnung';

  @override
  String get invoicePdfIssuedOn => 'Ausgestellt am';

  @override
  String get invoicePdfIssuedBy => 'Ausgestellt von';

  @override
  String get invoicePdfBilledTo => 'Rechnung an';

  @override
  String get invoicePdfSignature => 'Digitale Signatur (SHA-256)';

  @override
  String get addressTitle => 'Adresse';

  @override
  String get addressNone => 'Keine Adresse';

  @override
  String get addressSaved => 'Adresse gespeichert';

  @override
  String get workspaceAddressLabel => 'Adresse des Workspace';

  @override
  String get featureInvoicing => 'Rechnungen';

  @override
  String get featureInvoicingDesc =>
      'Unveränderliche, signierte Rechnungen im Archiv — als PDF herunterladen oder teilen.';

  @override
  String get featureAdminInvoicing => 'Admins stellen Rechnungen aus';

  @override
  String get featureAdminInvoicingDesc =>
      'Auch Admins stellen Rechnungen aus. Die Inhaberin kann es immer.';

  @override
  String get invoiceVoidedChip => 'Fehlerhaft';

  @override
  String get invoiceVoidAction => 'Als fehlerhaft markieren';

  @override
  String invoiceVoidConfirm(String number) {
    return 'Rechnung $number als fehlerhaft markieren? Das kann nicht rückgängig gemacht werden.';
  }

  @override
  String get invoiceVoided => 'Rechnung als fehlerhaft markiert.';

  @override
  String get invoiceReplaceAction => 'Ersatzrechnung ausstellen';

  @override
  String get invoicePdfVoided => 'FEHLERHAFT — storniert am';

  @override
  String get invoicePdfReplaces => 'Ersetzt';

  @override
  String get invoiceNothingToInvoice =>
      'Für diesen Monat wurde nichts erfasst — nichts zu berechnen.';

  @override
  String get invoiceLineAdjustment => 'Anpassung';

  @override
  String get invoiceFilterAllMembers => 'Alle Mitglieder';

  @override
  String get invoiceFilterAllMonths => 'Alle Monate';

  @override
  String get invoiceFilterMonthLabel => 'Monat';

  @override
  String get invoiceSortTooltip => 'Sortieren';

  @override
  String get invoiceSortNewest => 'Neueste zuerst';

  @override
  String get invoiceSortByMember => 'Nach Mitglied';

  @override
  String get invoiceSortByMonth => 'Nach Monat';

  @override
  String get invoiceBalance => 'Saldo';

  @override
  String get invoiceDetailedToggle =>
      'Detaillierten Anhang aufnehmen (Check-ins, Services, Zahlungen)';

  @override
  String get invoicePdfDescription => 'Beschreibung';

  @override
  String get invoicePdfCharges => 'Posten';

  @override
  String get invoicePdfPayments => 'Zahlungen';

  @override
  String get invoicePdfAnnex => 'Anhang — Details';

  @override
  String get invoicePdfAttendance => 'Check-ins';

  @override
  String get invoicePdfActivity => 'Buchungen & Zahlungen';

  @override
  String get invoicePdfReserved => 'reserviert';

  @override
  String get invoicePdfPage => 'Seite';

  @override
  String get invoiceRemindAction => 'Zahlungserinnerung senden';

  @override
  String get invoiceReminded => 'Erinnerung erfasst.';

  @override
  String invoiceRemindedBadge(int count) {
    return 'Erinnert ×$count';
  }

  @override
  String invoiceReminderMessage(String number, String amount) {
    return 'Freundliche Erinnerung: Rechnung $number — offener Saldo $amount.';
  }

  @override
  String get invoiceEInvoiceDownload => 'E-Rechnung herunterladen (XML)';

  @override
  String get invoiceEInvoiceShare => 'E-Rechnung teilen (XML)';

  @override
  String get invoiceTabToInvoice => 'Zu berechnen';

  @override
  String get invoiceTabOpen => 'Offen';

  @override
  String get invoiceTabArchive => 'Archiv';

  @override
  String get invoiceIssueAll => 'Alle berechnen';

  @override
  String get invoiceIssueOne => 'Berechnen';

  @override
  String get invoiceAllCaughtUp => 'Alles erledigt — nichts zu berechnen.';

  @override
  String get invoiceNoOpen => 'Keine offenen Rechnungen.';

  @override
  String invoiceSummaryToInvoice(int count) {
    return '$count zu berechnen';
  }

  @override
  String invoiceSummaryOpen(int count, String amount) {
    return '$count offen · $amount ausstehend';
  }

  @override
  String invoiceOpenAge(int days) {
    return '$days Tage';
  }

  @override
  String invoiceIssuedCount(int count) {
    return '$count Rechnungen ausgestellt.';
  }

  @override
  String get eventTypeInvoicePayment => 'Rechnungszahlung';

  @override
  String eventInvoicePaid(String number, String amount) {
    return 'Rechnung $number bezahlt — $amount';
  }

  @override
  String get invoiceMatchAction => 'Als bezahlt markieren';

  @override
  String get invoiceMatchNoteLabel => 'Notiz';

  @override
  String get invoiceMatchNoteRequired => 'Eine Notiz ist erforderlich.';

  @override
  String invoiceMatchOver(String excess) {
    return 'Das Mitglied hat $excess mehr gezahlt.';
  }

  @override
  String get invoiceMatchCreditNote =>
      'Gutschrift über den Überschuss erstellen';

  @override
  String get invoiceMatchForce => 'Trotzdem akzeptieren (mit Begründung)';

  @override
  String invoiceMatchUnder(String missing) {
    return 'Das Mitglied hat $missing weniger gezahlt — Akzeptieren erfordert eine Notiz.';
  }

  @override
  String get invoiceMatched => 'Rechnung abgeglichen.';

  @override
  String get invoiceMatchPendingBadge => 'Wartet auf Validierung';

  @override
  String get invoiceMatchedBadge => 'Bezahlt';

  @override
  String get invoiceAlreadyInvoiced =>
      'Dieser Monat ist für dieses Mitglied bereits berechnet.';

  @override
  String get invoiceMatchPickPayment => 'Registrierte Zahlung auswählen';

  @override
  String get invoiceMatchNoPayments =>
      'Keine registrierte Zahlung zum Abgleich — zuerst erfassen oder bestätigen.';

  @override
  String get invoiceStatusOpen => 'Offen';

  @override
  String invoiceCountShown(int count) {
    return '$count Rechnungen';
  }

  @override
  String get invoiceFilterNoMatch =>
      'Keine Rechnung entspricht diesen Filtern.';

  @override
  String get invoiceFilterClear => 'Filter zurücksetzen';

  @override
  String get invoiceShowCancelled => 'Stornierte anzeigen';

  @override
  String invoiceReplacedBy(String number) {
    return 'Ersetzt durch $number';
  }

  @override
  String invoiceMatchSummary(String amount, String date) {
    return 'Bezahlt $amount am $date';
  }

  @override
  String invoiceRemindedLast(String date) {
    return 'letzte Mahnung $date';
  }

  @override
  String invoiceAnnexSummary(int movements, int checkIns) {
    return 'Anhang: $movements Bewegungen, $checkIns Check-ins';
  }

  @override
  String get invoicePickMember =>
      'Ein Mitglied wählen, um zu sehen, was dieser Monat erfasst hat.';

  @override
  String get invoiceRunningMonth =>
      'Dieser Monat läuft noch — seine Positionen können sich noch ändern, und ein Monat lässt sich nur einmal abrechnen.';

  @override
  String invoiceIssueAllConfirm(int count, String month, String total) {
    return '$count Rechnungen für $month über insgesamt $total ausstellen? Eine ausgestellte Rechnung lässt sich nicht mehr ändern — ein Fehler wird durch eine Ersatzrechnung korrigiert.';
  }

  @override
  String invoiceIssuedPartial(int issued, int failed) {
    return '$issued ausgestellt, $failed fehlgeschlagen.';
  }

  @override
  String get invoiceEInvoiceAction => 'E-Rechnung (XML)';

  @override
  String get invoiceEInvoiceExplain =>
      'Die maschinenlesbare EN-16931-Rechnung — die Datei, die Finanzverwaltungen und Geschäftskunden verlangen.';

  @override
  String invoiceEInvoiceBusinessRoute(String channel, String format) {
    return 'Geschäftskunden: über $channel als $format übermitteln.';
  }

  @override
  String invoiceEInvoicePublicRoute(String channel) {
    return 'Öffentliche Auftraggeber: $channel.';
  }

  @override
  String get invoiceEInvoiceTransportPeppol =>
      'Ein Access Point liefert sie an den Kunden — keine staatliche Plattform dazwischen.';

  @override
  String get invoiceEInvoiceTransportClearance =>
      'Die nationale Plattform erhält die Rechnung zuerst und leitet sie weiter — ein direkter Versand an den Kunden ist nicht möglich.';

  @override
  String get invoiceEInvoiceTransportAccredited =>
      'Eine zugelassene Plattform übermittelt die Rechnung und meldet die Daten an die Finanzverwaltung.';

  @override
  String get invoiceEInvoiceTransportBilateral =>
      'Kein Kanal ist vorgeschrieben: E-Mail, Portal oder Peppol — wie mit dem Kunden vereinbart.';

  @override
  String invoiceEInvoiceFormatMismatch(String channel, String format) {
    return '$channel akzeptiert nur $format: Diese EN-16931-Datei dient für Peppol, öffentliche Auftraggeber und ausländische Kunden — den Rest konvertiert die Plattform.';
  }

  @override
  String get invoiceEInvoiceReady => 'Bereit — diese Datei erfüllt EN 16931.';

  @override
  String get invoiceEInvoiceBlockedTitle =>
      'Ein Validator würde diese Datei ablehnen:';

  @override
  String get invoiceEInvoiceIncompleteTitle =>
      'Gültig, doch die strengen nationalen Profile wollen zusätzlich:';

  @override
  String get invoiceGapVatNotSupported =>
      'Der Space verlangt Mehrwertsteuer, diese Rechnung trägt aber keinen Satz — Sätze anlegen und die Rechnung neu ausstellen.';

  @override
  String get invoiceGapMissingVatId =>
      'Die Umsatzsteuer-Identifikationsnummer fehlt — ein steuerbefreiter Verkäufer muss sie angeben.';

  @override
  String get invoiceGapMissingLegalId =>
      'Die Registernummer fehlt (SIREN, HRB, CIF…) — nichts identifiziert dich auf der Rechnung.';

  @override
  String get invoiceGapMissingExemptionReason =>
      'Der Grund für die Steuerbefreiung fehlt.';

  @override
  String get invoiceGapMissingSellerCountry => 'Das Land des Workspace fehlt.';

  @override
  String get invoiceGapMissingBuyerCountry => 'Das Land des Kunden fehlt.';

  @override
  String get invoiceGapNoChargeLines =>
      'Diese Rechnung hat keine Belastungsposition — ihr Monat war vollständig durch Zahlungen gedeckt, es gibt nichts zu übermitteln.';

  @override
  String get invoiceGapMissingSellerCity => 'die Stadt der Workspace-Adresse';

  @override
  String get invoiceGapMissingSellerPostalCode =>
      'die Postleitzahl der Workspace-Adresse';

  @override
  String get invoiceEInvoiceFixIdentity =>
      'Rechtliche Identität vervollständigen';

  @override
  String get legalIdentityTitle => 'Rechtliche Identität & E-Rechnung';

  @override
  String get legalIdentitySubtitle =>
      'Steuerregime und Registernummern — von der E-Rechnung verlangt';

  @override
  String get legalIdentityIntro =>
      'Was eine EN-16931-E-Rechnung über dich aussagen muss. Bereits ausgestellte Rechnungen behalten die Identität, mit der sie signiert wurden.';

  @override
  String get legalIdentityRegime => 'Steuerregime';

  @override
  String get legalIdentityRegimeNotSubject =>
      'Nicht der Umsatzsteuer unterliegend';

  @override
  String get legalIdentityRegimeExempt =>
      'Umsatzsteuerfrei (Kleinunternehmerregelung)';

  @override
  String get legalIdentityRegimeVatRegistered =>
      'Umsatzsteuerpflichtig (berechnet USt.)';

  @override
  String get legalIdentityRegimeHint =>
      'Das Regime entscheidet, welche Nummer die Norm verlangt: eine Registernummer außerhalb der Umsatzsteuer, eine USt-IdNr. bei Steuerbefreiung.';

  @override
  String get legalIdentityVatId => 'Umsatzsteuer-ID';

  @override
  String get legalIdentityLegalId => 'Registernummer';

  @override
  String get legalIdentityExemptionReason => 'Grund der Steuerbefreiung';

  @override
  String get legalIdentityStreet => 'Straße';

  @override
  String get legalIdentityCity => 'Stadt';

  @override
  String get legalIdentityPostalCode => 'Postleitzahl';

  @override
  String get legalIdentitySaved => 'Rechtliche Identität gespeichert.';

  @override
  String get legalIdentityVatWarning =>
      'Dieser Space verlangt Mehrwertsteuer, es ist aber kein Satz angelegt: Rechnungen weisen keine Steuer aus und der XML-Export bleibt deaktiviert.';

  @override
  String get addressCountryLabel => 'Land';

  @override
  String get addressVatIdLabel =>
      'Umsatzsteuer-ID (wenn du als Unternehmen abrechnest)';

  @override
  String get invoiceProformaAction => 'Proforma-Rechnung';

  @override
  String get invoicePdfProforma => 'Proforma';

  @override
  String get invoiceProformaShared => 'Proforma geteilt.';

  @override
  String get invoiceProformaNothing =>
      'Für diesen Monat wurde nichts erfasst — keine Proforma zu senden.';

  @override
  String get invoicePdfCopy => 'Kopie';

  @override
  String get invoiceStatusPartiallyPaid => 'Teilweise bezahlt';

  @override
  String get invoiceRegisterTitle => 'Rechnungsregister';

  @override
  String get invoiceRegisterDate => 'Datum';

  @override
  String get invoiceRegisterName => 'Name';

  @override
  String get invoiceRegisterAmount => 'Betrag';

  @override
  String get invoiceRegisterTotal => 'Gesamt';

  @override
  String get invoiceFacturXDownload => 'Factur-X (PDF) herunterladen';

  @override
  String get invoiceFacturXShare => 'Factur-X (PDF) teilen';

  @override
  String get invoiceFacturXExplain =>
      'Eine Datei: die Rechnung für Menschen, mit dem maschinenlesbaren XML darin. Das erwarten die meisten Plattformen.';

  @override
  String get invoiceSendAction => 'An die staatliche Plattform senden';

  @override
  String get invoiceSendAccepted =>
      'Gesendet — die Plattform hat sie angenommen.';

  @override
  String get invoiceSendCustomerAction => 'An den Dienst des Kunden senden';

  @override
  String get invoiceSendCustomerAccepted =>
      'Gesendet — der Dienst des Kunden hat sie angenommen.';

  @override
  String get einvoiceCustomerSectionTitle => 'Zustelldienst des Kunden';

  @override
  String get einvoiceCustomerSectionHelp =>
      'Wohin Rechnungen für den Kunden gehen: sein Peppol-Zugangspunkt, Portal oder die vereinbarte Upload-API — getrennt von der staatlichen Plattform.';

  @override
  String get invoiceSendRejected => 'Die Plattform hat sie abgelehnt.';

  @override
  String invoiceSentOn(String date, String status) {
    return 'Gesendet am $date · $status';
  }

  @override
  String get invoiceSendStatusAccepted => 'angenommen';

  @override
  String get invoiceSendStatusRejected => 'abgelehnt';

  @override
  String get invoiceSendStatusFailed => 'nicht übermittelt';

  @override
  String get einvoiceConfigTitle => 'E-Rechnungs-Plattform';

  @override
  String get einvoiceConfigIntro =>
      'Wohin DesKilo deine Rechnungen sendet. Jede Plattform, die einen Upload mit Token annimmt, funktioniert — eine zugelassene Plattform, ein Peppol Access Point, eine nationale Plattform. Das Token liegt serverseitig und kommt nie zurück.';

  @override
  String get einvoiceConfigEndpoint => 'Upload-URL';

  @override
  String get einvoiceConfigToken => 'Token oder Zugangsdaten';

  @override
  String get einvoiceConfigHeader => 'Auth-Header (Standard Authorization)';

  @override
  String get einvoiceConfigField => 'Feldname der Datei (Standard file)';

  @override
  String get einvoiceConfigSaved => 'Plattform gespeichert.';

  @override
  String get einvoiceConfigCleared => 'Plattform entfernt.';

  @override
  String get einvoiceConfigClear => 'Plattform entfernen';

  @override
  String get einvoiceConfigTokenSet =>
      'Ein Token ist gespeichert (neues eingeben, um es zu ersetzen).';

  @override
  String get invoiceAccountingExport => 'Buchhaltungsexport';

  @override
  String get invoiceAccountingExportEmpty =>
      'Für diesen Zeitraum gibt es nichts zu exportieren.';

  @override
  String get invoiceRegisterYear => 'Jahr';

  @override
  String get invoiceRegisterAllYears => 'Alle Jahre';

  @override
  String get invoiceExportSafT => 'SAF-T (XML, international)';

  @override
  String get invoiceExportFec => 'FEC (Frankreich, im Prüfungsfall verlangt)';

  @override
  String get invoiceExportChoose => 'Buchhaltungs-Export';

  @override
  String get fecAccountsTitle => 'Zu buchende Konten';

  @override
  String get fecAccountsIntro =>
      'Ein FEC besteht aus Buchungen und braucht daher Kontonummern. Dies sind die Standardkonten des französischen Kontenrahmens — ersetze sie durch die deiner Buchhaltung.';

  @override
  String get fecAccountCustomers => 'Kunden';

  @override
  String get fecAccountRevenue => 'Erlöse';

  @override
  String get fecAccountBank => 'Bank';

  @override
  String get fecMissingSiren =>
      'Der FEC-Dateiname enthält die Registernummer — trage sie zuerst unter Rechtliche Identität ein.';

  @override
  String get invoiceEInvoiceStaleIdentity =>
      'Ihre rechtliche Identität ist jetzt vollständig, diese Rechnung wurde aber vorher signiert und behält, womit sie ausgestellt wurde. Als fehlerhaft markieren und eine Ersatzrechnung ausstellen, damit sie die neue Identität trägt.';

  @override
  String get einvoiceConfigUnavailable =>
      'Die Plattform-Einstellungen konnten nicht geladen werden. Verbindung prüfen und erneut versuchen.';

  @override
  String get einvoiceEnvTitle => 'An welche Plattform senden?';

  @override
  String get einvoiceEnvProd => 'Produktion';

  @override
  String get einvoiceEnvUat => 'UAT (Testplattform)';

  @override
  String get einvoiceEnvDev => 'Dev (Testplattform)';

  @override
  String get einvoiceEnvProdHint => 'Die echte Übermittlung.';

  @override
  String get einvoiceEnvTestHint =>
      'Eine Probe — als Testversand protokolliert.';

  @override
  String invoiceSendAcceptedTest(String env) {
    return 'Testversand angenommen ($env).';
  }

  @override
  String get einvoiceTestEnvsTitle => 'Testumgebungen (UAT / Dev)';

  @override
  String get einvoiceTestEnvsHelp =>
      'Eigene Endpunkte und Token für Proben. Die Auswahl erscheint beim Senden nur bei aktivem Entwicklermodus.';

  @override
  String get einvoiceUatEndpoint => 'UAT-Upload-URL';

  @override
  String get einvoiceUatToken => 'UAT-Token oder Zugangsdaten';

  @override
  String get einvoiceDevEndpoint => 'Dev-Upload-URL';

  @override
  String get einvoiceDevToken => 'Dev-Token oder Zugangsdaten';

  @override
  String get invoiceSentTestChip => 'Test';

  @override
  String get invoiceTemplateTitle => 'Rechnungs-PDF-Vorlage';

  @override
  String get invoiceTemplateHint =>
      'Drei Berichtsbänder auf dem PDF — das E-Rechnungs-XML bleibt unangetastet. Liquid-Bedingungen und -Schleifen, dann Zeilen-Markup:';

  @override
  String get invoiceTemplateIntroLabel =>
      'Einleitung (über dem Empfängerblock)';

  @override
  String get invoiceTemplateFooterLabel =>
      'Fußtext (unter den Summen — Zahlungsbedingungen, Pflichtangaben)';

  @override
  String get invoiceTemplateSaved => 'Rechnungsvorlage gespeichert.';

  @override
  String get invoiceTemplateHeaderLabel => 'Kopfband';

  @override
  String get invoiceTemplateBodyLabel => 'Rumpfband (die Rechnungszeilen)';

  @override
  String get invoiceTemplateReset => 'Auf Standard zurücksetzen';

  @override
  String get invoiceTemplatePreview => 'Vorschau';

  @override
  String get invoiceTemplateNoPreview =>
      'Stelle zuerst eine Rechnung aus — die Vorschau rendert die neueste.';

  @override
  String get reminderPdfTitleFriendly => 'Zahlungserinnerung';

  @override
  String get reminderPdfTitleFirm => 'Mahnung';

  @override
  String get reminderPdfOpeningFriendly =>
      'dies ist eine freundliche Erinnerung: die untenstehende Rechnung ist noch offen. Sicher nur übersehen — kein Problem.';

  @override
  String get reminderPdfOpeningFirm =>
      'trotz unserer vorherigen Mahnung ist die untenstehende Rechnung weiterhin unbezahlt. Bitte begleichen Sie den Betrag umgehend.';

  @override
  String get reminderPdfDaysOpen => 'Offen seit';

  @override
  String get reminderPdfDays => 'Tagen';

  @override
  String get reminderPdfLevelLabel => 'Mahnstufe';

  @override
  String get reminderPdfClosing =>
      'Sollten Sie bereits gezahlt haben, betrachten Sie dieses Schreiben bitte als gegenstandslos.';

  @override
  String get dunningSettingsTitle => 'Mahnregeln';

  @override
  String get dunningLevels => 'Anzahl der Mahnstufen';

  @override
  String get dunningFirstAfterDays => 'Tage bis zur ersten Erinnerung';

  @override
  String get dunningBetweenDays => 'Tage zwischen den Mahnungen';

  @override
  String get dunningSaved => 'Mahnregeln gespeichert.';

  @override
  String dunningDueChip(int level) {
    return 'Mahnstufe $level fällig';
  }

  @override
  String get invoiceTemplateDocInvoice => 'Rechnung';

  @override
  String invoiceTemplateDocReminder(int level) {
    return 'Mahnung $level';
  }

  @override
  String get reportPreviewTitle => 'Schnellvorschau — deine neueste Rechnung';

  @override
  String get reportPreviewSimulated => 'Schnellvorschau — Beispieldaten';

  @override
  String get reportPresetClassic => 'Klassisch';

  @override
  String get reportPresetFormalLetter => 'Formeller Brief';

  @override
  String get reportSubject => 'Betreff';

  @override
  String get reportRegards => 'Mit freundlichen Grüßen';

  @override
  String get invoiceTemplatePresets => 'Vorlagen';

  @override
  String get invoiceTemplateQuickPreview => 'Schnellvorschau';

  @override
  String get invoiceTemplateDownload => 'PDF herunterladen';

  @override
  String get invoiceTemplateShare => 'PDF teilen';

  @override
  String get invoiceTemplateDocStatement => 'Abrechnung';

  @override
  String get reportPresetSimple => 'Einfach';

  @override
  String get reportPresetVerbose => 'Ausführlich';

  @override
  String get invoiceLegalSection => 'Rechnungsangaben';

  @override
  String get invoiceLegalIntro =>
      'Die Pflichtangaben auf Rechnungen und Mahnungen. Leere Zahlungsklauseln verwenden die gesetzlichen Standardtexte.';

  @override
  String get invoiceLegalFormField => 'Rechtsform & Kapital';

  @override
  String get invoiceLegalFormHint => 'z. B. SARL au capital de 7 500 €';

  @override
  String get invoiceLegalRegistrationField => 'Handelsregister';

  @override
  String get invoiceLegalRegistrationHint =>
      'z. B. RCS Saint-Brieuc 680 357 910';

  @override
  String get invoiceLegalPaymentTermsField => 'Zahlungsbedingungen';

  @override
  String get invoiceLegalLatePenaltyField => 'Verzugszinsen';

  @override
  String get invoiceLegalRecoveryField => 'Pauschale für Beitreibungskosten';

  @override
  String get invoiceLegalEscompteField => 'Skonto';

  @override
  String get invoiceLegalInsuranceField => 'Berufshaftpflicht';

  @override
  String get invoiceLegalSpecialField => 'Besondere Angaben';

  @override
  String get invoiceLegalPaymentTermsDefault => 'Zahlbar sofort nach Erhalt.';

  @override
  String get invoiceLegalLatePenaltyDefault =>
      'Verzugszinsen: dreifacher gesetzlicher Zinssatz.';

  @override
  String get invoiceLegalRecoveryDefault =>
      'Pauschale für Beitreibungskosten: 40 €.';

  @override
  String get invoiceLegalEscompteDefault =>
      'Kein Skonto bei vorzeitiger Zahlung.';

  @override
  String get reportColUnitPrice => 'Einzelpreis';

  @override
  String get reportColQty => 'Menge';

  @override
  String get reportColTotal => 'Gesamt';

  @override
  String get invoiceLegalKindField => 'Organisationsform';

  @override
  String get invoiceLegalKindCompany => 'Unternehmen';

  @override
  String get invoiceLegalKindAssociation => 'Verein (gemeinnützig)';

  @override
  String get invoiceLegalAssociationHint =>
      'Verzugszins-, Beitreibungs- und Skonto-Klauseln werden nur gedruckt, wenn ausgefüllt — sie sind nur zwischen Unternehmen Pflicht.';

  @override
  String get invoiceLegalFormHintAssociation =>
      'z. B. Association loi 1901 / e. V.';

  @override
  String get invoiceLegalRegistrationHintAssociation =>
      'z. B. RNA W123456789 · SIRET falls vergeben';

  @override
  String get invoiceLegalAssociationReasonHint =>
      'z. B. „TVA non applicable, art. 293 B du CGI“ — oder „Exonération de TVA, art. 261, 7-1° du CGI“ für Leistungen an Mitglieder';

  @override
  String get reportEditorMarkup => 'Markup';

  @override
  String get reportEditorVisual => 'Visuell';

  @override
  String get reportInsertImage => 'Bild einfügen';

  @override
  String get reportImagesTitle => 'Berichtsbilder';

  @override
  String get reportImagesEmpty =>
      'Noch kein Bild — laden Sie Ihr Logo, einen Stempel oder eine Unterschrift hoch und referenzieren Sie es mit ![name].';

  @override
  String get reportImageUpload => 'Bild hochladen';

  @override
  String get reportVisualAddLine => 'Zeile hinzufügen';

  @override
  String get reportLineTitle => 'Titel';

  @override
  String get reportLineSection => 'Abschnitt';

  @override
  String get reportLineText => 'Text';

  @override
  String get reportLineSmall => 'Kleingedrucktes';

  @override
  String get reportLineRow => 'Tabellenzeile';

  @override
  String get reportLineBoldRow => 'Fette Zeile';

  @override
  String get reportLineDivider => 'Trenner';

  @override
  String get reportLineSpacer => 'Abstand';

  @override
  String get reportLineImage => 'Bild';

  @override
  String get reportLineColumns => 'Spalten Anfang/Ende';

  @override
  String get reportLineColumnsSplit => 'Spaltenumbruch';

  @override
  String get reportLineLogic => 'Logik';

  @override
  String get reportDocAgreement => 'Finanzvereinbarung';

  @override
  String get reportDocPayments => 'Zahlungsbericht';

  @override
  String get reportDocWorkspace => 'Arbeitsbereichsbericht';

  @override
  String get agreementExtraHalfDay => 'Zusätzlicher halber Tag';

  @override
  String get paymentsPendingTag => 'wartet auf Validierung';

  @override
  String get reportSectionFeatures => 'Funktionen';

  @override
  String get reportSectionPrices => 'Preise';

  @override
  String get moneyMyAgreement => 'Meine Konditionen';

  @override
  String get memberSendAgreement => 'Finanzvereinbarung senden';

  @override
  String get reportQuickView => 'Schnellansicht';

  @override
  String get reportDocWorkspaceSubtitle =>
      'Alles über den Arbeitsbereich — über die Arbeitsbereichsvorlage des Berichtseditors';

  @override
  String get reportTemplateLangDefault => 'Standard (alle Sprachen)';

  @override
  String get reportLanguageAmbiguous =>
      'Dieses Land hat mehrere Sprachen — legen Sie zuerst die Arbeitsbereichssprache in den Einstellungen fest.';

  @override
  String get reportDesignEmpty =>
      'Leeres Band — fügen Sie unten ein Element hinzu.';

  @override
  String get invoiceStatusRemainderCancelled =>
      'Teilweise bezahlt · Restbetrag storniert';

  @override
  String get invoiceRemainingLabel => 'Restbetrag';

  @override
  String get invoiceWriteoffButton => 'Restbetrag stornieren';

  @override
  String get invoiceWriteoffExplain =>
      'Der offene Restbetrag dieser Rechnung wird storniert und die Rechnung als teilweise bezahlt archiviert — sobald die Validierung bestätigt. Bis dahin bleibt sie offen und geschuldet.';

  @override
  String get invoiceWriteoffRequested =>
      'Stornierung beantragt — wartet auf Validierung.';

  @override
  String get eventTypeInvoiceWriteoff => 'Restbetrag-Stornierung';

  @override
  String eventInvoiceWriteoffLine(String actor, String number, String amount) {
    return '$actor bittet um Stornierung des Restbetrags von $number — $amount';
  }

  @override
  String get invoicePdfCreditNote => 'Gutschrift';

  @override
  String get invoiceStatusRefunded => 'Erstattet';

  @override
  String get invoiceRefundLabel => 'Zu erstatten';

  @override
  String get invoiceRefundButton => 'Erstattung erfassen';

  @override
  String invoiceRefundExplain(String amount) {
    return 'Diese Gutschrift bedeutet: der ARBEITSBEREICH schuldet dem Mitglied $amount. Erfassen Sie die ausgezahlte Erstattung — der Betrag wird gegen das Mitgliedskonto gebucht und das Dokument schließt als Erstattet.';
  }

  @override
  String get invoiceRefunded => 'Erstattung erfasst.';

  @override
  String invoiceSummaryToRefund(int count, String amount) {
    return '$count zu erstatten · $amount';
  }

  @override
  String get eventTypeInvoiceReminder => 'Zahlungserinnerung';

  @override
  String eventInvoiceReminderLine(String number, int level, String amount) {
    return 'Mahnstufe $level: Rechnung $number — $amount noch offen';
  }

  @override
  String get dunningAutomatic => 'Automatische Mahnungen';

  @override
  String get dunningAutomaticHint =>
      'Einmal täglich erhalten offene Rechnungen nach Ablauf der Frist von selbst ihre nächste Mahnstufe — ein Hinweis im Feed des Mitglieds und eine Push-Nachricht. Aus: Sie senden jede Mahnung selbst.';

  @override
  String get eventTypePriceNegotiation => 'Preisverhandlung';

  @override
  String eventPriceNegotiationLine(String actor, String member, String terms) {
    return '$actor schlägt Konditionen für $member vor: $terms';
  }

  @override
  String eventPriceNegotiationItems(int count) {
    return '$count Artikel';
  }

  @override
  String get journeyStepIssued => 'Ausgestellt';

  @override
  String get journeyStepPayment => 'Zahlung';

  @override
  String get journeyStepConfirmation => 'Bestätigung';

  @override
  String get journeyStepClosed => 'Abgeschlossen';

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
  String journeyIssuerAdminConfirms(String name, String amount) {
    return '$name hat eine Zahlung von $amount gemeldet — ein anderer Admin bestätigt sie unter Ereignisse';
  }

  @override
  String journeyIssuerMemberConfirms(String name, String amount) {
    return 'Eine Zahlung von $amount wurde erfasst — $name bestätigt sie unter Ereignisse';
  }

  @override
  String journeyIssuerMatches(String amount) {
    return 'Eine Zahlung von $amount ist verbucht — ordnen Sie sie dieser Rechnung zu';
  }

  @override
  String get journeyValidatorsMatch =>
      'Zahlung zugeordnet — Entscheidung der Prüfer steht aus';

  @override
  String get journeyValidatorsWriteoff =>
      'Ausbuchung des Restbetrags beantragt — Prüfer entscheiden';

  @override
  String journeyIssuerRefunds(String name, String amount) {
    return 'Gutschrift — $amount an $name erstatten und erfassen';
  }

  @override
  String get journeyIssuerReplaces => 'Storniert — Ersatzrechnung ausstellen';

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
  String journeyMemberDeclared(String amount) {
    return 'Sie haben $amount gemeldet — der Space bestätigt es';
  }

  @override
  String journeyMemberConfirms(String amount) {
    return 'Sie sind dran: die für Sie erfasste Zahlung von $amount unter Ereignisse bestätigen';
  }

  @override
  String journeyMemberRegistered(String amount) {
    return 'Ihre Zahlung von $amount ist verbucht — der Space ordnet sie dieser Rechnung zu';
  }

  @override
  String get journeyMemberValidators =>
      'Zahlung zugeordnet — Validierung steht aus';

  @override
  String get journeyMemberWriteoff =>
      'Der Space hat die Ausbuchung des Restbetrags beantragt — Validierung steht aus';

  @override
  String journeyMemberRefund(String amount) {
    return 'Der Space schuldet Ihnen $amount — nichts zu zahlen';
  }

  @override
  String get journeyMemberReplaces => 'Storniert — eine Ersatzrechnung folgt';

  @override
  String journeyClosedPaid(String date) {
    return 'Bezahlt am $date — abgeschlossen';
  }

  @override
  String journeyClosedRemainder(String date) {
    return 'Abgeschlossen — Restbetrag am $date ausgebucht';
  }

  @override
  String journeyClosedRefunded(String date) {
    return 'Erstattet am $date — abgeschlossen';
  }

  @override
  String journeyClosedReplaced(String number) {
    return 'Storniert — ersetzt durch $number';
  }

  @override
  String get journeyClosedSettled =>
      'In eine andere Rechnung zusammengefasst — diese wird geschuldet und angemahnt';

  @override
  String get journeyStageIssue => 'Auszustellen';

  @override
  String get journeyStageCollect => 'Einzuziehen';

  @override
  String get journeyStageConfirm => 'Zu bestätigen';

  @override
  String get journeyStageClosed => 'Abgeschlossen';

  @override
  String journeyOverdueCount(int count) {
    return '$count überfällig';
  }

  @override
  String get journeyStageStripLabel =>
      'Der Fakturierungsprozess: ausstellen, einziehen, bestätigen, abschließen';

  @override
  String get journeyHowButton => 'So funktioniert es';

  @override
  String get journeyHowTitle => 'So funktioniert die Fakturierung';

  @override
  String get journeyHowIntro =>
      'Vier Schritte, für jede Rechnung dieselben. Jeder sagt, wer am Zug ist.';

  @override
  String get journeyHowWorkspaceLabel => 'Space';

  @override
  String get journeyHowMemberLabel => 'Mitglied';

  @override
  String get journeyHowIssuedWorkspace =>
      'Stellt die Rechnung aus den erfassten Monatsdaten aus — nummeriert, signiert, unveränderlich — und teilt das PDF oder sendet die E-Rechnung.';

  @override
  String get journeyHowIssuedMember =>
      'Findet sie in der Ansicht Rechnungen: Positionen, Saldo, Fälligkeit.';

  @override
  String get journeyHowPaymentWorkspace =>
      'Wartet auf das Geld. Nach der Frist sendet er die konfigurierten Mahnstufen — von Hand oder automatisch.';

  @override
  String get journeyHowPaymentMember =>
      'Zahlt online (sofort beglichen) oder per Überweisung und erfasst dann die Zahlung, damit der Space Bescheid weiß.';

  @override
  String get journeyHowConfirmationWorkspace =>
      'Ein anderer Admin bestätigt die gemeldete Zahlung; der Aussteller ordnet die verbuchte Zahlung dann der Rechnung zu (Als bezahlt markieren) — eine Validierungsregel kann die Zuordnung den Prüfern übergeben. Zu viel gezahlt? Eine Gutschrift. Zu wenig? Teilweise bezahlt, der Rest bleibt geschuldet bis zur Zahlung oder Ausbuchung.';

  @override
  String get journeyHowConfirmationMember =>
      'Nichts zu tun — außer der Space hat die Zahlung für das Mitglied erfasst: dann bestätigt es sie unter Ereignisse.';

  @override
  String get journeyHowClosedWorkspace =>
      'Bezahlt, Restbetrag ausgebucht oder erstattet: die Rechnung wandert ins Archiv. Eine falsche Rechnung wird als fehlerhaft markiert und ersetzt — vor der Zahlung, nie danach.';

  @override
  String get journeyHowClosedMember =>
      'Der Monat gilt als beglichen und die Rechnung bleibt für immer lesbar: Schnellansicht, PDF, Teilen.';

  @override
  String get journeyTimelineTitle => 'Verlauf';

  @override
  String journeyPrimaryRemind(int level) {
    return 'Mahnung $level senden';
  }

  @override
  String get journeyPrimaryConfirmInEvents => 'Ereignisse öffnen';

  @override
  String journeyOutstanding(String amount) {
    return '$amount offen';
  }

  @override
  String get reportEditorTitle => 'Berichtseditor';

  @override
  String get reportDesignerUndo => 'Rückgängig';

  @override
  String get reportDesignerRedo => 'Wiederholen';

  @override
  String get reportDesignerDiscardTitle => 'Ohne Speichern verlassen?';

  @override
  String get reportDesignerDiscardBody =>
      'Ihre Änderungen an den Vorlagen sind nicht gespeichert.';

  @override
  String get reportDesignerDiscard => 'Verwerfen';

  @override
  String get reportDesignerKeepEditing => 'Weiter bearbeiten';

  @override
  String get reportDesignerReplaceTitle => 'Aktuelles Layout ersetzen?';

  @override
  String get reportDesignerReplaceBody =>
      'Die Bänder dieses Dokuments werden ersetzt. Rückgängig holt sie zurück.';

  @override
  String get reportDesignerReplace => 'Ersetzen';

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
  String reportDesignerError(String message) {
    return 'Die Vorlage lässt sich nicht erzeugen — $message';
  }

  @override
  String get reportDesignerInsert => 'Element einfügen';

  @override
  String get reportDesignerFields => 'Felder';

  @override
  String get reportDesignerFieldsSearch => 'Feld suchen';

  @override
  String get reportDesignerMoveTo => 'In Band verschieben';

  @override
  String get reportDesignerDrag => 'Ziehen zum Umsortieren';

  @override
  String get reportImageSize => 'Größe';

  @override
  String get reportImageSizeSmall => 'Klein';

  @override
  String get reportImageSizeMedium => 'Mittel';

  @override
  String get reportImageSizeLarge => 'Groß';

  @override
  String get reportImageAlign => 'Ausrichtung';

  @override
  String get reportImageAlignLeft => 'Links';

  @override
  String get reportImageAlignCenter => 'Mitte';

  @override
  String get reportImageAlignRight => 'Rechts';

  @override
  String get reportTemplateLangOverridden => 'Eigene Vorlage';

  @override
  String get reportTemplateLangInherits => 'Erbt den Standard';

  @override
  String get reportTemplateClearOverlay =>
      'Für diese Sprache den Standard verwenden';

  @override
  String get reportDocCoa => 'Kontenrahmen';

  @override
  String get reportDocBadges => 'Mitgliedsausweise';

  @override
  String get reportDocSpaceCodes => 'QR-Karten der Plätze';

  @override
  String get reportFieldGroupDocument => 'Dokument';

  @override
  String get reportFieldGroupMember => 'Mitglied & Workspace';

  @override
  String get reportFieldGroupMoney => 'Beträge';

  @override
  String get reportFieldGroupLegal => 'Pflichtangaben';

  @override
  String get reportFieldGroupLoops => 'Schleifen Positionen & MwSt.';

  @override
  String get reportDesignerSideBySide => 'Entwurf und Vorschau nebeneinander';

  @override
  String get wizardTitle => 'Rechnungsassistent';

  @override
  String get invoiceWizardAction => 'Monatsabschluss-Assistent';

  @override
  String get wizardCardHint =>
      'Ausstellen, versenden, mahnen, Zahlungen erfassen und bestätigen, zuordnen und abschließen — ein geführter Prozess.';

  @override
  String get wizardRunStart => 'Monatsanfang';

  @override
  String get wizardRunEnd => 'Monatsende';

  @override
  String get wizardRunStartHint =>
      'Die im Voraus bezahlten Abonnements: für den kommenden Monat ausstellen, versenden, Mahnungen planen — dann die Zahlungsseite.';

  @override
  String get wizardRunEndHint =>
      'Was der abgelaufene Monat gekostet hat: Nutzung, Verbrauch und Zusatzkosten. Ausstellen, versenden, mahnen — dann Zahlungen erfassen, bestätigen und zuordnen, und abschließen.';

  @override
  String get wizardStepReview => 'Prüfen';

  @override
  String get wizardStepIssue => 'Ausstellen';

  @override
  String get wizardStepSend => 'Versenden';

  @override
  String get wizardStepRemind => 'Mahnen';

  @override
  String get wizardStepPayments => 'Zahlungen';

  @override
  String get wizardStepMatch => 'Zuordnen';

  @override
  String get wizardStepClose => 'Abschließen';

  @override
  String get wizardStepSummary => 'Zusammenfassung';

  @override
  String get wizardNext => 'Weiter';

  @override
  String get wizardBack => 'Zurück';

  @override
  String get wizardFinish => 'Fertig';

  @override
  String get wizardReviewToIssue => 'Auszustellen';

  @override
  String get wizardReviewIssued => 'Bereits ausgestellt';

  @override
  String get wizardReviewOpen => 'Offene Rechnungen';

  @override
  String get wizardReviewOverdue => 'Fällige Mahnungen';

  @override
  String get wizardReviewPending => 'Zu bestätigende Zahlungen';

  @override
  String wizardPeriodLabel(String period) {
    return 'Zeitraum: $period';
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
  String get wizardSendHint =>
      'Jede Rechnung an ihr Mitglied übergeben — das PDF teilen oder herunterladen und auf eigenem Weg senden.';

  @override
  String get wizardSendNone => 'Noch keine Rechnung dieses Laufs zu versenden.';

  @override
  String get wizardSendShare => 'PDF teilen';

  @override
  String get wizardSendDownload => 'PDF herunterladen';

  @override
  String get wizardRemindHint =>
      'Überfällig nach Ihren Mahnregeln. Ein Tipp erfasst jede Mahnung und benachrichtigt die Mitglieder; der Brief öffnet sich je Zeile.';

  @override
  String get wizardRemindNone => 'Nach Ihren Regeln ist keine Mahnung fällig.';

  @override
  String wizardRemindLevel(int level) {
    return 'Mahnung $level';
  }

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
  String get wizardRemindOne => 'Mahnbrief';

  @override
  String get wizardPaymentsHint =>
      'Was Mitglieder gemeldet haben, wartet unten auf Ihre Bestätigung. Eine Zahlung, die ohne Meldung auf dem Konto eintraf, wird hier erfasst — das Mitglied bestätigt sie dann.';

  @override
  String get wizardPaymentsNone => 'Keine gemeldete Zahlung wartet auf Sie.';

  @override
  String get wizardPaymentAccept => 'Bestätigen';

  @override
  String get wizardPaymentReject => 'Ablehnen';

  @override
  String get wizardMatchHint =>
      'Eine Rechnung ist bezahlt, sobald eine echte Zahlung zugeordnet ist. Zeilen mit Guthaben auf dem Mitgliedskonto sind bereit.';

  @override
  String get wizardMatchNone => 'Jede Rechnung ist bezahlt oder abgeschlossen.';

  @override
  String get wizardMatchPending => 'Wartet auf Bestätigung';

  @override
  String wizardMatchCredit(String amount) {
    return 'Verfügbares Guthaben: $amount';
  }

  @override
  String get wizardMatchNoCredit => 'Noch keine Zahlung auf dem Konto';

  @override
  String get wizardMatchAction => 'Zuordnen';

  @override
  String get wizardCloseHint =>
      'Ein Mitglied mit mehreren offenen Rechnungen kann EINE bezahlen; bei einer teilweise bezahlten kann der Rest abgeschrieben werden; eine Gutschrift wird erstattet. Jedes läuft über die Bestätigung.';

  @override
  String get wizardCloseNone =>
      'Nichts zusammenzufassen, abzuschreiben oder zu erstatten.';

  @override
  String wizardSettle(int count) {
    return '$count zusammenfassen';
  }

  @override
  String get wizardWriteoff => 'Abschreiben';

  @override
  String get wizardRefund => 'Erstatten';

  @override
  String get wizardSummaryHint => 'Was dieser Lauf getan hat';

  @override
  String get wizardTallyIssued => 'Ausgestellte Rechnungen';

  @override
  String get wizardTallyShared => 'Geteilte oder heruntergeladene PDFs';

  @override
  String get wizardTallyReminded => 'Gesendete Mahnungen';

  @override
  String get wizardTallyDecided => 'Bestätigte oder abgelehnte Zahlungen';

  @override
  String get wizardTallyRegistered => 'Erfasste Zahlungen';

  @override
  String get wizardTallyMatched => 'Zugeordnete Rechnungen';

  @override
  String get wizardTallySettled => 'Zusammenfassungen';

  @override
  String get wizardTallyWriteoffs => 'Beantragte Abschreibungen';

  @override
  String get wizardTallyRefunds => 'Erstattungen';

  @override
  String get wizardTallyNothing => 'Nichts wurde geändert.';

  @override
  String get wizardTodoHeading => 'Noch offen — wer ist am Zug';

  @override
  String get wizardTodoNone => 'Nichts mehr offen.';

  @override
  String get wizardWhoYou => 'Sie';

  @override
  String get wizardWhoValidators => 'Prüfer';

  @override
  String get registerPaymentTitle => 'Zahlung erfassen';

  @override
  String get registerPaymentHint =>
      'Eine Zahlung, die beim Workspace eingegangen ist — das Mitglied bestätigt sie, dann kann sie einer Rechnung zugeordnet werden.';

  @override
  String get registerPaymentMember => 'Mitglied';

  @override
  String get registerPaymentAmount => 'Betrag';

  @override
  String get registerPaymentMethod => 'Zahlungsart';

  @override
  String get registerPaymentDate => 'Bezahlt am';

  @override
  String get registerPaymentNote => 'Notiz';

  @override
  String get registerPaymentSubmit => 'Erfassen';

  @override
  String get registerPaymentDone =>
      'Zahlung erfasst — das Mitglied bestätigt sie von seiner Seite.';

  @override
  String get repartitionAction => 'Ausgabe verteilen';

  @override
  String get repartitionTitle => 'Ausgabe verteilen';

  @override
  String get repartitionHint =>
      'Verteilen Sie gemeinsame Kosten auf die Mitglieder. Die Anteile werden Positionen der nächsten Nutzungsrechnung jedes Mitglieds; eine Umkehrung gibt das Geld als Gutschriften zurück.';

  @override
  String get repartitionTitleField => 'Wofür';

  @override
  String get repartitionAmount => 'Gesamtbetrag';

  @override
  String get repartitionReverse => 'Umkehrung — als Gutschriften zurückgeben';

  @override
  String get repartitionMethod => 'Verteilen nach';

  @override
  String get repartitionMethodEqual => 'Gleich';

  @override
  String get repartitionMethodSubscription => 'Abonnement';

  @override
  String get repartitionMethodUsage => 'Nutzung';

  @override
  String get repartitionMethodCustom => 'Eigener Schlüssel';

  @override
  String get repartitionPeriod => 'Gebucht auf';

  @override
  String get repartitionWeight => 'Schlüssel';

  @override
  String get repartitionPreview => 'Anteile';

  @override
  String get repartitionNoShares =>
      'Niemand trägt einen Anteil — prüfen Sie den Schlüssel.';

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
  String get repartitionSubmit => 'Anteile buchen';

  @override
  String get repartitionFiled =>
      'Anteile gebucht — sie erscheinen auf der nächsten Nutzungsrechnung.';

  @override
  String get repartitionFiledPending =>
      'Anteile eingereicht — sie werden nach der Bestätigung gebucht.';

  @override
  String get repartitionHistory => 'Verteilungen';

  @override
  String get repartitionHistoryEmpty => 'Noch keine Verteilung.';

  @override
  String get repartitionStatusPending => 'Wartet auf Bestätigung';

  @override
  String get repartitionStatusConfirmed => 'Gebucht';

  @override
  String get repartitionStatusRejected => 'Abgelehnt';

  @override
  String get repartitionStatusExpired => 'Abgelaufen';

  @override
  String get reportDesignFileTypeLabel => 'JSON';

  @override
  String get reportDesignExport => 'Diese Vorlage exportieren';

  @override
  String get reportDesignImport => 'Vorlage importieren';

  @override
  String get reportDesignImported =>
      'Vorlage importiert. Zum Behalten speichern.';

  @override
  String get reportDesignErrorMalformed =>
      'Diese Datei ist kein lesbares JSON.';

  @override
  String get reportDesignErrorNotADesign =>
      'Diese Datei ist keine DesKilo-Berichtsvorlage.';

  @override
  String get reportDesignErrorVersion =>
      'Diese Vorlage stammt aus einer neueren DesKilo-Version.';

  @override
  String get reportDesignErrorUnknownKind =>
      'Diese Vorlage gehört zu einem Bericht, den dieser Space nicht hat.';

  @override
  String get reportDesignErrorWrongKind =>
      'Diese Vorlage gehört zu einem anderen Bericht. Öffnen Sie diesen und importieren Sie sie dort.';

  @override
  String get reportDesignErrorInvalidDesign =>
      'Diese Datei enthält keine lesbare Vorlage.';

  @override
  String get eventTypeMemberJoin => 'Neues Mitglied';

  @override
  String get memberStatusPending => 'Ausstehend';

  @override
  String get pendingApprovalTitle => 'Warten auf Freigabe';

  @override
  String pendingApprovalBody(String workspace) {
    return 'Du bist $workspace beigetreten. Ein Admin muss deine Mitgliedschaft bestätigen, bevor du den Workspace nutzen kannst — du erhältst Zugriff, sobald sie bestätigt ist.';
  }

  @override
  String get pendingApprovalRefresh => 'Erneut prüfen';

  @override
  String get memberApprove => 'Mitgliedschaft bestätigen';

  @override
  String get memberRejectJoin => 'Mitgliedschaft ablehnen';

  @override
  String get workspaceConfigInvitations => 'Einladungen';

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
  String get memberKioskLabel => 'Kiosk';

  @override
  String get memberMakeKiosk => 'Zum Kiosk-Gerät machen';

  @override
  String get memberUnmakeKiosk => 'Kiosk zu Mitglied zurücksetzen';

  @override
  String get memberBadgesTooltip => 'Badges';

  @override
  String memberBadgesTitle(String name) {
    return 'Badges — $name';
  }

  @override
  String get badgeIssue => 'Neuer Badge';

  @override
  String get badgeTokenOnce =>
      'Speichere diesen QR jetzt — er wird nur einmal angezeigt.';

  @override
  String get badgeNone => 'Noch keine Badges.';

  @override
  String get badgeDefaultLabel => 'Badge';

  @override
  String get badgeRevoke => 'Widerrufen';

  @override
  String get badgeRevoked => 'Widerrufen';

  @override
  String get commonClose => 'Schließen';

  @override
  String get kioskCheckIn => 'Einchecken';

  @override
  String get kioskReserve => 'Reservieren';

  @override
  String get kioskCheckOut => 'Auschecken';

  @override
  String get kioskPresentBadge => 'Badge vorzeigen';

  @override
  String get kioskBadgeHint =>
      'Scanne den QR deines Badges oder tippe seinen Code ein.';

  @override
  String get kioskBadgeFieldLabel => 'Badge-Code';

  @override
  String get kioskBadgeConfirm => 'Bestätigen';

  @override
  String get kioskBadgeRejected => 'Badge nicht erkannt.';

  @override
  String get kioskDone => 'Fertig — alles erledigt.';

  @override
  String get kioskTapHint => 'Tippe einen Platz zum Einchecken';

  @override
  String get badgeSavePdf => 'Als PDF speichern';

  @override
  String get badgeRegisterCard => 'Karte registrieren';

  @override
  String get badgeTapCardTitle => 'Karte registrieren';

  @override
  String get badgeTapCardHint =>
      'Halte die RFID/NFC-Karte an die Rückseite des Geräts.';

  @override
  String get badgeCardRegistered => 'Karte registriert.';

  @override
  String get badgeCardAlreadyRegistered =>
      'Diese Karte ist bereits registriert.';

  @override
  String get kioskBadgeHintNfc =>
      'Karte auflegen, QR scannen oder Code eintippen.';

  @override
  String get nfcConfigTitle => 'RFID-/NFC-Badges';

  @override
  String get nfcConfigIntro =>
      'Mitglieder checken an einem Wandtablet per RFID/NFC-Karte ein. Registriere die Karte jedes Mitglieds unter Mitglieder & Tarife; am Kiosk halten sie die Karte an, um zu reservieren oder einzuchecken.';

  @override
  String get nfcConfigEnable => 'NFC-Badge-Check-in aktivieren';

  @override
  String get nfcConfigEnableDesc =>
      'Zeigt die Karten-Antipp-Option an Kiosken und im Badge-Manager.';

  @override
  String get nfcConfigDeviceStatus => 'Dieses Gerät';

  @override
  String get nfcConfigChecking => 'Prüfe…';

  @override
  String get nfcConfigDeviceReady => 'NFC verfügbar und aktiviert';

  @override
  String get nfcConfigDeviceUnavailable =>
      'Hier kein NFC — ein Android-Gerät mit aktiviertem NFC ist nötig (iPads haben kein NFC). QR-Badges funktionieren weiter.';

  @override
  String get kioskConfirmAction => 'Bestätigen';

  @override
  String get kioskRejectAction => 'Ablehnen';

  @override
  String get kioskGateTitle => 'Kiosk-Modus starten?';

  @override
  String get kioskGateBody =>
      'Dieses Konto ist als Kiosk des Workspace eingerichtet. Im Kiosk-Modus zeigt das Tablet nur den Raumplan für das Einchecken per Badge — sonst lässt sich nichts öffnen. Zum Verlassen des Kiosk-Modus das Tablet neu starten.';

  @override
  String get kioskGateStart => 'Kiosk-Modus starten';

  @override
  String get kioskGateReject => 'Jetzt nicht — App normal öffnen';

  @override
  String get settingsFrontCamera => 'Mit der Frontkamera scannen';

  @override
  String get settingsFrontCameraDesc =>
      'Badges werden mit der Kamera auf der Bildschirmseite gelesen — ausschalten für die Rückkamera.';

  @override
  String get kioskNfcOff =>
      'NFC ist in den Android-Einstellungen dieses Tablets ausgeschaltet — zum Lesen von RFID-Karten einschalten.';

  @override
  String get kioskNfcUnsupported =>
      'Dieses Tablet hat keinen NFC-Leser — stattdessen den QR-Badge scannen.';

  @override
  String get kioskNfcFailed =>
      'Der RFID-Leser ist nicht gestartet — App neu starten und erneut versuchen.';

  @override
  String get nfcConfigDeviceOff =>
      'NFC ist in den Android-Einstellungen dieses Geräts ausgeschaltet — zum Lesen von RFID-Karten einschalten.';

  @override
  String get kioskScanQr => 'QR-Badge scannen';

  @override
  String get kioskRevertTitle => 'Kiosk-Gerät';

  @override
  String get kioskRevertDesc =>
      'Dieses Profil ist als Kiosk des Workspace eingerichtet. Als reguläres Mitglied zurücksetzen, damit die Kiosk-Frage beim Start nicht mehr erscheint.';

  @override
  String get kioskRevertDone =>
      'Dieses Profil ist wieder ein reguläres Mitglied.';

  @override
  String get memberNoActions =>
      'Nur der Inhaber des Workspace kann dieses Mitglied ändern.';

  @override
  String get kioskNotCheckedIn =>
      'Kein aktiver Check-in gefunden — der Plan hat sich womöglich gerade aktualisiert.';

  @override
  String get kioskRestOfDay => 'Rest des Tages';

  @override
  String get kioskPeriodCheckInHint =>
      'Bis wann bleibst du? Das Einchecken beginnt jetzt.';

  @override
  String get kioskPeriodReserveHint => 'Wähle den Zeitraum — nur heute.';

  @override
  String get kioskCheckInRightAway => 'Sofort einchecken';

  @override
  String get kioskCheckInRightAwayHint =>
      'Du bist da — die Reservierung startet eingecheckt.';

  @override
  String get kioskPresentBadgeNext => 'Badge vorzeigen';

  @override
  String get kioskReserveAndCheckIn => 'Reservieren & einchecken';

  @override
  String get badgeDeleteConfirm =>
      'Dieses widerrufene Badge endgültig löschen?';

  @override
  String get kioskClosedToday =>
      'Der Workspace ist heute geschlossen — Check-in und Reservierungen sind nicht möglich.';

  @override
  String kioskBasis(String granularity, String hours) {
    return 'Regel: $granularity · heute $hours';
  }

  @override
  String kioskBlockedContactHint(String name) {
    return 'Belegt von $name — du kannst ihm/ihr über die App auf deinem Handy schreiben.';
  }

  @override
  String get languageTitle => 'Sprache';

  @override
  String get languageSystemDefault => 'Systemstandard';

  @override
  String get levelReserveButton => 'Etage reservieren';

  @override
  String get levelReserveTitle => 'Die ganze Etage reservieren';

  @override
  String get levelPermissionTile => 'Etagen-Reservierungen';

  @override
  String get levelPermissionAllowed =>
      'Darf einen ganzen Tisch, ein Büro oder eine Etage reservieren';

  @override
  String get levelPermissionDenied =>
      'Darf keinen ganzen Tisch, kein Büro und keine Etage reservieren';

  @override
  String get levelBookableToggle => 'Als Ganzes reservierbar';

  @override
  String get levelBookableDesc =>
      'Die ganze Etage kann als eine Buchung reserviert werden.';

  @override
  String get levelPriceLabel => 'Preis je Halbtag';

  @override
  String get levelAssignMember => 'Für Mitglied';

  @override
  String get levelAssignMyself => 'Mich selbst';

  @override
  String get levelSupplementLabel => 'Etagen-Reservierungen';

  @override
  String get levelNotAllowed =>
      'Sie dürfen keinen ganzen Tisch, kein Büro und keine ganze Etage reservieren.';

  @override
  String get levelConflict =>
      'Die Etage hat Reservierungen in diesem Zeitraum.';

  @override
  String get bookingOnePlace =>
      'Du hast in diesem Zeitraum bereits eine Buchung — ein Platz zur Zeit.';

  @override
  String get bookingCheckedInElsewhere =>
      'Du bist woanders eingecheckt — checke dort zuerst aus.';

  @override
  String get spaceNotWholeBookable =>
      'Dieser Bereich ist nicht für Ganzbuchung eingerichtet — die Inhaberin aktiviert dafür „Als Ganzes buchbar“ im Editor.';

  @override
  String get levelFeatureOff =>
      'Büro- & Etagen-Reservierungen sind in den Funktionen ausgeschaltet.';

  @override
  String get levelDetail => 'Ganze Etage';

  @override
  String get kioskLevelButton => 'Diese Etage';

  @override
  String get officeSupplementLabel => 'Büro-Reservierungen';

  @override
  String get eventTypeSpaceReservation => 'Ganzraum-Reservierungen';

  @override
  String get deskDetail => 'Ganzer Tisch';

  @override
  String get deskSupplementLabel => 'Tisch-Reservierungen';

  @override
  String get editorLevelBookableOn => 'Als Ganzes buchbar';

  @override
  String get editorLevelBookableOff => 'Nicht als Ganzes buchbar';

  @override
  String get bookingPastError =>
      'Diese Buchung liegt vollständig in der Vergangenheit.';

  @override
  String get bookingWalkUpTodayError =>
      'Ein spontaner Check-in muss heute beginnen.';

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
  String get bookingSameDayError =>
      'Eine Buchung endet an dem Tag, an dem sie beginnt — den nächsten Tag separat buchen.';

  @override
  String get membersTitle => 'Mitglieder & Tarife';

  @override
  String get membersPlanNone => 'Kein Tarif';

  @override
  String get memberRoleOwner => 'Inhaber';

  @override
  String get memberRoleAdmin => 'Admin';

  @override
  String get memberStatusPaused => 'Pausiert';

  @override
  String get memberStatusExited => 'Ausgetreten';

  @override
  String get membersInvite => 'Mitglied einladen';

  @override
  String get profilesTitle => 'Profile';

  @override
  String get profilesAdd => 'Profil hinzufügen';

  @override
  String get profilesActive => 'Aktives Profil';

  @override
  String get memberRoleMember => 'Mitglied';

  @override
  String get noteRefGone => 'Diese Reservierung existiert nicht mehr.';

  @override
  String get memberNoteDelete => 'Löschen';

  @override
  String get memberNoteDeleteConfirm =>
      'Diese Nachricht löschen? Das lässt sich nicht rückgängig machen.';

  @override
  String get memberNoteReply => 'Antworten';

  @override
  String get noteRefReservation => 'Reservierung verknüpfen';

  @override
  String get noteRefSpace => 'Raum verknüpfen';

  @override
  String get noteRefNoReservations =>
      'Keine kommenden Reservierungen zum Verknüpfen.';

  @override
  String get noteRefWholeLevel => 'ganze Etage';

  @override
  String get memberMessagesAction => 'Nachrichten';

  @override
  String get conversationEmpty => 'Noch keine Nachrichten — sag hallo!';

  @override
  String get notesFilterUnread => 'Ungelesen';

  @override
  String get notesFilterEmpty =>
      'Keine ungelesenen Nachrichten — alles gelesen.';

  @override
  String get conversationGroup => 'Gruppe';

  @override
  String get conversationUnknownMember => 'Mitglied';

  @override
  String get conversationYesterday => 'Gestern';

  @override
  String get conversationYou => 'Sie';

  @override
  String get messagesTitle => 'Nachrichten';

  @override
  String get messagesEmpty => 'Noch keine Unterhaltungen.';

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
  String get newConversationTitle => 'Neue Unterhaltung';

  @override
  String get newConversationSearch => 'Mitglieder suchen';

  @override
  String get newConversationStart => 'Chat starten';

  @override
  String get newConversationNoMembers => 'Noch niemand sonst hier.';

  @override
  String get newGroupName => 'Gruppenname';

  @override
  String get newGroupCreate => 'Gruppe erstellen';

  @override
  String get conversationGroupInfo => 'Gruppe';

  @override
  String get conversationAddPeople => 'Mitglieder hinzufügen';

  @override
  String get conversationLeave => 'Gruppe verlassen';

  @override
  String get conversationLeaveConfirm =>
      'Diese Gruppe verlassen? Sie erhalten keine Nachrichten mehr; Ihre bisherigen bleiben.';

  @override
  String get conversationRemove => 'Entfernen';

  @override
  String get conversationAdmin => 'Admin';

  @override
  String get conversationLeft => 'Ausgetreten';

  @override
  String get messageSearchHint => 'Mitglieder, Gruppen, Nachrichten';

  @override
  String get messageSearchPrompt =>
      'Suchen Sie nach Mitgliedern, Gruppen und Gesagtem.';

  @override
  String get messageSearchNothing => 'Nichts gefunden.';

  @override
  String get messageSearchPeople => 'Mitglieder';

  @override
  String get messageSearchGroups => 'Gruppen';

  @override
  String get messageSearchMessages => 'Nachrichten';

  @override
  String get messageSearchTitle => 'Suchen';

  @override
  String get newGroupNameTaken =>
      'Eine Gruppe mit diesem Namen gibt es hier schon. Wählen Sie einen anderen.';

  @override
  String get conversationSeeProfile => 'Profil ansehen';

  @override
  String get inboxChatsTab => 'Chats';

  @override
  String get memberMoneySettled => 'Nichts offen.';

  @override
  String memberMoreInvoices(int count) {
    return '+$count weitere';
  }

  @override
  String get memberMonthInProgress => 'Dieser Monat';

  @override
  String get memberPayments => 'Zahlungen';

  @override
  String memberInvoiceOpen(String amount) {
    return '$amount offen';
  }

  @override
  String get memberInvoicePaid => 'Bezahlt';

  @override
  String get memberInvoiceVoided => 'Storniert';

  @override
  String get memberContactHeading => 'Kontakt';

  @override
  String memberPlanShare(String pct) {
    return 'Tarif $pct %';
  }

  @override
  String get memberMoneyUnavailable =>
      'Finanzen konnten nicht geladen werden. Zum Aktualisieren ziehen.';

  @override
  String get inboxAlertsTab => 'Hinweise';

  @override
  String get inboxFilterAll => 'Alle';

  @override
  String get inboxFilterUnread => 'Ungelesen';

  @override
  String get inboxFilterArchived => 'Archiviert';

  @override
  String get inboxNoUnread => 'Nichts Ungelesenes — du bist auf dem Laufenden.';

  @override
  String get inboxNoArchived => 'Keine archivierten Unterhaltungen.';

  @override
  String get conversationPin => 'Oben anheften';

  @override
  String get conversationUnpin => 'Loslösen';

  @override
  String get conversationMute => 'Benachrichtigungen stumm';

  @override
  String get conversationUnmute => 'Stummschaltung aufheben';

  @override
  String get conversationMarkUnread => 'Als ungelesen markieren';

  @override
  String get conversationArchive => 'Archivieren';

  @override
  String get conversationUnarchive => 'Aus dem Archiv holen';

  @override
  String get conversationArchived => 'Unterhaltung archiviert.';

  @override
  String get conversationMutedBadge => 'Stumm';

  @override
  String get conversationLoadEarlier => 'Frühere Nachrichten laden';

  @override
  String get conversationToday => 'Heute';

  @override
  String get composerAttach => 'Verweis anhängen';

  @override
  String composerCharsLeft(int count) {
    return '$count Zeichen übrig';
  }

  @override
  String get composerDraftKept => 'Entwurf behalten';

  @override
  String get newConversationTapToOpen =>
      'Tippe auf eine Person, um den Chat zu öffnen; schalte Gruppe ein, um mehrere zu wählen.';

  @override
  String get newConversationGroupSwitch => 'Gruppe';

  @override
  String get inboxRetry => 'Erneut versuchen';

  @override
  String get memberNoteDeleteRead =>
      'Schon gelesen — diese Nachricht kann nicht mehr zurückgenommen werden.';

  @override
  String get memberNoteDeleteNotMine =>
      'Nur der Absender kann eine Nachricht zurücknehmen.';

  @override
  String get noteRefFilterLabel => 'Filtern';

  @override
  String noteRefFilterCount(int shown, int total) {
    return '$shown von $total';
  }

  @override
  String get noteRefFilterEmpty => 'Keine Treffer.';

  @override
  String get noteRefAlert => 'Hinweis';

  @override
  String get noteRefValidation => 'Freigabe';

  @override
  String get noteRefInvoice => 'Rechnung';

  @override
  String get noteRefPayment => 'Zahlung';

  @override
  String get noteRefRefund => 'Erstattung';

  @override
  String get noteRefPickAlert => 'Welcher Hinweis?';

  @override
  String get noteRefPickValidation => 'Welche Freigabe?';

  @override
  String get noteRefPickInvoice => 'Welche Rechnung?';

  @override
  String get noteRefPickPayment => 'Welche Zahlung?';

  @override
  String get noteRefNone => 'Noch nichts zum Verweisen.';

  @override
  String get moneyBaseFee => 'Basis-Abo';

  @override
  String moneyUsage(int used, int included) {
    return '$used von $included halben Tagen genutzt';
  }

  @override
  String moneyUsageUnlimited(int used) {
    return '$used halbe Tage genutzt';
  }

  @override
  String moneyOverage(int count) {
    return 'Mehrnutzung ($count zusätzliche halbe Tage)';
  }

  @override
  String get moneyCredits => 'Zahlungen & Gutschriften';

  @override
  String get moneyBalance => 'Saldo';

  @override
  String get moneyStatementSettled => 'Beglichen';

  @override
  String get moneyStatementOpen => 'Offen';

  @override
  String get moneyRecordPayment => 'Zahlung erfassen';

  @override
  String get moneyAmountLabel => 'Betrag';

  @override
  String get moneyNoteLabel => 'Notiz (optional)';

  @override
  String get moneySubmitPayment => 'Zur Bestätigung einreichen';

  @override
  String get moneyPaymentPending =>
      'Zahlung eingereicht — wartet auf Bestätigung.';

  @override
  String get moneyLedgerHeader => 'Kontobuch';

  @override
  String get moneyLedgerEmpty => 'Noch keine Buchungen.';

  @override
  String get moneySubmitExpense => 'Ausgabe einreichen';

  @override
  String get moneyExpenseCategoryLabel => 'Kategorie';

  @override
  String get moneyDescriptionLabel => 'Beschreibung';

  @override
  String get moneyExpensePending =>
      'Ausgabe eingereicht — wartet auf Freigabe.';

  @override
  String get expenseCategoryCoffee => 'Kaffee & Küche';

  @override
  String get expenseCategorySupplies => 'Verbrauchsmaterial';

  @override
  String get expenseCategoryEquipment => 'Ausstattung';

  @override
  String get expenseCategoryOther => 'Sonstiges';

  @override
  String get ledgerCategorySubscription => 'Abo';

  @override
  String get ledgerCategoryOverage => 'Mehrnutzung';

  @override
  String get ledgerCategoryExpense => 'Auslagenerstattung';

  @override
  String get ledgerCategoryPayment => 'Zahlung';

  @override
  String get ledgerCategoryAdjustment => 'Korrektur';

  @override
  String get ledgerCategoryService => 'Leistung';

  @override
  String get plansEditorTitle => 'Tarife';

  @override
  String get plansEditorNew => 'Neuer Tarif';

  @override
  String get plansEditorEdit => 'Tarif bearbeiten';

  @override
  String get plansEditorInactive => 'Inaktiv';

  @override
  String get plansEditorUnlimited => 'unbegrenzte Halbtage';

  @override
  String plansEditorQuota(int count) {
    return '$count Halbtage';
  }

  @override
  String plansEditorPerExtra(String price) {
    return '$price/zusätzl. Halbtag';
  }

  @override
  String get planNameLabel => 'Name';

  @override
  String get planBaseFeeLabel => 'Monatliche Grundgebühr';

  @override
  String get planIncludedLabel => 'Enthaltene Halbtage';

  @override
  String get planIncludedHelper => 'Leer lassen für unbegrenzt';

  @override
  String get planOverageLabel => 'Preis pro zusätzlichem Halbtag';

  @override
  String get planActiveLabel => 'Aktiv';

  @override
  String get paymentMethodBankTransfer => 'Überweisung';

  @override
  String get paymentMethodCash => 'Bar';

  @override
  String get paymentMethodPaypal => 'PayPal';

  @override
  String get paymentMethodTwint => 'TWINT';

  @override
  String get paymentMethodCard => 'Karte';

  @override
  String get paymentMethodOther => 'Sonstiges';

  @override
  String get paymentMethodWero => 'Wero';

  @override
  String get paymentMethodLydia => 'Lydia';

  @override
  String get paymentMethodWise => 'Wise';

  @override
  String get moneyPaymentDateLabel => 'Zahlungsdatum';

  @override
  String get moneyPaymentPeriodLabel => 'Gilt für';

  @override
  String get moneySectionPay => 'Zahlen';

  @override
  String get moneySectionRequests => 'Anträge';

  @override
  String get moneySectionDocuments => 'Dokumente';

  @override
  String get vatDeclTitle => 'Umsatzsteuer-Voranmeldung';

  @override
  String get vatDeclPeriod => 'Zeitraum';

  @override
  String get vatDeclSeller => 'Verkäufer';

  @override
  String get vatDeclVatId => 'USt-IdNr.';

  @override
  String get vatDeclRate => 'Steuersatz';

  @override
  String get vatDeclNet => 'Bemessungsgrundlage';

  @override
  String get vatDeclVat => 'USt';

  @override
  String get vatDeclInvoices => 'Rechnungen';

  @override
  String get vatDeclTotals => 'Summen';

  @override
  String get vatDeclBoxes => 'Kennzahlen des amtlichen Formulars';

  @override
  String get vatDeclBox => 'Kz';

  @override
  String get vatDeclStatus => 'Status';

  @override
  String get vatDeclDisclaimer =>
      'Aus den ausgestellten Rechnungen des Zeitraums erzeugt. Vor der Abgabe mit der Buchhaltung abgleichen — eine Abgabehilfe, keine Steuerberatung.';

  @override
  String get vatDeclGenerate => 'Erstellen';

  @override
  String get vatDeclEmpty =>
      'Noch keine Voranmeldungen — Zeitraum wählen und die erste erstellen.';

  @override
  String get vatDeclDraft => 'Entwurf';

  @override
  String get vatDeclSubmitted => 'Übermittelt';

  @override
  String get vatDeclTransmit => 'Übermitteln';

  @override
  String get vatDeclMarkFiled => 'Als abgegeben markieren';

  @override
  String get vatDeclMarkFiledConfirm =>
      'Bestätige, dass du diese Voranmeldung selbst abgegeben hast (ELSTER/Portal oder Steuerberater). Sie wird unveränderlich.';

  @override
  String get vatDeclXml => 'XML-Export';

  @override
  String get vatDeclPdf => 'PDF';

  @override
  String get vatDeclSent => 'Voranmeldung übermittelt.';

  @override
  String get vatDeclRejected => 'Die Plattform hat die Voranmeldung abgelehnt.';

  @override
  String get vatDeclRegimeGate =>
      'Voranmeldungen gibt es nur unter dem umsatzsteuerpflichtigen Regime — in den USt-Einstellungen konfigurieren.';

  @override
  String get featureVatManagementTitle => 'USt-Verwaltung';

  @override
  String get featureVatManagementDesc =>
      'Der USt-Satz-Editor und die Satz-Auswahl bei Services, Paketen, Ausstattungen und Tarif. Aus blendet die Konfiguration aus; gespeicherte Sätze gelten weiter.';

  @override
  String get featureVatDeclarationsTitle => 'USt-Voranmeldungen';

  @override
  String get featureVatDeclarationsDesc =>
      'Die periodische USt-Voranmeldung aus den Rechnungen erzeugen, auf das amtliche Formular abbilden und übermitteln oder exportieren.';

  @override
  String get featureEinvoiceCustomerDeliveryTitle =>
      'E-Rechnungszustellung an Kunden';

  @override
  String get featureEinvoiceCustomerDeliveryDesc =>
      'Ein zweiter Sendekanal neben der staatlichen Plattform: die ausgestellte Rechnung direkt an den E-Rechnungsdienst des Kunden übermitteln.';

  @override
  String priceVatIncluded(String rate) {
    return 'inkl. $rate USt';
  }

  @override
  String billingPricesVatHint(String rate) {
    return 'Preise sind brutto — die USt $rate (Standardsatz des Space) ist enthalten.';
  }

  @override
  String billingTariffVatHint(String rate) {
    return 'Preise sind brutto — USt $rate (Tarifsatz) ist enthalten.';
  }

  @override
  String get billingNewPackage => 'Neues Paket';

  @override
  String get priceGrossHint =>
      'Bruttopreis — was das Mitglied zahlt; die USt steckt darin.';

  @override
  String vatShareAmount(String amount) {
    return 'inkl. USt $amount';
  }

  @override
  String get reportDesignerDesign => 'Entwurf';

  @override
  String get reportDesignerPreview => 'Vorschau';

  @override
  String get reportDesignerZoom => 'Zoom';

  @override
  String get reportDesignerZoomFit => 'An Breite anpassen';

  @override
  String get paymentBankNameLabel => 'Bankname';

  @override
  String get paymentAccountNumberLabel => 'Kontonummer';

  @override
  String get paymentSortCodeLabel => 'Sort code';

  @override
  String get paymentRoutingNumberLabel => 'Routing number';

  @override
  String get paymentTransitNumberLabel => 'Transit · Institution';

  @override
  String get paymentBankCodeLabel => 'Bankleitzahl';

  @override
  String get paymentBicLabel => 'BIC / SWIFT';

  @override
  String get paymentCopied => 'Kopiert.';

  @override
  String get moneyFacePayments => 'Zahlungen';

  @override
  String get moneyFaceInvoices => 'Rechnungen';

  @override
  String get moneyNoInvoicesYet =>
      'Noch keine Rechnung — der Monat wird nach Abschluss vom Workspace abgerechnet.';

  @override
  String get moneyFaceStatement => 'Abrechnung';

  @override
  String get moneyFaceDocuments => 'Dokumente';

  @override
  String moneyOverdueBanner(int count, String amount) {
    return '$count überfällig — $amount zu begleichen';
  }

  @override
  String get moneyPayNow => 'Jetzt zahlen';

  @override
  String get moneyOpenInvoicesTitle => 'Offene Rechnungen';

  @override
  String moneyOpenInvoicesSummary(int count, String amount) {
    return '$count offen · $amount fällig';
  }

  @override
  String moneyDueIn(int days) {
    return 'Fällig in $days Tagen';
  }

  @override
  String moneyOverdueBy(int days) {
    return 'Überfällig seit $days Tagen';
  }

  @override
  String get moneyNothingOpen => 'Nichts offen — Sie sind auf dem Laufenden.';

  @override
  String get moneyDocumentLibrary => 'Dokumentbibliothek';

  @override
  String get moneyStatementPdf => 'Monatsabrechnung (PDF)';

  @override
  String moneyRemindedTimes(int count) {
    return 'Gemahnt ×$count';
  }

  @override
  String get expenseSupplyToggle => 'Das ist ein Vorrat für den Raum';

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
  String get expenseSupplyUnitPrice => 'Stückpreis (was ein Verbrauch kostet)';

  @override
  String get expenseSupplyUnitPriceHint =>
      'Vorbelegt mit Betrag ÷ Menge; runden Sie nach Belieben.';

  @override
  String serviceStockCount(int count) {
    return '$count auf Lager';
  }

  @override
  String get serviceOutOfStock => 'Ausverkauft';

  @override
  String get serviceOutOfStockHint =>
      'Nichts mehr im Regal — der nächste Vorrat füllt es auf.';

  @override
  String get negotiationCardTitle => 'Meine verhandelten Preise';

  @override
  String get negotiationOnTariff => 'Sie sind auf dem Tarif des Workspace.';

  @override
  String get negotiationPending => 'Konditionen warten auf Prüfung.';

  @override
  String negotiationActiveSince(String month) {
    return 'Ihre Konditionen gelten seit $month.';
  }

  @override
  String get negotiationFee => 'Monatsbeitrag';

  @override
  String get negotiationOverage => 'Überschreitung je halben Tag';

  @override
  String get negotiationDiscount => 'Rabatt auf Zuschläge';

  @override
  String get negotiationDefaultColumn => 'Tarif';

  @override
  String get negotiationMineColumn => 'Meine';

  @override
  String get negotiationWhoCanSee => 'Wer das sehen kann';

  @override
  String get negotiationProposeTitle => 'Preisverhandlung';

  @override
  String get negotiationProposeHint =>
      'Ein leeres Feld behält den Tarif. Die Konditionen durchlaufen die Prüfung, bevor sie gelten.';

  @override
  String get negotiationNote => 'Notiz';

  @override
  String get negotiationValidFrom => 'Gilt ab';

  @override
  String get negotiationSubmit => 'Zur Prüfung vorschlagen';

  @override
  String get negotiationProposed =>
      'Konditionen vorgeschlagen — warten auf Prüfung.';

  @override
  String get negotiationPendingBadge => 'wartet auf Prüfung';

  @override
  String get negotiationOccupation => 'Auslastung';

  @override
  String get negotiationOccupationHint =>
      'Der Anteil der Öffnungstage, der monatlich enthalten ist; nach Prüfung auf das Mitglied angewendet.';

  @override
  String get negotiationKeepCurrent => 'Aktuelle behalten';

  @override
  String get negotiationItems => 'Leistungen und Pakete';

  @override
  String get negotiationItemsHint =>
      'Ein Stückpreis für dieses Mitglied; leer behält den Katalog.';

  @override
  String negotiationPercent(int value) {
    return '$value %';
  }

  @override
  String get negotiationReadOnly => 'Nur lesen';

  @override
  String get scheduledExpensesTitle => 'Geplante Ausgaben';

  @override
  String get scheduledExpensesIntro =>
      'Abos, die der Space bezahlt — Internet, Telefon, Strom. Der Plan wird einmal validiert; jede Fälligkeit wird Ihnen vorgelegt, bevor sie zählt.';

  @override
  String get scheduledExpensesEmpty => 'Noch keine geplante Ausgabe.';

  @override
  String get scheduleNew => 'Wiederkehrende Ausgabe planen';

  @override
  String get scheduleCancel => 'Diesen Plan beenden';

  @override
  String get scheduleTitleLabel => 'Was (z. B. Internet)';

  @override
  String get scheduleStartsOn => 'Erste Fälligkeit';

  @override
  String get scheduleEveryLabel => 'Alle';

  @override
  String get scheduleUnitLabel => 'Einheit';

  @override
  String get scheduleTimesLabel => 'Wiederholungen (leer = bis zum Enddatum)';

  @override
  String get scheduleEndsOn => 'Bis (optional)';

  @override
  String get scheduleNoEnd => 'Kein Enddatum';

  @override
  String get scheduleValidationHint =>
      'Der Plan geht zuerst an die Validierer. Jede Fälligkeit wird Ihnen dann vorgelegt: zu diesem Betrag bestätigt zählt sie sofort; ein anderer Betrag erklärt sich und wird erneut validiert.';

  @override
  String get scheduleSubmit => 'Planen';

  @override
  String get scheduleMissingFields => 'Name und Betrag sind nötig.';

  @override
  String get schedulePending =>
      'Geplant — wartet auf die Bestätigung der Validierer.';

  @override
  String get scheduleStatusPending => 'Wartet auf Validierung';

  @override
  String get scheduleStatusActive => 'Aktiv';

  @override
  String get scheduleStatusRejected => 'Abgelehnt';

  @override
  String get scheduleStatusEnded => 'Beendet';

  @override
  String get scheduleDaily => 'täglich';

  @override
  String get scheduleWeekly => 'wöchentlich';

  @override
  String get scheduleMonthly => 'monatlich';

  @override
  String get scheduleYearly => 'jährlich';

  @override
  String scheduleEveryDays(Object count) {
    return 'alle $count Tage';
  }

  @override
  String scheduleEveryWeeks(Object count) {
    return 'alle $count Wochen';
  }

  @override
  String scheduleEveryMonths(Object count) {
    return 'alle $count Monate';
  }

  @override
  String scheduleTimes(Object count) {
    return '$count Mal';
  }

  @override
  String scheduleUntil(Object date) {
    return 'bis $date';
  }

  @override
  String scheduleNextDue(Object date) {
    return 'nächste: $date';
  }

  @override
  String get occurrenceRejected =>
      'Die Validierer haben sie abgelehnt — Betrag oder Beschreibung anpassen und erneut senden.';

  @override
  String occurrenceScheduledAmount(Object amount) {
    return 'Validiert: $amount';
  }

  @override
  String get occurrenceReasonLabel => 'Warum es abweicht (Pflicht)';

  @override
  String get occurrenceConfirm => 'Diese Ausgabe bestätigen';

  @override
  String get occurrenceResend => 'Erneut zur Validierung senden';

  @override
  String get occurrenceReasonMissing =>
      'Ein abweichender Betrag braucht eine Erklärung.';

  @override
  String get occurrenceSentForValidation =>
      'An die Validierer gesendet — es zählt nach ihrer Bestätigung.';

  @override
  String get occurrenceAdded => 'Zu Ihren Ausgaben hinzugefügt.';

  @override
  String get scheduledAwaitingTitle => 'Geplante Ausgaben zur Bestätigung';

  @override
  String get scheduleUnitDays => 'Tage';

  @override
  String get scheduleUnitWeeks => 'Wochen';

  @override
  String get scheduleUnitMonths => 'Monate';

  @override
  String get scheduleUnitYears => 'Jahre';

  @override
  String get moneyFaceUsage => 'Nutzung';

  @override
  String get planDurationLabel => 'Dauer';

  @override
  String get planNoLevels => 'Der Workspace hat noch keinen Plan.';

  @override
  String get planLevelLabel => 'Etage';

  @override
  String get planCheckInTitle => 'Einchecken';

  @override
  String get planStartNow => 'Beginnt jetzt';

  @override
  String get planUntilLabel => 'Bis';

  @override
  String get planCheckInButton => 'Einchecken';

  @override
  String get planCheckInNotYetError =>
      'Einchecken ist ab 15 Minuten vor Beginn möglich.';

  @override
  String get planCheckInOverError =>
      'Diese Reservierung ist vorbei — Einchecken ist nicht mehr möglich.';

  @override
  String planCheckInOpensAt(String time) {
    return 'Einchecken ab $time möglich';
  }

  @override
  String planCheckInOpensOn(String date) {
    return 'Check-in öffnet am $date';
  }

  @override
  String planCheckInFor(String name) {
    return '$name einchecken';
  }

  @override
  String get planOverruleRemove => 'Reservierung entfernen (übersteuern)';

  @override
  String planOverruleHint(String name) {
    return '$name und alle Admins werden benachrichtigt.';
  }

  @override
  String planOverruleDone(String name) {
    return 'Reservierung entfernt — $name wurde benachrichtigt.';
  }

  @override
  String get planCheckOutButton => 'Auschecken';

  @override
  String get planCancelReservationButton => 'Reservierung stornieren';

  @override
  String get planSeatBlocked => 'Dieser Platz ist wegen Wartung gesperrt.';

  @override
  String planReservedBy(String name) {
    return 'Reserviert von $name';
  }

  @override
  String planOccupiedBy(String name) {
    return 'Besetzt von $name';
  }

  @override
  String planUntil(String time) {
    return 'bis $time';
  }

  @override
  String planCappedByNext(String time) {
    return 'Der Platz ist ab $time reserviert.';
  }

  @override
  String get planCheckInFailed =>
      'Einchecken nicht möglich — der Platz wurde eventuell gerade belegt.';

  @override
  String get planYourSeat => 'Dein Platz';

  @override
  String get planListViewTooltip => 'Listenansicht';

  @override
  String get planMapViewTooltip => 'Planansicht';

  @override
  String get planNowButton => 'Jetzt';

  @override
  String get planLevelTooltip => 'Etage';

  @override
  String get planReserveButton => 'Reservieren';

  @override
  String get planReservationsEmpty => 'Keine Reservierungen für diesen Tag.';

  @override
  String planStartsAt(String time) {
    return 'Beginnt um $time';
  }

  @override
  String get planRepeatLabel => 'Wiederholen';

  @override
  String get repeatNone => 'Keine Wiederholung';

  @override
  String get repeatDaily => 'Täglich';

  @override
  String get repeatWeekdays => 'Jeden Werktag';

  @override
  String get repeatWeekly => 'Wöchentlich';

  @override
  String get planUntilDateLabel => 'Wiederholen bis';

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
  String get commonOk => 'OK';

  @override
  String get reminderTitle => 'Bald einchecken';

  @override
  String reminderBody(String target, String time) {
    return '$target beginnt um $time';
  }

  @override
  String get planNoSeats => 'Diese Etage hat noch keine Plätze.';

  @override
  String get planStateFree => 'Frei';

  @override
  String get planStateYours => 'Deiner';

  @override
  String get planBookForLabel => 'Buchen für';

  @override
  String get planSendForConfirmation => 'Zur Bestätigung senden';

  @override
  String planBookedForPending(String name) {
    return 'Zur Bestätigung an $name gesendet.';
  }

  @override
  String get planMakeNotReservable => 'Nicht reservierbar machen';

  @override
  String get planMakeReservable => 'Reservierbar machen';

  @override
  String get planAccessorySupplementHint => 'Aufpreise gelten pro halbem Tag.';

  @override
  String get planFromLabel => 'Von';

  @override
  String get planToLabel => 'Bis';

  @override
  String get planEndBeforeStart => 'Das Ende muss nach dem Beginn liegen.';

  @override
  String get planClosedDay => 'An diesem Tag geschlossen';

  @override
  String get planClosedDayError =>
      'Der Workspace ist an diesem Tag geschlossen.';

  @override
  String get planMorningChip => 'Vormittag';

  @override
  String get planAfternoonChip => 'Nachmittag';

  @override
  String get planFullDayChip => 'Ganzer Tag';

  @override
  String get planHalfDayError => 'Buchungen erfolgen hier pro halbem Tag.';

  @override
  String get a11ySeatFree => 'frei';

  @override
  String get a11ySeatReserved => 'reserviert';

  @override
  String get a11ySeatOccupied => 'besetzt';

  @override
  String get a11ySeatMine => 'dein Platz';

  @override
  String get a11ySeatBlocked => 'nicht verfügbar';

  @override
  String get whatsappTitle => 'WhatsApp';

  @override
  String get whatsappNotShared => 'Nicht geteilt';

  @override
  String get whatsappFieldLabel => 'WhatsApp-Nummer';

  @override
  String get whatsappHint => '+49 151 23456789';

  @override
  String get whatsappHelper =>
      'Optional. Für Mitglieder deiner Workspaces sichtbar, damit sie dich über WhatsApp erreichen. Leer lassen, um die Nummer nicht mehr zu teilen.';

  @override
  String get whatsappSaved => 'WhatsApp-Nummer gespeichert';

  @override
  String get whatsappSaveFailed =>
      'WhatsApp-Nummer konnte nicht gespeichert werden';

  @override
  String get profileStatusTitle => 'Status';

  @override
  String get profileStatusNone => 'Kein Status';

  @override
  String get profileStatusFieldLabel => 'Status';

  @override
  String get profileStatusHint => 'Im Call · zurück um 14:00';

  @override
  String get profileStatusHelper =>
      'Optional. Für Mitglieder deiner Workspaces im Mitgliederverzeichnis sichtbar. Leer lassen, um den Status zu löschen.';

  @override
  String get profileStatusSaved => 'Status gespeichert';

  @override
  String get profileStatusSaveFailed =>
      'Status konnte nicht gespeichert werden';

  @override
  String get profilePhotoTitle => 'Foto';

  @override
  String get profilePhotoSet => 'Zum Ändern tippen';

  @override
  String get profilePhotoNone => 'Zum Hinzufügen eines Fotos tippen';

  @override
  String get profilePhotoChoose => 'Foto auswählen';

  @override
  String get profilePhotoRemove => 'Foto entfernen';

  @override
  String get profilePhotoSaved => 'Foto aktualisiert';

  @override
  String get profilePhotoRemoved => 'Foto entfernt';

  @override
  String get profilePhotoSaveFailed => 'Foto konnte nicht aktualisiert werden';

  @override
  String get profilePhotoFileType => 'Bild';

  @override
  String get settingsBillingReports => 'Abrechnung & Berichte';

  @override
  String get defaultPeriodTitle => 'Standard-Buchungszeitraum';

  @override
  String get defaultPeriodNone => 'Keine Präferenz (ganzer Tag)';

  @override
  String get privacyTitle => 'Datenschutz & Daten';

  @override
  String get privacyIntro =>
      'Deine Daten bleiben in der EU, werden nie getrackt oder verkauft und sind nur für die Rollen lesbar, die die Regeln unten nennen. Das sind deine Rechte nach der DSGVO — jedes ist ein Knopf.';

  @override
  String get privacyWhoCanSee => 'Wer meine Daten sehen kann';

  @override
  String get privacyWhoCanSeeHint =>
      'Die Regel je Kategorie, die Personen, die sie heute nennt, und wer tatsächlich hingesehen hat.';

  @override
  String get privacyExport => 'Meine Daten exportieren';

  @override
  String get privacyExportHint =>
      'Alles, dessen Betroffener du bist, als eine JSON-Datei (Art. 20).';

  @override
  String get privacyExportShareText => 'Mein DesKilo-Datenexport';

  @override
  String get privacyErase => 'Diesen Bereich verlassen und meine Daten löschen';

  @override
  String get privacyEraseHint =>
      'Storniert deine Buchungen, leert deine Nachrichten, löscht dein Profil. Buchhaltungsbelege bleiben für die gesetzliche Frist, per ID, nicht per Name (Art. 17).';

  @override
  String get privacyEraseOwner =>
      'Ein Eigentümer übergibt den Bereich zuerst (Mitglieder & Tarife → Miteigentum).';

  @override
  String get privacyEraseConfirmPhrase => 'LÖSCHEN';

  @override
  String privacyEraseConfirmHint(String phrase) {
    return 'Nicht rückgängig zu machen. Tippe $phrase zur Bestätigung.';
  }

  @override
  String get privacyEraseConfirmButton => 'Löschen';

  @override
  String get privacyErased => 'Deine Daten wurden gelöscht.';

  @override
  String get privacyPolicy => 'Datenschutzerklärung';

  @override
  String get consentTitle => 'Ihre Daten, Ihre Rechte';

  @override
  String get consentIntro =>
      'Bevor Sie DesKilo nutzen: was die App mit Ihren Daten tut, wer sie sehen kann und was Sie tun können. Zwei Minuten; mehr ist es nicht.';

  @override
  String get consentWhatTitle => 'Was DesKilo verarbeitet';

  @override
  String get consentWhatBody =>
      'Ihr Konto (E-Mail, Anzeigename, gehashtes Passwort), Ihr Profil, wie Sie es ausfüllen (Foto, Status, Adresse, WhatsApp-Nummer — je optional), und was Sie in einem Workspace tun: Reservierungen und Check-ins, Nachrichten, Ausgaben und Verbräuche, Ihr Abonnement, Rechnungen und Zahlungen. Alles liegt in der EU (Supabase, eu-central-1).';

  @override
  String get consentNotTitle => 'Was DesKilo nie tut';

  @override
  String get consentNotBody =>
      'Kein Tracking, keine Analytik, keine Werbung, kein Verkauf oder Teilen von Daten. Push-Nachrichten tragen keinen Inhalt — nur „Sie haben eine neue Nachricht“; die App selbst schreibt den Text. Die F-Droid-Version hat gar keine Google-Dienste.';

  @override
  String get consentWhoTitle => 'Wer was sehen kann';

  @override
  String get consentWhoBody =>
      'Der Zugriff folgt den Rollen und wird serverseitig durchgesetzt: Buchungen sieht der Workspace (der Plan zeigt die Belegung); Nachrichten nur die Personen der Unterhaltung, gleich welcher Rolle; Ihre Finanzen und Ihre Geschäftsvereinbarung nur Sie, die Inhaber und die Admins mit der passenden Berechtigung. Einstellungen → Datenschutz & Daten nennt die Personen und listet, wer tatsächlich nachgesehen hat.';

  @override
  String get consentControllerTitle => 'Wer verantwortlich ist';

  @override
  String get consentControllerBody =>
      'Jeder Workspace wird von seinem Inhaber betrieben — Ihrer Gemeinschaft —, der Mitglieder, Preise und Zahlungsanbieter bestimmt. Die App ist quelloffen (0BSD) und wird von Florian Dittgen (Deutschland) veröffentlicht; das Backend ist Supabase in der EU. Online-Zahlungen laufen über den vom Inhaber aktivierten Anbieter (PayPal, Stripe, Mollie, Wero) zu dessen Bedingungen.';

  @override
  String get consentRetentionTitle => 'Wie lange';

  @override
  String get consentRetentionBody =>
      'Solange Sie Mitglied sind. Wenn Sie gehen und löschen, verschwinden Profil und Nachrichten; Buchhaltungsbelege (Rechnungen, Zahlungen) bleiben für die gesetzliche Aufbewahrungsfrist, nach Kennung und nicht nach Name.';

  @override
  String get consentRightsTitle => 'Ihre Rechte';

  @override
  String get consentRightsBody =>
      'Auskunft, Berichtigung, Export (Art. 20), Löschung (Art. 17) und Widerspruch — jedes ein Knopf in Einstellungen → Datenschutz & Daten. Für alles andere: fdittgen@gmail.com. Sie können diese Einwilligung jederzeit widerrufen, indem Sie den Workspace verlassen und Ihre Daten löschen.';

  @override
  String get consentReviewTitle => 'Jederzeit nachlesen';

  @override
  String get consentReviewBody =>
      'Dieser Text bleibt in Einstellungen → Datenschutz & Daten, in der App-Hilfe (Datenschutz) und im Projekt-Wiki verfügbar. Eine Änderung des Textes fragt erneut nach Ihrer Zustimmung.';

  @override
  String get consentCheckbox =>
      'Ich habe das gelesen und akzeptiere, wie DesKilo meine Daten behandelt.';

  @override
  String get consentAccept => 'Akzeptieren und weiter';

  @override
  String get consentVersion => 'Version';

  @override
  String consentAcceptedOn(String date, String version) {
    return 'Akzeptiert am $date ($version)';
  }

  @override
  String get consentReadInHelp => 'In der Hilfe lesen';

  @override
  String get consentReadOnWiki => 'Im Wiki lesen';

  @override
  String get consentReviewHint =>
      'Der Text, den Sie akzeptiert haben, mit Datum — jederzeit nachlesbar.';

  @override
  String get backendServerTitle => 'Server';

  @override
  String backendServerDefault(Object host) {
    return 'Der eigene Server der App ($host)';
  }

  @override
  String backendServerCustom(Object host) {
    return 'Dein eigener Server ($host)';
  }

  @override
  String get backendServerHint =>
      'Standardmäßig nutzt die App ihren eigenen Server. Wenn deine Community ein eigenes Supabase-Projekt betreibt, trage es hier ein — die App speichert dann alles dort.';

  @override
  String get backendUrlLabel => 'Projekt-URL';

  @override
  String get backendKeyLabel => 'Publishable Key';

  @override
  String get backendServerRestartHint =>
      'Die App meldet dich ab und übernimmt die Änderung beim nächsten Start.';

  @override
  String get backendServerReset => 'Server der App verwenden';

  @override
  String get backendServerSaved =>
      'Gespeichert. Schließe die App und öffne sie erneut, um den neuen Server zu nutzen.';

  @override
  String get backendErrorUrlEmpty => 'Trage die Projekt-URL ein.';

  @override
  String get backendErrorUrlNotHttps => 'Die URL muss mit https:// beginnen.';

  @override
  String get backendErrorUrlNoHost => 'Das ist keine vollständige Adresse.';

  @override
  String get backendErrorKeyEmpty => 'Trage den Publishable Key ein.';

  @override
  String get backendErrorKeyNotSupabase =>
      'Das ist kein Supabase Publishable Key (sb_publishable_…).';

  @override
  String get backendCurrentTitle => 'Dieses Gerät nutzt';

  @override
  String get backendHowTitle => 'Eigenen Server verwenden';

  @override
  String get backendStep1 =>
      'Lege ein Projekt auf supabase.com an (die kostenlose Stufe reicht zum Start).';

  @override
  String get backendStep2 =>
      'Installiere das Schema der App: führe die SQL-Dateien aus supabase/migrations des Quell-Repositorys der Reihe nach aus.';

  @override
  String get backendStep3 =>
      'Öffne im Supabase-Dashboard Project Settings → API keys und kopiere die Project URL und den Publishable Key.';

  @override
  String get backendStep4 =>
      'Füge sie unten ein, teste die Verbindung und speichere. Mitglieder kommen über den QR-Code oben auf dieselbe Instanz.';

  @override
  String get backendScan => 'Server-QR scannen';

  @override
  String get backendScanNothing =>
      'Dieser QR-Code ist kein DesKilo-Servercode.';

  @override
  String get backendShare => 'Diesen Server teilen';

  @override
  String get backendShareHint =>
      'Mitglieder scannen das in Einstellungen → Server, um ihre App auf dieselbe Instanz zu richten.';

  @override
  String get backendPaste => 'Einfügen';

  @override
  String get backendTest => 'Verbindung testen';

  @override
  String get backendTesting => 'Test läuft…';

  @override
  String get backendTestOk => 'Erreicht — das Schema der App ist vorhanden.';

  @override
  String get backendTestUnreachable =>
      'Diese Adresse war nicht erreichbar. Prüfe die URL und dein Netz.';

  @override
  String get backendTestBadKey =>
      'Erreicht, aber der Key wurde abgelehnt. Kopiere den Publishable Key erneut aus Project Settings → API keys.';

  @override
  String get backendTestSchemaMissing =>
      'Erreicht, aber die DesKilo-Tabellen fehlen — führe zuerst die Migrationen aus supabase/migrations auf diesem Projekt aus.';

  @override
  String get backendCopyLink => 'Kopieren';

  @override
  String get profilesDefault => 'Standard beim Start';

  @override
  String get profilesMakeDefault => 'Beim Start als Standard verwenden';

  @override
  String get eventTypeRoleChange => 'Rollenwechsel';

  @override
  String eventRolePromote(String actor) {
    return '$actor befördert ein Mitglied zum Admin';
  }

  @override
  String eventRoleDemote(String actor) {
    return '$actor stuft einen Admin zum Mitglied zurück';
  }

  @override
  String get memberMakeAdmin => 'Zum Admin machen';

  @override
  String get memberMakeMember => 'Zum normalen Mitglied machen';

  @override
  String get memberRoleChangeRequested =>
      'Rollenwechsel zur Freigabe gesendet.';

  @override
  String get eventTypeQuota => 'Zusätzliche halbe Tage';

  @override
  String eventQuotaRequested(String actor, int halfDays, String period) {
    return '$actor beantragt $halfDays zusätzliche halbe Tage für $period';
  }

  @override
  String get quotaExceededError =>
      'Monatliches Halbtage-Kontingent erreicht — beantrage zusätzliche halbe Tage im Finanzen-Tab.';

  @override
  String get quotaRequestButton => 'Zusätzliche halbe Tage beantragen';

  @override
  String get quotaRequestTitle => 'Zusätzliche halbe Tage beantragen';

  @override
  String quotaRequestExplainer(String period) {
    return 'Deine Reservierungen sind durch dein Abo begrenzt. Zusätzliche halbe Tage für $period gelten nach der Freigabe.';
  }

  @override
  String get quotaRequestCountLabel => 'Anzahl halber Tage';

  @override
  String get quotaRequestPending => 'Antrag gesendet — wartet auf Freigabe.';

  @override
  String get memberReservationLimitTooltip => 'Reservierungslimit';

  @override
  String get memberReservationLimitLabel => 'Reservierungslimit';

  @override
  String get memberReservationLimitExplainer =>
      'Wie viele offene Reservierungen dieses Mitglied gleichzeitig halten darf.';

  @override
  String get memberReservationLimitNone => 'Kein Limit';

  @override
  String get memberReservationLimitCustom => 'Individuell (1–100)';

  @override
  String memberReservationLimitChip(int n) {
    return 'max. $n';
  }

  @override
  String get reservationLimitError =>
      'Reservierungslimit erreicht — du hältst bereits die maximale Zahl offener Reservierungen.';

  @override
  String get memberPause => 'Mitgliedschaft pausieren';

  @override
  String get memberReactivate => 'Mitgliedschaft reaktivieren';

  @override
  String get memberNotifyAction => 'Benachrichtigung senden';

  @override
  String get memberNotifyAllAdmins => 'Alle Admins benachrichtigen';

  @override
  String get memberAllAdmins => 'alle Admins';

  @override
  String memberNoteTitle(String name) {
    return '$name benachrichtigen';
  }

  @override
  String get memberNoteHint => 'Deine Nachricht';

  @override
  String get memberNoteSend => 'Senden';

  @override
  String get memberNoteSent => 'Benachrichtigung gesendet.';

  @override
  String memberNoteReceived(String name) {
    return 'Nachricht von $name';
  }

  @override
  String get eventsMessagesHeader => 'Nachrichten';

  @override
  String memberNoteTo(String name) {
    return 'An $name';
  }

  @override
  String get memberNoteToAllAdmins => 'An alle Admins';

  @override
  String get memberNoteDeleted => 'Nachricht gelöscht.';

  @override
  String get memberSimultaneousLimitLabel => 'Gleichzeitige Reservierungen';

  @override
  String get memberSimultaneousLimitExplainer =>
      'Wie viele Buchungen dieses Mitglied im selben Zeitraum halten darf. Ohne Angabe gilt die Vorgabe des Arbeitsraums.';

  @override
  String get memberSimultaneousLimitDefault => 'Vorgabe des Arbeitsraums';

  @override
  String memberSimultaneousLimitChip(int n) {
    return '$n gleichzeitig';
  }

  @override
  String get reserveMonthView => 'Monat';

  @override
  String monthFreeCount(int free, int total) {
    return '$free/$total';
  }

  @override
  String get reservationRecurring => 'Wiederkehrende Reservierung';

  @override
  String get reservationEditTimes => 'Zeit ändern';

  @override
  String get reservationUpdatedSnack => 'Reservierung aktualisiert.';

  @override
  String get reservationCancelledSnack => 'Reservierung storniert.';

  @override
  String get reserveDayView => 'Tag';

  @override
  String get reserveWeekView => 'Woche';

  @override
  String get reserveFullDayChip => 'Ganzer Tag';

  @override
  String get reservePickDateTooltip => 'Datum wählen';

  @override
  String get reserveBookingFailed =>
      'Reservieren nicht möglich — der Platz wurde eventuell gerade belegt.';

  @override
  String get spaceScanNfcHint =>
      '…oder das Telefon an den NFC-Tag eines Stuhls halten.';

  @override
  String get spaceScanUnknownTag =>
      'Dieser Tag ist mit keinem Stuhl verknüpft.';

  @override
  String bookingCheckedInUntil(String until) {
    return 'Eingecheckt bis $until.';
  }

  @override
  String bookingCheckedInAtUntil(String space, String until) {
    return 'Auf $space eingecheckt bis $until.';
  }

  @override
  String bookingReservedWhen(String when) {
    return 'Reserviert: $when.';
  }

  @override
  String bookingReservedSpaceWhen(String space, String when) {
    return '$space reserviert: $when.';
  }

  @override
  String bookingHorizonError(int days) {
    return 'Zu weit voraus — Buchungen sind $days Tage im Voraus möglich.';
  }

  @override
  String bookingTooShortError(int minutes) {
    return 'Zu kurz — eine Buchung dauert mindestens $minutes Minuten.';
  }

  @override
  String bookingTooLongError(int minutes) {
    return 'Zu lang — eine Buchung dauert höchstens $minutes Minuten.';
  }

  @override
  String get legendFree => 'Frei';

  @override
  String get legendReserved => 'Reserviert';

  @override
  String get legendOccupied => 'Eingecheckt';

  @override
  String get legendMine => 'Meine';

  @override
  String get legendBlocked => 'Gesperrt';

  @override
  String get legendClosed => 'Geschlossen';

  @override
  String get reserveClosedShort => 'Zu';

  @override
  String planCheckOutFor(String name) {
    return '$name auschecken';
  }

  @override
  String get scanCameraWebUnavailable =>
      'Kamera-Scan ist im Browser nicht verfügbar — Code eingeben oder ein NFC-Tag ans Gerät halten (Chrome auf Android).';

  @override
  String get bookingGateBlocked => 'So nicht buchbar';

  @override
  String get servicesTitle => 'Leistungen';

  @override
  String get servicesEmpty => 'Noch keine Leistungen.';

  @override
  String get servicesNew => 'Neue Leistung';

  @override
  String get servicesEdit => 'Leistung bearbeiten';

  @override
  String get servicesName => 'Name';

  @override
  String get servicesPrice => 'Preis';

  @override
  String get servicesInactive => 'Inaktiv';

  @override
  String get servicesActive => 'Aktiv';

  @override
  String get authContinueWith => 'oder weiter mit';

  @override
  String authSocialUnavailable(String provider) {
    return 'Die $provider-Anmeldung ist noch nicht verfügbar — der Server hat sie nicht aktiviert.';
  }

  @override
  String get linkedAccountsTitle => 'Verknüpfte Konten';

  @override
  String get linkedAccountsIntro =>
      'Melde dich mit jedem davon an diesem Konto an. Füge Google, Microsoft, Apple oder Facebook hinzu, um dich ohne Passwort anzumelden.';

  @override
  String get linkedAccountsLink => 'Verknüpfen';

  @override
  String get linkedAccountsUnlink => 'Trennen';

  @override
  String get linkedAccountsLinked => 'Verknüpft';

  @override
  String get linkedAccountsLinkStarted =>
      'Fahre im Browser fort, um die Verknüpfung abzuschließen.';

  @override
  String get spaceScanTitle => 'Raumcode scannen';

  @override
  String get spaceScanHint =>
      'Kamera auf die Karte eines Platzes, Tischs, Büros oder einer Etage richten — oder den Code eintippen.';

  @override
  String get spaceScanField => 'Code';

  @override
  String get spaceScanInvalid => 'Kein Raumcode dieses Workspace.';

  @override
  String get spaceScanUnknown => 'Dieser Code passt zu keinem Raum mehr.';

  @override
  String get spaceSeatTaken => 'Belegt';

  @override
  String get spaceNotBookable =>
      'Dieser Raum ist nicht für Ganzraum-Reservierungen eingerichtet.';

  @override
  String get spaceCodesTitle => 'Raum-QR-Codes (PDF)';

  @override
  String get spaceCodesDesc =>
      'Eine druckbare QR-Karte je Platz, Tisch, Büro und Etage — Mitglieder scannen sie zum Reservieren oder Einchecken.';

  @override
  String get spaceKindDesk => 'Tisch';

  @override
  String get spaceKindOffice => 'Büro';

  @override
  String get spaceKindLevel => 'Etage';

  @override
  String get spaceKindSeat => 'Platz';

  @override
  String get spaceYoursNow => 'Von dir für dieses Zeitfenster reserviert.';

  @override
  String get spaceCardSizeLabel => 'Kartengröße';

  @override
  String get spaceQrSizeLabel => 'Größe des QR-Codes';

  @override
  String get spaceCardSizeSmall => 'Klein';

  @override
  String get spaceCardSizeMedium => 'Mittel';

  @override
  String get spaceCardSizeLarge => 'Groß';

  @override
  String get spaceCardInfoLabel => 'Informationen auf der Karte';

  @override
  String get spaceCardInfoWorkspace => 'Workspace';

  @override
  String spaceMessageReserver(String name) {
    return 'Nachricht an $name';
  }

  @override
  String get spaceYoursCheckedIn =>
      'Sie sind hier für diesen Zeitraum eingecheckt.';

  @override
  String get spaceBlockedByYou =>
      'Sie halten diesen Bereich für diesen Zeitraum bereits.';

  @override
  String get spaceManageMyBooking => 'Meine Buchung verwalten';

  @override
  String get themeTitle => 'Design';

  @override
  String get themeSystem => 'Systemstandard';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get usageTitle => 'Nutzung';

  @override
  String get usageEmpty => 'Keine Nutzung in diesem Monat.';

  @override
  String get usageBooked => 'Gebucht';

  @override
  String get usagePresent => 'Anwesend';

  @override
  String get usageBilled => 'Berechnet';

  @override
  String get usageNoShow => 'Niemand kam — die Buchung wird voll berechnet';

  @override
  String get usageLeftEarly => 'Früher gegangen';

  @override
  String get usageCorrected => 'Korrigiert';

  @override
  String usageWas(String before) {
    return 'war $before';
  }

  @override
  String get usageAsk => 'Die Zeit berechnen, in der ich da war';

  @override
  String usageAskExplain(String booked, String present, String saved) {
    return 'Sie haben $booked gebucht und waren $present da. Bitten Sie darum, die nicht genutzten $saved nicht zu berechnen. Jemand anderes entscheidet — nie Sie.';
  }

  @override
  String get usageReasonLabel => 'Warum (optional)';

  @override
  String get usageAskSubmit => 'Anfragen';

  @override
  String get usageAskSubmitted => 'Angefragt. Jemand anderes entscheidet.';

  @override
  String get usageDelete => 'Diesen Satz entfernen';

  @override
  String get usageDeleteSubmitted => 'Entfernung angefragt.';

  @override
  String get usageMember => 'Mitglied';

  @override
  String get usageMemberAll => 'Alle';

  @override
  String eventValidations(int current, int required) {
    return '$current/$required Bestätigungen';
  }

  @override
  String eventValidatedBy(String name, String when) {
    return 'Bestätigt von $name · $when';
  }

  @override
  String eventRejectedBy(String name, String when) {
    return 'Abgelehnt von $name · $when';
  }

  @override
  String get eventSystemDecider => 'System';

  @override
  String get validationTrailTitle => 'Freigabeverlauf';

  @override
  String get validationTrailNone => 'Noch keine Entscheidung.';

  @override
  String validationTrailStep(int order) {
    return 'Stufe $order';
  }

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
  String eventValidationStage(int stage, int required) {
    return 'Freigabe $stage von $required angefragt';
  }

  @override
  String get validationTitle => 'Validierungsregeln';

  @override
  String get validationDefaultPolicy => 'Standardregel';

  @override
  String get validationInherited => 'Erbt den Standard';

  @override
  String get validationCustomized => 'Angepasst';

  @override
  String get validationRequiredCount => 'Erforderliche Validierungen';

  @override
  String get validationAdminsMay => 'Admins dürfen validieren';

  @override
  String get validationOwnerOnly => 'Nur Inhaber';

  @override
  String get validationAllAdmins => 'Alle Admins';

  @override
  String get validationSpecificAdmins => 'Bestimmte Admins';

  @override
  String get validationOwnerRequired => 'Inhaber muss immer validieren';

  @override
  String get validationNotEnough => 'Nicht genügend berechtigte Validierer.';

  @override
  String get validationSaved => 'Validierungsregel gespeichert.';

  @override
  String get validationAutoValidateOwner => 'Inhaber löschen ohne Validierung';

  @override
  String get validationAutoValidateAdmin => 'Admins löschen ohne Validierung';

  @override
  String get validationAutoValidateDesc =>
      'Ihr eigener Löschantrag erledigt sich selbst und bleibt als automatisch validiert markiert.';

  @override
  String get validationNoSelfTitle => 'Niemand gibt das Eigene frei';

  @override
  String get validationNoSelfDesc =>
      'Wer ein Ereignis auslöst, gibt es nie selbst frei. Es wartet auf jemand anderen oder verfällt unentschieden.';

  @override
  String get validationNoSelfShort => 'Nie das Eigene';

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
  String get validationSequential => 'Nacheinander';

  @override
  String get validationSequentialDesc =>
      'Die nächste Freigabe wird erst angefragt, wenn die vorige durch ist, und der Verlauf nummeriert jede Stufe.';

  @override
  String get vatTitle => 'Mehrwertsteuer';

  @override
  String get vatIntro =>
      'Preise in DesKilo sind Bruttopreise. Sätze anzulegen ändert nichts daran, was Mitglieder zahlen — die Steuer wird aus dem bestehenden Preis herausgerechnet und auf der Rechnung ausgewiesen.';

  @override
  String get vatRegimeHint =>
      'Dieser Space ist nicht als umsatzsteuerpflichtig deklariert, Rechnungen weisen daher keine Steuer aus. Das ändert sich unter Rechtliche Identität.';

  @override
  String get vatEmpty =>
      'Noch kein Satz — Rechnungen weisen keine Mehrwertsteuer aus.';

  @override
  String get vatSeed => 'Übliche Sätze übernehmen';

  @override
  String get vatAddRate => 'Satz hinzufügen';

  @override
  String get vatRateLabelField => 'Name';

  @override
  String get vatRatePercentField => 'Satz %';

  @override
  String get vatRateDefaultTooltip =>
      'Standardsatz — gilt für Abos und alles ohne eigenen Satz';

  @override
  String get vatRateRemoveTooltip => 'Entfernen';

  @override
  String get vatSaved => 'Steuersätze gespeichert.';

  @override
  String get vatNeedsDefault => 'Genau einen Satz als Standard markieren.';

  @override
  String get vatRateIncomplete =>
      'Jeder Satz braucht einen Namen und einen Prozentwert zwischen 0 und 99,99.';

  @override
  String get vatRatesTile => 'Steuersätze';

  @override
  String get vatAccountField => 'Steuerkonto';

  @override
  String get vatAccountHint =>
      'Konto, auf das der Buchhaltungsexport die vereinnahmte Steuer bucht. Leer = 445710.';

  @override
  String get vatServiceRate => 'Steuersatz';

  @override
  String get vatServiceRateDefault => 'Standard des Spaces';

  @override
  String get vatPdfNet => 'Netto';

  @override
  String get vatPdfVat => 'MwSt.';

  @override
  String get fecAccountVat => 'Vereinnahmte Steuer';

  @override
  String get vatKeptRate =>
      'Ein Satz, den eine Rechnung oder eine Leistung noch nutzt, bleibt erhalten und wird deaktiviert.';

  @override
  String get onboardingTitle => 'Willkommen bei DesKilo';

  @override
  String get onboardingCreateTab => 'Workspace erstellen';

  @override
  String get onboardingJoinTab => 'Workspace beitreten';

  @override
  String get workspaceNameLabel => 'Name des Workspace';

  @override
  String get workspaceCountryLabel => 'Land';

  @override
  String get workspaceCurrencyLabel => 'Währung';

  @override
  String get workspaceTimezoneLabel => 'Zeitzone';

  @override
  String get onboardingCreateButton => 'Workspace erstellen';

  @override
  String get workspaceInviteCodeLabel => 'Einladungscode';

  @override
  String get onboardingJoinButton => 'Beitreten';

  @override
  String get workspaceGenericError =>
      'Etwas ist schiefgelaufen. Bitte erneut versuchen.';

  @override
  String get countryNameDE => 'Deutschland';

  @override
  String get countryNameAT => 'Österreich';

  @override
  String get countryNameCH => 'Schweiz';

  @override
  String get countryNameFR => 'Frankreich';

  @override
  String get countryNameIT => 'Italien';

  @override
  String get countryNameES => 'Spanien';

  @override
  String get countryNamePT => 'Portugal';

  @override
  String get countryNameNL => 'Niederlande';

  @override
  String get countryNameBE => 'Belgien';

  @override
  String get countryNameLU => 'Luxemburg';

  @override
  String get countryNameGB => 'Vereinigtes Königreich';

  @override
  String get countryNameUS => 'Vereinigte Staaten';

  @override
  String get workspaceCodeTitle => 'Workspace-ID & QR';

  @override
  String get workspaceCodeLabel => 'Workspace-ID';

  @override
  String get workspaceCodeHint => '4–20 Buchstaben oder Ziffern, eindeutig';

  @override
  String get workspaceCodeEdit => 'Workspace-ID ändern';

  @override
  String get workspaceCodeRejected =>
      'ID abgelehnt — sie muss 4–20 Buchstaben oder Ziffern haben und darf nicht vergeben sein.';

  @override
  String get workspaceCodeExplainer =>
      'Coworker scannen diesen QR-Code — oder tippen die ID ein — um diesem Workspace beizutreten.';

  @override
  String get workspaceCodeCopy => 'ID kopieren';

  @override
  String get workspaceCodeCopied => 'Kopiert';

  @override
  String get inviteRoleMember => 'Mitglieder-Einladung';

  @override
  String get inviteRoleAdmin => 'Admin-Einladung';

  @override
  String get inviteAdminExplainer =>
      'Dieser Code ist einmalig nutzbar: Er lässt EINE Person als Admin beitreten und verfällt dann. Gib ihn nur der Person, für die er bestimmt ist.';

  @override
  String get inviteAdminNewCode => 'Neuer Admin-Code';

  @override
  String get inviteOwnerNote =>
      'Es gibt keine Eigentümer-Einladung — nur ein Eigentümer kann Eigentum vergeben, unter Mitglieder & Tarife.';

  @override
  String get scanJoinTitle => 'Workspace-QR scannen';

  @override
  String get onboardingScanButton => 'QR-Code scannen';

  @override
  String get scanJoinHelp =>
      'Richte die Kamera auf den Einladungs-QR — der Code wird übernommen und der Beitritt läuft automatisch.';

  @override
  String get scanJoinNotAnInvite =>
      'Dieser QR ist keine DesKilo-Einladung — scanne den aus der Einladungsnachricht.';

  @override
  String get workspaceCodeSharePng => 'Als PNG teilen';

  @override
  String get workspaceSettingsTitle => 'Workspace';

  @override
  String get workspaceSettingsSaved => 'Workspace gespeichert.';

  @override
  String get workspaceSettingsCurrencyHelper =>
      'Wird vom Land vorbelegt — überschreiben, falls eure Community in einer anderen Währung abrechnet.';

  @override
  String get paymentInstructionsTitle => 'Zahlungshinweise';

  @override
  String get paymentInstructionsHelper =>
      'Wird Mitgliedern auf einer offenen Abrechnung angezeigt. Leer lassen, um nichts anzuzeigen.';

  @override
  String get paymentInstructionsPaypalLabel => 'PayPal.me-Link oder -Name';

  @override
  String get paymentInstructionsReferenceLabel =>
      'Hinweis zum Verwendungszweck';

  @override
  String get paymentInstructionsIbanTitle => 'IBAN';

  @override
  String get paymentInstructionsIbanCopied => 'IBAN kopiert.';

  @override
  String get paymentInstructionsWeroLabel => 'Wero-Telefonnummer';

  @override
  String get paymentInstructionsLydiaLabel =>
      'Lydia-Telefonnummer oder -Nutzername';

  @override
  String get paymentInstructionsWiseLabel => 'Wisetag oder Wise-Zahlungslink';

  @override
  String get paymentInstructionsValueCopied => 'In die Zwischenablage kopiert.';

  @override
  String get workspaceWhatsappGroupTitle => 'WhatsApp-Gruppe';

  @override
  String get workspaceWhatsappGroupHelper =>
      'Wird Mitgliedern angezeigt, damit sie der WhatsApp-Gruppe der Community beitreten können. Einladungslink der Gruppe einfügen (https://chat.whatsapp.com/…). Leer lassen, um nichts anzuzeigen.';

  @override
  String get workspaceWhatsappGroupLabel => 'Link zur WhatsApp-Gruppe';

  @override
  String get workspaceWhatsappGroupInvalid =>
      'Muss ein chat.whatsapp.com-Einladungslink sein';

  @override
  String get memberStatusActive => 'Aktiv';

  @override
  String get workspaceConfigPdfExport => 'Konfiguration exportieren (PDF)';

  @override
  String get workspaceConfigPdfExportSubtitle =>
      'Vollständige Momentaufnahme: Einstellungen, alle Mitglieder und der Plan.';

  @override
  String get workspaceConfigPdfTitle => 'Workspace-Konfiguration';

  @override
  String workspaceConfigPdfGeneratedOn(String date) {
    return 'Erstellt am $date';
  }

  @override
  String get workspaceConfigOverview => 'Übersicht';

  @override
  String get workspaceConfigMembersSection => 'Mitglieder';

  @override
  String get workspaceConfigFeatures => 'Aktivierte Funktionen';

  @override
  String get workspaceConfigAvailability => 'Verfügbarkeit';

  @override
  String get workspaceConfigFloorPlan => 'Grundriss';

  @override
  String get workspaceConfigGranularity => 'Buchungsgranularität';

  @override
  String get workspaceConfigColName => 'Name';

  @override
  String get workspaceConfigColRole => 'Rolle';

  @override
  String get workspaceConfigColStatus => 'Status';

  @override
  String get workspaceConfigOpenDays => 'Öffnungstage';

  @override
  String get workspaceConfigClosures => 'Schließtage';

  @override
  String get workspaceConfigBookableWhole => 'als Ganzes buchbar';

  @override
  String get workspaceConfigSeats => 'Plätze';

  @override
  String get workspaceConfigEmptyLevel => 'Keine Räume';

  @override
  String get workspaceConfigNone => 'Keine';

  @override
  String get workspaceDeskTransparencyTitle => 'Tisch-Transparenz';

  @override
  String get workspaceDeskTransparencyHelper =>
      'Verringere die Deckkraft der Tische, damit das Hintergrundfoto der Etage durchscheint.';

  @override
  String workspaceDeskOpacityValue(int percent) {
    return 'Deckkraft: $percent %';
  }

  @override
  String get workspaceDangerZone => 'Gefahrenzone';

  @override
  String get workspaceResetTitle => 'Workspace zurücksetzen';

  @override
  String get workspaceResetSubtitle =>
      'Löscht alle Buchungen, Finanzen und den Grundriss. Einstellungen und Mitglieder bleiben.';

  @override
  String get workspaceResetDialogTitle => 'Diesen Workspace zurücksetzen?';

  @override
  String get workspaceResetWarning =>
      'Dies löscht dauerhaft alle Reservierungen, sämtliche Finanz- und Buchungsdaten, den Aktivitätsverlauf und den gesamten Grundriss — Etagen, Räume, Tische, Plätze und Bilder. Workspace-Einstellungen, Gebührenstufen, Verfügbarkeit, Funktionen, Kataloge und Mitglieder bleiben erhalten. Nicht rückgängig zu machen.';

  @override
  String get workspaceResetConfirmPhrase => 'Ich stimme zu';

  @override
  String workspaceResetConfirmLabel(String phrase) {
    return 'Tippe „$phrase“ zum Bestätigen';
  }

  @override
  String get workspaceResetConfirmButton => 'Workspace zurücksetzen';

  @override
  String get workspaceResetDone => 'Workspace zurückgesetzt.';

  @override
  String get workspaceExcelExport => 'Daten exportieren (Excel)';

  @override
  String get workspaceExcelExportSubtitle =>
      'Alle Daten in einer Arbeitsmappe: Buchungen, Zahlungen, Rechnungen, Mitglieder und Plan — je ein Tab.';

  @override
  String get workspaceLanguageLabel => 'Sprache des Arbeitsbereichs';

  @override
  String get workspaceLanguageHelper =>
      'Einladungen werden standardmäßig in dieser Sprache verfasst.';

  @override
  String get workspaceLanguageUnset => 'App-Sprache des Absenders';

  @override
  String get workspacePaymentsBillingTitle => 'Zahlungen & Abrechnung';

  @override
  String get paymentMethodsSubtitle =>
      'IBAN, PayPal, Wero, Lydia, Wise und der Verwendungszweck';

  @override
  String get featureDocuments => 'Dokumentbibliothek';

  @override
  String get featureDocumentsDesc =>
      'Die Dokumentbibliothek des Arbeitsbereichs: Satzung, Anleitungen, Finanzberichte, Protokolle — aus jedem Drive verlinkt, sichtbar je nach Rolle.';

  @override
  String get documentsTitle => 'Dokumente';

  @override
  String get documentsAdd => 'Dokument hinzufügen';

  @override
  String get documentsTitleLabel => 'Titel';

  @override
  String get documentsUrlLabel => 'Link (https://…)';

  @override
  String get documentsUrlHelper =>
      'Fügen Sie den Freigabelink Ihres Drives ein — die Zugriffsrechte bleiben dort verwaltet.';

  @override
  String get documentsProviderLabel => 'Gespeichert auf';

  @override
  String get documentsCategoryLabel => 'Kategorie';

  @override
  String get documentsRoleLabel => 'Sichtbar für';

  @override
  String get documentsRoleMember => 'Alle Mitglieder';

  @override
  String get documentsRoleAdmin => 'Admins und Inhaber';

  @override
  String get documentsRoleOwner => 'Nur Inhaber';

  @override
  String get documentsCategoryStatutes => 'Satzung & Rechtliches';

  @override
  String get documentsCategoryGuides => 'Anleitungen & Handbücher';

  @override
  String get documentsCategoryFinance => 'Finanzberichte';

  @override
  String get documentsCategoryMinutes => 'Protokolle';

  @override
  String get documentsCategoryOther => 'Weitere Dokumente';

  @override
  String get documentsEmpty =>
      'Noch kein Dokument. Verlinken Sie Satzung, Anleitungen und Berichte aus jedem Drive.';

  @override
  String get documentsDelete => 'Dokument entfernen?';

  @override
  String get documentsInvalid =>
      'Ein Dokument braucht einen Titel und einen https://-Link.';

  @override
  String get featureRoleManagement => 'Rollenverwaltung';

  @override
  String get featureRoleManagementDesc =>
      'Die zentrale Rolle→Berechtigung-Matrix: Die Inhaberin entscheidet, welche Rolle welche Berechtigung hält; alle anderen lesen ihre eigenen. Aus: Es gelten einfach die Standardwerte.';

  @override
  String get rolesTitle => 'Rollenverwaltung';

  @override
  String get rolesIntroEditor =>
      'Die Inhaberin hält immer alle Berechtigungen. Lege hier fest, was die anderen Rollen dürfen — ein Co-Inhaber kann weniger halten als ein Inhaber.';

  @override
  String get rolesIntroReadOnly =>
      'Nur lesen: Das sind die Berechtigungen jeder Rolle. Deine Rolle ist hervorgehoben.';

  @override
  String get rolesYourRole => 'Deine Rolle';

  @override
  String get roleOwner => 'Inhaber';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get roleMember => 'Mitglied';

  @override
  String get permManageRoles => 'Rollen & Berechtigungen verwalten';

  @override
  String get permManageMembers => 'Mitglieder verwalten';

  @override
  String get permManageValidation => 'Validierungsregeln konfigurieren';

  @override
  String get permWorkspaceSettings => 'Workspace-Einstellungen bearbeiten';

  @override
  String get permIssueInvoices => 'Rechnungen ausstellen & Zahlungen zuordnen';

  @override
  String get permViewFinances => 'Workspace-Finanzen einsehen';

  @override
  String get permManageDocuments => 'Dokumentbibliothek verwalten';

  @override
  String get permManageServices => 'Services & Pakete verwalten';

  @override
  String get permApproveExpenses => 'Ausgaben genehmigen';

  @override
  String get regionalFormatsTitle => 'Region & Formate';

  @override
  String get regionalFormatLocale => 'Zahlen & Daten';

  @override
  String regionalFormatLocaleAuto(String locale) {
    return 'Folgt der App-Sprache ($locale)';
  }

  @override
  String get regionalFollowLanguage => 'Automatisch';

  @override
  String get regionalClock => 'Uhr';

  @override
  String get regionalClockAuto => 'Auto';

  @override
  String get regionalDeviceZone => 'Zeiten in meiner Zeitzone anzeigen';

  @override
  String get regionalDeviceZoneHint =>
      'Aus: Zeiten in der Zone des Bereichs, in der gebucht wird. An: die deines Geräts, gekennzeichnet, wo sie abweicht.';

  @override
  String get workspaceTimezoneUnknown => 'Wähle eine Zeitzone aus der Liste';

  @override
  String get countryNameCY => 'Zypern';

  @override
  String get countryNameEE => 'Estland';

  @override
  String get countryNameFI => 'Finnland';

  @override
  String get countryNameGR => 'Griechenland';

  @override
  String get countryNameHR => 'Kroatien';

  @override
  String get countryNameIE => 'Irland';

  @override
  String get countryNameLT => 'Litauen';

  @override
  String get countryNameLV => 'Lettland';

  @override
  String get countryNameMT => 'Malta';

  @override
  String get countryNameSI => 'Slowenien';

  @override
  String get countryNameSK => 'Slowakei';

  @override
  String get countryNameBG => 'Bulgarien';

  @override
  String get countryNameCZ => 'Tschechien';

  @override
  String get countryNameDK => 'Dänemark';

  @override
  String get countryNameHU => 'Ungarn';

  @override
  String get countryNamePL => 'Polen';

  @override
  String get countryNameRO => 'Rumänien';

  @override
  String get countryNameSE => 'Schweden';

  @override
  String get regionalClock24h => '24h';

  @override
  String get regionalClock12h => '12h';

  @override
  String get countryNameMX => 'Mexiko';

  @override
  String get countryNameAU => 'Australien';

  @override
  String get countryNameJP => 'Japan';

  @override
  String get languageNameDE => 'Deutsch';

  @override
  String get languageNameEN => 'Englisch';

  @override
  String get languageNameES => 'Spanisch';

  @override
  String get languageNameFR => 'Französisch';

  @override
  String get languageNameIT => 'Italienisch';

  @override
  String get languageNameNL => 'Niederländisch';

  @override
  String get languageNamePT => 'Portugiesisch';

  @override
  String get languageNamePL => 'Polnisch';

  @override
  String get languageNameSV => 'Schwedisch';

  @override
  String get languageNameDA => 'Dänisch';

  @override
  String get languageNameNB => 'Norwegisch';

  @override
  String get languageNameFI => 'Finnisch';

  @override
  String get languageNameCS => 'Tschechisch';

  @override
  String get languageNameHU => 'Ungarisch';

  @override
  String get languageNameRO => 'Rumänisch';

  @override
  String get languageNameEL => 'Griechisch';

  @override
  String get languageNameJA => 'Japanisch';

  @override
  String get countryNameCA => 'Kanada';

  @override
  String get countryNameNO => 'Norwegen';

  @override
  String get permViewNegotiations => 'Geschäftsvereinbarungen einsehen';

  @override
  String get permManageNegotiations => 'Geschäftsvereinbarungen verwalten';

  @override
  String get workspaceXmlExport => 'Workspace exportieren (XML)';

  @override
  String get workspaceXmlExportSubtitle =>
      'Einstellungen und Raumplan als teilbare Datei. Ohne Mitglieder, Buchungen oder Finanzdaten.';

  @override
  String get workspaceXmlImport => 'Workspace importieren (XML)';

  @override
  String get workspaceXmlImportSubtitle =>
      'Einstellungen und Raumplan aus einer exportierten Datei wiederherstellen. Ersetzt den aktuellen Raumplan.';

  @override
  String get workspaceXmlFileTypeLabel => 'XML';

  @override
  String get workspaceXmlImportPreviewTitle => 'Raumplan ersetzen?';

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
  String workspaceXmlImportPreviewAccessories(int count) {
    return 'Zubehör: $count';
  }

  @override
  String get workspaceXmlImportPreviewWarning =>
      'Der aktuelle Raumplan wird gelöscht und ersetzt, die Workspace-Einstellungen werden überschrieben. Das kann nicht rückgängig gemacht werden.';

  @override
  String get workspaceXmlImportConfirm => 'Ersetzen und importieren';

  @override
  String get workspaceXmlImportSuccess => 'Workspace importiert.';

  @override
  String get workspaceXmlErrorMalformed => 'Die Datei ist kein lesbares XML.';

  @override
  String get workspaceXmlErrorWrongRoot =>
      'Das ist keine DesKilo-Workspace-Datei.';

  @override
  String get workspaceXmlErrorUnsupportedVersion =>
      'Die Datei wurde von einer neueren DesKilo-Version exportiert und kann nicht importiert werden.';

  @override
  String get workspaceXmlErrorMissingElement =>
      'Die Datei ist unvollständig — ein erforderlicher Abschnitt fehlt.';

  @override
  String get workspaceXmlErrorMissingAttribute =>
      'Die Datei ist unvollständig — ein erforderlicher Wert fehlt.';

  @override
  String get workspaceXmlErrorInvalidValue =>
      'Die Datei enthält einen ungültigen Wert und kann nicht importiert werden.';

  @override
  String get workspaceXmlErrorInvalidPlan =>
      'Der Raumplan in der Datei ist ungültig: Räume, Tische oder Plätze überlappen sich oder liegen außerhalb ihres Bereichs.';

  @override
  String get workspaceXmlImportReservationsError =>
      'Dieser Workspace hat bereits Reservierungen, daher kann sein Raumplan nicht ersetzt werden. Ein Import ist nur vor der ersten Buchung möglich.';
}
