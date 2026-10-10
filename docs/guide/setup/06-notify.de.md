<!-- anchor: setup.notify.overview -->
## Menschen informieren

Für Inhaber, die möchten, dass Mitglieder und Administratoren von dem erfahren, was wichtig ist, und nur davon. Dieses Kapitel beschreibt, was DesKilo tatsächlich sendet, wer es erhält, was Sie einstellen und was Sie dem Betreiber der Installation überlassen.

In diesem Kapitel:
- Die Kanäle, in einfachen Worten
- Eine Tabelle: was geschieht, wer informiert wird, über welchen Kanal und was ein Mitglied ändern kann
- Was Sie einstellen und was der Betreiber für Push tun muss
- Ein Testplan mit zwei Konten
- Wie Sie sowohl Überflutung als auch Stille vermeiden

<!-- anchor: setup.notify.channels -->
### Die Kanäle, in einfachen Worten

**Zielgruppe:** Inhaber · Administrator:in

Sie möchten ein klares Bild davon, auf welchen Wegen DesKilo eine Person erreichen kann, bevor Sie Ihren Mitgliedern etwas versprechen.

<p><img src="images/setup-notify-features.de.jpg" width="280"></p>

**Bevor Sie beginnen**

Es gibt sechs Wege, und sie sind nicht gleichwertig. Das meiste geschieht innerhalb der App.

| Kanal | Was es ist | Was es braucht |
|---|---|---|
| Der Ereignis-Feed und die Glocke | Alles, was im Space geschieht, wird in einen Feed geschrieben. Die Glocke zählt neue Meldungen und die Entscheidungen, die auf Sie warten. | **Ereignis-Tab**; **Gruppierung der Benachrichtigungen** ist eine Option obendrauf |
| Nachrichten | Private und Gruppenunterhaltungen zwischen Mitgliedern, mit Lesebestätigungen und Links zu einer Buchung oder einem Raum. | **Mitglieder-Benachrichtigungen** |
| Push | Eine kurze Benachrichtigung auf Handy oder Computer, auch bei geschlossener App. Der Text ist allgemein gehalten: keine Namen, keine Uhrzeiten. | **Push-Benachrichtigungen** an, **und** eine Push-Einrichtung durch den Betreiber; siehe [Aufgabe des Betreibers](help:setup.notify.operator) |
| Die Check-in-Erinnerung | Eine Benachrichtigung auf dem eigenen Gerät des Mitglieds, 15 Minuten vor einer Buchung, für die es noch nicht eingecheckt hat. | Die Systemberechtigung des Mitglieds. Nicht in der Browserversion. |
| Zahlungserinnerungen | Ein Hinweis im Feed und ein Push an das Mitglied, dessen Rechnung überfällig ist. | **Mahnwesen** und **Automatische Zahlungserinnerungen**; siehe [Zahlungserinnerungen](help:setup.money.reminders) |
| WhatsApp | Ein Gruppenlink, den Sie veröffentlichen, und die WhatsApp-Nummer, die ein Mitglied freiwillig teilt. Die App öffnet WhatsApp; vom Server wird nichts gesendet. | **WhatsApp-Integration** |

**Gut zu wissen**

- DesKilo versendet keine eigenen E-Mails außer den Konto-E-Mails (Bestätigung der Anmeldung, Zurücksetzen des Passworts). Einladungen sind Texte, die Sie von Ihrem eigenen Handy aus teilen.
- Es gibt keine Abonnements pro Ereignis: Ein Mitglied kann nicht wählen „Informiert mich über Ausgaben, aber nicht über Buchungen“.
- Eine Benachrichtigung kann sich wie jeder Push verspäten oder verloren gehen; der Feed und die Nachrichtenliste sind das Protokoll.

**Siehe auch:** [Benachrichtigungen](help:user.collaborate.notifications) · [Ereignisse & Bestätigungen](help:user.collaborate.events)

<!-- anchor: setup.notify.table -->
### Wer wird worüber informiert

**Zielgruppe:** Inhaber · Administrator:in

Sie möchten Ereignis für Ereignis wissen, wer davon erfährt und wie.

<p><img src="images/setup-notify-events.de.jpg" width="280"></p>

**Bevor Sie beginnen**

Push wird nur für die fünf unten mit „Push“ gekennzeichneten Zeilen gesendet. Jedes andere Ereignis (eine Buchung, eine erfasste Zahlung, ein neues Mitglied) erscheint im Feed und sonst nirgends.

| Quelle | Ereignis | Wer wird informiert | Kanal | Was das Mitglied ändern kann |
|---|---|---|---|---|
| Validierungsregeln | Eine Anfrage braucht eine Bestätigung | Die Personen, die die Regel nennt (Feed, **Wartet auf Ihre Bestätigung**); der Push geht nur an das Mitglied, um das es in der Anfrage geht, nie an die Person, die sie gestellt hat; Validierer erhalten also nur dann einen Push, wenn sie dieses Mitglied sind. Text: „Jemand braucht Ihre Bestätigung.“ | Feed, Glocke; Push | Push auf dem Gerät ausschalten |
| Reservierungen | Ein Administrator entfernt eine Buchung oder setzt sich darüber hinweg | Das verdrängte Mitglied sowie jeder aktive Administrator und Inhaber außer der handelnden Person. Text: „Eine Reservierung wurde von einem Administrator entfernt.“ | Feed; Push | Push auf dem Gerät ausschalten |
| Zahlungserinnerungen | Eine Rechnung ist über das Zahlungsziel hinaus, und eine Mahnstufe wird fällig | Das Mitglied, für das die Rechnung ausgestellt ist. Die eigene Rechnung eines Inhabers erreicht den Inhaber. Text: „Eine Zahlungserinnerung wartet auf Sie.“ | Hinweis im Feed; Push | Push auf dem Gerät ausschalten |
| Mitglieder-Benachrichtigungen | Eine neue Nachricht | Direktnachricht: der Empfänger. Gruppe: die Teilnehmenden außer dem Absender. Eine von einem Mitglied stummgeschaltete Unterhaltung bleibt für dieses Mitglied still. Text: „Sie haben eine neue Nachricht.“ | Nachrichten, Glocke; Push | Unterhaltung stummschalten, anheften oder archivieren; Push ausschalten |
| Erwähnungen in Nachrichten | Eine Gruppennachricht nennt jemanden | Die genannten Personen, auch in einer stummgeschalteten Unterhaltung. Text: „Sie wurden in einer Unterhaltung erwähnt.“ | Nachrichten; Push | Push ausschalten |
| Reservierungen | Eine Buchung steht bevor | Das Mitglied, das gebucht hat, auf seinem eigenen Gerät, 15 Minuten vor Beginn, für Buchungen der nächsten sieben Tage | Lokale Benachrichtigung | Die Systemberechtigung verweigern |
| WhatsApp-Integration | Es wird nichts gesendet | Der Gruppenlink erscheint im Verzeichnis; ein Mitglied kann seine Nummer teilen | Öffnet WhatsApp | Die Nummer teilen oder verbergen |

**Gut zu wissen**

- Ist die App geöffnet, wird ein Push zu einer entfernten Buchung durch eine Benachrichtigung in der Sprache des Mitglieds ersetzt. Bei Nachrichten, Erwähnungen, Bestätigungen und Zahlungserinnerungen zeigt die geöffnete App derzeit ihren allgemeinen Text („Jemand braucht Ihre Bestätigung.“). Die allgemeinen englischen Texte der Tabelle erscheinen, wenn die App im Hintergrund oder geschlossen ist.
- Ein Administrator wird nur über das informiert, worauf er reagiert oder was eine Regel ihm zuweist; es gibt keine Gesamtübersicht über „alles“.
- Mitglieder sehen ihre eigenen Ereignisse; Administratoren und Inhaber sehen die aller.

**Siehe auch:** [Validierungsregeln](help:user.validation.overview) · [Nachrichten](help:user.collaborate.messages)

<!-- anchor: setup.notify.configure -->
### Was Sie einstellen

**Zielgruppe:** Inhaber

Sie entscheiden, welche dieser Kanäle in Ihrem Space existieren und wer worüber entscheiden soll.

<p><img src="images/setup-notify-validation.de.jpg" width="280"></p>

**Schritte**

1. Öffnen Sie [Funktionen](help:user.features.switch) und prüfen Sie die Schalter für Benachrichtigungen: **Push-Benachrichtigungen**, **Mitglieder-Benachrichtigungen**, **Ereignis-Tab**, **Gruppierung der Benachrichtigungen**, **Mahnwesen**, **Automatische Zahlungserinnerungen** und **WhatsApp-Integration**.
2. Legen Sie die [Validierungsregeln](help:user.validation.overview) fest: für jede Art von Anfrage, wie viele Validierungen nötig sind und wer sie geben darf. Das bestimmt, wer gefragt wird und damit, wer eine wartende Entscheidung sieht.
3. Entscheiden Sie, ob die eigene Anfrage eines Administrators oder Inhabers sich selbst erledigt; siehe [Eigene Anfrage eines Administrators automatisch validieren](help:user.validation.auto-validate-admin) und [Eigene Anfrage eines Inhabers automatisch validieren](help:user.validation.auto-validate-owner). Eine bereits erledigte Anfrage meldet sich bei niemandem.
4. Schreiben Sie die Einladungsnachricht, die Mitglieder erhalten, und fügen Sie den Link zur Community-Gruppe ein; siehe [Einladungsnachricht](help:user.workspace.settings.invitation-message) und [WhatsApp-Gruppe](help:user.workspace.settings.whatsapp-group).
5. Schalten Sie **Lösch-Anträge für Buchungen** ein, wenn Mitglieder beantragen dürfen, eine vergangene oder eingecheckte Buchung zu löschen: Dann muss jemand antworten.

**Gut zu wissen**

- Voreinstellungen für einen neuen Space: Der Ereignis-Tab, die Mitglieder-Benachrichtigungen und die Gruppierung sind an; **Mahnwesen** und **Automatische Zahlungserinnerungen** sind als Funktionen an, aber es wird keine Mahnung gesendet, bis Sie **Automatische Mahnungen** in den Mahnregeln einschalten.
- **Push-Benachrichtigungen** ist standardmäßig an, liefert aber nichts, bis der Betreiber es eingerichtet hat.
- Eine Funktion auszuschalten stoppt neue Aktivität dieser Art. Vorhandenes wird nicht gelöscht.
- Rollen bestimmen, wer was sehen und beantworten kann; siehe [Die Rollenmatrix](help:user.roles.matrix).

**Siehe auch:** [Wer darf validieren](help:user.validation.who-may) · [Erforderliche Validierungen](help:user.validation.required-count)

<!-- anchor: setup.notify.operator -->
### Aufgabe des Betreibers: Push zum Laufen bringen

**Zielgruppe:** Betreiber:in · Inhaber

Sie möchten Push auf den Handys Ihrer Mitglieder und müssen wissen, wer was tut.

**Bevor Sie beginnen**

Push gehört nicht von selbst zur App. Betreiben Sie Ihren Space auf der gemeinsamen Referenzinstallation, fragen Sie deren Betreiber, ob Push eingerichtet ist. Betreiben Sie eine eigene Installation, sind Sie oder Ihre technische Ansprechperson der Betreiber.

**Schritte**

1. Legen Sie ein Firebase-Projekt an und bauen Sie die App damit. Ohne das bleibt die App bei lokalen Benachrichtigungen, und ein Mitglied sieht **Diese Version hat keine Push-Benachrichtigungen**. Die für F-Droid vorbereitete Version hat gar kein Push ([F-Droid-Status](https://github.com/fdittgen-png/deskilo/blob/master/docs/guides/fdroid.md#status)).
2. Fügen Sie für iPhone und Mac dem Firebase-Projekt einen Apple-Push-Schlüssel hinzu.
3. Hinterlegen Sie den Dienstkonto-Schlüssel von Firebase als Geheimnis des Servers und stellen Sie die Push-Funktion bereit.
4. Verweisen Sie bei einer eigenen Installation die Zeile `push_config` Ihrer Datenbank auf die URL und den Schlüssel Ihrer eigenen Push-Funktion. Sie ist mit der Adresse der Referenzinstallation vorbelegt.
5. Testen Sie mit zwei Konten, wie im [Testplan](help:setup.notify.test) beschrieben.

**Gut zu wissen**

- Ohne die Schritte 1 bis 4 wird nichts gepusht, was die Schalter auch sagen. Der Feed, die Glocke und die Nachrichten funktionieren weiterhin.
- Die ausführliche Checkliste ist für den Betreiber: siehe [Plattformen](help:user.advanced.platforms) und [Ihr eigener Server](help:user.advanced.own-server).
- Der Push-Text enthält nie einen Namen oder eine Uhrzeit: Das ist Absicht, aus Datenschutzgründen.

**Siehe auch:** [Push-Benachrichtigungen auf diesem Gerät](help:user.privacy.push)

<!-- anchor: setup.notify.members -->
### Was Mitglieder selbst steuern

**Zielgruppe:** Inhaber · Administrator:in

Sie möchten Ihren Mitgliedern ehrlich sagen, was sie ausschalten können.

<p><img src="images/setup-notify-push.de.jpg" width="280"></p>

**Schritte**

1. Ein Mitglied öffnet [Datenschutz & Daten](app:/privacy) und stoppt oder setzt Push auf diesem Gerät mit **Push-Benachrichtigungen auf diesem Gerät** fort.
2. In [Nachrichten](app:/me?tab=messages) drückt ein Mitglied lange auf eine Unterhaltung, um sie mit **Oben anheften**, **Benachrichtigungen stumm**, **Als ungelesen markieren** oder **Archivieren** zu verwalten.
3. In den Systemeinstellungen des Handys kann ein Mitglied Benachrichtigungen ganz verweigern, auch die Check-in-Erinnerungen.
4. In seinem Profil entscheidet ein Mitglied, ob es eine WhatsApp-Nummer teilt.

**Gut zu wissen**

- Eine stummgeschaltete Unterhaltung bleibt still, wird aber weiter mitgezählt; eine Erwähnung hebt die Stummschaltung auf.
- Wer Push auf einem Gerät ausschaltet, ist auf einem anderen nicht betroffen.
- Es gibt keine Schalter pro Kategorie. Braucht ein Mitglied weniger Lärm, schaltet es Unterhaltungen stumm; braucht es keinen, schaltet es Push aus.

**Siehe auch:** [Benachrichtigungen](help:user.collaborate.notifications) · [Ihre Daten, Ihre Rechte](help:user.privacy.consent)

<!-- anchor: setup.notify.test -->
### Ein Testplan: Senden Sie sich von jedem eine

**Zielgruppe:** Inhaber · Administrator:in · Betreiber:in

Sie stellen sicher, dass jeder Kanal funktioniert, bevor Ihre Mitglieder sich darauf verlassen.

**Bevor Sie beginnen**

Tun Sie das in einem Test-Space (siehe [einen gefahrlosen Probelauf](help:setup.money.dry-run)). Sie brauchen zwei Konten: Ihres als Inhaber und ein zweites als Mitglied, auf einem anderen Handy, in einem anderen Browser oder auf demselben Handy nach dem Abmelden. Der Demo-Space zeigt Ihnen die Bildschirme mit seinen Personas, sendet aber keinen echten Push.

**Schritte**

1. Nachricht: Schreiben Sie vom Mitgliedskonto aus in [Nachrichten](app:/me?tab=messages) an den Inhaber. Im Inhaberkonto zählt die Glocke sie, und die Unterhaltung erscheint ungelesen. Öffnen Sie sie: Die Nachricht des Mitglieds zeigt eine Lesebestätigung.
2. Erwähnung: Nennen Sie in einer Gruppenunterhaltung den Inhaber (die Erwähnungsfunktion des Nachrichtendienstes muss an sein). Ist Push eingerichtet, zeigt das Handy des Inhabers „Sie wurden in einer Unterhaltung erwähnt.“
3. Entscheidung: Beantragen Sie als Mitglied das Löschen einer vergangenen Buchung (die Funktion **Lösch-Anträge für Buchungen** muss an sein). Der Inhaber sieht den Antrag unter **Wartet auf Ihre Bestätigung** in [Ereignisse](app:/events); beantworten Sie ihn und beobachten Sie, wie sich der Feed des Mitglieds ändert.
4. Entfernung: Entfernen Sie als Inhaber eine künftige Buchung des Mitglieds. Der Feed des Mitglieds zeigt es, und ein Handy mit Push zeigt „Eine Reservierung wurde von einem Administrator entfernt.“
5. Erinnerung: Buchen Sie als Mitglied einen Platz, der in etwa 20 Minuten beginnt (eine Buchung, die in weniger als 15 Minuten beginnt, erhält keine Erinnerung). Etwa 15 Minuten vor Beginn zeigt das Handy des Mitglieds die Check-in-Erinnerung.
6. Zahlungserinnerung: Schalten Sie bei eingeschaltetem **Mahnwesen** in den Mahnregeln **Automatische Mahnungen** mit einer kurzen Frist bis zur ersten Mahnung ein, stellen Sie eine Probe-Rechnung mit Zahlungsziel aus, warten Sie die Frist ab und öffnen Sie dann als Inhaber oder Mitinhaber die Finanzen; der Feed des Mitglieds zeigt den Hinweis.
7. Stummschalten: Schalten Sie als Mitglied die Unterhaltung stumm, senden Sie vom Inhaber eine weitere Nachricht und prüfen Sie, dass nichts klingelt, der Zähler für Ungelesenes aber steigt.

**Gut zu wissen**

- Die Schritte 2 und 4 zeigen nur dann einen Push, wenn die Einrichtung des Betreibers vollständig ist. Scheitern sie, während die anderen funktionieren, liegt der Fehler in der Einrichtung, nicht in Ihren Regeln.
- In der Browserversion der App gibt es keine Check-in-Erinnerung.
- Ein Handy, das Benachrichtigungen blockiert, zeigt überhaupt nichts; prüfen Sie zuerst die Systemeinstellungen.

**Ergebnis**

Sie haben mit eigenen Augen jeden Kanal gesehen, auf den sich ein Mitglied verlassen wird.

**Siehe auch:** [Die Kanäle](help:setup.notify.channels) · [Eine Unterhaltung oder Gruppe beginnen](help:user.collaborate.messages-new)

<!-- anchor: setup.notify.silence -->
### Überflutung vermeiden, und Stille vermeiden

**Zielgruppe:** Inhaber · Administrator:in

Sie möchten, dass Menschen erfahren, was sie betrifft, und nicht überschüttet werden.

**Schritte**

1. Lassen Sie **Gruppierung der Benachrichtigungen** an: Mitglieder und Administratoren können den Feed nach Art, Tag oder Mitglied zusammenfalten.
2. Verlangen Sie eine Validierung nur dort, wo eine Entscheidung wirklich nötig ist: Jede Regel, die eine Validierung verlangt, erzeugt eine Anfrage, die jemand beantworten muss. Siehe [Validierungsregeln](help:user.validation.overview).
3. Nutzen Sie die Schalter für die automatische Validierung bei Anfragen, deren Antwort offensichtlich ist.
4. Sehen Sie ab und zu bei [Was auf Sie wartet](help:user.collaborate.attention) vorbei: Dort ist gereiht, was wartet.

**Gut zu wissen**

- Überflutung entsteht durch Regeln, die zu oft fragen, oder durch zu viele Administratoren für eine Regel.
- Stille entsteht durch eine Regel, die niemand beantworten kann: Verlangen Sie zwei Validierungen, obwohl es nur den Inhaber gibt, oder nennen Sie Administratoren, die gegangen sind, bleiben Anfragen für immer offen. Die Karte zur Einrichtungsbereitschaft kann eine Buchungsregel mit zu wenigen Validierern anzeigen.
- Stille entsteht auch durch Push ohne Einrichtung, durch Mitglieder, die Push ausgeschaltet haben, und durch ein System, das Benachrichtigungen blockiert.
- Automatische Zahlungserinnerungen ersetzen nicht den gelegentlichen Blick auf die offenen Rechnungen.

**Siehe auch:** [Wer darf validieren](help:user.validation.who-may) · [Erforderliche Validierungen](help:user.validation.required-count)
