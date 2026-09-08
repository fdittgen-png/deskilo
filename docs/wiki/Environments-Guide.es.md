# Entornos — un espacio para probar, un espacio que es real

Dos espacios, un solo nombre. En uno configura, importa, imprime y rompe
cosas; en el otro hay personas que reservan plazas y reciben facturas
que se deben. Lo que fija en el primero, lo despliega en el segundo.

<!-- anchor: env.pair.why -->
## Por qué una pareja

Un espacio de coworking lo configura quien lo lleva, no un integrador, y
la configuración es donde los errores son baratos de cometer y caros de
descubrir: una tarifa escrita dos veces, un tipo de IVA en el grupo
equivocado, un plano cuyas plazas se movieron después de que la gente
las reservara. Un espacio de desarrollo no cuesta nada y absorbe todo
eso. Cada documento que imprime lleva la **marca de agua de
desarrollo**, sus facturas electrónicas van al punto de prueba, y nada
de lo que produce puede confundirse con un documento real.

<!-- image: env-pair-profiles -->

<!-- anchor: env.pair.create -->
## Crear la pareja

Un espacio nuevo se crea **con su gemelo**: mismo nombre, mismo país,
misma moneda, misma zona horaria, ambos suyos desde el primer segundo.
*Perfiles* muestra la pareja como una sola tarjeta con dos chips,
**DEV** y **PROD**; tocar un chip cambia de lado, y ese cambio se
convierte en su valor por defecto, de modo que un reinicio abre donde
lo dejó.

Un espacio creado antes de que existieran las parejas, o creado solo,
recibe su gemelo cuando quiera: *Ajustes → Avanzado → Crear su gemelo*.
La configuración se copia una vez en ese momento; a partir de ahí los
dos lados son independientes y solo un despliegue mueve algo entre
ellos.

<!-- anchor: env.pair.permissions -->
## Quién puede qué

Tres permisos en la matriz de roles:

- **Entrar en el espacio de producción** — sin él, un rol no puede ser
  miembro del lado de producción en absoluto. Los propietarios y
  copropietarios lo tienen; los administradores lo tienen; los miembros
  no, hasta que usted lo dé.
- **Desplegar en desarrollo** — traer la configuración del lado de
  producción al de desarrollo. Los administradores lo tienen.
- **Desplegar en producción** — el delicado, por defecto solo
  propietario y copropietario. Quien lo tiene, tiene también *Desplegar
  en desarrollo*.

De ahí salen dos reglas. **Un miembro del lado de producción es siempre
miembro del lado de desarrollo**: la afiliación se refleja, rol y estado
incluidos, así nadie tiene que ser invitado dos veces. Y **un rol entra
en el lado de producción solo mientras tenga el permiso de acceso** —
una invitación, una adhesión o una toma de perfil hacia producción se
rechaza en caso contrario, con el motivo en pantalla.

<!-- anchor: env.work.configure -->
## Trabajar en el lado de desarrollo

Configure, importe un archivo de espacio, invite a un colega, emita una
factura de prueba, mueva plazas, imprima. Nada de eso es real: la marca
de agua lo dice en cada documento, y el punto de prueba de factura
electrónica se niega a alcanzar una plataforma gubernamental.

<!-- anchor: env.deploy.screen -->
## Desplegar

*Ajustes → Administración → Despliegue*, en el lado que quiere
**escribir**. Un despliegue va siempre **al lado en el que está**: en el
lado de producción el botón dice *Traer de DEV*, en el de desarrollo
*Traer de PROD*. Nada puede empujarse al otro lado por error.

<!-- image: env-deploy-screen -->

<!-- anchor: env.deploy.entities -->
### Lo que viaja, entidad por entidad

Agrupado en **Configuración**, **Datos maestros** e **Informes**:

| Grupo | Entidades |
|---|---|
| Configuración | Identidad y menciones legales · Reglas de reserva · Reglas de validación · Matriz de roles · Reglas de recordatorio · Instrucciones de pago · Enlaces de documentos · Días de cierre · Plantillas de invitación · Funcionalidades |
| Datos maestros | IVA · Tarifas · Servicios · Paquetes · Accesorios · Sedes · Planos |
| Informes | Diseños de documentos, con sus imágenes |

Marque una y lo que necesita se marca con ella — los servicios
necesitan los tipos de IVA, un plano necesita sus accesorios y sus
sedes.

<!-- anchor: env.deploy.plan -->
### El plano se fusiona, nunca se sustituye

Las plantas se emparejan por nombre; las oficinas, mesas y plazas por
nombre o, sin nombre, por posición. Lo que tiene el otro lado se añade o
se actualiza; lo que solo tiene este lado se señala y se **conserva**,
porque una plaza puede llevar ya una reserva. Las credenciales y los
bloqueos no viajan nunca. Los fondos y las imágenes del plano se copian
con él.

<!-- anchor: env.deploy.preview -->
### La vista previa, y luego la confirmación

Nada se mueve antes de que una vista previa diga, por entidad, qué se
añadiría, cambiaría y quitaría. Una vista previa sin nada que hacer lo
dice y no despliega nada. Después una confirmación nombra el lado que va
a escribirse y las entidades, porque ese es el momento en que un error
se vuelve caro.

<!-- anchor: env.deploy.journal -->
### El diario y la vuelta atrás

Cada despliegue queda registrado: quién, cuándo, en qué sentido, qué
entidades, y qué contenía el destino antes. *Deshacer* en el último
restaura exactamente eso. Deshacer se rechaza mientras haya un
despliegue posterior sobre el mismo lado — deshágalos en orden.

<!-- anchor: env.deploy.never -->
### Lo que no viaja nunca

Los miembros, las reservas, las cuentas, las facturas, los pagos, los
eventos, los mensajes, las credenciales de cualquier tipo y los
contadores de numeración. Una serie de números se despliega como un
**formato**; el número siguiente pertenece siempre al espacio que lo
emite.

<!-- anchor: env.instances -->
## Cuando una pareja no basta

Dos espacios comparten una base de datos. Donde los datos personales o
las credenciales de pago deban estar físicamente separados, empareje
**instancias** en su lugar: el asistente de nueva instancia construye
una segunda base a partir del paquete, y las mismas entidades viajan
entre ambas a través del archivo de espacio.
