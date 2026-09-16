# Administratorhandbuch — den Bereich einrichten

Für die Person, die den Bereich aufsetzt: was jeder Parameter
entscheidet, in der Reihenfolge, in der der Fragebogen ihn abfragt, dann
die Stammdaten, dann der Raumplan und seine Bilder. Die technische Seite
steht im [technischen Handbuch](Admin-Technical-Guide.de);
wie eine Konfiguration von einem Entwicklungs- in einen Produktivbereich
wandert, steht im [Umgebungshandbuch](Environments-Guide.de).

<!-- anchor: config.setup.questionnaire -->
## Der Einrichtungsfragebogen

Der Web-Fragebogen fragt der Reihe nach nur das ab, was Ihre früheren
Antworten möglich machen, und erzeugt die Bereichsdatei, die die App
importiert. Jede Frage dort existiert als Parameter in der App, und jeder
Parameter der App kommt dort vor — diese Symmetrie ist eine Regel, kein
Zufall.

<!-- image: config-setup-questionnaire -->

<!-- anchor: config.identity.legal -->
## Identität und Pflichtangaben

*Bereichseinstellungen → Rechtliche Identität und E-Rechnung.* Füllen Sie
das aus, bevor das erste Dokument das Haus verlässt: eine Rechnung, die
ihren Aussteller nicht ordentlich benennt, ist keine Rechnung.

Die **Organisationsform** — Unternehmen oder Verein — entscheidet,
welche Klauseln standardmäßig gedruckt werden. Verzugszinsen,
Beitreibungspauschale und Skonto sind Pflichten *zwischen Unternehmern*;
die Dokumente eines Vereins lassen diese Vorgaben deshalb weg und drucken
trotzdem alles, was Sie selbst eintragen.

Danach der Reihe nach: **Rechtsform und Kapital**, unter dem Namen
gedruckt; das **Register**, in dem eine Leserin Sie prüfen kann
(Handelsregister und Ort für ein Unternehmen, Vereinsregister für einen
Verein); das **Umsatzsteuerregime**, das entscheidet, ob die Norm von
Ihnen eine Umsatzsteuer-ID oder eine Registernummer erwartet; die
**strukturierte Anschrift**, die eine E-Rechnung trägt, weil eine
Maschine eine einzeilige Adresse nicht zuverlässig zerlegen kann; und die
acht Rechnungsangaben.

Jedes dieser Felder ist Feld für Feld im
[Benutzerhandbuch](Benutzerhandbuch) unter § 11a dokumentiert — das
Hilfesymbol daneben öffnet genau seinen Absatz.

**Zahlungshinweise** (der Bankblock, den ein Dokument druckt) sind eine
eigene Einheit und wandern deshalb für sich allein zwischen einem
Entwicklungs- und einem Produktivbereich.

<!-- anchor: config.vat.overview -->
## MwSt.

Welchen Satz eine Leistung trägt, entscheiden drei Dinge, nie eines
allein: was sie ist (**die Gruppe**), wer sie kauft (**die Behandlung**)
und wann sie stattfand (**der Steuerentstehungszeitpunkt**). Das ist die
ERP-Form, und sie ist der Grund, warum eine Satzänderung nie ein altes
Dokument umschreibt.

**Sätze** tragen einen Namen, einen Prozentwert und eine steuerliche
Gruppe, und einer ist der Standard. Ein Satz ist **nach Datum
versioniert**: von 19 % auf 20 % zu wechseln fügt eine ab einem Datum
gültige Version hinzu, es ändert die alte nicht. Jedes bereits
ausgestellte Dokument behält die Version, die bei seiner Ausstellung galt,
auf dem Dokument selbst eingefroren; nur Leistungen ab dem Startdatum der
neuen Version verwenden sie.

**Gruppen** sind, was eine Leistung *ist* — Regelsatz, ermäßigt,
Nullsatz, steuerfrei, nicht steuerbar. Eine Dienstleistung, ein Tarif,
ein Zubehör und ein Paket tragen eine Gruppe, keinen Prozentwert: Die
Satztabelle eines Landes kann sich also unter ihnen ändern, ohne den
Katalog anzufassen.

**Behandlungen** sind, was die Gegenseite daraus macht: Inland,
innergemeinschaftlich an Unternehmen (Steuerschuldnerschaft des
Empfängers, die Kundin versteuert selbst nach Art. 196),
innergemeinschaftlich an Verbraucher, Ausfuhr. Land und
Umsatzsteuer-ID der Kundin entscheiden, was gilt, und die
E-Rechnungsprüfung verweigert den Versand eines Dokuments mit
Steuerschuldnerschaft des Empfängers, solange diese Umsatzsteuer-ID
fehlt — sie ist der Nachweis, dass die Steuer die ihre ist.

**Wann die MwSt. fällig wird**, ist eine Einstellung des Bereichs:
*nach vereinbarten Entgelten* (fällig bei Ausstellung) oder *nach
vereinnahmten Entgelten* (fällig an dem Tag, an dem die Kundin zahlt).
Deutschland nennt Letzteres *Ist-Versteuerung*, Frankreich stellt
Dienstleistungen ohne Gegenoption darauf, Italien nennt es *IVA per
cassa*. Nach vereinnahmten Entgelten deckt ein Meldezeitraum die darin
eingegangenen Zahlungen ab, eine Teilzahlung trägt anteilig einen Teil
jedes Satzes des Dokuments, und die Rundung geht an den breitesten Satz,
damit die Summe exakt dem entspricht, was eingegangen ist.

**Meldungen** werden für einen Zeitraum aus den darin enthaltenen
Dokumenten (oder Zahlungen) gebildet, auf die Felder des Formulars Ihres
Landes übertragen — UStVA in Deutschland, CA3 in Frankreich — und als PDF
und XML erzeugt. Eine Meldung geht von Entwurf auf eingereicht, und eine
eingereichte wird nie neu berechnet.

Der vollständige Satzkatalog eines Landes wird mit der App ausgeliefert
(EU27, CH, NO, CA); ihn aktuell zu halten, wenn eine Regierung einen Satz
ändert, liegt bei Ihnen.

<!-- anchor: config.tariffs.overview -->
## Tarife und Abrechnungsregeln

Ein **Tarif** ist ein Abonnementanteil mit einem Monatsbetrag: 25 %,
50 %, 100 % der Arbeitshalbtage eines Monats, jeder mit eigenem Preis und
eigener Umsatzsteuergruppe. Ein Mitglied hält einen Tarif; der Anteil
wird zu einem Kontingent an Halbtagen, und der Betrag ist das, was der
Monat kostet, ob das Kontingent genutzt wird oder nicht.

**Der Halbtag** ist die Einheit, in der alles zählt. Was einer ist,
entscheiden die Öffnungszeiten und die Granularität: ein Vormittag, ein
Nachmittag oder ein Raster, das Sie festlegen.

**Mehrverbrauch** ist, was jenseits des Kontingents geschieht. Entweder
werden die zusätzlichen Halbtage abgelehnt, oder sie werden zum
Mehrpreis je Halbtag berechnet — ein eigener Preis mit eigener
Umsatzsteuergruppe. Zusätzliche Halbtage können auch je Mitglied
beantragt und gewährt werden.

**Wann ein Monat abgerechnet wird**, ist eine Regel, keine Gewohnheit:
Die Abonnementzeile wird *vor* dem Monat ausgestellt, den sie abdeckt,
und die Nutzungszeilen folgen ihr. Jede Abonnementzeile benennt ihren
Monat — *September 100 %* —, damit eine Rechnung immer an den Zeitraum
gebunden ist, den sie bezahlt.

**Die Arithmetik eines Monats ist auf dem Dokument eingefroren.** Den
Preis eines Tarifs zu ändern ändert, was der nächste Monat kostet; es
ändert nie eine bereits ausgestellte Rechnung, und es öffnet nie einen
bereits abgeschlossenen Monat erneut.

<!-- anchor: config.services -->
## Dienstleistungen

Alles Verkaufte, das kein Platz ist: eine Stunde Besprechungsraum, ein
Druckkontingent, ein Schließfach, ein Kaffee-Abo. Eine Dienstleistung hat
einen Namen, einen Preis, eine Umsatzsteuergruppe und eine Einheit, und
eine Administratorin kann sie auf eine Rechnung setzen oder an ein Paket
hängen.

Dienstleistungen wandern als eigene Einheit zwischen einem Entwicklungs-
und einem Produktivbereich — und weil sie eine Umsatzsteuergruppe statt
eines Prozentwerts tragen, reisen die Sätze mit ihnen.

<!-- anchor: config.packages -->
## Tagespakete

Ein Tag, als ein Ganzes verkauft: ein Platz, ein Schließfach und zwei
Stunden Besprechungsraum zu einem Preis. Ein Paket bündelt
Dienstleistungen und ein Platzkontingent, trägt seine eigene
Umsatzsteuergruppe und erscheint auf der Rechnung als eine Zeile, deren
Bestandteile darunter aufgeführt werden, wenn das Layout es verlangt.

Nehmen Sie ein Paket, wo ein Mitglied den Tag nicht selbst
zusammenstellen sollte, und einen Tarif, wo der Monat die Einheit ist.

<!-- anchor: config.accessories -->
## Zubehör

Ausstattung, die an einem Platz hängt, statt für sich verkauft zu werden:
ein zweiter Bildschirm, eine Dockingstation, ein Stehpultaufsatz, ein
Whiteboard. Ein Zubehör hat einen Namen, einen optionalen Preis mit
Umsatzsteuergruppe, und es wird auf dem Plan gegen einen Platz, einen
Tisch oder einen Raum gesetzt.

Auf dem Plan gehört Zubehör zu dem, was eine Buchung bekommt. Trägt es
einen Preis, fügt das Buchen des Platzes eine eigene Rechnungszeile zum
eigenen Satz hinzu — deshalb wandern der Zubehörkatalog und die
Umsatzsteuersätze gemeinsam.

<!-- anchor: config.sites -->
## Standorte

Mehrere Anschriften unter einer Organisation: welche ein Dokument
benennt, welche Registrierung es trägt und wie ein Mitglied einer davon
zugeordnet ist.

<!-- anchor: config.availability -->
## Verfügbarkeit und Buchungsregeln

*Bereichseinstellungen → Verfügbarkeit.* Jede Regel hier wird vom Server
durchgesetzt, nicht vom Bildschirm: Eine Regel, die Sie setzen, hält also
auch gegen eine veraltete App.

**Öffnungstage und -zeiten** bestimmen den Arbeitstag und, zusammen mit
der Granularität, was ein Halbtag ist. **Schließtage** sind Daten, an
denen der Bereich zu ist: Eine Buchung, die einen berührt, wird mit genau
diesem Grund abgelehnt.

**Feiertage** lassen sich jahrweise erzeugen, statt Datum für Datum
hinzugefügt zu werden (#1274). Wählen Sie das Jahr, lesen Sie die Liste,
die der Server vorschlägt, und bestätigen Sie — das Erzeugen ist nie
automatisch und nie stillschweigend. Ein Jahr erneut zu erzeugen fügt
nichts hinzu; es zu wiederholen ist also gefahrlos.

Ein Monat, der bereits eine Rechnung trägt, wird **übersprungen und am
Bildschirm benannt**. Ein Schließtag dort würde ändern, wie viele
Halbtage dieser Monat enthielt, und damit eine bereits ausgestellte
Rechnung; die Regel wird in der Datenbank durchgesetzt, nicht im
Bildschirm (ADR 0025). Einen abgerechneten Monat zu korrigieren bleibt
eine bewusste Handlung: Fügen Sie den Tag von Hand hinzu und kümmern Sie
sich um die Rechnung.

Die Daten kommen vom Server, dieselbe Liste speist also auch eine
Vorlage, die einen ganzen Bereich konfiguriert. Schalten Sie *Feiertage*
ein, um die Aktion zu sehen; sie ist aus, bis Sie danach fragen.

**Granularität** ist, was eine Buchung sein darf — ein halber Tag, ein
ganzer Tag oder ein Raster von N Minuten. Eine Buchung, die nicht auf dem
Raster liegt, wird abgelehnt, und die Schrittweite wird genannt.

**Der Horizont** ist, wie weit im Voraus Buchungen öffnen. **Mindest- und
Höchstdauer** begrenzen eine einzelne Buchung. **Gleichzeitige
Reservierungen** begrenzen, wie viele ein Mitglied zugleich offen halten
darf — je Bereich und je Mitglied überschreibbar. Eine Buchung endet
immer an dem Tag, an dem sie beginnt.

**Vergangene Buchungen** werden abgelehnt, sofern Sie sie nicht erlauben;
eine rückwirkende Buchung am selben Tag ist zulässig, denn wer sich um
neun hingesetzt hat, soll das um zehn sagen dürfen.

**Außerhalb der Öffnungszeiten** kennt drei Modi: *aus* (abgelehnt), *nur
spontan* (ein spontanes Einchecken ist möglich, im Voraus buchen nicht)
oder *berechnet* (erlaubt und gezählt). Jeder hat seinen eigenen
Ablehnungssatz, damit ein Mitglied erfährt, welche Tür zu ist.

**Freigaberegeln** entscheiden, welche Vorgänge eine menschliche
Entscheidung brauchen — siehe unten.

<!-- anchor: config.plan.overview -->
## Der Raumplan

Der Plan ist das, worauf Mitglieder buchen. Er entsteht aus drei
ineinanderliegenden Formen über einem Hintergrundbild, auf einem Raster,
dessen Zelle die Einheit der Platzierung ist. Bauen Sie ihn in dieser
Reihenfolge: zuerst die Ebene und ihr Hintergrund, dann die Räume, dann
die Tische und Plätze. Alles Folgende wird über das Bild gezeichnet, nie
aus dem Gedächtnis.

<!-- anchor: config.plan.levels -->
### Ebenen

Eine Ebene ist ein Stockwerk oder eine Gruppe von Räumen, die als eines
behandelt wird. Sie trägt ihren **Standort** (zu welcher Anschrift sie
gehört), ihr **Hintergrundbild** und, wenn sie als Ganzes buchbar ist,
ihren **Preis je Halbtag** samt Umsatzsteuergruppe.

*Als Ganzes buchbar* ist ein Schalter an der Ebene selbst. Ohne ihn wird
die Anfrage, die ganze Ebene zu reservieren, abgelehnt und nennt den
fehlenden Schalter — die Ablehnung benennt die Einstellung, statt dem
Mitglied die Schuld zu geben.

<!-- anchor: config.plan.offices -->
### Räume, Tische und Plätze

**Ein Raum** ist ein Zimmer innerhalb einer Ebene. **Ein Tisch** steht in
einem Raum oder frei auf der Ebene. **Ein Platz** ist ein Arbeitsplatz an
einem Tisch — das, was ein Mitglied tatsächlich bucht. Jedes hat seine
Grundfläche auf dem Raster; ein Platz belegt sechs Zellen in der Breite
und vier in der Tiefe, und das setzt den Maßstab für alles andere.

Ein Platz trägt seine **Ausrichtung** (wohin der Stuhl schaut, damit der
Plan sich liest wie der Raum), seine **Ausstattung und sein Zubehör** und
seine **Marken** — ein Badge oder ein NFC-Tag macht den Platz an der Tür
scanbar.

**Als Ganzes buchbar** gibt es auch am Tisch und am Raum: einschalten,
und der Tisch oder das Zimmer lässt sich in einer Buchung reservieren
statt Platz für Platz. Eine Ganzbuchung sperrt ihre Kinder für den
Zeitraum, und eine Kindbuchung sperrt das Ganze.

**Sperren** nimmt einen Platz für Wartung außer Betrieb, ohne ihn zu
löschen: Er bleibt auf dem Plan, ausgegraut, und jeder Buchungsversuch
wird mit diesem Grund abgelehnt. Sperren wandern nie von einem
Entwicklungs- in einen Produktivbereich, denn eine Wartungssperre ist
eine Tatsache über ein Gebäude an einem Tag.

<!-- anchor: config.plan.background -->
### Das Hintergrundbild

Ein Plan liest sich am besten über einer Zeichnung des tatsächlichen
Raums. Das Bild gehört zur Ebene, liegt unter dem Raster und bewegt sich
nicht mehr, sobald die Plätze darüber gezeichnet sind.

<!-- image: config-plan-background -->

<!-- anchor: config.plan.ai-image -->
### Dieses Bild aus Fotografien erzeugen, mit einer KI

Sie brauchen keine Architektenzeichnung. Fotografieren Sie den Raum,
bitten Sie ein Bildmodell um einen Grundriss von oben und nehmen Sie
dessen Antwort als Hintergrund.

**Fotografieren Sie gut.** Stellen Sie sich in jede Ecke, halten Sie die
Kamera auf Brusthöhe und machen Sie ein Bild je Ecke plus eines entlang
jeder langen Wand. Auf mindestens zwei davon soll der ganze Boden zu
sehen sein. Messen Sie eine Sache — die Länge eines Tisches, die Breite
einer Tür — und notieren Sie die Zahl: Sie setzt später den Maßstab.

**Bitten Sie um einen Plan, nicht um ein Bild.** Die Eingabe, die
funktioniert, verlangt eine orthografische Draufsicht, flache Farben,
keine Perspektive, keine Schatten, keine Personen und Möbel als einfache
Grundflächen:

> Zeichne aus diesen Fotografien eines Raums einen orthografischen
> Grundriss von oben. Gerade Wände, exakte rechte Winkel, keine
> Perspektive und keine Schatten. Zeige nur das Feste: Wände, Türen mit
> ihrem Anschlag, Fenster, Heizkörper, Stützen, Küchen- und
> Sanitärblöcke sowie die Grundfläche jedes großen Möbels als schlichte
> umrissene Form. Gedämpfte, helle Farben auf weißem Grund; kein Text,
> keine Beschriftungen, keine Maße, keine Personen, keine Dekoration.
> Der [Tisch] im Raum ist [1,60] m lang — zeichne alles in diesem
> Maßstab. Gib ein einziges Bild aus, im Format [4:3], mindestens 1600
> Pixel breit.

**Prüfen Sie den Maßstab, bevor Sie zeichnen.** Importieren Sie das Bild
als Hintergrund der Ebene und messen Sie dann das notierte Objekt gegen
das Raster: Ein Platz belegt sechs Zellen in der Breite und vier in der
Tiefe, und eine Zelle ist die Einheit der Platzierung. Skalieren Sie das
Bild, bis das reale Objekt seiner wahren Größe auf dem Raster entspricht;
alles danach Gezeichnete ist dann ehrlich.

**Zeichnen Sie nach, erfinden Sie nicht.** Setzen Sie Räume, Tische und
Plätze über das Bild. Der Hintergrund führt das Auge; gebucht werden die
Plätze, die Sie setzen.

**Was Sie nicht annehmen sollten.** Eine perspektivische Ansicht, ein
Rendering mit Schatten, einen Plan mit erfundenen Räumen oder einen, bei
dem die Möbel nicht zu den Fotos passen. Fragen Sie mit einer strengeren
Eingabe erneut, statt einen falschen Plan von Hand zu korrigieren.

<!-- anchor: config.plan.images -->
### Planbilder

Bilder, die *auf* dem Plan liegen statt darunter — ein Logo am Eingang,
ein Schild, das Foto einer Ecke —, jedes mit eigener Position und Größe
auf dem Raster. Sie sind Dekoration: Auf ihnen wird nichts gebucht, und
sie liegen über dem Hintergrund und unter den Plätzen.

Sie wandern mit dem Plan, wenn er deployt wird, und die Bereichsdatei
nimmt sie beim Export mit.

<!-- anchor: config.documents -->
## Dokumentenbibliothek

Dateien, die der Bereich aufbewahrt und den dazu Berechtigten zeigt: die
Hausordnung, eine Versicherungsbescheinigung, ein Fluchtwegplan, eine
Mustervereinbarung für Mitglieder. Jedes Dokument trägt die Rollen, die
es lesen dürfen; die Bibliothek ist also ein Ort mit Sichtbarkeit je
Rolle statt mehrerer Ordner.

Dokument*layouts* — die Gestaltung einer Rechnung oder eines Briefs —
sind etwas anderes und stehen im
[technischen Handbuch](Admin-Technical-Guide.de).

<!-- anchor: config.roles -->
## Rollen und Berechtigungen

*Einstellungen → Rollen.* Eine Matrix: die Rollen auf der einen Seite,
die Berechtigungen auf der anderen. Inhaberin, Mitinhaberin,
Administratorin, Mitglied — und jede Berechtigung ist eine Zelle, die Sie
ein- oder ausschalten können, außer denen, die eine Inhaberin immer hat.

Eine Berechtigung wird beim Server durch eine einzige Funktion
abgefragt: Eine Berechtigung, die Sie entziehen, ist also überall
zugleich entzogen. Der Bildschirm blendet die Schaltfläche aus, und der
Aufruf dahinter verweigert ohnehin.

Die Umgebungsberechtigungen leben ebenfalls hier — *Den Produktivbereich
betreten*, *Nach Entwicklung deployen*, *Nach Produktion deployen* — und
werden im [Umgebungshandbuch](Environments-Guide.de) erklärt.

<!-- anchor: config.validation -->
## Freigaberegeln

Welche Vorgänge eine menschliche Entscheidung brauchen, bevor sie
wirksam werden, und wer entscheidet. Jeder Bereich hat seine Regel: ein
beitretendes Mitglied, eine gelöschte Reservierung, eine ausgebuchte
Rechnung, gewährte Zusatzhalbtage und die übrigen.

Je Bereich wählen Sie, ob überhaupt eine Anfrage entsteht und ob die
eigene Anfrage einer Administratorin oder einer Inhaberin **automatisch
freigegeben** wird — dann wird das Ereignis bereits erledigt
aufgezeichnet, statt eine Freigeberin zu bitten, die eigene Handlung zu
genehmigen.

Eine Entscheidung ist immer ein Ereignis: wer entschieden hat, wann und
worüber. Nichts wird stillschweigend freigegeben, und eine vom System
getroffene Entscheidung sagt das.

<!-- anchor: config.features -->
## Funktionen

Jede Funktionalität ist ein Schalter. Was ein Schalter abschaltet, was er
nie abschaltet (die bereits angewandte Arithmetik) und der
Abhängigkeitsgraph, der entscheidet, welche Schalter überhaupt verfügbar
sind.
