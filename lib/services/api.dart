import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/article.dart';
import '../models/user.dart';
import '../models/session_model.dart';
import 'session_storage.dart';

const apiUrl = 'https://polyarticle-app.onrender.com';

Future<http.Response> _fetchWithTimeout(
  Uri url,
  Map<String, String> headers, {
  String method = 'GET',
  String? body,
  Duration timeout = const Duration(seconds: 60),
}) async {
  final client = http.Client();
  try {
    late http.Response response;
    final request = http.Request(method, url)..headers.addAll(headers);
    if (body != null) request.body = body;

    final streamedResponse =
        await client.send(request).timeout(timeout, onTimeout: () {
      throw TimeoutException('Request timed out. Please try again.');
    });
    response = await http.Response.fromStream(streamedResponse);
    return response;
  } finally {
    client.close();
  }
}

dynamic _handleJson(http.Response res) {
  final text = res.body;
  if (text.isEmpty) throw Exception('Empty response from server');

  dynamic data;
  try {
    data = json.decode(text);
  } catch (_) {
    throw Exception('Invalid JSON from server');
  }

  if (res.statusCode == 401) throw Exception('UNAUTHORIZED');

  if (res.statusCode < 200 || res.statusCode >= 300) {
    final err = data is Map ? data['error'] ?? text : text;
    throw Exception(err ?? 'Request failed');
  }

  return data;
}

Future<Map<String, dynamic>> signup({
  required String email,
  required String password,
  String? location,
  List<String>? interests,
  String? deviceName,
  String? deviceOS,
  String? guestToken,
}) async {
  final res = await _fetchWithTimeout(
    Uri.parse('$apiUrl/auth/signup'),
    {'Content-Type': 'application/json'},
    method: 'POST',
    body: json.encode({
      'email': email,
      'password': password,
      if (location != null) 'location': location,
      if (interests != null) 'interests': interests,
      if (deviceName != null) 'deviceName': deviceName,
      if (deviceOS != null) 'deviceOS': deviceOS,
      if (guestToken != null) 'guestToken': guestToken,
    }),
    timeout: const Duration(seconds: 30),
  );
  return _handleJson(res) as Map<String, dynamic>;
}

Future<String> createGuestSession({
  List<String>? interests,
  String? region,
}) async {
  final res = await _fetchWithTimeout(
    Uri.parse('$apiUrl/auth/guest'),
    {'Content-Type': 'application/json'},
    method: 'POST',
    body: json.encode({
      if (interests != null && interests.isNotEmpty) 'interests': interests,
      if (region != null) 'region': region,
      'deviceOS': 'ios',
      'platform': 'ios',
    }),
    timeout: const Duration(seconds: 30),
  );
  final data = _handleJson(res) as Map<String, dynamic>;
  return data['sessionToken'] as String;
}

Future<Map<String, dynamic>> login({
  required String email,
  required String password,
  String? deviceName,
  String? deviceOS,
}) async {
  final res = await _fetchWithTimeout(
    Uri.parse('$apiUrl/auth/login'),
    {'Content-Type': 'application/json'},
    method: 'POST',
    body: json.encode({
      'email': email,
      'password': password,
      if (deviceName != null) 'deviceName': deviceName,
      if (deviceOS != null) 'deviceOS': deviceOS,
    }),
    timeout: const Duration(seconds: 30),
  );
  return _handleJson(res) as Map<String, dynamic>;
}

Future<User> getMe({String? token}) async {
  final authToken = token ?? await getSession();
  if (authToken == null || authToken.isEmpty) throw Exception('NO_TOKEN');

  final res = await _fetchWithTimeout(
    Uri.parse('$apiUrl/auth/me'),
    {'Authorization': 'Bearer $authToken'},
  );
  final data = _handleJson(res) as Map<String, dynamic>;
  return User.fromJson(data['user'] as Map<String, dynamic>);
}

Future<void> updateLocation(String location) async {
  final token = await getSession();
  if (token == null || token.isEmpty) throw Exception('NO_TOKEN');

  final res = await _fetchWithTimeout(
    Uri.parse('$apiUrl/profile/location'),
    {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    method: 'PATCH',
    body: json.encode({'location': location}),
  );
  _handleJson(res);
}

Future<List<SessionModel>> getActiveSessions({String? token}) async {
  final authToken = token ?? await getSession();
  if (authToken == null || authToken.isEmpty) throw Exception('NO_TOKEN');

  final res = await _fetchWithTimeout(
    Uri.parse('$apiUrl/auth/sessions'),
    {'Authorization': 'Bearer $authToken'},
  );
  final data = _handleJson(res);
  final list = data is List ? data : (data['sessions'] as List? ?? []);
  return list
      .map((s) => SessionModel.fromJson(s as Map<String, dynamic>))
      .toList();
}

Future<void> logout({String? sessionToken}) async {
  final token = sessionToken ?? await getSession();
  if (token == null || token.isEmpty) throw Exception('NO_TOKEN');

  final res = await _fetchWithTimeout(
    Uri.parse('$apiUrl/auth/logout'),
    {'Authorization': 'Bearer $token'},
    method: 'POST',
  );
  _handleJson(res);
}

Future<void> revokeOtherSessions({String? token}) async {
  final authToken = token ?? await getSession();
  if (authToken == null || authToken.isEmpty) throw Exception('NO_TOKEN');

  final res = await _fetchWithTimeout(
    Uri.parse('$apiUrl/auth/revoke-others'),
    {'Authorization': 'Bearer $authToken'},
    method: 'POST',
  );
  _handleJson(res);
}

Future<void> revokeSessionById(String sessionId) async {
  final token = await getSession();
  if (token == null || token.isEmpty) throw Exception('NO_TOKEN');

  final res = await _fetchWithTimeout(
    Uri.parse('$apiUrl/auth/revoke-session'),
    {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    method: 'POST',
    body: json.encode({'sessionId': sessionId}),
  );
  _handleJson(res);
}

Future<List<Article>> fetchNews(
  String? category, {
  int page = 1,
  int limit = 10,
  bool fresh = false,
}) async {
  final token = await getSession();

  final selectedCategory = category ?? 'For You';
  final url = Uri.parse(
    '$apiUrl/news?category=${Uri.encodeComponent(selectedCategory)}&page=$page&limit=$limit&fresh=$fresh',
  );

  final headers = <String, String>{};
  if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

  final res = await _fetchWithTimeout(url, headers,
      timeout: const Duration(seconds: 20));
  final data = _handleJson(res) as Map<String, dynamic>;
  final articles = data['data'] as List? ?? [];

  return articles.map((a) {
    final map = a as Map<String, dynamic>;
    String? imageUrl = map['image_url'] as String?;
    if (imageUrl != null) {
      imageUrl = imageUrl.replaceAll('&amp;', '&');
    }
    return Article(
      id: map['id'].toString(),
      title: map['title'] as String,
      summary: map['summary'] as String,
      image: imageUrl,
      url: map['url'] as String,
      source: map['source'] as String? ?? '',
      publishedAt: map['published_at'] as String?,
      category: map['category'] as String?,
    );
  }).toList();
}

Future<List<Article>> fetchRegionalNews({int limit = 10}) async {
  final token = await getSession();

  final headers = <String, String>{};
  if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

  final res = await _fetchWithTimeout(
    Uri.parse('$apiUrl/news/regional?limit=$limit'),
    headers,
    timeout: const Duration(seconds: 20),
  );
  final data = _handleJson(res) as Map<String, dynamic>;
  final articles = data['data'] as List? ?? [];

  return articles.map((a) {
    final map = a as Map<String, dynamic>;
    String? imageUrl = map['image_url'] as String?;
    if (imageUrl != null) {
      imageUrl = imageUrl.replaceAll('&amp;', '&');
    }
    return Article(
      id: map['id'].toString(),
      title: map['title'] as String,
      summary: map['summary'] as String,
      image: imageUrl,
      url: map['url'] as String,
      source: map['source'] as String? ?? '',
      publishedAt: map['published_at'] as String?,
      category: map['category'] as String?,
      country: map['country'] as String?,
    );
  }).toList();
}
