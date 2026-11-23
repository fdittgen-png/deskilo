// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4417 -- the standard Postgres and PostgREST codes the app reacts to, spelled once. A code
// the server raises of its own is a [DkCode] (generated from the migrations).

/// SQLSTATE and PostgREST codes the app reads.
abstract final class PgCode {
  /// `insufficient_privilege`: the caller may not.
  static const insufficientPrivilege = '42501';

  /// `invalid_parameter_value`.
  static const invalidParameterValue = '22023';

  /// `serialization_failure`: the transaction is retried.
  static const serializationFailure = '40001';

  /// `undefined_function`: a server that does not have the function yet.
  static const undefinedFunction = '42883';

  /// `undefined_column`.
  static const undefinedColumn = '42703';

  /// `feature_not_supported`.
  static const featureNotSupported = '0A000';

  /// `unique_violation`.
  static const uniqueViolation = '23505';

  /// `invalid_authorization_specification`.
  static const invalidAuthorization = '28000';

  /// `raise_exception`: a bare `raise exception`, never a refusal the app maps.
  static const raiseException = 'P0001';

  /// PostgREST: the function is not in the schema cache.
  static const pgrstFunctionNotFound = 'PGRST202';

  /// PostgREST: the JWT is expired or invalid.
  static const pgrstJwtExpired = 'PGRST301';

  /// PostgREST: the JWT is not valid for this request.
  static const pgrstJwtInvalid = 'PGRST302';
}
