import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Set this to your Contabo server URL after deployment
  // TODO: Update to Contabo server URL after deployment
  static const String _baseUrl = 'http://10.0.2.2:8000';

  String get baseUrl => _baseUrl;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String?> get accessToken async =>
      (await _prefs).getString('access_token');

  Future<String?> get refreshToken async =>
      (await _prefs).getString('refresh_token');

  Future<void> saveTokens(String access, String refresh) async {
    final prefs = await _prefs;
    await prefs.setString('access_token', access);
    await prefs.setString('refresh_token', refresh);
  }

  Future<void> clearTokens() async {
    final prefs = await _prefs;
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('last_synced_at');
  }

  Future<bool> get isLoggedIn async => (await accessToken) != null;

  Future<DateTime?> get lastSyncedAt async {
    final prefs = await _prefs;
    final ms = prefs.getInt('last_synced_at');
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true) : null;
  }

  Future<void> setLastSyncedAt(DateTime dt) async {
    final prefs = await _prefs;
    await prefs.setInt('last_synced_at', dt.millisecondsSinceEpoch);
  }

  /// Makes an authenticated request, auto-refreshing the token if needed.
  Future<http.Response> authenticatedRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    var token = await accessToken;
    if (token == null) throw Exception('Not authenticated');

    var response = await _makeRequest(method, path, token, body);

    // If 401, try refreshing
    if (response.statusCode == 401) {
      final refreshed = await _refreshTokens();
      if (!refreshed) throw Exception('Session expired');
      token = await accessToken;
      response = await _makeRequest(method, path, token!, body);
    }

    return response;
  }

  Future<http.Response> _makeRequest(
    String method,
    String path,
    String token,
    Map<String, dynamic>? body,
  ) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    switch (method) {
      case 'POST':
        return http.post(uri, headers: headers, body: jsonEncode(body));
      case 'GET':
        return http.get(uri, headers: headers);
      default:
        return http.get(uri, headers: headers);
    }
  }

  Future<bool> _refreshTokens() async {
    final refresh = await refreshToken;
    if (refresh == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refresh}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveTokens(data['access_token'], data['refresh_token']);
        return true;
      }
    } catch (_) {}

    await clearTokens();
    return false;
  }

  // ─── Auth endpoints ────────────────────────────────────────

  Future<Map<String, dynamic>> register(
    String email,
    String username,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      await saveTokens(data['access_token'], data['refresh_token']);
      return data;
    }
    throw Exception(jsonDecode(response.body)['detail'] ?? 'Registration failed');
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await saveTokens(data['access_token'], data['refresh_token']);
      return data;
    }
    throw Exception(jsonDecode(response.body)['detail'] ?? 'Login failed');
  }

  Future<void> logout() async {
    await clearTokens();
  }
}
