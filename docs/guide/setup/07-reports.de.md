<!-- anchor: setup.reports.overview -->
## Dokumente und Berichte

**Zielgruppe:** Inhaber · Mitinhaber · Abrechnungsadministrator:in

Alles, was DesKilo druckt oder exportiert, kommt aus einer Engine und einem Ort zum Gestalten. Dieses Kapitel sagt Ihnen, welche Dokumente es gibt, in welcher Reihenfolge Sie sie vorbereiten, was Sie Ihrem Steuerberater übergeben können und wo ein KI-Assistent helfen kann und wo nicht. Die Klicks stehen im Benutzerhandbuch; hier erfahren Sie die Gründe und die Reihenfolge.

Das durchgehende Beispiel ist der Demo-Space *Atelier du Marché*.

<!-- anchor: setup.reports.documents -->
### Die Dokumente, die die App erzeugt

**Zielgruppe:** Inhaber · Abrechnungsadministrator:in

Sie möchten wissen, was es gibt, bevor Sie etwas gestalten, und wer welches Dokument erhält.

<p><img src="images/setup-reports-hub.de.jpg" width="280"></p>

Jedes Dokument ist eine eigene *Art*. Jede Art hat ihr eigenes Layout; wenn Sie die Rechnung ändern, ändert sich also nie der Kontoauszug.

| Dokument | Wer es erhält | Wo Sie es finden |
|---|---|---|
| Rechnung und Gutschrift (ein gemeinsames Layout) | Das Mitglied oder der Kunde eines abgerechneten Monats | [Rechnungsstellung](help:user.invoicing.hub) |
| Proforma-Rechnung | Ein Mitglied, das ein Angebot oder eine Vorauszahlungsaufforderung braucht | Derselbe Bildschirm |
| Kontoauszug | Das Mitglied (sein Konto über einen Zeitraum) | [Der Kontoauszug](help:user.money.statement) |
| Vereinbarung | Das Mitglied (die ausgehandelten Bedingungen) | [Preisverhandlung](help:user.money.negotiation) |
| Zahlungen, Nutzung | Das Mitglied, der Abrechnungsadministrator | [Zahlungen](help:user.money.payments) · [Nutzung](help:user.money.usage) |
| Mahnschreiben, Stufe 1 bis 9 | Das Mitglied mit einer überfälligen Rechnung | [Mahnregeln](help:user.money.reminders.rules) |
| Workspace-Bericht und Workspace-Status | Sie, der Vorstand, ein Prüfer | **Berichte** |
| Umsatzsteuer-Voranmeldung | Sie, danach die Steuerplattform | [Die periodische Umsatzsteuer-Voranmeldung](help:user.money.vat.declaration) |
| Ausweise, Raum-QR-Codes | Mitglieder an der Tür, Ihre Wände | [Raum-QR-Codes](help:user.workspace.export.space-qr) · [Ausweise](help:user.badges.nfc) |

**Gut zu wissen**

- Der Bildschirm **Berichte** ordnet sie je nach Ihren Berechtigungen unter **Finanzberichte**, **Workspace-Dokumente**, **Geschäftsanalyse** und **Vorlagen** ein.
- Einige Berichte (Kontenplan, Ausweise, QR-Karten) haben ein einziges mitgeliefertes Layout. Die anderen lassen sich neu gestalten.
- Dokumente aus einem Test-Space tragen ein Wasserzeichen, das darauf hinweist. Siehe [Wofür ein Test-Space da ist](help:user.advanced.test-space).

**Siehe auch:** [Berichte](help:user.money.reports) · [Die PDF-Vorlage der Rechnung](help:user.money.reports.invoice-template)

<!-- anchor: setup.reports.designer -->
### Der Editor, in Worten für Inhaber

**Zielgruppe:** Inhaber · Abrechnungsadministrator:in

Sie möchten einen Brief, der nach Ihnen aussieht, ohne eine Auszeichnungssprache zu lernen.

<p><img src="images/setup-reports-professional.de.jpg" width="280"></p>

Ein Dokument ist eine Seite aus mehreren Streifen, in der App **Bänder** genannt. Der *Kopf* trägt Ihren Briefkopf und den Empfänger. Der *Rumpf* trägt die Zeilen. Der *Fortsetzungsstreifen* beginnt auf Seite zwei, und der *Fuß* wiederholt sich auf jeder Seite mit Ihren Zahlungsbedingungen und rechtlichen Angaben. Sie bearbeiten sie unter **Entwurf** und prüfen sie in der **Vorschau**; **Markup** zeigt dieselben Bänder als Text für den Tag, an dem Sie das brauchen.

| Baustein | Was er Ihnen bringt | Wählen Sie ihn, wenn |
|---|---|---|
| Vorlagen (**Professionell**, **Klassisch**, **Einfach**, **Ausführlich**, **Formeller Brief**) | Ein fertiges Layout als Ausgangspunkt. Die Vorlagen unterscheiden sich für Rechnungen, Proforma-Rechnungen, Kontoauszüge, Vereinbarungen und Mahnungen; Dokumente mit fester Struktur haben ein einziges mitgeliefertes Layout | Immer: Beginnen Sie mit **Professionell** und ändern Sie wenig |
| Ein Layout pro Sprache | Ein Mitglied liest das Dokument in seiner eigenen Sprache | Ihre Mitglieder lesen nicht alle dieselbe Sprache |
| Briefkopf und Fensterumschlag | Absender, Empfänger und Text sitzen dort, wo ein Fensterumschlag sie erwartet | Sie versenden Rechnungen auf Papier |
| Positioniertes Layout (XML) | Jedes Element ist in Millimetern platziert, für ein nationales Formular | Ein Dokument muss einem festen Formular entsprechen |
| Bildbibliothek | Ein Logo, ein Stempel oder eine Unterschrift, die in mehreren Layouts verwendet werden | Sie haben ein Logo |
| Layout-Austausch | Ein Layout wird in eine Datei geschrieben und wieder eingelesen | Eine Person oder ein Werkzeug außerhalb der App bearbeitet es |

Zwei Tatsachen bewahren Sie vor Überraschungen. Der Briefstandard druckt den Empfänger im Fenster rechts für einen französischen Space und links für einen deutschen, sofern Sie das nicht ändern. Und ein Layout, das sich nicht darstellen lässt, blockiert nie ein Dokument: Dann übernimmt das eingebaute Layout.

> **Achtung** Die Formulierungen in einem Layout sind keine Rechtsberatung. Aussehen und Übersetzung allein stellen weder rechtliche Konformität her noch erfüllen sie eine Pflicht zur elektronischen Rechnung. Was eine Rechnung enthalten muss, legen Sie unter [Ihre rechtliche Identität](help:user.money.legal.identity) fest; Ihr Steuerberater bestätigt es.

**Siehe auch:** [Der Berichtseditor](help:user.money.reports.editor) · [Fertige Vorlagen](help:user.money.reports.presets) · [Ein Layout pro Sprache](help:user.money.reports.languages)

<!-- anchor: setup.reports.sequence -->
### Die Reihenfolge, der Sie folgen

**Zielgruppe:** Inhaber · Abrechnungsadministrator:in

Sie wollen Dokumente gestalten und es einmal tun, in der richtigen Reihenfolge.

<p><img src="images/setup-reports-presets.de.jpg" width="280"></p>

**Schritte**

1. Legen Sie zuerst Ihre rechtliche Identität fest: Organisationsform, Anschrift, Registereintrag, Steuerregime und die besonderen Angaben. Ein Layout druckt nur, was Sie dort eingegeben haben. Siehe [Ihre rechtliche Identität](help:user.money.legal.identity).
2. Öffnen Sie den [Berichtseditor](app:/report-editor), wählen Sie das Dokument und beginnen Sie mit **Professionell** unter **Vorlagen**.
3. Fügen Sie für jede Sprache, die Ihre Mitglieder lesen, eine Sprachversion hinzu. Wählen Sie **EN**, **FR**, **DE**, **ES** oder **IT** unter dem Dokument. Siehe [Ein Layout pro Sprache](help:user.money.reports.languages).
4. Prüfen Sie jede Version mit der **Schnellvorschau**. Sie verwendet Ihre neueste Rechnung oder Beispieldaten, wenn es keine gibt.
5. Proben Sie in einem Test-Space: Betreten Sie ihn, stellen Sie eine Probe-Rechnung aus, drucken Sie sie und senden Sie sie Ihrem Steuerberater. Siehe [Wofür ein Test-Space da ist](help:user.advanced.test-space).
6. Frieren Sie das Layout vor der ersten Rechnung ein. Schreiben Sie auf, was Sie entschieden haben, und ändern Sie ein Layout nur, wenn sich eine Vorschrift ändert.

**Gut zu wissen**

- Das Ersetzen eines Layouts lässt sich mit **Rückgängig** zurücknehmen, bis Sie den Editor verlassen.
- Eine ausgestellte Rechnung ist ein eingefrorenes Dokument. Ein späteres Ändern des Layouts betrifft neue Dokumente, nie die bereits ausgestellten.
- Steht derselbe Wortlaut in zwei Sprachen, bitten Sie jemanden, der die zweite Sprache liest, die Vorschau zu lesen.

> **Achtung** Die Rechnungsnummer und die auf einer Rechnung gedruckten rechtlichen Angaben werden mit der ersten ausgestellten Rechnung endgültig. Klären Sie sie davor, nicht danach.

**Ergebnis:** Jedes Dokument, das Sie versenden werden, sieht nach Ihnen aus, in jeder Sprache, und wurde einmal von jemand anderem als Ihnen gelesen.

**Siehe auch:** [Ihre rechtliche Identität](help:user.money.legal.identity) · [Die PDF-Vorlage der Rechnung](help:user.money.reports.invoice-template)

<!-- anchor: setup.reports.accountant -->
### Was Sie Ihrem Steuerberater übergeben

**Zielgruppe:** Inhaber · Abrechnungsadministrator:in

Sie möchten, dass Ihr Steuerberater hat, was er braucht, und weiß, was die App nicht behauptet.

<p><img src="images/setup-reports-export.de.jpg" width="280"></p>

Beginnen Sie beim [Rechnungsregister](app:/invoice-register), das jede Rechnung mit ihrem Status auflistet, und tippen Sie auf **Buchhaltungsexport**. Jedes Format sagt im Blatt, was es beansprucht.

| Datei | Was sie beansprucht | Was sie nicht beansprucht |
|---|---|---|
| FEC | Das französische Format, das eine Prüfung verlangt, aus Rechnungen und Zahlungen neu aufgebaut | Vollständige Bücher. Die vervollständigt Ihr Steuerberater |
| DATEV | Eine Austauschdatei für die Programme deutscher Steuerberater, von einer Person gelesen und gebucht | Eine Abgabe oder eine Übergabe für eine Betriebsprüfung |
| SAF-T | Die internationale Struktur, bewusst unvollständig: Rechnungen und Zahlungen, kein Hauptbuch | Eine vollständige Buchhaltungsdatei. Das steht im Kopf der Datei |
| SAF-T PT, Sage 50 | Ein portugiesisches Aufsichtsformat (nicht zertifiziert) und ein britisch-irisches Austauschformat, je nach Ihrem Land | Eine Abgabe oder eine Zertifizierung |
| Buchhaltungs-CSV, Prüfpfad, Jahresarchiv (zip) | Eine Lesehilfe für Ihren Steuerberater | Eine Abgabe |

Die Liste der Formate hängt von Ihrem Land ab. FEC und DATEV verlangen Ihre Kontonummern, FEC zusätzlich Ihre Registernummer: Halten Sie sie bereit. Die Umsatzsteuerzahlen für den Zeitraum finden Sie unter [Die periodische Umsatzsteuer-Voranmeldung](help:user.money.vat.declaration).

*Was die App nicht leistet*

- Sie führt Rechnungen, Zahlungen und ein laufendes Konto je Mitglied. Eine doppelte Buchführung über einen Kontenplan führt sie nicht, sie kann also eine Buchhaltungssoftware nicht ersetzen.
- Einige Pflichten bleiben bei Ihnen und Ihrem Steuerberater: vollständige Bücher, zertifizierte Software, wo Ihr Land sie verlangt, und die Annahme durch die zuständige Behörde.
- Eine Datei bleibt gesperrt, bis die Probleme in der Quelle behoben sind.

**Gut zu wissen**

- Ein Export ist ein Lesezugriff. Sie können ihn für jeden Zeitraum wiederholen.
- Bereiten Sie vor der ersten Rechnung eine kurze Zusammenfassung für Ihren Steuerberater vor: Ihr Steuerregime, wann die Umsatzsteuer fällig wird, die gewählte Nummerierung und die gewünschten Exporte. Siehe [Hilfe durch KI](help:setup.reports.ai).

**Siehe auch:** [Buchhaltungsexporte](help:user.invoicing.accounting-export) · [Das Rechnungsregister](help:user.invoicing.register) · [Umsatzsteuerkonto](help:user.money.vat.account)

<!-- anchor: setup.reports.analytics -->
### Geschäftsanalyse im Überblick

**Zielgruppe:** Inhaber · Abrechnungsadministrator:in

Sie möchten sehen, wie der Space läuft, sobald er in Betrieb ist, ohne Tabellenkalkulation.

<p><img src="images/setup-reports-documents.de.jpg" width="280"></p>

Die **Geschäftsanalyse** zeigt Zahlen nach Bereichen: in Rechnung gestellt und eingenommen, Auslastung und Kapazität. Sie wählen einen Zeitraum (Monat, Quartal oder Jahr), vergleichen ihn mit einem anderen, speichern eine Ansicht und exportieren sie als PDF. Sie sehen nur die Analysen, die Ihre Rolle lesen darf.

Eingenommen sind die Zahlungen, die Rechnungen zugeordnet sind. Das ist kein Gewinn, denn Kosten sind in der Zahl nicht enthalten, und der laufende Zeitraum ist unvollständig.

Für ein Dokument über den ganzen Space enthält der Reiter **Workspace-Dokumente** den **Arbeitsbereichsbericht**, **Raum-QR-Codes (PDF)**, **Daten exportieren (Excel)** und **Konfiguration exportieren (PDF)**. Nutzen Sie die letzten beiden als Sicherungskopie vor einer großen Änderung.

**Siehe auch:** [Geschäftsanalyse](help:user.invoicing.bi) · [Exporte](help:user.workspace.export.workspace-report)

<!-- anchor: setup.reports.ai -->
### Hilfe durch einen KI-Assistenten

**Zielgruppe:** Inhaber · Mitinhaber

Ein KI-Chatwerkzeug kann Ihnen bei den Worten rund um Ihre Einrichtung Stunden sparen. Es kann nicht derjenige sein, der entscheidet, was rechtlich oder steuerlich richtig ist. Dieser Abschnitt handelt von Werkzeugen, die Sie außerhalb von DesKilo nutzen; die Assistentenverbindung in der App wird am Ende beschrieben.

*Wofür ein externes Werkzeug taugt*

- Die Einladungsnachricht entwerfen, die Sie Ihren ersten Mitgliedern schicken. Siehe [Die Einladungsnachricht](help:user.workspace.settings.invitation-message). Die Platzhalter wie Vorname oder Einladungslink bleiben, wie sie sind.
- Die besonderen Angaben formulieren, die Sie Ihrem Steuerberater vorlegen, als Entwurf zum Prüfen, nie als endgültigen Text.
- Den Wortlaut eines Layouts in eine andere Sprache übersetzen, sodass Sie ihn nur noch durchsehen müssen.
- Einem Mitglied einen Bericht oder einen Kontoauszug in einfachen Worten erklären.
- Die Zusammenfassung Ihrer Entscheidungen für den Steuerberater vorbereiten: Land, Organisationsform, Steuerregime, Nummerierung, Exporte.
- Das Bild hinter Ihrem Grundriss entwerfen, aus Fotos, in einem Bildwerkzeug.

*Was es nicht entscheiden darf*

- Die rechtlichen Angaben einer Rechnung, die umsatzsteuerliche Behandlung einer Tätigkeit, den Grund, warum keine Umsatzsteuer berechnet wird, und die Steuersätze.
- Alles, was endgültig wird: ein Format der Rechnungsnummer, ein Steuerregime, die Währung, eine ausgestellte Rechnung.
- Ob etwas den Vorschriften entspricht. Eine selbstsichere Antwort ist keine geprüfte, und Ihr Steuerberater ist es.

*Der sichere Ablauf*

1. Bitten Sie das Werkzeug um einen Entwurf. Geben Sie ihm ein Szenario, nicht die Namen Ihrer Mitglieder oder andere personenbezogene Daten.
2. Fügen Sie den Entwurf in das Feld ein, im **Berichtseditor** oder in den Einstellungen.
3. Sehen Sie ihn sich in der **Vorschau** mit Beispieldaten an.
4. Schicken Sie den Text mit rechtlicher Wirkung an Ihren Steuerberater und warten Sie die Antwort ab.
5. Probieren Sie den gesamten Ablauf in einem Test-Space aus, bevor Sie den echten nutzen.

> **Achtung** Fügen Sie keinen Token, kein Passwort, keine Bankverbindung und keine personenbezogenen Daten eines Mitglieds in ein externes Werkzeug ein.

*Die eigene Assistentenverbindung von DesKilo*

Die App lässt einen Assistenten wie Claude oder ChatGPT über ein Protokoll namens MCP für ein Mitglied handeln. Sie ist standardmäßig aus und eine Funktion, die Sie einschalten (**MCP-Schnittstelle**, siehe [Ein Funktionsschalter](help:user.features.switch)). Sie ist in Schichten aufgebaut, sodass nicht eine einzelne Person alles öffnen kann.

<p><img src="images/setup-reports-assistants.de.jpg" width="280"></p>

| Schicht | Wer | Was er tut |
|---|---|---|
| Die Installation | Der Betreiber | Schaltet Assistenten für die Installation ein. |
| Der Workspace | Sie, der Inhaber | Schalten die Funktion ein und wählen dann unter [Was Assistenten dürfen](help:user.advanced.assistants-policy), welche Dienste angeboten werden und ob ein Assistent nur eigene Datensätze oder den ganzen Workspace sieht. |
| Die Datenbank | Ein Datenbankadministrator | Genehmigt die Anfrage jeder Person. |
| Das Mitglied | Jedes Mitglied | Bittet einmal um Genehmigung und wählt diesen Workspace. |
| Eine Anfrage mit Auswirkung | Das Mitglied, auf seinem Gerät | Bestätigt die genaue Anfrage, die weiterhin Ihren Validierungsregeln folgt. |

Der Assistent eines Mitglieds arbeitet mit den eigenen Datensätzen dieses Mitglieds: freie Plätze finden und beschreiben, Favoriten und Bewertungen, die eigene Reservierung buchen, ändern oder stornieren, das Löschen einer begonnenen Buchung beantragen, ein- und auschecken, den eigenen Kontoauszug und die Rechnungen lesen sowie die Validierungen auflisten und beantworten, um die man gebeten wird. Einige Anfragen (Rechnung ausstellen, Rechnung stornieren, Erstattung, Statusänderung eines Mitglieds, Abo-Anteil) sind nur für Mitarbeitende: Sie brauchen Mitarbeiterrechte, die Bestätigung der Person in der App und danach Ihre Validierungsregeln. Es gibt keine Operation, die einen Space konfiguriert: Ein Assistent kann keine Funktion einschalten, keinen Tarif festlegen, keine Rolle ändern und keinen Plan zeichnen. Er kann Ihren Space nicht für Sie einrichten und handelt nur im Rahmen dessen, was Sie freigeben.

**Gut zu wissen**

- Assistenten einzuschalten gewährt von sich aus niemandem etwas.
- Jede Genehmigung läuft ab; der Bildschirm sagt, wie viele Tage bleiben.
- Lesen Sie die Schritte unter [Genehmigungen und Bestätigungen für Assistenten](help:user.advanced.assistants-approve).

**Siehe auch:** [Assistenten: was sie sind](help:user.advanced.assistants) · [Einen Assistenten verbinden](help:user.advanced.assistants-connect)

<!-- anchor: setup.reports.developer -->
### Mit einer Entwicklerin oder einem Entwickler arbeiten: die Layoutdatei und das Berichtswerkzeug

**Zielgruppe:** Inhaber · Betreiber:in

Jemand Technisches hilft Ihnen, und ein Layout muss außerhalb der App bearbeitet oder nachgewiesen werden.

**Schritte**

1. Schreiben Sie im [Berichtseditor](app:/report-editor) mit **Diese Vorlage exportieren** das Layout in eine einzelne Datei. Die Datei erklärt, was ihre Felder bedeuten und welche Platzhalter es gibt. **Vorlage importieren** liest sie wieder ein; eine Datei für einen anderen Bericht oder aus einer neueren Version wird mit Begründung abgelehnt.
2. Ein Entwickler kann das Layout in einem Terminal mit dem Berichtswerkzeug prüfen, das im Handbuch für technische Administratoren beschrieben ist: `check` misst ein Layout gegen den Fensterumschlag-Vertrag und endet mit einem Fehlercode, wenn Tinte im Fenster landet; `render` erzeugt das PDF; `sample` schreibt eine Datendatei mit jedem Platzhalter; `describe` listet das Vokabular auf.
3. Importieren Sie die Datei zurück in der App, sehen Sie sie mit der **Schnellvorschau** an und tippen Sie auf **Speichern**.

**Gut zu wissen**

- Der Layout-Austausch ist eine Funktion (**Berichtsvorlagen exportieren und importieren**) unter den Berichtsfunktionen in [Funktionen](app:/features). Schalten Sie sie zuerst ein.
- Das Werkzeug braucht den Quellcode der App; es ist für die Person gedacht, die Ihre Installation betreibt, nicht für den täglichen Gebrauch.

**Siehe auch:** [Der Berichtseditor](help:user.money.reports.editor) · [Die PDF-Vorlage der Rechnung](help:user.money.reports.invoice-template)
