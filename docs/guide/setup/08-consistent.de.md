<!-- anchor: setup.consistent.overview -->
## Stimmig bleiben

Ein Space kann auf zwei Arten falsch sein: durch eine fehlende Einstellung und durch zwei Einstellungen, die sich widersprechen. DesKilo fängt manches von beidem ab und sagt es auf dem Bildschirm. Dieses Kapitel listet auf, was erkannt wird und wo Sie es sehen, sagt offen, was nicht erkannt wird, und gibt Ihnen eine Prüfung für die Zeit vor der Eröffnung sowie eine kurze Routine für jeden Monat.

In diesem Kapitel:
- [Die Schutzmechanismen der App](help:setup.consistent.guards)
- [Die Fehler, die die Schutzmechanismen nicht erkennen](help:setup.consistent.gaps)
- [Die Prüfung vor dem Start](help:setup.consistent.audit)
- [Die Monatsroutine](help:setup.consistent.monthly)
- [Wenn etwas falsch aussieht](help:setup.consistent.wrong)
- [Was sich nicht rückgängig machen lässt](help:setup.consistent.irreversible)

Das durchgehende Beispiel ist das *Atelier du Marché*. Seine Inhaberin Ada führt die Prüfung einmal in einem Test-Space durch und noch einmal im echten.

<!-- anchor: setup.consistent.guards -->
### Die Schutzmechanismen der App

**Zielgruppe:** Inhaber · Mitinhaber · Administrator:in · Abrechnungsadministrator:in

Sie möchten wissen, auf welche Ihrer Fehler die App hinweist und wo sie es tut, damit Sie am richtigen Ort nachsehen.

<p><img src="images/setup-consistent-features-attention.de.jpg" width="280"></p>

| Schutz | Was er erkennt | Wo Sie es sehen |
|---|---|---|
| Eine Funktion, die eine andere braucht | Eine Funktion kann ohne die, die sie braucht, nicht arbeiten. Wer eine Funktion einschaltet, schaltet ihre übergeordnete ein und erfährt, was dazugekommen ist. Wer eine übergeordnete ausschaltet, hält die untergeordneten zurück und behält deren eigene Wahl. | **Funktionen**: der Schaltablauf mit Vorschau, **Benötigt** und **Wartet auf die Funktion darüber** |
| Ein zurückgehaltener Prozess | Eine Funktion, die an ist, aber auf etwas wartet, das aus ist. | **Funktionen**, Ansicht **Prozesse**: der Zustand **Braucht Aufmerksamkeit** und sein Filter-Chip |
| Die Bereitschaftsliste | Eine Zeile pro Bereich des Space, mit Zustand, Verantwortlichem und Ort der Einstellung. Bereiche: **Öffnungstage, Zeitzone und Währung**, **Buchbare Plätze im Grundriss**, **Mitgliedschaftsmodelle und Tarife**, **Die ersten Mitglieder einladen**, **Wie Mitglieder bezahlen**, **Rollen und wer Anfragen bestätigt**, **Export und Wiederherstellung**, **Angaben, die Ihre Funktionen brauchen (Identität, Bank, Plattformen)**, **Eine erste Buchung** und, wenn es zutrifft, **Server und Datenbankversion** sowie **Assistentenzugang (optional)** (Letzterer nur bei eingeschalteter MCP-Schnittstelle). | **Einrichtung dieses Workspace**, oben in [Workspace](app:/workspace-settings) |
| Die Zeile, die eine erste Buchung verhindert | Nur das, was eine Buchung wirklich braucht: eine Zeitzone, eine Währung, einen Öffnungstag, einen Platz und, wenn eine Buchungsregel mehr Validierer verlangt, als es gibt, diese Validierer. Der Rest ist optional und lässt sich mit **Später** beiseitelegen. | **Bevor hier jemand buchen kann**, auf der Karte „Erste Schritte“ in [Reservieren](app:/reserve) |
| Was Ihre Funktionen lokal noch brauchen | Rechtliche Identität (für **Rechnungen**), Bankverbindung, ein Anbieter für Online-Zahlungen, ein E-Rechnungs-Konto, ein Standort. | Dieselbe Karte, Bereich **Angaben, die Ihre Funktionen brauchen (Identität, Bank, Plattformen)**, mit **Einrichten** und **Empfohlen** |
| Der Rechnungsschutz | Eine Rechnung wird abgelehnt, bis sie vollständig ist: die Anschrift des Workspace, seine Umsatzsteuer-Identifikationsnummer, ein Land Frankreich oder Deutschland, eine Rechtsgrundlage für eine Befreiung, Name, Anschrift und Umsatzsteuer-Identifikationsnummer des Mitglieds bei Reverse-Charge, ein gültiger Steuersatz, eine Erklärung für jede mit 0 % abgerechnete Zeile. Grenzüberschreitende, Reverse-Charge-, Ausfuhr- und steuerfreie Rechnungen werden abgelehnt: Stellen Sie sie außerhalb der App aus. | **Vor der Ausstellung bitte ergänzen**, mit den fehlenden Punkten |
| Der Schutz bei Online-Zahlungen | Ist **Online-Zahlungen** aus, lehnt der Server eine neue Online-Zahlung ab. Eine bereits offene wird noch abgeschlossen. | Die Zahlungsbildschirme (die Funktionszeile trägt dazu keinen Hinweis) |
| Der Validierungsschutz | **Erforderliche Validierungen** über der Zahl der verfügbaren Personen. | **Nicht genügend berechtigte Validierer.** im Regeleditor; „Eine Regel verlangt mehr Prüfer, als dieser Bereich hat“ in der Bereitschaftsliste |
| Der Schutz der Nummernkreise | Ein Neubeginn, der häufiger ist als das in der Nummer gedruckte Datum, wird abgelehnt. | [Nummernkreise](app:/settings/number-sequences), beim Speichern |
| Die Reifeprüfung | Eine Funktion, die als **Alpha** oder **Beta** eingestuft ist. | Eine Rückfrage, bevor Sie sie einschalten, und ein Abzeichen auf jedem Schalter |
| Die Prüfung beim Ersetzen des Plans | Das Ersetzen des Grundrisses oder der Einstellungen aus einer Datei. | Eine Warnung, dass es sich nicht rückgängig machen lässt. Der Plan wird abgelehnt, sobald Reservierungen existieren |

**Gut zu wissen**

- **Einrichtung dieses Workspace** ist eine Liste, keine Sperre. Sie hindert Sie nie daran, etwas einzuschalten.
- Die meisten Schutzmechanismen greifen, wenn Sie versuchen auszustellen, zu zahlen oder zu buchen, nicht wenn Sie eine Einstellung wählen. Deshalb gibt es die Prüfung unten.
- Der Posteingang des Inhabers ([Was auf Sie wartet](help:user.collaborate.attention)) meldet heute keine Konfigurationsprobleme. Warten Sie nicht darauf.

**Siehe auch:** [Funktionen vermeiden, die sich widersprechen](help:setup.features.consistency) · [Ihren Space prüfen](help:setup.place.check)

<!-- anchor: setup.consistent.gaps -->
### Die Fehler, die die Schutzmechanismen nicht erkennen

**Zielgruppe:** Inhaber · Mitinhaber · Abrechnungsadministrator:in

Sie möchten die ehrliche Liste dessen, was in Ihrer Verantwortung bleibt. Das sind Konfigurationen, die die App Sie anlegen lässt, ohne zu warnen. Für jede gibt es einen Weg, sie von Hand zu vermeiden.

| Fehler | Warum nichts ihn verhindert | Vermeiden Sie ihn durch |
|---|---|---|
| Ein anderes Land als Frankreich oder Deutschland wählen und Rechnungen erwarten | Die App bietet viele Länder und Steuersätze an, stellt aber nur für Frankreich und Deutschland Rechnungen aus. Bei der Länderwahl sagt Ihnen das nichts. | Entscheiden, bevor Sie Mitgliedern eine Rechnung versprechen. Anderswo bleiben die Kontoauszüge in der App, und Rechnungen stellen Sie außerhalb aus. |
| Umsatzsteuerpflichtig sein, ohne dass ein Satz gilt | Die Ausstellung wird abgelehnt, aber erst bei der ersten Rechnung. Ist **USt-Verwaltung** aus, ist die Konfiguration verborgen, die gespeicherten Sätze gelten aber weiter. | Den Satz unter [USt](app:/vat) vor dem ersten Monatsabschluss ergänzen und eine Probe-Rechnung ausstellen. |
| **Online-Zahlungen** an, ohne Anbieter | Sie können es einschalten; der fehlende Anbieter erscheint nur als Punkt in der Bereitschaftsliste. | Zuerst den Anbieter verbinden, dann einschalten. |
| **Rechnungen** an, ohne rechtliche Identität | Die Funktion ist vom ersten Tag an an; die Ablehnung kommt bei der Ausstellung. | Die Identität eintragen, bevor Sie Mitgliedern sagen, dass sie Rechnungen bekommen. |
| Eine Regel, die mehr Validierer braucht, als Sie haben, außerhalb von Buchungen | Die Bereitschaftsliste hält nur bei Reservierungsregeln die erste Buchung auf. Der Editor lässt Sie eine Regel speichern, die über der Zahl der verfügbaren Personen liegt. Andere Anfragen werden angelegt, können nicht abgeschlossen werden und laufen nach sieben Tagen ab. | Nach jeder Regel die aktiven Inhaber und Administratoren zählen. Siehe [Anfragen vermeiden, die ewig warten](help:setup.people.stuck). |
| Mitglieder, die den Plan nicht öffnen können | In einem neuen Space ist die Karte **Benutzer** unter [Rollen](app:/roles) leer, und nichts warnt Sie. | Die alltäglichen Berechtigungen ankreuzen und einmal mit einem zweiten Konto beitreten. |
| Ein Space, der aus einer Vorlage entsteht | Eine Vorlage übernimmt nie die Identität, die Bankverbindung, Standorte oder Einladungen. | Den Bereich **Angaben, die Ihre Funktionen brauchen (Identität, Bank, Plattformen)** als To-do-Liste behandeln. |
| Eine Einstellungsdatei, die mehr verspricht, als sie hält | Heute enthält die Datei die Rollenmatrix, Ihre eigenen Rollen und jede Validierungsregel, nicht aber die Mitglieder, die Rechnungs- und Mitgliedsnummern, den Umsatzsteuerzeitraum oder die Preise des ganzen Space. Was sie enthält, wird nur angewendet, wenn **Konfiguration in der Raumdatei** im Ziel an ist. Ein Plan wird nicht ersetzt, sobald Reservierungen existieren. | Das, was sie nicht enthält, von Hand neu eintragen und die Vorschau lesen, bevor Sie auf **Ersetzen und importieren** tippen. |
| Mahnungen, die nie laufen | Sie laufen jeden Morgen auf dem Server, wenn die Datenbank einen Scheduler (pg_cron) hat; hat sie keinen, laufen sie, wenn ein Administrator die Finanzen öffnet. Sie bleiben auch stumm, wenn **Automatische Zahlungserinnerungen** aus ist. | Den Betreiber fragen, ob es den Scheduler gibt, und selbst die Finanzen öffnen, wenn nicht. Siehe [Automatische Mahnungen](help:user.money.reminders.automatic). |
| Land, Währung oder Zeitzone ändern, sobald Geld im Spiel ist | Ich habe keine Sperre gefunden. Beträge werden als Zahlen gespeichert und nicht umgerechnet: Klären Sie es mit dem Eigentümer der Installation, bevor Sie sich darauf verlassen. | Sie am ersten Tag wählen. Siehe [Schwer rückgängig zu machende Entscheidungen](help:setup.before.permanent). |
| Eine Nummerierung oder ein Umsatzsteuerzeitraum, der nicht zum Format Ihres Steuerberaters passt | Die App vergleicht sie nicht mit dem Buchhaltungsexport des Landes. | Ihren Steuerberater vor der Ausstellung nach dem Nummernformat und dem Export fragen, den er nutzt. Siehe [Buchhaltungsexporte](help:user.invoicing.accounting-export). |
| Einen Test für den echten Space halten | Über das Wasserzeichen auf gedruckten Dokumenten hinaus ist der Unterschied leicht zu übersehen. | Vor dem Handeln auf das Banner des Test-Space und die in [Ich](app:/me) angezeigte Seite achten. |

**Gut zu wissen**

- Ein Kiosk ohne Kiosk-Mitglied, eine Standortfunktion ohne Standort, Push ohne Push-Dienst: [Funktionen vermeiden, die sich widersprechen](help:setup.features.consistency).
- Die App ist bei Rechnungen strenger, als es aussieht, und bei allem anderen lockerer. Stellen Sie im Zweifel in einem Test-Space eine Probe-Rechnung aus.

**Siehe auch:** [Ein gefahrloser Probelauf](help:setup.money.dry-run)

<!-- anchor: setup.consistent.audit -->
### Die Prüfung vor dem Start

**Zielgruppe:** Inhaber · Mitinhaber

Sie wollen einen Beleg, kein Gefühl, bevor Sie öffnen. Einunddreißig Prüfpunkte, in drei Stufen. Führen Sie *Öffnen* durch, bevor Sie jemanden einladen, *Betreiben*, bevor Sie etwas zu Geld versprechen, *Wachsen*, bevor die erste Rechnung hinausgeht. Tun Sie es zuerst in einem Test-Space, mit einer zweiten Person.

*Öffnen: ein Ort, an dem man buchen kann*

| # | Prüfpunkt | Wo | So sieht es richtig aus |
|---|---|---|---|
| 1 | Land, Währung, Zeitzone | [Workspace](app:/workspace-settings), **Allgemeine Angaben** | Atelier du Marché: Frankreich, EUR, Europe/Paris |
| 2 | Sprache des Workspace | Derselbe Bildschirm | Die Sprache, in der Ihre Einladungen geschrieben sind |
| 3 | Öffnungstage und -zeiten | [Verfügbarkeit](app:/availability) | Die Tage, an denen Sie öffnen, sind angekreuzt; die Zeiten passen zum Tag |
| 4 | Schließtage | Verfügbarkeit, Schließtage | Feiertage und Schließungen der nächsten Monate sind eingetragen, vor dem ersten Monatsende |
| 5 | Mindestens ein Platz | [Workspace-Editor](app:/editor) | Jeder Raum, den Sie vermieten, hat Plätze |
| 6 | Bereitschaft | **Einrichtung dieses Workspace** | Unter **Öffnungstage, Zeitzone und Währung** und **Buchbare Plätze im Grundriss** braucht nichts eine Konfiguration |
| 7 | Sie haben einen Platz gebucht | [Reservieren](app:/reserve) | Der Platz wird gebucht, eingecheckt und storniert, ohne Überraschung |
| 8 | Die Workspace-ID | [Workspace-ID & QR](app:/workspace-code) | Die ID lässt sich laut aussprechen; der QR-Code ist gedruckt |
| 9 | Alltägliche Berechtigungen | [Rollen](app:/roles) | **Benutzer** hält die sechs alltäglichen Berechtigungen |
| 10 | Ein zweites Konto ist beigetreten | Ein anderes Gerät | Es wurde genehmigt und konnte den Plan öffnen und buchen |
| 11 | Mehr als eine Person kann handeln | [Mitglieder & Tarife](app:/members) | Ein Inhaber plus ein Mitinhaber oder ein Administrator, alle **Aktiv** |
| 12 | Zahl der Validierungen | [Validierungsregeln](app:/validation) | Keine Regel verlangt mehr Validierer als aktive Inhaber und Administratoren |
| 13 | Die Einladung in jeder Sprache | **Gemeinschaft und Einladungen** | Sie haben jede Version einmal gelesen; kein Platzhalter bleibt unausgefüllt |
| 14 | Die Seite, auf der Sie sind | [Ich](app:/me) | Das Banner des Test-Space wird angezeigt oder nicht, wie beabsichtigt |

*Betreiben: Menschen zahlen und Rollen halten*

| # | Prüfpunkt | Wo | So sieht es richtig aus |
|---|---|---|---|
| 15 | Gebührenbänder | [Abrechnung](app:/billing) | Jeder Anteil, den ein Mitglied wählen kann, fällt in ein Band; keine Lücke zwischen 0 und 100 Prozent |
| 16 | Angebotene Tarife | Abrechnung, Stufen | Nur die Tarife, die Sie verkaufen wollen |
| 17 | Womit neue Mitglieder starten | **Neue Mitglieder**, im Workspace | Das Abo und die Regel bei aufgebrauchten Tagen sind die von Ihnen gewählten |
| 18 | Pakete und Leistungen | Abrechnung, [Leistungen](app:/services) | Namen und Preise lesen sich für ein Mitglied richtig |
| 19 | Wie Mitglieder bezahlen | **Wie Mitglieder bezahlen** in der Bereitschaftsliste | Der Bereich steht auf **Bereit**, und die erwartete Bankverbindung (IBAN, Verwendungszweck) wird in den Einstellungen angezeigt; ein Anbieter allein setzt ihn ebenfalls auf bereit |
| 20 | Online-Zahlungen | [Funktionen](app:/features) | Aus, außer ein Anbieter ist verbunden |
| 21 | Administratoren | Mitglieder & Tarife | Jeder ist eine Person, der Sie die Daten aller Mitglieder anvertrauen würden |
| 22 | Administrator-Karte der Matrix | Rollen | Sie können jedes Häkchen lesen und vertreten |
| 23 | Wer wird worüber informiert | [Wie Mitglieder informiert werden](help:setup.notify.members) | Mitglieder finden alles unter **Ereignisse**; Push nur, wenn der Betreiber es eingerichtet hat |
| 24 | Kiosk und Ausweise | [Funktionen](app:/features) | Aus, oder ein Kiosk-Mitglied existiert und Ausweise sind ausgegeben |
| 25 | Standorte | Funktionen | Aus, oder mindestens ein Standort existiert |
| 26 | Zurückgehaltene Funktionen | **Funktionen**, **Braucht Aufmerksamkeit** | Der Filter zeigt keinen Prozess |

*Wachsen: Rechnungen, Steuern und Unterlagen*

| # | Prüfpunkt | Wo | So sieht es richtig aus |
|---|---|---|---|
| 27 | Rechtliche Identität | [Rechtliche Identität & E-Rechnung](app:/legal-identity) | **Vor der Ausstellung bitte ergänzen** zeigt nichts, wenn Sie eine Probe-Rechnung beginnen |
| 28 | Steuerregime und Sätze | [USt](app:/vat) | Das Regime ist das, das Ihr Steuerberater genannt hat; für Ihren Standard gilt ein Satz |
| 29 | Nummernformat | [Nummernkreise](app:/settings/number-sequences) | Sie haben die Vorschau gelesen, und Ihr Steuerberater ist einverstanden |
| 30 | Eine Probe-Rechnung | Test-Space, Monatsabschluss-Assistent | Sie wurde ausgestellt, in jeder Sprache, die Ihre Mitglieder lesen, ohne fehlenden Punkt |
| 31 | Ein aktueller Export | **Export und Wiederherstellung** | „Ein aktueller Export ist erfasst“ |

**Schritte**

1. Drucken Sie die drei Tabellen aus oder kopieren Sie sie in Ihre Notizen.
2. Gehen Sie *Öffnen* durch und haken Sie jede Zeile ab, wenn Sie die Spalte *So sieht es richtig aus* sehen, nicht wenn Sie sich daran erinnern.
3. Tun Sie dasselbe für *Betreiben* und *Wachsen* im Test-Space, für die Zeilen von *Wachsen* mit Ihrem Steuerberater.
4. Wiederholen Sie die Zeilen, die sich geändert haben, wenn Sie in den echten Space wechseln. Eine Vorlage oder eine Einstellungsdatei übernimmt nicht alle.

**Ergebnis** Eine Liste, die Sie jemandem zeigen können, und ein Space, den Sie arbeiten gesehen haben, bevor jemand von ihm abhängt.

**Siehe auch:** [Woche 0 bis Woche 4](help:setup.training.overview) · [Ein gefahrloser Probelauf](help:setup.money.dry-run) · [Die Reihenfolge, der Sie folgen](help:setup.reports.sequence)

<!-- anchor: setup.consistent.monthly -->
### Die Monatsroutine

**Zielgruppe:** Inhaber · Administrator:in · Abrechnungsadministrator:in

Sie möchten eine kurze Gewohnheit, die den Space stimmig hält, in zehn Minuten am Monatsende.

**Schritte**

1. Öffnen Sie **Einrichtung dieses Workspace**. Jeder Bereich steht weiter auf **Bereit** oder **Hier nicht nötig** oder wurde bewusst beiseitegelegt.
2. Öffnen Sie [Ereignisse](app:/events). **Wartet auf Ihre Bestätigung** ist leer oder klein, und kein Mitglied ist länger als ein, zwei Tage **Ausstehend**.
3. Zählen Sie das Team neu. Wer gegangen ist oder pausiert, kann eine Regel zu knapp machen. Siehe [Anfragen vermeiden, die ewig warten](help:setup.people.stuck).
4. Schließen Sie den Monat: Schließtage sind eingetragen, der Monatsabschluss-Assistent ist durchgelaufen, Zahlungserinnerungen sind hinausgegangen (automatisch jeden Morgen oder beim Öffnen der Finanzen, wo die Datenbank keinen Scheduler hat). Siehe [Der Monatsabschluss-Assistent](help:user.invoicing.wizard).
5. Ziehen Sie den Datenexport und öffnen Sie **Funktionen**, um zu prüfen, dass nach den Änderungen des Monats kein Prozess Aufmerksamkeit braucht.

**Gut zu wissen**

- Schreiben Sie das Datum des letzten Durchlaufs in die erste Zeile Ihrer Notizen; so weiß die nächste Person, wann es zuletzt stimmte.
- Alles, was im Monat an der Rollenmatrix oder an einer Validierungsregel geändert wurde, ist eine weitere Prüfung der Zeilen 9, 11 und 12 der Prüfung wert.

**Ergebnis** Ein Space, der bleibt, was Sie eingerichtet haben.

**Siehe auch:** [Die Prüfung vor dem Start](help:setup.consistent.audit)

<!-- anchor: setup.consistent.wrong -->
### Wenn etwas falsch aussieht

**Zielgruppe:** Inhaber · Mitinhaber · Administrator:in

Sie möchten wissen, was Sie in welcher Reihenfolge versuchen und wen Sie fragen.

<p><img src="images/setup-consistent-recovery-export.de.jpg" width="280"></p>

**Schritte**

1. Lesen Sie die Meldung auf dem Bildschirm. Die meisten sagen, was zu tun ist.
2. Prüfen Sie die Seite. Sehen Sie auf das Banner des Test-Space und auf die in [Ich](app:/me) angezeigte Seite. Auf der Testseite gedruckte Dokumente tragen ein Wasserzeichen, und dort wird nichts geschuldet; die echte Seite stellt Rechnungen aus, die geschuldet sind.
3. Prüfen Sie [Funktionen](app:/features) und [Rollen](app:/roles): Eine fehlende Funktion ist eine Funktion, die aus ist, oder eine Berechtigung, die niemand angekreuzt hat.
4. Öffnen Sie **Einrichtung dieses Workspace** und lesen Sie den Bereich, der zum Symptom passt.
5. Bereiten Sie **Supportdetails** unter [Hilfe](app:/help) vor: Wählen Sie **Letzte Stunde** oder **Letzte 24 Stunden**, **Vorschau vorbereiten**, lesen Sie sie, **Speichern** Sie und senden Sie die Datei. Sie enthält nur Zahlen und Prüfungen, keine Identitäten, Zugangsdaten oder Geschäftsdaten.
6. Ziehen Sie vor jeder größeren Änderung den Datenexport (unten).

*Wen Sie fragen*

| Worum es geht | Fragen Sie |
|---|---|
| Eine Einstellung Ihres Space, eine Regel, eine Rolle | Sich selbst, dann Ihren Mitinhaber |
| Eine Rechnung, die Umsatzsteuer, eine Nummer | Ihren Steuerberater, mit der Probe-Rechnung |
| Ein Bereich, der **Wartet auf jemand anderen** oder **Der Serverbetreiber** sagt | Den Betreiber Ihrer Installation |
| Ein Assistent, der nicht genehmigt ist | Einen Datenbankadministrator |
| Ein Fehler, den Sie sich nicht erklären können | Den Support, mit der Support-Datei |

*Der Wiederherstellungsexport*

1. Öffnen Sie [Berichte](app:/reports?section=documents) und wählen Sie **Workspace-Dokumente**.
2. Tippen Sie auf **Daten exportieren (Excel)**. Dafür brauchen Sie die Funktion **Datenexport (Excel)** und die Berechtigung **Buchhaltung und Daten exportieren**. Sie erhalten eine ZIP-Datei: eine Arbeitsmappe mit einem Blatt je Datensatz, ein Manifest mit der Zeilenzahl und die gespeicherten Dateien.
3. Tippen Sie auf **Konfiguration exportieren (PDF)** für eine Aufzeichnung der Parameter und, im **Workspace**, auf **Workspace exportieren (XML)** für Plan und Einstellungen.

**Gut zu wissen**

- Ein abgeschlossener Datenexport wird erfasst; der Bereich **Export und Wiederherstellung** der Bereitschaftsliste zeigt das 90 Tage lang an und meldet dann, dass der Export älter ist.
- Das PDF ist eine Aufzeichnung, keine Sicherung. Nur das XML lässt sich wieder importieren, und es enthält nie Mitglieder oder Geldbeträge.
- Bewahren Sie die Datei an einem Ort auf, den nur Sie öffnen können: Sie enthält Ihre Mitglieder.

**Siehe auch:** [Supportdetails](help:user.advanced.support) · [Wenn etwas nicht funktioniert](help:user.advanced.troubleshooting) · [Die Daten exportieren (Excel)](help:user.workspace.export.excel)

<!-- anchor: setup.consistent.irreversible -->
### Was sich nicht rückgängig machen lässt

**Zielgruppe:** Inhaber · Mitinhaber · Abrechnungsadministrator:in

Sie möchten eine Seite, die sagt, wo Sie langsamer werden sollten. Die vollständige Liste mit dem, was Sie stattdessen tun können, steht unter [Schwer rückgängig zu machende Entscheidungen](help:setup.before.permanent). Dies ist die Zusammenfassung.

> **Achtung** Eine ausgestellte Rechnung ändert sich nie, und ihre Nummer wird nie wiederverwendet. Ein Fehler wird mit einer Stornierung, einer Gutschrift oder einem Erstattungsantrag korrigiert, nicht mit einer Bearbeitung.

| Entscheidung | Endgültig ab | Behandelt in |
|---|---|---|
| Format und Reihenfolge der Rechnungsnummer | Der ersten ausgestellten Rechnung | [Schwer rückgängig zu machende Entscheidungen](help:setup.before.permanent) |
| Der abgerechnete Monat eines Mitglieds | Dem Moment, in dem die Rechnung ausgestellt wird | [Geld](help:setup.money.permanent) |
| Rechtliche Angaben auf der Rechnung | Der ersten ausgestellten Rechnung | [Die Reihenfolge, der Sie folgen](help:setup.reports.sequence) |
| Steuerregime und Sätze | Sätze werden nach Datum versioniert und nie bearbeitet; eine eingereichte Voranmeldung wird nie neu berechnet | [Geld](help:setup.money.permanent) |
| Land, Währung, Zeitzone | Sobald Geld im Spiel ist: Beträge werden nicht umgerechnet | [Schwer rückgängig zu machende Entscheidungen](help:setup.before.permanent) |
| Ersetzen des Grundrisses | Wird abgelehnt, sobald eine Reservierung existiert; das Löschen eines Stockwerks entfernt, was darauf ist | [Schwer rückgängig zu machende Entscheidungen](help:setup.before.permanent) |
| Die Workspace-ID | Wenn Sie sie ändern, hört die alte sofort auf zu funktionieren; drucken Sie den QR-Code neu | [Wie Menschen beitreten](help:setup.people.join) |
| Eigentümerschaft | Ein Inhaber kann sie abgeben; es gibt keine Einladung zum Inhaber | [Mitinhaber](help:setup.people.coowner) |
| Eine Änderung an der Matrix oder an einer Validierung | Sie wird als Ereignis erfasst und wirkt sofort für alle | [Die Rollenmatrix](help:setup.people.matrix) |
| Test oder echt | Ein echter Space stellt Rechnungen aus, die geschuldet sind | [Bevor Sie beginnen](help:setup.before.overview) |
| Ein geteilter Export | Eine geteilte Datei lässt sich nicht zurückrufen | [Wenn etwas falsch aussieht](help:setup.consistent.wrong) |

**Gut zu wissen**

- Eine Funktion auszuschalten löscht nie Daten.
- Eine Datei mit Zugangsdaten ist keine Sicherung. Halten Sie Tokens aus jeder Datei heraus, die Sie versenden.

**Ergebnis** Sie wissen, welche Zeilen Sie zweimal lesen sollten.

**Siehe auch:** [Bevor Sie beginnen](help:setup.before.overview)
