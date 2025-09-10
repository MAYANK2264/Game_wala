import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  ApiService({required this.baseUrl});

  final String baseUrl; // like https://script.google.com/macros/s/AKfycb.../exec

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
  };

  static const _timeout = Duration(seconds: 20);

  Future<Map<String, dynamic>> getMasters() async {
    final uri = Uri.parse('$baseUrl?action=masters');
    final resp = await http.get(uri, headers: _headers).timeout(_timeout);
    return _decode(resp);
  }

  Future<Map<String, dynamic>> addMaster({required String type, required String value, required String role}) async {
    final uri = Uri.parse(baseUrl);
    final body = jsonEncode({'action': 'addMaster', 'type': type, 'value': value, 'role': role});
    final resp = await http.post(uri, headers: _headers, body: body).timeout(_timeout);
    return _decode(resp);
  }

  Future<Map<String, dynamic>> addRepair({
    required String customerName,
    required String phone,
    required String product,
    required String issue,
    required String estimatedTime,
    required String assignedTo,
    String? notes,
    String? voiceNoteBase64,
    String? voiceNoteFilename,
  }) async {
    final uri = Uri.parse(baseUrl);
    final payload = {
      'action': 'add',
      'data': {
        'CustomerName': customerName,
        'Phone': phone,
        'Product': product,
        'Issue': issue,
        'EstimatedTime': estimatedTime,
        'AssignedTo': assignedTo,
        if (notes != null && notes.isNotEmpty) 'Notes': notes,
        if (voiceNoteBase64 != null && voiceNoteBase64.isNotEmpty) 'VoiceNoteBase64': voiceNoteBase64,
        if (voiceNoteFilename != null && voiceNoteFilename.isNotEmpty) 'VoiceNoteFilename': voiceNoteFilename,
      }
    };
    final body = jsonEncode(payload);
    final resp = await http.post(uri, headers: _headers, body: body).timeout(_timeout);
    return _decode(resp);
  }

  Future<Map<String, dynamic>> updateStatus({
    required String repairId,
    required String status,
    String? notes,
    String? role,
    String? actorName,
  }) async {
    final uri = Uri.parse(baseUrl);
    final body = jsonEncode({
      'action': 'updateStatus',
      'repairId': repairId,
      'status': status,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (role != null && role.isNotEmpty) 'role': role,
      if (actorName != null && actorName.isNotEmpty) 'actorName': actorName,
    });
    final resp = await http.post(uri, headers: _headers, body: body).timeout(_timeout);
    return _decode(resp);
  }

  Future<Map<String, dynamic>> getAll() async {
    final uri = Uri.parse('$baseUrl?action=all');
    final resp = await http.get(uri, headers: _headers).timeout(_timeout);
    return _decode(resp);
  }

  Future<Map<String, dynamic>> search({String? repairId, String? customerName}) async {
    final params = <String, String>{'action': 'search'};
    if (repairId != null && repairId.isNotEmpty) params['repairId'] = repairId;
    if (customerName != null && customerName.isNotEmpty) params['customerName'] = customerName;
    final uri = Uri.parse(baseUrl).replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers).timeout(_timeout);
    return _decode(resp);
  }

  Map<String, dynamic> _decode(http.Response resp) {
    final map = jsonDecode(resp.body) as Map<String, dynamic>;
    return map;
  }
}
