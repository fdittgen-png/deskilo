# Umgebungen — ein Raum zum Ausprobieren, ein Raum, der echt ist

Zwei Räume, ein Name. Auf dem einen konfigurierst, importierst, druckst
und zerbrichst du Dinge; auf dem anderen buchen Menschen Plätze und
erhalten Rechnungen, die geschuldet sind. Was du auf dem ersten
festlegst, deployst du auf den zweiten.

<!-- anchor: env.pair.why -->
## Warum ein Paar

Ein Coworking-Raum wird von der Person konfiguriert, die ihn führt,
nicht von einem Integrator, und die Konfiguration ist die Stelle, an
der Fehler billig zu machen und teuer zu entdecken sind: ein doppelt
getippter Tarif, ein MwSt-Satz auf der falschen Gruppe, ein Plan, dessen
Plätze sich verschoben haben, nachdem Leute sie gebucht hatten. Ein
Entwicklungsraum kostet nichts und fängt all das auf. Jedes Dokument,
das er druckt, trägt das **Entwicklungs-Wasserzeichen**, seine
E-Rechnungen gehen an den Testendpunkt, und nichts, was er erzeugt, kann
für ein echtes Dokument gehalten werden.

<!-- image: env-pair-profiles -->

<!-- anchor: env.pair.create -->
## Das Paar anlegen

Ein neuer Raum wird **mit seinem Zwilling** angelegt: gleicher Name,
gleiches Land, gleiche Währung, gleiche Zeitzone, beide von der ersten
Sekunde an deine. *Profile* zeigt das Paar als eine Karte mit zwei
Chips, **DEV** und **PROD**; ein Tipp auf einen Chip wechselt die Seite,
und dieser Wechsel wird deine Voreinstellung, sodass ein Neustart dort
öffnet, wo du aufgehört hast.

Ein Raum, der vor den Paaren angelegt wurde oder allein entstand,
bekommt seinen Zwilling auf Wunsch: *Einstellungen → Erweitert →
Zwilling anlegen*. Die Konfiguration wird in diesem Moment einmal
kopiert; danach sind die beiden Seiten unabhängig, und nur ein
Deployment bewegt etwas zwischen ihnen.

<!-- anchor: env.pair.permissions -->
## Wer was darf

Drei Berechtigungen in der Rollenmatrix:

- **Den Produktionsraum betreten** — ohne sie kann eine Rolle überhaupt
  kein Mitglied der Produktionsseite sein. Eigentümerinnen und
  Miteigentümer haben sie; Administratorinnen haben sie; Mitglieder
  nicht, bis du sie gibst.
- **Nach Entwicklung deployen** — die Konfiguration der Produktionsseite
  in die Entwicklungsseite ziehen. Administratorinnen haben sie.
- **Nach Produktion deployen** — die heikle, standardmäßig nur
  Eigentümerin und Miteigentümer. Wer sie hält, hält auch *Nach
  Entwicklung deployen*.

Daraus folgen zwei Regeln. **Ein Mitglied der Produktionsseite ist immer
Mitglied der Entwicklungsseite**: die Mitgliedschaft wird gespiegelt,
Rolle und Status eingeschlossen, sodass niemand zweimal eingeladen
werden muss. Und **eine Rolle betritt die Produktionsseite nur, solange
sie die Zutrittsberechtigung hält** — eine Einladung, ein Beitritt oder
eine Profilübernahme in die Produktion wird sonst abgelehnt, mit dem
Grund auf dem Bildschirm.

<!-- anchor: env.work.configure -->
## Auf der Entwicklungsseite arbeiten

Konfigurieren, eine Raumdatei importieren, eine Kollegin einladen, eine
Testrechnung ausstellen, Plätze verschieben, drucken. Nichts davon ist
echt: das Wasserzeichen sagt es auf jedem Dokument, und der
E-Rechnungs-Testendpunkt weigert sich, eine staatliche Plattform zu
erreichen.

<!-- anchor: env.deploy.screen -->
## Deployen

*Einstellungen → Administration → Deployment*, auf der Seite, die du
**schreiben** willst. Ein Deployment geht immer **in die Seite, auf der
du stehst**: auf der Produktionsseite heißt der Knopf *Aus DEV ziehen*,
auf der Entwicklungsseite *Aus PROD ziehen*. Nichts kann versehentlich
auf die andere Seite geschoben werden.

<!-- image: env-deploy-screen -->

<!-- anchor: env.deploy.entities -->
### Was reist, Entität für Entität

Gruppiert als **Konfiguration**, **Stammdaten** und **Berichte**:

| Gruppe | Entitäten |
|---|---|
| Konfiguration | Identität & Pflichtangaben · Buchungsregeln · Prüfregeln · Rollenmatrix · Mahnregeln · Zahlungshinweise · Dokumentlinks · Schließtage · Einladungsvorlagen · Funktionen |
| Stammdaten | MwSt · Tarife · Leistungen · Pakete · Zubehör · Standorte · Grundrisse |
| Berichte | Dokumentgestaltungen, mit ihren Bildern |

Hake eine an, und was sie braucht, wird mit angehakt — Leistungen
brauchen die MwSt-Sätze, ein Grundriss braucht sein Zubehör und seine
Standorte.

<!-- anchor: env.deploy.plan -->
### Der Grundriss wird zusammengeführt, nie ersetzt

Etagen passen über den Namen zusammen, Büros, Tische und Plätze über den
Namen oder, ohne Namen, über die Position. Was die andere Seite hat,
wird hinzugefügt oder aktualisiert; was nur diese Seite hat, wird
gemeldet und **behalten**, denn ein Platz kann bereits eine Buchung
tragen. Ausweismarken und Sperren reisen nie. Hintergründe und
Planbilder werden mitkopiert.

<!-- anchor: env.deploy.preview -->
### Die Vorschau, dann die Bestätigung

Nichts bewegt sich, bevor eine Vorschau je Entität sagt, was
hinzugefügt, geändert und entfernt würde. Eine Vorschau ohne etwas zu
tun sagt das und deployt nichts. Dann nennt eine Bestätigung die Seite,
die gleich geschrieben wird, und die Entitäten, denn das ist der Moment,
in dem ein Fehler teuer wird.

<!-- anchor: env.deploy.journal -->
### Das Journal und der Weg zurück

Jedes Deployment wird festgehalten: wer, wann, in welche Richtung,
welche Entitäten, und was das Ziel vorher enthielt. *Zurücknehmen* auf
dem letzten stellt genau das wieder her. Eine Rücknahme wird abgelehnt,
solange ein späteres Deployment auf derselben Seite steht — nimm sie der
Reihe nach zurück.

<!-- anchor: env.deploy.never -->
### Was nie reist

Mitglieder, Reservierungen, Konten, Rechnungen, Zahlungen, Ereignisse,
Nachrichten, Zugangsdaten jeder Art und die Nummernzähler. Eine
Nummernserie wird als **Format** deployt; die nächste Nummer gehört
immer dem Raum, der sie ausstellt.

<!-- anchor: env.instances -->
## Wenn ein Paar nicht reicht

Zwei Räume teilen sich eine Datenbank. Wo personenbezogene Daten oder
Zahlungszugangsdaten physisch getrennt sein müssen, paare stattdessen
**Instanzen**: der Assistent für eine neue Instanz baut aus dem Bündel
eine zweite Datenbank, und dieselben Entitäten reisen über die Raumdatei
zwischen den beiden.
