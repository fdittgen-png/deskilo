<!-- anchor: user.space.overview -->
## Su espacio, configurado por usted (Ajustes del espacio)

Este capítulo está dirigido a quienes dirigen un espacio: propietarios, copropietarios y los administradores en quienes confían para los ajustes. Aquí usted dibuja las plantas, decide quién puede entrar y cuándo, elige qué funciones existen, da al espacio su aspecto y sus palabras, y hace una copia de todo.

En este capítulo:
- [Dibuje sus plantas, salas y mesas](help:user.space.editor.levels)
- [Invite a personas con el ID del espacio](help:user.workspace.code)
- [Indique cuándo está abierto el espacio](help:user.workspace.availability.open-weekdays)
- [Active y desactive funciones](help:user.features.processes)
- [Rellene los ajustes del espacio](help:user.workspace.settings.country)
- [Dé al espacio sus colores y sus palabras](help:user.workspace.settings.wording)
- [Decida quién puede hacer qué](help:user.roles.matrix)
- [Ponga en marcha una tableta de pared y credenciales](help:user.kiosk.mode)
- [Mantenga una biblioteca de documentos](help:user.documents.add)
- [Exporte e importe el espacio](help:user.workspace.export.space-xml)

> **Consejo** La mayoría de las pantallas de este capítulo están en el menú, bajo **Espacio**, **Disponibilidad**, **Funciones** y **Roles**. Cada entrada solo aparece a quien tiene el permiso necesario, y algunas solo mientras su función está activada. Un administrador solo ve estas pantallas si el propietario le ha dado el permiso en la matriz de roles.

<!-- anchor: user.space.editor.levels -->
### Editor del espacio: añadir, renombrar y eliminar plantas

**Público:** Propietario · Administrador/a

Usted quiere dar al edificio sus plantas, en el orden que la gente espera. El **Editor del espacio** enumera todas las plantas del espacio.

<p><img src="images/user-space-editor-levels.es.jpg" width="280"></p>

**Pasos**

1. Abra [Editor del espacio](app:/editor), o toque **Editar espacio** en la pantalla Reservar.
2. Toque **Añadir planta**, escriba el nombre y toque **Guardar**.
3. Arrastre el tirador a la izquierda de una planta para cambiar el orden.
4. Toque los tres puntos (**Acciones de la planta**) para **Cambiar nombre…** o **Eliminar** una planta.
5. Toque una planta para dibujar en ella.

**Conviene saber**

- Eliminar una planta borra todas las oficinas, mesas y asientos que contiene. La confirmación indica qué ocurre con las reservas que apuntan a ellos.
- La línea bajo cada planta le dice si es **Reservable por completo** o **No reservable por completo**.
- Sin ninguna planta, el editor dice **Aún no hay plantas. Añada la primera planta de su espacio.**

**Véase también:** [Reservar una planta entera](help:user.space.editor.level-booking) · [Dibujar salas, mesas y asientos](help:user.space.editor.rooms)

<!-- anchor: user.space.editor.level-booking -->
### Permitir reservar una planta entera

**Público:** Propietario · Administrador/a

Usted quiere que un equipo pueda ocupar una planta completa durante un día.

<p><img src="images/user-space-editor-level-booking.es.jpg" width="280"></p>

**Pasos**

1. En el [Editor del espacio](app:/editor), toque el botón de capas en la fila de la planta.
2. Active **Reservable por completo**.
3. Escriba el **Precio por media jornada**.
4. Toque **Guardar**.

**Conviene saber**

- El botón de capas aparece relleno cuando la planta es reservable por completo.
- Reservar una planta, oficina o mesa entera exige además la función **Reservas de mesa, oficina y planta**. Cada miembro necesita el derecho de reservar plantas; los administradores lo tienen automáticamente. Véase [Un interruptor de función](help:user.features.switch).

**Véase también:** [Propiedades de oficinas y mesas](help:user.space.editor.office)

<!-- anchor: user.space.editor.rooms -->
### Dibujar salas, mesas y asientos

**Público:** Propietario · Administrador/a

Usted quiere que el plano en pantalla se parezca a la planta real. Todo está dentro de una sala: dibuja una sala, coloca mesas en ella y después asientos en las mesas.

<p><img src="images/user-space-editor-rooms.es.jpg" width="280"></p>

**Pasos**

1. Abra una planta desde el [Editor del espacio](app:/editor). Una planta vacía ofrece **Dibujar la primera sala**.
2. Toque **Oficina** y arrastre sobre la cuadrícula para dibujar una sala.
3. Toque **Mesa** y arrastre dentro de la sala para dibujar una mesa.
4. Toque **Asiento** y después toque una mesa para añadirle un asiento.
5. Toque **Imagen** y después toque el lugar donde debe ir una ilustración.
6. Toque un elemento para seleccionarlo. La barra inferior ofrece **Duplicar**, **Propiedades** y **Eliminar**.

**Conviene saber**

- Si toca de nuevo la herramienta activada, la suelta, y el lienzo vuelve a seleccionar.
- La app rechaza una forma que **Se superpone con un elemento existente.** o que **Debe estar completamente dentro de una oficina.** Los asientos solo pueden colocarse en una mesa, y una mesa llena dice **No queda sitio en esta mesa.**
- El botón de imagen, arriba a la derecha, define, sustituye o quita la **Imagen de fondo** de la planta, por ejemplo un escaneo del plano real.
- Eliminar una sala se lleva consigo sus mesas y asientos.

**Véase también:** [Propiedades del asiento](help:user.space.editor.seat) · [Transparencia de mesas](help:user.workspace.settings.desk-transparency)

<!-- anchor: user.space.editor.office -->
### Dar nombre y precio a una oficina o una mesa

**Público:** Propietario · Administrador/a

Usted quiere que una sala o una mesa tenga su propio nombre y que se pueda reservar de una sola vez.

<p><img src="images/user-space-editor-office.es.jpg" width="280"></p>

**Pasos**

1. Seleccione la oficina o la mesa en la planta y toque **Propiedades**.
2. Cambie **Nombre de la oficina** (o **Nombre de la mesa**).
3. Active **Reservable en su totalidad** si alguien puede reservarla entera, con todo lo que contiene.
4. Escriba el **Precio por media jornada** que aparece.
5. Toque **Guardar**.

**Conviene saber**

- El campo del precio solo aparece mientras el interruptor está activado.
- Una sala reservable en su totalidad solo puede reservarse mientras no haya nada reservado dentro de ella.

**Véase también:** [Reservar una planta entera](help:user.space.editor.level-booking) · [Propiedades del asiento](help:user.space.editor.seat)

<!-- anchor: user.space.editor.seat -->
### Configurar un asiento

**Público:** Propietario · Administrador/a

Usted quiere que un asiento indique hacia dónde mira la silla, qué incluye y cuándo está fuera de servicio.

<p><img src="images/user-space-editor-seat.es.jpg" width="280"></p>

**Pasos**

1. Seleccione el asiento en la planta y toque **Propiedades**.
2. Cambie **Nombre del asiento**.
3. Elija la **Dirección de asiento**: la flecha muestra hacia dónde mira la silla en el plano.
4. Elija un **Tipo de silla**.
5. Toque los **Accesorios** que pertenecen a este asiento. Un precio junto a uno es un suplemento por media jornada.
6. Si el asiento lleva una etiqueta, escriba su número en **Etiqueta NFC/RFID**, o use **Leer una etiqueta ahora**. El campo de la etiqueta aparece cuando la función **Etiquetas NFC/RFID de las sillas** está activada, y la lectura requiere un dispositivo capaz de leer etiquetas.
7. Active **Bloqueado (mantenimiento)** para dejar el asiento fuera de servicio y toque **Guardar**.

**Conviene saber**

- Un número de etiqueta solo puede pertenecer a una silla: **Esta etiqueta ya está vinculada a otra silla.**
- Si aún no hay ningún accesorio, la hoja ofrece **Aún no hay equipamiento — configúrelo**.

**Véase también:** [Registro con credencial NFC](help:user.badges.nfc)

<!-- anchor: user.workspace.code -->
### El ID del espacio

**Público:** Propietario · Administrador/a

Usted quiere que la gente encuentre su espacio y pida unirse. La pantalla **ID del espacio y QR** muestra la invitación de miembro: un código QR y el ID que hay detrás.

<p><img src="images/user-workspace-code.es.jpg" width="280"></p>

**Pasos**

1. Abra [ID del espacio y QR](app:/workspace-code). Se muestra la pestaña **Invitación de miembro**.
2. Toque **Copiar ID** para pegar el ID donde quiera, o **Compartir como PNG** para imprimir o publicar el código QR.
3. Para elegir un ID fácil de recordar, toque **Cambiar el ID del espacio**, escriba de 4 a 20 letras o dígitos y toque **Guardar**.

**Conviene saber**

- El ID es único en todo DesKilo. Si ya está en uso, o no tiene de 4 a 20 letras o dígitos, la app dice **ID rechazado**.
- Quien escanea el código o escribe el ID pide unirse como miembro. Nadie entra sin aprobación.
- Cuando cambia el ID, el anterior deja de funcionar. Vuelva a imprimir el código QR.
- La pestaña **Invitación de administrador/a** es para propietarios y copropietarios.

**Véase también:** [Invitación de administrador/a](help:user.workspace.code.admin) · [Invitar a alguien](help:user.workspace.code.invite)

<!-- anchor: user.workspace.code.admin -->
### Invitar a un administrador

**Público:** Propietario

Usted quiere incorporar a una persona que le ayude a dirigir el espacio. La pestaña **Invitación de administrador/a** le da un código para una sola persona.

<p><img src="images/user-workspace-code-admin.es.jpg" width="280"></p>

**Pasos**

1. Abra [ID del espacio y QR](app:/workspace-code) y toque **Invitación de administrador/a**.
2. Entregue el código, o su QR, a la persona a quien va destinado.
3. Para el siguiente administrador, toque **Nuevo código de administrador/a**.

**Conviene saber**

- El código admite a una persona como administrador y después caduca.
- No existe una invitación de propietario. Solo un propietario puede conceder la propiedad, en **Miembros y planes**.

**Véase también:** [El ID del espacio](help:user.workspace.code) · [La matriz de roles](help:user.roles.matrix)

<!-- anchor: user.workspace.code.invite -->
### Invitar a alguien con un mensaje

**Público:** Propietario · Administrador/a

Usted quiere enviar una invitación amable y ya redactada en lugar de un código a secas.

<p><img src="images/user-workspace-code-invite.es.jpg" width="280"></p>

**Pasos**

1. En [ID del espacio y QR](app:/workspace-code), toque **Invitar a alguien**.
2. Rellene **Nombre (opcional)**, **Apellido (opcional)** y, si quiere, el número de teléfono.
3. En **Roles al llegar**, toque cualquier rol que esta persona deba recibir al unirse.
4. Elija el **Idioma del mensaje**.
5. Envíelo con **WhatsApp**, **SMS** o **Compartir…**.

**Conviene saber**

- El mensaje explica los pasos: descargar, crear una cuenta, unirse. Está escrito en el idioma que elija y parte del definido como [Idioma del espacio](help:user.workspace.settings.language).
- Cada mensaje lleva su propio código personal. Puede escribir su propio texto en [Mensaje de invitación](help:user.workspace.settings.invitation-message).

**Véase también:** [El ID del espacio](help:user.workspace.code)

<!-- anchor: user.workspace.availability.open-weekdays -->
### Días de apertura

**Público:** Propietario · Administrador/a con el permiso

Usted quiere que el espacio esté abierto solo los días en que trabaja. La pantalla **Disponibilidad** empieza con los días de la semana.

<p><img src="images/user-workspace-availability--open-weekdays.es.jpg" width="280"></p>

**Pasos**

1. Abra [Disponibilidad](app:/availability).
2. En **Días de apertura**, toque un día para abrirlo o cerrarlo.

**Conviene saber**

- Al menos un día de la semana debe quedar abierto.
- Se rechaza una reserva que toque un día de la semana cerrado, y el plano dibuja ese día como cerrado.

**Véase también:** [Días de cierre](help:user.workspace.availability.closure-days) · [Granularidad](help:user.workspace.availability.granularity)

<!-- anchor: user.workspace.availability.granularity -->
### Granularidad

**Público:** Propietario · Administrador/a con el permiso

Usted quiere que las reservas sigan un ritmo adecuado a su espacio: medios días, días completos o la hora que se quiera.

<p><img src="images/user-workspace-availability--granularity.es.jpg" width="280"></p>

**Pasos**

1. Abra [Disponibilidad](app:/availability).
2. En **Granularidad de las reservas**, elija la forma de una reserva.

**Conviene saber**

- Las opciones son **Franja horaria libre**, **Franjas de 5 minutos**, **Franjas de 15 minutos**, **Franjas de 30 minutos**, **Franjas de 1 hora**, **Medios días (mañana y tarde)**, **Solo días completos** y **Horas reales (de–a exacto, medias/jornadas como atajos)**. **Horas reales** aparece cuando la función **Horario laboral** está activada.
- El plano, la hoja de reserva, un código escaneado y el quiosco ofrecen solo lo que permite la granularidad.

**Véase también:** [Horario de trabajo](help:user.workspace.availability.working-hours)

<!-- anchor: user.workspace.availability.working-hours -->
### Horario de trabajo

**Público:** Propietario · Administrador/a con el permiso

Usted quiere que una mañana, una tarde y un día signifiquen lo mismo en todas partes.

<p><img src="images/user-workspace-availability--working-hours.es.jpg" width="280"></p>

**Pasos**

1. Abra [Disponibilidad](app:/availability).
2. En **Horario de trabajo**, toque **Inicio de la jornada**, **Límite de media jornada** y **Fin de la jornada** y fije cada hora.
3. Con la granularidad de horas reales, fije también **Horas facturadas como media jornada** y **Horas facturadas como jornada completa**.

**Conviene saber**

- Las ventanas de media jornada y de jornada completa en las reservas, el registro de llegada y la facturación siguen este horario.
- La pequeña etiqueta bajo el título dice si el horario es el predeterminado del producto, viene de una plantilla o es suyo. **Volver a la plantilla** y **Volver al valor predeterminado** lo recuperan.
- La jornada debe seguir un orden: inicio, después el límite de media jornada y después el fin.
- Esta sección forma parte de la función **Horario de trabajo**.

**Véase también:** [Fuera del horario de apertura](help:user.workspace.availability.outside-hours)

<!-- anchor: user.workspace.availability.closure-days -->
### Días de cierre

**Público:** Propietario · Administrador/a con el permiso

Usted quiere cerrar el espacio por una fiesta, una semana de agosto o un día para el fontanero, sin que nadie pueda reservar.

<p><img src="images/user-workspace-availability--closure-days.es.jpg" width="280"></p>

**Pasos**

1. Abra [Disponibilidad](app:/availability) y vaya a **Días de cierre**.
2. Toque **Añadir día de cierre**, elija la fecha y, si quiere, un **Motivo (opcional)**.
3. Para quitar uno, toque la papelera que hay a su lado.

**Conviene saber**

- Se rechaza una reserva en un día de cierre y se muestra el motivo.
- Los días que ya están facturados no pueden convertirse en días de cierre con el generador de días festivos.

**Véase también:** [Días festivos](help:user.workspace.availability.public-holidays)

<!-- anchor: user.workspace.availability.public-holidays -->
### Días festivos

**Público:** Propietario · Administrador/a con el permiso

Usted quiere todos los días festivos de un año como días de cierre de una sola vez.

**Pasos**

1. En [Disponibilidad](app:/availability), bajo **Días de cierre**, toque **Añadir días festivos**.
2. Use las flechas para elegir el año. La hoja enumera las fechas que se convertirían en días de cierre.
3. Toque el botón de abajo para crearlos.
4. ¿Prefiere una lista de datos abiertos? Toque **Importar días festivos (datos abiertos)**, elija la región y confirme.

**Conviene saber**

- No se crea nada antes de que confirme, y los días que ya existen aparecen marcados.
- Los meses que ya están facturados se omiten.
- Estas entradas aparecen cuando la función **Días festivos** está activada. **Importar días festivos (datos abiertos)** requiere además la función **Importar días festivos**.

**Véase también:** [Días de cierre](help:user.workspace.availability.closure-days)

<!-- anchor: user.workspace.availability.policies -->
### Políticas de reserva

**Público:** Propietario · Administrador/a con el permiso

Usted quiere flexibilizar o endurecer las reglas de reserva. Lo que fije aquí vale para todas las formas de reservar: la app, un código escaneado y el quiosco.

<p><img src="images/user-workspace-availability--policies.es.jpg" width="280"></p>

**Pasos**

1. Abra [Disponibilidad](app:/availability) y vaya a **Políticas de reserva**.
2. Active o desactive las políticas que quiera.
3. En **Fuera del horario de apertura** y **Límites de reserva**, fije el resto.

**Conviene saber**

- Los dos interruptores están desactivados por defecto.
- Esta sección forma parte de la función **Políticas de reserva**.
- La línea **Lo que el plano distingue**, debajo, explica los estados que los miembros ven en el plano.

**Véase también:** [Permitir reservas pasadas](help:user.workspace.availability.allow-past) · [Los administradores pueden hacer el check-out de los miembros](help:user.workspace.availability.admin-checkout) · [Límites de reserva](help:user.workspace.availability.limits)

<!-- anchor: user.workspace.availability.allow-past -->
### Permitir reservas pasadas

**Público:** Propietario · Administrador/a con el permiso

Usted quiere que los miembros puedan registrar una reserva a posteriori, en un espacio que anota la asistencia más tarde.

**Pasos**

1. En [Disponibilidad](app:/availability), bajo **Políticas de reserva**, active **Permitir reservas pasadas**.

**Conviene saber**

- Desactivada, se rechaza una reserva que ya terminó en un día anterior.
- Reservar una franja anterior el mismo día siempre está permitido.

**Véase también:** [Políticas de reserva](help:user.workspace.availability.policies)

<!-- anchor: user.workspace.availability.admin-checkout -->
### Los administradores pueden hacer el check-out

**Público:** Propietario · Administrador/a con el permiso

Usted quiere que el personal cierre la sala por la tarde y ponga fin a los registros de llegada que la gente olvidó.

**Pasos**

1. En [Disponibilidad](app:/availability), bajo **Políticas de reserva**, active **Los administradores pueden hacer el check-out de los miembros**.

**Conviene saber**

- Desactivada, el check-out es estrictamente personal.
- Activada, un administrador puede poner fin al registro de llegada en curso de un miembro.

**Véase también:** [Políticas de reserva](help:user.workspace.availability.policies)

<!-- anchor: user.workspace.availability.outside-hours -->
### Fuera del horario de apertura

**Público:** Propietario · Administrador/a con el permiso

Usted quiere decir qué ocurre cuando alguien llega temprano o se queda hasta tarde. Una sola respuesta vale para todas las granularidades.

<p><img src="images/user-workspace-availability--outside-hours.es.jpg" width="280"></p>

**Pasos**

1. En [Disponibilidad](app:/availability), busque **Fuera del horario de apertura**.
2. Elija **Desactivado**, **Solo espontáneo**, **Libre** o **De pago**.

**Conviene saber**

- **Desactivado**: nada fuera del horario, ni reserva anticipada ni llegada sin reserva.
- **Solo espontáneo**: los registros de llegada sin reserva siguen siendo posibles, horas extra de la tarde incluidas, pero se rechaza reservar con antelación fuera del horario.
- **Libre**: permitido, nunca se cuenta ni se cobra.
- **De pago**: permitido y contado como un uso normal, salvo un día en que el miembro ya tenga una reserva ordinaria.
- Una reserva que toque el horario de trabajo es una reserva ordinaria.

**Véase también:** [Horario de trabajo](help:user.workspace.availability.working-hours)

<!-- anchor: user.workspace.availability.limits -->
### Límites de reserva

**Público:** Propietario · Administrador/a con el permiso

Usted quiere decir con cuánta antelación se puede reservar, cuán corta o larga puede ser una reserva y cuántas puede tener cada persona a la vez.

<p><img src="images/user-workspace-availability--limits.es.jpg" width="280"></p>

**Pasos**

1. En [Disponibilidad](app:/availability), busque **Reservas simultáneas por miembro** y use los botones de menos y más.
2. En **Límites de reserva**, fije el **Horizonte de reserva**, la **Duración mínima** y la **Duración máxima**.

**Conviene saber**

- **Reservas simultáneas por miembro** es cuántas reservas superpuestas puede tener un miembro. Con 1 solo tiene un lugar a la vez.
- Una reserva termina el día en que empieza, de modo que un día completo es lo más largo que puede ser.
- El mínimo no puede superar el máximo; de lo contrario no se aceptaría ninguna reserva. La pantalla se lo advierte.
- Cada rechazo nombra el límite y su valor.

**Véase también:** [Políticas de reserva](help:user.workspace.availability.policies)

<!-- anchor: user.features.processes -->
### Activar o desactivar procesos enteros

**Público:** Propietario · Copropietario

Usted quiere una vista de conjunto de lo que puede hacer el espacio y activar un área entera de una vez. La pantalla **Funciones** se abre con una tarjeta por cada proceso de negocio.

<p><img src="images/user-features-processes.es.jpg" width="280"></p>

**Pasos**

1. Abra [Funciones](app:/features). Se muestra la vista **Procesos**.
2. Lea cada tarjeta: su estado, cuántos subprocesos están activos y cuántas funciones están activadas.
3. Abra una tarjeta y toque **Activar** o **Desactivar** para el proceso entero o un subproceso.
4. Lea la vista previa y confirme.

**Conviene saber**

- Una tarjeta está **Activa** cuando todas sus funciones funcionan, **Parcial** cuando algunas lo hacen, **Disponible** cuando aún no hay ninguna activada y **Requiere atención** cuando una función está activada pero espera un requisito que está desactivado.
- Los filtros **Todos**, **Activo**, **Disponible** y **Requiere atención** acotan las tarjetas, y **Buscar procesos y funciones** llega a todo.
- La vista previa enumera lo que se activa, lo que es **También necesarias** de otro proceso y lo que ya está activado. Desactivar algo que otras funciones necesitan se rechaza hasta que usted elija qué ocurre con ellas.

**Véase también:** [Un interruptor de función](help:user.features.switch)

<!-- anchor: user.features.switch -->
### Un interruptor de función

**Público:** Propietario · Copropietario

Usted quiere activar o desactivar una sola función.

<p><img src="images/user-features-switches.es.jpg" width="280"></p>

**Pasos**

1. Abra [Funciones](app:/features) y toque **Interruptores**.
2. Encuentre la función con **Buscar funciones**, o acote la lista con **Modificadas** o **Madurez**.
3. Accione su interruptor.

**Conviene saber**

- Active una función y aparece cada parte de ella: la pestaña, el botón, el enlace. Desactívela y no queda ninguna, ni siquiera un enlace guardado.
- Una función que necesita otra queda bajo ella con **Requiere** y dice **Esperando a la función de arriba: actívela y esta vuelve a funcionar.** mientras la principal está desactivada. Su propia elección se conserva.
- Activar una función también puede activar lo que necesita. La app se lo indica.
- Una función que aún no se ha revisado como estable le pide confirmar primero: puede cambiar y tiene límites conocidos.
- Lo que ya está hecho se queda hecho. Una factura emitida mientras una función estaba activada conserva lo que dice.

**Véase también:** [Activar o desactivar procesos enteros](help:user.features.processes)

<!-- anchor: user.workspace.settings.country -->
### País

**Público:** Propietario · Administrador/a con el permiso

Usted quiere que el espacio sepa dónde está establecido. **Espacio** se abre en **Datos generales**.

<p><img src="images/user-workspace-settings--country.es.jpg" width="280"></p>

**Pasos**

1. Abra [Espacio](app:/workspace-settings).
2. En **Datos generales**, elija el **País**.
3. Toque **Guardar** al pie.

**Conviene saber**

- El país propone la moneda y la zona horaria, y decide qué tipos de IVA se ofrecen.
- En cuanto el espacio ha emitido un documento o registrado dinero, el país ya no se puede cambiar: al guardar se indica «La moneda y el país quedan fijados en cuanto el espacio ha emitido un documento o registrado dinero. No se ha guardado nada.»
- **Guardar** escribe todo el formulario junto. Si alguien cambió estos ajustes entretanto, no se guarda nada y lo que usted escribió se queda en pantalla.

**Véase también:** [Moneda y zona horaria](help:user.workspace.settings.currency-timezone)

<!-- anchor: user.workspace.settings.currency-timezone -->
### Moneda y zona horaria

**Público:** Propietario · Administrador/a con el permiso

Usted quiere que los precios y los días se cuenten como los cuenta su espacio.

<p><img src="images/user-workspace-settings--currency-timezone.es.jpg" width="280"></p>

**Pasos**

1. En [Espacio](app:/workspace-settings), bajo **Datos generales**, elija la **Moneda**.
2. Busque la **Zona horaria** y elíjala.
3. Toque **Guardar**.

**Conviene saber**

- La moneda se propone a partir del país. Puede cambiarla hasta que el espacio haya emitido un documento o registrado dinero; después queda fijada.
- La zona horaria no es cosmética: una jornada, un límite de media jornada y un día de cierre se cuentan en ella, así que un miembro en el extranjero ve el día del espacio y no el suyo.

**Véase también:** [País](help:user.workspace.settings.country)

<!-- anchor: user.workspace.settings.language -->
### Idioma del espacio

**Público:** Propietario · Administrador/a con el permiso

Usted quiere que las invitaciones y los documentos hablen el idioma de su comunidad.

<p><img src="images/user-workspace-settings--language.es.jpg" width="280"></p>

**Pasos**

1. En [Espacio](app:/workspace-settings), bajo **Datos generales**, abra **Idioma del espacio**.
2. Elija un idioma, o **Idioma de la app del remitente**.
3. Toque **Guardar**.

**Conviene saber**

- Las invitaciones se escriben por defecto en este idioma.
- No es el idioma de su propia app. Ese solo cambia lo que usted ve y está en sus ajustes personales.

**Véase también:** [Mensaje de invitación](help:user.workspace.settings.invitation-message)

<!-- anchor: user.workspace.settings.address -->
### Dirección del membrete

**Público:** Propietario · Administrador/a con el permiso

Usted quiere su dirección postal en el papel que envía el espacio.

<p><img src="images/user-workspace-settings--address.es.jpg" width="280"></p>

**Pasos**

1. En [Espacio](app:/workspace-settings), bajo **Datos generales**, rellene **Dirección del espacio**.
2. Toque **Guardar**.

**Conviene saber**

- Es texto libre, impreso tal cual en cartas y facturas.
- La dirección estructurada que necesita una factura electrónica es una entrada aparte, bajo la identidad legal.

**Véase también:** [País](help:user.workspace.settings.country)

<!-- anchor: user.workspace.settings.whatsapp-group -->
### Grupo de WhatsApp

**Público:** Propietario · Administrador/a con el permiso

Usted quiere que los miembros encuentren el grupo de WhatsApp de su comunidad.

<p><img src="images/user-workspace-settings-community--whatsapp-group.es.jpg" width="280"></p>

**Pasos**

1. En [Espacio](app:/workspace-settings), abra **Comunidad e invitaciones**.
2. Pegue el enlace de invitación del grupo en **Enlace del grupo de WhatsApp**.
3. Toque **Guardar**.

**Conviene saber**

- El enlace debe ser un enlace de invitación de chat.whatsapp.com; de lo contrario, el campo lo indica.
- Déjelo vacío para no mostrar nada.

**Véase también:** [Mensaje de invitación](help:user.workspace.settings.invitation-message)

<!-- anchor: user.workspace.settings.invitation-message -->
### Mensaje de invitación

**Público:** Propietario · Administrador/a con el permiso

Usted quiere que las invitaciones suenen como usted, en cada idioma que use.

<p><img src="images/user-workspace-settings-community--invitation-message.es.jpg" width="280"></p>

**Pasos**

1. En [Espacio](app:/workspace-settings), abra **Comunidad e invitaciones**.
2. En **Idioma del mensaje**, elija el idioma del texto que está editando.
3. Escriba el texto. Toque una etiqueta como {firstName} o {inviteLink} para insertarla donde está el cursor.
4. Toque **Guardar**.

**Conviene saber**

- Deje el cuadro vacío para usar el mensaje integrado en ese idioma.
- La fila **Idioma del mensaje** solo dice qué borrador está en pantalla. No se guarda, y cada vez se abre en el idioma del espacio.
- Las etiquetas se rellenan al enviar una invitación. El código y el enlace los pone la app, así que no los pegue usted.

**Véase también:** [Invitar a alguien con un mensaje](help:user.workspace.code.invite)

<!-- anchor: user.workspace.settings.new-members -->
### Empezar igual a los nuevos miembros

**Público:** Propietario · Administrador/a con el permiso

Usted quiere que todos los que se unan empiecen con la misma suscripción y la misma regla para cuando se agoten sus días.

<p><img src="images/user-workspace-settings-members--defaults.es.jpg" width="280"></p>

**Pasos**

1. En [Espacio](app:/workspace-settings), abra **Nuevos miembros**.
2. Fije el porcentaje de **Suscripción** con los botones de menos y más.
3. Elija **Bloqueado al agotarse**, **Pago por uso** o **Debe comprar un paquete**.
4. Toque **Guardar**.

**Conviene saber**

- Hasta que usted elija, los nuevos miembros empiezan al 100 % con las reservas bloqueadas una vez agotado el derecho.
- La suscripción propia de cada miembro se fija después, en la página del miembro.

**Véase también:** [La suscripción de un miembro](help:user.members.subscription)

<!-- anchor: user.workspace.settings.wording -->
### Vocabulario

**Público:** Propietario · Administrador/a con el permiso

Usted quiere que la app use sus palabras: otro nombre para un asiento, para un estado en el plano, para una pestaña.

<p><img src="images/user-workspace-settings-wording.es.jpg" width="280"></p>

**Pasos**

1. En [Espacio](app:/workspace-settings), abra **Apariencia y textos** y toque **Vocabulario**.
2. Encuentre una palabra con **Buscar una palabra**, o toque **Solo modificados** para ver lo que ha renombrado.
3. Toque el lápiz que hay a su lado y escriba su palabra, para cada idioma.

**Conviene saber**

- La palabra del producto sigue visible debajo de la suya, de modo que ve lo que sustituye.
- **Restablecer** quita su palabra en lugar de copiar la del producto. El término sigue entonces al producto cuando este cambia su redacción.
- Los términos están agrupados según dónde aparecen: **Leyenda**, **El espacio**, **Navegación**, **Reserva**.

**Véase también:** [Colores](help:user.workspace.settings.colours)

<!-- anchor: user.workspace.settings.colours -->
### Colores

**Público:** Propietario · Administrador/a con el permiso

Usted quiere que la app vista su color. Elija uno y la app deriva de él sus temas claro y oscuro.

<p><img src="images/user-workspace-settings-colours--colours.es.jpg" width="280"></p>

**Pasos**

1. En [Espacio](app:/workspace-settings), abra **Apariencia y textos** y toque **Colores**. La fila está ahí mientras **Colores del espacio** esté activada en las funciones.
2. Toque uno de los colores, o escriba un código como #0F766E en **Color**.
3. Compruebe **Cómo se ve**, en **Claro** y **Oscuro**.
4. Toque **Guardar**. **Colores del producto** quita los suyos.

**Conviene saber**

- La app mantiene su propio contraste. Si un color fuera ilegible en algún sitio, se rechaza y la pantalla nombra la pareja de colores.
- En **Colores de las salas** puede añadir hasta ocho colores propios para las salas del plano.
- La marca DesKilo, los colores de los estados de los asientos y el banner de producción nunca se modifican.

**Véase también:** [Motivo](help:user.workspace.settings.pattern) · [Símbolo y emblema](help:user.workspace.settings.branding)

<!-- anchor: user.workspace.settings.pattern -->
### Motivo

**Público:** Propietario · Administrador/a con el permiso

Usted quiere que su espacio se distinga fácilmente de los demás a los que pertenece una persona.

<p><img src="images/user-workspace-settings-colours--pattern.es.jpg" width="280"></p>

**Pasos**

1. Abra [Colores](app:/settings/colours).
2. En **Motivo**, toque **Liso**, **Rayas**, **Lunares**, **Cuadrícula** u **Ondas**.

**Conviene saber**

- El motivo dibuja su color en la tarjeta de este espacio en Yo, en su etiqueta y mientras el espacio se abre.
- Se guarda en cuanto lo toca.

**Véase también:** [Colores](help:user.workspace.settings.colours)

<!-- anchor: user.workspace.settings.branding -->
### Símbolo y emblema

**Público:** Propietario · Administrador/a con el permiso

Usted quiere una pequeña marca que represente al espacio: letras sobre un color, o su propio logotipo.

<p><img src="images/user-workspace-settings-colours--branding.es.jpg" width="280"></p>

**Pasos**

1. Abra [Colores](app:/settings/colours) y vaya a **Símbolo**.
2. Escriba una o dos **Letras**, elija un color y toque **Guardar**.
3. En **Emblema**, toque **Elegir una imagen** para añadir su logotipo. **Quitar** lo retira.

**Conviene saber**

- Las letras sobre un color son únicas en un espacio. Si otro espacio ya tiene las mismas, la app le pide cambiar el color o las letras.
- El emblema se muestra bajo el nombre de la app en el menú y mientras alguien abre este espacio. Se redibuja con un máximo de 512 píxeles de ancho, y los datos propios de la foto, como dónde se tomó, no se conservan.
- El emblema nunca sustituye al logotipo de DesKilo.

**Véase también:** [Colores](help:user.workspace.settings.colours)

<!-- anchor: user.workspace.settings.desk-transparency -->
### Transparencia de mesas

**Público:** Propietario · Administrador/a con el permiso

Usted dibujó el plano sobre una fotografía y quiere que la sala se transparente a través del mobiliario.

<p><img src="images/user-workspace-settings-appearance--desk-transparency.es.jpg" width="280"></p>

**Pasos**

1. En [Espacio](app:/workspace-settings), abra **Apariencia y textos**.
2. Arrastre el control deslizante de **Transparencia de mesas**. El valor se muestra como *Opacidad*.
3. Toque **Guardar**.

**Conviene saber**

- Baje la opacidad para que la foto de fondo de una planta se vea a través de las mesas.
- Súbala al 100 % cuando los puestos importen más que la sala.

**Véase también:** [Dibujar salas, mesas y asientos](help:user.space.editor.rooms)

<!-- anchor: user.workspace.settings.public-page -->
### Página pública del espacio

**Público:** Propietario

Usted quiere que las personas ajenas a su espacio lo encuentren y vean lo que ofrece.

<p><img src="images/user-workspace-settings-public-page.es.jpg" width="280"></p>

**Pasos**

1. Abra [Página pública del espacio](app:/settings/public-page), o tóquela en la parte superior de **Espacio**.
2. Active **Visible en el directorio público**.
3. Elija el tipo de anfitrión y complete **Descripción**, **Dirección pública**, **Correo público**, **Teléfono público** y **Sitio web**.
4. Toque **Guardar y ver la vista externa**.

**Conviene saber**

- Los campos marcados **De la información del espacio** siguen los datos propios del espacio. **Usar la información del espacio** los restablece después de cambiarlos.
- **Restablecer todos los datos públicos con la información del espacio** sustituye cada campo que tiene un equivalente en el espacio.
- Los administradores pueden elegir por sí mismos si se muestran como administradores públicos.

**Véase también:** [Descubrir y la red pública](help:user.collaborate.discover)

<!-- anchor: user.roles.matrix -->
### La matriz de roles

**Público:** Propietario · Copropietario

Usted quiere decidir qué permisos tiene cada rol. **Roles** muestra una tarjeta por rol con una marca por cada permiso que tiene.

<p><img src="images/user-roles-matrix.es.jpg" width="280"></p>

**Pasos**

1. Abra [Roles](app:/roles).
2. En la tarjeta de un rol, marque o desmarque un permiso como **Gestionar roles y permisos**, **Gestionar miembros**, **Editar la configuración del espacio** o **Emitir facturas y conciliar pagos**.

**Conviene saber**

- Cada persona tiene exactamente un rol base: Usuario, Administrador, Copropietario o Propietario. Los demás roles se suman a él y nunca quitan nada.
- El propietario siempre tiene todos los permisos, por eso esa tarjeta está bloqueada. Un copropietario puede tener menos.
- Quien no puede gestionar roles ve la matriz en solo lectura, con **Su rol** resaltado.
- El servidor comprueba un permiso en todos los lugares, de modo que al desmarcarlo se quita en todas partes a la vez.
- La entrada **Roles** aparece cuando la función **Gestión de roles** está activada.

**Véase también:** [Roles que define este espacio](help:user.roles.space) · [Copropietarios](help:user.roles.co-owners)

<!-- anchor: user.roles.space -->
### Roles que define este espacio

**Público:** Propietario · Copropietario

Usted quiere roles adaptados a su espacio, como anfitrión o contable, además de los básicos.

<p><img src="images/user-roles-space.es.jpg" width="280"></p>

**Pasos**

1. En [Roles](app:/roles), toque **Los roles de este espacio**, o abra [Roles que define este espacio](app:/settings/roles-of-this-space). Esta pantalla aparece cuando la función **Roles que define este espacio** está activada.
2. Toque **Añadir un rol**.
3. Dé un nombre al rol y elija **Lo que añade**.
4. Toque **Guardar el rol**.
5. Para dárselo a un miembro, abra la página del miembro, busque **Roles** y toque **Añadir un rol**.

**Conviene saber**

- Cada rol suma permisos a lo que sus titulares ya pueden hacer. Ninguno quita nada, y el propietario conserva siempre todos los permisos.
- Un rol que ya no quiera puede apartarse desactivando **En uso**.
- La clave del rol nunca cambia: las personas que lo tienen apuntan a ella.
- Nadie puede darse un rol a sí mismo. Un rol que gestiona roles solo puede darlo el propietario.

**Véase también:** [La matriz de roles](help:user.roles.matrix)

<!-- anchor: user.roles.co-owners -->
### Copropietarios

**Público:** Propietario

Usted quiere que el espacio sobreviva si algún día se aparta.

**Pasos**

1. Abra [Miembros y planes](app:/members) y elija al miembro.
2. En **Copropiedad**, elija un copropietario activo o un sucesor.
3. Para traspasar ahora, elija **Promover a propietario ahora**.

**Conviene saber**

- Un copropietario activo tiene ya los permisos del propietario. Un sucesor, mostrado como **Sucesor**, espera y pasa a ser propietario cuando se activa o cuando el propietario se va.
- Si se va el último propietario, el mejor copropietario pasa a ser propietario automáticamente, el activo antes que el sucesor.
- Los copropietarios forman parte de la función **Copropietarios**.

**Véase también:** [Copropiedad](help:user.members.co-ownership) · [La matriz de roles](help:user.roles.matrix)

<!-- anchor: user.kiosk.mode -->
### Modo quiosco: una tableta de pared para registrar la llegada

**Público:** Propietario · Administrador/a

Usted quiere una tableta junto a la puerta donde la gente registre su llegada con una credencial.

**Pasos**

1. Cree una cuenta para la tableta, únala al espacio con ella y, en [Miembros y planes](app:/members), use **Convertir en quiosco** en ese miembro.
2. Asegúrese de que **Modo quiosco** está activado en [Funciones](app:/features).
3. En la tableta, abra la app. Pregunta **¿Iniciar el modo quiosco?**. Toque **Iniciar el modo quiosco**.
4. Un miembro toca un asiento, o **Esta planta**, y presenta una credencial: una tarjeta o un código QR impreso.

**Conviene saber**

- El modo quiosco nunca se inicia solo. **Ahora no — abrir la app normalmente** abre la app como de costumbre, lo que resulta práctico para la configuración.
- En modo quiosco la tableta solo muestra el plano. Para salir hay que reiniciar la tableta. Para que la cuenta vuelva a ser un miembro normal, use **Dispositivo quiosco** en **Ajustes** del dispositivo o **Revertir quiosco a miembro** en **Miembros y planes**.
- La hoja que se abre nombra la regla que sigue. En un día de cierre, el quiosco dice de entrada **El espacio está cerrado hoy**.
- La credencial es la confirmación: identifica al miembro, ejecuta la acción y la pantalla se despeja para la siguiente persona. Un asiento ocupado por otra persona muestra quién lo ocupa y le remite a la app.
- Las credenciales tienen sus propias funciones, **Credenciales RFID / NFC** y las credenciales QR, ambas bajo **Modo quiosco**.
- Aquí no se puede mostrar una tableta de pared: el quiosco solo se inicia en un dispositivo marcado como tal.

**Véase también:** [Registro con credencial NFC](help:user.badges.nfc) · [Códigos QR de espacios (PDF)](help:user.workspace.export.space-qr)

<!-- anchor: user.badges.nfc -->
### Registro con credencial NFC

**Público:** Propietario · Administrador/a

Usted quiere que los miembros registren su llegada acercando una tarjeta, sin teléfono.

<p><img src="images/user-badges-nfc.es.jpg" width="280"></p>

**Pasos**

1. Abra [Credenciales RFID / NFC](app:/nfc-config).
2. Active **Activar registro por credencial NFC**.
3. Lea la línea **Este dispositivo**: indica si este dispositivo puede leer tarjetas.
4. Dé una tarjeta a cada miembro en [Miembros y planes](app:/members): abra las credenciales del miembro, toque **Registrar tarjeta** y acerque la tarjeta a la parte trasera del dispositivo.

**Conviene saber**

- Necesita un dispositivo Android con NFC. Los iPad no tienen NFC, y las credenciales QR siguen funcionando allí.
- El gestor de credenciales también permite emitir una **Nueva credencial**, **Revocar** una y **Guardar como PDF** para imprimir. Una credencial revocada puede eliminarse definitivamente.
- **Inicia mi sesión** está desactivado por defecto: una credencial que registra la llegada no inicia la sesión hasta que el miembro lo decida.
- Cada miembro también puede crear su propia credencial en sus ajustes personales.

**Véase también:** [Una tableta de pared para registrar la llegada](help:user.kiosk.mode)

<!-- anchor: user.documents.add -->
### Añadir un documento a la biblioteca

**Público:** Propietario · Administrador/a

Usted quiere reunir en un solo lugar sus estatutos, guías, cuentas y actas para los miembros que los necesitan. La biblioteca contiene enlaces, no archivos.

<p><img src="images/user-documents-add.es.jpg" width="280"></p>

**Pasos**

1. Abra [Documentos](app:/documents) y toque el botón de más.
2. Rellene **Concepto** y **Enlace (https://…)**.
3. Elija **Almacenado en**, **Categoría** y **Visible para**.
4. Toque **Guardar**.

**Conviene saber**

- La biblioteca necesita la función **Biblioteca de documentos** y el permiso para gestionarla.
- Quite un documento con su papelera: antes pregunta **¿Quitar el documento?**
- Los miembros que pueden abrir la biblioteca ven los documentos que les corresponden, agrupados por categoría.

**Véase también:** [Título del documento](help:user.documents.title) · [Enlace](help:user.documents.url) · [Visible para](help:user.documents.role)

<!-- anchor: user.documents.title -->
### Título del documento

**Público:** Propietario · Administrador/a

Usted quiere que los miembros reconozcan un documento de un vistazo.

**Pasos**

1. En el formulario de añadir un documento, escriba el **Título**.

**Conviene saber**

- Un documento necesita un título y un enlace https://, o se rechaza **Guardar**.
- Escríbalo pensando en quien lo lee, pues es la línea que ve en la biblioteca.

**Véase también:** [Añadir un documento a la biblioteca](help:user.documents.add)

<!-- anchor: user.documents.url -->
### Enlace

**Público:** Propietario · Administrador/a

Usted quiere que el documento se abra donde ya está.

**Pasos**

1. Pegue el enlace para compartir de su unidad en **Enlace (https://…)**.

**Conviene saber**

- DesKilo guarda el enlace, no el archivo. Los derechos de acceso se gestionan donde está el documento.
- El enlace debe empezar por https://.

**Véase también:** [Almacenado en](help:user.documents.provider)

<!-- anchor: user.documents.provider -->
### Almacenado en

**Público:** Propietario · Administrador/a

Usted quiere que los miembros vean dónde se guarda el documento.

**Pasos**

1. Elija **Almacenado en**: Google Drive, OneDrive, SharePoint, Dropbox, Nextcloud o un enlace.

**Conviene saber**

- Es una etiqueta con un icono. No se recupera nada por usted.

**Véase también:** [Enlace](help:user.documents.url)

<!-- anchor: user.documents.category -->
### Categoría

**Público:** Propietario · Administrador/a

Usted quiere que la biblioteca se lea como una estantería ordenada.

**Pasos**

1. Elija una **Categoría**: **Estatutos y legal**, **Guías y manuales**, **Estados financieros**, **Actas de reuniones** u **Otros documentos**.

**Conviene saber**

- La biblioteca agrupa los documentos bajo estos encabezados y solo muestra un encabezado que tenga algún documento.

**Véase también:** [Visible para](help:user.documents.role)

<!-- anchor: user.documents.role -->
### Visible para

**Público:** Propietario · Administrador/a

Usted quiere algunos documentos para todos y otros solo para la junta.

**Pasos**

1. Elija **Visible para**: **Todos los miembros**, **Admins y propietarios** o **Solo propietarios**.

**Conviene saber**

- El servidor lo hace cumplir. Un miembro que no puede ver un documento no lo recibe en absoluto.

**Véase también:** [Añadir un documento a la biblioteca](help:user.documents.add)

<!-- anchor: user.workspace.export.space-xml -->
### Exportar el espacio (XML)

**Público:** Propietario · Administrador/a con el permiso

Usted quiere un archivo con el plano y los ajustes, para guardarlo como copia de seguridad, reutilizarlo o llevarlo a otro espacio.

<p><img src="images/user-workspace-settings-tools--tools.es.jpg" width="280"></p>

**Pasos**

1. Abra [Espacio](app:/workspace-settings) y vaya a **Plantillas y datos**.
2. Toque **Exportar el espacio (XML)**.

**Conviene saber**

- Contiene los ajustes y el plano. Nunca incluye miembros, reservas ni datos de dinero, ni el código de invitación ni las credenciales de pago.
- Con **Configuración en el archivo del espacio** activada, el archivo incluye también tarifas, tipos de IVA, reglas, roles y más.
- El archivo se guarda en su dispositivo.

**Véase también:** [Importar el espacio (XML)](help:user.workspace.export.space-import)

<!-- anchor: user.workspace.export.space-import -->
### Importar el espacio (XML)

**Público:** Propietario · Administrador/a con el permiso

Usted quiere aplicar a un espacio un archivo exportado.

**Pasos**

1. En [Espacio](app:/workspace-settings), bajo **Plantillas y datos**, toque **Importar el espacio (XML)**.
2. Elija el archivo y lea la vista previa: plantas, oficinas, mesas, asientos y configuración.
3. Toque **Sustituir e importar**.

**Conviene saber**

- Sustituye el plano actual y sobrescribe los ajustes. No se puede deshacer.
- Cuando un espacio ya tiene reservas, solo se aplica la configuración. El plano se conserva, y la app lo dice.
- Un archivo ilegible, o que no es de DesKilo, se rechaza con un mensaje claro.

**Véase también:** [Exportar el espacio (XML)](help:user.workspace.export.space-xml)

<!-- anchor: user.workspace.export.config-pdf -->
### Exportar la configuración (PDF)

**Público:** Propietario · Administrador/a con el permiso

Usted quiere un documento con todos los parámetros, para leerlo, firmarlo o entregarlo a un contable.

<p><img src="images/user-workspace-export-reports.es.jpg" width="280"></p>

**Pasos**

1. Abra [Informes](app:/reports?section=documents) y elija **Documentos del espacio**.
2. Toque **Exportar configuración (PDF)**.

**Conviene saber**

- Es una instantánea completa de los ajustes, los miembros y el plano. Es un registro, no una copia de seguridad: solo el XML se puede volver a importar.

**Véase también:** [Exportar el espacio (XML)](help:user.workspace.export.space-xml)

<!-- anchor: user.workspace.export.workspace-report -->
### Informe del espacio

**Público:** Propietario · Administrador/a con el permiso

Usted quiere el espacio como documento: sus lugares, precios y reglas.

**Pasos**

1. Abra [Informes](app:/reports?section=documents) y elija **Documentos del espacio**.
2. Toque **Informe del espacio**.

**Conviene saber**

- Lo genera la plantilla de espacio del editor de informes, de modo que su aspecto sigue el diseño que haya elegido.

**Véase también:** [Exportar la configuración (PDF)](help:user.workspace.export.config-pdf)

<!-- anchor: user.workspace.export.space-qr -->
### Códigos QR de espacios (PDF)

**Público:** Propietario · Administrador/a con el permiso

Usted quiere una tarjeta QR en cada asiento, mesa, oficina y planta, para que la gente reserve o registre su llegada escaneándola.

**Pasos**

1. Abra [Informes](app:/reports?section=documents) y elija **Documentos del espacio**.
2. Toque **Códigos QR de espacios (PDF)**.
3. Elija **Tamaño de la tarjeta**, **Tamaño del código QR** e **Información en la tarjeta**, y toque **Guardar**.
4. Imprima, recorte y pegue cada tarjeta en su lugar.

**Conviene saber**

- Necesita la función **Códigos QR de espacios**.
- Escanear una tarjeta abre la misma hoja que muestra el quiosco.

**Véase también:** [Una tableta de pared para registrar la llegada](help:user.kiosk.mode)

<!-- anchor: user.workspace.export.excel -->
### Exportar los datos (Excel)

**Público:** Propietario · Administrador/a con el permiso

Usted quiere sus cifras en una hoja de cálculo para su propio análisis.

**Pasos**

1. Abra [Informes](app:/reports?section=documents) y elija **Documentos del espacio**.
2. Toque **Exportar datos (Excel)**.

**Conviene saber**

- Llega como un único ZIP: un libro con una pestaña para reservas, pagos, facturas, miembros y el plano, un manifiesto que cuenta las filas y los archivos guardados del espacio.
- Necesita la función **Exportación de datos (Excel)** y el permiso de exportar datos. Es solo una exportación: nada la vuelve a leer.

**Véase también:** [Exportar el espacio (XML)](help:user.workspace.export.space-xml)

<!-- anchor: user.workspace.sites -->
### Sedes

**Público:** Propietario · Administrador/a

Usted dirige más de una dirección y quiere que cada planta y cada miembro pertenezcan a la correcta.

**Pasos**

1. Active **Sedes** en [Funciones](app:/features).
2. Abra [Sedes](app:/settings/sites) y toque **Añadir una sede**.
3. Rellene **Nombre de la sede**, **Calle**, **Código postal**, **Ciudad** y las plantas que le pertenecen.

**Conviene saber**

- La sede predeterminada lleva la dirección del espacio. La sede de origen de un miembro es la dirección que figura en sus documentos.
- **Eliminar esta sede** devuelve sus plantas y miembros a la sede predeterminada.
- Una sede que es su propia entidad legal puede llevar su propio registro y número de IVA.
