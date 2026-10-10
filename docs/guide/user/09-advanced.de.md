<!-- anchor: user.advanced.overview -->
## Erweitert

**Zielgruppe:** Inhaber · Betreiber:in

Das, was die tägliche Arbeit umgibt: die Testseite eines Space und die echte, Assistenten, der Aufgabenrekorder mit seinen geführten Touren, die Demo, die Apps auf jedem Gerät und was zu tun ist, wenn etwas nicht funktioniert.

In diesem Kapitel:
- [Ein Space hat zwei Seiten](help:user.advanced.environments) · [Eine Seite betreten](help:user.advanced.enter-environment) · [Ein Testspace](help:user.advanced.test-space) · [Wer ausrollen darf](help:user.advanced.deploy-permissions) · [Zwischen den Seiten ausrollen](help:user.advanced.deploy) · [Status des Workspace und das Jahresarchiv](help:user.advanced.status-archive)
- [Ihr eigener Server](help:user.advanced.own-server)
- [Assistenten](help:user.advanced.assistants) · [Einen Assistenten verbinden](help:user.advanced.assistants-connect) · [Freigaben](help:user.advanced.assistants-approve) · [Was Assistenten dürfen](help:user.advanced.assistants-policy)
- [Der Aufgabenrekorder](help:user.advanced.recorder) · [Eine Aufgabe aufzeichnen](help:user.advanced.recorder-record) · [Eine Aufzeichnung prüfen](help:user.advanced.recorder-review) · [Eine Anleitung erstellen](help:user.advanced.guide-make) · [Einer Anleitung folgen](help:user.advanced.guide-play) · [Das Kreismenü](help:user.advanced.guide-circle) · [Eine Anleitung bearbeiten](help:user.advanced.guide-edit) · [Datenschutz der Aufzeichnungen](help:user.advanced.recorder-privacy)
- [Der Demo-Workspace](help:user.advanced.demo) · [Aufnahmemodus](help:user.advanced.filming)
- [Plattformen](help:user.advanced.platforms) · [Supportdetails](help:user.advanced.support) · [Wenn etwas nicht funktioniert](help:user.advanced.troubleshooting)
- [Die Wörter der App](help:user.advanced.glossary) · [Barrierefreiheit und Tastatur](help:user.advanced.accessibility) · [Mehr Hilfe](help:user.advanced.help)

<!-- anchor: user.advanced.environments -->
### Ein Space hat zwei Seiten

**Zielgruppe:** Inhaber

Sie möchten einen Ort zum Ausprobieren, ohne die echten Buchungen und Rechnungen anzufassen. Ein Space kann als Paar angelegt werden: eine Testseite und eine echte Seite mit demselben Namen.

<p><img src="images/user-advanced-environments.de.jpg" width="280"></p>

**Schritte**

1. Lassen Sie beim Anlegen eines Space **Das Paar Entwicklung und Produktion anlegen** angehakt. Beide Seiten gehören Ihnen von der ersten Sekunde an.
2. Sie haben schon einen einzelnen Space? Öffnen Sie die [Einstellungen](app:/settings), gehen Sie zu **Governance** und tippen Sie auf **Zwilling anlegen**. Die Konfiguration wird einmal kopiert.
3. Ab dann sind die beiden Seiten unabhängig. Nur eine Ausrollung bringt etwas von der einen auf die andere.

**Gut zu wissen**

- Die Entwicklungsseite heißt **Entwicklung — zum Ausprobieren**. Die Produktionsseite heißt **Produktion — die Rechnungen sind geschuldet**.
- Jedes auf der Entwicklungsseite gedruckte Dokument trägt ein Wasserzeichen, damit es nicht mit einem echten verwechselt wird.
- **Zwilling anlegen** erscheint nur, wenn die Funktion **Umgebungspaare** eingeschaltet ist, und nur für den Inhaber. Das Ausspielen zwischen den Seiten liegt bei den Inhabern der Deploy-Berechtigungen.
- Mitglieder, Buchungen, Rechnungen und Zahlungen werden nie zwischen den Seiten kopiert.

**Siehe auch:** [Eine Seite betreten](help:user.advanced.enter-environment) · [Ein Testspace](help:user.advanced.test-space)

<!-- anchor: user.advanced.enter-environment -->
### Die echte oder die Testseite betreten

**Zielgruppe:** Alle

Sie möchten einen Space auf der Seite öffnen, die Sie brauchen. Ihr Konto sieht beide Seiten eines Paars, jede mit einer eigenen Schaltfläche.

**Schritte**

1. Öffnen Sie [Ich](app:/me) und suchen Sie den Space unter **Meine Spaces**.
2. Tippen Sie auf **Arbeitsbereich öffnen** für die echte Seite oder auf **Testbereich** für die Seite zum Üben.
3. Oder öffnen Sie die [Profile](app:/profiles): Das Paar ist eine Karte. Tippen Sie darauf, dann auf **Umgebung wählen** zwischen **DEV** und **PROD**.

**Gut zu wissen**

- Eine Seite, die Sie nicht betreten dürfen, ist ausgegraut und tut nichts.
- Wer Mitglied der echten Seite ist, ist immer auch Mitglied der Testseite.
- Die Test-Schaltfläche trägt den Hinweis „Testbereich: Übungsbuchungen und -rechnungen“; die echte „Echte Buchungen und Rechnungen“.

**Siehe auch:** [Wer ausrollen darf](help:user.advanced.deploy-permissions)

<!-- anchor: user.advanced.test-space -->
### Wofür ein Testspace da ist

**Zielgruppe:** Inhaber

Sie wollen Preise, Regeln oder den Plan ändern und zuerst die Wirkung sehen. Tun Sie es im Testspace.

**Schritte**

1. Betreten Sie die Testseite mit **Testbereich**.
2. Konfigurieren Sie, importieren Sie eine Space-Datei, laden Sie eine Kollegin oder einen Kollegen ein, stellen Sie eine Probe-Rechnung aus, verschieben Sie Plätze, drucken Sie.
3. Wenn alles stimmt, [rollen Sie es auf die echte Seite aus](help:user.advanced.deploy).

**Gut zu wissen**

- Der Schalter **Art des Space** in den [Einstellungen](app:/settings) (unter **Governance**) sagt, welche Art ein Space ist. Nur Inhaber sehen ihn.
- Wenn Sie einen Space zur Produktion erklären, fragt die App **Diesen Space zur Produktion erklären?** — das Banner verschwindet und Dokumente verlieren ihr Wasserzeichen. Bereits ausgestellte Rechnungen behalten das Wasserzeichen, das sie hatten.
- Erklären Sie einen Space nur dann zur Produktion, wenn die Rechnungen, die ihn verlassen, wirklich geschuldet sind.
- Wenn Sie jemanden einladen, können Sie wählen, ob die Person auch den Produktions-Space erreicht: **Testbereich** oder **Produktions-Workspace**. Dem Testspace tritt sie in jedem Fall bei.

**Siehe auch:** [Ein Space hat zwei Seiten](help:user.advanced.environments)

<!-- anchor: user.advanced.deploy-permissions -->
### Wer ausrollen und in die Produktion darf

**Zielgruppe:** Inhaber · Mitinhaber

Sie entscheiden, wer die echte Seite anfassen darf. Drei Berechtigungen in der Rollenmatrix steuern das.

**Schritte**

1. Öffnen Sie die [Rollen](app:/roles).
2. Suchen Sie **Den Produktionsraum betreten**, **In die Entwicklung ausrollen** und **In die Produktion ausrollen**.
3. Schalten Sie jede für die Rollen ein, die sie brauchen.

**Gut zu wissen**

- Inhaber und Mitinhaber haben alle drei. Administratoren haben **In die Entwicklung ausrollen** und **Den Produktionsraum betreten**. Mitglieder haben keine, bis Sie sie vergeben.
- Wer in die Produktion ausrollen darf, darf immer auch in die Entwicklung ausrollen.
- Eine Rolle betritt die Produktionsseite nur, solange sie **Den Produktionsraum betreten** hat: Eine Einladung oder ein Beitritt in die Produktion wird sonst abgelehnt, und die App sagt warum.

**Siehe auch:** [Die Rollenmatrix](help:user.roles.matrix) · [Zwischen den Seiten ausrollen](help:user.advanced.deploy)

<!-- anchor: user.advanced.deploy -->
### Zwischen den beiden Seiten ausrollen

**Zielgruppe:** Inhaber · Mitinhaber · Administrator:in

Sie haben die Konfiguration auf einer Seite festgelegt und möchten, dass die andere sie bekommt.

**Schritte**

1. Stellen Sie sich auf die Seite, in die geschrieben werden soll, und öffnen Sie [Einstellungen](app:/settings) → **Governance** → [Ausrollung](app:/deployment).
2. Haken Sie an, was mitreisen soll. Die Objekte sind gruppiert als **Konfiguration**, **Stammdaten** und **Berichte**; was ein Objekt **braucht**, wird mit angehakt.
3. Tippen Sie auf **Aus der PROD holen…** (von der Entwicklungsseite aus) oder **Aus der DEV holen…** (von der Produktionsseite aus).
4. Lesen Sie die Vorschau: **Was sich auf der Produktionsseite ändert**, oder auf der Entwicklungsseite. Wenn beide Seiten übereinstimmen, steht dort **Keine Änderung**.
5. Bestätigen Sie. Die Frage nennt die Seite, in die geschrieben wird: **In diese DEV ausrollen?** oder **In diese PROD ausrollen?**

**Gut zu wissen**

- Eine Ausrollung geht immer in die Seite, auf der Sie stehen. Nichts kann versehentlich auf die andere Seite geschoben werden.
- Jede Ausrollung landet im **Journal**. **Zurückrollen** bei der letzten stellt wieder her, was die Seite vorher hatte.
- Raumpläne werden zusammengeführt: Was nur diese Seite hat, bleibt erhalten, weil ein Platz eine Buchung tragen kann. Badge-Tags reisen nie mit.
- Mitglieder, Buchungen, Rechnungen, Zahlungen, Ereignisse und Zugangsdaten reisen nie mit.
- Der Eintrag erscheint nur, wenn die Funktion **Ausrollungen** eingeschaltet ist, der Space einen Zwilling hat und Sie eine Ausroll-Berechtigung haben.

**Siehe auch:** [Wer ausrollen darf](help:user.advanced.deploy-permissions)

<!-- anchor: user.advanced.status-archive -->
### Status des Workspace und das Jahresarchiv

**Zielgruppe:** Inhaber · Administrator:in · Abrechnungsadministrator:in

Sie möchten auf einen Blick sehen, was der Space in Rechnung gestellt und eingenommen hat, und eine vollständige Datei des Jahres für Ihre Unterlagen.

**Schritte**

1. Öffnen Sie die [Lage des Arbeitsbereichs](app:/money/status). Wählen Sie die Monate bei **Von** und **Bis**.
2. Lesen Sie **Fakturiert**, **Gutschriften**, **Zugeordnete Zahlungen**, **Eingegangene Zahlungen**, **Erstattete Ausgaben**, **Umgelegte Ausgaben** und **Gewährte Gutschriften**; **Netto** fasst es zusammen. Tippen Sie auf den Drucker, um die **Lage drucken**.
3. Wählen Sie für die Jahresdatei in den Rechnungsexporten **Jahresarchiv (zip)**.

**Gut zu wissen**

- **Netto** ist weder ein Gewinn noch ein Kontostand. Zugeordnete und eingegangene Zahlungen überschneiden sich, addieren Sie sie also nicht.
- Die Lage erscheint, wenn die Funktion **Lage des Arbeitsbereichs** eingeschaltet ist.
- Ein Entwicklungsspace erzeugt mit DEV gekennzeichnete Dateien: Sie sind nicht die echten Bücher.

**Siehe auch:** [Workspace-Bericht](help:user.workspace.export.workspace-report)

<!-- anchor: user.advanced.own-server -->
### Einen eigenen Server betreiben

**Zielgruppe:** Betreiber:in · Inhaber

Sie möchten die Daten Ihrer Gemeinschaft auf einem Server, den Sie kontrollieren, oder Sie gehören einer Organisation an, die einen betreibt.

**Schritte**

1. Lesen Sie unter [So betreiben Sie Ihren eigenen](help:user.backend.how), wie ein Server eingerichtet wird.
2. Richten Sie die App auf jedem Gerät darauf aus: [Ihr eigener Server](help:user.backend.server).
3. Prüfen Sie [Ich](app:/me) → **Wo meine Spaces liegen**: Dort stehen die Server, die dieses Konto nutzt.

**Gut zu wissen**

- Die App zeigt für die Anmeldung auf einen Server; **Dieses Gerät nutzt** zeigt, auf welchen. Die weiteren Server, denen Sie angehören, erscheinen unter **Wo meine Spaces liegen**.
- Eine Einladung wird nur auf ihrem eigenen Server geprüft, treten Sie einem Space also bei, während die App auf den Server zeigt, der sie ausgestellt hat.
- Ein Betreiber kann Assistenten für die ganze Installation einschalten — siehe [Freigaben](help:user.advanced.assistants-approve).

**Siehe auch:** [Ihr eigener Server](help:user.backend.server)

<!-- anchor: user.advanced.assistants -->
### Assistenten: was sie sind

**Zielgruppe:** Alle

Ein KI-Assistent wie Claude oder ChatGPT kann in DesKilo Dinge für Sie nachsehen und buchen. Er handelt als Sie, nur in den Workspaces und für die Aktionen, die Sie freigeben.

<p><img src="images/user-advanced-assistants-policy.de.jpg" width="280"></p>

**Schritte**

1. Öffnen Sie die [Assistenten](app:/assistants). **Wo Sie hier stehen** listet, was für Sie noch fehlt: **Anmeldung mit Google**, **Identität für Assistenten**, **Freigabe der Datenbank**, **Angebot des Arbeitsbereichs**, **Ihre Rolle**, **Ihre Zustimmung**, **Server**.
2. Arbeiten Sie die Liste ab; jede Zeile sagt, wer den nächsten Schritt tut.

**Gut zu wissen**

- Mehrere Personen wirken mit: Sie, die Inhaberin oder ein Administrator des Workspace, eine Datenbankadministratorin und der Betreiber der Installation. Keine einzelne Person kann alles öffnen.
- Das Einschalten von Assistenten gibt für sich allein niemandem etwas.
- Unter **Verbundene Assistenten** sehen Sie, was verbunden ist, und können es **Trennen**. **Ihre Nutzung durch Assistenten heute** zählt **Anfragen**, **Abgelehnt**, **Ausgeführt** und **Wartet auf Validierung**.

**Siehe auch:** [Einen Assistenten verbinden](help:user.advanced.assistants-connect)

<!-- anchor: user.advanced.assistants-connect -->
### Einen Assistenten verbinden

**Zielgruppe:** Mitglied · Administrator:in · Inhaber

Sie möchten, dass Ihr Assistent mit Ihren eigenen Buchungen und Ihrem Konto arbeitet.

**Schritte**

1. Öffnen Sie [Einen Assistenten verbinden](app:/assistants/connect). Unter **Bevor Sie verbinden** sollte jede Zeile **Erledigt** sagen.
2. Wählen Sie unter **Welchen Assistenten verwenden Sie?** **Claude**, **Claude Code**, **ChatGPT**, **Cursor**, **VS Code** oder **Andere**. Kopieren Sie **Ihre DesKilo-Adresse für Assistenten** dort hinein, wie die Schritte zeigen.
3. Melden Sie sich an, wenn der Assistent fragt, und wählen Sie dann diesen Workspace und was der Assistent dort tun darf.
4. Tippen Sie auf **Verbindung testen** und fragen Sie Ihren Assistenten: „Was sind mit DesKilo meine Buchungen diese Woche?“

**Gut zu wissen**

- Der Assistent selbst bittet Sie, den Workspace und jede Art von Vorgang freizugeben; nichts wird für Sie entschieden.
- Zum Verbinden braucht der Workspace die Funktion **MCP-Schnittstelle**. Ist sie aus, schickt der Bildschirm Sie zu den Assistenten.
- Es klappt nicht? **Verbindung testen** sagt, worauf noch gewartet wird.
- **Trennen** entfernt den Assistenten aus jedem Workspace dieser Datenbank. Was er schon gelesen hat, wird nicht zurückgenommen.

**Siehe auch:** [Freigaben](help:user.advanced.assistants-approve)

<!-- anchor: user.advanced.assistants-approve -->
### Freigaben und Bestätigungen für Assistenten

**Zielgruppe:** Inhaber · Betreiber:in

Assistenten werden in Schichten freigegeben, damit eine Person nicht allein einen einschalten kann.

**Schritte**

1. Der Inhaber des Workspace (oder wer die Integrationen verwaltet) öffnet die [Assistenten-Einrichtung](app:/settings/assistant-setup) und arbeitet sie ab: **Assistenten für diesen Arbeitsbereich einschalten**, **Festlegen, was Assistenten dürfen**.
2. Jedes Mitglied fragt einmal: **Freigabe anfragen**. Eine Datenbankadministratorin entscheidet in den [Assistenten-Freigaben](app:/database/assistant-approvals) mit **Freigeben** oder **Ablehnen**.
3. Der Betreiber der Installation öffnet [Installation: Assistenten](app:/installation/assistants) und tippt auf **Für alle Arbeitsbereiche einschalten**. Die Seite listet außerdem **Datenbankadministratoren** und **Assistenten-Clients**, jeweils **Freigegeben**, **Gesperrt** oder **Wartet auf Freigabe**.
4. Sendet ein Assistent eine Anfrage mit großer Tragweite, werden Sie gefragt: **Anfrage eines Assistenten bestätigen**. **Bestätigen** lässt ihn genau diese Anfrage einmal senden; **Ablehnen** tut nichts.

**Gut zu wissen**

- Freigaben und die Änderungen der Installation brauchen Ihren zweiten Faktor.
- Die Freigabe läuft ab; der Bildschirm nennt die verbleibenden Tage, und Sie fragen erneut an.
- Eine bestätigte Anfrage folgt weiterhin den Validierungsregeln des Workspace.
- Gibt es keine andere Datenbankadministratorin, gibt der Betreiber den Zugang mit einer Begründung für bis zu 30 Tage frei.

**Siehe auch:** [Was Assistenten dürfen](help:user.advanced.assistants-policy)

<!-- anchor: user.advanced.assistants-policy -->
### Was Assistenten in einem Workspace dürfen

**Zielgruppe:** Inhaber · Administrator:in

Sie entscheiden, welche Dienste ein Workspace Assistenten anbietet.

**Schritte**

1. Öffnen Sie den [Assistentenzugriff](app:/settings/assistants).
2. Schalten Sie **Assistentendienste anbieten** ein.
3. Wählen Sie unter **Daten, auf die ein Assistent zugreifen darf** **Nur eigene Daten** oder **Ganzer Arbeitsbereich**.
4. Haken Sie die Vorgänge an, in Gruppen: **Eigene Buchungen und Konto**, **Finanzanfragen**, **Mitgliedschaftsanfragen**, **Freigaben**.
5. Tippen Sie auf **Speichern**.

**Gut zu wissen**

- Die Vorgänge lauten etwa „Freie Plätze ansehen“, „Einen Platz für Sie buchen“, „Sie einchecken“ oder „Ihre noch nicht begonnenen Buchungen stornieren“.
- Assistenten erhalten reduzierte Antworten. Mit den **Optionalen Angaben** erlauben Sie mehr; jede Person entscheidet dennoch selbst.
- Bereits verbundene Assistenten erhalten neue Dienste erst, wenn jede Person erneut freigibt.
- Schalten Sie zuerst die Funktion **MCP-Schnittstelle** unter [Funktionen](app:/features) ein. Sie ist standardmäßig aus.
- Das ist für Personen mit der Integrations-Berechtigung; Inhaber haben sie immer.

**Siehe auch:** [Ein Funktionsschalter](help:user.features.switch)

<!-- anchor: user.advanced.recorder -->
### Der Aufgabenrekorder und geführte Touren

**Zielgruppe:** Alle

Sie möchten jemandem zeigen, wie eine Aufgabe geht, oder es selbst gezeigt bekommen. Zeichnen Sie die Aufgabe einmal auf, machen Sie daraus eine Anleitung und folgen Sie ihr Schritt für Schritt in der echten App.

<p><img src="images/user-advanced-wizard.de.jpg" width="280"></p>

**Schritte**

1. Öffnen Sie den [Aufgaben-Assistenten](app:/task-wizard): im Menü auf einem breiten Bildschirm oder unter **Erweitert** in [Ich](app:/me).
2. **Anleitungen** enthält Ihre eigenen Anleitungen und die mitgelieferten, etwa **Einen Platz buchen**.
3. **Aufzeichnungen** listet die Aufgaben, die Sie aufgezeichnet haben, und **Eine Aufgabe aufzeichnen** startet eine neue.
4. **Werkzeuge** öffnet eine Aufgabendatei ohne Konto.

**Gut zu wissen**

- Alles bleibt auf Ihrem Gerät, bis Sie es exportieren.
- Der Aufgabenrekorder ist eine Funktion (**Aufgabenrekorder**). Ist sie aus, erscheint der Aufgaben-Assistent nicht in den Menüs.
- Zum Aufzeichnen oder zum Befolgen einer Anleitung müssen Sie angemeldet sein.

**Siehe auch:** [Eine Aufgabe aufzeichnen](help:user.advanced.recorder-record) · [Einer Anleitung folgen](help:user.advanced.guide-play)

<!-- anchor: user.advanced.recorder-record -->
### Eine Aufgabe aufzeichnen

**Zielgruppe:** Alle

Sie möchten festhalten, was Sie tun, damit daraus ein Dokument oder eine Anleitung werden kann.

<p><img src="images/user-advanced-record.de.jpg" width="280"></p>

**Schritte**

1. Lesen Sie im [Aufgabenrekorder](app:/task-recorder) **Bevor Sie aufzeichnen**.
2. Tippen Sie auf **Aufzeichnung starten**.
3. Erledigen Sie die Aufgabe wie gewohnt, auf einem beliebigen Bildschirm des Space oder von [Ich](app:/me).
4. Nutzen Sie die Leiste mit der Anzeige **Aufzeichnung läuft**, um zu **Pausieren**, **Fortsetzen**, eine **Notiz hinzufügen** oder zu **Beenden**.

**Gut zu wissen**

- Eine Aufzeichnung dauert bis zu 500 Schritte oder 30 Minuten und wird nach 30 Tagen vom Gerät gelöscht. Eine exportierte Datei bleibt dort, wo Sie sie gespeichert haben.
- Jeder Schritt nennt den Bildschirm, die Aktion und was die App geantwortet hat, etwa **Gebucht** oder **Abgelehnt**.
- Anmeldung, Zahlung, Nachrichten und andere geschützte Bildschirme hinterlassen nur eine Markierung.
- Wechseln Sie zu einem anderen Konto oder Workspace, endet die Aufzeichnung.

**Siehe auch:** [Datenschutz der Aufzeichnungen](help:user.advanced.recorder-privacy)

<!-- anchor: user.advanced.recorder-review -->
### Eine Aufzeichnung prüfen, bearbeiten und exportieren

**Zielgruppe:** Alle

Sie möchten prüfen, was erfasst wurde, bevor Sie es teilen.

**Schritte**

1. Tippen Sie im [Aufgaben-Assistenten](app:/task-wizard) unter **Aufzeichnungen** auf eine Aufzeichnung.
2. Lesen Sie die Schritte. Tippen Sie bei jedem Schritt, den Sie nicht wollen, auf **Vom Export ausnehmen**; **Wieder aufnehmen** holt ihn zurück.
3. Sehen Sie sich **Was die Datei enthalten wird** an.
4. Wählen Sie **Datei exportieren**, **Aufgabenpaket exportieren** oder **Als Word-Dokument exportieren**.

**Gut zu wissen**

- Das Ausnehmen eines Schritts ändert nur den Export. Die Aufzeichnung auf dem Gerät bleibt unverändert.
- Um eine Datei von jemand anderem zu lesen, nutzen Sie **Aufgabendatei öffnen** in der [Aufgaben-Werkbank](app:/task-workbench). Nichts wird hochgeladen, und es ist kein Konto nötig.
- Eine beschädigte Datei oder eine Datei, die eine neuere Version erstellt hat, wird mit einer klaren Meldung abgelehnt.
- **Von diesem Gerät löschen** entfernt die Aufzeichnung; exportierte Dateien bleiben unberührt.

**Siehe auch:** [Eine Anleitung erstellen](help:user.advanced.guide-make)

<!-- anchor: user.advanced.guide-make -->
### Aus einer Aufzeichnung eine Anleitung erstellen

**Zielgruppe:** Alle

Sie möchten, dass andere einer Aufgabe folgen können, die Sie aufgezeichnet haben.

**Schritte**

1. Tippen Sie im [Aufgaben-Assistenten](app:/task-wizard) neben einer Aufzeichnung auf **Anleitung erstellen**. Oder wählen Sie **Anleitung hinzufügen** → **Aus einer meiner Aufzeichnungen** oder **Aus einer Aufgabendatei oder einem Paket**.
2. Prüfen Sie den Entwurf. Jeder Schritt ist so geschrieben, wie die lesende Person ihn sehen wird.
3. Geben Sie ihr unter **Name der Anleitung** einen Namen.
4. Tippen Sie auf **Zu meinen Anleitungen hinzufügen**.

**Gut zu wissen**

- Die Anleitung wird auf Ihrem Gerät unter **Anleitungen** aufbewahrt. Eine Anleitung lässt sich bearbeiten oder löschen: **Diese Anleitung löschen** lässt ihre Aufzeichnung unberührt.
- Ein Schritt, der bucht, wartet auf die echte Antwort. Für die lesende Person wird nichts erledigt.
- **Leitfaden speichern** schreibt sie in eine Datei, die Sie weitergeben können.

**Siehe auch:** [Eine Anleitung bearbeiten](help:user.advanced.guide-edit)

<!-- anchor: user.advanced.guide-play -->
### Einer Anleitung folgen

**Zielgruppe:** Alle

Sie möchten auf den echten Bildschirmen durch eine Aufgabe geführt werden.

**Schritte**

1. Tippen Sie im [Aufgaben-Assistenten](app:/task-wizard) neben einer der Anleitungen auf **Anleitung starten**.
2. Ein Fenster zeigt Schritt 1 von … und was zu tun ist, zum Beispiel „Tippen Sie auf ‚Reservieren‘.“ oder „Füllen Sie ‚…‘ aus und verlassen Sie dann das Feld.“
3. Tippen Sie auf **Öffnen und hervorheben**, um zum richtigen Bildschirm zu gelangen und das markierte Bedienelement zu sehen.
4. Führen Sie den Schritt selbst aus. Die Anleitung bemerkt es und geht weiter. Bei einem Leseschritt tippen Sie auf **Erledigt**.

**Gut zu wissen**

- Nutzen Sie **Zurück** und **Überspringen** und öffnen Sie **Alle Schritte**, um jeden als **Offen**, **Wartet**, **Erledigt**, **Bestätigt** oder **Übersprungen** zu sehen.
- Ein Schritt, der bucht, wartet auf die Antwort: **Warte auf das Ergebnis …**. Wird er abgelehnt, sagt die Anleitung, was Sie versuchen können; kam keine Antwort, bittet sie Sie, vor einem neuen Versuch nachzusehen.
- **Anleitung beenden** beendet sie. Nichts wird rückgängig gemacht.
- Die Anleitung pausiert, wenn sich das Konto oder der Workspace ändert oder der Aufgabenrekorder ausgeschaltet wird.

**Siehe auch:** [Das Kreismenü](help:user.advanced.guide-circle)

<!-- anchor: user.advanced.guide-circle -->
### Das Kreismenü

**Zielgruppe:** Alle

Sie brauchen den ganzen Bildschirm zum Arbeiten, möchten die Anleitung aber in der Nähe haben. Verkleinern Sie sie.

**Schritte**

1. Tippen Sie im Anleitungsfenster auf **Anleitung verkleinern**. Sie schrumpft zu einem kleinen Kreis.
2. Tippen Sie auf den Kreis für ein Menü: Anleitung anzeigen (Schritt … von …), **Öffnen und hervorheben**, eine Schaltfläche zur Seite des Schritts, **Erledigt**, **Überspringen**, **Zurück**, **Fortsetzen** und **Anleitung beenden**.
3. Wählen Sie „Anleitung anzeigen“, um das Fenster wieder zu öffnen.

**Gut zu wissen**

- Das Menü bietet nur an, was jetzt sinnvoll ist: **Fortsetzen** nur, solange pausiert ist, **Erledigt** nur bei einem Leseschritt.
- **Schließen** am Fenster blendet es aus; die Anleitung selbst bleibt, wo sie war.
- „Öffnen und hervorheben“ führt Sie zur Seite des Schritts und zeigt auf das Bedienelement; die Seiten-Schaltfläche führt Sie nur zur Seite.

**Siehe auch:** [Einer Anleitung folgen](help:user.advanced.guide-play)

<!-- anchor: user.advanced.guide-edit -->
### Eine Anleitung bearbeiten oder reparieren

**Zielgruppe:** Alle

Eine Anleitung liest sich schlecht, oder ein Schritt zeigt auf die falsche Seite. Beheben Sie es im Entwurf.

**Schritte**

1. Tippen Sie im [Aufgaben-Assistenten](app:/task-wizard) neben Ihrer Anleitung auf **Bearbeiten**.
2. Tippen Sie bei einem Schritt auf **Text schreiben** und geben Sie Ihren eigenen Text ein.
3. Wählen Sie unter **Ziel des Schritts** die Seite, auf die sich der Schritt bezieht. Tippen Sie zum Prüfen auf **Öffnen und hervorheben**.
4. Schalten Sie **Darf übersprungen werden** bei einem Schritt ein, der optional ist.
5. Tippen Sie auf **Änderungen speichern**.

**Gut zu wissen**

- Ein Schritt mit der Kennzeichnung **Eine noch zu schreibende Anweisung** braucht Ihre Worte. **Ein Schritt, den der Rekorder nicht beschreiben kann** und **Diesen Schritt selbst ausführen** erledigt die lesende Person.
- Schritte auf geschützten Bildschirmen, etwa bei der Zahlung, bitten die lesende Person, sie allein auszuführen.
- Sie können eine Anleitung nicht ein Ergebnis erwarten lassen, das ihre Aktion nicht hat; dieser Teil ist fest.
- Eine Anleitung, die Schritte nennt, die diese Version nicht kennt, kann gelesen, aber nicht befolgt werden.

**Siehe auch:** [Eine Anleitung erstellen](help:user.advanced.guide-make)

<!-- anchor: user.advanced.recorder-privacy -->
### Was eine Aufzeichnung behält

**Zielgruppe:** Alle

Sie möchten genau wissen, was nichts zurücklässt.

**Schritte**

1. Öffnen Sie den [Aufgabenrekorder](app:/task-recorder).
2. Lesen Sie **Bevor Sie aufzeichnen**.
3. Lassen Sie **Werte erfassen (für Fehlerberichte)** aus, es sei denn, ein Entwickler hat darum gebeten.

**Gut zu wissen**

- Normalerweise behält eine Aufzeichnung nie, was Sie eintippen, Namen, Beträge, Nachrichten, Codes oder Passwörter.
- Ist das Erfassen von Werten an, behält sie auch, was Sie eintippen und wählen, damit ein Entwickler ein Problem nachstellen kann. Passwörter, Zahlungsdaten, E-Mail-Adressen und Telefonnummern werden trotzdem nie behalten. Beim Exportieren erscheint die Frage **Diese Aufnahme enthält Werte**.
- Nichts wird hochgeladen: Sie entscheiden, was Sie exportieren.
- Teilen Sie eine Datei nur mit Personen, die sehen dürfen, was Sie eingegeben haben.

**Siehe auch:** [Eine Aufgabe aufzeichnen](help:user.advanced.recorder-record)

<!-- anchor: user.advanced.demo -->
### Der Demo-Workspace

**Zielgruppe:** Alle

Sie möchten sich umsehen, bevor Sie sich entscheiden. Die Demo ist ein erfundener Space, offen für alle, ohne Konto.

**Schritte**

1. Tippen Sie auf dem Anmeldebildschirm auf **Den Demobereich erkunden**.
2. Lesen Sie den kurzen Hinweis und tippen Sie dann auf **Loslegen**.
3. Nutzen Sie **Ansicht als**, um denselben Space als **Der Inhaber**, **Eine Verwaltung** oder **Ein Mitglied** zu sehen.
4. Tippen Sie auf **Demo zurücksetzen**, um sie wie am Anfang wiederherzustellen, oder auf **Demo verlassen**.

**Gut zu wissen**

- Alles ist erfunden: Personen, Buchungen und Rechnungen. Nichts erreicht einen echten Workspace, und nichts verlässt Ihr Gerät.
- Ein Banner mit **Demo** steht auf jedem Bildschirm.
- Schließen Sie die App, wird die Sitzung vergessen.
- Das Angebot erscheint nur, wenn die Funktion **Der Demobereich** eingeschaltet ist.

**Siehe auch:** [Aufnahmemodus](help:user.advanced.filming)

<!-- anchor: user.advanced.filming -->
### Aufnahmemodus

**Zielgruppe:** Inhaber

Sie müssen Ihren echten Space zeigen — in einem Video, auf einem Bild oder in einem Vortrag —, ohne seine Mitglieder zu zeigen.

**Schritte**

1. Öffnen Sie die [Funktionen](app:/features) und suchen Sie **Aufnahmemodus**.
2. Schalten Sie ihn ein. Ein Banner mit **Aufnahmemodus — erfundene Personen** steht auf jedem Bildschirm.
3. Filmen Sie. Wenn Sie fertig sind, schalten Sie ihn wieder aus.

**Gut zu wissen**

- Jeder Name, jede E-Mail-Adresse, Telefonnummer, Anschrift und jedes Foto wird zu einer erfundenen Person, überall derselben. Der Plan, die Buchungen und die Zahlen bleiben echt.
- Solange er an ist, lassen sich Identitätsformulare nicht speichern, damit erfundene Angaben keine echten überschreiben.
- Er kann nicht verbergen, was jemand getippt hat, etwa eine Nachricht oder eine Platzbezeichnung. Lesen Sie den Bildschirm, bevor Sie filmen.
- Für ein Bild, das nicht von diesem Space sein muss, nutzen Sie [die Demo](help:user.advanced.demo).

**Siehe auch:** [Ein Funktionsschalter](help:user.features.switch)

<!-- anchor: user.advanced.platforms -->
### DesKilo auf Ihren Geräten

**Zielgruppe:** Alle

Sie möchten DesKilo dort nutzen, wo Sie arbeiten. Dasselbe Konto und dieselben Daten folgen Ihnen.

**Schritte**

1. **Android:** Treten Sie dem geschlossenen Test bei Google Play bei.
2. iPhone und iPad: Treten Sie der Beta über TestFlight bei.
3. **Computer:** ein macOS-Disk-Image oder ein Windows-Installer von der Release-Seite; oder öffnen Sie einfach die Web-App.
4. **Browser:** Öffnen Sie die Adresse, die Ihr Workspace veröffentlicht. Nichts zu installieren.

**Gut zu wissen**

- Ein am Handy gebuchter Tisch erscheint einen Moment später in einem Browser-Tab.
- Das macOS-Disk-Image von der Release-Seite ist signiert und von Apple notarisiert; öffnen Sie es wie gewohnt.
- Der Windows-Installer ist nicht signiert: Windows SmartScreen warnt vor einem unbekannten Herausgeber; wählen Sie „Weitere Informationen“ und dann „Trotzdem ausführen“.
- Das Lesen eines Stuhl-Tags funktioniert in Chromium-Browsern auf Android (HTTPS und ein Tippen nötig); die Android- und iPhone-Apps lesen Tags direkt.
- Ein Build ohne Google-Dienste und ohne Cloud-Push ist für F-Droid vorbereitet; ob er schon über F-Droid installiert werden kann, steht auf der [F-Droid-Statusseite](https://github.com/fdittgen-png/deskilo/blob/master/docs/guides/fdroid.md#status). Darin sind Benachrichtigungen lokal, und der Posteingang ist maßgeblich.
- Aktualisierungen kommen über den Kanal, über den Sie installiert haben: Google Play, TestFlight, die Release-Seite oder das erneute Laden der Web-App.

**Siehe auch:** [Ihr Badge](help:user.profile.settings.badge)

<!-- anchor: user.advanced.support -->
### Supportdetails

**Zielgruppe:** Alle

Sie wenden sich an den Support und möchten senden, was ihm hilft, ohne etwas Privates preiszugeben.

<p><img src="images/user-advanced-support.de.jpg" width="280"></p>

**Schritte**

1. Öffnen Sie die [Hilfe](app:/help) und tippen Sie auf das Support-Symbol (**Supportdetails**).
2. Wählen Sie **Letzte Stunde** oder **Letzte 24 Stunden**.
3. Tippen Sie auf **Vorschau vorbereiten** und lesen Sie, was sie enthält: Vorschau: … Bytes.
4. Tippen Sie auf **Speichern** und senden Sie dann die Datei.

**Gut zu wissen**

- Enthalten sind nur begrenzte Ereigniszahlen und bekannte Prüfungen. Identitäten, Serveradressen, Zugangsdaten, Geschäftsdaten und Rohprotokolle sind ausgeschlossen.
- Eine geteilte Datei lässt sich nicht zurückrufen.
- Hat sich der Kontext geändert, bittet der Bildschirm Sie, eine neue Vorschau vorzubereiten.
- Ein Betreiber kann `doctor --support-json` für die Serverseite ausführen.

**Siehe auch:** [Wenn etwas nicht funktioniert](help:user.advanced.troubleshooting)

<!-- anchor: user.advanced.troubleshooting -->
### Wenn etwas nicht funktioniert

**Zielgruppe:** Alle

Etwas sieht falsch aus. Versuchen Sie dies, der Reihe nach.

**Schritte**

1. Suchen Sie eine Meldung auf dem Bildschirm; die meisten sagen, was zu tun ist. „Etwas ist schiefgelaufen. Bitte versuchen Sie es erneut.“ ist einen neuen Versuch wert.
2. Prüfen Sie, ob Sie auf der Seite sind, auf der Sie sich glauben: **Testbereich** oder **Arbeitsbereich öffnen** in [Ich](app:/me).
3. Prüfen Sie die [Funktionen](app:/features): Eine im Menü fehlende Funktion ist meist eine ausgeschaltete. Nur ein Inhaber kann das ändern.
4. Prüfen Sie den Server unter [Ihr eigener Server](help:user.backend.server): **Dieses Gerät nutzt** nennt ihn.
5. Bereiten Sie die [Supportdetails](help:user.advanced.support) vor und senden Sie sie.

**Gut zu wissen**

- Was Sie sehen, hängt von Ihrer Rolle ab: Ein fehlender Bildschirm kann eine Berechtigung sein. Fragen Sie Ihren Inhaber.
- Administratoren können unter **Erweitert** in den [Einstellungen](app:/settings) den **Entwicklermodus** einschalten. Er fügt einen Bildschirm [Entwickler](app:/developer) hinzu, auf dem **Protokoll exportieren** und **Protokoll leeren** dem Support helfen. Er gilt für jedes Mitglied des Workspace.
- Einen Fehler können Sie auch im Bereich „Über“ der App melden: **Fehler melden / Funktion vorschlagen**.
- Eine Anleitung, die bei **Warte auf das Ergebnis …** hängt, bedeutet, dass keine Antwort kam: Prüfen Sie das Ergebnis, bevor Sie es erneut versuchen.

**Siehe auch:** [Supportdetails](help:user.advanced.support)

<!-- anchor: user.advanced.glossary -->
### Die Wörter der App

**Zielgruppe:** Alle

Die Wörter, denen Sie am häufigsten begegnen, und was sie hier bedeuten.

| Wort | Was es bedeutet |
|---|---|
| **Workspace** (auch Space genannt) | Ein Ort, den eine Gemeinschaft führt: ihr Plan, ihre Mitglieder, Regeln und ihr Geld. Sie können mehreren angehören. |
| **Ich** | Ihr eigenes Konto: Profil, Nachrichten, Spaces und Einstellungen, über alle Ihre Spaces hinweg. |
| **Plan** | Entweder der Raumplan, von dem aus Sie buchen, oder ein Mitgliedschaftstarif — siehe **Mitglieder & Tarife**. |
| **Ebene** | Ein Stockwerk oder eine Zone des Plans. Eine Ebene kann als Ganzes reserviert werden, wenn die Funktion eingeschaltet ist. |
| **Tisch** | Ein buchbarer Platz. Büros und Räume fassen Tische zusammen. |
| Halbtag | Die Einheit, in der Buchungen und Abos gezählt werden. |
| **Freigabe** | Eine Regel, die besagt, dass eine Aktion eine oder mehrere Bestätigungen braucht, bevor sie zählt. |
| **Ereignisse** | Der Feed dessen, was passiert ist, mit den auf Sie wartenden Entscheidungen oben. |
| **Kiosk** | Ein gemeinsames Tablet an der Tür, an dem Menschen mit einem Badge einchecken. |
| Funktion | Eine Funktion, die der Inhaber für den ganzen Space ein- oder ausschaltet. |
| **Rolle** | Was eine Person in einem Space tun darf. Berechtigungen werden pro Rolle festgelegt. |
| **Umgebung** | Die Entwicklungsseite (Test) oder die Produktionsseite (echt) eines Space. |
| Zwilling | Die andere Seite eines Paars. |
| **Ausrollung** | Konfiguration von einer Seite eines Paars auf die andere übertragen. |
| **Assistent** | Ein KI-Werkzeug, das mit Ihrem Konto verbunden ist und nur so handelt, wie Sie es erlauben. |
| **Betreiber** | Die Person, die die Installation betreibt, mit der die App spricht. |

**Gut zu wissen**

- Inhaber können unter **Wortwahl** die Wörter ändern, die ein Space verwendet; die App zeigt dann die des Space.

**Siehe auch:** [Wortwahl](help:user.workspace.settings.wording)

<!-- anchor: user.advanced.accessibility -->
### Barrierefreiheit und Tastatur

**Zielgruppe:** Alle

Sie möchten, dass die App zu Ihrer Arbeitsweise passt.

**Schritte**

1. Wählen Sie ein Aussehen in den [Einstellungen](app:/settings): **Design**, **Sprache**, **Zahlen & Daten**.
2. Für ruhigere Bildschirme schalten Sie die Einstellung „Bewegung reduzieren“ Ihres Geräts ein.
3. Drücken Sie am Computer in einem Assistenten Esc, um einen Schritt zurückzugehen.

**Gut zu wissen**

- Die Einstellung „Bewegung reduzieren“ des Geräts hat immer Vorrang vor der Funktion **Oberflächen-Animationen**; ein Inhaber kann diese Funktion auch ausschalten.
- Beim Verlassen eines Assistenten mit nicht gespeicherten Änderungen wird zuerst gefragt: **Weiter bearbeiten** oder **Verwerfen**.
- Bedienelemente tragen Textbeschriftungen, sodass ein Screenreader sie vorliest.
- Im Web und am Computer zeigt ein breites Fenster das Menü neben dem Inhalt.

**Siehe auch:** [Design](help:user.profile.settings.theme) · [App-Sprache](help:user.profile.settings.language)

<!-- anchor: user.advanced.help -->
### Wo es mehr Hilfe gibt

**Zielgruppe:** Alle

Sie hängen an einem Feld oder einem Bildschirm fest.

**Schritte**

1. Tippen Sie auf das **?** neben einem Feld: Die Anleitung öffnet sich an diesem Feld.
2. Öffnen Sie die [Hilfe](app:/help) für die ganze Anleitung; **Inhalt** springt zu einem Kapitel.
3. Tipps auf einem Bildschirm lassen sich mit **Hinweis ausblenden** schließen; **Nächster Tipp** und **Vorheriger Tipp** blättern durch sie, **Mehr erfahren** öffnet die Anleitung.
4. Um ausgeblendete Hinweise wieder zu sehen, nutzen Sie **Hilfe-Hinweise wieder anzeigen** in Ihren Einstellungen.

**Gut zu wissen**

- Die Anleitung funktioniert offline, in Ihrer Sprache.
- Ihre Administratorin kann Fragen zu Ihrem Space beantworten; die Supportdetails helfen, wenn es an der App liegt.

**Siehe auch:** [Hinweise wiederherstellen](help:user.profile.settings.restore-hints) · [Supportdetails](help:user.advanced.support)
