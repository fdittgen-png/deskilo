# Guía de usuario

Todo lo que un miembro, admin o propietario necesita para usar DesKilo. *Otros idiomas: [English](User-Guide) · [Français](Guide-utilisateur) · [Deutsch](Benutzerhandbuch) · [Italiano](Guida-utente).*

> Las capturas de pantalla de esta guía muestran la app en francés — cada pantalla existe idéntica en los cinco idiomas (English, Français, Deutsch, Español, Italiano); cambia el idioma en **Ajustes → Idioma**.
>
> <img src="images/settings-language.jpg" width="200">

## 1. Primeros pasos

### Crear una cuenta

Abre la app y regístrate con tu correo, una contraseña (mínimo 8 caracteres) y un nombre visible. El botón del ojo muestra u oculta la contraseña mientras escribes.

### Crear un espacio — o unirse a uno

Tras iniciar sesión, la pantalla de bienvenida ofrece dos caminos:

- **Crear un espacio de trabajo** — te conviertes en su **propietario**. Elige nombre, país (determina la moneda por defecto) y zona horaria. Después dibujarás tu plano en el editor (§7).
- **Unirse a un espacio** — escribe el **ID del espacio** que te compartieron, o toca **Escanear código QR** y apunta la cámara al QR de invitación colgado en la pared. Te unes con el rol que lleva la invitación (§2).

Una cuenta puede pertenecer a varios espacios; cambia entre ellos en **Ajustes → Perfiles** y **marca uno con la estrella como predeterminado** — es el perfil con el que se abre la app. Todo en la app se refiere al espacio activo.

**Todo se mantiene en vivo.** Lo que cualquiera cambie — una reserva, un miembro nuevo, un ajuste — se envía en segundos a cada dispositivo conectado, incluido el que hizo el cambio. Sin reiniciar, sin tirar para actualizar.

## 2. Roles e invitaciones

DesKilo tiene tres roles acumulativos, más una cuenta de dispositivo:

| Rol | Puede |
|---|---|
| **Miembro** | Registrar entrada/salida, reservar, presentar gastos, ver y gestionar sus propios eventos y su propia cuenta |
| **Admin** | Todo lo de un miembro, más: actuar *por cualquiera* (reservas, pagos, gastos — sujeto a confirmación, §6), aprobar gastos, emitir credenciales de quiosco |
| **Propietario** | Todo lo de un admin, más: editar el espacio físico, definir planes y precios, gestionar roles, quioscos y ajustes del espacio |
| **Copropietario** | *Activo*: los permisos del propietario de inmediato, más la sucesión automática. *Pasivo*: un sucesor en espera, sin permisos adicionales hoy |
| **Quiosco** | Una cuenta de tableta de pared (§9) — solo muestra el plano; los miembros actúan a través de ella con una credencial |

**Cada invitación está ligada a un rol.** En la pantalla *ID del espacio & QR* del propietario hay dos invitaciones, cada una con su propio QR y su propio código:

- **Invitación de miembro** — el propio ID del espacio. Imprímelo, cuélgalo en la pared, compártelo libremente: quien lo escanee o escriba se une como miembro normal.
- **Invitación de admin** — un **código personal de un solo uso**, emitido por un propietario para una persona concreta. Admite solo a esa persona como admin y luego caduca (un código sin usar expira a los 14 días). Emite uno nuevo por admin con *Nuevo código de admin*.

**No existe invitación de propietario — a propósito.** La propiedad solo puede otorgarla un propietario existente, en *Miembros y planes*. Un espacio conserva siempre al menos un propietario. Promover o degradar un **admin** pasa por el flujo de validación (§6) — se aplica cuando los validadores del espacio confirman.

**Los copropietarios mantienen vivo el espacio.** El propietario nombra copropietario a cualquier miembro o admin (*Miembros y planes → el miembro → Copropiedad*), en una de dos variantes: un copropietario **activo** trabaja con los permisos del propietario de inmediato; un copropietario **pasivo** no tiene permisos adicionales hasta el día en que hagan falta. En ambos casos, la sucesión es automática: si el último propietario se va — sale, es eliminado o su cuenta desaparece — el mejor copropietario (activo antes que pasivo) **se convierte en propietario al instante**, en el servidor, sin que haga falta ninguna acción. El propietario también puede ceder el mando deliberadamente en cualquier momento con *Promover a propietario ahora*. Un matiz: las reglas de validación que exigen la firma del *propietario* (§6) se refieren siempre a un propietario literal, no a un copropietario activo.

El QR codifica un enlace que nombra el rol otorgado (`deskilo://join?role=…`). Manipular el enlace no cambia nada — el servidor deriva el rol del propio código: el ID del espacio siempre une como miembro, y una invitación personal une exactamente en el rol con el que se emitió, una sola vez. Un código de admin reenviado ya usado — o caducado — no admite a nadie.

**Invitar por mensaje** (*Invitar a alguien*): cada envío por WhatsApp/SMS/compartir emite su propio código personal de un solo uso y compone un mensaje listo en el idioma del invitado. El destinatario puede simplemente copiar el mensaje completo y pegarlo en el campo de unión de la app — el código se detecta automáticamente.

## 3. El plano (pestaña Plano)

El plano muestra la planta activa de tu espacio: oficinas, mesas y asientos, con código de colores — **libre**, **reservado**, **ocupado**, **mío**, **bloqueado**. Se abre **al instante con los últimos datos conocidos** y se actualiza en segundo plano — con un Wi-Fi inestable sigues viendo el estado más reciente en lugar de una pantalla vacía. Los asientos ocupados muestran el nombre de pila de quien está, una **insignia de registro** cuando ha hecho check-in, y un **punto verde** cuando está en línea en la app.

El plano puede parecerse a tu espacio real: el propietario puede poner una **foto de la sala como fondo de la planta** y colocar **imágenes de ilustración redimensionables** (plantas, sofás…) sobre la cuadrícula. Un control de **transparencia de mesas** en los ajustes deja ver la foto a través de las mesas dibujadas.

Moverse:

- El lienzo **se ajusta solo** a tu planta al abrir o al girar el dispositivo; **pellizca para hacer zoom** o usa los botones **+ / −**, arrastra las **barras de desplazamiento** en los bordes y toca el botón de **ajuste** para recentrar.
- Elige la planta en el **menú de plantas** (desplegable compacto); el icono de reloj devuelve la línea de tiempo a **ahora**.
- En **horizontal**, los controles pasan a un panel lateral y el plano llena la pantalla — útil en tabletas.

Reservar desde el plano:

- **Registro espontáneo**: toca un asiento libre → la hoja propone *ahora* hasta el fin por defecto del espacio → confirma. Si alguien reservó ese asiento más tarde, tu hora de fin se recorta y se te avisa.
- **Registro sobre reserva**: registrarse significa *estás aquí* — la ventana abre **15 minutos antes** de tu inicio y se cierra al final de la reserva. Fuera de ella el botón está desactivado y dice cuándo abre; navegar un horario futuro nunca ofrece un registro en vivo. Los admins pueden registrar a un miembro presente en su asiento (mientras *reservar por otros* esté activo).
- **Salida**: manual — o, si el propietario activa el **auto registro/salida**, las reservas olvidadas se completan solas al final del día: las nunca tocadas cuentan como asistidas de su inicio a su fin, y las salidas olvidadas se cierran al final propio de la reserva.
- **Espacios enteros**: **doble toque** en una mesa, una sala o una zona libre del suelo para actuar sobre la **mesa, oficina o planta entera** — la misma hoja que al escanear su tarjeta QR (§4), con el mismo selector de periodo y las mismas opciones de repetición que un puesto.
- **Línea de tiempo**: elige una ventana de→a (o Mañana / Tarde / Día completo, según la granularidad del espacio) para ver la ocupación en cualquier momento futuro.
- Los asientos pueden llevar **accesorios** (monitor, mesa elevable…), algunos con suplemento por media jornada que aparece en tu extracto.
- Las reservas cuentan contra tus **días mensuales** (§8) — pasado tu plan, la app bloquea o cobra, según lo que el propietario configuró para ti.

## 4. Reservas (hub Reservar)

Abre el hub **Reservar** (botón central). Una banda de fechas elige el día; los chips de ventana, la hora; luego cuatro vistas:

- **Plano** — el plano filtrado a tu ventana; toca un asiento libre para reservarlo.
- **Día** — cada asiento como fila de cronología del día elegido; toca un tramo libre para reservar, tu propio bloque para ver detalles.
- **Semana** — una cuadrícula asiento × día de toda la semana ISO; encuentra una media jornada libre de un vistazo y tócala para reservar.
- **Mes** — un calendario de disponibilidad: mesas libres por día en todas las plantas; toca un día para entrar en su vista Día.

**Un sitio a la vez**: solo puedes mantener una reserva activa por periodo — reservar o registrarte en otro sitio mientras corre otra se rechaza, y un registro cierra cualquier registro anterior cuya reserva ya terminó. Los admins y propietarios pueden **anular**: tocar un puesto ocupado o reservado ofrece *Quitar la reserva (anular)* — la reserva se elimina y el miembro y todos los admins son notificados por el feed de eventos.

Las reservas siguen la **regla de granularidad** del espacio — medias jornadas, días completos u horas libres sobre la rejilla de minutos del propietario. Respetan los **días de apertura** y los **días de cierre**, y las reglas de reserva (horizonte, duración máxima, plazo de cancelación). ¿Necesidad recurrente? Reserva una **serie** (diaria, laborables, semanal) — los días cerrados y conflictos se saltan y se informan.

La pestaña **Calendario** muestra tus reservas por mes — tus días en **rojo**, los de otros en **azul**, hoy rodeado — con cronología por día. En horizontal, calendario y cronología usan el diseño dividido.

### Escanear un código de espacio

Cada puesto, mesa, oficina y planta puede llevar una **tarjeta QR** impresa (§7). Toca el **botón de escaneo** en el hub Reservar, apunta la cámara a la tarjeta — o escribe su código — y la app identifica el espacio y muestra exactamente lo que *tú* puedes hacer allí:

- **Tarjeta de puesto** — reserva o regístrate en ese puesto concreto, al momento (la ventana de hoy: mañana / tarde / día completo donde el espacio usa medias jornadas; si no, desde ahora para las próximas horas).
- **Tarjeta de mesa** — los puestos de la mesa con su estado en vivo; elige uno libre.
- **Tarjeta de oficina o planta** — si el propietario la hizo reservable, la función *Reservas de oficina y planta* está activada **y** tienes el derecho personal (§7) — los propietarios y admins siempre lo tienen — puedes reservar o registrarte en la **oficina o planta entera** — con el mismo selector de periodo (mañana / tarde / día completo, u horas libres) y las mismas opciones de **serie** que un puesto; se muestra su precio por media jornada y entra en tu factura. Si no, la hoja te dice por qué, y una oficina recae en sus puestos.

**Los conflictos protegen en ambos sentidos:** una oficina o planta no puede reservarse mientras algún puesto de su interior ya esté reservado en esa ventana — y ningún puesto puede reservarse mientras su oficina o planta esté reservada entera.

## 5. Directorio de miembros (pestaña Miembros)

Mira quién forma tu comunidad:

- Cada tarjeta muestra su **foto** (o inicial), **rol**, **estado personalizado** («en Berlín hasta el viernes…»), un indicador **en línea / visto por última vez**, y un **chip de reserva**: asiento registrado, reservado ahora, o próxima reserva.
- Toca un miembro para su **ficha de detalle** — con sus próximas reservas.
- **Desliza** un miembro para escribirle por **WhatsApp**; el **botón de grupo** abre el grupo de WhatsApp de la comunidad (definido por el propietario).
- Define tu foto, estado y visibilidad del teléfono en **Ajustes**.
- Los admins y propietarios ven además el **correo** de cada miembro bajo el nombre — los miembros normales no: el canal de contacto entre miembros sigue siendo el número de WhatsApp compartido voluntariamente.

## 6. Eventos y confirmaciones (icono de campana)

El hilo de eventos es la pista de auditoría del espacio: reservas creadas/cambiadas/canceladas, pagos registrados, gastos presentados, solicitudes de días extra, cambios de rol. Los miembros ven sus propios eventos; admins y propietarios lo ven todo.

**El protocolo de confirmación:** cuando un admin hace algo *por otra persona* — te reserva un asiento, registra tu pago — queda **pendiente hasta que confirmes**. Lo pendiente se fija arriba con botones de aceptar/rechazar y recibes una notificación. Lo que haces sobre ti mismo nunca requiere confirmación.

**Quórum de validación:** para asuntos de dinero y cambios de rol, el propietario define *quién* debe aprobar y *cuántas* aprobaciones hacen falta. **Nadie valida su propio evento** — solo otra persona puede; sin otro validador, la solicitud simplemente espera. Las solicitudes sin respuesta caducan a los 7 días — nada costoso se concede jamás en silencio, ni uno mismo se lo concede.

El propietario afina esto por **dominio** en **Ajustes → Reglas de validación**: pagos, gastos, servicios, medias jornadas extra, cambios de rol, reservas y ajustes tienen cada uno su propia regla (o heredan la regla por defecto). Una regla define el número de validaciones requeridas, *qué* admins pueden validar (todos, o algunos concretos) y si el propietario debe firmar siempre.

<p><img src="images/validation-rules.jpg" width="240"> <img src="images/validation-rule-edit.jpg" width="240"></p>

*Izquierda: una regla por dominio, heredando de la regla por defecto. Derecha: edición de una regla — validaciones requeridas, validadores autorizados, firma del propietario.*

## 7. Para propietarios: editor y ajustes

Toda la administración vive en **Ajustes → Administración**. Una regla que conviene conocer: **la entrada de ajustes de una función solo aparece mientras esa función está activada** — desactiva *Pagos en línea* en **Funciones** y su pantalla de configuración desaparece con ella (y vuelve al reactivarla). La entrada **Funciones** siempre está presente, así que siempre puedes volver a activar un módulo.

<p><img src="images/settings-administration.jpg" width="240"></p>

- **Editor** (barra de la app): dibuja tu espacio en una cuadrícula — plantas, oficinas, mesas, asientos (con orientación, tipo de silla y equipamiento), bloqueo de asientos por mantenimiento. Añade una **foto de fondo** por planta e **imágenes de ilustración** que puedes mover y redimensionar. Borrar algo con reservas futuras obliga a resolverlas antes.
- **ID del espacio & QR**: tus invitaciones ligadas a rol (§2). Puedes sustituir el ID generado por uno memorable (4–20 letras/dígitos), copiarlo o compartir el QR como PNG.
- **Disponibilidad**: días de apertura, días de cierre y la granularidad — horas de inicio y fin libres, una rejilla de minutos (5/15/30/60), medias jornadas o solo días completos.
- **Funciones**: activa o desactiva módulos enteros por espacio — calendario, eventos, dinero, servicios, exportación PDF, series, reservar por otros, push, bloqueo de asientos por admins, suplementos de accesorios, **pagos en línea**, **facturas**, **reservas de oficina y planta**, **modo quiosco**, **credenciales RFID/NFC**, **directorio de miembros**, **integración con WhatsApp**, **códigos QR de espacios**, **copropietarios**, **exportación de datos**, **auto registro/salida**. Desactivar un módulo elimina *todas* sus pantallas y botones para todos los miembros.

  La lista es **jerárquica**: una función que necesita otra aparece indentada bajo ella con una nota *Requiere…*, y queda atenuada mientras su padre está desactivado — *Dinero* lleva los servicios, los suplementos de accesorios, los pagos en línea y las facturas; *Reservas de oficina y planta* lleva el derecho de asignación por admins; *Modo quiosco* lleva las credenciales RFID/NFC; *Directorio de miembros* lleva la integración con WhatsApp. Desactivar un padre saca todo su subárbol de la app; la elección guardada del hijo vuelve intacta cuando el padre regresa.

<p><img src="images/workspace-id-qr.jpg" width="220"> <img src="images/availability-granularity.jpg" width="220"> <img src="images/features-toggles-1.jpg" width="220"> <img src="images/features-toggles-2.jpg" width="220"></p>

- **Miembros y planes**: toca un miembro para abrir su **ficha de gestión** — añadirle un servicio, fijar su porcentaje de suscripción, elegir su **política de exceso** (§8), limitar sus **reservas simultáneas**, emitir **credenciales** (§9), promover/degradar admin, convertir la cuenta en **quiosco**, o pausar la membresía. Cada fila muestra el **correo** del miembro bajo su nombre.

<p><img src="images/member-management-sheet.jpg" width="220"> <img src="images/member-subscription.jpg" width="220"> <img src="images/member-reservation-limit.jpg" width="220"></p>

*La ficha de gestión, el diálogo de porcentaje de suscripción y el tope de reservas por miembro.*

- **Facturación**: bandas de tarifas de las suscripciones porcentuales, tarifas de exceso, niveles de suscripción ofrecidos (con un valor libre negociado opcional) — y **paquetes de días** (un número de días por un precio) para miembros con política de paquete.
- **Servicios** y **Accesorios**: los catálogos detrás del §8 — extras definidos por el propietario (taquillas, impresión…) y equipamiento por asiento con suplementos opcionales por media jornada. Ambos son listas simples con un botón **+**.

<p><img src="images/billing-bands-levels-packages.jpg" width="220"> <img src="images/services-catalog.jpg" width="220"> <img src="images/services-new-service.jpg" width="220"> <img src="images/accessories-catalog.jpg" width="220"></p>

*Facturación (bandas, niveles, paquetes de días) · el catálogo de Servicios y su formulario de creación · el catálogo de Accesorios. Un admin añade un consumo de servicio para un miembro desde la ficha de gestión del miembro:*

<p><img src="images/member-add-service.jpg" width="220"></p>

- **Ajustes del espacio**: nombre, país/moneda, zona horaria, instrucciones de pago (IBAN, PayPal.me, Wero, Lydia, Wise), enlace del grupo de WhatsApp, **transparencia de mesas**, exportaciones — y la **zona de peligro**: un **reinicio total del espacio** (borra reservas, dinero y plano; conserva configuración y miembros), protegido escribiendo «I agree».
- **Importar/exportar**: toda la configuración viaja como **archivo XML** — cópiala, úsala de plantilla o migra una instancia autoalojada. También puede generarse un **PDF de configuración** (miembros, plano, precios, funciones). Un **libro de Excel** exporta los propios datos vivos — espacio, plantas, mesas, asientos, miembros, reservas, registros, pagos, servicios y facturas, una pestaña cada uno (función *exportación de datos*). Cada exportación se guarda en la carpeta de **Descargas** de tu dispositivo.

### Códigos QR de espacios y reservas de espacios enteros (propietarios)

Cuatro pasos convierten «escanear el código de la mesa» en el flujo de reserva diario (§4):

1. En el **editor**, marca una oficina o una planta como **Reservable en su totalidad** y dale un **precio por media jornada** (la ficha de propiedades de la oficina / el menú de la planta).
2. Activa **Reservas de oficina y planta** en **Funciones** (desactivada por defecto).
3. Concede a cada miembro autorizado **«Puede reservar una oficina o planta entera»** — propietarios y admins lo fijan en la ficha de gestión del miembro, nunca para sí mismos.
4. Imprime las tarjetas: **Ajustes del espacio → Códigos QR de espacios (PDF)** — un QR tamaño tarjeta de crédito por **puesto, mesa, oficina y planta**, diez por página A4, guardado en Descargas. Recórtalas y pega cada tarjeta en su espacio.

Una reserva de oficina cubre **todas las mesas de su interior**; una reserva de planta cubre la planta entera. Ambas solo son posibles mientras nada de su interior esté reservado — y aparecen como líneas propias en la factura del miembro.

### Copropietarios (propietarios)

Asegúrate de que la comunidad nunca dependa de una sola cuenta:

1. Abre *Miembros y planes → el miembro → **Copropiedad*** y elige **activo** (permisos de propietario ya) o **pasivo** (sucesor en espera).
2. Cede el mando en cualquier momento con ***Promover a propietario ahora*** — el copropietario se convierte en propietario de pleno derecho junto a ti.
3. Si el último propietario abandona alguna vez el espacio, el mejor copropietario es **promovido automáticamente** en el servidor — activo antes que pasivo. Esta red de seguridad funciona incluso con el interruptor de la función *Copropietarios* desactivado (el interruptor solo oculta los botones de nombramiento).

### Configurar los pagos en línea (propietarios)

Cada comunidad cobra en su **propia** cuenta de proveedor; la app nunca guarda las claves secretas en ningún dispositivo — están en el servidor.

1. Abre **Ajustes → Pagos en línea** (solo propietario).
2. Elige un proveedor y pega sus claves desde su panel:
   - **PayPal** — Client ID, Secreto, Entorno (empieza por *sandbox*), ID de webhook, URL de retorno (PayPal Developer → tu app REST).
   - **Tarjeta (Stripe)** — Clave secreta, Secreto de firma del webhook, URL de retorno (Stripe → claves API / Webhooks).
   - **Mollie** — Clave API, URL de retorno (ofrece iDEAL, Bancontact, tarjetas…).
   - **Wero (con Mollie)** — la misma clave API de Mollie, con Wero activado en tu cuenta Mollie.
3. **Guarda** — aparece un chip verde *Configurado*. Activa la función **Pagos en línea** (Ajustes → Funciones) y los miembros verán **Pagar en línea** en una factura pendiente. (La propia entrada de ajustes *Pagos en línea* solo se muestra mientras la función está activada.)

<p><img src="images/payment-config-paypal-stripe.jpg" width="240"> <img src="images/payment-config-mollie-wero.jpg" width="240"></p>

Un secreto guardado no se vuelve a mostrar — deja el campo en blanco para conservarlo, escribe para reemplazarlo, **Eliminar** para quitar el proveedor. Las comisiones son del proveedor (típicamente ~1,5–3 % por pago, sin cuota mensual); DesKilo no añade nada, y la transferencia/IBAN manual sigue siendo gratis.

Si un pago no arranca, activa **Ajustes → Avanzado → Modo desarrollador** y abre la pantalla **Desarrollador**: la traza de *pagos* muestra exactamente qué proveedores están configurados y qué campos faltan todavía.

<p><img src="images/developer-payment-traces.jpg" width="240"></p>

#### Los paneles de los proveedores, paso a paso

Mantén **los entornos de prueba y de producción estrictamente separados**: cada proveedor tiene claves distintas por modo, y todas las claves que pegues en DesKilo deben pertenecer al mismo modo. En las URL de abajo, `<project-ref>` es la referencia de tu proyecto de Supabase (las instancias autoalojadas usan su propia URL).

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

### Configurar las credenciales RFID / NFC (propietarios)

Las tarjetas físicas permiten registrarse con un toque — sin teléfono.

1. Abre **Ajustes → Credenciales RFID / NFC** (solo propietario). Activa **Activar registro por credencial NFC** y lee la línea de **estado del dispositivo** — distingue entre *listo*, *NFC desactivado en los ajustes de Android* y *sin hardware NFC* (los iPad no tienen).
2. Da una tarjeta a cada miembro: **Miembros y planes → el miembro → Credenciales → Registrar tarjeta**, y acerca su tarjeta al dispositivo. Vale cualquier tarjeta con chip legible (MIFARE, NTAG…). Los miembros también pueden hacerlo **ellos mismos**: **Ajustes → Mi credencial** emite su credencial QR imprimible y registra su propia tarjeta — sin necesidad de admin.
3. Úsalas en un **quiosco** (§9): el miembro acerca la tarjeta para reservar o registrarse. Revoca una tarjeta perdida desde la misma ventana de Credenciales; **desliza una credencial revocada hacia la derecha para eliminarla** definitivamente.

Las credenciales pertenecen a **un solo espacio** — la ventana indica en cuál estás registrando, así que registra la tarjeta en el espacio cuyo quiosco la leerá. La misma tarjeta física puede servirte en varios espacios. Una credencial QR guardada **como PDF** imprime diez copias tamaño tarjeta de crédito en una página A4 — con repuestos incluidos.

<p><img src="images/nfc-config.jpg" width="240"> <img src="images/member-badges-dialog.jpg" width="240"></p>

*La pantalla de configuración NFC (interruptor del espacio + estado NFC de este dispositivo) y la ventana de Credenciales de un miembro: revocar, registrar una tarjeta o emitir una nueva credencial QR.*

## 8. Dinero (pestaña Dinero)

Tu cuenta responde *qué debo, qué me deben* — y *cuánto puedo reservar aún*:

- **Este mes** — la tarjeta encima de tu factura: cuántos **días** incluye tu suscripción este mes, cuántos has **usado**, cuántos **quedan**, con barra de progreso. Una mañana reservada cuenta 0,5 días. El derecho mensual sigue los días de apertura del espacio y tu porcentaje.
- **Cuando se acaban tus días**, lo que ocurre es elección del propietario, por miembro:
  - **Bloqueado** (por defecto) — no más reservas; pide a un admin, o solicita **medias jornadas extra** desde la pestaña Dinero (los validadores aprueban; los días concedidos se cobran igualmente a la tarifa de exceso).
  - **Pago por uso** — sigues reservando; cada día extra se cobra a la tarifa de exceso de tu banda (mostrada en la tarjeta).
  - **Paquetes** — toca **Comprar un paquete** y elige uno de los packs de días del propietario; tus días aumentan al momento y el precio entra en la factura del mes.
- **Cargos**: suscripción mensual (plan porcentual), exceso, consumo de servicios, suplementos de accesorios, paquetes de días.
- **Abonos**: gastos aprobados, pagos registrados, ajustes.
- **Extractos**: mensuales, con estado **saldado / pendiente**, exportables como **factura PDF** guardada localmente.
- **Facturas**: donde el espacio emite facturas (más abajo), las tuyas están siempre disponibles en **Dinero → Facturas** — toca una para leerla en la app (posiciones, saldo, estado), descarga el PDF y, en espacios de la UE, exporta la factura electrónica legible por máquina (XML).
- **Pagar**: DesKilo registra los pagos; una factura pendiente muestra las **instrucciones de pago** del espacio (el IBAN se copia con un toque, PayPal.me se abre directamente). Registra un pago («he pagado») con su método, la **fecha en que se movió el dinero** (hoy por defecto) y el **mes que salda** (el mes en curso por defecto, un paso atrás para atrasos, uno adelante para un anticipo) — la otra parte confirma. Ese mes decide en qué factura y en qué extracto entra el abono. Si el espacio activó los **pagos en línea** y su servidor está configurado, el botón **Pagar en línea** permite abonar el importe adeudado al instante — con **PayPal, tarjeta (Stripe), Mollie o Wero**, según lo que el espacio haya activado (si hay varios, se muestra un selector).
- **Gastos**: ¿compraste café para el espacio? Presenta el gasto — otro admin lo aprueba (sin autoaprobación) y el importe se abona en tu próximo extracto.
- **Servicios**: extras definidos por el propietario (taquillas, impresión…) cuyo consumo llega a tu extracto tras tu confirmación.

### Facturación (propietarios y admins de facturación)

*Los propietarios emiten facturas; los admins también cuando el propietario concede la delegación **Los admins emiten facturas**. La función **Facturas** cuelga de Dinero en la lista de funciones (§7).*

Una factura en DesKilo se genera, nunca se redacta: sus posiciones se **derivan exclusivamente de los datos registrados del mes** — suscripción, exceso, suplementos, servicios, paquetes — menos los pagos y abonos del mes, de modo que la línea final **es el saldo adeudado**. Cada documento captura las direcciones postales del espacio y del miembro (configura la tuya en **Ajustes → Dirección**; la dirección del espacio está en los ajustes del espacio) y se **firma digitalmente** al emitirse — después ya no cambia nunca. Un **anexo detallado** (el libro mayor y la asistencia del mes) puede adjuntarse con un interruptor al emitir.

Quien emite abre **Dinero → Facturas** y llega a un hub de tres pestañas bajo una franja de resumen en vivo:

- **Por facturar** — cada miembro cuyo mes anterior tiene datos facturables y aún sin factura, con el total del mes: emite por miembro (con vista previa de las posiciones derivadas) o **Facturar todo** de una pasada — una confirmación anuncia antes el número, el mes y el total. **Una factura activa por miembro y mes** — un mes solo vuelve a ser facturable cuando su factura fue anulada. La hoja de emisión abre en el **mes cerrado** (aquel cuyos números ya no se mueven); si eliges el mes en curso, avisa, porque un mes solo se factura una vez.
- **Abiertas** — facturas emitidas a la espera de cobro, las más antiguas primero; lo que lleva más de 30 días esperando se pone en rojo, en la tarjeta y en la franja de resumen. **Toca una tarjeta para leer la factura**; los botones actúan sobre ella: **Enviar un recordatorio** (registra el recordatorio y comparte el PDF con un mensaje — la tarjeta muestra *Recordado ×N*), **Marcar como errónea** (anula la factura para corregirla: pasa al archivo tachada, y una **sustituta** vuelve a derivar el mismo mes desde los datos corregidos, referenciando la original) y **Marcar como pagada**.
- **Archivo** — facturas cerradas, pagadas o anuladas, filtrables por miembro y mes y ordenables; bajo los filtros se indica cuántas facturas coinciden y **Borrar filtros** devuelve el archivo completo. Cada fila lleva su estado, su mes y su importe, con **Descargar PDF** ahí mismo. **Toca una fila para abrir la factura** — posiciones, saldo, a quién se facturó, en qué estado está, a qué factura sustituye o por cuál fue sustituida, el pago que la cerró, los recordatorios enviados, su firma — y cada acción que aún permite, con su nombre: compartir el PDF, exportar la **factura electrónica (XML)**, recordar, marcar como pagada, marcar como errónea, emitir una sustituta.

**Marcar como pagada significa emparejar un pago real.** El diálogo lista los pagos registrados del miembro — transferencias anotadas y pagos en línea confirmados — y tú emparejas la factura con uno de ellos; no hay ningún importe que teclear. ¿Pagó **de más**? Crea una **nota de crédito** por el exceso (un abono en la cuenta del miembro) o fuerza la aceptación con una nota obligatoria. ¿Pagó **de menos**? Acéptalo con una nota obligatoria. Todos los que tienen acceso a la facturación reciben notificación de las facturas pagadas, y el propietario puede poner una regla de validación **Pago de factura** (§6): el emparejamiento espera entonces al quórum — un rechazo reabre la factura.

**Una factura pagada es definitiva.** Una vez emparejada no puede anularse, sustituirse ni alterarse — las correcciones ocurren antes del pago, anulando la factura abierta y emitiendo su sustituta. Un pago que **no** cubrió el total, aceptado con una nota, aparece como **parcialmente pagada**, no como pagada.

**Proforma.** Ambas pestañas del hub ofrecen una proforma: en **Por facturar** representa las posiciones derivadas del mes como presupuesto — sin número, sin firma, sellada PROFORMA, y **no se emite nada**; en **Abiertas** vuelve a generar la factura emitida como solicitud de pago que no puede pasar por el original. En las tarjetas Abiertas cada acción es un icono con descripción emergente (anular · proforma · recordatorio · marcar pagada) — tres etiquetas seguidas se salían de la tarjeta.

**Sellos.** Una factura anulada lleva un gran **ERRÓNEA** en diagonal en cada página de su PDF, en gris claro sobre el contenido: no se confunde con un documento válido en un escritorio ni en una fotocopia. El mismo sello dice **PROFORMA** en un presupuesto y **COPIA** en cualquier factura generada por alguien que no sea su emisor — el original queda en el espacio.

**El registro.** El icono de lista en la barra de Facturas abre un libro con una línea por factura: **fecha · nombre · importe · estado**, ordenado por fecha (toca la cabecera Fecha para invertirlo), con la suma al pie y un selector de **año** cuando hay más de uno.

**Entregar el periodo a tu asesoría.** Desde el registro, quien emite exporta un archivo **SAF-T** — el *Standard Audit File for Tax* de la OCDE, el XML que leen los programas de contabilidad y las administraciones tributarias. Cubre exactamente lo que muestra el registro: elegir 2026 da el archivo de 2026 — la empresa tal como la declaran tus propias facturas, cada cliente, cada factura con sus líneas y totales, y los pagos que las liquidaron. Las facturas anuladas siguen dentro, marcadas como *anuladas*: un archivo de auditoría nunca borra lo que ocurrió. Lo que deja fuera a propósito es el **plan contable**: DesKilo no inventa números de cuenta, porque un código equivocado hay que descontabilizarlo a mano. Tu asesoría asigna las facturas a sus propias cuentas — es su trabajo y le lleva un minuto.

**Francia: el FEC.** Un espacio francés tiene una segunda opción, el **FEC** (*Fichier des Écritures Comptables*) — el archivo que allí exige legalmente una inspección. No es XML: un archivo plano separado por tabuladores, hecho de **asientos contables**, nombrado `<SIREN>FEC<AAAAMMDD>.txt`, con las 18 columnas obligatorias en su orden obligatorio. Al estar hecho de asientos no puede evitar los números de cuenta: la exportación los pide primero — precargados con el plan contable francés (411 clientes, 706 servicios, 512 banco) y corregibles. Cada factura carga su derecho de cobro contra el ingreso por el importe **bruto**; los créditos que descontó y el pago que la liquidó pasan por banco con su propia fecha, referenciados al número de factura. Las facturas anuladas no aparecen: una anulada antes del pago nunca se contabilizó, así que no hay nada que revertir. La columna *nombre* sigue a quien lee — quien emite repasa miembros, un miembro repasa sus propios números de factura. Los miembros solo ven lo que les concierne: las emitidas, nunca una anulada.

### Adónde debe ir la factura electrónica (UE)

La acción **Factura electrónica (XML)** abre una hoja que responde a eso para el país del espacio, antes de entregarte el archivo: por qué canal lo esperan tus clientes empresa, si se interpone una plataforma y por qué canal pasan los compradores públicos. En la Unión coexisten cuatro modelos:

- **Peppol** — un punto de acceso entrega el archivo al cliente; sin plataforma pública de por medio. Así funciona exactamente la obligación B2B belga, y por Peppol se llega a los compradores públicos en toda la UE (la Directiva 2014/55/UE hace que cada administración pueda recibir una factura EN 16931).
- **Plataformas autorizadas** — Francia: eliges una *plateforme agréée* (la antigua PDP), que transporta la factura y comunica los datos a la administración tributaria. El portal público es un directorio, no un buzón. El sector público sigue en **Chorus Pro**.
- **Plataformas de clearance** — Italia (**SdI**, FatturaPA), Polonia (**KSeF**, FA(3)), Rumanía (**RO e-Factura** vía el SPV, CIUS-RO): la plataforma recibe la factura *primero* y luego la reenvía; el envío directo al cliente no existe. Cada una impone su propia sintaxis, así que la hoja advierte de que el archivo EN 16931 que exporta DesKilo no es el que aceptan — úsalo para Peppol, compradores públicos y clientes extranjeros, y deja que tu plataforma o tu asesoría convierta.
- **Sin canal obligatorio** — Alemania hoy: recibir es obligatorio desde 2025 y emitir llega por fases, pero un adjunto por correo es una factura electrónica válida; las sintaxis esperadas son XRechnung y ZUGFeRD. Sector público: **OZG-RE / ZRE**, o Peppol.

**Factur-X — un archivo, dos lectores.** La hoja de factura electrónica ofrece primero **Factur-X (PDF)**: un PDF de factura de aspecto normal con la factura legible por máquina *dentro* (los datos EN 16931 en formato CII, el que impone el formato). Una persona lo abre y ve la factura; una plataforma lo abre y encuentra `factur-x.xml`. Es lo que realmente intercambian la mayoría de las pequeñas empresas francesas y alemanas, y no necesita un segundo archivo. El **XML** suelto sigue disponible debajo, para las plataformas que lo piden desnudo.

**Enviarla sin salir de la app.** El propietario registra la plataforma del espacio en *Ajustes del espacio → Identidad legal → **Plataforma de facturación electrónica***: una URL de subida y un token. Sirve cualquier plataforma que acepte una subida con credencial — una plataforma autorizada, un punto de acceso Peppol, una plataforma nacional. El token se guarda en el servidor, nunca vuelve a un teléfono, y la app solo puede decirte que hay uno guardado. Una vez configurada, la hoja empieza por **Enviar a la plataforma**: el documento Factur-X sale directamente, y la hoja de detalle de la factura conserva cuándo salió, qué respondió la plataforma y el identificador que devolvió. Cada intento queda registrado — aceptado, rechazado o no transmitido — porque un documento que *quizá* salió es peor que un envío fallido.

DesKilo sigue sin transmitir nada por su cuenta: genera el documento y lo entrega a la plataforma que elegiste.

**Ensayar sin riesgo.** Un espacio puede registrar, junto al punto de producción, **puntos de prueba** (el UAT de la plataforma o un destino dev). Con el **modo desarrollador** del espacio activado (un ajuste de todo el espacio que solo propietarios y admins pueden cambiar, en Ajustes → Avanzado), el envío ofrece elegir el entorno, un envío de prueba queda marcado como tal en el historial de transmisiones de la factura, y el punto de producción nunca se usa para un ensayo — un entorno de prueba sin configurar simplemente rechaza, sin recurrir al de producción.

**Antes de la primera exportación, completa la identidad legal.** En *Ajustes del espacio → **Identidad legal y facturación electrónica*** el propietario declara el **régimen de IVA** y el número que la norma exige con él: fuera del ámbito del IVA, un **número de registro** (SIREN, HRB, CIF…); con exención de pequeña empresa, un **número de IVA** y el motivo por el que no se cobra. Los miembros añaden su **país** — y su número de IVA si facturan como empresa — junto a su dirección en *Ajustes → Dirección*. DesKilo lo comprueba **antes** de generar el archivo y se niega nombrando lo que falta: una factura que la plataforma rechaza es peor que ninguna. Un espacio **sujeto a IVA** exporta como cualquier otro, siempre que haya configurado sus **tipos de IVA** (sección siguiente): con tipos, la factura lleva un desglose real; sin ellos, DesKilo se niega antes que declarar un cero que no cree.

Los calendarios también se mueven: consulta a tu administración antes del plazo que te afecte.

### IVA (propietarios)

**En DesKilo los precios incluyen IVA.** Lo que escribes como precio de cuota, de servicio o de bono de días es lo que paga el miembro. Activar el IVA no cambia ningún importe debido: dice qué parte de ese importe es impuesto. Por eso una cuenta, un extracto y una cuota no se mueven al añadir tipos, y por eso ningún total hay que cuadrarlo.

**Configurar los tipos.** *Ajustes del espacio → Identidad legal y facturación electrónica → **Tipos de IVA***. Una lista vacía significa que el IVA está desactivado: así empieza todo espacio. **Usar los tipos habituales** rellena la lista con el general, el reducido y el superreducido de tu país como primer borrador: un punto de partida, no asesoramiento fiscal — los tipos cambian, y qué prestación va a qué tipo es una pregunta para tu asesoría. Un tipo es el **predeterminado** (la estrella): cuotas, excesos, suplementos y regularizaciones lo usan, igual que todo servicio sin tipo propio. Quitar un tipo nunca lo borra: el que una factura o un servicio siga usando se conserva, desactivado, para que nada se vuelva a gravar en silencio.

**Tipos por elemento.** Un servicio (*Servicios*) y un bono de días (*Facturación → Bonos*) llevan su propio tipo, elegido en su formulario; déjalo en **Tipo por defecto del espacio** y seguirá al predeterminado. El campo de IVA solo aparece cuando el espacio tiene tipos.

**Qué cambia en un documento.** Una factura emitida después de crear los tipos lleva el desglose tal como se emitió: la tabla de posiciones gana una columna de tipo, y sobre el total el PDF muestra la **base** y una línea por tipo. La ficha de la factura en la app dice lo mismo. La **factura electrónica (XML)** lleva lo que exige EN 16931 — un subtotal de impuesto por tipo, los importes sin impuesto, el número de IVA del vendedor (BR-S-02) — tanto en UBL como en CII: un documento Factur-X también es válido para un vendedor sujeto a IVA. **SAF-T** declara cada tipo en su tabla de impuestos y registra cada línea sin impuesto con su cuota al lado; el **FEC** registra el derecho de cobro bruto contra el ingreso neto más una cuenta de **IVA recaudado** (445710 por defecto, y modificable — en el diálogo de exportación o de una vez en la pantalla de identidad legal).

**Una factura ya emitida no cambia nunca.** Lleva los tipos, la identidad y los importes con los que se firmó: eso es lo que la hace una factura. Añadir tipos hoy no pone IVA en el documento del mes pasado, y completar tu identidad legal hoy no le añade tu número de registro. Si un documento debe llevar los datos nuevos, márcalo como **erróneo** y emite una **sustitución**: la cadena de corrección se ve en ambos documentos, que es exactamente lo que quiere ver una inspección.

## 9. Modo quiosco (tableta de pared)

Monta una tableta Android o un iPad junto a la puerta y deja que la gente se registre al entrar:

1. El propietario crea una cuenta normal para el dispositivo, la une al espacio y la marca como **quiosco** en *Miembros y planes*.
2. **El modo quiosco nunca arranca solo.** En cada inicio de la app la tableta pregunta *¿Iniciar el modo quiosco?* — confirma y la tableta se bloquea: solo el plano a pantalla completa, botón de atrás desactivado, la app se ancla para que no pueda abrirse nada más; salir del modo quiosco implica reiniciar la tableta. Elige *Ahora no* y la app se abre normalmente — útil para la configuración. La propia designación de quiosco puede revertirse en cualquier momento: en el dispositivo, en **Ajustes → Dispositivo quiosco**, o por el propietario en *Miembros y planes*.
3. Cada miembro lleva una **credencial** — emitida por un admin (*Miembros y planes → Credenciales*) o por el propio miembro (**Ajustes → Mi credencial**, §7): una **credencial QR** imprimible y/o su **tarjeta RFID/NFC**.
4. En el quiosco, toca un asiento (o **Esta planta**) → **Registrarse**, **Reservar** o **Salir** → presenta la credencial:
   - **Acerca la tarjeta RFID/NFC.** Mientras el lector de tarjetas está armado, la cámara permanece apagada; si el NFC está desactivado o no existe, la hoja lo dice explícitamente.
   - O toca **Escanear la tarjeta QR** — la tableta lee la credencial impresa **con su propia cámara** (la frontal por defecto, ya que la lente trasera de una tableta de pared mira a la pared; cámbialo en *Ajustes → Escanear con la cámara frontal*). Un lector USB/Bluetooth o escribir el código también funcionan.
5. **Nada ocurre sin tu visto bueno:** el quiosco identifica la credencial, cierra los lectores y muestra un resumen — *a quién* reconoció, *qué* va a pasar, *dónde* y *cuándo*. Solo **Confirmar** ejecuta y actualiza el plano; **Rechazar** descarta.

Tu identidad solo existe durante la operación: la credencial viaja una vez al servidor, la reserva se hace **a tu nombre**, y nada se guarda en la tableta — quedas «desconectado» en cuanto termina. (El acceso puntual con Google sigue en la hoja de ruta; **los iPad no tienen NFC**, así que allí la vía es el QR con la cámara.)

## 10. Notificaciones

Recordatorios de registro, confirmaciones pendientes, decisiones de gastos — y cuando un admin **elimina una de tus reservas** (anular), tú y los admins recibís aviso. La entrega es local primero; los push del servidor llegan sin instalar nada en Android, iPhone/iPad, navegador y macOS (Firebase Cloud Messaging) — *Ajustes → Avanzado* muestra si el push está activo en este dispositivo. El icono de la app muestra tus confirmaciones pendientes. Los push nunca llevan nombres ni horas; la app compone el texto localmente.

## 11. Privacidad

Datos mínimos: nombre, correo, plan, reservas, cuenta. Tú controlas tu foto, tu estado, si tu nombre aparece en el plano y si tu teléfono es visible en el directorio. Las credenciales de quiosco se guardan solo como hash — una credencial perdida se revoca, no se adivina. Sin rastreo, sin analítica de terceros. El historial financiero se anonimiza, no se borra, al eliminar la cuenta (retención contable).

## 12. Plataformas

Android (Google Play), iPhone/iPad, escritorio — **macOS** (un DMG: arrastra DesKilo a Aplicaciones) y **Windows** (un instalador MSI) generados en cada versión — y el **navegador**: la misma app, sin instalar nada, en la dirección que publique tu espacio. Tus datos siguen a tu cuenta: un puesto reservado en el móvil aparece un segundo después en una pestaña.

Lo que el navegador no puede hacer es lo que a una página no se le permite: leer una credencial NFC o escanear un QR con la cámara como hace el quiosco. Todo lo demás — plano, reservas, miembros, dinero, facturas, descarga de PDF — es la misma app. Al abrir el DMG de macOS por primera vez, haz clic derecho sobre la app y elige *Abrir*: la compilación aún no está notarizada por Apple, así que un doble clic normal muestra un aviso de Gatekeeper.
