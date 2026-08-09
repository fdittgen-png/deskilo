# Guida utente

Tutto ciò che un membro, un admin o un proprietario deve sapere per usare DesKilo. *Altre lingue: [English](User-Guide) · [Français](Guide-utilisateur) · [Deutsch](Benutzerhandbuch) · [Español](Guia-de-usuario).*

> Gli screenshot di questa guida mostrano l'app in francese — ogni schermata esiste identica nelle cinque lingue (English, Français, Deutsch, Español, Italiano); cambia lingua in **Impostazioni → Lingua**.
>
> <img src="images/settings-language.jpg" width="200">

## 1. Primi passi

### Creare un account

Apri l'app e registrati con email, password (minimo 8 caratteri) e un nome visibile — oppure **continua con Google**. Il pulsante a occhio mostra o nasconde la password mentre digiti, e *Password dimenticata?* invia un link di reimpostazione. Un accesso Google può essere collegato in seguito a un account email esistente in **Impostazioni → Account collegati**.

### Creare uno spazio — o unirsi a uno

Dopo l'accesso, la schermata di benvenuto offre due strade:

- **Crea uno spazio di lavoro** — ne diventi il **proprietario**. Scegli nome, paese (determina la valuta predefinita) e fuso orario. Poi disegnerai la piantina nell'editor (§8).
- **Unisciti a uno spazio** — digita l'**ID dello spazio** che ti hanno condiviso, oppure tocca **Scansiona codice QR** e inquadra il QR d'invito appeso alla parete del tuo spazio. Ti unisci con il ruolo che l'invito porta con sé (§2).

### Profili — un account, più spazi

Un account può appartenere a più spazi. **Impostazioni → Profili** li elenca tutti: ogni riga mostra il nome dello spazio, **il tuo ruolo lì** (Membro, Admin, Proprietario) e il suo ID. Il **segno di spunta** indica il profilo in cui ti trovi adesso; la **stella** indica quello **predefinito** — il profilo con cui l'app si apre, su ogni dispositivo e anche dopo una reinstallazione (la scelta è salvata con il tuo account). Tocca una riga per cambiare, **+ Aggiungi un profilo** per unirti a un altro spazio ancora. Tutto nell'app è riferito allo spazio attivo.

### Orientarsi

L'app ha cinque destinazioni lungo il bordo inferiore: **Piantina** (§3), **Calendario** (§5), il grande pulsante centrale **Prenota** (§4), **Membri** (§6) e **Finanze** (§9). Due icone vivono in ogni intestazione: la **campanella** apre il flusso di eventi e conferme (§7, con un contatore di ciò che ti attende) e l'**ingranaggio** apre le **Impostazioni** (§12). Sui telefoni in orizzontale e sui tablet la maggior parte delle schermate passa a un **layout diviso** — i controlli in un pannello laterale, il contenuto a riempire il resto.

**Tutto resta dal vivo.** Qualunque cosa qualcuno cambi — una prenotazione, un nuovo membro, un'impostazione — viene inviata in pochi secondi a ogni dispositivo connesso, compreso quello che ha fatto la modifica. Nessun riavvio, nessun trascinare-per-aggiornare.

## 2. Ruoli e inviti

DesKilo ha tre ruoli cumulativi, più un account dispositivo:

| Ruolo | Può |
|---|---|
| **Membro** | Fare check-in/out, prenotare, presentare spese, vedere e gestire i propri eventi e il proprio conto |
| **Admin** | Tutto ciò che può un membro, più: agire *per chiunque* (prenotazioni, pagamenti, spese — soggetto a conferma, §7), approvare le spese, emettere badge per il chiosco |
| **Proprietario** | Tutto ciò che può un admin, più: modificare lo spazio fisico, definire piani e prezzi, gestire ruoli, dispositivi chiosco e impostazioni dello spazio |
| **Comproprietario** | *Attivo*: i permessi del proprietario da subito, più la successione automatica. *Passivo*: un successore in attesa, oggi senza permessi aggiuntivi |
| **Chiosco** | Un account per tablet a parete (§10) — mostra solo la piantina; i membri veri agiscono attraverso di esso con un badge |

Quale ruolo possa fare cosa non è scolpito nella pietra: il proprietario lo regola nella matrice **Gestione dei ruoli** (§8).

**Ogni invito è legato a un ruolo.** Nella schermata *ID spazio & QR* del proprietario due schede contengono due inviti, ciascuno con il proprio QR e il proprio codice:

- **Invito membro** — l'ID dello spazio stesso, mostrato sotto il nome dello spazio. Stampalo, appendilo alla parete, condividilo liberamente: chi lo scansiona o lo digita entra come semplice membro. Pulsanti: **Copia l'ID**, **Condividi come PNG**, **Cambia l'ID dello spazio** (sostituisci l'ID generato con uno memorizzabile, 4–20 lettere/cifre) e **Invita qualcuno**.
- **Invito admin** — un **codice personale monouso**, emesso da un proprietario per una persona precisa. La schermata lo dice chiaramente: *questo codice ammette UNA persona come admin, poi scade* (un codice inutilizzato decade dopo 14 giorni). Consegnalo solo alla persona a cui è destinato; emettine uno nuovo per ogni admin con **Nuovo codice admin**.
- **Gli inviti parlano la lingua dell'invitato** — il foglio d'invito scrive il messaggio nella lingua che scegli (cinque disponibili), per impostazione predefinita la **lingua dello spazio** definita nelle *Impostazioni dello spazio*. Lì il proprietario può anche personalizzare il testo dell'invito **per lingua**, con segnaposto come `{firstName}`, `{workspaceName}`, `{inviteLink}`, `{downloadUrl}`, `{role}`; una lingua lasciata vuota usa il messaggio integrato tradotto.

**Non esiste un invito proprietario — di proposito** (il piè della schermata te lo ricorda). La proprietà può essere concessa solo da un proprietario esistente, in *Membri e piani*. Uno spazio mantiene sempre almeno un proprietario. Promuovere o retrocedere un **admin** passa dal flusso di validazione (§7) — si applica quando i validatori dello spazio confermano.

**I comproprietari tengono in vita lo spazio.** Il proprietario nomina qualsiasi membro o admin come comproprietario (*Membri e piani → il membro → Comproprietà*), in una di due varianti: un comproprietario **attivo** lavora da subito con i permessi del proprietario; un comproprietario **passivo** non ha permessi aggiuntivi fino al giorno in cui servono. In entrambi i casi la successione è automatica: se l'ultimo proprietario se ne va — esce, viene rimosso, o il suo account scompare — il miglior comproprietario (attivo prima di passivo) **diventa proprietario all'istante**, sul server, senza alcuna azione richiesta. Il proprietario può anche passare la mano deliberatamente in qualsiasi momento con *Promuovi a proprietario ora*. Una sfumatura: le regole di validazione che esigono l'approvazione del *proprietario* (§7) intendono sempre un proprietario vero e proprio, non un comproprietario attivo.

Il QR codifica un link che nomina il ruolo concesso (`deskilo://join?role=…`). Manomettere il link non cambia nulla — il server ricava il ruolo dal codice stesso: l'ID dello spazio fa sempre entrare come membro, e un invito personale fa entrare esattamente nel ruolo con cui è stato emesso, una sola volta. Un codice admin inoltrato già usato — o scaduto — non ammette nessuno.

**Invitare via messaggio** (*Invita qualcuno*): ogni invio WhatsApp/SMS/condivisione emette il proprio codice personale monouso e compone un messaggio pronto nella lingua dell'invitato. Il destinatario può semplicemente copiare l'intero messaggio e incollarlo nel campo di adesione dell'app — il codice viene rilevato automaticamente.

## 3. La piantina (scheda Piantina)

La piantina mostra il livello attivo del tuo spazio: uffici, tavoli e posti, con codice colore — **libero**, **prenotato**, **occupato**, **mio**, **bloccato**. Si apre **all'istante dagli ultimi dati noti** e si aggiorna in background — con un Wi-Fi instabile vedi comunque lo stato più recente invece di una schermata vuota. I posti occupati mostrano il nome di chi c'è, un **badge di check-in** quando è arrivato, e un **punto verde** quando è online nell'app in questo momento. Quando un **tavolo, una sala o un piano intero** è prenotato, lo dice lo spazio stesso — una velatura colorata, un bordo marcato e un **chip con lucchetto e il nome dell'occupante** al centro (un glifo di check-in quando è arrivato); l'etichetta della sala recita *Bureau 2 · Florian*. Lo vedono tutti gli utenti, sulla piantina, nell'hub Prenota e sul chiosco.

La piantina può somigliare al tuo spazio reale: il proprietario può mettere una **foto della stanza come sfondo del livello** e piazzare liberamente **immagini illustrative ridimensionabili** (piante, divani…) sulla griglia. Un cursore di **trasparenza dei tavoli** nelle impostazioni dello spazio lascia trasparire la foto sotto i tavoli disegnati.

Muoversi:

- In alto: un interruttore **mappa / elenco** (l'elenco mostra gli stessi posti come righe), il **chip della data** (tocca per sfogliare un altro giorno) e tre **chip di fascia oraria** — mattina, pomeriggio, giornata intera — che filtrano ciò che la piantina mostra.
- La tela **si adatta da sola** al tuo piano all'apertura o alla rotazione del dispositivo; **pizzica per zoomare** o usa i pulsanti **+ / −**, trascina le **barre di scorrimento** ai bordi e tocca il pulsante di **adattamento** per ricentrare.
- Scegli il piano dalla **barra dei livelli** a destra (1, 2, …); la sua **icona livelli** agisce sull'intero livello (sotto). In **orizzontale**, i controlli passano in un pannello laterale e la piantina riempie lo schermo — comodo sui tablet.

Prenotare dalla piantina:

- **Check-in al volo**: tocca un posto libero → la scheda propone *adesso* fino alla fine predefinita dello spazio → conferma. Se qualcuno ha prenotato quel posto più tardi, la tua ora di fine viene limitata e te lo diciamo.
- **Check-in su prenotazione**: fare check-in significa *sei qui* — la finestra apre **15 minuti prima** del tuo inizio e si chiude alla fine della prenotazione. Fuori dalla finestra il pulsante di check-in è disattivato e dice quando apre; sfogliare un orario futuro non offre mai un check-in dal vivo. Gli admin possono fare il check-in di un membro presente al suo posto (finché *prenota per altri* è attivo).
- **Check-out**: manuale — o, se il proprietario attiva l'**auto check-in/out**, le prenotazioni dimenticate si completano da sole a fine giornata: quelle mai toccate contano come frequentate dal loro inizio alla loro fine, e i check-out dimenticati si chiudono alla fine propria della prenotazione.
- **Spazi interi**: **tocca due volte** un tavolo, una stanza o un tratto libero del pavimento — oppure tocca l'**icona livelli** sulla barra dei livelli — per agire sull'**intero tavolo, ufficio o piano**: la scheda nomina il livello, mostra il periodo (es. *gio 6 ago 10:13 → 12:00*), lascia agli admin la scelta **Per il membro** (te stesso o qualcun altro) e conferma con **Prenota il piano**. Stesso selettore di periodo e stesse opzioni di ripetizione di una postazione.
- **Selettore orario**: scegli una finestra da→a (o Mattina / Pomeriggio / Giornata intera, secondo la granularità dello spazio) per vedere l'occupazione in qualsiasi momento futuro.
- I posti possono avere **accessori** (monitor, scrivania regolabile…), alcuni con supplemento per mezza giornata che compare sul tuo estratto.
- Le prenotazioni contano sui tuoi **giorni mensili** (§9) — oltre il tuo piano, l'app blocca o addebita, secondo ciò che il proprietario ha configurato per te.

## 4. Prenotazioni (hub Prenota)

Apri l'hub **Prenota** (pulsante centrale). In alto: i quattro **pulsanti di vista**, il **chip della data**, il pulsante di **scansione QR** (sotto, §4a), i **chip di fascia oraria** (mattina / pomeriggio / giornata intera) e i **chip di piano** (*Tutti i piani*, o uno per livello). Poi quattro viste:

- **Piantina** — la piantina filtrata sulla finestra scelta; tocca un posto libero per prenotarlo.
- **Giorno** — ogni posto come riga temporale del giorno selezionato (08:00 → 17:00 o l'orario del tuo spazio, la linea rossa segna *adesso*); tocca un tratto libero per prenotare, tocca il tuo blocco per vederne i dettagli.
- **Settimana** — una griglia posto × giorno dell'intera settimana ISO, con una striscia dei giorni (*lun 3 … dom 9*) in alto; ogni cella contiene le mezze giornate del giorno con l'iniziale dell'occupante. Trova una mezza giornata libera a colpo d'occhio e toccala per prenotare.
- **Mese** — un calendario di disponibilità: ogni giorno mostra il suo **conteggio di scrivanie libere** (es. *10/12*); tocca un giorno per entrare nella sua vista Giorno.

**Un posto alla volta**: puoi tenere una sola prenotazione attiva per finestra temporale — prenotare o fare check-in altrove mentre un'altra è in corso viene rifiutato, e un check-in chiude ogni check-in precedente la cui prenotazione è già finita. Gli admin e i proprietari possono **scavalcare**: toccare un posto occupato o prenotato offre *Rimuovi la prenotazione (scavalca)* — la prenotazione viene rimossa e il membro e tutti gli admin vengono avvisati tramite il flusso degli eventi.

Le prenotazioni seguono la **regola di granularità** dello spazio (§8 Disponibilità) — mezze giornate, giornate intere, orari reali (da–a esatto, con le finestre di mezza/giornata intera come scorciatoie), oppure orari liberi di inizio/fine sulla griglia di minuti del proprietario. Mezze giornate e giornate intere coprono l'**orario di lavoro** configurato dello spazio (predefinito 8:00–17:00, con il limite di mezza giornata alle 12:00). Rispettano i **giorni di apertura** e i **giorni di chiusura**, e le regole di prenotazione (orizzonte di anticipo, durata massima, termine di cancellazione). Esigenze ricorrenti? Prenota una **serie** (giornaliera, feriale, settimanale) — giorni chiusi e conflitti vengono saltati e segnalati.

**Eliminare una prenotazione passata o con check-in è una richiesta, non un'azione.** Una prenotazione il cui inizio è passato — o dove hai già fatto check-in — non si annulla direttamente: la scheda offre invece **Richiedi eliminazione**. Un proprietario o admin decide l'unica domanda che conta per la fatturazione: il check-in è stato semplicemente dimenticato (la prenotazione resta agli atti), o non è mai stata usata (viene rimossa)? La richiesta appare nel flusso Eventi con il tuo motivo facoltativo; le prenotazioni future mai toccate mantengono il normale annullamento con un tocco.

### 4a. Scansionare un codice spazio

Ogni postazione, tavolo, ufficio e piano può avere una **scheda QR** stampata (§8). Tocca il **pulsante di scansione** nell'hub Prenota, inquadra la scheda — o digita il suo codice — e l'app identifica lo spazio e mostra esattamente ciò che *tu* puoi farci:

- **Scheda postazione** — prenota o fai check-in su quella precisa postazione, al momento (finestra di oggi: mattina / pomeriggio / giornata intera dove lo spazio usa le mezze giornate, altrimenti da adesso per le prossime ore).
- **Scheda tavolo** — le postazioni del tavolo con il loro stato in tempo reale; scegline una libera.
- **Scheda ufficio o piano** — se il proprietario lo ha reso prenotabile, la funzionalità *Prenotazioni di ufficio e piano* è attiva **e** possiedi il diritto personale (§8) — proprietari e admin lo hanno sempre — puoi prenotare o fare check-in sull'**intero ufficio o piano** — con lo stesso selettore di periodo (mattina / pomeriggio / giornata intera, o orari liberi) e le stesse opzioni di **serie** di una postazione; il suo prezzo per mezza giornata viene mostrato e finisce sulla tua fattura. Altrimenti la scheda ti spiega perché, e un ufficio ripiega sulle sue postazioni.

**I conflitti proteggono in entrambe le direzioni:** un ufficio o un piano non può essere prenotato mentre una postazione al suo interno è già prenotata in quella finestra — e nessuna postazione può essere prenotata mentre il suo ufficio o piano è prenotato per intero.

## 5. Calendario (scheda Calendario)

Il mese a colpo d'occhio, con due ambiti e due forme:

- **Miei / Tutti** — le tue prenotazioni, o quelle dell'intera comunità. I tuoi giorni sono segnati in **rosso**, quelli degli altri membri in **blu**, oggi è cerchiato; un punto sotto un giorno significa che lì c'è qualcosa di prenotato.
- L'**interruttore di forma** accanto commuta la metà inferiore tra una **griglia settimanale** (posti × giorni, come nell'hub Prenota) e un **elenco agenda** (ogni prenotazione come scheda: finestra oraria, membro, spazio).
- I **chip di piano** (*Tutti i piani* / per livello) filtrano entrambe le forme.
- Tocca un giorno nella griglia del mese per caricarlo sotto. In orizzontale, calendario e dettaglio usano il layout diviso.

## 6. Elenco dei membri (scheda Membri)

Guarda chi fa parte della tua comunità:

- Ogni scheda membro mostra la **foto** (o l'iniziale), il **chip di ruolo** (Admin, Proprietario), lo **stato personalizzato** («a Berlino fino a venerdì…»), un indicatore **online / ultimo accesso** (*Online*, *10 min*, *2 g*) e un **chip di prenotazione**: posto con check-in, *Prenotato adesso*, o la prossima prenotazione in arrivo.
- Tocca un membro per la sua **scheda di dettaglio** — ruolo, presenza, le sue **prossime prenotazioni** e **Invia una notifica**.
- **Invia una notifica**: una breve nota in-app (fino a 500 caratteri) a un altro membro — consegnata come push e come notifica con il tuo nome e il tuo messaggio. Il testo completo resta sempre leggibile in **Eventi → Messaggi**, per il destinatario e per il mittente (il push in sé non trasporta contenuto, per scelta di privacy). Gli admin hanno un megafono **Notifica tutti gli admin** nell'intestazione che raggiunge tutti gli admin, proprietario incluso. Attivabile/disattivabile con la funzionalità *Notifiche tra membri*. Durante la scrittura, due chip permettono di **collegare una tua prenotazione** o **uno spazio** (posto, tavolo, stanza o piano) — il riferimento appare come link toccabile da entrambe le parti: un link di prenotazione apre quella prenotazione, un link di spazio apre la scheda di prenotazione dello spazio, ideale per discutere una prenotazione futura.
- L'**icona messaggio** su una scheda scrive a quel membro su **WhatsApp** (se ha condiviso il numero); il **pulsante gruppo** apre il gruppo WhatsApp della tua comunità (impostato dal proprietario).
- Imposta la tua foto, il tuo stato e la visibilità del telefono in **Impostazioni** (§12).
- Gli admin e i proprietari vedono in più l'**email** di ogni membro sotto il nome — i membri normali no: il contatto tra membri resta il numero WhatsApp condiviso volontariamente.

## 7. Eventi e conferme (icona campanella)

Il flusso eventi è la traccia di controllo del tuo spazio: prenotazioni create/modificate/cancellate, pagamenti registrati, fatture pagate, spese presentate, richieste di giorni extra, cambi di ruolo, richieste di eliminazione. I membri vedono i propri eventi; admin e proprietari vedono quelli di tutti. I **chip di filtro** (Tutti · Prenotazione · Pagamento · Spesa · …) restringono l'elenco; ogni riga porta la sua icona di stato — una **clessidra** finché in sospeso, una **spunta verde** una volta confermata — e gli eventi di denaro mostrano *chi li ha validati e quando* direttamente sulla riga.

**In attesa della tua conferma:** ogni volta che un admin fa qualcosa *per qualcun altro* — ti prenota un posto, registra il tuo pagamento, retrocede un admin — resta **in sospeso finché non viene confermato**. Le voci in sospeso sono fissate in alto con una ✕ rossa e un pulsante verde **Accetta**, e ricevi una notifica. Le azioni che compi su te stesso non richiedono mai conferma.

**Messaggi:** la campanella raccoglie anche le tue notifiche tra membri (§6) — ricevute e inviate, le più recenti in alto. L'elenco mostra solo i **primi 64 caratteri**; **tocca un messaggio** per leggerlo per intero — emoji comprese — con i suoi link di riferimento attivi (un link di prenotazione apre quella prenotazione, un link di spazio apre la scheda di prenotazione) e i pulsanti **Rispondi**/**Elimina**. **Scorri a destra** per rispondere al mittente, **a sinistra** per eliminarlo — l'eliminazione chiede sempre **conferma** (una diffusione ricevuta a tutti gli admin non si può eliminare — sparirebbe per ogni admin). I messaggi non letti contano sulla campanella e sull'icona dell'app finché non apri questa schermata.

**Quorum di validazione:** per le questioni di denaro e i cambi di ruolo il proprietario definisce *chi* deve approvare e *quante* approvazioni servono. **Nessuno valida il proprio evento** — solo un'altra persona può; dove non esiste un altro validatore, la richiesta semplicemente attende. Le richieste senza risposta scadono dopo 7 giorni — nulla di costoso viene mai concesso in silenzio, né auto-concesso.

Il proprietario regola tutto questo per **dominio** in **Impostazioni → Regole di validazione** — una scheda per tipo di evento, ognuna che eredita dalla **regola predefinita** finché non viene modificata: *Regola predefinita, Pagamento, Spesa, Servizio, Mezze giornate extra, Eliminazione prenotazione, Cambio di ruolo, Nuovo membro, Prenotazione, Prenotazioni di spazi interi, Pagamento fattura, Rettifica* — e le richieste di **annullamento del saldo** delle fatture viaggiano sullo stesso framework. Una regola stabilisce il numero di validazioni richieste, *quali* admin possono validare (tutti, o alcuni nominati) e se il proprietario deve sempre dare l'approvazione finale.

<p><img src="images/validation-rules.jpg" width="240"> <img src="images/validation-rule-edit.jpg" width="240"></p>

*A sinistra: una regola per dominio, che eredita da quella predefinita. A destra: la modifica di una regola — validazioni richieste, validatori autorizzati, approvazione del proprietario.*

## 8. Per i proprietari: editor e impostazioni

Tutta l'amministrazione vive in **Impostazioni → Amministrazione** — *Spazio di coworking* (le impostazioni dello spazio), *Membri e piani*, *Gestione dei ruoli*, *Fatturazione e report* (l'hub di fatturazione con l'editor di report e le regole di sollecito nella sua intestazione), *Accessori*, *Disponibilità*, *Funzionalità* e le voci legate alle funzionalità (Pagamenti online, Badge RFID/NFC…). Una sola regola da conoscere: **la voce di impostazioni di una funzionalità appare solo finché quella funzionalità è attiva** — disattiva *Pagamenti online* in **Funzionalità** e la sua schermata di configurazione scompare con essa (e ritorna quando la riattivi). La voce **Funzionalità** è sempre presente, così puoi sempre riattivare un modulo.

<p><img src="images/settings-administration.jpg" width="240"></p>

### L'editor dello spazio

Apri l'**editor** dalla barra dell'app della scheda Piantina (icona attrezzi incrociati). La schermata **Editor dello spazio** elenca i tuoi piani — trascina per riordinare, l'**icona livelli** marca un livello *Prenotabile per intero*, il **menu ⋮** rinomina o elimina, **+ Aggiungi un piano** estende l'edificio. Apri un piano per disegnarlo sulla griglia con la barra strumenti in basso — **Seleziona · Ufficio · Tavolo · Posto · Immagine · Cancella**:

- Un **ufficio** riceve un nome, un interruttore facoltativo *Prenotabile per intero* e un **prezzo per mezza giornata**.
- Un **tavolo** riceve un nome e la stessa opzione tavolo-intero.
- Un **posto** riceve un nome, un **orientamento di seduta** (↑ → ↓ ←), un **tipo di sedia** facoltativo, i suoi **accessori** (ognuno può avere un supplemento per mezza giornata) e un interruttore **Bloccato (manutenzione)**.
- **Immagine** piazza un'illustrazione ridimensionabile; l'icona foto nella barra dell'app imposta la **foto di sfondo** del livello.
- Eliminare qualcosa con prenotazioni future obbliga prima a risolverle.

### ID spazio & QR

I tuoi inviti legati ai ruoli (§2): invito membro = l'ID dello spazio (sostituiscilo con uno memorizzabile, copialo, condividi il QR come PNG), invito admin = codici personali monouso.

### Disponibilità

- **Giorni di apertura** — chip lun…dom.
- **Granularità di prenotazione** — una tra: *orari liberi*, *griglia di 5 / 15 / 30 / 60 minuti*, *mezze giornate (mattina e pomeriggio)*, *solo giornate intere*, oppure *orari reali* (da–a esatto, con le scorciatoie di mezza/giornata intera).
- **Orario di lavoro** — inizio giornata, limite di mezza giornata, fine giornata (predefinito 08:00 / 12:00 / 17:00). Le mezze giornate e le giornate intere ovunque — prenotazioni, check-in e fatturazione — seguono questi orari; con gli *orari reali* imposti anche quante ore vengono fatturate come mezza giornata e come giornata intera.
- **Giorni di chiusura** — eccezioni datate, aggiunte con **+**.

### Funzionalità

Attiva o disattiva interi moduli per spazio — ogni interruttore porta la sua descrizione direttamente sullo schermo: scheda Calendario, scheda Eventi, scheda Finanze, servizi, supplementi accessori, pagamenti online, fatture, gli admin emettono fatture, esportazione PDF, prenotazione in serie, prenota per altri, notifiche push, gli admin possono bloccare i posti, prenotazioni di tavolo/ufficio e piano, gli admin possono assegnare piani, modalità chiosco, badge RFID/NFC, elenco dei membri, integrazione WhatsApp, codici QR degli spazi, comproprietari, check-in/out automatico, esportazione dati (Excel), orario di lavoro, modello PDF della fattura, notifiche tra membri, biblioteca documenti, solleciti di pagamento (Mahnwesen), report dei membri, richieste di eliminazione prenotazioni, gestione dei ruoli. Disattivare un modulo rimuove *tutte* le sue schermate e i suoi pulsanti per ogni membro.

L'elenco è **gerarchico**: una funzionalità che ne richiede un'altra compare rientrata sotto di essa con una nota *Richiede…*, ed è in grigio finché la funzionalità madre è disattivata — *Finanze* porta con sé servizi, supplementi, pagamenti online e fatturazione; *Fatture* porta la delega agli admin, il modello PDF e i solleciti di pagamento; *Modalità chiosco* porta i badge RFID/NFC; *Elenco dei membri* porta l'integrazione WhatsApp. Disattivare una funzionalità madre toglie dall'app tutto il suo sottoalbero; la scelta salvata della funzionalità figlia torna intatta quando la madre riappare.

<p><img src="images/workspace-id-qr.jpg" width="220"> <img src="images/availability-granularity.jpg" width="220"> <img src="images/features-toggles-1.jpg" width="220"> <img src="images/features-toggles-2.jpg" width="220"></p>

### Membri e piani

Tocca un membro per aprire la sua **scheda di gestione** — ogni azione per membro in un unico posto: **Invia l'accordo finanziario** (§11d), **Invia una notifica**, **Aggiungi un servizio** (servizio, quantità, mese di fatturazione → *invia per conferma*), **Abbonamento** (la sua percentuale), **Quando i giorni finiscono** (la politica di consumo extra, §9), **Limite di prenotazioni** (tetto di prenotazioni simultanee), **Può prenotare un intero tavolo, ufficio o piano**, **Badge** (§10), **Rendi admin** (validato, §7), **Comproprietà**, **Trasforma in chiosco** e **Sospendi l'iscrizione**. Ogni riga mostra l'**email** del membro sotto il nome.

<p><img src="images/member-management-sheet.jpg" width="220"> <img src="images/member-subscription.jpg" width="220"> <img src="images/member-reservation-limit.jpg" width="220"></p>

### Fatturazione

- **Fasce tariffarie** — la scala di prezzi dietro gli abbonamenti percentuali: ogni fascia dice *da X %*, *fino a Y %*, il **canone** mensile e la **tariffa extra** per mezza giornata aggiuntiva. **+ Aggiungi una fascia** estende la scala.
- **Livelli di abbonamento** — quali percentuali i membri possono scegliere (chip: 25 % · 50 % · 75 % · 100 %, più i tuoi valori), e un interruttore facoltativo **valore libero negoziato**.
- **Pacchetti di giorni** — un numero di giorni a un prezzo (nome · giorni · prezzo), ognuno con il proprio interruttore di attivazione; i membri con politica a *pacchetti* li acquistano quando i loro giorni finiscono.

### Servizi e Accessori

I cataloghi dietro il §9 — extra definiti dal proprietario (armadietti, stampe…, ognuno con un prezzo e un'aliquota IVA facoltativa) e dotazioni per posto con supplementi facoltativi per mezza giornata. Entrambi sono semplici elenchi con un pulsante **+**.

<p><img src="images/billing-bands-levels-packages.jpg" width="220"> <img src="images/services-catalog.jpg" width="220"> <img src="images/services-new-service.jpg" width="220"> <img src="images/accessories-catalog.jpg" width="220"></p>

### Impostazioni dello spazio (Spazio di coworking)

La schermata propria dello spazio, dall'alto in basso:

- **Identità** — nome, paese, valuta (proposta dal paese, modificabile), fuso orario, **lingua dello spazio** (gli inviti la usano per impostazione predefinita; *lingua dell'app del mittente* è un'opzione) e l'**indirizzo** postale stampato sulle fatture.
- **Pagamenti e fatturazione** — le **istruzioni di pagamento** che i membri vedono su un estratto non saldato (IBAN, link PayPal.me, numero di telefono Wero, Lydia, Wisetag, indicazione della causale — lascia un campo vuoto per nasconderlo), e **Identità legale e fatturazione elettronica** (§11a).
- **Gruppo WhatsApp** — il link del gruppo della comunità mostrato nell'elenco.
- **Messaggio d'invito** — i modelli d'invito per lingua (§2).
- **Trasparenza dei tavoli** — il cursore che lascia trasparire una foto di sfondo sotto i tavoli disegnati.
- **Modello PDF della fattura** e **Regole di sollecito** — scorciatoie verso l'editor di report e la configurazione dei solleciti (§11).
- **Esportazioni** — *Esporta lo spazio (XML)* (impostazioni + piantina, nessun dato personale — backup, modello, migrazione di un'istanza), *Esporta la configurazione (PDF)* (un'istantanea completa: impostazioni, membri, piantina), *Report dello spazio* (tutto sullo spazio tramite il modello «spazio» del motore di report), *Codici QR degli spazi (PDF)* (un QR formato carta di credito per postazione, tavolo, ufficio e piano, dieci per A4), *Esporta i dati (Excel)* (una cartella di lavoro: prenotazioni, pagamenti, fatture, membri, piantina — una scheda ciascuno), *Importa lo spazio (XML)* (ripristina impostazioni e piantina; sostituisce la piantina attuale). Ogni esportazione finisce nella cartella **Download** del tuo dispositivo.
- **Zona pericolosa** — **Reimposta lo spazio**: elimina tutte le prenotazioni, la contabilità e la piantina; conserva impostazioni e membri. Protetto da una conferma digitata.

### Codici QR degli spazi e prenotazioni di spazi interi

Quattro passi trasformano «scansiona il codice sul tavolo» nel flusso di prenotazione quotidiano (§4a):

1. Nell'**editor**, marca un ufficio o un piano come **Prenotabile per intero** e assegnagli un **prezzo per mezza giornata** — la scheda proprietà dell'ufficio, o per un piano l'**icona livelli direttamente sulla sua riga**.
2. Attiva **Prenotazioni di ufficio e piano** in **Funzionalità** (disattivata per impostazione predefinita).
3. Concedi a ogni membro autorizzato **«Può prenotare un ufficio o un piano intero»** — proprietari e admin lo impostano nella scheda di gestione del membro, mai per se stessi.
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

### Configurare i pagamenti online

Ogni comunità incassa sul **proprio** account del fornitore; l'app non conserva mai le chiavi segrete su alcun dispositivo — restano sul server.

1. Apri **Impostazioni → Pagamenti online** (solo proprietario).
2. Scegli un fornitore e incolla le sue chiavi dal suo pannello:
   - **PayPal** — Client ID, Secret, Ambiente (inizia con *sandbox*), ID webhook, URL di ritorno (PayPal Developer → la tua app REST).
   - **Carta di credito (Stripe)** — Chiave segreta, Segreto di firma webhook, URL di ritorno (Stripe → chiavi API / Webhook).
   - **Mollie** — Chiave API, URL di ritorno (offre iDEAL, Bancontact, carte…).
   - **Wero (tramite Mollie)** — la stessa chiave API Mollie, con Wero abilitato nel tuo account Mollie.
3. **Salva** — appare un chip verde *Configurato*. Attiva la funzionalità **Pagamenti online** (Impostazioni → Funzionalità) e i membri vedranno **Paga online** su una fattura da saldare. (La voce di impostazioni *Pagamenti online* appare solo finché la funzionalità è attiva.)

<p><img src="images/payment-config-paypal-stripe.jpg" width="240"> <img src="images/payment-config-mollie-wero.jpg" width="240"></p>

Un segreto salvato non viene più mostrato — lascia il campo vuoto per mantenerlo, digita per sostituirlo, **Rimuovi** per togliere il fornitore. Le commissioni sono del fornitore (tipicamente ~1,5–3 % per pagamento, senza canone mensile); DesKilo non aggiunge nulla, e il bonifico/IBAN manuale resta gratuito.

Se un pagamento non parte, attiva **Impostazioni → Avanzate → Modalità sviluppatore** e apri la schermata **Sviluppatore**: la traccia *pagamenti* mostra esattamente quali fornitori sono configurati e quali campi mancano ancora.

<p><img src="images/developer-payment-traces.jpg" width="240"></p>

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

1. Apri **Impostazioni → Badge RFID / NFC** (solo proprietario). Attiva **Abilita il check-in con badge NFC** e leggi la riga di **stato del dispositivo** — distingue *pronto*, *NFC disattivato nelle impostazioni Android* e *nessun hardware NFC* (gli iPad non ne hanno).
2. Dai una tessera a ogni membro: **Membri e piani → il membro → Badge → Registra tessera**, poi avvicina la sua tessera al dispositivo. Va bene qualsiasi tessera con chip leggibile (MIFARE, NTAG…). I membri possono farlo anche **da soli**: **Impostazioni → Il mio badge** emette il loro badge QR stampabile e registra la loro tessera — senza bisogno di un admin.
3. Usale a un **chiosco** (§10): il membro avvicina la tessera per prenotare o fare check-in. Revoca una tessera persa dalla stessa finestra Badge; **scorri un badge revocato verso destra per eliminarlo** definitivamente (dopo conferma).

I badge appartengono a **un solo spazio** — la finestra indica in quale stai registrando, quindi registra la tessera nello spazio il cui chiosco la leggerà. La stessa tessera fisica può servirti in più spazi. Un badge QR salvato **come PDF** stampa dieci copie formato carta di credito su una pagina A4 — scorte incluse.

<p><img src="images/nfc-config.jpg" width="240"> <img src="images/member-badges-dialog.jpg" width="240"></p>

## 9. Denaro (scheda Finanze)

Il tuo conto risponde a *quanto devo, quanto mi devono* — e *quanto posso ancora prenotare*. In verticale l'estratto del mese scorre sopra i pulsanti d'azione; in orizzontale le azioni passano in un pannello laterale e l'estratto riempie il resto. L'intestazione **‹ mese ›** sfoglia qualsiasi mese; il **pulsante PDF** esporta l'estratto visibile (§ sotto).

**L'estratto, scheda per scheda:**

- **Questo mese** — quanti **giorni** include il tuo abbonamento questo mese, quanti ne hai **usati**, quanti ne **restano**, con barra di avanzamento. Una mattina prenotata conta 0,5 giorni. Il diritto mensile segue i giorni di apertura dello spazio e la tua percentuale — la scheda dell'abbonamento sotto lo spiega per esteso (*3 mezze giornate usate su 42, 21 giorni di apertura*).
- **Servizi consumati** — ogni consumo di servizio con il totale dei servizi.
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
- **Documenti** — **Fatture** (le tue restano sempre leggibili qui: posizioni, saldo, stato — e per chi emette, l'hub di fatturazione, §11), l'**accordo finanziario** e il **report mensile dei pagamenti**, self-service (§11).

### 9a. Una volta fatturato il mese, decide la fattura

- Il tuo estratto mostra una **scheda fattura** — numero, stato, totale, già pagato, residuo — e il mese risulta **saldato** non appena la fattura è pagata, il suo saldo annullato o la sua nota di credito rimborsata, anche se il pagamento che la salda è stato registrato un mese dopo. Una fattura **parzialmente pagata** lascia il mese aperto esattamente per l'**importo residuo** (è anche quanto addebita *Paga online*). Un mese con **nota di credito** mostra ciò che lo spazio ti deve — nulla da pagare da parte tua.
- **Il tuo conto** — quando possiedi credito disponibile (un avoir, o pagamenti in eccesso di un mese passato), la scheda Finanze mostra la tua posizione reale tra i mesi, sopra l'estratto: **credito disponibile**, ogni **fattura aperta** con il residuo, i rimborsi che lo spazio ti deve e la **posizione netta** risultante. Il tuo credito può saldare le fatture aperte — lo spazio lo applica durante la riconciliazione dei pagamenti (imputazione). I mesi precedenti alla tua adesione non devono nulla e non risultano mai aperti.

### 9b. Anteprima rapida, scarica, condividi — ogni report

Ogni report dell'app — l'estratto, le fatture, le proforma, le note di credito, i tuoi documenti self-service — offre le stesse tre azioni: **Anteprima rapida** (vedere il documento renderizzato sullo schermo prima che esista un PDF), **Scarica PDF** (salvare localmente) e **Condividi PDF** (consegnarlo a qualsiasi app — WhatsApp, mail, …).

**I report parlano la lingua di chi legge:** i tuoi documenti vengono stampati nella *tua* lingua dell'app quando lo spazio la fornisce, con ripiego sulla lingua dello spazio (§11 modelli per lingua).

## 10. Modalità chiosco (tablet a parete)

Monta un tablet Android o un iPad vicino alla porta e lascia che le persone facciano check-in entrando:

1. Il proprietario crea un account normale per il dispositivo, lo unisce allo spazio e lo marca come **chiosco** in *Membri e piani*.
2. **La modalità chiosco non parte mai da sola.** A ogni avvio dell'app il tablet chiede *Avviare la modalità chiosco?* — conferma e il tablet si blocca: solo la piantina a schermo intero, pulsante indietro disabilitato, l'app si fissa in primo piano così non si può aprire altro; per uscire dalla modalità chiosco bisogna riavviare il tablet. Scegli invece *Non ora* e l'app si apre normalmente — utile per la configurazione. La designazione a chiosco si può revocare in qualsiasi momento: sul dispositivo in **Impostazioni → Dispositivo chiosco**, o dal proprietario in *Membri e piani*.
3. Ogni membro porta con sé un **badge** — emesso da un admin (*Membri e piani → Badge*) o dal membro stesso (**Impostazioni → Il mio badge**, §8): un **badge QR** stampabile e/o la sua **tessera RFID/NFC**.
4. Al chiosco, tocca un posto (o **Questo piano**) → **Check-in**, **Prenota** o **Check-out**. Per check-in e prenotazione viene prima un **passaggio del periodo** — dici *quando* prima di tirare fuori il badge, **solo oggi** e fedele alla granularità dello spazio: con le mezze giornate, chip **Mattina / Pomeriggio / Giornata** (una finestra in corso parte *adesso*, quelle passate sono disattivate, dopo l'orario resta un solo *Resto della giornata*); con le granularità orarie, selettori **Da/A** agganciati alla griglia — fare check-in significa essere lì, quindi l'inizio è fissato ad *adesso* e si muove solo la fine. Prenotare una finestra già iniziata chiede anche **Check-in immediato?** (attivo per default — dopotutto sei davanti al chiosco): confermare crea la prenotazione *già registrata*, con un'unica presentazione del badge. Poi presenta il badge:
   - **Avvicina la tessera RFID/NFC.** Finché il lettore di tessere è armato la fotocamera resta spenta; se l'NFC è disattivato o assente, la scheda lo dice esplicitamente.
   - Oppure tocca **Scansiona il badge QR** — il tablet legge il badge stampato **con la propria fotocamera** (frontale per impostazione predefinita, perché l'obiettivo posteriore di un tablet a parete guarda il muro; cambia in *Impostazioni → Scansiona con la fotocamera frontale*). Funzionano anche un lettore di codici USB/Bluetooth o la digitazione del codice.
5. **Nulla accade senza il tuo consenso:** il chiosco identifica il badge, chiude i lettori e mostra un riepilogo — *chi* ha riconosciuto, *cosa* accadrà, *dove* e *quando*. Solo **Conferma** esegue e aggiorna la piantina; **Rifiuta** annulla.

La tua identità esiste solo per il tempo dell'operazione: la credenziale va una volta al server, la prenotazione è fatta **a tuo nome**, e nulla resta sul tablet — sei «disconnesso» appena finisce. (L'accesso per singola operazione con Google è ancora nella roadmap; **gli iPad non hanno NFC**, quindi lì la via è il QR con fotocamera.)

## 11. Fatturazione (proprietari e admin di fatturazione)

*I proprietari emettono le fatture; anche gli admin, quando detengono il permesso **emettere fatture** (Gestione dei ruoli, §8 — o la vecchia delega **Gli admin emettono fatture**). La funzionalità **Fatture** sta sotto Finanze nell'elenco delle funzionalità.*

Una fattura in DesKilo viene generata, mai composta: le sue posizioni sono **derivate esclusivamente dai dati tracciati del mese** — abbonamento, eccedenza, supplementi, servizi, pacchetti — meno i pagamenti e gli accrediti del mese, così la riga finale **è il saldo dovuto**. Ogni documento fotografa gli indirizzi postali dello spazio e del membro (imposta il tuo in **Impostazioni → Indirizzo**; l'indirizzo dello spazio sta nelle impostazioni dello spazio) ed è **firmato digitalmente** all'emissione — dopo non cambia più. Un **allegato dettagliato** (il libro mastro e le presenze del mese) si aggiunge con un interruttore al momento dell'emissione.

Chi emette apre **Finanze → Fatture** e trova un hub a tre schede sotto una striscia di riepilogo in tempo reale (*N da fatturare · N aperte · X in sospeso · N da rimborsare · Y*):

- **Da fatturare** — ogni membro il cui mese precedente ha dati fatturabili e nessuna fattura, con il totale del mese: emetti per membro (con l'anteprima delle posizioni derivate) o **Fattura tutto** in un colpo solo — che prima chiede conferma, indicando il numero, il mese e il totale. Il pulsante **Nuova fattura** apre la stessa scheda per qualsiasi membro e mese — selettore del membro, ‹ mese ›, le posizioni derivate, il saldo, l'interruttore dell'**allegato dettagliato** ed **Emetti fattura** (uno snack verde *Fattura emessa.* conferma). **Una sola fattura attiva per membro e mese** — un mese torna fatturabile solo dopo che la sua fattura è stata annullata. Il foglio di emissione si apre sul **mese chiuso** (il momento in cui i suoi numeri smettono di muoversi); se scegli il mese in corso ti avvisa, perché quel mese si può fatturare una sola volta.
- **Aperte** — fatture emesse in attesa di saldo, dalle più vecchie; ciò che attende da oltre 30 giorni diventa rosso, sulla scheda e nella striscia di riepilogo. Ogni azione è un'icona con suggerimento (annulla · proforma · sollecito · segna come pagata). **Tocca una scheda per leggere la fattura.** **Invia un promemoria** registra il sollecito e condivide il PDF con un messaggio — la scheda mostra *Sollecitato ×N*. **Segna come errata** annulla la fattura per correggerla (una finestra esplicita avvisa che l'operazione è irreversibile): passa nell'archivio barrata, e una **sostitutiva** ri-deriva lo stesso mese dai dati corretti, citando l'originale. **Segna come pagata** abbina un pagamento reale (sotto). **Un pagamento parziale non chiude una fattura**: resta tra le Aperte, con badge *Parzialmente pagata* e l'importo residuo, finché il saldo non pagato non viene annullato esplicitamente **tramite il framework di convalida** — un admin/proprietario richiede l'annullamento (con un motivo), i validatori confermano e solo allora la fattura passa in archivio come *Parzialmente pagata · saldo annullato*. **Una fattura NEGATIVA è una nota di credito (avoir)** — i crediti del mese superano i suoi addebiti, quindi lo SPAZIO deve denaro al membro: il suo PDF si intitola *Nota di credito*, non riceve solleciti né riconciliazione con pagamenti del membro; la scheda mostra invece *Da rimborsare* con **Registra il rimborso** — il versamento si imputa al saldo del membro (convalidato come ogni liquidazione quando vale una regola; un rifiuto la riapre) e il documento si chiude come *Rimborsata*. La striscia di riepilogo separa le due direzioni del processo di pagamento: *N aperte · X in sospeso* conta le fatture positive al loro valore **residuo** (una fattura da 500 € con 280 € pagati conta 220 €), mentre *N da rimborsare · Y* somma le note di credito aperte che lo spazio deve ancora.
- **Archivio** — fatture chiuse, filtrabili per membro e mese e ordinabili; le fatture annullate sono **nascoste per impostazione predefinita** — il chip *Mostra annullate* riporta la catena di correzione; la barra sotto i filtri dice quante fatture corrispondono e **Azzera i filtri** riporta l'archivio intero. Ogni riga porta il suo chip di stato (*Pagata*, *Parzialmente pagata*, *Errata* barrata, le note di credito con il loro importo negativo), il suo mese e il suo importo, con **Scarica PDF** lì accanto. **Tocca una riga per aprire la fattura** — posizioni, saldo, destinatario, dove si trova (*Pagata 300,00 € il 6 ago*, *Sollecitato ×1 · ultimo sollecito…*, *Allegato: 5 movimenti, 10 check-in*), quale fattura sostituisce o da quale è stata sostituita, la sua firma — e ogni azione ancora permessa, per nome: **Anteprima rapida**, **Scarica PDF**, **Condividi PDF**, esporta la **fattura elettronica (XML)**, sollecita, segna come pagata, segna come errata, emetti una sostitutiva.

**Segnare come pagata significa abbinare un pagamento reale — o applicare un credito.** La finestra elenca i pagamenti registrati del membro — bonifici registrati e pagamenti online confermati — e tu abbini la fattura a uno di essi; non c'è alcun importo da digitare (nessun pagamento registrato? la finestra lo dice: *registralo o confermalo prima*). Elenca anche i **crediti sul conto** del membro (eccedenze da nota di credito): abbinarne uno imputa l'avoir sulla fattura, mesi passati compresi — l'alternativa standard al rimborso in contanti, per associazioni e imprese allo stesso modo. Ogni credito si spende esattamente una volta: uno già dedotto dentro una fattura emessa non può mai saldare un secondo documento. Ha pagato **di più**? Crea una **nota di credito** per l'eccedenza (un accredito sul libro mastro del membro) oppure forza l'accettazione con una nota obbligatoria. Ha pagato **di meno**? Accettalo con una nota obbligatoria. Tutti coloro che hanno accesso alla fatturazione vengono avvisati delle fatture pagate, e il proprietario può mettere una regola di validazione **Pagamento fattura** (§7): l'abbinamento resta allora in attesa del quorum — un rifiuto riapre la fattura.

**Una fattura pagata è definitiva.** Una volta abbinata non può più essere annullata, sostituita o modificata — le correzioni avvengono prima del pagamento, annullando la fattura aperta ed emettendo la sua sostitutiva. Un pagamento che **non** ha coperto l'intero importo, accettato con una nota, compare come **parzialmente pagata**, non come pagata.

**Proforma.** Entrambe le schede dell'hub offrono un'azione proforma: su **Da fatturare** rende le posizioni derivate del mese come preventivo — senza numero, senza firma, timbrata PROFORMA, e **non emette nulla**; su **Aperte** rigenera la fattura emessa come richiesta di pagamento che non può passare per l'originale. Entrambe offrono la triade anteprima rapida / scarica / condividi.

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

**In DesKilo i prezzi sono IVA inclusa.** Ciò che scrivi come prezzo di abbonamento, di servizio o di pacchetto di giorni è ciò che il membro paga. Attivare l'IVA non cambia un solo importo dovuto da nessuno — dice quanta parte di quell'importo è imposta. Per questo un estratto, un conto e una quota non si muovono mai quando aggiungi le aliquote, e per questo nessun totale va mai riconciliato.

**Configurare le aliquote.** *Identità legale e fatturazione elettronica → **Aliquote IVA***. Un elenco vuoto significa IVA disattivata: è così che ogni spazio comincia. **Usa le aliquote consuete** riempie l'elenco con l'aliquota ordinaria, intermedia e ridotta del tuo paese come prima bozza — un punto di partenza, non una consulenza fiscale. Un'aliquota è quella **predefinita** (la stella): abbonamenti, eccedenze, supplementi e rettifiche la usano, come ogni servizio che non ne ha una propria. Un servizio e un pacchetto di giorni portano ciascuno la propria aliquota, scelta nel loro editor. Rimuovere un'aliquota non la cancella mai — una a cui una fattura o un servizio fa ancora riferimento viene conservata, disattivata, così nulla viene tassato di nuovo in silenzio.

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

**Provare senza rischi.** La stessa schermata accetta **endpoint di prova** (lo UAT della piattaforma o una destinazione dev: URL + token ciascuno) accanto a quello di produzione. Con la **modalità sviluppatore** dello spazio attiva (un'impostazione a livello di spazio che solo proprietari e admin possono cambiare, in Impostazioni → Avanzate), l'invio offre la scelta dell'ambiente, un invio di prova è marcato come tale nella cronologia delle trasmissioni della fattura, e l'endpoint di produzione non viene mai usato per una prova — un ambiente di prova non configurato semplicemente rifiuta, senza ripiegare.

DesKilo continua a non trasmettere nulla per proprio conto: produce il documento e lo consegna alla piattaforma che hai scelto. I calendari degli obblighi continuano a muoversi: verifica con la tua amministrazione fiscale prima della scadenza che ti riguarda.

### 11c. L'editor di report — ogni documento, quattro modelli, cinque lingue

Il **Modello PDF della fattura** (icona matita nell'intestazione Fatture, o *Impostazioni dello spazio*) è uno strumento di reporting a bande per ogni documento che l'app stampa. Tre **bande** di report vengono rese sul PDF — intestazione, corpo (le righe della fattura), piè di pagina — mentre l'XML della fattura elettronica non viene mai toccato.

- **Un report per documento**: i chip passano tra **Fattura · Proforma · Estratto · Accordo · Pagamenti · Spazio · Livelli di sollecito**. La proforma ripiega sulle bande della fattura finché non la personalizzi; un estratto personalizzato sostituisce il PDF mensile integrato.
- **Per lingua**: una seconda fila di chip — *Predefinito (tutte le lingue)* · EN · FR · DE · ES · IT — memorizza una traduzione per documento; il report di un membro viene stampato nella *sua* lingua quando esiste un modello per essa, altrimenti nella lingua predefinita dello spazio.
- **Markup o Visuale**: la modalità **Markup** modifica le bande come testo — condizioni e cicli [Liquid](https://shopify.github.io/liquid/) (`{{ number }}`, `{% if proforma %}…{% endif %}`, `{% for line in lines %}…{% endfor %}`) più un markup di riga semplice: `#` titolo, `##` sezione, `>` testo piccolo, `---` divisore, `a | b` riga di tabella, `=` riga in grassetto, `::: … ||| … :::` colonne affiancate (il blocco indirizzi venditore-a-sinistra / cliente-a-destra e i totali allineati a destra di una facture francese — i modelli forniti seguono esattamente questa struttura), `![name]` un'immagine dalla **libreria immagini** dello spazio (*Inserisci immagine*). La modalità **Visuale** mostra le stesse bande come superficie di progettazione — righe stilizzate, `{{ token }}` evidenziati, tocca una riga per modificarla sul posto, aggiungi righe, spostale, inserisci campi dati da una tavolozza.
- **Galleria di modelli** (*Modelli*): quattro modelli pronti per ogni documento — **Classico · Semplice · Dettagliato · Lettera formale** — scegline uno ed estendilo. Ogni modello di fattura porta già le menzioni obbligatorie (§11a).
- L'**anteprima rapida** rende il risultato all'istante nell'app — la tua fattura più recente, o dati di esempio simulati quando non ce n'è (filigranati *dati di esempio*) — senza passare da un PDF; **Anteprima** produce il PDF; **Ripristina** riconsegna il layout integrato come esempio funzionante. Un modello rotto non blocca mai un documento — subentra il layout integrato; la filigrana di annullo, la firma digitale, l'allegato e i numeri di pagina restano fissi.

Variabili di modello (famiglia fatture): `{{ number }}`, `{{ member }}`, `{{ workspace }}`, `{{ workspace_address }}`, `{{ period }}`, `{{ issued }}`, `{{ issued_by }}`, `{{ replaces }}`, `{{ total }}`, `{{ charges }}`, `{{ payments }}`, `{{ voided }}`, `{{ proforma }}`, `{{ copy }}`, `{{ lines }}` (ognuna con `label`, `unit_price`, `qty`, `net`, `vat_rate`, `amount`), `{{ has_vat }}`, `{{ vat }}`, `{{ net_total }}`, `{{ vat_total }}`, `{{ credit_note }}`, `{{ refund_total }}` — e l'insieme legale: `{{ seller_legal_form }}`, `{{ seller_registration }}`, `{{ seller_vat_id }}`, `{{ seller_legal_id }}`, `{{ exemption_reason }}`, `{{ client_address }}`, `{{ client_vat_id }}`, `{{ client_legal_id }}`, `{{ payment_terms }}`, `{{ late_penalty }}`, `{{ recovery_indemnity }}`, `{{ escompte }}`, `{{ insurance }}`, `{{ special_mentions }}`.

### 11d. La suite di report e la biblioteca documenti

- **Accordo finanziario** — ogni prezzo in vigore che si applica a un membro: abbonamento, mezza giornata extra, servizi, pacchetti, supplementi di spazi interi e accessori. Proprietari/admin lo inviano dalla scheda azioni di un membro; ogni membro può vedere in anteprima/scaricare/condividere il proprio da *Finanze → Documenti*.
- **Report dei pagamenti** — tutto ciò che hai pagato, dichiarato o fatto convalidare in un mese: il tuo piccolo bilancio, self-service sulla stessa riga.
- **Report dello spazio** — identità, conteggi della piantina, disponibilità, funzionalità e prezzi: *Impostazioni dello spazio → Report dello spazio*.
- **Biblioteca documenti** — *Impostazioni → Documenti*: lo statuto dello spazio, le guide, i bilanci e i verbali, COLLEGATI dal sistema che già usi — Google Drive, OneDrive, SharePoint, Dropbox, Nextcloud o qualsiasi link https (il drive continua a gestire i propri permessi; l'app non conserva mai credenziali altrui). Ogni voce ha un **ruolo di visibilità**: tutti i membri, admin e proprietari, o solo proprietari — applicato lato server, così un membro non scarica nemmeno un elenco che contiene documenti del consiglio. Admin e proprietari curano con il pulsante +; l'interruttore della funzionalità *Biblioteca documenti* attiva il tutto.

## 12. Impostazioni e profilo

La tua schermata personale, dall'alto in basso:

- **Profili** (§1) e la tua **foto** (tocca per cambiare — scegli o rimuovi).
- **Membri** — una scorciatoia verso l'elenco; **WhatsApp** — il tuo numero, visibile agli altri membri solo se lo imposti; **Stato** — una riga libera (40 caratteri) mostrata nell'elenco; **Indirizzo** — il tuo indirizzo postale (stampato sulle tue fatture), il paese e la partita IVA facoltativa.
- **Aiuto** — la guida integrata, nella tua lingua; **Il mio badge** (§8); **Account collegati** — collega un accesso Google al tuo account email; **Documenti** — la biblioteca documenti dello spazio (§11d).
- **Preferenze** — **Lingua** (predefinita di sistema o una delle cinque), **Tema** (sistema / chiaro / scuro), **Scansiona con la fotocamera frontale** (per i tablet a parete).
- **Avanzate** — lo stato delle notifiche push di questo dispositivo, l'interruttore della **Modalità sviluppatore** a livello di spazio e la schermata delle tracce **Sviluppatore** (§8 pagamenti).
- **Esci**.

## 13. Notifiche

Promemoria di check-in, conferme in sospeso, decisioni sulle spese — e quando un admin **rimuove una tua prenotazione** (scavalca), tu e gli admin venite avvisati. La consegna è prima locale; i push dal server arrivano senza configurare nulla su Android, iPhone/iPad, browser e macOS (Firebase Cloud Messaging) — *Impostazioni → Avanzate* mostra se il push è attivo su questo dispositivo. Il contatore sull'icona dell'app mostra le tue conferme in attesa **più i tuoi messaggi non letti** — su Android, iPhone/iPad, nel Dock di macOS, nella barra delle applicazioni di Windows e nelle web app installate. I messaggi tra membri vengono annunciati **una volta per dispositivo con il mittente e il testo completo** — compreso ciò che è arrivato ad app chiusa, annunciato alla prossima apertura. I payload push non trasportano mai nomi né orari; l'app compone il testo della notifica localmente.

## 14. Privacy

Dati minimi: nome, email, piano, prenotazioni, conto. Controlli tu la foto, lo stato, se il tuo nome compare sulla piantina e se il tuo numero di telefono è visibile nell'elenco. I badge del chiosco sono salvati solo come hash — un badge perso si revoca, non si indovina. Nessun tracciamento, nessuna analitica di terze parti. Lo storico finanziario viene anonimizzato, non cancellato, all'eliminazione dell'account (obblighi di conservazione contabile).

## 15. Piattaforme

Android (Google Play), iPhone/iPad, desktop — **macOS** (un DMG: trascina DesKilo in Applicazioni) e **Windows** (un installer MSI) prodotti a ogni release — e il **browser**: la stessa app, niente da installare, all'indirizzo che il tuo spazio pubblica. I tuoi dati seguono il tuo account: una postazione prenotata dal telefono compare un secondo dopo in una scheda del browser.

Ciò che il browser non può fare è ciò che a una pagina non è permesso: leggere un badge NFC o scansionare un QR con la fotocamera come fa il chiosco. Tutto il resto — piantina, prenotazioni, membri, finanze, fatture, download dei PDF — è la stessa app. Al primo avvio del DMG macOS fai clic destro sull'app e scegli *Apri*: la build non è ancora notarizzata da Apple, quindi un doppio clic mostra un avviso di Gatekeeper.
