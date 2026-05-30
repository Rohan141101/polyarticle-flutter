import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/user.dart';
import '../services/api.dart' as api;
import '../services/session_storage.dart';
import '../services/event_logger.dart';

class AuthProvider extends ChangeNotifier {
  String? _sessionToken;
  User? _user;
  bool _loading = true;

  String? get sessionToken => _sessionToken;
  User? get user => _user;
  bool get loading => _loading;
  bool get isAuthenticated => _sessionToken != null && _user != null;

  AuthProvider() {
    _hydrateSession();
  }

  Future<void> _hydrateSession() async {
    final token = await getSession();
    if (token == null || token.isEmpty) {
      _loading = false;
      notifyListeners();
      return;
    }

    // Guest tokens are not user sessions — skip getMe to avoid clearing them
    final prefs = await SharedPreferences.getInstance();
    final isGuest = prefs.getBool('guest_mode') ?? false;
    if (isGuest) {
      _loading = false;
      notifyListeners();
      return;
    }

    try {
      final userData = await api.getMe(token: token)
          .timeout(const Duration(seconds: 10));
      _sessionToken = token;
      _user = userData;
      eventLogger.setToken(token);
      _registerFcmToken();
    } on TimeoutException {
      _sessionToken = null;
      _user = null;
    } catch (e) {
      await clearSession();
      _sessionToken = null;
      _user = null;
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> loginSuccess(String token) async {
    await saveSession(token);
    _sessionToken = token;
    eventLogger.setToken(token);
    try {
      final userData = await api.getMe(token: token);
      _user = userData;
    } catch (_) {}
    notifyListeners();
    _registerFcmToken();
  }

  Future<void> _registerFcmToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final fcmToken = await messaging.getToken();
        if (fcmToken != null) {
          final platform = Platform.isIOS ? 'ios' : 'android';
          await api.registerDeviceToken(fcmToken, platform);
        }
      }
    } catch (_) {}
  }

  Future<void> logout() async {
    final token = _sessionToken;
    _sessionToken = null;
    _user = null;
    eventLogger.setToken(null);
    notifyListeners();
    try {
      if (token != null) await api.logout(sessionToken: token);
    } catch (_) {}
    await clearSession();
  }

  Future<void> refreshUser() async {
    try {
      final userData = await api.getMe();
      _user = userData;
      notifyListeners();
    } catch (_) {}
  }
}
