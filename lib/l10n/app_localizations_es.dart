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
  String get featureInvoiceAddressWindow => 'Ventanilla de dirección';

  @override
  String get featureInvoiceAddressWindowDesc =>
      'Coloca al destinatario donde lo muestra un sobre con ventanilla, para que una factura impresa pueda doblarse y enviarse. El lado sigue al país y puede cambiarse.';

  @override
  String get addressWindowTitle => 'Ventanilla de dirección';

  @override
  String get addressWindowSubtitle =>
      'Dónde se imprime el destinatario para que se vea por la ventanilla del sobre. El bloque mide 85 × 45 mm, a 45 mm del borde superior.';

  @override
  String get addressWindowCountry => 'Seguir el país';

  @override
  String get addressWindowLeft => 'Izquierda (DIN 5008)';

  @override
  String get addressWindowRight => 'Derecha (uso francés)';

  @override
  String get addressWindowOff => 'Sin ventanilla';

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
  String get availabilityPoliciesTitle => 'Políticas de reserva';

  @override
  String get policyAllowPastTitle => 'Permitir reservas pasadas';

  @override
  String get policyAllowPastDesc =>
      'Los miembros pueden registrar una reserva ya finalizada.';

  @override
  String get policyAdminCheckoutTitle =>
      'Los administradores pueden hacer el check-out de los miembros';

  @override
  String get policyAdminCheckoutDesc =>
      'Un administrador puede finalizar el check-in en curso de un miembro.';

  @override
  String get policyOutsideHoursTitle => 'Fuera del horario de apertura';

  @override
  String get policyOutsideHoursDesc =>
      'Qué puede ocurrir fuera de la jornada laboral: una sola respuesta, para todas las granularidades. Una reserva que toca el horario laboral es una reserva normal.';

  @override
  String get policyOutsideHoursOff => 'Prohibido';

  @override
  String get policyOutsideHoursOffDesc =>
      'Nada fuera del horario: ni reservas por adelantado, ni check-ins espontáneos, y una reserva que se pasa del fin de la jornada también se rechaza.';

  @override
  String get policyOutsideHoursWalkUp => 'Solo espontáneo';

  @override
  String get policyOutsideHoursWalkUpDesc =>
      'Los check-ins espontáneos siguen siendo posibles, incluidas las horas extra vespertinas; reservar por adelantado fuera del horario se rechaza.';

  @override
  String get policyOutsideHoursFree => 'Gratis';

  @override
  String get policyOutsideHoursFreeDesc =>
      'Permitido, nunca contado ni cobrado: pura información de presencia.';

  @override
  String get policyOutsideHoursCharged => 'De pago';

  @override
  String get policyOutsideHoursChargedDesc =>
      'Permitido y contado como uso normal, salvo los días en que el miembro ya tiene una reserva normal.';

  @override
  String get policySimultaneousTitle => 'Reservas simultáneas por miembro';

  @override
  String get policySimultaneousDesc =>
      'Cuántas reservas superpuestas puede tener un miembro. 1 mantiene un solo sitio a la vez.';

  @override
  String get policyLimitsTitle => 'Límites de reserva';

  @override
  String get policyLimitsDesc =>
      'Con cuánta antelación se puede reservar y qué duración se acepta. Rigen en todas las granularidades.';

  @override
  String get policyHorizonTitle => 'Horizonte de reserva';

  @override
  String get policyHorizonDesc =>
      'Cuántos días antes puede empezar una reserva. Más allá, se rechaza.';

  @override
  String get policyMinDurationTitle => 'Duración mínima';

  @override
  String get policyMinDurationDesc =>
      'La reserva más corta aceptada. Por eso llegar a las 11:45 para el límite de las 12:00 se rechaza por ser demasiado corta.';

  @override
  String get policyMaxDurationTitle => 'Duración máxima';

  @override
  String get policyMaxDurationDesc =>
      'La reserva más larga aceptada. Una reserva termina el día en que empieza, así que la jornada entera es el techo.';

  @override
  String get policyDurationConflict =>
      'El mínimo no puede superar al máximo — no se aceptaría ninguna reserva.';

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
  String get myBadgeTitle => 'Mi credencial';

  @override
  String get badgeSignInTitle => 'Iniciar sesión con la credencial';

  @override
  String get badgeSignInTapPrompt => 'Acerque su credencial al teléfono.';

  @override
  String get badgeSignInNoReader =>
      'No hay lector de credenciales en este dispositivo.';

  @override
  String get badgeSignInRetry => 'Reintentar';

  @override
  String badgeSignInHello(String name) {
    return 'Hola $name';
  }

  @override
  String get badgeSignInPinLabel => 'Su PIN';

  @override
  String get badgeSignInButton => 'Iniciar sesión';

  @override
  String get badgeSignInUseEmail => 'Usar mi correo en su lugar';

  @override
  String get badgeSignInRefused =>
      'No ha funcionado. Compruebe la credencial y el PIN, o inicie sesión con su correo.';

  @override
  String get badgeSignInLocked =>
      'Demasiados intentos. Espere unos minutos, o inicie sesión con su correo.';

  @override
  String get badgeSignInUnavailable =>
      'El inicio con credencial no está disponible ahora. Inicie sesión con su correo.';

  @override
  String get badgeSignInEntry => 'Iniciar sesión con una credencial';

  @override
  String get badgePinSectionTitle => 'Mi credencial';

  @override
  String get badgePinSet => 'PIN definido';

  @override
  String get badgePinNotSet => 'Sin PIN todavía';

  @override
  String get badgePinExplain =>
      'Su PIN le permite iniciar sesión escaneando su credencial en lugar de escribir su correo. Solo usted puede definirlo, y nadie — ni siquiera un propietario — puede leerlo.';

  @override
  String get badgePinSetAction => 'Definir un PIN';

  @override
  String get badgePinChangeAction => 'Cambiar el PIN';

  @override
  String get badgePinClearAction => 'Eliminar el PIN';

  @override
  String get badgePinNewLabel => 'Nuevo PIN';

  @override
  String get badgePinConfirmLabel => 'Repítalo';

  @override
  String get badgePinMismatch => 'Las dos entradas no coinciden.';

  @override
  String badgePinTooShort(int min) {
    return 'Use al menos $min dígitos.';
  }

  @override
  String get badgePinSaved => 'PIN guardado.';

  @override
  String get badgePinCleared =>
      'PIN eliminado. Sus credenciales ya no inician su sesión.';

  @override
  String get badgeAuthEnabledLabel => 'Inicia mi sesión';

  @override
  String get badgeAuthEnabledHint =>
      'Desactivado por defecto: una credencial que le registra la entrada no inicia su sesión hasta que usted lo decida.';

  @override
  String get badgeAuthNeedsPin =>
      'Defina primero un PIN de acceso — una credencial sola nunca debe bastar.';

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
  String get invoiceExportSafTPt => 'SAF-T (Portugal)';

  @override
  String get invoiceExportDatev => 'DATEV (Buchungsstapel)';

  @override
  String get invoiceExportSage => 'Sage 50 (registro de auditoría)';

  @override
  String get invoiceExportAccountantCsv => 'CSV contable';

  @override
  String get invoiceExportAuditTrail => 'Pista de auditoría';

  @override
  String get exportClaimRegulatory =>
      'El formato que pide su administración tributaria.';

  @override
  String get exportClaimExchange =>
      'Para que su asesor lo importe y lo revise — no es una declaración.';

  @override
  String get exportClaimSubset =>
      'Solo facturas y cobros, sin libro mayor. El archivo lo indica en su cabecera.';

  @override
  String get exportUncertifiedSoftware =>
      'Generado según la especificación publicada, pero DesKilo no es software certificado en este país — consulte con su asesor si se le exige.';

  @override
  String get datevAccountsTitle => 'Exportación DATEV';

  @override
  String get datevAccountsIntro =>
      'Su asesor le da los números de asesor y de cliente. DATEV rechaza un archivo cuyos números no coincidan — que es lo que evita que acabe en los libros de otra empresa.';

  @override
  String get datevConsultantNumber => 'Beraternummer (n.º de asesor)';

  @override
  String get datevClientNumber => 'Mandantennummer (n.º de cliente)';

  @override
  String get sageAccountsTitle => 'Exportación Sage';

  @override
  String get sageAccountsIntro =>
      'Los valores por defecto son las cuentas que Sage trae de serie. El código de IVA decide en qué declaración caen estos asientos: contrástelo con su asesor si no está en el tipo general.';

  @override
  String get sageTaxCode => 'Código de IVA (T1 / T0 / T9)';

  @override
  String get saftLedgerTitle => '¿Incluir asientos?';

  @override
  String get saftLedgerIntro =>
      'Con números de cuenta, el archivo lleva asientos por partida doble que su asesor puede importar en lugar de teclear. Cubren sus ventas y los cobros correspondientes — no toda su contabilidad.';

  @override
  String get saftDocumentsOnly => 'Solo documentos';

  @override
  String get saftWithPostings => 'Con asientos';

  @override
  String get billPdfTitle => 'Factura mensual';

  @override
  String get billPdfExport => 'Exportar la factura como PDF';

  @override
  String get reportCoaTitle => 'Plan de cuentas — vista previa';

  @override
  String get reportCoaIntro =>
      'Una sugerencia, no tu contabilidad. Son las cuentas que un contable de tu país usaría normalmente para un espacio como el tuyo.';

  @override
  String get reportCoaAccounts => 'Cuentas sugeridas';

  @override
  String get reportCoaNumber => 'Cuenta';

  @override
  String get reportCoaLabel => 'Nombre';

  @override
  String get reportCoaDisclaimer =>
      'Solo una vista previa. DesKilo no lleva libro mayor ni hace tu contabilidad — el plan de tu contable siempre manda.';

  @override
  String get reportBadgesTitle => 'Credenciales de los miembros';

  @override
  String get reportBadgesIntro =>
      'Corta por las líneas. Cada tarjeta lleva el código de un miembro — preséntala en el quiosco para registrarte.';

  @override
  String get reportBadgesFooter =>
      'Una credencial perdida se revoca en Miembros y planes, no basta con sustituirla.';

  @override
  String get reportSpaceCodesTitle => 'Códigos de los espacios';

  @override
  String get reportSpaceCodesIntro =>
      'Una tarjeta por puesto, mesa, sala y planta. Pega cada tarjeta en su espacio: escanearla abre la misma ficha que el quiosco.';

  @override
  String get reportSpaceCodesFooter =>
      'Una tarjeta que ya no corresponde a su espacio confunde a quien la escanea: vuelva a imprimir la hoja tras mover o renombrar un espacio.';

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
  String get billingRulesTitle => 'Calendario de facturación';

  @override
  String get billingRulesSubtitle =>
      'Cuándo salen las facturas de suscripción y de fin de mes';

  @override
  String get billingRulesSaved => 'Calendario de facturación guardado.';

  @override
  String get billingSubscriptionSection => 'Suscripción, por adelantado';

  @override
  String get billingSubscriptionAuto => 'Emitir automáticamente';

  @override
  String get billingSubscriptionOff =>
      'Activa «Facturas de suscripción» en Funciones para usarlo.';

  @override
  String get billingAdvanceDays => 'Días antes de que empiece el mes';

  @override
  String billingSubscriptionWhen(String day, String month) {
    return 'Emitida el $day para $month';
  }

  @override
  String get billingUsageSection => 'El mes recién terminado';

  @override
  String get billingUsageAuto => 'Emitir automáticamente';

  @override
  String get billingUsageOff =>
      'Activa «Facturas de fin de mes» en Funciones para usarlo.';

  @override
  String get billingUsageWhenZero => 'También cuando no hay nada que pagar';

  @override
  String get billingUsageWhenZeroHint =>
      'Envía un documento a cero, como confirmación de que la suscripción cubrió todo el mes.';

  @override
  String get invoiceKindSubscription => 'Suscripción, por adelantado';

  @override
  String get invoiceKindUsage => 'Los extras del mes';

  @override
  String get invoiceKindSettlement => 'Facturas agrupadas';

  @override
  String get invoiceKindFull => 'Mes completo';

  @override
  String get settlementRegroups => 'Esta factura agrupa';

  @override
  String get settlementVatNote =>
      'Las líneas y su IVA se toman de las facturas reagrupadas; la declaración de IVA cuenta las originales una sola vez.';

  @override
  String get settlementSettledBy =>
      'Agrupada en otra factura: esa es la que se debe y se reclama.';

  @override
  String get settlementAction => 'Agrupar en una factura';

  @override
  String settlementConfirm(int count, String amount) {
    return '¿Agrupar $count facturas en una de $amount?';
  }

  @override
  String settlementDone(String number) {
    return 'Agrupadas en $number.';
  }

  @override
  String get settlementNeedsTwo =>
      'Elige al menos dos facturas abiertas del mismo miembro.';

  @override
  String settlementFoldedIn(String number) {
    return 'Reagrupada en $number';
  }

  @override
  String get settlementDocumentationOnly =>
      'Solo documentación: toda operación se hace en la factura de reagrupación.';

  @override
  String get settlementSourcePdf => 'PDF (reagrupada)';

  @override
  String settlementRegroupsNumbers(String numbers) {
    return 'Reagrupa $numbers';
  }

  @override
  String invoicePdfSettledIn(String number) {
    return 'Reagrupada en $number';
  }

  @override
  String settlementPaidThrough(String number) {
    return 'Pagada a través de $number';
  }

  @override
  String get settlementAnnexTitle => '¿Adjuntar las facturas reagrupadas?';

  @override
  String get settlementAnnexAlone => 'Solo esta factura';

  @override
  String get settlementAnnexWith => 'Adjuntarlas';

  @override
  String settlementAnnexBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Las $count facturas que esta sustituye pueden seguirla, cada una en sus propias páginas y sellada como reagrupada.',
      one:
          'La factura que esta sustituye puede seguirla, en sus propias páginas y sellada como reagrupada.',
    );
    return '$_temp0';
  }

  @override
  String get reservationExtendButton => 'Quedarse más tiempo';

  @override
  String get reservationExtendLaterOnly =>
      'Elige una hora posterior al final actual.';

  @override
  String get reservationEndEarlyButton => 'Terminar antes';

  @override
  String get reservationEndEarlyAheadOnly =>
      'Elige una hora que aún esté por venir y anterior al final actual.';

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
  String get calendarWhoCanSee => 'Quién puede ver esto';

  @override
  String get calendarPrevious => 'Anterior';

  @override
  String get calendarNext => 'Siguiente';

  @override
  String get calendarDay => 'Día';

  @override
  String get calendarRange => 'Periodo';

  @override
  String get calendarMemberMe => 'Yo';

  @override
  String get calendarNothingHere => 'Nada en estas fechas.';

  @override
  String calendarLockedKinds(String kinds) {
    return 'No visible para usted para este miembro: $kinds';
  }

  @override
  String calendarEventTitle(String label) {
    return 'Aviso: $label';
  }

  @override
  String get calendarKindReservation => 'Reservas';

  @override
  String get calendarKindCheckIn => 'Registros';

  @override
  String get calendarKindCheckOut => 'Salidas';

  @override
  String get calendarKindEvent => 'Avisos';

  @override
  String get calendarKindMessage => 'Mensajes';

  @override
  String get calendarKindInvoice => 'Facturas';

  @override
  String get calendarKindPayment => 'Pagos';

  @override
  String get calendarKindConsumption => 'Consumos';

  @override
  String get calendarKindReminder => 'Recordatorios';

  @override
  String get accessNobodyElse => 'nadie más';

  @override
  String get accessRuleReservations =>
      'Todos los miembros del espacio — el plano muestra la ocupación a todos.';

  @override
  String get accessRuleEvents => 'Usted, el miembro que actuó y los admins.';

  @override
  String get accessRuleMessages =>
      'Solo las personas de la conversación — ningún rol puede leer una conversación de la que no forma parte.';

  @override
  String accessRuleFinances(String people) {
    return 'Usted y quienes tienen el permiso de finanzas: $people.';
  }

  @override
  String get accessRuleReminders => 'Solo usted.';

  @override
  String get accessLogTitle => 'Quién accedió a sus datos';

  @override
  String get accessLogEmpty =>
      'Nadie ha consultado sus finanzas ni sus mensajes.';

  @override
  String accessLogRow(String actor, String category, String subject) {
    return '$actor consultó $category de $subject';
  }

  @override
  String get calendarEventActionCreated => 'creada';

  @override
  String get calendarEventActionModified => 'modificada';

  @override
  String get calendarEventActionCancelled => 'cancelada';

  @override
  String get calendarEventActionSubmitted => 'enviada';

  @override
  String get calendarEventActionApproved => 'aprobada';

  @override
  String get calendarEventActionRejected => 'rechazada';

  @override
  String get calendarEventStatusPending => 'pendiente de confirmación';

  @override
  String get calendarEventStatusRejected => 'rechazado';

  @override
  String get calendarEventStatusExpired => 'caducado';

  @override
  String get accessKindNegotiations => 'Negociaciones de precios';

  @override
  String accessRuleNegotiations(String people) {
    return 'Tú, los propietarios y los admins de finanzas: $people. Cada lectura por otra persona queda registrada abajo.';
  }

  @override
  String get calendarViewAgenda => 'Agenda';

  @override
  String get calendarViewWeek => 'Semana';

  @override
  String get calendarViewMonth => 'Mes';

  @override
  String get calendarToday => 'Hoy';

  @override
  String get calendarTomorrow => 'Mañana';

  @override
  String get calendarYesterday => 'Ayer';

  @override
  String get calendarKindDue => 'Pagos por vencer';

  @override
  String get calendarKindScheduled => 'Gastos programados';

  @override
  String calendarDueTitle(String number) {
    return 'Pago vence · $number';
  }

  @override
  String calendarScheduledTitle(String name) {
    return 'Gasto programado · $name';
  }

  @override
  String get calendarClosedDay => 'Cerrado';

  @override
  String calendarClosedDayReason(String reason) {
    return 'Cerrado — $reason';
  }

  @override
  String get calendarGroupBookings => 'Reservas y presencia';

  @override
  String get calendarGroupActivity => 'Alertas y mensajes';

  @override
  String get calendarGroupMoney => 'Finanzas';

  @override
  String calendarAgendaEmpty(int days) {
    return 'Nada previsto en los próximos $days días.';
  }

  @override
  String calendarAgendaRange(int days) {
    return 'Próximos $days días';
  }

  @override
  String get calendarWeekEmpty => 'Nada esta semana.';

  @override
  String get calendarDayEmpty => 'Nada ese día.';

  @override
  String calendarItemCount(int count) {
    return '$count elementos';
  }

  @override
  String get calendarKindValidation => 'Validaciones';

  @override
  String calendarValidationValidated(String what) {
    return 'Validado: $what';
  }

  @override
  String calendarValidationRefused(String what) {
    return 'Rechazado: $what';
  }

  @override
  String get calendarEventActionValidated => 'validado';

  @override
  String get calendarEventActionRefused => 'rechazado';

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
  String get developerExportReservations => 'Exportar reservas';

  @override
  String get developerExportReservationsHint =>
      'Todas las reservas y entradas — pasadas, presentes y futuras, en cualquier estado — en CSV, para análisis y depuración.';

  @override
  String get pushStatusNoTransport =>
      'Esta versión no tiene notificaciones push';

  @override
  String get pushStatusNoTransportHint =>
      'Las notificaciones llegan en la app y como notificaciones locales en este dispositivo.';

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
    return 'Visto hace $minutes min';
  }

  @override
  String directoryLastSeenHours(int hours) {
    return 'Visto hace $hours h';
  }

  @override
  String directoryLastSeenDays(int days) {
    return 'Visto hace $days d';
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
  String get memberPageEmailAction => 'Correo';

  @override
  String get memberPageAddService => 'Añadir un servicio';

  @override
  String get memberPageNone => 'Ninguno';

  @override
  String memberPageWorkspaceDefaultValue(int count) {
    return 'Predeterminado del espacio ($count)';
  }

  @override
  String get memberPageLevelTitle => 'Reservas de una planta entera';

  @override
  String get memberPageGroupMembership => 'Membresía';

  @override
  String get memberPageGroupBooking => 'Reglas de reserva';

  @override
  String get memberPageGroupBilling => 'Facturación';

  @override
  String get memberPageGroupAccess => 'Tarjetas y acceso';

  @override
  String get memberPageManageHeading => 'Gestionar';

  @override
  String get memberPageStatusActive => 'Activo';

  @override
  String get memberPageNeverSeen => 'Nunca visto';

  @override
  String memberPageYou(String name) {
    return '$name (tú)';
  }

  @override
  String memberPageSince(String date) {
    return 'Socio desde el $date';
  }

  @override
  String memberPageCheckedIn(String seat, String time) {
    return 'Registrado · $seat · desde las $time';
  }

  @override
  String memberPageReservedNow(String seat, String time) {
    return 'Reservado ahora · $seat · hasta las $time';
  }

  @override
  String memberPageNext(String label) {
    return 'Próxima: $label';
  }

  @override
  String get memberPageNowHeading => 'Ahora mismo';

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
  String get eventAutoValidated => 'Validado automáticamente';

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
  String get notifGroupBy => 'Agrupar por';

  @override
  String get notifGroupByType => 'Tipo';

  @override
  String get notifGroupByDate => 'Fecha';

  @override
  String get notifGroupByUser => 'Miembro';

  @override
  String get notifUngroup => 'Desagrupar';

  @override
  String get validationScopeLabel => 'Quién valida';

  @override
  String get validationScopeAdmins => 'Los admins';

  @override
  String get validationScopeListed => 'Personas designadas';

  @override
  String get validationScopeMembers => 'Todos los miembros';

  @override
  String get validationScopeHint =>
      'El propietario siempre puede. Admins: todos los admins, o los que listes. Designadas: exactamente estas personas, sea cual sea su rol. Todos los miembros: cualquiera activo.';

  @override
  String get validationPickPersons => 'Elige las personas';

  @override
  String get eventTypeExpenseSchedule => 'Gasto programado';

  @override
  String eventExpenseScheduleLine(Object actor, Object amount, Object title) {
    return '$actor programa «$title» — $amount recurrente';
  }

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
  String get eventTypeExpenseRepartition => 'Gasto compartido';

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
      'Los miembros comparten su número de WhatsApp en su perfil; un toque en un miembro abre el chat; el enlace del grupo en el directorio. Sin integración de WhatsApp en el servidor.';

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
      'Mensajería entre miembros: conversaciones privadas y de grupo, confirmaciones de lectura, enlaces a una reserva o un espacio; los admins pueden notificar a todos los admins, propietario incluido.';

  @override
  String get featureDunning => 'Recordatorios de pago (Mahnwesen)';

  @override
  String get featureDunningDesc =>
      'Niveles y plazos de recordatorio configurables, una carta por nivel y avisos «Recordatorio pendiente» en las facturas atrasadas. El envío sigue siendo manual, salvo con los Recordatorios de pago automáticos.';

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
  String get featureNotificationGroupingTitle => 'Agrupación de notificaciones';

  @override
  String get featureNotificationGroupingDesc =>
      'Los miembros pueden agrupar el hilo de notificaciones por tipo, día o miembro; tocar el símbolo del grupo vuelve a la lista plana.';

  @override
  String get featureBookingPoliciesTitle => 'Políticas de reserva';

  @override
  String get featureBookingPoliciesDesc =>
      'Comportamiento de reserva configurable: reservas pasadas, reservas por minutos fuera de horario y check-out por administradores.';

  @override
  String get featureNfcSeatTagsTitle => 'Etiquetas NFC/RFID de las sillas';

  @override
  String get featureNfcSeatTagsDesc =>
      'Una etiqueta NFC/RFID física en una silla lleva a su asiento como la tarjeta QR impresa; el campo se rellena acercando el chip.';

  @override
  String get featureQrBadgesTitle => 'Credenciales QR';

  @override
  String get featureQrBadgesDesc =>
      'Tarjetas de credencial QR imprimibles para el quiosco, junto a las tarjetas NFC/RFID.';

  @override
  String get featureFormHelpHintsTitle => 'Consejos de ayuda';

  @override
  String get featureFormHelpHintsDesc =>
      'Un carrusel de consejos descartable en cada pantalla principal, y un pequeño ? junto a cada parámetro y campo — un toque abre la guía en la sección correcta. Restaurable desde Ajustes.';

  @override
  String get featureUiAnimationsTitle => 'Animaciones de la interfaz';

  @override
  String get featureUiAnimationsDesc =>
      'Transiciones suaves y animaciones de estado en toda la aplicación. Desactivado, cada cambio es instantáneo; el ajuste de reducción de movimiento del dispositivo siempre prevalece.';

  @override
  String get featureKioskMemberPhotosTitle =>
      'Fotos de los miembros en el quiosco';

  @override
  String get featureKioskMemberPhotosDesc =>
      'El recibo del quiosco muestra la foto de perfil del miembro: el control visual de credencial equivocada.';

  @override
  String get featurePlanMemberPhotosTitle =>
      'Fotos de los miembros en el plano';

  @override
  String get featurePlanMemberPhotosDesc =>
      'Los asientos ocupados en la pestaña Plano y en el centro Reservar muestran la foto de perfil del ocupante en lugar de la inicial.';

  @override
  String get featureBadgeSignInTitle => 'Iniciar sesión con credencial';

  @override
  String get featureBadgeSignInDesc =>
      'Los miembros pueden iniciar sesión escaneando su credencial e introduciendo su PIN, en lugar de escribir un correo en una tableta compartida. Cada miembro define su propio PIN y activa su propia credencial.';

  @override
  String get featureRegionalFormatsTitle => 'Región y formatos';

  @override
  String get featureRegionalFormatsDesc =>
      'Cada miembro elige cómo se le muestran los números, las fechas, el reloj y la zona horaria. Desactivado: todos leen en la región del idioma de la app, en 24 h, hora del espacio.';

  @override
  String get featureCalendarHubTitle => 'Calendario central';

  @override
  String get featureCalendarHubDesc =>
      'El calendario muestra todo lo fechado — reservas, registros, avisos, mensajes, facturas, pagos, consumos, recordatorios — para un día o un periodo, cada fila abre su origen. Desactivado: solo reservas.';

  @override
  String get featureDataAccessLogTitle => 'Registro de accesos a datos';

  @override
  String get featureDataAccessLogDesc =>
      'Cada miembro ve quién consultó sus finanzas y cuándo (lo escribe el servidor, nunca se omite). Desactivado: la fila se oculta, el registro se conserva.';

  @override
  String get featureMemberDataExportTitle => 'Exportación y borrado';

  @override
  String get featureMemberDataExportDesc =>
      'Cada miembro puede exportar sus datos en un archivo (RGPD art. 20) y abandonar el espacio con sus datos personales borrados (art. 17) desde Ajustes → Privacidad y datos.';

  @override
  String get featureFinanceFacesTitle => 'Finanzas en cuatro vistas';

  @override
  String get featureFinanceFacesDesc =>
      'La pestaña Finanzas se lee en cuatro vistas — Extracto, Pagos, Facturas, Documentos — bajo un mismo selector de mes, cada una con su ayuda. Desactivado: una sola columna.';

  @override
  String get featurePaymentRemindersTitle =>
      'Recordatorios de pago automáticos';

  @override
  String get featurePaymentRemindersDesc =>
      'Las facturas abiertas más allá del plazo configurado reciben sus niveles de recordatorio automáticamente — un aviso en el feed del miembro y una notificación, una vez al día. Desactivado: recordar sigue siendo una acción manual.';

  @override
  String get featureSupplyExpensesTitle => 'Suministros desde gastos';

  @override
  String get featureSupplyExpensesDesc =>
      'Un gasto puede ser un suministro para el espacio (cápsulas de café, bolsas de aspiradora…): validado, repone o crea un servicio consumible con precio unitario, y los consumos descuentan el stock.';

  @override
  String get featureValidationScopesTitle => 'Validadores por rol o persona';

  @override
  String get featureValidationScopesDesc =>
      'Cada regla de validación nombra quién valida: los admins, personas designadas de cualquier rol, o todos los miembros — y cuántos. Desactivado: propietario y admins como antes.';

  @override
  String get featurePriceNegotiationsTitle => 'Negociaciones de precios';

  @override
  String get featurePriceNegotiationsDesc =>
      'La tarifa es el valor por defecto; un miembro puede tener sus propias condiciones — cuota mensual, tarifa de exceso, descuento en suplementos, precios unitarios por servicio y paquete, porcentaje de ocupación — propuestas por quien tiene «Gestionar los acuerdos comerciales» y validadas según las reglas. Las ven el miembro, los propietarios y quienes tienen «Consultar los acuerdos comerciales»; cada consulta queda registrada.';

  @override
  String get featureScheduledExpensesTitle => 'Gastos programados';

  @override
  String get featureUniqueMonogramsTitle => 'Iniciales de avatar distintas';

  @override
  String get featureMessageGesturesTitle => 'Deslizar para citar o retirar';

  @override
  String get featureSubscriptionInvoicesTitle => 'Facturas de suscripción';

  @override
  String get featureSubscriptionInvoicesDesc =>
      'La cuota se factura antes del mes que paga, en la fecha que elijas. Desactivado: la cuota sigue en la factura del mes.';

  @override
  String get featureUsageInvoicesTitle => 'Facturas de fin de mes';

  @override
  String get featureUsageInvoicesDesc =>
      'Cuando el mes termina, lo que realmente costó más allá de la suscripción — excesos, suplementos, servicios — se factura aparte. Desactivado: eso sigue en la factura del mes.';

  @override
  String get featureInvoiceSettlementTitle => 'Agrupar facturas';

  @override
  String get featureInvoiceSettlementDesc =>
      'Varias facturas abiertas de un miembro pueden agruparse en una sola que paga. Las originales siguen en el archivo, trazables posición por posición, y dejan de reclamarse por separado.';

  @override
  String featureAlsoEnabled(String features) {
    return 'También activado: $features';
  }

  @override
  String featureAlsoEnables(String features) {
    return 'Activar esto también habilita $features';
  }

  @override
  String get featureHeldBack =>
      'Esperando a la función de arriba: actívala y esta vuelve a funcionar.';

  @override
  String get featureMessageGesturesDesc =>
      'Desliza un mensaje a la derecha para citarlo en tu respuesta; a la izquierda para retirar tu propio mensaje mientras nadie lo haya leído, tras una confirmación. Desactivado: los mensajes se borran manteniéndolos pulsados.';

  @override
  String get featureUniqueMonogramsDesc =>
      'Un avatar sin foto muestra iniciales que pertenecen a un solo miembro: inicial del nombre y del apellido, una letra más si dos coinciden, y números solo como último recurso. Desactivado: solo la primera letra, repetida en todos los que la comparten.';

  @override
  String get featureScheduledExpensesDesc =>
      'Gastos recurrentes (internet, teléfono, electricidad): cualquier miembro programa uno con su regla (cada X días/semanas/meses/años, X veces o hasta una fecha); la programación se valida una vez, y cada vencimiento se presenta al miembro — el importe validado cuenta de inmediato, un importe distinto se explica y pasa la validación de gastos.';

  @override
  String get featureInvoiceJourneyTitle => 'El recorrido de una factura';

  @override
  String get featureInvoiceJourneyDesc =>
      'Cada factura muestra dónde está — Emitida, Pago, Confirmación, Cerrada — y a quién le toca: el miembro paga, un admin confirma el pago declarado, el emisor lo concilia, los validadores deciden. El hub de emisores añade una banda de etapas con contadores y una explicación «Cómo funciona».';

  @override
  String get featureBookingGateTitle => 'Guarda de reserva';

  @override
  String get featureBookingGateDesc =>
      'Cada superficie de reserva — plano, vistas de día, semana y mes, hoja de reserva, quiosco, escaneo QR o NFC — comprueba los parámetros de disponibilidad antes de ofrecer una franja y nombra el motivo cuando no puede; los días cerrados se dibujan cerrados en cada vista, una leyenda nombra los estados de los puestos, y los admins pueden dar salida a un miembro donde la regla lo permite.';

  @override
  String get featureCalendarViewsTitle => 'Vistas del calendario';

  @override
  String get featureCalendarViewsDesc =>
      'La pestaña Calendario como agenda, semana y mes: marcadores por día según el tipo, días cerrados dibujados cerrados, cabeceras Hoy / Mañana, vencimientos de pago y gastos programados en el feed. Desactivado: el simple selector de día o rango sobre el feed.';

  @override
  String get featureMessagesHubTitle => 'Mensajes, renovados';

  @override
  String get featureMessagesHubDesc =>
      'Una sola barra de bandeja (Todos / No leídos / Archivados y búsqueda), fijar, silenciar, archivar y marcar como no leído en un hilo, la conversación como página completa con separadores de fecha, un menú adjuntar y un borrador guardado en el compositor, una persona abierta con un toque. Desactivado: la bandeja de dos barras y el hilo en hoja.';

  @override
  String get featureReportDesignerTitle => 'Diseñador de informes';

  @override
  String get featureReportDesignerDesc =>
      'El editor de informes a pantalla completa: elementos editados en su sitio con su tipografía real, arrastrar para reordenar, una paleta de inserción, un selector de campos con búsqueda, deshacer y rehacer, tamaño y alineación de imágenes, una salvaguarda antes de descartar, plantillas y restablecer tras una confirmación, el error de la plantilla explicado, diseño y vista previa lado a lado en pantalla ancha. Desactivado: el editor en hoja.';

  @override
  String get featureMemberPageTitle => 'Ficha de socio';

  @override
  String get featureMemberPageDesc =>
      'Una página por socio: foto y presencia, última conexión, reservas actuales y próximas, acciones rápidas (mensaje, WhatsApp, correo), tarjetas de contacto y finanzas y, para los admins, cada ajuste agrupado por tema con su valor actual. Desactivado: la hoja de perfil y la hoja de acciones de Socios y planes.';

  @override
  String get featureInvoicingWizardTitle => 'Asistente de facturación';

  @override
  String get featureInvoicingWizardDesc =>
      'Un proceso guiado de cierre mensual para la persona de finanzas: una pasada de inicio de mes para las suscripciones pagadas por adelantado y otra de fin de mes para el uso y los cargos adicionales — revisión, emisión en lote, envío, recordatorios vencidos, registro y validación de pagos, conciliación con facturas, reagrupación, anulación o reembolso, y un resumen con lo que queda y a quién le toca. Desactivado: las pantallas separadas.';

  @override
  String get featureExpenseRepartitionTitle => 'Gastos compartidos';

  @override
  String get featureExpenseRepartitionDesc =>
      'Un gasto común (limpieza, mejora de internet, una silla rota) repartido entre los socios — partes iguales, prorrata de la suscripción, prorrata del uso o una clave por socio — con cada parte previsualizada antes de contabilizarse. Las partes se convierten en líneas de la próxima factura de uso; una reversión genera notas de crédito. Pasa por las reglas de validación. Desactivado: sin reparto.';

  @override
  String get featureSettlementFoldTitle => 'Facturas reagrupadas plegadas';

  @override
  String get featureSettlementFoldDesc =>
      'Las facturas reagrupadas en una desaparecen de las listas como iguales y se anidan bajo la factura de reagrupación, que lleva todas sus líneas. En una factura reagrupada toda operación está desactivada; solo queda su PDF, sellado con el número en que se reagrupó. Desactivado: las facturas reagrupadas siguen listadas junto a la de reagrupación.';

  @override
  String get featureValidationChainTitle => 'Validaciones encadenadas';

  @override
  String get featureValidationChainDesc =>
      'Una regla de validación puede pedir sus validaciones una tras otra, cada paso solicitado cuando el anterior ha pasado, y puede permitir que la propiedad —nunca un admin— valide su propio acto. Desactivado: todo se pide a la vez y nadie valida su propio evento.';

  @override
  String get featureRichMessageRefsTitle => 'Referencias en los mensajes';

  @override
  String get featureRichMessageRefsDesc =>
      'Un mensaje puede apuntar a un aviso, al historial de validación que hay detrás y a una factura, un pago o un reembolso: cada referencia es un enlace que abre lo que nombra. Cada selector filtra mientras escribes. Desactivado: solo se pueden referenciar reservas y espacios.';

  @override
  String get featureCalendarValidationsTitle => 'Validaciones en el calendario';

  @override
  String get featureCalendarValidationsDesc =>
      'Cada decisión tomada sobre un evento aparece en el calendario en el momento en que se tomó, no en el del evento: quién validó o rechazó qué, y cuándo. Al tocarla se abre su historial. Desactivado: el calendario no lleva decisiones.';

  @override
  String get featureUsageRecordsTitle => 'Registros de uso';

  @override
  String get featureUsageRecordsDesc =>
      'Cada reserva contada deja un registro: la ventana reservada, el tiempo realmente presente y lo que se factura. Una reserva a la que nadie llegó se factura entera. Quien sale antes puede pedir que el tiempo no usado deje de facturarse, y lo decide otra persona, nunca quien lo pide. Desactivado: sin registros ni corrección.';

  @override
  String get featureReportDesignExchangeTitle =>
      'Exportar e importar diseños de informe';

  @override
  String get featureReportDesignExchangeDesc =>
      'Cada diseño de informe puede escribirse en un archivo que se explica a sí mismo y volver a leerse. El archivo lleva el diseño y además qué significan sus campos, qué marcado admite y qué variables existen, así una persona o una herramienta puede editarlo fuera de la app y devolverlo. Un archivo de otro informe, o de una versión más nueva, se rechaza con el motivo. Desactivado: los diseños solo se editan en el editor.';

  @override
  String get helpTitle => 'Ayuda';

  @override
  String get helpContents => 'Índice';

  @override
  String get helpHintMessages =>
      'Todas las conversaciones en una lista, la más reciente arriba. Toque el lápiz para escribir a alguien o crear un grupo.';

  @override
  String get helpHintMessagesTopic => 'Mensajes';

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
  String get helpHintLearnMore => 'Más información';

  @override
  String get helpHintDismiss => 'Ocultar consejo';

  @override
  String get helpHintPrevTip => 'Consejo anterior';

  @override
  String get helpHintNextTip => 'Consejo siguiente';

  @override
  String get helpHintRestoreTitle => 'Volver a mostrar los consejos de ayuda';

  @override
  String get helpHintRestored => 'Los consejos de ayuda volverán a mostrarse.';

  @override
  String get helpHintReserve =>
      'Elige un día y una franja horaria y toca un asiento libre para reservarlo.';

  @override
  String get helpHintReserveTopic => 'hub Reservar';

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
  String get helpHintPlan =>
      'El plano en vivo: toca un asiento libre para reservar, toca tu reserva para registrar tu llegada.';

  @override
  String get helpHintPlanTopic => 'El plano';

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
  String get helpHintCalendar =>
      'Elija un día o un periodo: todo lo fechado que puede ver, en una lista, cada fila abre su origen.';

  @override
  String get helpHintCalendarTopic => 'Calendario';

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
  String get helpHintEvents =>
      'Todo lo ocurrido, en un solo hilo. Las decisiones que te esperan van arriba; los filtros acotan el resto.';

  @override
  String get helpHintEventsTopic => 'Eventos';

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
  String get helpHintEditor =>
      'Dibuja salas y escritorios, estampa los asientos y toca dos veces un asiento para editar sus propiedades.';

  @override
  String get helpHintEditorTopic => 'editor del espacio';

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
  String get helpHintAvailability =>
      'Define los días de apertura y el horario, y añade días de cierre que nadie puede reservar.';

  @override
  String get helpHintAvailabilityTopic => 'Disponibilidad';

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
  String get helpHintFeatures =>
      'Activa o desactiva funciones del espacio: la app de cada miembro se actualiza al instante.';

  @override
  String get helpHintFeaturesTopic => 'Funciones';

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
  String get helpHintMembers =>
      'Invita a miembros, ajusta su plan y su rol, y gestiona sus credenciales.';

  @override
  String get helpHintMembersTopic => 'Miembros y planes';

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
  String get helpHintMoney =>
      'Tu factura mensual: recorre los meses con las flechas; paga, exporta o comparte desde aquí.';

  @override
  String get helpHintMoneyTopic => 'dinero';

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
  String get helpHintValidation =>
      'Decide qué acciones necesitan confirmación, quién confirma y cuántas aprobaciones hacen falta.';

  @override
  String get helpHintValidationTopic => 'confirmaciones';

  @override
  String get helpHintValidationTip2 =>
      'Una tarjeta por tipo de evento, cada una heredando de la regla por defecto hasta que la edites: pagos, gastos, cambios de rol y más.';

  @override
  String get helpHintValidationTip3 =>
      'Nadie valida nunca su propio evento, y una solicitud sin respuesta caduca a los 7 días: nada se concede en silencio.';

  @override
  String get helpHintWorkspace =>
      'País, moneda, idioma y datos de facturación: documentos e impuestos siguen estos ajustes.';

  @override
  String get helpHintWorkspaceTopic => 'Ajustes del espacio';

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
  String get helpHintBadges =>
      'Emite una credencial QR imprimible o registra una tarjeta NFC; revoca credenciales perdidas en cualquier momento.';

  @override
  String get helpHintBadgesTopic => 'credenciales RFID';

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
  String get helpHintCalendarTip5 =>
      'El escudo muestra quién puede ver cada tipo y quién miró realmente sus finanzas.';

  @override
  String get helpHintCalendarTip5Topic => 'Privacidad';

  @override
  String get helpHintPrivacy =>
      'Vea quién puede leer sus datos y quién lo hizo, exporte todo en un archivo o salga con sus datos personales borrados.';

  @override
  String get helpHintPrivacyTopic => 'Privacidad';

  @override
  String get helpHintPrivacyTip2 =>
      'Los mensajes solo los leen las personas de la conversación, sea cual sea su rol; el dinero solo usted y el permiso de finanzas.';

  @override
  String get helpHintPrivacyTip3 =>
      'Cada lectura de sus finanzas por otra persona la registra el servidor — el registro no se puede omitir ni editar.';

  @override
  String get helpHintMoneyPayments =>
      'Liquidar y pedir: el saldo, cómo pagarlo o pagar en línea, registrar un pago — y enviar un gasto, pedir medios días o añadir un consumo.';

  @override
  String get helpHintMoneyPaymentsTopic => 'La vista Pagos';

  @override
  String get helpHintMoneyPaymentsTip2 =>
      'Registra un pago con la fecha del movimiento y el mes que salda — la otra parte confirma.';

  @override
  String get helpHintMoneyPaymentsTip3 =>
      'Pagar en línea liquida lo debido al instante; la tarjeta de instrucciones muestra la vía manual con la referencia a indicar.';

  @override
  String get helpHintMoneyPaymentsTip3Topic => 'pagos en línea';

  @override
  String get helpHintMoneyStatement =>
      'El mes tal como está: tu cuenta, días usados y restantes, suscripción, servicios, paquetes, posiciones abiertas, abonos y el saldo. Recorre los meses con las flechas.';

  @override
  String get helpHintMoneyStatementTopic => 'La vista Extracto';

  @override
  String get helpHintMoneyStatementTip2 =>
      'Una mañana reservada cuenta medio día; los días fuera del horario siguen la política de fuera de horario del espacio.';

  @override
  String get helpHintMoneyStatementTip2Topic => 'Cómo se comporta la reserva';

  @override
  String get helpHintMoneyStatementTip3 =>
      '¿Sin días? Pide medios días extra, compra un paquete o sigue reservando por consumo — según tu plan.';

  @override
  String get helpHintMoneyInvoices =>
      'Tus facturas: lo que está abierto y para cuándo, cada factura que te emitieron con su estado, un toque al detalle y al pago.';

  @override
  String get helpHintMoneyInvoicesTopic => 'La vista Facturas';

  @override
  String get helpHintMoneyInvoicesTip2 =>
      'Pasado el plazo de pago del espacio, una factura abierta se lee aquí como vencida, y los niveles de recordatorio configurados por el propietario llegan solos — en tu feed y como notificación.';

  @override
  String get helpHintMoneyInvoicesTip2Topic =>
      'Recordatorios de pago automáticos';

  @override
  String get helpHintMoneyDocuments =>
      'Tu papeleo: tus condiciones, el informe de pagos, el extracto del mes en PDF, la biblioteca de documentos.';

  @override
  String get helpHintMoneyDocumentsTopic => 'La vista Documentos';

  @override
  String get helpHintMoneyDocumentsTip3 =>
      'Mis condiciones es tu acuerdo financiero vigente — plan, tarifa, extras — como documento para conservar.';

  @override
  String get helpHintValidationTipScopes =>
      'Quién valida es el alcance de la regla: los admins, personas designadas de cualquier rol, o todos los miembros — y cuántos. El propietario siempre puede; nadie valida su propio evento.';

  @override
  String get helpHintValidationTipScopesTopic => 'Gestión de roles';

  @override
  String get helpHintMoneyPaymentsTipSupply =>
      '¿Compraste cápsulas o bolsas de aspiradora para el espacio? Envía el gasto como suministro: validado, pasa al estante como consumible que los demás pagan, y a ti te lo reembolsan.';

  @override
  String get helpHintMoneyPaymentsTipSupplyTopic => 'Servicios y Accesorios';

  @override
  String get helpHintMoneyStatementTipNegotiation =>
      '¿Condiciones negociadas? La tarjeta muestra tus precios junto a la tarifa, desde cuándo, y quién puede verlos — los propietarios y los admins de finanzas, cada lectura registrada.';

  @override
  String get helpHintMoneyStatementTipNegotiationTopic =>
      'Negociaciones de precios';

  @override
  String get helpHintMembersTipNegotiation =>
      'Los precios propios de un miembro: abre su ficha → Negociación de precios, indica la cuota, el exceso o el descuento acordados, y los validadores de la regla lo confirman.';

  @override
  String get helpHintMembersTipNegotiationTopic => 'Negociaciones de precios';

  @override
  String get helpDotTooltip => 'Abrir la guía';

  @override
  String get helpTopicLegalIdentity => 'Identidad legal';

  @override
  String get helpTopicEinvoice => 'factura electrónica';

  @override
  String get helpTopicReportEditor => 'editor de informes';

  @override
  String get helpTopicDocumentLibrary => 'biblioteca de documentos';

  @override
  String get helpTopicWorkspaceId => 'ID del espacio';

  @override
  String get helpTopicVat => 'IVA';

  @override
  String get helpTopicSettings => 'Ajustes y perfil';

  @override
  String get helpTopicKiosk => 'Modo quiosco';

  @override
  String get helpTopicBilling => 'Facturación';

  @override
  String get helpTopicWorkingHours => 'Horario de trabajo';

  @override
  String get helpTopicBookingPolicies => 'Políticas de reserva';

  @override
  String get helpTopicBookingLimits => 'Límites de reserva';

  @override
  String get helpTopicScheduledExpenses => 'Gastos programados';

  @override
  String get helpTopicServer => 'tu propio servidor';

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
  String get invoiceAccountingExport => 'Exportación contable';

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
  String get eventTypeInvoiceReminder => 'Recordatorio de pago';

  @override
  String eventInvoiceReminderLine(String number, int level, String amount) {
    return 'Recordatorio $level: factura $number — $amount pendientes';
  }

  @override
  String get dunningAutomatic => 'Recordatorios automáticos';

  @override
  String get dunningAutomaticHint =>
      'Una vez al día, las facturas abiertas más allá del plazo reciben solas su siguiente nivel de recordatorio — un aviso en el feed del miembro y una notificación. Desactivado: envías cada recordatorio tú mismo.';

  @override
  String get eventTypePriceNegotiation => 'Negociación de precios';

  @override
  String eventPriceNegotiationLine(String actor, String member, String terms) {
    return '$actor propone condiciones para $member: $terms';
  }

  @override
  String eventPriceNegotiationItems(int count) {
    return '$count artículos';
  }

  @override
  String get journeyStepIssued => 'Emitida';

  @override
  String get journeyStepPayment => 'Pago';

  @override
  String get journeyStepConfirmation => 'Confirmación';

  @override
  String get journeyStepClosed => 'Cerrada';

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
  String journeyIssuerAdminConfirms(String name, String amount) {
    return '$name declaró un pago de $amount — otro admin lo confirma en Eventos';
  }

  @override
  String journeyIssuerMemberConfirms(String name, String amount) {
    return 'Se registró un pago de $amount — $name lo confirma en Eventos';
  }

  @override
  String journeyIssuerMatches(String amount) {
    return 'Hay un pago de $amount registrado — concílielo con esta factura';
  }

  @override
  String get journeyValidatorsMatch =>
      'Pago conciliado — a la espera de la decisión de los validadores';

  @override
  String get journeyValidatorsWriteoff =>
      'Cancelación del resto solicitada — a la espera de los validadores';

  @override
  String journeyIssuerRefunds(String name, String amount) {
    return 'Nota de crédito — reembolse $amount a $name y regístrelo';
  }

  @override
  String get journeyIssuerReplaces => 'Anulada — emita la factura de reemplazo';

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
  String journeyMemberDeclared(String amount) {
    return 'Declaró $amount — el espacio lo está confirmando';
  }

  @override
  String journeyMemberConfirms(String amount) {
    return 'Le toca: confirme en Eventos el pago de $amount registrado para usted';
  }

  @override
  String journeyMemberRegistered(String amount) {
    return 'Su pago de $amount está registrado — el espacio lo concilia con esta factura';
  }

  @override
  String get journeyMemberValidators =>
      'Pago conciliado — pendiente de validación';

  @override
  String get journeyMemberWriteoff =>
      'El espacio pidió cancelar el resto — pendiente de validación';

  @override
  String journeyMemberRefund(String amount) {
    return 'El espacio le debe $amount — nada que pagar';
  }

  @override
  String get journeyMemberReplaces =>
      'Anulada — sigue una factura de reemplazo';

  @override
  String journeyClosedPaid(String date) {
    return 'Pagada el $date — cerrada';
  }

  @override
  String journeyClosedRemainder(String date) {
    return 'Cerrada — resto cancelado el $date';
  }

  @override
  String journeyClosedRefunded(String date) {
    return 'Reembolsada el $date — cerrada';
  }

  @override
  String journeyClosedReplaced(String number) {
    return 'Anulada — reemplazada por $number';
  }

  @override
  String get journeyClosedSettled =>
      'Reagrupada en otra factura — esa es la que se debe y se reclama';

  @override
  String get journeyStageIssue => 'Por emitir';

  @override
  String get journeyStageCollect => 'Por cobrar';

  @override
  String get journeyStageConfirm => 'Por confirmar';

  @override
  String get journeyStageClosed => 'Cerradas';

  @override
  String journeyOverdueCount(int count) {
    return '$count atrasadas';
  }

  @override
  String get journeyStageStripLabel =>
      'El proceso de facturación: emitir, cobrar, confirmar, cerrar';

  @override
  String get journeyHowButton => 'Cómo funciona';

  @override
  String get journeyHowTitle => 'Cómo funciona la facturación';

  @override
  String get journeyHowIntro =>
      'Cuatro pasos, los mismos para cada factura. Cada uno dice a quién le toca.';

  @override
  String get journeyHowWorkspaceLabel => 'Espacio';

  @override
  String get journeyHowMemberLabel => 'Miembro';

  @override
  String get journeyHowIssuedWorkspace =>
      'Emite la factura a partir de los datos del mes — numerada, firmada, inmutable — y comparte el PDF o envía la factura electrónica.';

  @override
  String get journeyHowIssuedMember =>
      'La encuentra en la vista Facturas: partidas, saldo, vencimiento.';

  @override
  String get journeyHowPaymentWorkspace =>
      'Espera el dinero. Pasado el plazo envía los niveles de recordatorio configurados — a mano o automáticamente.';

  @override
  String get journeyHowPaymentMember =>
      'Paga en línea (liquidado al instante) o por transferencia, y luego registra el pago para que el espacio lo sepa.';

  @override
  String get journeyHowConfirmationWorkspace =>
      'Otro admin confirma el pago declarado; el emisor concilia luego el pago registrado con la factura (Marcar pagada) — una regla de validación puede pasar la conciliación a los validadores. ¿Pagó de más? Una nota de crédito. ¿De menos? Parcialmente pagada, el resto se debe hasta pagarlo o cancelarlo.';

  @override
  String get journeyHowConfirmationMember =>
      'Nada que hacer — salvo que el espacio registrara el pago por él: entonces lo confirma en Eventos.';

  @override
  String get journeyHowClosedWorkspace =>
      'Pagada, resto cancelado o reembolsada: la factura pasa al archivo. Una factura errónea se marca como tal y se reemplaza — antes del pago, nunca después.';

  @override
  String get journeyHowClosedMember =>
      'El mes se lee saldado y la factura sigue legible para siempre: vista rápida, PDF, compartir.';

  @override
  String get journeyTimelineTitle => 'Cronología';

  @override
  String journeyPrimaryRemind(int level) {
    return 'Enviar recordatorio $level';
  }

  @override
  String get journeyPrimaryConfirmInEvents => 'Abrir Eventos';

  @override
  String journeyOutstanding(String amount) {
    return '$amount pendientes';
  }

  @override
  String get reportEditorTitle => 'Editor de informes';

  @override
  String get reportDesignerUndo => 'Deshacer';

  @override
  String get reportDesignerRedo => 'Rehacer';

  @override
  String get reportDesignerDiscardTitle => '¿Salir sin guardar?';

  @override
  String get reportDesignerDiscardBody =>
      'Sus cambios en las plantillas no están guardados.';

  @override
  String get reportDesignerDiscard => 'Descartar';

  @override
  String get reportDesignerKeepEditing => 'Seguir editando';

  @override
  String get reportDesignerReplaceTitle => '¿Reemplazar el diseño actual?';

  @override
  String get reportDesignerReplaceBody =>
      'Las bandas de este documento se reemplazan. Deshacer las recupera.';

  @override
  String get reportDesignerReplace => 'Reemplazar';

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
  String reportDesignerError(String message) {
    return 'La plantilla no se genera — $message';
  }

  @override
  String get reportDesignerInsert => 'Insertar elemento';

  @override
  String get reportDesignerFields => 'Campos';

  @override
  String get reportDesignerFieldsSearch => 'Buscar un campo';

  @override
  String get reportDesignerMoveTo => 'Mover a la banda';

  @override
  String get reportDesignerDrag => 'Arrastrar para reordenar';

  @override
  String get reportImageSize => 'Tamaño';

  @override
  String get reportImageSizeSmall => 'Pequeña';

  @override
  String get reportImageSizeMedium => 'Mediana';

  @override
  String get reportImageSizeLarge => 'Grande';

  @override
  String get reportImageAlign => 'Alineación';

  @override
  String get reportImageAlignLeft => 'Izquierda';

  @override
  String get reportImageAlignCenter => 'Centro';

  @override
  String get reportImageAlignRight => 'Derecha';

  @override
  String get reportTemplateLangOverridden => 'Plantilla propia';

  @override
  String get reportTemplateLangInherits => 'Hereda la predeterminada';

  @override
  String get reportTemplateClearOverlay =>
      'Usar la predeterminada para este idioma';

  @override
  String get reportDocCoa => 'Plan de cuentas';

  @override
  String get reportDocBadges => 'Tarjetas de socios';

  @override
  String get reportDocSpaceCodes => 'Tarjetas QR de espacios';

  @override
  String get reportFieldGroupDocument => 'Documento';

  @override
  String get reportFieldGroupMember => 'Socio y espacio';

  @override
  String get reportFieldGroupMoney => 'Importes';

  @override
  String get reportFieldGroupLegal => 'Menciones legales';

  @override
  String get reportFieldGroupLoops => 'Bucles de líneas e IVA';

  @override
  String get reportDesignerSideBySide => 'Diseño y vista previa lado a lado';

  @override
  String get wizardTitle => 'Asistente de facturación';

  @override
  String get invoiceWizardAction => 'Asistente de cierre mensual';

  @override
  String get wizardCardHint =>
      'Emitir, enviar, recordar, registrar y validar pagos, conciliar y cerrar: un solo proceso guiado.';

  @override
  String get wizardRunStart => 'Inicio de mes';

  @override
  String get wizardRunEnd => 'Fin de mes';

  @override
  String get wizardRunStartHint =>
      'Las suscripciones pagadas por adelantado: emitirlas para el mes que viene, enviarlas, planificar los recordatorios; luego, la parte de pagos.';

  @override
  String get wizardRunEndHint =>
      'Lo que costó el mes que acaba de terminar: uso, consumo y cargos adicionales. Emitir, enviar, recordar; luego registrar, validar y conciliar los pagos, y cerrar.';

  @override
  String get wizardStepReview => 'Revisión';

  @override
  String get wizardStepIssue => 'Emitir';

  @override
  String get wizardStepSend => 'Enviar';

  @override
  String get wizardStepRemind => 'Recordar';

  @override
  String get wizardStepPayments => 'Pagos';

  @override
  String get wizardStepMatch => 'Conciliar';

  @override
  String get wizardStepClose => 'Cerrar';

  @override
  String get wizardStepSummary => 'Resumen';

  @override
  String get wizardNext => 'Siguiente';

  @override
  String get wizardBack => 'Atrás';

  @override
  String get wizardFinish => 'Terminar';

  @override
  String get wizardReviewToIssue => 'Por emitir';

  @override
  String get wizardReviewIssued => 'Ya emitidas';

  @override
  String get wizardReviewOpen => 'Facturas abiertas';

  @override
  String get wizardReviewOverdue => 'Recordatorios vencidos';

  @override
  String get wizardReviewPending => 'Pagos por validar';

  @override
  String wizardPeriodLabel(String period) {
    return 'Periodo: $period';
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
  String get wizardSendHint =>
      'Entregue cada factura a su socio: comparta el PDF o descárguelo para enviarlo a su manera.';

  @override
  String get wizardSendNone =>
      'Todavía no hay factura de esta pasada que enviar.';

  @override
  String get wizardSendShare => 'Compartir el PDF';

  @override
  String get wizardSendDownload => 'Descargar el PDF';

  @override
  String get wizardRemindHint =>
      'Vencidas según sus reglas de recordatorio. Un toque registra cada recordatorio y avisa a los socios; la carta se abre por fila.';

  @override
  String get wizardRemindNone => 'Ningún recordatorio vence según sus reglas.';

  @override
  String wizardRemindLevel(int level) {
    return 'recordatorio $level';
  }

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
  String get wizardRemindOne => 'Carta de recordatorio';

  @override
  String get wizardPaymentsHint =>
      'Lo que los socios declararon espera su confirmación abajo. Un pago que llegó a la cuenta sin declaración se registra aquí; el socio lo confirma después.';

  @override
  String get wizardPaymentsNone => 'Ningún pago declarado espera su decisión.';

  @override
  String get wizardPaymentAccept => 'Confirmar';

  @override
  String get wizardPaymentReject => 'Rechazar';

  @override
  String get wizardMatchHint =>
      'Una factura está pagada cuando se le concilia un pago real. Las filas con crédito en la cuenta del socio están listas.';

  @override
  String get wizardMatchNone => 'Todas las facturas están pagadas o cerradas.';

  @override
  String get wizardMatchPending => 'Pendiente de validación';

  @override
  String wizardMatchCredit(String amount) {
    return 'Crédito disponible: $amount';
  }

  @override
  String get wizardMatchNoCredit => 'Aún no hay pago en la cuenta';

  @override
  String get wizardMatchAction => 'Conciliar';

  @override
  String get wizardCloseHint =>
      'Un socio con varias facturas abiertas puede pagar UNA; a una factura pagada en parte se le puede anular el resto; una nota de crédito se reembolsa. Cada una pasa por la validación.';

  @override
  String get wizardCloseNone => 'Nada que reagrupar, anular o reembolsar.';

  @override
  String wizardSettle(int count) {
    return 'Reagrupar $count';
  }

  @override
  String get wizardWriteoff => 'Anular';

  @override
  String get wizardRefund => 'Reembolsar';

  @override
  String get wizardSummaryHint => 'Lo que hizo esta pasada';

  @override
  String get wizardTallyIssued => 'Facturas emitidas';

  @override
  String get wizardTallyShared => 'PDF compartidos o descargados';

  @override
  String get wizardTallyReminded => 'Recordatorios enviados';

  @override
  String get wizardTallyDecided => 'Pagos confirmados o rechazados';

  @override
  String get wizardTallyRegistered => 'Pagos registrados';

  @override
  String get wizardTallyMatched => 'Facturas conciliadas';

  @override
  String get wizardTallySettled => 'Reagrupaciones';

  @override
  String get wizardTallyWriteoffs => 'Anulaciones solicitadas';

  @override
  String get wizardTallyRefunds => 'Reembolsos';

  @override
  String get wizardTallyNothing => 'No se cambió nada.';

  @override
  String get wizardTodoHeading => 'Aún abierto: a quién le toca';

  @override
  String get wizardTodoNone => 'No queda nada abierto.';

  @override
  String get wizardWhoYou => 'Usted';

  @override
  String get wizardWhoValidators => 'Validadores';

  @override
  String get registerPaymentTitle => 'Registrar un pago';

  @override
  String get registerPaymentHint =>
      'Un pago que llegó al espacio: el socio lo confirma y luego puede conciliarse con una factura.';

  @override
  String get registerPaymentMember => 'Socio';

  @override
  String get registerPaymentAmount => 'Importe';

  @override
  String get registerPaymentMethod => 'Medio';

  @override
  String get registerPaymentDate => 'Pagado el';

  @override
  String get registerPaymentNote => 'Nota';

  @override
  String get registerPaymentSubmit => 'Registrar';

  @override
  String get registerPaymentDone =>
      'Pago registrado: el socio lo confirma por su parte.';

  @override
  String get repartitionAction => 'Repartir un gasto';

  @override
  String get repartitionTitle => 'Repartir un gasto';

  @override
  String get repartitionHint =>
      'Reparta un coste común entre los socios. Las partes se convierten en líneas de la próxima factura de uso de cada uno; una reversión devuelve el dinero como notas de crédito.';

  @override
  String get repartitionTitleField => 'Concepto';

  @override
  String get repartitionAmount => 'Importe total';

  @override
  String get repartitionReverse => 'Reversión — devolver como notas de crédito';

  @override
  String get repartitionMethod => 'Repartir por';

  @override
  String get repartitionMethodEqual => 'Partes iguales';

  @override
  String get repartitionMethodSubscription => 'Suscripción';

  @override
  String get repartitionMethodUsage => 'Uso';

  @override
  String get repartitionMethodCustom => 'Clave propia';

  @override
  String get repartitionPeriod => 'Se imputa a';

  @override
  String get repartitionWeight => 'Clave';

  @override
  String get repartitionPreview => 'Partes';

  @override
  String get repartitionNoShares => 'Nadie lleva una parte: revise la clave.';

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
  String get repartitionSubmit => 'Contabilizar las partes';

  @override
  String get repartitionFiled =>
      'Partes contabilizadas: aparecerán en la próxima factura de uso.';

  @override
  String get repartitionFiledPending =>
      'Partes presentadas: se contabilizan tras la validación.';

  @override
  String get repartitionHistory => 'Repartos';

  @override
  String get repartitionHistoryEmpty => 'Ningún reparto todavía.';

  @override
  String get repartitionStatusPending => 'Pendiente de validación';

  @override
  String get repartitionStatusConfirmed => 'Contabilizado';

  @override
  String get repartitionStatusRejected => 'Rechazado';

  @override
  String get repartitionStatusExpired => 'Caducado';

  @override
  String get reportDesignFileTypeLabel => 'JSON';

  @override
  String get reportDesignExport => 'Exportar este diseño';

  @override
  String get reportDesignImport => 'Importar un diseño';

  @override
  String get reportDesignImported =>
      'Diseño importado. Guarda para conservarlo.';

  @override
  String get reportDesignErrorMalformed => 'Ese archivo no es JSON legible.';

  @override
  String get reportDesignErrorNotADesign =>
      'Ese archivo no es un diseño de informe de DesKilo.';

  @override
  String get reportDesignErrorVersion =>
      'Ese diseño se escribió con una versión más nueva de DesKilo.';

  @override
  String get reportDesignErrorUnknownKind =>
      'Ese diseño es de un informe que este espacio no tiene.';

  @override
  String get reportDesignErrorWrongKind =>
      'Ese diseño pertenece a otro informe. Ábrelo e impórtalo allí.';

  @override
  String get reportDesignErrorInvalidDesign =>
      'Ese archivo no contiene ningún diseño legible.';

  @override
  String get invoicesManage => 'Gestionar facturas';

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
  String kioskBlockedContactHint(String name) {
    return 'Ocupado por $name — puedes escribirle desde la aplicación en tu teléfono.';
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
  String get bookingPastError =>
      'Esta reserva está completamente en el pasado.';

  @override
  String get bookingWalkUpTodayError =>
      'Un check-in espontáneo debe empezar hoy.';

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
  String get bookingSameDayError =>
      'Una reserva termina el día en que empieza: reserva el día siguiente por separado.';

  @override
  String get featureManagedProfiles => 'Perfiles gestionados';

  @override
  String get featureManagedProfilesDesc =>
      'Los admins crean miembros sin cuenta, reservan y facturan por ellos y les entregan el perfil con un código personal que la persona canjea al unirse.';

  @override
  String get managedProfileAdd => 'Añadir un perfil gestionado';

  @override
  String get managedProfileTitle => 'Perfil gestionado';

  @override
  String get managedProfileChip => 'Gestionado';

  @override
  String get managedProfileEdit => 'Editar identidad';

  @override
  String get managedProfileHandOver => 'Entregar a la persona';

  @override
  String get managedProfileHandOverHint =>
      'Genera un código personal ligado a este perfil. Quien lo canjee se hace con el perfil — reservas, facturas, suscripción — en cuanto apruebes la membresía.';

  @override
  String get managedProfileRevoke => 'Revocar la entrega';

  @override
  String get managedProfileRevoked => 'Entrega revocada';

  @override
  String get managedProfileCreated => 'Perfil gestionado creado';

  @override
  String get managedProfileSaved => 'Identidad guardada';

  @override
  String get managedProfileIntro =>
      'Esta persona aún no tiene cuenta. Reservas, facturas y gestionas por ella; entrégale el perfil cuando se una.';

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
  String get notesFilterUnread => 'No leídos';

  @override
  String get notesFilterEmpty => 'No hay mensajes sin leer — todo al día.';

  @override
  String get conversationGroup => 'Grupo';

  @override
  String get conversationUnknownMember => 'Miembro';

  @override
  String get conversationYesterday => 'Ayer';

  @override
  String get conversationYou => 'Usted';

  @override
  String get messagesTitle => 'Mensajes';

  @override
  String get messagesEmpty => 'Aún no hay conversaciones.';

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
  String get newConversationTitle => 'Nueva conversación';

  @override
  String get newConversationSearch => 'Buscar miembros';

  @override
  String get newConversationStart => 'Iniciar chat';

  @override
  String get newConversationNoMembers => 'Aún no hay nadie más.';

  @override
  String get newGroupName => 'Nombre del grupo';

  @override
  String get newGroupCreate => 'Crear grupo';

  @override
  String get conversationGroupInfo => 'Grupo';

  @override
  String get conversationAddPeople => 'Añadir miembros';

  @override
  String get conversationLeave => 'Salir del grupo';

  @override
  String get conversationLeaveConfirm =>
      '¿Salir de este grupo? Dejará de recibir sus mensajes; lo que ya envió permanece.';

  @override
  String get conversationRemove => 'Quitar';

  @override
  String get conversationAdmin => 'Admin';

  @override
  String get conversationLeft => 'Salió';

  @override
  String get messageSearchHint => 'Miembros, grupos, mensajes';

  @override
  String get messageSearchPrompt => 'Busque miembros, grupos y lo que se dijo.';

  @override
  String get messageSearchNothing => 'Sin resultados.';

  @override
  String get messageSearchPeople => 'Miembros';

  @override
  String get messageSearchGroups => 'Grupos';

  @override
  String get messageSearchMessages => 'Mensajes';

  @override
  String get messageSearchTitle => 'Buscar';

  @override
  String get newGroupNameTaken =>
      'Ya existe un grupo con ese nombre aquí. Elija otro.';

  @override
  String get conversationSeeProfile => 'Ver perfil';

  @override
  String get inboxChatsTab => 'Chats';

  @override
  String get memberMoneySettled => 'Nada pendiente.';

  @override
  String memberMoreInvoices(int count) {
    return '+$count más';
  }

  @override
  String get memberMonthInProgress => 'Este mes';

  @override
  String get memberPayments => 'Pagos';

  @override
  String memberInvoiceOpen(String amount) {
    return '$amount pendientes';
  }

  @override
  String get memberInvoicePaid => 'Pagada';

  @override
  String get memberInvoiceVoided => 'Anulada';

  @override
  String get memberContactHeading => 'Contacto';

  @override
  String memberPlanShare(String pct) {
    return 'Plan $pct %';
  }

  @override
  String get memberMoneyUnavailable =>
      'No se pudieron cargar las finanzas. Tire para actualizar.';

  @override
  String get inboxAlertsTab => 'Alertas';

  @override
  String get inboxFilterAll => 'Todos';

  @override
  String get inboxFilterUnread => 'No leídos';

  @override
  String get inboxFilterArchived => 'Archivados';

  @override
  String get inboxNoUnread => 'Nada sin leer — estás al día.';

  @override
  String get inboxNoArchived => 'Ninguna conversación archivada.';

  @override
  String get conversationPin => 'Fijar arriba';

  @override
  String get conversationUnpin => 'Desfijar';

  @override
  String get conversationMute => 'Silenciar notificaciones';

  @override
  String get conversationUnmute => 'Reactivar notificaciones';

  @override
  String get conversationMarkUnread => 'Marcar como no leído';

  @override
  String get conversationArchive => 'Archivar';

  @override
  String get conversationUnarchive => 'Sacar del archivo';

  @override
  String get conversationArchived => 'Conversación archivada.';

  @override
  String get conversationMutedBadge => 'Silenciada';

  @override
  String get conversationLoadEarlier => 'Cargar mensajes anteriores';

  @override
  String get conversationToday => 'Hoy';

  @override
  String get composerAttach => 'Adjuntar una referencia';

  @override
  String composerCharsLeft(int count) {
    return '$count caracteres restantes';
  }

  @override
  String get composerDraftKept => 'Borrador guardado';

  @override
  String get newConversationTapToOpen =>
      'Toca a una persona para abrir el chat; activa Grupo para elegir varias.';

  @override
  String get newConversationGroupSwitch => 'Grupo';

  @override
  String get inboxRetry => 'Reintentar';

  @override
  String get memberNoteDeleteRead =>
      'Ya leído: este mensaje ya no se puede retirar.';

  @override
  String get memberNoteDeleteNotMine =>
      'Solo quien lo envió puede retirar un mensaje.';

  @override
  String get noteRefFilterLabel => 'Filtrar';

  @override
  String noteRefFilterCount(int shown, int total) {
    return '$shown de $total';
  }

  @override
  String get noteRefFilterEmpty => 'Sin resultados.';

  @override
  String get noteRefAlert => 'Aviso';

  @override
  String get noteRefValidation => 'Validación';

  @override
  String get noteRefInvoice => 'Factura';

  @override
  String get noteRefPayment => 'Pago';

  @override
  String get noteRefRefund => 'Reembolso';

  @override
  String get noteRefPickAlert => '¿Qué aviso?';

  @override
  String get noteRefPickValidation => '¿Qué validación?';

  @override
  String get noteRefPickInvoice => '¿Qué factura?';

  @override
  String get noteRefPickPayment => '¿Qué pago?';

  @override
  String get noteRefNone => 'Nada que referenciar todavía.';

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
  String get paymentBankNameLabel => 'Nombre del banco';

  @override
  String get paymentAccountNumberLabel => 'Número de cuenta';

  @override
  String get paymentSortCodeLabel => 'Sort code';

  @override
  String get paymentRoutingNumberLabel => 'Routing number';

  @override
  String get paymentTransitNumberLabel => 'Tránsito · institución';

  @override
  String get paymentBankCodeLabel => 'Código bancario';

  @override
  String get paymentBicLabel => 'BIC / SWIFT';

  @override
  String get paymentCopied => 'Copiado.';

  @override
  String get moneyFacePayments => 'Pagos';

  @override
  String get moneyFaceInvoices => 'Facturas';

  @override
  String get moneyNoInvoicesYet =>
      'Aún no hay factura — el espacio factura el mes una vez cerrado.';

  @override
  String get moneyFaceStatement => 'Extracto';

  @override
  String get moneyFaceDocuments => 'Documentos';

  @override
  String moneyOverdueBanner(int count, String amount) {
    return '$count vencidas — $amount por liquidar';
  }

  @override
  String get moneyPayNow => 'Pagar ahora';

  @override
  String get moneyOpenInvoicesTitle => 'Facturas abiertas';

  @override
  String moneyOpenInvoicesSummary(int count, String amount) {
    return '$count abiertas · $amount pendientes';
  }

  @override
  String moneyDueIn(int days) {
    return 'Vence en $days días';
  }

  @override
  String moneyOverdueBy(int days) {
    return 'Vencida hace $days días';
  }

  @override
  String get moneyNothingOpen => 'Nada abierto — estás al día.';

  @override
  String get moneyDocumentLibrary => 'Biblioteca de documentos';

  @override
  String get moneyStatementPdf => 'Extracto del mes (PDF)';

  @override
  String moneyRemindedTimes(int count) {
    return 'Recordada ×$count';
  }

  @override
  String get expenseSupplyToggle => 'Es un suministro para el espacio';

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
  String get expenseSupplyUnitPrice =>
      'Precio unitario (lo que cuesta un consumo)';

  @override
  String get expenseSupplyUnitPriceHint =>
      'Prellenado con importe ÷ cantidad; redondea si quieres.';

  @override
  String serviceStockCount(int count) {
    return '$count en stock';
  }

  @override
  String get serviceOutOfStock => 'Agotado';

  @override
  String get serviceOutOfStockHint =>
      'No queda nada en el estante — el próximo suministro lo repone.';

  @override
  String get negotiationCardTitle => 'Mis precios negociados';

  @override
  String get negotiationOnTariff => 'Estás en la tarifa del espacio.';

  @override
  String get negotiationPending => 'Unas condiciones esperan validación.';

  @override
  String negotiationActiveSince(String month) {
    return 'Tus condiciones se aplican desde $month.';
  }

  @override
  String get negotiationFee => 'Cuota mensual';

  @override
  String get negotiationOverage => 'Exceso por medio día';

  @override
  String get negotiationDiscount => 'Descuento en suplementos';

  @override
  String get negotiationDefaultColumn => 'Tarifa';

  @override
  String get negotiationMineColumn => 'Las mías';

  @override
  String get negotiationWhoCanSee => 'Quién puede verlo';

  @override
  String get negotiationProposeTitle => 'Negociación de precios';

  @override
  String get negotiationProposeHint =>
      'Deja un campo vacío para mantener la tarifa. Las condiciones pasan por validación antes de aplicarse.';

  @override
  String get negotiationNote => 'Nota';

  @override
  String get negotiationValidFrom => 'Se aplica desde';

  @override
  String get negotiationSubmit => 'Proponer para validación';

  @override
  String get negotiationProposed =>
      'Condiciones propuestas — pendientes de validación.';

  @override
  String get negotiationPendingBadge => 'pendiente de validación';

  @override
  String get negotiationOccupation => 'Ocupación';

  @override
  String get negotiationOccupationHint =>
      'La parte de días abiertos incluida cada mes; se aplica al miembro una vez validada.';

  @override
  String get negotiationKeepCurrent => 'Mantener la actual';

  @override
  String get negotiationItems => 'Servicios y paquetes';

  @override
  String get negotiationItemsHint =>
      'Un precio unitario para este miembro; vacío mantiene el catálogo.';

  @override
  String negotiationPercent(int value) {
    return '$value %';
  }

  @override
  String get negotiationReadOnly => 'Solo lectura';

  @override
  String get scheduledExpensesTitle => 'Gastos programados';

  @override
  String get scheduledExpensesIntro =>
      'Las suscripciones que paga el espacio — internet, teléfono, electricidad. La programación se valida una vez; cada vencimiento se te presenta antes de contar.';

  @override
  String get scheduledExpensesEmpty => 'Aún no hay gastos programados.';

  @override
  String get scheduleNew => 'Programar un gasto recurrente';

  @override
  String get scheduleCancel => 'Terminar esta programación';

  @override
  String get scheduleTitleLabel => 'Qué (p. ej. Internet)';

  @override
  String get scheduleStartsOn => 'Primer vencimiento';

  @override
  String get scheduleEveryLabel => 'Cada';

  @override
  String get scheduleUnitLabel => 'Unidad';

  @override
  String get scheduleTimesLabel =>
      'Repeticiones (vacío = hasta la fecha de fin)';

  @override
  String get scheduleEndsOn => 'Hasta (opcional)';

  @override
  String get scheduleNoEnd => 'Sin fecha de fin';

  @override
  String get scheduleValidationHint =>
      'La programación pasa primero por los validadores. Cada vencimiento se te presenta después: confirmado a este importe cuenta de inmediato; un importe distinto se explica y vuelve a validarse.';

  @override
  String get scheduleSubmit => 'Programar';

  @override
  String get scheduleMissingFields => 'Se necesitan el nombre y el importe.';

  @override
  String get schedulePending =>
      'Programado — a la espera de la confirmación de los validadores.';

  @override
  String get scheduleStatusPending => 'Pendiente de validación';

  @override
  String get scheduleStatusActive => 'Activa';

  @override
  String get scheduleStatusRejected => 'Rechazada';

  @override
  String get scheduleStatusEnded => 'Terminada';

  @override
  String get scheduleDaily => 'diaria';

  @override
  String get scheduleWeekly => 'semanal';

  @override
  String get scheduleMonthly => 'mensual';

  @override
  String get scheduleYearly => 'anual';

  @override
  String scheduleEveryDays(Object count) {
    return 'cada $count días';
  }

  @override
  String scheduleEveryWeeks(Object count) {
    return 'cada $count semanas';
  }

  @override
  String scheduleEveryMonths(Object count) {
    return 'cada $count meses';
  }

  @override
  String scheduleTimes(Object count) {
    return '$count veces';
  }

  @override
  String scheduleUntil(Object date) {
    return 'hasta $date';
  }

  @override
  String scheduleNextDue(Object date) {
    return 'próxima: $date';
  }

  @override
  String get occurrenceRejected =>
      'Los validadores la rechazaron — ajusta el importe o la descripción y reenvía.';

  @override
  String occurrenceScheduledAmount(Object amount) {
    return 'Validado: $amount';
  }

  @override
  String get occurrenceReasonLabel => 'Por qué difiere (obligatorio)';

  @override
  String get occurrenceConfirm => 'Confirmar este gasto';

  @override
  String get occurrenceResend => 'Reenviar a validación';

  @override
  String get occurrenceReasonMissing =>
      'Un importe distinto necesita una explicación.';

  @override
  String get occurrenceSentForValidation =>
      'Enviado a los validadores — contará cuando confirmen.';

  @override
  String get occurrenceAdded => 'Añadido a tus gastos.';

  @override
  String get scheduledAwaitingTitle => 'Gastos programados por confirmar';

  @override
  String get scheduleUnitDays => 'días';

  @override
  String get scheduleUnitWeeks => 'semanas';

  @override
  String get scheduleUnitMonths => 'meses';

  @override
  String get scheduleUnitYears => 'años';

  @override
  String get moneyFaceUsage => 'Uso';

  @override
  String billParticipation(int pct) {
    return 'Participación $pct %';
  }

  @override
  String get featureMemberPaymentTerms => 'Condiciones de pago por miembro';

  @override
  String get featureMemberPaymentTermsDesc =>
      'El espacio fija las condiciones de pago por defecto; un miembro puede tener las suyas, visibles para él, cambiadas solo por una solicitud validada de un admin autorizado.';

  @override
  String get permPaymentTermsEdit => 'Solicitar cambios de condiciones de pago';

  @override
  String get eventTypePaymentTermsChange => 'Condiciones de pago';

  @override
  String eventPaymentTermsChangeLine(String actor, String terms) {
    return '$actor pide fijar las condiciones de pago: $terms';
  }

  @override
  String get paymentTermsInherit => 'las del espacio por defecto';

  @override
  String get paymentTermsTitle => 'Condiciones de pago';

  @override
  String get paymentTermsInherited => 'Por defecto del espacio';

  @override
  String get paymentTermsOverridden => 'Propias del miembro';

  @override
  String get paymentTermsEdit => 'Solicitar un cambio';

  @override
  String get paymentTermsRequestTitle =>
      'Solicitar un cambio de condiciones de pago';

  @override
  String get paymentTermsRequestHint =>
      'Deje un campo vacío para conservar la redacción del espacio. El cambio se aplica una vez validado.';

  @override
  String get paymentTermsReason => 'Motivo (opcional)';

  @override
  String get paymentTermsRequested =>
      'Cambio solicitado — pendiente de validación';

  @override
  String get paymentTermsUseDefault =>
      'Volver a las condiciones por defecto del espacio';

  @override
  String get paymentTermsMemberNote =>
      'Estas condiciones las fija el espacio; un cambio pasa por su validación.';

  @override
  String get paymentTermsSubmit => 'Enviar solicitud';

  @override
  String get paymentTermsFieldTerms => 'Condiciones de pago';

  @override
  String get paymentTermsFieldEscompte => 'Descuento por pronto pago';

  @override
  String get paymentTermsFieldLatePenalty => 'Penalización por demora';

  @override
  String get paymentTermsFieldRecovery => 'Indemnización de cobro';

  @override
  String get paymentTermsNone => 'Sin condiciones redactadas';

  @override
  String get featurePersonalInfo => 'Datos personales';

  @override
  String get featurePersonalInfoDesc =>
      'Los miembros introducen nombre, dirección postal, teléfono, e-mail e identificadores en Ajustes; facturas y cartas los imprimen en el bloque postal normalizado.';

  @override
  String get personalInfoTitle => 'Datos personales';

  @override
  String get personalInfoSubtitle =>
      'Se imprimen en sus facturas y cartas. El apellido se escribe en mayúsculas, como en el correo oficial.';

  @override
  String get personalInfoFirstName => 'Nombre';

  @override
  String get personalInfoLastName => 'Apellidos';

  @override
  String get personalInfoCompany => 'Empresa (opcional)';

  @override
  String get personalInfoStreet => 'Calle y número';

  @override
  String get personalInfoPostalCode => 'Código postal';

  @override
  String get personalInfoCity => 'Ciudad';

  @override
  String get personalInfoCountry => 'País';

  @override
  String get personalInfoPhone => 'Teléfono';

  @override
  String get personalInfoEmail => 'E-mail para documentos';

  @override
  String get personalInfoVatId => 'NIF-IVA (opcional)';

  @override
  String get personalInfoLegalId => 'Identificador de empresa (opcional)';

  @override
  String get personalInfoSaved => 'Datos personales guardados';

  @override
  String get personalInfoNone => 'Aún sin rellenar';

  @override
  String get personalInfoPreview => 'En sus documentos';

  @override
  String get personalInfoSave => 'Guardar';

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
  String planCheckInOpensOn(String date) {
    return 'El check-in abre el $date';
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
  String get privacyTitle => 'Privacidad y datos';

  @override
  String get privacyIntro =>
      'Sus datos permanecen en la UE, nunca se rastrean ni se venden, y solo los leen los roles que nombran las reglas de abajo. Estos son sus derechos según el RGPD — cada uno es un botón.';

  @override
  String get privacyWhoCanSee => 'Quién puede ver mis datos';

  @override
  String get privacyWhoCanSeeHint =>
      'La regla por categoría, las personas que nombra hoy y quién miró realmente.';

  @override
  String get privacyExport => 'Exportar mis datos';

  @override
  String get privacyExportHint =>
      'Todo aquello de lo que usted es el sujeto, en un archivo JSON (art. 20).';

  @override
  String get privacyExportShareText => 'Mi exportación de datos DesKilo';

  @override
  String get privacyErase => 'Abandonar este espacio y borrar mis datos';

  @override
  String get privacyEraseHint =>
      'Cancela sus reservas, vacía sus mensajes, borra su perfil. Los registros contables se conservan durante la retención legal, por id, no por nombre (art. 17).';

  @override
  String get privacyEraseOwner =>
      'Un propietario transfiere primero el espacio (Miembros y planes → Copropiedad).';

  @override
  String get privacyEraseConfirmPhrase => 'BORRAR';

  @override
  String privacyEraseConfirmHint(String phrase) {
    return 'No se puede deshacer. Escriba $phrase para confirmar.';
  }

  @override
  String get privacyEraseConfirmButton => 'Borrar';

  @override
  String get privacyErased => 'Sus datos han sido borrados.';

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get consentTitle => 'Tus datos, tus derechos';

  @override
  String get consentIntro =>
      'Antes de usar DesKilo, esto es lo que la app hace con tus datos, quién puede verlos y qué puedes hacer al respecto. Dos minutos; no hay más.';

  @override
  String get consentWhatTitle => 'Qué procesa DesKilo';

  @override
  String get consentWhatBody =>
      'Tu cuenta (e-mail, nombre visible, contraseña cifrada), tu perfil tal como lo rellenas (foto, estado, dirección, número de WhatsApp — cada uno opcional), y lo que haces en un espacio: reservas y registros de entrada, mensajes, gastos y consumos, tu suscripción, facturas y pagos. Todo se guarda en la UE (Supabase, eu-central-1).';

  @override
  String get consentNotTitle => 'Lo que DesKilo nunca hace';

  @override
  String get consentNotBody =>
      'Sin rastreo, sin analítica, sin publicidad, sin venta ni cesión de datos. Las notificaciones push no llevan contenido — solo «tienes un mensaje nuevo»; la propia app escribe el texto. La versión F-Droid no tiene ningún servicio de Google.';

  @override
  String get consentWhoTitle => 'Quién puede ver qué';

  @override
  String get consentWhoBody =>
      'El acceso sigue los roles y se aplica en el servidor: las reservas las ve el espacio (el plano muestra la ocupación); los mensajes solo las personas de la conversación, sea cual sea su rol; tus finanzas y tu acuerdo comercial solo tú, los propietarios y los admins con el permiso correspondiente. Ajustes → Privacidad y datos nombra a las personas y lista quién miró realmente.';

  @override
  String get consentControllerTitle => 'Quién es responsable';

  @override
  String get consentControllerBody =>
      'Cada espacio lo opera su propietario — tu comunidad —, que decide miembros, precios y proveedores de pago. La app es de código abierto (0BSD) y la publica Florian Dittgen (Alemania); el backend es Supabase en la UE. Los pagos en línea pasan por el proveedor que activó el propietario (PayPal, Stripe, Mollie, Wero) según sus condiciones.';

  @override
  String get consentRetentionTitle => 'Cuánto tiempo';

  @override
  String get consentRetentionBody =>
      'Mientras seas miembro. Cuando te vas y borras, tu perfil y tus mensajes desaparecen; los registros contables (facturas, pagos) se conservan el plazo legal, por identificador y no por nombre.';

  @override
  String get consentRightsTitle => 'Tus derechos';

  @override
  String get consentRightsBody =>
      'Acceso, rectificación, exportación (art. 20), supresión (art. 17) y oposición — cada uno es un botón en Ajustes → Privacidad y datos. Para lo demás: fdittgen@gmail.com. Puedes retirar este consentimiento en cualquier momento saliendo del espacio y borrando tus datos.';

  @override
  String get consentReviewTitle => 'Vuelve a leerlo cuando quieras';

  @override
  String get consentReviewBody =>
      'Este texto sigue disponible en Ajustes → Privacidad y datos, en la ayuda de la app (Privacidad) y en el wiki del proyecto. Un cambio del texto vuelve a pedir tu aceptación.';

  @override
  String get consentCheckbox =>
      'He leído esto y acepto cómo DesKilo trata mis datos.';

  @override
  String get consentAccept => 'Aceptar y continuar';

  @override
  String get consentVersion => 'Versión';

  @override
  String consentAcceptedOn(String date, String version) {
    return 'Aceptado el $date ($version)';
  }

  @override
  String get consentReadInHelp => 'Leer en la ayuda';

  @override
  String get consentReadOnWiki => 'Leer en el wiki';

  @override
  String get consentReviewHint =>
      'El texto que aceptaste, con la fecha — vuelve a leerlo cuando quieras.';

  @override
  String get backendServerTitle => 'Servidor';

  @override
  String backendServerDefault(Object host) {
    return 'El servidor propio de la app ($host)';
  }

  @override
  String backendServerCustom(Object host) {
    return 'Tu propio servidor ($host)';
  }

  @override
  String get backendServerHint =>
      'Por defecto la app usa su propio servidor. Si tu comunidad tiene su propio proyecto de Supabase, introdúcelo aquí — la app guardará todo allí.';

  @override
  String get backendUrlLabel => 'URL del proyecto';

  @override
  String get backendKeyLabel => 'Clave publicable';

  @override
  String get backendServerRestartHint =>
      'La app cierra tu sesión y aplica el cambio en el próximo inicio.';

  @override
  String get backendServerReset => 'Usar el servidor de la app';

  @override
  String get backendServerSaved =>
      'Guardado. Cierra y vuelve a abrir la app para usar el nuevo servidor.';

  @override
  String get backendErrorUrlEmpty => 'Introduce la URL del proyecto.';

  @override
  String get backendErrorUrlNotHttps => 'La URL debe empezar por https://.';

  @override
  String get backendErrorUrlNoHost => 'Esa no es una dirección completa.';

  @override
  String get backendErrorKeyEmpty => 'Introduce la clave publicable.';

  @override
  String get backendErrorKeyNotSupabase =>
      'Esa no es una clave publicable de Supabase (sb_publishable_…).';

  @override
  String get backendCurrentTitle => 'Este dispositivo usa';

  @override
  String get backendHowTitle => 'Usar tu propio servidor';

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
  String get backendScan => 'Escanear un QR de servidor';

  @override
  String get backendScanNothing =>
      'Ese QR no es un código de servidor de DesKilo.';

  @override
  String get backendShare => 'Compartir este servidor';

  @override
  String get backendShareHint =>
      'Los miembros lo escanean en Ajustes → Servidor para apuntar su app a la misma instancia.';

  @override
  String get backendPaste => 'Pegar';

  @override
  String get backendTest => 'Probar la conexión';

  @override
  String get backendTesting => 'Probando…';

  @override
  String get backendTestOk => 'Contactado: el esquema de la app está ahí.';

  @override
  String get backendTestUnreachable =>
      'No se pudo contactar esa dirección. Revisa la URL y tu red.';

  @override
  String get backendTestBadKey =>
      'Contactado, pero la clave fue rechazada. Copia de nuevo la clave publicable desde Project Settings → API keys.';

  @override
  String get backendTestSchemaMissing =>
      'Contactado, pero faltan las tablas de DesKilo: ejecuta antes las migraciones de supabase/migrations en ese proyecto.';

  @override
  String get backendCopyLink => 'Copiar';

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
  String get memberSimultaneousLimitLabel => 'Reservas simultáneas';

  @override
  String get memberSimultaneousLimitExplainer =>
      'Cuántas reservas puede tener este miembro en el mismo periodo. Sin definir, se aplica el valor por defecto del espacio.';

  @override
  String get memberSimultaneousLimitDefault => 'Valor del espacio';

  @override
  String memberSimultaneousLimitChip(int n) {
    return '$n a la vez';
  }

  @override
  String get reportLayoutTitle => 'Maqueta posicionada (XML)';

  @override
  String get reportLayoutSubtitle =>
      'Una maqueta indica dónde se sitúa cada elemento, en mm, cm, px o %. Expórtela, edítela, compruébela con `dart run tool/report.dart check`, vuelva a importarla. Cuando existe una maqueta es la que se imprime; elimínela y vuelven a imprimirse las bandas.';

  @override
  String get reportLayoutActive => 'Maqueta activa';

  @override
  String get reportLayoutBands => 'Bandas';

  @override
  String get reportLayoutExport => 'Exportar XML';

  @override
  String get reportLayoutImport => 'Importar XML';

  @override
  String get reportLayoutPreview => 'Vista de página';

  @override
  String get reportLayoutRemove => 'Quitar la maqueta (bandas)';

  @override
  String get reportLayoutImported =>
      'Maqueta importada. Guarde para conservarla.';

  @override
  String get reportLayoutFileTypeLabel => 'XML';

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
  String get reportTextsTitle => 'Textos';

  @override
  String get reportTextsHint =>
      'Sus propias formulaciones, colocadas en cualquier banda o diseño como text.clave. Cada idioma puede tener su valor; uno vacío recurre al idioma predeterminado.';

  @override
  String get reportTextsAdd => 'Añadir un texto';

  @override
  String get reportTextsKey => 'Clave';

  @override
  String get reportTextsKeyHint =>
      'Letras, dígitos y guiones bajos, p. ej. saludo';

  @override
  String get reportTextsKeyInvalid =>
      'Solo letras, dígitos y guiones bajos, empezando por una letra.';

  @override
  String get reportTextsKeyExists => 'Esta clave ya existe.';

  @override
  String get reportTextsRemove => 'Eliminar texto';

  @override
  String get reportTextsInherited => 'Idioma predeterminado';

  @override
  String get reportFieldGroupTexts => 'Sus textos';

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
  String bookingCheckedInUntil(String until) {
    return 'Registrado hasta las $until.';
  }

  @override
  String bookingCheckedInAtUntil(String space, String until) {
    return 'Registrado en $space hasta las $until.';
  }

  @override
  String bookingReservedWhen(String when) {
    return 'Reservado: $when.';
  }

  @override
  String bookingReservedSpaceWhen(String space, String when) {
    return '$space reservado: $when.';
  }

  @override
  String bookingHorizonError(int days) {
    return 'Demasiado lejos — las reservas se abren con $days días de antelación.';
  }

  @override
  String bookingTooShortError(int minutes) {
    return 'Demasiado corta — una reserva dura al menos $minutes minutos.';
  }

  @override
  String bookingTooLongError(int minutes) {
    return 'Demasiado larga — una reserva dura como máximo $minutes minutos.';
  }

  @override
  String get legendFree => 'Libre';

  @override
  String get legendReserved => 'Reservada';

  @override
  String get legendOccupied => 'Con check-in';

  @override
  String get legendMine => 'Mía';

  @override
  String get legendBlocked => 'Bloqueada';

  @override
  String get legendClosed => 'Día cerrado';

  @override
  String get reserveClosedShort => 'Cerrado';

  @override
  String planCheckOutFor(String name) {
    return 'Dar salida a $name';
  }

  @override
  String get scanCameraWebUnavailable =>
      'El escaneo con cámara no está disponible en el navegador — escriba el código o acerque una etiqueta NFC al dispositivo (Chrome en Android).';

  @override
  String get bookingGateBlocked => 'No reservable así';

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
  String get spaceQrSizeLabel => 'Tamaño del código QR';

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
  String spaceMessageReserver(String name) {
    return 'Escribir a $name';
  }

  @override
  String get spaceYoursCheckedIn =>
      'Ha registrado su entrada aquí para esta franja.';

  @override
  String get spaceBlockedByYou => 'Ya tiene este espacio para ese periodo.';

  @override
  String get spaceManageMyBooking => 'Gestionar mi reserva';

  @override
  String get themeTitle => 'Tema';

  @override
  String get themeSystem => 'Predeterminado del sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get usageTitle => 'Uso';

  @override
  String get usageEmpty => 'Sin uso este mes.';

  @override
  String get usageBooked => 'Reservado';

  @override
  String get usagePresent => 'Presente';

  @override
  String get usageBilled => 'Facturado';

  @override
  String get usageNoShow => 'Nadie llegó: la reserva se factura entera';

  @override
  String get usageLeftEarly => 'Salió antes';

  @override
  String get usageCorrected => 'Corregido';

  @override
  String usageWas(String before) {
    return 'era $before';
  }

  @override
  String get usageAsk => 'Facturar el tiempo que estuve';

  @override
  String usageAskExplain(String booked, String present, String saved) {
    return 'Reservaste $booked y estuviste $present. Pide que las $saved no usadas dejen de facturarse. Lo decide otra persona, nunca tú.';
  }

  @override
  String get usageReasonLabel => 'Por qué (opcional)';

  @override
  String get usageAskSubmit => 'Pedir';

  @override
  String get usageAskSubmitted => 'Pedido. Lo decide otra persona.';

  @override
  String get usageDelete => 'Eliminar este registro';

  @override
  String get usageDeleteSubmitted => 'Eliminación solicitada.';

  @override
  String get usageMember => 'Miembro';

  @override
  String get usageMemberAll => 'Todos';

  @override
  String get featureUsageReport => 'Informe de consumo';

  @override
  String get featureUsageReportDesc =>
      'A fin de mes el miembro recibe lo que pagó su participación, lo que consumió realmente y lo que queda o excede — a partir de los registros de uso, como carta.';

  @override
  String get reportDocUsage => 'Informe de consumo';

  @override
  String get usageReportPaid => 'Pagado por adelantado (participación)';

  @override
  String get usageReportIncluded => 'Medias jornadas incluidas';

  @override
  String get usageReportUsed => 'Medias jornadas consumidas';

  @override
  String get usageReportRemaining => 'Medias jornadas restantes';

  @override
  String get usageReportExtra => 'Medias jornadas extra';

  @override
  String get usageReportOverage => 'Exceso trasladado a la próxima factura';

  @override
  String get usageReportSupplements =>
      'Suplementos (accesorios, mesas, despachos)';

  @override
  String get usageReportRecordsHeading => 'Lo consumido';

  @override
  String get usageReportButton => 'Informe de consumo del mes';

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
  String get validationTrailTitle => 'Historial de validación';

  @override
  String get validationTrailNone => 'Aún no hay decisión.';

  @override
  String validationTrailStep(int order) {
    return 'Paso $order';
  }

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
  String eventValidationStage(int stage, int required) {
    return 'Validación $stage de $required solicitada';
  }

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
  String get validationAutoValidateOwner =>
      'Los propietarios eliminan sin validación';

  @override
  String get validationAutoValidateAdmin =>
      'Los admins eliminan sin validación';

  @override
  String get validationAutoValidateDesc =>
      'Su propia solicitud de eliminación se resuelve sola y queda marcada como autovalidada.';

  @override
  String get validationNoSelfTitle => 'Nadie valida lo propio';

  @override
  String get validationNoSelfDesc =>
      'Quien crea un evento nunca lo valida. Espera a otra persona, o caduca sin decisión.';

  @override
  String get validationNoSelfShort => 'Nunca lo propio';

  @override
  String get validationOwnerSelf => 'La propiedad puede validar lo propio';

  @override
  String get validationOwnerSelfDesc =>
      'La única excepción, y es solo de la propiedad: un admin nunca valida su propio acto.';

  @override
  String get validationOwnerSelfShort => 'La propiedad puede validar lo propio';

  @override
  String get validationSequential => 'Una tras otra';

  @override
  String get validationSequentialDesc =>
      'La siguiente validación se pide cuando la anterior ha pasado, y el historial numera cada paso.';

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
  String get assistantPrefix => 'Asistente';

  @override
  String get settlementStepPick => 'Elegir facturas';

  @override
  String get settlementSummaryHint =>
      'Estas facturas se agrupan en un documento de liquidación; cada una sigue legible detrás.';

  @override
  String get repartitionStepExpense => 'El gasto';

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
  String get scanJoinNotAnInvite =>
      'Ese QR no es una invitación de DesKilo: escanea el del mensaje de invitación.';

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
  String get regionalFormatsTitle => 'Región y formatos';

  @override
  String get regionalFormatLocale => 'Números y fechas';

  @override
  String regionalFormatLocaleAuto(String locale) {
    return 'Sigue el idioma de la app ($locale)';
  }

  @override
  String get regionalFollowLanguage => 'Automático';

  @override
  String get regionalClock => 'Reloj';

  @override
  String get regionalClockAuto => 'Auto';

  @override
  String get regionalDeviceZone => 'Mostrar las horas en mi zona horaria';

  @override
  String get regionalDeviceZoneHint =>
      'Desactivado: las horas se muestran en la zona del espacio, en la que se reserva. Activado: la de su dispositivo, señalada cuando difiere.';

  @override
  String get workspaceTimezoneUnknown => 'Elija una zona horaria de la lista';

  @override
  String get countryNameCY => 'Chipre';

  @override
  String get countryNameEE => 'Estonia';

  @override
  String get countryNameFI => 'Finlandia';

  @override
  String get countryNameGR => 'Grecia';

  @override
  String get countryNameHR => 'Croacia';

  @override
  String get countryNameIE => 'Irlanda';

  @override
  String get countryNameLT => 'Lituania';

  @override
  String get countryNameLV => 'Letonia';

  @override
  String get countryNameMT => 'Malta';

  @override
  String get countryNameSI => 'Eslovenia';

  @override
  String get countryNameSK => 'Eslovaquia';

  @override
  String get countryNameBG => 'Bulgaria';

  @override
  String get countryNameCZ => 'Chequia';

  @override
  String get countryNameDK => 'Dinamarca';

  @override
  String get countryNameHU => 'Hungría';

  @override
  String get countryNamePL => 'Polonia';

  @override
  String get countryNameRO => 'Rumanía';

  @override
  String get countryNameSE => 'Suecia';

  @override
  String get regionalClock24h => '24h';

  @override
  String get regionalClock12h => '12h';

  @override
  String get countryNameMX => 'México';

  @override
  String get countryNameAU => 'Australia';

  @override
  String get countryNameJP => 'Japón';

  @override
  String get languageNameDE => 'Alemán';

  @override
  String get languageNameEN => 'Inglés';

  @override
  String get languageNameES => 'Español';

  @override
  String get languageNameFR => 'Francés';

  @override
  String get languageNameIT => 'Italiano';

  @override
  String get languageNameNL => 'Neerlandés';

  @override
  String get languageNamePT => 'Portugués';

  @override
  String get languageNamePL => 'Polaco';

  @override
  String get languageNameSV => 'Sueco';

  @override
  String get languageNameDA => 'Danés';

  @override
  String get languageNameNB => 'Noruego';

  @override
  String get languageNameFI => 'Finés';

  @override
  String get languageNameCS => 'Checo';

  @override
  String get languageNameHU => 'Húngaro';

  @override
  String get languageNameRO => 'Rumano';

  @override
  String get languageNameEL => 'Griego';

  @override
  String get languageNameJA => 'Japonés';

  @override
  String get countryNameCA => 'Canadá';

  @override
  String get countryNameNO => 'Noruega';

  @override
  String get permViewNegotiations => 'Consultar los acuerdos comerciales';

  @override
  String get permManageNegotiations => 'Gestionar los acuerdos comerciales';

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
