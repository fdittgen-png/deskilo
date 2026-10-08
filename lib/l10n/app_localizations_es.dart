// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get a11yClearDate => 'Borrar la fecha';

  @override
  String get a11yDecrease => 'Disminuir';

  @override
  String get a11yFinishEditing => 'Terminar la edición';

  @override
  String get a11yIncrease => 'Aumentar';

  @override
  String get a11yMoveDown => 'Bajar';

  @override
  String get a11yMoveUp => 'Subir';

  @override
  String get a11yRecentre => 'Ajustar el plano a la pantalla';

  @override
  String get a11ySeatBlocked => 'no disponible';

  @override
  String get a11ySeatFree => 'libre';

  @override
  String get a11ySeatMine => 'tu sitio';

  @override
  String get a11ySeatOccupied => 'ocupado';

  @override
  String get a11ySeatReserved => 'reservado';

  @override
  String get a11yZoomIn => 'Acercar';

  @override
  String get a11yZoomOut => 'Alejar';

  @override
  String get aboutAttribution =>
      'Based on DesKilo by Florian DITTGEN — https://github.com/fdittgen-png/deskilo';

  @override
  String get aboutAttributionNote =>
      'Esta mención debe seguir visible en cada copia y cada versión modificada.';

  @override
  String get aboutOpenSource => 'Software libre (licencia AGPL-3.0)';

  @override
  String get aboutOpenSourceDesc => 'Código fuente en GitHub';

  @override
  String get aboutPrivacy => 'Política de privacidad';

  @override
  String get aboutReportBug => 'Informar de un error / sugerir una función';

  @override
  String get aboutSupportBody =>
      'Esta aplicación es gratuita, de código abierto y sin publicidad. Si te resulta útil, apoya al desarrollador.';

  @override
  String get aboutSupportTitle => 'Apoyar este proyecto';

  @override
  String aboutVersion(String version) {
    return 'Versión $version';
  }

  @override
  String get accessKindNegotiations => 'Negociaciones de precios';

  @override
  String get accessKindProfile => 'su perfil';

  @override
  String get accessLogEmpty =>
      'Nadie ha consultado sus finanzas ni sus mensajes.';

  @override
  String accessLogRow(String actor, String category, String subject) {
    return '$actor consultó $category de $subject';
  }

  @override
  String get accessLogTitle => 'Quién accedió a sus datos';

  @override
  String get accessNobodyElse => 'nadie más';

  @override
  String get accessRuleEvents => 'Usted, el miembro que actuó y los admins.';

  @override
  String accessRuleFinances(String people) {
    return 'Usted y quienes tienen el permiso de finanzas: $people.';
  }

  @override
  String accessRuleManagedProfile(String people) {
    return 'Mientras este perfil se gestionó para usted: $people. Cada consulta o cambio por alguno de ellos consta abajo.';
  }

  @override
  String get accessRuleMessages =>
      'Solo las personas de la conversación — ningún rol puede leer una conversación de la que no forma parte.';

  @override
  String accessRuleNegotiations(String people) {
    return 'Tú, los propietarios y los admins de finanzas: $people. Cada lectura por otra persona queda registrada abajo.';
  }

  @override
  String get accessRuleReminders => 'Solo usted.';

  @override
  String get accessRuleReservations =>
      'Todos los miembros del espacio — el plano muestra la ocupación a todos.';

  @override
  String get accessoriesActive => 'Activo';

  @override
  String get accessoriesEdit => 'Editar accesorio';

  @override
  String get accessoriesEmpty => 'Aún no hay accesorios.';

  @override
  String get accessoriesInactive => 'Inactivo';

  @override
  String get accessoriesName => 'Nombre';

  @override
  String get accessoriesNew => 'Nuevo accesorio';

  @override
  String get accessoriesNoSupplement => 'Sin suplemento';

  @override
  String accessoriesPerHalfDay(String amount) {
    return '$amount / media jornada';
  }

  @override
  String get accessoriesSupplement => 'Suplemento por media jornada';

  @override
  String get accessoriesTitle => 'Accesorios';

  @override
  String get accountActivityEmpty => 'No hay registros que mostrar.';

  @override
  String get accountActivityFailed =>
      'No se pudo cargar tu historial financiero. Toca para reintentar.';

  @override
  String get accountActivityScope =>
      'Todos tus perfiles en este servidor, incluidas las afiliaciones anteriores. Las monedas se muestran por separado.';

  @override
  String get accountActivityTitle => 'Mi consumo y mis pagos';

  @override
  String get accountCardTitle => 'Tu cuenta';

  @override
  String get accountCredit => 'Crédito a favor';

  @override
  String get accountImputationHint =>
      'Tu crédito puede saldar facturas abiertas: el espacio lo imputa al conciliar los pagos.';

  @override
  String get accountInvoiceIssued => 'Factura emitida';

  @override
  String get accountInvoiceRegrouped =>
      'Incluido en una factura de liquidación';

  @override
  String get accountInvoiceVoided => 'Factura anulada';

  @override
  String get accountNet => 'Posición neta';

  @override
  String accountOpenPartial(String period, String paid) {
    return '$period · $paid pagados';
  }

  @override
  String get accountPaymentAsk => 'Elegir al pagar';

  @override
  String get accountPaymentConfirmed => 'Pago confirmado';

  @override
  String get accountPaymentPreference => 'Pago en línea preferido';

  @override
  String get accountPaymentsTitle => 'Pagos';

  @override
  String get accountRefundDue => 'Reembolso pendiente del espacio';

  @override
  String get accountUsageCorrected => 'Consumo facturable corregido';

  @override
  String accountUsageMinutes(int minutes) {
    return '$minutes minutos';
  }

  @override
  String get accountingExportDevelopment =>
      'Espacio de desarrollo: el archivo lleva la marca DEV y no es la contabilidad real.';

  @override
  String get addressCountryLabel => 'País';

  @override
  String get addressNone => 'Sin dirección';

  @override
  String get addressSaved => 'Dirección guardada';

  @override
  String get addressTitle => 'Dirección';

  @override
  String get addressVatIdLabel => 'Número de IVA (si facturas como empresa)';

  @override
  String get addressWindowCountry => 'Seguir el país';

  @override
  String get addressWindowLeft => 'Izquierda (DIN 5008)';

  @override
  String get addressWindowOff => 'Sin ventanilla';

  @override
  String get addressWindowRight => 'Derecha (uso francés)';

  @override
  String get addressWindowSubtitle =>
      'Dónde se imprime el destinatario para que se vea por la ventanilla del sobre. El bloque mide 85 × 45 mm, a 45 mm del borde superior.';

  @override
  String get addressWindowTitle => 'Ventanilla de dirección';

  @override
  String get agreementExtraHalfDay => 'Media jornada extra';

  @override
  String get amenityDock => 'Estación de acoplamiento';

  @override
  String get amenityErgonomicChair => 'Silla ergonómica';

  @override
  String get amenityMonitor => 'Monitor';

  @override
  String get amenityStandingDesk => 'Mesa de pie';

  @override
  String get amenityWindow => 'Junto a la ventana';

  @override
  String get appTitle => 'DesKilo';

  @override
  String get applicationAcceptedVote => 'Ha aprobado esta solicitud';

  @override
  String get applicationApproved => 'Aprobada';

  @override
  String get applicationDecisionComment =>
      'Comentario visible para la persona solicitante';

  @override
  String get applicationDiscussionHint =>
      'Tus solicitudes y conversaciones con quienes las revisan siguen disponibles, incluso si se rechaza una solicitud.';

  @override
  String get applicationNoMessages => 'Aún no hay mensajes.';

  @override
  String get applicationPending => 'Pendiente de aprobación';

  @override
  String get applicationRefused => 'Rechazada';

  @override
  String get applicationRefusedVote => 'Ha rechazado esta solicitud';

  @override
  String get applicationReplyFailed =>
      'Tu mensaje no se ha enviado. Se conserva el borrador; inténtalo de nuevo.';

  @override
  String get applicationsEmpty => 'No hay solicitudes de acceso.';

  @override
  String get applicationsLoadFailed =>
      'No se pudieron cargar tus solicitudes de acceso. Inténtalo de nuevo.';

  @override
  String get applicationsTitle => 'Solicitudes de acceso';

  @override
  String get assistantPrefix => 'Asistente';

  @override
  String get assistantSetupActorConfigurer =>
      'Quién: alguien que gestiona la configuración de este espacio de trabajo';

  @override
  String get assistantSetupActorDatabaseAdministrator =>
      'Quién: un administrador de la base de datos';

  @override
  String get assistantSetupActorInstanceOperator =>
      'Quién: el propietario de la instancia o un delegado';

  @override
  String get assistantSetupActorIntegrations =>
      'Quién: alguien que gestiona las integraciones de este espacio de trabajo';

  @override
  String get assistantSetupActorYou => 'Quién: usted';

  @override
  String get assistantSetupAllDone =>
      'Todo está configurado para este espacio de trabajo.';

  @override
  String get assistantSetupApply => 'Aplicar';

  @override
  String get assistantSetupConnectHowTo =>
      '1. En su asistente, añada un conector personalizado con esta URL.\n2. Inicie sesión con su cuenta de DesKilo cuando se le pida.\n3. Apruebe este espacio de trabajo y las operaciones que permite.';

  @override
  String get assistantSetupCopied => 'URL del conector copiada.';

  @override
  String get assistantSetupCopyUrl => 'Copiar la URL del conector';

  @override
  String get assistantSetupCustomise => 'Personalizar';

  @override
  String get assistantSetupFailed =>
      'No se pudo guardar. No cambió nada; inténtelo de nuevo.';

  @override
  String assistantSetupInstanceNames(String names) {
    return 'Responden de esta base de datos: $names.';
  }

  @override
  String get assistantSetupInstanceNobody =>
      'Nadie responde todavía de esta base de datos.';

  @override
  String get assistantSetupInstanceYou =>
      'Usted responde de esta base de datos: active los asistentes desde las herramientas de la instancia.';

  @override
  String get assistantSetupIntro =>
      'Lo que los asistentes necesitan en este espacio de trabajo, en orden. Cada paso indica quién lo realiza.';

  @override
  String get assistantSetupLinkIdentity => 'Confirmar mi identidad';

  @override
  String assistantSetupNextTodo(String step) {
    return 'Siguiente: $step.';
  }

  @override
  String assistantSetupNextWaiting(String step, String actor) {
    return 'Siguiente: $step. $actor.';
  }

  @override
  String get assistantSetupNoConnector =>
      'Esta app funciona sin servidor, así que no hay URL de conector.';

  @override
  String get assistantSetupNoWorkspace =>
      'Elija primero un espacio de trabajo.';

  @override
  String get assistantSetupPreviewAdds => 'Añadidas';

  @override
  String get assistantSetupPreviewNone =>
      'Sin cambios: el espacio de trabajo ya ofrece exactamente esta selección.';

  @override
  String get assistantSetupPreviewNote =>
      'Solo los datos propios de un miembro y las consultas de disponibilidad. Los asistentes ya conectados reciben operaciones nuevas solo cuando cada persona vuelve a aprobar.';

  @override
  String get assistantSetupPreviewOwn =>
      'Los asistentes solo ven los datos propios de cada miembro.';

  @override
  String get assistantSetupPreviewRemoves => 'Retiradas';

  @override
  String get assistantSetupPreviewTitle => 'Selección recomendada';

  @override
  String get assistantSetupReasonConnect =>
      'Añada el conector en su asistente, inicie sesión y apruebe este espacio de trabajo.';

  @override
  String get assistantSetupReasonEligibility =>
      'Los administradores de esta base de datos aprueban a cada persona una vez, para todos sus espacios de trabajo.';

  @override
  String get assistantSetupReasonIdentity =>
      'Un asistente actúa en su nombre, así que esta base de datos debe saber que es usted.';

  @override
  String get assistantSetupReasonInstallation =>
      'El propietario de la instancia o un delegado activa los asistentes para todos los espacios de trabajo de esta base de datos.';

  @override
  String get assistantSetupReasonPolicy =>
      'No se ofrece nada a los asistentes hasta que alguien elija las operaciones.';

  @override
  String get assistantSetupReasonWorkspace =>
      'Mientras esté desactivado, el espacio de trabajo rechaza toda llamada de asistente.';

  @override
  String get assistantSetupRecommended => 'Usar la selección recomendada';

  @override
  String get assistantSetupRequest => 'Solicitar acceso';

  @override
  String get assistantSetupReview => 'Revisar solicitudes';

  @override
  String get assistantSetupSaved => 'Guardado.';

  @override
  String get assistantSetupStale =>
      'Alguien cambió la oferta mientras tanto. Revísela e inténtelo de nuevo.';

  @override
  String get assistantSetupStateBlocked => 'Después de los pasos anteriores';

  @override
  String get assistantSetupStateDone => 'Hecho';

  @override
  String get assistantSetupStateTodo => 'Pendiente';

  @override
  String get assistantSetupStateUnavailable => 'No se pudo consultar';

  @override
  String get assistantSetupStateWaiting => 'En espera';

  @override
  String get assistantSetupStepConnect => 'Conecte su asistente';

  @override
  String get assistantSetupStepEligibility => 'Solicite su acceso a asistentes';

  @override
  String get assistantSetupStepIdentity => 'Vincule su identidad';

  @override
  String get assistantSetupStepInstallation =>
      'Asistentes activados en esta base de datos';

  @override
  String get assistantSetupStepPolicy =>
      'Elegir qué pueden hacer los asistentes';

  @override
  String get assistantSetupStepWorkspace =>
      'Activar asistentes en este espacio de trabajo';

  @override
  String get assistantSetupTitle => 'Configuración de asistentes';

  @override
  String get assistantSetupTurnOn => 'Activar';

  @override
  String get authAlreadyRegistered =>
      'Esta dirección no puede usarse para crear una cuenta. Inicia sesión o restablece tu contraseña.';

  @override
  String get authConnectServer =>
      'Conectar con el servidor de una organización';

  @override
  String get authContinueWith => 'o continuar con';

  @override
  String get authDisplayNameLabel => 'Nombre visible';

  @override
  String get authEmailLabel => 'Correo electrónico';

  @override
  String get authEmailNotConfirmed =>
      'Confirma primero tu dirección de correo: abre el mensaje que te enviamos y luego inicia sesión.';

  @override
  String get authFieldRequired => 'Obligatorio';

  @override
  String get authForgotPassword => '¿Olvidaste la contraseña?';

  @override
  String get authGenericError =>
      'Error de autenticación. Comprueba tus credenciales e inténtalo de nuevo.';

  @override
  String get authHidePassword => 'Ocultar contraseña';

  @override
  String get authJoinByInvitation => 'Unirse con invitación';

  @override
  String get authJoinHint =>
      'Crea tu cuenta o inicia sesión primero; pegarás tu invitación justo después.';

  @override
  String authLinkAlreadyUsed(String provider) {
    return 'Esta identidad de $provider ya está vinculada a otra cuenta.';
  }

  @override
  String authLinkFailed(String provider, String code) {
    return 'No se pudo vincular $provider ($code). Inténtelo de nuevo; si sigue fallando, comunique este código al administrador del servidor.';
  }

  @override
  String get authLinkManualDisabled =>
      'La vinculación de cuentas está desactivada en este servidor. Su administrador debe activar «Permitir vinculación manual» en los ajustes de autenticación.';

  @override
  String get authNetworkError =>
      'No se pudo contactar con el servidor. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get authPasswordLabel => 'Contraseña';

  @override
  String get authPasswordTooShort => 'Al menos 8 caracteres';

  @override
  String get authProviderDisabled =>
      'Este método de acceso está desactivado en este servidor.';

  @override
  String get authRateLimited =>
      'Demasiados intentos. Espera un momento y vuelve a intentarlo.';

  @override
  String get authRecoveryNotSaved =>
      'Tu código fue aceptado, pero la nueva contraseña no se guardó. Intenta guardarla de nuevo.';

  @override
  String get authRecoveryRetryUpdate => 'Volver a guardar la nueva contraseña';

  @override
  String get authRecoverySessionLost =>
      'Ese código ya no es válido aquí. Solicita uno nuevo.';

  @override
  String get authResetCodeLabel => 'Código del correo';

  @override
  String get authResetCodeSent => 'Código enviado — revisa tu correo.';

  @override
  String get authResetDone => 'Contraseña actualizada — has iniciado sesión.';

  @override
  String get authResetExplainer =>
      'Te enviaremos un código de un solo uso por correo. Úsalo aquí para establecer una nueva contraseña.';

  @override
  String get authResetInvalidCode => 'Ese código no es válido o ha caducado.';

  @override
  String get authResetNewPasswordLabel => 'Nueva contraseña';

  @override
  String get authResetSendCode => 'Enviar código';

  @override
  String get authResetSubmit => 'Establecer nueva contraseña';

  @override
  String get authResetTitle => 'Restablecer contraseña';

  @override
  String get authShowPassword => 'Mostrar contraseña';

  @override
  String get authSignInButton => 'Iniciar sesión';

  @override
  String get authSignInTitle => 'Iniciar sesión';

  @override
  String get authSignOut => 'Cerrar sesión';

  @override
  String get authSignUpButton => 'Crear cuenta';

  @override
  String get authSignUpTitle => 'Crear cuenta';

  @override
  String authSocialUnavailable(String provider) {
    return 'El inicio de sesión con $provider aún no está disponible — el servidor no lo ha activado.';
  }

  @override
  String get authToggleToSignIn => '¿Ya tienes cuenta? Inicia sesión';

  @override
  String get authToggleToSignUp => '¿Nuevo aquí? Crea una cuenta';

  @override
  String get authVerifyBackToSignIn => 'Volver al inicio de sesión';

  @override
  String authVerifyBody(String email) {
    return 'Hemos enviado un enlace de confirmación a $email. Ábrelo en este dispositivo para terminar de crear tu cuenta.';
  }

  @override
  String get authVerifyChangeEmail => 'Usar otra dirección';

  @override
  String get authVerifyHint =>
      '¿Nada todavía? Mira en la carpeta de spam o vuelve a enviarlo.';

  @override
  String get authVerifyResend => 'Volver a enviar el correo';

  @override
  String get authVerifyResendWait =>
      'Podrás volver a enviarlo dentro de un minuto.';

  @override
  String get authVerifyResent => 'Enviado de nuevo.';

  @override
  String get authVerifyTitle => 'Revisa tu correo';

  @override
  String get authWeakPassword => 'Elige una contraseña más segura.';

  @override
  String get availabilityAddClosure => 'Añadir día de cierre';

  @override
  String get availabilityClosureDays => 'Días de cierre';

  @override
  String get availabilityClosureReason => 'Motivo (opcional)';

  @override
  String get availabilityFullDayHours =>
      'Horas facturadas como jornada completa';

  @override
  String get availabilityGranularity15 => 'Franjas de 15 minutos';

  @override
  String get availabilityGranularity30 => 'Franjas de 30 minutos';

  @override
  String get availabilityGranularity5 => 'Franjas de 5 minutos';

  @override
  String get availabilityGranularity60 => 'Franjas de 1 hora';

  @override
  String get availabilityGranularityDescription =>
      'Medias jornadas: las reservas cubren la mañana, la tarde o la jornada completa — las ventanas siguen el horario laboral configurado.';

  @override
  String get availabilityGranularityFlexible => 'Franja horaria libre';

  @override
  String get availabilityGranularityFullDay => 'Solo días completos';

  @override
  String get availabilityGranularityHalfDay => 'Medios días (mañana y tarde)';

  @override
  String get availabilityGranularityHours =>
      'Horas reales (de–a exacto, medias/jornadas como atajos)';

  @override
  String get availabilityGranularityTitle => 'Granularidad de las reservas';

  @override
  String get availabilityHalfBoundary => 'Límite de media jornada';

  @override
  String get availabilityHalfDayHours => 'Horas facturadas como media jornada';

  @override
  String availabilityHourOption(int count) {
    return '$count h';
  }

  @override
  String get availabilityLastOpenDay =>
      'Al menos un día de la semana debe permanecer abierto.';

  @override
  String get availabilityNoClosures => 'No hay días de cierre.';

  @override
  String get availabilityOpenWeekdays => 'Días de apertura';

  @override
  String get availabilityPoliciesTitle => 'Políticas de reserva';

  @override
  String get availabilityTitle => 'Disponibilidad';

  @override
  String get availabilityWorkEnd => 'Fin de la jornada';

  @override
  String get availabilityWorkHoursDescription =>
      'Las ventanas de media jornada y jornada completa en todas partes — reservas, check-in y facturación — siguen este horario.';

  @override
  String get availabilityWorkHoursInvalid =>
      'Debe cumplirse: inicio < límite de media jornada < fin.';

  @override
  String get availabilityWorkHoursTitle => 'Horario laboral';

  @override
  String get availabilityWorkStart => 'Inicio de la jornada';

  @override
  String get backendCopyLink => 'Copiar';

  @override
  String get backendCurrentTitle => 'Este dispositivo usa';

  @override
  String get backendDescriptorInvalid =>
      'Eso no es un código de servidor DesKilo válido.';

  @override
  String get backendDescriptorLabel => 'Código de servidor';

  @override
  String backendDescriptorNamed(String label) {
    return 'Llamado «$label» por quien lo compartió — sin verificar.';
  }

  @override
  String backendDestination(String host) {
    return 'Destino: $host';
  }

  @override
  String get backendErrorKeyConnectionString =>
      'Eso es una cadena de conexión a la base de datos. Nunca sale del servidor — pegue aquí la clave publicable del proyecto.';

  @override
  String get backendErrorKeyEmpty => 'Introduce la clave publicable.';

  @override
  String get backendErrorKeyNotSupabase =>
      'Esa no es una clave publicable de Supabase (sb_publishable_…).';

  @override
  String get backendErrorKeyPersonalToken =>
      'Eso es un token de acceso personal. Se queda con su propietario — pegue aquí la clave publicable del proyecto.';

  @override
  String get backendErrorKeySecret =>
      'Eso es una clave secreta, no una publicable. No la comparta nunca: rótela en Project Settings → API keys y pegue aquí la clave publicable.';

  @override
  String get backendErrorKeyUserToken =>
      'Eso es un token de sesión o de identidad, no una clave de proyecto. Pegue aquí la clave publicable del proyecto.';

  @override
  String get backendErrorUrlEmpty => 'Introduce la URL del proyecto.';

  @override
  String get backendErrorUrlNoHost => 'Esa no es una dirección completa.';

  @override
  String get backendErrorUrlNotCanonical =>
      'Indique solo la dirección del proyecto (https://host), sin ruta, parámetros ni credenciales.';

  @override
  String get backendErrorUrlNotHttps => 'La URL debe empezar por https://.';

  @override
  String get backendFacetNo => 'no';

  @override
  String get backendFacetUnknown => 'desconocido';

  @override
  String get backendFacetYes => 'sí';

  @override
  String backendFacets(
    String reachable,
    String key,
    String schema,
    String version,
  ) {
    return 'Alcanzado: $reachable · Clave aceptada: $key · Esquema: $schema · Versión: $version';
  }

  @override
  String get backendFullCheckHint =>
      'Pegue un token de acceso personal para esta comprobación. Solo se usa para ella y nunca se guarda.';

  @override
  String get backendFullCheckTitle => 'Ejecutar una comprobación completa';

  @override
  String get backendFullCheckUseToken => 'Usar este token';

  @override
  String get backendHowTitle => 'Usar tu propio servidor';

  @override
  String get backendKeyLabel => 'Clave publicable';

  @override
  String backendLastOk(String time) {
    return 'Última prueba correcta: $time';
  }

  @override
  String get backendModeConnect => 'Conectar con una organización existente';

  @override
  String get backendModeConnectHint =>
      'Escanee o pegue el código de servidor que le dio su organización. Nunca hace falta una clave de administrador.';

  @override
  String get backendModeDefault => 'Usar el servicio de DesKilo';

  @override
  String get backendModeDefaultHint =>
      'El servicio de DesKilo no necesita configuración. Los miembros de una organización con servidor propio usan su código en su lugar.';

  @override
  String get backendModeOperator => 'Configurar un servidor (operadores)';

  @override
  String get backendOpenDashboard => 'Abrir en Supabase';

  @override
  String get backendOwnServer => 'Su propio servidor';

  @override
  String get backendOwnership =>
      'Pertenece a su organización de Supabase. DesKilo no conserva ningún acceso.';

  @override
  String get backendOwnershipOther =>
      'Pertenece a quien lo opera. DesKilo no conserva ningún acceso.';

  @override
  String get backendPaste => 'Pegar';

  @override
  String backendPendingBody(String active, String saved) {
    return 'Esta sesión sigue en $active. $saved tomará el relevo cuando cierre y vuelva a abrir la app.';
  }

  @override
  String get backendPendingTitle => 'Guardado para el próximo inicio';

  @override
  String get backendPendingUndo => 'Deshacer';

  @override
  String get backendPendingUndone =>
      'Deshecho — el servidor anterior ha vuelto.';

  @override
  String backendProjectRef(String ref) {
    return 'Su proyecto de Supabase $ref';
  }

  @override
  String get backendResetDeviceOnly =>
      'Esto cambia solo este dispositivo y nunca toca su proyecto de Supabase.';

  @override
  String get backendSaveNeedsTest =>
      'Pruebe primero la conexión. Solo se puede guardar un servidor verificado.';

  @override
  String get backendScan => 'Escanear un QR de servidor';

  @override
  String get backendScanNothing =>
      'Ese QR no es un código de servidor de DesKilo.';

  @override
  String backendServerCustom(Object host) {
    return 'Tu propio servidor ($host)';
  }

  @override
  String backendServerDefault(Object host) {
    return 'El servidor propio de la app ($host)';
  }

  @override
  String get backendServerHint =>
      'Por defecto la app usa su propio servidor. Si tu comunidad tiene su propio proyecto de Supabase, introdúcelo aquí — la app guardará todo allí.';

  @override
  String get backendServerInUse => 'En uso en este dispositivo';

  @override
  String get backendServerReset => 'Usar el servidor de la app';

  @override
  String get backendServerRestartHint =>
      'La app cierra tu sesión y aplica el cambio en el próximo inicio.';

  @override
  String get backendServerSaved =>
      'Guardado. Cierra y vuelve a abrir la app para usar el nuevo servidor.';

  @override
  String get backendServerTitle => 'Servidor';

  @override
  String get backendShare => 'Compartir este servidor';

  @override
  String get backendShareHint =>
      'Los miembros lo escanean en Ajustes → Servidor para apuntar su app a la misma instancia.';

  @override
  String get backendStep1 =>
      'Crea un proyecto en supabase.com (el plan gratuito basta para empezar).';

  @override
  String get backendStep2 =>
      'Instala el esquema de la app: ejecuta los archivos SQL de supabase/migrations del repositorio fuente, en orden.';

  @override
  String get backendStep3 =>
      'En el panel de Supabase, abre Project Settings → API keys y copia la Project URL y la clave publicable.';

  @override
  String get backendStep4 =>
      'Pégalos abajo, prueba la conexión y guarda. Los miembros se unen a la misma instancia escaneando el QR de arriba.';

  @override
  String get backendTest => 'Probar la conexión';

  @override
  String get backendTestAhead =>
      'Conectado. Su esquema es más reciente que esta aplicación: funciona, y hay una aplicación más reciente disponible.';

  @override
  String get backendTestAttention =>
      'Se alcanzó, pero la respuesta no pudo clasificarse. Revise el servidor antes de usarlo.';

  @override
  String get backendTestBadKey =>
      'Contactado, pero la clave fue rechazada. Copia de nuevo la clave publicable desde Project Settings → API keys.';

  @override
  String get backendTestBehind =>
      'Conectado, pero su esquema de DesKilo es más antiguo de lo que necesita esta aplicación. Actualice el servidor antes de usarlo.';

  @override
  String get backendTestOk => 'Contactado: el esquema de la app está ahí.';

  @override
  String get backendTestSchemaMissing =>
      'Contactado, pero faltan las tablas de DesKilo: ejecuta antes las migraciones de supabase/migrations en ese proyecto.';

  @override
  String get backendTestUnreachable =>
      'No se pudo contactar esa dirección. Revisa la URL y tu red.';

  @override
  String get backendTesting => 'Probando…';

  @override
  String get backendUrlLabel => 'URL del proyecto';

  @override
  String get backendVersionAhead =>
      'El servidor es más reciente que esta app: actualice la app cuando pueda';

  @override
  String backendVersionBehind(int version) {
    return 'Necesita una actualización: esta app necesita el esquema $version';
  }

  @override
  String get backendVersionBehindHow =>
      'Su propietario lo actualiza con el asistente de instalación o `dart run tool/instance.dart install`, que aplica solo lo que falta.';

  @override
  String backendVersionCurrent(int version) {
    return 'Actualizado (esquema $version)';
  }

  @override
  String get backendVersionShortAhead => 'más reciente';

  @override
  String get backendVersionShortBehind => 'más antigua';

  @override
  String get backendVersionShortCurrent => 'actual';

  @override
  String get backendVersionUnknown =>
      'No se pudo comprobar la versión en este momento';

  @override
  String get badgeAuthEnabledHint =>
      'Desactivado por defecto: una credencial que le registra la entrada no inicia su sesión hasta que usted lo decida.';

  @override
  String get badgeAuthEnabledLabel => 'Inicia mi sesión';

  @override
  String get badgeAuthNeedsPin =>
      'Defina primero un PIN de acceso — una credencial sola nunca debe bastar.';

  @override
  String get badgeCardAlreadyRegistered => 'Esa tarjeta ya está registrada.';

  @override
  String get badgeCardRegistered => 'Tarjeta registrada.';

  @override
  String get badgeDefaultLabel => 'Credencial';

  @override
  String get badgeDeleteConfirm =>
      '¿Eliminar definitivamente esta credencial revocada?';

  @override
  String get badgeIssue => 'Nueva credencial';

  @override
  String badgeIssuedOn(String date) {
    return 'Emitido el $date';
  }

  @override
  String get badgeNone => 'Aún no hay credenciales.';

  @override
  String get badgePinChangeAction => 'Cambiar el PIN';

  @override
  String get badgePinClearAction => 'Eliminar el PIN';

  @override
  String get badgePinCleared =>
      'PIN eliminado. Sus credenciales ya no inician su sesión.';

  @override
  String get badgePinConfirmLabel => 'Repítalo';

  @override
  String get badgePinExplain =>
      'Su PIN le permite iniciar sesión escaneando su credencial en lugar de escribir su correo. Solo usted puede definirlo, y nadie — ni siquiera un propietario — puede leerlo.';

  @override
  String get badgePinMismatch => 'Las dos entradas no coinciden.';

  @override
  String get badgePinNewLabel => 'Nuevo PIN';

  @override
  String get badgePinNotSet => 'Sin PIN todavía';

  @override
  String get badgePinSaveFailed =>
      'No se pudo contactar con el servidor. Tu PIN no ha cambiado: inténtalo de nuevo.';

  @override
  String get badgePinSaved => 'PIN guardado.';

  @override
  String get badgePinSectionTitle => 'Mi PIN';

  @override
  String get badgePinSet => 'PIN definido';

  @override
  String get badgePinSetAction => 'Definir un PIN';

  @override
  String badgePinTooShort(int min) {
    return 'Use al menos $min dígitos.';
  }

  @override
  String get badgeRegisterCard => 'Registrar tarjeta';

  @override
  String get badgeRevoke => 'Revocar';

  @override
  String get badgeRevoked => 'Revocada';

  @override
  String get badgeSavePdf => 'Guardar como PDF';

  @override
  String get badgeSignInButton => 'Iniciar sesión';

  @override
  String get badgeSignInEntry => 'Iniciar sesión con una credencial';

  @override
  String badgeSignInHello(String name) {
    return 'Hola $name';
  }

  @override
  String get badgeSignInLocked =>
      'Demasiados intentos. Espere unos minutos, o inicie sesión con su correo.';

  @override
  String get badgeSignInNoReader =>
      'No hay lector de credenciales en este dispositivo.';

  @override
  String get badgeSignInPinLabel => 'Su PIN';

  @override
  String get badgeSignInRefused =>
      'No ha funcionado. Compruebe la credencial y el PIN, o inicie sesión con su correo.';

  @override
  String get badgeSignInRetry => 'Reintentar';

  @override
  String get badgeSignInTapPrompt => 'Acerque su credencial al teléfono.';

  @override
  String get badgeSignInTitle => 'Iniciar sesión con la credencial';

  @override
  String get badgeSignInUnavailable =>
      'El inicio con credencial no está disponible ahora. Inicie sesión con su correo.';

  @override
  String get badgeSignInUseEmail => 'Usar mi correo en su lugar';

  @override
  String get badgeTapCardHint =>
      'Acerca la tarjeta RFID/NFC a la parte trasera del dispositivo.';

  @override
  String get badgeTapCardTitle => 'Registrar una tarjeta';

  @override
  String get badgeTokenOnce =>
      'Guarda este QR ahora — solo se muestra una vez.';

  @override
  String get baseRoleNote =>
      'Cada persona tiene exactamente un rol base: Usuario, Administrador, Copropietario o Propietario. Los demás roles se suman; ninguno quita nada.';

  @override
  String get baseRoleUser => 'Usuario';

  @override
  String get biAreaCapacity => 'Espacios y capacidad';

  @override
  String get biAreaFinance => 'Finanzas';

  @override
  String get biAreaOperations => 'Operaciones';

  @override
  String get biAreaOverview => 'Resumen';

  @override
  String get biAreaPeople => 'Personas y negocio';

  @override
  String get biAreaPlanning => 'Planificación';

  @override
  String get biAreaSaved => 'Análisis guardados';

  @override
  String get biAreaTreasury => 'Tesorería';

  @override
  String get biBookingBasis =>
      'La capacidad reservada mide reservas, no la asistencia real.';

  @override
  String get biCardDown => 'Bajar';

  @override
  String get biCardUp => 'Subir';

  @override
  String get biCards => 'Análisis mostrados';

  @override
  String biCardsUnavailable(String count) {
    return '$count análisis de esta vista no están disponibles para usted y se omiten.';
  }

  @override
  String biChangePoints(String value) {
    return '$value p. p.';
  }

  @override
  String get biCollectionCentre => 'de lo facturado';

  @override
  String get biCollectionCollected => 'Cobrado';

  @override
  String get biCollectionNoComposition =>
      'Los importes cobrados incluyen facturas anteriores, por lo que no son una parte del total facturado del periodo.';

  @override
  String get biCollectionOutstanding => 'Pendiente de cobro';

  @override
  String get biColumnChange => 'Variación';

  @override
  String get biColumnValue => 'Valor';

  @override
  String get biCompare => 'Comparar con';

  @override
  String get biCompareCustom => 'Un periodo que elijo';

  @override
  String get biCompareNone => 'Nada';

  @override
  String get biComparePrevious => 'El periodo anterior';

  @override
  String get biComparePreviousYear => 'El mismo periodo un año antes';

  @override
  String get biCompareTitle => 'Comparado con el pasado';

  @override
  String biComparedLine(String period, String value, String change) {
    return '$period: $value ($change)';
  }

  @override
  String biComparedNotRecorded(String period, String since) {
    return '$period no se registró (el historial empieza el $since); no hay comparación.';
  }

  @override
  String biComparedPartial(String period) {
    return '$period solo está registrado en parte.';
  }

  @override
  String get biComparisonUnqualified =>
      'Cambio no disponible: un periodo contiene datos parciales o desactualizados.';

  @override
  String get biCompositionTitle => 'De qué se compone';

  @override
  String biComputedWorkspaceTime(String date) {
    return 'Calculado el $date · hora del espacio';
  }

  @override
  String get biCurrentBasis =>
      'Se incluye el periodo completo. La comparación con un periodo terminado no tiene una base equivalente.';

  @override
  String get biDataNotApplicable => 'Sin capacidad aplicable';

  @override
  String get biDataNotRecorded => 'No registrado';

  @override
  String get biDataPartial => 'Datos parciales';

  @override
  String get biDataStale => 'Datos desactualizados';

  @override
  String get biDataUnavailable => 'No disponible';

  @override
  String get biDeltaNone => 'Aún sin comparación';

  @override
  String get biDimensionLevel => 'Planta';

  @override
  String get biEvolutionTitle => 'Evolución';

  @override
  String get biExportPdf => 'Exportar a PDF';

  @override
  String get biExposureDiffers =>
      'Los dos periodos no ofrecen la misma base; la tasa lo tiene en cuenta, las cifras brutas no se comparan directamente.';

  @override
  String get biFinanceCollected => 'Cobrado';

  @override
  String biFinanceCollectedBasis(String count) {
    return 'De $count pagos conciliados con facturas';
  }

  @override
  String get biFinanceCollectedDefinition =>
      'Pagos conciliados con facturas, según el mes de la conciliación en la hora del espacio.';

  @override
  String get biFinanceCollectedZero => 'Medido: no se cobró nada.';

  @override
  String biFinanceComputed(String date) {
    return 'Calculado el $date';
  }

  @override
  String get biFinanceCurrencyMix =>
      'Este periodo contiene importes en otra moneda; monedas distintas no se suman, así que no se muestra ninguno.';

  @override
  String get biFinanceInvoiced => 'Facturado';

  @override
  String biFinanceInvoicedBasis(String count, String credit) {
    return 'De $count facturas; abonos $credit, mostrados aparte';
  }

  @override
  String get biFinanceInvoicedDefinition =>
      'Facturas de estos meses, sin las anuladas ni las liquidaciones (una liquidación agrupa facturas ya contadas); solo totales positivos.';

  @override
  String get biFinanceInvoicedZero => 'Medido: no se facturó nada.';

  @override
  String biFinanceLastChange(String date) {
    return 'Último cambio en la fuente: $date';
  }

  @override
  String get biFinanceNotExact =>
      'Un importe es demasiado grande para mostrarlo con exactitud, así que no se muestra.';

  @override
  String get biFinanceNotProfit =>
      'No es un beneficio: esta cifra no incluye costes y las dos cifras no se restan entre sí.';

  @override
  String get biFinancePartial =>
      'El periodo no ha terminado: estas cifras aún cambiarán.';

  @override
  String get biFinanceSameAsReport =>
      'Las mismas reglas que el informe de estado del espacio, calculadas una vez en el servidor.';

  @override
  String get biForbidden => 'No puede leer este análisis en este espacio.';

  @override
  String get biFutureBasis =>
      'Reservas existentes y horarios actuales; no es una previsión de demanda ni un uso garantizado.';

  @override
  String get biGrain => 'Duración del periodo';

  @override
  String get biGrainMonth => 'Mes';

  @override
  String get biGrainQuarter => 'Trimestre';

  @override
  String get biGrainYear => 'Año';

  @override
  String get biGroupBy => 'Agrupar por';

  @override
  String get biGroupNone => 'Sin agrupar';

  @override
  String get biInvalidAddress =>
      'Esta dirección pide un análisis que no existe; no se ha leído nada.';

  @override
  String get biKindCurrent => 'Ahora';

  @override
  String get biKindPrevious => 'Periodo anterior';

  @override
  String get biKindYearAgo => 'Mismo periodo del año pasado';

  @override
  String biNarrativeDown(String label, String change) {
    return 'Más bajo que $label ($change).';
  }

  @override
  String biNarrativeFlat(String label) {
    return 'Más o menos igual que $label.';
  }

  @override
  String biNarrativeUp(String label, String change) {
    return 'Más alto que $label ($change).';
  }

  @override
  String get biNoDataLabel => 'sin datos';

  @override
  String get biNotOffered => 'no lo ofrecen los análisis mostrados';

  @override
  String get biOnPace => 'al ritmo actual';

  @override
  String get biOpenSource => 'Abrir la fuente';

  @override
  String get biPastBasis =>
      'Recalculado con los datos disponibles hoy, no con los conocidos entonces.';

  @override
  String get biPdfEstimateNote =>
      'Las líneas discontinuas y las bandas sombreadas son estimaciones de periodos pasados, no mediciones.';

  @override
  String get biPdfFailed => 'No se pudo crear el PDF.';

  @override
  String biPdfProduced(String date) {
    return 'Elaborado el $date';
  }

  @override
  String get biPdfTitle => 'Análisis de actividad';

  @override
  String biProjectionBasis(int count) {
    return 'Una recta trazada sobre los últimos $count periodos completos, prolongada. La banda sombreada es el rango probable. Una estimación, no una promesa.';
  }

  @override
  String get biProjectionLabel => 'Estimación';

  @override
  String biProjectionNotEnough(int have, int need) {
    return 'Aún no hay historial suficiente para proyectar: $have periodos completos hasta ahora, se necesitan $need.';
  }

  @override
  String get biProjectionTitle => 'Hacia dónde va';

  @override
  String get biProvisionalNote =>
      'Provisional: el periodo no ha terminado, este cambio es una estimación.';

  @override
  String biQuarter(String quarter, String year) {
    return 'T$quarter $year';
  }

  @override
  String get biRecordedFuture => 'Periodo futuro · reservas registradas';

  @override
  String get biRecordedPast => 'Periodo pasado · datos actuales';

  @override
  String get biRecordedPresent => 'Periodo en curso · incluye fechas futuras';

  @override
  String get biRefresh => 'Actualizar datos';

  @override
  String biRefusedBudget(String count) {
    return 'Hay más de $count grupos; elija «Sin agrupar».';
  }

  @override
  String get biRefusedComparison =>
      'Este análisis no puede hacer esa comparación.';

  @override
  String get biRefusedGrain =>
      'Este análisis no se ofrece para esa duración de periodo.';

  @override
  String get biRefusedGrouping => 'Este análisis no se puede agrupar así.';

  @override
  String get biRemainder => 'Fuera de los grupos actuales';

  @override
  String get biReset => 'Mostrar la vista estándar';

  @override
  String biRunRate(String value) {
    return 'Al ritmo actual, este periodo terminaría en torno a $value.';
  }

  @override
  String get biRunningLabel => 'en curso';

  @override
  String get biSeatCentre => 'del tiempo total de puestos';

  @override
  String get biSeatClosed => 'Fuera del horario de apertura';

  @override
  String get biSeatFree => 'Libre en horario de apertura';

  @override
  String biSeatHoursBlocked(String hours) {
    return '$hours horas-asiento bloqueadas';
  }

  @override
  String biSeatHoursFree(String hours) {
    return '$hours horas-asiento sin reservar';
  }

  @override
  String get biSeatReserved => 'Reservado';

  @override
  String get biShareByLevel => 'Tiempo reservado por planta';

  @override
  String get biSort => 'Orden';

  @override
  String get biSortAscending => 'Menor primero';

  @override
  String get biSortDescending => 'Mayor primero';

  @override
  String get biSortNatural => 'Como en la lista';

  @override
  String get biSortUngrouped => 'Orden (solo grupos)';

  @override
  String get biSourceRestricted =>
      'Los registros de origen solo los ven quienes los gestionan.';

  @override
  String get biTitle => 'Análisis de negocio';

  @override
  String get biTotal => 'Total';

  @override
  String get biUnavailable => 'No se pudo calcular este análisis.';

  @override
  String get biViewChart => 'Gráfico';

  @override
  String get biViewClearMyDefault => 'Dejar de abrir mi vista por defecto';

  @override
  String get biViewClearTeamDefault => 'Quitar la vista por defecto del equipo';

  @override
  String biViewCopyName(String name) {
    return '$name (copia)';
  }

  @override
  String get biViewDashboard => 'Panel';

  @override
  String get biViewDelete => 'Eliminar';

  @override
  String biViewDeleteConfirm(String name) {
    return '¿Eliminar la vista «$name»?';
  }

  @override
  String get biViewDuplicate => 'Duplicar como mi vista';

  @override
  String get biViewForbidden => 'No puede cambiar esta vista.';

  @override
  String get biViewInvalid => 'Este nombre o vista no se puede guardar.';

  @override
  String get biViewMakeMyDefault => 'Abrir esta vista por defecto';

  @override
  String get biViewMakeTeamDefault =>
      'Convertirla en la vista por defecto del equipo';

  @override
  String get biViewModified => 'modificada desde que se abrió';

  @override
  String get biViewName => 'Nombre';

  @override
  String get biViewNameTaken => 'Ya existe una vista con este nombre.';

  @override
  String biViewPeriodFixed(String period) {
    return 'Siempre $period';
  }

  @override
  String get biViewPeriodMoves => 'El periodo sigue al día en que se abre';

  @override
  String get biViewRename => 'Cambiar nombre…';

  @override
  String get biViewSave => 'Guardar';

  @override
  String get biViewSaveAs => 'Guardar como vista nueva…';

  @override
  String get biViewScopePrivate => 'Solo yo';

  @override
  String get biViewScopeTeam => 'El equipo';

  @override
  String get biViewStale =>
      'Alguien guardó esta vista desde que la abrió. La lista se ha vuelto a leer; inténtelo de nuevo.';

  @override
  String get biViewStandard => 'Vista estándar';

  @override
  String get biViewTable => 'Tabla';

  @override
  String get biViewUnreadable =>
      'Esta vista no se puede abrir aquí: se guardó en una forma que esta versión no lee, o ninguno de sus análisis está disponible para usted.';

  @override
  String get biViews => 'Vistas';

  @override
  String get biViewsMine => 'Mis vistas';

  @override
  String get biViewsTeam => 'Vistas del equipo';

  @override
  String get biVsPrevious => 'vs periodo anterior';

  @override
  String get biVsYearAgo => 'vs año pasado';

  @override
  String get billAccessorySupplements => 'Suplementos de accesorios';

  @override
  String get billBalance => 'Saldo';

  @override
  String billCreditNoteCard(String number) {
    return 'Nota de crédito $number';
  }

  @override
  String get billCreditNoteDue =>
      'El espacio te debe este importe: no tienes nada que pagar.';

  @override
  String get billCreditNoteRefunded =>
      'El espacio te ha reembolsado este importe.';

  @override
  String billEntitlement(int used, int included, int openDays) {
    return '$used de $included medias jornadas facturadas ($openDays días de apertura)';
  }

  @override
  String billInvoiceCard(String number) {
    return 'Factura $number';
  }

  @override
  String get billInvoicePaid => 'Pagado hasta ahora';

  @override
  String get billInvoiceRemaining => 'Pendiente de pago';

  @override
  String get billInvoiceTotal => 'Total de la factura';

  @override
  String get billOpenPositions => 'Partidas pendientes';

  @override
  String get billOutstanding => 'Pendiente';

  @override
  String billOverage(int extra) {
    return '$extra medias jornadas extra';
  }

  @override
  String get billPackages => 'Paquetes de días';

  @override
  String billParticipation(int pct) {
    return 'Participación $pct %';
  }

  @override
  String billParticipationMonth(String month, int pct) {
    return '$month $pct %';
  }

  @override
  String get billPaymentsCredits => 'Pagos y créditos';

  @override
  String get billPdfExport => 'Exportar la factura como PDF';

  @override
  String get billPdfTitle => 'Factura mensual';

  @override
  String get billPendingBadge => 'pendiente de validación';

  @override
  String get billServices => 'Servicios consumidos';

  @override
  String get billServicesTotal => 'Total de servicios';

  @override
  String get billSettled => 'Al día';

  @override
  String billSubscription(int pct) {
    return 'Suscripción $pct %';
  }

  @override
  String billSubscriptionMonth(String month, int pct) {
    return 'Suscripción $month $pct %';
  }

  @override
  String get billingAddBand => 'Añadir tramo';

  @override
  String get billingAddLevel => 'Añadir nivel';

  @override
  String get billingAddPackage => 'Añadir paquete';

  @override
  String get billingAdvanceDays => 'Días antes de que empiece el mes';

  @override
  String get billingAllowCustom => 'Permitir un valor personalizado negociado';

  @override
  String get billingBandFee => 'Cuota mensual';

  @override
  String billingBandFrom(int from) {
    return 'desde $from %';
  }

  @override
  String get billingBandOverage => 'Exceso';

  @override
  String get billingBandTo => 'Hasta %';

  @override
  String get billingBandsInvalid =>
      'Los tramos deben ser crecientes y terminar en 100 %.';

  @override
  String get billingFeeBands => 'Tramos de tarifas';

  @override
  String get billingLevelValue => 'Nivel (1–100)';

  @override
  String get billingLevels => 'Niveles de suscripción';

  @override
  String get billingNewPackage => 'Nuevo bono';

  @override
  String get billingPackageDays => 'Días';

  @override
  String get billingPackageName => 'Nombre';

  @override
  String get billingPackagePrice => 'Precio';

  @override
  String billingPackageSummary(int days, String price) {
    return '$days días · $price';
  }

  @override
  String get billingPackages => 'Paquetes de días';

  @override
  String get billingPackagesHint =>
      'Los miembros con plan de paquetes los compran cuando se les acaban los días.';

  @override
  String billingPricesVatHint(String rate) {
    return 'Los precios son brutos — el IVA $rate (tipo por defecto del espacio) está incluido.';
  }

  @override
  String get billingRemoveBand => 'Eliminar tramo';

  @override
  String get billingRulesSaved => 'Calendario de facturación guardado.';

  @override
  String get billingRulesSubtitle =>
      'Cuándo salen las facturas de suscripción y de fin de mes';

  @override
  String get billingRulesTitle => 'Calendario de facturación';

  @override
  String get billingSaved => 'Guardado.';

  @override
  String get billingSubscriptionAuto => 'Emitir automáticamente';

  @override
  String get billingSubscriptionOff =>
      'Activa «Facturas de suscripción» en Funciones para usarlo.';

  @override
  String get billingSubscriptionSection => 'Suscripción, por adelantado';

  @override
  String billingSubscriptionWhen(String day, String month) {
    return 'Emitida el $day para $month';
  }

  @override
  String billingTariffVatHint(String rate) {
    return 'Los precios son con IVA incluido — IVA $rate (tipo de las tarifas).';
  }

  @override
  String get billingTitle => 'Facturación';

  @override
  String get billingUsageAuto => 'Emitir automáticamente';

  @override
  String get billingUsageOff =>
      'Activa «Facturas de fin de mes» en Funciones para usarlo.';

  @override
  String get billingUsageSection => 'El mes recién terminado';

  @override
  String get billingUsageWhenZero => 'También cuando no hay nada que pagar';

  @override
  String get billingUsageWhenZeroHint =>
      'Envía un documento a cero, como confirmación de que la suscripción cubrió todo el mes.';

  @override
  String get blockPersonAction => 'Bloquear a esta persona';

  @override
  String blockPersonConfirm(String name) {
    return '¿Bloquear a $name? Ninguno de los dos verá ni podrá contactar al otro. Puedes deshacerlo en Yo.';
  }

  @override
  String get blockPersonDone => 'Bloqueada.';

  @override
  String get blockedPeopleEmpty => 'No has bloqueado a nadie.';

  @override
  String get blockedPeopleHint =>
      'Una persona bloqueada no puede verte ni escribirte, y tú no puedes verla ni contactarla.';

  @override
  String get blockedPeopleTitle => 'Personas bloqueadas';

  @override
  String get bookAccountCode => 'Código de cuenta';

  @override
  String get bookAccountName => 'Nombre de la cuenta';

  @override
  String get bookAccountPosting => 'Admite asientos';

  @override
  String get bookAuthorityExternal => 'Sistema externo';

  @override
  String get bookAuthorityLocal => 'DesKilo lleva el libro';

  @override
  String get bookAuthorityPre => 'Precontabilidad';

  @override
  String get bookBasisAccrual => 'Criterio de devengo';

  @override
  String get bookBasisCash => 'Criterio de caja';

  @override
  String get bookChartSuggest => 'Añadir las cuentas sugeridas para revisarlas';

  @override
  String bookChartTitle(String site) {
    return 'Plan contable · $site';
  }

  @override
  String get bookCurrency => 'Moneda funcional';

  @override
  String bookEffectiveFrom(String date) {
    return 'Vigente desde el $date';
  }

  @override
  String get bookExternalSystem => 'Sistema que hace fe';

  @override
  String bookFiscalPreview(String label, String start, String end) {
    return 'Ejercicio $label: $start – $end';
  }

  @override
  String get bookFiscalStart => 'El ejercicio empieza el';

  @override
  String get bookIssuer => 'Emisor';

  @override
  String get bookMappingsTitle => 'La cuenta de cada asiento';

  @override
  String get bookProblemCurrency =>
      'Esta moneda no tiene un número de decimales verificado.';

  @override
  String get bookProblemExternal =>
      'Indique el sistema externo que lleva los libros oficiales.';

  @override
  String get bookProblemFiscal =>
      'Un ejercicio empieza un día que tiene todo año (nunca el 29 de febrero).';

  @override
  String bookProblemUnmapped(String roles) {
    return 'Asigne estas cuentas antes de iniciar un libro local: $roles.';
  }

  @override
  String get bookRoleBank => 'Banco';

  @override
  String get bookRoleCustomers => 'Clientes (cuentas por cobrar)';

  @override
  String get bookRoleExpenses => 'Gastos';

  @override
  String get bookRoleRevenue => 'Ingresos';

  @override
  String get bookRoleVatOutput => 'IVA repercutido';

  @override
  String get bookSaveFailed =>
      'El libro no se guardó. Compruebe la conexión e inténtelo de nuevo.';

  @override
  String get bookSaved => 'Libro guardado';

  @override
  String get bookSheetTitle => 'Libro contable';

  @override
  String get bookStale =>
      'Alguien guardó este libro desde que lo abrió. Cierre y vuelva a abrir para ver su versión.';

  @override
  String get bookTileEmpty =>
      'Sin libro: DesKilo lleva los saldos de los miembros y las facturas (precontabilidad).';

  @override
  String get bookTypeAsset => 'Activo';

  @override
  String get bookTypeEquity => 'Patrimonio neto';

  @override
  String get bookTypeExpense => 'Gasto';

  @override
  String get bookTypeIncome => 'Ingreso';

  @override
  String get bookTypeLiability => 'Pasivo';

  @override
  String bookingCheckedInAtUntil(String space, String until) {
    return 'Registrado en $space hasta las $until.';
  }

  @override
  String get bookingCheckedInElsewhere =>
      'Estás registrado en otro sitio — haz la salida allí primero.';

  @override
  String bookingCheckedInUntil(String until) {
    return 'Registrado hasta las $until.';
  }

  @override
  String get bookingGateBlocked => 'No reservable así';

  @override
  String bookingHorizonError(int days) {
    return 'Demasiado lejos — las reservas se abren con $days días de antelación.';
  }

  @override
  String get bookingMembershipPaused =>
      'Su afiliación está en pausa — un administrador la reactiva en Miembros.';

  @override
  String get bookingModeCheckInNow => 'Registrarse ahora';

  @override
  String get bookingMoreOptions => 'Más opciones';

  @override
  String get bookingNoLongerCheckedIn =>
      'Esta reserva ya no está registrada — se cerró mientras tanto.';

  @override
  String get bookingNotAMember =>
      'Ya no es miembro de este espacio — pida una invitación a un administrador.';

  @override
  String get bookingOnePlace =>
      'Ya tienes una reserva en ese periodo — un sitio a la vez.';

  @override
  String get bookingOpenDetails => 'Detalles';

  @override
  String get bookingOutsideHoursError =>
      'Las reservas deben permanecer dentro del horario laboral.';

  @override
  String get bookingOutsideOffError =>
      'Las reservas fuera del horario de apertura no están permitidas.';

  @override
  String get bookingOutsideWalkUpError =>
      'Fuera del horario de apertura solo es posible un check-in espontáneo, no una reserva por adelantado.';

  @override
  String get bookingOverlapsAnother =>
      'El puesto ya está reservado durante parte de este tiempo.';

  @override
  String get bookingPastError =>
      'Esta reserva está completamente en el pasado.';

  @override
  String bookingRecordedPastSpaceWhen(String space, String when) {
    return '$space registrado: $when. Ese periodo ya ha terminado, así que se conserva como una visita pasada.';
  }

  @override
  String bookingRecordedPastWhen(String when) {
    return 'Registrado: $when. Ese periodo ya ha terminado, así que se conserva como una visita pasada.';
  }

  @override
  String get bookingRecoveryBanner =>
      'Una de sus solicitudes de reserva sigue sin respuesta.';

  @override
  String get bookingRecoveryBannerAction => 'Comprobar';

  @override
  String get bookingRecoveryCheck => 'Comprobar el resultado';

  @override
  String get bookingRecoveryCommitted =>
      'La reserva existe: exactamente una, de su solicitud original.';

  @override
  String get bookingRecoveryDiscard => 'Descartar';

  @override
  String get bookingRecoveryInProgress =>
      'El servidor sigue procesando esta solicitud. Compruébelo de nuevo en un momento.';

  @override
  String get bookingRecoveryNotCommitted =>
      'No se reservó nada para esta solicitud. Puede reanudarla tal cual o descartarla.';

  @override
  String get bookingRecoveryNotSaved =>
      'Este dispositivo no pudo guardar su solicitud de reserva, así que no se envió nada. Libere espacio o inténtelo de nuevo.';

  @override
  String get bookingRecoveryResume => 'Reanudar la misma solicitud';

  @override
  String get bookingRecoveryResumed =>
      'Reanudada: su solicitud original se reservó una sola vez.';

  @override
  String get bookingRecoverySpaceFallback => 'El espacio elegido';

  @override
  String get bookingRecoveryTitle => 'Su solicitud de reserva';

  @override
  String get bookingRecoveryUnavailable =>
      'No se pudo consultar al servidor. Nada cambió; inténtelo de nuevo.';

  @override
  String get bookingRecoveryUnknown =>
      'La conexión se cortó después de enviar su solicitud. La reserva puede existir o no: compruébelo antes de reservar de nuevo.';

  @override
  String get bookingRecoveryUnresolved =>
      'El servidor ya no guarda registro de esta solicitud y no puede decirlo. Revise sus reservas antes de reservar de nuevo.';

  @override
  String get bookingRecoveryView => 'Ver la reserva';

  @override
  String bookingRecoveryWindow(String space, String from, String to) {
    return '$space · $from – $to';
  }

  @override
  String bookingReservedSpaceWhen(String space, String when) {
    return '$space reservado: $when.';
  }

  @override
  String bookingReservedWhen(String when) {
    return 'Reservado: $when.';
  }

  @override
  String get bookingSameDayError =>
      'Una reserva termina el día en que empieza: reserva el día siguiente por separado.';

  @override
  String get bookingSpaceChainTaken =>
      'Este espacio, o un espacio que lo contiene, ya está reservado en ese periodo.';

  @override
  String bookingTooLongError(int minutes) {
    return 'Demasiado larga — una reserva dura como máximo $minutes minutos.';
  }

  @override
  String bookingTooShortError(int minutes) {
    return 'Demasiado corta — una reserva dura al menos $minutes minutos.';
  }

  @override
  String get bookingWalkUpTodayError =>
      'Un check-in espontáneo debe empezar hoy.';

  @override
  String get bootFailedBody =>
      'El servidor o el almacenamiento seguro de este dispositivo no respondió. No se cambió nada. Cierre la aplicación y vuelva a abrirla; si sigue ocurriendo, compruebe la red.';

  @override
  String get bootFailedTitle => 'DesKilo no pudo iniciarse';

  @override
  String get bootSlowBody =>
      'Sigue intentándolo. Si no ocurre nada, cierre la aplicación y vuelva a abrirla.';

  @override
  String get bootSlowTitle => 'El inicio tarda más de lo habitual';

  @override
  String brandColorRefused(String color, String pair) {
    return 'El color $color no se aplicó: $pair sería ilegible.';
  }

  @override
  String get buyPackageButton => 'Comprar un paquete';

  @override
  String buyPackageDays(int days) {
    return '$days días';
  }

  @override
  String get buyPackageDone => 'Días añadidos — disfruta del tiempo extra.';

  @override
  String get buyPackageNone => 'Aún no hay paquetes disponibles.';

  @override
  String get buyPackageTitle => 'Comprar un paquete';

  @override
  String calendarAgendaEmpty(int days) {
    return 'Nada previsto en los próximos $days días.';
  }

  @override
  String calendarAgendaRange(int days) {
    return 'Próximos $days días';
  }

  @override
  String get calendarAllLevels => 'Todas las plantas';

  @override
  String get calendarCancelFollowing => 'Cancelar esta y las siguientes';

  @override
  String get calendarCancelOccurrence => 'Cancelar esta ocurrencia';

  @override
  String get calendarClosedDay => 'Cerrado';

  @override
  String calendarClosedDayReason(String reason) {
    return 'Cerrado — $reason';
  }

  @override
  String get calendarDay => 'Día';

  @override
  String get calendarDayEmpty => 'Nada ese día.';

  @override
  String calendarDueTitle(String number) {
    return 'Pago vence · $number';
  }

  @override
  String get calendarEventActionApproved => 'aprobada';

  @override
  String get calendarEventActionCancelled => 'cancelada';

  @override
  String get calendarEventActionCreated => 'creada';

  @override
  String get calendarEventActionModified => 'modificada';

  @override
  String get calendarEventActionRefused => 'rechazado';

  @override
  String get calendarEventActionRejected => 'rechazada';

  @override
  String get calendarEventActionSubmitted => 'enviada';

  @override
  String get calendarEventActionValidated => 'validado';

  @override
  String get calendarEventStatusExpired => 'caducado';

  @override
  String get calendarEventStatusPending => 'pendiente de confirmación';

  @override
  String get calendarEventStatusRejected => 'rechazado';

  @override
  String calendarEventTitle(String label) {
    return 'Aviso: $label';
  }

  @override
  String get calendarEveryoneTab => 'Todos';

  @override
  String get calendarGroupActivity => 'Alertas y mensajes';

  @override
  String get calendarGroupBookings => 'Reservas y presencia';

  @override
  String get calendarGroupMoney => 'Finanzas';

  @override
  String calendarItemCount(int count) {
    return '$count elementos';
  }

  @override
  String get calendarKindCheckIn => 'Registros';

  @override
  String get calendarKindCheckOut => 'Salidas';

  @override
  String get calendarKindConsumption => 'Consumos';

  @override
  String get calendarKindDue => 'Pagos por vencer';

  @override
  String get calendarKindEvent => 'Avisos';

  @override
  String get calendarKindInvoice => 'Facturas';

  @override
  String get calendarKindMessage => 'Mensajes';

  @override
  String get calendarKindPayment => 'Pagos';

  @override
  String get calendarKindReminder => 'Recordatorios';

  @override
  String get calendarKindReservation => 'Reservas';

  @override
  String get calendarKindScheduled => 'Gastos programados';

  @override
  String get calendarKindValidation => 'Validaciones';

  @override
  String calendarLevelCollapsed(String level) {
    return '$level, contraído';
  }

  @override
  String calendarLevelExpanded(String level) {
    return '$level, expandido';
  }

  @override
  String get calendarListView => 'Vista de lista';

  @override
  String calendarLockedKinds(String kinds) {
    return 'No visible para usted para este miembro: $kinds';
  }

  @override
  String get calendarMemberMe => 'Yo';

  @override
  String get calendarMineTab => 'Mías';

  @override
  String get calendarNext => 'Siguiente';

  @override
  String get calendarNextMonth => 'Mes siguiente';

  @override
  String get calendarNoReservations => 'No hay reservas ese día.';

  @override
  String get calendarNothingHere => 'Nada en estas fechas.';

  @override
  String get calendarPrevious => 'Anterior';

  @override
  String get calendarPreviousMonth => 'Mes anterior';

  @override
  String get calendarRange => 'Periodo';

  @override
  String get calendarReservationActions => 'Acciones de la reserva';

  @override
  String calendarScheduledTitle(String name) {
    return 'Gasto programado · $name';
  }

  @override
  String get calendarShowOnPlan => 'Ver en el plano';

  @override
  String get calendarTimelineAllEmpty =>
      'No hay reservas en ninguna planta ese día.';

  @override
  String get calendarTimelineEmpty => 'No hay reservas en esta planta ese día.';

  @override
  String get calendarTimelineView => 'Vista de cronología';

  @override
  String get calendarToday => 'Hoy';

  @override
  String get calendarTomorrow => 'Mañana';

  @override
  String calendarValidationRefused(String what) {
    return 'Rechazado: $what';
  }

  @override
  String calendarValidationValidated(String what) {
    return 'Validado: $what';
  }

  @override
  String get calendarViewAgenda => 'Agenda';

  @override
  String get calendarViewAlerts => 'Avisos';

  @override
  String get calendarViewMonth => 'Mes';

  @override
  String get calendarViewWeek => 'Semana';

  @override
  String get calendarWeekEmpty => 'Nada esta semana.';

  @override
  String get calendarWhoCanSee => 'Quién puede ver esto';

  @override
  String get calendarYesterday => 'Ayer';

  @override
  String get capabilityBrowserPrefer => 'Preferir';

  @override
  String get capabilityBrowserRequire => 'Exigir';

  @override
  String get capabilityBrowserTitle => 'Explorar funciones';

  @override
  String get capabilityCreditPacks => 'Bonos';

  @override
  String get capabilityCustomMemberForm => 'Formulario de socio personalizado';

  @override
  String get capabilityMultiApproval => 'Dos o más aprobaciones';

  @override
  String get capabilityOpeningHours => 'Horario de apertura';

  @override
  String get capabilityPayAsYouGo => 'Pago por uso';

  @override
  String get capabilityRefundApprovals => 'Dos aprobaciones para reembolsos';

  @override
  String get capabilityStateConditional =>
      'Activado solo si sus requisitos lo están';

  @override
  String get capabilityStateDisabled => 'Desactivado';

  @override
  String get capabilityStateEnabled => 'Activado';

  @override
  String get capabilityStateIncompatible => 'No aplicable aquí';

  @override
  String get capabilityStateLocalInput => 'Necesita antes un valor local';

  @override
  String get capabilityStateUnknown => 'Desconocido';

  @override
  String get capabilityStateUnspecified => 'No lo fija esta plantilla';

  @override
  String get capabilitySubscriptionPlans => 'Planes de suscripción';

  @override
  String capacityKpiAsOf(String time) {
    return 'Calculado $time';
  }

  @override
  String get capacityKpiDefinition =>
      'Horas-puesto reservadas dentro del horario de apertura, divididas por las horas-puesto ofrecidas: cada puesto por las horas de apertura de los días abiertos, menos los días de cierre y los bloqueos de puestos. Una mesa, sala o planta completa cuenta cada uno de sus puestos una vez; las reservas canceladas no cuentan.';

  @override
  String get capacityKpiExplain => '¿Cómo se calcula?';

  @override
  String get capacityKpiForbidden =>
      'No puede consultar las cifras de capacidad de este espacio.';

  @override
  String capacityKpiHistory(String date) {
    return 'Historial registrado desde el $date';
  }

  @override
  String capacityKpiHistorySince(String date) {
    return 'Contado desde el $date, cuando empezó el historial de este espacio; el tiempo anterior no se conoce y no se cuenta.';
  }

  @override
  String get capacityKpiKnownZero => 'Medido: no se reservó nada.';

  @override
  String capacityKpiNotRecorded(String date) {
    return 'Este periodo es anterior al inicio del historial del espacio, el $date; no hay nada registrado que contar.';
  }

  @override
  String capacityKpiOutside(String hours) {
    return 'Reservado fuera de las horas ofrecidas: $hours horas-puesto, fuera del ratio';
  }

  @override
  String capacityKpiOverlap(String hours) {
    return 'Reservado dos veces a la vez: $hours horas-puesto, contadas una vez';
  }

  @override
  String capacityKpiPhysical(String hours) {
    return 'Capacidad física: $hours horas-puesto';
  }

  @override
  String capacityKpiRatio(String reserved, String offered) {
    return '$reserved de $offered horas-puesto reservadas';
  }

  @override
  String get capacityKpiRetry => 'Reintentar';

  @override
  String capacityKpiRooms(String count, String reserved, String offered) {
    return 'Salas sin puestos: $count, $reserved de $offered horas-sala reservadas';
  }

  @override
  String get capacityKpiRoomsToday =>
      'Las salas sin puestos se leen tal como están hoy.';

  @override
  String get capacityKpiTitle => 'Ocupación de puestos';

  @override
  String get capacityKpiUnattributed =>
      'Algunas reservas del periodo apuntan a un lugar que ya no existe; no se cuentan.';

  @override
  String get capacityKpiUnavailable =>
      'No se pudo calcular la ocupación de puestos.';

  @override
  String get capacityKpiUndefined =>
      'En este periodo no se ofreció tiempo de puesto, así que no hay ocupación que mostrar.';

  @override
  String get captureRecordingHidden =>
      'Oculto mientras tu pantalla se graba o se duplica.';

  @override
  String get captureWebNotice =>
      'Tu navegador no puede impedir capturas de pantalla de esta conversación.';

  @override
  String get carnetAdd => 'Añadir bono';

  @override
  String carnetBalance(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Quedan $count medias jornadas',
      one: 'Queda 1 media jornada',
      zero: 'No quedan medias jornadas',
    );
    return '$_temp0';
  }

  @override
  String get carnetHalfDays => 'Medias jornadas';

  @override
  String get carnetName => 'Nombre';

  @override
  String get carnetPrice => 'Precio';

  @override
  String get carnetSell => 'Vender un bono';

  @override
  String get carnetSold =>
      'Bono vendido — cobrado una vez en la factura del mes.';

  @override
  String carnetSummary(int halfDays, String price) {
    return '$halfDays medias jornadas · $price';
  }

  @override
  String get carnetValidity => 'Validez (meses, vacío = no caduca)';

  @override
  String get carnetsEmpty => 'Aún no hay bonos.';

  @override
  String get carnetsTitle => 'Bonos';

  @override
  String get coOwnerAction => 'Copropiedad';

  @override
  String get coOwnerActivate => 'Promover a propietario ahora';

  @override
  String get coOwnerActive =>
      'Copropietario activo — permisos de propietario ya, sucesión automática';

  @override
  String get coOwnerNone => 'Sin copropiedad';

  @override
  String get coOwnerPassive =>
      'Sucesor — se convierte en propietario al activarlo o cuando el propietario se va';

  @override
  String coloursApplied(String hex) {
    return '$hex aplicado. La aplicación deriva de él sus temas.';
  }

  @override
  String get coloursDark => 'Oscuro';

  @override
  String get coloursHexHint =>
      'Seis dígitos hexadecimales. Déjelo vacío para los colores del producto.';

  @override
  String get coloursHexLabel => 'Color';

  @override
  String get coloursIntro =>
      'Un color, y la aplicación deriva de él sus temas claro y oscuro. Todo lo demás conserva la paleta del producto.';

  @override
  String get coloursLight => 'Claro';

  @override
  String coloursMalformed(String text) {
    return '$text no es un color: escríbalo como #RRGGBB.';
  }

  @override
  String get coloursNeverTheirs =>
      'La marca DesKilo, los colores de los estados de plaza y el banner de producción son del producto, en todos los espacios.';

  @override
  String get coloursPreview => 'Cómo se ve';

  @override
  String coloursRefused(String pair) {
    return 'Rechazado: $pair sería ilegible con este color.';
  }

  @override
  String get coloursReset => 'Colores del producto';

  @override
  String get coloursResetDone => 'Los colores del producto han vuelto.';

  @override
  String get coloursRooms => 'Colores de las salas';

  @override
  String get coloursRoomsAdd => 'Añadir un color';

  @override
  String coloursRoomsOwn(int n) {
    return '$n colores propios, en este orden.';
  }

  @override
  String get coloursRoomsProduct =>
      'La paleta del producto. Añada un color para usar el suyo.';

  @override
  String coloursRoomsSaved(int n) {
    return '$n colores de salas guardados.';
  }

  @override
  String get coloursSaveFailed =>
      'No se pudo guardar el color. Nada ha cambiado.';

  @override
  String get coloursTitle => 'Colores';

  @override
  String coloursTooMany(int most) {
    return 'El plano pinta como máximo $most colores de salas.';
  }

  @override
  String get comingSoon => 'Próximamente';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonCopy => 'Copiar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonDone => 'Listo';

  @override
  String get commonOk => 'Aceptar';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonSaveFailed => 'No se pudo guardar el archivo.';

  @override
  String commonSavedTo(String path) {
    return 'Guardado en $path';
  }

  @override
  String get commonShare => 'Compartir';

  @override
  String get commonStart => 'Empezar';

  @override
  String get compareAdd => 'Añadir a la comparación';

  @override
  String get compareAll => 'Todos los ajustes';

  @override
  String compareCount(String shown, String total) {
    return '$shown de $total ajustes';
  }

  @override
  String get compareCurrencies => 'Monedas distintas: no comparable';

  @override
  String get compareDefault => 'Predeterminado';

  @override
  String get compareDifferences => 'Diferencias';

  @override
  String get compareEmpty => 'Vacío';

  @override
  String get compareExport => 'Exportar a Excel';

  @override
  String get compareExported => 'Libro guardado.';

  @override
  String get compareInherits => 'Conserva el del espacio';

  @override
  String compareLimit(String count) {
    return 'Se pueden comparar hasta $count plantillas. Quite una primero.';
  }

  @override
  String get compareLocal => 'A definir localmente';

  @override
  String get compareMissing => 'No está en esta plantilla';

  @override
  String get compareNo => 'No';

  @override
  String get compareNotCarried => 'No se transporta';

  @override
  String get compareNothing => 'Ningún ajuste difiere.';

  @override
  String compareOpen(String count) {
    return 'Comparar ($count)';
  }

  @override
  String get compareRemove => 'Quitar de la comparación';

  @override
  String get compareSearch => 'Buscar un ajuste';

  @override
  String get compareTitle => 'Comparar plantillas';

  @override
  String get compareUnavailable =>
      'No se pudieron leer estas plantillas para compararlas. No se afirma nada.';

  @override
  String get compareUnknown => 'Desconocido';

  @override
  String get compareYes => 'Sí';

  @override
  String get composerAttach => 'Adjuntar una referencia';

  @override
  String composerCharsLeft(int count) {
    return '$count caracteres restantes';
  }

  @override
  String get composerDraftKept => 'Borrador guardado';

  @override
  String get composerMention => 'Mencionar a alguien';

  @override
  String get connectionCancelled =>
      'La cuenta cambió entretanto, así que se descartó esta respuesta.';

  @override
  String get connectionChangedIdentity =>
      'Este servidor ya no es el que conectaste. Sus acciones están en pausa hasta que lo verifiques de nuevo.';

  @override
  String get connectionChecking => 'Comprobando…';

  @override
  String get connectionCurrentServer =>
      'Este es el servidor que esta aplicación ya utiliza.';

  @override
  String get connectionDenied =>
      'Este servidor ha rechazado la cuenta. Revisa los datos de acceso o desconéctalo.';

  @override
  String get connectionExpired =>
      'Tu sesión en este servidor ha caducado. Vuelve a iniciar sesión en este servidor.';

  @override
  String get connectionInvalidEndpoint =>
      'Esta dirección o clave no corresponde a un servidor válido.';

  @override
  String get connectionMalformed =>
      'Este servidor ha respondido algo que esta aplicación no puede leer.';

  @override
  String get connectionNotConnected =>
      'Este servidor no está conectado en este dispositivo.';

  @override
  String get connectionRetry => 'Reintentar';

  @override
  String get connectionSessionNotSaved =>
      'La acción se realizó, pero este dispositivo no pudo guardar la sesión del servidor. Puede que tengas que volver a iniciar sesión.';

  @override
  String get connectionSignInAgain => 'Volver a iniciar sesión';

  @override
  String get connectionUnavailable =>
      'Este servidor no responde en este momento. Tus otros servidores no se ven afectados.';

  @override
  String get connectionUnknownOutcome =>
      'La conexión se cortó después de enviar la solicitud. Puede que se haya aplicado: compruébalo antes de volver a intentarlo.';

  @override
  String get connectionUnsupported =>
      'Esta versión del servidor no se puede conectar desde esta aplicación. Actualiza la aplicación o pide al operador del servidor que lo actualice.';

  @override
  String get connectionUsable => 'Conectado';

  @override
  String get connectionVerifyAgain => 'Verificar de nuevo';

  @override
  String get consentAccept => 'Aceptar y continuar';

  @override
  String consentAcceptedOn(String date, String version) {
    return 'Aceptado el $date ($version)';
  }

  @override
  String get consentCheckbox =>
      'He leído esto y acepto cómo DesKilo trata mis datos.';

  @override
  String get consentControllerBody =>
      'Cada espacio lo opera su propietario — tu comunidad —, que decide miembros, precios y proveedores de pago. La app es software libre (AGPL-3.0-or-later) y la publica Florian Dittgen (Alemania); el backend es Supabase en la UE. Los pagos en línea pasan por el proveedor que activó el propietario (PayPal, Stripe, Mollie, Wero) según sus condiciones.';

  @override
  String get consentControllerTitle => 'Quién es responsable';

  @override
  String get consentIntro =>
      'Antes de usar DesKilo, esto es lo que la app hace con tus datos, quién puede verlos y qué puedes hacer al respecto. Dos minutos; no hay más.';

  @override
  String get consentNotBody =>
      'Sin rastreo, sin analítica, sin publicidad, sin venta ni cesión de datos. Las notificaciones push no llevan contenido — solo «tienes un mensaje nuevo»; la propia app escribe el texto. La versión F-Droid no tiene ningún servicio de Google.';

  @override
  String get consentNotTitle => 'Lo que DesKilo nunca hace';

  @override
  String get consentReadInHelp => 'Leer en la ayuda';

  @override
  String get consentReadOnWiki => 'Leer en el wiki';

  @override
  String get consentRetentionBody =>
      'Mientras seas miembro. Cuando te vas y borras, tu perfil y tus mensajes desaparecen; los registros contables (facturas, pagos) se conservan el plazo legal, por identificador y no por nombre.';

  @override
  String get consentRetentionTitle => 'Cuánto tiempo';

  @override
  String get consentReviewBody =>
      'Este texto sigue disponible en Ajustes → Privacidad y datos, en la ayuda de la app (Privacidad) y en el wiki del proyecto. Un cambio del texto vuelve a pedir tu aceptación.';

  @override
  String get consentReviewHint =>
      'El texto que aceptaste, con la fecha — vuelve a leerlo cuando quieras.';

  @override
  String get consentReviewTitle => 'Vuelve a leerlo cuando quieras';

  @override
  String get consentRightsBody =>
      'Acceso, rectificación, exportación (art. 20), supresión (art. 17) y oposición — cada uno es un botón en Ajustes → Privacidad y datos. Para lo demás: fdittgen@gmail.com. Puedes retirar este consentimiento en cualquier momento saliendo del espacio y borrando tus datos.';

  @override
  String get consentRightsTitle => 'Tus derechos';

  @override
  String get consentTitle => 'Tus datos, tus derechos';

  @override
  String get consentUnavailable =>
      'No se pudo cargar tu cuenta, así que todavía no hay nada que aceptar.';

  @override
  String get consentVersion => 'Versión';

  @override
  String get consentWhatBody =>
      'Tu cuenta (e-mail, nombre visible, contraseña cifrada), tu perfil tal como lo rellenas (foto, estado, dirección, número de WhatsApp — cada uno opcional), y lo que haces en un espacio: reservas y registros de entrada, mensajes, gastos y consumos, tu suscripción, facturas y pagos. Todo se guarda en la UE (Supabase, eu-central-1).';

  @override
  String get consentWhatTitle => 'Qué procesa DesKilo';

  @override
  String get consentWhoBody =>
      'El acceso sigue los roles y se aplica en el servidor: las reservas las ve el espacio (el plano muestra la ocupación); los mensajes solo las personas de la conversación, sea cual sea su rol; tus finanzas y tu acuerdo comercial solo tú, los propietarios y los admins con el permiso correspondiente. Ajustes → Privacidad y datos nombra a las personas y lista quién miró realmente.';

  @override
  String get consentWhoTitle => 'Quién puede ver qué';

  @override
  String get consumptionAdd => 'Añadir consumo';

  @override
  String consumptionAddForMember(String name) {
    return 'Añadir servicio para $name';
  }

  @override
  String get consumptionNoServices => 'No hay servicios activos que registrar.';

  @override
  String get consumptionPeriodLabel => 'Período de facturación (AAAA-MM)';

  @override
  String get consumptionQuantity => 'Cantidad';

  @override
  String get consumptionRecorded =>
      'Consumo registrado — pendiente de confirmación.';

  @override
  String get consumptionRefusedInactive =>
      'Este servicio ya no se ofrece. No se registró nada.';

  @override
  String get consumptionRefusedPeriod =>
      'El periodo de facturación debe ser un mes (AAAA-MM). No se registró nada.';

  @override
  String get consumptionRefusedQuantity =>
      'La cantidad debe estar entre 1 y 999. No se registró nada.';

  @override
  String get consumptionRefusedStock =>
      'No queda suficiente stock. No se registró nada.';

  @override
  String get consumptionService => 'Servicio';

  @override
  String get conversationAddPeople => 'Añadir miembros';

  @override
  String get conversationAdmin => 'Admin';

  @override
  String get conversationArchive => 'Archivar';

  @override
  String get conversationArchived => 'Conversación archivada.';

  @override
  String get conversationEmpty => 'Aún no hay mensajes — ¡saluda!';

  @override
  String get conversationGroup => 'Grupo';

  @override
  String get conversationGroupInfo => 'Grupo';

  @override
  String get conversationLeave => 'Salir del grupo';

  @override
  String get conversationLeaveConfirm =>
      '¿Salir de este grupo? Dejará de recibir sus mensajes; lo que ya envió permanece.';

  @override
  String get conversationLeft => 'Salió';

  @override
  String get conversationLoadEarlier => 'Cargar mensajes anteriores';

  @override
  String get conversationMarkUnread => 'Marcar como no leído';

  @override
  String conversationMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count miembros',
      one: '1 miembro',
    );
    return '$_temp0';
  }

  @override
  String get conversationMute => 'Silenciar notificaciones';

  @override
  String get conversationMutedBadge => 'Silenciada';

  @override
  String get conversationPin => 'Fijar arriba';

  @override
  String get conversationRemove => 'Quitar';

  @override
  String get conversationSeeProfile => 'Ver perfil';

  @override
  String get conversationToday => 'Hoy';

  @override
  String get conversationUnarchive => 'Sacar del archivo';

  @override
  String get conversationUnknownMember => 'Miembro';

  @override
  String get conversationUnmute => 'Reactivar notificaciones';

  @override
  String get conversationUnpin => 'Desfijar';

  @override
  String get conversationYesterday => 'Ayer';

  @override
  String get conversationYou => 'Usted';

  @override
  String get countryNameAT => 'Austria';

  @override
  String get countryNameAU => 'Australia';

  @override
  String get countryNameBE => 'Bélgica';

  @override
  String get countryNameBG => 'Bulgaria';

  @override
  String get countryNameCA => 'Canadá';

  @override
  String get countryNameCH => 'Suiza';

  @override
  String get countryNameCY => 'Chipre';

  @override
  String get countryNameCZ => 'Chequia';

  @override
  String get countryNameDE => 'Alemania';

  @override
  String get countryNameDK => 'Dinamarca';

  @override
  String get countryNameEE => 'Estonia';

  @override
  String get countryNameES => 'España';

  @override
  String get countryNameFI => 'Finlandia';

  @override
  String get countryNameFR => 'Francia';

  @override
  String get countryNameGB => 'Reino Unido';

  @override
  String get countryNameGR => 'Grecia';

  @override
  String get countryNameHR => 'Croacia';

  @override
  String get countryNameHU => 'Hungría';

  @override
  String get countryNameIE => 'Irlanda';

  @override
  String get countryNameIT => 'Italia';

  @override
  String get countryNameJP => 'Japón';

  @override
  String get countryNameLT => 'Lituania';

  @override
  String get countryNameLU => 'Luxemburgo';

  @override
  String get countryNameLV => 'Letonia';

  @override
  String get countryNameMT => 'Malta';

  @override
  String get countryNameMX => 'México';

  @override
  String get countryNameNL => 'Países Bajos';

  @override
  String get countryNameNO => 'Noruega';

  @override
  String get countryNamePL => 'Polonia';

  @override
  String get countryNamePT => 'Portugal';

  @override
  String get countryNameRO => 'Rumanía';

  @override
  String get countryNameSE => 'Suecia';

  @override
  String get countryNameSI => 'Eslovenia';

  @override
  String get countryNameSK => 'Eslovaquia';

  @override
  String get countryNameUS => 'Estados Unidos';

  @override
  String get courtesyHint =>
      'Se imprime delante de su nombre en los documentos. «Ninguno» imprime solo el nombre.';

  @override
  String get courtesyHintManaged =>
      'Se imprime delante de su nombre en los documentos. «Ninguno» imprime solo el nombre.';

  @override
  String get courtesyLabel => 'Tratamiento';

  @override
  String get courtesyMr => 'Sr.';

  @override
  String get courtesyMrs => 'Sra.';

  @override
  String get courtesyNone => 'Ninguno';

  @override
  String get customerCapacityBusiness => 'Empresa';

  @override
  String get customerCapacityConsumer => 'Consumidor';

  @override
  String get customerCapacityExplainer =>
      'Si este cliente actúa en el marco de una actividad empresarial o profesional (sociedad, autónomo, asociación que actúa como tal) o como consumidor. Decide qué cláusulas de pago imprime una factura; un número de IVA por sí solo no lo decide. Sin indicar: se aplica el valor por defecto del espacio.';

  @override
  String get customerCapacityLabel => 'Condición del cliente';

  @override
  String get customerCapacityNotStated => 'Sin indicar';

  @override
  String get customerCapacitySaveError =>
      'La condición del cliente no se ha guardado.';

  @override
  String get datevAccountsIntro =>
      'Su asesor le da los números de asesor y de cliente. DATEV rechaza un archivo cuyos números no coincidan — que es lo que evita que acabe en los libros de otra empresa.';

  @override
  String get datevAccountsTitle => 'Exportación DATEV';

  @override
  String get datevClientNumber => 'Mandantennummer (n.º de cliente)';

  @override
  String get datevConsultantNumber => 'Beraternummer (n.º de asesor)';

  @override
  String get decisionSurfaceEmpty => 'Nada te espera';

  @override
  String get decisionSurfaceEmptyDetail => 'Todo está resuelto.';

  @override
  String get defaultPeriodNone => 'Sin preferencia (día completo)';

  @override
  String get defaultPeriodTitle => 'Período de reserva predeterminado';

  @override
  String get demoEntryAction => 'Explorar el espacio de demostración';

  @override
  String get demoEntryBody =>
      'Todo en él es inventado: las personas, las reservas y las facturas se han creado para la demostración. Nada de lo que hagas aquí llega a un espacio real, nada sale de este dispositivo y no hace falta ninguna cuenta. Reiniciar lo deja como estaba cuando quieras.';

  @override
  String get demoEntryStart => 'Empezar';

  @override
  String get demoEntryTitle => 'Un espacio para mirar';

  @override
  String get demoPersonaAdmin => 'Una administradora';

  @override
  String get demoPersonaMember => 'Un miembro';

  @override
  String get demoPersonaOwner => 'La propietaria';

  @override
  String get demoSessionBadge => 'Demo';

  @override
  String get demoSessionBadgeHint =>
      'Estás explorando un espacio de demostración. Nada de esto sale de este dispositivo.';

  @override
  String get demoSessionLeave => 'Salir de la demo';

  @override
  String get demoSessionReset => 'Reiniciar la demo';

  @override
  String get demoSessionResetDone => 'La demo ha vuelto a su estado inicial.';

  @override
  String get demoSessionViewAs => 'Ver como';

  @override
  String get deployEntityAccessories => 'Accesorios';

  @override
  String get deployEntityBookingRules => 'Reglas de reserva';

  @override
  String get deployEntityBranding => 'Colores';

  @override
  String get deployEntityClosureDays => 'Días de cierre';

  @override
  String get deployEntityCreditProducts => 'Los bonos prepago en venta';

  @override
  String get deployEntityDocumentDesign => 'Diseños de documentos';

  @override
  String get deployEntityDocumentLinks => 'Enlaces de documentos';

  @override
  String get deployEntityFeatures => 'Funciones';

  @override
  String get deployEntityFieldDefinitions => 'Las preguntas del espacio';

  @override
  String get deployEntityFloorPlan => 'Planos (plantas, puestos, imágenes)';

  @override
  String get deployEntityIdentity => 'Identidad y datos legales';

  @override
  String get deployEntityInvitations => 'Plantillas de invitación';

  @override
  String get deployEntityPackages => 'Paquetes';

  @override
  String get deployEntityPaymentInstructions => 'Instrucciones de pago';

  @override
  String get deployEntityReminders => 'Reglas de recordatorio';

  @override
  String get deployEntityRoles => 'Matriz de roles';

  @override
  String get deployEntityServices => 'Servicios';

  @override
  String get deployEntitySites => 'Sedes';

  @override
  String get deployEntityTariffs => 'Tarifas';

  @override
  String get deployEntityValidationRules => 'Reglas de validación';

  @override
  String get deployEntityVat => 'IVA';

  @override
  String get deployEntityWorkspaceRoles => 'Los roles propios del espacio';

  @override
  String get deploymentConfirm => 'Desplegar';

  @override
  String get deploymentConfirmBody =>
      'Lo que este espacio contiene para las entidades marcadas se sustituye por lo del gemelo. El diario conserva la vuelta atrás.';

  @override
  String get deploymentConfirmTitleDev => '¿Desplegar en este DEV?';

  @override
  String get deploymentConfirmTitleProd => '¿Desplegar en este PROD?';

  @override
  String get deploymentDirectionToDev => 'A desarrollo';

  @override
  String get deploymentDirectionToProd => 'A producción';

  @override
  String get deploymentDone => 'Desplegado. Está en el diario.';

  @override
  String get deploymentFlowFromDev => 'Desde DEV';

  @override
  String get deploymentFlowFromProd => 'Desde PROD';

  @override
  String get deploymentFlowToDev => 'A DEV';

  @override
  String get deploymentFlowToProd => 'A PROD';

  @override
  String get deploymentIntroFromDev =>
      'Está en el lado de producción. Lo que marque abajo se trae del gemelo de desarrollo a este espacio, tras una vista previa.';

  @override
  String get deploymentIntroFromProd =>
      'Está en el lado de desarrollo. Lo que marque abajo se trae del gemelo de producción a este espacio, tras una vista previa.';

  @override
  String get deploymentIntroToDev =>
      'Está en el lado de producción. Lo que marque abajo se despliega al gemelo de desarrollo, tras una vista previa de lo que cambia.';

  @override
  String get deploymentIntroToProd =>
      'Está en el lado de desarrollo. Lo que marque abajo se despliega al gemelo de producción, tras una vista previa de lo que cambia.';

  @override
  String get deploymentJournal => 'Diario';

  @override
  String get deploymentJournalEmpty => 'Todavía no se ha desplegado nada.';

  @override
  String get deploymentKindConfiguration => 'Configuración';

  @override
  String get deploymentKindMasterData => 'Datos maestros';

  @override
  String get deploymentKindReports => 'Informes';

  @override
  String get deploymentNeedsDevPermission =>
      'Desplegar en desarrollo requiere el permiso «Desplegar en desarrollo».';

  @override
  String get deploymentNeedsProdPermission =>
      'Desplegar en producción requiere el permiso «Desplegar en producción».';

  @override
  String get deploymentNoChange => 'Sin cambios';

  @override
  String get deploymentNoTwin =>
      'Este espacio no tiene un gemelo del que usted sea miembro.';

  @override
  String get deploymentNothingToDo =>
      'Los dos lados ya coinciden en estas entidades.';

  @override
  String get deploymentPreviewToDev => 'Lo que cambia en el lado de desarrollo';

  @override
  String get deploymentPreviewToProd =>
      'Lo que cambia en el lado de producción';

  @override
  String get deploymentPullFromDev => 'Traer desde DEV…';

  @override
  String get deploymentPullFromProd => 'Traer desde PROD…';

  @override
  String get deploymentRequires => 'necesita';

  @override
  String get deploymentRollback => 'Deshacer';

  @override
  String get deploymentRolledBack => 'Deshecho.';

  @override
  String get deploymentRolledBackLabel => 'deshecho';

  @override
  String get deploymentTitle => 'Despliegue';

  @override
  String get deploymentToDev => 'Desplegar en DEV…';

  @override
  String get deploymentToProd => 'Desplegar en PROD…';

  @override
  String get deskDetail => 'Mesa entera';

  @override
  String get deskSupplementLabel => 'Reservas de mesa';

  @override
  String get developerClear => 'Vaciar registro';

  @override
  String get developerEmpty => 'Aún no hay entradas de registro.';

  @override
  String get developerExport => 'Exportar registro';

  @override
  String get developerExportReservations => 'Exportar reservas';

  @override
  String get developerExportReservationsHint =>
      'Todas las reservas y entradas — pasadas, presentes y futuras, en cualquier estado — en CSV, para análisis y depuración.';

  @override
  String get developerExportReservationsOwnHint =>
      'Tus propias reservas y entradas, en cualquier estado, como CSV: exportar todo el espacio requiere el permiso de exportación de datos.';

  @override
  String get developerFilterAll => 'Todo';

  @override
  String get developerFilterErrors => 'Errores';

  @override
  String get developerFilterWarnings => 'Avisos+';

  @override
  String get developerMode => 'Modo desarrollador';

  @override
  String get developerModeWorkspaceHint =>
      'Se aplica a todos los miembros de este espacio.';

  @override
  String get developerTitle => 'Desarrollador';

  @override
  String get developmentBanner => 'Espacio de desarrollo — aquí nada es real';

  @override
  String get developmentWatermark => 'DESARROLLO';

  @override
  String get directoryApproximate => 'Ubicación aproximada de la dirección';

  @override
  String get directoryCheckedIn => 'Presente';

  @override
  String directoryCheckedInSeat(String seat) {
    return 'Presente · $seat';
  }

  @override
  String get directoryClose => 'Cerrar';

  @override
  String get directoryEmpty => 'Aún no hay miembros.';

  @override
  String directoryLastSeenDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Visto hace $days días',
      one: 'Visto hace 1 día',
    );
    return '$_temp0';
  }

  @override
  String directoryLastSeenHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Visto hace $hours horas',
      one: 'Visto hace 1 hora',
    );
    return '$_temp0';
  }

  @override
  String directoryLastSeenMinutes(int minutes) {
    return 'Visto hace $minutes min';
  }

  @override
  String get directoryLocate => 'Localizar en el mapa';

  @override
  String get directoryLocating => 'Localizando la dirección pública…';

  @override
  String get directoryLocationMissing =>
      'Ubicación no disponible. El propietario puede publicar coordenadas precisas.';

  @override
  String get directoryNoUpcoming => 'Sin reservas próximas';

  @override
  String get directoryOnline => 'En línea';

  @override
  String get directoryOpenGroup => 'Abrir el grupo de WhatsApp';

  @override
  String get directoryReservationsHeading => 'Reservas';

  @override
  String get directoryReservedNow => 'Reservado ahora';

  @override
  String directoryReservedNowSeat(String seat) {
    return 'Reservado ahora · $seat';
  }

  @override
  String get directoryReservedToday => 'Reservado hoy';

  @override
  String get directoryTitle => 'Miembros';

  @override
  String get directoryWhatsapp => 'Chatear por WhatsApp';

  @override
  String get documentsAdd => 'Añadir un documento';

  @override
  String get documentsCategoryFinance => 'Estados financieros';

  @override
  String get documentsCategoryGuides => 'Guías y manuales';

  @override
  String get documentsCategoryLabel => 'Categoría';

  @override
  String get documentsCategoryMinutes => 'Actas de reuniones';

  @override
  String get documentsCategoryOther => 'Otros documentos';

  @override
  String get documentsCategoryStatutes => 'Estatutos y legal';

  @override
  String get documentsDelete => '¿Quitar el documento?';

  @override
  String get documentsEmpty =>
      'Aún no hay documentos. Enlaza tus estatutos, guías y estados desde cualquier drive.';

  @override
  String get documentsInvalid =>
      'Un documento necesita un título y un enlace https://.';

  @override
  String get documentsProviderLabel => 'Almacenado en';

  @override
  String get documentsRoleAdmin => 'Admins y propietarios';

  @override
  String get documentsRoleLabel => 'Visible para';

  @override
  String get documentsRoleMember => 'Todos los miembros';

  @override
  String get documentsRoleOwner => 'Solo propietarios';

  @override
  String get documentsTitle => 'Documentos';

  @override
  String get documentsTitleLabel => 'Título';

  @override
  String get documentsUrlHelper =>
      'Pega el enlace de compartir de tu drive — los permisos se gestionan allí.';

  @override
  String get documentsUrlLabel => 'Enlace (https://…)';

  @override
  String get dunningAutomatic => 'Recordatorios automáticos';

  @override
  String get dunningAutomaticHint =>
      'Una vez al día, las facturas que superan su plazo de pago registrado pasan solas al siguiente nivel de recordatorio — por el importe aún pendiente, nunca mientras un pago está pendiente o la factura está en suspenso. Las facturas sin plazo registrado quedan en tus manos. Desactivado: envías cada recordatorio tú mismo.';

  @override
  String get dunningBetweenDays => 'Días entre recordatorios';

  @override
  String dunningDueChip(int level) {
    return 'Recordatorio $level pendiente';
  }

  @override
  String get dunningFirstAfterDays => 'Días hasta el primer recordatorio';

  @override
  String get dunningLevels => 'Número de niveles de recordatorio';

  @override
  String get dunningSaved => 'Reglas de recordatorio guardadas.';

  @override
  String get dunningSettingsTitle => 'Reglas de recordatorio';

  @override
  String get eInvoiceGapBuyerLegalIdAdvisable =>
      'Falta el SIREN del comprador. Una plataforma francesa enruta por él: introdúzcalo en el perfil del miembro antes de transmitir. No es un rechazo — el archivo es válido sin él.';

  @override
  String get eInvoiceGapMissingBuyerLegalId =>
      'El comprador es una empresa francesa sin SIREN — indique su identificador legal en el perfil del socio.';

  @override
  String get eInvoiceGapMixedNotSubjectLines =>
      'Una línea no sujeta (envase retornable) figura junto a líneas gravadas — la norma EN 16931 rechaza la mezcla; emita el envase en un documento aparte.';

  @override
  String get editorAccessoriesLabel => 'Accesorios';

  @override
  String get editorAddLevel => 'Añadir planta';

  @override
  String get editorAmenitiesLabel => 'Equipamiento';

  @override
  String get editorBackgroundImage => 'Imagen de fondo';

  @override
  String get editorBackgroundRemove => 'Quitar imagen de fondo';

  @override
  String get editorBackgroundReplace => 'Reemplazar imagen de fondo';

  @override
  String get editorBackgroundSet => 'Establecer imagen de fondo';

  @override
  String get editorBlockedLabel => 'Bloqueado (mantenimiento)';

  @override
  String get editorBookableAsWhole => 'Reservable en su totalidad';

  @override
  String get editorBookableAsWholeHint =>
      'Alguien puede reservarla entera, con todo lo que hay dentro.';

  @override
  String get editorCanvasSemantics => 'Área de dibujo del plano';

  @override
  String get editorChairLabel => 'Tipo de silla';

  @override
  String get editorDeleteElementConfirm =>
      '¿Eliminar este elemento? Todo lo colocado sobre él también se eliminará.';

  @override
  String get editorDeleteElementConfirmAudit =>
      '¿Eliminar este elemento? Todo lo colocado sobre él también se elimina. Las reservas que hacen referencia a él conservan una instantánea de texto para auditorías; las reservas abiertas se cancelan.';

  @override
  String get editorDeleteLevelConfirm =>
      '¿Eliminar esta planta? Se eliminarán todas las oficinas, mesas y asientos que contiene.';

  @override
  String get editorDeleteLevelConfirmAudit =>
      '¿Eliminar esta planta? Se eliminan todas las oficinas, mesas y asientos que contiene. Las reservas que hacen referencia a ellos conservan una instantánea de texto para auditorías; las reservas abiertas se cancelan.';

  @override
  String get editorDeskFull => 'No queda sitio en esta mesa.';

  @override
  String get editorDeskNameDefault => 'Mesa';

  @override
  String get editorDeskNameLabel => 'Nombre de la mesa';

  @override
  String get editorDeskProperties => 'Mesa';

  @override
  String get editorDuplicate => 'Duplicar';

  @override
  String get editorEmptyFloorAction => 'Dibujar la primera sala';

  @override
  String get editorEmptyFloorBody =>
      'Todo va dentro de una sala: dibuja una, pon mesas dentro y luego puestos en las mesas.';

  @override
  String get editorEmptyFloorTitle => 'Esta planta está vacía';

  @override
  String get editorHintDesk =>
      'Arrastra dentro de una sala para dibujar una mesa';

  @override
  String get editorHintImage => 'Toca dónde debe ir la imagen';

  @override
  String get editorHintOffice => 'Arrastra para dibujar una sala';

  @override
  String get editorHintSeat => 'Toca una mesa para añadir un puesto';

  @override
  String get editorLevelActions => 'Acciones de la planta';

  @override
  String get editorLevelBookableOff => 'No reservable por completo';

  @override
  String get editorLevelBookableOn => 'Reservable por completo';

  @override
  String get editorLevelNameLabel => 'Nombre de la planta';

  @override
  String get editorMediaSaving => 'Guardando la imagen…';

  @override
  String get editorMediaWriteFailed =>
      'No se pudo confirmar que la imagen se guardó. Reintentar nunca la añade dos veces.';

  @override
  String get editorNewOffice => 'Nueva oficina';

  @override
  String get editorNoAccessories =>
      'Todavía no hay accesorios — añádelos en Ajustes → Accesorios.';

  @override
  String get editorNoAccessoriesAction =>
      'Aún no hay equipamiento — configúralo';

  @override
  String get editorNoLevels =>
      'Aún no hay plantas. Añade la primera planta de tu espacio.';

  @override
  String get editorOfficeNameDefault => 'Oficina';

  @override
  String get editorOfficeNameLabel => 'Nombre de la oficina';

  @override
  String get editorOfficeProperties => 'Oficina';

  @override
  String get editorOpenTooltip => 'Editar espacio';

  @override
  String get editorOrientationHint => 'Hacia dónde mira la silla en el plano.';

  @override
  String get editorOrientationLabel => 'Dirección de asiento';

  @override
  String get editorPlacementOutside =>
      'Debe estar completamente dentro de una oficina.';

  @override
  String get editorPlacementOverlap =>
      'Se superpone con un elemento existente.';

  @override
  String get editorProperties => 'Propiedades';

  @override
  String get editorRenameLevel => 'Renombrar';

  @override
  String get editorSeatNameDefault => 'Asiento';

  @override
  String get editorSeatNameLabel => 'Nombre del asiento';

  @override
  String get editorSeatNfcDuplicate =>
      'Esta etiqueta ya está vinculada a otra silla.';

  @override
  String get editorSeatNfcHelp =>
      'UID de la etiqueta en hexadecimal — dejar vacío para ninguna.';

  @override
  String get editorSeatNfcLabel => 'Etiqueta NFC/RFID';

  @override
  String get editorSeatNfcRead => 'Leer una etiqueta ahora';

  @override
  String get editorSeatNfcReadFailed =>
      'No se pudo iniciar el lector de etiquetas.';

  @override
  String get editorSeatNoDesk =>
      'Los asientos solo pueden colocarse sobre una mesa.';

  @override
  String get editorSeatProperties => 'Asiento';

  @override
  String get editorTitle => 'Editor del espacio';

  @override
  String get editorToolDesk => 'Mesa';

  @override
  String get editorToolErase => 'Borrar';

  @override
  String get editorToolImage => 'Imagen';

  @override
  String get editorToolOffice => 'Oficina';

  @override
  String get editorToolSeat => 'Asiento';

  @override
  String get editorToolSelect => 'Seleccionar';

  @override
  String get einvoiceConfigClear => 'Eliminar la plataforma';

  @override
  String get einvoiceConfigCleared => 'Plataforma eliminada.';

  @override
  String get einvoiceConfigEndpoint => 'URL de subida';

  @override
  String get einvoiceConfigField =>
      'Nombre del campo de archivo (file por defecto)';

  @override
  String get einvoiceConfigHeader =>
      'Cabecera de autenticación (Authorization por defecto)';

  @override
  String get einvoiceConfigIntro =>
      'Donde DesKilo deposita tus facturas. Sirve cualquier plataforma que acepte una subida con un token — una plataforma autorizada, un punto de acceso Peppol, una plataforma nacional. El token se guarda en el servidor y nunca sale.';

  @override
  String get einvoiceConfigSaved => 'Plataforma guardada.';

  @override
  String get einvoiceConfigTitle => 'Plataforma de facturación electrónica';

  @override
  String get einvoiceConfigToken => 'Token o credencial';

  @override
  String get einvoiceConfigTokenSet =>
      'Hay un token guardado (escribe uno nuevo para reemplazarlo).';

  @override
  String get einvoiceConfigUnavailable =>
      'No se pudo cargar la configuración de la plataforma. Comprueba la conexión e inténtalo de nuevo.';

  @override
  String get einvoiceCustomerSectionHelp =>
      'Adónde van las facturas para el cliente: su punto de acceso Peppol, portal o la API acordada — separado de la plataforma gubernamental.';

  @override
  String get einvoiceCustomerSectionTitle => 'Servicio de entrega al cliente';

  @override
  String get einvoiceDevEndpoint => 'URL de subida Dev';

  @override
  String get einvoiceDevToken => 'Token o credencial Dev';

  @override
  String get einvoiceEnvDev => 'Dev (plataforma de prueba)';

  @override
  String get einvoiceEnvProd => 'Producción';

  @override
  String get einvoiceEnvProdHint => 'La transmisión real.';

  @override
  String get einvoiceEnvTestHint =>
      'Un ensayo — registrado como envío de prueba.';

  @override
  String get einvoiceEnvTitle => '¿Enviar a qué plataforma?';

  @override
  String get einvoiceEnvUat => 'UAT (plataforma de prueba)';

  @override
  String get einvoiceTestEnvsHelp =>
      'Endpoints y tokens separados para ensayos. La opción aparece al enviar solo con el modo desarrollador activo.';

  @override
  String get einvoiceTestEnvsTitle => 'Entornos de prueba (UAT / Dev)';

  @override
  String get einvoiceUatEndpoint => 'URL de subida UAT';

  @override
  String get einvoiceUatToken => 'Token o credencial UAT';

  @override
  String get emblemChoose => 'Elegir una imagen';

  @override
  String get emblemFailed => 'No se pudo guardar el emblema. Nada ha cambiado.';

  @override
  String get emblemHint =>
      'Una imagen pequeña que aparece bajo el nombre de la aplicación en el menú. Se redibuja a 512 píxeles como máximo y se guarda sin los metadatos del archivo.';

  @override
  String get emblemNotAnImage => 'Ese archivo no es una imagen.';

  @override
  String get emblemRemove => 'Quitar';

  @override
  String get emblemRemoved => 'Emblema quitado.';

  @override
  String get emblemSaved => 'Emblema guardado.';

  @override
  String get emblemTitle => 'Emblema';

  @override
  String get emblemTooHeavy =>
      'Esa imagen es demasiado pesada para una marca que se muestra a 28 píxeles.';

  @override
  String get entitlementBlockedFull =>
      'Has usado todos tus días este mes. Pide más a un administrador o solicita medias jornadas extra abajo.';

  @override
  String entitlementDaysLeft(String left) {
    return '$left días restantes';
  }

  @override
  String entitlementDaysUsed(String used, String total) {
    return '$used de $total días usados';
  }

  @override
  String get entitlementPackageFull =>
      'Has usado todos tus días este mes. Compra un paquete para seguir reservando.';

  @override
  String entitlementPaygRate(String rate) {
    return 'Los días que superen tu plan se cobran a $rate cada uno.';
  }

  @override
  String get entitlementTitle => 'Este mes';

  @override
  String get environmentDev => 'Desarrollo — para probar';

  @override
  String get environmentHint =>
      'Un espacio de desarrollo lo anuncia en cada pantalla y pone marca de agua en cada documento. Decláre­lo producción solo cuando las facturas que salen de él se deban de verdad.';

  @override
  String get environmentLabel => 'Tipo de espacio';

  @override
  String get environmentPairsCreateTwin => 'Crear su gemelo';

  @override
  String get environmentPairsCreateTwinDesc =>
      'Un espacio de desarrollo y uno de producción con el mismo nombre; la configuración se copia una vez.';

  @override
  String get environmentPairsPairedDev =>
      'Emparejado con su gemelo de desarrollo';

  @override
  String get environmentPairsPairedProd =>
      'Emparejado con su gemelo de producción';

  @override
  String get environmentPairsTwinCreated => 'El gemelo está creado.';

  @override
  String get environmentProd => 'Producción — las facturas se deben';

  @override
  String get environmentProdConfirmAction => 'Declarar producción';

  @override
  String get environmentProdConfirmBody =>
      'El banner desaparece y los documentos pierden su marca de agua. Las facturas ya emitidas no cambian: conservan la marca que llevaban al emitirse.';

  @override
  String get environmentProdConfirmTitle =>
      '¿Declarar este espacio de producción?';

  @override
  String get environmentSaved => 'Tipo de espacio guardado.';

  @override
  String get erasurePreviewKept => 'Conservado, y por qué';

  @override
  String get erasurePreviewOutside => 'Fuera de esta instalación';

  @override
  String get erasurePreviewRemoved => 'Suprimido';

  @override
  String get erasurePreviewTitle => 'Qué hace la supresión aquí';

  @override
  String get erasureStoreAccounts =>
      'Facturas y libro — prueba contable, conservada durante el plazo legal; los documentos emitidos no se reescriben';

  @override
  String get erasureStoreAnswers =>
      'Tus respuestas a las preguntas del espacio';

  @override
  String get erasureStoreBackups =>
      'Copias de seguridad del operador — caducan según su rotación';

  @override
  String get erasureStoreDeviceCaches =>
      'Copias en tus dispositivos — se borran al cerrar sesión en cada uno';

  @override
  String get erasureStoreHeldAnswers =>
      'Respuestas bajo una obligación de conservación documentada por el espacio';

  @override
  String get erasureStoreMembership =>
      'La fila de membresía — enlaza los registros conservados; seudónima, no anónima';

  @override
  String get erasureStoreMessages => 'Mensajes que enviaste';

  @override
  String get erasureStoreOpenBookings => 'Reservas abiertas — canceladas';

  @override
  String get erasureStoreOtherInstallations =>
      'Otra instalación de DesKilo es un responsable distinto — pregúntale directamente';

  @override
  String get erasureStorePastBookings =>
      'Reservas pasadas — el registro de ocupación del espacio';

  @override
  String get erasureStoreProfile => 'Tu perfil (si es tu último espacio)';

  @override
  String get errorOffline =>
      'Sin conexión: no se ha enviado nada. Inténtalo de nuevo cuando vuelvas a estar en línea.';

  @override
  String get eventAccept => 'Aceptar';

  @override
  String get eventAutoValidated => 'Validado automáticamente';

  @override
  String eventExpenseDeviation(Object reason, Object scheduled) {
    return 'validado $scheduled — $reason';
  }

  @override
  String eventExpenseRepartitionLine(
    String actor,
    String title,
    String amount,
    int count,
  ) {
    return '$actor reparte «$title»: $amount entre $count socios';
  }

  @override
  String eventExpenseScheduleLine(Object actor, Object amount, Object title) {
    return '$actor programa «$title» — $amount recurrente';
  }

  @override
  String eventExpenseSubmitted(String actor, String amount) {
    return '$actor envió un gasto de $amount';
  }

  @override
  String eventForSubject(String name) {
    return 'para $name';
  }

  @override
  String eventInvoicePaid(String number, String amount) {
    return 'Factura $number pagada — $amount';
  }

  @override
  String eventInvoiceReminderLine(String number, int level, String amount) {
    return 'Recordatorio $level: factura $number — $amount pendientes';
  }

  @override
  String eventInvoiceWriteoffLine(String actor, String number, String amount) {
    return '$actor pide anular el saldo de $number — $amount';
  }

  @override
  String eventPaymentSubmitted(String actor, String amount) {
    return '$actor registró un pago de $amount';
  }

  @override
  String eventPaymentTermsChangeLine(String actor, String terms) {
    return '$actor pide fijar las condiciones de pago: $terms';
  }

  @override
  String eventPriceNegotiationItems(int count) {
    return '$count artículos';
  }

  @override
  String eventPriceNegotiationLine(String actor, String member, String terms) {
    return '$actor propone condiciones para $member: $terms';
  }

  @override
  String eventQuotaRequested(String actor, int halfDays, String period) {
    return '$actor solicita $halfDays medias jornadas extra para $period';
  }

  @override
  String get eventReject => 'Rechazar';

  @override
  String eventRejectedBy(String name, String when) {
    return 'Rechazado por $name · $when';
  }

  @override
  String eventReservationCancelled(String actor, String target) {
    return '$actor canceló la reserva de $target';
  }

  @override
  String eventReservationCreated(String actor, String target) {
    return '$actor reservó $target';
  }

  @override
  String get eventReservationDeleteCheckedIn => 'registrada';

  @override
  String eventReservationDeleteLine(String actor, String date, String state) {
    return '$actor pide eliminar la reserva del $date ($state)';
  }

  @override
  String get eventReservationDeleteUnused => 'nunca usada';

  @override
  String eventReservationModified(String actor, String target) {
    return '$actor modificó la reserva de $target';
  }

  @override
  String eventRoleDemote(String actor) {
    return '$actor pide retirar el rol Administrador/a';
  }

  @override
  String eventRoleGiven(String actor, String role, String member) {
    return '$actor da el rol $role a $member';
  }

  @override
  String eventRolePromote(String actor) {
    return '$actor pide dar el rol Administrador/a';
  }

  @override
  String eventRoleTakenBack(String actor, String role, String member) {
    return '$actor retira el rol $role a $member';
  }

  @override
  String eventServiceChargeTitle(String name, int quantity, String amount) {
    return '$name ×$quantity — $amount';
  }

  @override
  String get eventSystemDecider => 'Sistema';

  @override
  String get eventTypeAdjustment => 'Ajuste';

  @override
  String get eventTypeExpense => 'Gasto';

  @override
  String get eventTypeExpenseRepartition => 'Gasto compartido';

  @override
  String get eventTypeExpenseSchedule => 'Gasto programado';

  @override
  String get eventTypeInvoiceIssue => 'Emisión de factura';

  @override
  String get eventTypeInvoicePayment => 'Pago de factura';

  @override
  String get eventTypeInvoiceReminder => 'Recordatorio de pago';

  @override
  String get eventTypeInvoiceVoid => 'Anulación de factura';

  @override
  String get eventTypeInvoiceWriteoff => 'Anulación de saldo';

  @override
  String get eventTypeMatrixChange => 'Cambio de la matriz de permisos';

  @override
  String get eventTypeMemberJoin => 'Nuevo miembro';

  @override
  String get eventTypeMemberStatusChange => 'Cambio de membresía';

  @override
  String get eventTypePayment => 'Pago';

  @override
  String get eventTypePaymentTermsChange => 'Condiciones de pago';

  @override
  String get eventTypePriceNegotiation => 'Negociación de precios';

  @override
  String get eventTypeQuota => 'Medias jornadas extra';

  @override
  String get eventTypeRefund => 'Reembolso';

  @override
  String get eventTypeReservation => 'Reserva';

  @override
  String get eventTypeReservationDelete => 'Eliminación de reserva';

  @override
  String get eventTypeRoleChange => 'Cambio de rol';

  @override
  String get eventTypeServiceCharge => 'Servicio';

  @override
  String get eventTypeSpaceReservation => 'Reservas de espacios enteros';

  @override
  String get eventTypeSubscriptionChange => 'Cambio de suscripción';

  @override
  String get eventTypeUnknown => 'Actividad';

  @override
  String get eventTypeUsageCorrection => 'Salida anticipada';

  @override
  String get eventTypeUsageRecordDelete => 'Eliminar registro de uso';

  @override
  String eventUsageCorrectionLine(String actor, String from, String to) {
    return '$actor pide que se facture $to en lugar de $from';
  }

  @override
  String eventUsageRecordDeleteLine(String actor, String space) {
    return '$actor pide eliminar un registro de uso ($space)';
  }

  @override
  String eventValidatedBy(String name, String when) {
    return 'Validado por $name · $when';
  }

  @override
  String eventValidationStage(int stage, int required) {
    return 'Validación $stage de $required solicitada';
  }

  @override
  String eventValidations(int current, int required) {
    return '$current/$required validaciones';
  }

  @override
  String get eventsEmpty => 'Aún no hay eventos.';

  @override
  String get eventsFilterAll => 'Todos';

  @override
  String get eventsMessagesHeader => 'Mensajes';

  @override
  String get eventsPendingHeader => 'Esperando tu confirmación';

  @override
  String get expenseCategoryCoffee => 'Café y cocina';

  @override
  String get expenseCategoryEquipment => 'Equipamiento';

  @override
  String get expenseCategoryOther => 'Otro';

  @override
  String get expenseCategorySupplies => 'Material';

  @override
  String get expenseInvalidAmount => 'Introduzca un importe mayor que cero.';

  @override
  String get expenseInvalidSupplyQuantity => 'Introduzca al menos una unidad.';

  @override
  String get expenseInvalidUnitPrice =>
      'Introduzca un precio unitario válido o déjelo vacío.';

  @override
  String get expenseMissingSupplyName => 'Ponga nombre al nuevo artículo.';

  @override
  String get expenseSupplyHint =>
      'Cápsulas de café, bolsas de aspiradora… Una vez validado, el artículo pasa al estante como servicio consumible: quien lo usa lo paga.';

  @override
  String get expenseSupplyItem => 'Artículo';

  @override
  String get expenseSupplyNewItem => 'Artículo nuevo';

  @override
  String get expenseSupplyQuantity => 'Cantidad';

  @override
  String get expenseSupplyToggle => 'Es un suministro para el espacio';

  @override
  String get expenseSupplyUnitPrice =>
      'Precio unitario (lo que cuesta un consumo)';

  @override
  String get expenseSupplyUnitPriceHint =>
      'Prellenado con importe ÷ cantidad; redondea si quieres.';

  @override
  String get exportClaimExchange =>
      'Para que su asesor lo importe y lo revise — no es una declaración.';

  @override
  String get exportClaimRegulatory =>
      'El formato que pide su administración tributaria.';

  @override
  String get exportClaimSubset =>
      'Solo facturas y cobros, sin libro mayor. El archivo lo indica en su cabecera.';

  @override
  String get exportNoCompleteBooks =>
      'Reconstruido a partir de facturas y pagos — DesKilo no lleva contabilidad por partida doble, así que no son sus libros completos. Su asesor los completa.';

  @override
  String get exportUncertifiedSoftware =>
      'Generado según la especificación publicada, pero DesKilo no es software certificado en este país — consulte con su asesor si se le exige.';

  @override
  String get featureAccessorySupplements => 'Suplementos de accesorios';

  @override
  String get featureAccessorySupplementsDesc =>
      'Facturar los accesorios de sitio con precio por media jornada reservada. Se aplica a las reservas desde la activación.';

  @override
  String get featureAccountingBookDesc =>
      'Quién lleva los libros oficiales de cada emisor: Deskilo como precontabilidad, un libro local o un sistema contable externo que hace fe. Cada emisor indica su moneda, su ejercicio y su base contable. Desactivado: los saldos de los miembros y las facturas funcionan como antes.';

  @override
  String get featureAccountingBookTitle => 'Libro contable';

  @override
  String get featureAdminInvoicing => 'Los admins emiten facturas';

  @override
  String get featureAdminInvoicingDesc =>
      'Los admins también emiten facturas. El propietario siempre puede.';

  @override
  String get featureAdminLevelAssign => 'Los admins pueden asignar plantas';

  @override
  String get featureAdminLevelAssignDesc =>
      'Los admins asignan reservas de planta a los miembros. El propietario siempre puede.';

  @override
  String get featureAdminSeatBlocking =>
      'Los administradores pueden bloquear sitios';

  @override
  String get featureAdminSeatBlockingDesc =>
      'Los administradores marcan sitios como no reservables por mantenimiento. El propietario siempre puede.';

  @override
  String featureAlsoEnabled(String features) {
    return 'También activado: $features';
  }

  @override
  String featureAlsoEnables(String features) {
    return 'Activar esto también habilita $features';
  }

  @override
  String get featureAutoCheckInOut =>
      'Entrada/salida automática al final del día';

  @override
  String get featureAutoCheckInOutDesc =>
      'Las reservas sin entrada o salida registradas se completan solas cuando pasa su horario.';

  @override
  String get featureBadgeSignInDesc =>
      'Los miembros pueden iniciar sesión escaneando su credencial e introduciendo su PIN, en lugar de escribir un correo en una tableta compartida. Cada miembro define su propio PIN y activa su propia credencial.';

  @override
  String get featureBadgeSignInTitle => 'Iniciar sesión con credencial';

  @override
  String get featureBookForOthers => 'Reservar para otros';

  @override
  String get featureBookForOthersDesc =>
      'Los administradores y propietarios reservan sitios para otros miembros.';

  @override
  String get featureBookingGateDesc =>
      'Cada superficie de reserva — plano, vistas de día, semana y mes, hoja de reserva, quiosco, escaneo QR o NFC — comprueba los parámetros de disponibilidad antes de ofrecer una franja y nombra el motivo cuando no puede; los días cerrados se dibujan cerrados en cada vista, una leyenda nombra los estados de los puestos, y los admins pueden dar salida a un miembro donde la regla lo permite.';

  @override
  String get featureBookingGateTitle => 'Guarda de reserva';

  @override
  String get featureBookingPoliciesDesc =>
      'Comportamiento de reserva configurable: reservas pasadas, reservas por minutos fuera de horario y check-out por administradores.';

  @override
  String get featureBookingPoliciesTitle => 'Políticas de reserva';

  @override
  String get featureCalendarFileExportDesc =>
      'Permite a un miembro guardar una de sus propias reservas como archivo de calendario estándar (.ics) para el calendario que ya usa. El archivo solo lleva la hora, el espacio reservado y el nombre del espacio de coworking — sin importe, sin nombre, sin nota, sin enlace — y es una instantánea: un cambio posterior de la reserva no actualiza un archivo ya guardado. No se escribe en ningún calendario y nada se sincroniza. Desactivada, oculta el botón.';

  @override
  String get featureCalendarFileExportTitle =>
      'Archivo de calendario de una reserva';

  @override
  String get featureCalendarHubDesc =>
      'El calendario muestra todo lo fechado — reservas, registros, avisos, mensajes, facturas, pagos, consumos, recordatorios — para un día o un periodo, cada fila abre su origen. Desactivado: solo reservas.';

  @override
  String get featureCalendarHubTitle => 'Calendario central';

  @override
  String get featureCalendarTab => 'Pestaña Calendario';

  @override
  String get featureCalendarTabDesc =>
      'Vista mensual de reservas y días de cierre.';

  @override
  String get featureCalendarValidationsDesc =>
      'Cada decisión tomada sobre un evento aparece en el calendario en el momento en que se tomó, no en el del evento: quién validó o rechazó qué, y cuándo. Al tocarla se abre su historial. Desactivado: el calendario no lleva decisiones.';

  @override
  String get featureCalendarValidationsTitle => 'Validaciones en el calendario';

  @override
  String get featureCalendarViewsDesc =>
      'La pestaña Calendario como agenda, semana y mes: marcadores por día según el tipo, días cerrados dibujados cerrados, cabeceras Hoy / Mañana, vencimientos de pago y gastos programados en el feed. Desactivado: el simple selector de día o rango sobre el feed.';

  @override
  String get featureCalendarViewsTitle => 'Vistas del calendario';

  @override
  String get featureCapacityKpiDesc =>
      'Muestra a los propietarios y a quienes gestionan las reservas qué parte del tiempo de puesto ofrecido se reservó en un mes, cómo se calcula y lo que la cifra no puede saber.';

  @override
  String get featureCapacityKpiTitle => 'Ocupación de puestos';

  @override
  String get featureCaptureProtectionDesc =>
      'Las pantallas de mensajes rechazan capturas y grabaciones de pantalla cuando el dispositivo lo permite, ocultan su contenido mientras se graba la pantalla y anuncian una captura en la conversación cuando solo puede detectarse. Un navegador no puede bloquear capturas; allí la conversación se difumina cuando la pestaña pierde el foco.';

  @override
  String get featureCaptureProtectionTitle =>
      'Protección contra capturas de pantalla';

  @override
  String get featureCarnetsDesc =>
      'Vender bonos de medias jornadas que se gastan a lo largo de los meses cuando un miembro reserva más allá de su suscripción, cobrados una sola vez en la venta.';

  @override
  String get featureCarnetsTitle => 'Bonos';

  @override
  String get featureChangeUnconfirmed =>
      'El cambio se envió, pero no se pudieron recargar las funciones para confirmarlo. Vuelva a abrir la pantalla para ver el estado.';

  @override
  String get featureChangedMeanwhile =>
      'Las funciones cambiaron mientras tanto, así que no se guardó nada. Revise la lista y vuelva a intentarlo.';

  @override
  String get featureCoOwner => 'Copropietarios';

  @override
  String get featureCoOwnerDesc =>
      'Nombrar copropietarios: permisos de propietario ya (activo) o sucesión en espera (pasivo).';

  @override
  String get featureConfigurationTransfer =>
      'Configuración en el archivo del espacio';

  @override
  String get featureConfigurationTransferDesc =>
      'El archivo del espacio (XML) lleva toda la configuración — tarifas, identidad legal, reglas de reserva y validación, roles, diseños de documentos, sedes, días de cierre — y la importación la aplica, incluso en un espacio que ya tiene reservas. Desactivado: el archivo solo lleva ajustes y plano.';

  @override
  String get featureCustomFieldsDesc =>
      'El espacio puede hacer sus propias preguntas dentro del formulario de identidad: un cargo en la junta, una fecha de alta, un contacto de emergencia. Las respuestas pertenecen a la membresía, así que una pregunta hecha aquí no sigue a nadie a otro sitio.';

  @override
  String get featureCustomFieldsTitle => 'Las preguntas de este espacio';

  @override
  String get featureCustomRolesDesc =>
      'El espacio puede definir sus propios roles — tesorero, secretario — que añaden permisos a los del rol de un miembro. Nunca quitan ninguno, y un propietario los conserva todos.';

  @override
  String get featureCustomRolesTitle => 'Roles que define este espacio';

  @override
  String get featureDataAccessLogDesc =>
      'Cada miembro ve quién consultó sus finanzas y cuándo (lo escribe el servidor, nunca se omite). Desactivado: la fila se oculta, el registro se conserva.';

  @override
  String get featureDataAccessLogTitle => 'Registro de accesos a datos';

  @override
  String get featureDataExport => 'Exportación de datos (Excel)';

  @override
  String get featureDataExportDesc =>
      'Descargar todos los datos del espacio en un libro de Excel.';

  @override
  String get featureDecisionSurfaceDesc =>
      'Un único lugar que responde «¿hay algo que me espere?», ordenado por lo que cuesta la demora: primero el dinero que se va, luego alguien que espera una respuesta. Una línea aparece solo si alguien debe decidir o actuar; una cifra sobre la que nadie puede actuar se queda en la pantalla que la tiene.';

  @override
  String get featureDecisionSurfaceTitle => 'Lo que te espera';

  @override
  String get featureDeletionRequests =>
      'Solicitudes de eliminación de reservas';

  @override
  String get featureDeletionRequestsDesc =>
      'Los miembros pueden SOLICITAR la eliminación de una reserva pasada o registrada; un propietario/admin valida. Desactivado, esas reservas no se pueden eliminar.';

  @override
  String get featureDemoMode => 'El espacio de demostración';

  @override
  String get featureDemoModeDesc =>
      'Un espacio inventado que cualquiera puede abrir desde la pantalla de inicio de sesión, con sus propias personas, reservas y facturas. Nada de lo que se hace allí llega a un espacio real ni sale del dispositivo, y no hace falta ninguna cuenta. Desactivado: la propuesta no aparece.';

  @override
  String get featureDeployments => 'Despliegues';

  @override
  String get featureDeploymentsDesc =>
      'Configuración y datos maestros desplegados entre los dos lados de una pareja, entidad por entidad, con una vista previa de lo que cambia y un diario que sabe deshacer. Desactivado: los gemelos se ajustan a mano, cada uno por su lado.';

  @override
  String get featureDetailChange => 'Cambiarla entre los interruptores';

  @override
  String featureDetailGrantsPermission(String permission) {
    return 'Concede a los administradores el permiso «$permission».';
  }

  @override
  String featureDetailHeldBack(String feature) {
    return 'Activada, pero retenida: necesita $feature, que está desactivada.';
  }

  @override
  String get featureDetailKey => 'Clave técnica';

  @override
  String get featureDetailNone => 'Nada.';

  @override
  String get featureDetailOff => 'Desactivada.';

  @override
  String get featureDetailOn => 'Activada.';

  @override
  String featureDetailOnNeededBy(String names) {
    return 'Activada y necesaria para $names.';
  }

  @override
  String get featureDetailProvides => 'Aporta';

  @override
  String get featureDetailRequires => 'Requiere';

  @override
  String get featureDetailTechnical => 'Detalles técnicos';

  @override
  String get featureDetailUsedBy => 'Usada por';

  @override
  String get featureDocuments => 'Biblioteca de documentos';

  @override
  String get featureDocumentsDesc =>
      'La biblioteca de documentos del espacio: estatutos, guías, estados financieros, actas — enlazados desde cualquier drive, visibles según el rol.';

  @override
  String get featureDunning => 'Recordatorios de pago';

  @override
  String get featureDunningDesc =>
      'Niveles y plazos de recordatorio configurables, una carta por nivel y avisos «Recordatorio pendiente» en las facturas atrasadas. El envío sigue siendo manual, salvo con los Recordatorios de pago automáticos.';

  @override
  String get featureEinvoiceCustomerDeliveryDesc =>
      'Un segundo canal de envío junto a la plataforma gubernamental: transmitir la factura emitida directamente al servicio de facturación del cliente.';

  @override
  String get featureEinvoiceCustomerDeliveryTitle =>
      'Entrega de facturas al cliente';

  @override
  String get featureEnvironmentPairs => 'Pares de entornos';

  @override
  String get featureEnvironmentPairsDesc =>
      'Un espacio y su gemelo — el lado de desarrollo y el de producción — como una pareja: una tarjeta en Perfiles con un interruptor, y el gemelo creado a demanda con la configuración copiada. Desactivado: dos entradas sin relación.';

  @override
  String get featureEventsTab => 'Pestaña Eventos';

  @override
  String get featureEventsTabDesc => 'Actividad y confirmaciones pendientes.';

  @override
  String get featureExpenseRepartitionDesc =>
      'Un gasto común (limpieza, mejora de internet, una silla rota) repartido entre los socios — partes iguales, prorrata de la suscripción, prorrata del uso o una clave por socio — con cada parte previsualizada antes de contabilizarse. Las partes se convierten en líneas de la próxima factura de uso; una reversión genera notas de crédito. Pasa por las reglas de validación. Desactivado: sin reparto.';

  @override
  String get featureExpenseRepartitionTitle => 'Gastos compartidos';

  @override
  String get featureExpenseRepartitionWizard => 'Asistente de reparto';

  @override
  String get featureExpenseRepartitionWizardDesc =>
      'Un reparto guiado: un gasto común propuesto según el porcentaje de suscripción, cada parte ajustable, y la regla ajustada recordada para el mes siguiente. Desactivado: solo la ficha de reparto de un gasto.';

  @override
  String get featureFinanceFacesDesc =>
      'La pestaña Finanzas se lee en cuatro vistas — Extracto, Pagos, Facturas, Documentos — bajo un mismo selector de mes, cada una con su ayuda. Desactivado: una sola columna.';

  @override
  String get featureFinanceFacesTitle => 'Finanzas en cuatro vistas';

  @override
  String get featureFormHelpHintsDesc =>
      'Un carrusel de consejos descartable en cada pantalla principal, y un pequeño ? junto a cada parámetro y campo — un toque abre la guía en la sección correcta. Restaurable desde Ajustes.';

  @override
  String get featureFormHelpHintsTitle => 'Consejos de ayuda';

  @override
  String get featureGuestParticipationDesc =>
      'Permite a una persona que no es miembro pedir visitar este espacio, y a quien gestiona las reservas admitirla o rechazarla. Una visita no crea membresía, suscripción ni rol. Desactivado: nadie pide ni es admitido aquí.';

  @override
  String get featureGuestParticipationTitle => 'Visitas de invitados';

  @override
  String get featureHeldBack =>
      'Esperando a la función de arriba: actívala y esta vuelve a funcionar.';

  @override
  String get featureHolidayImportDesc =>
      'Un propietario importa los días festivos del país, y de una región, desde una fuente de datos abiertos, desmarca los días en que el espacio sigue abierto e importa el resto como días de cierre. Los meses ya facturados se omiten y se nombran.';

  @override
  String get featureHolidayImportTitle => 'Importar días festivos';

  @override
  String get featureInstanceWizard => 'Asistente de instancia';

  @override
  String get featureInstanceWizardDesc =>
      'En la pantalla Servidor, un asistente crea un nuevo proyecto Supabase, instala el esquema de la app, despliega sus funciones y apunta este dispositivo a él — un token de acceso, sin terminal. Desactivado: solo los pasos manuales.';

  @override
  String get featureIntakeStoppedNote =>
      'Desactivado: no empieza nada nuevo; lo que ya está abierto aún puede atenderse y cerrarse.';

  @override
  String get featureIntakeUnconfirmedNote =>
      'Desactivado: no empieza nada nuevo. Este servidor no pudo confirmar que lo que ya está abierto siga pudiendo atenderse; no cuente con ello.';

  @override
  String get featureInvoiceAddressWindow => 'Ventanilla de dirección';

  @override
  String get featureInvoiceAddressWindowDesc =>
      'Coloca al destinatario donde lo muestra un sobre con ventanilla, para que una factura impresa pueda doblarse y enviarse. El lado sigue al país y puede cambiarse.';

  @override
  String get featureInvoiceJourneyDesc =>
      'Cada factura muestra dónde está — Emitida, Pago, Confirmación, Cerrada — y a quién le toca: el miembro paga, un admin confirma el pago declarado, el emisor lo concilia, los validadores deciden. El hub de emisores añade una banda de etapas con contadores y una explicación «Cómo funciona».';

  @override
  String get featureInvoiceJourneyTitle => 'El recorrido de una factura';

  @override
  String get featureInvoicePdfTemplate => 'Plantilla del PDF de factura';

  @override
  String get featureInvoicePdfTemplateDesc =>
      'Introducción y pie escritos por el propietario en el PDF de la factura. Nunca toca el XML de la factura electrónica.';

  @override
  String get featureInvoiceSettlementDesc =>
      'Varias facturas abiertas de un miembro pueden agruparse en una sola que paga. Las originales siguen en el archivo, trazables posición por posición, y dejan de reclamarse por separado.';

  @override
  String get featureInvoiceSettlementTitle => 'Agrupar facturas';

  @override
  String get featureInvoicing => 'Facturas';

  @override
  String get featureInvoicingDesc =>
      'Facturas inmutables y firmadas en un archivo — descarga o comparte en PDF.';

  @override
  String get featureInvoicingWizardDesc =>
      'Un proceso guiado de cierre mensual para la persona de finanzas: una pasada de inicio de mes para las suscripciones pagadas por adelantado y otra de fin de mes para el uso y los cargos adicionales — revisión, emisión en lote, envío, recordatorios vencidos, registro y validación de pagos, conciliación con facturas, reagrupación, anulación o reembolso, y un resumen con lo que queda y a quién le toca. Desactivado: las pantallas separadas.';

  @override
  String get featureInvoicingWizardTitle => 'Asistente de facturación';

  @override
  String get featureKioskMemberPhotosDesc =>
      'El recibo del quiosco muestra la foto de perfil del miembro: el control visual de credencial equivocada.';

  @override
  String get featureKioskMemberPhotosTitle =>
      'Fotos de los miembros en el quiosco';

  @override
  String get featureKioskMode => 'Modo quiosco';

  @override
  String get featureKioskModeDesc =>
      'Cuentas de tableta de pared bloqueadas en el plano en vivo; los miembros actúan con credencial.';

  @override
  String get featureLess => 'Menos';

  @override
  String get featureLetterStandard => 'Estándar de carta para cada documento';

  @override
  String get featureLetterStandardDesc =>
      'Facturas, proformas, estados, acuerdos, informes de pagos y de consumo y recordatorios sin diseño se imprimen como carta estándar: membrete, destinatario en la ventana del sobre, cuerpo desde 90 mm, pie fijo.';

  @override
  String get featureLevelBooking => 'Reservas de mesa, oficina y planta';

  @override
  String get featureLevelBookingDesc =>
      'Reservar una mesa, oficina o planta entera como una sola reserva, con precio por media jornada. Concede el derecho por miembro.';

  @override
  String get featureLifecycleActive => 'Activa';

  @override
  String get featureLifecycleDeprecated => 'Obsoleta';

  @override
  String get featureLifecycleRetired => 'Retirada';

  @override
  String get featureManagedProfileAccess => 'Quién administra un perfil';

  @override
  String get featureManagedProfileAccessDesc =>
      'Cada perfil gestionado indica quién puede administrarlo: por rol, por personas nombradas o ambos. Desactivado: todo propietario y todo admin puede, como antes. La identidad está protegida en ambos casos, y cada consulta queda registrada para la persona que reciba el perfil.';

  @override
  String get featureManagedProfiles => 'Perfiles gestionados';

  @override
  String get featureManagedProfilesDesc =>
      'Los admins crean miembros sin cuenta, reservan y facturan por ellos y les entregan el perfil con un código personal que la persona canjea al unirse.';

  @override
  String get featureMaturityAlpha => 'Alfa';

  @override
  String get featureMaturityBeta => 'Beta';

  @override
  String get featureMaturityFilterAll => 'Todas las etapas';

  @override
  String get featureMaturityFilterLabel => 'Madurez';

  @override
  String featureMaturitySemantics(String maturity, String lifecycle) {
    return 'Madurez $maturity, $lifecycle';
  }

  @override
  String get featureMaturityStable => 'Estable';

  @override
  String get featureMaturityUnreviewed => 'Sin evaluar';

  @override
  String get featureMcpAccessDesc =>
      'Pone la interfaz MCP a disposición de este espacio, para que un asistente de IA pueda conectarse a DesKilo. Solo disponibilidad: activarla no concede nada a nadie. Cada persona sigue necesitando una autorización que el propietario configura y el administrador de la instancia aprueba, y cada operación sigue respondiendo a los permisos y reglas que la aplicación ya aplica. Desactivada, oculta los puntos de entrada MCP y rechaza las llamadas; las autorizaciones existentes siguen visibles y revocables.';

  @override
  String get featureMcpAccessTitle => 'Interfaz MCP';

  @override
  String get featureMemberAccountMenuDesc =>
      'Un miembro que no administra nada encuentra Mi cuenta en lugar de Ajustes — la misma pantalla, que ya solo le muestra su cuenta, su membresía y sus preferencias, con el nombre que lo dice. Quien tenga administración por su rol conserva Ajustes y todo lo que abre. Esto renombra una entrada; no concede ni retira nada.';

  @override
  String get featureMemberAccountMenuTitle => 'Los miembros ven Mi cuenta';

  @override
  String get featureMemberDataExportDesc =>
      'Cada miembro puede exportar sus datos en un archivo (RGPD art. 20) y abandonar el espacio con sus datos personales borrados (art. 17) desde Ajustes → Privacidad y datos.';

  @override
  String get featureMemberDataExportTitle => 'Exportación y borrado';

  @override
  String get featureMemberEnvironmentsDesc =>
      'Cuando invite a alguien, elija si también llega al espacio de producción. Se une al espacio de prueba en cualquier caso, y el rol todavía tiene que permitir el acceso a producción.';

  @override
  String get featureMemberEnvironmentsTitle =>
      'Elegir los entornos en los que se activa a una persona';

  @override
  String get featureMemberGettingStartedDesc =>
      'Tras unirse a un espacio o crearlo, un miembro ve una tarjeta compacta en el hub Reservar: en qué espacio está y un siguiente paso sugerido — elegir un horario para reservar, ver su membresía o abrir la ayuda — solo donde las funciones y sus permisos lo permiten. Ahora no la oculta; los Ajustes pueden volver a mostrarla. Nunca reserva, paga ni aprueba nada. Para quien configura el espacio, los ajustes muestran además, sección por sección, lo que falta para una primera reserva. Desactivada, oculta la tarjeta y esa lista y no cambia nada más.';

  @override
  String get featureMemberGettingStartedTitle => 'Tarjeta Primeros pasos';

  @override
  String get featureMemberNotifications => 'Notificaciones entre miembros';

  @override
  String get featureMemberNotificationsDesc =>
      'Mensajería entre miembros: conversaciones privadas y de grupo, confirmaciones de lectura, enlaces a una reserva o un espacio; los admins pueden notificar a todos los admins, propietario incluido.';

  @override
  String get featureMemberOriginDesc =>
      'Una línea discreta en un miembro que indica cómo empezó su afiliación: fundó el espacio, se unió por invitación, o un administrador le creó el perfil. No es un estado.';

  @override
  String get featureMemberOriginTitle => 'Cómo llegó cada miembro';

  @override
  String get featureMemberPageDesc =>
      'Una página por socio: foto y presencia, última conexión, reservas actuales y próximas, acciones rápidas (mensaje, WhatsApp, correo), tarjetas de contacto y finanzas y, para los admins, cada ajuste agrupado por tema con su valor actual. Desactivado: la hoja de perfil y la hoja de acciones de Socios y planes.';

  @override
  String get featureMemberPageTitle => 'Ficha de socio';

  @override
  String get featureMemberPaymentTerms => 'Condiciones de pago por miembro';

  @override
  String get featureMemberPaymentTermsDesc =>
      'El espacio fija las condiciones de pago por defecto; un miembro puede tener las suyas, visibles para él, cambiadas solo por una solicitud validada de un admin autorizado.';

  @override
  String get featureMemberReports => 'Informes de miembros';

  @override
  String get featureMemberReportsDesc =>
      'El acuerdo financiero y el informe mensual de pagos — autoservicio para miembros, enviables por miembro.';

  @override
  String get featureMembersDirectory => 'Directorio de miembros';

  @override
  String get featureMembersDirectoryDesc =>
      'La pestaña de comunidad: quién está, estados, presencia.';

  @override
  String get featureMessageForwardingDesc =>
      'Un mensaje puede reenviarse a otra conversación en la que participe quien lo reenvía. La copia indica su origen y su autor, la conversación original sabe quién lo reenvió y adónde, y un autor puede bloquear un mensaje contra el reenvío. Desactivado, no sale ningún reenvío de este espacio.';

  @override
  String get featureMessageForwardingTitle => 'Reenvío de mensajes';

  @override
  String get featureMessageGesturesDesc =>
      'Desliza un mensaje a la derecha para citarlo en tu respuesta; a la izquierda para retirar tu propio mensaje mientras nadie lo haya leído, tras una confirmación. Desactivado: los mensajes se borran manteniéndolos pulsados.';

  @override
  String get featureMessageGesturesTitle => 'Deslizar para citar o retirar';

  @override
  String get featureMessageMentionsDesc =>
      'En un grupo se puede mencionar a una persona por su nombre. Solo se puede mencionar a personas de la conversación, y la persona mencionada recibe un aviso aunque haya silenciado la conversación. Desactivado, un nombre escrito tras @ es texto normal y no avisa a nadie.';

  @override
  String get featureMessageMentionsTitle => 'Menciones en grupos';

  @override
  String get featureMessagesHubDesc =>
      'Una sola barra de bandeja (Todos / No leídos / Archivados y búsqueda), fijar, silenciar, archivar y marcar como no leído en un hilo, la conversación como página completa con separadores de fecha, un menú adjuntar y un borrador guardado en el compositor, una persona abierta con un toque. Desactivado: la bandeja de dos barras y el hilo en hoja.';

  @override
  String get featureMessagesHubTitle => 'Mensajes, renovados';

  @override
  String get featureMoneyTab => 'Pestaña Finanzas';

  @override
  String get featureMoneyTabDesc => 'Facturas mensuales, pagos y gastos.';

  @override
  String get featureMore => 'Más';

  @override
  String get featureMultiSite => 'Sedes';

  @override
  String get featureMultiSiteDesc =>
      'Varias direcciones: las plantas se agrupan por sede, cada sede tiene su dirección y su registro, cada socio una sede de referencia, y los documentos nombran la sede a la que se refieren. Desactivado: una sola dirección para todo el espacio.';

  @override
  String get featureNavigationStyle => 'Elección de navegación';

  @override
  String get featureNavigationStyleDesc =>
      'Cada miembro elige en sus ajustes cómo navega la app: la barra inferior clásica con el botón redondo Reservar, o el menú como en la web. Desactivado: cada dispositivo conserva el valor por defecto de su plataforma.';

  @override
  String get featureNfcBadges => 'Credenciales RFID / NFC';

  @override
  String get featureNfcBadgesDesc =>
      'Los miembros se registran en un quiosco acercando una tarjeta RFID/NFC. Requiere un dispositivo Android con NFC.';

  @override
  String get featureNfcSeatTagsDesc =>
      'Una etiqueta NFC/RFID física en una silla lleva a su asiento como la tarjeta QR impresa; el campo se rellena acercando el chip.';

  @override
  String get featureNfcSeatTagsTitle => 'Etiquetas NFC/RFID de las sillas';

  @override
  String get featureNotificationGroupingDesc =>
      'Los miembros pueden agrupar el hilo de notificaciones por tipo, día o miembro; tocar el símbolo del grupo vuelve a la lista plana.';

  @override
  String get featureNotificationGroupingTitle => 'Agrupación de notificaciones';

  @override
  String get featureNumberSequences => 'Series de numeración';

  @override
  String get featureNumberSequencesDesc =>
      'Cómo numera cada diario sus documentos — prefijo, año o mes, dígitos, reinicio del contador — en una sola pantalla para todas las series. Los números se asignan en la base de datos, sin huecos, esté activado o no; activado, el propietario cambia el formato para lo que venga.';

  @override
  String get featureOnlinePayments => 'Pagos en línea';

  @override
  String get featureOnlinePaymentsDesc =>
      'Permite a los miembros pagar su factura en línea (PayPal). Requiere configurar el proveedor de pago en el servidor.';

  @override
  String featureOptInAlsoOn(int count, String features) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'También se activan, porque son necesarios ($count): $features',
      one: 'También se activa, porque es necesario: $features',
    );
    return '$_temp0';
  }

  @override
  String featureOptInBody(String features) {
    return 'Aún no evaluada como estable: $features. Puede cambiar y tiene límites conocidos. Actívela solo si este espacio lo acepta.';
  }

  @override
  String get featureOptInConfirm => 'Activar';

  @override
  String featureOptInStage(String feature, String stage) {
    return '$feature: $stage';
  }

  @override
  String get featureOptInTitle => '¿Activar una función experimental?';

  @override
  String get featurePaymentRemindersDesc =>
      'Las facturas abiertas más allá del plazo configurado reciben sus niveles de recordatorio automáticamente — un aviso en el feed del miembro y una notificación, una vez al día. Desactivado: recordar sigue siendo una acción manual.';

  @override
  String get featurePaymentRemindersTitle =>
      'Recordatorios de pago automáticos';

  @override
  String get featurePdfExport => 'Exportar PDF';

  @override
  String get featurePdfExportDesc => 'Exportar la factura mensual como PDF.';

  @override
  String get featurePersonalInfo => 'Datos personales';

  @override
  String get featurePersonalInfoDesc =>
      'Los miembros introducen nombre, dirección postal, teléfono, e-mail e identificadores en Ajustes; facturas y cartas los imprimen en el bloque postal normalizado.';

  @override
  String get featurePlaceFeedbackDesc =>
      'Los miembros marcan puestos, mesas, oficinas y plantas como favoritos y los valoran de 0 a 5 estrellas. Un favorito es personal; una valoración muestra su media y cuántas hay, nunca quién. Un asistente puede listar los favoritos, reservar uno y registrar una valoración. Desactivado oculta corazones y estrellas y rechaza las escrituras; nada más depende de ello.';

  @override
  String get featurePlaceFeedbackTitle => 'Favoritos y valoraciones';

  @override
  String get featurePlanMemberPhotosDesc =>
      'Los asientos ocupados en la pestaña Plano y en el centro Reservar muestran la foto de perfil del ocupante en lugar de la inicial.';

  @override
  String get featurePlanMemberPhotosTitle =>
      'Fotos de los miembros en el plano';

  @override
  String get featurePlanObjectDeleteDesc =>
      'Los propietarios pueden eliminar plantas, oficinas, mesas y asientos aunque reservas pasadas hagan referencia a ellos: las reservas conservan una instantánea de texto para auditorías e informes.';

  @override
  String get featurePlanObjectDeleteTitle => 'Eliminar espacios con historial';

  @override
  String get featurePriceNegotiationsDesc =>
      'La tarifa es el valor por defecto; un miembro puede tener sus propias condiciones — cuota mensual, tarifa de exceso, descuento en suplementos, precios unitarios por servicio y paquete, porcentaje de ocupación — propuestas por quien tiene «Gestionar los acuerdos comerciales» y validadas según las reglas. Las ven el miembro, los propietarios y quienes tienen «Consultar los acuerdos comerciales»; cada consulta queda registrada.';

  @override
  String get featurePriceNegotiationsTitle => 'Negociaciones de precios';

  @override
  String get featurePublicHolidaysDesc =>
      'El propietario elige un año, ve los días festivos que se convertirían en días de cierre y confirma. Repetir un año no añade nada, y un mes que ya tiene factura se omite y se nombra: generar festivos nunca cambia una factura ya emitida.';

  @override
  String get featurePublicHolidaysTitle => 'Días festivos';

  @override
  String get featurePublicListings => 'Anuncio público del espacio';

  @override
  String get featurePublicListingsDesc =>
      'Publica solo los datos y planos elegidos, con propietarios visibles y contactos opcionales de administradores.';

  @override
  String get featurePushNotifications => 'Notificaciones push';

  @override
  String get featurePushNotificationsDesc =>
      'Entregar las confirmaciones pendientes en los dispositivos de los miembros.';

  @override
  String get featureQrBadgesDesc =>
      'Tarjetas de credencial QR imprimibles para el quiosco, junto a las tarjetas NFC/RFID.';

  @override
  String get featureQrBadgesTitle => 'Credenciales QR';

  @override
  String get featureRecordingPrivacyDesc =>
      'Para filmar o fotografiar este espacio. Cada nombre, correo electrónico, número de teléfono, dirección postal y fotografía se sustituye por una persona inventada antes de llegar a la pantalla, mientras que el plano, las reservas y los importes siguen siendo los reales. Un aviso lo indica en cada pantalla, y los formularios de identidad se niegan a guardar mientras esté activo.';

  @override
  String get featureRecordingPrivacyTitle => 'Modo grabación';

  @override
  String get featureRegionalFormatsDesc =>
      'Cada miembro elige cómo se le muestran los números, las fechas, el reloj y la zona horaria. Desactivado: todos leen en la región del idioma de la app, en 24 h, hora del espacio.';

  @override
  String get featureRegionalFormatsTitle => 'Región y formatos';

  @override
  String get featureReportDesignExchangeDesc =>
      'Cada diseño de informe puede escribirse en un archivo que se explica a sí mismo y volver a leerse. El archivo lleva el diseño y además qué significan sus campos, qué marcado admite y qué variables existen, así una persona o una herramienta puede editarlo fuera de la app y devolverlo. Un archivo de otro informe, o de una versión más nueva, se rechaza con el motivo. Desactivado: los diseños solo se editan en el editor.';

  @override
  String get featureReportDesignExchangeTitle =>
      'Exportar e importar diseños de informe';

  @override
  String get featureReportDesignerDesc =>
      'El editor de informes a pantalla completa: elementos editados en su sitio con su tipografía real, arrastrar para reordenar, una paleta de inserción, un selector de campos con búsqueda, deshacer y rehacer, tamaño y alineación de imágenes, una salvaguarda antes de descartar, plantillas y restablecer tras una confirmación, el error de la plantilla explicado, diseño y vista previa lado a lado en pantalla ancha. Desactivado: el editor en hoja.';

  @override
  String get featureReportDesignerTitle => 'Diseñador de informes';

  @override
  String get featureReportLayouts => 'Maquetas de informe posicionadas';

  @override
  String get featureReportLayoutsDesc =>
      'Diseñe un informe indicando dónde se sitúa cada elemento, en mm, cm, px o %; el PDF imprime exactamente eso. Un documento con maqueta la usa; los demás conservan sus bandas.';

  @override
  String get featureReportTexts => 'Textos de informes';

  @override
  String get featureReportTextsDesc =>
      'El propietario escribe textos (saludo, nota, párrafo legal) por idioma y los coloca en cualquier informe como text.clave — el texto cambia sin tocar el diseño.';

  @override
  String featureRequires(String feature) {
    return 'Requiere $feature';
  }

  @override
  String get featureRichMessageRefsDesc =>
      'Un mensaje puede apuntar a un aviso, al historial de validación que hay detrás y a una factura, un pago o un reembolso: cada referencia es un enlace que abre lo que nombra. Cada selector filtra mientras escribes. Desactivado: solo se pueden referenciar reservas y espacios.';

  @override
  String get featureRichMessageRefsTitle => 'Referencias en los mensajes';

  @override
  String get featureRoleAssignmentDesc =>
      'Muestra una sección Roles en la página de cada miembro para dar o retirar un rol, los miembros de cada rol, y permite a cada miembro ver lo que puede hacer aquí.';

  @override
  String get featureRoleAssignmentTitle => 'Asignación de roles';

  @override
  String get featureRoleManagement => 'Gestión de roles';

  @override
  String get featureRoleManagementDesc =>
      'La matriz central rol→permiso: el propietario decide qué permiso tiene cada rol; los demás consultan los suyos. Desactivada, simplemente aplican los valores por defecto.';

  @override
  String get featureScheduledExpensesDesc =>
      'Gastos recurrentes (internet, teléfono, electricidad): cualquier miembro programa uno con su regla (cada X días/semanas/meses/años, X veces o hasta una fecha); la programación se valida una vez, y cada vencimiento se presenta al miembro — el importe validado cuenta de inmediato, un importe distinto se explica y pasa la validación de gastos.';

  @override
  String get featureScheduledExpensesTitle => 'Gastos programados';

  @override
  String get featureSeatDayTimeline => 'La jornada de una plaza';

  @override
  String get featureSeatDayTimelineDesc =>
      'Una plaza reservada solo parte del día se dibuja parcialmente llena en el plano, y una plaza compartida por varias personas abre la jornada: quién la ocupa, cuándo y qué tramos quedan libres.';

  @override
  String get featureSeriesBooking => 'Reserva en serie';

  @override
  String get featureSeriesBookingDesc =>
      'Repetir una reserva a diario, semanalmente o en días laborables.';

  @override
  String get featureServices => 'Servicios';

  @override
  String get featureServicesDesc =>
      'Catálogo de servicios y registro de consumos.';

  @override
  String get featureSettlementFoldDesc =>
      'Las facturas reagrupadas en una desaparecen de las listas como iguales y se anidan bajo la factura de reagrupación, que lleva todas sus líneas. En una factura reagrupada toda operación está desactivada; solo queda su PDF, sellado con el número en que se reagrupó. Desactivado: las facturas reagrupadas siguen listadas junto a la de reagrupación.';

  @override
  String get featureSettlementFoldTitle => 'Facturas reagrupadas plegadas';

  @override
  String get featureSingleRoomLevelNamesDesc =>
      'Cuando una planta tiene una sola sala, las vistas de reserva nombran la planta en lugar de la sala: «2.ª planta · Mesa 3», no «Despacho 1 · Mesa 3». Una segunda sala recupera ambos nombres; el editor del plano muestra siempre las salas.';

  @override
  String get featureSingleRoomLevelNamesTitle =>
      'Nombrar por la planta una planta de una sola sala';

  @override
  String get featureSiteDocuments => 'Sedes en los documentos';

  @override
  String get featureSiteDocumentsDesc =>
      'Los documentos nombran la sede a la que se refieren: la dirección y el registro de la sede de referencia del socio como vendedor, y las demás sedes utilizadas en el mes en el detalle. Desactivado: la dirección del espacio en todos los documentos.';

  @override
  String get featureSpaceInquiriesDesc =>
      'Una persona con sesión iniciada que encuentra la página publicada puede escribir a los anfitriones: los propietarios y los administradores que eligieron ser contactos públicos. Los anfitriones se nombran antes de escribir, y solo esa persona y los anfitriones leen la conversación. Desactivado, desaparecen el botón y la vista Consultas, así que nadie abre una consulta nueva; las abiertas siguen en la bandeja de los anfitriones para responderlas y cerrarlas.';

  @override
  String get featureSpaceInquiriesTitle => 'Escribir a los anfitriones';

  @override
  String get featureSpaceQrCodes => 'Códigos QR de espacios';

  @override
  String get featureSpaceQrCodesDesc =>
      'Tarjetas QR imprimibles por puesto, mesa, oficina y planta — escanea para reservar o fichar.';

  @override
  String get featureSubscriptionInvoicesDesc =>
      'La cuota se factura antes del mes que paga, en la fecha que elijas. Desactivado: la cuota sigue en la factura del mes.';

  @override
  String get featureSubscriptionInvoicesTitle => 'Facturas de suscripción';

  @override
  String get featureSupplyExpensesDesc =>
      'Un gasto puede ser un suministro para el espacio (cápsulas de café, bolsas de aspiradora…): validado, repone o crea un servicio consumible con precio unitario, y los consumos descuentan el stock.';

  @override
  String get featureSupplyExpensesTitle => 'Suministros desde gastos';

  @override
  String get featureSurfaceCalendarHint => 'Qué ocurre, por día y por mes.';

  @override
  String get featureSurfaceDocumentsHint =>
      'Los archivos que el espacio guarda y comparte.';

  @override
  String get featureSurfaceEverywhere => 'Toda la aplicación';

  @override
  String get featureSurfaceEverywhereHint =>
      'Cambia el comportamiento de la aplicación, estés donde estés.';

  @override
  String get featureSurfaceKioskHint =>
      'La tableta de la entrada, las credenciales y los escaneos.';

  @override
  String get featureSurfaceMembersHint =>
      'Quién está en el espacio, sus perfiles y sus roles.';

  @override
  String get featureSurfaceMessagesHint =>
      'Conversaciones, avisos y lo que llega al teléfono.';

  @override
  String get featureSurfaceMoneyHint =>
      'Extractos, pagos, facturas y de qué se componen.';

  @override
  String get featureSurfaceReports => 'Documentos que se imprimen';

  @override
  String get featureSurfaceReportsHint =>
      'Facturas, extractos y cartas, y su aspecto en papel.';

  @override
  String get featureSurfaceReserveHint =>
      'Reservar un puesto, el plano, la llegada.';

  @override
  String get featureSurfaceSettingsHint => 'Cómo está configurado el espacio.';

  @override
  String get featureTaskRecorderDesc =>
      'Permite grabar los pasos de una tarea en las pantallas de este espacio, en el propio dispositivo, revisarlos y exportar un archivo sin ningún valor escrito. No se envía nada. Desactivado: nadie graba aquí.';

  @override
  String get featureTaskRecorderTitle => 'Grabador de tareas';

  @override
  String get featureTierCore => 'Esencial';

  @override
  String get featureTierCoreDesc =>
      'Lo que todo espacio necesita. Activo desde el primer día.';

  @override
  String get featureTierPlatform => 'Plataforma';

  @override
  String get featureTierPlatformDesc =>
      'Pedido, nunca supuesto. Active lo que este espacio realmente hace.';

  @override
  String get featureUiAnimationsDesc =>
      'Transiciones suaves y animaciones de estado en toda la aplicación. Desactivado, cada cambio es instantáneo; el ajuste de reducción de movimiento del dispositivo siempre prevalece.';

  @override
  String get featureUiAnimationsTitle => 'Animaciones de la interfaz';

  @override
  String get featureUniqueMonogramsDesc =>
      'Un avatar sin foto muestra iniciales que pertenecen a un solo miembro: inicial del nombre y del apellido, una letra más si dos coinciden, y números solo como último recurso. Desactivado: solo la primera letra, repetida en todos los que la comparten.';

  @override
  String get featureUniqueMonogramsTitle => 'Iniciales de avatar distintas';

  @override
  String get featureUsageInvoicesDesc =>
      'Cuando el mes termina, lo que realmente costó más allá de la suscripción — excesos, suplementos, servicios — se factura aparte. Desactivado: eso sigue en la factura del mes.';

  @override
  String get featureUsageInvoicesTitle => 'Facturas de fin de mes';

  @override
  String get featureUsageRecordsDesc =>
      'Cada reserva contada deja un registro: la ventana reservada, el tiempo realmente presente y lo que se factura. Una reserva a la que nadie llegó se factura entera. Quien sale antes puede pedir que el tiempo no usado deje de facturarse, y lo decide otra persona, nunca quien lo pide. Desactivado: sin registros ni corrección.';

  @override
  String get featureUsageRecordsTitle => 'Registros de uso';

  @override
  String get featureUsageReport => 'Informe de consumo';

  @override
  String get featureUsageReportDesc =>
      'A fin de mes el miembro recibe lo que pagó su participación, lo que consumió realmente y lo que queda o excede — a partir de los registros de uso, como carta.';

  @override
  String get featureValidationChainDesc =>
      'Una regla de validación puede pedir sus validaciones una tras otra, cada paso solicitado cuando el anterior ha pasado, y puede permitir que la propiedad —nunca un admin— valide su propio acto. Desactivado: todo se pide a la vez y nadie valida su propio evento.';

  @override
  String get featureValidationChainTitle => 'Validaciones encadenadas';

  @override
  String get featureValidationScopesDesc =>
      'Cada regla de validación nombra quién valida: los admins, personas designadas de cualquier rol, o todos los miembros — y cuántos. Desactivado: propietario y admins como antes.';

  @override
  String get featureValidationScopesTitle => 'Validadores por rol o persona';

  @override
  String get featureVatCounterparty => 'IVA según el cliente';

  @override
  String get featureVatCounterpartyDesc =>
      'Quién es el comprador a efectos de IVA, fijado en cada miembro: IVA nacional, inversión del sujeto pasivo, fuera de la UE o exento con el motivo impreso. Desactivado: solo la regla automática.';

  @override
  String get featureVatDeclarationsDesc =>
      'Generar la declaración periódica de IVA desde las facturas emitidas, mapearla al formulario oficial y transmitirla o exportarla.';

  @override
  String get featureVatDeclarationsTitle => 'Declaraciones de IVA';

  @override
  String get featureVatGroups => 'Grupos de IVA';

  @override
  String get featureVatGroupsDesc =>
      'Cada tipo de IVA lleva el grupo fiscal de lo que grava — general, intermedio, reducido, superreducido, cero, exento, no sujeto, envase retornable, con impuestos especiales — con la categoría y la mención de exención que el grupo implica. Desactivado: simples porcentajes.';

  @override
  String get featureVatManagementDesc =>
      'El editor de tipos de IVA y los selectores de tipo en servicios, bonos, accesorios y tarifas. Desactivado oculta la configuración; los tipos guardados siguen aplicándose.';

  @override
  String get featureVatManagementTitle => 'Gestión del IVA';

  @override
  String get featureVatRateHistory => 'Versiones de los tipos de IVA';

  @override
  String get featureVatRateHistoryDesc =>
      'Un tipo es una familia de versiones fechadas: un cambio por ley añade el nuevo valor desde su fecha, el antiguo permanece en toda prestación anterior y nada se reasigna. Desactivado: un valor por tipo.';

  @override
  String get featureVatReport => 'Informe de IVA';

  @override
  String get featureVatReportDesc =>
      'Cada posición gravable de un mes o periodo — documento, cliente, base, tipo, IVA, total, categoría — con subtotales por tipo, como carta y como CSV para el contable.';

  @override
  String get featureWhatsappIntegration => 'Integración con WhatsApp';

  @override
  String get featureWhatsappIntegrationDesc =>
      'Los miembros comparten su número de WhatsApp en su perfil; un toque en un miembro abre el chat; el enlace del grupo en el directorio. Sin integración de WhatsApp en el servidor.';

  @override
  String get featureWorkingHours => 'Horario laboral';

  @override
  String get featureWorkingHoursDesc =>
      'Configura la jornada laboral y ofrece reservas por horas exactas; desactivado se aplican los valores 8:00–17:00.';

  @override
  String get featureWorkspaceBrandingDesc =>
      'El espacio elige un color de marca del que la aplicación deriva sus temas claro y oscuro, y los colores de relleno de sus salas. Un color que haría ilegible la aplicación se rechaza con el motivo; la paleta del producto sigue siendo la predeterminada.';

  @override
  String get featureWorkspaceBrandingTitle => 'Colores del espacio';

  @override
  String get featureWorkspaceLibraryDesc =>
      'Guarde el plano de este espacio y cómo funciona como plantilla, elija quién puede verla, invite a personas por e-mail y parta de lo que otros ofrecen.';

  @override
  String get featureWorkspaceLibraryTitle => 'Biblioteca de espacios';

  @override
  String get featureWorkspaceStatus => 'Situación del espacio';

  @override
  String get featureWorkspaceStatusDesc =>
      'Lo que el espacio facturó, cobró, reembolsó y repartió en un periodo, socio por socio — en pantalla para propietarios y admins, y como informe imprimible. Desactivado: sin vista de situación.';

  @override
  String get featureWorkspaceVocabularyDesc =>
      'El espacio puede renombrar, por idioma, un conjunto reducido y aprobado de palabras del producto: una plaza, las etiquetas de la leyenda, las pestañas. Todo lo demás conserva la redacción del producto, y un espacio que no renombra nada se ve exactamente igual que antes.';

  @override
  String get featureWorkspaceVocabularyTitle => 'Vocabulario del espacio';

  @override
  String get featuresFilterChanged => 'Modificadas';

  @override
  String get featuresNoMatch => 'Ninguna función coincide.';

  @override
  String get featuresSearchLabel => 'Buscar funciones';

  @override
  String get featuresTitle => 'Funciones';

  @override
  String get featuresViewProcesses => 'Procesos';

  @override
  String get featuresViewSwitches => 'Interruptores';

  @override
  String get fecAccountBank => 'Banco';

  @override
  String get fecAccountCustomers => 'Clientes';

  @override
  String get fecAccountExpenses => 'Gastos';

  @override
  String get fecAccountRevenue => 'Ventas';

  @override
  String get fecAccountVat => 'IVA recaudado';

  @override
  String get fecAccountsIntro =>
      'Un FEC está hecho de asientos contables, así que necesita números de cuenta. Estas son las cuentas del plan contable francés — cámbialas por las de tu asesoría.';

  @override
  String get fecAccountsTitle => 'Cuentas a utilizar';

  @override
  String get fecMissingSiren =>
      'El FEC se nombra con tu número de registro — rellénalo primero en Identidad legal.';

  @override
  String get federationActionExistingAccount =>
      'Iniciar sesión en mi cuenta existente';

  @override
  String get federationActionReviewServer => 'Revisar el servidor';

  @override
  String get federationCancel => 'Cancelar';

  @override
  String get federationClose => 'Cerrar';

  @override
  String get federationContinue => 'Continuar con Deskilo';

  @override
  String federationDetailAuthority(String host) {
    return 'Autoridad de identidad: $host';
  }

  @override
  String federationDetailServer(String host) {
    return 'Servidor: $host';
  }

  @override
  String get federationDetails => 'Detalles técnicos';

  @override
  String get federationFailureBrowser =>
      'No se pudo abrir el navegador. Comprueba que hay un navegador disponible y vuelve a intentarlo.';

  @override
  String get federationFailureExpired =>
      'Este inicio de sesión tardó demasiado y ha caducado. Vuelve a empezarlo.';

  @override
  String get federationFailureIncompatible =>
      'Este servidor no acepta este inicio de sesión de Deskilo. Revisa la dirección del servidor o consulta a su administrador.';

  @override
  String get federationFailureNetwork =>
      'No se pudo contactar con el servidor, así que el inicio de sesión no se completó. Revisa tu conexión y vuelve a intentarlo.';

  @override
  String get federationFailureProviderMissing =>
      'El inicio de sesión con Deskilo no está configurado en este servidor. Pide a su administrador que lo active.';

  @override
  String get federationFailureRefused =>
      'El inicio de sesión se canceló o se rechazó en el navegador. No ha cambiado nada; puedes volver a intentarlo.';

  @override
  String get federationFailureUnlinked =>
      'Esta cuenta de Deskilo coincide con una cuenta de aquí que aún no está vinculada. Inicia sesión en esa cuenta y vincula Deskilo en Cuentas vinculadas. No se fusiona nada hasta que el servidor lo confirme.';

  @override
  String get federationFailureWrongAccount =>
      'Tu navegador inició sesión con otra cuenta de Deskilo. Cambia de cuenta en el navegador y vuelve a intentarlo.';

  @override
  String federationPurpose(String server) {
    return 'Tu navegador confirma tu cuenta de Deskilo y luego te devuelve a $server. Tus membresías y tu historial aquí no cambian.';
  }

  @override
  String get federationRetry => 'Reintentar';

  @override
  String get federationStageCompleting => 'Completando el inicio de sesión…';

  @override
  String get federationStageOpening => 'Abriendo el inicio de sesión…';

  @override
  String get federationStageWaiting =>
      'Esperando el inicio de sesión en tu navegador…';

  @override
  String get fieldProblemNotAChoice => 'Elige de la lista.';

  @override
  String get fieldProblemNotADate => 'Una fecha, por favor.';

  @override
  String get fieldProblemNotANumber => 'Un número, por favor.';

  @override
  String get fieldProblemNotAPhone => 'Eso no es un número de teléfono.';

  @override
  String get fieldProblemNotAUrl => 'Eso no es una dirección web.';

  @override
  String get fieldProblemNotAnEmail => 'Eso no es una dirección de correo.';

  @override
  String get fieldProblemNotWhole => 'Un número entero, por favor.';

  @override
  String get fieldProblemRequired => 'Responde, por favor.';

  @override
  String fieldProblemTooEarly(String date) {
    return 'No antes del $date.';
  }

  @override
  String fieldProblemTooLarge(String max) {
    return 'Como máximo $max.';
  }

  @override
  String fieldProblemTooLate(String date) {
    return 'No después del $date.';
  }

  @override
  String fieldProblemTooLong(int count) {
    return 'Como máximo $count caracteres.';
  }

  @override
  String fieldProblemTooShort(int count) {
    return 'Al menos $count caracteres.';
  }

  @override
  String fieldProblemTooSmall(String min) {
    return 'Al menos $min.';
  }

  @override
  String get financesAllSpaces => 'Todos los espacios';

  @override
  String get financesAutomatic => 'automático';

  @override
  String get financesAwaitingValidation => 'Pago en validación';

  @override
  String get financesDevSection =>
      'Espacios de desarrollo — datos de prueba, no contados arriba';

  @override
  String financesDueOn(String date) {
    return 'Vence el $date';
  }

  @override
  String get financesFullHistory =>
      'Historial completo, uso y otros servidores';

  @override
  String financesLinkAction(String space) {
    return 'Abrir para $space';
  }

  @override
  String get financesLinkBody =>
      'Tus facturas, recordatorios y pagos de todos tus espacios están juntos en Yo › Finanzas.';

  @override
  String get financesLinkTitle => 'Tus documentos están en Yo';

  @override
  String get financesNoReminders => 'Ningún recordatorio recibido.';

  @override
  String get financesNothingOwed => 'Nada que pagar — está al día.';

  @override
  String get financesNothingPaid => 'Aún no hay facturas saldadas.';

  @override
  String get financesOutstanding => 'Pendiente';

  @override
  String financesOverdueCount(int count) {
    return '$count vencidas';
  }

  @override
  String financesOverdueSince(String date) {
    return 'Vencida desde el $date';
  }

  @override
  String get financesPaid => 'Pagadas';

  @override
  String get financesPartlyPaid => 'Pagada en parte';

  @override
  String get financesPayments => 'Pagos';

  @override
  String financesRemindedTimes(int count) {
    return 'Recordada ×$count';
  }

  @override
  String financesReminderLevel(int level) {
    return 'Recordatorio $level';
  }

  @override
  String get financesReminders => 'Recordatorios';

  @override
  String get financesStateClosed => 'Cerrada';

  @override
  String get financesStatePaid => 'Pagada';

  @override
  String get financesStateRefunded => 'Reembolsada';

  @override
  String get financesTitle => 'Finanzas';

  @override
  String get financesToPay => 'Por pagar';

  @override
  String get gettingStartedActionChooseDay => 'Elegir otro día';

  @override
  String get gettingStartedActionChooseTime =>
      'Elegir un horario para reservar';

  @override
  String get gettingStartedActionFinishSetup => 'Terminar la configuración';

  @override
  String get gettingStartedActionHelp => 'Ayuda para este espacio';

  @override
  String get gettingStartedActionMembership => 'Ver mi membresía';

  @override
  String gettingStartedAllowance(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Puedes tener $count reservas a la vez.',
      one: 'Puedes tener una reserva a la vez.',
    );
    return '$_temp0';
  }

  @override
  String get gettingStartedAvailabilityUnknown =>
      'No se pudo cargar la disponibilidad. La ayuda explica cómo funcionan las reservas aquí.';

  @override
  String gettingStartedBooked(String id, String state) {
    return 'Tu reserva $id está $state. Tu membresía muestra qué más está incluido.';
  }

  @override
  String get gettingStartedClosedToday =>
      'El espacio está cerrado el día seleccionado. Elige otro día para ver qué está libre.';

  @override
  String get gettingStartedEnvDev => 'Espacio de desarrollo';

  @override
  String get gettingStartedEnvProd => 'Espacio de producción';

  @override
  String get gettingStartedMembershipUnknown =>
      'No se pudo cargar tu membresía ahora mismo. La ayuda explica cómo funciona este espacio.';

  @override
  String get gettingStartedNoSpaces =>
      'Aquí todavía no se puede reservar nada. Tu membresía muestra lo que incluye tu acceso.';

  @override
  String get gettingStartedNotNow => 'Ahora no';

  @override
  String get gettingStartedReadyToBook =>
      'El espacio está abierto ese día. Elige un horario y un puesto en el plano — no se reserva nada hasta que confirmes.';

  @override
  String get gettingStartedReopen => 'Primeros pasos';

  @override
  String get gettingStartedSemantics =>
      'Primeros pasos: un siguiente paso sugerido';

  @override
  String gettingStartedSetupIncomplete(String step) {
    return 'Antes de que alguien pueda reservar aquí: $step.';
  }

  @override
  String get gettingStartedStandingAdmin => 'Eres administrador aquí.';

  @override
  String get gettingStartedStandingMember => 'Eres miembro aquí.';

  @override
  String get gettingStartedStandingOwner => 'Eres propietario de este espacio.';

  @override
  String get gettingStartedStateCancelled => 'cancelada';

  @override
  String get gettingStartedStateCheckedIn => 'registrada';

  @override
  String get gettingStartedStateCompleted => 'completada';

  @override
  String get gettingStartedStateReleased => 'liberada';

  @override
  String get gettingStartedStateReserved => 'reservada';

  @override
  String gettingStartedTitle(String workspace) {
    return 'Primeros pasos en $workspace';
  }

  @override
  String get groupAnnounceOnly => 'Solo los admins pueden escribir';

  @override
  String get groupAnnounceOnlyHint => 'Todos leen; solo los admins escriben.';

  @override
  String get groupCreate => 'Crear grupo';

  @override
  String get groupDescription => 'Descripción';

  @override
  String get groupDescriptionAdd => 'Añadir una descripción';

  @override
  String get groupDescriptionTitle => 'Descripción del grupo';

  @override
  String get groupMakeAdmin => 'Hacer admin';

  @override
  String get groupName => 'Nombre del grupo';

  @override
  String get groupNeedsPeople => 'Añada al menos una persona.';

  @override
  String get groupNew => 'Nuevo grupo';

  @override
  String get groupNewTitle => 'Nuevo grupo';

  @override
  String get groupPeople => 'Personas del grupo';

  @override
  String get groupPickPeople => 'Añadir personas';

  @override
  String get groupPostingClosed =>
      'Solo los admins pueden escribir en este grupo.';

  @override
  String get groupRemoveAdmin => 'Quitar admin';

  @override
  String get groupRename => 'Renombrar grupo';

  @override
  String get groupRenameTitle => 'Nombre del grupo';

  @override
  String get guideActionConfirmBooking =>
      'confirme la reserva y espere la respuesta';

  @override
  String get guideActionOpenReserve => 'abra Reservar';

  @override
  String get guideActionSelectDate => 'elija el día';

  @override
  String get guideActionSelectPeriod => 'elija el periodo';

  @override
  String get guideActionSelectResource =>
      'elija un sitio en el plano o en la lista';

  @override
  String get guideBookingRefusedRecovery =>
      'Se rechazó la reserva (sitio ocupado o una regla lo impide). Elija otro sitio o periodo y vuelva a confirmar.';

  @override
  String get guideBuiltinBooking => 'Reservar un sitio';

  @override
  String get guideBuiltinBookingIntro =>
      'Esta guía muestra cómo reservar un sitio: elija el día y el periodo, un sitio y confirme. No se reserva nada hasta que confirme.';

  @override
  String get guideHostBack => 'Atrás';

  @override
  String get guideHostBlocked =>
      'Resuelva primero el mensaje en pantalla; la guía espera.';

  @override
  String get guideHostClose => 'Cerrar';

  @override
  String get guideHostCommand => 'Confirme y espere el resultado.';

  @override
  String get guideHostCompleted => 'Guía completada.';

  @override
  String guideHostDoAction(String action) {
    return 'A continuación: $action.';
  }

  @override
  String get guideHostDone => 'Hecho';

  @override
  String get guideHostFillField => 'Rellene el campo resaltado y salga de él.';

  @override
  String guideHostFillLabel(String label) {
    return 'Rellene «$label» y salga del campo.';
  }

  @override
  String get guideHostGoToPage => 'Ir a la página';

  @override
  String get guideHostInstruction => 'Lea esto y márquelo como hecho.';

  @override
  String get guideHostManual =>
      'Haga este paso usted mismo y márquelo como hecho.';

  @override
  String guideHostManualProtected(String category) {
    return 'Esta parte ocurre en una pantalla protegida ($category). Hágala usted mismo y márquela como hecha.';
  }

  @override
  String get guideHostMinimize => 'Minimizar la guía';

  @override
  String get guideHostNotOnScreen =>
      'Este control no está en esta pantalla. Vaya a la pantalla del paso anterior o revise la guía.';

  @override
  String guideHostOpenLabel(String label) {
    return 'Abra «$label».';
  }

  @override
  String get guideHostOpenScreen => 'Abra la siguiente pantalla.';

  @override
  String get guideHostPausedFeature =>
      'En pausa: la grabadora de tareas está desactivada en este espacio.';

  @override
  String get guideHostPausedScope =>
      'En pausa: cambió la cuenta o el espacio. La guía solo continúa donde empezó.';

  @override
  String get guideHostRecovery =>
      'Se rechazó. Siga estos pasos y vuelva a intentarlo.';

  @override
  String guideHostRestore(int current, int total) {
    return 'Mostrar la guía (paso $current de $total)';
  }

  @override
  String get guideHostResume => 'Reanudar';

  @override
  String get guideHostShowMe => 'Muéstramelo';

  @override
  String get guideHostSkip => 'Omitir';

  @override
  String get guideHostStatusAcknowledged => 'Confirmado';

  @override
  String get guideHostStatusDone => 'Hecho';

  @override
  String get guideHostStatusPending => 'Pendiente';

  @override
  String get guideHostStatusSkipped => 'Omitido';

  @override
  String get guideHostStatusWaiting => 'Esperando';

  @override
  String guideHostStepOf(int current, int total) {
    return 'Paso $current de $total';
  }

  @override
  String get guideHostSteps => 'Todos los pasos';

  @override
  String get guideHostStop => 'Detener la guía';

  @override
  String get guideHostStopped => 'Guía detenida. No se deshizo nada.';

  @override
  String get guideHostTapControl => 'Toque el control resaltado.';

  @override
  String guideHostTapLabel(String label) {
    return 'Toque «$label».';
  }

  @override
  String get guideHostTitle => 'Tarea guiada';

  @override
  String get guideHostUncertain =>
      'No llegó la respuesta. Compruebe si ocurrió antes de volver a intentarlo.';

  @override
  String get guideHostWaiting => 'Esperando el resultado…';

  @override
  String get guideStart => 'Iniciar la guía';

  @override
  String get guideStartNotRunnable =>
      'Esta guía nombra pasos que esta versión de la aplicación no conoce; puede leerse, no seguirse.';

  @override
  String get guideStartRefused =>
      'Esta guía no puede iniciarse aquí: inicie sesión y active la grabadora de tareas en este espacio.';

  @override
  String handoffAmountOutOfRange(String number) {
    return '$number: un total demasiado grande para transmitirse con exactitud';
  }

  @override
  String get handoffBlocked =>
      'Este archivo no puede entregarse hasta que se corrija el origen.';

  @override
  String get handoffChanged =>
      'Las facturas cambiaron mientras las revisaba. Vuelva a exportar para ver las cuentas actuales.';

  @override
  String handoffDuplicate(String number) {
    return '$number: aparece dos veces en el origen';
  }

  @override
  String handoffExcludedSettlements(String count) {
    return '$count resumen(es) de liquidación omitido(s): sus facturas ya figuran';
  }

  @override
  String handoffIncluded(String count) {
    return '$count documento(s) en el archivo';
  }

  @override
  String get handoffIssued => 'Emitidas';

  @override
  String handoffMissingCurrency(String number) {
    return '$number: sin moneda';
  }

  @override
  String handoffOrphanMatch(String key) {
    return 'Un pago ($key) no corresponde a ningún documento de esta exportación';
  }

  @override
  String handoffOverpaid(String number) {
    return '$number: pagado por encima de lo facturado';
  }

  @override
  String handoffPayments(String confirmed, String pending) {
    return 'Pagado: $confirmed confirmado, $pending pendiente';
  }

  @override
  String handoffRowMismatch(String detail) {
    return 'Las filas del archivo no coinciden con los documentos ($detail)';
  }

  @override
  String get handoffSave => 'Guardar archivo e informe';

  @override
  String get handoffTitle => 'Antes de guardar';

  @override
  String handoffUnsupportedCurrency(String number) {
    return '$number: su moneda no tiene un número de decimales verificado';
  }

  @override
  String get handoffVoided => 'Anuladas';

  @override
  String get helpContents => 'Índice';

  @override
  String get helpDotTooltip => 'Abrir la guía';

  @override
  String get helpGuidedTasks => 'Tareas guiadas';

  @override
  String get helpHintAvailability =>
      'Define los días de apertura y el horario, y añade días de cierre que nadie puede reservar.';

  @override
  String get helpHintAvailabilityTip2 =>
      'La granularidad de reserva decide la forma de una franja: medios días, días completos, rejillas de minutos u horarios libres.';

  @override
  String get helpHintAvailabilityTip3 =>
      'El inicio del día, el límite del medio día y el fin del día rigen cada franja: reserva, registro y facturación los siguen.';

  @override
  String get helpHintAvailabilityTip4 =>
      'Tres políticas de reserva endurecen o relajan las reglas: reservas pasadas, minutos confinados al horario laboral y salida por un admin.';

  @override
  String get helpHintAvailabilityTopic => 'Disponibilidad';

  @override
  String get helpHintBadges =>
      'Emite una credencial QR imprimible o registra una tarjeta NFC; revoca credenciales perdidas en cualquier momento.';

  @override
  String get helpHintBadgesTip2 =>
      'Registra una tarjeta acercándola al dispositivo: cualquier chip legible sirve, y el diálogo indica a qué espacio se asocia.';

  @override
  String get helpHintBadgesTip3 =>
      'Guarda una credencial QR como PDF para imprimir diez copias tamaño tarjeta en una página A4, con repuestos incluidos.';

  @override
  String get helpHintBadgesTip4 =>
      'Revoca una credencial perdida en cualquier momento; desliza una credencial revocada hacia la derecha para eliminarla definitivamente.';

  @override
  String get helpHintBadgesTopic => 'credenciales RFID';

  @override
  String get helpHintCalendar =>
      'Elija un día o un periodo: todo lo fechado que puede ver, en una lista, cada fila abre su origen.';

  @override
  String get helpHintCalendarTip2 =>
      'Cambie de Día a Periodo para ver una semana o un mes de golpe — las flechas avanzan el tamaño de su selección.';

  @override
  String get helpHintCalendarTip3 =>
      'Toque un chip de tipo para ver solo eso: reservas, avisos, mensajes, facturas, pagos, consumos, recordatorios.';

  @override
  String get helpHintCalendarTip4 =>
      'Cada fila abre su origen — la reserva, la conversación, el aviso, la factura o ese mes en Finanzas.';

  @override
  String get helpHintCalendarTip4Topic => 'Cómo se comporta la reserva';

  @override
  String get helpHintCalendarTip5 =>
      'El escudo muestra quién puede ver cada tipo y quién miró realmente sus finanzas.';

  @override
  String get helpHintCalendarTip5Topic => 'Privacidad';

  @override
  String get helpHintCalendarTopic => 'Calendario';

  @override
  String get helpHintDismiss => 'Ocultar consejo';

  @override
  String get helpHintEditor =>
      'Dibuja salas y escritorios, estampa los asientos y toca dos veces un asiento para editar sus propiedades.';

  @override
  String get helpHintEditorTip2 =>
      'Elige Oficina o Mesa en la barra de herramientas y arrastra sobre la cuadrícula para dibujarla; Seleccionar mueve y redimensiona lo existente.';

  @override
  String get helpHintEditorTip3 =>
      'La herramienta Asiento estampa asientos en los escritorios; la ficha de un asiento fija su orientación, tipo de silla, accesorios y un bloqueo por mantenimiento.';

  @override
  String get helpHintEditorTip4 =>
      'Da a un asiento su etiqueta NFC/RFID desde su ficha: acerca el chip al teléfono y el campo se rellena solo.';

  @override
  String get helpHintEditorTip5 =>
      'Imprime una tarjeta QR para cada asiento, escritorio, oficina y planta: elige el tamaño de la tarjeta y qué muestra antes de exportar.';

  @override
  String get helpHintEditorTip5Topic => 'Códigos QR de espacios';

  @override
  String get helpHintEditorTopic => 'editor del espacio';

  @override
  String get helpHintEvents =>
      'Todo lo ocurrido, en un solo hilo. Las decisiones que te esperan van arriba; los filtros acotan el resto.';

  @override
  String get helpHintEventsTip2 =>
      'Los chips de filtro recuerdan tu elección entre visitas, y el chip No leídos reduce la lista a los mensajes sin leer.';

  @override
  String get helpHintEventsTip3 =>
      'Agrupa el hilo por tipo, día o miembro desde el menú Agrupar por; toca el símbolo de grupo para volver a la lista plana.';

  @override
  String get helpHintEventsTip4 =>
      'Las decisiones pendientes quedan fijadas arriba con Aceptar y rechazar, y nadie valida nunca su propio evento.';

  @override
  String get helpHintEventsTopic => 'Eventos';

  @override
  String get helpHintFeatures =>
      'Activa o desactiva funciones del espacio: la app de cada miembro se actualiza al instante.';

  @override
  String get helpHintFeaturesTip2 =>
      'La lista es jerárquica: una función que necesita otra aparece sangrada debajo y se atenúa mientras su padre está apagado.';

  @override
  String get helpHintFeaturesTip3 =>
      'Apagar un padre saca todo su subárbol de la app; las elecciones guardadas de los hijos vuelven intactas con el padre.';

  @override
  String get helpHintFeaturesTip4 =>
      'La entrada de ajustes de una función solo aparece mientras está activada; la pantalla Funciones, en cambio, siempre queda accesible.';

  @override
  String get helpHintFeaturesTopic => 'Funciones';

  @override
  String get helpHintLearnMore => 'Más información';

  @override
  String get helpHintMembers =>
      'Invita a miembros, ajusta su plan y su rol, y gestiona sus credenciales.';

  @override
  String get helpHintMembersTip2 =>
      'Toca un miembro para su ficha de gestión: suscripción, límite de reservas, credenciales, servicios y más en un solo lugar.';

  @override
  String get helpHintMembersTip3 =>
      'Las credenciales son por miembro: emite una credencial QR imprimible o registra su tarjeta NFC acercándola al dispositivo.';

  @override
  String get helpHintMembersTip3Topic => 'credenciales RFID';

  @override
  String get helpHintMembersTip4 =>
      'Nombrar admin concede permisos tras validación; la matriz de roles bajo Gestión de roles decide qué puede hacer cada rol.';

  @override
  String get helpHintMembersTip4Topic => 'Gestión de roles';

  @override
  String get helpHintMembersTipNegotiation =>
      'Los precios propios de un miembro: abre su ficha → Negociación de precios, indica la cuota, el exceso o el descuento acordados, y los validadores de la regla lo confirman.';

  @override
  String get helpHintMembersTipNegotiationTopic => 'Negociaciones de precios';

  @override
  String get helpHintMembersTopic => 'Miembros y planes';

  @override
  String get helpHintMessages =>
      'Todas las conversaciones en una lista, la más reciente arriba. Toque el lápiz para escribir a alguien o crear un grupo.';

  @override
  String get helpHintMessagesTip2 =>
      'Elija una persona para un chat privado, o varias para crear un grupo — el campo del nombre aparece a partir de dos, y ese nombre es único aquí: nadie tiene que adivinar a qué «Equipo» escribe.';

  @override
  String get helpHintMessagesTip3 =>
      'Toque un nombre en la parte superior de un chat para ver su perfil: la reserva de hoy, si ha registrado su entrada, y cómo contactarle.';

  @override
  String get helpHintMessagesTip4 =>
      'La búsqueda encuentra miembros, grupos y las palabras dentro de los mensajes — un resultado le lleva directamente allí.';

  @override
  String get helpHintMessagesTip5 =>
      'Enlace una reserva o un espacio en el mensaje en vez de describirlo; quien lo lea lo toca y llega al correcto.';

  @override
  String get helpHintMessagesTopic => 'Mensajes';

  @override
  String get helpHintMoney =>
      'Tu factura mensual: recorre los meses con las flechas; paga, exporta o comparte desde aquí.';

  @override
  String get helpHintMoneyDocuments =>
      'Tu papeleo: tus condiciones, el informe de pagos, el extracto del mes en PDF, la biblioteca de documentos.';

  @override
  String get helpHintMoneyDocumentsTip3 =>
      'Mis condiciones es tu acuerdo financiero vigente — plan, tarifa, extras — como documento para conservar.';

  @override
  String get helpHintMoneyDocumentsTopic => 'La vista Documentos';

  @override
  String get helpHintMoneyInvoices =>
      'Tus facturas: lo que está abierto y para cuándo, cada factura que te emitieron con su estado, un toque al detalle y al pago.';

  @override
  String get helpHintMoneyInvoicesTip2 =>
      'Pasado el plazo de pago del espacio, una factura abierta se lee aquí como vencida, y los niveles de recordatorio configurados por el propietario llegan solos — en tu feed y como notificación.';

  @override
  String get helpHintMoneyInvoicesTip2Topic =>
      'Recordatorios de pago automáticos';

  @override
  String get helpHintMoneyInvoicesTopic => 'La vista Facturas';

  @override
  String get helpHintMoneyPayments =>
      'Liquidar y pedir: el saldo, cómo pagarlo o pagar en línea, registrar un pago — y enviar un gasto, pedir medios días o añadir un consumo.';

  @override
  String get helpHintMoneyPaymentsTip2 =>
      'Registra un pago con la fecha del movimiento y el mes que salda — la otra parte confirma.';

  @override
  String get helpHintMoneyPaymentsTip3 =>
      'Pagar en línea liquida lo debido al instante; la tarjeta de instrucciones muestra la vía manual con la referencia a indicar.';

  @override
  String get helpHintMoneyPaymentsTip3Topic => 'pagos en línea';

  @override
  String get helpHintMoneyPaymentsTipSupply =>
      '¿Compraste cápsulas o bolsas de aspiradora para el espacio? Envía el gasto como suministro: validado, pasa al estante como consumible que los demás pagan, y a ti te lo reembolsan.';

  @override
  String get helpHintMoneyPaymentsTipSupplyTopic => 'Servicios y Accesorios';

  @override
  String get helpHintMoneyPaymentsTopic => 'La vista Pagos';

  @override
  String get helpHintMoneyStatement =>
      'El mes tal como está: tu cuenta, días usados y restantes, suscripción, servicios, paquetes, posiciones abiertas, abonos y el saldo. Recorre los meses con las flechas.';

  @override
  String get helpHintMoneyStatementTip2 =>
      'Una mañana reservada cuenta medio día; los días fuera del horario siguen la política de fuera de horario del espacio.';

  @override
  String get helpHintMoneyStatementTip2Topic => 'Cómo se comporta la reserva';

  @override
  String get helpHintMoneyStatementTip3 =>
      '¿Sin días? Pide medios días extra, compra un paquete o sigue reservando por consumo — según tu plan.';

  @override
  String get helpHintMoneyStatementTipNegotiation =>
      '¿Condiciones negociadas? La tarjeta muestra tus precios junto a la tarifa, desde cuándo, y quién puede verlos — los propietarios y los admins de finanzas, cada lectura registrada.';

  @override
  String get helpHintMoneyStatementTipNegotiationTopic =>
      'Negociaciones de precios';

  @override
  String get helpHintMoneyStatementTopic => 'La vista Extracto';

  @override
  String get helpHintMoneyTip2 =>
      'Cada documento ofrece las mismas tres acciones: vista rápida en pantalla, descarga en PDF y compartir con cualquier app.';

  @override
  String get helpHintMoneyTip2Topic => 'Vista rápida, guardar, compartir';

  @override
  String get helpHintMoneyTip3 =>
      'Registra un pago con la fecha en que se movió el dinero y el mes que salda: la otra parte lo confirma.';

  @override
  String get helpHintMoneyTip4 =>
      'Una vez facturado el mes, decide la factura: el mes aparece saldado en cuanto su factura queda pagada.';

  @override
  String get helpHintMoneyTip4Topic => 'decide la factura';

  @override
  String get helpHintMoneyTopic => 'dinero';

  @override
  String get helpHintNextTip => 'Consejo siguiente';

  @override
  String get helpHintPlan =>
      'El plano en vivo: toca un asiento libre para reservar, toca tu reserva para registrar tu llegada.';

  @override
  String get helpHintPlanTip2 =>
      '¿Estás ante un asiento libre? Tócalo: la ficha propone desde ahora hasta el cierre, y al confirmar quedas registrado al instante.';

  @override
  String get helpHintPlanTip3 =>
      'Recorre otro momento con el chip de fecha y el selector de hora: el plano muestra quién ocupa qué en cualquier instante futuro.';

  @override
  String get helpHintPlanTip4 =>
      'Toca dos veces un escritorio, una sala o la planta entera —o el icono de capas de la barra de niveles— para reservar todo el espacio de una vez.';

  @override
  String get helpHintPlanTip5 =>
      'Toca tu propio asiento para abrir su ficha: registra tu llegada desde 15 minutos antes del inicio y tu salida al marcharte.';

  @override
  String get helpHintPlanTip5Topic => 'Cómo se comporta la reserva';

  @override
  String get helpHintPlanTopic => 'El plano';

  @override
  String get helpHintPrevTip => 'Consejo anterior';

  @override
  String get helpHintPrivacy =>
      'Vea quién puede leer sus datos y quién lo hizo, exporte todo en un archivo o salga con sus datos personales borrados.';

  @override
  String get helpHintPrivacyTip2 =>
      'Los mensajes solo los leen las personas de la conversación, sea cual sea su rol; el dinero solo usted y el permiso de finanzas.';

  @override
  String get helpHintPrivacyTip3 =>
      'Cada lectura de sus finanzas por otra persona la registra el servidor — el registro no se puede omitir ni editar.';

  @override
  String get helpHintPrivacyTopic => 'Privacidad';

  @override
  String get helpHintReserve =>
      'Elige un día y una franja horaria y toca un asiento libre para reservarlo.';

  @override
  String get helpHintReserveTip2 =>
      'Las vistas Semana y Mes encuentran un medio día libre de un vistazo: toca una celda o un día libre para reservar ahí mismo.';

  @override
  String get helpHintReserveTip3 =>
      'Toca el botón de escaneo y apunta la cámara a la tarjeta QR de un espacio: la ficha muestra exactamente qué puedes hacer allí.';

  @override
  String get helpHintReserveTip3Topic => 'Escanear un código de espacio';

  @override
  String get helpHintReserveTip4 =>
      'Los chips de mañana, tarde y día completo fijan tu franja antes de elegir asiento: una mañana reservada cuenta como medio día.';

  @override
  String get helpHintReserveTip4Topic => 'Cómo se comporta la reserva';

  @override
  String get helpHintReserveTip5 =>
      'Define tu periodo de reserva por defecto en Ajustes: el hub lo preselecciona en cada visita.';

  @override
  String get helpHintReserveTip5Topic => 'Ajustes y perfil';

  @override
  String get helpHintReserveTopic => 'hub Reservar';

  @override
  String get helpHintRestoreTitle => 'Volver a mostrar los consejos de ayuda';

  @override
  String get helpHintRestored => 'Los consejos de ayuda volverán a mostrarse.';

  @override
  String get helpHintValidation =>
      'Decide qué acciones necesitan confirmación, quién confirma y cuántas aprobaciones hacen falta.';

  @override
  String get helpHintValidationTip2 =>
      'Una tarjeta por tipo de evento, cada una heredando de la regla por defecto hasta que la edites: pagos, gastos, cambios de rol y más.';

  @override
  String get helpHintValidationTip3 =>
      'Nadie valida nunca su propio evento, y una solicitud sin respuesta caduca a los 7 días: nada se concede en silencio.';

  @override
  String get helpHintValidationTipScopes =>
      'Quién valida es el alcance de la regla: los admins, personas designadas de cualquier rol, o todos los miembros — y cuántos. El propietario siempre puede; nadie valida su propio evento.';

  @override
  String get helpHintValidationTipScopesTopic => 'Gestión de roles';

  @override
  String get helpHintValidationTopic => 'confirmaciones';

  @override
  String get helpHintWorkspace =>
      'País, moneda, idioma y datos de facturación: documentos e impuestos siguen estos ajustes.';

  @override
  String get helpHintWorkspaceTip2 =>
      'Imprime las tarjetas QR de los espacios desde Exportaciones: elige el tamaño y la información de cada tarjeta, diez por página A4.';

  @override
  String get helpHintWorkspaceTip2Topic => 'Códigos QR de espacios';

  @override
  String get helpHintWorkspaceTip3 =>
      'Exporta el espacio como XML para respaldarlo o usarlo de plantilla; el cuestionario de configuración prepara un espacio nuevo de principio a fin.';

  @override
  String get helpHintWorkspaceTip4 =>
      'Restablecer el espacio borra reservas, contabilidad y plano: ajustes y miembros sobreviven, y una confirmación escrita protege la acción.';

  @override
  String get helpHintWorkspaceTopic => 'Ajustes del espacio';

  @override
  String get helpTitle => 'Ayuda';

  @override
  String get helpTopicAccounting => 'Exportaciones contables';

  @override
  String get helpTopicBilling => 'Facturación';

  @override
  String get helpTopicBookingLimits => 'Límites de reserva';

  @override
  String get helpTopicBookingPolicies => 'Políticas de reserva';

  @override
  String get helpTopicDeployment => 'Desplegar';

  @override
  String get helpTopicDocumentLibrary => 'biblioteca de documentos';

  @override
  String get helpTopicEinvoice => 'factura electrónica';

  @override
  String get helpTopicEnvironments => 'Entornos';

  @override
  String get helpTopicInstances => 'Instancias';

  @override
  String get helpTopicKiosk => 'Modo quiosco';

  @override
  String get helpTopicLegalIdentity => 'Identidad legal';

  @override
  String get helpTopicReadiness => 'admisibilidad';

  @override
  String get helpTopicReportEditor => 'editor de informes';

  @override
  String get helpTopicReportLayout => 'Los diseños posicionados';

  @override
  String get helpTopicScheduledExpenses => 'Gastos programados';

  @override
  String get helpTopicServer => 'tu propio servidor';

  @override
  String get helpTopicSettings => 'Ajustes y perfil';

  @override
  String get helpTopicTrace => 'El registro';

  @override
  String get helpTopicVat => 'IVA';

  @override
  String get helpTopicWindowEnvelope => 'El contrato del sobre con ventana';

  @override
  String get helpTopicWorkingHours => 'Horario de trabajo';

  @override
  String get helpTopicWorkspaceId => 'ID del espacio';

  @override
  String get holidayAllSaints => 'Todos los Santos';

  @override
  String get holidayArmistice => 'Armisticio de 1918';

  @override
  String get holidayAscension => 'Ascensión';

  @override
  String get holidayAssumption => 'Asunción';

  @override
  String get holidayBoxingDay => 'San Esteban';

  @override
  String get holidayChristmas => 'Navidad';

  @override
  String get holidayEasterMonday => 'Lunes de Pascua';

  @override
  String get holidayGermanUnity => 'Día de la Unidad Alemana';

  @override
  String get holidayGoodFriday => 'Viernes Santo';

  @override
  String get holidayImportAction => 'Importar días festivos (datos abiertos)';

  @override
  String holidayImportConfirm(int count) {
    return 'Importar $count días de cierre';
  }

  @override
  String get holidayImportFailed =>
      'No se pudieron comprobar ni importar los días festivos. No se ha cambiado nada.';

  @override
  String get holidayImportNationwide => 'Solo festivos nacionales';

  @override
  String get holidayImportRegion => 'Región';

  @override
  String get holidayImportRetry => 'Reintentar';

  @override
  String holidayImportSource(String source) {
    return 'Fuente: $source';
  }

  @override
  String get holidayImportUnavailable =>
      'La fuente de días festivos no está disponible ahora. Inténtelo más tarde o use «Añadir días festivos».';

  @override
  String get holidayLabourDay => 'Día del Trabajo';

  @override
  String get holidayNationalDay => 'Fiesta Nacional de Francia';

  @override
  String get holidayNewYear => 'Año Nuevo';

  @override
  String get holidayVictory1945 => 'Victoria de 1945';

  @override
  String get holidayWhitMonday => 'Lunes de Pentecostés';

  @override
  String get identityConnectBrowser => 'No se pudo abrir el navegador.';

  @override
  String identityConnectConfirmApply(String name) {
    return '¿Enviar su solicitud de membresía a $name?';
  }

  @override
  String get identityConnectConfirmApplyBody =>
      'Ya está conectado. El espacio revisa su solicitud; no se comparte nada más.';

  @override
  String get identityConnectContinue => 'Continuar con Deskilo';

  @override
  String get identityConnectCurrentServer =>
      'Es el servidor en el que ya ha iniciado sesión.';

  @override
  String get identityConnectDifferentAuthority =>
      'Este servidor acepta otro proveedor de identidad.';

  @override
  String identityConnectDone(String host) {
    return 'Conectado a $host.';
  }

  @override
  String get identityConnectExistingAccount =>
      'Usar una cuenta que ya tengo en este servidor';

  @override
  String get identityConnectExpired =>
      'El inicio de sesión tardó demasiado. Empiece de nuevo.';

  @override
  String identityConnectExplain(String host) {
    return '$host sabrá que es usted, gracias a su identidad Deskilo. Conectarse no le convierte en miembro, no le da ningún rol ni conecta ningún asistente: el espacio sigue decidiendo cada solicitud.';
  }

  @override
  String get identityConnectNetwork =>
      'El servidor no respondió. Inténtelo de nuevo.';

  @override
  String get identityConnectNoDeskiloSignIn =>
      'Este servidor no ofrece el inicio de sesión con Deskilo.';

  @override
  String get identityConnectNoSharedIdentity =>
      'Su cuenta aquí no tiene una identidad Deskilo que otro servidor pueda aceptar.';

  @override
  String identityConnectNotSaved(String host) {
    return '$host le ha aceptado, pero este dispositivo no pudo guardar la conexión. No se ha enviado nada. Inténtelo de nuevo.';
  }

  @override
  String get identityConnectRefused =>
      'La conexión no se completó. No se ha enviado nada.';

  @override
  String get identityConnectRetry => 'Intentar de nuevo';

  @override
  String get identityConnectSend => 'Enviar solicitud';

  @override
  String get identityConnectServerUnsupported =>
      'Este servidor no se puede conectar desde esta versión de la aplicación.';

  @override
  String identityConnectTitle(String host) {
    return 'Conectarse a $host';
  }

  @override
  String get identityConnectUnavailable => 'Este servidor no respondió.';

  @override
  String get identityConnectUnlinked =>
      'Una cuenta de ese servidor ya usa esta identidad o este correo sin estar vinculada a ella. Use esa cuenta.';

  @override
  String get identityConnectWaiting =>
      'Termine de iniciar sesión en su navegador y vuelva aquí.';

  @override
  String get identityConnectWrongAccount =>
      'El navegador inició sesión con otra persona. No se ha conectado nada.';

  @override
  String identityConsentAsks(String host) {
    return 'Usa tu identidad de Deskilo para iniciar sesión en $host.';
  }

  @override
  String get identityConsentCompleting => 'Guardando tu elección…';

  @override
  String get identityConsentPurpose =>
      'El acceso a espacios y asistentes se aprueba por separado.';

  @override
  String get identityConsentReturnFailed => 'No se pudo abrir el destino.';

  @override
  String get identityConsentReturning => 'Volviendo al inicio de sesión…';

  @override
  String get identityConsentTitle => 'Continuar con Deskilo';

  @override
  String get identityConsentUnavailable =>
      'Esta solicitud de inicio de sesión no está disponible. Vuelve al destino y empieza de nuevo.';

  @override
  String get inboxAlertsTab => 'Alertas';

  @override
  String get inboxChatsTab => 'Chats';

  @override
  String get inboxFilterAll => 'Todos';

  @override
  String get inboxFilterArchived => 'Archivados';

  @override
  String get inboxFilterUnread => 'No leídos';

  @override
  String get inboxMessengerDoor => 'Abrir mi mensajería';

  @override
  String get inboxNoArchived => 'Ninguna conversación archivada.';

  @override
  String get inboxNoUnread => 'Nada sin leer — estás al día.';

  @override
  String get inboxRetry => 'Reintentar';

  @override
  String get instanceAccessTitle => 'Acceso a los asistentes';

  @override
  String instanceAccessUntil(String date) {
    return 'Hasta el $date';
  }

  @override
  String get instanceAccountIntro =>
      'Cree una cuenta gratuita en supabase.com, luego un token de acceso personal (Account → Access Tokens) y péguelo aquí. El asistente lo usa para crear y configurar el proyecto; nunca se guarda.';

  @override
  String get instanceAdminsHelp =>
      'Deciden quién puede usar asistentes. Solo pueden elegirse personas que confirmaron su identidad para asistentes.';

  @override
  String get instanceAdminsTitle => 'Administradores de la base';

  @override
  String get instanceApplySignIn => 'Aplicar los ajustes de inicio de sesión';

  @override
  String get instanceApprove => 'Aprobar';

  @override
  String instanceAttentionForeign(String tables) {
    return 'Su esquema public contiene tablas que DesKilo no crea ($tables). Se rechaza instalar ahí; use un proyecto vacío.';
  }

  @override
  String get instanceAttentionNotHealthy =>
      'Supabase no indica que el proyecto esté operativo. Espere a que lo esté o restáurelo en el panel.';

  @override
  String get instanceAttentionOtherTooling =>
      'Sus migraciones las registró otra herramienta, así que no se puede saber dónde continuaría DesKilo. Use un proyecto vacío.';

  @override
  String instanceAttentionPostgres(int found, int supported) {
    return 'Usa Postgres $found; DesKilo está hecho para Postgres $supported.';
  }

  @override
  String get instanceAttentionUnrecorded =>
      'Las tablas de DesKilo están, pero no se registró ninguna migración. Registre primero lo que tiene con `dart run tool/instance.dart record`.';

  @override
  String get instanceBlock => 'Bloquear';

  @override
  String get instanceBlockerNoAdmin => 'un administrador de la base';

  @override
  String get instanceBlockers => 'Todavía falta:';

  @override
  String get instanceCheckToken => 'Comprobar el token';

  @override
  String get instanceChooseAnother => 'Elegir otro proyecto';

  @override
  String get instanceClaimBody =>
      'Usted creó esta instancia y no hay propietario definido. Al asumir la propiedad, usted responde de ella.';

  @override
  String get instanceClaimButton => 'Asumir la propiedad';

  @override
  String get instanceClaimDone => 'Ahora es el propietario de la instancia.';

  @override
  String get instanceClaimFailed => 'No se pudo asumir la propiedad.';

  @override
  String get instanceClaimTitle => 'Asumir la propiedad';

  @override
  String get instanceClientApproved => 'Aprobado';

  @override
  String get instanceClientBlocked => 'Bloqueado';

  @override
  String get instanceClientWaiting => 'Pendiente de aprobación';

  @override
  String get instanceClientsHelp =>
      'Un asistente se registra solo la primera vez que alguien lo conecta; funciona solo después de aprobarlo aquí.';

  @override
  String get instanceClientsTitle => 'Clientes de asistente';

  @override
  String get instanceConfirmSecondFactor => 'Confirmar con mi autenticador';

  @override
  String get instanceCreateButton => 'Crear una nueva instancia';

  @override
  String get instanceCreateProject => 'Crear el proyecto';

  @override
  String get instanceDatabasePassword =>
      'Contraseña de la base de datos, elegida por usted — cópiela en un lugar seguro; la app no vuelve a necesitarla.';

  @override
  String get instanceDelegateAdd => 'Delegar el rol';

  @override
  String get instanceDelegateAlreadyOwner =>
      'El propietario no necesita una delegación.';

  @override
  String get instanceDelegateFieldLabel => 'Correo electrónico de una cuenta';

  @override
  String get instanceDelegateNoAccount =>
      'Ninguna cuenta usa esta dirección de correo.';

  @override
  String get instanceDelegateUnavailable =>
      'Este servidor aún no permite delegar.';

  @override
  String get instanceDelegateUnchanged => 'Esta persona ya es delegada.';

  @override
  String get instanceDelegateUnconfirmed =>
      'Esta cuenta aún no ha confirmado su correo electrónico.';

  @override
  String get instanceDelegateWithdraw => 'Retirar la delegación';

  @override
  String get instanceDelegateWithdrawBody =>
      'Esta persona pierde de inmediato el acceso a la configuración de la instalación.';

  @override
  String get instanceDelegateWithdrawConfirm => 'Retirar';

  @override
  String get instanceDelegateWithdrawTitle => '¿Retirar esta delegación?';

  @override
  String get instanceDelegated => 'Rol delegado.';

  @override
  String get instanceDelegatesHelp =>
      'Un delegado puede realizar la configuración de los asistentes para toda la instalación. No puede delegar a su vez ni ve ningún otro espacio.';

  @override
  String get instanceDelegatesNone => 'Sin delegados.';

  @override
  String get instanceDelegatesTitle => 'Delegados';

  @override
  String get instanceDelegationWithdrawn => 'Delegación retirada.';

  @override
  String instanceDeployFunctions(int count) {
    return 'Desplegar las funciones: pagos, facturas electrónicas, push, tarjetas ($count).';
  }

  @override
  String get instanceDoctorAttention => 'Requiere atención';

  @override
  String get instanceDoctorIntro =>
      'Antes de que este dispositivo la use, la comprobación de seguridad debe pasar: una alarma mantiene el botón desactivado hasta corregirla.';

  @override
  String instanceDoctorPassed(int count) {
    return '$count comprobaciones superadas';
  }

  @override
  String get instanceDoctorProtected => 'Protegido';

  @override
  String get instanceDoctorRun => 'Ejecutar la comprobación de seguridad';

  @override
  String get instanceDoctorRunAgain => 'Comprobar de nuevo';

  @override
  String get instanceDoneIntro =>
      'La instancia está lista. Úsela en este dispositivo y comparta luego el QR del servidor desde la pantalla Servidor para que los miembros se unan a la misma.';

  @override
  String get instanceEndpointTitle => 'Punto de acceso de los asistentes';

  @override
  String get instanceFamilyChatgpt => 'ChatGPT';

  @override
  String get instanceFamilyClaude => 'Claude';

  @override
  String get instanceFamilyLoopback =>
      'Asistente de escritorio o de línea de comandos';

  @override
  String get instanceGrant => 'Aprobar el acceso';

  @override
  String get instanceGrantDays => 'Elija entre 1 y 30 días.';

  @override
  String instanceGrantDaysLabel(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días',
      one: '1 día',
    );
    return 'Durante $_temp0';
  }

  @override
  String get instanceGrantHelp =>
      'Mientras no exista otro administrador de la base de datos, usted aprueba los accesos — incluido el suyo — por hasta 30 días, con un motivo. Cada aprobación queda registrada.';

  @override
  String get instanceGrantNeedsGoogle =>
      'Para aprobar el acceso, esta sesión debe haberse iniciado con Google.';

  @override
  String get instanceGrantNoIdentity =>
      'Esa persona aún no ha confirmado su identidad.';

  @override
  String get instanceGrantOtherAdmin =>
      'Aquí decide el acceso un administrador de la base de datos; pídaselo.';

  @override
  String get instanceGrantReason => 'Motivo';

  @override
  String get instanceGrantReasonNeeded =>
      'Escriba por qué se aprueba este acceso (hasta 500 caracteres).';

  @override
  String instanceGrantTitle(String name) {
    return 'Aprobar el acceso a los asistentes para $name';
  }

  @override
  String instanceInstallSchema(int count) {
    return 'Instalar el esquema: cada migración de la app, en orden ($count).';
  }

  @override
  String get instanceIntro =>
      'Ajustes para todos los espacios de trabajo de esta instalación. Solo el operador de la instancia ve esta página; cada cambio requiere su segundo factor y queda registrado.';

  @override
  String get instanceLoopbackHelp =>
      'Claude Code, Cursor, VS Code y otros asistentes que se ejecutan en el propio equipo de una persona. Cada persona sigue aprobando su propia conexión.';

  @override
  String get instanceLoopbackTitle =>
      'Permitir asistentes de escritorio y de línea de comandos';

  @override
  String get instanceMakeAdmin => 'Nombrar administrador';

  @override
  String get instanceNoCandidates =>
      'Nadie más ha confirmado aún su identidad.';

  @override
  String get instanceNotOperator =>
      'Solo el operador de la instancia gestiona los asistentes de la instalación.';

  @override
  String instanceNoticeClientWaiting(String name) {
    return '$name espera su aprobación.';
  }

  @override
  String instanceNoticeOperatorGrant(String name) {
    return 'El operador aprobó el acceso a los asistentes para $name.';
  }

  @override
  String instanceNoticeSelfGrant(String name) {
    return '$name aprobó su propio acceso a los asistentes.';
  }

  @override
  String get instanceNoticesMarkRead => 'Marcar como leído';

  @override
  String get instanceOperatorApproved => 'Aprobado por el operador';

  @override
  String get instanceOrganisationLabel => 'Organización';

  @override
  String get instanceOwnerClaimIntro =>
      '¿A quién pertenece esta instancia? Introduzca el correo electrónico con el que se registrará en ella. Tras confirmar esa dirección, reclame la titularidad en Ajustes → Propietario de la instancia.';

  @override
  String get instanceOwnerClaimLabel => 'Correo del titular';

  @override
  String get instanceOwnerCopied => 'Dirección de correo copiada.';

  @override
  String get instanceOwnerCopyEmail => 'Copiar la dirección de correo';

  @override
  String get instanceOwnerHelp =>
      'Esta instalación la comparten todos sus espacios. El propietario de la instancia responde de ella: contáctelo para todo lo que afecte a toda la instalación, como los asistentes.';

  @override
  String get instanceOwnerNone => 'Todavía no hay propietario de la instancia.';

  @override
  String get instanceOwnerTitle => 'Propietario de la instancia';

  @override
  String get instanceProbeCheck => 'Comprobar el servidor';

  @override
  String get instanceProbeDeployed =>
      'El punto de acceso de los asistentes responde como debe.';

  @override
  String get instanceProbeMismatch =>
      'El punto de acceso responde con otra dirección distinta de la que reciben los asistentes.';

  @override
  String get instanceProbeMissing => 'El servidor aún no se ha comprobado.';

  @override
  String get instanceProbeNotDeployed =>
      'El punto de acceso de los asistentes aún no está desplegado en este servidor.';

  @override
  String get instanceProbePending => 'Comprobando el servidor…';

  @override
  String get instanceProbeStale =>
      'La última comprobación tiene más de 15 minutos. Compruebe de nuevo antes de activar los asistentes.';

  @override
  String get instanceProbeUnavailable =>
      'No se pudo contactar con el servidor. Inténtelo de nuevo en un momento.';

  @override
  String instanceProgress(int done, int total, String current) {
    return '$done / $total · $current';
  }

  @override
  String get instanceProjectName => 'Nombre del proyecto';

  @override
  String instanceProjectReady(String ref) {
    return 'Proyecto listo: $ref';
  }

  @override
  String instanceProjectStatus(String status) {
    return 'Estado del proyecto: $status';
  }

  @override
  String get instanceReadyAttention =>
      'Este proyecto requiere atención: no se instaló nada.';

  @override
  String instanceReadyCurrent(int version) {
    return 'La versión $version de DesKilo está instalada y al día: el esquema no necesita nada.';
  }

  @override
  String get instanceReadyInstall =>
      'El proyecto está vacío: se instalará todo.';

  @override
  String instanceReadyResume(int pending) {
    return 'Una instalación de DesKilo se detuvo a medias: quedan $pending migraciones y solo se ejecutarán esas.';
  }

  @override
  String instanceReadyUpgrade(int version, int pending) {
    return 'La versión $version de DesKilo está instalada: solo se ejecutarán las $pending migraciones que faltan.';
  }

  @override
  String get instanceRegion => 'Región (la más cercana al espacio)';

  @override
  String get instanceRemoveAdmin => 'Quitar';

  @override
  String get instanceRetry => 'Reintentar desde donde se detuvo';

  @override
  String get instanceRevokeToken =>
      'Ya puede revocar el token de acceso: DesKilo no guardó ninguna copia.';

  @override
  String get instanceRuntimeOff => 'Desactivados';

  @override
  String get instanceRuntimeOn => 'Activados';

  @override
  String get instanceRuntimeTitle => 'Asistentes en esta instalación';

  @override
  String get instanceSecondFactorNeeded =>
      'Los cambios aquí requieren su segundo factor en esta sesión.';

  @override
  String get instanceSelfApproved => 'Autoaprobado por el operador';

  @override
  String get instanceSignInExplain =>
      'Ajustes de inicio de sesión: confirmación por correo activada (un registro debe pulsar el enlace del correo), y los enlaces de la app permitidos para restablecer contraseñas y enlaces mágicos.';

  @override
  String get instanceStepAccount => 'Cuenta';

  @override
  String get instanceStepDone => 'Listo';

  @override
  String instanceStepFailed(String item, String message) {
    return 'Detenido en $item: $message';
  }

  @override
  String get instanceStepFunctions => 'Funciones';

  @override
  String get instanceStepProject => 'Proyecto';

  @override
  String get instanceStepSchema => 'Esquema';

  @override
  String get instanceStepSignIn => 'Inicio de sesión';

  @override
  String get instanceTitle => 'Instalación: asistentes';

  @override
  String get instanceTokenLabel => 'Token de acceso personal';

  @override
  String get instanceTokenReach =>
      'Un token de acceso personal abre toda su cuenta de Supabase mientras exista. El asistente solo lo guarda en memoria y le indica cuándo puede revocarlo.';

  @override
  String get instanceTokenRefused =>
      'Supabase rechazó el token. Cree uno en Account → Access Tokens y péguelo entero.';

  @override
  String get instanceTurnOff => 'Desactivar';

  @override
  String get instanceTurnOn => 'Activar para todos los espacios';

  @override
  String get instanceTurnOnConfirm =>
      'Los asistentes pasan a poder usarse en cada espacio que los ofrece. Puede desactivarlos en cualquier momento.';

  @override
  String get instanceTurnOnNeedsProbe =>
      'El punto de acceso de los asistentes no está confirmado. Compruebe primero el servidor.';

  @override
  String get instanceUseExisting => 'O usar un proyecto existente:';

  @override
  String get instanceUseHere => 'Usar esta instancia en este dispositivo';

  @override
  String get instanceWizardTitle => 'Crear una nueva instancia';

  @override
  String get instanceYou => 'usted';

  @override
  String get instanceYouAreDelegate =>
      'Usted es delegado del propietario de la instancia.';

  @override
  String get instanceYouAreOwner => 'Usted es el propietario de la instancia.';

  @override
  String invitationAlreadyMember(String workspace) {
    return 'Ya eres miembro de $workspace.';
  }

  @override
  String get invitationApprovalRequired =>
      'Un administrador aprueba a los nuevos miembros antes de que se abra el espacio.';

  @override
  String get invitationApprovalUnknown =>
      'No se sabe si un administrador debe aprobar.';

  @override
  String get invitationBadServer =>
      'El servidor de esta invitación no es válido. Pide una nueva invitación.';

  @override
  String get invitationChangeAccount => 'Cambiar de cuenta';

  @override
  String get invitationCheckAnother => 'Usar otra invitación';

  @override
  String get invitationCheckFailed =>
      'No se pudo comprobar la invitación — estado no actualizado. No se cambió nada; inténtalo de nuevo.';

  @override
  String get invitationContinue => 'Continuar a este espacio';

  @override
  String invitationDefaultTemplate(
    String firstName,
    String workspaceName,
    String workspaceId,
    String downloadUrl,
    String inviteLink,
  ) {
    return '¡Hola$firstName! Te invitamos a unirte a nuestro espacio de coworking «$workspaceName» en DesKilo.\n\n1. Descarga la aplicación:\n$downloadUrl\n\n2. Ábrela, crea tu cuenta (correo + contraseña) e inicia sesión.\n\n3. Elige «Unirse a un espacio» e introduce tu código de invitación personal:\n$workspaceId\n(enlace de invitación: $inviteLink)\n\nConsejo: simplemente copia este mensaje completo y pégalo en la aplicación — el código se detecta automáticamente. Tu código es personal, de un solo uso y válido durante 14 días.\n\n¡Hasta pronto en $workspaceName!';
  }

  @override
  String get invitationEnvironmentProduction => 'Espacio de producción';

  @override
  String get invitationEnvironmentTest => 'Espacio de prueba';

  @override
  String get invitationExpired =>
      'Esta invitación ha caducado. Pide una nueva a quien te la envió.';

  @override
  String invitationInvalid(String host) {
    return 'Ningún espacio en $host conoce esta invitación. Revísala o pide al organizador el enlace de su servidor.';
  }

  @override
  String get invitationJoinButton => 'Unirse al espacio';

  @override
  String get invitationJoinUnconfirmed =>
      'No se pudo confirmar el resultado. Únete de nuevo para comprobarlo — la invitación no se usa dos veces.';

  @override
  String invitationJoiningAs(String account) {
    return 'Te unes como $account';
  }

  @override
  String get invitationNewerVersion =>
      'Esta invitación se creó con una versión más reciente de DesKilo. Actualiza la app y vuelve a abrirla.';

  @override
  String invitationOtherServer(String host) {
    return 'Esta invitación es para otro servidor: $host.';
  }

  @override
  String get invitationPasteButton => 'Pegar';

  @override
  String invitationPaused(String workspace) {
    return 'Tu membresía en $workspace está en pausa. Solo un administrador de allí puede reanudarla.';
  }

  @override
  String get invitationReviewButton => 'Revisar invitación';

  @override
  String get invitationReviewTitle => 'Revisa antes de unirte';

  @override
  String get invitationRevoked =>
      'Este código de espacio fue sustituido. Pide el actual a quien te lo envió.';

  @override
  String get invitationRoleAdmin => 'Rol ofrecido: administrador';

  @override
  String get invitationRoleMember => 'Rol ofrecido: miembro';

  @override
  String get invitationRoleUnknown => 'Rol ofrecido: aún no se sabe';

  @override
  String invitationServerLabel(String label) {
    return 'Llamado «$label» por quien lo compartió';
  }

  @override
  String invitationServerRow(String host) {
    return 'Servidor: $host';
  }

  @override
  String get invitationTemplateHelp =>
      'Se envía al invitar a alguien por WhatsApp, SMS o compartir. Déjalo vacío para usar el mensaje integrado en el idioma elegido. Etiquetas disponibles:';

  @override
  String get invitationTemplateHint =>
      'Mensaje de invitación personalizado usando las etiquetas de arriba…';

  @override
  String get invitationTemplateLanguage => 'Idioma del mensaje';

  @override
  String get invitationTemplateTitle => 'Mensaje de invitación';

  @override
  String invitationThisDevice(String host) {
    return 'Este dispositivo usa $host. Una invitación solo se comprueba en su propio servidor.';
  }

  @override
  String get invitationUnknownAnswer =>
      'El servidor dio una respuesta que esta versión de la app no sabe leer. No se cambió nada.';

  @override
  String get invitationUseServer => 'Usar este servidor';

  @override
  String get invitationWrongAccount =>
      'Otra cuenta ya usó esta invitación. Si era para ti, inicia sesión con esa cuenta.';

  @override
  String get inviteAdminExplainer =>
      'Este código es de un solo uso: admite a UNA persona como admin y luego caduca. Entrégalo solo a la persona a la que está destinado.';

  @override
  String get inviteAdminNewCode => 'Nuevo código de administrador/a';

  @override
  String get inviteAlsoProdSubtitle =>
      'La persona se une al espacio de prueba en cualquier caso. El rol todavía tiene que permitir el acceso a producción.';

  @override
  String get inviteAlsoProdTitle => 'Dar también acceso a producción';

  @override
  String get inviteCreateFailed =>
      'No se pudo crear la invitación. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get inviteFirstNameLabel => 'Nombre (opcional)';

  @override
  String get inviteLanguageLabel => 'Idioma del mensaje';

  @override
  String get inviteLastNameLabel => 'Apellido (opcional)';

  @override
  String get inviteOwnerNote =>
      'No existe invitación de propietario — solo un propietario puede conceder la propiedad, en Miembros y planes.';

  @override
  String get invitePhoneLabel => 'Teléfono (opcional, con prefijo)';

  @override
  String get inviteRoleAdmin => 'Invitación de administrador/a';

  @override
  String get inviteRoleMember => 'Invitación de miembro';

  @override
  String get inviteRolesHint =>
      'Se dan al unirse, una vez activa la membresía.';

  @override
  String get inviteRolesTitle => 'Roles al llegar';

  @override
  String get inviteSectionTitle => 'Invitar a alguien';

  @override
  String get inviteSendFailed =>
      'No se pudo abrir la aplicación de envío. El mensaje se copió en su lugar.';

  @override
  String get inviteViaShare => 'Compartir…';

  @override
  String get inviteViaSms => 'SMS';

  @override
  String get inviteViaWhatsapp => 'WhatsApp';

  @override
  String get invoiceAccountingExport => 'Exportación contable';

  @override
  String get invoiceAccountingExportEmpty =>
      'No hay nada que exportar en este periodo.';

  @override
  String get invoiceAllCaughtUp => 'Todo al día — nada que facturar.';

  @override
  String get invoiceAlreadyInvoiced =>
      'Este mes ya está facturado para este miembro.';

  @override
  String invoiceAnnexSummary(int movements, int checkIns) {
    return 'Anexo: $movements movimientos, $checkIns registros de entrada';
  }

  @override
  String get invoiceBalance => 'Saldo';

  @override
  String get invoiceBuyerReference => 'Código de servicio';

  @override
  String get invoiceBuyerReferenceHint =>
      'Comprador público (Chorus Pro): el code service exécutant.';

  @override
  String invoiceCountShown(int count) {
    return '$count facturas';
  }

  @override
  String get invoiceCreate => 'Nueva factura';

  @override
  String get invoiceDetailedToggle =>
      'Incluir el anexo detallado (asistencias, servicios, pagos)';

  @override
  String get invoiceDownload => 'Descargar PDF';

  @override
  String get invoiceEInvoiceAction => 'Factura electrónica (XML)';

  @override
  String get invoiceEInvoiceBlockedTitle =>
      'Un validador rechazaría este archivo:';

  @override
  String invoiceEInvoiceBusinessRoute(String channel, String format) {
    return 'Clientes empresa: envíala por $channel en formato $format.';
  }

  @override
  String get invoiceEInvoiceDownload => 'Descargar factura electrónica (XML)';

  @override
  String get invoiceEInvoiceExplain =>
      'La factura EN 16931 legible por máquina — el archivo que piden las administraciones y los clientes empresa.';

  @override
  String get invoiceEInvoiceFixIdentity => 'Completar la identidad legal';

  @override
  String invoiceEInvoiceFormatMismatch(String channel, String format) {
    return '$channel solo acepta $format: este archivo EN 16931 sirve para Peppol, compradores públicos y clientes extranjeros — tu plataforma o tu asesoría convierte el resto.';
  }

  @override
  String get invoiceEInvoiceIncompleteTitle =>
      'Válido, pero los perfiles nacionales estrictos piden además:';

  @override
  String invoiceEInvoicePublicRoute(String channel) {
    return 'Clientes del sector público: $channel.';
  }

  @override
  String get invoiceEInvoiceReady => 'Listo — este archivo cumple EN 16931.';

  @override
  String get invoiceEInvoiceShare => 'Compartir factura electrónica (XML)';

  @override
  String get invoiceEInvoiceStaleIdentity =>
      'Tu identidad legal ya está completa, pero esta factura se firmó antes y conserva aquello con lo que se emitió. Márcala como errónea y emite una sustitución para que lleve la nueva identidad.';

  @override
  String get invoiceEInvoiceTransportAccredited =>
      'Una plataforma autorizada transporta la factura y comunica los datos a la administración tributaria por ti.';

  @override
  String get invoiceEInvoiceTransportBilateral =>
      'Ningún canal es obligatorio: correo, un portal o Peppol — lo que acuerdes con el cliente.';

  @override
  String get invoiceEInvoiceTransportClearance =>
      'La plataforma nacional recibe la factura primero y la reenvía — enviarla directamente al cliente no es posible.';

  @override
  String get invoiceEInvoiceTransportPeppol =>
      'Un punto de acceso la entrega al cliente — sin plataforma pública de por medio.';

  @override
  String get invoiceEssentialsRefused =>
      'La factura no se emitió: faltan datos obligatorios.';

  @override
  String get invoiceExportAccountantCsv => 'CSV contable';

  @override
  String get invoiceExportAuditTrail => 'Pista de auditoría';

  @override
  String get invoiceExportBundle => 'Archivo del ejercicio (zip)';

  @override
  String get invoiceExportChoose => 'Exportación contable';

  @override
  String get invoiceExportDatev => 'DATEV (Buchungsstapel)';

  @override
  String get invoiceExportFec => 'FEC (Francia, exigido en una inspección)';

  @override
  String get invoiceExportSafT => 'SAF-T (XML, internacional)';

  @override
  String get invoiceExportSafTPt => 'SAF-T (Portugal)';

  @override
  String get invoiceExportSage => 'Sage 50 (registro de auditoría)';

  @override
  String get invoiceFacturXDownload => 'Descargar Factur-X (PDF)';

  @override
  String get invoiceFacturXExplain =>
      'Un solo archivo: la factura que lee una persona, con el XML legible por máquina dentro. Es lo que esperan la mayoría de las plataformas.';

  @override
  String get invoiceFacturXShare => 'Compartir Factur-X (PDF)';

  @override
  String get invoiceFilterAllMembers => 'Todos los miembros';

  @override
  String get invoiceFilterAllMonths => 'Todos los meses';

  @override
  String get invoiceFilterClear => 'Borrar filtros';

  @override
  String get invoiceFilterMonthLabel => 'Mes';

  @override
  String get invoiceFilterNoMatch =>
      'Ninguna factura coincide con estos filtros.';

  @override
  String get invoiceGapBuyerVatIdFormat =>
      'El NIF-IVA del cliente no tiene la forma de su país — compruébelo.';

  @override
  String get invoiceGapCreditNoteWithPayments =>
      'Esta factura rectificativa también compensa pagos, algo que una nota de crédito EN 16931 no puede expresar. Emita el abono en un documento propio.';

  @override
  String get invoiceGapMissingBuyerCountry => 'Falta el país del cliente.';

  @override
  String get invoiceGapMissingBuyerVatId =>
      'Falta el NIF-IVA del cliente — una factura con inversión del sujeto pasivo debe indicarlo.';

  @override
  String get invoiceGapMissingExemptionReason =>
      'Falta el motivo por el que no se cobra IVA.';

  @override
  String get invoiceGapMissingLegalId =>
      'Falta el número de registro (SIREN, HRB, CIF…) — nada te identifica en la factura.';

  @override
  String get invoiceGapMissingSellerCity =>
      'la ciudad de la dirección del espacio';

  @override
  String get invoiceGapMissingSellerCountry => 'Falta el país del espacio.';

  @override
  String get invoiceGapMissingSellerPostalCode =>
      'el código postal de la dirección del espacio';

  @override
  String get invoiceGapMissingVatId =>
      'Falta el número de IVA — un vendedor exento debe indicarlo.';

  @override
  String get invoiceGapNoChargeLines =>
      'Esta factura no tiene ninguna línea de cargo — su mes quedó cubierto por los pagos, así que no hay nada que enviar.';

  @override
  String get invoiceGapPublicSectorRefs =>
      'Destinada a una plataforma pública sin número de compromiso ni código de servicio — Chorus Pro rechaza la mayoría de los depósitos sin uno de los dos.';

  @override
  String get invoiceGapVatNotSupported =>
      'El espacio cobra IVA pero esta factura no lleva ningún tipo: añade tus tipos de IVA y vuelve a emitirla.';

  @override
  String invoiceHeldNote(String reason) {
    return 'Recordatorios suspendidos: $reason';
  }

  @override
  String get invoiceHoldAction => 'Suspender los recordatorios';

  @override
  String get invoiceHoldConfirm => 'Suspender';

  @override
  String get invoiceHoldExplain =>
      'No se envía ningún recordatorio para esta factura, ni a mano ni automáticamente, hasta que se levante la suspensión.';

  @override
  String get invoiceHoldFailed =>
      'No se pudo cambiar la suspensión de recordatorios. Inténtalo de nuevo.';

  @override
  String get invoiceHoldNote => 'Nota (opcional)';

  @override
  String get invoiceHoldPlaced =>
      'Los recordatorios de esta factura están suspendidos.';

  @override
  String get invoiceHoldReasonDispute => 'El miembro la impugna';

  @override
  String get invoiceHoldReasonIdentity =>
      'Persona equivocada o error de identidad';

  @override
  String get invoiceHoldReasonInsolvency => 'Procedimiento de insolvencia';

  @override
  String get invoiceHoldReasonOther => 'Otro motivo';

  @override
  String get invoiceHoldReleaseAction =>
      'Levantar la suspensión de recordatorios';

  @override
  String get invoiceHoldReleased =>
      'Los recordatorios de esta factura pueden reanudarse.';

  @override
  String get invoiceHoldTitle => '¿Por qué suspender los recordatorios?';

  @override
  String get invoiceIntegrityAltered => 'Modificada desde la emisión';

  @override
  String get invoiceIntegrityUnverifiable =>
      'Emitida antes de los controles de integridad';

  @override
  String get invoiceIntegrityVerified => 'Integridad verificada';

  @override
  String get invoiceIssue => 'Emitir factura';

  @override
  String get invoiceIssueAll => 'Facturar todo';

  @override
  String invoiceIssueAllConfirm(int count, String month, String total) {
    return '¿Emitir $count facturas de $month por $total en total? Una factura emitida ya no se modifica — un error se corrige con una sustitución.';
  }

  @override
  String get invoiceIssueOne => 'Facturar';

  @override
  String get invoiceIssued => 'Factura emitida.';

  @override
  String invoiceIssuedCount(int count) {
    return '$count facturas emitidas.';
  }

  @override
  String invoiceIssuedPartial(int issued, int failed) {
    return '$issued emitidas, $failed con error.';
  }

  @override
  String get invoiceKindFull => 'Mes completo';

  @override
  String get invoiceKindSettlement => 'Facturas agrupadas';

  @override
  String get invoiceKindSubscription => 'Suscripción, por adelantado';

  @override
  String get invoiceKindUsage => 'Los extras del mes';

  @override
  String get invoiceLegalAssociationReasonHint =>
      'p. ej. «TVA non applicable, art. 293 B du CGI» — o «Exonération de TVA, art. 261, 7-1° du CGI» para servicios a los miembros';

  @override
  String get invoiceLegalCustomerCapacityField =>
      'Condición del cliente por defecto';

  @override
  String get invoiceLegalCustomerCapacityHint =>
      'Decide qué cláusulas de pago imprime una factura. Los textos legales por defecto de intereses de demora, indemnización por costes de cobro y descuento solo se aplican a clientes empresariales, y un consumidor nunca recibe la indemnización por costes de cobro. La condición propia de un miembro prevalece sobre este valor. Cada factura conserva las cláusulas con las que se emitió.';

  @override
  String get invoiceLegalEscompteDefault => 'Sin descuento por pronto pago.';

  @override
  String get invoiceLegalEscompteField => 'Descuento por pronto pago';

  @override
  String get invoiceLegalFormField => 'Forma jurídica y capital';

  @override
  String get invoiceLegalFormHint => 'p. ej. SARL au capital de 7 500 €';

  @override
  String get invoiceLegalFormHintAssociation => 'p. ej. Association loi 1901';

  @override
  String get invoiceLegalInsuranceField => 'Seguro profesional';

  @override
  String get invoiceLegalIntro =>
      'Las menciones legales impresas en facturas y recordatorios. Las cláusulas de pago vacías usan los textos legales por defecto.';

  @override
  String get invoiceLegalKindAssociation => 'Asociación (sin ánimo de lucro)';

  @override
  String get invoiceLegalKindCompany => 'Empresa';

  @override
  String get invoiceLegalKindField => 'Tipo de organización';

  @override
  String get invoiceLegalLatePenaltyDefault =>
      'Penalización por demora: tres veces el tipo de interés legal.';

  @override
  String get invoiceLegalLatePenaltyField => 'Penalización por demora';

  @override
  String get invoiceLegalPaymentTermsDefault => 'Pago a la recepción.';

  @override
  String get invoiceLegalPaymentTermsField => 'Condiciones de pago';

  @override
  String get invoiceLegalRecoveryDefault =>
      'Indemnización fija por costes de cobro: 40 €.';

  @override
  String get invoiceLegalRecoveryField => 'Indemnización por costes de cobro';

  @override
  String get invoiceLegalRegistrationField => 'Registro mercantil';

  @override
  String get invoiceLegalRegistrationHint =>
      'p. ej. RCS Saint-Brieuc 680 357 910';

  @override
  String get invoiceLegalRegistrationHintAssociation =>
      'p. ej. RNA W123456789 · SIRET si está asignado';

  @override
  String get invoiceLegalSection => 'Menciones de facturación';

  @override
  String get invoiceLegalSpecialField => 'Menciones particulares';

  @override
  String get invoiceLineAdjustment => 'Ajuste';

  @override
  String get invoiceMatchAction => 'Marcar como pagada';

  @override
  String get invoiceMatchCreditNote =>
      'Crear una nota de crédito por el exceso';

  @override
  String get invoiceMatchForce => 'Aceptar de todos modos (justificar)';

  @override
  String get invoiceMatchNoPayments =>
      'No hay pago registrado que conciliar — regístralo o confírmalo primero.';

  @override
  String get invoiceMatchNoteLabel => 'Nota';

  @override
  String get invoiceMatchNoteRequired => 'Se requiere una nota.';

  @override
  String invoiceMatchOver(String excess) {
    return 'El miembro pagó $excess de más.';
  }

  @override
  String get invoiceMatchPendingBadge => 'Pendiente de validación';

  @override
  String get invoiceMatchPickPayment => 'Selecciona el pago registrado';

  @override
  String invoiceMatchSummary(String amount, String date) {
    return 'Pagada $amount el $date';
  }

  @override
  String invoiceMatchUnder(String missing) {
    return 'El miembro pagó $missing de menos — aceptar requiere una nota.';
  }

  @override
  String get invoiceMatched => 'Factura conciliada.';

  @override
  String get invoiceMatchedBadge => 'Pagada';

  @override
  String get invoiceMaturityReview =>
      'No se registró ningún plazo de pago acordado para esta factura: no se envían recordatorios automáticos hasta que la revises.';

  @override
  String get invoiceMemberLabel => 'Miembro';

  @override
  String get invoiceMissingBuyerAddress =>
      'La dirección postal del miembro (obligatoria para una empresa)';

  @override
  String get invoiceMissingBuyerName => 'El nombre o la empresa del miembro';

  @override
  String get invoiceMissingBuyerVatId =>
      'El número de IVA del miembro (necesario para la inversión del sujeto pasivo)';

  @override
  String get invoiceMissingExemptionReason =>
      'El fundamento legal de la exención de IVA';

  @override
  String get invoiceMissingSellerAddress =>
      'La dirección postal del espacio (calle o ciudad)';

  @override
  String get invoiceMissingSellerCountry =>
      'El país del espacio debe ser Francia o Alemania para emitir aquí — los demás países se emiten fuera de la aplicación';

  @override
  String get invoiceMissingSellerVatId =>
      'El número de identificación fiscal (IVA) del espacio';

  @override
  String get invoiceMissingTitle => 'Complete estos datos antes de emitir';

  @override
  String get invoiceMissingVatNotRegistered =>
      'Ningún IVA en las líneas: el espacio no cobra IVA, pero hay un tipo configurado en la suscripción o en un accesorio';

  @override
  String get invoiceMissingVatRate =>
      'Un tipo de IVA vigente para el tipo por defecto del espacio (si no, se facturaría 0 %)';

  @override
  String get invoiceMissingVatZeroLine =>
      'Un tipo de IVA para cada cargo: un cargo se factura al 0 % sin exportación, exención ni inversión del sujeto pasivo que lo explique';

  @override
  String get invoiceNoOpen => 'No hay facturas abiertas.';

  @override
  String get invoiceNothingToInvoice =>
      'Nada registrado este mes — nada que facturar.';

  @override
  String invoiceOpenAge(int days) {
    return '$days días';
  }

  @override
  String get invoicePdfActivity => 'Movimientos y pagos';

  @override
  String get invoicePdfAnnex => 'Anexo — detalles';

  @override
  String get invoicePdfAttendance => 'Asistencias';

  @override
  String get invoicePdfBilledTo => 'Facturar a';

  @override
  String get invoicePdfBuyerReference => 'Servicio';

  @override
  String get invoicePdfCharges => 'Cargos';

  @override
  String get invoicePdfCopy => 'Copia';

  @override
  String get invoicePdfCreditNote => 'Nota de crédito';

  @override
  String get invoicePdfDescription => 'Descripción';

  @override
  String get invoicePdfDueOn => 'Vencimiento';

  @override
  String get invoicePdfIssuedBy => 'Emitida por';

  @override
  String get invoicePdfIssuedOn => 'Emitida el';

  @override
  String get invoicePdfPage => 'Página';

  @override
  String get invoicePdfPayments => 'Pagos';

  @override
  String get invoicePdfProforma => 'Proforma';

  @override
  String get invoicePdfPurchaseOrder => 'Referencia de pedido';

  @override
  String get invoicePdfReplaces => 'Reemplaza a';

  @override
  String get invoicePdfReserved => 'reservado';

  @override
  String invoicePdfSettledIn(String number) {
    return 'Reagrupada en $number';
  }

  @override
  String get invoicePdfSignature => 'Firma digital (SHA-256)';

  @override
  String get invoicePdfTitle => 'Factura';

  @override
  String get invoicePdfVoided => 'ERRÓNEA — anulada el';

  @override
  String get invoicePickMember =>
      'Elige un miembro para ver lo que registró su mes.';

  @override
  String get invoiceProformaAction => 'Factura proforma';

  @override
  String get invoiceProformaNothing =>
      'Nada registrado este mes — no hay proforma que enviar.';

  @override
  String get invoiceProformaShared => 'Proforma compartida.';

  @override
  String get invoicePublicBuyer => 'Comprador público (Chorus Pro)';

  @override
  String get invoicePurchaseOrder => 'N.º de compromiso';

  @override
  String get invoicePurchaseOrderHint =>
      'Comprador público (Chorus Pro): el numéro d\'engagement.';

  @override
  String get invoiceRefundButton => 'Registrar el reembolso';

  @override
  String invoiceRefundExplain(String amount) {
    return 'Esta nota de crédito significa que el ESPACIO debe $amount al miembro. Registra el reembolso pagado — el importe se imputa al saldo del miembro y el documento se cierra como Reembolsada.';
  }

  @override
  String get invoiceRefundLabel => 'A reembolsar';

  @override
  String get invoiceRefunded => 'Reembolso registrado.';

  @override
  String get invoiceRegisterAllYears => 'Todos los años';

  @override
  String get invoiceRegisterAmount => 'Importe';

  @override
  String get invoiceRegisterDate => 'Fecha';

  @override
  String get invoiceRegisterName => 'Nombre';

  @override
  String get invoiceRegisterTitle => 'Registro de facturas';

  @override
  String get invoiceRegisterTotal => 'Total';

  @override
  String get invoiceRegisterYear => 'Año';

  @override
  String get invoiceRemainingLabel => 'Pendiente';

  @override
  String get invoiceRemindAction => 'Enviar un recordatorio';

  @override
  String get invoiceReminded => 'Recordatorio registrado.';

  @override
  String invoiceRemindedBadge(int count) {
    return 'Recordado ×$count';
  }

  @override
  String invoiceRemindedLast(String date) {
    return 'último recordatorio $date';
  }

  @override
  String invoiceReminderMessage(String number, String amount) {
    return 'Recordatorio amistoso: factura $number — saldo pendiente $amount.';
  }

  @override
  String get invoiceReminderNotSent =>
      'No se envió nada, así que no se registró nada.';

  @override
  String get invoiceReplaceAction => 'Emitir reemplazo';

  @override
  String invoiceReplacedBy(String number) {
    return 'Sustituida por $number';
  }

  @override
  String get invoiceRunningMonth =>
      'Este mes sigue en curso — sus posiciones aún pueden cambiar, y un mes solo se factura una vez.';

  @override
  String get invoiceSendAccepted => 'Enviada — la plataforma la aceptó.';

  @override
  String invoiceSendAcceptedTest(String env) {
    return 'Envío de prueba aceptado ($env).';
  }

  @override
  String get invoiceSendAction => 'Enviar a la plataforma gubernamental';

  @override
  String get invoiceSendCustomerAccepted =>
      'Enviada — el servicio del cliente la aceptó.';

  @override
  String get invoiceSendCustomerAction => 'Enviar al servicio del cliente';

  @override
  String get invoiceSendRejected => 'La plataforma la rechazó.';

  @override
  String get invoiceSendStatusAccepted => 'aceptada';

  @override
  String get invoiceSendStatusFailed => 'no transmitida';

  @override
  String get invoiceSendStatusRejected => 'rechazada';

  @override
  String invoiceSentOn(String date, String status) {
    return 'Enviada el $date · $status';
  }

  @override
  String get invoiceSentTestChip => 'prueba';

  @override
  String get invoiceShare => 'Compartir PDF';

  @override
  String get invoiceShowCancelled => 'Mostrar canceladas';

  @override
  String get invoiceSortByMember => 'Por miembro';

  @override
  String get invoiceSortByMonth => 'Por mes';

  @override
  String get invoiceSortNewest => 'Más recientes primero';

  @override
  String get invoiceSortTooltip => 'Ordenar';

  @override
  String get invoiceStatusOpen => 'Abierta';

  @override
  String get invoiceStatusPartiallyPaid => 'Parcialmente pagada';

  @override
  String get invoiceStatusRefunded => 'Reembolsada';

  @override
  String get invoiceStatusRemainderCancelled =>
      'Parcialmente pagada · saldo anulado';

  @override
  String invoiceSummaryOpen(int count, String amount) {
    return '$count abiertas · $amount pendiente';
  }

  @override
  String invoiceSummaryToInvoice(int count) {
    return '$count por facturar';
  }

  @override
  String invoiceSummaryToRefund(int count, String amount) {
    return '$count por reembolsar · $amount';
  }

  @override
  String get invoiceTabArchive => 'Archivo';

  @override
  String get invoiceTabOpen => 'Abiertas';

  @override
  String get invoiceTabToInvoice => 'Por facturar';

  @override
  String get invoiceTemplateBodyLabel =>
      'Banda de cuerpo (las líneas de la factura)';

  @override
  String get invoiceTemplateDocInvoice => 'Factura';

  @override
  String invoiceTemplateDocReminder(int level) {
    return 'Recordatorio $level';
  }

  @override
  String get invoiceTemplateDocStatement => 'Extracto';

  @override
  String get invoiceTemplateDownload => 'Descargar PDF';

  @override
  String get invoiceTemplateFooterLabel =>
      'Pie (bajo los totales — condiciones de pago, menciones legales)';

  @override
  String get invoiceTemplateHeaderLabel => 'Banda de cabecera';

  @override
  String get invoiceTemplateHint =>
      'Tres bandas de informe renderizadas en el PDF — el XML de la factura electrónica nunca se toca. Condiciones y bucles Liquid, luego marcado de líneas:';

  @override
  String get invoiceTemplateIntroLabel =>
      'Introducción (sobre el bloque del destinatario)';

  @override
  String get invoiceTemplateNoPreview =>
      'Emite primero una factura — la vista previa usa la más reciente.';

  @override
  String get invoiceTemplatePresets => 'Plantillas';

  @override
  String get invoiceTemplatePreview => 'Vista previa';

  @override
  String get invoiceTemplateQuickPreview => 'Vista rápida';

  @override
  String get invoiceTemplateReset => 'Restablecer al modelo por defecto';

  @override
  String get invoiceTemplateSaved => 'Plantilla de factura guardada.';

  @override
  String get invoiceTemplateShare => 'Compartir PDF';

  @override
  String get invoiceTemplateTitle => 'Plantilla del PDF de factura';

  @override
  String get invoiceVoidAction => 'Marcar como errónea';

  @override
  String invoiceVoidConfirm(String number) {
    return '¿Marcar la factura $number como errónea? Esta acción no se puede deshacer.';
  }

  @override
  String get invoiceVoided => 'Factura marcada como errónea.';

  @override
  String get invoiceVoidedChip => 'Errónea';

  @override
  String get invoiceWizardAction => 'Asistente de cierre mensual';

  @override
  String get invoiceWriteoffButton => 'Anular el saldo pendiente';

  @override
  String get invoiceWriteoffExplain =>
      'El saldo impagado de esta factura se anulará y la factura se archivará como parcialmente pagada — cuando la validación lo confirme. Hasta entonces sigue abierta y adeudada.';

  @override
  String get invoiceWriteoffRequested =>
      'Anulación solicitada — pendiente de validación.';

  @override
  String get invoicesEmpty => 'Aún no hay facturas.';

  @override
  String get invoicesManage => 'Gestionar facturas';

  @override
  String get invoicesTitle => 'Facturas';

  @override
  String get invoicingBanner =>
      'Emite y reclama las facturas de todo el espacio. Sus propias facturas y pagos están en Yo › Finanzas.';

  @override
  String get invoicingHubTitle => 'Facturación';

  @override
  String get invoicingMyFinances => 'Mis finanzas';

  @override
  String get invoicingTools => 'Herramientas de facturación';

  @override
  String journeyClosedPaid(String date) {
    return 'Pagada el $date — cerrada';
  }

  @override
  String journeyClosedRefunded(String date) {
    return 'Reembolsada el $date — cerrada';
  }

  @override
  String journeyClosedRemainder(String date) {
    return 'Cerrada — resto cancelado el $date';
  }

  @override
  String journeyClosedReplaced(String number) {
    return 'Anulada — reemplazada por $number';
  }

  @override
  String get journeyClosedSettled =>
      'Reagrupada en otra factura — esa es la que se debe y se reclama';

  @override
  String get journeyHowButton => 'Cómo funciona';

  @override
  String get journeyHowClosedMember =>
      'El mes se lee saldado y la factura sigue legible para siempre: vista rápida, PDF, compartir.';

  @override
  String get journeyHowClosedWorkspace =>
      'Pagada, resto cancelado o reembolsada: la factura pasa al archivo. Una factura errónea se marca como tal y se reemplaza — antes del pago, nunca después.';

  @override
  String get journeyHowConfirmationMember =>
      'Nada que hacer — salvo que el espacio registrara el pago por él: entonces lo confirma en Eventos.';

  @override
  String get journeyHowConfirmationWorkspace =>
      'Otro admin confirma el pago declarado; el emisor concilia luego el pago registrado con la factura (Marcar pagada) — una regla de validación puede pasar la conciliación a los validadores. ¿Pagó de más? Una nota de crédito. ¿De menos? Parcialmente pagada, el resto se debe hasta pagarlo o cancelarlo.';

  @override
  String get journeyHowIntro =>
      'Cuatro pasos, los mismos para cada factura. Cada uno dice a quién le toca.';

  @override
  String get journeyHowIssuedMember =>
      'La encuentra en la vista Facturas: partidas, saldo, vencimiento.';

  @override
  String get journeyHowIssuedWorkspace =>
      'Emite la factura a partir de los datos del mes — numerada, firmada, inmutable — y comparte el PDF o envía la factura electrónica.';

  @override
  String get journeyHowMemberLabel => 'Miembro';

  @override
  String get journeyHowPaymentMember =>
      'Paga en línea (liquidado al instante) o por transferencia, y luego registra el pago para que el espacio lo sepa.';

  @override
  String get journeyHowPaymentWorkspace =>
      'Espera el dinero. Pasado el plazo envía los niveles de recordatorio configurados — a mano o automáticamente.';

  @override
  String get journeyHowTitle => 'Cómo funciona la facturación';

  @override
  String get journeyHowWorkspaceLabel => 'Espacio';

  @override
  String journeyIssuerAdminConfirms(String name, String amount) {
    return '$name declaró un pago de $amount — otro admin lo confirma en Eventos';
  }

  @override
  String journeyIssuerMatches(String amount) {
    return 'Hay un pago de $amount registrado — concílielo con esta factura';
  }

  @override
  String journeyIssuerMemberConfirms(String name, String amount) {
    return 'Se registró un pago de $amount — $name lo confirma en Eventos';
  }

  @override
  String journeyIssuerMemberPays(String name, String amount, String date) {
    return 'Esperando el pago de $name: $amount — vence $date';
  }

  @override
  String journeyIssuerMemberPaysOverdue(String name, String amount, int days) {
    return '$name debe $amount — $days días de retraso';
  }

  @override
  String journeyIssuerMemberPaysRemainder(String name, String amount) {
    return '$name aún debe $amount tras un pago parcial';
  }

  @override
  String journeyIssuerRefunds(String name, String amount) {
    return 'Nota de crédito — reembolse $amount a $name y regístrelo';
  }

  @override
  String get journeyIssuerReplaces => 'Anulada — emita la factura de reemplazo';

  @override
  String journeyMemberConfirms(String amount) {
    return 'Le toca: confirme en Eventos el pago de $amount registrado para usted';
  }

  @override
  String journeyMemberDeclared(String amount) {
    return 'Declaró $amount — el espacio lo está confirmando';
  }

  @override
  String journeyMemberPays(String amount, String date) {
    return 'Le toca: pague $amount antes del $date';
  }

  @override
  String journeyMemberPaysOverdue(String amount, int days) {
    return 'Le toca: pague $amount — $days días de retraso';
  }

  @override
  String journeyMemberPaysRemainder(String amount) {
    return 'Le toca: pague el resto de $amount';
  }

  @override
  String journeyMemberRefund(String amount) {
    return 'El espacio le debe $amount — nada que pagar';
  }

  @override
  String journeyMemberRegistered(String amount) {
    return 'Su pago de $amount está registrado — el espacio lo concilia con esta factura';
  }

  @override
  String get journeyMemberReplaces =>
      'Anulada — sigue una factura de reemplazo';

  @override
  String get journeyMemberValidators =>
      'Pago conciliado — pendiente de validación';

  @override
  String get journeyMemberWriteoff =>
      'El espacio pidió cancelar el resto — pendiente de validación';

  @override
  String journeyOutstanding(String amount) {
    return '$amount pendientes';
  }

  @override
  String journeyOverdueCount(int count) {
    return '$count atrasadas';
  }

  @override
  String get journeyPrimaryConfirmInEvents => 'Abrir Eventos';

  @override
  String journeyPrimaryRemind(int level) {
    return 'Enviar recordatorio $level';
  }

  @override
  String get journeyStageClosed => 'Cerradas';

  @override
  String get journeyStageCollect => 'Por cobrar';

  @override
  String get journeyStageConfirm => 'Por confirmar';

  @override
  String get journeyStageIssue => 'Por emitir';

  @override
  String get journeyStageStripLabel =>
      'El proceso de facturación: emitir, cobrar, confirmar, cerrar';

  @override
  String get journeyStepClosed => 'Cerrada';

  @override
  String get journeyStepConfirmation => 'Confirmación';

  @override
  String get journeyStepIssued => 'Emitida';

  @override
  String get journeyStepPayment => 'Pago';

  @override
  String get journeyTimelineTitle => 'Cronología';

  @override
  String get journeyValidatorsMatch =>
      'Pago conciliado — a la espera de la decisión de los validadores';

  @override
  String get journeyValidatorsWriteoff =>
      'Cancelación del resto solicitada — a la espera de los validadores';

  @override
  String get kioskBadgeConfirm => 'Confirmar';

  @override
  String get kioskBadgeFieldLabel => 'Código de credencial';

  @override
  String get kioskBadgeHint =>
      'Escanea el QR de tu credencial o escribe su código.';

  @override
  String get kioskBadgeHintNfc =>
      'Acerca tu tarjeta, escanea tu QR o escribe el código.';

  @override
  String get kioskBadgeRejected => 'Credencial no reconocida.';

  @override
  String kioskBasis(String granularity, String hours) {
    return 'Regla: $granularity · hoy $hours';
  }

  @override
  String kioskBlockedContactHint(String name) {
    return 'Ocupado por $name — puedes escribirle desde la aplicación en tu teléfono.';
  }

  @override
  String get kioskCheckIn => 'Registrarse';

  @override
  String get kioskCheckInRightAway => 'Registrarse ahora mismo';

  @override
  String get kioskCheckInRightAwayHint =>
      'Estás aquí: la reserva empieza registrada.';

  @override
  String get kioskCheckOut => 'Salir';

  @override
  String get kioskClosedToday =>
      'El espacio está cerrado hoy — no es posible registrarse ni reservar.';

  @override
  String get kioskConfirmAction => 'Confirmar';

  @override
  String get kioskDone => 'Listo — todo en orden.';

  @override
  String get kioskGateBody =>
      'Esta cuenta está configurada como quiosco del espacio. En modo quiosco la tableta solo muestra el plano para fichar con la tarjeta — no se puede abrir nada más. Para salir del modo quiosco, reinicia la tableta.';

  @override
  String get kioskGateReject => 'Ahora no — abrir la app normalmente';

  @override
  String get kioskGateStart => 'Iniciar el modo quiosco';

  @override
  String get kioskGateTitle => '¿Iniciar el modo quiosco?';

  @override
  String get kioskLevelButton => 'Esta planta';

  @override
  String get kioskNfcFailed =>
      'El lector RFID no se inició — reinicia la aplicación e inténtalo de nuevo.';

  @override
  String get kioskNfcOff =>
      'El NFC está desactivado en los ajustes de Android de esta tableta — actívalo para leer tarjetas RFID.';

  @override
  String get kioskNfcUnsupported =>
      'Esta tableta no tiene lector NFC — escanea la tarjeta QR en su lugar.';

  @override
  String get kioskNotCheckedIn =>
      'No hay ningún registro activo — puede que el plano se acabe de actualizar.';

  @override
  String get kioskPeriodCheckInHint =>
      '¿Hasta cuándo te quedas? El registro empieza ahora.';

  @override
  String get kioskPeriodReserveHint => 'Elige el periodo: solo hoy.';

  @override
  String get kioskPresentBadge => 'Presenta tu credencial';

  @override
  String get kioskPresentBadgeNext => 'Presentar la tarjeta';

  @override
  String get kioskRejectAction => 'Rechazar';

  @override
  String get kioskReserve => 'Reservar';

  @override
  String get kioskReserveAndCheckIn => 'Reservar y registrarse';

  @override
  String get kioskRestOfDay => 'Resto del día';

  @override
  String get kioskRevertDesc =>
      'Este perfil está configurado como quiosco del espacio. Reviértelo a miembro normal para que la pregunta de quiosco no aparezca al iniciar.';

  @override
  String get kioskRevertDone => 'Este perfil vuelve a ser un miembro normal.';

  @override
  String get kioskRevertTitle => 'Dispositivo quiosco';

  @override
  String get kioskScanQr => 'Escanear la tarjeta QR';

  @override
  String get kioskTapHint => 'Toca un asiento para registrarte';

  @override
  String get languageNameCS => 'Checo';

  @override
  String get languageNameDA => 'Danés';

  @override
  String get languageNameDE => 'Alemán';

  @override
  String get languageNameEL => 'Griego';

  @override
  String get languageNameEN => 'Inglés';

  @override
  String get languageNameES => 'Español';

  @override
  String get languageNameFI => 'Finés';

  @override
  String get languageNameFR => 'Francés';

  @override
  String get languageNameHU => 'Húngaro';

  @override
  String get languageNameIT => 'Italiano';

  @override
  String get languageNameJA => 'Japonés';

  @override
  String get languageNameNB => 'Noruego';

  @override
  String get languageNameNL => 'Neerlandés';

  @override
  String get languageNamePL => 'Polaco';

  @override
  String get languageNamePT => 'Portugués';

  @override
  String get languageNameRO => 'Rumano';

  @override
  String get languageNameSV => 'Sueco';

  @override
  String get languageSystemDefault => 'Predeterminado del sistema';

  @override
  String get languageTitle => 'Idioma';

  @override
  String get ledgerCategoryAdjustment => 'Ajuste';

  @override
  String get ledgerCategoryExpense => 'Reembolso de gasto';

  @override
  String get ledgerCategoryOverage => 'Exceso';

  @override
  String get ledgerCategoryPayment => 'Pago';

  @override
  String get ledgerCategoryService => 'Servicio';

  @override
  String get ledgerCategorySubscription => 'Suscripción';

  @override
  String get legalIdentityAssociationRegime =>
      'Una asociación sin actividad lucrativa no está sujeta al IVA: elija «Fuera del ámbito del IVA», no «Exento». El régimen de exención exige un número de IVA que no tiene, y la factura electrónica sería rechazada. Fuera del ámbito, su número de registro identifica a la asociación.';

  @override
  String get legalIdentityCity => 'Ciudad';

  @override
  String get legalIdentityExemptionReason =>
      'Motivo por el que no se cobra IVA';

  @override
  String get legalIdentityIntro =>
      'Lo que una factura electrónica EN 16931 debe indicar sobre ti. Las facturas ya emitidas conservan la identidad con la que se firmaron.';

  @override
  String get legalIdentityLegalId => 'Número de registro';

  @override
  String get legalIdentityPostalCode => 'Código postal';

  @override
  String get legalIdentityRegime => 'Régimen de IVA';

  @override
  String get legalIdentityRegimeExempt =>
      'Exento de IVA (régimen de franquicia)';

  @override
  String get legalIdentityRegimeHint =>
      'El régimen decide qué número exige la norma: un número de registro fuera del ámbito del IVA, un número de IVA si está exento.';

  @override
  String get legalIdentityRegimeNotSubject => 'Fuera del ámbito del IVA';

  @override
  String get legalIdentityRegimeVatRegistered => 'Sujeto a IVA (cobra IVA)';

  @override
  String get legalIdentitySaved => 'Identidad legal guardada.';

  @override
  String get legalIdentityStreet => 'Calle';

  @override
  String get legalIdentitySubtitle =>
      'Régimen de IVA, identificadores y las condiciones de pago por defecto del espacio';

  @override
  String get legalIdentityTitle => 'Identidad legal y facturación electrónica';

  @override
  String get legalIdentityVatId => 'Número de IVA';

  @override
  String get legalIdentityVatWarning =>
      'Este espacio cobra IVA pero no hay ningún tipo configurado: las facturas no muestran impuesto y la exportación XML sigue desactivada.';

  @override
  String get legendBlocked => 'Bloqueada';

  @override
  String get legendClosed => 'Día cerrado';

  @override
  String get legendFree => 'Libre';

  @override
  String get legendMine => 'Mía';

  @override
  String get legendOccupied => 'Con check-in';

  @override
  String get legendProfileFull => 'Todos los estados';

  @override
  String get legendProfileFullDesc =>
      'Libre · Reservada · Presente · La mía · Bloqueada: se ve quién ha llegado.';

  @override
  String get legendProfileSimple => 'Menos estados';

  @override
  String get legendProfileSimpleDesc =>
      'Libre · Reservada · La mía · No disponible. Una plaza reservada y otra donde alguien ha llegado se ven igual.';

  @override
  String get legendProfileTitle => 'Lo que el plano distingue';

  @override
  String get legendReserved => 'Reservada';

  @override
  String get legendUnavailable => 'No disponible';

  @override
  String get levelAssignMember => 'Para el miembro';

  @override
  String get levelAssignMyself => 'Yo mismo';

  @override
  String get levelBookableDesc =>
      'La planta entera puede reservarse como una sola reserva.';

  @override
  String get levelBookableToggle => 'Reservable en su totalidad';

  @override
  String get levelConflict => 'La planta tiene reservas en ese periodo.';

  @override
  String get levelDetail => 'Planta entera';

  @override
  String get levelFeatureOff =>
      'Las reservas de oficina y planta están desactivadas en Funciones.';

  @override
  String get levelNotAllowed =>
      'No tienes permiso para reservar una mesa, oficina o planta entera.';

  @override
  String get levelPermissionAllowed =>
      'Puede reservar una mesa, oficina o planta entera';

  @override
  String get levelPermissionDenied =>
      'No puede reservar una mesa, oficina o planta entera';

  @override
  String get levelPermissionTile => 'Reservas de planta';

  @override
  String get levelPriceLabel => 'Precio por media jornada';

  @override
  String get levelReorderStale =>
      'Los niveles cambiaron mientras tanto. No se guardó nada; se muestra el orden actual.';

  @override
  String get levelReserveButton => 'Reservar la planta';

  @override
  String get levelReserveTitle => 'Reservar la planta entera';

  @override
  String get levelSupplementLabel => 'Reservas de planta';

  @override
  String get libraryApplied => 'Plantilla aplicada.';

  @override
  String libraryAppliedChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cambios aplicados.',
      one: '1 cambio aplicado.',
    );
    return '$_temp0';
  }

  @override
  String get libraryApply => 'Aplicar a este espacio';

  @override
  String libraryApplyChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Aplicar $count cambios',
      one: 'Aplicar 1 cambio',
      zero: 'Nada seleccionado',
    );
    return '$_temp0';
  }

  @override
  String get libraryApplyConfirmBody =>
      'El plano se añade o actualiza por nombre, y los ajustes que lleva la plantilla se fusionan. No se elimina nada de lo que ya tiene.';

  @override
  String libraryApplyConfirmTitle(String name) {
    return '¿Aplicar « $name »?';
  }

  @override
  String get libraryCarriesSettings => 'con sus ajustes';

  @override
  String libraryConfirmSensitive(String groups) {
    return 'Esto cambia: $groups. ¿Aplicar?';
  }

  @override
  String libraryCounts(int levels, int desks, int seats) {
    return '$levels niveles · $desks mesas · $seats plazas';
  }

  @override
  String get libraryCustomizedHere => 'Personalizado aquí';

  @override
  String get libraryDelete => 'Eliminar plantilla';

  @override
  String libraryDeleteConfirm(String name) {
    return '¿Eliminar « $name »? Las personas con quienes la compartió pierden el acceso.';
  }

  @override
  String get libraryEmpty =>
      'Nada aquí todavía. Guarde este espacio como plantilla o espere a que alguien comparta una con usted.';

  @override
  String libraryFeatureNeeds(String feature, String prerequisite) {
    return '$feature necesita $prerequisite, que sigue desactivado: todavía no funcionará.';
  }

  @override
  String get libraryGroupAppearance => 'Apariencia';

  @override
  String get libraryGroupCalendarNavigation => 'Calendario y cierres';

  @override
  String get libraryGroupDocumentsOperations => 'Documentos y funcionamiento';

  @override
  String get libraryGroupForms => 'Formularios';

  @override
  String get libraryGroupHoursBooking => 'Horarios y reservas';

  @override
  String get libraryGroupPricingCredits => 'Precios y créditos';

  @override
  String get libraryGroupRolesAccess => 'Roles y acceso';

  @override
  String get libraryGroupSpace => 'Espacio y plano';

  @override
  String get libraryGroupUnknown => 'Otro — esta versión no puede aplicarlo';

  @override
  String get libraryGroupWording => 'Vocabulario';

  @override
  String get libraryInvitationTexts => 'Textos de invitación';

  @override
  String libraryInvitationTextsHint(String tag) {
    return 'Solo textos escritos con marcadores como $tag; un texto que nombre su espacio o a sus personas se rechaza.';
  }

  @override
  String get libraryInvitationTextsRefused =>
      'Un texto de invitación todavía nombra su espacio o a sus personas. Sustitúyalos por marcadores en los ajustes de invitación o desmarque los textos de invitación.';

  @override
  String get libraryNeverDocumentDesign => 'Diseño de los documentos';

  @override
  String get libraryNeverDocumentLinks => 'Enlaces a sus documentos';

  @override
  String get libraryNeverIdentity =>
      'Su dirección, identificadores legales, menciones legales y grupo de WhatsApp';

  @override
  String get libraryNeverInvitations => 'Textos de invitación';

  @override
  String get libraryNeverPayment => 'Datos bancarios';

  @override
  String get libraryNeverPublished => 'Nunca se publica';

  @override
  String get libraryNeverSites => 'Las sedes y sus direcciones';

  @override
  String get libraryNotSupported => 'Esta plantilla no puede aplicarse aquí.';

  @override
  String get libraryNothingToApply =>
      'Todo lo que trae esta plantilla ya está aquí.';

  @override
  String get libraryPartial =>
      'Una parte de esta plantilla no puede aplicarse aquí y se deja fuera.';

  @override
  String libraryPlanNames(String names) {
    return 'Estos nombres viajan con el plano: $names';
  }

  @override
  String get libraryPreviewChanges => 'Ver los cambios';

  @override
  String get libraryPreviewFailed =>
      'No se pudieron previsualizar los cambios. No se aplicó nada.';

  @override
  String libraryPreviewTitle(String name) {
    return 'Qué cambiaría « $name »';
  }

  @override
  String libraryProcessOff(String feature) {
    return '$feature desactivada';
  }

  @override
  String libraryProcessOn(String feature) {
    return '$feature activada';
  }

  @override
  String get libraryProcessTechnical => 'Técnico';

  @override
  String get libraryPublishGroups => 'Lo que viaja';

  @override
  String get libraryPublishNothing => 'Elija al menos un grupo.';

  @override
  String get libraryReasonFeeSchedule =>
      'Su escala de comisiones se sustituiría entera.';

  @override
  String get librarySave => 'Guardar este espacio como plantilla';

  @override
  String get librarySaveDescription => 'Descripción (opcional)';

  @override
  String get librarySaveName => 'Nombre de la plantilla';

  @override
  String get librarySaveTags => 'Etiquetas, separadas por comas';

  @override
  String get librarySaved => 'Guardado en sus plantillas.';

  @override
  String librarySearchCapabilities(String capabilities) {
    return 'Plantillas configuradas para: $capabilities';
  }

  @override
  String get librarySearchHint => 'Buscar plantillas';

  @override
  String librarySearchSuggestion(String word) {
    return '¿Quiso decir «$word»?';
  }

  @override
  String get librarySearchUnavailable =>
      'No se pudieron comprobar los ajustes de las plantillas, así que ninguna aparece como coincidente. Inténtelo de nuevo.';

  @override
  String get libraryShare => 'Compartir…';

  @override
  String get libraryShareAdd => 'Invitar';

  @override
  String get libraryShareEmail => 'Dirección de e-mail';

  @override
  String get libraryShareHint =>
      'Invite por e-mail. La invitación funciona en cuanto esa dirección inicia sesión; no se revela si ya tiene cuenta.';

  @override
  String get libraryShareNobody => 'Nadie invitado todavía.';

  @override
  String libraryShareTitle(String name) {
    return 'Compartir « $name »';
  }

  @override
  String get libraryStartFrom => 'Partir de la biblioteca';

  @override
  String get libraryStateAttention => 'Requiere atención';

  @override
  String get libraryStateChange => 'Cambia lo que tiene';

  @override
  String get libraryStateMatching => 'Ya es igual';

  @override
  String get libraryStateNew => 'Nuevo';

  @override
  String get libraryTitle => 'Biblioteca de espacios';

  @override
  String get libraryVisibility => 'Quién puede verla';

  @override
  String get libraryVisibilityBuiltin => 'Integrada';

  @override
  String get libraryVisibilityPrivate => 'Solo yo';

  @override
  String get libraryVisibilityPublic => 'Todos (la biblioteca)';

  @override
  String get libraryVisibilityShared => 'Personas que invito';

  @override
  String get libraryYours => 'Sus plantillas';

  @override
  String get linkedAccountsIntro =>
      'Inicia sesión en esta cuenta con una identidad vinculada. Los proveedores disponibles dependen de tu servidor.';

  @override
  String get linkedAccountsLink => 'Vincular';

  @override
  String get linkedAccountsLinkStarted =>
      'Continúa en el navegador para terminar la vinculación.';

  @override
  String get linkedAccountsLinked => 'Vinculada';

  @override
  String get linkedAccountsTitle => 'Cuentas vinculadas';

  @override
  String get linkedAccountsUnlink => 'Desvincular';

  @override
  String listCoversSeats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count puestos',
      one: '1 puesto',
    );
    return '$_temp0';
  }

  @override
  String listCoversTables(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mesas',
      one: '1 mesa',
    );
    return '$_temp0';
  }

  @override
  String get listWholeReservable => 'Reservable entero';

  @override
  String get localGapsTitle => 'Para terminar de configurar este espacio';

  @override
  String get localNeedsTitle =>
      'Los añadirá usted; una plantilla nunca los transporta:';

  @override
  String get localSlotEinvoicePlatform =>
      'Su cuenta en la plataforma de facturación electrónica';

  @override
  String get localSlotLegalIdentity =>
      'Su identidad legal y su dirección (para las facturas)';

  @override
  String localSlotNamedValidators(String type) {
    return 'Quién valida: $type';
  }

  @override
  String get localSlotOpen => 'Configurar';

  @override
  String get localSlotPaymentDetails =>
      'Cómo le pagan los miembros (datos bancarios)';

  @override
  String get localSlotPaymentProvider => 'Un proveedor de pagos en línea';

  @override
  String get localSlotRecommended => 'Recomendado';

  @override
  String get localSlotSite => 'Al menos una sede';

  @override
  String get managedAccessAdmins => 'Admins';

  @override
  String get managedAccessDefault => 'Todo propietario y todo admin';

  @override
  String get managedAccessHint =>
      'Por defecto: todo propietario y todo admin. Restrinja por rol, por persona o ambos. El propietario siempre puede cambiar esta regla — si no, un perfil quedaría inadministrable — pero solo accede a los datos si la regla lo nombra.';

  @override
  String get managedAccessOwners => 'Propietarios';

  @override
  String get managedAccessPeople => 'Personas nombradas';

  @override
  String get managedAccessSaved => 'Regla guardada.';

  @override
  String get managedAccessTitle => 'Quién puede administrar este perfil';

  @override
  String get managedProfileAdd => 'Añadir un perfil gestionado';

  @override
  String get managedProfileChip => 'Gestionado';

  @override
  String get managedProfileCreated => 'Perfil gestionado creado';

  @override
  String get managedProfileEdit => 'Editar identidad';

  @override
  String get managedProfileHandOver => 'Entregar a la persona';

  @override
  String get managedProfileHandOverHint =>
      'Genera un código personal ligado a este perfil. Quien lo canjee se hace con el perfil — reservas, facturas, suscripción — en cuanto apruebes la membresía.';

  @override
  String get managedProfileIdentityUnavailable =>
      'No se han podido leer estos datos, así que todavía no hay nada que editar. No se ha cambiado nada.';

  @override
  String get managedProfileIntro =>
      'Esta persona aún no tiene cuenta. Reservas, facturas y gestionas por ella; entrégale el perfil cuando se una.';

  @override
  String get managedProfileRevoke => 'Revocar la entrega';

  @override
  String get managedProfileRevoked => 'Entrega revocada';

  @override
  String get managedProfileSaved => 'Identidad guardada';

  @override
  String get managedProfileTitle => 'Perfil gestionado';

  @override
  String get mcpApiReference => 'Referencia de la API';

  @override
  String get mcpApiReferenceHint =>
      'Qué puede llamar un asistente y cómo se autoriza';

  @override
  String get mcpAssistantsTitle => 'Asistentes';

  @override
  String get mcpAssistantsUnavailable =>
      'No se pudo cargar su acceso a asistentes. Inténtelo más tarde.';

  @override
  String get mcpCancel => 'Cancelar';

  @override
  String get mcpConfirmAccept => 'Confirmar';

  @override
  String get mcpConfirmApprove => 'Su respuesta: aprobar';

  @override
  String mcpConfirmClient(String client) {
    return 'Solicitado por: $client';
  }

  @override
  String get mcpConfirmConsequence =>
      'Confirmar permite al asistente enviar esta solicitud exacta una sola vez. Las reglas de validación del espacio siguen aplicándose.';

  @override
  String get mcpConfirmDecline => 'Rechazar';

  @override
  String get mcpConfirmDeclined => 'Rechazado. No se ha hecho nada.';

  @override
  String get mcpConfirmDone =>
      'Confirmado. El asistente ya puede enviar la solicitud.';

  @override
  String get mcpConfirmExpired =>
      'Esta solicitud ha caducado. Pida al asistente que la envíe de nuevo.';

  @override
  String mcpConfirmNewShare(String pct) {
    return 'Nueva parte de suscripción: $pct %';
  }

  @override
  String mcpConfirmNewStatus(String status) {
    return 'Nuevo estado: $status';
  }

  @override
  String get mcpConfirmNotFound => 'No hay ninguna solicitud así para usted.';

  @override
  String mcpConfirmPeriod(String period) {
    return 'Periodo: $period';
  }

  @override
  String get mcpConfirmRefuse => 'Su respuesta: rechazar';

  @override
  String get mcpConfirmStale =>
      'Esta solicitud ya no coincide con los datos actuales o con su acceso. No se ha hecho nada.';

  @override
  String get mcpConfirmTitle => 'Confirmar una solicitud del asistente';

  @override
  String get mcpConfirmUnavailable =>
      'No se pudo cargar esta solicitud. Vuelva a intentarlo desde el enlace.';

  @override
  String mcpConfirmWorkspace(String workspace) {
    return 'Espacio: $workspace';
  }

  @override
  String mcpConnectAccessExpiresIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días',
      one: '1 día',
    );
    return 'Aprobado — quedan $_temp0.';
  }

  @override
  String mcpConnectAccessExpiresSoon(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días',
      one: '1 día',
    );
    return 'Aprobado — caduca en $_temp0. Vuelva a pedir la aprobación cuando caduque.';
  }

  @override
  String get mcpConnectAddTitle => 'Añadir DesKilo a su asistente';

  @override
  String get mcpConnectAddressLabel =>
      'Su dirección de DesKilo para asistentes';

  @override
  String get mcpConnectAllDone =>
      'Todo está listo. Pruebe la conexión más abajo.';

  @override
  String get mcpConnectBeforeTitle => 'Antes de conectar';

  @override
  String get mcpConnectChatgptNote =>
      'El modo desarrollador requiere un plan de pago de ChatGPT (Plus, Pro, Business, Enterprise o Edu).';

  @override
  String get mcpConnectChatgptStep1 =>
      'En ChatGPT, active el modo desarrollador: Ajustes → Apps → Ajustes avanzados.';

  @override
  String get mcpConnectChatgptStep2 =>
      'Cree una app llamada DesKilo, pegue la dirección de arriba y elija OAuth como autenticación.';

  @override
  String get mcpConnectChatgptStep3 =>
      'Inicie sesión con Google y elija este espacio de trabajo y lo que ChatGPT puede hacer en él.';

  @override
  String get mcpConnectClaudeNote =>
      'Claude en la web, Claude Desktop y la app móvil de Claude comparten los mismos conectores. En un plan Team o Enterprise, un propietario de la organización de Claude añade primero el conector.';

  @override
  String get mcpConnectClaudeOpen => 'Abrir los conectores de Claude';

  @override
  String get mcpConnectClaudeStep1 => 'En Claude, abra Ajustes → Conectores.';

  @override
  String get mcpConnectClaudeStep2 =>
      'Elija «Añadir conector personalizado», llámelo DesKilo y pegue la dirección de arriba.';

  @override
  String get mcpConnectClaudeStep3 =>
      'Elija Conectar, inicie sesión con Google y elija este espacio de trabajo y lo que Claude puede hacer en él.';

  @override
  String get mcpConnectCodeStep1 => 'Ejecute esto en un terminal:';

  @override
  String get mcpConnectCodeStep2 =>
      'En Claude Code, escriba /mcp, elija deskilo y luego Authenticate. Se abre un navegador para iniciar sesión y elegir este espacio de trabajo.';

  @override
  String get mcpConnectCopied => 'Copiado.';

  @override
  String get mcpConnectCopyRequest => 'Copiar una solicitud para enviar';

  @override
  String get mcpConnectCursorInstall => 'Añadir a Cursor';

  @override
  String get mcpConnectCursorStep =>
      'Cursor propone instalar DesKilo y luego abre un navegador para iniciar sesión y elegir este espacio de trabajo. Sin el botón, añada esto a ~/.cursor/mcp.json:';

  @override
  String get mcpConnectDone => 'Hecho';

  @override
  String get mcpConnectIntro =>
      'Deje que Claude, ChatGPT u otro asistente consulte y reserve por usted en DesKilo. Actúa en su nombre, solo en los espacios de trabajo y para las acciones que usted apruebe.';

  @override
  String mcpConnectLastCall(String client, String when) {
    return 'Última llamada: $client, $when.';
  }

  @override
  String get mcpConnectManageHint =>
      'Para ver lo que hizo un asistente o desconectarlo, abra Asistentes.';

  @override
  String get mcpConnectOpenFailed =>
      'No se pudo abrir la aplicación desde aquí. Siga los pasos de abajo.';

  @override
  String get mcpConnectOpenGuide => 'Abrir la guía de conexión';

  @override
  String get mcpConnectOpenInstallation => 'Abrir la consola de la instalación';

  @override
  String get mcpConnectOpenSetup => 'Abrir la configuración de asistentes';

  @override
  String get mcpConnectOperatorRequest =>
      'Hola, ¿podría activar los asistentes en nuestro servidor DesKilo? Está en Ajustes → Instalación: asistentes. Gracias.';

  @override
  String get mcpConnectOtherStep1 =>
      'La mayoría de los clientes leen un archivo JSON de servidores. Añada esta entrada; el cliente abre un navegador para iniciar sesión la primera vez.';

  @override
  String get mcpConnectOtherStep2 =>
      'Un cliente que solo inicia programas locales puede llegar a DesKilo mediante mcp-remote (requiere Node.js):';

  @override
  String get mcpConnectRoleDenied =>
      'Aquí no se ofrece nada a su rol. Un administrador del espacio de trabajo decide qué puede hacer cada rol.';

  @override
  String get mcpConnectStepAccess => 'Su acceso a los asistentes';

  @override
  String get mcpConnectStepConnect => 'DesKilo añadido a su asistente';

  @override
  String get mcpConnectStepGoogle => 'Inicio de sesión con Google';

  @override
  String get mcpConnectStepIdentity => 'Su identidad en este servidor';

  @override
  String get mcpConnectStepServer => 'Asistentes activados en este servidor';

  @override
  String get mcpConnectStepWorkspace =>
      'Este espacio de trabajo ofrece asistentes';

  @override
  String get mcpConnectSwitchWorkspace => 'Cambiar a este espacio de trabajo';

  @override
  String get mcpConnectTabChatgpt => 'ChatGPT';

  @override
  String get mcpConnectTabClaude => 'Claude';

  @override
  String get mcpConnectTabClaudeCode => 'Claude Code';

  @override
  String get mcpConnectTabCursor => 'Cursor';

  @override
  String get mcpConnectTabOther => 'Otro';

  @override
  String get mcpConnectTabVscode => 'VS Code';

  @override
  String get mcpConnectTest => 'Probar la conexión';

  @override
  String get mcpConnectTestAgain => 'Probar de nuevo';

  @override
  String get mcpConnectTestPrompt =>
      'Con DesKilo, ¿cuáles son mis reservas de esta semana?';

  @override
  String mcpConnectTestReached(String client, String when) {
    return 'Conectado: $client llegó a DesKilo, $when.';
  }

  @override
  String get mcpConnectTestTimeout =>
      'Aún no ha llegado ninguna llamada. Compruebe que el conector está añadido, que aprobó este espacio de trabajo y que los pasos de arriba están hechos; luego pruebe de nuevo.';

  @override
  String get mcpConnectTestTitle => 'Comprobar que funciona';

  @override
  String get mcpConnectTestWaiting =>
      'Esperando a que su asistente llame a DesKilo. Pregúntele:';

  @override
  String get mcpConnectTitle => 'Conectar un asistente';

  @override
  String get mcpConnectTodoConnect =>
      'Pendiente — usted: siga los pasos para su asistente más abajo.';

  @override
  String get mcpConnectTodoYou => 'Pendiente — usted.';

  @override
  String get mcpConnectUnavailable => 'No se pudo comprobar ahora.';

  @override
  String get mcpConnectVscodeInstall => 'Añadir a VS Code';

  @override
  String get mcpConnectVscodeStep =>
      'VS Code propone instalar DesKilo. Inícielo desde la lista de servidores MCP; se abre un navegador para iniciar sesión y elegir este espacio de trabajo.';

  @override
  String get mcpConnectWaitingDatabaseAdmin =>
      'Esperando a que un administrador de la base de datos apruebe su solicitud.';

  @override
  String mcpConnectWaitingOperator(String names) {
    return 'Esperando al operador del servidor: $names.';
  }

  @override
  String get mcpConnectWaitingOperatorUnknown =>
      'Esperando al operador del servidor, que aún no está designado.';

  @override
  String get mcpConnectWaitingWorkspaceAdmin =>
      'Esperando a que un administrador del espacio de trabajo ofrezca asistentes aquí.';

  @override
  String get mcpConnectWhich => '¿Qué asistente usa?';

  @override
  String get mcpConnectWorkspaceSelected => 'Espacio de trabajo seleccionado';

  @override
  String get mcpConnectWorkspacesHint =>
      'Cada espacio de trabajo decide por sí mismo. Cuando su asistente lo pida, usted elige entre los que están listos.';

  @override
  String get mcpConnectWorkspacesTitle => 'Sus espacios de trabajo';

  @override
  String get mcpConnectWsConnected =>
      'Conectado — un asistente puede actuar por usted aquí.';

  @override
  String get mcpConnectWsNotOffered =>
      'Los asistentes están activados, pero aún no se ofrece nada a su rol. Decide un administrador del espacio de trabajo.';

  @override
  String get mcpConnectWsOff =>
      'Los asistentes están desactivados en este espacio de trabajo. Un administrador del espacio de trabajo los activa en la configuración de asistentes.';

  @override
  String get mcpConnectWsReady =>
      'Listo — elíjalo cuando su asistente lo pida.';

  @override
  String get mcpConnectWsUnknown =>
      'Se muestra cuando se apruebe su acceso a los asistentes.';

  @override
  String get mcpConnectedNoWorkspace =>
      'Ningún espacio: este asistente no puede hacer nada aquí.';

  @override
  String get mcpConnectedNone =>
      'No hay ningún asistente conectado. Conecte uno desde el propio asistente.';

  @override
  String get mcpConnectedTitle => 'Asistentes conectados';

  @override
  String get mcpConsentAlready =>
      'Este asistente ya está conectado. Volviendo a él.';

  @override
  String get mcpConsentApprove => 'Conectar';

  @override
  String mcpConsentAsks(String client) {
    return '$client pide actuar por usted en Deskilo.';
  }

  @override
  String get mcpConsentChoose =>
      'Elija cada espacio y lo que el asistente puede hacer allí. No se elige nada por usted.';

  @override
  String mcpConsentClientBlocked(String name) {
    return 'El operador ha bloqueado $name en este servidor. No se puede conectar.';
  }

  @override
  String mcpConsentClientWaiting(String name) {
    return '$name aún no está aprobado en este servidor. El operador aprueba cada asistente una vez; después vuelva a conectar desde el asistente.';
  }

  @override
  String get mcpConsentConnected => 'Conectado. Volviendo al asistente.';

  @override
  String mcpConsentDeciderAsk(String name) {
    return 'Pida a $name que decida.';
  }

  @override
  String get mcpConsentDeciderMe =>
      'Lo decide usted mismo, en la consola de la instalación.';

  @override
  String get mcpConsentDeciderNobody =>
      'Nadie responde todavía de este servidor.';

  @override
  String get mcpConsentDenied => 'Rechazado. El asistente no obtiene nada.';

  @override
  String get mcpConsentDeny => 'Rechazar';

  @override
  String get mcpConsentFamilyChatgpt =>
      'Aprobado para todas las conexiones de ChatGPT.';

  @override
  String get mcpConsentFamilyClaude =>
      'Aprobado para todas las conexiones de Claude.';

  @override
  String get mcpConsentFamilyLoopback =>
      'Aprobado para asistentes de escritorio y de línea de comandos en este equipo.';

  @override
  String get mcpConsentFieldsExplain =>
      'Detalles que también puede ver aquí. Déjelos sin marcar para mantener sus respuestas minimizadas.';

  @override
  String get mcpConsentNoWorkspace =>
      'Ninguno de sus espacios admite asistentes. No se puede conectar nada.';

  @override
  String get mcpConsentNotEligible =>
      'Esta base de datos aún no ha aprobado asistentes para usted. Solicite la aprobación y vuelva a conectar.';

  @override
  String get mcpConsentPartial =>
      'El asistente fue aprobado pero la conexión aún no se puede usar. Vuelva a conectar desde el asistente.';

  @override
  String mcpConsentRedirectHost(String host) {
    return 'La respuesta se envía a $host.';
  }

  @override
  String get mcpConsentRequestEligibility => 'Solicitar aprobación';

  @override
  String get mcpConsentRequested =>
      'Aprobación solicitada. Un administrador de la base de datos la revisará.';

  @override
  String get mcpConsentTitle => 'Conectar un asistente';

  @override
  String get mcpConsentUnavailable =>
      'No se pudo cargar esta solicitud de conexión. Empiece de nuevo desde el asistente.';

  @override
  String get mcpDisclosureMaximumExplain =>
      'Lo máximo que los propietarios de esta base de datos pueden dejar ver a los asistentes. Nunca amplía la política de un espacio ni el consentimiento de una persona.';

  @override
  String get mcpDisclosureMaximumLocked =>
      'Confirme con su segundo factor para ver y cambiar el máximo.';

  @override
  String get mcpDisclosureMaximumRefused =>
      'El máximo no se guardó. Necesita su segundo factor.';

  @override
  String get mcpDisclosureMaximumSave => 'Guardar el máximo';

  @override
  String get mcpDisclosureMaximumSaved => 'Máximo guardado.';

  @override
  String get mcpDisclosureNoneAllowed =>
      'Esta base de datos no permite mostrar ningún detalle opcional a los asistentes.';

  @override
  String get mcpDisclosurePolicyExplain =>
      'Los asistentes reciben respuestas minimizadas. Elija los detalles que también pueden ver aquí; cada persona sigue eligiendo por sí misma.';

  @override
  String get mcpDisclosurePreviewDetailed => 'Respuesta detallada';

  @override
  String get mcpDisclosurePreviewMinimised => 'Respuesta minimizada';

  @override
  String get mcpDisclosurePreviewNote =>
      'Una respuesta ficticia, para mostrar lo que verían los asistentes.';

  @override
  String get mcpDisclosureTitle => 'Detalles opcionales';

  @override
  String get mcpDisclosureUnlock => 'Confirmar';

  @override
  String get mcpDisconnect => 'Desconectar';

  @override
  String get mcpDisconnectBody =>
      'El asistente pierde el acceso a todos los espacios de esta base de datos. Lo que ya leyó no se recupera.';

  @override
  String mcpDisconnectTitle(String client) {
    return '¿Desconectar $client?';
  }

  @override
  String get mcpEligibleExpired =>
      'Su aprobación caducó. Vuelva a solicitarla para seguir usando asistentes.';

  @override
  String get mcpEligibleNoIdentity =>
      'Su identidad aún no está confirmada para los asistentes en esta base.';

  @override
  String get mcpEligibleNot =>
      'Esta base de datos no ha aprobado asistentes para usted.';

  @override
  String get mcpEligibleRequested =>
      'Solicitó la aprobación. Un administrador de la base de datos la revisará.';

  @override
  String get mcpEligibleWithdraw =>
      'Renunciar al acceso de asistentes en esta base de datos';

  @override
  String get mcpEligibleYes => 'Esta base de datos le permite usar asistentes.';

  @override
  String get mcpFieldName => 'Nombres de espacios y puestos';

  @override
  String get mcpFieldNameSample => 'Escritorio ventana 12';

  @override
  String get mcpGroupFinancial => 'Solicitudes financieras';

  @override
  String get mcpGroupMembership => 'Solicitudes de membresía';

  @override
  String get mcpGroupOwn => 'Reservas y cuenta propias';

  @override
  String get mcpGroupValidations => 'Validaciones';

  @override
  String get mcpIdentityConflict =>
      'Otra cuenta ya tiene esta identidad aquí: un administrador de la base puede resolverlo.';

  @override
  String get mcpIdentityIneligible =>
      'Esta cuenta aún no puede confirmarse: confirme primero su dirección de correo o inicie sesión con un proveedor.';

  @override
  String get mcpNextAwaitEligibility =>
      'Siguiente paso: un administrador de la base de datos decide su solicitud.';

  @override
  String get mcpNextConsent =>
      'Siguiente paso: conecte un asistente desde el propio asistente y apruebe este espacio de trabajo.';

  @override
  String get mcpNextLinkGoogle =>
      'Los asistentes usan su inicio de sesión con Google. Vincule primero Google a esta cuenta; sin ello, la cuenta no puede usar asistentes.';

  @override
  String get mcpNextLinkIdentity =>
      'Siguiente paso: confirme su identidad para los asistentes en esta base, con un toque abajo.';

  @override
  String get mcpNextOwnerExposes =>
      'Siguiente paso: el propietario del espacio de trabajo ofrece operaciones a los asistentes.';

  @override
  String get mcpNextReady =>
      'Listo: un asistente conectado puede actuar por usted en este espacio de trabajo, dentro de lo que aprobó.';

  @override
  String get mcpNextRequestEligibility =>
      'Siguiente paso: pida la aprobación a los administradores de esta base de datos.';

  @override
  String get mcpNextRoleDenied =>
      'Su rol no deja aquí ninguna operación. El propietario del espacio de trabajo decide lo que puede hacer cada rol.';

  @override
  String get mcpNextSignInGoogle =>
      'Los asistentes usan su inicio de sesión con Google. Inicie sesión con Google para continuar.';

  @override
  String get mcpNextUnavailable =>
      'El servidor no pudo responder. No se supone nada; inténtelo más tarde.';

  @override
  String get mcpOpAvailability => 'Ver plazas libres';

  @override
  String get mcpOpCancelReservation =>
      'Cancelar sus reservas que aún no han empezado';

  @override
  String get mcpOpCapabilities => 'Ver qué puede hacer allí';

  @override
  String get mcpOpCheckIn => 'Registrar su entrada';

  @override
  String get mcpOpCheckOut => 'Registrar su salida';

  @override
  String get mcpOpCreateReservation => 'Reservar una plaza por usted';

  @override
  String get mcpOpGetPlace => 'Describir un lugar y mostrarlo si lo pide';

  @override
  String get mcpOpGetValidation => 'Leer una solicitud de validación';

  @override
  String get mcpOpInvoiceIssue => 'Emitir una factura';

  @override
  String get mcpOpInvoiceVoid => 'Anular una factura';

  @override
  String get mcpOpListMyFavorites => 'Sus lugares favoritos';

  @override
  String get mcpOpListWorkspaces => 'Ver qué espacios puede usar';

  @override
  String get mcpOpMemberStatus => 'Cambiar el estado de un miembro';

  @override
  String get mcpOpMyInvoices => 'Ver sus facturas';

  @override
  String get mcpOpMyReservations => 'Ver sus reservas';

  @override
  String get mcpOpMyStatement => 'Ver su estado de cuenta';

  @override
  String get mcpOpPendingValidations =>
      'Ver solicitudes de validación pendientes';

  @override
  String get mcpOpRatePlace => 'Valorar lugares';

  @override
  String get mcpOpRefund => 'Reembolsar una factura';

  @override
  String get mcpOpReservationDeletion =>
      'Pedir la eliminación de una reserva ya iniciada';

  @override
  String get mcpOpRespond => 'Responder a una solicitud de validación';

  @override
  String get mcpOpSetFavorite => 'Marcar lugares como favoritos';

  @override
  String get mcpOpSubscription =>
      'Cambiar la parte de suscripción de un miembro';

  @override
  String get mcpOpUpdateReservation => 'Cambiar sus reservas';

  @override
  String get mcpOverviewTitle => 'Otras bases de datos conectadas';

  @override
  String get mcpOverviewUnavailable => 'No se pudo consultar ahora.';

  @override
  String get mcpPolicyBroadening =>
      'Los asistentes ya conectados no reciben los servicios añadidos: cada persona debe añadirlos al volver a conectar.';

  @override
  String get mcpPolicyCeiling =>
      'Registros sobre los que puede actuar un asistente';

  @override
  String get mcpPolicyCeilingOwn => 'Solo registros propios';

  @override
  String get mcpPolicyCeilingWorkspace => 'Todo el espacio';

  @override
  String get mcpPolicyConflict =>
      'Se rechazó este guardado. Revise los ajustes actuales y guarde de nuevo.';

  @override
  String get mcpPolicyEnabled => 'Ofrecer servicios de asistente';

  @override
  String get mcpPolicyExplain =>
      'Elija qué pueden hacer los asistentes en este espacio. Un miembro sigue necesitando la aprobación de esta base de datos, el rol adecuado, y debe elegir este espacio al conectar su asistente.';

  @override
  String get mcpPolicyFeatureOff =>
      'Los asistentes están desactivados en las funciones de este espacio. Aún puede restringir o desactivar los servicios de abajo.';

  @override
  String get mcpPolicySave => 'Guardar';

  @override
  String get mcpPolicySaved => 'Guardado.';

  @override
  String get mcpPolicyStale =>
      'Alguien cambió estos ajustes mientras tanto. Revise los ajustes actuales y guarde de nuevo.';

  @override
  String get mcpPolicySwitched =>
      'Ha cambiado de espacio. Vuelva a abrir esta página para editar el otro espacio.';

  @override
  String get mcpPolicyTitle => 'Acceso de asistentes';

  @override
  String get mcpPolicyUnavailable =>
      'No se pudieron cargar los ajustes de asistentes. Inténtelo más tarde.';

  @override
  String get mcpRefusalClientNotApproved =>
      'Este asistente aún no está aprobado en este servidor. El operador aprueba cada asistente una vez; pídaselo y vuelva a conectar desde el asistente.';

  @override
  String get mcpRefusalNoIdentity =>
      'Confirme primero su identidad en DesKilo en Asistentes y vuelva a conectar desde el asistente.';

  @override
  String get mcpRefusalNotEligible =>
      'Su acceso a los asistentes aún no está aprobado. Solicítelo en DesKilo en Asistentes y vuelva a conectar desde el asistente.';

  @override
  String get mcpRefusalOfferChanged =>
      'Lo que ofrece este espacio de trabajo cambió mientras elegía. Vuelva a conectar desde el asistente para ver la oferta actual.';

  @override
  String get mcpRefusalRequestExpired =>
      'Esta solicitud de conexión ha caducado o ya se usó. Empiece de nuevo desde el asistente.';

  @override
  String get mcpRemoveWorkspace => 'Quitar este espacio';

  @override
  String get mcpReviewApprove => 'Aprobar';

  @override
  String get mcpReviewChanged =>
      'Esta solicitud cambió u otro administrador decidió antes. No se hizo nada.';

  @override
  String get mcpReviewDone => 'Decisión registrada.';

  @override
  String get mcpReviewEmpty => 'No hay solicitudes pendientes.';

  @override
  String get mcpReviewExplain =>
      'Aprobar permite a una persona conectar asistentes en esta base de datos, en los espacios cuyos propietarios lo admiten. No otorga membresía ni rol.';

  @override
  String get mcpReviewNotAdmin =>
      'Solo los administradores de esta base de datos revisan las aprobaciones.';

  @override
  String get mcpReviewRefused => 'La decisión fue rechazada.';

  @override
  String get mcpReviewReject => 'Rechazar';

  @override
  String get mcpReviewSecondFactor =>
      'Esa base de datos necesita su segundo factor en su propia sesión. No se decidió nada.';

  @override
  String get mcpReviewTitle => 'Aprobaciones de asistentes';

  @override
  String get mcpReviewUnavailable =>
      'No se pudieron cargar las solicitudes. Una revisión necesita su segundo factor; inténtelo de nuevo.';

  @override
  String get mcpStateAfterPrevious => 'Después del paso anterior';

  @override
  String get mcpStateAllowed => 'Permitido';

  @override
  String get mcpStateApproved => 'Aprobada';

  @override
  String get mcpStateAvailable => 'Accesible';

  @override
  String get mcpStateCurrent => 'Otorgado';

  @override
  String get mcpStateDenied => 'Nada para su rol';

  @override
  String get mcpStateDisabled => 'Nada ofrecido';

  @override
  String get mcpStateExposed => 'Operaciones ofrecidas';

  @override
  String get mcpStateGoogleMissing => 'Google no vinculado';

  @override
  String get mcpStateGoogleOtherSession => 'Sesión iniciada de otra forma';

  @override
  String get mcpStateGoogleReady => 'Sesión iniciada con Google';

  @override
  String get mcpStateIncompatible => 'Versión incompatible';

  @override
  String get mcpStateMissing => 'No otorgado';

  @override
  String get mcpStateNotRequested => 'No solicitada';

  @override
  String get mcpStatePending => 'En espera de una decisión';

  @override
  String get mcpStateRevoked => 'Caducada o retirada';

  @override
  String get mcpStateUnavailable => 'Desconocido';

  @override
  String get mcpStateUnlinked => 'No confirmada';

  @override
  String get mcpStateVerified => 'Verificada';

  @override
  String get mcpStatusBackend => 'Servidor';

  @override
  String get mcpStatusConfirmIdentity => 'Confirmar mi identidad';

  @override
  String get mcpStatusConsent => 'Su consentimiento';

  @override
  String get mcpStatusEligibility => 'Aprobación de la base de datos';

  @override
  String get mcpStatusExposure => 'Oferta del espacio de trabajo';

  @override
  String get mcpStatusGoogle => 'Inicio de sesión con Google';

  @override
  String get mcpStatusIdentity => 'Identidad para asistentes';

  @override
  String get mcpStatusLinkGoogle => 'Vincular Google';

  @override
  String get mcpStatusOpenLinkedAccounts => 'Abrir cuentas vinculadas';

  @override
  String get mcpStatusRole => 'Su rol';

  @override
  String get mcpStatusSignInGoogle => 'Iniciar sesión con Google';

  @override
  String get mcpStatusTitle => 'Su situación aquí';

  @override
  String get mcpUsageApplied => 'Aplicadas';

  @override
  String mcpUsageLastUsed(String when) {
    return 'Último uso $when';
  }

  @override
  String get mcpUsageMineTitle => 'Su uso de asistentes hoy';

  @override
  String get mcpUsageNone => 'Ningún asistente ha usado todavía su acceso.';

  @override
  String get mcpUsagePending => 'Pendientes de validación';

  @override
  String get mcpUsageRefusals => 'Rechazadas';

  @override
  String get mcpUsageRequests => 'Solicitudes';

  @override
  String get mcpUsageUnavailable => 'No se pudo cargar el uso.';

  @override
  String get mcpUsageWorkspaceTitle => 'Uso de asistentes, últimos 30 días';

  @override
  String get meAccountInMe => 'Mi cuenta está en Yo';

  @override
  String get meAccountInMeBody =>
      'Foto, idioma, tema e inicios de sesión son tuyos en todos los espacios.';

  @override
  String get meAddressSaveFailed =>
      'No se pudo guardar tu dirección. Inténtalo de nuevo.';

  @override
  String get meCreateSpace => 'Crear un espacio';

  @override
  String meFinanceGlanceOwed(String amount) {
    return 'A pagar: $amount';
  }

  @override
  String get meFindSpace => 'Buscar un espacio';

  @override
  String get meGroupAdd => 'Nuevo grupo';

  @override
  String get meGroupDelete => 'Eliminar grupo';

  @override
  String get meGroupEmptyFavorites =>
      'Dale un corazón a un espacio y te espera aquí.';

  @override
  String get meGroupEmptyOwn => 'Mueve espacios aquí desde su menú.';

  @override
  String get meGroupFavorites => 'Favoritos';

  @override
  String get meGroupInstallations => 'Instalaciones conectadas';

  @override
  String get meGroupMove => 'Mover a un grupo…';

  @override
  String get meGroupName => 'Nombre del grupo';

  @override
  String get meGroupOther => 'Otros';

  @override
  String get meGroupProfile => 'Mi perfil';

  @override
  String get meGroupRename => 'Renombrar';

  @override
  String get meGroupWorkspaces => 'Mis espacios de trabajo';

  @override
  String get meHeaderOwned => 'Tu cuenta · solo te pertenece a ti';

  @override
  String get meHomeTitle => 'Inicio';

  @override
  String get meJoinSpace => 'Unirse con un código';

  @override
  String get meLeaveAction => 'Salir de este espacio';

  @override
  String get meLeaveBody =>
      'Dejas de ser miembro. Tus reservas, facturas y mensajes se quedan en el espacio. Para borrar también tus datos, usa Privacidad.';

  @override
  String meLeaveDone(String name) {
    return 'Has salido de $name.';
  }

  @override
  String get meLeaveFailed =>
      'No se pudo salir del espacio. Inténtalo de nuevo.';

  @override
  String get meLeaveOwner =>
      'Los propietarios traspasan el espacio antes de salir';

  @override
  String meLeaveSide(String side) {
    return 'Salir de $side';
  }

  @override
  String meLeaveTitle(String name) {
    return '¿Salir de $name?';
  }

  @override
  String meLinkedOpen(String host) {
    return 'Abrir en $host';
  }

  @override
  String meLinkedOpenBody(String host) {
    return 'Este espacio está en $host. La app trabaja con un servidor a la vez: abrirlo cambia a ese servidor y te pide iniciar sesión allí.';
  }

  @override
  String meLinkedPendingOn(String host) {
    return 'Pendiente de aprobación · $host';
  }

  @override
  String meLinkedUnavailable(String host) {
    return '$host no respondió: esta lista puede estar incompleta.';
  }

  @override
  String get meManageSpaces => 'Gestionar mis espacios';

  @override
  String get meMySpaces => 'Mis espacios';

  @override
  String get meNoSpaceBody =>
      'Busca uno cerca de ti, únete con un código de invitación o crea el tuyo.';

  @override
  String get meNoSpaceTitle => 'Aún no estás en ningún espacio';

  @override
  String get meSectionMine => 'Mi historial y mis datos';

  @override
  String get meSortAlphabet => 'A–Z';

  @override
  String get meSortHand => 'Mi orden';

  @override
  String get meSortRating => 'Mejor valorados';

  @override
  String get meSortRecent => 'Usados recientemente';

  @override
  String get meSortTooltip => 'Ordenar';

  @override
  String get meSpaceException => 'En este espacio';

  @override
  String get meSpaceLastUsed => 'Último usado';

  @override
  String get meSpaceOpen => 'Abrir';

  @override
  String get meSpacePending => 'Pendiente de aprobación';

  @override
  String get meSpacesNoMatch => 'Ningún espacio coincide.';

  @override
  String get meSpacesSearch => 'Buscar mis espacios';

  @override
  String get meTabDiscover => 'Descubrir';

  @override
  String get meTabHome => 'Inicio';

  @override
  String get meTabMe => 'Yo';

  @override
  String get meTabMessages => 'Mensajes';

  @override
  String get meWhereSpacesLive => 'Dónde están mis espacios';

  @override
  String get memberAccountTitle => 'Mi cuenta';

  @override
  String get memberAllAdmins => 'todos los admins';

  @override
  String get memberApprove => 'Aprobar membresía';

  @override
  String memberBadgesTitle(String name) {
    return 'Credenciales — $name';
  }

  @override
  String get memberBadgesTooltip => 'Credenciales';

  @override
  String get memberCoOwnerChip => 'Copropietario';

  @override
  String get memberCoOwnerPassiveChip => 'Sucesor';

  @override
  String get memberContactHeading => 'Contacto';

  @override
  String get memberHomeSiteDefault => 'Dirección del espacio';

  @override
  String get memberHomeSiteLabel => 'Sede de referencia';

  @override
  String memberInvoiceOpen(String amount) {
    return '$amount pendientes';
  }

  @override
  String get memberInvoicePaid => 'Pagada';

  @override
  String get memberInvoiceVoided => 'Anulada';

  @override
  String get memberInvoicesBanner =>
      'Todas sus facturas y pagos, de todos los espacios, están en Yo › Finanzas.';

  @override
  String get memberKioskLabel => 'Quiosco';

  @override
  String get memberMakeAdmin => 'Dar el rol Administrador/a';

  @override
  String get memberMakeKiosk => 'Convertir en quiosco';

  @override
  String get memberMakeMember => 'Retirar el rol Administrador/a';

  @override
  String get memberMessagesAction => 'Mensajes';

  @override
  String get memberMoneySettled => 'Nada pendiente.';

  @override
  String get memberMoneyUnavailable =>
      'No se pudieron cargar las finanzas. Tire para actualizar.';

  @override
  String get memberMonthInProgress => 'Este mes';

  @override
  String memberMoreInvoices(int count) {
    return '+$count más';
  }

  @override
  String get memberNoActions =>
      'Solo el propietario del espacio puede modificar este miembro.';

  @override
  String get memberNoSubscription => 'Sin suscripción';

  @override
  String get memberNoSubscriptionPaygHint =>
      'Sin suscripción no es posible con pago por uso: elija primero bloquear o un paquete.';

  @override
  String get memberNoteDelete => 'Eliminar';

  @override
  String get memberNoteDeleteConfirm =>
      '¿Eliminar este mensaje? No se puede deshacer.';

  @override
  String get memberNoteDeleteNotMine =>
      'Solo quien lo envió puede retirar un mensaje.';

  @override
  String get memberNoteDeleteRead =>
      'Ya leído: este mensaje ya no se puede retirar.';

  @override
  String get memberNoteDeleted => 'Mensaje eliminado.';

  @override
  String get memberNoteHint => 'Tu mensaje';

  @override
  String memberNoteReceived(String name) {
    return 'Mensaje de $name';
  }

  @override
  String get memberNoteReply => 'Responder';

  @override
  String get memberNoteSend => 'Enviar';

  @override
  String get memberNoteSent => 'Notificación enviada.';

  @override
  String memberNoteTitle(String name) {
    return 'Notificar a $name';
  }

  @override
  String memberNoteTo(String name) {
    return 'Para $name';
  }

  @override
  String get memberNoteToAllAdmins => 'Para todos los admins';

  @override
  String get memberNotifyAction => 'Enviar notificación';

  @override
  String get memberNotifyAllAdmins => 'Notificar a todos los admins';

  @override
  String get memberNumberLabel => 'N.º de socio';

  @override
  String get memberOriginDelegated => 'Perfil creado por un administrador';

  @override
  String get memberOriginFounder => 'Fundó este espacio';

  @override
  String get memberOriginHeading => 'Cómo empezó esta afiliación';

  @override
  String get memberOriginInvited => 'Se unió por invitación';

  @override
  String get memberOveragePolicyLabel => 'Cuando se acaban los días';

  @override
  String get memberOveragePolicyTooltip => 'Exceso de consumo';

  @override
  String get memberPageAddService => 'Añadir un servicio';

  @override
  String memberPageCheckedIn(String seat, String time) {
    return 'Registrado · $seat · desde las $time';
  }

  @override
  String get memberPageEmailAction => 'Correo';

  @override
  String get memberPageGroupAccess => 'Tarjetas y acceso';

  @override
  String get memberPageGroupBilling => 'Facturación';

  @override
  String get memberPageGroupBooking => 'Reglas de reserva';

  @override
  String get memberPageGroupMembership => 'Membresía';

  @override
  String get memberPageLevelTitle => 'Reservas de un espacio entero';

  @override
  String get memberPageManageHeading => 'Gestionar';

  @override
  String get memberPageNeverSeen => 'Nunca visto';

  @override
  String memberPageNext(String label) {
    return 'Próxima: $label';
  }

  @override
  String get memberPageNone => 'Ninguno';

  @override
  String get memberPageNowHeading => 'Ahora mismo';

  @override
  String memberPageReservedNow(String seat, String time) {
    return 'Reservado ahora · $seat · hasta las $time';
  }

  @override
  String memberPageSince(String date) {
    return 'Socio desde el $date';
  }

  @override
  String get memberPageStatusActive => 'Activo';

  @override
  String memberPageWorkspaceDefaultValue(int count) {
    return 'Predeterminado del espacio ($count)';
  }

  @override
  String memberPageYou(String name) {
    return '$name (tú)';
  }

  @override
  String get memberPause => 'Pausar la membresía';

  @override
  String get memberPayments => 'Pagos';

  @override
  String memberPlanShare(String pct) {
    return 'Plan $pct %';
  }

  @override
  String get memberReactivate => 'Reactivar la membresía';

  @override
  String get memberRejectJoin => 'Rechazar membresía';

  @override
  String memberReservationLimitChip(int n) {
    return 'máx. $n';
  }

  @override
  String get memberReservationLimitCustom => 'Personalizado (1–100)';

  @override
  String get memberReservationLimitExplainer =>
      'Cuántas reservas abiertas puede tener este miembro a la vez.';

  @override
  String get memberReservationLimitLabel => 'Límite de reservas';

  @override
  String get memberReservationLimitNone => 'Sin límite';

  @override
  String get memberReservationLimitTooltip => 'Límite de reservas';

  @override
  String get memberRoleAdmin => 'Administrador/a';

  @override
  String get memberRoleChangeRequested =>
      'Cambio de rol enviado para validación.';

  @override
  String get memberRoleMember => 'Miembro';

  @override
  String get memberRoleOwner => 'Propietario';

  @override
  String get memberRolesAdd => 'Añadir un rol';

  @override
  String get memberRolesNone =>
      'Ningún rol: todo lo que puede hacer un miembro.';

  @override
  String get memberRolesTitle => 'Roles';

  @override
  String get memberRolesWhatTheyCanDo => 'Lo que esta persona puede hacer aquí';

  @override
  String get memberSendAgreement => 'Enviar el acuerdo financiero';

  @override
  String memberSimultaneousLimitChip(int n) {
    return '$n a la vez';
  }

  @override
  String get memberSimultaneousLimitDefault => 'Valor del espacio';

  @override
  String get memberSimultaneousLimitExplainer =>
      'Cuántas reservas puede tener este miembro en el mismo periodo. Sin definir, se aplica el valor por defecto del espacio.';

  @override
  String get memberSimultaneousLimitLabel => 'Reservas simultáneas';

  @override
  String get memberStatusActive => 'Activo';

  @override
  String get memberStatusExited => 'Salido';

  @override
  String get memberStatusPaused => 'En pausa';

  @override
  String get memberStatusPending => 'Pendiente';

  @override
  String get memberSubscriptionCustom => 'Personalizado (1–100)';

  @override
  String get memberSubscriptionLabel => 'Suscripción';

  @override
  String get memberUnmakeKiosk => 'Revertir quiosco a miembro';

  @override
  String get memberVatTreatmentExplainer =>
      'Quién es este miembro a efectos de IVA: la regla automática (inversión del sujeto pasivo para una empresa de otro Estado de la UE), IVA nacional en todo caso, inversión del sujeto pasivo, fuera de la UE o un comprador exento con el motivo impreso en la factura.';

  @override
  String get memberVatTreatmentLabel => 'Tratamiento del IVA';

  @override
  String get membersInvite => 'Invitar a un miembro';

  @override
  String get membersPlanNone => 'Sin plan';

  @override
  String get membersTitle => 'Miembros y planes';

  @override
  String get messageInfo => 'Info del mensaje';

  @override
  String get messageNotReadYet => 'Aún sin leer';

  @override
  String get messageReadBy => 'Leído por';

  @override
  String get messageRequestsHint =>
      'Estas personas no están entre quienes elegiste para poder contactarte. No se les avisa de tu decisión.';

  @override
  String get messageRequestsTitle => 'Solicitudes de mensaje';

  @override
  String get messageSearchGroups => 'Grupos';

  @override
  String get messageSearchHint => 'Miembros, grupos, mensajes';

  @override
  String get messageSearchMessages => 'Mensajes';

  @override
  String get messageSearchNothing => 'Sin resultados.';

  @override
  String get messageSearchPeople => 'Miembros';

  @override
  String get messageSearchPrompt => 'Busque miembros, grupos y lo que se dijo.';

  @override
  String get messageSearchTitle => 'Buscar';

  @override
  String get messagesEmpty => 'Aún no hay conversaciones.';

  @override
  String get messagesTitle => 'Mensajes';

  @override
  String get messengerContextAccount => 'De persona a persona';

  @override
  String get messengerContextGroup => 'Grupo';

  @override
  String messengerContextInquiryIn(String space) {
    return 'Consulta a $space';
  }

  @override
  String messengerContextInquiryOut(String space) {
    return 'Tu consulta a $space';
  }

  @override
  String messengerContextSpace(String space) {
    return 'En $space';
  }

  @override
  String get messengerCopied => 'Copiado.';

  @override
  String get messengerCopy => 'Copiar texto';

  @override
  String get messengerDelete => 'Eliminar mensaje';

  @override
  String get messengerDeleteConfirm =>
      '¿Eliminar este mensaje para todas las personas de la conversación?';

  @override
  String get messengerDeleted => 'Mensaje eliminado.';

  @override
  String get messengerDelivered => 'Entregado';

  @override
  String get messengerEdit => 'Editar';

  @override
  String get messengerEditFailed =>
      'No se pudo editar el mensaje — quizá pasaron los 15 minutos.';

  @override
  String get messengerEditTitle => 'Editar mensaje';

  @override
  String get messengerEditWindow =>
      'Un mensaje se puede corregir durante 15 minutos tras enviarlo.';

  @override
  String get messengerEdited => 'editado';

  @override
  String messengerEventCaptured(String actor) {
    return 'Captura de pantalla de $actor';
  }

  @override
  String messengerEventDeleted(String actor) {
    return 'Eliminado por $actor';
  }

  @override
  String messengerEventForwarded(String actor, String target) {
    return 'Reenviado por $actor a $target';
  }

  @override
  String messengerEventForwardedFrom(String actor, String context) {
    return 'Escrito originalmente por $actor en $context';
  }

  @override
  String messengerEventForwardedPrivate(String actor) {
    return 'Reenviado por $actor a una conversación personal';
  }

  @override
  String messengerEventOther(String event, String actor) {
    return '$event · $actor';
  }

  @override
  String messengerEventRead(String actor) {
    return 'Leído por $actor';
  }

  @override
  String messengerEventSent(String actor) {
    return 'Enviado por $actor';
  }

  @override
  String get messengerForward => 'Reenviar';

  @override
  String get messengerForwardExplain =>
      'Todas las personas de la conversación original, primero quien la escribió, sabrán quién la reenvió, cuándo y adónde.';

  @override
  String get messengerForwardLocked =>
      'La persona autora ha bloqueado el reenvío de este mensaje.';

  @override
  String get messengerForwardNoTargets =>
      'No hay otra conversación en este servidor a la que reenviar.';

  @override
  String get messengerForwardTitle => 'Reenviar a';

  @override
  String messengerForwarded(String target) {
    return 'Reenviado a $target.';
  }

  @override
  String messengerForwardedFrom(String context, String author) {
    return 'Reenviado desde $context · escrito por $author';
  }

  @override
  String get messengerHistory => 'Qué ha pasado';

  @override
  String get messengerHistoryEmpty =>
      'Aún no hay nada registrado para este mensaje.';

  @override
  String get messengerHostsIntro =>
      'Tu mensaje lo leen estos anfitriones del espacio:';

  @override
  String get messengerHostsNone =>
      'En este espacio nadie responde mensajes ahora mismo.';

  @override
  String messengerInboxUnavailable(String servers) {
    return 'No disponible ahora: $servers. Sus conversaciones faltan en esta lista.';
  }

  @override
  String get messengerInquiriesEmpty => 'Aún no hay consultas.';

  @override
  String get messengerInquiriesTitle => 'Consultas';

  @override
  String get messengerInquiryClose => 'Cerrar consulta';

  @override
  String get messengerInquiryClosed => 'Consulta cerrada.';

  @override
  String messengerInquiryFrom(String name) {
    return 'De $name';
  }

  @override
  String get messengerInquirySend => 'Enviar consulta';

  @override
  String get messengerLock => 'Bloquear el reenvío';

  @override
  String get messengerMessageActions => 'Acciones del mensaje';

  @override
  String get messengerNoStarred => 'Aún no hay mensajes destacados.';

  @override
  String messengerNoticeCaptured(String actor) {
    return '$actor hizo una captura de pantalla de esta conversación.';
  }

  @override
  String messengerNoticeForwarded(String actor, String target) {
    return '$actor reenvió un mensaje de esta conversación a $target.';
  }

  @override
  String messengerNoticeForwardedPrivate(String actor) {
    return '$actor reenvió un mensaje de esta conversación a una conversación personal.';
  }

  @override
  String messengerOnServer(String server) {
    return 'en $server';
  }

  @override
  String get messengerRead => 'Leído';

  @override
  String get messengerRefusedClosed => 'Esta consulta está cerrada.';

  @override
  String get messengerRefusedForwardingOff =>
      'Este espacio no permite reenviar sus mensajes.';

  @override
  String get messengerRefusedLimit => 'Demasiados a la vez. Espera un minuto.';

  @override
  String get messengerRefusedRequestPending =>
      'Tu primer mensaje espera una respuesta.';

  @override
  String get messengerRefusedTooLong =>
      'Este mensaje es demasiado largo para esa conversación.';

  @override
  String get messengerRefusedUnavailable =>
      'Este espacio no acepta consultas ahora mismo.';

  @override
  String get messengerStar => 'Destacar';

  @override
  String get messengerStarred => 'Destacados';

  @override
  String get messengerUnlock => 'Permitir el reenvío';

  @override
  String get messengerUnstar => 'Quitar destacado';

  @override
  String get messengerWriteToHosts => 'Escribir a los anfitriones';

  @override
  String get mfaCode => 'Código de seis dígitos';

  @override
  String get mfaEnroll =>
      'Escanee este código con una aplicación de autenticación, o introduzca la clave, y escriba los seis dígitos que muestra.';

  @override
  String get mfaTitle => 'Confirme con su aplicación de autenticación';

  @override
  String get mfaVerify => 'Verificar';

  @override
  String get mfaWrong => 'Ese código no fue aceptado. Pruebe el actual.';

  @override
  String get moneyAmountLabel => 'Importe';

  @override
  String get moneyBalance => 'Saldo';

  @override
  String get moneyBaseFee => 'Suscripción base';

  @override
  String get moneyCredits => 'Pagos y créditos';

  @override
  String get moneyDescriptionLabel => 'Descripción';

  @override
  String get moneyDocumentLibrary => 'Biblioteca de documentos';

  @override
  String moneyDueIn(int days) {
    return 'Vence en $days días';
  }

  @override
  String get moneyExpenseCategoryLabel => 'Categoría';

  @override
  String get moneyExpensePending => 'Gasto enviado — esperando aprobación.';

  @override
  String get moneyFaceDocuments => 'Documentos';

  @override
  String get moneyFaceInvoices => 'Facturas';

  @override
  String get moneyFacePayments => 'Pagos';

  @override
  String get moneyFaceStatement => 'Extracto';

  @override
  String get moneyFaceUsage => 'Uso';

  @override
  String get moneyLedgerEmpty => 'Aún no hay movimientos.';

  @override
  String get moneyLedgerHeader => 'Libro de cuentas';

  @override
  String get moneyMyAgreement => 'Mis condiciones';

  @override
  String get moneyNoInvoicesYet =>
      'Aún no hay factura — el espacio factura el mes una vez cerrado.';

  @override
  String get moneyNoteLabel => 'Nota (opcional)';

  @override
  String get moneyNothingOpen => 'Nada abierto — estás al día.';

  @override
  String moneyOpenInvoicesSummary(int count, String amount) {
    return '$count abiertas · $amount pendientes';
  }

  @override
  String get moneyOpenInvoicesTitle => 'Facturas abiertas';

  @override
  String moneyOverage(int count) {
    return 'Exceso ($count medias jornadas extra)';
  }

  @override
  String moneyOverdueBanner(int count, String amount) {
    return '$count vencidas — $amount por liquidar';
  }

  @override
  String moneyOverdueBy(int days) {
    return 'Vencida hace $days días';
  }

  @override
  String get moneyPayNow => 'Pagar ahora';

  @override
  String get moneyPaymentDateLabel => 'Fecha del pago';

  @override
  String get moneyPaymentPending => 'Pago enviado — esperando confirmación.';

  @override
  String get moneyPaymentPeriodLabel => 'Se aplica a';

  @override
  String get moneyRecordPayment => 'Registrar un pago';

  @override
  String moneyRemindedTimes(int count) {
    return 'Recordada ×$count';
  }

  @override
  String get moneySectionDocuments => 'Documentos';

  @override
  String get moneySectionPay => 'Pagar';

  @override
  String get moneySectionRequests => 'Solicitudes';

  @override
  String get moneyStatementOpen => 'Pendiente';

  @override
  String get moneyStatementPdf => 'Extracto del mes (PDF)';

  @override
  String get moneyStatementSettled => 'Al día';

  @override
  String get moneySubmitExpense => 'Enviar un gasto';

  @override
  String get moneySubmitPayment => 'Enviar para confirmación';

  @override
  String moneySubscriptionPct(int pct) {
    return 'Suscripción $pct %';
  }

  @override
  String moneyUsage(int used, int included) {
    return '$used de $included medias jornadas usadas';
  }

  @override
  String moneyUsageUnlimited(int used) {
    return '$used medias jornadas usadas';
  }

  @override
  String monthFreeCount(int free, int total) {
    return '$free/$total';
  }

  @override
  String get myBadgeTitle => 'Mi credencial';

  @override
  String get myInvoicesTitle => 'Mis facturas';

  @override
  String get myVisitsHelp =>
      'Visitas que pediste o a las que fuiste admitido como invitado. Una visita no es una membresía.';

  @override
  String get myVisitsTitle => 'Mis visitas';

  @override
  String get navigationClassic =>
      'Clásica: la barra inferior y el botón redondo';

  @override
  String get navigationDefault => 'Por defecto para este dispositivo';

  @override
  String get navigationMenu => 'Menú: la hamburguesa, como en la web';

  @override
  String get navigationTitle => 'Navegación';

  @override
  String negotiationActiveSince(String month) {
    return 'Tus condiciones se aplican desde $month.';
  }

  @override
  String get negotiationCardTitle => 'Mis precios negociados';

  @override
  String get negotiationDefaultColumn => 'Tarifa';

  @override
  String get negotiationDiscount => 'Descuento en suplementos';

  @override
  String get negotiationFee => 'Cuota mensual';

  @override
  String get negotiationItems => 'Servicios y paquetes';

  @override
  String get negotiationItemsHint =>
      'Un precio unitario para este miembro; vacío mantiene el catálogo.';

  @override
  String get negotiationKeepCurrent => 'Mantener la actual';

  @override
  String get negotiationMineColumn => 'Las mías';

  @override
  String get negotiationNote => 'Nota';

  @override
  String get negotiationOccupation => 'Ocupación';

  @override
  String get negotiationOccupationHint =>
      'La parte de días abiertos incluida cada mes; se aplica al miembro una vez validada.';

  @override
  String get negotiationOnTariff => 'Estás en la tarifa del espacio.';

  @override
  String get negotiationOverage => 'Exceso por medio día';

  @override
  String get negotiationPending => 'Unas condiciones esperan validación.';

  @override
  String get negotiationPendingBadge => 'pendiente de validación';

  @override
  String negotiationPercent(int value) {
    return '$value %';
  }

  @override
  String get negotiationProposeHint =>
      'Deja un campo vacío para mantener la tarifa. Las condiciones pasan por validación antes de aplicarse.';

  @override
  String get negotiationProposeTitle => 'Negociación de precios';

  @override
  String get negotiationProposed =>
      'Condiciones propuestas — pendientes de validación.';

  @override
  String get negotiationReadOnly => 'Solo lectura';

  @override
  String get negotiationSubmit => 'Proponer para validación';

  @override
  String get negotiationValidFrom => 'Se aplica desde';

  @override
  String get negotiationWhoCanSee => 'Quién puede verlo';

  @override
  String get newConversationGroupSwitch => 'Grupo';

  @override
  String get newConversationNoMembers => 'Aún no hay nadie más.';

  @override
  String get newConversationSearch => 'Buscar miembros';

  @override
  String get newConversationStart => 'Iniciar chat';

  @override
  String get newConversationTapToOpen =>
      'Toca a una persona para abrir el chat; activa Grupo para elegir varias.';

  @override
  String get newConversationTitle => 'Nueva conversación';

  @override
  String get newGroupCreate => 'Crear grupo';

  @override
  String get newGroupName => 'Nombre del grupo';

  @override
  String get newGroupNameTaken =>
      'Ya existe un grupo con ese nombre aquí. Elija otro.';

  @override
  String get newMemberDefaultsConfigured =>
      'Con qué empieza alguien que se une.';

  @override
  String get newMemberDefaultsTitle => 'Nuevos miembros';

  @override
  String get newMemberDefaultsUnavailable =>
      'No se han podido leer ahora mismo. Al guardar se quedan como están.';

  @override
  String get newMemberDefaultsUnset =>
      'Nada elegido: los nuevos miembros empiezan al 100 % y las reservas se bloquean cuando se agota el derecho.';

  @override
  String get newMemberOverageBlocked => 'Bloqueado al agotarse';

  @override
  String get newMemberOveragePackage => 'Debe comprar un paquete';

  @override
  String get newMemberOveragePayg => 'Pago por uso';

  @override
  String get newMemberSubscription => 'Suscripción';

  @override
  String get newMemberSubscriptionLess => 'Suscripción más pequeña';

  @override
  String get newMemberSubscriptionMore => 'Suscripción más grande';

  @override
  String newMemberSubscriptionValue(int percent) {
    return '$percent %';
  }

  @override
  String get nfcConfigChecking => 'Comprobando…';

  @override
  String get nfcConfigDeviceOff =>
      'El NFC está desactivado en los ajustes de Android de este dispositivo — actívalo para leer tarjetas RFID.';

  @override
  String get nfcConfigDeviceReady => 'NFC disponible y activado';

  @override
  String get nfcConfigDeviceStatus => 'Este dispositivo';

  @override
  String get nfcConfigDeviceUnavailable =>
      'Sin NFC aquí — se necesita un dispositivo Android con NFC activado (los iPad no tienen NFC). Las credenciales QR siguen funcionando.';

  @override
  String get nfcConfigEnable => 'Activar registro por credencial NFC';

  @override
  String get nfcConfigEnableDesc =>
      'Muestra la opción de acercar la tarjeta en los quioscos y en el gestor de credenciales.';

  @override
  String get nfcConfigIntro =>
      'Los miembros se registran en un quiosco de pared acercando una tarjeta RFID/NFC. Registra la tarjeta de cada miembro en Miembros y planes; en el quiosco la acercan para reservar o registrarse.';

  @override
  String get nfcConfigTitle => 'Credenciales RFID / NFC';

  @override
  String get noteRefAlert => 'Aviso';

  @override
  String noteRefFilterCount(int shown, int total) {
    return '$shown de $total';
  }

  @override
  String get noteRefFilterEmpty => 'Sin resultados.';

  @override
  String get noteRefFilterLabel => 'Filtrar';

  @override
  String get noteRefGone => 'Esta reserva ya no existe.';

  @override
  String get noteRefInvoice => 'Factura';

  @override
  String get noteRefNoReservations => 'No hay reservas próximas que vincular.';

  @override
  String get noteRefNone => 'Nada que referenciar todavía.';

  @override
  String get noteRefPayment => 'Pago';

  @override
  String get noteRefPickAlert => '¿Qué aviso?';

  @override
  String get noteRefPickInvoice => '¿Qué factura?';

  @override
  String get noteRefPickPayment => '¿Qué pago?';

  @override
  String get noteRefPickValidation => '¿Qué validación?';

  @override
  String get noteRefRefund => 'Reembolso';

  @override
  String get noteRefReservation => 'Vincular una reserva';

  @override
  String get noteRefSpace => 'Vincular un espacio';

  @override
  String get noteRefValidation => 'Validación';

  @override
  String get noteRefWholeLevel => 'planta entera';

  @override
  String get notesFilterEmpty => 'No hay mensajes sin leer — todo al día.';

  @override
  String get notesFilterRead => 'Leídos';

  @override
  String get notesFilterUnread => 'No leídos';

  @override
  String get notifCategoryCheckIns => 'Registros';

  @override
  String get notifCategoryMembers => 'Miembros';

  @override
  String get notifCategoryMoney => 'Dinero';

  @override
  String get notifGroupBy => 'Agrupar por';

  @override
  String get notifGroupByDate => 'Fecha';

  @override
  String get notifGroupByType => 'Tipo';

  @override
  String get notifGroupByUser => 'Miembro';

  @override
  String get notifSortByDate => 'Ordenar por fecha';

  @override
  String get notifUngroup => 'Desagrupar';

  @override
  String get notificationsSystemOff =>
      'Android está bloqueando las notificaciones de DesKilo';

  @override
  String get notificationsSystemOffHint =>
      'Permítelas en Ajustes del sistema → Aplicaciones → DesKilo → Notificaciones — la insignia del icono las necesita.';

  @override
  String get numberSequenceDateNone => 'Ninguna';

  @override
  String get numberSequenceDatePart => 'Fecha';

  @override
  String get numberSequenceDateRemovalBlocked =>
      'Ya se emitieron números con la fecha. Quitarla podría repetir uno: cambia también el prefijo o el sufijo.';

  @override
  String get numberSequenceDateYear => 'Año';

  @override
  String get numberSequenceDateYearMonth => 'Año-mes';

  @override
  String get numberSequenceDigits => 'Dígitos';

  @override
  String get numberSequenceGapless => 'Sin huecos — garantizado';

  @override
  String get numberSequenceJournalCreditNote => 'Abonos';

  @override
  String get numberSequenceJournalInvoice => 'Facturas';

  @override
  String get numberSequenceJournalMember => 'Socios';

  @override
  String get numberSequenceJournalPayment => 'Pagos';

  @override
  String get numberSequenceJournalVatDeclaration => 'Declaraciones de IVA';

  @override
  String get numberSequenceNext => 'Próximo número';

  @override
  String get numberSequencePrefix => 'Prefijo';

  @override
  String get numberSequenceReset => 'Reinicio';

  @override
  String get numberSequenceResetLimited =>
      'Un número se reinicia como mucho tan a menudo como muestra su fecha; si no, volvería a emitir un número anterior.';

  @override
  String get numberSequenceResetMonthly => 'Cada mes';

  @override
  String get numberSequenceResetNever => 'Nunca';

  @override
  String get numberSequenceResetWasInvalid =>
      'Esta serie se reiniciaba más a menudo de lo que muestra su fecha. Guarda para mantener un reinicio que no repita ningún número.';

  @override
  String get numberSequenceResetYearly => 'Cada año';

  @override
  String get numberSequenceSaved => 'Serie guardada.';

  @override
  String get numberSequenceSuffix => 'Sufijo';

  @override
  String get numberSequencesIntro =>
      'Una serie por diario, sin huecos: el número se toma en la base de datos al emitir el documento, y un documento que falla no consume nada. Cambiar el formato nunca toca un documento ya emitido.';

  @override
  String get numberSequencesSubtitle => 'Cómo se numeran facturas y abonos.';

  @override
  String get numberSequencesTitle => 'Series de numeración';

  @override
  String get occurrenceAdded => 'Añadido a tus gastos.';

  @override
  String get occurrenceConfirm => 'Confirmar este gasto';

  @override
  String get occurrenceReasonLabel => 'Por qué difiere (obligatorio)';

  @override
  String get occurrenceReasonMissing =>
      'Un importe distinto necesita una explicación.';

  @override
  String get occurrenceRejected =>
      'Los validadores la rechazaron — ajusta el importe o la descripción y reenvía.';

  @override
  String get occurrenceResend => 'Reenviar a validación';

  @override
  String occurrenceScheduledAmount(Object amount) {
    return 'Validado: $amount';
  }

  @override
  String get occurrenceSentForValidation =>
      'Enviado a los validadores — contará cuando confirmen.';

  @override
  String get officeSupplementLabel => 'Reservas de oficina';

  @override
  String get onboardingConfirmIntro => 'Esto es lo que se creará:';

  @override
  String get onboardingCreateButton => 'Crear espacio';

  @override
  String get onboardingCreateTab => 'Crear un espacio';

  @override
  String get onboardingCreateWithoutTemplate => 'Crear sin plantilla';

  @override
  String get onboardingCurrencyUnknown =>
      'Introduzca un código de moneda admitido, por ejemplo EUR';

  @override
  String get onboardingDiscardDraft =>
      'Se perderán los datos introducidos. Esto no cancela una solicitud ya enviada.';

  @override
  String get onboardingIntentChanged =>
      'Puede que su solicitud anterior ya se haya creado. Reinténtela tal como se envió antes de cambiar nada.';

  @override
  String get onboardingIntentResumed =>
      'Puede que una creación anterior se haya completado. Reintente para comprobar la misma solicitud.';

  @override
  String get onboardingJoinButton => 'Unirse';

  @override
  String get onboardingJoinTab => 'Unirse a un espacio';

  @override
  String get onboardingRetryAsSent => 'Reintentar tal cual';

  @override
  String get onboardingScanButton => 'Escanear código QR';

  @override
  String get onboardingShapeLabel => 'Qué crear';

  @override
  String get onboardingShapePair => 'Un par vinculado de prueba y real';

  @override
  String get onboardingShapeReal => 'Un espacio real';

  @override
  String get onboardingShapeRealHint =>
      'Para la operación real: las facturas que emite se deben.';

  @override
  String get onboardingShapeTest => 'Un espacio de prueba';

  @override
  String get onboardingShapeTestHint =>
      'Seguro para probar: cada pantalla y cada documento indica que es una prueba. Sin facturación real.';

  @override
  String get onboardingStartEmpty => 'Espacio vacío';

  @override
  String get onboardingStartEmptyDesc =>
      'Dibuje su propio plano desde un lienzo en blanco.';

  @override
  String get onboardingStartFrom => 'Partir de';

  @override
  String get onboardingStepConfirm => 'Confirmar';

  @override
  String get onboardingStepName => 'Nombre';

  @override
  String get onboardingStepWhere => 'Dónde';

  @override
  String get onboardingSummaryBillingOff =>
      'Sin facturación real: los documentos se marcan como prueba.';

  @override
  String get onboardingSummaryBillingOn =>
      'La facturación real es posible: sus facturas se deben.';

  @override
  String onboardingSummaryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Crea $count espacios',
      one: 'Crea un espacio',
    );
    return '$_temp0';
  }

  @override
  String onboardingSummaryServer(String host) {
    return 'En el servidor $host';
  }

  @override
  String onboardingTemplateSetsUp(String groups) {
    return 'Configura: $groups';
  }

  @override
  String get onboardingTemplatesFailedEmpty =>
      'No se pudieron cargar las plantillas, así que este espacio empezaría vacío. Vuelva atrás para intentarlo de nuevo.';

  @override
  String get onboardingTitle => 'Bienvenido a DesKilo';

  @override
  String get onboardingUnconfirmed =>
      'No se pudo confirmar el resultado. Sus datos se conservan. Vuelva a intentarlo para comprobar la misma solicitud.';

  @override
  String get onboardingUseSuggested => 'Usar los ajustes propuestos';

  @override
  String get onboardingWithTwin => 'Crear la pareja desarrollo y producción';

  @override
  String get onboardingWithTwinHint =>
      'Dos espacios con el mismo nombre: uno para probar, otro que es real. Ambos son suyos.';

  @override
  String get overagePolicyBlocked => 'Bloquear más reservas';

  @override
  String get overagePolicyPackage => 'Exigir comprar un paquete';

  @override
  String get overagePolicyPayg => 'Cobrar el exceso (pago por uso)';

  @override
  String get payConfigConfigured => 'Configurado';

  @override
  String get payConfigIntro =>
      'Introduce cada proveedor de pago que quieras ofrecer. Las claves se guardan de forma segura en el servidor y no se vuelven a mostrar.';

  @override
  String get payConfigNotConfigured => 'Sin configurar';

  @override
  String get payConfigOpen => 'Configurar';

  @override
  String get payConfigRemove => 'Eliminar';

  @override
  String get payConfigRemoved => 'Eliminado.';

  @override
  String get payConfigSaved => 'Guardado.';

  @override
  String get payConfigSecretSet => 'Definido — deja en blanco para conservar';

  @override
  String get payConfigTitle => 'Pagos en línea';

  @override
  String get payFieldApiKey => 'Clave API';

  @override
  String get payFieldClientId => 'Client ID';

  @override
  String get payFieldEnv => 'Entorno';

  @override
  String get payFieldReturnUrl => 'URL de retorno';

  @override
  String get payFieldSecret => 'Secreto';

  @override
  String get payFieldSecretKey => 'Clave secreta';

  @override
  String get payFieldWebhookId => 'ID de webhook';

  @override
  String get payFieldWebhookSecret => 'Secreto de firma del webhook';

  @override
  String get payOnlineButton => 'Pagar en línea';

  @override
  String get payOnlineChooseTitle => 'Pagar en línea';

  @override
  String get payOnlineDiagHint => 'Al servidor le falta esta configuración:';

  @override
  String get payOnlineDiagTitle => 'Pagos en línea — sin configurar';

  @override
  String payOnlineFailedDetail(
    String reference,
    String amount,
    String provider,
  ) {
    return 'El pago $reference ($amount vía $provider) no se completó — no se abonó nada; el saldo sigue pendiente.';
  }

  @override
  String get payOnlineFailedTitle => 'Pago en línea fallido';

  @override
  String get payOnlineNotConfigured =>
      'Los pagos en línea aún no están configurados. Pregunta al propietario del espacio.';

  @override
  String payOnlinePendingDetail(
    String reference,
    String amount,
    String provider,
  ) {
    return 'El pago $reference ($amount vía $provider) aún no ha sido confirmado por el proveedor, por lo que el saldo sigue mostrando lo adeudado. Cite esta referencia si no se liquida.';
  }

  @override
  String get payOnlinePendingTitle => 'Pago en línea pendiente';

  @override
  String get paymentAccountNumberLabel => 'Número de cuenta';

  @override
  String get paymentBankCodeLabel => 'Código bancario';

  @override
  String get paymentBankNameLabel => 'Nombre del banco';

  @override
  String get paymentBicLabel => 'BIC / SWIFT';

  @override
  String get paymentCopied => 'Copiado.';

  @override
  String get paymentInstructionsHelper =>
      'Se muestran a los miembros en un extracto pendiente. Déjalo vacío para no mostrar nada.';

  @override
  String get paymentInstructionsIbanCopied => 'IBAN copiado.';

  @override
  String get paymentInstructionsIbanTitle => 'IBAN';

  @override
  String get paymentInstructionsLydiaLabel =>
      'Número de teléfono o usuario de Lydia';

  @override
  String get paymentInstructionsPaypalLabel => 'Enlace o usuario de PayPal.me';

  @override
  String get paymentInstructionsReferenceLabel =>
      'Indicación de referencia del pago';

  @override
  String get paymentInstructionsTitle => 'Instrucciones de pago';

  @override
  String get paymentInstructionsValueCopied => 'Copiado al portapapeles.';

  @override
  String get paymentInstructionsWeroLabel => 'Número de teléfono de Wero';

  @override
  String get paymentInstructionsWiseLabel => 'Wisetag o enlace de pago de Wise';

  @override
  String get paymentMethodBankTransfer => 'Transferencia';

  @override
  String get paymentMethodCard => 'Tarjeta';

  @override
  String get paymentMethodCash => 'Efectivo';

  @override
  String get paymentMethodLydia => 'Lydia';

  @override
  String get paymentMethodOther => 'Otro';

  @override
  String get paymentMethodPaypal => 'PayPal';

  @override
  String get paymentMethodTwint => 'TWINT';

  @override
  String get paymentMethodWero => 'Wero';

  @override
  String get paymentMethodWise => 'Wise';

  @override
  String get paymentMethodsSubtitle =>
      'IBAN, PayPal, Wero, Lydia, Wise y la referencia de pago';

  @override
  String get paymentProviderMollie => 'Mollie — iDEAL, Bancontact…';

  @override
  String get paymentProviderStripe => 'Tarjeta (Stripe)';

  @override
  String get paymentProviderWero => 'Wero (con Mollie)';

  @override
  String get paymentRoutingNumberLabel => 'Routing number';

  @override
  String get paymentSortCodeLabel => 'Sort code';

  @override
  String get paymentTermsEdit => 'Solicitar un cambio';

  @override
  String get paymentTermsFieldEscompte => 'Descuento por pronto pago';

  @override
  String get paymentTermsFieldLatePenalty => 'Penalización por demora';

  @override
  String get paymentTermsFieldRecovery => 'Indemnización de cobro';

  @override
  String get paymentTermsFieldTerms => 'Condiciones de pago';

  @override
  String get paymentTermsInherit => 'las del espacio por defecto';

  @override
  String get paymentTermsInherited => 'Por defecto del espacio';

  @override
  String get paymentTermsMemberNote =>
      'Estas condiciones las fija el espacio; un cambio pasa por su validación.';

  @override
  String get paymentTermsNone => 'Sin condiciones redactadas';

  @override
  String get paymentTermsOverridden => 'Propias del miembro';

  @override
  String get paymentTermsReason => 'Motivo (opcional)';

  @override
  String get paymentTermsRequestHint =>
      'Deje un campo vacío para conservar la redacción del espacio. El cambio se aplica una vez validado.';

  @override
  String get paymentTermsRequestTitle =>
      'Solicitar un cambio de condiciones de pago';

  @override
  String get paymentTermsRequested =>
      'Cambio solicitado — pendiente de validación';

  @override
  String get paymentTermsSubmit => 'Enviar solicitud';

  @override
  String get paymentTermsTitle => 'Condiciones de pago';

  @override
  String get paymentTermsUseDefault =>
      'Volver a las condiciones por defecto del espacio';

  @override
  String get paymentTransitNumberLabel => 'Tránsito · institución';

  @override
  String get paymentsPendingTag => 'pendiente de validación';

  @override
  String pendingApprovalBody(String workspace) {
    return 'Te has unido a $workspace. Un administrador debe aprobar tu membresía antes de que puedas usar el espacio — tendrás acceso en cuanto confirme.';
  }

  @override
  String get pendingApprovalRefresh => 'Comprobar de nuevo';

  @override
  String get pendingApprovalTitle =>
      'Membresía del espacio pendiente de aprobación';

  @override
  String get pendingAvailable =>
      'Mientras esperas, tus otros espacios, tu cuenta y la ayuda siguen disponibles.';

  @override
  String get pendingHelp => 'Ayuda';

  @override
  String pendingLastChecked(String time) {
    return 'Última comprobación $time';
  }

  @override
  String get pendingNotUpdated =>
      'Estado no actualizado — no se pudo contactar con el servidor. Tu solicitud no ha cambiado.';

  @override
  String get pendingStillWaiting => 'Sigue pendiente de aprobación.';

  @override
  String get pendingSwitchWorkspace => 'Cambiar de espacio';

  @override
  String percentValue(int value) {
    return '$value %';
  }

  @override
  String get permAccessProd => 'Entrar en el espacio de producción';

  @override
  String get permApproveExpenses => 'Aprobar gastos';

  @override
  String get permDeployToDev => 'Desplegar en desarrollo';

  @override
  String get permDeployToProd => 'Desplegar en producción';

  @override
  String get permDesignDocuments => 'Diseñar los documentos';

  @override
  String get permExportData => 'Exportar contabilidad y datos';

  @override
  String get permIssueInvoices => 'Emitir facturas y conciliar pagos';

  @override
  String get permMakeReservations => 'Reservar y usar las reservas';

  @override
  String get permManageBilling => 'Gestionar tarifas y reglas de facturación';

  @override
  String get permManageConfiguration => 'Gestionar la configuración';

  @override
  String get permManageDocuments => 'Gestionar la biblioteca de documentos';

  @override
  String get permManageIntegrations => 'Gestionar integraciones';

  @override
  String get permManageMembers => 'Gestionar miembros';

  @override
  String get permManageNegotiations => 'Gestionar los acuerdos comerciales';

  @override
  String get permManageReservations => 'Gestionar reservas de otros';

  @override
  String get permManageRoles => 'Gestionar roles y permisos';

  @override
  String get permManageServices => 'Gestionar servicios y paquetes';

  @override
  String get permManageSites => 'Gestionar sedes y editar el plano';

  @override
  String get permManageValidation => 'Configurar reglas de validación';

  @override
  String get permOperateKiosk => 'Operar el quiosco y las tarjetas';

  @override
  String get permPaymentTermsEdit => 'Solicitar cambios de condiciones de pago';

  @override
  String get permUseMessages => 'Usar la mensajería';

  @override
  String get permViewAnalytics => 'Consultar las cifras del espacio';

  @override
  String get permViewCalendar => 'Ver el calendario';

  @override
  String get permViewDirectory => 'Ver el directorio de miembros';

  @override
  String get permViewDocuments => 'Ver los documentos compartidos';

  @override
  String get permViewFinances => 'Ver las finanzas del espacio';

  @override
  String get permViewMyMoney => 'Ver su propia cuenta y sus facturas';

  @override
  String get permViewNegotiations => 'Consultar los acuerdos comerciales';

  @override
  String get permViewPersonalData =>
      'Consultar los datos personales de los miembros';

  @override
  String get permWorkspaceSettings => 'Editar la configuración del espacio';

  @override
  String get personalInfoCity => 'Ciudad';

  @override
  String get personalInfoCompany => 'Empresa (opcional)';

  @override
  String get personalInfoCountry => 'País';

  @override
  String get personalInfoEmail => 'E-mail para documentos';

  @override
  String get personalInfoFirstName => 'Nombre';

  @override
  String get personalInfoLastName => 'Apellidos';

  @override
  String get personalInfoLegalId => 'Identificador de empresa (opcional)';

  @override
  String get personalInfoNone => 'Aún sin rellenar';

  @override
  String get personalInfoPhone => 'Teléfono';

  @override
  String get personalInfoPostalCode => 'Código postal';

  @override
  String get personalInfoPreview => 'En sus documentos';

  @override
  String get personalInfoSave => 'Guardar';

  @override
  String get personalInfoSaved => 'Datos personales guardados';

  @override
  String get personalInfoStreet => 'Calle y número';

  @override
  String get personalInfoSubtitle =>
      'Se imprimen en sus facturas y cartas. El apellido se escribe en mayúsculas, como en el correo oficial.';

  @override
  String get personalInfoTitle => 'Datos personales';

  @override
  String get personalInfoVatId => 'NIF-IVA (opcional)';

  @override
  String placeFeedbackAverage(String average, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valoraciones',
      one: '1 valoración',
    );
    return '$average · $_temp0';
  }

  @override
  String get placeFeedbackFailed => 'No se pudo guardar. Inténtelo de nuevo.';

  @override
  String get placeFeedbackFavorite => 'Añadir a favoritos';

  @override
  String get placeFeedbackNoRating => 'Aún sin valoración';

  @override
  String placeFeedbackStars(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n estrellas',
      one: '1 estrella',
    );
    return '$_temp0';
  }

  @override
  String get placeFeedbackUnfavorite => 'Quitar de favoritos';

  @override
  String get placeFeedbackZero => '0 estrellas';

  @override
  String get planAccessorySupplementHint =>
      'Los suplementos se aplican por media jornada.';

  @override
  String get planActiveLabel => 'Activo';

  @override
  String get planAfternoonChip => 'Tarde';

  @override
  String get planAvailabilityLoading => 'Comprobando los días de apertura…';

  @override
  String get planBaseFeeLabel => 'Cuota mensual base';

  @override
  String get planBookForLabel => 'Reservar para';

  @override
  String planBookedForPending(String name) {
    return 'Enviado a $name para confirmación.';
  }

  @override
  String get planCancelReservationButton => 'Cancelar reserva';

  @override
  String planCappedByNext(String time) {
    return 'El asiento está reservado a partir de las $time.';
  }

  @override
  String get planCheckInButton => 'Registrarse';

  @override
  String get planCheckInFailed =>
      'No se pudo registrar — puede que el asiento se acabe de ocupar.';

  @override
  String planCheckInFor(String name) {
    return 'Registrar a $name';
  }

  @override
  String get planCheckInNotYetError =>
      'El registro se abre 15 minutos antes del inicio.';

  @override
  String planCheckInOpensAt(String time) {
    return 'El registro se abre a las $time';
  }

  @override
  String planCheckInOpensOn(String date) {
    return 'El check-in abre el $date';
  }

  @override
  String get planCheckInOverError =>
      'Esta reserva ha terminado — ya no es posible registrarse.';

  @override
  String get planCheckInTitle => 'Registrarse';

  @override
  String get planCheckOutButton => 'Salir';

  @override
  String planCheckOutFor(String name) {
    return 'Dar salida a $name';
  }

  @override
  String get planClosedDay => 'Cerrado este día';

  @override
  String get planClosedDayError => 'El espacio está cerrado ese día.';

  @override
  String planClosedDayShowNext(String day) {
    return 'Mostrar el $day';
  }

  @override
  String get planDurationLabel => 'Duración';

  @override
  String get planEndBeforeStart => 'El fin debe ser posterior al inicio.';

  @override
  String get planFromLabel => 'Desde';

  @override
  String get planFullDayChip => 'Día';

  @override
  String get planFullDayError => 'Aquí las reservas cubren el día completo.';

  @override
  String get planHalfDayError => 'Aquí las reservas son por media jornada.';

  @override
  String get planIncludedHelper => 'Dejar vacío para ilimitado';

  @override
  String get planIncludedLabel => 'Medias jornadas incluidas';

  @override
  String get planLevelLabel => 'Planta';

  @override
  String get planLevelTooltip => 'Planta';

  @override
  String get planListViewTooltip => 'Vista de lista';

  @override
  String get planMakeNotReservable => 'Hacer no reservable';

  @override
  String get planMakeReservable => 'Hacer reservable';

  @override
  String get planMapViewTooltip => 'Vista de plano';

  @override
  String get planMorningChip => 'Mañana';

  @override
  String get planNameLabel => 'Nombre';

  @override
  String get planNoLevels => 'El espacio aún no tiene plano.';

  @override
  String get planNoSeats => 'Esta planta aún no tiene asientos.';

  @override
  String get planNowButton => 'Ahora';

  @override
  String planOccupiedBy(String name) {
    return 'Ocupado por $name';
  }

  @override
  String get planOverageLabel => 'Precio por media jornada extra';

  @override
  String planOverruleDone(String name) {
    return 'Reserva eliminada — se notificó a $name.';
  }

  @override
  String planOverruleHint(String name) {
    return '$name y todos los admins serán notificados.';
  }

  @override
  String get planOverruleRemove => 'Quitar la reserva (anular)';

  @override
  String get planRepeatLabel => 'Repetir';

  @override
  String get planReservationsEmpty => 'No hay reservas para este día.';

  @override
  String get planReserveButton => 'Reservar';

  @override
  String planReservedBy(String name) {
    return 'Reservado por $name';
  }

  @override
  String get planSeatBlocked =>
      'Este asiento está bloqueado por mantenimiento.';

  @override
  String get planSendForConfirmation => 'Enviar para confirmación';

  @override
  String planSlotError(int minutes) {
    return 'Las reservas deben empezar y terminar en la cuadrícula de $minutes minutos.';
  }

  @override
  String get planStartNow => 'Empieza ahora';

  @override
  String planStartsAt(String time) {
    return 'Empieza a las $time';
  }

  @override
  String get planStateFree => 'Libre';

  @override
  String get planStateYours => 'Tuyo';

  @override
  String get planToLabel => 'Hasta';

  @override
  String planUntil(String time) {
    return 'hasta las $time';
  }

  @override
  String get planUntilDateLabel => 'Repetir hasta';

  @override
  String get planUntilLabel => 'Hasta';

  @override
  String get planYourSeat => 'Tu asiento';

  @override
  String get plansEditorEdit => 'Editar plan';

  @override
  String get plansEditorInactive => 'Inactivo';

  @override
  String get plansEditorNew => 'Nuevo plan';

  @override
  String plansEditorPerExtra(String price) {
    return '$price/media jornada extra';
  }

  @override
  String plansEditorQuota(int count) {
    return '$count medias jornadas';
  }

  @override
  String get plansEditorTitle => 'Planes';

  @override
  String get plansEditorUnlimited => 'medias jornadas ilimitadas';

  @override
  String get policyAdminCheckoutDesc =>
      'Un administrador puede finalizar el check-in en curso de un miembro.';

  @override
  String get policyAdminCheckoutTitle =>
      'Los administradores pueden hacer el check-out de los miembros';

  @override
  String get policyAllowPastDesc =>
      'Los miembros pueden registrar una reserva ya finalizada.';

  @override
  String get policyAllowPastTitle => 'Permitir reservas pasadas';

  @override
  String policyDaysValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '1 día',
    );
    return '$_temp0';
  }

  @override
  String get policyDurationConflict =>
      'El mínimo no puede superar al máximo — no se aceptaría ninguna reserva.';

  @override
  String get policyHorizonDesc =>
      'Cuántos días antes puede empezar una reserva. Más allá, se rechaza.';

  @override
  String get policyHorizonTitle => 'Horizonte de reserva';

  @override
  String policyHoursValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count horas',
      one: '1 hora',
    );
    return '$_temp0';
  }

  @override
  String get policyLimitsDesc =>
      'Con cuánta antelación se puede reservar y qué duración se acepta. Rigen en todas las granularidades.';

  @override
  String get policyLimitsTitle => 'Límites de reserva';

  @override
  String get policyMaxDurationDesc =>
      'La reserva más larga aceptada. Una reserva termina el día en que empieza, así que la jornada entera es el techo.';

  @override
  String get policyMaxDurationTitle => 'Duración máxima';

  @override
  String get policyMinDurationDesc =>
      'La reserva más corta aceptada. Por eso llegar a las 11:45 para el límite de las 12:00 se rechaza por ser demasiado corta.';

  @override
  String get policyMinDurationTitle => 'Duración mínima';

  @override
  String policyMinutesValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutos',
      one: '1 minuto',
    );
    return '$_temp0';
  }

  @override
  String get policyOutsideHoursCharged => 'De pago';

  @override
  String get policyOutsideHoursChargedDesc =>
      'Permitido y contado como uso normal, salvo los días en que el miembro ya tiene una reserva normal.';

  @override
  String get policyOutsideHoursDesc =>
      'Qué puede ocurrir fuera de la jornada laboral: una sola respuesta, para todas las granularidades. Una reserva que toca el horario laboral es una reserva normal.';

  @override
  String get policyOutsideHoursFree => 'Gratis';

  @override
  String get policyOutsideHoursFreeDesc =>
      'Permitido, nunca contado ni cobrado: pura información de presencia.';

  @override
  String get policyOutsideHoursOff => 'Prohibido';

  @override
  String get policyOutsideHoursOffDesc =>
      'Nada fuera del horario: ni reservas por adelantado, ni check-ins espontáneos, y una reserva que se pasa del fin de la jornada también se rechaza.';

  @override
  String get policyOutsideHoursTitle => 'Fuera del horario de apertura';

  @override
  String get policyOutsideHoursWalkUp => 'Solo espontáneo';

  @override
  String get policyOutsideHoursWalkUpDesc =>
      'Los check-ins espontáneos siguen siendo posibles, incluidas las horas extra vespertinas; reservar por adelantado fuera del horario se rechaza.';

  @override
  String get policySimultaneousDesc =>
      'Cuántas reservas superpuestas puede tener un miembro. 1 mantiene un solo sitio a la vez.';

  @override
  String get policySimultaneousTitle => 'Reservas simultáneas por miembro';

  @override
  String get portalActionFailed =>
      'No se pudo guardar el cambio. Inténtalo de nuevo.';

  @override
  String get portalActionNotNegotiated =>
      'Esta acción no está disponible entre esta aplicación y ese servidor. Actualizar la aplicación puede ayudar.';

  @override
  String get portalAddress => 'Dirección pública';

  @override
  String get portalAdmin => 'Administrador';

  @override
  String get portalAdminVisible => 'Mostrarme como administrador público';

  @override
  String get portalAssociation => 'Asociación';

  @override
  String get portalAvailable =>
      'Permitir que los usuarios encuentren mi cuenta y me escriban';

  @override
  String get portalChat => 'Conversar';

  @override
  String get portalCompany => 'Empresa';

  @override
  String get portalConnect => 'Conectar un servidor';

  @override
  String get portalConnectionFailed =>
      'No se pudo conectar. Comprueba el servidor y tus credenciales.';

  @override
  String get portalConnections => 'Servidores conectados';

  @override
  String get portalConnectionsHint =>
      'Cada servidor usa su propia sesión. Desconectarlo elimina el acceso guardado de esta cuenta en este dispositivo.';

  @override
  String get portalCopyEmail => 'Copiar el correo';

  @override
  String get portalCustomised => 'Personalizado';

  @override
  String get portalDescription => 'Descripción';

  @override
  String get portalDirectoryIncompatible =>
      'Algunos espacios requieren una versión más reciente de la aplicación y no se muestran.';

  @override
  String get portalDirectoryUnavailable =>
      'Algunos directorios no están disponibles. Los resultados están incompletos.';

  @override
  String get portalDisconnect => 'Desconectar';

  @override
  String get portalDiscover => 'Buscar un espacio de trabajo';

  @override
  String get portalEmail => 'Correo público';

  @override
  String get portalEmailCode => 'Código de acceso por correo';

  @override
  String get portalEmailCopied => 'Correo copiado';

  @override
  String get portalEmployed => 'Empleado de este espacio';

  @override
  String get portalEmploymentHint =>
      'El empleo no modifica los permisos ni las suscripciones. Los pagos de salarios no están habilitados.';

  @override
  String get portalEnterSpace => 'Entrar';

  @override
  String get portalFindPeople => 'Buscar personas disponibles';

  @override
  String get portalFollowsWorkspace => 'De la información del espacio';

  @override
  String get portalImage => 'URL de la imagen del espacio';

  @override
  String get portalLatitude => 'Latitud';

  @override
  String get portalList => 'Lista';

  @override
  String get portalLongitude => 'Longitud';

  @override
  String get portalMap => 'Mapa';

  @override
  String get portalMessenger => 'Mensajería de la cuenta';

  @override
  String get portalMoreDirectories => 'Más directorios';

  @override
  String get portalNoLongerPublished => 'Este espacio ya no está publicado.';

  @override
  String get portalNoWorkspaces => 'No se encontraron espacios publicados.';

  @override
  String get portalOpenMe => 'Yo: mi cuenta y mis espacios';

  @override
  String get portalOwner => 'Propietario';

  @override
  String get portalPerson => 'Anfitrión particular';

  @override
  String get portalPhone => 'Teléfono público';

  @override
  String get portalPlans => 'Planes y precios';

  @override
  String get portalPreview => 'Vista externa';

  @override
  String get portalPublicPlan => 'Plano público';

  @override
  String get portalPublication => 'Página pública del espacio';

  @override
  String get portalPublished => 'Visible en el directorio público';

  @override
  String get portalRegisterDirectory => 'Publicar un servidor en el directorio';

  @override
  String get portalRequestProfile => 'Solicitar un perfil en este espacio';

  @override
  String get portalRequestSent =>
      'Solicitud enviada. El espacio revisará tu perfil.';

  @override
  String get portalResetAll =>
      'Restablecer todos los datos públicos con la información del espacio';

  @override
  String get portalResetAllBody =>
      'Los valores públicos de cada campo que tiene información en el espacio se sustituyen por ella. Los campos sin equivalente en el espacio conservan lo que escribió.';

  @override
  String get portalResetAllConfirm => 'Restablecer';

  @override
  String get portalSavePreview => 'Guardar y ver la vista externa';

  @override
  String get portalSearch => 'Buscar espacios';

  @override
  String get portalSendCode => 'Enviar código de acceso';

  @override
  String get portalSourceUnavailable =>
      'Un servidor no está disponible. Esta vista está incompleta. Toca para reintentar.';

  @override
  String get portalThisServer => 'Este servidor';

  @override
  String get portalUseCode => 'Usar un código por correo';

  @override
  String get portalUseWorkspaceInfo => 'Usar la información del espacio';

  @override
  String get portalVisibilityLink => 'Quién puede encontrarme y escribirme';

  @override
  String get portalVisibilityLinkBody => 'Se elige en Yo, en Quién me ve.';

  @override
  String get portalWebsite => 'Sitio web';

  @override
  String get preferencesSaveFailed =>
      'No se han podido guardar tus preferencias. Inténtalo de nuevo.';

  @override
  String get preferencesScopeHint =>
      'Idioma, apariencia y formatos regionales. Desactivado: editar mis valores predeterminados.';

  @override
  String get preferencesUseDefaults => 'Usar mis valores predeterminados';

  @override
  String get preferencesWorkspaceOnly => 'Solo para este espacio';

  @override
  String get priceGrossHint =>
      'Precio bruto — lo que paga el miembro; el IVA está dentro.';

  @override
  String priceVatIncluded(String rate) {
    return 'IVA $rate incl.';
  }

  @override
  String get privacyErase => 'Abandonar este espacio y borrar mis datos';

  @override
  String get privacyEraseConfirmButton => 'Borrar';

  @override
  String privacyEraseConfirmHint(String phrase) {
    return 'No se puede deshacer. Escriba $phrase para confirmar.';
  }

  @override
  String get privacyEraseConfirmPhrase => 'BORRAR';

  @override
  String get privacyEraseHint =>
      'Cancela sus reservas, vacía sus mensajes, borra su perfil. Los registros contables se conservan durante la retención legal, por id, no por nombre (art. 17).';

  @override
  String get privacyEraseOwner =>
      'Un propietario transfiere primero el espacio (Miembros y planes → Copropiedad).';

  @override
  String get privacyErased => 'Sus datos han sido borrados.';

  @override
  String get privacyExport => 'Exportar mis datos';

  @override
  String get privacyExportHint =>
      'Todo aquello de lo que usted es el sujeto, en un archivo JSON (art. 20).';

  @override
  String get privacyExportShareText => 'Mi exportación de datos DesKilo';

  @override
  String get privacyIntro =>
      'Tus datos nunca se rastrean ni se venden, y solo los pueden leer los roles que nombran las reglas de abajo; dónde se alojan figura en el aviso de privacidad de esta instalación. Estos son tus derechos según el RGPD — cada uno es un botón.';

  @override
  String privacyNoticeController(String name, String contact) {
    return 'Responsable del tratamiento: $name — $contact';
  }

  @override
  String get privacyNoticeEssential => 'Necesario para la cuenta y el espacio';

  @override
  String get privacyNoticeNotRecorded => 'no registrado por el operador';

  @override
  String get privacyNoticeOptional =>
      'Opcional — puedes usar la aplicación sin ello';

  @override
  String privacyNoticeRegion(String region) {
    return 'Región: $region';
  }

  @override
  String privacyNoticeRights(String contact) {
    return 'Tus derechos: $contact';
  }

  @override
  String get privacyNoticeRightsRoute => 'Tus derechos y el contacto';

  @override
  String get privacyNoticeTitle => 'Quién trata tus datos';

  @override
  String privacyNoticeTransfer(String mechanism) {
    return 'Garantía de transferencia: $mechanism';
  }

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get privacyPushOnDevice => 'Notificaciones push en este dispositivo';

  @override
  String get privacyPushOnDeviceFailed =>
      'No se pudo guardar la elección. Inténtalo de nuevo.';

  @override
  String get privacyPushOnDeviceHint =>
      'Opcional. Activado, la dirección de este dispositivo y cada notificación pasan por el servicio push; desactivado, la aplicación sigue funcionando y no se envía nada a este dispositivo.';

  @override
  String get privacySpaceNotice => 'El aviso de privacidad de este espacio';

  @override
  String get privacySpaceNoticeAcknowledge => 'He leído este aviso';

  @override
  String get privacySpaceNoticeFailed =>
      'No se pudo registrar la toma de conocimiento. Inténtalo de nuevo.';

  @override
  String get privacySpaceNoticeRead =>
      'Has tomado conocimiento de esta versión.';

  @override
  String get privacySpaceNoticeUnread => 'Aún no leído — léelo aquí.';

  @override
  String get privacyTitle => 'Privacidad y datos';

  @override
  String get privacyWhoCanSee => 'Quién puede ver mis datos';

  @override
  String get privacyWhoCanSeeHint =>
      'La regla por categoría, las personas que nombra hoy y quién miró realmente.';

  @override
  String processAlsoNeeds(String features) {
    return 'Activarlo todo también necesita: $features';
  }

  @override
  String processApplied(int count) {
    return '$count funcionalidades cambiadas.';
  }

  @override
  String get processBillingPayments => 'Facturación y pagos';

  @override
  String get processBillingPaymentsDesc =>
      'Facturar la actividad y conciliar los importes pendientes.';

  @override
  String processBlockedIntro(String feature, String features) {
    return '$feature sigue siendo necesaria para: $features';
  }

  @override
  String get processChangeFailed =>
      'No se pudieron cambiar las funcionalidades. No se escribió nada; inténtelo de nuevo.';

  @override
  String processConfirmOff(int count) {
    return 'Desactivar $count funcionalidades';
  }

  @override
  String processConfirmOn(int count) {
    return 'Activar $count funcionalidades';
  }

  @override
  String get processConflict =>
      'Alguien cambió las funcionalidades mientras tanto. Esta es la vista previa actualizada: revísela de nuevo.';

  @override
  String get processCoordination => 'Calendario y coordinación';

  @override
  String get processCoordinationDesc =>
      'Coordinar actividades, mensajes y decisiones.';

  @override
  String get processDocumentsInformation => 'Documentos e información';

  @override
  String get processDocumentsInformationDesc =>
      'Crear, compartir y exportar información del espacio.';

  @override
  String processFeatureCount(int enabled, int total) {
    return '$enabled de $total funciones activadas';
  }

  @override
  String get processFeatureOff => 'Desactivada';

  @override
  String get processFeatureOn => 'Activada';

  @override
  String processFeatureWaiting(String feature) {
    return 'Activada, esperando $feature';
  }

  @override
  String get processFilterAll => 'Todos';

  @override
  String get processFilterEmpty => 'Ningún proceso coincide con este filtro.';

  @override
  String processHeldBack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count funciones están activadas pero esperan un requisito desactivado',
      one: '1 función está activada pero espera un requisito desactivado',
    );
    return '$_temp0';
  }

  @override
  String processInProcess(String process) {
    return 'en $process';
  }

  @override
  String get processIntegrations => 'Integraciones y automatización';

  @override
  String get processIntegrationsDesc =>
      'Enviar notificaciones y documentos mediante servicios externos.';

  @override
  String get processKeepDependants =>
      'Desactivar igualmente, conservar sus ajustes';

  @override
  String get processMembershipCommerce => 'Ofertas para miembros';

  @override
  String get processMembershipCommerceDesc =>
      'Definir precios de servicios y acuerdos con los miembros.';

  @override
  String processNeededBy(String features) {
    return 'necesaria para $features';
  }

  @override
  String get processNothingToDo => 'Ya es así: nada que cambiar.';

  @override
  String get processOperations => 'Operaciones y administración';

  @override
  String get processOperationsDesc =>
      'Gestionar la configuración y el uso de la aplicación.';

  @override
  String processRemoveDependants(int count) {
    return 'Desactivar también las $count dependientes';
  }

  @override
  String get processReservationsUsage => 'Reservas y uso';

  @override
  String get processReservationsUsageDesc =>
      'Reservar plazas y registrar su uso.';

  @override
  String get processSearchLabel => 'Buscar procesos y funciones';

  @override
  String get processSectionAlreadyOn => 'Ya activas';

  @override
  String get processSectionAlsoNeeded => 'También necesarias';

  @override
  String get processSectionAlsoOff => 'También desactivadas';

  @override
  String get processSectionKeptWaiting =>
      'Dejan de funcionar; su ajuste se conserva';

  @override
  String get processSectionSwitchedOff => 'Desactivadas';

  @override
  String get processSectionSwitchedOn => 'Activadas';

  @override
  String get processSectionWorksAgain => 'Vuelven a funcionar';

  @override
  String processSheetTitleOff(String name) {
    return 'Desactivar $name';
  }

  @override
  String processSheetTitleOn(String name) {
    return 'Activar $name';
  }

  @override
  String get processSpaceManagement => 'Gestión de espacios';

  @override
  String get processSpaceManagementDesc =>
      'Organizar los espacios disponibles y sus horarios.';

  @override
  String get processStateActive => 'Activo';

  @override
  String get processStateAvailable => 'Disponible';

  @override
  String get processStateNeedsAttention => 'Requiere atención';

  @override
  String get processStatePartial => 'Parcial';

  @override
  String processSubprocessCount(int active, int total) {
    return '$active de $total subprocesos activos';
  }

  @override
  String get processSwitchHint =>
      'Toque una función para cambiarla entre los interruptores.';

  @override
  String get processSwitchOff => 'Desactivar';

  @override
  String get processSwitchOn => 'Activar';

  @override
  String get processUnconfirmed =>
      'El cambio se escribió, pero la app no pudo confirmarlo. Cierre y vuelva a abrir las funcionalidades para ver el estado actual.';

  @override
  String get processWorkspaceAccess => 'Espacio y acceso';

  @override
  String get processWorkspaceAccessDesc =>
      'Gestionar membresías, roles y acceso al espacio.';

  @override
  String get profilePhotoChoose => 'Elegir una foto';

  @override
  String get profilePhotoFileType => 'Imagen';

  @override
  String get profilePhotoNone => 'Toca para añadir una foto';

  @override
  String get profilePhotoRemove => 'Quitar foto';

  @override
  String get profilePhotoRemoved => 'Foto eliminada';

  @override
  String get profilePhotoSaveFailed => 'No se pudo actualizar la foto';

  @override
  String get profilePhotoSaved => 'Foto actualizada';

  @override
  String get profilePhotoSet => 'Toca para cambiar';

  @override
  String get profilePhotoTitle => 'Foto';

  @override
  String get profileStatusFieldLabel => 'Estado';

  @override
  String get profileStatusHelper =>
      'Opcional. Visible para los miembros de tus espacios en el directorio de miembros. Déjalo vacío para borrarlo.';

  @override
  String get profileStatusHint => 'En una llamada · vuelvo a las 14:00';

  @override
  String get profileStatusNone => 'Sin estado';

  @override
  String get profileStatusSaveFailed => 'No se pudo guardar el estado';

  @override
  String get profileStatusSaved => 'Estado guardado';

  @override
  String get profileStatusTitle => 'Estado';

  @override
  String get profilesActive => 'Perfil activo';

  @override
  String get profilesAdd => 'Añadir un perfil';

  @override
  String get profilesAllWorkspaces =>
      'Todos los espacios (operador de la plataforma)';

  @override
  String get profilesCopyEmail => 'Copiar correo';

  @override
  String get profilesDefault => 'Predeterminado al iniciar';

  @override
  String get profilesEmailCopied => 'Correo copiado.';

  @override
  String get profilesMakeDefault => 'Usar como predeterminado al iniciar';

  @override
  String profilesNotMember(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count miembros',
      one: '1 miembro',
    );
    return 'No miembro · $_temp0';
  }

  @override
  String get profilesOwnersNone => 'Sin propietario.';

  @override
  String profilesOwnersOf(String name) {
    return 'Propietarios de $name';
  }

  @override
  String get profilesPairDev => 'DEV';

  @override
  String get profilesPairProd => 'PROD';

  @override
  String profilesSiteLine(String site) {
    return 'Sede: $site';
  }

  @override
  String get profilesSitePick => 'Cambiar de sede';

  @override
  String get profilesTitle => 'Perfiles';

  @override
  String get profilesUnavailable =>
      'No se pudieron cargar tus espacios de trabajo.';

  @override
  String provenanceFromTemplate(String name) {
    return 'De la plantilla «$name»';
  }

  @override
  String get provenanceProductDefault => 'Valor predeterminado del producto';

  @override
  String get provenanceResetToDefault => 'Volver al valor predeterminado';

  @override
  String get provenanceResetToTemplate => 'Volver a la plantilla';

  @override
  String get provenanceWorkspaceSetting => 'Ajuste del espacio';

  @override
  String get publicHolidaysAction => 'Añadir días festivos';

  @override
  String publicHolidaysConfirm(int count) {
    return 'Crear $count días de cierre';
  }

  @override
  String get publicHolidaysCountry => 'País';

  @override
  String publicHolidaysCreated(int count) {
    return '$count días de cierre creados';
  }

  @override
  String get publicHolidaysLocked => 'Mes facturado: no se crea';

  @override
  String publicHolidaysLockedMonths(String months) {
    return 'Omitidos, ya facturados: $months';
  }

  @override
  String get publicHolidaysNothingToCreate =>
      'Nada que crear: todos los días ya están.';

  @override
  String get publicHolidaysPresent => 'Ya es un día de cierre';

  @override
  String get publicHolidaysPreviewNone => 'No hay días festivos para este año.';

  @override
  String get publicHolidaysSheetTitle => 'Días festivos';

  @override
  String get publicHolidaysYear => 'Año';

  @override
  String get publicPersonUnavailable => 'Este perfil no es público.';

  @override
  String get publicProfileCopied => 'Enlace copiado.';

  @override
  String get publicProfileCopy => 'Copiar el enlace';

  @override
  String get publicProfileOff =>
      'Desactivado: quienes no han iniciado sesión no ven nada de ti.';

  @override
  String get publicProfileOn =>
      'Cualquiera con el enlace lee tu nombre, tu profesión y tu presentación.';

  @override
  String get publicProfilePublishAction => 'Publicar';

  @override
  String get publicProfilePublishBody =>
      'Cualquier persona en Internet, con sesión o sin ella, podrá leer tu nombre, tu profesión y tu presentación en tu enlace. Tus datos de contacto, tu presencia y tus espacios siguen siendo privados.';

  @override
  String get publicProfilePublishTitle => '¿Publicar un perfil público?';

  @override
  String get publicProfileTitle => 'Perfil público';

  @override
  String get pushCancelledBody => 'Un admin eliminó una reserva.';

  @override
  String get pushCancelledTitle => 'Reserva eliminada';

  @override
  String get pushPendingBody => 'Alguien necesita tu confirmación.';

  @override
  String get pushPendingTitle => 'DesKilo';

  @override
  String get pushStatusNoTransport =>
      'Esta versión no tiene notificaciones push';

  @override
  String get pushStatusNoTransportHint =>
      'Las notificaciones llegan en la app y como notificaciones locales en este dispositivo.';

  @override
  String get pushStatusNotConfigured =>
      'Las notificaciones push aún no están configuradas';

  @override
  String get pushStatusNotConfiguredHint =>
      'El propietario completa la configuración de Firebase (guía push-setup).';

  @override
  String get pushStatusRegistered => 'Las notificaciones push están activas';

  @override
  String get questionEditorActive => 'Se pregunta ahora';

  @override
  String get questionEditorChoices => 'Opciones, una por línea';

  @override
  String get questionEditorContextJoin => 'Al unirse';

  @override
  String get questionEditorContextManaged =>
      'La información de un miembro gestionado';

  @override
  String get questionEditorContextProfile => 'La información del miembro';

  @override
  String get questionEditorContexts => 'Dónde se pregunta';

  @override
  String get questionEditorKey => 'Clave';

  @override
  String get questionEditorKeyHelp =>
      'Minúsculas, dígitos y guiones bajos. No cambia nunca: las respuestas se apoyan en ella.';

  @override
  String questionEditorLabelFor(String locale) {
    return 'Etiqueta ($locale)';
  }

  @override
  String get questionEditorMax => 'Número máximo';

  @override
  String get questionEditorMaxLength => 'Respuesta más larga (caracteres)';

  @override
  String get questionEditorMin => 'Número mínimo';

  @override
  String get questionEditorNotPersonalWarning =>
      'Sigue siendo personal: la respuesta está vinculada a un miembro, así que se exporta y se borra con la membresía, diga lo que diga este interruptor. Solo una conservación legal documentada puede guardarla.';

  @override
  String get questionEditorPersonal => 'Es un dato personal';

  @override
  String get questionEditorPersonalHelp =>
      'Cada respuesta está vinculada a un miembro, así que es un dato personal: viaja en su exportación de datos y se borra cuando se va.';

  @override
  String get questionEditorPreview => 'Cómo se verá';

  @override
  String get questionEditorRequired => 'Debe responderse';

  @override
  String get questionEditorSave => 'Guardar la pregunta';

  @override
  String get questionEditorSaveFailed => 'La pregunta no se ha guardado.';

  @override
  String get questionEditorType => 'Tipo de respuesta';

  @override
  String get questionEditorVisibility => 'Quién ve la respuesta';

  @override
  String get questionEditorVisibilityManagers =>
      'El miembro, y quien puede ver datos personales';

  @override
  String get questionEditorVisibilityMembers =>
      'Todos los miembros del espacio';

  @override
  String get questionEditorVisibilitySelf => 'Solo el miembro';

  @override
  String get questionTypeBoolean => 'Sí o no';

  @override
  String get questionTypeDate => 'Una fecha';

  @override
  String get questionTypeDecimal => 'Un número';

  @override
  String get questionTypeInteger => 'Un número entero';

  @override
  String get questionTypeLongText => 'Una respuesta larga';

  @override
  String get questionTypeMultiChoice => 'Varias de una lista';

  @override
  String get questionTypeSingleChoice => 'Una de una lista';

  @override
  String get questionTypeText => 'Una respuesta corta';

  @override
  String get questionsAdd => 'Añadir una pregunta';

  @override
  String get questionsEmpty => 'Todavía no hay preguntas.';

  @override
  String get questionsInactive => 'Apartada';

  @override
  String get questionsSubtitle =>
      'Aparecen dentro de la información personal, bajo el nombre de tu espacio.';

  @override
  String get questionsTitle => 'Las preguntas de este espacio';

  @override
  String get quotaExceededError =>
      'Cuota mensual de medias jornadas alcanzada — solicita medias jornadas extra desde la pestaña Finanzas.';

  @override
  String get quotaRequestButton => 'Solicitar medias jornadas extra';

  @override
  String get quotaRequestCountLabel => 'Número de medias jornadas';

  @override
  String quotaRequestExplainer(String period) {
    return 'Tus reservas están limitadas por tu suscripción. Las medias jornadas extra para $period se aplican una vez validadas.';
  }

  @override
  String get quotaRequestPending =>
      'Solicitud enviada — pendiente de validación.';

  @override
  String get quotaRequestTitle => 'Solicitar medias jornadas extra';

  @override
  String readinessActor(String who) {
    return 'Quién: $who';
  }

  @override
  String get readinessActorAdministrator =>
      'Un administrador de la base de datos';

  @override
  String get readinessActorOperator => 'El operador del servidor';

  @override
  String get readinessActorOwner => 'Usted';

  @override
  String readinessAll(String ready, String total) {
    return 'Todas las secciones ($ready de $total listas)';
  }

  @override
  String get readinessAreaAssistant => 'Acceso de asistentes (opcional)';

  @override
  String get readinessAreaBackend => 'Servidor y versión de la base de datos';

  @override
  String get readinessAreaFirstBooking => 'Una primera reserva';

  @override
  String get readinessAreaInvitations => 'Invitar a los primeros miembros';

  @override
  String get readinessAreaLocalSetup =>
      'Datos que necesitan sus funciones (identidad, banco, plataformas)';

  @override
  String get readinessAreaPayments => 'Cómo pagan los miembros';

  @override
  String get readinessAreaPricing => 'Planes de membresía y tarifas';

  @override
  String get readinessAreaRecovery => 'Exportación y recuperación';

  @override
  String get readinessAreaRegionRules =>
      'Días de apertura, zona horaria y moneda';

  @override
  String get readinessAreaResources => 'Puestos reservables en el plano';

  @override
  String get readinessAreaRolesValidation =>
      'Roles y quién valida las solicitudes';

  @override
  String readinessBlocked(String step) {
    return 'Antes de una primera reserva: $step';
  }

  @override
  String get readinessFirstBookingReady => 'Listo para una primera reserva';

  @override
  String get readinessLater => 'Necesario más adelante';

  @override
  String get readinessNeededFirst => 'Necesario para una primera reserva';

  @override
  String readinessNext(String step) {
    return 'Siguiente: $step';
  }

  @override
  String get readinessReasonEligibilityExpired =>
      'Su habilitación para asistentes ha caducado';

  @override
  String get readinessReasonEligibilityMissing =>
      'Ningún administrador de la base de datos le ha habilitado para asistentes';

  @override
  String get readinessReasonEligibilityNoIdentity =>
      'Inicie sesión primero con su identidad verificada';

  @override
  String get readinessReasonEligibilityRequested =>
      'Su solicitud espera a un administrador de la base de datos';

  @override
  String get readinessReasonNoEvidence =>
      'Aún no se ha registrado ninguna exportación ni restauración';

  @override
  String get readinessReasonNoPolicies =>
      'Ninguna solicitud espera a un validador';

  @override
  String get readinessReasonNotExposed =>
      'Este espacio aún no expone nada a los asistentes';

  @override
  String get readinessReasonRecentExport =>
      'Hay una exportación reciente registrada';

  @override
  String get readinessReasonStaleExport =>
      'La última exportación registrada tiene más de 90 días';

  @override
  String get readinessReasonTooFewValidators =>
      'Una regla pide más validadores de los que tiene este espacio';

  @override
  String get readinessSetAside => 'Dejado para más tarde';

  @override
  String get readinessSetAsideAction => 'Más tarde';

  @override
  String get readinessSetAsideFailed =>
      'No se pudo guardar. Inténtelo de nuevo.';

  @override
  String get readinessSetAsideUndo => 'Deshacer';

  @override
  String get readinessStateNeeds => 'Por configurar';

  @override
  String get readinessStateNeedsOperator => 'A la espera de otra persona';

  @override
  String get readinessStateNotApplicable => 'No es necesario aquí';

  @override
  String get readinessStateReady => 'Listo';

  @override
  String get readinessStateUnavailable => 'No se pudo leer';

  @override
  String get readinessStateUnverified => 'Aún no verificado';

  @override
  String get readinessTitle => 'Configuración de este espacio';

  @override
  String get recordingPrivacyBadge => 'Modo grabación — personas inventadas';

  @override
  String get recordingPrivacyBadgeHint =>
      'El modo grabación está activo: cada nombre, correo electrónico, número de teléfono, dirección y fotografía en pantalla pertenece a una persona inventada. El plano, las reservas y los importes sí son los de este espacio. Desactívelo en los Ajustes cuando termine de grabar.';

  @override
  String get recordingPrivacyWriteRefused =>
      'No mientras el modo grabación esté activo: este formulario muestra una persona inventada, y guardarlo sobrescribiría los datos reales de alguien. Desactive antes el modo grabación.';

  @override
  String get refFacetMonth => 'Mes';

  @override
  String get refFacetPerson => 'Persona';

  @override
  String get refFacetStatus => 'Estado';

  @override
  String get refFacetType => 'Tipo';

  @override
  String get refFacetWorkspace => 'Espacio';

  @override
  String get refFilterAll => 'Todo';

  @override
  String get refFilterAmount => 'Importe';

  @override
  String get refFilterClear => 'Borrar filtros';

  @override
  String refFilterFindIn(String facet) {
    return 'Buscar en $facet';
  }

  @override
  String get refFilterMore => 'Filtros';

  @override
  String get refFilterReset => 'Restablecer';

  @override
  String refFilterShow(int count) {
    return 'Mostrar $count resultados';
  }

  @override
  String get refFilterSort => 'Ordenar';

  @override
  String get refSortAmountHigh => 'Importe más alto';

  @override
  String get refSortAmountLow => 'Importe más bajo';

  @override
  String get refSortNewest => 'Más recientes primero';

  @override
  String get refSortOldest => 'Más antiguos primero';

  @override
  String get refStatusCancelled => 'Anulada';

  @override
  String get refStatusDecided => 'Decidida';

  @override
  String get refStatusOpen => 'Abierta (sin pagar)';

  @override
  String get refStatusPaid => 'Pagada';

  @override
  String get refStatusPending => 'Pendiente';

  @override
  String get refStatusRefunded => 'Reembolsada';

  @override
  String get refTypeCreditNote => 'Nota de crédito';

  @override
  String get refTypeInvoice => 'Factura';

  @override
  String get refusalAlreadyDecided =>
      'Alguien ya lo ha decidido. La lista muestra el resultado.';

  @override
  String get refusalChangedMeanwhile =>
      'Esto ha cambiado mientras tanto. Vuelva a abrirlo para ver cómo está.';

  @override
  String get refusalPermission =>
      'No tiene permiso para esto. Un propietario del espacio puede concederlo en Gestión de roles.';

  @override
  String get refusalSession =>
      'Su sesión ha terminado. Vuelva a iniciar sesión e inténtelo de nuevo.';

  @override
  String get regionalClock => 'Reloj';

  @override
  String get regionalClock12h => '12h';

  @override
  String get regionalClock24h => '24h';

  @override
  String get regionalClockAuto => 'Auto';

  @override
  String get regionalDeviceZone => 'Mostrar las horas en mi zona horaria';

  @override
  String get regionalDeviceZoneHint =>
      'Desactivado: las horas se muestran en la zona del espacio, en la que se reserva. Activado: la de su dispositivo, señalada cuando difiere.';

  @override
  String get regionalFollowLanguage => 'Automático';

  @override
  String get regionalFormatLocale => 'Números y fechas';

  @override
  String regionalFormatLocaleAuto(String locale) {
    return 'Sigue el idioma de la app ($locale)';
  }

  @override
  String get regionalFormatsTitle => 'Región y formatos';

  @override
  String get registerPaymentAmount => 'Importe';

  @override
  String get registerPaymentDate => 'Pagado el';

  @override
  String get registerPaymentDone =>
      'Pago registrado: el socio lo confirma por su parte.';

  @override
  String get registerPaymentHint =>
      'Un pago que llegó al espacio: el socio lo confirma y luego puede conciliarse con una factura.';

  @override
  String get registerPaymentMember => 'Socio';

  @override
  String get registerPaymentMethod => 'Medio';

  @override
  String get registerPaymentNote => 'Nota';

  @override
  String get registerPaymentSubmit => 'Registrar';

  @override
  String get registerPaymentTitle => 'Registrar un pago';

  @override
  String reminderBody(String target, String time) {
    return '$target empieza a las $time';
  }

  @override
  String reminderHistoryLine(int level, String origin, String date) {
    return 'Nivel $level · $origin · $date';
  }

  @override
  String get reminderHistoryRefresh => 'Comprobar de nuevo el envío';

  @override
  String get reminderHistoryTitle => 'Historial de recordatorios';

  @override
  String get reminderOriginAutomatic => 'automático';

  @override
  String get reminderOriginLegacy => 'anterior';

  @override
  String get reminderOriginManual => 'a mano';

  @override
  String get reminderPdfClosing => 'Si ya has pagado, ignora esta carta.';

  @override
  String get reminderPdfDays => 'días';

  @override
  String get reminderPdfDaysOpen => 'Abierta desde hace';

  @override
  String get reminderPdfLevelLabel => 'Nivel de recordatorio';

  @override
  String get reminderPdfOpeningFirm =>
      'a pesar de nuestro recordatorio anterior, la factura de abajo sigue sin pagar. Por favor, liquida el importe sin demora.';

  @override
  String get reminderPdfOpeningFriendly =>
      'este es un recordatorio amistoso: la factura de abajo sigue abierta. Seguramente un simple despiste — sin problema.';

  @override
  String get reminderPdfTitleFirm => 'Recordatorio';

  @override
  String get reminderPdfTitleFriendly => 'Recordatorio de pago';

  @override
  String get reminderStatusAccepted =>
      'Aceptado por el servicio de notificaciones — no prueba que se haya leído';

  @override
  String get reminderStatusDeclared =>
      'Compartido por el remitente — su declaración, no un acuse de recibo';

  @override
  String get reminderStatusFailed => 'No entregado';

  @override
  String get reminderStatusLegacy =>
      'Registrado antes del seguimiento de envíos — desconocido';

  @override
  String get reminderStatusPrepared => 'Preparado';

  @override
  String get reminderStatusQueued => 'Entregado al servicio de notificaciones';

  @override
  String get reminderStatusUnknown =>
      'Sin respuesta del servicio de notificaciones';

  @override
  String get reminderTitle => 'Regístrate pronto';

  @override
  String get repartitionAction => 'Repartir un gasto';

  @override
  String get repartitionAmount => 'Importe total';

  @override
  String get repartitionAmountLabel => 'Importe';

  @override
  String get repartitionBooked => 'Reparto contabilizado.';

  @override
  String get repartitionExclude => 'Excluir';

  @override
  String get repartitionFiled =>
      'Partes contabilizadas: aparecerán en la próxima factura de uso.';

  @override
  String get repartitionFiledPending =>
      'Partes presentadas: se contabilizan tras la validación.';

  @override
  String get repartitionHint =>
      'Reparta un coste común entre los socios. Las partes se convierten en líneas de la próxima factura de uso de cada uno; una reversión devuelve el dinero como notas de crédito.';

  @override
  String get repartitionHistory => 'Repartos';

  @override
  String get repartitionHistoryEmpty => 'Ningún reparto todavía.';

  @override
  String get repartitionMethod => 'Repartir por';

  @override
  String get repartitionMethodCustom => 'Clave propia';

  @override
  String get repartitionMethodEqual => 'Partes iguales';

  @override
  String get repartitionMethodSubscription => 'Suscripción';

  @override
  String get repartitionMethodUsage => 'Uso';

  @override
  String get repartitionNoShares => 'Nadie lleva una parte: revise la clave.';

  @override
  String get repartitionPeriod => 'Se imputa a';

  @override
  String get repartitionPeriodLabel => 'Mes';

  @override
  String get repartitionPreview => 'Partes';

  @override
  String get repartitionRememberRule => 'Recordar esta regla';

  @override
  String get repartitionReverse => 'Reversión — devolver como notas de crédito';

  @override
  String get repartitionRuleHint =>
      'Cada parte se propone según el porcentaje de suscripción. Desmarque un socio para excluirlo; con el método «clave», indique su peso. La regla ajustada se propondrá el mes que viene.';

  @override
  String get repartitionRuleNotSaved =>
      'No se pudo guardar la regla, así que no se repartió nada. Inténtalo de nuevo.';

  @override
  String get repartitionSharesTotal => 'Total de las partes';

  @override
  String get repartitionStatusConfirmed => 'Contabilizado';

  @override
  String get repartitionStatusExpired => 'Caducado';

  @override
  String get repartitionStatusPending => 'Pendiente de validación';

  @override
  String get repartitionStatusRejected => 'Rechazado';

  @override
  String get repartitionStepBook => 'Contabilizar';

  @override
  String get repartitionStepCost => 'El gasto';

  @override
  String get repartitionStepExpense => 'El gasto';

  @override
  String get repartitionStepRule => 'La regla';

  @override
  String get repartitionSubmit => 'Contabilizar las partes';

  @override
  String repartitionSum(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count socios · $amount',
      one: '1 socio · $amount',
    );
    return '$_temp0';
  }

  @override
  String get repartitionTitle => 'Repartir un gasto';

  @override
  String get repartitionTitleField => 'Concepto';

  @override
  String get repartitionTitleLabel => 'Concepto';

  @override
  String get repartitionWeight => 'Clave';

  @override
  String get repartitionWizardSubtitle =>
      'Proponer según la suscripción, ajustar, contabilizar';

  @override
  String get repartitionWizardTitle => 'Repartir un gasto';

  @override
  String get repartitionWizardWeight => 'Peso';

  @override
  String get repeatDaily => 'Cada día';

  @override
  String get repeatNone => 'No se repite';

  @override
  String get repeatWeekdays => 'Cada día laborable';

  @override
  String get repeatWeekly => 'Semanalmente';

  @override
  String get reportBadgesFooter =>
      'Una credencial perdida se revoca en Miembros y planes, no basta con sustituirla.';

  @override
  String get reportBadgesIntro =>
      'Corta por las líneas. Cada tarjeta lleva el código de un miembro — preséntala en el quiosco para registrarte.';

  @override
  String get reportBadgesTitle => 'Credenciales de los miembros';

  @override
  String get reportCoaAccounts => 'Cuentas sugeridas';

  @override
  String get reportCoaDisclaimer =>
      'Solo una vista previa. DesKilo no lleva libro mayor ni hace tu contabilidad — el plan de tu contable siempre manda.';

  @override
  String get reportCoaIntro =>
      'Una sugerencia, no tu contabilidad. Son las cuentas que un contable de tu país usaría normalmente para un espacio como el tuyo.';

  @override
  String get reportCoaLabel => 'Nombre';

  @override
  String get reportCoaNumber => 'Cuenta';

  @override
  String get reportCoaTitle => 'Plan de cuentas — vista previa';

  @override
  String get reportColQty => 'Cant.';

  @override
  String get reportColTotal => 'Total';

  @override
  String get reportColUnitPrice => 'Precio unit.';

  @override
  String get reportDesignEmpty => 'Banda vacía — añade un elemento abajo.';

  @override
  String get reportDesignErrorInvalidDesign =>
      'Ese archivo no contiene ningún diseño legible.';

  @override
  String get reportDesignErrorMalformed => 'Ese archivo no es JSON legible.';

  @override
  String get reportDesignErrorNotADesign =>
      'Ese archivo no es un diseño de informe de DesKilo.';

  @override
  String get reportDesignErrorUnknownKind =>
      'Ese diseño es de un informe que este espacio no tiene.';

  @override
  String get reportDesignErrorVersion =>
      'Ese diseño se escribió con una versión más nueva de DesKilo.';

  @override
  String get reportDesignErrorWrongKind =>
      'Ese diseño pertenece a otro informe. Ábrelo e impórtalo allí.';

  @override
  String get reportDesignExport => 'Exportar este diseño';

  @override
  String get reportDesignFileTypeLabel => 'JSON';

  @override
  String get reportDesignImport => 'Importar un diseño';

  @override
  String get reportDesignImported =>
      'Diseño importado. Guarda para conservarlo.';

  @override
  String get reportDesignerDesign => 'Diseño';

  @override
  String get reportDesignerDiscard => 'Descartar';

  @override
  String get reportDesignerDiscardBody =>
      'Sus cambios en las plantillas no están guardados.';

  @override
  String get reportDesignerDiscardTitle => '¿Salir sin guardar?';

  @override
  String get reportDesignerDrag => 'Arrastrar para reordenar';

  @override
  String reportDesignerError(String message) {
    return 'La plantilla no se genera — $message';
  }

  @override
  String get reportDesignerFields => 'Campos';

  @override
  String get reportDesignerFieldsSearch => 'Buscar un campo';

  @override
  String get reportDesignerInsert => 'Insertar elemento';

  @override
  String get reportDesignerKeepEditing => 'Seguir editando';

  @override
  String get reportDesignerMoveTo => 'Mover a la banda';

  @override
  String reportDesignerPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count páginas',
      one: '1 página',
    );
    return '$_temp0';
  }

  @override
  String get reportDesignerPreview => 'Vista previa';

  @override
  String get reportDesignerRedo => 'Rehacer';

  @override
  String get reportDesignerReplace => 'Reemplazar';

  @override
  String get reportDesignerReplaceBody =>
      'Las bandas de este documento se reemplazan. Deshacer las recupera.';

  @override
  String get reportDesignerReplaceTitle => '¿Reemplazar el diseño actual?';

  @override
  String get reportDesignerSideBySide => 'Diseño y vista previa lado a lado';

  @override
  String get reportDesignerUndo => 'Deshacer';

  @override
  String get reportDesignerZoom => 'Zoom';

  @override
  String get reportDesignerZoomFit => 'Ajustar al ancho';

  @override
  String get reportDocAgreement => 'Acuerdo financiero';

  @override
  String get reportDocBadges => 'Tarjetas de socios';

  @override
  String get reportDocCoa => 'Plan de cuentas';

  @override
  String get reportDocPayments => 'Informe de pagos';

  @override
  String get reportDocSpaceCodes => 'Tarjetas QR de espacios';

  @override
  String get reportDocStatus => 'Situación del espacio';

  @override
  String get reportDocUsage => 'Informe de consumo';

  @override
  String get reportDocVat => 'Informe de IVA';

  @override
  String get reportDocWorkspace => 'Informe del espacio';

  @override
  String get reportDocWorkspaceSubtitle =>
      'Todo sobre el espacio — mediante la plantilla de espacio del editor de informes';

  @override
  String get reportEditorMarkup => 'Marcado';

  @override
  String get reportEditorTitle => 'Editor de informes';

  @override
  String get reportEditorVisual => 'Visual';

  @override
  String get reportFieldGroupBank => 'Datos bancarios';

  @override
  String get reportFieldGroupDocument => 'Documento';

  @override
  String get reportFieldGroupLegal => 'Menciones legales';

  @override
  String get reportFieldGroupLoops => 'Bucles de líneas e IVA';

  @override
  String get reportFieldGroupMember => 'Socio y espacio';

  @override
  String get reportFieldGroupMoney => 'Importes';

  @override
  String get reportFieldGroupSeller => 'Vendedor';

  @override
  String get reportFieldGroupSites => 'Sedes';

  @override
  String get reportFieldGroupStatus => 'Situación del espacio';

  @override
  String get reportFieldGroupTexts => 'Sus textos';

  @override
  String get reportFieldGroupUsage => 'Informe de consumo';

  @override
  String get reportFieldGroupVat => 'Informe de IVA';

  @override
  String get reportFieldMeaningAccountHolder => 'El titular de la cuenta';

  @override
  String get reportFieldMeaningBankAccount => 'El número de cuenta';

  @override
  String get reportFieldMeaningBankCode => 'El código bancario';

  @override
  String get reportFieldMeaningBankName => 'El nombre del banco';

  @override
  String get reportFieldMeaningBic => 'El BIC del banco';

  @override
  String get reportFieldMeaningBuyerReference =>
      'La referencia propia del comprador (sector público)';

  @override
  String get reportFieldMeaningCharges => 'Los cargos antes de los pagos';

  @override
  String get reportFieldMeaningClientAddress => 'El bloque postal del cliente';

  @override
  String get reportFieldMeaningClientCompany => 'La empresa del cliente';

  @override
  String get reportFieldMeaningClientEmail => 'El correo del cliente';

  @override
  String get reportFieldMeaningClientLegalId =>
      'El identificador legal del cliente';

  @override
  String get reportFieldMeaningClientMemberNumber =>
      'El número de socio del cliente';

  @override
  String get reportFieldMeaningClientName => 'El nombre completo del cliente';

  @override
  String get reportFieldMeaningClientPhone => 'El teléfono del cliente';

  @override
  String get reportFieldMeaningClientVatId => 'El número de IVA del cliente';

  @override
  String get reportFieldMeaningCopy => 'Verdadero en un duplicado';

  @override
  String get reportFieldMeaningCreditNote => 'Verdadero en una nota de crédito';

  @override
  String get reportFieldMeaningDueDate => 'La fecha de vencimiento';

  @override
  String get reportFieldMeaningEscompte =>
      'La mención de descuento por pronto pago';

  @override
  String get reportFieldMeaningExemptionReason =>
      'La mención de exención de IVA';

  @override
  String get reportFieldMeaningHasVat => 'Verdadero cuando se aplica IVA';

  @override
  String get reportFieldMeaningIban => 'El IBAN de la cuenta';

  @override
  String get reportFieldMeaningInsurance => 'La mención del seguro profesional';

  @override
  String get reportFieldMeaningIssued => 'La fecha de emisión';

  @override
  String get reportFieldMeaningIssuedBy => 'Quién emitió el documento';

  @override
  String get reportFieldMeaningLatePenalty =>
      'La mención de penalización por demora';

  @override
  String get reportFieldMeaningLines => 'Las líneas de la factura — un bucle';

  @override
  String get reportFieldMeaningMember => 'El nombre visible del miembro';

  @override
  String get reportFieldMeaningNetTotal => 'El total sin IVA';

  @override
  String get reportFieldMeaningNumber => 'El número del documento';

  @override
  String get reportFieldMeaningPaymentReference =>
      'La referencia a indicar al pagar';

  @override
  String get reportFieldMeaningPaymentTerms =>
      'La mención de las condiciones de pago';

  @override
  String get reportFieldMeaningPaymentTermsSource =>
      'De dónde vienen las condiciones (miembro o espacio)';

  @override
  String get reportFieldMeaningPayments => 'Los pagos ya recibidos';

  @override
  String get reportFieldMeaningPendingExpensesTotal => 'Gastos aún por validar';

  @override
  String get reportFieldMeaningPendingPaymentsTotal =>
      'Pagos aún por confirmar';

  @override
  String get reportFieldMeaningPeriod => 'El mes que cubre el documento';

  @override
  String get reportFieldMeaningPeriodMonth =>
      'El mes del periodo, por su nombre («Septiembre»)';

  @override
  String get reportFieldMeaningPeriodYear => 'El año del periodo';

  @override
  String get reportFieldMeaningProforma => 'Verdadero en una proforma';

  @override
  String get reportFieldMeaningPurchaseOrder =>
      'La referencia del pedido del comprador';

  @override
  String get reportFieldMeaningRecoveryIndemnity =>
      'La mención de la indemnización de cobro';

  @override
  String get reportFieldMeaningRefundTotal => 'El importe reembolsado';

  @override
  String get reportFieldMeaningReplaces =>
      'El número de la factura que esta reemplaza';

  @override
  String get reportFieldMeaningSellerLegalForm =>
      'La forma jurídica del vendedor';

  @override
  String get reportFieldMeaningSellerLegalId =>
      'El identificador legal del vendedor';

  @override
  String get reportFieldMeaningSellerRegistration => 'El registro del vendedor';

  @override
  String get reportFieldMeaningSellerVatId => 'El número de IVA del vendedor';

  @override
  String get reportFieldMeaningSiteAddress =>
      'La dirección de la sede del documento';

  @override
  String get reportFieldMeaningSiteName => 'El nombre de la sede del documento';

  @override
  String get reportFieldMeaningSpecialMentions =>
      'Las menciones especiales del espacio';

  @override
  String get reportFieldMeaningStatusCreditNotes =>
      'Las notas de crédito emitidas';

  @override
  String get reportFieldMeaningStatusCredits => 'Los créditos concedidos';

  @override
  String get reportFieldMeaningStatusFrom =>
      'El primer día del periodo de situación';

  @override
  String get reportFieldMeaningStatusInvoiced => 'Lo que el espacio facturó';

  @override
  String get reportFieldMeaningStatusMembers =>
      'Las líneas por miembro — un bucle';

  @override
  String get reportFieldMeaningStatusNet => 'Ingresos menos gastos';

  @override
  String get reportFieldMeaningStatusPayments => 'Lo que se cobró';

  @override
  String get reportFieldMeaningStatusReimbursed => 'Lo que se reembolsó';

  @override
  String get reportFieldMeaningStatusRepartitioned => 'Lo que se repartió';

  @override
  String get reportFieldMeaningStatusTo =>
      'El último día del periodo de situación';

  @override
  String get reportFieldMeaningTotal => 'El importe debido, todo incluido';

  @override
  String get reportFieldMeaningUsageExtraHalfDays =>
      'Medias jornadas más allá de la suscripción';

  @override
  String get reportFieldMeaningUsageIncludedHalfDays =>
      'Medias jornadas incluidas en la suscripción';

  @override
  String get reportFieldMeaningUsageOverage => 'El exceso facturado';

  @override
  String get reportFieldMeaningUsagePaid => 'Lo que costó el consumo del mes';

  @override
  String get reportFieldMeaningUsageRecords =>
      'Cada registro de consumo — un bucle';

  @override
  String get reportFieldMeaningUsageRemainingHalfDays =>
      'Medias jornadas restantes';

  @override
  String get reportFieldMeaningUsageSites => 'Las otras sedes del mes';

  @override
  String get reportFieldMeaningUsageSupplements =>
      'Los suplementos de accesorios';

  @override
  String get reportFieldMeaningUsageUsedHalfDays => 'Medias jornadas usadas';

  @override
  String get reportFieldMeaningVat => 'El IVA por tipo — un bucle';

  @override
  String get reportFieldMeaningVatBasisNote =>
      'Si el periodo cuenta lo cobrado o lo emitido';

  @override
  String get reportFieldMeaningVatExigibilityMention =>
      'Cuándo es exigible el IVA, en palabras';

  @override
  String get reportFieldMeaningVatPeriod => 'El periodo de IVA declarado';

  @override
  String get reportFieldMeaningVatPeriodGross => 'El total bruto del periodo';

  @override
  String get reportFieldMeaningVatPeriodNet => 'El total neto del periodo';

  @override
  String get reportFieldMeaningVatPeriodVat => 'El IVA del periodo';

  @override
  String get reportFieldMeaningVatPositions =>
      'Cada factura del periodo de IVA — un bucle';

  @override
  String get reportFieldMeaningVatRateTotals =>
      'Los totales del periodo por tipo — un bucle';

  @override
  String get reportFieldMeaningVatTotal => 'El total de IVA';

  @override
  String get reportFieldMeaningVoided =>
      'Verdadero cuando la factura está anulada';

  @override
  String get reportFieldMeaningWorkspace => 'El nombre del espacio';

  @override
  String get reportFieldMeaningWorkspaceAddress =>
      'La dirección del espacio, o la de la sede del documento';

  @override
  String get reportGuideInsertField => 'Insertar un campo…';

  @override
  String reportGuideInsertedInto(String band) {
    return 'Insertado en $band';
  }

  @override
  String get reportGuideIntro =>
      'Tres bandas componen el PDF: cabecera, cuerpo, pie. Escriba texto, ponga un campo donde va un valor y un signo de marcado al inicio de la línea para su estilo. El XML de la factura electrónica nunca se toca.';

  @override
  String get reportGuideMarkupTitle => 'Marcado de línea';

  @override
  String get reportGuideSnippetIf => 'Una línea solo si el valor existe';

  @override
  String get reportGuideSnippetLoop => 'Una fila por línea de factura';

  @override
  String get reportGuideSnippetTitle =>
      'El título: factura, nota de crédito o proforma';

  @override
  String get reportGuideSnippetsTitle => 'Piezas listas';

  @override
  String get reportGuideTitle => 'Campos y marcado';

  @override
  String get reportImageAlign => 'Alineación';

  @override
  String get reportImageAlignCenter => 'Centro';

  @override
  String get reportImageAlignLeft => 'Izquierda';

  @override
  String get reportImageAlignRight => 'Derecha';

  @override
  String get reportImageSize => 'Tamaño';

  @override
  String get reportImageSizeLarge => 'Grande';

  @override
  String get reportImageSizeMedium => 'Mediana';

  @override
  String get reportImageSizeSmall => 'Pequeña';

  @override
  String get reportImageUpload => 'Subir imagen';

  @override
  String get reportImagesEmpty =>
      'Aún no hay imágenes — sube tu logotipo, un sello o una firma y refénciala con ![nombre].';

  @override
  String get reportImagesLoadFailed =>
      'No se pudieron cargar las imágenes de los informes. Inténtelo de nuevo.';

  @override
  String get reportImagesTitle => 'Imágenes de informes';

  @override
  String get reportInsertImage => 'Insertar imagen';

  @override
  String get reportLanguageAmbiguous =>
      'Este país tiene varios idiomas — define primero el idioma del espacio en los Ajustes del espacio.';

  @override
  String get reportLayoutActive => 'Maqueta activa';

  @override
  String get reportLayoutBands => 'Bandas';

  @override
  String get reportLayoutExport => 'Exportar XML';

  @override
  String get reportLayoutFileTypeLabel => 'XML';

  @override
  String get reportLayoutImport => 'Importar XML';

  @override
  String get reportLayoutImported =>
      'Maqueta importada. Guarde para conservarla.';

  @override
  String get reportLayoutPreview => 'Vista de página';

  @override
  String get reportLayoutRemove => 'Quitar la maqueta (bandas)';

  @override
  String get reportLayoutSubtitle =>
      'Una maqueta indica dónde se sitúa cada elemento, en mm, cm, px o %. Expórtela, edítela, compruébela con `dart run tool/report.dart check`, vuelva a importarla. Cuando existe una maqueta es la que se imprime; elimínela y vuelven a imprimirse las bandas.';

  @override
  String get reportLayoutTitle => 'Maqueta posicionada (XML)';

  @override
  String get reportLineBoldRow => 'Fila en negrita';

  @override
  String get reportLineColumns => 'Inicio/fin de columnas';

  @override
  String get reportLineColumnsSplit => 'Salto de columna';

  @override
  String get reportLineDivider => 'Separador';

  @override
  String get reportLineImage => 'Imagen';

  @override
  String get reportLineLogic => 'Lógica';

  @override
  String get reportLineRow => 'Fila de tabla';

  @override
  String get reportLineSection => 'Sección';

  @override
  String get reportLineSmall => 'Letra pequeña';

  @override
  String get reportLineSpacer => 'Espaciado';

  @override
  String get reportLineText => 'Texto';

  @override
  String get reportLineTitle => 'Título';

  @override
  String get reportMarkupBoldRow => 'Una fila de tabla en negrita';

  @override
  String get reportMarkupColumns => 'Columnas lado a lado, separadas por |||';

  @override
  String get reportMarkupHeading => 'Un título grande';

  @override
  String get reportMarkupImage =>
      'Una imagen de la biblioteca: tamaño s/m/l, alineación left/center/right';

  @override
  String get reportMarkupRule => 'Una línea horizontal';

  @override
  String get reportMarkupSection => 'Un encabezado de sección';

  @override
  String get reportMarkupSmall => 'Texto pequeño y discreto';

  @override
  String get reportMarkupTable => 'Una fila de tabla, una celda por |';

  @override
  String get reportPaymentsPeriodTotal => 'Pagos del periodo';

  @override
  String get reportPendingExpenses => 'Gastos pendientes';

  @override
  String get reportPendingPayments => 'Pagos pendientes';

  @override
  String get reportPresetClassic => 'Clásico';

  @override
  String get reportPresetFormalLetter => 'Carta formal';

  @override
  String get reportPresetProfessional => 'Profesional';

  @override
  String get reportPresetSimple => 'Sencillo';

  @override
  String get reportPresetVerbose => 'Detallado';

  @override
  String get reportPreviewFit => 'Ajustar al ancho';

  @override
  String get reportPreviewSimulated => 'Vista rápida — datos de ejemplo';

  @override
  String get reportPreviewTitle => 'Vista rápida — tu factura más reciente';

  @override
  String get reportPreviewZoomIn => 'Acercar';

  @override
  String get reportPreviewZoomOut => 'Alejar';

  @override
  String get reportQuickView => 'Vista rápida';

  @override
  String get reportRegards => 'Atentamente';

  @override
  String get reportSectionFeatures => 'Funciones';

  @override
  String get reportSectionPrices => 'Precios';

  @override
  String get reportSpaceCodesFooter =>
      'Una tarjeta que ya no corresponde a su espacio confunde a quien la escanea: vuelva a imprimir la hoja tras mover o renombrar un espacio.';

  @override
  String get reportSpaceCodesIntro =>
      'Una tarjeta por puesto, mesa, sala y planta. Pega cada tarjeta en su espacio: escanearla abre la misma ficha que el quiosco.';

  @override
  String get reportSpaceCodesTitle => 'Códigos de los espacios';

  @override
  String get reportSubject => 'Asunto';

  @override
  String get reportTemplateClearOverlay =>
      'Usar la predeterminada para este idioma';

  @override
  String get reportTemplateLangDefault => 'Predeterminado (todos los idiomas)';

  @override
  String get reportTemplateLangInherits => 'Hereda la predeterminada';

  @override
  String get reportTemplateLangOverridden => 'Plantilla propia';

  @override
  String get reportTextsAdd => 'Añadir un texto';

  @override
  String get reportTextsHint =>
      'Sus propias formulaciones, colocadas en cualquier banda o diseño como text.clave. Cada idioma puede tener su valor; uno vacío recurre al idioma predeterminado.';

  @override
  String get reportTextsInherited => 'Idioma predeterminado';

  @override
  String get reportTextsKey => 'Clave';

  @override
  String get reportTextsKeyExists => 'Esta clave ya existe.';

  @override
  String get reportTextsKeyHint =>
      'Letras, dígitos y guiones bajos, p. ej. saludo';

  @override
  String get reportTextsKeyInvalid =>
      'Solo letras, dígitos y guiones bajos, empezando por una letra.';

  @override
  String get reportTextsRemove => 'Eliminar texto';

  @override
  String get reportTextsTitle => 'Textos';

  @override
  String get reportVisualAddLine => 'Añadir línea';

  @override
  String get requestAccept => 'Aceptar';

  @override
  String get requestBlock => 'Bloquear';

  @override
  String get requestIgnore => 'Ignorar';

  @override
  String get reservationCalendarFileButton => 'Guardar archivo de calendario';

  @override
  String get reservationCalendarFileContents => 'Contenido del archivo';

  @override
  String get reservationCalendarFileEvent => 'Evento';

  @override
  String get reservationCalendarFileLocation => 'Lugar';

  @override
  String get reservationCalendarFileName => 'Archivo';

  @override
  String get reservationCalendarFileRefused =>
      'Esta reserva no se puede exportar: no es tuya o ya no existe.';

  @override
  String get reservationCalendarFileSnapshotNote =>
      'Este archivo es una instantánea de la reserva tal como está ahora. Si más tarde se mueve o se cancela, un archivo ya guardado o compartido no cambia — y un archivo compartido no se puede recuperar.';

  @override
  String get reservationCalendarFileStale =>
      'La reserva cambió desde esta vista previa. Revísala de nuevo antes de guardar.';

  @override
  String get reservationCalendarFileStatus => 'Estado';

  @override
  String get reservationCalendarFileStatusCancelled => 'Cancelada';

  @override
  String get reservationCalendarFileStatusConfirmed => 'Confirmada';

  @override
  String get reservationCalendarFileTitle => 'Archivo de calendario';

  @override
  String get reservationCalendarFileWhen => 'Cuándo';

  @override
  String get reservationCancelledSnack => 'Reserva cancelada.';

  @override
  String get reservationDeleteReasonLabel => 'Motivo (opcional)';

  @override
  String get reservationDeleteRequestButton => 'Solicitar eliminación';

  @override
  String get reservationDeleteRequestExplain =>
      'Las reservas pasadas o con registro no se eliminan directamente. Un propietario o admin decidirá: ¿se olvidó simplemente el registro (la reserva se mantiene) o nunca se usó (se elimina)?';

  @override
  String get reservationDeleteSubmit => 'Enviar solicitud';

  @override
  String get reservationDeleteSubmitted =>
      'Eliminación solicitada — un propietario o admin decidirá.';

  @override
  String get reservationEditTimes => 'Cambiar horario';

  @override
  String get reservationEndEarlyAheadOnly =>
      'Elige una hora que aún esté por venir y anterior al final actual.';

  @override
  String get reservationEndEarlyButton => 'Terminar antes';

  @override
  String get reservationExtendButton => 'Quedarse más tiempo';

  @override
  String get reservationExtendLaterOnly =>
      'Elige una hora posterior al final actual.';

  @override
  String get reservationLimitError =>
      'Límite de reservas alcanzado — ya tienes el máximo de reservas abiertas.';

  @override
  String reservationNoteCheckedOutAt(String time) {
    return 'Completada: salida registrada a las $time.';
  }

  @override
  String get reservationNoteOverNotCheckedIn =>
      'Este periodo terminó sin registro de llegada.';

  @override
  String get reservationNoteRecordedAfterEnd =>
      'Registrada después de que terminara este periodo, así que se conserva como una visita pasada.';

  @override
  String get reservationRecurring => 'Reserva recurrente';

  @override
  String get reservationUpdatedSnack => 'Reserva actualizada.';

  @override
  String get reserveAvailabilityUnavailable =>
      'No se pudo cargar toda la disponibilidad, por eso no se muestra ningún puesto como libre. Reintente.';

  @override
  String get reserveBackToNow => 'Volver a ahora';

  @override
  String get reserveBookingFailed =>
      'No se pudo reservar — puede que el asiento se acabe de ocupar.';

  @override
  String get reserveClosedShort => 'Cerrado';

  @override
  String get reserveDayView => 'Día';

  @override
  String get reserveFullDayChip => 'Día completo';

  @override
  String get reserveMonthView => 'Mes';

  @override
  String get reservePickDateTooltip => 'Elegir una fecha';

  @override
  String reserveStaleAvailability(String time) {
    return 'Sin conexión — disponibilidad de las $time. Un puesto que aparece libre puede haberse ocupado desde entonces.';
  }

  @override
  String get reserveStaleRetry => 'Reintentar';

  @override
  String get reserveViewMenu => 'Vista';

  @override
  String get reserveWeekView => 'Semana';

  @override
  String get reverseChargeSubtitle =>
      'Un cliente con NIF-IVA en otro Estado miembro se factura sin impuesto y lo autoliquida (art. 196). Desactívalo si nunca facturas a empresas en el extranjero.';

  @override
  String get reverseChargeTitle =>
      'Inversión del sujeto pasivo para empresas de la UE';

  @override
  String get rightsKindAccess => 'Ver una copia de mis datos';

  @override
  String get rightsKindErasure => 'Suprimir mis datos';

  @override
  String get rightsKindObjection => 'Oponerme a un uso de mis datos';

  @override
  String get rightsKindPortability =>
      'Llevar mis datos a otro sitio (legible por máquina)';

  @override
  String get rightsKindRectification => 'Rectificar mis datos';

  @override
  String get rightsKindRestriction => 'Limitar el uso de mis datos';

  @override
  String get rightsRequestAsk => '¿Qué pides al espacio?';

  @override
  String get rightsRequestDetails => 'Detalles (opcional)';

  @override
  String get rightsRequestFailed =>
      'No se pudo enviar la solicitud. Inténtalo de nuevo.';

  @override
  String get rightsRequestNew => 'Hacer una solicitud';

  @override
  String get rightsRequestSend => 'Enviar la solicitud';

  @override
  String rightsRequestSent(String date) {
    return 'Solicitud enviada — el espacio responde antes del $date.';
  }

  @override
  String get rightsRequestsEmpty => 'Aún no hay solicitudes.';

  @override
  String get rightsRequestsHint =>
      'Pide al espacio una copia, una rectificación, una limitación o la supresión — respuesta en un mes natural.';

  @override
  String get rightsRequestsTitle => 'Mis solicitudes de derechos';

  @override
  String get rightsStatusCompleted =>
      'Atendida — el espacio registró lo que hizo';

  @override
  String rightsStatusExtended(String date, String reason) {
    return 'Prorrogada hasta el $date: $reason';
  }

  @override
  String rightsStatusReceived(String date) {
    return 'Recibida — respuesta antes del $date';
  }

  @override
  String rightsStatusRefused(String reason) {
    return 'Denegada: $reason';
  }

  @override
  String get roleAdmin => 'Administrador/a';

  @override
  String get roleAssignImmediateHint => 'Surte efecto de inmediato.';

  @override
  String get roleAssignNothing => 'No queda ningún rol por dar.';

  @override
  String get roleAssignQuorumHint => 'Surte efecto una vez validado.';

  @override
  String roleAssignSheetTitle(String name) {
    return 'Dar un rol a $name';
  }

  @override
  String get roleBuiltInNote =>
      'Integrado. Lo que permite se define en Roles; se da en la página de cada miembro y surte efecto una vez validado.';

  @override
  String get roleBuiltInSubtitle =>
      'Integrado. Lo que permite se define en Roles.';

  @override
  String get roleEditorActive => 'En uso';

  @override
  String get roleEditorHolders => 'Miembros con este rol';

  @override
  String get roleEditorKey => 'Clave';

  @override
  String get roleEditorKeyHelp =>
      'Minúsculas, dígitos y guiones bajos. No cambia nunca: las personas con el rol se apoyan en ella.';

  @override
  String roleEditorNameFor(String locale) {
    return 'Nombre ($locale)';
  }

  @override
  String get roleEditorNobody => 'Nadie todavía.';

  @override
  String get roleEditorNotYourself => 'No puedes darte un rol a ti misma.';

  @override
  String get roleEditorPermissions => 'Lo que añade';

  @override
  String get roleEditorSave => 'Guardar el rol';

  @override
  String get roleEditorSaveFailed => 'El rol no se ha guardado.';

  @override
  String get roleGiveFailed => 'El rol no se asignó.';

  @override
  String get roleGiven => 'Rol asignado.';

  @override
  String get roleHoldersAdd => 'Añadir un miembro';

  @override
  String get roleMember => 'Todos los miembros';

  @override
  String get roleOwner => 'Propietario';

  @override
  String get roleRefusalExceedsYours =>
      'Este rol puede hacer cosas que tú no puedes, así que solo el propietario lo da.';

  @override
  String get roleRefusalNotAssignable =>
      'Este miembro no puede tener este rol.';

  @override
  String get roleRefusalNotPermitted =>
      'Solo alguien que gestiona los roles puede dar este.';

  @override
  String get roleRefusalOwnerOnly =>
      'Solo el propietario da un rol que gestiona los roles.';

  @override
  String get roleRenameAdministrator => 'Cambiar el nombre';

  @override
  String get roleTakeBackFailed => 'El rol no se retiró.';

  @override
  String get roleTakenBack => 'Rol retirado.';

  @override
  String get rolesIntroEditor =>
      'Cada persona tiene exactamente un rol base — Usuario, Administrador, Copropietario o Propietario. Cualquier otro rol añade lo que sus titulares pueden hacer y nunca quita nada. El propietario siempre tiene todos los permisos; un copropietario puede tener menos.';

  @override
  String get rolesIntroReadOnly =>
      'Solo lectura: estos son los permisos de cada rol. Tu rol está resaltado.';

  @override
  String get rolesOfSpaceAdd => 'Añadir un rol';

  @override
  String get rolesOfSpaceEmpty => 'Todavía no hay roles.';

  @override
  String get rolesOfSpaceInactive => 'Apartado';

  @override
  String get rolesOfSpaceSubtitle =>
      'Cada uno añade permisos a lo que ya pueden hacer quienes lo tienen. Ninguno quita nada, y la propietaria conserva siempre todos los permisos.';

  @override
  String get rolesOfSpaceTitle => 'Los roles de este espacio';

  @override
  String get rolesOwnRolesLink => 'Los roles de este espacio';

  @override
  String get rolesTitle => 'Roles';

  @override
  String get rolesYourRole => 'Tu rol';

  @override
  String get saftDocumentsOnly => 'Solo documentos';

  @override
  String get saftLedgerIntro =>
      'Con números de cuenta, el archivo lleva asientos por partida doble que su asesor puede importar en lugar de teclear. Cubren sus ventas y los cobros correspondientes — no toda su contabilidad.';

  @override
  String get saftLedgerTitle => '¿Incluir asientos?';

  @override
  String get saftWithPostings => 'Con asientos';

  @override
  String get sageAccountsIntro =>
      'Los valores por defecto son las cuentas que Sage trae de serie. El código de IVA decide en qué declaración caen estos asientos: contrástelo con su asesor si no está en el tipo general.';

  @override
  String get sageAccountsTitle => 'Exportación Sage';

  @override
  String get sageTaxCode => 'Código de IVA (T1 / T0 / T9)';

  @override
  String get scanCameraWebUnavailable =>
      'El escaneo con cámara no está disponible en el navegador — escriba el código o acerque una etiqueta NFC al dispositivo (Chrome en Android).';

  @override
  String get scanJoinHelp =>
      'Apunta la cámara al QR de invitación — verás el espacio antes de unirte.';

  @override
  String get scanJoinNotAnInvite =>
      'Ese QR no es una invitación de DesKilo: escanea el del mensaje de invitación.';

  @override
  String get scanJoinTitle => 'Escanear QR del espacio';

  @override
  String get scheduleCancel => 'Terminar esta programación';

  @override
  String get scheduleDaily => 'diaria';

  @override
  String get scheduleEndsOn => 'Hasta (opcional)';

  @override
  String scheduleEveryDays(Object count) {
    return 'cada $count días';
  }

  @override
  String get scheduleEveryLabel => 'Cada';

  @override
  String scheduleEveryMonths(Object count) {
    return 'cada $count meses';
  }

  @override
  String scheduleEveryWeeks(Object count) {
    return 'cada $count semanas';
  }

  @override
  String get scheduleMissingFields => 'Se necesitan el nombre y el importe.';

  @override
  String get scheduleMonthly => 'mensual';

  @override
  String get scheduleNew => 'Programar un gasto recurrente';

  @override
  String scheduleNextDue(Object date) {
    return 'próxima: $date';
  }

  @override
  String get scheduleNoEnd => 'Sin fecha de fin';

  @override
  String get schedulePending =>
      'Programado — a la espera de la confirmación de los validadores.';

  @override
  String get scheduleStartsOn => 'Primer vencimiento';

  @override
  String get scheduleStatusActive => 'Activa';

  @override
  String get scheduleStatusEnded => 'Terminada';

  @override
  String get scheduleStatusPending => 'Pendiente de validación';

  @override
  String get scheduleStatusRejected => 'Rechazada';

  @override
  String get scheduleSubmit => 'Programar';

  @override
  String scheduleTimes(Object count) {
    return '$count veces';
  }

  @override
  String get scheduleTimesLabel =>
      'Repeticiones (vacío = hasta la fecha de fin)';

  @override
  String get scheduleTitleLabel => 'Qué (p. ej. Internet)';

  @override
  String get scheduleUnitDays => 'días';

  @override
  String get scheduleUnitLabel => 'Unidad';

  @override
  String get scheduleUnitMonths => 'meses';

  @override
  String get scheduleUnitWeeks => 'semanas';

  @override
  String get scheduleUnitYears => 'años';

  @override
  String scheduleUntil(Object date) {
    return 'hasta $date';
  }

  @override
  String get scheduleValidationHint =>
      'La programación pasa primero por los validadores. Cada vencimiento se te presenta después: confirmado a este importe cuenta de inmediato; un importe distinto se explica y vuelve a validarse.';

  @override
  String get scheduleWeekly => 'semanal';

  @override
  String get scheduleYearly => 'anual';

  @override
  String get scheduledAwaitingTitle => 'Gastos programados por confirmar';

  @override
  String get scheduledExpensesEmpty => 'Aún no hay gastos programados.';

  @override
  String scheduledExpensesFinished(int count) {
    return 'Finalizadas y rechazadas ($count)';
  }

  @override
  String get scheduledExpensesIntro =>
      'Las suscripciones que paga el espacio — internet, teléfono, electricidad. La programación se valida una vez; cada vencimiento se te presenta antes de contar.';

  @override
  String get scheduledExpensesTitle => 'Gastos programados';

  @override
  String schemaUpdateBody(int version) {
    return 'Esta aplicación necesita la versión $version del esquema de DesKilo, y el servidor al que se conecta ejecuta una más antigua. Hasta que el servidor se actualice, la aplicación fallaría de formas que no podría explicar, así que se detiene aquí.';
  }

  @override
  String get schemaUpdateMember =>
      'Si no: avise a la persona que gestiona su espacio. No se pierde nada de lo que haya introducido.';

  @override
  String get schemaUpdateOperator =>
      'Si gestiona este servidor: aplique las migraciones que faltan con `dart run tool/instance.dart install --ref <proyecto>`. Solo se ejecuta lo que falta.';

  @override
  String get schemaUpdateRetry => 'Comprobar de nuevo';

  @override
  String get schemaUpdateServer => 'Ajustes del servidor';

  @override
  String get schemaUpdateTitle => 'Este servidor necesita una actualización';

  @override
  String get seatDayAhead => 'Por venir';

  @override
  String get seatDayFree => 'Libre — reservar';

  @override
  String get seatDayMine => 'Tú';

  @override
  String get seatDayNow => 'Ahora';

  @override
  String get seatDayPast => 'Terminado';

  @override
  String get seatDaySomeone => 'Un miembro';

  @override
  String get seatDaySubtitle =>
      'Quién ocupa esta plaza, y cuándo. Toca una reserva para abrirla, o un tramo libre para reservarlo.';

  @override
  String seatDayTitle(String seat) {
    return 'Plaza $seat hoy';
  }

  @override
  String seriesBookedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reservas creadas',
      one: '1 reserva creada',
    );
    return '$_temp0';
  }

  @override
  String get seriesSkippedTitle => 'Omitidas (ya ocupadas):';

  @override
  String get serviceOutOfStock => 'Agotado';

  @override
  String get serviceOutOfStockHint =>
      'No queda nada en el estante — el próximo suministro lo repone.';

  @override
  String serviceStockCount(int count) {
    return '$count en stock';
  }

  @override
  String get servicesActive => 'Activo';

  @override
  String get servicesEdit => 'Editar servicio';

  @override
  String get servicesEmpty => 'Aún no hay servicios.';

  @override
  String get servicesInactive => 'Inactivo';

  @override
  String get servicesName => 'Nombre';

  @override
  String get servicesNew => 'Nuevo servicio';

  @override
  String get servicesPrice => 'Precio';

  @override
  String get servicesTitle => 'Servicios';

  @override
  String get settingsBillingReports => 'Facturación e informes';

  @override
  String get settingsFrontCamera => 'Escanear con la cámara frontal';

  @override
  String get settingsFrontCameraDesc =>
      'Las tarjetas se leen con la cámara del lado de la pantalla — desactívalo para usar la cámara trasera.';

  @override
  String get settingsSectionAccount => 'Mi cuenta';

  @override
  String get settingsSectionAdministration => 'Administración';

  @override
  String get settingsSectionAdvanced => 'Avanzado';

  @override
  String get settingsSectionGovernance => 'Gobernanza';

  @override
  String get settingsSectionHelpAbout => 'Ayuda y acerca de';

  @override
  String get settingsSectionMembership => 'Mi membresía';

  @override
  String get settingsSectionWorkspace => 'Este espacio';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settlementAction => 'Agrupar en una factura';

  @override
  String get settlementAnnexAlone => 'Solo esta factura';

  @override
  String settlementAnnexBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Las $count facturas que esta sustituye pueden seguirla, cada una en sus propias páginas y sellada como reagrupada.',
      one: 'La factura que esta sustituye puede seguirla, en sus propias páginas y sellada como reagrupada.',
    );
    return '$_temp0';
  }

  @override
  String get settlementAnnexTitle => '¿Adjuntar las facturas reagrupadas?';

  @override
  String get settlementAnnexWith => 'Adjuntarlas';

  @override
  String settlementConfirm(int count, String amount) {
    return '¿Agrupar $count facturas en una de $amount?';
  }

  @override
  String get settlementDocumentationOnly =>
      'Solo documentación: toda operación se hace en la factura de reagrupación.';

  @override
  String settlementDone(String number) {
    return 'Agrupadas en $number.';
  }

  @override
  String settlementFoldedIn(String number) {
    return 'Reagrupada en $number';
  }

  @override
  String get settlementNeedsTwo =>
      'Elige al menos dos facturas abiertas del mismo miembro.';

  @override
  String settlementPaidThrough(String number) {
    return 'Pagada a través de $number';
  }

  @override
  String get settlementRegroups => 'Esta factura agrupa';

  @override
  String settlementRegroupsNumbers(String numbers) {
    return 'Reagrupa $numbers';
  }

  @override
  String get settlementSettledBy =>
      'Agrupada en otra factura: esa es la que se debe y se reclama.';

  @override
  String get settlementSourcePdf => 'PDF (reagrupada)';

  @override
  String get settlementStepPick => 'Elegir facturas';

  @override
  String get settlementSummaryHint =>
      'Estas facturas se agrupan en un documento de liquidación; cada una sigue legible detrás.';

  @override
  String get settlementVatNote =>
      'Las líneas y su IVA se toman de las facturas reagrupadas; la declaración de IVA cuenta las originales una sola vez.';

  @override
  String get shellBarHiddenAnnounce => 'Barra de navegación oculta';

  @override
  String get shellBarHideHint =>
      'Mantén pulsado para la vista de pantalla completa';

  @override
  String get shellBarShowHint =>
      'Mantén pulsado para mostrar la barra de navegación';

  @override
  String get shellBarShownAnnounce => 'Barra de navegación visible';

  @override
  String shellPendingDecisions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count decisiones te esperan',
      one: '1 decisión te espera',
    );
    return '$_temp0';
  }

  @override
  String get shellReserveButton => 'Reservar';

  @override
  String get shellSwipeCoachMark =>
      'Desliza la barra hacia abajo para la vista de pantalla completa. Desliza hacia arriba, o mantén pulsado el botón Reservar, para recuperarla.';

  @override
  String get siteCity => 'Ciudad';

  @override
  String get siteCountry => 'País (código)';

  @override
  String get siteDelete => 'Eliminar esta sede';

  @override
  String get siteDeleteHint =>
      'Sus plantas y socios vuelven a la sede por defecto.';

  @override
  String get siteExemptionReason => 'Mención de exención (esta entidad)';

  @override
  String get siteLegalId => 'Registro del establecimiento';

  @override
  String get siteName => 'Nombre de la sede';

  @override
  String get sitePostalCode => 'Código postal';

  @override
  String get siteRegistrationHint =>
      'Solo si la sede es una entidad jurídica distinta — normalmente eso es un espacio aparte. Vacío: se aplican los números del espacio.';

  @override
  String get siteSaved => 'Sede guardada.';

  @override
  String get siteStreet => 'Calle';

  @override
  String get siteVatId => 'Número de IVA (esta entidad)';

  @override
  String get sitesAdd => 'Añadir una sede';

  @override
  String get sitesDefault => 'Sede por defecto';

  @override
  String get sitesIntro =>
      'Cada planta pertenece a una sede; la sede por defecto lleva la dirección del espacio. Un socio tiene una sede de referencia: es la dirección de sus documentos.';

  @override
  String get sitesLevels => 'Plantas';

  @override
  String get sitesSubtitle =>
      'Direcciones, las plantas de cada una y la sede de cada socio';

  @override
  String get sitesTitle => 'Sedes';

  @override
  String get spaceAlreadyCheckedInHere =>
      'Ya ha fichado aquí. Elija « Fichar la salida » para dejar la plaza.';

  @override
  String get spaceBackToMe => 'Volver a Yo';

  @override
  String get spaceBlockedByYou => 'Ya tiene este espacio para ese periodo.';

  @override
  String get spaceCardInfoLabel => 'Información en la tarjeta';

  @override
  String get spaceCardInfoWorkspace => 'Espacio de trabajo';

  @override
  String get spaceCardSizeLabel => 'Tamaño de la tarjeta';

  @override
  String get spaceCardSizeLarge => 'Grande';

  @override
  String get spaceCardSizeMedium => 'Mediana';

  @override
  String get spaceCardSizeSmall => 'Pequeña';

  @override
  String get spaceChipTooltip => 'Cambiar de espacio';

  @override
  String get spaceCodesDesc =>
      'Una tarjeta QR imprimible por puesto, mesa, oficina y planta — los miembros la escanean para reservar o fichar.';

  @override
  String get spaceCodesTitle => 'Códigos QR de espacios (PDF)';

  @override
  String get spaceFavoriteAdd => 'Añadir a favoritos';

  @override
  String get spaceFavoriteRemove => 'Quitar de favoritos';

  @override
  String get spaceKindDesk => 'Mesa';

  @override
  String get spaceKindLevel => 'Planta';

  @override
  String get spaceKindOffice => 'Oficina';

  @override
  String get spaceKindSeat => 'Puesto';

  @override
  String get spaceManageMyBooking => 'Gestionar mi reserva';

  @override
  String spaceMessageReserver(String name) {
    return 'Escribir a $name';
  }

  @override
  String get spaceMoveDown => 'Bajar';

  @override
  String get spaceMoveUp => 'Subir';

  @override
  String get spaceNotBookable =>
      'Este espacio no está configurado para reservas completas.';

  @override
  String get spaceNotWholeBookable =>
      'Este espacio no está configurado para reserva completa — el propietario activa \"Reservable como un todo\" en el editor.';

  @override
  String spaceOptions(String name) {
    return 'Opciones de $name';
  }

  @override
  String get spaceQrSizeLabel => 'Tamaño del código QR';

  @override
  String get spaceRatingClear => 'Sin valoración';

  @override
  String get spaceScanField => 'Código';

  @override
  String get spaceScanHint =>
      'Apunta la cámara a la tarjeta de un puesto, mesa, oficina o planta — o escribe su código.';

  @override
  String get spaceScanInvalid =>
      'No es un código de espacio de este espacio de trabajo.';

  @override
  String get spaceScanNfcHint =>
      '…o acerca el teléfono a la etiqueta NFC de una silla.';

  @override
  String get spaceScanTitle => 'Escanear un código de espacio';

  @override
  String get spaceScanUnknown =>
      'Este código ya no corresponde a ningún espacio aquí.';

  @override
  String get spaceScanUnknownTag =>
      'Esta etiqueta no está vinculada a ninguna silla.';

  @override
  String get spaceSeatTaken => 'Ocupado';

  @override
  String get spaceYoursCheckedIn =>
      'Ha registrado su entrada aquí para esta franja.';

  @override
  String get spaceYoursNow => 'Reservado por ti para esta franja.';

  @override
  String get statusAwaiting => 'Pendiente';

  @override
  String get statusCreditNotes => 'Abonos';

  @override
  String get statusCredits => 'Créditos concedidos';

  @override
  String get statusFrom => 'Desde';

  @override
  String get statusInvoiced => 'Facturado';

  @override
  String get statusMembers => 'Socios';

  @override
  String get statusNet => 'Neto';

  @override
  String get statusNetExplanation =>
      'Este subtotal son importes facturados menos abonos, reembolsos y créditos. No es un beneficio ni un saldo bancario. Los pagos conciliados y recibidos se solapan y no deben sumarse.';

  @override
  String get statusPaymentsMatched => 'Pagos conciliados';

  @override
  String get statusPaymentsReceived => 'Pagos recibidos';

  @override
  String get statusPrint => 'Imprimir la situación';

  @override
  String get statusReimbursed => 'Gastos reembolsados';

  @override
  String get statusRepartitioned => 'Gastos repartidos';

  @override
  String get statusSubtitle => 'Ingresos, gastos y socios en un periodo';

  @override
  String get statusTitle => 'Situación del espacio';

  @override
  String get statusTo => 'Hasta';

  @override
  String get subprocessAttendance => 'Asistencia y uso';

  @override
  String get subprocessAttendanceDesc =>
      'Registrar asistencia y cerrar entradas al final del día.';

  @override
  String get subprocessAvailability => 'Días y horarios de apertura';

  @override
  String get subprocessAvailabilityDesc =>
      'Definir horarios y generar días de cierre.';

  @override
  String get subprocessCalendar => 'Vistas del calendario';

  @override
  String get subprocessCalendarDesc =>
      'Ver reservas y decisiones pendientes a lo largo del tiempo.';

  @override
  String get subprocessCollection => 'Cobro de pagos';

  @override
  String get subprocessCollectionDesc =>
      'Cobrar pagos y reclamar facturas vencidas.';

  @override
  String get subprocessCommunication => 'Comunicación entre miembros';

  @override
  String get subprocessCommunicationDesc =>
      'Intercambiar mensajes y seguir las novedades.';

  @override
  String get subprocessConfiguration => 'Configuración y despliegue';

  @override
  String get subprocessConfigurationDesc =>
      'Transferir configuraciones, usar plantillas y gestionar instancias.';

  @override
  String get subprocessDecisions => 'Decisiones y aprobaciones';

  @override
  String get subprocessDecisionsDesc =>
      'Revisar acciones y registrar las aprobaciones necesarias.';

  @override
  String get subprocessDelivery => 'Envío externo';

  @override
  String get subprocessDeliveryDesc =>
      'Conectar notificaciones push, WhatsApp y envío de facturas electrónicas.';

  @override
  String get subprocessDocuments => 'Publicación de documentos';

  @override
  String get subprocessDocumentsDesc =>
      'Publicar documentos y generar archivos imprimibles.';

  @override
  String get subprocessExpenses => 'Gastos compartidos';

  @override
  String get subprocessExpensesDesc =>
      'Repartir costes, reponer suministros y programar gastos recurrentes.';

  @override
  String get subprocessExperience => 'Uso de la aplicación';

  @override
  String get subprocessExperienceDesc =>
      'Ajustar ayuda, navegación y preferencias de visualización.';

  @override
  String get subprocessInvoicing => 'Facturación';

  @override
  String get subprocessInvoicingDesc =>
      'Emitir y seguir facturas inmutables hasta su liquidación.';

  @override
  String get subprocessPeople => 'Personas y membresías';

  @override
  String get subprocessPeopleDesc =>
      'Identificar miembros y gestionar sus membresías y permisos.';

  @override
  String get subprocessPhysicalAccess => 'Acceso físico';

  @override
  String get subprocessPhysicalAccessDesc =>
      'Usar credenciales, etiquetas de puestos y el quiosco compartido.';

  @override
  String get subprocessPresentation => 'Presentación del espacio';

  @override
  String get subprocessPresentationDesc =>
      'Ayudar a reconocer personas y lugares en el plano.';

  @override
  String get subprocessPricing => 'Servicios y precios';

  @override
  String get subprocessPricingDesc =>
      'Fijar precios de servicios y accesorios y acordar condiciones.';

  @override
  String get subprocessPrivacy => 'Acceso a datos y exportaciones';

  @override
  String get subprocessPrivacyDesc =>
      'Consultar accesos a datos personales y exportar registros.';

  @override
  String get subprocessRecords => 'Registros financieros';

  @override
  String get subprocessRecordsDesc =>
      'Comprender saldos, pagos y extractos de los miembros.';

  @override
  String get subprocessReportDesign => 'Diseño de informes';

  @override
  String get subprocessReportDesignDesc =>
      'Diseñar informes y mantener sus textos y diseños.';

  @override
  String get subprocessReservations => 'Reservar puestos y espacios';

  @override
  String get subprocessReservationsDesc =>
      'Reservar puestos o espacios completos según las reglas.';

  @override
  String get subprocessStructure => 'Estructura del espacio';

  @override
  String get subprocessStructureDesc =>
      'Gestionar sedes y disponibilidad de elementos del plano.';

  @override
  String get subprocessTax => 'Gestión del IVA';

  @override
  String get subprocessTaxDesc =>
      'Gestionar grupos, tipos y declaraciones de IVA.';

  @override
  String get supportChanged =>
      'El contexto cambió. Prepare una nueva vista previa.';

  @override
  String get supportDay => 'Últimas 24 horas';

  @override
  String get supportDemo => 'Demo: contexto local simulado';

  @override
  String get supportFailed =>
      'No se pudieron preparar los detalles. Inténtelo de nuevo.';

  @override
  String get supportHour => 'Última hora';

  @override
  String get supportPrepare => 'Preparar vista previa';

  @override
  String get supportPrivacy =>
      'Solo se incluyen recuentos limitados de este dispositivo y comprobaciones conocidas. Se excluyen identidades, direcciones del servidor, credenciales, datos comerciales y registros sin procesar. Las comprobaciones desconocidas no están disponibles; un operador puede ejecutar doctor --support-json por separado. Los archivos compartidos no se pueden revocar.';

  @override
  String get supportSaved => 'Guardado localmente';

  @override
  String supportSize(int bytes) {
    final intl.NumberFormat bytesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String bytesString = bytesNumberFormat.format(bytes);

    return 'Vista previa: $bytesString bytes';
  }

  @override
  String get supportTitle => 'Detalles de soporte';

  @override
  String get symbolHint =>
      'Una marca redonda de una o dos letras sobre un color, única de este espacio — o use una foto abajo.';

  @override
  String get symbolLetters => 'Letras';

  @override
  String get symbolLettersRule =>
      'Use una o dos letras o dígitos para el símbolo.';

  @override
  String get symbolSaveFailed =>
      'No se pudo guardar el símbolo. No cambió nada.';

  @override
  String get symbolSaved => 'Símbolo guardado.';

  @override
  String get symbolTaken =>
      'Otro espacio ya usa estas letras en este color. Elija otro color u otras letras — o use una foto.';

  @override
  String get symbolTitle => 'Símbolo';

  @override
  String get tabCalendar => 'Calendario';

  @override
  String get tabEvents => 'Eventos';

  @override
  String get tabMoney => 'Finanzas';

  @override
  String get tabPlan => 'Plano';

  @override
  String get taskExportActionBack => 'Vuelva atrás.';

  @override
  String get taskExportActionCancelReview =>
      'Cancele la revisión sin reservar.';

  @override
  String taskExportActionChangeField(String field) {
    return 'Cambie el campo: $field.';
  }

  @override
  String get taskExportActionConfirmBooking => 'Confirme la reserva.';

  @override
  String get taskExportActionOpenReserve => 'Abra la pantalla Reservar.';

  @override
  String get taskExportActionSelectDate => 'Elija la fecha.';

  @override
  String get taskExportActionSelectPeriod => 'Elija el periodo.';

  @override
  String get taskExportActionSelectResource => 'Elija un puesto.';

  @override
  String get taskExportActionSwitchView => 'Cambie la vista.';

  @override
  String get taskExportActionUnknown =>
      'Una acción que esta versión no puede describir.';

  @override
  String get taskExportActionViewDetails => 'Abra el detalle de la reserva.';

  @override
  String get taskExportAuthored =>
      'Añadido al editar: no observado por la grabadora.';

  @override
  String get taskExportCompletenessComplete =>
      'Completa: la persona detuvo la grabación y cada orden recibió respuesta.';

  @override
  String get taskExportCompletenessInterrupted =>
      'Interrumpida: la aplicación se detuvo durante la grabación.';

  @override
  String get taskExportCompletenessPartial =>
      'Parcial: la grabación terminó antes de tiempo o una orden no recibió respuesta.';

  @override
  String taskExportDetail(String field, String value) {
    return '$field: $value';
  }

  @override
  String get taskExportDocFallbackTitle => 'Procedimiento de tarea';

  @override
  String taskExportDuration(int minutes, int seconds) {
    return 'Duración: $minutes min $seconds s';
  }

  @override
  String get taskExportEndInterrupted =>
      'Detenida porque la aplicación se cerró.';

  @override
  String get taskExportEndLimitReached =>
      'Detenida porque se alcanzó un límite de pasos, tamaño o duración.';

  @override
  String get taskExportEndScopeChanged =>
      'Detenida porque cambió la cuenta, el espacio o la instalación.';

  @override
  String get taskExportEndStopped => 'Detenida por la persona que la grabó.';

  @override
  String get taskExportEndStorageFailed =>
      'Detenida porque falló la escritura de la grabación.';

  @override
  String taskExportExcluded(String category) {
    return 'Se visitó una pantalla protegida ($category); no se grabó nada de ella.';
  }

  @override
  String get taskExportFieldAccessories => 'Accesorios';

  @override
  String get taskExportFieldCheckIn => 'Registro de llegada';

  @override
  String get taskExportFieldDateRelation => 'Fecha';

  @override
  String get taskExportFieldForWhom => 'Para quién';

  @override
  String get taskExportFieldPeriod => 'Periodo';

  @override
  String get taskExportFieldRefusal => 'Motivo';

  @override
  String get taskExportFieldRepeat => 'Repetición';

  @override
  String get taskExportFieldResourceKind => 'Tipo de puesto';

  @override
  String get taskExportFieldSeriesResult => 'Serie';

  @override
  String get taskExportFieldTime => 'Hora';

  @override
  String get taskExportFieldUnknown =>
      'un campo que esta versión no puede describir';

  @override
  String get taskExportFieldViewMode => 'Vista';

  @override
  String taskExportFooter(String page, String pages) {
    return 'Página $page de $pages';
  }

  @override
  String get taskExportIllustrationNotApproved =>
      'Ilustración no incluida: no se aprobó.';

  @override
  String get taskExportIncludeIllustrations =>
      'Incluir las ilustraciones aprobadas';

  @override
  String get taskExportIntro =>
      'Este documento describe, paso a paso, una tarea grabada en DesKilo. Es documentación: no reproduce la tarea ni demuestra que haya salido bien. Solo lo que la grabación observó se presenta como observado.';

  @override
  String get taskExportKindEdited =>
      'Procedimiento editado: derivado de una grabación y modificado por una persona.';

  @override
  String get taskExportKindSource =>
      'Captura original: los pasos fueron observados por la grabadora.';

  @override
  String get taskExportLimitEdited =>
      'Los pasos marcados como añadidos al editar los escribió una persona; no se observaron.';

  @override
  String get taskExportLimitIncomplete =>
      'La grabación está incompleta: no se sabe qué ocurrió después del último paso mostrado.';

  @override
  String get taskExportLimitNoIllustrations =>
      'Este documento no tiene ilustraciones.';

  @override
  String get taskExportLimitNotRunnable =>
      'Algunos pasos proceden de una versión más reciente y no pueden describirse aquí.';

  @override
  String get taskExportLimitRecreated =>
      'Las ilustraciones se recrean a partir de los datos seguros de la grabación, con nombres de puestos inventados; no son capturas de la pantalla.';

  @override
  String get taskExportLimitValues =>
      'Los valores escritos o elegidos nunca se graban: solo aparece su tipo, y «no grabado» sustituye a todo lo demás.';

  @override
  String get taskExportNoResult =>
      'No se grabó ningún resultado para esta orden.';

  @override
  String taskExportNote(String note) {
    return 'Nota escrita por la persona que grabó (sus propias palabras): $note';
  }

  @override
  String get taskExportNoteOmitted =>
      'Se omitió una nota personal en este documento.';

  @override
  String taskExportOnScreen(String screen) {
    return 'Pantalla: $screen';
  }

  @override
  String get taskExportOutcomeConfirmed => 'la reserva se confirmó';

  @override
  String get taskExportOutcomeRefused => 'la reserva se rechazó';

  @override
  String get taskExportOutcomeRequested =>
      'la reserva se solicitó y espera una decisión';

  @override
  String get taskExportOutcomeSeriesBooked => 'la serie se reservó';

  @override
  String get taskExportOutcomeUnknown =>
      'no se pudo confirmar ninguna respuesta; el resultado es desconocido';

  @override
  String get taskExportOutcomeUnregistered =>
      'un resultado que esta versión no puede describir';

  @override
  String taskExportPauses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pausas',
      one: 'Una pausa',
      zero: 'Sin pausas',
    );
    return '$_temp0';
  }

  @override
  String taskExportPlatform(String platform) {
    return 'Grabada en: $platform';
  }

  @override
  String get taskExportPrereqBookablePlace =>
      'Se puede reservar al menos un puesto.';

  @override
  String get taskExportPrereqSignedIn => 'Ha iniciado sesión.';

  @override
  String taskExportPrereqStartsOn(String screen) {
    return 'Empiece en $screen.';
  }

  @override
  String get taskExportPrereqUnknown =>
      'Una condición que esta versión no puede describir.';

  @override
  String get taskExportPrereqWorkspaceMember => 'Es miembro del espacio.';

  @override
  String get taskExportProtectedAuthentication => 'inicio de sesión';

  @override
  String get taskExportProtectedIdentity => 'identidad';

  @override
  String get taskExportProtectedMessenger => 'mensajes';

  @override
  String get taskExportProtectedOperator => 'operador';

  @override
  String get taskExportProtectedPayment => 'pago';

  @override
  String get taskExportProtectedProvider => 'proveedor';

  @override
  String get taskExportProtectedSecrets => 'secretos';

  @override
  String get taskExportRefused =>
      'Esta grabación no se puede exportar como documento de Word.';

  @override
  String taskExportResult(String outcome) {
    return 'Resultado: $outcome';
  }

  @override
  String taskExportRevision(String revision) {
    return 'Revisión del contenido: $revision';
  }

  @override
  String get taskExportSaveFailed =>
      'No se pudo guardar el documento de Word. La grabación no ha cambiado.';

  @override
  String taskExportSaved(String file) {
    return 'Documento de Word guardado: $file';
  }

  @override
  String taskExportSceneAlt(String screen, String step) {
    return 'Ilustración: $screen – $step';
  }

  @override
  String get taskExportSceneBookingTitle => 'Reservar un puesto';

  @override
  String get taskExportSceneCancel => 'Cancelar';

  @override
  String get taskExportSceneConfirm => 'Confirmar';

  @override
  String get taskExportSceneDetailTitle => 'Reserva';

  @override
  String get taskExportSceneLater => 'Más adelante';

  @override
  String get taskExportSceneProvenance =>
      'Ilustración recreada a partir de la grabación, no una captura de pantalla';

  @override
  String get taskExportSectionAbout => 'Acerca de esta grabación';

  @override
  String get taskExportSectionBefore => 'Antes de empezar';

  @override
  String get taskExportSectionLimits => 'Limitaciones';

  @override
  String get taskExportSectionSteps => 'Pasos';

  @override
  String get taskExportStale =>
      'El guion gráfico corresponde a otra versión de esta grabación. Revíselo antes de exportar.';

  @override
  String get taskExportStoryboardApprove => 'Aprobar la ilustración';

  @override
  String get taskExportStoryboardGap => 'Hueco: aquí no se grabó nada';

  @override
  String get taskExportStoryboardInclude => 'Incluir';

  @override
  String get taskExportStoryboardLeftOut => 'Paso omitido en la revisión.';

  @override
  String get taskExportStoryboardMoveDown => 'Bajar';

  @override
  String get taskExportStoryboardMoveUp => 'Subir';

  @override
  String get taskExportStoryboardOrderRefused =>
      'Un resultado no puede ir antes de la orden a la que responde.';

  @override
  String get taskExportStoryboardRenderFailed =>
      'No se pudo dibujar la ilustración; este paso queda como texto.';

  @override
  String get taskExportStoryboardSourceExcluded =>
      'Pantalla protegida: sin ilustración';

  @override
  String get taskExportStoryboardSourceScene =>
      'Ilustración recreada (no es una captura)';

  @override
  String get taskExportStoryboardSourceText => 'Diapositiva de texto';

  @override
  String get taskExportSurfaceAny => 'cualquier pantalla';

  @override
  String get taskExportSurfaceBookingSheet => 'la hoja de reserva';

  @override
  String get taskExportSurfaceReservationDetail => 'el detalle de la reserva';

  @override
  String get taskExportSurfaceReserve => 'la pantalla Reservar';

  @override
  String get taskExportSurfaceUnknown =>
      'una pantalla que esta versión no puede describir';

  @override
  String get taskExportUnrecorded =>
      'Un paso que esta versión no puede describir.';

  @override
  String get taskExportValueAfternoon => 'tarde';

  @override
  String get taskExportValueAllBooked => 'todo reservado';

  @override
  String get taskExportValueClosed => 'el espacio estaba cerrado';

  @override
  String get taskExportValueConflict => 'el puesto ya estaba ocupado';

  @override
  String get taskExportValueCustom => 'personalizado';

  @override
  String get taskExportValueDesk => 'un escritorio';

  @override
  String get taskExportValueFullDay => 'día completo';

  @override
  String get taskExportValueHours => 'por horas';

  @override
  String get taskExportValueLater => 'más adelante';

  @override
  String get taskExportValueLaterThisWeek => 'más adelante esta semana';

  @override
  String get taskExportValueList => 'lista';

  @override
  String get taskExportValueMorning => 'mañana';

  @override
  String get taskExportValueNo => 'no';

  @override
  String get taskExportValueOff => 'desactivado';

  @override
  String get taskExportValueOffline => 'sin conexión';

  @override
  String get taskExportValueOn => 'activado';

  @override
  String get taskExportValueOnce => 'una vez';

  @override
  String get taskExportValueOtherMember => 'otro miembro';

  @override
  String get taskExportValueOtherPlace => 'otro tipo de puesto';

  @override
  String get taskExportValueOtherReason => 'otro motivo';

  @override
  String get taskExportValuePartiallyBooked => 'reservado en parte';

  @override
  String get taskExportValuePast => 'un día pasado';

  @override
  String get taskExportValuePermission => 'falta un permiso';

  @override
  String get taskExportValuePlan => 'plano';

  @override
  String get taskExportValuePolicy => 'una regla de reserva';

  @override
  String get taskExportValueQuota => 'una cuota';

  @override
  String taskExportValueRedacted(int length) {
    return 'no guardado ($length caracteres)';
  }

  @override
  String get taskExportValueRoom => 'una sala';

  @override
  String get taskExportValueSelf => 'yo';

  @override
  String get taskExportValueSeries => 'como serie';

  @override
  String get taskExportValueToday => 'hoy';

  @override
  String get taskExportValueTomorrow => 'mañana';

  @override
  String get taskExportValueWithheld => 'no grabado';

  @override
  String get taskExportValueYes => 'sí';

  @override
  String taskExportVersion(int schema, int contract) {
    return 'Formato de grabación $schema, contrato de acciones $contract';
  }

  @override
  String get taskExportWordButton => 'Exportar como documento de Word';

  @override
  String get taskGuideCreate => 'Crear un borrador de guía';

  @override
  String get taskGuideEditText => 'Escribir el texto';

  @override
  String get taskGuideIntro =>
      'Cada paso tal como lo seguirá un lector. Un paso que reserva espera la respuesta real; nada se hace por el lector.';

  @override
  String get taskGuideManual => 'Haga este paso usted mismo';

  @override
  String taskGuideManualProtected(String category) {
    return 'Haga este paso usted mismo, en una pantalla protegida: $category';
  }

  @override
  String get taskGuideNoText => 'Una instrucción aún por escribir';

  @override
  String get taskGuideOptional => 'El lector puede omitirlo';

  @override
  String get taskGuideRecovery =>
      'Si se rechaza: elija otro sitio, día o periodo y confirme de nuevo.';

  @override
  String get taskGuideSave => 'Guardar la guía';

  @override
  String get taskGuideTitle => 'Borrador de guía';

  @override
  String taskGuideWaitsFor(String outcomes) {
    return 'Espera: $outcomes';
  }

  @override
  String get taskOutputBusy => 'Este resultado ya se está creando.';

  @override
  String get taskOutputDocument => 'Documento de Word';

  @override
  String get taskOutputFailed => 'No se pudo crear el resultado.';

  @override
  String get taskOutputMake => 'Crear';

  @override
  String get taskOutputMissingMedia => 'Esta tarea no tiene imágenes que usar.';

  @override
  String get taskOutputStale =>
      'Las ilustraciones se revisaron para una versión anterior.';

  @override
  String get taskOutputStoryboard => 'Guion gráfico';

  @override
  String get taskOutputTooLong =>
      'Esta tarea es demasiado larga para este formato.';

  @override
  String get taskOutputUnsupportedPlatform =>
      'No disponible en este dispositivo.';

  @override
  String get taskRecorderActionBack => 'Volvió atrás';

  @override
  String get taskRecorderActionCalendarCancel =>
      'Canceló una reserva desde el calendario';

  @override
  String get taskRecorderActionCalendarFilterKind =>
      'Cambió lo que muestra el calendario';

  @override
  String get taskRecorderActionCalendarMove => 'Se movió por las fechas';

  @override
  String get taskRecorderActionCalendarOpenItem =>
      'Abrió una entrada del calendario';

  @override
  String get taskRecorderActionCalendarSelectDay =>
      'Eligió un día en el calendario';

  @override
  String get taskRecorderActionCalendarView => 'Cambió la vista del calendario';

  @override
  String get taskRecorderActionCalendarWhose =>
      'Eligió de quién ver el calendario';

  @override
  String get taskRecorderActionCancelReservation => 'Canceló la reserva';

  @override
  String get taskRecorderActionCancelReview => 'Cerró la reserva sin reservar';

  @override
  String get taskRecorderActionCancelRoleEdit => 'Cerró el rol sin guardar';

  @override
  String get taskRecorderActionCancelValidationRule =>
      'Cerró la regla sin guardar';

  @override
  String get taskRecorderActionChangeField => 'Cambió un detalle de la reserva';

  @override
  String get taskRecorderActionCheckIn => 'Registró su llegada';

  @override
  String get taskRecorderActionCheckOut => 'Registró su salida';

  @override
  String get taskRecorderActionCloseMyReservation =>
      'Cerró su reserva sin cambiarla';

  @override
  String get taskRecorderActionConfirmBooking => 'Confirmó la reserva';

  @override
  String get taskRecorderActionDecideEvent =>
      'Respondió a una solicitud de decisión';

  @override
  String get taskRecorderActionDeclineOptIn =>
      'No activó una función en prueba';

  @override
  String get taskRecorderActionGiveRole => 'Asignó o retiró un rol';

  @override
  String get taskRecorderActionOpenReserve => 'Abrió Reservar';

  @override
  String get taskRecorderActionOpenRoleMatrix => 'Abrió la matriz de roles';

  @override
  String get taskRecorderActionOpenSpaceRoles =>
      'Abrió los roles de este espacio';

  @override
  String get taskRecorderActionOpenValidationRules =>
      'Abrió las reglas de validación';

  @override
  String get taskRecorderActionOpenWhatYouCanDo => 'Abrió lo que puedes hacer';

  @override
  String get taskRecorderActionSaveRole => 'Guardó un rol';

  @override
  String get taskRecorderActionSaveValidationRule =>
      'Guardó una regla de validación';

  @override
  String get taskRecorderActionSelectDate => 'Eligió el día';

  @override
  String get taskRecorderActionSelectLevel => 'Eligió un nivel';

  @override
  String get taskRecorderActionSelectPeriod => 'Eligió el periodo';

  @override
  String get taskRecorderActionSelectResource => 'Eligió un sitio';

  @override
  String get taskRecorderActionSwitchFeature => 'Cambió una función';

  @override
  String get taskRecorderActionSwitchView => 'Cambió la vista';

  @override
  String get taskRecorderActionTogglePermission => 'Cambió un permiso';

  @override
  String get taskRecorderActionUiCloseWindow => 'Cerró una ventana';

  @override
  String get taskRecorderActionUiCommand => 'Ejecutó una orden';

  @override
  String get taskRecorderActionUiCommitField => 'Rellenó un campo';

  @override
  String get taskRecorderActionUiOpenScreen => 'Abrió una pantalla';

  @override
  String get taskRecorderActionUiOpenWindow => 'Abrió una ventana';

  @override
  String get taskRecorderActionUiTap => 'Tocó';

  @override
  String get taskRecorderActionViewDetails => 'Abrió la reserva';

  @override
  String get taskRecorderAddNote => 'Añadir una nota';

  @override
  String get taskRecorderCaptureValues =>
      'Capturar valores (para informes de problemas)';

  @override
  String get taskRecorderCaptureValuesHint =>
      'También guarda lo que escribes y eliges — texto, números, fechas, interruptores — para que un desarrollador pueda reproducir el problema con el archivo. Nunca se guardan contraseñas, datos de pago, correos electrónicos, teléfonos ni otros datos de contacto personales. Comparte el archivo solo con quien deba ver lo que introdujiste.';

  @override
  String get taskRecorderCompletenessComplete => 'Completa';

  @override
  String get taskRecorderCompletenessInterrupted => 'Interrumpida';

  @override
  String get taskRecorderCompletenessPartial => 'Parcial';

  @override
  String get taskRecorderDelete => 'Borrar de este dispositivo';

  @override
  String get taskRecorderDeleteConfirm =>
      '¿Borrar esta grabación de este dispositivo? Los archivos exportados no se ven afectados y nada cambia en el espacio.';

  @override
  String get taskRecorderDiscard => 'Descartar';

  @override
  String get taskRecorderDisclosureBody =>
      'El grabador anota los pasos que da en las pantallas de este espacio — qué pantalla, qué acción, qué respondió la aplicación — solo en este dispositivo. Nunca guarda lo que escribe, ni nombres, importes, mensajes, códigos o contraseñas. El inicio de sesión, el pago, los mensajes y otras pantallas protegidas solo dejan una marca. No se envía nada: usted decide qué exportar.';

  @override
  String get taskRecorderDisclosureTitle => 'Antes de grabar';

  @override
  String taskRecorderEditedNote(int count) {
    return 'Copia editada: $count pasos excluidos. La grabación en este dispositivo no cambia.';
  }

  @override
  String get taskRecorderEndInterrupted =>
      'Interrumpida: la aplicación se detuvo mientras grababa';

  @override
  String get taskRecorderEndLimitReached => 'Terminada: se alcanzó un límite';

  @override
  String get taskRecorderEndScopeChanged =>
      'Terminada: cambió la cuenta o el espacio';

  @override
  String get taskRecorderEndStopped => 'Detenida por usted';

  @override
  String get taskRecorderEndStorageFailed =>
      'Terminada: no se pudo guardar en este dispositivo';

  @override
  String get taskRecorderExport => 'Exportar un archivo';

  @override
  String get taskRecorderExportPackage => 'Exportar un paquete de tarea';

  @override
  String get taskRecorderExportPreview => 'Lo que contendrá el archivo';

  @override
  String get taskRecorderExportValuesBody =>
      'Contiene lo que se escribió y eligió durante la grabación. Revísala antes de compartirla y compártela solo con quien deba verlo.';

  @override
  String get taskRecorderExportValuesConfirm => 'Guardar de todos modos';

  @override
  String get taskRecorderExportValuesTitle => 'Esta grabación contiene valores';

  @override
  String get taskRecorderFieldAccessories => 'accesorios';

  @override
  String get taskRecorderFieldCheckIn => 'registro de llegada';

  @override
  String get taskRecorderFieldForWhom => 'para quién';

  @override
  String get taskRecorderFieldRepeat => 'repetición';

  @override
  String get taskRecorderFieldTime => 'horario';

  @override
  String taskRecorderIndicator(int count) {
    return 'Grabando una tarea: $count pasos';
  }

  @override
  String get taskRecorderLeaveOut => 'Dejar fuera de la exportación';

  @override
  String taskRecorderLimits(int steps, int minutes, int days) {
    return 'Hasta $steps pasos o $minutes minutos por grabación. Las grabaciones se borran de este dispositivo después de $days días; un archivo exportado es suyo y se queda donde lo guardó.';
  }

  @override
  String get taskRecorderMyRecordings => 'Mis grabaciones en este dispositivo';

  @override
  String get taskRecorderNoOutcome => 'Ninguna respuesta grabada';

  @override
  String get taskRecorderNoRecordings =>
      'No hay grabaciones en este dispositivo.';

  @override
  String get taskRecorderNoteHint =>
      'Sus propias palabras, guardadas tal como las escribe';

  @override
  String get taskRecorderOpenRecorder => 'Abrir el grabador de tareas';

  @override
  String get taskRecorderOutcomeCancelled => 'Cancelada';

  @override
  String get taskRecorderOutcomeCheckedIn => 'Llegada registrada';

  @override
  String get taskRecorderOutcomeCheckedOut => 'Salida registrada';

  @override
  String get taskRecorderOutcomeCommandDone => 'Hecho';

  @override
  String get taskRecorderOutcomeCommandPending => 'Enviado para validación';

  @override
  String get taskRecorderOutcomeConfirmed => 'Reservado';

  @override
  String get taskRecorderOutcomeEventDecided => 'Respuesta registrada';

  @override
  String get taskRecorderOutcomeEventNotConfirmed =>
      'La respuesta no se confirmó';

  @override
  String get taskRecorderOutcomeRefused => 'Rechazado';

  @override
  String get taskRecorderOutcomeRequested => 'Enviado para confirmación';

  @override
  String get taskRecorderOutcomeSeries => 'Serie reservada';

  @override
  String get taskRecorderOutcomeSettingNotSaved => 'No guardado';

  @override
  String get taskRecorderOutcomeSettingPending => 'Enviado para validación';

  @override
  String get taskRecorderOutcomeSettingSaved => 'Guardado';

  @override
  String get taskRecorderOutcomeUnknown => 'No llegó ninguna respuesta';

  @override
  String get taskRecorderPause => 'Pausar';

  @override
  String get taskRecorderPaused => 'En pausa';

  @override
  String get taskRecorderProtectedAuthentication => 'inicio de sesión';

  @override
  String get taskRecorderProtectedIdentity => 'identidad';

  @override
  String get taskRecorderProtectedMessenger => 'mensajes';

  @override
  String get taskRecorderProtectedOperator => 'operador de la instalación';

  @override
  String get taskRecorderProtectedPayment => 'pago';

  @override
  String get taskRecorderProtectedProvider => 'pantalla de un proveedor';

  @override
  String get taskRecorderProtectedSecrets => 'claves y secretos';

  @override
  String get taskRecorderPutBack => 'Volver a incluir';

  @override
  String get taskRecorderRecordATask => 'Grabar una tarea';

  @override
  String get taskRecorderRecordThisTask => 'Grabar esta tarea';

  @override
  String get taskRecorderRecording => 'Grabando';

  @override
  String get taskRecorderResume => 'Reanudar';

  @override
  String get taskRecorderSaveFailed => 'No se pudo guardar el archivo.';

  @override
  String get taskRecorderSaveNoPath =>
      'El archivo se entregó a su navegador o dispositivo, que no dijo dónde quedó.';

  @override
  String taskRecorderSaved(String path) {
    return 'Guardado: $path';
  }

  @override
  String taskRecorderSavedPrivately(String path) {
    return 'Guardado solo dentro de la aplicación: $path';
  }

  @override
  String get taskRecorderSegmentGap => 'En pausa aquí';

  @override
  String get taskRecorderSignedOut => 'Inicie sesión para grabar una tarea.';

  @override
  String get taskRecorderStart => 'Empezar a grabar';

  @override
  String get taskRecorderStartFailed =>
      'La grabación no pudo empezar en este dispositivo.';

  @override
  String taskRecorderStepCount(int count) {
    return '$count pasos';
  }

  @override
  String get taskRecorderStepExcluded => 'Una pantalla protegida — no grabada';

  @override
  String get taskRecorderStepNote => 'Su nota';

  @override
  String get taskRecorderStepUnrecorded =>
      'Un paso que el grabador no puede describir';

  @override
  String get taskRecorderStop => 'Detener';

  @override
  String get taskRecorderTargetAllKinds => 'todos los tipos';

  @override
  String get taskRecorderTargetDefaultRule => 'la regla predeterminada';

  @override
  String get taskRecorderTargetUnkeyed => 'un control sin nombre';

  @override
  String get taskRecorderTitle => 'Grabador de tareas';

  @override
  String get taskRecorderUnavailable =>
      'La grabación no está activada en este espacio.';

  @override
  String get taskRecorderUnreadable =>
      'Esta grabación no se puede leer. Puede borrarla.';

  @override
  String get taskRecorderUntitled => 'Tarea sin título';

  @override
  String get taskRecorderValueAccept => 'aceptada';

  @override
  String get taskRecorderValueAfternoon => 'tarde';

  @override
  String get taskRecorderValueAgenda => 'agenda';

  @override
  String get taskRecorderValueAlert => 'un aviso';

  @override
  String get taskRecorderValueAllBooked => 'todas las fechas reservadas';

  @override
  String get taskRecorderValueCheckIn => 'con registro de llegada';

  @override
  String get taskRecorderValueClosed => 'cerrado';

  @override
  String get taskRecorderValueConflict => 'ya ocupado';

  @override
  String get taskRecorderValueConversation => 'una conversación';

  @override
  String get taskRecorderValueCreated => 'creado';

  @override
  String get taskRecorderValueCustom => 'horario propio';

  @override
  String get taskRecorderValueDay => 'día';

  @override
  String get taskRecorderValueDecision => 'una decisión';

  @override
  String get taskRecorderValueDecline => 'rechazada';

  @override
  String get taskRecorderValueDesk => 'un escritorio';

  @override
  String get taskRecorderValueEdited => 'editado';

  @override
  String get taskRecorderValueEveryone => 'el de todos';

  @override
  String get taskRecorderValueFullDay => 'día completo';

  @override
  String get taskRecorderValueHours => 'por horas';

  @override
  String get taskRecorderValueInvoice => 'una factura';

  @override
  String get taskRecorderValueLater => 'un día posterior';

  @override
  String get taskRecorderValueLaterThisWeek => 'más tarde esta semana';

  @override
  String get taskRecorderValueList => 'lista';

  @override
  String get taskRecorderValueMine => 'el mío';

  @override
  String get taskRecorderValueMonth => 'mes';

  @override
  String get taskRecorderValueMorning => 'mañana (franja)';

  @override
  String get taskRecorderValueNext => 'adelante';

  @override
  String get taskRecorderValueNoCheckIn => 'sin registro de llegada';

  @override
  String get taskRecorderValueOff => 'desactivada';

  @override
  String get taskRecorderValueOffline => 'sin conexión';

  @override
  String get taskRecorderValueOn => 'activada';

  @override
  String get taskRecorderValueOnce => 'una vez';

  @override
  String get taskRecorderValueOther => 'otro';

  @override
  String get taskRecorderValueOtherMember => 'para otro miembro';

  @override
  String get taskRecorderValuePartiallyBooked => 'algunas fechas rechazadas';

  @override
  String get taskRecorderValuePast => 'un día pasado';

  @override
  String get taskRecorderValuePayment => 'un pago';

  @override
  String get taskRecorderValuePermission => 'un permiso';

  @override
  String get taskRecorderValuePlan => 'plano';

  @override
  String get taskRecorderValuePolicy => 'una regla de reserva';

  @override
  String get taskRecorderValuePrevious => 'atrás';

  @override
  String get taskRecorderValueQuota => 'un cupo';

  @override
  String get taskRecorderValueRange => 'un intervalo de fechas';

  @override
  String get taskRecorderValueRenamed => 'renombrado';

  @override
  String get taskRecorderValueRoleAdmin => 'administradores';

  @override
  String get taskRecorderValueRoleCoOwner => 'un copropietario';

  @override
  String get taskRecorderValueRoleMember => 'cada miembro';

  @override
  String get taskRecorderValueRoleOwner => 'el propietario';

  @override
  String get taskRecorderValueRoom => 'una sala';

  @override
  String get taskRecorderValueSelf => 'para mí';

  @override
  String get taskRecorderValueSeries => 'repetida';

  @override
  String get taskRecorderValueSomeoneElse => 'el de otro miembro';

  @override
  String get taskRecorderValueTimeline => 'línea de tiempo';

  @override
  String get taskRecorderValueToday => 'hoy';

  @override
  String get taskRecorderValueTomorrow => 'mañana';

  @override
  String get taskRecorderValueWeek => 'semana';

  @override
  String get taskRecorderValueWithheld => 'no grabado';

  @override
  String get taskRecorderValuesOn => 'Se están capturando valores';

  @override
  String get taskWizardAddGuide => 'Añadir una guía';

  @override
  String get taskWizardAddToGuides => 'Añadir a mis guías';

  @override
  String get taskWizardBuiltIn => 'Guías incluidas en la aplicación';

  @override
  String get taskWizardDeleteGuide => 'Eliminar esta guía';

  @override
  String get taskWizardDeleteGuideBody =>
      'La guía se elimina de este dispositivo. La grabación de la que procede no se toca.';

  @override
  String get taskWizardEdit => 'Editar';

  @override
  String get taskWizardFromFile => 'Desde un archivo o paquete de tarea';

  @override
  String get taskWizardFromFileHint =>
      'Una grabación, un paquete de tarea o un archivo de guía de otra persona.';

  @override
  String get taskWizardFromRecording => 'Desde una de mis grabaciones';

  @override
  String get taskWizardFromRecordingHint =>
      'Elija una grabación; se convierte en guía al instante.';

  @override
  String get taskWizardGuideAdded => 'Añadida a Mis guías.';

  @override
  String get taskWizardGuideName => 'Nombre de la guía';

  @override
  String get taskWizardGuideNotSaved => 'No se pudo guardar la guía.';

  @override
  String get taskWizardGuides => 'Guías';

  @override
  String get taskWizardIntro =>
      'Grabe lo que hace, conviértalo en una guía y siga las guías paso a paso en la aplicación real.';

  @override
  String get taskWizardMakeGuide => 'Crear una guía';

  @override
  String get taskWizardNoGuides =>
      'Aún no tiene guías propias. Añada una desde una grabación o un archivo de tarea.';

  @override
  String get taskWizardOpenFileHint =>
      'Leer, editar y exportar una grabación o un paquete de tarea, sin cuenta.';

  @override
  String get taskWizardRecordings => 'Grabaciones';

  @override
  String get taskWizardSaveChanges => 'Guardar los cambios';

  @override
  String get taskWizardTitle => 'Asistente de tareas';

  @override
  String get taskWizardTools => 'Herramientas';

  @override
  String get taskWizardUnavailable =>
      'El grabador de tareas está desactivado en este espacio: las guías se pueden leer y editar aquí, pero no seguir.';

  @override
  String taskWorkbenchAccepted(int megabytes) {
    return 'Se aceptan: .json y .deskilo-task.zip, hasta $megabytes MB.';
  }

  @override
  String get taskWorkbenchChoose => 'Elegir un archivo de tarea';

  @override
  String taskWorkbenchClaim(String key, String value) {
    return 'El archivo indica $key: $value';
  }

  @override
  String get taskWorkbenchEdited => 'Una copia editada de una grabación.';

  @override
  String get taskWorkbenchFileType => 'Archivo de tarea';

  @override
  String get taskWorkbenchIntro =>
      'Abra un archivo de tarea guardado. Se lee solo en este dispositivo; no se envía nada y no hace falta iniciar sesión.';

  @override
  String get taskWorkbenchOfflineFailed => 'El navegador se negó a guardarlo.';

  @override
  String get taskWorkbenchOfflineForget => 'Dejar de guardarlo';

  @override
  String get taskWorkbenchOfflineKeep => 'Guardarlo en este dispositivo';

  @override
  String get taskWorkbenchOfflineOff =>
      'No guardado: sin conexión esta página no se abrirá.';

  @override
  String get taskWorkbenchOfflineReady =>
      'Guardado en este navegador: el taller verificado se abre sin conexión. Las acciones del espacio siguen necesitando conexión.';

  @override
  String get taskWorkbenchOfflineTitle => 'Usar el taller sin conexión';

  @override
  String get taskWorkbenchOfflineUnsupported =>
      'Este navegador no puede guardarlo (una ventana privada normalmente no puede).';

  @override
  String get taskWorkbenchOpen => 'Abrir un archivo de tarea';

  @override
  String get taskWorkbenchRefusedDamaged =>
      'Este archivo está dañado o se cambió después de crearse.';

  @override
  String get taskWorkbenchRefusedInvalid =>
      'Este archivo no contiene una tarea válida.';

  @override
  String get taskWorkbenchRefusedNewer =>
      'Este archivo se creó con una versión más reciente de la aplicación.';

  @override
  String get taskWorkbenchRefusedTooLarge =>
      'Este archivo es más grande de lo que lee el taller.';

  @override
  String get taskWorkbenchRefusedUnsafe =>
      'Este archivo está construido de una forma que no es seguro abrir.';

  @override
  String get taskWorkbenchRefusedUnsupported =>
      'Esto no es un archivo de tarea.';

  @override
  String get taskWorkbenchReviewIllustrations => 'Revisar las ilustraciones';

  @override
  String get taskWorkbenchStoryboardRestored =>
      'Las ilustraciones revisadas se restauraron desde el archivo.';

  @override
  String get taskWorkbenchTitle => 'Taller de tareas';

  @override
  String get taskWorkbenchTranscriptOnly =>
      'Algunos pasos vienen de una versión más reciente: se muestran solo como transcripción.';

  @override
  String get taskWorkbenchUntrusted =>
      'Un borrador privado de un archivo: nada de él se considera fiable ni se envía.';

  @override
  String get templateApplyConflict =>
      'Esta solicitud ya se usó para otra cosa. No se aplicó nada.';

  @override
  String get templateChangedSinceReview =>
      'Esta plantilla cambió desde que la revisó. No se aplicó nada; ábrala de nuevo para revisar la nueva versión.';

  @override
  String get templateClearFilters => 'Borrar la búsqueda';

  @override
  String get templateDetailNone => 'Ningún ajuste coincide.';

  @override
  String get templateDetailSearch => 'Buscar un ajuste en esta plantilla';

  @override
  String get templateDetails => 'Qué contiene';

  @override
  String templateExportResults(String count) {
    return 'Exportar estos resultados ($count)';
  }

  @override
  String templateExportTooMany(String max) {
    return 'Como máximo $max plantillas por libro. Acote primero la búsqueda.';
  }

  @override
  String get templateNoMatch =>
      'Ninguna plantilla coincide. Cambie las palabras, una etiqueta o un requisito.';

  @override
  String templatePrefer(String capability) {
    return 'Preferir: $capability';
  }

  @override
  String templatePreferredChip(String capability) {
    return 'Preferido: $capability';
  }

  @override
  String get templatePricesOtherCurrency =>
      'Los precios de la plantilla están en otra moneda, así que los precios de aquí no se cambiaron.';

  @override
  String get templateProfileFull => 'Perfil de configuración completo';

  @override
  String templateProfileSelected(String chosen, String total) {
    return 'Grupos elegidos: $chosen de $total';
  }

  @override
  String get templatePublishLocalNeeds =>
      'Un espacio que la aplique configurará esto por sí mismo:';

  @override
  String templateRegionSuggested(String values) {
    return 'Esta plantilla se creó para $values. Se mantiene su elección salvo que use sus valores.';
  }

  @override
  String get templateRegionUse => 'Usar la región de la plantilla';

  @override
  String templateRequire(String capability) {
    return 'Exigir: $capability';
  }

  @override
  String get templateRequirementRemove => 'Quitar el requisito';

  @override
  String get templateRequirementsReset => 'Restablecer';

  @override
  String templateResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plantillas mostradas',
      one: '1 plantilla mostrada',
      zero: 'Ninguna plantilla mostrada',
    );
    return '$_temp0';
  }

  @override
  String templateValidatorsToChoose(String types) {
    return 'Elija quién valida $types en los ajustes de validación; esas reglas se dejaron como estaban.';
  }

  @override
  String get templateWhy => 'Por qué coincide';

  @override
  String get templateWhyHide => 'Ocultar el porqué';

  @override
  String get templateWidenConfirm => 'Hacer legible';

  @override
  String templateWidenCount(String count) {
    return '$count ajustes pasan a ser legibles, tal como los contiene ahora la plantilla.';
  }

  @override
  String templateWidenExcluded(String count) {
    return '$count tipos de valores nunca salen con ella (datos bancarios, sedes, direcciones…).';
  }

  @override
  String templateWidenTitle(String audience) {
    return '¿Hacer esta plantilla legible para: $audience?';
  }

  @override
  String get templatesLoadFailed => 'No se pudieron cargar las plantillas.';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeSystem => 'Predeterminado del sistema';

  @override
  String get themeTitle => 'Tema';

  @override
  String get threadNoRefs =>
      'Las referencias solo se comparten con personas del mismo espacio.';

  @override
  String get threadRefsIn => 'Referencias en';

  @override
  String get unblockAction => 'Desbloquear';

  @override
  String get unblockDone => 'Desbloqueada.';

  @override
  String get usageAsk => 'Facturar el tiempo que estuve';

  @override
  String usageAskExplain(String booked, String present, String saved) {
    return 'Reservaste $booked y estuviste $present. Pide que las $saved no usadas dejen de facturarse. Lo decide otra persona, nunca tú.';
  }

  @override
  String get usageAskSubmit => 'Pedir';

  @override
  String get usageAskSubmitted => 'Pedido. Lo decide otra persona.';

  @override
  String get usageBilled => 'Facturado';

  @override
  String get usageBooked => 'Reservado';

  @override
  String get usageCorrected => 'Corregido';

  @override
  String get usageDelete => 'Eliminar este registro';

  @override
  String get usageDeleteSubmitted => 'Eliminación solicitada.';

  @override
  String get usageEmpty => 'Sin uso este mes.';

  @override
  String get usageLeftEarly => 'Salió antes';

  @override
  String get usageMember => 'Miembro';

  @override
  String get usageMemberAll => 'Todos';

  @override
  String get usageNoShow => 'Nadie llegó: la reserva se factura entera';

  @override
  String get usagePresent => 'Presente';

  @override
  String get usageReasonLabel => 'Por qué (opcional)';

  @override
  String get usageReportButton => 'Informe de consumo del mes';

  @override
  String get usageReportExtra => 'Medias jornadas extra';

  @override
  String get usageReportIncluded => 'Medias jornadas incluidas';

  @override
  String get usageReportOverage => 'Exceso trasladado a la próxima factura';

  @override
  String get usageReportPaid => 'Pagado por adelantado (participación)';

  @override
  String get usageReportRecordsHeading => 'Lo consumido';

  @override
  String get usageReportRemaining => 'Medias jornadas restantes';

  @override
  String get usageReportSupplements =>
      'Suplementos (accesorios, mesas, despachos)';

  @override
  String get usageReportUsed => 'Medias jornadas consumidas';

  @override
  String get usageTitle => 'Uso';

  @override
  String usageWas(String before) {
    return 'era $before';
  }

  @override
  String get uxLinkedReference => 'Recurso enlazado';

  @override
  String get validationAdminsMay => 'Los admins pueden validar';

  @override
  String get validationAllAdmins => 'Todos los admins';

  @override
  String get validationAutoValidateAdmin =>
      'Los admins eliminan sin validación';

  @override
  String get validationAutoValidateDesc =>
      'Su propia solicitud de eliminación se resuelve sola y queda marcada como autovalidada.';

  @override
  String get validationAutoValidateOwner =>
      'Los propietarios eliminan sin validación';

  @override
  String get validationCustomized => 'Personalizada';

  @override
  String get validationDefaultPolicy => 'Regla predeterminada';

  @override
  String get validationInherited => 'Hereda la predeterminada';

  @override
  String get validationMinAmount => 'Solo por encima de este importe';

  @override
  String get validationMinAmountDesc =>
      'Por debajo, el acto se aplica de inmediato. Vacío: cualquier importe.';

  @override
  String get validationNoSelfDesc =>
      'Quien crea un evento nunca lo valida. Espera a otra persona, o caduca sin decisión.';

  @override
  String get validationNoSelfShort => 'Nunca lo propio';

  @override
  String get validationNoSelfTitle => 'Nadie valida lo propio';

  @override
  String get validationNotEnough => 'No hay suficientes validadores elegibles.';

  @override
  String get validationOwnerOnly => 'Solo el propietario';

  @override
  String get validationOwnerRequired => 'El propietario siempre debe validar';

  @override
  String get validationOwnerSelf => 'La propiedad puede validar lo propio';

  @override
  String get validationOwnerSelfDesc =>
      'La única excepción, y es solo de la propiedad: un admin nunca valida su propio acto.';

  @override
  String get validationOwnerSelfShort => 'La propiedad puede validar lo propio';

  @override
  String get validationPickPersons => 'Elige las personas';

  @override
  String get validationRequiredCount => 'Validaciones requeridas';

  @override
  String get validationSaved => 'Regla de validación guardada.';

  @override
  String get validationScopeAdmins => 'Los admins';

  @override
  String get validationScopeHint =>
      'El propietario siempre puede. Admins: todos los admins, o los que listes. Designadas: exactamente estas personas, sea cual sea su rol. Todos los miembros: cualquiera activo.';

  @override
  String get validationScopeLabel => 'Quién valida';

  @override
  String get validationScopeListed => 'Personas designadas';

  @override
  String get validationScopeMembers => 'Todos los miembros';

  @override
  String get validationSentForApproval =>
      'Enviado a validación — se aplica una vez aprobado.';

  @override
  String get validationSequential => 'Una tras otra';

  @override
  String get validationSequentialDesc =>
      'La siguiente validación se pide cuando la anterior ha pasado, y el historial numera cada paso.';

  @override
  String get validationSpecificAdmins => 'Admins específicos';

  @override
  String get validationStepApplies => 'surte efecto';

  @override
  String get validationStepOwnerToo => 'y la propiedad, siempre';

  @override
  String validationStepQuorum(int count, String who) {
    return '$who — $count cualesquiera';
  }

  @override
  String get validationStepRaised => 'Alguien lo pide';

  @override
  String validationStepSequential(int count, String who) {
    return '$who — $count por turnos';
  }

  @override
  String get validationThresholdNote =>
      'Los importes menores se aplican de inmediato.';

  @override
  String get validationTitle => 'Reglas de validación';

  @override
  String validationTrailAwaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltan $count validaciones.',
      one: 'Falta 1 validación.',
    );
    return '$_temp0';
  }

  @override
  String get validationTrailNone => 'Aún no hay decisión.';

  @override
  String validationTrailStep(int order) {
    return 'Paso $order';
  }

  @override
  String get validationTrailTitle => 'Historial de validación';

  @override
  String get validationWorkflowBookings => 'Reservas';

  @override
  String get validationWorkflowBookingsStake =>
      'Hasta que se acepte, el puesto sigue como estaba.';

  @override
  String get validationWorkflowMoneyStake =>
      'Hasta que se acepte, el importe no cuenta en ningún extracto.';

  @override
  String get validationWorkflowPeople => 'Personas y roles';

  @override
  String get validationWorkflowPeopleStake =>
      'Hasta que se acepte, la persona conserva los accesos que tiene.';

  @override
  String get vatAccountField => 'Cuenta de IVA';

  @override
  String get vatAccountHint =>
      'Cuenta donde la exportación contable registra el IVA recaudado. Vacío = 445710.';

  @override
  String get vatAddRate => 'Añadir un tipo';

  @override
  String get vatChangeByLaw => 'Cambio por ley';

  @override
  String get vatChangeByLawExplainer =>
      'Un nuevo valor desde una fecha: el antiguo permanece en toda prestación anterior, el nuevo se aplica desde ese día. Nada se reasigna.';

  @override
  String get vatChangeInvalid =>
      'Hacen falta un porcentaje entre 0 y 99,99 y una fecha posterior al inicio del tipo.';

  @override
  String get vatChangeNeedsSave =>
      'Guarde primero el tipo; después cámbielo por ley.';

  @override
  String get vatDeclBox => 'Casilla';

  @override
  String get vatDeclBoxes => 'Casillas del formulario oficial';

  @override
  String get vatDeclDisclaimer =>
      'Generada a partir de las facturas emitidas del periodo. Verifíquela con su contabilidad antes de presentarla — es una ayuda, no asesoría fiscal.';

  @override
  String get vatDeclDraft => 'Borrador';

  @override
  String get vatDeclEmpty =>
      'Aún no hay declaraciones — elija un periodo y genere la primera.';

  @override
  String get vatDeclGenerate => 'Generar';

  @override
  String get vatDeclInvoices => 'Facturas';

  @override
  String get vatDeclMarkFiled => 'Marcar como presentada';

  @override
  String get vatDeclMarkFiledConfirm =>
      'Confirme que presentó esta declaración usted mismo (portal de Hacienda o su gestor). Se vuelve inmutable.';

  @override
  String get vatDeclNet => 'Base imponible';

  @override
  String get vatDeclPdf => 'PDF';

  @override
  String get vatDeclPeriod => 'Periodo';

  @override
  String get vatDeclRate => 'Tipo';

  @override
  String get vatDeclRegimeGate =>
      'Las declaraciones solo existen bajo el régimen sujeto a IVA — configúrelo en los ajustes de IVA.';

  @override
  String get vatDeclRejected => 'La plataforma rechazó la declaración.';

  @override
  String get vatDeclSeller => 'Vendedor';

  @override
  String get vatDeclSent => 'Declaración transmitida.';

  @override
  String get vatDeclStatus => 'Estado';

  @override
  String get vatDeclSubmitted => 'Presentada';

  @override
  String get vatDeclTitle => 'Declaración de IVA';

  @override
  String get vatDeclTotals => 'Totales';

  @override
  String get vatDeclTransmit => 'Transmitir';

  @override
  String get vatDeclVat => 'IVA';

  @override
  String get vatDeclVatId => 'NIF-IVA';

  @override
  String get vatDeclXml => 'Exportar XML';

  @override
  String get vatDeclarationBasisInvoice =>
      'Base: facturas (IVA sobre los documentos emitidos durante el periodo).';

  @override
  String get vatDeclarationBasisPayment =>
      'Base: cobros (IVA sobre los pagos recibidos durante el periodo).';

  @override
  String get vatEffectiveDate => 'Fecha de efecto (AAAA-MM-DD)';

  @override
  String get vatEmpty =>
      'Aún no hay ningún tipo: las facturas no muestran IVA.';

  @override
  String get vatExemptionReasonField => 'Mención de exención';

  @override
  String get vatExigibilityInvoice => 'Con la factura (criterio general)';

  @override
  String get vatExigibilityPayment => 'Con el cobro (criterio de caja)';

  @override
  String get vatExigibilitySubtitle =>
      'Con el cobro, un periodo declara lo que los clientes pagaron dentro de él; con la factura, lo que usted emitió. La elección se imprime en cada factura.';

  @override
  String get vatExigibilityTitle => 'Devengo del IVA';

  @override
  String get vatGroupDeposit => 'Envase retornable (fuera del IVA)';

  @override
  String get vatGroupExamples => 'Qué entra en cada grupo';

  @override
  String get vatGroupExcise => 'Con impuestos especiales';

  @override
  String get vatGroupExempt => 'Exento';

  @override
  String get vatGroupIntermediate => 'Intermedio';

  @override
  String get vatGroupLabel => 'Grupo';

  @override
  String get vatGroupNotSubject => 'No sujeto';

  @override
  String get vatGroupReduced => 'Reducido';

  @override
  String get vatGroupStandard => 'General';

  @override
  String get vatGroupSuperReduced => 'Superreducido';

  @override
  String get vatGroupZero => 'Tipo cero';

  @override
  String get vatIntro =>
      'En DesKilo los precios incluyen IVA. Añadir tipos no cambia nada de lo que pagan los miembros: el impuesto se extrae del precio que ya cobras y se muestra en la factura.';

  @override
  String get vatKeptRate =>
      'Un tipo que todavía usa una factura o un servicio se conserva, desactivado.';

  @override
  String get vatNeedsDefault =>
      'Marca exactamente un tipo como predeterminado.';

  @override
  String get vatNewPercent => 'Nuevo tipo %';

  @override
  String get vatPdfNet => 'Base';

  @override
  String get vatPdfVat => 'IVA';

  @override
  String get vatRateDefaultTooltip =>
      'Tipo por defecto: lo usan las cuotas y todo lo que no tenga tipo propio';

  @override
  String get vatRateIncomplete =>
      'Cada tipo necesita un nombre y un porcentaje entre 0 y 99,99.';

  @override
  String get vatRateLabelField => 'Nombre';

  @override
  String get vatRatePercentField => 'Tipo %';

  @override
  String get vatRateRemoveTooltip => 'Quitar';

  @override
  String get vatRatesTile => 'Tipos de IVA';

  @override
  String get vatRegimeHint =>
      'Este espacio no está declarado como sujeto a IVA, así que las facturas no lo muestran. Eso se cambia en Identidad legal.';

  @override
  String get vatReportByRate => 'Totales por tipo';

  @override
  String get vatReportCsv => 'Informe de IVA (CSV)';

  @override
  String get vatReportPdf => 'Informe de IVA (PDF)';

  @override
  String get vatReportPositions => 'Posiciones';

  @override
  String get vatReportTotals => 'Totales del periodo';

  @override
  String get vatSaved => 'Tipos de IVA guardados.';

  @override
  String get vatSeed => 'Usar los tipos habituales';

  @override
  String get vatServiceRate => 'Tipo de IVA';

  @override
  String get vatServiceRateDefault => 'Tipo por defecto del espacio';

  @override
  String vatShareAmount(String amount) {
    return 'IVA incl. $amount';
  }

  @override
  String get vatSince => 'desde el';

  @override
  String get vatTitle => 'IVA';

  @override
  String get vatTreatmentAuto => 'Automático';

  @override
  String get vatTreatmentDomestic => 'IVA nacional';

  @override
  String get vatTreatmentExempt => 'Comprador exento';

  @override
  String get vatTreatmentExport => 'Fuera de la UE';

  @override
  String get vatTreatmentReasonField =>
      'Motivo de exención (impreso en la factura)';

  @override
  String get vatTreatmentReverseCharge => 'Inversión del sujeto pasivo';

  @override
  String get vatUntil => 'hasta el';

  @override
  String get visibilityAbout => 'Profesión y biografía';

  @override
  String get visibilityAboutEmpty => 'Añade tu profesión y unas palabras';

  @override
  String get visibilityAboutMe => 'Sobre mí';

  @override
  String get visibilityAboutSaveFailed =>
      'No se pudieron guardar tu profesión y biografía. Inténtalo de nuevo.';

  @override
  String get visibilityBio => 'Unas palabras sobre ti';

  @override
  String visibilityChosenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Miembros de $count espacios elegidos',
      one: 'Miembros de 1 espacio elegido',
    );
    return '$_temp0';
  }

  @override
  String get visibilityChosenSpaces => 'Miembros de espacios elegidos';

  @override
  String get visibilityContact => 'WhatsApp y correo';

  @override
  String get visibilityElsewhereIntro =>
      'En un servidor conectado tiene la cuenta de ese servidor. Quienes allí no comparten ningún espacio con usted ven lo que permite a cualquier persona con sesión iniciada; sus datos de contacto y su presencia nunca salen de sus espacios.';

  @override
  String get visibilityElsewhereTitle => 'En mis otros servidores';

  @override
  String get visibilityIdentity => 'Nombre y foto';

  @override
  String get visibilityIntro =>
      'Cada parte de tu cuenta elige su propio público. Nada es público si no lo eliges.';

  @override
  String get visibilityMySpaces => 'Miembros de mis espacios';

  @override
  String get visibilityNobody => 'Nadie';

  @override
  String visibilityOnServer(String host) {
    return 'Quién me ve en $host';
  }

  @override
  String visibilityOnServerUnavailable(String host) {
    return '$host no respondió. Inténtelo más tarde.';
  }

  @override
  String get visibilityPresence => 'Hoy en el espacio';

  @override
  String get visibilityPreviewCanWrite =>
      'Puede iniciar una conversación contigo';

  @override
  String get visibilityPreviewCannotWrite =>
      'No puede iniciar una conversación contigo';

  @override
  String get visibilityPreviewFailed => 'No se pudo cargar la vista previa.';

  @override
  String get visibilityPreviewMySpaces => 'Un miembro de mis espacios';

  @override
  String get visibilityPreviewNobody => 'Solo yo';

  @override
  String get visibilityPreviewNothing => 'No ven nada de ti.';

  @override
  String get visibilityPreviewSignedIn => 'Cualquiera con sesión iniciada';

  @override
  String get visibilityPreviewTitle => 'Cómo me ven los demás';

  @override
  String get visibilityProfession => 'Profesión';

  @override
  String get visibilityReachability =>
      'Quién puede iniciar una conversación conmigo';

  @override
  String get visibilitySaveFailed =>
      'No se pudo guardar quién lo ve. Inténtalo de nuevo.';

  @override
  String get visibilitySignedIn => 'Cualquiera con sesión iniciada';

  @override
  String get visibilityTitle => 'Quién me ve';

  @override
  String get visibilityWidenAction => 'Ampliar';

  @override
  String visibilityWidenConfirm(String field, String audience) {
    return '¿Mostrar tu $field a: $audience? Podrán verlo.';
  }

  @override
  String get visitCancel => 'Cancelar esta visita';

  @override
  String get visitCancelFailed =>
      'No se pudo cancelar la visita. Nada ha cambiado; inténtalo de nuevo.';

  @override
  String get visitGuestNote => 'Visita de invitado — no una membresía';

  @override
  String get visitStatusCancelled => 'Cancelada';

  @override
  String get visitStatusConfirmed => 'Confirmada';

  @override
  String get visitStatusDeclined => 'Rechazada';

  @override
  String get visitStatusExpired => 'Caducada';

  @override
  String get visitStatusRequested => 'Solicitada';

  @override
  String whatTheyCanDoTitle(String name) {
    return 'Lo que $name puede hacer aquí';
  }

  @override
  String get whatYouCanDoFromAdministrator => 'Del rol Administrador/a';

  @override
  String get whatYouCanDoFromCoOwner => 'Como copropietario';

  @override
  String get whatYouCanDoFromEveryMember => 'Como todos los miembros';

  @override
  String get whatYouCanDoFromOwner => 'Como propietario: todo';

  @override
  String whatYouCanDoFromRole(String role) {
    return 'Del rol $role';
  }

  @override
  String get whatYouCanDoIntro =>
      'Aquí todas las personas son miembros; lo que puede hacer — mensajes, reservas y el resto — viene solo de los roles que tiene.';

  @override
  String get whatYouCanDoNothingMore => 'Nada más que un miembro.';

  @override
  String get whatYouCanDoTitle => 'Lo que puedes hacer aquí';

  @override
  String get whatsappFieldLabel => 'Número de WhatsApp';

  @override
  String get whatsappHelper =>
      'Opcional. Visible para los miembros de tus espacios para que puedan contactarte por WhatsApp. Déjalo vacío para dejar de compartirlo.';

  @override
  String get whatsappHint => '+34 612 34 56 78';

  @override
  String get whatsappNotShared => 'No compartido';

  @override
  String get whatsappSaveFailed => 'No se pudo guardar el número de WhatsApp';

  @override
  String get whatsappSaved => 'Número de WhatsApp guardado';

  @override
  String get whatsappTitle => 'WhatsApp';

  @override
  String get wizardBack => 'Atrás';

  @override
  String get wizardCardHint =>
      'Emitir, enviar, recordar, registrar y validar pagos, conciliar y cerrar: un solo proceso guiado.';

  @override
  String get wizardCloseHint =>
      'Un socio con varias facturas abiertas puede pagar UNA; a una factura pagada en parte se le puede anular el resto; una nota de crédito se reembolsa. Cada una pasa por la validación.';

  @override
  String get wizardCloseNone => 'Nada que reagrupar, anular o reembolsar.';

  @override
  String get wizardFinish => 'Terminar';

  @override
  String wizardIssueAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Emitir $count facturas',
      one: 'Emitir 1 factura',
    );
    return '$_temp0';
  }

  @override
  String wizardIssueFailed(String name) {
    return 'No se pudo emitir para $name.';
  }

  @override
  String get wizardIssueHint =>
      'Desmarque a un socio para dejarlo fuera de este lote. Los socios ya cubiertos aparecen como hechos.';

  @override
  String get wizardIssueNothing => 'Nada que emitir para este periodo.';

  @override
  String wizardIssuedChip(String number) {
    return 'Emitida $number';
  }

  @override
  String get wizardMatchAction => 'Conciliar';

  @override
  String wizardMatchCredit(String amount) {
    return 'Crédito disponible: $amount';
  }

  @override
  String get wizardMatchHint =>
      'Una factura está pagada cuando se le concilia un pago real. Las filas con crédito en la cuenta del socio están listas.';

  @override
  String get wizardMatchNoCredit => 'Aún no hay pago en la cuenta';

  @override
  String get wizardMatchNone => 'Todas las facturas están pagadas o cerradas.';

  @override
  String get wizardMatchPending => 'Pendiente de validación';

  @override
  String get wizardNext => 'Siguiente';

  @override
  String get wizardPaymentAccept => 'Confirmar';

  @override
  String get wizardPaymentReject => 'Rechazar';

  @override
  String get wizardPaymentsHint =>
      'Lo que los socios declararon espera su confirmación abajo. Un pago que llegó a la cuenta sin declaración se registra aquí; el socio lo confirma después.';

  @override
  String get wizardPaymentsNone => 'Ningún pago declarado espera su decisión.';

  @override
  String wizardPeriodLabel(String period) {
    return 'Periodo: $period';
  }

  @override
  String get wizardRefund => 'Reembolsar';

  @override
  String wizardRemindAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Enviar $count recordatorios',
      one: 'Enviar 1 recordatorio',
    );
    return '$_temp0';
  }

  @override
  String get wizardRemindHint =>
      'Vencidas según sus reglas de recordatorio. Un toque registra cada recordatorio y avisa a los socios; la carta se abre por fila.';

  @override
  String wizardRemindLevel(int level) {
    return 'recordatorio $level';
  }

  @override
  String get wizardRemindNone => 'Ningún recordatorio vence según sus reglas.';

  @override
  String get wizardRemindOne => 'Carta de recordatorio';

  @override
  String get wizardReviewIssued => 'Ya emitidas';

  @override
  String get wizardReviewOpen => 'Facturas abiertas';

  @override
  String get wizardReviewOverdue => 'Recordatorios vencidos';

  @override
  String get wizardReviewPending => 'Pagos por validar';

  @override
  String get wizardReviewToIssue => 'Por emitir';

  @override
  String get wizardRunEnd => 'Fin de mes';

  @override
  String get wizardRunEndHint =>
      'Lo que costó el mes que acaba de terminar: uso, consumo y cargos adicionales. Emitir, enviar, recordar; luego registrar, validar y conciliar los pagos, y cerrar.';

  @override
  String get wizardRunStart => 'Inicio de mes';

  @override
  String get wizardRunStartHint =>
      'Las suscripciones pagadas por adelantado: emitirlas para el mes que viene, enviarlas, planificar los recordatorios; luego, la parte de pagos.';

  @override
  String get wizardSendDownload => 'Descargar el PDF';

  @override
  String get wizardSendHint =>
      'Entregue cada factura a su socio: comparta el PDF o descárguelo para enviarlo a su manera.';

  @override
  String get wizardSendNone =>
      'Todavía no hay factura de esta pasada que enviar.';

  @override
  String get wizardSendShare => 'Compartir el PDF';

  @override
  String wizardSettle(int count) {
    return 'Reagrupar $count';
  }

  @override
  String get wizardStepClose => 'Cerrar';

  @override
  String get wizardStepCompleted => 'Completado';

  @override
  String get wizardStepIssue => 'Emitir';

  @override
  String get wizardStepMatch => 'Conciliar';

  @override
  String get wizardStepPayments => 'Pagos';

  @override
  String get wizardStepRemind => 'Recordar';

  @override
  String get wizardStepReview => 'Revisión';

  @override
  String get wizardStepSend => 'Enviar';

  @override
  String get wizardStepSkipped => 'Omitido — ajustes sugeridos';

  @override
  String get wizardStepSummary => 'Resumen';

  @override
  String get wizardStepUnavailable => 'Aún no disponible';

  @override
  String get wizardSubmitting => 'Enviando';

  @override
  String get wizardSummaryHint => 'Lo que hizo esta pasada';

  @override
  String get wizardTallyDecided => 'Pagos confirmados o rechazados';

  @override
  String get wizardTallyIssued => 'Facturas emitidas';

  @override
  String get wizardTallyMatched => 'Facturas conciliadas';

  @override
  String get wizardTallyNothing => 'No se cambió nada.';

  @override
  String get wizardTallyRefunds => 'Reembolsos';

  @override
  String get wizardTallyRegistered => 'Pagos registrados';

  @override
  String get wizardTallyReminded => 'Recordatorios enviados';

  @override
  String get wizardTallySettled => 'Reagrupaciones';

  @override
  String get wizardTallyShared => 'PDF compartidos o descargados';

  @override
  String get wizardTallyWriteoffs => 'Anulaciones solicitadas';

  @override
  String get wizardTitle => 'Asistente de facturación';

  @override
  String get wizardTodoHeading => 'Aún abierto: a quién le toca';

  @override
  String get wizardTodoNone => 'No queda nada abierto.';

  @override
  String get wizardWhoValidators => 'Validadores';

  @override
  String get wizardWhoYou => 'Usted';

  @override
  String get wizardWriteoff => 'Anular';

  @override
  String get wordingChangedOnly => 'Solo modificados';

  @override
  String get wordingDefaultLabel => 'Palabra del producto';

  @override
  String get wordingIntro =>
      'Renombre un conjunto reducido y aprobado de palabras del producto. Todo lo demás conserva la redacción del producto, y un término que no haya renombrado se muestra exactamente igual que antes.';

  @override
  String get wordingLocale => 'Idioma';

  @override
  String get wordingNone => 'Ningún término coincide.';

  @override
  String get wordingReset => 'Restablecer';

  @override
  String get wordingResetHint =>
      'Restablecer elimina su palabra y recupera la del producto.';

  @override
  String get wordingRow => 'Vocabulario';

  @override
  String get wordingRowHint =>
      'Las palabras que este espacio usa para una plaza, la leyenda y las pestañas.';

  @override
  String get wordingSavedOne => 'Guardado';

  @override
  String get wordingSearch => 'Buscar una palabra';

  @override
  String get wordingSurfaceBooking => 'Reserva';

  @override
  String get wordingSurfaceLegend => 'Leyenda';

  @override
  String get wordingSurfaceNavigation => 'Navegación';

  @override
  String get wordingSurfacePlan => 'El espacio';

  @override
  String get wordingTitle => 'Vocabulario';

  @override
  String get workbookExportBuilding => 'Creando el libro…';

  @override
  String get workbookExportCancelled =>
      'Exportación cancelada. No se ha guardado nada.';

  @override
  String workbookExportReading(String done, String total) {
    return 'Leyendo plantillas: $done de $total';
  }

  @override
  String get workbookExportSaving => 'Elija dónde guardarlo…';

  @override
  String get workbookExportTitle => 'Exportando el libro';

  @override
  String get workbookNote =>
      'Una instantánea de definiciones de plantillas. Editar este archivo no cambia nada en DesKilo, y no es la copia de seguridad de ningún espacio: no contiene miembros, reservas, facturas ni credenciales.';

  @override
  String get workbookStateDefault =>
      'la plantilla no lo indica; se aplica el valor por defecto';

  @override
  String get workbookStateExcluded => 'deliberadamente nunca publicado';

  @override
  String get workbookStateInherit =>
      'la plantilla no lo indica; el destino conserva el suyo';

  @override
  String get workbookStateLocal => 'a definir localmente';

  @override
  String get workbookStatePresent => 'la plantilla fija este valor';

  @override
  String get workbookStateUnknown => 'no se pudo leer; no se afirma nada';

  @override
  String get workbookWide =>
      'Catalogs, RolePermissions, Validations y Fields muestran un valor donde la plantilla lo fija y, si no, su estado';

  @override
  String get workspaceAddressLabel => 'Dirección del espacio';

  @override
  String get workspaceCodeCopied => 'Copiado';

  @override
  String get workspaceCodeCopy => 'Copiar ID';

  @override
  String get workspaceCodeEdit => 'Cambiar el ID del espacio';

  @override
  String get workspaceCodeExplainer =>
      'Los coworkers escanean este código QR — o escriben el ID — para unirse a este espacio.';

  @override
  String get workspaceCodeHint => '4–20 letras o dígitos, único';

  @override
  String get workspaceCodeLabel => 'ID del espacio';

  @override
  String get workspaceCodeRejected =>
      'ID rechazado — debe tener 4–20 letras o dígitos y no estar ya en uso.';

  @override
  String get workspaceCodeSharePng => 'Compartir como PNG';

  @override
  String get workspaceCodeTitle => 'ID del espacio y QR';

  @override
  String get workspaceConfigAvailability => 'Disponibilidad';

  @override
  String get workspaceConfigBookableWhole => 'reservable en su totalidad';

  @override
  String get workspaceConfigClosures => 'Cierres';

  @override
  String get workspaceConfigColName => 'Nombre';

  @override
  String get workspaceConfigColRole => 'Rol';

  @override
  String get workspaceConfigColStatus => 'Estado';

  @override
  String get workspaceConfigEmptyLevel => 'Sin salas';

  @override
  String get workspaceConfigFeatures => 'Funciones activadas';

  @override
  String get workspaceConfigFloorPlan => 'Plano';

  @override
  String get workspaceConfigGranularity => 'Granularidad de reserva';

  @override
  String get workspaceConfigInvitationCustom =>
      'Mensaje de invitación personalizado configurado';

  @override
  String get workspaceConfigInvitationDefault =>
      'Mensaje de invitación integrado (todos los idiomas)';

  @override
  String get workspaceConfigInvitationSingleUse =>
      'Los códigos de invitación personales son de un solo uso y caducan a los 14 días; los nuevos miembros necesitan la aprobación de un admin';

  @override
  String get workspaceConfigInvitations => 'Invitaciones';

  @override
  String get workspaceConfigMembersSection => 'Miembros';

  @override
  String get workspaceConfigNone => 'Ninguno';

  @override
  String get workspaceConfigOpenDays => 'Días de apertura';

  @override
  String get workspaceConfigOverview => 'Resumen';

  @override
  String get workspaceConfigPdfExport => 'Exportar configuración (PDF)';

  @override
  String get workspaceConfigPdfExportSubtitle =>
      'Instantánea completa: ajustes, todos los miembros y el plano.';

  @override
  String workspaceConfigPdfGeneratedOn(String date) {
    return 'Generado el $date';
  }

  @override
  String get workspaceConfigPdfTitle => 'Configuración del espacio';

  @override
  String get workspaceConfigSeats => 'Plazas';

  @override
  String get workspaceCountryLabel => 'País';

  @override
  String get workspaceCurrencyLabel => 'Moneda';

  @override
  String get workspaceDangerZone => 'Zona de peligro';

  @override
  String workspaceDeskOpacityValue(int percent) {
    return 'Opacidad: $percent %';
  }

  @override
  String get workspaceDeskTransparencyHelper =>
      'Reduce la opacidad de las mesas para que se vea la foto de fondo de la planta.';

  @override
  String get workspaceDeskTransparencyTitle => 'Transparencia de mesas';

  @override
  String get workspaceExcelExport => 'Exportar datos (Excel)';

  @override
  String get workspaceExcelExportSubtitle =>
      'Un ZIP: todos los datos en un libro (reservas, pagos, facturas, miembros, plano — una pestaña cada uno), un manifiesto que cuenta sus filas y los archivos guardados del espacio.';

  @override
  String get workspaceFieldsOptional => 'opcional';

  @override
  String get workspaceFieldsPersonalNote =>
      'Tus respuestas son datos personales: forman parte de tu exportación de datos y se borran cuando dejas este espacio, salvo que el espacio documente una obligación legal de conservar alguna.';

  @override
  String get workspaceFieldsSaveFailed =>
      'Tus respuestas a las preguntas de este espacio no se han guardado. El resto de tus datos sí.';

  @override
  String workspaceFieldsTitle(String workspace) {
    return 'Preguntas de $workspace';
  }

  @override
  String get workspaceGenericError => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get workspaceInviteCodeInvalid =>
      'No se encontró ningún ID — pega la invitación o escribe el ID.';

  @override
  String get workspaceInviteCodeLabel => 'Código de invitación';

  @override
  String get workspaceInvitePasteHint =>
      'Pega el mensaje de invitación completo — el ID se detecta automáticamente.';

  @override
  String get workspaceLanguageHelper =>
      'Las invitaciones se redactan por defecto en este idioma. El idioma de tu app se cambia en Ajustes.';

  @override
  String get workspaceLanguageLabel => 'Idioma del espacio';

  @override
  String get workspaceLanguageUnset => 'Idioma de la app del remitente';

  @override
  String get workspaceNameLabel => 'Nombre del espacio';

  @override
  String get workspacePaymentsBillingTitle => 'Pagos y facturación';

  @override
  String get workspaceResetConfirmButton => 'Restablecer el espacio';

  @override
  String workspaceResetConfirmLabel(String phrase) {
    return 'Escribe «$phrase» para confirmar';
  }

  @override
  String get workspaceResetConfirmPhrase => 'Acepto';

  @override
  String get workspaceResetDialogTitle => '¿Restablecer este espacio?';

  @override
  String get workspaceResetDone => 'Espacio restablecido.';

  @override
  String get workspaceResetSubtitle =>
      'Elimina todas las reservas, las finanzas y el plano. Conserva ajustes y miembros.';

  @override
  String get workspaceResetTitle => 'Restablecer el espacio';

  @override
  String get workspaceResetWarning =>
      'Esto elimina permanentemente todas las reservas, todos los datos financieros y del libro mayor, el registro de actividad y todo el plano — plantas, salas, mesas, plazas e imágenes. Se conservan los ajustes del espacio, los tramos de tarifa, la disponibilidad, las funciones, los catálogos y los miembros. No se puede deshacer.';

  @override
  String get workspaceSettingsConflict =>
      'Alguien cambió estos ajustes mientras los editaba. No se guardó nada; sus cambios siguen aquí.';

  @override
  String get workspaceSettingsCurrencyHelper =>
      'Se propone según el país — cámbiala si tu comunidad factura en otra moneda.';

  @override
  String get workspaceSettingsSaved => 'Espacio guardado.';

  @override
  String get workspaceSettingsTitle => 'Espacio de coworking';

  @override
  String get workspaceTimezoneHint => 'Europe/Madrid';

  @override
  String get workspaceTimezoneLabel => 'Zona horaria';

  @override
  String get workspaceTimezoneUnknown => 'Elija una zona horaria de la lista';

  @override
  String get workspaceWhatsappGroupHelper =>
      'Se muestra a los miembros para que puedan unirse al grupo de WhatsApp de la comunidad. Pega el enlace de invitación del grupo (https://chat.whatsapp.com/…). Déjalo vacío para no mostrar nada.';

  @override
  String get workspaceWhatsappGroupInvalid =>
      'Debe ser un enlace de invitación de chat.whatsapp.com';

  @override
  String get workspaceWhatsappGroupLabel => 'Enlace del grupo de WhatsApp';

  @override
  String get workspaceWhatsappGroupTitle => 'Grupo de WhatsApp';

  @override
  String get workspaceXmlErrorInvalidPlan =>
      'El plano del archivo no es válido: hay salas, mesas o puestos que se superponen o quedan fuera de su zona.';

  @override
  String get workspaceXmlErrorInvalidValue =>
      'El archivo contiene un valor no válido y no se puede importar.';

  @override
  String get workspaceXmlErrorMalformed => 'El archivo no es un XML legible.';

  @override
  String get workspaceXmlErrorMissingAttribute =>
      'El archivo está incompleto — falta un valor obligatorio.';

  @override
  String get workspaceXmlErrorMissingElement =>
      'El archivo está incompleto — falta una sección obligatoria.';

  @override
  String get workspaceXmlErrorUnsupportedVersion =>
      'El archivo fue exportado por una versión más reciente de DesKilo y no se puede importar.';

  @override
  String get workspaceXmlErrorWrongRoot =>
      'Este no es un archivo de espacio de DesKilo.';

  @override
  String get workspaceXmlExport => 'Exportar el espacio (XML)';

  @override
  String get workspaceXmlExportSubtitle =>
      'Ajustes y plano del espacio en un archivo para compartir. Sin miembros, reservas ni datos financieros.';

  @override
  String get workspaceXmlFileTypeLabel => 'XML';

  @override
  String get workspaceXmlImport => 'Importar el espacio (XML)';

  @override
  String get workspaceXmlImportConfigurationOnly =>
      'La configuración se aplicó. El plano se conservó: este espacio ya tiene reservas, así que su plano no puede reemplazarse.';

  @override
  String get workspaceXmlImportConfirm => 'Sustituir e importar';

  @override
  String get workspaceXmlImportPartial =>
      'Parte de la importación se aplicó antes de detenerse: revisa los ajustes y el plano abajo.';

  @override
  String workspaceXmlImportPreviewAccessories(int count) {
    return 'Accesorios: $count';
  }

  @override
  String workspaceXmlImportPreviewConfiguration(
    int settings,
    int tables,
    int rows,
  ) {
    return 'Configuración: $settings ajustes, $rows filas en $tables tablas';
  }

  @override
  String workspaceXmlImportPreviewCounts(
    int levels,
    int offices,
    int desks,
    int seats,
  ) {
    return 'Plantas: $levels · Salas: $offices · Mesas: $desks · Puestos: $seats';
  }

  @override
  String get workspaceXmlImportPreviewTitle => '¿Sustituir el plano?';

  @override
  String get workspaceXmlImportPreviewWarning =>
      'El plano actual se eliminará y sustituirá, y los ajustes del espacio se sobrescribirán. Esta acción no se puede deshacer.';

  @override
  String get workspaceXmlImportReservationsError =>
      'Este espacio ya tiene reservas, por lo que su plano no se puede sustituir. Solo se puede importar antes de la primera reserva.';

  @override
  String get workspaceXmlImportSubtitle =>
      'Restaurar los ajustes y el plano desde un archivo exportado. Sustituye el plano actual.';

  @override
  String get workspaceXmlImportSuccess => 'Espacio importado.';
}
