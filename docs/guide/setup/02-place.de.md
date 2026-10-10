<!-- anchor: setup.place.overview -->
## Den Ort aufbauen

Dieses Kapitel baut die erste Stufe, *Öffnen*: wo der Space liegt, wie er aussieht, wann er geöffnet ist und welche Regeln für Buchungen gelten. In etwa zwanzig Minuten kann der Space gebucht werden. Das Beispiel ist das *Atelier du Marché*, ein Verein in Pézenas mit zwei Etagen und einem Raum.

In diesem Kapitel:
- [Land, Währung, Zeitzone und Sprache](help:setup.place.where)
- [Der Grundriss](help:setup.place.plan)
- [Öffnungszeiten und Buchungsregeln](help:setup.place.times)
- [Schließtage und Feiertage](help:setup.place.closure)
- [Ihren Space prüfen](help:setup.place.check)

<!-- anchor: setup.place.where -->
### Land, Währung, Zeitzone und Sprache

**Zielgruppe:** Inhaber · Administrator:in

Sie möchten, dass der Space weiß, wo er zu Hause ist. Diese vier Angaben bestimmen mehr, als man denkt.

<p><img src="images/setup-place-country.de.jpg" width="280"></p>

*Was jede Angabe bestimmt*

| Angabe | Was sie festlegt |
|---|---|
| **Land** | Die vorgeschlagene Währung und Zeitzone sowie die Feiertage, die als Schließtage angeboten werden (siehe unten). |
| **Währung** | Wie jeder Betrag angezeigt und gezählt wird. |
| **Zeitzone** | Was ein Arbeitstag, eine Halbtagsgrenze und ein Schließtag bedeuten; ein Mitglied im Ausland sieht den Tag des Spaces. |
| **Sprache des Arbeitsbereichs** | Die Sprache, in der Einladungen und geteilte Nachrichtenverweise standardmäßig geschrieben werden. |

**Schritte**

1. Öffnen Sie [Workspace](app:/workspace-settings) und gehen Sie zu **Allgemeine Angaben**.
2. Wählen Sie das **Land**; **Währung** und **Zeitzone** folgen, und Sie können sie korrigieren. Für das Atelier du Marché: Frankreich, EUR, Europe/Paris.
3. Wählen Sie die **Sprache des Arbeitsbereichs** und tippen Sie auf **Speichern**.

> **Achtung** Wählen Sie Land und Währung am ersten Tag richtig. Beträge werden als einfache Zahlen gespeichert; die Währung zu ändern, wenn schon Geld gezählt wurde, würde alles Bisherige falsch beschriften.

**Gut zu wissen**

- Die App listet viele Länder, doch Rechnungen innerhalb von DesKilo auszustellen funktioniert heute nur für Frankreich und Deutschland. Anderswo führen Sie Kontoauszüge weiter und stellen Rechnungen außerhalb der App aus.
- Die Sprache des Arbeitsbereichs ist nicht Ihre eigene App-Sprache; die steht in Ihren persönlichen Einstellungen.

**Siehe auch:** [Land](help:user.workspace.settings.country) · [Währung und Zeitzone](help:user.workspace.settings.currency-timezone) · [Sprache des Arbeitsbereichs](help:user.workspace.settings.language)

<!-- anchor: setup.place.plan -->
### Der Grundriss

**Zielgruppe:** Inhaber · Administrator:in

Sie möchten, dass der Plan auf dem Bildschirm dem echten Ort gleicht. Er besteht aus vier Ebenen: Etagen, dann Büros (Räume), dann Tische, dann Plätze. Ein Mitglied bucht einen Platz; einen Platz zählt die Bereitschaftsliste.

<p><img src="images/setup-place-rooms.de.jpg" width="280"></p>

**Schritte**

1. Skizzieren Sie auf Papier: Etagen, Räume, Tische, Plätze.
2. Öffnen Sie den [Workspace-Editor](app:/editor) und fügen Sie die Etagen mit **Etage hinzufügen** hinzu.
3. Öffnen Sie eine Etage und zeichnen Sie jeden Raum mit **Büro**, darin dann **Tisch** und **Platz**.
4. Darf ein Team einen Raum oder eine Etage für einen Tag nehmen, schalten Sie in dessen Eigenschaften die Buchung des ganzen Raums ein.

**Gut zu wissen**

- Beginnen Sie klein: eine erste Etage, ein Raum, ein paar Plätze. Alles lässt sich später ergänzen.
- Eine ganze Etage, ein Büro oder ein Tisch ist nur buchbar, wenn **Tisch-, Büro- & Etagen-Reservierungen** eingeschaltet ist und das Mitglied die Berechtigung hat.
- Die eingebaute Vorlage A tiny space gibt Ihnen zwei Etagen, vier Tische und acht Plätze zum Anpassen.
- Eine Etage zu löschen entfernt alles darauf, und ein Plan-Import wird abgelehnt, sobald Buchungen existieren.

**Siehe auch:** [Etagen hinzufügen, umbenennen und löschen](help:user.space.editor.levels) · [Räume, Tische und Plätze zeichnen](help:user.space.editor.rooms) · [Mitglieder eine ganze Etage buchen lassen](help:user.space.editor.level-booking)

<!-- anchor: setup.place.times -->
### Öffnungszeiten und Buchungsregeln

**Zielgruppe:** Inhaber · Administrator:in

Sie möchten, dass Buchungen dem Rhythmus Ihres Ortes folgen. Ein Bildschirm, **Verfügbarkeit**, enthält die Tage, die Form einer Buchung, die Arbeitszeiten und die Regeln. Der Server wendet sie überall an: auf dem Plan, im Buchungsblatt, bei gescannten Codes und am Kiosk.

<p><img src="images/setup-place-availability--times.de.jpg" width="280"></p>

**Schritte**

1. Öffnen Sie [Verfügbarkeit](app:/availability).
2. Wählen Sie unter **Geöffnete Wochentage** die Tage (mindestens einen) und die **Buchungsgranularität**.
3. Legen Sie die **Arbeitszeiten** fest: **Tagesbeginn**, **Halbtagsgrenze**, **Tagesende**.
4. Entscheiden Sie unter **Buchungsregeln** über **Vergangene Buchungen erlauben**, **Außerhalb der Öffnungszeiten** und die **Buchungsgrenzen**.

<p><img src="images/setup-place-availability--rules.de.jpg" width="280"></p>

*Empfohlene Ausgangspunkte (Vorschläge, keine Vorschriften; die Voreinstellung für **Außerhalb der Öffnungszeiten** ist **Berechnet**, und die Vereinsvorlage ändert daran nichts)*

| Szenario | Granularität | Zeiten | Außerhalb der Zeiten | Vergangene Buchungen | Grenzen |
|---|---|---|---|---|---|
| Ein paar gemeinsame Tische | **Freier Zeitraum** oder **1-Stunden-Slots** | Tag 8:00–17:00 Uhr | **Frei** | Aus | Eine Buchung gleichzeitig; Vorlauf 30 Tage |
| Ein Vereinsraum (Atelier du Marché) | **Halbe Tage (Vormittag & Nachmittag)** | 7:00, Grenze 13:00, Ende 19:00 Uhr | **Aus** | Aus | Eine Buchung gleichzeitig; Vorlauf 90 Tage |
| Ein Coworking mit halben Tagen | **Halbe Tage (Vormittag & Nachmittag)** | 8:00, Grenze 12:00, Ende 18:00 Uhr | **Berechnet** | Aus | Ein oder zwei gleichzeitig; Vorlauf 90 Tage |

**Gut zu wissen**

- Außerhalb der Öffnungszeiten verweigert **Aus** alles, **Nur spontan** erlaubt Buchungen ohne Voranmeldung, **Frei** erlaubt sie ohne Zählung, **Berechnet** zählt wie gewöhnliche Nutzung, außer an einem Tag, an dem das Mitglied schon eine reguläre Buchung hat.
- Der Tag muss der Reihe nach laufen: Beginn, dann Grenze, dann Ende; die Mindestdauer darf die Höchstdauer nicht überschreiten.
- Eine Buchung endet an dem Tag, an dem sie beginnt. Vergangene Buchungen sind standardmäßig aus; ein früheres Zeitfenster am selben Tag zu buchen ist immer erlaubt.
- Halbtags- und Ganztagsfenster steuern auch das Einchecken und die Abrechnung; legen Sie also die Zeiten fest, bevor Sie Preise setzen.

**Siehe auch:** [Geöffnete Wochentage](help:user.workspace.availability.open-weekdays) · [Granularität](help:user.workspace.availability.granularity) · [Arbeitszeiten](help:user.workspace.availability.working-hours) · [Außerhalb der Öffnungszeiten](help:user.workspace.availability.outside-hours) · [Buchungsgrenzen](help:user.workspace.availability.limits)

<!-- anchor: setup.place.closure -->
### Schließtage und Feiertage

**Zielgruppe:** Inhaber · Administrator:in

Sie möchten, dass der Space an Feiertagen geschlossen ist, ohne dass jemand sie versehentlich bucht.

<p><img src="images/setup-place-availability--closure.de.jpg" width="280"></p>

**Schritte**

1. Gehen Sie in [Verfügbarkeit](app:/availability) zu **Schließtage**.
2. Tippen Sie auf **Feiertage hinzufügen** (sehen Sie die Schaltfläche nicht, schalten Sie zuerst die Funktion *Feiertage* ein; sie ist standardmäßig aus), um ein ganzes Jahr auf einmal anzulegen, oder auf **Schließtag hinzufügen** für ein einzelnes Datum wie einen Inventurtag.
3. Prüfen Sie die Liste und entfernen Sie jeden Tag, an dem Sie tatsächlich arbeiten.

**Gut zu wissen**

- Eingebaute Feiertagslisten gibt es für Frankreich und Deutschland. Für andere Länder schalten Sie *Feiertage* und *Feiertage importieren* ein (offene Daten, braucht eine Verbindung). Nichts wird angelegt, bevor Sie bestätigen.
- Eine Buchung an einem Schließtag wird abgelehnt, und der Plan zeigt den Tag mit seinem Grund als geschlossen.
- Bereits abgerechnete Monate werden übersprungen; legen Sie Schließtage also vor Monatsabschluss an.

**Siehe auch:** [Schließtage](help:user.workspace.availability.closure-days) · [Feiertage](help:user.workspace.availability.public-holidays)

<!-- anchor: setup.place.check -->
### Ihren Space prüfen

**Zielgruppe:** Inhaber · Administrator:in

Sie möchten den Beweis, dass der Space bereit ist, bevor Sie jemanden einladen. Zwei Karten zeigen es.

<p><img src="images/setup-place-get-started--card.de.jpg" width="280"></p>

**Schritte**

1. Öffnen Sie [Workspace](app:/workspace-settings): Die Karte **Einrichtung dieses Workspace** listet jeden Bereich mit seinem Zustand und dem nächsten Schritt auf.
2. Öffnen Sie [Reservieren](app:/reserve). Inhaber und Administratoren mit der Berechtigung zur Konfiguration sehen die Karte *Erste Schritte in* Ihrem Space. Fehlt etwas, steht dort *Bevor hier jemand buchen kann*, mit **Einrichtung abschließen**.
3. Buchen Sie zum Test selbst einen Platz und stornieren Sie ihn wieder.

**Gut zu wissen**

- Bereit heißt bereit für eine erste Buchung: Öffnungstage, Zeitzone, Währung, mindestens ein Platz und genug Bestätigende.
- Alles Optionale, etwa Tarife oder Zahlungen, können Sie mit **Später** zurückstellen; es verhindert das Öffnen nicht.
- Beide Karten hängen von der Funktion *Karte „Erste Schritte“* ab.
- **Jetzt nicht** blendet die Karte auf diesem Gerät aus; das Ansichtsmenü auf dem Plan holt sie mit **Erste Schritte** zurück.

**Ergebnis** Ein Space, den Mitglieder buchen können. Als Nächstes: die ersten Personen einladen, dann die Rollen und Tarife der zweiten Stufe.

**Siehe auch:** [Die Karte „Erste Schritte“ und die Tipps](help:user.start.get-started) · [Mit der Workspace-ID einladen](help:user.workspace.code) · [Rollen](help:user.roles.matrix)
