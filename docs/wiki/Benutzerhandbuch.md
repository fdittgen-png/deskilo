# Benutzerhandbuch

Alles, was Mitglieder, Admins und Inhaberinnen brauchen, um DesKilo zu nutzen. *Andere Sprachen: [English](User-Guide) · [Français](Guide-utilisateur) · [Español](Guia-de-usuario) · [Italiano](Guida-utente).*

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

## 7. Für Inhaberinnen: Editor & Einstellungen

- **Editor** (App-Leiste): Zeichne deinen Raum auf einem Raster — Etagen, Büros, Tische, Plätze (mit Ausrichtung, Stuhltyp und Ausstattung), Platzsperren für Wartung. Füge pro Etage ein **Hintergrundfoto** und verschieb- und skalierbare **Illustrationsbilder** hinzu. Löschen mit künftigen Reservierungen erzwingt erst deren Auflösung.
- **Workspace-ID & QR**: deine rollengebundenen Einladungen (§2). Die generierte ID lässt sich durch eine merkbare ersetzen (4–20 Buchstaben/Ziffern).
- **Verfügbarkeit**: Öffnungstage, Schließtage und die Granularität — Halbtage, ganze Tage oder Minutenraster (15/30/60).
- **Funktionen**: Ganze Module pro Workspace ein-/ausschalten — Kalender, Ereignisse, Geld, Services, PDF-Export, Serienbuchung, Buchen für andere, Push, Platzsperren durch Admins, Zubehör-Aufpreise, **Online-Zahlungen**.
- **Mitglieder & Tarife**: Abo-Prozente zuweisen, je Mitglied die **Mehrverbrauchs-Politik** (§8) setzen, pausieren/austragen, Admin-Beförderungen anstoßen, **Kiosk-Geräte** markieren und **Badges** ausstellen (§9).
- **Abrechnung**: Gebührenbänder für die Prozent-Abos, Mehrverbrauchssätze, wählbare Abo-Stufen — und **Tagespakete** (Tage zum Festpreis) für Mitglieder mit Paket-Politik.
- **Workspace-Einstellungen**: Name, Land/Währung, Zeitzone, Zahlungshinweise (IBAN, PayPal.me, Wero, Lydia, Wise), WhatsApp-Gruppenlink, **Tisch-Transparenz**, Exporte — und die **Gefahrenzone**: ein kompletter **Workspace-Reset** (löscht Buchungen, Geld und Grundriss; behält Konfiguration und Mitglieder), abgesichert durch das getippte „I agree".
- **Import/Export**: Die gesamte Konfiguration reist als **XML-Datei** — Backup, Vorlage oder Migration einer selbst gehosteten Instanz. Auch ein **Konfigurations-PDF** (Mitglieder, Plan, Preise, Funktionen) lässt sich erzeugen. Dateien werden **lokal auf deinem Gerät** gespeichert.

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
- **Zahlen**: DesKilo erfasst Zahlungen; offene Rechnungen zeigen die **Zahlungshinweise** des Workspace (IBAN mit einem Tipp kopiert, PayPal.me öffnet direkt). Erfasse eine Zahlung („ich habe gezahlt") mit Methode — die Gegenseite bestätigt. Hat der Workspace **Online-Zahlungen** aktiviert und ist sein Server dafür eingerichtet, startet **Online mit PayPal bezahlen** eine echte PayPal-Zahlung über den offenen Betrag.
- **Ausgaben**: Kaffee für den Raum gekauft? Reiche die Ausgabe ein — ein anderer Admin genehmigt (keine Selbstgenehmigung) und der Betrag wird deiner nächsten Abrechnung gutgeschrieben.
- **Services**: von der Inhaberin definierte Extras (Schließfächer, Druck…), deren Konsum nach deiner Bestätigung auf der Abrechnung landet.

## 9. Kiosk-Modus (Wandtablet)

Häng ein Android-Tablet oder iPad neben die Tür und lass alle beim Reinkommen einchecken:

1. Die Inhaberin legt ein normales Konto für das Gerät an, lässt es dem Workspace beitreten und markiert es unter *Mitglieder & Tarife* als **Kiosk**. Ab dann ist dieses Konto auf den Vollbild-Grundriss festgenagelt — keine anderen Bildschirme, nichts sonst zu bedienen.
2. Die Inhaberin (oder ein Admin) stellt jedem Mitglied einen **Badge** aus: einen QR-Code, der **genau einmal** angezeigt wird — als Karte drucken oder aufs Handy nehmen. Badges lassen sich jederzeit widerrufen.
3. Am Kiosk: Platz antippen → **Einchecken**, **Reservieren** oder **Auschecken** → Badge vorzeigen. Ein USB/Bluetooth-Barcode-Scanner liest ihn sofort (er tippt den Code), oder gib den Code manuell ein.

Deine Identität existiert nur für den Moment der Operation: Der Badge-Code geht einmal zum Server, die Buchung läuft **auf deinen Namen**, und auf dem Tablet wird nichts gespeichert — du bist „abgemeldet", sobald es fertig ist. Kamera-Scan, NFC-Badges (Android — iPads haben keine NFC-Hardware) und die Anmeldung pro Vorgang mit Google/Facebook stehen auf der Roadmap.

## 10. Benachrichtigungen

Check-in-Erinnerungen, Freigaben bei Nichterscheinen, offene Bestätigungen, Ausgaben-Entscheide. Zustellung ist lokal zuerst; auf Android nutzt die F-Droid-Variante **UnifiedPush** (z. B. ntfy) statt Google-Diensten — nirgendwo Firebase.

## 11. Datenschutz

Minimale Daten: Name, E-Mail, Tarif, Buchungen, Konto. Du bestimmst dein Foto, deinen Status, ob dein Name auf dem Plan erscheint und ob deine Telefonnummer im Verzeichnis sichtbar ist. Kiosk-Badges werden nur als Hash gespeichert — ein verlorener Badge wird widerrufen, nicht erraten. Kein Tracking, keine Dritt-Analytik. Finanzhistorie wird bei Kontolöschung anonymisiert, nicht gelöscht (Aufbewahrungspflichten).

## 12. Plattformen

Android (Google Play und F-Droid), iPhone/iPad und Desktop — macOS, und Windows mit einem **MSI-Installer** aus jedem Release. Deine Daten folgen deinem Konto.
