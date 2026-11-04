// SPDX-License-Identifier: AGPL-3.0-or-later
// Bundled synthetic wayfinding illustration; never reads remote storage.
import 'package:flutter/services.dart';

import 'floor_plan_repository.dart';

class CityFloorPlanRepository extends FakeFloorPlanRepository {
  Future<Uint8List>? _locator;

  @override
  Future<Uint8List?> fetchPlanImageBytes(String imageId) async {
    if (imageId.endsWith('-locator') &&
        planImages.any((image) => image.id == imageId)) {
      return _locator ??= rootBundle
          .load('assets/demo/office-locator.png')
          .then(
            (data) =>
                data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
    }
    return super.fetchPlanImageBytes(imageId);
  }
}
