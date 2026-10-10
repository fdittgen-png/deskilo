<!-- anchor: setup.consistent.overview -->
## Mantenere la coerenza

Uno spazio può essere sbagliato in due modi: un'impostazione che manca e due impostazioni che si contraddicono. DesKilo ne intercetta alcune, e lo dice sullo schermo. Questo capitolo elenca che cosa intercetta e dove lo vede, dice con franchezza che cosa non intercetta e Le propone una verifica da eseguire prima di aprire le porte e una breve routine da ripetere ogni mese.

In questo capitolo:
- [Le protezioni che l'app Le offre](help:setup.consistent.guards)
- [Gli errori che le protezioni non intercettano](help:setup.consistent.gaps)
- [La verifica prima dell'apertura](help:setup.consistent.audit)
- [La routine mensile](help:setup.consistent.monthly)
- [Quando qualcosa non sembra giusto](help:setup.consistent.wrong)
- [Ciò che non si può annullare](help:setup.consistent.irreversible)

L'esempio che seguiamo è *Atelier du Marché*. La sua proprietaria, Ada, esegue la verifica una volta in uno spazio di prova e una seconda volta in quello reale.

<!-- anchor: setup.consistent.guards -->
### Le protezioni che l'app Le offre

**Destinatari:** Proprietario · Comproprietario · Amministratore · Amministratore fatturazione

Vuole sapere quali Suoi errori l'app Le segnalerà e dove lo farà, così da guardare nel posto giusto.

<p><img src="images/setup-consistent-features-attention.it.jpg" width="280"></p>

| Protezione | Che cosa intercetta | Dove la vede |
|---|---|---|
| Una funzione che ne richiede un'altra | Una funzione non può funzionare senza quella di cui ha bisogno. Attivare una funzione attiva la sua funzione madre e indica che cosa si è attivato. Spegnere una funzione madre trattiene le sue figlie e conserva la loro scelta. | **Funzionalità**: il flusso di attivazione con la sua anteprima, **Richiede** e **In attesa della funzione qui sopra** |
| Un processo trattenuto | Una funzione attiva che attende qualcosa che è spento. | **Funzionalità**, vista **Processi**: lo stato **Richiede attenzione** e il suo filtro |
| L'elenco di prontezza | Una riga per ogni area dello spazio, con il suo stato, chi agisce e dove impostarla. Aree: **Giorni di apertura, fuso orario e valuta**, **Posti prenotabili sulla planimetria**, **Piani di iscrizione e tariffe**, **Invitare i primi membri**, **Come pagano i membri**, **Ruoli e chi convalida le richieste**, **Esportazione e ripristino**, **Cosa possono fare i membri**, **Dati richiesti dalle funzioni (identità, banca, piattaforme)**, **Una prima prenotazione** e, quando serve, **L'identità legale e l'indirizzo dello spazio** (solo con **Fatture** attiva), **Server e versione del database** e **Accesso degli assistenti (facoltativo)** (quest'ultima solo con l'interfaccia MCP attiva). | **Configurazione di questo spazio**, in cima a [Spazio](app:/workspace-settings) |
| La riga che blocca una prima prenotazione | Le aree che l'elenco segna **Necessario per una prima prenotazione**: un fuso orario, una valuta, un giorno della settimana aperto, un posto, membri che possiedono **Prenotare e usare le prenotazioni** (un nuovo spazio non concede loro nulla) e, quando una regola di convalida di qualsiasi tipo chiede più convalidatori di quanti ce ne siano, quei convalidatori. Il resto è facoltativo e si può mettere da parte con **Più avanti**. | **Prima che qualcuno possa prenotare qui**, nella scheda Primi passi di [Prenota](app:/reserve) |
| La riga che blocca una prima fattura | Con **Fatture** attiva, l'identità legale e l'indirizzo dello spazio. Senza di essi non si può emettere alcuna fattura, quindi l'area non si può mettere da parte. | **Configurazione di questo spazio**: l'area **L'identità legale e l'indirizzo dello spazio**, segnata **Necessario prima di fatturare**; finché è il passo successivo, il titolo della scheda dice «Prima di fatturare: …» |
| Ciò che le Sue funzioni richiedono ancora in locale | Dati bancari, un fornitore di pagamenti online, un account di fatturazione elettronica, una sede. L'identità legale non compare qui: con **Fatture** attiva è un'area a sé (sopra). | La stessa scheda, area **Dati richiesti dalle funzioni (identità, banca, piattaforme)**, con **Configura** e **Consigliato** |
| La protezione delle fatture | Una fattura viene rifiutata finché non è completa: l'indirizzo dello spazio, la sua partita IVA, un paese tra Francia e Germania, una base giuridica per un'esenzione, nome, indirizzo e partita IVA del membro quando si applica l'inversione contabile, un'aliquota IVA in vigore, una spiegazione per ogni riga fatturata allo 0 %. Le fatture transfrontaliere, con inversione contabile, di esportazione ed esenti vengono rifiutate: le emetta fuori dall'app. | **Completi questi dati prima dell'emissione**, con l'elenco delle voci mancanti |
| La protezione dei pagamenti online | Con **Pagamenti online** spento, il server rifiuta un nuovo pagamento online. Uno già aperto si conclude comunque. | Le schermate dei pagamenti (la riga della funzione non riporta alcuna nota in proposito) |
| La protezione delle convalide | **Validazioni richieste** in numero superiore alle persone disponibili, per qualsiasi tipo di richiesta. | **Validatori idonei insufficienti.** nell'editor della regola; «Una regola richiede più validatori di quanti ne abbia questo spazio» nell'elenco di prontezza, dove **Ruoli e chi convalida le richieste** diventa allora obbligatoria |
| Il blocco di valuta e paese | Quando lo spazio ha emesso un documento o registrato denaro, il server rifiuta qualsiasi cambio di **Valuta** o **Paese**, dal modulo delle impostazioni, da un'importazione o da qualsiasi altro punto. Il fuso orario non è bloccato. | «La valuta e il paese sono fissati non appena lo spazio ha emesso un documento o registrato denaro. Non è stato salvato nulla.» quando salva [Spazio](app:/workspace-settings) |
| La posta del proprietario | Ciò che resta da configurare: una riga «Da configurare: …» per ogni area obbligatoria dell'elenco di prontezza che non è pronta, e una riga «… funzioni attivate attendono «…»» per ogni funzione spenta che ne trattiene altre. | [Che cosa richiede la Sua attenzione](help:user.collaborate.attention); un tocco apre la schermata in cui si configura, oppure **Funzionalità** |
| La protezione delle serie di numerazione | Un azzeramento più frequente della data stampata nel numero viene rifiutato. | [Serie di numerazione](app:/settings/number-sequences), al salvataggio |
| Il controllo di maturità | Una funzione valutata **Alfa** o **Beta**. | Una conferma prima di attivarla e un contrassegno su ogni interruttore |
| Il controllo di sostituzione della planimetria | Sostituire la planimetria o le impostazioni da un file. | Un avviso che non si può annullare. La planimetria viene rifiutata quando esistono prenotazioni |

**Da sapere**

- **Configurazione di questo spazio** è un elenco, non un blocco. Non Le impedisce mai di attivare qualcosa.
- La maggior parte delle protezioni agisce quando prova a emettere, pagare o prenotare, non quando sceglie un'impostazione. Per questo esiste la verifica qui sotto.
- La posta del proprietario ([Che cosa richiede la Sua attenzione](help:user.collaborate.attention)) segnala solo le aree obbligatorie e le funzioni trattenute. Le aree facoltative restano nell'elenco di prontezza: lo legga Lei stesso.

**Vedi anche:** [Evitare funzioni che si contraddicono](help:setup.features.consistency) · [Controlli il Suo spazio](help:setup.place.check)

<!-- anchor: setup.consistent.gaps -->
### Gli errori che le protezioni non intercettano

**Destinatari:** Proprietario · Comproprietario · Amministratore fatturazione

Vuole l'elenco onesto di ciò che resta a Suo carico. Sono configurazioni che l'app Le lascia creare e per le quali non avvisa. Ciascuna ha un modo per evitarla a mano.

| Errore | Perché nulla lo ferma | Come evitarlo |
|---|---|---|
| Scegliere un paese diverso da Francia o Germania e aspettarsi delle fatture | L'app offre molti paesi e aliquote IVA, ma emette fatture solo per Francia e Germania. Nulla lo dice quando sceglie il paese. | Deciderlo prima di promettere una fattura ai membri. Altrove, tenga gli estratti conto nell'app ed emetta le fatture all'esterno. |
| Essere soggetti a IVA senza alcuna aliquota in vigore | L'emissione viene rifiutata, ma solo alla prima fattura. La descrizione di **Gestione IVA** e l'avviso nella schermata dell'identità legale lo dicono; nulla La ferma prima. Con **Gestione IVA** spenta, la configurazione è nascosta ma le aliquote memorizzate continuano ad applicarsi. | Aggiungere l'aliquota in [IVA](app:/vat) prima della prima chiusura mensile ed eseguire una fattura di prova. |
| **Pagamenti online** attivi senza fornitore | Può attivarli; il fornitore mancante compare solo come voce nell'elenco di prontezza. | Collegare prima il fornitore, poi attivare. |
| **Fatture** attive senza identità legale | La funzione è attiva fin dal primo giorno. L'elenco di prontezza segna l'identità **Necessario prima di fatturare** e la Sua posta la segnala, ma nulla Le impedisce di invitare membri e far girare un mese; il rifiuto arriva al momento dell'emissione. | Compilare l'identità prima di dire ai membri che verranno fatturati. |
| Una regola che richiede più convalidatori di quanti ne ha | L'editor Le lascia salvarne una superiore alle persone disponibili. L'elenco di prontezza segna allora **Ruoli e chi convalida le richieste** come obbligatoria, qualunque sia il tipo di richiesta, ma le richieste create prima della correzione non possono essere completate e scadono dopo sette giorni. | Contare i proprietari e gli amministratori attivi dopo ogni regola. Vedi [Evitare richieste che attendono per sempre](help:setup.people.stuck). |
| Membri che non riescono ad aprire la planimetria | In un nuovo spazio la scheda **Utente** di [Ruoli](app:/roles) è vuota. L'elenco di prontezza segna **Cosa possono fare i membri** finché i membri non possiedono **Prenotare e usare le prenotazioni**, ma controlla solo quello: gli altri cinque permessi di uso quotidiano li spunta Lei. | Spuntare i permessi di uso quotidiano e iscriversi una volta con un secondo account. |
| Uno spazio creato da un modello | Un modello non porta mai con sé identità, dati bancari, sedi né inviti. | Trattare l'area **Dati richiesti dalle funzioni (identità, banca, piattaforme)** come un elenco di cose da fare. |
| Un file di impostazioni che promette più di quanto dà | Il file porta la matrice dei ruoli con tutti i permessi, i Suoi ruoli, ogni regola di convalida, la numerazione di fatture e membri e i prezzi dell'intero spazio; non i membri, il periodo IVA, il nome dello spazio né le credenziali della fatturazione elettronica. Quando **Configurazione nel file dello spazio** è disattivata nella destinazione, l'importazione chiede prima: **Attiva e applica** o **Importa senza la configurazione**. Una planimetria non viene sostituita quando esistono prenotazioni. | Reinserire a mano ciò che non porta e leggere l'anteprima prima di **Sostituisci e importa**. |
| Solleciti che non partono mai | Girano ogni mattina sul server se l'installazione pianifica attività (pg_cron); altrimenti quando un amministratore apre Finanze. L'interruttore e la descrizione della funzione lo dicono, ma non possono dire quale vale per la Sua installazione. Restano silenziosi anche quando **Solleciti di pagamento automatici** è spenta. | Chiedere all'operatore se lo scheduler esiste e, se non c'è, aprire Finanze personalmente. Vedi [Solleciti automatici](help:user.money.reminders.automatic). |
| Cambiare il fuso orario quando esiste già del denaro | Il server blocca la valuta e il paese quando lo spazio ha emesso un documento o registrato denaro, ma non il fuso orario, nel quale si contano ogni giorno lavorativo, mezza giornata e giorno di chiusura. | Sceglierlo il primo giorno. Vedi [Decisioni difficili da annullare](help:setup.before.permanent). |
| Una numerazione o un periodo IVA che non si adatta al formato del commercialista | L'app non li confronta con l'esportazione contabile del paese. | Chiedere al commercialista il formato di numerazione e l'esportazione che usa prima di emettere. Vedi [Esportazioni contabili](help:user.invoicing.accounting-export). |
| Scambiare uno spazio di prova per quello reale | Oltre alla filigrana sui documenti stampati, la differenza è facile da non notare. | Guardare il banner dello spazio di prova e il lato mostrato in [Io](app:/me) prima di agire. |

**Da sapere**

- Un chiosco senza membro chiosco, una funzione per le sedi senza sede, una push senza servizio push: [Evitare funzioni che si contraddicono](help:setup.features.consistency).
- L'app è più severa di quanto sembri per le fatture e più permissiva di quanto sembri per tutto il resto. Nel dubbio, emetta una fattura di prova in uno spazio di prova.

**Vedi anche:** [Una prova sicura](help:setup.money.dry-run)

<!-- anchor: setup.consistent.audit -->
### La verifica prima dell'apertura

**Destinatari:** Proprietario · Comproprietario

Vuole una prova, non una sensazione, prima di aprire. Trentuno controlli, in tre livelli. Esegua *Aprire* prima di invitare qualcuno, *Funzionare* prima di promettere qualcosa sul denaro, *Crescere* prima che esca la prima fattura. Lo faccia prima in uno spazio di prova, con una seconda persona.

*Aprire: un luogo che le persone possono prenotare*

| # | Controllo | Dove | Com'è quando va bene |
|---|---|---|---|
| 1 | Paese, valuta, fuso orario | [Spazio](app:/workspace-settings), **Informazioni generali** | Atelier du Marché: Francia, EUR, Europe/Paris, impostati prima del primo documento o pagamento, dopo il quale la valuta e il paese sono bloccati |
| 2 | Lingua dello spazio | Stessa schermata | La lingua in cui sono scritti i Suoi inviti |
| 3 | Giorni e orari di apertura | [Disponibilità](app:/availability) | I giorni in cui apre sono spuntati; gli orari corrispondono al giorno |
| 4 | Giorni di chiusura | Disponibilità, giorni di chiusura | Festività e chiusure dei prossimi mesi sono inserite, prima della prima fine mese |
| 5 | Almeno un posto | [Editor dello spazio](app:/editor) | Ogni stanza che affitta ha dei posti |
| 6 | Prontezza | **Configurazione di questo spazio** | Nulla sotto **Giorni di apertura, fuso orario e valuta**, **Posti prenotabili sulla planimetria** o **Cosa possono fare i membri** richiede configurazione |
| 7 | Ha prenotato un posto | [Prenota](app:/reserve) | Il posto è prenotato, con check-in e annullato senza sorprese |
| 8 | L'ID dello spazio | [ID dello spazio e QR](app:/workspace-code) | L'ID è uno che si può dire a voce alta; il QR è stampato |
| 9 | Permessi di uso quotidiano | [Ruoli](app:/roles) | **Utente** possiede i sei permessi di uso quotidiano, tra cui **Prenotare e usare le prenotazioni** |
| 10 | Un secondo account si è iscritto | Un altro dispositivo | È stato approvato e ha potuto aprire la planimetria e prenotare |
| 11 | Più di una persona può agire | [Membri e piani](app:/members) | Un proprietario più un comproprietario o un amministratore, tutti **Attivo** |
| 12 | Numero di convalide | [Regole di convalida](app:/validation) | Nessuna regola chiede più convalidatori dei proprietari e amministratori attivi; **Ruoli e chi convalida le richieste** non richiede configurazione |
| 13 | L'invito in ogni lingua | **Comunità e inviti** | Ha letto ogni versione una volta; nessun segnaposto resta vuoto |
| 14 | Il lato in cui si trova | [Io](app:/me) | Il banner dello spazio di prova è mostrato, oppure no, come intendeva |

*Funzionare: le persone pagano e i ruoli tengono*

| # | Controllo | Dove | Com'è quando va bene |
|---|---|---|---|
| 15 | Fasce tariffarie | [Fatturazione](app:/billing) | Ogni quota che un membro può scegliere rientra in una fascia; nessun buco tra 0 e 100 per cento |
| 16 | Piani offerti | Fatturazione, livelli | Solo i piani che vuole vendere |
| 17 | Con che cosa partono i nuovi membri | **Nuovi membri**, in Spazio | L'abbonamento e la regola per quando i giorni finiscono sono quelli che ha scelto |
| 18 | Pacchetti e servizi | Fatturazione, [Servizi](app:/services) | Nomi e prezzi sono chiari per un membro |
| 19 | Come pagano i membri | **Come pagano i membri** nell'elenco di prontezza | L'area indica **Pronto** e i dati bancari che si aspetta (IBAN, causale) sono mostrati nelle Impostazioni; anche un solo fornitore la rende pronta |
| 20 | Pagamenti online | [Funzionalità](app:/features) | Spenti, a meno che un fornitore sia collegato |
| 21 | Amministratori | Membri e piani | Ciascuno è una persona a cui affiderebbe i dati di ogni membro |
| 22 | Scheda Amministratore della matrice | Ruoli | Sa leggere ogni spunta e giustificarla |
| 23 | Chi viene informato di che cosa | [Come vengono informati i membri](help:setup.notify.members) | I membri trovano tutto sotto **Eventi**; la push solo se l'operatore l'ha configurata |
| 24 | Chiosco e badge | [Funzionalità](app:/features) | Spenti, oppure esiste un membro chiosco e i badge sono emessi |
| 25 | Sedi | Funzionalità | Spente, oppure esiste almeno una sede |
| 26 | Funzioni trattenute | **Funzionalità**, **Richiede attenzione** | Il filtro non mostra alcun processo, e la Sua posta non ha righe su funzioni in attesa |

*Crescere: fatture, imposte e registri*

| # | Controllo | Dove | Com'è quando va bene |
|---|---|---|---|
| 27 | Identità legale | [Identità legale e fatturazione elettronica](app:/legal-identity) | **L'identità legale e l'indirizzo dello spazio** indica **Pronto**, e **Completi questi dati prima dell'emissione** non mostra nulla quando avvia una fattura di prova |
| 28 | Regime e aliquote IVA | [IVA](app:/vat) | Il regime è quello indicato dal commercialista; per la Sua aliquota predefinita ce n'è una in vigore |
| 29 | Formato dei numeri | [Serie di numerazione](app:/settings/number-sequences) | Ha letto l'anteprima e il commercialista è d'accordo |
| 30 | Una fattura di prova | Spazio di prova, assistente di chiusura mensile | È stata emessa, in ogni lingua che leggono i Suoi membri, senza voci mancanti |
| 31 | Un'esportazione recente | **Esportazione e ripristino** | «A recent export is on record» |

**Passaggi**

1. Stampi le tre tabelle o le copi nei Suoi appunti.
2. Esegua *Aprire* e spunti ogni riga quando vede la colonna «va bene», non quando se ne ricorda.
3. Faccia lo stesso per *Funzionare* e *Crescere* nello spazio di prova, con il commercialista per le righe di *Crescere*.
4. Ripeta le righe che sono cambiate quando passa allo spazio reale. Un modello o un file di impostazioni non porta con sé tutto.

**Risultato** Un elenco che può mostrare a qualcuno e uno spazio che ha visto funzionare prima che qualcuno dipenda da esso.

**Vedi anche:** [Dalla settimana 0 alla settimana 4](help:setup.training.overview) · [Una prova sicura](help:setup.money.dry-run) · [La sequenza da seguire](help:setup.reports.sequence)

<!-- anchor: setup.consistent.monthly -->
### La routine mensile

**Destinatari:** Proprietario · Amministratore · Amministratore fatturazione

Vuole un'abitudine breve che mantenga coerente lo spazio, in dieci minuti a fine mese.

**Passaggi**

1. Apra **Configurazione di questo spazio**. Ogni area indica ancora **Pronto**, oppure **Non necessario qui**, oppure è messa da parte di proposito.
2. Apra [Eventi](app:/events). **In attesa della sua conferma** è vuoto o piccolo, e nessun membro è **In attesa** da più di un giorno o due.
3. Riconti la squadra. Chi se n'è andato o è stato sospeso può lasciare una regola scoperta. Vedi [Evitare richieste che attendono per sempre](help:setup.people.stuck).
4. Chiuda il mese: i giorni di chiusura sono inseriti, l'assistente di chiusura mensile è stato eseguito, i solleciti di pagamento sono partiti (in automatico ogni mattina, oppure all'apertura di Finanze dove il database non ha lo scheduler). Vedi [L'assistente di chiusura mensile](help:user.invoicing.wizard).
5. Faccia l'esportazione dei dati e apra **Funzionalità** per verificare che, dopo le modifiche del mese, nessun processo richieda attenzione.

**Da sapere**

- Scrivere la data dell'ultima esecuzione sulla prima riga dei Suoi appunti dice alla persona successiva quando è stato vero l'ultima volta.
- Qualsiasi modifica fatta durante il mese alla matrice dei ruoli o a una regola di convalida merita un ulteriore controllo delle righe 9, 11 e 12 della verifica.

**Risultato** Uno spazio che resta come l'ha configurato.

**Vedi anche:** [La verifica prima dell'apertura](help:setup.consistent.audit)

<!-- anchor: setup.consistent.wrong -->
### Quando qualcosa non sembra giusto

**Destinatari:** Proprietario · Comproprietario · Amministratore

Vuole sapere che cosa provare, in quale ordine e a chi chiedere.

<p><img src="images/setup-consistent-recovery-export.it.jpg" width="280"></p>

**Passaggi**

1. Legga il messaggio sullo schermo. La maggior parte dice che cosa fare.
2. Controlli il lato. Guardi il banner dello spazio di prova e il lato mostrato in [Io](app:/me). I documenti stampati sul lato di prova portano una filigrana e lì nulla è dovuto; il lato reale emette fatture che sono dovute.
3. Controlli [Funzionalità](app:/features) e [Ruoli](app:/roles): una funzione che manca è una funzione spenta o un permesso che nessuno ha spuntato.
4. Apra **Configurazione di questo spazio** e legga l'area che corrisponde al sintomo.
5. Prepari i **Dettagli per l’assistenza** in [Aiuto](app:/help): scelga **Ultima ora** o **Ultime 24 ore**, **Prepara anteprima**, la legga, **Salva** e invii il file. Contiene solo conteggi e controlli, non identità, credenziali né dati aziendali.
6. Prima di cambiare qualcosa di importante, faccia l'esportazione dei dati (qui sotto).

*A chi chiedere*

| Riguardo a | Chieda a |
|---|---|
| Un'impostazione del Suo spazio, una regola, un ruolo | A Lei stesso, poi al Suo comproprietario |
| Una fattura, l'IVA, un numero | Al Suo commercialista, con la fattura di prova |
| Un'area che indica **In attesa di un’altra persona** o **L’operatore del server** | All'operatore della Sua installazione |
| Un assistente che non è approvato | A un amministratore del database |
| Un errore che non sa spiegare | All'assistenza, con il file di assistenza |

*L'esportazione di ripristino*

1. Apra [Report](app:/reports?section=documents) e scelga **Documenti dello spazio**.
2. Tocchi **Esporta i dati (Excel)**. Servono la funzione **Esportazione dati (Excel)** e il permesso **Esportare contabilità e dati**. Ottiene un unico ZIP: una cartella di lavoro con una scheda per ogni insieme di dati, un manifesto che conta le righe e i file archiviati.
3. Tocchi **Esporta configurazione (PDF)** per una registrazione dei parametri e, in **Spazio**, **Esporta lo spazio (XML)** per la planimetria e le impostazioni.

**Da sapere**

- Un'esportazione dei dati completata viene registrata; l'area di prontezza **Esportazione e ripristino** lo indica per 90 giorni, poi segnala che l'esportazione è più vecchia.
- Il PDF è una registrazione, non una copia di sicurezza. Solo l'XML può essere reimportato e non contiene mai membri né denaro.
- Conservi il file in un luogo che solo Lei può aprire: contiene i Suoi membri.

**Vedi anche:** [Dettagli per l'assistenza](help:user.advanced.support) · [Quando qualcosa non funziona](help:user.advanced.troubleshooting) · [Esportare i dati (Excel)](help:user.workspace.export.excel)

<!-- anchor: setup.consistent.irreversible -->
### Ciò che non si può annullare

**Destinatari:** Proprietario · Comproprietario · Amministratore fatturazione

Vuole una pagina sola che dica su che cosa rallentare. L'elenco completo, con che cosa fare in alternativa, è in [Decisioni difficili da annullare](help:setup.before.permanent). Questo è il riepilogo.

> **Attenzione** Una fattura emessa non cambia mai e il suo numero non viene mai riutilizzato. Un errore si corregge con un annullamento, una nota di credito o una richiesta di rimborso, non con una modifica.

| Decisione | Definitiva da | Trattata in |
|---|---|---|
| Formato e sequenza del numero di fattura | La prima fattura emessa | [Decisioni difficili da annullare](help:setup.before.permanent) |
| Il mese fatturato di un membro | Il momento in cui la fattura viene emessa | [Denaro](help:setup.money.permanent) |
| Menzioni legali sulla fattura | La prima fattura emessa | [La sequenza da seguire](help:setup.reports.sequence) |
| Regime e aliquote IVA | Le aliquote sono versionate per data e mai modificate; una dichiarazione presentata non viene mai ricalcolata | [Denaro](help:setup.money.permanent) |
| Paese e valuta | Bloccati dal server quando lo spazio ha emesso un documento o registrato denaro: gli importi non vengono convertiti | [Decisioni difficili da annullare](help:setup.before.permanent) |
| Fuso orario | Mai bloccato, ma i giorni si contano in esso: lo scelga il primo giorno | [Decisioni difficili da annullare](help:setup.before.permanent) |
| Sostituzione della planimetria | Rifiutata quando esiste una prenotazione; eliminare un piano rimuove ciò che contiene | [Decisioni difficili da annullare](help:setup.before.permanent) |
| L'ID dello spazio | Quando lo cambia, il vecchio smette subito di funzionare; ristampi il QR | [Come si entra](help:setup.people.join) |
| La proprietà | Un proprietario può cederla; non esiste un invito come proprietario | [Comproprietari](help:setup.people.coowner) |
| Una modifica alla matrice o a una convalida | Viene registrata come evento e ha effetto per tutti subito | [La matrice dei ruoli](help:setup.people.matrix) |
| Prova o reale | Uno spazio reale emette fatture che sono dovute | [Prima di iniziare](help:setup.before.overview) |
| Un'esportazione condivisa | Un file condiviso non si può revocare | [Quando qualcosa non sembra giusto](help:setup.consistent.wrong) |

**Da sapere**

- Spegnere una funzione non cancella mai dati.
- Un file con credenziali non è una copia di sicurezza. Tenga i token fuori da qualsiasi file che invia.

**Risultato** Sa quali righe leggere due volte.

**Vedi anche:** [Prima di iniziare](help:setup.before.overview)
