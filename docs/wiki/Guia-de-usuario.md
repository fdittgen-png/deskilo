# Guía de usuario

Todo lo que un miembro, admin o propietario necesita para usar DesKilo. *Otros idiomas: [English](User-Guide) · [Français](Guide-utilisateur) · [Deutsch](Benutzerhandbuch) · [Italiano](Guida-utente).*

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
- **Invitación de admin** — un código secreto aparte, visible solo para propietarios. Compártelo solo con quien deba gestionar el espacio: quien lo use se une como admin.

**No existe invitación de propietario — a propósito.** La propiedad solo puede otorgarla un propietario existente, en *Miembros y planes*. Un espacio conserva siempre al menos un propietario: la app se niega a degradar o eliminar al último. Promover o degradar un **admin** pasa por el flujo de validación (§6) — se aplica cuando los validadores del espacio confirman.

El QR codifica un enlace que nombra el rol otorgado (`deskilo://join?role=…`). Manipular el enlace no cambia nada — el servidor deriva el rol del propio código secreto.

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

## 7. Para propietarios: editor y ajustes

- **Editor** (barra de la app): dibuja tu espacio en una cuadrícula — plantas, oficinas, mesas, asientos (con orientación, tipo de silla y equipamiento), bloqueo de asientos por mantenimiento. Añade una **foto de fondo** por planta e **imágenes de ilustración** que puedes mover y redimensionar. Borrar algo con reservas futuras obliga a resolverlas antes.
- **ID del espacio & QR**: tus invitaciones ligadas a rol (§2). Puedes sustituir el ID generado por uno memorable (4–20 letras/dígitos).
- **Disponibilidad**: días de apertura, días de cierre y la granularidad — medias jornadas, días completos o rejilla de minutos (15/30/60).
- **Funciones**: activa o desactiva módulos enteros por espacio — calendario, eventos, dinero, servicios, exportación PDF, series, reservar por otros, push, bloqueo de asientos por admins, suplementos de accesorios, **pagos en línea**.
- **Miembros y planes**: porcentajes de suscripción, **política de exceso** de cada miembro (§8), pausar/salir, promociones/degradaciones de admin, marcar **quioscos** y emitir **credenciales** (§9).
- **Facturación**: bandas de tarifas de las suscripciones porcentuales, tarifas de exceso, niveles de suscripción ofrecidos — y **paquetes de días** (un número de días por un precio) para miembros con política de paquete.
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
3. **Guarda** — aparece un chip verde *Configurado*. Activa la función **Pagos en línea** (Ajustes → Funciones) y los miembros verán **Pagar en línea** en una factura pendiente.

Un secreto guardado no se vuelve a mostrar — deja el campo en blanco para conservarlo, escribe para reemplazarlo, **Eliminar** para quitar el proveedor. Las comisiones son del proveedor (típicamente ~1,5–3 % por pago, sin cuota mensual); DesKilo no añade nada, y la transferencia/IBAN manual sigue siendo gratis.

### Configurar las credenciales RFID / NFC (propietarios)

Las tarjetas físicas permiten registrarse con un toque — sin teléfono.

1. Abre **Ajustes → Credenciales RFID / NFC** (solo propietario). Activa **Activar registro por credencial NFC** y lee la línea de **estado del dispositivo** — hace falta un dispositivo **Android** con NFC activado (los iPad no tienen NFC).
2. Da una tarjeta a cada miembro: **Miembros y planes → el miembro → Credenciales → Registrar tarjeta**, y acerca su tarjeta al dispositivo. Vale cualquier tarjeta con chip legible (MIFARE, NTAG…).
3. Úsalas en un **quiosco** (§9): el miembro acerca la tarjeta para reservar o registrarse. Revoca una tarjeta perdida desde la misma ventana de Credenciales.

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
