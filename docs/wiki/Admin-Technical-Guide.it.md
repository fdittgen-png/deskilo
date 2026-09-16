# Guida dell'amministratore — la parte tecnica

Per chi tiene in piedi uno spazio DesKilo: i documenti che stampa, i file
che scambia, i servizi con cui parla e la base dati che sta sotto. La
configurazione di tutti i giorni sta nella
[guida di configurazione](Admin-Configuration-Guide.it); quello che vede
un membro sta nella [guida utente](Guida-utente).

*Uno spazio segnato `<!-- image: … -->` è una schermata che la catena non
ha ancora ricevuto.*

<!-- anchor: admin.reports.overview -->
## Documenti e report

Tutto ciò che DesKilo stampa — una fattura, un sollecito, una lettera a
un membro, un report di consumo, una dichiarazione IVA, un foglio di
badge — esce da un solo motore. Un **tipo di documento** lo nomina; un
**progetto** dice che aspetto ha; i **dati** che l'app gli consegna sono
un vocabolario fisso di segnaposto.

<p><img src="images/admin-reports-editor.jpg" width="240"></p>

*L'editor dei report: i selettori di lingua e documento in alto, gli interruttori Marcatura / Visivo e Progetto / Anteprima sotto, e le bande della fattura — intestazione, corpo, piè di pagina — più giù.*

<!-- anchor: admin.reports.kinds -->
### I tipi e i quattro modelli

Ogni tipo (fattura, nota di credito, proforma, estratto conto, accordo,
pagamenti, consumo, IVA, spazio) parte da uno dei quattro modelli —
*Semplice*, *Classico*, *Dettagliato*, *Lettera formale* — che
differiscono solo per quanto dicono, mai per ciò che la legge richiede.

<!-- anchor: admin.reports.bands -->
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

<!-- anchor: admin.reports.layouts -->
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

<!-- anchor: admin.reports.placeholders -->
### Il vocabolario

Ogni segnaposto che il motore conosce, per famiglia di documento, con i
cicli (`lines`, `vat`, `usage_records`, …) e i campi che ogni riga porta.
`dart run tool/report.dart describe` stampa l'elenco corrente — è
generato dallo stesso registro che legge il renderer, quindi non può mai
essere superato.

<!-- anchor: admin.reports.operators -->
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

<!-- anchor: admin.reports.window -->
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

<!-- anchor: admin.reports.cli -->
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

<!-- anchor: admin.einvoice.overview -->
## Fatturazione elettronica

Una fattura lascia DesKilo come un PDF che legge una persona e un file
strutturato che legge una macchina, e i due dicono la stessa cosa perché
sono prodotti dallo stesso documento congelato.

<!-- anchor: admin.einvoice.formats -->
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

<!-- anchor: admin.einvoice.readiness -->
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

<!-- anchor: admin.einvoice.platforms -->
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

<!-- anchor: admin.exports.accounting -->
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

<!-- anchor: admin.integrations.overview -->
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

<!-- anchor: admin.instances.overview -->
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

<!-- anchor: admin.trace.overview -->
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
