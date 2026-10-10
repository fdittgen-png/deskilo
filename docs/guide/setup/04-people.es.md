<!-- anchor: setup.people.overview -->
## Personas, roles y decisiones

Un espacio son sus personas. Antes de invitar a la primera, decida tres cosas: quién puede hacer qué, cómo entra alguien y qué actos necesitan que una segunda persona diga que sí. Se fijan rápido, pero son incómodas de reparar cuando cuarenta personas ya cuentan con ellas.

En este capítulo:
- [Quién hace qué en una organización real](help:setup.people.organisation)
- [La matriz de roles: el mínimo privilegio](help:setup.people.matrix)
- [Copropietarios: más de una persona que pueda actuar](help:setup.people.coowner)
- [Cómo se une la gente](help:setup.people.join)
- [El mensaje de invitación, idioma por idioma](help:setup.people.invitation)
- [Perfiles gestionados](help:setup.people.managed)
- [Validación: de qué se compone una regla](help:setup.people.validation)
- [Tres ajustes preestablecidos para copiar](help:setup.people.presets)
- [Evite solicitudes que esperan para siempre](help:setup.people.stuck)
- [La primera semana de sus miembros](help:setup.people.first-week)

El ejemplo que seguimos es *Atelier du Marché*. Imagine que lo dirige una asociación: Ada es la presidenta, Chiara la secretaria y Bruno el tesorero. Cada paso de abajo se muestra en ese espacio.

<!-- anchor: setup.people.organisation -->
### Quién hace qué en una organización real

**Público:** Propietario · Copropietario

Usted quiere trasladar a las personas de su organización a los roles que tiene DesKilo, de modo que nadie tenga más de lo que su trabajo exige.

<p><img src="images/setup-people-members.es.jpg" width="280"></p>

*Los cuatro roles de base*

| Rol | Para qué sirve | En la asociación |
|---|---|---|
| **Propietario** | La persona que responde del espacio y tiene todos los permisos. Solo un propietario puede conceder la propiedad. | Ada, la presidenta. |
| **Copropietario** | Una segunda llave. Tiene todos los permisos por defecto y puede tomar el relevo cuando el propietario se va. | La vicepresidenta, si la junta tiene una. |
| **Administrador** | Lleva el día a día: miembros, reservas de otros, el quiosco, documentos, servicios. Tiene lo que da la matriz y nada más. | Chiara, la secretaria. |
| **Usuario** | La persona que usa el espacio. Solo tiene los permisos cotidianos que usted le dé. | Bruno, un miembro como los demás. |

Cada persona tiene exactamente un rol de base. Un rol que define el espacio, como *Anfitrión* o *Contable*, se añade encima y nunca quita nada.

*Un tesorero sin ser administrador*

Bruno lleva las cuentas, pero no debería editar el plano ni aprobar miembros nuevos. Dele el rol de base **Usuario** y añada un rol propio, por ejemplo *Contable*, con cuatro permisos: **Ver las finanzas del espacio**, **Emitir facturas y conciliar pagos**, **Exportar contabilidad y datos** y **Consultar las cifras del espacio**. Nada más. No existe ningún rol así de serie; lo crea con los pasos de abajo.

<p><img src="images/setup-people-roles-space.es.jpg" width="280"></p>

**Pasos**

1. Abra [Roles que define este espacio](app:/settings/roles-of-this-space) y toque **Añadir un rol**. Véase [Los roles de este espacio](help:user.roles.space).
2. Ponga nombre al rol, elija **Lo que añade** y toque **Guardar el rol**.
3. Abra a la persona en [Miembros y planes](app:/members), busque **Roles** y toque **Añadir un rol**.

**Conviene saber**

- **Los roles de este espacio** es una función aparte y está desactivada en un espacio nuevo. Actívela en [Funciones](app:/features).
- Nadie puede darse un rol a sí mismo. Dar un rol requiere **Gestionar roles y permisos**, y solo un propietario puede dar un rol que lo incluya.
- Un rol que define el espacio surte efecto al instante y queda registrado. Solo hacer administrador a alguien, o quitárselo, sigue la regla de validación **Cambio de rol**.

**Resultado** Cada persona de la junta tiene los permisos de su trabajo, y el propietario sigue siendo el único que puede cambiarlos.

**Véase también:** [La matriz de roles](help:user.roles.matrix)

<!-- anchor: setup.people.matrix -->
### La matriz de roles: el mínimo privilegio

**Público:** Propietario · Copropietario

Usted quiere que cada rol tenga lo que necesita y nada más. Es el principio del mínimo privilegio: empiece con poco y añada cuando alguien lo pida, porque un permiso concedido pocas veces se retira de buen grado.

<p><img src="images/setup-people-roles-matrix.es.jpg" width="280"></p>

**Pasos**

1. Abra [Roles](app:/roles). Hay una tarjeta por rol: **Propietario**, **Copropietario**, **Administrador** (el propietario puede renombrarlo) y **Usuario**.
2. Lea primero la tarjeta del **Administrador**. Muestra lo que hoy tiene un administrador en su espacio.
3. Desmarque lo que no quiera delegar. Marque los permisos cotidianos que necesita la tarjeta **Usuario** (véase más abajo).

*Lo que tiene un administrador por defecto*

| Grupo | Permisos |
|---|---|
| Personas | **Gestionar miembros**, **Consultar los datos personales de los miembros** |
| Reservas y el lugar | **Gestionar reservas de otros**, **Operar el quiosco y las tarjetas**, **Gestionar sedes y editar el plano** |
| Dinero: lectura y aprobación | **Ver las finanzas del espacio**, **Aprobar gastos**, **Gestionar servicios y paquetes**, **Consultar los acuerdos comerciales**, **Gestionar los acuerdos comerciales**, **Solicitar cambios de condiciones de pago**, **Exportar contabilidad y datos** |
| Documentos y cifras | **Gestionar la biblioteca de documentos**, **Consultar las cifras del espacio** |
| Las dos caras de un espacio | **Desplegar en desarrollo**, **Entrar en el espacio de producción** |

Un administrador no tiene **Gestionar roles y permisos**, **Configurar reglas de validación**, **Editar la configuración del espacio**, **Gestionar tarifas y reglas de facturación**, **Diseñar los documentos**, **Gestionar integraciones**, **Gestionar la configuración** ni **Desplegar en producción**. Un copropietario los tiene todos hasta que usted desmarque alguno. El propietario siempre los tiene todos.

> **Atención** En un espacio nuevo, la tarjeta **Usuario** está vacía. Los seis permisos cotidianos (**Usar la mensajería**, **Reservar y usar las reservas**, **Ver el calendario**, **Ver el directorio de miembros**, **Ver su propia cuenta y sus facturas**, **Ver los documentos compartidos**) solo se tienen a través de la matriz o de un rol. Mientras no los marque, un miembro que se une no puede abrir el plano. La demostración los muestra ya marcados, lo que lo oculta. Márquelos en la tarjeta **Usuario**, y en la tarjeta **Administrador** si los administradores también reservan, y pruebe después con una segunda cuenta.

**Conviene saber**

- Por defecto, un administrador puede leer todas las finanzas y los datos personales de todos los miembros. Si sus administradores son voluntarios, piense si deberían poder.
- **Los admins emiten facturas** (una función, desactivada por defecto, bajo **Facturas**) da a los administradores **Emitir facturas y conciliar pagos** diga lo que diga la matriz. Es preferible la marca en la matriz, o un rol propio, que es más preciso.
- Desmarcar un permiso lo retira en todas partes a la vez; lo comprueba el servidor, no solo el menú.
- Cada cambio de la matriz queda registrado como un evento. La función **Gestión de roles** solo muestra la pantalla; desactivada, la matriz que guardó sigue aplicándose, solo que no se puede editar.

**Resultado** Una matriz que puede explicar en una frase por rol.

**Véase también:** [La matriz de roles](help:user.roles.matrix) · [Quién hace qué](help:setup.before.who)

<!-- anchor: setup.people.coowner -->
### Copropietarios: más de una persona que pueda actuar

**Público:** Propietario · Copropietario

Usted quiere que el espacio siga funcionando cuando esté enfermo, de viaje o ya no esté. Todo espacio necesita más de una persona que pueda actuar. Por defecto, solo los propietarios y los copropietarios tienen los permisos que cambian las funciones, los roles, las reglas de validación y el ID del espacio, y solo un propietario puede nombrar a otro propietario.

<p><img src="images/setup-people-coowner.es.jpg" width="280"></p>

*Los dos tipos*

| Tipo | Qué hace | Elíjalo cuando |
|---|---|---|
| *Copropietario activo* | Tiene ya los permisos del propietario y toma el relevo si el propietario se va. | Comparten el trabajo: la vicepresidenta, un socio. |
| **Sucesor** | Espera. Pasa a ser propietario cuando usted lo promueve o cuando usted se va. | Solo quiere un heredero. |

**Pasos**

1. Active la función **Copropietarios** en [Funciones](app:/features). Está desactivada en un espacio nuevo.
2. Abra a la persona en [Miembros y planes](app:/members), vaya a **Gestionar** y toque **Copropiedad**.
3. Elija *Copropietario activo* o **Sucesor**. Para traspasar ya, elija **Promover a propietario ahora**.

**Conviene saber**

- Si se va el último propietario, el mejor copropietario pasa a ser propietario por sí solo, uno activo antes que un sucesor.
- Dos administradores no son lo mismo: un administrador solo tiene lo que da la matriz y nunca puede transmitir la propiedad.
- Una regla que dice **El propietario siempre debe validar** exige un propietario. Compruebe en su lado de prueba que su copropietario puede seguir decidiendo lo que usted espera.

**Resultado** El espacio tiene una segunda persona que puede actuar.

**Véase también:** [Copropietarios](help:user.roles.co-owners) · [Copropiedad](help:user.members.co-ownership)

<!-- anchor: setup.people.join -->
### Cómo se une la gente

**Público:** Propietario · Administrador/a

Usted quiere elegir cómo llega la gente a su espacio y quién la deja entrar. Existen cuatro vías, y todas terminan en el mismo sitio: una persona que pide unirse y alguien que decide.

<p><img src="images/setup-people-workspace-code.es.jpg" width="280"></p>

| Vía | Qué recibe la persona | En qué se convierte |
|---|---|---|
| El ID del espacio | Una palabra corta, que escribe en la aplicación. | Miembro, tras la aprobación. |
| El código QR | El mismo ID como imagen para imprimir o colgar (**Compartir como PNG**). | Miembro, tras la aprobación. |
| Un mensaje de invitación | Un texto con un código personal, válido para una sola persona, en el idioma que usted elija. | El rol que usted ofrezca, tras la aprobación. |
| Un código de administrador | Un código para una persona, de la pestaña **Invitación de administrador/a**. | Administrador, una sola vez. |

**Pasos**

1. Abra [ID del espacio y QR](app:/workspace-code). Elija un ID que la gente pueda recordar con **Cambiar el ID del espacio**: de 4 a 20 letras o cifras, único en todo DesKilo.
2. Para una persona con nombre, toque **Invitar a alguien**. Rellene el nombre, marque **Roles al llegar** si debe recibir un rol, elija el **Idioma del mensaje** y envíe.
3. Cuando alguien pide unirse, su fila en [Miembros y planes](app:/members) dice **Pendiente**. Ábrala y elija **Aprobar membresía** o **Rechazar membresía**.

**Conviene saber**

- Nadie entra sin una decisión. Hasta que se toma, quien llega ve una pantalla de espera y nada más.
- La decisión sigue la regla de **Nuevo miembro** en [Reglas de validación](app:/validation): por defecto basta con un propietario o un administrador; si exige dos, la primera aprobación deja a la persona pendiente.
- Si cambia el ID del espacio, el antiguo deja de funcionar. Vuelva a imprimir el código QR.
- No existe invitación de propietario. La propiedad se concede en **Miembros y planes**.

**Resultado** La gente puede encontrarle y usted decide quién se queda.

**Véase también:** [El ID del espacio](help:user.workspace.code) · [Unirse a un espacio](help:user.start.join) · [Miembros pendientes y en pausa](help:user.members.pending)

<!-- anchor: setup.people.invitation -->
### El mensaje de invitación, idioma por idioma

**Público:** Propietario · Administrador/a

Usted quiere una invitación que suene a su espacio, en el idioma de quien la recibe. Cada idioma tiene su propio texto; el que usted no escriba recurre al mensaje incluido.

<p><img src="images/setup-people-invite.es.jpg" width="280"></p>

<p><img src="images/setup-people-invitation-message--message.es.jpg" width="280"></p>

**Pasos**

1. Abra [Espacio](app:/workspace-settings) y vaya a **Comunidad e invitaciones**.
2. En **Idioma del mensaje**, elija el idioma para el que escribe. La fila se abre en el idioma de su espacio.
3. Escriba el texto. Toque una etiqueta para insertarla donde está el cursor. El límite es de 2000 caracteres.
4. Repita para cada idioma que usen sus miembros y toque **Guardar**.

*Las etiquetas*

| Etiqueta | Se rellena con |
|---|---|
| `{firstName}` `{lastName}` `{phone}` | Lo que escribió en **Invitar a alguien**. Vacío si no escribió nada. |
| `{workspaceName}` | El nombre de su espacio. |
| `{workspaceId}` | El código de invitación personal de este mensaje (no el ID público del espacio). |
| `{inviteLink}` | Un enlace que abre la aplicación en el servidor correcto con el código ya rellenado. |
| `{downloadUrl}` | La página de la aplicación en la tienda. |
| `{role}` | El rol que ofrece la invitación, en el idioma del mensaje. |

**Conviene saber**

- Si deja el cuadro vacío, la aplicación escribe su propio mensaje en ese idioma. Explica los pasos: descargar, crear una cuenta, unirse con el código.
- No pegue usted mismo un código ni un enlace. Cada envío crea su propio código, válido para una sola persona.
- Una etiqueta mal escrita queda visible en el texto enviado: lea la vista previa antes de enviar.
- El mensaje incluido avisa a la persona de que el código es de un solo uso y válido durante 14 días.

**Resultado** Una invitación que sus miembros pueden seguir sin tener que preguntarle.

**Véase también:** [Mensaje de invitación](help:user.workspace.settings.invitation-message) · [Invitar a alguien por mensaje](help:user.workspace.code.invite)

<!-- anchor: setup.people.managed -->
### Perfiles gestionados

**Público:** Propietario · Administrador/a

Usted quiere reservar, facturar y gestionar para alguien que aún no tiene cuenta: un visitante, un miembro mayor, una persona que prefiere el papel.

**Pasos**

1. Active **Perfiles gestionados** en [Funciones](app:/features).
2. En [Miembros y planes](app:/members), toque **Añadir un perfil gestionado** y rellene la identidad.
3. Cuando la persona esté lista, abra su página y elija **Entregar a la persona**. Se crea un código personal vinculado al perfil.

**Conviene saber**

- Quien canjee el código asume el perfil con sus reservas, sus facturas y su suscripción, una vez que usted apruebe la membresía.
- Retire la entrega con **Revocar la entrega** si el código aún no se ha usado.

**Véase también:** [Añadir un perfil gestionado](help:user.members.managed)

<!-- anchor: setup.people.validation -->
### Validación: de qué se compone una regla

**Público:** Propietario

Usted quiere decidir, acto por acto, si una segunda persona debe estar de acuerdo. Un dominio de validación es una clase de acto con su propia regla: *un pago*, *un gasto*, *un miembro nuevo*, *la eliminación de una reserva*. En **Reglas de validación**, los dominios están en tres grupos.

<p><img src="images/setup-people-validation-overview.es.jpg" width="280"></p>

| Grupo | Dominios, en palabras sencillas | Mientras espera |
|---|---|---|
| **Finanzas** | Un pago, un gasto, un servicio, una factura conciliada con su pago, una factura emitida o anulada, un reembolso, una condonación, un acuerdo de precios, un gasto compartido, un gasto programado, un cambio de condiciones de pago, una salida anticipada, un registro de uso eliminado | El importe no cuenta en el estado de cuenta de nadie. |
| **Reservas** | **Medias jornadas extra** que pide un miembro, **Reservas de espacios enteros**, una reserva hecha para un miembro por un administrador, una **Eliminación de reserva** | El puesto se queda como estaba. |
| **Personas y roles** | **Nuevo miembro**, un cambio de rol, un cambio de estado, un cambio de suscripción, un cambio de la matriz de permisos | La persona conserva el acceso que tiene ahora. |

Todo dominio empieza con **Hereda la predeterminada**: una validación de cualquier administrador o propietario. **Regla predeterminada** es la regla que heredan todas las demás. Un dominio que usted abre y guarda pasa a ser **Personalizada**.

*Los mandos de una regla*

| Ajuste | Qué significa | Necesita |
|---|---|---|
| **Validaciones requeridas** | Cuántas personas deben decir que sí. | |
| **Quién valida** | **Admins**, **Personas designadas** o **Todos los miembros**. El propietario siempre puede. | **Validadores por rol o persona**: sin ella no se muestra la elección y validan los administradores. Tras desactivarla, revise de nuevo las reglas que nombraban a **Personas designadas** |
| **Los admins pueden validar** | Desactivado, solo validan los propietarios. | |
| **El propietario siempre debe validar** | Uno de los síes debe venir de un propietario. | |
| **La propiedad puede validar lo propio** | La solicitud del propio propietario no se queda esperando a otra persona. Un administrador nunca recibe esto. | **Validaciones encadenadas** |
| **Una tras otra** | La segunda se pide cuando la primera ha dicho que sí. | **Validaciones encadenadas** |
| **Solo por encima de este importe** | Por debajo, el acto se aplica de inmediato. Solo en los dominios de dinero. | **Validaciones encadenadas** |
| **Los admins eliminan sin validación** / **Los propietarios eliminan sin validación** | Su propia **Eliminación de reserva** se resuelve sola y queda marcada como autovalidada. Desactivado por defecto. | |

<p><img src="images/setup-people-validation-sheet.es.jpg" width="280"></p>

**Pasos**

1. Abra [Reglas de validación](app:/validation). Toque **Regla predeterminada** y decida qué hereda todo lo demás.
2. Toque un dominio, fije los mandos y toque **Guardar**.
3. Mantenga pocas excepciones. Cada excepción es una cosa más que debe recordar cuando alguien pregunte «¿por qué esto está esperando?».

**Conviene saber**

- Nadie valida su propio acto. Espera a otra persona, salvo que esté activada la excepción del propietario.
- Cada decisión queda registrada: quién, cuándo, sobre qué.
- Una solicitud a la que nadie responde caduca a los siete días, al barrerla la próxima vez que alguien abre Eventos. Un acto que un administrador hizo por un miembro se confirma automáticamente.

**Véase también:** [Reglas de validación, dominio por dominio](help:user.validation.overview) · [Quién puede validar](help:user.validation.who-may) · [Validación automática](help:user.validation.auto-validate-admin)

<!-- anchor: setup.people.presets -->
### Tres ajustes preestablecidos para copiar

**Público:** Propietario

Usted quiere un conjunto de reglas que pueda copiar hoy y afinar después. Elija uno; todos se apoyan en el alcance por defecto, el propietario y los administradores, así que no hace falta ninguna función adicional.

| Ajuste | Elíjalo cuando | Qué fija | Validadores que necesita |
|---|---|---|---|
| *Unión abierta* | Conoce a las personas que escanearán su código. | Nada. Cada dominio hereda la predeterminada: una validación de cualquier propietario o administrador. Una unión sigue sin ser nunca automática. | 1 (usted) |
| *Aprobar uniones* | Una junta decide quién entra. | **Nuevo miembro**: **Validaciones requeridas** 2, **El propietario siempre debe validar** activado. | 2: un propietario y un administrador |
| *Aprobar uniones y reservas* | Los puestos o las salas enteras escasean, o las eliminaciones de reservas necesitan un testigo. | *Aprobar uniones*, más, en **Reservas de espacios enteros**, **Medias jornadas extra** y **Eliminación de reserva**: **Validaciones requeridas** 1. | 2 como mínimo, 3 para estar cómodo |

En la asociación: Ada es la propietaria y Chiara administradora. Con *Aprobar uniones*, Ada y Chiara aprueban ambas a cada recién llegado. Con el tercer ajuste, una sala entera que reserva Bruno queda bloqueada para él de inmediato, pero Ada o Chiara aún pueden rechazarla, y una eliminación que pide Chiara la decide Ada, no Chiara.

**Pasos**

1. Abra [Reglas de validación](app:/validation).
2. Toque **Nuevo miembro**, fije lo que dice la tabla y toque **Guardar**.
3. Para el tercer ajuste, repita en los otros tres dominios.
4. Abra **Miembros y planes** y cuente sus propietarios y administradores activos. Deben ser al menos el número de la última columna.

**Conviene saber**

- Estos ajustes nunca retienen para su aprobación una reserva ordinaria de un miembro. Lo que espera es una sala entera, unas medias jornadas extra, una eliminación y la unión.
- Un ajuste preestablecido es un punto de partida. Suba un número solo cuando tenga suficientes personas para responder.

**Véase también:** [Validaciones requeridas](help:user.validation.required-count) · [Se requiere un propietario](help:user.validation.owner-required)

<!-- anchor: setup.people.stuck -->
### Evite solicitudes que esperan para siempre

**Público:** Propietario · Copropietario

Usted quiere estar seguro de que toda solicitud para la que crea una regla puede recibir respuesta. Una regla que necesita más validadores de los que existen no se rechaza en todas partes: la solicitud se crea, nadie puede completarla y caduca a los siete días.

> **Atención** El editor cuenta un validador adicional para la persona afectada, así que le deja guardar **Validaciones requeridas** con uno más que las personas que tiene. Ese sí adicional existe solo para una reserva que un administrador hizo para un miembro y para algunos pagos. Para una unión o una solicitud de dinero no existe. No confíe en que el editor cuente por usted.

*Cuente antes de exigir*

| Usted exige | Necesita, además de la persona que pide |
|---|---|
| 1 | Un propietario o administrador activo |
| 2 | Dos propietarios o administradores activos |
| 2 con **El propietario siempre debe validar** | Un propietario y otra persona más |
| Una lista de **Personas designadas** | Cada persona de la lista debe estar activa; un administrador nuevo no se añade automáticamente |

*Cómo comprobarlo*

1. Abra [Reglas de validación](app:/validation) y lea cada tarjeta personalizada: «Todos los admins — 2 cualesquiera» significa dos personas.
2. Abra [Miembros y planes](app:/members). Cuente los propietarios y administradores activos. Las personas en pausa o que han salido no cuentan.
3. Abra **Configuración de este espacio** en [Espacio](app:/workspace-settings). El área **Roles y quién valida las solicitudes** dice «Una regla pide más validadores de los que tiene este espacio» cuando cuenta pocos. Solo retiene la primera reserva cuando la regla es para reservas.
4. Abra [Eventos](app:/events). **Esperando su confirmación** muestra lo que está esperando, y una fila muestra «1/2 validaciones».

**Conviene saber**

- El propio editor dice **No hay suficientes validadores elegibles.** cuando un recuento supera claramente a las personas disponibles. No detecta todos los casos.
- Un propietario solo que pide algo para sí mismo está esperando a otra persona: añada un administrador, o active **La propiedad puede validar lo propio** en **Validaciones encadenadas**.
- Poner en pausa o retirar a un administrador puede dejar corta una regla. Vuelva a contar tras cada cambio de equipo.

**Resultado** Toda regla puede recibir respuesta de personas que existen.

**Véase también:** [Validaciones requeridas](help:user.validation.required-count) · [Mantenga la coherencia](help:setup.consistent.overview)

<!-- anchor: setup.people.first-week -->
### La primera semana de sus miembros

**Público:** Propietario · Administrador/a

Usted quiere que sus primeros miembros lo logren sin preguntarle. Lo que les diga la primera semana decide cuánto tendrá que responder la segunda.

*Antes de invitar a nadie*

1. Inicie sesión como una segunda persona con una cuenta de prueba y únase a su espacio. Compruebe que puede abrir el plano y reservar un asiento.
2. Apruebe esa cuenta como miembro y, si exige dos, haga que el segundo validador también apruebe.

**Pasos**

1. Envíe el mensaje de invitación. Explica cómo descargar la aplicación, crear una cuenta y unirse. Véase [Unirse a un espacio](help:user.start.join).
2. Apruebe a cada recién llegado el mismo día. Quien espera un día empieza con una duda.
3. Cuéntele las tres primeras cosas: el plano y la reserva ([Reservar un puesto](help:user.reserve.book)), el registro de entrada ([Entrar y salir](help:user.reserve.check-in)) y dónde esperan sus solicitudes ([Eventos](help:user.collaborate.events)).
4. Dígale qué ve usted de esa persona y qué controla ella ([Quién puede ver mis datos](help:user.privacy.visibility)).
5. Nombre a una persona a quien preguntar, y dónde: la mensajería o el mostrador.

**Conviene saber**

- Cuando un administrador hace algo por un miembro, queda pendiente hasta que el miembro lo confirma. Avíselos, o la primera reserva que haga por alguien parecerá un error.
- Los miembros que no usan notificaciones push encuentran todo igualmente en **Eventos**.
- En la primera visita a Reservar, la tarjeta **Primeros pasos** muestra a los propietarios lo que aún falta. Los miembros tienen sus propios consejos breves. Véase [La tarjeta Primeros pasos y los consejos](help:user.start.get-started).

**Resultado** Personas que saben reservar, entrar y a quién preguntar.

**Véase también:** [De la semana 0 a la semana 4](help:setup.training.overview) · [Cómo se informa a los miembros](help:setup.notify.members)
