<!-- anchor: setup.training.overview -->
## Apréndalo en cuatro semanas

**Público:** Propietario · Copropietario

No tiene que entender DesKilo antes de empezar. Tiene que entenderlo en el orden adecuado y practicar cada paso donde un error no cuesta nada. Este capítulo es un camino de cuatro semanas, de media hora al día, con una semana previa para echar un vistazo. Cada semana termina con una lista de comprobación: cuando todas las casillas estén marcadas, continúe.

La regla de todo el camino: *aprenda en la demo, construya en un espacio de prueba y solo después toque el espacio real.*

<!-- anchor: setup.training.week0 -->
### Semana 0: eche un vistazo a la demo

**Público:** Propietario

Quiere ver el producto terminado antes de tomar decisiones. El espacio de demostración *Atelier du Marché* es inventado, está abierto a cualquiera y no cambia nada real.

**Pasos**

1. En la pantalla de inicio de sesión, pulse **Explorar el espacio de demostración** y después **Empezar**. Véase [El espacio de demostración](help:user.advanced.demo).
2. Use **Ver como** para pasar entre **Propietario**, **Administrador/a** y **Miembro**. Haga los tres ejercicios de cada persona que figuran a continuación.
3. Pulse **Reiniciar la demo** cuando quiera dejarla como al principio.

*Como miembro*

| Ejercicio | Resultado esperado |
|---|---|
| Reserve un puesto para mañana en el plano. Véase [Reservar un puesto](help:user.reserve.book). | El puesto pasa a *Reservado* en su plano y la reserva aparece en su calendario. |
| Abra su extracto. Véase [El extracto](help:user.money.statement). | Ve lo que debe, lo pagado y lo pendiente del periodo. |
| Envíe un mensaje a otro miembro. Véase [Mensajes](help:user.collaborate.messages). | El mensaje aparece en la conversación con una marca simple (enviado); aparece una doble marca cuando la otra persona lo abre. |

*Como administrador*

| Ejercicio | Resultado esperado |
|---|---|
| Abra la lista de miembros y lea la ficha de uno. | Ve su plan, su estado y su cuenta. |
| Responda a una solicitud de gasto pendiente (por ejemplo, el papel de la impresora). Véase [Reglas de validación](help:user.validation.overview). | La solicitud sale de su lista y su estado cambia para quien la hizo. Otras solicitudes pueden necesitar también al propietario y siguen abiertas. |
| Abra el [Registro de facturas](app:/invoice-register) y lea una factura. | Ve las líneas, el estado y una marca de integridad. |

*Como propietario*

| Ejercicio | Resultado esperado |
|---|---|
| Abra [Funciones](app:/features) y lea las tarjetas de dos procesos. Véase [Funciones y procesos](help:user.features.processes). | Ve qué capacidades están activadas, cuáles esperan un requisito previo y por qué. |
| Abra [Roles](app:/roles) y compare **Administrador** con **Propietario**. | El propietario tiene todos los permisos; el administrador, una parte. |
| Abra el editor de informes y mire la **Vista previa** de una factura. Véase [El editor de informes](help:user.money.reports.editor). | Ve una factura tal como la recibiría un miembro. |

*Ha terminado cuando*

- [ ] Sabe decir en una frase qué ve cada una de las tres personas que no ven las otras.
- [ ] Encontró dónde se valida una solicitud, dónde se lee una factura y dónde se activa una función.
- [ ] Anotó tres cosas que quiere en su propio espacio y tres que no.

**Véase también:** [Primeros pasos](help:user.start.get-started) · [Las palabras de la aplicación](help:user.advanced.glossary)

<!-- anchor: setup.training.week1 -->
### Semana 1: Abrir

**Público:** Propietario

Construye el lugar y sus horarios en un espacio de prueba, para que un miembro pueda reservar. Todavía no se factura nada.

**Pasos**

1. Cree un espacio de prueba propio o entre en el lado de prueba de su espacio. Véase [Crear un espacio](help:user.start.create) y [Para qué sirve un espacio de prueba](help:user.advanced.test-space).
2. Fije el país, la moneda, la zona horaria y el idioma. Véase [País](help:user.workspace.settings.country).
3. Dibuje una planta con una sala y tres puestos en el [Editor del espacio](app:/editor). Véase [El editor del plano](help:user.space.overview).
4. Elija los días laborables abiertos, la granularidad y el horario de trabajo. Véase [Días laborables abiertos](help:user.workspace.availability.open-weekdays).
5. Añada un día de cierre. Véase [Días de cierre](help:user.workspace.availability.closure-days).
6. Conserve las funciones por defecto. Abra [Funciones](app:/features) solo para leer lo que está activado.
7. Haga una reserva usted mismo y registre después la entrada y la salida. Véase [Registrar entrada y salida](help:user.reserve.check-in).
8. En [Roles](app:/roles), marque los permisos cotidianos en la tarjeta **Usuario** y comparta después el ID del espacio con una persona y deje que se una. Véase [El ID del espacio](help:user.workspace.code).

**Conviene saber**

- Un espacio puede reservarse cuando tiene una zona horaria, una moneda, al menos un día laborable abierto, al menos un puesto y miembros que tengan **Reservar y usar las reservas**. Todo lo demás puede esperar.
- Un plano no se puede sustituir mediante una importación cuando ya existe una reserva.

*Ha terminado cuando*

- [ ] Una segunda persona encontró el espacio con su ID y reservó un puesto sin su ayuda.
- [ ] Sabe explicar por qué el plano muestra un puesto como *Reservado*, *Libre* o *Bloqueado*.
- [ ] Conoce sus reglas de apertura de memoria: días, horas, límite de la media jornada.

**Véase también:** [Horario de trabajo](help:user.workspace.availability.working-hours) · [Políticas de reserva](help:user.workspace.availability.policies)

<!-- anchor: setup.training.week2 -->
### Semana 2: Funcionar

**Público:** Propietario · Administrador/a

Decide quién puede hacer qué, qué paga cada miembro y a quién se avisa de qué. Lo hace con una segunda persona, porque las reglas solo se muestran cuando alguien más se topa con ellas.

<p><img src="images/setup-training-roles.es.jpg" width="280"></p>

**Pasos**

1. Represente una validación con una segunda persona. Conviértala en administradora, fije una validación requerida para las reservas, reserve después como miembro y deje que la administradora confirme. Véase [Reglas de validación](help:user.validation.overview) y [Roles](help:user.roles.space).
2. Suba el número requerido a dos y observe cómo la solicitud queda en espera. Después vuelva a bajarlo. Una regla que necesita más validadores de los que existen deja las solicitudes esperando para siempre.
3. Escriba primero las tarifas en papel: niveles de suscripción en porcentaje, el tramo de tarifa de cada nivel, el precio por encima del derecho. Introdúzcalas después en Facturación y asigne el nivel al miembro en Miembros y planes. Véase [Miembros y planes](help:user.members.subscription).
4. Dé un nivel a la segunda persona y deje que reserve por encima de su derecho. Lea el extracto.
5. Pruebe las notificaciones: un mensaje, una solicitud pendiente, una reserva cancelada. Véase [Notificaciones](help:user.collaborate.notifications).
6. Abra [Roles](app:/roles) y compruebe lo que puede hacer un administrador. Quite un permiso y vea qué desaparece para él.

**Conviene saber**

- Las notificaciones dentro de la aplicación funcionan de inmediato. Las notificaciones push necesitan además la configuración del operador, así que una prueba puede no mostrar nada en un teléfono. Pregunte a su operador.
- Los recordatorios de pago automáticos se ejecutan una vez al día en el servidor cuando la instalación tiene su programador, y también cuando una persona autorizada abre Finanzas.

*Ha terminado cuando*

- [ ] Vio una solicitud atravesar la validación que configuró, y otra quedarse en espera.
- [ ] Sus tarifas caben en una hoja y el extracto del miembro de prueba coincide con sus cuentas.
- [ ] Sabe a quién se avisa de qué.

**Véase también:** [Reglas de validación](help:user.validation.overview) · [Roles y permisos](help:user.roles.matrix)

<!-- anchor: setup.training.week3 -->
### Semana 3: Crecer

**Público:** Propietario · Administrador/a de facturación

Hace la primera factura, en dos idiomas, en el espacio de prueba, con su gestor mirando por encima del hombro.

**Pasos**

1. Rellene su identidad legal y su régimen de IVA junto con su gestor. Véase [Su identidad legal](help:user.money.legal.identity) y [Régimen de IVA](help:user.money.vat.regime).
2. Cierre un mes y emita una factura de prueba en el espacio de prueba. Véase [El asistente de cierre mensual](help:user.invoicing.wizard).
3. Abra la factura con el diseño **Profesional** y después en un segundo idioma. Véase [Un diseño por idioma](help:user.money.reports.languages).
4. Exporte el registro del periodo en el formato que usa su gestor. Véase [Exportaciones contables](help:user.invoicing.accounting-export).
5. Haga tres preguntas al gestor: ¿Son correctas las menciones? ¿Es correcto el tratamiento del IVA? ¿Puede leer el archivo?
6. Anote las respuestas. Se convertirán en el resumen para el espacio real.

**Conviene saber**

- Hoy la aplicación emite facturas solo en Francia y Alemania. Se niega a emitir cuando falta un dato esencial y dice cuál falta.
- Las facturas de un espacio de prueba llevan una marca de agua que lo indica.

> **Atención** Tras la primera factura emitida en el espacio real, la factura queda congelada, su número no puede reutilizarse y ese mes queda bloqueado para el miembro. Las correcciones se hacen mediante una anulación, una factura rectificativa o un reembolso.

*Ha terminado cuando*

- [ ] Existe una factura de prueba, leída por su gestor, en dos idiomas.
- [ ] Exportó un archivo para el gestor y lo pudo abrir.
- [ ] Tiene las respuestas por escrito.

**Véase también:** [Documentos e informes](help:setup.reports.overview) · [El registro de facturas](help:user.invoicing.register)

<!-- anchor: setup.training.week4 -->
### Semana 4: salir en vivo

**Público:** Propietario · Copropietario

Pasa del ensayo al espacio real, y no lo hace solo: invita a cinco personas a que lo vean.

*La lista de comprobación de la salida en vivo*

1. Decida si conserva su espacio de prueba como lado de ensayo o crea el espacio real. Si el espacio tiene dos lados, despliegue del lado de prueba al real. Véase [Desplegar entre los dos lados](help:user.advanced.deploy).
2. Si en cambio crea el espacio real, repita lo que funcionó: el mismo país, moneda y zona horaria, el mismo plano, las mismas reglas, tarifas y roles. Una plantilla, una transferencia de configuración o un despliegue entre los dos lados incluye la mayor parte. Véase [Exportar, importar y configuración](help:user.workspace.export.space-xml).
3. Introduzca de nuevo su identidad legal en el espacio real. Una plantilla nunca la incluye; un despliegue entre los dos lados sí, pero nunca las credenciales. Compruébela en cualquier caso.
4. Declare el espacio como producción solo cuando las facturas que salgan de él se deban de verdad. Véase [Entrar en el lado real o en el de prueba](help:user.advanced.enter-environment).
5. Invite a cinco personas, no a cincuenta. Véase [El mensaje de invitación](help:user.workspace.settings.invitation-message).
6. Observe sus primeras reservas. Abra [Reservar](app:/reserve) y lea qué sigue pidiendo la tarjeta **Primeros pasos**.
7. Pasada una semana, haga un balance: qué pregunta hicieron, qué regla les sorprendió, qué ajuste quiere cambiar ahora.

**Conviene saber**

- Las credenciales, como los tokens de facturación electrónica o las claves del proveedor de pagos, nunca viajan entre espacios. Introdúzcalas de nuevo.
- Una copia de recuperación antes de la primera factura es barata. Véase [Documentos e informes](help:setup.reports.accountant).

*Ha terminado cuando*

- [ ] Cinco personas reales reservaron sin preguntarle cómo.
- [ ] Sabe dónde mirar cuando algo no funciona.
- [ ] Programó su primer cierre mensual.

**Véase también:** [Un espacio tiene dos lados](help:user.advanced.environments)

<!-- anchor: setup.training.glossary -->
### Veinte palabras de la configuración

**Público:** Propietario · Copropietario

Las decisiones con las que se encontrará tienen nombre. Esto es lo que significa cada una en DesKilo.

| Término | Significado |
|---|---|
| Granularidad | La unidad de una reserva: media jornada, día, hora o minutos. Decide cómo se divide el plano. |
| Límite de la media jornada | La hora que separa la mañana de la tarde, fijada con el inicio y el final de la jornada de trabajo. |
| Exceso | El uso por encima del derecho de un miembro. Usted elige bloquearlo, cobrarlo según se produce o vender bonos. |
| Tramo de tarifa | El precio de una suscripción, según el porcentaje del derecho que toma el miembro. |
| Dominio de validación | Un tipo de solicitud con su propia regla: una reserva, un gasto, un reembolso y otros. |
| Quórum | El número de validadores que necesita una solicitud. Más que las personas que pueden validar la deja en espera. |
| Exigibilidad | El momento en que se devenga el IVA: con el cobro, en el mes del servicio o con la factura, según la ley del país, salvo opción por otra base (el criterio de caja en España). |
| Reinicio de numeración | Cada cuánto vuelve a empezar el número de factura. No puede ser más frecuente que la fecha impresa en la factura. |
| Par de entornos | Un lado de prueba y un lado real de un mismo espacio. |
| Plantilla | Una configuración guardada (plano, reglas, tarifas, roles) que puede aplicar a un espacio nuevo. Nunca incluye la identidad ni los datos de pago. |
| Preparación | La lista de comprobación al principio de los ajustes del espacio que dice qué falta antes de que la gente pueda reservar, y antes de la primera factura. |
| Retenida | Una función que está activada pero espera a otra que está desactivada. |
| Quiosco | Una pantalla compartida en la puerta donde los miembros registran su entrada y su salida. |
| Credencial | Una tarjeta o etiqueta que un miembro muestra para registrarse en un quiosco. |
| Perfil gestionado | Un miembro que usted lleva por alguien que aún no tiene cuenta, y que se le entrega más tarde con un código. |
| Día de cierre | Un día en que el espacio está cerrado, como un festivo. |
| Vocabulario (léxico) | Las palabras que sustituye en la aplicación para ajustarlas a su lugar, como la forma de llamar a un miembro. |
| Exportación de recuperación | Una copia de los ajustes y los datos que guarda antes de un cambio importante. Aparece en la lista de preparación. |
| Nivel ofrecido | Un nivel de suscripción que usted ofrece a los miembros. Debe existir antes de que nadie lo elija. |
| Tipo de vendedor | El tipo de organización que es cuando factura. Decide las menciones por defecto. |

**Véase también:** [Las palabras de la aplicación](help:user.advanced.glossary)

<!-- anchor: setup.training.help -->
### Dónde pedir ayuda

**Público:** Todos

Se ha atascado en un campo o en una decisión.

**Pasos**

1. Pulse el **?** junto a un campo. La guía se abre en ese campo.
2. Abra la [Ayuda](app:/help) y use el **Índice** para saltar. Los consejos de las pantallas se pueden pasar con **Consejo siguiente**.
3. Cuando falla la aplicación, abra **Detalles de soporte** y envíe la vista previa. Véase [Detalles de soporte](help:user.advanced.support).
4. Para una decisión legal o fiscal, pregunte a su gestor. Para su instalación, pregunte a su operador. Para saber cómo lo hicieron otros propietarios, pregunte a su comunidad.

**Conviene saber**

- La guía funciona sin conexión y en su idioma.
- Contacte con el soporte con el archivo de **Detalles de soporte**. No contiene ninguna identidad ni ningún registro del negocio.

**Véase también:** [Dónde obtener más ayuda](help:user.advanced.help)

<!-- anchor: setup.training.cheatsheet -->
### La hoja de referencia

**Público:** Propietario · Copropietario

Toda la configuración en una página. *Reversible* indica si puede cambiar de opinión después de haberlo hecho.

| Paso | Dónde en la aplicación | Cuánto dura | ¿Reversible? |
|---|---|---|---|
| 1. País, moneda, zona horaria, idioma | [Ajustes del espacio](app:/workspace-settings) | 5 minutos | Sí, hasta el primer documento o pago; después la moneda y el país quedan bloqueados |
| 2. Plano | [Editor del espacio](app:/editor) | 30 minutos | Sí, hasta la primera reserva; después se edita un objeto cada vez |
| 3. Reglas de apertura | Disponibilidad | 10 minutos | Sí |
| 4. Funciones | [Funciones](app:/features) | 10 minutos | Sí. Desactivar detiene el uso nuevo y no borra nada |
| 5. Roles y validación | [Roles](app:/roles) | 20 minutos | Sí, pero una regla que necesite demasiados validadores bloquea las solicitudes |
| 6. Tarifas y niveles | [Facturación](app:/billing) (los niveles se asignan en Miembros y planes) | 1 hora | Sí para el futuro; los importes emitidos se quedan |
| 7. Identidad legal y régimen de IVA | Identidad legal | 1 hora con su gestor | Atención tras la primera factura |
| 8. Numeración de facturas y menciones | Identidad legal | 20 minutos | No, tras la primera factura |
| 9. Diseños de informes | [Editor de informes](app:/report-editor) | 1 hora | Sí para los documentos nuevos; los emitidos se quedan |
| 10. Mensaje de invitación | Ajustes del espacio | 10 minutos | Sí |
| 11. Prueba de notificaciones | Mensajes, solicitudes | 20 minutos | Sí |
| 12. Factura de prueba en el lado de prueba | Facturación | 1 hora | Solo el lado de prueba |
| 13. Espacio real o despliegue | [Yo](app:/me) | 1 hora | Atención: producción significa que las facturas se deben |
| 14. Invitar a los cinco primeros | Ajustes del espacio | 10 minutos | Sí |

**Véase también:** [La secuencia que debe seguir](help:setup.reports.sequence)
