<!-- anchor: user.invoicing.overview -->
## Impuestos, facturación y contabilidad

Para propietarios y administradores de facturación: quién es usted como vendedor, cómo se trata el IVA, adónde van las facturas electrónicas, qué aspecto tienen sus documentos y el ritmo mensual de emitir, enviar y reclamar facturas.

> **Atención** DesKilo imprime lo que usted declara y comprueba que estén presentes los datos obligatorios. No certifica sus facturas, su tratamiento del IVA ni su contabilidad. Cada vez que una sección siguiente diga «consúltelo con su gestor», hágalo.

En este capítulo:
- Lo que emite la aplicación por sí misma y lo que queda en manos de su gestor
- Su identidad legal y las menciones que se imprimen en cada factura
- IVA: régimen, número, tipos, grupos y la declaración periódica
- Facturación electrónica: adónde se envía la factura legible por máquina
- La plantilla PDF de factura y el editor de informes
- Emitir y cerrar un mes: la pantalla de Facturación, el asistente de cierre mensual, la reagrupación, los gastos compartidos
- Recordatorios de pago
- El registro de facturas, las exportaciones contables y el análisis de negocio

<!-- anchor: user.invoicing.scope -->
### Lo que emite la aplicación y lo que queda en manos de su gestor

**Público:** Propietario · Administrador/a de facturación

Quiere saber, antes de confiar en ella, qué facturas emite DesKilo por sí mismo y cuáles sigue emitiendo con su gestor. Este es el alcance de esta versión.

| Situación | En la aplicación | Fuera de la aplicación |
|---|---|---|
| Un espacio en Francia o Alemania, sujeto al IVA o fuera del ámbito del IVA | Facturas emitidas, numeradas, enviadas y seguidas | — |
| Un puesto, una oficina o una sala, sea quien sea el cliente, también en el extranjero | Emitidas con su IVA: el lugar de la prestación es el edificio | — |
| Un espacio en otro país | Reservas, extractos y pagos | Las facturas, con su gestor |
| El régimen exento de IVA | — | Las facturas, con su gestor |
| Inversión del sujeto pasivo, exportación, comprador exento | Registrado en el miembro | Las facturas, con su gestor |
| Factura electrónica | El archivo EN 16931, enviado a la plataforma que usted configura | La elección de la plataforma y lo que le exige el sistema nacional |
| Contabilidad | Exportaciones reconstruidas a partir de facturas y pagos | El libro mayor, el cierre y las cuentas |
| Declaración de IVA | Los importes, calculados a partir de facturas y pagos | Su presentación ante la administración tributaria |

**Conviene saber**

- La factura electrónica tiene tres pasos: DesKilo produce la factura estructurada; el conector la envía a su plataforma; la plataforma la hace llegar al cliente y a la administración según el sistema nacional. Un archivo válido es solo el primer paso.
- En Francia, solo una plataforma autorizada (plateforme agréée) puede transmitir facturas dentro de la reforma, y DesKilo no lo es: configure la plataforma que elija. Todas las empresas afectadas deben poder recibir facturas electrónicas a partir del 1 de septiembre de 2026; las pymes y las microempresas deben emitirlas a partir del 1 de septiembre de 2027.
- DesKilo no lleva una contabilidad por partida doble: su gestor completa los archivos exportados.
- Esta tabla cambia con la aplicación. Cuando una fila pasa a la aplicación, esta sección lo dice.

**Véase también:** [Emitir una factura](help:user.invoicing.new-invoice) · [La plataforma de facturación electrónica](help:user.money.einvoice.overview) · [Exportaciones contables](help:user.invoicing.accounting-export) · [Régimen de IVA](help:user.money.vat.regime)

<!-- anchor: user.money.legal.identity -->
### Su identidad legal

**Público:** Propietario

Quiere que sus facturas le nombren correctamente: quién es, cómo está registrado y cómo cobra el IVA.

**Pasos**

1. Abra [Espacio de coworking](app:/workspace-settings) y pulse **Identidad legal y facturación electrónica**, o vaya directamente a [Identidad legal y facturación electrónica](app:/legal-identity).
2. Trabaje de arriba abajo: primero el régimen de IVA, después los identificadores, la dirección y las **Menciones de facturación**.
3. Pulse **Guardar** en la parte inferior.

**Conviene saber**

- La pantalla solo muestra los campos que necesita su régimen de IVA. Si cambia el régimen, el formulario lo sigue.
- Las facturas ya emitidas conservan la identidad con la que se firmaron. Un cambio se aplica a las siguientes.
- Solo los propietarios pueden abrir esta pantalla.

**Véase también:** [Régimen de IVA](help:user.money.vat.regime) · [Tipo de organización](help:user.money.legal.seller-kind) · [Facturación electrónica](help:user.money.einvoice.overview)

<!-- anchor: user.money.legal.seller-kind -->
### Tipo de organización

**Público:** Propietario

Usted dirige una empresa o una asociación sin ánimo de lucro, y sus facturas deben reflejarlo.

<p><img src="images/user-money-legal-seller-kind--f.es.jpg" width="280"></p>

**Pasos**

1. Abra [Identidad legal y facturación electrónica](app:/legal-identity) y baje hasta **Menciones de facturación**.
2. Elija **Empresa** o **Asociación (sin ánimo de lucro)**.
3. Pulse **Guardar**.

**Conviene saber**

- Para una asociación, los textos de ejemplo cambian (por ejemplo, un registro como el RNA en lugar de un registro mercantil). Qué cláusulas de pago se imprimen depende de su país y de la condición del cliente, no del tipo de organización.
- Una asociación sin actividad comercial normalmente queda fuera del ámbito del IVA. La pantalla le avisa si elige «exento» para una asociación; confirme la opción correcta con su gestor.

**Véase también:** [Condición del cliente](help:user.money.legal.customer-capacity) · [Régimen de IVA](help:user.money.vat.regime)

<!-- anchor: user.money.legal.customer-capacity -->
### Condición del cliente por defecto

**Público:** Propietario

A las empresas clientes y a los particulares no se les deben las mismas cláusulas de pago. Usted define el valor por defecto del espacio.

<p><img src="images/user-money-legal-customer-capacity--f.es.jpg" width="280"></p>

**Pasos**

1. En **Menciones de facturación**, busque **Condición del cliente por defecto**.
2. Elija **Sin indicar**, **Empresa** o **Consumidor**.
3. Pulse **Guardar**.

**Conviene saber**

- Los valores legales por defecto de penalización por demora, indemnización de cobro y descuento solo se aplican a clientes empresa de un espacio en Francia; para otros países no se imprime nada salvo lo que haya escrito usted. Un consumidor nunca recibe la indemnización de cobro.
- La condición propia de un miembro prevalece sobre este valor por defecto.
- Cada factura conserva las cláusulas con las que se emitió.

**Véase también:** [Penalización por demora](help:user.money.legal.late-penalty) · [Indemnización de cobro](help:user.money.legal.recovery)

<!-- anchor: user.money.legal.legal-form -->
### Forma jurídica y capital

**Público:** Propietario

Sus facturas indican la forma jurídica de su empresa y, si procede, su capital social.

<p><img src="images/user-money-legal-legal-form--f.es.jpg" width="280"></p>

**Pasos**

1. En **Menciones de facturación**, pulse **Forma jurídica y capital**.
2. Escriba la línea tal como debe imprimirse, por ejemplo «SARL au capital de 7 500 €» (una asociación podría escribir «Association loi 1901»).
3. Pulse **Guardar**.

**Conviene saber**

- El texto se imprime tal como lo escribe, hasta 300 caracteres. Consulte con su gestor la redacción exacta que exige su forma jurídica.

**Véase también:** [Registro mercantil](help:user.money.legal.registration)

<!-- anchor: user.money.legal.registration -->
### Registro mercantil

**Público:** Propietario

Indica dónde está registrada su organización.

<p><img src="images/user-money-legal-registration--f.es.jpg" width="280"></p>

**Pasos**

1. En **Menciones de facturación**, pulse **Registro mercantil**.
2. Escriba la línea de registro, por ejemplo «RCS Saint-Brieuc 680 357 910». Una asociación podría introducir un número RNA, y un SIRET si lo tiene.
3. Pulse **Guardar**.

**Conviene saber**

- Esta línea es una mención impresa en el documento. El identificador que necesita la propia factura electrónica es el [número de registro](help:user.money.legal.legal-id) o el [número de IVA](help:user.money.vat.number), según su régimen.

**Véase también:** [Forma jurídica y capital](help:user.money.legal.legal-form)

<!-- anchor: user.money.legal.payment-terms -->
### Condiciones de pago

**Público:** Propietario

Indica cuándo vencen las facturas.

<p><img src="images/user-money-legal-payment-terms--f.es.jpg" width="280"></p>

**Pasos**

1. En **Menciones de facturación**, pulse **Condiciones de pago**.
2. Escriba sus condiciones, por ejemplo «Pago en un plazo de 30 días desde la fecha de la factura».
3. Pulse **Guardar**.

**Conviene saber**

- Si lo deja vacío, las facturas imprimen «Pago a la recepción».
- Un miembro puede tener sus propias condiciones de pago; estas se imprimen en los documentos de ese miembro en su lugar.
- Los recordatorios no leen este texto: cuentan desde la fecha de la factura más **Días hasta el primer recordatorio** en las reglas de recordatorio. Las condiciones de pago son solo lo que imprime el documento.

**Véase también:** [Reglas de recordatorio](help:user.money.reminders.rules)

<!-- anchor: user.money.legal.late-penalty -->
### Penalización por demora

**Público:** Propietario

Indica la penalización por pago tardío.

<p><img src="images/user-money-legal-late-penalty--f.es.jpg" width="280"></p>

**Pasos**

1. En **Menciones de facturación**, pulse **Penalización por demora**.
2. Escriba su cláusula, o déjela vacía.
3. Pulse **Guardar**.

**Conviene saber**

- Si lo deja vacío, no se inventa nada por usted, salvo en un espacio en Francia que factura a un cliente empresa: entonces se imprime la redacción legal (tres veces el tipo de interés legal).
- Confirme con su gestor la cláusula que se aplica a su país.

**Véase también:** [Condición del cliente por defecto](help:user.money.legal.customer-capacity)

<!-- anchor: user.money.legal.recovery -->
### Indemnización de cobro

**Público:** Propietario

Indica la indemnización fija por costes de cobro.

<p><img src="images/user-money-legal-recovery--f.es.jpg" width="280"></p>

**Pasos**

1. En **Menciones de facturación**, pulse **Indemnización de cobro**.
2. Escriba su cláusula, o déjela vacía.
3. Pulse **Guardar**.

**Conviene saber**

- Si lo deja vacío, la indemnización fija de 40 € solo se imprime en las facturas de un espacio en Francia a un cliente empresa.
- Un consumidor nunca recibe esta mención.

**Véase también:** [Condición del cliente por defecto](help:user.money.legal.customer-capacity)

<!-- anchor: user.money.legal.escompte -->
### Descuento por pronto pago

**Público:** Propietario

Indica si pagar antes da derecho a un descuento.

<p><img src="images/user-money-legal-escompte--f.es.jpg" width="280"></p>

**Pasos**

1. En **Menciones de facturación**, pulse **Descuento por pronto pago**.
2. Escriba las condiciones de su descuento, o déjelo vacío.
3. Pulse **Guardar**.

**Conviene saber**

- Si lo deja vacío, las facturas de un espacio en Francia a un cliente empresa imprimen «Sin descuento por pronto pago»; en otros casos la línea se omite salvo que escriba una.

**Véase también:** [Condiciones de pago](help:user.money.legal.payment-terms)

<!-- anchor: user.money.legal.insurance -->
### Seguro profesional

**Público:** Propietario

Si su actividad le obliga a indicar su seguro profesional, se imprime en sus facturas.

<p><img src="images/user-money-legal-insurance--f.es.jpg" width="280"></p>

**Pasos**

1. En **Menciones de facturación**, pulse **Seguro profesional**.
2. Escriba la aseguradora, la póliza y la cobertura geográfica tal como deben leerse.
3. Pulse **Guardar**.

**Conviene saber**

- No hay valor por defecto: un campo vacío no imprime nada.
- Si debe indicarlo o no depende de su actividad. Pregunte a su gestor.

**Véase también:** [Menciones particulares](help:user.money.legal.special-mentions)

<!-- anchor: user.money.legal.special-mentions -->
### Menciones particulares

**Público:** Propietario

Una línea propia que debe aparecer en todas las facturas.

<p><img src="images/user-money-legal-special-mentions--f.es.jpg" width="280"></p>

**Pasos**

1. En **Menciones de facturación**, pulse **Menciones particulares**.
2. Escriba el texto.
3. Pulse **Guardar**.

**Conviene saber**

- No se imprime nada cuando el campo está vacío.
- Bajo las menciones, cuando la función **Ventanilla de dirección** está activada, **Ventanilla de dirección** fija dónde se coloca la dirección del destinatario para que se vea a través de un sobre con ventanilla.

**Véase también:** [La plantilla PDF de factura](help:user.money.reports.invoice-template)

<!-- anchor: user.money.vat.regime -->
### Régimen de IVA

**Público:** Propietario

Declara cuál es la situación de su organización respecto al IVA. La elección decide qué número necesitan sus documentos.

<p><img src="images/user-money-vat-regime--f.es.jpg" width="280"></p>

**Pasos**

1. Abra [Identidad legal y facturación electrónica](app:/legal-identity).
2. En **Régimen de IVA**, elija **Fuera del ámbito del IVA**, **Exento de IVA (régimen de franquicia)** o **Sujeto a IVA (cobra IVA)**.
3. Pulse **Guardar**.

**Conviene saber**

- Fuera del ámbito del IVA: no se imprime ningún número de IVA; le identifica el número de registro.
- Exento o sujeto: se le pide su número de IVA.
- Elegir el régimen es una decisión fiscal, no un ajuste del programa. Confírmela con su gestor antes de emitir facturas.
- En esta versión la aplicación emite facturas por sí misma para espacios en Francia o Alemania, a clientes nacionales, bajo el régimen de sujeto a IVA o fuera del ámbito del IVA. Las facturas bajo el régimen exento se emiten fuera de la aplicación con su gestor.

**Véase también:** [Número de IVA](help:user.money.vat.number) · [Número de registro](help:user.money.legal.legal-id)

<!-- anchor: user.money.vat.reverse-charge -->
### Inversión del sujeto pasivo para empresas de la UE

**Público:** Propietario

Cuando cobra IVA y factura a una empresa de otro país de la UE, el impuesto puede correr a cargo del cliente.

<p><img src="images/user-money-vat-reverse-charge--f.es.jpg" width="280"></p>

**Pasos**

1. Elija **Sujeto a IVA (cobra IVA)** como régimen.
2. Active o desactive **Inversión del sujeto pasivo para empresas de la UE**.
3. Pulse **Guardar**.

**Conviene saber**

- Activado: un servicio general (no vinculado a los locales) a una empresa de otro país de la UE aplica la inversión del sujeto pasivo. Un puesto, una oficina o una sala nunca: lleva su IVA, sea cual sea el número de IVA del cliente. Hoy la aplicación no emite por sí misma las facturas con inversión del sujeto pasivo: usted las emite fuera de la aplicación con su gestor.
- Desactivado: desactívelo si nunca factura a empresas del extranjero.
- La opción solo aparece con el régimen de sujeto a IVA.

**Véase también:** [Tratamiento del IVA de un miembro](help:user.members.vat-treatment)

<!-- anchor: user.money.vat.due -->
### Cuándo se devenga el IVA

**Público:** Propietario

El IVA de cada factura se devenga el día que fija la ley de su país: con el cobro, al prestarse el servicio o con la factura. Usted conserva esa regla o elige la opción que su país permite.

<p><img src="images/user-money-vat-due--f.es.jpg" width="280"></p>

**Pasos**

1. Elija **Sujeto a IVA (cobra IVA)** como régimen.
2. En **Devengo del IVA**, conserve la primera opción, la regla legal de su país, o elija la opción que su país permite: **Con el cobro (criterio de caja)** en España, **Con la factura (criterio general)** en Francia.
3. Pulse **Guardar**.

**Conviene saber**

- La regla legal para los servicios: el cobro en Francia; el mes en que se presta el servicio en Alemania y España, los anticipos al cobrarse; la factura o el pago, lo que ocurra primero, en Italia, el Reino Unido y Canadá; la factura en Suiza.
- Con el cobro, una factura pagada a plazos cae en tantos periodos como pagos tuvo; con el criterio de caja, lo no cobrado se devenga el 31 de diciembre del año siguiente. Una nota de crédito cuenta al emitirse (con el cobro, al reembolsarse), nunca en el periodo de la factura que corrige.
- La elección se imprime en cada factura y determina por igual la [declaración de IVA](help:user.money.vat.declaration), el informe de IVA y las exportaciones FEC y DATEV.
- Qué opción le corresponde es una cuestión fiscal para su gestor.
- Una factura conserva la regla que imprimió: emitida según cobros, espera al pago; con la opción por el devengo a la emisión, es exigible al emitirse, elija lo que elija después el espacio.

**Véase también:** [Preparar la declaración del IVA](help:user.money.vat.declaration)

<!-- anchor: user.money.vat.account -->
### Cuenta de IVA

**Público:** Propietario

Su gestor quiere que el IVA repercutido se contabilice en una cuenta concreta.

<p><img src="images/user-money-vat-account--f.es.jpg" width="280"></p>

**Pasos**

1. Elija **Sujeto a IVA (cobra IVA)** como régimen.
2. Escriba su número de cuenta en **Cuenta de IVA**.
3. Pulse **Guardar**.

**Conviene saber**

- La exportación contable registra el IVA repercutido en esta cuenta. Si lo deja vacío, usa la 445710.

**Véase también:** [Exportaciones contables](help:user.invoicing.accounting-export)

<!-- anchor: user.money.vat.number -->
### Número de IVA

**Público:** Propietario

Su número de identificación de IVA aparece en sus facturas y facturas electrónicas.

<p><img src="images/user-money-vat-number--f.es.jpg" width="280"></p>

**Pasos**

1. Abra [Identidad legal y facturación electrónica](app:/legal-identity).
2. Escriba el número en **Número de IVA**.
3. Pulse **Guardar**.

**Conviene saber**

- El campo aparece para los regímenes exento y sujeto. Fuera del ámbito del IVA se sustituye por el número de registro.
- Sus miembros tienen su propio número de IVA en sus ajustes, para sus documentos.

**Véase también:** [Número de registro](help:user.money.legal.legal-id)

<!-- anchor: user.money.vat.exemption-reason -->
### Motivo por el que no se cobra IVA

**Público:** Propietario

Cuando no se cobra IVA, la ley suele exigir que el motivo figure impreso en la factura.

<p><img src="images/user-money-vat-exemption-reason--f.es.jpg" width="280"></p>

**Pasos**

1. Abra [Identidad legal y facturación electrónica](app:/legal-identity).
2. Escriba el fundamento legal en **Motivo por el que no se cobra IVA**, por ejemplo «TVA non applicable, art. 293 B du CGI».
3. Pulse **Guardar**.

**Conviene saber**

- La aplicación no puede saber qué fundamento le corresponde. Pida a su gestor la redacción exacta.
- La redacción se imprime en la factura. Por ahora la aplicación no emite por sí misma facturas bajo el régimen exento: se emiten fuera de la aplicación con su gestor.

**Véase también:** [Régimen de IVA](help:user.money.vat.regime)

<!-- anchor: user.money.legal.legal-id -->
### Número de registro

**Público:** Propietario

Si está fuera del ámbito del IVA, su número de registro le identifica en las facturas electrónicas.

<p><img src="images/user-money-legal-legal-id--f.es.jpg" width="280"></p>

**Pasos**

1. Ponga el **Régimen de IVA** en **Fuera del ámbito del IVA**.
2. Escriba el número en **Número de registro**.
3. Pulse **Guardar**.

**Conviene saber**

- Con los demás regímenes, este campo se sustituye por el número de IVA.
- Una asociación suele usar su registro (por ejemplo, el RNA, o el SIRET si se le ha asignado).

**Véase también:** [Registro mercantil](help:user.money.legal.registration)

<!-- anchor: user.money.legal.address -->
### Dirección estructurada

**Público:** Propietario

Una factura electrónica necesita su dirección en partes separadas, no en un único bloque de texto.

<p><img src="images/user-money-legal-address--f.es.jpg" width="280"></p>

**Pasos**

1. Abra [Identidad legal y facturación electrónica](app:/legal-identity).
2. Rellene **Calle**, **Código postal** y **Ciudad**.
3. Pulse **Guardar**.

**Conviene saber**

- La calle parte de la dirección que ya figura en los ajustes de su espacio, de modo que la completa en lugar de volver a escribirla.
- No se pueden emitir facturas sin la dirección postal del espacio.

**Véase también:** [Dirección del membrete](help:user.workspace.settings.address)

<!-- anchor: user.money.vat.rates -->
### Fijar los tipos

**Público:** Propietario · Administrador/a de facturación

Enumera los tipos de IVA que pueden usar sus facturas. Lo que pagan los miembros no cambia: los precios incluyen el IVA y el impuesto se extrae de ellos.

<p><img src="images/user-money-vat-rates--f.es.jpg" width="320"></p>

**Pasos**

1. Abra [IVA](app:/vat) (desde **Identidad legal y facturación electrónica**, pulse **Tipos de IVA**).
2. Con la lista vacía, pulse **Usar los tipos habituales** (si su país tiene un catálogo) para partir de los tipos de su país, o **Añadir un tipo** y rellene el nombre y **Tipo %** (de 0 a 99,99).
3. Pulse la estrella de exactamente un tipo para convertirlo en el tipo por defecto.
4. Pulse **Guardar**.

**Conviene saber**

- Los tipos habituales son un punto de partida. Qué operación va con qué tipo es una pregunta para su gestor.
- El tipo por defecto lo usan las suscripciones y todo lo que no tiene tipo propio.
- Un tipo que todavía usa una factura o un servicio se conserva, desactivado, en lugar de eliminarse.
- Si no hay ningún tipo por defecto en vigor mientras está sujeto a IVA, no se puede emitir ninguna factura; la pantalla de identidad legal lo advierte.
- Esta pantalla requiere la función **Gestión del IVA**; la entrada de tipos de IVA de la pantalla de identidad legal solo aparece con el régimen de sujeto a IVA.

**Véase también:** [Grupos de IVA](help:user.money.vat.groups) · [Cambio por ley](help:user.money.vat.change-by-law)

<!-- anchor: user.money.vat.groups -->
### Grupos de IVA

**Público:** Propietario · Administrador/a de facturación

Un grupo indica de qué clase es el tipo, para que la factura lo coloque en la categoría correcta.

<p><img src="images/user-money-vat-groups.es.jpg" width="320"></p>

**Pasos**

1. Abra [IVA](app:/vat).
2. En cada tipo, cuando la función **Grupos de IVA** está activada, elija un **Grupo**: **General**, **Intermedio**, **Reducido**, **Superreducido**, **Tipo cero**, **Exento**, **No sujeto**, **Envase retornable (fuera del IVA)** o **Con impuestos especiales**.
3. Para un grupo exento o no sujeto, rellene la **Mención de exención** que aparece.
4. Pulse **Guardar**.

**Conviene saber**

- **Qué entra en cada grupo** enumera ejemplos para su país, solo a modo orientativo.
- Una línea fuera del IVA, como un envase retornable, no puede compartir documento con líneas gravadas; emítala por separado.

**Véase también:** [Fijar los tipos](help:user.money.vat.rates)

<!-- anchor: user.money.vat.change-by-law -->
### Cambiar un tipo por ley

**Público:** Propietario · Administrador/a de facturación

Un tipo cambia a partir de una fecha determinada. Las operaciones antiguas conservan el valor antiguo; el nuevo se aplica desde ese día.

<p><img src="images/user-money-vat-change-by-law.es.jpg" width="320"></p>

**Pasos**

1. Abra [IVA](app:/vat) y asegúrese de que el tipo está guardado.
2. Pulse el botón **Cambio por ley** del tipo.
3. Escriba **Nuevo tipo %** y la **Fecha de efecto (AAAA-MM-DD)**.
4. Pulse **Guardar** en el cuadro de diálogo y después **Guardar** en la pantalla.

**Conviene saber**

- El tipo antiguo se cierra en esa fecha y se abre uno nuevo, con la estrella trasladada si era el tipo por defecto.
- Nada de lo ya emitido se reasigna.

**Véase también:** [Fijar los tipos](help:user.money.vat.rates)

<!-- anchor: user.money.vat.declaration -->
### Preparar la declaración del IVA

**Público:** Propietario

Quiere el IVA de un periodo calculado a partir de sus facturas y cobros, listo para presentarlo ante la administración tributaria o entregarlo a su gestor.

<p><img src="images/user-money-vat-declaration.es.jpg" width="280"></p>

**Pasos**

1. Abra [Declaración de IVA](app:/vat-declarations).
2. Elija el **Periodo** y pulse **Preparar**.
3. Abra el resultado con **PDF** o **Exportar XML**, o consulte el **Informe de IVA (PDF)** y el **Informe de IVA (CSV)**.
4. Presente usted mismo la declaración ante la administración tributaria (o a través de su gestor), pulse **Marcar como presentada** e introduzca la **Referencia del justificante de la administración tributaria**.

**Conviene saber**

- Solo existe con el régimen de sujeto a IVA. La nota de arriba indica cuándo se devenga el IVA del periodo.
- El servidor calcula los importes a partir de las facturas, de los cobros registrados uno a uno y del devengo de cada factura. Cada tipo se desglosa por categoría: tipo general, inversión del sujeto pasivo, exenta y tipo cero quedan separadas. Las facturas de agrupación se excluyen; su cobro cuenta para las facturas que agrupan.
- Una declaración pasa de **Borrador** a **Preparada** y luego a **Presentada**. Prepararla de nuevo sustituye los importes; una vez presentada, nada la modifica. Si una factura o un cobro del periodo ha cambiado desde la preparación, la aplicación se niega a marcarla como presentada hasta que la prepare de nuevo.
- La aplicación no transmite declaraciones: Francia presenta por EDI-TVA o el espacio profesional de impots.gouv, Alemania por ELSTER. La plataforma de facturación electrónica solo transporta facturas.
- Es una ayuda para la presentación, no un asesoramiento fiscal. Verifíquela con su contabilidad antes de presentarla.

**Véase también:** [Cuándo se devenga el IVA](help:user.money.vat.due) · [Exportaciones contables](help:user.invoicing.accounting-export)

<!-- anchor: user.money.einvoice.overview -->
### La plataforma de facturación electrónica

**Público:** Propietario · Administrador/a de facturación

Indica a DesKilo dónde enviar sus facturas como archivos legibles por máquina.

<p><img src="images/user-money-einvoice-overview--f.es.jpg" width="280"></p>

**Pasos**

1. Abra [Plataforma de facturación electrónica](app:/einvoice-config) (también accesible desde **Identidad legal y facturación electrónica**).
2. Rellene **URL de subida** y **Token o credencial**, y los dos campos opcionales si su plataforma los pide.
3. Pulse **Guardar**. **Eliminar la plataforma** borra los ajustes.

**Conviene saber**

- Sirve cualquier plataforma que acepte una subida con un token: una plataforma homologada, un punto de acceso Peppol, una plataforma nacional.
- El token se guarda en el servidor y no vuelve a mostrarse.
- El archivo válido es una factura EN 16931. Si su país exige una plataforma, y cuál, es algo que debe confirmar con su gestor.
- Enviar el archivo es el segundo de tres pasos: véase [Lo que emite la aplicación y lo que queda en manos de su gestor](help:user.invoicing.scope).

**Véase también:** [Enviar una factura electrónica](help:user.money.einvoice.send) · [Identidad legal](help:user.money.legal.identity)

<!-- anchor: user.money.einvoice.endpoint -->
### URL de subida

**Público:** Propietario · Administrador/a de facturación

La dirección en la que su plataforma recibe las facturas.

<p><img src="images/user-money-einvoice-endpoint--f.es.jpg" width="280"></p>

**Pasos**

1. Abra [Plataforma de facturación electrónica](app:/einvoice-config).
2. Pegue la dirección en **URL de subida**, exactamente como la documenta su plataforma.
3. Pulse **Guardar**.

**Conviene saber**

- Procede de la documentación de su plataforma o de su proveedor.

**Véase también:** [Token o credencial](help:user.money.einvoice.token)

<!-- anchor: user.money.einvoice.token -->
### Token o credencial

**Público:** Propietario · Administrador/a de facturación

El secreto que demuestra a la plataforma que la subida es suya.

<p><img src="images/user-money-einvoice-token--f.es.jpg" width="280"></p>

**Pasos**

1. Abra [Plataforma de facturación electrónica](app:/einvoice-config).
2. Pegue la clave en **Token o credencial**.
3. Pulse **Guardar**.

**Conviene saber**

- Una vez guardado, la pantalla dice «Hay un token guardado». Escriba uno nuevo solo para sustituirlo.
- Se conserva en el servidor y nunca sale de él.

**Véase también:** [Cabecera de autenticación](help:user.money.einvoice.auth-header)

<!-- anchor: user.money.einvoice.auth-header -->
### Cabecera de autenticación

**Público:** Propietario · Administrador/a de facturación

El nombre de la cabecera que lleva el token.

<p><img src="images/user-money-einvoice-auth-header--f.es.jpg" width="280"></p>

**Pasos**

1. Abra [Plataforma de facturación electrónica](app:/einvoice-config).
2. Si su plataforma espera otra cabecera distinta de la estándar, escriba su nombre en **Cabecera de autenticación (Authorization por defecto)**.
3. Pulse **Guardar**.

**Conviene saber**

- Si lo deja vacío, se usa **Authorization**.

**Véase también:** [Nombre del campo de archivo](help:user.money.einvoice.file-field)

<!-- anchor: user.money.einvoice.file-field -->
### Nombre del campo de archivo

**Público:** Propietario · Administrador/a de facturación

El nombre del campo del formulario que lleva el archivo de la factura.

<p><img src="images/user-money-einvoice-file-field--f.es.jpg" width="280"></p>

**Pasos**

1. Abra [Plataforma de facturación electrónica](app:/einvoice-config).
2. Si su plataforma espera otro nombre de campo, escríbalo en **Nombre del campo de archivo (file por defecto)**.
3. Pulse **Guardar**.

**Conviene saber**

- Si lo deja vacío, se usa **file**.

**Véase también:** [URL de subida](help:user.money.einvoice.endpoint)

<!-- anchor: user.money.einvoice.customer-delivery -->
### Servicio de entrega al cliente

**Público:** Propietario · Administrador/a de facturación

Es posible que su cliente reciba sus facturas en otro lugar que no sea una plataforma gubernamental: su propio punto de acceso Peppol, un portal o un servicio de subida acordado.

<p><img src="images/user-money-einvoice-customer-delivery--f.es.jpg" width="280"></p>

**Pasos**

1. Abra [Plataforma de facturación electrónica](app:/einvoice-config).
2. En **Servicio de entrega al cliente**, rellene los mismos cuatro campos que arriba.
3. Pulse **Guardar**.

**Conviene saber**

- Es independiente de la plataforma gubernamental. Pueden configurarse ambas, y cada factura ofrece los dos envíos.

**Véase también:** [Enviar una factura electrónica](help:user.money.einvoice.send)

<!-- anchor: user.money.einvoice.uat -->
### Endpoint y token UAT

**Público:** Propietario · Administrador/a de facturación

Quiere hacer un ensayo antes de enviar facturas reales.

<p><img src="images/user-money-einvoice-uat--f.es.jpg" width="280"></p>

**Pasos**

1. Abra [Plataforma de facturación electrónica](app:/einvoice-config).
2. Bajo **Entornos de prueba (UAT / Dev)**, rellene **URL de subida UAT** y **Token o credencial UAT**.
3. Pulse **Guardar**.

**Conviene saber**

- La elección del entorno solo aparece al enviar mientras el modo desarrollador está activado.
- Un envío de prueba se registra como envío de prueba.

**Véase también:** [Endpoint y token Dev](help:user.money.einvoice.dev)

<!-- anchor: user.money.einvoice.dev -->
### Endpoint y token Dev

**Público:** Propietario · Administrador/a de facturación

Un segundo endpoint de prueba, para desarrollo.

<p><img src="images/user-money-einvoice-dev--f.es.jpg" width="280"></p>

**Pasos**

1. Abra [Plataforma de facturación electrónica](app:/einvoice-config).
2. Bajo **Entornos de prueba (UAT / Dev)**, rellene **URL de subida Dev** y **Token o credencial Dev**.
3. Pulse **Guardar**.

**Conviene saber**

- Las mismas reglas que para UAT. El envío real va siempre al endpoint de producción.

**Véase también:** [Endpoint y token UAT](help:user.money.einvoice.uat)

<!-- anchor: user.money.einvoice.send -->
### Enviar una factura electrónica

**Público:** Propietario · Administrador/a de facturación

Quiere entregar una factura emitida en su forma legible por máquina.

**Pasos**

1. Abra una factura en [Facturación](app:/invoices) y pulse **Factura electrónica (XML)**.
2. Lea la comprobación de la parte superior de la hoja: indica si el archivo está listo o qué falta.
3. Pulse **Enviar a la plataforma gubernamental**, **Enviar al servicio del cliente**, o descargue o comparta el archivo (**Descargar Factur-X (PDF)** lleva el XML dentro del PDF).

**Conviene saber**

- Si falta algo, la hoja lo enumera. **Completar la identidad legal** le lleva a la pantalla que lo corrige.
- Una factura firmada antes de que completara su identidad conserva lo que tenía al emitirse. Márquela como errónea y emita una sustitutiva si es importante.
- Qué canal debe usar un cliente depende de su país y del cliente. Confírmelo con su gestor.

**Véase también:** [La plataforma de facturación electrónica](help:user.money.einvoice.overview) · [La pantalla de Facturación](help:user.invoicing.hub)

<!-- anchor: user.money.reports.invoice-template -->
### La plantilla PDF de factura

**Público:** Propietario · Administrador/a de facturación

Quiere que sus facturas se parezcan a usted: logotipo, maquetación, redacción.

<p><img src="images/user-money-reports-invoice-template.es.jpg" width="280"></p>

**Pasos**

1. Abra [Informes](app:/reports?section=templates) y la pestaña **Plantillas**.
2. Pulse **Editor de informes**.

**Conviene saber**

- La plantilla cambia solo el PDF. El XML de la factura electrónica nunca se toca.
- Puede hacerlo cualquier persona con permiso para diseñar documentos.
- Una plantilla que no se genera nunca bloquea un documento: entra en juego la maquetación integrada.

**Véase también:** [El editor de informes](help:user.money.reports.editor)

<!-- anchor: user.money.reports.editor -->
### El editor de informes

**Público:** Propietario · Administrador/a de facturación

Diseña un documento sobre una página, en lugar de escribir código.

<p><img src="images/user-money-reports-editor.es.jpg" width="280"></p>

**Pasos**

1. Abra [Editor de informes](app:/report-editor).
2. Elija el documento con las etiquetas (Factura, Proforma, Extracto, recordatorios y los demás informes).
3. En **Diseño**, pulse una línea para editarla, añada líneas o arrastre para reordenar. Pulse **Vista previa** para verlo con sus datos.
4. Pulse **Guardar**.

**Conviene saber**

- El modo **Marcado** edita las mismas bandas como texto.
- **Insertar imagen** coloca un logotipo, un sello o una firma de la biblioteca de imágenes.
- **Vista rápida** se genera al instante con su factura más reciente, o con datos de ejemplo si no hay ninguna. **Restablecer al modelo por defecto** recupera la maquetación integrada.
- **Exportar este diseño** e **Importar un diseño** llevan un diseño de entrada y de salida como archivo. **Maqueta posicionada (XML)** es para documentos que deben ajustarse a un sobre con ventanilla o a un formulario nacional.
- Si sale con trabajo sin guardar, se le pregunta antes.

**Véase también:** [Plantillas y modelos](help:user.money.reports.presets) · [Idiomas](help:user.money.reports.languages)

<!-- anchor: user.money.reports.presets -->
### Plantillas ya preparadas

**Público:** Propietario · Administrador/a de facturación

Parte de un diseño terminado y cambia lo que quiera.

<p><img src="images/user-money-reports-presets.es.jpg" width="280"></p>

**Pasos**

1. Abra [Editor de informes](app:/report-editor) y elija un documento.
2. Pulse **Plantillas** y elija **Profesional**, **Clásico**, **Sencillo**, **Detallado** o **Carta formal**.
3. Confirme la sustitución si la aplicación se lo pide, edite y **Guardar**.

**Conviene saber**

- Sustituir una maquetación se puede deshacer con **Deshacer**.
- Los informes estructurales (plan contable, credenciales, tarjetas QR) tienen una única maquetación incluida.
- Las plantillas de factura ya incluyen sus menciones legales. Aun así, imprimen únicamente lo que usted introdujo en [Menciones de facturación](help:user.money.legal.identity).

**Véase también:** [El editor de informes](help:user.money.reports.editor)

<!-- anchor: user.money.reports.languages -->
### Un diseño por idioma

**Público:** Propietario · Administrador/a de facturación

Sus miembros leen sus documentos en su propio idioma.

<p><img src="images/user-money-reports-languages--f.es.jpg" width="280"></p>

**Pasos**

1. Abra [Editor de informes](app:/report-editor).
2. Bajo el documento, elija **Predeterminado (todos los idiomas)** o uno de **EN**, **FR**, **DE**, **ES**, **IT**.
3. Edite las bandas para ese idioma y **Guardar**. **Usar la predeterminada para este idioma** elimina un diseño propio.

**Conviene saber**

- Un punto en un idioma significa que tiene su propio diseño; de lo contrario, hereda el predeterminado.
- El documento de un miembro se imprime en su idioma cuando existe un diseño para él; si no, en el idioma por defecto del espacio.

**Véase también:** [Idioma del espacio](help:user.workspace.settings.language)

<!-- anchor: user.invoicing.hub -->
### La pantalla de Facturación

**Público:** Propietario · Administrador/a de facturación

Ve de un vistazo qué hay que emitir, qué hay que cobrar y qué está cerrado.

<p><img src="images/user-invoicing-hub.es.jpg" width="280"></p>

**Pasos**

1. Abra [Facturación](app:/invoices).
2. Lea la franja: **Por emitir**, **Por cobrar**, **Por confirmar**, **Cerrada**.
3. Trabaje en las tres pestañas: **Por facturar** (miembros con algo registrado, aún sin facturar), **Abiertas** (emitidas, sin pagar) y **Archivo** (pagadas o cerradas).
4. Pulse el icono de herramientas para ver las demás herramientas.

**Conviene saber**

- Ve las facturas de todo el espacio. Las suyas están en sus finanzas, bajo **Mis finanzas**.
- Las facturas nunca se editan ni se eliminan: una equivocada se marca como errónea y se sustituye.
- La entrada **Cómo funciona la facturación** explica quién actúa en cada paso.

**Véase también:** [Nueva factura](help:user.invoicing.new-invoice) · [Facturas abiertas](help:user.invoicing.open)

<!-- anchor: user.invoicing.new-invoice -->
### Emitir una factura

**Público:** Propietario · Administrador/a de facturación

Factura un mes a un miembro.

<p><img src="images/user-invoicing-new-invoice.es.jpg" width="280"></p>

**Pasos**

1. En [Facturación](app:/invoices), pulse **Nueva factura**, o **Emitir** en una fila de **Por facturar**.
2. Elija el **Miembro** y el mes. Las partidas proceden de lo registrado.
3. Active **Incluir el anexo detallado (asistencias, servicios, pagos)** si lo desea.
4. Pulse **Emitir factura**. En **Por facturar**, **Facturar todo** emite todas las filas.

**Conviene saber**

- Las facturas se derivan de datos registrados y no se pueden componer a mano. La línea final es el **Saldo**.
- Un mes solo se puede facturar una vez por miembro, y un mes aún en curso le avisa de que las partidas pueden cambiar.
- Si falta un dato obligatorio, **Complete estos datos antes de emitir** lo enumera (dirección, número de IVA, fundamento de la exención, tipo de IVA; también el país del espacio, que debe ser Francia o Alemania).
- En esta versión, la emisión en la aplicación está disponible para espacios en Francia o Alemania, también para clientes en el extranjero: un puesto, una oficina o una sala lleva su IVA viva donde viva el cliente. Las facturas con inversión del sujeto pasivo, de exportación o a un comprador exento se emiten fuera de la aplicación con su gestor, y un servicio general a un cliente en el extranjero requiere antes su condición (empresa o consumidor).
- Una factura emitida está firmada y es inmutable.

**Véase también:** [Asistente de cierre mensual](help:user.invoicing.wizard)

<!-- anchor: user.invoicing.open -->
### Reclamar y saldar facturas abiertas

**Público:** Propietario · Administrador/a de facturación

Hace seguimiento de lo que está sin pagar y lo cierra como es debido.

<p><img src="images/user-invoicing-open.es.jpg" width="280"></p>

**Pasos**

1. En [Facturación](app:/invoices), abra la pestaña **Abiertas** y pulse una factura.
2. Use las acciones que ofrece: **Enviar un recordatorio**, **Marcar como pagada** (concilia un pago registrado), **Anular el saldo pendiente**, **Marcar como errónea**, o comparta el PDF.
3. Las facturas pagadas pasan a **Archivo**.

**Conviene saber**

- Una factura está pagada cuando se le ha conciliado un pago real. Una diferencia necesita una nota, o una factura rectificativa por el exceso.
- Anular un saldo pendiente pasa por validación.
- **Marcar como errónea** no se puede deshacer. Hágalo antes del pago, nunca después.

**Véase también:** [Reglas de recordatorio](help:user.money.reminders.rules) · [Agrupar facturas](help:user.invoicing.settlement)

<!-- anchor: user.invoicing.wizard -->
### El asistente de cierre mensual

**Público:** Propietario · Administrador/a de facturación

Un único recorrido guiado para la rutina del dinero: emitir, enviar, recordar, registrar pagos, conciliar y cerrar.

<p><img src="images/user-invoicing-wizard.es.jpg" width="280"></p>

**Pasos**

1. En [Facturación](app:/invoices), pulse **Asistente de cierre mensual** (o abra el [Asistente de facturación](app:/invoicing/wizard)).
2. Elija la ejecución: **Inicio de mes** (suscripciones que los miembros pagan por adelantado, para el mes siguiente) o **Fin de mes** (uso, consumo y cargos extra del mes que acaba de terminar). La fecha propone una.
3. Siga los pasos: **Revisión**, **Emitir**, **Enviar**, **Recordar**, **Pagos**, **Conciliar**, **Cerrar**, **Resumen**.
4. Pulse **Siguiente** en cada paso y **Terminar** al final.

**Conviene saber**

- Puede desmarcar a un miembro para dejarlo fuera de un lote; los miembros ya cubiertos aparecen como hechos.
- **Resumen** enumera lo que hizo la ejecución, y lo que sigue abierto y a quién le toca actuar.
- Un paso sin nada que hacer lo indica.

**Véase también:** [La pantalla de Facturación](help:user.invoicing.hub) · [Agrupar facturas](help:user.invoicing.settlement)

<!-- anchor: user.invoicing.settlement -->
### Agrupar facturas en una

**Público:** Propietario · Administrador/a de facturación

Un miembro tiene varias facturas abiertas y debería pagar una sola.

<p><img src="images/user-invoicing-settlement.es.jpg" width="280"></p>

**Pasos**

1. En [Facturación](app:/invoices), pulse el icono de herramientas y **Agrupar en una factura**.
2. Elija al menos dos facturas abiertas del mismo miembro.
3. Confirme. Se le pregunta si desea adjuntar las facturas agrupadas.

**Conviene saber**

- La nueva factura es la que se debe y se reclama. Las originales siguen siendo legibles detrás de ella.
- Las líneas y el IVA se trasladan; la declaración de IVA cuenta las originales una sola vez.

**Véase también:** [Facturas abiertas](help:user.invoicing.open)

<!-- anchor: user.invoicing.shared-expense -->
### Repartir un gasto compartido

**Público:** Propietario · Administrador/a de facturación

Un coste compartido por la comunidad se divide entre los miembros.

<p><img src="images/user-invoicing-shared-expense.es.jpg" width="280"></p>

**Pasos**

1. En [Facturación](app:/invoices), pulse el icono de herramientas y **Repartir un gasto**.
2. Describa **El gasto** y después elija **Repartir por**: **Partes iguales**, **Suscripción**, **Uso** o **Clave propia**.
3. Compruebe las **Partes**, desmarque a quien quiera **Excluir** y pulse **Contabilizar las partes**.

**Conviene saber**

- Una vez contabilizadas (tras la validación, si una regla la exige), las partes se incorporan como líneas en la siguiente factura de uso de cada miembro.
- **Reversión — devolver como notas de crédito** devuelve el dinero.
- **Recordar esta regla** vuelve a proponer la regla ajustada el mes siguiente.

**Véase también:** [El asistente de cierre mensual](help:user.invoicing.wizard)

<!-- anchor: user.money.reminders.rules -->
### Reglas de recordatorio

**Público:** Propietario · Administrador/a de facturación

Decide cuándo y con qué frecuencia se reclama una factura vencida.

<p><img src="images/user-money-reminders-rules.es.jpg" width="280"></p>

**Pasos**

1. En [Facturación](app:/invoices), pulse el icono de herramientas y **Reglas de recordatorio**.
2. Defina **Número de niveles de recordatorio**, **Días hasta el primer recordatorio** y **Días entre recordatorios**.
3. Pulse **Guardar**.

**Conviene saber**

- Los recordatorios imprimen las menciones de pago que usted ha configurado.
- Un recordatorio queda registrado en la factura y aparece con la etiqueta **Recordado**.

**Véase también:** [Recordatorios automáticos](help:user.money.reminders.automatic) · [Condiciones de pago](help:user.money.legal.payment-terms)

<!-- anchor: user.money.reminders.automatic -->
### Recordatorios automáticos

**Público:** Propietario · Administrador/a de facturación

Quiere que los recordatorios salgan solos.

<p><img src="images/user-money-reminders-automatic.es.jpg" width="280"></p>

**Pasos**

1. Abra **Reglas de recordatorio** en las herramientas de Facturación.
2. Active **Recordatorios automáticos**.
3. Pulse **Guardar**.

**Conviene saber**

- Una vez al día, las facturas que han superado su plazo de pago registrado reciben el nivel siguiente, por el importe aún pendiente.
- Nunca mientras haya un pago pendiente o la factura esté en espera. Las facturas sin plazo registrado quedan en sus manos.
- Desactivado: usted envía cada recordatorio.
- Cuándo se ejecuta: cada mañana en el servidor si la instalación programa tareas; si no, cuando un administrador abre Finanzas. El operador de su servidor sabe cuál se aplica.

**Véase también:** [Reglas de recordatorio](help:user.money.reminders.rules)

<!-- anchor: user.invoicing.register -->
### El registro de facturas

**Público:** Propietario · Administrador/a de facturación

Todas las facturas en una sola lista ordenable.

<p><img src="images/user-invoicing-register.es.jpg" width="280"></p>

**Pasos**

1. Abra [Registro de facturas](app:/invoice-register).
2. Elija el **Año** o **Todos los años**.
3. Ordene por **Fecha**, **Nombre** o **Importe**; el total está al final.

**Conviene saber**

- Los miembros ven las suyas; quienes emiten facturas ven las del espacio.
- La exportación contable empieza aquí.

**Véase también:** [Exportaciones contables](help:user.invoicing.accounting-export)

<!-- anchor: user.invoicing.accounting-export -->
### Exportaciones contables

**Público:** Propietario · Administrador/a de facturación

Entrega a su gestor las facturas y los pagos del año.

<p><img src="images/user-invoicing-accounting-export.es.jpg" width="280"></p>

**Pasos**

1. Abra [Registro de facturas](app:/invoice-register) y pulse **Exportación contable**.
2. En **Exportación contable**, elija un formato, como **FEC (Francia, exigido en una inspección)**, **SAF-T (XML, internacional)**, **CSV contable**, **Pista de auditoría** o **Archivo del ejercicio (zip)**. La lista depende de su país; algunos países añaden el suyo, como **DATEV (Buchungsstapel)**.
3. En **Antes de guardar**, lea la comprobación y pulse **Guardar archivo e informe**.

**Conviene saber**

- Cada formato indica lo que pretende ser. «Para que su gestor lo importe y lo revise — no es una presentación» no es una declaración de impuestos.
- DesKilo no lleva libro de contabilidad por partida doble: los archivos se reconstruyen a partir de las facturas y los pagos, y su gestor los completa.
- Un archivo queda bloqueado hasta que se corrigen los problemas del origen.
- Algunos formatos señalan que DesKilo no es un programa certificado en su país.

**Véase también:** [Cuenta de IVA](help:user.money.vat.account) · [El registro de facturas](help:user.invoicing.register)

<!-- anchor: user.invoicing.bi -->
### Análisis de negocio

**Público:** Propietario · Administrador/a de facturación

Observa cómo rinde el espacio.

**Pasos**

1. Abra [Análisis de negocio](app:/bi), o **Informes** en el menú.
2. Elija la **Duración del periodo** (**Mes**, **Trimestre**, **Año**), una comparación y, cuando se ofrezca, una agrupación.
3. Lea los análisis por área, como **Finanzas** (**Facturado**, **Cobrado**) y **Espacios y capacidad**.
4. Guarde una vista en **Vistas**, o pulse **Exportar a PDF**.

**Conviene saber**

- Solo ve los análisis que tiene permiso para leer.
- Cobrado son los pagos conciliados con facturas. No es un beneficio: en la cifra no entra ningún coste.
- El periodo actual es parcial; sus cifras todavía cambian.

**Véase también:** [La pantalla de Facturación](help:user.invoicing.hub)
