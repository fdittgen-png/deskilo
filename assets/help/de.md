# Benutzerhandbuch

Alles, was Mitglieder, Admins und Inhaberinnen brauchen, um DesKilo zu nutzen.

> Die Screenshots in diesem Handbuch zeigen die App auf Französisch — jeder Bildschirm existiert identisch in allen fünf Sprachen (English, Français, Deutsch, Español, Italiano); umschalten unter **Einstellungen → Sprache**.

![](assets/help/images/settings-language.jpg)

## 1. Erste Schritte

### Konto anlegen

Öffne die App und registriere dich mit E-Mail, Passwort (mindestens 8 Zeichen) und Anzeigenamen. Mit dem Augen-Button kannst du das Passwort beim Tippen ein- und ausblenden.

### Workspace anlegen — oder beitreten

Nach der Anmeldung bietet der Startbildschirm zwei Wege:

- **Workspace anlegen** — du wirst **Inhaberin**. Wähle Name, Land (bestimmt die Standardwährung) und Zeitzone. Danach zeichnest du deinen Grundriss im Editor (§7).
- **Workspace beitreten** — tippe die **Workspace-ID** ein, die man dir gegeben hat, oder wähle **QR-Code scannen** und richte die Kamera auf den Einladungs-QR an der Wand. Du trittst mit der Rolle bei, die die Einladung trägt (§2).

Ein Konto kann mehreren Workspaces angehören; wechsle unter **Einstellungen → Profile**. Alles in der App bezieht sich auf den aktiven Workspace.

## 2. Rollen & Einladungen

DesKilo hat drei additive Rollen plus ein Gerätekonto:

| Rolle | Kann |
|---|---|
| **Mitglied** | Ein-/auschecken, reservieren, Ausgaben einreichen, eigene Ereignisse und das eigene Konto sehen und verwalten |
| **Admin** | Alles, was ein Mitglied kann, plus: *für andere* handeln (Reservierungen, Zahlungen, Ausgaben — bestätigungspflichtig, §6), Ausgaben freigeben, Kiosk-Badges ausstellen |
| **Inhaberin** | Alles, was ein Admin kann, plus: den physischen Workspace bearbeiten, Tarife und Preise festlegen, Rollen, Kiosk-Geräte und Einstellungen verwalten |
| **Kiosk** | Ein Wandtablet-Konto (§9) — zeigt nur den Plan; echte Mitglieder handeln darüber mit einem Badge |

**Jede Einladung ist an eine Rolle gebunden.** Auf dem Bildschirm *Workspace-ID & QR* gibt es zwei Einladungen, jede mit eigenem QR-Code und Code:

- **Mitglieder-Einladung** — die Workspace-ID selbst. Drucken, an die Wand hängen, frei teilen: Wer sie scannt oder eintippt, tritt als einfaches Mitglied bei.
- **Admin-Einladung** — ein separater Geheimcode, nur für Inhaberinnen sichtbar. Nur an Personen geben, die den Workspace verwalten sollen: Wer ihn nutzt, tritt als Admin bei.

**Eine Inhaber-Einladung gibt es absichtlich nicht.** Inhaberschaft kann nur eine bestehende Inhaberin vergeben, unter *Mitglieder & Tarife*. Ein Workspace behält immer mindestens eine Inhaberin: Die App weigert sich, die letzte zu degradieren oder zu entfernen. **Admin**-Beförderungen und -Degradierungen laufen über den Validierungsfluss (§6) — sie greifen erst nach Bestätigung durch die Validierenden.

Der QR kodiert einen Link, der die vergebene Rolle nennt (`deskilo://join?role=…`). Manipulation am Link ändert nichts — der Server leitet die Rolle aus dem Geheimcode selbst ab.

## 3. Der Grundriss (Tab Plan)

Der Plan zeigt die aktive Etage: Büros, Tische und Plätze, farbcodiert — **frei**, **reserviert**, **besetzt**, **meiner**, **gesperrt**. Besetzte Plätze zeigen den Vornamen, ein **Check-Abzeichen**, wenn die Person eingecheckt ist, und einen **grünen Punkt**, wenn sie gerade in der App online ist.

Der Plan kann wie dein echter Raum aussehen: Die Inhaberin kann ein **Foto des Raums als Etagen-Hintergrund** hinterlegen und frei **skalierbare Illustrationsbilder** (Pflanzen, Sofas…) auf dem Raster platzieren. Ein Regler für die **Tisch-Transparenz** in den Einstellungen lässt das Foto durch die gezeichneten Tische durchscheinen.

Navigation:

- Die Fläche **passt sich automatisch** an deine Etage an, beim Öffnen und beim Drehen des Geräts; **zoome mit zwei Fingern** oder den **+ / −**-Buttons, ziehe die **Scrollbalken** an den Rändern, und tippe den **Einpassen**-Button zum Zentrieren.
- Wähle die Etage im **Etagen-Menü** (kompakte Auswahl); das Uhr-Symbol setzt die Zeitleiste auf **jetzt** zurück.
- Im **Querformat** wandern die Bedienelemente in eine Seitenleiste und der Plan füllt den Bildschirm — praktisch auf Tablets.

Buchen vom Plan aus:

- **Spontanes Einchecken**: Tippe einen freien Platz → das Formular schlägt *jetzt* bis zum Standard-Ende des Workspace vor → bestätigen. Hat jemand den Platz später reserviert, wird deine Endzeit gekappt und du erfährst es.
- **Einchecken auf Reservierung**: Deine Reservierung öffnet ein Check-in-Fenster. Checke vom Plan oder aus der Erinnerung ein. Bei Nichterscheinen wird der Platz nach der konfigurierten Frist **automatisch freigegeben**.
- **Auschecken**: manuell, oder automatisch zum Reservierungsende / bei Schließung.
- **Zeitleiste**: Wähle ein von→bis-Fenster (oder Vormittag / Nachmittag / Ganzer Tag, je nach Granularität), um die Belegung zu jedem künftigen Zeitpunkt zu sehen.
- Plätze können **Zubehör** tragen (Monitor, Stehpult…), teils mit Aufpreis je Halbtag, der auf deiner Abrechnung erscheint.
- Buchungen zählen gegen deine **Monatstage** (§8) — jenseits deines Tarifs blockt oder berechnet die App, je nachdem, was die Inhaberin für dich eingestellt hat.

## 4. Reservierungen (Reservieren-Hub)

Öffne den **Reservieren**-Hub (Mittelbutton). Eine Datumsleiste wählt den Tag, die Fenster-Chips die Zeit; dann vier Ansichten:

- **Plan** — der Grundriss, gefiltert auf dein Fenster; freier Platz antippen = buchen.
- **Tag** — jeder Platz als Zeitstrahl für den gewählten Tag; freie Strecke antippen = buchen, eigener Block = Details.
- **Woche** — ein Raster Platz × Tag für die ganze ISO-Woche; freie Halbtage auf einen Blick, Antippen bucht.
- **Monat** — ein Verfügbarkeitskalender: freie Tische pro Tag über alle Etagen; ein Tag öffnet seine Tagesansicht.

Reservierungen folgen der **Granularitätsregel** des Workspace — Halbtage, ganze Tage oder freie Zeiten auf dem Minutenraster der Inhaberin. Sie respektieren **Öffnungstage** und **Schließtage** sowie die Buchungsregeln (Vorlauf, Maximaldauer, Stornofrist). Wiederkehrender Bedarf? Buche eine **Serie** (täglich, werktags, wöchentlich) — geschlossene Tage und Konflikte werden übersprungen und gemeldet.

Der Tab **Kalender** zeigt deine Buchungen pro Monat — deine Tage **rot**, die der anderen **blau**, heute umkreist — mit Tages-Zeitstrahl. Im Querformat nutzen Kalender und Zeitstrahl das geteilte Layout.

## 5. Mitgliederverzeichnis (Tab Mitglieder)

Sieh, wer zu deiner Community gehört:

- Jede Karte zeigt **Foto** (oder Initiale), **Rolle**, **eigenen Status** („bis Freitag in Berlin…"), einen **Online/zuletzt-gesehen**-Indikator und einen **Reservierungs-Chip**: eingecheckter Platz, jetzt reserviert, oder die nächste Buchung.
- Antippen öffnet das **Detailblatt** — inklusive kommender Reservierungen.
- **Wische** über ein Mitglied, um es per **WhatsApp** anzuschreiben; der **Gruppen-Button** öffnet die WhatsApp-Gruppe der Community (von der Inhaberin hinterlegt).
- Eigenes Foto, Status und Telefon-Sichtbarkeit stellst du unter **Einstellungen** ein.

## 6. Ereignisse & Bestätigungen (Glocken-Symbol)

Der Ereignis-Feed ist die Prüfspur deines Workspace: Reservierungen erstellt/geändert/storniert, Zahlungen erfasst, Ausgaben eingereicht, Extra-Tage-Anfragen, Rollenwechsel. Mitglieder sehen ihre eigenen Ereignisse; Admins und Inhaberinnen alle.

**Das Bestätigungsprotokoll:** Wann immer ein Admin etwas *für jemand anderen* tut — einen Platz für dich bucht, deine Zahlung erfasst — bleibt es **offen, bis du bestätigst**. Offene Punkte sind oben angeheftet, mit Annehmen/Ablehnen, und du wirst benachrichtigt. Eigene Aktionen auf dich selbst brauchen nie eine Bestätigung.

**Validierungsquorum:** Für Geldfragen und Rollenwechsel legt die Inhaberin fest, *wer* zustimmen muss und *wie viele* Zustimmungen nötig sind. Unbeantwortete Anfragen verfallen nach 7 Tagen — nichts Kostspieliges wird je stillschweigend gewährt.

Die Inhaberin stellt das pro **Bereich** ein, unter **Einstellungen → Validierungsregeln**: Zahlungen, Ausgaben, Services, zusätzliche Halbtage, Rollenwechsel, Reservierungen und Anpassungen haben je eine eigene Regel (oder erben die Standardregel). Eine Regel legt die Zahl der nötigen Bestätigungen fest, *welche* Admins bestätigen dürfen (alle oder namentlich benannte) und ob die Inhaberin immer mitzeichnen muss.

![](assets/help/images/validation-rules.jpg)

 

![](assets/help/images/validation-rule-edit.jpg)

*Links: eine Regel pro Bereich, mit Vererbung von der Standardregel. Rechts: Bearbeiten einer Regel — nötige Bestätigungen, zugelassene Validierende, Mitzeichnung der Inhaberin.*

## 7. Für Inhaberinnen: Editor & Einstellungen

Die gesamte Administration liegt unter **Einstellungen → Administration**. Eine Regel muss man kennen: **Der Einstellungs-Eintrag einer Funktion erscheint nur, solange die Funktion aktiviert ist** — schalte *Online-Zahlungen* unter **Funktionen** aus und ihr Konfigurationsbildschirm verschwindet mit (und kommt beim Wiedereinschalten zurück). Der Eintrag **Funktionen** selbst ist immer da, sodass sich ein Modul jederzeit wieder einschalten lässt.

![](assets/help/images/settings-administration.jpg)

- **Editor** (App-Leiste): Zeichne deinen Raum auf einem Raster — Etagen, Büros, Tische, Plätze (mit Ausrichtung, Stuhltyp und Ausstattung), Platzsperren für Wartung. Füge pro Etage ein **Hintergrundfoto** und verschieb- und skalierbare **Illustrationsbilder** hinzu. Löschen mit künftigen Reservierungen erzwingt erst deren Auflösung.
- **Workspace-ID & QR**: deine rollengebundenen Einladungen (§2). Die generierte ID lässt sich durch eine merkbare ersetzen (4–20 Buchstaben/Ziffern), kopieren, und der QR als PNG teilen.
- **Verfügbarkeit**: Öffnungstage, Schließtage und die Granularität — freie Start-/Endzeiten, ein Minutenraster (5/15/30/60), Halbtage oder nur ganze Tage.
- **Funktionen**: Ganze Module pro Workspace ein-/ausschalten — Kalender, Ereignisse, Geld, Services, PDF-Export, Serienbuchung, Buchen für andere, Push, Platzsperren durch Admins, Zubehör-Aufpreise, **Online-Zahlungen**, **RFID-/NFC-Badges**. Ein ausgeschaltetes Modul entfernt *alle* seine Bildschirme und Buttons für jedes Mitglied.

![](assets/help/images/workspace-id-qr.jpg)

 

![](assets/help/images/availability-granularity.jpg)

 

![](assets/help/images/features-toggles-1.jpg)

 

![](assets/help/images/features-toggles-2.jpg)

- **Mitglieder & Tarife**: Tippe ein Mitglied an, um sein **Verwaltungsblatt** zu öffnen — einen Service für es hinzufügen, den Abo-Prozentsatz setzen, die **Mehrverbrauchs-Politik** (§8) wählen, die **gleichzeitigen Reservierungen** deckeln, **Badges** ausstellen (§9), zum Admin befördern/degradieren, das Konto zum **Kiosk-Gerät** machen oder die Mitgliedschaft pausieren.

![](assets/help/images/member-management-sheet.jpg)

 

![](assets/help/images/member-subscription.jpg)

 

![](assets/help/images/member-reservation-limit.jpg)

*Das Verwaltungsblatt, der Dialog für den Abo-Prozentsatz und die Reservierungsobergrenze pro Mitglied.*

- **Abrechnung**: Gebührenbänder für die Prozent-Abos, Mehrverbrauchssätze, wählbare Abo-Stufen (mit optionalem frei verhandeltem Wert) — und **Tagespakete** (Tage zum Festpreis) für Mitglieder mit Paket-Politik.
- **Services** und **Zubehör**: die Kataloge hinter §8 — von der Inhaberin definierte Extras (Schließfächer, Druck…) und Platz-Ausstattung mit optionalem Aufpreis je Halbtag. Beides sind schlichte Listen mit einem **+**-Button.

![](assets/help/images/billing-bands-levels-packages.jpg)

 

![](assets/help/images/services-catalog.jpg)

 

![](assets/help/images/services-new-service.jpg)

 

![](assets/help/images/accessories-catalog.jpg)

*Abrechnung (Bänder, Stufen, Tagespakete) · der Services-Katalog und sein Anlegeformular · der Zubehör-Katalog. Ein Admin erfasst einen Service-Konsum für ein Mitglied über dessen Verwaltungsblatt:*

![](assets/help/images/member-add-service.jpg)

- **Workspace-Einstellungen**: Name, Land/Währung, Zeitzone, Zahlungshinweise (IBAN, PayPal.me, Wero, Lydia, Wise), WhatsApp-Gruppenlink, **Tisch-Transparenz**, Exporte — und die **Gefahrenzone**: ein kompletter **Workspace-Reset** (löscht Buchungen, Geld und Grundriss; behält Konfiguration und Mitglieder), abgesichert durch das getippte „I agree".
- **Import/Export**: Die gesamte Konfiguration reist als **XML-Datei** — Backup, Vorlage oder Migration einer selbst gehosteten Instanz. Auch ein **Konfigurations-PDF** (Mitglieder, Plan, Preise, Funktionen) lässt sich erzeugen. Dateien werden **lokal auf deinem Gerät** gespeichert.

### Online-Zahlungen einrichten (Inhaberinnen)

Jede Community kassiert auf ihr **eigenes** Anbieterkonto; die App speichert die geheimen Schlüssel nie auf einem Gerät — sie liegen auf dem Server.

1. Öffne **Einstellungen → Online-Zahlungen** (nur Inhaberin).
2. Wähle einen Anbieter und füge seine Schlüssel aus dessen Dashboard ein:
   - **PayPal** — Client-ID, Secret, Umgebung (beginne mit *sandbox*), Webhook-ID, Rückkehr-URL (PayPal Developer → deine REST-App).
   - **Kreditkarte (Stripe)** — Secret Key, Webhook-Signaturgeheimnis, Rückkehr-URL (Stripe → API-Keys / Webhooks).
   - **Mollie** — API-Schlüssel, Rückkehr-URL (bietet iDEAL, Bancontact, Karten…).
   - **Wero (über Mollie)** — derselbe Mollie-API-Schlüssel, mit Wero im Mollie-Konto aktiviert.
3. **Speichern** — ein grünes *Eingerichtet* erscheint. Aktiviere die Funktion **Online-Zahlungen** (Einstellungen → Funktionen), dann sehen Mitglieder **Online bezahlen** auf einer offenen Rechnung. (Der Einstellungs-Eintrag *Online-Zahlungen* selbst erscheint nur, solange die Funktion eingeschaltet ist.)

![](assets/help/images/payment-config-paypal-stripe.jpg)

 

![](assets/help/images/payment-config-mollie-wero.jpg)

Ein gespeichertes Geheimnis wird nie wieder gezeigt — Feld leer lassen zum Behalten, tippen zum Ersetzen, **Entfernen** löscht den Anbieter. Die Gebühren sind die des Anbieters (typisch ~1,5–3 % pro Zahlung, keine Monatsgebühr); DesKilo kommt nichts hinzu, und der manuelle Überweisungs-/IBAN-Weg bleibt kostenlos.

Startet eine Zahlung nicht, aktiviere **Einstellungen → Erweitert → Entwicklermodus** und öffne den **Entwickler**-Bildschirm: die *payments*-Spur zeigt genau, welche Anbieter eingerichtet sind und welche Felder noch fehlen.

![](assets/help/images/developer-payment-traces.jpg)

#### Die Anbieter-Dashboards, Schritt für Schritt

Trenne **Test- und Live-Umgebung strikt**: jeder Anbieter hat je Modus eigene Schlüssel, und alle in DesKilo eingetragenen Schlüssel müssen zum selben Modus gehören. In den URLs unten ist `<project-ref>` die Referenz deines Supabase-Projekts (Selbst-Hoster verwenden die URL ihrer Instanz).

**PayPal**

1. Melde dich auf [developer.paypal.com](https://developer.paypal.com) an und öffne **Apps & Credentials**.
2. Schalte den **Sandbox/Live**-Schalter um — beginne in der *Sandbox*; wechsle erst für die Produktion auf *Live*. Das Feld *Umgebung* in DesKilo muss zu den Schlüsseln passen.
3. **Erstelle eine REST-API-App** — dadurch generiert das System **Client ID** und **Secret**.
4. Richte in der App einen **Webhook** ein: URL `https://<project-ref>.supabase.co/functions/v1/paypal-webhook`, abonniert mindestens auf *Payment capture completed* (plus *denied* / *order voided*). Kopiere die **Webhook-ID**. In DesKilo ist der Webhook nicht optional — er verbucht die Zahlung auf der Rechnung.
5. Trage Client ID, Secret, Umgebung, Webhook-ID und deine Rückkehr-URL unter **Einstellungen → Online-Zahlungen → PayPal** ein. Nichts davon landet in der App oder auf einem Gerät — alles wird serverseitig gespeichert.

**Stripe (Kreditkarten & Cartes Bancaires)**

1. Melde dich auf [dashboard.stripe.com](https://dashboard.stripe.com) an und öffne **Developers**.
2. Der Schalter **Testmodus / Livemodus** bestimmt, welche Schlüssel du siehst. DesKilo braucht nur den **Secret Key** — der Checkout wird serverseitig erstellt, der *Publishable Key* wird nicht verwendet.
3. Aktiviere unter **Settings → Payment methods** die gewünschten Kartennetze. **Zielt dein Space auf Frankreich? Aktiviere explizit Cartes Bancaires** — französische Mitglieder bevorzugen das CB-Netz häufig gegenüber dem internationalen Visa-/Mastercard-Routing.
4. Lege unter **Developers → Webhooks** den Endpunkt `https://<project-ref>.supabase.co/functions/v1/stripe-webhook` mit dem Ereignis `checkout.session.completed` an und kopiere das **Webhook-Signing-Secret**.
5. Trage Secret Key, Signing-Secret und deine Rückkehr-URL unter **Einstellungen → Online-Zahlungen → Kreditkarte (Stripe)** ein.

**Mollie (iDEAL, Bancontact, Wero…)**

1. Melde dich auf [my.mollie.com](https://my.mollie.com) an → **Developers → API keys** und kopiere den **Test-** oder **Live-API-Key** (der Modus steckt im Schlüssel selbst).
2. Aktiviere unter **Settings → Payment methods**, was deine Mitglieder sehen sollen: **iDEAL** (Niederlande), **Bancontact** (Belgien), Karten — und **Wero**, das Wallet der European Payments Initiative für Instant-Account-to-Account-Zahlungen in Deutschland, Frankreich und Belgien (der Nachfolger von Paylib und giropay).
3. In DesKilo sind **Mollie** und **Wero** zwei Anbieter-Karten mit demselben API-Key — eine Wero-Zahlung wird als Mollie-Zahlung mit der Wero-Methode erstellt. Konfiguriere, was deine Mitglieder sehen sollen.
4. Redirect- und Webhook-URLs setzt **DesKilo bei jeder Zahlung automatisch** (Redirect = deine Rückkehr-URL, Webhook = die Funktion `mollie-webhook`) — im Mollie-Dashboard ist nichts zu konfigurieren.

#### Weitere Zahlungsmethoden (Ausblick)

| Anbieter / Methode | Fokus | So passt es zu DesKilo |
|---|---|---|
| **Apple Pay / Google Pay** | Mobile Wallets, One-Tap-Checkout | Im Stripe- (oder Mollie-)Dashboard aktivieren — sie erscheinen automatisch auf der gehosteten Zahlungsseite, ohne Änderung in DesKilo und ohne zusätzliche Grundgebühr. |
| **Klarna** | Buy Now, Pay Later (BNPL) | Genauso: in Stripe/Mollie zuschalten und es erscheint beim Bezahlen — relevant bei höheren Beträgen. |
| **Adyen** | Enterprise & Omnichannel, eine API für fast alle Methoden | Nicht integriert — wäre ein neuer Anbieter in DesKilo (Beiträge willkommen). |
| **Braintree** | Mobile & Web Drop-in-UI (gehört zu PayPal) | Nicht integriert — DesKilos direkte PayPal-Integration deckt das Terrain bereits ab. |

### RFID-/NFC-Badges einrichten (Inhaberinnen)

Physische Karten ermöglichen Check-in per Antippen — ohne Handy.

1. Öffne **Einstellungen → RFID-/NFC-Badges** (nur Inhaberin). Schalte **NFC-Badge-Check-in aktivieren** ein und lies die **Gerätestatus**-Zeile — nötig ist ein **Android**-Gerät mit aktiviertem NFC (iPads haben kein NFC).
2. Gib jedem Mitglied eine Karte: **Mitglieder & Tarife → das Mitglied → Badges → Karte registrieren**, dann die Karte ans Gerät halten. Jede Karte mit lesbarem Chip passt (MIFARE, NTAG…).
3. Nutze sie an einem **Kiosk** (§9): das Mitglied tippt die Karte an, um zu reservieren oder einzuchecken. Eine verlorene Karte im selben Badges-Dialog widerrufen.

![](assets/help/images/nfc-config.jpg)

 

![](assets/help/images/member-badges-dialog.jpg)

*Der NFC-Konfigurationsbildschirm (Workspace-Schalter + NFC-Status dieses Geräts) und der Badges-Dialog eines Mitglieds: widerrufen, Karte registrieren oder einen neuen QR-Badge ausstellen.*

## 8. Geld (Tab Geld)

Dein Konto beantwortet *was schulde ich, was schuldet man mir* — und *wie viel kann ich noch buchen*:

- **Diesen Monat** — die Karte oben auf der Rechnung: wie viele **Tage** dein Abo diesen Monat enthält, wie viele **genutzt** sind, wie viele **übrig**, mit Fortschrittsbalken. Ein gebuchter Vormittag zählt 0,5 Tage. Das Monatskontingent folgt den Öffnungstagen des Workspace und deinem Prozentsatz.
- **Wenn deine Tage aufgebraucht sind**, entscheidet die Inhaberin pro Mitglied, was gilt:
  - **Gesperrt** (Standard) — keine weiteren Buchungen; frag einen Admin oder beantrage **zusätzliche Halbtage** direkt im Geld-Tab (Validierende genehmigen; gewährte Tage kosten weiter den Mehrverbrauchssatz).
  - **Nach Verbrauch** — du buchst weiter; jeder Extra-Tag kostet den Mehrverbrauchssatz deines Gebührenbands (auf der Karte angezeigt).
  - **Pakete** — tippe **Paket kaufen** und wähle eines der Tagespakete; deine Tage steigen sofort und der Preis landet auf der Monatsrechnung.
- **Belastungen**: Monatsabo (Prozent-Tarif), Mehrverbrauch, Service-Konsum, Zubehör-Aufpreise, Tagespakete.
- **Gutschriften**: genehmigte Ausgaben, erfasste Zahlungen, Anpassungen.
- **Abrechnungen**: monatlich, mit Status **beglichen / offen**, exportierbar als **PDF-Rechnung**, lokal gespeichert.
- **Zahlen**: DesKilo erfasst Zahlungen; offene Rechnungen zeigen die **Zahlungshinweise** des Workspace (IBAN mit einem Tipp kopiert, PayPal.me öffnet direkt). Erfasse eine Zahlung („ich habe gezahlt") mit Methode — die Gegenseite bestätigt. Hat der Workspace **Online-Zahlungen** aktiviert und ist sein Server dafür eingerichtet, lässt **Online bezahlen** den offenen Betrag sofort begleichen — per **PayPal, Kreditkarte (Stripe), Mollie oder Wero**, je nachdem was der Workspace aktiviert hat (mehrere zeigen eine Auswahl).
- **Ausgaben**: Kaffee für den Raum gekauft? Reiche die Ausgabe ein — ein anderer Admin genehmigt (keine Selbstgenehmigung) und der Betrag wird deiner nächsten Abrechnung gutgeschrieben.
- **Services**: von der Inhaberin definierte Extras (Schließfächer, Druck…), deren Konsum nach deiner Bestätigung auf der Abrechnung landet.

## 9. Kiosk-Modus (Wandtablet)

Häng ein Android-Tablet oder iPad neben die Tür und lass alle beim Reinkommen einchecken:

1. Die Inhaberin legt ein normales Konto für das Gerät an, lässt es dem Workspace beitreten und markiert es unter *Mitglieder & Tarife* als **Kiosk**. Ab dann ist dieses Konto auf den Vollbild-Grundriss festgenagelt — keine anderen Bildschirme, nichts sonst zu bedienen.
2. Die Inhaberin (oder ein Admin) gibt jedem Mitglied einen **Badge**, unter *Mitglieder & Tarife → ein Mitglied → Badges*. Zwei Arten:
   - **QR-Code** — **genau einmal** angezeigt; tippe **Als PDF speichern** für eine gedruckte Badge-Karte, oder speichere den QR auf dem Handy des Mitglieds.
   - **RFID/NFC-Karte** — tippe **Karte registrieren** und halte die physische Karte ans Gerät (Android mit NFC). Einrichtung unter *Einstellungen → RFID-/NFC-Badges* (§7).
   Jeder Badge ist jederzeit widerrufbar.
3. Am Kiosk: Platz antippen → **Einchecken**, **Reservieren** oder **Auschecken** → Badge vorzeigen: **RFID/NFC-Karte antippen**, QR mit einem USB/Bluetooth-Barcode-Scanner scannen oder Code eintippen.

Deine Identität existiert nur für den Moment der Operation: die Berechtigung geht einmal zum Server, die Buchung läuft **auf deinen Namen**, und auf dem Tablet wird nichts gespeichert — du bist „abgemeldet", sobald es fertig ist. (Kamera-QR-Scan und Anmeldung pro Vorgang mit Google/Facebook stehen noch auf der Roadmap; **iPads haben kein NFC**, dort ist der QR-Weg der richtige.)

## 10. Benachrichtigungen

Check-in-Erinnerungen, Freigaben bei Nichterscheinen, offene Bestätigungen, Ausgaben-Entscheide. Zustellung ist lokal zuerst; auf Android nutzt die F-Droid-Variante **UnifiedPush** (z. B. ntfy) statt Google-Diensten — nirgendwo Firebase.

## 11. Datenschutz

Minimale Daten: Name, E-Mail, Tarif, Buchungen, Konto. Du bestimmst dein Foto, deinen Status, ob dein Name auf dem Plan erscheint und ob deine Telefonnummer im Verzeichnis sichtbar ist. Kiosk-Badges werden nur als Hash gespeichert — ein verlorener Badge wird widerrufen, nicht erraten. Kein Tracking, keine Dritt-Analytik. Finanzhistorie wird bei Kontolöschung anonymisiert, nicht gelöscht (Aufbewahrungspflichten).

## 12. Plattformen

Android (Google Play und F-Droid), iPhone/iPad und Desktop — macOS, und Windows mit einem **MSI-Installer** aus jedem Release. Deine Daten folgen deinem Konto.
