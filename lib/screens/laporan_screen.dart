// Laporan Stok = daftar semua produk dengan filter gudang, kategori, toko
// & rentang tanggal, ringkasan total unit & nilai inventori, plus:
//   • Grafik bar masuk vs keluar per toko — TAP bar buat lihat rincian produk.
//   • Grafik opname minggu ini: stok sistem, hasil opname, selisih.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api.dart';
import '../models.dart';
import '../ui.dart';
import '../config.dart';

class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key});
  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> {
  List<Product> _all = [];
  List<Warehouse> _warehouses = [];
  List<Category> _categories = [];
  List<Toko> _tokos = [];
  List<StockMove> _moves = [];
  int? _gudangId;
  int? _kategoriId;
  int? _tokoId;
  DateTimeRange? _range;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        api.products(),
        api.warehouses(),
        api.categories(tipe: 'produk'),
        api.tokos(),
        api.moves(),
      ]);
      setState(() {
        _all = results[0] as List<Product>;
        _warehouses = results[1] as List<Warehouse>;
        _categories = results[2] as List<Category>;
        _tokos = results[3] as List<Toko>;
        _moves = results[4] as List<StockMove>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  List<Product> get _filtered => _all.where((p) {
        if (_gudangId != null && p.gudangId != _gudangId) return false;
        if (_kategoriId != null && p.kategoriId != _kategoriId) return false;
        if (_tokoId != null && p.tokoId != _tokoId) return false;
        return true;
      }).toList();

  /// Mutasi yang lolos filter gudang, toko & rentang tanggal (buat grafik).
  List<StockMove> get _movesF {
    final byId = {for (final p in _all) p.id: p};
    return _moves.where((m) {
      if (_gudangId != null && m.gudangId != _gudangId) return false;
      if (_tokoId != null) {
        final p = m.productId == null ? null : byId[m.productId];
        if (p?.tokoId != _tokoId) return false;
      }
      if (_range != null) {
        final d = DateTime.tryParse(m.tanggal);
        if (d != null) {
          final dd = DateUtils.dateOnly(d);
          if (dd.isBefore(DateUtils.dateOnly(_range!.start)) ||
              dd.isAfter(DateUtils.dateOnly(_range!.end))) {
            return false;
          }
        }
      }
      return true;
    }).toList();
  }

  /// Data grafik 1: total masuk & keluar per toko.
  List<({String toko, int masuk, int keluar})> get _chartData {
    final byId = {for (final p in _all) p.id: p};
    final map = <String, List<int>>{}; // nama toko → [masuk, keluar]
    for (final m in _movesF) {
      final p = m.productId == null ? null : byId[m.productId];
      final toko = (p?.toko?.trim().isNotEmpty ?? false) ? p!.toko! : 'Tanpa Toko';
      final e = map.putIfAbsent(toko, () => [0, 0]);
      if (m.tipe == 'masuk') {
        e[0] += m.qty;
      } else if (m.tipe == 'keluar') {
        e[1] += m.qty;
      }
    }
    final list = map.entries
        .map((e) => (toko: e.key, masuk: e.value[0], keluar: e.value[1]))
        .where((d) => d.masuk > 0 || d.keluar > 0)
        .toList()
      ..sort((a, b) => (b.masuk + b.keluar).compareTo(a.masuk + a.keluar));
    return list;
  }

  /// Data grafik opname PER TOKO, ikut filter gudang/toko/tanggal.
  /// Kalau rentang tanggal tak aktif → semua opname dihitung.
  /// Tiap toko: stok sistem sekarang, hasil opname (stok produk yg diopname),
  /// dan selisih (net penyesuaian) dalam rentang.
  List<({String toko, int stok, int hasil, int selisih})> get _opnameData {
    final byId = {for (final p in _all) p.id: p};
    final selisihMap = <String, int>{};
    final opnamedIds = <String, Set<int>>{};
    for (final m in _moves) {
      if (m.tipe != 'opname') continue;
      if (_gudangId != null && m.gudangId != _gudangId) continue;
      final p = m.productId == null ? null : byId[m.productId];
      if (_tokoId != null && p?.tokoId != _tokoId) continue;
      if (_range != null) {
        final d = DateTime.tryParse(m.tanggal);
        if (d != null) {
          final dd = DateUtils.dateOnly(d);
          if (dd.isBefore(DateUtils.dateOnly(_range!.start)) ||
              dd.isAfter(DateUtils.dateOnly(_range!.end))) {
            continue;
          }
        }
      }
      final toko = (p?.toko?.trim().isNotEmpty ?? false) ? p!.toko! : 'Tanpa Toko';
      selisihMap[toko] = (selisihMap[toko] ?? 0) + m.qty;
      if (m.productId != null) (opnamedIds[toko] ??= <int>{}).add(m.productId!);
    }
    // stok sistem sekarang per toko (produk terfilter gudang/kategori/toko)
    final stokMap = <String, int>{};
    for (final p in _filtered) {
      final toko = (p.toko?.trim().isNotEmpty ?? false) ? p.toko! : 'Tanpa Toko';
      stokMap[toko] = (stokMap[toko] ?? 0) + p.stok;
    }
    final list = selisihMap.keys.map((t) {
      final hasil = (opnamedIds[t] ?? {}).fold<int>(0, (s, id) => s + (byId[id]?.stok ?? 0));
      return (toko: t, stok: stokMap[t] ?? 0, hasil: hasil, selisih: selisihMap[t] ?? 0);
    }).toList()
      ..sort((a, b) => b.selisih.abs().compareTo(a.selisih.abs()));
    return list;
  }

  /// Rincian produk masuk/keluar untuk satu toko — muncul saat bar di-tap.
  void _showTokoDetail(String toko) {
    final byId = {for (final p in _all) p.id: p};
    final masukMap = <String, int>{};
    final keluarMap = <String, int>{};
    for (final m in _movesF) {
      final p = m.productId == null ? null : byId[m.productId];
      final t = (p?.toko?.trim().isNotEmpty ?? false) ? p!.toko! : 'Tanpa Toko';
      if (t != toko) continue;
      final warna = (m.warna?.isNotEmpty ?? false)
          ? m.warna!
          : ((p?.warna?.isNotEmpty ?? false) ? p!.warna! : '');
      final nama =
          '${namaPendek(m.item ?? p?.nama ?? m.sku ?? '-')}${warna.isNotEmpty ? ' · $warna' : ''}';
      if (m.tipe == 'masuk') {
        masukMap[nama] = (masukMap[nama] ?? 0) + m.qty;
      } else if (m.tipe == 'keluar') {
        keluarMap[nama] = (keluarMap[nama] ?? 0) + m.qty;
      }
    }
    final masuk = masukMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final keluar = keluarMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final totalMasuk = masuk.fold<int>(0, (s, e) => s + e.value);
    final totalKeluar = keluar.fold<int>(0, (s, e) => s + e.value);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Center(
              child: Container(
                width: 42, height: 5,
                decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                    color: AppTheme.info.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.storefront_rounded, color: AppTheme.info, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(toko,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink)),
              ),
            ]),
            const SizedBox(height: 16),
            _detailSection('Masuk (${angka(totalMasuk)})', Icons.south_west_rounded, AppTheme.success, masuk),
            const SizedBox(height: 14),
            _detailSection('Keluar (${angka(totalKeluar)})', Icons.north_east_rounded, AppTheme.danger, keluar),
          ],
        ),
      ),
    );
  }

  Widget _detailSection(String title, IconData icon, Color color, List<MapEntry<String, int>> items) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(title, icon: icon, color: color),
      const SizedBox(height: 8),
      if (items.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppTheme.soft, borderRadius: BorderRadius.circular(12)),
          child: const Text('Tidak ada data.', style: TextStyle(color: AppTheme.muted, fontSize: 13)),
        )
      else
        Container(
          decoration: BoxDecoration(
              color: AppTheme.soft, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  Expanded(
                    child: Text(items[i].key,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.ink)),
                  ),
                  Text(angka(items[i].value),
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: color)),
                ]),
              ),
            ],
          ]),
        ),
    ]);
  }

  /// Saldo stok tepat SEBELUM sebuah mutasi (dari seluruh riwayat produk itu).
  /// Dipakai buat rekonstruksi "stok sistem sebelum opname".
  int _saldoSebelum(StockMove target) {
    final same = _moves.where((m) => m.productId == target.productId).toList()
      ..sort((a, b) {
        final c = a.tanggal.compareTo(b.tanggal);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    int saldo = 0;
    for (final m in same) {
      if (m.id == target.id) break; // berhenti tepat sebelum target
      if (m.tipe == 'masuk') {
        saldo += m.qty;
      } else if (m.tipe == 'keluar' || m.tipe == 'transfer') {
        saldo -= m.qty;
      } else {
        saldo += m.qty; // opname sebelumnya
      }
    }
    return saldo;
  }

  /// Rincian opname satu toko (dalam rentang tanggal) — muncul saat bar di-tap.
  /// Per produk: stok sistem (sebelum) → hasil opname (sesudah) + selisih.
  void _showOpnameDetail(String toko) {
    final byId = {for (final p in _all) p.id: p};
    final rows = <({String nama, String tanggal, int sebelum, int sesudah, int selisih})>[];
    for (final m in _moves) {
      if (m.tipe != 'opname') continue;
      if (_gudangId != null && m.gudangId != _gudangId) continue;
      final p = m.productId == null ? null : byId[m.productId];
      if (_tokoId != null && p?.tokoId != _tokoId) continue;
      final t = (p?.toko?.trim().isNotEmpty ?? false) ? p!.toko! : 'Tanpa Toko';
      if (t != toko) continue;
      if (_range != null) {
        final d = DateTime.tryParse(m.tanggal);
        if (d != null) {
          final dd = DateUtils.dateOnly(d);
          if (dd.isBefore(DateUtils.dateOnly(_range!.start)) ||
              dd.isAfter(DateUtils.dateOnly(_range!.end))) {
            continue;
          }
        }
      }
      final warna = (m.warna?.isNotEmpty ?? false)
          ? m.warna!
          : ((p?.warna?.isNotEmpty ?? false) ? p!.warna! : '');
      final ukuran = (m.ukuran?.isNotEmpty ?? false) ? ' · uk ${m.ukuran}' : '';
      final nama =
          '${namaPendek(m.item ?? p?.nama ?? m.sku ?? '-')}${warna.isNotEmpty ? ' · $warna' : ''}$ukuran';
      final sebelum = _saldoSebelum(m);
      rows.add((nama: nama, tanggal: tanggalID(m.tanggal), sebelum: sebelum, sesudah: sebelum + m.qty, selisih: m.qty));
    }
    rows.sort((a, b) => b.selisih.abs().compareTo(a.selisih.abs()));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        maxChildSize: 0.9,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Center(
              child: Container(
                width: 42, height: 5,
                decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.fact_check_rounded, color: AppTheme.warning, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(toko,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                  Text('${rows.length} penyesuaian opname', style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            if (rows.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppTheme.soft, borderRadius: BorderRadius.circular(14)),
                child: const Text('Tidak ada opname untuk rentang ini.',
                    style: TextStyle(color: AppTheme.muted, fontSize: 13)),
              )
            else
              for (final r in rows) ...[
                _opnameDetailRow(r),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }

  Widget _opnameDetailRow(({String nama, String tanggal, int sebelum, int sesudah, int selisih}) r) {
    final naik = r.selisih > 0;
    final c = r.selisih == 0 ? AppTheme.muted : (naik ? AppTheme.success : AppTheme.danger);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.soft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(r.nama,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.ink)),
          ),
          Text(r.tanggal, style: const TextStyle(fontSize: 11, color: AppTheme.faint)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _pill('Stok Sistem', angka(r.sebelum), AppTheme.info),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward_rounded, size: 16, color: AppTheme.faint),
          ),
          _pill('Hasil Opname', angka(r.sesudah), AppTheme.warning),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(r.selisih == 0 ? Icons.remove_rounded : (naik ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded),
                  size: 13, color: c),
              const SizedBox(width: 3),
              Text('${naik ? '+' : ''}${angka(r.selisih)}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c)),
            ]),
          ),
        ]),
      ]),
    );
  }

  Widget _pill(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 10.5, color: AppTheme.muted)),
          const SizedBox(height: 1),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const ModernHeader(title: 'Laporan', subtitle: 'Ringkasan, grafik & nilai inventori'),
      Expanded(child: _body()),
    ]);
  }

  Widget _body() {
    if (_loading) return const Loading();
    if (_error != null) return ErrorView(_error!, onRetry: _load);
    final items = _filtered;
    final totalUnit = items.fold<int>(0, (s, p) => s + p.stok);
    final nilai = items.fold<double>(0, (s, p) => s + p.hargaBeli * p.stok);
    final chart = _chartData;
    final opData = _opnameData;
    final scopeText = _range == null
        ? 'Semua tanggal'
        : '${DateFormat('d MMM yy', 'id_ID').format(_range!.start)} – ${DateFormat('d MMM yy', 'id_ID').format(_range!.end)}';

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          // ── Filter ──
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<int?>(
                initialValue: _gudangId,
                isExpanded: true,
                borderRadius: BorderRadius.circular(14),
                decoration: const InputDecoration(labelText: 'Gudang', prefixIcon: Icon(Icons.warehouse_outlined)),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Semua')),
                  ..._warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.nama, overflow: TextOverflow.ellipsis))),
                ],
                onChanged: (v) => setState(() => _gudangId = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int?>(
                initialValue: _kategoriId,
                isExpanded: true,
                borderRadius: BorderRadius.circular(14),
                decoration: const InputDecoration(labelText: 'Kategori', prefixIcon: Icon(Icons.category_outlined)),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Semua')),
                  ..._categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nama, overflow: TextOverflow.ellipsis))),
                ],
                onChanged: (v) => setState(() => _kategoriId = v),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: _tokoId,
            isExpanded: true,
            borderRadius: BorderRadius.circular(14),
            decoration: const InputDecoration(labelText: 'Toko', prefixIcon: Icon(Icons.storefront_outlined)),
            items: [
              const DropdownMenuItem(value: null, child: Text('Semua')),
              ..._tokos.map((t) => DropdownMenuItem(value: t.id, child: Text(t.namaToko, overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (v) => setState(() => _tokoId = v),
          ),
          const SizedBox(height: 12),
          // ── Filter rentang tanggal (buat grafik) ──
          Row(children: [
            Expanded(
              child: TapField(
                value: _range == null
                    ? null
                    : '${DateFormat('d MMM yy', 'id_ID').format(_range!.start)} – ${DateFormat('d MMM yy', 'id_ID').format(_range!.end)}',
                hint: 'Semua tanggal',
                leadingIcon: Icons.date_range_rounded,
                onTap: () async {
                  final r = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    initialDateRange: _range,
                  );
                  if (r != null) setState(() => _range = r);
                },
              ),
            ),
            if (_range != null) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => setState(() => _range = null),
                icon: const Icon(Icons.close_rounded, color: AppTheme.muted),
                style: IconButton.styleFrom(backgroundColor: AppTheme.soft),
              ),
            ],
          ]),
          const SizedBox(height: 16),
          // ── Ringkasan ──
          Row(children: [
            Expanded(child: StatCard(label: 'Produk', value: angka(items.length), icon: Icons.checkroom_rounded, color: AppTheme.primary)),
            const SizedBox(width: 12),
            Expanded(child: StatCard(label: 'Total Unit', value: angka(totalUnit), icon: Icons.inventory_2_rounded, color: AppTheme.info)),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.border),
              boxShadow: AppTheme.softShadow,
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.payments_rounded, color: AppTheme.success, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(rupiah(nilai), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  const Text('Nilai Inventori (modal)', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          // ── Grafik 1: masuk vs keluar per toko ──
          SectionHeader('Masuk vs Keluar per Toko', icon: Icons.bar_chart_rounded, color: AppTheme.info),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.only(left: 2),
            child: Text('Ketuk bar untuk lihat rincian produknya.',
                style: TextStyle(fontSize: 11.5, color: AppTheme.faint)),
          ),
          const SizedBox(height: 10),
          SoftCard(
            child: chart.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: Center(child: Text('Belum ada data mutasi untuk grafik.', style: TextStyle(color: AppTheme.muted))))
                : _BarChart(data: chart, onTapGroup: _showTokoDetail),
          ),
          const SizedBox(height: 20),
          // ── Grafik 2: opname per toko ──
          SectionHeader('Opname per Toko', icon: Icons.fact_check_rounded, color: AppTheme.warning),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text('Rentang: $scopeText · ketuk bar untuk detail.',
                style: const TextStyle(fontSize: 11.5, color: AppTheme.faint)),
          ),
          const SizedBox(height: 10),
          SoftCard(
            child: opData.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: Center(child: Text('Belum ada opname untuk rentang ini.', style: TextStyle(color: AppTheme.muted))))
                : _OpnameChart(data: opData, onTapGroup: _showOpnameDetail),
          ),
          const SizedBox(height: 20),
          SectionHeader('Daftar Produk (${items.length})', icon: Icons.list_alt_rounded),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 20), child: EmptyView('Tidak ada produk untuk filter ini.'))
          else
            SoftCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (int i = 0; i < items.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 16),
                  _row(items[i]),
                ],
              ]),
            ),
        ],
      ),
    );
  }

  Widget _row(Product p) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(namaPendek(p.nama),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 2),
              Text(
                  [
                    p.sku,
                    if (p.warna != null && p.warna!.isNotEmpty) p.warna!,
                    p.gudang ?? '-',
                    p.toko ?? '-',
                  ].join(' · '),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${angka(p.stok)} ${p.satuan}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
            Text('min ${p.stokMin}', style: const TextStyle(fontSize: 10.5, color: AppTheme.faint)),
          ]),
          const SizedBox(width: 10),
          StockBadge(p.stockState),
        ]),
      );
}

/// Grafik bar sederhana tanpa library: per toko 2 bar (masuk hijau, keluar
/// merah). Scroll horizontal kalau tokonya banyak. Tap grup → rincian produk.
class _BarChart extends StatelessWidget {
  final List<({String toko, int masuk, int keluar})> data;
  final void Function(String toko)? onTapGroup;
  const _BarChart({required this.data, this.onTapGroup});

  static const double _maxBarH = 110;

  @override
  Widget build(BuildContext context) {
    int maxV = 1;
    for (final d in data) {
      if (d.masuk > maxV) maxV = d.masuk;
      if (d.keluar > maxV) maxV = d.keluar;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _legend(AppTheme.success, 'Masuk'),
          const SizedBox(width: 14),
          _legend(AppTheme.danger, 'Keluar'),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: _maxBarH + 52,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [for (final d in data) _group(d, maxV)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _legend(Color c, String label) => Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11.5, color: AppTheme.muted, fontWeight: FontWeight.w600)),
      ]);

  Widget _group(({String toko, int masuk, int keluar}) d, int maxV) {
    return InkWell(
      onTap: onTapGroup == null ? null : () => onTapGroup!(d.toko),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 86,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _bar(d.masuk, maxV, AppTheme.success),
                const SizedBox(width: 5),
                _bar(d.keluar, maxV, AppTheme.danger),
              ],
            ),
            const SizedBox(height: 7),
            Text(d.toko,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10.5, color: AppTheme.ink, fontWeight: FontWeight.w600, height: 1.15)),
          ],
        ),
      ),
    );
  }

  Widget _bar(int v, int maxV, Color color) {
    final h = (v / maxV) * _maxBarH;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(angka(v), style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(height: 3),
      Container(
        width: 18,
        height: h < 3 ? 3 : h,
        decoration: BoxDecoration(
          color: v == 0 ? color.withValues(alpha: 0.2) : color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
        ),
      ),
    ]);
  }
}

/// Grafik opname per toko: tiap toko 3 bar — Stok Sistem (biru), Hasil Opname
/// (oranye), Selisih (hijau kalau +, merah kalau −). Scroll horizontal, tap
/// grup buat rincian produk.
class _OpnameChart extends StatelessWidget {
  final List<({String toko, int stok, int hasil, int selisih})> data;
  final void Function(String toko)? onTapGroup;
  const _OpnameChart({required this.data, this.onTapGroup});

  static const double _maxBarH = 110;

  @override
  Widget build(BuildContext context) {
    int maxV = 1;
    for (final d in data) {
      for (final v in [d.stok, d.hasil, d.selisih.abs()]) {
        if (v > maxV) maxV = v;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 14, runSpacing: 6, children: [
          _legend(AppTheme.info, 'Stok Sistem'),
          _legend(AppTheme.warning, 'Hasil Opname'),
          _legend(AppTheme.success, 'Selisih'),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: _maxBarH + 54,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [for (final d in data) _group(d, maxV)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _legend(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11.5, color: AppTheme.muted, fontWeight: FontWeight.w600)),
      ]);

  Widget _group(({String toko, int stok, int hasil, int selisih}) d, int maxV) {
    final selColor = d.selisih >= 0 ? AppTheme.success : AppTheme.danger;
    return InkWell(
      onTap: onTapGroup == null ? null : () => onTapGroup!(d.toko),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 108,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _bar(angka(d.stok), d.stok, maxV, AppTheme.info),
                const SizedBox(width: 4),
                _bar(angka(d.hasil), d.hasil, maxV, AppTheme.warning),
                const SizedBox(width: 4),
                _bar('${d.selisih >= 0 ? '+' : ''}${angka(d.selisih)}', d.selisih.abs(), maxV, selColor),
              ],
            ),
            const SizedBox(height: 7),
            Text(d.toko,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10.5, color: AppTheme.ink, fontWeight: FontWeight.w600, height: 1.15)),
          ],
        ),
      ),
    );
  }

  Widget _bar(String valueText, int v, int maxV, Color color) {
    final h = (v / maxV) * _maxBarH;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(valueText, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(height: 3),
      Container(
        width: 18,
        height: h < 3 ? 3 : h,
        decoration: BoxDecoration(
          color: v == 0 ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
        ),
      ),
    ]);
  }
}
