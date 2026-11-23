// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4423 -- the server names the app calls from more than one file: an RPC, a table or a storage
// bucket is spelled once, here, and every caller reads the constant. A name that only one data file
// calls stays a literal in that file (a row mapper names its column); `data_names_test` fails a name
// that two files quote, so it joins this file when its second caller appears.

/// RPCs called from more than one file.
abstract final class ServerRpc {
  static const exportMyData = 'export_my_data';
  static const finalizeIdentityBinding = 'finalize_identity_binding';
  static const mcpConsentOptions = 'mcp_consent_options';
  static const publicIdentityAuthority = 'public_identity_authority';
  static const roomOfferV1 = 'room_offer_v1';
  static const sendAccountMessage = 'send_account_message';
}

/// Tables read or written from more than one file.
abstract final class ServerTable {
  static const installationIdentity = 'installation_identity';
  static const levels = 'levels';
  static const memberNotes = 'member_notes';
  static const members = 'members';
  static const offices = 'offices';
  static const planImages = 'plan_images';
  static const profiles = 'profiles';
  static const reservations = 'reservations';
  static const seats = 'seats';
  static const services = 'services';
  static const sites = 'sites';
  static const stockLocations = 'stock_locations';
  static const suppliers = 'suppliers';
  static const workspaces = 'workspaces';
}

/// Storage buckets named in more than one file.
abstract final class ServerBucket {
  static const floorPlans = 'floor-plans';
}
