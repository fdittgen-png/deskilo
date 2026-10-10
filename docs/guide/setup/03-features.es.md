<!-- anchor: setup.features.overview -->
## Elija lo que ofrece su espacio

Un espacio no es un producto con cien ajustes. Es un puñado de cosas que usted decide ofrecer, una a una. Este capítulo explica cómo agrupa DesKilo lo que sabe hacer, qué tiene ya un espacio nuevo, cómo dependen unas piezas de otras y en qué orden activarlas para no ofrecer nunca algo que todavía no puede atender.

En este capítulo:
- [Funciones y procesos](help:setup.features.what)
- [Esencial y Plataforma: lo que tiene un espacio nuevo](help:setup.features.tiers)
- [Funciones que necesitan otras funciones](help:setup.features.dependencies)
- [Desactivar no borra nada](help:setup.features.off)
- [Beta, Sin evaluar y la pregunta antes de activar](help:setup.features.maturity)
- [Tres puntos de partida](help:setup.features.profiles)
- [El orden para activar las cosas](help:setup.features.order)
- [Active una función con seguridad](help:setup.features.safely)
- [Evite funciones que se contradicen](help:setup.features.consistency)
- [El mapa de funciones](help:setup.features.map)

<!-- anchor: setup.features.what -->
### Funciones y procesos

**Público:** Propietario · Copropietario

Usted quiere saber qué está activando cuando abre **Funciones**. Todo lo que DesKilo sabe hacer más allá de lo básico es una función con su propio interruptor. Para que cien interruptores sigan siendo legibles, la pantalla los agrupa según su finalidad.

<p><img src="images/setup-features-what.es.jpg" width="280"></p>

*Cómo está organizado*

- Un *proceso* es un trabajo del negocio: por ejemplo **Facturación y pagos** o **Calendario y coordinación**. Hay nueve.
- Un *subproceso* es un paso de ese trabajo: **Facturación**, **Cobro de pagos** y **Gestión del IVA** son tres de los cinco pasos de **Facturación y pagos**.
- Una *función* es un interruptor dentro de un subproceso: **Facturas**, **Recordatorios de pago**, **Declaraciones de IVA**.

*Los nueve procesos y sus subprocesos*

| Proceso | Subprocesos |
|---|---|
| **Espacio y acceso** | **Personas y membresías** · **Acceso físico** |
| **Gestión de espacios** | **Estructura del espacio** · **Días y horarios de apertura** · **Presentación del espacio** |
| **Reservas y uso** | **Reservar puestos y espacios** · **Asistencia y uso** |
| **Calendario y coordinación** | **Vistas del calendario** · **Decisiones y aprobaciones** · **Comunicación entre miembros** |
| **Ofertas para miembros** | **Servicios y precios** |
| **Facturación y pagos** | **Registros financieros** · **Facturación** · **Cobro de pagos** · **Gastos compartidos** · **Gestión del IVA** |
| **Documentos e información** | **Publicación de documentos** · **Diseño de informes** · **Acceso a datos y exportaciones** |
| **Operaciones y administración** | **Configuración y despliegue** · **Uso de la aplicación** |
| **Integraciones y automatización** | **Envío externo** |

**Conviene saber**

- Una función pertenece a un solo proceso, aunque necesite una función de otro. La tarjeta lo dice: «Activarlo todo también necesita: Pestaña Finanzas (Facturación y pagos)».
- Los planes de membresía y el editor del plano no son funciones: siempre están ahí. Sus ajustes están en Espacio y en Facturación, no en esta pantalla. Los bonos prepago sí son una función: véase **Bonos**.
- Desactivar una función la oculta en todas las pantallas donde aparecía; no es un permiso. Quién puede hacer qué se decide en [Roles](help:user.roles.matrix).

**Véase también:** [Qué puede hacer DesKilo](help:setup.before.what) · [Activar y desactivar procesos enteros](help:user.features.processes)

<!-- anchor: setup.features.tiers -->
### Esencial y Plataforma: lo que tiene un espacio nuevo

**Público:** Propietario · Copropietario

Usted quiere saber qué encuentran los miembros el primer día, antes de que haya activado nada.

<p><img src="images/setup-features-tiers.es.jpg" width="280"></p>

Cada función pertenece a uno de dos niveles, y un espacio nuevo se crea a partir de ellos:

| Nivel | Con las palabras de la aplicación | Qué recibe un espacio nuevo |
|---|---|---|
| **Esencial** | Lo que todo espacio necesita. Activo desde el primer día. | Activada, cuando la función está pensada para estarlo desde el principio. |
| **Plataforma** | Pedido, nunca supuesto. Active lo que este espacio realmente hace. | Desactivada. En **Interruptores**, aparecen en el nivel **Plataforma**. |

Un espacio nuevo arranca con 45 funciones activadas, todas Esenciales (46 si crea a la vez el gemelo de prueba: entonces también está activada **Pares de entornos**). En palabras sencillas:

- Reserva: reservar un asiento en el plano, repetir una reserva (**Reserva en serie**), reservar para otra persona (**Reservar para otros**), ver como parcialmente ocupado un asiento reservado a medias (**La jornada de una plaza**), guardar una reserva en un calendario personal (**Archivo de calendario de una reserva**), reglas de reserva como las reservas pasadas y las de fuera de horario (**Políticas de reserva**, **Guarda de reserva**), solicitar la eliminación de una reserva pasada (**Solicitudes de eliminación de reservas**), imprimir tarjetas QR de los puestos (**Códigos QR de espacios**), horario de trabajo configurable (**Horario de trabajo**).
- Personas: la pestaña de la comunidad (**Directorio de miembros**), una página por miembro (**Ficha de socio**), la matriz central de roles (**Gestión de roles** y **Asignación de roles**), datos personales para cartas y facturas (**Datos personales**), iniciales distintas en los avatares (**Iniciales de avatar distintas**).
- Calendario y mensajes: el calendario en varias vistas (**Pestaña Calendario**, **Calendario central**, **Vistas del calendario**), el flujo de actividad y las confirmaciones (**Pestaña Eventos**), conversaciones privadas y de grupo (**Notificaciones entre miembros**, **Mensajes, renovados**) con referencias, reenvío, menciones, gestos de deslizamiento y protección contra capturas de pantalla, la agrupación del flujo de notificaciones (**Agrupación de notificaciones**) y el botón para escribir a los anfitriones de una página publicada (**Escribir a los anfitriones**).
- Dinero: la pestaña Finanzas con sus cuatro vistas (**Pestaña Finanzas**, **Finanzas en cuatro vistas**), facturas (**Facturas**), un catálogo de servicios (**Servicios**), un PDF de la factura mensual (**Exportar PDF**).
- Documentos y datos: la biblioteca de documentos (**Biblioteca de documentos**), la exportación de datos para el propietario (**Exportación de datos (Excel)**) y la exportación y el borrado de los datos de cada miembro (**Exportación y borrado**).
- Comodidad: consejos de ayuda, la tarjeta de primeros pasos, favoritos y valoraciones de los puestos, animaciones, formatos regionales y la elección del estilo de navegación.
- Entrega: **Notificaciones push**, que solo llegan a los teléfonos cuando quien gestiona la instalación ha configurado el servicio push (véase [Cómo se informa a los miembros](help:setup.notify.channels)).
- Orden del plano: **Eliminar espacios con historial** y **Nombrar por la planta una planta de una sola sala**.

Todo lo demás es Plataforma y está desactivado: quiosco y credenciales, varias sedes, suplementos de accesorios, pagos en línea, gestión del IVA, el recorrido de las facturas, diseño de informes, despliegues, WhatsApp, la interfaz para asistentes y el resto.

**Conviene saber**

- La función de facturas está activada desde el principio, pero no se puede emitir nada hasta que su identidad legal esté completa. Véase [Evite funciones que se contradicen](help:setup.features.consistency).
- Un espacio que ya existe nunca cambia cuando DesKilo cambia lo que recibe un espacio nuevo.
- Si parte de una plantilla, la plantilla puede activar o desactivar unas pocas funciones además de este conjunto. Véase [Tres puntos de partida](help:setup.features.profiles).

**Véase también:** [Un interruptor de función](help:user.features.switch)

<!-- anchor: setup.features.dependencies -->
### Funciones que necesitan otras funciones

**Público:** Propietario · Copropietario

Usted quiere activar algo con la seguridad de que funciona, o desactivar algo sin romper lo que depende de ello.

Muchas funciones cuelgan de otra. **Pagos en línea** necesita **Pestaña Finanzas**; **Recordatorios de pago** necesita **Facturas**; **Recordatorios de pago automáticos** necesita **Recordatorios de pago**; **Declaraciones de IVA** necesita **Gestión del IVA**, que a su vez necesita **Facturas**. En la lista de **Interruptores**, una función que necesita otra muestra **Requiere** seguido del nombre de su función de origen.

*Qué hace la aplicación*

| Usted | La aplicación |
|---|---|
| Activa una función cuya función de origen está desactivada | Activa toda la cadena y dice qué se ha activado con ella: «También activado: …». |
| Desactiva una función de origen | No borra las elecciones de sus dependientes. Se conservan tal como las fijó, pero no hacen nada; la fila dice «Esperando a la función de arriba: actívala y esta vuelve a funcionar». |
| Vuelve a activar la función de origen | Las dependientes que estaban activadas vuelven a funcionar al instante. |
| Desactiva un proceso o subproceso entero mientras algo aún lo necesita | Se niega y nombra quién lo necesita («… sigue siendo necesaria para: …»), salvo que elija **Desactivar igualmente, conservar sus ajustes** o desactivar también a los dependientes. |

**Conviene saber**

- Una función dependiente que está activada pero espera a su función de origen hace que su proceso muestre **Requiere atención**. Es el único estado en que un interruptor y la aplicación no coinciden, así que merece una mirada. Véase [Active una función con seguridad](help:setup.features.safely).
- Una función de origen puede estar en un proceso distinto del de su dependiente: **Servicios** (Ofertas para miembros) necesita **Pestaña Finanzas** (Facturación y pagos). La tarjeta advierte entonces de que activarlo todo también necesita la otra.
- La comprobación se hace sobre la función, no sobre un permiso: que un rol pueda hacer algo nunca basta si la función está desactivada.

**Véase también:** [Un interruptor de función](help:user.features.switch) · [Activar y desactivar procesos enteros](help:user.features.processes)

<!-- anchor: setup.features.off -->
### Desactivar no borra nada

**Público:** Propietario · Copropietario

Usted quiere poder cambiar de idea más adelante, así que necesita saber qué no toca un interruptor.

Desactivar una función detiene lo nuevo. No borra ni un solo registro: facturas, reservas, mensajes, roles y ajustes se quedan donde están, y volver a activar la función los recupera. Lo ya hecho, hecho está: una factura emitida mientras la función estaba activada conserva lo que dice.

Detrás de esto, DesKilo clasifica las acciones de una función conmutable en tres tipos:

| Tipo | Qué le hace el interruptor | Ejemplo |
|---|---|---|
| Trabajo nuevo (*acceptNew*) | Se detiene cuando la función está desactivada. | Iniciar una conversación nueva con los anfitriones; dar un rol propio a un miembro; bloquear un asiento; iniciar un pago en línea nuevo. |
| Trabajo ya abierto (*serviceExisting*) | Continúa, para que nada quede colgado. | Responder a una conversación ya iniciada; retirar un rol propio; levantar el bloqueo de un asiento; liquidar un pago ya abierto. |
| Vías inseguras (*suspended*) | Permanecen cerradas diga lo que diga el interruptor. | Reservado para una vía que el servidor juzgue insegura; hoy ninguna acción está clasificada así. |

Tres funciones lo dicen en su fila, con estas palabras: «Desactivado: no empieza nada nuevo; lo que ya está abierto aún puede atenderse y cerrarse.» Son **Escribir a los anfitriones**, **Los roles de este espacio** y **Los administradores pueden bloquear sitios**. **Entrada/salida automática al final del día** también detiene su barrido de fin de jornada cuando está desactivada, pero su fila no lo dice. En un servidor que no puede confirmarlo, la fila dice «no cuente con ello».

**Conviene saber**

- El dinero ya comprometido siempre se liquida: ningún interruptor bloquea una devolución de pago ni un reembolso.
- Con **Pagos en línea** desactivados, el servidor rechaza un pago en línea nuevo; uno que ya está abierto sigue liquidándose. Su fila no lleva ninguna nota al respecto.
- Un interruptor no sirve para ocultar algo a una persona concreta. Para eso use los [Roles](help:user.roles.matrix).

**Véase también:** [Un interruptor de función](help:user.features.switch)

<!-- anchor: setup.features.maturity -->
### Beta, Sin evaluar y la pregunta antes de activar

**Público:** Propietario · Copropietario

Usted ve una palabra pequeña bajo el nombre de una función y quiere saber qué hacer con ella.

<p><img src="images/setup-features-maturity.es.jpg" width="280"></p>

Cada fila de **Interruptores** lleva una insignia de madurez, que indica hasta qué punto se ha revisado la función frente a pruebas:

| Insignia | Significa |
|---|---|
| **Sin evaluar** | Nadie la ha evaluado todavía frente a pruebas. No dice nada malo de ella. |
| **Alfa** | Evaluada, en una fase temprana. |
| **Beta** | Evaluada, con límites conocidos; sus pruebas se ejecutan en cada cambio. |
| **Estable** | Evaluada y además cualificada con proveedores, equipos u operadores reales. |

En el momento de escribir esto, la mayoría de las funciones figuran como **Sin evaluar**, dieciocho como **Beta** y ninguna ha llegado aún a **Estable**.

*Qué pregunta la aplicación*

1. Accione el interruptor de una función **Alfa** o **Beta**.
2. La aplicación pregunta **¿Activar una función experimental?** y dice: «Aún no evaluada como estable: … Puede cambiar y tiene límites conocidos. Actívela solo si este espacio lo acepta.»
3. Nombra la fase de cada función y las funciones que se activarían con ella por ser necesarias.
4. Toque **Activar** para aceptar, o **Cancelar**: no se escribe nada.

**Conviene saber**

- Las funciones **Sin evaluar** no preguntan. Solo preguntan **Alfa** y **Beta**.
- La pregunta se hace con un solo interruptor. Un **Activar** de un proceso entero muestra lo que va a activar, pero no hace esta pregunta: active las funciones **Beta** una a una.
- Entre las funciones Beta en el momento de escribir esto figuran **Facturas**, **Pagos en línea**, **Gestión del IVA**, **Bonos**, **Gastos compartidos**, **Registros de uso**, **Políticas de reserva**, **Reserva en serie**, **Guarda de reserva**, **Solicitudes de eliminación de reservas**, **Finanzas en cuatro vistas**, **Suministros desde gastos**, **Validadores por rol o persona**, **Validaciones encadenadas**, **Entrada/salida automática al final del día**, **Exportación de datos (Excel)**, **Entrega de facturas al cliente** y el espacio de demostración. Lea los límites de cada función con **Más** antes de apoyarse en ella para el dinero.
- Varias de ellas son Esenciales y ya están activadas en un espacio nuevo. Arrancan activadas sin la pregunta; solo aparece cuando usted vuelve a activar una.
- **Madurez** limita la lista a una fase, lo que permite ver rápidamente todo lo experimental que su espacio ya utiliza.

**Véase también:** [Un interruptor de función](help:user.features.switch)

<!-- anchor: setup.features.profiles -->
### Tres puntos de partida

**Público:** Propietario · Copropietario

Usted no quiere decidir cien cosas. Aquí tiene tres puntos de partida realistas; cada uno enumera exactamente lo que está activado. Elija el más cercano y ajuste después.

El primero no necesita plantilla. El segundo es la plantilla lista para usar de la aplicación. El tercero se construye con las propias funciones. Se nombran por lo que ofrecen, no por un tamaño.

<!-- anchor: setup.features.profile-tiny -->
### Unos pocos lugares compartidos

**Público:** Propietario

Usted gestiona un puñado de mesas o salas que la gente reserva, y nada más por ahora. Cree el espacio con **Espacio vacío** o con la plantilla «A tiny space» en **Partir de**: dos plantas, cuatro mesas y ocho asientos, lo justo para reservar, escanear y explorar.

La plantilla no fija ninguna función, de modo que el espacio tiene exactamente las 45 funciones Esenciales de [Esencial y Plataforma](help:setup.features.tiers). No se activa nada más. Para este perfil, deje el resto como está:

- Reserva, calendario, mensajes, directorio, tarjetas QR de los puestos, biblioteca de documentos y consejos de ayuda: todo está ahí.
- **Pestaña Finanzas** y **Facturas** están activadas, pero mientras no introduzca su identidad legal y sus tarifas solo muestran un estado de cuenta vacío.
- Nada necesita configuración fuera del plano y de los horarios de apertura. Véase [Su lugar](help:setup.place.overview).

> **Consejo** Si nunca cobra nada, puede dejar activadas las funciones de dinero sin problema: los miembros simplemente no verán nada que pagar.

<!-- anchor: setup.features.profile-association -->
### Una asociación con una sala

**Público:** Propietario

Usted es una asociación francesa que comparte una sala, con una junta, miembros que pagan una cuota y reservas por medias jornadas. Elija la plantilla «Association de coworking (France)» en **Partir de**. Configura las reglas de apertura, tramos de cuota al 50 % y al 100 %, dos bonos prepago, los roles de la junta, el vocabulario en francés y dos plantas, y trae este perfil de funciones:

- Las 45 funciones Esenciales, excepto cuatro que desactiva: **Pestaña Eventos**, **Directorio de miembros**, **Ficha de socio** y **Agrupación de notificaciones**. Una asociación pequeña no necesita un flujo de eventos ni un directorio junto a sus conversaciones.
- Cuatro que activa, porque la junta las necesita: **Validaciones en el calendario** (decisiones mostradas en el calendario), **Bonos** (medias jornadas prepago para quienes no se suscriben, Beta), **Los roles de este espacio** (tesorero, secretario, responsable de sala) y **Vocabulario del espacio** (las palabras propias de la asociación).

Son 45 − 4 + 4 = 45 funciones activadas. La plantilla no trae identidad alguna, así que la dirección, el número de registro y los datos bancarios siguen siendo suyos para introducir, y el régimen de IVA empieza como «no sujeto».

**Conviene saber**

- Bonos es Beta y la plantilla lo activa sin la pregunta; es una decisión de la plantilla, y usted puede desactivarlo.
- La plantilla deja **Facturas** activada, del conjunto Esencial. Una asociación que no factura puede dejarla así.

<!-- anchor: setup.features.profile-invoicing -->
### Un coworking que factura

**Público:** Propietario

Usted alquila mesas a miembros y les envía facturas cada mes, en Francia o en Alemania. No hay plantilla lista para usar, así que este perfil es una lista de lo que hay que añadir al conjunto Esencial, en este orden. Todo cuelga de **Pestaña Finanzas** y **Facturas**, que ya están activadas.

| # | Active | Por qué | Necesita |
|---|---|---|---|
| 1 | **Series de numeración** | Decidir cómo se numeran los documentos antes de que exista el primero. | **Facturas** |
| 2 | **Facturas de suscripción** | La cuota de membresía se factura antes del mes al que corresponde. | **Facturas** |
| 3 | **Registros de uso** | Un registro del tiempo realmente utilizado (Beta). | **Facturas** |
| 4 | **Facturas de fin de mes** | Lo que el mes costó además de la suscripción se factura aparte. | **Facturas** |
| 5 | **Asistente de facturación** | Un cierre de mes guiado para quien se ocupa de la facturación. | **Facturas** |
| 6 | **El recorrido de una factura** | Cada factura muestra en qué punto está y a quién le toca mover. | **Facturas** |
| 7 | **Plantilla del PDF de factura** | Su propio texto de introducción y de pie en el PDF. | **Facturas** |
| 8 | **Informes de miembros** | El acuerdo financiero y el informe mensual de pagos para los miembros. | **Pestaña Finanzas** |
| 9 | **Recordatorios de pago** | Niveles de recordatorio, una carta por nivel, «Recordatorio pendiente» en las facturas atrasadas. | **Facturas** |
| 10 | **Informe de consumo** | Una carta a fin de mes con lo que se ha utilizado. | **Registros de uso** |

Después añada solo lo que le corresponda:

- **Gestión del IVA** (Beta) si su espacio está registrado a efectos del IVA. Después **Declaraciones de IVA**, y **Versiones de los tipos de IVA** y **Grupos de IVA** si su contable se los pide.
- **Los admins emiten facturas** si quiere que un administrador de facturación las emita. El propietario siempre puede.
- **Pagos en línea** (Beta) solo cuando tenga un proveedor de pago al que conectarse.
- **Recordatorios de pago automáticos** solo después de leer [lo que hacen](help:setup.money.reminders).
- **Suplementos de accesorios**, **Bonos** y **Gastos compartidos** cuando facture esas cosas.

**Conviene saber**

- Antes de la primera factura, complete su identidad legal y el IVA. Véase [Identidad legal y facturación](help:setup.money.identity).
- Emitir aquí solo funciona para espacios en Francia y Alemania.
- Active estas funciones de una en una y emita antes una factura de prueba en un espacio de prueba. Véase [El orden para activar las cosas](help:setup.features.order).

**Véase también:** [Dinero y facturación](help:setup.money.overview) · [Partir de una plantilla o de cero](help:setup.before.template)

<!-- anchor: setup.features.order -->
### El orden para activar las cosas

**Público:** Propietario · Copropietario

Usted quiere evitar el día en que todo está activado y nada funciona. Vaya proceso a proceso y mire cada uno desde el lado de un miembro antes de pasar al siguiente.

<p><img src="images/setup-features-order.es.jpg" width="280"></p>

**Pasos**

1. Conserve el conjunto Esencial y haga funcionar lo básico: los puestos, los horarios de apertura, una tarifa. Véase [Su lugar](help:setup.place.overview).
2. Abra [Funciones](app:/features) y abra la tarjeta de un proceso. Elija el que responda a su próxima necesidad, no el que parezca más completo.
3. Toque **Activar** en un subproceso, o abra una función concreta entre los **Interruptores**.
4. Lea la vista previa: qué es **También necesarias** y qué está ya activado.
5. Mírelo como un miembro: inicie sesión como uno (una segunda cuenta, o el lado de prueba de su espacio) y haga lo que haría un miembro.
6. Solo entonces pase al siguiente proceso.

*Un orden razonable*

| Paso | Proceso | Por qué en este lugar del orden |
|---|---|---|
| 1 | **Gestión de espacios** | Sin un lugar y unos horarios de apertura no se puede reservar nada. |
| 2 | **Reservas y uso** | Las reglas de reserva condicionan todo lo que viene después. |
| 3 | **Espacio y acceso** | Los roles y quién valida, antes de la primera invitación. |
| 4 | **Calendario y coordinación** | Los mensajes y las validaciones necesitan que existan personas. |
| 5 | **Ofertas para miembros**, después **Facturación y pagos** | Los precios antes que las facturas; la identidad legal antes de la primera factura. |
| 6 | **Documentos e información**, **Integraciones y automatización** | Dan forma y entregan lo que producen los demás. |
| 7 | **Operaciones y administración** | Pares, despliegues y transferencias cuando el espacio merece copiarse. |

**Conviene saber**

- Activar es barato y desactivar no borra nada, así que un paso equivocado cuesta tiempo, no datos. La excepción es todo lo que emite una factura: véase [Decisiones difíciles de deshacer](help:setup.before.permanent).
- Un espacio de prueba es el lugar adecuado para probar un proceso. Véase [Un espacio de prueba o uno real](help:setup.before.environment) y [Un espacio de prueba](help:user.advanced.test-space).
- Invite a los miembros en último lugar, después de los roles, las reglas de validación y las tarifas con las que se van a encontrar.

**Véase también:** [Activar y desactivar procesos enteros](help:user.features.processes)

<!-- anchor: setup.features.safely -->
### Active una función con seguridad

**Público:** Propietario · Copropietario

Usted está a punto de cambiar una función y quiere ver el efecto antes de que exista.

<p><img src="images/setup-features-safely.es.jpg" width="280"></p>

**Pasos**

1. Abra [Funciones](app:/features). Se muestra la vista **Procesos**.
2. Toque **Requiere atención**. Solo quedan los procesos que contienen algo activado pero en espera.
3. Abra una tarjeta. Una función **Activada, esperando** una función de origen con nombre es lo que hay que arreglar.
4. Arréglelo activando la función de origen, o desactivando la función.
5. Para cambiar una sola función, toque **Interruptores**, búsquela con **Buscar funciones** y accione su interruptor.
6. Lea la pregunta o la línea «También activado» y confirme.

*Qué significa «retenida»*

Una función está retenida cuando usted la eligió pero algo que necesita está desactivado. Su propio interruptor sigue activado, y por eso es fácil pasarlo por alto: la pantalla dice que la función está activada, y la aplicación no la ofrece. La tarjeta indica cuántas funciones están retenidas («… están activadas pero esperan un requisito desactivado») y qué requisito esperan, y se arregla en [Funciones](app:/features) mismo.

Otras cosas que una función puede esperar no están en esta pantalla. Una función puede estar activada y plenamente permitida mientras faltan sus datos: su identidad legal, una sede, un proveedor de pago. Esos aparecen en **Configuración de este espacio**, en **Datos que necesitan sus funciones (identidad, banco, plataformas)**, en lo alto de los ajustes del espacio.

**Conviene saber**

- Si otra persona cambió las funciones mientras usted miraba, la aplicación no escribe nada y lo dice: «Las funciones cambiaron mientras tanto, así que no se guardó nada.» Vuelva a mirar la lista y accione de nuevo.
- **Modificadas** cuenta los interruptores que difieren del valor por defecto del registro. En un espacio nuevo ya muestra un número (las funciones de Plataforma que arrancan desactivadas), así que no es un recuento de sus propios cambios.
- Solo un propietario o un copropietario puede escribir las funciones. El servidor lo vuelve a comprobar en el momento de escribir.

**Véase también:** [Activar y desactivar procesos enteros](help:user.features.processes) · [Un interruptor de función](help:user.features.switch)

<!-- anchor: setup.features.consistency -->
### Evite funciones que se contradicen

**Público:** Propietario · Copropietario · Administrador/a de facturación

Usted quiere saber qué combinaciones dejan un espacio a medio funcionar, y cuáles de ellas detecta la aplicación por usted.

La aplicación tiene salvaguardas para algunas contradicciones y ninguna para otras. En la tabla, una salvaguarda es lo que hace la aplicación; una laguna es lo que sigue siendo responsabilidad suya.

| Si tiene… | Salvaguarda de la aplicación | Laguna que queda |
|---|---|---|
| **Facturas** activadas, sin identidad legal | Se rechaza la emisión, con **Complete estos datos antes de emitir** listando la dirección, el número de IVA, etc. que faltan. La necesidad también aparece en **Configuración de este espacio**. | La función está activada desde el primer día, así que nada impide invitar a los miembros y llevar un mes antes de que exista la identidad. |
| Un país distinto de Francia o Alemania | Al emitir, dice que el país «debe ser Francia o Alemania para emitir aquí». | Nada avisa al elegir el país ni al activar la facturación. |
| Registrado a efectos del IVA, sin ningún tipo en vigor | Se rechaza la emisión hasta que haya un tipo en vigor. | Con **Gestión del IVA** desactivada, la configuración queda oculta mientras los tipos guardados siguen aplicándose. Compruebe los tipos tras desactivarla. |
| **Pagos en línea** activados, sin proveedor | Se rechaza un pago en línea nuevo cuando la función está desactivada; el proveedor que falta aparece en **Configuración de este espacio**. | Puede activarla sin proveedor. Conéctelo antes: [Proveedor de pago](help:user.money.payments.provider). |
| **Modo quiosco** activado, sin credenciales ni miembro de quiosco | **Credenciales RFID / NFC**, **Credenciales QR**, **Fotos de los miembros en el quiosco** e **Iniciar sesión con credencial** no pueden estar activadas sin él. | Nada comprueba que exista un miembro de quiosco ni que se haya emitido una credencial. Véase [Ponga en marcha una tableta de pared](help:user.kiosk.mode). |
| **Sedes** activadas, sin ninguna sede | **Al menos una sede** aparece entre los datos que necesitan sus funciones. | El interruptor puede estar activado sin ninguna sede. |
| **Notificaciones push** activadas, sin servicio push | Los miembros siguen recibiendo todo en la aplicación. | Los teléfonos no reciben nada hasta que quien gestiona la instalación haya configurado el servicio push. Véase [Cómo se informa a los miembros](help:setup.notify.channels). |
| **Recordatorios de pago** activados, **Recordatorios de pago automáticos** activados | Los segundos no pueden estar activados sin los primeros. | El programador del servidor los envía cada mañana; si la base de datos no tiene programador, se envían cuando un administrador abre Finanzas. |
| Una regla de validación que pide más validadores de los que hay | **Configuración de este espacio** dice «Una regla pide más validadores de los que tiene este espacio» y retiene la primera reserva cuando la regla es para reservas. | Las demás solicitudes se crean, no se pueden completar y caducan a los siete días. Véase [Quién valida](help:user.validation.overview). |
| **Solicitudes de eliminación de reservas** activadas, nadie que valide | La misma línea de preparación. | La misma laguna. |
| **Reservas de mesa, oficina y planta** activadas | **Los admins pueden asignar plantas** la necesita. | Además, cada miembro necesita el derecho; nada comprueba que alguien lo tenga. |
| Una función dependiente activada, su función de origen desactivada | **Requiere atención**, y «Esperando a la función de arriba». | Ninguna: este caso está totalmente cubierto. |
| Un espacio creado a partir de una plantilla | La plantilla nombra lo que usted debe introducir (identidad, banco, sede). | No trae nada de eso, así que un espacio puede empezar con **Facturas** activadas y nada con lo que emitir. |

**Conviene saber**

- La regla práctica: si una función lleva a un documento su nombre, su dinero o sus obligaciones legales, termine sus datos antes de avisar a los miembros.
- **Configuración de este espacio** es una lista, no un cerrojo. Nunca le impide activar algo.
- La comprobación «Antes de que alguien pueda reservar aquí» solo habla de lo que una reserva necesita de verdad: la zona horaria, la moneda, un día de apertura y al menos un asiento.

**Véase también:** [Identidad legal y facturación](help:setup.money.identity) · [Ensayo en seco](help:setup.money.dry-run)

<!-- anchor: setup.features.map -->
### El mapa de funciones

**Público:** Propietario · Copropietario

Usted quiere un lugar que diga, para las funciones principales, qué obtienen los miembros, qué necesita y quién debe configurarla. «Necesita» enumera primero la función de origen y luego los datos ajenos a la pantalla Funciones. «Quién» es la persona que debe hacer algo para que sea útil; «Nadie» significa que funciona en cuanto se activa.

*Espacio y acceso*

| Función | Qué aporta a los miembros | Qué necesita | Quién la configura |
|---|---|---|---|
| **Directorio de miembros** | La pestaña de la comunidad: quién está, estados, presencia. | | Nadie |
| **Copropietarios** | Permisos de propietario para personas designadas, ahora o en una sucesión. | | Propietario |
| **Gestión de roles** | La matriz de qué rol tiene qué permiso. | | Propietario |
| **Asignación de roles** | Una sección Roles en cada ficha de miembro. | **Gestión de roles** | Propietario |
| **Los roles de este espacio** | Roles propios, como tesorero o secretario. | | Propietario |
| **Las preguntas de este espacio** | Sus propias preguntas en el formulario de identidad. | | Propietario |
| **Datos personales** | Nombre, dirección, teléfono e identificadores que imprimen las cartas. | | Los miembros |
| **Perfiles gestionados** | Miembros sin cuenta, a quienes se reserva y se factura. | **Directorio de miembros** | Administrador/a |
| **Ficha de socio** | Una página por miembro. | **Directorio de miembros** | Nadie |
| **Visitas de invitados** | Una persona que no es miembro puede pedir visitar. | | Quien admite las visitas |
| **Modo quiosco** | Una tableta de pared fijada al plano en vivo. | Una tableta y un miembro de quiosco | Propietario |
| **Credenciales RFID / NFC** | Entrar acercando una tarjeta. | **Modo quiosco**, Android con NFC, credenciales emitidas | Propietario |
| **Credenciales QR** | Tarjetas de credencial QR imprimibles. | **Modo quiosco** | Propietario |
| **Iniciar sesión con credencial** | Credencial y PIN en lugar de escribir un correo electrónico. | **Credenciales RFID / NFC** | Propietario, y después cada miembro |
| **Etiquetas NFC/RFID de las sillas** | Un chip en una silla abre su asiento. | Etiquetas | Propietario |
| **Códigos QR de espacios** | Tarjetas QR imprimibles por puesto. | | Nadie |

*Gestión de espacios*

| Función | Qué aporta a los miembros | Qué necesita | Quién la configura |
|---|---|---|---|
| **Sedes** | Varias direcciones, cada una con su propio registro. | Al menos una sede | Propietario |
| **Eliminar espacios con historial** | Los propietarios pueden eliminar un puesto que tiene reservas pasadas. | | Nadie |
| **Los administradores pueden bloquear sitios** | Asientos marcados como no reservables por mantenimiento. | | Propietario |
| **Horario de trabajo** | La jornada laboral y la reserva por horas exactas. | | Propietario |
| **Días festivos** | Días de cierre a partir de los festivos de un año. | | Propietario |
| **Importar días festivos** | Festivos de un país o región importados. | **Días festivos** | Propietario |
| **Ocupación de puestos** | Una cifra mensual de cuánto se reservó. | | Propietario |
| **Fotos de los miembros en el plano** | Fotos de los ocupantes en los asientos. | | Nadie |
| **Vocabulario del espacio** | Las palabras propias del espacio para unas cuantas etiquetas. | | Propietario |
| **Colores del espacio** | El color de la marca y los colores de las salas. | | Propietario |
| **Anuncio público del espacio** | Una página pública con lo que usted decida mostrar. | | Propietario |

*Reservas y uso*

| Función | Qué aporta a los miembros | Qué necesita | Quién la configura |
|---|---|---|---|
| **Reserva en serie** | Repetir una reserva. | | Nadie |
| **Reservar para otros** | Los administradores reservan para los miembros. | | Nadie |
| **Reservas de mesa, oficina y planta** | Reservar una mesa, una oficina o una planta enteras. | Un derecho concedido a cada miembro | Propietario |
| **Los admins pueden asignar plantas** | Los administradores asignan esas reservas. | **Reservas de mesa, oficina y planta** | Propietario |
| **Políticas de reserva** | Reservas pasadas, reservas fuera de horario, salida registrada por un administrador. | | Propietario |
| **Guarda de reserva** | Cada pantalla comprueba las reglas y nombra el motivo. | **Políticas de reserva** | Nadie |
| **Entrada/salida automática al final del día** | Las reservas sin registrar se completan solas. | | Propietario |
| **Registros de uso** | El tiempo realmente utilizado, y una solicitud para dejar de facturar el tiempo no utilizado. | **Facturas** | Administrador/a de facturación |

*Calendario y coordinación*

| Función | Qué aporta a los miembros | Qué necesita | Quién la configura |
|---|---|---|---|
| **Pestaña Calendario**, **Calendario central**, **Vistas del calendario** | Mes, semana y agenda, con todo lo fechado. | | Nadie |
| **Validaciones en el calendario** | Las decisiones se muestran en el momento en que se tomaron. | **Calendario central** | Nadie |
| **Pestaña Eventos** | El flujo de actividad y las confirmaciones. | | Nadie |
| **Agrupación de notificaciones** | Notificaciones agrupadas en el flujo. | | Nadie |
| **Validadores por rol o persona** | Una regla puede nombrar quién valida y cuántas personas. | | Propietario |
| **Validaciones encadenadas** | Validaciones pedidas una tras otra. | | Propietario |
| **Solicitudes de eliminación de reservas** | Un miembro pide eliminar una reserva pasada. | Un validador | Propietario |
| **Notificaciones entre miembros** | Conversaciones privadas y de grupo. | | Nadie |
| **Mensajes, renovados** | Barra de bandeja, fijar, silenciar, archivar, borradores. | | Nadie |
| **Escribir a los anfitriones** | Quien encuentra su página puede escribirle. | Una página publicada | Propietario |
| **Menciones en grupos**, **Reenvío de mensajes**, **Protección contra capturas de pantalla** | Extras de mensajería. | **Notificaciones entre miembros** | Nadie |

*Ofertas para miembros*

| Función | Qué aporta a los miembros | Qué necesita | Quién la configura |
|---|---|---|---|
| **Servicios** | Un catálogo de cosas para consumir y pagar. | **Pestaña Finanzas** | Administrador/a de facturación |
| **Suplementos de accesorios** | Accesorios de asiento con precio por media jornada. | **Pestaña Finanzas** | Administrador/a de facturación |
| **Negociaciones de precios** | Condiciones propias para un miembro. | **Pestaña Finanzas** | Administrador/a de facturación |
| **Condiciones de pago por miembro** | Plazos de pago propios. | **Facturas** | Administrador/a de facturación |
| **Bonos** | Medias jornadas prepago (Beta). | **Facturas**, un paquete definido | Administrador/a de facturación |

*Facturación y pagos*

| Función | Qué aporta a los miembros | Qué necesita | Quién la configura |
|---|---|---|---|
| **Pestaña Finanzas** | La pestaña Finanzas: estado de cuenta, pagos, gastos. | | Nadie |
| **Finanzas en cuatro vistas** | Estado de cuenta, Pagos, Facturas, Documentos. | **Pestaña Finanzas** | Nadie |
| **Informes de miembros** | El acuerdo y el informe mensual de pagos. | **Pestaña Finanzas** | Administrador/a de facturación |
| **Facturas** | Facturas firmadas e inmutables (Beta). | **Pestaña Finanzas**, identidad legal, IVA, FR o DE | Administrador/a de facturación |
| **Los admins emiten facturas** | Los administradores también las emiten. | **Facturas** | Propietario |
| **Facturas de suscripción** | La cuota facturada antes de su mes. | **Facturas**, una fecha | Administrador/a de facturación |
| **Facturas de fin de mes** | El uso facturado después del mes. | **Facturas** | Administrador/a de facturación |
| **Agrupar facturas** | Varias facturas abiertas como una sola. | **Facturas** | Administrador/a de facturación |
| **El recorrido de una factura** | En qué punto está cada factura. | **Facturas** | Nadie |
| **Asistente de facturación** | Un cierre de mes guiado. | **Facturas** | Administrador/a de facturación |
| **Series de numeración** | Numeración por diario. | **Facturas** | Administrador/a de facturación |
| **Pagos en línea** | Pagar en línea (Beta). | **Pestaña Finanzas**, un proveedor de pago | Propietario |
| **Recordatorios de pago** | Niveles de recordatorio y cartas. | **Facturas**, reglas | Administrador/a de facturación |
| **Recordatorios de pago automáticos** | Recordatorios enviados por sí solos. | **Recordatorios de pago** | Administrador/a de facturación |
| **Suministros desde gastos** | Los suministros comprados pasan a ser servicios. | **Servicios** | Administrador/a de facturación |
| **Gastos programados** | Costes recurrentes programados. | **Pestaña Finanzas** | Administrador/a de facturación |
| **Gastos compartidos** | Costes repartidos entre miembros. | **Facturas** | Administrador/a de facturación |
| **Asistente de reparto** | Un reparto guiado de un coste compartido. | **Gastos compartidos** | Administrador/a de facturación |
| **Libro contable** | Quién lleva los libros oficiales. | **Facturas** | Administrador/a de facturación |
| **Gestión del IVA** | Tipos de IVA y selectores (Beta). | **Facturas**, régimen de IVA | Administrador/a de facturación |
| **Declaraciones de IVA** | La declaración periódica. | **Gestión del IVA** | Administrador/a de facturación |
| **Grupos de IVA**, **Versiones de los tipos de IVA**, **IVA según el cliente** | Un tratamiento del IVA más fino. | **Gestión del IVA** | Administrador/a de facturación |

*Documentos e información, Operaciones, Integraciones*

| Función | Qué aporta a los miembros | Qué necesita | Quién la configura |
|---|---|---|---|
| **Biblioteca de documentos** | Estatutos, actas, guías, por rol. | | Propietario |
| **Exportar PDF** | La factura mensual en PDF. | | Nadie |
| **Plantilla del PDF de factura** | Sus textos en la factura. | **Facturas** | Propietario |
| **Diseñador de informes**, **Maquetas de informe posicionadas**, **Textos de informes** | Informes diseñados. | **Plantilla del PDF de factura** | Propietario |
| **Informe de consumo** | Una carta mensual sobre lo que se utilizó. | **Registros de uso** | Administrador/a de facturación |
| **Informe de IVA** | Cada línea imponible, con un CSV. | **Declaraciones de IVA** | Administrador/a de facturación |
| **Registro de accesos a datos** | Los miembros ven quién ha consultado sus finanzas. | **Pestaña Finanzas** | Nadie |
| **Exportación de datos (Excel)** | El propietario exporta los datos como libro de cálculo (Beta). | El permiso **Exportar contabilidad y datos** | Propietario |
| **Exportación y borrado** | Un miembro exporta y borra sus propios datos. | | Nadie |
| **Modo grabación** | Sustituye en pantalla a las personas reales por otras inventadas. | | Propietario |
| **Pares de entornos**, **Despliegues** | Un lado de prueba y un lado real, con despliegue. | | Propietario |
| **Configuración en el archivo del espacio** | Toda la configuración viaja en el archivo del espacio. | **Exportación de datos (Excel)** | Propietario |
| **Asistente de instancia** | Crear un servidor nuevo desde la aplicación. | | Operador/a |
| **Lo que te espera** | Una lista ordenada de lo que le espera. | | Nadie |
| **Grabador de tareas** | Grabar y reproducir los pasos de una tarea. | | Nadie |
| **Notificaciones push** | Confirmaciones pendientes en el teléfono. | El servicio push de la instalación | Operador/a |
| **Integración con WhatsApp** | Un chat con un miembro con un toque, el enlace del grupo. | **Directorio de miembros** | Propietario |
| **Entrega de facturas al cliente** | Envío a la plataforma propia del cliente (Beta). | **Facturas**, una cuenta | Administrador/a de facturación |
| **Interfaz MCP** | Se puede conectar un asistente. | Una autorización por persona, aprobada por la instalación | Propietario, y después operador/a |

**Conviene saber**

- Los nombres son los de la lista de **Interruptores**. Allí se muestra el nivel Esencial o Plataforma de cada una.
- Algunas funciones no figuran aquí. Las funciones de comodidad (consejos de ayuda, animaciones, estilo de navegación, formatos regionales) no tienen fila en la tabla: funcionan en cuanto se activan.

**Véase también:** [Quién hace qué](help:setup.before.who) · [Activar y desactivar funciones](help:user.features.processes)
