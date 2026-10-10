<!-- anchor: setup.before.overview -->
## Antes de empezar

Un poco de preparación le ahorra lo que más cuesta después: volver a escribirlo todo y las decisiones que ya no se pueden deshacer. Este capítulo muestra qué hace DesKilo, qué necesita realmente para abrir y qué conviene tener a mano.

En este capítulo:
- [Qué puede hacer DesKilo](help:setup.before.what)
- [Qué es necesario y qué es opcional](help:setup.before.necessary)
- [Un espacio de prueba o uno real](help:setup.before.environment)
- [Partir de una plantilla o de cero](help:setup.before.template)
- [Qué preparar](help:setup.before.prepare)
- [Decisiones difíciles de deshacer](help:setup.before.permanent)
- [Quién hace qué](help:setup.before.who)

<!-- anchor: setup.before.what -->
### Qué puede hacer DesKilo

**Público:** Propietario · Copropietario

Usted quiere ver el conjunto antes de elegir nada. DesKilo agrupa sus funciones en nueve procesos; la pantalla **Funciones** muestra una tarjeta por proceso con su estado.

<p><img src="images/setup-before-processes.es.jpg" width="280"></p>

*Los nueve procesos, en palabras sencillas*

| Proceso | Qué ofrece a un miembro |
|---|---|
| **Espacio y acceso** | Una puerta de entrada: unirse con el ID del espacio, un rol, una credencial. |
| **Gestión de espacios** | Un lugar que se parece al real: plantas, salas, mesas, horarios de apertura. |
| **Reservas y uso** | Reservar una mesa o una sala, entrar y salir, ver qué está libre. |
| **Calendario y coordinación** | Un calendario, mensajes y solicitudes que alguien confirma. |
| **Ofertas para miembros** | Un plan, precios de servicios y acuerdos. |
| **Facturación y pagos** | Un estado de cuenta, facturas, pago, recordatorios, IVA. |
| **Documentos e información** | Documentos para leer, informes para imprimir, sus propios datos para exportar. |
| **Operaciones y administración** | Un espacio con sus propios colores y sus propias palabras. |
| **Integraciones y automatización** | Notificaciones y documentos entregados a través de servicios externos. |

**Conviene saber**

- Un espacio nuevo arranca con un conjunto sensato de funciones activadas; no tiene que decidir una por una. Desactivar una función solo detiene lo nuevo y no borra nada.
- Una función que depende de otra la activa consigo, y la pantalla indica qué se ha activado. Véase [Un interruptor de función](help:user.features.switch).
- Las funciones marcadas como alfa o beta piden su consentimiento al activarlas.

**Véase también:** [Activar y desactivar funciones](help:user.features.processes)

<!-- anchor: setup.before.necessary -->
### Qué es necesario y qué es opcional

**Público:** Propietario · Copropietario · Administrador/a

Usted quiere conocer el camino más corto hacia un espacio que se pueda reservar. La aplicación mantiene una lista de preparación llamada **Configuración de este espacio** y, en la pantalla Reservar, dice a los propietarios **Antes de que alguien pueda reservar aquí** qué falta.

*Lo que debe existir antes de la primera reserva*

1. **Días de apertura, zona horaria y moneda**: una zona horaria, una moneda y al menos un día de apertura.
2. **Puestos reservables en el plano**: al menos un asiento.
3. **Roles y quién valida las solicitudes**: solo cuenta cuando una regla sobre reservas exige más validadores de los que tiene el espacio. Una regla que pida dos aprobaciones cuando usted está solo en el espacio dejaría las solicitudes esperando para siempre.

Una cuarta fila, **Servidor y versión de la base de datos**, solo bloquea cuando el servidor va por detrás de esta aplicación; entonces espera al operador del servidor.

*Lo que es opcional y puede dejarse para más tarde*

- **Planes de membresía y tarifas**
- **Invitar a los primeros miembros**
- **Cómo pagan los miembros**
- **Exportación y recuperación**
- **Datos que necesitan sus funciones (identidad, banco, plataformas)**
- **Una primera reserva**

Cada uno de estos pasos puede aplazarse con **Más adelante** y recuperarse después; la lista indica si un paso está **Por configurar**, **Listo**, **No es necesario aquí** o **A la espera de otra persona**. Existen otros dos estados: **Aún no verificado** (**Exportación y recuperación** pasa a Listo solo tras una exportación real en los últimos 90 días) y una fila que no se pudo leer.

**Conviene saber**

- La lista nombra quién actúa: **Usted**, **El operador del servidor** o **Un administrador de la base de datos**.
- Opcional no significa poco importante: en cuanto factura, su identidad legal es obligatoria para esa función. La lista la llama un dato que necesitan sus funciones.
- Si activa la facturación sin identidad legal, la aplicación se lo permite; se niega en el momento de emitir una factura y dice qué falta.

**Véase también:** [Revisar su espacio](help:setup.place.check) · [La tarjeta Primeros pasos y los consejos](help:user.start.get-started)

<!-- anchor: setup.before.environment -->
### Un espacio de prueba o uno real

**Público:** Propietario · Copropietario · Operador/a

Usted quiere probar sin consecuencias y después llevar el espacio real. Un espacio puede ser de prueba, real, o un par vinculado con el mismo nombre.

<p><img src="images/setup-before-environment.es.jpg" width="280"></p>

| Opción | Elíjala cuando | Qué ocurre |
|---|---|---|
| **Un espacio de prueba** | Está aprendiendo. | Cada pantalla y cada documento indica que es una prueba: los documentos llevan una marca de agua. Sin facturación real. |
| **Un espacio real** | Ya conoce sus ajustes. | Las facturas que emite son exigibles. |
| **Un par vinculado de prueba y real** | Quiere ensayar los cambios antes de que los vean los miembros reales. | Dos espacios, ambos suyos. Solo un despliegue traslada la configuración de uno a otro; los miembros, las reservas, las facturas y los pagos nunca viajan. |

**Conviene saber**

- El selector empieza en la opción de prueba.
- El entorno es una declaración del propietario; quien tenga el permiso de configuración (el propietario siempre) puede cambiarlo más tarde, y las facturas ya emitidas conservan la marca de agua que llevaban, así que empiece con un espacio de prueba si tiene dudas.
- Para practicar sin un espacio propio, utilice el espacio de demostración.

**Véase también:** [Un espacio tiene dos caras](help:user.advanced.environments) · [Crear un espacio](help:user.start.create) · [Un espacio de prueba](help:user.advanced.test-space)

<!-- anchor: setup.before.template -->
### Partir de una plantilla o de cero

**Público:** Propietario

Usted quiere una ventaja inicial sin quedar atado a las decisiones de otros. Al crear un espacio, **Partir de** ofrece **Espacio vacío** o una plantilla lista para usar, y viene preseleccionada *A tiny space*; elija *Espacio vacío* si prefiere un lienzo en blanco.

<p><img src="images/setup-before-template.es.jpg" width="280"></p>

*Las dos plantillas incluidas*

| Plantilla | Qué configura |
|---|---|
| A tiny space | Dos plantas, cuatro mesas, ocho asientos y nada más: lo justo para reservar, escanear y explorar desde el primer minuto. |
| Association de coworking (France) | Medias jornadas de 7:00 a 13:00 y de 13:00 a 19:00, de lunes a viernes, días festivos, membresías al 50 % y al 100 %, dos bonos prepago de medias jornadas (10 y 20), roles de junta (tesorero, secretario, responsable de sala), un calendario para las validaciones y dos plantas listas para reservar. También fija el idioma del espacio en francés y el régimen de IVA en *no sujeto al IVA*; solo se renombran tres palabras (Place, Étage, Réservations). El nombre de la plantilla es francés en todos los idiomas de la aplicación. |

**Conviene saber**

- Una plantilla nunca incluye su identidad legal, sus datos bancarios, sus sedes, sus invitaciones ni los enlaces a documentos: eso es cosa suya, y la lista de preparación lo nombra como datos que necesitan sus funciones.
- Un espacio creado con una plantilla puede tener la facturación activada y nada con lo que emitir hasta que añada la identidad.
- Aplicar una plantilla a un espacio que ya tiene tarifas sustituye sus tramos de cuota: úsela en un espacio nuevo.

**Véase también:** [Crear un espacio](help:user.start.create)

<!-- anchor: setup.before.prepare -->
### Qué preparar

**Público:** Propietario

Usted quiere tener los datos a mano para que configurar lleve minutos y no días. Reúna primero lo siguiente.

**Antes de empezar**

- [ ] La **identidad legal**: asociación o empresa, razón social, dirección, números de registro y de IVA si los tiene.
- [ ] Un contable (o alguien que confirme las decisiones fiscales): las facturas y el IVA son lo que conviene revisar con un profesional.
- [ ] Una idea de tarifa: gratuita, una membresía fija, o un porcentaje de días con una cuota mensual.
- [ ] Los **datos bancarios** a los que pagarán los miembros (IBAN y BIC, o el método habitual en su país).
- [ ] Una lista de las primeras personas: nombres y direcciones de correo, y quién aprobará las solicitudes.
- [ ] Un croquis del plano: plantas, salas, cuántas mesas y asientos, y si se puede reservar una sala entera.
- [ ] Sus días y horas de apertura, y los días en que cierra.

**Conviene saber**

- Puede abrir sin la identidad legal ni los datos bancarios; los necesitará antes de la primera factura.
- Haga primero el croquis en papel. La aplicación dibuja plantas, salas, mesas y asientos; es más rápido introducir un plano que ya ha pensado.

**Véase también:** [Preparar un espacio con el cuestionario de configuración](help:user.start.questionnaire)

<!-- anchor: setup.before.permanent -->
### Decisiones difíciles de deshacer

**Público:** Propietario · Copropietario

Usted quiere saber en qué decisiones conviene ir despacio. La mayoría de los ajustes se pueden cambiar cualquier día. Estos no, o no limpiamente.

> **Atención** Una factura emitida no cambia nunca, y su número no se reutiliza. Si se equivoca, corrige con una anulación, una nota de crédito o una solicitud de reembolso, no con una edición.

| Decisión | Cuándo pasa a ser definitiva | Qué hacer en su lugar |
|---|---|---|
| Formato y secuencia del número de factura | El siguiente número puede subirse, nunca bajarse. Tras la primera factura ya no se puede imprimir menos de la fecha que muestra la serie. | Previsualice el formato, consulte a su contable y después emita. |
| El mes de una factura emitida | Una vez facturado el mes de un miembro queda bloqueado; los días de cierre y las importaciones de días festivos lo omiten. | Fije los días de cierre antes de fin de mes. |
| Régimen de IVA y tipos | Los tipos se versionan por fecha y nunca se editan; una declaración de IVA presentada no se vuelve a calcular. | Añada un tipo nuevo desde una fecha; decida el régimen con su contable. |
| País, moneda, zona horaria | Los importes se guardan como números, sin conversión, así que cambiar la moneda cuando ya hay dinero es arriesgado. | Elíjalos bien desde el primer día; véase [Construir el lugar](help:setup.place.overview). |
| Sustitución del plano | Se rechaza importar un plano cuando ya hay reservas. | Edite las plantas y las salas una por una en el editor. |
| ID del espacio | Es lo que escriben los miembros y lo que señalan los códigos QR impresos. Puede cambiarlo (de 4 a 20 letras o cifras) con **Cambiar el ID del espacio**, pero el ID antiguo deja de funcionar de inmediato. | Elija un ID corto y fácil de recordar antes de imprimir nada; cámbielo pronto si debe hacerlo. |
| Prueba o real | Un espacio real emite facturas exigibles; los documentos de desarrollo llevan marca de agua. | Empiece en un espacio de prueba y despliegue cuando esté listo. |
| Una regla que exige más validadores de los que tiene | Las solicitudes esperan para siempre. | Cuente sus validadores antes de exigir dos. |

**Conviene saber**

- Desactivar una función nunca borra datos.
- Eliminar una planta elimina todas las oficinas, mesas y asientos que contiene.

**Véase también:** [Dinero](help:setup.money.permanent)

<!-- anchor: setup.before.who -->
### Quién hace qué

**Público:** Propietario · Copropietario · Administrador/a · Operador/a

Usted quiere saber a quién acudir para cada cosa. Pueden intervenir tres personas, y la lista de preparación las nombra.

| Quién | Qué hace |
|---|---|
| **Propietario** (y *Copropietario*) | Todo lo del espacio: plantas, horarios, funciones, roles, tarifas, identidad legal, invitaciones, despliegues. Los copropietarios tienen todos los permisos por defecto; el propietario decide lo que pueden hacer los administradores. |
| *Operador/a* | Gestiona la instalación: el servidor y sus secretos, y las actualizaciones de la base de datos. Es necesario para que funcionen las notificaciones push y para todo lo que la lista de preparación llama **A la espera de otra persona**. |
| *Administrador/a de la base de datos* | Aprueba el acceso de un miembro para los asistentes. |

**Conviene saber**

- En una instalación compartida, el operador suele ser el de la plataforma, no usted.
- Los administradores actúan dentro de los permisos que les dio el propietario en la [matriz de roles](help:user.roles.matrix).
- Si una sección dice **El operador del servidor**, la aplicación no puede hacerlo desde su pantalla.

**Véase también:** [Decida quién puede hacer qué](help:user.roles.matrix) · [Permisos de despliegue](help:user.advanced.deploy-permissions)
