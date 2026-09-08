# Ambienti — uno spazio per provare, uno spazio che è reale

Due spazi, un solo nome. Su uno configuri, importi, stampi e rompi cose;
sull'altro le persone prenotano posti e ricevono fatture che sono
dovute. Ciò che fissi sul primo, lo distribuisci sul secondo.

<!-- anchor: env.pair.why -->
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

<!-- image: env-pair-profiles -->

<!-- anchor: env.pair.create -->
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

<!-- anchor: env.pair.permissions -->
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

<!-- anchor: env.work.configure -->
## Lavorare sul lato sviluppo

Configura, importa un file di spazio, invita un collega, emetti una
fattura di prova, sposta posti, stampa. Nulla lì è reale: la filigrana
lo dice su ogni documento, e l'endpoint di prova della fattura
elettronica rifiuta di raggiungere una piattaforma governativa.

<!-- anchor: env.deploy.screen -->
## Distribuire

*Impostazioni → Amministrazione → Distribuzione*, sul lato che vuoi
**scrivere**. Una distribuzione va sempre **nel lato in cui ti trovi**:
sul lato produzione il pulsante dice *Tira da DEV*, su quello di
sviluppo *Tira da PROD*. Nulla può essere spinto sull'altro lato per
errore.

<!-- image: env-deploy-screen -->

<!-- anchor: env.deploy.entities -->
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

<!-- anchor: env.deploy.plan -->
### La piantina è unita, mai sostituita

I piani si corrispondono per nome, gli uffici, i tavoli e i posti per
nome o, senza nome, per posizione. Ciò che ha l'altro lato è aggiunto o
aggiornato; ciò che ha solo questo lato è segnalato e **conservato**,
perché un posto può già portare una prenotazione. I badge e i blocchi
non viaggiano mai. Gli sfondi e le immagini della piantina sono copiati
insieme.

<!-- anchor: env.deploy.preview -->
### L'anteprima, poi la conferma

Nulla si muove prima che un'anteprima dica, per entità, cosa verrebbe
aggiunto, cambiato e rimosso. Un'anteprima senza nulla da fare lo dice e
non distribuisce niente. Poi una conferma nomina il lato che sta per
essere scritto e le entità, perché quello è il momento in cui un errore
diventa caro.

<!-- anchor: env.deploy.journal -->
### Il giornale e la via del ritorno

Ogni distribuzione è registrata: chi, quando, in quale direzione, quali
entità, e cosa conteneva la destinazione prima. *Annulla* sull'ultima
ripristina esattamente quello. Un annullamento è rifiutato finché una
distribuzione successiva insiste sullo stesso lato — annullale in
ordine.

<!-- anchor: env.deploy.never -->
### Cosa non viaggia mai

I membri, le prenotazioni, i conti, le fatture, i pagamenti, gli eventi,
i messaggi, le credenziali di ogni tipo e i contatori di numerazione.
Una serie di numeri si distribuisce come **formato**; il numero
successivo appartiene sempre allo spazio che lo emette.

<!-- anchor: env.instances -->
## Quando una coppia non basta

Due spazi condividono un database. Dove dati personali o credenziali di
pagamento devono essere fisicamente separati, accoppia invece
**istanze**: la procedura guidata di nuova istanza costruisce un secondo
database dal pacchetto, e le stesse entità viaggiano tra i due
attraverso il file di spazio.
