<!-- anchor: setup.reports.overview -->
## Documenti e report

**Destinatari:** Proprietario · Comproprietario · Amministratore fatturazione

Tutto ciò che DesKilo stampa o esporta nasce da un unico motore e da un unico luogo in cui progettarlo. Questo capitolo Le dice quali documenti esistono, in che ordine prepararli, che cosa può consegnare al commercialista e dove un assistente di intelligenza artificiale può aiutarLa e dove non deve. I clic sono nella guida utente; qui trova le ragioni e l'ordine.

L'esempio che seguiamo è lo spazio dimostrativo *Atelier du Marché*.

<!-- anchor: setup.reports.documents -->
### I documenti prodotti dall'app

**Destinatari:** Proprietario · Amministratore fatturazione

Vuole sapere che cosa esiste prima di progettare qualcosa, e chi riceve ciascun documento.

<p><img src="images/setup-reports-hub.it.jpg" width="280"></p>

Ogni documento è un *tipo*. Ogni tipo ha il proprio progetto, perciò modificare la fattura non cambia mai l'estratto conto.

| Documento | Chi lo riceve | Dove lo trova |
|---|---|---|
| Fattura e nota di credito (un solo progetto condiviso) | Il membro, o il cliente di un mese fatturato | [Fatturazione](help:user.invoicing.hub) |
| Proforma | Un membro che ha bisogno di un preventivo o di una richiesta di anticipo | Stessa schermata |
| Estratto conto | Il membro (il suo conto in un periodo) | [L'estratto conto](help:user.money.statement) |
| Accordo | Il membro (le condizioni negoziate) | [Negoziazione dei prezzi](help:user.money.negotiation) |
| Pagamenti, utilizzo | Il membro, l'amministratore di fatturazione | [Pagamenti](help:user.money.payments) · [Utilizzo](help:user.money.usage) |
| Lettere di sollecito, dal livello 1 al 9 | Il membro con una fattura scaduta | [Regole di sollecito](help:user.money.reminders.rules) |
| Report dello spazio e stato dello spazio | Lei, il consiglio, un revisore | **Report** |
| Dichiarazione IVA | Lei, poi la piattaforma fiscale | [La dichiarazione IVA periodica](help:user.money.vat.declaration) |
| Badge, codici QR degli spazi | I membri alla porta, le Sue pareti | [Codici QR degli spazi](help:user.workspace.export.space-qr) · [Badge](help:user.badges.nfc) |

**Da sapere**

- La schermata **Report** li raggruppa in **Report finanziari**, **Documenti dello spazio**, **Analisi aziendale** e **Modelli**, a seconda dei Suoi permessi.
- Alcuni report (piano dei conti, badge, schede QR) hanno un solo layout fornito. Gli altri possono essere ridisegnati.
- I documenti ricavati da uno spazio di prova portano una filigrana che lo dichiara. Vedi [A che cosa serve uno spazio di prova](help:user.advanced.test-space).

**Vedi anche:** [Report](help:user.money.reports) · [Il modello PDF della fattura](help:user.money.reports.invoice-template)

<!-- anchor: setup.reports.designer -->
### L'editor, in termini da proprietario

**Destinatari:** Proprietario · Amministratore fatturazione

Vuole una lettera che somigli alla Sua senza imparare un linguaggio di marcatura.

<p><img src="images/setup-reports-professional.it.jpg" width="280"></p>

Un documento è una pagina composta da **bande**. L'*intestazione* porta la Sua carta intestata e il destinatario. Il *corpo* porta le righe. La striscia di *continuazione* parte dalla seconda pagina, e il *piè di pagina* si ripete su ogni pagina con i Suoi termini di pagamento e le menzioni legali. Le modifica in **Progetto** e le verifica in **Anteprima**; **Markup** mostra le stesse bande come testo per il giorno in cui servirà.

| Elemento | Che cosa Le dà | Lo scelga quando |
|---|---|---|
| Modelli predefiniti (**Professionale**, **Classico**, **Semplice**, **Dettagliato**, **Lettera formale**) | Un progetto finito da cui partire. I modelli differiscono per fatture, proforma, estratti conto, accordi e solleciti; i documenti strutturali hanno un solo layout fornito | Sempre: parta da **Professionale** e cambi poco |
| Un progetto per lingua | Un membro legge il documento nella propria lingua | I Suoi membri non leggono tutti la stessa lingua |
| Carta intestata e busta con finestra | Mittente, destinatario e corpo collocati dove li aspetta una busta con finestra | Spedisce le fatture su carta |
| Layout posizionato (XML) | Ogni elemento collocato in millimetri, per un modulo nazionale | Un documento deve corrispondere a un modulo fisso |
| Libreria di immagini | Un logo, un timbro o una firma riutilizzati in più progetti | Ha un logo |
| Scambio di modelli | Un progetto scritto in un file e riletto | Una persona o uno strumento esterno all'app lo modifica |

Due fatti Le evitano sorprese. Lo standard della lettera stampa il destinatario nella finestra a destra per uno spazio francese e a sinistra per uno tedesco, salvo Sua diversa impostazione. E un progetto che non riesce a essere generato non blocca mai un documento: subentra il layout incorporato.

> **Attenzione** Le parole di un progetto non sono una consulenza legale. L'aspetto e la traduzione da soli non stabiliscono la conformità legale né soddisfano un obbligo di fatturazione elettronica. Ciò che una fattura deve dire si decide in [La Sua identità legale](help:user.money.legal.identity) e lo conferma il Suo commercialista.

**Vedi anche:** [L'editor dei report](help:user.money.reports.editor) · [Modelli pronti](help:user.money.reports.presets) · [Un progetto per lingua](help:user.money.reports.languages)

<!-- anchor: setup.reports.sequence -->
### La sequenza da seguire

**Destinatari:** Proprietario · Amministratore fatturazione

Sta per progettare i documenti e vuole farlo una volta sola, nell'ordine giusto.

<p><img src="images/setup-reports-presets.it.jpg" width="280"></p>

**Passaggi**

1. Fissi prima la Sua identità legale: tipo di organizzazione, indirizzo, registrazione, regime IVA e menzioni particolari. Un progetto stampa solo ciò che ha inserito lì. Vedi [La Sua identità legale](help:user.money.legal.identity).
2. Apra l'[Editor dei report](app:/report-editor), scelga il documento e parta da **Professionale** sotto **Modelli**.
3. Aggiunga una versione per ogni lingua che i Suoi membri leggono. Scelga **EN**, **FR**, **DE**, **ES** o **IT** sotto il documento. Vedi [Un progetto per lingua](help:user.money.reports.languages).
4. Controlli ciascuna con **Anteprima rapida**. Usa la Sua fattura più recente, oppure dati di esempio se non ce n'è.
5. Provi in uno spazio di prova: vi entri, emetta una fattura di prova, la stampi e la invii al commercialista. Vedi [A che cosa serve uno spazio di prova](help:user.advanced.test-space).
6. Congeli il progetto prima della prima fattura. Annoti ciò che ha deciso e lo modifichi solo quando cambia una regola.

**Da sapere**

- La sostituzione di un layout può essere annullata con **Annulla** finché non lascia l'editor.
- Una fattura emessa è un documento congelato. Cambiare il progetto in seguito cambia i nuovi documenti, mai quelli già emessi.
- Con lo stesso testo in due lingue, chieda a qualcuno che legge la seconda lingua di leggere l'anteprima.

> **Attenzione** Il numero di fattura e le menzioni legali stampate su una fattura diventano definitivi con la prima fattura emessa. Le fissi prima, non dopo.

**Risultato:** ogni documento che invierà somiglia al Suo, in ogni lingua, ed è stato letto una volta da qualcuno diverso da Lei.

**Vedi anche:** [La Sua identità legale](help:user.money.legal.identity) · [Il modello PDF della fattura](help:user.money.reports.invoice-template)

<!-- anchor: setup.reports.accountant -->
### Che cosa consegna al commercialista

**Destinatari:** Proprietario · Amministratore fatturazione

Vuole che il commercialista abbia ciò che gli serve e sappia che cosa l'app non afferma.

<p><img src="images/setup-reports-export.it.jpg" width="280"></p>

Parta dal [Registro fatture](app:/invoice-register), che elenca ogni fattura con il suo stato, e tocchi **Esportazione contabile**. Ogni formato dichiara nella scheda che cosa afferma.

| File | Che cosa afferma | Che cosa non afferma |
|---|---|---|
| FEC | Il formato francese richiesto da una verifica, ricostruito da fatture e pagamenti | Una contabilità completa. La completa il Suo commercialista |
| DATEV | Un file di scambio per i software dei commercialisti tedeschi, letto e registrato da una persona | Una presentazione, o una consegna per una verifica fiscale |
| SAF-T | La struttura internazionale, volutamente parziale: fatture e pagamenti, senza libro mastro | Un file contabile completo. Lo dice nella sua intestazione |
| SAF-T PT, Sage 50 | Un formato normativo portoghese (non certificato) e un formato di scambio britannico/irlandese, a seconda del Suo paese | Una presentazione o una certificazione |
| CSV contabile, Traccia di controllo, Archivio annuale (zip) | Un ausilio di lettura per il Suo commercialista | Una presentazione |

L'elenco dei formati dipende dal Suo paese. FEC e DATEV chiedono i Suoi numeri di conto, e il FEC anche il Suo numero di registrazione: li tenga pronti. Le cifre IVA del periodo si trovano in [La dichiarazione IVA periodica](help:user.money.vat.declaration).

*Che cosa l'app non fa*

- Conserva fatture, pagamenti e un conto corrente per ogni membro. Non tiene una contabilità in partita doppia su un piano dei conti, perciò non può sostituire un software di contabilità.
- Alcuni obblighi restano a carico Suo e del Suo commercialista: la contabilità completa, il software certificato dove il Suo paese lo richiede e l'accettazione da parte dell'autorità competente.
- Un file è bloccato finché i problemi nell'origine non sono risolti.

**Da sapere**

- Esportare è una lettura. Può ripeterla per qualsiasi periodo.
- Prepari una breve nota per il commercialista prima della prima fattura: il Suo regime IVA, quando l'IVA diventa esigibile, la numerazione scelta e le esportazioni che vorrà. Vedi [Aiuto da un assistente IA](help:setup.reports.ai).

**Vedi anche:** [Esportazioni contabili](help:user.invoicing.accounting-export) · [Il registro fatture](help:user.invoicing.register) · [Conto IVA](help:user.money.vat.account)

<!-- anchor: setup.reports.analytics -->
### L'analisi aziendale in breve

**Destinatari:** Proprietario · Amministratore fatturazione

Vuole vedere come va lo spazio una volta avviato, senza un foglio di calcolo.

<p><img src="images/setup-reports-documents.it.jpg" width="280"></p>

**Analisi aziendale** mostra le cifre per area: fatturato e incassato, occupazione e capacità. Sceglie un periodo (mese, trimestre o anno), lo confronta con un altro, salva una vista e la esporta in PDF. Vede solo le analisi che il Suo ruolo può leggere.

L'incassato è l'insieme dei pagamenti abbinati alle fatture. Non è un utile, perché nella cifra non ci sono i costi, e il periodo in corso è parziale.

Per un documento sull'intero spazio, la scheda **Documenti dello spazio** contiene il **Report dello spazio**, i **Codici QR degli spazi (PDF)**, **Esporta i dati (Excel)** ed **Esporta configurazione (PDF)**. Usi gli ultimi due come copia di ripristino prima di un cambiamento importante.

**Vedi anche:** [Analisi aziendale](help:user.invoicing.bi) · [Esportazioni](help:user.workspace.export.workspace-report)

<!-- anchor: setup.reports.ai -->
### Aiuto da un assistente IA

**Destinatari:** Proprietario · Comproprietario

Uno strumento di chat con IA può farLe risparmiare ore sulle parole che circondano la Sua configurazione. Non può essere lui a decidere che cosa è giusto sul piano legale o fiscale. Questa sezione riguarda gli strumenti che usa fuori da DesKilo; il collegamento dell'assistente dentro l'app è descritto alla fine.

*A che cosa serve uno strumento esterno*

- Redigere il messaggio di invito che invia ai primi membri. Vedi [Il messaggio di invito](help:user.workspace.settings.invitation-message). I segnaposto come il nome o il link di invito restano così come sono.
- Formulare le menzioni particolari da sottoporre al commercialista, come bozza da verificare, mai come testo definitivo.
- Tradurre il testo di un progetto in un'altra lingua, così che debba solo rileggerlo.
- Spiegare a un membro, con parole semplici, un report o un estratto conto.
- Preparare la nota delle Sue scelte per il commercialista: paese, tipo di organizzazione, regime IVA, numerazione, esportazioni.
- Abbozzare, a partire da fotografie, l'immagine che sta dietro la Sua planimetria, in uno strumento per immagini.

*Che cosa non deve decidere*

- Le menzioni legali di una fattura, il trattamento IVA di un'attività, il motivo per cui non viene applicata l'IVA e le aliquote IVA.
- Qualsiasi cosa diventi definitiva: un formato del numero di fattura, un regime IVA, la valuta, una fattura emessa.
- Se qualcosa è conforme. Una risposta sicura di sé non è una risposta verificata, e chi verifica è il Suo commercialista.

*Il procedimento sicuro*

1. Chieda allo strumento una bozza. Gli fornisca uno scenario, non i nomi dei Suoi membri né dati personali.
2. Incolli la bozza nel campo, nell'**Editor dei report** o nelle impostazioni.
3. La guardi in **Anteprima** con dati di esempio.
4. Invii al commercialista il testo che ha peso legale e attenda la risposta.
5. Provi l'intero procedimento in uno spazio di prova prima di quello reale.

> **Attenzione** Non incolli in uno strumento esterno un token, una password, un numero bancario né dati personali di un membro.

*Il collegamento dell'assistente di DesKilo*

L'app consente a un assistente come Claude o ChatGPT di agire per un membro tramite un protocollo chiamato MCP. È spento per impostazione predefinita ed è una funzione che attiva Lei (**Interfaccia MCP**, vedi [Un interruttore di funzione](help:user.features.switch)). È costruito a strati, così che nessuna persona da sola possa aprire tutto.

<p><img src="images/setup-reports-assistants.it.jpg" width="280"></p>

| Livello | Chi | Che cosa fa |
|---|---|---|
| L'installazione | L'operatore | Attiva gli assistenti per l'installazione. |
| Lo spazio | Lei, il proprietario | Attiva la funzione, poi sceglie in [Che cosa possono fare gli assistenti](help:user.advanced.assistants-policy) quali servizi offrire e se un assistente vede solo i propri dati o quelli dell'intero spazio. |
| Il database | Un amministratore del database | Approva la richiesta di ciascuna persona. |
| Il membro | Ogni membro | Chiede una volta l'approvazione e sceglie questo spazio. |
| Una richiesta con effetti | Il membro, sul proprio dispositivo | Conferma la richiesta esatta, che segue comunque le Sue regole di convalida. |

L'assistente di un membro lavora sui dati di quel membro: trovare e descrivere i posti liberi, preferiti e valutazioni, prenotare, modificare o annullare la propria prenotazione, chiedere di eliminare una prenotazione iniziata, fare check-in e check-out, leggere il proprio estratto conto e le proprie fatture, elencare e risolvere le convalide richieste. Alcune richieste (emissione di fattura, annullamento di fattura, rimborso, cambio di stato di un membro, quota di abbonamento) sono riservate al personale: richiedono i diritti del personale, la conferma della persona nell'app e poi le Sue regole di convalida. Non esiste alcuna operazione che configuri uno spazio: non può attivare una funzione, impostare una tariffa, cambiare un ruolo né costruire una planimetria. Non può configurare lo spazio al posto Suo e agisce solo entro ciò che Lei espone.

**Da sapere**

- Attivare gli assistenti non concede nulla a nessuno di per sé.
- Ogni approvazione scade; la schermata indica quanti giorni restano.
- Legga i passaggi in [Approvazioni e conferme per gli assistenti](help:user.advanced.assistants-approve).

**Vedi anche:** [Assistenti: che cosa sono](help:user.advanced.assistants) · [Collegare un assistente](help:user.advanced.assistants-connect)

<!-- anchor: setup.reports.developer -->
### Lavorare con uno sviluppatore: il file del progetto e lo strumento dei report

**Destinatari:** Proprietario · Operatore

Una persona tecnica La sta aiutando e un progetto va modificato o verificato fuori dall'app.

**Passaggi**

1. Nell'[Editor dei report](app:/report-editor) usi **Esporta questo modello** per scrivere il progetto in un unico file. Il file spiega che cosa significano i suoi campi e quali segnaposto esistono. **Importa un modello** lo rilegge; un file per un altro report, o di una versione più recente, viene rifiutato con il motivo.
2. Uno sviluppatore può verificare il progetto da terminale con lo strumento dei report, descritto nella guida dell'amministratore tecnico: `check` misura un layout rispetto al contratto della busta con finestra e termina con un codice diverso da zero quando l'inchiostro cade nella finestra; `render` produce il PDF; `sample` scrive un file di dati con ogni segnaposto; `describe` elenca il vocabolario.
3. Tornato nell'app, importi il file, lo veda con **Anteprima rapida** e **Salva**.

**Da sapere**

- Lo scambio di modelli è una funzione (**Esporta e importa i modelli di report**), tra le funzioni dei report in [Funzionalità](app:/features). La attivi per prima.
- Lo strumento richiede il codice sorgente dell'app; è per la persona che gestisce la Sua installazione, non per l'uso quotidiano.

**Vedi anche:** [L'editor dei report](help:user.money.reports.editor) · [Il modello PDF della fattura](help:user.money.reports.invoice-template)
