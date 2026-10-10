<!-- anchor: setup.features.overview -->
## Wählen, was Ihr Space anbietet

Ein Space ist kein einzelnes Produkt mit hundert Einstellungen. Er besteht aus einer Handvoll Dinge, die Sie einzeln zum Angebot machen. Dieses Kapitel erklärt, wie DesKilo gliedert, was es kann, was ein neuer Space schon mitbringt, wie die Teile voneinander abhängen und in welcher Reihenfolge Sie sie einschalten, damit Sie nie etwas anbieten, das Sie noch nicht betreiben können.

In diesem Kapitel:
- [Funktionen und Prozesse](help:setup.features.what)
- [Kern und Plattform: was ein neuer Space hat](help:setup.features.tiers)
- [Funktionen, die andere Funktionen brauchen](help:setup.features.dependencies)
- [Ausschalten löscht nichts](help:setup.features.off)
- [Beta, Nicht bewertet und die Frage vor dem Einschalten](help:setup.features.maturity)
- [Drei Ausgangspunkte](help:setup.features.profiles)
- [Die Reihenfolge beim Einschalten](help:setup.features.order)
- [Eine Funktion sicher einschalten](help:setup.features.safely)
- [Funktionen vermeiden, die sich widersprechen](help:setup.features.consistency)
- [Die Funktionslandkarte](help:setup.features.map)

<!-- anchor: setup.features.what -->
### Funktionen und Prozesse

**Zielgruppe:** Inhaber · Mitinhaber

Sie möchten wissen, was Sie schalten, wenn Sie **Funktionen** öffnen. Alles, was DesKilo über die Grundlagen hinaus kann, ist eine Funktion mit eigenem Schalter. Damit hundert Schalter lesbar bleiben, gruppiert der Bildschirm sie nach ihrem Zweck.

<p><img src="images/setup-features-what.de.jpg" width="280"></p>

*So ist es aufgebaut*

- Ein *Prozess* ist eine betriebliche Aufgabe, zum Beispiel **Abrechnung & Zahlungen** oder **Kalender und Koordination**. Es gibt neun.
- Ein *Teilprozess* ist ein Schritt dieser Aufgabe: **Rechnungsstellung**, **Zahlungseingang** und **USt-Verwaltung** sind drei der fünf Schritte von **Abrechnung & Zahlungen**.
- Eine *Funktion* ist ein Schalter innerhalb eines Teilprozesses: **Rechnungen**, **Mahnwesen**, **USt-Voranmeldungen**.

*Die neun Prozesse und ihre Teilprozesse*

| Prozess | Teilprozesse |
|---|---|
| **Arbeitsbereich und Zugang** | **Personen und Mitgliedschaften** · **Zutritt** |
| **Raumverwaltung** | **Raumstruktur** · **Öffnungstage und Zeiten** · **Raumdarstellung** |
| **Buchungen und Nutzung** | **Plätze und Räume buchen** · **Anwesenheit und Nutzung** |
| **Kalender und Koordination** | **Kalenderansichten** · **Entscheidungen und Freigaben** · **Mitgliederkommunikation** |
| **Mitgliedschaftsangebote** | **Leistungen und Preise** |
| **Abrechnung & Zahlungen** | **Finanzübersicht** · **Rechnungsstellung** · **Zahlungseingang** · **Gemeinsame Ausgaben** · **USt-Verwaltung** |
| **Dokumente und Informationen** | **Dokumentbereitstellung** · **Berichtsgestaltung** · **Datenzugriff und Exporte** |
| **Betrieb und Verwaltung** | **Konfiguration und Bereitstellung** · **App-Bedienung** |
| **Integrationen und Automatisierung** | **Externer Versand** |

**Gut zu wissen**

- Eine Funktion gehört genau einem Prozess an, auch wenn sie eine Funktion eines anderen braucht. Die Karte sagt es: „Alles einzuschalten braucht auch: Finanzen-Tab (Abrechnung & Zahlungen)“.
- Mitgliedschaftsmodelle und der Grundrisseditor sind keine Funktionen: Sie sind immer da. Ihre Einstellungen stehen unter Workspace und Abrechnung, nicht auf diesem Bildschirm. Vorausbezahlte Mehrfachkarten sind eine Funktion: siehe **Mehrfachkarten**.
- Eine Funktion auszuschalten blendet sie auf jedem Bildschirm aus, auf dem sie erschien; das ist keine Berechtigung. Wer was darf, entscheiden Sie unter [Rollen](help:user.roles.matrix).

**Siehe auch:** [Was DesKilo kann](help:setup.before.what) · [Ganze Prozesse ein- oder ausschalten](help:user.features.processes)

<!-- anchor: setup.features.tiers -->
### Kern und Plattform: was ein neuer Space hat

**Zielgruppe:** Inhaber · Mitinhaber

Sie möchten wissen, was Mitglieder am ersten Tag vorfinden, bevor Sie etwas geschaltet haben.

<p><img src="images/setup-features-tiers.de.jpg" width="280"></p>

Jede Funktion gehört zu einer von zwei Stufen, und ein neuer Space wird aus ihnen erstellt:

| Stufe | In den Worten der App | Was ein neuer Space bekommt |
|---|---|---|
| **Kern** | Was jeder Space braucht. Ab dem ersten Tag an. | An, wenn die Funktion von Anfang an an sein soll. |
| **Plattform** | Auf Wunsch, nie vorausgesetzt. Schalten Sie ein, was dieser Space wirklich nutzt. | Aus. Unter **Schalter** stehen sie in der Stufe **Plattform**. |

Ein neuer Space startet mit 45 eingeschalteten Funktionen, alle aus dem Kern (46, wenn Sie den Test-Zwilling gleichzeitig erstellen: Dann ist auch **Umgebungspaare** an). In einfachen Worten:

- Buchen: einen Platz auf dem Plan reservieren, eine Buchung wiederholen (**Serienbuchung**), für andere buchen (**Für andere buchen**), einen halb gebuchten Platz als teilweise belegt sehen (**Tagesverlauf eines Platzes**), eine Buchung in einem persönlichen Kalender speichern (**Kalenderdatei einer Buchung**), Buchungsregeln wie vergangene Buchungen und Zeiten außerhalb der Öffnungszeiten (**Buchungsregeln**, **Buchungsprüfung**), die Löschung einer vergangenen Buchung beantragen (**Lösch-Anträge für Buchungen**), QR-Karten für Plätze drucken (**Raum-QR-Codes**), einstellbare Arbeitszeiten (**Arbeitszeiten**).
- Personen: der Community-Tab (**Mitgliederverzeichnis**), eine Seite pro Mitglied (**Mitgliedsseite**), die zentrale Rollenmatrix (**Rollenverwaltung** und **Rollen vergeben**), persönliche Angaben für Briefe und Rechnungen (**Persönliche Angaben**), unterscheidbare Initialen bei Avataren (**Eindeutige Avatar-Initialen**).
- Kalender und Nachrichten: der Kalender in mehreren Ansichten (**Kalender-Tab**, **Kalender-Hub**, **Kalenderansichten**), der Aktivitätsfeed und Bestätigungen (**Ereignis-Tab**), private und Gruppenunterhaltungen (**Mitglieder-Benachrichtigungen**, **Nachrichten, überarbeitet**) mit Verweisen, Weiterleiten, Erwähnungen, Wischgesten und Schutz vor Bildschirmaufnahmen, die Gruppierung des Benachrichtigungsfeeds (**Gruppierung der Benachrichtigungen**) und die Schaltfläche, um den Gastgebern einer veröffentlichten Seite zu schreiben (**An die Gastgeber schreiben**).
- Geld: der Tab Finanzen mit seinen vier Ansichten (**Finanzen-Tab**, **Finanzen in vier Ansichten**), Rechnungen (**Rechnungen**), ein Leistungskatalog (**Leistungen**), ein PDF der Monatsrechnung (**PDF-Export**).
- Dokumente und Daten: die Dokumentbibliothek (**Dokumentbibliothek**), Datenexport für den Inhaber (**Datenexport (Excel)**) sowie Export und Löschung der eigenen Daten durch jedes Mitglied (**Export & Löschung**).
- Komfort: Hilfehinweise, die Karte „Erste Schritte“, Favoriten und Bewertungen für Plätze, Animationen, regionale Formate und die Wahl des Navigationsstils.
- Zustellung: **Push-Benachrichtigungen**, die Telefone erst erreichen, wenn die Betreiberin oder der Betreiber der Installation den Push-Dienst eingerichtet hat (siehe [Wie Mitglieder informiert werden](help:setup.notify.channels)).
- Plan aufräumen: **Räume mit Historie löschen** und **Einraum-Etagen nach der Etage benennen**.

Alles andere gehört zur Plattform und ist aus: Kiosk und Badges, mehrere Standorte, Zubehör-Aufpreise, Online-Zahlungen, USt-Verwaltung, der Weg einer Rechnung, Berichtsgestaltung, Ausrollungen, WhatsApp, die Assistentenschnittstelle und der Rest.

**Gut zu wissen**

- Die Funktion Rechnungen ist von Anfang an an, doch ausstellen lässt sich nichts, bevor Ihre rechtliche Identität vollständig ist; **Einrichtung dieses Workspace** markiert sie mit **Vor der Rechnungsstellung nötig**. Siehe [Funktionen vermeiden, die sich widersprechen](help:setup.features.consistency).
- Ein bestehender Space ändert sich nie, wenn DesKilo ändert, was ein neuer Space bekommt.
- Beginnen Sie mit einer Vorlage, kann die Vorlage zusätzlich zu diesem Satz einige Funktionen ein- oder ausschalten. Siehe [Drei Ausgangspunkte](help:setup.features.profiles).

**Siehe auch:** [Ein Funktionsschalter](help:user.features.switch)

<!-- anchor: setup.features.dependencies -->
### Funktionen, die andere Funktionen brauchen

**Zielgruppe:** Inhaber · Mitinhaber

Sie möchten etwas einschalten und sicher sein, dass es funktioniert, oder etwas ausschalten, ohne zu zerstören, was daran hängt.

Viele Funktionen hängen unter einer anderen. **Online-Zahlungen** braucht **Finanzen-Tab**; **Mahnwesen** braucht **Rechnungen**; **Automatische Zahlungserinnerungen** braucht **Mahnwesen**; **USt-Voranmeldungen** braucht **USt-Verwaltung**, die wiederum **Rechnungen** braucht. In der Liste **Schalter** zeigt eine Funktion, die eine andere braucht, **Benötigt** gefolgt vom Namen ihrer übergeordneten Funktion.

*Was die App tut*

| Sie | Die App |
|---|---|
| Schalten eine Funktion ein, deren übergeordnete Funktion aus ist | Schaltet die ganze Kette ein und nennt, was mit eingeschaltet wurde: „Ebenfalls eingeschaltet: …“. |
| Schalten eine übergeordnete Funktion aus | Löscht die Entscheidungen ihrer untergeordneten Funktionen nicht. Sie bleiben so gespeichert, wie Sie sie gesetzt haben, bewirken aber nichts; die Zeile sagt „Wartet auf die Funktion darüber — schalte sie ein, dann wirkt auch diese wieder“. |
| Schalten die übergeordnete Funktion wieder ein | Die untergeordneten Funktionen, die an waren, wirken sofort wieder. |
| Schalten einen ganzen Prozess oder Teilprozess aus, während ihn noch etwas braucht | Lehnt ab und nennt, wer ihn braucht („… wird noch benötigt von: …“), es sei denn, Sie wählen **Trotzdem ausschalten, Einstellungen behalten** oder schalten die abhängigen Funktionen mit aus. |

**Gut zu wissen**

- Eine untergeordnete Funktion, die an ist, aber auf ihre übergeordnete wartet, lässt ihren Prozess **Braucht Aufmerksamkeit** anzeigen. Das ist der eine Zustand, in dem ein Schalter und die App sich widersprechen; ein Blick lohnt sich. Siehe [Eine Funktion sicher einschalten](help:setup.features.safely).
- Eine übergeordnete Funktion kann in einem anderen Prozess liegen als ihre untergeordnete: **Leistungen** (Mitgliedschaftsangebote) braucht **Finanzen-Tab** (Abrechnung & Zahlungen). Die Karte warnt dann, dass alles Einschalten auch die andere braucht.
- Geprüft wird die Funktion, nicht eine Berechtigung: Eine Rolle, die etwas darf, reicht nie, wenn die Funktion aus ist.

**Siehe auch:** [Ein Funktionsschalter](help:user.features.switch) · [Ganze Prozesse ein- oder ausschalten](help:user.features.processes)

<!-- anchor: setup.features.off -->
### Ausschalten löscht nichts

**Zielgruppe:** Inhaber · Mitinhaber

Sie möchten es sich später anders überlegen können und müssen daher wissen, was ein Schalter nicht berührt.

Eine Funktion auszuschalten stoppt neue Vorgänge. Es löscht keinen einzigen Datensatz: Rechnungen, Buchungen, Nachrichten, Rollen und Einstellungen bleiben, wo sie sind, und wieder Einschalten bringt sie zurück. Was schon geschehen ist, bleibt geschehen: Eine Rechnung, die ausgestellt wurde, als die Funktion an war, behält ihren Inhalt.

Dahinter ordnet DesKilo die Aktionen einer schaltbaren Funktion in drei Arten ein:

| Art | Was der Schalter damit macht | Beispiel |
|---|---|---|
| Neue Arbeit (*acceptNew*) | Hört auf, wenn die Funktion aus ist. | Eine neue Unterhaltung mit den Gastgebern beginnen; einem Mitglied eine eigene Rolle geben; einen Platz sperren; eine neue Online-Zahlung starten. |
| Bereits offene Arbeit (*serviceExisting*) | Läuft weiter, damit nichts in der Luft hängt. | Eine schon begonnene Unterhaltung beantworten; eine eigene Rolle zurücknehmen; eine Platzsperre aufheben; eine schon offene Zahlung abschließen. |
| Unsichere Wege (*suspended*) | Bleiben zu, was auch der Schalter sagt. | Für einen Weg reserviert, den der Server als unsicher beurteilt; heute ist keine Aktion so eingestuft. |

Drei Funktionen sagen es in ihrer Zeile mit diesen Worten: „Aus: nichts Neues beginnt; was schon offen ist, kann noch beantwortet und geschlossen werden.“ Es sind **An die Gastgeber schreiben**, **Rollen dieses Bereichs** und **Admins können Plätze sperren**. **Auto-Check-in/-out am Tagesende** stoppt, wenn es aus ist, auch seinen Durchlauf am Tagesende, doch seine Zeile sagt das nicht. Auf einem Server, der das nicht bestätigen kann, steht in der Zeile: „verlassen Sie sich nicht darauf“.

**Gut zu wissen**

- Bereits zugesagtes Geld wird immer abgewickelt: Eine Zahlungsrückführung oder eine Erstattung blockiert nie ein Schalter.
- Ist **Online-Zahlungen** aus, lehnt der Server eine neue Online-Zahlung ab; eine bereits offene wird trotzdem abgeschlossen. Ihre Zeile enthält dazu keinen Hinweis.
- Ein Schalter ist kein Weg, etwas vor einer einzelnen Person zu verbergen. Dafür nutzen Sie [Rollen](help:user.roles.matrix).

**Siehe auch:** [Ein Funktionsschalter](help:user.features.switch)

<!-- anchor: setup.features.maturity -->
### Beta, Nicht bewertet und die Frage vor dem Einschalten

**Zielgruppe:** Inhaber · Mitinhaber

Sie sehen ein kleines Wort unter dem Namen einer Funktion und möchten wissen, was Sie damit anfangen sollen.

<p><img src="images/setup-features-maturity.de.jpg" width="280"></p>

Jede Zeile von **Schalter** trägt ein Reifeabzeichen, das sagt, wie weit die Funktion anhand von Belegen geprüft wurde:

| Abzeichen | Es bedeutet |
|---|---|
| **Nicht bewertet** | Noch niemand hat sie anhand von Belegen beurteilt. Das sagt nichts Schlechtes über sie. |
| **Alpha** | Beurteilt, in einem frühen Stadium. |
| **Beta** | Beurteilt, mit bekannten Grenzen; ihre Tests laufen bei jeder Änderung. |
| **Stabil** | Beurteilt und zusätzlich mit echten Anbietern, Geräten oder Betreibern erprobt. |

Zum Zeitpunkt dieses Textes stehen die meisten Funktionen auf **Nicht bewertet**, achtzehn auf **Beta**, und keine hat bisher **Stabil** erreicht.

*Was die App fragt*

1. Legen Sie den Schalter einer Funktion mit **Alpha** oder **Beta** um.
2. Die App fragt **Experimentelle Funktion einschalten?** und sagt: „Noch nicht als stabil bewertet: … Sie kann sich ändern und hat bekannte Grenzen. Nur einschalten, wenn dieser Space das akzeptiert.“
3. Sie nennt die Stufe jeder Funktion und die Funktionen, die mit eingeschaltet würden, weil sie gebraucht werden.
4. Tippen Sie zum Akzeptieren auf **Einschalten** oder auf **Abbrechen**: Dann wird nichts gespeichert.

**Gut zu wissen**

- Funktionen mit **Nicht bewertet** fragen nicht. Nur **Alpha** und **Beta** fragen.
- Die Frage kommt bei einem einzelnen Schalter. Ein **Einschalten** für einen ganzen Prozess zeigt, was es einschalten wird, stellt diese Frage aber nicht: Schalten Sie **Beta**-Funktionen einzeln ein.
- Zu den Beta-Funktionen gehören zum Zeitpunkt dieses Textes **Rechnungen**, **Online-Zahlungen**, **USt-Verwaltung**, **Mehrfachkarten**, **Gemeinsame Ausgaben**, **Nutzungssätze**, **Buchungsregeln**, **Serienbuchung**, **Buchungsprüfung**, **Lösch-Anträge für Buchungen**, **Finanzen in vier Ansichten**, **Vorräte aus Ausgaben**, **Prüfer nach Rolle oder Person**, **Verkettete Freigaben**, **Auto-Check-in/-out am Tagesende**, **Datenexport (Excel)**, **E-Rechnungszustellung an Kunden** und **Der Demobereich**. Lesen Sie die Grenzen jeder Funktion mit **Mehr**, bevor Sie sich bei Geld darauf verlassen.
- Einige davon gehören zum Kern und sind in einem neuen Space schon an. Sie starten ohne die Frage eingeschaltet; sie erscheint erst, wenn Sie eine davon wieder einschalten.
- **Reife** grenzt die Liste auf eine Stufe ein; so sehen Sie schnell alles Experimentelle, das Ihr Space schon nutzt.

**Siehe auch:** [Ein Funktionsschalter](help:user.features.switch)

<!-- anchor: setup.features.profiles -->
### Drei Ausgangspunkte

**Zielgruppe:** Inhaber · Mitinhaber

Sie möchten nicht hundert Dinge entscheiden. Hier sind drei realistische Ausgangspunkte; jeder nennt genau, was an ist. Wählen Sie den nächstliegenden und passen Sie ihn dann an.

Der erste braucht keine Vorlage. Der zweite ist die fertige Vorlage der App. Der dritte wird aus den Funktionen selbst zusammengesetzt. Sie sind nach dem benannt, was sie bieten, nicht nach einer Größe.

<!-- anchor: setup.features.profile-tiny -->
### Ein paar gemeinsame Plätze

**Zielgruppe:** Inhaber

Sie betreiben eine Handvoll Tische oder Räume, die gebucht werden, und sonst noch nichts. Erstellen Sie den Space unter **Beginnen mit** mit **Leerer Raum** oder mit der Vorlage „A tiny space“: zwei Etagen, vier Tische und acht Plätze, genug zum Buchen, Scannen und Stöbern.

Die Vorlage schaltet keine Funktionen, der Space hat also genau die 45 Kernfunktionen aus [Kern und Plattform](help:setup.features.tiers). Darüber hinaus ist nichts eingeschaltet. Lassen Sie für dieses Profil den Rest in Ruhe:

- Buchen, Kalender, Nachrichten, Verzeichnis, QR-Karten für Plätze, die Dokumentbibliothek und Hilfehinweise sind alle da.
- **Finanzen-Tab** und **Rechnungen** sind an, zeigen aber nur einen leeren Kontoauszug, bis Sie Ihre rechtliche Identität und Tarife eingeben.
- Außerhalb von Plan und Öffnungszeiten muss nichts eingerichtet werden. Siehe [Ihr Ort](help:setup.place.overview).

> **Tipp** Wenn Sie nie etwas berechnen, können Sie die Geldfunktionen ohne Schaden eingeschaltet lassen: Mitglieder sehen dann einfach nichts zu bezahlen.

<!-- anchor: setup.features.profile-association -->
### Ein Verein mit einem Raum

**Zielgruppe:** Inhaber

Sie sind ein französischer Verein, der sich einen Raum teilt, mit einem Vorstand, zahlenden Mitgliedern und Halbtagsbuchungen. Wählen Sie unter **Beginnen mit** die Vorlage „Association de coworking (France)“. Sie richtet die Öffnungsregeln, Gebührenstufen zu 50 % und 100 %, zwei Vorauszahlungsblöcke, die Rollen des Vorstands, französische Begriffe und zwei Etagen ein und bringt dieses Funktionsprofil mit:

- Die 45 Kernfunktionen, **außer** vier, die sie ausschaltet: **Ereignis-Tab**, **Mitgliederverzeichnis**, **Mitgliedsseite** und **Gruppierung der Benachrichtigungen**. Ein kleiner Verein braucht neben seinen Unterhaltungen keinen Ereignisfeed und kein Verzeichnis.
- Vier, die sie einschaltet, weil der Vorstand sie braucht: **Freigaben im Kalender** (Entscheidungen im Kalender angezeigt), **Mehrfachkarten** (vorausbezahlte halbe Tage für Personen ohne Abo, Beta), **Rollen dieses Bereichs** (Schatzmeister, Schriftführer, Raumbeauftragter) und **Wortwahl des Arbeitsbereichs** (die eigenen Begriffe des Vereins).

Das ergibt 45 − 4 + 4 = 45 eingeschaltete Funktionen. Die Vorlage bringt keine Identität mit; Adresse, Registernummer und Bankdaten geben also weiterhin Sie ein, und die Umsatzsteuerregelung beginnt als „nicht steuerbar“.

**Gut zu wissen**

- Mehrfachkarten ist Beta und wird von der Vorlage ohne die Frage eingeschaltet; das ist die Entscheidung der Vorlage, und Sie können es ausschalten.
- Die Vorlage lässt **Rechnungen** aus dem Kern an. Ein Verein, der keine Rechnungen stellt, kann es so lassen.

<!-- anchor: setup.features.profile-invoicing -->
### Ein Coworking, das Rechnungen stellt

**Zielgruppe:** Inhaber

Sie vermieten Tische an Mitglieder und schicken ihnen jeden Monat Rechnungen, in Frankreich oder Deutschland. Es gibt keine fertige Vorlage; dieses Profil ist also eine Liste dessen, was Sie zum Kern hinzufügen, in dieser Reihenfolge. Alles daran hängt an **Finanzen-Tab** und **Rechnungen**, die schon an sind.

| # | Einschalten | Warum | Braucht |
|---|---|---|---|
| 1 | **Nummernkreise** | Legen Sie fest, wie Dokumente nummeriert werden, bevor das erste existiert. | **Rechnungen** |
| 2 | **Abo-Rechnungen** | Der Mitgliedsbeitrag wird vor dem Monat berechnet, für den er gilt. | **Rechnungen** |
| 3 | **Nutzungssätze** | Eine Aufzeichnung der wirklich genutzten Zeit (Beta). | **Rechnungen** |
| 4 | **Monatsabschluss-Rechnungen** | Was der Monat über das Abo hinaus gekostet hat, wird gesondert berechnet. | **Rechnungen** |
| 5 | **Rechnungsassistent** | Ein geführter Monatsabschluss für die Person, die abrechnet. | **Rechnungen** |
| 6 | **Der Weg einer Rechnung** | Jede Rechnung zeigt, wo sie steht und wer am Zug ist. | **Rechnungen** |
| 7 | **Rechnungs-PDF-Vorlage** | Ihr eigener Einleitungs- und Fußtext auf dem PDF. | **Rechnungen** |
| 8 | **Mitgliederberichte** | Die Finanzvereinbarung und der monatliche Zahlungsbericht für Mitglieder. | **Finanzen-Tab** |
| 9 | **Mahnwesen** | Mahnstufen, ein Schreiben pro Stufe, „Mahnung fällig“ bei verspäteten Rechnungen. | **Rechnungen** |
| 10 | **Verbrauchsbericht** | Ein Brief am Monatsende mit dem, was genutzt wurde. | **Nutzungssätze** |

Fügen Sie dann nur hinzu, was auf Sie zutrifft:

- **USt-Verwaltung** (Beta), wenn Ihr Space für die Umsatzsteuer registriert ist. Dann **USt-Voranmeldungen** und, wenn Ihre Steuerberatung es verlangt, **USt-Satzversionen** und **USt-Gruppen**.
- **Admins stellen Rechnungen aus**, wenn eine Abrechnungsadministration sie ausstellen soll. Der Inhaber kann es immer.
- **Online-Zahlungen** (Beta) nur, wenn Sie einen Zahlungsanbieter anbinden.
- **Automatische Zahlungserinnerungen** erst, nachdem Sie gelesen haben, [was sie tun](help:setup.money.reminders).
- **Zubehör-Aufpreise**, **Mehrfachkarten** und **Gemeinsame Ausgaben**, wenn Sie diese Dinge berechnen.

**Gut zu wissen**

- Vervollständigen Sie vor der ersten Rechnung Ihre rechtliche Identität und die Umsatzsteuer. Siehe [Rechtliche Identität und Rechnungen](help:setup.money.identity).
- Das Ausstellen funktioniert hier nur für Spaces in Frankreich und Deutschland.
- Schalten Sie diese einzeln ein und stellen Sie zuerst in einem Test-Space eine Testrechnung aus. Siehe [Die Reihenfolge beim Einschalten](help:setup.features.order).

**Siehe auch:** [Geld und Rechnungen](help:setup.money.overview) · [Mit einer Vorlage oder bei null beginnen](help:setup.before.template)

<!-- anchor: setup.features.order -->
### Die Reihenfolge beim Einschalten

**Zielgruppe:** Inhaber · Mitinhaber

Sie möchten den Tag vermeiden, an dem alles an ist und nichts funktioniert. Gehen Sie einen Prozess nach dem anderen durch und sehen Sie jeden aus der Sicht eines Mitglieds an, bevor Sie weitergehen.

<p><img src="images/setup-features-order.de.jpg" width="280"></p>

**Schritte**

1. Behalten Sie den Kern und bringen Sie die Grundlagen zum Laufen: die Plätze, die Öffnungszeiten, einen Tarif. Siehe [Ihr Ort](help:setup.place.overview).
2. Öffnen Sie [Funktionen](app:/features) und öffnen Sie eine Prozesskarte. Wählen Sie den Prozess, der zu Ihrem nächsten Bedarf passt, nicht den, der am vollständigsten aussieht.
3. Tippen Sie bei einem Teilprozess auf **Einschalten** oder öffnen Sie eine einzelne Funktion unter **Schalter**.
4. Lesen Sie die Vorschau: was **Ebenfalls nötig** ist und was schon an ist.
5. Sehen Sie es als Mitglied an: Melden Sie sich als eines an (mit einem zweiten Konto oder auf der Testseite Ihres Spaces) und tun Sie, was ein Mitglied täte.
6. Erst dann gehen Sie zum nächsten Prozess.

*Eine sinnvolle Reihenfolge*

| Schritt | Prozess | Warum an dieser Stelle |
|---|---|---|
| 1 | **Raumverwaltung** | Ohne Ort und Öffnungszeiten lässt sich nichts buchen. |
| 2 | **Buchungen und Nutzung** | Buchungsregeln prägen alles, was danach kommt. |
| 3 | **Arbeitsbereich und Zugang** | Rollen und wer bestätigt, vor der ersten Einladung. |
| 4 | **Kalender und Koordination** | Nachrichten und Freigaben setzen voraus, dass es Personen gibt. |
| 5 | **Mitgliedschaftsangebote**, dann **Abrechnung & Zahlungen** | Preise vor Rechnungen; rechtliche Identität vor der ersten Rechnung. |
| 6 | **Dokumente und Informationen**, **Integrationen und Automatisierung** | Sie kleiden ein und liefern aus, was die anderen erzeugen. |
| 7 | **Betrieb und Verwaltung** | Paare, Ausrollungen und Übertragungen, wenn der Space es wert ist, kopiert zu werden. |

**Gut zu wissen**

- Einschalten ist billig, und Ausschalten löscht nichts; ein falscher Schritt kostet also Zeit, keine Daten. Die Ausnahme ist alles, was eine Rechnung ausstellt: siehe [Entscheidungen, die sich schwer rückgängig machen lassen](help:setup.before.permanent).
- Ein Test-Space ist der richtige Ort, um einen Prozess auszuprobieren. Siehe [Ein Test-Space oder ein echter](help:setup.before.environment) und [Ein Test-Space](help:user.advanced.test-space).
- Laden Sie Mitglieder zuletzt ein, nach den Rollen, den Freigaberegeln und den Tarifen, denen sie begegnen werden.

**Siehe auch:** [Ganze Prozesse ein- oder ausschalten](help:user.features.processes)

<!-- anchor: setup.features.safely -->
### Eine Funktion sicher einschalten

**Zielgruppe:** Inhaber · Mitinhaber

Sie sind dabei, eine Funktion zu ändern, und möchten die Wirkung sehen, bevor es sie gibt.

<p><img src="images/setup-features-safely.de.jpg" width="280"></p>

**Schritte**

1. Öffnen Sie [Funktionen](app:/features). Die Ansicht **Prozesse** wird angezeigt.
2. Tippen Sie auf **Braucht Aufmerksamkeit**. Es bleiben nur die Prozesse, die etwas enthalten, das an ist, aber wartet.
3. Öffnen Sie eine Karte. Eine Funktion mit dem Vermerk „An, wartet auf“ eine benannte übergeordnete Funktion ist das, was Sie beheben müssen.
4. Beheben Sie es, indem Sie die übergeordnete Funktion einschalten oder die Funktion ausschalten.
5. Um eine einzelne Funktion zu ändern, tippen Sie auf **Schalter**, suchen Sie sie mit **Funktionen durchsuchen** und legen Sie ihren Schalter um.
6. Lesen Sie die Frage oder die Zeile „Ebenfalls eingeschaltet“ und bestätigen Sie.

*Was „zurückgehalten“ bedeutet*

Eine Funktion ist zurückgehalten, wenn Sie sie gewählt haben, aber etwas, das sie braucht, aus ist. Ihr eigener Schalter bleibt an, weshalb man es leicht übersieht: Der Bildschirm sagt, die Funktion sei an, und die App bietet sie nicht an. Die Karte sagt, wie viele Funktionen zurückgehalten sind („… sind an, warten aber auf eine ausgeschaltete Voraussetzung“) und auf welche Voraussetzung sie warten; beheben Sie es direkt in [Funktionen](app:/features). [Was auf Sie wartet](help:user.collaborate.attention) zeigt dasselbe als eine Zeile pro ausgeschalteter Voraussetzung.

Auf anderes, worauf eine Funktion warten kann, geht dieser Bildschirm nicht ein. Eine Funktion kann an und voll erlaubt sein, während ihre Angaben fehlen: Ihre rechtliche Identität, ein Standort, ein Zahlungsanbieter. Diese erscheinen in **Einrichtung dieses Workspace**, oben in den Workspace-Einstellungen: die rechtliche Identität, bei eingeschalteten **Rechnungen**, als **Rechtliche Identität und Adresse des Space**, der Rest unter **Angaben, die Ihre Funktionen brauchen (Identität, Bank, Plattformen)**.

**Gut zu wissen**

- Hat jemand anderes die Funktionen geändert, während Sie hinsahen, schreibt die App nichts und sagt es: „Die Funktionen haben sich inzwischen geändert, daher wurde nichts gespeichert.“ Sehen Sie die Liste noch einmal an und schalten Sie erneut.
- **Geändert** zählt die Schalter, die vom Standard der Registry abweichen. In einem neuen Space zeigt es schon eine Zahl (die Plattformfunktionen, die ausgeschaltet starten); es ist also keine Zählung Ihrer eigenen Änderungen.
- Nur ein Inhaber oder Mitinhaber kann Funktionen schreiben. Der Server prüft es im Moment des Schreibens noch einmal.

**Siehe auch:** [Ganze Prozesse ein- oder ausschalten](help:user.features.processes) · [Ein Funktionsschalter](help:user.features.switch)

<!-- anchor: setup.features.consistency -->
### Funktionen vermeiden, die sich widersprechen

**Zielgruppe:** Inhaber · Mitinhaber · Abrechnungsadministrator:in

Sie möchten wissen, welche Kombinationen einen Space halb funktionsfähig lassen und welche davon die App für Sie abfängt.

Die App hat Schutzvorkehrungen für manche Widersprüche und für andere keine. In der Tabelle ist eine Schutzvorkehrung, was die App tut; eine Lücke ist, was in Ihrer Verantwortung bleibt.

| Wenn Sie … haben | Schutz in der App | Verbleibende Lücke |
|---|---|---|
| **Rechnungen** an, keine rechtliche Identität | Das Ausstellen wird verweigert; **Vor der Ausstellung bitte ergänzen** listet die fehlende Adresse, Umsatzsteuernummer usw. auf. Der Bedarf erscheint auch in **Einrichtung dieses Workspace**, als **Rechtliche Identität und Adresse des Space**, **Vor der Rechnungsstellung nötig**, und in Was auf Sie wartet. | Die Funktion ist ab dem ersten Tag an; nichts hindert Sie also daran, Mitglieder einzuladen und einen Monat laufen zu lassen, bevor die Identität existiert. |
| Ein anderes Land als Frankreich oder Deutschland | Das Ausstellen sagt, das Land „muss Frankreich oder Deutschland sein, um hier auszustellen“. | Nichts warnt Sie, wenn Sie das Land wählen oder die Rechnungsstellung einschalten. |
| Für die Umsatzsteuer registriert, kein gültiger Satz | Das Ausstellen wird verweigert, bis ein Standardsatz gilt. Die Beschreibung von **USt-Verwaltung** und die Warnung auf dem Bildschirm der rechtlichen Identität sagen es. | Bei ausgeschalteter **USt-Verwaltung** ist die Konfiguration verborgen, während die gespeicherten Sätze weiter gelten. Prüfen Sie die Sätze nach dem Ausschalten. |
| **Online-Zahlungen** an, kein Anbieter | Eine neue Online-Zahlung wird abgelehnt, wenn die Funktion aus ist; der fehlende Anbieter erscheint in **Einrichtung dieses Workspace**. | Sie können sie ohne Anbieter einschalten. Binden Sie ihn zuerst an: [Zahlungsanbieter](help:user.money.payments.provider). |
| **Kiosk-Modus** an, keine Badges und kein Kiosk-Mitglied | **RFID-/NFC-Badges**, **QR-Badges**, **Mitgliederfotos am Kiosk** und **Mit Ausweis anmelden** können ohne ihn nicht an sein. | Nichts prüft, ob ein Kiosk-Mitglied existiert oder ein Badge ausgegeben wurde. Siehe [Ein Wand-Tablet betreiben](help:user.kiosk.mode). |
| **Standorte** an, kein Standort | **Mindestens ein Standort** erscheint unter den Angaben, die Ihre Funktionen brauchen. | Der Schalter kann ohne Standort an sein. |
| **Push-Benachrichtigungen** an, kein Push-Dienst | Mitglieder bekommen weiterhin alles in der App. | Telefone erhalten nichts, bis die Betreiberin oder der Betreiber der Installation den Push-Dienst eingerichtet hat. Siehe [Wie Mitglieder informiert werden](help:setup.notify.channels). |
| **Mahnwesen** an, **Automatische Zahlungserinnerungen** an | Die zweite kann ohne die erste nicht an sein. | Der Server versendet sie jeden Morgen, sofern die Installation Aufgaben plant; sonst werden sie versendet, wenn ein Administrator Finanzen öffnet. Der Schalter und die Funktionsbeschreibung sagen es; der Betreiber Ihres Servers weiß, was zutrifft. |
| Eine Freigaberegel verlangt mehr Prüfer, als es gibt | **Einrichtung dieses Workspace** sagt „Eine Regel verlangt mehr Prüfer, als dieser Bereich hat“, und **Rollen und wer Anfragen bestätigt** wird erforderlich, gleich welche Art von Anfrage. | Anfragen, die vor Ihrer Korrektur angelegt wurden, können nicht abgeschlossen werden und verfallen nach sieben Tagen. Siehe [Wer bestätigt](help:user.validation.overview). |
| **Lösch-Anträge für Buchungen** an, niemand zum Bestätigen | Dieselbe Bereitschaftszeile. | Dieselbe Lücke. |
| **Tisch-, Büro- & Etagen-Reservierungen** an | **Admins können Etagen zuweisen** braucht sie. | Jedes Mitglied braucht außerdem das Recht; nichts prüft, ob es jemand hat. |
| Eine untergeordnete Funktion an, ihre übergeordnete aus | **Braucht Aufmerksamkeit** und „Wartet auf die Funktion darüber“. | Keine: Dieser Fall ist vollständig abgedeckt. |
| Ein Space aus einer Vorlage | Die Vorlage nennt, was Sie selbst eingeben müssen (Identität, Bank, Standort). | Sie bringt nichts davon mit; ein Space kann also mit eingeschalteten **Rechnungen** starten, ohne dass etwas ausgestellt werden kann. |

**Gut zu wissen**

- Die Faustregel: Bringt eine Funktion Ihren Namen, Ihr Geld oder Ihre rechtlichen Pflichten auf ein Dokument, vervollständigen Sie ihre Angaben, bevor Sie es den Mitgliedern sagen.
- **Einrichtung dieses Workspace** ist eine Liste, keine Sperre. Sie hindert Sie nie daran, etwas einzuschalten.
- Die Prüfung „Bevor hier jemand buchen kann“ spricht nur über die erforderlichen Bereiche: die Zeitzone, die Währung, einen geöffneten Wochentag, mindestens einen Platz, Mitglieder mit **Buchen und Reservierungen nutzen** und genug Bestätigende. Bei eingeschalteten **Rechnungen** ist auch die rechtliche Identität erforderlich, aber vor der Rechnungsstellung: Die Karte des Space sagt „Vor der Rechnungsstellung“, die Karte unter Reservieren nennt sie nie.

**Siehe auch:** [Rechtliche Identität und Rechnungen](help:setup.money.identity) · [Probelauf](help:setup.money.dry-run)

<!-- anchor: setup.features.map -->
### Die Funktionslandkarte

**Zielgruppe:** Inhaber · Mitinhaber

Sie möchten einen Ort, der für die wichtigsten Funktionen sagt, was Mitglieder bekommen, was sie brauchen und wer sie einrichten muss. „Braucht“ nennt zuerst die übergeordnete Funktion, dann die Angaben außerhalb des Bildschirms Funktionen. „Wer“ ist die Person, die etwas tun muss, bevor die Funktion nützt; „Niemand“ heißt, sie funktioniert, sobald sie an ist.

*Arbeitsbereich und Zugang*

| Funktion | Was sie Mitgliedern bringt | Was sie braucht | Wer richtet sie ein |
|---|---|---|---|
| **Mitgliederverzeichnis** | Der Community-Tab: wer da ist, Status, Anwesenheit. | | Niemand |
| **Mitinhaber** | Inhaberrechte für ernannte Personen, jetzt oder bei Nachfolge. | | Inhaber |
| **Rollenverwaltung** | Die Matrix, welche Rolle welche Berechtigung hat. | | Inhaber |
| **Rollen vergeben** | Ein Abschnitt Rollen auf jeder Mitgliedsseite. | **Rollenverwaltung** | Inhaber |
| **Rollen dieses Bereichs** | Eigene Rollen, etwa Schatzmeister oder Schriftführer. | | Inhaber |
| **Fragen dieses Bereichs** | Eigene Fragen im Identitätsformular. | | Inhaber |
| **Persönliche Angaben** | Name, Adresse, Telefon und Kennungen, die Briefe drucken. | | Mitglieder |
| **Verwaltete Profile** | Mitglieder ohne Konto, für die gebucht und abgerechnet wird. | **Mitgliederverzeichnis** | Administrator:in |
| **Mitgliedsseite** | Eine Seite pro Mitglied. | **Mitgliederverzeichnis** | Niemand |
| **Gastbesuche** | Eine Person, die kein Mitglied ist, kann um einen Besuch bitten. | | Wer Besuche zulässt |
| **Kiosk-Modus** | Ein Wand-Tablet, das auf den Live-Plan festgelegt ist. | Ein Tablet und ein Kiosk-Mitglied | Inhaber |
| **RFID-/NFC-Badges** | Einchecken durch Auflegen einer Karte. | **Kiosk-Modus**, Android mit NFC, ausgegebene Badges | Inhaber |
| **QR-Badges** | Druckbare QR-Badge-Karten. | **Kiosk-Modus** | Inhaber |
| **Mit Ausweis anmelden** | Badge und PIN statt Eintippen einer E-Mail-Adresse. | **RFID-/NFC-Badges** | Inhaber, dann jedes Mitglied |
| **NFC/RFID-Tags an Stühlen** | Ein Chip an einem Stuhl öffnet seinen Platz. | Tags | Inhaber |
| **Raum-QR-Codes** | Druckbare QR-Karten pro Platz. | | Niemand |

*Raumverwaltung*

| Funktion | Was sie Mitgliedern bringt | Was sie braucht | Wer richtet sie ein |
|---|---|---|---|
| **Standorte** | Mehrere Adressen, jede mit eigener Registrierung. | Mindestens ein Standort | Inhaber |
| **Räume mit Historie löschen** | Inhaber können einen Platz löschen, der vergangene Buchungen hat. | | Niemand |
| **Admins können Plätze sperren** | Plätze, die für Wartung als nicht buchbar markiert sind. | | Inhaber |
| **Arbeitszeiten** | Der Arbeitstag und die Buchung auf genaue Uhrzeiten. | | Inhaber |
| **Feiertage** | Schließtage aus den Feiertagen eines Jahres. | | Inhaber |
| **Feiertage importieren** | Feiertage eines Landes oder einer Region importiert. | **Feiertage** | Inhaber |
| **Platzauslastung** | Eine Monatszahl dazu, wie viel gebucht wurde. | | Inhaber |
| **Mitgliederfotos auf dem Plan** | Fotos der Belegenden auf den Plätzen. | | Niemand |
| **Wortwahl des Arbeitsbereichs** | Die eigenen Begriffe des Spaces für einige Beschriftungen. | | Inhaber |
| **Farben des Arbeitsbereichs** | Die Markenfarbe und die Raumfarben. | | Inhaber |
| **Öffentlicher Workspace-Eintrag** | Eine öffentliche Seite mit dem, was Sie zeigen möchten. | | Inhaber |

*Buchungen und Nutzung*

| Funktion | Was sie Mitgliedern bringt | Was sie braucht | Wer richtet sie ein |
|---|---|---|---|
| **Serienbuchung** | Eine Buchung wiederholen. | | Niemand |
| **Für andere buchen** | Admins buchen für Mitglieder. | | Niemand |
| **Tisch-, Büro- & Etagen-Reservierungen** | Einen ganzen Tisch, ein Büro oder eine Etage buchen. | Ein pro Mitglied erteiltes Recht | Inhaber |
| **Admins können Etagen zuweisen** | Admins weisen diese Reservierungen zu. | **Tisch-, Büro- & Etagen-Reservierungen** | Inhaber |
| **Buchungsregeln** | Vergangene Buchungen, Buchungen außerhalb der Zeiten, Check-out durch Admins. | | Inhaber |
| **Buchungsprüfung** | Jede Oberfläche prüft die Regeln und nennt den Grund. | **Buchungsregeln** | Niemand |
| **Auto-Check-in/-out am Tagesende** | Nicht ausgecheckte Buchungen schließen sich selbst ab. | | Inhaber |
| **Nutzungssätze** | Die wirklich genutzte Zeit und ein Antrag, ungenutzte Zeit nicht abzurechnen. | **Rechnungen** | Abrechnungsadministrator:in |

*Kalender und Koordination*

| Funktion | Was sie Mitgliedern bringt | Was sie braucht | Wer richtet sie ein |
|---|---|---|---|
| **Kalender-Tab**, **Kalender-Hub**, **Kalenderansichten** | Monat, Woche und Agenda, mit allem, was ein Datum hat. | | Niemand |
| **Freigaben im Kalender** | Entscheidungen, angezeigt, wenn sie getroffen wurden. | **Kalender-Hub** | Niemand |
| **Ereignis-Tab** | Der Aktivitätsfeed und Bestätigungen. | | Niemand |
| **Gruppierung der Benachrichtigungen** | Benachrichtigungen im Feed gruppiert. | | Niemand |
| **Prüfer nach Rolle oder Person** | Eine Regel kann benennen, wer bestätigt und wie viele. | | Inhaber |
| **Verkettete Freigaben** | Freigaben, die nacheinander erbeten werden. | | Inhaber |
| **Lösch-Anträge für Buchungen** | Ein Mitglied beantragt, eine vergangene Buchung zu löschen. | Ein Prüfer | Inhaber |
| **Mitglieder-Benachrichtigungen** | Private und Gruppenunterhaltungen. | | Niemand |
| **Nachrichten, überarbeitet** | Posteingangsleiste, Anheften, Stummschalten, Archivieren, Entwürfe. | | Niemand |
| **An die Gastgeber schreiben** | Wer Ihre Seite findet, kann Ihnen schreiben. | Eine veröffentlichte Seite | Inhaber |
| **Erwähnungen in Gruppen**, **Nachrichten weiterleiten**, **Schutz vor Bildschirmaufnahmen** | Zusätze für Nachrichten. | **Mitglieder-Benachrichtigungen** | Niemand |

*Mitgliedschaftsangebote*

| Funktion | Was sie Mitgliedern bringt | Was sie braucht | Wer richtet sie ein |
|---|---|---|---|
| **Leistungen** | Ein Katalog dessen, was man verbrauchen und bezahlen kann. | **Finanzen-Tab** | Abrechnungsadministrator:in |
| **Zubehör-Aufpreise** | Bepreistes Platzzubehör pro halbem Tag. | **Finanzen-Tab** | Abrechnungsadministrator:in |
| **Preisverhandlungen** | Eigene Konditionen für ein Mitglied. | **Finanzen-Tab** | Abrechnungsadministrator:in |
| **Zahlungsbedingungen je Mitglied** | Eigene Zahlungsfristen. | **Rechnungen** | Abrechnungsadministrator:in |
| **Mehrfachkarten** | Vorausbezahlte halbe Tage (Beta). | **Rechnungen**, ein definierter Block | Abrechnungsadministrator:in |

*Abrechnung & Zahlungen*

| Funktion | Was sie Mitgliedern bringt | Was sie braucht | Wer richtet sie ein |
|---|---|---|---|
| **Finanzen-Tab** | Der Tab Finanzen: Kontoauszug, Zahlungen, Ausgaben. | | Niemand |
| **Finanzen in vier Ansichten** | Kontoauszug, Zahlungen, Rechnungen, Dokumente. | **Finanzen-Tab** | Niemand |
| **Mitgliederberichte** | Die Vereinbarung und der monatliche Zahlungsbericht. | **Finanzen-Tab** | Abrechnungsadministrator:in |
| **Rechnungen** | Unveränderliche, signierte Rechnungen (Beta). | **Finanzen-Tab**, rechtliche Identität, Umsatzsteuer, FR oder DE | Abrechnungsadministrator:in |
| **Admins stellen Rechnungen aus** | Administratoren stellen sie auch aus. | **Rechnungen** | Inhaber |
| **Abo-Rechnungen** | Der Beitrag, vor seinem Monat berechnet. | **Rechnungen**, ein Datum | Abrechnungsadministrator:in |
| **Monatsabschluss-Rechnungen** | Nutzung, nach dem Monat berechnet. | **Rechnungen** | Abrechnungsadministrator:in |
| **Rechnungen zusammenfassen** | Mehrere offene Rechnungen als eine. | **Rechnungen** | Abrechnungsadministrator:in |
| **Der Weg einer Rechnung** | Wo jede Rechnung steht. | **Rechnungen** | Niemand |
| **Rechnungsassistent** | Ein geführter Monatsabschluss. | **Rechnungen** | Abrechnungsadministrator:in |
| **Nummernkreise** | Nummerierung pro Journal. | **Rechnungen** | Abrechnungsadministrator:in |
| **Online-Zahlungen** | Online bezahlen (Beta). | **Finanzen-Tab**, ein Zahlungsanbieter | Inhaber |
| **Mahnwesen** | Mahnstufen und Schreiben. | **Rechnungen**, Regeln | Abrechnungsadministrator:in |
| **Automatische Zahlungserinnerungen** | Erinnerungen, die sich selbst versenden. | **Mahnwesen** | Abrechnungsadministrator:in |
| **Vorräte aus Ausgaben** | Eingekaufte Vorräte werden zu Leistungen. | **Leistungen** | Abrechnungsadministrator:in |
| **Geplante Ausgaben** | Wiederkehrende Kosten, eingeplant. | **Finanzen-Tab** | Abrechnungsadministrator:in |
| **Gemeinsame Ausgaben** | Kosten, die unter Mitgliedern geteilt werden. | **Rechnungen** | Abrechnungsadministrator:in |
| **Umlage-Assistent** | Eine geführte Aufteilung einer gemeinsamen Ausgabe. | **Gemeinsame Ausgaben** | Abrechnungsadministrator:in |
| **Buchführung** | Wer die offiziellen Bücher führt. | **Rechnungen** | Abrechnungsadministrator:in |
| **USt-Verwaltung** | Umsatzsteuersätze und Auswahllisten (Beta). | **Rechnungen**, Umsatzsteuerregelung | Abrechnungsadministrator:in |
| **USt-Voranmeldungen** | Die periodische Erklärung. | **USt-Verwaltung** | Abrechnungsadministrator:in |
| **USt-Gruppen**, **USt-Satzversionen**, **USt nach Kunde** | Feinere Umsatzsteuerbehandlung. | **USt-Verwaltung** | Abrechnungsadministrator:in |

*Dokumente und Informationen, Betrieb, Integrationen*

| Funktion | Was sie Mitgliedern bringt | Was sie braucht | Wer richtet sie ein |
|---|---|---|---|
| **Dokumentbibliothek** | Satzung, Protokolle, Anleitungen, je Rolle. | | Inhaber |
| **PDF-Export** | Die Monatsrechnung als PDF. | | Niemand |
| **Rechnungs-PDF-Vorlage** | Ihre Texte auf der Rechnung. | **Rechnungen** | Inhaber |
| **Berichtsdesigner**, **Positionierte Berichtslayouts**, **Berichtstexte** | Gestaltete Berichte. | **Rechnungs-PDF-Vorlage** | Inhaber |
| **Verbrauchsbericht** | Ein Monatsbrief darüber, was genutzt wurde. | **Nutzungssätze** | Abrechnungsadministrator:in |
| **MwSt-Bericht** | Jede steuerpflichtige Zeile, mit CSV. | **USt-Voranmeldungen** | Abrechnungsadministrator:in |
| **Datenzugriffsprotokoll** | Mitglieder sehen, wer ihre Finanzen angesehen hat. | **Finanzen-Tab** | Niemand |
| **Datenexport (Excel)** | Der Inhaber exportiert die Daten als Arbeitsmappe (Beta). | Die Berechtigung **Buchhaltung und Daten exportieren** | Inhaber |
| **Export & Löschung** | Ein Mitglied exportiert und löscht seine eigenen Daten. | | Niemand |
| **Aufnahmemodus** | Ersetzt auf dem Bildschirm echte Personen durch erfundene. | | Inhaber |
| **Umgebungspaare**, **Ausrollungen** | Eine Testseite und eine echte Seite, mit Ausrollung. | | Inhaber |
| **Konfiguration in der Raumdatei** | Die gesamte Konfiguration reist in der Raumdatei mit. | **Datenexport (Excel)** | Inhaber |
| **Instanz-Assistent** | Einen neuen Server aus der App erstellen. | | Betreiber:in |
| **Was auf Sie wartet** | Eine geordnete Liste dessen, was auf Sie wartet. | | Niemand |
| **Aufgabenrekorder** | Die Schritte einer Aufgabe aufzeichnen und wiedergeben. | | Niemand |
| **Push-Benachrichtigungen** | Ausstehende Bestätigungen auf dem Telefon. | Der Push-Dienst der Installation | Betreiber:in |
| **WhatsApp-Integration** | Ein Chat mit einem Mitglied mit einem Tipp, der Gruppenlink. | **Mitgliederverzeichnis** | Inhaber |
| **E-Rechnungszustellung an Kunden** | Versand an die eigene Plattform des Kunden (Beta). | **Rechnungen**, ein Konto | Abrechnungsadministrator:in |
| **MCP-Schnittstelle** | Ein Assistent kann angebunden werden. | Eine Freigabe je Person, von der Installation genehmigt | Inhaber, dann Betreiber:in |

**Gut zu wissen**

- Die Namen sind die der Liste **Schalter**. Dort steht auch die Stufe Kern oder Plattform jeder Funktion.
- Einige Funktionen sind hier nicht aufgeführt. Komfortfunktionen (Hilfehinweise, Animationen, Navigationsstil, regionale Formate) haben keine Tabellenzeile: Sie funktionieren, sobald sie an sind.

**Siehe auch:** [Wer was tut](help:setup.before.who) · [Funktionen ein- und ausschalten](help:user.features.processes)
