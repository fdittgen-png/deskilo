// SPDX-License-Identifier: 0BSD
import 'currencies.dart';

/// The active workspace's currency GRAIN — how many minor units make one
/// major unit (#1077).
///
/// Ambient for the same reason as [WorkspaceTime] and [WorkHours]: the
/// major-unit editor helpers are called from three dozen forms, most of
/// them inside builders and top-level helpers with no `ref` in scope, and
/// threading a currency code into every one of them would churn all of
/// it while adding nothing a reader needs at the call site. The shell
/// installs the active workspace's code on connect and on profile
/// switch, exactly where it installs the clock and the working day.
///
/// Null — tests, pre-connect boot — means the two-decimal default, which
/// is what those helpers always assumed. Money that is DISPLAYED does
/// not read this: `AppFormat.formatMinor` already takes the code
/// explicitly and stays the way to render an amount.
abstract final class WorkspaceCurrency {
  static String? _code;

  /// Installs [currencyCode] (ISO 4217) as the ambient grain.
  static void install(String? currencyCode) => _code = currencyCode;

  /// Back to the two-decimal default (tests).
  static void reset() => _code = null;

  /// The active code, or 'EUR' before one is installed.
  static String get code => _code ?? 'EUR';

  /// Minor units per major unit: 100 for the euro, 1 for the yen,
  /// 1 000 for the dinar.
  static int get minorPerMajor => Currencies.minorPerMajor(code);

  /// Digits after the decimal separator this currency carries.
  static int get minorDigits => Currencies.minorDigits(code);
}
