<!-- anchor: setup.money.overview -->
## Geld und Steuern

Für Inhaber und Abrechnungsadministratoren, die entscheiden wollen, wie ein Space bezahlt wird. Dieses Kapitel behandelt die Entscheidungen und ihre Reihenfolge; die einzelnen Klicks stehen im Benutzerhandbuch, und jeder Abschnitt verweist dorthin.

> **Achtung** DesKilo erfasst, berechnet und druckt, was Sie angeben, und prüft, ob die erforderlichen Angaben vorhanden sind. Es bescheinigt weder Ihre Rechnungen noch Ihre umsatzsteuerliche Behandlung noch Ihre Buchführung. Wo dieses Kapitel „fragen Sie Ihren Steuerberater“ sagt, tun Sie das bitte.

In diesem Kapitel:
- Ob Mitglieder überhaupt zahlen und wer die Rechnungen ausstellt
- Wie ein Tarif aufgebaut ist, mit Zahlen aus dem Demo-Space *Atelier du Marché*
- Wie Mitglieder Sie bezahlen
- Ihre rechtliche Identität und die Fragen für Ihren Steuerberater
- Rechnungen von Hand oder automatisch, Mahnungen und Umsatzsteuer im Überblick
- Die Geldentscheidungen, die sich nicht mehr zurücknehmen lassen, und wie Sie gefahrlos üben

<!-- anchor: setup.money.decide -->
### Zuerst entscheiden: Zahlen die Mitglieder, und wer stellt die Rechnungen aus?

**Zielgruppe:** Inhaber

Sie legen fest, wie weit DesKilo in Ihre Finanzen hineinreicht. Alles Weitere in diesem Kapitel folgt aus dieser einen Wahl. Sie lässt sich später leicht ausbauen, aber schwer zurückbauen, sobald Rechnungen existieren.

<p><img src="images/setup-money-paths.de.jpg" width="280"></p>

**Bevor Sie beginnen**

Beantworten Sie zwei Fragen: Zahlen Ihnen die Mitglieder etwas für den Space, und sollen die rechtsgültigen Rechnungen aus DesKilo kommen?

| Weg | Wählen Sie ihn, wenn | Was geschieht |
|---|---|---|
| 1. Kein Geld | Der Space ist kostenlos, oder die Mitglieder sind Freunde, die die Miete außerhalb der App teilen | Sie lassen die Geldfunktionen aus. Mitglieder buchen; niemand wird abgerechnet. |
| 2. Kontoauszüge und Zahlungen, Rechnungen außerhalb | Sie haben schon einen Steuerberater oder ein Rechnungsprogramm, oder Sie arbeiten in einem Land, für das DesKilo keine Rechnungen ausstellen kann | Mitglieder haben einen Monatsauszug, Sie erfassen die eingegangenen Zahlungen und exportieren die Zahlen für Ihren Steuerberater. Die rechtsgültigen Rechnungen entstehen anderswo. |
| 3. Rechnungen von DesKilo | Sie sind in Frankreich oder Deutschland und entweder umsatzsteuerpflichtig oder nicht steuerbar (zum Beispiel als Verein) | DesKilo erzeugt aus den Buchungen signierte, fortlaufend nummerierte Rechnungen, auf denen Ihre rechtliche Identität steht. |

**Schritte**

1. Wählen Sie Ihren Weg aus der Tabelle.
2. Schalten Sie bei Weg 2 oder 3 die benötigten Geldfunktionen unter [Funktionen](help:user.features.switch) ein: **Rechnungen** ist die Grundlage für alles, was ausgestellt wird; die Funktionen darunter (**Abo-Rechnungen**, **Monatsabschluss-Rechnungen**, **Mahnwesen**, **USt-Verwaltung**) kommen einzeln dazu.
3. Fahren Sie bei Weg 3 mit [Ihrer rechtlichen Identität](help:setup.money.identity) fort, und zwar vor der ersten Buchung, nicht danach.

**Gut zu wissen**

- Rechnungen in der App auszustellen ist heute für einen Workspace in **Frankreich** oder **Deutschland** möglich. In jedem anderen Land nehmen Sie Weg 2; die Kontoauszüge bleiben verfügbar.
- Der Server verweigert die Ausstellung, wenn eine Angabe fehlt oder wenn die Behandlung eine ist, die DesKilo nicht abdeckt; die Liste **Vor der Ausstellung bitte ergänzen** nennt den Grund. Grenzüberschreitende Umsätze, Reverse-Charge, Ausfuhren und umsatzsteuerfreie Rechnungen müssen Sie mit Ihrem Steuerberater prüfen und außerhalb der App ausstellen.
- Wer unter die Kleinunternehmerregelung fällt (§ 19 UStG; in Frankreich „franchise en base“), kann in der App keine Rechnungen ausstellen: Der Server lehnt die Steuerkategorie „steuerfrei“ ab. Bleiben Sie bei Weg 2 und stellen Sie diese Rechnungen anderswo aus.
- Eine Funktion auszuschalten stoppt neue Vorgänge dieser Art; gelöscht wird nichts.
- Sie können dauerhaft bei Weg 2 bleiben. Viele Vereine tun das.

**Ergebnis**

Sie wissen, welcher der drei Wege Ihrer ist und welche Funktionen er braucht.

**Siehe auch:** [Rechnungsstellung im Überblick](help:user.money.invoicing) · [Ganze Prozesse ein- oder ausschalten](help:user.features.processes)

<!-- anchor: setup.money.tariff -->
### Einen Tarif entwerfen

**Zielgruppe:** Inhaber · Abrechnungsadministrator:in

Sie verwandeln die Frage „Was ist ein Platz wert?“ in Zahlen, die DesKilo jeden Monat ohne Ihr Zutun anwendet.

<p><img src="images/setup-money-bands--bands.de.jpg" width="280"></p>

**Bevor Sie beginnen**

Behalten Sie das Modell im Kopf. Es liest sich von links nach rechts, und jeder Schritt speist den nächsten:

1. Abo-Anteil in Prozent: Ein Mitglied hält einen Anteil am Monat: 25, 50, 75 oder 100 %, oder einen Wert, den Sie zulassen.
2. Halbtage-Kontingent: Der Anteil wird zu einer Anzahl Halbtage für den Monat: Zahl der Öffnungstage mal zwei mal Prozentsatz, aufgerundet.
3. Gebührenband: Der Prozentsatz fällt in genau ein Band, das die Monatsgebühr und den Preis für einen zusätzlichen Halbtag festlegt. Ein Band gilt „über seinem Anfang, bis einschließlich seines Endes“, und die Bänder zusammen müssen 0 bis 100 % ohne Lücke abdecken.
4. Regel bei Überschreitung: Ist das Kontingent aufgebraucht, wird jedes Mitglied entweder gesperrt, mit dem Preis für die Überschreitung belastet oder gebeten, ein Paket zu kaufen.
5. Pakete und Leistungen: Ein Tagespaket verkauft zusätzliche Halbtage im Voraus zu einem Preis, den Sie festlegen; Leistungen (ein Kaffee, ein Schließfach, Drucken) werden obendrauf verkauft.

**Schritte**

1. Legen Sie unter **Abo-Stufen** fest, welche Prozentsätze Sie anbieten und ob ein Inhaber einen ausgehandelten Wert eintragen darf (siehe [Abo-Stufen](help:user.money.billing.levels)).
2. Legen Sie unter **Gebührenbänder** pro Bereich eine Zeile an: die Obergrenze, die Monatsgebühr und den Preis bei Überschreitung (siehe [Gebührenbänder](help:user.money.billing.fee-bands)).
3. Bestimmen Sie die Standardregel für Mitglieder, deren Tage aufgebraucht sind: [Wenn die Tage aufgebraucht sind](help:user.members.overage-policy).
4. Ergänzen Sie die [Tagespakete](help:user.money.billing.packages) und [Leistungen](help:user.money.services.overview), die Sie verkaufen.

**Gut zu wissen**

- Die Rechenweise wird auf jedem ausgestellten Dokument eingefroren. Ein geänderter Preis gilt ab dem nächsten Monat, nie für einen bereits abgerechneten.
- Öffnungszeiten und Schließtage bestimmen, wie viele Öffnungstage ein Monat hat, und damit die Größe des Kontingents. Legen Sie sie zuerst fest.
- Ein Mitglied ohne Abo ist für Besucher gedacht, die Zehnerkarten kaufen; sie können nicht nach Verbrauch abgerechnet werden.

**Siehe auch:** [Abrechnung](help:user.money.billing.fee-bands) · [Das Abo eines Mitglieds](help:user.members.subscription)

<!-- anchor: setup.money.example -->
### Ein durchgerechnetes Beispiel

**Zielgruppe:** Inhaber · Abrechnungsadministrator:in

Sie begleiten ein Mitglied durch einen Monat, mit den Zahlen des *Atelier du Marché*, damit Sie Ihre eigenen Zahlen auf dieselbe Weise prüfen können.

<p><img src="images/setup-money-packages--packages.de.jpg" width="280"></p>

**Bevor Sie beginnen**

Der Demo-Space hat drei Gebührenbänder, in Euro und inklusive Umsatzsteuer. Die Zahlen stammen aus der Demo und sind keine Empfehlung.

| Band | Monatsgebühr | Zusätzlicher Halbtag | Halbtage in einem Monat mit 22 Öffnungstagen |
|---|---|---|---|
| bis 25 % | 0,00 | 15,00 | 11 |
| über 25 %, bis 50 % | 150,00 | 8,00 | 22 |
| über 50 %, bis 100 % | 250,00 | 0,00 | 44 (bei 100 %) |

**Schritte**

1. Ein Mitglied hält 50 %. In einem Monat mit 22 Öffnungstagen beträgt das Kontingent 22 × 2 × 50 / 100 = 22 Halbtage.
2. 50 % fallen in das zweite Band (über 25, bis 50): Die Gebühr beträgt 150,00, egal wie viel das Mitglied nutzt.
3. Das Mitglied bucht 24 Halbtage. Zwei liegen über dem Kontingent, je 8,00: macht 16,00.
4. Der Monat kostet 150,00 + 16,00 = 166,00, vor etwaigen Leistungen. In der Demo sind die Preise Bruttopreise: Die 20 % Umsatzsteuer sind enthalten, und der Bildschirm zeigt sie unter jedem Preis an.
5. Vergleichen Sie mit einem Paket: Das 5-Tage-Paket der Demo kostet 40,00 und bringt 10 Halbtage (5 Tage, je zwei Halbtage), also 4,00 pro Halbtag. Gegenüber 8,00 bei Überschreitung lohnt es sich ab dem sechsten zusätzlichen Halbtag im Monat.

**Gut zu wissen**

- Ein Preis von 0,00 bei Überschreitung bedeutet: Zusätzliche Halbtage kosten bei Abrechnung nach Verbrauch nichts.
- Der Kontoauszug, den ein Mitglied sieht, zeigt dieselben Zeilen: Gebühr, enthalten, genutzt, zusätzlich, Überschreitung.
- Preise werden inklusive Umsatzsteuer angezeigt, wenn die Umsatzsteuer aktiv ist; die Steuer wird daraus herausgerechnet.
- Wenn Sie mit einem Mitglied andere Bedingungen vereinbaren, lesen Sie [Preisverhandlung](help:setup.money.negotiation).

**Ergebnis**

Sie können die Rechnung eines Mitglieds aus drei Zahlen vorhersagen: seinem Prozentsatz, den Öffnungstagen und den Buchungen.

**Siehe auch:** [Ihren Kontoauszug lesen](help:user.money.statement) · [Was jede Buchung gekostet hat](help:user.money.usage)

<!-- anchor: setup.money.negotiation -->
### Preisverhandlung

**Zielgruppe:** Inhaber · Abrechnungsadministrator:in

Sie möchten, dass ein Mitglied andere Bedingungen als im Tarif bekommt, und zwar nachvollziehbar.

**Schritte**

1. Schalten Sie die Funktion Preisverhandlung unter [Funktionen](help:user.features.switch) ein.
2. Schlagen Sie auf der Mitgliedsseite Bedingungen vor: eine andere Monatsgebühr, einen anderen Satz bei Überschreitung, einen Nachlass auf Zusatzleistungen, Stückpreise oder einen Belegungsanteil (siehe [Preisverhandlung](help:user.members.negotiation)).
3. Lassen Sie die Validierungsregel für Preisverhandlungen entscheiden, wer sie bestätigt.

**Gut zu wissen**

- Der Tarif bleibt der Standard; ein ausgehandelter Preis gehört zu genau einem Mitglied.
- Ihn sehen das Mitglied, die Inhaber und die Personen mit dem Recht, Geschäftsvereinbarungen einzusehen; jeder Lesezugriff wird protokolliert.
- Legen Sie Ihre Linie fest, bevor Sie anfangen: Eine Ausnahme, die stillschweigend gewährt wird, wird schnell zum Preis, den alle verlangen.

**Siehe auch:** [Ihre ausgehandelten Preise](help:user.money.negotiation)

<!-- anchor: setup.money.pay -->
### Wie Mitglieder Sie bezahlen

**Zielgruppe:** Inhaber · Abrechnungsadministrator:in

Sie bestimmen, wohin das Geld eines Mitglieds fließt und wie viel Arbeit DesKilo Ihnen dabei abnimmt.

<p><img src="images/setup-money-payment-instructions.de.jpg" width="280"></p>

**Schritte**

1. Beginnen Sie mit dem kostenlosen Weg: Tragen Sie die [Zahlungsanweisungen](help:user.money.payments.methods) ein, also Ihre IBAN und Bankverbindung sowie, was Sie akzeptieren, PayPal.me, Wero, Lydia oder Wise, dazu einen Hinweis zum Verwendungszweck.
2. Mitglieder sehen diese Angaben auf einem unbezahlten Kontoauszug. Wenn eine Zahlung auf Ihrem Konto eingeht, [erfassen](help:user.money.payments.record) Sie oder ein Abrechnungsadministrator sie.
3. Nur wenn Mitglieder in der App bezahlen sollen, verbinden Sie unter [Online-Zahlungen](help:user.money.payments.provider) einen Anbieter: PayPal, Stripe oder Mollie. Dafür brauchen Sie die Funktion **Online-Zahlungen** und ein eigenes Konto beim Anbieter.

**Gut zu wissen**

- DesKilo erfasst Zahlungen; auf dem manuellen Weg bewegt es nie Geld.
- Ein Anbieter berechnet eigene Gebühren und erhält die Schlüssel Ihres Kontos (das Blatt für die Zugangsdaten erklärt, wie sie eingegeben werden).
- Ist **Online-Zahlungen** aus, wird eine neue Online-Zahlung abgelehnt; eine bereits offene kann noch abgeschlossen werden.
- Ein Space, der aus einer Vorlage entsteht, übernimmt keine Zahlungsangaben: Tragen Sie sie in jedem Space ein. Ein Konfigurationsexport enthält sie dagegen.

**Siehe auch:** [Bezahlen, was Sie schulden](help:user.money.payments) · [Zugangsdaten des Anbieters](help:user.money.payments.credentials)

<!-- anchor: setup.money.identity -->
### Ihre rechtliche Identität, und was Sie Ihren Steuerberater fragen

**Zielgruppe:** Inhaber

Sie teilen DesKilo mit, wer verkauft, damit jede Rechnung Sie korrekt benennt. Das ist der Teil, den Sie mit einem Fachmann klären sollten.

<p><img src="images/setup-money-legal--top.de.jpg" width="280"></p>

**Bevor Sie beginnen**

Der Bildschirm heißt [Rechtliche Identität & E-Rechnung](app:/legal-identity). Halten Sie bereit:

- Ihre Organisationsform: Unternehmen oder gemeinnütziger Verein;
- Ihr Steuerregime: nicht der Umsatzsteuer unterliegend, umsatzsteuerfrei (Kleinunternehmerregelung) oder umsatzsteuerpflichtig. Die App kann nur für den ersten und den letzten Fall Rechnungen ausstellen; bei der Kleinunternehmerregelung hält der Bildschirm Ihren Status fest, die Rechnungen müssen aber anderswo ausgestellt werden (Weg 2);
- Ihre Registernummer und, falls vorhanden, Ihre Umsatzsteuer-Identifikationsnummer;
- Ihre Postanschrift, wie sie in Ihrer Eintragung steht;
- den Grund, warum keine Umsatzsteuer berechnet wird, falls Sie keine berechnen.

> **Achtung** Das Steuerregime zu wählen ist eine steuerliche Entscheidung, keine Software-Einstellung. Ein Verein ohne wirtschaftliche Tätigkeit liegt normalerweise außerhalb der Umsatzsteuer, und der Bildschirm warnt Sie, wenn Sie für ihn „steuerfrei“ wählen. Bestätigen Sie die Wahl, bevor Sie die erste Rechnung ausstellen.

**Schritte**

1. Öffnen Sie [Rechtliche Identität & E-Rechnung](app:/legal-identity) und arbeiten Sie von oben nach unten: zuerst das **Steuerregime**, dann die Kennungen, die Adresse und die **Rechnungsangaben**.
2. Tragen Sie die Zahlungsbedingungen, die Hinweise zum Zahlungsverzug und die weiteren Angaben ein, die Ihr Land verlangt (siehe [Ihre rechtliche Identität](help:user.money.legal.identity)).
3. Tippen Sie auf **Speichern** und lesen Sie die Rechnungsvorlage einmal gemeinsam mit Ihrem Steuerberater durch (siehe [Die PDF-Vorlage der Rechnung](help:user.money.reports.invoice-template)).

> **Tipp** Fragen für Ihren Steuerberater:
>
> 1. Welche Organisationsform und welches Steuerregime habe ich?
> 2. Wie lauten meine Registernummer und meine Umsatzsteuer-Identifikationsnummer, und wie schreibe ich sie?
> 3. Wenn ich keine Umsatzsteuer berechne: Mit welchem Gesetzestext begründe ich das?
> 4. Welche Angaben müssen auf meinen Rechnungen stehen (Zahlungsziel, Verzugszinsen, Einziehungspauschale, Skonto, Versicherung)?
> 5. Wie sind Rechnungen zu nummerieren, und beginnt die Nummer jedes Jahr oder jeden Monat neu?
> 6. Wann entsteht die Umsatzsteuer auf meine Leistungen nach der Regel meines Landes (Zahlung, Leistungsmonat, Rechnung), und soll ich eine andere Grundlage wählen, etwa die Ist-Versteuerung?
> 7. Muss ich E-Rechnungen an eine staatliche Plattform senden, und an welche?
> 8. Brauche ich regelmäßige Umsatzsteuer-Voranmeldungen, und wie oft?

**Gut zu wissen**

- Bereits ausgestellte Rechnungen behalten die Identität, mit der sie signiert wurden; eine Änderung gilt für die nächsten.
- Nur ein Inhaber oder ein aktiver Mitinhaber kann diesen Bildschirm öffnen, und die Funktion **Rechnungen** muss eingeschaltet sein.
- Ein Space, der aus einer Vorlage entsteht, übernimmt Ihre Identität nicht: Tragen Sie sie neu ein. Ein Deployment zwischen den beiden Seiten eines Paars übernimmt sie.

**Siehe auch:** [Steuerregime](help:user.money.vat.regime) · [Die E-Rechnungs-Plattform](help:user.money.einvoice.overview) · [Art der Organisation](help:user.money.legal.seller-kind)

<!-- anchor: setup.money.invoicing -->
### Rechnungen von Hand oder automatisch

**Zielgruppe:** Inhaber · Abrechnungsadministrator:in

Sie entscheiden, ob jemand jeden Monat die Knöpfe drückt oder DesKilo das übernimmt.


**Schritte**

1. Arbeiten Sie im ersten Monat von Hand: Öffnen Sie [Rechnungsstellung](app:/invoices), lesen Sie **Auszustellen** und stellen Sie die Rechnung eines Mitglieds aus (siehe [Eine Rechnung ausstellen](help:user.invoicing.new-invoice)).
2. Für den Alltag nutzen Sie den [Monatsabschluss-Assistenten](help:user.invoicing.wizard): Er führt durch **Prüfen**, **Ausstellen**, **Senden**, **Mahnen**, **Zahlungen**, **Zuordnen**, **Abschließen** und **Zusammenfassung**.
3. Zum Automatisieren schalten Sie **Abo-Rechnungen** und **Monatsabschluss-Rechnungen** unter [Funktionen](help:user.features.switch) ein und legen die Tage im [Rechnungsplan](help:user.money.billing.schedule) fest.

**Gut zu wissen**

- Pro Monat gibt es zwei Dokumente: die Abogebühr, die vor dem Monat ausgestellt wird, und das, was der Monat tatsächlich gekostet hat, ausgestellt danach. Eine Rechnung kann einige Tage vordatiert sein (standardmäßig drei, einstellbar im Rechnungsplan); eine Rechnung vom 29. August kann also den September betreffen.
- Auf dem Server stellt ein täglicher Lauf beide aus, wenn die Datenbank der Installation ihren Scheduler aktiviert hat; fragen Sie im Zweifel den Betreiber.
- Jede Rechnungsart (Abo, Monatsabschluss) kann pro Mitglied und Monat einmal ausgestellt werden. Rechnungen lassen sich weder bearbeiten noch löschen; eine falsche wird als fehlerhaft markiert und ersetzt.
- Standardmäßig stellen der Inhaber und die Mitinhaber Rechnungen aus. **Admins stellen Rechnungen aus** erweitert das auf die Administratoren.

**Siehe auch:** [Der Bildschirm Rechnungsstellung](help:user.invoicing.hub) · [Offene Rechnungen nachfassen und abschließen](help:user.invoicing.open)

<!-- anchor: setup.money.reminders -->
### Zahlungserinnerungen

**Zielgruppe:** Inhaber · Abrechnungsadministrator:in

Sie bestimmen, ab wann eine Zahlung überfällig ist und wer nachfasst.

<p><img src="images/setup-money-reminders.de.jpg" width="280"></p>

**Schritte**

1. Schalten Sie **Mahnwesen** unter [Funktionen](help:user.features.switch) ein. Es liegt unter **Rechnungen**.
2. Legen Sie in den [Mahnregeln](help:user.money.reminders.rules) die Zahl der Stufen und die Fristen fest: Tage bis zur ersten Mahnung, Tage zwischen den Mahnungen.
3. Entscheiden Sie, ob Mahnungen von selbst hinausgehen: Schalten Sie im selben Dialog **Automatische Mahnungen** ein (siehe [Automatische Mahnungen](help:user.money.reminders.automatic)); auch die Funktion **Automatische Zahlungserinnerungen** muss eingeschaltet sein.

**Gut zu wissen**

- Die Frist bis zur ersten Mahnung gilt zugleich als Ihr Zahlungsziel. Legen Sie es mit den [Zahlungsbedingungen](help:user.money.legal.payment-terms) fest.
- Automatische Mahnungen laufen einmal täglich auf dem Server, wenn die Datenbank ihren Scheduler aktiviert hat. Sie laufen auch, wenn jemand mit dem Recht, Rechnungen auszustellen (ein Inhaber, ein Mitinhaber oder, wenn **Admins stellen Rechnungen aus** an ist, ein Administrator), die Finanzen öffnet; ein Space ohne Scheduler bekommt sie also an den Tagen, an denen jemand hinsieht. Der Schalter und die Funktionsbeschreibung sagen es ebenfalls; der Betreiber Ihres Servers weiß, was zutrifft.
- Die Funktion **Mahnwesen** stellt nur die Regeln bereit. Eine Mahnung geht erst dann von selbst hinaus, wenn **Automatische Mahnungen** in den Mahnregeln eingeschaltet ist; das ist zunächst aus, bis Sie es wählen.
- Übersprungen werden Rechnungen mit ausstehender oder angehaltener Zahlung und Rechnungen ohne erfasstes Zahlungsziel.
- Das Mitglied erhält einen Hinweis in seinem Feed und, wenn Push eingerichtet ist, eine allgemein gehaltene Benachrichtigung; siehe [Menschen informieren](help:setup.notify.overview).

**Siehe auch:** [Zahlungsbedingungen](help:user.money.legal.payment-terms)

<!-- anchor: setup.money.vat -->
### Umsatzsteuer im Überblick

**Zielgruppe:** Inhaber · Abrechnungsadministrator:in

Sie möchten wissen, was die Umsatzsteuer von Ihnen verlangt, bevor Sie sie einschalten.

<p><img src="images/setup-money-vat--rates.de.jpg" width="280"></p>

**Schritte**

1. Schalten Sie **USt-Verwaltung** unter [Funktionen](help:user.features.switch) nur ein, wenn Sie umsatzsteuerpflichtig sind.
2. Legen Sie die Sätze unter [USt](app:/vat) fest: **Übliche Sätze übernehmen** für Ihr Land, dann genau einen davon als Standard markieren (siehe [Die Sätze festlegen](help:user.money.vat.rates)).
3. Ordnen Sie jedem Satz seine Gruppe zu, und wo es zutrifft, einen Befreiungsgrund (siehe [USt-Gruppen](help:user.money.vat.groups)).
4. Ändert das Gesetz einen Satz, verwenden Sie **Änderung per Gesetz**, damit ältere Rechnungen ihren Satz behalten (siehe [Einen Satz per Gesetz ändern](help:user.money.vat.change-by-law)).
5. Müssen Sie Erklärungen abgeben, schalten Sie **USt-Voranmeldungen** ein und bereiten Sie jeden Zeitraum unter [USt-Voranmeldung](help:user.money.vat.declaration) vor.

**Gut zu wissen**

- Ein Katalog der Sätze liegt für die EU-Mitgliedstaaten, die Schweiz, Norwegen und Kanada bei. Ihn aktuell zu halten, wenn ein Staat einen Satz ändert, ist Ihre Aufgabe.
- Wer umsatzsteuerpflichtig ist, aber keinen gültigen Standardsatz hat, dem verweigert der Server die Ausstellung. Die Beschreibung von **USt-Verwaltung** und die Warnung auf dem Bildschirm der rechtlichen Identität sagen es.
- Der Server berechnet jede Voranmeldung aus Ihren Rechnungen, Zahlungseingängen und Steuerzeitpunkten. Geben Sie sie selbst beim Finanzamt ab und markieren Sie sie dann mit der Referenz der Eingangsbestätigung als abgegeben: Die App übermittelt nichts.
- Das Journal der Voranmeldungen hat einen eigenen Nummernkreis.

**Siehe auch:** [Steuerregime](help:user.money.vat.regime) · [Wann die Umsatzsteuer fällig wird](help:user.money.vat.due)

<!-- anchor: setup.money.permanent -->
### Was sich nicht rückgängig machen lässt

**Zielgruppe:** Inhaber

Sie möchten vor der ersten Rechnung wissen, was Sie danach nicht mehr ändern können.

<p><img src="images/setup-money-numbering.de.jpg" width="280"></p>

> **Achtung** Ab der ersten ausgestellten Rechnung ist das Folgende endgültig. Entscheiden Sie es vorher mit Ihrem Steuerberater.

| Entscheidung | Was endgültig wird | Wann |
|---|---|---|
| Eine ausgestellte Rechnung | Sie ist signiert und unveränderlich: Beträge, Beteiligte, Steueraufschlüsselung und Tarifberechnung bleiben, wie gedruckt. Eine Korrektur ist eine Stornierung, eine Gutschrift oder eine Erstattung, jeweils ein neues Dokument. | Bei der Ausstellung |
| Rechnungsnummer | Nummern sind lückenlos und werden im Moment der Ausstellung in der Datenbank vergeben. Die nächste Nummer lässt sich erhöhen, nie senken. Ein neues Format gilt ab dann. Ein Neubeginn der Zählung darf nicht häufiger sein als das Datum, das die Nummer druckt. | Bei der ersten Ausstellung |
| Ein abgerechneter Monat | Ein Monat, für den ein Mitglied eine Rechnung hat, ist für dieses Mitglied abgeschlossen. Schließtage und Feiertagsimporte überspringen solche Monate und nennen sie. | Bei der ersten Rechnung dafür |
| Umsatzsteuersätze | Sätze werden nach Datum versioniert und nie bearbeitet. Eine eingereichte Voranmeldung wird nie neu berechnet. | Bei der ersten Verwendung |
| Währung und Land | Beträge werden als ganze kleinste Einheiten ohne Umrechnung gespeichert. Sobald der Space ein Dokument ausgestellt oder Geld erfasst hat, lehnt der Server jede Änderung von beiden ab. | Beim ersten Dokument oder der ersten Zahlung |

**Schritte**

1. Öffnen Sie [Nummernkreise](app:/settings/number-sequences) und legen Sie für jedes Journal (Rechnungen, Gutschriften, Voranmeldungen, Mitglieder, Zahlungen) Präfix, Suffix, Datumsteil, Stellenzahl und Neubeginn fest. Der Bildschirm braucht die Funktion **Nummernkreise**.
2. Zeigen Sie das Ergebnis Ihrem Steuerberater vor der ersten Rechnung.
3. Wählen Sie Land, Währung und Zeitzone in den [Workspace-Einstellungen](help:user.workspace.settings.country), bevor irgendjemand bucht.

**Gut zu wissen**

- Nummern gehen nicht verloren: Ein Dokument, dessen Ausstellung scheitert, verbraucht keine.
- Die zwei Zustände eines Space, Test und Produktion, gibt es, damit nichts hiervon ernsthaft ausprobiert wird; siehe [einen gefahrlosen Probelauf](help:setup.money.dry-run).

**Siehe auch:** [Das Rechnungsregister](help:user.invoicing.register) · [Währung und Zeitzone](help:user.workspace.settings.currency-timezone)

<!-- anchor: setup.money.dry-run -->
### Ein gefahrloser Probelauf in einem Test-Space

**Zielgruppe:** Inhaber

Sie üben die gesamte Geldroutine einmal durch, ohne dass etwas Echtes auf dem Spiel steht.

**Schritte**

1. Erstellen oder öffnen Sie einen Test-Workspace (**Ein Test-Arbeitsbereich** oder die DEV-Seite eines verbundenen Paars); siehe [Test-Space](help:user.advanced.test-space) und [Umgebungen](help:user.advanced.environments).
2. Tragen Sie die rechtliche Identität, die Sätze, den Tarif und die Zahlungsanweisungen so ein, wie Sie sie betreiben wollen.
3. Laden Sie zwei oder drei Personen ein, einige Tage zu buchen; fügen Sie für eine davon eine Leistung hinzu.
4. Führen Sie den [Monatsabschluss-Assistenten](help:user.invoicing.wizard) von Anfang bis Ende durch und lesen Sie das Rechnungs-PDF.
5. Erfassen Sie eine Zahlung, lassen Sie eine Mahnung fällig werden und lesen Sie den Kontoauszug aus Sicht des Mitglieds.
6. Zeigen Sie die PDFs und den Buchhaltungsexport Ihrem Steuerberater.

**Gut zu wissen**

- Ein Test-Space versieht jedes Dokument mit einem Wasserzeichen und weist es als Test aus; geschuldet wird nichts.
- Wer einen Space zur Produktion erklärt, entfernt das Wasserzeichen; bereits ausgestellte Rechnungen behalten es.
- Das Paar kann die Konfiguration von einer Seite auf die andere übertragen, Zugangsdaten reisen aber nicht mit.

**Ergebnis**

Ein erster Monat, den Sie schon gesehen haben, und eine Liste von Fragen, die beantwortet sind, bevor sie etwas kosten.

**Siehe auch:** [Die zwei Umgebungen](help:user.advanced.environments) · [Buchhaltungsexporte](help:user.invoicing.accounting-export)
