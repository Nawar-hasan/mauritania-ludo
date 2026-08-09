import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionStore {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _localeKey = 'locale';
  static const _onboardingKey = 'onboarding_completed';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<String?> get accessToken => _secure.read(key: _accessKey);
  Future<String?> get refreshToken => _secure.read(key: _refreshKey);

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _secure.write(key: _accessKey, value: accessToken);
    await _secure.write(key: _refreshKey, value: refreshToken);
  }

  Future<void> clearTokens() async {
    await _secure.delete(key: _accessKey);
    await _secure.delete(key: _refreshKey);
  }

  Future<String> getLocale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_localeKey) ?? 'ar';
  }

  Future<void> setLocale(String locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale);
  }

  Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
  }
}
