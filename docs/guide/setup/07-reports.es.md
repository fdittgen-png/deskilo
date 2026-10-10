<!-- anchor: setup.reports.overview -->
## Documentos e informes

**Público:** Propietario · Copropietario · Administrador/a de facturación

Todo lo que DesKilo imprime o exporta sale de un único motor y de un único lugar de diseño. Este capítulo le dice qué documentos existen, en qué orden prepararlos, qué puede entregar a su gestor y dónde puede ayudarle un asistente de IA y dónde no debe hacerlo. Los clics están en la guía de usuario; aquí encontrará las razones y el orden.

El ejemplo que seguimos es el espacio de demostración *Atelier du Marché*.

<!-- anchor: setup.reports.documents -->
### Los documentos que produce la aplicación

**Público:** Propietario · Administrador/a de facturación

Quiere saber qué existe antes de diseñar nada y quién recibe cada documento.

<p><img src="images/setup-reports-hub.es.jpg" width="280"></p>

Cada documento es de un *tipo*. Cada tipo tiene su propio diseño, de modo que cambiar la factura nunca cambia el extracto.

| Documento | Quién lo recibe | Dónde se encuentra |
|---|---|---|
| Factura y factura rectificativa (un diseño compartido) | El miembro, o el cliente de un mes facturado | [Facturación](help:user.invoicing.hub) |
| Proforma | Un miembro que necesita un presupuesto o una solicitud de pago anticipado | La misma pantalla |
| Extracto | El miembro (su cuenta durante un periodo) | [El extracto](help:user.money.statement) |
| Acuerdo | El miembro (las condiciones negociadas) | [Negociación de precios](help:user.money.negotiation) |
| Pagos, uso | El miembro, el administrador de facturación | [Pagos](help:user.money.payments) · [Uso](help:user.money.usage) |
| Cartas de recordatorio, nivel 1 a 9 | El miembro con una factura vencida | [Reglas de recordatorio](help:user.money.reminders.rules) |
| Informe del espacio y estado del espacio | Usted, la junta, un auditor | **Informes** |
| Declaración de IVA | Usted, y después la plataforma tributaria | [La declaración periódica de IVA](help:user.money.vat.declaration) |
| Credenciales, códigos QR de espacios | Los miembros en la puerta, sus paredes | [Códigos QR de espacios](help:user.workspace.export.space-qr) · [Credenciales](help:user.badges.nfc) |

**Conviene saber**

- La pantalla **Informes** los agrupa en **Informes financieros**, **Documentos del espacio**, **Análisis de actividad** y **Plantillas**, según sus permisos.
- Unos pocos informes (plan contable, credenciales, tarjetas QR) tienen un único diseño incluido. Los demás se pueden rediseñar.
- Los documentos sacados de un espacio de prueba llevan una marca de agua que lo indica. Véase [Para qué sirve un espacio de prueba](help:user.advanced.test-space).

**Véase también:** [Informes](help:user.money.reports) · [La plantilla PDF de factura](help:user.money.reports.invoice-template)

<!-- anchor: setup.reports.designer -->
### El diseñador, en lenguaje de propietario

**Público:** Propietario · Administrador/a de facturación

Quiere una carta que se parezca a la suya sin aprender un lenguaje de marcado.

<p><img src="images/setup-reports-professional.es.jpg" width="280"></p>

Un documento es una página hecha de **bandas**. La *cabecera* lleva su membrete y el destinatario. El *cuerpo* lleva las líneas. La franja de *continuación* empieza en la segunda página, y el *pie* se repite en cada página con sus condiciones de pago y sus menciones legales. Las edita en **Diseño** y las comprueba en **Vista previa**; **Marcado** muestra las mismas bandas como texto para el día en que lo necesite.

| Pieza | Qué le da | Elíjala cuando |
|---|---|---|
| Ajustes preestablecidos (**Profesional**, **Clásico**, **Sencillo**, **Detallado**, **Carta formal**) | Un diseño terminado para empezar. Los ajustes difieren para facturas, proformas, extractos, acuerdos y recordatorios; los documentos estructurales tienen un único diseño incluido | Siempre: empiece por **Profesional** y cambie poco |
| Un diseño por idioma | Un miembro lee el documento en su propio idioma | Sus miembros no leen todos el mismo idioma |
| Membrete y sobre con ventana | Remitente, destinatario y cuerpo colocados donde los espera un sobre con ventana | Envía las facturas por correo postal |
| Diseño posicionado (XML) | Cada elemento colocado en milímetros, para un formulario oficial | Un documento debe ajustarse a un formulario fijo |
| Biblioteca de imágenes | Un logotipo, un sello o una firma que se reutiliza en varios diseños | Tiene un logotipo |
| Intercambio de diseños | Un diseño escrito en un archivo y leído de nuevo | Una persona o una herramienta ajena a la aplicación lo edita |

Dos datos le evitan sorpresas. La norma de la carta imprime el destinatario en la ventana de la derecha para un espacio francés y en la de la izquierda para uno alemán, salvo que usted lo modifique. Y un diseño que no se consigue generar nunca bloquea un documento: entra en su lugar el diseño incorporado.

> **Atención** El texto de un diseño no es asesoramiento jurídico. El aspecto y la traducción por sí solos no establecen el cumplimiento legal ni satisfacen una obligación de facturación electrónica. Lo que debe decir una factura se decide en [Su identidad legal](help:user.money.legal.identity) y lo confirma su gestor.

**Véase también:** [El editor de informes](help:user.money.reports.editor) · [Plantillas listas para usar](help:user.money.reports.presets) · [Un diseño por idioma](help:user.money.reports.languages)

<!-- anchor: setup.reports.sequence -->
### La secuencia que debe seguir

**Público:** Propietario · Administrador/a de facturación

Va a diseñar documentos y quiere hacerlo una sola vez, en el orden correcto.

<p><img src="images/setup-reports-presets.es.jpg" width="280"></p>

**Pasos**

1. Fije primero su identidad legal: tipo de organización, dirección, registro, régimen de IVA y menciones especiales. Un diseño imprime solo lo que usted introdujo ahí. Véase [Su identidad legal](help:user.money.legal.identity).
2. Abra el [Editor de informes](app:/report-editor), elija el documento y empiece por **Profesional** en **Plantillas**.
3. Añada una versión de idioma para cada idioma que lean sus miembros. Elija **EN**, **FR**, **DE**, **ES** o **IT** bajo el documento. Véase [Un diseño por idioma](help:user.money.reports.languages).
4. Compruebe cada uno con **Vista rápida**. Usa su factura más reciente o, si no hay ninguna, datos de ejemplo.
5. Ensaye en un espacio de prueba: entre en él, emita una factura de prueba, imprímala y envíela a su gestor. Véase [Para qué sirve un espacio de prueba](help:user.advanced.test-space).
6. Congele el diseño antes de la primera factura. Anote lo que decidió y cambie un diseño solo cuando cambie una norma.

**Conviene saber**

- Sustituir un diseño se puede deshacer con **Deshacer** hasta que salga del editor.
- Una factura emitida es un documento congelado. Cambiar el diseño más adelante cambia los documentos nuevos, nunca los ya emitidos.
- Con el mismo texto en dos idiomas, pida a alguien que lea el segundo idioma que revise la vista previa.

> **Atención** El número de factura y las menciones legales impresas en una factura pasan a ser permanentes con la primera factura emitida. Defínalos antes, no después.

**Resultado:** todos los documentos que envíe se parecen a los suyos, en cada idioma, y han sido leídos una vez por alguien que no es usted.

**Véase también:** [Su identidad legal](help:user.money.legal.identity) · [La plantilla PDF de factura](help:user.money.reports.invoice-template)

<!-- anchor: setup.reports.accountant -->
### Qué entregar a su gestor

**Público:** Propietario · Administrador/a de facturación

Quiere que su gestor tenga lo que necesita y sepa lo que la aplicación no afirma.

<p><img src="images/setup-reports-export.es.jpg" width="280"></p>

Empiece por el [Registro de facturas](app:/invoice-register), que enumera todas las facturas con su estado, y pulse **Exportación contable**. Cada formato indica en su hoja lo que afirma.

| Archivo | Qué afirma | Qué no afirma |
|---|---|---|
| FEC | El formato francés que pide una inspección, reconstruido a partir de facturas y pagos | Una contabilidad completa. Su gestor la completa |
| DATEV | Un archivo de intercambio para el programa de los contables alemanes, que lee y contabiliza una persona | Una presentación, ni una entrega para una inspección fiscal |
| SAF-T | La estructura internacional, deliberadamente parcial: facturas y pagos, sin libro mayor | Un archivo contable completo. Lo dice en su cabecera |
| SAF-T PT, Sage 50 | Un formato regulatorio portugués (no certificado) y un formato de intercambio británico/irlandés, según su país | Una presentación ni una certificación |
| CSV contable, Pista de auditoría, Archivo del año (zip) | Una ayuda de lectura para su gestor | Una presentación |

La lista de formatos depende de su país. FEC y DATEV piden sus números de cuenta, y FEC también su número de registro: téngalos a mano. Las cifras de IVA del periodo están en [La declaración periódica de IVA](help:user.money.vat.declaration).

*Lo que la aplicación no hace*

- Conserva facturas, pagos y una cuenta corriente por miembro. No lleva un libro mayor por partida doble sobre un plan contable, así que no puede sustituir a un programa de contabilidad.
- Algunas obligaciones siguen siendo suyas y de su gestor: la contabilidad completa, un programa certificado cuando su país lo exige y la aceptación por parte de la autoridad de destino.
- Un archivo queda bloqueado hasta que se corrigen los problemas de origen.

**Conviene saber**

- Exportar es una lectura. Puede repetirla para cualquier periodo.
- Prepare un breve informe para su gestor antes de la primera factura: su régimen de IVA, cuándo se devenga el IVA, la numeración elegida y las exportaciones que querrá. Véase [Ayuda de IA](help:setup.reports.ai).

**Véase también:** [Exportaciones contables](help:user.invoicing.accounting-export) · [El registro de facturas](help:user.invoicing.register) · [Cuenta de IVA](help:user.money.vat.account)

<!-- anchor: setup.reports.analytics -->
### El análisis de actividad a grandes rasgos

**Público:** Propietario · Administrador/a de facturación

Quiere ver cómo rinde el espacio cuando ya funciona, sin una hoja de cálculo.

<p><img src="images/setup-reports-documents.es.jpg" width="280"></p>

**Análisis de actividad** muestra cifras por ámbito: facturado y cobrado, ocupación y capacidad. Usted elige un periodo (mes, trimestre o año), lo compara con otro, guarda una vista y la exporta como PDF. Solo ve los análisis que su rol puede leer.

Lo cobrado son los pagos conciliados con facturas. No es un beneficio, porque la cifra no incluye costes, y el periodo en curso es parcial.

Para un documento sobre todo el espacio, la pestaña **Documentos del espacio** contiene el **Informe del espacio**, **Códigos QR de espacios (PDF)**, **Exportar datos (Excel)** y **Exportar configuración (PDF)**. Use los dos últimos como copia de recuperación antes de un cambio importante.

**Véase también:** [Análisis de actividad](help:user.invoicing.bi) · [Exportaciones](help:user.workspace.export.workspace-report)

<!-- anchor: setup.reports.ai -->
### Ayuda de un asistente de IA

**Público:** Propietario · Copropietario

Una herramienta de chat con IA puede ahorrarle horas con las palabras que rodean su configuración. No puede ser quien decida lo que es correcto en lo legal o lo fiscal. Esta sección trata de las herramientas que usa fuera de DesKilo; la conexión de asistentes dentro de la aplicación se describe al final.

*Para qué sirve una herramienta externa*

- Redactar el mensaje de invitación que envía a sus primeros miembros. Véase [El mensaje de invitación](help:user.workspace.settings.invitation-message). Los marcadores, como el nombre o el enlace de invitación, se dejan tal cual.
- Formular las menciones especiales que presentará a su gestor, como borrador para revisar, nunca como texto definitivo.
- Traducir el texto de un diseño a otro idioma, de modo que solo tenga que revisarlo.
- Explicar un informe o un extracto a un miembro con palabras sencillas.
- Preparar el resumen de sus decisiones para su gestor: país, tipo de organización, régimen de IVA, numeración, exportaciones.
- Esbozar la imagen de fondo de su plano, a partir de fotografías, en una herramienta de imágenes.

*Lo que no debe decidir*

- Las menciones legales de una factura, el tratamiento del IVA de una actividad, el motivo por el que no se cobra IVA y los tipos de IVA.
- Todo lo que pasa a ser permanente: un formato de numeración de facturas, un régimen de IVA, la moneda, una factura emitida.
- Si algo cumple la normativa. Una respuesta segura de sí misma no es una respuesta verificada; quien verifica es su gestor.

*El flujo de trabajo seguro*

1. Pida a la herramienta un borrador. Dele un escenario, no los nombres de sus miembros ni ningún dato personal.
2. Pegue el borrador en el campo, en el **Editor de informes** o en los ajustes.
3. Revíselo en **Vista previa** con datos de ejemplo.
4. Envíe a su gestor el texto con peso legal y espere su respuesta.
5. Pruebe todo el flujo en un espacio de prueba antes de hacerlo en el real.

> **Atención** No pegue un token, una contraseña, un número bancario ni datos personales de un miembro en una herramienta externa.

*La conexión de asistentes propia de DesKilo*

La aplicación permite que un asistente como Claude o ChatGPT actúe en nombre de un miembro mediante un protocolo llamado MCP. Viene desactivada y es una función que usted activa (**Interfaz MCP**, véase [Un interruptor de función](help:user.features.switch)). Está construida por capas, de modo que ninguna persona puede abrirlo todo.

<p><img src="images/setup-reports-assistants.es.jpg" width="280"></p>

| Capa | Quién | Qué hace |
|---|---|---|
| La instalación | El operador | Activa los asistentes para la instalación. |
| El espacio | Usted, el propietario | Activa la función y elige después en [Qué pueden hacer los asistentes](help:user.advanced.assistants-policy) qué servicios se ofrecen y si un asistente ve solo los registros propios o los de todo el espacio. |
| La base de datos | Un administrador de la base de datos | Aprueba la solicitud de cada persona. |
| El miembro | Cada miembro | Pide la aprobación una vez y elige este espacio. |
| Una solicitud con efectos | El miembro, en su dispositivo | Confirma la solicitud exacta, que además sigue sus reglas de validación. |

El asistente de un miembro trabaja sobre los registros de ese miembro: encontrar y describir puestos libres, favoritos y valoraciones, reservar, modificar o cancelar su propia reserva, pedir que se borre una reserva ya iniciada, registrar la entrada y la salida, leer su extracto y sus facturas, y enumerar y responder las validaciones que se le piden. Unas pocas solicitudes (emisión de factura, anulación de factura, reembolso, cambio de estado de un miembro, parte de la suscripción) son solo para el personal: exigen derechos de personal, la confirmación de la persona en la aplicación y, después, sus reglas de validación. No tiene ninguna operación que configure un espacio: no puede activar una función, fijar una tarifa, cambiar un rol ni construir un plano. No puede configurar su espacio por usted, y actúa únicamente dentro de lo que usted expone.

**Conviene saber**

- Activar los asistentes no concede nada a nadie por sí solo.
- Cada aprobación caduca; la pantalla indica cuántos días quedan.
- Lea los pasos en [Aprobaciones y confirmaciones para asistentes](help:user.advanced.assistants-approve).

**Véase también:** [Asistentes: qué son](help:user.advanced.assistants) · [Conectar un asistente](help:user.advanced.assistants-connect)

<!-- anchor: setup.reports.developer -->
### Trabajar con un desarrollador: el archivo de diseño y la herramienta de informes

**Público:** Propietario · Operador/a

Una persona técnica le ayuda y hay que editar o comprobar un diseño fuera de la aplicación.

**Pasos**

1. En el [Editor de informes](app:/report-editor), use **Exportar este diseño** para escribir el diseño en un único archivo. El archivo explica qué significan sus campos y qué marcadores existen. **Importar un diseño** lo vuelve a leer; un archivo de otro informe, o de una versión más reciente, se rechaza indicando el motivo.
2. Un desarrollador puede comprobar el diseño desde un terminal con la herramienta de informes, descrita en la guía del administrador técnico: `check` mide un diseño frente al contrato del sobre con ventana y termina con un código distinto de cero cuando hay tinta en la ventana; `render` genera el PDF; `sample` escribe un archivo de datos con todos los marcadores; `describe` enumera el vocabulario.
3. De vuelta en la aplicación, importe el archivo, véalo con **Vista rápida** y pulse **Guardar**.

**Conviene saber**

- El intercambio de diseños es una función (**Exportar e importar diseños de informe**), entre las funciones de informes de [Funciones](app:/features). Actívela primero.
- La herramienta necesita el código fuente de la aplicación; es para la persona que gestiona su instalación, no para el uso diario.

**Véase también:** [El editor de informes](help:user.money.reports.editor) · [La plantilla PDF de factura](help:user.money.reports.invoice-template)
