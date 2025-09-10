import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  ApiService({required this.baseUrl});

  final String baseUrl; // like https://script.google.com/macros/s/AKfycb.../exec

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
  };

  Future<Map<String, dynamic>> addRepair({
    required String customerName,
    required String phone,
    required String product,
    required String issue,
    required String estimatedTime,
    required String assignedTo,
    String? notes,
  }) async {
    final uri = Uri.parse(baseUrl);
    final body = jsonEncode({
      'action': 'add',
      'data': {
        'CustomerName': customerName,
        'Phone': phone,
        'Product': product,
        'Issue': issue,
        'EstimatedTime': estimatedTime,
        'AssignedTo': assignedTo,
        if (notes != null && notes.isNotEmpty) 'Notes': notes,
      }
    });
    final resp = await http.post(uri, headers: _headers, body: body);
    return _decode(resp);
  }

  Future<Map<String, dynamic>> updateStatus({
    required String repairId,
    required String status,
    String? notes,
  }) async {
    final uri = Uri.parse(baseUrl);
    final body = jsonEncode({
      'action': 'updateStatus',
      'repairId': repairId,
      'status': status,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    final resp = await http.post(uri, headers: _headers, body: body);
    return _decode(resp);
  }

  Future<Map<String, dynamic>> getAll() async {
    final uri = Uri.parse('$baseUrl?action=all');
    final resp = await http.get(uri, headers: _headers);
    return _decode(resp);
  }

  Future<Map<String, dynamic>> search({String? repairId, String? customerName}) async {
    final params = <String, String>{'action': 'search'};
    if (repairId != null && repairId.isNotEmpty) params['repairId'] = repairId;
    if (customerName != null && customerName.isNotEmpty) params['customerName'] = customerName;
    final uri = Uri.parse(baseUrl).replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers);
    return _decode(resp);
  }

  Map<String, dynamic> _decode(http.Response resp) {
    final map = jsonDecode(resp.body) as Map<String, dynamic>;
    return map;
  }
}
