<!-- anchor: setup.people.overview -->
## Persone, ruoli e decisioni

Uno spazio è le sue persone. Prima di invitare la prima, decida tre cose: chi può fare che cosa, come si entra e quali atti richiedono il sì di una seconda persona. Sono rapide da impostare e scomode da riparare quando quaranta persone ci fanno affidamento.

In questo capitolo:
- [Chi fa che cosa in un’organizzazione reale](help:setup.people.organisation)
- [La matrice dei ruoli: il privilegio minimo](help:setup.people.matrix)
- [Comproprietari: più di una persona che può agire](help:setup.people.coowner)
- [Come entrano le persone](help:setup.people.join)
- [Il messaggio d’invito, lingua per lingua](help:setup.people.invitation)
- [Profili gestiti](help:setup.people.managed)
- [Convalida: di che cosa è fatta una regola](help:setup.people.validation)
- [Tre modelli da copiare](help:setup.people.presets)
- [Evitare richieste che attendono per sempre](help:setup.people.stuck)
- [La prima settimana dei suoi membri](help:setup.people.first-week)

L’esempio di riferimento è *Atelier du Marché*. Immagini che sia gestito da un’associazione: Ada è la presidente, Chiara la segretaria, Bruno il tesoriere. Ogni passaggio qui sotto è mostrato su quello spazio.

<!-- anchor: setup.people.organisation -->
### Chi fa che cosa in un’organizzazione reale

**Destinatari:** Proprietario · Comproprietario

Vuole far corrispondere le persone della sua organizzazione ai ruoli di DesKilo, in modo che nessuno abbia più di quanto richieda il suo compito.

<p><img src="images/setup-people-members.it.jpg" width="280"></p>

*I quattro ruoli di base*

| Ruolo | A che cosa serve | Nell’associazione |
|---|---|---|
| **Proprietario** | La persona che risponde dello spazio e detiene tutti i permessi. Solo un proprietario può conferire la proprietà. | Ada, la presidente. |
| **Comproprietario** | Una seconda chiave. Detiene per impostazione predefinita tutti i permessi e può subentrare quando il proprietario se ne va. | Il vicepresidente, se il consiglio ne ha uno. |
| **Amministratore** | Gestisce la giornata: membri, prenotazioni per conto di altri, chiosco, documenti, servizi. Detiene ciò che la matrice gli dà e nulla di più. | Chiara, la segretaria. |
| **Utente** | La persona che usa lo spazio. Detiene solo i permessi quotidiani che Lei le concede. | Bruno, un membro come gli altri. |

Ognuno ha esattamente un ruolo di base. Un ruolo definito dallo spazio, come *Ospite* o *Contabile*, si aggiunge a quello di base e non toglie mai nulla.

*Un tesoriere senza essere amministratore*

Bruno tiene i conti, ma non deve modificare la planimetria né approvare nuovi membri. Gli dia il ruolo di base **Utente** e aggiunga un ruolo proprio, per esempio *Contabile*, con quattro permessi: **Consultare le finanze dello spazio**, **Emettere fatture e riconciliare pagamenti**, **Esportare contabilità e dati** e **Consultare i dati dello spazio**. Nient’altro. Un ruolo simile non è predefinito: lo crea con i passaggi seguenti.

<p><img src="images/setup-people-roles-space.it.jpg" width="280"></p>

**Passaggi**

1. Apra [I ruoli di questo spazio](app:/settings/roles-of-this-space) e tocchi **Aggiungi un ruolo**. Veda [I ruoli di questo spazio](help:user.roles.space).
2. Dia un nome al ruolo, scelga **Cosa aggiunge** e tocchi **Salva il ruolo**.
3. Apra la persona in [Membri e piani](app:/members), trovi **Ruoli** e tocchi **Aggiungi un ruolo**.

**Da sapere**

- **I ruoli di questo spazio** è una funzionalità a sé e in un nuovo spazio è disattivata. La attivi in [Funzionalità](app:/features).
- Nessuno può assegnarsi un ruolo da solo. Assegnare un ruolo richiede **Gestire ruoli e permessi**, e solo un proprietario può assegnare un ruolo che lo include.
- Un ruolo definito dallo spazio ha effetto subito ed è registrato. Solo rendere qualcuno amministratore, o toglierglielo, segue la regola di convalida **Cambio di ruolo**.

**Risultato** Ogni persona del consiglio detiene i permessi del proprio compito, e il proprietario resta l’unico che può modificarli.

**Vedi anche:** [La matrice dei ruoli](help:user.roles.matrix)

<!-- anchor: setup.people.matrix -->
### La matrice dei ruoli: il privilegio minimo

**Destinatari:** Proprietario · Comproprietario

Vuole che ogni ruolo detenga ciò che gli serve e nient’altro. È il principio del privilegio minimo: si parte da poco e si aggiunge quando qualcuno lo chiede, perché un permesso concesso raramente si toglie con garbo.

<p><img src="images/setup-people-roles-matrix.it.jpg" width="280"></p>

**Passaggi**

1. Apra [Ruoli](app:/roles). C’è una scheda per ogni ruolo: **Proprietario**, **Comproprietario**, **Amministratore** (il proprietario può rinominarlo) e **Utente**.
2. Legga per prima la scheda dell’**Amministratore**. Mostra ciò che oggi un amministratore detiene nel suo spazio.
3. Tolga la spunta a ciò che non vuole delegare. Spunti i permessi quotidiani di cui ha bisogno la scheda **Utente** (veda sotto).

*Che cosa detiene per impostazione predefinita un amministratore*

| Gruppo | Permessi |
|---|---|
| Persone | **Gestire i membri**, **Consultare i dati personali dei membri** |
| Prenotazioni e luogo | **Gestire le prenotazioni degli altri**, **Operare il chiosco e i badge**, **Gestire sedi e modificare la planimetria** |
| Denaro, lettura e approvazione | **Consultare le finanze dello spazio**, **Approvare le spese**, **Gestire servizi e pacchetti**, **Consultare gli accordi commerciali**, **Gestire gli accordi commerciali**, **Richiedere modifiche alle condizioni di pagamento**, **Esportare contabilità e dati** |
| Documenti e dati | **Gestire la libreria dei documenti**, **Consultare i dati dello spazio** |
| I due lati di uno spazio | **Distribuire in sviluppo**, **Entrare nello spazio di produzione** |

Un amministratore non detiene **Gestire ruoli e permessi**, **Configurare le regole di convalida**, **Modificare le impostazioni dello spazio**, **Gestire tariffe e regole di fatturazione**, **Progettare i documenti**, **Gestire le integrazioni**, **Gestire la configurazione** né **Distribuire in produzione**. Un comproprietario li detiene tutti finché Lei non ne toglie qualcuno. Il proprietario li detiene sempre tutti.

> **Attenzione** In un nuovo spazio la scheda **Utente** è vuota. I sei permessi quotidiani (**Usare la messaggistica**, **Prenotare e usare le prenotazioni**, **Vedere il calendario**, **Vedere l'elenco dei membri**, **Vedere il proprio conto e le proprie fatture**, **Vedere i documenti condivisi**) si detengono solo tramite la matrice o un ruolo. Finché non li spunta, un membro che entra non può aprire la planimetria. La demo li mostra già spuntati, e questo lo nasconde. Li spunti per la scheda **Utente** e, se anche gli amministratori prenotano, per la scheda **Amministratore**, poi provi con un secondo account.

**Da sapere**

- Per impostazione predefinita un amministratore può leggere tutte le finanze e i dati personali di ogni membro. Se i suoi amministratori sono volontari, valuti se debba essere così.
- **Gli admin emettono fatture** (una funzionalità, disattivata per impostazione predefinita, sotto **Fatture**) dà agli amministratori **Emettere fatture e riconciliare pagamenti** a prescindere da ciò che dice la matrice. Preferisca la spunta nella matrice, o un ruolo proprio, che è più preciso.
- Togliere la spunta a un permesso lo rimuove ovunque in una volta sola; lo verifica il server, non solo il menu.
- Ogni modifica della matrice viene registrata come evento. La funzionalità **Gestione dei ruoli** mostra soltanto la schermata; se è disattivata, la matrice che ha salvato continua ad applicarsi, semplicemente non può più modificarla.

**Risultato** Una matrice che sa spiegare in una frase per ruolo.

**Vedi anche:** [La matrice dei ruoli](help:user.roles.matrix) · [Chi fa che cosa](help:setup.before.who)

<!-- anchor: setup.people.coowner -->
### Comproprietari: più di una persona che può agire

**Destinatari:** Proprietario · Comproprietario

Vuole che lo spazio continui a funzionare quando Lei è malato, assente o non c’è più. Ogni spazio ha bisogno di più di una persona che possa agire. Per impostazione predefinita solo proprietari e comproprietari detengono i permessi che modificano funzionalità, ruoli, regole di convalida e ID dello spazio, e solo un proprietario può nominare un altro proprietario.

<p><img src="images/setup-people-coowner.it.jpg" width="280"></p>

*I due tipi*

| Tipo | Che cosa fa | Lo scelga quando |
|---|---|---|
| *Comproprietario attivo* | Detiene subito i permessi del proprietario e subentra se il proprietario se ne va. | Vi dividete il lavoro: il vicepresidente, un socio. |
| **Successore** | Attende. Diventa proprietario quando Lei lo promuove o quando Lei se ne va. | Vuole solo un erede. |

**Passaggi**

1. Attivi la funzionalità **Comproprietari** in [Funzionalità](app:/features). In un nuovo spazio è disattivata.
2. Apra la persona in [Membri e piani](app:/members), vada su **Gestisci** e tocchi **Comproprietà**.
3. Scelga *Comproprietario attivo* oppure **Successore**. Per cedere subito il posto, scelga **Promuovi a proprietario ora**.

**Da sapere**

- Se l’ultimo proprietario se ne va, il miglior comproprietario diventa proprietario automaticamente, un comproprietario attivo prima di un successore.
- Due amministratori non sono la stessa cosa: un amministratore detiene solo ciò che la matrice gli dà e non può mai trasmettere la proprietà.
- Una regola che dice **Il proprietario deve sempre validare** richiede un proprietario. Verifichi sul suo lato di prova che il suo comproprietario possa ancora decidere ciò che si aspetta.

**Risultato** Lo spazio ha una seconda persona che può agire.

**Vedi anche:** [Comproprietari](help:user.roles.co-owners) · [Comproprietà](help:user.members.co-ownership)

<!-- anchor: setup.people.join -->
### Come entrano le persone

**Destinatari:** Proprietario · Amministratore

Vuole scegliere come le persone raggiungono il suo spazio e chi le fa entrare. Esistono quattro modi, e tutti finiscono nello stesso punto: una persona che chiede di partecipare e qualcuno che decide.

<p><img src="images/setup-people-workspace-code.it.jpg" width="280"></p>

| Modo | Che cosa riceve la persona | Che cosa diventa |
|---|---|---|
| L’ID dello spazio | Una parola breve, da digitare nell’app. | Un membro, dopo l’approvazione. |
| Il codice QR | Lo stesso ID come immagine da stampare o affiggere (**Condividi come PNG**). | Un membro, dopo l’approvazione. |
| Un messaggio d’invito | Un testo con un codice personale, valido per una sola persona, nella lingua scelta. | Il ruolo che offre, dopo l’approvazione. |
| Un codice amministratore | Un codice per una sola persona, dalla scheda **Invito amministratore**. | Un amministratore, una volta sola. |

**Passaggi**

1. Apra [ID dello spazio e QR](app:/workspace-code). Scelga un ID che le persone possano ricordare con **Cambia l'ID dello spazio**: da 4 a 20 lettere o cifre, unico in tutto DesKilo.
2. Per una persona precisa, tocchi **Invita qualcuno**. Compili il nome, spunti **Ruoli all'arrivo** se deve ricevere un ruolo, scelga la **Lingua del messaggio** e invii.
3. Quando qualcuno chiede di partecipare, la sua riga in [Membri e piani](app:/members) riporta **In attesa**. La apra e scelga **Approva l'adesione** o **Rifiuta l'adesione**.

**Da sapere**

- Nessuno entra senza una decisione. Finché non viene presa, il nuovo arrivato vede una schermata di attesa e nient’altro.
- La decisione segue la regola di **Nuovo membro** nelle [Regole di convalida](app:/validation): per impostazione predefinita basta un proprietario o un amministratore; se ne richiede due, la prima approvazione lascia la persona in attesa.
- Se cambia l’ID dello spazio, il vecchio smette di funzionare. Stampi di nuovo il codice QR.
- Non esiste un invito da proprietario. La proprietà si conferisce in **Membri e piani**.

**Risultato** Le persone possono trovarla, e Lei decide chi resta.

**Vedi anche:** [L’ID dello spazio](help:user.workspace.code) · [Entrare in uno spazio di lavoro](help:user.start.join) · [Membri in attesa e in pausa](help:user.members.pending)

<!-- anchor: setup.people.invitation -->
### Il messaggio d’invito, lingua per lingua

**Destinatari:** Proprietario · Amministratore

Vuole un invito che suoni come il suo spazio, nella lingua di chi lo riceve. Ogni lingua ha il suo testo; quello che non scrive ricade sul messaggio predefinito.

<p><img src="images/setup-people-invite.it.jpg" width="280"></p>

<p><img src="images/setup-people-invitation-message--message.it.jpg" width="280"></p>

**Passaggi**

1. Apra [Spazio di lavoro](app:/workspace-settings) e vada su **Comunità e inviti**.
2. Sotto **Lingua del messaggio** scelga la lingua per cui scrive. La riga si apre sulla lingua del suo spazio.
3. Scriva il testo. Tocchi un segnaposto per inserirlo dove si trova il cursore. Il limite è di 2000 caratteri.
4. Ripeta per ogni lingua usata dai suoi membri, poi tocchi **Salva**.

*I segnaposto*

| Segnaposto | Viene sostituito con |
|---|---|
| `{firstName}` `{lastName}` `{phone}` | Ciò che ha digitato in **Invita qualcuno**. Vuoto se non ha digitato nulla. |
| `{workspaceName}` | Il nome del suo spazio. |
| `{workspaceId}` | Il codice d’invito personale di questo messaggio (non l’ID pubblico dello spazio). |
| `{inviteLink}` | Un link che apre l’app sul server giusto con il codice già inserito. |
| `{downloadUrl}` | La pagina dell’app nello store. |
| `{role}` | Il ruolo offerto dall’invito, nella lingua del messaggio. |

**Da sapere**

- Se lascia vuota la casella, l’app scrive il proprio messaggio in quella lingua. Spiega i passaggi: scaricare, creare un account, partecipare con il codice.
- Non incolli lei stesso un codice o un link. Ogni invio crea il suo codice, valido per una sola persona.
- Un segnaposto scritto male resta visibile nel testo inviato: legga l’anteprima prima di inviare.
- Il messaggio predefinito dice alla persona che il codice è monouso e valido 14 giorni.

**Risultato** Un invito che i suoi membri possono seguire senza chiederle nulla.

**Vedi anche:** [Messaggio d’invito](help:user.workspace.settings.invitation-message) · [Invitare qualcuno con un messaggio](help:user.workspace.code.invite)

<!-- anchor: setup.people.managed -->
### Profili gestiti

**Destinatari:** Proprietario · Amministratore

Vuole prenotare, fatturare e gestire per conto di qualcuno che non ha ancora un account: un visitatore, un membro anziano, una persona che preferisce la carta.

**Passaggi**

1. Attivi **Profili gestiti** in [Funzionalità](app:/features).
2. In [Membri e piani](app:/members), tocchi **Aggiungi un profilo gestito** e compili l’identità.
3. Quando la persona è pronta, apra la sua pagina e scelga **Consegna alla persona**. Crea un codice personale legato al profilo.

**Da sapere**

- Chi riscatta il codice subentra nel profilo con le sue prenotazioni, fatture e abbonamento, una volta che Lei approva l’adesione.
- Annulli la consegna con **Revoca la consegna** se il codice non è ancora stato usato.

**Vedi anche:** [Aggiungere un profilo gestito](help:user.members.managed)

<!-- anchor: setup.people.validation -->
### Convalida: di che cosa è fatta una regola

**Destinatari:** Proprietario

Vuole scegliere, atto per atto, se una seconda persona debba essere d’accordo. Un ambito di convalida è un tipo di atto con la sua regola: *un pagamento*, *una spesa*, *un nuovo membro*, *l’eliminazione di una prenotazione*. In **Regole di convalida** gli ambiti sono in tre gruppi.

<p><img src="images/setup-people-validation-overview.it.jpg" width="280"></p>

| Gruppo | Ambiti, in parole semplici | Durante l’attesa |
|---|---|---|
| **Denaro** | Un pagamento, una spesa, un servizio, una fattura abbinata al suo pagamento, una fattura emessa o annullata, un rimborso, uno stralcio, un accordo sul prezzo, una spesa condivisa, una spesa programmata, una modifica delle condizioni di pagamento, una partenza anticipata, un rilevamento di utilizzo rimosso | L’importo non conta sull’estratto conto di nessuno. |
| **Prenotazioni** | Le **Mezze giornate extra** richieste da un membro, le **Prenotazioni di spazi interi**, una prenotazione fatta per un membro da un amministratore, una **Eliminazione prenotazione** | Il posto resta com’era. |
| **Persone e ruoli** | **Nuovo membro**, un cambio di ruolo, un cambio di stato, una modifica dell’abbonamento, una modifica della matrice dei permessi | La persona conserva l’accesso che ha adesso. |

Ogni ambito parte con **Eredita la predefinita**: una convalida da parte di un qualsiasi amministratore o proprietario. **Regola predefinita** è la regola che tutte le altre ereditano. Un ambito che apre e salva diventa **Personalizzata**.

*Le manopole di una regola*

| Impostazione | Che cosa significa | Richiede |
|---|---|---|
| **Validazioni richieste** | Quante persone devono dire sì. | |
| **Chi convalida** | **Admin**, **Persone designate** o **Tutti i membri**. Il proprietario può sempre. | **Convalidatori per ruolo o persona**: senza di essa la scelta non viene mostrata e convalidano gli amministratori. Dopo averla disattivata, ricontrolli le regole che indicavano **Persone designate** |
| **Gli admin possono validare** | Disattivata, convalidano solo i proprietari. | |
| **Il proprietario deve sempre validare** | Uno dei sì deve venire da un proprietario. | |
| **La proprietà può convalidare il proprio** | La richiesta del proprietario stesso non resta in attesa di qualcun altro. Un amministratore non lo ottiene mai. | **Convalide concatenate** |
| **Una dopo l’altra** | La seconda viene chiesta quando la prima ha detto sì. | **Convalide concatenate** |
| **Solo oltre questo importo** | Al di sotto, l’atto si applica subito. Solo per gli ambiti di denaro. | **Convalide concatenate** |
| **Gli admin eliminano senza validazione** / **I proprietari eliminano senza validazione** | La loro **Eliminazione prenotazione** si regola da sola e resta contrassegnata come convalidata automaticamente. Disattivata per impostazione predefinita. | |

<p><img src="images/setup-people-validation-sheet.it.jpg" width="280"></p>

**Passaggi**

1. Apra [Regole di convalida](app:/validation). Tocchi **Regola predefinita** e decida che cosa eredita tutto il resto.
2. Tocchi un ambito, imposti le manopole, tocchi **Salva**.
3. Tenga poche eccezioni. Ogni eccezione è una cosa in più da ricordare quando qualcuno dice «perché questa è in attesa?».

**Da sapere**

- Nessuno convalida un proprio atto. Attende qualcun altro, a meno che non sia attiva l’eccezione del proprietario.
- Ogni decisione è registrata: chi, quando, su che cosa.
- Una richiesta a cui nessuno risponde scade dopo sette giorni, con una verifica alla prossima apertura di Eventi da parte di chiunque. Un atto che un amministratore ha compiuto per un membro viene invece confermato automaticamente.

**Vedi anche:** [Regole di convalida, ambito per ambito](help:user.validation.overview) · [Chi può convalidare](help:user.validation.who-may) · [Convalida automatica](help:user.validation.auto-validate-admin)

<!-- anchor: setup.people.presets -->
### Tre modelli da copiare

**Destinatari:** Proprietario

Vuole un insieme di regole da copiare oggi e affinare in seguito. Ne scelga uno; ciascuno si basa sull’ambito predefinito, proprietario e amministratori, quindi non serve alcuna funzionalità aggiuntiva.

| Modello | Lo scelga quando | Che cosa imposta | Validatori necessari |
|---|---|---|---|
| *Adesione aperta* | Conosce le persone che scansioneranno il suo codice. | Nulla. Ogni ambito eredita la predefinita: una convalida da parte di un qualsiasi proprietario o amministratore. Un’adesione non è comunque mai automatica. | 1 (Lei) |
| *Adesioni da approvare* | Un consiglio decide chi entra. | **Nuovo membro**: **Validazioni richieste** 2, **Il proprietario deve sempre validare** attivo. | 2: un proprietario e un amministratore |
| *Adesioni e prenotazioni da approvare* | I posti o le sale intere sono scarsi, oppure le eliminazioni di prenotazioni richiedono un testimone. | *Adesioni da approvare*, più su **Prenotazioni di spazi interi**, **Mezze giornate extra** e **Eliminazione prenotazione**: **Validazioni richieste** 1. | Almeno 2, 3 per stare tranquilli |

Nell’associazione: Ada è la proprietaria, Chiara un’amministratrice. Con *Adesioni da approvare*, Ada e Chiara approvano entrambe ogni nuovo arrivato. Con il terzo modello una sala intera prenotata da Bruno gli viene subito bloccata, ma Ada o Chiara possono comunque rifiutarla, e un’eliminazione richiesta da Chiara è decisa da Ada, non da Chiara.

**Passaggi**

1. Apra [Regole di convalida](app:/validation).
2. Tocchi **Nuovo membro**, imposti quanto dice la tabella, tocchi **Salva**.
3. Per il terzo modello, ripeta sugli altri tre ambiti.
4. Apra **Membri e piani** e conti i proprietari e gli amministratori attivi. Devono essere almeno il numero indicato nell’ultima colonna.

**Da sapere**

- Una normale prenotazione di un membro non viene mai trattenuta per approvazione da questi modelli. Ciò che attende è una sala intera, le mezze giornate extra, un’eliminazione e l’adesione.
- Un modello è un punto di partenza. Aumenti un numero solo quando ha abbastanza persone per rispondere.

**Vedi anche:** [Validazioni richieste](help:user.validation.required-count) · [Serve un proprietario](help:user.validation.owner-required)

<!-- anchor: setup.people.stuck -->
### Evitare richieste che attendono per sempre

**Destinatari:** Proprietario · Comproprietario

Vuole essere certo che ogni richiesta per cui crea una regola possa ricevere una risposta. Una regola che richiede più validatori di quanti ne esistano non viene rifiutata ovunque: la richiesta viene creata, nessuno può completarla e scade dopo sette giorni.

> **Attenzione** L’editor conta un validatore in più per la persona interessata, quindi le permette di salvare **Validazioni richieste** con uno in più rispetto alle persone che ha. Quel sì in più esiste solo per una prenotazione fatta da un amministratore per un membro e per alcuni pagamenti. Per un’adesione o una richiesta di denaro non esiste. Non si affidi all’editor per il conteggio.

*Contare prima di richiedere*

| Richiede | Servono, oltre alla persona che chiede |
|---|---|
| 1 | Un proprietario o amministratore attivo |
| 2 | Due proprietari o amministratori attivi |
| 2 con **Il proprietario deve sempre validare** | Un proprietario e un’altra persona |
| Un elenco di **Persone designate** | Ogni persona dell’elenco deve essere attiva; un nuovo amministratore non viene aggiunto automaticamente |

*Come verificare*

1. Apra [Regole di convalida](app:/validation) e legga ogni scheda personalizzata: «Tutti gli admin — qualsiasi 2» significa due persone.
2. Apra [Membri e piani](app:/members). Conti i proprietari e gli amministratori attivi. Le persone in pausa o uscite non contano.
3. Apra **Configurazione di questo spazio** in [Spazio di lavoro](app:/workspace-settings). L’area **Ruoli e chi convalida le richieste** dice «Una regola richiede più validatori di quanti ne abbia questo spazio» quando ne conta troppo pochi. Blocca la prima prenotazione solo quando la regola riguarda le prenotazioni.
4. Apra [Eventi](app:/events). **In attesa della sua conferma** mostra ciò che attende, e una riga mostra «1/2 validazioni».

**Da sapere**

- L’editor stesso dice **Validatori idonei insufficienti.** quando un conteggio supera chiaramente le persone disponibili. Non intercetta tutti i casi.
- Un proprietario solo che chiede qualcosa per sé attende qualcun altro: aggiunga un amministratore, oppure attivi **La proprietà può convalidare il proprio** sotto **Convalide concatenate**.
- Mettere in pausa o rimuovere un amministratore può lasciare una regola scoperta. Ricontei dopo ogni cambio di squadra.

**Risultato** Ogni regola può ricevere risposta da persone che esistono.

**Vedi anche:** [Validazioni richieste](help:user.validation.required-count) · [Mantenere la coerenza](help:setup.consistent.overview)

<!-- anchor: setup.people.first-week -->
### La prima settimana dei suoi membri

**Destinatari:** Proprietario · Amministratore

Vuole che i suoi primi membri riescano senza doverle chiedere nulla. Ciò che dice loro nella prima settimana decide quanto dovrà rispondere nella seconda.

*Prima di invitare qualcuno*

1. Acceda come seconda persona con un account di prova e partecipi al suo spazio. Verifichi di poter aprire la planimetria e prenotare un posto.
2. Approvi quell’account come membro e, se ne richiede due, faccia approvare anche il secondo validatore.

**Passaggi**

1. Invii il messaggio d’invito. Dice come scaricare l’app, creare un account e partecipare. Veda [Entrare in uno spazio di lavoro](help:user.start.join).
2. Approvi ogni nuovo arrivato lo stesso giorno. Una persona che attende un giorno intero comincia con un dubbio.
3. Dica loro le prime tre cose: la planimetria e la prenotazione ([Prenotare un posto](help:user.reserve.book)), la registrazione dell’arrivo ([Arrivo e partenza](help:user.reserve.check-in)) e dove attendono le loro richieste ([Eventi](help:user.collaborate.events)).
4. Dica loro che cosa vede di loro e che cosa controllano ([Chi può vedere i miei dati](help:user.privacy.visibility)).
5. Indichi una persona a cui chiedere, e dove: la messaggistica o la scrivania.

**Da sapere**

- Quando un amministratore fa qualcosa per un membro, resta in sospeso finché il membro non conferma. Li avvisi, altrimenti la prima prenotazione che fa per qualcuno sembrerà un errore.
- I membri che non usano le notifiche push trovano comunque tutto sotto **Eventi**.
- Alla prima visita di Prenota, la scheda **Primi passi** mostra ai proprietari che cosa manca ancora. I membri hanno i loro brevi suggerimenti. Veda [La scheda Primi passi e i suggerimenti](help:user.start.get-started).

**Risultato** Persone che sanno come prenotare, come registrare l’arrivo e a chi chiedere.

**Vedi anche:** [Dalla settimana 0 alla settimana 4](help:setup.training.overview) · [Come vengono informati i membri](help:setup.notify.members)
