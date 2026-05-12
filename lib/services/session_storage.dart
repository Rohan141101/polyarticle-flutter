import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _key = 'flashfeed_session';
const _storage = FlutterSecureStorage();

Future<void> saveSession(String token) async {
  final trimmed = token.trim();
  if (trimmed.isEmpty) return;
  try {
    await _storage.write(key: _key, value: trimmed);
  } catch (e) {
    // ignore
  }
}

Future<String?> getSession() async {
  try {
    final token = await _storage.read(key: _key);
    return token?.trim();
  } catch (e) {
    return null;
  }
}

Future<void> clearSession() async {
  try {
    await _storage.delete(key: _key);
  } catch (e) {
    // ignore
  }
}
