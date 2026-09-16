# Guía del administrador — configurar el espacio

Para quien pone el espacio en marcha: qué decide cada parámetro, en el
orden en que el cuestionario los pregunta, después los datos maestros y
después el plano y sus imágenes. La parte técnica está en la
[guía técnica](Admin-Technical-Guide.es); mover una
configuración de un espacio de desarrollo a uno de producción está en la
[guía de entornos](Environments-Guide.es).

<!-- anchor: config.setup.questionnaire -->
## El cuestionario de instalación

El cuestionario web pregunta, en orden, solo lo que sus respuestas
anteriores hacen posible, y produce el archivo de espacio que la app
importa. Cada pregunta que aparece allí existe como parámetro en la app,
y cada parámetro de la app aparece allí — esa simetría es una regla, no
una casualidad.

<!-- image: config-setup-questionnaire -->

<!-- anchor: config.identity.legal -->
## Identidad y menciones legales

*Ajustes del espacio → Identidad legal y facturación electrónica.*
Rellene esto antes de que el primer documento salga de la casa: una
factura que no nombra correctamente a quien la emite no es una factura.

El **tipo de organización** — empresa o asociación — decide qué cláusulas
se imprimen por defecto. El interés de demora, la indemnización por
recobro y el descuento por pronto pago son obligaciones *entre
profesionales*: los documentos de una asociación prescinden de esas
menciones por defecto y siguen imprimiendo lo que usted escriba.

Después, en orden: la **forma jurídica y el capital** impresos bajo el
nombre; el **registro** donde un lector puede comprobarle (Registro
Mercantil y ciudad para una empresa, registro de asociaciones para una
asociación); el **régimen de IVA**, que decide si la norma espera de
usted un número de IVA o un número de registro; la **dirección
estructurada**, que es lo que lleva una factura electrónica porque una
máquina no sabe partir con fiabilidad una dirección de una sola línea; y
las ocho menciones de factura.

Cada uno de esos campos está documentado, campo por campo, en la
[guía de usuario](Guia-de-usuario), § 11a — el símbolo de ayuda que hay
al lado abre exactamente su párrafo.

Las **instrucciones de pago** (el bloque bancario que imprime un
documento) son una entidad aparte, así que se despliegan solas entre un
espacio de desarrollo y uno de producción.

<!-- anchor: config.vat.overview -->
## IVA

El tipo que lleva una prestación lo deciden tres cosas, nunca una sola:
qué es (**el grupo**), quién la compra (**el tratamiento**) y cuándo
ocurrió (**el devengo**). Esa es la forma ERP, y es la razón por la que
un cambio de tipo nunca reescribe un documento antiguo.

Los **tipos** llevan un nombre, un porcentaje y un grupo fiscal, y uno es
el predeterminado. Un tipo está **versionado por fecha**: pasar del 21 %
al 22 % añade una versión válida desde una fecha, no modifica la
anterior. Todo documento ya emitido conserva la versión que estaba en
vigor cuando se emitió, congelada en el propio documento; solo las
prestaciones con fecha igual o posterior al inicio de la nueva versión la
usan.

Los **grupos** son lo que una prestación *es* — general, reducido, tipo
cero, exento, no sujeto. Un servicio, una cuota, un accesorio y un
paquete llevan un grupo, no un porcentaje: la tabla de tipos de un país
puede cambiar bajo ellos sin tocar el catálogo.

Los **tratamientos** son lo que la contraparte hace con ello: interior,
intracomunitario a empresas (inversión del sujeto pasivo, el cliente se
autoliquida según el art. 196), intracomunitario a consumidores,
exportación. El país y el número de IVA del cliente deciden cuál se
aplica, y la comprobación de facturación electrónica se niega a enviar un
documento con inversión del sujeto pasivo mientras falte ese número de
IVA, porque es lo que prueba que el impuesto es suyo.

**Cuándo se devenga el IVA** es un ajuste del espacio: *por facturas*
(devengado al emitir) o *por cobros* (devengado el día en que el cliente
paga). España lo llama *criterio de caja*; Francia pone los servicios
sobre los cobros salvo opción en contra; Alemania lo llama
*Ist-Versteuerung*. Por cobros, un periodo de declaración cubre los
cobros recibidos dentro de él, un pago parcial lleva una parte
proporcional de cada tipo del documento, y el redondeo va al tipo más
amplio para que el total coincida exactamente con lo recibido.

Las **declaraciones** se construyen para un periodo a partir de los
documentos (o los cobros) que contiene, trasladadas a las casillas del
formulario de su país — CA3 en Francia, UStVA en Alemania — y se producen
en PDF y XML. Una declaración pasa de borrador a presentada, y una
presentada no se vuelve a calcular nunca.

El catálogo completo de tipos de un país viene con la app (UE27, CH, NO,
CA); mantenerlo al día cuando un gobierno cambia un tipo le corresponde a
usted.

<!-- anchor: config.tariffs.overview -->
## Cuotas y reglas de facturación

Una **cuota** es un porcentaje de abono con un importe mensual: 25 %,
50 %, 100 % de las medias jornadas laborables de un mes, cada una con su
precio y su grupo de IVA. Un miembro tiene una cuota; el porcentaje se
convierte en una bolsa de medias jornadas, y el importe es lo que cuesta
el mes, se use o no la bolsa.

**La media jornada** es la unidad en la que todo se cuenta. Qué cuenta
como una lo deciden el horario de apertura y la granularidad: una mañana,
una tarde, o una franja de la rejilla que usted defina.

**El exceso** es lo que ocurre más allá de la bolsa. O bien las medias
jornadas de más se rechazan, o bien se cobran al precio de exceso por
media jornada, que es un precio aparte con su propio grupo de IVA.
También pueden solicitarse y concederse medias jornadas adicionales por
miembro.

**Cuándo se factura un mes** es una regla, no una costumbre: la línea de
abono se emite *antes* del mes que cubre, y las líneas de uso la siguen.
Cada línea de abono nombra su mes — *septiembre 100 %* — para que una
factura esté siempre atada al periodo que paga.

**La aritmética de un mes queda congelada en el documento.** Cambiar el
precio de una cuota cambia lo que costará el mes siguiente; no cambia
nunca una factura ya emitida, y no reabre nunca un mes ya liquidado.

<!-- anchor: config.services -->
## Servicios

Todo lo que se vende y no es un puesto: una hora de sala de reuniones, un
bono de impresión, una taquilla, una suscripción de café. Un servicio
tiene nombre, precio, grupo de IVA y unidad, y un administrador puede
ponerlo en una factura o adjuntarlo a un paquete.

Los servicios se despliegan entre un espacio de desarrollo y uno de
producción como entidad propia — y como llevan un grupo de IVA en lugar
de un porcentaje, los tipos viajan con ellos.

<!-- anchor: config.packages -->
## Paquetes de día

Un día vendido como una sola cosa: un puesto, una taquilla y dos horas de
sala de reuniones, a un precio. Un paquete agrupa servicios y una bolsa
de puestos, lleva su propio grupo de IVA, y aparece en la factura como
una línea con sus partes detalladas debajo cuando el diseño lo pide.

Use un paquete donde un miembro no debería tener que montarse el día él
mismo, y una cuota donde el mes es la unidad.

<!-- anchor: config.accessories -->
## Accesorios

Equipamiento adosado a un puesto en lugar de vendido por separado: una
segunda pantalla, una base de conexión, un elevador de escritorio, una
pizarra. Un accesorio tiene nombre, precio opcional con su grupo de IVA,
y se coloca en el plano contra un puesto, una mesa o una oficina.

En el plano, un accesorio forma parte de lo que obtiene una reserva.
Cuando lleva precio, reservar el puesto añade su propia línea de factura
a su propio tipo — por eso el catálogo de accesorios y los tipos de IVA
se despliegan juntos.

<!-- anchor: config.sites -->
## Sedes

Varias direcciones bajo una misma organización: cuál nombra un documento,
qué registro lleva y cómo se adscribe un miembro a una de ellas.

<!-- anchor: config.availability -->
## Disponibilidad y reglas de reserva

*Ajustes del espacio → Disponibilidad.* Cada regla de aquí la aplica el
servidor, no la pantalla: una regla que usted fije se sostiene incluso
frente a una app desactualizada.

**Los días y horas de apertura** definen la jornada laboral y, junto con
la granularidad, qué es una media jornada. **Los días de cierre** son
fechas en que el espacio está cerrado: una reserva que toque uno se
rechaza nombrando ese motivo.

**Los festivos** pueden generarse un año entero en lugar de añadirse
fecha a fecha (#1274). Elija el año, lea la lista que propone el
servidor, y confirme — la generación nunca es automática ni silenciosa.
Volver a lanzar un año no añade nada, así que repetirlo es seguro.

Un mes que ya lleva una factura se **omite y se nombra en pantalla**. Un
día de cierre ahí cambiaría cuántas medias jornadas incluía ese mes, y
por tanto una factura ya emitida; la regla se aplica en la base de datos
y no en la pantalla (ADR 0025). Corregir un mes facturado sigue siendo un
acto deliberado: añada el día a mano y ocúpese de la factura.

Las fechas vienen del servidor, así que la misma lista alimenta una
plantilla que configura un espacio entero. Active *Festivos* para ver la
acción; está desactivada hasta que la pida.

**La granularidad** es lo que puede ser una reserva — media jornada,
jornada completa, o una franja en una rejilla de N minutos. Una reserva
que no cae en la rejilla se rechaza indicando el paso.

**El horizonte** es con cuánta antelación se abren las reservas. **La
duración mínima y máxima** acotan una reserva. **Las reservas
simultáneas** acotan cuántas puede tener abiertas un miembro a la vez,
por espacio y redefinible por miembro. Una reserva termina siempre el día
en que empieza.

**Las reservas pasadas** se rechazan salvo que usted las permita; una
reserva retroactiva del mismo día es legítima, porque quien se sentó a
las nueve debe poder decirlo a las diez.

**Fuera del horario de apertura** tiene tres modos: *desactivado*
(rechazado), *solo entrada espontánea* (se puede hacer un check-in
espontáneo, reservar con antelación no) o *cobrado* (permitido y
contado). Cada uno tiene su propia frase de rechazo, para que un miembro
sepa qué puerta está cerrada.

**Las reglas de validación** deciden qué actos necesitan una decisión
humana — véase más abajo.

<!-- anchor: config.plan.overview -->
## El plano

El plano es aquello sobre lo que reservan los miembros. Se construye con
tres formas anidadas sobre una imagen de fondo, en una rejilla cuya celda
es la unidad de colocación. Constrúyalo en este orden: primero la planta
y su fondo, después las oficinas, después las mesas y los puestos. Todo
lo de abajo se calca sobre la imagen, nunca de memoria.

<!-- anchor: config.plan.levels -->
### Plantas

Una planta es un piso, o un conjunto de salas tratado como uno solo.
Lleva su **sede** (a qué dirección pertenece), su **imagen de fondo** y,
cuando es reservable entera, su **precio por media jornada** y su grupo
de IVA.

*Reservable entera* es un interruptor en la propia planta. Sin él, una
petición de reservar la planta completa se rechaza indicando qué
interruptor falta — el rechazo nombra el ajuste en vez de culpar al
miembro.

<!-- anchor: config.plan.offices -->
### Oficinas, mesas y puestos

**Una oficina** es una sala dentro de una planta. **Una mesa** es una
mesa dentro de una oficina o suelta en la planta. **Un puesto** es un
sitio en una mesa — lo que un miembro reserva realmente. Cada uno tiene
su huella en la rejilla; un puesto ocupa seis celdas de ancho y cuatro de
fondo, y eso fija la escala de todo lo demás.

Un puesto lleva su **orientación** (hacia dónde mira la silla, para que
el plano se lea como la sala), su **equipamiento y accesorios** y sus
**etiquetas** — una credencial o una etiqueta NFC hace el puesto
escaneable en la puerta.

**Reservable entera** existe también en la mesa y en la oficina:
actívelo y la mesa o la sala se reserva de una vez en lugar de puesto a
puesto. Una reserva del conjunto bloquea a sus hijos durante el periodo,
y una reserva de un hijo bloquea el conjunto.

**Bloquear** un puesto lo retira del servicio por mantenimiento sin
borrarlo: sigue en el plano, atenuado, y todo intento de reserva se
rechaza con ese motivo. Los bloqueos nunca viajan de un espacio de
desarrollo a uno de producción, porque un bloqueo de mantenimiento es un
hecho sobre un edificio en un día.

<!-- anchor: config.plan.background -->
### La imagen de fondo

Un plano se lee mejor sobre un dibujo de la sala real. La imagen es por
planta, va bajo la rejilla, y no se mueve una vez calcados los puestos
sobre ella.

<!-- image: config-plan-background -->

<!-- anchor: config.plan.ai-image -->
### Hacer esa imagen a partir de fotografías, con una IA

No hace falta el dibujo de un arquitecto. Fotografíe la sala, pida a un
modelo de imagen un plano cenital, y use su respuesta como fondo.

**Fotografíe bien.** Colóquese en cada esquina, sostenga la cámara a la
altura del pecho, y tome una foto por esquina más una a lo largo de cada
pared larga. Que el suelo entero aparezca en al menos dos de ellas. Mida
una cosa — el largo de una mesa, el ancho de una puerta — y anote el
número: es lo que fijará la escala.

**Pida un plano, no una imagen.** La instrucción que funciona pide una
vista cenital ortográfica, colores planos, sin perspectiva, sin sombras,
sin personas, y el mobiliario como simples huellas:

> A partir de estas fotografías de una misma sala, dibuja un plano
> ortográfico cenital de ella. Paredes rectas, ángulos rectos exactos,
> sin perspectiva y sin sombras. Muestra solo los elementos fijos:
> paredes, puertas con su abatimiento, ventanas, radiadores, pilares,
> bloques de cocina y sanitarios, y la huella de cada mueble grande como
> una forma sencilla con contorno. Colores claros y apagados sobre fondo
> blanco; sin texto, sin etiquetas, sin cotas, sin personas, sin
> decoración. La [mesa] de la sala mide [1,60] m de largo — dibuja todo a
> esa escala. Devuelve una sola imagen, en [4:3], de al menos 1600
> píxeles de ancho.

**Compruebe la escala antes de calcar.** Importe la imagen como fondo de
la planta y mida el objeto que anotó contra la rejilla: un puesto ocupa
seis celdas de ancho y cuatro de fondo, y una celda es la unidad de
colocación de la app. Escale la imagen hasta que el objeto real coincida
con su tamaño verdadero en la rejilla; todo lo calcado después será
entonces honesto.

**Calque, no dibuje.** Coloque oficinas, mesas y puestos sobre la imagen.
El fondo guía el ojo; lo que la app reserva son los puestos que usted
coloca.

**Qué no aceptar.** Una vista en perspectiva, un render con sombras, un
plano con salas inventadas, o uno cuyo mobiliario no coincide con las
fotografías. Vuelva a pedirlo con una instrucción más estricta en lugar
de corregir a mano un plano equivocado.

<!-- anchor: config.plan.images -->
### Imágenes del plano

Imágenes colocadas *sobre* el plano en lugar de debajo — un logotipo
junto a la entrada, un cartel, la foto de un rincón —, cada una con su
posición y su tamaño en la rejilla. Son decoración: no se reserva nada
sobre ellas, y van por encima del fondo y por debajo de los puestos.

Viajan con el plano cuando se despliega, y el archivo de espacio se las
lleva al exportar.

<!-- anchor: config.documents -->
## Biblioteca de documentos

Archivos que el espacio guarda y muestra a quienes tienen derecho a
verlos: el reglamento interno, un certificado de seguro, un plano de
evacuación, un modelo de acuerdo de socio. Cada documento lleva los roles
que pueden leerlo, así que la biblioteca es un único sitio con
visibilidad por rol en lugar de varias carpetas.

Los *diseños* de documento — la maquetación de una factura o de una
carta — son otra cosa, y están en la
[guía técnica](Admin-Technical-Guide.es).

<!-- anchor: config.roles -->
## Roles y permisos

*Ajustes → Roles.* Una matriz: los roles a un lado, los permisos al otro.
Propietario, copropietario, administrador, miembro — y cada permiso es
una casilla que puede activar o desactivar, salvo las que un propietario
tiene siempre.

Un permiso se le pide al servidor a través de una sola función: un
permiso que usted retira queda retirado en todas partes a la vez. La
pantalla oculta el botón, y la llamada que hay detrás se niega de todos
modos.

Los permisos de entorno viven aquí también — *Entrar en el espacio de
producción*, *Desplegar a desarrollo*, *Desplegar a producción* — y se
explican en la [guía de entornos](Environments-Guide.es).

<!-- anchor: config.validation -->
## Reglas de validación

Qué actos necesitan una decisión humana antes de surtir efecto, y quién
decide. Cada dominio tiene su regla: un miembro que se incorpora, una
reserva que se elimina, una factura que se da por fallida, medias
jornadas adicionales que se conceden, y las demás.

Por dominio elige usted si llega a plantearse una solicitud, y si la
solicitud de un administrador o de un propietario se **valida
automáticamente** — en cuyo caso el evento se registra ya resuelto, en
lugar de avisar a un validador para que apruebe su propia acción.

Una decisión es siempre un evento: quién decidió, cuándo y sobre qué.
Nada se valida en silencio, y una decisión tomada por el sistema lo dice.

<!-- anchor: config.features -->
## Funcionalidades

Cada funcionalidad es un interruptor. Qué apaga un interruptor, qué no
apaga nunca (la aritmética ya aplicada), y el grafo de dependencias que
decide qué interruptores están disponibles siquiera.
