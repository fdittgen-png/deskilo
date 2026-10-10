<!-- anchor: setup.notify.overview -->
## Avisar a las personas

Para propietarios que quieren que los miembros y los administradores se enteren de lo que importa, y solo de eso. Este capítulo describe lo que DesKilo envía realmente, quién lo recibe, qué configura usted y qué debe dejar al operador de la instalación.

En este capítulo:
- Los canales, en palabras sencillas
- Una tabla: qué ocurre, a quién se avisa, por qué canal y qué puede cambiar un miembro
- Lo que usted configura y lo que debe hacer el operador para las notificaciones push
- Un plan de pruebas con dos cuentas
- Cómo evitar tanto el exceso de avisos como el silencio

<!-- anchor: setup.notify.channels -->
### Los canales, en palabras sencillas

**Público:** Propietario · Administrador/a

Quiere tener una idea clara de las vías por las que DesKilo puede llegar a una persona, antes de prometer nada a sus miembros.

<p><img src="images/setup-notify-features.es.jpg" width="280"></p>

**Antes de empezar**

Hay seis vías, y no son iguales. La mayor parte del trabajo se hace dentro de la aplicación.

| Canal | Qué es | Qué necesita |
|---|---|---|
| El flujo de eventos y la campana | Todo lo que ocurre en el espacio se anota en un flujo. La campana cuenta las novedades y las decisiones que esperan por usted. | **Pestaña Eventos**; **Agrupación de notificaciones** es una opción adicional |
| Mensajes | Conversaciones privadas y de grupo entre miembros, con confirmaciones de lectura y enlaces a una reserva o a un espacio. | **Notificaciones entre miembros** |
| Notificaciones push | Una notificación breve en un teléfono o un ordenador, incluso con la aplicación cerrada. El texto es genérico: sin nombres ni horas. | **Notificaciones push** activadas, **y** una configuración de push por parte del operador; véase [la parte del operador](help:setup.notify.operator) |
| El recordatorio de registro de entrada | Una notificación en el propio dispositivo del miembro, 15 minutos antes de una reserva en la que aún no ha registrado su entrada. | El permiso del sistema por parte del miembro. No existe en la versión de navegador. |
| Recordatorios de pago | Una alerta en el flujo y una notificación push al miembro cuya factura está vencida. | **Recordatorios de pago** y **Recordatorios de pago automáticos**; véase [Recordatorios de pago](help:setup.money.reminders) |
| WhatsApp | Un enlace de grupo que usted publica y el número de WhatsApp que un miembro decide compartir. La aplicación abre WhatsApp; el servidor no envía nada. | **Integración con WhatsApp** |

**Conviene saber**

- DesKilo no envía correos electrónicos propios, aparte de los de la cuenta (confirmación de alta, restablecimiento de contraseña). Las invitaciones son textos que usted comparte desde su propio teléfono.
- No existe una suscripción por evento: un miembro no puede elegir «avísame de los gastos pero no de las reservas».
- Una notificación puede retrasarse o perderse como cualquier push; el flujo y la lista de mensajes son el registro fiable.

**Véase también:** [Notificaciones](help:user.collaborate.notifications) · [Eventos y confirmaciones](help:user.collaborate.events)

<!-- anchor: setup.notify.table -->
### A quién se avisa de qué

**Público:** Propietario · Administrador/a

Quiere saber, evento por evento, quién se entera y cómo.

<p><img src="images/setup-notify-events.es.jpg" width="280"></p>

**Antes de empezar**

Solo se envía push en las cinco líneas marcadas con «push» más abajo. Cualquier otro evento (una reserva hecha, un pago registrado, la llegada de un miembro) aparece en el flujo y en ningún otro sitio.

| Origen | Evento | A quién se avisa | Canal | Qué puede cambiar el miembro |
|---|---|---|---|---|
| Reglas de validación | Una solicitud necesita una confirmación | A las personas que nombra la regla (flujo, **Esperando su confirmación**); el push va solo al miembro al que se refiere la solicitud, nunca a quien la hizo, de modo que los validadores reciben el push solo cuando son ese miembro. Texto: «Alguien necesita tu confirmación.» | Flujo, campana; push | Desactivar el push en el dispositivo |
| Reservas | Un administrador elimina o anula una reserva | Al miembro desplazado y a todos los administradores y propietarios activos excepto quien actuó. Texto: «Un administrador ha eliminado una reserva.» | Flujo; push | Desactivar el push en el dispositivo |
| Recordatorios de pago | Una factura ha superado su plazo y vence un nivel de recordatorio | Al miembro destinatario de la factura. La factura de un propietario llega al propio propietario. Texto: «Tienes un recordatorio de pago.» | Alerta en el flujo; push | Desactivar el push en el dispositivo |
| Notificaciones entre miembros | Un mensaje nuevo | Mensaje directo: el destinatario. Grupo: los participantes excepto el remitente. Una conversación silenciada por un miembro permanece en silencio para ese miembro. Texto: «Tienes un mensaje nuevo.» | Mensajes, campana; push | Silenciar, fijar o archivar una conversación; desactivar el push |
| Menciones en mensajes | Un mensaje de grupo nombra a alguien | A las personas nombradas, incluso en una conversación silenciada. Texto: «Te han mencionado en una conversación.» | Mensajes; push | Desactivar el push |
| Reservas | Se acerca una reserva | Al miembro que reservó, en su propio dispositivo, 15 minutos antes de que empiece, para las reservas de los próximos siete días | Notificación local | Rechazar el permiso del sistema |
| Integración con WhatsApp | No se envía nada | El enlace del grupo se muestra en el directorio; un miembro puede compartir su número | Abre WhatsApp | Compartir u ocultar el número |

**Conviene saber**

- Con la aplicación abierta, el push de una reserva eliminada se sustituye por una notificación en el idioma del miembro. Para los mensajes, las menciones, las confirmaciones y los recordatorios de pago, la aplicación abierta muestra hoy su texto genérico («Alguien necesita tu confirmación.»). Los textos genéricos en inglés de la tabla aparecen cuando la aplicación está en segundo plano o cerrada.
- A un administrador solo se le avisa de aquello sobre lo que actúa o de lo que una regla le asigna; no existe un resumen de «todo».
- Los miembros ven sus propios eventos; los administradores y los propietarios ven los de todos.

**Véase también:** [Reglas de validación](help:user.validation.overview) · [Mensajes](help:user.collaborate.messages)

<!-- anchor: setup.notify.configure -->
### Lo que usted configura

**Público:** Propietario

Usted decide qué canales existen en su espacio y a quién se le pide decidir qué.

<p><img src="images/setup-notify-validation.es.jpg" width="280"></p>

**Pasos**

1. Abra [Funciones](help:user.features.switch) y revise los interruptores de notificación: **Notificaciones push**, **Notificaciones entre miembros**, **Pestaña Eventos**, **Agrupación de notificaciones**, **Recordatorios de pago**, **Recordatorios de pago automáticos** e **Integración con WhatsApp**.
2. Fije las [reglas de validación](help:user.validation.overview): para cada tipo de solicitud, cuántas validaciones se exigen y quién puede darlas. Esto decide a quién se le pregunta, y por tanto quién ve una decisión pendiente.
3. Decida si la solicitud de un administrador o de un propietario se resuelve por sí sola; véase [Autovalidar la solicitud de un administrador](help:user.validation.auto-validate-admin) y [Autovalidar la solicitud de un propietario](help:user.validation.auto-validate-owner). Una solicitud ya resuelta nunca avisa a nadie.
4. Escriba el mensaje de invitación que reciben los miembros y pegue el enlace del grupo de la comunidad; véase [Mensaje de invitación](help:user.workspace.settings.invitation-message) y [Grupo de WhatsApp](help:user.workspace.settings.whatsapp-group).
5. Active **Solicitudes de eliminación de reservas** si los miembros pueden pedir que se borre una reserva pasada o con registro de entrada: alguien tendrá entonces que responder.

**Conviene saber**

- Valores por defecto de un espacio nuevo: la pestaña de eventos, las notificaciones entre miembros y la agrupación están activadas; **Recordatorios de pago** y **Recordatorios de pago automáticos** están activadas como funciones, pero no se envía ningún recordatorio hasta que usted activa **Recordatorios automáticos** en las reglas de recordatorio.
- **Notificaciones push** está activada por defecto, pero no entrega nada hasta que el operador la haya configurado.
- Desactivar una función detiene la actividad nueva de ese tipo. No borra lo que ya existe.
- Los roles deciden quién puede ver y responder qué; véase [La matriz de roles](help:user.roles.matrix).

**Véase también:** [Quién puede validar](help:user.validation.who-may) · [Validaciones requeridas](help:user.validation.required-count)

<!-- anchor: setup.notify.operator -->
### La parte del operador: hacer que funcione el push

**Público:** Operador/a · Propietario

Quiere notificaciones push en los teléfonos de los miembros y necesita saber quién hace qué.

**Antes de empezar**

El push no viene con la aplicación por sí solo. Si usted ejecuta su espacio en la instalación de referencia compartida, pregunte a su operador si el push está configurado. Si ejecuta su propia instalación, el operador es usted o su persona técnica.

**Pasos**

1. Cree un proyecto de Firebase y compile la aplicación con él. Sin esto, la aplicación se queda solo con las notificaciones locales, y un miembro ve **Esta versión no tiene notificaciones push**. La versión preparada para F-Droid no tiene push en absoluto ([estado de F-Droid](https://github.com/fdittgen-png/deskilo/blob/master/docs/guides/fdroid.md#status)).
2. Para iPhone y Mac, añada una clave push de Apple al proyecto de Firebase.
3. Guarde la clave de cuenta de servicio de Firebase como secreto del servidor y despliegue la función de push.
4. En su propia instalación, apunte la fila `push_config` de su base de datos a la URL y la clave de su propia función de push. Viene preparada con la dirección de la instalación de referencia.
5. Pruébelo con dos cuentas, como se describe en [el plan de pruebas](help:setup.notify.test).

**Conviene saber**

- Sin los pasos 1 a 4, no se envía ningún push, digan lo que digan los interruptores. El flujo, la campana y los mensajes siguen funcionando.
- La lista de comprobación detallada es para el operador: véase [Plataformas](help:user.advanced.platforms) y [Su propio servidor](help:user.advanced.own-server).
- El texto del push nunca lleva un nombre ni una hora: es deliberado, por privacidad.

**Véase también:** [Notificaciones push en este dispositivo](help:user.privacy.push)

<!-- anchor: setup.notify.members -->
### Lo que controlan los miembros

**Público:** Propietario · Administrador/a

Quiere decir con honestidad a sus miembros qué pueden desactivar.

<p><img src="images/setup-notify-push.es.jpg" width="280"></p>

**Pasos**

1. Un miembro abre [Privacidad y datos](app:/privacy) y usa **Notificaciones push en este dispositivo** para detener o reanudar el push en ese dispositivo.
2. En [Mensajes](app:/me?tab=messages), un miembro mantiene pulsada una conversación para **Fijar arriba**, **Silenciar notificaciones**, **Marcar como no leído** o **Archivar**.
3. En los ajustes del sistema del teléfono, un miembro puede rechazar las notificaciones por completo, incluidos los recordatorios de registro de entrada.
4. En su perfil, un miembro decide si comparte un número de WhatsApp.

**Conviene saber**

- Una conversación silenciada permanece en silencio, pero se sigue contando; una mención anula el silencio.
- Un miembro que desactiva el push en un dispositivo no se ve afectado en otro.
- No hay interruptores por categoría. Si un miembro necesita menos ruido, que silencie conversaciones; si no quiere ninguno, que desactive el push.

**Véase también:** [Notificaciones](help:user.collaborate.notifications) · [Sus datos, sus derechos](help:user.privacy.consent)

<!-- anchor: setup.notify.test -->
### Un plan de pruebas: envíese uno de cada

**Público:** Propietario · Administrador/a · Operador/a

Se asegura de que cada canal funciona antes de que sus miembros dependan de él.

**Antes de empezar**

Hágalo en un espacio de prueba (véase [un ensayo seguro](help:setup.money.dry-run)). Necesita dos cuentas: la suya como propietario y una segunda como miembro, en otro teléfono, en otro navegador o en el mismo teléfono tras cerrar la sesión. El espacio de demostración permite ver las pantallas con sus personajes, pero no envía ningún push real.

**Pasos**

1. Mensaje: desde la cuenta del miembro, escriba al propietario en [Mensajes](app:/me?tab=messages). En la cuenta del propietario, la campana lo cuenta y la conversación aparece como no leída. Ábrala: el mensaje del miembro muestra una confirmación de lectura.
2. Mención: en una conversación de grupo, nombre al propietario (la función de menciones de la mensajería debe estar activada). Si el push está configurado, el teléfono del propietario muestra «Te han mencionado en una conversación.»
3. Decisión: como miembro, pida eliminar una reserva pasada (la función **Solicitudes de eliminación de reservas** debe estar activada). El propietario la ve en **Esperando su confirmación** en [Eventos](app:/events); respóndala y observe cómo cambia el flujo del miembro.
4. Eliminación: como propietario, elimine una reserva futura del miembro. El flujo del miembro la muestra, y un teléfono con push muestra «Un administrador ha eliminado una reserva.»
5. Recordatorio: como miembro, reserve un puesto que empiece dentro de unos 20 minutos (una reserva que empieza en menos de 15 minutos no recibe recordatorio). Unos 15 minutos antes del inicio, el teléfono del miembro muestra el recordatorio de registro de entrada.
6. Recordatorio de pago: con **Recordatorios de pago** activado, active **Recordatorios automáticos** en las reglas de recordatorio con un plazo corto hasta el primer recordatorio, emita una factura de prueba que tenga un plazo de pago, espere a que pase el plazo y abra Finanzas como propietario o copropietario; el flujo del miembro muestra la alerta.
7. Silencio: como miembro, silencie la conversación, envíe otro mensaje desde el propietario y compruebe que no suena nada pero el contador de no leídos sube.

**Conviene saber**

- Los pasos 2 y 4 muestran un push solo si la configuración del operador está completa. Si fallan mientras los demás funcionan, el fallo está en esa configuración, no en sus reglas.
- En la versión de navegador de la aplicación no existe el recordatorio de registro de entrada.
- Un teléfono que bloquea las notificaciones no muestra nada; revise primero los ajustes del sistema.

**Resultado**

Ha visto con sus propios ojos todos los canales en los que se apoyará un miembro.

**Véase también:** [Los canales](help:setup.notify.channels) · [Iniciar una conversación o un grupo](help:user.collaborate.messages-new)

<!-- anchor: setup.notify.silence -->
### Evitar el exceso y evitar el silencio

**Público:** Propietario · Administrador/a

Quiere que las personas se enteren de lo que las necesita, sin ahogarlas.

**Pasos**

1. Mantenga activada la **Agrupación de notificaciones**: los miembros y los administradores pueden plegar el flujo por tipo, día o miembro.
2. Pida validación solo donde la decisión sea real: cada regla que exige validación crea una solicitud que alguien debe responder. Véase [Reglas de validación](help:user.validation.overview).
3. Use los interruptores de autovalidación para las solicitudes cuya respuesta es obvia.
4. Eche un vistazo de vez en cuando a [Lo que le necesita](help:user.collaborate.attention): clasifica lo que está pendiente.

**Conviene saber**

- El exceso viene de reglas que preguntan con demasiada frecuencia o de demasiados administradores en una misma regla.
- El silencio viene de una regla sin nadie que la responda: exigir dos validaciones cuando solo existe el propietario, o nombrar a administradores que ya se han marchado, deja las solicitudes esperando para siempre. La tarjeta de preparación puede señalar una regla de reserva con pocos validadores.
- El silencio viene también de un push sin configurar, de miembros que desactivaron el push y de un sistema que bloquea las notificaciones.
- Los recordatorios de pago automáticos no sustituyen el repaso ocasional de las facturas abiertas.

**Véase también:** [Quién puede validar](help:user.validation.who-may) · [Validaciones requeridas](help:user.validation.required-count)
