// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:http/http.dart' as http;

/// Never follow a redirect carrying any installation's key or bearer elsewhere.
class OriginOnlyClient extends http.BaseClient {
  OriginOnlyClient(this.origin, this.inner);
  final String origin;
  final http.Client inner;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request.url.origin != origin) {
      throw StateError('cross-origin request refused');
    }
    request.followRedirects = false;
    return inner.send(request).timeout(const Duration(seconds: 20));
  }

  @override
  void close() => inner.close();
}
