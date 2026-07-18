// State autentikasi — simpan token & user, persist ke device (shared_preferences)
// biar nggak perlu login ulang tiap buka app.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'models.dart';
import 'services/alarm_notif.dart';

class AuthProvider extends ChangeNotifier {
  static const _kToken = 'auth_token';

  AppUser? _user;
  String? _token;
  bool _booting = true; // lagi cek token tersimpan saat start

  AppUser? get user => _user;
  bool get isLoggedIn => _token != null && _user != null;
  bool get booting => _booting;

  /// Dipanggil sekali di startup: pulihkan sesi dari token tersimpan.
  Future<void> boot() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString(_kToken);
    if (t != null) {
      api.setToken(t);
      try {
        _user = await api.me(); // validasi token masih hidup
        _token = t;
      } catch (_) {
        await _clear(); // token basi → paksa login lagi
      }
    }
    _booting = false;
    notifyListeners();
  }

  /// Login lewat endpoint khusus APK. Lempar ApiException kalau gagal/ditolak.
  Future<void> login(String email, String password) async {
    final res = await api.loginApk(email.trim(), password);
    _token = res.token;
    _user = res.user;
    api.setToken(_token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, _token!);
    try { await NotifAlarm.start(); } catch (_) {} // mulai pantau notif alarm di background
    notifyListeners();
  }

  Future<void> logout() async {
    try { await NotifAlarm.stop(); } catch (_) {} // matiin service sebelum token dihapus
    await api.logout();
    await _clear();
    notifyListeners();
  }

  Future<void> _clear() async {
    _user = null;
    _token = null;
    api.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
  }

  bool get canManageStock =>
      _user != null && hasModuleAccess("pm");

  /// Cek akses APA PUN ke modul (mis. "pm") — admin, umbrella lama, atau key
  /// granular ber-prefix modul. Samain logika dengan backend has_module_access.
  bool hasModuleAccess(String prefix) {
    final u = _user;
    if (u == null) return false;
    if (u.isAdmin || u.permissions.contains("*")) return true;
    const umbrella = {"pm": "product_management", "acc": "accounting"};
    final umb = umbrella[prefix];
    if (umb != null && u.permissions.contains(umb)) return true;
    return u.permissions.any((p) => p.startsWith("$prefix."));
  }

  /// Cek AKSI granular (mis. "pm.produk.create"). admin / key persis / umbrella.
  bool can(String key) {
    final u = _user;
    if (u == null) return false;
    if (u.isAdmin || u.permissions.contains("*")) return true;
    if (u.permissions.contains(key)) return true;
    const umbrella = {"pm": "product_management", "acc": "accounting"};
    final umb = umbrella[key.split(".").first];
    return umb != null && u.permissions.contains(umb);
  }
}
