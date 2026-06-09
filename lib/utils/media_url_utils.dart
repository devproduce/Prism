import 'package:prism/utils/constants.dart';

/// URL resolution and auth header helpers for batch/review media.
class MediaUrlUtils {
  MediaUrlUtils._();

  static String? resolve(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    final cleanUrl = url.startsWith('/') ? url.substring(1) : url;
    return '${ApiConstants.baseUrl}/$cleanUrl';
  }

  /// Returns auth headers for API-hosted images; skips S3 signed URLs.
  static Map<String, String>? authHeaders(String? url, String? token) {
    if (url?.contains('X-Amz-Signature') ?? false) return null;
    if (token == null || token.isEmpty) return null;
    return {'Authorization': 'Bearer $token'};
  }
}
