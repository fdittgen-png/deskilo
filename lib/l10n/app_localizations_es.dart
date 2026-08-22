// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get accessoriesTitle => 'Accesorios';

  @override
  String get accessoriesEmpty => 'Aún no hay accesorios.';

  @override
  String get accessoriesNew => 'Nuevo accesorio';

  @override
  String get accessoriesEdit => 'Editar accesorio';

  @override
  String get accessoriesName => 'Nombre';

  @override
  String get accessoriesSupplement => 'Suplemento por media jornada';

  @override
  String accessoriesPerHalfDay(String amount) {
    return '$amount / media jornada';
  }

  @override
  String get accessoriesNoSupplement => 'Sin suplemento';

  @override
  String get accessoriesInactive => 'Inactivo';

  @override
  String get accessoriesActive => 'Activo';

  @override
  String get authSignInTitle => 'Iniciar sesión';

  @override
  String get authSignUpTitle => 'Crear cuenta';

  @override
  String get authEmailLabel => 'Correo electrónico';

  @override
  String get authPasswordLabel => 'Contraseña';

  @override
  String get authShowPassword => 'Mostrar contraseña';

  @override
  String get authHidePassword => 'Ocultar contraseña';

  @override
  String get authDisplayNameLabel => 'Nombre visible';

  @override
  String get authForgotPassword => '¿Olvidaste la contraseña?';

  @override
  String get authResetTitle => 'Restablecer contraseña';

  @override
  String get authResetExplainer =>
      'Te enviaremos un código de un solo uso por correo. Úsalo aquí para establecer una nueva contraseña.';

  @override
  String get authResetSendCode => 'Enviar código';

  @override
  String get authResetCodeSent => 'Código enviado — revisa tu correo.';

  @override
  String get authResetCodeLabel => 'Código del correo';

  @override
  String get authResetNewPasswordLabel => 'Nueva contraseña';

  @override
  String get authResetSubmit => 'Establecer nueva contraseña';

  @override
  String get authResetDone => 'Contraseña actualizada — has iniciado sesión.';

  @override
  String get authResetInvalidCode => 'Ese código no es válido o ha caducado.';

  @override
  String get authSignInButton => 'Iniciar sesión';

  @override
  String get authSignUpButton => 'Crear cuenta';

  @override
  String get authToggleToSignUp => '¿Nuevo aquí? Crea una cuenta';

  @override
  String get authToggleToSignIn => '¿Ya tienes cuenta? Inicia sesión';

  @override
  String get authFieldRequired => 'Obligatorio';

  @override
  String get authPasswordTooShort => 'Al menos 8 caracteres';

  @override
  String get authGenericError =>
      'Error de autenticación. Comprueba tus credenciales e inténtalo de nuevo.';

  @override
  String get authSignOut => 'Cerrar sesión';

  @override
  String get authNetworkError =>
      'No se pudo contactar con el servidor. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get availabilityTitle => 'Disponibilidad';

  @override
  String get availabilityOpenWeekdays => 'Días de apertura';

  @override
  String get availabilityClosureDays => 'Días de cierre';

  @override
  String get availabilityAddClosure => 'Añadir día de cierre';

  @override
  String get availabilityClosureReason => 'Motivo (opcional)';

  @override
  String get availabilityLastOpenDay =>
      'Al menos un día de la semana debe permanecer abierto.';

  @override
  String get availabilityNoClosures => 'No hay días de cierre.';

  @override
  String get availabilityGranularityTitle => 'Granularidad de las reservas';

  @override
  String get availabilityGranularityDescription =>
      'Medias jornadas: las reservas cubren la mañana, la tarde o la jornada completa — las ventanas siguen el horario laboral configurado.';

  @override
  String get availabilityGranularityFlexible => 'Franja horaria libre';

  @override
  String get availabilityGranularityHalfDay => 'Medios días (mañana y tarde)';

  @override
  String get availabilityGranularity5 => 'Franjas de 5 minutos';

  @override
  String get availabilityGranularity15 => 'Franjas de 15 minutos';

  @override
  String get availabilityGranularity30 => 'Franjas de 30 minutos';

  @override
  String get availabilityGranularity60 => 'Franjas de 1 hora';

  @override
  String get availabilityGranularityFullDay => 'Solo días completos';

  @override
  String planSlotError(int minutes) {
    return 'Las reservas deben empezar y terminar en la cuadrícula de $minutes minutos.';
  }

  @override
  String get planFullDayError => 'Aquí las reservas cubren el día completo.';

  @override
  String get availabilityGranularityHours =>
      'Horas reales (de–a exacto, medias/jornadas como atajos)';

  @override
  String get availabilityWorkHoursTitle => 'Horario laboral';

  @override
  String get availabilityWorkHoursDescription =>
      'Las ventanas de media jornada y jornada completa en todas partes — reservas, check-in y facturación — siguen este horario.';

  @override
  String get availabilityWorkStart => 'Inicio de la jornada';

  @override
  String get availabilityHalfBoundary => 'Límite de media jornada';

  @override
  String get availabilityWorkEnd => 'Fin de la jornada';

  @override
  String get availabilityHalfDayHours => 'Horas facturadas como media jornada';

  @override
  String get availabilityFullDayHours =>
      'Horas facturadas como jornada completa';

  @override
  String availabilityHourOption(int count) {
    return '$count h';
  }

  @override
  String get availabilityWorkHoursInvalid =>
      'Debe cumplirse: inicio < límite de media jornada < fin.';

  @override
  String get myBadgeTitle => 'Mi credencial';

  @override
  String billSubscription(int pct) {
    return 'Suscripción $pct %';
  }

  @override
  String billEntitlement(int used, int included, int openDays) {
    return '$used de $included medias jornadas usadas ($openDays días de apertura)';
  }

  @override
  String billOverage(int extra) {
    return '$extra medias jornadas extra';
  }

  @override
  String get billServices => 'Servicios consumidos';

  @override
  String get billServicesTotal => 'Total de servicios';

  @override
  String get billOpenPositions => 'Partidas pendientes';

  @override
  String get billPendingBadge => 'pendiente de validación';

  @override
  String get billPaymentsCredits => 'Pagos y créditos';

  @override
  String get billBalance => 'Saldo';

  @override
  String get billSettled => 'Al día';

  @override
  String get billOutstanding => 'Pendiente';

  @override
  String get billAccessorySupplements => 'Suplementos de accesorios';

  @override
  String get entitlementTitle => 'Este mes';

  @override
  String entitlementDaysUsed(String used, String total) {
    return '$used de $total días usados';
  }

  @override
  String entitlementDaysLeft(String left) {
    return '$left días restantes';
  }

  @override
  String get entitlementBlockedFull =>
      'Has usado todos tus días este mes. Pide más a un administrador o solicita medias jornadas extra abajo.';

  @override
  String entitlementPaygRate(String rate) {
    return 'Los días que superen tu plan se cobran a $rate cada uno.';
  }

  @override
  String get entitlementPackageFull =>
      'Has usado todos tus días este mes. Compra un paquete para seguir reservando.';

  @override
  String get billPackages => 'Paquetes de días';

  @override
  String get payOnlineButton => 'Pagar en línea';

  @override
  String get payOnlineNotConfigured =>
      'Los pagos en línea aún no están configurados. Pregunta al propietario del espacio.';

  @override
  String get payOnlineChooseTitle => 'Pagar en línea';

  @override
  String get paymentProviderStripe => 'Tarjeta (Stripe)';

  @override
  String get paymentProviderMollie => 'Mollie — iDEAL, Bancontact…';

  @override
  String get payOnlineDiagTitle => 'Pagos en línea — sin configurar';

  @override
  String get payOnlineDiagHint =>
      'Al servidor le falta esta configuración (docs/design/payments-integration.md):';

  @override
  String billInvoiceCard(String number) {
    return 'Factura $number';
  }

  @override
  String billCreditNoteCard(String number) {
    return 'Nota de crédito $number';
  }

  @override
  String get billInvoiceTotal => 'Total de la factura';

  @override
  String get billInvoicePaid => 'Pagado hasta ahora';

  @override
  String get billInvoiceRemaining => 'Pendiente de pago';

  @override
  String get billCreditNoteDue =>
      'El espacio te debe este importe: no tienes nada que pagar.';

  @override
  String get billCreditNoteRefunded =>
      'El espacio te ha reembolsado este importe.';

  @override
  String get accountCardTitle => 'Tu cuenta';

  @override
  String get accountCredit => 'Crédito a favor';

  @override
  String get accountRefundDue => 'Reembolso pendiente del espacio';

  @override
  String get accountNet => 'Posición neta';

  @override
  String accountOpenPartial(String period, String paid) {
    return '$period · $paid pagados';
  }

  @override
  String get accountImputationHint =>
      'Tu crédito puede saldar facturas abiertas: el espacio lo imputa al conciliar los pagos.';

  @override
  String get billPdfTitle => 'Factura mensual';

  @override
  String get billPdfExport => 'Exportar la factura como PDF';

  @override
  String get billingTitle => 'Facturación';

  @override
  String get billingFeeBands => 'Tramos de tarifas';

  @override
  String billingBandFrom(int from) {
    return 'desde $from %';
  }

  @override
  String get billingBandTo => 'Hasta %';

  @override
  String get billingBandFee => 'Cuota mensual';

  @override
  String get billingBandOverage => 'Exceso';

  @override
  String get billingAddBand => 'Añadir tramo';

  @override
  String get billingRemoveBand => 'Eliminar tramo';

  @override
  String get billingBandsInvalid =>
      'Los tramos deben ser crecientes y terminar en 100 %.';

  @override
  String get billingSaved => 'Guardado.';

  @override
  String get billingLevels => 'Niveles de suscripción';

  @override
  String get billingAddLevel => 'Añadir nivel';

  @override
  String get billingLevelValue => 'Nivel (1–100)';

  @override
  String get billingAllowCustom => 'Permitir un valor personalizado negociado';

  @override
  String get memberSubscriptionLabel => 'Suscripción';

  @override
  String get memberSubscriptionCustom => 'Personalizado (1–100)';

  @override
  String moneySubscriptionPct(int pct) {
    return 'Suscripción $pct %';
  }

  @override
  String percentValue(int value) {
    return '$value %';
  }

  @override
  String get memberOveragePolicyLabel => 'Cuando se acaban los días';

  @override
  String get memberOveragePolicyTooltip => 'Exceso de consumo';

  @override
  String get overagePolicyBlocked => 'Bloquear más reservas';

  @override
  String get overagePolicyPayg => 'Cobrar el exceso (pago por uso)';

  @override
  String get overagePolicyPackage => 'Exigir comprar un paquete';

  @override
  String get billingPackages => 'Paquetes de días';

  @override
  String get billingPackagesHint =>
      'Los miembros con plan de paquetes los compran cuando se les acaban los días.';

  @override
  String billingPackageSummary(int days, String price) {
    return '$days días · $price';
  }

  @override
  String get billingPackageName => 'Nombre';

  @override
  String get billingPackageDays => 'Días';

  @override
  String get billingPackagePrice => 'Precio';

  @override
  String get billingAddPackage => 'Añadir paquete';

  @override
  String get buyPackageButton => 'Comprar un paquete';

  @override
  String get buyPackageTitle => 'Comprar un paquete';

  @override
  String buyPackageDays(int days) {
    return '$days días';
  }

  @override
  String get buyPackageNone => 'Aún no hay paquetes disponibles.';

  @override
  String get buyPackageDone => 'Días añadidos — disfruta del tiempo extra.';

  @override
  String get payConfigTitle => 'Pagos en línea';

  @override
  String get payConfigOpen => 'Configurar';

  @override
  String get payConfigIntro =>
      'Introduce cada proveedor de pago que quieras ofrecer. Las claves se guardan de forma segura en el servidor y no se vuelven a mostrar. Consulta docs/design/payments-integration.md.';

  @override
  String get payConfigConfigured => 'Configurado';

  @override
  String get payConfigNotConfigured => 'Sin configurar';

  @override
  String get payConfigSecretSet => 'Definido — deja en blanco para conservar';

  @override
  String get payConfigSaved => 'Guardado.';

  @override
  String get payConfigRemove => 'Eliminar';

  @override
  String get payConfigRemoved => 'Eliminado.';

  @override
  String get payFieldClientId => 'Client ID';

  @override
  String get payFieldSecret => 'Secreto';

  @override
  String get payFieldEnv => 'Entorno';

  @override
  String get payFieldWebhookId => 'ID de webhook';

  @override
  String get payFieldReturnUrl => 'URL de retorno';

  @override
  String get payFieldSecretKey => 'Clave secreta';

  @override
  String get payFieldWebhookSecret => 'Secreto de firma del webhook';

  @override
  String get payFieldApiKey => 'Clave API';

  @override
  String get paymentProviderWero => 'Wero (con Mollie)';

  @override
  String get reservationExtendButton => 'Quedarse más tiempo';

  @override
  String get reservationExtendLaterOnly =>
      'Elige una hora posterior al final actual.';

  @override
  String get calendarMineTab => 'Mías';

  @override
  String get calendarEveryoneTab => 'Todos';

  @override
  String get calendarNoReservations => 'No hay reservas ese día.';

  @override
  String get calendarCancelOccurrence => 'Cancelar esta ocurrencia';

  @override
  String get calendarCancelFollowing => 'Cancelar esta y las siguientes';

  @override
  String get calendarPreviousMonth => 'Mes anterior';

  @override
  String get calendarNextMonth => 'Mes siguiente';

  @override
  String get calendarReservationActions => 'Acciones de la reserva';

  @override
  String get calendarShowOnPlan => 'Ver en el plano';

  @override
  String get calendarListView => 'Vista de lista';

  @override
  String get calendarTimelineView => 'Vista de cronología';

  @override
  String get calendarTimelineEmpty => 'No hay reservas en esta planta ese día.';

  @override
  String get calendarAllLevels => 'Todas las plantas';

  @override
  String get calendarTimelineAllEmpty =>
      'No hay reservas en ninguna planta ese día.';

  @override
  String calendarLevelCollapsed(String level) {
    return '$level, contraído';
  }

  @override
  String calendarLevelExpanded(String level) {
    return '$level, expandido';
  }

  @override
  String get appTitle => 'DesKilo';

  @override
  String get tabPlan => 'Plano';

  @override
  String get tabCalendar => 'Calendario';

  @override
  String get tabEvents => 'Eventos';

  @override
  String get tabMoney => 'Finanzas';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsSectionAdministration => 'Administración';

  @override
  String get settingsSectionPreferences => 'Preferencias';

  @override
  String get settingsSectionAdvanced => 'Avanzado';

  @override
  String get comingSoon => 'Próximamente';

  @override
  String get shellReserveButton => 'Reservar';

  @override
  String commonSavedTo(String path) {
    return 'Guardado en $path';
  }

  @override
  String get commonSaveFailed => 'No se pudo guardar el archivo.';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get settingsSectionAbout => 'Acerca de';

  @override
  String aboutVersion(String version) {
    return 'Versión $version';
  }

  @override
  String get aboutOpenSource => 'Open source (licencia 0BSD)';

  @override
  String get aboutOpenSourceDesc => 'Código fuente en GitHub';

  @override
  String get aboutPrivacy => 'Política de privacidad';

  @override
  String get aboutReportBug => 'Informar de un error / sugerir una función';

  @override
  String get aboutSupportTitle => 'Apoyar este proyecto';

  @override
  String get aboutSupportBody =>
      'Esta aplicación es gratuita, de código abierto y sin publicidad. Si te resulta útil, apoya al desarrollador.';

  @override
  String get consumptionAdd => 'Añadir consumo';

  @override
  String consumptionAddForMember(String name) {
    return 'Añadir servicio para $name';
  }

  @override
  String get consumptionService => 'Servicio';

  @override
  String get consumptionQuantity => 'Cantidad';

  @override
  String get consumptionPeriodLabel => 'Período de facturación (AAAA-MM)';

  @override
  String get consumptionNoServices => 'No hay servicios activos que registrar.';

  @override
  String get consumptionRecorded =>
      'Consumo registrado — pendiente de confirmación.';

  @override
  String get eventTypeServiceCharge => 'Servicio';

  @override
  String eventServiceChargeTitle(String name, int quantity, String amount) {
    return '$name ×$quantity — $amount';
  }

  @override
  String get coOwnerAction => 'Copropiedad';

  @override
  String get coOwnerNone => 'Sin rol de copropietario';

  @override
  String get coOwnerActive =>
      'Copropietario activo — permisos de propietario ya, sucesión automática';

  @override
  String get coOwnerPassive =>
      'Copropietario pasivo — se convierte en propietario al activarlo o cuando el propietario se va';

  @override
  String get coOwnerActivate => 'Promover a propietario ahora';

  @override
  String get memberCoOwnerChip => 'Copropietario';

  @override
  String get memberCoOwnerPassiveChip => 'Copropietario (pasivo)';

  @override
  String get developerMode => 'Modo desarrollador';

  @override
  String get developerModeWorkspaceHint =>
      'Se aplica a todos los miembros de este espacio.';

  @override
  String get developerTitle => 'Desarrollador';

  @override
  String get developerExport => 'Exportar registro';

  @override
  String get developerClear => 'Vaciar registro';

  @override
  String get developerEmpty => 'Aún no hay entradas de registro.';

  @override
  String get developerFilterAll => 'Todo';

  @override
  String get developerFilterErrors => 'Errores';

  @override
  String get developerFilterWarnings => 'Avisos+';

  @override
  String get pushStatusRegistered => 'Las notificaciones push están activas';

  @override
  String get pushStatusNotConfigured =>
      'Las notificaciones push aún no están configuradas';

  @override
  String get pushStatusNotConfiguredHint =>
      'El propietario completa la configuración de Firebase (guía push-setup).';

  @override
  String get notificationsSystemOff =>
      'Android está bloqueando las notificaciones de DesKilo';

  @override
  String get notificationsSystemOffHint =>
      'Permítelas en Ajustes del sistema → Aplicaciones → DesKilo → Notificaciones — la insignia del icono las necesita.';

  @override
  String get directoryTitle => 'Miembros';

  @override
  String get directoryEmpty => 'Aún no hay miembros.';

  @override
  String get directoryCheckedIn => 'Presente';

  @override
  String directoryCheckedInSeat(String seat) {
    return 'Presente · $seat';
  }

  @override
  String get directoryOnline => 'En línea';

  @override
  String get directoryReservedToday => 'Reservado hoy';

  @override
  String directoryLastSeenMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String directoryLastSeenHours(int hours) {
    return '$hours h';
  }

  @override
  String directoryLastSeenDays(int days) {
    return '$days d';
  }

  @override
  String get directoryWhatsapp => 'Chatear por WhatsApp';

  @override
  String get directoryOpenGroup => 'Abrir el grupo de WhatsApp';

  @override
  String get directoryClose => 'Cerrar';

  @override
  String get directoryReservedNow => 'Reservado ahora';

  @override
  String directoryReservedNowSeat(String seat) {
    return 'Reservado ahora · $seat';
  }

  @override
  String get directoryReservationsHeading => 'Reservas';

  @override
  String get directoryNoUpcoming => 'Sin reservas próximas';

  @override
  String get editorBackgroundImage => 'Imagen de fondo';

  @override
  String get editorBackgroundSet => 'Establecer imagen de fondo';

  @override
  String get editorBackgroundReplace => 'Reemplazar imagen de fondo';

  @override
  String get editorBackgroundRemove => 'Quitar imagen de fondo';

  @override
  String get editorTitle => 'Editor del espacio';

  @override
  String get editorOpenTooltip => 'Editar espacio';

  @override
  String get editorAddLevel => 'Añadir planta';

  @override
  String get editorNoLevels =>
      'Aún no hay plantas. Añade la primera planta de tu espacio.';

  @override
  String get editorLevelNameLabel => 'Nombre de la planta';

  @override
  String get editorRenameLevel => 'Renombrar';

  @override
  String get editorLevelActions => 'Acciones de la planta';

  @override
  String get editorDeleteLevelConfirm =>
      '¿Eliminar esta planta? Se eliminarán todas las oficinas, mesas y asientos que contiene.';

  @override
  String get editorToolSelect => 'Seleccionar';

  @override
  String get editorToolOffice => 'Oficina';

  @override
  String get editorToolDesk => 'Mesa';

  @override
  String get editorToolImage => 'Imagen';

  @override
  String get editorToolErase => 'Borrar';

  @override
  String get editorNewOffice => 'Nueva oficina';

  @override
  String get editorOfficeNameLabel => 'Nombre de la oficina';

  @override
  String get editorOfficeNameDefault => 'Oficina';

  @override
  String get editorDeskNameDefault => 'Mesa';

  @override
  String get editorDeskNameLabel => 'Nombre de la mesa';

  @override
  String get editorPlacementOverlap =>
      'Se superpone con un elemento existente.';

  @override
  String get editorPlacementOutside =>
      'Debe estar completamente dentro de una oficina.';

  @override
  String get editorOfficeProperties => 'Oficina';

  @override
  String get editorDeskProperties => 'Mesa';

  @override
  String get editorBookableAsWhole => 'Reservable en su totalidad';

  @override
  String get editorDeleteElementConfirm =>
      '¿Eliminar este elemento? Todo lo colocado sobre él también se eliminará.';

  @override
  String get editorToolSeat => 'Asiento';

  @override
  String get editorSeatProperties => 'Asiento';

  @override
  String get editorSeatNameLabel => 'Nombre del asiento';

  @override
  String get editorSeatNameDefault => 'Asiento';

  @override
  String get editorOrientationLabel => 'Dirección de asiento';

  @override
  String get editorChairLabel => 'Tipo de silla';

  @override
  String get editorAmenitiesLabel => 'Equipamiento';

  @override
  String get editorBlockedLabel => 'Bloqueado (mantenimiento)';

  @override
  String get editorSeatNoDesk =>
      'Los asientos solo pueden colocarse sobre una mesa.';

  @override
  String get amenityMonitor => 'Monitor';

  @override
  String get amenityStandingDesk => 'Mesa de pie';

  @override
  String get amenityWindow => 'Junto a la ventana';

  @override
  String get amenityDock => 'Estación de acoplamiento';

  @override
  String get amenityErgonomicChair => 'Silla ergonómica';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get editorAccessoriesLabel => 'Accesorios';

  @override
  String get editorNoAccessories =>
      'Todavía no hay accesorios — añádelos en Ajustes → Accesorios.';

  @override
  String get editorSeatNfcLabel => 'Etiqueta NFC/RFID';

  @override
  String get editorSeatNfcHelp =>
      'UID de la etiqueta en hexadecimal — dejar vacío para ninguna.';

  @override
  String get editorSeatNfcRead => 'Leer una etiqueta ahora';

  @override
  String get editorSeatNfcReadFailed =>
      'No se pudo iniciar el lector de etiquetas.';

  @override
  String get editorSeatNfcDuplicate =>
      'Esta etiqueta ya está vinculada a otra silla.';

  @override
  String get editorDeleteElementConfirmAudit =>
      '¿Eliminar este elemento? Todo lo colocado sobre él también se elimina. Las reservas que hacen referencia a él conservan una instantánea de texto para auditorías; las reservas abiertas se cancelan.';

  @override
  String get editorDeleteLevelConfirmAudit =>
      '¿Eliminar esta planta? Se eliminan todas las oficinas, mesas y asientos que contiene. Las reservas que hacen referencia a ellos conservan una instantánea de texto para auditorías; las reservas abiertas se cancelan.';

  @override
  String get eventsPendingHeader => 'Esperando tu confirmación';

  @override
  String get eventAccept => 'Aceptar';

  @override
  String get eventReject => 'Rechazar';

  @override
  String get eventsEmpty => 'Aún no hay eventos.';

  @override
  String get eventsFilterAll => 'Todos';

  @override
  String get eventTypeReservation => 'Reserva';

  @override
  String get eventTypePayment => 'Pago';

  @override
  String get eventTypeExpense => 'Gasto';

  @override
  String get eventTypeAdjustment => 'Ajuste';

  @override
  String eventReservationCreated(String actor, String target) {
    return '$actor reservó $target';
  }

  @override
  String eventReservationModified(String actor, String target) {
    return '$actor modificó la reserva de $target';
  }

  @override
  String eventReservationCancelled(String actor, String target) {
    return '$actor canceló la reserva de $target';
  }

  @override
  String eventPaymentSubmitted(String actor, String amount) {
    return '$actor registró un pago de $amount';
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
  String get pushPendingTitle => 'DesKilo';

  @override
  String get pushPendingBody => 'Alguien necesita tu confirmación.';

  @override
  String get pushCancelledTitle => 'Reserva eliminada';

  @override
  String get pushCancelledBody => 'Un admin eliminó una reserva.';

  @override
  String get eventTypeReservationDelete => 'Eliminación de reserva';

  @override
  String eventReservationDeleteLine(String actor, String date, String state) {
    return '$actor pide eliminar la reserva del $date ($state)';
  }

  @override
  String get eventReservationDeleteCheckedIn => 'registrada';

  @override
  String get eventReservationDeleteUnused => 'nunca usada';

  @override
  String get reservationDeleteRequestButton => 'Solicitar eliminación';

  @override
  String get reservationDeleteRequestExplain =>
      'Las reservas pasadas o con registro no se eliminan directamente. Un propietario o admin decidirá: ¿se olvidó simplemente el registro (la reserva se mantiene) o nunca se usó (se elimina)?';

  @override
  String get reservationDeleteReasonLabel => 'Motivo (opcional)';

  @override
  String get reservationDeleteSubmit => 'Enviar solicitud';

  @override
  String get reservationDeleteSubmitted =>
      'Eliminación solicitada — un propietario o admin decidirá.';

  @override
  String get notifCategoryCheckIns => 'Registros';

  @override
  String get notifCategoryMoney => 'Dinero';

  @override
  String get notifCategoryMembers => 'Miembros';

  @override
  String get notesFilterRead => 'Leídos';

  @override
  String get notifSortByDate => 'Ordenar por fecha';

  @override
  String get featuresTitle => 'Funciones';

  @override
  String get featureCalendarTab => 'Pestaña Calendario';

  @override
  String get featureCalendarTabDesc =>
      'Vista mensual de reservas y días de cierre.';

  @override
  String get featureEventsTab => 'Pestaña Eventos';

  @override
  String get featureEventsTabDesc => 'Actividad y confirmaciones pendientes.';

  @override
  String get featureMoneyTab => 'Pestaña Finanzas';

  @override
  String get featureMoneyTabDesc => 'Facturas mensuales, pagos y gastos.';

  @override
  String get featureServices => 'Servicios';

  @override
  String get featureServicesDesc =>
      'Catálogo de servicios y registro de consumos.';

  @override
  String get featurePdfExport => 'Exportar PDF';

  @override
  String get featurePdfExportDesc => 'Exportar la factura mensual como PDF.';

  @override
  String get featureSeriesBooking => 'Reserva en serie';

  @override
  String get featureSeriesBookingDesc =>
      'Repetir una reserva a diario, semanalmente o en días laborables.';

  @override
  String get featureBookForOthers => 'Reservar para otros';

  @override
  String get featureBookForOthersDesc =>
      'Los administradores y propietarios reservan sitios para otros miembros.';

  @override
  String get featurePushNotifications => 'Notificaciones push';

  @override
  String get featurePushNotificationsDesc =>
      'Entregar las confirmaciones pendientes en los dispositivos de los miembros.';

  @override
  String get featureAdminSeatBlocking =>
      'Los administradores pueden bloquear sitios';

  @override
  String get featureAdminSeatBlockingDesc =>
      'Los administradores marcan sitios como no reservables por mantenimiento. El propietario siempre puede.';

  @override
  String get featureAccessorySupplements => 'Suplementos de accesorios';

  @override
  String get featureAccessorySupplementsDesc =>
      'Facturar los accesorios de sitio con precio por media jornada reservada. Se aplica a las reservas desde la activación.';

  @override
  String get featureOnlinePayments => 'Pagos en línea';

  @override
  String get featureOnlinePaymentsDesc =>
      'Permite a los miembros pagar su factura en línea (PayPal). Requiere configurar el proveedor de pago en el servidor.';

  @override
  String get featureNfcBadges => 'Credenciales RFID / NFC';

  @override
  String get featureNfcBadgesDesc =>
      'Los miembros se registran en un quiosco acercando una tarjeta RFID/NFC. Requiere un dispositivo Android con NFC.';

  @override
  String get featureLevelBooking => 'Reservas de mesa, oficina y planta';

  @override
  String get featureLevelBookingDesc =>
      'Reservar una mesa, oficina o planta entera como una sola reserva, con precio por media jornada. Concede el derecho por miembro.';

  @override
  String get featureAdminLevelAssign => 'Los admins pueden asignar plantas';

  @override
  String get featureAdminLevelAssignDesc =>
      'Los admins asignan reservas de planta a los miembros. El propietario siempre puede.';

  @override
  String get featureKioskMode => 'Modo quiosco';

  @override
  String get featureKioskModeDesc =>
      'Cuentas de tableta de pared bloqueadas en el plano en vivo; los miembros actúan con credencial.';

  @override
  String get featureMembersDirectory => 'Directorio de miembros';

  @override
  String get featureMembersDirectoryDesc =>
      'La pestaña de comunidad: quién está, estados, presencia.';

  @override
  String get featureWhatsappIntegration => 'Integración con WhatsApp';

  @override
  String get featureWhatsappIntegrationDesc =>
      'Escribir a los miembros por WhatsApp y enlazar el grupo de la comunidad.';

  @override
  String get featureSpaceQrCodes => 'Códigos QR de espacios';

  @override
  String get featureSpaceQrCodesDesc =>
      'Tarjetas QR imprimibles por puesto, mesa, oficina y planta — escanea para reservar o fichar.';

  @override
  String featureRequires(String feature) {
    return 'Requiere $feature';
  }

  @override
  String get featureCoOwner => 'Copropietarios';

  @override
  String get featureCoOwnerDesc =>
      'Nombrar copropietarios: permisos de propietario ya (activo) o sucesión en espera (pasivo).';

  @override
  String get featureAutoCheckInOut =>
      'Entrada/salida automática al final del día';

  @override
  String get featureDataExport => 'Exportación de datos (Excel)';

  @override
  String get featureAutoCheckInOutDesc =>
      'Las reservas sin entrada o salida registradas se completan solas cuando pasa su horario.';

  @override
  String get featureDataExportDesc =>
      'Descargar todos los datos del espacio en un libro de Excel.';

  @override
  String get featureWorkingHours => 'Horario laboral';

  @override
  String get featureWorkingHoursDesc =>
      'Configura la jornada laboral y ofrece reservas por horas exactas; desactivado se aplican los valores 8:00–17:00.';

  @override
  String get featureInvoicePdfTemplate => 'Plantilla del PDF de factura';

  @override
  String get featureInvoicePdfTemplateDesc =>
      'Introducción y pie escritos por el propietario en el PDF de la factura. Nunca toca el XML de la factura electrónica.';

  @override
  String get featureMemberNotifications => 'Notificaciones entre miembros';

  @override
  String get featureMemberNotificationsDesc =>
      'Envía una notificación corta a otro miembro; los admins pueden notificar a todos los admins, incluido el propietario.';

  @override
  String get featureDunning => 'Recordatorios de pago (Mahnwesen)';

  @override
  String get featureDunningDesc =>
      'Reglas de recordatorio configurables y avisos «Recordatorio pendiente» en facturas vencidas. Nunca se envía nada automáticamente.';

  @override
  String get featureMemberReports => 'Informes de miembros';

  @override
  String get featureMemberReportsDesc =>
      'El acuerdo financiero y el informe mensual de pagos — autoservicio para miembros, enviables por miembro.';

  @override
  String get featureDeletionRequests =>
      'Solicitudes de eliminación de reservas';

  @override
  String get featureDeletionRequestsDesc =>
      'Los miembros pueden SOLICITAR la eliminación de una reserva pasada o registrada; un propietario/admin valida. Desactivado, esas reservas no se pueden eliminar.';

  @override
  String get featurePlanObjectDeleteTitle => 'Eliminar espacios con historial';

  @override
  String get featurePlanObjectDeleteDesc =>
      'Los propietarios pueden eliminar plantas, oficinas, mesas y asientos aunque reservas pasadas hagan referencia a ellos: las reservas conservan una instantánea de texto para auditorías e informes.';

  @override
  String get helpTitle => 'Ayuda';

  @override
  String get helpContents => 'Índice';

  @override
  String get inviteSectionTitle => 'Invitar a alguien';

  @override
  String get inviteViaWhatsapp => 'WhatsApp';

  @override
  String get inviteViaSms => 'SMS';

  @override
  String get inviteViaShare => 'Compartir…';

  @override
  String get inviteFirstNameLabel => 'Nombre (opcional)';

  @override
  String get inviteLastNameLabel => 'Apellido (opcional)';

  @override
  String get invitePhoneLabel => 'Teléfono (opcional, con prefijo)';

  @override
  String get inviteLanguageLabel => 'Idioma del mensaje';

  @override
  String get inviteSendFailed =>
      'No se pudo abrir la aplicación de envío. El mensaje se copió en su lugar.';

  @override
  String get inviteCreateFailed =>
      'No se pudo crear la invitación. Comprueba tu conexión e inténtalo de nuevo.';

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
  String get invitationTemplateTitle => 'Mensaje de invitación';

  @override
  String get invitationTemplateHelp =>
      'Se envía al invitar a alguien por WhatsApp, SMS o compartir. Déjalo vacío para usar el mensaje integrado en el idioma elegido. Etiquetas disponibles:';

  @override
  String get invitationTemplateHint =>
      'Mensaje de invitación personalizado usando las etiquetas de arriba…';

  @override
  String get workspaceInvitePasteHint =>
      'Pega el mensaje de invitación completo — el ID se detecta automáticamente.';

  @override
  String get workspaceInviteCodeInvalid =>
      'No se encontró ningún ID — pega la invitación o escribe el ID.';

  @override
  String get invoicesTitle => 'Facturas';

  @override
  String get invoicesEmpty => 'Aún no hay facturas.';

  @override
  String get invoiceCreate => 'Nueva factura';

  @override
  String get invoiceMemberLabel => 'Miembro';

  @override
  String get invoiceIssue => 'Emitir factura';

  @override
  String get invoiceIssued => 'Factura emitida.';

  @override
  String get invoiceDownload => 'Descargar PDF';

  @override
  String get invoiceShare => 'Compartir PDF';

  @override
  String get invoicePdfTitle => 'Factura';

  @override
  String get invoicePdfIssuedOn => 'Emitida el';

  @override
  String get invoicePdfIssuedBy => 'Emitida por';

  @override
  String get invoicePdfBilledTo => 'Facturar a';

  @override
  String get invoicePdfSignature => 'Firma digital (SHA-256)';

  @override
  String get addressTitle => 'Dirección';

  @override
  String get addressNone => 'Sin dirección';

  @override
  String get addressSaved => 'Dirección guardada';

  @override
  String get workspaceAddressLabel => 'Dirección del espacio';

  @override
  String get featureInvoicing => 'Facturas';

  @override
  String get featureInvoicingDesc =>
      'Facturas inmutables y firmadas en un archivo — descarga o comparte en PDF.';

  @override
  String get featureAdminInvoicing => 'Los admins emiten facturas';

  @override
  String get featureAdminInvoicingDesc =>
      'Los admins también emiten facturas. El propietario siempre puede.';

  @override
  String get invoiceVoidedChip => 'Errónea';

  @override
  String get invoiceVoidAction => 'Marcar como errónea';

  @override
  String invoiceVoidConfirm(String number) {
    return '¿Marcar la factura $number como errónea? Esta acción no se puede deshacer.';
  }

  @override
  String get invoiceVoided => 'Factura marcada como errónea.';

  @override
  String get invoiceReplaceAction => 'Emitir reemplazo';

  @override
  String get invoicePdfVoided => 'ERRÓNEA — anulada el';

  @override
  String get invoicePdfReplaces => 'Reemplaza a';

  @override
  String get invoiceNothingToInvoice =>
      'Nada registrado este mes — nada que facturar.';

  @override
  String get invoiceLineAdjustment => 'Ajuste';

  @override
  String get invoiceFilterAllMembers => 'Todos los miembros';

  @override
  String get invoiceFilterAllMonths => 'Todos los meses';

  @override
  String get invoiceFilterMonthLabel => 'Mes';

  @override
  String get invoiceSortTooltip => 'Ordenar';

  @override
  String get invoiceSortNewest => 'Más recientes primero';

  @override
  String get invoiceSortByMember => 'Por miembro';

  @override
  String get invoiceSortByMonth => 'Por mes';

  @override
  String get invoiceBalance => 'Saldo';

  @override
  String get invoiceDetailedToggle =>
      'Incluir el anexo detallado (asistencias, servicios, pagos)';

  @override
  String get invoicePdfDescription => 'Descripción';

  @override
  String get invoicePdfCharges => 'Cargos';

  @override
  String get invoicePdfPayments => 'Pagos';

  @override
  String get invoicePdfAnnex => 'Anexo — detalles';

  @override
  String get invoicePdfAttendance => 'Asistencias';

  @override
  String get invoicePdfActivity => 'Movimientos y pagos';

  @override
  String get invoicePdfReserved => 'reservado';

  @override
  String get invoicePdfPage => 'Página';

  @override
  String get invoiceRemindAction => 'Enviar un recordatorio';

  @override
  String get invoiceReminded => 'Recordatorio registrado.';

  @override
  String invoiceRemindedBadge(int count) {
    return 'Recordado ×$count';
  }

  @override
  String invoiceReminderMessage(String number, String amount) {
    return 'Recordatorio amistoso: factura $number — saldo pendiente $amount.';
  }

  @override
  String get invoiceEInvoiceDownload => 'Descargar factura electrónica (XML)';

  @override
  String get invoiceEInvoiceShare => 'Compartir factura electrónica (XML)';

  @override
  String get invoiceTabToInvoice => 'Por facturar';

  @override
  String get invoiceTabOpen => 'Abiertas';

  @override
  String get invoiceTabArchive => 'Archivo';

  @override
  String get invoiceIssueAll => 'Facturar todo';

  @override
  String get invoiceIssueOne => 'Facturar';

  @override
  String get invoiceAllCaughtUp => 'Todo al día — nada que facturar.';

  @override
  String get invoiceNoOpen => 'No hay facturas abiertas.';

  @override
  String invoiceSummaryToInvoice(int count) {
    return '$count por facturar';
  }

  @override
  String invoiceSummaryOpen(int count, String amount) {
    return '$count abiertas · $amount pendiente';
  }

  @override
  String invoiceOpenAge(int days) {
    return '$days días';
  }

  @override
  String invoiceIssuedCount(int count) {
    return '$count facturas emitidas.';
  }

  @override
  String get eventTypeInvoicePayment => 'Pago de factura';

  @override
  String eventInvoicePaid(String number, String amount) {
    return 'Factura $number pagada — $amount';
  }

  @override
  String get invoiceMatchAction => 'Marcar como pagada';

  @override
  String get invoiceMatchNoteLabel => 'Nota';

  @override
  String get invoiceMatchNoteRequired => 'Se requiere una nota.';

  @override
  String invoiceMatchOver(String excess) {
    return 'El miembro pagó $excess de más.';
  }

  @override
  String get invoiceMatchCreditNote =>
      'Crear una nota de crédito por el exceso';

  @override
  String get invoiceMatchForce => 'Aceptar de todos modos (justificar)';

  @override
  String invoiceMatchUnder(String missing) {
    return 'El miembro pagó $missing de menos — aceptar requiere una nota.';
  }

  @override
  String get invoiceMatched => 'Factura conciliada.';

  @override
  String get invoiceMatchPendingBadge => 'Pendiente de validación';

  @override
  String get invoiceMatchedBadge => 'Pagada';

  @override
  String get invoiceAlreadyInvoiced =>
      'Este mes ya está facturado para este miembro.';

  @override
  String get invoiceMatchPickPayment => 'Selecciona el pago registrado';

  @override
  String get invoiceMatchNoPayments =>
      'No hay pago registrado que conciliar — regístralo o confírmalo primero.';

  @override
  String get invoiceStatusOpen => 'Abierta';

  @override
  String invoiceCountShown(int count) {
    return '$count facturas';
  }

  @override
  String get invoiceFilterNoMatch =>
      'Ninguna factura coincide con estos filtros.';

  @override
  String get invoiceFilterClear => 'Borrar filtros';

  @override
  String get invoiceShowCancelled => 'Mostrar canceladas';

  @override
  String invoiceReplacedBy(String number) {
    return 'Sustituida por $number';
  }

  @override
  String invoiceMatchSummary(String amount, String date) {
    return 'Pagada $amount el $date';
  }

  @override
  String invoiceRemindedLast(String date) {
    return 'último recordatorio $date';
  }

  @override
  String invoiceAnnexSummary(int movements, int checkIns) {
    return 'Anexo: $movements movimientos, $checkIns registros de entrada';
  }

  @override
  String get invoicePickMember =>
      'Elige un miembro para ver lo que registró su mes.';

  @override
  String get invoiceRunningMonth =>
      'Este mes sigue en curso — sus posiciones aún pueden cambiar, y un mes solo se factura una vez.';

  @override
  String invoiceIssueAllConfirm(int count, String month, String total) {
    return '¿Emitir $count facturas de $month por $total en total? Una factura emitida ya no se modifica — un error se corrige con una sustitución.';
  }

  @override
  String invoiceIssuedPartial(int issued, int failed) {
    return '$issued emitidas, $failed con error.';
  }

  @override
  String get invoiceEInvoiceAction => 'Factura electrónica (XML)';

  @override
  String get invoiceEInvoiceExplain =>
      'La factura EN 16931 legible por máquina — el archivo que piden las administraciones y los clientes empresa.';

  @override
  String invoiceEInvoiceBusinessRoute(String channel, String format) {
    return 'Clientes empresa: envíala por $channel en formato $format.';
  }

  @override
  String invoiceEInvoicePublicRoute(String channel) {
    return 'Clientes del sector público: $channel.';
  }

  @override
  String get invoiceEInvoiceTransportPeppol =>
      'Un punto de acceso la entrega al cliente — sin plataforma pública de por medio.';

  @override
  String get invoiceEInvoiceTransportClearance =>
      'La plataforma nacional recibe la factura primero y la reenvía — enviarla directamente al cliente no es posible.';

  @override
  String get invoiceEInvoiceTransportAccredited =>
      'Una plataforma autorizada transporta la factura y comunica los datos a la administración tributaria por ti.';

  @override
  String get invoiceEInvoiceTransportBilateral =>
      'Ningún canal es obligatorio: correo, un portal o Peppol — lo que acuerdes con el cliente.';

  @override
  String invoiceEInvoiceFormatMismatch(String channel, String format) {
    return '$channel solo acepta $format: este archivo EN 16931 sirve para Peppol, compradores públicos y clientes extranjeros — tu plataforma o tu asesoría convierte el resto.';
  }

  @override
  String get invoiceEInvoiceReady => 'Listo — este archivo cumple EN 16931.';

  @override
  String get invoiceEInvoiceBlockedTitle =>
      'Un validador rechazaría este archivo:';

  @override
  String get invoiceEInvoiceIncompleteTitle =>
      'Válido, pero los perfiles nacionales estrictos piden además:';

  @override
  String get invoiceGapVatNotSupported =>
      'El espacio cobra IVA pero esta factura no lleva ningún tipo: añade tus tipos de IVA y vuelve a emitirla.';

  @override
  String get invoiceGapMissingVatId =>
      'Falta el número de IVA — un vendedor exento debe indicarlo.';

  @override
  String get invoiceGapMissingLegalId =>
      'Falta el número de registro (SIREN, HRB, CIF…) — nada te identifica en la factura.';

  @override
  String get invoiceGapMissingExemptionReason =>
      'Falta el motivo por el que no se cobra IVA.';

  @override
  String get invoiceGapMissingSellerCountry => 'Falta el país del espacio.';

  @override
  String get invoiceGapMissingBuyerCountry => 'Falta el país del cliente.';

  @override
  String get invoiceGapNoChargeLines =>
      'Esta factura no tiene ninguna línea de cargo — su mes quedó cubierto por los pagos, así que no hay nada que enviar.';

  @override
  String get invoiceGapMissingSellerCity =>
      'la ciudad de la dirección del espacio';

  @override
  String get invoiceGapMissingSellerPostalCode =>
      'el código postal de la dirección del espacio';

  @override
  String get invoiceEInvoiceFixIdentity => 'Completar la identidad legal';

  @override
  String get legalIdentityTitle => 'Identidad legal y facturación electrónica';

  @override
  String get legalIdentitySubtitle =>
      'Régimen de IVA y números de registro — exigidos por la factura electrónica';

  @override
  String get legalIdentityIntro =>
      'Lo que una factura electrónica EN 16931 debe indicar sobre ti. Las facturas ya emitidas conservan la identidad con la que se firmaron.';

  @override
  String get legalIdentityRegime => 'Régimen de IVA';

  @override
  String get legalIdentityRegimeNotSubject => 'Fuera del ámbito del IVA';

  @override
  String get legalIdentityRegimeExempt =>
      'Exento de IVA (régimen de franquicia)';

  @override
  String get legalIdentityRegimeVatRegistered => 'Sujeto a IVA (cobra IVA)';

  @override
  String get legalIdentityRegimeHint =>
      'El régimen decide qué número exige la norma: un número de registro fuera del ámbito del IVA, un número de IVA si está exento.';

  @override
  String get legalIdentityVatId => 'Número de IVA';

  @override
  String get legalIdentityLegalId => 'Número de registro';

  @override
  String get legalIdentityExemptionReason =>
      'Motivo por el que no se cobra IVA';

  @override
  String get legalIdentityStreet => 'Calle';

  @override
  String get legalIdentityCity => 'Ciudad';

  @override
  String get legalIdentityPostalCode => 'Código postal';

  @override
  String get legalIdentitySaved => 'Identidad legal guardada.';

  @override
  String get legalIdentityVatWarning =>
      'Este espacio cobra IVA pero no hay ningún tipo configurado: las facturas no muestran impuesto y la exportación XML sigue desactivada.';

  @override
  String get addressCountryLabel => 'País';

  @override
  String get addressVatIdLabel => 'Número de IVA (si facturas como empresa)';

  @override
  String get invoiceProformaAction => 'Factura proforma';

  @override
  String get invoicePdfProforma => 'Proforma';

  @override
  String get invoiceProformaShared => 'Proforma compartida.';

  @override
  String get invoiceProformaNothing =>
      'Nada registrado este mes — no hay proforma que enviar.';

  @override
  String get invoicePdfCopy => 'Copia';

  @override
  String get invoiceStatusPartiallyPaid => 'Parcialmente pagada';

  @override
  String get invoiceRegisterTitle => 'Registro de facturas';

  @override
  String get invoiceRegisterDate => 'Fecha';

  @override
  String get invoiceRegisterName => 'Nombre';

  @override
  String get invoiceRegisterAmount => 'Importe';

  @override
  String get invoiceRegisterTotal => 'Total';

  @override
  String get invoiceFacturXDownload => 'Descargar Factur-X (PDF)';

  @override
  String get invoiceFacturXShare => 'Compartir Factur-X (PDF)';

  @override
  String get invoiceFacturXExplain =>
      'Un solo archivo: la factura que lee una persona, con el XML legible por máquina dentro. Es lo que esperan la mayoría de las plataformas.';

  @override
  String get invoiceSendAction => 'Enviar a la plataforma gubernamental';

  @override
  String get invoiceSendAccepted => 'Enviada — la plataforma la aceptó.';

  @override
  String get invoiceSendCustomerAction => 'Enviar al servicio del cliente';

  @override
  String get invoiceSendCustomerAccepted =>
      'Enviada — el servicio del cliente la aceptó.';

  @override
  String get einvoiceCustomerSectionTitle => 'Servicio de entrega al cliente';

  @override
  String get einvoiceCustomerSectionHelp =>
      'Adónde van las facturas para el cliente: su punto de acceso Peppol, portal o la API acordada — separado de la plataforma gubernamental.';

  @override
  String get invoiceSendRejected => 'La plataforma la rechazó.';

  @override
  String invoiceSentOn(String date, String status) {
    return 'Enviada el $date · $status';
  }

  @override
  String get invoiceSendStatusAccepted => 'aceptada';

  @override
  String get invoiceSendStatusRejected => 'rechazada';

  @override
  String get invoiceSendStatusFailed => 'no transmitida';

  @override
  String get einvoiceConfigTitle => 'Plataforma de facturación electrónica';

  @override
  String get einvoiceConfigIntro =>
      'Donde DesKilo deposita tus facturas. Sirve cualquier plataforma que acepte una subida con un token — una plataforma autorizada, un punto de acceso Peppol, una plataforma nacional. El token se guarda en el servidor y nunca sale.';

  @override
  String get einvoiceConfigEndpoint => 'URL de subida';

  @override
  String get einvoiceConfigToken => 'Token o credencial';

  @override
  String get einvoiceConfigHeader =>
      'Cabecera de autenticación (Authorization por defecto)';

  @override
  String get einvoiceConfigField =>
      'Nombre del campo de archivo (file por defecto)';

  @override
  String get einvoiceConfigSaved => 'Plataforma guardada.';

  @override
  String get einvoiceConfigCleared => 'Plataforma eliminada.';

  @override
  String get einvoiceConfigClear => 'Eliminar la plataforma';

  @override
  String get einvoiceConfigTokenSet =>
      'Hay un token guardado (escribe uno nuevo para reemplazarlo).';

  @override
  String get invoiceAccountingExport => 'Exportación contable (SAF-T)';

  @override
  String get invoiceAccountingExportEmpty =>
      'No hay nada que exportar en este periodo.';

  @override
  String get invoiceRegisterYear => 'Año';

  @override
  String get invoiceRegisterAllYears => 'Todos los años';

  @override
  String get invoiceExportSafT => 'SAF-T (XML, internacional)';

  @override
  String get invoiceExportFec => 'FEC (Francia, exigido en una inspección)';

  @override
  String get invoiceExportChoose => 'Exportación contable';

  @override
  String get fecAccountsTitle => 'Cuentas a utilizar';

  @override
  String get fecAccountsIntro =>
      'Un FEC está hecho de asientos contables, así que necesita números de cuenta. Estas son las cuentas del plan contable francés — cámbialas por las de tu asesoría.';

  @override
  String get fecAccountCustomers => 'Clientes';

  @override
  String get fecAccountRevenue => 'Ventas';

  @override
  String get fecAccountBank => 'Banco';

  @override
  String get fecMissingSiren =>
      'El FEC se nombra con tu número de registro — rellénalo primero en Identidad legal.';

  @override
  String get invoiceEInvoiceStaleIdentity =>
      'Tu identidad legal ya está completa, pero esta factura se firmó antes y conserva aquello con lo que se emitió. Márcala como errónea y emite una sustitución para que lleve la nueva identidad.';

  @override
  String get einvoiceConfigUnavailable =>
      'No se pudo cargar la configuración de la plataforma. Comprueba la conexión e inténtalo de nuevo.';

  @override
  String get einvoiceEnvTitle => '¿Enviar a qué plataforma?';

  @override
  String get einvoiceEnvProd => 'Producción';

  @override
  String get einvoiceEnvUat => 'UAT (plataforma de prueba)';

  @override
  String get einvoiceEnvDev => 'Dev (plataforma de prueba)';

  @override
  String get einvoiceEnvProdHint => 'La transmisión real.';

  @override
  String get einvoiceEnvTestHint =>
      'Un ensayo — registrado como envío de prueba.';

  @override
  String invoiceSendAcceptedTest(String env) {
    return 'Envío de prueba aceptado ($env).';
  }

  @override
  String get einvoiceTestEnvsTitle => 'Entornos de prueba (UAT / Dev)';

  @override
  String get einvoiceTestEnvsHelp =>
      'Endpoints y tokens separados para ensayos. La opción aparece al enviar solo con el modo desarrollador activo.';

  @override
  String get einvoiceUatEndpoint => 'URL de subida UAT';

  @override
  String get einvoiceUatToken => 'Token o credencial UAT';

  @override
  String get einvoiceDevEndpoint => 'URL de subida Dev';

  @override
  String get einvoiceDevToken => 'Token o credencial Dev';

  @override
  String get invoiceSentTestChip => 'prueba';

  @override
  String get invoiceTemplateTitle => 'Plantilla del PDF de factura';

  @override
  String get invoiceTemplateHint =>
      'Tres bandas de informe renderizadas en el PDF — el XML de la factura electrónica nunca se toca. Condiciones y bucles Liquid, luego marcado de líneas:';

  @override
  String get invoiceTemplateIntroLabel =>
      'Introducción (sobre el bloque del destinatario)';

  @override
  String get invoiceTemplateFooterLabel =>
      'Pie (bajo los totales — condiciones de pago, menciones legales)';

  @override
  String get invoiceTemplateSaved => 'Plantilla de factura guardada.';

  @override
  String get invoiceTemplateHeaderLabel => 'Banda de cabecera';

  @override
  String get invoiceTemplateBodyLabel =>
      'Banda de cuerpo (las líneas de la factura)';

  @override
  String get invoiceTemplateReset => 'Restablecer al modelo por defecto';

  @override
  String get invoiceTemplatePreview => 'Vista previa';

  @override
  String get invoiceTemplateNoPreview =>
      'Emite primero una factura — la vista previa usa la más reciente.';

  @override
  String get reminderPdfTitleFriendly => 'Recordatorio de pago';

  @override
  String get reminderPdfTitleFirm => 'Recordatorio';

  @override
  String get reminderPdfOpeningFriendly =>
      'este es un recordatorio amistoso: la factura de abajo sigue abierta. Seguramente un simple despiste — sin problema.';

  @override
  String get reminderPdfOpeningFirm =>
      'a pesar de nuestro recordatorio anterior, la factura de abajo sigue sin pagar. Por favor, liquida el importe sin demora.';

  @override
  String get reminderPdfDaysOpen => 'Abierta desde hace';

  @override
  String get reminderPdfDays => 'días';

  @override
  String get reminderPdfLevelLabel => 'Nivel de recordatorio';

  @override
  String get reminderPdfClosing => 'Si ya has pagado, ignora esta carta.';

  @override
  String get dunningSettingsTitle => 'Reglas de recordatorio';

  @override
  String get dunningLevels => 'Número de niveles de recordatorio';

  @override
  String get dunningFirstAfterDays => 'Días hasta el primer recordatorio';

  @override
  String get dunningBetweenDays => 'Días entre recordatorios';

  @override
  String get dunningSaved => 'Reglas de recordatorio guardadas.';

  @override
  String dunningDueChip(int level) {
    return 'Recordatorio $level pendiente';
  }

  @override
  String get invoiceTemplateDocInvoice => 'Factura';

  @override
  String invoiceTemplateDocReminder(int level) {
    return 'Recordatorio $level';
  }

  @override
  String get reportPreviewTitle => 'Vista rápida — tu factura más reciente';

  @override
  String get reportPreviewSimulated => 'Vista rápida — datos de ejemplo';

  @override
  String get reportPresetClassic => 'Clásico';

  @override
  String get reportPresetFormalLetter => 'Carta formal';

  @override
  String get reportSubject => 'Asunto';

  @override
  String get reportRegards => 'Atentamente';

  @override
  String get invoiceTemplatePresets => 'Plantillas';

  @override
  String get invoiceTemplateQuickPreview => 'Vista rápida';

  @override
  String get invoiceTemplateDownload => 'Descargar PDF';

  @override
  String get invoiceTemplateShare => 'Compartir PDF';

  @override
  String get invoiceTemplateDocStatement => 'Extracto';

  @override
  String get reportPresetSimple => 'Sencillo';

  @override
  String get reportPresetVerbose => 'Detallado';

  @override
  String get invoiceLegalSection => 'Menciones de facturación';

  @override
  String get invoiceLegalIntro =>
      'Las menciones legales impresas en facturas y recordatorios. Las cláusulas de pago vacías usan los textos legales por defecto.';

  @override
  String get invoiceLegalFormField => 'Forma jurídica y capital';

  @override
  String get invoiceLegalFormHint => 'p. ej. SARL au capital de 7 500 €';

  @override
  String get invoiceLegalRegistrationField => 'Registro mercantil';

  @override
  String get invoiceLegalRegistrationHint =>
      'p. ej. RCS Saint-Brieuc 680 357 910';

  @override
  String get invoiceLegalPaymentTermsField => 'Condiciones de pago';

  @override
  String get invoiceLegalLatePenaltyField => 'Penalización por demora';

  @override
  String get invoiceLegalRecoveryField => 'Indemnización por costes de cobro';

  @override
  String get invoiceLegalEscompteField => 'Descuento por pronto pago';

  @override
  String get invoiceLegalInsuranceField => 'Seguro profesional';

  @override
  String get invoiceLegalSpecialField => 'Menciones particulares';

  @override
  String get invoiceLegalPaymentTermsDefault => 'Pago a la recepción.';

  @override
  String get invoiceLegalLatePenaltyDefault =>
      'Penalización por demora: tres veces el tipo de interés legal.';

  @override
  String get invoiceLegalRecoveryDefault =>
      'Indemnización fija por costes de cobro: 40 €.';

  @override
  String get invoiceLegalEscompteDefault => 'Sin descuento por pronto pago.';

  @override
  String get reportColUnitPrice => 'Precio unit.';

  @override
  String get reportColQty => 'Cant.';

  @override
  String get reportColTotal => 'Total';

  @override
  String get invoiceLegalKindField => 'Tipo de organización';

  @override
  String get invoiceLegalKindCompany => 'Empresa';

  @override
  String get invoiceLegalKindAssociation => 'Asociación (sin ánimo de lucro)';

  @override
  String get invoiceLegalAssociationHint =>
      'Las cláusulas de penalización, indemnización de cobro y descuento solo se imprimen si se rellenan — solo son obligatorias entre profesionales.';

  @override
  String get invoiceLegalFormHintAssociation => 'p. ej. Association loi 1901';

  @override
  String get invoiceLegalRegistrationHintAssociation =>
      'p. ej. RNA W123456789 · SIRET si está asignado';

  @override
  String get invoiceLegalAssociationReasonHint =>
      'p. ej. «TVA non applicable, art. 293 B du CGI» — o «Exonération de TVA, art. 261, 7-1° du CGI» para servicios a los miembros';

  @override
  String get reportEditorMarkup => 'Marcado';

  @override
  String get reportEditorVisual => 'Visual';

  @override
  String get reportInsertImage => 'Insertar imagen';

  @override
  String get reportImagesTitle => 'Imágenes de informes';

  @override
  String get reportImagesEmpty =>
      'Aún no hay imágenes — sube tu logotipo, un sello o una firma y refénciala con ![nombre].';

  @override
  String get reportImageUpload => 'Subir imagen';

  @override
  String get reportVisualAddLine => 'Añadir línea';

  @override
  String get reportLineTitle => 'Título';

  @override
  String get reportLineSection => 'Sección';

  @override
  String get reportLineText => 'Texto';

  @override
  String get reportLineSmall => 'Letra pequeña';

  @override
  String get reportLineRow => 'Fila de tabla';

  @override
  String get reportLineBoldRow => 'Fila en negrita';

  @override
  String get reportLineDivider => 'Separador';

  @override
  String get reportLineSpacer => 'Espaciado';

  @override
  String get reportLineImage => 'Imagen';

  @override
  String get reportLineColumns => 'Inicio/fin de columnas';

  @override
  String get reportLineColumnsSplit => 'Salto de columna';

  @override
  String get reportLineLogic => 'Lógica';

  @override
  String get reportDocAgreement => 'Acuerdo financiero';

  @override
  String get reportDocPayments => 'Informe de pagos';

  @override
  String get reportDocWorkspace => 'Informe del espacio';

  @override
  String get agreementExtraHalfDay => 'Media jornada extra';

  @override
  String get paymentsPendingTag => 'pendiente de validación';

  @override
  String get reportSectionFeatures => 'Funciones';

  @override
  String get reportSectionPrices => 'Precios';

  @override
  String get moneyMyAgreement => 'Mis condiciones';

  @override
  String get memberSendAgreement => 'Enviar el acuerdo financiero';

  @override
  String get reportQuickView => 'Vista rápida';

  @override
  String get reportDocWorkspaceSubtitle =>
      'Todo sobre el espacio — mediante la plantilla de espacio del editor de informes';

  @override
  String get reportTemplateLangDefault => 'Predeterminado (todos los idiomas)';

  @override
  String get reportLanguageAmbiguous =>
      'Este país tiene varios idiomas — define primero el idioma del espacio en los Ajustes del espacio.';

  @override
  String get reportDesignEmpty => 'Banda vacía — añade un elemento abajo.';

  @override
  String get invoiceStatusRemainderCancelled =>
      'Parcialmente pagada · saldo anulado';

  @override
  String get invoiceRemainingLabel => 'Pendiente';

  @override
  String get invoiceWriteoffButton => 'Anular el saldo pendiente';

  @override
  String get invoiceWriteoffExplain =>
      'El saldo impagado de esta factura se anulará y la factura se archivará como parcialmente pagada — cuando la validación lo confirme. Hasta entonces sigue abierta y adeudada.';

  @override
  String get invoiceWriteoffRequested =>
      'Anulación solicitada — pendiente de validación.';

  @override
  String get eventTypeInvoiceWriteoff => 'Anulación de saldo';

  @override
  String eventInvoiceWriteoffLine(String actor, String number, String amount) {
    return '$actor pide anular el saldo de $number — $amount';
  }

  @override
  String get invoicePdfCreditNote => 'Nota de crédito';

  @override
  String get invoiceStatusRefunded => 'Reembolsada';

  @override
  String get invoiceRefundLabel => 'A reembolsar';

  @override
  String get invoiceRefundButton => 'Registrar el reembolso';

  @override
  String invoiceRefundExplain(String amount) {
    return 'Esta nota de crédito significa que el ESPACIO debe $amount al miembro. Registra el reembolso pagado — el importe se imputa al saldo del miembro y el documento se cierra como Reembolsada.';
  }

  @override
  String get invoiceRefunded => 'Reembolso registrado.';

  @override
  String invoiceSummaryToRefund(int count, String amount) {
    return '$count por reembolsar · $amount';
  }

  @override
  String get eventTypeMemberJoin => 'Nuevo miembro';

  @override
  String get memberStatusPending => 'Pendiente';

  @override
  String get pendingApprovalTitle => 'Esperando aprobación';

  @override
  String pendingApprovalBody(String workspace) {
    return 'Te has unido a $workspace. Un administrador debe aprobar tu membresía antes de que puedas usar el espacio — tendrás acceso en cuanto confirme.';
  }

  @override
  String get pendingApprovalRefresh => 'Comprobar de nuevo';

  @override
  String get memberApprove => 'Aprobar membresía';

  @override
  String get memberRejectJoin => 'Rechazar membresía';

  @override
  String get workspaceConfigInvitations => 'Invitaciones';

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
  String get memberKioskLabel => 'Quiosco';

  @override
  String get memberMakeKiosk => 'Convertir en quiosco';

  @override
  String get memberUnmakeKiosk => 'Revertir quiosco a miembro';

  @override
  String get memberBadgesTooltip => 'Credenciales';

  @override
  String memberBadgesTitle(String name) {
    return 'Credenciales — $name';
  }

  @override
  String get badgeIssue => 'Nueva credencial';

  @override
  String get badgeTokenOnce =>
      'Guarda este QR ahora — solo se muestra una vez.';

  @override
  String get badgeNone => 'Aún no hay credenciales.';

  @override
  String get badgeDefaultLabel => 'Credencial';

  @override
  String get badgeRevoke => 'Revocar';

  @override
  String get badgeRevoked => 'Revocada';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get kioskCheckIn => 'Registrarse';

  @override
  String get kioskReserve => 'Reservar';

  @override
  String get kioskCheckOut => 'Salir';

  @override
  String get kioskPresentBadge => 'Presenta tu credencial';

  @override
  String get kioskBadgeHint =>
      'Escanea el QR de tu credencial o escribe su código.';

  @override
  String get kioskBadgeFieldLabel => 'Código de credencial';

  @override
  String get kioskBadgeConfirm => 'Confirmar';

  @override
  String get kioskBadgeRejected => 'Credencial no reconocida.';

  @override
  String get kioskDone => 'Listo — todo en orden.';

  @override
  String get kioskTapHint => 'Toca un asiento para registrarte';

  @override
  String get badgeSavePdf => 'Guardar como PDF';

  @override
  String get badgeRegisterCard => 'Registrar tarjeta';

  @override
  String get badgeTapCardTitle => 'Registrar una tarjeta';

  @override
  String get badgeTapCardHint =>
      'Acerca la tarjeta RFID/NFC a la parte trasera del dispositivo.';

  @override
  String get badgeCardRegistered => 'Tarjeta registrada.';

  @override
  String get badgeCardAlreadyRegistered => 'Esa tarjeta ya está registrada.';

  @override
  String get kioskBadgeHintNfc =>
      'Acerca tu tarjeta, escanea tu QR o escribe el código.';

  @override
  String get nfcConfigTitle => 'Credenciales RFID / NFC';

  @override
  String get nfcConfigIntro =>
      'Los miembros se registran en un quiosco de pared acercando una tarjeta RFID/NFC. Registra la tarjeta de cada miembro en Miembros y planes; en el quiosco la acercan para reservar o registrarse.';

  @override
  String get nfcConfigEnable => 'Activar registro por credencial NFC';

  @override
  String get nfcConfigEnableDesc =>
      'Muestra la opción de acercar la tarjeta en los quioscos y en el gestor de credenciales.';

  @override
  String get nfcConfigDeviceStatus => 'Este dispositivo';

  @override
  String get nfcConfigChecking => 'Comprobando…';

  @override
  String get nfcConfigDeviceReady => 'NFC disponible y activado';

  @override
  String get nfcConfigDeviceUnavailable =>
      'Sin NFC aquí — se necesita un dispositivo Android con NFC activado (los iPad no tienen NFC). Las credenciales QR siguen funcionando.';

  @override
  String get kioskConfirmAction => 'Confirmar';

  @override
  String get kioskRejectAction => 'Rechazar';

  @override
  String get kioskGateTitle => '¿Iniciar el modo quiosco?';

  @override
  String get kioskGateBody =>
      'Esta cuenta está configurada como quiosco del espacio. En modo quiosco la tableta solo muestra el plano para fichar con la tarjeta — no se puede abrir nada más. Para salir del modo quiosco, reinicia la tableta.';

  @override
  String get kioskGateStart => 'Iniciar el modo quiosco';

  @override
  String get kioskGateReject => 'Ahora no — abrir la app normalmente';

  @override
  String get settingsFrontCamera => 'Escanear con la cámara frontal';

  @override
  String get settingsFrontCameraDesc =>
      'Las tarjetas se leen con la cámara del lado de la pantalla — desactívalo para usar la cámara trasera.';

  @override
  String get kioskNfcOff =>
      'El NFC está desactivado en los ajustes de Android de esta tableta — actívalo para leer tarjetas RFID.';

  @override
  String get kioskNfcUnsupported =>
      'Esta tableta no tiene lector NFC — escanea la tarjeta QR en su lugar.';

  @override
  String get kioskNfcFailed =>
      'El lector RFID no se inició — reinicia la aplicación e inténtalo de nuevo.';

  @override
  String get nfcConfigDeviceOff =>
      'El NFC está desactivado en los ajustes de Android de este dispositivo — actívalo para leer tarjetas RFID.';

  @override
  String get kioskScanQr => 'Escanear la tarjeta QR';

  @override
  String get kioskRevertTitle => 'Dispositivo quiosco';

  @override
  String get kioskRevertDesc =>
      'Este perfil está configurado como quiosco del espacio. Reviértelo a miembro normal para que la pregunta de quiosco no aparezca al iniciar.';

  @override
  String get kioskRevertDone => 'Este perfil vuelve a ser un miembro normal.';

  @override
  String get memberNoActions =>
      'Solo el propietario del espacio puede modificar este miembro.';

  @override
  String get kioskNotCheckedIn =>
      'No hay ningún registro activo — puede que el plano se acabe de actualizar.';

  @override
  String get kioskRestOfDay => 'Resto del día';

  @override
  String get kioskPeriodCheckInHint =>
      '¿Hasta cuándo te quedas? El registro empieza ahora.';

  @override
  String get kioskPeriodReserveHint => 'Elige el periodo: solo hoy.';

  @override
  String get kioskCheckInRightAway => 'Registrarse ahora mismo';

  @override
  String get kioskCheckInRightAwayHint =>
      'Estás aquí: la reserva empieza registrada.';

  @override
  String get kioskPresentBadgeNext => 'Presentar la tarjeta';

  @override
  String get kioskReserveAndCheckIn => 'Reservar y registrarse';

  @override
  String get badgeDeleteConfirm =>
      '¿Eliminar definitivamente esta credencial revocada?';

  @override
  String get kioskClosedToday =>
      'El espacio está cerrado hoy — no es posible registrarse ni reservar.';

  @override
  String kioskBasis(String granularity, String hours) {
    return 'Regla: $granularity · hoy $hours';
  }

  @override
  String get languageTitle => 'Idioma';

  @override
  String get languageSystemDefault => 'Predeterminado del sistema';

  @override
  String get levelReserveButton => 'Reservar la planta';

  @override
  String get levelReserveTitle => 'Reservar la planta entera';

  @override
  String get levelPermissionTile => 'Reservas de planta';

  @override
  String get levelPermissionAllowed =>
      'Puede reservar una mesa, oficina o planta entera';

  @override
  String get levelPermissionDenied =>
      'No puede reservar una mesa, oficina o planta entera';

  @override
  String get levelBookableToggle => 'Reservable en su totalidad';

  @override
  String get levelBookableDesc =>
      'La planta entera puede reservarse como una sola reserva.';

  @override
  String get levelPriceLabel => 'Precio por media jornada';

  @override
  String get levelAssignMember => 'Para el miembro';

  @override
  String get levelAssignMyself => 'Yo mismo';

  @override
  String get levelSupplementLabel => 'Reservas de planta';

  @override
  String get levelNotAllowed =>
      'No tienes permiso para reservar una mesa, oficina o planta entera.';

  @override
  String get levelConflict => 'La planta tiene reservas en ese periodo.';

  @override
  String get bookingOnePlace =>
      'Ya tienes una reserva en ese periodo — un sitio a la vez.';

  @override
  String get bookingCheckedInElsewhere =>
      'Estás registrado en otro sitio — haz la salida allí primero.';

  @override
  String get spaceNotWholeBookable =>
      'Este espacio no está configurado para reserva completa — el propietario activa \"Reservable como un todo\" en el editor.';

  @override
  String get levelFeatureOff =>
      'Las reservas de oficina y planta están desactivadas en Funciones.';

  @override
  String get levelDetail => 'Planta entera';

  @override
  String get kioskLevelButton => 'Esta planta';

  @override
  String get officeSupplementLabel => 'Reservas de oficina';

  @override
  String get eventTypeSpaceReservation => 'Reservas de espacios enteros';

  @override
  String get deskDetail => 'Mesa entera';

  @override
  String get deskSupplementLabel => 'Reservas de mesa';

  @override
  String get editorLevelBookableOn => 'Reservable por completo';

  @override
  String get editorLevelBookableOff => 'No reservable por completo';

  @override
  String get membersTitle => 'Miembros y planes';

  @override
  String get membersPlanNone => 'Sin plan';

  @override
  String get memberRoleOwner => 'Propietario';

  @override
  String get memberRoleAdmin => 'Admin';

  @override
  String get memberStatusPaused => 'En pausa';

  @override
  String get memberStatusExited => 'Salido';

  @override
  String get membersInvite => 'Invitar a un miembro';

  @override
  String get profilesTitle => 'Perfiles';

  @override
  String get profilesAdd => 'Añadir un perfil';

  @override
  String get profilesActive => 'Perfil activo';

  @override
  String get memberRoleMember => 'Miembro';

  @override
  String get noteRefGone => 'Esta reserva ya no existe.';

  @override
  String get memberNoteDelete => 'Eliminar';

  @override
  String get memberNoteDeleteConfirm =>
      '¿Eliminar este mensaje? No se puede deshacer.';

  @override
  String get memberNoteReply => 'Responder';

  @override
  String get noteRefReservation => 'Vincular una reserva';

  @override
  String get noteRefSpace => 'Vincular un espacio';

  @override
  String get noteRefNoReservations => 'No hay reservas próximas que vincular.';

  @override
  String get noteRefWholeLevel => 'planta entera';

  @override
  String get memberMessagesAction => 'Mensajes';

  @override
  String get conversationEmpty => 'Aún no hay mensajes — ¡saluda!';

  @override
  String get whatsappNotesTitle => 'Recibir mensajes en WhatsApp';

  @override
  String get whatsappNotesSubtitle =>
      'Los mensajes de los miembros llegan también a WhatsApp.';

  @override
  String get messageLinkGone => 'Este mensaje está en tu bandeja de entrada.';

  @override
  String get whatsappNotesUnconfigured =>
      'Canal sin configurar — los mensajes llegan solo en la app y por push.';

  @override
  String get whatsappChannelTitle => 'Canal de WhatsApp';

  @override
  String get whatsappChannelConfigured =>
      'Canal configurado — los mensajes llegan también a WhatsApp, con sus enlaces; el enlace DesKilo abre la conversación en la app.';

  @override
  String get whatsappChannelNotConfigured =>
      'Sin configurar — los mensajes llegan solo en la app y por push.';

  @override
  String get whatsappChannelHelp =>
      '1. Crea una app (gratuita) en developers.facebook.com y añade el producto WhatsApp.\n2. En WhatsApp → Configuración de la API, copia el token de acceso permanente y el ID del número de teléfono.\n3. Pega ambos abajo — los mensajes de los miembros salen entonces desde ese número.\nNota: WhatsApp solo entrega dentro de las 24 h del último mensaje de WhatsApp del destinatario a tu número (su ventana de servicio).';

  @override
  String get whatsappChannelToken => 'Token de acceso';

  @override
  String get whatsappChannelPhoneId => 'ID del número de teléfono';

  @override
  String get whatsappChannelKeepHint =>
      'Déjalo en blanco para conservar el valor guardado.';

  @override
  String get whatsappChannelSaved => 'Canal de WhatsApp guardado.';

  @override
  String get notesFilterUnread => 'No leídos';

  @override
  String get notesFilterEmpty => 'No hay mensajes sin leer — todo al día.';

  @override
  String get moneyBaseFee => 'Suscripción base';

  @override
  String moneyUsage(int used, int included) {
    return '$used de $included medias jornadas usadas';
  }

  @override
  String moneyUsageUnlimited(int used) {
    return '$used medias jornadas usadas';
  }

  @override
  String moneyOverage(int count) {
    return 'Exceso ($count medias jornadas extra)';
  }

  @override
  String get moneyCredits => 'Pagos y créditos';

  @override
  String get moneyBalance => 'Saldo';

  @override
  String get moneyStatementSettled => 'Al día';

  @override
  String get moneyStatementOpen => 'Pendiente';

  @override
  String get moneyRecordPayment => 'Registrar un pago';

  @override
  String get moneyAmountLabel => 'Importe';

  @override
  String get moneyNoteLabel => 'Nota (opcional)';

  @override
  String get moneySubmitPayment => 'Enviar para confirmación';

  @override
  String get moneyPaymentPending => 'Pago enviado — esperando confirmación.';

  @override
  String get moneyLedgerHeader => 'Libro de cuentas';

  @override
  String get moneyLedgerEmpty => 'Aún no hay movimientos.';

  @override
  String get moneySubmitExpense => 'Enviar un gasto';

  @override
  String get moneyExpenseCategoryLabel => 'Categoría';

  @override
  String get moneyDescriptionLabel => 'Descripción';

  @override
  String get moneyExpensePending => 'Gasto enviado — esperando aprobación.';

  @override
  String get expenseCategoryCoffee => 'Café y cocina';

  @override
  String get expenseCategorySupplies => 'Material';

  @override
  String get expenseCategoryEquipment => 'Equipamiento';

  @override
  String get expenseCategoryOther => 'Otro';

  @override
  String get ledgerCategorySubscription => 'Suscripción';

  @override
  String get ledgerCategoryOverage => 'Exceso';

  @override
  String get ledgerCategoryExpense => 'Reembolso de gasto';

  @override
  String get ledgerCategoryPayment => 'Pago';

  @override
  String get ledgerCategoryAdjustment => 'Ajuste';

  @override
  String get ledgerCategoryService => 'Servicio';

  @override
  String get plansEditorTitle => 'Planes';

  @override
  String get plansEditorNew => 'Nuevo plan';

  @override
  String get plansEditorEdit => 'Editar plan';

  @override
  String get plansEditorInactive => 'Inactivo';

  @override
  String get plansEditorUnlimited => 'medias jornadas ilimitadas';

  @override
  String plansEditorQuota(int count) {
    return '$count medias jornadas';
  }

  @override
  String plansEditorPerExtra(String price) {
    return '$price/media jornada extra';
  }

  @override
  String get planNameLabel => 'Nombre';

  @override
  String get planBaseFeeLabel => 'Cuota mensual base';

  @override
  String get planIncludedLabel => 'Medias jornadas incluidas';

  @override
  String get planIncludedHelper => 'Dejar vacío para ilimitado';

  @override
  String get planOverageLabel => 'Precio por media jornada extra';

  @override
  String get planActiveLabel => 'Activo';

  @override
  String get paymentMethodBankTransfer => 'Transferencia';

  @override
  String get paymentMethodCash => 'Efectivo';

  @override
  String get paymentMethodPaypal => 'PayPal';

  @override
  String get paymentMethodTwint => 'TWINT';

  @override
  String get paymentMethodCard => 'Tarjeta';

  @override
  String get paymentMethodOther => 'Otro';

  @override
  String get paymentMethodWero => 'Wero';

  @override
  String get paymentMethodLydia => 'Lydia';

  @override
  String get paymentMethodWise => 'Wise';

  @override
  String get moneyPaymentDateLabel => 'Fecha del pago';

  @override
  String get moneyPaymentPeriodLabel => 'Se aplica a';

  @override
  String get moneySectionPay => 'Pagar';

  @override
  String get moneySectionRequests => 'Solicitudes';

  @override
  String get moneySectionDocuments => 'Documentos';

  @override
  String get vatDeclTitle => 'Declaración de IVA';

  @override
  String get vatDeclPeriod => 'Periodo';

  @override
  String get vatDeclSeller => 'Vendedor';

  @override
  String get vatDeclVatId => 'NIF-IVA';

  @override
  String get vatDeclRate => 'Tipo';

  @override
  String get vatDeclNet => 'Base imponible';

  @override
  String get vatDeclVat => 'IVA';

  @override
  String get vatDeclInvoices => 'Facturas';

  @override
  String get vatDeclTotals => 'Totales';

  @override
  String get vatDeclBoxes => 'Casillas del formulario oficial';

  @override
  String get vatDeclBox => 'Casilla';

  @override
  String get vatDeclStatus => 'Estado';

  @override
  String get vatDeclDisclaimer =>
      'Generada a partir de las facturas emitidas del periodo. Verifíquela con su contabilidad antes de presentarla — es una ayuda, no asesoría fiscal.';

  @override
  String get vatDeclGenerate => 'Generar';

  @override
  String get vatDeclEmpty =>
      'Aún no hay declaraciones — elija un periodo y genere la primera.';

  @override
  String get vatDeclDraft => 'Borrador';

  @override
  String get vatDeclSubmitted => 'Presentada';

  @override
  String get vatDeclTransmit => 'Transmitir';

  @override
  String get vatDeclMarkFiled => 'Marcar como presentada';

  @override
  String get vatDeclMarkFiledConfirm =>
      'Confirme que presentó esta declaración usted mismo (portal de Hacienda o su gestor). Se vuelve inmutable.';

  @override
  String get vatDeclXml => 'Exportar XML';

  @override
  String get vatDeclPdf => 'PDF';

  @override
  String get vatDeclSent => 'Declaración transmitida.';

  @override
  String get vatDeclRejected => 'La plataforma rechazó la declaración.';

  @override
  String get vatDeclRegimeGate =>
      'Las declaraciones solo existen bajo el régimen sujeto a IVA — configúrelo en los ajustes de IVA.';

  @override
  String get featureVatManagementTitle => 'Gestión del IVA';

  @override
  String get featureVatManagementDesc =>
      'El editor de tipos de IVA y los selectores de tipo en servicios, bonos, accesorios y tarifas. Desactivado oculta la configuración; los tipos guardados siguen aplicándose.';

  @override
  String get featureVatDeclarationsTitle => 'Declaraciones de IVA';

  @override
  String get featureVatDeclarationsDesc =>
      'Generar la declaración periódica de IVA desde las facturas emitidas, mapearla al formulario oficial y transmitirla o exportarla.';

  @override
  String get featureEinvoiceCustomerDeliveryTitle =>
      'Entrega de facturas al cliente';

  @override
  String get featureEinvoiceCustomerDeliveryDesc =>
      'Un segundo canal de envío junto a la plataforma gubernamental: transmitir la factura emitida directamente al servicio de facturación del cliente.';

  @override
  String priceVatIncluded(String rate) {
    return 'IVA $rate incl.';
  }

  @override
  String billingPricesVatHint(String rate) {
    return 'Los precios son brutos — el IVA $rate (tipo por defecto del espacio) está incluido.';
  }

  @override
  String billingTariffVatHint(String rate) {
    return 'Los precios son con IVA incluido — IVA $rate (tipo de las tarifas).';
  }

  @override
  String get billingNewPackage => 'Nuevo bono';

  @override
  String get priceGrossHint =>
      'Precio bruto — lo que paga el miembro; el IVA está dentro.';

  @override
  String vatShareAmount(String amount) {
    return 'IVA incl. $amount';
  }

  @override
  String get reportDesignerDesign => 'Diseño';

  @override
  String get reportDesignerPreview => 'Vista previa';

  @override
  String get reportDesignerZoom => 'Zoom';

  @override
  String get reportDesignerZoomFit => 'Ajustar al ancho';

  @override
  String get planDurationLabel => 'Duración';

  @override
  String get planNoLevels => 'El espacio aún no tiene plano.';

  @override
  String get planLevelLabel => 'Planta';

  @override
  String get planCheckInTitle => 'Registrarse';

  @override
  String get planStartNow => 'Empieza ahora';

  @override
  String get planUntilLabel => 'Hasta';

  @override
  String get planCheckInButton => 'Registrarse';

  @override
  String get planCheckInNotYetError =>
      'El registro se abre 15 minutos antes del inicio.';

  @override
  String get planCheckInOverError =>
      'Esta reserva ha terminado — ya no es posible registrarse.';

  @override
  String planCheckInOpensAt(String time) {
    return 'El registro se abre a las $time';
  }

  @override
  String planCheckInFor(String name) {
    return 'Registrar a $name';
  }

  @override
  String get planOverruleRemove => 'Quitar la reserva (anular)';

  @override
  String planOverruleHint(String name) {
    return '$name y todos los admins serán notificados.';
  }

  @override
  String planOverruleDone(String name) {
    return 'Reserva eliminada — se notificó a $name.';
  }

  @override
  String get planCheckOutButton => 'Salir';

  @override
  String get planCancelReservationButton => 'Cancelar reserva';

  @override
  String get planSeatBlocked =>
      'Este asiento está bloqueado por mantenimiento.';

  @override
  String planReservedBy(String name) {
    return 'Reservado por $name';
  }

  @override
  String planOccupiedBy(String name) {
    return 'Ocupado por $name';
  }

  @override
  String planUntil(String time) {
    return 'hasta las $time';
  }

  @override
  String planCappedByNext(String time) {
    return 'El asiento está reservado a partir de las $time.';
  }

  @override
  String get planCheckInFailed =>
      'No se pudo registrar — puede que el asiento se acabe de ocupar.';

  @override
  String get planYourSeat => 'Tu asiento';

  @override
  String get planListViewTooltip => 'Vista de lista';

  @override
  String get planMapViewTooltip => 'Vista de plano';

  @override
  String get planNowButton => 'Ahora';

  @override
  String get planLevelTooltip => 'Planta';

  @override
  String get planReserveButton => 'Reservar';

  @override
  String get planReservationsEmpty => 'No hay reservas para este día.';

  @override
  String planStartsAt(String time) {
    return 'Empieza a las $time';
  }

  @override
  String get planRepeatLabel => 'Repetir';

  @override
  String get repeatNone => 'No se repite';

  @override
  String get repeatDaily => 'Cada día';

  @override
  String get repeatWeekdays => 'Cada día laborable';

  @override
  String get repeatWeekly => 'Semanalmente';

  @override
  String get planUntilDateLabel => 'Repetir hasta';

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
  String get commonOk => 'Aceptar';

  @override
  String get reminderTitle => 'Regístrate pronto';

  @override
  String reminderBody(String target, String time) {
    return '$target empieza a las $time';
  }

  @override
  String get planNoSeats => 'Esta planta aún no tiene asientos.';

  @override
  String get planStateFree => 'Libre';

  @override
  String get planStateYours => 'Tuyo';

  @override
  String get planBookForLabel => 'Reservar para';

  @override
  String get planSendForConfirmation => 'Enviar para confirmación';

  @override
  String planBookedForPending(String name) {
    return 'Enviado a $name para confirmación.';
  }

  @override
  String get planMakeNotReservable => 'Hacer no reservable';

  @override
  String get planMakeReservable => 'Hacer reservable';

  @override
  String get planAccessorySupplementHint =>
      'Los suplementos se aplican por media jornada.';

  @override
  String get planFromLabel => 'Desde';

  @override
  String get planToLabel => 'Hasta';

  @override
  String get planEndBeforeStart => 'El fin debe ser posterior al inicio.';

  @override
  String get planClosedDay => 'Cerrado este día';

  @override
  String get planClosedDayError => 'El espacio está cerrado ese día.';

  @override
  String get planMorningChip => 'Mañana';

  @override
  String get planAfternoonChip => 'Tarde';

  @override
  String get planFullDayChip => 'Día';

  @override
  String get planHalfDayError => 'Aquí las reservas son por media jornada.';

  @override
  String get a11ySeatFree => 'libre';

  @override
  String get a11ySeatReserved => 'reservado';

  @override
  String get a11ySeatOccupied => 'ocupado';

  @override
  String get a11ySeatMine => 'tu sitio';

  @override
  String get a11ySeatBlocked => 'no disponible';

  @override
  String get whatsappTitle => 'WhatsApp';

  @override
  String get whatsappNotShared => 'No compartido';

  @override
  String get whatsappFieldLabel => 'Número de WhatsApp';

  @override
  String get whatsappHint => '+34 612 34 56 78';

  @override
  String get whatsappHelper =>
      'Opcional. Visible para los miembros de tus espacios para que puedan contactarte por WhatsApp. Déjalo vacío para dejar de compartirlo.';

  @override
  String get whatsappSaved => 'Número de WhatsApp guardado';

  @override
  String get whatsappSaveFailed => 'No se pudo guardar el número de WhatsApp';

  @override
  String get profileStatusTitle => 'Estado';

  @override
  String get profileStatusNone => 'Sin estado';

  @override
  String get profileStatusFieldLabel => 'Estado';

  @override
  String get profileStatusHint => 'En una llamada · vuelvo a las 14:00';

  @override
  String get profileStatusHelper =>
      'Opcional. Visible para los miembros de tus espacios en el directorio de miembros. Déjalo vacío para borrarlo.';

  @override
  String get profileStatusSaved => 'Estado guardado';

  @override
  String get profileStatusSaveFailed => 'No se pudo guardar el estado';

  @override
  String get profilePhotoTitle => 'Foto';

  @override
  String get profilePhotoSet => 'Toca para cambiar';

  @override
  String get profilePhotoNone => 'Toca para añadir una foto';

  @override
  String get profilePhotoChoose => 'Elegir una foto';

  @override
  String get profilePhotoRemove => 'Quitar foto';

  @override
  String get profilePhotoSaved => 'Foto actualizada';

  @override
  String get profilePhotoRemoved => 'Foto eliminada';

  @override
  String get profilePhotoSaveFailed => 'No se pudo actualizar la foto';

  @override
  String get profilePhotoFileType => 'Imagen';

  @override
  String get settingsBillingReports => 'Facturación e informes';

  @override
  String get defaultPeriodTitle => 'Período de reserva predeterminado';

  @override
  String get defaultPeriodNone => 'Sin preferencia (día completo)';

  @override
  String get profilesDefault => 'Predeterminado al iniciar';

  @override
  String get profilesMakeDefault => 'Usar como predeterminado al iniciar';

  @override
  String get eventTypeRoleChange => 'Cambio de rol';

  @override
  String eventRolePromote(String actor) {
    return '$actor promueve a un miembro a admin';
  }

  @override
  String eventRoleDemote(String actor) {
    return '$actor degrada a un admin a miembro';
  }

  @override
  String get memberMakeAdmin => 'Hacer admin';

  @override
  String get memberMakeMember => 'Hacer miembro normal';

  @override
  String get memberRoleChangeRequested =>
      'Cambio de rol enviado para validación.';

  @override
  String get eventTypeQuota => 'Medias jornadas extra';

  @override
  String eventQuotaRequested(String actor, int halfDays, String period) {
    return '$actor solicita $halfDays medias jornadas extra para $period';
  }

  @override
  String get quotaExceededError =>
      'Cuota mensual de medias jornadas alcanzada — solicita medias jornadas extra desde la pestaña Finanzas.';

  @override
  String get quotaRequestButton => 'Solicitar medias jornadas extra';

  @override
  String get quotaRequestTitle => 'Solicitar medias jornadas extra';

  @override
  String quotaRequestExplainer(String period) {
    return 'Tus reservas están limitadas por tu suscripción. Las medias jornadas extra para $period se aplican una vez validadas.';
  }

  @override
  String get quotaRequestCountLabel => 'Número de medias jornadas';

  @override
  String get quotaRequestPending =>
      'Solicitud enviada — pendiente de validación.';

  @override
  String get memberReservationLimitTooltip => 'Límite de reservas';

  @override
  String get memberReservationLimitLabel => 'Límite de reservas';

  @override
  String get memberReservationLimitExplainer =>
      'Cuántas reservas abiertas puede tener este miembro a la vez.';

  @override
  String get memberReservationLimitNone => 'Sin límite';

  @override
  String get memberReservationLimitCustom => 'Personalizado (1–100)';

  @override
  String memberReservationLimitChip(int n) {
    return 'máx. $n';
  }

  @override
  String get reservationLimitError =>
      'Límite de reservas alcanzado — ya tienes el máximo de reservas abiertas.';

  @override
  String get memberPause => 'Pausar la membresía';

  @override
  String get memberReactivate => 'Reactivar la membresía';

  @override
  String get memberNotifyAction => 'Enviar notificación';

  @override
  String get memberNotifyAllAdmins => 'Notificar a todos los admins';

  @override
  String get memberAllAdmins => 'todos los admins';

  @override
  String memberNoteTitle(String name) {
    return 'Notificar a $name';
  }

  @override
  String get memberNoteHint => 'Tu mensaje';

  @override
  String get memberNoteSend => 'Enviar';

  @override
  String get memberNoteSent => 'Notificación enviada.';

  @override
  String memberNoteReceived(String name) {
    return 'Mensaje de $name';
  }

  @override
  String get eventsMessagesHeader => 'Mensajes';

  @override
  String memberNoteTo(String name) {
    return 'Para $name';
  }

  @override
  String get memberNoteToAllAdmins => 'Para todos los admins';

  @override
  String get memberNoteDeleted => 'Mensaje eliminado.';

  @override
  String get reserveMonthView => 'Mes';

  @override
  String monthFreeCount(int free, int total) {
    return '$free/$total';
  }

  @override
  String get reservationRecurring => 'Reserva recurrente';

  @override
  String get reservationEditTimes => 'Cambiar horario';

  @override
  String get reservationUpdatedSnack => 'Reserva actualizada.';

  @override
  String get reservationCancelledSnack => 'Reserva cancelada.';

  @override
  String get reserveDayView => 'Día';

  @override
  String get reserveWeekView => 'Semana';

  @override
  String get reserveFullDayChip => 'Día completo';

  @override
  String get reservePickDateTooltip => 'Elegir una fecha';

  @override
  String get reserveBookingFailed =>
      'No se pudo reservar — puede que el asiento se acabe de ocupar.';

  @override
  String get spaceScanNfcHint =>
      '…o acerca el teléfono a la etiqueta NFC de una silla.';

  @override
  String get spaceScanUnknownTag =>
      'Esta etiqueta no está vinculada a ninguna silla.';

  @override
  String get servicesTitle => 'Servicios';

  @override
  String get servicesEmpty => 'Aún no hay servicios.';

  @override
  String get servicesNew => 'Nuevo servicio';

  @override
  String get servicesEdit => 'Editar servicio';

  @override
  String get servicesName => 'Nombre';

  @override
  String get servicesPrice => 'Precio';

  @override
  String get servicesInactive => 'Inactivo';

  @override
  String get servicesActive => 'Activo';

  @override
  String get authContinueWith => 'o continuar con';

  @override
  String authSocialUnavailable(String provider) {
    return 'El inicio de sesión con $provider aún no está disponible — el servidor no lo ha activado.';
  }

  @override
  String get linkedAccountsTitle => 'Cuentas vinculadas';

  @override
  String get linkedAccountsIntro =>
      'Inicia sesión en esta cuenta con cualquiera de ellas. Añade Google, Microsoft, Apple o Facebook para entrar sin contraseña.';

  @override
  String get linkedAccountsLink => 'Vincular';

  @override
  String get linkedAccountsUnlink => 'Desvincular';

  @override
  String get linkedAccountsLinked => 'Vinculada';

  @override
  String get linkedAccountsLinkStarted =>
      'Continúa en el navegador para terminar la vinculación.';

  @override
  String get spaceScanTitle => 'Escanear un código de espacio';

  @override
  String get spaceScanHint =>
      'Apunta la cámara a la tarjeta de un puesto, mesa, oficina o planta — o escribe su código.';

  @override
  String get spaceScanField => 'Código';

  @override
  String get spaceScanInvalid =>
      'No es un código de espacio de este espacio de trabajo.';

  @override
  String get spaceScanUnknown =>
      'Este código ya no corresponde a ningún espacio aquí.';

  @override
  String get spaceSeatTaken => 'Ocupado';

  @override
  String get spaceNotBookable =>
      'Este espacio no está configurado para reservas completas.';

  @override
  String get spaceCodesTitle => 'Códigos QR de espacios (PDF)';

  @override
  String get spaceCodesDesc =>
      'Una tarjeta QR imprimible por puesto, mesa, oficina y planta — los miembros la escanean para reservar o fichar.';

  @override
  String get spaceKindDesk => 'Mesa';

  @override
  String get spaceKindOffice => 'Oficina';

  @override
  String get spaceKindLevel => 'Planta';

  @override
  String get spaceKindSeat => 'Puesto';

  @override
  String get spaceYoursNow => 'Reservado por ti para esta franja.';

  @override
  String get spaceCardSizeLabel => 'Tamaño de la tarjeta';

  @override
  String get spaceCardSizeSmall => 'Pequeña';

  @override
  String get spaceCardSizeMedium => 'Mediana';

  @override
  String get spaceCardSizeLarge => 'Grande';

  @override
  String get spaceCardInfoLabel => 'Información en la tarjeta';

  @override
  String get spaceCardInfoWorkspace => 'Espacio de trabajo';

  @override
  String get themeTitle => 'Tema';

  @override
  String get themeSystem => 'Predeterminado del sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String eventValidations(int current, int required) {
    return '$current/$required validaciones';
  }

  @override
  String eventValidatedBy(String name, String when) {
    return 'Validado por $name · $when';
  }

  @override
  String eventRejectedBy(String name, String when) {
    return 'Rechazado por $name · $when';
  }

  @override
  String get eventSystemDecider => 'Sistema';

  @override
  String get validationTitle => 'Reglas de validación';

  @override
  String get validationDefaultPolicy => 'Regla predeterminada';

  @override
  String get validationInherited => 'Hereda la predeterminada';

  @override
  String get validationCustomized => 'Personalizada';

  @override
  String get validationRequiredCount => 'Validaciones requeridas';

  @override
  String get validationAdminsMay => 'Los admins pueden validar';

  @override
  String get validationOwnerOnly => 'Solo el propietario';

  @override
  String get validationAllAdmins => 'Todos los admins';

  @override
  String get validationSpecificAdmins => 'Admins específicos';

  @override
  String get validationOwnerRequired => 'El propietario siempre debe validar';

  @override
  String get validationNotEnough => 'No hay suficientes validadores elegibles.';

  @override
  String get validationSaved => 'Regla de validación guardada.';

  @override
  String get vatTitle => 'IVA';

  @override
  String get vatIntro =>
      'En DesKilo los precios incluyen IVA. Añadir tipos no cambia nada de lo que pagan los miembros: el impuesto se extrae del precio que ya cobras y se muestra en la factura.';

  @override
  String get vatRegimeHint =>
      'Este espacio no está declarado como sujeto a IVA, así que las facturas no lo muestran. Eso se cambia en Identidad legal.';

  @override
  String get vatEmpty =>
      'Aún no hay ningún tipo: las facturas no muestran IVA.';

  @override
  String get vatSeed => 'Usar los tipos habituales';

  @override
  String get vatAddRate => 'Añadir un tipo';

  @override
  String get vatRateLabelField => 'Nombre';

  @override
  String get vatRatePercentField => 'Tipo %';

  @override
  String get vatRateDefaultTooltip =>
      'Tipo por defecto: lo usan las cuotas y todo lo que no tenga tipo propio';

  @override
  String get vatRateRemoveTooltip => 'Quitar';

  @override
  String get vatSaved => 'Tipos de IVA guardados.';

  @override
  String get vatNeedsDefault =>
      'Marca exactamente un tipo como predeterminado.';

  @override
  String get vatRateIncomplete =>
      'Cada tipo necesita un nombre y un porcentaje entre 0 y 99,99.';

  @override
  String get vatRatesTile => 'Tipos de IVA';

  @override
  String get vatAccountField => 'Cuenta de IVA';

  @override
  String get vatAccountHint =>
      'Cuenta donde la exportación contable registra el IVA recaudado. Vacío = 445710.';

  @override
  String get vatServiceRate => 'Tipo de IVA';

  @override
  String get vatServiceRateDefault => 'Tipo por defecto del espacio';

  @override
  String get vatPdfNet => 'Base';

  @override
  String get vatPdfVat => 'IVA';

  @override
  String get fecAccountVat => 'IVA recaudado';

  @override
  String get vatKeptRate =>
      'Un tipo que todavía usa una factura o un servicio se conserva, desactivado.';

  @override
  String get onboardingTitle => 'Bienvenido a DesKilo';

  @override
  String get onboardingCreateTab => 'Crear un espacio';

  @override
  String get onboardingJoinTab => 'Unirse a un espacio';

  @override
  String get workspaceNameLabel => 'Nombre del espacio';

  @override
  String get workspaceCountryLabel => 'País';

  @override
  String get workspaceCurrencyLabel => 'Moneda';

  @override
  String get workspaceTimezoneLabel => 'Zona horaria';

  @override
  String get onboardingCreateButton => 'Crear espacio';

  @override
  String get workspaceInviteCodeLabel => 'Código de invitación';

  @override
  String get onboardingJoinButton => 'Unirse';

  @override
  String get workspaceGenericError => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get countryNameDE => 'Alemania';

  @override
  String get countryNameAT => 'Austria';

  @override
  String get countryNameCH => 'Suiza';

  @override
  String get countryNameFR => 'Francia';

  @override
  String get countryNameIT => 'Italia';

  @override
  String get countryNameES => 'España';

  @override
  String get countryNamePT => 'Portugal';

  @override
  String get countryNameNL => 'Países Bajos';

  @override
  String get countryNameBE => 'Bélgica';

  @override
  String get countryNameLU => 'Luxemburgo';

  @override
  String get countryNameGB => 'Reino Unido';

  @override
  String get countryNameUS => 'Estados Unidos';

  @override
  String get workspaceCodeTitle => 'ID del espacio y QR';

  @override
  String get workspaceCodeLabel => 'ID del espacio';

  @override
  String get workspaceCodeHint => '4–20 letras o dígitos, único';

  @override
  String get workspaceCodeEdit => 'Cambiar el ID del espacio';

  @override
  String get workspaceCodeRejected =>
      'ID rechazado — debe tener 4–20 letras o dígitos y no estar ya en uso.';

  @override
  String get workspaceCodeExplainer =>
      'Los coworkers escanean este código QR — o escriben el ID — para unirse a este espacio.';

  @override
  String get workspaceCodeCopy => 'Copiar ID';

  @override
  String get workspaceCodeCopied => 'Copiado';

  @override
  String get inviteRoleMember => 'Invitación de miembro';

  @override
  String get inviteRoleAdmin => 'Invitación de admin';

  @override
  String get inviteAdminExplainer =>
      'Este código es de un solo uso: admite a UNA persona como admin y luego caduca. Entrégalo solo a la persona a la que está destinado.';

  @override
  String get inviteAdminNewCode => 'Nuevo código de admin';

  @override
  String get inviteOwnerNote =>
      'No existe invitación de propietario — solo un propietario puede conceder la propiedad, en Miembros y planes.';

  @override
  String get scanJoinTitle => 'Escanear QR del espacio';

  @override
  String get onboardingScanButton => 'Escanear código QR';

  @override
  String get scanJoinHelp =>
      'Apunta la cámara al QR de invitación — el código se toma y la unión se hace automáticamente.';

  @override
  String get workspaceCodeSharePng => 'Compartir como PNG';

  @override
  String get workspaceSettingsTitle => 'Espacio de coworking';

  @override
  String get workspaceSettingsSaved => 'Espacio guardado.';

  @override
  String get workspaceSettingsCurrencyHelper =>
      'Se propone según el país — cámbiala si tu comunidad factura en otra moneda.';

  @override
  String get paymentInstructionsTitle => 'Instrucciones de pago';

  @override
  String get paymentInstructionsHelper =>
      'Se muestran a los miembros en un extracto pendiente. Déjalo vacío para no mostrar nada.';

  @override
  String get paymentInstructionsPaypalLabel => 'Enlace o usuario de PayPal.me';

  @override
  String get paymentInstructionsReferenceLabel =>
      'Indicación de referencia del pago';

  @override
  String get paymentInstructionsIbanTitle => 'IBAN';

  @override
  String get paymentInstructionsIbanCopied => 'IBAN copiado.';

  @override
  String get paymentInstructionsWeroLabel => 'Número de teléfono de Wero';

  @override
  String get paymentInstructionsLydiaLabel =>
      'Número de teléfono o usuario de Lydia';

  @override
  String get paymentInstructionsWiseLabel => 'Wisetag o enlace de pago de Wise';

  @override
  String get paymentInstructionsValueCopied => 'Copiado al portapapeles.';

  @override
  String get workspaceWhatsappGroupTitle => 'Grupo de WhatsApp';

  @override
  String get workspaceWhatsappGroupHelper =>
      'Se muestra a los miembros para que puedan unirse al grupo de WhatsApp de la comunidad. Pega el enlace de invitación del grupo (https://chat.whatsapp.com/…). Déjalo vacío para no mostrar nada.';

  @override
  String get workspaceWhatsappGroupLabel => 'Enlace del grupo de WhatsApp';

  @override
  String get workspaceWhatsappGroupInvalid =>
      'Debe ser un enlace de invitación de chat.whatsapp.com';

  @override
  String get memberStatusActive => 'Activo';

  @override
  String get workspaceConfigPdfExport => 'Exportar configuración (PDF)';

  @override
  String get workspaceConfigPdfExportSubtitle =>
      'Instantánea completa: ajustes, todos los miembros y el plano.';

  @override
  String get workspaceConfigPdfTitle => 'Configuración del espacio';

  @override
  String workspaceConfigPdfGeneratedOn(String date) {
    return 'Generado el $date';
  }

  @override
  String get workspaceConfigOverview => 'Resumen';

  @override
  String get workspaceConfigMembersSection => 'Miembros';

  @override
  String get workspaceConfigFeatures => 'Funciones activadas';

  @override
  String get workspaceConfigAvailability => 'Disponibilidad';

  @override
  String get workspaceConfigFloorPlan => 'Plano';

  @override
  String get workspaceConfigGranularity => 'Granularidad de reserva';

  @override
  String get workspaceConfigColName => 'Nombre';

  @override
  String get workspaceConfigColRole => 'Rol';

  @override
  String get workspaceConfigColStatus => 'Estado';

  @override
  String get workspaceConfigOpenDays => 'Días de apertura';

  @override
  String get workspaceConfigClosures => 'Cierres';

  @override
  String get workspaceConfigBookableWhole => 'reservable en su totalidad';

  @override
  String get workspaceConfigSeats => 'Plazas';

  @override
  String get workspaceConfigEmptyLevel => 'Sin salas';

  @override
  String get workspaceConfigNone => 'Ninguno';

  @override
  String get workspaceDeskTransparencyTitle => 'Transparencia de mesas';

  @override
  String get workspaceDeskTransparencyHelper =>
      'Reduce la opacidad de las mesas para que se vea la foto de fondo de la planta.';

  @override
  String workspaceDeskOpacityValue(int percent) {
    return 'Opacidad: $percent %';
  }

  @override
  String get workspaceDangerZone => 'Zona de peligro';

  @override
  String get workspaceResetTitle => 'Restablecer el espacio';

  @override
  String get workspaceResetSubtitle =>
      'Elimina todas las reservas, las finanzas y el plano. Conserva ajustes y miembros.';

  @override
  String get workspaceResetDialogTitle => '¿Restablecer este espacio?';

  @override
  String get workspaceResetWarning =>
      'Esto elimina permanentemente todas las reservas, todos los datos financieros y del libro mayor, el registro de actividad y todo el plano — plantas, salas, mesas, plazas e imágenes. Se conservan los ajustes del espacio, los tramos de tarifa, la disponibilidad, las funciones, los catálogos y los miembros. No se puede deshacer.';

  @override
  String get workspaceResetConfirmPhrase => 'Acepto';

  @override
  String workspaceResetConfirmLabel(String phrase) {
    return 'Escribe «$phrase» para confirmar';
  }

  @override
  String get workspaceResetConfirmButton => 'Restablecer el espacio';

  @override
  String get workspaceResetDone => 'Espacio restablecido.';

  @override
  String get workspaceExcelExport => 'Exportar datos (Excel)';

  @override
  String get workspaceExcelExportSubtitle =>
      'Todos los datos en un libro: reservas, pagos, facturas, miembros y plano — una pestaña cada uno.';

  @override
  String get workspaceLanguageLabel => 'Idioma del espacio';

  @override
  String get workspaceLanguageHelper =>
      'Las invitaciones se redactan por defecto en este idioma.';

  @override
  String get workspaceLanguageUnset => 'Idioma de la app del remitente';

  @override
  String get workspacePaymentsBillingTitle => 'Pagos y facturación';

  @override
  String get paymentMethodsSubtitle =>
      'IBAN, PayPal, Wero, Lydia, Wise y la referencia de pago';

  @override
  String get featureDocuments => 'Biblioteca de documentos';

  @override
  String get featureDocumentsDesc =>
      'La biblioteca de documentos del espacio: estatutos, guías, estados financieros, actas — enlazados desde cualquier drive, visibles según el rol.';

  @override
  String get documentsTitle => 'Documentos';

  @override
  String get documentsAdd => 'Añadir un documento';

  @override
  String get documentsTitleLabel => 'Título';

  @override
  String get documentsUrlLabel => 'Enlace (https://…)';

  @override
  String get documentsUrlHelper =>
      'Pega el enlace de compartir de tu drive — los permisos se gestionan allí.';

  @override
  String get documentsProviderLabel => 'Almacenado en';

  @override
  String get documentsCategoryLabel => 'Categoría';

  @override
  String get documentsRoleLabel => 'Visible para';

  @override
  String get documentsRoleMember => 'Todos los miembros';

  @override
  String get documentsRoleAdmin => 'Admins y propietarios';

  @override
  String get documentsRoleOwner => 'Solo propietarios';

  @override
  String get documentsCategoryStatutes => 'Estatutos y legal';

  @override
  String get documentsCategoryGuides => 'Guías y manuales';

  @override
  String get documentsCategoryFinance => 'Estados financieros';

  @override
  String get documentsCategoryMinutes => 'Actas de reuniones';

  @override
  String get documentsCategoryOther => 'Otros documentos';

  @override
  String get documentsEmpty =>
      'Aún no hay documentos. Enlaza tus estatutos, guías y estados desde cualquier drive.';

  @override
  String get documentsDelete => '¿Quitar el documento?';

  @override
  String get documentsInvalid =>
      'Un documento necesita un título y un enlace https://.';

  @override
  String get featureRoleManagement => 'Gestión de roles';

  @override
  String get featureRoleManagementDesc =>
      'La matriz central rol→permiso: el propietario decide qué permiso tiene cada rol; los demás consultan los suyos. Desactivada, simplemente aplican los valores por defecto.';

  @override
  String get rolesTitle => 'Gestión de roles';

  @override
  String get rolesIntroEditor =>
      'El propietario siempre tiene todos los permisos. Decide aquí qué pueden hacer los demás roles: un copropietario puede tener menos que un propietario.';

  @override
  String get rolesIntroReadOnly =>
      'Solo lectura: estos son los permisos de cada rol. Tu rol está resaltado.';

  @override
  String get rolesYourRole => 'Tu rol';

  @override
  String get roleOwner => 'Propietario';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get roleMember => 'Miembro';

  @override
  String get permManageRoles => 'Gestionar roles y permisos';

  @override
  String get permManageMembers => 'Gestionar miembros';

  @override
  String get permManageValidation => 'Configurar reglas de validación';

  @override
  String get permWorkspaceSettings => 'Editar la configuración del espacio';

  @override
  String get permIssueInvoices => 'Emitir facturas y conciliar pagos';

  @override
  String get permViewFinances => 'Ver las finanzas del espacio';

  @override
  String get permManageDocuments => 'Gestionar la biblioteca de documentos';

  @override
  String get permManageServices => 'Gestionar servicios y paquetes';

  @override
  String get permApproveExpenses => 'Aprobar gastos';

  @override
  String get workspaceXmlExport => 'Exportar el espacio (XML)';

  @override
  String get workspaceXmlExportSubtitle =>
      'Ajustes y plano del espacio en un archivo para compartir. Sin miembros, reservas ni datos financieros.';

  @override
  String get workspaceXmlImport => 'Importar el espacio (XML)';

  @override
  String get workspaceXmlImportSubtitle =>
      'Restaurar los ajustes y el plano desde un archivo exportado. Sustituye el plano actual.';

  @override
  String get workspaceXmlFileTypeLabel => 'XML';

  @override
  String get workspaceXmlImportPreviewTitle => '¿Sustituir el plano?';

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
  String workspaceXmlImportPreviewAccessories(int count) {
    return 'Accesorios: $count';
  }

  @override
  String get workspaceXmlImportPreviewWarning =>
      'El plano actual se eliminará y sustituirá, y los ajustes del espacio se sobrescribirán. Esta acción no se puede deshacer.';

  @override
  String get workspaceXmlImportConfirm => 'Sustituir e importar';

  @override
  String get workspaceXmlImportSuccess => 'Espacio importado.';

  @override
  String get workspaceXmlErrorMalformed => 'El archivo no es un XML legible.';

  @override
  String get workspaceXmlErrorWrongRoot =>
      'Este no es un archivo de espacio de DesKilo.';

  @override
  String get workspaceXmlErrorUnsupportedVersion =>
      'El archivo fue exportado por una versión más reciente de DesKilo y no se puede importar.';

  @override
  String get workspaceXmlErrorMissingElement =>
      'El archivo está incompleto — falta una sección obligatoria.';

  @override
  String get workspaceXmlErrorMissingAttribute =>
      'El archivo está incompleto — falta un valor obligatorio.';

  @override
  String get workspaceXmlErrorInvalidValue =>
      'El archivo contiene un valor no válido y no se puede importar.';

  @override
  String get workspaceXmlErrorInvalidPlan =>
      'El plano del archivo no es válido: hay salas, mesas o puestos que se superponen o quedan fuera de su zona.';

  @override
  String get workspaceXmlImportReservationsError =>
      'Este espacio ya tiene reservas, por lo que su plano no se puede sustituir. Solo se puede importar antes de la primera reserva.';
}
