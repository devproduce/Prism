import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:prism/utils/constants.dart';

class EngagementApi {
  static final EngagementApi _instance = EngagementApi._internal();
  factory EngagementApi() => _instance;
  EngagementApi._internal();

  final http.Client _client = http.Client();

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

    try {
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(
          errorBody['detail'] ?? 'Failed to submit feedback',
        );
      }
    } catch (e) {
      throw Exception('Failed to submit feedback: $e');
    }
  }
}
