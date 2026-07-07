// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get authSignInTitle => 'Iniciar sesión';

  @override
  String get authSignUpTitle => 'Crear cuenta';

  @override
  String get authEmailLabel => 'Correo electrónico';

  @override
  String get authPasswordLabel => 'Contraseña';

  @override
  String get authDisplayNameLabel => 'Nombre visible';

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
  String get comingSoon => 'Próximamente';

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
  String get planReserveButton => 'Reservar';

  @override
  String get planReservationsEmpty => 'No hay reservas para este día.';

  @override
  String planStartsAt(String time) {
    return 'Empieza a las $time';
  }

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
}
