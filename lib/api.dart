// Lapisan API — semua panggilan HTTP ke backend lewat sini.
// Token disuntik ke header Authorization: Bearer user-<id>.
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'models.dart';

/// Error yang bawa pesan `detail` dari backend biar bisa ditampilin ke user.
class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => message;
}

class Api {
  String? _token;
  void setToken(String? t) => _token = t;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String base, String path, [Map<String, dynamic>? query]) {
    final q = <String, String>{};
    query?.forEach((k, v) {
      if (v != null && '$v'.isNotEmpty) q[k] = '$v';
    });
    return Uri.parse('$base$path').replace(queryParameters: q.isEmpty ? null : q);
  }

  Never _fail(http.Response r) {
    String msg = 'Terjadi kesalahan (${r.statusCode})';
    try {
      final body = jsonDecode(r.body);
      if (body is Map && body['detail'] != null) msg = body['detail'].toString();
    } catch (_) {}
    throw ApiException(r.statusCode, msg);
  }

  dynamic _decode(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) {
      if (r.body.isEmpty) return null;
      return jsonDecode(r.body);
    }
    _fail(r);
  }

  Future<dynamic> _get(String base, String path, [Map<String, dynamic>? q]) async =>
      _decode(await http.get(_uri(base, path, q), headers: _headers));
  Future<dynamic> _post(String base, String path, [Object? body]) async =>
      _decode(await http.post(_uri(base, path), headers: _headers, body: jsonEncode(body ?? {})));
  Future<dynamic> _put(String base, String path, [Object? body]) async =>
      _decode(await http.put(_uri(base, path), headers: _headers, body: jsonEncode(body ?? {})));
  Future<dynamic> _delete(String base, String path) async =>
      _decode(await http.delete(_uri(base, path), headers: _headers));

  // ── AUTH ────────────────────────────────────────────────────────
  /// Login khusus APK — backend nolak akun tanpa permission product_management.
  Future<({String token, AppUser user})> loginApk(String email, String password) async {
    final j = await _post(Config.authBase, '/apk/login', {'email': email, 'password': password});
    return (token: j['token'].toString(), user: AppUser.fromJson(j['user'] as Map<String, dynamic>));
  }

  Future<AppUser> me() async => AppUser.fromJson(await _get(Config.authBase, '/me') as Map<String, dynamic>);

  Future<void> logout() async {
    try {
      await _post(Config.authBase, '/logout');
    } catch (_) {/* logout tetap lanjut walau server error */}
  }

  // ── MASTER DATA ──────────────────────────────────────────────────
  Future<List<Category>> categories({String? tipe}) async {
    final j = await _get(Config.pmBase, '/categories', {'tipe': tipe}) as List;
    return j.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Warehouse>> warehouses() async {
    final j = await _get(Config.pmBase, '/warehouses') as List;
    return j.map((e) => Warehouse.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Supplier>> suppliers() async {
    final j = await _get(Config.pmBase, '/suppliers') as List;
    return j.map((e) => Supplier.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Toko>> tokos() async {
    final j = await _get(Config.pmBase, '/tokos') as List;
    return j.map((e) => Toko.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── PRODUK ───────────────────────────────────────────────────────
  Future<List<Product>> products({String? search, int? kategoriId, String? status}) async {
    final j = await _get(Config.pmBase, '/products',
        {'search': search, 'kategori_id': kategoriId, 'status': status}) as List;
    return j.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Product> createProduct(Map<String, dynamic> body) async =>
      Product.fromJson(await _post(Config.pmBase, '/products', body) as Map<String, dynamic>);
  Future<Product> updateProduct(int id, Map<String, dynamic> body) async =>
      Product.fromJson(await _put(Config.pmBase, '/products/$id', body) as Map<String, dynamic>);
  Future<void> deleteProduct(int id) async => _delete(Config.pmBase, '/products/$id');

  // ── MUTASI STOK ──────────────────────────────────────────────────
  Future<List<StockMove>> moves({String? tipe, String? search}) async {
    final j = await _get(Config.pmBase, '/moves', {'tipe': tipe, 'search': search}) as List;
    return j.map((e) => StockMove.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<StockMove> createMove(Map<String, dynamic> body) async =>
      StockMove.fromJson(await _post(Config.pmBase, '/moves', body) as Map<String, dynamic>);
  Future<void> deleteMove(int id) async => _delete(Config.pmBase, '/moves/$id');

  // ── OPNAME ───────────────────────────────────────────────────────
  Future<int> opname(Map<String, dynamic> body) async {
    final j = await _post(Config.pmBase, '/opname', body) as Map<String, dynamic>;
    return (j['created'] as num?)?.toInt() ?? 0;
  }
}

// Instance global sederhana (dipakai lewat AuthProvider).
final api = Api();
