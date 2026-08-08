# Guía de usuario

Todo lo que un miembro, admin o propietario necesita para usar DesKilo.

> Las capturas de pantalla de esta guía muestran la app en francés — cada pantalla existe idéntica en los cinco idiomas (English, Français, Deutsch, Español, Italiano); cambia el idioma en **Ajustes → Idioma**.

![](assets/help/images/settings-language.jpg)

## 1. Primeros pasos

### Crear una cuenta

Abre la app y regístrate con tu correo, una contraseña (mínimo 8 caracteres) y un nombre visible — o **continúa con Google**. El botón del ojo muestra u oculta la contraseña mientras escribes, y *¿Olvidaste la contraseña?* envía un enlace de restablecimiento. Un acceso con Google puede vincularse más tarde a una cuenta de correo existente en **Ajustes → Cuentas vinculadas**.

### Crear un espacio — o unirse a uno

Tras iniciar sesión llegas a la pantalla de bienvenida con dos caminos:

- **Crear un espacio** — te conviertes en su **propietario**. Elige nombre, país (determina la moneda por defecto) y zona horaria. Después dibujarás tu plano en el editor (§8).
- **Unirse a un espacio** — escribe el **ID del espacio** que te compartieron, o toca **Escanear código QR** y apunta la cámara al QR de invitación colgado en la pared de tu espacio. Te unes con el rol que lleva la invitación (§2).

### Perfiles — una cuenta, varios espacios

Una cuenta puede pertenecer a varios espacios. **Ajustes → Perfiles** los lista todos: cada fila muestra el nombre del espacio, **tu rol allí** (Miembro, Admin, Propietario) y su ID de espacio. La **marca de verificación** señala el perfil en el que estás ahora; la **estrella** marca tu perfil **predeterminado** — aquel con el que se abre la app, en cualquier dispositivo e incluso tras reinstalar (la elección se guarda con tu cuenta). Toca una fila para cambiar, **+ Añadir un perfil** para unirte a otro espacio más. Todo en la app se refiere al espacio activo.

### Orientarse

La app tiene cinco destinos en la barra inferior: **Plano** (§3), **Calendario** (§5), el gran botón central **Reservar** (§4), **Miembros** (§6) y **Finanzas** (§9). Dos iconos viven en cada cabecera: la **campana** abre el hilo de eventos y confirmaciones (§7, con una insignia que cuenta lo que te espera) y el **engranaje** abre los **Ajustes** (§12). Con el teléfono en horizontal y en tabletas, la mayoría de las pantallas pasan a un **diseño dividido** — controles en un panel lateral, contenido llenando el resto.

**Todo se mantiene en vivo.** Lo que cualquiera cambie — una reserva, un miembro nuevo, un ajuste — se envía en segundos a cada dispositivo conectado, incluido el que hizo el cambio. Sin reiniciar, sin tirar para actualizar.

## 2. Roles e invitaciones

DesKilo tiene tres roles acumulativos, más una cuenta de dispositivo:

| Rol | Puede |
|---|---|
| **Miembro** | Registrar entrada/salida, reservar, presentar gastos, ver y gestionar sus propios eventos y su propia cuenta |
| **Admin** | Todo lo de un miembro, más: actuar *por cualquiera* (reservas, pagos, gastos — sujeto a confirmación, §7), aprobar gastos, emitir credenciales de quiosco |
| **Propietario** | Todo lo de un admin, más: editar el espacio físico, definir planes y precios, gestionar roles, dispositivos quiosco y ajustes del espacio |
| **Copropietario** | *Activo*: los permisos del propietario de inmediato, más la sucesión automática. *Pasivo*: un sucesor en espera, sin permisos adicionales hoy |
| **Quiosco** | Una cuenta de tableta de pared (§10) — solo muestra el plano; los miembros reales actúan a través de ella con una credencial |

Qué rol puede hacer qué no está grabado en piedra: el propietario lo afina en la matriz de **Gestión de roles** (§8).

**Cada invitación está ligada a un rol.** En la pantalla *ID del espacio y QR* del propietario, dos pestañas guardan dos invitaciones, cada una con su propio código QR y su propio código:

- **Invitación de miembro** — el propio ID del espacio, mostrado bajo el nombre del espacio. Imprímelo, cuélgalo en la pared, compártelo libremente: quien lo escanee o escriba se une como miembro normal. Botones: **Copiar ID**, **Compartir como PNG**, **Cambiar el ID del espacio** (sustituye el ID generado por uno memorable, 4–20 letras/dígitos) e **Invitar a alguien**.
- **Invitación de admin** — un **código personal de un solo uso**, emitido por un propietario para una persona concreta. La pantalla lo dice claramente: *este código admite a UNA persona como admin y luego caduca* (un código sin usar expira a los 14 días). Entrégalo solo a la persona a la que está destinado; emite uno nuevo por admin con **Nuevo código de admin**.
- **Las invitaciones hablan el idioma del invitado** — la hoja de invitación redacta el mensaje en el idioma que elijas (cinco disponibles), por defecto el **idioma del espacio** definido en los *Ajustes del espacio*. El propietario también puede personalizar allí el texto de la invitación **por idioma**, con marcadores como `{firstName}`, `{workspaceName}`, `{inviteLink}`, `{downloadUrl}`, `{role}`; un idioma dejado vacío usa el mensaje integrado traducido.

**No existe invitación de propietario — a propósito** (el pie de la pantalla te lo recuerda). La propiedad solo puede otorgarla un propietario existente, en *Miembros y planes*. Un espacio conserva siempre al menos un propietario. Promover o degradar un **admin** pasa por el flujo de validación (§7) — se aplica cuando los validadores del espacio confirman.

**Los copropietarios mantienen vivo el espacio.** El propietario nombra copropietario a cualquier miembro o admin (*Miembros y planes → el miembro → Copropiedad*), en una de dos variantes: un copropietario **activo** trabaja con los permisos del propietario de inmediato; un copropietario **pasivo** no tiene permisos adicionales hasta el día en que hagan falta. En ambos casos, la sucesión es automática: si el último propietario se va — sale, es eliminado o su cuenta desaparece — el mejor copropietario (activo antes que pasivo) **se convierte en propietario al instante**, en el servidor, sin que haga falta ninguna acción. El propietario también puede ceder el mando deliberadamente en cualquier momento con *Promover a propietario ahora*. Un matiz: las reglas de validación que exigen la firma del *propietario* (§7) se refieren siempre a un propietario literal, no a un copropietario activo.

El QR codifica un enlace que nombra el rol otorgado (`deskilo://join?role=…`). Manipular el enlace no cambia nada — el servidor deriva el rol del propio código: el ID del espacio siempre une como miembro, y una invitación personal une exactamente en el rol con el que se emitió, una sola vez. Un código de admin reenviado ya usado — o caducado — no admite a nadie.

**Invitar por mensaje** (*Invitar a alguien*): cada envío por WhatsApp/SMS/compartir emite su propio código personal de un solo uso y compone un mensaje listo en el idioma del invitado. El destinatario puede simplemente copiar el mensaje completo y pegarlo en el campo de unión de la app — el código se detecta automáticamente.

## 3. El plano (pestaña Plano)

El plano muestra la planta activa de tu espacio: oficinas, mesas y puestos, con código de colores — **libre**, **reservado**, **ocupado**, **mío**, **bloqueado**. Se abre **al instante con los últimos datos conocidos** y se actualiza en segundo plano — con un Wi-Fi inestable sigues viendo el estado más reciente en lugar de una pantalla vacía. Los puestos ocupados muestran el nombre de pila de quien está, una **insignia de registro** cuando ha hecho check-in y un **punto verde** cuando está en línea en la app en ese momento. Cuando una **mesa, sala o planta entera** está reservada, el propio espacio lo dice — un lavado de color, un borde marcado y una **ficha con candado y el nombre del ocupante** en el centro (un glifo de registro cuando ya está allí); la etiqueta de la sala se lee *Bureau 2 · Florian*. Lo ven todos los usuarios, en el plano, en el hub Reservar y en el quiosco.

El plano puede parecerse a tu espacio real: el propietario puede poner una **foto de la sala como fondo de la planta** y colocar libremente **imágenes de ilustración redimensionables** (plantas, sofás…) sobre la cuadrícula. Un control de **transparencia de mesas** en los ajustes del espacio deja ver la foto a través de las mesas dibujadas.

Moverse:

- A lo largo del borde superior: un conmutador **mapa / lista** (la lista muestra los mismos puestos como filas), el **chip de fecha** (tócalo para navegar a otro día) y tres **chips de franja** — mañana, tarde, día completo — que filtran lo que muestra el plano.
- El lienzo **se ajusta solo** a tu planta al abrir o al girar el dispositivo; **pellizca para hacer zoom** o usa los botones **+ / −**, arrastra las **barras de desplazamiento** en los bordes y toca el botón de **ajuste** para recentrar.
- Elige la planta en la **barra de plantas** a la derecha (1, 2, …); su **icono de capas** actúa sobre la planta entera (abajo). En **horizontal**, los controles pasan a un panel lateral y el plano llena la pantalla — útil en tabletas.

Reservar desde el plano:

- **Registro espontáneo**: toca un puesto libre → la hoja propone *ahora* hasta el fin por defecto del espacio → confirma. Si alguien reservó ese puesto más tarde, tu hora de fin se recorta y se te avisa.
- **Registro sobre reserva**: registrarse significa *estás aquí* — la ventana abre **15 minutos antes** de tu inicio y se cierra al final de la reserva. Fuera de ella el botón de registro está desactivado y dice cuándo abre; navegar un horario futuro nunca ofrece un registro en vivo. Los admins pueden registrar a un miembro presente en su puesto (mientras *reservar para otros* esté activo).
- **Salida**: manual — o, si el propietario activa la **entrada/salida automática**, las reservas olvidadas se completan solas al final del día: las nunca tocadas cuentan como asistidas de su inicio a su fin, y las salidas olvidadas se cierran al final propio de la reserva.
- **Espacios enteros**: **doble toque** en una mesa, una sala o una zona libre del suelo — o toca el **icono de capas** de la barra de plantas — para actuar sobre la **mesa, oficina o planta entera**: la hoja nombra la planta, muestra el periodo (p. ej. *jue 6 ago 10:13 → 12:00*), deja a los admins elegir **Para el miembro** (tú mismo u otra persona) y confirma con **Reservar la planta**. El mismo selector de periodo y las mismas opciones de repetición que un puesto.
- **Línea de tiempo**: elige una ventana de→a (o Mañana / Tarde / Día completo, según la granularidad del espacio) para ver la ocupación en cualquier momento futuro.
- Los puestos pueden llevar **accesorios** (monitor, mesa elevable…), algunos con suplemento por media jornada que aparece en tu extracto.
- Las reservas cuentan contra tus **días mensuales** (§9) — pasado tu plan, la app bloquea o cobra, según lo que el propietario configuró para ti.

## 4. Reservas (hub Reservar)

Abre el hub **Reservar** (botón central). A lo largo del borde superior: los cuatro **botones de vista**, el **chip de fecha**, el **botón de escaneo QR** (abajo, §4a), los **chips de franja** (mañana / tarde / día completo) y los **chips de planta** (*Todas las plantas*, o uno por planta). Después, cuatro vistas:

- **Plano** — el plano filtrado a tu ventana elegida; toca un puesto libre para reservarlo.
- **Día** — cada puesto como fila de cronología del día elegido (08:00 → 17:00 o el horario de tu espacio, la línea roja marca *ahora*); toca un tramo libre para reservar, tu propio bloque para ver sus detalles.
- **Semana** — una cuadrícula puesto × día de toda la semana ISO, con una banda de días (*lun 3 … dom 9*) encima; cada celda contiene las medias jornadas del día con la inicial del ocupante. Encuentra una media jornada libre de un vistazo y tócala para reservar.
- **Mes** — un calendario de disponibilidad: cada día muestra su **recuento de mesas libres** (p. ej. *10/12*); toca un día para entrar en su vista Día.

**Un sitio a la vez**: solo puedes mantener una reserva activa por ventana de tiempo — reservar o registrarte en otro sitio mientras corre otra se rechaza, y registrarse cierra cualquier registro anterior cuya reserva ya terminó. Los admins y propietarios pueden **anular**: tocar un puesto ocupado o reservado ofrece *Quitar la reserva (anular)* — la reserva se elimina y el miembro y todos los admins reciben aviso por el hilo de eventos.

Las reservas siguen la **regla de granularidad** del espacio (§8 Disponibilidad) — medias jornadas, días completos, horas reales (de–a exacto, con las ventanas de media jornada y jornada como atajos) u horas de inicio/fin libres sobre la rejilla de tramos del propietario. Las medias jornadas y jornadas completas cubren el **horario laboral** configurado del espacio (por defecto 8:00–17:00 con el límite de media jornada a las 12:00). Respetan los **días de apertura** y los **días de cierre**, y las reglas de reserva (horizonte de antelación, duración máxima, plazo de cancelación). ¿Necesidad recurrente? Reserva una **serie** (diaria, laborables, semanal) — los días cerrados y los conflictos se saltan y se informan.

**Eliminar una reserva pasada o registrada es una solicitud, no una acción.** Una reserva cuyo inicio ya pasó — o donde ya te registraste — no se cancela directamente: la hoja ofrece en su lugar **Solicitar eliminación**. Un propietario o admin decide la única pregunta que importa para la facturación: ¿se olvidó simplemente el registro (la reserva se mantiene en el historial) o nunca se usó (se elimina)? La solicitud aparece en el hilo de Eventos con tu motivo opcional; las reservas futuras sin tocar conservan la cancelación normal de un toque.

### 4a. Escanear un código de espacio

Cada puesto, mesa, oficina y planta puede llevar una **tarjeta QR** impresa (§8). Toca el **botón de escaneo** en el hub Reservar, apunta la cámara a la tarjeta — o escribe su código — y la app identifica el espacio y muestra exactamente lo que *tú* puedes hacer allí:

- **Tarjeta de puesto** — reserva o regístrate en ese puesto concreto, al momento (la ventana de hoy: mañana / tarde / día completo donde el espacio usa medias jornadas; si no, desde ahora para las próximas horas).
- **Tarjeta de mesa** — los puestos de la mesa con su estado en vivo; elige uno libre.
- **Tarjeta de oficina o planta** — si el propietario la hizo reservable, la función *Reservas de mesa, oficina y planta* está activada **y** tienes el derecho personal (§8) — los propietarios y admins siempre lo tienen — puedes reservar o registrarte en la **oficina o planta entera** — con el mismo selector de periodo (mañana / tarde / día completo, u horas libres) y las mismas opciones de **serie** que un puesto; se muestra su precio por media jornada y entra en tu factura. Si no, la hoja te dice por qué, y una oficina recae en sus puestos.

**Los conflictos protegen en ambos sentidos:** una oficina o planta no puede reservarse mientras algún puesto de su interior ya esté reservado en esa ventana — y ningún puesto puede reservarse mientras su oficina o planta esté reservada entera.

## 5. Calendario (pestaña Calendario)

El mes de un vistazo, con dos alcances y dos formas:

- **Mías / Todos** — tus propias reservas, o las de toda la comunidad. Tus días se marcan en **rojo**, los de otros miembros en **azul**, hoy va rodeado; un punto bajo un día significa que allí hay algo reservado.
- El **conmutador de forma** a su lado cambia la mitad inferior entre una **cuadrícula semanal** (puestos × días, como en el hub Reservar) y una **lista de agenda** (cada reserva como tarjeta: ventana horaria, miembro, espacio).
- Los **chips de planta** (*Todas las plantas* / por planta) filtran ambas formas.
- Toca un día en la cuadrícula mensual para cargarlo abajo. En horizontal, el calendario y el detalle usan el diseño dividido.

## 6. Directorio de miembros (pestaña Miembros)

Mira quién forma tu comunidad:

- Cada tarjeta de miembro muestra su **foto** (o inicial), su **chip de rol** (Admin, Propietario), su **estado personalizado** («en Berlín hasta el viernes…»), un indicador **en línea / visto por última vez** (*En línea*, *10 min*, *2 d*) y un **chip de reserva**: puesto registrado, *Reservado ahora*, o la próxima reserva.
- Toca un miembro para su **ficha de detalle** — rol, presencia, sus **próximas reservas** y **Enviar notificación**.
- **Enviar notificación**: una nota corta dentro de la app (hasta 500 caracteres) a otro miembro — entregada como push y como notificación con tu nombre y tu mensaje. El texto completo queda siempre legible en **Eventos → Mensajes**, para el destinatario y el remitente (el push en sí no transporta contenido, por diseño de privacidad). Los admins tienen un megáfono **Notificar a todos los admins** en la cabecera que llega a todos los admins, incluido el propietario. Conmutable con la función *Notificaciones entre miembros*.
- El **icono de mensaje** de una tarjeta escribe a ese miembro por **WhatsApp** (si compartió su número); el **botón de grupo** abre el grupo de WhatsApp de tu comunidad (definido por el propietario).
- Define tu propia foto, tu estado y la visibilidad de tu teléfono en **Ajustes** (§12).
- Los admins y propietarios ven además el **correo** de cada miembro bajo el nombre — los miembros normales no: el contacto entre miembros sigue siendo el número de WhatsApp compartido voluntariamente.

## 7. Eventos y confirmaciones (icono de campana)

El hilo de eventos es la pista de auditoría de tu espacio: reservas creadas/cambiadas/canceladas, pagos registrados, facturas pagadas, gastos presentados, solicitudes de días extra, cambios de rol, solicitudes de eliminación. Los miembros ven sus propios eventos; los admins y propietarios ven los de todos. Los **chips de filtro** (Todo · Reserva · Pago · Gasto · …) acotan la lista; cada fila lleva su icono de estado — un **reloj de arena** mientras está pendiente, una **marca verde** una vez confirmado — y los eventos de dinero muestran *quién los validó y cuándo* directamente en la fila.

**A la espera de tu confirmación:** siempre que un admin hace algo *por otra persona* — te reserva un puesto, registra tu pago, degrada a un admin — queda **pendiente hasta que se confirme**. Lo pendiente se fija arriba con una ✕ roja y un botón verde **Aceptar**, y recibes una notificación. Lo que haces sobre ti mismo nunca requiere confirmación.

**Mensajes:** la campana también reúne tus notificaciones entre miembros (§6) — recibidas y enviadas, con su **texto completo**, las más recientes primero. **Desliza a la derecha** un mensaje para responder a su remitente, **a la izquierda** para borrarlo (una difusión recibida a todos los admins no se puede borrar — desaparecería para todos los admins). Los mensajes sin leer cuentan en la campana y en el icono de la app hasta que abres esta pantalla.

**Quórum de validación:** para asuntos de dinero y cambios de rol, el propietario define *quién* debe aprobar y *cuántas* aprobaciones hacen falta. **Nadie valida su propio evento** — solo otra persona puede; donde no existe otro validador, la solicitud simplemente espera. Las solicitudes sin respuesta caducan a los 7 días — nada costoso se concede jamás en silencio, y nadie se lo concede a sí mismo.

El propietario afina esto por **dominio** en **Ajustes → Reglas de validación** — una tarjeta por tipo de evento, cada una heredando de la **regla predeterminada** hasta que se edita: *Regla predeterminada, Pago, Gasto, Servicio, Medias jornadas extra, Eliminación de reserva, Cambio de rol, Nuevo miembro, Reserva, Reservas de espacios enteros, Pago de factura, Ajuste* — y las solicitudes de **anulación de saldo** de factura viajan por el mismo marco. Una regla fija el número de validaciones requeridas, *qué* admins pueden validar (todos, o algunos concretos) y si el propietario debe firmar siempre.

![](assets/help/images/validation-rules.jpg)

 

![](assets/help/images/validation-rule-edit.jpg)

*Izquierda: una regla por dominio, heredando de la predeterminada. Derecha: edición de una regla — validaciones requeridas, validadores autorizados, firma del propietario.*

## 8. Para propietarios: editor y ajustes

Toda la administración vive en **Ajustes → Administración** — *Espacio de coworking* (los ajustes del espacio), *Miembros y planes*, *Gestión de roles*, *Facturación e informes* (el hub de facturación con el editor de informes y las reglas de recordatorio en su cabecera), *Accesorios*, *Disponibilidad*, *Funciones* y las entradas ligadas a funciones (Pagos en línea, Credenciales RFID/NFC…). Una regla que conviene conocer: **la entrada de ajustes de una función solo aparece mientras esa función está activada** — desactiva *Pagos en línea* en **Funciones** y su pantalla de configuración desaparece con ella (y vuelve al reactivarla). La entrada **Funciones** siempre está presente, así que siempre puedes volver a activar un módulo.

![](assets/help/images/settings-administration.jpg)

### El editor del espacio

Abre el **editor** desde la barra de la pestaña Plano (icono de herramientas cruzadas). La pantalla **Editor del espacio** lista tus plantas — arrastra para reordenar, el **icono de capas** marca una planta *Reservable en su totalidad*, el **menú ⋮** renombra o elimina, **+ Añadir planta** amplía el edificio. Abre una planta para dibujarla sobre la cuadrícula con la barra inferior — **Seleccionar · Oficina · Mesa · Puesto · Imagen · Borrar**:

- Una **oficina** recibe un nombre, un interruptor opcional *Reservable en su totalidad* y un **precio por media jornada**.
- Una **mesa** recibe un nombre y la misma opción de mesa entera.
- Un **puesto** recibe un nombre, una **orientación de asiento** (↑ → ↓ ←), un **tipo de silla** opcional, sus **accesorios** (cada uno puede llevar un suplemento por media jornada) y un interruptor **Bloqueado (mantenimiento)**.
- **Imagen** coloca una ilustración redimensionable; el icono de foto de la barra define la **foto de fondo** de la planta.
- Borrar algo con reservas futuras obliga a resolverlas antes.

### ID del espacio y QR

Tus invitaciones ligadas a rol (§2): invitación de miembro = el propio ID del espacio (sustitúyelo por uno memorable, cópialo, comparte el QR como PNG), invitación de admin = códigos personales de un solo uso.

### Disponibilidad

- **Días de apertura** — chips lun…dom.
- **Granularidad de reserva** — una de: *rango horario libre*, *tramos de 5 / 15 / 30 / 60 minutos*, *medias jornadas (mañana y tarde)*, *solo días completos* u *horas reales* (de–a exacto, con los atajos de media jornada y jornada completa).
- **Horario laboral** — inicio del día, límite de media jornada, fin del día (por defecto 08:00 / 12:00 / 17:00). Las medias jornadas y jornadas completas de toda la app — reservas, registro y facturación — siguen este horario; con *horas reales* defines además cuántas horas se facturan como media jornada y como jornada completa.
- **Días de cierre** — excepciones con fecha, añadidas con **+**.

### Funciones

Activa o desactiva módulos enteros por espacio — cada interruptor lleva su descripción en la propia pantalla: pestaña calendario, pestaña eventos, pestaña finanzas, servicios, suplementos de accesorios, pagos en línea, facturas, los admins emiten facturas, exportar PDF, reserva en serie, reservar para otros, notificaciones push, los administradores pueden bloquear sitios, reservas de mesa, oficina y planta, los admins pueden asignar plantas, modo quiosco, credenciales RFID/NFC, directorio de miembros, integración con WhatsApp, códigos QR de espacios, copropietarios, entrada/salida automática, exportación de datos (Excel), horario laboral, plantilla del PDF de factura, notificaciones entre miembros, biblioteca de documentos, recordatorios de pago (Mahnwesen), informes de miembros, solicitudes de eliminación de reservas, gestión de roles. Desactivar un módulo elimina *todas* sus pantallas y botones para todos los miembros.

La lista es **jerárquica**: una función que necesita otra aparece indentada bajo ella con una nota *Requiere…*, y queda atenuada mientras su padre está desactivado — *Finanzas* lleva los servicios, los suplementos, los pagos en línea y la facturación; *Facturas* lleva la delegación a admins, la plantilla PDF y los recordatorios de pago; *Modo quiosco* lleva las credenciales RFID/NFC; *Directorio de miembros* lleva la integración con WhatsApp. Desactivar un padre saca todo su subárbol de la app; la elección guardada del hijo vuelve intacta cuando el padre regresa.

![](assets/help/images/workspace-id-qr.jpg)

 

![](assets/help/images/availability-granularity.jpg)

 

![](assets/help/images/features-toggles-1.jpg)

 

![](assets/help/images/features-toggles-2.jpg)

### Miembros y planes

Toca un miembro para abrir su **ficha de gestión** — cada acción por miembro en un solo lugar: **Enviar el acuerdo financiero** (§11d), **Enviar notificación**, **Añadir un servicio** (servicio, cantidad, mes de facturación → *enviar a confirmación*), **Suscripción** (su porcentaje), **Cuando se acaban los días** (la política de exceso, §9), **Límite de reservas** (tope de reservas simultáneas), **Puede reservar una mesa, oficina o planta entera**, **Credenciales** (§10), **Nombrar admin** (validado, §7), **Copropiedad**, **Convertir en quiosco** y **Pausar la membresía**. Cada fila muestra el **correo** del miembro bajo el nombre.

![](assets/help/images/member-management-sheet.jpg)

 

![](assets/help/images/member-subscription.jpg)

 

![](assets/help/images/member-reservation-limit.jpg)

### Facturación

- **Tramos de tarifas** — la escalera de precios detrás de las suscripciones porcentuales: cada tramo dice *desde X %*, *hasta Y %*, la **cuota** mensual y la **tarifa de exceso** por media jornada extra. **+ Añadir tramo** amplía la escalera.
- **Niveles de suscripción** — qué porcentajes pueden elegir los miembros (chips: 25 % · 50 % · 75 % · 100 %, más tus propios valores), y un interruptor opcional de **valor personalizado negociado**.
- **Paquetes de días** — un número de días por un precio (nombre · días · precio), cada uno con su propio interruptor; los miembros con la política de *paquetes* los compran cuando se les acaban los días.

### Servicios y Accesorios

Los catálogos detrás del §9 — extras definidos por el propietario (taquillas, impresión…, cada uno con un precio y un tipo de IVA opcional) y equipamiento por puesto con suplementos opcionales por media jornada. Ambos son listas simples con un botón **+**.

![](assets/help/images/billing-bands-levels-packages.jpg)

 

![](assets/help/images/services-catalog.jpg)

 

![](assets/help/images/services-new-service.jpg)

 

![](assets/help/images/accessories-catalog.jpg)

### Ajustes del espacio (Espacio de coworking)

La pantalla propia del espacio, de arriba abajo:

- **Identidad** — nombre, país, moneda (propuesta según el país, editable), zona horaria, **idioma del espacio** (las invitaciones lo usan por defecto; *idioma de la app del remitente* es una opción) y la **dirección** postal impresa en las facturas.
- **Pagos y facturación** — las **instrucciones de pago** que los miembros ven en una factura impagada (IBAN, enlace PayPal.me, número de teléfono Wero, Lydia, Wisetag, pista de referencia de pago — deja un campo vacío para ocultarlo), y **Identidad legal y facturación electrónica** (§11a).
- **Grupo de WhatsApp** — el enlace del grupo de la comunidad mostrado en el directorio.
- **Mensaje de invitación** — las plantillas de invitación por idioma (§2).
- **Transparencia de mesas** — el control que deja ver una foto de fondo a través de las mesas dibujadas.
- **Plantilla del PDF de factura** y **Reglas de recordatorio** — accesos directos al editor de informes y a la configuración de recordatorios (§11).
- **Exportaciones** — *Exportar el espacio (XML)* (ajustes + plano, sin datos personales — respáldalo, úsalo de plantilla, migra una instancia), *Exportar configuración (PDF)* (una instantánea completa: ajustes, miembros, plano), *Informe del espacio* (todo sobre el espacio mediante la plantilla « espacio » del motor de informes), *Códigos QR de espacios (PDF)* (un QR tamaño tarjeta de crédito por puesto, mesa, oficina y planta, diez por A4), *Exportar datos (Excel)* (un libro: reservas, pagos, facturas, miembros, plano — una pestaña cada uno), *Importar el espacio (XML)* (restaura ajustes y plano; sustituye el plano actual). Cada exportación se guarda en la carpeta de **Descargas** de tu dispositivo.
- **Zona de peligro** — **Restablecer el espacio**: borra todas las reservas, la contabilidad y el plano; conserva ajustes y miembros. Protegido por una confirmación escrita.

### Códigos QR de espacios y reservas de espacios enteros

Cuatro pasos convierten «escanear el código de la mesa» en el flujo de reserva diario (§4a):

1. En el **editor**, marca una oficina o una planta como **Reservable en su totalidad** y dale un **precio por media jornada** — la ficha de propiedades de la oficina, o para una planta el **icono de capas directamente en su fila**.
2. Activa **Reservas de mesa, oficina y planta** en **Funciones** (desactivada por defecto).
3. Concede a cada miembro autorizado **«Puede reservar una oficina o planta entera»** — propietarios y admins lo fijan en la ficha de gestión del miembro, nunca para sí mismos.
4. Imprime las tarjetas: **Ajustes del espacio → Códigos QR de espacios (PDF)** — recórtalas y pega cada tarjeta en su espacio.

Una reserva de oficina cubre **todas las mesas de su interior**; una reserva de planta cubre la planta entera. Ambas solo son posibles mientras nada de su interior esté reservado — y aparecen como líneas propias en la factura del miembro.

### Copropietarios

Asegúrate de que la comunidad nunca dependa de una sola cuenta:

1. Abre *Miembros y planes → el miembro → **Copropiedad*** y elige **activo** (permisos de propietario ya) o **pasivo** (sucesor en espera).
2. Cede el mando en cualquier momento con ***Promover a propietario ahora*** — el copropietario se convierte en propietario de pleno derecho junto a ti.
3. Si el último propietario abandona alguna vez el espacio, el mejor copropietario es **promovido automáticamente** en el servidor — activo antes que pasivo. Esta red de seguridad funciona incluso con el interruptor de la función *Copropietarios* desactivado (el interruptor solo oculta los botones de nombramiento).

### Gestión de roles

Una matriz central decide **qué rol tiene qué permiso** — gestionar roles, gestionar miembros, políticas de validación, configuración del espacio, emitir facturas y conciliar pagos, ver finanzas, documentos, servicios, aprobar gastos. Ábrela en *Ajustes → Administración → Gestión de roles* (su interruptor de función debe estar activado):

- El **propietario tiene siempre todos los permisos** — su fila está bloqueada.
- Quien tenga *Gestionar roles y permisos* edita las demás filas. Un **copropietario** empieza con todo («un copropietario puede tener menos» — el propietario quita lo que quiera); un **admin** empieza con las capacidades de admin de hoy; un **miembro**, sin ninguna.
- Todos los demás con algún permiso ven la matriz en **solo lectura**, con su propio rol resaltado.
- Una matriz sin tocar significa los valores por defecto — nada cambia hasta que el propietario la edita. El antiguo interruptor de función *los admins emiten facturas* sigue concediendo la facturación a los admins por compatibilidad. El servidor aplica la misma matriz en las RPC de facturación (`has_permission`), de modo que la interfaz y la base de datos nunca pueden discrepar.

### Configurar los pagos en línea

Cada comunidad cobra en su **propia** cuenta de proveedor; la app nunca guarda las claves secretas en ningún dispositivo — viven en el servidor.

1. Abre **Ajustes → Pagos en línea** (solo propietario).
2. Elige un proveedor y pega sus claves desde el panel de ese proveedor:
   - **PayPal** — Client ID, Secreto, Entorno (empieza por *sandbox*), ID de webhook, URL de retorno (PayPal Developer → tu app REST).
   - **Tarjeta (Stripe)** — Clave secreta, Secreto de firma del webhook, URL de retorno (Stripe → claves API / Webhooks).
   - **Mollie** — Clave API, URL de retorno (ofrece iDEAL, Bancontact, tarjetas…).
   - **Wero (con Mollie)** — la misma clave API de Mollie, con Wero activado en tu cuenta Mollie.
3. **Guarda** — aparece un chip verde *Configurado*. Activa la función **Pagos en línea** (Ajustes → Funciones) y los miembros verán **Pagar en línea** en una factura pendiente. (La propia entrada de ajustes *Pagos en línea* solo se muestra mientras la función está activada.)

![](assets/help/images/payment-config-paypal-stripe.jpg)

 

![](assets/help/images/payment-config-mollie-wero.jpg)

Un secreto guardado no se vuelve a mostrar — deja su campo en blanco para conservarlo, escribe para reemplazarlo, **Eliminar** para quitar el proveedor. Las comisiones son del proveedor (típicamente ~1,5–3 % por pago, sin cuota mensual); DesKilo no añade nada, y la vía manual por transferencia/IBAN sigue siendo gratis.

Si un pago no arranca, activa **Ajustes → Avanzado → Modo desarrollador** y abre la pantalla **Desarrollador**: la traza de *pagos* muestra exactamente qué proveedores están configurados y qué campos faltan todavía.

![](assets/help/images/developer-payment-traces.jpg)

#### Los paneles de los proveedores, paso a paso

Mantén **los entornos de prueba y de producción estrictamente separados**: cada proveedor tiene claves distintas por modo, y todas las claves que pegues en DesKilo deben pertenecer al mismo modo. En las URL de abajo, `<project-ref>` es la referencia de tu proyecto de Supabase (las instancias autoalojadas usan la URL de su propia instancia).

**PayPal**

1. Inicia sesión en [developer.paypal.com](https://developer.paypal.com) y abre **Apps & Credentials**.
2. Cambia el conmutador **Sandbox / Live** — empieza en *sandbox*; pasa a *live* solo para producción. El campo *Entorno* de DesKilo debe coincidir con las claves.
3. **Crea una app REST-API** — esto genera el **Client ID** y el **Secret**.
4. En la app, añade un **webhook**: URL `https://<project-ref>.supabase.co/functions/v1/paypal-webhook`, suscrito como mínimo a *Payment capture completed* (más *denied* / *order voided*). Copia el **Webhook ID**. En DesKilo el webhook no es opcional — es la vía por la que un pago queda liquidado en la factura.
5. Pega el Client ID, el Secret, el Entorno, el Webhook ID y tu URL de retorno en **Ajustes → Pagos en línea → PayPal**. Nada se guarda en la app ni en ningún dispositivo — todo va al servidor.

**Stripe (tarjetas y Cartes Bancaires)**

1. Inicia sesión en [dashboard.stripe.com](https://dashboard.stripe.com) y abre **Developers**.
2. El conmutador **Test mode / Live mode** decide qué claves ves. DesKilo solo necesita la **Secret key** — el checkout se crea en el servidor, así que la clave *publishable* no se usa.
3. En **Settings → Payment methods**, activa las redes de tarjetas que quieras. **¿Tu público está en Francia? Activa explícitamente Cartes Bancaires** — los miembros franceses suelen preferir CB al enrutado internacional de Visa/Mastercard.
4. En **Developers → Webhooks**, añade el endpoint `https://<project-ref>.supabase.co/functions/v1/stripe-webhook` con el evento `checkout.session.completed`, y copia el **Webhook signing secret**.
5. Pega la Secret key, el secreto de firma y tu URL de retorno en **Ajustes → Pagos en línea → Tarjeta (Stripe)**.

**Mollie (iDEAL, Bancontact, Wero…)**

1. Inicia sesión en [my.mollie.com](https://my.mollie.com) → **Developers → API keys** y copia la **API key** de **Test** o **Live** (el modo va codificado en la propia clave).
2. En **Settings → Payment methods**, activa lo que deban ver tus miembros: **iDEAL** (Países Bajos), **Bancontact** (Bélgica), tarjetas — y **Wero**, el monedero de la European Payments Initiative para pagos instantáneos de cuenta a cuenta en Alemania, Francia y Bélgica (el sucesor de Paylib y giropay).
3. En DesKilo, **Mollie** y **Wero** son dos tarjetas de proveedor que comparten la misma API key — un pago Wero se crea como un pago Mollie con el método Wero. Configura las que quieras que vean los miembros.
4. Las URL de redirección y de webhook las establece **DesKilo automáticamente** en cada pago (redirección = tu URL de retorno, webhook = la función `mollie-webhook`) — no hay nada que configurar en el panel de Mollie.

#### Más métodos de pago (perspectiva)

| Proveedor / método | Enfoque | Cómo encaja en DesKilo |
|---|---|---|
| **Apple Pay / Google Pay** | Monederos móviles, pago con un toque | Actívalos en tu panel de Stripe (o Mollie) — aparecen automáticamente en la página de pago alojada, sin cambios en DesKilo y sin comisión base extra. |
| **Klarna** | Compra ahora, paga después | Igual: actívalo en Stripe/Mollie y aparece en el checkout — relevante para importes grandes. |
| **Adyen** | Empresas y omnicanal, una API para casi cualquier método | No integrado — sería un nuevo proveedor en DesKilo (las contribuciones son bienvenidas). |
| **Braintree** | UI drop-in para móvil y web (propiedad de PayPal) | No integrado — la integración directa de DesKilo con PayPal ya cubre ese terreno. |

### Configurar las credenciales RFID / NFC

Las tarjetas físicas permiten registrarse con un toque — sin teléfono.

1. Abre **Ajustes → Credenciales RFID / NFC** (solo propietario). Activa **Activar registro por credencial NFC** y lee la línea de **estado del dispositivo** — distingue entre *listo*, *NFC desactivado en los ajustes de Android* y *sin hardware NFC* (los iPad no tienen).
2. Da una tarjeta a cada miembro: **Miembros y planes → el miembro → Credenciales → Registrar una tarjeta**, y acerca su tarjeta al dispositivo. Vale cualquier tarjeta con chip legible (MIFARE, NTAG…). Los miembros también pueden hacerlo **ellos mismos**: **Ajustes → Mi credencial** emite su credencial QR imprimible y registra su propia tarjeta — sin necesidad de admin.
3. Úsalas en un **quiosco** (§10): el miembro acerca la tarjeta para reservar o registrarse. Revoca una tarjeta perdida desde la misma ventana de Credenciales; **desliza una credencial revocada hacia la derecha para eliminarla** definitivamente.

Las credenciales pertenecen a **un solo espacio** — la ventana indica en cuál estás registrando, así que registra la tarjeta en el espacio cuyo quiosco la leerá. La misma tarjeta física puede servirte en varios espacios. Una credencial QR guardada **como PDF** imprime diez copias tamaño tarjeta de crédito en una página A4 — con repuestos incluidos.

![](assets/help/images/nfc-config.jpg)

 

![](assets/help/images/member-badges-dialog.jpg)

## 9. El dinero (pestaña Finanzas)

Tu cuenta responde *qué debo, qué me deben* — y *cuánto puedo reservar aún*. En vertical, la factura del mes se desplaza sobre los botones de acción; en horizontal, las acciones pasan a un panel lateral y la factura llena el resto. La cabecera **‹ mes ›** navega cualquier mes; el **botón PDF** exporta la factura visible (§ más abajo).

**La factura, tarjeta por tarjeta:**

- **Este mes** — cuántos **días** incluye tu suscripción este mes, cuántos has **usado**, cuántos **quedan**, con una barra de progreso. Una mañana reservada cuenta 0,5 días. El derecho mensual sigue los días de apertura del espacio y tu porcentaje — la tarjeta de suscripción debajo lo detalla (*3 de 42 medias jornadas usadas, 21 días de apertura*).
- **Servicios consumidos** — cada consumo de servicio con el total de servicios.
- **Paquetes de días** — los packs comprados este mes.
- **Partidas pendientes** — todo lo que aún *espera validación* (gastos, consumos de servicio…), en su propia tarjeta con borde ámbar: estos importes aún no están en la factura.
- **Pagos y créditos** — pagos registrados, reembolsos de gastos aprobados, notas de crédito, ajustes.
- **Tarjeta de factura** — una vez facturado el mes: número, chip de estado, total, lo pagado, lo pendiente (§9a).
- **Tu cuenta** — tu posición real entre meses, cuando existe (§9a).
- **Saldo** — saldado / pendiente, y debajo las **instrucciones de pago** y **Pagar en línea** cuando se debe algo.

**Cuando se acaban tus días**, lo que ocurre es elección del propietario, por miembro:

- **Bloqueado** (por defecto) — no más reservas; pide a un admin, o solicita **medias jornadas extra** directamente desde la pestaña Finanzas (los validadores aprueban; los días aprobados se cobran igualmente a la tarifa de exceso).
- **Pago por uso** — puedes seguir reservando; cada día extra se cobra a la tarifa de exceso de tu tramo (mostrada en la tarjeta).
- **Paquetes** — toca **Comprar un paquete** y elige uno de los packs de días del propietario; tus días aumentan al momento y el precio entra en la factura de este mes.

**Las acciones, agrupadas por sentido:**

- **Pagar** — **Registrar un pago** («he pagado») con su método, la **fecha en que se movió el dinero** (hoy por defecto) y el **mes que salda** (el mes en curso por defecto, un paso atrás para atrasos, uno adelante para un anticipo) — la otra parte confirma. Ese mes decide en qué factura y en qué documento entra el abono. **Pagar en línea** (cuando está activado) abona el importe adeudado al instante — con **PayPal, tarjeta (Stripe), Mollie o Wero**, según lo que el espacio haya activado (si hay varios, se muestra un selector).
- **Solicitudes** — **Enviar un gasto** (¿compraste café para el espacio? otro admin lo aprueba — sin autoaprobación — y se abona en tu extracto), **Solicitar medias jornadas extra**, **Añadir un consumo** (servicios definidos por el propietario — taquillas, impresión… — tú confirmas lo que consumiste).
- **Documentos** — **Facturas** (las tuyas siempre están legibles aquí: posiciones, saldo, estado — y para quien emite, el hub de facturación, §11), el **acuerdo financiero** y el **informe mensual de pagos**, en autoservicio (§11).

### 9a. Una vez facturado el mes, decide la factura

- Tu factura mensual muestra una **tarjeta de factura** — número, estado, total, lo pagado, lo pendiente — y el mes pasa a **saldado** en cuanto la factura se paga, se anula su saldo o se reembolsa su nota de crédito, aunque el pago que la salda se registrara en un mes posterior. Una factura **parcialmente pagada** deja el mes pendiente exactamente por el importe **restante** (eso es también lo que cobra *Pagar en línea*). Un mes con **nota de crédito** muestra lo que el espacio te debe devolver — nada que pagar por tu parte.
- **Tu cuenta** — cuando tienes crédito disponible (un avoir, o pagos sobrantes de un mes pasado), la pestaña Finanzas muestra tu posición real entre meses encima de la factura: **crédito a favor**, cada **factura abierta** con su importe restante, los reembolsos que el espacio te debe y la **posición neta** resultante. Tu crédito puede saldar facturas abiertas — el espacio lo aplica al conciliar los pagos (imputación). Los meses anteriores a tu adhesión no deben nada y nunca aparecen pendientes.

### 9b. Vista rápida, guardar, compartir — todos los informes

Cada informe de la app — la factura mensual, las facturas, los proformas, las notas de crédito, tus documentos de autoservicio — ofrece las mismas tres acciones: **Vista rápida** (ver el documento renderizado en pantalla antes de que exista PDF alguno), **Descargar PDF** (guardar localmente) y **Compartir PDF** (entregarlo a cualquier app — WhatsApp, correo, …).

**Los informes hablan el idioma de quien los lee:** tus documentos se imprimen en *tu* idioma de la app cuando el espacio lo proporciona, con el idioma del espacio como respaldo (§11, plantillas por idioma).

## 10. Modo quiosco (tableta de pared)

Monta una tableta Android o un iPad junto a la puerta y deja que la gente se registre al entrar:

1. El propietario crea una cuenta normal para el dispositivo, la une al espacio y la marca como **quiosco** en *Miembros y planes*.
2. **El modo quiosco nunca arranca solo.** En cada inicio de la app la tableta pregunta *¿Iniciar el modo quiosco?* — confirma y la tableta se bloquea: solo el plano a pantalla completa, botón de atrás desactivado, la app se ancla para que no pueda abrirse nada más; salir del modo quiosco implica reiniciar la tableta. Elige *Ahora no* y la app se abre normalmente — útil para la configuración. La propia designación de quiosco puede revertirse en cualquier momento: en el dispositivo, en **Ajustes → Dispositivo quiosco**, o por el propietario en *Miembros y planes*.
3. Cada miembro lleva una **credencial** — emitida por un admin (*Miembros y planes → Credenciales*) o por el propio miembro (**Ajustes → Mi credencial**, §8): una **credencial QR** imprimible y/o su **tarjeta RFID/NFC**.
4. En el quiosco, toca un puesto (o **Esta planta**) → **Registrarse**, **Reservar** o **Salir**. Para registrarse y reservar viene primero un **paso de periodo** — dices *cuándo* antes de sacar la credencial, **solo hoy** y fiel a la granularidad del espacio: con medias jornadas, fichas **Mañana / Tarde / Día** (una ventana en curso empieza *ahora*, las pasadas se desactivan, tras el horario queda un único *Resto del día*); con granularidades horarias, selectores **Desde/Hasta** ajustados a la cuadrícula — registrarse significa estar ahí, así que su inicio queda fijado en *ahora* y solo se mueve el final. Reservar una ventana ya empezada pregunta además **¿Registrarse ahora mismo?** (activado por defecto — al fin y al cabo estás delante del quiosco): confirmar crea la reserva *ya registrada*, con una sola presentación de la credencial. Después presenta la credencial:
   - **Acerca la tarjeta RFID/NFC.** Mientras el lector de tarjetas está armado, la cámara permanece apagada; si el NFC está desactivado o no existe, la hoja lo dice explícitamente.
   - O toca **Escanear la tarjeta QR** — la tableta lee la credencial impresa **con su propia cámara** (la frontal por defecto, ya que la lente trasera de una tableta de pared mira a la pared; cámbialo en *Ajustes → Escanear con la cámara frontal*). Un lector USB/Bluetooth o escribir el código también funcionan.
5. **Nada ocurre sin tu visto bueno:** el quiosco identifica la credencial, cierra los lectores y muestra un resumen — *a quién* reconoció, *qué* va a pasar, *dónde* y *cuándo*. Solo **Confirmar** ejecuta y actualiza el plano; **Rechazar** descarta.

Tu identidad solo existe durante la operación: la credencial viaja una vez al servidor, la reserva se hace **a tu nombre**, y nada se guarda en la tableta — quedas «desconectado» en cuanto termina. (El acceso puntual con Google sigue en la hoja de ruta; **los iPad no tienen NFC**, así que allí la vía es el QR con la cámara.)

## 11. Facturación (propietarios y admins de facturación)

*Los propietarios emiten facturas; los admins también cuando tienen el permiso **emitir facturas** (Gestión de roles, §8 — o la antigua delegación de función **Los admins emiten facturas**). La función **Facturas** cuelga de Finanzas en la lista de funciones.*

Una factura en DesKilo se genera, nunca se redacta: sus posiciones se **derivan exclusivamente de los datos registrados del mes** — suscripción, exceso, suplementos, servicios, paquetes — menos los pagos y créditos del mes, de modo que la línea final **es el saldo adeudado**. Cada documento captura las direcciones postales del espacio y del miembro (configura la tuya en **Ajustes → Dirección**; la dirección del espacio está en los ajustes del espacio) y se **firma digitalmente** al emitirse — después ya no cambia nunca. Un **anexo detallado** (el libro mayor y la asistencia del mes) puede adjuntarse con un interruptor al emitir.

Quien emite abre **Finanzas → Facturas** y llega a un hub de tres pestañas bajo una franja de resumen en vivo (*N por facturar · N abiertas · X pendiente · N por reembolsar · Y*):

- **Por facturar** — cada miembro cuyo mes anterior tiene datos facturables y aún sin factura, con el total del mes: emite por miembro (con vista previa de las posiciones derivadas) o **Facturar todo** de una pasada — que pide confirmación antes, anunciando el número, el mes y el total. El botón **Nueva factura** abre la misma hoja para cualquier miembro y mes — selector de miembro, ‹ mes ›, las posiciones derivadas, el saldo, el interruptor del **anexo detallado** y **Emitir factura** (un aviso verde *Factura emitida.* confirma). **Una factura activa por miembro y mes** — un mes solo vuelve a ser facturable cuando su factura fue anulada. La hoja de emisión abre en el **mes cerrado** (el momento en que sus números dejan de moverse); si eliges el mes en curso, te avisa, porque ese mes solo puede facturarse una vez.
- **Abiertas** — facturas emitidas a la espera de cobro, las más antiguas primero; lo que lleva más de 30 días esperando se pone en rojo, en la tarjeta y en la franja de resumen. Cada acción es un icono con descripción emergente (anular · proforma · recordatorio · marcar como pagada). **Toca una tarjeta para leer la factura.** **Enviar un recordatorio** registra el recordatorio y comparte el PDF con un mensaje — la tarjeta muestra *Recordado ×N*. **Marcar como errónea** anula la factura para corregirla (un diálogo explícito avisa de que la acción es irreversible): pasa al archivo tachada, y un **reemplazo** vuelve a derivar el mismo mes desde los datos corregidos, referenciando la original. **Marcar como pagada** empareja un pago real (abajo). **Un pago parcial no cierra una factura**: permanece en Abiertas, con la insignia *Parcialmente pagada* y el importe restante, hasta que el saldo pendiente se anule explícitamente **mediante el marco de validación** — un admin/propietario solicita la anulación (con un motivo), los validadores confirman y solo entonces la factura pasa al archivo como *Parcialmente pagada · saldo anulado*. **Una factura NEGATIVA es una nota de crédito (avoir)** — los créditos del mes superaron sus cargos, así que el ESPACIO debe dinero al miembro: su PDF se titula *Nota de crédito*, no recibe recordatorios ni conciliación de pagos del miembro; en su lugar la tarjeta muestra *A reembolsar* con **Registrar el reembolso** — el pago se imputa al saldo del miembro (validado como cualquier liquidación cuando aplica una regla; un rechazo la reabre) y el documento se cierra como *Reembolsada*. La franja de resumen separa las dos direcciones del proceso de pago: *N abiertas · X pendiente* cuenta las facturas positivas por su valor **restante** (una factura de 500 € con 280 € pagados cuenta 220 €), mientras que *N por reembolsar · Y* suma las notas de crédito abiertas que el espacio aún debe.
- **Archivo** — facturas cerradas, filtrables por miembro y mes y ordenables; las facturas anuladas están **ocultas por defecto** — el chip *Mostrar canceladas* recupera la cadena de corrección; la barra bajo los filtros dice cuántas facturas coinciden y **Borrar filtros** devuelve el archivo completo. Cada fila lleva su chip de estado (*Pagada*, *Parcialmente pagada*, *Errónea* tachada, notas de crédito con su importe negativo), su mes y su importe, con **Descargar PDF** ahí mismo. **Toca una fila para abrir la factura** — posiciones, saldo, a quién se facturó, en qué estado está (*Pagada 300,00 € el 6 ago*, *Recordado ×1 · último recordatorio…*, *Anexo: 5 movimientos, 10 registros*), a qué factura sustituye o por cuál fue sustituida, su firma — y cada acción que aún permite, con su nombre: **Vista rápida**, **Descargar PDF**, **Compartir PDF**, exportar la **factura electrónica (XML)**, recordar, marcar como pagada, marcar como errónea, emitir un reemplazo.

**Marcar como pagada significa emparejar un pago real — o aplicar un crédito.** El diálogo lista los pagos registrados del miembro — transferencias anotadas y pagos en línea confirmados — y tú emparejas la factura con uno de ellos; no hay ningún importe que teclear (¿aún no hay pago registrado? el diálogo lo dice: *regístralo o confírmalo primero*). También lista los **créditos en cuenta** del miembro (excedente de nota de crédito): emparejar uno imputa el avoir en la factura, meses pasados incluidos — la alternativa estándar al reembolso en efectivo, tanto para asociaciones como para empresas. Cada crédito se gasta exactamente una vez: uno ya deducido dentro de una factura emitida nunca puede saldar un segundo documento. ¿Pagó **de más**? Crea una **nota de crédito** por el exceso (un abono en la cuenta del miembro) o fuerza la aceptación con una nota obligatoria. ¿Pagó **de menos**? Acéptalo con una nota obligatoria. Todos los que tienen acceso a la facturación reciben aviso de las facturas pagadas, y el propietario puede poner una regla de validación de **Pago de factura** (§7): el emparejamiento espera entonces al quórum — un rechazo reabre la factura.

**Una factura pagada es definitiva.** Una vez emparejada no puede anularse, sustituirse ni alterarse — las correcciones ocurren antes del pago, anulando la factura abierta y emitiendo su reemplazo. Un pago que **no** cubrió el importe completo, aceptado con una nota, aparece como **parcialmente pagada**, no como pagada.

**Proforma.** Ambas pestañas del hub llevan una acción de proforma: en **Por facturar** representa las posiciones derivadas del mes como presupuesto — sin número, sin firma, sellada PROFORMA, y **no se emite nada**; en **Abiertas** vuelve a renderizar la factura emitida como solicitud de pago que no puede pasar por el original. Ambas ofrecen la tríada vista rápida / descargar / compartir.

**Sellos.** Una factura anulada lleva un gran **ERRÓNEA** en diagonal en cada página de su PDF, en gris claro sobre el contenido: no se confunde con un documento válido sobre un escritorio ni en una fotocopia. El mismo sello dice **PROFORMA** en un presupuesto, y **COPIA** en cualquier factura renderizada por alguien que no sea su emisor — el original queda en el espacio.

**Recordatorios (Mahnwesen).** El propietario define las **reglas de recordatorio** (icono de lista de comprobación en la cabecera de Facturas, o *Ajustes del espacio → Reglas de recordatorio*): cuántos niveles, días hasta el primer recordatorio, días entre niveles. Las facturas abiertas vencidas se marcan **«Recordatorio N pendiente»** y la campana de la tarjeta se pone roja — nada se envía nunca automáticamente. El envío genera una **carta de recordatorio de pago** (nivel 1 amistoso, niveles superiores más firmes) a partir de la plantilla de ese nivel — incluida lista para usar en tu idioma, impresa en el idioma del *miembro* y editable por nivel en el editor de informes con los campos extra `{{ reminder_level }}`, `{{ reminder_date }}` y `{{ days_open }}`.

**El registro.** El icono de lista en la barra de Facturas abre un libro con una línea por factura: **fecha · nombre · importe · estado**, ordenado por fecha (toca la cabecera Fecha para invertir el orden), con la suma al pie y un selector de **año** cuando hay más de uno. Su botón de exportación abre la hoja de **Exportación contable**: **SAF-T (XML, internacional)** y — para un espacio francés — **FEC (Francia, exigido en una inspección fiscal)**.

**Entregar el periodo a tu asesoría.** Desde el registro, quien emite exporta un **SAF-T** — el *Standard Audit File for Tax* de la OCDE, el XML que leen los programas de contabilidad y las administraciones tributarias. Cubre exactamente lo que muestra el registro, así que elegir 2026 da el archivo de 2026: la empresa tal como la declaran tus propias facturas, cada cliente, cada factura con sus líneas y totales, y los pagos que las liquidaron. Las facturas anuladas siguen en el archivo marcadas como *anuladas* — un archivo de auditoría nunca borra lo que ocurrió. Lo que deja fuera a propósito es el **plan contable**: DesKilo no inventa números de cuenta, porque un código equivocado hay que descontabilizarlo a mano. Tu asesoría asigna las facturas a sus propias cuentas — es su trabajo y le lleva un minuto.

**Francia: el FEC.** Un espacio francés tiene una segunda opción, el **FEC** (*Fichier des Écritures Comptables*) — el archivo que una inspección exige legalmente (art. L47 A-I du LPF). No es XML: un archivo plano separado por tabuladores, hecho de **asientos** contables, nombrado `<SIREN>FEC<AAAAMMDD>.txt` como exige el arrêté, con las 18 columnas obligatorias en su orden obligatorio. Al estar hecho de asientos *no puede* evitar los números de cuenta, así que la exportación los pide primero — precargados con el *plan comptable général* (411 clients, 706 prestations, 512 banque) y corregibles. Cada factura carga su derecho de cobro contra el ingreso por el importe **bruto**; los créditos que descontó y el pago que la liquidó pasan por banco con su propia fecha, punteados con el número de factura. Las facturas anuladas no aparecen: una anulada antes del pago nunca se contabilizó, así que no hay nada que revertir. La columna del *nombre* sigue a quien lee — quien emite repasa nombres de miembros, un miembro repasa sus propios números de factura. Los miembros solo ven lo que les concierne: las emitidas, y nunca una anulada.

### 11a. Identidad legal, IVA y menciones

**Antes de la primera exportación, completa la identidad legal.** En *Ajustes del espacio → **Identidad legal y facturación electrónica*** el propietario declara:

- El **régimen de IVA** — decide el número que exige la norma EN 16931: fuera del ámbito del IVA, un **número de registro mercantil** (SIREN, HRB, CIF…); con exención por régimen de pequeña empresa, un **número de IVA** más el **motivo por el que no se cobra IVA** (el campo sugiere la mención adecuada — *TVA non applicable, art. 293 B du CGI*, o para servicios a los miembros de una asociación *Exonération de TVA, art. 261, 7-1° du CGI*). El régimen se aplica de extremo a extremo: solo un espacio registrado a efectos de IVA estampa un tipo en una suscripción, un suplemento, un servicio o un paquete, y los selectores de IVA simplemente desaparecen bajo cualquier otro régimen.
- La **dirección** estructurada (calle, código postal, ciudad) junto a la dirección libre del membrete.
- La **plataforma de facturación electrónica** (§11b).
- Las **menciones de facturación**, con un selector de **Tipo de organización** — *Empresa* frente a *Asociación (loi 1901)*: forma jurídica y capital (p. ej. *Association loi 1901*), registro mercantil (empresas: RCS; asociaciones: **RNA W… · SIRET si está asignado**), condiciones de pago, penalización por demora, la **indemnización de cobro de 40 €**, descuento por pronto pago (escompte), seguro profesional, menciones particulares. Cada cláusula vacía imprime el texto legal por defecto — y los documentos de una asociación omiten las cláusulas por defecto solo-B2B (penalización por demora, indemnización de cobro y escompte son obligatorias solo entre profesionales; lo que escribas se sigue imprimiendo).

Los miembros añaden su **país** — y su número de IVA si facturan como empresa — junto a su dirección en *Ajustes → Dirección*. DesKilo lo comprueba todo **antes** de producir una factura electrónica y se niega nombrando lo que falta, porque una factura que una plataforma rechaza es peor que ninguna factura.

**En DesKilo los precios incluyen IVA.** Lo que escribes como precio de suscripción, de servicio o de paquete de días es lo que paga el miembro. Activar el IVA no cambia ni un solo importe adeudado — dice qué parte de ese importe es impuesto. Por eso una factura mensual, un extracto y una cuota no se mueven al añadir tipos, y por eso ningún total hay que cuadrarlo.

**Configurar los tipos.** *Identidad legal y facturación electrónica → **Tipos de IVA***. Una lista vacía significa que el IVA está desactivado, que es como empieza todo espacio. **Usar los tipos habituales** rellena la lista con el tipo general, el intermedio y el reducido de tu país como primer borrador — un punto de partida, no asesoramiento fiscal. Un tipo es el **predeterminado** (la estrella): las suscripciones, los excesos, los suplementos y los ajustes lo usan, igual que todo servicio sin tipo propio. Un servicio y un paquete de días llevan cada uno su propio tipo, elegido en su editor. Quitar un tipo nunca lo borra — el que una factura o un servicio siga usando se conserva, desactivado, para que nada se vuelva a gravar en silencio.

**Qué cambia en un documento.** Una factura emitida después de existir los tipos lleva el desglose tal como se emitió: la tabla de posiciones gana una columna de tipo, y sobre el total el PDF muestra la **base** y una línea por tipo. La **factura electrónica (XML)** lleva lo que exige EN 16931, tanto en UBL como en CII; el **SAF-T** declara cada tipo en su tabla de impuestos; el **FEC** contabiliza el derecho de cobro bruto contra el ingreso neto más una cuenta de **IVA recaudado** (445710 por defecto, y modificable).

**Una factura ya emitida no cambia nunca.** Lleva los tipos, la identidad y los importes con los que se firmó — eso es lo que la hace una factura. Si un documento debe llevar cifras nuevas, márcalo como **erróneo** y emite un **reemplazo**: la cadena de corrección se ve en ambos documentos, que es exactamente lo que quiere ver una inspección.

### 11b. Adónde debe ir la factura electrónica (UE)

La acción **Factura electrónica (XML)** abre una hoja que responde a esto para el país del propio espacio antes de entregarte el archivo: por qué canal la esperan los clientes empresa, si se interpone una plataforma y qué canal usan los compradores públicos. En la Unión coexisten cuatro modelos:

- **Peppol** — un punto de acceso entrega el archivo al cliente; sin plataforma pública de por medio. Así funciona exactamente la obligación B2B belga, y por Peppol se llega a los compradores públicos en toda la UE (la Directiva 2014/55/UE hace que cada administración pueda recibir una factura EN 16931).
- **Plataformas autorizadas** — Francia: eliges una *plateforme agréée* (la PDP renombrada), que transporta la factura y comunica los datos a la administración tributaria. El portal público es un directorio, no un buzón. Las facturas al sector público siguen en **Chorus Pro**.
- **Plataformas de clearance** — Italia (**SdI**, FatturaPA), Polonia (**KSeF**, FA(3)), Rumanía (**RO e-Factura** vía el SPV, CIUS-RO): la plataforma recibe la factura *primero* y luego la reenvía; enviar directamente al cliente no es una opción. Cada una impone su propia sintaxis, así que la hoja advierte de que el archivo EN 16931 que exporta DesKilo no es el que aceptan — úsalo para Peppol, compradores públicos y clientes extranjeros, y deja que tu plataforma o tu asesoría lo convierta.
- **Sin canal impuesto** — Alemania hoy: recibir es obligatorio desde 2025 y emitir llega por fases, pero un adjunto de correo electrónico es una factura electrónica legal; XRechnung y ZUGFeRD son las sintaxis esperadas. Sector público: **OZG-RE / ZRE**, o Peppol.

**Factur-X — un archivo, dos lectores.** La hoja de factura electrónica ofrece primero **Factur-X (PDF)**: un PDF de factura de aspecto normal con la factura legible por máquina *dentro* (los datos EN 16931 en CII, que es lo que impone el formato). Una persona lo abre y ve la factura; una plataforma lo abre y encuentra `factur-x.xml`. Es lo que realmente intercambian la mayoría de las pequeñas empresas francesas y alemanas, y no necesita un segundo archivo. El **XML** suelto sigue disponible debajo, para las plataformas que lo piden desnudo.

**Enviarla sin salir de la app.** El propietario registra la plataforma del espacio en *Identidad legal → **Plataforma de facturación electrónica***: una **URL de subida**, un **token o credencial**, opcionalmente la forma de la **cabecera Authorization** y el **nombre del campo de archivo**. Sirve cualquier plataforma que acepte una subida con credencial — una *plateforme agréée*, un punto de acceso Peppol, una plataforma nacional. El token se guarda en el servidor, nunca vuelve a un teléfono, y la app solo puede decirte que hay uno guardado. Una vez configurada, la hoja de factura electrónica empieza por **Enviar a la plataforma**: el documento Factur-X sale directamente, y la ficha de detalle de la factura registra cuándo salió, qué respondió la plataforma y el identificador que devolvió. Cada intento queda registrado — aceptado, rechazado o no transmitido — porque un documento que *quizá* salió es peor que uno que falló.

**Ensayar sin riesgo.** La misma pantalla admite **puntos de prueba** (el UAT de la plataforma o un destino dev: URL + token cada uno) junto al de producción. Con el **modo desarrollador** del espacio activado (un ajuste de todo el espacio que solo propietarios y admins pueden cambiar, en Ajustes → Avanzado), el envío ofrece elegir el entorno, un envío de prueba queda marcado como tal en el historial de transmisiones de la factura, y el punto de producción nunca se usa para un ensayo — un entorno de prueba sin configurar simplemente se niega en lugar de recurrir al de producción.

DesKilo sigue sin transmitir nada por cuenta propia: produce el documento y lo entrega a la plataforma que elegiste. Los calendarios de obligatoriedad siguen moviéndose: consulta a tu propia administración tributaria antes del plazo que te afecte.

### 11c. El editor de informes — cada documento, cuatro modelos, cinco idiomas

La **Plantilla del PDF de factura** (icono de lápiz en la cabecera de Facturas, o *Ajustes del espacio*) es una herramienta de informes por bandas para cada documento que imprime la app. Tres **bandas** de informe se renderizan en el PDF — cabecera, cuerpo (las líneas de la factura), pie — mientras que el XML de la factura electrónica nunca se toca.

- **Un informe por documento**: los chips cambian entre **Factura · Proforma · Extracto · Acuerdo · Pagos · Espacio · Niveles de recordatorio**. El proforma recae en las bandas de la factura hasta que lo personalices; un extracto personalizado sustituye el PDF mensual integrado.
- **Por idioma**: una segunda fila de chips — *Predeterminado (todos los idiomas)* · EN · FR · DE · ES · IT — guarda una capa de traducción por documento; el informe de un miembro se imprime en *su* idioma cuando existe una plantilla para él, y si no, en el predeterminado del espacio.
- **Marcado o Visual**: el modo **Marcado** edita las bandas como texto — condiciones y bucles [Liquid](https://shopify.github.io/liquid/) (`{{ number }}`, `{% if proforma %}…{% endif %}`, `{% for line in lines %}…{% endfor %}`) más un marcado de líneas sencillo: `#` título, `##` sección, `>` letra pequeña, `---` separador, `a | b` fila de tabla, `=` fila en negrita, `::: … ||| … :::` columnas lado a lado (el bloque de direcciones vendedor-izquierda / cliente-derecha y los totales alineados a la derecha de una facture francesa — las plantillas incluidas siguen exactamente esa estructura), `![name]` una imagen de la **biblioteca de imágenes** del espacio (*Insertar una imagen*). El modo **Visual** muestra las mismas bandas como superficie de diseño — filas con estilo, `{{ tokens }}` resaltados, toca una línea para editarla en el sitio, añade líneas, muévelas, inserta campos de datos desde una paleta.
- **Galería de plantillas** (*Plantillas*): cuatro modelos listos para cada documento — **Clásico · Sencillo · Detallado · Carta formal** — elige uno y extiéndelo. Cada modelo de factura ya lleva las menciones obligatorias (§11a).
- La **Vista rápida** renderiza el resultado al instante en la app — tu factura más reciente, o datos de ejemplo simulados si no existe ninguna (con marca de agua *datos de ejemplo*) — sin pasar por un PDF; **Vista previa** produce el PDF; **Restablecer al modelo por defecto** devuelve el diseño integrado como ejemplo funcional. Una plantilla rota nunca bloquea un documento — el diseño integrado toma el relevo; la marca de agua de anulación, la firma digital, el anexo y los números de página quedan fijos.

Variables de plantilla (familia de facturas): `{{ number }}`, `{{ member }}`, `{{ workspace }}`, `{{ workspace_address }}`, `{{ period }}`, `{{ issued }}`, `{{ issued_by }}`, `{{ replaces }}`, `{{ total }}`, `{{ charges }}`, `{{ payments }}`, `{{ voided }}`, `{{ proforma }}`, `{{ copy }}`, `{{ lines }}` (cada una con `label`, `unit_price`, `qty`, `net`, `vat_rate`, `amount`), `{{ has_vat }}`, `{{ vat }}`, `{{ net_total }}`, `{{ vat_total }}`, `{{ credit_note }}`, `{{ refund_total }}` — y el juego legal: `{{ seller_legal_form }}`, `{{ seller_registration }}`, `{{ seller_vat_id }}`, `{{ seller_legal_id }}`, `{{ exemption_reason }}`, `{{ client_address }}`, `{{ client_vat_id }}`, `{{ client_legal_id }}`, `{{ payment_terms }}`, `{{ late_penalty }}`, `{{ recovery_indemnity }}`, `{{ escompte }}`, `{{ insurance }}`, `{{ special_mentions }}`.

### 11d. La suite de informes y la biblioteca de documentos

- **Acuerdo financiero** — cada precio vigente que se aplica a un miembro: suscripción, media jornada extra, servicios, paquetes, suplementos de espacios enteros y de accesorios. Propietarios y admins lo envían desde la ficha de acciones de un miembro; cada miembro puede ver/descargar/compartir el suyo en *Finanzas → Documentos*.
- **Informe de pagos** — todo lo que pagaste, declaraste o te validaron en un mes: tu pequeño balance, en autoservicio en la misma fila.
- **Informe del espacio** — identidad, recuentos del plano, disponibilidad, funciones y precios: *Ajustes del espacio → Informe del espacio*.
- **Biblioteca de documentos** — *Ajustes → Documentos*: los estatutos, guías de usuario, estados financieros y actas del espacio, ENLAZADOS desde el sistema que ya uses — Google Drive, OneDrive, SharePoint, Dropbox, Nextcloud o cualquier enlace https (el drive sigue gestionando sus propios accesos; la app nunca guarda credenciales ajenas). Cada entrada tiene un **rol de visibilidad**: todos los miembros, admins y propietarios, o solo propietarios — aplicado en el servidor, de modo que un miembro ni siquiera descarga una lista que contenga documentos de la junta. Los admins y propietarios la gestionan con el botón +; un interruptor de función *Biblioteca de documentos* activa todo el conjunto.

## 12. Ajustes y perfil

Tu pantalla personal, de arriba abajo:

- **Perfiles** (§1) y tu **foto** (tócala para cambiarla — elegir o quitar).
- **Miembros** — un acceso directo al directorio; **WhatsApp** — tu número, visible para los demás miembros solo si lo defines; **Estado** — una línea libre (40 caracteres) mostrada en el directorio; **Dirección** — tu dirección postal (impresa en tus facturas), país y número de IVA opcional.
- **Ayuda** — la guía integrada, en tu idioma; **Mi credencial** (§8); **Cuentas vinculadas** — vincula un acceso con Google a tu cuenta de correo; **Documentos** — la biblioteca de documentos del espacio (§11d).
- **Preferencias** — **Idioma** (el del sistema o uno de cinco), **Tema** (sistema / claro / oscuro), **Escanear con la cámara frontal** (para tabletas de pared).
- **Avanzado** — el estado de notificaciones push de este dispositivo, el interruptor del **Modo desarrollador** de todo el espacio y la pantalla de trazas **Desarrollador** (§8 pagos).
- **Cerrar sesión**.

## 13. Notificaciones

Recordatorios de registro, confirmaciones pendientes, decisiones de gastos — y cuando un admin **elimina una de tus reservas** (anulación), tú y los admins recibís aviso. La entrega es local primero; los push del servidor llegan de serie en Android, iPhone/iPad, el navegador y macOS (Firebase Cloud Messaging) — *Ajustes → Avanzado* muestra si el push está activo en este dispositivo. La insignia del icono de la app muestra tus confirmaciones pendientes **más tus mensajes sin leer** — en Android, iPhone/iPad, el Dock de macOS, la barra de tareas de Windows y las web apps instaladas. Los mensajes entre miembros se anuncian **una vez por dispositivo con el remitente y el texto completo** — incluido lo enviado con la app cerrada, anunciado en cuanto la vuelves a abrir. Los payloads push nunca llevan nombres ni horas; la app compone el texto de la notificación localmente.

## 14. Privacidad

Datos mínimos: nombre, correo, plan, reservas, cuenta. Tú controlas tu foto, tu estado, si tu nombre aparece en el plano y si tu número de teléfono es visible en el directorio. Las credenciales de quiosco se guardan solo como hash — una credencial perdida se revoca, no se adivina. Sin rastreo, sin analítica de terceros. El historial financiero se anonimiza, no se borra, al eliminar la cuenta (retención contable).

## 15. Plataformas

Android (Google Play), iPhone/iPad, escritorio — **macOS** (un DMG: arrastra DesKilo a Aplicaciones) y **Windows** (un instalador MSI) generados en cada versión — y el **navegador**: la misma app, sin instalar nada, en la dirección que publique tu espacio. Tus datos siguen a tu cuenta, así que un puesto reservado en el móvil aparece un segundo después en una pestaña del navegador.

Lo que el navegador no puede hacer es lo que a una página no se le permite: leer una credencial NFC o escanear un QR con la cámara como hace el quiosco. Todo lo demás — plano, reservas, miembros, dinero, facturas, descargas de PDF — es la misma app. Al abrir el DMG de macOS por primera vez, haz clic derecho sobre la app y elige *Abrir*: la compilación aún no está notarizada por Apple, así que un doble clic normal muestra un aviso de Gatekeeper.
