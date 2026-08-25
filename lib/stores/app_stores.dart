/// Global application state: authentication and theme selection.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api.dart';
import '../core/models.dart';

/// Which of the four built-in visual themes is active.
enum AppThemeMode { material, metro, clean, midnight }

class ThemeStore extends ChangeNotifier {
  ThemeStore(this._prefs) {
    final saved = _prefs.getString('zv_theme');
    _mode = AppThemeMode.values
        .where((m) => m.name == saved)
        .firstOrNull ?? AppThemeMode.clean;
  }

  final SharedPreferences _prefs;
  late AppThemeMode _mode;

  AppThemeMode get mode => _mode;

  void setMode(AppThemeMode m) {
    if (m == _mode) return;
    _mode = m;
    _prefs.setString('zv_theme', m.name);
    notifyListeners();
  }
}

/// Holds the JWT token + the profile of the signed-in user.
class AuthStore extends ChangeNotifier {
  AuthStore(this._prefs, this.api) {
    _token = _prefs.getString('zv_token');
    api.onToken = () => _token;
  }

  final SharedPreferences _prefs;
  final ZerexaApi api;

  String? _token;
  UserInfo? _user;
  bool initializing = true;

  String? get token => _token;
  UserInfo? get user => _user;
  bool get isAuthed => _token != null && _token!.isNotEmpty;
  bool get isAdmin => _user?.isAdmin ?? false;

  /// Restores the session from the persisted token (called at startup).
  Future<void> bootstrap() async {
    if (!isAuthed) {
      initializing = false;
      notifyListeners();
      return;
    }
    try {
      _user = await api.me();
    } catch (_) {
      // Token expired or network unavailable; keep the token so the user
      // stays signed in across brief outages but clear the cached profile.
      _user = null;
    } finally {
      initializing = false;
      notifyListeners();
    }
  }

  Future<void> login(String identifier, String password) async {
    final token = await api.login(identifier: identifier, password: password);
    if (token == null || token.isEmpty) {
      throw ApiException('服务器未返回令牌');
    }
    await _applyToken(token);
    _user = await api.me();
    notifyListeners();
  }

  Future<void> register(
      String username, String email, String password) async {
    final token = await api.register(
        username: username, email: email, password: password);
    if (token == null || token.isEmpty) {
      throw ApiException('注册成功，请手动登录');
    }
    await _applyToken(token);
    _user = await api.me();
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    if (!isAuthed) return;
    try {
      _user = await api.me();
      notifyListeners();
    } catch (_) {
      // Ignore - profile refresh is best effort.
    }
  }

  Future<void> logout() async {
    try {
      await api.logout();
    } catch (_) {
      // Upstream logout is best-effort.
    }
    await _applyToken(null);
    _user = null;
    notifyListeners();
  }

  Future<void> _applyToken(String? token) async {
    _token = token;
    if (token == null) {
      await _prefs.remove('zv_token');
    } else {
      await _prefs.setString('zv_token', token);
    }
  }
}
