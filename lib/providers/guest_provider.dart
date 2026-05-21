import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GuestProvider extends ChangeNotifier {
  bool _isGuest = false;
  bool _setupDone = false;
  List<String> _interests = [];
  String _region = 'USA';
  bool _loaded = false;

  bool get isGuest => _isGuest;
  bool get setupDone => _setupDone;
  List<String> get interests => _interests;
  String get region => _region;
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isGuest = prefs.getBool('guest_mode') ?? false;
    _setupDone = prefs.getBool('guest_setup_done') ?? false;
    _interests = prefs.getStringList('guest_interests') ?? [];
    _region = prefs.getString('guest_region') ?? 'USA';
    _loaded = true;
    notifyListeners();
  }

  Future<void> startGuest() async {
    _isGuest = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('guest_mode', true);
    notifyListeners();
  }

  Future<void> saveInterests(List<String> interests) async {
    _interests = interests;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('guest_interests', interests);
    notifyListeners();
  }

  Future<void> saveRegion(String region) async {
    _region = region;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('guest_region', region);
    notifyListeners();
  }

  Future<void> completeSetup() async {
    _setupDone = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('guest_setup_done', true);
    notifyListeners();
  }

  Future<void> clearGuest() async {
    _isGuest = false;
    _setupDone = false;
    _interests = [];
    _region = 'USA';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('guest_mode');
    await prefs.remove('guest_setup_done');
    await prefs.remove('guest_interests');
    await prefs.remove('guest_region');
    notifyListeners();
  }
}
