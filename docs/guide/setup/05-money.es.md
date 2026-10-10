<!-- anchor: setup.money.overview -->
## Dinero e impuestos

Para propietarios y administradores de facturación que van a decidir cómo se paga un espacio. Este capítulo trata de las decisiones y de su orden; los clics están en la guía de usuario, y cada sección enlaza con ellos.

> **Atención** DesKilo registra, calcula e imprime lo que usted declara, y comprueba que estén los datos obligatorios. No certifica sus facturas, su tratamiento del IVA ni su contabilidad. Cada vez que este capítulo diga «consúltelo con su gestor», hágalo.

En este capítulo:
- Si los miembros pagan o no, y quién emite las facturas
- Cómo se construye una tarifa, con las cifras del espacio de demostración *Atelier du Marché*
- Cómo le pagan los miembros
- Su identidad legal y las preguntas que conviene llevar a su gestor
- Facturación manual o automática, recordatorios y el IVA a grandes rasgos
- Las decisiones de dinero que no tienen vuelta atrás, y cómo ensayarlas sin riesgo

<!-- anchor: setup.money.decide -->
### Decida primero: si los miembros pagan y quién emite las facturas

**Público:** Propietario

Usted elige hasta dónde llega DesKilo en su dinero. Todo lo demás en este capítulo depende de esta elección, que es fácil de ampliar más adelante y difícil de reducir cuando ya existen facturas.

<p><img src="images/setup-money-paths.es.jpg" width="280"></p>

**Antes de empezar**

Responda a dos preguntas: ¿le pagan los miembros por el espacio?, ¿quiere que las facturas legales salgan de DesKilo?

| Vía | Elíjala cuando | Qué ocurre |
|---|---|---|
| 1. Sin dinero | El espacio es gratuito, o los miembros son amigos que reparten el alquiler fuera de la aplicación | Deja las funciones de dinero desactivadas. Los miembros reservan; nadie recibe facturas. |
| 2. Extractos y pagos, facturas fuera | Ya tiene un gestor o una herramienta de facturación, o trabaja en un país para el que DesKilo no puede emitir facturas | Los miembros tienen un extracto mensual, usted registra los pagos que recibe y exporta las cifras para su gestor. Las facturas legales se producen en otro sitio. |
| 3. Facturas emitidas por DesKilo | Está en Francia o en Alemania, y está registrado en el IVA o fuera de su ámbito (una asociación, por ejemplo) | DesKilo produce facturas firmadas y numeradas a partir de lo reservado, con su identidad legal impresa. |

**Pasos**

1. Elija su vía en la tabla.
2. Para la vía 2 o 3, active las funciones de dinero que necesite en [Funciones](help:user.features.switch): **Facturas** es la base de todo lo que se emite, y las funciones que dependen de ella (**Facturas de suscripción**, **Facturas de fin de mes**, **Recordatorios de pago**, **Gestión del IVA**) se activan una a una.
3. Para la vía 3, continúe con [su identidad legal](help:setup.money.identity) antes de la primera reserva, no después.

**Conviene saber**

- Hoy la emisión de facturas dentro de la aplicación existe para un espacio en **Francia** o **Alemania**. En cualquier otro país, use la vía 2: los extractos siguen disponibles.
- El servidor se niega a emitir, y la lista **Complete estos datos antes de emitir** explica por qué, cuando falta un dato o cuando el tratamiento es uno que DesKilo no gestiona: las ventas transfronterizas, la inversión del sujeto pasivo, las exportaciones y las facturas exentas de IVA deben revisarse y emitirse fuera de la aplicación con su gestor.
- Un vendedor acogido al régimen de franquicia (franchise en base, Kleinunternehmer) no puede emitir facturas en la aplicación: el servidor rechaza la categoría de IVA exenta. Quédese en la vía 2 y emita esas facturas en otro sitio.
- Desactivar una función detiene la actividad nueva de ese tipo; no borra nada.
- Puede quedarse en la vía 2 para siempre. Muchas asociaciones lo hacen.

**Resultado**

Sabe cuál de las tres vías es la suya y qué funciones necesita.

**Véase también:** [La facturación de un vistazo](help:user.money.invoicing) · [Activar o desactivar procesos enteros](help:user.features.processes)

<!-- anchor: setup.money.tariff -->
### Diseñar una tarifa

**Público:** Propietario · Administrador/a de facturación

Convierte la pregunta «¿cuánto vale un puesto?» en cifras que DesKilo aplica cada mes sin que usted intervenga.

<p><img src="images/setup-money-bands--bands.es.jpg" width="280"></p>

**Antes de empezar**

Tenga presente el modelo. Se lee de izquierda a derecha, y cada paso alimenta al siguiente:

1. Porcentaje de suscripción: un miembro tiene un porcentaje del mes: 25, 50, 75 o 100 %, o un valor que usted permita.
2. Derecho en medias jornadas: el porcentaje se convierte en un número de medias jornadas para el mes: los días abiertos, por dos, por el porcentaje, redondeado hacia arriba.
3. Tramo de tarifa: el porcentaje cae en un tramo, que da la cuota mensual y el precio de una media jornada adicional. Un tramo abarca «por encima de su inicio, hasta su final inclusive», y juntos los tramos deben cubrir de 0 a 100 % sin huecos.
4. Política de exceso: cuando se agota el derecho, cada miembro queda bloqueado, paga el precio del exceso o se le invita a comprar un bono.
5. Bonos y servicios: un bono de días vende medias jornadas adicionales por adelantado a un precio que usted fija; los servicios (un café, una taquilla, impresión) se venden además.

**Pasos**

1. Decida los porcentajes que quiere ofrecer en **Niveles de suscripción**, y si un propietario puede escribir un valor negociado (véase [Niveles de suscripción](help:user.money.billing.levels)).
2. Defina una fila por intervalo en **Tramos de tarifas**: su límite superior, la cuota mensual y el precio del exceso (véase [Tramos de tarifas](help:user.money.billing.fee-bands)).
3. Decida el valor por defecto para los miembros que se quedan sin días: [Cuando se acaban los días](help:user.members.overage-policy).
4. Añada los [bonos de días](help:user.money.billing.packages) y los [servicios](help:user.money.services.overview) que vende.

**Conviene saber**

- La aritmética queda congelada en cada documento emitido. Cambiar un precio cambia el mes siguiente, nunca un mes ya facturado.
- El horario de apertura y los días de cierre determinan cuántos días abiertos tiene un mes, y por tanto el tamaño del derecho. Defínalos primero.
- Un miembro sin suscripción es para visitantes que compran bonos; no puede estar en pago por uso.

**Véase también:** [Facturación](help:user.money.billing.fee-bands) · [La suscripción de un miembro](help:user.members.subscription)

<!-- anchor: setup.money.example -->
### Un ejemplo completo

**Público:** Propietario · Administrador/a de facturación

Sigue a un miembro durante un mes con las cifras de *Atelier du Marché*, para que pueda comprobar las suyas de la misma manera.

<p><img src="images/setup-money-packages--packages.es.jpg" width="280"></p>

**Antes de empezar**

El espacio de demostración tiene tres tramos de tarifa, en euros y con el IVA incluido. Las cifras son las de la demo, no una recomendación.

| Tramo | Cuota mensual | Media jornada adicional | Medias jornadas en un mes de 22 días abiertos |
|---|---|---|---|
| hasta 25 % | 0,00 | 15,00 | 11 |
| por encima de 25 %, hasta 50 % | 150,00 | 8,00 | 22 |
| por encima de 50 %, hasta 100 % | 250,00 | 0,00 | 44 (al 100 %) |

**Pasos**

1. Un miembro tiene el 50 %. En un mes con 22 días abiertos, el derecho es 22 × 2 × 50 / 100 = 22 medias jornadas.
2. El 50 % cae en el segundo tramo (por encima de 25, hasta 50): la cuota es de 150,00, use lo que use el miembro.
3. El miembro reserva 24 medias jornadas. Dos exceden el derecho, a 8,00 cada una: 16,00.
4. El mes cuesta 150,00 + 16,00 = 166,00, antes de cualquier servicio. En la demo los precios son brutos: el IVA del 20 % está incluido y la pantalla lo muestra bajo cada precio.
5. Compárelo con un bono: el bono de 5 días de la demo cuesta 40,00 y añade 10 medias jornadas (5 días, dos medias jornadas cada uno), es decir, 4,00 por media jornada. Frente a 8,00 de exceso, compensa a partir de la sexta media jornada adicional en un mes.

**Conviene saber**

- Un precio de exceso de 0,00 significa que las medias jornadas adicionales no cuestan nada en pago por uso.
- El extracto que ve un miembro muestra las mismas líneas: cuota, incluido, usado, adicional, exceso.
- Los precios se muestran con el IVA incluido cuando el IVA está activado; el impuesto se extrae de ellos.
- Si usted y un miembro acuerdan otras condiciones, véase la [negociación de precios](help:setup.money.negotiation).

**Resultado**

Puede predecir la factura de un miembro con tres datos: su porcentaje, los días abiertos y las reservas.

**Véase también:** [Lea su extracto](help:user.money.statement) · [Lo que costó cada reserva](help:user.money.usage)

<!-- anchor: setup.money.negotiation -->
### Negociación de precios

**Público:** Propietario · Administrador/a de facturación

Quiere que un miembro pague condiciones distintas de la tarifa, de forma que quede constancia.

**Pasos**

1. Active la función de negociación de precios en [Funciones](help:user.features.switch).
2. Proponga las condiciones en la ficha del miembro: otra cuota mensual, otra tasa de exceso, un descuento en los suplementos, otros precios unitarios u otro porcentaje de ocupación (véase [Negociación de precios](help:user.members.negotiation)).
3. Deje que la regla de validación de las negociaciones de precios decida quién la confirma.

**Conviene saber**

- La tarifa sigue siendo la referencia; un precio negociado pertenece a un solo miembro.
- Lo ven el miembro, los propietarios y las personas con derecho a consultar los acuerdos comerciales, y cada lectura queda registrada.
- Defina su política antes de abrir: una excepción concedida en silencio acaba siendo el precio que todos piden.

**Véase también:** [Sus precios negociados](help:user.money.negotiation)

<!-- anchor: setup.money.pay -->
### Cómo le pagan los miembros

**Público:** Propietario · Administrador/a de facturación

Usted elige adónde va el dinero de un miembro y cuánto trabajo hace DesKilo por usted.

<p><img src="images/setup-money-payment-instructions.es.jpg" width="280"></p>

**Pasos**

1. Empiece por la vía gratuita: rellene las [instrucciones de pago](help:user.money.payments.methods): su IBAN y datos bancarios, y los medios que acepte entre PayPal.me, Wero, Lydia o Wise, más una indicación de referencia.
2. Los miembros ven estos datos en un extracto sin pagar. Cuando un pago llega a su cuenta, usted o un administrador de facturación [lo registra](help:user.money.payments.record).
3. Solo si quiere que los miembros paguen dentro de la aplicación, conecte un proveedor en [Pagos en línea](help:user.money.payments.provider): PayPal, Stripe o Mollie. Necesita la función **Pagos en línea** y su propia cuenta en el proveedor.

**Conviene saber**

- DesKilo registra los pagos; con la vía manual nunca mueve dinero.
- Un proveedor cobra sus propias comisiones y recibe las claves de su cuenta (la hoja de credenciales explica cómo se introducen).
- Con **Pagos en línea** desactivado, se rechaza un nuevo pago en línea; uno ya abierto todavía puede liquidarse.
- Un espacio creado a partir de una plantilla no incluye los datos de pago: introdúzcalos en cada espacio. Una exportación de la configuración sí los incluye.

**Véase también:** [Pague lo que debe](help:user.money.payments) · [Credenciales del proveedor](help:user.money.payments.credentials)

<!-- anchor: setup.money.identity -->
### Su identidad legal y qué preguntar a su gestor

**Público:** Propietario

Usted indica a DesKilo quién vende, para que cada factura le nombre correctamente. Esta es la parte que conviene cerrar con un profesional.

<p><img src="images/setup-money-legal--top.es.jpg" width="280"></p>

**Antes de empezar**

La pantalla es [Identidad legal y facturación electrónica](app:/legal-identity). Tenga a mano:

- el tipo de organización: una empresa o una asociación sin ánimo de lucro;
- su régimen de IVA: fuera del ámbito del IVA, exento de IVA (régimen de franquicia) o registrado en el IVA. La aplicación solo puede emitir facturas para el primero y el último; con la franquicia, la pantalla registra su situación pero las facturas deben emitirse en otro sitio (vía 2);
- su número de registro y, si lo tiene, su número de IVA;
- su dirección postal, tal como figura en su registro;
- el motivo por el que no se cobra IVA, si no cobra ninguno.

> **Atención** Elegir el régimen es una decisión fiscal, no un ajuste del programa. Una asociación sin actividad comercial normalmente está fuera del IVA, y la pantalla le avisa si elige «exento» para una. Confirme la elección antes de emitir la primera factura.

**Pasos**

1. Abra [Identidad legal y facturación electrónica](app:/legal-identity) y trabaje de arriba abajo: primero el **Régimen de IVA**, después los identificadores, la dirección y las **Menciones de facturación**.
2. Rellene las condiciones de pago, las menciones de demora y las demás menciones que exija su país (véase [Su identidad legal](help:user.money.legal.identity)).
3. Pulse **Guardar** y lea la plantilla de factura una vez con su gestor (véase [La plantilla PDF de factura](help:user.money.reports.invoice-template)).

> **Consejo** Preguntas para llevar a su gestor:
>
> 1. ¿En qué tipo de organización y en qué régimen de IVA estoy?
> 2. ¿Cuáles son mi número de registro y mi número de IVA, y cómo se escriben?
> 3. Si no cobro IVA, ¿qué texto legal lo justifica?
> 4. ¿Qué menciones deben figurar en mis facturas (plazo de pago, penalización por demora, indemnización por cobro, descuento por pronto pago, seguro)?
> 5. ¿Cómo deben numerarse las facturas, y la numeración se reinicia cada año o cada mes?
> 6. ¿Cuándo se devenga el IVA de mis servicios según la regla de mi país (cobro, mes del servicio, factura), y debo optar por otra base, como el criterio de caja?
> 7. ¿Debo enviar facturas electrónicas a una plataforma pública, y a cuál?
> 8. ¿Necesito declaraciones periódicas de IVA, y con qué frecuencia?

**Conviene saber**

- Las facturas ya emitidas conservan la identidad con la que se firmaron; un cambio se aplica a las siguientes.
- Solo un propietario o un copropietario activo puede abrir esta pantalla, y la función **Facturas** debe estar activada.
- Un espacio creado a partir de una plantilla no incluye su identidad: introdúzcala de nuevo. Un despliegue entre los dos lados de un par sí la incluye.

**Véase también:** [Régimen de IVA](help:user.money.vat.regime) · [La plataforma de facturación electrónica](help:user.money.einvoice.overview) · [Tipo de organización](help:user.money.legal.seller-kind)

<!-- anchor: setup.money.invoicing -->
### Facturar a mano o automáticamente

**Público:** Propietario · Administrador/a de facturación

Usted decide si una persona pulsa los botones cada mes o si lo hace DesKilo.


**Pasos**

1. Para un primer mes, trabaje a mano: abra [Facturación](app:/invoices), lea **Por emitir** y emita la factura de un miembro (véase [Emitir una factura](help:user.invoicing.new-invoice)).
2. Para una rutina, use el [asistente de cierre mensual](help:user.invoicing.wizard): recorre **Revisión**, **Emitir**, **Enviar**, **Recordar**, **Pagos**, **Conciliar**, **Cerrar** y **Resumen**.
3. Para automatizar, active **Facturas de suscripción** y **Facturas de fin de mes** en [Funciones](help:user.features.switch) y fije los días en [Calendario de facturación](help:user.money.billing.schedule).

**Conviene saber**

- Existen dos documentos por mes: la cuota de suscripción, emitida antes del mes, y lo que el mes costó realmente, emitido después. Una factura puede llevar una fecha unos días adelantada (tres por defecto, según el calendario de facturación), de modo que una fechada el 29 de agosto puede nombrar septiembre.
- En el servidor, una ejecución diaria emite ambos cuando la base de datos de la instalación tiene su programador activado; si no está seguro, pregúntelo al operador.
- Cada tipo de factura (suscripción, fin de mes) puede emitirse una vez por miembro y mes. Las facturas no se pueden editar ni borrar; una errónea se marca como tal y se sustituye.
- Por defecto emiten facturas el propietario y los copropietarios. **Los admins emiten facturas** lo extiende a los administradores.

**Véase también:** [La pantalla de Facturación](help:user.invoicing.hub) · [Reclamar y liquidar las facturas abiertas](help:user.invoicing.open)

<!-- anchor: setup.money.reminders -->
### Recordatorios de pago

**Público:** Propietario · Administrador/a de facturación

Usted decide cuándo se considera tarde y quién se encarga de reclamar.

<p><img src="images/setup-money-reminders.es.jpg" width="280"></p>

**Pasos**

1. Active **Recordatorios de pago** en [Funciones](help:user.features.switch). Depende de **Facturas**.
2. Fije el número de niveles y los plazos en [Reglas de recordatorio](help:user.money.reminders.rules): días hasta el primer recordatorio y días entre recordatorios.
3. Decida si los recordatorios salen solos: active **Recordatorios automáticos** en el mismo cuadro de diálogo (véase [Recordatorios automáticos](help:user.money.reminders.automatic)); la función **Recordatorios de pago automáticos** también debe estar activada.

**Conviene saber**

- El plazo antes del primer recordatorio se lee también como su plazo de pago. Fíjelo en [Condiciones de pago](help:user.money.legal.payment-terms).
- Los recordatorios automáticos se ejecutan una vez al día en el servidor cuando la base de datos tiene su programador activado. También se ejecutan cuando alguien autorizado a emitir facturas (un propietario, un copropietario o un administrador si **Los admins emiten facturas** está activado) abre Finanzas, de modo que un espacio sin programador igualmente los recibe, los días en que alguien mira. El interruptor y la descripción de la función también lo dicen; el operador de su servidor sabe cuál se aplica.
- La función **Recordatorios de pago** solo pone las reglas a su disposición. Un recordatorio sale solo únicamente cuando **Recordatorios automáticos** está activado en las reglas de recordatorio, lo cual no ocurre hasta que usted lo decide.
- Se omiten las facturas con un pago pendiente o en espera, y las facturas sin plazo de pago registrado.
- El miembro recibe una alerta en su flujo y, si las notificaciones push están configuradas, una notificación genérica; véase [Avisar a las personas](help:setup.notify.overview).

**Véase también:** [Condiciones de pago](help:user.money.legal.payment-terms)

<!-- anchor: setup.money.vat -->
### El IVA a grandes rasgos

**Público:** Propietario · Administrador/a de facturación

Quiere saber qué le pedirá el IVA antes de activarlo.

<p><img src="images/setup-money-vat--rates.es.jpg" width="280"></p>

**Pasos**

1. Solo si está registrado en el IVA, active **Gestión del IVA** en [Funciones](help:user.features.switch).
2. Fije los tipos en [IVA](app:/vat): **Usar los tipos habituales** de su país y marque exactamente uno como predeterminado (véase [Fijar los tipos](help:user.money.vat.rates)).
3. Dé a cada tipo su grupo y, cuando proceda, un motivo de exención (véase [Grupos de IVA](help:user.money.vat.groups)).
4. Cuando la ley cambie un tipo, use **Cambio por ley** para que las facturas antiguas conserven su tipo (véase [Cambiar un tipo por ley](help:user.money.vat.change-by-law)).
5. Si debe presentar declaraciones, active **Declaraciones de IVA** y prepare cada periodo en [Declaración de IVA](help:user.money.vat.declaration).

**Conviene saber**

- Se incluye un catálogo de tipos para los Estados miembros de la UE, Suiza, Noruega y Canadá. Mantenerlo al día cuando un gobierno cambia un tipo es cosa suya.
- Si está registrado y no hay un tipo predeterminado en vigor, el servidor se niega a emitir. La descripción de **Gestión del IVA** y el aviso de la pantalla de identidad legal lo dicen.
- El servidor calcula cada declaración a partir de sus facturas, cobros y devengos. Preséntela usted mismo ante la administración tributaria y márquela como presentada con la referencia del justificante: la aplicación no transmite nada.
- El diario de declaraciones tiene su propia serie de numeración.

**Véase también:** [Régimen de IVA](help:user.money.vat.regime) · [Cuándo se devenga el IVA](help:user.money.vat.due)

<!-- anchor: setup.money.permanent -->
### Lo que no tiene vuelta atrás

**Público:** Propietario

Quiere saber, antes de la primera factura, qué no podrá cambiar después.

<p><img src="images/setup-money-numbering.es.jpg" width="280"></p>

> **Atención** Desde la primera factura emitida, lo que sigue es permanente. Decídalo antes con su gestor.

| Decisión | Qué pasa a ser permanente | Cuándo |
|---|---|---|
| Una factura emitida | Está firmada y es inmutable: los importes, las partes, el desglose del IVA y la aritmética de la tarifa quedan como se imprimieron. Una corrección es una anulación, una factura rectificativa o un reembolso, cada uno un documento nuevo. | Al emitir |
| Número de factura | Los números son correlativos, sin huecos, y se asignan en la base de datos en el momento de emitir. El número siguiente puede subirse, nunca bajarse. Un cambio de formato se aplica desde ese momento. Un reinicio no puede ser más frecuente que la fecha que imprime el número. | En la primera emisión |
| Un mes facturado | Un mes con una factura para un miembro queda cerrado para ese miembro. Los días de cierre y las importaciones de festivos omiten esos meses y los nombran. | En la primera factura de ese mes |
| Tipos de IVA | Los tipos se versionan por fecha, nunca se editan. Una declaración de IVA presentada no se recalcula nunca. | En el primer uso |
| Moneda y país | Los importes se guardan como unidades menores enteras, sin conversión. En cuanto el espacio ha emitido un documento o registrado dinero, el servidor rechaza cambiar uno u otro. | En el primer documento o pago |

**Pasos**

1. Abra [Series de numeración](app:/settings/number-sequences) y fije el prefijo, el sufijo, la parte de fecha, los dígitos y el reinicio de cada diario (facturas, facturas rectificativas, declaraciones de IVA, miembros, pagos). La pantalla necesita la función **Series de numeración**.
2. Enseñe el resultado a su gestor antes de la primera factura.
3. Elija el país, la moneda y la zona horaria en los [Ajustes del espacio](help:user.workspace.settings.country) antes de que nadie reserve.

**Conviene saber**

- Los números no se desperdician: un documento que no llega a emitirse no consume ninguno.
- Los dos estados de un espacio, prueba y producción, existen para que nada de esto se ensaye de verdad; véase [un ensayo seguro](help:setup.money.dry-run).

**Véase también:** [El registro de facturas](help:user.invoicing.register) · [Moneda y zona horaria](help:user.workspace.settings.currency-timezone)

<!-- anchor: setup.money.dry-run -->
### Un ensayo seguro en un espacio de prueba

**Público:** Propietario

Ensaya una vez toda la rutina del dinero, sin nada real en juego.

**Pasos**

1. Cree o abra un espacio de prueba (**Un espacio de prueba**, o el lado DEV de un par vinculado); véase [Espacio de prueba](help:user.advanced.test-space) y [Entornos](help:user.advanced.environments).
2. Introduzca la identidad legal, los tipos, la tarifa y las instrucciones de pago tal como piensa usarlos.
3. Invite a dos o tres personas a reservar unos días; añada un servicio para una de ellas.
4. Ejecute el [asistente de cierre mensual](help:user.invoicing.wizard) de principio a fin y lea el PDF de la factura.
5. Registre un pago, deje que venza un recordatorio y lea el extracto como lo vería el miembro.
6. Enseñe los PDF y la exportación contable a su gestor.

**Conviene saber**

- Un espacio de prueba pone una marca de agua en cada documento y dice que es una prueba; no se debe nada.
- Declarar un espacio como producción quita la marca de agua; las facturas ya emitidas conservan la suya.
- El par puede traer la configuración de un lado al otro, pero las credenciales no viajan.

**Resultado**

Un primer mes que ya ha visto y una lista de preguntas resueltas antes de que cuesten algo.

**Véase también:** [Los dos entornos](help:user.advanced.environments) · [Exportaciones contables](help:user.invoicing.accounting-export)
