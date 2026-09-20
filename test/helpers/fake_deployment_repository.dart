// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Moved to lib/core/demo/data by ADR 0028: the suite's in-memory
// repositories are the Demo backend, so they live where the app can
// reach them. This shim keeps every existing import working.
export 'package:deskilo/core/demo/data/deployment_repository.dart';
