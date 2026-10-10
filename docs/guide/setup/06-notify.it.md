<!-- anchor: setup.notify.overview -->
## Informare le persone

Per i proprietari che vogliono che membri e amministratori vengano a sapere ciò che conta, e solo quello. Questo capitolo descrive che cosa DesKilo invia davvero, chi lo riceve, che cosa configura Lei e che cosa lascia all'operatore dell'installazione.

In questo capitolo:
- I canali, in parole semplici
- Una tabella: che cosa succede, chi viene informato, con quale canale, che cosa può cambiare un membro
- Che cosa configura Lei e che cosa deve fare l'operatore per le notifiche push
- Un piano di prova con due account
- Come evitare sia il sovraccarico sia il silenzio

<!-- anchor: setup.notify.channels -->
### I canali, in parole semplici

**Destinatari:** Proprietario · Amministratore

Vuole un quadro chiaro dei modi in cui DesKilo può raggiungere una persona, prima di promettere qualcosa ai Suoi membri.

<p><img src="images/setup-notify-features.it.jpg" width="280"></p>

**Prima di iniziare**

I modi sono sei e non sono tutti uguali. Gran parte del lavoro avviene dentro l'app.

| Canale | Che cos'è | Che cosa serve |
|---|---|---|
| Il flusso degli eventi e la campanella | Tutto ciò che accade nello spazio viene scritto in un flusso. La campanella conta i nuovi aggiornamenti e le decisioni che attendono Lei. | **Scheda Eventi**; **Raggruppamento delle notifiche** è un'opzione in più |
| Messaggi | Conversazioni private e di gruppo tra membri, con conferme di lettura e collegamenti a una prenotazione o a uno spazio. | **Notifiche tra membri** |
| Push | Una breve notifica su telefono o computer, anche quando l'app è chiusa. Il testo è generico: niente nomi, niente orari. | **Notifiche push** attive **e** una configurazione push da parte dell'operatore; vedi [la parte dell'operatore](help:setup.notify.operator) |
| Il promemoria di check-in | Una notifica sul dispositivo del membro stesso, 15 minuti prima di una prenotazione per la quale non ha ancora fatto il check-in. | Il permesso di sistema del membro. Non nella versione per browser. |
| Solleciti di pagamento | Un avviso nel flusso e una notifica push al membro la cui fattura è scaduta. | **Solleciti di pagamento** e **Solleciti di pagamento automatici**; vedi [Solleciti di pagamento](help:setup.money.reminders) |
| WhatsApp | Un link di gruppo che Lei pubblica e il numero WhatsApp che un membro sceglie di condividere. L'app apre WhatsApp; dal server non viene inviato nulla. | **Integrazione WhatsApp** |

**Da sapere**

- DesKilo non invia e-mail proprie oltre a quelle dell'account (conferma di iscrizione, reimpostazione della password). Gli inviti sono testi che condivide dal Suo telefono.
- Non esiste un'iscrizione per singolo evento: un membro non può scegliere «avvisami per le spese ma non per le prenotazioni».
- Una notifica può arrivare in ritardo o perdersi come qualsiasi push; il flusso e l'elenco dei messaggi sono il registro.

**Vedi anche:** [Notifiche](help:user.collaborate.notifications) · [Eventi e conferme](help:user.collaborate.events)

<!-- anchor: setup.notify.table -->
### Chi viene informato di che cosa

**Destinatari:** Proprietario · Amministratore

Vuole sapere, evento per evento, chi lo viene a sapere e come.

<p><img src="images/setup-notify-events.it.jpg" width="280"></p>

**Prima di iniziare**

La notifica push viene inviata solo per le cinque righe contrassegnate «push» qui sotto. Ogni altro evento (una prenotazione effettuata, un pagamento registrato, l'ingresso di un membro) compare nel flusso e in nessun altro luogo.

| Fonte | Evento | Chi viene informato | Canale | Che cosa può cambiare il membro |
|---|---|---|---|---|
| Regole di convalida | Una richiesta ha bisogno di una conferma | Le persone indicate dalla regola (flusso, **In attesa della tua conferma**); la push va solo al membro a cui la richiesta si riferisce, mai a chi l'ha fatta, quindi i convalidatori ricevono la push solo se sono quel membro. Testo: «Someone needs your confirmation.» | Flusso, campanella; push | Spegnere la push sul dispositivo |
| Prenotazioni | Un amministratore rimuove o annulla una prenotazione | Il membro spostato e ogni amministratore e proprietario attivo, tranne chi ha agito. Testo: «A reservation was removed by an admin.» | Flusso; push | Spegnere la push sul dispositivo |
| Solleciti di pagamento | Una fattura è scaduta e scatta un livello di sollecito | Il membro a cui è intestata la fattura. La fattura di un proprietario arriva al proprietario stesso. Testo: «A payment reminder is waiting for you.» | Avviso nel flusso; push | Spegnere la push sul dispositivo |
| Notifiche tra membri | Un nuovo messaggio | Messaggio diretto: il destinatario. Gruppo: i partecipanti tranne il mittente. Una conversazione silenziata da un membro resta muta per quel membro. Testo: «You have a new message.» | Messaggi, campanella; push | Silenziare, fissare o archiviare una conversazione; spegnere la push |
| Menzioni nei messaggi | Un messaggio di gruppo nomina qualcuno | Le persone nominate, anche in una conversazione silenziata. Testo: «You were mentioned in a conversation.» | Messaggi; push | Spegnere la push |
| Prenotazioni | Una prenotazione è imminente | Il membro che ha prenotato, sul proprio dispositivo, 15 minuti prima dell'inizio, per le prenotazioni dei prossimi sette giorni | Notifica locale | Rifiutare il permesso di sistema |
| Integrazione WhatsApp | Non viene inviato nulla | Il link del gruppo compare nella rubrica; un membro può condividere il proprio numero | Apre WhatsApp | Condividere o nascondere il numero |

**Da sapere**

- Quando l'app è aperta, la push di una prenotazione rimossa viene sostituita da una notifica nella lingua del membro. Per messaggi, menzioni, conferme e solleciti di pagamento l'app aperta mostra oggi il suo testo generico («Someone needs your confirmation.»). I testi generici inglesi della tabella compaiono quando l'app è in background o chiusa.
- Un amministratore viene informato solo di ciò su cui agisce o che una regola gli assegna; non esiste un riepilogo di «tutto».
- I membri vedono i propri eventi; amministratori e proprietari vedono quelli di tutti.

**Vedi anche:** [Regole di convalida](help:user.validation.overview) · [Messaggi](help:user.collaborate.messages)

<!-- anchor: setup.notify.configure -->
### Che cosa configura Lei

**Destinatari:** Proprietario

Decide quali di questi canali esistono nel Suo spazio e a chi viene chiesto di decidere che cosa.

<p><img src="images/setup-notify-validation.it.jpg" width="280"></p>

**Passaggi**

1. Apra [Funzionalità](help:user.features.switch) e controlli gli interruttori delle notifiche: **Notifiche push**, **Notifiche tra membri**, **Scheda Eventi**, **Raggruppamento delle notifiche**, **Solleciti di pagamento**, **Solleciti di pagamento automatici** e **Integrazione WhatsApp**.
2. Imposti le [regole di convalida](help:user.validation.overview): per ogni tipo di richiesta, quante convalide servono e chi può darle. Questo decide a chi viene chiesto, e quindi chi vede una decisione in attesa.
3. Decida se la richiesta di un amministratore o di un proprietario si risolve da sé; vedi [Convalida automatica della richiesta di un amministratore](help:user.validation.auto-validate-admin) e [Convalida automatica della richiesta di un proprietario](help:user.validation.auto-validate-owner). Una richiesta già risolta non avvisa mai nessuno.
4. Scriva il messaggio di invito che i membri ricevono e incolli il link del gruppo della comunità; vedi [Messaggio di invito](help:user.workspace.settings.invitation-message) e [Gruppo WhatsApp](help:user.workspace.settings.whatsapp-group).
5. Attivi **Richieste di eliminazione prenotazioni** se i membri possono chiedere di eliminare una prenotazione passata o con check-in effettuato: qualcuno dovrà allora rispondere.

**Da sapere**

- Impostazioni predefinite di un nuovo spazio: la scheda Eventi, le notifiche tra membri e il raggruppamento sono attivi; **Solleciti di pagamento** e **Solleciti di pagamento automatici** sono attivi come funzioni, ma nessun sollecito viene inviato finché non attiva **Solleciti automatici** nelle regole di sollecito.
- **Notifiche push** è attivo per impostazione predefinita, ma non recapita nulla finché l'operatore non l'ha configurato.
- Spegnere una funzione ferma le nuove attività di quel tipo. Non cancella ciò che esiste.
- I ruoli decidono chi può vedere e rispondere a che cosa; vedi [La matrice dei ruoli](help:user.roles.matrix).

**Vedi anche:** [Chi può convalidare](help:user.validation.who-may) · [Convalide richieste](help:user.validation.required-count)

<!-- anchor: setup.notify.operator -->
### La parte dell'operatore: far funzionare le notifiche push

**Destinatari:** Operatore · Proprietario

Vuole le notifiche push sui telefoni dei membri e deve sapere chi fa che cosa.

**Prima di iniziare**

Le notifiche push non arrivano con l'app da sole. Se gestisce il Suo spazio sull'installazione di riferimento condivisa, chieda al suo operatore se le push sono configurate. Se gestisce una Sua installazione, l'operatore è Lei o la Sua persona tecnica.

**Passaggi**

1. Crei un progetto Firebase e compili l'app con esso. Senza questo passaggio l'app resta con le sole notifiche locali e un membro vede **Questa versione non ha notifiche push**. La versione preparata per F-Droid non ha affatto le push ([stato F-Droid](https://github.com/fdittgen-png/deskilo/blob/master/docs/guides/fdroid.md#status)).
2. Per iPhone e Mac, aggiunga una chiave push Apple al progetto Firebase.
3. Memorizzi la chiave dell'account di servizio Firebase come segreto del server e distribuisca la funzione push.
4. Sulla Sua installazione, punti la riga `push_config` del database all'URL e alla chiave della Sua funzione push. È precompilata con l'indirizzo dell'installazione di riferimento.
5. La provi con due account, come descritto nel [piano di prova](help:setup.notify.test).

**Da sapere**

- Senza i passaggi da 1 a 4 non viene inviata alcuna push, qualunque cosa dicano gli interruttori. Il flusso, la campanella e i messaggi funzionano comunque.
- L'elenco dettagliato è per l'operatore: vedi [Piattaforme](help:user.advanced.platforms) e [Il Suo server](help:user.advanced.own-server).
- Il testo della push non contiene mai un nome né un orario: è voluto, per la riservatezza.

**Vedi anche:** [Notifiche push su questo dispositivo](help:user.privacy.push)

<!-- anchor: setup.notify.members -->
### Che cosa controllano i membri

**Destinatari:** Proprietario · Amministratore

Vuole dire ai Suoi membri, con onestà, che cosa possono spegnere.

<p><img src="images/setup-notify-push.it.jpg" width="280"></p>

**Passaggi**

1. Un membro apre [Privacy e dati](app:/privacy) e usa **Notifiche push su questo dispositivo** per fermare o riprendere le push su quel dispositivo.
2. In [Messaggi](app:/me?tab=messages), un membro tiene premuta una conversazione per **Fissa in alto**, **Silenzia le notifiche**, **Segna come non letto** o **Archivia**.
3. Nelle impostazioni di sistema del telefono, un membro può rifiutare del tutto le notifiche, compresi i promemoria di check-in.
4. Nel proprio profilo, un membro decide se condividere un numero WhatsApp.

**Da sapere**

- Una conversazione silenziata resta muta ma viene comunque conteggiata; una menzione prevale sul silenziamento.
- Un membro che spegne la push su un dispositivo non è toccato su un altro.
- Non ci sono interruttori per categoria. Se un membro ha bisogno di meno rumore, silenzi le conversazioni; se non ne vuole affatto, spenga la push.

**Vedi anche:** [Notifiche](help:user.collaborate.notifications) · [I Suoi dati, i Suoi diritti](help:user.privacy.consent)

<!-- anchor: setup.notify.test -->
### Un piano di prova: invii a se stesso un esempio di ogni tipo

**Destinatari:** Proprietario · Amministratore · Operatore

Si assicura che ogni canale funzioni prima che i Suoi membri dipendano da esso.

**Prima di iniziare**

Lo faccia in uno spazio di prova (vedi [una prova sicura](help:setup.money.dry-run)). Servono due account: il Suo come proprietario e un secondo come membro, su un altro telefono, un altro browser o lo stesso telefono dopo essere uscito. Lo spazio dimostrativo Le fa vedere le schermate con i suoi personaggi, ma non invia alcuna push reale.

**Passaggi**

1. Messaggio: dall'account del membro, scriva al proprietario in [Messaggi](app:/me?tab=messages). Sull'account del proprietario la campanella lo conta e la conversazione risulta non letta. La apra: il messaggio del membro mostra una conferma di lettura.
2. Menzione: in una conversazione di gruppo, nomini il proprietario (la funzione di menzione della messaggistica deve essere attiva). Se la push è configurata, il telefono del proprietario mostra «You were mentioned in a conversation.»
3. Decisione: come membro, chieda di eliminare una prenotazione passata (la funzione **Richieste di eliminazione prenotazioni** deve essere attiva). Il proprietario la vede sotto **In attesa della tua conferma** in [Eventi](app:/events); risponda e osservi come cambia il flusso del membro.
4. Rimozione: come proprietario, rimuova una prenotazione futura del membro. Il flusso del membro la mostra e un telefono con la push mostra «A reservation was removed by an admin.»
5. Promemoria: come membro, prenoti un posto che inizia fra circa 20 minuti (una prenotazione che inizia fra meno di 15 minuti non riceve alcun promemoria). Circa 15 minuti prima dell'inizio, il telefono del membro mostra il promemoria di check-in.
6. Sollecito di pagamento: con **Solleciti di pagamento** attivi, attivi **Solleciti automatici** nelle regole di sollecito con un breve ritardo per il primo sollecito, emetta una fattura di prova con un termine di pagamento, attenda che il ritardo passi, poi apra Finanze come proprietario o comproprietario; il flusso del membro mostra l'avviso.
7. Silenziamento: come membro, silenzi la conversazione, invii un altro messaggio dal proprietario e verifichi che nulla suoni ma il conteggio dei non letti aumenti.

**Da sapere**

- I passaggi 2 e 4 mostrano una push solo se la configurazione dell'operatore è completa. Se falliscono mentre gli altri funzionano, il difetto è nella configurazione, non nelle Sue regole.
- Nella versione per browser dell'app non c'è alcun promemoria di check-in.
- Un telefono che blocca le notifiche non mostra nulla; controlli prima le impostazioni di sistema.

**Risultato**

Ha visto con i Suoi occhi ogni canale su cui un membro farà affidamento.

**Vedi anche:** [I canali](help:setup.notify.channels) · [Avviare una conversazione o un gruppo](help:user.collaborate.messages-new)

<!-- anchor: setup.notify.silence -->
### Evitare il sovraccarico e evitare il silenzio

**Destinatari:** Proprietario · Amministratore

Vuole che le persone vengano informate di ciò che le riguarda, senza sommergerle.

**Passaggi**

1. Tenga attivo **Raggruppamento delle notifiche**: membri e amministratori possono ripiegare il flusso per tipo, giorno o membro.
2. Chieda la convalida solo dove la decisione è reale: ogni regola che richiede una convalida crea una richiesta a cui qualcuno deve rispondere. Vedi [Regole di convalida](help:user.validation.overview).
3. Usi gli interruttori di convalida automatica per le richieste la cui risposta è ovvia.
4. Guardi di tanto in tanto [Che cosa richiede la Sua attenzione](help:user.collaborate.attention): ordina ciò che è in attesa.

**Da sapere**

- Il sovraccarico nasce da regole che chiedono troppo spesso o da troppi amministratori su una sola regola.
- Il silenzio nasce da una regola senza nessuno che risponda: richiedere due convalide quando esiste solo il proprietario, oppure elencare amministratori che se ne sono andati, lascia le richieste in attesa per sempre. La scheda di prontezza della configurazione può segnalare una regola di prenotazione con troppo pochi convalidatori.
- Il silenzio nasce anche da una push senza configurazione, da membri che hanno spento la push e da un sistema che blocca le notifiche.
- I solleciti di pagamento automatici non sostituiscono uno sguardo ogni tanto alle fatture aperte.

**Vedi anche:** [Chi può convalidare](help:user.validation.who-may) · [Convalide richieste](help:user.validation.required-count)
