# Guida utente

Tutto ciò che un membro, un admin o un proprietario deve sapere per usare DesKilo.

> Gli screenshot di questa guida mostrano l'app in francese — ogni schermata esiste identica nelle cinque lingue (English, Français, Deutsch, Español, Italiano); cambia lingua in **Impostazioni → Lingua**.

![](assets/help/images/settings-language.jpg)

## 1. Primi passi

### Creare un account

Apri l'app e registrati con email, password (minimo 8 caratteri) e un nome visibile. Il pulsante a occhio mostra o nasconde la password mentre digiti.

### Creare uno spazio — o unirsi a uno

Dopo l'accesso, la schermata di benvenuto offre due strade:

- **Crea uno spazio di lavoro** — ne diventi il **proprietario**. Scegli nome, paese (determina la valuta predefinita) e fuso orario. Poi disegnerai la planimetria nell'editor (§7).
- **Unisciti a uno spazio** — digita l'**ID dello spazio** che ti hanno condiviso, oppure tocca **Scansiona codice QR** e inquadra il QR d'invito appeso alla parete. Ti unisci con il ruolo che l'invito porta con sé (§2).

Un account può appartenere a più spazi; passa dall'uno all'altro in **Impostazioni → Profili**, e **contrassegna con la stella quello predefinito** — è il profilo con cui l'app si apre. Tutto nell'app è riferito allo spazio attivo.

## 2. Ruoli e inviti

DesKilo ha tre ruoli cumulativi, più un account dispositivo:

| Ruolo | Può |
|---|---|
| **Membro** | Fare check-in/out, prenotare, presentare spese, vedere e gestire i propri eventi e il proprio conto |
| **Admin** | Tutto ciò che può un membro, più: agire *per chiunque* (prenotazioni, pagamenti, spese — soggetto a conferma, §6), approvare le spese, emettere badge per il chiosco |
| **Proprietario** | Tutto ciò che può un admin, più: modificare lo spazio fisico, definire piani e prezzi, gestire ruoli, chioschi e impostazioni dello spazio |
| **Comproprietario** | *Attivo*: i permessi del proprietario da subito, più la successione automatica. *Passivo*: un successore in attesa, oggi senza permessi aggiuntivi |
| **Chiosco** | Un account per tablet a parete (§9) — mostra solo la planimetria; i membri agiscono attraverso di esso con un badge |

**Ogni invito è legato a un ruolo.** Nella schermata *ID spazio & QR* del proprietario ci sono due inviti, ciascuno con il proprio QR e il proprio codice:

- **Invito membro** — l'ID dello spazio stesso. Stampalo, appendilo, condividilo liberamente: chi lo scansiona o lo digita entra come semplice membro.
- **Invito admin** — un **codice personale monouso**, emesso da un proprietario per una persona precisa. Ammette solo quella persona come admin, poi scade (un codice inutilizzato decade dopo 14 giorni). Emettine uno nuovo per ogni admin con *Nuovo codice admin*.

**Non esiste un invito proprietario — di proposito.** La proprietà può essere concessa solo da un proprietario esistente, in *Membri e piani*. Uno spazio mantiene sempre almeno un proprietario. Promuovere o retrocedere un **admin** passa dal flusso di validazione (§6) — si applica quando i validatori dello spazio confermano.

**I comproprietari tengono in vita lo spazio.** Il proprietario nomina qualsiasi membro o admin come comproprietario (*Membri e piani → il membro → Comproprietà*), in una di due varianti: un comproprietario **attivo** lavora da subito con i permessi del proprietario; un comproprietario **passivo** non ha permessi aggiuntivi fino al giorno in cui servono. In entrambi i casi la successione è automatica: se l'ultimo proprietario se ne va — esce, viene rimosso, o il suo account scompare — il miglior comproprietario (attivo prima di passivo) **diventa proprietario all'istante**, sul server, senza alcuna azione richiesta. Il proprietario può anche passare la mano deliberatamente in qualsiasi momento con *Promuovi a proprietario ora*. Una sfumatura: le regole di validazione che esigono l'approvazione del *proprietario* (§6) intendono sempre un proprietario vero e proprio, non un comproprietario attivo.

Il QR codifica un link che nomina il ruolo concesso (`deskilo://join?role=…`). Manomettere il link non cambia nulla — il server ricava il ruolo dal codice stesso: l'ID dello spazio fa sempre entrare come membro, e un invito personale fa entrare esattamente nel ruolo con cui è stato emesso, una sola volta. Un codice admin inoltrato già usato — o scaduto — non ammette nessuno.

**Invitare via messaggio** (*Invita qualcuno*): ogni invio WhatsApp/SMS/condivisione emette il proprio codice personale monouso e compone un messaggio pronto nella lingua dell'invitato. Il destinatario può semplicemente copiare l'intero messaggio e incollarlo nel campo di adesione dell'app — il codice viene rilevato automaticamente.

## 3. La planimetria (scheda Piano)

La planimetria mostra il livello attivo del tuo spazio: uffici, tavoli e posti, con codice colore — **libero**, **prenotato**, **occupato**, **mio**, **bloccato**. Si apre **all'istante dagli ultimi dati noti** e si aggiorna in background — con un Wi-Fi instabile vedi comunque lo stato più recente invece di una schermata vuota. I posti occupati mostrano il nome di chi c'è, un **badge di check-in** quando è arrivato, e un **punto verde** quando è online nell'app.

La planimetria può somigliare al tuo spazio reale: il proprietario può mettere una **foto della stanza come sfondo del livello** e piazzare **immagini illustrative ridimensionabili** (piante, divani…) sulla griglia. Un cursore di **trasparenza dei tavoli** nelle impostazioni lascia trasparire la foto sotto i tavoli disegnati.

Muoversi:

- La tela **si adatta da sola** al tuo piano all'apertura o alla rotazione del dispositivo; **pizzica per zoomare** o usa i pulsanti **+ / −**, trascina le **barre di scorrimento** ai bordi e tocca il pulsante di **adattamento** per ricentrare.
- Scegli il piano dal **menu dei livelli** (menu compatto); l'icona dell'orologio riporta la linea temporale a **adesso**.
- In **orizzontale**, i controlli passano in un pannello laterale e la planimetria riempie lo schermo — comodo sui tablet.

Prenotare dalla planimetria:

- **Check-in al volo**: tocca un posto libero → la scheda propone *adesso* fino alla fine predefinita dello spazio → conferma. Se qualcuno ha prenotato quel posto più tardi, la tua ora di fine viene limitata e te lo diciamo.
- **Check-in su prenotazione**: la tua prenotazione apre una finestra di check-in. Fai check-in dalla planimetria o dalla notifica di promemoria. In caso di assenza, il posto viene **liberato automaticamente** dopo il ritardo configurato.
- **Check-out**: manuale, o automatico alla fine della prenotazione / alla chiusura.
- **Spazi interi**: **tocca due volte** un tavolo, una stanza o un tratto libero del pavimento per agire sull'**intero tavolo, ufficio o piano** — la stessa scheda della scansione del suo QR (§4), con lo stesso selettore di periodo e le stesse opzioni di ripetizione di una postazione.
- **Linea temporale**: scegli una finestra da→a (o Mattina / Pomeriggio / Giornata intera, secondo la granularità dello spazio) per vedere l'occupazione in qualsiasi momento futuro.
- I posti possono avere **accessori** (monitor, scrivania regolabile…), alcuni con supplemento per mezza giornata che compare sul tuo estratto.
- Le prenotazioni contano sui tuoi **giorni mensili** (§8) — oltre il tuo piano, l'app blocca o addebita, secondo ciò che il proprietario ha configurato per te.

## 4. Prenotazioni (hub Prenota)

Apri l'hub **Prenota** (pulsante centrale). Una striscia di date sceglie il giorno; i chip di finestra l'orario; poi quattro viste:

- **Piano** — la planimetria filtrata sulla tua finestra; tocca un posto libero per prenotarlo.
- **Giorno** — ogni posto come riga temporale del giorno scelto; tocca un tratto libero per prenotare, il tuo blocco per i dettagli.
- **Settimana** — una griglia posto × giorno dell'intera settimana ISO; trova una mezza giornata libera a colpo d'occhio e toccala per prenotare.
- **Mese** — un calendario di disponibilità: scrivanie libere per giorno su tutti i piani; tocca un giorno per entrare nella sua vista Giorno.

Le prenotazioni seguono la **regola di granularità** dello spazio — mezze giornate, giornate intere, oppure orari liberi sulla griglia di minuti del proprietario. Rispettano i **giorni di apertura** e i **giorni di chiusura**, e le regole di prenotazione (orizzonte, durata massima, termine di cancellazione). Esigenze ricorrenti? Prenota una **serie** (giornaliera, feriale, settimanale) — giorni chiusi e conflitti vengono saltati e segnalati.

La scheda **Calendario** mostra le tue prenotazioni per mese — i tuoi giorni in **rosso**, quelli degli altri in **blu**, oggi cerchiato — con una timeline per giorno. In orizzontale, calendario e timeline usano il layout diviso.

### Scansionare un codice spazio

Ogni postazione, tavolo, ufficio e piano può avere una **scheda QR** stampata (§7). Tocca il **pulsante di scansione** nell'hub Prenota, inquadra la scheda — o digita il suo codice — e l'app identifica lo spazio e mostra esattamente ciò che *tu* puoi farci:

- **Scheda postazione** — prenota o fai check-in su quella precisa postazione, al momento (finestra di oggi: mattina / pomeriggio / giornata intera dove lo spazio usa le mezze giornate, altrimenti da adesso per le prossime ore).
- **Scheda tavolo** — le postazioni del tavolo con il loro stato in tempo reale; scegline una libera.
- **Scheda ufficio o piano** — se il proprietario lo ha reso prenotabile, la funzionalità *Prenotazioni di ufficio e piano* è attiva **e** possiedi il diritto personale (§7), puoi prenotare o fare check-in sull'**intero ufficio o piano** — con lo stesso selettore di periodo (mattina / pomeriggio / giornata intera, o orari liberi) e le stesse opzioni di **serie** di una postazione; il suo prezzo per mezza giornata viene mostrato e finisce sulla tua fattura. Altrimenti la scheda ti spiega perché, e un ufficio ripiega sulle sue postazioni.

**I conflitti proteggono in entrambe le direzioni:** un ufficio o un piano non può essere prenotato mentre una postazione al suo interno è già prenotata in quella finestra — e nessuna postazione può essere prenotata mentre il suo ufficio o piano è prenotato per intero.

## 5. Elenco dei membri (scheda Membri)

Guarda chi fa parte della tua comunità:

- Ogni scheda membro mostra **foto** (o iniziale), **ruolo**, **stato personalizzato** («a Berlino fino a venerdì…»), un indicatore **online / ultimo accesso**, e un **chip di prenotazione**: posto con check-in, prenotato adesso, o prossima prenotazione.
- Tocca un membro per la sua **scheda di dettaglio** — incluse le prossime prenotazioni.
- **Scorri** su un membro per scrivergli su **WhatsApp**; il **pulsante gruppo** apre il gruppo WhatsApp della comunità (impostato dal proprietario).
- Imposta foto, stato e visibilità del telefono in **Impostazioni**.

## 6. Eventi e conferme (icona campanella)

Il flusso eventi è la traccia di controllo dello spazio: prenotazioni create/modificate/cancellate, pagamenti registrati, spese presentate, richieste di giorni extra, cambi di ruolo. I membri vedono i propri eventi; admin e proprietari vedono tutto.

**Il protocollo di conferma:** quando un admin fa qualcosa *per qualcun altro* — ti prenota un posto, registra il tuo pagamento — resta **in sospeso finché non confermi**. Le voci in sospeso sono fissate in alto con pulsanti accetta/rifiuta e ricevi una notifica. Le azioni su te stesso non richiedono mai conferma.

**Quorum di validazione:** per le questioni di denaro e i cambi di ruolo il proprietario definisce *chi* deve approvare e *quante* approvazioni servono. Le richieste senza risposta scadono dopo 7 giorni — nulla di costoso viene mai concesso in silenzio.

Il proprietario regola tutto questo per **dominio** in **Impostazioni → Regole di validazione**: pagamenti, spese, servizi, mezze giornate extra, cambi di ruolo, prenotazioni e rettifiche hanno ciascuno la propria regola (o ereditano quella predefinita). Una regola stabilisce il numero di validazioni richieste, *quali* admin possono validare (tutti, o alcuni nominati) e se il proprietario deve sempre dare l'approvazione finale.

![](assets/help/images/validation-rules.jpg)

 

![](assets/help/images/validation-rule-edit.jpg)

*A sinistra: una regola per dominio, che eredita da quella predefinita. A destra: la modifica di una regola — validazioni richieste, validatori autorizzati, approvazione del proprietario.*

## 7. Per i proprietari: editor e impostazioni

Tutta l'amministrazione vive in **Impostazioni → Amministrazione**. Una sola regola da conoscere: **la voce di impostazioni di una funzionalità appare solo finché quella funzionalità è attiva** — disattiva *Pagamenti online* in **Funzionalità** e la sua schermata di configurazione scompare con essa (e ritorna quando la riattivi). La voce **Funzionalità** è sempre presente, così puoi sempre riattivare un modulo.

![](assets/help/images/settings-administration.jpg)

- **Editor** (barra dell'app): disegna il tuo spazio su una griglia — livelli, uffici, tavoli, posti (con orientamento, tipo di sedia e dotazioni), blocco posti per manutenzione. Aggiungi una **foto di sfondo** per livello e **immagini illustrative** spostabili e ridimensionabili. Eliminare qualcosa con prenotazioni future obbliga prima a risolverle.
- **ID spazio & QR**: i tuoi inviti legati ai ruoli (§2). Puoi sostituire l'ID generato con uno memorizzabile (4–20 lettere/cifre), copiarlo, o condividere il QR come PNG.
- **Disponibilità**: giorni di apertura, giorni di chiusura e granularità — orari liberi di inizio/fine, una griglia di minuti (5/15/30/60), mezze giornate o solo giornate intere.
- **Funzionalità**: attiva o disattiva interi moduli per spazio — calendario, eventi, denaro, servizi, esportazione PDF, serie, prenotare per altri, push, blocco posti da parte degli admin, supplementi accessori, **pagamenti online**, **fatture**, **prenotazioni di ufficio e piano**, **modalità chiosco**, **badge RFID/NFC**, **elenco dei membri**, **integrazione WhatsApp**, **codici QR degli spazi**, **comproprietari**. Disattivare un modulo rimuove *tutte* le sue schermate e i suoi pulsanti per ogni membro.

  L'elenco è **gerarchico**: una funzionalità che ne richiede un'altra compare rientrata sotto di essa con una nota *Richiede…*, ed è in grigio finché la funzionalità madre è disattivata — *Denaro* porta con sé servizi, supplementi accessori, pagamenti online e fatture; *Prenotazioni di ufficio e piano* porta il diritto di assegnazione degli admin; *Modalità chiosco* porta i badge RFID/NFC; *Elenco dei membri* porta l'integrazione WhatsApp. Disattivare una funzionalità madre toglie dall'app tutto il suo sottoalbero; la scelta salvata della funzionalità figlia torna intatta quando la madre riappare.

![](assets/help/images/workspace-id-qr.jpg)

 

![](assets/help/images/availability-granularity.jpg)

 

![](assets/help/images/features-toggles-1.jpg)

 

![](assets/help/images/features-toggles-2.jpg)

- **Membri e piani**: tocca un membro per aprire la sua **scheda di gestione** — aggiungi un servizio per lui, imposta la sua percentuale di abbonamento, scegli la sua **politica di consumo extra** (§8), limita le sue **prenotazioni simultanee**, emetti i **badge** (§9), promuovi/retrocedi admin, trasforma l'account in un dispositivo **chiosco**, o metti in pausa l'iscrizione.

![](assets/help/images/member-management-sheet.jpg)

 

![](assets/help/images/member-subscription.jpg)

 

![](assets/help/images/member-reservation-limit.jpg)

*La scheda di gestione, la finestra della percentuale di abbonamento e il limite di prenotazioni per membro.*

- **Fatturazione**: fasce tariffarie degli abbonamenti percentuali, tariffe di extra, livelli di abbonamento offerti (con un valore libero negoziato opzionale) — e **pacchetti di giorni** (un numero di giorni a un prezzo) per i membri con politica a pacchetto.
- **Servizi** e **Accessori**: i cataloghi dietro il §8 — extra definiti dal proprietario (armadietti, stampe…) e dotazioni per posto con supplementi opzionali per mezza giornata. Entrambi sono semplici elenchi con un pulsante **+**.

![](assets/help/images/billing-bands-levels-packages.jpg)

 

![](assets/help/images/services-catalog.jpg)

 

![](assets/help/images/services-new-service.jpg)

 

![](assets/help/images/accessories-catalog.jpg)

*Fatturazione (fasce, livelli, pacchetti di giorni) · il catalogo Servizi con il suo modulo di creazione · il catalogo Accessori. Un admin aggiunge un consumo di servizio per un membro dalla sua scheda di gestione:*

![](assets/help/images/member-add-service.jpg)

- **Impostazioni dello spazio**: nome, paese/valuta, fuso, istruzioni di pagamento (IBAN, PayPal.me, Wero, Lydia, Wise), link del gruppo WhatsApp, **trasparenza dei tavoli**, esportazioni — e la **zona pericolosa**: un **reset completo dello spazio** (elimina prenotazioni, denaro e planimetria; conserva configurazione e membri), protetto digitando «I agree».
- **Import/export**: l'intera configurazione viaggia come **file XML** — backup, modello o migrazione di un'istanza self-hosted. Si può generare anche un **PDF di configurazione** (membri, planimetria, prezzi, funzionalità). Ogni esportazione finisce nella cartella **Download** del tuo dispositivo.

### Codici QR degli spazi e prenotazioni di spazi interi (proprietari)

Quattro passi trasformano «scansiona il codice sul tavolo» nel flusso di prenotazione quotidiano (§4):

1. Nell'**editor**, marca un ufficio o un piano come **Prenotabile per intero** e assegnagli un **prezzo per mezza giornata** (la scheda proprietà dell'ufficio / il menu del livello).
2. Attiva **Prenotazioni di ufficio e piano** in **Funzionalità** (disattivata per impostazione predefinita).
3. Concedi a ogni membro autorizzato **«Può prenotare un ufficio o un piano intero»** — proprietari e admin lo impostano nella scheda di gestione del membro, mai per se stessi.
4. Stampa le schede: **Impostazioni dello spazio → Codici QR degli spazi (PDF)** — un QR formato carta di credito per **postazione, tavolo, ufficio e piano**, dieci per pagina A4, salvato in Download. Ritagliale e attacca ogni scheda sul suo spazio.

Una prenotazione di ufficio copre **tutti i tavoli al suo interno**; una prenotazione di piano copre l'intero piano. Entrambe sono possibili solo finché nulla all'interno è prenotato — e compaiono come righe a sé sulla fattura del membro.

### Comproprietari (proprietari)

Fai in modo che la comunità non dipenda mai da un solo account:

1. Apri *Membri e piani → il membro → **Comproprietà*** e scegli **attivo** (permessi da proprietario subito) o **passivo** (successore in attesa).
2. Passa la mano in qualsiasi momento con ***Promuovi a proprietario ora*** — il comproprietario diventa proprietario a pieno titolo accanto a te.
3. Se l'ultimo proprietario lascia lo spazio, il miglior comproprietario viene **promosso automaticamente** sul server — attivo prima di passivo. Questa rete di sicurezza funziona anche mentre l'interruttore della funzionalità *Comproprietari* è disattivato (l'interruttore nasconde solo i pulsanti di nomina).

### Configurare i pagamenti online (proprietari)

Ogni comunità incassa sul **proprio** account del fornitore; l'app non conserva mai le chiavi segrete su alcun dispositivo — restano sul server.

1. Apri **Impostazioni → Pagamenti online** (solo proprietario).
2. Scegli un fornitore e incolla le sue chiavi dal suo pannello:
   - **PayPal** — Client ID, Secret, Ambiente (inizia con *sandbox*), ID webhook, URL di ritorno (PayPal Developer → la tua app REST).
   - **Carta (Stripe)** — Chiave segreta, Segreto di firma webhook, URL di ritorno (Stripe → chiavi API / Webhook).
   - **Mollie** — Chiave API, URL di ritorno (offre iDEAL, Bancontact, carte…).
   - **Wero (tramite Mollie)** — la stessa chiave API Mollie, con Wero abilitato nel tuo account Mollie.
3. **Salva** — appare un chip verde *Configurato*. Attiva la funzione **Pagamenti online** (Impostazioni → Funzionalità) e i membri vedranno **Paga online** su una fattura da saldare. (La voce di impostazioni *Pagamenti online* appare solo finché la funzionalità è attiva.)

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
5. Incolla la Secret key, il signing secret e il tuo URL di ritorno in **Impostazioni → Pagamenti online → Carta (Stripe)**.

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

### Configurare i badge RFID / NFC (proprietari)

Le tessere fisiche permettono il check-in con un tocco — senza telefono.

1. Apri **Impostazioni → Badge RFID / NFC** (solo proprietario). Attiva **Abilita il check-in con badge NFC** e leggi la riga di **stato del dispositivo** — distingue *pronto*, *NFC disattivato nelle impostazioni Android* e *nessun hardware NFC* (gli iPad non ne hanno).
2. Dai una tessera a ogni membro: **Membri e piani → il membro → Badge → Registra tessera**, poi avvicina la sua tessera al dispositivo. Va bene qualsiasi tessera con chip leggibile (MIFARE, NTAG…). I membri possono farlo anche **da soli**: **Impostazioni → Il mio badge** emette il loro badge QR stampabile e registra la loro tessera — senza bisogno di un admin.
3. Usale a un **chiosco** (§9): il membro avvicina la tessera per prenotare o fare check-in. Revoca una tessera persa dalla stessa finestra Badge; **scorri un badge revocato verso destra per eliminarlo** definitivamente.

I badge appartengono a **un solo spazio** — la finestra indica in quale stai registrando, quindi registra la tessera nello spazio il cui chiosco la leggerà. La stessa tessera fisica può servirti in più spazi. Un badge QR salvato **come PDF** stampa dieci copie formato carta di credito su una pagina A4 — scorte incluse.

![](assets/help/images/nfc-config.jpg)

 

![](assets/help/images/member-badges-dialog.jpg)

*La schermata di configurazione NFC (interruttore dello spazio + stato NFC di questo dispositivo) e la finestra Badge di un membro: revoca, registra una tessera, o emetti un nuovo badge QR.*

## 8. Denaro (scheda Denaro)

Il tuo conto risponde a *quanto devo, quanto mi devono* — e *quanto posso ancora prenotare*:

- **Questo mese** — la scheda in cima alla fattura: quanti **giorni** include il tuo abbonamento questo mese, quanti ne hai **usati**, quanti ne **restano**, con barra di avanzamento. Una mattina prenotata conta 0,5 giorni. Il diritto mensile segue i giorni di apertura dello spazio e la tua percentuale.
- **Quando i giorni finiscono**, ciò che accade è una scelta del proprietario, per membro:
  - **Bloccato** (predefinito) — niente più prenotazioni; chiedi a un admin, o richiedi **mezze giornate extra** direttamente dalla scheda Denaro (i validatori approvano; i giorni concessi restano addebitati alla tariffa extra).
  - **A consumo** — continui a prenotare; ogni giorno extra è addebitato alla tariffa extra della tua fascia (mostrata sulla scheda).
  - **Pacchetti** — tocca **Acquista un pacchetto** e scegli uno dei pacchetti di giorni del proprietario; i tuoi giorni aumentano subito e il prezzo finisce sulla fattura del mese.
- **Addebiti**: abbonamento mensile (piano percentuale), extra, consumo di servizi, supplementi accessori, pacchetti di giorni.
- **Accrediti**: spese approvate, pagamenti registrati, rettifiche.
- **Estratti**: mensili, con stato **saldato / da saldare**, esportabili come **fattura PDF** salvata localmente.
- **Fatture**: dove lo spazio emette fatture (più sotto), le tue restano sempre disponibili in **Denaro → Fatture** — toccane una per leggerla nell'app (posizioni, saldo, stato), scarica il PDF e, negli spazi UE, esporta la fattura elettronica leggibile dalle macchine (XML).
- **Pagare**: DesKilo tiene traccia dei pagamenti; una fattura da saldare mostra le **istruzioni di pagamento** dello spazio (l'IBAN si copia con un tocco, PayPal.me si apre direttamente). Registra un pagamento («ho pagato») con il metodo, la **data in cui il denaro si è mosso** (oggi per impostazione predefinita) e il **mese che salda** (quello in corso per impostazione predefinita, un passo indietro per gli arretrati, uno avanti per un anticipo) — l'altra parte conferma. Quel mese decide su quale fattura e su quale estratto conto finisce l'accredito. Se lo spazio ha attivato i **pagamenti online** e il suo server è configurato, il pulsante **Paga online** consente di saldare subito l'importo dovuto — con **PayPal, carta (Stripe), Mollie o Wero**, secondo ciò che lo spazio ha attivato (se più di uno, appare un selettore).
- **Spese**: hai comprato il caffè per lo spazio? Presenta la spesa — un altro admin la approva (niente auto-approvazione) e l'importo viene accreditato sul prossimo estratto.
- **Servizi**: extra definiti dal proprietario (armadietti, stampe…) il cui consumo arriva sul tuo estratto dopo la tua conferma.

### Fatture (proprietari e admin di fatturazione)

*I proprietari emettono le fatture; anche gli admin, quando il proprietario concede la delega **Gli admin emettono fatture**. La funzionalità **Fatture** sta sotto Denaro nell'elenco delle funzionalità (§7).*

Una fattura in DesKilo viene generata, mai composta: le sue posizioni sono **derivate esclusivamente dai dati tracciati del mese** — abbonamento, extra, supplementi, servizi, pacchetti — meno i pagamenti e gli accrediti del mese, così la riga finale **è il saldo dovuto**. Ogni documento fotografa gli indirizzi postali dello spazio e del membro (imposta il tuo in **Impostazioni → Indirizzo**; l'indirizzo dello spazio sta nelle impostazioni dello spazio) ed è **firmato digitalmente** all'emissione — dopo non cambia più. Un **allegato dettagliato** (il libro mastro e le presenze del mese) si aggiunge con un interruttore al momento dell'emissione.

Chi emette apre **Denaro → Fatture** e trova un hub a tre schede sotto una striscia di riepilogo in tempo reale:

- **Da fatturare** — ogni membro il cui mese precedente ha dati fatturabili e nessuna fattura, con il totale del mese: emetti per membro (con l'anteprima delle posizioni derivate) o **Fattura tutto** in un colpo solo — una conferma annuncia prima quante fatture, quale mese e quale totale. **Una sola fattura attiva per membro e mese** — un mese torna fatturabile solo dopo che la sua fattura è stata annullata. Il foglio di emissione si apre sul **mese chiuso** (quello i cui numeri non si muovono più); se scegli il mese in corso ti avvisa, perché un mese si fattura una sola volta.
- **Aperte** — fatture emesse in attesa di saldo, dalle più vecchie; ciò che attende da oltre 30 giorni diventa rosso, sulla scheda e nella striscia di riepilogo. **Tocca una scheda per leggere la fattura**; i pulsanti agiscono su di essa: **Invia un promemoria** (registra il sollecito e condivide il PDF con un messaggio — la scheda mostra *Sollecitato ×N*), **Segna come errata** (annulla la fattura per correggerla: passa nell'archivio barrata, e una **sostitutiva** ri-deriva lo stesso mese dai dati corretti, citando l'originale) e **Segna come pagata**.
- **Archivio** — fatture chiuse, pagate o annullate, filtrabili per membro e mese e ordinabili; sotto i filtri è indicato quante fatture corrispondono e **Azzera i filtri** riporta l'archivio intero. Ogni riga porta stato, mese e importo, con **Scarica PDF** lì accanto. **Tocca una riga per aprire la fattura** — posizioni, saldo, destinatario, stato, quale fattura sostituisce o da quale è stata sostituita, il pagamento che l'ha chiusa, i solleciti inviati, la sua firma — e ogni azione ancora permessa, per nome: condividi il PDF, esporta la **fattura elettronica (XML)**, sollecita, segna come pagata, segna come errata, emetti una sostitutiva.

**Segnare come pagata significa abbinare un pagamento reale.** La finestra elenca i pagamenti registrati del membro — bonifici registrati e pagamenti online confermati — e tu abbini la fattura a uno di essi; non c'è alcun importo da digitare. Ha pagato **di più**? Crea una **nota di credito** per l'eccedenza (un accredito sul libro mastro del membro) oppure forza l'accettazione con una nota obbligatoria. Ha pagato **di meno**? Accettalo con una nota obbligatoria. Tutti coloro che hanno accesso alla fatturazione vengono avvisati delle fatture pagate, e il proprietario può mettere una regola di validazione **Pagamento fattura** (§6): l'abbinamento resta allora in attesa del quorum — un rifiuto riapre la fattura.

**Una fattura pagata è definitiva.** Una volta abbinata non può più essere annullata, sostituita o modificata — le correzioni avvengono prima del pagamento, annullando la fattura aperta ed emettendo la sua sostitutiva. Un pagamento che **non** ha coperto l'intero importo, accettato con una nota, compare come **parzialmente pagata**, non come pagata.

**Proforma.** Entrambe le schede dell'hub offrono una proforma: su **Da fatturare** rende le voci derivate del mese come preventivo — senza numero, senza firma, timbrata PROFORMA, e **non emette nulla**; su **Aperte** rigenera la fattura emessa come richiesta di pagamento che non può passare per l'originale. Sulle schede Aperte ogni azione è un'icona con suggerimento (annulla · proforma · sollecito · segna pagata) — tre etichette affiancate uscivano dalla scheda.

**Timbri.** Una fattura annullata porta un grande **ERRATA** in diagonale su ogni pagina del PDF, in grigio chiaro sopra il contenuto: non si confonde con un documento valido su una scrivania né in fotocopia. Lo stesso timbro dice **PROFORMA** su un preventivo e **COPIA** su ogni fattura generata da qualcuno che non sia chi l'ha emessa — l'originale resta allo spazio.

**Il registro.** L'icona elenco nella barra delle Fatture apre un giornale con una riga per fattura: **data · nome · importo · stato**, ordinato per data (tocca l'intestazione Data per invertire), con il totale in fondo. La colonna *nome* segue chi legge — chi emette scorre i membri, un membro scorre i propri numeri di fattura. I membri vedono solo ciò che li riguarda: le fatture emesse, mai una annullata.

### Dove deve andare la fattura elettronica (UE)

L'azione **Fattura elettronica (XML)** apre un foglio che risponde alla domanda per il paese dello spazio, prima di consegnarti il file: su quale canale la aspettano i clienti business, se una piattaforma si mette in mezzo e su quale canale passano gli enti pubblici. Nell'Unione convivono quattro modelli:

- **Peppol** — un access point consegna il file al cliente; nessuna piattaforma pubblica nel percorso. Così funziona esattamente l'obbligo B2B belga, ed è tramite Peppol che si raggiungono gli enti pubblici in tutta l'UE (la direttiva 2014/55/UE rende ogni amministrazione capace di ricevere una fattura EN 16931).
- **Piattaforme accreditate** — la Francia: scegli una *plateforme agréée* (l'ex PDP), che trasporta la fattura e trasmette i dati all'amministrazione fiscale. Il portale pubblico è un elenco, non una casella. Il settore pubblico resta su **Chorus Pro**.
- **Piattaforme di clearance** — l'Italia (**SdI**, FatturaPA), la Polonia (**KSeF**, FA(3)), la Romania (**RO e-Factura** tramite l'SPV, CIUS-RO): la piattaforma riceve la fattura *per prima* e poi la inoltra; l'invio diretto al cliente non esiste. Ognuna impone la propria sintassi, perciò il foglio avvisa che il file EN 16931 esportato da DesKilo non è quello accettato — usalo per Peppol, la pubblica amministrazione e i clienti esteri, e lascia convertire alla tua piattaforma o al tuo commercialista.
- **Nessun canale imposto** — la Germania oggi: ricevere è obbligatorio dal 2025 ed emettere arriva a scaglioni, ma un allegato via e-mail è una fattura elettronica valida; le sintassi attese sono XRechnung e ZUGFeRD. Settore pubblico: **OZG-RE / ZRE**, oppure Peppol.

DesKilo non trasmette mai nulla da sé — produce il file, a inviarlo sei tu o la tua piattaforma.

**Prima della prima esportazione, compila l'identità legale.** In *Impostazioni dello spazio → **Identità legale e fatturazione elettronica*** il proprietario dichiara il **regime IVA** e il numero che la norma richiede con esso: fuori campo IVA, un **numero di registrazione** (SIREN, HRB, CIF…); in regime di esenzione, una **partita IVA** e il motivo del mancato addebito. I membri aggiungono il proprio **paese** — e la partita IVA se fatturano come impresa — accanto all'indirizzo in *Impostazioni → Indirizzo*. DesKilo verifica tutto questo **prima** di produrre il file e rifiuta indicando ciò che manca: una fattura rifiutata dalla piattaforma è peggio di nessuna fattura. Uno spazio **soggetto IVA** non può ancora esportare: DesKilo non calcola l'IVA per voce e non dichiarerà uno zero in cui non crede. Il PDF non è mai interessato.

Anche i calendari si spostano: verifica con la tua amministrazione prima della scadenza che ti riguarda.

## 9. Modalità chiosco (tablet a parete)

Monta un tablet Android o un iPad vicino alla porta e lascia che le persone facciano check-in entrando:

1. Il proprietario crea un account normale per il dispositivo, lo unisce allo spazio e lo marca come **chiosco** in *Membri e piani*.
2. **La modalità chiosco non parte mai da sola.** A ogni avvio dell'app il tablet chiede *Avviare la modalità chiosco?* — conferma e il tablet si blocca: solo la planimetria a schermo intero, pulsante indietro disabilitato, l'app si fissa in primo piano così non si può aprire altro; per uscire dalla modalità chiosco bisogna riavviare il tablet. Scegli invece *Non ora* e l'app si apre normalmente — utile per la configurazione. La designazione a chiosco si può revocare in qualsiasi momento: sul dispositivo in **Impostazioni → Dispositivo chiosco**, o dal proprietario in *Membri e piani*.
3. Ogni membro porta con sé un **badge** — emesso da un admin (*Membri e piani → Badge*) o dal membro stesso (**Impostazioni → Il mio badge**, §7): un **badge QR** stampabile e/o la sua **tessera RFID/NFC**.
4. Al chiosco, tocca un posto (o **Questo piano**) → **Check-in**, **Prenota** o **Check-out** → presenta il badge:
   - **Avvicina la tessera RFID/NFC.** Finché il lettore di tessere è armato la fotocamera resta spenta; se l'NFC è disattivato o assente, la scheda lo dice esplicitamente.
   - Oppure tocca **Scansiona il badge QR** — il tablet legge il badge stampato **con la propria fotocamera** (frontale per impostazione predefinita, perché l'obiettivo posteriore di un tablet a parete guarda il muro; cambia in *Impostazioni → Scansiona con la fotocamera frontale*). Funzionano anche un lettore di codici USB/Bluetooth o la digitazione del codice.
5. **Nulla accade senza il tuo consenso:** il chiosco identifica il badge, chiude i lettori e mostra un riepilogo — *chi* ha riconosciuto, *cosa* accadrà, *dove* e *quando*. Solo **Conferma** esegue e aggiorna la planimetria; **Rifiuta** annulla.

La tua identità esiste solo per il tempo dell'operazione: la credenziale va una volta al server, la prenotazione è fatta **a tuo nome**, e nulla resta sul tablet — sei «disconnesso» appena finisce. (L'accesso per singola operazione con Google è ancora nella roadmap; **gli iPad non hanno NFC**, quindi lì la via è il QR con fotocamera.)

## 10. Notifiche

Promemoria di check-in, liberazioni per assenza, conferme in sospeso, decisioni sulle spese. La consegna è prima di tutto locale; su Android la variante F-Droid usa **UnifiedPush** (es. ntfy) al posto dei servizi Google — niente Firebase da nessuna parte.

## 11. Privacy

Dati minimi: nome, email, piano, prenotazioni, conto. Controlli tu la foto, lo stato, se il tuo nome compare sulla planimetria e se il tuo telefono è visibile nell'elenco. I badge del chiosco sono salvati solo come hash — un badge perso si revoca, non si indovina. Nessun tracciamento, nessuna analitica di terze parti. Lo storico finanziario viene anonimizzato, non cancellato, all'eliminazione dell'account (obblighi contabili).

## 12. Piattaforme

Android (Google Play e F-Droid), iPhone/iPad e desktop — macOS, e Windows con un **installer MSI** prodotto a ogni release. I tuoi dati seguono il tuo account.
