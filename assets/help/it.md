# Guida utente

Tutto ciò che un membro, un admin o un proprietario deve sapere per usare DesKilo.

> Gli screenshot di questa guida mostrano l'app in francese — ogni schermata esiste identica nelle cinque lingue (English, Français, Deutsch, Español, Italiano); cambia lingua in **Impostazioni → Lingua**.

![](assets/help/images/settings-language.jpg)

## 1. Primi passi

### Creare un account

Apri l'app e registrati con email, password (minimo 8 caratteri) e un nome visibile — oppure **continua con Google**. Il pulsante a occhio mostra o nasconde la password mentre digiti. *Password dimenticata?* ti manda via e-mail un **codice numerico monouso**, che riporti nell'app insieme alla nuova password — di proposito un codice e non un link, così la reimpostazione funziona anche dove i link diretti all'app non sono configurati. Un accesso Google può essere collegato in seguito a un account email esistente in **Impostazioni → Account collegati**.

### Creare uno spazio — o unirsi a uno

Dopo l'accesso, la schermata di benvenuto offre due strade:

- **Crea uno spazio di lavoro** — ne diventi il **proprietario**. Scegli nome, paese (determina la valuta predefinita) e fuso orario. Poi disegnerai la piantina nell'editor (§8).
- **Unisciti a uno spazio** — digita l'**ID dello spazio** che ti hanno condiviso, oppure tocca **Scansiona codice QR** e inquadra il QR d'invito appeso alla parete del tuo spazio. La tua richiesta arriva **in attesa**: *Nuovo membro* è uno dei domini di validazione (§7), quindi è un validatore a farti entrare, e da quel momento hai esattamente il ruolo che l'invito porta con sé (§2).

### Il questionario di configurazione — preparare uno spazio prima di aprire l'app

Creare uno spazio significa decine di decisioni sparse in una decina di schermate diverse: che forma può avere una prenotazione, quanto costa un mese, che cosa la legge vuole su una fattura, chi valida che cosa. L'app te le lascia prendere una alla volta, man mano che le incontri. Il **questionario di configurazione** te le lascia prendere tutte insieme, *prima* di cominciare — su uno schermo grande, con il tuo commercialista o il tuo consiglio direttivo se aiuta, senza toccare nulla di reale:

<https://fdittgen-png.github.io/deskilo/setup.html>

È una sola pagina web. Niente da installare, nessun account, niente che parta da qualche parte: le tue risposte si salvano nel tuo browser, quindi puoi chiudere la scheda e ritrovarle.

![](assets/help/images/setup-wizard.jpg)

*La procedura guidata: dodici passi in ordine di dipendenza, ogni domanda dice dove si regola l'impostazione nell'app, con un **?** che apre questa guida alla sezione corrispondente.*

**Come si usa**

1. **Rispondi ai passi in ordine** — identità, funzionalità, disponibilità, piantina, abbonamenti, identità legale e IVA, servizi, istruzioni di pagamento, ruoli e validazione, membri. Ogni passo chiede solo ciò che le risposte precedenti rendono possibile: niente aliquote IVA se non sei soggetto a IVA, niente piattaforma di fatturazione elettronica fuori dall'UE, niente opzione pacchetto di giorni per un membro finché non esiste un pacchetto, niente funzionalità figlia finché la madre è spenta.
2. **Controlla il riepilogo delle funzionalità.** Elenca ogni funzionalità che l'app attiverà e *come le tue stesse risposte la configurano*. Deseleziona quelle che non vuoi: vengono esportate disattivate e la loro configurazione viene lasciata fuori — puoi sempre attivarle in seguito in Impostazioni → Funzionalità.
3. **Leggi il passo di verifica.** Separa ciò che è completo, ciò che è una scelta da confermare e ciò che blocca davvero, ognuno con un salto diretto alla domanda che lo risolve.
4. **Esporta l'XML**, poi apri l'app: **Impostazioni → Spazio di coworking → Importa lo spazio (XML)** crea direttamente le impostazioni, gli accessori e la piantina. La sezione `<setup>` dello stesso file porta tutto ciò che l'importazione non prende — fatturazione, identità legale, ruoli, membri — così puoi completare quelle schermate una a una; ogni domanda ti ha detto dove si regola la sua risposta.
5. **Conserva il file.** Ricaricarlo nella pagina riprende da dove avevi lasciato — compreso un file esportato prima che un'impostazione esistesse, che torna semplicemente con quella impostazione al suo valore predefinito.

![](assets/help/images/setup-feature-summary.jpg)

*Il riepilogo delle funzionalità: ciò che l'app attiverà, configurato dalle tue stesse risposte — deseleziona ciò che non vuoi.*

**Un avvertimento.** Il file esportato è in chiaro. Inserisci un token di fatturazione elettronica o una chiave di un fornitore di pagamenti solo se rispondi in privato; altrimenti lascia vuoti quei campi e digita i segreti nell'app, dove partono lato server e non tornano mai indietro.

**Saltarlo non costa nulla.** Ogni risposta che raccoglie è un'impostazione che puoi anche fare — e cambiare — nell'app in seguito. Il questionario è una scorciatoia per la prima ora, non un passaggio obbligato.

### Profili — un account, più spazi

Un account può appartenere a più spazi. **Impostazioni → Profili** li elenca tutti: ogni riga mostra il nome dello spazio, **il tuo ruolo lì** (Membro, Admin, Proprietario) e il suo ID. Il **segno di spunta** indica il profilo in cui ti trovi adesso; la **stella** indica quello **predefinito** — il profilo con cui l'app si apre, su ogni dispositivo e anche dopo una reinstallazione (la scelta è salvata con il tuo account). Tocca una riga per cambiare, **+ Aggiungi un profilo** per unirti a un altro spazio ancora. Tutto nell'app è riferito allo spazio attivo. Dal #996 **il cambio viene ricordato**: toccare un altro profilo, o l'altro lato di una coppia, lo rende predefinito all'avvio — la stella lo segue, e dopo un riavvio non torni mai in uno spazio o in un ambiente che avevi lasciato.

![](assets/help/images/profiles.jpg)

*Profili: ogni spazio a cui appartiene il tuo account, il tuo ruolo, la stella per il predefinito, la spunta per quello attivo.*

### Orientarsi

L'app ha fino a cinque destinazioni lungo il bordo inferiore: **Messaggi** (§16), **Calendario** (§5), il grande pulsante centrale **Prenota** (§4), **Membri** (§6) e **Finanze** (§9). Messaggi e Prenota ci sono sempre; Calendario, Membri e Finanze vanno e vengono con la loro funzionalità (§8). **Messaggi è la casella**: le tue conversazioni e il flusso di eventi e conferme (§7) sono le sue due facce, e la **campanella** nella barra dell'app salta dritta alla seconda, con il conteggio di ciò che ti aspetta. L'**ingranaggio** che apre le **Impostazioni** (§12) è invece in ogni intestazione. Sui telefoni in orizzontale e sui tablet la maggior parte delle schermate passa a un **layout diviso** — i controlli in un pannello laterale, il contenuto a riempire il resto. **Senza campanella (#1306).** Uno spazio può disattivare il feed degli eventi in Funzionalità. Le decisioni che ti aspettano passano allora al **Calendario**: la sua destinazione porta il contatore e il calendario si apre con esse fissate in alto, *Accetta* a un tocco — finché il calendario mostra le decisioni sulla sua linea temporale.

**Tutto resta dal vivo.** Qualunque cosa qualcuno cambi — una prenotazione, un nuovo membro, un'impostazione — viene inviata in pochi secondi a ogni dispositivo connesso, compreso quello che ha fatto la modifica. Nessun riavvio, nessun trascinare-per-aggiornare.

**Sul web: il pulsante menu.** In un browser spariscono la barra in basso e il suo pulsante rotondo Prenota — la finestra ha la larghezza che manca al telefono e nulla della sua portata del pollice. Il **menu ☰** in alto a sinistra apre un cassetto con ogni destinazione a un tocco: Prenota, le schede, Eventi, poi le schermate di amministrazione (Spazio, Membri e piani, Disponibilità, Ruoli, Fatturazione e report, Coordinate di pagamento, Pagamenti online, Badge, Servizi, Accessori, Fatturazione, Funzionalità, Modifica spazio) e, per ultimi, Documenti, Privacy e dati, Impostazioni. Tutta l'altezza resta al contenuto. Telefoni e app desktop mantengono la barra.

**Più spazio: scorri via la barra (#1173).** Scorri la barra in basso **verso il basso** — o toccala due volte — e le schede si spostano, lasciando il pulsante rotondo **Prenota** dov'è. La barra segue il dito mentre tiri, così vedi dove sta andando: lasciala prima di metà e torna, oltre metà e resta via. Un colpetto deciso sceglie da solo, per quanto poco abbia viaggiato (#1265). Il contenuto riprende tutta la fascia, che sulla piantina è la differenza fra quattro file di posti e cinque. Tre modi la riportano: scorrere **verso l'alto** nella stessa fascia, **tenere premuto** il pulsante Prenota, o usare la sua azione *Mostra navigazione* con uno screen reader. La scelta è ricordata su questo dispositivo, e il suggerimento compare una volta sola. **La barra del titolo va via con lei (#1322)**, quindi la vista è davvero a schermo intero: le due barre seguono insieme il dito e tornano insieme. La barra di stato del telefono e la striscia di sviluppo restano. Scansione, editor, Privacy e Impostazioni tornano con le barre, e finché una decisione ti aspetta il pulsante Prenota porta il contatore della campanella.

## 2. Ruoli e inviti

DesKilo ha tre ruoli cumulativi e, sopra di essi, una variante di comproprietà, più un account dispositivo:

| Ruolo | Può |
|---|---|
| **Membro** | Fare check-in/out, prenotare, presentare spese, vedere e gestire i propri eventi e il proprio conto |
| **Admin** | Tutto ciò che può un membro, più: agire *per chiunque* (prenotazioni, pagamenti, spese — soggetto a conferma, §7), approvare le spese, consultare e gestire gli accordi commerciali, emettere badge per il chiosco |
| **Proprietario** | Tutto ciò che può un admin, più: modificare lo spazio fisico, definire piani e prezzi, gestire ruoli, dispositivi chiosco e impostazioni dello spazio |
| **Comproprietario** | *Attivo*: i permessi del proprietario da subito, più la successione automatica. *Passivo*: un successore in attesa, oggi senza permessi aggiuntivi |
| **Chiosco** | Un account per tablet a parete (§10) — mostra solo la piantina; i membri veri agiscono attraverso di esso con un badge |

Una parte di tutto questo non è scolpita nella pietra: il proprietario riregola **undici permessi di amministrazione** nella matrice **Gestione dei ruoli** (§8) — gestire i ruoli, gestire i membri, regole di convalida, impostazioni dello spazio, emettere fatture, consultare le finanze, documenti, servizi, approvare le spese, consultare e gestire gli accordi commerciali. Ciò che la matrice *non* governa è il quotidiano — fare check-in, prenotare, agire per un altro membro, modificare lo spazio — che resta dove lo mette la tabella qui sopra, retto invece dalle funzionalità e dagli interruttori per singolo membro. Dal #982 la matrice porta anche ciò che prima poteva fare solo un proprietario o un admin: **sedi e piani**, **tariffe e regole di fatturazione**, **prenotazioni degli altri**, **chiosco e badge**, **esportazioni**, **progettazione dei documenti**, **dati personali dei membri**, **integrazioni** e **configurazione**. Una riga admin mai modificata mantiene esattamente ciò che gli admin potevano fare (sedi, prenotazioni, chiosco, esportazioni, dati personali); chi modifica una riga decide l'intera riga.

**Ogni invito è legato a un ruolo.** Nella schermata *ID spazio & QR* del proprietario due schede contengono due inviti, ciascuno con il proprio QR e il proprio codice:

- **Invito membro** — l'ID dello spazio stesso, mostrato sotto il nome dello spazio. Stampalo, appendilo alla parete, condividilo liberamente: chi lo scansiona o lo digita chiede di entrare come semplice membro, e un validatore lo ammette (§7). Pulsanti: **Copia l'ID**, **Condividi come PNG**, **Cambia l'ID dello spazio** (sostituisci l'ID generato con uno memorizzabile, 4–20 lettere/cifre) e **Invita qualcuno**.
- **Invito admin** — un **codice personale monouso**, emesso da un proprietario per una persona precisa. La schermata lo dice chiaramente: *questo codice ammette UNA persona come admin, poi scade* (un codice inutilizzato decade dopo 14 giorni). Consegnalo solo alla persona a cui è destinato; emettine uno nuovo per ogni admin con **Nuovo codice admin**.
- **Gli inviti parlano la lingua dell'invitato** — il foglio d'invito scrive il messaggio nella lingua che scegli (cinque disponibili), per impostazione predefinita la **lingua dello spazio** definita nelle *Impostazioni dello spazio*. Lì il proprietario può anche personalizzare il testo dell'invito **per lingua**, con segnaposto come `{firstName}`, `{workspaceName}`, `{inviteLink}`, `{downloadUrl}`, `{role}`; una lingua lasciata vuota usa il messaggio integrato tradotto.

**Non esiste un invito proprietario — di proposito** (il piè della schermata te lo ricorda). La proprietà può essere concessa solo da un proprietario esistente, in *Membri e piani*. Uno spazio mantiene sempre almeno un proprietario. Promuovere o retrocedere un **admin** passa dal flusso di validazione (§7) — si applica quando i validatori dello spazio confermano.

**I comproprietari tengono in vita lo spazio.** Il proprietario nomina qualsiasi membro o admin come comproprietario (*Membri e piani → il membro → Comproprietà*), in una di due varianti: un comproprietario **attivo** lavora da subito con i permessi del proprietario; un comproprietario **passivo** non ha permessi aggiuntivi fino al giorno in cui servono. In entrambi i casi la successione è automatica: se l'ultimo proprietario se ne va — esce, viene rimosso, o il suo account scompare — il miglior comproprietario (attivo prima di passivo) **diventa proprietario all'istante**, sul server, senza alcuna azione richiesta. Il proprietario può anche passare la mano deliberatamente in qualsiasi momento con *Promuovi a proprietario ora*. Una sfumatura: le regole di validazione che esigono l'approvazione del *proprietario* (§7) intendono sempre un proprietario vero e proprio, non un comproprietario attivo.

Il QR codifica un link che nomina il ruolo concesso (`deskilo://join?role=…`). Manomettere il link non cambia nulla — il server ricava il ruolo dal codice stesso: l'ID dello spazio fa sempre entrare come membro, e un invito personale fa entrare esattamente nel ruolo con cui è stato emesso, una sola volta. Un codice admin inoltrato già usato — o scaduto — non ammette nessuno.

**Invitare via messaggio** (*Invita qualcuno*): ogni invio WhatsApp/SMS/condivisione emette il proprio codice personale monouso e compone un messaggio pronto nella lingua dell'invitato. Il destinatario può semplicemente copiare l'intero messaggio e incollarlo nel campo di adesione dell'app — il codice viene rilevato automaticamente.

## 3. La piantina (nell'hub Prenota)

La piantina mostra il livello attivo del tuo spazio: uffici, tavoli e posti, con codice colore — **libero**, **prenotato**, **occupato**, **mio**, **bloccato**. Si apre **all'istante dagli ultimi dati noti** e si aggiorna in background — con un Wi-Fi instabile vedi comunque lo stato più recente invece di una schermata vuota. Se quello stato non ha potuto essere aggiornato, un avviso lo dice — *Offline — disponibilità delle 09:30* — con **Riprova**, perché un posto mostrato libero potrebbe essere stato preso nel frattempo (#1305). Un posto occupato mostra chi c'è con la sua **iniziale** — o con la sua **foto**, se l'ha impostata e il proprietario ha attivato *Foto dei membri sulla piantina* — più un **badge di check-in** quando è arrivato e un **punto verde** quando è online nell'app in questo momento. I nomi per esteso compaiono dove c'è spazio: sul chip con lucchetto di una prenotazione di spazio intero e nella vista a elenco. Quando un **tavolo, una sala o un piano intero** è prenotato, lo dice lo spazio stesso — una velatura colorata, un bordo marcato e un **chip con lucchetto e il nome dell'occupante** al centro (un glifo di check-in quando è arrivato); l'etichetta della sala recita *Bureau 2 · Florian*. Lo vedono tutti gli utenti, sulla piantina, nell'hub Prenota e sul chiosco.

La piantina può somigliare al tuo spazio reale: il proprietario può mettere una **foto della stanza come sfondo del livello** e piazzare liberamente **immagini illustrative ridimensionabili** (piante, divani…) sulla griglia. Un cursore di **trasparenza dei tavoli** nelle impostazioni dello spazio lascia trasparire la foto sotto i tavoli disegnati.

Muoversi:

- In alto: il controllo **Vista**, che nomina ciò che stai guardando (*Piantina ▾*) e apre le altre viste — **Giorno**, **Settimana** e **Mese**, per esplorare più che per prenotare (#1301); un interruttore **mappa / elenco** (l'elenco mostra gli stessi posti come righe), il **chip della data** (tocca per sfogliare un altro giorno) e i controlli della finestra, che seguono la granularità del tuo spazio (§8): tre **chip di fascia oraria** — mattina, pomeriggio, giornata intera — dove lo spazio prenota a mezze giornate; solo *Giornata intera* dove prenota a giornate; controlli **da → a** su una griglia di minuti o a orari liberi; e gli uni e gli altri con gli *orari reali*.
- La tela **si adatta da sola** al tuo piano all'apertura o alla rotazione del dispositivo; **pizzica per zoomare** o usa i pulsanti **+ / −**, trascina le **barre di scorrimento** ai bordi e tocca il pulsante di **adattamento** per ricentrare.
- Scegli il piano dalla **barra dei livelli** a destra (1, 2, …); la sua **icona livelli** agisce sull'intero livello (sotto). In **orizzontale**, i controlli passano in un pannello laterale e la piantina riempie lo schermo — comodo sui tablet.

Prenotare dalla piantina:

- **Check-in al volo**: tocca un posto libero → la scheda propone *adesso* fino a un bordo canonico → conferma. Con le mezze giornate e le giornate intere il server **riporta poi l'inizio all'inizio dello slot** a cui la finestra appartiene: arrivi alle 10:00, confermi *fino alle 12:00*, e prenoti — e consumi — tutta la mattina 8:00–12:00 (§4b). Se qualcuno ha prenotato quel posto più tardi, la tua ora di fine viene limitata e te lo diciamo.
- **Check-in su prenotazione**: fare check-in significa *sei qui*. Con mezze giornate, giornate intere e orari reali la finestra si apre a **qualsiasi ora del giorno stesso della prenotazione**: alle 10:00 puoi già fare check-in sul tuo pomeriggio delle 12:00. Su una griglia di minuti si apre 15 minuti prima del tuo inizio, o un passo di griglia prima se quel passo è più lungo (così le griglie da 5 e 15 minuti mantengono i 15 minuti, una griglia oraria apre un'ora prima). Si chiude alla fine della prenotazione; fuori dalla finestra il pulsante è disattivato e dice quando apre. Gli admin possono fare il check-in di un membro presente al suo posto (finché *prenota per altri* è attivo).
- **Check-out**: manuale — e **accorcia la prenotazione ad adesso**, così il posto si libera subito per tutti gli altri. È **personale per impostazione predefinita**: un admin (proprietario compreso) può chiudere il check-in di qualcun altro solo se *Gli amministratori possono fare il check-out dei membri* è attivo (§8). Con l'**auto check-in/out** attivo, le prenotazioni dimenticate si chiudono da sole — la pulizia gira a ogni lettura, quindi una prenotazione della mattina lasciata aperta viene completata alla sua stessa fine già dalle 12:01, non a mezzanotte.
- **Spazi interi**: **tocca due volte** un tavolo, una stanza o un tratto libero del pavimento — oppure tocca l'**icona livelli** sulla barra dei livelli — per agire sull'**intero tavolo, ufficio o piano**. **Una sola scheda** contiene tutto: il nome dello spazio, il selettore di periodo (es. *gio 6 ago 10:13 → 12:00*) con le stesse opzioni di ripetizione di una postazione, un selettore facoltativo **Per il membro** per gli admin che prenotano per conto di qualcuno, e il pulsante di conferma.
- **La scheda di prenotazione** tiene la prenotazione in vista: il posto, la data, l'orario e **Prenota**. **Ripeti** e, per gli operatori, *Rendi non prenotabile* aspettano sotto **Altre opzioni** (#1301). Una volta prenotato, la conferma offre **Dettagli**, che apre la nuova prenotazione con il passo successivo: check-in, spostare, annullare.
- **Rendi non prenotabile**: sotto *Altre opzioni* sulla scheda di prenotazione, proprietari e admin (con *Gli admin possono bloccare posti*) mettono il posto fuori servizio da adesso — si legge **bloccato** sulla planimetria finché non viene liberato nella scheda del posto dell'editor.
- **Selettore orario**: scegli una finestra da→a (o Mattina / Pomeriggio / Giornata intera, secondo la granularità dello spazio) per vedere l'occupazione in qualsiasi momento futuro.
- I posti possono avere **accessori** (monitor, scrivania regolabile…), alcuni con supplemento per mezza giornata che compare sul tuo estratto.
- Le prenotazioni contano sui tuoi **giorni mensili** (§9) — oltre il tuo piano, l'app blocca o addebita, secondo ciò che il proprietario ha configurato per te. Un'eccezione: una prenotazione che sta **interamente fuori dagli orari di lavoro** può essere gratuita o esente, secondo la regola fuori-orario dello spazio (§4b).

![](assets/help/images/reserve-plan-closed.jpg)

*La planimetria nell'hub Prenota in un giorno di chiusura: il banner di chiusura, il selettore di vista, la data e i chip di mezza giornata, la barra dei livelli (1 · 2 · livelli) e i controlli di zoom.*

**Una postazione prenotata per parte della giornata lo dimostra (#903).** La piantina legge la postazione da sinistra a destra come la giornata aperta: una prenotazione che finisce a mezzogiorno riempie la metà sinistra, una che inizia nel pomeriggio riempie la destra, e una postazione tenuta tutto il giorno si riempie interamente come prima. Un filetto separa due prenotazioni vicine perché non si leggano mai come una sola, e ogni fascia porta il colore di chi la occupa — tua o di qualcun altro.

**Chi occupa oggi questa postazione.** Tocca una postazione con **più di una prenotazione** e si apre la giornata al posto della scheda abituale: ogni fascia con l'orario, la persona e lo stato (finito, ora, più tardi), e ogni fascia libera come qualcosa da prendere — toccala e la scheda di prenotazione si apre esattamente su quella finestra. Una postazione con una sola prenotazione si comporta come sempre. Il tutto dipende dalla funzionalità *La giornata di una postazione*.

## 4. Prenotazioni (hub Prenota)

Apri l'hub **Prenota** (pulsante centrale). In alto: due righe di controlli. La prima dice **che cosa** stai guardando: i quattro **pulsanti di vista** e, sulla piantina, il selettore **piantina / elenco**. La seconda dice **quando**: il **chip della data**, un pulsante **Adesso** appena ti allontani da oggi, e gli stessi controlli della finestra legati alla granularità della piantina stessa (§3 — chip di fascia oraria, un chip *Giornata intera*, oppure da → a). I **chip di piano** (*Tutti i piani*, o uno per livello) stanno sulla piantina stessa, e il pulsante di **scansione QR** (§4a) sta nella barra dell'app, accanto all'editor e alla campanella. Poi quattro viste:

- **Piantina** — la piantina filtrata sulla finestra scelta; tocca un posto libero per prenotarlo.
- **Giorno** — ogni posto come riga temporale del giorno selezionato (08:00 → 17:00 o l'orario del tuo spazio, la linea rossa segna *adesso*); tocca un tratto libero per prenotare, tocca il tuo blocco per vederne i dettagli.
- **Settimana** — una griglia posto × giorno dell'intera settimana ISO, con una striscia dei giorni (*lun 3 … dom 9*) in alto; ogni cella contiene le mezze giornate del giorno con l'iniziale dell'occupante. Trova una mezza giornata libera a colpo d'occhio e toccala per prenotare.
- **Mese** — un calendario di disponibilità: ogni giorno mostra il suo **conteggio di scrivanie libere** (es. *10/12*); tocca un giorno per entrare nella sua vista Giorno.

**Un posto alla volta — per impostazione predefinita**: lo spazio stabilisce quante prenotazioni sovrapposte un membro può tenere, e quel numero è **1** finché il proprietario non lo alza (§8). A 1, prenotare o fare check-in altrove mentre un'altra è in corso viene rifiutato; in ogni caso un check-in chiude ogni check-in precedente la cui prenotazione è già finita. Gli admin e i proprietari possono **scavalcare**: toccare un posto occupato o prenotato offre *Rimuovi la prenotazione (scavalca)* — la prenotazione viene rimossa e il membro e tutti gli admin vengono avvisati tramite il flusso degli eventi.

Le prenotazioni seguono la **regola di granularità** dello spazio (§8 Disponibilità) — mezze giornate, giornate intere, orari reali (da–a esatto, con le finestre di mezza/giornata intera come scorciatoie), oppure orari liberi di inizio/fine sulla griglia di minuti del proprietario. Mezze giornate e giornate intere coprono l'**orario di lavoro** configurato dello spazio (predefinito 8:00–17:00, con il limite di mezza giornata alle 12:00). Rispettano i **giorni di apertura** e i **giorni di chiusura**, e le regole di prenotazione (orizzonte di anticipo, durata minima e massima). **Una prenotazione finisce sempre nel giorno in cui inizia** — nulla attraversa la mezzanotte; una permanenza che continua domani è la prenotazione di domani, fatta domani (§4b). Esigenze ricorrenti? Prenota una **serie** (giornaliera, feriale, settimanale) — giorni chiusi e conflitti vengono saltati e segnalati.

**Eliminare una prenotazione passata o con check-in è una richiesta, non un'azione.** Una prenotazione il cui inizio è passato — o dove hai già fatto check-in — non si annulla direttamente: la scheda offre invece **Richiedi eliminazione**. Un proprietario o admin decide l'unica domanda che conta per la fatturazione: il check-in è stato semplicemente dimenticato (la prenotazione resta agli atti), o non è mai stata usata (viene rimossa)? La richiesta appare nel flusso Eventi con il tuo motivo facoltativo; le prenotazioni future mai toccate mantengono il normale annullamento con un tocco. Tutto questo percorso viaggia sulla funzionalità **Richieste di eliminazione prenotazioni**: disattivata, una prenotazione iniziata o con check-in non ha né pulsante di annullamento né richiesta — resta semplicemente agli atti.

![](assets/help/images/reserve-day.jpg)

*La vista Giorno: ogni posto come riga temporale, la linea rossa segna adesso — tocca un tratto libero per prenotare.*

![](assets/help/images/reserve-week.jpg)

*La vista Settimana: una griglia posto × giorno con le mezze giornate di ogni giorno, l'iniziale dell'occupante nella cella.*

![](assets/help/images/reserve-month.jpg)

*La vista Mese conta i posti liberi per giorno (8/10); toccare un giorno porta nella sua vista Giorno.*

![](assets/help/images/reserve-booking-sheet.jpg)

*La scheda di prenotazione: Mattina / Pomeriggio / Giornata intera, Prenota per (admin), Ripeti — e Rendi non prenotabile, per proprietari e admin.*

### 4a. Scansionare un codice spazio

Ogni postazione, tavolo, ufficio e piano può avere una **scheda QR** stampata (§8). Tocca il **pulsante di scansione** nell'hub Prenota, inquadra la scheda — o digita il suo codice — e l'app identifica lo spazio e mostra esattamente ciò che *tu* puoi farci:

- **Scheda postazione** — prenota o fai check-in su quella precisa postazione, al momento (finestra di oggi: mattina / pomeriggio / giornata intera dove lo spazio usa le mezze giornate, altrimenti da adesso per le prossime ore).
- **Scheda tavolo** — le postazioni del tavolo con il loro stato in tempo reale; scegline una libera. Un tavolo che il proprietario ha reso prenotabile offre anche il **tavolo intero**, con il suo prezzo per mezza giornata, esattamente come una scheda di ufficio o di piano.
- **Scheda ufficio o piano** — se il proprietario lo ha reso prenotabile, la funzionalità *Prenotazioni di tavolo, ufficio e piano* è attiva **e** possiedi il diritto personale (§8) — proprietari e admin lo hanno sempre — puoi prenotare o fare check-in sull'**intero ufficio o piano** — con lo stesso selettore di periodo (mattina / pomeriggio / giornata intera, o orari liberi) e le stesse opzioni di **serie** di una postazione; il suo prezzo per mezza giornata viene mostrato e finisce sulla tua fattura. Altrimenti la scheda ti spiega perché, e un ufficio ripiega sulle sue postazioni.

**Una scansione apre la scheda del chiosco.** Leggere il codice di una **postazione** — la sua scheda QR stampata, o il tag NFC applicato sulla sedia — propone esattamente ciò che propone il chiosco quando si tocca quella postazione: le stesse tre azioni (**Check-in**, **Prenota**, **Check-out**), lo stesso periodo dedotto dalle impostazioni dello spazio. Unica differenza: hai già effettuato l'accesso, quindi il passaggio del badge non c'è (§4b). Le schede di tavolo, ufficio e piano aprono invece la propria scheda di spazio intero, come descritto sopra; i **tag NFC portano solo a una postazione**, quindi il tag sulla sedia è l'unica scorciatoia «tocca e prenota».

**I conflitti proteggono in entrambe le direzioni:** un ufficio o un piano non può essere prenotato mentre una postazione al suo interno è già prenotata in quella finestra — e nessuna postazione può essere prenotata mentre il suo ufficio o piano è prenotato per intero.

### 4b. Come si comporta la prenotazione

Tutti gli orari qui sotto sono locali dello spazio, e gli esempi assumono la giornata lavorativa predefinita (08:00 – 12:00 – 17:00).

**Prenotare in anticipo.** La forma possibile di una finestra dipende dalla granularità dello spazio (§8 Disponibilità): Dal #1000 la riga nomina il suo mese — «Settembre 100 %» — così ogni fattura si legge come il mese a cui si riferisce.

| Chiedi | Mezze giornate | Giornate intere | Griglia di minuti (5/15/30/60 min) | Orari reali / orari liberi |
|---|---|---|---|---|
| La mattina (8–12) | ✅ | ❌ — deve coprire la giornata intera | ✅ se i bordi cadono sulla griglia | ✅ |
| Il pomeriggio (12–17) | ✅ | ❌ | ✅ | ✅ |
| Tutta la giornata lavorativa (8–17) | ✅ | ✅ | ✅ | ✅ |
| Una finestra atipica (9–15) | ❌ | ❌ | ✅ se sulla griglia | ✅ |
| Prima dell'apertura / fuori orario (inizio alle 6:00, 17–21) | solo come arrivo spontaneo | solo come arrivo spontaneo | ✅ — le griglie sono a orari liberi | ✅ |
| Fuori griglia (10:02) | — | — | ❌ — il rifiuto nomina la griglia | — |

L'ultima riga della tabella è l'unica che una granularità possa escludere per forma; tutto il resto di una finestra è deciso da regole che valgono **su ogni granularità allo stesso modo**:

- Il futuro è aperto fino all'**orizzonte di prenotazione** (90 giorni predefiniti) e rifiutato oltre.
- La **durata minima e massima** valgono ovunque, non solo sulle griglie: con il minimo predefinito di 30 minuti, un arrivo spontaneo a mezza giornata iniziato alle 11:45 per il limite delle 12:00 viene rifiutato perché troppo corto — arriva prima, o prendi il pomeriggio.
- **Una prenotazione finisce nel giorno in cui inizia.** Nessuna finestra può attraversare la mezzanotte, qualunque sia la granularità: una serata che prosegue diventa la prenotazione di domani, creata domani. Il rifiuto recita *«una prenotazione termina il giorno in cui inizia — prenota il giorno dopo separatamente»*. L'arrivo spontaneo serale che corre fino alla **mezzanotte locale** resta invece legittimo — la mezzanotte è la fine propria di quel giorno, non un attraversamento. È proprio perché ogni prenotazione sta dentro un solo giorno che occupazione, quota e conto di quel giorno si possono chiudere su quel giorno soltanto.
- Una prenotazione in un **giorno già terminato** (ieri e prima) viene rifiutata — *«interamente nel passato»* — a meno che il proprietario non abbia attivato **Consenti prenotazioni passate**. Prenotare la finestra di stamattina più tardi lo stesso giorno funziona sempre.
- Un **check-in spontaneo deve iniziare oggi**: creare per domani una prenotazione già con check-in viene rifiutato.
- Un **giorno di chiusura** rifiuta nominandosi; una postazione occupata rifiuta; e un membro tiene solo tante prenotazioni **sovrapposte** quante gliene concede la sua quota (sotto).
- La regola **Fuori dagli orari di apertura** (§8) decide quanto vale una finestra che esce dalla giornata lavorativa, o se possa esistere affatto (sotto).

Tutto questo è applicato in **un unico punto condiviso sul server**: è per questo che la piantina, l'hub Prenota, una scansione QR o NFC e il chiosco a parete offrono esattamente ciò che sarà accettato, ed è per questo che il chiosco rifiuta esattamente ciò che rifiuta la piantina — non esiste la scorciatoia «ma il chiosco me l'ha lasciato fare». Una richiesta che sfuggisse da una schermata non aggiornata viene rifiutata con il motivo indicato.

**Prima che tu chieda, l'app te lo dice (#814).** Ognuna di quelle regole è rispecchiata sul dispositivo dal **controllo prenotazione** (Funzionalità → *Controllo prenotazione*, sotto *Regole di prenotazione*, attivo per impostazione predefinita): il tocco sul piano, i tocchi su una fascia libera delle viste Giorno e Settimana, il foglio di prenotazione, il foglio unico del chiosco e il foglio di scansione QR/NFC verificano la fascia contro i parametri di disponibilità **prima** di offrirla, e nominano lo stesso motivo del server — *chiuso quel giorno*, *interamente nel passato*, *troppo lontano — le prenotazioni sono aperte con N giorni di anticipo*, *troppo breve*, *troppo lunga*, *una prenotazione termina il giorno in cui inizia*, *fuori dall'orario di apertura*. Una fascia rifiutata disattiva **Prenota** con il motivo sotto il periodo; al chiosco il badge semplicemente non è accettato per essa, e il foglio di scansione rifiuta un giorno chiuso subito, esattamente come il chiosco. Le **viste Giorno, Settimana e Mese** disegnano i giorni chiusi come chiusi — colonne attenuate, nessun tocco su fasce libere, *Chiuso* al posto del conteggio dei posti liberi — e una **legenda** sotto i controlli nomina gli stati dei posti (*Libera · Prenotata · Con check-in · Mia · Bloccata · Giorno chiuso*). Dove il proprietario ha attivato **Gli admin possono fare il check-out dei membri**, il foglio di un admin su un posto occupato offre **Check-out di {name}**. Nel browser, che non ha uno scanner con fotocamera, i fogli di scansione e chiosco lo dicono e rimandano al codice digitato e al tag NFC.

**Quanti posti alla volta.** Lo spazio fissa un numero di **prenotazioni simultanee** (§8); vale **1** per impostazione predefinita — esattamente lo storico un posto alla volta. Un proprietario o un admin può concedere a un singolo membro una quota superiore in *Membri e piani*, e quel permesso personale prevale sul numero dello spazio; nessuno fissa il proprio. La stessa quota governa i **check-in**: chi è autorizzato a 2 posti può risultare in check-in su 2 posti insieme. Raggiungere la quota rifiuta con il messaggio di sempre — *hai già una prenotazione in quel periodo*, oppure *già in check-in altrove*.

**Fuori dagli orari di apertura.** Una finestra che esce dalla giornata lavorativa — una mattina presto 6:00–8:00, una sera 17:00–21:00, lo straordinario spontaneo che corre fino alla mezzanotte locale — è governata da un'unica regola dello spazio con **quattro** risposte mutuamente esclusive (§8), le stesse su ogni granularità.

| Posizione | Una prenotazione (o un check-in spontaneo) fuori orario |
|---|---|
| **Vietato** | ❌ rifiutata su ogni granularità — compreso lo straordinario serale che le granularità a giornate permettono invece sempre, e compresa una prenotazione che semplicemente **sfora** la fine della giornata (16:00–20:00) o inizia prima dell'apertura |
| **Solo spontaneo** | ✅ il check-in spontaneo, a **entrambi i bordi della giornata** — l'arrivo delle 6:00 tanto quanto lo straordinario serale fino a mezzanotte — ❌ prenotare quella finestra **in anticipo**, e ❌ una prenotazione che sfora la fine della giornata |
| **Gratis** | ✅ permessa, ma mai contata né fatturata: la prenotazione è pura informazione — gli altri vedono che lo spazio è preso, e un check-in dice dove trovare la persona |
| **A pagamento** (il predefinito) | ✅ permessa e contata come uso ordinario — **salvo** in un giorno in cui tieni già una prenotazione regolare dentro gli orari: la parte fuori orario viaggia allora gratis |

Quell'esenzione è il senso del predefinito: toglie il «prenoto solo fuori orario per non pagare» senza far pagare due volte chi la sua giornata l'ha già consumata. Due precisazioni. **Gratis e A pagamento guardano solo le finestre che stanno *interamente* fuori orario**: una prenotazione che tocca gli orari di lavoro, anche solo di un minuto, è una prenotazione ordinaria e contata. **Vietato e Solo spontaneo rifiutano più largamente**: rifiutano anche la finestra che sfora, perché uno spazio che chiude alle 17:00 non ha motivo di essere prenotato fino alle 18:00. In *Solo spontaneo* è confluito il ritirato interruttore **Prenotazioni al minuto negli orari di lavoro** — stessa idea, ora su ogni granularità. Uno spazio che porta ancora il vecchio interruttore legge *Solo spontaneo*, con un miglioramento deliberato: il vecchio interruttore lasciava passare solo l'arrivo *serale*, mentre una modalità che si chiama «spontaneo» non ha motivo di respingere chi arriva alle 6:00. Ciò che rifiuta è prenotare in anticipo; presentarsi di persona e mettersi a lavorare è esattamente ciò per cui esiste. Le regole di forma della granularità continuano ad applicarsi sopra, quindi questo non apre nessuna finestra arbitraria.

**Gli arrivi spontanei si agganciano allo slot.** Un arrivo spontaneo (toccare una postazione libera, scansionare il suo QR/NFC, o il chiosco) prenota da *adesso* fino a un bordo canonico — il limite di mezza giornata, la fine della giornata o un bordo della griglia. Con la granularità a giornate, la prenotazione copre l'**intero slot a cui appartiene la fine**: arrivare alle 10:00 e scegliere *fino alle 12:00* prenota tutta la mattina 8:00–12:00; quando la finestra così riportata indietro risulta non disponibile — la prenotazione di qualcun altro, una tua che si sovrappone, un posto bloccato, un tavolo/ufficio/piano intero già preso — la prenotazione si ancora invece al tuo arrivo, conservando la fine dello slot. Alla fine della giornata lavorativa o dopo, un arrivo spontaneo può correre fino alla **mezzanotte locale** (straordinario serale — su ogni granularità, a meno che **Fuori dagli orari di apertura** sia su *Vietato*, l'unica regola che lo rifiuta); lì si ferma, perché una prenotazione finisce nel giorno in cui inizia. E un check-in spontaneo deve iniziare **oggi**: creare una prenotazione «con check-in» per domani viene rifiutato.

**Una scansione si comporta come il chiosco.** Scansionare una **postazione** — la sua scheda QR stampata o il tag NFC sulla sedia — apre la stessa identica scheda che il chiosco apre quando quella postazione viene toccata: **Check-in**, **Prenota** o **Check-out**, sugli stessi periodi dedotti dalle impostazioni dello spazio, senza il passaggio del badge, perché hai già effettuato l'accesso. (Le schede QR di tavolo, ufficio e piano aprono invece la scheda di spazio intero, §4a; i tag NFC portano solo a una postazione.) Da lì decide lo spazio:

| Cosa scansioni | Cosa fa la scheda |
|---|---|
| Uno spazio su cui tieni una prenotazione | prosegue con il check-in di **quella** prenotazione |
| Uno spazio libero | il check-in lo prenota implicitamente, agganciato allo slot come ogni arrivo spontaneo |
| Uno spazio bloccato dalla prenotazione di un altro | nomina il titolare e propone **Scrivigli** — la conversazione si apre con in riferimento la prenotazione che blocca |

La stessa azione *scrivere al titolare* si trova nella scheda **Piantina** quando tocchi una postazione occupata da qualcun altro. Al chiosco è invece la ricevuta a nominare il titolare e a rimandarti all'app: un dispositivo a muro non invia mai messaggi al posto tuo.

**Fare check-in.** Con mezze giornate, giornate intere e orari reali la finestra apre per l'**intera giornata prenotata**: alle 10:00 puoi già fare check-in sul tuo pomeriggio delle 12:00, perché lo slot *è* la giornata lavorativa. Su una griglia di minuti apre **15 minuti prima** del tuo inizio — o un **passo di griglia** prima, se quel passo è più lungo, così le griglie da 5, 15 e 30 minuti mantengono i 15 minuti e una griglia oraria apre un'ora intera prima. La scheda legge sempre l'orologio reale, quindi sfogliare una data futura non nasconde mai il check-in di oggi su una tua prenotazione. Fare check-in in un altro giorno («la prenotazione di domani oggi»), dopo la fine della prenotazione, due volte, o in un giorno di chiusura viene rifiutato con il motivo. Se sei ancora in check-in **altrove**: una prenotazione ancora in corso lo blocca non appena hai raggiunto la tua quota (1 per impostazione predefinita, quindi la prima prenotazione in corso già blocca — *fai prima il check-out lì*); una già terminata si chiude in silenzio — timbrata alla propria fine — e il nuovo check-in procede. Un admin può fare il check-in di un membro finché *Prenota per altri* è attivo (§8 Funzionalità).

**Fare check-out.** Fare check-out prima della fine prenotata **accorcia la prenotazione ad adesso** — la postazione si libera subito per tutti. Dopo un check-in anticipato lo stesso giorno, il check-out prima dell'inizio prenotato conserva la **presenza reale** (dall'istante del check-in ad adesso). Dimenticato e tornato più tardi? Il check-out funziona ancora: la fine prenotata resta, il timbro è veritiero. Fare check-out senza check-in — o due volte — viene rifiutato. Per impostazione predefinita il **check-out è personale**: un admin può terminare il check-in in corso di un membro solo se il proprietario ha attivato **Gli amministratori possono fare il check-out dei membri** (§8). Un check-in mai chiuso si completa da solo appena fai check-in altrove dopo la sua fine — o, con il **check-in/out automatico**, alla pulizia successiva.

**Assenze.** Una prenotazione mai passata dal check-in resta semplicemente *prenotata* nello storico. Con il **check-in/out automatico**, la pulizia segna la finestra passata come frequentata — check-in all'inizio, check-out alla fine, completata. La pulizia è **pigra**: gira a ogni lettura invece che a un'ora fissa, quindi una prenotazione della mattina che nessuno ha toccato è già sistemata quando qualcuno apre la piantina alle 12:01.

**Annullare.**

| Caso | Cosa succede |
|---|---|
| Una tua prenotazione futura | ✅ annullata con un tocco |
| La tua prenotazione in corso, con check-in | ❌ nessun annullamento diretto — la scheda offre invece **Richiedi eliminazione** (§4) e **Terminare prima** (sotto), perché la presenza è già avvenuta |
| Restituire il resto della giornata | ✅ **Terminare prima** su una prenotazione in corso: con mezze giornate e giornate intere sposta la fine al limite di mezza giornata finché questo è ancora davanti; sulle griglie apre un selettore agganciato alla griglia che rifiuta qualsiasi orario non successivo ad adesso. L'inizio è immutabile, e il tempo liberato è subito prenotabile da altri |
| Una prenotazione completata o già annullata | ❌ non resta nulla da annullare |
| La prenotazione di qualcun altro | ❌ per un membro; ✅ per un admin/proprietario — la rimozione d'autorità (§4), attribuita all'admin nel flusso eventi |
| Una serie, «questa e le seguenti» | ✅ annulla le occorrenze *prenotate* rimanenti da quella data; quelle con check-in e completate conservano il loro storico |
| Una prenotazione **passata o con check-in** che vuoi rimuovere | una **richiesta di eliminazione** (§4): un validatore conferma (rimossa) o respinge (conservata); una nuova richiesta sostituisce quella in sospeso, e le prenotazioni future si annullano direttamente |

**Approvazioni.** Dove il proprietario ha posto una regola di validazione sulle **prenotazioni di spazi interi** (§7), la prenotazione blocca subito lo spazio e attende il quorum — un rifiuto la annulla; nessuna regola, nessun passaggio di approvazione. Le richieste di eliminazione seguono lo stesso quadro. **Nessuno valida il proprio evento** — con un'eccezione che il proprietario attiva deliberatamente: nelle regole di validazione (§7), due interruttori indipendenti lasciano che gli **admin** e/o i **proprietari** risolvano subito *le proprie* richieste di **eliminazione di prenotazione**, senza attendere un validatore. Entrambi sono **disattivati per impostazione predefinita**, arrivano soltanto alle eliminazioni di prenotazione, e un'eliminazione risolta automaticamente resta segnata come tale nel flusso eventi — sempre distinguibile da una vagliata da altri.

#### Il foglio di prenotazione

Ciò che si apre quando tocchi un posto libero: la finestra, se ti
registri subito, e per un amministratore, per chi è. Il foglio propone
soltanto — ogni regola la verifica il server alla conferma, così un
posto preso un secondo prima viene rifiutato qui anziché prenotato due
volte.

## 5. Calendario (scheda Calendario)

Il mese a colpo d'occhio, con due ambiti e due forme:

**Il calendario è un selettore, non un palcoscenico (#718).** Scegli un **giorno** o un **periodo**; vedi un unico flusso di tutto ciò che ha una data e che puoi vedere — prenotazioni, check-in e check-out, avvisi, messaggi, fatture, pagamenti, consumi, promemoria — raggruppato per giorno, filtrato per tipo con i chip, e **ogni riga apre la sua origine** (la prenotazione, la conversazione, l'avviso, la fattura, il mese in Finanze). Chi ha il permesso finanze o amministrazione membri può guardare un altro membro; i tipi che il server non consente per quel membro appaiono **bloccati**, mai come un giorno vuoto. Lo scudo apre *Chi può vedere questo*, con il registro degli accessi.

**Tre viste (#818).** Con *Viste del calendario* attiva (predefinita), la scheda si apre sull'**Agenda** — tutto ciò che è datato nei **prossimi 30 giorni**, raggruppato sotto intestazioni *Oggi · Domani · giorno della settimana*, le frecce avanzano di 30 giorni e **Oggi** riporta al presente. **Settimana** mostra una striscia di sette pillole (giorno, numero, indicatori colorati, conteggio) con il feed dell'intera settimana sotto; **Mese** una griglia compatta in cui ogni giorno porta fino a tre **indicatori** — *prenotazioni e presenza*, *avvisi e messaggi*, *finanze* — oggi cerchiato, il giorno scelto pieno, i **giorni chiusi** attenuati e barrati; tocca un giorno per leggerlo sotto (la legenda sotto la griglia nomina i colori). Un giorno chiuso lo dice nel feed, con il motivo della chiusura. Il feed porta inoltre due fatti finora assenti: la **scadenza di pagamento** di ogni fattura aperta (data di emissione + termine di sollecito) e ogni **spesa programmata** in scadenza. Le chip di tipo e il selettore del membro restringono la richiesta come prima; lo scudo apre *Chi può vedere questo*. Disattivata, resta il semplice selettore giorno o intervallo.

- **Le mie / Tutti** — le tue prenotazioni, o quelle dell'intera comunità; l'interruttore ce l'ha ogni membro, dato che la piantina e la griglia settimanale dell'hub Prenota mostrano già l'occupazione di tutti. I puntini sotto un giorno dicono tutto a colpo d'occhio: **rosso** = hai una prenotazione, **blu** = ce l'hanno altri membri, **entrambi i puntini** = tutte e due. Oggi è cerchiato.
- L'**interruttore di forma** accanto commuta la metà inferiore tra una **vista elenco** (ogni prenotazione come scheda: finestra oraria, membro, spazio) e una **vista cronologia** (posti × le ore del giorno selezionato). La griglia posti × *giorni* della settimana vive nell'hub Prenota (§4), non qui.
- I **chip di piano** (*Tutti i piani* / per livello) filtrano la **cronologia**.
- Tocca un giorno nella griglia del mese per caricarlo sotto. In orizzontale, calendario e dettaglio usano il layout diviso.

![](assets/help/images/calendar-agenda.jpg)

*La scheda Calendario: un giorno o un intervallo, i chip per tipo, un unico feed raggruppato per giorno — ogni riga apre la sua origine.*

## 6. Elenco dei membri (scheda Membri)

![](assets/help/images/member-profile-sheet.jpg)

*Il profilo di un membro: la prenotazione di oggi, i contatti e — dove hai il diritto di vederla — la sua posizione finanziaria.*

**Tocca un membro per il suo profilo (#704).** Foto, ruolo e stato; che cosa ha prenotato e se ha fatto il check-in in questo momento; e **Contatti** — il numero WhatsApp condiviso volontariamente per tutti, l'**indirizzo e-mail e la quota di piano per gli admin**. Dove hai il diritto di vedere le cifre — **le tue sempre, quelle di un altro con il permesso *Vedere le finanze*** — il profilo porta anche **Finanze**: la posizione netta (chi deve che cosa a chi), le fatture aperte con quanto resta su ciascuna, i pagamenti già arrivati e il mese in corso. La stessa scheda della scheda Finanze, così le due non possono contraddirsi.

**Una pagina per membro (#825).** Toccare un membro apre ora una **pagina intera**: la foto con il punto di presenza, i chip di ruolo, la propria riga di stato, **quando è stato visto l'ultima volta** («Visto 20 h fa», non un numero nudo) e da quando è membro. Una scheda **In questo momento** dice in una frase se ha fatto il check-in, se ha una prenotazione in questo minuto o quando cade la **prossima** prenotazione: toccala, o qualsiasi riga in arrivo, per aprire quella prenotazione. Sotto, le **azioni rapide**: Messaggi, WhatsApp e (per gli admin) e-mail, più *Aggiungi un servizio* e *Invia l'accordo finanziario* dove si applicano. Le schede contatto e finanze seguono invariate. **Admin e proprietari** trovano nella stessa pagina la sezione **Gestisci**: *Iscrizione* (approva o rifiuta, sospendi, ruolo, comproprietà, chiosco), *Regole di prenotazione* (limite di prenotazioni, prenotazioni simultanee, piano intero come interruttore), *Fatturazione* (abbonamento, quando i giorni finiscono, negoziazioni) e *Badge e accesso*; ogni riga mostra il suo **valore attuale**, nulla va aperto per essere saputo. Le righe di *Impostazioni → Membri e piani* aprono la stessa pagina.

Guarda chi fa parte della tua comunità:

- Ogni scheda membro mostra la **foto** (o l'iniziale), il **chip di ruolo** (Admin, Proprietario), lo **stato personalizzato** («a Berlino fino a venerdì…»), un indicatore **online / ultimo accesso** (*Online*, *10 min*, *2 g*) e un **chip di prenotazione**: posto con check-in, *Prenotato adesso*, o la prossima prenotazione in arrivo.
- Tocca un membro per la sua **scheda di dettaglio** — ruolo, presenza, le sue **prossime prenotazioni** e **Messaggi**.
- **Messaggi**: un **filo di conversazione** per membro (fino a 500 caratteri per messaggio) — aprilo dalla scheda **Messaggi** (§16), dalla scheda del membro o dal suo profilo nell'elenco, leggi tutto lo scambio a fumetti e invia dallo stesso posto. Ogni messaggio raggiunge l'altra parte per due vie: un **push che non trasporta alcun contenuto** (*«Hai un nuovo messaggio»* — per scelta di privacy) e, ad app avviata, una notifica locale che mostra invece il tuo nome e il tuo testo.). Il testo completo resta sempre leggibile nella scheda **Messaggi**, per il destinatario e per il mittente (il push in sé non trasporta contenuto, per scelta di privacy). Gli admin hanno un megafono **Notifica tutti gli admin** — in *Membri e piani* (Impostazioni → Amministrazione), non nella scheda Membri, che non ha una barra dell'app propria — e raggiunge tutti gli admin, proprietario incluso. Attivabile/disattivabile con la funzionalità *Notifiche tra membri*. Durante la scrittura, due chip permettono di **collegare una prenotazione o un check-in in corso — tuoi o di un altro membro** — o **uno spazio** (posto, tavolo, stanza o piano) — il riferimento appare come link toccabile da entrambe le parti: un link di prenotazione apre quella prenotazione, un link di spazio apre la scheda di prenotazione dello spazio, ideale per discutere una prenotazione futura.
- L'**icona messaggio** su una scheda scrive a quel membro su **WhatsApp** (se ha condiviso il numero); il **pulsante gruppo** apre il gruppo WhatsApp della tua comunità (impostato dal proprietario).
- Imposta la tua foto, il tuo stato e la visibilità del telefono in **Impostazioni** (§12).
- Gli admin e i proprietari vedono in più l'**email** di ogni membro sotto il nome — i membri normali no: il contatto tra membri resta il numero WhatsApp condiviso volontariamente.

![](assets/help/images/members-directory.jpg)

*L'elenco: foto o iniziale, chip di ruolo, stato, online/ultimo accesso e la prossima prenotazione su ogni scheda.*

## 7. Eventi e conferme (Messaggi → Eventi)

**Dove si trova.** Il flusso è la seconda faccia della scheda **Messaggi**, e la **campanella** in ogni barra dell'app porta dritto lì, con il conteggio di ciò che ti aspetta. Un solo posto tiene gli avvisi: leggerne uno lì è averlo letto ovunque. Con la messaggistica rinnovata la scheda si chiama **Avvisi** e si segna come letta solo finché è la faccia sullo schermo: passarci è leggerla; averla dietro le chat, no.

Il flusso eventi è la traccia di controllo del tuo spazio: prenotazioni create/modificate/cancellate, pagamenti registrati, fatture pagate, spese presentate, richieste di giorni extra, cambi di ruolo, richieste di eliminazione. I membri vedono i propri eventi; admin e proprietari vedono quelli di tutti. I **chip di filtro** (Tutti · Prenotazione · Pagamento · Spesa · …) restringono l'elenco — la tua scelta viene ricordata — e un menu **Raggruppa per** ripiega il feed in gruppi per tipo, giorno o membro (toccare il simbolo del gruppo riporta all'elenco piatto); ogni riga porta la sua icona di stato — una **clessidra** finché in sospeso, una **spunta verde** una volta confermata — e gli eventi di denaro mostrano *chi li ha validati e quando* direttamente sulla riga.

**In attesa della tua conferma:** ogni volta che un admin fa qualcosa *per qualcun altro* — ti prenota un posto, registra il tuo pagamento, retrocede un admin — resta **in sospeso finché non viene confermato**. Le voci in sospeso sono fissate in alto con una ✕ rossa e un pulsante verde **Accetta**, e ricevi una notifica. Le azioni che compi su te stesso non richiedono mai conferma.

**I messaggi si sono spostati.** I messaggi tra membri vivono ora in una scheda **Messaggi** dedicata (§16), non più qui — un messaggio in due posti è uno che puoi segnare come letto in uno e vedere ancora non letto nell'altro. Questo flusso tiene l'unico tipo che non ha una conversazione in cui stare: una **diffusione a tutti gli amministratori**.

**Quorum di validazione:** per le questioni di denaro e i cambi di ruolo il proprietario definisce *chi* deve approvare e *quante* approvazioni servono. **Nessuno valida il proprio evento** — solo un'altra persona può (un'eccezione, configurata dal proprietario, per le eliminazioni di prenotazione, più sotto); dove non esiste un altro validatore, la richiesta semplicemente attende. Dopo 7 giorni senza risposta, ciò che accade dipende da come è rivolta la richiesta. Una richiesta **che hai presentato tu** per te stesso — un'eliminazione, mezze giornate extra, l'annullamento di un saldo — **scade**: nulla di costoso viene mai concesso in silenzio. Qualcosa che un admin **ha fatto per te** — una prenotazione creata o modificata, un pagamento registrato — **si conferma da sé**, perché è già avvenuto e il flusso ti chiedeva solo di prenderne atto; una prenotazione che un admin ha fatto per te viene allora concessa e consuma la tua quota. Un **pagamento fattura** scaduto — abbinamento, rimborso o raggruppamento che nessuno ha deciso in tempo — libera ciò che tratteneva: il pagamento, la nota di credito e le fatture raggruppate tornano dov'erano (#816).

Il proprietario regola tutto questo per **dominio** in **Impostazioni → Regole di validazione** — quattordici schede, una per tipo di evento, ognuna che eredita dalla **regola predefinita** finché non viene modificata: *Regola predefinita, Pagamento, Spesa, Servizio, Mezze giornate extra, Eliminazione prenotazione, Cambio di ruolo, Nuovo membro, Prenotazione, Prenotazioni di spazi interi, Pagamento fattura*, *Annullamento del saldo*, *Negoziazione tariffaria* e *Spesa programmata*. Una regola stabilisce il numero di validazioni richieste, *quali* admin possono validare (tutti, o alcuni nominati) e se il proprietario deve sempre dare l'approvazione finale. La regola **Eliminazione prenotazione** porta due interruttori in più — *gli admin eliminano senza validazione* e *i proprietari eliminano senza validazione*, entrambi **disattivati per impostazione predefinita** — l'unica eccezione, deliberata, al «nessuno valida il proprio evento»: la richiesta di eliminazione dell'interessato si risolve da sola e resta segnata come **auto-validata** nel flusso. Valgono per le eliminazioni di prenotazione e per nient'altro. Dal #982 sei atti in più hanno la loro scheda: **Emissione fattura**, **Annullamento fattura**, **Rimborso**, **Cambio di adesione**, **Cambio di abbonamento** e **Modifica della matrice dei permessi**. Ognuno si applica subito senza regola e attende la decisione appena una regola esiste, esattamente come l'eliminazione di una prenotazione; una regola su un atto di denaro porta anche una **soglia di importo** (*Solo oltre questo importo*), così che «le fatture oltre 500 € richiedono due convalide» sia una regola sola.

![](assets/help/images/validation-rules.jpg)

 

![](assets/help/images/validation-rule-edit.jpg)

*A sinistra: una regola per dominio, che eredita da quella predefinita. A destra: la modifica di una regola — validazioni richieste, validatori autorizzati, approvazione del proprietario.*

![](assets/help/images/messages-events.jpg)

*Il volto Eventi di Messaggi: chip per tipo, Non letti / Letti, e Raggruppa per Tipo · Data · Membro.*

### Regole di validazione, dominio per dominio

Ogni tipo di atto — un'adesione, una prenotazione cancellata, una
fattura stralciata, mezze giornate extra concesse — ha la sua regola che
dice se un umano deve decidere prima che abbia effetto, e chi. Una
decisione è sempre un evento: chi ha deciso, quando e su cosa. Nulla
viene validato in silenzio.

### Validazioni richieste

Quante persone devono confermare prima che l'atto passi. Una è il caso
corrente; due per il denaro. Impostarla oltre il numero di persone che
*possono* validare viene rifiutato: una regola che nessuno può
soddisfare blocca l'atto per sempre.

### Chi può validare

O **qualunque amministratore**, o un elenco nominato che scegli tu. Un
elenco nominato sopravvive a chi diventa amministratore più tardi —
essere amministratore non ti aggiunge in silenzio a un elenco che
qualcuno ha scelto di proposito.

### Serve un proprietario

Almeno una delle conferme deve venire da un proprietario, qualunque cosa
dica il numero. Per i casi in cui il benestare di un amministratore da
solo non deve bastare.

### Un proprietario può confermare la propria richiesta

Spento, la richiesta di un proprietario attende comunque qualcun altro.
Acceso, è sua. È l'interruttore che decide se uno spazio di una sola
persona funziona.

### Una dopo l'altra

Le conferme si raccolgono nell'ordine dell'elenco anziché in ordine
qualunque. Più lento, e la forma giusta quando il secondo lettore deve
vedere la decisione del primo.

### Validare d'ufficio la richiesta di un proprietario

La richiesta è registrata **già chiusa** invece che aperta e poi
confermata — così nessuno viene avvisato di una questione chiusa.
L'evento esiste comunque, marcato come deciso dal sistema, così la
traccia di audit resta intera.

### Validare d'ufficio la richiesta di un amministratore

Lo stesso per gli amministratori, e deliberatamente **indipendente**
dall'interruttore del proprietario: ogni proprietario porta anche il
ruolo di amministratore, quindi un solo interruttore non avrebbe potuto
esprimere «proprietari sì, amministratori no».

## 8. Per i proprietari: editor e impostazioni

L'amministrazione vive in tre sezioni delle **Impostazioni**, e ogni voce appare solo a chi detiene il permesso che richiede (#1307): **Questo spazio** — *Spazio di coworking* (le impostazioni dello spazio), *Disponibilità*, *Fatturazione*, *Servizi*, *Accessori*, *Fatturazione e report* (l'hub di fatturazione con l'editor dei report e le regole di sollecito nell'intestazione), *Sequenze di numerazione*, *Istruzioni di pagamento*, *Regole di convalida* e *Funzionalità*; **Amministrazione** — *Membri e piani*, *Pagamenti online*, *Badge RFID / NFC*, *Sedi* e *ID e QR dello spazio*; **Governance** — *Gestione dei ruoli*, *Distribuzione* e l'ambiente dello spazio (alcune seguono la propria funzionalità: *Accessori*, *Pagamenti online*, *Badge RFID / NFC*…). Una sola regola da conoscere: **la voce di impostazioni di una funzionalità appare solo finché quella funzionalità è attiva** — disattiva *Pagamenti online* in **Funzionalità** e la sua schermata di configurazione scompare con essa (e ritorna quando la riattivi). La voce **Funzionalità** è sempre presente, così puoi sempre riattivare un modulo.

**Creare uno spazio, passo dopo passo (#1303).** L'accoglienza percorre **Nome → Dove → Partire da → Conferma**. *Dove* raccoglie il paese (proposto da questo dispositivo), la valuta, il fuso orario, se lo spazio serve per provare o è reale, e la coppia dev/prod; *Partire da* è la galleria dei modelli. **Indietro** conserva tutto ciò che è stato scritto. *Usa le impostazioni proposte*, già al primo passo, porta direttamente a **Conferma**, che elenca esattamente cosa verrà creato prima di **Crea spazio**. Se un modello non può essere applicato, il passo di conferma offre **Crea senza modello**, così nessuno resta bloccato. Prima di creare qualsiasi cosa, **Conferma** indica anche cosa configura il modello scelto (*Configura: Spazio e pianta, Terminologia…*). Se questo server non può applicare il modello, lo dice lì: **Crea spazio** resta disattivato e viene offerto **Crea senza modello**.

**Paese, valuta, fuso orario (#711).** La scelta del paese copre ora i 32 paesi per cui l'app sa dichiarare le imposte (UE-27, Svizzera, Norvegia, Regno Unito, Stati Uniti e Canada). La valuta è un **selettore** dei codici che l'app sa formattare — ognuno con il simbolo e il giusto numero di decimali: lo yen non ne ha, il dinaro ne ha tre, e ogni importo, fattura e pagamento online lo rispetta. Il fuso è un **elenco con ricerca** delle zone IANA che l'orologio sa installare; un refuso non si salva più. **Un nuovo spazio parte dal paese del tuo dispositivo (#1303):** valuta e fuso orario lo seguono, tutti e tre modificabili prima della creazione — `fr_CH` propone la Svizzera, un telefono in tedesco propone la Germania e ciò che il catalogo non conosce propone la Francia.

### L'editor dello spazio

Apri l'**editor** dalla barra dell'app dell'hub Prenota (icona attrezzi incrociati). La schermata **Editor dello spazio** elenca i tuoi piani — trascina per riordinare, l'**icona livelli** marca un livello *Prenotabile per intero*, il **menu ⋮** rinomina o elimina, **+ Aggiungi un piano** estende l'edificio. Apri un piano per disegnarlo sulla griglia con la barra strumenti in basso — **Seleziona · Ufficio · Tavolo · Posto · Immagine · Cancella**:

- Un **ufficio** riceve un nome, un interruttore facoltativo *Prenotabile per intero* e un **prezzo per mezza giornata**.
- Un **tavolo** riceve un nome, la stessa opzione tavolo-intero e un proprio **prezzo per mezza giornata**.
- Un **posto** riceve un nome, un **orientamento di seduta** (↑ → ↓ ←), un **tipo di sedia** facoltativo, i suoi **accessori** (ognuno può avere un supplemento per mezza giornata) e un interruttore **Bloccato (manutenzione)**. Il suo campo **Tag NFC/RFID** riceve l'UID del tag della sedia in esadecimale — letto con il pulsante tag o digitato — così un tocco sulla sedia risolve questo posto (§4a).
- **Immagine** piazza un'illustrazione ridimensionabile; l'icona foto nella barra dell'app imposta la **foto di sfondo** del livello.
- Eliminare uno spazio che ha una storia alle spalle è una decisione del **proprietario**, e con *Eliminare spazi con cronologia* attivo (il predefinito) funziona senz'altro: le prenotazioni che facevano riferimento a quello spazio ne conservano un'istantanea di testo, e ogni prenotazione ancora aperta su di esso viene annullata automaticamente. Disattiva la funzionalità e uno spazio con prenotazioni future va prima svuotato a mano.

![](assets/help/images/space-editor-floors.jpg)

*L'elenco dei piani dell'editor dello spazio: trascina per riordinare, l'icona livelli marca un livello prenotabile per intero.*

![](assets/help/images/space-editor-canvas.jpg)

*Un piano sulla griglia con la barra strumenti in basso — Seleziona · Ufficio · Tavolo · Posto · Immagine · Cancella.*

![](assets/help/images/space-editor-seat.jpg)

*La scheda di un posto: nome, orientamento di seduta, tipo di sedia, accessori, il campo del tag NFC/RFID e l'interruttore di blocco.*

### ID spazio & QR

I tuoi inviti legati ai ruoli (§2): invito membro = l'ID dello spazio (sostituiscilo con uno memorizzabile, copialo, condividi il QR come PNG), invito admin = codici personali monouso.

![](assets/help/images/workspace-id-qr.jpg)

*ID dello spazio e QR: l'invito membro (QR + ID — copia, cambia, condividi come PNG, invita qualcuno) e la scheda invito admin.*

#### L'identificativo dello spazio

Da quattro a venti lettere o cifre, unico in tutto DesKilo. È insieme il
nome leggibile dello spazio e l'**invito d'ingresso**: chi ce l'ha può
chiedere di unirsi, e ogni adesione attende comunque la conferma di un
amministratore. Cambiarlo ferma il vecchio all'istante — ristampa il QR.

### Disponibilità

#### Giorni di apertura e granularità

- **Giorni di apertura** — chip lun…dom.
- **Granularità di prenotazione** — una tra: *orari liberi*, *griglia di 5 / 15 / 30 / 60 minuti*, *mezze giornate (mattina e pomeriggio)*, *solo giornate intere*, oppure *orari reali* (da–a esatto, con le scorciatoie di mezza/giornata intera).

![](assets/help/images/availability-basics.jpg)

*I giorni di apertura e la scelta della granularità — la forma possibile di una prenotazione comincia qui.*

#### Orari di lavoro

- **Orario di lavoro** — inizio giornata, limite di mezza giornata, fine giornata (predefinito 08:00 / 12:00 / 17:00). Le mezze giornate e le giornate intere ovunque — prenotazioni, check-in e fatturazione — seguono questi orari; con gli *orari reali* imposti anche quante ore vengono fatturate come mezza giornata e come giornata intera.
- **Giorni di chiusura** — eccezioni datate, aggiunte con **+**.

![](assets/help/images/availability-hours.jpg)

*L'orario di lavoro: inizio giornata, limite di mezza giornata, fine giornata — ogni mezza giornata e giornata intera li segue.*

#### Regole di prenotazione

- **Regole di prenotazione** — quattro voci che allentano o stringono le regole del §4b (la sezione segue la funzionalità *Regole di prenotazione*); i due interruttori sono **disattivati per impostazione predefinita**:
  - **Consenti prenotazioni passate** — i membri possono registrare a posteriori una prenotazione già terminata (ieri e prima). Disattivato, tali prenotazioni sono rifiutate; prenotare una finestra precedente dello *stesso giorno* è sempre permesso. Attivalo negli spazi che annotano la presenza a cose fatte.
  - **Gli amministratori possono fare il check-out dei membri** — un admin può terminare il check-in in corso di un membro. Disattivato, il check-out è strettamente personale. Utile dove il personale chiude la sala la sera.
  - **Fuori dagli orari di apertura** — una domanda, quattro risposte mutuamente esclusive, le stesse su ogni granularità: *che cosa è possibile fuori dalla giornata lavorativa?* **Vietato** — niente: né prenotazioni in anticipo, né check-in spontanei, e anche una prenotazione che sfora la fine della giornata (o inizia prima dell'apertura) viene rifiutata. **Solo spontaneo** — il check-in spontaneo resta possibile a **entrambi i bordi della giornata**, l'arrivo mattutino prima dell'apertura tanto quanto lo straordinario serale fino a mezzanotte, mentre prenotare in anticipo fuori dagli orari viene rifiutato; qui è confluito il vecchio interruttore **Prenotazioni al minuto negli orari di lavoro**, e gli spazi che l'avevano attivo leggono così (quell'interruttore permetteva solo l'arrivo serale — la modalità prende il nome dalla spontaneità, non dalla sera, quindi anche l'arrivo mattutino è ammesso). **Gratis** — consentito, mai contato né fatturato (pura informazione di presenza). **A pagamento** (il **predefinito**) — contato come uso ordinario, salvo in un giorno in cui il membro tiene già una prenotazione regolare dentro gli orari: la parte fuori orario viaggia allora gratis.
  - **Prenotazioni simultanee per membro** — quante prenotazioni sovrapposte un membro può tenere, check-in compresi. **1** per impostazione predefinita: un posto alla volta. Un proprietario o un admin può concedere a un singolo membro una quota superiore in *Membri e piani* (mai a sé stesso), e quel permesso personale prevale su questo numero.

![](assets/help/images/availability-outside.jpg)

*La regola fuori dagli orari di apertura: una domanda, quattro risposte mutuamente esclusive — le stesse su ogni granularità.*

#### Limiti di prenotazione

  Subito sotto stanno i **Limiti di prenotazione** — tre numeri che il server ha sempre applicato e che l'app ora sa impostare:

  - **Orizzonte di prenotazione** — quanti giorni prima può iniziare una prenotazione (predefinito **90**); oltre, viene rifiutata dicendolo.
  - **Durata minima** — la prenotazione più breve accettata (predefinito **30 minuti**), su ogni granularità. È esattamente per questo che un arrivo alle 11:45 per il limite delle 12:00 viene rifiutato: troppo corto.
  - **Durata massima** — la più lunga accettata (predefinito **24 ore**). Poiché una prenotazione finisce nel giorno in cui inizia, la giornata intera è il tetto e il selettore non propone nulla oltre.

  Se imposti un minimo superiore al massimo lo schermo lo segnala, perché il server controlla ogni limite per conto suo e si limiterebbe a rifiutare ogni prenotazione senza mai spiegare il motivo.

![](assets/help/images/availability-limits.jpg)

*I limiti di prenotazione — orizzonte di anticipo, durata minima e massima — e i giorni di chiusura lì sotto.*

  I due interruttori di **auto-validazione** — *gli admin eliminano senza validazione*, *i proprietari eliminano senza validazione* — non stanno qui: vivono con le regole di validazione (§7), disattivati per impostazione predefinita, e arrivano soltanto alle eliminazioni di prenotazione.

#### Giorni di apertura

In quali giorni della settimana lo spazio è aperto. Una prenotazione che
tocca un giorno chiuso viene rifiutata con quel motivo, e la piantina
disegna la giornata come chiusa anziché vuota.

#### Granularità

Cosa può essere una prenotazione: **mezza giornata**, **giornata
intera** o uno **slot** su una griglia di N minuti. Una prenotazione che
non cade sulla griglia viene rifiutata e le viene detto il passo, così
nessuno deve indovinarlo.

#### Orario di lavoro

L'inizio e la fine della giornata lavorativa. Insieme alla granularità
decidono cos'è una mezza giornata — l'unità in cui contano ogni
assegnazione, ogni quota e ogni riga di fattura.

#### Giorni di chiusura

Date in cui lo spazio è chiuso qualunque sia il giorno della settimana:
festività, una settimana ad agosto, un giorno per l'idraulico. Una
prenotazione che ne tocca una viene rifiutata e lo dice.

#### Regole di prenotazione

Le regole che il server applica su ogni percorso di creazione — l'app,
un QR scansionato, il chiosco a muro — così che una regola scritta una
volta li leghi tutti e tre.

#### Consentire prenotazioni passate

Spento, una prenotazione interamente nel passato viene rifiutata.
Acceso, è permessa. Una prenotazione retroattiva **dello stesso giorno**
resta lecita in entrambi i casi: chi si è seduto alle nove deve poterlo
dire alle dieci.

#### Gli amministratori possono chiudere la presenza

Permette a un amministratore di terminare la presenza di un'altra
persona. Utile quando un membro se ne va senza chiudere e il posto
resterebbe occupato fino a fine giornata.

#### Fuori dall'orario di apertura

Quattro risposte, ciascuna con la propria frase di rifiuto: **no**
(rifiutato), **solo presenza spontanea** (registrarsi sul posto sì,
prenotare in anticipo no), **libero** o **addebitato** (permesso e
contato). Una prenotazione che sconfina soltanto è trattata come
esterna nei modi severi; la fatturazione conta solo quella *interamente*
fuori.

#### Limiti di prenotazione

L'orizzonte di apertura (quanto in anticipo si può prenotare), la durata
minima e massima di una prenotazione, e quante prenotazioni sovrapposte
un membro può tenere. Ogni rifiuto nomina il limite e il suo valore: il
messaggio è la regola.

### Funzionalità

**Prima i processi** (#1327). La schermata si apre con una scheda per ogni processo aziendale — *Spazio e accesso*, *Fatturazione e pagamenti* e gli altri — invece che con un centinaio di interruttori. Ogni scheda dice il suo stato a parole accanto a un'icona: **Attivo** (ogni funzionalità del processo funziona), **Parziale** (alcune), **Disponibile** (nessuna è ancora attiva) oppure **Da verificare** (una funzionalità è attiva ma attende un prerequisito disattivato). Conta i sottoprocessi attivi e le funzionalità attive, e avvisa quando attivare l'intero processo richiederebbe anche una funzionalità di un altro processo. Tocca una scheda per vederne i sottoprocessi e cosa fa ogni funzionalità; tocca una funzionalità per leggere le dipendenze e la configurazione attuale. Un solo campo di ricerca raggiunge processi, sottoprocessi e funzionalità, e mostra ogni risultato sotto il suo percorso (*Spazio e accesso › Accesso fisico*); i chip **Tutti**, **Attivo**, **Disponibile** e **Da verificare** restringono le schede — un processo parziale conta sia come attivo sia come disponibile. La vista **Interruttori**, sopra l'elenco, conserva ogni interruttore, la loro ricerca e il chip **Modificate**.

![](assets/help/images/features-tree.jpg)

*La vista Interruttori della schermata Funzionalità: ogni modulo con la sua descrizione; una figlia rientrata richiede la madre.*

Attiva o disattiva interi moduli per spazio — ogni interruttore porta la sua descrizione direttamente sullo schermo: scheda Calendario, scheda Eventi, raggruppamento delle notifiche, scheda Finanze, servizi, supplementi accessori, pagamenti online, fatture, gli admin emettono fatture, modello PDF della fattura, solleciti di pagamento (Mahnwesen), gestione dell'IVA, dichiarazioni IVA, invio della fattura elettronica al cliente, esportazione PDF, prenotazione in serie, prenota per altri, notifiche push, gli admin possono bloccare i posti, prenotazioni di tavolo/ufficio e piano, gli admin possono assegnare piani, modalità chiosco, badge RFID/NFC, badge QR, foto dei membri al chiosco, elenco dei membri, integrazione WhatsApp, codici QR degli spazi, tag NFC/RFID delle sedie, foto dei membri sulla piantina, comproprietari, check-in/out automatico, esportazione dati (Excel), orario di lavoro, regole di prenotazione, notifiche tra membri, biblioteca documenti, report dei membri, richieste di eliminazione prenotazioni, gestione dei ruoli, eliminare spazi con cronologia, suggerimenti di aiuto e animazioni dell'interfaccia. Disattivare un modulo rimuove *tutte* le sue schermate e i suoi pulsanti per ogni membro.

L'elenco è **gerarchico**: una funzionalità che ne richiede un'altra compare rientrata sotto di essa con una nota *Richiede…*, ed è in grigio finché la funzionalità madre è disattivata — *Finanze* porta con sé servizi, supplementi accessori, pagamenti online e fatturazione; *Fatture* porta la delega agli admin, il modello PDF, i solleciti di pagamento, la gestione dell'IVA (con le dichiarazioni ancora sotto) e l'invio della fattura elettronica al cliente; *Modalità chiosco* porta tre figlie — badge RFID/NFC, badge QR e foto dei membri al chiosco; le *prenotazioni di tavolo, ufficio e piano* portano *gli admin possono assegnare piani*; *Elenco dei membri* porta l'integrazione WhatsApp; la *scheda Eventi* porta il raggruppamento del feed. Disattivare una funzionalità madre toglie dall'app tutto il suo sottoalbero; la scelta salvata della funzionalità figlia torna intatta quando la madre riappare.

#### Un interruttore di funzionalità

Apri **Processi e dipendenze** da Funzionalità per esplorare ogni processo e le sue capacità. Ogni capacità spiega lo stato salvato, i prerequisiti mancanti e le capacità che la utilizzano, con i rispettivi processi. Viene descritta la configurazione attuale, non la cronologia delle scelte. La chiave tecnica è in una sezione espandibile. (#1328)

Ogni funzionalità è un interruttore. Accendilo e appaiono **tutte** le
sue superfici — la scheda, la linguetta, il pulsante, il collegamento
diretto; spegnilo e non ne resta nessuna, nemmeno un URL nei preferiti.
Ciò che un interruttore non disfa mai è l'aritmetica già applicata: una
fattura emessa con la funzionalità accesa mantiene ciò che dice. Alcuni
interruttori ne richiedono un altro prima, e quello che attende il
genitore lo dice invece di fallire in silenzio.

### Membri e piani

Tocca un membro per aprire la sua **scheda di gestione** — ogni azione per membro in un unico posto: **Invia l'accordo finanziario** (§11d), **Messaggi**, **Aggiungi un servizio** (servizio, quantità, mese di fatturazione → *invia per conferma*), **Abbonamento** (la sua percentuale), **Quando i giorni finiscono** (la politica di consumo extra, §9), **Limite di prenotazioni** (quante prenotazioni **aperte** il membro può tenere in tutto, in qualunque momento cadano), **Prenotazioni simultanee** (quante prenotazioni possono **sovrapporsi nel tempo** — la quota personale che prevale sul numero dello spazio, §4b; sono due limiti diversi, quindi leggi le etichette), **Può prenotare un tavolo, ufficio o piano intero**, **Badge** (§10), **Rendi admin** (validato, §7), **Comproprietà**, **Trasforma in chiosco** — o **Riporta il chiosco a membro** su un account dispositivo —, **Approva l'adesione** o **Rifiuta l'adesione** per un'iscrizione in attesa, e **Sospendi l'iscrizione**. Ogni riga mostra l'**email** del membro sotto il nome.

![](assets/help/images/members-plans-list.jpg)

*Membri e piani: e-mail, quota di piano e chip di ruolo su ogni riga; megafono, aggiunta e filtri nella barra dell'app.*

![](assets/help/images/member-management-sheet.jpg)

 

![](assets/help/images/member-add-service.jpg)

*La scheda di gestione di un membro — ogni azione per membro in un unico posto — e accanto la finestra Aggiungi un servizio: il servizio, la quantità e il mese in cui atterra.*

![](assets/help/images/member-management-sheet-self.jpg)

*La tua scheda è più corta: nessuno si concede diritti da solo (niente righe admin/spazi interi/simultanee su te stesso).*

![](assets/help/images/member-subscription.jpg)

 

![](assets/help/images/member-reservation-limit.jpg)

*Il dialogo dell'abbonamento (la percentuale del membro) e quello del limite di prenotazioni (il tetto alle prenotazioni aperte).*

#### La biblioteca degli spazi

*Impostazioni → Biblioteca degli spazi* (#1120), quando la funzione è
attiva.

**Partire dalla biblioteca.** Cercate per nome, descrizione o etichetta e restringete con i chip delle etichette — le due cose si combinano; una scheda dice cosa dà il modello: la sua pianta in cifre, *con le sue impostazioni* quando viaggiano anche orari, prezzi o regole (#1280). Ogni modello che potete vedere: quello
integrato, quelli pubblici e quelli che qualcuno ha condiviso con il
vostro indirizzo e-mail. *Vedi le modifiche* mostra, gruppo per gruppo, cosa farebbe qui il modello: i gruppi **Nuovo** sono spuntati, quelli che **cambiano ciò che avete** sono proposti ma non spuntati, quelli **già uguali** non hanno nulla da applicare, e un gruppo che **richiede attenzione** dice perché e non si può scegliere. **Applica N modifiche** applica esattamente ciò che è spuntato — mai il modello intero — e prezzi o ruoli chiedono una conferma in più. Applicando una versione più recente di un modello già applicato, ciò che avete cambiato nel frattempo appare come **Personalizzato qui** e non spuntato: un aggiornamento non annulla mai in silenzio una vostra scelta. Livelli, stanze, scrivanie e posti si uniscono **per nome**; non viene mai rimosso ciò che avete già.

**I vostri modelli.** *Salva questo spazio come modello* scatta
un'istantanea della vostra pianta. Prezzi, immagini della pianta e
indirizzo della sede vengono rimossi prima del salvataggio. La scheda chiede **cosa viaggia** — spuntate i gruppi da pubblicare, un modello dei soli orari va benissimo — e dice cosa non lascia **mai** lo spazio (dati bancari, sedi e loro indirizzi, identificativi legali, testi di invito, collegamenti e impaginazione dei documenti) e **quali nomi viaggiano con la pianta**, perché stanze e scrivanie si uniscono per nome e quindi non si possono nascondere. Aggiungete **etichette** perché altri lo trovino (#1280). Ogni modello
è *Solo io* finché non decidete altrimenti: *Le persone che invito* (via
e-mail — l'invito funziona non appena quell'indirizzo accede, senza
rivelare se esiste già un account) oppure *Tutti*, che lo mette in
biblioteca.

**Più di una pianta** (#1276). Un modello porta con sé anche il modo in
cui lo spazio funziona: orari e regole di prenotazione, tariffe, servizi,
pacchetti, accessori, regole di convalida, la matrice dei ruoli,
promemoria, giorni di chiusura, formati di numerazione (mai i contatori),
il lessico e il profilo delle funzioni. Ciò che appartiene solo al vostro
spazio non viaggia mai: le sedi e i loro indirizzi, gli identificativi
legali e la partita IVA, le menzioni legali, i dati bancari, i testi di
invito, i collegamenti e l'impaginazione dei documenti. Il server li
rimuove prima di salvare il modello, qualunque cosa abbia inviato l'app.
Applicare unisce: i giorni di chiusura, i vostri prezzi sulla pianta e
tutto ciò che lo spazio ha già restano al loro posto. Un'eccezione: una scala di commissioni portata dal
modello sostituisce la vostra per intero, perché le sue fasce coprono
insieme 0–100 % e due scale non si possono intrecciare. Salvare di nuovo con lo
stesso nome aggiorna il modello e ne aumenta la versione, e ogni
applicazione viene registrata con ciò che lo spazio conteneva prima. Un
modello creato da un DesKilo più recente che questo server non
comprende viene rifiutato, mai applicato a metà.

Due modelli sono integrati: **A tiny space** (due livelli, otto posti) e **Association de coworking (France)**. Il secondo è ciò di cui un'associazione di coworking francese ha di solito bisogno dal primo giorno: mezze giornate dalle 7 alle 13 e dalle 13 alle 19, dal lunedì al venerdì; le festività dell'anno e del successivo per il paese dello spazio come giorni di chiusura (mai in un mese già fatturato); quote al 50 % e al 100 % da 50 € e 100 €; niente IVA; il francese come lingua dello spazio, con le parole dell'associazione (*Place*, *Étage*, *Réservations*); le convalide nel calendario, con la scheda eventi e l'elenco dei membri disattivati; e due piani pronti da prenotare (#1282). Paese, valuta e fuso orario vengono sempre dall'accoglienza.

Un nuovo spazio inizia sempre con una stanza, qualunque cosa dica questa
funzione: l'accoglienza propone *Partire da* con il modello integrato
selezionato.

#### Quali ambienti dà un invito

Quando il vostro spazio ha un gemello di produzione, il foglio d'invito
pone una domanda: **Dare anche accesso alla produzione?** (#1119)

La persona entra comunque nello spazio di prova. La produzione si
aggiunge sopra, mai al posto — il gemello di prova è dove si prova, e chi
esistesse solo in produzione non potrebbe esservi provato.

Il ruolo decide ancora. Se il ruolo invitato non detiene *Accesso alla
produzione*, l'invito si rifiuta di essere creato e lo dice, invece di
fallire più tardi. Un invito non concede mai ciò che la matrice dei ruoli
nega.

Da attivare in *Impostazioni → Funzionalità → Scegliere gli ambienti su
cui una persona è attivata*; disattivato all'avvio.

#### Come è iniziata l'adesione

Ogni membro porta una riga discreta che dice come è arrivato (#1110):
**Ha fondato questo spazio**, **Si è unito su invito**, oppure **Profilo
creato da un amministratore**.

È un fatto, non uno stato, e non cambia nulla di ciò che una persona può
fare. Un profilo creato da un amministratore e poi consegnato continua a
dirlo dopo il passaggio — la data del passaggio è un'altra cosa.

Chi lo vede: il membro stesso e chi gestisce i membri. Nessun altro. Da
attivare in *Impostazioni → Funzionalità → Come è arrivato ogni membro*;
disattivato all'avvio.

#### L'abbonamento di un membro

La percentuale delle mezze giornate lavorative del mese a cui il membro
ha diritto. Sceglie la fascia tariffaria, e la fascia decide quanto costa
il mese. Un valore negoziato fuori elenco è possibile solo dove lo spazio
lo consente.

#### Quando i giorni finiscono

Cosa succede oltre l'assegnazione, per questo membro: rifiutare altre
prenotazioni, addebitarle al prezzo di eccedenza, o lasciargli comprare
un pacchetto giornaliero. Finché non imposti nulla qui, vale il valore
predefinito dello spazio.

#### Limite di prenotazioni

Quante prenotazioni **aperte** questo membro può tenere in tutto. Limita
la dimensione dell'arretrato, ed è cosa diversa dal limite di
contemporaneità qui sotto.

#### Prenotazioni contemporanee

Quante prenotazioni questo membro può tenere che **si sovrappongono nel
tempo**. Una per impostazione predefinita, ed è ciò che impedisce a
qualcuno di tenere due posti per lo stesso pomeriggio. La propria non la
puoi mai impostare.

#### Trattamento IVA

Cosa fa la controparte dell'imposta: nazionale, impresa
intracomunitaria in inversione contabile, consumatore intracomunitario,
o esportazione. Si deduce dal paese e dalla partita IVA del membro, e
viene congelato su ogni documento all'emissione.

#### Negoziazione di prezzo

Un prezzo concordato con questo membro e diverso dal catalogo. È
registrato come negoziazione anziché digitato sopra la tariffa: il
documento dice ciò che è stato concordato e il catalogo resta vero.

#### Comproprietà

Eleva un membro a comproprietario. Un comproprietario ha i permessi di un
proprietario e conta come tale ovunque una regola ne chieda uno —
compresa la regola per cui l'ultimo proprietario attivo non può essere
rimosso.

#### Le azioni su un membro

Tutto ciò che un amministratore può fare per un membro — abbonamento,
eccedenza, accordo, pausa, limiti, badge, ruolo — raccolto in un solo
foglio, così nulla va cercato su un'altra schermata.

### Fatturazione

- **Fasce tariffarie** — la scala di prezzi dietro gli abbonamenti percentuali: ogni fascia dice *da X %*, *fino a Y %*, il **canone** mensile e la **tariffa extra** per mezza giornata aggiuntiva. **+ Aggiungi una fascia** estende la scala.
- **Livelli di abbonamento** — quali percentuali i membri possono scegliere (chip: 25 % · 50 % · 75 % · 100 %, più i tuoi valori), e un interruttore facoltativo **valore libero negoziato**.
- **Pacchetti di giorni** — un numero di giorni a un prezzo (nome · giorni · prezzo), ognuno con il proprio interruttore di attivazione; i membri con politica a *pacchetti* li acquistano quando i loro giorni finiscono.

![](assets/help/images/billing-tiers.jpg)

*Le fasce tariffarie (da % · fino a % · canone · tariffa extra) e i livelli di abbonamento che i membri possono scegliere.*

![](assets/help/images/billing-packages.jpg)

*I pacchetti di giorni: un numero di giorni a un prezzo, ognuno con il proprio interruttore di attivazione.*

#### Fasce tariffarie

La scala dei prezzi dietro gli abbonamenti a percentuale. Ogni fascia
copre un tratto della scala e dice quanto costa un mese al suo interno.
La tariffa di un membro sceglie una fascia; la fascia decide il canone
e il prezzo dell'eccedenza, mai il contrario.

#### Fino a %

Il tetto della fascia. La successiva comincia dove questa finisce: la
scala non ha buchi né sovrapposizioni, e una percentuale cade sempre in
esattamente una fascia.

#### Canone mensile

Quanto costa un mese in questa fascia, che l'assegnazione sia usata o
no. Porta il proprio gruppo IVA: l'aliquota segue il catalogo invece di
essere digitata qui.

#### Eccedenza

Il prezzo di una mezza giornata oltre l'assegnazione. Lascialo vuoto e
le mezze giornate in più vengono rifiutate anziché addebitate;
compilalo e vengono fatturate a questo prezzo sulla stessa fattura.

#### Livelli di abbonamento

Quali percentuali un membro può scegliere — i chip che vede quando
prende una tariffa. Aggiungi i tuoi valori accanto ai soliti 25 · 50 ·
75 · 100.

#### Valore del livello

Una percentuale, da 1 a 100. È una quota delle mezze giornate
lavorative del mese: per questo l'assegnazione segue il calendario e
non un numero fisso di giorni.

#### Consentire un valore negoziato

Permette a un amministratore di fissare, per un membro, una percentuale
che non è in elenco. Disattivato per impostazione predefinita: un
valore che nessun altro vede è un valore che nessun altro può
verificare.

#### Pacchetti giornalieri

Un numero di giorni venduto a un prezzo, comprato quando i giorni
servono anziché sottoscritto al mese. Ogni pacchetto ha il suo
interruttore: uno vecchio può smettere di essere venduto senza sparire
dalle fatture che lo portano.

#### Nuovo pacchetto

Nome, giorni e prezzo, poi aggiungi. Un pacchetto è acquistabile appena
è attivo.

#### Nome del pacchetto

Ciò che un membro vede in vendita e ciò che dice la riga di fattura.
Rinominalo e cambiano solo i documenti futuri: una fattura emessa
mantiene il nome con cui è stata venduta.

#### Giorni del pacchetto

Quanti giorni concede il pacchetto. Si consumano con l'uso e non
scadono con il mese.

#### Prezzo del pacchetto

Il prezzo dell'intero pacchetto, con il proprio gruppo IVA. La riga di
fattura mostra il prezzo e l'aliquota in vigore il giorno della
vendita.

#### Calendario di fatturazione

Quando il mese viene fatturato. La riga di abbonamento è emessa **prima**
del mese che copre e le righe di consumo la seguono: per questo una
fattura può nominare un mese non ancora avvenuto.

### Servizi e Accessori

I cataloghi dietro il §9 — extra definiti dal proprietario (armadietti, stampe…, ognuno con un prezzo e un'aliquota IVA facoltativa) e dotazioni per posto con supplementi facoltativi per mezza giornata. Entrambi sono semplici elenchi con un pulsante **+**.

![](assets/help/images/services-catalog.jpg)

 

![](assets/help/images/services-new-service.jpg)

*Il catalogo dei servizi e un nuovo servizio — nome, prezzo, la sua aliquota IVA dove il regime la applica.*

![](assets/help/images/accessories-catalog.jpg)

 

![](assets/help/images/accessory-edit-dialog.jpg)

*Il catalogo degli accessori e l'editor di un accessorio — il supplemento si fattura per mezza giornata prenotata.*

**Scorta (#731).** Un servizio nato da una scorta mostra *N in scorta* / *Esaurito*; un consumo superiore allo scaffale viene rifiutato.

#### Un servizio

Tutto ciò che si vende e non è un posto: un'ora di sala riunioni, un
pacchetto di stampe, un armadietto, un abbonamento al caffè. Un servizio
può essere messo in fattura da un amministratore o legato a un
pacchetto.

#### Nome del servizio

Ciò che dice la riga di fattura. Rinominarlo cambia solo i documenti
futuri: una fattura emessa mantiene il nome con cui è stata venduta.

#### Prezzo del servizio

Il prezzo di un'unità, con il proprio gruppo IVA — l'aliquota segue il
catalogo invece di essere digitata qui, così un cambio di aliquota non
torna mai su un documento già emesso.

#### Attivo

Se il servizio può ancora essere venduto. Spegnerlo ferma le vendite
nuove e lascia intatte tutte le fatture che lo portano: è ciò che si
vuole per qualcosa di dismesso, non per qualcosa di sbagliato.

### Impostazioni dello spazio (Spazio di coworking)

La schermata propria dello spazio, dall'alto in basso:

- **Identità** — nome, paese, valuta (proposta dal paese, modificabile), fuso orario, **lingua dello spazio** (gli inviti la usano per impostazione predefinita; *lingua dell'app del mittente* è un'opzione) e l'**indirizzo** postale stampato sulle fatture.

![](assets/help/images/workspace-identity.jpg)

*Identità: il paese propone valuta e fuso orario; la lingua dello spazio scrive gli inviti.*
- **Pagamenti e fatturazione** — le **istruzioni di pagamento** che i membri vedono su un estratto non saldato (IBAN, link PayPal.me, numero di telefono Wero, Lydia, Wisetag, indicazione della causale — lascia un campo vuoto per nasconderlo), e **Identità legale e fatturazione elettronica** (§11a).

![](assets/help/images/workspace-billing-links.jpg)

 

![](assets/help/images/payment-instructions.jpg)

*Pagamenti e fatturazione: le due voci verso le istruzioni di pagamento e l'identità legale — e il modulo delle istruzioni stesso, campo per campo.*
- **Gruppo WhatsApp** — il link del gruppo della comunità mostrato nell'elenco.
- **Messaggio d'invito** — i modelli d'invito per lingua (§2).

![](assets/help/images/workspace-invitation.jpg)

*Il messaggio d'invito per lingua, con i suoi segnaposto, e il cursore della trasparenza dei tavoli lì sotto.*
- **Trasparenza dei tavoli** — il cursore che lascia trasparire una foto di sfondo sotto i tavoli disegnati.
- **Modello PDF della fattura** e **Regole di sollecito** — scorciatoie verso l'editor di report e la configurazione dei solleciti (§11).
- **Esportazioni** — *Esporta lo spazio (XML)* (impostazioni + piantina, nessun dato personale — backup, modello, migrazione di un'istanza), *Esporta la configurazione (PDF)* (un'istantanea completa: impostazioni, membri, piantina), *Report dello spazio* (tutto sullo spazio tramite il modello «spazio» del motore di report), *Codici QR degli spazi (PDF)* (un QR formato carta di credito per postazione, tavolo, ufficio e piano, dieci per A4), *Esporta i dati (Excel)* (una cartella di lavoro: prenotazioni, pagamenti, fatture, membri, piantina — una scheda ciascuno), *Importa lo spazio (XML)* (ripristina impostazioni e piantina; sostituisce la piantina attuale). Ogni esportazione finisce nella cartella **Download** del tuo dispositivo.
- **Tutta la configurazione viaggia (#916)** — con *Configurazione nel file dello spazio* attivo (lo è per impostazione predefinita), *Esporta lo spazio (XML)* porta anche una sezione `<configuration>`: tariffe e pacchetti, aliquote IVA, identità legale e ogni dicitura di fattura, regole di prenotazione e convalida, ruoli, regole di sollecito, layout dei documenti, sedi, giorni di chiusura e collegamenti documentali — più i prezzi della planimetria, le prenotazioni in blocco, i nomi delle sedi e i tag dei posti. *Importa lo spazio (XML)* applica prima quella sezione, anche su uno spazio che ha già prenotazioni; solo la planimetria resta rifiutata quando esistono prenotazioni, e l'importazione lo dice. Mai nel file: il codice d'invito, le credenziali di fattura elettronica e di pagamento, membri, prenotazioni, fatture e pagamenti. Esportare uno spazio, importare il file altrove e riesportare dà lo stesso file, byte per byte.

![](assets/help/images/workspace-exports.jpg)

*Il blocco delle esportazioni — XML, PDF di configurazione, report dello spazio, codici QR degli spazi, Excel, importazione XML — e la zona pericolosa.*
- **Il questionario di configurazione** — <https://fdittgen-png.github.io/deskilo/setup.html> (il §1 lo spiega per esteso): la pagina autonoma che raccoglie un'intera configurazione *prima* che l'app esista. **Importa lo spazio (XML)** qui sopra è dove atterra il suo file — direttamente impostazioni, accessori e piantina; la sezione `<setup>` del file porta fatturazione, identità legale, ruoli e membri per le schermate a cui appartengono.
- **Zona pericolosa** — **Reimposta lo spazio**: elimina tutte le prenotazioni, la contabilità e la piantina; conserva impostazioni e membri. Protetto da una conferma digitata.

#### Paese

Dove l'organizzazione ha sede. Decide la valuta predefinita, il catalogo
di aliquote IVA che ti viene proposto, e la formula di legge che stampa
un venditore esente o fuori campo quando non ne scrivi nessuna.

#### Valuta e fuso orario

La valuta in cui sono espressi ogni prezzo e ogni documento, e il fuso su
cui corre l'orologio dello spazio. **Il fuso non è cosmetico**: una
giornata lavorativa, un confine di mezza giornata e un giorno di chiusura
si contano lì, così un membro all'estero vede la giornata dello spazio e
non la propria.

#### Lingua dello spazio

La lingua che lo spazio parla per impostazione predefinita. Gli inviti
sono scritti in essa, e un documento vi ricade quando chi legge non ha
una lingua propria.

**Non è la lingua della tua applicazione.** Quella si imposta in
*Impostazioni → Lingua*, cambia ciò che **tu** vedi e non riguarda nessun
altro. Questa appartiene allo spazio e cambia ciò che lo spazio **scrive
agli altri**.

#### Indirizzo della carta intestata

L'indirizzo in testo libero che stampa un documento cartaceo. È distinto
dall'**indirizzo strutturato** dell'identità legale, che è ciò che porta
la fattura elettronica — una macchina non sa spezzare una riga in modo
affidabile, e chi legge una lettera preferisce la riga.

#### Gruppo WhatsApp

Il gruppo dove può essere pubblicato un avviso. Facoltativo, e senza
altri effetti: senza di esso un messaggio resta nella posta dell'app.

#### Messaggio di invito

Il testo che un invito porta, per lingua. Scrivilo una volta e ogni
invito in quella lingua lo usa; il codice e il link li aggiunge l'app,
quindi non incollarne mai uno nel testo.

**Lingua del messaggio**, sopra il campo, dice quale dei cinque
brogliacci è a schermo. Non è un'impostazione: nulla di esso viene
salvato, e si apre ogni volta sulla lingua dello spazio.

#### Lessico

Le parole che questo spazio usa al posto di quelle del prodotto.
Rinomina un posto, le etichette della legenda, le schede o le parole
della prenotazione — per lingua — e tutto il resto mantiene la
formulazione del prodotto.

La parola del prodotto resta visibile sotto la tua, così vedi che cosa
stai sostituendo. **Reimposta** rimuove la tua parola invece di salvare
quella del prodotto al suo posto: un termine reimpostato segue il
prodotto quando la sua formulazione cambia in seguito.

I termini sono raggruppati per punto di comparsa, non elencati per
nome — due di essi si leggono *Reserve* in inglese, ed è il gruppo a
distinguerli.

#### Trasparenza dei tavoli

Quanto l'immagine di sfondo traspare sotto un tavolo nella piantina.
Alzala quando la piantina è tracciata su una fotografia e l'arredo conta;
abbassala quando contano più i posti della stanza.

#### Esportare lo spazio (XML)

L'intero spazio in un file: la piantina e — con *Configurazione nel file
dello spazio* attivo — tariffe, aliquote IVA, l'identità legale e tutte
le menzioni di fattura, regole di prenotazione e validazione, ruoli,
regole di sollecito, progettazioni dei documenti, sedi, giorni di
chiusura e collegamenti ai documenti. **Mai nel file:** il codice di
invito, le credenziali di fattura elettronica e di pagamento, i membri,
le prenotazioni, le fatture e i pagamenti.

#### Importare lo spazio (XML)

Applica quel file qui. La sezione di configurazione si applica anche a
uno spazio che ha già prenotazioni; solo la piantina stessa viene
rifiutata quando esistono prenotazioni, e l'importazione lo dice invece
di fallire in silenzio.

#### Esportare la configurazione (PDF)

Ogni parametro dello spazio come documento leggibile, firmabile, da
consegnare a un commercialista. È un'istantanea, non un backup — l'XML è
il file che si reimporta.

#### Report dello spazio

Lo spazio stesso come documento: sedi, piani, posti, tariffe e le regole
in vigore. Utile come allegato a un contratto d'affitto o a una pratica
assicurativa.

#### Codici QR dei posti (PDF)

Un foglio stampabile di codici QR, uno per posto. Attaccali sui tavoli e
un membro può prenotare o registrarsi scansionando il posto davanti al
quale si trova.

#### Esportare i dati (Excel)

I dati operativi — membri, prenotazioni, consumo, fatture, pagamenti —
come foglio di calcolo, per l'analisi che l'app non fa. È
un'esportazione, non un trasferimento: nulla la rilegge.

Arriva come **un unico ZIP** (#1310): `workspace.xlsx`, un `manifest.json`
che indica quante righe contiene ogni scheda, da quale versione dello
schema provengono i dati e uno SHA-256 per file, e `files/` con i file
salvati dello spazio — sfondi e immagini della piantina, immagini dei
report. Ogni tabella viene letta fino alla fine; un'esportazione che non
può essere completa fallisce con un messaggio invece di salvare meno. Gli
account non viaggiano: le persone si riuniscono e rivendicano il proprio
profilo su un altro server.

### Codici QR degli spazi e prenotazioni di spazi interi

Quattro passi trasformano «scansiona il codice sul tavolo» nel flusso di prenotazione quotidiano (§4a):

1. Nell'**editor**, marca un ufficio o un piano come **Prenotabile per intero** e assegnagli un **prezzo per mezza giornata** — la scheda proprietà dell'ufficio, o per un piano l'**icona livelli direttamente sulla sua riga**.
2. Attiva **Prenotazioni di tavolo, ufficio e piano** in **Funzionalità** (disattivata per impostazione predefinita).
3. Concedi a ogni membro autorizzato **«Può prenotare un tavolo, ufficio o piano intero»** — proprietari e admin lo impostano nella scheda di gestione del membro, mai per se stessi. Proprietari e admin hanno il diritto anche senza l'interruttore, nell'app come al **chiosco**.
4. Stampa le schede: **Impostazioni dello spazio → Codici QR degli spazi (PDF)** — ritagliale e attacca ogni scheda sul suo spazio.

Una prenotazione di ufficio copre **tutti i tavoli al suo interno**; una prenotazione di piano copre l'intero piano. Entrambe sono possibili solo finché nulla all'interno è prenotato — e compaiono come righe a sé sulla fattura del membro.

### Comproprietari

Fai in modo che la comunità non dipenda mai da un solo account:

1. Apri *Membri e piani → il membro → **Comproprietà*** e scegli **attivo** (permessi da proprietario subito) o **passivo** (successore in attesa).
2. Passa la mano in qualsiasi momento con ***Promuovi a proprietario ora*** — il comproprietario diventa proprietario a pieno titolo accanto a te.
3. Se l'ultimo proprietario lascia lo spazio, il miglior comproprietario viene **promosso automaticamente** sul server — attivo prima di passivo. Questa rete di sicurezza funziona anche mentre l'interruttore della funzionalità *Comproprietari* è disattivato (l'interruttore nasconde solo i pulsanti di nomina).

### Gestione dei ruoli

Una matrice centrale decide **quale ruolo detiene quale permesso** — gestire i ruoli, gestire i membri, regole di convalida, impostazioni dello spazio, emettere fatture e riconciliare pagamenti, consultare le finanze, documenti, servizi, approvare le spese, consultare e gestire gli accordi commerciali. Aprila in *Impostazioni → Governance → Gestione dei ruoli* (il suo interruttore di funzionalità deve essere attivo):

- Il **proprietario detiene sempre tutti i permessi** — la riga è bloccata.
- Chi detiene *Gestire ruoli e permessi* modifica le altre righe. Un **comproprietario** parte con tutto («un comproprietario può averne meno» — il proprietario toglie ciò che vuole); un **admin** parte con le capacità admin di oggi; un **membro** con nessuna.
- Chiunque altro con un permesso qualsiasi vede la matrice **in sola lettura**, con il proprio ruolo evidenziato.
- Una matrice mai toccata significa i valori predefiniti — nulla cambia finché il proprietario non la modifica. Il vecchio interruttore *gli admin emettono fatture* continua a concedere la fatturazione agli admin per compatibilità. Il server applica la stessa matrice in ogni RPC di fatturazione — emettere, sostituire, annullare, sollecitare, abbinare, rimborsare, cancellare un residuo e raggruppare chiedono tutti `has_permission` (#816) — così l'interfaccia e il database non possono essere in disaccordo; un membro a cui è concesso *emettere fatture* lo usa come un admin.

**Chi convalida (#732).** Una regola indica il suo **ambito**: *Gli admin* (il proprietario e tutti gli admin, o quelli elencati), *Persone designate* (il proprietario ed esattamente le persone scelte — anche un semplice membro può convalidare), o *Tutti i membri*. Numero e firma del proprietario mantengono il loro senso, e nessuno convalida mai il proprio evento. Funzionalità *Convalidatori per ruolo o persona*.

![](assets/help/images/roles-matrix.jpg)

*Gestione dei ruoli: la scheda del proprietario bloccata, quella del comproprietario con tutto concesso per impostazione predefinita — seguono le schede admin e membro con le stesse undici autorizzazioni.*

#### La matrice dei ruoli

I ruoli da un lato, i permessi dall'altro. Ogni casella è un
interruttore, tranne quelle che un proprietario ha sempre. Un permesso è
chiesto al server da una sola funzione: togliere una casella lo toglie
ovunque in una volta — lo schermo nasconde il pulsante, e la chiamata
dietro rifiuta comunque.

### Configurare i pagamenti online

Ogni comunità incassa sul **proprio** account del fornitore; l'app non conserva mai le chiavi segrete su alcun dispositivo — restano sul server.

1. Apri **Impostazioni → Pagamenti online** (solo proprietario).
2. Scegli un fornitore e incolla le sue chiavi dal suo pannello:
   - **PayPal** — Client ID, Secret, Ambiente (inizia con *sandbox*), ID webhook, URL di ritorno (PayPal Developer → la tua app REST).
   - **Carta di credito (Stripe)** — Chiave segreta, Segreto di firma webhook, URL di ritorno (Stripe → chiavi API / Webhook).
   - **Mollie** — Chiave API, URL di ritorno (offre iDEAL, Bancontact, carte…).
   - **Wero (tramite Mollie)** — la stessa chiave API Mollie, con Wero abilitato nel tuo account Mollie.
3. **Salva** — appare un chip verde *Configurato*. Attiva la funzionalità **Pagamenti online** (Impostazioni → Funzionalità) e i membri vedranno **Paga online** su una fattura da saldare. (La voce di impostazioni *Pagamenti online* appare solo finché la funzionalità è attiva.)

![](assets/help/images/online-payments-config.jpg)

*Una scheda per fornitore — qui PayPal; Stripe, Mollie e Wero hanno la stessa forma: chiavi dentro, un chip Configurato in risposta.*

Un segreto salvato non viene più mostrato — lascia il campo vuoto per mantenerlo, digita per sostituirlo, **Rimuovi** per togliere il fornitore. Le commissioni sono del fornitore (tipicamente ~1,5–3 % per pagamento, senza canone mensile); DesKilo non aggiunge nulla, e il bonifico/IBAN manuale resta gratuito.

Se un pagamento non parte, attiva **Impostazioni → Avanzate → Modalità sviluppatore** e apri la schermata **Sviluppatore**: la traccia *pagamenti* mostra esattamente quali fornitori sono configurati e quali campi mancano ancora.

![](assets/help/images/developer-screen.jpg)

#### I pannelli dei fornitori, passo per passo

Tieni **ambienti di test e di produzione rigorosamente separati**: ogni fornitore ha chiavi distinte per modalità, e le chiavi che incolli in DesKilo devono appartenere tutte alla stessa modalità. Negli URL qui sotto, `<project-ref>` è il riferimento del tuo progetto Supabase (chi fa self-hosting usa l'URL della propria istanza).

**PayPal**

1. Accedi su [developer.paypal.com](https://developer.paypal.com) e apri **Apps & Credentials**.
2. Usa l'interruttore **Sandbox / Live** — inizia in *sandbox*; passa a *live* solo per la produzione. Il campo *Ambiente* di DesKilo deve corrispondere alle chiavi.
3. **Crea un'app REST-API** — questo genera il **Client ID** e il **Secret**.
4. Nell'app, aggiungi un **webhook**: URL `https://<project-ref>.supabase.co/functions/v1/paypal-webhook`, iscritto almeno a *Payment capture completed* (più *denied* / *order voided*). Copia il **Webhook ID**. In DesKilo il webhook non è opzionale — è il modo in cui un pagamento viene registrato sulla fattura.
5. Incolla Client ID, Secret, Ambiente, Webhook ID e il tuo URL di ritorno in **Impostazioni → Pagamenti online → PayPal**. Nulla viene salvato nell'app o su alcun dispositivo — tutto va al server.

**Stripe (carte di credito e Cartes Bancaires)**

1. Accedi su [dashboard.stripe.com](https://dashboard.stripe.com) e apri **Developers**.
2. L'interruttore **Test mode / Live mode** decide quali chiavi vedi. A DesKilo serve solo la **Secret key** — il checkout viene creato lato server, quindi la chiave *publishable* non serve.
3. Sotto **Settings → Payment methods**, abilita i circuiti di carte che vuoi. **Punti alla Francia? Abilita esplicitamente Cartes Bancaires** — i membri francesi spesso preferiscono CB all'instradamento internazionale Visa/Mastercard.
4. Sotto **Developers → Webhooks**, aggiungi l'endpoint `https://<project-ref>.supabase.co/functions/v1/stripe-webhook` con l'evento `checkout.session.completed` e copia il **Webhook signing secret**.
5. Incolla la Secret key, il signing secret e il tuo URL di ritorno in **Impostazioni → Pagamenti online → Carta di credito (Stripe)**.

**Mollie (iDEAL, Bancontact, Wero…)**

1. Accedi su [my.mollie.com](https://my.mollie.com) → **Developers → API keys** e copia la **API key Test o Live** (la modalità è codificata nella chiave stessa).
2. Sotto **Settings → Payment methods**, abilita ciò che i tuoi membri devono vedere: **iDEAL** (Paesi Bassi), **Bancontact** (Belgio), carte — e **Wero**, il wallet della European Payments Initiative per pagamenti istantanei da conto a conto in Germania, Francia e Belgio (il successore di Paylib e giropay).
3. In DesKilo, **Mollie** e **Wero** sono due schede fornitore che condividono la stessa API key — un pagamento Wero viene creato come pagamento Mollie con il metodo Wero. Configura quelli che vuoi mostrare ai membri.
4. Gli URL di redirect e di webhook vengono impostati **automaticamente da DesKilo** a ogni pagamento (redirect = il tuo URL di ritorno, webhook = la funzione `mollie-webhook`) — nulla da configurare nel pannello Mollie.

#### Altri metodi di pagamento (prospettive)

| Fornitore / metodo | Focus | Come si inserisce in DesKilo |
|---|---|---|
| **Apple Pay / Google Pay** | Wallet mobili, checkout con un tocco | Abilitali nel tuo pannello Stripe (o Mollie) — compaiono automaticamente sulla pagina di pagamento ospitata, senza modifiche a DesKilo e senza costi base aggiuntivi. |
| **Klarna** | Compra ora, paga dopo | Lo stesso: attivalo in Stripe/Mollie e compare al checkout — rilevante per gli importi più alti. |
| **Adyen** | Enterprise e omnicanale, una sola API per quasi ogni metodo | Non integrato — sarebbe un nuovo fornitore in DesKilo (contributi benvenuti). |
| **Braintree** | Drop-in UI per mobile e web (di proprietà di PayPal) | Non integrato — l'integrazione PayPal diretta di DesKilo copre già quel terreno. |

#### Il fornitore di pagamento

Quale servizio incassa — PayPal, Stripe, Mollie o Wero tramite Mollie.
Una sonda riporta quali fornitori sono pronti e quali campi mancano
ancora: lo scopri qui invece che da un pagamento fallito.

#### Credenziali del fornitore

Le chiavi che il fornitore ti ha rilasciato. Sono **solo in scrittura**:
puoi sostituire un campo o cancellare un fornitore, ma i valori non
vengono più mostrati, né a te né a nessun client — lo schermo rilegge
solo i nomi delle chiavi. Lascia un campo vuoto per conservare ciò che è
salvato. Vivono sullo spazio e non entrano mai in un file di spazio né in
una distribuzione.

#### Modalità di pagamento

Quali modi di pagare lo spazio accetta e come si chiama ciascuno su un
documento — bonifico, carta, contanti, assegno. L'etichetta è ciò che
stampano una fattura e una ricevuta.

### Configurare i badge RFID / NFC

Le tessere fisiche permettono il check-in con un tocco — senza telefono.

1. Apri **Impostazioni → Badge RFID / NFC** (solo proprietario). Attiva **Abilita il check-in con badge NFC** e leggi la riga di **stato del dispositivo** — distingue *pronto*, *NFC disattivato nelle impostazioni Android* e *nessun hardware NFC*. I telefoni e i tablet Android dotati di NFC, e gli **iPhone**, sanno leggere un tag; gli iPad non hanno alcun hardware NFC.
2. Dai una tessera a ogni membro: **Membri e piani → il membro → Badge → Registra tessera**, poi avvicina la sua tessera al dispositivo. Va bene qualsiasi tessera con chip leggibile (MIFARE, NTAG…). I membri possono farlo anche **da soli**: **Impostazioni → Il mio badge** emette il loro badge QR stampabile e registra la loro tessera — senza bisogno di un admin.
3. Usale a un **chiosco** (§10): il membro avvicina la tessera per prenotare o fare check-in. Revoca una tessera persa dalla stessa finestra Badge; **scorri un badge revocato verso destra per eliminarlo** definitivamente (dopo conferma).

I badge appartengono a **un solo spazio** — la finestra indica in quale stai registrando, quindi registra la tessera nello spazio il cui chiosco la leggerà. La stessa tessera fisica può servirti in più spazi. Un badge QR salvato **come PDF** stampa dieci copie formato carta di credito su una pagina A4 — scorte incluse.

![](assets/help/images/nfc-config.jpg)

*Passo 1 — l'interruttore NFC e la riga di stato del dispositivo, che dice se questo dispositivo sa leggere una tessera.*

![](assets/help/images/member-badges-dialog.jpg)

*Passo 2 — i badge di un membro: badge QR e tessera registrata, ciascuno con la sua revoca e il proprio interruttore «mi connette».*

![](assets/help/images/my-badge-code.jpg)

*Self-service: Impostazioni → Il mio badge emette il badge QR stampabile; il codice badge lo imposti solo tu.*

## 9. Denaro (scheda Finanze)

Il tuo conto risponde a *quanto devo, quanto mi devono* — e *quanto posso ancora prenotare*. In verticale l'estratto del mese scorre sopra i pulsanti d'azione; in orizzontale le azioni passano in un pannello laterale e l'estratto riempie il resto. L'intestazione **‹ mese ›** sfoglia qualsiasi mese; il **pulsante PDF** esporta l'estratto visibile (§ sotto).

**L'estratto, scheda per scheda:**

- **Questo mese** — quanti **giorni** include il tuo abbonamento questo mese, quanti ne hai **usati**, quanti ne **restano**, con barra di avanzamento. Una mattina prenotata conta 0,5 giorni — a meno che stia interamente fuori dagli orari di lavoro e la regola fuori-orario dello spazio la renda gratuita o esente (§4b): la stessa identica regola guida qui la quota e sull'estratto l'importo. Il diritto mensile segue i giorni di apertura dello spazio e la tua percentuale — la scheda dell'abbonamento sotto lo spiega per esteso (*3 mezze giornate usate su 42, 21 giorni di apertura*).
- **Eccedenza** — le mezze giornate oltre il tuo piano, alla tariffa extra della tua fascia.
- **Servizi consumati** — ogni consumo di servizio con il totale dei servizi.
- **Supplementi accessori** — gli extra per mezza giornata legati ai posti che hai prenotato.
- **Prenotazioni del piano, di ufficio e di tavolo** — le prenotazioni di spazi interi, ciascuna al suo prezzo per mezza giornata.
- **Pacchetti di giorni** — i pacchetti acquistati questo mese.
- **Voci in sospeso** — tutto ciò che è ancora *in attesa di convalida* (spese, consumi di servizi…), in una scheda a bordo ambra propria: questi importi non sono ancora sull'estratto.
- **Pagamenti e crediti** — pagamenti registrati, rimborsi spese approvati, note di credito, rettifiche.
- **Scheda fattura** — una volta fatturato il mese: numero, chip di stato, totale, già pagato, residuo (§9a).
- **Il tuo conto** — la tua posizione reale tra i mesi, quando esiste (§9a).
- **Saldo** — saldato / aperto, e sotto le **istruzioni di pagamento** e **Paga online** quando c'è qualcosa da pagare.

**Quando i tuoi giorni finiscono**, ciò che accade è una scelta del proprietario, per membro:

- **Bloccato** (predefinito) — niente più prenotazioni; chiedi a un admin, o richiedi **mezze giornate extra** direttamente dalla scheda Finanze (i validatori approvano; i giorni concessi restano addebitati alla tariffa extra).
- **A consumo** — continui a prenotare; ogni giorno extra viene addebitato alla tariffa extra della tua fascia (mostrata sulla scheda).
- **Pacchetti** — tocca **Acquista un pacchetto** e scegli uno dei pacchetti di giorni del proprietario; i tuoi giorni aumentano subito e il prezzo finisce sull'estratto del mese.

Un membro può anche essere **senza abbonamento** — un visitatore occasionale (#1279): nessuna quota mensile, nessuna riga di abbonamento in fattura e nessuna mezza giornata inclusa, quindi prenota con un pacchetto o con crediti. **Senza abbonamento** e **A consumo** non si combinano mai, perché significherebbe prenotare gratis; l'app e il server rifiutano la combinazione.

I **carnet** (Funzioni → *Carnet*, sotto la fatturazione; disattivati per impostazione predefinita) sono mezze giornate prepagate (#1279). Il proprietario li definisce in **Fatturazione** (nome, mezze giornate, prezzo e una validità in mesi — o nessuna: non scadono mai), e chi emette le fatture ne vende uno dalla pagina di un membro. La vendita è addebitata **una sola volta**, sulla fattura del mese. Poi ogni mezza giornata prenotata oltre quanto include l'abbonamento viene presa dai carnet, prima quelli che scadono prima, per tutti i mesi necessari; annullare una prenotazione restituisce la sua mezza giornata. Consumare non aggiunge nulla alla fattura, e una mezza giornata coperta da un carnet non viene mai addebitata anche come eccedenza. La pagina del membro mostra quante mezze giornate restano.

**Le azioni, raggruppate per significato:**

- **Pagare** — **Registra un pagamento** («ho pagato») con il metodo, la **data in cui il denaro si è mosso** (oggi per impostazione predefinita) e il **mese che salda** (quello in corso per impostazione predefinita, un passo indietro per gli arretrati, uno avanti per un anticipo) — l'altra parte conferma. Quel mese decide su quale estratto e su quale fattura finisce l'accredito. **Paga online** (quando attivo) salda subito l'importo dovuto — con **PayPal, carta di credito (Stripe), Mollie o Wero**, secondo ciò che lo spazio ha attivato (se più di uno, appare un selettore).
- **Richieste** — **Invia una spesa** (hai comprato il caffè per lo spazio? un altro admin la approva — niente auto-approvazione — e viene accreditata sul tuo estratto), **Richiedi mezze giornate extra**, **Aggiungi un consumo** (servizi definiti dal proprietario — armadietti, stampe… — confermi ciò che hai consumato).
- **Documenti** — **Fatture** (le tue restano sempre leggibili qui: posizioni, saldo, stato — e per chi emette, l'hub di fatturazione, §11), **Le mie condizioni** (che stampa il documento intitolato *Accordo finanziario*) e il **report mensile dei pagamenti**, self-service (§11).

Finanze ha **quattro viste** in alto — **Estratto · Pagamenti · Fatture · Documenti** (§9c–9f) — che condividono il selettore **‹ mese ›** e il pulsante **PDF**; lo scudo, la campana e l'ingranaggio stanno nella barra dell'app come ovunque.

#### Registrazione con badge NFC

Attiva l'avvicinamento di una tessera invece della scansione di un QR.
L'UID della tessera è conservato come **hash**, mai in chiaro: un badge
può essere revocato ma mai riletto da DesKilo. Solo Android; altrove il
badge QR fa lo stesso lavoro.

### 9a. Una volta fatturato il mese, decide la fattura

- Il tuo estratto mostra una **scheda fattura** — numero, stato, totale, già pagato, residuo — e il mese risulta **saldato** non appena la fattura è pagata, il suo saldo annullato o la sua nota di credito rimborsata, anche se il pagamento che la salda è stato registrato un mese dopo. Una fattura **parzialmente pagata** lascia il mese aperto esattamente per l'**importo residuo** (è anche quanto addebita *Paga online*). Un mese con **nota di credito** mostra ciò che lo spazio ti deve — nulla da pagare da parte tua.
- **Il tuo conto** — quando possiedi credito disponibile (un avoir, o pagamenti in eccesso di un mese passato), la scheda Finanze mostra la tua posizione reale tra i mesi, sopra l'estratto: **credito disponibile**, ogni **fattura aperta** con il residuo, i rimborsi che lo spazio ti deve e la **posizione netta** risultante. Il tuo credito può saldare le fatture aperte — lo spazio lo applica durante la riconciliazione dei pagamenti (imputazione). I mesi precedenti alla tua adesione non devono nulla e non risultano mai aperti.

### 9b. Anteprima rapida, scarica, condividi — ogni report

Ogni report dell'app — l'estratto, le fatture, le proforma, le note di credito, i tuoi documenti self-service — offre le stesse tre azioni: **Anteprima rapida** (vedere il documento renderizzato sullo schermo prima che esista un PDF), **Scarica PDF** (salvare localmente) e **Condividi PDF** (consegnarlo a qualsiasi app — WhatsApp, mail, …).

**I report parlano la lingua di chi legge:** un documento viene stampato nella lingua del **membro** quando per essa esiste un modello, altrimenti nella **lingua dello spazio**, e in mancanza di entrambe nella **lingua del paese dello spazio** (§11 modelli per lingua). Dove quel paese non ha una lingua unica, l'app non tira a indovinare: rifiuta e ti chiede di *impostare prima la lingua dello spazio*.

**Ogni documento come lettera standard (#874).** Con *Standard lettera per ogni documento* attivo, un documento mai progettato dal proprietario — fattura, proforma, estratto, accordo finanziario, report dei pagamenti, report dei consumi, ogni livello di sollecito — si stampa come lettera posizionata: intestazione a 20 mm, destinatario nella finestra della busta DL (110 mm in larghezza, 45 mm in altezza), blocco di identificazione da 90 mm, un piè di pagina su ogni pagina con le coordinate bancarie e il riferimento, una breve striscia dalle pagine 2+. Piega sui segni e l'indirizzo appare. Un layout progettato vince sempre; `dart run tool/report.dart default --kind usage` stampa un layout di partenza.

### 9c. La vista Estratto

**Il mese così com'è.** Il tuo conto (la posizione reale su più mesi), la scheda **Questo mese** (giorni inclusi, usati, rimasti), la scheda **abbonamento**, **servizi consumati**, **supplementi di accessori e spazi**, **pacchetti di giorni**, **posizioni aperte** in attesa di convalida, **pagamenti e crediti**, la **scheda fattura** del mese appena è fatturato (§9a) e il **saldo**. Sola lettura: nulla da premere tranne il selettore **‹ mese ›**, comune a tutte le viste.

![](assets/help/images/statement-account.jpg)

*La parte alta dell'Estratto: il tuo conto (la posizione reale su più mesi) e le tue condizioni negoziate — la tariffa accanto ai tuoi prezzi, con Chi può vedere.*

![](assets/help/images/statement-balance.jpg)

*La parte bassa dell'Estratto: i servizi, le voci ancora in attesa di convalida, pagamenti e crediti, e il saldo.*

### 9d. La vista Pagamenti

**Regolare e chiedere.** Una **striscia di scaduto** quando una fattura supera il termine di pagamento dello spazio (§11e), il **saldo**, le **istruzioni di pagamento** e **Paga online** finché qualcosa è dovuto, poi le azioni: **Registra un pagamento**, **Compra un pacchetto** (piani a pacchetti), **Invia una spesa**, **Chiedi mezze giornate extra**, **Aggiungi un consumo**.

**Scorte (#731).** Hai comprato capsule di caffè o sacchetti per aspirapolvere per lo spazio? In **Invia una spesa**, attiva *È una scorta per lo spazio*, indica l'articolo (o scegline uno esistente), la quantità e quanto costerà un consumo (precompilato con importo ÷ quantità). Convalidata la spesa, vieni rimborsato come sempre **e** l'articolo va sullo scaffale come servizio consumabile con quella scorta; chi lo usa aggiunge un consumo e lo paga, la scorta scende, e a zero l'articolo non si può consumare fino alla prossima scorta. Funzionalità *Scorte dalle spese* (richiede Servizi).

![](assets/help/images/finances-payments.jpg)

*La vista Pagamenti: il saldo e il suo stato, Registra un pagamento, poi Invia una spesa, Richiedi mezze giornate, Aggiungi un consumo.*

### 9e. La vista Fatture

**Cosa mi è stato fatturato?** Una scheda di testa — *niente di aperto, sei in regola*, o *N aperte · importo dovuto*, con il numero delle scadute — poi **ogni fattura emessa a tuo nome**, dalla più recente, ciascuna con il suo chip di stato, **scade tra N giorni** o **scaduta da N giorni**, quante volte è stata sollecitata, e un pulsante **paga** che salta alla vista Pagamenti; tocca una riga per la scheda di dettaglio con anteprima, PDF e condivisione. Chi emette trova il pulsante **Fatture** verso il registro (§11).

**Il percorso (#812).** Ogni riga porta anche la **barra del percorso** della fattura — *Emessa · Pagamento · Conferma · Chiusa*, il passo corrente cerchiato — e **tocca a te** in una frase: *paga X entro il data*, *hai dichiarato X — lo spazio lo sta confermando*, *il tuo pagamento è registrato — lo spazio lo abbina*, *pagata il … — chiusa*. **Come funziona** sulla scheda di testa apre i quattro passi con ciò che fa lo spazio e ciò che fai tu. Funzione *Il percorso di una fattura* (sotto Fatture).

![](assets/help/images/finances-invoices.jpg)

 

![](assets/help/images/invoice-detail.jpg)

*La vista Fatture — la scheda di sintesi e ogni fattura emessa a tuo nome — e la scheda di dettaglio di una fattura: voci, saldo, firma, anteprima rapida / PDF / condivisione.*

### 9f. La vista Documenti

**Il resto delle carte:** **Le mie condizioni** (il tuo accordo finanziario), il **report mensile dei pagamenti**, **l'estratto del mese in PDF** e la **libreria dei documenti** quando lo spazio ne usa una (§11d). Disattiva le viste in Funzionalità → *Finanze in tre viste* per tornare alla colonna unica.

![](assets/help/images/finances-documents.jpg)

*La vista Documenti: Le mie condizioni, il report dei pagamenti, l'estratto del mese in PDF, la biblioteca di documenti.*

### 9g. Negoziazioni di prezzo

**La tariffa è il valore predefinito; le tue condizioni sono tue.** Un proprietario o un admin finanze può proporre una **negoziazione di prezzo** per un membro — quota mensile, eccedenza per mezza giornata, sconto sui supplementi (accessori, prenotazioni di spazi interi) — ciascuno opzionale, la tariffa se assente. La proposta arriva in Eventi ai convalidatori della regola (dominio *Negoziazione di prezzo*, o la regola predefinita); confermata, si applica dal mese scelto e sostituisce le condizioni precedenti. Nella tua vista **Estratto**, la scheda *I miei prezzi negoziati* mostra la tariffa barrata accanto ai tuoi prezzi, da quando, e **Chi può vederlo**: tu, i proprietari e gli admin finanze — ogni lettura da parte di altri è registrata ed elencata lì (§14). Funzionalità *Negoziazioni di prezzo*.

**Servizi, pacchetti e occupazione (#744).** Le condizioni possono fissare anche l'**occupazione** — la quota di giorni di apertura inclusa ogni mese, negoziata con il suo prezzo (applicata al membro una volta convalidata, il valore precedente accanto) — e un **prezzo unitario per servizio e per pacchetto**: un consumo o l'acquisto di un pacchetto è addebitato al prezzo del membro, il prezzo di catalogo barrato nelle schede e sulla carta.

### 9h. Spese programmate

**Gli abbonamenti si pagano da soli — ma mai senza di te.** Ogni membro, qualunque sia il suo ruolo, può **programmare una spesa ricorrente** (internet, telefono, elettricità…): un importo, una prima scadenza, una regola — ogni X giorni, settimane, mesi o anni — e una durata (*X volte*, *fino a una data*, o entrambe; la prima raggiunta termina). La **programmazione stessa viene prima validata** (il suo dominio *Spesa programmata*), quindi il suo importo è un importo approvato dai validatori. Poi ogni scadenza **materializza un'occorrenza e te la presenta** nella vista Pagamenti — nulla viene mai contabilizzato in silenzio:

- Confermata **all'importo validato**, la spesa si aggiunge subito alle tue spese — già definita, perché la programmazione era approvata.
- Confermata **a un importo diverso**, una breve **spiegazione è obbligatoria**; la spesa passa allora la normale validazione delle spese. Confermata → aggiunta; **rifiutata → torna a te**, e puoi cambiare importo e/o descrizione e reinviarla.

L'elenco delle tue programmazioni (stato, regola, prossima scadenza) e il modulo *Programma una spesa ricorrente* stanno dietro **Finanze → Pagamenti → Spese programmate**; terminarne una è un tocco. Funzionalità *Spese programmate* (sotto la scheda Finanze).

#### Una spesa programmata

Un costo che ritorna — la connessione internet, le pulizie, l'affitto.
La descrivi una volta e l'app crea ogni scadenza il suo giorno, senza
che nessuno debba ricordarsene. Ogni scadenza passa comunque per la
validazione che il dominio delle spese richiede: programmare crea la
richiesta, non la approva.

#### Cosa

Il nome che porta ogni scadenza. È ciò che dicono la riga di conto e la
richiesta di validazione: scrivilo come vorresti rileggerlo sei mesi
dopo.

#### Importo

Quanto costa una scadenza. Cambiarlo tocca solo le scadenze non ancora
create; quelle già a conto mantengono l'importo con cui sono state
create.

#### Descrizione

Il testo più lungo, per chi valida. Facoltativo, e il posto per un
numero di contratto o un riferimento fornitore.

#### Prima scadenza

La data in cui scade la prima. Ogni successiva si conta da lì: spostarla
sposta tutta la serie.

#### Ogni

L'intervallo fra due scadenze — ogni mese, ogni trimestre, ogni anno.
Con la prima scadenza decide ogni data che la serie avrà mai.

#### Numero di volte

Quante scadenze creare. Lascialo vuoto per una serie che non si ferma, e
usa *Fino al* quando la fine è una data e non un numero.

#### Fino al

La data dopo la quale non si crea più nulla. Facoltativa: senza, la
serie corre finché non la fermi — giusto per un affitto, sbagliato per
un pagamento in dodici rate.

### 9i. Il report dei consumi

Poiché la partecipazione è **fatturata prima del suo mese** e **consumata** durante, il mese merita una parola di chiusura. **Report dei consumi del mese** — sulla faccia Utilizzo e tra i Documenti — è una lettera al membro: ciò che la partecipazione ha pagato (la quota, le mezze giornate incluse), ciò che è stato realmente consumato (mezze giornate, supplementi), ciò che resta o eccede e, sotto, **ogni record di utilizzo** del mese con il tempo conteggiato. Le cifre sono quelle dell'estratto e dei record — nulla viene ricalcolato. Come ogni lettera si consulta, si salva o si condivide, stampata con l'intestazione dello spazio e, una volta progettata, con il proprio layout (il designer la elenca come *Report dei consumi*).

## 10. Modalità chiosco (tablet a parete)

Monta un tablet Android o un iPad vicino alla porta e lascia che le persone facciano check-in entrando:

1. Il proprietario crea un account normale per il dispositivo, lo unisce allo spazio e lo marca come **chiosco** in *Membri e piani*.
2. **La modalità chiosco non parte mai da sola.** A ogni avvio dell'app il tablet chiede *Avviare la modalità chiosco?* — conferma e il tablet si blocca: solo la piantina a schermo intero, pulsante indietro disabilitato e, su **Android**, l'app si fissa in primo piano così non si può aprire altro — il che significa che lì uscire dalla modalità chiosco passa per un riavvio del tablet. Un **iPad** non ha questo fissaggio, quindi vale solo il blocco della schermata: usa l'**Accesso guidato** di iOS (Impostazioni → Accessibilità) per ottenere l'equivalente. Scegli invece *Non ora* e l'app si apre normalmente — utile per la configurazione. La designazione a chiosco si può revocare in qualsiasi momento: sul dispositivo in **Impostazioni → Dispositivo chiosco**, o dal proprietario in *Membri e piani*.
3. Ogni membro porta con sé un **badge** — emesso da un admin (*Membri e piani → Badge*) o dal membro stesso (**Impostazioni → Il mio badge**, §8): un **badge QR** stampabile e/o la sua **tessera RFID/NFC**. Ciascuno viaggia sulla propria funzionalità (**Badge QR**, **Badge RFID / NFC**), entrambe sotto *Modalità chiosco*, così uno spazio può offrire l'una credenziale, l'altra o tutte e due.
4. Al chiosco, tocca un posto (o **Questo piano** — che richiede le prenotazioni di spazi interi attive *e* quel piano marcato come prenotabile) — si apre **UNA sola scheda** con tutto: **Check-in** già selezionato (un tocco passa a **Prenota** o **Check-out**), il **periodo già derivato dalle impostazioni dello spazio**, e il **lettore badge attivo** in basso. Con le mezze giornate, la parte del giorno in cui ti trovi è preselezionata (chip Mattina / Pomeriggio / Giornata per cambiare — una finestra in corso parte *adesso*, le fasce già concluse non vengono proprio proposte, e ciò che risulta in grigio è semmai una fascia ancora futura quando l'azione scelta è **Check-in**, perché non si può essere presenti in anticipo; dopo l'orario resta un unico *Resto della giornata*, che corre fino a mezzanotte e non oltre, perché una prenotazione finisce nel giorno in cui inizia). Con granularità a tempo: selettori Da/A allineati alla griglia, l'inizio di un check-in fissato ad *adesso*. La scheda **dichiara la regola che segue** — la granularità e le finestre orarie di oggi — quindi offre esattamente ciò che le impostazioni permettono; un **giorno di chiusura** viene detto subito con un banner invece di fallire alla fine. Prenotare una finestra già iniziata offre anche **Check-in subito?** (attivo per default): una sola presentazione del badge registra la prenotazione *già con check-in*. Poi presenta il badge:
   - **Avvicina la tessera RFID/NFC.** Finché il lettore di tessere è armato la fotocamera resta spenta; se l'NFC è disattivato o assente, la scheda lo dice esplicitamente.
   - Oppure tocca **Scansiona il badge QR** — il tablet legge il badge stampato **con la propria fotocamera** (frontale per impostazione predefinita, perché l'obiettivo posteriore di un tablet a parete guarda il muro; cambia in *Impostazioni → Scansiona con la fotocamera frontale*). Funzionano anche un lettore di codici USB/Bluetooth o la digitazione del codice.
5. **Il badge È la conferma:** esegue immediatamente, e una **ricevuta che si chiude da sola** mostra *chi* è stato riconosciuto — con la sua **foto del profilo**, dove la funzionalità *Foto dei membri al chiosco* è attiva —, *cosa* è successo, *dove* e *fino a quando*, poi la parete è pulita per il membro successivo. Allo stesso modo la piantina a parete mostra le foto degli occupanti. Il percorso felice sono due gesti: tocca il tuo posto, presenta il tuo badge.

**Ciò che la parete di proposito non fa.** Tocca un posto che tiene qualcun altro e il chiosco **nomina il titolare e ti rimanda al telefono**: un dispositivo a muro non manda mai un messaggio a nome di un membro, perché potrebbe farlo chiunque gli stia davanti. L'azione *Scrivigli* per uno spazio bloccato vive nell'app (§4b). Tutto ciò che il chiosco *offre* passa dalle stesse regole applicate sul server per l'app — controllo del giorno già terminato, obbligo che un check-in spontaneo inizi oggi e regola del giorno unico compresi — quindi la parete rifiuta esattamente ciò che rifiuta la piantina.

La tua identità esiste solo per il tempo dell'operazione: la credenziale viene inviata **solo per quell'operazione** — una volta per identificarti, una volta per eseguire l'azione — e **non viene conservata**, né sul tablet né altrove. La prenotazione è fatta **a tuo nome**, e sei «disconnesso» appena finisce. (L'accesso per singola operazione con Google è ancora nella roadmap; **gli iPad non hanno NFC**, quindi lì la via è il QR con fotocamera.)

## 11. Fatturazione (proprietari e admin di fatturazione)

*I proprietari emettono le fatture; anche gli admin, quando detengono il permesso **emettere fatture** (Gestione dei ruoli, §8 — o la vecchia delega **Gli admin emettono fatture**). La funzionalità **Fatture** sta sotto Finanze nell'elenco delle funzionalità.*

**Coordinate bancarie senza IBAN (#711).** In *Istruzioni di pagamento*, accanto all'IBAN: nome della banca, numero di conto, un codice di instradamento chiamato come lo chiama il tuo paese — *sort code* nel Regno Unito, *routing number* negli USA, *transito · istituzione* in Canada — e un BIC/SWIFT per i bonifici esteri. Solo i campi compilati compaiono sulla scheda «come pagare».

Una fattura in DesKilo viene generata, mai composta: le sue posizioni sono **derivate esclusivamente dai dati tracciati del mese** — abbonamento, eccedenza, supplementi, servizi, pacchetti — meno i pagamenti e gli accrediti del mese, così la riga finale **è il saldo dovuto**. Ogni documento fotografa gli indirizzi postali dello spazio e del membro (imposta il tuo in **Impostazioni → Dati personali**; l'indirizzo dello spazio sta nelle impostazioni dello spazio) ed è **firmato digitalmente** all'emissione — dopo non cambia più. Un **allegato dettagliato** (il libro mastro e le presenze del mese) si aggiunge con un interruttore al momento dell'emissione.

**Il percorso di una fattura (#812).** Con la funzione *Il percorso di una fattura* (attiva per impostazione predefinita), l'hub racconta il processo invece di elencare stati. Una **barra delle fasi** sostituisce le pillole di riepilogo — *1 · Da emettere · 2 · Da incassare · 3 · Da confermare · 4 · Chiuse* — con i contatori in tempo reale (Da incassare al valore residuo, le scadute in rosso; Da confermare raccoglie ogni fattura la cui prossima mossa non è del membro: un pagamento dichiarato che un altro admin conferma, un pagamento registrato da abbinare, un abbinamento o una cancellazione del residuo davanti ai validatori, una nota di credito da rimborsare); ogni riquadro porta alla sua scheda. Ogni **scheda aperta** porta la **barra del percorso** (*Emessa · Pagamento · Conferma · Chiusa*) e la **prossima mossa** in una frase — *in attesa del pagamento di Flo: 250 € — scadenza 27 mag*, *Flo deve 250 € — in ritardo di 6 giorni*, *Flo ha dichiarato un pagamento di 250 € — un altro admin lo conferma in Eventi*, *un pagamento di 250 € è registrato — abbinalo a questa fattura*, *pagamento abbinato — in attesa della decisione dei validatori*, *nota di credito — rimborsa 8 € a Flo e registralo*. L'azione che quella mossa si aspetta da te è l'**unico pulsante con etichetta** della scheda (*Invia sollecito 2*, *Segna come pagata*, *Registra il rimborso*, *Apri Eventi*); il resto restano icone con tooltip. Il **foglio di dettaglio** si apre sulla stessa barra e la stessa frase, i suoi fatti datati sotto il titolo *Cronologia*, e l'azione attesa apre l'elenco. Il **?** nell'intestazione apre **Come funziona la fatturazione** — i quattro passi, ciascuno con il lato dello spazio e quello del membro — lo stesso foglio che i membri aprono dalla loro vista Fatture.

Chi emette apre **Finanze → Fatture** e trova un hub a tre schede sotto una striscia di riepilogo in tempo reale (*N da fatturare · N aperte · X in sospeso · N da rimborsare · Y*):

- **Da fatturare** — ogni membro il cui mese precedente ha dati fatturabili e nessuna fattura, con il totale del mese: emetti per membro (con l'anteprima delle posizioni derivate) o **Fattura tutto** in un colpo solo — che prima chiede conferma, indicando il numero, il mese e il totale. Il pulsante **Nuova fattura** apre la stessa scheda per qualsiasi membro e mese — selettore del membro, ‹ mese ›, le posizioni derivate, il saldo, l'interruttore dell'**allegato dettagliato** ed **Emetti fattura** (uno snack verde *Fattura emessa.* conferma). **Una sola fattura attiva per membro e mese** — un mese torna fatturabile solo dopo che la sua fattura è stata annullata. Il foglio di emissione si apre sul **mese chiuso** (il momento in cui i suoi numeri smettono di muoversi); se scegli il mese in corso ti avvisa, perché quel mese si può fatturare una sola volta.
- **Aperte** — fatture emesse in attesa di saldo, dalle più vecchie; ciò che attende da oltre 30 giorni diventa rosso, sulla scheda e nella striscia di riepilogo. Ogni azione è un'icona con suggerimento (annulla · proforma · sollecito · segna come pagata). **Tocca una scheda per leggere la fattura.** **Invia un promemoria** registra il sollecito e condivide il PDF con un messaggio — la scheda mostra *Sollecitato ×N*. **Segna come errata** annulla la fattura per correggerla (una finestra esplicita avvisa che l'operazione è irreversibile): passa nell'archivio barrata, e una **sostitutiva** ri-deriva lo stesso mese dai dati corretti, citando l'originale. **Segna come pagata** abbina un pagamento reale (sotto). **Un pagamento parziale non chiude una fattura**: resta tra le Aperte, con badge *Parzialmente pagata* e l'importo residuo, finché il saldo non pagato non viene annullato esplicitamente **tramite il framework di convalida** — un admin/proprietario richiede l'annullamento (con un motivo), i validatori confermano e solo allora la fattura passa in archivio come *Parzialmente pagata · saldo annullato*. **Una fattura NEGATIVA è una nota di credito (avoir)** — i crediti del mese superano i suoi addebiti, quindi lo SPAZIO deve denaro al membro: il suo PDF si intitola *Nota di credito*, non riceve solleciti né riconciliazione con pagamenti del membro; la scheda mostra invece *Da rimborsare* con **Registra il rimborso** — il versamento si imputa al saldo del membro (convalidato come ogni liquidazione quando vale una regola; un rifiuto la riapre) e il documento si chiude come *Rimborsata*. La striscia di riepilogo separa le due direzioni del processo di pagamento: *N aperte · X in sospeso* conta le fatture positive al loro valore **residuo** (una fattura da 500 € con 280 € pagati conta 220 €), mentre *N da rimborsare · Y* somma le note di credito aperte che lo spazio deve ancora.
- **Archivio** — fatture chiuse, filtrabili per membro e mese e ordinabili; le fatture annullate sono **nascoste per impostazione predefinita** — il chip *Mostra annullate* riporta la catena di correzione; la barra sotto i filtri dice quante fatture corrispondono e **Azzera i filtri** riporta l'archivio intero. Ogni riga porta il suo chip di stato (*Pagata*, *Parzialmente pagata*, *Errata* barrata, le note di credito con il loro importo negativo), il suo mese e il suo importo, con **Scarica PDF** lì accanto. **Tocca una riga per aprire la fattura** — posizioni, saldo, destinatario, dove si trova (*Pagata 300,00 € il 6 ago*, *Sollecitato ×1 · ultimo sollecito…*, *Allegato: 5 movimenti, 10 check-in*), quale fattura sostituisce o da quale è stata sostituita, la sua firma — e ogni azione ancora permessa, per nome: **Anteprima rapida**, **Scarica PDF**, **Condividi PDF**, esporta la **fattura elettronica (XML)**, sollecita, segna come pagata, segna come errata, emetti una sostitutiva.

**Segnare come pagata significa abbinare un pagamento reale — o applicare un credito.** La finestra elenca i pagamenti registrati del membro — bonifici registrati e pagamenti online confermati — e tu abbini la fattura a uno di essi; non c'è alcun importo da digitare (nessun pagamento registrato? la finestra lo dice: *registralo o confermalo prima*). Elenca anche i **crediti sul conto** del membro (eccedenze da nota di credito): abbinarne uno imputa l'avoir sulla fattura, mesi passati compresi — l'alternativa standard al rimborso in contanti, per associazioni e imprese allo stesso modo. Ogni credito si spende esattamente una volta: uno già dedotto dentro una fattura emessa non può mai saldare un secondo documento. Ha pagato **di più**? Crea una **nota di credito** per l'eccedenza (un accredito sul libro mastro del membro) oppure forza l'accettazione con una nota obbligatoria. Ha pagato **di meno**? Accettalo con una nota obbligatoria. Tutti coloro che hanno accesso alla fatturazione vengono avvisati delle fatture pagate, e il proprietario può mettere una regola di validazione **Pagamento fattura** (§7): l'abbinamento resta allora in attesa del quorum — un rifiuto riapre la fattura.

**Una fattura pagata è definitiva.** Una volta abbinata non può più essere annullata, sostituita o modificata — le correzioni avvengono prima del pagamento, annullando la fattura aperta ed emettendo la sua sostitutiva. Un pagamento che **non** ha coperto l'intero importo, accettato con una nota, compare come **parzialmente pagata**, non come pagata.

**Proforma.** Due delle tre schede dell'hub offrono un'azione proforma: su **Da fatturare** rende le posizioni derivate del mese come preventivo — senza numero, senza firma, timbrata PROFORMA, e **non emette nulla**; su **Aperte** rigenera la fattura emessa come richiesta di pagamento che non può passare per l'originale. Entrambe offrono la triade anteprima rapida / scarica / condividi.

**Timbri.** Una fattura annullata porta un grande **ERRATA** in diagonale su ogni pagina del suo PDF, in grigio chiaro sopra il contenuto: non si confonde con un documento valido su una scrivania né in fotocopia. Lo stesso timbro dice **PROFORMA** su un preventivo e **COPIA** su ogni fattura generata da qualcuno che non sia chi l'ha emessa — l'originale resta allo spazio.

![](assets/help/images/dunning-rules.jpg)

*Le regole di sollecito: livelli, giorni fino al primo promemoria, giorni tra i livelli — e l'interruttore Solleciti automatici.*

**Solleciti (Mahnwesen).** Il proprietario imposta le **regole di sollecito** (icona elenco puntato nell'intestazione Fatture, o *Impostazioni dello spazio → Regole di sollecito*): quanti livelli, giorni fino al primo promemoria, giorni tra i livelli. Le fatture aperte scadute sono contrassegnate **«Sollecito N da inviare»** e la campanella sulla scheda diventa rossa — nulla parte al posto tuo finché **Solleciti automatici** non è attivo (§11e). Un sollecito manuale è registrato al suo livello e arriva nel feed del membro esattamente come uno automatico (#816). L'invio genera una **lettera di promemoria di pagamento** (livello 1 amichevole, livelli superiori più fermi) dal modello di quel livello — fornito pronto nella tua lingua, stampato nella lingua del *membro* e modificabile per livello nell'editor di report con i campi extra `{{ reminder_level }}`, `{{ reminder_date }}` e `{{ days_open }}`.

![](assets/help/images/invoice-register.jpg)

*Il registro: una riga per fattura, il totale in fondo, il selettore dell'anno e il pulsante di esportazione contabile (SAF-T / FEC).*

**Il registro.** L'icona elenco nella barra delle Fatture apre un giornale con una riga per fattura: **data · nome · importo · stato**, ordinato per data (tocca l'intestazione Data per invertire la direzione), con il totale in fondo e un selettore dell'**anno** quando ce n'è più di uno. Il suo pulsante di esportazione apre il foglio **Esportazione contabile**: **SAF-T (XML, internazionale)** e — per uno spazio francese — **FEC (Francia, richiesto in caso di verifica)**.

**Consegnare il periodo al commercialista.** Dal registro, chi emette esporta il **SAF-T** — lo *Standard Audit File for Tax* dell'OCSE, l'XML che leggono i software contabili e le amministrazioni fiscali. Copre esattamente ciò che mostra il registro, quindi scegliere 2026 dà il file del 2026: l'impresa così come la dichiarano le tue stesse fatture, ogni cliente, ogni fattura con righe e totali, e i pagamenti che le hanno saldate. Le fatture annullate restano nel file, marcate *annullate* — un file di audit non cancella mai ciò che è avvenuto. Ciò che lascia fuori di proposito è il **piano dei conti**: DesKilo non inventa numeri di conto, perché un codice sbagliato va stornato a mano. Il commercialista associa le fatture ai propri conti — è il suo lavoro e gli costa un minuto.

**Francia: il FEC.** Uno spazio francese ha una seconda scelta, il **FEC** (*Fichier des Écritures Comptables*) — il file che una verifica fiscale richiede per legge (art. L47 A-I du LPF). Non è XML: un file piatto separato da tabulazioni fatto di **scritture** contabili, denominato `<SIREN>FEC<YYYYMMDD>.txt` come impone l'arrêté, con le 18 colonne obbligatorie nell'ordine obbligatorio. Essendo fatto di scritture *non può* fare a meno dei numeri di conto, quindi l'esportazione li chiede prima — precompilati con il *plan comptable général* (411 clienti, 706 prestazioni, 512 banca) e correggibili. Ogni fattura iscrive il suo credito a fronte del ricavo per l'importo **lordo**; i crediti che ha compensato e il pagamento che l'ha saldata passano in banca con le proprie date, lettrati con il numero di fattura. Le fatture annullate non ci sono: una annullata prima del pagamento non è mai stata contabilizzata, quindi non c'è nulla da stornare. La colonna del *nome* segue chi legge — chi emette scorre i nomi dei membri, un membro scorre i propri numeri di fattura. I membri vedono solo ciò che li riguarda: le fatture emesse, e mai una annullata. Da #927 il numero di registrazione è derivato dal documento che contabilizza — `VE-` più il numero di fattura, `BQ-…-P` per l'incasso — invece di essere contato per file: due esportazioni di periodi sovrapposti portano così lo stesso numero per la stessa registrazione, come il file richiede.

![](assets/help/images/invoices-admin.jpg)

*L'hub degli emittenti: Da fatturare · Aperte · Archivio sotto la striscia di riepilogo in tempo reale; una fattura aperta con le sue quattro azioni (annulla · proforma · sollecito · segna come pagata).*

![](assets/help/images/invoices-to-invoice.jpg)

 

![](assets/help/images/invoice-new-sheet.jpg)

*Da fatturare senza nulla in sospeso e il chip di sintesi — e la scheda Nuova fattura: membro, mese, le voci derivate, l'interruttore dell'allegato dettagliato.*

### 11a. Identità legale, IVA e menzioni

**Prima della prima esportazione, compila l'identità legale.** In *Impostazioni dello spazio → **Identità legale e fatturazione elettronica*** il proprietario dichiara:

- Il **regime IVA** — decide il numero che la norma EN 16931 richiede: fuori dal campo di applicazione dell'IVA, un **numero di registrazione** dell'impresa (SIREN, HRB, CIF…); esente IVA in un regime forfettario, una **partita IVA** più il **motivo del mancato addebito dell'IVA** (il campo suggerisce la dicitura corretta — *TVA non applicable, art. 293 B du CGI*, o per i servizi ai membri di un'associazione *Exonération de TVA, art. 261, 7-1° du CGI*). Il regime è applicato end-to-end: solo uno spazio soggetto IVA applica mai un'aliquota a un abbonamento, un supplemento, un servizio o un pacchetto, e i selettori IVA semplicemente scompaiono sotto qualsiasi altro regime.
- L'**indirizzo** strutturato (via, codice postale, città) accanto all'indirizzo libero dell'intestazione.
- La **piattaforma di fatturazione elettronica** (§11b).
- Le **menzioni di fatturazione**, con un selettore **Tipo di organizzazione** — *Impresa* vs *Associazione (loi 1901)*: forma giuridica e capitale (es. *Association loi 1901*), registro delle imprese (imprese: RCS; associazioni: **RNA W… · SIRET se assegnato**), termini di pagamento, penale di mora, l'**indennità di recupero di 40 €**, sconto per pagamento anticipato (escompte), assicurazione professionale, menzioni particolari. Ogni clausola lasciata vuota stampa la dicitura legale predefinita — e i documenti di un'associazione omettono le clausole predefinite solo-B2B (penale di mora, indennità di recupero ed escompte sono obbligatorie solo tra professionisti; ciò che scrivi viene comunque stampato).

I membri aggiungono il proprio **paese** — e la partita IVA se fatturano come impresa — accanto all'indirizzo in *Impostazioni → Dati personali*. DesKilo verifica tutto questo **prima** di produrre una fattura elettronica e rifiuta indicando l'elemento mancante, perché una fattura che una piattaforma rigetta è peggio di nessuna fattura.

**I tuoi dati personali (#886).** *Impostazioni → Dati personali* contiene ciò che ogni documento stampa su di te: nome e **cognome** (in maiuscolo sui documenti, come nella posta ufficiale), una **società** facoltativa, via, CAP, città, paese, telefono, **l'e-mail a cui vanno i tuoi documenti** e — se fatturi come impresa — partita IVA e identificativo. Il modulo mostra in anteprima il blocco esattamente come lo mostrerà la finestra della busta: nome, società, via, `CAP CITTÀ`, e il paese solo se vivi all'estero. Elenchi e documenti ti chiamano con questo nome; l'indirizzo libero delle versioni precedenti resta il ripiego finché non compili il modulo.

**Profili gestiti (#887).** Qualcuno entra nell'associazione prima di avere l'app? Un admin apre **Membri → Aggiungi un profilo gestito** e compila lo stesso modulo di identità. Il membro esiste subito — prenoti per lui, emetti le sue fatture (stampate con l'identità inserita), imposti l'abbonamento — e la sua pagina porta il chip **Gestito**. Quando la persona è pronta, **Consegna alla persona** genera un codice personale legato a quel profilo (QR, link o messaggio, come ogni invito). Crea il suo account, inserisce il codice e prende il profilo: prenotazioni, fatture e abbonamento restano suoi, l'identità inserita arriva nelle sue impostazioni (i suoi dati da quel momento — solo i campi vuoti vengono riempiti) e l'adesione passa per la consueta approvazione. **Revoca la consegna** ritira un codice non usato.

**Chi amministra un profilo gestito (#914/#915).** Un profilo gestito contiene l'identità di una persona reale prima che abbia un account: indirizzo, telefono, e-mail, identificativi fiscali. Quei campi non sono più leggibili dagli altri membri — restano tali solo nome e azienda, perché l'elenco dei membri ne ha bisogno. Il resto vive dietro una **regola**, e ogni consultazione è **registrata**. Per impostazione predefinita la regola è quella di prima: ogni proprietario e ogni admin. Attivate *Chi amministra un profilo* per restringerla per ruolo, per persone indicate o entrambi. Il proprietario può sempre **cambiare** la regola — altrimenti un profilo il cui unico admin indicato se ne va diventerebbe inamministrabile — ma accede ai dati solo se la regola lo nomina. La regola protegge l'identità e la consegna; prenotare e fatturare restano normale amministrazione. Quando la persona riprende il profilo, *Impostazioni → Privacy → Chi vede cosa* le mostra la regola applicata e chi ha davvero aperto o modificato i suoi dati.

**Sviluppo o produzione (#917).** Uno spazio dichiara se è reale. Uno spazio di **sviluppo** lo annuncia su una fascia presente in ogni schermata, e ogni documento che stampa porta «SVILUPPO» attraverso la pagina — prima di qualsiasi altro timbro, perché una fattura di prova che è anche una nota di credito è anzitutto una fattura che non esiste. La scelta si fa **alla creazione** ed è di sviluppo per impostazione predefinita: la risposta prudente a «è reale?» è no finché qualcuno non dice il contrario. Tutti gli spazi creati prima di questa versione sono dunque di sviluppo. Solo il **proprietario** può dichiarare uno spazio di produzione — un admin non può togliere di nascosto il marchio dai documenti che emette — e l'app chiede conferma dicendo che cosa smette di accadere. Le fatture già emesse non cambiano: la filigrana è applicata alla stampa.

**Un cliente può essere un'azienda (#910).** Un profilo gestito non ha bisogno di un nome di battesimo: basta la **ragione sociale**. Quando manca il nome di una persona, è l'azienda a diventare il destinatario — sulla fattura, negli elenchi, nel flusso di pagamento — e sparisce allora dall'indirizzo sottostante, perché è già la riga sopra. Se una persona è indicata, non cambia nulla: l'azienda resta nel blocco indirizzo, tra il nome e la via. Ne beneficiano anche i documenti già emessi: la ragione sociale vi era congelata fin dall'inizio, semplicemente non veniva letta.

**Prima l'azienda, poi la persona (#912).** Quando un cliente porta una ragione sociale E un nome di persona, il documento si rivolge all'**azienda** — è lei a dovere la fattura — e nomina la persona nella riga sottostante, con la formula che ha scelto:

> SASU KaloA
> Sig. Guilhem MARTIN
> 209 rue Jean Bart, Immeuble AGORA 1B
> 31670 LABÈGE

La **formula di cortesia** è un campo dei vostri dati personali: *Sig.*, *Sig.ra* o *Nessuna*, che stampa solo il nome. Non viene mai dedotta da un nome di battesimo, e ogni lettore la vede nella propria lingua — *Monsieur* in francese, *Herr* in tedesco. Senza azienda nulla cambia: la persona resta il destinatario.

**La scadenza è sul documento (#910).** Ogni fattura stampa ora la sua **data di pagamento**, calcolata dal termine delle vostre regole di sollecito — lo stesso termine che l'app mostra nel flusso di pagamento, così i due non possono più annunciare date diverse. Un modello può collocarla dove vuole con `due_date`. E un documento di una sola pagina non porta più il numero di pagina: «1/1» non dice nulla a nessuno.

**In DesKilo i prezzi sono IVA inclusa.** Ciò che scrivi come prezzo di abbonamento, di servizio o di pacchetto di giorni è ciò che il membro paga. Attivare l'IVA non cambia un solo importo dovuto da nessuno — dice quanta parte di quell'importo è imposta. Per questo un estratto, un conto e una quota non si muovono mai quando aggiungi le aliquote, e per questo nessun totale va mai riconciliato. Sotto un regime soggetto a IVA il catalogo lo dice ad alta voce: ogni riga di servizio e di pacchetto nomina la sua aliquota inclusa (*IVA 22 % incl.*), l'editor di fatturazione consente al proprietario di scegliere l'aliquota IVA delle tariffe (predefinita: quella dello spazio) e mostra la quota IVA di ogni importo mentre digiti, ogni accessorio può portare la propria aliquota (predefinita: quella dello spazio), e ogni campo prezzo ricorda che è lordo.

#### Configurare le aliquote

*Identità legale e fatturazione elettronica → **Aliquote IVA***. Un elenco vuoto significa IVA disattivata: è così che ogni spazio comincia. **Usa le aliquote consuete** riempie l'elenco con l'aliquota ordinaria, intermedia e ridotta del tuo paese come prima bozza — un punto di partenza, non una consulenza fiscale. Un'aliquota è quella **predefinita** (la stella): abbonamenti, eccedenze, supplementi e rettifiche la usano, come ogni servizio che non ne ha una propria. Un servizio e un pacchetto di giorni portano ciascuno la propria aliquota, scelta nel loro editor. Rimuovere un'aliquota non la cancella mai — una a cui una fattura o un servizio fa ancora riferimento viene conservata, disattivata, così nulla viene tassato di nuovo in silenzio. Tutto questo è la funzionalità *Gestione IVA*: disattivata, l'editor delle aliquote e tutti i selettori scompaiono mentre le aliquote salvate continuano ad applicarsi — l'aritmetica fiscale non è mai disattivabile — e l'interruttore *Dichiarazioni IVA* vive sotto di essa.

#### La dichiarazione IVA periodica

(*Aliquote IVA → Dichiarazione IVA*, solo spazi soggetti a IVA). Scegli il periodo — mese o trimestre, secondo il tuo regime — e **Genera**: l'app aggrega le fatture emesse del periodo per aliquota **con l'esatta aritmetica delle fatture**, la dichiarazione quadra quindi con ogni documento al centesimo. Il risultato mostra imponibile e IVA per aliquota, mappati sulle **righe del modulo ufficiale** (CA3 08/09/9B/11 in Francia, UStVA Kz 81/86 in Germania, elenco generico altrove). Ogni dichiarazione si esporta in **PDF** e **XML leggibile dalla macchina**; se sotto la fatturazione elettronica è configurata una piattaforma di invio, **Trasmetti** la invia elettronicamente e registra la ricevuta — altrimenti porta i numeri sul portale dell'agenzia o dal commercialista e **Segna come inviata**. In entrambi i casi la dichiarazione diventa immutabile, con canale e ricevuta registrati. Il catalogo di aliquote suggerite copre tutti gli Stati membri UE, la Svizzera (incluso il 3,8 % alloggio), la Norvegia e le province canadesi; gli USA non hanno IVA federale — l'app lo dice invece di indovinare. Un aiuto alla dichiarazione, non consulenza fiscale.

**Cosa cambia su un documento.** Una fattura emessa dopo la creazione delle aliquote porta la ripartizione così come emessa: la tabella delle posizioni guadagna una colonna di aliquota, e sopra il totale il PDF mostra l'**imponibile** e una riga per aliquota. La **fattura elettronica (XML)** porta ciò che EN 16931 richiede, sia in UBL sia in CII; il **SAF-T** dichiara ogni aliquota nella sua tabella imposte; il **FEC** registra il credito al lordo contro il ricavo netto più un conto di **IVA incassata** (445710 per impostazione predefinita, modificabile).

**Una fattura già emessa non cambia mai.** Porta le aliquote, l'identità e gli importi con cui è stata firmata — è questo che la rende una fattura. Se un documento deve portare nuovi dati, segnalo come **errato** ed emetti una **sostitutiva**: la catena di correzione è visibile su entrambi i documenti, che è esattamente ciò che una verifica vuole vedere.

**Come sono numerati i documenti (#925).** Ogni registro — fatture, note di credito, dichiarazioni IVA, numeri di socio, riferimenti di pagamento — ha la sua **serie**, presa nel database nel momento in cui il documento è emesso: senza buchi (un documento che fallisce non consuma nulla), esatta comunque tanti admin emettano insieme, e sull'anno del **vostro** fuso, non dell'UTC. Il proprietario imposta il formato in una sola schermata, *Impostazioni → Serie di numerazione*: prefisso, anno o mese, cifre, azzeramento, con l'anteprima del prossimo numero. Il formato vale per ciò che segue; un documento emesso non cambia mai, e il contatore può essere alzato ma mai abbassato. **Una serie non ripete mai un numero (#1320):** ricomincia al massimo tanto spesso quanto stampa la sua data — senza data mai, con l'anno al massimo ogni anno —, quindi la schermata offre solo quegli azzeramenti. Cambiare l'azzeramento vale dal periodo successivo, mai in quello in corso, e togliere la data da una serie che ha già emesso numeri richiede un nuovo prefisso o suffisso nello stesso passo.

**Fatturare a un'impresa di un altro paese UE (#895).** Uno spazio soggetto a IVA non la addebita a un'**impresa di un altro Stato membro**: quel cliente assolve l'imposta lui (art. 196). Quando il profilo del cliente porta una partita IVA e un paese diverso dal tuo, la fattura è emessa **senza imposta**, indica la categoria richiesta dalla norma (AE) e stampa la dicitura di legge — *Inversione contabile*, o quella che parla il tuo paese. Il prezzo resta la tariffa: nulla viene aggiunto, nulla tolto. Il controllo della fattura elettronica rifiuta l'invio finché manca la partita IVA del cliente, perché è ciò che prova che l'imposta è sua. Uno spazio che non fattura mai imprese all'estero disattiva tutto in *Identità legale → Inversione contabile per imprese UE*.

**Fatturare a un comune, un ospedale, lo Stato (#922).** Un deposito su **Chorus Pro** richiede, per la maggior parte degli enti pubblici, un **numero di impegno** (BT-13) o un **codice servizio** (BT-10). Entrambi si inseriscono **all'emissione** della fattura, sono congelati sul documento, stampati sotto il numero di socio e portati nell'XML — UBL come Factur-X — dove la norma li colloca. Il controllo della fattura elettronica **avvisa** quando una fattura parte verso la piattaforma pubblica senza nessuno dei due; non blocca, perché un socio non è un comune.

**Quando l'IVA diventa esigibile (#896).** Uno spazio soggetto dichiara con il **criterio ordinario** — l'imposta è esigibile con la fattura — oppure con l'**IVA per cassa** — è esigibile il giorno in cui il cliente paga. In Francia i servizi seguono l'incasso salvo opzione contraria; la Germania la chiama *Ist-Versteuerung*. La scelta è in *Identità legale → Esigibilità dell'IVA*. All'incasso, un periodo dichiara **i pagamenti ricevuti al suo interno** e non le fatture emesse: un pagamento parziale porta una quota di ogni aliquota del documento, in proporzione, e l'arrotondamento va all'aliquota più ampia perché il totale corrisponda esattamente a quanto incassato. Il rapporto IVA del commercialista segue la stessa regola — una posizione è lì un incasso, datato al giorno in cui è arrivato — quindi rapporto e dichiarazione non possono divergere. Ogni fattura stampa la menzione corrispondente e la schermata delle dichiarazioni nomina la base in uso.

**Una nota di credito restituisce anche l'imposta (#894).** Un credito che annulla un addebito soggetto a IVA indica ora l'aliquota che storna: la ripartizione del documento mostra quell'imposta in negativo e la dichiarazione la compensa — una spesa ripartita e restituita (#828) viene stornata all'aliquota con cui era stata addebitata. Il denaro che si muove — un pagamento, un rimborso spese — non porta aliquota e non tocca mai l'imposta, come prima. Un documento con totale negativo è tipizzato **nota di credito (381)** nella fattura elettronica, non fattura.

**Condizioni di pagamento per membro (#881).** La formulazione sopra è quella predefinita dello spazio, per tutti. Un membro può avere **le proprie** — un termine più lungo per un grande cliente, ad esempio. Non si scrivono mai direttamente sul membro: un admin con il permesso *Richiedere modifiche alle condizioni di pagamento* apre la pagina del membro, **Condizioni di pagamento → Richiedi una modifica**, compila solo i campi che differiscono (un campo vuoto mantiene la formulazione dello spazio) e indica un motivo; la richiesta diventa una scheda di convalida **Condizioni di pagamento** decisa come ogni altro dominio (il proprietario, per impostazione predefinita), e la deroga si applica alla conferma. Il membro vede le condizioni effettive in sola lettura sulla sua pagina e in **Impostazioni → Condizioni di pagamento**, etichettate *Predefinite dello spazio* o *Proprie del membro*; ogni fattura e sollecito stampa quelle effettive, e un layout può verificare `payment_terms_source`. *Torna alle condizioni predefinite dello spazio* chiede di togliere la deroga — con la stessa convalida.
**IVA — la checklist di conformità (#878).** Rivista il 05/09/2026 rispetto alla direttiva 2006/112/CE e a EN 16931 (ADR 0015). Ciò che regge: il regime del venditore è **fissato su ogni documento** all'emissione (un'associazione che diventa esente mantiene le fatture precedenti fuori campo così com'erano); anche la ripartizione per aliquota è fissata, arrotondata per riga esattamente come il server; la numerazione è continua e i documenti non cambiano mai (si annullano e si riemettono). Ciò che l'app fa ora per te: i documenti di un venditore **esente o fuori campo stampano la dicitura di legge del loro paese** (FR art. 293 B CGI, DE § 19 UStG, AT, ES, IT, BE, NL, LU, altrimenti la direttiva) quando non hai scritto nulla in *Identità legale*; il controllo della fattura elettronica **avvisa quando la partita IVA di un cliente non ha la forma del suo paese**. Ciò che resta al proprietario: tenere aggiornato il catalogo delle aliquote quando cambiano; un venditore soggetto deve avere una partita IVA. I tre limiti annotati dalla revisione sono chiusi: le note di credito stornano l'IVA (#894), l'inversione contabile intracomunitaria è decisa all'emissione (#895) e l'IVA per cassa è un'impostazione dello spazio (#896).
**Il report IVA (#878).** In *Dichiarazioni IVA*, per il mese o trimestre scelto: **Report IVA (PDF)** — ogni posizione imponibile (documento, data, cliente, imponibile, aliquota, IVA, totale, categoria, l'originale rettificato se presente), subtotali per aliquota e categoria, totali del periodo — come lettera da vedere, salvare, condividere e progettare come ogni documento (*Report IVA* nell'editor); **Report IVA (CSV)** — le stesse posizioni, separate da punto e virgola, per il commercialista.

#### Tipo di organizzazione

*Impresa / società* o *Associazione (loi 1901)*. Decide quali clausole un documento stampa per impostazione predefinita: interessi di mora, indennità di recupero e sconto sono obblighi **tra professionisti**, quindi le fatture di un'associazione ne fanno a meno. Ciò che scrivi tu viene sempre stampato, qualunque sia il tipo.

#### Forma giuridica e capitale

Ciò che l'organizzazione è in diritto, stampato sotto il suo nome: *S.r.l. con capitale di 10 000 €*, *Association loi 1901*. Lasciato vuoto, un'impresa non stampa nulla e un'associazione stampa la sua forma statutaria.

#### Registro delle imprese

L'iscrizione con cui si può verificarti: **Registro delle imprese** e città per una società, **RNA W…** e il **SIRET** se assegnato per un'associazione. È ciò che cerca la contabilità del tuo cliente, e senza cui il controllo della fattura elettronica rifiuta di inviare.

#### Condizioni di pagamento

Quando il denaro è dovuto — *pagamento alla ricezione della fattura, a 30 giorni* per impostazione predefinita. Si stampa su ogni fattura ed è il punto di partenza delle regole di sollecito.

#### Interessi di mora

Gli interessi che un pagamento tardivo comporta. Tra professionisti la menzione è obbligatoria; il valore predefinito enuncia il tasso legale in vigore. Un'associazione non stampa nulla qui finché non scrivi qualcosa.

#### Indennità di recupero

I **40 €** forfettari dovuti per spese di recupero su un ritardo tra professionisti. Stessa regola: obbligatoria tra professionisti, tolta per un'associazione, sempre stampata se la scrivi.

#### Sconto per pagamento anticipato

Se pagare in anticipo dà diritto a uno sconto. La maggior parte degli spazi non ne concede alcuno, e il valore predefinito lo dice con le parole che la legge si aspetta — dire *nessuno sconto* è di per sé una menzione obbligatoria tra professionisti.

#### Assicurazione professionale

L'assicuratore, la polizza e la sua copertura geografica. Richiesta alle professioni regolamentate; vuota non stampa nulla.

#### Menzioni particolari

Tutto ciò che il tuo mestiere o il tuo paese esige in più, stampato dopo le altre. Il posto per un numero di socio, un organismo di mediazione o una clausola richiesta dal tuo commercialista.

#### Regime IVA

Se lo spazio è **fuori campo IVA**, **esente** per un regime di piccola impresa, o **soggetto**. Decide quale numero la norma EN 16931 esige da te e quale frase di legge un documento stampa. Il regime è **congelato su ogni documento all'emissione**: modificarlo non riscrive mai una fattura già inviata.

#### Partita IVA

Il numero intracomunitario, verificato nella forma usata dal suo paese. È ciò che serve a un documento prima dell'invio quando applichi l'IVA, e ciò che prova che l'imposta spetta al cliente in caso di inversione contabile.

#### Conto IVA

Il conto del piano dei conti su cui è imputata l'IVA riscossa. Le esportazioni contabili e i prospetti del commercialista lo seguono.

#### Motivo dell'esenzione

La frase che un venditore esente o fuori campo deve stampare. Lasciata vuota, DesKilo stampa la formula di legge del tuo paese — *art. 293 B du CGI* in Francia, *§ 19 UStG* in Germania, la Direttiva altrove.

#### Numero di iscrizione

SIREN, SIRET, HRB, CIF — l'identificativo che la norma esige da un venditore che non applica l'IVA. Senza di esso una fattura elettronica di uno spazio fuori campo non può essere emessa.

#### Indirizzo strutturato

Via, codice postale e città in tre campi distinti, accanto all'indirizzo libero della carta intestata. La carta intestata è ciò che stampa un documento cartaceo; **l'indirizzo strutturato è ciò che porta la fattura elettronica**, perché una macchina non sa spezzare una riga in modo affidabile.

### 11b. Dove deve andare la fattura elettronica (UE)

L'azione **fattura elettronica (XML)** apre un foglio che risponde alla domanda per il paese dello spazio, prima di consegnarti il file: su quale canale la aspettano i clienti business, se una piattaforma si mette in mezzo e quale canale usano gli acquirenti pubblici. Nell'Unione convivono quattro modelli:

- **Peppol** — un access point consegna il file al cliente; nessuna piattaforma pubblica nel percorso. Così funziona esattamente l'obbligo B2B belga, ed è tramite Peppol che si raggiungono gli acquirenti pubblici in tutta l'UE (la direttiva 2014/55/UE rende ogni amministrazione capace di ricevere una fattura EN 16931).
- **Piattaforme accreditate** — la Francia: scegli una *plateforme agréée* (l'ex PDP), che instrada la fattura e comunica i dati all'amministrazione fiscale. Il portale pubblico è un elenco, non una casella. Le fatture verso il settore pubblico restano su **Chorus Pro**.
- **Piattaforme di clearance** — l'Italia (**SdI**, FatturaPA), la Polonia (**KSeF**, FA(3)), la Romania (**RO e-Factura** tramite lo SPV, CIUS-RO): la piattaforma riceve la fattura *per prima* e poi la inoltra; inviarla direttamente al cliente non è un'opzione. Ognuna impone la propria sintassi, perciò il foglio avvisa che il file EN 16931 esportato da DesKilo non è quello che accettano — usalo per Peppol, gli acquirenti pubblici e i clienti esteri, e lascia convertire alla tua piattaforma o al tuo commercialista.
- **Nessun canale imposto** — la Germania oggi: ricevere è obbligatorio dal 2025 ed emettere arriva a scaglioni, ma un allegato via e-mail è una fattura elettronica valida; XRechnung e ZUGFeRD sono le sintassi attese. Settore pubblico: **OZG-RE / ZRE**, oppure Peppol.

**Factur-X — un file, due lettori.** Il foglio della fattura elettronica propone per primo **Factur-X (PDF)**: un PDF di fattura dall'aspetto normale con la fattura leggibile dalle macchine *al suo interno* (i dati EN 16931 in CII, che è ciò che il formato impone). Una persona lo apre e vede la fattura; una piattaforma lo apre e trova `factur-x.xml`. È ciò che la maggior parte delle piccole imprese francesi e tedesche si scambia davvero, e non richiede un secondo file. L'**XML** semplice resta disponibile sotto, per le piattaforme che lo chiedono nudo.

**Inviarla senza uscire dall'app.** Il proprietario registra la piattaforma dello spazio in *Identità legale → **Piattaforma di fatturazione elettronica***: un **URL di caricamento**, un **token o credenziale**, facoltativamente la forma dell'**header di autenticazione** e il **nome del campo file**. Va bene qualsiasi piattaforma che accetti un upload con una credenziale — una *plateforme agréée*, un access point Peppol, una piattaforma nazionale. Il token resta sul server, non torna mai su un telefono, e l'app può solo dirti che ne esiste uno. Una volta configurata, il foglio della fattura elettronica inizia con **Invia alla piattaforma**: il documento Factur-X parte direttamente, e il foglio di dettaglio della fattura registra quando è partito, cosa ha risposto la piattaforma e l'identificativo restituito. Ogni tentativo viene registrato — accettato, rifiutato o non trasmesso — perché un documento che *forse* è partito è peggio di uno che ha fallito.

**Una seconda tratta, dritta al cliente.** Raggiungere la piattaforma pubblica non è la stessa cosa che raggiungere l'acquirente, e diversi clienti gestiscono un proprio servizio di ricezione. Per questo la stessa schermata accetta una **seconda destinazione** — l'endpoint del cliente, con URL, token, forma dell'header di autenticazione e nome del campo file propri — e il foglio d'invio propone allora entrambe le tratte, ciascuna con la sua cronologia di trasmissione. Viaggia sulla funzionalità **Invio della fattura elettronica al cliente**, sotto *Fatture*; lasciala disattivata ed esiste solo la tratta verso la piattaforma, esattamente come prima.

**Provare senza rischi.** La stessa schermata accetta **endpoint di prova** (lo UAT della piattaforma o una destinazione dev: URL + token ciascuno) accanto a quello di produzione. Con la **modalità sviluppatore** dello spazio attiva (un'impostazione a livello di spazio che solo proprietari e admin possono cambiare, in Impostazioni → Avanzate), l'invio offre la scelta dell'ambiente, un invio di prova è marcato come tale nella cronologia delle trasmissioni della fattura, e l'endpoint di produzione non viene mai usato per una prova — un ambiente di prova non configurato semplicemente rifiuta, senza ripiegare.

DesKilo continua a non trasmettere nulla per proprio conto: produce il documento e lo consegna alla piattaforma che hai scelto. I calendari degli obblighi continuano a muoversi: verifica con la tua amministrazione fiscale prima della scadenza che ti riguarda.

#### La piattaforma di fatturazione elettronica

Dove viene trasmessa una fattura strutturata, e con quali credenziali.
Un documento può andare a **due destinazioni insieme**: la piattaforma
imposta dal tuo paese e il servizio proprio del cliente. Entrambe
possono restare vuote. Le credenziali vivono sullo spazio e non entrano
mai in un file di spazio né in una distribuzione: un export che mandi a
un collega porta la configurazione, non le chiavi.

#### URL di invio

L'indirizzo a cui la fattura viene inviata. Copialo dalla documentazione
della piattaforma — una barra finale o un segmento di versione mancante
è il motivo abituale di una trasmissione che fallisce senza nulla di
utile da leggere.

#### Token o credenziale

Il segreto che ti identifica presso la piattaforma. Una volta salvato
non viene più mostrato, nemmeno a te: lo schermo dice *impostato* e
nient'altro. Riscrivilo per sostituirlo, lascialo vuoto per
conservarlo.

#### Intestazione di autenticazione

L'intestazione HTTP in cui viaggia il token — `Authorization` per la
maggior parte delle piattaforme, un nome proprio del fornitore per
alcune. Se la documentazione mostra `Bearer <token>`, metti qui il nome
dell'intestazione e il token nudo sopra.

#### Nome del campo file

Il nome del campo di modulo multipart sotto cui il documento viene
caricato. Le piattaforme differiscono (`file`, `invoice`, `document`), e
sbagliarlo produce un rifiuto che non nomina alcun campo.

#### URL e token UAT

L'ambiente di collaudo della piattaforma, dove una trasmissione vera può
essere provata contro una validazione vera senza emettere nulla.
Compilali prima del primo invio reale, non dopo.

#### URL e token di sviluppo

L'endpoint che usa uno **spazio di sviluppo**. Non può raggiungere una
piattaforma governativa: è questo che rende una fattura di prova
impossibile da confondere con una reale.

### 11c. L'editor di report — ogni documento, quattro modelli, cinque lingue

Il **Modello PDF della fattura** (icona matita nell'intestazione Fatture, o *Impostazioni dello spazio*) è uno strumento di reporting a bande per ogni documento che l'app stampa. Tre **bande** di report vengono rese sul PDF — intestazione, corpo (le righe della fattura), piè di pagina — mentre l'XML della fattura elettronica non viene mai toccato.

- **Campi e marcatura, come guida (#966)** — in modalità marcatura la lunga fila di tutti i campi è sparita. Un solo pannello, *Campi e marcatura*, chiuso finché non lo aprite, contiene: due frasi su come funziona una banda; **Inserisci un campo…**, il selettore con ricerca raggruppato per tema (documento, cliente, venditore, importi, coordinate bancarie, diciture legali, consumo, IVA, sedi, situazione, cicli, i vostri testi) con un significato di una riga sotto ogni nome, ricercabile anche per quel significato; la **marcatura di riga**, un segno per riga con il suo effetto; e tre **pezzi pronti** (una riga solo se il valore esiste, una riga per ogni riga di fattura, il titolo che dice fattura, nota di credito o proforma). Tutto ciò che toccate finisce al cursore della banda modificata per ultima.

- **Un report per documento**: i chip passano tra **Fattura · Proforma · Estratto · Accordo · Pagamenti · Spazio · Livelli di sollecito**. La proforma ripiega sulle bande della fattura finché non la personalizzi; un estratto personalizzato sostituisce il PDF mensile integrato.
- **Per lingua**: una seconda fila di chip — *Predefinito (tutte le lingue)* · EN · FR · DE · ES · IT — memorizza una traduzione per documento; il report di un membro viene stampato nella *sua* lingua quando esiste un modello per essa, altrimenti nella lingua predefinita dello spazio.
- **Markup o Visuale**: la modalità **Markup** modifica le bande come testo — condizioni e cicli [Liquid](https://shopify.github.io/liquid/) (`{{ number }}`, `{% if proforma %}…{% endif %}`, `{% for line in lines %}…{% endfor %}`) più un markup di riga semplice: `#` titolo, `##` sezione, `>` testo piccolo, `---` divisore, `a | b` riga di tabella, `=` riga in grassetto, `::: … ||| … :::` colonne affiancate (il blocco indirizzi venditore-a-sinistra / cliente-a-destra e i totali allineati a destra di una facture francese — i modelli forniti seguono esattamente questa struttura), `![name]` un'immagine dalla **libreria immagini** dello spazio (*Inserisci immagine*). La modalità **Visuale** è una superficie di progettazione fedele alla pagina, nella tradizione degli strumenti professionali (Crystal Reports, Docentric): le tre bande si modificano **su una pagina A4 bianca** ai margini del documento, nella sua esatta tipografia di stampa — stesso font, dimensioni, colori e colonne degli importi allineate a destra del PDF generato — con strisce di banda etichettate, guide tratteggiate di cambio pagina e zoom (adatta, 75/100/150 %). I `{{ token }}` restano evidenziati; tocca una riga per modificarla sul posto, aggiungi, sposta, inserisci campi dalla tavolozza. Un interruttore **Progetto ↔ Anteprima** fonde le bande non salvate con i tuoi dati reali (o di esempio) attraverso il vero motore, sulla stessa pagina — via i campi, dentro i valori.
- **Galleria di modelli** (*Modelli*): quattro modelli pronti per ogni documento — **Classico · Semplice · Dettagliato · Lettera formale** — scegline uno ed estendilo. Ogni modello di fattura porta già le menzioni obbligatorie (§11a).
- **Designer a schermo intero** (opzione *Designer di report*): l'editor si apre come **pagina a sé**, in modalità Visuale, con **Annulla / Ripeti** e **Salva** nella barra. Tocca un elemento e lo modifichi **nella sua tipografia**: il titolo in dimensione titolo, le righe piccole in piccolo. Il **+** sotto l'elemento attivo inserisce sotto un **elemento tipizzato** (titolo, sezione, testo, righe piccole, riga di tabella, separatore, spazio, immagine, colonne, logica); il pulsante **{ }** apre un **selettore di campi con ricerca**, raggruppato per documento, membro, importi, menzioni legali e cicli; **tieni premuto e trascina** una riga per riordinarla, e il suo menu la manda in **un'altra banda**. Un'immagine porta la sua **dimensione** (piccola, media, grande) e il suo **allineamento** (sinistra, centro, destra), scritti `![nome|l|center]`. *Modelli* e *Ripristina* chiedono conferma prima di sostituire un layout esistente; anche uscire con lavoro non salvato chiede. Quando un modello non si genera, l'anteprima **dice quale banda e perché** invece di un errore generico. Su schermo largo **progettazione e anteprima sono affiancate**, e la pagina conta su quante pagine verrà stampato il documento. I tre documenti strutturali — **Piano dei conti · Badge dei membri · Schede QR degli spazi** — hanno i propri chip.
- L'**anteprima rapida** rende il risultato all'istante nell'app — la tua fattura più recente, o dati di esempio simulati quando non ce n'è (filigranati *dati di esempio*) — senza passare da un PDF; **Anteprima** produce il PDF; **Ripristina** riconsegna il layout integrato come esempio funzionante. Un modello rotto non blocca mai un documento — subentra il layout integrato; la filigrana di annullo, la firma digitale, l'allegato e i numeri di pagina restano fissi.

Variabili di modello (famiglia fatture): `{{ number }}`, `{{ member }}`, `{{ workspace }}`, `{{ workspace_address }}`, `{{ period }}`, `{{ period_month }}`, `{{ period_year }}`, `{{ issued }}`, `{{ issued_by }}`, `{{ replaces }}`, `{{ total }}`, `{{ charges }}`, `{{ payments }}`, `{{ voided }}`, `{{ proforma }}`, `{{ copy }}`, `{{ lines }}` (ognuna con `label`, `kind`, `pct`, `month`, `unit_price`, `qty`, `net`, `vat_rate`, `amount`), `{{ has_vat }}`, `{{ vat }}`, `{{ net_total }}`, `{{ vat_total }}`, `{{ credit_note }}`, `{{ refund_total }}` — e l'insieme legale: `{{ seller_legal_form }}`, `{{ seller_registration }}`, `{{ seller_vat_id }}`, `{{ seller_legal_id }}`, `{{ exemption_reason }}`, `{{ client_address }}`, `{{ client_vat_id }}`, `{{ client_legal_id }}`, `{{ payment_terms }}`, `{{ late_penalty }}`, `{{ recovery_indemnity }}`, `{{ escompte }}`, `{{ insurance }}`, `{{ special_mentions }}`.

![](assets/help/images/report-designer-markup.jpg)

*La modalità Markup: le tre bande come testo, la legenda delle variabili, i chip per documento e per lingua.*

![](assets/help/images/report-designer-design.jpg)

 

![](assets/help/images/report-designer-preview.jpg)

*La modalità Visuale — Progettazione modifica le bande etichettate sulla vera pagina A4; Anteprima fonde le bande non salvate con i dati reali tramite il vero motore.*

#### Il modello PDF di fattura

Con quale progettazione viene stampata una fattura, e i testi che quella
progettazione porta. Una progettazione esiste per tipo di documento e per
lingua; chi non ha una lingua propria riceve quella dello spazio.

#### L'editor dei report

Dove si scrive la progettazione di un documento. Due vie d'ingresso: le
**bande** — testata, corpo, continuazione, piede, un segno per riga — e
un **layout posizionato** in XML per un documento che deve soddisfare
una busta a finestra o un modulo ufficiale. Un layout vince sulle bande
per il tipo su cui è impostato.

### 11d. La suite di report e la biblioteca documenti

- **Accordo finanziario** — ogni prezzo in vigore che si applica a un membro: abbonamento, mezza giornata extra, servizi, pacchetti, supplementi accessori e i prezzi degli spazi interi, **tavoli compresi**. Proprietari/admin lo inviano dalla scheda azioni di un membro; ogni membro può vedere in anteprima/scaricare/condividere il proprio da *Finanze → Documenti*.
- **Report dei pagamenti** — tutto ciò che hai pagato, dichiarato o fatto convalidare in un mese: il tuo piccolo bilancio, self-service sulla stessa riga.
- **Report dello spazio** — identità, conteggi della piantina, disponibilità, funzionalità e prezzi: *Impostazioni dello spazio → Report dello spazio*.
- **Biblioteca documenti** — *Impostazioni → Documenti*: lo statuto dello spazio, le guide, i bilanci e i verbali, COLLEGATI dal sistema che già usi — Google Drive, OneDrive, SharePoint, Dropbox, Nextcloud o qualsiasi link https (il drive continua a gestire i propri permessi; l'app non conserva mai credenziali altrui). Ogni voce ha un **ruolo di visibilità**: tutti i membri, admin e proprietari, o solo proprietari — applicato lato server, così un membro non scarica nemmeno un elenco che contiene documenti del consiglio. Admin e proprietari curano con il pulsante +; l'interruttore della funzionalità *Biblioteca documenti* attiva il tutto.

![](assets/help/images/documents-library.jpg)

 

![](assets/help/images/documents-add-dialog.jpg)

*La biblioteca di documenti, e l'aggiunta di un documento: titolo, link, archiviazione, categoria, visibile da.*

#### Titolo del documento

Ciò che la biblioteca mostra e per cui un membro cerca. È l'unica parte
di una voce che qualcuno legge: scrivila per lui.

#### Collegamento

L'indirizzo `https://…` dove vive il documento. DesKilo conserva il
collegamento, non il file: per questo il documento mantiene le regole di
accesso che impone il suo stesso servizio.

#### Conservato su

Quale servizio lo detiene — un disco, un wiki, un file server. È
un'etichetta per chi legge, non una connessione: nulla viene scaricato
per te.

#### Categoria

Come la biblioteca raggruppa la voce. Le categorie le inventi tu;
l'elenco propone quelle che lo spazio usa già.

#### Visibile a

Quali ruoli possono vedere la voce. Lo impone il server, non è solo
nascosta nell'elenco: un membro senza il ruolo non riceve la riga.

### 11e. Solleciti di pagamento automatici

Con **Solleciti di pagamento automatici** attivo (Funzionalità, figlio di *Solleciti di pagamento*) e l'interruttore **Solleciti automatici** nelle regole di sollecito (Fatture → Regole di sollecito), i livelli si applicano da soli: ogni mattina — e ogni volta che un proprietario o un admin apre Finanze — una fattura **aperta** il cui termine è trascorso (i *giorni prima del primo sollecito* dall'emissione, poi i *giorni tra i solleciti* dopo il precedente) riceve il livello successivo. Il membro vede un avviso **Promemoria di pagamento** in Eventi («Sollecito 2: fattura X — importo ancora dovuto») e riceve una notifica; la sua vista Fatture legge *scaduta da N giorni*. I livelli non superano mai il numero configurato; una fattura riconciliata non è mai sollecitata; con l'interruttore spento, sollecitare resta manuale, una fattura alla volta come prima.

#### Regole di sollecito

Quanti solleciti riceve una fattura non pagata, a quanto dalla scadenza
parte ciascuno, e cosa dice ciascuno. Una volta al giorno le fatture
aperte scadute passano al livello successivo; un livello già raggiunto
non viene mai rinviato.

#### Solleciti automatici

Spento, i solleciti si inviano a mano. Acceso, una volta al giorno ogni
fattura aperta scaduta passa al livello successivo e invia ciò che quel
livello dice. Un livello già raggiunto non viene mai inviato due volte,
quindi accenderlo non sommerge nessuno con l'arretrato.

### 11f. Raggruppare fatture (saldo)

**Un documento invece di tre.** Un membro nel ciclo di fatturazione diviso (§11) può avere insieme una fattura di abbonamento, una di fine mese e il residuo del mese precedente. **Raggruppa in una fattura** (icona unione nell'intestazione Fatture, funzionalità *Raggruppa fatture*) ripiega le fatture aperte e non pagate di un membro in una sola fattura di **saldo** con la loro somma. Le fonti **non vengono annullate**: restano in archivio esattamente come emesse, ognuna punta al saldo che ora ne porta il residuo, e il saldo elenca ogni fonte con le sue voci. Da quel momento è il saldo a essere dovuto, pagato e sollecitato; una fonte non può più essere annullata, sostituita o abbinata da sola. L'IVA non viene ridichiarata — ogni fonte ha già dichiarato la sua imposta, quindi le righe del saldo portano 0 % e nominano le fatture che la portano.

**Validato come ogni pagamento.** Un saldo è un evento *pagamento fattura*: dove il proprietario ha messo una regola su quel dominio (§7), attende i validatori; un **rifiuto** — o una scadenza — annulla il documento di saldo e libera le sue fonti, di nuovo dovute separatamente. **Annullare** un saldo (*Segna come errata*) libera le sue fonti allo stesso modo.

**Le fatture raggruppate si ripiegano sotto quella di raggruppamento (#831).** La fattura di raggruppamento porta ora **tutte le righe delle fatture che sostituisce**, raggruppate sotto i loro numeri, con la loro IVA: basta a sé stessa ed è quella dovuta, sollecitata, abbinata e chiusa. Le fatture raggruppate lasciano la lista delle aperte, l'archivio e la lista del membro come pari e **si annidano sotto la fattura di raggruppamento** («Raggruppata in INV-…»), nell'hub e dal lato del membro. Aprendone una, un banner lo dice; ogni operazione è disattivata; resta solo il suo **PDF, timbrato con il numero in cui è stata raggruppata**. Per il commercialista il documento di raggruppamento è trasparente: ogni esportazione e la dichiarazione IVA portano le fatture originali, e il pagamento ricevuto sul raggruppamento viene loro assegnato, dalla più vecchia alla più recente — ogni originale è saldata esattamente come se fosse stata pagata da sola. Nell'app un originale si legge «Pagata tramite INV-…» quando il suo raggruppamento è pagato. Scaricando, condividendo o visualizzando in anteprima una fattura di raggruppamento, viene chiesto se allegare le fatture sostituite: allegate, ognuna segue su pagine proprie, dopo la nuova e senza sovrapporsi, timbrata come raggruppata.

### 11g. L'assistente di chiusura mensile

I tre assistenti — **chiusura mensile**, **raggruppare in una fattura**, **ripartire una spesa** — hanno la stessa forma (#872): passi numerati in alto, il contenuto del passo, poi **Indietro · i / n · Avanti** e un'azione finale all'ultimo passo. Si impara una volta; ogni voce della barra si chiama *Assistente · …*.

L'**assistente di chiusura** (opzione *Assistente di fatturazione*; la bacchetta nell'intestazione Fatture o la scheda in cima a *Da fatturare*) mette in fila tutto il lavoro di fatturazione in **un solo processo guidato** con una barra di passi: **Revisione** (quale giro, quale periodo, cosa è in sospeso), **Emetti** (le fatture del giro in un blocco: i membri già coperti compaiono fatti, deseleziona per escludere), **Invia** (condividi o scarica ogni PDF), **Sollecita** (tutto ciò che è in ritardo secondo le tue regole, registrato e notificato con un tocco, la lettera per riga), **Pagamenti** (conferma o rifiuta ciò che i membri hanno dichiarato; **registra** un bonifico o un contante per un membro, che lo conferma dalla sua parte), **Abbina** (ogni fattura aperta contro il credito del membro; le righe con credito sono pronte), **Chiudi** (raggruppa più fatture di un membro in una, stralcia un resto, rimborsa una nota di credito, ognuna con convalida) e **Riepilogo** (cosa ha fatto il giro e cosa resta aperto con a chi tocca). Due giri: **Inizio mese** per gli abbonamenti pagati in anticipo (suggerito dalla tua finestra di anticipo), **Fine mese** per utilizzo, consumi e costi aggiuntivi del mese chiuso.

### 11h. Spese condivise, ripartite

**Ripartisci una spesa** (opzione *Spese condivise*; l'icona di ripartizione nell'intestazione Fatture) prende un costo comune — pulizie, potenziamento internet, una sedia rotta — e lo ripartisce tra i membri: quote **uguali**, **in proporzione all'abbonamento**, **in proporzione all'utilizzo** (mezze giornate usate nel periodo) o una **chiave personalizzata** per membro. Ogni quota è in anteprima, i centesimi tornano esatti e nulla viene registrato prima della conferma. Le quote sono registrate come righe di rettifica sul periodo scelto e compaiono così sulla **prossima fattura di utilizzo** di ogni membro (il giro di fine mese dell'assistente, §11g). Attiva **Storno** per restituire denaro: la stessa ripartizione registra **crediti**, che si compensano con gli addebiti del mese e, se li superano, producono una **nota di credito** che lo spazio rimborsa (§11). Una ripartizione è un evento a sé: con una regola di convalida su *Spesa condivisa* attende il quorum e si registra una volta confermata; senza regola vale la decisione di chi emette. La cronologia sotto il modulo mostra ogni ripartizione e il suo stato.

### 11i. Utilizzo: quanto è costata davvero ogni prenotazione

**Utilizzo** (funzione *Rilevamenti di utilizzo*; una faccia della scheda Finanze) mostra le prenotazioni conteggiate del mese, una scheda ciascuna, con tre numeri volutamente distinti: la finestra **prenotata**, il tempo in cui eri davvero **presente** e quanto di esso viene **fatturato**. La prenotazione è l'impegno; la presenza è il fatto.

Ne discendono due regole, e le schede le dicono entrambe apertamente. Una prenotazione **a cui non è venuto nessuno è fatturata per intero** — non presentarsi non è uno sconto. E anche una prenotazione lasciata **in anticipo** è fatturata per intero, finché qualcun altro non accetta il contrario: la scheda propone **Fattura il tempo in cui c'ero**. Quella richiesta non la decidi mai tu; va a chi la regola di convalida *Uscita anticipata* indica, e senza regola vale subito. Accettata, la fine della prenotazione stessa si sposta al momento dell'uscita, così estratto conto, tetto delle mezze giornate e fattura seguono — e la scheda continua a dire quanto il tempo fatturato **era**.

Vedi i tuoi rilevamenti; chi può vedere il denaro dello spazio li vede tutti. Un admin o la proprietà può **rimuovere** un rilevamento, e dove è configurata una regola *Rimozione del rilevamento*, a convalidarla è il membro interessato.

### 11j. Portare fuori un modello di report e restituirlo

**Esporta questo modello** (funzione *Esporta e importa i modelli di report*, nell'editor dei report) scrive l'impaginazione del report aperto in un file JSON. **Importa un modello** ne rilegge uno.

Il file non è un semplice dump. Accanto alle tre bande porta un blocco `howToEdit` che dice a cosa serve ogni banda, la sintassi Liquid, ogni riga di markup accettata dal renderer, dimensioni e allineamenti delle immagini e l'elenco completo dei segnaposto: quanto basta perché una persona, o uno strumento come Claude, lo apra, ne cambi l'impaginazione e lo restituisca senza indovinare. Il blocco è rigenerato a ogni esportazione, quindi modificarlo non ha effetto; in ingresso si leggono solo `kind`, `language` e `design`.

Ogni report ce l'ha — fattura, proforma, estratto, accordo, report dei pagamenti, report dello spazio, piano dei conti, badge, schede QR e ogni livello di sollecito — e un report aggiunto in seguito lo ottiene automaticamente.

Un'importazione è **rifiutata con la motivazione** se il file non è JSON leggibile, non è un modello DesKilo, viene da una versione più recente, riguarda un report che questo spazio non ha, o appartiene a un **altro** report: un modello non viene mai reindirizzato in silenzio. Un'importazione accettata arriva nell'editor, non nello spazio: nulla cambia finché non premi **Salva**.

### 11k. I tuoi testi, per lingua (#880)

Alcune formulazioni sono tue, non del design: un saluto, una nota stagionale, un paragrafo legale, il nome della banca. Il pannello **Testi** in fondo al designer dei report le tiene come `chiave → valore`. **Aggiungi un testo** chiede una chiave (lettere, cifre, trattini bassi — `saluto`), poi scrivi il valore; qualsiasi banda o layout posizionato lo stampa con il campo `text.saluto` tra doppie graffe, offerto dal selettore dei campi sotto **I tuoi testi**. Cambia il valore e ogni documento cambia — il design non viene toccato. Con un chip di lingua selezionato il pannello modifica i valori di quella lingua; uno vuoto ricade sulla lingua predefinita, esattamente come i documenti. Una chiave che nessuno ha compilato non stampa nulla (e una condizione su di essa resta falsa). Un file di layout esportato porta i testi della sua lingua in un elemento `<texts>`; l'importazione li riporta.

### Layout posizionati (XML)

Un report può essere descritto da un **layout** che indica dove si trova ogni elemento — in millimetri, centimetri, pixel o in percentuale del suo contenitore — invece che da bande in sequenza. Quando un documento ha un layout, è quello che si stampa; altrimenti si stampano le sue bande come prima. I due convivono: si migra un documento alla volta.

**Il ciclo**: nel designer dei report, **Esporta XML**; modifica il file (tu o Claude); verificalo in locale; **Importa XML**; salva. Il file esportato contiene le proprie istruzioni: le zone (intestazione a pagina 1, striscia nelle pagine successive, destinatario nella finestra della busta, corpo, piè di pagina fisso su ogni pagina), gli elementi, le unità e i campi disponibili.

**Verifica prima di importare** — senza avviare l'app:

```
dart run tool/report.dart check mio-layout.xml
```

Il comando stampa la posizione di ogni zona in millimetri e conclude con **CONFORMS** oppure elenca le deviazioni (indirizzo fuori dalla finestra, testo nella fascia 45–90 mm, pagina senza piè di pagina…). Apri il PDF, piegalo, infilalo in una busta DL a finestra.

**Immagini**: `<image name="logo" h="12mm"/>` inserisce un'immagine dalla libreria del report; compare nell'anteprima e si stampa nel PDF.

## 12. Impostazioni e profilo

La tua schermata personale, dall'alto in basso:

![](assets/help/images/settings-personal.jpg)

*Il blocco personale: profili, foto, regione e formati, WhatsApp, stato, periodo di prenotazione predefinito, indirizzo, aiuto, badge.*

![](assets/help/images/settings-admin.jpg)

*Per i proprietari segue la sezione Amministrazione — ogni schermata di amministrazione del §8 parte da qui.*

![](assets/help/images/settings-preferences.jpg)

*Preferenze e Avanzate: lingua, tema, scansione con fotocamera frontale, stato del push, modalità sviluppatore.*

![](assets/help/images/settings-about.jpg)

*Informazioni: versione, autore, la licenza open source, l'informativa sulla privacy, le segnalazioni di bug e come sostenere il progetto.*

![](assets/help/images/profiles.jpg)

 

![](assets/help/images/region-formats.jpg)

 

![](assets/help/images/linked-accounts.jpg)

 

![](assets/help/images/settings-language.jpg)

*Quattro delle schermate personali: Profili, Regione e formati, Account collegati e il selettore della lingua.*

![](assets/help/images/settings-whatsapp-dialog.jpg)

 

![](assets/help/images/settings-status-dialog.jpg)

 

![](assets/help/images/settings-address-dialog.jpg)

 

![](assets/help/images/settings-default-period-dialog.jpg)

*I quattro dialoghi personali: numero WhatsApp, riga di stato, indirizzo postale, periodo di prenotazione predefinito.*

![](assets/help/images/settings-theme-dialog.jpg)

 

![](assets/help/images/settings-photo-sheet.jpg)

 

![](assets/help/images/developer-screen.jpg)

*Tema, la scheda foto e la schermata delle tracce Sviluppatore.*

**Privacy e dati (#719)** — chi può vedere i tuoi dati, chi l'ha fatto, esportazione, cancellazione, la politica. Vedi §14.

**Regione e formati (#711).** Come *tu* leggi ciò che lo spazio mostra: **numeri e date** nella regione che scegli (`it_CH`, `en_GB`, `de_AT`… indipendente dalla lingua dell'app), l'**orologio** (24 h, 12 h o ciò che fa quella regione) e se gli orari appaiono nel **fuso dello spazio** — quello delle prenotazioni, il predefinito — o **nel tuo**, segnalato dove i due differiscono. Una riga di anteprima mostra la somma delle tre scelte. La valuta resta quella dello spazio; solo la sua scrittura è tua. Salvato sul tuo profilo: ti segue da un dispositivo all'altro.

- **Profili** (§1) e la tua **foto** (tocca per cambiare — scegli o rimuovi). In uno spazio con più sedi, il profilo indica anche la vostra **sede di riferimento** — l'indirizzo che portano i vostri documenti e i piani che sono vostri per impostazione predefinita — e un tocco su di essa vi lascia cambiare sede da soli (#974).
- **Il mio account** (#1307) — chi sei e come l'app ti parla, in tutti i tuoi spazi: la tua **foto**; **Informazioni personali** (o **Indirizzo**) — il tuo indirizzo postale (stampato sulle tue fatture), il paese e la partita IVA facoltativa; **WhatsApp** — il tuo numero, visibile agli altri membri solo se lo imposti (§6); **Regione e formati**; **Account collegati** — collega un accesso Google al tuo account email; **Il mio badge** (§8); **Lingua** (predefinita di sistema o una delle cinque); **Tema** (sistema / chiaro / scuro); **Navigazione** (predefinito del dispositivo, la barra inferiore classica con il pulsante rotondo, o il menu come sul web — sul web il menu è l'unica navigazione, quindi la scelta non è offerta lì); e **Mostra di nuovo i suggerimenti di aiuto**, che riporta indietro ogni suggerimento contestuale che avevi chiuso. Quei suggerimenti sono piccoli caroselli sui moduli stessi: scorri avanti e indietro tra più suggerimenti per schermata, ognuno con un collegamento *Scopri di più* che salta direttamente alla sezione corrispondente di questa guida.
- **La mia iscrizione** — il tuo posto in *questo* spazio: **Stato** — una riga libera (40 caratteri) mostrata nell'elenco; **Periodo di prenotazione predefinito** (la finestra su cui si aprono le schede di prenotazione, così la tua solita mezza giornata o il tuo solito da–a è già compilato); le tue **Condizioni di pagamento**; **Documenti** — la biblioteca documenti dello spazio (§11d). L'elenco è la destinazione **Membri** della barra inferiore, non una voce qui.
- **Questo spazio**, **Amministrazione** e **Governance** — solo per chi detiene il permesso che ogni voce richiede (§8): come funziona lo spazio, la gestione dei suoi membri e dispositivi, e che cosa è lo spazio.
- **Avanzate** — questo dispositivo: il **server** con cui parla, lo stato delle sue notifiche push, **Scansiona con la fotocamera frontale** (per i tablet a parete), l'interruttore della **Modalità sviluppatore** a livello di spazio, la schermata delle tracce **Sviluppatore** (§8 pagamenti) e la **Modalità demo** (su questo dispositivo ogni nome, e-mail, telefono e indirizzo postale sullo schermo è sfocato sul posto — il testo reale, ammorbidito fino all'illeggibile, il layout intatto — così screenshot e registrazioni non portano dati personali; nulla è nascosto e ogni modulo resta modificabile).
- **Aiuto e informazioni** — **Aiuto**, la guida integrata nella tua lingua; la versione dell'app, l'autore (Florian DITTGEN), la licenza open source (0BSD) con il codice su GitHub, l'informativa sulla privacy, un link per segnalare bug, e come **sostenere il progetto** (PayPal, Revolut).
- **Esci**.

### Il tuo server — puntare l'app al Supabase della tua comunità

Per impostazione predefinita l'app dialoga con il proprio server, e qui non c'è nulla che richieda la tua attenzione. Ma il backend di DesKilo fa parte del codice sorgente — lo schema, le politiche di sicurezza a livello di riga e le funzioni edge — quindi una comunità può far girare **il proprio progetto Supabase** e tenere su di esso ogni singolo byte. **Impostazioni → Avanzate → Server** fa passare questo dispositivo dall'altra parte, senza ricompilare nulla:

1. **Crea un progetto** su supabase.com — il piano gratuito basta per iniziare.
2. **Installa lo schema**: esegui nell'ordine i file SQL di `supabase/migrations` presi dal repository del codice sorgente.
3. **Copia le credenziali**: nella dashboard Supabase, *Project Settings → API keys* contiene l'**URL del progetto** e la **chiave pubblicabile** (la chiave pubblicabile è fatta per stare dentro un client; a proteggere i dati è la sicurezza a livello di riga del server).
4. **Inseriscile** in Impostazioni → Server — incolla ogni campo, premi **Prova la connessione**, poi **Salva**.

**Crea una nuova istanza (#977).** La schermata Server porta anche un assistente per chi gestisce uno spazio di coworking, non un database. Create un account gratuito su supabase.com, fate lì un token di accesso personale (Account → Access Tokens) e incollatelo nell'assistente: elenca le vostre organizzazioni, crea il progetto nella regione più vicina al vostro spazio (o prende uno vuoto esistente), installa ogni migrazione dell'app in ordine con una barra di avanzamento, distribuisce ogni funzione, attiva la conferma via e-mail con i link dell'app consentiti e infine punta questo dispositivo al nuovo server — il QR della schermata Server porta poi i membri. Ogni passo si può ripetere da solo; il token non viene mai salvato. Ogni migrazione viene registrata mentre si installa (#1314): un'app chiusa o una connessione persa riprende da dove si era fermata senza mai eseguire due volte una migrazione, e la diagnosi (`dart run tool/instance.dart doctor`) vede lo schema sano. Un'istanza costruita prima non registrava nulla: `dart run tool/instance.dart record --ref … --through <NNNN>` segna le migrazioni che ha già senza eseguirle. Chi preferisce un terminale ha lo stesso costruttore: `dart run tool/instance.dart create --token … --org … --name …`.

**Usare un progetto esistente (#1308).** Scegliendo uno dei vostri progetti esistenti, prima si legge cosa contiene, senza modificare nulla: un progetto vuoto viene installato per intero; uno schema DesKilo con versione viene solo **aggiornato** con le migrazioni mancanti (o non richiede nulla se è aggiornato); un'installazione interrotta riprende. Un progetto il cui schema public contiene tabelle che DesKilo non crea mai, che usa un'altra versione principale di Postgres, che non è operativo o le cui migrazioni sono state registrate da un altro strumento **richiede attenzione**: il motivo viene mostrato, non viene eseguito nulla e *Scegli un altro progetto* riporta all'elenco. La stessa lettura trova le funzioni che il progetto ha già e se le impostazioni di accesso sono già corrette: riaprendo la procedura guidata su un progetto costruito a metà vengono distribuite solo le funzioni mancanti e si salta un passo di accesso già a posto. Prima che il dispositivo usi il nuovo server, l'ultimo passo esegue il **controllo di sicurezza** (lo stesso di `dart run tool/instance.dart doctor`): *Protetto* permette di proseguire, un allarme tiene disattivato **Usa questa istanza su questo dispositivo** e indica cosa correggere, un avviso viene mostrato senza bloccare. Un token di accesso personale apre tutto il vostro account Supabase finché esiste: la procedura lo dice prima che lo incolliate e ricorda alla fine che potete revocarlo; DesKilo non ne ha conservato alcuna copia.

Il test dice quale parte non va invece di limitarsi a fallire: *impossibile raggiungere quell'indirizzo*, *la chiave è stata rifiutata* oppure *le tabelle mancano* — quest'ultimo significa che il progetto ha risposto ma il passo 2 non è ancora stato fatto.

**I membri non digitano nulla di tutto questo.** Una volta che il dispositivo del proprietario è sul server della comunità, il **pulsante QR** di quella schermata mostra un codice; ogni membro lo scansiona nelle proprie Impostazioni → Server e finisce sulla stessa istanza.

**A chi appartiene il server, ed è aggiornato (#1309).** Per un progetto vostro la schermata lo nomina — *Il vostro progetto Supabase ‹ref›* — e dice a chi appartiene: alla vostra organizzazione Supabase. Il progetto è stato creato lì con il vostro token, che la procedura guidata ha tenuto solo in memoria: DesKilo non conserva alcun accesso e non può renderlo orfano. **Apri in Supabase** porta alla dashboard di quel progetto, dove Supabase chiede di accedere. Una riga di versione confronta lo schema del server con ciò che serve a questa app: *Aggiornato*, oppure *Serve un aggiornamento* con il modo di applicare solo ciò che manca. Dopo un test riuscito compare l'ora dell'ultimo. **Usa il server dell'app** cambia solo questo dispositivo e non tocca mai il vostro progetto Supabase.

Il cambio ti disconnette e ha effetto alla prossima apertura dell'app — la sessione apparteneva all'altro server. **Usa il server dell'app** riporta al predefinito in qualsiasi momento.

### Il tuo numero WhatsApp

Visibile ai membri dei tuoi spazi nella rubrica, così qualcuno può
raggiungerti senza uscire dall'app. Facoltativo, e cancellarlo lo toglie
ovunque in una volta.

### La tua riga di stato

Una riga breve accanto al tuo nome nella rubrica — *In chiamata · torno
alle 14:00*. La metti tu e la togli tu; nessun altro può cambiarla.

### Periodo di prenotazione predefinito

Quale metà della giornata una prenotazione presume quando non lo dici.
Preseleziona soltanto: ogni schermata di prenotazione ti lascia
scegliere, e la granularità dello spazio decide cosa siano le metà.

### Informazioni personali

Nome, cognome, azienda, l'indirizzo strutturato, telefono ed e-mail. È
ciò che stampa un documento che ti nomina come cliente: una fattura con
il solo nome visualizzato significa che questa schermata è vuota.

### Il tuo indirizzo

L'indirizzo in testo libero stampato sulle tue fatture. Dove esistono le
*Informazioni personali*, lo sostituiscono; il campo resta per gli spazi
che non hanno cambiato.

### La tua partita IVA

Compilala solo se ti viene fatturato come impresa. È ciò che decide se
una fattura transfrontaliera è emessa **senza imposta** in inversione
contabile — e il controllo della fattura elettronica rifiuta di inviare
un tale documento finché manca.

### Le tue condizioni di pagamento

Le condizioni che valgono solo per te, quando un amministratore ne ha
negoziate. Vuote, valgono quelle dello spazio.

### Ripristinare i suggerimenti

Riporta ogni suggerimento d'aiuto che hai nascosto. Nient'altro viene
azzerato.

### Il tuo badge

Il badge QR o NFC che ti identifica alla porta e sul chiosco. L'app
conserva solo un hash: un badge può essere revocato ma mai riletto, per
questo sostituire un badge perso significa emetterne uno nuovo, non
recuperare il vecchio.

### Il PIN del tuo badge

Un codice breve chiesto accanto al badge dove uno spazio vuole due
fattori. Protegge le azioni che il badge permette, non il badge stesso.

### Lingua dell'app

La lingua dell'app su **questo dispositivo**, indipendente dalla lingua
dello spazio e da quella dei tuoi documenti. Lasciala sull'impostazione
di sistema e segue il telefono.

### Tema

Chiaro, scuro o la miscela del marchio — anche questo per dispositivo.
L'impostazione di sistema segue l'interruttore chiaro/scuro del
telefono.

### Stile di navigazione

Se l'app naviga con una barra in basso o una guida laterale. Su schermo
largo la guida lascia più spazio alla piantina; sul telefono la barra è
più facile da raggiungere.

### Modalità dimostrazione

Sostituisce a schermo nomi e importi con altri plausibili, per mostrare
uno spazio a un visitatore senza mostrare gli affari di nessuno. Cambia
solo ciò che si vede: nulla viene toccato nei dati, e nulla di ciò che
fai si comporta diversamente.

### Fotocamera frontale per scansionare

Usa l'obiettivo anteriore invece del posteriore. Per un tablet a muro la
cui fotocamera posteriore guarda il muro.

### Profili

Un account, più spazi. Il selettore mostra ogni spazio a cui appartieni,
una coppia sviluppo/produzione come un'unica scheda con due chip, e
cambiare diventa la tua impostazione predefinita — un riavvio apre dove
eri rimasto.

### Numeri e date

Con quali convenzioni numeri e date sono scritti su **questo
dispositivo**. Separato dalla lingua dell'app di proposito: si può
volere un'app in inglese che scrive date italiane.

### Orologio

Dodici o ventiquattro ore. Cambia come si scrivono gli orari, mai cosa
significano.

### Mostrare gli orari nel mio fuso

Spento, gli orari sono quelli dello spazio — ciò che una prenotazione è
davvero. Acceso, vengono convertiti dove ti trovi. Utile in viaggio, e
meglio rispegnerlo prima di confrontare uno schermo con quello di un
collega.

### Il tuo server

Con quale progetto Supabase parla questa app. Per impostazione
predefinita quello di DesKilo; puntala a un progetto che ospiti tu e
l'app è tua da capo a fondo. Cambiarlo ti disconnette, perché un account
esiste su un server, non nell'app.

### Come ospitare il tuo

Il pacchetto costruisce un secondo database da ogni migrazione in
ordine, dalle edge function, dai bucket e dal seed. È questo a rendere un
DesKilo autoospitato identico a quello di riferimento anziché una
diramazione.

### Chi può vedere i miei dati

Cosa ogni ruolo, in ciascuno dei tuoi spazi, può leggere di te. È
l'enunciato di ciò che il server impone, non una serie di interruttori —
la risposta è la stessa che questa schermata sia aperta o no.

### Esportare i miei dati

Tutto ciò che DesKilo tiene su di te, come file che conservi. È prodotto
su richiesta anziché tenuto pronto, quindi dice ciò che è vero nel
momento in cui lo chiedi.

### Cancellare i miei dati

Toglie te e ciò che è tuo. Ciò che non si può cancellare è quanto la
legge impone allo **spazio** di conservare: una fattura emessa è un
documento dell'organizzazione e resta con l'identità di acquirente con
cui è stata emessa. La schermata dice quali spazi ne sono toccati prima
che accada qualcosa.

### I tuoi dati, i tuoi diritti

Cosa viene raccolto, perché, su quale base giuridica e per quanto viene
conservato. Un consenso richiesto è registrato con la sua data, così puoi
vedere a cosa hai acconsentito e quando.

## 13. Notifiche

Promemoria di check-in, conferme in sospeso, decisioni sulle spese — e quando un admin **rimuove una tua prenotazione** (scavalca), tu e gli admin venite avvisati. La consegna è prima locale; i push dal server arrivano senza configurare nulla su Android, iPhone/iPad, browser e macOS (Firebase Cloud Messaging) — *Impostazioni → Avanzate* mostra se il push è attivo su questo dispositivo. Il contatore sull'icona dell'app mostra le tue conferme in attesa **più i tuoi messaggi non letti** — su Android, iPhone/iPad, nel Dock di macOS, nella barra delle applicazioni di Windows e nelle web app installate. I messaggi tra membri vengono annunciati **una volta per dispositivo con il mittente e il testo completo** — compreso ciò che è arrivato ad app chiusa, annunciato alla prossima apertura. Quell'annuncio è sempre generato **in locale, dall'app stessa**: il payload push non trasporta mai un nome, un orario né una parola del messaggio (§6), quindi ciò che viaggia in rete dice soltanto che è arrivato qualcosa. Una conversazione **silenziata** (§16) resta muta: per lei non viene annunciato nulla, anche se conta ancora sulla sua riga e sul badge.

## 14. Privacy

**Consenso (#751).** La prima volta che un account apre l'app — e di nuovo quando questo testo cambia — una schermata di consenso lo mostra per intero: cosa viene trattato, cosa non si fa mai, chi può vedere cosa, chi è responsabile, per quanto tempo, i tuoi diritti e dove rileggerlo. Nient'altro è raggiungibile finché non spunti *Ho letto questo testo e accetto* — l'accettazione (versione e data) è registrata sul tuo account e ti segue tra i dispositivi. Rileggilo quando vuoi in **Impostazioni → Privacy e dati → I tuoi dati, i tuoi diritti**, qui nell'aiuto o sul wiki del progetto.

Dati minimi: nome, email, piano, prenotazioni, conto. Controlli tu la foto, lo stato e se il tuo numero di telefono è visibile nell'elenco; sulla piantina un tuo posto mostra un'iniziale, o la tua foto dove il proprietario ha attivato le foto dei membri. I badge del chiosco sono salvati solo come hash — un badge perso si revoca, non si indovina. Nessun tracciamento, nessuna analitica di terze parti. Le tue scritture di conto e le tue fatture **restano come sono** all'eliminazione dell'account — sono i documenti contabili dello spazio, non tuoi da ritirare, e la legge impone alla comunità di conservarli per il periodo di legge. Ciò che viene cancellato è il tuo profilo: nome, foto, numero WhatsApp, stato, indirizzo e partita IVA. Non vengono anonimizzate; il nome che compare su una fattura già emessa vi rimane.

**GDPR (#719).** DesKilo è costruita per il Regolamento generale sulla protezione dei dati: dati ospitati nell'UE, nessun tracciamento né analitica, accesso limitato per ruolo e applicato dal server, e quattro diritti che eserciti tu stesso in **lo scudo nella barra in alto (Privacy e dati)**: **chi può vedere i miei dati** (la regola per categoria e le persone che nomina), **chi ha consultato i miei dati** (un registro scritto dal server di ogni lettura delle tue finanze o messaggi da parte di altri — mai aggirabile), **esportare i miei dati** (un file JSON, art. 20) e **uscire con cancellazione** (art. 17: prenotazioni annullate, messaggi svuotati, profilo cancellato; i documenti contabili restano per la conservazione legale indicata nella politica, riferiti a un id, non a un nome). I messaggi li leggono solo le persone della conversazione, qualunque sia il ruolo; fatture e pagamenti solo tu e chi ha il permesso finanze.

## 15. Piattaforme

Android (Google Play), iPhone/iPad, desktop — **macOS** (un DMG: trascina DesKilo in Applicazioni) e **Windows** (un installer MSI) prodotti a ogni release — e il **browser**: la stessa app, niente da installare, all'indirizzo che il tuo spazio pubblica. I tuoi dati seguono il tuo account: una postazione prenotata dal telefono compare un secondo dopo in una scheda del browser.

Il browser fa più di quanto ti aspetteresti: **il Web NFC funziona** nei browser Chromium su Android in HTTPS, ed è un modo per configurare da un telefono il tag di una sedia — le app installate per **Android e iPhone leggono i tag direttamente**, di solito la via più comoda. Ciò che non può fare è scansionare un QR con la fotocamera come fa il chiosco. Tutto il resto — piantina, prenotazioni, membri, finanze, fatture, download dei PDF — è la stessa app. Al primo avvio del DMG macOS fai clic destro sull'app e scegli *Apri*: la build non è ancora notarizzata da Apple, quindi un doppio clic mostra un avviso di Gatekeeper.

## 16. Messaggi
La scheda **Messaggi** è il centro di messaggistica del tuo spazio: tutte le conversazioni in un elenco, la più recente in alto, persone e gruppi insieme. Una riga mostra l'ultimo messaggio, l'ora e quanti non hai letto. Tocca la **matita** per iniziarne una.

**Una persona o un gruppo, un solo foglio.** Scegli una persona per una chat privata; scegline due o più e **compare un campo per il nome** — quello è un gruppo. Il nome è **unico nel tuo spazio**, così nessuno deve indovinare a quale *Team* sta scrivendo; se è già preso l'app lo dice e cambi una parola.

**Distinguerli a colpo d'occhio.** Una persona mostra la sua foto in un cerchio. Un gruppo mostra un **distintivo quadrato** con un simbolo di gruppo e — finché nessuno ha scritto — quanti membri ha.

**Dentro una conversazione.** I messaggi si leggono dal più vecchio al più recente in fumetti, con emoji e **collegamenti** attivi: un link a una prenotazione apre quella prenotazione, uno a uno spazio apre il suo foglio di prenotazione, ciascuno con *Mostra sulla piantina*. Il campo di scrittura sta sotto. **Tieni premuto un fumetto per eliminarlo**, con conferma. I tuoi messaggi portano una spunta: **grigia = consegnato**, **blu = letto**.

**Tenere la lista in ordine.** Dei chip sopra la lista la restringono a **Tutti**, **Non letti** o **Archiviati**. **Tieni premuta una riga** per **fissarla** in alto, **silenziarla**, **segnarla come non letta** per tornarci più tardi, o **archiviarla** — una conversazione archiviata esce dalla lista, conserva la cronologia e torna da sola appena qualcuno ci scrive. Una puntina e una campana barrata sulla riga dicono qual è quale.

**Una conversazione è una pagina.** Si apre a tutta altezza con una freccia indietro, e il suo indirizzo si può condividere o salvare nei preferiti. I messaggi stanno sotto **separatori di giorno**, quindi una bolla mostra solo l'ora; **Carica messaggi precedenti** in alto recupera la cronologia più vecchia. Ciò che scrivi senza inviare resta come **bozza** per quella conversazione. **Scorri a destra** per citare un messaggio e tocca il blocco citato in una risposta per saltare all'originale; **scorri a sinistra** per ritirare un tuo messaggio che nessuno ha ancora letto. La **graffetta** allega una prenotazione o uno spazio, e un contatore compare avvicinandosi al limite di lunghezza.

**Iniziarne una.** Tocca la matita, poi una persona: la chat si apre subito. Attiva l'interruttore **Gruppo** per scegliere più persone e dare il nome al gruppo.

**Tocca il nome in alto.** In una chat privata apre il **profilo** della persona — la prenotazione di oggi, se ha fatto il check-in, il suo stato e come raggiungerla. In un gruppo apre l'**elenco dei membri**, dove un amministratore del gruppo aggiunge o rimuove persone e chiunque può uscire. Uscire non lascia mai un gruppo senza amministratore.

**La ricerca** (la lente) guarda in tre posti: **persone**, **gruppi** e le **parole dentro i messaggi**. Un risultato ti porta direttamente alla persona, al gruppo o al messaggio.

**Niente foto né file.** I messaggi portano testo, più collegamenti a una prenotazione o a uno spazio. È voluto: un'app di coworking non è un servizio di file.

**Notifiche.** Un messaggio *ricevuto* ti avvisa e conta sulla scheda **Messaggi**; aprire la conversazione azzera il contatore. I messaggi non compaiono più nella campana, riservata a conferme ed eventi. Unica eccezione: una **diffusione a tutti gli amministratori**, che non ha una conversazione in cui stare e resta lì.

![](assets/help/images/messages-discussions.jpg)

*L'elenco delle conversazioni: persone e gruppi insieme, i contatori dei non letti, la matita per iniziarne una nuova.*

![](assets/help/images/messages-conversation.jpg)

*Una chat privata: fumetti dal più vecchio al più recente, le spunte di lettura grigie/blu sui tuoi messaggi.*

![](assets/help/images/messages-conversation-links.jpg)

*Un messaggio di gruppo con un link di prenotazione e un link di spazio — entrambi attivi, entrambi con il salto Mostra sulla piantina.*

### Operatore della piattaforma

L'account che gestisce l'installazione vede, in *Profili*, **tutti gli spazi** del database: i propri come sempre, gli altri **in grigio** con ambiente e numero di membri. Toccando uno spazio in grigio compaiono i suoi **proprietari** con l'e-mail — e quella lettura è registrata, visibile ai proprietari dello spazio. Un proprietario ha sempre un indirizzo e-mail: l'app rifiuta di creare uno spazio o nominare un comproprietario senza.
### Situazione dello spazio e ripartizione guidata (#934)

*Denaro → Situazione dello spazio* mostra a proprietari e admin, nel periodo scelto, ciò che lo spazio ha **fatturato** (al netto delle note di credito), **incassato**, **rimborsato** e **ripartito**, poi lo stesso socio per socio con la percentuale di abbonamento — e lo stampa come rapporto. *Ripartire una spesa* propone la quota di ciascuno **in base all'abbonamento**, permette di escludere un socio o modificare un peso, registra le quote come oggi (righe della prossima fattura di consumo) e **ricorda la regola** per il mese successivo.

### Esportazioni contabili complete (#936)

Il FEC e il file DATEV riportano ora, oltre a vendite e banca, un **giornale acquisti**: spese rimborsate ai soci e costi comuni ripartiti. Una **nota di credito** è registrata come vendita stornata (mancava). Il conto spese è chiesto all'esportazione come gli altri. Uno spazio di sviluppo produce un file contrassegnato **DEV**: non è la contabilità reale.

### Sedi (#945)

Uno spazio può avere **più indirizzi**. *Impostazioni → Sedi*: la sede predefinita porta l'indirizzo dello spazio; aggiungi una sede per ogni indirizzo in più (via, CAP, città, registrazione dell'unità locale) e assegnale i suoi piani. Ogni socio ha una **sede di riferimento** (pagina del socio): è l'indirizzo che porteranno i suoi documenti. Eliminare una sede riporta piani e soci alla sede predefinita.

### Sedi sui documenti (#946)

Con più sedi, una fattura porta **l'indirizzo e la registrazione della sede di riferimento** del socio come venditore (la sede predefinita mantiene l'indirizzo dello spazio), indica la sede sotto l'intestazione e — quando si stampa il dettaglio delle presenze — elenca le **altre sedi** in cui il socio ha lavorato nel mese. La fattura elettronica segue lo stesso indirizzo.
### Numeri per sede (#948)

In Francia la partita IVA e l'esenzione appartengono all'entità giuridica; ogni unità locale ha il proprio **SIRET**, che la sede porta. Una sede che è un'**entità giuridica distinta** può portare inoltre la propria partita IVA e la propria dicitura di esenzione — i documenti emessi in quella sede le riprendono. Di solito è il segno di uno spazio separato; la schermata lo ricorda.

### Gruppi IVA (#947)

Ogni aliquota porta ora il **gruppo fiscale** di ciò che tassa: ordinaria, intermedia, ridotta, super-ridotta, zero, esente, non soggetta, **cauzione** (fuori IVA) o **con accise** (birra, liquori, bevande zuccherate: accise nel prezzo, IVA ordinaria). *Impostazioni → IVA* mostra cosa rientra in ogni gruppo nel tuo paese e la dicitura di esenzione che implica. Un'associazione non soggetta mantiene la categoria O. Una cauzione accanto a righe tassate non può uscire come fattura elettronica (EN 16931): l'app lo segnala e la emetti a parte.
### Distribuzione tra i due lati (#988, #990)

In **Impostazioni → Governance → Distribuzione** — visibile finché la funzionalità *Distribuzioni* è attiva, lo spazio ha il suo gemello e tu detieni un permesso di distribuzione — configurazione e dati anagrafici viaggiano tra i due lati **entità per entità**: *Identità e dati legali, IVA, Tariffe, Servizi, Pacchetti, Accessori, Sedi, Regole di prenotazione, Regole di convalida, Matrice dei ruoli, Regole di sollecito, Modelli di documento, Collegamenti ai documenti, Giorni di chiusura, Modelli di invito, Funzionalità*. Spunta un'entità e ciò di cui ha bisogno si spunta con lei (i servizi hanno bisogno delle aliquote IVA). **La direzione è il lato su cui ti trovi**: dal lato sviluppo il pulsante dice *Distribuisci in PROD*, dal lato produzione *Distribuisci in DEV*. Nulla si muove prima che un'**anteprima** dica, per entità, cosa verrebbe aggiunto, modificato e rimosso dall'altro lato; un'anteprima senza nulla da fare lo dice e non distribuisce nulla. Ogni distribuzione entra nel **giornale** — chi, quando, in che direzione, quali entità — con *Torna indietro* sull'ultima, che rimette ciò che l'altro lato aveva prima. Membri, prenotazioni, conti, fatture, pagamenti ed eventi non viaggiano mai; nemmeno le credenziali o i contatori di numerazione. La planimetria continua a viaggiare tramite il file dello spazio. Dal #1004 anche le **planimetrie** si distribuiscono — piani con sede, prezzi e prenotazione intera, uffici, tavoli e postazioni con sedie, dotazioni e accessori, sfondi e immagini della planimetria — come **fusione**: ciò che ha l'altro lato viene aggiunto o aggiornato, ciò che ha solo questo lato viene segnalato e conservato, perché una postazione può avere una prenotazione; badge e blocchi non viaggiano mai, e le immagini vengono copiate insieme. Dal #1010 anche le **istruzioni di pagamento** (il blocco bancario che una fattura stampa) sono un'entità, e distribuire i **modelli di documento** ne copia le immagini — il logo — insieme, come la planimetria. Dal #1006 una distribuzione va sempre **nel lato in cui ti trovi**: sul lato produzione il pulsante dice *Tira da DEV*, sul lato sviluppo *Tira da PROD* — nulla può essere spinto sull'altro lato per errore — e dopo l'anteprima una **conferma** nomina il lato che viene scritto e le entità prima che qualcosa si muova. Richiede il permesso della direzione di destinazione (*Distribuire in produzione* in prod, *Distribuire in sviluppo* in dev) sul lato in cui ti trovi. L'elenco è raggruppato in *Configurazione*, *Dati anagrafici* e *Report* (i modelli di documento: ogni tipo di report, preset e lingua).

### Coppie di ambienti e permessi di distribuzione (#987, #989)

Uno spazio ora viene creato **insieme al suo gemello**: il lato sviluppo e il lato produzione condividono nome, paese, valuta e fuso orario, li possiedi entrambi, e **Profili** mostra la coppia come **una sola scheda con due chip, DEV e PROD** — tocca un chip per cambiare lato. Uno spazio creato prima delle coppie, o creato da solo (deseleziona *Crea la coppia sviluppo e produzione*), riceve il suo gemello su richiesta in **Impostazioni → Avanzate → Crea il suo gemello**: la configurazione è copiata una volta, e nient'altro. La coppia si disattiva con la funzionalità *Coppie di ambienti*, che lascia due voci ordinarie.

Tre permessi entrano nella matrice dei ruoli: **Distribuire in produzione**, **Distribuire in sviluppo** e **Entrare nello spazio di produzione**. Chi può distribuire in produzione può sempre distribuire in sviluppo. Proprietari e comproprietari hanno tutti e tre; gli admin hanno *Distribuire in sviluppo* e *Entrare nello spazio di produzione*; i membri nulla finché non lo concedi. Ne seguono due regole: **un membro del lato produzione è sempre membro del lato sviluppo** (l'adesione è rispecchiata, ruolo e stato compresi), e **un ruolo entra in produzione solo finché detiene quel permesso** — un invito, un'adesione o una rivendicazione verso la prod viene rifiutata altrimenti, e l'app dice perché.

### L'IVA come in un ERP — versioni datate delle aliquote, un momento impositivo, il cliente (#985)

Due funzionalità sotto *Gestione IVA* fanno delle aliquote ciò che un ERP chiama una **configurazione di registrazione**.

- **Versioni delle aliquote IVA.** Un'aliquota è una **famiglia di versioni datate**. Quando la legge cambia un'aliquota, tocca **Modifica per legge** sulla riga, digita la nuova percentuale e la data di effetto: il vecchio valore si chiude a quella data, il successore si apre lo stesso giorno, e ogni servizio, pacchetto, accessorio o abbonamento che puntava alla vecchia riga continua a puntarvi — l'app percorre la famiglia e applica **il valore in vigore alla data del momento impositivo**. Nulla viene modificato sul posto, nulla riassegnato. Il **momento impositivo** di un mese fatturato è il suo ultimo giorno, o la data della fattura quando il mese è fatturato in anticipo (la regola dell'acconto); un addebito timbrato alla prenotazione (un servizio, un pacchetto) conserva il suo timbro. Un mese terminato prima della modifica è quindi tassato al vecchio valore anche se la sua fattura è emessa — o riemessa — dopo, e solo le prestazioni successive alla modifica portano il nuovo valore. L'esportazione della configurazione porta con sé le versioni e la famiglia.
- **IVA secondo il cliente.** Nella pagina di un membro, **Trattamento IVA** dice chi è questo acquirente ai fini fiscali: *Automatico* (la regola attuale: inversione contabile per un'impresa di un altro Stato UE), *IVA nazionale* qualunque sia il paese (una postazione è una prestazione relativa a un immobile), *Inversione contabile* (categoria AE), *Fuori UE* (categoria G, con la dicitura di legge) o *Acquirente esente* con il motivo stampato sulla fattura (categoria E). La fattura applica la matrice cliente × prodotto: un gruppo esente o non soggetto resta ciò che è; un gruppo imponibile prende la categoria del cliente. La fattura elettronica porta la categoria e il suo codice VATEX.

Il catalogo dei paesi nomina il **gruppo** di ogni aliquota proposta (ordinaria, intermedia, ridotta, super-ridotta): inizializzare uno spazio produce una riga per gruppo di legge in ogni paese, e la modifica per legge è la stessa ovunque.

### Archivio dell'esercizio (#957)

*Esportazioni contabili → Archivio dell'esercizio* scarica un unico zip con il numero di registrazione e l'anno: ogni fattura in PDF/A-3 con la fattura elettronica incorporata, il **registro delle fatture** (numero, data, importo, stato e la parola di integrità di ogni documento), il FEC sui conti predefiniti e la traccia di audit. Uno spazio di sviluppo produce un file contrassegnato DEV.

# Guida dell'amministratore — configurare lo spazio

Per chi mette in piedi lo spazio: che cosa decide ogni parametro,
nell'ordine in cui il questionario li chiede, poi i dati anagrafici, poi
la piantina e le sue immagini. La parte tecnica sta nella
[guida tecnica](Admin-Technical-Guide.it); spostare una
configurazione da uno spazio di sviluppo a uno di produzione sta nella
[guida degli ambienti](Environments-Guide.it).

## Il questionario di installazione

Il questionario web chiede, nell'ordine, solo ciò che le risposte
precedenti rendono possibile, e produce il file di spazio che l'app
importa. Ogni domanda che vi compare esiste come parametro nell'app, e
ogni parametro dell'app compare lì — quella simmetria è una regola, non
una coincidenza.

<!-- image: config-setup-questionnaire -->

## Identità e menzioni legali

*Impostazioni dello spazio → Identità legale e fatturazione
elettronica.* Compila questa parte prima che il primo documento esca di
casa: una fattura che non nomina correttamente chi la emette non è una
fattura.

Il **tipo di organizzazione** — società o associazione — decide quali
clausole vengono stampate per impostazione predefinita. Gli interessi di
mora, l'indennizzo per il recupero e lo sconto per pagamento anticipato
sono obblighi *tra professionisti*: i documenti di un'associazione
lasciano cadere quelle menzioni predefinite e stampano comunque tutto
ciò che scrivi tu.

Poi, in ordine: la **forma giuridica e il capitale** stampati sotto il
nome; il **registro** in cui chi legge può verificarti (Registro delle
imprese e città per una società, registro delle associazioni per
un'associazione); il **regime IVA**, che decide se la norma si aspetta da
te una partita IVA o un numero di iscrizione; l'**indirizzo
strutturato**, che è ciò che porta una fattura elettronica perché una
macchina non sa spezzare in modo affidabile un indirizzo su una sola
riga; e le otto menzioni di fattura.

Ognuno di quei campi è documentato, campo per campo, nella
guida utente, § 11a — il simbolo di aiuto accanto apre
esattamente il suo paragrafo.

Le **istruzioni di pagamento** (il blocco bancario che un documento
stampa) sono un'entità separata, quindi si distribuiscono da sole tra uno
spazio di sviluppo e uno di produzione.

## IVA

L'aliquota che una prestazione porta è decisa da tre cose, mai da una
sola: che cosa è (**il gruppo**), chi la compra (**il trattamento**) e
quando è avvenuta (**il momento di esigibilità**). È la forma ERP, ed è
il motivo per cui un cambio di aliquota non riscrive mai un documento
vecchio.

Le **aliquote** portano un nome, una percentuale e un gruppo fiscale, e
una è quella predefinita. Un'aliquota è **versionata per data**: passare
dal 22 % al 23 % aggiunge una versione valida da una data, non modifica
quella vecchia. Ogni documento già emesso conserva la versione in vigore
al momento dell'emissione, congelata sul documento stesso; solo le
prestazioni datate dal giorno di inizio della nuova versione in poi la
usano.

I **gruppi** sono ciò che una prestazione *è* — ordinaria, ridotta,
aliquota zero, esente, fuori campo. Un servizio, un abbonamento, un
accessorio e un pacchetto portano un gruppo, non una percentuale: la
tabella delle aliquote di un paese può quindi cambiare sotto di loro
senza toccare il catalogo.

I **trattamenti** sono ciò che la controparte ne fa: interno,
intracomunitario verso imprese (inversione contabile, il cliente assolve
l'imposta secondo l'art. 196), intracomunitario verso consumatori,
esportazione. Il paese e la partita IVA del cliente decidono quale si
applica, e il controllo della fatturazione elettronica rifiuta di inviare
un documento in inversione contabile finché quella partita IVA manca:
è ciò che prova che l'imposta è sua.

**Quando l'IVA diventa esigibile** è un'impostazione dello spazio: *sulle
fatture* (esigibile all'emissione) oppure *sugli incassi* (esigibile il
giorno in cui il cliente paga). L'Italia lo chiama *IVA per cassa*; la
Francia mette i servizi sugli incassi salvo opzione contraria; la
Germania lo chiama *Ist-Versteuerung*. Sugli incassi, un periodo di
dichiarazione copre gli incassi ricevuti al suo interno, un pagamento
parziale porta una quota proporzionale di ogni aliquota del documento, e
l'arrotondamento va all'aliquota più ampia perché il totale corrisponda
esattamente a quanto ricevuto.

Le **dichiarazioni** sono costruite per un periodo a partire dai
documenti (o dagli incassi) che contiene, riportate nelle caselle del
modulo del tuo paese — CA3 in Francia, UStVA in Germania — e prodotte in
PDF e XML. Una dichiarazione passa da bozza a presentata, e una
presentata non viene mai ricalcolata.

Il catalogo completo delle aliquote di un paese è fornito con l'app
(UE27, CH, NO, CA); tenerlo aggiornato quando un governo cambia
un'aliquota spetta a te.

## Abbonamenti e regole di fatturazione

Un **abbonamento** è una percentuale con un importo mensile: 25 %, 50 %,
100 % delle mezze giornate lavorative di un mese, ciascuna con il proprio
prezzo e il proprio gruppo IVA. Un membro ha un abbonamento; la
percentuale diventa una dotazione di mezze giornate, e l'importo è ciò
che costa il mese, che la dotazione venga usata o no.

**La mezza giornata** è l'unità in cui tutto si conta. Che cosa ne
costituisce una lo decidono gli orari di apertura e la granularità: una
mattina, un pomeriggio, o una fascia della griglia che imposti tu.

**L'eccedenza** è ciò che succede oltre la dotazione. O le mezze giornate
in più vengono rifiutate, oppure vengono addebitate al prezzo di
eccedenza per mezza giornata, che è un prezzo separato con il proprio
gruppo IVA. Mezze giornate aggiuntive possono anche essere richieste e
concesse per singolo membro.

**Quando un mese viene fatturato** è una regola, non un'abitudine: la
riga di abbonamento è emessa *prima* del mese che copre, e le righe di
utilizzo la seguono. Ogni riga di abbonamento nomina il proprio mese —
*settembre 100 %* — così una fattura è sempre legata al periodo che paga.

**L'aritmetica di un mese è congelata sul documento.** Cambiare il prezzo
di un abbonamento cambia quanto costerà il mese successivo; non cambia
mai una fattura già emessa, e non riapre mai un mese già chiuso.

## Servizi

Tutto ciò che si vende e non è una postazione: un'ora di sala riunioni,
un pacchetto di stampe, un armadietto, un abbonamento al caffè. Un
servizio ha un nome, un prezzo, un gruppo IVA e un'unità, e un
amministratore può metterlo su una fattura o collegarlo a un pacchetto.

I servizi si distribuiscono tra uno spazio di sviluppo e uno di
produzione come entità propria — e poiché portano un gruppo IVA anziché
una percentuale, le aliquote viaggiano con loro.

## Pacchetti giornalieri

Una giornata venduta come una cosa sola: una postazione, un armadietto e
due ore di sala riunioni, a un unico prezzo. Un pacchetto raggruppa
servizi e una dotazione di postazioni, porta il proprio gruppo IVA, e
compare in fattura come una riga con le sue parti elencate sotto quando
il layout lo richiede.

Usa un pacchetto dove un membro non dovrebbe doversi comporre la giornata
da solo, e un abbonamento dove l'unità è il mese.

## Accessori

Attrezzatura collegata a una postazione anziché venduta a sé: un secondo
schermo, una docking station, un rialzo per lavorare in piedi, una
lavagna. Un accessorio ha un nome, un prezzo facoltativo con il suo
gruppo IVA, e viene posato sulla piantina contro una postazione, un
tavolo o un ufficio.

Sulla piantina un accessorio fa parte di ciò che una prenotazione
ottiene. Quando porta un prezzo, prenotare la postazione aggiunge la sua
riga di fattura alla sua aliquota — per questo il catalogo degli
accessori e le aliquote IVA si distribuiscono insieme.

## Sedi

Più indirizzi sotto una stessa organizzazione: quale ne nomina un
documento, quale iscrizione porta, e come un membro è collegato a una di
esse.

## Disponibilità e regole di prenotazione

*Impostazioni dello spazio → Disponibilità.* Ogni regola qui è applicata
dal server, non dalla schermata: una regola che imposti tiene anche
contro un'app non aggiornata.

**I giorni e gli orari di apertura** definiscono la giornata lavorativa
e, insieme alla granularità, che cosa sia una mezza giornata. **I giorni
di chiusura** sono date in cui lo spazio è chiuso: una prenotazione che
ne tocca uno viene rifiutata nominando quel motivo.

**I giorni festivi** possono essere generati un anno alla volta anziché
aggiunti data per data (#1274). Scegli l'anno, leggi l'elenco che il
server propone, e conferma — la generazione non è mai automatica né
silenziosa. Rilanciare un anno non aggiunge nulla, quindi ripeterlo è
sicuro.

Un mese che porta già una fattura viene **saltato e nominato a schermo**.
Un giorno di chiusura lì cambierebbe quante mezze giornate quel mese
includeva, e quindi una fattura già emessa; la regola è applicata nel
database e non nella schermata (ADR 0025). Correggere un mese fatturato
resta un atto deliberato: aggiungi il giorno a mano e occupati della
fattura.

Le date vengono dal server, quindi lo stesso elenco alimenta un modello
che configura uno spazio intero. Attiva *Giorni festivi* per vedere
l'azione; è spenta finché non la chiedi.

**La granularità** è ciò che una prenotazione può essere — una mezza
giornata, una giornata intera, o una fascia su una griglia di N minuti.
Una prenotazione che non cade sulla griglia viene rifiutata, e le viene
detto il passo.

**L'orizzonte** è quanto in anticipo si aprono le prenotazioni. **La
durata minima e massima** limitano una singola prenotazione. **Le
prenotazioni simultanee** limitano quante un membro può tenerne aperte
insieme, per spazio e ridefinibile per membro. Una prenotazione finisce
sempre il giorno in cui inizia.

**Le prenotazioni nel passato** vengono rifiutate se non le consenti; una
prenotazione retroattiva in giornata è legittima, perché chi si è seduto
alle nove deve poterlo dire alle dieci.

**Fuori dagli orari di apertura** ha tre modi: *spento* (rifiutato),
*solo accesso spontaneo* (un check-in spontaneo è possibile, prenotare in
anticipo no) oppure *addebitato* (consentito e conteggiato). Ciascuno ha
la propria frase di rifiuto, così un membro impara quale porta è chiusa.

**Le regole di validazione** decidono quali atti richiedono una decisione
umana — vedi più sotto.

## La piantina

La piantina è ciò su cui i membri prenotano. È costruita con tre forme
annidate sopra un'immagine di sfondo, su una griglia la cui cella è
l'unità di posizionamento. Costruiscila in quest'ordine: prima il piano e
il suo sfondo, poi gli uffici, poi i tavoli e le postazioni. Tutto quanto
segue si ricalca sopra l'immagine, mai a memoria.

### Piani

Un piano è un livello dell'edificio, o un insieme di stanze trattato come
uno solo. Porta la sua **sede** (a quale indirizzo appartiene), la sua
**immagine di sfondo** e, quando è prenotabile per intero, il suo
**prezzo per mezza giornata** e il suo gruppo IVA.

*Prenotabile per intero* è un interruttore sul piano stesso. Senza di
esso, una richiesta di prenotare l'intero piano viene rifiutata indicando
quale interruttore manca — il rifiuto nomina l'impostazione invece di
dare la colpa al membro.

### Uffici, tavoli e postazioni

**Un ufficio** è una stanza dentro un piano. **Un tavolo** sta dentro un
ufficio o libero sul piano. **Una postazione** è un posto a un tavolo —
ciò che un membro prenota davvero. Ciascuno ha la propria impronta sulla
griglia; una postazione occupa sei celle in larghezza e quattro in
profondità, e questo fissa la scala di tutto il resto.

Una postazione porta il suo **orientamento** (da che parte guarda la
sedia, così la piantina si legge come la stanza), la sua **dotazione e i
suoi accessori**, e le sue **etichette** — un badge o un tag NFC rende la
postazione scansionabile alla porta.

**Prenotabile per intero** esiste anche sul tavolo e sull'ufficio:
attivalo e il tavolo o la stanza si prenota in una volta anziché
postazione per postazione. Una prenotazione dell'insieme blocca i suoi
figli per il periodo, e la prenotazione di un figlio blocca l'insieme.

**Bloccare** una postazione la toglie dal servizio per manutenzione senza
cancellarla: resta sulla piantina, in grigio, e ogni tentativo di
prenotazione viene rifiutato con quel motivo. I blocchi non viaggiano mai
da uno spazio di sviluppo a uno di produzione, perché un blocco di
manutenzione è un fatto che riguarda un edificio in un giorno.

### L'immagine di sfondo

Una piantina si legge meglio sopra un disegno della stanza reale.
L'immagine è per piano, sta sotto la griglia, e non si muove più una
volta ricalcate sopra le postazioni.

<!-- image: config-plan-background -->

### Ricavare quell'immagine da fotografie, con un'IA

Non serve il disegno di un architetto. Fotografa la stanza, chiedi a un
modello di immagini una pianta dall'alto, e usa la sua risposta come
sfondo.

**Fotografa bene.** Mettiti in ogni angolo, tieni la fotocamera
all'altezza del petto, e scatta una foto per angolo più una lungo ogni
parete lunga. In almeno due di esse deve entrare tutto il pavimento.
Misura una cosa — la lunghezza di un tavolo, la larghezza di una porta —
e annota il numero: è ciò che fisserà la scala.

**Chiedi una pianta, non un'immagine.** Il prompt che funziona chiede una
vista ortografica dall'alto, colori piatti, nessuna prospettiva, nessuna
ombra, nessuna persona, e i mobili come semplici impronte:

> Da queste fotografie di una stessa stanza, disegna una pianta
> ortografica vista dall'alto. Muri dritti, angoli retti esatti, nessuna
> prospettiva e nessuna ombra. Mostra solo gli elementi fissi: muri,
> porte con il loro verso di apertura, finestre, termosifoni, pilastri,
> blocchi cucina e servizi, e l'impronta di ogni mobile grande come una
> forma semplice con il contorno. Colori chiari e tenui su fondo bianco;
> nessun testo, nessuna etichetta, nessuna quota, nessuna persona,
> nessuna decorazione. Il [tavolo] nella stanza è lungo [1,60] m —
> disegna tutto in quella scala. Produci una sola immagine, in [4:3], di
> almeno 1600 pixel di larghezza.

**Verifica la scala prima di ricalcare.** Importa l'immagine come sfondo
del piano, poi misura l'oggetto che hai annotato contro la griglia: una
postazione occupa sei celle in larghezza e quattro in profondità, e una
cella è l'unità di posizionamento dell'app. Scala l'immagine finché
l'oggetto reale non corrisponde alla sua dimensione vera sulla griglia;
tutto ciò che ricalchi dopo è allora onesto.

**Ricalca, non disegnare.** Posiziona uffici, tavoli e postazioni sopra
l'immagine. Lo sfondo guida l'occhio; ciò che l'app prenota sono le
postazioni che posizioni tu.

**Che cosa non accettare.** Una vista in prospettiva, un rendering con
ombre, una pianta con stanze inventate, o una in cui i mobili non
corrispondono alle fotografie. Richiedila con un prompt più stretto
invece di correggere a mano una pianta sbagliata.

### Immagini della piantina

Immagini posate *sopra* la piantina anziché sotto — un logo vicino
all'ingresso, un cartello, la foto di un angolo —, ciascuna con la
propria posizione e dimensione sulla griglia. Sono decorazione: su di
esse non si prenota nulla, e stanno sopra lo sfondo e sotto le
postazioni.

Viaggiano con la piantina quando viene distribuita, e il file di spazio
se le porta all'esportazione.

## Biblioteca dei documenti

File che lo spazio conserva e mostra a chi ha diritto di vederli: il
regolamento interno, un certificato di assicurazione, una pianta di
evacuazione, un modello di accordo per i membri. Ogni documento porta i
ruoli che possono leggerlo, quindi la biblioteca è un unico posto con
visibilità per ruolo invece di più cartelle.

I *layout* dei documenti — l'impaginazione di una fattura o di una
lettera — sono un'altra cosa, e stanno nella
[guida tecnica](Admin-Technical-Guide.it).

## Ruoli e permessi

*Impostazioni → Ruoli.* Una matrice: i ruoli da un lato, i permessi
dall'altro. Proprietario, comproprietario, amministratore, membro — e
ogni permesso è una casella che puoi attivare o disattivare, tranne
quelle che un proprietario ha sempre.

Un permesso viene chiesto al server attraverso un'unica funzione: un
permesso che togli è tolto ovunque nello stesso momento. La schermata
nasconde il pulsante, e la chiamata dietro rifiuta comunque.

Anche i permessi di ambiente vivono qui — *Entrare nello spazio di
produzione*, *Distribuire allo sviluppo*, *Distribuire alla produzione* —
e sono spiegati nella [guida degli ambienti](Environments-Guide.it).

## Regole di validazione

Quali atti richiedono una decisione umana prima di avere effetto, e chi
decide. Ogni dominio ha la sua regola: un membro che entra, una
prenotazione eliminata, una fattura stralciata, mezze giornate
aggiuntive concesse, e le altre.

Per dominio scegli se una richiesta venga sollevata del tutto, e se la
richiesta di un amministratore o di un proprietario venga **validata
automaticamente** — nel qual caso l'evento è registrato già risolto,
anziché avvisare un validatore perché approvi la propria azione.

Una decisione è sempre un evento: chi ha deciso, quando e su che cosa.
Nulla viene validato in silenzio, e una decisione presa dal sistema lo
dice.

## Funzionalità

Ogni funzionalità è un interruttore. Che cosa spegne un interruttore, che
cosa non spegne mai (l'aritmetica già applicata), e il grafo delle
dipendenze che decide quali interruttori siano disponibili.

# Guida dell'amministratore — la parte tecnica

Per chi tiene in piedi uno spazio DesKilo: i documenti che stampa, i file
che scambia, i servizi con cui parla e la base dati che sta sotto. La
configurazione di tutti i giorni sta nella
[guida di configurazione](Admin-Configuration-Guide.it); quello che vede
un membro sta nella guida utente.

*Uno spazio segnato `<!-- image: … -->` è una schermata che la catena non
ha ancora ricevuto.*

## Documenti e report

Tutto ciò che DesKilo stampa — una fattura, un sollecito, una lettera a
un membro, un report di consumo, una dichiarazione IVA, un foglio di
badge — esce da un solo motore. Un **tipo di documento** lo nomina; un
**progetto** dice che aspetto ha; i **dati** che l'app gli consegna sono
un vocabolario fisso di segnaposto.

![](assets/help/images/admin-reports-editor.jpg)

*L'editor dei report: i selettori di lingua e documento in alto, gli interruttori Marcatura / Visivo e Progetto / Anteprima sotto, e le bande della fattura — intestazione, corpo, piè di pagina — più giù.*

### I tipi e i quattro modelli

Ogni tipo (fattura, nota di credito, proforma, estratto conto, accordo,
pagamenti, consumo, IVA, spazio) parte da uno dei quattro modelli —
*Semplice*, *Classico*, *Dettagliato*, *Lettera formale* — che
differiscono solo per quanto dicono, mai per ciò che la legge richiede.

### Le bande: intestazione, continuazione, corpo, piè di pagina

Il modo rapido di progettare. Quattro bande di marcatura, ciascuna con il
suo compito:

| Banda | Dove stampa |
|---|---|
| **intestazione** | in cima alla pagina 1 soltanto — la carta intestata |
| **continuazione** | in cima alla pagina 2 e seguenti — una striscia che nomina il documento |
| **corpo** | l'unica zona che scorre: è quella che prosegue e impagina |
| **piè di pagina** | in fondo a *ogni* pagina |

Dentro una banda, un segno per riga decide che cosa è la riga:

| Segno | In che cosa diventa la riga |
|---|---|
| `# ` | un titolo |
| `## ` | un sottotitolo |
| `- ` | una riga piccola |
| `\| a \| b \|` | una riga di tabella; una riga di `---` rende intestazione quella sopra |
| `---` | una linea orizzontale |
| `![nome\|l\|align]` | un'immagine dalla libreria, con dimensione e allineamento |
| (vuoto) | uno spazio |
| tutto il resto | testo corrente |

Il pannello *Segnaposto e marcatura* del progettista porta tutto questo
in linea, più **Inserisci un campo…** — il selettore ricercabile,
raggruppato per tema, con una riga di significato sotto ogni nome,
ricercabile anche per quel significato — e tre pezzi già pronti: una riga
che stampa solo quando il suo valore esiste, una riga per ogni riga di
fattura, e il titolo che dice fattura, nota di credito o proforma. Quello
che toccate atterra al cursore della banda modificata per ultima.

### I layout posizionati

Il modo esatto. Un layout XML colloca ogni elemento al millimetro, per un
documento che deve soddisfare una busta a finestra o un modulo
nazionale. **Un layout vince sulle bande** per il tipo su cui è
impostato.

La radice e le sue zone:

```xml
<report-layout version="1" page="A4" margin="20mm"
               margin-top="8mm" margin-bottom="8mm">
  <header height="…">…</header>
  <continuation height="…">…</continuation>
  <recipient window="fr|din|off"/>
  <body y="90mm">…</body>
  <footer height="…">…</footer>
</report-layout>
```

`margin` è il margine laterale; `margin-top` e `margin-bottom` separano
il margine verticale quando un documento li vuole distinti, e valgono il
margine laterale quando mancano. `<recipient>` prende una finestra con
nome — **fr** a 110 mm, **din** a 20 mm, entrambe a 45 mm dall'alto in un
riquadro di 85 × 40 mm — oppure `x y w h` espliciti, oppure `off`.
`<body y="…">` è l'unica zona che scorre: `y` è il punto in cui
riprende, 90 mm sotto una finestra.

**Elementi**, validi dentro una zona, una `<box>` o una `<column>`:

| Elemento | Che cosa fa |
|---|---|
| `<text style="heading\|subheading\|body\|small" align="left\|center\|right" bold="true">` | un tratto di testo |
| `<image name="nome-in-libreria" fit="contain\|cover\|fill" align="…"/>` | un'immagine dalla libreria |
| `<table><col w="55%" align="right"/>…<row bold="true"><cell align="…">…</cell></row></table>` | una tabella con colonne dichiarate |
| `<box>…</box>` | un gruppo, perché i figli si posizionino dentro |
| `<columns><column>…</column>…</columns>` | gruppi affiancati |
| `<rule/>` | una linea orizzontale |
| `<spacer size="4mm"/>` | spazio verticale |
| `<markup>…</markup>` | marcatura di banda, alla lettera, dentro un layout posizionato |

**Gli attributi di cornice** — `x y w h` — valgono per qualsiasi
elemento. Con `x` o `y` l'elemento è posto in assoluto dentro il suo
genitore; senza né l'uno né l'altro scorre dopo i suoi fratelli.

**Le unità** sono `mm cm px pt %`. Un numero nudo è in millimetri; `px` è
il pixel CSS (1/96 di pollice); `%` è rispetto al genitore — larghezza
per `x` e `w`, altezza per `y` e `h`.

### Il vocabolario

Ogni segnaposto che il motore conosce, per famiglia di documento, con i
cicli (`lines`, `vat`, `usage_records`, …) e i campi che ogni riga porta.
`dart run tool/report.dart describe` stampa l'elenco corrente — è
generato dallo stesso registro che legge il renderer, quindi non può mai
essere superato.

### Liquid: condizioni, cicli, filtri

Liquid passa **prima** su tutto il file, prima che l'XML venga
analizzato: una condizione può quindi aprirsi in un elemento e chiudersi
in un altro. I valori sono sottoposti a escape XML in ingresso.

| Forma | Che cosa fa |
|---|---|
| `{{ campo }}` | stampa il valore, con escape |
| `{% if campo != "" %}…{% endif %}` | stampa il blocco solo quando il campo ha un valore |
| `{% if a == b %}…{% else %}…{% endif %}` | la forma a due rami |
| `{% unless campo == "" %}…{% endunless %}` | la forma negata |
| `{% for line in lines %}…{% endfor %}` | un passaggio per ogni riga di un ciclo |
| `{{ forloop.index }}` | il numero di riga, a partire da 1, dentro un ciclo |

**La regola che frega tutti:** ogni segnaposto che il motore conosce è
inizializzato **vuoto**, mai nullo. Un campo assente vale `""`, quindi
`{% if x != "" %}` si comporta bene e un progetto non stampa mai la
parola `nil`. I testi del proprietario (`text.<chiave>`) sono
inizializzati allo stesso modo tramite la loro tabella di valori
predefiniti.

**I cicli e le loro righe.** `lines` dà `label, kind, pct, month, qty,
unit_price, net, vat_rate, amount, negative`. `month` è il mese della
posizione di abbonamento, già tradotto nella lingua del documento — è il
motivo per cui una riga di fattura può leggersi *settembre 100 %*. `vat`
dà la ripartizione per aliquota, `usage_records` le mezze giornate,
`vat_positions` e `vat_rate_totals` le righe proprie della
dichiarazione.

### Il contratto della busta a finestra

Una lettera che va in una busta a finestra ha una geometria, e non è
questione di gusto:

| Cosa | Dove |
|---|---|
| riga del mittente | a 20 mm da sinistra, 20 mm dall'alto |
| blocco del destinatario | a 110 mm da sinistra, 45 mm dall'alto, dentro 85 × 40 mm |
| corpo | riprende a 90 mm |
| piè di pagina | su ogni pagina |
| striscia di continuazione | dalla pagina due |

Nulla oltre al destinatario può mettere inchiostro nella banda della
finestra. Questo è **dimostrato sul PDF prodotto**, non a occhio: il
controllo misura le posizioni di inchiostro del file generato e termina
con errore quando qualcosa atterra dove sta la finestra.

### La riga di comando

```
dart run tool/report.dart check <layout.xml> [--data data.json]
dart run tool/report.dart render <layout.xml> [--data data.json] -o out.pdf
dart run tool/report.dart sample --kind invoice > data.json
dart run tool/report.dart describe
```

- **check** rende il progetto e lo misura contro il contratto della
  finestra. Uscita 0: conforme; uscita 1: inchiostro nella banda della
  finestra, e dice quale elemento; uscita 2: il progetto non si è potuto
  leggere, e nomina l'elemento che si è rotto.
- **render** produce il PDF, così un progetto si può verificare senza
  l'app.
- **sample** scrive un file di dati con ogni segnaposto che il motore
  conosce, che è il modo più rapido per vedere come si chiama un campo.
- **describe** stampa il vocabolario qui sopra — zone, elementi,
  attributi di cornice, unità, Liquid e l'elenco dei segnaposto. È
  generato dallo stesso registro che legge il renderer, quindi non può
  divergere dal motore.

La CLI è Dart puro e deve restarlo: non importa nulla da Flutter né dalle
localizzazioni, e un test si rompe nel momento in cui un file di dominio
che usa si tira dietro `AppLocalizations`.

## Fatturazione elettronica

Una fattura lascia DesKilo come un PDF che legge una persona e un file
strutturato che legge una macchina, e i due dicono la stessa cosa perché
sono prodotti dallo stesso documento congelato.

### CII, UBL, Factur-X

Tutti e tre sono la stessa fattura espressa in tre modi, e tutti e tre
soddisfano **EN 16931**, il modello semantico europeo che dice quali
fatti una fattura deve portare (BT-1 il numero, BT-48 l'identificativo
IVA dell'acquirente, e così via).

| Formato | Che cos'è |
|---|---|
| **CII** | UN/CEFACT Cross Industry Invoice — la sintassi XML che prende Chorus Pro |
| **UBL** | OASIS Universal Business Language — la sintassi che prende Peppol |
| **Factur-X** | un PDF/A-3 con l'XML CII *incorporato dentro* — un file che una persona legge e una macchina analizza |

Factur-X è il motivo per cui il PDF e l'XML non possono contraddirsi:
sono lo stesso file. Quando una piattaforma li vuole separati, entrambi
sono prodotti dall'unico documento congelato, mai rigenerati dai dati
vivi.

### Il controllo di ammissibilità

Prima di qualsiasi trasmissione l'app verifica il documento contro la
norma e **rifiuta nominando ciò che manca**, perché una fattura
respinta da una piattaforma costa più da riparare di una mai inviata.

Che cosa rifiuta:

- un venditore senza l'identificativo che il regime richiede — una
  partita IVA quando addebitate l'IVA, un numero di registrazione quando
  non la addebitate;
- un documento in **inversione contabile** il cui cliente non ha partita
  IVA: quel numero è ciò che prova che l'imposta è sua;
- un'esenzione senza motivo e senza un valore predefinito del paese su
  cui ripiegare;
- una partita IVA cliente la cui **forma non corrisponde al suo paese** —
  un avviso, non un rifiuto, dato che le forme cambiano;
- un acquirente senza indirizzo, non appena la destinazione ne richieda
  uno.

I membri indicano da sé il proprio paese e, quando fatturano come
impresa, la propria partita IVA, accanto al loro indirizzo in
*Impostazioni → Dati personali*.

### Piattaforme e credenziali

Un documento può andare a **due destinazioni insieme**: la piattaforma
pubblica che il vostro paese impone e il servizio proprio del cliente.
Entrambe si configurano sullo spazio, e l'una o l'altra può essere
spenta.

Le credenziali vivono sullo spazio, mai nel file di spazio e mai in un
deployment — un export che mandate a un collega porta la configurazione e
non le chiavi. Uno **spazio di sviluppo usa sempre l'endpoint di
prova**, che fisicamente non può raggiungere una piattaforma pubblica:
una fattura di prova non può quindi mai diventare reale.

Ogni tentativo è registrato nello storico di trasmissione della fattura
stessa: quando, verso quale destinazione, che cosa ha risposto la
piattaforma e quale riferimento ha restituito. Una trasmissione fallita
lascia la fattura intatta e ritentabile — il documento è congelato, la
trasmissione non ne fa parte.

## Esportazioni contabili

Tre formati, un solo libro mastro sotto:

| Formato | Dove viene chiesto | Che cosa porta |
|---|---|---|
| **FEC** | Francia (art. A47 A-1 LPF) | ogni scrittura del periodo, nell'ordine di colonne imposto |
| **SAF-T** | lo standard OCSE, diversi paesi UE | il file di audit: conti, scritture, documenti |
| **DATEV** | Germania, per il software del consulente fiscale | le scritture nella disposizione che DATEV importa |

Tutti e tre coprono un periodo che scegliete voi e usano il **piano dei
conti** configurato sullo spazio — il conto IVA compreso, ed è per questo
che quel campo appartiene all'identità legale e non all'esportazione. Un
periodo già esportato non è bloccato: un export è una lettura, e può
essere ripreso dopo una correzione.

## Integrazioni

| Integrazione | Che cosa fa | Senza di essa |
|---|---|---|
| **Fornitore di pagamento** | incassa un pagamento a fronte di una fattura | i pagamenti si registrano a mano; nient'altro cambia |
| **Canale WhatsApp** | manda un sollecito o un avviso su WhatsApp | il messaggio resta nella posta dell'app |
| **Push** | consegna le notifiche a un dispositivo | le notifiche compaiono all'apertura dell'app |
| **Piattaforma di fatturazione elettronica** | trasmette la fattura strutturata | il PDF è prodotto e inviato per altre vie |

Due regole valgono per tutte. **Le credenziali vivono sullo spazio**, in
una tabella che il file di spazio e ogni deployment saltano: nessun
export porta quindi mai una chiave. E **un'integrazione non configurata
degrada, non si rompe**: la funzionalità che la richiede è spenta, la
schermata lo dice, e nulla solleva eccezioni.

## Istanze

Un'**istanza** è un DesKilo intero sulla propria base dati. Due spazi —
anche una coppia di sviluppo e produzione — ne condividono una; due
istanze non condividono nulla. Usatene una dove dati personali o
credenziali di pagamento devono essere fisicamente separati, o dove un
cliente pretende la propria base dati.

Il **bundle** è il materiale da costruzione dell'istanza: ogni migrazione
in ordine, le funzioni edge, i bucket di archiviazione e il seme. Viene
rigenerato a ogni migrazione applicata, così bundle e base dati viva non
vanno mai fuori passo.

Create un'istanza dall'assistente dell'app o da
`dart run tool/instance.dart`; entrambi applicano il bundle a una base
vuota e timbrano a quale migrazione si trova. Una migrazione successiva
raggiunge un'istanza esistente per la stessa via — applicata in ordine dal
timbro in avanti, mai rieseguita.

La versione è un numero che lo schema porta con sé:
`select public.deskilo_schema_version();` restituisce l'ultima migrazione
applicata, e ogni migrazione lo scrive nella propria transazione (#1312).
Un'app più vecchia del suo server continua a funzionare. Un'app **più
recente** del suo server si ferma su *Questo server deve essere
aggiornato*: chi gestisce il server applica le migrazioni mancanti; gli
altri possono aprire da lì la schermata Server e puntare il dispositivo
altrove. Senza rete il controllo semplicemente non avviene, e nulla viene
bloccato.

Configurazione e dati anagrafici viaggiano fra istanze attraverso il
**file di spazio**, dato che un deployment ha bisogno di una sola base
dati e un'istanza è esattamente il punto in cui ce ne sono due.

## Il registro

*Impostazioni → Sviluppatore.* Un buffer circolare delle ultime 500 voci,
appoggiato a un file sul dispositivo, con ogni errore del framework e
della piattaforma agganciato fin dalla prima riga di `main()`.

Tre forme, e quella di mezzo è la utile:

- **step** — una decisione o un giro sul server andato come previsto.
- **refused** — l'app che declina ciò che qualcuno ha cercato di fare.
  Livello di avviso, e la prima cosa da cercare quando la segnalazione è
  *«ho premuto e non è successo niente»*.
- **failed** — un'eccezione, che porta gli stessi campi dello step che ci
  stava provando, così una riga rossa non resta mai orfana del suo
  contesto.

Ogni riga è un verbo seguito da coppie `chiave=valore`, quindi un
registro si può grepare: `grep 'act=check-in'` legge un tipo di tentativo
da capo a fondo, e `grep 'server='` legge ogni rifiuto emesso dal server,
con codice, messaggio, dettagli e suggerimento in un solo campo.

**Un registro è per dispositivo.** Il registro che risponde a *«un membro
non è riuscito a registrare l'ingresso»* sta sul telefono di quel membro.
*Esporta* lo scrive in un file timbrato con la versione dell'app e lo
spazio, ed è ciò che lega un registro esportato alla segnalazione a cui
risponde. I payload scansionati sono annotati per **forma** — schema,
host, quali parametri sono presenti, quanto lunghi — mai per valore,
perché un codice di invito è un segreto e un registro è fatto per essere
mandato a qualcuno.

**Uno «started» senza il suo «done»** significa che l'atto non è mai
tornato: l'app è stata uccisa, la richiesta non è mai rientrata, o un
`await` è appeso. Quel buco è la scoperta.

# Ambienti — uno spazio per provare, uno spazio che è reale

Due spazi, un solo nome. Su uno configuri, importi, stampi e rompi cose;
sull'altro le persone prenotano posti e ricevono fatture che sono
dovute. Ciò che fissi sul primo, lo distribuisci sul secondo.

## Perché una coppia

Uno spazio di coworking è configurato da chi lo gestisce, non da un
integratore, e la configurazione è il punto in cui gli errori sono
economici da commettere e cari da scoprire: una tariffa digitata due
volte, un'aliquota IVA sul gruppo sbagliato, una piantina i cui posti si
sono spostati dopo che qualcuno li aveva prenotati. Uno spazio di
sviluppo non costa nulla e assorbe tutto questo. Ogni documento che
stampa porta la **filigrana di sviluppo**, le sue fatture elettroniche
vanno all'endpoint di prova, e nulla di ciò che produce può essere
scambiato per un documento reale.

![](assets/help/images/env-pair-profiles.jpg)

*La schermata Profili: uno spazio accoppiato porta DEV e PROD su una sola riga — uno spazio, due ambienti, e la spunta mostra in quale ti trovi.*

## Creare la coppia

Un nuovo spazio nasce **con il suo gemello**: stesso nome, stesso paese,
stessa valuta, stesso fuso orario, entrambi tuoi dal primo secondo.
*Profili* mostra la coppia come un'unica scheda con due chip, **DEV** e
**PROD**; toccare un chip cambia lato, e quel cambio diventa la tua
impostazione predefinita, così un riavvio apre dove eri rimasto.

Uno spazio creato prima che le coppie esistessero, o creato da solo,
riceve il suo gemello su richiesta: *Impostazioni → Avanzate → Crea il
gemello*. La configurazione è copiata una volta in quel momento; da lì
in poi i due lati sono indipendenti e solo una distribuzione sposta
qualcosa tra loro.

## Chi può fare cosa

Tre permessi nella matrice dei ruoli:

- **Accedere allo spazio di produzione** — senza di esso un ruolo non
  può essere membro del lato produzione affatto. I proprietari e i
  comproprietari ce l'hanno; gli amministratori ce l'hanno; i membri no,
  finché non glielo dai.
- **Distribuire in sviluppo** — tirare la configurazione del lato
  produzione dentro quello di sviluppo. Gli amministratori ce l'hanno.
- **Distribuire in produzione** — quello delicato, per impostazione
  predefinita solo proprietario e comproprietario. Chi lo detiene
  detiene anche *Distribuire in sviluppo*.

Ne seguono due regole. **Un membro del lato produzione è sempre membro
del lato sviluppo**: l'iscrizione è rispecchiata, ruolo e stato
compresi, così nessuno deve essere invitato due volte. E **un ruolo
entra nel lato produzione solo finché detiene il permesso di accesso** —
un invito, un'adesione o una presa in carico di profilo verso la
produzione viene altrimenti rifiutata, con il motivo a schermo.

## Lavorare sul lato sviluppo

Configura, importa un file di spazio, invita un collega, emetti una
fattura di prova, sposta posti, stampa. Nulla lì è reale: la filigrana
lo dice su ogni documento, e l'endpoint di prova della fattura
elettronica rifiuta di raggiungere una piattaforma governativa.

## Distribuire

*Impostazioni → Governance → Distribuzione*, sul lato che vuoi
**scrivere**. Una distribuzione va sempre **nel lato in cui ti trovi**:
sul lato produzione il pulsante dice *Tira da DEV*, su quello di
sviluppo *Tira da PROD*. Nulla può essere spinto sull'altro lato per
errore.

![](assets/help/images/env-deploy-screen.jpg)

*La schermata Distribuzione dal lato sviluppo: la frase in alto nomina la direzione, e ciò che spunti viene tirato dal gemello di produzione — dopo un'anteprima.*

### Cosa viaggia, entità per entità

Raggruppato in **Configurazione**, **Dati anagrafici** e **Report**:

| Gruppo | Entità |
|---|---|
| Configurazione | Identità e menzioni di legge · Regole di prenotazione · Regole di validazione · Matrice dei ruoli · Regole di sollecito · Istruzioni di pagamento · Collegamenti ai documenti · Giorni di chiusura · Modelli di invito · Funzionalità |
| Dati anagrafici | IVA · Tariffe · Servizi · Pacchetti · Accessori · Sedi · Piantine |
| Report | Progettazioni dei documenti, con le loro immagini |

Spunta un'entità e ciò di cui ha bisogno si spunta con lei — i servizi
hanno bisogno delle aliquote IVA, una piantina ha bisogno dei suoi
accessori e delle sue sedi.

### La piantina è unita, mai sostituita

I piani si corrispondono per nome, gli uffici, i tavoli e i posti per
nome o, senza nome, per posizione. Ciò che ha l'altro lato è aggiunto o
aggiornato; ciò che ha solo questo lato è segnalato e **conservato**,
perché un posto può già portare una prenotazione. I badge e i blocchi
non viaggiano mai. Gli sfondi e le immagini della piantina sono copiati
insieme.

### L'anteprima, poi la conferma

Nulla si muove prima che un'anteprima dica, per entità, cosa verrebbe
aggiunto, cambiato e rimosso. Un'anteprima senza nulla da fare lo dice e
non distribuisce niente. Poi una conferma nomina il lato che sta per
essere scritto e le entità, perché quello è il momento in cui un errore
diventa caro.

### Il giornale e la via del ritorno

Ogni distribuzione è registrata: chi, quando, in quale direzione, quali
entità, e cosa conteneva la destinazione prima. *Annulla* sull'ultima
ripristina esattamente quello. Un annullamento è rifiutato finché una
distribuzione successiva insiste sullo stesso lato — annullale in
ordine.

### Cosa non viaggia mai

I membri, le prenotazioni, i conti, le fatture, i pagamenti, gli eventi,
i messaggi, le credenziali di ogni tipo e i contatori di numerazione.
Una serie di numeri si distribuisce come **formato**; il numero
successivo appartiene sempre allo spazio che lo emette.

## Quando una coppia non basta

Due spazi condividono un database. Dove dati personali o credenziali di
pagamento devono essere fisicamente separati, accoppia invece
**istanze**: la procedura guidata di nuova istanza costruisce un secondo
database dal pacchetto, e le stesse entità viaggiano tra i due
attraverso il file di spazio.
