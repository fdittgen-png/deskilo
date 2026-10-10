<!-- anchor: setup.money.overview -->
## Denaro e imposte

Per i proprietari e gli amministratori di fatturazione che stanno per decidere come si paga uno spazio. Questo capitolo parla delle decisioni e del loro ordine; i clic sono nella guida utente, e ogni sezione rimanda ad essa.

> **Attenzione** DesKilo registra, calcola e stampa ciò che Lei dichiara, e verifica che i dati richiesti siano presenti. Non certifica le Sue fatture, il Suo trattamento IVA né la Sua contabilità. Ogni volta che questo capitolo dice «chieda al Suo commercialista», lo faccia.

In questo capitolo:
- Se i membri pagano e chi emette le fatture
- Come si costruisce una tariffa, con le cifre dello spazio dimostrativo *Atelier du Marché*
- Come i membri Le pagano
- La Sua identità legale e le domande da portare al commercialista
- Fatturazione manuale o automatica, solleciti e IVA in breve
- Le decisioni economiche che non si possono annullare e come provarle senza rischi

<!-- anchor: setup.money.decide -->
### Decida prima: i membri pagano e chi emette le fatture

**Destinatari:** Proprietario

Sceglie fin dove DesKilo arriva nella Sua gestione del denaro. Tutto il resto di questo capitolo discende da questa scelta, che è facile ampliare in seguito e difficile ridurre una volta emesse le fatture.

<p><img src="images/setup-money-paths.it.jpg" width="280"></p>

**Prima di iniziare**

Risponda a due domande: i membri Le pagano lo spazio e vuole che le fatture legali escano da DesKilo?

| Percorso | Lo scelga quando | Che cosa succede |
|---|---|---|
| 1. Nessun denaro | Lo spazio è gratuito, oppure i membri sono amici che dividono l'affitto fuori dall'app | Lascia spente le funzioni economiche. I membri prenotano; nessuno riceve una fattura. |
| 2. Estratti conto e pagamenti, fatture all'esterno | Ha già un commercialista o uno strumento di fatturazione, oppure lavora in un paese per cui DesKilo non può emettere fatture | I membri hanno un estratto conto mensile, Lei registra i pagamenti ricevuti ed esporta le cifre per il commercialista. Le fatture legali vengono prodotte altrove. |
| 3. Fatture emesse da DesKilo | Si trova in Francia o in Germania ed è soggetto a IVA oppure fuori campo IVA (un'associazione, per esempio) | DesKilo produce fatture firmate e numerate a partire dalle prenotazioni, con la Sua identità legale stampata. |

**Passaggi**

1. Scelga il Suo percorso dalla tabella.
2. Per il percorso 2 o 3, attivi in [Funzionalità](help:user.features.switch) le funzioni economiche che Le servono: **Fatture** è la base di tutto ciò che viene emesso, e le funzioni sottostanti (**Fatture di abbonamento**, **Fatture di fine mese**, **Solleciti di pagamento**, **Gestione IVA**) si attivano una alla volta.
3. Per il percorso 3, prosegua con [la Sua identità legale](help:setup.money.identity) prima della prima prenotazione, non dopo.

**Da sapere**

- L'emissione di fatture nell'app esiste oggi per uno spazio in **Francia** o in **Germania**. In qualsiasi altro paese usi il percorso 2: gli estratti conto restano disponibili.
- Il server rifiuta di emettere, e l'elenco **Completi questi dati prima dell'emissione** ne spiega il motivo, quando manca un dato o quando il trattamento non è gestito da DesKilo: vendite transfrontaliere, inversione contabile, esportazioni e fatture esenti da IVA vanno verificate ed emesse fuori dall'app con il Suo commercialista.
- Un venditore in regime di franchigia per le piccole imprese (franchise en base, Kleinunternehmer) non può emettere fatture nell'app: il server rifiuta la categoria IVA esente. Resti sul percorso 2 ed emetta quelle fatture altrove.
- Spegnere una funzione ferma le nuove operazioni di quel tipo; non cancella nulla.
- Può restare sul percorso 2 per sempre. Molte associazioni lo fanno.

**Risultato**

Sa quale dei tre percorsi è il Suo e di quali funzioni ha bisogno.

**Vedi anche:** [La fatturazione in sintesi](help:user.money.invoicing) · [Attivare o disattivare interi processi](help:user.features.processes)

<!-- anchor: setup.money.tariff -->
### Progettare una tariffa

**Destinatari:** Proprietario · Amministratore fatturazione

Trasforma la domanda «quanto vale un posto?» in numeri che DesKilo può applicare ogni mese senza di Lei.

<p><img src="images/setup-money-bands--bands.it.jpg" width="280"></p>

**Prima di iniziare**

Tenga a mente il modello. Si legge da sinistra a destra e ogni passo alimenta il successivo:

1. Percentuale di abbonamento: un membro detiene una percentuale del mese: 25, 50, 75 o 100 %, oppure un valore che Lei consente.
2. Quota di mezze giornate: la percentuale diventa un numero di mezze giornate per il mese: i giorni di apertura, per due, per la percentuale, arrotondato per eccesso.
3. Fascia tariffaria: la percentuale rientra in una fascia, che dà la quota mensile e il prezzo di una mezza giornata in più. Una fascia copre «sopra il suo inizio, fino alla sua fine inclusa», e le fasce insieme devono coprire da 0 a 100 % senza buchi.
4. Regola di superamento: quando la quota è esaurita, ogni membro viene bloccato, addebitato al prezzo di superamento oppure invitato ad acquistare un pacchetto.
5. Pacchetti e servizi: un pacchetto di giornate vende in anticipo mezze giornate in più a un prezzo da Lei fissato; i servizi (un caffè, un armadietto, la stampa) si vendono in aggiunta.

**Passaggi**

1. Decida le percentuali da offrire in **Livelli di abbonamento** e se un proprietario può digitare un valore negoziato (vedi [Livelli di abbonamento](help:user.money.billing.levels)).
2. Imposti una riga per ogni intervallo in **Fasce tariffarie**: il suo limite superiore, la quota mensile e il prezzo di superamento (vedi [Fasce tariffarie](help:user.money.billing.fee-bands)).
3. Stabilisca il comportamento predefinito per chi esaurisce la quota: [Quando i giorni finiscono](help:user.members.overage-policy).
4. Aggiunga i [pacchetti di giornate](help:user.money.billing.packages) e i [servizi](help:user.money.services.overview) che vende.

**Da sapere**

- Il calcolo è congelato su ogni documento emesso. Cambiare un prezzo cambia il mese successivo, mai un mese già fatturato.
- Gli orari di apertura e i giorni di chiusura decidono quanti giorni di apertura ha un mese, e quindi la dimensione della quota. Li imposti per primi.
- Un membro senza abbonamento è pensato per i visitatori che acquistano carnet; non può essere a consumo.

**Vedi anche:** [Fatturazione](help:user.money.billing.fee-bands) · [L'abbonamento di un membro](help:user.members.subscription)

<!-- anchor: setup.money.example -->
### Un esempio svolto

**Destinatari:** Proprietario · Amministratore fatturazione

Segue un membro lungo un mese con le cifre di *Atelier du Marché*, così può controllare i Suoi numeri allo stesso modo.

<p><img src="images/setup-money-packages--packages.it.jpg" width="280"></p>

**Prima di iniziare**

Lo spazio dimostrativo ha tre fasce tariffarie, in euro e IVA inclusa. Le cifre sono quelle della demo, non una raccomandazione.

| Fascia | Quota mensile | Mezza giornata in più | Mezze giornate in un mese di 22 giorni di apertura |
|---|---|---|---|
| fino al 25 % | 0,00 | 15,00 | 11 |
| oltre il 25 %, fino al 50 % | 150,00 | 8,00 | 22 |
| oltre il 50 %, fino al 100 % | 250,00 | 0,00 | 44 (al 100 %) |

**Passaggi**

1. Un membro detiene il 50 %. In un mese con 22 giorni di apertura la quota è 22 × 2 × 50 / 100 = 22 mezze giornate.
2. Il 50 % rientra nella seconda fascia (oltre 25, fino a 50): la quota è 150,00, qualunque sia l'uso del membro.
3. Il membro prenota 24 mezze giornate. Due superano la quota, a 8,00 ciascuna: 16,00.
4. Il mese costa 150,00 + 16,00 = 166,00, prima di eventuali servizi. Nella demo i prezzi sono lordi: l'IVA al 20 % è compresa e la schermata la mostra sotto ogni prezzo.
5. Confronti con un pacchetto: il pacchetto da 5 giorni della demo costa 40,00 e aggiunge 10 mezze giornate (5 giorni, due mezze giornate ciascuno), cioè 4,00 a mezza giornata. Rispetto agli 8,00 di superamento conviene dalla sesta mezza giornata in più in un mese.

**Da sapere**

- Un prezzo di superamento di 0,00 significa che le mezze giornate in più non costano nulla a consumo.
- L'estratto conto che il membro vede mostra le stesse righe: quota, inclusi, usati, extra, superamento.
- I prezzi sono mostrati IVA inclusa quando l'IVA è attiva; l'imposta viene estratta da essi.
- Se Lei e un membro concordate altre condizioni, vedi la [negoziazione dei prezzi](help:setup.money.negotiation).

**Risultato**

Può prevedere il conto di un membro con tre numeri: la sua percentuale, i giorni di apertura, le prenotazioni.

**Vedi anche:** [Leggere il proprio estratto conto](help:user.money.statement) · [Quanto è costata ogni prenotazione](help:user.money.usage)

<!-- anchor: setup.money.negotiation -->
### Negoziazione dei prezzi

**Destinatari:** Proprietario · Amministratore fatturazione

Vuole che un membro paghi condizioni diverse dalla tariffa, in modo che ne resti traccia.

**Passaggi**

1. Attivi la funzione di negoziazione dei prezzi in [Funzionalità](help:user.features.switch).
2. Proponga le condizioni nella pagina del membro: una quota mensile diversa, una tariffa di superamento, uno sconto sui supplementi, prezzi unitari o una percentuale di occupazione (vedi [Negoziazione dei prezzi](help:user.members.negotiation)).
3. Lasci che sia la regola di convalida per le negoziazioni di prezzo a decidere chi la conferma.

**Da sapere**

- La tariffa resta quella predefinita; un prezzo negoziato appartiene a un solo membro.
- Lo vedono il membro, i proprietari e le persone autorizzate a consultare gli accordi commerciali, e ogni lettura viene registrata.
- Definisca la Sua politica prima di aprire: un'eccezione concessa in silenzio diventa il prezzo che tutti chiedono.

**Vedi anche:** [I Suoi prezzi negoziati](help:user.money.negotiation)

<!-- anchor: setup.money.pay -->
### Come i membri Le pagano

**Destinatari:** Proprietario · Amministratore fatturazione

Sceglie dove va il denaro di un membro e quanto lavoro DesKilo svolge al Suo posto.

<p><img src="images/setup-money-payment-instructions.it.jpg" width="280"></p>

**Passaggi**

1. Cominci dalla via gratuita: compili le [istruzioni di pagamento](help:user.money.payments.methods): il Suo IBAN e i dati bancari, e quello tra PayPal.me, Wero, Lydia o Wise che accetta, più un suggerimento per la causale.
2. I membri vedono questi dati su un estratto conto non pagato. Quando un pagamento arriva sul Suo conto, Lei o un amministratore di fatturazione lo [registra](help:user.money.payments.record).
3. Solo se vuole che i membri paghino dentro l'app, colleghi un fornitore in [Pagamenti online](help:user.money.payments.provider): PayPal, Stripe o Mollie. Servono la funzione **Pagamenti online** e un Suo conto presso il fornitore.

**Da sapere**

- DesKilo registra i pagamenti; con la via manuale non sposta mai denaro.
- Un fornitore applica le proprie commissioni e riceve le chiavi del Suo conto (la scheda delle credenziali spiega come vengono inserite).
- Con **Pagamenti online** spento, un nuovo pagamento online viene rifiutato; uno già aperto può ancora concludersi.
- Uno spazio creato da un modello non porta con sé i dati di pagamento: li inserisca in ogni spazio. Un'esportazione della configurazione li include.

**Vedi anche:** [Pagare ciò che si deve](help:user.money.payments) · [Credenziali del fornitore](help:user.money.payments.credentials)

<!-- anchor: setup.money.identity -->
### La Sua identità legale e che cosa chiedere al commercialista

**Destinatari:** Proprietario

Dice a DesKilo chi vende, così che ogni fattura La indichi correttamente. È la parte da concordare con un professionista.

<p><img src="images/setup-money-legal--top.it.jpg" width="280"></p>

**Prima di iniziare**

La schermata è [Identità legale e fatturazione elettronica](app:/legal-identity). Tenga pronti:

- il tipo di organizzazione: un'impresa oppure un'associazione senza scopo di lucro;
- il Suo regime IVA: fuori campo IVA, esente da IVA (regime delle piccole imprese) oppure soggetto a IVA. L'app può emettere fatture solo per il primo e per l'ultimo; con la franchigia per le piccole imprese la schermata registra il Suo stato, ma le fatture vanno emesse altrove (percorso 2);
- il numero di registrazione e, se ne ha uno, il numero di partita IVA;
- il Suo indirizzo postale, come figura nella registrazione;
- il motivo per cui non viene applicata l'IVA, se non ne applica.

> **Attenzione** Scegliere il regime è una decisione fiscale, non un'impostazione del software. Un'associazione senza attività commerciale è normalmente fuori campo IVA, e la schermata Le segnala se sceglie «esente» per una di esse. Confermi la scelta prima di emettere la prima fattura.

**Passaggi**

1. Apra [Identità legale e fatturazione elettronica](app:/legal-identity) e proceda dall'alto: prima il **Regime IVA**, poi gli identificativi, l'indirizzo e le **Menzioni di fatturazione**.
2. Compili le condizioni di pagamento, le menzioni sui ritardi di pagamento e le altre menzioni richieste dal Suo paese (vedi [La Sua identità legale](help:user.money.legal.identity)).
3. Tocchi **Salva**, poi legga una volta il modello di fattura insieme al commercialista (vedi [Il modello PDF della fattura](help:user.money.reports.invoice-template)).

> **Consiglio** Domande da portare al commercialista:
>
> 1. A quale tipo di organizzazione e a quale regime IVA appartengo?
> 2. Quali sono il mio numero di registrazione e la mia partita IVA, e come si scrivono?
> 3. Se non applico l'IVA, quale formulazione di legge lo giustifica?
> 4. Quali menzioni devono comparire sulle mie fatture (termine di pagamento, penale per ritardato pagamento, indennità di recupero, sconto per pagamento anticipato, assicurazione)?
> 5. Come vanno numerate le fatture, e il numero riparte ogni anno o ogni mese?
> 6. Quando diventa esigibile l'IVA sui miei servizi secondo la regola del mio Paese (incasso, mese della prestazione, fattura), e devo optare per un'altra base, come l'IVA per cassa?
> 7. Devo inviare fatture elettroniche a una piattaforma pubblica, e a quale?
> 8. Mi servono dichiarazioni IVA periodiche, e con quale frequenza?

**Da sapere**

- Le fatture già emesse conservano l'identità con cui sono state firmate; una modifica vale per le successive.
- Solo un proprietario o un comproprietario attivo può aprire questa schermata, e la funzione **Fatture** deve essere attiva.
- Uno spazio creato da un modello non porta con sé la Sua identità: la inserisca di nuovo. Un trasferimento tra i due lati di una coppia la include.

**Vedi anche:** [Regime IVA](help:user.money.vat.regime) · [La piattaforma di fatturazione elettronica](help:user.money.einvoice.overview) · [Tipo di organizzazione](help:user.money.legal.seller-kind)

<!-- anchor: setup.money.invoicing -->
### Fatturare a mano o in automatico

**Destinatari:** Proprietario · Amministratore fatturazione

Decide se una persona preme i pulsanti ogni mese o se ci pensa DesKilo.


**Passaggi**

1. Per un primo mese lavori a mano: apra [Fatturazione](app:/invoices), legga **Da emettere** ed emetta la fattura di un membro (vedi [Emettere una fattura](help:user.invoicing.new-invoice)).
2. Per la routine usi l'[assistente di chiusura mensile](help:user.invoicing.wizard): percorre **Revisione**, **Emetti**, **Invia**, **Sollecita**, **Pagamenti**, **Abbina**, **Chiudi** e **Riepilogo**.
3. Per automatizzare, attivi **Fatture di abbonamento** e **Fatture di fine mese** in [Funzionalità](help:user.features.switch), poi imposti i giorni nel [Calendario delle fatture](help:user.money.billing.schedule).

**Da sapere**

- Ogni mese esistono due documenti: la quota di abbonamento, emessa prima del mese, e ciò che il mese è costato davvero, emesso dopo. Una fattura può essere datata alcuni giorni in anticipo (tre per impostazione predefinita, regolabili nel calendario delle fatture), per cui una datata 29 agosto può riguardare settembre.
- Sul server, un'esecuzione giornaliera emette entrambe quando il database dell'installazione ha lo scheduler attivo; se non ne è sicuro, lo chieda all'operatore.
- Ogni tipo di fattura (abbonamento, fine mese) può essere emesso una sola volta per membro e per mese. Le fatture non si possono modificare né eliminare; una fattura sbagliata viene contrassegnata come errata e sostituita.
- Per impostazione predefinita emettono le fatture il proprietario e i comproprietari. **Gli admin emettono fatture** estende questa facoltà agli amministratori.

**Vedi anche:** [La schermata Fatturazione](help:user.invoicing.hub) · [Sollecitare e incassare le fatture aperte](help:user.invoicing.open)

<!-- anchor: setup.money.reminders -->
### Solleciti di pagamento

**Destinatari:** Proprietario · Amministratore fatturazione

Decide quando un pagamento è in ritardo e chi si occupa di sollecitare.

<p><img src="images/setup-money-reminders.it.jpg" width="280"></p>

**Passaggi**

1. Attivi **Solleciti di pagamento** in [Funzionalità](help:user.features.switch). Si trova sotto **Fatture**.
2. Imposti il numero di livelli e i tempi nelle [Regole di sollecito](help:user.money.reminders.rules): giorni fino al primo sollecito, giorni tra un sollecito e l'altro.
3. Decida se i solleciti partono da soli: attivi **Solleciti automatici** nella stessa finestra (vedi [Solleciti automatici](help:user.money.reminders.automatic)); deve essere attiva anche la funzione **Solleciti di pagamento automatici**.

**Da sapere**

- Il tempo prima del primo sollecito vale anche come Suo termine di pagamento. Lo imposti con i [Termini di pagamento](help:user.money.legal.payment-terms).
- I solleciti automatici girano una volta al giorno sul server quando il database ha lo scheduler attivo. Girano anche quando chi può emettere fatture (un proprietario, un comproprietario o un amministratore, se **Gli admin emettono fatture** è attivo) apre Finanze: così anche uno spazio senza scheduler li riceve, nei giorni in cui qualcuno guarda. Lo dicono anche l'interruttore e la descrizione della funzionalità; l'operatore del Suo server sa quale vale.
- La funzione **Solleciti di pagamento** rende disponibili soltanto le regole. Un sollecito parte da solo solo se **Solleciti automatici** è attivo nelle regole di sollecito, e questo resta spento finché non lo sceglie Lei.
- Saltano una fattura con un pagamento in sospeso o in attesa, e una fattura senza termine di pagamento registrato.
- Il membro riceve un avviso nel suo flusso e, se le notifiche push sono configurate, una notifica generica; vedi [Informare le persone](help:setup.notify.overview).

**Vedi anche:** [Termini di pagamento](help:user.money.legal.payment-terms)

<!-- anchor: setup.money.vat -->
### L'IVA in breve

**Destinatari:** Proprietario · Amministratore fatturazione

Vuole sapere che cosa l'IVA Le chiederà prima di attivarla.

<p><img src="images/setup-money-vat--rates.it.jpg" width="280"></p>

**Passaggi**

1. Solo se è soggetto a IVA, attivi **Gestione IVA** in [Funzionalità](help:user.features.switch).
2. Imposti le aliquote in [IVA](app:/vat): **Usa le aliquote consuete** per il Suo paese, poi ne contrassegni esattamente una come predefinita (vedi [Impostare le aliquote](help:user.money.vat.rates)).
3. Assegni a ogni aliquota il suo gruppo e, dove serve, un motivo di esenzione (vedi [Gruppi IVA](help:user.money.vat.groups)).
4. Quando la legge cambia un'aliquota, usi **Modifica per legge** così che le fatture precedenti mantengano la loro aliquota (vedi [Modificare un'aliquota per legge](help:user.money.vat.change-by-law)).
5. Se deve presentare dichiarazioni, attivi **Dichiarazioni IVA** e generi ogni periodo in [Dichiarazione IVA](help:user.money.vat.declaration).

**Da sapere**

- Viene fornito un catalogo di aliquote per gli Stati membri dell'UE, la Svizzera, la Norvegia e il Canada. Tenerlo aggiornato quando un governo cambia un'aliquota spetta a Lei.
- Se è registrato senza un'aliquota predefinita in vigore, il server rifiuta di emettere. La descrizione di **Gestione IVA** e l'avviso nella schermata dell'identità legale lo dicono.
- Una dichiarazione è un ausilio alla presentazione, costruito dalle Sue fatture emesse. La verifichi prima di presentarla e la segni come presentata solo dopo averlo fatto.
- Il giornale delle dichiarazioni ha una propria serie di numerazione.

**Vedi anche:** [Regime IVA](help:user.money.vat.regime) · [Quando l'IVA diventa esigibile](help:user.money.vat.due)

<!-- anchor: setup.money.permanent -->
### Ciò che non si può annullare

**Destinatari:** Proprietario

Vuole sapere, prima della prima fattura, che cosa non potrà più cambiare in seguito.

<p><img src="images/setup-money-numbering.it.jpg" width="280"></p>

> **Attenzione** Dalla prima fattura emessa, le voci qui sotto sono definitive. Le decida prima con il Suo commercialista.

| Decisione | Che cosa diventa definitivo | Quando |
|---|---|---|
| Una fattura emessa | È firmata e immodificabile: importi, parti, ripartizione dell'IVA e calcolo tariffario restano come stampati. Una correzione è un annullamento, una nota di credito o un rimborso, ciascuno un nuovo documento. | All'emissione |
| Numero di fattura | I numeri sono senza interruzioni e vengono assegnati nel database al momento dell'emissione. Il numero successivo può essere alzato, mai abbassato. Un cambio di formato vale da quel momento. Un azzeramento non può essere più frequente della data stampata nel numero. | Alla prima emissione |
| Un mese fatturato | Un mese con una fattura per un membro è chiuso per quel membro. I giorni di chiusura e le importazioni dei giorni festivi saltano questi mesi e li nominano. | Alla prima fattura del mese |
| Aliquote IVA | Le aliquote sono versionate per data, mai modificate. Una dichiarazione IVA presentata non viene mai ricalcolata. | Al primo utilizzo |
| Valuta e paese | Gli importi sono memorizzati in unità minime intere, senza conversione. Quando lo spazio ha emesso un documento o registrato denaro, il server rifiuta di cambiare l'uno o l'altra. | Al primo documento o pagamento |

**Passaggi**

1. Apra [Serie di numerazione](app:/settings/number-sequences) e imposti prefisso, suffisso, parte della data, cifre e azzeramento per ogni giornale (fatture, note di credito, dichiarazioni IVA, membri, pagamenti). La schermata richiede la funzione **Serie di numerazione**.
2. Mostri il risultato al commercialista prima della prima fattura.
3. Scelga paese, valuta e fuso orario nelle [Impostazioni dello spazio](help:user.workspace.settings.country) prima che qualcuno prenoti.

**Da sapere**

- I numeri non si sprecano: un documento la cui emissione fallisce non ne consuma alcuno.
- I due stati di uno spazio, prova e produzione, esistono perché nulla di tutto questo venga provato per davvero; vedi [una prova sicura](help:setup.money.dry-run).

**Vedi anche:** [Il registro fatture](help:user.invoicing.register) · [Valuta e fuso orario](help:user.workspace.settings.currency-timezone)

<!-- anchor: setup.money.dry-run -->
### Una prova sicura in uno spazio di prova

**Destinatari:** Proprietario

Prova una volta l'intera routine economica, senza nulla di reale in gioco.

**Passaggi**

1. Crei o apra uno spazio di prova (**Uno spazio di prova**, oppure il lato DEV di una coppia collegata); vedi [Spazio di prova](help:user.advanced.test-space) e [Ambienti](help:user.advanced.environments).
2. Inserisca l'identità legale, le aliquote, la tariffa e le istruzioni di pagamento come intende gestirle.
3. Inviti due o tre persone a prenotare qualche giorno; aggiunga un servizio per una di loro.
4. Esegua l'[assistente di chiusura mensile](help:user.invoicing.wizard) dall'inizio alla fine e legga il PDF della fattura.
5. Registri un pagamento, lasci scadere un sollecito e legga l'estratto conto come membro.
6. Mostri i PDF e l'esportazione contabile al commercialista.

**Da sapere**

- Uno spazio di prova mette una filigrana su ogni documento e dichiara di essere una prova; nulla è dovuto.
- Dichiarare uno spazio in produzione toglie la filigrana; le fatture già emesse conservano la propria.
- La coppia può trasferire la configurazione da un lato all'altro, ma le credenziali non viaggiano.

**Risultato**

Un primo mese già visto e un elenco di domande risolte prima che costino qualcosa.

**Vedi anche:** [I due ambienti](help:user.advanced.environments) · [Esportazioni contabili](help:user.invoicing.accounting-export)
