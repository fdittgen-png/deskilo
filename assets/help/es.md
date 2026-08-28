# Guía de usuario

Todo lo que un miembro, admin o propietario necesita para usar DesKilo.

> Las capturas de pantalla de esta guía muestran la app en francés — cada pantalla existe idéntica en los cinco idiomas (English, Français, Deutsch, Español, Italiano); cambia el idioma en **Ajustes → Idioma**.

![](assets/help/images/settings-language.jpg)

## 1. Primeros pasos

### Crear una cuenta

Abre la app y regístrate con tu correo, una contraseña (mínimo 8 caracteres) y un nombre visible — o **continúa con Google**. El botón del ojo muestra u oculta la contraseña mientras escribes. *¿Olvidaste la contraseña?* te envía por correo un **código numérico de un solo uso**, que tecleas de vuelta en la app junto con tu nueva contraseña — deliberadamente un código y no un enlace, para que el restablecimiento funcione también allí donde los enlaces profundos no llegan. Un acceso con Google puede vincularse más tarde a una cuenta de correo existente en **Ajustes → Cuentas vinculadas**.

### Crear un espacio — o unirse a uno

Tras iniciar sesión llegas a la pantalla de bienvenida con dos caminos:

- **Crear un espacio** — te conviertes en su **propietario**. Elige nombre, país (determina la moneda por defecto) y zona horaria. Después dibujarás tu plano en el editor (§8).
- **Unirse a un espacio** — escribe el **ID del espacio** que te compartieron, o toca **Escanear código QR** y apunta la cámara al QR de invitación colgado en la pared de tu espacio. Tu solicitud llega como **pendiente**: *Nuevo miembro* es uno de los dominios de validación (§7), así que un validador te da paso, y a partir de ahí tienes exactamente el rol que lleva la invitación (§2).

### Perfiles — una cuenta, varios espacios

Una cuenta puede pertenecer a varios espacios. **Ajustes → Perfiles** los lista todos: cada fila muestra el nombre del espacio, **tu rol allí** (Miembro, Admin, Propietario) y su ID de espacio. La **marca de verificación** señala el perfil en el que estás ahora; la **estrella** marca tu perfil **predeterminado** — aquel con el que se abre la app, en cualquier dispositivo e incluso tras reinstalar (la elección se guarda con tu cuenta). Toca una fila para cambiar, **+ Añadir un perfil** para unirte a otro espacio más. Todo en la app se refiere al espacio activo.

### Orientarse

La app tiene hasta cinco destinos en la barra inferior: **Plano** (§3), **Calendario** (§5), el gran botón central **Reservar** (§4), **Miembros** (§6) y **Finanzas** (§9). Solo Plano y Reservar están siempre: Calendario, Miembros y Finanzas van y vienen con su función (§8), y lo mismo la **campana** que abre el hilo de eventos y confirmaciones (§7, con una insignia que cuenta lo que te espera). El **engranaje** que abre los **Ajustes** (§12) sí está en todas las cabeceras. Con el teléfono en horizontal y en tabletas, la mayoría de las pantallas pasan a un **diseño dividido** — controles en un panel lateral, contenido llenando el resto.

**Todo se mantiene en vivo.** Lo que cualquiera cambie — una reserva, un miembro nuevo, un ajuste — se envía en segundos a cada dispositivo conectado, incluido el que hizo el cambio. Sin reiniciar, sin tirar para actualizar.

## 2. Roles e invitaciones

DesKilo tiene tres roles acumulativos y, encima de ellos, una variante de copropiedad, más una cuenta de dispositivo:

| Rol | Puede |
|---|---|
| **Miembro** | Registrar entrada/salida, reservar, presentar gastos, ver y gestionar sus propios eventos y su propia cuenta |
| **Admin** | Todo lo de un miembro, más: actuar *por cualquiera* (reservas, pagos, gastos — sujeto a confirmación, §7), aprobar gastos, emitir credenciales de quiosco |
| **Propietario** | Todo lo de un admin, más: editar el espacio físico, definir planes y precios, gestionar roles, dispositivos quiosco y ajustes del espacio |
| **Copropietario** | *Activo*: los permisos del propietario de inmediato, más la sucesión automática. *Pasivo*: un sucesor en espera, sin permisos adicionales hoy |
| **Quiosco** | Una cuenta de tableta de pared (§10) — solo muestra el plano; los miembros reales actúan a través de ella con una credencial |

Parte de esto no está grabada en piedra: el propietario reajusta **nueve permisos de administración** en la matriz de **Gestión de roles** (§8) — gestionar roles, gestionar miembros, políticas de validación, configuración del espacio, emitir facturas, ver finanzas, documentos, servicios, aprobar gastos. Lo que la matriz *no* gobierna es lo cotidiano — registrarse, reservar, actuar por otro miembro, editar el espacio —, que se queda donde lo pone la tabla de arriba, condicionado en cambio por las funciones y por los interruptores de cada miembro.

**Cada invitación está ligada a un rol.** En la pantalla *ID del espacio y QR* del propietario, dos pestañas guardan dos invitaciones, cada una con su propio código QR y su propio código:

- **Invitación de miembro** — el propio ID del espacio, mostrado bajo el nombre del espacio. Imprímelo, cuélgalo en la pared, compártelo libremente: quien lo escanee o escriba **pide** unirse como miembro normal, y un validador lo admite (§7). Botones: **Copiar ID**, **Compartir como PNG**, **Cambiar el ID del espacio** (sustituye el ID generado por uno memorable, 4–20 letras/dígitos) e **Invitar a alguien**.
- **Invitación de admin** — un **código personal de un solo uso**, emitido por un propietario para una persona concreta. La pantalla lo dice claramente: *este código admite a UNA persona como admin y luego caduca* (un código sin usar expira a los 14 días). Entrégalo solo a la persona a la que está destinado; emite uno nuevo por admin con **Nuevo código de admin**.
- **Las invitaciones hablan el idioma del invitado** — la hoja de invitación redacta el mensaje en el idioma que elijas (cinco disponibles), por defecto el **idioma del espacio** definido en los *Ajustes del espacio*. El propietario también puede personalizar allí el texto de la invitación **por idioma**, con marcadores como `{firstName}`, `{workspaceName}`, `{inviteLink}`, `{downloadUrl}`, `{role}`; un idioma dejado vacío usa el mensaje integrado traducido.

**No existe invitación de propietario — a propósito** (el pie de la pantalla te lo recuerda). La propiedad solo puede otorgarla un propietario existente, en *Miembros y planes*. Un espacio conserva siempre al menos un propietario. Promover o degradar un **admin** pasa por el flujo de validación (§7) — se aplica cuando los validadores del espacio confirman.

**Los copropietarios mantienen vivo el espacio.** El propietario nombra copropietario a cualquier miembro o admin (*Miembros y planes → el miembro → Copropiedad*), en una de dos variantes: un copropietario **activo** trabaja con los permisos del propietario de inmediato; un copropietario **pasivo** no tiene permisos adicionales hasta el día en que hagan falta. En ambos casos, la sucesión es automática: si el último propietario se va — sale, es eliminado o su cuenta desaparece — el mejor copropietario (activo antes que pasivo) **se convierte en propietario al instante**, en el servidor, sin que haga falta ninguna acción. El propietario también puede ceder el mando deliberadamente en cualquier momento con *Promover a propietario ahora*. Un matiz: las reglas de validación que exigen la firma del *propietario* (§7) se refieren siempre a un propietario literal, no a un copropietario activo.

El QR codifica un enlace que nombra el rol otorgado (`deskilo://join?role=…`). Manipular el enlace no cambia nada — el servidor deriva el rol del propio código: el ID del espacio siempre une como miembro, y una invitación personal une exactamente en el rol con el que se emitió, una sola vez. Un código de admin reenviado ya usado — o caducado — no admite a nadie.

**Invitar por mensaje** (*Invitar a alguien*): cada envío por WhatsApp/SMS/compartir emite su propio código personal de un solo uso y compone un mensaje listo en el idioma del invitado. El destinatario puede simplemente copiar el mensaje completo y pegarlo en el campo de unión de la app — el código se detecta automáticamente.

## 3. El plano (en el hub Reservar)

El plano muestra la planta activa de tu espacio: oficinas, mesas y puestos, con código de colores — **libre**, **reservado**, **ocupado**, **mío**, **bloqueado**. Se abre **al instante con los últimos datos conocidos** y se actualiza en segundo plano — con un Wi-Fi inestable sigues viendo el estado más reciente en lugar de una pantalla vacía. Un puesto ocupado muestra a quien está con su **inicial** — o con su **foto**, cuando la ha puesto y el propietario activó *Fotos de los miembros en el plano* —, con una **insignia de registro** cuando ha hecho check-in y un **punto verde** cuando está en línea en la app en ese momento. Los nombres de pila aparecen donde hay sitio para ellos: en la ficha con candado de una reserva de espacio entero y en la vista de lista. Cuando una **mesa, sala o planta entera** está reservada, el propio espacio lo dice — un lavado de color, un borde marcado y una **ficha con candado y el nombre del ocupante** en el centro (un glifo de registro cuando ya está allí); la etiqueta de la sala se lee *Bureau 2 · Florian*. Lo ven todos los usuarios, en el plano, en el hub Reservar y en el quiosco.

El plano puede parecerse a tu espacio real: el propietario puede poner una **foto de la sala como fondo de la planta** y colocar libremente **imágenes de ilustración redimensionables** (plantas, sofás…) sobre la cuadrícula. Un control de **transparencia de mesas** en los ajustes del espacio deja ver la foto a través de las mesas dibujadas.

Moverse:

- A lo largo del borde superior: un conmutador **mapa / lista** (la lista muestra los mismos puestos como filas), el **chip de fecha** (tócalo para navegar a otro día) y los controles de ventana, que siguen la granularidad de tu espacio (§8): tres **chips de franja** — mañana, tarde, día completo — donde el espacio reserva por medias jornadas; solo *Día completo* donde reserva por jornadas enteras; controles **de → a** sobre una rejilla de minutos o un rango horario libre; y ambos a la vez con *horas reales*.
- El lienzo **se ajusta solo** a tu planta al abrir o al girar el dispositivo; **pellizca para hacer zoom** o usa los botones **+ / −**, arrastra las **barras de desplazamiento** en los bordes y toca el botón de **ajuste** para recentrar.
- Elige la planta en la **barra de plantas** a la derecha (1, 2, …); su **icono de capas** actúa sobre la planta entera (abajo). En **horizontal**, los controles pasan a un panel lateral y el plano llena la pantalla — útil en tabletas.

Reservar desde el plano:

- **Registro espontáneo**: toca un puesto libre → la hoja propone *ahora* hasta un borde canónico → confirma. Con medias jornadas y jornadas completas, el servidor **retrasa después el inicio hasta el tramo al que pertenece**: llegas a las 10:00, confirmas *hasta las 12:00* y reservas — y consumes — toda la mañana de 8:00–12:00 (§4b). Si alguien reservó ese puesto más tarde, tu hora de fin se recorta y se te avisa.
- **Registro sobre reserva**: registrarse significa *estás aquí*. Con medias jornadas, jornadas completas y horas reales, **cualquier llegada el propio día de la reserva** abre la ventana: a las 10:00 ya puedes registrarte en tu tarde de las 12:00. Con una rejilla de minutos, la ventana abre 15 minutos antes de tu inicio, o un paso de rejilla antes cuando ese paso es más largo (así las rejillas de 5 y 15 minutos conservan los 15 minutos, y una rejilla horaria abre una hora antes). Se cierra al final de la reserva; fuera de ella el botón está desactivado y dice cuándo abre. Los admins pueden registrar a un miembro presente en su puesto (mientras *reservar para otros* esté activo).
- **Salida**: manual — y **recorta la reserva a ahora**, así que el puesto se libera de inmediato para los demás. Es **personal por defecto**: un admin (incluido el propietario) solo puede terminar el registro de otra persona si **Los administradores pueden hacer el check-out de los miembros** está activado (§8). Con la **entrada/salida automática** activada, las reservas olvidadas se cierran solas — el barrido corre en cada lectura, así que una reserva de mañana que quedó abierta se completa en su propio fin a partir de las 12:01, no a medianoche.
- **Espacios enteros**: **doble toque** en una mesa, una sala o una zona libre del suelo — o toca el **icono de capas** de la barra de plantas — para actuar sobre la **mesa, oficina o planta entera**. **Una sola hoja** lo contiene todo: el nombre del espacio, el selector de periodo (p. ej. *jue 6 ago 10:13 → 12:00*) con las mismas opciones de repetición que un puesto, un selector opcional **Para el miembro** para los admins que reservan por cuenta de otro, y el botón de confirmación.
- **Línea de tiempo**: elige una ventana de→a (o Mañana / Tarde / Día completo, según la granularidad del espacio) para ver la ocupación en cualquier momento futuro.
- Los puestos pueden llevar **accesorios** (monitor, mesa elevable…), algunos con suplemento por media jornada que aparece en tu extracto.
- Las reservas cuentan contra tus **días mensuales** (§9) — pasado tu plan, la app bloquea o cobra, según lo que el propietario configuró para ti. Una excepción: una reserva situada **enteramente fuera del horario laboral** puede ser gratuita o quedar exenta, según la política de fuera de horario del espacio (§4b).

## 4. Reservas (hub Reservar)

Abre el hub **Reservar** (botón central). A lo largo del borde superior: dos filas de controles. La primera dice **qué** está mirando: los cuatro **botones de vista** y, en el plano, el selector **plano / lista**. La segunda dice **cuándo**: el **chip de fecha**, un botón **Ahora** en cuanto se aleja de hoy, y los **chips de franja** (mañana / tarde / día completo). Los **chips de planta** (*Todas las plantas*, o uno por planta) están sobre el propio plano, y el **botón de escaneo QR** (§4a) está en la barra superior, junto al editor y la campana. Después, cuatro vistas:

- **Plano** — el plano filtrado a tu ventana elegida; toca un puesto libre para reservarlo.
- **Día** — cada puesto como fila de cronología del día elegido (08:00 → 17:00 o el horario de tu espacio, la línea roja marca *ahora*); toca un tramo libre para reservar, tu propio bloque para ver sus detalles.
- **Semana** — una cuadrícula puesto × día de toda la semana ISO, con una banda de días (*lun 3 … dom 9*) encima; cada celda contiene las medias jornadas del día con la inicial del ocupante. Encuentra una media jornada libre de un vistazo y tócala para reservar.
- **Mes** — un calendario de disponibilidad: cada día muestra su **recuento de mesas libres** (p. ej. *10/12*); toca un día para entrar en su vista Día.

**Un sitio a la vez — por defecto**: el espacio fija cuántas reservas superpuestas puede mantener un miembro, y ese número es **1** mientras el propietario no lo suba (§8). Con 1, reservar o registrarte en otro sitio mientras corre otra se rechaza; en cualquier caso, registrarse cierra cualquier registro anterior cuya reserva ya terminó. Los admins y propietarios pueden **anular**: tocar un puesto ocupado o reservado ofrece *Quitar la reserva (anular)* — la reserva se elimina y el miembro y todos los admins reciben aviso por el hilo de eventos.

Las reservas siguen la **regla de granularidad** del espacio (§8 Disponibilidad) — medias jornadas, días completos, horas reales (de–a exacto, con las ventanas de media jornada y jornada como atajos) u horas de inicio/fin libres sobre la rejilla de tramos del propietario. Las medias jornadas y jornadas completas cubren el **horario laboral** configurado del espacio (por defecto 8:00–17:00 con el límite de media jornada a las 12:00). Respetan los **días de apertura** y los **días de cierre**, y las reglas de reserva (horizonte de antelación, duración mínima y máxima). **Una reserva termina siempre el día en que empieza** — nada cruza la medianoche; una estancia que sigue mañana es la reserva de mañana, hecha mañana (§4b). ¿Necesidad recurrente? Reserva una **serie** (diaria, laborables, semanal) — los días cerrados y los conflictos se saltan y se informan.

**Eliminar una reserva pasada o registrada es una solicitud, no una acción.** Una reserva cuyo inicio ya pasó — o donde ya te registraste — no se cancela directamente: la hoja ofrece en su lugar **Solicitar eliminación**. Un propietario o admin decide la única pregunta que importa para la facturación: ¿se olvidó simplemente el registro (la reserva se mantiene en el historial) o nunca se usó (se elimina)? La solicitud aparece en el hilo de Eventos con tu motivo opcional; las reservas futuras sin tocar conservan la cancelación normal de un toque. Todo este camino depende de la función **Solicitudes de eliminación de reservas**: desactivada, una reserva empezada o registrada no tiene ni botón de cancelar ni solicitud — simplemente se queda en el historial.

### 4a. Escanear un código de espacio

Cada puesto, mesa, oficina y planta puede llevar una **tarjeta QR** impresa (§8). Toca el **botón de escaneo** en el hub Reservar, apunta la cámara a la tarjeta — o escribe su código — y la app identifica el espacio y muestra exactamente lo que *tú* puedes hacer allí:

- **Tarjeta de puesto** — reserva o regístrate en ese puesto concreto, al momento (la ventana de hoy: mañana / tarde / día completo donde el espacio usa medias jornadas; si no, desde ahora para las próximas horas).
- **Tarjeta de mesa** — los puestos de la mesa con su estado en vivo; elige uno libre. Una mesa que el propietario marcó como reservable ofrece además la **mesa entera**, con su precio por media jornada, exactamente igual que una tarjeta de oficina o de planta.
- **Tarjeta de oficina o planta** — si el propietario la hizo reservable, la función *Reservas de mesa, oficina y planta* está activada **y** tienes el derecho personal (§8) — los propietarios y admins siempre lo tienen — puedes reservar o registrarte en la **oficina o planta entera** — con el mismo selector de periodo (mañana / tarde / día completo, u horas libres) y las mismas opciones de **serie** que un puesto; se muestra su precio por media jornada y entra en tu factura. Si no, la hoja te dice por qué, y una oficina recae en sus puestos.

**Un escaneo abre la hoja del quiosco.** Leer el código de un **puesto** — su tarjeta QR impresa, o la etiqueta NFC pegada en la silla — ofrece exactamente lo que ofrece el quiosco al tocar ese puesto: las mismas tres acciones (**Registrarse**, **Reservar**, **Salir**) y el mismo periodo derivado de los ajustes del espacio. La única diferencia: ya has iniciado sesión, así que no hay paso de credencial (§4b). Las tarjetas de mesa, oficina y planta abren su propia hoja de espacio entero, como se describe arriba; y las **etiquetas NFC solo resuelven puestos**, así que la etiqueta de la silla es el único atajo de tocar y reservar.

**Los conflictos protegen en ambos sentidos:** una oficina o planta no puede reservarse mientras algún puesto de su interior ya esté reservado en esa ventana — y ningún puesto puede reservarse mientras su oficina o planta esté reservada entera.

### 4b. Cómo se comporta la reserva

Cada regla de abajo se aplica **en el servidor**, en un único sitio compartido al que llama toda vía de reserva. Todas las horas son locales del espacio; los ejemplos asumen la jornada laboral por defecto (08:00 – 12:00 – 17:00).

**Reservar con antelación.** La forma posible de una ventana depende de la granularidad del espacio (§8 Disponibilidad):

| Pides | Medias jornadas | Jornadas completas | Rejilla de minutos (5/15/30/60 min) | Horas reales / rango horario libre |
|---|---|---|---|---|
| La mañana (8–12) | ✅ | ❌ — debe cubrir el día completo | ✅ si los bordes caen en la rejilla | ✅ |
| La tarde (12–17) | ✅ | ❌ | ✅ | ✅ |
| Toda la jornada laboral (8–17) | ✅ | ✅ | ✅ | ✅ |
| Una ventana atípica (9–15) | ❌ | ❌ | ✅ si cae en la rejilla | ✅ |
| Antes de abrir / fuera de horario (un inicio a las 6:00, 17–21) | solo como llegada espontánea | solo como llegada espontánea | ✅ — las rejillas son libres | ✅ |
| Fuera de la rejilla (10:02) | — | — | ❌ — el rechazo nombra la rejilla | — |

Esa última fila es la única que una granularidad puede descartar por su propia forma; todo lo demás sobre una ventana lo deciden reglas que valen **en todas las granularidades por igual**:

- El futuro está abierto hasta el **horizonte de reserva** (90 días por defecto) y rechazado más allá.
- La **duración mínima y máxima** rige en todas partes, no solo en las rejillas: con el mínimo por defecto de 30 minutos, una llegada espontánea de media jornada iniciada a las 11:45 para el límite de las 12:00 se rechaza por demasiado corta — llega antes, o toma la tarde.
- **Una reserva termina el día en que empieza.** Ninguna ventana puede cruzar la medianoche, sea cual sea la granularidad: una tarde que se alarga se convierte en la reserva de mañana, creada mañana. El rechazo dice *«una reserva termina el día en que empieza»*. La llegada espontánea vespertina que corre hasta la **medianoche local** sigue siendo válida — la medianoche es el fin propio de ese día, no un cruce. Mantener cada reserva dentro de un solo día es lo que permite responder a la ocupación, la cuota y la factura de cada día con ese día solo.
- Una reserva en un **día ya terminado** (ayer y antes) se rechaza — *«completamente en el pasado»* — salvo que el propietario haya activado **Permitir reservas pasadas**. Reservar la ventana de esta mañana más tarde el mismo día funciona siempre.
- Un **check-in espontáneo debe empezar hoy**: crear una reserva ya registrada para mañana se rechaza.
- Un **día de cierre** rechaza nombrándose; un puesto ocupado rechaza; y un miembro solo mantiene tantas reservas **superpuestas** como le permita su cupo (abajo).
- La política **Fuera del horario de apertura** (§8) decide cuánto vale una ventana que se sale de la jornada laboral, o si puede existir siquiera (abajo).

Todo ello se aplica en **un único sitio compartido del servidor**, y por eso el plano, el hub Reservar, un escaneo QR o NFC y el quiosco de pared ofrecen exactamente lo que será aceptado, y por eso el quiosco rechaza justo lo que rechaza el plano — no existe el camino del «pero el quiosco me dejó». Una petición que se cuele por una pantalla desfasada se rechaza con el motivo nombrado.

**Cuántos sitios a la vez.** El espacio fija un número de **reservas simultáneas** (§8); vale **1** por defecto — exactamente el histórico un sitio a la vez. Un propietario o un admin puede conceder a un miembro concreto un cupo mayor en *Miembros y planes*, y ese permiso personal prevalece sobre el número del espacio; nadie fija el suyo propio. El mismo cupo gobierna los **registros**: quien tiene 2 sitios permitidos puede estar registrado en 2 sitios a la vez. Alcanzar el cupo rechaza con el mensaje de siempre — *ya tienes una reserva en ese periodo*, o *ya estás registrado en otro sitio*.

**Fuera del horario de apertura.** Una ventana que se sale de la jornada laboral — una mañana temprana de 6:00–8:00, una tarde de 17:00–21:00, la llegada espontánea que corre hasta la medianoche local — se rige por una única política del espacio con **cuatro** respuestas mutuamente excluyentes (§8), las mismas en todas las granularidades.

| Posición | Una reserva (o un registro espontáneo) fuera de horario |
|---|---|
| **Prohibido** | ❌ rechazada en todas las granularidades — incluida la prórroga vespertina que las granularidades por jornadas permiten siempre, e incluida una reserva que simplemente **se pasa** del fin de la jornada (16:00–20:00) o empieza antes de abrir |
| **Solo espontáneo** | ✅ el registro espontáneo, en **cualquiera de los dos extremos del día** — la llegada temprana de las 6:00 tanto como la prórroga vespertina hasta medianoche — ❌ reservar esa ventana **por adelantado**, y ❌ una reserva que se pasa del fin de la jornada |
| **Gratis** | ✅ permitida, pero nunca contada ni facturada: la reserva es pura información — los demás ven que el espacio está ocupado, y un registro dice dónde encontrar a la persona |
| **De pago** (el defecto) | ✅ permitida y contada como uso ordinario — **salvo** un día en el que ya mantienes una reserva normal dentro del horario: la parte de fuera viaja entonces gratis |

Esa exención es la razón de ser del defecto: corta el «reservar solo fuera de horario para no pagar» sin cobrar dos veces a quien ya consumió su día. Dos precisiones. **Gratis y De pago solo miran las ventanas situadas *enteramente* fuera del horario**: una reserva que toca el horario laboral, aunque sea un minuto, es una reserva ordinaria y contada. **Prohibido y Solo espontáneo rechazan más ampliamente**: rechazan también la ventana que se pasa, porque un espacio que cierra a las 17:00 no tiene por qué estar reservado hasta las 18:00. En *Solo espontáneo* fue a parar el retirado interruptor **Reservas por minutos dentro del horario laboral** — la misma idea, ahora en todas las granularidades. Un espacio que aún arrastra el antiguo interruptor se lee como *Solo espontáneo*, con una mejora deliberada: el interruptor viejo solo dejaba pasar la llegada *vespertina*, mientras que un modo que se llama «espontáneo» no tiene por qué rechazar a quien llega a las 6:00. Lo que rechaza es reservar por adelantado; para lo que existe es para entrar sin más. Las reglas de forma de cada granularidad siguen aplicándose encima, así que esto no abre ninguna ventana arbitraria.

**Las llegadas espontáneas encajan en el tramo.** Una llegada espontánea (tocar un puesto libre, escanear su QR/NFC, o el quiosco) reserva desde *ahora* hasta un borde canónico — el límite de media jornada, el fin del día o un borde de la rejilla. Con granularidad por jornadas, la reserva cubre el **tramo entero al que pertenece el fin**: llegar a las 10:00 y elegir *hasta las 12:00* reserva toda la mañana de 8:00–12:00; cuando la ventana retrasada resulta no estar disponible — la reserva de otra persona, una tuya que se solapa, un puesto bloqueado, una mesa, oficina o planta entera ya tomada — la reserva se ancla entonces en tu llegada y conserva el fin del tramo. Al final de la jornada laboral o después, una llegada espontánea puede correr hasta la **medianoche local** (horas extra vespertinas — en todas las granularidades, salvo que **Fuera del horario de apertura** esté en *Prohibido*, la única política que las rechaza); y ahí se detiene, porque una reserva termina el día en que empieza. Y un check-in espontáneo debe empezar **hoy**: crear una reserva «registrada» para mañana se rechaza.

**Un escaneo se comporta como el quiosco.** Escanear un **puesto** — su tarjeta QR impresa o la etiqueta NFC de la silla — abre la misma hoja que abre el quiosco al tocar ese puesto: **Registrarse**, **Reservar** o **Salir**, sobre los mismos periodos derivados de los ajustes del espacio, sin el paso de la credencial, porque ya has iniciado sesión. (Las tarjetas QR de mesa, oficina y planta abren en cambio la hoja de espacio entero, §4a; las etiquetas NFC solo resuelven puestos.) A partir de ahí decide el espacio:

| Lo que escaneas | Lo que hace la hoja |
|---|---|
| Un espacio en el que mantienes una reserva | continúa con el registro de **esa** reserva |
| Un espacio libre | el registro lo reserva implícitamente, encajado en el tramo como toda llegada espontánea |
| Un espacio bloqueado por la reserva de otra persona | nombra al titular y ofrece **Escribirle** — la conversación se abre con la reserva que bloquea referenciada |

La misma acción *escribir al titular* está en la pestaña **Plano** cuando tocas un puesto que ocupa otra persona. En el quiosco, en cambio, el recibo nombra al titular y te remite a la app: un dispositivo de pared nunca envía mensajes por ti.

**Registrarse (check-in).** Con medias jornadas, jornadas completas y horas reales, la ventana abre para **todo el día reservado**: a las 10:00 ya puedes registrarte en tu tarde de las 12:00, porque el tramo *es* la jornada laboral. Con una rejilla de minutos abre **15 minutos antes** de tu inicio — o un **paso de rejilla** antes cuando ese paso es más largo, así que las rejillas de 5, 15 y 30 minutos conservan los 15 minutos y una rejilla horaria abre una hora entera antes. La hoja lee siempre el reloj real, de modo que navegar una fecha futura nunca esconde el registro de hoy en tu propia reserva. Registrarse otro día («la reserva de mañana hoy»), después de terminar la reserva, dos veces, o en un día de cierre se rechaza con el motivo. Si sigues registrado **en otro sitio**: una reserva aún en curso lo bloquea en cuanto has alcanzado tu cupo (1 por defecto, así que la primera reserva en curso ya bloquea — *haz allí primero el check-out*); una ya terminada se cierra en silencio — sellada en su propio fin — y el nuevo registro procede. Un admin puede registrar a un miembro mientras *Reservar para otros* esté activo (§8 Funcionalidades).

**Salir (check-out).** Salir antes del fin reservado **recorta la reserva a ahora** — el puesto se libera inmediatamente para los demás. Tras un registro anticipado el mismo día, salir antes del inicio reservado conserva la **presencia real** (del instante del registro a ahora). ¿Lo olvidaste y volviste después? El check-out sigue funcionando: el fin reservado se queda, el sello es veraz. Salir sin haberse registrado — o dos veces — se rechaza. Por defecto el **check-out es personal**: un admin solo puede terminar el registro en curso de un miembro si el propietario activó **Los administradores pueden hacer el check-out de los miembros** (§8). Un registro nunca cerrado se completa solo en cuanto te registras en otro sitio después de su fin — o, con la **entrada/salida automática**, en el barrido de fin de día.

**Ausencias.** Una reserva nunca registrada simplemente queda *reservada* en el historial. Con la **entrada/salida automática**, el barrido de fin de día marca el día pasado como asistido — registrado al inicio, salido al final, completado.

**Cancelar.**

| Caso | Qué pasa |
|---|---|
| Una reserva futura tuya | ✅ cancelada con un toque |
| Tu reserva en curso, registrada | ❌ no hay cancelación directa — la hoja ofrece en su lugar **Solicitar eliminación** (§4) y **Terminar antes** (abajo), porque la presencia ya ocurrió |
| Devolver el resto del día | ✅ **Terminar antes** sobre una reserva en curso: con medias jornadas y jornadas completas mueve el fin al límite de media jornada mientras este siga por delante; en las rejillas abre un selector encajado que rechaza cualquier hora que no quede por delante de ahora. El inicio es inamovible, y el tiempo liberado es inmediatamente reservable por otros |
| Una reserva completada o ya cancelada | ❌ no queda nada que cancelar |
| La reserva de otra persona | ❌ para un miembro; ✅ para un admin/propietario — la anulación (§4), atribuida al admin en el hilo de eventos |
| Una serie, «esta y las siguientes» | ✅ cancela las ocurrencias *reservadas* restantes desde esa fecha; las registradas y completadas conservan su historial |
| Una reserva **pasada o registrada** que quieres eliminar | una **solicitud de eliminación** (§4): un validador confirma (eliminada) o rechaza (se mantiene); una nueva solicitud sustituye a una pendiente, y las reservas futuras se cancelan directamente |

**Aprobaciones.** Donde el propietario puso una regla de validación sobre las **reservas de espacios enteros** (§7), la reserva bloquea el espacio inmediatamente y espera el quórum — un rechazo la cancela; sin regla, sin paso de aprobación. Las solicitudes de eliminación siguen el mismo marco. **Nadie valida su propio evento** — con una excepción que el propietario activa deliberadamente: en las reglas de validación (§7), dos interruptores independientes permiten a los **admins** y/o a los **propietarios** resolver al instante *sus propias* solicitudes de **eliminación de reserva**, sin esperar a un validador. Ambos están **desactivados por defecto**, alcanzan únicamente a las eliminaciones de reservas, y una eliminación resuelta automáticamente queda marcada como tal en el hilo de eventos — siempre distinguible de una revisada por otra persona.

## 5. Calendario (pestaña Calendario)

El mes de un vistazo, con dos alcances y dos formas:

- **Mías / Todos** — tus propias reservas, o las de toda la comunidad; el conmutador lo tiene **cada miembro**, ya que el plano y la cuadrícula semanal del hub Reservar muestran de todos modos la ocupación de todo el mundo. Los puntos bajo un día lo dicen de un vistazo: **rojo** = tienes una reserva, **azul** = otros miembros la tienen, **ambos puntos** = ambas cosas. Hoy va rodeado.
- El **conmutador de forma** a su lado cambia la mitad inferior entre una **lista de agenda** (cada reserva como tarjeta: ventana horaria, miembro, espacio) y una **cronología del día** (puestos × las horas del día elegido). La cuadrícula puestos × *días* de la semana vive en el hub Reservar (§4), no aquí.
- Los **chips de planta** (*Todas las plantas* / por planta) filtran la **cronología**.
- Toca un día en la cuadrícula mensual para cargarlo abajo. En horizontal, el calendario y el detalle usan el diseño dividido.

## 6. Directorio de miembros (pestaña Miembros)

Mira quién forma tu comunidad:

- Cada tarjeta de miembro muestra su **foto** (o inicial), su **chip de rol** (Admin, Propietario), su **estado personalizado** («en Berlín hasta el viernes…»), un indicador **en línea / visto por última vez** (*En línea*, *10 min*, *2 d*) y un **chip de reserva**: puesto registrado, *Reservado ahora*, o la próxima reserva.
- Toca un miembro para su **ficha de detalle** — rol, presencia, sus **próximas reservas** y **Mensajes**.
- **Mensajes**: un **hilo de conversación** por miembro (hasta 500 caracteres por mensaje) — ábrelo desde la pestaña **Mensajes** (§16), la ficha del miembro o su perfil del directorio, lee todo el intercambio en burbujas y envía desde el mismo sitio. Cada mensaje llega al otro lado por dos vías: un **push** que no transporta contenido alguno (*«Tienes un mensaje nuevo»* — por diseño de privacidad) y, una vez la app está en marcha, una notificación local que sí muestra tu nombre y tu texto. En *Ajustes*, una vez compartido tu número de WhatsApp, puedes además optar por **recibir tus mensajes en WhatsApp**: el texto llega tal como lo lee el mensajero, cada referencia de reserva/espacio como enlace web tocable, más un enlace DesKilo que **abre la app directamente en la conversación**. El propietario conecta el canal **en la app** (*Ajustes → Canal de WhatsApp*): una hoja guiada explica los tres pasos de Meta — crear una app gratuita en developers.facebook.com con el producto WhatsApp, copiar el token de acceso permanente y el ID del número desde la configuración de la API — y guarda ambos por espacio (solo escritura; WhatsApp solo entrega dentro de la ventana de servicio de 24 h del destinatario). El texto completo queda siempre legible en la pestaña **Mensajes**, para el destinatario y el remitente (el push en sí no transporta contenido, por diseño de privacidad). Los admins tienen un megáfono **Notificar a todos los admins** — en *Miembros y planes* (Ajustes → Administración), no en la pestaña Miembros, que no tiene barra propia — que llega a todos los admins, incluido el propietario. Conmutable con la función *Notificaciones entre miembros*. Al redactar, dos chips permiten **enlazar una reserva o un registro en curso — tuyos o de otro miembro** — o **un espacio** (asiento, mesa, sala o planta) — la referencia aparece como un enlace tocable en ambos lados: un enlace de reserva abre esa reserva, un enlace de espacio abre la hoja de reserva del espacio, ideal para hablar de una reserva futura.
- El **icono de mensaje** de una tarjeta escribe a ese miembro por **WhatsApp** (si compartió su número); el **botón de grupo** abre el grupo de WhatsApp de tu comunidad (definido por el propietario).
- Define tu propia foto, tu estado y la visibilidad de tu teléfono en **Ajustes** (§12).
- Los admins y propietarios ven además el **correo** de cada miembro bajo el nombre — los miembros normales no: el contacto entre miembros sigue siendo el número de WhatsApp compartido voluntariamente.

## 7. Eventos y confirmaciones (icono de campana)

El hilo de eventos es la pista de auditoría de tu espacio: reservas creadas/cambiadas/canceladas, pagos registrados, facturas pagadas, gastos presentados, solicitudes de días extra, cambios de rol, solicitudes de eliminación. Los miembros ven sus propios eventos; los admins y propietarios ven los de todos. Los **chips de filtro** (Todo · Reserva · Pago · Gasto · …) acotan la lista — tu elección se recuerda — y un menú **Agrupar por** pliega el hilo en grupos por tipo, día o miembro (tocar el símbolo del grupo vuelve a la lista plana); cada fila lleva su icono de estado — un **reloj de arena** mientras está pendiente, una **marca verde** una vez confirmado — y los eventos de dinero muestran *quién los validó y cuándo* directamente en la fila.

**A la espera de tu confirmación:** siempre que un admin hace algo *por otra persona* — te reserva un puesto, registra tu pago, degrada a un admin — queda **pendiente hasta que se confirme**. Lo pendiente se fija arriba con una ✕ roja y un botón verde **Aceptar**, y recibes una notificación. Lo que haces sobre ti mismo nunca requiere confirmación.

**Los mensajes se han mudado.** Los mensajes entre miembros viven ahora en su propia pestaña **Mensajes** (§16), no aquí — un mensaje en dos sitios es uno que puede marcar como leído en uno y seguir viendo sin leer en el otro. La campana conserva el único tipo que no tiene conversación donde vivir: una **difusión a todos los administradores**.

**Quórum de validación:** para asuntos de dinero y cambios de rol, el propietario define *quién* debe aprobar y *cuántas* aprobaciones hacen falta. **Nadie valida su propio evento** — solo otra persona puede (una excepción, que configura el propietario, para las eliminaciones de reserva, más abajo); donde no existe otro validador, la solicitud simplemente espera. Pasados 7 días sin respuesta, lo que ocurre depende de hacia dónde apunta la solicitud. Lo que **tú mismo pediste** para ti — una eliminación, medias jornadas extra, la anulación del saldo de una factura — **caduca**: nada costoso se concede jamás en silencio. En cambio, lo que un admin **hizo por ti** — crear o modificar una reserva, registrar un pago — **se confirma solo**, porque ya ocurrió y el hilo solo te pedía darte por enterado; una reserva que un admin te hizo queda entonces concedida y consume tu cuota.

El propietario afina esto por **dominio** en **Ajustes → Reglas de validación** — trece tarjetas, una por tipo de evento, cada una heredando de la **regla predeterminada** hasta que se edita: *Regla predeterminada, Pago, Gasto, Servicio, Medias jornadas extra, Eliminación de reserva, Cambio de rol, Nuevo miembro, Reserva, Reservas de espacios enteros, Pago de factura, Ajuste* y *Anulación de saldo*. Una regla fija el número de validaciones requeridas, *qué* admins pueden validar (todos, o algunos concretos) y si el propietario debe firmar siempre. La regla **Eliminación de reserva** lleva dos interruptores más — *los admins eliminan sin validación* y *los propietarios eliminan sin validación*, ambos **desactivados por defecto** — la única excepción, deliberada, a «nadie valida su propio evento»: la solicitud de eliminación del interesado se resuelve sola y queda marcada como **autovalidada** en el hilo. Se aplican a las eliminaciones de reserva y a nada más.

![](assets/help/images/validation-rules.jpg)

 

![](assets/help/images/validation-rule-edit.jpg)

*Izquierda: una regla por dominio, heredando de la predeterminada. Derecha: edición de una regla — validaciones requeridas, validadores autorizados, firma del propietario.*

## 8. Para propietarios: editor y ajustes

Toda la administración vive en **Ajustes → Administración** — *Espacio de coworking* (los ajustes del espacio), *ID del espacio y QR*, *Miembros y planes*, *Gestión de roles*, *Disponibilidad*, *Facturación*, *Instrucciones de pago*, *Servicios*, *Reglas de validación*, *Facturación e informes* (el hub de facturación con el editor de informes y las reglas de recordatorio en su cabecera), *Funciones* y las entradas ligadas a funciones (*Accesorios*, Pagos en línea, Credenciales RFID/NFC…). Una regla que conviene conocer: **la entrada de ajustes de una función solo aparece mientras esa función está activada** — desactiva *Pagos en línea* en **Funciones** y su pantalla de configuración desaparece con ella (y vuelve al reactivarla). La entrada **Funciones** siempre está presente, así que siempre puedes volver a activar un módulo.

![](assets/help/images/settings-administration.jpg)

### El editor del espacio

Abre el **editor** desde la barra del hub Reservar (icono de herramientas cruzadas). La pantalla **Editor del espacio** lista tus plantas — arrastra para reordenar, el **icono de capas** marca una planta *Reservable en su totalidad*, el **menú ⋮** renombra o elimina, **+ Añadir planta** amplía el edificio. Abre una planta para dibujarla sobre la cuadrícula con la barra inferior — **Seleccionar · Oficina · Mesa · Puesto · Imagen · Borrar**:

- Una **oficina** recibe un nombre, un interruptor opcional *Reservable en su totalidad* y un **precio por media jornada**.
- Una **mesa** recibe un nombre, la misma opción de mesa entera y su propio **precio por media jornada**.
- Un **puesto** recibe un nombre, una **orientación de asiento** (↑ → ↓ ←), un **tipo de silla** opcional, sus **accesorios** (cada uno puede llevar un suplemento por media jornada) y un interruptor **Bloqueado (mantenimiento)**.
- **Imagen** coloca una ilustración redimensionable; el icono de foto de la barra define la **foto de fondo** de la planta.
- Borrar un espacio con historial es cosa del **propietario**, y con *Eliminar espacios con historial* activada (lo está por defecto) funciona sin más: las reservas que referenciaban el espacio conservan una instantánea de texto de lo que era, y cualquier reserva aún vigente sobre él se cancela automáticamente. Desactiva la función y un espacio con reservas futuras hay que vaciarlo a mano antes.

### ID del espacio y QR

Tus invitaciones ligadas a rol (§2): invitación de miembro = el propio ID del espacio (sustitúyelo por uno memorable, cópialo, comparte el QR como PNG), invitación de admin = códigos personales de un solo uso.

### Disponibilidad

- **Días de apertura** — chips lun…dom.
- **Granularidad de reserva** — una de: *rango horario libre*, *tramos de 5 / 15 / 30 / 60 minutos*, *medias jornadas (mañana y tarde)*, *solo días completos* u *horas reales* (de–a exacto, con los atajos de media jornada y jornada completa).
- **Horario laboral** — inicio del día, límite de media jornada, fin del día (por defecto 08:00 / 12:00 / 17:00). Las medias jornadas y jornadas completas de toda la app — reservas, registro y facturación — siguen este horario; con *horas reales* defines además cuántas horas se facturan como media jornada y como jornada completa.
- **Días de cierre** — excepciones con fecha, añadidas con **+**.
- **Políticas de reserva** — cuatro entradas que relajan o endurecen las reglas del §4b (la sección sigue la función *Políticas de reserva*); los dos interruptores están **desactivados por defecto**:
  - **Permitir reservas pasadas** — los miembros pueden registrar a posteriori una reserva ya finalizada (ayer y antes). Desactivado, tales reservas se rechazan; reservar una ventana anterior del *mismo día* está siempre permitido. Actívalo en espacios que apuntan la asistencia después.
  - **Los administradores pueden hacer el check-out de los miembros** — un admin puede terminar el registro en curso de un miembro. Desactivado, el check-out es estrictamente personal. Útil donde el personal cierra la sala por la noche.
  - **Fuera del horario de apertura** — una pregunta, cuatro respuestas mutuamente excluyentes, iguales en todas las granularidades: *¿qué puede ocurrir fuera de la jornada laboral?* **Prohibido** — nada: ni reservas por adelantado, ni registros espontáneos, y una reserva que se pasa del fin de la jornada (o empieza antes de abrir) también se rechaza. **Solo espontáneo** — el registro espontáneo sigue siendo posible en **cualquiera de los dos extremos del día**, la llegada temprana antes de abrir tanto como la prórroga vespertina hasta medianoche, mientras que reservar por adelantado fuera del horario se rechaza; aquí fue a parar el antiguo interruptor **Reservas por minutos dentro del horario laboral**, y los espacios que lo tenían activo se leen así (aquel interruptor solo permitía la llegada vespertina — el modo se llama por lo espontáneo, no por la tarde, así que la llegada matinal también entra). **Gratis** — permitido, nunca contado ni facturado (pura información de presencia). **De pago** (el **defecto**) — contado como uso ordinario, salvo un día en el que el miembro ya mantiene una reserva normal dentro del horario: la parte de fuera viaja entonces gratis.
  - **Reservas simultáneas por miembro** — cuántas reservas superpuestas puede mantener un miembro, registros incluidos. **1** por defecto: un sitio a la vez. Un propietario o un admin puede conceder a un miembro concreto un cupo mayor en *Miembros y planes* (nunca a sí mismo), y ese permiso personal prevalece sobre este número.

  Justo debajo están los **Límites de reserva** — tres números que el servidor siempre ha aplicado y que la app ya sabe ajustar:

  - **Horizonte de reserva** — cuántos días antes puede empezar una reserva (por defecto **90**); más allá se rechaza diciéndolo.
  - **Duración mínima** — la reserva más corta aceptada (por defecto **30 minutos**), en todas las granularidades. Por eso exactamente una llegada a las 11:45 para el límite de las 12:00 se rechaza por corta.
  - **Duración máxima** — la más larga aceptada (por defecto **24 horas**). Como una reserva termina el día en que empieza, la jornada entera es el techo y el selector no ofrece nada por encima.

  Si pones un mínimo por encima del máximo, la pantalla lo advierte: el servidor comprueba cada límite por separado y se limitaría a rechazar todas las reservas sin explicar nunca por qué.

  Los dos interruptores de **autovalidación** — *los admins eliminan sin validación*, *los propietarios eliminan sin validación* — no están aquí: viven con las reglas de validación (§7), desactivados por defecto, y solo alcanzan a las eliminaciones de reserva.

### Funciones

Activa o desactiva módulos enteros por espacio — cada interruptor lleva su descripción en la propia pantalla: pestaña calendario, pestaña eventos, agrupación de notificaciones, pestaña Finanzas, servicios, suplementos de accesorios, pagos en línea, facturas, los admins emiten facturas, plantilla del PDF de factura, recordatorios de pago (Mahnwesen), gestión del IVA, declaraciones de IVA, envío de la factura electrónica al cliente, exportar PDF, reserva en serie, reservar para otros, notificaciones push, los administradores pueden bloquear sitios, reservas de mesa, oficina y planta, los admins pueden asignar plantas, modo quiosco, credenciales RFID/NFC, credenciales QR, fotos de los miembros en el quiosco, directorio de miembros, integración con WhatsApp, códigos QR de espacios, etiquetas NFC/RFID de las sillas, fotos de los miembros en el plano, copropietarios, entrada/salida automática, exportación de datos (Excel), horario laboral, políticas de reserva, notificaciones entre miembros, biblioteca de documentos, informes de miembros, solicitudes de eliminación de reservas, gestión de roles, eliminar espacios con historial, consejos de ayuda y animaciones de la interfaz. Desactivar un módulo elimina *todas* sus pantallas y botones para todos los miembros.

La lista es **jerárquica**: una función que necesita otra aparece indentada bajo ella con una nota *Requiere…*, y queda atenuada mientras su padre está desactivado — *Finanzas* lleva los servicios, los suplementos de accesorios, los pagos en línea y la facturación; *Facturas* lleva la delegación a admins, la plantilla PDF, los recordatorios de pago, la gestión del IVA (con las declaraciones debajo) y el envío al cliente; *Modo quiosco* lleva tres hijas — credenciales RFID/NFC, credenciales QR y fotos de los miembros en el quiosco; *Reservas de mesa, oficina y planta* lleva *los admins pueden asignar plantas*; *Directorio de miembros* lleva la integración con WhatsApp; la *pestaña eventos* lleva la agrupación del hilo. Desactivar un padre saca todo su subárbol de la app; la elección guardada del hijo vuelve intacta cuando el padre regresa.

![](assets/help/images/workspace-id-qr.jpg)

 

![](assets/help/images/availability-granularity.jpg)

 

![](assets/help/images/features-toggles-1.jpg)

 

![](assets/help/images/features-toggles-2.jpg)

### Miembros y planes

Toca un miembro para abrir su **ficha de gestión** — cada acción por miembro en un solo lugar: **Enviar el acuerdo financiero** (§11d), **Mensajes**, **Añadir un servicio** (servicio, cantidad, mes de facturación → *enviar a confirmación*), **Suscripción** (su porcentaje), **Cuando se acaban los días** (la política de exceso, §9), **Límite de reservas** (cuántas reservas **abiertas** puede mantener el miembro en total, caigan cuando caigan), **Reservas simultáneas** (cuántas reservas pueden **solaparse en el tiempo** — el cupo personal que prevalece sobre el número del espacio, §4b; son dos topes distintos, así que lee las etiquetas), **Puede reservar una mesa, oficina o planta entera**, **Credenciales** (§10), **Nombrar admin** (validado, §7), **Copropiedad**, **Convertir en quiosco** — o **Revertir quiosco a miembro** en una cuenta de dispositivo —, **Aprobar membresía** o **Rechazar membresía** cuando está pendiente, y **Pausar la membresía**. Cada fila muestra el **correo** del miembro bajo el nombre.

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
- **El cuestionario de configuración** — <https://fdittgen-png.github.io/deskilo/setup.html>: una página independiente (Mac, PC o teléfono; las respuestas se guardan solas en el navegador) que guía a un propietario nuevo por **cada asunto con opciones predefinidas** — identidad (país incl. Noruega, moneda, zona horaria, idioma del espacio, transparencia de mesas y las plantillas de invitación por idioma), disponibilidad — granularidad, horario laboral, días de cierre y **las cuatro reglas de reserva** (reservas pasadas, check-out por un admin, modo fuera de horario, reservas simultáneas), más la conversión horas → medias jornadas en «horas reales» —, el plano, **las 43 funciones** con sus valores por defecto reales, tramos de cuota y niveles de suscripción, bonos de días, servicios y accesorios, instrucciones de pago, **identidad legal e IVA** (tipo de organización, régimen, los tipos habituales del país — el 3,8 % suizo de alojamiento, Noruega, las provincias canadienses, con la nota honesta sobre el sales tax estadounidense —, menciones de factura, reglas de recordatorio, la periodicidad de declaración y los puntos de acceso de facturación electrónica, incluido el servicio de entrega al cliente), la matriz rol → permiso, la regla de validación por defecto **con una tarjeta por dominio y los dos interruptores de validación automática**, y los miembros a invitar con sus ajustes personales (política de exceso, derecho sobre espacios enteros, permiso de solapamiento, límite de reservas). **Exporta el XML** y la app importa directamente ajustes, accesorios y plano (*Importar el espacio (XML)*); la sección `<setup>` del archivo lleva todo lo demás para terminar la configuración. La página también puede **recargar** un archivo exportado antes para seguir editando — incluido uno escrito antes de que existiera un ajuste, que vuelve sencillamente con ese ajuste en su valor por defecto. Una advertencia que la página repite: el archivo exportado es texto plano, así que escribe un token de plataforma solo si respondes en privado; si no, deja esos campos vacíos y tecléalos en la app, donde van al servidor y nunca vuelven.
- **Zona de peligro** — **Restablecer el espacio**: borra todas las reservas, la contabilidad y el plano; conserva ajustes y miembros. Protegido por una confirmación escrita.

### Códigos QR de espacios y reservas de espacios enteros

Cuatro pasos convierten «escanear el código de la mesa» en el flujo de reserva diario (§4a):

1. En el **editor**, marca una mesa, una oficina o una planta como **Reservable en su totalidad** y dale un **precio por media jornada** — la ficha de propiedades de la mesa o de la oficina, o para una planta el **icono de capas directamente en su fila**.
2. Activa **Reservas de mesa, oficina y planta** en **Funciones** (desactivada por defecto).
3. Concede a cada miembro autorizado **«Puede reservar una mesa, oficina o planta entera»** — propietarios y admins lo fijan en la ficha de gestión del miembro, nunca para sí mismos. Los propietarios y admins tienen ese derecho sin el interruptor, tanto en la app como en el **quiosco**.
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

1. Abre **Ajustes → Credenciales RFID / NFC** (solo propietario). Activa **Activar registro por credencial NFC** y lee la línea de **estado del dispositivo** — distingue entre *listo*, *NFC desactivado en los ajustes de Android* y *sin hardware NFC*. Los teléfonos y tabletas Android con NFC, y los **iPhone**, pueden leer una etiqueta; los iPad no llevan hardware NFC alguno.
2. Da una tarjeta a cada miembro: **Miembros y planes → el miembro → Credenciales → Registrar una tarjeta**, y acerca su tarjeta al dispositivo. Vale cualquier tarjeta con chip legible (MIFARE, NTAG…). Los miembros también pueden hacerlo **ellos mismos**: **Ajustes → Mi credencial** emite su credencial QR imprimible y registra su propia tarjeta — sin necesidad de admin.
3. Úsalas en un **quiosco** (§10): el miembro acerca la tarjeta para reservar o registrarse. Revoca una tarjeta perdida desde la misma ventana de Credenciales; **desliza una credencial revocada hacia la derecha para eliminarla** definitivamente (tras confirmación).

Las credenciales pertenecen a **un solo espacio** — la ventana indica en cuál estás registrando, así que registra la tarjeta en el espacio cuyo quiosco la leerá. La misma tarjeta física puede servirte en varios espacios. Una credencial QR guardada **como PDF** imprime diez copias tamaño tarjeta de crédito en una página A4 — con repuestos incluidos.

![](assets/help/images/nfc-config.jpg)

 

![](assets/help/images/member-badges-dialog.jpg)

## 9. El dinero (pestaña Finanzas)

Tu cuenta responde *qué debo, qué me deben* — y *cuánto puedo reservar aún*. En vertical, la factura del mes se desplaza sobre los botones de acción; en horizontal, las acciones pasan a un panel lateral y la factura llena el resto. La cabecera **‹ mes ›** navega cualquier mes; el **botón PDF** exporta la factura visible (§ más abajo).

**La factura, tarjeta por tarjeta:**

- **Este mes** — cuántos **días** incluye tu suscripción este mes, cuántos has **usado**, cuántos **quedan**, con una barra de progreso. Una mañana reservada cuenta 0,5 días — salvo que quede enteramente fuera del horario laboral y la política de fuera de horario del espacio la haga gratuita o exenta (§4b): la misma regla gobierna aquí la cuota y allí el importe de la factura. El derecho mensual sigue los días de apertura del espacio y tu porcentaje — la tarjeta de suscripción debajo lo detalla (*3 de 42 medias jornadas usadas, 21 días de apertura*).
- **Exceso** — las medias jornadas que superan tu plan, a la tarifa de tu tramo.
- **Servicios consumidos** — cada consumo de servicio con el total de servicios.
- **Suplementos de accesorios** — los extras por media jornada de los puestos que reservaste.
- **Reservas de planta, oficina y mesa** — las reservas de espacios enteros, cada una a su precio por media jornada.
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
- **Documentos** — **Facturas** (las tuyas siempre están legibles aquí: posiciones, saldo, estado — y para quien emite, el hub de facturación, §11), **Mis condiciones** (que produce el documento titulado *Acuerdo financiero*) y el **informe mensual de pagos**, en autoservicio (§11).

### 9a. Una vez facturado el mes, decide la factura

- Tu factura mensual muestra una **tarjeta de factura** — número, estado, total, lo pagado, lo pendiente — y el mes pasa a **saldado** en cuanto la factura se paga, se anula su saldo o se reembolsa su nota de crédito, aunque el pago que la salda se registrara en un mes posterior. Una factura **parcialmente pagada** deja el mes pendiente exactamente por el importe **restante** (eso es también lo que cobra *Pagar en línea*). Un mes con **nota de crédito** muestra lo que el espacio te debe devolver — nada que pagar por tu parte.
- **Tu cuenta** — cuando tienes crédito disponible (un avoir, o pagos sobrantes de un mes pasado), la pestaña Finanzas muestra tu posición real entre meses encima de la factura: **crédito a favor**, cada **factura abierta** con su importe restante, los reembolsos que el espacio te debe y la **posición neta** resultante. Tu crédito puede saldar facturas abiertas — el espacio lo aplica al conciliar los pagos (imputación). Los meses anteriores a tu adhesión no deben nada y nunca aparecen pendientes.

### 9b. Vista rápida, guardar, compartir — todos los informes

Cada informe de la app — la factura mensual, las facturas, los proformas, las notas de crédito, tus documentos de autoservicio — ofrece las mismas tres acciones: **Vista rápida** (ver el documento renderizado en pantalla antes de que exista PDF alguno), **Descargar PDF** (guardar localmente) y **Compartir PDF** (entregarlo a cualquier app — WhatsApp, correo, …).

**Los informes hablan el idioma de quien los lee:** un documento se imprime en el idioma **del miembro** cuando existe una plantilla para él, si no en el **idioma del espacio**, y a falta de ambos en el **idioma del país del espacio** (§11, plantillas por idioma). Cuando ese país tiene varios idiomas, la app no adivina: se niega y te pide *definir primero el idioma del espacio*.

## 10. Modo quiosco (tableta de pared)

Monta una tableta Android o un iPad junto a la puerta y deja que la gente se registre al entrar:

1. El propietario crea una cuenta normal para el dispositivo, la une al espacio y la marca como **quiosco** en *Miembros y planes*.
2. **El modo quiosco nunca arranca solo.** En cada inicio de la app la tableta pregunta *¿Iniciar el modo quiosco?* — confirma y la tableta se bloquea: solo el plano a pantalla completa, botón de atrás desactivado y, en **Android**, la app se ancla para que no pueda abrirse nada más, lo que significa que allí salir del modo quiosco implica reiniciar la tableta. Un **iPad** no tiene ese anclaje, así que solo se aplica el bloqueo de ruta — usa el **Acceso guiado** de iOS (Ajustes → Accesibilidad) para conseguir el equivalente. Elige *Ahora no* y la app se abre normalmente — útil para la configuración. La propia designación de quiosco puede revertirse en cualquier momento: en el dispositivo, en **Ajustes → Dispositivo quiosco**, o por el propietario en *Miembros y planes*.
3. Cada miembro lleva una **credencial** — emitida por un admin (*Miembros y planes → Credenciales*) o por el propio miembro (**Ajustes → Mi credencial**, §8): una **credencial QR** imprimible y/o su **tarjeta RFID/NFC**. Cada una depende de su propia función (**Credenciales QR**, **Credenciales RFID/NFC**), ambas bajo *Modo quiosco*, así que un espacio puede ofrecer una, la otra o las dos.
4. En el quiosco, toca un puesto (o **Esta planta** — que necesita las reservas de espacios enteros activadas *y* esa planta marcada como reservable) — se abre **UNA sola hoja** con todo: **Registrarse** ya seleccionado (un toque cambia a **Reservar** o **Salir**), el **periodo ya derivado de los ajustes del espacio**, y el **lector de credenciales activo** abajo. Con medias jornadas, la parte del día en que estás viene preseleccionada (chips Mañana / Tarde / Día para cambiar — una ventana en curso empieza *ahora*, las franjas ya terminadas ni siquiera se ofrecen, y lo que sí queda atenuado es una franja aún futura mientras la acción elegida es **Registrarse**, porque no se puede estar presente por adelantado; tras el horario queda un único *Resto del día*, que corre hasta la medianoche y ni un minuto más, porque una reserva termina el día en que empieza). Con granularidad horaria: selectores De/A ajustados a la rejilla, el inicio de un registro fijado a *ahora*. La hoja **nombra la regla que sigue** — la granularidad y las ventanas horarias de hoy — así que lo que ofrece es exactamente lo que los ajustes permiten; un **día cerrado** se anuncia de entrada con un aviso en vez de fallar al final. Reservar una ventana ya empezada ofrece además **Registrarse ahora mismo** (activado por defecto): una sola presentación de la credencial registra la reserva *ya con entrada*. Después presenta la credencial:
   - **Acerca la tarjeta RFID/NFC.** Mientras el lector de tarjetas está armado, la cámara permanece apagada; si el NFC está desactivado o no existe, la hoja lo dice explícitamente.
   - O toca **Escanear la tarjeta QR** — la tableta lee la credencial impresa **con su propia cámara** (la frontal por defecto, ya que la lente trasera de una tableta de pared mira a la pared; cámbialo en *Ajustes → Escanear con la cámara frontal*). Un lector USB/Bluetooth o escribir el código también funcionan.
5. **La credencial ES la confirmación:** ejecuta inmediatamente, y un **recibo que se cierra solo** muestra *a quién* se reconoció — con su **foto de perfil**, donde la función *Fotos de los miembros en el quiosco* está activada —, *qué* pasó, *dónde* y *hasta cuándo*; y la pared queda limpia para el siguiente miembro. El plano de la pared muestra las fotos de los ocupantes del mismo modo. El camino feliz son dos gestos: toca tu puesto, presenta tu credencial.

**Lo que la pared deliberadamente no puede hacer.** Toca un puesto que ocupa otra persona y el quiosco **nombra al titular y te remite a tu teléfono**: un dispositivo de pared nunca envía un mensaje por cuenta de un miembro, porque cualquiera que esté delante podría hacerlo. La acción *Escribirle* para un espacio bloqueado vive en la app (§4b). Todo lo que el quiosco *sí* ofrece pasa por las mismas reglas de servidor que la app — incluidas la del día ya terminado, la de que un check-in espontáneo debe empezar hoy y la del mismo día —, así que la pared rechaza exactamente lo que rechaza el plano.

Tu identidad solo existe durante la operación: la credencial se envía **únicamente para esa operación** — una vez para identificarte, otra para ejecutar la acción — y **no se guarda nada**, ni en la tableta ni en ningún otro sitio. La reserva se hace **a tu nombre**, y quedas «desconectado» en cuanto termina. (El acceso puntual con Google sigue en la hoja de ruta; **los iPad no tienen NFC**, así que allí la vía es el QR con la cámara.)

## 11. Facturación (propietarios y admins de facturación)

*Los propietarios emiten facturas; los admins también cuando tienen el permiso **emitir facturas** (Gestión de roles, §8 — o la antigua delegación de función **Los admins emiten facturas**). La función **Facturas** cuelga de Finanzas en la lista de funciones.*

Una factura en DesKilo se genera, nunca se redacta: sus posiciones se **derivan exclusivamente de los datos registrados del mes** — suscripción, exceso, suplementos, servicios, paquetes — menos los pagos y créditos del mes, de modo que la línea final **es el saldo adeudado**. Cada documento captura las direcciones postales del espacio y del miembro (configura la tuya en **Ajustes → Dirección**; la dirección del espacio está en los ajustes del espacio) y se **firma digitalmente** al emitirse — después ya no cambia nunca. Un **anexo detallado** (el libro mayor y la asistencia del mes) puede adjuntarse con un interruptor al emitir.

Quien emite abre **Finanzas → Facturas** y llega a un hub de tres pestañas bajo una franja de resumen en vivo (*N por facturar · N abiertas · X pendiente · N por reembolsar · Y*):

- **Por facturar** — cada miembro cuyo mes anterior tiene datos facturables y aún sin factura, con el total del mes: emite por miembro (con vista previa de las posiciones derivadas) o **Facturar todo** de una pasada — que pide confirmación antes, anunciando el número, el mes y el total. El botón **Nueva factura** abre la misma hoja para cualquier miembro y mes — selector de miembro, ‹ mes ›, las posiciones derivadas, el saldo, el interruptor del **anexo detallado** y **Emitir factura** (un aviso verde *Factura emitida.* confirma). **Una factura activa por miembro y mes** — un mes solo vuelve a ser facturable cuando su factura fue anulada. La hoja de emisión abre en el **mes cerrado** (el momento en que sus números dejan de moverse); si eliges el mes en curso, te avisa, porque ese mes solo puede facturarse una vez.
- **Abiertas** — facturas emitidas a la espera de cobro, las más antiguas primero; lo que lleva más de 30 días esperando se pone en rojo, en la tarjeta y en la franja de resumen. Cada acción es un icono con descripción emergente (anular · proforma · recordatorio · marcar como pagada). **Toca una tarjeta para leer la factura.** **Enviar un recordatorio** registra el recordatorio y comparte el PDF con un mensaje — la tarjeta muestra *Recordado ×N*. **Marcar como errónea** anula la factura para corregirla (un diálogo explícito avisa de que la acción es irreversible): pasa al archivo tachada, y un **reemplazo** vuelve a derivar el mismo mes desde los datos corregidos, referenciando la original. **Marcar como pagada** empareja un pago real (abajo). **Un pago parcial no cierra una factura**: permanece en Abiertas, con la insignia *Parcialmente pagada* y el importe restante, hasta que el saldo pendiente se anule explícitamente **mediante el marco de validación** — un admin/propietario solicita la anulación (con un motivo), los validadores confirman y solo entonces la factura pasa al archivo como *Parcialmente pagada · saldo anulado*. **Una factura NEGATIVA es una nota de crédito (avoir)** — los créditos del mes superaron sus cargos, así que el ESPACIO debe dinero al miembro: su PDF se titula *Nota de crédito*, no recibe recordatorios ni conciliación de pagos del miembro; en su lugar la tarjeta muestra *A reembolsar* con **Registrar el reembolso** — el pago se imputa al saldo del miembro (validado como cualquier liquidación cuando aplica una regla; un rechazo la reabre) y el documento se cierra como *Reembolsada*. La franja de resumen separa las dos direcciones del proceso de pago: *N abiertas · X pendiente* cuenta las facturas positivas por su valor **restante** (una factura de 500 € con 280 € pagados cuenta 220 €), mientras que *N por reembolsar · Y* suma las notas de crédito abiertas que el espacio aún debe.
- **Archivo** — facturas cerradas, filtrables por miembro y mes y ordenables; las facturas anuladas están **ocultas por defecto** — el chip *Mostrar canceladas* recupera la cadena de corrección; la barra bajo los filtros dice cuántas facturas coinciden y **Borrar filtros** devuelve el archivo completo. Cada fila lleva su chip de estado (*Pagada*, *Parcialmente pagada*, *Errónea* tachada, notas de crédito con su importe negativo), su mes y su importe, con **Descargar PDF** ahí mismo. **Toca una fila para abrir la factura** — posiciones, saldo, a quién se facturó, en qué estado está (*Pagada 300,00 € el 6 ago*, *Recordado ×1 · último recordatorio…*, *Anexo: 5 movimientos, 10 registros*), a qué factura sustituye o por cuál fue sustituida, su firma — y cada acción que aún permite, con su nombre: **Vista rápida**, **Descargar PDF**, **Compartir PDF**, exportar la **factura electrónica (XML)**, recordar, marcar como pagada, marcar como errónea, emitir un reemplazo.

**Marcar como pagada significa emparejar un pago real — o aplicar un crédito.** El diálogo lista los pagos registrados del miembro — transferencias anotadas y pagos en línea confirmados — y tú emparejas la factura con uno de ellos; no hay ningún importe que teclear (¿aún no hay pago registrado? el diálogo lo dice: *regístralo o confírmalo primero*). También lista los **créditos en cuenta** del miembro (excedente de nota de crédito): emparejar uno imputa el avoir en la factura, meses pasados incluidos — la alternativa estándar al reembolso en efectivo, tanto para asociaciones como para empresas. Cada crédito se gasta exactamente una vez: uno ya deducido dentro de una factura emitida nunca puede saldar un segundo documento. ¿Pagó **de más**? Crea una **nota de crédito** por el exceso (un abono en la cuenta del miembro) o fuerza la aceptación con una nota obligatoria. ¿Pagó **de menos**? Acéptalo con una nota obligatoria. Todos los que tienen acceso a la facturación reciben aviso de las facturas pagadas, y el propietario puede poner una regla de validación de **Pago de factura** (§7): el emparejamiento espera entonces al quórum — un rechazo reabre la factura.

**Una factura pagada es definitiva.** Una vez emparejada no puede anularse, sustituirse ni alterarse — las correcciones ocurren antes del pago, anulando la factura abierta y emitiendo su reemplazo. Un pago que **no** cubrió el importe completo, aceptado con una nota, aparece como **parcialmente pagada**, no como pagada.

**Proforma.** Dos de las tres pestañas del hub llevan una acción de proforma: en **Por facturar** representa las posiciones derivadas del mes como presupuesto — sin número, sin firma, sellada PROFORMA, y **no se emite nada**; en **Abiertas** vuelve a renderizar la factura emitida como solicitud de pago que no puede pasar por el original. Ambas ofrecen la tríada vista rápida / descargar / compartir.

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

**En DesKilo los precios incluyen IVA.** Lo que escribes como precio de suscripción, de servicio o de paquete de días es lo que paga el miembro. Activar el IVA no cambia ni un solo importe adeudado — dice qué parte de ese importe es impuesto. Por eso una factura mensual, un extracto y una cuota no se mueven al añadir tipos, y por eso ningún total hay que cuadrarlo. Bajo un régimen sujeto a IVA el catálogo lo dice en voz alta: cada fila de servicio y de bono nombra su tipo incluido (*IVA 21 % incl.*), el editor de facturación permite al propietario elegir el tipo de IVA de las tarifas (por defecto: el tipo por defecto del espacio) y muestra la parte de IVA de cada importe al teclear, cada accesorio puede llevar su propio tipo (por defecto: el del espacio), y cada campo de precio recuerda que es bruto.

**Configurar los tipos.** *Identidad legal y facturación electrónica → **Tipos de IVA***. Una lista vacía significa que el IVA está desactivado, que es como empieza todo espacio. **Usar los tipos habituales** rellena la lista con el tipo general, el intermedio y el reducido de tu país como primer borrador — un punto de partida, no asesoramiento fiscal. Un tipo es el **predeterminado** (la estrella): las suscripciones, los excesos, los suplementos y los ajustes lo usan, igual que todo servicio sin tipo propio. Un servicio y un paquete de días llevan cada uno su propio tipo, elegido en su editor. Quitar un tipo nunca lo borra — el que una factura o un servicio siga usando se conserva, desactivado, para que nada se vuelva a gravar en silencio. Todo esto es la funcionalidad *Gestión del IVA*: desactivada, el editor de tipos y todos los selectores desaparecen mientras los tipos guardados siguen aplicándose — la aritmética fiscal nunca es desconectable — y el conmutador *Declaraciones de IVA* cuelga debajo.

**La declaración periódica de IVA** (*Tipos de IVA → Declaración de IVA*, solo espacios sujetos a IVA). Elija el periodo — mes o trimestre, según su régimen — y **Generar**: la app agrega las facturas emitidas del periodo por tipo **con la aritmética exacta de las facturas**, así la declaración cuadra con cada documento al céntimo. El resultado muestra la base imponible y el IVA repercutido por tipo, mapeados a las **casillas del formulario oficial** (CA3 08/09/9B/11 en Francia, UStVA Kz 81/86 en Alemania, lista genérica en el resto). Cada declaración se exporta como **PDF** y **XML legible por máquina**; si hay una plataforma de envío configurada en la facturación electrónica, **Transmitir** la envía electrónicamente y registra el acuse — si no, lleve las cifras al portal de Hacienda o a su gestor y **Márquela como presentada**. En ambos casos la declaración se vuelve inmutable, con canal y recibo registrados. El catálogo de tipos sugeridos cubre todos los Estados miembros de la UE, Suiza (incluido el 3,8 % de alojamiento), Noruega y las provincias canadienses; EE. UU. no tiene IVA federal — la app lo dice en vez de adivinar. Una ayuda para declarar, no asesoría fiscal.

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

**Un segundo destino, directo al cliente.** Llegar a la plataforma pública no es lo mismo que llegar al comprador, y no pocos clientes tienen su propio servicio de recepción. Por eso la misma pantalla admite un **segundo destino** — el punto del cliente, con su propia URL, su token, su forma de cabecera Authorization y su nombre de campo de archivo —, y la hoja de envío ofrece entonces las dos vías, cada una con su propio historial de transmisiones. Depende de la función **Envío de la factura electrónica al cliente**, bajo *Facturas*; déjala desactivada y solo existe la vía de la plataforma, exactamente como antes.

**Ensayar sin riesgo.** La misma pantalla admite **puntos de prueba** (el UAT de la plataforma o un destino dev: URL + token cada uno) junto al de producción. Con el **modo desarrollador** del espacio activado (un ajuste de todo el espacio que solo propietarios y admins pueden cambiar, en Ajustes → Avanzado), el envío ofrece elegir el entorno, un envío de prueba queda marcado como tal en el historial de transmisiones de la factura, y el punto de producción nunca se usa para un ensayo — un entorno de prueba sin configurar simplemente se niega en lugar de recurrir al de producción.

DesKilo sigue sin transmitir nada por cuenta propia: produce el documento y lo entrega a la plataforma que elegiste. Los calendarios de obligatoriedad siguen moviéndose: consulta a tu propia administración tributaria antes del plazo que te afecte.

### 11c. El editor de informes — cada documento, cuatro modelos, cinco idiomas

La **Plantilla del PDF de factura** (icono de lápiz en la cabecera de Facturas, o *Ajustes del espacio*) es una herramienta de informes por bandas para cada documento que imprime la app. Tres **bandas** de informe se renderizan en el PDF — cabecera, cuerpo (las líneas de la factura), pie — mientras que el XML de la factura electrónica nunca se toca.

- **Un informe por documento**: los chips cambian entre **Factura · Proforma · Extracto · Acuerdo · Pagos · Espacio · Niveles de recordatorio**. El proforma recae en las bandas de la factura hasta que lo personalices; un extracto personalizado sustituye el PDF mensual integrado.
- **Por idioma**: una segunda fila de chips — *Predeterminado (todos los idiomas)* · EN · FR · DE · ES · IT — guarda una capa de traducción por documento; el informe de un miembro se imprime en *su* idioma cuando existe una plantilla para él, y si no, en el predeterminado del espacio.
- **Marcado o Visual**: el modo **Marcado** edita las bandas como texto — condiciones y bucles [Liquid](https://shopify.github.io/liquid/) (`{{ number }}`, `{% if proforma %}…{% endif %}`, `{% for line in lines %}…{% endfor %}`) más un marcado de líneas sencillo: `#` título, `##` sección, `>` letra pequeña, `---` separador, `a | b` fila de tabla, `=` fila en negrita, `::: … ||| … :::` columnas lado a lado (el bloque de direcciones vendedor-izquierda / cliente-derecha y los totales alineados a la derecha de una facture francesa — las plantillas incluidas siguen exactamente esa estructura), `![name]` una imagen de la **biblioteca de imágenes** del espacio (*Insertar una imagen*). El modo **Visual** es una superficie de diseño fiel a la página, en la tradición de las herramientas profesionales (Crystal Reports, Docentric): las tres bandas se editan **sobre una página A4 blanca** con los márgenes del documento, en su tipografía de impresión exacta — misma fuente, tamaños, colores y columnas de importes alineadas a la derecha que el PDF generado — con tiras de banda etiquetadas, guías punteadas de salto de página y zoom (ajustar, 75/100/150 %). Los `{{ tokens }}` siguen resaltados; toca una línea para editarla en el sitio, añade, mueve, inserta campos desde la paleta. Un conmutador **Diseño ↔ Vista previa** fusiona tus bandas sin guardar con tus datos reales (o de ejemplo) a través del motor real, en la misma página — fuera campos, dentro valores.
- **Galería de plantillas** (*Plantillas*): cuatro modelos listos para cada documento — **Clásico · Sencillo · Detallado · Carta formal** — elige uno y extiéndelo. Cada modelo de factura ya lleva las menciones obligatorias (§11a).
- La **Vista rápida** renderiza el resultado al instante en la app — tu factura más reciente, o datos de ejemplo simulados si no existe ninguna (con marca de agua *datos de ejemplo*) — sin pasar por un PDF; **Vista previa** produce el PDF; **Restablecer al modelo por defecto** devuelve el diseño integrado como ejemplo funcional. Una plantilla rota nunca bloquea un documento — el diseño integrado toma el relevo; la marca de agua de anulación, la firma digital, el anexo y los números de página quedan fijos.

Variables de plantilla (familia de facturas): `{{ number }}`, `{{ member }}`, `{{ workspace }}`, `{{ workspace_address }}`, `{{ period }}`, `{{ issued }}`, `{{ issued_by }}`, `{{ replaces }}`, `{{ total }}`, `{{ charges }}`, `{{ payments }}`, `{{ voided }}`, `{{ proforma }}`, `{{ copy }}`, `{{ lines }}` (cada una con `label`, `unit_price`, `qty`, `net`, `vat_rate`, `amount`), `{{ has_vat }}`, `{{ vat }}`, `{{ net_total }}`, `{{ vat_total }}`, `{{ credit_note }}`, `{{ refund_total }}` — y el juego legal: `{{ seller_legal_form }}`, `{{ seller_registration }}`, `{{ seller_vat_id }}`, `{{ seller_legal_id }}`, `{{ exemption_reason }}`, `{{ client_address }}`, `{{ client_vat_id }}`, `{{ client_legal_id }}`, `{{ payment_terms }}`, `{{ late_penalty }}`, `{{ recovery_indemnity }}`, `{{ escompte }}`, `{{ insurance }}`, `{{ special_mentions }}`.

### 11d. La suite de informes y la biblioteca de documentos

- **Acuerdo financiero** — cada precio vigente que se aplica a un miembro: suscripción, media jornada extra, servicios, paquetes, suplementos de accesorios y los precios de los espacios enteros, **mesas incluidas**. Propietarios y admins lo envían desde la ficha de acciones de un miembro; cada miembro puede ver/descargar/compartir el suyo en *Finanzas → Documentos*.
- **Informe de pagos** — todo lo que pagaste, declaraste o te validaron en un mes: tu pequeño balance, en autoservicio en la misma fila.
- **Informe del espacio** — identidad, recuentos del plano, disponibilidad, funciones y precios: *Ajustes del espacio → Informe del espacio*.
- **Biblioteca de documentos** — *Ajustes → Documentos*: los estatutos, guías de usuario, estados financieros y actas del espacio, ENLAZADOS desde el sistema que ya uses — Google Drive, OneDrive, SharePoint, Dropbox, Nextcloud o cualquier enlace https (el drive sigue gestionando sus propios accesos; la app nunca guarda credenciales ajenas). Cada entrada tiene un **rol de visibilidad**: todos los miembros, admins y propietarios, o solo propietarios — aplicado en el servidor, de modo que un miembro ni siquiera descarga una lista que contenga documentos de la junta. Los admins y propietarios la gestionan con el botón +; un interruptor de función *Biblioteca de documentos* activa todo el conjunto.

## 12. Ajustes y perfil

Tu pantalla personal, de arriba abajo:

- **Perfiles** (§1) y tu **foto** (tócala para cambiarla — elegir o quitar).
- **Miembros** — un acceso directo al directorio; **WhatsApp** — tu número, visible para los demás miembros solo si lo defines; **Estado** — una línea libre (40 caracteres) mostrada en el directorio; **Dirección** — tu dirección postal (impresa en tus facturas), país y número de IVA opcional.
- **Ayuda** — la guía integrada, en tu idioma; **Mi credencial** (§8); **Cuentas vinculadas** — vincula un acceso con Google a tu cuenta de correo; **Documentos** — la biblioteca de documentos del espacio (§11d).
- **Preferencias** — **Idioma** (el del sistema o uno de cinco), **Tema** (sistema / claro / oscuro), **Período de reserva predeterminado** (la ventana con la que abren las hojas de reserva, para que tu media jornada o tu de–a habitual venga ya puesto), **Escanear con la cámara frontal** (para tabletas de pared) y **Volver a mostrar los consejos de ayuda**, que recupera todos los consejos contextuales que descartaste. Esos consejos son pequeños carruseles sobre los propios formularios: pasa adelante y atrás por varios consejos en cada pantalla, cada uno con un enlace *Saber más* que salta directamente a la sección correspondiente de esta guía. Tu número de WhatsApp y el interruptor *recibir los mensajes en WhatsApp* también viven en esta pantalla (§6).
- **Avanzado** — el estado de notificaciones push de este dispositivo, el interruptor del **Modo desarrollador** de todo el espacio y la pantalla de trazas **Desarrollador** (§8 pagos).
- **Acerca de** — la versión de la app, el autor (Florian DITTGEN), la licencia open source (0BSD) con el código en GitHub, la política de privacidad, un enlace para informar de errores, y cómo **apoyar el proyecto** (PayPal, Revolut).
- **Cerrar sesión**.

## 13. Notificaciones

Recordatorios de registro, confirmaciones pendientes, decisiones de gastos — y cuando un admin **elimina una de tus reservas** (anulación), tú y los admins recibís aviso. La entrega es local primero; los push del servidor llegan de serie en Android, iPhone/iPad, el navegador y macOS (Firebase Cloud Messaging) — *Ajustes → Avanzado* muestra si el push está activo en este dispositivo. La insignia del icono de la app muestra tus confirmaciones pendientes **más tus mensajes sin leer** — en Android, iPhone/iPad, el Dock de macOS, la barra de tareas de Windows y las web apps instaladas. Los mensajes entre miembros se anuncian **una vez por dispositivo con el remitente y el texto completo** — incluido lo enviado con la app cerrada, anunciado en cuanto la vuelves a abrir. Ese aviso siempre lo genera **la propia app, en local**: el payload push no lleva nunca un nombre, una hora ni una palabra del mensaje (§6), así que lo que viaja por la red solo dice que ha llegado algo.

## 14. Privacidad

Datos mínimos: nombre, correo, plan, reservas, cuenta. Tú controlas tu foto, tu estado y si tu número de teléfono es visible en el directorio; en el plano, un puesto tuyo muestra una inicial, o tu foto donde el propietario activó las fotos de los miembros. Las credenciales de quiosco se guardan solo como hash — una credencial perdida se revoca, no se adivina. Sin rastreo, sin analítica de terceros. El historial financiero se anonimiza, no se borra, al eliminar la cuenta (retención contable).

## 15. Plataformas

Android (Google Play), iPhone/iPad, escritorio — **macOS** (un DMG: arrastra DesKilo a Aplicaciones) y **Windows** (un instalador MSI) generados en cada versión — y el **navegador**: la misma app, sin instalar nada, en la dirección que publique tu espacio. Tus datos siguen a tu cuenta, así que un puesto reservado en el móvil aparece un segundo después en una pestaña del navegador.

El navegador hace más de lo que cabría esperar: **la Web NFC funciona** en navegadores Chromium sobre Android y por HTTPS, que es una forma de configurar desde el navegador de un teléfono la etiqueta de una silla — las apps instaladas de **Android e iPhone leen las etiquetas directamente**, que suele ser más cómodo. Lo que no puede hacer es escanear un QR con la cámara como hace el quiosco. Todo lo demás — plano, reservas, miembros, dinero, facturas, descargas de PDF — es la misma app. Al abrir el DMG de macOS por primera vez, haz clic derecho sobre la app y elige *Abrir*: la compilación aún no está notarizada por Apple, así que un doble clic normal muestra un aviso de Gatekeeper.

## 16. Mensajes
La pestaña **Mensajes** es el centro de mensajería de su espacio: todas las conversaciones en una lista, la más reciente arriba, personas y grupos juntos. Una fila muestra el último mensaje, la hora y cuántos no ha leído. Toque el **lápiz** para empezar una.

**Una persona o un grupo, una sola hoja.** Elija una persona para un chat privado; elija dos o más y **aparece un campo de nombre** — eso es un grupo. El nombre es **único en su espacio**, así nadie tiene que adivinar a qué *Equipo* escribe; si está ocupado, la app lo dice y usted cambia una palabra.

**Distinguirlos de un vistazo.** Una persona muestra su foto en un círculo. Un grupo muestra una **insignia cuadrada** con un símbolo de grupo y — mientras nadie haya escrito — cuántos miembros tiene.

**Dentro de una conversación.** Los mensajes se leen de antiguo a reciente en burbujas, con emojis y **enlaces de referencia** activos: un enlace de reserva abre esa reserva, uno de espacio abre su hoja de reserva, cada uno con *Ver en el plano*. El campo de escritura está debajo. **Mantenga pulsada una burbuja para eliminarla**, con confirmación. Sus mensajes llevan una marca: **gris = entregado**, **azul = leído**.

**Toque el nombre de arriba.** En un chat privado abre el **perfil** de la persona — la reserva de hoy, si ha registrado su entrada, su estado y cómo contactarla. En un grupo abre la **lista de miembros**, donde un administrador del grupo añade o quita personas y cualquiera puede salir. Salir nunca deja un grupo sin administrador.

**La búsqueda** (la lupa) mira en tres sitios: **personas**, **grupos** y las **palabras dentro de los mensajes**. Un resultado le lleva directamente a la persona, al grupo o al mensaje.

**Ni fotos ni archivos.** Los mensajes llevan texto, más enlaces a una reserva o un espacio. Es deliberado: una app de coworking no es un alojamiento de archivos.

**Notificaciones.** Un mensaje *recibido* le avisa y cuenta en la pestaña **Mensajes**; abrir la conversación lo borra. Los mensajes ya no aparecen en la campana, reservada a confirmaciones y eventos. Única excepción: una **difusión a todos los administradores**, que no tiene conversación donde vivir y permanece allí.
