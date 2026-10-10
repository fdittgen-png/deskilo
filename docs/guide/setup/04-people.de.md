<!-- anchor: setup.people.overview -->
## Personen, Rollen und Entscheidungen

Ein Space besteht aus seinen Menschen. Bevor Sie den ersten einladen, entscheiden Sie drei Dinge: wer was darf, wie jemand hineinkommt und welche Handlungen eine zweite Person brauchen, die zustimmt. Sie sind schnell festgelegt und mühsam zu reparieren, sobald vierzig Personen sich darauf verlassen.

In diesem Kapitel:
- [Wer in einer echten Organisation was tut](help:setup.people.organisation)
- [Die Rollenmatrix: so wenig Rechte wie nötig](help:setup.people.matrix)
- [Mitinhaber: mehr als eine Person, die handeln kann](help:setup.people.coowner)
- [Wie Personen beitreten](help:setup.people.join)
- [Die Einladungsnachricht, Sprache für Sprache](help:setup.people.invitation)
- [Verwaltete Profile](help:setup.people.managed)
- [Freigabe: woraus eine Regel besteht](help:setup.people.validation)
- [Drei Vorlagen zum Kopieren](help:setup.people.presets)
- [Anfragen vermeiden, die ewig warten](help:setup.people.stuck)
- [Die erste Woche Ihrer Mitglieder](help:setup.people.first-week)

Das durchgehende Beispiel ist das *Atelier du Marché*. Stellen Sie sich vor, ein Verein führt es: Ada ist die Präsidentin, Chiara die Schriftführerin, Bruno der Schatzmeister. Jeder Schritt unten wird an diesem Space gezeigt.

<!-- anchor: setup.people.organisation -->
### Wer in einer echten Organisation was tut

**Zielgruppe:** Inhaber · Mitinhaber

Sie möchten die Personen Ihrer Organisation den Rollen zuordnen, die DesKilo kennt, damit niemand mehr hält, als seine Aufgabe verlangt.

<p><img src="images/setup-people-members.de.jpg" width="280"></p>

*Die vier Grundrollen*

| Rolle | Wofür sie da ist | Im Verein |
|---|---|---|
| **Inhaber** | Die Person, die für den Space einsteht und jede Berechtigung hat. Nur ein Inhaber kann die Inhaberschaft erteilen. | Ada, die Präsidentin. |
| **Mitinhaber** | Ein zweiter Schlüssel. Hat standardmäßig jede Berechtigung und kann übernehmen, wenn der Inhaber geht. | Die Vizepräsidentin, falls der Vorstand eine hat. |
| **Administrator** | Führt den Alltag: Mitglieder, Buchungen für andere, den Kiosk, Dokumente, Leistungen. Hat, was die Matrix gibt, und nicht mehr. | Chiara, die Schriftführerin. |
| **Benutzer** | Die Person, die den Space nutzt. Hat nur die Alltagsberechtigungen, die Sie geben. | Bruno, ein Mitglied wie die anderen. |

Jede Person hat genau eine Grundrolle. Eine Rolle, die der Space selbst festlegt, etwa *Gastgeber* oder *Buchhaltung*, kommt darauf und nimmt nie etwas weg.

*Ein Schatzmeister, ohne Administrator zu sein*

Bruno führt die Bücher, soll aber den Grundriss nicht bearbeiten und keine neuen Mitglieder freigeben. Geben Sie ihm die Grundrolle **Benutzer** und fügen Sie eine eigene Rolle hinzu, zum Beispiel *Buchhaltung*, mit vier Berechtigungen: **Workspace-Finanzen einsehen**, **Rechnungen ausstellen & Zahlungen zuordnen**, **Buchhaltung und Daten exportieren** und **Kennzahlen des Arbeitsbereichs lesen**. Nicht mehr. Eine solche Rolle ist nicht eingebaut; Sie legen sie mit den folgenden Schritten an.

<p><img src="images/setup-people-roles-space.de.jpg" width="280"></p>

**Schritte**

1. Öffnen Sie [Rollen dieses Bereichs](app:/settings/roles-of-this-space) und tippen Sie auf **Rolle hinzufügen**. Siehe [Rollen dieses Bereichs](help:user.roles.space).
2. Geben Sie der Rolle einen Namen, wählen Sie **Was sie ergänzt** und tippen Sie auf **Rolle speichern**.
3. Öffnen Sie die Person unter [Mitglieder & Tarife](app:/members), suchen Sie **Rollen** und tippen Sie auf **Rolle hinzufügen**.

**Gut zu wissen**

- **Rollen dieses Bereichs** ist eine eigene Funktion und in einem neuen Space aus. Schalten Sie sie unter [Funktionen](app:/features) ein.
- Niemand kann sich selbst eine Rolle geben. Eine Rolle zu geben braucht **Rollen & Berechtigungen verwalten**, und nur ein Inhaber kann eine Rolle geben, die das enthält.
- Eine Rolle, die der Space festlegt, gilt sofort und wird festgehalten. Nur wenn jemand zum Administrator gemacht wird oder es nicht mehr ist, greift die Freigaberegel **Rollenwechsel**.

**Ergebnis** Jede Person des Vorstands hat die Berechtigungen ihrer Aufgabe, und der Inhaber bleibt der Einzige, der das ändern kann.

**Siehe auch:** [Die Rollenmatrix](help:user.roles.matrix)

<!-- anchor: setup.people.matrix -->
### Die Rollenmatrix: so wenig Rechte wie nötig

**Zielgruppe:** Inhaber · Mitinhaber

Sie möchten, dass jede Rolle hat, was sie braucht, und sonst nichts. Das ist das Prinzip der geringsten Rechte: klein beginnen, hinzufügen, wenn jemand fragt, denn eine einmal gegebene Berechtigung nimmt man selten ohne Verstimmung zurück.

<p><img src="images/setup-people-roles-matrix.de.jpg" width="280"></p>

**Schritte**

1. Öffnen Sie [Rollen](app:/roles). Es gibt eine Karte pro Rolle: **Inhaber**, **Mitinhaber**, **Administrator** (der Inhaber kann sie umbenennen) und **Benutzer**.
2. Lesen Sie zuerst die Karte **Administrator**. Sie zeigt, was ein Administrator heute in Ihrem Space hat.
3. Entfernen Sie den Haken bei dem, was Sie nicht abgeben möchten. Setzen Sie die Alltagsberechtigungen, die die Karte **Benutzer** braucht (siehe unten).

*Was ein Administrator standardmäßig hat*

| Gruppe | Berechtigungen |
|---|---|
| Personen | **Mitglieder verwalten**, **Persönliche Daten der Mitglieder lesen** |
| Buchungen und der Ort | **Reservierungen anderer verwalten**, **Kiosk und Badges bedienen**, **Standorte verwalten und den Grundriss bearbeiten** |
| Geld, lesen und genehmigen | **Workspace-Finanzen einsehen**, **Ausgaben genehmigen**, **Services & Pakete verwalten**, **Geschäftsvereinbarungen einsehen**, **Geschäftsvereinbarungen verwalten**, **Änderung der Zahlungsbedingungen beantragen**, **Buchhaltung und Daten exportieren** |
| Dokumente und Kennzahlen | **Dokumentbibliothek verwalten**, **Kennzahlen des Arbeitsbereichs lesen** |
| Zwei Seiten eines Spaces | **In die Entwicklung ausrollen**, **Den Produktionsraum betreten** |

Ein Administrator hat nicht **Rollen & Berechtigungen verwalten**, **Validierungsregeln konfigurieren**, **Workspace-Einstellungen bearbeiten**, **Tarife und Abrechnungsregeln verwalten**, **Dokumente gestalten**, **Integrationen verwalten**, **Konfiguration verwalten** oder **In die Produktion ausrollen**. Eine Mit-Inhaberin hat alle, bis Sie einige abwählen. Der Inhaber hat sie immer alle.

> **Achtung** In einem neuen Space ist die Karte **Benutzer** leer. Die sechs Alltagsberechtigungen (**Den Messenger nutzen**, **Buchen und Reservierungen nutzen**, **Den Kalender sehen**, **Das Mitgliederverzeichnis sehen**, **Das eigene Konto und die eigenen Rechnungen sehen**, **Die geteilten Dokumente sehen**) gelten nur über die Matrix oder eine Rolle. Solange Sie sie nicht angehakt haben, kann ein beitretendes Mitglied den Plan nicht öffnen. Die Demo zeigt sie schon angehakt, was das verdeckt. **Einrichtung dieses Workspace** zeigt **Was Mitglieder dürfen** als **Nötig für eine erste Buchung**, bis die Karte **Benutzer** **Buchen und Reservierungen nutzen** hält; die fünf anderen prüft sie nicht. Haken Sie sie bei der Karte **Benutzer** an, und bei der Karte **Administrator**, wenn auch Administratoren buchen, und testen Sie dann mit einem zweiten Konto.

**Gut zu wissen**

- Standardmäßig kann ein Administrator alle Finanzen und die persönlichen Daten jedes Mitglieds lesen. Sind Ihre Administratoren Ehrenamtliche, überlegen Sie, ob sie das sollen.
- **Admins stellen Rechnungen aus** (eine Funktion, standardmäßig aus, unter **Rechnungen**) gibt Administratoren **Rechnungen ausstellen & Zahlungen zuordnen**, was auch immer die Matrix sagt. Besser ist der Haken in der Matrix oder eine eigene Rolle, was genauer ist.
- Entfernen Sie eine Berechtigung, verschwindet sie überall zugleich; der Server prüft sie, nicht nur das Menü.
- Jede Änderung der Matrix wird als Ereignis festgehalten. Die Funktion **Rollenverwaltung** zeigt nur den Bildschirm; ist sie aus, gilt die gespeicherte Matrix weiter, Sie können sie nur nicht bearbeiten.

**Ergebnis** Eine Matrix, die Sie pro Rolle in einem Satz erklären können.

**Siehe auch:** [Die Rollenmatrix](help:user.roles.matrix) · [Wer was tut](help:setup.before.who)

<!-- anchor: setup.people.coowner -->
### Mitinhaber: mehr als eine Person, die handeln kann

**Zielgruppe:** Inhaber · Mitinhaber

Sie möchten, dass der Space weiterläuft, wenn Sie krank, verreist oder fort sind. Jeder Space braucht mehr als eine Person, die handeln kann. Standardmäßig haben nur Inhaber und Mitinhaber die Berechtigungen, die Funktionen, Rollen, Freigaberegeln und die Workspace-ID ändern, und nur ein Inhaber kann einen weiteren Inhaber machen.

<p><img src="images/setup-people-coowner.de.jpg" width="280"></p>

*Die zwei Arten*

| Art | Was sie bewirkt | Wählen Sie sie, wenn … |
|---|---|---|
| *Aktiver Mitinhaber* | Hat jetzt die Berechtigungen des Inhabers und übernimmt, wenn der Inhaber geht. | Sie die Arbeit teilen: die Vizepräsidentin, ein Partner. |
| **Nachfolge** | Wartet. Wird Inhaber, wenn Sie sie befördern oder wenn Sie gehen. | Sie nur einen Erben möchten. |

**Schritte**

1. Schalten Sie die Funktion **Mitinhaber** unter [Funktionen](app:/features) ein. In einem neuen Space ist sie aus.
2. Öffnen Sie die Person unter [Mitglieder & Tarife](app:/members), gehen Sie zu **Verwalten** und tippen Sie auf **Mit-Inhaberschaft**.
3. Wählen Sie den aktiven Mitinhaber oder **Nachfolge**. Um sofort zu übergeben, wählen Sie **Jetzt zum Inhaber machen**.

**Gut zu wissen**

- Geht der letzte Inhaber, wird die geeignetste Mit-Inhaberin von selbst Inhaber, eine aktive vor einer Nachfolgerin.
- Zwei Administratoren sind nicht dasselbe: Ein Administrator hat nur, was die Matrix gibt, und kann die Inhaberschaft nie weitergeben.
- Eine Regel mit **Inhaber muss immer validieren** verlangt einen Inhaber. Prüfen Sie auf Ihrer Testseite, dass Ihre Mit-Inhaberin weiterhin so entscheiden kann, wie Sie erwarten.

**Ergebnis** Der Space hat eine zweite Person, die handeln kann.

**Siehe auch:** [Mit-Inhaberinnen](help:user.roles.co-owners) · [Mit-Inhaberschaft](help:user.members.co-ownership)

<!-- anchor: setup.people.join -->
### Wie Personen beitreten

**Zielgruppe:** Inhaber · Administrator:in

Sie möchten wählen, wie Personen zu Ihrem Space kommen und wer sie hereinlässt. Es gibt vier Wege, und jeder endet am selben Punkt: Eine Person bittet um Beitritt, und jemand entscheidet.

<p><img src="images/setup-people-workspace-code.de.jpg" width="280"></p>

| Weg | Was die Person erhält | Was sie wird |
|---|---|---|
| Die Workspace-ID | Ein kurzes Wort, in der App einzutippen. | Mitglied, nach Freigabe. |
| Der QR-Code | Dieselbe ID als Bild zum Drucken oder Aushängen (**Als PNG teilen**). | Mitglied, nach Freigabe. |
| Eine Einladungsnachricht | Ein Text mit persönlichem Code, für eine Person gültig, in der Sprache Ihrer Wahl. | Die Rolle, die Sie anbieten, nach Freigabe. |
| Ein Administratorcode | Ein Code für eine Person aus dem Tab **Einladung als Administrator:in**. | Einmalig Administrator. |

**Schritte**

1. Öffnen Sie [Workspace-ID & QR](app:/workspace-code). Wählen Sie mit **Workspace-ID ändern** eine ID, die man sich merken kann: 4 bis 20 Buchstaben oder Ziffern, in ganz DesKilo eindeutig.
2. Tippen Sie für eine namentlich bekannte Person auf **Jemanden einladen**. Tragen Sie den Namen ein, haken Sie **Rollen bei der Ankunft** an, wenn sie eine Rolle bekommen soll, wählen Sie die **Sprache der Nachricht** und senden Sie.
3. Bittet jemand um Beitritt, steht in seiner Zeile unter [Mitglieder & Tarife](app:/members) **Ausstehend**. Öffnen Sie sie und wählen Sie **Mitgliedschaft bestätigen** oder **Mitgliedschaft ablehnen**.

**Gut zu wissen**

- Niemand kommt ohne Entscheidung hinein. Bis sie getroffen ist, sieht die neue Person einen Wartebildschirm und sonst nichts.
- Die Entscheidung folgt der Regel für **Neues Mitglied** unter [Freigaberegeln](app:/validation): Standardmäßig genügt ein Inhaber oder Administrator; verlangen Sie zwei, bleibt die Person nach der ersten Freigabe ausstehend.
- Ändern Sie die Workspace-ID, funktioniert die alte nicht mehr. Drucken Sie den QR-Code neu.
- Es gibt keine Einladung als Inhaber. Die Inhaberschaft wird unter **Mitglieder & Tarife** erteilt.

**Ergebnis** Personen finden Sie, und Sie entscheiden, wer bleibt.

**Siehe auch:** [Die Workspace-ID](help:user.workspace.code) · [Einem Workspace beitreten](help:user.start.join) · [Ausstehende und pausierte Mitglieder](help:user.members.pending)

<!-- anchor: setup.people.invitation -->
### Die Einladungsnachricht, Sprache für Sprache

**Zielgruppe:** Inhaber · Administrator:in

Sie möchten eine Einladung, die nach Ihrem Space klingt, in der Sprache der Person, die sie erhält. Jede Sprache hat ihren eigenen Text; die, die Sie nicht schreiben, fällt auf die eingebaute Nachricht zurück.

<p><img src="images/setup-people-invite.de.jpg" width="280"></p>

<p><img src="images/setup-people-invitation-message--message.de.jpg" width="280"></p>

**Schritte**

1. Öffnen Sie [Workspace](app:/workspace-settings) und gehen Sie zu **Gemeinschaft und Einladungen**.
2. Wählen Sie unter **Sprache der Nachricht** die Sprache, für die Sie schreiben. Die Zeile öffnet sich mit der Sprache Ihres Arbeitsbereichs.
3. Schreiben Sie den Text. Tippen Sie auf einen Platzhalter, um ihn an der Cursorposition einzufügen. Die Grenze liegt bei 2000 Zeichen.
4. Wiederholen Sie das für jede Sprache, die Ihre Mitglieder nutzen, und tippen Sie dann auf **Speichern**.

*Die Platzhalter*

| Platzhalter | Wird gefüllt mit |
|---|---|
| `{firstName}` `{lastName}` `{phone}` | Dem, was Sie unter **Jemanden einladen** eingetippt haben. Leer, wenn Sie nichts eingetippt haben. |
| `{workspaceName}` | Dem Namen Ihres Spaces. |
| `{workspaceId}` | Dem persönlichen Einladungscode dieser Nachricht (nicht der öffentlichen Workspace-ID). |
| `{inviteLink}` | Einem Link, der die App auf dem richtigen Server mit ausgefülltem Code öffnet. |
| `{downloadUrl}` | Der Store-Seite der App. |
| `{role}` | Der Rolle, die die Einladung anbietet, in der Sprache der Nachricht. |

**Gut zu wissen**

- Lassen Sie das Feld leer, schreibt die App ihre eigene Nachricht in dieser Sprache. Sie erklärt die Schritte: herunterladen, Konto anlegen, mit dem Code beitreten.
- Fügen Sie keinen Code und keinen Link selbst ein. Jeder Versand erzeugt seinen eigenen Code, für eine Person gültig.
- Ein falsch geschriebener Platzhalter bleibt im gesendeten Text sichtbar: Lesen Sie die Vorschau, bevor Sie senden.
- Die eingebaute Nachricht sagt der Person, dass der Code nur einmal verwendbar und 14 Tage gültig ist.

**Ergebnis** Eine Einladung, der Ihre Mitglieder folgen können, ohne Sie zu fragen.

**Siehe auch:** [Einladungsnachricht](help:user.workspace.settings.invitation-message) · [Jemanden per Nachricht einladen](help:user.workspace.code.invite)

<!-- anchor: setup.people.managed -->
### Verwaltete Profile

**Zielgruppe:** Inhaber · Administrator:in

Sie möchten für jemanden buchen, abrechnen und verwalten, der noch kein Konto hat: einen Besucher, ein älteres Mitglied, eine Person, die Papier bevorzugt.

**Schritte**

1. Schalten Sie **Verwaltete Profile** unter [Funktionen](app:/features) ein.
2. Tippen Sie unter [Mitglieder & Tarife](app:/members) auf **Verwaltetes Profil anlegen** und füllen Sie die Identität aus.
3. Ist die Person so weit, öffnen Sie ihre Seite und wählen **An die Person übergeben**. Das erzeugt einen persönlichen, an das Profil gebundenen Code.

**Gut zu wissen**

- Wer den Code einlöst, übernimmt das Profil mit seinen Buchungen, Rechnungen und seinem Abo, sobald Sie die Mitgliedschaft bestätigen.
- Nehmen Sie die Übergabe mit **Übergabe zurückziehen** zurück, wenn der Code noch nicht benutzt wurde.

**Siehe auch:** [Ein verwaltetes Profil anlegen](help:user.members.managed)

<!-- anchor: setup.people.validation -->
### Freigabe: woraus eine Regel besteht

**Zielgruppe:** Inhaber

Sie möchten Handlung für Handlung wählen, ob eine zweite Person zustimmen muss. Ein Freigabebereich ist eine Art von Handlung mit eigener Regel: *eine Zahlung*, *eine Ausgabe*, *ein neues Mitglied*, *eine Buchungslöschung*. Unter **Freigaberegeln** stehen die Bereiche in drei Gruppen.

<p><img src="images/setup-people-validation-overview.de.jpg" width="280"></p>

| Gruppe | Bereiche, in einfachen Worten | Während sie wartet |
|---|---|---|
| **Finanzen** | Eine Zahlung, eine Ausgabe, eine Leistung, eine Rechnung, die ihrer Zahlung zugeordnet wird, eine ausgestellte oder stornierte Rechnung, eine Erstattung, eine Abschreibung, eine Preisvereinbarung, eine gemeinsame Ausgabe, eine geplante Ausgabe, eine Änderung der Zahlungsbedingungen, ein vorzeitiger Austritt, ein entfernter Nutzungssatz | Der Betrag zählt auf keinem Kontoauszug. |
| **Buchungen** | **Zusätzliche Halbtage**, um die ein Mitglied bittet, **Ganzraum-Reservierungen**, eine Buchung, die ein Administrator für ein Mitglied macht, eine **Buchungslöschung** | Der Platz bleibt, wie er war. |
| **Personen und Rollen** | **Neues Mitglied**, ein Rollenwechsel, eine Statusänderung, eine Abo-Änderung, eine Änderung der Berechtigungsmatrix | Die Person behält den Zugang, den sie jetzt hat. |

Jeder Bereich beginnt mit **Erbt den Standard**: eine Freigabe durch einen beliebigen Administrator oder Inhaber. Die **Standardregel** ist die Regel, die alle anderen erben. Ein Bereich, den Sie öffnen und speichern, wird **Angepasst**.

*Die Stellschrauben einer Regel*

| Einstellung | Was sie bedeutet | Braucht |
|---|---|---|
| **Erforderliche Validierungen** | Wie viele Personen zustimmen müssen. | |
| **Wer prüft** | **Admins**, **Benannte Personen** oder **Alle Mitglieder**. Der Inhaber darf immer. | **Prüfer nach Rolle oder Person**: Ohne sie wird die Auswahl nicht angezeigt, und Administratoren validieren. Prüfen Sie nach dem Ausschalten noch einmal die Regeln, die **Benannte Personen** nannten |
| **Admins dürfen validieren** | Aus: nur Inhaber validieren. | |
| **Inhaber muss immer validieren** | Eine der Zustimmungen muss von einem Inhaber kommen. | |
| **Die Inhaberschaft darf das Eigene freigeben** | Die eigene Anfrage des Inhabers bleibt nicht auf jemand anderen wartend liegen. Ein Administrator bekommt das nie. | **Verkettete Freigaben** |
| **Nacheinander** | Die zweite Person wird gefragt, sobald die erste zugestimmt hat. | **Verkettete Freigaben** |
| **Nur über diesem Betrag** | Darunter gilt die Handlung sofort. Nur Finanzbereiche. | **Verkettete Freigaben** |
| **Admins löschen ohne Validierung** / **Inhaber löschen ohne Validierung** | Ihre eigene **Buchungslöschung** erledigt sich selbst und bleibt als automatisch validiert markiert. Standardmäßig aus. | |

<p><img src="images/setup-people-validation-sheet.de.jpg" width="280"></p>

**Schritte**

1. Öffnen Sie [Freigaberegeln](app:/validation). Tippen Sie auf **Standardregel** und entscheiden Sie, was alles andere erbt.
2. Tippen Sie auf einen Bereich, stellen Sie die Schrauben ein und tippen Sie auf **Speichern**.
3. Halten Sie die Ausnahmen gering. Jede Ausnahme ist eine Sache mehr, die Sie im Kopf behalten müssen, wenn jemand fragt: „Warum wartet das?“

**Gut zu wissen**

- Niemand validiert die eigene Handlung. Sie wartet auf jemand anderen, es sei denn, die Ausnahme für den Inhaber ist eingeschaltet.
- Jede Entscheidung wird festgehalten: wer, wann, wozu.
- Eine Anfrage, die niemand beantwortet, verfällt nach sieben Tagen, beim nächsten Öffnen von Ereignisse durch irgendjemanden aufgeräumt. Eine Handlung, die ein Administrator für ein Mitglied vornahm, wird stattdessen automatisch bestätigt.

**Siehe auch:** [Freigaberegeln, Bereich für Bereich](help:user.validation.overview) · [Wer validieren darf](help:user.validation.who-may) · [Automatisch validieren](help:user.validation.auto-validate-admin)

<!-- anchor: setup.people.presets -->
### Drei Vorlagen zum Kopieren

**Zielgruppe:** Inhaber

Sie möchten einen Regelsatz, den Sie heute kopieren und später verfeinern können. Wählen Sie einen; jeder stützt sich auf den Standardkreis, Inhaber und Administratoren, es ist also keine zusätzliche Funktion nötig.

| Vorlage | Wählen Sie sie, wenn … | Was Sie einstellen | Benötigte Prüfer |
|---|---|---|---|
| *Offener Beitritt* | Sie die Menschen kennen, die Ihren Code scannen werden. | Nichts. Jeder Bereich erbt den Standard: eine Freigabe durch einen beliebigen Inhaber oder Administrator. Ein Beitritt ist trotzdem nie automatisch. | 1 (Sie) |
| *Beitritte freigeben* | Ein Vorstand entscheidet, wer hereinkommt. | **Neues Mitglied**: **Erforderliche Validierungen** 2, **Inhaber muss immer validieren** an. | 2: ein Inhaber und ein Administrator |
| *Beitritte und Buchungen freigeben* | Plätze oder ganze Räume knapp sind oder Buchungslöschungen einen Zeugen brauchen. | *Beitritte freigeben*, dazu bei **Ganzraum-Reservierungen**, **Zusätzliche Halbtage** und **Buchungslöschung**: **Erforderliche Validierungen** 1. | Mindestens 2, bequem 3 |

Im Verein: Ada ist Inhaberin, Chiara Administratorin. Mit *Beitritte freigeben* bestätigen Ada und Chiara jede neue Person gemeinsam. Mit der dritten Vorlage ist ein ganzer Raum, den Bruno bucht, für ihn sofort blockiert, aber Ada oder Chiara können ihn noch ablehnen, und eine Löschung, die Chiara beantragt, entscheidet Ada, nicht Chiara.

**Schritte**

1. Öffnen Sie [Freigaberegeln](app:/validation).
2. Tippen Sie auf **Neues Mitglied**, stellen Sie ein, was die Tabelle sagt, und tippen Sie auf **Speichern**.
3. Wiederholen Sie das für die dritte Vorlage bei den anderen drei Bereichen.
4. Öffnen Sie **Mitglieder & Tarife** und zählen Sie Ihre aktiven Inhaber und Administratoren. Es müssen mindestens so viele sein wie in der letzten Spalte.

**Gut zu wissen**

- Eine gewöhnliche Buchung eines Mitglieds wird durch diese Vorlagen nie zur Freigabe zurückgehalten. Es warten ein ganzer Raum, zusätzliche Halbtage, eine Löschung und der Beitritt.
- Eine Vorlage ist ein Ausgangspunkt. Erhöhen Sie eine Zahl erst, wenn Sie genug Personen haben, die antworten.

**Siehe auch:** [Erforderliche Validierungen](help:user.validation.required-count) · [Ein Inhaber ist erforderlich](help:user.validation.owner-required)

<!-- anchor: setup.people.stuck -->
### Anfragen vermeiden, die ewig warten

**Zielgruppe:** Inhaber · Mitinhaber

Sie möchten sicher sein, dass jede Anfrage, für die Sie eine Regel anlegen, beantwortet werden kann. Eine Regel, die mehr Prüfer braucht, als es gibt, wird nicht überall abgelehnt: Die Anfrage wird angelegt, niemand kann sie abschließen, und sie verfällt nach sieben Tagen.

> **Achtung** Der Editor zählt einen zusätzlichen Prüfer für die betroffene Person und lässt Sie daher **Erforderliche Validierungen** um eins über den Personen speichern, die Sie haben. Diese zusätzliche Zustimmung gibt es nur bei einer Buchung, die ein Administrator für ein Mitglied gemacht hat, und bei einigen Zahlungen. Bei einem Beitritt oder einer Finanzanfrage gibt es sie nicht. Verlassen Sie sich nicht darauf, dass der Editor für Sie zählt.

*Zählen Sie, bevor Sie verlangen*

| Sie verlangen | Sie brauchen, außer der Person, die fragt |
|---|---|
| 1 | Einen aktiven Inhaber oder Administrator |
| 2 | Zwei aktive Inhaber oder Administratoren |
| 2 mit **Inhaber muss immer validieren** | Einen Inhaber und eine weitere Person |
| Eine Liste **Benannte Personen** | Jede Person darauf muss aktiv sein; ein neuer Administrator wird nicht automatisch hinzugefügt |

*So prüfen Sie es*

1. Öffnen Sie [Freigaberegeln](app:/validation) und lesen Sie jede angepasste Karte: „Alle Admins — beliebige 2“ bedeutet zwei Personen.
2. Öffnen Sie [Mitglieder & Tarife](app:/members). Zählen Sie die aktiven Inhaber und Administratoren. Pausierte und ausgetretene Personen zählen nicht.
3. Öffnen Sie **Einrichtung dieses Workspace** unter [Workspace](app:/workspace-settings). Der Bereich **Rollen und wer Anfragen bestätigt** sagt „Eine Regel verlangt mehr Prüfer, als dieser Bereich hat“, wenn zu wenige gezählt werden. Der Bereich wird dann erforderlich, gleich welche Art von Anfrage, und [Was auf Sie wartet](help:user.collaborate.attention) meldet ihn.
4. Öffnen Sie [Ereignisse](app:/events). **Wartet auf Ihre Bestätigung** zeigt, was wartet, und eine Zeile zeigt „1/2 Validierungen“.

**Gut zu wissen**

- Der Editor selbst sagt **Nicht genügend berechtigte Validierer.**, wenn eine Zahl die verfügbaren Personen deutlich übersteigt. Er fängt nicht jeden Fall ab.
- Ein einzelner Inhaber, der etwas für sich selbst beantragt, wartet auf jemand anderen: Fügen Sie entweder einen Administrator hinzu oder schalten Sie unter **Verkettete Freigaben** **Die Inhaberschaft darf das Eigene freigeben** ein.
- Einen Administrator zu pausieren oder zu entfernen kann eine Regel unterbesetzt zurücklassen. Zählen Sie nach jeder Änderung des Teams neu.

**Ergebnis** Jede Regel kann von Personen beantwortet werden, die es gibt.

**Siehe auch:** [Erforderliche Validierungen](help:user.validation.required-count) · [Stimmig bleiben](help:setup.consistent.overview)

<!-- anchor: setup.people.first-week -->
### Die erste Woche Ihrer Mitglieder

**Zielgruppe:** Inhaber · Administrator:in

Sie möchten, dass Ihre ersten Mitglieder zurechtkommen, ohne Sie zu fragen. Was Sie ihnen in der ersten Woche sagen, entscheidet, wie viel Sie in der zweiten beantworten.

*Bevor Sie jemanden einladen*

1. Melden Sie sich als zweite Person mit einem Testkonto an und treten Sie Ihrem Space bei. Prüfen Sie, dass Sie den Plan öffnen und einen Platz buchen können.
2. Bestätigen Sie dieses Konto als Mitglied, und lassen Sie auch den zweiten Prüfer bestätigen, wenn Sie zwei verlangen.

**Schritte**

1. Senden Sie die Einladungsnachricht. Sie sagt den Personen, wie sie die App herunterladen, ein Konto anlegen und beitreten. Siehe [Einem Workspace beitreten](help:user.start.join).
2. Bestätigen Sie jede neue Person am selben Tag. Wer einen Tag wartet, beginnt mit einem Zweifel.
3. Sagen Sie ihnen die drei ersten Dinge: den Plan und das Buchen ([Einen Platz reservieren](help:user.reserve.book)), das Einchecken ([Ein- und Auschecken](help:user.reserve.check-in)) und wo ihre Anfragen warten ([Ereignisse](help:user.collaborate.events)).
4. Sagen Sie ihnen, was Sie über sie sehen und was sie selbst steuern ([Wer meine Daten sehen kann](help:user.privacy.visibility)).
5. Nennen Sie eine Person, die man fragen kann, und wo: im Messenger oder am Empfang.

**Gut zu wissen**

- Tut ein Administrator etwas für ein Mitglied, bleibt es ausstehend, bis das Mitglied bestätigt. Warnen Sie es, sonst wirkt die erste Buchung, die Sie für jemanden machen, wie ein Fehler.
- Mitglieder, die keine Push-Benachrichtigungen nutzen, finden trotzdem alles unter **Ereignisse**.
- Beim ersten Besuch von Reservieren zeigt die Karte **Erste Schritte** den Inhabern, was noch fehlt. Mitglieder haben ihre eigenen kurzen Tipps. Siehe [Die Karte „Erste Schritte“ und die Tipps](help:user.start.get-started).

**Ergebnis** Personen, die wissen, wie man bucht, wie man eincheckt und wen man fragt.

**Siehe auch:** [Woche 0 bis Woche 4](help:setup.training.overview) · [Wie Mitglieder informiert werden](help:setup.notify.members)
