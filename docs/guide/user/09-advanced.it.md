<!-- anchor: user.advanced.overview -->
## Avanzate

**Destinatari:** Proprietario · Operatore

Ciò che sta attorno al lavoro di ogni giorno: il lato di prova di uno spazio e quello reale, gli assistenti, il registratore di attività e le sue visite guidate, la demo, le app su ogni dispositivo e che cosa fare quando qualcosa non funziona.

In questo capitolo:
- [Uno spazio ha due lati](help:user.advanced.environments) · [Entrare in un lato](help:user.advanced.enter-environment) · [Uno spazio di prova](help:user.advanced.test-space) · [Chi può distribuire](help:user.advanced.deploy-permissions) · [Distribuire tra i lati](help:user.advanced.deploy) · [Situazione dello spazio e archivio dell'esercizio](help:user.advanced.status-archive)
- [Il Suo server](help:user.advanced.own-server)
- [Assistenti](help:user.advanced.assistants) · [Collegare un assistente](help:user.advanced.assistants-connect) · [Approvazioni](help:user.advanced.assistants-approve) · [Che cosa possono fare gli assistenti](help:user.advanced.assistants-policy)
- [Il registratore di attività](help:user.advanced.recorder) · [Registrare un'attività](help:user.advanced.recorder-record) · [Rivedere una registrazione](help:user.advanced.recorder-review) · [Creare una guida](help:user.advanced.guide-make) · [Seguire una guida](help:user.advanced.guide-play) · [Il menu circolare](help:user.advanced.guide-circle) · [Modificare una guida](help:user.advanced.guide-edit) · [Riservatezza delle registrazioni](help:user.advanced.recorder-privacy)
- [Lo spazio dimostrativo](help:user.advanced.demo) · [Modalità ripresa](help:user.advanced.filming)
- [Piattaforme](help:user.advanced.platforms) · [Dettagli per l'assistenza](help:user.advanced.support) · [Quando qualcosa non funziona](help:user.advanced.troubleshooting)
- [Le parole dell'app](help:user.advanced.glossary) · [Accessibilità e tastiera](help:user.advanced.accessibility) · [Altro aiuto](help:user.advanced.help)

<!-- anchor: user.advanced.environments -->
### Uno spazio ha due lati

**Destinatari:** Proprietario

Vuole un posto dove provare senza toccare le prenotazioni e le fatture reali. Uno spazio può essere una coppia: un lato di prova e un lato reale, con lo stesso nome.

<p><img src="images/user-advanced-environments.it.jpg" width="280"></p>

**Passaggi**

1. Quando crea uno spazio, lasci spuntato **Crea la coppia sviluppo e produzione**. Entrambi i lati Le appartengono fin dal primo secondo.
2. Ha già uno spazio isolato? Apra [Impostazioni](app:/settings), vada a **Governance** e tocchi **Crea il suo gemello**. La configurazione viene copiata una sola volta.
3. Da quel momento i due lati sono indipendenti. Solo una distribuzione sposta qualcosa dall'uno all'altro.

**Da sapere**

- Il lato di sviluppo si chiama **Sviluppo — per provare**. Il lato di produzione è **Produzione — le fatture sono dovute**.
- Ogni documento stampato sul lato di sviluppo porta una filigrana, così non può essere scambiato per uno reale.
- **Crea il suo gemello** compare solo quando la funzione **Coppie di ambienti** è attiva, e solo per il proprietario. Il rilascio tra i due lati spetta a chi ha i permessi di rilascio.
- Membri, prenotazioni, fatture e pagamenti non vengono mai copiati tra i lati.

**Vedi anche:** [Entrare in un lato](help:user.advanced.enter-environment) · [Uno spazio di prova](help:user.advanced.test-space)

<!-- anchor: user.advanced.enter-environment -->
### Entrare nel lato reale o in quello di prova

**Destinatari:** Tutti

Vuole aprire uno spazio dal lato che Le serve. Il Suo account vede entrambi i lati di una coppia, ciascuno con il proprio pulsante.

**Passaggi**

1. Apra [Io](app:/me) e trovi lo spazio sotto **I miei spazi**.
2. Tocchi **Apri spazio** per il lato reale, oppure **Spazio di prova** per il lato su cui esercitarsi.
3. Oppure apra [Profili](app:/profiles): la coppia è una sola scheda. La tocchi, poi **Scegli un ambiente** tra **DEV** e **PROD**.

**Da sapere**

- Un lato in cui non può entrare è in grigio e non fa nulla.
- Chi è membro del lato reale è sempre membro anche del lato di prova.
- Il pulsante di prova riporta il suggerimento «Spazio di prova: prenotazioni e fatture di prova»; quello reale «Prenotazioni e fatture reali».

**Vedi anche:** [Chi può distribuire](help:user.advanced.deploy-permissions)

<!-- anchor: user.advanced.test-space -->
### A che cosa serve uno spazio di prova

**Destinatari:** Proprietario

Sta per cambiare prezzi, regole o la piantina e vuole vedere prima l'effetto. Lo faccia sullo spazio di prova.

**Passaggi**

1. Entri nel lato di prova con **Spazio di prova**.
2. Configuri, importi un file dello spazio, inviti un collega, emetta una fattura di prova, sposti i posti, stampi.
3. Quando tutto è a posto, [lo distribuisca sul lato reale](help:user.advanced.deploy).

**Da sapere**

- L'interruttore **Tipo di spazio** in [Impostazioni](app:/settings) (sotto **Governance**) indica di che tipo è uno spazio. Lo vedono solo i proprietari.
- Dichiarare uno spazio di produzione fa comparire **Dichiarare questo spazio di produzione?** — il banner scompare e i documenti perdono la filigrana. Le fatture già emesse conservano la filigrana che avevano.
- Dichiari la produzione solo quando le fatture che escono dallo spazio sono davvero dovute.
- Quando invita qualcuno, può scegliere se raggiunge anche lo spazio di produzione: **Spazio di prova** o **Spazio di produzione**. In ogni caso la persona entra nello spazio di prova.

**Vedi anche:** [Uno spazio ha due lati](help:user.advanced.environments)

<!-- anchor: user.advanced.deploy-permissions -->
### Chi può distribuire ed entrare in produzione

**Destinatari:** Proprietario · Comproprietario

Decide chi può toccare il lato reale. Lo controllano tre permessi nella matrice dei ruoli.

**Passaggi**

1. Apra [Ruoli](app:/roles).
2. Trovi **Entrare nello spazio di produzione**, **Distribuire in sviluppo** e **Distribuire in produzione**.
3. Attivi ciascuno per i ruoli che ne hanno bisogno.

**Da sapere**

- Proprietari e comproprietari li hanno tutti e tre. Gli amministratori hanno **Distribuire in sviluppo** ed **Entrare nello spazio di produzione**. I membri non ne hanno nessuno finché Lei non glielo concede.
- Chi può distribuire in produzione può sempre distribuire in sviluppo.
- Un ruolo entra nel lato di produzione solo finché possiede **Entrare nello spazio di produzione**: altrimenti un invito o un'adesione alla produzione viene rifiutato e l'app ne spiega il motivo.

**Vedi anche:** [La matrice dei ruoli](help:user.roles.matrix) · [Distribuire tra i lati](help:user.advanced.deploy)

<!-- anchor: user.advanced.deploy -->
### Distribuire tra i due lati

**Destinatari:** Proprietario · Comproprietario · Amministratore

Ha messo a punto la configurazione su un lato e vuole che l'altro la riceva.

**Passaggi**

1. Si posizioni sul lato che vuole scrivere e apra [Impostazioni](app:/settings) → **Governance** → [Distribuzione](app:/deployment).
2. Spunti ciò che deve viaggiare. Le entità sono raggruppate in **Configurazione**, **Dati anagrafici** e **Report**; ciò che un'entità **richiede** viene spuntato insieme a essa.
3. Tocchi **Tira da PROD…** (dal lato di sviluppo) o **Tira da DEV…** (dal lato di produzione).
4. Legga l'anteprima: **Cosa cambia sul lato produzione**, oppure sul lato di sviluppo. Quando i due lati coincidono, riporta **Nessuna modifica**.
5. Confermi. La domanda indica il lato che viene scritto: **Distribuire in questo DEV?** oppure **Distribuire in questo PROD?**

**Da sapere**

- Una distribuzione va sempre nel lato su cui si trova. Nulla può essere spinto per errore sull'altro lato.
- Ogni distribuzione finisce nel **Giornale**. **Torna indietro** sull'ultima ripristina ciò che il lato conteneva prima.
- Le piantine vengono unite: ciò che c'è solo su questo lato viene conservato, perché un posto può avere una prenotazione. I tag dei badge non viaggiano mai.
- Membri, prenotazioni, fatture, pagamenti, eventi e credenziali non viaggiano mai.
- La voce compare solo quando la funzione **Distribuzioni** è attiva, lo spazio ha un gemello e Lei possiede un permesso di distribuzione.

**Vedi anche:** [Chi può distribuire](help:user.advanced.deploy-permissions)

<!-- anchor: user.advanced.status-archive -->
### Situazione dello spazio e archivio dell'esercizio

**Destinatari:** Proprietario · Amministratore · Amministratore fatturazione

Vuole un colpo d'occhio su ciò che lo spazio ha fatturato e incassato, e un file completo dell'anno per i Suoi archivi.

**Passaggi**

1. Apra [Situazione dello spazio](app:/money/status). Scelga i mesi in **Dal** e **Al**.
2. Legga **Fatturato**, **Note di credito**, **Pagamenti abbinati**, **Pagamenti ricevuti**, **Spese rimborsate**, **Spese ripartite** e **Crediti concessi**; **Netto** li riassume. Tocchi la stampante per **Stampa la situazione**.
3. Per il file annuale, scelga **Archivio dell'esercizio (zip)** nelle esportazioni delle fatture.

**Da sapere**

- **Netto** non è né un utile né un saldo bancario. I pagamenti abbinati e quelli ricevuti si sovrappongono, quindi non li sommi.
- La situazione compare quando la funzione **Situazione dello spazio** è attiva.
- Uno spazio di sviluppo produce file contrassegnati DEV: non sono la contabilità reale.

**Vedi anche:** [Report dello spazio](help:user.workspace.export.workspace-report)

<!-- anchor: user.advanced.own-server -->
### Gestire il proprio server

**Destinatari:** Operatore · Proprietario

Vuole i dati della Sua comunità su un server che controlla, oppure appartiene a un'organizzazione che ne gestisce uno.

**Passaggi**

1. Legga come si configura un server in [Come gestire il proprio](help:user.backend.how).
2. Su ogni dispositivo, indirizzi l'app verso di esso: [Il Suo server](help:user.backend.server).
3. Controlli [Io](app:/me) → **Dove si trovano i miei spazi**: elenca i server usati da questo account.

**Da sapere**

- L'app punta a un solo server per l'accesso; **Questo dispositivo usa** indica quale. Gli altri server a cui appartiene compaiono sotto **Dove si trovano i miei spazi**.
- Un invito viene verificato solo sul proprio server, quindi si unisca a uno spazio mentre l'app punta al server che lo ha emesso.
- Un operatore può attivare gli assistenti per l'intera installazione — veda [Approvazioni](help:user.advanced.assistants-approve).

**Vedi anche:** [Il Suo server](help:user.backend.server)

<!-- anchor: user.advanced.assistants -->
### Assistenti: che cosa sono

**Destinatari:** Tutti

Un assistente di intelligenza artificiale come Claude o ChatGPT può controllare e prenotare per Lei in DesKilo. Agisce a Suo nome, solo negli spazi e per le azioni che approva.

<p><img src="images/user-advanced-assistants-policy.it.jpg" width="280"></p>

**Passaggi**

1. Apra [Assistenti](app:/assistants). **A che punto sei qui** elenca ciò che ancora manca: **Accesso con Google**, **Identità per gli assistenti**, **Approvazione del database**, **Offerta dello spazio di lavoro**, **Il tuo ruolo**, **Il tuo consenso**, **Server**.
2. Scorra l'elenco; ogni riga dice chi compie il passo successivo.

**Da sapere**

- Partecipano più persone: Lei, il proprietario o un amministratore dello spazio, un amministratore del database e l'operatore dell'installazione. Nessuno da solo può aprire tutto.
- Attivare gli assistenti non concede nulla a nessuno di per sé.
- Sotto **Assistenti collegati** vede che cosa è collegato e può **Disconnetti**. **Il tuo uso degli assistenti oggi** conta **Richieste**, **Rifiutate**, **Applicate** e **In attesa di convalida**.

**Vedi anche:** [Collegare un assistente](help:user.advanced.assistants-connect)

<!-- anchor: user.advanced.assistants-connect -->
### Collegare un assistente

**Destinatari:** Membro · Amministratore · Proprietario

Vuole che il Suo assistente lavori con le Sue prenotazioni e il Suo account.

**Passaggi**

1. Apra [Collegare un assistente](app:/assistants/connect). Sotto **Prima di collegare**, ogni riga dovrebbe riportare **Fatto**.
2. Sotto **Quale assistente usi?**, scelga **Claude**, **Claude Code**, **ChatGPT**, **Cursor**, **VS Code** o **Altro**. Copi **Il tuo indirizzo DesKilo per gli assistenti** al suo interno come indicano i passaggi.
3. Acceda quando l'assistente lo chiede, poi scelga questo spazio e che cosa l'assistente può farvi.
4. Tocchi **Prova la connessione** e chieda al Suo assistente: «Con DesKilo, quali sono le mie prenotazioni di questa settimana?»

**Da sapere**

- È l'assistente stesso a chiederLe di approvare lo spazio e ogni tipo di operazione; nulla viene scelto al Suo posto.
- Il collegamento richiede la funzione **Interfaccia MCP** nello spazio. Se è disattivata, la schermata Le indica Assistenti.
- Non funziona? **Prova la connessione** dice che cosa sta ancora aspettando.
- **Disconnetti** rimuove l'assistente da ogni spazio di questo database. Ciò che ha già letto non viene ritirato.

**Vedi anche:** [Approvazioni](help:user.advanced.assistants-approve)

<!-- anchor: user.advanced.assistants-approve -->
### Approvazioni e conferme per gli assistenti

**Destinatari:** Proprietario · Operatore

Gli assistenti sono approvati a livelli, così una persona non può attivarne uno da sola.

**Passaggi**

1. Il proprietario dello spazio (o chi gestisce le integrazioni) apre [Configurazione degli assistenti](app:/settings/assistant-setup) e la percorre: **Attiva gli assistenti per questo spazio di lavoro**, **Scegli cosa possono fare gli assistenti**.
2. Ogni membro chiede una volta: **Chiedi l'approvazione**. Un amministratore del database decide in [Approvazioni degli assistenti](app:/database/assistant-approvals) con **Approva** o **Rifiuta**.
3. L'operatore dell'installazione apre [Installazione: assistenti](app:/installation/assistants) e tocca **Attiva per tutti gli spazi**. La pagina elenca anche **Amministratori della base** e **Client degli assistenti**, ciascuno **Approvato**, **Bloccato** oppure **In attesa di approvazione**.
4. Quando un assistente invia una richiesta ad alto impatto, Le viene chiesto: **Conferma una richiesta dell'assistente**. **Conferma** gli permette di inviare quella richiesta esatta una sola volta; **Rifiuta** non fa nulla.

**Da sapere**

- Le approvazioni e le modifiche dell'installazione richiedono il Suo secondo fattore.
- L'approvazione scade; la schermata indica i giorni rimanenti e Lei chiede di nuovo.
- Una richiesta confermata segue comunque le regole di convalida dello spazio.
- Senza un altro amministratore del database, l'operatore approva l'accesso, con un motivo, per un massimo di 30 giorni.

**Vedi anche:** [Che cosa possono fare gli assistenti](help:user.advanced.assistants-policy)

<!-- anchor: user.advanced.assistants-policy -->
### Che cosa possono fare gli assistenti in uno spazio

**Destinatari:** Proprietario · Amministratore

Decide quali servizi uno spazio offre agli assistenti.

**Passaggi**

1. Apra [Accesso degli assistenti](app:/settings/assistants).
2. Attivi **Offri i servizi per assistenti**.
3. Sotto **Dati su cui un assistente può agire**, scelga **Solo i propri dati** o **Tutto lo spazio**.
4. Spunti le operazioni, per gruppi: **Prenotazioni e conto personali**, **Richieste finanziarie**, **Richieste di iscrizione**, **Convalide**.
5. Tocchi **Salva**.

**Da sapere**

- Le operazioni si leggono come «Vedere i posti liberi», «Prenotare un posto per te», «Registrare il tuo arrivo» o «Annullare le tue prenotazioni non ancora iniziate».
- Gli assistenti ricevono risposte ridotte al minimo. **Dettagli facoltativi** permette di consentirne di più; ogni persona sceglie comunque per sé.
- Gli assistenti già collegati ricevono nuovi servizi solo quando ogni persona approva di nuovo.
- Attivi prima la funzione **Interfaccia MCP** in [Funzionalità](app:/features). È disattivata per impostazione predefinita.
- È riservato a chi possiede il permesso sulle integrazioni; i proprietari lo hanno sempre.

**Vedi anche:** [Un interruttore di funzione](help:user.features.switch)

<!-- anchor: user.advanced.recorder -->
### Il registratore di attività e le visite guidate

**Destinatari:** Tutti

Vuole mostrare a qualcuno come si svolge un'attività, o che La si guidi. Registri l'attività una volta, la trasformi in una guida e la segua passo dopo passo sull'app reale.

<p><img src="images/user-advanced-wizard.it.jpg" width="280"></p>

**Passaggi**

1. Apra la [Procedura guidata delle attività](app:/task-wizard): nel menu su uno schermo largo, oppure sotto **Avanzate** in [Io](app:/me).
2. **Guide** contiene le Sue guide e quelle fornite con l'app, come **Prenota un posto**.
3. **Registrazioni** elenca le attività che ha registrato e **Registra un'attività** ne avvia una nuova.
4. **Strumenti** apre un file di attività senza account.

**Da sapere**

- Tutto resta sul Suo dispositivo finché non lo esporta.
- Il registratore di attività è una funzione (**Registratore di attività**). Quando è disattivata, l'assistente di attività non compare nei menu.
- Deve aver effettuato l'accesso per registrare o seguire una guida.

**Vedi anche:** [Registrare un'attività](help:user.advanced.recorder-record) · [Seguire una guida](help:user.advanced.guide-play)

<!-- anchor: user.advanced.recorder-record -->
### Registrare un'attività

**Destinatari:** Tutti

Vuole catturare ciò che fa, perché diventi un documento o una guida.

<p><img src="images/user-advanced-record.it.jpg" width="280"></p>

**Passaggi**

1. Nel [Registratore di attività](app:/task-recorder), legga **Prima di registrare**.
2. Tocchi **Avvia registrazione**.
3. Svolga l'attività come al solito, su qualsiasi schermata dello spazio o di [Io](app:/me).
4. Usi la barra che riporta **Registrazione in corso** per **Pausa**, **Riprendi**, **Aggiungi una nota** o **Ferma**.

**Da sapere**

- Una registrazione dura fino a 500 passaggi o 30 minuti e viene eliminata dal dispositivo dopo 30 giorni. Un file esportato resta dove l'ha salvato.
- Ogni passaggio indica la schermata, l'azione e ciò che l'app ha risposto, come **Prenotato** o **Rifiutato**.
- Accesso, pagamento, messaggi e altre schermate protette lasciano soltanto un segnaposto.
- Se passa a un altro account o a un altro spazio, la registrazione termina.

**Vedi anche:** [Riservatezza delle registrazioni](help:user.advanced.recorder-privacy)

<!-- anchor: user.advanced.recorder-review -->
### Rivedere, modificare ed esportare una registrazione

**Destinatari:** Tutti

Vuole controllare ciò che è stato catturato prima di condividerlo.

**Passaggi**

1. Nella [Procedura guidata delle attività](app:/task-wizard), tocchi una registrazione sotto **Registrazioni**.
2. Legga i passaggi. Tocchi **Escludi dall'esportazione** su ogni passaggio che non vuole; **Reinserisci** lo riporta.
3. Guardi **Cosa conterrà il file**.
4. Scelga **Esporta un file**, **Esporta un pacchetto dell'attività** o **Esporta come documento Word**.

**Da sapere**

- Escludere un passaggio cambia solo l'esportazione. La registrazione sul dispositivo resta invariata.
- Per leggere il file di un'altra persona, usi **Apri un file di attività** nel [Banco di lavoro delle attività](app:/task-workbench). Nulla viene caricato e non serve alcun account.
- Un file danneggiato o creato da una versione più recente viene rifiutato con un messaggio semplice.
- **Elimina da questo dispositivo** rimuove la registrazione; i file esportati non vengono toccati.

**Vedi anche:** [Creare una guida](help:user.advanced.guide-make)

<!-- anchor: user.advanced.guide-make -->
### Creare una guida da una registrazione

**Destinatari:** Tutti

Vuole che altri seguano un'attività che ha registrato.

**Passaggi**

1. Nella [Procedura guidata delle attività](app:/task-wizard), tocchi **Crea una guida** accanto a una registrazione. Oppure scelga **Aggiungi una guida** → **Da una delle mie registrazioni** o **Da un file o pacchetto di attività**.
2. Controlli la bozza. Ogni passaggio è scritto come lo vedrà il lettore.
3. Le dia un nome sotto **Nome della guida**.
4. Tocchi **Aggiungi alle mie guide**.

**Da sapere**

- La guida resta sul Suo dispositivo sotto **Guide**. Una guida si può modificare o eliminare: **Elimina questa guida** non tocca la sua registrazione.
- Un passaggio che prenota attende la risposta reale. Nulla viene fatto al posto del lettore.
- **Salva la guida** la scrive in un file che può consegnare.

**Vedi anche:** [Modificare una guida](help:user.advanced.guide-edit)

<!-- anchor: user.advanced.guide-play -->
### Seguire una guida

**Destinatari:** Tutti

Vuole essere accompagnato in un'attività sulle schermate reali.

**Passaggi**

1. Nella [Procedura guidata delle attività](app:/task-wizard), tocchi **Avvia la guida** accanto a una delle guide.
2. Un pannello mostra Passo 1 di … e che cosa fare, ad esempio «Tocca “Prenota”.» oppure «Compila “…”, poi esci dal campo.»
3. Tocchi **Apri ed evidenzia** per andare alla schermata giusta e vedere il comando segnalato.
4. Esegua il passaggio da sé. La guida se ne accorge e va avanti. Per un passaggio di sola lettura, tocchi **Fatto**.

**Da sapere**

- Usi **Indietro** e **Salta**, e apra **Tutti i passi** per vedere ciascuno come **Da fare**, **In attesa**, **Fatto**, **Preso atto** o **Saltato**.
- Un passaggio che prenota attende la risposta: **In attesa del risultato…**. Se viene rifiutato, la guida dice che cosa provare; se non è arrivata alcuna risposta, Le chiede di verificare prima di riprovare.
- **Interrompi la guida** la termina. Nulla viene annullato.
- La guida si mette in pausa quando cambia l'account o lo spazio, oppure quando il registratore di attività viene disattivato.

**Vedi anche:** [Il menu circolare](help:user.advanced.guide-circle)

<!-- anchor: user.advanced.guide-circle -->
### Il menu circolare

**Destinatari:** Tutti

Le serve tutto lo schermo per lavorare, ma vuole la guida a portata di mano. La riduca.

**Passaggi**

1. Nel pannello della guida, tocchi **Riduci la guida**. Si restringe in un piccolo cerchio.
2. Tocchi il cerchio per un menu: Mostra la guida (passo … di …), **Apri ed evidenzia**, un pulsante verso la pagina del passaggio, **Fatto**, **Salta**, **Indietro**, **Riprendi** e **Interrompi la guida**.
3. Scelga **Mostra la guida** per riaprire il pannello.

**Da sapere**

- Il menu offre solo ciò che ha senso adesso: **Riprendi** solo in pausa, **Fatto** solo per un passaggio di sola lettura.
- **Chiudi** nel pannello lo nasconde; la guida resta dov'era.
- Apri ed evidenzia porta alla pagina del passaggio e indica il comando; il pulsante della pagina porta soltanto alla pagina.

**Vedi anche:** [Seguire una guida](help:user.advanced.guide-play)

<!-- anchor: user.advanced.guide-edit -->
### Modificare o riparare una guida

**Destinatari:** Tutti

Una guida si legge male, oppure un passaggio rimanda alla pagina sbagliata. La corregga nella bozza.

**Passaggi**

1. Nella [Procedura guidata delle attività](app:/task-wizard), tocchi **Modifica** accanto alla Sua guida.
2. Su un passaggio, tocchi **Scrivi il testo** e digiti il Suo testo.
3. Sotto **Destinazione del passaggio**, scelga la pagina a cui il passaggio si riferisce. Tocchi **Apri ed evidenzia** per verificare.
4. Attivi **Il lettore può saltarlo** per un passaggio facoltativo.
5. Tocchi **Salva le modifiche**.

**Da sapere**

- Un passaggio contrassegnato **Un'istruzione ancora da scrivere** richiede le Sue parole. **Un passaggio che il registratore non sa descrivere** ed **Esegua questo passaggio da sé** li esegue il lettore.
- I passaggi su schermate protette, come il pagamento, chiedono al lettore di eseguirli da solo.
- Non può far attendere a una guida un esito che la sua azione non ha; quella parte è fissa.
- Una guida che nomina passaggi sconosciuti a questa versione si può leggere, non seguire.

**Vedi anche:** [Creare una guida](help:user.advanced.guide-make)

<!-- anchor: user.advanced.recorder-privacy -->
### Che cosa conserva una registrazione

**Destinatari:** Tutti

Vuole sapere esattamente che cosa non lascia traccia.

**Passaggi**

1. Apra il [Registratore di attività](app:/task-recorder).
2. Legga **Prima di registrare**.
3. Lasci disattivato **Cattura i valori (per le segnalazioni)**, a meno che uno sviluppatore non lo abbia chiesto.

**Da sapere**

- Normalmente una registrazione non conserva mai ciò che digita, nomi, importi, messaggi, codici o password.
- Con **Cattura i valori** attivo, conserva anche ciò che digita e sceglie, così uno sviluppatore può riprodurre un problema. Password, dati di pagamento, indirizzi e-mail e numeri di telefono non vengono comunque mai conservati. L'esportazione chiede **Questa registrazione contiene valori**.
- Nulla viene caricato: decide Lei che cosa esportare.
- Condivida un file solo con chi può vedere ciò che ha inserito.

**Vedi anche:** [Registrare un'attività](help:user.advanced.recorder-record)

<!-- anchor: user.advanced.demo -->
### Lo spazio dimostrativo

**Destinatari:** Tutti

Vuole dare un'occhiata prima di impegnarsi. La demo è uno spazio inventato, aperto a chiunque, senza account.

**Passaggi**

1. Nella schermata di accesso, tocchi **Esplora lo spazio dimostrativo**.
2. Legga la breve nota, poi tocchi **Inizia**.
3. Usi **Vedi come** per vedere lo stesso spazio come **La proprietaria**, **Un'amministratrice** o **Un membro**.
4. Tocchi **Reimposta la demo** per riportarla all'inizio, oppure **Esci dalla demo**.

**Da sapere**

- Tutto è inventato: persone, prenotazioni e conti. Nulla raggiunge uno spazio reale e nulla lascia il Suo dispositivo.
- Un banner riporta **Demo** su ogni schermata.
- Chiudendo l'app la sessione viene dimenticata.
- L'offerta compare solo quando la funzione **Lo spazio dimostrativo** è attiva.

**Vedi anche:** [Modalità ripresa](help:user.advanced.filming)

<!-- anchor: user.advanced.filming -->
### Modalità ripresa

**Destinatari:** Proprietario

Deve mostrare il Suo spazio reale — in un video, in un'immagine o in un intervento — senza mostrarne i membri.

**Passaggi**

1. Apra [Funzionalità](app:/features) e cerchi **Modalità ripresa**.
2. La attivi. Un banner riporta **Modalità ripresa — persone inventate** su ogni schermata.
3. Giri. Quando ha finito, la disattivi di nuovo.

**Da sapere**

- Ogni nome, e-mail, numero di telefono, indirizzo e fotografia diventa una persona inventata, la stessa ovunque. La piantina, le prenotazioni e le cifre restano reali.
- Finché è attiva, i moduli di identità rifiutano di salvare, così i dati inventati non possono sovrascrivere quelli reali.
- Non può nascondere ciò che qualcuno ha digitato, come un messaggio o l'etichetta di un posto. Legga la schermata prima di girare.
- Per un'immagine che non deve riguardare questo spazio, usi [la demo](help:user.advanced.demo).

**Vedi anche:** [Un interruttore di funzione](help:user.features.switch)

<!-- anchor: user.advanced.platforms -->
### DesKilo sui Suoi dispositivi

**Destinatari:** Tutti

Vuole usare DesKilo dove lavora. Lo stesso account e gli stessi dati La seguono.

**Passaggi**

1. **Android:** si unisca al test chiuso su Google Play.
2. iPhone e iPad: si unisca alla beta tramite TestFlight.
3. **Computer:** un'immagine disco per macOS o un programma di installazione per Windows dalla pagina delle versioni; oppure apra semplicemente l'app web.
4. **Browser:** apra l'indirizzo che il Suo spazio pubblica. Non c'è nulla da installare.

**Da sapere**

- Una scrivania prenotata su un telefono compare un attimo dopo in una scheda del browser.
- L'immagine disco per macOS dalla pagina delle versioni è firmata e notarizzata da Apple; la apra normalmente.
- Il programma di installazione per Windows non è firmato: Windows SmartScreen segnala un editore sconosciuto; scelga Ulteriori informazioni, poi Esegui comunque.
- La lettura del tag di una sedia funziona nei browser Chromium su Android (servono HTTPS e un tocco); le app Android e iPhone leggono i tag direttamente.
- Una build senza servizi Google e senza push dal cloud è preparata per F-Droid; se si può già installare da F-Droid lo indica la [pagina di stato F-Droid](https://github.com/fdittgen-png/deskilo/blob/master/docs/guides/fdroid.md#status). In essa le notifiche sono locali e la posta in arrivo fa fede.
- Gli aggiornamenti arrivano dal canale da cui ha installato: Google Play, TestFlight, la pagina delle versioni oppure ricaricando l'app web.

**Vedi anche:** [Il Suo badge](help:user.profile.settings.badge)

<!-- anchor: user.advanced.support -->
### Dettagli per l'assistenza

**Destinatari:** Tutti

Contatta l'assistenza e vuole inviare ciò che li aiuta, senza esporre nulla di privato.

<p><img src="images/user-advanced-support.it.jpg" width="280"></p>

**Passaggi**

1. Apra [Aiuto](app:/help) e tocchi l'icona dell'assistenza (**Dettagli per l’assistenza**).
2. Scelga **Ultima ora** o **Ultime 24 ore**.
3. Tocchi **Prepara anteprima** e legga ciò che contiene: Anteprima: … byte.
4. Tocchi **Salva**, poi invii il file.

**Da sapere**

- Sono inclusi solo conteggi di eventi limitati e verifiche note. Identità, indirizzi di server, credenziali, dati aziendali e log grezzi sono esclusi.
- Un file condiviso non si può revocare.
- Se il contesto è cambiato, la schermata Le chiede di preparare una nuova anteprima.
- Un operatore può eseguire `doctor --support-json` per il lato server.

**Vedi anche:** [Quando qualcosa non funziona](help:user.advanced.troubleshooting)

<!-- anchor: user.advanced.troubleshooting -->
### Quando qualcosa non funziona

**Destinatari:** Tutti

Qualcosa sembra sbagliato. Provi questi passaggi, in ordine.

**Passaggi**

1. Cerchi un messaggio sulla schermata; la maggior parte dice che cosa fare. «Qualcosa è andato storto. Riprova.» merita un nuovo tentativo.
2. Verifichi di trovarsi sul lato che crede: **Spazio di prova** o **Apri spazio** in [Io](app:/me).
3. Controlli [Funzionalità](app:/features): una funzione assente dal menu è di solito una funzione disattivata. Solo un proprietario può cambiarla.
4. Controlli il server sotto [Il Suo server](help:user.backend.server): **Questo dispositivo usa** lo indica.
5. Prepari i [Dettagli per l'assistenza](help:user.advanced.support) e li invii.

**Da sapere**

- Ciò che vede dipende dal Suo ruolo: una schermata mancante può essere un permesso. Chieda al Suo proprietario.
- Gli amministratori possono attivare la **Modalità sviluppatore** sotto **Avanzate** in [Impostazioni](app:/settings). Aggiunge una schermata [Sviluppatore](app:/developer) dove **Esporta registro** e **Svuota registro** aiutano l'assistenza. Vale per ogni membro dello spazio.
- Può anche segnalare un bug dalla sezione Informazioni dell'app: **Segnala un bug / suggerisci una funzione**.
- Una guida bloccata su **In attesa del risultato…** significa che non è arrivata alcuna risposta: verifichi il risultato prima di riprovare.

**Vedi anche:** [Dettagli per l'assistenza](help:user.advanced.support)

<!-- anchor: user.advanced.glossary -->
### Le parole dell'app

**Destinatari:** Tutti

Le parole che incontra più spesso e che cosa significano qui.

| Parola | Che cosa significa |
|---|---|
| **Spazio** (detto anche spazio di coworking) | Un luogo gestito da una comunità: la sua piantina, i membri, le regole e il denaro. Può appartenere a più spazi. |
| **Io** | Il Suo account personale: profilo, messaggi, spazi e impostazioni, in tutti i Suoi spazi. |
| **Piantina** | La pianta da cui prenota, oppure un piano di abbonamento — veda **Membri e piani**. |
| **Piano** | Un piano o una zona della piantina. Un piano può essere prenotato per intero quando la funzione è attiva. |
| **Scrivania** | Un posto prenotabile. Uffici e sale raggruppano scrivanie. |
| **Mezza giornata** | L'unità in cui si contano prenotazioni e abbonamenti. |
| **Convalida** | Una regola che dice che un'azione richiede una o più conferme prima di contare. |
| **Eventi** | Il flusso di ciò che è accaduto, con in cima le decisioni che La attendono. |
| **Chiosco** | Un tablet condiviso all'ingresso dove le persone effettuano il check-in con un badge. |
| **Funzionalità** | Una funzione che il proprietario attiva o disattiva per l'intero spazio. |
| **Ruolo** | Ciò che una persona può fare in uno spazio. I permessi si impostano per ruolo. |
| **Ambiente** | Il lato di sviluppo (prova) o il lato di produzione (reale) di uno spazio. |
| **Gemello** | L'altro lato di una coppia. |
| **Distribuzione** | Spostare la configurazione da un lato di una coppia all'altro. |
| **Assistente** | Uno strumento di intelligenza artificiale collegato al Suo account, che agisce solo come Lei consente. |
| **Operatore** | La persona che gestisce l'installazione con cui l'app comunica. |

**Da sapere**

- I proprietari possono cambiare le parole usate da uno spazio sotto **Terminologia**; l'app mostra allora quelle proprie dello spazio.

**Vedi anche:** [Terminologia](help:user.workspace.settings.wording)

<!-- anchor: user.advanced.accessibility -->
### Accessibilità e tastiera

**Destinatari:** Tutti

Vuole che l'app si adatti al Suo modo di lavorare.

**Passaggi**

1. Scelga un aspetto sotto [Impostazioni](app:/settings): **Tema**, **Lingua**, **Numeri e date**.
2. Per schermate più calme, attivi l'impostazione di movimento ridotto del Suo dispositivo.
3. Su un computer, prema Esc in una procedura guidata per tornare indietro.

**Da sapere**

- L'impostazione di movimento ridotto del dispositivo prevale sempre sulla funzione **Animazioni dell'interfaccia**; anche un proprietario può disattivare quella funzione.
- Uscire da una procedura guidata con modifiche non salvate chiede prima conferma: **Continua a modificare** o **Scarta**.
- I comandi hanno etichette di testo, così uno screen reader li annuncia.
- Sul web e su un computer, una finestra ampia mostra il menu accanto al contenuto.

**Vedi anche:** [Tema](help:user.profile.settings.theme) · [Lingua dell'app](help:user.profile.settings.language)

<!-- anchor: user.advanced.help -->
### Dove trovare altro aiuto

**Destinatari:** Tutti

È bloccato su un campo o su una schermata.

**Passaggi**

1. Tocchi il **?** accanto a un campo: la guida si apre su quel campo.
2. Apra [Aiuto](app:/help) per l'intera guida; **Indice** porta a un capitolo.
3. I suggerimenti su una schermata si possono chiudere con **Nascondi suggerimento**; **Suggerimento successivo** e **Suggerimento precedente** li sfogliano, **Scopri di più** apre la guida.
4. Per rivedere i suggerimenti nascosti, usi **Mostra di nuovo i suggerimenti di aiuto** nelle Sue impostazioni.

**Da sapere**

- La guida funziona offline, nella Sua lingua.
- Il Suo amministratore può rispondere alle domande sul Suo spazio; i Dettagli per l'assistenza servono quando si tratta dell'app.

**Vedi anche:** [Ripristinare i suggerimenti](help:user.profile.settings.restore-hints) · [Dettagli per l'assistenza](help:user.advanced.support)
