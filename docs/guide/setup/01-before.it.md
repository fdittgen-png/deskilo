<!-- anchor: setup.before.overview -->
## Prima di iniziare

Un po’ di preparazione le risparmia le due cose che costano di più in seguito: riscrivere tutto e prendere decisioni che non si possono più cambiare. Questo capitolo mostra che cosa fa DesKilo, che cosa serve davvero per aprire e che cosa tenere a portata di mano.

In questo capitolo:
- [Che cosa può fare DesKilo](help:setup.before.what)
- [Che cosa è necessario e che cosa è facoltativo](help:setup.before.necessary)
- [Uno spazio di prova o uno reale](help:setup.before.environment)
- [Partire da un modello o da zero](help:setup.before.template)
- [Che cosa preparare](help:setup.before.prepare)
- [Decisioni difficili da annullare](help:setup.before.permanent)
- [Chi fa che cosa](help:setup.before.who)

<!-- anchor: setup.before.what -->
### Che cosa può fare DesKilo

**Destinatari:** Proprietario · Comproprietario

Vuole avere un quadro d’insieme prima di scegliere qualsiasi cosa. DesKilo raggruppa le sue funzionalità in nove processi; la schermata **Funzionalità** mostra una scheda per ogni processo con il suo stato.

<p><img src="images/setup-before-processes.it.jpg" width="280"></p>

*I nove processi, in parole semplici*

| Processo | Che cosa offre a un membro |
|---|---|
| **Spazio e accesso** | Un ingresso: partecipare con l’ID dello spazio, un ruolo, un badge. |
| **Gestione degli spazi** | Un luogo uguale a quello reale: piani, sale, scrivanie, orari di apertura. |
| **Prenotazioni e utilizzo** | Prenotare una scrivania o una sala, registrare l’arrivo e la partenza, vedere che cosa è libero. |
| **Calendario e coordinamento** | Un calendario, messaggi e richieste che qualcuno conferma. |
| **Offerte per i membri** | Un piano, i prezzi dei servizi e gli accordi. |
| **Fatturazione e pagamenti** | Un estratto conto, fatture, pagamento, solleciti, IVA. |
| **Documenti e informazioni** | Documenti da leggere, rapporti da stampare, i propri dati da esportare. |
| **Operazioni e amministrazione** | Uno spazio con i suoi colori e le sue parole. |
| **Integrazioni e automazione** | Notifiche e documenti recapitati tramite servizi esterni. |

**Da sapere**

- Un nuovo spazio parte con un insieme ragionevole di funzionalità attive: non deve deciderle una per una. Disattivare una funzionalità blocca solo le nuove operazioni e non cancella nulla.
- Una funzionalità che ne richiede un’altra attiva anche quella, e la schermata indica che cosa si è attivato. Veda [Un interruttore di funzionalità](help:user.features.switch).
- Le funzionalità contrassegnate come alpha o beta chiedono il suo consenso quando le attiva.

**Vedi anche:** [Attivare e disattivare le funzionalità](help:user.features.processes)

<!-- anchor: setup.before.necessary -->
### Che cosa è necessario e che cosa è facoltativo

**Destinatari:** Proprietario · Comproprietario · Amministratore

Vuole conoscere la strada più breve verso uno spazio prenotabile. L’app tiene un elenco di preparazione chiamato **Configurazione di questo spazio** e, nella schermata Prenota, indica ai proprietari che cosa manca con «Prima che qualcuno possa prenotare qui».

*Che cosa deve esserci prima della prima prenotazione*

1. **Giorni di apertura, fuso orario e valuta**: un fuso orario, una valuta e almeno un giorno della settimana aperto.
2. **Posti prenotabili sulla planimetria**: almeno un posto.
3. **Ruoli e chi convalida le richieste**: conta solo quando una regola di convalida, di qualsiasi tipo, chiede più validatori di quanti ne abbia lo spazio. Una regola che chiede due approvazioni, con lei sola nello spazio, lascerebbe le richieste in attesa per sempre.
4. **Cosa possono fare i membri**: i membri possiedono **Prenotare e usare le prenotazioni**. Un nuovo spazio non concede loro nulla, quindi un membro che entra non può prenotare finché lei non lo spunta in [Ruoli](app:/roles).

Un’altra riga, **Server e versione del database**, blocca soltanto quando il server è indietro rispetto a questa app; in quel caso si attende l’operatore del server. E finché **Fatture** è attiva, è richiesta anche **L'identità legale e l'indirizzo dello spazio**: l’elenco la segna **Necessario prima di fatturare**, perché senza di essa non si può emettere alcuna fattura.

*Che cosa è facoltativo e può essere rimandato*

- **Piani di iscrizione e tariffe**
- **Invitare i primi membri**
- **Come pagano i membri**
- **Esportazione e ripristino**
- **Dati richiesti dalle funzioni (identità, banca, piattaforme)**
- **Una prima prenotazione**

Ognuno di questi passaggi può essere messo da parte con **Più tardi** e ripreso in seguito; l’elenco indica se un passaggio è **Da configurare**, **Pronto**, **Non necessario qui** o **In attesa di un’altra persona**. Esistono altri due stati: **Non ancora verificato** (**Esportazione e ripristino** diventa Pronto solo dopo un’esportazione reale negli ultimi 90 giorni) e una riga che non è stato possibile leggere.

**Da sapere**

- L’elenco indica chi deve agire: **Lei**, **L’operatore del server** o **Un amministratore del database**.
- Facoltativo non significa poco importante: coordinate bancarie, un fornitore di pagamento o una sede sono dati richiesti dalle funzioni, e l’elenco li indica.
- Se attiva la fatturazione senza identità legale, l’app lo consente; l’elenco e [Che cosa richiede la Sua attenzione](help:user.collaborate.attention) la segnalano, e l’emissione di una fattura viene rifiutata, dicendo che cosa manca.

**Vedi anche:** [Verificare il suo spazio](help:setup.place.check) · [La scheda Primi passi e i suggerimenti](help:user.start.get-started)

<!-- anchor: setup.before.environment -->
### Uno spazio di prova o uno reale

**Destinatari:** Proprietario · Comproprietario · Operatore

Vuole provare senza conseguenze e poi gestire lo spazio reale. Uno spazio può essere di prova, reale oppure una coppia collegata con lo stesso nome.

<p><img src="images/setup-before-environment.it.jpg" width="280"></p>

| Opzione | La scelga quando | Che cosa succede |
|---|---|---|
| **Uno spazio di prova** | Sta imparando. | Ogni schermata e ogni documento dichiara di essere una prova: i documenti portano una filigrana. Nessuna fatturazione reale. |
| **Uno spazio reale** | Conosce le sue impostazioni. | Le fatture che emette sono dovute. |
| **Una coppia collegata di prova e reale** | Vuole provare le modifiche prima che le vedano i membri reali. | Due spazi, entrambi suoi. Solo un rilascio sposta la configurazione dall’uno all’altro; membri, prenotazioni, fatture e pagamenti non viaggiano mai. |

**Da sapere**

- Il selettore parte dall’opzione di prova.
- L’ambiente è una dichiarazione del proprietario; chiunque abbia il permesso di configurazione (il proprietario sempre) può cambiarlo in seguito, e le fatture già emesse conservano la filigrana che portavano: se ha dei dubbi, cominci con uno spazio di prova.
- Per fare pratica senza uno spazio proprio, usi lo spazio dimostrativo.

**Vedi anche:** [Uno spazio ha due lati](help:user.advanced.environments) · [Creare uno spazio di lavoro](help:user.start.create) · [Uno spazio di prova](help:user.advanced.test-space)

<!-- anchor: setup.before.template -->
### Partire da un modello o da zero

**Destinatari:** Proprietario

Vuole un vantaggio iniziale senza essere vincolato alle scelte di altri. Quando crea uno spazio, **Partire da** propone **Spazio vuoto** oppure un modello pronto, ed è preselezionato su *A tiny space*; scelga *Spazio vuoto* se preferisce una tela bianca.

<p><img src="images/setup-before-template.it.jpg" width="280"></p>

*I due modelli integrati*

| Modello | Che cosa configura |
|---|---|
| A tiny space | Due piani, quattro scrivanie, otto posti, nient’altro: abbastanza per prenotare, scansionare ed esplorare fin dal primo minuto. |
| Association de coworking (France) | Mezze giornate 7:00–13:00 e 13:00–19:00, dal lunedì al venerdì, giorni festivi, iscrizioni al 50 % e al 100 %, due carnet prepagati di mezze giornate (10 e 20), ruoli del consiglio (tesoriere, segretario, responsabile della sala), un calendario per le convalide e due piani pronti per le prenotazioni. Imposta inoltre la lingua dello spazio sul francese e il regime IVA su *non soggetto a IVA*; vengono rinominate solo tre parole (Place, Étage, Réservations). Il nome del modello è in francese in tutte le lingue dell’app. |

**Da sapere**

- Un modello non contiene mai la sua identità legale, le coordinate bancarie, le sedi, gli inviti o i link ai documenti: sono suoi, e l’elenco di preparazione li indica (l’identità legale, con **Fatture** attiva, come un’area a sé).
- Uno spazio creato da un modello può avere la fatturazione attiva e nulla con cui emettere finché non aggiunge l’identità.
- Applicare un modello a uno spazio che ha già delle tariffe sostituisce le sue fasce di tariffa: lo usi su uno spazio nuovo.

**Vedi anche:** [Creare uno spazio di lavoro](help:user.start.create)

<!-- anchor: setup.before.prepare -->
### Che cosa preparare

**Destinatari:** Proprietario

Vuole avere i dati a portata di mano, così che la configurazione richieda minuti e non giorni. Raccolga prima queste cose.

**Prima di iniziare**

- [ ] L’**identità legale**: associazione o società, denominazione registrata, indirizzo, numeri di registrazione e di partita IVA se li ha.
- [ ] Un **commercialista** (o qualcuno che confermi le scelte fiscali): fatture e IVA sono la parte da verificare con un professionista.
- [ ] Un’idea di tariffa: gratuita, un’iscrizione forfettaria o una percentuale di giorni con una quota mensile.
- [ ] Le **coordinate bancarie** su cui i membri pagheranno (IBAN e BIC, o il metodo in uso nel suo Paese).
- [ ] Un elenco delle prime persone: nomi e indirizzi e-mail, e chi approverà le richieste.
- [ ] Uno schizzo della planimetria: piani, sale, quante scrivanie e quanti posti, e se una sala intera può essere prenotata.
- [ ] I suoi giorni e orari di apertura, e i giorni di chiusura.

**Da sapere**

- Può aprire senza identità legale e senza coordinate bancarie; le servono prima della prima fattura.
- Faccia prima lo schizzo su carta. L’app disegna piani, sale, scrivanie e posti; è più veloce inserire una pianta a cui ha già pensato.

**Vedi anche:** [Preparare uno spazio con il questionario di configurazione](help:user.start.questionnaire)

<!-- anchor: setup.before.permanent -->
### Decisioni difficili da annullare

**Destinatari:** Proprietario · Comproprietario

Vuole sapere su quali scelte rallentare. La maggior parte delle impostazioni si può cambiare in qualsiasi giorno. Queste no, o non senza conseguenze.

> **Attenzione** Una fattura emessa non cambia mai e il suo numero non viene mai riutilizzato. Se sbaglia, corregge con uno storno, una nota di credito o una richiesta di rimborso, non con una modifica.

| Decisione | Quando diventa definitiva | Che cosa fare invece |
|---|---|---|
| Formato e sequenza del numero di fattura | Il numero successivo può essere aumentato, mai diminuito. Dopo la prima fattura non può più stampare una parte della data inferiore a quella che la serie mostra. | Veda l’anteprima del formato, chieda al commercialista, poi emetta. |
| Il mese di una fattura emessa | Quando il mese di un membro è fatturato, è bloccato; i giorni di chiusura e le importazioni dei giorni festivi lo saltano. | Imposti i giorni di chiusura prima della fine del mese. |
| Regime IVA e aliquote | Le aliquote hanno una versione per data e non si modificano mai; una dichiarazione IVA trasmessa non viene mai ricalcolata. | Aggiunga una nuova aliquota da una data; decida il regime con il commercialista. |
| Paese, valuta, fuso orario | Gli importi sono memorizzati come numeri, senza conversione. Quando lo spazio ha emesso un documento o registrato denaro, il server rifiuta qualsiasi cambio di valuta o paese. Il fuso orario non è mai bloccato, ma ogni giorno si conta in esso. | Li scelga bene il primo giorno; veda [Costruire il luogo](help:setup.place.overview). |
| Sostituzione della planimetria | L’importazione di una pianta viene rifiutata quando esistono prenotazioni. | Modifichi piani e sale uno per uno nell’editor. |
| ID dello spazio | È ciò che i membri digitano e ciò a cui puntano i codici QR stampati. Può cambiarlo (da 4 a 20 lettere o cifre) con **Cambia l'ID dello spazio**, ma il vecchio ID smette subito di funzionare. | Scelga un ID breve e facile da ricordare prima di stampare qualsiasi cosa; se deve, lo cambi presto. |
| Prova o reale | Uno spazio reale emette fatture dovute; i documenti di sviluppo portano una filigrana. | Cominci in uno spazio di prova, poi rilasci quando è pronto. |
| Una regola che richiede più validatori di quanti ne abbia | Le richieste restano in attesa per sempre. | Conti i suoi validatori prima di richiederne due. |

**Da sapere**

- Disattivare una funzionalità non cancella mai i dati.
- Eliminare un piano rimuove tutti gli uffici, le scrivanie e i posti che contiene.

**Vedi anche:** [Denaro](help:setup.money.permanent)

<!-- anchor: setup.before.who -->
### Chi fa che cosa

**Destinatari:** Proprietario · Comproprietario · Amministratore · Operatore

Vuole sapere a chi rivolgersi per che cosa. Possono essere coinvolte tre persone, e l’elenco di preparazione le nomina.

| Chi | Che cosa fa |
|---|---|
| **Proprietario** (e *Comproprietario*) | Tutto ciò che riguarda lo spazio: piani, orari, funzionalità, ruoli, tariffe, identità legale, inviti, rilasci. I comproprietari hanno per impostazione predefinita tutti i permessi; il proprietario decide che cosa possono fare gli amministratori. |
| **Operatore** | Gestisce l’installazione: il server e i suoi segreti, e gli aggiornamenti del database. Serve perché le notifiche push funzionino e per tutto ciò che l’elenco di preparazione chiama **In attesa di un’altra persona**. |
| **Amministratore del database** | Approva l’accesso di un membro per gli assistenti. |

**Da sapere**

- In un’installazione condivisa l’operatore è di solito quello della piattaforma, non Lei.
- Gli amministratori agiscono nei limiti dei permessi che il proprietario ha dato loro nella [matrice dei ruoli](help:user.roles.matrix).
- Se una sezione dice **L’operatore del server**, l’app non può farlo dalla sua schermata.

**Vedi anche:** [Decidere chi può fare che cosa](help:user.roles.matrix) · [Permessi di rilascio](help:user.advanced.deploy-permissions)
