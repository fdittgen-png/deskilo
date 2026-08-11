# Benutzerhandbuch

Alles, was Mitglieder, Admins und Inhaber brauchen, um DesKilo zu nutzen. *Andere Sprachen: [English](User-Guide) · [Français](Guide-utilisateur) · [Español](Guia-de-usuario) · [Italiano](Guida-utente).*

> Die Screenshots in diesem Handbuch zeigen die App auf Französisch — jeder Bildschirm existiert identisch in allen fünf Sprachen (English, Français, Deutsch, Español, Italiano); umschalten unter **Einstellungen → Sprache**.
>
> <img src="images/settings-language.jpg" width="200">

## 1. Erste Schritte

### Konto anlegen

App öffnen und mit E-Mail, Passwort (8+ Zeichen) und Anzeigenamen registrieren — oder **mit Google fortfahren**. Das Auge zeigt oder verbirgt das Passwort beim Tippen, *Passwort vergessen?* schickt einen Zurücksetz-Link. Eine Google-Anmeldung lässt sich später unter **Einstellungen → Verknüpfte Konten** an ein bestehendes E-Mail-Konto anhängen.

### Workspace anlegen — oder beitreten

Nach der Anmeldung bietet der Startbildschirm zwei Wege:

- **Workspace anlegen** — du wirst **Inhaber**. Name, Land (bestimmt die Standardwährung) und Zeitzone wählen; danach zeichnest du deinen Grundriss im Editor (§8).
- **Workspace beitreten** — die geteilte **Workspace-ID** eintippen, oder **QR-Code scannen** und die Kamera auf den Einladungs-QR an der Wand richten. Du trittst mit der Rolle bei, die die Einladung trägt (§2).

### Profile — ein Konto, mehrere Spaces

Ein Konto kann mehreren Workspaces angehören. **Einstellungen → Profile** listet alle: jede Zeile zeigt den Namen des Space, **deine Rolle dort** (Mitglied, Admin, Inhaber) und die Workspace-ID. Das **Häkchen** markiert das aktive Profil; der **Stern** dein **Standardprofil** — das, mit dem die App öffnet, auf jedem Gerät und selbst nach Neuinstallation (die Wahl ist beim Konto gespeichert). Zeile antippen zum Wechseln, **+ Profil hinzufügen** für einen weiteren Space. Alles in der App ist auf den aktiven Workspace beschränkt.

### Orientierung

Die App hat fünf Ziele am unteren Rand: **Plan** (§3), **Kalender** (§5), den großen zentralen **Reservieren**-Knopf (§4), **Mitglieder** (§6) und **Finanzen** (§9). Zwei Icons wohnen in jeder Kopfzeile: die **Glocke** öffnet den Ereignis- und Bestätigungs-Feed (§7, mit Zähler) und das **Zahnrad** die **Einstellungen** (§12). Quer gehalten und auf Tablets wechseln die meisten Bildschirme in eine **geteilte Ansicht** — Bedienelemente im Seitenpanel, Inhalt füllt den Rest.

**Alles bleibt live.** Was irgendjemand ändert — eine Buchung, ein neues Mitglied, eine Einstellung — wird binnen Sekunden auf jedes verbundene Gerät geschoben, auch auf das, das die Änderung machte. Kein Neustart, kein Ziehen zum Aktualisieren.

## 2. Rollen & Einladungen

DesKilo hat drei additive Rollen plus ein Gerätekonto:

| Rolle | Kann |
|---|---|
| **Mitglied** | Ein-/auschecken, reservieren, Ausgaben einreichen, eigene Ereignisse und eigenes Konto sehen und verwalten |
| **Admin** | Alles wie ein Mitglied, plus: *für jeden* handeln (Buchungen, Zahlungen, Ausgaben — unter Bestätigung, §7), Ausgaben genehmigen, Badges ausstellen |
| **Inhaber** | Alles wie ein Admin, plus: den physischen Space bearbeiten, Pläne und Preise definieren, Rollen, Kiosk-Geräte und Einstellungen verwalten |
| **Co-Inhaber** | *Aktiv*: die Inhaber-Berechtigungen sofort, plus automatische Nachfolge. *Passiv*: ein wartender Nachfolger ohne Extra-Berechtigungen heute |
| **Kiosk** | Ein Wandtablet-Konto (§10) — zeigt nur den Plan; echte Mitglieder handeln per Badge |

Wer was darf, ist nicht in Stein gemeißelt: die Inhaberin justiert es in der **Rollenverwaltung** (§8).

**Jede Einladung ist an eine Rolle gebunden.** Auf dem Inhaber-Bildschirm *Workspace-ID & QR* tragen zwei Tabs zwei Einladungen, jede mit eigenem QR und Code:

- **Mitglieder-Einladung** — die Workspace-ID selbst, unter dem Namen des Space. Drucken, an die Wand, frei teilen: Wer sie scannt oder eintippt, tritt als einfaches Mitglied bei. Schaltflächen: **ID kopieren**, **Als PNG teilen**, **Workspace-ID ändern** (die generierte ID durch eine merkbare ersetzen, 4–20 Buchstaben/Ziffern) und **Jemanden einladen**.
- **Admin-Einladung** — ein **persönlicher Einmal-Code**, von einem Inhaber für genau eine Person geprägt. Der Bildschirm sagt es klar: *dieser Code lässt EINE Person als Admin ein, dann verfällt er* (ungenutzte Codes nach 14 Tagen). Nur an die gemeinte Person geben; pro Admin einen neuen mit **Neuer Admin-Code**.
- **Einladungen sprechen die Sprache des Eingeladenen** — das Einladungsblatt schreibt die Nachricht in der gewählten Sprache (fünf verfügbar), standardmäßig in der **Workspace-Sprache** aus den *Workspace-Einstellungen*. Die Inhaberin kann den Einladungstext dort auch **pro Sprache** anpassen, mit Platzhaltern wie `{firstName}`, `{workspaceName}`, `{inviteLink}`, `{downloadUrl}`, `{role}`; eine leere Sprache nutzt die eingebaute Übersetzung.

**Eine Inhaber-Einladung gibt es nicht — mit Absicht** (die Fußzeile erinnert daran). Inhaberschaft vergibt nur ein bestehender Inhaber, in *Mitglieder & Pläne*. Ein Workspace behält immer mindestens einen Inhaber. Einen **Admin** ernennen oder zurückstufen läuft über die Validierung (§7) — wirksam, sobald die Validierer bestätigen.

**Co-Inhaber halten den Workspace am Leben.** Die Inhaberin ernennt jedes Mitglied oder jeden Admin zum Co-Inhaber (*Mitglieder & Pläne → das Mitglied → Co-Inhaberschaft*), in zwei Varianten: ein **aktiver** Co-Inhaber arbeitet sofort mit Inhaber-Berechtigungen; ein **passiver** hat heute keine zusätzlichen. In beiden Fällen ist die Nachfolge automatisch: Verlässt der letzte Inhaber den Space — Austritt, Entfernung, Konto weg — wird der beste Co-Inhaber (aktiv vor passiv) **sofort Inhaber**, serverseitig, ohne Zutun. Übergabe geht auch jederzeit bewusst mit *Jetzt zum Inhaber machen*. Eine Nuance: Validierungsregeln, die die Unterschrift des *Inhabers* verlangen (§7), meinen immer einen buchstäblichen Inhaber, keinen aktiven Co-Inhaber.

Der QR codiert einen Link, der die vergebene Rolle nennt (`deskilo://join?role=…`). Manipulation ändert nichts — der Server leitet die Rolle aus dem Code selbst ab: die Workspace-ID tritt immer als Mitglied bei, eine persönliche Einladung genau in ihrer geprägten Rolle, einmal. Ein weitergeleiteter, schon benutzter — oder verfallener — Admin-Code lässt niemanden ein.

**Per Nachricht einladen** (*Jemanden einladen*): jeder WhatsApp/SMS/Teilen-Versand prägt seinen eigenen persönlichen Einmal-Code und baut eine fertige Nachricht in der Sprache des Eingeladenen. Der Empfänger kann die ganze Nachricht kopieren und ins Beitrittsfeld der App einfügen — der Code wird automatisch erkannt.

## 3. Der Grundriss (Plan-Tab)

Der Plan zeigt die aktive Ebene deines Space: Büros, Tische und Plätze, farbcodiert — **frei**, **reserviert**, **besetzt**, **meiner**, **gesperrt**. Er öffnet **sofort mit den letzten bekannten Daten** und aktualisiert im Hintergrund — bei wackligem WLAN siehst du den letzten Stand statt eines leeren Bildschirms. Besetzte Plätze zeigen den Vornamen, ein **Häkchen-Badge** nach dem Einchecken und einen **grünen Punkt**, wenn die Person gerade online ist. Ist ein **ganzer Tisch, Raum oder eine Etage** reserviert, sagt es der Raum selbst — farbige Fläche, kräftiger Rand und ein **Schloss-Chip mit dem Namen** in der Mitte; das Raumlabel liest *Bureau 2 · Florian*. Jeder sieht es: auf dem Plan, im Reservieren-Hub, am Kiosk.

Der Plan kann wie dein echter Raum aussehen: die Inhaberin kann ein **Foto des Raums als Ebenen-Hintergrund** setzen und frei **skalierbare Illustrationsbilder** (Pflanzen, Sofas…) platzieren. Der Regler **Tisch-Transparenz** in den Einstellungen lässt das Foto durch die gezeichneten Tische scheinen.

Navigation:

- Oben: der **Karte/Liste**-Umschalter (die Liste zeigt dieselben Plätze als Zeilen), der **Datums-Chip** (antippen für einen anderen Tag) und drei **Tageszeit-Chips** — Vormittag, Nachmittag, ganzer Tag — als Filter.
- Die Leinwand **passt sich automatisch ein**; **Pinch-Zoom** oder **+ / −**, **Scrollleisten** an den Rändern, **Einpassen**-Knopf zum Zentrieren.
- Die Etage wählst du am **Ebenen-Rail** rechts (1, 2, …); sein **Ebenen-Icon** wirkt auf die ganze Etage (unten). Im **Querformat** wandern die Bedienelemente in ein Seitenpanel.

Vom Plan aus buchen:

- **Spontan einchecken**: freien Platz antippen → das Blatt schlägt *jetzt* bis zum Standard-Tagesende vor → bestätigen. Hat jemand den Platz später reserviert, wird dein Ende gekappt und du erfährst es.
- **Auf eine Reservierung einchecken**: Einchecken heißt *du bist da* — das Fenster öffnet **15 Minuten vor** deinem Start und schließt am Ende der Reservierung. Außerhalb ist der Knopf deaktiviert und nennt die Öffnungszeit; ein Zukunftszeitpunkt bietet nie ein Live-Einchecken. Admins können ein Mitglied an seinem Platz einchecken (solange *für andere buchen* aktiv ist).
- **Auschecken**: manuell — oder, mit **Auto-Ein-/Auschecken**, schließen vergessene Buchungen sich am Tagesende selbst: nie berührte zählen von Start bis Ende, vergessene Auscheckvorgänge enden mit der Reservierung.
- **Ganze Räume**: **Doppeltipp** auf Tisch, Raum oder freien Boden — oder das **Ebenen-Icon** am Rail — für **den ganzen Tisch, das Büro oder die Etage**: das Blatt nennt die Ebene, zeigt den Zeitraum, lässt Admins **Für das Mitglied** wählen und bestätigt mit **Ebene reservieren**. Gleicher Zeitraum-Picker, gleiche Wiederholungen wie ein Platz.
- **Zeit-Scroller**: ein von→bis-Fenster (oder Vormittag / Nachmittag / Ganztag, je nach Granularität) zeigt die Belegung zu jedem künftigen Zeitpunkt.
- Plätze können **Zubehör** tragen (Monitor, Stehpult…), manches mit Aufpreis je halbem Tag auf deiner Abrechnung.
- Buchungen zählen auf deine **Monatstage** (§9) — darüber hinaus blockt oder berechnet die App, je nach Konfiguration.

## 4. Reservierungen (Reservieren-Hub)

Öffne den **Reservieren**-Hub (Mittelknopf). Oben: die vier **Ansichts-Knöpfe**, der **Datums-Chip**, der **QR-Scan** (darunter, §4a), die **Tageszeit-Chips** und die **Etagen-Chips** (*Alle Etagen* oder eine je Ebene). Dann vier Ansichten:

- **Plan** — der Grundriss, gefiltert auf dein Fenster; freien Platz antippen und buchen.
- **Tag** — jeder Platz als Zeitleisten-Zeile für den gewählten Tag (08:00 → 17:00 oder deine Zeiten, die rote Linie ist *jetzt*); freie Strecke antippen zum Buchen, den eigenen Block für Details.
- **Woche** — ein Raster Plätze × Tage für die ISO-Woche, ein Tagesband (*Mo 3 … So 9*) darüber; jede Zelle trägt die Halbtage mit der Initiale des Belegers.
- **Monat** — ein Verfügbarkeitskalender: jeder Tag zeigt seinen **Frei-Zähler** (z. B. *10/12*); Tag antippen führt in dessen Tagesansicht.

**Ein Platz zur Zeit**: du hältst nur eine aktive Reservierung je Zeitfenster — woanders buchen oder einchecken, während eine läuft, wird abgelehnt; Einchecken schließt frühere Check-ins, deren Buchung endete. Admins und Inhaber können **übersteuern**: ein besetzter/reservierter Platz bietet *Reservierung entfernen (übersteuern)* — Mitglied und alle Admins werden über den Feed benachrichtigt.

Reservierungen folgen der **Granularität** des Space (§8 Verfügbarkeit) — Halbtage, nur ganze Tage, echte Uhrzeiten (exakt von–bis, Halb-/Ganztag als Kurzwahl) oder freie Zeiten auf dem Raster. Halb- und Ganztage decken die **Arbeitszeiten** ab (Standard 8:00–17:00, Halbtagsgrenze 12:00). Sie respektieren **Öffnungstage**, **Schließtage** und die Buchungsregeln (Horizont, Maximaldauer, Stornofrist). Wiederkehrender Bedarf? Eine **Serie** buchen (täglich, werktags, wöchentlich) — geschlossene Tage und Konflikte werden übersprungen und gemeldet.

**Eine vergangene oder eingecheckte Buchung zu löschen ist ein Antrag, keine Aktion.** Eine Buchung mit vergangenem Start — oder mit Check-in — lässt sich nicht direkt stornieren: das Blatt bietet **Löschung beantragen**. Inhaber oder Admin entscheiden die eine Abrechnungsfrage: Check-in vergessen (die Buchung bleibt) oder nie genutzt (sie wird entfernt)? Der Antrag erscheint im Ereignis-Feed mit deinem optionalen Grund; künftige unberührte Buchungen behalten das Ein-Tipp-Storno.

### 4a. Einen Raumcode scannen

Jeder Platz, Tisch, jedes Büro und jede Etage kann eine gedruckte **QR-Karte** tragen (§8). **Scan-Knopf** im Hub, Karte anvisieren — oder Code eintippen — und die App identifiziert den Raum und zeigt genau, was *du* dort darfst:

- **Platz-Karte** — genau diesen Platz reservieren oder einchecken, sofort.
- **Tisch-Karte** — die Plätze des Tischs mit Live-Zustand; einen freien wählen.
- **Büro- oder Etagen-Karte** — wenn die Inhaberin ihn buchbar machte, *Büro- & Etagenreservierungen* aktiv ist **und** du das persönliche Recht hältst (§8) — Inhaber und Admins immer — reservierst du das **ganze Büro oder die Etage** — gleicher Zeitraum-Picker, gleiche **Serien**; der Preis je Halbtag wird gezeigt und landet auf deiner Abrechnung. Sonst erklärt das Blatt warum, und ein Büro fällt auf seine Plätze zurück.

**Konflikte schützen in beide Richtungen:** ein Büro/eine Etage ist nicht reservierbar, solange ein Platz darin im Fenster belegt ist — und kein Platz, solange sein Büro/seine Etage als Ganzes reserviert ist.

## 5. Kalender (Kalender-Tab)

Der Monat auf einen Blick, mit zwei Reichweiten und zwei Formen:

- **Meine / Alle** — deine eigenen Buchungen oder die der ganzen Community. Die Punkte unter einem Tag sagen alles auf einen Blick: **rot** = du hast eine Buchung, **blau** = andere Mitglieder haben eine, **beide Punkte** = beides. Heute ist umringt.
- Der **Form-Umschalter** daneben wechselt die untere Hälfte zwischen **Wochenraster** (Plätze × Tage) und **Agenda-Liste** (jede Reservierung als Karte: Zeitfenster, Mitglied, Raum).
- Die **Etagen-Chips** filtern beide Formen.
- Einen Tag antippen lädt ihn unten. Im Querformat geteilte Ansicht.

## 6. Mitgliederverzeichnis (Mitglieder-Tab)

Sieh, wer zur Community gehört:

- Jede Karte zeigt **Foto** (oder Initiale), **Rollen-Chip**, **Status** („bis Freitag in Berlin…"), einen **online / zuletzt gesehen**-Indikator (*Online*, *10 min*, *2 T*) und einen **Reservierungs-Chip**: eingecheckter Platz, *Jetzt reserviert* oder nächste Buchung.
- Ein Mitglied antippen öffnet das **Detailblatt** — Rolle, Präsenz, **kommende Reservierungen**, **Nachrichten**.
- **Nachrichten**: ein **Unterhaltungs-Thread** pro Mitglied (bis 500 Zeichen je Nachricht) — vom Mitgliedsblatt oder dem Verzeichnis-Profil aus öffnen, den ganzen Austausch als Sprechblasen lesen und an derselben Stelle senden. Jede Nachricht wird als Push und Benachrichtigung mit deinem Namen und Text zugestellt. In den *Einstellungen* kannst du — sobald deine WhatsApp-Nummer geteilt ist — zusätzlich wählen, **deine Nachrichten auf WhatsApp zu erhalten**: der Text kommt so an, wie ihn der Messenger liest, jede Reservierungs-/Raum-Referenz als antippbarer Web-Link, plus ein DesKilo-Link, der **die App direkt auf der Unterhaltung öffnet**. Der volle Text bleibt unter **Ereignisse → Nachrichten** lesbar, für Empfänger und Absender (der Push selbst trägt keinen Inhalt, aus Datenschutz). Admins haben ein **Alle Admins benachrichtigen**-Megafon in der Kopfzeile, das jeden Admin samt Inhaber erreicht. Abschaltbar über *Mitglieder-Benachrichtigungen*. Beim Schreiben lassen sich per Chip **eine Reservierung oder ein laufender Check-in — eigene wie die anderer Mitglieder** — oder **ein Raum** (Sitz, Tisch, Büro oder Etage) **verlinken** — die Referenz erscheint beidseitig als antippbarer Link: ein Reservierungs-Link öffnet diese Reservierung, ein Raum-Link das Buchungsblatt des Raums, ideal um eine künftige Buchung zu besprechen.
- Das **Nachrichten-Icon** einer Karte schreibt dem Mitglied auf **WhatsApp** (wenn es seine Nummer teilt); der **Gruppen-Knopf** öffnet die WhatsApp-Gruppe der Community.
- Eigenes Foto, Status und Nummern-Sichtbarkeit in den **Einstellungen** (§12).
- Admins und Inhaber sehen zusätzlich die **E-Mail** jedes Mitglieds — einfache Mitglieder nicht: Kontakt bleibt die Opt-in-WhatsApp-Nummer.

## 7. Ereignisse & Bestätigungen (Glocke)

Der Ereignis-Feed ist die Prüfspur deines Space: Buchungen erstellt/geändert/storniert, Zahlungen erfasst, Rechnungen bezahlt, Ausgaben eingereicht, Extratage-Anträge, Rollenwechsel, Löschanträge. Mitglieder sehen ihre eigenen Ereignisse; Admins und Inhaber alles. **Filter-Chips** (Alle · Reservierung · Zahlung · Ausgabe · …) engen die Liste ein; jede Zeile trägt ihr Status-Icon — **Sanduhr** wartend, **grünes Häkchen** bestätigt — und Geld-Ereignisse zeigen *wer wann validierte* direkt auf der Zeile.

**Wartet auf deine Bestätigung:** Handelt ein Admin *für jemand anderen* — bucht dir einen Platz, erfasst deine Zahlung, stuft einen Admin zurück — bleibt es **bis zur Bestätigung offen**. Offenes ist oben angepinnt mit rotem ✕ und grünem **Annehmen**, plus Benachrichtigung. Eigene Aktionen auf dich selbst brauchen nie eine Bestätigung.

**Nachrichten:** die Glocke sammelt auch deine Mitglieder-Nachrichten (§6) — empfangen und gesendet, neueste zuerst. Die Liste zeigt nur die **ersten 64 Zeichen**; **antippen** (oder **nach rechts wischen**) öffnet die **Unterhaltung** mit diesem Mitglied — der ganze Austausch als Sprechblasen, Emojis und Referenz-Links aktiv (ein Reservierungs-Link öffnet diese Reservierung, ein Raum-Link das Buchungsblatt — beide mit einem *Auf dem Plan zeigen*-Sprung), der Verfasser direkt darunter; ein Broadcast öffnet als einzelne Nachricht. **Nach links wischen** = löschen (langes Drücken einer Sprechblase löscht auch im Thread) — Löschen fragt immer erst **zur Bestätigung** (ein empfangener Alle-Admins-Broadcast lässt sich nicht löschen — er verschwände für alle).  **Ungelesene Nachrichten sind fett mit Punkt**; der **Ungelesen**-Chip filtert die Liste, und gelesen ist eine Nachricht erst, wenn ihre **Unterhaltung** geöffnet wird — der Blick auf den Posteingang zählt nicht. Eigene Nachrichten tragen neben der Zeit ein kleines Häkchen: **grau = zugestellt**, **blau = gelesen** (ein Broadcast an alle Admins bleibt grau — er hat viele Leser). Ungelesene zählen auf Glocke und App-Icon.

**Validierungsquorum:** für Geld und Rollen definiert die Inhaberin, *wer* zustimmen muss und *wie viele*. **Niemand validiert das eigene Ereignis** — nur eine andere Person; ohne anderen Validierer wartet der Antrag. Unbeantwortetes verfällt nach 7 Tagen — nichts Teures wird still gewährt, nichts selbst gewährt.

Die Inhaberin justiert das je **Domäne** unter **Einstellungen → Validierungsregeln** — eine Karte pro Ereignistyp, erbend von der **Standardregel** bis zur Bearbeitung: *Standardregel, Zahlung, Ausgabe, Service, Extra-Halbtage, Buchungslöschung, Rollenwechsel, Neues Mitglied, Reservierung, Ganzraum-Reservierungen, Rechnungszahlung, Anpassung* — und **Restbetrag-Stornierungen** fahren im selben Rahmen. Eine Regel setzt die nötigen Validierungen, *welche* Admins validieren dürfen (alle oder benannte) und ob der Inhaber immer unterschreiben muss.

<p><img src="images/validation-rules.jpg" width="240"> <img src="images/validation-rule-edit.jpg" width="240"></p>

## 8. Für Inhaber: Editor & Einstellungen

Alle Administration wohnt unter **Einstellungen → Administration** — *Coworking-Space* (die Workspace-Einstellungen), *Mitglieder & Pläne*, *Rollenverwaltung*, *Abrechnung & Berichte* (der Rechnungs-Hub mit Report-Editor und Mahnregeln in der Kopfzeile), *Zubehör*, *Verfügbarkeit*, *Funktionen* und die feature-abhängigen Einträge (Online-Zahlungen, RFID/NFC-Badges…). Eine Regel: **der Einstellungs-Eintrag einer Funktion erscheint nur, solange sie aktiviert ist** — *Online-Zahlungen* in **Funktionen** aus, und ihr Konfigurationsbildschirm verschwindet (und kommt beim Reaktivieren zurück). **Funktionen** selbst ist immer da.

<p><img src="images/settings-administration.jpg" width="240"></p>

### Der Space-Editor

Den **Editor** öffnest du aus der Kopfzeile des Plan-Tabs. Der **Space-Editor** listet die Etagen — ziehen zum Umordnen, das **Ebenen-Icon** markiert eine Etage *als Ganzes buchbar*, das **⋮**-Menü benennt um oder löscht, **+ Etage hinzufügen** erweitert. Eine Etage öffnen und mit der Werkzeugleiste zeichnen — **Auswahl · Büro · Tisch · Platz · Bild · Löschen**:

- Ein **Büro** bekommt Namen, *als Ganzes buchbar* und einen **Preis je Halbtag**.
- Ein **Tisch** bekommt Namen und dieselbe Ganztisch-Option.
- Ein **Platz** bekommt Namen, **Sitzrichtung** (↑ → ↓ ←), optionalen **Stuhltyp**, sein **Zubehör** (je mit optionalem Halbtags-Aufpreis) und **Gesperrt (Wartung)**.
- **Bild** platziert eine skalierbare Illustration; das Foto-Icon setzt das **Hintergrundfoto** der Ebene.
- Löschen mit künftigen Buchungen verlangt erst deren Auflösung.

### Workspace-ID & QR

Die rollengebundenen Einladungen (§2): Mitglieder-Einladung = die Workspace-ID (ersetzbar, kopierbar, QR als PNG), Admin-Einladung = persönliche Einmal-Codes.

### Verfügbarkeit

- **Öffnungstage** — Chips Mo…So.
- **Buchungsgranularität** — *freier Zeitraum*, *5/15/30/60-Minuten-Raster*, *Halbtage (Vormittag & Nachmittag)*, *nur ganze Tage* oder *echte Uhrzeiten* (exakt von–bis, Halb-/Ganztag als Kurzwahl).
- **Arbeitszeiten** — Tagesbeginn, Halbtagsgrenze, Tagesende (Standard 08:00 / 12:00 / 17:00). Halb- und Ganztags-Slots überall — Buchen, Einchecken, Abrechnen — folgen diesen Zeiten; unter *echten Uhrzeiten* legst du auch fest, wie viele Stunden als halber und ganzer Tag abrechnen.
- **Schließtage** — datierte Ausnahmen, per **+**.

### Funktionen

Ganze Module je Workspace ein- oder ausschalten — jeder Schalter trägt seine Beschreibung: Kalender-Tab, Ereignisse-Tab, Finanzen-Tab, Services, Zubehör-Aufpreise, Online-Zahlungen, Rechnungen, Admins stellen Rechnungen aus, PDF-Export, Serienbuchung, für andere buchen, Push-Benachrichtigungen, Admins dürfen Plätze sperren, Tisch-/Büro-/Etagen-Reservierungen, Admins dürfen Etagen zuweisen, Kiosk-Modus, RFID/NFC-Badges, Mitgliederverzeichnis, WhatsApp-Integration, Raum-QR-Codes, Co-Inhaber, Auto-Ein-/Auschecken, Datenexport (Excel), Arbeitszeiten, Rechnungs-PDF-Vorlage, Mitglieder-Benachrichtigungen, Dokumentbibliothek, Zahlungserinnerungen (Mahnwesen), Mitglieder-Berichte, Buchungslöschanträge, Rollenverwaltung. Ein Modul aus = *alle* seine Bildschirme und Knöpfe verschwinden für jedes Mitglied.

Die Liste ist **hierarchisch**: eine Funktion, die eine andere braucht, sitzt eingerückt darunter mit *Benötigt…*, ausgegraut solange der Elternteil aus ist — *Finanzen* trägt Services, Aufpreise, Online-Zahlungen und Rechnungen; *Rechnungen* die Admin-Delegation, die PDF-Vorlage und die Mahnungen; *Kiosk-Modus* die Badges; *Verzeichnis* die WhatsApp-Integration. Elternteil aus = ganzer Teilbaum weg; die gespeicherte Wahl des Kindes kehrt unversehrt zurück.

<p><img src="images/workspace-id-qr.jpg" width="220"> <img src="images/availability-granularity.jpg" width="220"> <img src="images/features-toggles-1.jpg" width="220"> <img src="images/features-toggles-2.jpg" width="220"></p>

### Mitglieder & Pläne

Ein Mitglied antippen öffnet sein **Verwaltungsblatt** — jede Mitglieds-Aktion an einem Ort: **Finanzvereinbarung senden** (§11d), **Nachrichten**, **Service hinzufügen** (Service, Menge, Abrechnungsmonat → *zur Bestätigung einreichen*), **Abonnement** (der Prozentsatz), **Wenn die Tage aufgebraucht sind** (die Überziehungs-Politik, §9), **Reservierungslimit**, **Darf Tisch, Büro oder Etage als Ganzes reservieren**, **Badges** (§10), **Zum Admin ernennen** (validiert, §7), **Co-Inhaberschaft**, **In Kiosk verwandeln**, **Mitgliedschaft pausieren**. Jede Zeile zeigt die **E-Mail** unter dem Namen.

<p><img src="images/member-management-sheet.jpg" width="220"> <img src="images/member-subscription.jpg" width="220"> <img src="images/member-reservation-limit.jpg" width="220"></p>

### Abrechnung

- **Tarifstufen** — die Preisleiter der Prozent-Abos: jede Stufe nennt *ab X %*, *bis Y %*, die monatliche **Gebühr** und den **Überziehungssatz** je Extra-Halbtag. **+ Stufe hinzufügen** verlängert die Leiter.
- **Abo-Stufen** — welche Prozentsätze Mitglieder wählen dürfen (Chips: 25 % · 50 % · 75 % · 100 % plus eigene), und ein Schalter **frei verhandelter Wert**.
- **Tagespakete** — Tage für einen Preis (Name · Tage · Preis), je mit Aktivierungs-Schalter; Mitglieder mit *Paket*-Politik kaufen sie, wenn ihre Tage ausgehen.

### Services und Zubehör

Die Kataloge hinter §9 — Extras der Inhaberin (Schließfächer, Druck…, je mit Preis und optionalem MwSt-Satz) und Platz-Ausstattung mit optionalen Halbtags-Aufpreisen. Zwei einfache Listen mit **+**.

<p><img src="images/billing-bands-levels-packages.jpg" width="220"> <img src="images/services-catalog.jpg" width="220"> <img src="images/services-new-service.jpg" width="220"> <img src="images/accessories-catalog.jpg" width="220"></p>

### Workspace-Einstellungen (Coworking-Space)

Der Bildschirm des Space, von oben nach unten:

- **Identität** — Name, Land, Währung (aus dem Land vorgeschlagen, änderbar), Zeitzone, **Workspace-Sprache** (Einladungen standardmäßig darin; *App-Sprache des Absenders* ist eine Option) und die **Postadresse** auf den Rechnungen.
- **Zahlungen & Abrechnung** — die **Zahlungshinweise** auf einer offenen Abrechnung (IBAN, PayPal.me, Wero-Nummer, Lydia, Wisetag, Verwendungszweck-Hinweis — leeres Feld = nichts angezeigt), und **Rechtliche Identität & E-Rechnung** (§11a).
- **WhatsApp-Gruppe** — der Gruppenlink im Verzeichnis.
- **Einladungsnachricht** — die Vorlagen je Sprache (§2).
- **Tisch-Transparenz** — der Regler fürs Hintergrundfoto.
- **Rechnungs-PDF-Vorlage** und **Mahnregeln** — Abkürzungen zum Report-Editor und zur Mahnkonfiguration (§11).
- **Exporte** — *Space exportieren (XML)* (Einstellungen + Plan, ohne persönliche Daten), *Konfiguration exportieren (PDF)* (Vollschnappschuss: Einstellungen, Mitglieder, Plan), *Space-Bericht* (alles über den Space via Report-Vorlage „Space"), *Raum-QR-Codes (PDF)* (eine Karte je Platz, Tisch, Büro, Etage, zehn je A4), *Daten exportieren (Excel)* (eine Mappe: Buchungen, Zahlungen, Rechnungen, Mitglieder, Plan — je ein Blatt), *Space importieren (XML)* (stellt Einstellungen und Plan wieder her; ersetzt den aktuellen Plan). Jeder Export landet in den **Downloads**.
- **Der Einrichtungs-Fragebogen** — <https://fdittgen-png.github.io/deskilo/setup.html>: eine eigenständige Seite (Mac, PC oder Telefon; Antworten speichern sich automatisch im Browser), die neue Inhaber durch **jedes Thema mit vorgegebenen Auswahlen** führt — Identität (Land inkl. Norwegen, Währung, Zeitzone), Verfügbarkeit und Granularität, Grundriss, alle Funktionsschalter (inkl. USt-Voranmeldungen), Abrechnungsstufen und Abo-Level, Pakete, Services und Ausstattung, Zahlungshinweise, **rechtliche Identität und MwSt** (Organisationsform, Regime, übliche Sätze des Landes — der Schweizer 3,8 %-Beherbergungssatz, Norwegen, die kanadischen Provinzen, samt ehrlicher US-Sales-Tax-Notiz —, Rechnungsangaben, Mahnregeln), die Rollen-Matrix, die Validierungsregel und die einzuladenden Mitglieder. **XML exportieren**: die App importiert Einstellungen, Ausstattung und Plan direkt (*Space importieren (XML)*); der `<setup>`-Teil trägt den Rest. Die Seite kann eine exportierte Datei auch **wieder laden** und weiterbearbeiten.
- **Gefahrenzone** — **Space zurücksetzen**: löscht alle Buchungen, die Buchhaltung und den Plan; behält Einstellungen und Mitglieder. Durch getippte Bestätigung geschützt.

### Raum-QR-Codes & Ganzraum-Reservierungen

Vier Schritte machen „scann die Karte am Tisch" zum Alltag (§4a):

1. Im **Editor** Büro oder Etage **als Ganzes buchbar** markieren, **Preis je Halbtag** setzen.
2. **Büro- & Etagenreservierungen** in **Funktionen** aktivieren (standardmäßig aus).
3. Jedem berechtigten Mitglied **„Darf Tisch, Büro oder Etage als Ganzes reservieren"** gewähren — im Verwaltungsblatt, nie für sich selbst.
4. Karten drucken: **Workspace-Einstellungen → Raum-QR-Codes (PDF)** — ausschneiden, aufkleben.

Eine Büro-Reservierung deckt **alle Tische darin**; eine Etagen-Reservierung die ganze Etage. Beide nur, solange nichts darin gebucht ist — als eigene Zeilen auf der Abrechnung.

### Co-Inhaber

1. *Mitglieder & Pläne → das Mitglied → **Co-Inhaberschaft*** — **aktiv** (Inhaber-Berechtigungen jetzt) oder **passiv** (Nachfolger in Wartestellung).
2. Übergabe jederzeit mit ***Jetzt zum Inhaber machen***.
3. Verlässt der letzte Inhaber den Space, wird der beste Co-Inhaber **automatisch befördert** — aktiv vor passiv. Das Netz wirkt auch bei ausgeschalteter *Co-Inhaber*-Funktion (sie verbirgt nur die Ernennungs-Knöpfe).

### Rollenverwaltung

Eine zentrale Matrix entscheidet, **welche Rolle welche Berechtigung hält** — Rollen & Berechtigungen verwalten, Mitglieder verwalten, Validierungsregeln konfigurieren, Workspace-Einstellungen bearbeiten, Rechnungen ausstellen & Zahlungen zuordnen, Finanzen einsehen, Dokumentbibliothek verwalten, Services & Pakete verwalten, Ausgaben genehmigen. Zu finden unter *Einstellungen → Administration → Rollenverwaltung* (Funktion muss aktiv sein):

- Die **Inhaberin hält immer alle Berechtigungen** — ihre Zeile ist gesperrt (Schloss-Icon).
- Wer *Rollen & Berechtigungen verwalten* hält, bearbeitet die anderen Zeilen. Ein **Co-Inhaber** startet mit allem („kann weniger haben"); ein **Admin** mit den heutigen Admin-Fähigkeiten; ein **Mitglied** ohne alles.
- Alle anderen mit irgendeiner Berechtigung sehen die Matrix **schreibgeschützt** — der Bildschirm sagt es: *„Nur lesen: das sind die Berechtigungen jeder Rolle. Deine Rolle ist hervorgehoben"* — mit dem Chip **Deine Rolle**.
- Unberührte Matrix = Standardwerte. Der Server erzwingt dieselbe Matrix in den Rechnungs-RPCs (`has_permission`): UI und Datenbank können nie auseinanderlaufen.

### Online-Zahlungen einrichten

Jede Community kassiert auf ihr **eigenes** Anbieterkonto; die App behält Geheimschlüssel nie auf einem Gerät — sie leben auf dem Server.

1. **Einstellungen → Online-Zahlungen** (nur Inhaber).
2. Anbieter wählen und Schlüssel aus dessen Dashboard einfügen:
   - **PayPal** — Client ID, Secret, Umgebung (mit *sandbox* beginnen), Webhook ID, Rückkehr-URL.
   - **Kreditkarte (Stripe)** — Secret key, Webhook-Signiergeheimnis, Rückkehr-URL.
   - **Mollie** — API-Schlüssel, Rückkehr-URL (iDEAL, Bancontact, Karten…).
   - **Wero (via Mollie)** — derselbe Mollie-Schlüssel, mit Wero im Mollie-Konto aktiviert.
3. **Speichern** — ein grüner *Konfiguriert*-Chip erscheint. **Online-Zahlungen** in den Funktionen aktivieren, und Mitglieder sehen **Online zahlen** auf offenen Abrechnungen.

<p><img src="images/payment-config-paypal-stripe.jpg" width="240"> <img src="images/payment-config-mollie-wero.jpg" width="240"></p>

Ein gespeichertes Geheimnis wird nie wieder angezeigt — Feld leer lassen zum Behalten, tippen zum Ersetzen, **Entfernen** löscht den Anbieter. Gebühren sind Anbietergebühren (~1,5–3 % je Zahlung, keine Grundgebühr); DesKilo schlägt nichts auf, Überweisung/IBAN bleibt gratis.

Startet eine Zahlung nicht: **Einstellungen → Erweitert → Entwicklermodus** an und den **Entwickler**-Bildschirm öffnen — die *payments*-Spur zeigt, welche Anbieter konfiguriert sind und welche Felder fehlen.

<p><img src="images/developer-payment-traces.jpg" width="240"></p>

#### Die Anbieter-Dashboards, Schritt für Schritt

**Test- und Live-Umgebung strikt trennen**: jeder Anbieter hat Schlüssel je Modus, und alle in DesKilo eingefügten müssen zum selben Modus gehören. `<project-ref>` ist deine Supabase-Projektreferenz.

**PayPal** — [developer.paypal.com](https://developer.paypal.com) → **Apps & Credentials**; **Sandbox/Live** umschalten (Environment-Feld muss passen); **REST-API-App anlegen** (Client ID + Secret); **Webhook** `https://<project-ref>.supabase.co/functions/v1/paypal-webhook` mit *Payment capture completed* (+ *denied* / *order voided*), **Webhook ID** kopieren — der Webhook ist Pflicht, so landet die Zahlung auf der Abrechnung; alles in DesKilo einfügen.

**Stripe** — [dashboard.stripe.com](https://dashboard.stripe.com) → **Developers**; Test/Live entscheidet die Schlüssel; nur der **Secret key** wird gebraucht; unter **Payment methods** die Netze aktivieren (**Frankreich? Cartes Bancaires explizit aktivieren**); Webhook `https://<project-ref>.supabase.co/functions/v1/stripe-webhook` mit `checkout.session.completed`, Signiergeheimnis kopieren.

**Mollie** — [my.mollie.com](https://my.mollie.com) → **API keys** (Test/Live steckt im Schlüssel); Methoden aktivieren: **iDEAL**, **Bancontact**, Karten — und **Wero**, die EPI-Wallet für Konto-zu-Konto-Zahlungen in DE/FR/BE. **Mollie** und **Wero** sind in DesKilo zwei Anbieterkarten mit demselben Schlüssel. Redirect/Webhook setzt DesKilo automatisch.

#### Weitere Zahlarten (Ausblick)

| Anbieter | Fokus | Einordnung |
|---|---|---|
| **Apple Pay / Google Pay** | Mobile Wallets | Im Stripe-/Mollie-Dashboard aktivieren — erscheinen automatisch auf der Zahlseite. |
| **Klarna** | Später zahlen | Ebenso: in Stripe/Mollie einschalten. |
| **Adyen** | Enterprise | Nicht integriert — wäre ein neuer Anbieter (Beiträge willkommen). |
| **Braintree** | Drop-in (PayPal) | Nicht integriert — die direkte PayPal-Integration deckt das ab. |

### RFID/NFC-Badges einrichten

Physische Karten zum Einchecken per Tap — ohne Telefon.

1. **Einstellungen → RFID/NFC-Badges** (nur Inhaber). **NFC-Badge-Check-in** aktivieren, die **Gerätestatus-Zeile** lesen — *bereit*, *NFC in Android aus* oder *keine NFC-Hardware* (iPads haben keine).
2. Jedem Mitglied eine Karte: **Mitglieder & Pläne → das Mitglied → Badges → Karte registrieren**, Karte ans Gerät halten. Jede lesbare Chipkarte geht (MIFARE, NTAG…). Mitglieder können es auch **selbst**: **Einstellungen → Mein Badge** prägt ihr druckbares QR-Badge und registriert die eigene Karte.
3. Am **Kiosk** (§10) einsetzen. Verlorene Karte im Badges-Dialog widerrufen; **ein widerrufenes Badge nach rechts wischen** löscht es endgültig (nach Bestätigung).

Badges gehören **einem Workspace** — der Dialog nennt welchem. Dieselbe physische Karte kann in mehreren Workspaces dienen. Ein QR-Badge **als PDF** druckt zehn Kartenformat-Kopien auf eine A4-Seite.

<p><img src="images/nfc-config.jpg" width="240"> <img src="images/member-badges-dialog.jpg" width="240"></p>

## 9. Geld (Finanzen-Tab)

Dein Konto beantwortet *was schulde ich, was schuldet man mir* — und *wie viel kann ich noch buchen*. Hochkant scrollt die Monatsabrechnung über den Aktionsknöpfen; quer wandern die Aktionen ins Seitenpanel. Die Kopfzeile **‹ Monat ›** blättert jeden Monat an; der **PDF-Knopf** exportiert die sichtbare Abrechnung.

**Die Abrechnung, Karte für Karte:**

- **Dieser Monat** — wie viele **Tage** dein Abo diesen Monat enthält, wie viele **genutzt**, wie viele **übrig**, mit Fortschrittsbalken. Ein gebuchter Vormittag zählt 0,5 Tage. Die Abo-Karte darunter rechnet es vor (*3 von 42 Halbtagen genutzt, 21 Öffnungstage*).
- **Konsumierte Services** — jede Konsumation und die Servicesumme.
- **Tagespakete** — diesen Monat gekaufte Pakete.
- **Offene Posten** — alles, was noch auf Validierung wartet, in einer orange umrandeten Karte: diese Beträge stehen noch nicht auf der Abrechnung.
- **Zahlungen & Gutschriften** — erfasste Zahlungen, genehmigte Erstattungen, Gutschriften, Anpassungen.
- **Rechnungskarte** — sobald der Monat fakturiert ist: Nummer, Status, Betrag, bezahlt, Rest (§9a).
- **Dein Konto** — die echte monatsübergreifende Position, wenn es eine gibt (§9a).
- **Saldo** — beglichen / offen, darunter die **Zahlungshinweise** und **Online zahlen**, wenn etwas fällig ist.

**Wenn die Tage aufgebraucht sind** — die Wahl der Inhaberin, je Mitglied:

- **Blockiert** (Standard) — keine Buchungen mehr; frag einen Admin oder beantrage **Extra-Halbtage** direkt aus dem Finanzen-Tab (Validierer genehmigen; genehmigte Tage kosten den Überziehungssatz).
- **Nach Verbrauch** — weiterbuchen; jeder Extra-Tag kostet den Überziehungssatz deiner Stufe.
- **Pakete** — **Paket kaufen**, ein Tagespaket wählen; Tage steigen sofort, der Preis landet auf der Monatsabrechnung.

**Die Aktionen, nach Sinn gruppiert:**

- **Zahlen** — **Zahlung erfassen** („ich habe gezahlt") mit Methode, dem **Datum der Geldbewegung** (Standard: heute) und dem **Monat, den sie begleicht** (Standard: der laufende; ein Schritt zurück für Rückstand, vor für Vorauszahlung) — die andere Seite bestätigt. Dieser Monat entscheidet, auf welcher Abrechnung und Rechnung die Gutschrift landet. **Online zahlen** (falls aktiv) begleicht den fälligen Betrag sofort — **PayPal, Kreditkarte (Stripe), Mollie oder Wero**.
- **Anträge** — **Ausgabe einreichen** (Kaffee für den Space? ein anderer Admin genehmigt — keine Selbst-Genehmigung), **Extra-Halbtage beantragen**, **Konsumation hinzufügen**.
- **Dokumente** — **Rechnungen** (deine sind hier immer lesbar; für Aussteller der Rechnungs-Hub, §11), die **Finanzvereinbarung** und der **monatliche Zahlungsbericht**, Selbstbedienung (§11).

### 9a. Sobald der Monat fakturiert ist, entscheidet die Rechnung

- Deine Abrechnung zeigt eine **Rechnungskarte** — Nummer, Status, Betrag, bereits bezahlt, Restbetrag — und der Monat gilt als **beglichen**, sobald die Rechnung bezahlt, ihr Rest erlassen oder ihre Gutschrift erstattet ist — auch wenn die Zahlung erst in einem späteren Monat erfasst wurde. Eine **teilweise bezahlte** Rechnung hält den Monat offen, genau um den **Restbetrag** (den zieht auch *Online zahlen* ein). Ein **Gutschrift**-Monat zeigt, was der Space dir schuldet — du musst nichts zahlen.
- **Dein Konto** — sobald du freies Guthaben hältst (eine Gutschrift oder überzählige Zahlungen eines vergangenen Monats), zeigt der Finanzen-Tab deine echte monatsübergreifende Position über der Abrechnung: **Guthaben auf dem Konto**, jede **offene Rechnung** mit Restbetrag, ausstehende Erstattungen und die **Nettoposition**. Dein Guthaben kann offene Rechnungen begleichen — der Space rechnet es beim Zuordnen an. Monate vor Beginn deiner Mitgliedschaft schulden nichts.

### 9b. Schnellansicht, Speichern, Teilen — jeder Bericht

Jeder Bericht der App — Abrechnung, Rechnungen, Proformas, Gutschriften, deine Selbstservice-Dokumente — bietet dieselben drei Aktionen: **Schnellansicht** (das gerenderte Dokument auf dem Bildschirm, bevor ein PDF entsteht), **PDF herunterladen** und **PDF teilen** (an jede App — WhatsApp, Mail, …).

**Berichte sprechen die Sprache des Lesers:** deine Dokumente drucken in *deiner* App-Sprache, wenn der Space sie liefert, sonst in der Workspace-Sprache (§11, Vorlagen je Sprache).

## 10. Kiosk-Modus (Wandtablet)

Ein Android-Tablet oder iPad an die Tür:

1. Die Inhaberin legt ein normales Konto fürs Gerät an, tritt dem Space bei und markiert es als **Kiosk** in *Mitglieder & Pläne* (*In Kiosk verwandeln*).
2. **Der Kiosk-Modus startet nie von selbst.** Bei jedem Start fragt das Tablet *Kiosk-Modus starten?* — Bestätigen sperrt: nur Vollbild-Plan, Zurück deaktiviert, App gepinnt; verlassen = Tablet neu starten. *Nicht jetzt* öffnet die App normal. Die Kiosk-Markierung ist jederzeit widerrufbar: am Gerät unter **Einstellungen → Kiosk-Gerät** oder durch die Inhaberin.
3. Jedes Mitglied trägt ein **Badge** — vom Admin geprägt oder selbst (**Einstellungen → Mein Badge**, §8): druckbares **QR-Badge** und/oder **RFID/NFC-Karte**.
4. Am Kiosk: Platz (oder **Diese Etage**) antippen — **EIN Blatt** öffnet sich mit allem darauf: **Einchecken** vorausgewählt (ein Tipp wechselt zu **Reservieren** oder **Auschecken**), der **Zeitraum bereits aus den Einstellungen abgeleitet**, und der **Badge-Leser aktiv** darunter. Bei Halbtagen ist der Tagesteil vorausgewählt, in dem du gerade stehst (Vormittag / Nachmittag / Tag-Chips zum Wechseln — ein laufendes Fenster startet *jetzt*, vergangene sind deaktiviert, nach Feierabend bleibt ein einzelnes *Rest des Tages*); bei Zeit-Granularitäten Von/Bis-Picker auf dem Slot-Raster, der Start eines Check-ins auf *jetzt* fixiert. Das Blatt **nennt die Regel, der es folgt** — Granularität und die heutigen Arbeitszeit-Fenster — es bietet also genau, was die Einstellungen erlauben; ein **geschlossener Tag** wird sofort per Banner gesagt statt am Ende zu scheitern. Eine schon begonnene Reservierung bietet zusätzlich **Sofort einchecken?** (standardmäßig an): eine einzige Badge-Präsentation bucht die Reservierung *bereits eingecheckt*. Dann Badge zeigen:
   - **RFID/NFC-Karte antippen.** Solange der Leser scharf ist, bleibt die Kamera aus; ist NFC aus oder fehlt, sagt es das Blatt.
   - Oder **QR-Badge scannen** — mit der eigenen Kamera (Frontkamera als Standard; umschalten unter *Einstellungen → Mit der Frontkamera scannen*). Auch USB/Bluetooth-Scanner oder Tippen des Codes geht.
5. **Das Badge IST die Bestätigung:** es führt sofort aus, und ein **selbst-schließender Beleg** zeigt, *wen* der Kiosk erkannt hat, *was* passiert ist, *wo* und *bis wann* — danach ist die Wand frei für das nächste Mitglied. Der glückliche Pfad sind zwei Gesten: Platz antippen, Badge zeigen.

Deine Identität existiert nur für den Moment der Operation: die Kennung geht einmal zum Server, die Buchung läuft **auf deinen Namen**, nichts bleibt auf dem Tablet. (**iPads haben kein NFC** — dort ist der Kamera-QR-Weg der richtige.)

## 11. Fakturierung (Inhaber & Abrechnungs-Admins)

*Inhaber stellen Rechnungen aus; Admins auch, sobald sie die Berechtigung **Rechnungen ausstellen & Zahlungen zuordnen** halten (Rollenverwaltung, §8 — oder die alte Delegation **Admins stellen Rechnungen aus**). Die Funktion **Rechnungen** wohnt unter Finanzen.*

Eine DesKilo-Rechnung wird generiert, nie komponiert: ihre Positionen sind **ausschließlich aus den erfassten Monatsdaten abgeleitet** — Abo, Überziehung, Aufpreise, Services, Pakete — minus Zahlungen und Gutschriften des Monats, sodass die letzte Zeile **der fällige Saldo ist**. Jedes Dokument friert die Postadressen ein (deine unter **Einstellungen → Adresse**) und wird bei Ausstellung **digital signiert** — es ändert sich nie mehr. Ein **detaillierter Anhang** (Bewegungen und Anwesenheiten) hängt per Schalter an.

Aussteller öffnen **Finanzen → Rechnungen**: ein Drei-Tab-Hub unter einem Live-Übersichtsstreifen (*N zu fakturieren · N offen · X ausstehend · N zu erstatten · Y*):

- **Zu fakturieren** — jedes Mitglied, dessen Vormonat abrechenbare Daten und noch keine Rechnung hat: je Mitglied ausstellen (mit Vorschau der abgeleiteten Positionen) oder **Alle fakturieren** — mit Bestätigungsdialog (Anzahl, Monat, Summe). **Neue Rechnung** öffnet dasselbe Blatt für jedes Mitglied und jeden Monat — Mitglieder-Picker, ‹ Monat ›, die Positionen, der Saldo, der **Anhang**-Schalter und **Rechnung ausstellen** (grüner *Rechnung ausgestellt.*-Balken). **Eine aktive Rechnung je Mitglied und Monat**. Das Blatt öffnet auf dem **abgeschlossenen Monat**; der laufende warnt, denn er ist nur einmal fakturierbar.
- **Offen** — ausgestellte Rechnungen, älteste zuerst; über 30 Tage wird rot. Jede Aktion ist ein Icon mit Tooltip (stornieren · Proforma · Mahnung · als bezahlt markieren). **Karte antippen = Rechnung lesen.** **Zahlungserinnerung senden** erfasst die Mahnung und teilt das PDF — die Karte zeigt *Erinnert ×N*. **Als fehlerhaft markieren** storniert zur Korrektur (ein Dialog warnt: unumkehrbar): sie wandert durchgestrichen ins Archiv, eine **Ersatzrechnung** leitet den Monat neu ab. **Als bezahlt markieren** ordnet eine echte Zahlung zu (unten). **Eine Teilzahlung schließt keine Rechnung**: sie bleibt offen, Badge *Teilweise bezahlt* mit Restbetrag, bis der Rest ausdrücklich **über das Validierungs-Framework storniert** wird — erst dann Archiv als *Teilweise bezahlt · Restbetrag storniert*. **Eine NEGATIVE Rechnung ist eine Gutschrift** — der SPACE schuldet dem Mitglied: PDF-Titel *Gutschrift*, keine Mahnungen, kein Zuordnen von Mitgliedszahlungen; die Karte zeigt *Zu erstatten* mit **Erstattung erfassen** — die Auszahlung bucht gegen das Mitgliedskonto (validiert, wenn eine Regel greift; Ablehnung öffnet wieder), das Dokument schließt als *Erstattet*. Der Übersichtsstreifen trennt beide Richtungen: *N offen · X ausstehend* zählt positive Rechnungen zum **Restwert** (500 € mit 280 € bezahlt zählt 220 €), *N zu erstatten · Y* summiert die offenen Gutschriften.
- **Archiv** — geschlossene Rechnungen, filterbar nach Mitglied und Monat, sortierbar; stornierte **standardmäßig ausgeblendet** — *Stornierte anzeigen* holt die Korrekturkette zurück; **Filter zurücksetzen** holt alles. Jede Zeile: Status-Chip (*Bezahlt*, *Teilweise bezahlt*, *Fehlerhaft* durchgestrichen, Gutschriften mit Negativbetrag), Monat, Betrag, **PDF herunterladen**. **Zeile antippen = Rechnung öffnen** — Positionen, Saldo, Empfänger, Stand (*Bezahlt €300.00 am 6. Aug.*, *Erinnert ×1…*, *Anhang: 5 Bewegungen, 10 Check-ins*), Ersetzungskette, Signatur — und jede noch erlaubte Aktion: **Schnellansicht**, **PDF herunterladen**, **PDF teilen**, **E-Rechnung (XML)**, mahnen, als bezahlt markieren, als fehlerhaft markieren, Ersatz ausstellen.

**Als bezahlt markieren heißt: eine echte Zahlung zuordnen — oder ein Guthaben anrechnen.** Der Dialog listet die registrierten Zahlungen — erfasste Überweisungen und bestätigte Online-Zahlungen — und du ordnest die Rechnung einer zu; kein Betrag zu tippen (noch keine? der Dialog sagt es: *erst erfassen oder bestätigen*). Er listet auch die **Guthaben des Mitglieds** (Gutschrift-Überschuss): eines zuzuordnen rechnet die Gutschrift auf die Rechnung an, vergangene Monate eingeschlossen — die übliche Alternative zur Auszahlung, für Vereine wie Unternehmen. Jedes Guthaben wird genau einmal ausgegeben. **Mehr** gezahlt? **Gutschrift über den Überschuss** oder erzwungen akzeptieren mit Pflichtnotiz. **Weniger**? Mit Pflichtnotiz akzeptieren. Alle mit Rechnungszugriff werden benachrichtigt; die Inhaberin kann eine **Rechnungszahlung**-Validierungsregel (§7) setzen — die Zuordnung wartet aufs Quorum, eine Ablehnung öffnet wieder.

**Eine bezahlte Rechnung ist endgültig.** Einmal zugeordnet: nie mehr stornieren, ersetzen, ändern — Korrekturen vor der Zahlung, per Storno + Ersatz. Eine Zahlung unter dem Betrag, mit Notiz akzeptiert, zeigt **teilweise bezahlt**.

**Proforma.** Beide Hub-Tabs tragen eine Proforma-Aktion: auf **Zu fakturieren** als Angebot — keine Nummer, keine Signatur, Stempel PROFORMA, **nichts wird ausgestellt**; auf **Offen** als Zahlungsaufforderung, die nicht als Original durchgeht. Beide mit Schnellansicht / Download / Teilen.

**Stempel.** Eine stornierte Rechnung trägt ein diagonales **FEHLERHAFT** über jeder Seite. Derselbe Stempel sagt **PROFORMA** auf einem Angebot und **KOPIE** auf jeder Rechnung, die nicht ihr Aussteller rendert.

**Mahnungen (Mahnwesen).** Die Inhaberin setzt die **Mahnregeln** (Häkchenlisten-Icon in der Kopfzeile, oder *Workspace-Einstellungen → Mahnregeln*): Anzahl Stufen, Tage bis zur ersten, Tage dazwischen. Überfällige Rechnungen tragen **„Mahnung N fällig"**, die Glocke wird rot — nichts geht je automatisch raus. Der Versand erzeugt einen **Mahnbrief** (Stufe 1 freundlich, höhere fester) aus der Vorlage der Stufe — fertig in deiner Sprache, gedruckt in der Sprache des *Mitglieds*, je Stufe editierbar mit `{{ reminder_level }}`, `{{ reminder_date }}`, `{{ days_open }}`.

**Das Register.** Das Listen-Icon öffnet ein Ein-Zeilen-Register: **Datum · Name · Betrag · Status**, nach Datum sortiert (Kopfzeile antippen dreht die Richtung), Summe am Fuß, **Jahres**-Picker ab zwei Jahren. Sein Export-Knopf öffnet **Buchhaltungs-Export**: **SAF-T (XML, international)** und — für einen französischen Space — **FEC (Frankreich, bei Prüfung verlangt)**.

**Die Periode an die Buchhaltung übergeben.** Aus dem Register exportieren Aussteller **SAF-T** — das OECD-*Standard Audit File for Tax*. Es deckt genau das Register: das Unternehmen, jeden Kunden, jede Rechnung mit Zeilen und Summen, die begleichenden Zahlungen. Stornierte bleiben als *annulliert* — eine Prüfdatei löscht nichts. Bewusst fehlt der **Kontenplan**: DesKilo erfindet keine Kontonummern; das Mapping macht die Buchhaltung.

**Frankreich: das FEC.** Ein französischer Space bekommt das **FEC** (*Fichier des Écritures Comptables*, art. L47 A-I du LPF): eine tabulierte Flachdatei von **Buchungen**, benannt `<SIREN>FEC<JJJJMMTT>.txt`, mit den 18 vorgeschriebenen Spalten. Kontonummern fragt der Export vorher ab — vorbelegt mit dem *plan comptable général* (411, 706, 512). Jede Rechnung bucht brutto Forderung an Ertrag; Gutschriften und die begleichende Zahlung buchen zu ihren Daten, gelettert mit der Rechnungsnummer. Stornierte fehlen. Mitglieder sehen nur, was sie betrifft.

### 11a. Rechtliche Identität, MwSt & Pflichtangaben

**Vor dem ersten Export die rechtliche Identität ausfüllen.** Unter *Workspace-Einstellungen → **Rechtliche Identität & E-Rechnung*** erklärt die Inhaberin:

- Das **MwSt-Regime** — es bestimmt die von EN 16931 verlangte Nummer: außerhalb der MwSt eine **Registernummer** (SIREN, HRB, CIF…); als Kleinunternehmer eine **USt-IdNr.** plus **Befreiungsgrund** (das Feld schlägt die passenden Formeln vor). Das Regime gilt durchgängig: nur ein steuerpflichtiger Space stempelt je einen Satz, unter jedem anderen Regime verschwinden die MwSt-Picker.
- Die strukturierte **Adresse** (Straße, PLZ, Ort).
- Die **E-Rechnungs-Plattform** (§11b).
- Die **Rechnungs-Pflichtangaben**, mit **Organisationstyp** — *Unternehmen* vs. *Verein (loi 1901)*: Rechtsform & Kapital, Register (Unternehmen: Handelsregister; Vereine: **RNA W… · SIRET falls vergeben**), Zahlungsbedingungen, Verzugszinsen, die **40-€-Beitreibungspauschale**, Skonto, Berufshaftpflicht, besondere Vermerke. Leere Klauseln drucken die gesetzliche Standardformel — Vereinsdokumente lassen die reinen B2B-Klausel-Defaults weg (was du eintippst, druckt trotzdem).

Mitglieder ergänzen ihr **Land** — und ihre USt-IdNr., wenn sie als Unternehmen fakturieren — neben ihrer Adresse unter *Einstellungen → Adresse*. DesKilo prüft alles **vor** der E-Rechnung und verweigert mit benanntem fehlendem Element.

**DesKilo-Preise sind brutto.** Was du als Preis eintippst, zahlt das Mitglied. MwSt einschalten ändert keinen geschuldeten Betrag — es sagt, wie viel davon Steuer ist. Unter einem steuerpflichtigen Regime sagt es der Katalog laut: jede Service- und Paket-Zeile nennt ihren enthaltenen Satz (*inkl. 19 % USt*), der Abrechnungs-Editor vermerkt den Standardsatz der Stufen und zeigt beim Tippen den USt-Anteil jedes Betrags, Ausstattungs-Aufpreise nennen den Standardsatz, und jedes Preisfeld erinnert daran, dass es brutto ist.

**Sätze setzen.** *Rechtliche Identität → **MwSt-Sätze***. Leere Liste = MwSt aus. **Übliche Sätze verwenden** füllt Standard-, Zwischen- und ermäßigten Satz deines Landes — ein Entwurf, keine Steuerberatung. Ein Satz ist der **Standard** (Stern). Service und Paket tragen je ihren eigenen Satz. Entfernen löscht nie — referenzierte Sätze bleiben deaktiviert erhalten.

**Die periodische USt-Voranmeldung** (*MwSt-Sätze → Umsatzsteuer-Voranmeldung*, nur steuerpflichtige Spaces). Zeitraum wählen — Monat oder Quartal, was dein Regime verlangt — und **Erstellen**: die App aggregiert die ausgestellten Rechnungen des Zeitraums je Satz **mit exakt der Arithmetik der Rechnungen**, die Voranmeldung stimmt also mit jedem Dokument auf den Cent überein. Das Ergebnis zeigt Bemessungsgrundlage und USt je Satz, abgebildet auf die **Kennzahlen des amtlichen Formulars** (UStVA Kz 81/86 in Deutschland, CA3-Zeilen 08/09/9B/11 in Frankreich, generische Liste sonst). Jede Voranmeldung exportiert als **PDF** und **maschinenlesbares XML**; ist unter E-Rechnung eine Upload-Plattform konfiguriert, sendet **Übermitteln** sie elektronisch dorthin und protokolliert die Quittung — sonst die Zahlen in ELSTER/das Portal übertragen und **Als abgegeben markieren**. In beiden Fällen wird die Voranmeldung unveränderlich, mit Kanal und Beleg. Der Katalog vorgeschlagener Sätze deckt alle EU-Staaten, die Schweiz (samt 3,8 % Beherbergung), Norwegen und die kanadischen Provinzen ab; die USA haben keine Bundes-MwSt — die App sagt es, statt zu raten. Eine Abgabehilfe, keine Steuerberatung.

**Was es am Dokument ändert.** Eine danach ausgestellte Rechnung trägt die Aufschlüsselung wie ausgestellt: Satzspalte, Netto und eine Zeile je Satz. Die **E-Rechnung (XML)** trägt, was EN 16931 verlangt (UBL und CII); **SAF-T** deklariert jeden Satz; das **FEC** bucht brutto gegen netto plus ein **Umsatzsteuer**-Konto (445710, änderbar).

**Eine ausgestellte Rechnung ändert sich nie.** Braucht ein Dokument neue Zahlen: **fehlerhaft** markieren und **Ersatz** ausstellen — die Korrekturkette ist auf beiden sichtbar.

### 11b. Wohin die E-Rechnung muss (EU)

Die Aktion **E-Rechnung (XML)** öffnet ein Blatt, das es fürs Land des Space beantwortet: welcher Kanal für Geschäftskunden, ob eine Plattform dazwischen sitzt, welcher Kanal für öffentliche Käufer. Vier Modelle:

- **Peppol** — ein Access Point liefert an den Kunden; keine Staatsplattform dazwischen. Belgiens B2B-Mandat funktioniert so; Peppol erreicht öffentliche Käufer EU-weit (Richtlinie 2014/55/EU).
- **Zugelassene Plattformen** — Frankreich: eine *plateforme agréée* routet und meldet dem Fiskus. Öffentlicher Sektor bleibt **Chorus Pro**.
- **Clearance** — Italien (**SdI**), Polen (**KSeF**), Rumänien (**RO e-Factura**): die Plattform empfängt *zuerst*; jede verlangt eigene Syntax — das Blatt warnt, dass die EN-16931-Datei nicht die ihre ist; für Peppol, öffentliche Käufer und Auslandskunden nutzen, konvertieren lässt die Plattform oder die Buchhaltung.
- **Kein Kanalzwang** — Deutschland heute: Empfang seit 2025 Pflicht, Ausstellung phasenweise; E-Mail-Anhang ist legal; XRechnung und ZUGFeRD erwartet. Öffentlich: **OZG-RE / ZRE** oder Peppol.

**Factur-X — eine Datei, beide Leser.** Das Blatt bietet zuerst **Factur-X (PDF)**: ein normal aussehendes Rechnungs-PDF mit der Maschinenrechnung *darin* (EN-16931-Daten als CII). Der Mensch sieht die Rechnung, die Plattform findet `factur-x.xml`. Das nackte **XML** bleibt darunter verfügbar.

**Senden, ohne die App zu verlassen.** Die Inhaberin registriert die Plattform unter *Rechtliche Identität → **E-Rechnungs-Plattform***: **Upload-URL**, **Token/Kennung**, bei Bedarf **Authorization-Header** und **Dateifeldname**. Jede Plattform mit Credential-Upload geht. Der Token bleibt serverseitig. Danach führt das Blatt mit **An die Plattform senden**: das Factur-X-Dokument geht direkt raus; das Detailblatt protokolliert Abgang, Antwort und zurückgegebene ID. Jeder Versuch wird geloggt.

**Proben ohne Risiko.** Derselbe Bildschirm nimmt **Testumgebungen** (UAT/Dev: je URL + Token). Mit aktivem **Entwicklermodus** bietet der Versand die Umgebungswahl; ein Test wird als solcher markiert; die Produktions-URL dient nie einer Probe.

DesKilo überträgt nichts auf eigene Rechnung: es produziert das Dokument und übergibt es deiner Plattform. Mandatskalender bewegen sich: prüfe deine Steuerverwaltung.

### 11c. Der Report-Editor — jedes Dokument, vier Vorlagen, fünf Sprachen

Die **Rechnungs-PDF-Vorlage** (Stift in der Kopfzeile, oder *Workspace-Einstellungen*) ist ein Banden-Reporting für jedes gedruckte Dokument. Drei **Banden** rendern aufs PDF — Kopf, Körper (die Rechnungszeilen), Fuß — das E-Rechnungs-XML bleibt unberührt.

- **Ein Report je Dokument**: Chips wechseln zwischen **Rechnung · Proforma · Abrechnung · Vereinbarung · Zahlungen · Space · Mahnstufen**. Die Proforma fällt auf die Rechnungsbanden zurück; eine angepasste Abrechnung ersetzt das eingebaute Monats-PDF.
- **Je Sprache**: eine zweite Chip-Reihe — *Standard (alle Sprachen)* · EN · FR · DE · ES · IT — speichert eine Übersetzungs-Schicht je Dokument; der Report eines Mitglieds druckt in *seiner* Sprache, wenn eine Vorlage existiert.
- **Markup oder Visuell**: **Markup** editiert die Banden als Text — [Liquid](https://shopify.github.io/liquid/)-Bedingungen und -Schleifen (`{{ number }}`, `{% if proforma %}…{% endif %}`, `{% for line in lines %}…{% endfor %}`) plus einfaches Zeilen-Markup: `#` Titel, `##` Abschnitt, `>` Kleindruck, `---` Trenner, `a | b` Tabellenzeile, `=` Fettzeile, `::: … ||| … :::` Spalten nebeneinander (der Verkäufer-links/Kunde-rechts-Block und die rechtsbündigen Summen einer französischen Facture), `![name]` ein Bild aus der **Bildbibliothek** (*Bild einfügen*). **Visuell** zeigt dieselben Banden als Design-Fläche — gestylte Zeilen, `{{ Tokens }}` markiert, Zeile antippen zum Editieren, hinzufügen, verschieben, Datenfelder aus einer Palette einfügen.
- **Vorlagen-Galerie** (*Vorlagen*): vier fertige Presets je Dokument — **Klassisch · Einfach · Detailliert · Formeller Brief**. Jedes Rechnungs-Preset trägt schon die Pflichtangaben (§11a).
- **Schnellansicht** rendert sofort in der App — deine neueste Rechnung, oder simulierte Beispieldaten (*Beispieldaten*-Wasserzeichen) — ohne PDF-Umweg; **Vorschau** erzeugt das PDF; **Auf Standard zurücksetzen** liefert das eingebaute Layout als Arbeitsbeispiel. Eine kaputte Vorlage blockiert nie ein Dokument; Storno-Wasserzeichen, Signatur, Anhang und Seitenzahlen bleiben fix.

Variablen (Rechnungsfamilie): `{{ number }}`, `{{ member }}`, `{{ workspace }}`, `{{ workspace_address }}`, `{{ period }}`, `{{ issued }}`, `{{ issued_by }}`, `{{ replaces }}`, `{{ total }}`, `{{ charges }}`, `{{ payments }}`, `{{ voided }}`, `{{ proforma }}`, `{{ copy }}`, `{{ lines }}` (je mit `label`, `unit_price`, `qty`, `net`, `vat_rate`, `amount`), `{{ has_vat }}`, `{{ vat }}`, `{{ net_total }}`, `{{ vat_total }}`, `{{ credit_note }}`, `{{ refund_total }}` — und der Rechts-Satz: `{{ seller_legal_form }}`, `{{ seller_registration }}`, `{{ seller_vat_id }}`, `{{ seller_legal_id }}`, `{{ exemption_reason }}`, `{{ client_address }}`, `{{ client_vat_id }}`, `{{ client_legal_id }}`, `{{ payment_terms }}`, `{{ late_penalty }}`, `{{ recovery_indemnity }}`, `{{ escompte }}`, `{{ insurance }}`, `{{ special_mentions }}`.

### 11d. Die Report-Suite & die Dokumentbibliothek

- **Finanzvereinbarung** — jeder für ein Mitglied geltende Preis: Abo, Extra-Halbtag, Services, Pakete, Ganzraum- und Zubehör-Aufpreise. Inhaber/Admins senden sie vom Verwaltungsblatt; jedes Mitglied holt seine unter *Finanzen → Dokumente*.
- **Zahlungsbericht** — alles, was du in einem Monat gezahlt, erklärt oder validiert bekommen hast: deine kleine Bilanz, Selbstbedienung.
- **Space-Bericht** — Identität, Plan-Zählungen, Verfügbarkeit, Funktionen und Preise: *Workspace-Einstellungen → Space-Bericht*.
- **Dokumentbibliothek** — *Einstellungen → Dokumente*: Satzung, Leitfäden, Abschlüsse, Protokolle — VERLINKT aus dem System, das du schon nutzt: Google Drive, OneDrive, SharePoint, Dropbox, Nextcloud oder jeder https-Link (der Drive verwaltet seine Zugriffe; die App speichert nie fremde Zugangsdaten). Jeder Eintrag hat eine **Sichtbarkeitsrolle**: jedes Mitglied, Admins & Inhaber, nur Inhaber — serverseitig erzwungen. Kuratiert per + ; die Funktion *Dokumentbibliothek* schaltet alles.

## 12. Einstellungen & Profil

Dein persönlicher Bildschirm, von oben nach unten:

- **Profile** (§1) und dein **Foto** (antippen — wählen oder entfernen).
- **Mitglieder** — Abkürzung ins Verzeichnis; **WhatsApp** — deine Nummer, nur sichtbar, wenn du sie einträgst; **Status** — eine freie Zeile (40 Zeichen) im Verzeichnis; **Adresse** — deine Postadresse (auf deinen Rechnungen), Land und optionale USt-IdNr.
- **Hilfe** — das eingebaute Handbuch, in deiner Sprache; **Mein Badge** (§8); **Verknüpfte Konten** — Google-Anmeldung ans E-Mail-Konto hängen; **Dokumente** — die Dokumentbibliothek (§11d).
- **Präferenzen** — **Sprache** (Systemstandard oder eine von fünf), **Thema** (System / Hell / Dunkel), **Mit der Frontkamera scannen** (für Wandtablets).
- **Erweitert** — der Push-Status dieses Geräts, der workspace-weite **Entwicklermodus** und der **Entwickler**-Trace-Bildschirm (§8 Zahlungen).
- **Abmelden**.

## 13. Benachrichtigungen

Check-in-Erinnerungen, offene Bestätigungen, Ausgaben-Entscheidungen — und wenn ein Admin **eine deiner Buchungen entfernt** (übersteuern), werden du und die Admins benachrichtigt. Zustellung lokal zuerst; Server-Push kommt fertig auf Android, iPhone/iPad, Browser und macOS (Firebase Cloud Messaging) — *Einstellungen → Erweitert* zeigt den Gerätestatus. Das Icon-Badge zählt offene Bestätigungen **plus ungelesene Nachrichten** — Android, iPhone/iPad, macOS-Dock, Windows-Leiste, installierte Web-Apps. Mitglieder-Nachrichten werden **einmal je Gerät mit Absender und vollem Text** angesagt — auch was bei geschlossener App kam. Push-Payloads tragen nie Namen oder Zeiten; die App baut den Text lokal.

## 14. Datenschutz

Minimale Daten: Name, E-Mail, Plan, Buchungen, Konto. Du kontrollierst Foto, Status, Namensanzeige auf dem Plan, Nummern-Sichtbarkeit. Badges liegen nur als Hashes — ein verlorenes wird widerrufen, nicht erraten. Kein Tracking, keine Fremd-Analytik. Finanzhistorie wird bei Kontolöschung anonymisiert, nicht gelöscht (Aufbewahrungspflicht).

## 15. Plattformen

Android (Google Play), iPhone/iPad, Desktop — **macOS** (DMG: DesKilo in Programme ziehen) und **Windows** (MSI-Installer) aus jedem Release — und der **Browser**: dieselbe App, nichts zu installieren. Deine Daten folgen deinem Konto.

Was der Browser nicht kann, darf eine Webseite nicht: NFC lesen oder wie der Kiosk per Kamera scannen. Alles andere — Plan, Buchungen, Mitglieder, Geld, Rechnungen, PDFs — ist dieselbe App. Beim ersten Start des macOS-DMG: Rechtsklick → *Öffnen* (die Build ist noch nicht von Apple notariell beglaubigt).
