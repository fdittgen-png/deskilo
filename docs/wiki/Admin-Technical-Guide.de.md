# Administratorhandbuch — die technische Seite

Für die Person, die einen DesKilo-Bereich am Laufen hält: die Dokumente,
die er druckt, die Dateien, die er austauscht, die Dienste, mit denen er
spricht, und die Datenbank darunter. Die alltägliche Konfiguration steht
im [Konfigurationshandbuch](Admin-Configuration-Guide.de); was ein
Mitglied sieht, steht im [Benutzerhandbuch](Benutzerhandbuch).

*Ein mit `<!-- image: … -->` markierter Platz ist ein Bildschirmfoto, das
die Kette noch nicht bekommen hat.*

<!-- anchor: admin.reports.overview -->
## Dokumente und Berichte

Alles, was DesKilo druckt — eine Rechnung, eine Mahnung, ein
Mitgliederbrief, ein Verbrauchsbericht, eine Umsatzsteuererklärung, ein
Badge-Bogen — kommt aus einem einzigen Motor. Eine **Dokumentart** nennt
das Dokument; ein **Entwurf** sagt, wie es aussieht; die **Daten**, die
die App ihm übergibt, sind ein festes Vokabular von Platzhaltern.

<p><img src="images/admin-reports-editor.jpg" width="240"></p>

*Der Berichts-Editor: die Sprach- und Dokumentauswahl oben, die Schalter Markup / Visuell und Entwurf / Vorschau darunter, und die Bänder der Rechnung — Kopf, Rumpf, Fuß — weiter unten.*

<!-- anchor: admin.reports.kinds -->
### Die Arten und die vier Vorlagen

Jede Art (Rechnung, Gutschrift, Proforma, Auszug, Vereinbarung,
Zahlungen, Verbrauch, MwSt., Bereich) geht von einer der vier Vorlagen
aus — *Einfach*, *Klassisch*, *Ausführlich*, *Formeller Brief* — die
sich nur darin unterscheiden, wie viel sie sagen, nie darin, was
rechtlich verlangt ist.

<!-- anchor: admin.reports.bands -->
### Die Bänder: Kopf, Fortsetzung, Rumpf, Fuß

Der schnelle Weg zu entwerfen. Vier Bänder aus Markup, jedes mit seiner
Aufgabe:

| Band | Wo es druckt |
|---|---|
| **Kopf** | oben auf Seite 1 allein — der Briefkopf |
| **Fortsetzung** | oben auf Seite 2 und danach — ein Streifen, der das Dokument nennt |
| **Rumpf** | die einzige fließende Zone: sie läuft weiter und paginiert |
| **Fuß** | unten auf *jeder* Seite |

Innerhalb eines Bandes entscheidet ein Zeichen je Zeile, was die Zeile
ist:

| Zeichen | Was die Zeile wird |
|---|---|
| `# ` | eine Überschrift |
| `## ` | eine Unterüberschrift |
| `- ` | eine kleine Zeile |
| `\| a \| b \|` | eine Tabellenzeile; eine Zeile aus `---` macht die darüber zur Kopfzeile |
| `---` | eine waagerechte Linie |
| `![name\|b\|align]` | ein Bild aus der Bibliothek, mit Größe und Ausrichtung |
| (leer) | ein Abstand |
| alles andere | Fließtext |

Das Panel *Platzhalter und Markup* des Entwerfers trägt all das inline,
dazu **Feld einfügen…** — die durchsuchbare, nach Thema gruppierte
Auswahl, mit einer Zeile Bedeutung unter jedem Namen, auch nach dieser
Bedeutung durchsuchbar — und drei fertige Stücke: eine Zeile, die nur
druckt, wenn ihr Wert existiert, eine Zeile je Rechnungsposition, und der
Titel, der Rechnung, Gutschrift oder Proforma sagt. Was Sie antippen,
landet an der Einfügemarke des zuletzt bearbeiteten Bandes.

<!-- anchor: admin.reports.layouts -->
### Positionierte Layouts

Der exakte Weg. Ein XML-Layout setzt jedes Element auf den Millimeter,
für ein Dokument, das ein Fensterkuvert oder ein amtliches Formular
erfüllen muss. **Ein Layout schlägt die Bänder** für die Art, auf die es
gesetzt ist.

Die Wurzel und ihre Zonen:

```xml
<report-layout version="1" page="A4" margin="20mm"
               margin-top="8mm" margin-bottom="8mm">
  <header height="…">…</header>
  <continuation height="…">…</continuation>
  <recipient window="fr|din|off"/>
  <body y="90mm">…</body>
  <footer height="…">…</footer>
</report-layout>
```

`margin` ist der Seitenrand; `margin-top` und `margin-bottom` teilen den
senkrechten Rand, wenn ein Dokument sie getrennt braucht, und sind der
Seitenrand, wenn sie fehlen. `<recipient>` nimmt ein benanntes Fenster —
**fr** bei 110 mm, **din** bei 20 mm, beide 45 mm von oben in einem
Kasten von 85 × 40 mm — oder ausdrückliche `x y w h`, oder `off`.
`<body y="…">` ist die einzige fließende Zone: `y` ist, wo sie wieder
aufnimmt, 90 mm unter einem Fenster.

**Elemente**, gültig in einer Zone, einer `<box>` oder einer `<column>`:

| Element | Was es tut |
|---|---|
| `<text style="heading\|subheading\|body\|small" align="left\|center\|right" bold="true">` | ein Textlauf |
| `<image name="bibliotheksname" fit="contain\|cover\|fill" align="…"/>` | ein Bild aus der Bildbibliothek |
| `<table><col w="55%" align="right"/>…<row bold="true"><cell align="…">…</cell></row></table>` | eine Tabelle mit deklarierten Spalten |
| `<box>…</box>` | eine Gruppe, damit Kinder sich darin positionieren |
| `<columns><column>…</column>…</columns>` | Gruppen nebeneinander |
| `<rule/>` | eine waagerechte Linie |
| `<spacer size="4mm"/>` | senkrechter Abstand |
| `<markup>…</markup>` | Band-Markup, wörtlich, in einem positionierten Layout |

**Rahmenattribute** — `x y w h` — gelten für jedes Element. Mit `x` oder
`y` wird das Element absolut in seinem Elternteil gesetzt; ohne beides
fließt es hinter seinen Geschwistern.

**Einheiten** sind `mm cm px pt %`. Eine nackte Zahl ist Millimeter; `px`
ist das CSS-Pixel (1/96 Zoll); `%` bezieht sich auf das Elternteil —
Breite bei `x` und `w`, Höhe bei `y` und `h`.

<!-- anchor: admin.reports.placeholders -->
### Das Vokabular

Jeder Platzhalter, den der Motor kennt, je Dokumentfamilie, mit den
Schleifen (`lines`, `vat`, `usage_records`, …) und den Feldern, die jede
Zeile trägt. `dart run tool/report.dart describe` druckt die aktuelle
Liste — sie wird aus derselben Registrierung erzeugt, die der Renderer
liest, und kann deshalb nie veraltet sein.

<!-- anchor: admin.reports.operators -->
### Liquid: Bedingungen, Schleifen, Filter

Liquid läuft **zuerst** über die ganze Datei, bevor das XML geparst
wird: eine Bedingung darf also in einem Element öffnen und in einem
anderen schließen. Werte werden beim Eintritt XML-escaped.

| Form | Was sie tut |
|---|---|
| `{{ feld }}` | druckt den Wert, escaped |
| `{% if feld != "" %}…{% endif %}` | druckt den Block nur, wenn das Feld einen Wert hat |
| `{% if a == b %}…{% else %}…{% endif %}` | die zweizweigige Form |
| `{% unless feld == "" %}…{% endunless %}` | die verneinte Form |
| `{% for line in lines %}…{% endfor %}` | ein Durchlauf je Zeile einer Schleife |
| `{{ forloop.index }}` | die ab 1 zählende Zeilennummer in einer Schleife |

**Die Regel, die alle erwischt:** jeder Platzhalter, den der Motor kennt,
ist **leer** vorbelegt, nie nil. Ein fehlendes Feld ist `""`, also
verhält sich `{% if x != "" %}` und ein Entwurf druckt nie das Wort
`nil`. Eigene Texte (`text.<schlüssel>`) werden über ihre eigene
Vorgabetabelle genauso vorbelegt.

**Schleifen und ihre Zeilen.** `lines` gibt `label, kind, pct, month,
qty, unit_price, net, vat_rate, amount, negative`. `month` ist der Monat
der Abonnementposition, bereits in die Sprache des Dokuments übersetzt —
der Grund, warum eine Rechnungszeile *September 100 %* lauten kann.
`vat` gibt die Aufschlüsselung je Satz, `usage_records` die halben Tage,
`vat_positions` und `vat_rate_totals` die eigenen Zeilen der Erklärung.

<!-- anchor: admin.reports.window -->
### Der Vertrag des Fensterkuverts

Ein Brief, der in ein Fensterkuvert geht, hat eine Geometrie, und sie ist
keine Geschmacksfrage:

| Sache | Wo |
|---|---|
| Absenderzeile | 20 mm von links, 20 mm von oben |
| Empfängerblock | 110 mm von links, 45 mm von oben, in 85 × 40 mm |
| Rumpf | nimmt bei 90 mm wieder auf |
| Fuß | auf jeder Seite |
| Fortsetzungsstreifen | ab Seite zwei |

Nichts außer dem Empfänger darf Farbe in das Fensterband setzen. Das wird
**am gerenderten PDF bewiesen**, nicht nach Augenmaß: die Prüfung misst
die Farbpositionen der erzeugten Datei und endet mit einem Fehler, wenn
etwas dort landet, wo das Fenster ist.

<!-- anchor: admin.reports.cli -->
### Die Kommandozeile

```
dart run tool/report.dart check <layout.xml> [--data data.json]
dart run tool/report.dart render <layout.xml> [--data data.json] -o out.pdf
dart run tool/report.dart sample --kind invoice > data.json
dart run tool/report.dart describe
```

- **check** rendert den Entwurf und misst ihn gegen den Fenstervertrag.
  Ende 0: konform; Ende 1: Farbe im Fensterband, und es sagt welches
  Element; Ende 2: der Entwurf konnte nicht gelesen werden, und es nennt
  das Element, das brach.
- **render** erzeugt das PDF, damit ein Entwurf ohne die App geprüft
  werden kann.
- **sample** schreibt eine Datendatei mit jedem Platzhalter, den der
  Motor kennt — der schnellste Weg zu sehen, wie ein Feld heißt.
- **describe** druckt das Vokabular von oben — Zonen, Elemente,
  Rahmenattribute, Einheiten, Liquid und die Platzhalterliste. Es wird
  aus derselben Registrierung erzeugt, die der Renderer liest, und kann
  deshalb nicht vom Motor abweichen.

Die CLI ist reines Dart und muss es bleiben: sie importiert nichts aus
Flutter oder den Lokalisierungen, und ein Test bricht in dem Moment, in
dem eine Domänendatei, die sie nutzt, `AppLocalizations` hereinzieht.

<!-- anchor: admin.einvoice.overview -->
## Elektronische Rechnungsstellung

Eine Rechnung verlässt DesKilo als PDF, das ein Mensch liest, und als
strukturierte Datei, die eine Maschine liest, und beide sagen dasselbe,
weil sie aus demselben eingefrorenen Dokument erzeugt werden.

<!-- anchor: admin.einvoice.formats -->
### CII, UBL, Factur-X

Alle drei sind dieselbe Rechnung, auf drei Arten ausgedrückt, und alle
drei erfüllen **EN 16931**, das europäische semantische Modell, das
sagt, welche Fakten eine Rechnung tragen muss (BT-1 die Nummer, BT-48
die USt-IdNr. des Käufers und so weiter).

| Format | Was es ist |
|---|---|
| **CII** | UN/CEFACT Cross Industry Invoice — die XML-Syntax, die Chorus Pro nimmt |
| **UBL** | OASIS Universal Business Language — die Syntax, die Peppol nimmt |
| **Factur-X** | ein PDF/A-3 mit dem CII-XML *darin eingebettet* — eine Datei, die ein Mensch liest und eine Maschine parst |

Factur-X ist der Grund, warum PDF und XML sich nicht widersprechen
können: es ist dieselbe Datei. Wenn eine Plattform sie getrennt will,
werden beide aus dem einen eingefrorenen Dokument erzeugt, nie aus
lebenden Daten neu gerendert.

<!-- anchor: admin.einvoice.readiness -->
### Die Bereitschaftsprüfung

Vor jeder Übermittlung prüft die App das Dokument gegen die Norm und
**verweigert unter Nennung des Fehlenden**, weil eine von einer
Plattform abgewiesene Rechnung teurer zu reparieren ist als eine nie
gesendete.

Was sie verweigert:

- einen Verkäufer ohne die Kennung, die das Regime verlangt — eine
  USt-IdNr., wenn Sie Umsatzsteuer berechnen, eine Registernummer, wenn
  nicht;
- ein Dokument mit **Steuerschuldnerschaft des Empfängers**, dessen Kunde
  keine USt-IdNr. hat: diese Nummer ist der Beweis, dass die Steuer seine
  ist;
- eine Befreiung ohne Grund und ohne Landesvorgabe, auf die man
  zurückfallen könnte;
- eine Kunden-USt-IdNr., deren **Form nicht zu ihrem Land passt** — eine
  Warnung, keine Verweigerung, da Formen sich ändern;
- einen Käufer ohne Adresse, sobald das Ziel eine verlangt.

Mitglieder geben ihr Land selbst an und, wenn sie als Unternehmen
fakturieren, ihre USt-IdNr., neben ihrer Adresse unter
*Einstellungen → Persönliche Angaben*.

<!-- anchor: admin.einvoice.platforms -->
### Plattformen und Zugangsdaten

Ein Dokument kann an **zwei Ziele zugleich** gehen: die staatliche
Plattform, die Ihr Land vorschreibt, und den eigenen Dienst des Kunden.
Beide werden am Bereich konfiguriert, und beide dürfen aus sein.

Zugangsdaten leben am Bereich, nie in der Bereichsdatei und nie in einem
Deployment — ein Export, den Sie einem Kollegen schicken, trägt die
Konfiguration und nicht die Schlüssel. Ein **Entwicklungsbereich nutzt
immer den Testendpunkt**, der eine staatliche Plattform physisch nicht
erreichen kann: eine Testrechnung kann also nie eine echte werden.

Jeder Versuch wird in der Übermittlungshistorie der Rechnung selbst
festgehalten: wann, an welches Ziel, was die Plattform geantwortet hat
und welche Referenz sie zurückgab. Eine gescheiterte Übermittlung lässt
die Rechnung unberührt und wiederholbar — das Dokument ist eingefroren,
die Übermittlung gehört nicht dazu.

<!-- anchor: admin.exports.accounting -->
## Buchhaltungsexporte

Drei Formate, ein Hauptbuch darunter:

| Format | Wo es verlangt wird | Was es trägt |
|---|---|---|
| **FEC** | Frankreich (Art. A47 A-1 LPF) | jede Buchung der Periode, in der vorgeschriebenen Spaltenfolge |
| **SAF-T** | der OECD-Standard, mehrere EU-Länder | die Prüfdatei: Konten, Buchungen, Belege |
| **DATEV** | Deutschland, für die Software des Steuerberaters | die Buchungen in dem Aufbau, den DATEV importiert |

Alle drei decken eine Periode Ihrer Wahl ab und nutzen den am Bereich
konfigurierten **Kontenrahmen** — das Umsatzsteuerkonto eingeschlossen,
weshalb dieses Feld zur rechtlichen Identität gehört und nicht zum
Export. Eine bereits exportierte Periode ist nicht gesperrt: ein Export
ist ein Lesen und darf nach einer Korrektur erneut genommen werden.

<!-- anchor: admin.integrations.overview -->
## Integrationen

| Integration | Was sie tut | Ohne sie |
|---|---|---|
| **Zahlungsanbieter** | nimmt eine Zahlung gegen eine Rechnung an | Zahlungen werden von Hand erfasst; sonst ändert sich nichts |
| **WhatsApp-Kanal** | sendet eine Mahnung oder einen Hinweis über WhatsApp | die Nachricht bleibt im Posteingang der App |
| **Push** | liefert Benachrichtigungen an ein Gerät | Benachrichtigungen erscheinen beim Öffnen der App |
| **E-Rechnungs-Plattform** | übermittelt die strukturierte Rechnung | das PDF wird erzeugt und anders versendet |

Für alle gelten zwei Regeln. **Zugangsdaten leben am Bereich**, in einer
Tabelle, die die Bereichsdatei und jedes Deployment auslassen: kein
Export trägt also je einen Schlüssel. Und **eine nicht konfigurierte
Integration degradiert, sie bricht nicht**: die Funktion, die sie
braucht, ist ausgeschaltet, der Bildschirm sagt es, und nichts wirft
eine Ausnahme.

<!-- anchor: admin.instances.overview -->
## Instanzen

Eine **Instanz** ist ein ganzes DesKilo auf seiner eigenen Datenbank.
Zwei Bereiche — selbst ein Paar aus Entwicklung und Produktion — teilen
sich eine; zwei Instanzen teilen nichts. Nutzen Sie eine dort, wo
personenbezogene Daten oder Zahlungszugangsdaten physisch getrennt sein
müssen, oder wo ein Kunde auf seiner eigenen Datenbank besteht.

Das **Bündel** ist das Baumaterial der Instanz: jede Migration in der
Reihenfolge, die Edge-Funktionen, die Speicher-Buckets und die Saat. Es
wird bei jeder angewandten Migration neu erzeugt, sodass Bündel und
lebende Datenbank nie auseinanderlaufen.

Erstellen Sie eine Instanz aus dem Assistenten der App oder aus
`dart run tool/instance.dart`; beide wenden das Bündel auf eine leere
Datenbank an und stempeln, bei welcher Migration sie steht. Eine spätere
Migration erreicht eine bestehende Instanz auf demselben Weg — der Reihe
nach ab dem Stempel angewandt, nie erneut ausgeführt.

Konfiguration und Stammdaten reisen zwischen Instanzen über die
**Bereichsdatei**, denn ein Deployment braucht eine Datenbank, und eine
Instanz ist genau der Punkt, an dem es zwei gibt.

<!-- anchor: admin.trace.overview -->
## Das Protokoll

*Einstellungen → Entwickler.* Ein Ringpuffer der letzten 500 Einträge,
gestützt auf eine Datei auf dem Gerät, mit jedem Framework- und
Plattformfehler ab der ersten Zeile von `main()` daran gehängt.

Drei Formen, und die mittlere ist die nützliche:

- **step** — eine Entscheidung oder ein Server-Umlauf, der wie
  beabsichtigt lief.
- **refused** — die App lehnt ab, was jemand angefasst hat.
  Warnstufe, und das Erste, wohin man scrollt, wenn die Meldung *„ich
  habe getippt und es passierte nichts“* lautet.
- **failed** — eine Ausnahme, die dieselben Felder trägt wie der Schritt,
  der es versuchte, sodass eine rote Zeile nie ohne ihren Kontext
  dasteht.

Jede Zeile ist ein Verb, gefolgt von `schlüssel=wert`-Paaren: ein
Protokoll lässt sich also greppen. `grep 'act=check-in'` liest eine Art
Versuch von Anfang bis Ende, und `grep 'server='` liest jede Ablehnung
des Servers, mit Code, Meldung, Details und Hinweis in einem Feld.

**Ein Protokoll gilt je Gerät.** Das Protokoll, das *„ein Mitglied
konnte nicht einchecken“* beantwortet, liegt auf dem Telefon dieses
Mitglieds. *Exportieren* schreibt es in eine Datei, gestempelt mit
App-Version und Bereich — das ist es, was ein exportiertes Protokoll an
die Meldung bindet, die es beantwortet. Gescannte Nutzlasten werden nach
**Form** festgehalten — Schema, Host, welche Parameter da sind, wie lang
— nie nach Wert, weil ein Einladungscode ein Geheimnis ist und ein
Protokoll dazu da ist, jemandem geschickt zu werden.

**Ein „started“ ohne passendes „done“** heißt, dass der Akt nie
zurückkam: die App wurde getötet, die Anfrage kam nie zurück, oder ein
`await` hängt. Diese Lücke ist der Befund.
