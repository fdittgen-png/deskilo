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
      'Medios días: las reservas cubren la mañana (hasta las 13:00), la tarde (desde las 13:00) o el día completo.';

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
  String get developerMode => 'Modo desarrollador';

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
  String get languageTitle => 'Idioma';

  @override
  String get languageSystemDefault => 'Predeterminado del sistema';

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
      'Quien escanee este código QR — o escriba este código — se unirá como admin. Compártelo solo con personas que deban gestionar este espacio.';

  @override
  String get inviteOwnerNote =>
      'No existe invitación de propietario — solo un propietario puede conceder la propiedad, en Miembros y planes.';

  @override
  String get scanJoinTitle => 'Escanear QR del espacio';

  @override
  String get onboardingScanButton => 'Escanear código QR';

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
