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

Una cuenta puede pertenecer a varios espacios; cambia entre ellos en **Ajustes → Perfiles**. Todo en la app se refiere al espacio activo.

## 2. Roles e invitaciones

DesKilo tiene tres roles acumulativos, más una cuenta de dispositivo:

| Rol | Puede |
|---|---|
| **Miembro** | Registrar entrada/salida, reservar, presentar gastos, ver y gestionar sus propios eventos y su propia cuenta |
| **Admin** | Todo lo de un miembro, más: actuar *por cualquiera* (reservas, pagos, gastos — sujeto a confirmación, §6), aprobar gastos, emitir credenciales de quiosco |
| **Propietario** | Todo lo de un admin, más: editar el espacio físico, definir planes y precios, gestionar roles, quioscos y ajustes del espacio |
| **Quiosco** | Una cuenta de tableta de pared (§9) — solo muestra el plano; los miembros actúan a través de ella con una credencial |

**Cada invitación está ligada a un rol.** En la pantalla *ID del espacio & QR* del propietario hay dos invitaciones, cada una con su propio QR y su propio código:

- **Invitación de miembro** — el propio ID del espacio. Imprímelo, cuélgalo en la pared, compártelo libremente: quien lo escanee o escriba se une como miembro normal.
- **Invitación de admin** — un **código personal de un solo uso**, emitido por un propietario para una persona concreta. Admite solo a esa persona como admin y luego caduca (un código sin usar expira a los 14 días). Emite uno nuevo por admin con *Nuevo código de admin*.

**No existe invitación de propietario — a propósito.** La propiedad solo puede otorgarla un propietario existente, en *Miembros y planes*. Un espacio conserva siempre al menos un propietario: la app se niega a degradar o eliminar al último. Promover o degradar un **admin** pasa por el flujo de validación (§6) — se aplica cuando los validadores del espacio confirman.

El QR codifica un enlace que nombra el rol otorgado (`deskilo://join?role=…`). Manipular el enlace no cambia nada — el servidor deriva el rol del propio código: el ID del espacio siempre une como miembro, y una invitación personal une exactamente en el rol con el que se emitió, una sola vez. Un código de admin reenviado ya usado — o caducado — no admite a nadie.

**Invitar por mensaje** (*Invitar a alguien*): cada envío por WhatsApp/SMS/compartir emite su propio código personal de un solo uso y compone un mensaje listo en el idioma del invitado. El destinatario puede simplemente copiar el mensaje completo y pegarlo en el campo de unión de la app — el código se detecta automáticamente.

## 3. El plano (pestaña Plano)

El plano muestra la planta activa de tu espacio: oficinas, mesas y asientos, con código de colores — **libre**, **reservado**, **ocupado**, **mío**, **bloqueado**. Los asientos ocupados muestran el nombre de pila de quien está, una **insignia de registro** cuando ha hecho check-in, y un **punto verde** cuando está en línea en la app.

El plano puede parecerse a tu espacio real: el propietario puede poner una **foto de la sala como fondo de la planta** y colocar **imágenes de ilustración redimensionables** (plantas, sofás…) sobre la cuadrícula. Un control de **transparencia de mesas** en los ajustes deja ver la foto a través de las mesas dibujadas.

Moverse:

- El lienzo **se ajusta solo** a tu planta al abrir o al girar el dispositivo; **pellizca para hacer zoom** o usa los botones **+ / −**, arrastra las **barras de desplazamiento** en los bordes y toca el botón de **ajuste** para recentrar.
- Elige la planta en el **menú de plantas** (desplegable compacto); el icono de reloj devuelve la línea de tiempo a **ahora**.
- En **horizontal**, los controles pasan a un panel lateral y el plano llena la pantalla — útil en tabletas.

Reservar desde el plano:

- **Registro espontáneo**: toca un asiento libre → la hoja propone *ahora* hasta el fin por defecto del espacio → confirma. Si alguien reservó ese asiento más tarde, tu hora de fin se recorta y se te avisa.
- **Registro sobre reserva**: tu reserva abre una ventana de check-in. Regístrate desde el plano o desde la notificación de recordatorio. Si no apareces, el asiento se **libera automáticamente** tras el plazo configurado.
- **Salida**: manual, o automática al final de la reserva / al cierre.
- **Línea de tiempo**: elige una ventana de→a (o Mañana / Tarde / Día completo, según la granularidad del espacio) para ver la ocupación en cualquier momento futuro.
- Los asientos pueden llevar **accesorios** (monitor, mesa elevable…), algunos con suplemento por media jornada que aparece en tu extracto.
- Las reservas cuentan contra tus **días mensuales** (§8) — pasado tu plan, la app bloquea o cobra, según lo que el propietario configuró para ti.

## 4. Reservas (hub Reservar)

Abre el hub **Reservar** (botón central). Una banda de fechas elige el día; los chips de ventana, la hora; luego cuatro vistas:

- **Plano** — el plano filtrado a tu ventana; toca un asiento libre para reservarlo.
- **Día** — cada asiento como fila de cronología del día elegido; toca un tramo libre para reservar, tu propio bloque para ver detalles.
- **Semana** — una cuadrícula asiento × día de toda la semana ISO; encuentra una media jornada libre de un vistazo y tócala para reservar.
- **Mes** — un calendario de disponibilidad: mesas libres por día en todas las plantas; toca un día para entrar en su vista Día.

Las reservas siguen la **regla de granularidad** del espacio — medias jornadas, días completos u horas libres sobre la rejilla de minutos del propietario. Respetan los **días de apertura** y los **días de cierre**, y las reglas de reserva (horizonte, duración máxima, plazo de cancelación). ¿Necesidad recurrente? Reserva una **serie** (diaria, laborables, semanal) — los días cerrados y conflictos se saltan y se informan.

La pestaña **Calendario** muestra tus reservas por mes — tus días en **rojo**, los de otros en **azul**, hoy rodeado — con cronología por día. En horizontal, calendario y cronología usan el diseño dividido.

## 5. Directorio de miembros (pestaña Miembros)

Mira quién forma tu comunidad:

- Cada tarjeta muestra su **foto** (o inicial), **rol**, **estado personalizado** («en Berlín hasta el viernes…»), un indicador **en línea / visto por última vez**, y un **chip de reserva**: asiento registrado, reservado ahora, o próxima reserva.
- Toca un miembro para su **ficha de detalle** — con sus próximas reservas.
- **Desliza** un miembro para escribirle por **WhatsApp**; el **botón de grupo** abre el grupo de WhatsApp de la comunidad (definido por el propietario).
- Define tu foto, estado y visibilidad del teléfono en **Ajustes**.

## 6. Eventos y confirmaciones (icono de campana)

El hilo de eventos es la pista de auditoría del espacio: reservas creadas/cambiadas/canceladas, pagos registrados, gastos presentados, solicitudes de días extra, cambios de rol. Los miembros ven sus propios eventos; admins y propietarios lo ven todo.

**El protocolo de confirmación:** cuando un admin hace algo *por otra persona* — te reserva un asiento, registra tu pago — queda **pendiente hasta que confirmes**. Lo pendiente se fija arriba con botones de aceptar/rechazar y recibes una notificación. Lo que haces sobre ti mismo nunca requiere confirmación.

**Quórum de validación:** para asuntos de dinero y cambios de rol, el propietario define *quién* debe aprobar y *cuántas* aprobaciones hacen falta. Las solicitudes sin respuesta caducan a los 7 días — nada costoso se concede jamás en silencio.

El propietario afina esto por **dominio** en **Ajustes → Reglas de validación**: pagos, gastos, servicios, medias jornadas extra, cambios de rol, reservas y ajustes tienen cada uno su propia regla (o heredan la regla por defecto). Una regla define el número de validaciones requeridas, *qué* admins pueden validar (todos, o algunos concretos) y si el propietario debe firmar siempre.

<p><img src="images/validation-rules.jpg" width="240"> <img src="images/validation-rule-edit.jpg" width="240"></p>

*Izquierda: una regla por dominio, heredando de la regla por defecto. Derecha: edición de una regla — validaciones requeridas, validadores autorizados, firma del propietario.*

## 7. Para propietarios: editor y ajustes

Toda la administración vive en **Ajustes → Administración**. Una regla que conviene conocer: **la entrada de ajustes de una función solo aparece mientras esa función está activada** — desactiva *Pagos en línea* en **Funciones** y su pantalla de configuración desaparece con ella (y vuelve al reactivarla). La entrada **Funciones** siempre está presente, así que siempre puedes volver a activar un módulo.

<p><img src="images/settings-administration.jpg" width="240"></p>

- **Editor** (barra de la app): dibuja tu espacio en una cuadrícula — plantas, oficinas, mesas, asientos (con orientación, tipo de silla y equipamiento), bloqueo de asientos por mantenimiento. Añade una **foto de fondo** por planta e **imágenes de ilustración** que puedes mover y redimensionar. Borrar algo con reservas futuras obliga a resolverlas antes.
- **ID del espacio & QR**: tus invitaciones ligadas a rol (§2). Puedes sustituir el ID generado por uno memorable (4–20 letras/dígitos), copiarlo o compartir el QR como PNG.
- **Disponibilidad**: días de apertura, días de cierre y la granularidad — horas de inicio y fin libres, una rejilla de minutos (5/15/30/60), medias jornadas o solo días completos.
- **Funciones**: activa o desactiva módulos enteros por espacio — calendario, eventos, dinero, servicios, exportación PDF, series, reservar por otros, push, bloqueo de asientos por admins, suplementos de accesorios, **pagos en línea**, **credenciales RFID/NFC**. Desactivar un módulo elimina *todas* sus pantallas y botones para todos los miembros.

<p><img src="images/workspace-id-qr.jpg" width="220"> <img src="images/availability-granularity.jpg" width="220"> <img src="images/features-toggles-1.jpg" width="220"> <img src="images/features-toggles-2.jpg" width="220"></p>

- **Miembros y planes**: toca un miembro para abrir su **ficha de gestión** — añadirle un servicio, fijar su porcentaje de suscripción, elegir su **política de exceso** (§8), limitar sus **reservas simultáneas**, emitir **credenciales** (§9), promover/degradar admin, convertir la cuenta en **quiosco**, o pausar la membresía.

<p><img src="images/member-management-sheet.jpg" width="220"> <img src="images/member-subscription.jpg" width="220"> <img src="images/member-reservation-limit.jpg" width="220"></p>

*La ficha de gestión, el diálogo de porcentaje de suscripción y el tope de reservas por miembro.*

- **Facturación**: bandas de tarifas de las suscripciones porcentuales, tarifas de exceso, niveles de suscripción ofrecidos (con un valor libre negociado opcional) — y **paquetes de días** (un número de días por un precio) para miembros con política de paquete.
- **Servicios** y **Accesorios**: los catálogos detrás del §8 — extras definidos por el propietario (taquillas, impresión…) y equipamiento por asiento con suplementos opcionales por media jornada. Ambos son listas simples con un botón **+**.

<p><img src="images/billing-bands-levels-packages.jpg" width="220"> <img src="images/services-catalog.jpg" width="220"> <img src="images/services-new-service.jpg" width="220"> <img src="images/accessories-catalog.jpg" width="220"></p>

*Facturación (bandas, niveles, paquetes de días) · el catálogo de Servicios y su formulario de creación · el catálogo de Accesorios. Un admin añade un consumo de servicio para un miembro desde la ficha de gestión del miembro:*

<p><img src="images/member-add-service.jpg" width="220"></p>

- **Ajustes del espacio**: nombre, país/moneda, zona horaria, instrucciones de pago (IBAN, PayPal.me, Wero, Lydia, Wise), enlace del grupo de WhatsApp, **transparencia de mesas**, exportaciones — y la **zona de peligro**: un **reinicio total del espacio** (borra reservas, dinero y plano; conserva configuración y miembros), protegido escribiendo «I agree».
- **Importar/exportar**: toda la configuración viaja como **archivo XML** — cópiala, úsala de plantilla o migra una instancia autoalojada. También puede generarse un **PDF de configuración** (miembros, plano, precios, funciones). Los archivos se guardan **localmente en tu dispositivo**.

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

1. Abre **Ajustes → Credenciales RFID / NFC** (solo propietario). Activa **Activar registro por credencial NFC** y lee la línea de **estado del dispositivo** — hace falta un dispositivo **Android** con NFC activado (los iPad no tienen NFC).
2. Da una tarjeta a cada miembro: **Miembros y planes → el miembro → Credenciales → Registrar tarjeta**, y acerca su tarjeta al dispositivo. Vale cualquier tarjeta con chip legible (MIFARE, NTAG…).
3. Úsalas en un **quiosco** (§9): el miembro acerca la tarjeta para reservar o registrarse. Revoca una tarjeta perdida desde la misma ventana de Credenciales.

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
- **Pagar**: DesKilo registra los pagos; una factura pendiente muestra las **instrucciones de pago** del espacio (el IBAN se copia con un toque, PayPal.me se abre directamente). Registra un pago («he pagado») con su método — la otra parte confirma. Si el espacio activó los **pagos en línea** y su servidor está configurado, el botón **Pagar en línea** permite abonar el importe adeudado al instante — con **PayPal, tarjeta (Stripe), Mollie o Wero**, según lo que el espacio haya activado (si hay varios, se muestra un selector).
- **Gastos**: ¿compraste café para el espacio? Presenta el gasto — otro admin lo aprueba (sin autoaprobación) y el importe se abona en tu próximo extracto.
- **Servicios**: extras definidos por el propietario (taquillas, impresión…) cuyo consumo llega a tu extracto tras tu confirmación.

## 9. Modo quiosco (tableta de pared)

Monta una tableta Android o un iPad junto a la puerta y deja que la gente se registre al entrar:

1. El propietario crea una cuenta normal para el dispositivo, la une al espacio y la marca como **quiosco** en *Miembros y planes*. Desde entonces esa cuenta queda bloqueada en el plano a pantalla completa — sin otras pantallas, sin nada más que tocar.
2. El propietario (o un admin) da una **credencial** a cada miembro, en *Miembros y planes → un miembro → Credenciales*. Dos tipos:
   - **Código QR** — mostrado **una sola vez**; toca **Guardar como PDF** para imprimir una tarjeta, o guarda el QR en el móvil del miembro.
   - **Tarjeta RFID/NFC** — toca **Registrar tarjeta** y acerca la tarjeta física del miembro (Android con NFC). Configúralo en *Ajustes → Credenciales RFID / NFC* (§7).
   Cualquier credencial es revocable en cualquier momento.
3. En el quiosco: toca un asiento → **Registrarse**, **Reservar** o **Salir** → presenta la credencial: **acerca la tarjeta RFID/NFC**, escanea el QR con un lector de códigos USB/Bluetooth, o escribe el código.

Tu identidad solo existe durante la operación: la credencial viaja una vez al servidor, la reserva se hace **a tu nombre**, y nada se guarda en la tableta — quedas «desconectado» en cuanto termina. (El escaneo de QR con cámara y el acceso puntual con Google/Facebook siguen en la hoja de ruta; **los iPad no tienen NFC**, así que allí el QR es la vía.)

## 10. Notificaciones

Recordatorios de registro, liberaciones por ausencia, confirmaciones pendientes, decisiones de gastos. La entrega es local primero; en Android, la variante F-Droid usa **UnifiedPush** (p. ej. ntfy) en lugar de servicios de Google — sin Firebase en ninguna parte.

## 11. Privacidad

Datos mínimos: nombre, correo, plan, reservas, cuenta. Tú controlas tu foto, tu estado, si tu nombre aparece en el plano y si tu teléfono es visible en el directorio. Las credenciales de quiosco se guardan solo como hash — una credencial perdida se revoca, no se adivina. Sin rastreo, sin analítica de terceros. El historial financiero se anonimiza, no se borra, al eliminar la cuenta (retención contable).

## 12. Plataformas

Android (Google Play y F-Droid), iPhone/iPad y escritorio — macOS, y Windows con un **instalador MSI** generado en cada versión. Tus datos siguen a tu cuenta.
