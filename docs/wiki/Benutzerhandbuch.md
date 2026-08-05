# Benutzerhandbuch

Alles, was Mitglieder, Admins und Inhaberinnen brauchen, um DesKilo zu nutzen. *Andere Sprachen: [English](User-Guide) · [Français](Guide-utilisateur) · [Español](Guia-de-usuario) · [Italiano](Guida-utente).*

> Die Screenshots in diesem Handbuch zeigen die App auf Französisch — jeder Bildschirm existiert identisch in allen fünf Sprachen (English, Français, Deutsch, Español, Italiano); umschalten unter **Einstellungen → Sprache**.
>
> <img src="images/settings-language.jpg" width="200">

## 1. Erste Schritte

### Konto anlegen

Öffne die App und registriere dich mit E-Mail, Passwort (mindestens 8 Zeichen) und Anzeigenamen. Mit dem Augen-Button kannst du das Passwort beim Tippen ein- und ausblenden.

### Workspace anlegen — oder beitreten

Nach der Anmeldung bietet der Startbildschirm zwei Wege:

- **Workspace anlegen** — du wirst **Inhaberin**. Wähle Name, Land (bestimmt die Standardwährung) und Zeitzone. Danach zeichnest du deinen Grundriss im Editor (§7).
- **Workspace beitreten** — tippe die **Workspace-ID** ein, die man dir gegeben hat, oder wähle **QR-Code scannen** und richte die Kamera auf den Einladungs-QR an der Wand. Du trittst mit der Rolle bei, die die Einladung trägt (§2).

Ein Konto kann mehreren Workspaces angehören; wechsle unter **Einstellungen → Profile** und **markiere eines mit dem Stern als Standard** — mit diesem Profil öffnet sich die App, auf jedem Gerät und selbst nach einer Neuinstallation (die Wahl ist im Konto gespeichert). Alles in der App bezieht sich auf den aktiven Workspace.

**Alles bleibt live.** Was irgendjemand ändert — eine Buchung, ein neues Mitglied, eine Einstellung — wird binnen Sekunden auf jedes verbundene Gerät gepusht, auch auf das, das die Änderung gemacht hat. Kein Neustart, kein Ziehen zum Aktualisieren.

## 2. Rollen & Einladungen

DesKilo hat drei additive Rollen plus ein Gerätekonto:

| Rolle | Kann |
|---|---|
| **Mitglied** | Ein-/auschecken, reservieren, Ausgaben einreichen, eigene Ereignisse und das eigene Konto sehen und verwalten |
| **Admin** | Alles, was ein Mitglied kann, plus: *für andere* handeln (Reservierungen, Zahlungen, Ausgaben — bestätigungspflichtig, §6), Ausgaben freigeben, Kiosk-Badges ausstellen |
| **Inhaberin** | Alles, was ein Admin kann, plus: den physischen Workspace bearbeiten, Tarife und Preise festlegen, Rollen, Kiosk-Geräte und Einstellungen verwalten |
| **Mit-Inhaberin** | *Aktiv*: sofort die Rechte der Inhaberin plus automatische Nachfolge. *Passiv*: Nachfolge in Wartestellung, heute ohne zusätzliche Rechte |
| **Kiosk** | Ein Wandtablet-Konto (§9) — zeigt nur den Plan; echte Mitglieder handeln darüber mit einem Badge |

**Jede Einladung ist an eine Rolle gebunden.** Auf dem Bildschirm *Workspace-ID & QR* gibt es zwei Einladungen, jede mit eigenem QR-Code und Code:

- **Mitglieder-Einladung** — die Workspace-ID selbst. Drucken, an die Wand hängen, frei teilen: Wer sie scannt oder eintippt, tritt als einfaches Mitglied bei.
- **Admin-Einladung** — ein **persönlicher, einmalig nutzbarer Code**, von einer Inhaberin für genau eine Person ausgestellt. Er lässt nur diese eine Person als Admin beitreten und verfällt dann (ungenutzte Codes verfallen nach 14 Tagen). Für jeden weiteren Admin mit *Neuer Admin-Code* einen neuen ausstellen.
- **Einladungen sprechen die Sprache des Eingeladenen** — das Einladungsblatt verfasst die Nachricht in der gewählten Sprache (fünf verfügbar), standardmäßig in der in den *Arbeitsbereich-Einstellungen* festgelegten **Arbeitsbereichssprache**. Der Inhaber kann den Einladungstext dort auch **pro Sprache** anpassen; eine leere Sprache nutzt die eingebaute übersetzte Nachricht.

**Eine Inhaber-Einladung gibt es absichtlich nicht.** Inhaberschaft kann nur eine bestehende Inhaberin vergeben, unter *Mitglieder & Tarife*. Ein Workspace behält immer mindestens eine Inhaberin. **Admin**-Beförderungen und -Degradierungen laufen über den Validierungsfluss (§6) — sie greifen erst nach Bestätigung durch die Validierenden.

**Mit-Inhaberinnen halten den Workspace am Leben.** Die Inhaberin ernennt ein beliebiges Mitglied oder einen Admin zur Mit-Inhaberin (*Mitglieder & Tarife → das Mitglied → Mit-Inhaberschaft*), in einer von zwei Spielarten: Eine **aktive** Mit-Inhaberin arbeitet sofort mit den Rechten der Inhaberin; eine **passive** hat heute keine zusätzlichen Rechte — bis zu dem Tag, an dem sie gebraucht werden. In beiden Fällen ist die Nachfolge automatisch: Geht die letzte Inhaberin — sie tritt aus, wird entfernt oder ihr Konto verschwindet — wird die beste Mit-Inhaberin (aktiv vor passiv) **sofort zur Inhaberin**, auf dem Server, ohne dass jemand etwas tun muss. Die Inhaberin kann auch jederzeit bewusst übergeben, mit *Jetzt zur Inhaberin machen*. Eine Feinheit: Validierungsregeln, die die Mitzeichnung der *Inhaberin* verlangen (§6), meinen immer eine echte Inhaberin, nicht eine aktive Mit-Inhaberin.

Der QR kodiert einen Link, der die vergebene Rolle nennt (`deskilo://join?role=…`). Manipulation am Link ändert nichts — der Server leitet die Rolle aus dem Code selbst ab: Die Workspace-ID lässt immer als Mitglied beitreten, eine persönliche Einladung genau in der Rolle, für die sie ausgestellt wurde — ein einziges Mal. Ein weitergeleiteter, bereits genutzter — oder abgelaufener — Admin-Code lässt niemanden mehr beitreten.

**Per Nachricht einladen** (*Jemanden einladen*): Jeder WhatsApp-/SMS-/Teilen-Versand stellt seinen eigenen persönlichen Einmal-Code aus und baut eine fertige Nachricht in der Sprache der eingeladenen Person. Die Empfängerin kann einfach die ganze Nachricht kopieren und in das Beitrittsfeld der App einfügen — der Code wird automatisch erkannt.

## 3. Der Grundriss (Tab Plan)

Der Plan zeigt die aktive Etage: Büros, Tische und Plätze, farbcodiert — **frei**, **reserviert**, **besetzt**, **meiner**, **gesperrt**. Er öffnet sich **sofort aus den letzten bekannten Daten** und aktualisiert sich im Hintergrund — bei wackeligem WLAN siehst du den letzten Stand statt eines leeren Bildschirms. Besetzte Plätze zeigen den Vornamen, ein **Check-Abzeichen**, wenn die Person eingecheckt ist, und einen **grünen Punkt**, wenn sie gerade in der App online ist. Ist ein **ganzer Tisch, Raum oder eine ganze Etage** reserviert, zeigt es der Raum selbst — farbige Tönung, kräftiger Rahmen und ein **Schloss-Chip mit dem Namen der Person** in der Mitte (ein Check-in-Glyph, sobald sie da ist); die Raumbeschriftung liest sich *Bureau 2 · Florian*. Alle sehen es, auf dem Plan, im Reservieren-Hub und am Kiosk.

Der Plan kann wie dein echter Raum aussehen: Die Inhaberin kann ein **Foto des Raums als Etagen-Hintergrund** hinterlegen und frei **skalierbare Illustrationsbilder** (Pflanzen, Sofas…) auf dem Raster platzieren. Ein Regler für die **Tisch-Transparenz** in den Einstellungen lässt das Foto durch die gezeichneten Tische durchscheinen.

Navigation:

- Die Fläche **passt sich automatisch** an deine Etage an, beim Öffnen und beim Drehen des Geräts; **zoome mit zwei Fingern** oder den **+ / −**-Buttons, ziehe die **Scrollbalken** an den Rändern, und tippe den **Einpassen**-Button zum Zentrieren.
- Wähle die Etage im **Etagen-Menü** (kompakte Auswahl); das Uhr-Symbol setzt die Zeitleiste auf **jetzt** zurück.
- Im **Querformat** wandern die Bedienelemente in eine Seitenleiste und der Plan füllt den Bildschirm — praktisch auf Tablets.

Buchen vom Plan aus:

- **Spontanes Einchecken**: Tippe einen freien Platz → das Formular schlägt *jetzt* bis zum Standard-Ende des Workspace vor → bestätigen. Hat jemand den Platz später reserviert, wird deine Endzeit gekappt und du erfährst es.
- **Einchecken auf Reservierung**: Einchecken heißt *du bist da* — das Fenster öffnet **15 Minuten vor** deinem Beginn und schließt mit dem Reservierungsende. Außerhalb ist der Button deaktiviert und sagt, wann es so weit ist; wer eine zukünftige Zeit durchstöbert, bekommt nie ein Live-Einchecken angeboten. Admins können ein Mitglied einchecken, das an seinem Platz steht (solange *Buchen für andere* an ist).
- **Auschecken**: manuell — oder, wenn die Inhaberin **Auto-Check-in/out** aktiviert, schließen vergessene Reservierungen sich am Tagesende selbst ab: Nie angerührte Buchungen gelten von ihrem Beginn bis zu ihrem Ende als wahrgenommen, vergessene Check-outs enden zum Reservierungsende.
- **Ganze Räume**: **Doppeltippe** einen Tisch, einen Raum oder eine freie Stelle der Etage, um den **ganzen Tisch, das Büro oder die Etage** zu buchen — dasselbe Formular wie beim Scan seiner QR-Karte (§4), mit derselben Zeitraum-Auswahl und denselben Wiederholungsoptionen wie ein Platz.
- **Zeitleiste**: Wähle ein von→bis-Fenster (oder Vormittag / Nachmittag / Ganzer Tag, je nach Granularität), um die Belegung zu jedem künftigen Zeitpunkt zu sehen.
- Plätze können **Zubehör** tragen (Monitor, Stehpult…), teils mit Aufpreis je Halbtag, der auf deiner Abrechnung erscheint.
- Buchungen zählen gegen deine **Monatstage** (§8) — jenseits deines Tarifs blockt oder berechnet die App, je nachdem, was die Inhaberin für dich eingestellt hat.

## 4. Reservierungen (Reservieren-Hub)

Öffne den **Reservieren**-Hub (Mittelbutton). Eine Datumsleiste wählt den Tag, die Fenster-Chips die Zeit; dann vier Ansichten:

- **Plan** — der Grundriss, gefiltert auf dein Fenster; freier Platz antippen = buchen.
- **Tag** — jeder Platz als Zeitstrahl für den gewählten Tag; freie Strecke antippen = buchen, eigener Block = Details.
- **Woche** — ein Raster Platz × Tag für die ganze ISO-Woche; freie Halbtage auf einen Blick, Antippen bucht.
- **Monat** — ein Verfügbarkeitskalender: freie Tische pro Tag über alle Etagen; ein Tag öffnet seine Tagesansicht.

Der **Ebenen-Button am Etagenwähler** reserviert die **ganze Etage** — auf dem Plan-Tab wie hier im Hub. Inhaberinnen und Admins können sie immer für sich selbst buchen; andere Mitglieder brauchen das persönliche Recht (§7).

**Ein Platz zur Zeit**: Du kannst je Zeitraum nur eine aktive Reservierung halten — anderswo buchen oder einchecken, während eine läuft, wird abgelehnt, und ein Check-in schließt einen früheren Check-in, dessen Buchung schon vorbei ist. Admins und Inhaberinnen können **übersteuern**: Ein Tipp auf einen belegten oder reservierten Platz bietet *Reservierung entfernen (übersteuern)* — die Reservierung wird entfernt und das Mitglied sowie alle Admins werden über den Ereignis-Feed benachrichtigt.

Reservierungen folgen der **Granularitätsregel** des Workspace — Halbtage, ganze Tage, echte Uhrzeiten (exakt von–bis, mit den Halb-/Ganztagsfenstern als Schnellwahl) oder freie Zeiten auf dem Minutenraster der Inhaberin. Halb- und Ganztage decken die konfigurierten **Arbeitszeiten** ab (Standard 8–17 Uhr, Halbtagsgrenze 12 Uhr). Sie respektieren **Öffnungstage** und **Schließtage** sowie die Buchungsregeln (Vorlauf, Maximaldauer, Stornofrist). Wiederkehrender Bedarf? Buche eine **Serie** (täglich, werktags, wöchentlich) — geschlossene Tage und Konflikte werden übersprungen und gemeldet.

**Das Löschen einer vergangenen oder eingecheckten Buchung ist ein Antrag, keine Aktion.** Eine Buchung, deren Beginn vorbei ist — oder bei der Sie bereits eingecheckt haben — lässt sich nicht direkt stornieren: Das Blatt bietet stattdessen **Löschung beantragen**. Inhaber oder Admin entscheiden die eine Frage, die für die Abrechnung zählt: wurde der Check-in nur vergessen (die Buchung bleibt), oder wurde sie nie genutzt (sie wird entfernt)? Der Antrag erscheint im Ereignis-Feed mit Ihrem optionalen Grund; zukünftige unberührte Buchungen behalten das direkte Stornieren.


Der Tab **Kalender** zeigt deine Buchungen pro Monat — deine Tage **rot**, die der anderen **blau**, heute umkreist — mit Tages-Zeitstrahl. Im Querformat nutzen Kalender und Zeitstrahl das geteilte Layout.

### Raumcode scannen

Jeder Platz, Tisch, jedes Büro und jede Etage kann eine gedruckte **QR-Karte** tragen (§7). Tippe den **Scan-Button** im Reservieren-Hub, richte die Kamera auf die Karte — oder tippe ihren Code ein — und die App erkennt den Raum und zeigt genau, was *du* dort tun darfst:

- **Platz-Karte** — reserviere oder checke direkt auf genau diesem Platz ein (heutiges Fenster: Vormittag / Nachmittag / Ganzer Tag, wo der Workspace Halbtage nutzt, sonst ab jetzt für die nächsten Stunden).
- **Tisch-Karte** — die Plätze des Tischs mit ihrem Live-Status; wähle einen freien.
- **Büro- oder Etagen-Karte** — hat die Inhaberin sie reservierbar gemacht, ist die Funktion *Büro- & Etagen-Reservierungen* eingeschaltet **und** hast du das persönliche Recht (§7) — Inhaberinnen und Admins haben es immer — kannst du das **ganze Büro oder die ganze Etage** reservieren oder dort einchecken — mit derselben Zeitraum-Auswahl (Vormittag / Nachmittag / Ganzer Tag, oder freie Zeiten) und denselben **Serien**-Optionen wie ein Platz; der Preis je Halbtag wird angezeigt und landet auf deiner Rechnung. Andernfalls sagt dir das Formular, warum nicht — und ein Büro fällt auf seine Plätze zurück.

**Konflikte schützen in beide Richtungen:** Ein Büro oder eine Etage kann nicht reserviert werden, solange irgendein Platz darin in diesem Fenster schon gebucht ist — und kein Platz kann gebucht werden, solange sein Büro oder seine Etage als Ganzes reserviert ist.

## 5. Mitgliederverzeichnis (Tab Mitglieder)

Sieh, wer zu deiner Community gehört:

- Jede Karte zeigt **Foto** (oder Initiale), **Rolle**, **eigenen Status** („bis Freitag in Berlin…"), einen **Online/zuletzt-gesehen**-Indikator und einen **Reservierungs-Chip**: eingecheckter Platz, jetzt reserviert, oder die nächste Buchung.
- Antippen öffnet das **Detailblatt** — inklusive kommender Reservierungen.
- **Wische** über ein Mitglied, um es per **WhatsApp** anzuschreiben; der **Gruppen-Button** öffnet die WhatsApp-Gruppe der Community (von der Inhaberin hinterlegt).
- **Benachrichtigung senden** (in der Detailkarte und auf den Mitgliederkarten von *Mitglieder & Pläne*): eine kurze Notiz an ein anderes Mitglied — zugestellt als Push und als Benachrichtigung mit deinem Namen und deiner Nachricht. Der volle Text bleibt unter **Ereignisse → Nachrichten** lesbar, für Empfänger wie Absender (der Push selbst trägt aus Datenschutzgründen keinen Inhalt). Admins haben ein Megafon **Alle Admins benachrichtigen** in der Kopfzeile, das alle Admins inkl. Inhaber erreicht. Schaltbar über die Funktion *Mitglieder-Benachrichtigungen*.
- Eigenes Foto, Status und Telefon-Sichtbarkeit stellst du unter **Einstellungen** ein.
- Admins und Inhaberinnen sehen zusätzlich die **E-Mail** jedes Mitglieds unter dem Namen — normale Mitglieder nicht: Der Kontaktkanal von Mitglied zu Mitglied bleibt die freiwillig geteilte WhatsApp-Nummer.

## 6. Ereignisse & Bestätigungen (Glocken-Symbol)

Der Ereignis-Feed ist die Prüfspur deines Workspace: Reservierungen erstellt/geändert/storniert, Zahlungen erfasst, Ausgaben eingereicht, Extra-Tage-Anfragen, Rollenwechsel. Mitglieder sehen ihre eigenen Ereignisse; Admins und Inhaberinnen alle.

**Nachrichten:** Die Glocke sammelt auch deine Mitglieder-Benachrichtigungen (§5) — empfangene und gesendete, mit **vollem Text**, neueste zuerst. **Wische nach rechts**, um dem Absender zu antworten, **nach links**, um zu löschen (eine empfangene Alle-Admins-Rundnachricht lässt sich nicht löschen — sie verschwände für alle Admins). Ungelesene Nachrichten zählen auf der Glocke und dem App-Icon, bis du diesen Bildschirm öffnest.

**Das Bestätigungsprotokoll:** Wann immer ein Admin etwas *für jemand anderen* tut — einen Platz für dich bucht, deine Zahlung erfasst — bleibt es **offen, bis du bestätigst**. Offene Punkte sind oben angeheftet, mit Annehmen/Ablehnen, und du wirst benachrichtigt. Eigene Aktionen auf dich selbst brauchen nie eine Bestätigung.

**Validierungsquorum:** Für Geldfragen und Rollenwechsel legt die Inhaberin fest, *wer* zustimmen muss und *wie viele* Zustimmungen nötig sind. **Niemand validiert das eigene Ereignis** — nur eine andere Person kann das; gibt es keine, wartet die Anfrage schlicht. Unbeantwortete Anfragen verfallen nach 7 Tagen — nichts Kostspieliges wird je stillschweigend gewährt, und nichts wird sich selbst gewährt.

Die Inhaberin stellt das pro **Bereich** ein, unter **Einstellungen → Validierungsregeln**: Zahlungen, Ausgaben, Services, zusätzliche Halbtage, Rollenwechsel, Reservierungen und Anpassungen haben je eine eigene Regel (oder erben die Standardregel). Eine Regel legt die Zahl der nötigen Bestätigungen fest, *welche* Admins bestätigen dürfen (alle oder namentlich benannte) und ob die Inhaberin immer mitzeichnen muss.

<p><img src="images/validation-rules.jpg" width="240"> <img src="images/validation-rule-edit.jpg" width="240"></p>

*Links: eine Regel pro Bereich, mit Vererbung von der Standardregel. Rechts: Bearbeiten einer Regel — nötige Bestätigungen, zugelassene Validierende, Mitzeichnung der Inhaberin.*

## 7. Für Inhaberinnen: Editor & Einstellungen

Die gesamte Administration liegt unter **Einstellungen → Administration**. Eine Regel muss man kennen: **Der Einstellungs-Eintrag einer Funktion erscheint nur, solange die Funktion aktiviert ist** — schalte *Online-Zahlungen* unter **Funktionen** aus und ihr Konfigurationsbildschirm verschwindet mit (und kommt beim Wiedereinschalten zurück). Der Eintrag **Funktionen** selbst ist immer da, sodass sich ein Modul jederzeit wieder einschalten lässt.

<p><img src="images/settings-administration.jpg" width="240"></p>

- **Editor** (App-Leiste): Zeichne deinen Raum auf einem Raster — Etagen, Büros, Tische, Plätze (mit Ausrichtung, Stuhltyp und Ausstattung), Platzsperren für Wartung. Füge pro Etage ein **Hintergrundfoto** und verschieb- und skalierbare **Illustrationsbilder** hinzu. Löschen mit künftigen Reservierungen erzwingt erst deren Auflösung.
- **Workspace-ID & QR**: deine rollengebundenen Einladungen (§2). Die generierte ID lässt sich durch eine merkbare ersetzen (4–20 Buchstaben/Ziffern), kopieren, und der QR als PNG teilen.
- **Verfügbarkeit**: Öffnungstage, Schließtage, die Granularität — freie Start-/Endzeiten, ein Minutenraster (5/15/30/60), Halbtage, nur ganze Tage oder echte Uhrzeiten — und die **Arbeitszeiten** (Tagesbeginn, Halbtagsgrenze, Tagesende; bei echten Uhrzeiten auch, wie viele Stunden als halber und ganzer Tag gelten).
- **Funktionen**: Ganze Module pro Workspace ein-/ausschalten — Kalender, Ereignisse, Geld, Services, PDF-Export, Serienbuchung, Buchen für andere, Push, Platzsperren durch Admins, Zubehör-Aufpreise, **Online-Zahlungen**, **Rechnungen**, **Büro- & Etagen-Reservierungen**, **Kiosk-Modus**, **RFID-/NFC-Badges**, **Mitgliederverzeichnis**, **WhatsApp-Integration**, **Raum-QR-Codes**, **Mit-Inhaberinnen**, **Datenexport**, **Auto-Check-in/out**. Ein ausgeschaltetes Modul entfernt *alle* seine Bildschirme und Buttons für jedes Mitglied.

  Die Liste ist **hierarchisch**: Eine Funktion, die eine andere benötigt, steht eingerückt darunter mit dem Hinweis *Benötigt…* und ist ausgegraut, solange ihr Elternteil aus ist — *Geld* trägt Services, Zubehör-Aufpreise, Online-Zahlungen und Rechnungen; *Büro- & Etagen-Reservierungen* tragen das Zuweisungsrecht der Admins; *Kiosk-Modus* trägt die RFID-/NFC-Badges; *Mitgliederverzeichnis* trägt die WhatsApp-Integration. Ein ausgeschaltetes Elternteil nimmt seinen ganzen Teilbaum aus der App; die gespeicherte Wahl des Kindes kommt unangetastet zurück, sobald das Elternteil wiederkehrt.

<p><img src="images/workspace-id-qr.jpg" width="220"> <img src="images/availability-granularity.jpg" width="220"> <img src="images/features-toggles-1.jpg" width="220"> <img src="images/features-toggles-2.jpg" width="220"></p>

- **Mitglieder & Tarife**: Tippe ein Mitglied an, um sein **Verwaltungsblatt** zu öffnen — einen Service für es hinzufügen, den Abo-Prozentsatz setzen, die **Mehrverbrauchs-Politik** (§8) wählen, die **gleichzeitigen Reservierungen** deckeln, **Badges** ausstellen (§9), zum Admin befördern/degradieren, das Konto zum **Kiosk-Gerät** machen oder die Mitgliedschaft pausieren. Jede Zeile zeigt die **E-Mail** des Mitglieds unter dem Namen.

<p><img src="images/member-management-sheet.jpg" width="220"> <img src="images/member-subscription.jpg" width="220"> <img src="images/member-reservation-limit.jpg" width="220"></p>

*Das Verwaltungsblatt, der Dialog für den Abo-Prozentsatz und die Reservierungsobergrenze pro Mitglied.*

- **Abrechnung**: Gebührenbänder für die Prozent-Abos, Mehrverbrauchssätze, wählbare Abo-Stufen (mit optionalem frei verhandeltem Wert) — und **Tagespakete** (Tage zum Festpreis) für Mitglieder mit Paket-Politik.
- **Services** und **Zubehör**: die Kataloge hinter §8 — von der Inhaberin definierte Extras (Schließfächer, Druck…) und Platz-Ausstattung mit optionalem Aufpreis je Halbtag. Beides sind schlichte Listen mit einem **+**-Button.

<p><img src="images/billing-bands-levels-packages.jpg" width="220"> <img src="images/services-catalog.jpg" width="220"> <img src="images/services-new-service.jpg" width="220"> <img src="images/accessories-catalog.jpg" width="220"></p>

*Abrechnung (Bänder, Stufen, Tagespakete) · der Services-Katalog und sein Anlegeformular · der Zubehör-Katalog. Ein Admin erfasst einen Service-Konsum für ein Mitglied über dessen Verwaltungsblatt:*

<p><img src="images/member-add-service.jpg" width="220"></p>

- **Workspace-Einstellungen**: Name, Land/Währung, Zeitzone, Zahlungshinweise (IBAN, PayPal.me, Wero, Lydia, Wise), WhatsApp-Gruppenlink, **Tisch-Transparenz**, Exporte — und die **Gefahrenzone**: ein kompletter **Workspace-Reset** (löscht Buchungen, Geld und Grundriss; behält Konfiguration und Mitglieder), abgesichert durch das getippte „I agree".
- **Import/Export**: Die gesamte Konfiguration reist als **XML-Datei** — Backup, Vorlage oder Migration einer selbst gehosteten Instanz. Auch ein **Konfigurations-PDF** (Mitglieder, Plan, Preise, Funktionen) lässt sich erzeugen. Eine **Excel-Arbeitsmappe** exportiert die Live-Daten selbst — Workspace, Etagen, Tische, Plätze, Mitglieder, Reservierungen, Check-ins/outs, Zahlungen, Services und Rechnungen, je ein Tabellenblatt (Funktion *Datenexport*). Jeder Export landet im **Downloads**-Ordner deines Geräts.

### Raum-QR-Codes & Ganzraum-Reservierungen (Inhaberinnen)

Vier Schritte machen aus „scanne den Code auf dem Tisch" den täglichen Buchungsablauf (§4):

1. Markiere im **Editor** ein Büro oder eine Etage als **Als Ganzes reservierbar** und gib einen **Preis je Halbtag** an — das Eigenschaftsblatt des Büros, oder bei einer Etage das **Ebenen-Symbol direkt auf ihrer Zeile** (der Untertitel der Zeile nennt den aktuellen Buchungsstatus).
2. Aktiviere **Büro- & Etagen-Reservierungen** unter **Funktionen** (standardmäßig aus).
3. Gib jedem berechtigten Mitglied **„Darf ein ganzes Büro oder eine Etage reservieren"** — Inhaberinnen und Admins setzen es im Verwaltungsblatt des Mitglieds, nie für sich selbst.
4. Drucke die Karten: **Workspace-Einstellungen → Raum-QR-Codes (PDF)** — ein QR im Kreditkartenformat je **Platz, Tisch, Büro und Etage**, zehn pro A4-Seite, gespeichert in Downloads. Ausschneiden und jede Karte auf ihren Raum kleben.

Eine Büro-Reservierung umfasst **alle Tische darin**; eine Etagen-Reservierung die ganze Etage. Beide sind nur möglich, solange nichts darin gebucht ist — und sie erscheinen als eigene Zeilen auf der Rechnung des Mitglieds.

### Mit-Inhaberinnen (Inhaberinnen)

Sorge dafür, dass die Community nie von einem einzigen Konto abhängt:

1. Öffne *Mitglieder & Tarife → das Mitglied → **Mit-Inhaberschaft*** und wähle **aktiv** (Inhaber-Rechte sofort) oder **passiv** (Nachfolge in Wartestellung).
2. Übergib jederzeit mit ***Jetzt zur Inhaberin machen*** — die Mit-Inhaberin wird volle Inhaberin neben dir.
3. Verlässt die letzte Inhaberin je den Workspace, wird die beste Mit-Inhaberin **automatisch auf dem Server befördert** — aktiv vor passiv. Dieses Sicherheitsnetz greift selbst dann, wenn der Funktions-Schalter *Mit-Inhaberinnen* aus ist (der Schalter blendet nur die Ernennungs-Buttons aus).

### Online-Zahlungen einrichten (Inhaberinnen)

Jede Community kassiert auf ihr **eigenes** Anbieterkonto; die App speichert die geheimen Schlüssel nie auf einem Gerät — sie liegen auf dem Server.

1. Öffne **Einstellungen → Online-Zahlungen** (nur Inhaberin).
2. Wähle einen Anbieter und füge seine Schlüssel aus dessen Dashboard ein:
   - **PayPal** — Client-ID, Secret, Umgebung (beginne mit *sandbox*), Webhook-ID, Rückkehr-URL (PayPal Developer → deine REST-App).
   - **Kreditkarte (Stripe)** — Secret Key, Webhook-Signaturgeheimnis, Rückkehr-URL (Stripe → API-Keys / Webhooks).
   - **Mollie** — API-Schlüssel, Rückkehr-URL (bietet iDEAL, Bancontact, Karten…).
   - **Wero (über Mollie)** — derselbe Mollie-API-Schlüssel, mit Wero im Mollie-Konto aktiviert.
3. **Speichern** — ein grünes *Eingerichtet* erscheint. Aktiviere die Funktion **Online-Zahlungen** (Einstellungen → Funktionen), dann sehen Mitglieder **Online bezahlen** auf einer offenen Rechnung. (Der Einstellungs-Eintrag *Online-Zahlungen* selbst erscheint nur, solange die Funktion eingeschaltet ist.)

<p><img src="images/payment-config-paypal-stripe.jpg" width="240"> <img src="images/payment-config-mollie-wero.jpg" width="240"></p>

Ein gespeichertes Geheimnis wird nie wieder gezeigt — Feld leer lassen zum Behalten, tippen zum Ersetzen, **Entfernen** löscht den Anbieter. Die Gebühren sind die des Anbieters (typisch ~1,5–3 % pro Zahlung, keine Monatsgebühr); DesKilo kommt nichts hinzu, und der manuelle Überweisungs-/IBAN-Weg bleibt kostenlos.

Startet eine Zahlung nicht, aktiviere **Einstellungen → Erweitert → Entwicklermodus** und öffne den **Entwickler**-Bildschirm: die *payments*-Spur zeigt genau, welche Anbieter eingerichtet sind und welche Felder noch fehlen.

<p><img src="images/developer-payment-traces.jpg" width="240"></p>

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

1. Öffne **Einstellungen → RFID-/NFC-Badges** (nur Inhaberin). Schalte **NFC-Badge-Check-in aktivieren** ein und lies die **Gerätestatus**-Zeile — sie unterscheidet *bereit*, *NFC in den Android-Einstellungen ausgeschaltet* und *keine NFC-Hardware* (iPads haben keine).
2. Gib jedem Mitglied eine Karte: **Mitglieder & Tarife → das Mitglied → Badges → Karte registrieren**, dann die Karte ans Gerät halten. Jede Karte mit lesbarem Chip passt (MIFARE, NTAG…). Mitglieder können es auch **selbst** erledigen: **Einstellungen → Mein Badge** stellt ihren druckbaren QR-Badge aus und registriert ihre eigene Karte — ganz ohne Admin.
3. Nutze sie an einem **Kiosk** (§9): das Mitglied tippt die Karte an, um zu reservieren oder einzuchecken. Eine verlorene Karte im selben Badges-Dialog widerrufen; **wische einen widerrufenen Badge nach rechts, um ihn endgültig zu löschen**.

Badges gehören zu **einem Workspace** — der Dialog nennt, in welchem du registrierst; registriere die Karte also in dem Workspace, dessen Kiosk sie lesen soll. Dieselbe physische Karte kann dich in mehreren Workspaces bedienen. Ein **als PDF** gespeicherter QR-Badge druckt zehn Kopien im Kreditkartenformat auf eine A4-Seite — Ersatz inklusive.

<p><img src="images/nfc-config.jpg" width="240"> <img src="images/member-badges-dialog.jpg" width="240"></p>

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
- **Rechnungen**: Stellt der Workspace Rechnungen aus (unten), findest du deine jederzeit unter **Geld → Rechnungen** — tippe eine an, um sie in der App zu lesen (Positionen, Saldo, Stand), lade das PDF herunter und exportiere in EU-Workspaces die maschinenlesbare E-Rechnung (XML).
- **Zahlen**: DesKilo erfasst Zahlungen; offene Rechnungen zeigen die **Zahlungshinweise** des Workspace (IBAN mit einem Tipp kopiert, PayPal.me öffnet direkt). Erfasse eine Zahlung („ich habe gezahlt") mit Methode, dem **Datum, an dem das Geld geflossen ist** (heute als Vorgabe) und dem **Monat, den sie begleicht** (der laufende als Vorgabe, ein Schritt zurück für Rückstände, einer vor für eine Vorauszahlung) — die Gegenseite bestätigt. Dieser Monat entscheidet, auf welcher Abrechnung und welcher Rechnung die Gutschrift landet. Hat der Workspace **Online-Zahlungen** aktiviert und ist sein Server dafür eingerichtet, lässt **Online bezahlen** den offenen Betrag sofort begleichen — per **PayPal, Kreditkarte (Stripe), Mollie oder Wero**, je nachdem was der Workspace aktiviert hat (mehrere zeigen eine Auswahl).
- **Ausgaben**: Kaffee für den Raum gekauft? Reiche die Ausgabe ein — ein anderer Admin genehmigt (keine Selbstgenehmigung) und der Betrag wird deiner nächsten Abrechnung gutgeschrieben.
- **Services**: von der Inhaberin definierte Extras (Schließfächer, Druck…), deren Konsum nach deiner Bestätigung auf der Abrechnung landet.

### Rechnungsstellung (Inhaberinnen & Abrechnungs-Admins)

*Inhaberinnen stellen Rechnungen aus; Admins auch, sobald die Inhaberin die Delegation **Admins stellen Rechnungen aus** erteilt. Die Funktion **Rechnungen** steht in der Funktionsliste (§7) unter Geld.*

Eine Rechnung in DesKilo wird generiert, nie verfasst: Ihre Positionen werden **ausschließlich aus den erfassten Daten des Monats abgeleitet** — Abo, Mehrverbrauch, Aufpreise, Services, Pakete — abzüglich der Zahlungen und Gutschriften des Monats, sodass die Schlusszeile **der geschuldete Saldo ist**. Jedes Dokument hält die Postadressen des Workspace und des Mitglieds fest (deine setzt du unter **Einstellungen → Adresse**; die Workspace-Adresse steht in den Workspace-Einstellungen) und wird beim Ausstellen **digital signiert** — danach ändert es sich nie mehr. Ein **detaillierter Anhang** (Kontobewegungen und Anwesenheit des Monats) lässt sich beim Ausstellen mit einem Schalter beilegen.

Aussteller öffnen **Geld → Rechnungen** und landen auf einem Hub mit drei Tabs unter einer Live-Übersichtsleiste:

- **Zu berechnen** — jedes Mitglied, dessen Vormonat abrechenbare Daten und noch keine Rechnung hat, samt Monatssumme: pro Mitglied ausstellen (mit Vorschau der abgeleiteten Positionen) oder **Alle berechnen** in einem Durchgang — eine Bestätigung nennt vorher Anzahl, Monat und Gesamtbetrag. **Eine aktive Rechnung pro Mitglied und Monat** — ein Monat wird erst wieder berechenbar, nachdem seine Rechnung storniert wurde. Das Ausstellungsblatt öffnet auf dem **abgeschlossenen Monat** (dem, dessen Zahlen sich nicht mehr ändern); wählt man den laufenden, warnt es, denn ein Monat lässt sich nur einmal abrechnen.
- **Offen** — ausgestellte Rechnungen, die auf Begleichung warten, älteste zuerst; was länger als 30 Tage wartet, wird rot — auf der Karte wie im Übersichtsstreifen. **Tippe eine Karte an, um die Rechnung zu lesen**; die Schaltflächen handeln: **Zahlungserinnerung senden** (erfasst die Erinnerung und teilt das PDF mit einer Nachricht — die Karte zeigt *Erinnert ×N*), **Als fehlerhaft markieren** (storniert die Rechnung zur Korrektur: Sie wandert durchgestrichen ins Archiv, und eine **Ersatzrechnung** leitet denselben Monat aus den korrigierten Daten neu ab und verweist auf das Original) und **Als bezahlt markieren**. **Eine Teilzahlung schließt keine Rechnung**: sie bleibt unter Offen, mit Badge *Teilweise bezahlt* und Restbetrag, bis der offene Rest ausdrücklich **über das Validierungs-Framework storniert** wird — Admin/Inhaber beantragen die Stornierung (mit Grund), die Validierer bestätigen, erst dann wandert die Rechnung als *Teilweise bezahlt · Restbetrag storniert* ins Archiv.
- **Rechnungsbericht-Editor** (Inhaber, Stift-Symbol in der Rechnungs-Kopfzeile) — ein Band-Reporting-Werkzeug für das Rechnungs-PDF: **Kopfband**, **Rumpfband mit den Zeilen** und **Fußband**, jedes in [Liquid](https://shopify.github.io/liquid/) — `{{ number }}`, `{{ member }}`, Bedingungen `{% if voided %}…{% endif %}`, Schleifen `{% for line in lines %}{{ line.label }} | {{ line.amount }}{% endfor %}` — plus ein einfaches Zeilen-Markup (`#` Titel, `##` Abschnitt, `>` Kleingedrucktes, `---` Trenner, `a | b` Tabellenzeile, `=` fette Zeile, `:::` … `|||` … `:::` nebeneinanderliegende Spalten — die Adressblöcke Verkäufer links / Kunde rechts und der rechtsbündige Summenblock einer französischen Rechnung; die mitgelieferten Vorlagen folgen genau dieser Struktur). **Zurücksetzen** liefert das eingebaute Layout als funktionierendes Beispiel; **Vorschau** rendert die neueste Rechnung als Wasserzeichen-Kopie durch die ungespeicherten Bänder. Ein **Dokumentwähler** wechselt zwischen der Rechnung, der **Proforma**, der **Mitglieder-Abrechnung** und jeder Mahnstufe — jedes sein eigener Bericht. Die Proforma nutzt die Rechnungsbänder, bis du sie anpasst; eine angepasste Abrechnung ersetzt das eingebaute Monats-PDF. Eine **Vorlagen-Galerie** bietet für jedes Dokument vier fertige Berichte — *Klassisch*, *Einfach*, *Ausführlich*, *Formeller Brief* — auswählen und erweitern; jede Rechnungsvorlage trägt bereits die unten genannten Pflichtangaben. Die **Schnellvorschau** rendert das Ergebnis sofort in der App (deine neueste Rechnung, oder simulierte Beispieldaten, wenn keine existiert — ohne PDF-Umweg), und das **Vorschau**-Menü erzeugt das PDF zum **Herunterladen aufs Gerät** oder Teilen. Editor und Mahnregeln sind auch über die **Workspace-Einstellungen** erreichbar.
- **Mahnwesen** — die Inhaberin setzt die **Mahnregeln** (Checklisten-Symbol in der Rechnungs-Kopfzeile): Anzahl der Stufen, Tage bis zur ersten Erinnerung, Tage zwischen den Mahnungen. Überfällige offene Rechnungen werden mit **„Mahnstufe N fällig“** markiert und die Glocke der Karte wird rot — nichts wird je automatisch versendet. Der Versand erzeugt einen **Zahlungserinnerungs-Brief** (Stufe 1 freundlich, höhere Stufen bestimmter) aus der Vorlage dieser Stufe — fertig mitgeliefert in deiner Sprache und je Stufe im Bericht-Editor anpassbar, mit den Zusatzfeldern `{{ reminder_level }}`, `{{ reminder_date }}` und `{{ days_open }}`. Eine kaputte Vorlage blockiert nie eine Rechnung (das eingebaute Layout übernimmt); Storno-Wasserzeichen, digitale Signatur, Anhang und Seitenzahlen bleiben fix — und das E-Rechnungs-XML bleibt unangetastet.
- **Rechtsgültige Rechnungen** — die mitgelieferten Vorlagen drucken alles, was eine französische *facture* tragen muss: die vollständige Verkäufer-Identität (Name, **Rechtsform & Kapital**, Adresse, **Handelsregister**, **USt-IdNr.** — deklariert unter *Arbeitsbereich-Einstellungen → Rechtsidentität*, neuer Abschnitt **Rechnungsangaben**), Name und Adresse des Kunden, die eindeutige fortlaufende Nummer mit Datum, je Zeile **Menge, Einzelpreis und MwSt-Satz**, die MwSt-Aufstellung je Satz mit **Netto- / MwSt- / Gesamtsumme** sowie die Zahlungsklauseln: **Zahlungsbedingungen**, **Skonto**, **Verzugszinsen** und die **40-€-Beitreibungspauschale** — leere Klauseln drucken den gesetzlichen Standardtext. Optionale Zeilen (Berufshaftpflicht, besondere Angaben wie *TVA non applicable, art. 293 B du CGI* über den Befreiungsgrund) erscheinen erst nach Deklaration. Variablen: `{{ seller_legal_form }}`, `{{ seller_registration }}`, `{{ seller_vat_id }}`, `{{ client_address }}`, `{{ payment_terms }}`, `{{ late_penalty }}`, `{{ recovery_indemnity }}`, `{{ escompte }}`, `{{ insurance }}`, `{{ special_mentions }}`, `{{ net_total }}`, `{{ vat_total }}`, und je Zeile `{{ line.qty }}`, `{{ line.unit_price }}`, `{{ line.vat_rate }}`, `{{ line.net }}`.
- **Fakturierung mit oder ohne MwSt — auch als Verein** — das **MwSt-Regime** des *Rechtsidentität*-Bildschirms gilt jetzt durchgängig: Nur ein als *umsatzsteuerpflichtig* deklarierter Arbeitsbereich stempelt einen Satz auf Abonnements, Zuschläge, Services und Pakete (serverseitig, Migration 0095); die MwSt-Auswahl in den Service-/Paket-Editoren und die Steuersatz-Kachel verschwinden unter jedem anderen Regime — Rest-Sätze können niemanden mehr besteuern. Die neue Wahl **Organisationsform** (*Unternehmen* / *Verein*) deckt die französischen Vereinsregeln (loi 1901) ab: Vereinsdokumente lassen die B2B-Standardklauseln weg (Verzugszinsen, 40-€-Pauschale, Skonto — nur zwischen Unternehmen Pflicht; eigener Text wird weiterhin gedruckt), die Hinweise wechseln auf **RNA (W…)** statt Handelsregister und *Association loi 1901* als Rechtsform, und das Befreiungsfeld schlägt die passenden Vermerke vor — *TVA non applicable, art. 293 B du CGI* oder *Exonération de TVA, art. 261, 7-1° du CGI* (Leistungen an Mitglieder).
- **Die Berichts-Suite** — drei weitere Engine-Dokumente neben der Rechnungsfamilie, jedes mit den vier Vorlagen und eigenem Template im Berichtseditor: die **Finanzvereinbarung** (alle geltenden Preise eines Mitglieds — Abo, zusätzlicher halber Tag, Services, Pakete, Raum- und Zubehörzuschläge; Inhaber/Admins senden sie aus dem Aktionsblatt eines Mitglieds, jedes Mitglied kann seine eigene unter *Finanzen → Dokumente* ansehen/herunterladen/teilen), der **Zahlungsbericht** (alles im Monat Gezahlte, Gemeldete oder Validierte — die kleine Bilanz, Self-Service in derselben Zeile) und der **Arbeitsbereichsbericht** (Identität, Grundriss-Zahlen, Verfügbarkeit, Funktionen und Preise — *Arbeitsbereich-Einstellungen → Arbeitsbereichsbericht*).
- **Die Dokumentbibliothek** — *Einstellungen → Dokumente*: Satzung, Anleitungen, Finanzberichte und Protokolle des Arbeitsbereichs, VERLINKT aus dem System, das Sie schon nutzen — Google Drive, OneDrive, SharePoint, Dropbox, Nextcloud oder ein beliebiger https-Link (das Drive verwaltet seine Zugriffe selbst; die App speichert nie fremde Zugangsdaten). Jeder Eintrag hat eine **Sichtbarkeitsrolle**: alle Mitglieder, Admins und Inhaber, oder nur Inhaber — serverseitig erzwungen. Admins/Inhaber pflegen per +-Knopf; der Funktionsschalter *Dokumentbibliothek* aktiviert alles.
- **Archiv** — geschlossene Rechnungen, filterbar nach Mitglied und Monat und sortierbar; stornierte Rechnungen sind **standardmäßig ausgeblendet** — der Chip *Stornierte anzeigen* holt die Korrekturkette zurück; unter den Filtern steht, wie viele Rechnungen passen, und **Filter zurücksetzen** holt das ganze Archiv zurück. Jede Zeile trägt Status, Monat und Betrag, mit **PDF herunterladen** direkt dort. **Tippe eine Zeile an, um die Rechnung zu öffnen** — Positionen, Saldo, Empfänger, Stand, welche Rechnung sie ersetzt oder durch welche sie ersetzt wurde, die Zahlung, die sie geschlossen hat, die gesendeten Erinnerungen, ihre Signatur — und jede noch erlaubte Aktion im Klartext: PDF teilen, **E-Rechnung (XML)** exportieren, erinnern, als bezahlt markieren, als fehlerhaft markieren, Ersatzrechnung ausstellen.

**Als bezahlt markieren heißt: eine echte Zahlung zuordnen.** Der Dialog listet die registrierten Zahlungen des Mitglieds — erfasste Überweisungen und bestätigte Online-Zahlungen — und du ordnest die Rechnung einer davon zu; es gibt keinen Betrag einzutippen. **Mehr** gezahlt? Erstelle eine **Gutschrift über den Überschuss** (eine Gutschrift auf dem Konto des Mitglieds) oder akzeptiere erzwungen mit einer Pflichtnotiz. **Weniger** gezahlt? Akzeptiere mit einer Pflichtnotiz. Alle mit Rechnungszugriff werden über bezahlte Rechnungen benachrichtigt, und die Inhaberin kann eine Validierungsregel **Rechnungszahlung** (§6) darauf legen: Die Zuordnung wartet dann auf das Quorum — eine Ablehnung öffnet die Rechnung wieder.

**Eine bezahlte Rechnung ist endgültig.** Einmal zugeordnet kann sie nie mehr storniert, ersetzt oder geändert werden — Korrekturen passieren vor der Zahlung, indem die offene Rechnung storniert und ihre Ersatzrechnung ausgestellt wird. Eine Zahlung, die den Betrag **nicht** deckt und mit Notiz akzeptiert wurde, erscheint als **teilweise bezahlt**, nicht als bezahlt.

**Proforma.** Beide Hub-Tabs bieten eine Proforma: Auf **Zu berechnen** rendert sie die abgeleiteten Positionen des Monats als Angebot — ohne Nummer, ohne Signatur, mit PROFORMA gestempelt, und **es wird nichts ausgestellt**; auf **Offen** gibt sie die ausgestellte Rechnung als Zahlungsaufforderung aus, die nicht als Original durchgehen kann. Auf den Offen-Karten ist jede Aktion ein Icon mit Tooltip (stornieren · Proforma · Mahnung · als bezahlt markieren) — drei Beschriftungen nebeneinander liefen aus der Karte.

**Stempel.** Eine stornierte Rechnung trägt ein großes diagonales **ERRONÉE/FEHLERHAFT** auf jeder Seite ihres PDFs, hellgrau über dem Inhalt: Auf einem Schreibtisch oder als Fotokopie ist sie nicht mit einem gültigen Dokument zu verwechseln. Derselbe Stempel sagt **PROFORMA** auf einem Angebot und **KOPIE** auf jeder Rechnung, die jemand anderes als der Aussteller rendert — das Original liegt beim Workspace.

**Das Register.** Das Listen-Icon in der Rechnungen-Leiste öffnet ein Journal mit einer Zeile pro Rechnung: **Datum · Name · Betrag · Status**, nach Datum sortiert (Tippen auf die Spalte Datum dreht die Richtung), mit der Summe am Fuß und einer **Jahres**-Auswahl, sobald es mehr als eines gibt.

**Den Zeitraum an die Buchhaltung geben.** Aus dem Register exportieren Ausstellende eine **SAF-T**-Datei — das *Standard Audit File for Tax* der OECD, das XML, das Buchhaltungssoftware und Finanzverwaltungen lesen. Sie umfasst genau das, was das Register zeigt: 2026 gewählt heißt die Datei für 2026 — das Unternehmen so, wie die eigenen Rechnungen es angeben, jeder Kunde, jede Rechnung mit Positionen und Summen und die Zahlungen, die sie beglichen haben. Stornierte Rechnungen bleiben als *annulliert* darin: Eine Audit-Datei löscht nie, was passiert ist. Bewusst nicht enthalten ist der **Kontenrahmen**: DesKilo erfindet keine Kontonummern, denn ein falscher Code muss von Hand ausgebucht werden. Die Buchhaltung ordnet die Rechnungen ihren eigenen Konten zu — das ist ihre Arbeit und dauert eine Minute.

**Frankreich: der FEC.** Ein französischer Workspace hat eine zweite Wahl, den **FEC** (*Fichier des Écritures Comptables*) — die Datei, die eine Prüfung dort gesetzlich verlangt. Sie ist kein XML: eine tabulatorgetrennte Flachdatei aus **Buchungen**, benannt `<SIREN>FEC<JJJJMMTT>.txt`, mit den 18 vorgeschriebenen Spalten in vorgeschriebener Reihenfolge. Weil sie aus Buchungen besteht, kommt sie nicht ohne Kontonummern aus: Der Export fragt sie zuerst ab — vorbelegt mit dem französischen Kontenrahmen (411 Kunden, 706 Dienstleistungen, 512 Bank) und korrigierbar. Jede Rechnung bucht ihre Forderung gegen den Erlös zum **Bruttobetrag**; die verrechneten Gutschriften und die Zahlung, die sie beglichen hat, laufen mit eigenem Datum über die Bank, verbunden mit der Rechnungsnummer. Stornierte Rechnungen fehlen: Eine vor der Zahlung stornierte wurde nie gebucht, es gibt nichts zu stornieren. Die Spalte *Name* folgt dem Lesenden — Ausstellende überfliegen Mitglieder, Mitglieder ihre eigenen Rechnungsnummern. Mitglieder sehen nur, was sie betrifft: ausgestellte Rechnungen, nie eine stornierte.

### Wohin die E-Rechnung muss (EU)

Die Aktion **E-Rechnung (XML)** öffnet ein Blatt, das genau das für das Land des Workspace beantwortet, bevor es die Datei herausgibt: über welchen Kanal Geschäftskunden sie erwarten, ob eine Plattform dazwischen liegt und über welchen Kanal öffentliche Auftraggeber erreicht werden. In der Union existieren vier Modelle:

- **Peppol** — ein Access Point liefert die Datei an den Kunden; keine staatliche Plattform dazwischen. Genau so funktioniert die belgische B2B-Pflicht, und über Peppol werden EU-weit die öffentlichen Auftraggeber erreicht (die Richtlinie 2014/55/EU macht jede Verwaltung empfangsfähig für eine EN-16931-Rechnung).
- **Zugelassene Plattformen** — Frankreich: Man wählt eine *plateforme agréée* (die umbenannte PDP), sie transportiert die Rechnung und meldet die Daten an die Finanzverwaltung. Das öffentliche Portal ist ein Verzeichnis, kein Postfach. Öffentliche Auftraggeber bleiben auf **Chorus Pro**.
- **Clearance-Plattformen** — Italien (**SdI**, FatturaPA), Polen (**KSeF**, FA(3)), Rumänien (**RO e-Factura** über das SPV, CIUS-RO): Die Plattform erhält die Rechnung *zuerst* und leitet sie weiter; ein direkter Versand an den Kunden existiert nicht. Jede schreibt ihre eigene Syntax vor — das Blatt warnt deshalb, dass die von DesKilo exportierte EN-16931-Datei nicht die akzeptierte ist. Nutze sie für Peppol, öffentliche Auftraggeber und ausländische Kunden und lass die Plattform oder die Steuerberatung konvertieren.
- **Kein vorgeschriebener Kanal** — Deutschland heute: Der Empfang ist seit 2025 Pflicht, das Ausstellen kommt gestaffelt, aber ein E-Mail-Anhang ist eine gültige E-Rechnung; erwartet werden XRechnung und ZUGFeRD. Öffentliche Verwaltung: **OZG-RE / ZRE** oder Peppol.

**Factur-X — eine Datei, zwei Lesende.** Das E-Rechnungs-Blatt bietet zuerst **Factur-X (PDF)**: ein ganz normal aussehendes Rechnungs-PDF mit der maschinenlesbaren Rechnung *darin* (die EN-16931-Daten als CII, wie das Format es verlangt). Ein Mensch öffnet es und sieht die Rechnung; eine Plattform öffnet es und findet `factur-x.xml`. Genau das tauschen kleine Unternehmen in Frankreich und Deutschland tatsächlich aus, und es braucht keine zweite Datei. Das reine **XML** bleibt darunter verfügbar, für Plattformen, die es nackt wollen.

**Senden, ohne die App zu verlassen.** Die Inhaberin registriert die Plattform des Workspace unter *Workspace-Einstellungen → Rechtliche Identität → **E-Rechnungs-Plattform***: eine Upload-URL und ein Token. Jede Plattform, die einen Upload mit Zugangsdaten annimmt, funktioniert — eine zugelassene Plattform, ein Peppol Access Point, eine nationale Plattform. Das Token liegt serverseitig, kommt nie auf ein Telefon zurück, und die App kann nur melden, dass eines gesetzt ist. Danach beginnt das Blatt mit **An die Plattform senden**: das Factur-X-Dokument geht direkt hinaus, und das Detailblatt der Rechnung hält fest, wann es ging, was die Plattform antwortete und welche Id sie zurückgab. Jeder Versuch wird protokolliert — angenommen, abgelehnt oder nicht übermittelt — denn ein Dokument, das *vielleicht* draußen ist, ist schlimmer als ein gescheiterter Versand.

DesKilo übermittelt weiterhin nichts auf eigene Rechnung: Es erzeugt das Dokument und übergibt es der Plattform, die du gewählt hast.

**Proben ohne Risiko.** Ein Workspace kann neben dem Produktions-Endpunkt zusätzlich **Test-Endpunkte** hinterlegen (das UAT der Plattform oder ein Dev-Ziel). Mit eingeschaltetem **Entwicklermodus** des Workspace (eine workspace-weite Einstellung, die nur Inhaberinnen und Admins umlegen, unter Einstellungen → Erweitert) bietet das Senden die Wahl der Umgebung an, eine Test-Einreichung ist in der Übertragungshistorie der Rechnung als solche markiert, und der Produktions-Endpunkt wird für eine Probe nie verwendet — eine nicht konfigurierte Testumgebung verweigert schlicht, statt zurückzufallen.

**Vor dem ersten Export die rechtliche Identität ausfüllen.** Unter *Workspace-Einstellungen → **Rechtliche Identität & E-Rechnung*** erklärt die Inhaberin das **Steuerregime** und die Nummer, die die Norm damit verlangt: außerhalb der Umsatzsteuer eine **Registernummer** (SIREN, HRB, CIF…); bei Steuerbefreiung eine **Umsatzsteuer-ID** plus den Grund der Befreiung. Mitglieder ergänzen ihr **Land** — und ihre USt-ID, falls sie als Unternehmen abrechnen — neben ihrer Adresse unter *Einstellungen → Adresse*. DesKilo prüft das alles **vor** dem Erzeugen der Datei und verweigert sie unter Nennung des fehlenden Punktes: Eine von der Plattform abgelehnte Rechnung ist schlimmer als gar keine. Ein **umsatzsteuerpflichtiger** Workspace exportiert wie jeder andere — sobald seine **Steuersätze** eingerichtet sind (nächster Abschnitt): mit Sätzen trägt die Rechnung eine echte Aufteilung, ohne sie verweigert DesKilo die Datei, statt eine Null zu erklären, an die es nicht glaubt.

Auch die Fristenkalender verschieben sich: Prüfe vor dem Termin, der dich betrifft, bei der eigenen Finanzverwaltung.

### Mehrwertsteuer (Inhaberinnen)

**Preise in DesKilo sind Bruttopreise.** Was Sie als Abo-, Leistungs- oder Tagespaketpreis eintragen, ist das, was das Mitglied zahlt. Die Steuer einzuschalten ändert keinen einzigen geschuldeten Betrag — es sagt, wie viel davon Steuer ist. Deshalb bewegen sich Rechnung, Abrechnung und Kontingent nicht, wenn Sie Sätze anlegen, und deshalb muss nie ein Betrag abgestimmt werden.

**Sätze einrichten.** *Workspace-Einstellungen → Rechtliche Identität & E-Rechnung → **Steuersätze***. Eine leere Liste heißt: keine Steuer — so startet jeder Workspace. **Übliche Sätze übernehmen** füllt die Liste mit Regelsatz und ermäßigten Sätzen Ihres Landes als erster Entwurf — ein Ausgangspunkt, keine Steuerberatung: Sätze ändern sich, und welche Leistung unter welchen Satz fällt, ist eine Frage für Ihre Steuerberatung. Ein Satz ist der **Standard** (der Stern): Abos, Überschreitungen, Zuschläge und Korrekturen nutzen ihn, ebenso jede Leistung ohne eigenen Satz. Einen Satz zu entfernen löscht ihn nie — einer, auf den eine Rechnung oder eine Leistung noch verweist, bleibt erhalten und wird deaktiviert, damit nichts stillschweigend neu besteuert wird.

**Sätze pro Position.** Eine Leistung (*Leistungen*) und ein Tagespaket (*Abrechnung → Pakete*) tragen jeweils ihren eigenen Satz, im jeweiligen Formular gewählt; belassen Sie es beim **Standard des Spaces**, folgt sie dem Standardsatz. Das Steuerfeld erscheint erst, wenn der Workspace Sätze hat.

**Was sich auf einem Dokument ändert.** Eine Rechnung, die nach dem Anlegen der Sätze ausgestellt wird, trägt die Aufteilung wie ausgestellt: die Positionstabelle bekommt eine Satz-Spalte, und über dem Gesamtbetrag zeigt das PDF den **Netto**-Betrag und je Satz eine Zeile. Die Rechnungsansicht in der App sagt dasselbe. Die **E-Rechnung (XML)** trägt, was EN 16931 verlangt — je Satz ein Steuer-Subtotal, die Nettobeträge, die USt-ID der Verkäuferin (BR-S-02) — in UBL wie in CII: ein Factur-X-Dokument ist damit auch für eine steuerpflichtige Verkäuferin gültig. **SAF-T** deklariert jeden Satz in seiner Steuertabelle und bucht jede Zeile netto mit der Steuer daneben; der **FEC** bucht die Forderung brutto gegen den Nettoerlös plus ein Konto **vereinnahmte Steuer** (standardmäßig 445710, änderbar — im Export-Dialog oder ein für alle Mal im Bildschirm der rechtlichen Identität).

**Eine ausgestellte Rechnung ändert sich nie.** Sie trägt die Sätze, die Identität und die Beträge, mit denen sie signiert wurde — das macht sie zur Rechnung. Sätze heute anzulegen setzt keine Steuer auf das Dokument vom letzten Monat, und die rechtliche Identität heute zu vervollständigen setzt keine Registernummer darauf. Muss ein Dokument die neuen Zahlen tragen, markieren Sie es als **fehlerhaft** und stellen eine **Ersatzrechnung** aus: die Korrekturkette ist auf beiden Dokumenten sichtbar — genau das, was eine Prüfung sehen will.

## 9. Kiosk-Modus (Wandtablet)

Häng ein Android-Tablet oder iPad neben die Tür und lass alle beim Reinkommen einchecken:

1. Die Inhaberin legt ein normales Konto für das Gerät an, lässt es dem Workspace beitreten und markiert es unter *Mitglieder & Tarife* als **Kiosk**.
2. **Der Kiosk-Modus startet nie von selbst.** Bei jedem App-Start fragt das Tablet *Kiosk-Modus starten?* — bestätige, und das Gerät riegelt sich ab: nur noch der Vollbild-Grundriss, Zurück-Button deaktiviert, die App pinnt sich fest, sodass sich nichts anderes öffnen lässt; den Kiosk-Modus verlässt man nur durch Neustart des Tablets. Wähle stattdessen *Jetzt nicht* und die App öffnet normal — praktisch für die Einrichtung. Die Kiosk-Zuweisung selbst lässt sich jederzeit zurücknehmen: am Gerät unter **Einstellungen → Kiosk-Gerät** oder durch die Inhaberin unter *Mitglieder & Tarife*.
3. Jedes Mitglied trägt einen **Badge** — ausgestellt von einem Admin (*Mitglieder & Tarife → Badges*) oder vom Mitglied selbst (**Einstellungen → Mein Badge**, §7): ein druckbarer **QR-Badge** und/oder seine **RFID/NFC-Karte**.
4. Am Kiosk: Platz antippen (oder **Diese Etage**) → **Einchecken**, **Reservieren** oder **Auschecken** → Badge vorzeigen:
   - **RFID/NFC-Karte antippen.** Solange der Kartenleser scharf ist, bleibt die Kamera aus; ist NFC ausgeschaltet oder nicht vorhanden, sagt es das Formular ausdrücklich.
   - Oder tippe **QR-Badge scannen** — das Tablet liest den gedruckten Badge **mit seiner eigenen Kamera** (standardmäßig die Frontkamera, denn die Rücklinse eines Wandtablets zeigt zur Wand; umschalten unter *Einstellungen → Mit der Frontkamera scannen*). Ein USB/Bluetooth-Scanner oder das Eintippen des Codes funktioniert ebenfalls.
5. **Nichts passiert ohne dein Zutun:** Der Kiosk identifiziert den Badge, schließt die Leser und zeigt eine Zusammenfassung — *wen* er erkannt hat, *was* passieren wird, *wo* und *wann*. Erst **Bestätigen** führt aus und aktualisiert den Plan; **Ablehnen** verwirft.

Deine Identität existiert nur für den Moment der Operation: die Berechtigung geht einmal zum Server, die Buchung läuft **auf deinen Namen**, und auf dem Tablet wird nichts gespeichert — du bist „abgemeldet", sobald es fertig ist. (Anmeldung pro Vorgang mit Google steht noch auf der Roadmap; **iPads haben kein NFC**, dort ist der Kamera-QR-Weg der richtige.)

## 10. Benachrichtigungen

Check-in-Erinnerungen, offene Bestätigungen, Ausgaben-Entscheide — und wenn ein Admin **eine deiner Reservierungen entfernt** (Übersteuern), werden du und die Admins benachrichtigt. Zustellung ist lokal zuerst; Server-Pushes kommen auf Android, iPhone/iPad, im Browser und auf macOS ohne Zusatz-App an (Firebase Cloud Messaging) — *Einstellungen → Erweitert* zeigt, ob Push auf diesem Gerät aktiv ist. Das App-Icon zeigt deine offenen Bestätigungen **plus deine ungelesenen Nachrichten** — auf Android, iPhone/iPad, im macOS-Dock, in der Windows-Taskleiste und in installierten Web-Apps. Mitglieder-Nachrichten werden **einmal pro Gerät mit Absender und vollem Text** angekündigt — auch was ankam, während die App geschlossen war, direkt beim nächsten Öffnen. Push-Inhalte tragen nie Namen oder Zeiten; der Text entsteht lokal in der App.

## 11. Datenschutz

Minimale Daten: Name, E-Mail, Tarif, Buchungen, Konto. Du bestimmst dein Foto, deinen Status, ob dein Name auf dem Plan erscheint und ob deine Telefonnummer im Verzeichnis sichtbar ist. Kiosk-Badges werden nur als Hash gespeichert — ein verlorener Badge wird widerrufen, nicht erraten. Kein Tracking, keine Dritt-Analytik. Finanzhistorie wird bei Kontolöschung anonymisiert, nicht gelöscht (Aufbewahrungspflichten).

## 12. Plattformen

Android (Google Play), iPhone/iPad, Desktop — **macOS** (ein DMG: DesKilo in „Programme“ ziehen) und **Windows** (ein MSI-Installer) aus jedem Release — und der **Browser**: dieselbe App, nichts zu installieren, unter der Adresse, die dein Space veröffentlicht. Deine Daten folgen deinem Konto: ein am Handy gebuchter Platz erscheint eine Sekunde später im Browser-Tab.

Was der Browser nicht kann, ist das, was eine Seite nicht darf: ein NFC-Badge lesen oder einen QR-Code mit der Kamera scannen wie der Kiosk. Alles andere — Plan, Buchungen, Mitglieder, Geld, Rechnungen, PDF-Downloads — ist dieselbe App. Beim ersten Start des macOS-DMG die App rechtsklicken und *Öffnen* wählen: der Build ist noch nicht von Apple notarisiert, ein einfacher Doppelklick führt zur Gatekeeper-Warnung.
