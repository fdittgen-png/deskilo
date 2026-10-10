<!-- anchor: user.space.overview -->
## Il suo spazio, configurato da Lei (Impostazioni dello spazio)

Questo capitolo è per chi gestisce uno spazio: proprietari, comproprietari e gli amministratori a cui affidano le impostazioni. Qui disegna i piani, decide chi può entrare e quando, sceglie quali funzionalità esistono, dà allo spazio il suo aspetto e le sue parole, e ne prende una copia completa.

In questo capitolo:
- [Disegnare piani, stanze e scrivanie](help:user.space.editor.levels)
- [Invitare le persone con l'ID dello spazio di lavoro](help:user.workspace.code)
- [Indicare quando lo spazio è aperto](help:user.workspace.availability.open-weekdays)
- [Attivare e disattivare le funzionalità](help:user.features.processes)
- [Compilare le impostazioni dello spazio di lavoro](help:user.workspace.settings.country)
- [Dare allo spazio i suoi colori e le sue parole](help:user.workspace.settings.wording)
- [Decidere chi può fare che cosa](help:user.roles.matrix)
- [Gestire un tablet a muro e i badge](help:user.kiosk.mode)
- [Tenere una biblioteca di documenti](help:user.documents.add)
- [Esportare e importare lo spazio](help:user.workspace.export.space-xml)

> **Consiglio** La maggior parte delle schermate di questo capitolo si trova nel menu sotto **Spazio di lavoro**, **Disponibilità**, **Funzionalità** e **Ruoli**. Ogni voce compare solo a chi ha il permesso necessario, e alcune solo finché la loro funzionalità è attiva. Un amministratore vede queste schermate solo se il proprietario gli ha dato il permesso nella matrice dei ruoli.

<!-- anchor: user.space.editor.levels -->
### Editor dello spazio: aggiungere, rinominare ed eliminare piani

**Destinatari:** Proprietario · Amministratore

Vuole dare all'edificio i suoi piani, nell'ordine che le persone si aspettano. L'**Editor dello spazio** elenca tutti i piani dello spazio.

<p><img src="images/user-space-editor-levels.it.jpg" width="280"></p>

**Passaggi**

1. Apra [Editor dello spazio](app:/editor), oppure tocchi **Modifica spazio** nella schermata Prenota.
2. Tocchi **Aggiungi piano**, digiti il nome e tocchi **Salva**.
3. Trascini la maniglia a sinistra di un piano per cambiarne l'ordine.
4. Tocchi i tre puntini (**Azioni del piano**) per **Rinomina** o **Elimina** un piano.
5. Tocchi un piano per disegnarci sopra.

**Da sapere**

- Eliminare un piano rimuove tutti gli uffici, le scrivanie e i posti che contiene. La conferma indica che cosa succede alle prenotazioni che li riguardano.
- La riga sotto ogni piano indica se è **Prenotabile per intero** o **Non prenotabile per intero**.
- Senza alcun piano l'editor mostra **Ancora nessun piano. Aggiungi il primo piano del tuo spazio.**

**Vedi anche:** [Prenotare un intero piano](help:user.space.editor.level-booking) · [Disegnare stanze, scrivanie e posti](help:user.space.editor.rooms)

<!-- anchor: user.space.editor.level-booking -->
### Permettere ai membri di prenotare un intero piano

**Destinatari:** Proprietario · Amministratore

Vuole che una squadra possa prendere un piano completo per un giorno.

<p><img src="images/user-space-editor-level-booking.it.jpg" width="280"></p>

**Passaggi**

1. Nell'[Editor dello spazio](app:/editor), tocchi il pulsante dei livelli sulla riga del piano.
2. Attivi **Prenotabile per intero**.
3. Digiti il **Prezzo per mezza giornata**.
4. Tocchi **Salva**.

**Da sapere**

- Il pulsante dei livelli è pieno quando il piano è prenotabile per intero.
- Prenotare un intero piano, ufficio o scrivania richiede anche la funzionalità **Prenotazioni di tavolo, ufficio e piano**. Ogni membro deve avere il diritto di prenotare un piano; gli amministratori lo hanno automaticamente. Vedi [Un interruttore di funzionalità](help:user.features.switch).

**Vedi anche:** [Proprietà di uffici e scrivanie](help:user.space.editor.office)

<!-- anchor: user.space.editor.rooms -->
### Disegnare stanze, scrivanie e posti

**Destinatari:** Proprietario · Amministratore

Vuole che la piantina sullo schermo assomigli al piano reale. Tutto sta dentro una stanza: disegna una stanza, ci mette le scrivanie, poi mette i posti sulle scrivanie.

<p><img src="images/user-space-editor-rooms.it.jpg" width="280"></p>

**Passaggi**

1. Apra un piano dall'[Editor dello spazio](app:/editor). Un piano vuoto propone **Disegna la prima stanza**.
2. Tocchi **Ufficio** e trascini sulla griglia per disegnare una stanza.
3. Tocchi **Scrivania** e trascini dentro la stanza per disegnare una scrivania.
4. Tocchi **Posto**, poi tocchi una scrivania per aggiungervi un posto.
5. Tocchi **Immagine**, poi tocchi il punto in cui deve andare un'illustrazione.
6. Tocchi un elemento per selezionarlo. La barra in basso offre **Duplica**, **Proprietà** ed **Elimina**.

**Da sapere**

- Toccando una seconda volta lo strumento attivo lo si rimette giù, e la tela torna a selezionare.
- L'app rifiuta una forma che *si sovrappone a un elemento esistente* o che *deve trovarsi completamente all'interno di un ufficio*. I posti si possono collocare solo su una scrivania, e una scrivania piena indica **Non c’è più posto su questo tavolo.**
- Il pulsante con l'immagine in alto a destra imposta, sostituisce o rimuove l'**Immagine di sfondo** del piano, per esempio la scansione della piantina reale.
- Eliminare una stanza elimina anche le sue scrivanie e i suoi posti.

**Vedi anche:** [Proprietà del posto](help:user.space.editor.seat) · [Trasparenza dei tavoli](help:user.workspace.settings.desk-transparency)

<!-- anchor: user.space.editor.office -->
### Dare un nome a un ufficio o a una scrivania e fissarne il prezzo

**Destinatari:** Proprietario · Amministratore

Vuole che una stanza o una scrivania abbia un nome proprio e si possa prenotare in blocco.

<p><img src="images/user-space-editor-office.it.jpg" width="280"></p>

**Passaggi**

1. Selezioni l'ufficio o la scrivania sul piano e tocchi **Proprietà**.
2. Modifichi **Nome dell'ufficio** (o **Nome della scrivania**).
3. Attivi **Prenotabile per intero** se qualcuno può riservarlo per intero, con tutto ciò che contiene.
4. Digiti il **Prezzo per mezza giornata** che compare.
5. Tocchi **Salva**.

**Da sapere**

- Il campo del prezzo compare solo finché l'interruttore è attivo.
- Una stanza prenotabile per intero si può riservare solo finché nulla al suo interno è prenotato.

**Vedi anche:** [Prenotare un intero piano](help:user.space.editor.level-booking) · [Proprietà del posto](help:user.space.editor.seat)

<!-- anchor: user.space.editor.seat -->
### Configurare un posto

**Destinatari:** Proprietario · Amministratore

Vuole che un posto indichi in che direzione guarda la sedia, che cosa lo accompagna e quando è fuori servizio.

<p><img src="images/user-space-editor-seat.it.jpg" width="280"></p>

**Passaggi**

1. Selezioni il posto sul piano e tocchi **Proprietà**.
2. Modifichi **Nome del posto**.
3. Scelga la **Direzione di seduta**: la freccia mostra in che direzione guarda la sedia sulla piantina.
4. Scelga un **Tipo di sedia**.
5. Tocchi gli **Accessori** che appartengono a questo posto. Un prezzo accanto a un accessorio è un supplemento per mezza giornata.
6. Se il posto ha un tag, digiti il suo numero in **Tag NFC/RFID**, oppure usi **Leggi un tag ora**. Il campo del tag compare quando la funzionalità **Tag NFC/RFID delle sedie** è attiva, e la lettura richiede un dispositivo in grado di leggere i tag.
7. Attivi **Bloccato (manutenzione)** per mettere il posto fuori servizio, poi tocchi **Salva**.

**Da sapere**

- Il numero di un tag può appartenere a una sola sedia: **Questo tag è già collegato a un'altra sedia.**
- Se non c'è ancora alcun accessorio, la scheda propone **Nessun accessorio — configurali**.

**Vedi anche:** [Check-in con badge NFC](help:user.badges.nfc)

<!-- anchor: user.workspace.code -->
### L'ID dello spazio di lavoro

**Destinatari:** Proprietario · Amministratore

Vuole che le persone trovino il suo spazio e chiedano di unirsi. La schermata **ID dello spazio e QR** mostra l'invito per i membri: un codice QR e l'ID che contiene.

<p><img src="images/user-workspace-code.it.jpg" width="280"></p>

**Passaggi**

1. Apra [ID dello spazio e QR](app:/workspace-code). Viene mostrata la scheda **Invito membro**.
2. Tocchi **Copia ID** per incollare l'ID dove vuole, oppure **Condividi come PNG** per stampare o affiggere il codice QR.
3. Per scegliere un ID facile da ricordare, tocchi **Cambia l'ID dello spazio**, digiti da 4 a 20 lettere o cifre e tocchi **Salva**.

**Da sapere**

- L'ID è unico in tutto DesKilo. Se è già in uso, o non ha da 4 a 20 lettere o cifre, l'app indica *ID rifiutato*.
- Chi scansiona il codice o digita l'ID chiede di unirsi come membro. Nessuno entra senza approvazione.
- Quando cambia l'ID, il vecchio smette di funzionare. Stampi di nuovo il codice QR.
- La scheda **Invito amministratore** è riservata a proprietari e comproprietari.

**Vedi anche:** [Invito amministratore](help:user.workspace.code.admin) · [Invitare qualcuno](help:user.workspace.code.invite)

<!-- anchor: user.workspace.code.admin -->
### Invitare un amministratore

**Destinatari:** Proprietario

Vuole coinvolgere una persona che l'aiuterà a gestire lo spazio. La scheda **Invito amministratore** le dà un codice per una sola persona.

<p><img src="images/user-workspace-code-admin.it.jpg" width="280"></p>

**Passaggi**

1. Apra [ID dello spazio e QR](app:/workspace-code) e tocchi **Invito amministratore**.
2. Consegni il codice, o il suo QR, alla persona a cui è destinato.
3. Per il prossimo amministratore, tocchi **Nuovo codice amministratore**.

**Da sapere**

- Il codice ammette una sola persona come amministratore, poi scade.
- Non esiste un invito per proprietari. Solo un proprietario può concedere la proprietà, in **Membri e piani**.

**Vedi anche:** [L'ID dello spazio di lavoro](help:user.workspace.code) · [La matrice dei ruoli](help:user.roles.matrix)

<!-- anchor: user.workspace.code.invite -->
### Invitare qualcuno con un messaggio

**Destinatari:** Proprietario · Amministratore

Vuole inviare un invito cordiale e già pronto invece di un semplice codice.

<p><img src="images/user-workspace-code-invite.it.jpg" width="280"></p>

**Passaggi**

1. In [ID dello spazio e QR](app:/workspace-code), tocchi **Invita qualcuno**.
2. Compili **Nome (facoltativo)**, **Cognome (facoltativo)** e, se vuole, il numero di telefono.
3. Sotto **Ruoli all'arrivo**, tocchi i ruoli che questa persona deve ricevere quando si unisce.
4. Scelga la **Lingua del messaggio**.
5. Lo invii con **WhatsApp**, **SMS** o **Condividi…**.

**Da sapere**

- Il messaggio spiega i passaggi: scaricare l'app, creare un account, unirsi. È scritto nella lingua che sceglie e parte da quella impostata come [Lingua dello spazio](help:user.workspace.settings.language).
- Ogni messaggio porta il suo codice personale. Può scrivere un testo suo sotto [Messaggio d'invito](help:user.workspace.settings.invitation-message).

**Vedi anche:** [L'ID dello spazio di lavoro](help:user.workspace.code)

<!-- anchor: user.workspace.availability.open-weekdays -->
### Giorni di apertura

**Destinatari:** Proprietario · Amministratore con il permesso

Vuole che lo spazio sia aperto solo nei giorni in cui lavorate. La schermata **Disponibilità** inizia con i giorni della settimana.

<p><img src="images/user-workspace-availability--open-weekdays.it.jpg" width="280"></p>

**Passaggi**

1. Apra [Disponibilità](app:/availability).
2. Sotto **Giorni di apertura**, tocchi un giorno per aprirlo o chiuderlo.

**Da sapere**

- Almeno un giorno della settimana deve restare aperto.
- Una prenotazione che tocca un giorno chiuso viene rifiutata, e la piantina disegna quel giorno come chiuso.

**Vedi anche:** [Giorni di chiusura](help:user.workspace.availability.closure-days) · [Granularità](help:user.workspace.availability.granularity)

<!-- anchor: user.workspace.availability.granularity -->
### Granularità

**Destinatari:** Proprietario · Amministratore con il permesso

Vuole che le prenotazioni seguano un ritmo adatto al suo spazio: mezze giornate, giornate intere o l'orario che preferisce.

<p><img src="images/user-workspace-availability--granularity.it.jpg" width="280"></p>

**Passaggi**

1. Apra [Disponibilità](app:/availability).
2. Sotto **Granularità delle prenotazioni**, scelga la forma di una prenotazione.

**Da sapere**

- Le scelte sono **Fascia oraria libera**, **Slot di 5 minuti**, **Slot di 15 minuti**, **Slot di 30 minuti**, **Slot di 1 ora**, **Mezze giornate (mattina e pomeriggio)**, **Solo giornate intere** e **Orari reali (da–a esatto, mezze/giornate come scorciatoie)**. **Orari reali** compare quando la funzionalità **Orario di lavoro** è attiva.
- La piantina, la scheda di prenotazione, un codice scansionato e il chiosco offrono solo ciò che la granularità consente.

**Vedi anche:** [Orari di lavoro](help:user.workspace.availability.working-hours)

<!-- anchor: user.workspace.availability.working-hours -->
### Orari di lavoro

**Destinatari:** Proprietario · Amministratore con il permesso

Vuole che una mattina, un pomeriggio e una giornata significhino la stessa cosa ovunque.

<p><img src="images/user-workspace-availability--working-hours.it.jpg" width="280"></p>

**Passaggi**

1. Apra [Disponibilità](app:/availability).
2. Sotto **Orari di lavoro**, tocchi **Inizio giornata**, **Limite di mezza giornata** e **Fine giornata** e imposti ogni orario.
3. Con la granularità *Orari reali*, imposti anche **Ore fatturate come mezza giornata** e **Ore fatturate come giornata intera**.

**Da sapere**

- Le fasce di mezza giornata e di giornata intera nelle prenotazioni, nel check-in e nella fatturazione seguono questi orari.
- La piccola etichetta sotto il titolo indica se gli orari sono quelli predefiniti del prodotto, provengono da un modello o sono i suoi. **Ripristina il modello** e **Ripristina il valore predefinito** li riportano indietro.
- La giornata deve procedere in ordine: inizio, poi limite di mezza giornata, poi fine.
- Questa sezione fa parte della funzionalità **Orari di lavoro**.

**Vedi anche:** [Fuori dagli orari di apertura](help:user.workspace.availability.outside-hours)

<!-- anchor: user.workspace.availability.closure-days -->
### Giorni di chiusura

**Destinatari:** Proprietario · Amministratore con il permesso

Vuole chiudere lo spazio per una festa, una settimana d'agosto o il giorno in cui viene l'idraulico, senza che nessuno prenoti.

<p><img src="images/user-workspace-availability--closure-days.it.jpg" width="280"></p>

**Passaggi**

1. Apra [Disponibilità](app:/availability) e vada a **Giorni di chiusura**.
2. Tocchi **Aggiungi giorno di chiusura**, scelga la data e, se vuole, un **Motivo (facoltativo)**.
3. Per rimuoverne uno, tocchi il cestino accanto.

**Da sapere**

- Una prenotazione in un giorno di chiusura viene rifiutata e il motivo viene mostrato.
- I giorni già fatturati non possono essere trasformati in giorni di chiusura dal generatore dei giorni festivi.

**Vedi anche:** [Giorni festivi](help:user.workspace.availability.public-holidays)

<!-- anchor: user.workspace.availability.public-holidays -->
### Giorni festivi

**Destinatari:** Proprietario · Amministratore con il permesso

Vuole inserire in un colpo solo i giorni festivi di un intero anno come giorni di chiusura.

**Passaggi**

1. In [Disponibilità](app:/availability), sotto **Giorni di chiusura**, tocchi **Aggiungi i giorni festivi**.
2. Usi le frecce per scegliere l'anno. La scheda elenca le date che diventerebbero giorni di chiusura.
3. Tocchi il pulsante in basso per crearli.
4. Preferisce un elenco di dati aperti? Tocchi **Importa i giorni festivi (dati aperti)**, scelga la regione e confermi.

**Da sapere**

- Nulla viene creato prima della sua conferma, e i giorni già presenti sono contrassegnati.
- I mesi già fatturati vengono saltati.
- Queste voci compaiono quando la funzionalità **Giorni festivi** è attiva. **Importa i giorni festivi (dati aperti)** richiede anche la funzionalità **Importa i giorni festivi**.

**Vedi anche:** [Giorni di chiusura](help:user.workspace.availability.closure-days)

<!-- anchor: user.workspace.availability.policies -->
### Regole di prenotazione

**Destinatari:** Proprietario · Amministratore con il permesso

Vuole allentare o rendere più severe le regole di prenotazione. Ciò che imposta qui vale per ogni modo di prenotare: l'app, un codice scansionato e il chiosco.

<p><img src="images/user-workspace-availability--policies.it.jpg" width="280"></p>

**Passaggi**

1. Apra [Disponibilità](app:/availability) e vada a **Regole di prenotazione**.
2. Attivi o disattivi le regole che desidera.
3. Sotto **Fuori dagli orari di apertura** e **Limiti di prenotazione**, imposti il resto.

**Da sapere**

- I due interruttori sono disattivati per impostazione predefinita.
- Questa sezione fa parte della funzionalità **Regole di prenotazione**.
- La riga **Cosa distingue la pianta** sotto spiega gli stati che i membri vedono sulla piantina.

**Vedi anche:** [Consentire prenotazioni passate](help:user.workspace.availability.allow-past) · [Gli amministratori possono fare il check-out dei membri](help:user.workspace.availability.admin-checkout) · [Limiti di prenotazione](help:user.workspace.availability.limits)

<!-- anchor: user.workspace.availability.allow-past -->
### Consentire prenotazioni passate

**Destinatari:** Proprietario · Amministratore con il permesso

Vuole che i membri possano registrare una prenotazione a posteriori, per uno spazio che annota le presenze in un secondo momento.

**Passaggi**

1. In [Disponibilità](app:/availability), sotto **Regole di prenotazione**, attivi **Consenti prenotazioni passate**.

**Da sapere**

- Se è disattivato, una prenotazione già terminata in un giorno precedente viene rifiutata.
- Prenotare una fascia precedente nello stesso giorno è sempre consentito.

**Vedi anche:** [Regole di prenotazione](help:user.workspace.availability.policies)

<!-- anchor: user.workspace.availability.admin-checkout -->
### Gli amministratori possono fare il check-out

**Destinatari:** Proprietario · Amministratore con il permesso

Vuole che il personale chiuda la sala la sera e termini i check-in dimenticati.

**Passaggi**

1. In [Disponibilità](app:/availability), sotto **Regole di prenotazione**, attivi **Gli amministratori possono fare il check-out dei membri**.

**Da sapere**

- Se è disattivato, il check-out è strettamente personale.
- Se è attivo, un amministratore può terminare il check-in in corso di un membro.

**Vedi anche:** [Regole di prenotazione](help:user.workspace.availability.policies)

<!-- anchor: user.workspace.availability.outside-hours -->
### Fuori dagli orari di apertura

**Destinatari:** Proprietario · Amministratore con il permesso

Vuole stabilire che cosa succede quando qualcuno arriva presto o si ferma fino a tardi. Una sola risposta vale per ogni granularità.

<p><img src="images/user-workspace-availability--outside-hours.it.jpg" width="280"></p>

**Passaggi**

1. In [Disponibilità](app:/availability), trovi **Fuori dagli orari di apertura**.
2. Scelga **Vietato**, **Solo spontaneo**, **Gratis** o **A pagamento**.

**Da sapere**

- **Vietato**: nulla fuori orario, nessuna prenotazione in anticipo, nessun accesso spontaneo.
- **Solo spontaneo**: i check-in senza prenotazione restano possibili, compreso lo straordinario serale, ma la prenotazione in anticipo fuori orario viene rifiutata.
- **Gratis**: consentito, mai conteggiato e mai addebitato.
- **A pagamento**: consentito e conteggiato come un normale utilizzo, tranne nei giorni in cui il membro ha già una prenotazione ordinaria.
- Una prenotazione che tocca gli orari di lavoro è una prenotazione ordinaria.

**Vedi anche:** [Orari di lavoro](help:user.workspace.availability.working-hours)

<!-- anchor: user.workspace.availability.limits -->
### Limiti di prenotazione

**Destinatari:** Proprietario · Amministratore con il permesso

Vuole stabilire con quanto anticipo si può prenotare, quanto può essere breve o lunga una prenotazione e quante se ne possono avere contemporaneamente.

<p><img src="images/user-workspace-availability--limits.it.jpg" width="280"></p>

**Passaggi**

1. In [Disponibilità](app:/availability), trovi **Prenotazioni simultanee per membro** e usi i pulsanti meno e più.
2. Sotto **Limiti di prenotazione**, imposti **Orizzonte di prenotazione**, **Durata minima** e **Durata massima**.

**Da sapere**

- **Prenotazioni simultanee per membro** è il numero di prenotazioni sovrapposte che un membro può avere. Con 1 si ha un solo posto alla volta.
- Una prenotazione termina nel giorno in cui inizia, quindi una giornata intera è il massimo possibile.
- Il minimo non può superare il massimo, altrimenti nessuna prenotazione verrebbe accettata. La schermata la avvisa.
- Ogni rifiuto indica il limite e il suo valore.

**Vedi anche:** [Regole di prenotazione](help:user.workspace.availability.policies)

<!-- anchor: user.features.processes -->
### Attivare o disattivare interi processi

**Destinatari:** Proprietario · Comproprietario

Vuole una visione d'insieme di ciò che lo spazio sa fare e attivare un'intera area in un colpo solo. La schermata **Funzionalità** si apre con una scheda per ogni processo aziendale.

<p><img src="images/user-features-processes.it.jpg" width="280"></p>

**Passaggi**

1. Apra [Funzionalità](app:/features). Viene mostrata la vista **Processi**.
2. Legga ogni scheda: il suo stato, quanti sottoprocessi sono attivi e quante funzionalità sono attive.
3. Apra una scheda e tocchi **Attiva** o **Disattiva** per l'intero processo o per un sottoprocesso.
4. Legga l'anteprima, poi confermi.

**Da sapere**

- Una scheda è **Attiva** quando tutte le sue funzionalità sono operative, **Parziale** quando solo alcune lo sono, **Disponibile** quando nessuna è ancora attiva e **Richiede attenzione** quando una funzionalità è attiva ma attende un prerequisito disattivato.
- I filtri **Tutti**, **Attiva**, **Disponibile** e **Richiede attenzione** restringono le schede, e **Cerca processi e funzionalità** raggiunge tutto.
- L'anteprima elenca ciò che viene attivato, ciò che è **Necessarie anche** da un altro processo e ciò che è già attivo. Disattivare qualcosa di cui altre funzionalità hanno bisogno viene rifiutato finché non sceglie che cosa ne sarà di loro.

**Vedi anche:** [Un interruttore di funzionalità](help:user.features.switch)

<!-- anchor: user.features.switch -->
### Un interruttore di funzionalità

**Destinatari:** Proprietario · Comproprietario

Vuole attivare o disattivare una singola funzionalità.

<p><img src="images/user-features-switches.it.jpg" width="280"></p>

**Passaggi**

1. Apra [Funzionalità](app:/features) e tocchi **Interruttori**.
2. Trovi la funzionalità con **Cerca funzionalità**, oppure restringa l'elenco con **Modificate** o **Maturità**.
3. Sposti il suo interruttore.

**Da sapere**

- Attivi una funzionalità e ne compare ogni parte: la scheda, il pulsante, il link. La disattivi e non ne resta nulla, nemmeno un link salvato.
- Una funzionalità che ne richiede un'altra sta sotto di essa con **Richiede** e indica *In attesa della funzione qui sopra* finché quella principale è disattivata. La sua scelta viene conservata.
- Attivare una funzionalità può attivare anche ciò che le serve. L'app la avvisa.
- Una funzionalità non ancora verificata come stabile chiede prima una conferma: può cambiare e ha limiti noti.
- Ciò che è già stato fatto resta com'è. Una fattura emessa mentre una funzionalità era attiva conserva ciò che riporta.

**Vedi anche:** [Attivare o disattivare interi processi](help:user.features.processes)

<!-- anchor: user.workspace.settings.country -->
### Paese

**Destinatari:** Proprietario · Amministratore con il permesso

Vuole che lo spazio sappia dove ha sede. **Spazio di lavoro** si apre su **Informazioni generali**.

<p><img src="images/user-workspace-settings--country.it.jpg" width="280"></p>

**Passaggi**

1. Apra [Spazio di lavoro](app:/workspace-settings).
2. Sotto **Informazioni generali**, scelga il **Paese**.
3. Tocchi **Salva** in basso.

**Da sapere**

- Il paese propone la valuta e il fuso orario, e decide quali aliquote IVA vengono offerte.
- **Salva** scrive insieme tutto il modulo. Se nel frattempo qualcuno ha modificato queste impostazioni, non viene salvato nulla e ciò che ha digitato resta sullo schermo.

**Vedi anche:** [Valuta e fuso orario](help:user.workspace.settings.currency-timezone)

<!-- anchor: user.workspace.settings.currency-timezone -->
### Valuta e fuso orario

**Destinatari:** Proprietario · Amministratore con il permesso

Vuole che i prezzi e i giorni siano contati come li conta il suo spazio.

<p><img src="images/user-workspace-settings--currency-timezone.it.jpg" width="280"></p>

**Passaggi**

1. In [Spazio di lavoro](app:/workspace-settings), sotto **Informazioni generali**, scelga la **Valuta**.
2. Cerchi il **Fuso orario** e lo scelga.
3. Tocchi **Salva**.

**Da sapere**

- La valuta viene proposta in base al paese. Può cambiarla.
- Il fuso orario non è un dettaglio estetico: una giornata lavorativa, il limite di mezza giornata e un giorno di chiusura sono tutti contati in base ad esso, perciò un membro all'estero vede la giornata dello spazio e non la propria.

**Vedi anche:** [Paese](help:user.workspace.settings.country)

<!-- anchor: user.workspace.settings.language -->
### Lingua dello spazio

**Destinatari:** Proprietario · Amministratore con il permesso

Vuole che gli inviti e i documenti parlino la lingua della sua comunità.

<p><img src="images/user-workspace-settings--language.it.jpg" width="280"></p>

**Passaggi**

1. In [Spazio di lavoro](app:/workspace-settings), sotto **Informazioni generali**, apra **Lingua dello spazio**.
2. Scelga una lingua, oppure **Lingua dell'app del mittente**.
3. Tocchi **Salva**.

**Da sapere**

- Gli inviti sono scritti per impostazione predefinita in questa lingua.
- Non è la lingua della sua app. Quella cambia solo ciò che vede Lei e si trova nelle sue impostazioni personali.

**Vedi anche:** [Messaggio d'invito](help:user.workspace.settings.invitation-message)

<!-- anchor: user.workspace.settings.address -->
### Indirizzo dell'intestazione

**Destinatari:** Proprietario · Amministratore con il permesso

Vuole il suo indirizzo postale sulla carta che lo spazio invia.

<p><img src="images/user-workspace-settings--address.it.jpg" width="280"></p>

**Passaggi**

1. In [Spazio di lavoro](app:/workspace-settings), sotto **Informazioni generali**, compili **Indirizzo dello spazio**.
2. Tocchi **Salva**.

**Da sapere**

- È un testo libero, stampato così com'è su lettere e fatture.
- L'indirizzo strutturato necessario a una fattura elettronica è una voce separata, sotto l'identità legale.

**Vedi anche:** [Paese](help:user.workspace.settings.country)

<!-- anchor: user.workspace.settings.whatsapp-group -->
### Gruppo WhatsApp

**Destinatari:** Proprietario · Amministratore con il permesso

Vuole che i membri trovino il gruppo WhatsApp della sua comunità.

<p><img src="images/user-workspace-settings-community--whatsapp-group.it.jpg" width="280"></p>

**Passaggi**

1. In [Spazio di lavoro](app:/workspace-settings), apra **Comunità e inviti**.
2. Incolli il link d'invito del gruppo in **Link del gruppo WhatsApp**.
3. Tocchi **Salva**.

**Da sapere**

- Il link deve essere un link d'invito chat.whatsapp.com, altrimenti il campo lo segnala.
- Lo lasci vuoto per non mostrare nulla.

**Vedi anche:** [Messaggio d'invito](help:user.workspace.settings.invitation-message)

<!-- anchor: user.workspace.settings.invitation-message -->
### Messaggio d'invito

**Destinatari:** Proprietario · Amministratore con il permesso

Vuole che gli inviti suonino come Lei, in ogni lingua che usa.

<p><img src="images/user-workspace-settings-community--invitation-message.it.jpg" width="280"></p>

**Passaggi**

1. In [Spazio di lavoro](app:/workspace-settings), apra **Comunità e inviti**.
2. Sotto **Lingua del messaggio**, scelga di quale lingua sta modificando il testo.
3. Scriva il testo. Tocchi un tag come {firstName} o {inviteLink} per inserirlo dove si trova il cursore.
4. Tocchi **Salva**.

**Da sapere**

- Lasci vuoto il campo per usare il messaggio integrato in quella lingua.
- La riga **Lingua del messaggio** indica solo quale bozza è sullo schermo. Non viene salvata e si apre ogni volta sulla lingua dello spazio.
- I tag vengono compilati quando invia un invito. Il codice e il link provengono dall'app, quindi non li incolli Lei.

**Vedi anche:** [Invitare qualcuno con un messaggio](help:user.workspace.code.invite)

<!-- anchor: user.workspace.settings.new-members -->
### Far partire i nuovi membri allo stesso modo

**Destinatari:** Proprietario · Amministratore con il permesso

Vuole che chiunque si unisca inizi con lo stesso abbonamento e con la stessa regola per quando i suoi giorni finiscono.

<p><img src="images/user-workspace-settings-members--defaults.it.jpg" width="280"></p>

**Passaggi**

1. In [Spazio di lavoro](app:/workspace-settings), apra **Nuovi membri**.
2. Imposti la percentuale di **Abbonamento** con i pulsanti meno e più.
3. Scelga **Bloccato una volta esaurito**, **Paga a consumo** o **Deve acquistare un pacchetto**.
4. Tocchi **Salva**.

**Da sapere**

- Finché non sceglie, i nuovi membri partono al 100% con le prenotazioni bloccate una volta esaurito il diritto.
- L'abbonamento di un singolo membro si imposta in seguito, nella pagina del membro.

**Vedi anche:** [L'abbonamento di un membro](help:user.members.subscription)

<!-- anchor: user.workspace.settings.wording -->
### Terminologia

**Destinatari:** Proprietario · Amministratore con il permesso

Vuole che l'app usi le sue parole: un altro nome per un posto, per uno stato sulla piantina, per una scheda.

<p><img src="images/user-workspace-settings-wording.it.jpg" width="280"></p>

**Passaggi**

1. In [Spazio di lavoro](app:/workspace-settings), apra **Aspetto e diciture** e tocchi **Terminologia**.
2. Trovi una parola con **Cerca una parola**, oppure tocchi **Solo modificati** per vedere ciò che ha rinominato.
3. Tocchi la matita accanto e digiti la sua parola, per ogni lingua.

**Da sapere**

- La parola del prodotto resta mostrata sotto la sua, così vede ciò che sostituisce.
- **Azzera** rimuove la sua parola invece di copiare quella del prodotto. Il termine segue allora il prodotto quando la sua terminologia cambia.
- I termini sono raggruppati in base a dove compaiono: **Legenda**, **Lo spazio**, **Navigazione**, **Prenotazione**.

**Vedi anche:** [Colori](help:user.workspace.settings.colours)

<!-- anchor: user.workspace.settings.colours -->
### Colori

**Destinatari:** Proprietario · Amministratore con il permesso

Vuole che l'app porti il suo colore. Ne scelga uno e l'app ne ricava i temi chiaro e scuro.

<p><img src="images/user-workspace-settings-colours--colours.it.jpg" width="280"></p>

**Passaggi**

1. In [Spazio di lavoro](app:/workspace-settings), apra **Aspetto e diciture** e tocchi **Colori**. La riga è presente finché **Colori dello spazio** è attivo nelle funzionalità.
2. Tocchi uno dei colori, oppure digiti un codice come #0F766E in **Colore**.
3. Controlli **Come appare**, in **Chiaro** e in **Scuro**.
4. Tocchi **Salva**. **Colori del prodotto** rimuove i suoi.

**Da sapere**

- L'app mantiene il proprio contrasto. Se un colore risultasse illeggibile da qualche parte, viene rifiutato e la schermata indica la coppia interessata.
- Sotto **Colori delle sale** può aggiungere fino a otto colori suoi per le sale sulla piantina.
- Il marchio DesKilo, i colori degli stati dei posti e il banner di produzione non vengono mai ridisegnati.

**Vedi anche:** [Motivo](help:user.workspace.settings.pattern) · [Simbolo ed emblema](help:user.workspace.settings.branding)

<!-- anchor: user.workspace.settings.pattern -->
### Motivo

**Destinatari:** Proprietario · Amministratore con il permesso

Vuole che il suo spazio si distingua facilmente dagli altri a cui una persona appartiene.

<p><img src="images/user-workspace-settings-colours--pattern.it.jpg" width="280"></p>

**Passaggi**

1. Apra [Colori](app:/settings/colours).
2. Sotto **Motivo**, tocchi **Tinta unita**, **Righe**, **Pois**, **Griglia** oppure **Onde**.

**Da sapere**

- Il motivo disegna il suo colore sulla scheda di questo spazio in Io, sul suo chip e mentre lo spazio si apre.
- Si salva non appena lo tocca.

**Vedi anche:** [Colori](help:user.workspace.settings.colours)

<!-- anchor: user.workspace.settings.branding -->
### Simbolo ed emblema

**Destinatari:** Proprietario · Amministratore con il permesso

Vuole un piccolo segno che rappresenti lo spazio: lettere su un colore, oppure il suo logo.

<p><img src="images/user-workspace-settings-colours--branding.it.jpg" width="280"></p>

**Passaggi**

1. Apra [Colori](app:/settings/colours) e vada a **Simbolo**.
2. Digiti una o due **Lettere**, scelga un colore e tocchi **Salva**.
3. Sotto **Emblema**, tocchi **Scegli un’immagine** per aggiungere il suo logo. **Rimuovi** lo toglie.

**Da sapere**

- Le lettere su un colore sono uniche per ogni spazio di lavoro. Se un altro spazio ha già le stesse, l'app le chiede di cambiare il colore o le lettere.
- L'emblema è mostrato sotto il nome dell'app nel menu e mentre qualcuno apre questo spazio. Viene ridisegnato con una larghezza massima di 512 pixel, e i dettagli propri della foto, come il luogo in cui è stata scattata, non vengono conservati.
- L'emblema non sostituisce mai il logo DesKilo.

**Vedi anche:** [Colori](help:user.workspace.settings.colours)

<!-- anchor: user.workspace.settings.desk-transparency -->
### Trasparenza dei tavoli

**Destinatari:** Proprietario · Amministratore con il permesso

Ha disegnato la piantina sopra una fotografia e vuole che la stanza si veda attraverso i mobili.

<p><img src="images/user-workspace-settings-appearance--desk-transparency.it.jpg" width="280"></p>

**Passaggi**

1. In [Spazio di lavoro](app:/workspace-settings), apra **Aspetto e diciture**.
2. Trascini il cursore **Trasparenza dei tavoli**. Il valore è mostrato come *Opacità*.
3. Tocchi **Salva**.

**Da sapere**

- Abbassi l'opacità perché la foto di sfondo di un piano si veda attraverso i tavoli.
- La porti al 100% quando i posti contano più della stanza.

**Vedi anche:** [Disegnare stanze, scrivanie e posti](help:user.space.editor.rooms)

<!-- anchor: user.workspace.settings.public-page -->
### Pagina pubblica dello spazio

**Destinatari:** Proprietario

Vuole che chi è fuori dal suo spazio lo trovi e veda che cosa offre.

<p><img src="images/user-workspace-settings-public-page.it.jpg" width="280"></p>

**Passaggi**

1. Apra [Pagina pubblica dello spazio](app:/settings/public-page), oppure la tocchi in alto in **Spazio di lavoro**.
2. Attivi **Visibile nella directory pubblica**.
3. Scelga il tipo di ospite e compili **Descrizione**, **Indirizzo pubblico**, **Email pubblica**, **Telefono pubblico** e **Sito web**.
4. Tocchi **Salva e mostra la vista esterna**.

**Da sapere**

- I campi contrassegnati **Dalle informazioni dello spazio** seguono i dati propri dello spazio. **Usa le informazioni dello spazio** li ripristina dopo che li ha modificati.
- **Ripristina tutti i dati pubblici dalle informazioni dello spazio** sostituisce ogni campo che ha un corrispondente nello spazio.
- Gli amministratori possono scegliere da sé se essere mostrati come amministratori pubblici.

**Vedi anche:** [Scoprire e la rete pubblica](help:user.collaborate.discover)

<!-- anchor: user.roles.matrix -->
### La matrice dei ruoli

**Destinatari:** Proprietario · Comproprietario

Vuole decidere quali permessi ha ciascun ruolo. **Ruoli** mostra una scheda per ruolo con una spunta per ogni permesso che possiede.

<p><img src="images/user-roles-matrix.it.jpg" width="280"></p>

**Passaggi**

1. Apra [Ruoli](app:/roles).
2. Sulla scheda di un ruolo, spunti o tolga la spunta a un permesso come **Gestire ruoli e permessi**, **Gestire i membri**, **Modificare le impostazioni dello spazio** o **Emettere fatture e riconciliare pagamenti**.

**Da sapere**

- Ognuno ha esattamente un ruolo di base: Utente, Amministratore, Comproprietario o Proprietario. Gli altri ruoli si aggiungono ad esso e non tolgono mai nulla.
- Il proprietario ha sempre ogni permesso, quindi la sua scheda è bloccata. Un comproprietario può averne meno.
- Chi non può gestire i ruoli vede la matrice in sola lettura, con **Il tuo ruolo** evidenziato.
- Un permesso viene verificato dal server in ogni punto, quindi togliere la spunta lo rimuove ovunque in una volta sola.
- La voce **Ruoli** compare quando la funzionalità **Gestione dei ruoli** è attiva.

**Vedi anche:** [I ruoli definiti da questo spazio](help:user.roles.space) · [Comproprietari](help:user.roles.co-owners)

<!-- anchor: user.roles.space -->
### I ruoli definiti da questo spazio

**Destinatari:** Proprietario · Comproprietario

Vuole ruoli adatti al suo spazio, come un ospite o un contabile, oltre a quelli di base.

<p><img src="images/user-roles-space.it.jpg" width="280"></p>

**Passaggi**

1. In [Ruoli](app:/roles), tocchi **I ruoli di questo spazio**, oppure apra [I ruoli definiti da questo spazio](app:/settings/roles-of-this-space). Questa schermata compare quando la funzionalità **Ruoli definiti da questo spazio** è attiva.
2. Tocchi **Aggiungi un ruolo**.
3. Dia un nome al ruolo, poi scelga **Cosa aggiunge**.
4. Tocchi **Salva il ruolo**.
5. Per assegnarlo a un membro, apra la pagina del membro, trovi **Ruoli** e tocchi **Aggiungi un ruolo**.

**Da sapere**

- Ogni ruolo aggiunge permessi a quelli che i suoi titolari hanno già. Nessuno toglie nulla, e il proprietario conserva sempre ogni permesso.
- Un ruolo che non vuole più può essere messo da parte disattivando **In uso**.
- La chiave del ruolo non cambia mai: le persone che lo hanno vi fanno riferimento.
- Nessuno può assegnare un ruolo a se stesso. Un ruolo che gestisce i ruoli può essere assegnato solo dal proprietario.

**Vedi anche:** [La matrice dei ruoli](help:user.roles.matrix)

<!-- anchor: user.roles.co-owners -->
### Comproprietari

**Destinatari:** Proprietario

Vuole che lo spazio sopravviva se un giorno Lei si facesse da parte.

**Passaggi**

1. Apra [Membri e piani](app:/members) e scelga il membro.
2. Sotto **Comproprietà**, scelga un comproprietario attivo o un successore.
3. Per passare la mano subito, scelga **Promuovi a proprietario ora**.

**Da sapere**

- Un comproprietario attivo ha subito i permessi del proprietario. Un successore, indicato come **Successore**, attende e diventa proprietario quando viene attivato o quando il proprietario se ne va.
- Se se ne va l'ultimo proprietario, il miglior comproprietario diventa automaticamente proprietario, prima l'attivo e poi il successore.
- I comproprietari fanno parte della funzionalità **Comproprietari**.

**Vedi anche:** [Comproprietà](help:user.members.co-ownership) · [La matrice dei ruoli](help:user.roles.matrix)

<!-- anchor: user.kiosk.mode -->
### Modalità chiosco: un tablet a muro per il check-in

**Destinatari:** Proprietario · Amministratore

Vuole un tablet vicino alla porta dove le persone fanno il check-in con un badge.

**Passaggi**

1. Crei un account per il tablet, si unisca allo spazio di lavoro con esso e, in [Membri e piani](app:/members), usi **Trasforma in chiosco** su quel membro.
2. Si assicuri che **Modalità chiosco** sia attiva in [Funzionalità](app:/features).
3. Sul tablet, apra l'app. Chiede **Avviare la modalità chiosco?**. Tocchi **Avvia la modalità chiosco**.
4. Un membro tocca un posto, oppure **Questo piano**, e presenta un badge: una tessera o un codice QR stampato.

**Da sapere**

- La modalità chiosco non si avvia mai da sola. **Non ora — apri l'app normalmente** apre l'app come di consueto, comodo per la configurazione.
- In modalità chiosco il tablet mostra solo la piantina. Per uscirne si riavvia il tablet. Per far tornare l'account un normale membro, usi **Dispositivo chiosco** sotto **Impostazioni** sul dispositivo oppure **Riporta il chiosco a membro** in **Membri e piani**.
- La scheda che si apre indica la regola che segue. In un giorno di chiusura il chiosco mostra subito *Lo spazio è chiuso oggi*.
- Il badge è la conferma: identifica il membro, esegue l'azione e la schermata si svuota per la persona successiva. Un posto occupato da un'altra persona mostra chi lo occupa e rimanda all'app.
- I badge hanno le proprie funzionalità, **Badge RFID / NFC** e i badge QR, entrambe sotto **Modalità chiosco**.
- Un tablet a muro non può essere mostrato qui: il chiosco si avvia solo su un dispositivo contrassegnato come tale.

**Vedi anche:** [Check-in con badge NFC](help:user.badges.nfc) · [Codici QR degli spazi (PDF)](help:user.workspace.export.space-qr)

<!-- anchor: user.badges.nfc -->
### Check-in con badge NFC

**Destinatari:** Proprietario · Amministratore

Vuole che i membri facciano il check-in avvicinando una tessera, senza telefono.

<p><img src="images/user-badges-nfc.it.jpg" width="280"></p>

**Passaggi**

1. Apra [Badge RFID / NFC](app:/nfc-config).
2. Attivi **Abilita il check-in con badge NFC**.
3. Legga la riga **Questo dispositivo**: indica se questo dispositivo può leggere le tessere.
4. Dia a ogni membro una tessera in [Membri e piani](app:/members): apra i badge del membro, tocchi **Registra tessera**, poi avvicini la tessera al retro del dispositivo.

**Da sapere**

- Serve un dispositivo Android con NFC. Gli iPad non hanno NFC, e i badge QR funzionano comunque.
- Il gestore dei badge permette anche di emettere un **Nuovo badge**, di ritirarne uno con **Revoca** e di usare **Salva come PDF** per stamparlo. Un badge revocato può essere eliminato definitivamente.
- **Mi fa accedere** è disattivato per impostazione predefinita: un badge che registra il check-in non fa accedere finché il membro non lo sceglie.
- Ogni membro può anche creare il proprio badge nelle sue impostazioni personali.

**Vedi anche:** [Un tablet a muro per il check-in](help:user.kiosk.mode)

<!-- anchor: user.documents.add -->
### Aggiungere un documento alla biblioteca

**Destinatari:** Proprietario · Amministratore

Vuole riunire in un solo posto statuti, guide, bilanci e verbali per i membri che ne hanno bisogno. La biblioteca contiene link, non file.

<p><img src="images/user-documents-add.it.jpg" width="280"></p>

**Passaggi**

1. Apra [Documenti](app:/documents) e tocchi il pulsante più.
2. Compili **Titolo** e **Link (https://…)**.
3. Scelga **Archiviato su**, **Categoria** e **Visibile a**.
4. Tocchi **Salva**.

**Da sapere**

- La biblioteca richiede la funzionalità **Biblioteca documenti** e il permesso di gestirla.
- Rimuova un documento con il suo cestino: chiede prima **Rimuovere il documento?**
- I membri che possono aprire la biblioteca vedono i documenti consentiti, raggruppati per categoria.

**Vedi anche:** [Titolo del documento](help:user.documents.title) · [Link](help:user.documents.url) · [Visibile a](help:user.documents.role)

<!-- anchor: user.documents.title -->
### Titolo del documento

**Destinatari:** Proprietario · Amministratore

Vuole che i membri riconoscano un documento a colpo d'occhio.

**Passaggi**

1. Nel modulo di aggiunta di un documento, digiti il **Titolo**.

**Da sapere**

- Un documento richiede un titolo e un link https://, altrimenti **Salva** viene rifiutato.
- Lo scriva pensando a chi legge, perché è la riga che vede nella biblioteca.

**Vedi anche:** [Aggiungere un documento alla biblioteca](help:user.documents.add)

<!-- anchor: user.documents.url -->
### Link

**Destinatari:** Proprietario · Amministratore

Vuole che il documento si apra dove già si trova.

**Passaggi**

1. Incolli il link di condivisione del suo drive in **Link (https://…)**.

**Da sapere**

- DesKilo conserva il link, non il file. I diritti di accesso restano gestiti dove si trova il documento.
- Il link deve iniziare con https://.

**Vedi anche:** [Archiviato su](help:user.documents.provider)

<!-- anchor: user.documents.provider -->
### Archiviato su

**Destinatari:** Proprietario · Amministratore

Vuole che i membri vedano dove è conservato il documento.

**Passaggi**

1. Scelga **Archiviato su**: Google Drive, OneDrive, SharePoint, Dropbox, Nextcloud o *Link*.

**Da sapere**

- È un'etichetta con un'icona. Nulla viene recuperato per Lei.

**Vedi anche:** [Link](help:user.documents.url)

<!-- anchor: user.documents.category -->
### Categoria

**Destinatari:** Proprietario · Amministratore

Vuole che la biblioteca si legga come uno scaffale ordinato.

**Passaggi**

1. Scelga una **Categoria**: **Statuto e legale**, **Guide e manuali**, **Bilanci**, **Verbali** oppure **Altri documenti**.

**Da sapere**

- La biblioteca raggruppa i documenti sotto questi titoli e mostra solo un titolo che ha almeno un documento.

**Vedi anche:** [Visibile a](help:user.documents.role)

<!-- anchor: user.documents.role -->
### Visibile a

**Destinatari:** Proprietario · Amministratore

Vuole alcuni documenti per tutti e alcuni solo per il consiglio.

**Passaggi**

1. Scelga **Visibile a**: **Tutti i membri**, **Admin e proprietari** oppure **Solo proprietari**.

**Da sapere**

- Lo fa rispettare il server. Un membro che non può vedere un documento non lo riceve affatto.

**Vedi anche:** [Aggiungere un documento alla biblioteca](help:user.documents.add)

<!-- anchor: user.workspace.export.space-xml -->
### Esportare lo spazio (XML)

**Destinatari:** Proprietario · Amministratore con il permesso

Vuole un file con la piantina e le impostazioni, da conservare come copia di sicurezza, da riutilizzare o da trasferire in un altro spazio.

<p><img src="images/user-workspace-settings-tools--tools.it.jpg" width="280"></p>

**Passaggi**

1. Apra [Spazio di lavoro](app:/workspace-settings) e vada a **Modelli e dati**.
2. Tocchi **Esporta lo spazio (XML)**.

**Da sapere**

- Contiene le impostazioni e la piantina. Non contiene mai membri, prenotazioni o dati finanziari, né il codice d'invito o le credenziali di pagamento.
- Con **Configurazione nel file dello spazio** attiva, il file contiene anche tariffe, aliquote IVA, regole, ruoli e altro.
- Il file viene salvato sul suo dispositivo.

**Vedi anche:** [Importare lo spazio (XML)](help:user.workspace.export.space-import)

<!-- anchor: user.workspace.export.space-import -->
### Importare lo spazio (XML)

**Destinatari:** Proprietario · Amministratore con il permesso

Vuole applicare a uno spazio un file esportato.

**Passaggi**

1. In [Spazio di lavoro](app:/workspace-settings), sotto **Modelli e dati**, tocchi **Importa lo spazio (XML)**.
2. Scelga il file e legga l'anteprima: piani, uffici, scrivanie, posti e configurazione.
3. Tocchi **Sostituisci e importa**.

**Da sapere**

- Sostituisce la piantina attuale e sovrascrive le impostazioni. Non si può annullare.
- Quando uno spazio ha già delle prenotazioni, viene applicata solo la configurazione. La piantina viene mantenuta, e l'app lo dice.
- Un file illeggibile, o che non proviene da DesKilo, viene rifiutato con un messaggio chiaro.

**Vedi anche:** [Esportare lo spazio (XML)](help:user.workspace.export.space-xml)

<!-- anchor: user.workspace.export.config-pdf -->
### Esportare la configurazione (PDF)

**Destinatari:** Proprietario · Amministratore con il permesso

Vuole un documento con ogni parametro, da leggere, firmare o consegnare a un commercialista.

<p><img src="images/user-workspace-export-reports.it.jpg" width="280"></p>

**Passaggi**

1. Apra [Report](app:/reports?section=documents) e scelga **Documenti dello spazio**.
2. Tocchi **Esporta configurazione (PDF)**.

**Da sapere**

- È un'istantanea completa di impostazioni, membri e piantina. È una documentazione, non una copia di sicurezza: solo l'XML si può reimportare.

**Vedi anche:** [Esportare lo spazio (XML)](help:user.workspace.export.space-xml)

<!-- anchor: user.workspace.export.workspace-report -->
### Report dello spazio

**Destinatari:** Proprietario · Amministratore con il permesso

Vuole lo spazio sotto forma di documento: i suoi posti, i prezzi e le regole.

**Passaggi**

1. Apra [Report](app:/reports?section=documents) e scelga **Documenti dello spazio**.
2. Tocchi **Report dello spazio**.

**Da sapere**

- Viene prodotto dal modello dello spazio dell'editor dei report, quindi il suo aspetto segue il disegno che ha scelto.

**Vedi anche:** [Esportare la configurazione (PDF)](help:user.workspace.export.config-pdf)

<!-- anchor: user.workspace.export.space-qr -->
### Codici QR degli spazi (PDF)

**Destinatari:** Proprietario · Amministratore con il permesso

Vuole una scheda QR su ogni posto, scrivania, ufficio e piano, in modo che le persone prenotino o facciano il check-in scansionandola.

**Passaggi**

1. Apra [Report](app:/reports?section=documents) e scelga **Documenti dello spazio**.
2. Tocchi **Codici QR degli spazi (PDF)**.
3. Scelga **Dimensione della scheda**, **Dimensione del codice QR** e **Informazioni sulla scheda**, poi tocchi **Salva**.
4. Stampi, ritagli e incolli ogni scheda al suo posto.

**Da sapere**

- Richiede la funzionalità **Codici QR degli spazi**.
- Scansionare una scheda apre la stessa scheda che mostra il chiosco.

**Vedi anche:** [Un tablet a muro per il check-in](help:user.kiosk.mode)

<!-- anchor: user.workspace.export.excel -->
### Esportare i dati (Excel)

**Destinatari:** Proprietario · Amministratore con il permesso

Vuole i suoi numeri in un foglio di calcolo per le sue analisi.

**Passaggi**

1. Apra [Report](app:/reports?section=documents) e scelga **Documenti dello spazio**.
2. Tocchi **Esporta i dati (Excel)**.

**Da sapere**

- Arriva come un unico ZIP: una cartella di lavoro con una scheda per prenotazioni, pagamenti, fatture, membri e piantina, un manifesto che conta le righe e i file conservati dello spazio.
- Richiede la funzionalità **Esportazione dati (Excel)** e il permesso di esportare i dati. È solo un'esportazione: nulla la rilegge.

**Vedi anche:** [Esportare lo spazio (XML)](help:user.workspace.export.space-xml)

<!-- anchor: user.workspace.sites -->
### Sedi

**Destinatari:** Proprietario · Amministratore

Gestisce più di un indirizzo e vuole che ogni piano e ogni membro appartengano a quello giusto.

**Passaggi**

1. Attivi **Sedi** in [Funzionalità](app:/features).
2. Apra [Sedi](app:/settings/sites) e tocchi **Aggiungi una sede**.
3. Compili **Nome della sede**, **Via**, **CAP**, **Città** e i piani che le appartengono.

**Da sapere**

- La sede predefinita porta l'indirizzo dello spazio di lavoro. La sede di un membro è l'indirizzo che compare sui suoi documenti.
- **Elimina questa sede** riporta i suoi piani e i suoi membri alla sede predefinita.
- Una sede che è una persona giuridica a sé può avere la propria registrazione e la propria partita IVA.
