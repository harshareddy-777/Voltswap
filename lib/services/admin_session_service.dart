import 'package:shared_preferences/shared_preferences.dart';

class AdminSessionService {
  static const _adminLoggedInKey = 'admin_logged_in';

  Future<void> setAdminLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_adminLoggedInKey, value);
  }

  Future<bool> isAdminLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_adminLoggedInKey) ?? false;
  }
}
