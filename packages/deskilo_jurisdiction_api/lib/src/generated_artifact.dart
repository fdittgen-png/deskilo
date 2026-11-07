// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

/// A file an add-on generated: its bytes in the encoding its channel reads,
/// its media type and name, its digest and who produced it.
class GeneratedArtifact {
  GeneratedArtifact({
    required List<int> bytes,
    required this.mediaType,
    required this.fileName,
    required Map<String, String> provenance,
  }) : bytes = Uint8List.fromList(bytes),
       sha256 = crypto.sha256.convert(bytes).toString(),
       provenance = Map.unmodifiable(provenance);

  /// A private copy of the bytes: the artifact does not change after it is built.
  final Uint8List bytes;
  final String mediaType;
  final String fileName;

  /// The lower-case hex SHA-256 of [bytes].
  final String sha256;

  /// The producer's `CapabilityDescriptor.toProvenance()`.
  final Map<String, String> provenance;
}
