// Model data — bentuknya ngikutin JSON dari backend product_management/router.py.
// Semua pakai factory fromJson + helper toJson buat body request.

// Helper parsing aman (backend kadang balikin int/double/null campur).
int _asInt(dynamic v) => v == null ? 0 : (v is int ? v : (v as num).toInt());
double _asDouble(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
String? _asStr(dynamic v) => v?.toString();

class AppUser {
  final int id;
  final String? nama;
  final String email;
  final String? role;
  final bool isAdmin;
  final List<String> permissions;

  AppUser({
    required this.id,
    this.nama,
    required this.email,
    this.role,
    required this.isAdmin,
    required this.permissions,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: _asInt(j['id']),
        nama: _asStr(j['nama']),
        email: j['email']?.toString() ?? '',
        role: _asStr(j['role']),
        isAdmin: j['is_admin'] == true,
        permissions: (j['permissions'] as List?)?.map((e) => e.toString()).toList() ?? [],
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'nama': nama, 'email': email, 'role': role,
        'is_admin': isAdmin, 'permissions': permissions,
      };
}

class Variant {
  String ukuran;
  int stok;
  Variant({this.ukuran = '', this.stok = 0});
  factory Variant.fromJson(Map<String, dynamic> j) =>
      Variant(ukuran: j['ukuran']?.toString() ?? '', stok: _asInt(j['stok']));
  Map<String, dynamic> toJson() => {'ukuran': ukuran, 'stok': stok};
}

class Category {
  final int id;
  final String nama;
  final String tipe; // produk | bahan
  Category({required this.id, required this.nama, required this.tipe});
  factory Category.fromJson(Map<String, dynamic> j) =>
      Category(id: _asInt(j['id']), nama: j['nama']?.toString() ?? '', tipe: j['tipe']?.toString() ?? 'produk');
}

class Warehouse {
  final int id;
  final String nama;
  final String? kode;
  final String? lokasi;
  final String? pic;
  final String? telepon;
  final String? catatan;
  Warehouse({required this.id, required this.nama, this.kode, this.lokasi, this.pic, this.telepon, this.catatan});
  factory Warehouse.fromJson(Map<String, dynamic> j) => Warehouse(
        id: _asInt(j['id']), nama: j['nama']?.toString() ?? '',
        kode: _asStr(j['kode']), lokasi: _asStr(j['lokasi']),
        pic: _asStr(j['pic']), telepon: _asStr(j['telepon']), catatan: _asStr(j['catatan']),
      );
}

class Supplier {
  final int id;
  final String nama;
  final String? kontak;
  final String? telepon;
  final String? email;
  final String? alamat;
  final String? catatan;
  Supplier({required this.id, required this.nama, this.kontak, this.telepon, this.email, this.alamat, this.catatan});
  factory Supplier.fromJson(Map<String, dynamic> j) => Supplier(
        id: _asInt(j['id']), nama: j['nama']?.toString() ?? '',
        kontak: _asStr(j['kontak']), telepon: _asStr(j['telepon']),
        email: _asStr(j['email']), alamat: _asStr(j['alamat']), catatan: _asStr(j['catatan']),
      );
}

class Toko {
  final int id;
  final String namaToko;
  Toko({required this.id, required this.namaToko});
  factory Toko.fromJson(Map<String, dynamic> j) =>
      Toko(id: _asInt(j['id']), namaToko: j['nama_toko']?.toString() ?? j['nama']?.toString() ?? '');
}

class Product {
  final int id;
  String sku;
  String nama;
  int? kategoriId;
  String? kategori;
  String? warna;
  String satuan;
  double hargaBeli;
  double hargaJual;
  int stok;
  int stokMin;
  int? gudangId;
  String? gudang;
  int? tokoId;
  String? toko;
  List<Variant> variants;
  String status;
  String? catatan;

  Product({
    required this.id,
    required this.sku,
    required this.nama,
    this.kategoriId,
    this.kategori,
    this.warna,
    this.satuan = 'pcs',
    this.hargaBeli = 0,
    this.hargaJual = 0,
    this.stok = 0,
    this.stokMin = 0,
    this.gudangId,
    this.gudang,
    this.tokoId,
    this.toko,
    this.variants = const [],
    this.status = 'aktif',
    this.catatan,
  });

  bool get pakaiVarian => variants.isNotEmpty;

  // Status stok: habis / menipis / aman (samain logika sama web).
  String get stockState {
    if (stok <= 0) return 'habis';
    if (stok <= stokMin) return 'menipis';
    return 'aman';
  }

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: _asInt(j['id']),
        sku: j['sku']?.toString() ?? '',
        nama: j['nama']?.toString() ?? '',
        kategoriId: j['kategori_id'] == null ? null : _asInt(j['kategori_id']),
        kategori: _asStr(j['kategori']),
        warna: _asStr(j['warna']),
        satuan: j['satuan']?.toString() ?? 'pcs',
        hargaBeli: _asDouble(j['harga_beli']),
        hargaJual: _asDouble(j['harga_jual']),
        stok: _asInt(j['stok']),
        stokMin: _asInt(j['stok_min']),
        gudangId: j['gudang_id'] == null ? null : _asInt(j['gudang_id']),
        gudang: _asStr(j['gudang']),
        tokoId: j['toko_id'] == null ? null : _asInt(j['toko_id']),
        toko: _asStr(j['toko']),
        variants: (j['variants'] as List?)?.map((e) => Variant.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        status: j['status']?.toString() ?? 'aktif',
        catatan: _asStr(j['catatan']),
      );

  // Body buat POST/PUT (ProductIn di backend).
  Map<String, dynamic> toInput() => {
        'sku': sku.trim().isEmpty ? null : sku.trim(),
        'nama': nama,
        'kategori_id': kategoriId,
        'warna': warna,
        'satuan': satuan,
        'harga_beli': hargaBeli,
        'harga_jual': hargaJual,
        'stok': stok,
        'stok_min': stokMin,
        'gudang_id': gudangId,
        'toko_id': tokoId,
        'variants': variants.map((v) => v.toJson()).toList(),
        'status': status,
        'catatan': catatan,
      };
}

class StockMove {
  final int id;
  final String tanggal; // ISO yyyy-mm-dd
  final String tipe; // masuk | keluar | transfer | opname
  final String? refNo;
  final int? productId;
  final String? item;
  final String? sku;
  final String? warna;
  final String? ukuran;
  final int qty;
  final String? satuan;
  final int? gudangId;
  final String? gudang;
  final int? gudangTujuanId;
  final String? gudangTujuan;
  final String? keterangan;
  final String? petugas;

  StockMove({
    required this.id,
    required this.tanggal,
    required this.tipe,
    this.refNo,
    this.productId,
    this.item,
    this.sku,
    this.warna,
    this.ukuran,
    this.qty = 0,
    this.satuan,
    this.gudangId,
    this.gudang,
    this.gudangTujuanId,
    this.gudangTujuan,
    this.keterangan,
    this.petugas,
  });

  factory StockMove.fromJson(Map<String, dynamic> j) => StockMove(
        id: _asInt(j['id']),
        tanggal: j['tanggal']?.toString() ?? '',
        tipe: j['tipe']?.toString() ?? 'masuk',
        refNo: _asStr(j['ref_no']),
        productId: j['product_id'] == null ? null : _asInt(j['product_id']),
        item: _asStr(j['item']),
        sku: _asStr(j['sku']),
        warna: _asStr(j['warna']),
        ukuran: _asStr(j['ukuran']),
        qty: _asInt(j['qty']),
        satuan: _asStr(j['satuan']),
        gudangId: j['gudang_id'] == null ? null : _asInt(j['gudang_id']),
        gudang: _asStr(j['gudang']),
        gudangTujuanId: j['gudang_tujuan_id'] == null ? null : _asInt(j['gudang_tujuan_id']),
        gudangTujuan: _asStr(j['gudang_tujuan']),
        keterangan: _asStr(j['keterangan']),
        petugas: _asStr(j['petugas']),
      );
}
