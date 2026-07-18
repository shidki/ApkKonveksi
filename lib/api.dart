// Lapisan API — semua panggilan HTTP ke backend produksi konveksi.
// Token disuntik ke header Authorization: Bearer user-<id>. Scoping data
// (tukang cuma lihat miliknya) ditangani backend berdasarkan token ini.
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'models.dart';

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
  Future<dynamic> _delete(String base, String path) async =>
      _decode(await http.delete(_uri(base, path), headers: _headers));

  String get _b => Config.pmBase;

  // ── AUTH ──
  Future<({String token, AppUser user})> loginApk(String email, String password) async {
    final j = await _post(Config.authBase, '/apk/login', {'email': email, 'password': password});
    return (token: j['token'].toString(), user: AppUser.fromJson(j['user'] as Map<String, dynamic>));
  }

  Future<AppUser> me() async => AppUser.fromJson(await _get(Config.authBase, '/me') as Map<String, dynamic>);
  Future<void> logout() async {
    try { await _post(Config.authBase, '/logout'); } catch (_) {}
  }

  // ── REFERENSI ──
  Future<List<Tukang>> tukang({String? peran}) async {
    final j = await _get(_b, '/tukang', {'peran': peran}) as List;
    return j.map((e) => Tukang.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Warehouse>> warehouses() async {
    final j = await _get(_b, '/warehouses') as List;
    return j.map((e) => Warehouse.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ProductLite>> products({String? search}) async {
    final j = await _get(_b, '/products', {'search': search}) as List;
    return j.map((e) => ProductLite.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── BAHAN MASUK + KARTU ROLL (tukang potong) ──
  Future<List<BahanMasuk>> bahanMasuk() async {
    final j = await _get(_b, '/bahan-masuk') as List;
    return j.map((e) => BahanMasuk.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> createBahanMasuk(Map<String, dynamic> body) async => _post(_b, '/bahan-masuk', body);
  Future<void> deleteBahanMasuk(int id) async => _delete(_b, '/bahan-masuk/$id');

  Future<List<KartuRoll>> kartuRoll({int? tukangId}) async {
    final j = await _get(_b, '/kartu-roll', {'tukang_id': tukangId}) as List;
    return j.map((e) => KartuRoll.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── POTONGAN (tukang potong) ──
  Future<List<Potongan>> potongan({int? tukangId, String? status}) async {
    final j = await _get(_b, '/potongan', {'tukang_id': tukangId, 'status': status}) as List;
    return j.map((e) => Potongan.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Potongan> potonganDetail(int id) async =>
      Potongan.fromJson(await _get(_b, '/potongan/$id') as Map<String, dynamic>);
  Future<Potongan> createPotongan(Map<String, dynamic> body) async =>
      Potongan.fromJson(await _post(_b, '/potongan', body) as Map<String, dynamic>);
  Future<void> deletePotongan(int id) async => _delete(_b, '/potongan/$id');

  // ── JAHIT ──
  Future<List<Potongan>> jahitStokMentah() async {
    final j = await _get(_b, '/jahit/stok-mentah') as List;
    return j.map((e) => Potongan.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Potongan> jahitStokMentahDetail(int id) async =>
      Potongan.fromJson(await _get(_b, '/jahit/stok-mentah/$id') as Map<String, dynamic>);

  Future<List<JahitRequest>> jahitRequests({int? potonganId, int? tukangId, String? status}) async {
    final j = await _get(_b, '/jahit/requests',
        {'potongan_id': potonganId, 'tukang_id': tukangId, 'status': status}) as List;
    return j.map((e) => JahitRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<JahitRequest> jahitRequestDetail(int id) async =>
      JahitRequest.fromJson(await _get(_b, '/jahit/requests/$id') as Map<String, dynamic>);
  Future<void> createJahitRequest(Map<String, dynamic> body) async => _post(_b, '/jahit/requests', body);
  Future<void> accJahit(int id, List<int> rollIds) async => _post(_b, '/jahit/requests/$id/acc', {'roll_ids': rollIds});
  Future<void> rejectJahit(int id, String? alasan) async => _post(_b, '/jahit/requests/$id/reject', {'alasan': alasan});
  Future<void> jahitProgress(int id, List<Map<String, dynamic>> lines, bool selesai) async =>
      _post(_b, '/jahit/requests/$id/progress', {'lines': lines, 'selesai': selesai});
  Future<void> batalSelesaiJahit(int id) async => _post(_b, '/jahit/requests/$id/batal-selesai', {});

  // ── CHECKING ──
  Future<List<JahitRequest>> checkingAntrian() async {
    final j = await _get(_b, '/checking/antrian') as List;
    return j.map((e) => JahitRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<CheckingHistoryRow>> checkingHistory() async {
    final j = await _get(_b, '/checking/history') as List;
    return j.map((e) => CheckingHistoryRow.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<CheckingDetail> checkingDetail(int id) async =>
      CheckingDetail.fromJson(await _get(_b, '/checking/$id') as Map<String, dynamic>);
  Future<void> createChecking(Map<String, dynamic> body) async => _post(_b, '/checking', body);
  Future<void> deleteChecking(int id) async => _delete(_b, '/checking/$id');

  // ── MONITORING & PRESTASI ──
  Future<Monitoring> monitoring() async =>
      Monitoring.fromJson(await _get(_b, '/monitoring') as Map<String, dynamic>);
  Future<Prestasi> prestasi({int? tahun, int? bulan}) async =>
      Prestasi.fromJson(await _get(_b, '/prestasi', {'tahun': tahun, 'bulan': bulan}) as Map<String, dynamic>);

  // ── NOTIFIKASI ──
  Future<NotifResp> notif() async => NotifResp.fromJson(await _get(_b, '/notif') as Map<String, dynamic>);
  Future<int> notifUnread() async {
    final j = await _get(_b, '/notif/unread-count') as Map<String, dynamic>;
    return _asIntSafe(j['unread']);
  }
  Future<void> notifRead(int id) async => _post(_b, '/notif/$id/read', {});
  Future<void> notifReadAll() async => _post(_b, '/notif/read-all', {});
}

int _asIntSafe(dynamic v) => v == null ? 0 : (v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0));

final api = Api();
