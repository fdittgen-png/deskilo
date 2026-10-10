<!-- anchor: setup.consistent.overview -->
## Mantenerlo coherente

Un espacio puede estar mal de dos maneras: por un ajuste que falta y por dos ajustes que se contradicen. DesKilo detecta algunos de los dos casos y lo dice en pantalla. Este capítulo enumera lo que detecta y dónde lo ve, explica con claridad lo que no detecta y le da una auditoría para pasar antes de abrir las puertas y una rutina breve para cada mes.

En este capítulo:
- [Las protecciones que le da la aplicación](help:setup.consistent.guards)
- [Los errores que las protecciones no detectan](help:setup.consistent.gaps)
- [La auditoría previa al lanzamiento](help:setup.consistent.audit)
- [La rutina mensual](help:setup.consistent.monthly)
- [Cuando algo parece ir mal](help:setup.consistent.wrong)
- [Lo que no tiene vuelta atrás](help:setup.consistent.irreversible)

El ejemplo que seguimos es *Atelier du Marché*. Su propietaria, Ada, pasa la auditoría una vez en un espacio de prueba y otra en el espacio real.

<!-- anchor: setup.consistent.guards -->
### Las protecciones que le da la aplicación

**Público:** Propietario · Copropietario · Administrador/a · Administrador/a de facturación

Quiere saber cuáles de sus errores señalará la aplicación y dónde lo hará, para mirar en el sitio adecuado.

<p><img src="images/setup-consistent-features-attention.es.jpg" width="280"></p>

| Protección | Qué detecta | Dónde se ve |
|---|---|---|
| Una función que necesita otra | Una función no puede funcionar sin la que necesita. Activar una función activa la función de la que depende y nombra lo que se ha activado. Desactivar la función de la que otras dependen retiene las dependientes y conserva su propia elección. | **Funciones**: el flujo de activación con su vista previa, **Requiere…** y *Esperando la función de arriba* |
| Un proceso retenido | Una función que está activada pero espera algo que está desactivado. | **Funciones**, vista **Procesos**: el estado **Requiere atención** y su filtro |
| La lista de preparación | Una línea por ámbito del espacio, con su estado, quién actúa y dónde se configura. Ámbitos: **Días de apertura, zona horaria y moneda**, **Puestos reservables en el plano**, **Planes de membresía y tarifas**, **Invitar a los primeros miembros**, **Cómo pagan los miembros**, **Roles y quién valida las solicitudes**, **Exportación y recuperación**, **Lo que pueden hacer los miembros**, **Datos que necesitan sus funciones (identidad, banco, plataformas)**, **Una primera reserva** y, cuando proceda, **La identidad legal y la dirección del espacio** (solo con **Facturas** activada), **Servidor y versión de la base de datos** y **Acceso de asistentes (opcional)** (este último solo con la interfaz MCP activada). | **Configuración de este espacio**, en la parte superior de [Espacio](app:/workspace-settings) |
| La línea que impide una primera reserva | Los ámbitos que la lista marca como **Necesario para una primera reserva**: una zona horaria, una moneda, un día laborable abierto, un puesto, miembros que tengan **Reservar y usar las reservas** (un espacio nuevo no les concede nada) y, cuando una regla de validación de cualquier tipo pide más validadores de los que existen, esos validadores. Lo demás es opcional y se puede dejar a un lado con **Más adelante**. | *Antes de que nadie pueda reservar aquí*, en la tarjeta Primeros pasos de [Reservar](app:/reserve) |
| La línea que impide una primera factura | Con **Facturas** activada, la identidad legal y la dirección del espacio. Sin ellas no se puede emitir ninguna factura, así que el ámbito no se puede dejar a un lado. | **Configuración de este espacio**: el ámbito **La identidad legal y la dirección del espacio**, marcado como **Necesario antes de facturar**; mientras es el paso siguiente, el titular de la tarjeta dice «Antes de facturar: …» |
| Lo que sus funciones aún necesitan en local | Datos bancarios, un proveedor de pagos en línea, una cuenta de facturación electrónica, un sitio. La identidad legal no figura aquí: con **Facturas** activada es un ámbito propio (arriba). | La misma tarjeta, ámbito **Datos que necesitan sus funciones (identidad, banco, plataformas)**, con **Configurar** y **Recomendado** |
| La protección de la factura | Una factura se rechaza hasta que está completa: la dirección del espacio, su número de IVA, un país que sea Francia o Alemania, un fundamento legal para una exención, el nombre, la dirección y el número de IVA del miembro cuando se aplica la inversión del sujeto pasivo, un tipo de IVA en vigor, una explicación para cada línea facturada al 0 %. Las facturas transfronterizas, con inversión del sujeto pasivo, de exportación o exentas se rechazan: emítalas fuera de la aplicación. | **Complete estos datos antes de emitir**, con los elementos que faltan |
| La protección del pago en línea | Con **Pagos en línea** desactivado, el servidor rechaza un pago en línea nuevo. Uno ya abierto aún se liquida. | Las pantallas de pago (la fila de la función no lleva ninguna nota al respecto) |
| La protección de la validación | **Validaciones requeridas** por encima de las personas disponibles, para cualquier tipo de solicitud. | **No hay suficientes validadores elegibles.** en el editor de reglas; «Una regla pide más validadores de los que tiene este espacio» en la lista de preparación, donde **Roles y quién valida las solicitudes** pasa entonces a ser obligatorio |
| El bloqueo de la moneda y el país | En cuanto el espacio ha emitido un documento o registrado dinero, el servidor rechaza cualquier cambio de **Moneda** o de **País**, desde el formulario de ajustes, una importación o cualquier otro sitio. La zona horaria no queda bloqueada. | «La moneda y el país quedan fijados en cuanto el espacio ha emitido un documento o registrado dinero. No se ha guardado nada.» al guardar [Espacio](app:/workspace-settings) |
| La bandeja del propietario | Lo que queda por configurar: una línea «Por configurar: …» por cada ámbito obligatorio de la lista de preparación que no está listo, y una línea «… funciones activadas esperan «…»» por cada función desactivada que retiene otras. | [Lo que le necesita](help:user.collaborate.attention); un toque abre la pantalla donde se configura, o **Funciones** |
| La protección de la serie de numeración | Se rechaza un reinicio más frecuente que la fecha impresa en el número. | [Series de numeración](app:/settings/number-sequences), al guardar |
| El control de madurez | Una función evaluada como **Alfa** o **Beta**. | Una confirmación antes de activarla y una insignia en cada interruptor |
| El control de sustitución del plano | Sustituir el plano o los ajustes desde un archivo. | Un aviso de que no se puede deshacer. El plano se rechaza cuando ya existen reservas |

**Conviene saber**

- **Configuración de este espacio** es una lista, no un candado. Nunca le impide activar algo.
- La mayoría de las protecciones actúan cuando intenta emitir, pagar o reservar, no cuando elige un ajuste. Por eso existe la auditoría de más abajo.
- La bandeja del propietario ([Lo que le necesita](help:user.collaborate.attention)) solo muestra los ámbitos obligatorios y las funciones retenidas. Los ámbitos opcionales se quedan en la lista de preparación: léala usted mismo.

**Véase también:** [Evite funciones que se contradicen](help:setup.features.consistency) · [Revise su espacio](help:setup.place.check)

<!-- anchor: setup.consistent.gaps -->
### Los errores que las protecciones no detectan

**Público:** Propietario · Copropietario · Administrador/a de facturación

Quiere la lista honesta de lo que sigue siendo responsabilidad suya. Son configuraciones que la aplicación le deja crear y sobre las que no avisa. Cada una tiene una forma de evitarla a mano.

| Error | Por qué nada lo impide | Cómo evitarlo |
|---|---|---|
| Elegir un país distinto de Francia o Alemania y esperar facturas | La aplicación ofrece muchos países y tipos de IVA, pero solo emite facturas para Francia y Alemania. Nada lo dice al elegir el país. | Decidirlo antes de prometer una factura a los miembros. En otros países, mantenga los extractos en la aplicación y emita las facturas fuera de ella. |
| Estar registrado en el IVA sin ningún tipo en vigor | Se rechaza la emisión, pero solo en la primera factura. La descripción de **Gestión del IVA** y el aviso de la pantalla de identidad legal lo dicen; nada se lo impide antes. Con **Gestión del IVA** desactivada, la configuración queda oculta pero los tipos guardados siguen aplicándose. | Añadir el tipo en [IVA](app:/vat) antes del primer cierre mensual y emitir una factura de prueba. |
| **Pagos en línea** activados sin proveedor | Puede activarlos; la falta de proveedor solo aparece como un elemento de la lista de preparación. | Conectar primero el proveedor y activar después. |
| **Facturas** activadas sin identidad legal | La función está activada desde el primer día. La lista de preparación marca la identidad como **Necesario antes de facturar** y Lo que le necesita la muestra, pero nada le impide invitar a miembros y llevar un mes entero; el rechazo llega en el momento de emitir. | Rellenar la identidad antes de decir a los miembros que se les facturará. |
| Una regla que necesita más validadores de los que tiene | El editor le deja guardar una por encima de las personas disponibles. La lista de preparación marca entonces **Roles y quién valida las solicitudes** como obligatorio, sea cual sea el tipo de solicitud, pero las solicitudes creadas antes de corregirlo no pueden completarse y caducan a los siete días. | Contar los propietarios y administradores activos tras cada regla. Véase [Evite solicitudes que esperan para siempre](help:setup.people.stuck). |
| Miembros que no pueden abrir el plano | En un espacio nuevo, la tarjeta **Usuario** de [Roles](app:/roles) está vacía. La lista de preparación marca **Lo que pueden hacer los miembros** hasta que los miembros tengan **Reservar y usar las reservas**, pero solo comprueba ese: los otros cinco permisos de uso diario le corresponde marcarlos a usted. | Marcar los permisos de uso diario y unirse una vez con una segunda cuenta. |
| Un espacio creado a partir de una plantilla | Una plantilla nunca incluye la identidad, los datos bancarios, los sitios ni las invitaciones. | Tratar el ámbito **Datos que necesitan sus funciones (identidad, banco, plataformas)** como una lista de tareas. |
| Un archivo de ajustes que promete más de lo que entrega | El archivo incluye la matriz de roles con todos los permisos, sus propios roles, todas las reglas de validación, la numeración de facturas y de miembros y los precios de todo el espacio; no los miembros, el periodo de IVA, el nombre del espacio ni las credenciales de factura electrónica. Cuando **Configuración en el archivo del espacio** está desactivada en el destino, la importación pregunta antes: **Activar y aplicar** o **Importar sin la configuración**. Un plano no se sustituye cuando ya existen reservas. | Volver a introducir a mano lo que no incluye y leer la vista previa antes de **Sustituir e importar**. |
| Recordatorios que nunca se ejecutan | Se ejecutan cada mañana en el servidor si la instalación programa tareas (pg_cron); si no, cuando un administrador abre Finanzas. El interruptor y la descripción de la función lo dicen, pero no pueden saber cuál se aplica a su instalación. También permanecen en silencio cuando **Recordatorios de pago automáticos** está desactivada. | Preguntar al operador si existe el programador y abrir usted mismo Finanzas si no existe. Véase [Recordatorios de pago](help:user.money.reminders.automatic). |
| Cambiar la zona horaria cuando ya hay dinero | El servidor bloquea la moneda y el país en cuanto el espacio ha emitido un documento o registrado dinero, pero no la zona horaria, en la que se cuentan cada día laborable, cada media jornada y cada día de cierre. | Elegirla el primer día. Véase [Decisiones difíciles de deshacer](help:setup.before.permanent). |
| Una numeración o un periodo de IVA que no encaja con el formato de su gestor | La aplicación no los compara con la exportación contable del país. | Pedir a su gestor el formato de numeración y la exportación que usa antes de emitir. Véase [Exportaciones contables](help:user.invoicing.accounting-export). |
| Tomar una prueba por el espacio real | Más allá de la marca de agua en los documentos impresos, la diferencia es fácil de pasar por alto. | Mirar el banner del espacio de prueba y el lado que se muestra en [Yo](app:/me) antes de actuar. |

**Conviene saber**

- Un quiosco sin miembro de quiosco, una función de sitios sin ningún sitio, un push sin servicio de push: [Evite funciones que se contradicen](help:setup.features.consistency).
- La aplicación es más estricta de lo que parece con las facturas y más laxa de lo que parece con todo lo demás. En caso de duda, emita una factura de prueba en un espacio de prueba.

**Véase también:** [Un ensayo seguro](help:setup.money.dry-run)

<!-- anchor: setup.consistent.audit -->
### La auditoría previa al lanzamiento

**Público:** Propietario · Copropietario

Quiere pruebas, no una sensación, antes de abrir. Treinta y una comprobaciones, en tres niveles. Pase *Abrir* antes de invitar a nadie, *Funcionar* antes de prometer nada sobre dinero y *Crecer* antes de que salga la primera factura. Hágalo primero en un espacio de prueba, con una segunda persona.

*Abrir: un lugar que la gente puede reservar*

| N.º | Comprobación | Dónde | Qué aspecto tiene lo correcto |
|---|---|---|---|
| 1 | País, moneda, zona horaria | [Espacio](app:/workspace-settings), **Datos generales** | Atelier du Marché: Francia, EUR, Europe/Paris, fijados antes del primer documento o pago, tras el cual la moneda y el país quedan bloqueados |
| 2 | Idioma del espacio | La misma pantalla | El idioma en que están escritas sus invitaciones |
| 3 | Días y horas de apertura | [Disponibilidad](app:/availability) | Los días en que abre están marcados; las horas encajan con el día |
| 4 | Días de cierre | Disponibilidad, días de cierre | Los festivos y cierres de los próximos meses están introducidos, antes del primer fin de mes |
| 5 | Al menos un puesto | [Editor del espacio](app:/editor) | Cada sala que alquila tiene puestos |
| 6 | Preparación | **Configuración de este espacio** | Nada en **Días de apertura, zona horaria y moneda**, **Puestos reservables en el plano** ni **Lo que pueden hacer los miembros** necesita configuración |
| 7 | Usted reservó un puesto | [Reservar](app:/reserve) | El puesto se reserva, se registra y se cancela sin sorpresas |
| 8 | El ID del espacio | [ID del espacio y QR](app:/workspace-code) | El ID es uno que se puede decir en voz alta; el QR está impreso |
| 9 | Permisos de uso diario | [Roles](app:/roles) | **Usuario** tiene los seis permisos de uso diario, entre ellos **Reservar y usar las reservas** |
| 10 | Se unió una segunda cuenta | Otro dispositivo | Fue aprobada y pudo abrir el plano y reservar |
| 11 | Más de una persona puede actuar | [Miembros y planes](app:/members) | Un propietario más un copropietario o un administrador, todos **Activo** |
| 12 | Recuento de validaciones | [Reglas de validación](app:/validation) | Ninguna regla pide más validadores que propietarios y administradores activos; **Roles y quién valida las solicitudes** no necesita configuración |
| 13 | La invitación en cada idioma | **Comunidad e invitaciones** | Leyó cada versión una vez; no queda ninguna etiqueta sin rellenar |
| 14 | El lado en que está | [Yo](app:/me) | El banner del espacio de prueba aparece, o no, como usted pretendía |

*Funcionar: la gente paga y los roles se sostienen*

| N.º | Comprobación | Dónde | Qué aspecto tiene lo correcto |
|---|---|---|---|
| 15 | Tramos de tarifas | [Facturación](app:/billing) | Cada porcentaje que un miembro puede elegir cae en un tramo; sin huecos entre 0 y 100 por ciento |
| 16 | Planes ofrecidos | Facturación, niveles | Solo los planes que quiere vender |
| 17 | Con qué empiezan los miembros nuevos | **Nuevos miembros**, en Espacio | La suscripción y la regla para cuando se acaban los días son las que eligió |
| 18 | Bonos y servicios | Facturación, [Servicios](app:/services) | Los nombres y los precios se leen bien para un miembro |
| 19 | Cómo pagan los miembros | **Cómo pagan los miembros** en la lista de preparación | El ámbito indica **Listo** y los datos bancarios esperados (IBAN, referencia) aparecen en Ajustes; un proveedor por sí solo también lo deja listo |
| 20 | Pagos en línea | [Funciones](app:/features) | Desactivados, salvo que haya un proveedor conectado |
| 21 | Administradores | Miembros y planes | Cada uno es una persona a quien confiaría los datos de todos los miembros |
| 22 | Tarjeta del administrador de la matriz | Roles | Sabe leer cada marca y defenderla |
| 23 | A quién se avisa de qué | [Cómo se avisa a los miembros](help:setup.notify.members) | Los miembros encuentran todo en **Eventos**; push solo si el operador lo configuró |
| 24 | Quiosco y credenciales | [Funciones](app:/features) | Desactivados, o existe un miembro de quiosco y se han emitido credenciales |
| 25 | Sitios | Funciones | Desactivados, o existe al menos un sitio |
| 26 | Funciones retenidas | **Funciones**, **Requiere atención** | El filtro no muestra ningún proceso, y Lo que le necesita no tiene ninguna línea sobre funciones que esperan |

*Crecer: facturas, impuestos y registros*

| N.º | Comprobación | Dónde | Qué aspecto tiene lo correcto |
|---|---|---|---|
| 27 | Identidad legal | [Identidad legal y facturación electrónica](app:/legal-identity) | **La identidad legal y la dirección del espacio** indica **Listo**, y **Complete estos datos antes de emitir** no muestra nada al iniciar una factura de prueba |
| 28 | Régimen de IVA y tipos | [IVA](app:/vat) | El régimen es el que le dio su gestor; hay un tipo en vigor para el predeterminado |
| 29 | Formato de numeración | [Series de numeración](app:/settings/number-sequences) | Leyó la vista previa y su gestor está de acuerdo |
| 30 | Una factura de prueba | Espacio de prueba, asistente de cierre mensual | Se emitió, en cada idioma que leen sus miembros, sin ningún elemento que falte |
| 31 | Una exportación reciente | **Exportación y recuperación** | «Hay una exportación reciente registrada» |

**Pasos**

1. Imprima las tres tablas o cópielas en sus notas.
2. Pase *Abrir* y marque cada línea cuando vea la columna de lo correcto, no cuando lo recuerde.
3. Haga lo mismo con *Funcionar* y *Crecer* en el espacio de prueba, con su gestor para las líneas de *Crecer*.
4. Repita las líneas que cambiaron cuando pase al espacio real. Una plantilla o un archivo de ajustes no incluye todas.

**Resultado** Una lista que puede enseñar a alguien y un espacio que ha visto funcionar antes de que nadie dependa de él.

**Véase también:** [De la semana 0 a la semana 4](help:setup.training.overview) · [Un ensayo seguro](help:setup.money.dry-run) · [La secuencia que debe seguir](help:setup.reports.sequence)

<!-- anchor: setup.consistent.monthly -->
### La rutina mensual

**Público:** Propietario · Administrador/a · Administrador/a de facturación

Quiere un hábito breve que mantenga el espacio coherente, en diez minutos a final de mes.

**Pasos**

1. Abra **Configuración de este espacio**. Cada ámbito sigue indicando **Listo**, o **No es necesario aquí**, o está dejado a un lado a propósito.
2. Abra [Eventos](app:/events). **Esperando su confirmación** está vacío o es pequeño, y ningún miembro lleva **Pendiente** más de uno o dos días.
3. Vuelva a contar el equipo. Quien se haya marchado o esté en pausa puede dejar una regla corta. Véase [Evite solicitudes que esperan para siempre](help:setup.people.stuck).
4. Cierre el mes: los días de cierre están introducidos, se ha ejecutado el asistente de cierre mensual y los recordatorios de pago han salido (automáticamente cada mañana, o al abrir Finanzas cuando la base de datos no tiene programador). Véase [El asistente de cierre mensual](help:user.invoicing.wizard).
5. Haga la exportación de datos y abra **Funciones** para comprobar que ningún proceso requiere atención tras los cambios del mes.

**Conviene saber**

- Escribir la fecha de la última pasada en la primera línea de sus notas indica a la persona siguiente cuándo fue cierto por última vez.
- Todo lo que haya cambiado durante el mes en la matriz de roles o en una regla de validación merece una comprobación más de las líneas 9, 11 y 12 de la auditoría.

**Resultado** Un espacio que sigue siendo lo que usted configuró.

**Véase también:** [La auditoría previa al lanzamiento](help:setup.consistent.audit)

<!-- anchor: setup.consistent.wrong -->
### Cuando algo parece ir mal

**Público:** Propietario · Copropietario · Administrador/a

Quiere saber qué probar, en qué orden y a quién preguntar.

<p><img src="images/setup-consistent-recovery-export.es.jpg" width="280"></p>

**Pasos**

1. Lea el mensaje de la pantalla. La mayoría dicen qué hacer.
2. Compruebe el lado. Mire el banner del espacio de prueba y el lado que se muestra en [Yo](app:/me). Los documentos impresos en el lado de prueba llevan una marca de agua y no se debe nada; el lado real emite facturas que sí se deben.
3. Revise [Funciones](app:/features) y [Roles](app:/roles): una función que falta es una función desactivada o un permiso que nadie marcó.
4. Abra **Configuración de este espacio** y lea el ámbito que corresponde al síntoma.
5. Prepare **Detalles de soporte** en [Ayuda](app:/help): elija **Última hora** o **Últimas 24 horas**, **Preparar vista previa**, léala, pulse **Guardar** y envíe el archivo. Contiene solo recuentos y comprobaciones, no identidades, credenciales ni registros del negocio.
6. Antes de cambiar algo importante, haga la exportación de datos (más abajo).

*A quién preguntar*

| Sobre | Pregunte a |
|---|---|
| Un ajuste de su espacio, una regla, un rol | A usted y después a su copropietario |
| Una factura, el IVA, un número | A su gestor, con la factura de prueba |
| Un ámbito que indica **A la espera de otra persona** o **El operador del servidor** | Al operador de su instalación |
| Un asistente que no está aprobado | A un administrador de la base de datos |
| Un error que no sabe explicar | Al soporte, con el archivo de soporte |

*La exportación de recuperación*

1. Abra [Informes](app:/reports?section=documents) y elija **Documentos del espacio**.
2. Pulse **Exportar datos (Excel)**. Necesita la función **Exportación de datos (Excel)** y el permiso **Exportar contabilidad y datos**. Obtiene un único ZIP: un libro con una pestaña por conjunto de datos, un manifiesto que cuenta las filas y los archivos guardados.
3. Pulse **Exportar configuración (PDF)** para tener un registro de los parámetros y, en **Espacio**, **Exportar el espacio (XML)** para el plano y los ajustes.

**Conviene saber**

- Una exportación de datos completada queda registrada; el ámbito de preparación **Exportación y recuperación** lo indica durante 90 días y después señala que la exportación es más antigua.
- El PDF es un registro, no una copia de seguridad. Solo el XML puede importarse de nuevo, y nunca contiene miembros ni dinero.
- Guarde el archivo en un sitio que solo usted pueda abrir: contiene a sus miembros.

**Véase también:** [Detalles de soporte](help:user.advanced.support) · [Cuando algo no funciona](help:user.advanced.troubleshooting) · [Exportar los datos (Excel)](help:user.workspace.export.excel)

<!-- anchor: setup.consistent.irreversible -->
### Lo que no tiene vuelta atrás

**Público:** Propietario · Copropietario · Administrador/a de facturación

Quiere una página que diga en qué hay que ir despacio. La lista completa, con lo que hacer en su lugar, está en [Decisiones difíciles de deshacer](help:setup.before.permanent). Esto es el resumen.

> **Atención** Una factura emitida no cambia nunca y su número no se reutiliza. Un error se corrige con una anulación, una factura rectificativa o una solicitud de reembolso, no con una edición.

| Decisión | Permanente desde | Se trata en |
|---|---|---|
| Formato y secuencia del número de factura | La primera factura emitida | [Decisiones difíciles de deshacer](help:setup.before.permanent) |
| El mes facturado de un miembro | El momento en que se emite la factura | [Dinero](help:setup.money.permanent) |
| Menciones legales de la factura | La primera factura emitida | [La secuencia que debe seguir](help:setup.reports.sequence) |
| Régimen de IVA y tipos | Los tipos se versionan por fecha y nunca se editan; una declaración presentada no se recalcula nunca | [Dinero](help:setup.money.permanent) |
| País y moneda | Bloqueados por el servidor en cuanto el espacio ha emitido un documento o registrado dinero: los importes no se convierten | [Decisiones difíciles de deshacer](help:setup.before.permanent) |
| Zona horaria | Nunca se bloquea, pero los días se cuentan en ella: elíjala el primer día | [Decisiones difíciles de deshacer](help:setup.before.permanent) |
| Sustitución del plano | Se rechaza cuando existe una reserva; borrar una planta elimina lo que contiene | [Decisiones difíciles de deshacer](help:setup.before.permanent) |
| El ID del espacio | Cuando lo cambia, el anterior deja de funcionar al instante; reimprima el QR | [Cómo se une la gente](help:setup.people.join) |
| La propiedad | Un propietario puede cederla; no existe invitación de propietario | [Copropietarios](help:setup.people.coowner) |
| Un cambio de matriz o de validación | Queda registrado como evento y se aplica a todos a la vez | [La matriz de roles](help:setup.people.matrix) |
| Prueba o real | Un espacio real emite facturas que se deben | [Antes de empezar](help:setup.before.overview) |
| Una exportación compartida | Un archivo compartido no se puede revocar | [Cuando algo parece ir mal](help:setup.consistent.wrong) |

**Conviene saber**

- Desactivar una función nunca borra datos.
- Un archivo con credenciales no es una copia de seguridad. Mantenga los tokens fuera de cualquier archivo que envíe.

**Resultado** Sabe qué líneas debe leer dos veces.

**Véase también:** [Antes de empezar](help:setup.before.overview)
