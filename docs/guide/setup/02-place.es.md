<!-- anchor: setup.place.overview -->
## Construir el lugar

Este capítulo levanta el primer nivel, *Abrir*: dónde está el espacio, cómo es, cuándo abre y cuáles son las reglas de reserva. En unos veinte minutos el espacio ya se puede reservar. El ejemplo es *Atelier du Marché*, una asociación de Pézenas con dos plantas y una sala.

En este capítulo:
- [País, moneda, zona horaria e idioma](help:setup.place.where)
- [El plano](help:setup.place.plan)
- [Horarios de apertura y reglas de reserva](help:setup.place.times)
- [Días de cierre y días festivos](help:setup.place.closure)
- [Revisar su espacio](help:setup.place.check)

<!-- anchor: setup.place.where -->
### País, moneda, zona horaria e idioma

**Público:** Propietario · Administrador/a

Usted quiere que el espacio sepa dónde vive. Estas cuatro elecciones determinan más cosas de las que parece.

<p><img src="images/setup-place-country.es.jpg" width="280"></p>

*Qué determina cada elección*

| Elección | Qué decide |
|---|---|
| **País** | La moneda y la zona horaria que propone, y los días festivos que se ofrecen como días de cierre (véase más abajo). |
| **Moneda** | Cómo se muestra y se cuenta cada importe. |
| **Zona horaria** | Qué significan una jornada laboral, el límite de media jornada y un día de cierre; un miembro que está en el extranjero ve el día del espacio. |
| **Idioma del espacio** | El idioma en que se redactan por defecto las invitaciones y las referencias de mensajes compartidas. |

**Pasos**

1. Abra [Espacio](app:/workspace-settings) y vaya a **Datos generales**.
2. Elija el **País**; la **Moneda** y la **Zona horaria** se proponen solas y puede corregirlas. Para Atelier du Marché: Francia, EUR, Europe/Paris.
3. Elija el **Idioma del espacio** y toque **Guardar**.

> **Atención** Elija bien el país y la moneda desde el primer día. Los importes se guardan como simples números, así que cambiar la moneda cuando ya hay dinero etiquetaría mal todo lo ya contado.

**Conviene saber**

- La aplicación enumera muchos países, pero emitir facturas dentro de DesKilo solo funciona hoy para Francia y Alemania. En otros países conserva los estados de cuenta y emite las facturas fuera de la aplicación.
- El idioma del espacio no es el idioma de su aplicación, que está en sus ajustes personales.

**Véase también:** [País](help:user.workspace.settings.country) · [Moneda y zona horaria](help:user.workspace.settings.currency-timezone) · [Idioma del espacio](help:user.workspace.settings.language)

<!-- anchor: setup.place.plan -->
### El plano

**Público:** Propietario · Administrador/a

Usted quiere que el plano en pantalla se parezca al lugar real. Se construye en cuatro capas: plantas, después oficinas (salas), después mesas y después asientos. Un miembro reserva un asiento; el asiento es lo que cuenta la lista de preparación.

<p><img src="images/setup-place-rooms.es.jpg" width="280"></p>

**Pasos**

1. Haga un croquis en papel: plantas, salas, mesas, asientos.
2. Abra [Editor del espacio](app:/editor) y añada las plantas con **Añadir planta**.
3. Abra una planta y dibuje cada sala con **Oficina**, y dentro de ella **Mesa** y **Asiento**.
4. Si un equipo puede ocupar una sala o una planta durante un día, active la reserva completa en sus propiedades.

**Conviene saber**

- Empiece poco a poco: una primera planta, una sala, unos cuantos asientos. Todo se puede añadir después.
- Una planta, una oficina o una mesa enteras solo se pueden reservar si **Reservas de mesa, oficina y planta** está activada y el miembro tiene el permiso.
- La plantilla incluida A tiny space le da dos plantas, cuatro mesas y ocho asientos para ajustar.
- Eliminar una planta elimina todo lo que contiene, y se rechaza importar un plano cuando ya hay reservas.

**Véase también:** [Añadir, renombrar y eliminar plantas](help:user.space.editor.levels) · [Dibujar salas, mesas y asientos](help:user.space.editor.rooms) · [Permitir reservar una planta entera](help:user.space.editor.level-booking)

<!-- anchor: setup.place.times -->
### Horarios de apertura y reglas de reserva

**Público:** Propietario · Administrador/a

Usted quiere que las reservas sigan el ritmo de su lugar. Una sola pantalla, **Disponibilidad**, reúne los días, la forma de una reserva, el horario de trabajo y las reglas. El servidor las aplica en todas partes: plano, hoja de reserva, códigos escaneados y quiosco.

<p><img src="images/setup-place-availability--times.es.jpg" width="280"></p>

**Pasos**

1. Abra [Disponibilidad](app:/availability).
2. Elija los **Días de apertura** (al menos uno) y la **Granularidad de las reservas**.
3. Fije el **Horario de trabajo**: **Inicio de la jornada**, **Límite de media jornada**, **Fin de la jornada**.
4. En **Políticas de reserva**, decida sobre **Permitir reservas pasadas**, **Fuera del horario de apertura** y los **Límites de reserva**.

<p><img src="images/setup-place-availability--rules.es.jpg" width="280"></p>

*Puntos de partida recomendados (sugerencias, no reglas; el valor por defecto de **Fuera del horario de apertura** es **De pago**, y la plantilla de asociación no lo cambia)*

| Escenario | Granularidad | Horario | Fuera de horario | Reservas pasadas | Límites |
|---|---|---|---|---|---|
| Unas pocas mesas compartidas | **Franja horaria libre** o **Franjas de 1 hora** | Jornada de 8:00 a 17:00 | **Gratis** | Desactivado | Una reserva a la vez; horizonte de 30 días |
| Una sala de asociación (Atelier du Marché) | **Medios días (mañana y tarde)** | 7:00, límite a las 13:00, fin a las 19:00 | **Prohibido** | Desactivado | Una reserva a la vez; horizonte de 90 días |
| Un coworking con medias jornadas | **Medios días (mañana y tarde)** | 8:00, límite a las 12:00, fin a las 18:00 | **De pago** | Desactivado | Una o dos a la vez; horizonte de 90 días |

**Conviene saber**

- Fuera del horario de apertura, **Prohibido** rechaza todo, **Solo espontáneo** admite a quien llega sin reserva, **Gratis** lo permite sin contarlo y **De pago** cuenta como un uso normal, salvo el día en que el miembro ya tiene una reserva normal.
- La jornada debe seguir un orden: inicio, después límite, después fin; la duración mínima no puede superar la máxima.
- Una reserva termina el mismo día en que empieza. Las reservas pasadas están desactivadas por defecto; reservar una franja anterior el mismo día siempre está permitido.
- Las franjas de media jornada y de jornada completa también determinan la entrada y la facturación, así que fije los horarios antes de poner precios.

**Véase también:** [Días de apertura](help:user.workspace.availability.open-weekdays) · [Granularidad](help:user.workspace.availability.granularity) · [Horario de trabajo](help:user.workspace.availability.working-hours) · [Fuera del horario de apertura](help:user.workspace.availability.outside-hours) · [Límites de reserva](help:user.workspace.availability.limits)

<!-- anchor: setup.place.closure -->
### Días de cierre y días festivos

**Público:** Propietario · Administrador/a

Usted quiere que el espacio cierre los días festivos sin que nadie los reserve por error.

<p><img src="images/setup-place-availability--closure.es.jpg" width="280"></p>

**Pasos**

1. En [Disponibilidad](app:/availability), vaya a **Días de cierre**.
2. Toque **Añadir días festivos** (si no lo ve, active primero la función *Días festivos*; está desactivada por defecto) para crear todo un año de una vez, o **Añadir día de cierre** para una fecha concreta, como un día de inventario.
3. Revise la lista y quite los días en que sí trabaja.

**Conviene saber**

- Hay listas de días festivos incluidas para Francia y Alemania. Para otros países, active *Días festivos* e *Importar días festivos* (datos abiertos, requiere conexión). No se crea nada antes de que usted lo confirme.
- Se rechaza una reserva en un día de cierre, y el plano muestra el día como cerrado con su motivo.
- Los meses ya facturados se omiten, así que añada los días de cierre antes de que el mes se cierre.

**Véase también:** [Días de cierre](help:user.workspace.availability.closure-days) · [Días festivos](help:user.workspace.availability.public-holidays)

<!-- anchor: setup.place.check -->
### Revisar su espacio

**Público:** Propietario · Administrador/a

Usted quiere una prueba de que el espacio está listo antes de invitar a nadie. Lo dicen dos tarjetas.

<p><img src="images/setup-place-get-started--card.es.jpg" width="280"></p>

**Pasos**

1. Abra [Espacio](app:/workspace-settings): la tarjeta **Configuración de este espacio** enumera cada área con su estado, y el siguiente paso.
2. Abra [Reservar](app:/reserve). Los propietarios y los administradores con el permiso de configuración ven la tarjeta **Primeros pasos en** su espacio. Si falta algo, dice **Antes de que alguien pueda reservar aquí**, con **Terminar la configuración**.
3. Reserve usted mismo un asiento como prueba y cancélelo después.

**Conviene saber**

- Listo significa listo para una primera reserva: días de apertura, zona horaria, moneda, al menos un asiento y suficientes validadores.
- Todo lo opcional, como las tarifas o los pagos, puede aplazarse con **Más adelante** y no impide abrir.
- Ambas tarjetas dependen de la función *Tarjeta de primeros pasos*.
- **Ahora no** oculta la tarjeta en este dispositivo; el menú de vista del plano la recupera con **Primeros pasos**.

**Resultado** Un espacio que los miembros pueden reservar. A continuación: invitar a las primeras personas y pasar a los roles y las tarifas del segundo nivel.

**Véase también:** [La tarjeta Primeros pasos y los consejos](help:user.start.get-started) · [Invite a personas con el ID del espacio](help:user.workspace.code) · [Roles](help:user.roles.matrix)
