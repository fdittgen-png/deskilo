<!-- anchor: setup.place.overview -->
## Costruire il luogo

Questo capitolo costruisce il primo livello, **Aprire**: dove si trova lo spazio, che aspetto ha, quando è aperto e quali sono le regole di prenotazione. In circa venti minuti lo spazio può essere prenotato. L’esempio è *Atelier du Marché*, un’associazione a Pézenas con due piani e una sala.

In questo capitolo:
- [Paese, valuta, fuso orario e lingua](help:setup.place.where)
- [La planimetria](help:setup.place.plan)
- [Orari di apertura e regole di prenotazione](help:setup.place.times)
- [Giorni di chiusura e giorni festivi](help:setup.place.closure)
- [Verificare il suo spazio](help:setup.place.check)

<!-- anchor: setup.place.where -->
### Paese, valuta, fuso orario e lingua

**Destinatari:** Proprietario · Amministratore

Vuole che lo spazio sappia dove si trova. Queste quattro scelte determinano più cose di quanto sembri.

<p><img src="images/setup-place-country.it.jpg" width="280"></p>

*Che cosa determina ciascuna scelta*

| Scelta | Che cosa decide |
|---|---|
| **Paese** | La valuta e il fuso orario che propone, e i giorni festivi offerti come giorni di chiusura (veda sotto). |
| **Valuta** | Come ogni importo viene mostrato e contato. |
| **Fuso orario** | Che cosa significano una giornata lavorativa, un limite di mezza giornata e un giorno di chiusura; un membro all’estero vede la giornata dello spazio. |
| **Lingua dello spazio** | La lingua in cui, per impostazione predefinita, sono scritti gli inviti e i riferimenti ai messaggi condivisi. |

**Passaggi**

1. Apra [Spazio di lavoro](app:/workspace-settings) e vada su **Informazioni generali**.
2. Scelga il **Paese**; la **Valuta** e il **Fuso orario** lo seguono e può correggerli. Per Atelier du Marché: Francia, EUR, Europe/Paris.
3. Scelga la **Lingua dello spazio**, poi tocchi **Salva**.

> **Attenzione** Scelga bene paese e valuta il primo giorno. Gli importi sono memorizzati come semplici numeri, quindi quando lo spazio ha emesso un documento o registrato denaro, il server rifiuta di cambiare l’uno o l’altra: «La valuta e il paese sono fissati non appena lo spazio ha emesso un documento o registrato denaro. Non è stato salvato nulla.»

**Da sapere**

- L’app elenca molti paesi, ma l’emissione di fatture dentro DesKilo oggi funziona solo per la Francia e la Germania. Altrove conserva gli estratti conto ed emette le fatture fuori dall’app.
- La lingua dello spazio non è la lingua della sua app, che si trova nelle sue impostazioni personali.

**Vedi anche:** [Paese](help:user.workspace.settings.country) · [Valuta e fuso orario](help:user.workspace.settings.currency-timezone) · [Lingua dello spazio](help:user.workspace.settings.language)

<!-- anchor: setup.place.plan -->
### La planimetria

**Destinatari:** Proprietario · Amministratore

Vuole che la planimetria sullo schermo somigli al luogo reale. È costruita su quattro livelli: i piani, poi gli uffici (le sale), poi le scrivanie, poi i posti. Un membro prenota un posto; un posto è ciò che l’elenco di preparazione conta.

<p><img src="images/setup-place-rooms.it.jpg" width="280"></p>

**Passaggi**

1. Faccia uno schizzo su carta: piani, sale, scrivanie, posti.
2. Apra [Editor dello spazio](app:/editor) e aggiunga i piani con **Aggiungi piano**.
3. Apra un piano e disegni ogni sala con **Ufficio**, poi **Scrivania** e **Posto** al suo interno.
4. Se una squadra può occupare una sala o un piano per un giorno, attivi la prenotazione dell’intera sala nelle sue proprietà.

**Da sapere**

- Cominci in piccolo: un primo piano, una sala, qualche posto. Tutto si può aggiungere in seguito.
- Un intero piano, ufficio o scrivania può essere prenotato solo se **Prenotazioni di tavolo, ufficio e piano** è attivo e il membro ha il permesso.
- Il modello integrato A tiny space le dà due piani, quattro scrivanie e otto posti da adattare.
- Eliminare un piano rimuove tutto ciò che contiene, e l’importazione di una planimetria viene rifiutata quando esistono prenotazioni.

**Vedi anche:** [Aggiungere, rinominare ed eliminare piani](help:user.space.editor.levels) · [Disegnare sale, scrivanie e posti](help:user.space.editor.rooms) · [Lasciare che i membri prenotino un intero piano](help:user.space.editor.level-booking)

<!-- anchor: setup.place.times -->
### Orari di apertura e regole di prenotazione

**Destinatari:** Proprietario · Amministratore

Vuole che le prenotazioni seguano il ritmo del suo luogo. Una sola schermata, **Disponibilità**, contiene i giorni, la forma di una prenotazione, gli orari di lavoro e le regole. Il server le applica ovunque: planimetria, scheda di prenotazione, codici scansionati e chiosco.

<p><img src="images/setup-place-availability--times.it.jpg" width="280"></p>

**Passaggi**

1. Apra [Disponibilità](app:/availability).
2. Scelga i **Giorni di apertura** (almeno uno) e la **Granularità delle prenotazioni**.
3. Imposti gli **Orari di lavoro**: **Inizio giornata**, **Limite di mezza giornata**, **Fine giornata**.
4. Sotto **Regole di prenotazione**, decida su **Consenti prenotazioni passate**, **Fuori dagli orari di apertura** e **Limiti di prenotazione**.

<p><img src="images/setup-place-availability--rules.it.jpg" width="280"></p>

*Punti di partenza consigliati (suggerimenti, non regole; il valore predefinito di **Fuori dagli orari di apertura** è **A pagamento**, e il modello per associazioni non lo modifica)*

| Scenario | Granularità | Orari | Fuori orario | Prenotazioni passate | Limiti |
|---|---|---|---|---|---|
| Qualche scrivania condivisa | **Fascia oraria libera** o **Slot di 1 ora** | Giornata 8:00–17:00 | **Libero** | Disattivate | Una prenotazione alla volta; orizzonte di 30 giorni |
| Una sala associativa (Atelier du Marché) | **Mezze giornate (mattina e pomeriggio)** | 7:00, limite 13:00, fine 19:00 | **Disattivata** | Disattivate | Una prenotazione alla volta; orizzonte di 90 giorni |
| Un coworking con mezze giornate | **Mezze giornate (mattina e pomeriggio)** | 8:00, limite 12:00, fine 18:00 | **A pagamento** | Disattivate | Una o due alla volta; orizzonte di 90 giorni |

**Da sapere**

- Fuori dagli orari di apertura, **Disattivata** rifiuta tutto, **Solo spontaneo** consente gli arrivi senza prenotazione, **Libero** consente senza contare, **A pagamento** conta come un normale utilizzo, tranne in un giorno in cui il membro ha già una prenotazione ordinaria.
- La giornata deve procedere in ordine: inizio, poi limite, poi fine; la durata minima non può superare quella massima.
- Una prenotazione termina nel giorno in cui inizia. Le prenotazioni passate sono disattivate per impostazione predefinita; prenotare una fascia precedente nello stesso giorno è sempre consentito.
- Le fasce di mezza giornata e di giornata intera guidano anche l’arrivo e la fatturazione, quindi definisca gli orari prima di stabilire i prezzi.

**Vedi anche:** [Giorni di apertura](help:user.workspace.availability.open-weekdays) · [Granularità](help:user.workspace.availability.granularity) · [Orari di lavoro](help:user.workspace.availability.working-hours) · [Fuori dagli orari di apertura](help:user.workspace.availability.outside-hours) · [Limiti di prenotazione](help:user.workspace.availability.limits)

<!-- anchor: setup.place.closure -->
### Giorni di chiusura e giorni festivi

**Destinatari:** Proprietario · Amministratore

Vuole che lo spazio sia chiuso nei giorni festivi, senza che nessuno li prenoti per errore.

<p><img src="images/setup-place-availability--closure.it.jpg" width="280"></p>

**Passaggi**

1. In [Disponibilità](app:/availability), vada su **Giorni di chiusura**.
2. Tocchi **Aggiungi i giorni festivi** (se non lo vede, attivi prima la funzionalità *Giorni festivi*; è disattivata per impostazione predefinita) per creare un intero anno in una volta, oppure **Aggiungi giorno di chiusura** per una singola data, come un giorno di inventario.
3. Controlli l’elenco e tolga ogni giorno in cui lavora davvero.

**Da sapere**

- Esistono elenchi di giorni festivi integrati per la Francia e la Germania. Per gli altri paesi attivi *Giorni festivi* e *Importa i giorni festivi* (dati aperti, serve una connessione). Non viene creato nulla prima che Lei confermi.
- Una prenotazione in un giorno di chiusura viene rifiutata, e la planimetria mostra il giorno come chiuso con il suo motivo.
- I mesi già fatturati vengono saltati, quindi aggiunga i giorni di chiusura prima della chiusura del mese.

**Vedi anche:** [Giorni di chiusura](help:user.workspace.availability.closure-days) · [Giorni festivi](help:user.workspace.availability.public-holidays)

<!-- anchor: setup.place.check -->
### Verificare il suo spazio

**Destinatari:** Proprietario · Amministratore

Vuole una prova che lo spazio sia pronto, prima di invitare qualcuno. Lo dicono due schede.

<p><img src="images/setup-place-get-started--card.it.jpg" width="280"></p>

**Passaggi**

1. Apra [Spazio di lavoro](app:/workspace-settings): la scheda **Configurazione di questo spazio** elenca ogni area con il suo stato e il passo successivo.
2. Apra [Prenota](app:/reserve). I proprietari e gli amministratori con il permesso di configurazione vedono la scheda *Primi passi nel suo spazio*. Se manca qualcosa, riporta «Prima che qualcuno possa prenotare qui», con **Completa la configurazione**.
3. Prenoti lei stesso un posto come prova, poi lo annulli.

**Da sapere**

- Pronto significa pronto per una prima prenotazione: giorni di apertura, fuso orario, valuta, almeno un posto, membri che possono prenotare e abbastanza validatori.
- Tutto ciò che è facoltativo, come tariffe o pagamenti, può essere messo da parte con **Più tardi** e non impedisce l’apertura.
- Entrambe le schede dipendono dalla funzionalità *Scheda Primi passi*.
- **Non ora** nasconde la scheda su questo dispositivo; il menu di visualizzazione sulla planimetria la riporta con **Primi passi**.

**Risultato** Uno spazio che i membri possono prenotare. Il passo successivo: invitare le prime persone, poi i ruoli e le tariffe del secondo livello.

**Vedi anche:** [La scheda Primi passi e i suggerimenti](help:user.start.get-started) · [Invitare le persone con l’ID dello spazio](help:user.workspace.code) · [Ruoli](help:user.roles.matrix)
