import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import 'debug_log_service.dart';

class AiService {
  static const String _openAiUrl =
      'https://api.openai.com/v1/chat/completions';
  static const String _model = 'gpt-4o';
  static const int _maxTokens = 400;

  String? _cachedApiKey;

  Future<String?> _getApiKey() async {
    if (_cachedApiKey != null) return _cachedApiKey;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('ai_config')
          .get();
      _cachedApiKey = doc.data()?['openai_api_key'] as String?;
      return _cachedApiKey;
    } catch (e) {
      await DebugLogService.log('AI', '_getApiKey error',
          data: {'error': e.toString()});
      return null;
    }
  }

  Future<Map<String, dynamic>?> _callVision(
    File imageFile,
    String prompt,
  ) async {
    try {
      final apiKey = await _getApiKey();
      if (apiKey == null) {
        await DebugLogService.log('AI', 'no API key in config/ai_config');
        return null;
      }
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final ext = imageFile.path.split('.').last.toLowerCase();
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

      final response = await http.post(
        Uri.parse(_openAiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': _maxTokens,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:$mimeType;base64,$base64Image',
                    'detail': 'low',
                  },
                },
                {'type': 'text', 'text': prompt},
              ],
            }
          ],
        }),
      );

      if (response.statusCode != 200) {
        await DebugLogService.log('AI', 'vision call failed', data: {
          'statusCode': response.statusCode,
          'body': response.body,
        });
        return null;
      }

      final decoded = jsonDecode(response.body);
      final content =
          decoded['choices']?[0]?['message']?['content'] as String?;
      if (content == null) return null;

      final clean =
          content.replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(clean) as Map<String, dynamic>;
    } catch (e) {
      await DebugLogService.log('AI', '_callVision error',
          data: {'error': e.toString()});
      return null;
    }
  }

  /// Generic vision call for future features — supply any JSON-returning prompt.
  Future<Map<String, dynamic>?> analyzeWithPrompt(
    File imageFile,
    String prompt,
  ) =>
      _callVision(imageFile, prompt);

  /// Returns { crowd_score: int, description: String }
  /// Called from PostScreen after image selection.
  Future<Map<String, dynamic>?> analyzeVenueImage(File imageFile) async {
    const prompt = '''
You are analyzing a venue photo for a real-time crowd intelligence app.
Return ONLY valid JSON with no markdown, no backticks, no preamble:
{
  "crowd_score": <integer 0-10, where 0=completely empty, 5=moderately busy, 10=dangerously packed>,
  "description": "<one concise sentence describing the crowd conditions visible>"
}
If the image does not show an indoor or outdoor venue, return { "crowd_score": -1, "description": "Not a venue" }.
''';
    return _callVision(imageFile, prompt);
  }

  /// Returns { description: String }
  /// Auto-generates a post description from a venue photo.
  Future<Map<String, dynamic>?> generatePostDescription(
    File imageFile,
    int crowdScore,
  ) async {
    final prompt = '''
You are generating a short venue description for a crowd intelligence app post.
The crowd score for this venue is $crowdScore out of 10 (0=empty, 10=packed).
Return ONLY valid JSON with no markdown, no backticks, no preamble:
{
  "description": "<two sentences max: describe the atmosphere, vibe, and crowd conditions visible in the photo>"
}
''';
    return _callVision(imageFile, prompt);
  }

  /// Returns { valid: bool, confidence: double, reason: String }
  /// Validates that the user-reported crowd score is plausible given the photo.
  Future<Map<String, dynamic>?> validateCrowdScore(
    File imageFile,
    int reportedScore,
  ) async {
    final prompt = '''
A user is reporting a crowd score of $reportedScore out of 10 for this venue photo (0=empty, 10=packed).
Assess whether this score is plausible given what you see.
Return ONLY valid JSON with no markdown, no backticks, no preamble:
{
  "valid": <true or false>,
  "confidence": <float 0.0 to 1.0 indicating your confidence in the assessment>,
  "reason": "<one sentence explanation>"
}
''';
    return _callVision(imageFile, prompt);
  }
}
