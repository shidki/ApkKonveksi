// Model data — ngikutin JSON dari backend produksi konveksi
// (app/product_management/production_router.py). Semua factory fromJson.

int _asInt(dynamic v) => v == null ? 0 : (v is int ? v : (v as num).toInt());
double _asDouble(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
String? _asStr(dynamic v) => v?.toString();
List<String> _asStrList(dynamic v) => (v as List?)?.map((e) => e.toString()).toList() ?? [];

// ─────────────────────────── USER ───────────────────────────
class AppUser {
  final int id;
  final String? nama;
  final String email;
  final String? role;
  final bool isAdmin;
  final List<String> permissions;

  AppUser({required this.id, this.nama, required this.email, this.role, required this.isAdmin, required this.permissions});

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: _asInt(j['id']),
        nama: _asStr(j['nama']),
        email: j['email']?.toString() ?? '',
        role: _asStr(j['role']),
        isAdmin: j['is_admin'] == true,
        permissions: _asStrList(j['permissions']),
      );
}

// ─────────────────────── MASTER / REFERENSI ───────────────────────
class Tukang {
  final int id;
  final String nama;
  final List<String> peran; // potong | jahit | checking
  final String? telepon;
  final String status;
  Tukang({required this.id, required this.nama, this.peran = const [], this.telepon, this.status = 'aktif'});
  factory Tukang.fromJson(Map<String, dynamic> j) => Tukang(
        id: _asInt(j['id']), nama: j['nama']?.toString() ?? '',
        peran: _asStrList(j['peran']), telepon: _asStr(j['telepon']), status: j['status']?.toString() ?? 'aktif',
      );
}

class Warehouse {
  final int id;
  final String nama;
  final String? kode;
  Warehouse({required this.id, required this.nama, this.kode});
  factory Warehouse.fromJson(Map<String, dynamic> j) =>
      Warehouse(id: _asInt(j['id']), nama: j['nama']?.toString() ?? '', kode: _asStr(j['kode']));
}

class Variant {
  final String ukuran;
  final int stok;
  Variant({this.ukuran = '', this.stok = 0});
  factory Variant.fromJson(Map<String, dynamic> j) => Variant(ukuran: j['ukuran']?.toString() ?? '', stok: _asInt(j['stok']));
}

class ProductLite {
  final int id;
  final String sku;
  final String nama;
  final String? warna;
  final String satuan;
  final double hargaJual;
  final int stok;
  final int? gudangId;
  final String? gudang;
  final List<Variant> variants;
  ProductLite({required this.id, required this.sku, required this.nama, this.warna, this.satuan = 'pcs',
    this.hargaJual = 0, this.stok = 0, this.gudangId, this.gudang, this.variants = const []});
  factory ProductLite.fromJson(Map<String, dynamic> j) => ProductLite(
        id: _asInt(j['id']), sku: j['sku']?.toString() ?? '', nama: j['nama']?.toString() ?? '',
        warna: _asStr(j['warna']), satuan: j['satuan']?.toString() ?? 'pcs', hargaJual: _asDouble(j['harga_jual']),
        stok: _asInt(j['stok']), gudangId: j['gudang_id'] == null ? null : _asInt(j['gudang_id']), gudang: _asStr(j['gudang']),
        variants: (j['variants'] as List?)?.map((e) => Variant.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      );
}

class KartuRoll {
  final int tukangId;
  final String? tukang;
  final String warna;
  final int masuk;
  final int keluar;
  final int sisa;
  KartuRoll({required this.tukangId, this.tukang, this.warna = '-', this.masuk = 0, this.keluar = 0, this.sisa = 0});
  factory KartuRoll.fromJson(Map<String, dynamic> j) => KartuRoll(
        tukangId: _asInt(j['tukang_id']), tukang: _asStr(j['tukang']), warna: j['warna']?.toString() ?? '-',
        masuk: _asInt(j['masuk']), keluar: _asInt(j['keluar']), sisa: _asInt(j['sisa']),
      );
}

// ─────────────────────── BAHAN MASUK ───────────────────────
class BahanMasukItem {
  final int? materialId;
  final String? nama;
  final String? warna;
  final int jumlahRoll;
  BahanMasukItem({this.materialId, this.nama, this.warna, this.jumlahRoll = 0});
  factory BahanMasukItem.fromJson(Map<String, dynamic> j) => BahanMasukItem(
        materialId: j['material_id'] == null ? null : _asInt(j['material_id']),
        nama: _asStr(j['nama']), warna: _asStr(j['warna']), jumlahRoll: _asInt(j['jumlah_roll']),
      );
}

class BahanMasuk {
  final int id;
  final String tanggal;
  final int tukangId;
  final String? tukang;
  final String? catatan;
  final List<BahanMasukItem> items;
  final int totalRoll;
  BahanMasuk({required this.id, required this.tanggal, required this.tukangId, this.tukang, this.catatan,
    this.items = const [], this.totalRoll = 0});
  factory BahanMasuk.fromJson(Map<String, dynamic> j) => BahanMasuk(
        id: _asInt(j['id']), tanggal: j['tanggal']?.toString() ?? '', tukangId: _asInt(j['tukang_id']),
        tukang: _asStr(j['tukang']), catatan: _asStr(j['catatan']),
        items: (j['items'] as List?)?.map((e) => BahanMasukItem.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        totalRoll: _asInt(j['total_roll']),
      );
}

// ─────────────────────── POTONGAN ───────────────────────
class RollSize {
  final int id;
  final String ukuran;
  final int pcsPotong;
  final double yard;
  final int qtyJahit;
  // Jumlah yang SUDAH di-acc (lolos QC) kumulatif — dipakai checking untuk hitung
  // sisa yang perlu dicek pada pemeriksaan ulang (revisi/kurang). Dikirim backend
  // via 'acc' / 'qty_acc'; default 0 kalau backend belum mengirim.
  final int accSoFar;
  // Jumlah yang SUDAH ditolak (reject) kumulatif — dipakai memisahkan "revisi"
  // (hasil reject yang dijahit ulang) vs "kurang" (baru dijahit) saat re-check.
  final int rejectSoFar;
  RollSize({this.id = 0, this.ukuran = '', this.pcsPotong = 0, this.yard = 0, this.qtyJahit = 0, this.accSoFar = 0, this.rejectSoFar = 0});
  factory RollSize.fromJson(Map<String, dynamic> j) => RollSize(
        id: _asInt(j['id']), ukuran: j['ukuran']?.toString() ?? '', pcsPotong: _asInt(j['pcs_potong']),
        yard: _asDouble(j['yard']), qtyJahit: _asInt(j['qty_jahit']),
        accSoFar: _asInt(j['acc'] ?? j['qty_acc'] ?? j['acc_so_far']),
        rejectSoFar: _asInt(j['reject_so_far'] ?? j['qty_reject']),
      );
}

class PotonganRoll {
  final int id;
  final int noRoll;
  final String? warna;
  final String status; // available | dialokasi | selesai | dicek
  final int? jahitRequestId;
  final int pcs;
  final List<RollSize> sizes;
  PotonganRoll({required this.id, this.noRoll = 1, this.warna, this.status = 'available', this.jahitRequestId,
    this.pcs = 0, this.sizes = const []});
  factory PotonganRoll.fromJson(Map<String, dynamic> j) => PotonganRoll(
        id: _asInt(j['id']), noRoll: _asInt(j['no_roll']), warna: _asStr(j['warna']),
        status: j['status']?.toString() ?? 'available',
        jahitRequestId: j['jahit_request_id'] == null ? null : _asInt(j['jahit_request_id']),
        pcs: _asInt(j['pcs']),
        sizes: (j['sizes'] as List?)?.map((e) => RollSize.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      );
}

class Potongan {
  final int id;
  final String? no;
  final String tanggal;
  final int tukangId;
  final String? tukang;
  final int? productId;
  final String? produk;
  final String? sku;
  final String status;
  final int totalRoll;
  final int rollAvailable;
  final int totalPcs;
  final int pcsAvailable;
  final int reqPending;
  final int reqDiproses;
  final int reqReject;
  final List<PotonganRoll> rolls;
  Potongan({required this.id, this.no, required this.tanggal, required this.tukangId, this.tukang, this.productId,
    this.produk, this.sku, this.status = 'aktif', this.totalRoll = 0, this.rollAvailable = 0, this.totalPcs = 0,
    this.pcsAvailable = 0, this.reqPending = 0, this.reqDiproses = 0, this.reqReject = 0, this.rolls = const []});
  factory Potongan.fromJson(Map<String, dynamic> j) => Potongan(
        id: _asInt(j['id']), no: _asStr(j['no']), tanggal: j['tanggal']?.toString() ?? '',
        tukangId: _asInt(j['tukang_id']), tukang: _asStr(j['tukang']),
        productId: j['product_id'] == null ? null : _asInt(j['product_id']), produk: _asStr(j['produk']), sku: _asStr(j['sku']),
        status: j['status']?.toString() ?? 'aktif',
        totalRoll: _asInt(j['total_roll']), rollAvailable: _asInt(j['roll_available']),
        totalPcs: _asInt(j['total_pcs']), pcsAvailable: _asInt(j['pcs_available']),
        reqPending: _asInt(j['req_pending']), reqDiproses: _asInt(j['req_diproses']), reqReject: _asInt(j['req_reject']),
        rolls: (j['rolls'] as List?)?.map((e) => PotonganRoll.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      );
}

// ─────────────────────── JAHIT ───────────────────────
const jahitStatusLabel = {
  'pending': 'Menunggu ACC', 'acc': 'Dikerjakan', 'reject': 'Ditolak',
  'selesai': 'Selesai — ke Checking', 'rework': 'Perbaikan', 'done': 'Tuntas',
};

class ReworkItem {
  final int? rollNo;
  final String? warna;
  final String? ukuran;
  final int qty;
  ReworkItem({this.rollNo, this.warna, this.ukuran, this.qty = 0});
  factory ReworkItem.fromJson(Map<String, dynamic> j) => ReworkItem(
        rollNo: j['roll_no'] == null ? null : _asInt(j['roll_no']), warna: _asStr(j['warna']),
        ukuran: _asStr(j['ukuran']), qty: _asInt(j['qty']));
}

class JahitRequest {
  final int id;
  final int potonganId;
  final String? potonganNo;
  final int? productId;
  final String? produk;
  final int tukangId;
  final String? penjahit;
  final String tanggal;
  final String status;
  final String? catatan;
  final String? alasanReject;
  final List<PotonganRoll> rolls;
  final int nRoll;
  final int pcs;
  final List<ReworkItem> rework;
  final String? cutter;
  JahitRequest({required this.id, required this.potonganId, this.potonganNo, this.productId, this.produk,
    required this.tukangId, this.penjahit, required this.tanggal, this.status = 'pending', this.catatan,
    this.alasanReject, this.rolls = const [], this.nRoll = 0, this.pcs = 0, this.rework = const [], this.cutter});
  factory JahitRequest.fromJson(Map<String, dynamic> j) => JahitRequest(
        id: _asInt(j['id']), potonganId: _asInt(j['potongan_id']), potonganNo: _asStr(j['potongan_no']),
        productId: j['product_id'] == null ? null : _asInt(j['product_id']), produk: _asStr(j['produk']),
        tukangId: _asInt(j['tukang_id']), penjahit: _asStr(j['penjahit']), tanggal: j['tanggal']?.toString() ?? '',
        status: j['status']?.toString() ?? 'pending', catatan: _asStr(j['catatan']), alasanReject: _asStr(j['alasan_reject']),
        rolls: (j['rolls'] as List?)?.map((e) => PotonganRoll.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        nRoll: _asInt(j['n_roll']), pcs: _asInt(j['pcs']),
        rework: (j['rework'] as List?)?.map((e) => ReworkItem.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        cutter: _asStr(j['cutter']),
      );
}

// ─────────────────────── CHECKING ───────────────────────
class CheckingHistoryRow {
  final int id;
  final String? no;
  final String tanggal;
  final String? checker;
  final int jahitRequestId;
  final String? penjahit;
  final int acc;
  final int reject;
  CheckingHistoryRow({required this.id, this.no, required this.tanggal, this.checker, required this.jahitRequestId,
    this.penjahit, this.acc = 0, this.reject = 0});
  factory CheckingHistoryRow.fromJson(Map<String, dynamic> j) => CheckingHistoryRow(
        id: _asInt(j['id']), no: _asStr(j['no']), tanggal: j['tanggal']?.toString() ?? '', checker: _asStr(j['checker']),
        jahitRequestId: _asInt(j['jahit_request_id']), penjahit: _asStr(j['penjahit']),
        acc: _asInt(j['acc']), reject: _asInt(j['reject']),
      );
}

class CheckingItemDetail {
  final int id;
  final int? rollNo;
  final String? warna;
  final String? ukuran;
  final int dipotong;
  final int dijahit;
  final int kurang;
  final int acc;
  final int reject;
  final String? gudang;
  CheckingItemDetail({required this.id, this.rollNo, this.warna, this.ukuran, this.dipotong = 0, this.dijahit = 0,
    this.kurang = 0, this.acc = 0, this.reject = 0, this.gudang});
  factory CheckingItemDetail.fromJson(Map<String, dynamic> j) => CheckingItemDetail(
        id: _asInt(j['id']), rollNo: j['roll_no'] == null ? null : _asInt(j['roll_no']), warna: _asStr(j['warna']),
        ukuran: _asStr(j['ukuran']), dipotong: _asInt(j['dipotong']), dijahit: _asInt(j['dijahit']),
        kurang: _asInt(j['kurang']), acc: _asInt(j['acc']), reject: _asInt(j['reject']), gudang: _asStr(j['gudang']),
      );
}

class CheckingDetail {
  final int id;
  final String? no;
  final String tanggal;
  final String? checker;
  final String? penjahit;
  final String? potonganNo;
  final String? produk;
  final String? catatan;
  final int totalDipotong, totalDijahit, totalKurang, totalAcc, totalReject;
  final List<CheckingItemDetail> items;
  CheckingDetail({required this.id, this.no, required this.tanggal, this.checker, this.penjahit, this.potonganNo,
    this.produk, this.catatan, this.totalDipotong = 0, this.totalDijahit = 0, this.totalKurang = 0,
    this.totalAcc = 0, this.totalReject = 0, this.items = const []});
  factory CheckingDetail.fromJson(Map<String, dynamic> j) => CheckingDetail(
        id: _asInt(j['id']), no: _asStr(j['no']), tanggal: j['tanggal']?.toString() ?? '', checker: _asStr(j['checker']),
        penjahit: _asStr(j['penjahit']), potonganNo: _asStr(j['potongan_no']), produk: _asStr(j['produk']),
        catatan: _asStr(j['catatan']),
        totalDipotong: _asInt(j['total_dipotong']), totalDijahit: _asInt(j['total_dijahit']),
        totalKurang: _asInt(j['total_kurang']), totalAcc: _asInt(j['total_acc']), totalReject: _asInt(j['total_reject']),
        items: (j['items'] as List?)?.map((e) => CheckingItemDetail.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      );
}

// ─────────────────────── MONITORING & PRESTASI ───────────────────────
class WipDetailRow {
  final String? label, produk, warna, ukuran, gudang;
  final int pcs;
  WipDetailRow({this.label, this.produk, this.warna, this.ukuran, this.gudang, this.pcs = 0});
  factory WipDetailRow.fromJson(Map<String, dynamic> j) => WipDetailRow(
        label: _asStr(j['label']), produk: _asStr(j['produk']), warna: _asStr(j['warna']),
        ukuran: _asStr(j['ukuran']), gudang: _asStr(j['gudang']), pcs: _asInt(j['pcs']));
}

class PerCutterRow {
  final String? tukang, produk, warna, ukuran;
  final int nPotongan, totalPcs, availablePcs;
  PerCutterRow({this.tukang, this.produk, this.warna, this.ukuran, this.nPotongan = 0, this.totalPcs = 0, this.availablePcs = 0});
  factory PerCutterRow.fromJson(Map<String, dynamic> j) => PerCutterRow(
        tukang: _asStr(j['tukang']), produk: _asStr(j['produk']), warna: _asStr(j['warna']), ukuran: _asStr(j['ukuran']),
        nPotongan: _asInt(j['n_potongan']), totalPcs: _asInt(j['total_pcs']), availablePcs: _asInt(j['available_pcs']));
}

// Satu kejadian penolakan (1 sesi checking yang menghasilkan reject).
class RiwayatTolak {
  final String tanggal;
  final String? no;
  final int jumlah;
  RiwayatTolak({this.tanggal = '', this.no, this.jumlah = 0});
  factory RiwayatTolak.fromJson(Map<String, dynamic> j) =>
      RiwayatTolak(tanggal: j['tanggal']?.toString() ?? '', no: _asStr(j['no']), jumlah: _asInt(j['jumlah']));
}

// Rekap penolakan per request jahit: status ditolak sekarang + histori tiap ronde.
class PenolakanRow {
  final int jahitRequestId;
  final String? penjahit, potonganNo, produk, status;
  final int ditolakSekarang, totalDitolak, nDitolak;
  final List<RiwayatTolak> riwayat;
  PenolakanRow({this.jahitRequestId = 0, this.penjahit, this.potonganNo, this.produk, this.status,
    this.ditolakSekarang = 0, this.totalDitolak = 0, this.nDitolak = 0, this.riwayat = const []});
  factory PenolakanRow.fromJson(Map<String, dynamic> j) => PenolakanRow(
        jahitRequestId: _asInt(j['jahit_request_id']), penjahit: _asStr(j['penjahit']),
        potonganNo: _asStr(j['potongan_no']), produk: _asStr(j['produk']), status: _asStr(j['status']),
        ditolakSekarang: _asInt(j['ditolak_sekarang']), totalDitolak: _asInt(j['total_ditolak']),
        nDitolak: _asInt(j['n_ditolak']),
        riwayat: (j['riwayat'] as List?)?.map((e) => RiwayatTolak.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      );
}

class Monitoring {
  final int nPotongan;
  final Map<String, int> wip; // stok_mentah, dijahit, nunggu_cek, rework, kurang, selesai
  final Map<String, List<WipDetailRow>> wipDetail;
  final List<PerCutterRow> perCutter;
  final List<JahitRequest> aktif;
  final List<PenolakanRow> penolakan;
  Monitoring({this.nPotongan = 0, this.wip = const {}, this.wipDetail = const {}, this.perCutter = const [], this.aktif = const [], this.penolakan = const []});
  factory Monitoring.fromJson(Map<String, dynamic> j) {
    final wd = <String, List<WipDetailRow>>{};
    (j['wip_detail'] as Map?)?.forEach((k, v) =>
        wd['$k'] = (v as List?)?.map((e) => WipDetailRow.fromJson(e as Map<String, dynamic>)).toList() ?? []);
    return Monitoring(
      nPotongan: _asInt(j['n_potongan']),
      wip: (j['wip'] as Map?)?.map((k, v) => MapEntry('$k', _asInt(v))) ?? {},
      wipDetail: wd,
      perCutter: (j['per_cutter'] as List?)?.map((e) => PerCutterRow.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      aktif: (j['aktif'] as List?)?.map((e) => JahitRequest.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      penolakan: (j['penolakan'] as List?)?.map((e) => PenolakanRow.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    );
  }
}

class PrestasiPenjahit {
  final int tukangId;
  final String? penjahit;
  final int acc, reject, kurang, total, target, nRequest;
  final double persenAcc;
  PrestasiPenjahit({required this.tukangId, this.penjahit, this.acc = 0, this.reject = 0, this.kurang = 0,
    this.total = 0, this.target = 0, this.nRequest = 0, this.persenAcc = 0});
  factory PrestasiPenjahit.fromJson(Map<String, dynamic> j) => PrestasiPenjahit(
        tukangId: _asInt(j['tukang_id']), penjahit: _asStr(j['penjahit']), acc: _asInt(j['acc']), reject: _asInt(j['reject']),
        kurang: _asInt(j['kurang']), total: _asInt(j['total']), target: _asInt(j['target']), nRequest: _asInt(j['n_request']),
        persenAcc: _asDouble(j['persen_acc']));
}

class PrestasiCutter {
  final String? tukang, produk, warna, ukuran;
  final int nPotongan, totalPcs;
  PrestasiCutter({this.tukang, this.produk, this.warna, this.ukuran, this.nPotongan = 0, this.totalPcs = 0});
  factory PrestasiCutter.fromJson(Map<String, dynamic> j) => PrestasiCutter(
        tukang: _asStr(j['tukang']), produk: _asStr(j['produk']), warna: _asStr(j['warna']), ukuran: _asStr(j['ukuran']),
        nPotongan: _asInt(j['n_potongan']), totalPcs: _asInt(j['total_pcs']));
}

class PrestasiChecker {
  final String? checker;
  final int nSesi, acc, reject;
  PrestasiChecker({this.checker, this.nSesi = 0, this.acc = 0, this.reject = 0});
  factory PrestasiChecker.fromJson(Map<String, dynamic> j) => PrestasiChecker(
        checker: _asStr(j['checker']), nSesi: _asInt(j['n_sesi']), acc: _asInt(j['acc']), reject: _asInt(j['reject']));
}

class Prestasi {
  final String periode;
  final List<PrestasiPenjahit> rows;
  final List<PrestasiCutter> cutter;
  final List<PrestasiChecker> checker;
  Prestasi({this.periode = '', this.rows = const [], this.cutter = const [], this.checker = const []});
  factory Prestasi.fromJson(Map<String, dynamic> j) => Prestasi(
        periode: j['periode']?.toString() ?? '',
        rows: (j['rows'] as List?)?.map((e) => PrestasiPenjahit.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        cutter: (j['cutter'] as List?)?.map((e) => PrestasiCutter.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        checker: (j['checker'] as List?)?.map((e) => PrestasiChecker.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      );
}

// ─────────────────────── NOTIFIKASI ───────────────────────
class Notif {
  final int id;
  final String judul;
  final String? pesan;
  final String? tipe;
  final String? link;
  final int? refId;
  final bool dibaca;
  final String createdAt;
  Notif({required this.id, required this.judul, this.pesan, this.tipe, this.link, this.refId,
    this.dibaca = false, this.createdAt = ''});
  factory Notif.fromJson(Map<String, dynamic> j) => Notif(
        id: _asInt(j['id']), judul: j['judul']?.toString() ?? '', pesan: _asStr(j['pesan']),
        tipe: _asStr(j['tipe']), link: _asStr(j['link']),
        refId: j['ref_id'] == null ? null : _asInt(j['ref_id']),
        dibaca: j['dibaca'] == true, createdAt: j['created_at']?.toString() ?? '',
      );
}

class NotifResp {
  final int unread;
  final List<Notif> items;
  NotifResp({this.unread = 0, this.items = const []});
  factory NotifResp.fromJson(Map<String, dynamic> j) => NotifResp(
        unread: _asInt(j['unread']),
        items: (j['items'] as List?)?.map((e) => Notif.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      );
}
