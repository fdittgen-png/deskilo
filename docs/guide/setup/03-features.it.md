<!-- anchor: setup.features.overview -->
## Scegliere che cosa offre il suo spazio

Uno spazio non è un unico prodotto con cento impostazioni. È un insieme ristretto di cose che decide di offrire, una alla volta. Questo capitolo spiega come DesKilo raggruppa ciò che sa fare, che cosa ha già un nuovo spazio, come i vari elementi dipendono l’uno dall’altro e in quale ordine attivarli, così da non offrire mai qualcosa che non è ancora in grado di gestire.

In questo capitolo:
- [Funzionalità e processi](help:setup.features.what)
- [Essenziale e Piattaforma: che cosa ha un nuovo spazio](help:setup.features.tiers)
- [Funzionalità che ne richiedono altre](help:setup.features.dependencies)
- [Disattivare non cancella nulla](help:setup.features.off)
- [Beta, Non valutata e la domanda prima di attivare](help:setup.features.maturity)
- [Tre punti di partenza](help:setup.features.profiles)
- [L’ordine in cui attivare le cose](help:setup.features.order)
- [Attivare una funzionalità in sicurezza](help:setup.features.safely)
- [Evitare funzionalità in contraddizione tra loro](help:setup.features.consistency)
- [La mappa delle funzionalità](help:setup.features.map)

<!-- anchor: setup.features.what -->
### Funzionalità e processi

**Destinatari:** Proprietario · Comproprietario

Vuole sapere che cosa sta attivando quando apre **Funzionalità**. Tutto ciò che DesKilo sa fare oltre alle basi è una funzionalità con il suo interruttore. Per tenere leggibili cento interruttori, la schermata li raggruppa in base alla loro finalità.

<p><img src="images/setup-features-what.it.jpg" width="280"></p>

*Come è organizzato*

- Un *processo* è un compito dell’attività: per esempio **Fatturazione e pagamenti** o **Calendario e coordinamento**. Sono nove.
- Un *sottoprocesso* è una tappa di quel compito: **Fatturazione**, **Incasso dei pagamenti** e **Gestione IVA** sono tre delle cinque tappe di **Fatturazione e pagamenti**.
- Una *funzionalità* è un singolo interruttore all’interno di un sottoprocesso: **Fatture**, **Solleciti di pagamento**, **Dichiarazioni IVA**.

*I nove processi e i loro sottoprocessi*

| Processo | Sottoprocessi |
|---|---|
| **Spazio e accesso** | **Persone e adesioni** · **Accesso fisico** |
| **Gestione degli spazi** | **Struttura dello spazio** · **Giorni e orari di apertura** · **Presentazione dello spazio** |
| **Prenotazioni e utilizzo** | **Prenotare postazioni e spazi** · **Presenze e utilizzo** |
| **Calendario e coordinamento** | **Viste del calendario** · **Decisioni e approvazioni** · **Comunicazione tra membri** |
| **Offerte per i membri** | **Servizi e prezzi** |
| **Fatturazione e pagamenti** | **Registrazioni finanziarie** · **Fatturazione** · **Incasso dei pagamenti** · **Spese condivise** · **Gestione IVA** |
| **Documenti e informazioni** | **Pubblicazione dei documenti** · **Progettazione dei rapporti** · **Accesso ai dati ed esportazioni** |
| **Operazioni e amministrazione** | **Configurazione e distribuzione** · **Utilizzo dell’applicazione** |
| **Integrazioni e automazione** | **Invio esterno** |

**Da sapere**

- Una funzionalità appartiene a un solo processo, anche quando ne richiede una di un altro. La scheda lo dice: «Attivare tutto richiede anche: Scheda Finanze (Fatturazione e pagamenti)».
- I piani di iscrizione e l’editor della planimetria non sono funzionalità: ci sono sempre. Le loro impostazioni si trovano in Spazio di lavoro e Fatturazione, non in questa schermata. I carnet prepagati sono una funzionalità: veda **Carnet**.
- Disattivare una funzionalità la nasconde da ogni schermata in cui compariva; non è un permesso. Chi può fare che cosa si decide nei [Ruoli](help:user.roles.matrix).

**Vedi anche:** [Che cosa può fare DesKilo](help:setup.before.what) · [Attivare o disattivare interi processi](help:user.features.processes)

<!-- anchor: setup.features.tiers -->
### Essenziale e Piattaforma: che cosa ha un nuovo spazio

**Destinatari:** Proprietario · Comproprietario

Vuole sapere che cosa trovano i membri il primo giorno, prima che Lei abbia attivato qualsiasi cosa.

<p><img src="images/setup-features-tiers.it.jpg" width="280"></p>

Ogni funzionalità appartiene a uno di due livelli, e un nuovo spazio viene creato a partire da questi:

| Livello | Con le parole dell’app | Che cosa riceve un nuovo spazio |
|---|---|---|
| **Essenziale** | Ciò di cui ogni spazio ha bisogno. Attivo dal primo giorno. | Attiva, quando la funzionalità è pensata per essere attiva all’inizio. |
| **Piattaforma** | Su richiesta, mai data per scontata. Attivi ciò che questo spazio usa davvero. | Disattivata. In **Interruttori** sono elencate sotto il livello **Piattaforma**. |

Un nuovo spazio parte con 45 funzionalità attive, tutte Essenziali (46 se crea nello stesso momento il gemello di prova: in tal caso è attiva anche **Coppie di ambienti**). In parole semplici:

- Prenotazione: riservare un posto sulla planimetria, ripetere una prenotazione (**Prenotazione in serie**), prenotare per un’altra persona (**Prenota per altri**), vedere un posto parzialmente prenotato come parzialmente occupato (**La giornata di una postazione**), salvare una prenotazione in un calendario personale (**File calendario di una prenotazione**), regole di prenotazione come le prenotazioni passate e quelle fuori orario (**Regole di prenotazione**, **Controllo prenotazione**), richiedere l’eliminazione di una prenotazione passata (**Richieste di eliminazione prenotazioni**), stampare schede QR per i posti (**Codici QR degli spazi**), orari di lavoro configurabili (**Orari di lavoro**).
- Persone: la scheda della comunità (**Elenco dei membri**), una pagina per ogni membro (**Scheda membro**), la matrice centrale dei ruoli (**Gestione dei ruoli** e **Assegnazione dei ruoli**), i dati personali per lettere e fatture (**Dati personali**), iniziali distinte sugli avatar (**Iniziali avatar distinte**).
- Calendario e messaggi: il calendario in più viste (**Scheda Calendario**, **Calendario centrale**, **Viste del calendario**), il flusso delle attività e le conferme (**Scheda Eventi**), conversazioni private e di gruppo (**Notifiche tra membri**, **Messaggi, rinnovati**) con riferimenti, inoltro, menzioni, gesti di scorrimento e protezione dalle catture dello schermo, il raggruppamento del flusso delle notifiche (**Raggruppamento delle notifiche**) e il pulsante per scrivere agli organizzatori di una pagina pubblicata (**Scrivi ai gestori**).
- Denaro: la scheda Finanze con le sue quattro viste (**Scheda Finanze**, **Finanze in quattro viste**), le fatture (**Fatture**), un catalogo di servizi (**Servizi**), un PDF del conto mensile (**Esportazione PDF**).
- Documenti e dati: la biblioteca dei documenti (**Biblioteca documenti**), l’esportazione dei dati per il proprietario (**Esportazione dati (Excel)**) e l’esportazione e la cancellazione dei propri dati da parte di ogni membro (**Esportazione e cancellazione**).
- Comfort: suggerimenti di aiuto, la scheda Primi passi, preferiti e valutazioni dei posti, animazioni, formati regionali e la scelta dello stile di navigazione.
- Recapito: **Notifiche push**, che raggiungono i telefoni solo quando chi gestisce l’installazione ha configurato il servizio push (veda [Come vengono informati i membri](help:setup.notify.channels)).
- Riordino della planimetria: **Eliminare spazi con cronologia** e **Chiamare con il piano un piano a stanza unica**.

Tutto il resto è Piattaforma e disattivato: chiosco e badge, più sedi, supplementi accessori, pagamenti online, gestione IVA, il percorso della fattura, progettazione dei rapporti, distribuzioni, WhatsApp, l’interfaccia per gli assistenti e il resto.

**Da sapere**

- La funzionalità delle fatture è attiva fin dall’inizio, ma non si può emettere nulla finché la sua identità legale non è completa; **Configurazione di questo spazio** la segna **Necessario prima di fatturare**. Veda [Evitare funzionalità in contraddizione tra loro](help:setup.features.consistency).
- Uno spazio già esistente non cambia mai quando DesKilo modifica ciò che riceve un nuovo spazio.
- Se parte da un modello, il modello può attivare o disattivare alcune funzionalità in aggiunta a questo insieme. Veda [Tre punti di partenza](help:setup.features.profiles).

**Vedi anche:** [Un interruttore di funzionalità](help:user.features.switch)

<!-- anchor: setup.features.dependencies -->
### Funzionalità che ne richiedono altre

**Destinatari:** Proprietario · Comproprietario

Vuole attivare qualcosa ed essere sicuro che funzioni, oppure disattivare qualcosa senza rompere ciò che ne dipende.

Molte funzionalità dipendono da un’altra. **Pagamenti online** richiede **Scheda Finanze**; **Solleciti di pagamento** richiede **Fatture**; **Solleciti di pagamento automatici** richiede **Solleciti di pagamento**; **Dichiarazioni IVA** richiede **Gestione IVA**, che richiede **Fatture**. Nell’elenco **Interruttori**, una funzionalità che ne richiede un’altra mostra **Richiede** seguito dal nome della funzionalità da cui dipende.

*Che cosa fa l’app*

| Lei | L’app |
|---|---|
| Attiva una funzionalità la cui funzionalità madre è disattivata | Attiva l’intera catena e indica che cosa si è attivato con essa: «Attivato anche: …». |
| Disattiva una funzionalità madre | Non cancella le scelte delle sue funzionalità figlie. Restano memorizzate come le aveva impostate, ma non fanno nulla; la riga dice «In attesa della funzione qui sopra: attivala e anche questa torna a funzionare». |
| Riattiva la funzionalità madre | Le figlie che erano attive tornano subito a funzionare. |
| Disattiva un intero processo o sottoprocesso mentre qualcosa ne ha ancora bisogno | Rifiuta e indica chi ne ha bisogno («… è ancora necessaria per: …»), a meno che non scelga **Disattiva comunque, conserva le impostazioni** o di disattivare anche le dipendenti. |

**Da sapere**

- Una figlia attiva che attende la funzionalità madre fa comparire nel suo processo la dicitura **Richiede attenzione**. È l’unico stato in cui un interruttore e l’app non concordano, quindi vale la pena dargli un’occhiata. Veda [Attivare una funzionalità in sicurezza](help:setup.features.safely).
- Una funzionalità madre può trovarsi in un processo diverso da quello della figlia: **Servizi** (Offerte per i membri) richiede **Scheda Finanze** (Fatturazione e pagamenti). La scheda avverte allora che attivare tutto richiede anche l’altra.
- Il controllo riguarda la funzionalità, non un permesso: un ruolo che può fare qualcosa non basta mai se la funzionalità è disattivata.

**Vedi anche:** [Un interruttore di funzionalità](help:user.features.switch) · [Attivare o disattivare interi processi](help:user.features.processes)

<!-- anchor: setup.features.off -->
### Disattivare non cancella nulla

**Destinatari:** Proprietario · Comproprietario

Vuole poter cambiare idea in seguito, quindi deve sapere che cosa un interruttore non tocca.

Disattivare una funzionalità blocca le nuove operazioni. Non cancella nemmeno un dato: fatture, prenotazioni, messaggi, ruoli e impostazioni restano dove sono, e riattivando la funzionalità tornano disponibili. Ciò che è già stato fatto resta fatto: una fattura emessa mentre la funzionalità era attiva conserva quanto riporta.

Dietro le quinte, DesKilo suddivide le azioni di una funzionalità attivabile in tre tipi:

| Tipo | Che cosa fa l’interruttore | Esempio |
|---|---|---|
| Lavoro nuovo (*acceptNew*) | Si ferma quando la funzionalità è disattivata. | Avviare una nuova conversazione con gli organizzatori; assegnare a un membro un ruolo personalizzato; bloccare un posto; avviare un nuovo pagamento online. |
| Lavoro già aperto (*serviceExisting*) | Prosegue, così che nulla resti in sospeso. | Rispondere a una conversazione già avviata; revocare un ruolo personalizzato; togliere il blocco a un posto; regolare un pagamento già aperto. |
| Percorsi non sicuri (*suspended*) | Restano chiusi qualunque cosa dica l’interruttore. | Riservato a un percorso che il server giudica non sicuro; oggi nessuna azione è classificata così. |

Tre funzionalità lo dicono nella loro riga, con queste parole: «Disattivato: non inizia nulla di nuovo; ciò che è già aperto può ancora essere gestito e chiuso.» Sono **Scrivi ai gestori**, **I ruoli di questo spazio** e **Gli admin possono bloccare i posti**. Anche **Check-in/out automatico a fine giornata**, quando è disattivata, interrompe la sua elaborazione di fine giornata, ma la sua riga non lo dice. Su un server che non può confermarlo, la riga dice «non contarci».

**Da sapere**

- Il denaro già impegnato viene sempre regolato: il ritorno di un pagamento o un rimborso non è mai bloccato da un interruttore.
- Con **Pagamenti online** disattivati, il server rifiuta un nuovo pagamento online; uno già aperto viene comunque regolato. La sua riga non riporta alcuna nota in proposito.
- Un interruttore non è un modo per nascondere qualcosa a una sola persona. Per questo usi i [Ruoli](help:user.roles.matrix).

**Vedi anche:** [Un interruttore di funzionalità](help:user.features.switch)

<!-- anchor: setup.features.maturity -->
### Beta, Non valutata e la domanda prima di attivare

**Destinatari:** Proprietario · Comproprietario

Vede una piccola parola sotto il nome di una funzionalità e vuole sapere che cosa farne.

<p><img src="images/setup-features-maturity.it.jpg" width="280"></p>

Ogni riga di **Interruttori** porta un badge di maturità, che indica fino a che punto la funzionalità è stata verificata con prove concrete:

| Badge | Che cosa significa |
|---|---|
| **Non valutata** | Nessuno l’ha ancora valutata con prove concrete. Non dice nulla di negativo. |
| **Alfa** | Valutata, a uno stadio iniziale. |
| **Beta** | Valutata, con limiti noti; i suoi test vengono eseguiti a ogni modifica. |
| **Stabile** | Valutata e qualificata anche con fornitori, hardware o operatori reali. |

Al momento in cui scriviamo, la maggior parte delle funzionalità risulta **Non valutata**, diciotto risultano **Beta** e nessuna ha ancora raggiunto lo stato **Stabile**.

*Che cosa chiede l’app*

1. Sposti l’interruttore di una funzionalità **Alfa** o **Beta**.
2. L’app chiede **Attivare una funzione sperimentale?** e dice: «Non ancora valutata come stabile: … Può cambiare e ha limiti noti. Attivala solo se questo spazio lo accetta.»
3. Indica lo stadio di ogni funzionalità e quelle che si attiverebbero con essa perché necessarie.
4. Tocchi **Attiva** per accettare, oppure **Annulla**: non viene scritto nulla.

**Da sapere**

- Le funzionalità **Non valutata** non fanno domande. Solo **Alfa** e **Beta** le fanno.
- La domanda viene posta su un singolo interruttore. Un **Attiva** su un intero processo mostra che cosa attiverà, ma non pone questa domanda: attivi le funzionalità **Beta** una per una.
- Al momento in cui scriviamo, tra le funzionalità Beta ci sono **Fatture**, **Pagamenti online**, **Gestione IVA**, **Carnet**, **Spese condivise**, **Rilevamenti di utilizzo**, **Regole di prenotazione**, **Prenotazione in serie**, **Controllo prenotazione**, **Richieste di eliminazione prenotazioni**, **Finanze in quattro viste**, **Scorte dalle spese**, **Convalidatori per ruolo o persona**, **Convalide concatenate**, **Check-in/out automatico a fine giornata**, **Esportazione dati (Excel)**, **Recapito delle fatture al cliente** e lo spazio dimostrativo. Legga i limiti di ciascuna funzionalità con **Altro** prima di farci affidamento per il denaro.
- Molte di queste sono Essenziali e già attive in un nuovo spazio. Partono attive senza la domanda; la domanda compare solo quando ne riattiva una.
- **Maturità** restringe l’elenco a uno stadio, un modo rapido per vedere tutto ciò che è sperimentale e che il suo spazio già usa.

**Vedi anche:** [Un interruttore di funzionalità](help:user.features.switch)

<!-- anchor: setup.features.profiles -->
### Tre punti di partenza

**Destinatari:** Proprietario · Comproprietario

Non vuole decidere cento cose. Ecco tre punti di partenza realistici; ciascuno elenca esattamente che cosa è attivo. Scelga il più vicino, poi adatti.

Il primo non richiede alcun modello. Il secondo è il modello già pronto dell’app. Il terzo è costruito a partire dalle funzionalità stesse. Prendono il nome da ciò che offrono, non da una dimensione.

<!-- anchor: setup.features.profile-tiny -->
### Pochi posti condivisi

**Destinatari:** Proprietario

Gestisce una manciata di scrivanie o di sale che le persone prenotano, e per ora nient’altro. Crei lo spazio con **Spazio vuoto** oppure con il modello «A tiny space» sotto **Partire da**: due piani, quattro scrivanie e otto posti, abbastanza per prenotare, scansionare ed esplorare.

Il modello non imposta alcuna funzionalità, quindi lo spazio ha esattamente le 45 funzionalità Essenziali descritte in [Essenziale e Piattaforma](help:setup.features.tiers). Nulla è attivato oltre a questo. Per questo profilo, lasci stare il resto:

- Prenotazione, calendario, messaggi, elenco, schede QR per i posti, biblioteca dei documenti e suggerimenti di aiuto ci sono tutti.
- **Scheda Finanze** e **Fatture** sono attive, ma finché non inserisce la sua identità legale e le tariffe mostrano solo un estratto conto vuoto.
- Non c’è nulla da configurare al di fuori della planimetria e degli orari di apertura. Veda [Il suo luogo](help:setup.place.overview).

> **Consiglio** Se non fa mai pagare nulla, può lasciare attive le funzionalità del denaro senza alcun danno: i membri semplicemente non vedono nulla da pagare.

<!-- anchor: setup.features.profile-association -->
### Un’associazione con una sala

**Destinatari:** Proprietario

È un’associazione francese che condivide una sala, con un ufficio di presidenza, membri che pagano una quota e prenotazioni a mezza giornata. Scelga il modello «Association de coworking (France)» sotto **Partire da**. Imposta le regole di apertura, le fasce di tariffa al 50 % e al 100 %, due carnet prepagati, i ruoli dell’ufficio di presidenza, la terminologia francese e due piani, e porta con sé questo profilo di funzionalità:

- Le 45 funzionalità Essenziali, tranne quattro che disattiva: **Scheda Eventi**, **Elenco dei membri**, **Scheda membro** e **Raggruppamento delle notifiche**. Una piccola associazione non ha bisogno di un flusso di eventi o di un elenco accanto alle sue conversazioni.
- Quattro che **attiva**, perché l’ufficio di presidenza ne ha bisogno: **Convalide nel calendario** (le decisioni mostrate nel calendario), **Carnet** (mezze giornate prepagate per chi non sottoscrive un abbonamento, Beta), **I ruoli di questo spazio** (tesoriere, segretario, referente della sala) e **Lessico dello spazio** (le parole proprie dell’associazione).

Fa 45 − 4 + 4 = 45 funzionalità attive. Il modello non porta alcuna identità, quindi l’indirizzo, il numero di registrazione e le coordinate bancarie restano da inserire a Lei, e il regime IVA parte come «non soggetto».

**Da sapere**

- Carnet è Beta ed è attivato dal modello senza la domanda; è una scelta del modello e può disattivarlo.
- Il modello lascia attive le **Fatture** dall’insieme Essenziale. Un’associazione che non fattura può lasciarle così.

<!-- anchor: setup.features.profile-invoicing -->
### Un coworking che fattura

**Destinatari:** Proprietario

Affitta scrivanie ai membri e invia loro fatture ogni mese, in Francia o in Germania. Non esiste un modello già pronto, quindi questo profilo è un elenco di ciò che aggiungere all’insieme Essenziale, in quest’ordine. Tutto dipende a catena da **Scheda Finanze** e **Fatture**, che sono già attive.

| N. | Attivi | Perché | Richiede |
|---|---|---|---|
| 1 | **Serie di numerazione** | Decida come numerare i documenti prima che esista il primo. | **Fatture** |
| 2 | **Fatture di abbonamento** | La quota di iscrizione viene fatturata prima del mese che paga. | **Fatture** |
| 3 | **Rilevamenti di utilizzo** | Un registro del tempo realmente utilizzato (Beta). | **Fatture** |
| 4 | **Fatture di fine mese** | Ciò che il mese è costato oltre all’abbonamento viene fatturato a parte. | **Fatture** |
| 5 | **Assistente di fatturazione** | Una chiusura del mese guidata per chi si occupa della fatturazione. | **Fatture** |
| 6 | **Il percorso di una fattura** | Ogni fattura mostra a che punto è e a chi tocca la mossa successiva. | **Fatture** |
| 7 | **Modello PDF della fattura** | La sua introduzione e il suo piè di pagina nel PDF. | **Fatture** |
| 8 | **Report dei membri** | L’accordo finanziario e il rapporto mensile dei pagamenti per i membri. | **Scheda Finanze** |
| 9 | **Solleciti di pagamento** | Livelli di sollecito, una lettera per livello, «Sollecito dovuto» sulle fatture in ritardo. | **Fatture** |
| 10 | **Report dei consumi** | Una lettera a fine mese con quanto è stato utilizzato. | **Rilevamenti di utilizzo** |

Poi aggiunga solo ciò che la riguarda:

- **Gestione IVA** (Beta) se il suo spazio è registrato ai fini IVA. Poi **Dichiarazioni IVA**, e **Versioni delle aliquote IVA** e **Gruppi IVA** se il commercialista li richiede.
- **Gli admin emettono fatture** se vuole che sia un amministratore della fatturazione a emetterle. Il proprietario può sempre farlo.
- **Pagamenti online** (Beta) solo quando ha un fornitore di pagamenti da collegare.
- **Solleciti di pagamento automatici** solo dopo aver letto [che cosa fanno](help:setup.money.reminders).
- **Supplementi accessori**, **Carnet** e **Spese condivise** quando fattura queste cose.

**Da sapere**

- Prima della prima fattura, completi la sua identità legale e l’IVA. Veda [Identità legale e fatturazione](help:setup.money.identity).
- L’emissione qui funziona solo per gli spazi in Francia e in Germania.
- Attivi queste funzionalità una alla volta ed emetta prima una fattura di prova in uno spazio di prova. Veda [L’ordine in cui attivare le cose](help:setup.features.order).

**Vedi anche:** [Denaro e fatturazione](help:setup.money.overview) · [Partire da un modello o da zero](help:setup.before.template)

<!-- anchor: setup.features.order -->
### L’ordine in cui attivare le cose

**Destinatari:** Proprietario · Comproprietario

Vuole evitare il giorno in cui tutto è attivo e nulla funziona. Proceda un processo alla volta e guardi ciascuno dal punto di vista di un membro prima di passare oltre.

<p><img src="images/setup-features-order.it.jpg" width="280"></p>

**Passaggi**

1. Tenga l’insieme Essenziale e faccia funzionare le basi: i posti, gli orari di apertura, una tariffa. Veda [Il suo luogo](help:setup.place.overview).
2. Apra [Funzionalità](app:/features) e apra la scheda di un processo. Scelga il processo che corrisponde alla sua prossima necessità, non quello che sembra più completo.
3. Tocchi **Attiva** per un sottoprocesso, oppure apra una singola funzionalità tra gli **Interruttori**.
4. Legga l’anteprima: che cosa è **Necessarie anche**, che cosa è già attivo.
5. La guardi come un membro: acceda come tale (con un secondo account o dal lato di prova del suo spazio) e faccia ciò che farebbe un membro.
6. Solo allora passi al processo successivo.

*Un ordine sensato*

| Passo | Processo | Perché in questo punto dell’ordine |
|---|---|---|
| 1 | **Gestione degli spazi** | Senza un luogo e degli orari di apertura non si può prenotare nulla. |
| 2 | **Prenotazioni e utilizzo** | Le regole di prenotazione danno forma a tutto ciò che segue. |
| 3 | **Spazio e accesso** | I ruoli e chi convalida, prima del primo invito. |
| 4 | **Calendario e coordinamento** | Messaggi e convalide presuppongono che le persone esistano. |
| 5 | **Offerte per i membri**, poi **Fatturazione e pagamenti** | I prezzi prima delle fatture; l’identità legale prima della prima fattura. |
| 6 | **Documenti e informazioni**, **Integrazioni e automazione** | Rivestono e recapitano ciò che gli altri producono. |
| 7 | **Operazioni e amministrazione** | Coppie, distribuzioni e trasferimenti una volta che lo spazio vale la pena di essere copiato. |

**Da sapere**

- Attivare costa poco e disattivare non cancella nulla, quindi un passo sbagliato costa tempo, non dati. L’eccezione è tutto ciò che emette una fattura: veda [Decisioni difficili da annullare](help:setup.before.permanent).
- Uno spazio di prova è il posto giusto per provare un processo. Veda [Uno spazio di prova o uno reale](help:setup.before.environment) e [Uno spazio di prova](help:user.advanced.test-space).
- Inviti i membri per ultimi, dopo i ruoli, le regole di convalida e le tariffe che incontreranno.

**Vedi anche:** [Attivare o disattivare interi processi](help:user.features.processes)

<!-- anchor: setup.features.safely -->
### Attivare una funzionalità in sicurezza

**Destinatari:** Proprietario · Comproprietario

Sta per cambiare una funzionalità e vuole vedere l’effetto prima che esista.

<p><img src="images/setup-features-safely.it.jpg" width="280"></p>

**Passaggi**

1. Apra [Funzionalità](app:/features). Viene mostrata la vista **Processi**.
2. Tocchi **Richiede attenzione**. Restano solo i processi che contengono qualcosa di attivo ma in attesa.
3. Apra una scheda. Una funzionalità attiva e in attesa di una funzionalità madre indicata è ciò che va sistemato.
4. La sistemi attivando la funzionalità madre, oppure disattivando la funzionalità.
5. Per cambiare una sola funzionalità, tocchi **Interruttori**, la trovi con **Cerca funzionalità** e sposti il suo interruttore.
6. Legga la domanda o la riga «Attivato anche», e confermi.

*Che cosa significa «trattenuta»*

Una funzionalità è trattenuta quando l’ha scelta, ma qualcosa di cui ha bisogno è disattivato. Il suo interruttore resta attivo, ed è per questo che è facile non accorgersene: la schermata dice che la funzionalità è attiva, e l’app non la offre. La scheda indica quante funzionalità sono trattenute («… attive ma attendono un prerequisito disattivato») e quale prerequisito attendono, e Lei lo sistema nella schermata [Funzionalità](app:/features) stessa. [Che cosa richiede la Sua attenzione](help:user.collaborate.attention) mostra la stessa cosa con una riga per ogni prerequisito disattivato.

Altre cose che una funzionalità può attendere non si trovano in questa schermata. Una funzionalità può essere attiva e pienamente consentita mentre mancano i suoi dati: la sua identità legale, una sede, un fornitore di pagamenti. Compaiono in **Configurazione di questo spazio**, in cima alle impostazioni dello spazio: l’identità legale, con **Fatture** attiva, come **L'identità legale e l'indirizzo dello spazio**, il resto sotto **Dati richiesti dalle funzioni (identità, banca, piattaforme)** di lavoro.

**Da sapere**

- Se qualcun altro ha modificato le funzionalità mentre le guardava, l’app non scrive nulla e lo dice: «Le funzionalità sono cambiate nel frattempo, quindi non è stato salvato nulla.» Riguardi l’elenco e riprovi.
- **Modificate** conta gli interruttori che differiscono dal valore predefinito del registro. In un nuovo spazio mostra già un numero (le funzionalità Piattaforma che partono disattivate), quindi non è un conteggio delle sue modifiche.
- Solo un proprietario o un comproprietario può scrivere le funzionalità. Il server ricontrolla nel momento della scrittura.

**Vedi anche:** [Attivare o disattivare interi processi](help:user.features.processes) · [Un interruttore di funzionalità](help:user.features.switch)

<!-- anchor: setup.features.consistency -->
### Evitare funzionalità in contraddizione tra loro

**Destinatari:** Proprietario · Comproprietario · Amministratore fatturazione

Vuole sapere quali combinazioni lasciano uno spazio a metà e quali l’app intercetta per Lei.

L’app ha dei controlli per alcune contraddizioni e nessuno per altre. Nella tabella, un controllo è ciò che fa l’app; una lacuna è ciò che resta di sua responsabilità.

| Se ha… | Controllo nell’app | Lacuna che resta |
|---|---|---|
| **Fatture** attive, nessuna identità legale | L’emissione viene rifiutata, con **Completa questi dati prima dell'emissione** che elenca l’indirizzo mancante, il numero di partita IVA e così via. La necessità compare anche in **Configurazione di questo spazio**, come **L'identità legale e l'indirizzo dello spazio**, **Necessario prima di fatturare**, e nella Sua posta. | La funzionalità è attiva dal primo giorno, quindi nulla impedisce di invitare i membri e di gestire un mese prima che esista l’identità. |
| Un paese diverso da Francia o Germania | L’emissione dice che il paese «deve essere Francia o Germania per emettere qui». | Nulla la avvisa quando sceglie il paese o attiva la fatturazione. |
| Registrato ai fini IVA, nessuna aliquota in vigore | L’emissione viene rifiutata finché non è in vigore un’aliquota predefinita. La descrizione di **Gestione IVA** e l’avviso nella schermata dell’identità legale lo dicono. | Con **Gestione IVA** disattivata, la configurazione è nascosta mentre le aliquote memorizzate continuano ad applicarsi. Controlli le aliquote dopo averla disattivata. |
| **Pagamenti online** attivi, nessun fornitore | Un nuovo pagamento online viene rifiutato quando la funzionalità è disattivata; il fornitore mancante compare in **Configurazione di questo spazio**. | Può attivarla senza un fornitore. Lo colleghi prima: [Fornitore di pagamenti](help:user.money.payments.provider). |
| **Modalità chiosco** attiva, nessun badge e nessun membro chiosco | **Badge RFID / NFC**, **Badge QR**, **Foto dei membri al chiosco** e **Accedi con un badge** non possono essere attivi senza di essa. | Nulla verifica che esista un membro chiosco o che sia stato emesso un badge. Veda [Gestire un tablet a muro](help:user.kiosk.mode). |
| **Sedi** attive, nessuna sede | **Almeno una sede** compare tra i dati richiesti dalle funzioni. | L’interruttore può essere attivo senza alcuna sede. |
| **Notifiche push** attive, nessun servizio push | I membri ricevono comunque tutto nell’app. | I telefoni non ricevono nulla finché chi gestisce l’installazione non ha configurato il servizio push. Veda [Come vengono informati i membri](help:setup.notify.channels). |
| **Solleciti di pagamento** attivi, **Solleciti di pagamento automatici** attivi | I secondi non possono essere attivi senza i primi. | Il server li invia ogni mattina se l’installazione pianifica attività; altrimenti vengono inviati quando un amministratore apre Finanze. L’interruttore e la descrizione della funzionalità lo dicono; l’operatore del Suo server sa quale vale. |
| Una regola di convalida che richiede più validatori di quanti ne esistano | **Configurazione di questo spazio** dice «Una regola richiede più validatori di quanti ne abbia questo spazio» e **Ruoli e chi convalida le richieste** diventa obbligatoria, qualunque sia il tipo di richiesta. | Le richieste create prima della correzione non possono essere completate e scadono dopo sette giorni. Veda [Chi convalida](help:user.validation.overview). |
| **Richieste di eliminazione prenotazioni** attive, nessuno che convalidi | Stessa riga di preparazione. | Stessa lacuna. |
| **Prenotazioni di tavolo, ufficio e piano** attive | **Gli admin possono assegnare piani** ne ha bisogno. | Ogni membro deve inoltre avere il diritto; nulla verifica che qualcuno lo abbia. |
| Una funzionalità figlia attiva, la sua madre disattivata | **Richiede attenzione** e «In attesa della funzione qui sopra». | Nessuna: questo caso è pienamente coperto. |
| Uno spazio creato da un modello | Il modello indica che cosa spetta a Lei inserire (identità, banca, sede). | Non ne porta nessuna, quindi uno spazio può partire con le **Fatture** attive e nulla con cui emettere. |

**Da sapere**

- La regola pratica: se una funzionalità porta su un documento il suo nome, il suo denaro o i suoi obblighi legali, completi i suoi dati prima di avvisare i membri.
- **Configurazione di questo spazio** è un elenco, non un blocco. Non le impedisce mai di attivare qualcosa.
- Il controllo «Prima che qualcuno possa prenotare qui» parla solo delle aree obbligatorie: il fuso orario, la valuta, un giorno della settimana aperto, almeno un posto, membri che possiedono **Prenotare e usare le prenotazioni** e abbastanza validatori. Con **Fatture** attiva anche l’identità legale è obbligatoria, ma prima di fatturare: la scheda dello spazio dice «Prima di fatturare» e quella di Prenota non la nomina mai.

**Vedi anche:** [Identità legale e fatturazione](help:setup.money.identity) · [Prova a vuoto](help:setup.money.dry-run)

<!-- anchor: setup.features.map -->
### La mappa delle funzionalità

**Destinatari:** Proprietario · Comproprietario

Vuole un unico punto che dica, per le funzionalità principali, che cosa ricevono i membri, di che cosa ha bisogno e chi deve configurarla. «Richiede» elenca prima la funzionalità da cui dipende, poi i dati esterni alla schermata Funzionalità. «Chi» è la persona che deve fare qualcosa prima che sia utile; «Nessuno» significa che funziona non appena è attiva.

*Spazio e accesso*

| Funzionalità | Che cosa aggiunge per i membri | Di che cosa ha bisogno | Chi configura |
|---|---|---|---|
| **Elenco dei membri** | La scheda della comunità: chi c’è, stati, presenza. | | Nessuno |
| **Comproprietari** | Permessi da proprietario a persone designate, subito o in caso di successione. | | Proprietario |
| **Gestione dei ruoli** | La matrice di quale ruolo detiene quale permesso. | | Proprietario |
| **Assegnazione dei ruoli** | Una sezione Ruoli in ogni scheda membro. | **Gestione dei ruoli** | Proprietario |
| **I ruoli di questo spazio** | Ruoli propri, come tesoriere o segretario. | | Proprietario |
| **Le domande di questo spazio** | Domande proprie nel modulo di identità. | | Proprietario |
| **Dati personali** | Nome, indirizzo, telefono e identificativi che le lettere riportano. | | Membri |
| **Profili gestiti** | Membri senza account, per i quali si prenota e si fattura. | **Elenco dei membri** | Amministratore |
| **Scheda membro** | Una pagina per ogni membro. | **Elenco dei membri** | Nessuno |
| **Visite degli ospiti** | Una persona che non è membro può chiedere di fare visita. | | Chi ammette le visite |
| **Modalità chiosco** | Un tablet a muro bloccato sulla planimetria in tempo reale. | Un tablet e un membro chiosco | Proprietario |
| **Badge RFID / NFC** | Registrare l’arrivo toccando una tessera. | **Modalità chiosco**, Android con NFC, badge emessi | Proprietario |
| **Badge QR** | Tessere badge QR stampabili. | **Modalità chiosco** | Proprietario |
| **Accedi con un badge** | Badge e PIN al posto della digitazione di un indirizzo e-mail. | **Badge RFID / NFC** | Proprietario, poi ogni membro |
| **Tag NFC/RFID delle sedie** | Un chip su una sedia apre il suo posto. | Tag | Proprietario |
| **Codici QR degli spazi** | Schede QR stampabili per ogni posto. | | Nessuno |

*Gestione degli spazi*

| Funzionalità | Che cosa aggiunge per i membri | Di che cosa ha bisogno | Chi configura |
|---|---|---|---|
| **Sedi** | Più indirizzi, ciascuno con la propria registrazione. | Almeno una sede | Proprietario |
| **Eliminare spazi con cronologia** | I proprietari possono eliminare un posto che ha prenotazioni passate. | | Nessuno |
| **Gli admin possono bloccare i posti** | Posti segnati come non prenotabili per manutenzione. | | Proprietario |
| **Orari di lavoro** | La giornata lavorativa e la prenotazione a orario esatto. | | Proprietario |
| **Giorni festivi** | Giorni di chiusura ricavati dai giorni festivi di un anno. | | Proprietario |
| **Importa i giorni festivi** | Giorni festivi di un paese o di una regione importati. | **Giorni festivi** | Proprietario |
| **Occupazione dei posti** | Un dato mensile su quanto è stato prenotato. | | Proprietario |
| **Foto dei membri sulla piantina** | Le foto degli occupanti sui posti. | | Nessuno |
| **Lessico dello spazio** | Le parole proprie dello spazio per alcune etichette. | | Proprietario |
| **Colori dello spazio** | Il colore del marchio e i colori delle sale. | | Proprietario |
| **Scheda pubblica dello spazio** | Una pagina pubblica con ciò che sceglie di mostrare. | | Proprietario |

*Prenotazioni e utilizzo*

| Funzionalità | Che cosa aggiunge per i membri | Di che cosa ha bisogno | Chi configura |
|---|---|---|---|
| **Prenotazione in serie** | Ripetere una prenotazione. | | Nessuno |
| **Prenota per altri** | Gli amministratori prenotano per i membri. | | Nessuno |
| **Prenotazioni di tavolo, ufficio e piano** | Prenotare un’intera scrivania, un ufficio o un piano. | Un diritto concesso a ciascun membro | Proprietario |
| **Gli admin possono assegnare piani** | Gli amministratori assegnano quelle prenotazioni. | **Prenotazioni di tavolo, ufficio e piano** | Proprietario |
| **Regole di prenotazione** | Prenotazioni passate, prenotazioni fuori orario, check-out da parte dell’amministratore. | | Proprietario |
| **Controllo prenotazione** | Ogni schermata verifica le regole e ne indica il motivo. | **Regole di prenotazione** | Nessuno |
| **Check-in/out automatico a fine giornata** | Le prenotazioni senza registrazione si completano da sole. | | Proprietario |
| **Rilevamenti di utilizzo** | Il tempo realmente utilizzato e una richiesta per non fatturare il tempo non usato. | **Fatture** | Amministratore fatturazione |

*Calendario e coordinamento*

| Funzionalità | Che cosa aggiunge per i membri | Di che cosa ha bisogno | Chi configura |
|---|---|---|---|
| **Scheda Calendario**, **Calendario centrale**, **Viste del calendario** | Mese, settimana e agenda, con tutto ciò che ha una data. | | Nessuno |
| **Convalide nel calendario** | Le decisioni mostrate nel momento in cui sono state prese. | **Calendario centrale** | Nessuno |
| **Scheda Eventi** | Il flusso delle attività e le conferme. | | Nessuno |
| **Raggruppamento delle notifiche** | Notifiche raggruppate nel flusso. | | Nessuno |
| **Convalidatori per ruolo o persona** | Una regola può indicare chi convalida e quanti. | | Proprietario |
| **Convalide concatenate** | Convalide richieste una dopo l’altra. | | Proprietario |
| **Richieste di eliminazione prenotazioni** | Un membro chiede di eliminare una prenotazione passata. | Un validatore | Proprietario |
| **Notifiche tra membri** | Conversazioni private e di gruppo. | | Nessuno |
| **Messaggi, rinnovati** | Barra della posta in arrivo, fissare, silenziare, archiviare, bozze. | | Nessuno |
| **Scrivi ai gestori** | Chi trova la sua pagina può scriverle. | Una pagina pubblicata | Proprietario |
| **Menzioni nei gruppi**, **Inoltro dei messaggi**, **Protezione dalle catture dello schermo** | Extra della messaggistica. | **Notifiche tra membri** | Nessuno |

*Offerte per i membri*

| Funzionalità | Che cosa aggiunge per i membri | Di che cosa ha bisogno | Chi configura |
|---|---|---|---|
| **Servizi** | Un catalogo di cose da consumare e pagare. | **Scheda Finanze** | Amministratore fatturazione |
| **Supplementi accessori** | Accessori dei posti con prezzo per mezza giornata. | **Scheda Finanze** | Amministratore fatturazione |
| **Negoziazioni di prezzo** | Condizioni proprie per un singolo membro. | **Scheda Finanze** | Amministratore fatturazione |
| **Condizioni di pagamento per membro** | Condizioni di pagamento proprie. | **Fatture** | Amministratore fatturazione |
| **Carnet** | Mezze giornate prepagate (Beta). | **Fatture**, un carnet definito | Amministratore fatturazione |

*Fatturazione e pagamenti*

| Funzionalità | Che cosa aggiunge per i membri | Di che cosa ha bisogno | Chi configura |
|---|---|---|---|
| **Scheda Finanze** | La scheda Finanze: estratto conto, pagamenti, spese. | | Nessuno |
| **Finanze in quattro viste** | Estratto conto, Pagamenti, Fatture, Documenti. | **Scheda Finanze** | Nessuno |
| **Report dei membri** | L’accordo e il rapporto mensile dei pagamenti. | **Scheda Finanze** | Amministratore fatturazione |
| **Fatture** | Fatture firmate e immutabili (Beta). | **Scheda Finanze**, identità legale, IVA, FR o DE | Amministratore fatturazione |
| **Gli admin emettono fatture** | Anche gli amministratori le emettono. | **Fatture** | Proprietario |
| **Fatture di abbonamento** | La quota fatturata prima del suo mese. | **Fatture**, una data | Amministratore fatturazione |
| **Fatture di fine mese** | L’utilizzo fatturato dopo il mese. | **Fatture** | Amministratore fatturazione |
| **Raggruppa le fatture** | Più fatture aperte come una sola. | **Fatture** | Amministratore fatturazione |
| **Il percorso di una fattura** | A che punto è ogni fattura. | **Fatture** | Nessuno |
| **Assistente di fatturazione** | Una chiusura del mese guidata. | **Fatture** | Amministratore fatturazione |
| **Serie di numerazione** | Numerazione per registro. | **Fatture** | Amministratore fatturazione |
| **Pagamenti online** | Pagare online (Beta). | **Scheda Finanze**, un fornitore di pagamenti | Proprietario |
| **Solleciti di pagamento** | Livelli di sollecito e lettere. | **Fatture**, regole | Amministratore fatturazione |
| **Solleciti di pagamento automatici** | Solleciti inviati in automatico. | **Solleciti di pagamento** | Amministratore fatturazione |
| **Scorte dalle spese** | Le scorte acquistate diventano servizi. | **Servizi** | Amministratore fatturazione |
| **Spese programmate** | Costi ricorrenti pianificati. | **Scheda Finanze** | Amministratore fatturazione |
| **Spese condivise** | Costi condivisi tra i membri. | **Fatture** | Amministratore fatturazione |
| **Assistente di ripartizione** | Una suddivisione guidata di un costo condiviso. | **Spese condivise** | Amministratore fatturazione |
| **Libro contabile** | Chi tiene i libri ufficiali. | **Fatture** | Amministratore fatturazione |
| **Gestione IVA** | Aliquote IVA e selettori (Beta). | **Fatture**, regime IVA | Amministratore fatturazione |
| **Dichiarazioni IVA** | La dichiarazione periodica. | **Gestione IVA** | Amministratore fatturazione |
| **Gruppi IVA**, **Versioni delle aliquote IVA**, **IVA secondo il cliente** | Una gestione dell’IVA più fine. | **Gestione IVA** | Amministratore fatturazione |

*Documenti e informazioni, Operazioni, Integrazioni*

| Funzionalità | Che cosa aggiunge per i membri | Di che cosa ha bisogno | Chi configura |
|---|---|---|---|
| **Biblioteca documenti** | Statuti, verbali, guide, per ruolo. | | Proprietario |
| **Esportazione PDF** | Il conto mensile in PDF. | | Nessuno |
| **Modello PDF della fattura** | I suoi testi sulla fattura. | **Fatture** | Proprietario |
| **Designer di report**, **Layout di report posizionati**, **Testi dei report** | Rapporti progettati. | **Modello PDF della fattura** | Proprietario |
| **Report dei consumi** | Una lettera mensile su quanto è stato utilizzato. | **Rilevamenti di utilizzo** | Amministratore fatturazione |
| **Rapporto IVA** | Ogni riga imponibile, con un CSV. | **Dichiarazioni IVA** | Amministratore fatturazione |
| **Registro degli accessi ai dati** | I membri vedono chi ha consultato le loro finanze. | **Scheda Finanze** | Nessuno |
| **Esportazione dati (Excel)** | Il proprietario esporta i dati come cartella di lavoro (Beta). | Il permesso **Esportare contabilità e dati** | Proprietario |
| **Esportazione e cancellazione** | Un membro esporta e cancella i propri dati. | | Nessuno |
| **Modalità ripresa** | Sostituisce sullo schermo le persone reali con persone inventate. | | Proprietario |
| **Coppie di ambienti**, **Distribuzioni** | Un lato di prova e uno reale, con distribuzione. | | Proprietario |
| **Configurazione nel file dello spazio** | L’intera configurazione viaggia nel file dello spazio. | **Esportazione dati (Excel)** | Proprietario |
| **Assistente istanza** | Creare un nuovo server dall’app. | | Operatore |
| **Cosa ti aspetta** | Un unico elenco ordinato di ciò che attende Lei. | | Nessuno |
| **Registratore di attività** | Registrare e riprodurre i passaggi di un’attività. | | Nessuno |
| **Notifiche push** | Conferme in sospeso sul telefono. | Il servizio push dell’installazione | Operatore |
| **Integrazione WhatsApp** | Una chat con un membro con un tocco, il link del gruppo. | **Elenco dei membri** | Proprietario |
| **Recapito delle fatture al cliente** | Invio alla piattaforma del cliente (Beta). | **Fatture**, un account | Amministratore fatturazione |
| **Interfaccia MCP** | Si può collegare un assistente. | Un’autorizzazione per persona, approvata dall’installazione | Proprietario, poi Operatore |

**Da sapere**

- I nomi sono quelli dell’elenco **Interruttori**. Il livello Essenziale o Piattaforma di ciascuna è mostrato lì.
- Alcune funzionalità non sono elencate qui. Le funzionalità di comfort (suggerimenti di aiuto, animazioni, stile di navigazione, formati regionali) non hanno una riga nella tabella: funzionano non appena sono attive.

**Vedi anche:** [Chi fa che cosa](help:setup.before.who) · [Attivare o disattivare le funzionalità](help:user.features.processes)
