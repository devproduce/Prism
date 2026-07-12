import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:prism/api/api_client.dart';
import 'package:prism/utils/constants.dart';

class EngagementApi {
  static final EngagementApi _instance = EngagementApi._internal();
  factory EngagementApi() => _instance;
  EngagementApi._internal();

  final http.Client _client = http.Client();
  final ApiClient _apiClient = ApiClient();

  /// Submit user feedback
  Future<Map<String, dynamic>> submitFeedback({
    required String userId,
    required String email,
    required String feedbackType,
    String? category,
    required String message,
    String source = 'dashboard',
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/engagement/feedback');

    final body = {
      'user_id': userId,
      'email': email,
      'feedback_type': feedbackType,
      if (category != null) 'category': category,
      'message': message,
      'source': source,
    };

    if (!await _apiClient.ensureAuthenticated()) {
      throw ApiException('Your session has expired. Please log in again.', 401);
    }

    final token = _apiClient.token;
    final response = await _client.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: json.encode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
        return {'ok': true};
      } catch (_) {
        return {'ok': true};
      }
    }

    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map<String, dynamic>) {
        throw ApiException(
          errorBody['detail']?.toString() ?? 'Failed to submit feedback',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
    }

    throw ApiException('Failed to submit feedback', response.statusCode);
  }
}
