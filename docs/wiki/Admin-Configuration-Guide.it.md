# Guida dell'amministratore — configurare lo spazio

Per chi mette in piedi lo spazio: che cosa decide ogni parametro,
nell'ordine in cui il questionario li chiede, poi i dati anagrafici, poi
la piantina e le sue immagini. La parte tecnica sta nella
[guida tecnica](Admin-Technical-Guide) (in inglese); spostare una
configurazione da uno spazio di sviluppo a uno di produzione sta nella
[guida degli ambienti](Environments-Guide.it).

<!-- anchor: config.setup.questionnaire -->
## Il questionario di installazione

Il questionario web chiede, nell'ordine, solo ciò che le risposte
precedenti rendono possibile, e produce il file di spazio che l'app
importa. Ogni domanda che vi compare esiste come parametro nell'app, e
ogni parametro dell'app compare lì — quella simmetria è una regola, non
una coincidenza.

<!-- image: config-setup-questionnaire -->

<!-- anchor: config.identity.legal -->
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
[guida utente](Guida-utente), § 11a — il simbolo di aiuto accanto apre
esattamente il suo paragrafo.

Le **istruzioni di pagamento** (il blocco bancario che un documento
stampa) sono un'entità separata, quindi si distribuiscono da sole tra uno
spazio di sviluppo e uno di produzione.

<!-- anchor: config.vat.overview -->
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

<!-- anchor: config.tariffs.overview -->
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

<!-- anchor: config.services -->
## Servizi

Tutto ciò che si vende e non è una postazione: un'ora di sala riunioni,
un pacchetto di stampe, un armadietto, un abbonamento al caffè. Un
servizio ha un nome, un prezzo, un gruppo IVA e un'unità, e un
amministratore può metterlo su una fattura o collegarlo a un pacchetto.

I servizi si distribuiscono tra uno spazio di sviluppo e uno di
produzione come entità propria — e poiché portano un gruppo IVA anziché
una percentuale, le aliquote viaggiano con loro.

<!-- anchor: config.packages -->
## Pacchetti giornalieri

Una giornata venduta come una cosa sola: una postazione, un armadietto e
due ore di sala riunioni, a un unico prezzo. Un pacchetto raggruppa
servizi e una dotazione di postazioni, porta il proprio gruppo IVA, e
compare in fattura come una riga con le sue parti elencate sotto quando
il layout lo richiede.

Usa un pacchetto dove un membro non dovrebbe doversi comporre la giornata
da solo, e un abbonamento dove l'unità è il mese.

<!-- anchor: config.accessories -->
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

<!-- anchor: config.sites -->
## Sedi

Più indirizzi sotto una stessa organizzazione: quale ne nomina un
documento, quale iscrizione porta, e come un membro è collegato a una di
esse.

<!-- anchor: config.availability -->
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

<!-- anchor: config.plan.overview -->
## La piantina

La piantina è ciò su cui i membri prenotano. È costruita con tre forme
annidate sopra un'immagine di sfondo, su una griglia la cui cella è
l'unità di posizionamento. Costruiscila in quest'ordine: prima il piano e
il suo sfondo, poi gli uffici, poi i tavoli e le postazioni. Tutto quanto
segue si ricalca sopra l'immagine, mai a memoria.

<!-- anchor: config.plan.levels -->
### Piani

Un piano è un livello dell'edificio, o un insieme di stanze trattato come
uno solo. Porta la sua **sede** (a quale indirizzo appartiene), la sua
**immagine di sfondo** e, quando è prenotabile per intero, il suo
**prezzo per mezza giornata** e il suo gruppo IVA.

*Prenotabile per intero* è un interruttore sul piano stesso. Senza di
esso, una richiesta di prenotare l'intero piano viene rifiutata indicando
quale interruttore manca — il rifiuto nomina l'impostazione invece di
dare la colpa al membro.

<!-- anchor: config.plan.offices -->
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

<!-- anchor: config.plan.background -->
### L'immagine di sfondo

Una piantina si legge meglio sopra un disegno della stanza reale.
L'immagine è per piano, sta sotto la griglia, e non si muove più una
volta ricalcate sopra le postazioni.

<!-- image: config-plan-background -->

<!-- anchor: config.plan.ai-image -->
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

<!-- anchor: config.plan.images -->
### Immagini della piantina

Immagini posate *sopra* la piantina anziché sotto — un logo vicino
all'ingresso, un cartello, la foto di un angolo —, ciascuna con la
propria posizione e dimensione sulla griglia. Sono decorazione: su di
esse non si prenota nulla, e stanno sopra lo sfondo e sotto le
postazioni.

Viaggiano con la piantina quando viene distribuita, e il file di spazio
se le porta all'esportazione.

<!-- anchor: config.documents -->
## Biblioteca dei documenti

File che lo spazio conserva e mostra a chi ha diritto di vederli: il
regolamento interno, un certificato di assicurazione, una pianta di
evacuazione, un modello di accordo per i membri. Ogni documento porta i
ruoli che possono leggerlo, quindi la biblioteca è un unico posto con
visibilità per ruolo invece di più cartelle.

I *layout* dei documenti — l'impaginazione di una fattura o di una
lettera — sono un'altra cosa, e stanno nella
[guida tecnica](Admin-Technical-Guide) (in inglese).

<!-- anchor: config.roles -->
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

<!-- anchor: config.validation -->
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

<!-- anchor: config.features -->
## Funzionalità

Ogni funzionalità è un interruttore. Che cosa spegne un interruttore, che
cosa non spegne mai (l'aritmetica già applicata), e il grafo delle
dipendenze che decide quali interruttori siano disponibili.
