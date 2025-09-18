import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  ApiService({required this.baseUrl, this.ownerEmail, this.actorEmail});

  final String baseUrl; // like https://script.google.com/macros/s/AKfycb.../exec
  final String? ownerEmail; // Owner's email for Google Sheets
  String? actorEmail; // logged-in user email (employee/owner)

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
  };

  static const _timeout = Duration(seconds: 20);

  Future<Map<String, dynamic>> getMasters() async {
    final params = <String, String>{'action': 'masters'};
    if (ownerEmail != null) params['ownerEmail'] = ownerEmail!;
    final uri = Uri.parse(baseUrl).replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers).timeout(_timeout);
    return _decode(resp);
  }

  Future<Map<String, dynamic>> addMaster({required String type, required String value, required String role}) async {
    final uri = Uri.parse(baseUrl);
    final payload = {'action': 'addMaster', 'type': type, 'value': value, 'role': role};
    if (ownerEmail != null) payload['ownerEmail'] = ownerEmail!;
    final body = jsonEncode(payload);
    final resp = await http.post(uri, headers: _headers, body: body).timeout(_timeout);
    return _decode(resp);
  }

  Future<Map<String, dynamic>> addRepair({
    required String customerName,
    required String phone,
    required String product,
    required String faultDescription,
    required String estimatedTime,
    String? assignedEmployee,
    String? employeeNotes,
    String? faultVoiceNoteBase64,
    String? faultVoiceNoteFilename,
  }) async {
    final uri = Uri.parse(baseUrl);
    final payload = {
      'action': 'add',
      'data': {
        'CustomerName': customerName,
        'Phone': phone,
        'Product': product,
        'FaultDescription': faultDescription,
        'EstimatedTime': estimatedTime,
        if (assignedEmployee != null && assignedEmployee.isNotEmpty) 'AssignedEmployee': assignedEmployee,
        if (employeeNotes != null && employeeNotes.isNotEmpty) 'EmployeeNotes': employeeNotes,
        if (faultVoiceNoteBase64 != null && faultVoiceNoteBase64.isNotEmpty) 'FaultVoiceNoteBase64': faultVoiceNoteBase64,
        if (faultVoiceNoteFilename != null && faultVoiceNoteFilename.isNotEmpty) 'FaultVoiceNoteFilename': faultVoiceNoteFilename,
      }
    };
    if (ownerEmail != null) payload['ownerEmail'] = ownerEmail!;
    if (actorEmail != null) payload['actorEmail'] = actorEmail!;
    final body = jsonEncode(payload);
    final resp = await http.post(uri, headers: _headers, body: body).timeout(_timeout);
    return _decode(resp);
  }

  Future<Map<String, dynamic>> updateStatus({
    required String uniqueId,
    required String status,
    String? notes,
    String? role,
    String? actorEmail,
  }) async {
    final uri = Uri.parse(baseUrl);
    final payload = {
      'action': 'updateStatus',
      'uniqueId': uniqueId,
      'status': status,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (role != null && role.isNotEmpty) 'role': role,
      if (actorEmail != null && actorEmail.isNotEmpty) 'actorEmail': actorEmail,
    };
    if (ownerEmail != null) payload['ownerEmail'] = ownerEmail!;
    final body = jsonEncode(payload);
    final resp = await http.post(uri, headers: _headers, body: body).timeout(_timeout);
    return _decode(resp);
  }

  Future<Map<String, dynamic>> getAll() async {
    final params = <String, String>{'action': 'all'};
    if (ownerEmail != null) params['ownerEmail'] = ownerEmail!;
    final uri = Uri.parse(baseUrl).replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers).timeout(_timeout);
    return _decode(resp);
  }

  Future<List<Map<String, dynamic>>> getEmployees() async {
    final params = <String, String>{'action': 'employees'};
    if (ownerEmail != null) params['ownerEmail'] = ownerEmail!;
    final uri = Uri.parse(baseUrl).replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers).timeout(_timeout);
    final map = _decode(resp);
    if (map['success'] == true) {
      final list = (map['data'] as List?)?.map((e) => (e as Map).map((k, v) => MapEntry('$k', v))).cast<Map<String, dynamic>>().toList() ?? [];
      return list;
    }
    return [];
  }

  Future<Map<String, dynamic>> search({String? uniqueId, String? customerName, String? phone}) async {
    final params = <String, String>{'action': 'search'};
    if (uniqueId != null && uniqueId.isNotEmpty) params['uniqueId'] = uniqueId;
    if (customerName != null && customerName.isNotEmpty) params['customerName'] = customerName;
    if (phone != null && phone.isNotEmpty) params['phone'] = phone;
    if (ownerEmail != null) params['ownerEmail'] = ownerEmail!;
    final uri = Uri.parse(baseUrl).replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers).timeout(_timeout);
    return _decode(resp);
  }

  Future<Map<String, dynamic>> setupOwner({required String ownerEmail}) async {
    final uri = Uri.parse(baseUrl);
    final body = jsonEncode({'action': 'setup', 'ownerEmail': ownerEmail});
    final resp = await http.post(uri, headers: _headers, body: body).timeout(_timeout);
    return _decode(resp);
  }

  Future<Map<String, dynamic>> requestAccess({required String email}) async {
    final uri = Uri.parse(baseUrl);
    final body = jsonEncode({'action': 'requestAccess', 'email': email});
    final resp = await http.post(uri, headers: _headers, body: body).timeout(_timeout);
    return _decode(resp);
  }

  Future<Map<String, dynamic>> approveEmployee({required String email}) async {
    final uri = Uri.parse(baseUrl);
    final body = jsonEncode({'action': 'approveEmployee', 'email': email, 'role': 'Owner'});
    final resp = await http.post(uri, headers: _headers, body: body).timeout(_timeout);
    return _decode(resp);
  }

  Future<Map<String, dynamic>> removeEmployee({required String email}) async {
    final uri = Uri.parse(baseUrl);
    final body = jsonEncode({'action': 'removeEmployee', 'email': email, 'role': 'Owner'});
    final resp = await http.post(uri, headers: _headers, body: body).timeout(_timeout);
    return _decode(resp);
  }

  Future<Map<String, dynamic>> handover({required String uniqueId}) async {
    final uri = Uri.parse(baseUrl);
    final body = jsonEncode({'action': 'handover', 'uniqueId': uniqueId});
    final resp = await http.post(uri, headers: _headers, body: body).timeout(_timeout);
    return _decode(resp);
  }

  Map<String, dynamic> _decode(http.Response resp) {
    try {
      final map = jsonDecode(resp.body) as Map<String, dynamic>;
      return map;
    } catch (e) {
      final body = resp.body.trim();
      if (body.startsWith('<')) {
        throw FormatException('Apps Script returned HTML (status ${resp.statusCode}). Ensure Web App access is "Anyone" and _baseUrl points to the latest deployment.');
      }
      rethrow;
    }
  }
}
