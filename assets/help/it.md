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

### Profili — un account, più spazi

Un account può appartenere a più spazi. **Impostazioni → Profili** li elenca tutti: ogni riga mostra il nome dello spazio, **il tuo ruolo lì** (Membro, Admin, Proprietario) e il suo ID. Il **segno di spunta** indica il profilo in cui ti trovi adesso; la **stella** indica quello **predefinito** — il profilo con cui l'app si apre, su ogni dispositivo e anche dopo una reinstallazione (la scelta è salvata con il tuo account). Tocca una riga per cambiare, **+ Aggiungi un profilo** per unirti a un altro spazio ancora. Tutto nell'app è riferito allo spazio attivo.

### Orientarsi

L'app ha fino a cinque destinazioni lungo il bordo inferiore: **Messaggi** (§16), **Calendario** (§5), il grande pulsante centrale **Prenota** (§4), **Membri** (§6) e **Finanze** (§9). Messaggi e Prenota ci sono sempre; Calendario, Membri e Finanze vanno e vengono con la loro funzionalità (§8). **Messaggi è la casella**: le tue conversazioni e il flusso di eventi e conferme (§7) sono le sue due facce, e la **campanella** nella barra dell'app salta dritta alla seconda, con il conteggio di ciò che ti aspetta. L'**ingranaggio** che apre le **Impostazioni** (§12) è invece in ogni intestazione. Sui telefoni in orizzontale e sui tablet la maggior parte delle schermate passa a un **layout diviso** — i controlli in un pannello laterale, il contenuto a riempire il resto.

**Tutto resta dal vivo.** Qualunque cosa qualcuno cambi — una prenotazione, un nuovo membro, un'impostazione — viene inviata in pochi secondi a ogni dispositivo connesso, compreso quello che ha fatto la modifica. Nessun riavvio, nessun trascinare-per-aggiornare.

## 2. Ruoli e inviti

DesKilo ha tre ruoli cumulativi e, sopra di essi, una variante di comproprietà, più un account dispositivo:

| Ruolo | Può |
|---|---|
| **Membro** | Fare check-in/out, prenotare, presentare spese, vedere e gestire i propri eventi e il proprio conto |
| **Admin** | Tutto ciò che può un membro, più: agire *per chiunque* (prenotazioni, pagamenti, spese — soggetto a conferma, §7), approvare le spese, emettere badge per il chiosco |
| **Proprietario** | Tutto ciò che può un admin, più: modificare lo spazio fisico, definire piani e prezzi, gestire ruoli, dispositivi chiosco e impostazioni dello spazio |
| **Comproprietario** | *Attivo*: i permessi del proprietario da subito, più la successione automatica. *Passivo*: un successore in attesa, oggi senza permessi aggiuntivi |
| **Chiosco** | Un account per tablet a parete (§10) — mostra solo la piantina; i membri veri agiscono attraverso di esso con un badge |

Una parte di tutto questo non è scolpita nella pietra: il proprietario riregola **nove permessi di amministrazione** nella matrice **Gestione dei ruoli** (§8) — gestire i ruoli, gestire i membri, regole di convalida, impostazioni dello spazio, emettere fatture, consultare le finanze, documenti, servizi, approvare le spese. Ciò che la matrice *non* governa è il quotidiano — fare check-in, prenotare, agire per un altro membro, modificare lo spazio — che resta dove lo mette la tabella qui sopra, retto invece dalle funzionalità e dagli interruttori per singolo membro.

**Ogni invito è legato a un ruolo.** Nella schermata *ID spazio & QR* del proprietario due schede contengono due inviti, ciascuno con il proprio QR e il proprio codice:

- **Invito membro** — l'ID dello spazio stesso, mostrato sotto il nome dello spazio. Stampalo, appendilo alla parete, condividilo liberamente: chi lo scansiona o lo digita chiede di entrare come semplice membro, e un validatore lo ammette (§7). Pulsanti: **Copia l'ID**, **Condividi come PNG**, **Cambia l'ID dello spazio** (sostituisci l'ID generato con uno memorizzabile, 4–20 lettere/cifre) e **Invita qualcuno**.
- **Invito admin** — un **codice personale monouso**, emesso da un proprietario per una persona precisa. La schermata lo dice chiaramente: *questo codice ammette UNA persona come admin, poi scade* (un codice inutilizzato decade dopo 14 giorni). Consegnalo solo alla persona a cui è destinato; emettine uno nuovo per ogni admin con **Nuovo codice admin**.
- **Gli inviti parlano la lingua dell'invitato** — il foglio d'invito scrive il messaggio nella lingua che scegli (cinque disponibili), per impostazione predefinita la **lingua dello spazio** definita nelle *Impostazioni dello spazio*. Lì il proprietario può anche personalizzare il testo dell'invito **per lingua**, con segnaposto come `{firstName}`, `{workspaceName}`, `{inviteLink}`, `{downloadUrl}`, `{role}`; una lingua lasciata vuota usa il messaggio integrato tradotto.

**Non esiste un invito proprietario — di proposito** (il piè della schermata te lo ricorda). La proprietà può essere concessa solo da un proprietario esistente, in *Membri e piani*. Uno spazio mantiene sempre almeno un proprietario. Promuovere o retrocedere un **admin** passa dal flusso di validazione (§7) — si applica quando i validatori dello spazio confermano.

**I comproprietari tengono in vita lo spazio.** Il proprietario nomina qualsiasi membro o admin come comproprietario (*Membri e piani → il membro → Comproprietà*), in una di due varianti: un comproprietario **attivo** lavora da subito con i permessi del proprietario; un comproprietario **passivo** non ha permessi aggiuntivi fino al giorno in cui servono. In entrambi i casi la successione è automatica: se l'ultimo proprietario se ne va — esce, viene rimosso, o il suo account scompare — il miglior comproprietario (attivo prima di passivo) **diventa proprietario all'istante**, sul server, senza alcuna azione richiesta. Il proprietario può anche passare la mano deliberatamente in qualsiasi momento con *Promuovi a proprietario ora*. Una sfumatura: le regole di validazione che esigono l'approvazione del *proprietario* (§7) intendono sempre un proprietario vero e proprio, non un comproprietario attivo.

Il QR codifica un link che nomina il ruolo concesso (`deskilo://join?role=…`). Manomettere il link non cambia nulla — il server ricava il ruolo dal codice stesso: l'ID dello spazio fa sempre entrare come membro, e un invito personale fa entrare esattamente nel ruolo con cui è stato emesso, una sola volta. Un codice admin inoltrato già usato — o scaduto — non ammette nessuno.

**Invitare via messaggio** (*Invita qualcuno*): ogni invio WhatsApp/SMS/condivisione emette il proprio codice personale monouso e compone un messaggio pronto nella lingua dell'invitato. Il destinatario può semplicemente copiare l'intero messaggio e incollarlo nel campo di adesione dell'app — il codice viene rilevato automaticamente.

## 3. La piantina (nell'hub Prenota)

La piantina mostra il livello attivo del tuo spazio: uffici, tavoli e posti, con codice colore — **libero**, **prenotato**, **occupato**, **mio**, **bloccato**. Si apre **all'istante dagli ultimi dati noti** e si aggiorna in background — con un Wi-Fi instabile vedi comunque lo stato più recente invece di una schermata vuota. Un posto occupato mostra chi c'è con la sua **iniziale** — o con la sua **foto**, se l'ha impostata e il proprietario ha attivato *Foto dei membri sulla piantina* — più un **badge di check-in** quando è arrivato e un **punto verde** quando è online nell'app in questo momento. I nomi per esteso compaiono dove c'è spazio: sul chip con lucchetto di una prenotazione di spazio intero e nella vista a elenco. Quando un **tavolo, una sala o un piano intero** è prenotato, lo dice lo spazio stesso — una velatura colorata, un bordo marcato e un **chip con lucchetto e il nome dell'occupante** al centro (un glifo di check-in quando è arrivato); l'etichetta della sala recita *Bureau 2 · Florian*. Lo vedono tutti gli utenti, sulla piantina, nell'hub Prenota e sul chiosco.

La piantina può somigliare al tuo spazio reale: il proprietario può mettere una **foto della stanza come sfondo del livello** e piazzare liberamente **immagini illustrative ridimensionabili** (piante, divani…) sulla griglia. Un cursore di **trasparenza dei tavoli** nelle impostazioni dello spazio lascia trasparire la foto sotto i tavoli disegnati.

Muoversi:

- In alto: un interruttore **mappa / elenco** (l'elenco mostra gli stessi posti come righe), il **chip della data** (tocca per sfogliare un altro giorno) e i controlli della finestra, che seguono la granularità del tuo spazio (§8): tre **chip di fascia oraria** — mattina, pomeriggio, giornata intera — dove lo spazio prenota a mezze giornate; solo *Giornata intera* dove prenota a giornate; controlli **da → a** su una griglia di minuti o a orari liberi; e gli uni e gli altri con gli *orari reali*.
- La tela **si adatta da sola** al tuo piano all'apertura o alla rotazione del dispositivo; **pizzica per zoomare** o usa i pulsanti **+ / −**, trascina le **barre di scorrimento** ai bordi e tocca il pulsante di **adattamento** per ricentrare.
- Scegli il piano dalla **barra dei livelli** a destra (1, 2, …); la sua **icona livelli** agisce sull'intero livello (sotto). In **orizzontale**, i controlli passano in un pannello laterale e la piantina riempie lo schermo — comodo sui tablet.

Prenotare dalla piantina:

- **Check-in al volo**: tocca un posto libero → la scheda propone *adesso* fino a un bordo canonico → conferma. Con le mezze giornate e le giornate intere il server **riporta poi l'inizio all'inizio dello slot** a cui la finestra appartiene: arrivi alle 10:00, confermi *fino alle 12:00*, e prenoti — e consumi — tutta la mattina 8:00–12:00 (§4b). Se qualcuno ha prenotato quel posto più tardi, la tua ora di fine viene limitata e te lo diciamo.
- **Check-in su prenotazione**: fare check-in significa *sei qui*. Con mezze giornate, giornate intere e orari reali la finestra si apre a **qualsiasi ora del giorno stesso della prenotazione**: alle 10:00 puoi già fare check-in sul tuo pomeriggio delle 12:00. Su una griglia di minuti si apre 15 minuti prima del tuo inizio, o un passo di griglia prima se quel passo è più lungo (così le griglie da 5 e 15 minuti mantengono i 15 minuti, una griglia oraria apre un'ora prima). Si chiude alla fine della prenotazione; fuori dalla finestra il pulsante è disattivato e dice quando apre. Gli admin possono fare il check-in di un membro presente al suo posto (finché *prenota per altri* è attivo).
- **Check-out**: manuale — e **accorcia la prenotazione ad adesso**, così il posto si libera subito per tutti gli altri. È **personale per impostazione predefinita**: un admin (proprietario compreso) può chiudere il check-in di qualcun altro solo se *Gli amministratori possono fare il check-out dei membri* è attivo (§8). Con l'**auto check-in/out** attivo, le prenotazioni dimenticate si chiudono da sole — la pulizia gira a ogni lettura, quindi una prenotazione della mattina lasciata aperta viene completata alla sua stessa fine già dalle 12:01, non a mezzanotte.
- **Spazi interi**: **tocca due volte** un tavolo, una stanza o un tratto libero del pavimento — oppure tocca l'**icona livelli** sulla barra dei livelli — per agire sull'**intero tavolo, ufficio o piano**. **Una sola scheda** contiene tutto: il nome dello spazio, il selettore di periodo (es. *gio 6 ago 10:13 → 12:00*) con le stesse opzioni di ripetizione di una postazione, un selettore facoltativo **Per il membro** per gli admin che prenotano per conto di qualcuno, e il pulsante di conferma.
- **Selettore orario**: scegli una finestra da→a (o Mattina / Pomeriggio / Giornata intera, secondo la granularità dello spazio) per vedere l'occupazione in qualsiasi momento futuro.
- I posti possono avere **accessori** (monitor, scrivania regolabile…), alcuni con supplemento per mezza giornata che compare sul tuo estratto.
- Le prenotazioni contano sui tuoi **giorni mensili** (§9) — oltre il tuo piano, l'app blocca o addebita, secondo ciò che il proprietario ha configurato per te. Un'eccezione: una prenotazione che sta **interamente fuori dagli orari di lavoro** può essere gratuita o esente, secondo la regola fuori-orario dello spazio (§4b).

## 4. Prenotazioni (hub Prenota)

Apri l'hub **Prenota** (pulsante centrale). In alto: due righe di controlli. La prima dice **che cosa** stai guardando: i quattro **pulsanti di vista** e, sulla piantina, il selettore **piantina / elenco**. La seconda dice **quando**: il **chip della data**, un pulsante **Adesso** appena ti allontani da oggi, e gli stessi controlli della finestra legati alla granularità della piantina stessa (§3 — chip di fascia oraria, un chip *Giornata intera*, oppure da → a). I **chip di piano** (*Tutti i piani*, o uno per livello) stanno sulla piantina stessa, e il pulsante di **scansione QR** (§4a) sta nella barra dell'app, accanto all'editor e alla campanella. Poi quattro viste:

- **Piantina** — la piantina filtrata sulla finestra scelta; tocca un posto libero per prenotarlo.
- **Giorno** — ogni posto come riga temporale del giorno selezionato (08:00 → 17:00 o l'orario del tuo spazio, la linea rossa segna *adesso*); tocca un tratto libero per prenotare, tocca il tuo blocco per vederne i dettagli.
- **Settimana** — una griglia posto × giorno dell'intera settimana ISO, con una striscia dei giorni (*lun 3 … dom 9*) in alto; ogni cella contiene le mezze giornate del giorno con l'iniziale dell'occupante. Trova una mezza giornata libera a colpo d'occhio e toccala per prenotare.
- **Mese** — un calendario di disponibilità: ogni giorno mostra il suo **conteggio di scrivanie libere** (es. *10/12*); tocca un giorno per entrare nella sua vista Giorno.

**Un posto alla volta — per impostazione predefinita**: lo spazio stabilisce quante prenotazioni sovrapposte un membro può tenere, e quel numero è **1** finché il proprietario non lo alza (§8). A 1, prenotare o fare check-in altrove mentre un'altra è in corso viene rifiutato; in ogni caso un check-in chiude ogni check-in precedente la cui prenotazione è già finita. Gli admin e i proprietari possono **scavalcare**: toccare un posto occupato o prenotato offre *Rimuovi la prenotazione (scavalca)* — la prenotazione viene rimossa e il membro e tutti gli admin vengono avvisati tramite il flusso degli eventi.

Le prenotazioni seguono la **regola di granularità** dello spazio (§8 Disponibilità) — mezze giornate, giornate intere, orari reali (da–a esatto, con le finestre di mezza/giornata intera come scorciatoie), oppure orari liberi di inizio/fine sulla griglia di minuti del proprietario. Mezze giornate e giornate intere coprono l'**orario di lavoro** configurato dello spazio (predefinito 8:00–17:00, con il limite di mezza giornata alle 12:00). Rispettano i **giorni di apertura** e i **giorni di chiusura**, e le regole di prenotazione (orizzonte di anticipo, durata minima e massima). **Una prenotazione finisce sempre nel giorno in cui inizia** — nulla attraversa la mezzanotte; una permanenza che continua domani è la prenotazione di domani, fatta domani (§4b). Esigenze ricorrenti? Prenota una **serie** (giornaliera, feriale, settimanale) — giorni chiusi e conflitti vengono saltati e segnalati.

**Eliminare una prenotazione passata o con check-in è una richiesta, non un'azione.** Una prenotazione il cui inizio è passato — o dove hai già fatto check-in — non si annulla direttamente: la scheda offre invece **Richiedi eliminazione**. Un proprietario o admin decide l'unica domanda che conta per la fatturazione: il check-in è stato semplicemente dimenticato (la prenotazione resta agli atti), o non è mai stata usata (viene rimossa)? La richiesta appare nel flusso Eventi con il tuo motivo facoltativo; le prenotazioni future mai toccate mantengono il normale annullamento con un tocco. Tutto questo percorso viaggia sulla funzionalità **Richieste di eliminazione prenotazioni**: disattivata, una prenotazione iniziata o con check-in non ha né pulsante di annullamento né richiesta — resta semplicemente agli atti.

### 4a. Scansionare un codice spazio

Ogni postazione, tavolo, ufficio e piano può avere una **scheda QR** stampata (§8). Tocca il **pulsante di scansione** nell'hub Prenota, inquadra la scheda — o digita il suo codice — e l'app identifica lo spazio e mostra esattamente ciò che *tu* puoi farci:

- **Scheda postazione** — prenota o fai check-in su quella precisa postazione, al momento (finestra di oggi: mattina / pomeriggio / giornata intera dove lo spazio usa le mezze giornate, altrimenti da adesso per le prossime ore).
- **Scheda tavolo** — le postazioni del tavolo con il loro stato in tempo reale; scegline una libera. Un tavolo che il proprietario ha reso prenotabile offre anche il **tavolo intero**, con il suo prezzo per mezza giornata, esattamente come una scheda di ufficio o di piano.
- **Scheda ufficio o piano** — se il proprietario lo ha reso prenotabile, la funzionalità *Prenotazioni di tavolo, ufficio e piano* è attiva **e** possiedi il diritto personale (§8) — proprietari e admin lo hanno sempre — puoi prenotare o fare check-in sull'**intero ufficio o piano** — con lo stesso selettore di periodo (mattina / pomeriggio / giornata intera, o orari liberi) e le stesse opzioni di **serie** di una postazione; il suo prezzo per mezza giornata viene mostrato e finisce sulla tua fattura. Altrimenti la scheda ti spiega perché, e un ufficio ripiega sulle sue postazioni.

**Una scansione apre la scheda del chiosco.** Leggere il codice di una **postazione** — la sua scheda QR stampata, o il tag NFC applicato sulla sedia — propone esattamente ciò che propone il chiosco quando si tocca quella postazione: le stesse tre azioni (**Check-in**, **Prenota**, **Check-out**), lo stesso periodo dedotto dalle impostazioni dello spazio. Unica differenza: hai già effettuato l'accesso, quindi il passaggio del badge non c'è (§4b). Le schede di tavolo, ufficio e piano aprono invece la propria scheda di spazio intero, come descritto sopra; i **tag NFC portano solo a una postazione**, quindi il tag sulla sedia è l'unica scorciatoia «tocca e prenota».

**I conflitti proteggono in entrambe le direzioni:** un ufficio o un piano non può essere prenotato mentre una postazione al suo interno è già prenotata in quella finestra — e nessuna postazione può essere prenotata mentre il suo ufficio o piano è prenotato per intero.

### 4b. Come si comporta la prenotazione

Tutti gli orari qui sotto sono locali dello spazio, e gli esempi assumono la giornata lavorativa predefinita (08:00 – 12:00 – 17:00).

**Prenotare in anticipo.** La forma possibile di una finestra dipende dalla granularità dello spazio (§8 Disponibilità):

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

## 5. Calendario (scheda Calendario)

Il mese a colpo d'occhio, con due ambiti e due forme:

**Il calendario è un selettore, non un palcoscenico (#718).** Scegli un **giorno** o un **periodo**; vedi un unico flusso di tutto ciò che ha una data e che puoi vedere — prenotazioni, check-in e check-out, avvisi, messaggi, fatture, pagamenti, consumi, promemoria — raggruppato per giorno, filtrato per tipo con i chip, e **ogni riga apre la sua origine** (la prenotazione, la conversazione, l'avviso, la fattura, il mese in Finanze). Chi ha il permesso finanze o amministrazione membri può guardare un altro membro; i tipi che il server non consente per quel membro appaiono **bloccati**, mai come un giorno vuoto. Lo scudo apre *Chi può vedere questo*, con il registro degli accessi.

- **Le mie / Tutti** — le tue prenotazioni, o quelle dell'intera comunità; l'interruttore ce l'ha ogni membro, dato che la piantina e la griglia settimanale dell'hub Prenota mostrano già l'occupazione di tutti. I puntini sotto un giorno dicono tutto a colpo d'occhio: **rosso** = hai una prenotazione, **blu** = ce l'hanno altri membri, **entrambi i puntini** = tutte e due. Oggi è cerchiato.
- L'**interruttore di forma** accanto commuta la metà inferiore tra una **vista elenco** (ogni prenotazione come scheda: finestra oraria, membro, spazio) e una **vista cronologia** (posti × le ore del giorno selezionato). La griglia posti × *giorni* della settimana vive nell'hub Prenota (§4), non qui.
- I **chip di piano** (*Tutti i piani* / per livello) filtrano la **cronologia**.
- Tocca un giorno nella griglia del mese per caricarlo sotto. In orizzontale, calendario e dettaglio usano il layout diviso.

## 6. Elenco dei membri (scheda Membri)


**Tocca un membro per il suo profilo (#704).** Foto, ruolo e stato; che cosa ha prenotato e se ha fatto il check-in in questo momento; e **Contatti** — il numero WhatsApp condiviso volontariamente per tutti, l'**indirizzo e-mail e la quota di piano per gli admin**. Dove hai il diritto di vedere le cifre — **le tue sempre, quelle di un altro con il permesso *Vedere le finanze*** — il profilo porta anche **Finanze**: la posizione netta (chi deve che cosa a chi), le fatture aperte con quanto resta su ciascuna, i pagamenti già arrivati e il mese in corso. La stessa scheda della scheda Finanze, così le due non possono contraddirsi.

Guarda chi fa parte della tua comunità:

- Ogni scheda membro mostra la **foto** (o l'iniziale), il **chip di ruolo** (Admin, Proprietario), lo **stato personalizzato** («a Berlino fino a venerdì…»), un indicatore **online / ultimo accesso** (*Online*, *10 min*, *2 g*) e un **chip di prenotazione**: posto con check-in, *Prenotato adesso*, o la prossima prenotazione in arrivo.
- Tocca un membro per la sua **scheda di dettaglio** — ruolo, presenza, le sue **prossime prenotazioni** e **Messaggi**.
- **Messaggi**: un **filo di conversazione** per membro (fino a 500 caratteri per messaggio) — aprilo dalla scheda **Messaggi** (§16), dalla scheda del membro o dal suo profilo nell'elenco, leggi tutto lo scambio a fumetti e invia dallo stesso posto. Ogni messaggio raggiunge l'altra parte per due vie: un **push che non trasporta alcun contenuto** (*«Hai un nuovo messaggio»* — per scelta di privacy) e, ad app avviata, una notifica locale che mostra invece il tuo nome e il tuo testo.). Il testo completo resta sempre leggibile nella scheda **Messaggi**, per il destinatario e per il mittente (il push in sé non trasporta contenuto, per scelta di privacy). Gli admin hanno un megafono **Notifica tutti gli admin** — in *Membri e piani* (Impostazioni → Amministrazione), non nella scheda Membri, che non ha una barra dell'app propria — e raggiunge tutti gli admin, proprietario incluso. Attivabile/disattivabile con la funzionalità *Notifiche tra membri*. Durante la scrittura, due chip permettono di **collegare una prenotazione o un check-in in corso — tuoi o di un altro membro** — o **uno spazio** (posto, tavolo, stanza o piano) — il riferimento appare come link toccabile da entrambe le parti: un link di prenotazione apre quella prenotazione, un link di spazio apre la scheda di prenotazione dello spazio, ideale per discutere una prenotazione futura.
- L'**icona messaggio** su una scheda scrive a quel membro su **WhatsApp** (se ha condiviso il numero); il **pulsante gruppo** apre il gruppo WhatsApp della tua comunità (impostato dal proprietario).
- Imposta la tua foto, il tuo stato e la visibilità del telefono in **Impostazioni** (§12).
- Gli admin e i proprietari vedono in più l'**email** di ogni membro sotto il nome — i membri normali no: il contatto tra membri resta il numero WhatsApp condiviso volontariamente.

## 7. Eventi e conferme (Messaggi → Eventi)

**Dove si trova.** Il flusso è la seconda faccia della scheda **Messaggi**, e la **campanella** in ogni barra dell'app porta dritto lì, con il conteggio di ciò che ti aspetta. Un solo posto tiene gli avvisi: leggerne uno lì è averlo letto ovunque.

Il flusso eventi è la traccia di controllo del tuo spazio: prenotazioni create/modificate/cancellate, pagamenti registrati, fatture pagate, spese presentate, richieste di giorni extra, cambi di ruolo, richieste di eliminazione. I membri vedono i propri eventi; admin e proprietari vedono quelli di tutti. I **chip di filtro** (Tutti · Prenotazione · Pagamento · Spesa · …) restringono l'elenco — la tua scelta viene ricordata — e un menu **Raggruppa per** ripiega il feed in gruppi per tipo, giorno o membro (toccare il simbolo del gruppo riporta all'elenco piatto); ogni riga porta la sua icona di stato — una **clessidra** finché in sospeso, una **spunta verde** una volta confermata — e gli eventi di denaro mostrano *chi li ha validati e quando* direttamente sulla riga.

**In attesa della tua conferma:** ogni volta che un admin fa qualcosa *per qualcun altro* — ti prenota un posto, registra il tuo pagamento, retrocede un admin — resta **in sospeso finché non viene confermato**. Le voci in sospeso sono fissate in alto con una ✕ rossa e un pulsante verde **Accetta**, e ricevi una notifica. Le azioni che compi su te stesso non richiedono mai conferma.

**I messaggi si sono spostati.** I messaggi tra membri vivono ora in una scheda **Messaggi** dedicata (§16), non più qui — un messaggio in due posti è uno che puoi segnare come letto in uno e vedere ancora non letto nell'altro. Questo flusso tiene l'unico tipo che non ha una conversazione in cui stare: una **diffusione a tutti gli amministratori**.

**Quorum di validazione:** per le questioni di denaro e i cambi di ruolo il proprietario definisce *chi* deve approvare e *quante* approvazioni servono. **Nessuno valida il proprio evento** — solo un'altra persona può (un'eccezione, configurata dal proprietario, per le eliminazioni di prenotazione, più sotto); dove non esiste un altro validatore, la richiesta semplicemente attende. Dopo 7 giorni senza risposta, ciò che accade dipende da come è rivolta la richiesta. Una richiesta **che hai presentato tu** per te stesso — un'eliminazione, mezze giornate extra, l'annullamento di un saldo — **scade**: nulla di costoso viene mai concesso in silenzio. Qualcosa che un admin **ha fatto per te** — una prenotazione creata o modificata, un pagamento registrato — **si conferma da sé**, perché è già avvenuto e il flusso ti chiedeva solo di prenderne atto; una prenotazione che un admin ha fatto per te viene allora concessa e consuma la tua quota.

Il proprietario regola tutto questo per **dominio** in **Impostazioni → Regole di validazione** — tredici schede, una per tipo di evento, ognuna che eredita dalla **regola predefinita** finché non viene modificata: *Regola predefinita, Pagamento, Spesa, Servizio, Mezze giornate extra, Eliminazione prenotazione, Cambio di ruolo, Nuovo membro, Prenotazione, Prenotazioni di spazi interi, Pagamento fattura, Rettifica* e *Annullamento del saldo*. Una regola stabilisce il numero di validazioni richieste, *quali* admin possono validare (tutti, o alcuni nominati) e se il proprietario deve sempre dare l'approvazione finale. La regola **Eliminazione prenotazione** porta due interruttori in più — *gli admin eliminano senza validazione* e *i proprietari eliminano senza validazione*, entrambi **disattivati per impostazione predefinita** — l'unica eccezione, deliberata, al «nessuno valida il proprio evento»: la richiesta di eliminazione dell'interessato si risolve da sola e resta segnata come **auto-validata** nel flusso. Valgono per le eliminazioni di prenotazione e per nient'altro.

![](assets/help/images/validation-rules.jpg)

 

![](assets/help/images/validation-rule-edit.jpg)

*A sinistra: una regola per dominio, che eredita da quella predefinita. A destra: la modifica di una regola — validazioni richieste, validatori autorizzati, approvazione del proprietario.*

## 8. Per i proprietari: editor e impostazioni

Tutta l'amministrazione vive in **Impostazioni → Amministrazione** — *Spazio di coworking* (le impostazioni dello spazio), *ID dello spazio e QR*, *Membri e piani*, *Gestione dei ruoli*, *Disponibilità*, *Fatturazione*, *Istruzioni di pagamento*, *Servizi*, *Regole di validazione*, *Fatturazione e report* (l'hub di fatturazione con l'editor di report e le regole di sollecito nella sua intestazione), *Funzionalità* e le voci legate alle funzionalità (*Accessori*, Pagamenti online, Badge RFID/NFC…). Una sola regola da conoscere: **la voce di impostazioni di una funzionalità appare solo finché quella funzionalità è attiva** — disattiva *Pagamenti online* in **Funzionalità** e la sua schermata di configurazione scompare con essa (e ritorna quando la riattivi). La voce **Funzionalità** è sempre presente, così puoi sempre riattivare un modulo.

**Paese, valuta, fuso orario (#711).** La scelta del paese copre ora i 32 paesi per cui l'app sa dichiarare le imposte (UE-27, Svizzera, Norvegia, Regno Unito, Stati Uniti e Canada). La valuta è un **selettore** dei codici che l'app sa formattare — ognuno con il simbolo e il giusto numero di decimali: lo yen non ne ha, il dinaro ne ha tre, e ogni importo, fattura e pagamento online lo rispetta. Il fuso è un **elenco con ricerca** delle zone IANA che l'orologio sa installare; un refuso non si salva più.

![](assets/help/images/settings-administration.jpg)

### L'editor dello spazio

Apri l'**editor** dalla barra dell'app dell'hub Prenota (icona attrezzi incrociati). La schermata **Editor dello spazio** elenca i tuoi piani — trascina per riordinare, l'**icona livelli** marca un livello *Prenotabile per intero*, il **menu ⋮** rinomina o elimina, **+ Aggiungi un piano** estende l'edificio. Apri un piano per disegnarlo sulla griglia con la barra strumenti in basso — **Seleziona · Ufficio · Tavolo · Posto · Immagine · Cancella**:

- Un **ufficio** riceve un nome, un interruttore facoltativo *Prenotabile per intero* e un **prezzo per mezza giornata**.
- Un **tavolo** riceve un nome, la stessa opzione tavolo-intero e un proprio **prezzo per mezza giornata**.
- Un **posto** riceve un nome, un **orientamento di seduta** (↑ → ↓ ←), un **tipo di sedia** facoltativo, i suoi **accessori** (ognuno può avere un supplemento per mezza giornata) e un interruttore **Bloccato (manutenzione)**.
- **Immagine** piazza un'illustrazione ridimensionabile; l'icona foto nella barra dell'app imposta la **foto di sfondo** del livello.
- Eliminare uno spazio che ha una storia alle spalle è una decisione del **proprietario**, e con *Eliminare spazi con cronologia* attivo (il predefinito) funziona senz'altro: le prenotazioni che facevano riferimento a quello spazio ne conservano un'istantanea di testo, e ogni prenotazione ancora aperta su di esso viene annullata automaticamente. Disattiva la funzionalità e uno spazio con prenotazioni future va prima svuotato a mano.

### ID spazio & QR

I tuoi inviti legati ai ruoli (§2): invito membro = l'ID dello spazio (sostituiscilo con uno memorizzabile, copialo, condividi il QR come PNG), invito admin = codici personali monouso.

### Disponibilità

- **Giorni di apertura** — chip lun…dom.
- **Granularità di prenotazione** — una tra: *orari liberi*, *griglia di 5 / 15 / 30 / 60 minuti*, *mezze giornate (mattina e pomeriggio)*, *solo giornate intere*, oppure *orari reali* (da–a esatto, con le scorciatoie di mezza/giornata intera).
- **Orario di lavoro** — inizio giornata, limite di mezza giornata, fine giornata (predefinito 08:00 / 12:00 / 17:00). Le mezze giornate e le giornate intere ovunque — prenotazioni, check-in e fatturazione — seguono questi orari; con gli *orari reali* imposti anche quante ore vengono fatturate come mezza giornata e come giornata intera.
- **Giorni di chiusura** — eccezioni datate, aggiunte con **+**.
- **Regole di prenotazione** — quattro voci che allentano o stringono le regole del §4b (la sezione segue la funzionalità *Regole di prenotazione*); i due interruttori sono **disattivati per impostazione predefinita**:
  - **Consenti prenotazioni passate** — i membri possono registrare a posteriori una prenotazione già terminata (ieri e prima). Disattivato, tali prenotazioni sono rifiutate; prenotare una finestra precedente dello *stesso giorno* è sempre permesso. Attivalo negli spazi che annotano la presenza a cose fatte.
  - **Gli amministratori possono fare il check-out dei membri** — un admin può terminare il check-in in corso di un membro. Disattivato, il check-out è strettamente personale. Utile dove il personale chiude la sala la sera.
  - **Fuori dagli orari di apertura** — una domanda, quattro risposte mutuamente esclusive, le stesse su ogni granularità: *che cosa è possibile fuori dalla giornata lavorativa?* **Vietato** — niente: né prenotazioni in anticipo, né check-in spontanei, e anche una prenotazione che sfora la fine della giornata (o inizia prima dell'apertura) viene rifiutata. **Solo spontaneo** — il check-in spontaneo resta possibile a **entrambi i bordi della giornata**, l'arrivo mattutino prima dell'apertura tanto quanto lo straordinario serale fino a mezzanotte, mentre prenotare in anticipo fuori dagli orari viene rifiutato; qui è confluito il vecchio interruttore **Prenotazioni al minuto negli orari di lavoro**, e gli spazi che l'avevano attivo leggono così (quell'interruttore permetteva solo l'arrivo serale — la modalità prende il nome dalla spontaneità, non dalla sera, quindi anche l'arrivo mattutino è ammesso). **Gratis** — consentito, mai contato né fatturato (pura informazione di presenza). **A pagamento** (il **predefinito**) — contato come uso ordinario, salvo in un giorno in cui il membro tiene già una prenotazione regolare dentro gli orari: la parte fuori orario viaggia allora gratis.
  - **Prenotazioni simultanee per membro** — quante prenotazioni sovrapposte un membro può tenere, check-in compresi. **1** per impostazione predefinita: un posto alla volta. Un proprietario o un admin può concedere a un singolo membro una quota superiore in *Membri e piani* (mai a sé stesso), e quel permesso personale prevale su questo numero.

  Subito sotto stanno i **Limiti di prenotazione** — tre numeri che il server ha sempre applicato e che l'app ora sa impostare:

  - **Orizzonte di prenotazione** — quanti giorni prima può iniziare una prenotazione (predefinito **90**); oltre, viene rifiutata dicendolo.
  - **Durata minima** — la prenotazione più breve accettata (predefinito **30 minuti**), su ogni granularità. È esattamente per questo che un arrivo alle 11:45 per il limite delle 12:00 viene rifiutato: troppo corto.
  - **Durata massima** — la più lunga accettata (predefinito **24 ore**). Poiché una prenotazione finisce nel giorno in cui inizia, la giornata intera è il tetto e il selettore non propone nulla oltre.

  Se imposti un minimo superiore al massimo lo schermo lo segnala, perché il server controlla ogni limite per conto suo e si limiterebbe a rifiutare ogni prenotazione senza mai spiegare il motivo.

  I due interruttori di **auto-validazione** — *gli admin eliminano senza validazione*, *i proprietari eliminano senza validazione* — non stanno qui: vivono con le regole di validazione (§7), disattivati per impostazione predefinita, e arrivano soltanto alle eliminazioni di prenotazione.

### Funzionalità

Attiva o disattiva interi moduli per spazio — ogni interruttore porta la sua descrizione direttamente sullo schermo: scheda Calendario, scheda Eventi, raggruppamento delle notifiche, scheda Finanze, servizi, supplementi accessori, pagamenti online, fatture, gli admin emettono fatture, modello PDF della fattura, solleciti di pagamento (Mahnwesen), gestione dell'IVA, dichiarazioni IVA, invio della fattura elettronica al cliente, esportazione PDF, prenotazione in serie, prenota per altri, notifiche push, gli admin possono bloccare i posti, prenotazioni di tavolo/ufficio e piano, gli admin possono assegnare piani, modalità chiosco, badge RFID/NFC, badge QR, foto dei membri al chiosco, elenco dei membri, integrazione WhatsApp, codici QR degli spazi, tag NFC/RFID delle sedie, foto dei membri sulla piantina, comproprietari, check-in/out automatico, esportazione dati (Excel), orario di lavoro, regole di prenotazione, notifiche tra membri, biblioteca documenti, report dei membri, richieste di eliminazione prenotazioni, gestione dei ruoli, eliminare spazi con cronologia, suggerimenti di aiuto e animazioni dell'interfaccia. Disattivare un modulo rimuove *tutte* le sue schermate e i suoi pulsanti per ogni membro.

L'elenco è **gerarchico**: una funzionalità che ne richiede un'altra compare rientrata sotto di essa con una nota *Richiede…*, ed è in grigio finché la funzionalità madre è disattivata — *Finanze* porta con sé servizi, supplementi accessori, pagamenti online e fatturazione; *Fatture* porta la delega agli admin, il modello PDF, i solleciti di pagamento, la gestione dell'IVA (con le dichiarazioni ancora sotto) e l'invio della fattura elettronica al cliente; *Modalità chiosco* porta tre figlie — badge RFID/NFC, badge QR e foto dei membri al chiosco; le *prenotazioni di tavolo, ufficio e piano* portano *gli admin possono assegnare piani*; *Elenco dei membri* porta l'integrazione WhatsApp; la *scheda Eventi* porta il raggruppamento del feed. Disattivare una funzionalità madre toglie dall'app tutto il suo sottoalbero; la scelta salvata della funzionalità figlia torna intatta quando la madre riappare.

![](assets/help/images/workspace-id-qr.jpg)

 

![](assets/help/images/availability-granularity.jpg)

 

![](assets/help/images/features-toggles-1.jpg)

 

![](assets/help/images/features-toggles-2.jpg)

### Membri e piani

Tocca un membro per aprire la sua **scheda di gestione** — ogni azione per membro in un unico posto: **Invia l'accordo finanziario** (§11d), **Messaggi**, **Aggiungi un servizio** (servizio, quantità, mese di fatturazione → *invia per conferma*), **Abbonamento** (la sua percentuale), **Quando i giorni finiscono** (la politica di consumo extra, §9), **Limite di prenotazioni** (quante prenotazioni **aperte** il membro può tenere in tutto, in qualunque momento cadano), **Prenotazioni simultanee** (quante prenotazioni possono **sovrapporsi nel tempo** — la quota personale che prevale sul numero dello spazio, §4b; sono due limiti diversi, quindi leggi le etichette), **Può prenotare un tavolo, ufficio o piano intero**, **Badge** (§10), **Rendi admin** (validato, §7), **Comproprietà**, **Trasforma in chiosco** — o **Riporta il chiosco a membro** su un account dispositivo —, **Approva l'adesione** o **Rifiuta l'adesione** per un'iscrizione in attesa, e **Sospendi l'iscrizione**. Ogni riga mostra l'**email** del membro sotto il nome.

![](assets/help/images/member-management-sheet.jpg)

 

![](assets/help/images/member-subscription.jpg)

 

![](assets/help/images/member-reservation-limit.jpg)

### Fatturazione

- **Fasce tariffarie** — la scala di prezzi dietro gli abbonamenti percentuali: ogni fascia dice *da X %*, *fino a Y %*, il **canone** mensile e la **tariffa extra** per mezza giornata aggiuntiva. **+ Aggiungi una fascia** estende la scala.
- **Livelli di abbonamento** — quali percentuali i membri possono scegliere (chip: 25 % · 50 % · 75 % · 100 %, più i tuoi valori), e un interruttore facoltativo **valore libero negoziato**.
- **Pacchetti di giorni** — un numero di giorni a un prezzo (nome · giorni · prezzo), ognuno con il proprio interruttore di attivazione; i membri con politica a *pacchetti* li acquistano quando i loro giorni finiscono.

### Servizi e Accessori

I cataloghi dietro il §9 — extra definiti dal proprietario (armadietti, stampe…, ognuno con un prezzo e un'aliquota IVA facoltativa) e dotazioni per posto con supplementi facoltativi per mezza giornata. Entrambi sono semplici elenchi con un pulsante **+**.

![](assets/help/images/billing-bands-levels-packages.jpg)

 

![](assets/help/images/services-catalog.jpg)

 

![](assets/help/images/services-new-service.jpg)

 

![](assets/help/images/accessories-catalog.jpg)

**Scorta (#731).** Un servizio nato da una scorta mostra *N in scorta* / *Esaurito*; un consumo superiore allo scaffale viene rifiutato.

### Impostazioni dello spazio (Spazio di coworking)

La schermata propria dello spazio, dall'alto in basso:

- **Identità** — nome, paese, valuta (proposta dal paese, modificabile), fuso orario, **lingua dello spazio** (gli inviti la usano per impostazione predefinita; *lingua dell'app del mittente* è un'opzione) e l'**indirizzo** postale stampato sulle fatture.
- **Pagamenti e fatturazione** — le **istruzioni di pagamento** che i membri vedono su un estratto non saldato (IBAN, link PayPal.me, numero di telefono Wero, Lydia, Wisetag, indicazione della causale — lascia un campo vuoto per nasconderlo), e **Identità legale e fatturazione elettronica** (§11a).
- **Gruppo WhatsApp** — il link del gruppo della comunità mostrato nell'elenco.
- **Messaggio d'invito** — i modelli d'invito per lingua (§2).
- **Trasparenza dei tavoli** — il cursore che lascia trasparire una foto di sfondo sotto i tavoli disegnati.
- **Modello PDF della fattura** e **Regole di sollecito** — scorciatoie verso l'editor di report e la configurazione dei solleciti (§11).
- **Esportazioni** — *Esporta lo spazio (XML)* (impostazioni + piantina, nessun dato personale — backup, modello, migrazione di un'istanza), *Esporta la configurazione (PDF)* (un'istantanea completa: impostazioni, membri, piantina), *Report dello spazio* (tutto sullo spazio tramite il modello «spazio» del motore di report), *Codici QR degli spazi (PDF)* (un QR formato carta di credito per postazione, tavolo, ufficio e piano, dieci per A4), *Esporta i dati (Excel)* (una cartella di lavoro: prenotazioni, pagamenti, fatture, membri, piantina — una scheda ciascuno), *Importa lo spazio (XML)* (ripristina impostazioni e piantina; sostituisce la piantina attuale). Ogni esportazione finisce nella cartella **Download** del tuo dispositivo.
- **L'assistente di configurazione** (#723) — <https://fdittgen-png.github.io/deskilo/setup.html>: Dal 29/08/2026 è una **procedura guidata**: passi in ordine di dipendenza (identità → funzionalità → disponibilità → piano → abbonamenti → identità legale e IVA → servizi → pagamento → ruoli → membri → verifica), ciascuno chiede solo ciò che le risposte precedenti rendono possibile — niente aliquote IVA senza soggettività, niente piattaforma di fatturazione elettronica fuori UE, niente opzione pacchetti per i membri finché non ne esiste uno, niente funzionalità figlia senza la madre. Ogni domanda dice dove si regola nell'app e rimanda alla sezione di questa guida; un passo **Riepilogo delle funzionalità** elenca ogni funzionalità che l'app attiverà con la configurazione data dalle tue risposte — deseleziona quelle opzionali e vengono esportate disattivate, senza la loro configurazione; poi un passo di **Verifica** elenca ciò che è completo, ciò che è una scelta da confermare e ciò che blocca, con un salto per correggere; «Mostra tutto in una pagina» conserva la vista esperta. Poi: una pagina autonoma (Mac, PC o telefono; le risposte si salvano da sole nel browser) che guida un nuovo proprietario attraverso **ogni argomento, con scelte predefinite** — identità (paese compresa la Norvegia, valuta, fuso, lingua dello spazio, trasparenza dei tavoli e i modelli di invito per lingua), disponibilità — granularità, orario di lavoro, giorni di chiusura e **le quattro regole di prenotazione** (prenotazioni passate, check-out da parte di un admin, modalità fuori orario, prenotazioni simultanee), più la conversione ore → mezze giornate con la granularità «orari reali» —, la piantina, **tutte le 43 funzionalità** ai loro valori predefiniti reali, fasce di quota e livelli di abbonamento, pacchetti di giorni, servizi e accessori, istruzioni di pagamento, **identità legale e IVA** (tipo di organizzazione, regime, le aliquote abituali del paese — il 3,8 % svizzero per l'alloggio, la Norvegia, le province canadesi, con la nota onesta sulla sales tax statunitense —, diciture di fattura, regole di sollecito, la periodicità della dichiarazione e gli endpoint di fatturazione elettronica compreso il servizio di consegna al cliente), la matrice ruolo → permesso, la regola di validazione predefinita **con una scheda per dominio e i due interruttori di validazione automatica**, e i membri da invitare con le loro impostazioni personali (politica di sforamento, diritto sugli spazi interi, permesso di sovrapposizione, limite di prenotazioni). **Esporta l'XML** e l'app importa direttamente impostazioni, accessori e piantina (*Importa lo spazio (XML)*); la sezione `<setup>` del file porta tutto il resto per completare la configurazione. La pagina può anche **ricaricare** un file esportato in precedenza per continuare — compreso uno scritto prima che un'impostazione esistesse, che torna semplicemente con quella impostazione al suo valore predefinito. Un avvertimento che la pagina ripete: il file esportato è in chiaro, quindi inserisci un token di piattaforma solo se rispondi in privato; altrimenti lascia vuoti quei campi e digitali nell'app, dove partono lato server e non tornano mai indietro.
- **Zona pericolosa** — **Reimposta lo spazio**: elimina tutte le prenotazioni, la contabilità e la piantina; conserva impostazioni e membri. Protetto da una conferma digitata.

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

Una matrice centrale decide **quale ruolo detiene quale permesso** — gestire i ruoli, gestire i membri, regole di convalida, impostazioni dello spazio, emettere fatture e riconciliare pagamenti, consultare le finanze, documenti, servizi, approvare le spese. Aprila in *Impostazioni → Amministrazione → Gestione dei ruoli* (il suo interruttore di funzionalità deve essere attivo):

- Il **proprietario detiene sempre tutti i permessi** — la riga è bloccata.
- Chi detiene *Gestire ruoli e permessi* modifica le altre righe. Un **comproprietario** parte con tutto («un comproprietario può averne meno» — il proprietario toglie ciò che vuole); un **admin** parte con le capacità admin di oggi; un **membro** con nessuna.
- Chiunque altro con un permesso qualsiasi vede la matrice **in sola lettura**, con il proprio ruolo evidenziato.
- Una matrice mai toccata significa i valori predefiniti — nulla cambia finché il proprietario non la modifica. Il vecchio interruttore *gli admin emettono fatture* continua a concedere la fatturazione agli admin per compatibilità. Il server applica la stessa matrice nelle RPC di fatturazione (`has_permission`), così l'interfaccia e il database non possono mai essere in disaccordo.

**Chi convalida (#732).** Una regola indica il suo **ambito**: *Gli admin* (il proprietario e tutti gli admin, o quelli elencati), *Persone designate* (il proprietario ed esattamente le persone scelte — anche un semplice membro può convalidare), o *Tutti i membri*. Numero e firma del proprietario mantengono il loro senso, e nessuno convalida mai il proprio evento. Funzionalità *Convalidatori per ruolo o persona*.

### Configurare i pagamenti online

Ogni comunità incassa sul **proprio** account del fornitore; l'app non conserva mai le chiavi segrete su alcun dispositivo — restano sul server.

1. Apri **Impostazioni → Pagamenti online** (solo proprietario).
2. Scegli un fornitore e incolla le sue chiavi dal suo pannello:
   - **PayPal** — Client ID, Secret, Ambiente (inizia con *sandbox*), ID webhook, URL di ritorno (PayPal Developer → la tua app REST).
   - **Carta di credito (Stripe)** — Chiave segreta, Segreto di firma webhook, URL di ritorno (Stripe → chiavi API / Webhook).
   - **Mollie** — Chiave API, URL di ritorno (offre iDEAL, Bancontact, carte…).
   - **Wero (tramite Mollie)** — la stessa chiave API Mollie, con Wero abilitato nel tuo account Mollie.
3. **Salva** — appare un chip verde *Configurato*. Attiva la funzionalità **Pagamenti online** (Impostazioni → Funzionalità) e i membri vedranno **Paga online** su una fattura da saldare. (La voce di impostazioni *Pagamenti online* appare solo finché la funzionalità è attiva.)

![](assets/help/images/payment-config-paypal-stripe.jpg)

 

![](assets/help/images/payment-config-mollie-wero.jpg)

Un segreto salvato non viene più mostrato — lascia il campo vuoto per mantenerlo, digita per sostituirlo, **Rimuovi** per togliere il fornitore. Le commissioni sono del fornitore (tipicamente ~1,5–3 % per pagamento, senza canone mensile); DesKilo non aggiunge nulla, e il bonifico/IBAN manuale resta gratuito.

Se un pagamento non parte, attiva **Impostazioni → Avanzate → Modalità sviluppatore** e apri la schermata **Sviluppatore**: la traccia *pagamenti* mostra esattamente quali fornitori sono configurati e quali campi mancano ancora.

![](assets/help/images/developer-payment-traces.jpg)

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

### Configurare i badge RFID / NFC

Le tessere fisiche permettono il check-in con un tocco — senza telefono.

1. Apri **Impostazioni → Badge RFID / NFC** (solo proprietario). Attiva **Abilita il check-in con badge NFC** e leggi la riga di **stato del dispositivo** — distingue *pronto*, *NFC disattivato nelle impostazioni Android* e *nessun hardware NFC*. I telefoni e i tablet Android dotati di NFC, e gli **iPhone**, sanno leggere un tag; gli iPad non hanno alcun hardware NFC.
2. Dai una tessera a ogni membro: **Membri e piani → il membro → Badge → Registra tessera**, poi avvicina la sua tessera al dispositivo. Va bene qualsiasi tessera con chip leggibile (MIFARE, NTAG…). I membri possono farlo anche **da soli**: **Impostazioni → Il mio badge** emette il loro badge QR stampabile e registra la loro tessera — senza bisogno di un admin.
3. Usale a un **chiosco** (§10): il membro avvicina la tessera per prenotare o fare check-in. Revoca una tessera persa dalla stessa finestra Badge; **scorri un badge revocato verso destra per eliminarlo** definitivamente (dopo conferma).

I badge appartengono a **un solo spazio** — la finestra indica in quale stai registrando, quindi registra la tessera nello spazio il cui chiosco la leggerà. La stessa tessera fisica può servirti in più spazi. Un badge QR salvato **come PDF** stampa dieci copie formato carta di credito su una pagina A4 — scorte incluse.

![](assets/help/images/nfc-config.jpg)

 

![](assets/help/images/member-badges-dialog.jpg)

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

**Le azioni, raggruppate per significato:**

- **Pagare** — **Registra un pagamento** («ho pagato») con il metodo, la **data in cui il denaro si è mosso** (oggi per impostazione predefinita) e il **mese che salda** (quello in corso per impostazione predefinita, un passo indietro per gli arretrati, uno avanti per un anticipo) — l'altra parte conferma. Quel mese decide su quale estratto e su quale fattura finisce l'accredito. **Paga online** (quando attivo) salda subito l'importo dovuto — con **PayPal, carta di credito (Stripe), Mollie o Wero**, secondo ciò che lo spazio ha attivato (se più di uno, appare un selettore).
- **Richieste** — **Invia una spesa** (hai comprato il caffè per lo spazio? un altro admin la approva — niente auto-approvazione — e viene accreditata sul tuo estratto), **Richiedi mezze giornate extra**, **Aggiungi un consumo** (servizi definiti dal proprietario — armadietti, stampe… — confermi ciò che hai consumato).
- **Documenti** — **Fatture** (le tue restano sempre leggibili qui: posizioni, saldo, stato — e per chi emette, l'hub di fatturazione, §11), **Le mie condizioni** (che stampa il documento intitolato *Accordo finanziario*) e il **report mensile dei pagamenti**, self-service (§11).

### 9a. Una volta fatturato il mese, decide la fattura

- Il tuo estratto mostra una **scheda fattura** — numero, stato, totale, già pagato, residuo — e il mese risulta **saldato** non appena la fattura è pagata, il suo saldo annullato o la sua nota di credito rimborsata, anche se il pagamento che la salda è stato registrato un mese dopo. Una fattura **parzialmente pagata** lascia il mese aperto esattamente per l'**importo residuo** (è anche quanto addebita *Paga online*). Un mese con **nota di credito** mostra ciò che lo spazio ti deve — nulla da pagare da parte tua.
- **Il tuo conto** — quando possiedi credito disponibile (un avoir, o pagamenti in eccesso di un mese passato), la scheda Finanze mostra la tua posizione reale tra i mesi, sopra l'estratto: **credito disponibile**, ogni **fattura aperta** con il residuo, i rimborsi che lo spazio ti deve e la **posizione netta** risultante. Il tuo credito può saldare le fatture aperte — lo spazio lo applica durante la riconciliazione dei pagamenti (imputazione). I mesi precedenti alla tua adesione non devono nulla e non risultano mai aperti.

### 9b. Anteprima rapida, scarica, condividi — ogni report

Ogni report dell'app — l'estratto, le fatture, le proforma, le note di credito, i tuoi documenti self-service — offre le stesse tre azioni: **Anteprima rapida** (vedere il documento renderizzato sullo schermo prima che esista un PDF), **Scarica PDF** (salvare localmente) e **Condividi PDF** (consegnarlo a qualsiasi app — WhatsApp, mail, …).

**I report parlano la lingua di chi legge:** un documento viene stampato nella lingua del **membro** quando per essa esiste un modello, altrimenti nella **lingua dello spazio**, e in mancanza di entrambe nella **lingua del paese dello spazio** (§11 modelli per lingua). Dove quel paese non ha una lingua unica, l'app non tira a indovinare: rifiuta e ti chiede di *impostare prima la lingua dello spazio*.

### 9c. La vista Estratto

**Il mese così com'è.** Il tuo conto (la posizione reale su più mesi), la scheda **Questo mese** (giorni inclusi, usati, rimasti), la scheda **abbonamento**, **servizi consumati**, **supplementi di accessori e spazi**, **pacchetti di giorni**, **posizioni aperte** in attesa di convalida, **pagamenti e crediti**, la **scheda fattura** del mese appena è fatturato (§9a) e il **saldo**. Sola lettura: nulla da premere tranne il selettore **‹ mese ›**, comune a tutte le viste.

### 9d. La vista Pagamenti

**Regolare e chiedere.** Una **striscia di scaduto** quando una fattura supera il termine di pagamento dello spazio (§11e), il **saldo**, le **istruzioni di pagamento** e **Paga online** finché qualcosa è dovuto, poi le azioni: **Registra un pagamento**, **Compra un pacchetto** (piani a pacchetti), **Invia una spesa**, **Chiedi mezze giornate extra**, **Aggiungi un consumo**.

**Scorte (#731).** Hai comprato capsule di caffè o sacchetti per aspirapolvere per lo spazio? In **Invia una spesa**, attiva *È una scorta per lo spazio*, indica l'articolo (o scegline uno esistente), la quantità e quanto costerà un consumo (precompilato con importo ÷ quantità). Convalidata la spesa, vieni rimborsato come sempre **e** l'articolo va sullo scaffale come servizio consumabile con quella scorta; chi lo usa aggiunge un consumo e lo paga, la scorta scende, e a zero l'articolo non si può consumare fino alla prossima scorta. Funzionalità *Scorte dalle spese* (richiede Servizi).

### 9e. La vista Fatture

**Cosa mi è stato fatturato?** Una scheda di testa — *niente di aperto, sei in regola*, o *N aperte · importo dovuto*, con il numero delle scadute — poi **ogni fattura emessa a tuo nome**, dalla più recente, ciascuna con il suo chip di stato, **scade tra N giorni** o **scaduta da N giorni**, quante volte è stata sollecitata, e un pulsante **paga** che salta alla vista Pagamenti; tocca una riga per la scheda di dettaglio con anteprima, PDF e condivisione. Chi emette trova il pulsante **Fatture** verso il registro (§11).

### 9f. La vista Documenti

**Il resto delle carte:** **Le mie condizioni** (il tuo accordo finanziario), il **report mensile dei pagamenti**, **l'estratto del mese in PDF** e la **libreria dei documenti** quando lo spazio ne usa una (§11d). Disattiva le viste in Funzionalità → *Finanze in tre viste* per tornare alla colonna unica.

### 9g. Negoziazioni di prezzo

**La tariffa è il valore predefinito; le tue condizioni sono tue.** Un proprietario o un admin finanze può proporre una **negoziazione di prezzo** per un membro — quota mensile, eccedenza per mezza giornata, sconto sui supplementi (accessori, prenotazioni di spazi interi) — ciascuno opzionale, la tariffa se assente. La proposta arriva in Eventi ai convalidatori della regola (dominio *Negoziazione di prezzo*, o la regola predefinita); confermata, si applica dal mese scelto e sostituisce le condizioni precedenti. Nella tua vista **Estratto**, la scheda *I miei prezzi negoziati* mostra la tariffa barrata accanto ai tuoi prezzi, da quando, e **Chi può vederlo**: tu, i proprietari e gli admin finanze — ogni lettura da parte di altri è registrata ed elencata lì (§14). Funzionalità *Negoziazioni di prezzo*.

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

Una fattura in DesKilo viene generata, mai composta: le sue posizioni sono **derivate esclusivamente dai dati tracciati del mese** — abbonamento, eccedenza, supplementi, servizi, pacchetti — meno i pagamenti e gli accrediti del mese, così la riga finale **è il saldo dovuto**. Ogni documento fotografa gli indirizzi postali dello spazio e del membro (imposta il tuo in **Impostazioni → Indirizzo**; l'indirizzo dello spazio sta nelle impostazioni dello spazio) ed è **firmato digitalmente** all'emissione — dopo non cambia più. Un **allegato dettagliato** (il libro mastro e le presenze del mese) si aggiunge con un interruttore al momento dell'emissione.

Chi emette apre **Finanze → Fatture** e trova un hub a tre schede sotto una striscia di riepilogo in tempo reale (*N da fatturare · N aperte · X in sospeso · N da rimborsare · Y*):

- **Da fatturare** — ogni membro il cui mese precedente ha dati fatturabili e nessuna fattura, con il totale del mese: emetti per membro (con l'anteprima delle posizioni derivate) o **Fattura tutto** in un colpo solo — che prima chiede conferma, indicando il numero, il mese e il totale. Il pulsante **Nuova fattura** apre la stessa scheda per qualsiasi membro e mese — selettore del membro, ‹ mese ›, le posizioni derivate, il saldo, l'interruttore dell'**allegato dettagliato** ed **Emetti fattura** (uno snack verde *Fattura emessa.* conferma). **Una sola fattura attiva per membro e mese** — un mese torna fatturabile solo dopo che la sua fattura è stata annullata. Il foglio di emissione si apre sul **mese chiuso** (il momento in cui i suoi numeri smettono di muoversi); se scegli il mese in corso ti avvisa, perché quel mese si può fatturare una sola volta.
- **Aperte** — fatture emesse in attesa di saldo, dalle più vecchie; ciò che attende da oltre 30 giorni diventa rosso, sulla scheda e nella striscia di riepilogo. Ogni azione è un'icona con suggerimento (annulla · proforma · sollecito · segna come pagata). **Tocca una scheda per leggere la fattura.** **Invia un promemoria** registra il sollecito e condivide il PDF con un messaggio — la scheda mostra *Sollecitato ×N*. **Segna come errata** annulla la fattura per correggerla (una finestra esplicita avvisa che l'operazione è irreversibile): passa nell'archivio barrata, e una **sostitutiva** ri-deriva lo stesso mese dai dati corretti, citando l'originale. **Segna come pagata** abbina un pagamento reale (sotto). **Un pagamento parziale non chiude una fattura**: resta tra le Aperte, con badge *Parzialmente pagata* e l'importo residuo, finché il saldo non pagato non viene annullato esplicitamente **tramite il framework di convalida** — un admin/proprietario richiede l'annullamento (con un motivo), i validatori confermano e solo allora la fattura passa in archivio come *Parzialmente pagata · saldo annullato*. **Una fattura NEGATIVA è una nota di credito (avoir)** — i crediti del mese superano i suoi addebiti, quindi lo SPAZIO deve denaro al membro: il suo PDF si intitola *Nota di credito*, non riceve solleciti né riconciliazione con pagamenti del membro; la scheda mostra invece *Da rimborsare* con **Registra il rimborso** — il versamento si imputa al saldo del membro (convalidato come ogni liquidazione quando vale una regola; un rifiuto la riapre) e il documento si chiude come *Rimborsata*. La striscia di riepilogo separa le due direzioni del processo di pagamento: *N aperte · X in sospeso* conta le fatture positive al loro valore **residuo** (una fattura da 500 € con 280 € pagati conta 220 €), mentre *N da rimborsare · Y* somma le note di credito aperte che lo spazio deve ancora.
- **Archivio** — fatture chiuse, filtrabili per membro e mese e ordinabili; le fatture annullate sono **nascoste per impostazione predefinita** — il chip *Mostra annullate* riporta la catena di correzione; la barra sotto i filtri dice quante fatture corrispondono e **Azzera i filtri** riporta l'archivio intero. Ogni riga porta il suo chip di stato (*Pagata*, *Parzialmente pagata*, *Errata* barrata, le note di credito con il loro importo negativo), il suo mese e il suo importo, con **Scarica PDF** lì accanto. **Tocca una riga per aprire la fattura** — posizioni, saldo, destinatario, dove si trova (*Pagata 300,00 € il 6 ago*, *Sollecitato ×1 · ultimo sollecito…*, *Allegato: 5 movimenti, 10 check-in*), quale fattura sostituisce o da quale è stata sostituita, la sua firma — e ogni azione ancora permessa, per nome: **Anteprima rapida**, **Scarica PDF**, **Condividi PDF**, esporta la **fattura elettronica (XML)**, sollecita, segna come pagata, segna come errata, emetti una sostitutiva.

**Segnare come pagata significa abbinare un pagamento reale — o applicare un credito.** La finestra elenca i pagamenti registrati del membro — bonifici registrati e pagamenti online confermati — e tu abbini la fattura a uno di essi; non c'è alcun importo da digitare (nessun pagamento registrato? la finestra lo dice: *registralo o confermalo prima*). Elenca anche i **crediti sul conto** del membro (eccedenze da nota di credito): abbinarne uno imputa l'avoir sulla fattura, mesi passati compresi — l'alternativa standard al rimborso in contanti, per associazioni e imprese allo stesso modo. Ogni credito si spende esattamente una volta: uno già dedotto dentro una fattura emessa non può mai saldare un secondo documento. Ha pagato **di più**? Crea una **nota di credito** per l'eccedenza (un accredito sul libro mastro del membro) oppure forza l'accettazione con una nota obbligatoria. Ha pagato **di meno**? Accettalo con una nota obbligatoria. Tutti coloro che hanno accesso alla fatturazione vengono avvisati delle fatture pagate, e il proprietario può mettere una regola di validazione **Pagamento fattura** (§7): l'abbinamento resta allora in attesa del quorum — un rifiuto riapre la fattura.

**Una fattura pagata è definitiva.** Una volta abbinata non può più essere annullata, sostituita o modificata — le correzioni avvengono prima del pagamento, annullando la fattura aperta ed emettendo la sua sostitutiva. Un pagamento che **non** ha coperto l'intero importo, accettato con una nota, compare come **parzialmente pagata**, non come pagata.

**Proforma.** Due delle tre schede dell'hub offrono un'azione proforma: su **Da fatturare** rende le posizioni derivate del mese come preventivo — senza numero, senza firma, timbrata PROFORMA, e **non emette nulla**; su **Aperte** rigenera la fattura emessa come richiesta di pagamento che non può passare per l'originale. Entrambe offrono la triade anteprima rapida / scarica / condividi.

**Timbri.** Una fattura annullata porta un grande **ERRATA** in diagonale su ogni pagina del suo PDF, in grigio chiaro sopra il contenuto: non si confonde con un documento valido su una scrivania né in fotocopia. Lo stesso timbro dice **PROFORMA** su un preventivo e **COPIA** su ogni fattura generata da qualcuno che non sia chi l'ha emessa — l'originale resta allo spazio.

**Solleciti (Mahnwesen).** Il proprietario imposta le **regole di sollecito** (icona elenco puntato nell'intestazione Fatture, o *Impostazioni dello spazio → Regole di sollecito*): quanti livelli, giorni fino al primo promemoria, giorni tra i livelli. Le fatture aperte scadute sono contrassegnate **«Sollecito N da inviare»** e la campanella sulla scheda diventa rossa — nulla parte mai automaticamente. L'invio genera una **lettera di promemoria di pagamento** (livello 1 amichevole, livelli superiori più fermi) dal modello di quel livello — fornito pronto nella tua lingua, stampato nella lingua del *membro* e modificabile per livello nell'editor di report con i campi extra `{{ reminder_level }}`, `{{ reminder_date }}` e `{{ days_open }}`.

**Il registro.** L'icona elenco nella barra delle Fatture apre un giornale con una riga per fattura: **data · nome · importo · stato**, ordinato per data (tocca l'intestazione Data per invertire la direzione), con il totale in fondo e un selettore dell'**anno** quando ce n'è più di uno. Il suo pulsante di esportazione apre il foglio **Esportazione contabile**: **SAF-T (XML, internazionale)** e — per uno spazio francese — **FEC (Francia, richiesto in caso di verifica)**.

**Consegnare il periodo al commercialista.** Dal registro, chi emette esporta il **SAF-T** — lo *Standard Audit File for Tax* dell'OCSE, l'XML che leggono i software contabili e le amministrazioni fiscali. Copre esattamente ciò che mostra il registro, quindi scegliere 2026 dà il file del 2026: l'impresa così come la dichiarano le tue stesse fatture, ogni cliente, ogni fattura con righe e totali, e i pagamenti che le hanno saldate. Le fatture annullate restano nel file, marcate *annullate* — un file di audit non cancella mai ciò che è avvenuto. Ciò che lascia fuori di proposito è il **piano dei conti**: DesKilo non inventa numeri di conto, perché un codice sbagliato va stornato a mano. Il commercialista associa le fatture ai propri conti — è il suo lavoro e gli costa un minuto.

**Francia: il FEC.** Uno spazio francese ha una seconda scelta, il **FEC** (*Fichier des Écritures Comptables*) — il file che una verifica fiscale richiede per legge (art. L47 A-I du LPF). Non è XML: un file piatto separato da tabulazioni fatto di **scritture** contabili, denominato `<SIREN>FEC<YYYYMMDD>.txt` come impone l'arrêté, con le 18 colonne obbligatorie nell'ordine obbligatorio. Essendo fatto di scritture *non può* fare a meno dei numeri di conto, quindi l'esportazione li chiede prima — precompilati con il *plan comptable général* (411 clienti, 706 prestazioni, 512 banca) e correggibili. Ogni fattura iscrive il suo credito a fronte del ricavo per l'importo **lordo**; i crediti che ha compensato e il pagamento che l'ha saldata passano in banca con le proprie date, lettrati con il numero di fattura. Le fatture annullate non ci sono: una annullata prima del pagamento non è mai stata contabilizzata, quindi non c'è nulla da stornare. La colonna del *nome* segue chi legge — chi emette scorre i nomi dei membri, un membro scorre i propri numeri di fattura. I membri vedono solo ciò che li riguarda: le fatture emesse, e mai una annullata.

### 11a. Identità legale, IVA e menzioni

**Prima della prima esportazione, compila l'identità legale.** In *Impostazioni dello spazio → **Identità legale e fatturazione elettronica*** il proprietario dichiara:

- Il **regime IVA** — decide il numero che la norma EN 16931 richiede: fuori dal campo di applicazione dell'IVA, un **numero di registrazione** dell'impresa (SIREN, HRB, CIF…); esente IVA in un regime forfettario, una **partita IVA** più il **motivo del mancato addebito dell'IVA** (il campo suggerisce la dicitura corretta — *TVA non applicable, art. 293 B du CGI*, o per i servizi ai membri di un'associazione *Exonération de TVA, art. 261, 7-1° du CGI*). Il regime è applicato end-to-end: solo uno spazio soggetto IVA applica mai un'aliquota a un abbonamento, un supplemento, un servizio o un pacchetto, e i selettori IVA semplicemente scompaiono sotto qualsiasi altro regime.
- L'**indirizzo** strutturato (via, codice postale, città) accanto all'indirizzo libero dell'intestazione.
- La **piattaforma di fatturazione elettronica** (§11b).
- Le **menzioni di fatturazione**, con un selettore **Tipo di organizzazione** — *Impresa* vs *Associazione (loi 1901)*: forma giuridica e capitale (es. *Association loi 1901*), registro delle imprese (imprese: RCS; associazioni: **RNA W… · SIRET se assegnato**), termini di pagamento, penale di mora, l'**indennità di recupero di 40 €**, sconto per pagamento anticipato (escompte), assicurazione professionale, menzioni particolari. Ogni clausola lasciata vuota stampa la dicitura legale predefinita — e i documenti di un'associazione omettono le clausole predefinite solo-B2B (penale di mora, indennità di recupero ed escompte sono obbligatorie solo tra professionisti; ciò che scrivi viene comunque stampato).

I membri aggiungono il proprio **paese** — e la partita IVA se fatturano come impresa — accanto all'indirizzo in *Impostazioni → Indirizzo*. DesKilo verifica tutto questo **prima** di produrre una fattura elettronica e rifiuta indicando l'elemento mancante, perché una fattura che una piattaforma rigetta è peggio di nessuna fattura.

**In DesKilo i prezzi sono IVA inclusa.** Ciò che scrivi come prezzo di abbonamento, di servizio o di pacchetto di giorni è ciò che il membro paga. Attivare l'IVA non cambia un solo importo dovuto da nessuno — dice quanta parte di quell'importo è imposta. Per questo un estratto, un conto e una quota non si muovono mai quando aggiungi le aliquote, e per questo nessun totale va mai riconciliato. Sotto un regime soggetto a IVA il catalogo lo dice ad alta voce: ogni riga di servizio e di pacchetto nomina la sua aliquota inclusa (*IVA 22 % incl.*), l'editor di fatturazione consente al proprietario di scegliere l'aliquota IVA delle tariffe (predefinita: quella dello spazio) e mostra la quota IVA di ogni importo mentre digiti, ogni accessorio può portare la propria aliquota (predefinita: quella dello spazio), e ogni campo prezzo ricorda che è lordo.

**Configurare le aliquote.** *Identità legale e fatturazione elettronica → **Aliquote IVA***. Un elenco vuoto significa IVA disattivata: è così che ogni spazio comincia. **Usa le aliquote consuete** riempie l'elenco con l'aliquota ordinaria, intermedia e ridotta del tuo paese come prima bozza — un punto di partenza, non una consulenza fiscale. Un'aliquota è quella **predefinita** (la stella): abbonamenti, eccedenze, supplementi e rettifiche la usano, come ogni servizio che non ne ha una propria. Un servizio e un pacchetto di giorni portano ciascuno la propria aliquota, scelta nel loro editor. Rimuovere un'aliquota non la cancella mai — una a cui una fattura o un servizio fa ancora riferimento viene conservata, disattivata, così nulla viene tassato di nuovo in silenzio. Tutto questo è la funzionalità *Gestione IVA*: disattivata, l'editor delle aliquote e tutti i selettori scompaiono mentre le aliquote salvate continuano ad applicarsi — l'aritmetica fiscale non è mai disattivabile — e l'interruttore *Dichiarazioni IVA* vive sotto di essa.

**La dichiarazione IVA periodica** (*Aliquote IVA → Dichiarazione IVA*, solo spazi soggetti a IVA). Scegli il periodo — mese o trimestre, secondo il tuo regime — e **Genera**: l'app aggrega le fatture emesse del periodo per aliquota **con l'esatta aritmetica delle fatture**, la dichiarazione quadra quindi con ogni documento al centesimo. Il risultato mostra imponibile e IVA per aliquota, mappati sulle **righe del modulo ufficiale** (CA3 08/09/9B/11 in Francia, UStVA Kz 81/86 in Germania, elenco generico altrove). Ogni dichiarazione si esporta in **PDF** e **XML leggibile dalla macchina**; se sotto la fatturazione elettronica è configurata una piattaforma di invio, **Trasmetti** la invia elettronicamente e registra la ricevuta — altrimenti porta i numeri sul portale dell'agenzia o dal commercialista e **Segna come inviata**. In entrambi i casi la dichiarazione diventa immutabile, con canale e ricevuta registrati. Il catalogo di aliquote suggerite copre tutti gli Stati membri UE, la Svizzera (incluso il 3,8 % alloggio), la Norvegia e le province canadesi; gli USA non hanno IVA federale — l'app lo dice invece di indovinare. Un aiuto alla dichiarazione, non consulenza fiscale.

**Cosa cambia su un documento.** Una fattura emessa dopo la creazione delle aliquote porta la ripartizione così come emessa: la tabella delle posizioni guadagna una colonna di aliquota, e sopra il totale il PDF mostra l'**imponibile** e una riga per aliquota. La **fattura elettronica (XML)** porta ciò che EN 16931 richiede, sia in UBL sia in CII; il **SAF-T** dichiara ogni aliquota nella sua tabella imposte; il **FEC** registra il credito al lordo contro il ricavo netto più un conto di **IVA incassata** (445710 per impostazione predefinita, modificabile).

**Una fattura già emessa non cambia mai.** Porta le aliquote, l'identità e gli importi con cui è stata firmata — è questo che la rende una fattura. Se un documento deve portare nuovi dati, segnalo come **errato** ed emetti una **sostitutiva**: la catena di correzione è visibile su entrambi i documenti, che è esattamente ciò che una verifica vuole vedere.

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

### 11c. L'editor di report — ogni documento, quattro modelli, cinque lingue

Il **Modello PDF della fattura** (icona matita nell'intestazione Fatture, o *Impostazioni dello spazio*) è uno strumento di reporting a bande per ogni documento che l'app stampa. Tre **bande** di report vengono rese sul PDF — intestazione, corpo (le righe della fattura), piè di pagina — mentre l'XML della fattura elettronica non viene mai toccato.

- **Un report per documento**: i chip passano tra **Fattura · Proforma · Estratto · Accordo · Pagamenti · Spazio · Livelli di sollecito**. La proforma ripiega sulle bande della fattura finché non la personalizzi; un estratto personalizzato sostituisce il PDF mensile integrato.
- **Per lingua**: una seconda fila di chip — *Predefinito (tutte le lingue)* · EN · FR · DE · ES · IT — memorizza una traduzione per documento; il report di un membro viene stampato nella *sua* lingua quando esiste un modello per essa, altrimenti nella lingua predefinita dello spazio.
- **Markup o Visuale**: la modalità **Markup** modifica le bande come testo — condizioni e cicli [Liquid](https://shopify.github.io/liquid/) (`{{ number }}`, `{% if proforma %}…{% endif %}`, `{% for line in lines %}…{% endfor %}`) più un markup di riga semplice: `#` titolo, `##` sezione, `>` testo piccolo, `---` divisore, `a | b` riga di tabella, `=` riga in grassetto, `::: … ||| … :::` colonne affiancate (il blocco indirizzi venditore-a-sinistra / cliente-a-destra e i totali allineati a destra di una facture francese — i modelli forniti seguono esattamente questa struttura), `![name]` un'immagine dalla **libreria immagini** dello spazio (*Inserisci immagine*). La modalità **Visuale** è una superficie di progettazione fedele alla pagina, nella tradizione degli strumenti professionali (Crystal Reports, Docentric): le tre bande si modificano **su una pagina A4 bianca** ai margini del documento, nella sua esatta tipografia di stampa — stesso font, dimensioni, colori e colonne degli importi allineate a destra del PDF generato — con strisce di banda etichettate, guide tratteggiate di cambio pagina e zoom (adatta, 75/100/150 %). I `{{ token }}` restano evidenziati; tocca una riga per modificarla sul posto, aggiungi, sposta, inserisci campi dalla tavolozza. Un interruttore **Progetto ↔ Anteprima** fonde le bande non salvate con i tuoi dati reali (o di esempio) attraverso il vero motore, sulla stessa pagina — via i campi, dentro i valori.
- **Galleria di modelli** (*Modelli*): quattro modelli pronti per ogni documento — **Classico · Semplice · Dettagliato · Lettera formale** — scegline uno ed estendilo. Ogni modello di fattura porta già le menzioni obbligatorie (§11a).
- L'**anteprima rapida** rende il risultato all'istante nell'app — la tua fattura più recente, o dati di esempio simulati quando non ce n'è (filigranati *dati di esempio*) — senza passare da un PDF; **Anteprima** produce il PDF; **Ripristina** riconsegna il layout integrato come esempio funzionante. Un modello rotto non blocca mai un documento — subentra il layout integrato; la filigrana di annullo, la firma digitale, l'allegato e i numeri di pagina restano fissi.

Variabili di modello (famiglia fatture): `{{ number }}`, `{{ member }}`, `{{ workspace }}`, `{{ workspace_address }}`, `{{ period }}`, `{{ issued }}`, `{{ issued_by }}`, `{{ replaces }}`, `{{ total }}`, `{{ charges }}`, `{{ payments }}`, `{{ voided }}`, `{{ proforma }}`, `{{ copy }}`, `{{ lines }}` (ognuna con `label`, `unit_price`, `qty`, `net`, `vat_rate`, `amount`), `{{ has_vat }}`, `{{ vat }}`, `{{ net_total }}`, `{{ vat_total }}`, `{{ credit_note }}`, `{{ refund_total }}` — e l'insieme legale: `{{ seller_legal_form }}`, `{{ seller_registration }}`, `{{ seller_vat_id }}`, `{{ seller_legal_id }}`, `{{ exemption_reason }}`, `{{ client_address }}`, `{{ client_vat_id }}`, `{{ client_legal_id }}`, `{{ payment_terms }}`, `{{ late_penalty }}`, `{{ recovery_indemnity }}`, `{{ escompte }}`, `{{ insurance }}`, `{{ special_mentions }}`.

### 11d. La suite di report e la biblioteca documenti

- **Accordo finanziario** — ogni prezzo in vigore che si applica a un membro: abbonamento, mezza giornata extra, servizi, pacchetti, supplementi accessori e i prezzi degli spazi interi, **tavoli compresi**. Proprietari/admin lo inviano dalla scheda azioni di un membro; ogni membro può vedere in anteprima/scaricare/condividere il proprio da *Finanze → Documenti*.
- **Report dei pagamenti** — tutto ciò che hai pagato, dichiarato o fatto convalidare in un mese: il tuo piccolo bilancio, self-service sulla stessa riga.
- **Report dello spazio** — identità, conteggi della piantina, disponibilità, funzionalità e prezzi: *Impostazioni dello spazio → Report dello spazio*.
- **Biblioteca documenti** — *Impostazioni → Documenti*: lo statuto dello spazio, le guide, i bilanci e i verbali, COLLEGATI dal sistema che già usi — Google Drive, OneDrive, SharePoint, Dropbox, Nextcloud o qualsiasi link https (il drive continua a gestire i propri permessi; l'app non conserva mai credenziali altrui). Ogni voce ha un **ruolo di visibilità**: tutti i membri, admin e proprietari, o solo proprietari — applicato lato server, così un membro non scarica nemmeno un elenco che contiene documenti del consiglio. Admin e proprietari curano con il pulsante +; l'interruttore della funzionalità *Biblioteca documenti* attiva il tutto.

### 11e. Solleciti di pagamento automatici

Con **Solleciti di pagamento automatici** attivo (Funzionalità, figlio di *Solleciti di pagamento*) e l'interruttore **Solleciti automatici** nelle regole di sollecito (Fatture → Regole di sollecito), i livelli si applicano da soli: ogni mattina — e ogni volta che un proprietario o un admin apre Finanze — una fattura **aperta** il cui termine è trascorso (i *giorni prima del primo sollecito* dall'emissione, poi i *giorni tra i solleciti* dopo il precedente) riceve il livello successivo. Il membro vede un avviso **Promemoria di pagamento** in Eventi («Sollecito 2: fattura X — importo ancora dovuto») e riceve una notifica; la sua vista Fatture legge *scaduta da N giorni*. I livelli non superano mai il numero configurato; una fattura riconciliata non è mai sollecitata; con l'interruttore spento, sollecitare resta manuale, una fattura alla volta come prima.

## 12. Impostazioni e profilo

La tua schermata personale, dall'alto in basso:

**Privacy e dati (#719)** — chi può vedere i tuoi dati, chi l'ha fatto, esportazione, cancellazione, la politica. Vedi §14.

**Regione e formati (#711).** Come *tu* leggi ciò che lo spazio mostra: **numeri e date** nella regione che scegli (`it_CH`, `en_GB`, `de_AT`… indipendente dalla lingua dell'app), l'**orologio** (24 h, 12 h o ciò che fa quella regione) e se gli orari appaiono nel **fuso dello spazio** — quello delle prenotazioni, il predefinito — o **nel tuo**, segnalato dove i due differiscono. Una riga di anteprima mostra la somma delle tre scelte. La valuta resta quella dello spazio; solo la sua scrittura è tua. Salvato sul tuo profilo: ti segue da un dispositivo all'altro.

- **Profili** (§1) e la tua **foto** (tocca per cambiare — scegli o rimuovi).
- **Membri** — una scorciatoia verso l'elenco; **WhatsApp** — il tuo numero, visibile agli altri membri solo se lo imposti; **Stato** — una riga libera (40 caratteri) mostrata nell'elenco; **Indirizzo** — il tuo indirizzo postale (stampato sulle tue fatture), il paese e la partita IVA facoltativa.
- **Aiuto** — la guida integrata, nella tua lingua; **Il mio badge** (§8); **Account collegati** — collega un accesso Google al tuo account email; **Documenti** — la biblioteca documenti dello spazio (§11d).
- **Preferenze** — **Lingua** (predefinita di sistema o una delle cinque), **Tema** (sistema / chiaro / scuro), **Periodo di prenotazione predefinito** (la finestra su cui si aprono le schede di prenotazione, così la tua solita mezza giornata o il tuo solito da–a è già compilato), **Scansiona con la fotocamera frontale** (per i tablet a parete) e **Mostra di nuovo i suggerimenti di aiuto**, che riporta indietro ogni suggerimento contestuale che avevi chiuso. Quei suggerimenti sono piccoli caroselli sui moduli stessi: scorri avanti e indietro tra più suggerimenti per schermata, ognuno con un collegamento *Scopri di più* che salta direttamente alla sezione corrispondente di questa guida. Anche il tuo numero WhatsApp vive in questa schermata (§6).
- **Avanzate** — lo stato delle notifiche push di questo dispositivo, l'interruttore della **Modalità sviluppatore** a livello di spazio e la schermata delle tracce **Sviluppatore** (§8 pagamenti).
- **Informazioni** — la versione dell'app, l'autore (Florian DITTGEN), la licenza open source (0BSD) con il codice su GitHub, l'informativa sulla privacy, un link per segnalare bug, e come **sostenere il progetto** (PayPal, Revolut).
- **Esci**.

## 13. Notifiche

Promemoria di check-in, conferme in sospeso, decisioni sulle spese — e quando un admin **rimuove una tua prenotazione** (scavalca), tu e gli admin venite avvisati. La consegna è prima locale; i push dal server arrivano senza configurare nulla su Android, iPhone/iPad, browser e macOS (Firebase Cloud Messaging) — *Impostazioni → Avanzate* mostra se il push è attivo su questo dispositivo. Il contatore sull'icona dell'app mostra le tue conferme in attesa **più i tuoi messaggi non letti** — su Android, iPhone/iPad, nel Dock di macOS, nella barra delle applicazioni di Windows e nelle web app installate. I messaggi tra membri vengono annunciati **una volta per dispositivo con il mittente e il testo completo** — compreso ciò che è arrivato ad app chiusa, annunciato alla prossima apertura. Quell'annuncio è sempre generato **in locale, dall'app stessa**: il payload push non trasporta mai un nome, un orario né una parola del messaggio (§6), quindi ciò che viaggia in rete dice soltanto che è arrivato qualcosa.

## 14. Privacy

Dati minimi: nome, email, piano, prenotazioni, conto. Controlli tu la foto, lo stato e se il tuo numero di telefono è visibile nell'elenco; sulla piantina un tuo posto mostra un'iniziale, o la tua foto dove il proprietario ha attivato le foto dei membri. I badge del chiosco sono salvati solo come hash — un badge perso si revoca, non si indovina. Nessun tracciamento, nessuna analitica di terze parti. Lo storico finanziario viene anonimizzato, non cancellato, all'eliminazione dell'account (obblighi di conservazione contabile).

**GDPR (#719).** DesKilo è costruita per il Regolamento generale sulla protezione dei dati: dati ospitati nell'UE, nessun tracciamento né analitica, accesso limitato per ruolo e applicato dal server, e quattro diritti che eserciti tu stesso in **lo scudo nella barra in alto (Privacy e dati)**: **chi può vedere i miei dati** (la regola per categoria e le persone che nomina), **chi ha consultato i miei dati** (un registro scritto dal server di ogni lettura delle tue finanze o messaggi da parte di altri — mai aggirabile), **esportare i miei dati** (un file JSON, art. 20) e **uscire con cancellazione** (art. 17: prenotazioni annullate, messaggi svuotati, profilo cancellato; i documenti contabili restano per la conservazione legale indicata nella politica, riferiti a un id, non a un nome). I messaggi li leggono solo le persone della conversazione, qualunque sia il ruolo; fatture e pagamenti solo tu e chi ha il permesso finanze.

## 15. Piattaforme

Android (Google Play), iPhone/iPad, desktop — **macOS** (un DMG: trascina DesKilo in Applicazioni) e **Windows** (un installer MSI) prodotti a ogni release — e il **browser**: la stessa app, niente da installare, all'indirizzo che il tuo spazio pubblica. I tuoi dati seguono il tuo account: una postazione prenotata dal telefono compare un secondo dopo in una scheda del browser.

Il browser fa più di quanto ti aspetteresti: **il Web NFC funziona** nei browser Chromium su Android in HTTPS, ed è un modo per configurare da un telefono il tag di una sedia — le app installate per **Android e iPhone leggono i tag direttamente**, di solito la via più comoda. Ciò che non può fare è scansionare un QR con la fotocamera come fa il chiosco. Tutto il resto — piantina, prenotazioni, membri, finanze, fatture, download dei PDF — è la stessa app. Al primo avvio del DMG macOS fai clic destro sull'app e scegli *Apri*: la build non è ancora notarizzata da Apple, quindi un doppio clic mostra un avviso di Gatekeeper.

## 16. Messaggi
La scheda **Messaggi** è il centro di messaggistica del tuo spazio: tutte le conversazioni in un elenco, la più recente in alto, persone e gruppi insieme. Una riga mostra l'ultimo messaggio, l'ora e quanti non hai letto. Tocca la **matita** per iniziarne una.

**Una persona o un gruppo, un solo foglio.** Scegli una persona per una chat privata; scegline due o più e **compare un campo per il nome** — quello è un gruppo. Il nome è **unico nel tuo spazio**, così nessuno deve indovinare a quale *Team* sta scrivendo; se è già preso l'app lo dice e cambi una parola.

**Distinguerli a colpo d'occhio.** Una persona mostra la sua foto in un cerchio. Un gruppo mostra un **distintivo quadrato** con un simbolo di gruppo e — finché nessuno ha scritto — quanti membri ha.

**Dentro una conversazione.** I messaggi si leggono dal più vecchio al più recente in fumetti, con emoji e **collegamenti** attivi: un link a una prenotazione apre quella prenotazione, uno a uno spazio apre il suo foglio di prenotazione, ciascuno con *Mostra sulla piantina*. Il campo di scrittura sta sotto. **Tieni premuto un fumetto per eliminarlo**, con conferma. I tuoi messaggi portano una spunta: **grigia = consegnato**, **blu = letto**.

**Tocca il nome in alto.** In una chat privata apre il **profilo** della persona — la prenotazione di oggi, se ha fatto il check-in, il suo stato e come raggiungerla. In un gruppo apre l'**elenco dei membri**, dove un amministratore del gruppo aggiunge o rimuove persone e chiunque può uscire. Uscire non lascia mai un gruppo senza amministratore.

**La ricerca** (la lente) guarda in tre posti: **persone**, **gruppi** e le **parole dentro i messaggi**. Un risultato ti porta direttamente alla persona, al gruppo o al messaggio.

**Niente foto né file.** I messaggi portano testo, più collegamenti a una prenotazione o a uno spazio. È voluto: un'app di coworking non è un servizio di file.

**Notifiche.** Un messaggio *ricevuto* ti avvisa e conta sulla scheda **Messaggi**; aprire la conversazione azzera il contatore. I messaggi non compaiono più nella campana, riservata a conferme ed eventi. Unica eccezione: una **diffusione a tutti gli amministratori**, che non ha una conversazione in cui stare e resta lì.
