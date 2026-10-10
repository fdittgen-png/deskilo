<!-- anchor: user.advanced.overview -->
## Avanzado

**Público:** Propietario · Operador/a

Lo que rodea al trabajo diario: la cara de pruebas de un espacio y la real, los asistentes, el grabador de tareas y sus visitas guiadas, la demo, las aplicaciones de cada dispositivo y qué hacer cuando algo no funciona.

En este capítulo:
- [Un espacio tiene dos caras](help:user.advanced.environments) · [Entre en una cara](help:user.advanced.enter-environment) · [Un espacio de prueba](help:user.advanced.test-space) · [Quién puede desplegar](help:user.advanced.deploy-permissions) · [Despliegue entre las caras](help:user.advanced.deploy) · [Situación del espacio y archivo del ejercicio](help:user.advanced.status-archive)
- [Su propio servidor](help:user.advanced.own-server)
- [Asistentes](help:user.advanced.assistants) · [Conecte un asistente](help:user.advanced.assistants-connect) · [Aprobaciones](help:user.advanced.assistants-approve) · [Qué pueden hacer los asistentes](help:user.advanced.assistants-policy)
- [El grabador de tareas](help:user.advanced.recorder) · [Grabe una tarea](help:user.advanced.recorder-record) · [Revise una grabación](help:user.advanced.recorder-review) · [Cree una guía](help:user.advanced.guide-make) · [Siga una guía](help:user.advanced.guide-play) · [El menú circular](help:user.advanced.guide-circle) · [Edite una guía](help:user.advanced.guide-edit) · [Privacidad de las grabaciones](help:user.advanced.recorder-privacy)
- [El espacio de demostración](help:user.advanced.demo) · [Modo grabación](help:user.advanced.filming)
- [Plataformas](help:user.advanced.platforms) · [Detalles de soporte](help:user.advanced.support) · [Cuando algo no funciona](help:user.advanced.troubleshooting)
- [Las palabras de la aplicación](help:user.advanced.glossary) · [Accesibilidad y teclado](help:user.advanced.accessibility) · [Más ayuda](help:user.advanced.help)

<!-- anchor: user.advanced.environments -->
### Un espacio tiene dos caras

**Público:** Propietario

Quiere un lugar donde probar cosas sin tocar las reservas y facturas reales. Un espacio puede venir en pareja: una cara de pruebas y una cara real, con el mismo nombre.

<p><img src="images/user-advanced-environments.es.jpg" width="280"></p>

**Pasos**

1. Al crear un espacio, deje marcada la opción **Crear la pareja desarrollo y producción**. Ambas caras son suyas desde el primer segundo.
2. ¿Ya tiene un espacio suelto? Abra [Ajustes](app:/settings), vaya a **Gobernanza** y pulse **Crear su gemelo**. La configuración se copia una sola vez.
3. A partir de ahí, las dos caras son independientes. Solo un despliegue traslada algo de una a otra.

**Conviene saber**

- La cara de desarrollo se llama **Desarrollo — para probar**. La cara de producción es **Producción — las facturas se deben**.
- Todo documento impreso en la cara de desarrollo lleva una marca de agua, para que no pueda confundirse con uno real.
- **Crear su gemelo** solo aparece cuando la función **Pares de entornos** está activada, y solo para el propietario. El despliegue entre los lados corresponde a quienes tienen los permisos de despliegue.
- Los miembros, las reservas, las facturas y los pagos nunca se copian entre las caras.

**Véase también:** [Entre en una cara](help:user.advanced.enter-environment) · [Un espacio de prueba](help:user.advanced.test-space)

<!-- anchor: user.advanced.enter-environment -->
### Entre en la cara real o en la de pruebas

**Público:** Todos

Quiere abrir un espacio por la cara que necesita. Su cuenta ve las dos caras de una pareja, cada una con su propio botón.

**Pasos**

1. Abra [Yo](app:/me) y busque el espacio en **Mis espacios**.
2. Pulse **Abrir espacio** para la cara real, o **Espacio de prueba** para la cara donde practicar.
3. O abra [Perfiles](app:/profiles): la pareja es una sola tarjeta. Púlsela y después **Elegir un entorno** entre **DEV** y **PROD**.

**Conviene saber**

- Una cara a la que no puede entrar aparece atenuada y no hace nada.
- Quien es miembro de la cara real lo es siempre también de la cara de pruebas.
- El botón de pruebas lleva la indicación «Espacio de prueba: reservas y facturas de ensayo»; el real, «Reservas y facturas reales».

**Véase también:** [Quién puede desplegar](help:user.advanced.deploy-permissions)

<!-- anchor: user.advanced.test-space -->
### Para qué sirve un espacio de prueba

**Público:** Propietario

Está a punto de cambiar precios, reglas o el plano y quiere ver antes el efecto. Hágalo en el espacio de prueba.

**Pasos**

1. Entre en la cara de pruebas con **Espacio de prueba**.
2. Configure, importe un archivo de espacio, invite a un colega, emita una factura de ensayo, mueva puestos, imprima.
3. Cuando esté bien, [despliéguelo en la cara real](help:user.advanced.deploy).

**Conviene saber**

- El interruptor **Tipo de espacio** en [Ajustes](app:/settings) (bajo **Gobernanza**) indica de qué clase es un espacio. Solo lo ven los propietarios.
- Declarar un espacio de producción plantea **¿Declarar este espacio de producción?**: el banner desaparece y los documentos pierden su marca de agua. Las facturas ya emitidas conservan la marca de agua que tenían.
- Declare producción solo cuando las facturas que salen del espacio se deban realmente.
- Al invitar a alguien, puede elegir si también accede al espacio de producción: **Espacio de prueba** o **Espacio de producción**. En ambos casos se une al espacio de prueba.

**Véase también:** [Un espacio tiene dos caras](help:user.advanced.environments)

<!-- anchor: user.advanced.deploy-permissions -->
### Quién puede desplegar y entrar en producción

**Público:** Propietario · Copropietario

Usted decide quién puede tocar la cara real. Tres permisos de la matriz de roles lo controlan.

**Pasos**

1. Abra [Roles](app:/roles).
2. Busque **Entrar en el espacio de producción**, **Desplegar en desarrollo** y **Desplegar en producción**.
3. Active cada uno para los roles que lo necesiten.

**Conviene saber**

- Los propietarios y copropietarios tienen los tres. Los administradores tienen **Desplegar en desarrollo** y **Entrar en el espacio de producción**. Los miembros no tienen ninguno hasta que usted se lo conceda.
- Quien puede desplegar en producción puede desplegar siempre en desarrollo.
- Un rol solo entra en la cara de producción mientras tenga **Entrar en el espacio de producción**: en caso contrario se rechaza una invitación o una incorporación a producción, y la aplicación dice por qué.

**Véase también:** [La matriz de roles](help:user.roles.matrix) · [Despliegue entre las caras](help:user.advanced.deploy)

<!-- anchor: user.advanced.deploy -->
### Despliegue entre las dos caras

**Público:** Propietario · Copropietario · Administrador/a

Ha dejado lista la configuración en una cara y quiere que la otra la tenga.

**Pasos**

1. Colóquese en la cara en la que quiere escribir y abra [Ajustes](app:/settings) → **Gobernanza** → [Despliegue](app:/deployment).
2. Marque lo que debe viajar. Las entidades se agrupan en **Configuración**, **Datos maestros** e **Informes**; lo que una entidad **necesita** se marca con ella.
3. Pulse **Traer desde PROD…** (desde la cara de desarrollo) o **Traer desde DEV…** (desde la cara de producción).
4. Lea la vista previa: **Lo que cambia en el lado de producción**, o en el de desarrollo. Cuando ambas caras coinciden, dice **Sin cambios**.
5. Confirme. La pregunta nombra la cara en la que se escribe: **¿Desplegar en este DEV?** o **¿Desplegar en este PROD?**

**Conviene saber**

- Un despliegue entra siempre en la cara en la que usted está. No se puede empujar nada a la otra cara por error.
- Cada despliegue queda en el **Diario**. **Deshacer** en el último devuelve lo que la cara tenía antes.
- Los planos se fusionan: lo que solo tiene esta cara se conserva, porque un puesto puede tener una reserva. Las etiquetas de credencial nunca viajan.
- Los miembros, las reservas, las facturas, los pagos, los eventos y las credenciales nunca viajan.
- La entrada solo se muestra cuando la función **Despliegues** está activada, el espacio tiene gemelo y usted tiene un permiso de despliegue.

**Véase también:** [Quién puede desplegar](help:user.advanced.deploy-permissions)

<!-- anchor: user.advanced.status-archive -->
### Situación del espacio y archivo del ejercicio

**Público:** Propietario · Administrador/a · Administrador/a de facturación

Quiere ver de un vistazo lo que el espacio ha facturado y cobrado, y un archivo completo del año para sus registros.

**Pasos**

1. Abra [Situación del espacio](app:/money/status). Elija los meses en **Desde** y **Hasta**.
2. Lea **Facturado**, **Abonos**, **Pagos conciliados**, **Pagos recibidos**, **Gastos reembolsados**, **Gastos repartidos** y **Créditos concedidos**; **Neto** lo resume. Pulse la impresora para **Imprimir la situación**.
3. Para el archivo anual, elija **Archivo del ejercicio (zip)** en las exportaciones de facturas.

**Conviene saber**

- **Neto** no es un beneficio ni un saldo bancario. Los pagos conciliados y los recibidos se solapan, así que no los sume.
- La situación aparece cuando la función **Situación del espacio** está activada.
- Un espacio de desarrollo produce archivos marcados DEV: no son la contabilidad real.

**Véase también:** [Informe del espacio](help:user.workspace.export.workspace-report)

<!-- anchor: user.advanced.own-server -->
### Gestione su propio servidor

**Público:** Operador/a · Propietario

Quiere los datos de su comunidad en un servidor que usted controle, o pertenece a una organización que gestiona uno.

**Pasos**

1. Lea cómo se configura un servidor en [Cómo gestionar el suyo](help:user.backend.how).
2. En cada dispositivo, apunte la aplicación hacia él: [Su propio servidor](help:user.backend.server).
3. Compruebe en [Yo](app:/me) → **Dónde están mis espacios**: enumera los servidores que usa esta cuenta.

**Conviene saber**

- La aplicación apunta a un solo servidor para iniciar sesión; **Este dispositivo usa** indica cuál. Los demás servidores a los que pertenece aparecen en **Dónde están mis espacios**.
- Una invitación solo se comprueba en su propio servidor, así que únase a un espacio mientras la aplicación apunte al servidor que la emitió.
- Un operador puede activar los asistentes para toda la instalación; véase [Aprobaciones](help:user.advanced.assistants-approve).

**Véase también:** [Su propio servidor](help:user.backend.server)

<!-- anchor: user.advanced.assistants -->
### Asistentes: qué son

**Público:** Todos

Un asistente de IA como Claude o ChatGPT puede consultar y reservar cosas por usted en DesKilo. Actúa como usted, solo en los espacios y para las acciones que usted apruebe.

<p><img src="images/user-advanced-assistants-policy.es.jpg" width="280"></p>

**Pasos**

1. Abra [Asistentes](app:/assistants). **Su situación aquí** enumera lo que aún le falta: **Inicio de sesión con Google**, **Identidad para asistentes**, **Aprobación de la base de datos**, **Oferta del espacio de trabajo**, **Su rol**, **Su consentimiento**, **Servidor**.
2. Recorra la lista de arriba abajo; cada línea indica quién da el siguiente paso.

**Conviene saber**

- Participan varias personas: usted, el propietario o un administrador del espacio, un administrador de la base de datos y el operador de la instalación. Ninguna persona sola puede abrirlo todo.
- Activar los asistentes no concede nada a nadie por sí solo.
- Bajo **Asistentes conectados** ve lo que está conectado y puede **Desconectar** cada uno. **Su uso de asistentes hoy** cuenta **Solicitudes**, **Rechazadas**, **Aplicadas** y **Pendiente de validación**.

**Véase también:** [Conecte un asistente](help:user.advanced.assistants-connect)

<!-- anchor: user.advanced.assistants-connect -->
### Conecte un asistente

**Público:** Miembro · Administrador/a · Propietario

Quiere que su asistente trabaje con sus propias reservas y su cuenta.

**Pasos**

1. Abra [Conectar un asistente](app:/assistants/connect). Bajo **Antes de conectar**, cada línea debería decir **Hecho**.
2. Bajo **¿Qué asistente usa?**, elija **Claude**, **Claude Code**, **ChatGPT**, **Cursor**, **VS Code** u **Otro**. Copie **Su dirección de DesKilo para asistentes** en él como indican los pasos.
3. Inicie sesión cuando el asistente se lo pida y elija después este espacio y lo que el asistente puede hacer en él.
4. Pulse **Probar la conexión** y pregunte a su asistente: «Con DesKilo, ¿cuáles son mis reservas de esta semana?»

**Conviene saber**

- El propio asistente le pide que apruebe el espacio y cada tipo de operación; nada se elige por usted.
- Conectar requiere la función **Interfaz MCP** en el espacio. Si está desactivada, la pantalla le envía a Asistentes.
- ¿No funciona? **Probar la conexión** indica qué está esperando aún.
- **Desconectar** elimina el asistente de todos los espacios de esta base de datos. Lo que ya leyó no se recupera.

**Véase también:** [Aprobaciones](help:user.advanced.assistants-approve)

<!-- anchor: user.advanced.assistants-approve -->
### Aprobaciones y confirmaciones de los asistentes

**Público:** Propietario · Operador/a

Los asistentes se aprueban por capas, para que una persona no pueda activar uno por sí sola.

**Pasos**

1. El propietario del espacio (o quien gestione las integraciones) abre [Configuración de asistentes](app:/settings/assistant-setup) y la recorre: **Activar asistentes en este espacio de trabajo**, **Elegir qué pueden hacer los asistentes**.
2. Cada miembro lo pide una vez: **Solicitar aprobación**. Un administrador de la base de datos decide en [Aprobaciones de asistentes](app:/database/assistant-approvals) con **Aprobar** o **Rechazar**.
3. El operador de la instalación abre [Instalación: asistentes](app:/installation/assistants) y pulsa **Activar para todos los espacios**. La página enumera también los **Administradores de la base** y los **Clientes de asistente**, cada uno **Aprobado**, **Bloqueado** o **Pendiente de aprobación**.
4. Cuando un asistente envía una solicitud de gran impacto, se le pregunta: **Confirmar una solicitud del asistente**. **Confirmar** le permite enviar esa solicitud exacta una vez; **Rechazar** no hace nada.

**Conviene saber**

- Las aprobaciones y los cambios de la instalación requieren su segundo factor.
- La aprobación caduca; la pantalla le indica los días que quedan y usted vuelve a pedirla.
- Una solicitud confirmada sigue estando sujeta a las reglas de validación del espacio.
- Si no hay otro administrador de la base de datos, el operador aprueba el acceso, con un motivo, durante un máximo de 30 días.

**Véase también:** [Qué pueden hacer los asistentes](help:user.advanced.assistants-policy)

<!-- anchor: user.advanced.assistants-policy -->
### Qué pueden hacer los asistentes en un espacio

**Público:** Propietario · Administrador/a

Usted decide qué servicios ofrece un espacio a los asistentes.

**Pasos**

1. Abra [Acceso de asistentes](app:/settings/assistants).
2. Active **Ofrecer servicios de asistente**.
3. Bajo **Registros sobre los que puede actuar un asistente**, elija **Solo registros propios** o **Todo el espacio**.
4. Marque las operaciones, por grupos: **Reservas y cuenta propias**, **Solicitudes financieras**, **Solicitudes de membresía**, **Validaciones**.
5. Pulse **Guardar**.

**Conviene saber**

- Las operaciones se leen como «Ver plazas libres», «Reservar una plaza por usted», «Registrar su entrada» o «Cancelar sus reservas que aún no han empezado».
- Los asistentes reciben respuestas minimizadas. **Detalles opcionales** permite autorizar más; cada persona sigue eligiendo por sí misma.
- Los asistentes ya conectados solo reciben servicios nuevos cuando cada persona vuelve a aprobar.
- Active primero la función **Interfaz MCP** en [Funciones](app:/features). Viene desactivada por defecto.
- Es para quienes tienen el permiso de integraciones; los propietarios siempre lo tienen.

**Véase también:** [Un interruptor de función](help:user.features.switch)

<!-- anchor: user.advanced.recorder -->
### El grabador de tareas y las visitas guiadas

**Público:** Todos

Quiere mostrar a alguien cómo se hace una tarea, o que se lo muestren. Grabe la tarea una vez, conviértala en una guía y sígala paso a paso en la aplicación real.

<p><img src="images/user-advanced-wizard.es.jpg" width="280"></p>

**Pasos**

1. Abra el [Asistente de tareas](app:/task-wizard): en el menú en una pantalla ancha, o bajo **Avanzado** en [Yo](app:/me).
2. **Guías** contiene sus propias guías y las que vienen con la aplicación, como **Reservar un puesto**.
3. **Grabaciones** enumera las tareas que ha grabado, y **Grabar una tarea** inicia una nueva.
4. **Herramientas** abre un archivo de tarea sin necesidad de cuenta.

**Conviene saber**

- Todo permanece en su dispositivo hasta que lo exporte.
- El grabador de tareas es una función (**Grabador de tareas**). Cuando está desactivada, el asistente de tareas no aparece en los menús.
- Debe haber iniciado sesión para grabar o seguir una guía.

**Véase también:** [Grabe una tarea](help:user.advanced.recorder-record) · [Siga una guía](help:user.advanced.guide-play)

<!-- anchor: user.advanced.recorder-record -->
### Grabe una tarea

**Público:** Todos

Quiere capturar lo que hace, para que pueda convertirse en un documento o en una guía.

<p><img src="images/user-advanced-record.es.jpg" width="280"></p>

**Pasos**

1. En el [Grabador de tareas](app:/task-recorder), lea **Antes de grabar**.
2. Pulse **Empezar a grabar**.
3. Haga la tarea como de costumbre, en cualquier pantalla del espacio o de [Yo](app:/me).
4. Use la barra que muestra **Grabando** para **Pausar**, **Reanudar**, **Añadir una nota** o **Detener**.

**Conviene saber**

- Una grabación dura hasta 500 pasos o 30 minutos, y se borra del dispositivo a los 30 días. Un archivo que haya exportado queda donde lo guardó.
- Cada paso nombra la pantalla, la acción y lo que respondió la aplicación, como **Reservado** o **Rechazado**.
- El inicio de sesión, el pago, los mensajes y otras pantallas protegidas dejan solo una marca.
- Si cambia a otra cuenta o espacio, la grabación termina.

**Véase también:** [Privacidad de las grabaciones](help:user.advanced.recorder-privacy)

<!-- anchor: user.advanced.recorder-review -->
### Revise, edite y exporte una grabación

**Público:** Todos

Quiere comprobar lo que se capturó antes de compartirlo.

**Pasos**

1. En el [Asistente de tareas](app:/task-wizard), pulse una grabación en **Grabaciones**.
2. Lea los pasos. Pulse **Dejar fuera de la exportación** en cualquier paso que no desee; **Volver a incluir** lo recupera.
3. Mire **Lo que contendrá el archivo**.
4. Elija **Exportar un archivo**, **Exportar un paquete de tarea** o **Exportar como documento de Word**.

**Conviene saber**

- Dejar un paso fuera cambia solo la exportación. La grabación del dispositivo no cambia.
- Para leer un archivo de otra persona, use **Abrir un archivo de tarea** en el [Banco de trabajo de tareas](app:/task-workbench). No se sube nada y no hace falta cuenta.
- Un archivo dañado o creado por una versión más reciente se rechaza con un mensaje claro.
- **Borrar de este dispositivo** elimina la grabación; los archivos exportados no se tocan.

**Véase también:** [Cree una guía](help:user.advanced.guide-make)

<!-- anchor: user.advanced.guide-make -->
### Cree una guía a partir de una grabación

**Público:** Todos

Quiere que otras personas sigan una tarea que usted grabó.

**Pasos**

1. En el [Asistente de tareas](app:/task-wizard), pulse **Crear una guía** junto a una grabación. O elija **Añadir una guía** → **Desde una de mis grabaciones** o **Desde un archivo o paquete de tarea**.
2. Revise el borrador. Cada paso está escrito tal como lo verá el lector.
3. Póngale un nombre en **Nombre de la guía**.
4. Pulse **Añadir a mis guías**.

**Conviene saber**

- La guía se conserva en su dispositivo bajo **Guías**. Una guía se puede editar o eliminar: **Eliminar esta guía** no toca su grabación.
- Un paso que reserva espera la respuesta real. No se hace nada por el lector.
- **Guardar la guía** la escribe en un archivo que puede entregar.

**Véase también:** [Edite una guía](help:user.advanced.guide-edit)

<!-- anchor: user.advanced.guide-play -->
### Siga una guía

**Público:** Todos

Quiere que le acompañen en una tarea sobre las pantallas reales.

**Pasos**

1. En el [Asistente de tareas](app:/task-wizard), pulse **Iniciar la guía** junto a una de las guías.
2. Un panel muestra Paso 1 de … y lo que hay que hacer, por ejemplo «Toque “Reservar”.» o «Rellene “…” y salga del campo.»
3. Pulse **Abrir y resaltar** para ir a la pantalla correcta y ver el control marcado.
4. Haga usted mismo el paso. La guía lo detecta y avanza. En un paso de lectura, pulse **Hecho**.

**Conviene saber**

- Use **Atrás** y **Omitir**, y abra **Todos los pasos** para ver cada uno como **Pendiente**, **Esperando**, **Hecho**, **Confirmado** u **Omitido**.
- Un paso que reserva espera la respuesta: **Esperando el resultado…**. Si se rechaza, la guía dice qué probar; si no llegó respuesta, le pide que lo compruebe antes de volver a intentarlo.
- **Detener la guía** la termina. No se deshace nada.
- La guía se pausa cuando cambia la cuenta o el espacio, o cuando se desactiva el grabador de tareas.

**Véase también:** [El menú circular](help:user.advanced.guide-circle)

<!-- anchor: user.advanced.guide-circle -->
### El menú circular

**Público:** Todos

Necesita toda la pantalla para trabajar, pero quiere tener la guía a mano. Minimícela.

**Pasos**

1. En el panel de la guía, pulse **Minimizar la guía**. Se reduce a un pequeño círculo.
2. Pulse el círculo para ver un menú: Mostrar la guía (paso … de …), **Abrir y resaltar**, un botón a la página del paso, **Hecho**, **Omitir**, **Atrás**, **Reanudar** y **Detener la guía**.
3. Elija Mostrar la guía para abrir de nuevo el panel.

**Conviene saber**

- El menú solo ofrece lo que tiene sentido ahora: **Reanudar** solo en pausa, **Hecho** solo en un paso de lectura.
- **Cerrar** en el panel lo oculta; la guía en sí se queda donde estaba.
- Abrir y resaltar le lleva a la página del paso y señala el control; el botón de página le lleva solo a la página.

**Véase también:** [Siga una guía](help:user.advanced.guide-play)

<!-- anchor: user.advanced.guide-edit -->
### Edite o repare una guía

**Público:** Todos

Una guía se lee mal, o un paso apunta a la página equivocada. Corríjalo en el borrador.

**Pasos**

1. En el [Asistente de tareas](app:/task-wizard), pulse **Editar** junto a su guía.
2. En un paso, pulse **Escribir el texto** y escriba su propio texto.
3. Bajo **Destino del paso**, elija la página a la que se refiere el paso. Pulse **Abrir y resaltar** para comprobarlo.
4. Active **El lector puede omitirlo** en un paso opcional.
5. Pulse **Guardar los cambios**.

**Conviene saber**

- Un paso marcado como **Una instrucción aún por escribir** necesita sus palabras. **Un paso que el grabador no puede describir** y **Haga este paso usted mismo** los hace el lector.
- Los pasos en pantallas protegidas, como el pago, piden al lector que los haga a solas.
- No puede hacer que una guía espere un resultado que su acción no tiene; esa parte es fija.
- Una guía que nombra pasos que esta versión no conoce se puede leer, pero no seguir.

**Véase también:** [Cree una guía](help:user.advanced.guide-make)

<!-- anchor: user.advanced.recorder-privacy -->
### Qué conserva una grabación

**Público:** Todos

Quiere saber exactamente qué no deja rastro.

**Pasos**

1. Abra el [Grabador de tareas](app:/task-recorder).
2. Lea **Antes de grabar**.
3. Deje desactivado **Capturar valores (para informes de problemas)** salvo que se lo pida un desarrollador.

**Conviene saber**

- Normalmente una grabación nunca conserva lo que escribe, los nombres, los importes, los mensajes, los códigos ni las contraseñas.
- Con **Capturar valores** activado, conserva también lo que escribe y elige, para que un desarrollador pueda reproducir un problema. Las contraseñas, los datos de pago, las direcciones de correo y los números de teléfono siguen sin conservarse nunca. Al exportarla se le pregunta **Esta grabación contiene valores**.
- No se sube nada: usted decide qué exportar.
- Comparta un archivo solo con las personas que deban ver lo que usted introdujo.

**Véase también:** [Grabe una tarea](help:user.advanced.recorder-record)

<!-- anchor: user.advanced.demo -->
### El espacio de demostración

**Público:** Todos

Quiere echar un vistazo antes de comprometerse. La demo es un espacio inventado, abierto a cualquiera, sin cuenta.

**Pasos**

1. En la pantalla de inicio de sesión, pulse **Explorar el espacio de demostración**.
2. Lea la breve nota y pulse **Empezar**.
3. Use **Ver como** para ver el mismo espacio como **La propietaria**, **Una administradora** o **Un miembro**.
4. Pulse **Reiniciar la demo** para devolverla a como empezó, o **Salir de la demo**.

**Conviene saber**

- Todo es inventado: las personas, las reservas y las facturas. Nada llega a un espacio real y nada sale de su dispositivo.
- Un banner dice **Demo** en cada pantalla.
- Al cerrar la aplicación se olvida la sesión.
- La oferta solo se muestra cuando la función **El espacio de demostración** está activada.

**Véase también:** [Modo grabación](help:user.advanced.filming)

<!-- anchor: user.advanced.filming -->
### Modo grabación

**Público:** Propietario

Debe mostrar su espacio real —en un vídeo, una imagen o una charla— sin mostrar a sus miembros.

**Pasos**

1. Abra [Funciones](app:/features) y busque **Modo grabación**.
2. Actívelo. Un banner dice **Modo grabación — personas inventadas** en cada pantalla.
3. Grabe. Cuando termine, desactívelo de nuevo.

**Conviene saber**

- Cada nombre, correo, teléfono, dirección y fotografía se convierte en una persona inventada, la misma en todas partes. El plano, las reservas y las cifras siguen siendo reales.
- Mientras está activado, los formularios de identidad se niegan a guardar, para que los datos inventados no sobrescriban los reales.
- No puede ocultar lo que alguien haya escrito, como un mensaje o la etiqueta de un puesto. Lea la pantalla antes de grabar.
- Para una imagen que no necesita ser de este espacio, use [la demo](help:user.advanced.demo).

**Véase también:** [Un interruptor de función](help:user.features.switch)

<!-- anchor: user.advanced.platforms -->
### DesKilo en sus dispositivos

**Público:** Todos

Quiere usar DesKilo allí donde trabaja. La misma cuenta y los mismos datos le siguen.

**Pasos**

1. **Android:** únase a la prueba cerrada en Google Play.
2. iPhone y iPad: únase a la beta mediante TestFlight.
3. Ordenador: una imagen de disco para macOS o un instalador para Windows desde la página de versiones; o simplemente abra la aplicación web.
4. **Navegador:** abra la dirección que publica su espacio. No hay nada que instalar.

**Conviene saber**

- Un puesto reservado en un teléfono aparece en una pestaña del navegador un momento después.
- La imagen de disco para macOS de la página de versiones está firmada y notarizada por Apple; ábrala con normalidad.
- El instalador de Windows no está firmado: Windows SmartScreen avisa de un editor desconocido; elija Más información y luego Ejecutar de todas formas.
- La lectura de una etiqueta de silla funciona en navegadores Chromium en Android (hacen falta HTTPS y un toque); las aplicaciones de Android y de iPhone leen las etiquetas directamente.
- Una compilación sin servicios de Google y sin notificaciones push en la nube está preparada para F-Droid; si ya puede instalarse desde F-Droid lo indica la [página de estado de F-Droid](https://github.com/fdittgen-png/deskilo/blob/master/docs/guides/fdroid.md#status). En ella, las notificaciones son locales y la bandeja de entrada es la fuente de verdad.
- Las actualizaciones llegan por el canal desde el que instaló: Google Play, TestFlight, la página de versiones o recargando la aplicación web.

**Véase también:** [Su credencial](help:user.profile.settings.badge)

<!-- anchor: user.advanced.support -->
### Detalles de soporte

**Público:** Todos

Se pone en contacto con soporte y quiere enviar lo que les ayuda, sin exponer nada privado.

<p><img src="images/user-advanced-support.es.jpg" width="280"></p>

**Pasos**

1. Abra [Ayuda](app:/help) y pulse el icono de soporte (**Detalles de soporte**).
2. Elija **Última hora** o **Últimas 24 horas**.
3. Pulse **Preparar vista previa** y lea lo que contiene: Vista previa: … bytes.
4. Pulse **Guardar** y envíe el archivo.

**Conviene saber**

- Solo se incluyen recuentos de eventos acotados y comprobaciones conocidas. Se excluyen las identidades, las direcciones de servidor, las credenciales, los registros de negocio y los logs en bruto.
- Un archivo compartido no se puede revocar.
- Si el contexto ha cambiado, la pantalla le pide preparar una nueva vista previa.
- Un operador puede ejecutar `doctor --support-json` para la parte del servidor.

**Véase también:** [Cuando algo no funciona](help:user.advanced.troubleshooting)

<!-- anchor: user.advanced.troubleshooting -->
### Cuando algo no funciona

**Público:** Todos

Algo parece ir mal. Pruebe esto, por orden.

**Pasos**

1. Busque un mensaje en la pantalla; la mayoría dice qué hacer. «Algo salió mal. Inténtalo de nuevo.» merece un reintento.
2. Compruebe que está en la cara que cree: **Espacio de prueba** o **Abrir espacio** en [Yo](app:/me).
3. Compruebe [Funciones](app:/features): una función que falta en el menú suele ser una función desactivada. Solo un propietario puede cambiarla.
4. Compruebe el servidor en [Su propio servidor](help:user.backend.server): **Este dispositivo usa** lo nombra.
5. Prepare los [Detalles de soporte](help:user.advanced.support) y envíelos.

**Conviene saber**

- Lo que ve depende de su rol: una pantalla ausente puede ser un permiso. Pregunte a su propietario.
- Los administradores pueden activar el **Modo desarrollador** bajo **Avanzado** en [Ajustes](app:/settings). Añade una pantalla de [Desarrollador](app:/developer) donde **Exportar registro** y **Vaciar registro** ayudan a soporte. Se aplica a todos los miembros del espacio.
- También puede informar de un error desde la sección Acerca de de la aplicación: **Informar de un error / sugerir una función**.
- Una guía atascada en **Esperando el resultado…** significa que no llegó respuesta: compruebe el resultado antes de volver a intentarlo.

**Véase también:** [Detalles de soporte](help:user.advanced.support)

<!-- anchor: user.advanced.glossary -->
### Las palabras de la aplicación

**Público:** Todos

Las palabras que más se encuentra y qué significan aquí.

| Palabra | Qué significa |
|---|---|
| **Espacio de trabajo** (también llamado espacio) | Un lugar gestionado por una comunidad: su plano, sus miembros, sus reglas y su dinero. Puede pertenecer a varios. |
| **Yo** | Su propia cuenta: perfil, mensajes, espacios y ajustes, en todos sus espacios. |
| **Plano** | O bien el plano de planta desde el que reserva, o bien un plan de membresía; véase **Miembros y planes**. |
| **Planta** | Un piso o zona del plano. Una planta se puede reservar entera cuando la función está activada. |
| **Mesa** | Un puesto reservable. Las oficinas y las salas agrupan mesas. |
| **Media jornada** | La unidad en la que se cuentan las reservas y las suscripciones. |
| **Validación** | Una regla que dice que una acción necesita una o más confirmaciones antes de contar. |
| **Eventos** | El flujo de lo ocurrido, con las decisiones que le esperan arriba. |
| **Quiosco** | Una tableta compartida en la puerta donde las personas registran su entrada con una credencial. |
| **Función** | Una funcionalidad que el propietario activa o desactiva para todo el espacio. |
| **Rol** | Lo que una persona puede hacer en un espacio. Los permisos se definen por rol. |
| **Entorno** | La cara de desarrollo (pruebas) o la de producción (real) de un espacio. |
| **Gemelo** | La otra cara de una pareja. |
| **Despliegue** | Trasladar la configuración de una cara de una pareja a la otra. |
| **Asistente** | Una herramienta de IA conectada a su cuenta, que actúa solo como usted permita. |
| **Operador** | La persona que gestiona la instalación con la que habla la aplicación. |

**Conviene saber**

- Los propietarios pueden cambiar las palabras que usa un espacio en **Vocabulario**; la aplicación muestra entonces las del propio espacio.

**Véase también:** [Vocabulario](help:user.workspace.settings.wording)

<!-- anchor: user.advanced.accessibility -->
### Accesibilidad y teclado

**Público:** Todos

Quiere que la aplicación se adapte a su forma de trabajar.

**Pasos**

1. Elija un aspecto en [Ajustes](app:/settings): **Tema**, **Idioma**, **Números y fechas**.
2. Para pantallas más tranquilas, active el ajuste de movimiento reducido de su dispositivo.
3. En un ordenador, pulse Escape en un asistente para retroceder.

**Conviene saber**

- El ajuste de movimiento reducido del dispositivo siempre prevalece sobre la función **Animaciones de la interfaz**; un propietario también puede desactivar esa función.
- Salir de un asistente con cambios sin guardar pregunta antes: **Seguir editando** o **Descartar**.
- Los controles llevan etiquetas de texto, de modo que un lector de pantalla los anuncia.
- En la web y en un ordenador, una ventana ancha muestra el menú junto al contenido.

**Véase también:** [Tema](help:user.profile.settings.theme) · [Idioma de la aplicación](help:user.profile.settings.language)

<!-- anchor: user.advanced.help -->
### Dónde obtener más ayuda

**Público:** Todos

Se ha atascado en un campo o en una pantalla.

**Pasos**

1. Pulse el **?** junto a un campo: la guía se abre en ese campo.
2. Abra [Ayuda](app:/help) para toda la guía; **Índice** salta a un capítulo.
3. Los consejos de una pantalla se pueden descartar con **Ocultar consejo**; **Consejo siguiente** y **Consejo anterior** los recorren, y **Más información** abre la guía.
4. Para volver a ver los consejos descartados, use **Volver a mostrar los consejos de ayuda** en sus ajustes.

**Conviene saber**

- La guía funciona sin conexión, en su idioma.
- Su administrador puede responder preguntas sobre su espacio; los Detalles de soporte ayudan cuando se trata de la aplicación.

**Véase también:** [Restaurar los consejos](help:user.profile.settings.restore-hints) · [Detalles de soporte](help:user.advanced.support)
