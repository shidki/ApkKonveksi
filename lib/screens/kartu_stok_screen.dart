// Riwayat / Kartu Stok = riwayat mutasi satu produk + saldo berjalan.
// Alur: pilih GUDANG dulu → pilih produk (yang ada di gudang itu) → riwayat.
// Ada ringkasan total masuk/keluar, filter rentang tanggal, dan info toko.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api.dart';
import '../models.dart';
import '../ui.dart';
import '../config.dart';
import 'pickers.dart';

class KartuStokScreen extends StatefulWidget {
  const KartuStokScreen({super.key});
  @override
  State<KartuStokScreen> createState() => _KartuStokScreenState();
}

class _Row {
  final StockMove move;
  final int saldo;
  _Row(this.move, this.saldo);
}

class _KartuStokScreenState extends State<KartuStokScreen> {
  List<Product> _products = [];
  List<Warehouse> _warehouses = [];
  int? _gudangId;
  Product? _selected;
  List<_Row> _rows = [];
  DateTimeRange? _range;
  bool _loading = true;
  bool _loadingCard = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRefs();
  }

  Future<void> _loadRefs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([api.products(), api.warehouses()]);
      setState(() {
        _products = results[0] as List<Product>;
        _warehouses = results[1] as List<Warehouse>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _chooseProduct() async {
    if (_gudangId == null) {
      toast(context, 'Pilih gudang dulu.', error: true);
      return;
    }
    final list = _products.where((p) => p.gudangId == _gudangId).toList();
    if (list.isEmpty) {
      toast(context, 'Tidak ada produk di gudang ini.', error: true);
      return;
    }
    final p = await pickProduct(context, list, title: 'Produk di gudang ini');
    if (p == null) return;
    setState(() => _selected = p);
    await _loadCard(p);
  }

  /// Ambil ulang riwayat mutasi produk terpilih (dipakai juga saat refresh).
  Future<void> _loadCard(Product p) async {
    setState(() {
      _loadingCard = true;
      _rows = [];
    });
    try {
      final moves = await api.moves(search: p.sku);
      // saring persis by sku + urutkan tanggal lalu id
      final mine = moves.where((m) => m.sku == p.sku).toList()
        ..sort((a, b) {
          final c = a.tanggal.compareTo(b.tanggal);
          return c != 0 ? c : a.id.compareTo(b.id);
        });
      int saldo = 0;
      final rows = <_Row>[];
      for (final m in mine) {
        if (m.tipe == 'masuk') {
          saldo += m.qty;
        } else if (m.tipe == 'keluar' || m.tipe == 'transfer') {
          saldo -= m.qty;
        } else {
          saldo += m.qty; // opname: qty sudah selisih (bisa +/-)
        }
        rows.add(_Row(m, saldo));
      }
      setState(() {
        _rows = rows.reversed.toList(); // terbaru di atas
        _loadingCard = false;
      });
    } on ApiException catch (e) {
      setState(() => _loadingCard = false);
      if (mounted) toast(context, e.message, error: true);
    }
  }

  /// Tarik data terbaru (produk + stok + riwayat produk terpilih) — pull-to-refresh.
  Future<void> _refreshAll() async {
    try {
      final results = await Future.wait([api.products(), api.warehouses()]);
      final products = results[0] as List<Product>;
      Product? np;
      if (_selected != null) {
        for (final x in products) {
          if (x.id == _selected!.id) {
            np = x;
            break;
          }
        }
      }
      setState(() {
        _products = products;
        _warehouses = results[1] as List<Warehouse>;
        if (np != null) _selected = np; // stok terbaru ikut ke header
      });
      if (_selected != null) await _loadCard(_selected!);
    } catch (e) {
      if (mounted) toast(context, 'Gagal memuat data terbaru.', error: true);
    }
  }

  /// Baris yang lolos filter tanggal (saldo tetap dihitung dari riwayat penuh).
  List<_Row> get _filteredRows {
    if (_range == null) return _rows;
    return _rows.where((r) {
      final d = DateTime.tryParse(r.move.tanggal);
      if (d == null) return true;
      final start = DateUtils.dateOnly(_range!.start);
      final end = DateUtils.dateOnly(_range!.end);
      final dd = DateUtils.dateOnly(d);
      return !dd.isBefore(start) && !dd.isAfter(end);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const ModernHeader(title: 'Riwayat', subtitle: 'Kartu stok & mutasi per produk'),
      Expanded(child: _body()),
    ]);
  }

  Widget _body() {
    if (_loading) return const Loading();
    if (_error != null) return ErrorView(_error!, onRetry: _loadRefs);
    final shown = _filteredRows;
    int totalMasuk = 0, totalKeluar = 0;
    for (final r in shown) {
      final m = r.move;
      final masuk = m.tipe == 'masuk' || (m.tipe == 'opname' && m.qty >= 0);
      if (masuk) {
        totalMasuk += m.qty.abs();
      } else {
        totalKeluar += m.qty.abs();
      }
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _refreshAll,
      child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        // ── Step 1: gudang ──
        DropdownButtonFormField<int?>(
          initialValue: _gudangId,
          isExpanded: true,
          borderRadius: BorderRadius.circular(14),
          decoration: const InputDecoration(labelText: 'Gudang', prefixIcon: Icon(Icons.warehouse_outlined)),
          hint: const Text('Pilih gudang dulu', style: TextStyle(color: AppTheme.faint)),
          items: _warehouses
              .map((w) => DropdownMenuItem(value: w.id, child: Text(w.nama, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) => setState(() {
            _gudangId = v;
            _selected = null; // gudang ganti → produk direset
            _rows = [];
          }),
        ),
        const SizedBox(height: 12),
        // ── Step 2: produk ──
        TapField(
          value: _selected?.nama,
          hint: _gudangId == null ? 'Pilih gudang dulu' : 'Ketuk untuk pilih produk',
          leadingIcon: Icons.checkroom_rounded,
          onTap: _chooseProduct,
        ),
        const SizedBox(height: 16),
        if (_selected == null)
          const Padding(
            padding: EdgeInsets.only(top: 30),
            child: EmptyView('Pilih gudang lalu produk\nuntuk lihat kartu stoknya.', icon: Icons.receipt_long_rounded),
          )
        else if (_loadingCard)
          const Padding(padding: EdgeInsets.all(30), child: Loading())
        else ...[
          // ── Info produk (gradient) ──
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppTheme.brandGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: AppTheme.softShadow,
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_selected!.nama,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 5),
                  Row(children: [
                    Icon(Icons.warehouse_outlined, size: 13, color: Colors.white.withValues(alpha: 0.85)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(_selected!.gudang ?? '-',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.storefront_outlined, size: 13, color: Colors.white.withValues(alpha: 0.85)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(_selected!.toko ?? '-',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Text(_selected!.sku,
                      style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.7))),
                ]),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(angka(_selected!.stok),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
                Text('stok kini · ${_selected!.satuan}',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.85))),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          // ── Filter tanggal ──
          Row(children: [
            Expanded(
              child: TapField(
                value: _range == null
                    ? null
                    : '${DateFormat('d MMM yy', 'id_ID').format(_range!.start)} – ${DateFormat('d MMM yy', 'id_ID').format(_range!.end)}',
                hint: 'Semua tanggal',
                leadingIcon: Icons.date_range_rounded,
                trailingIcon: Icons.expand_more_rounded,
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
          const SizedBox(height: 12),
          // ── Ringkasan total masuk / keluar ──
          Row(children: [
            Expanded(child: _totalCard('Total Masuk', totalMasuk, AppTheme.success, Icons.south_west_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _totalCard('Total Keluar', totalKeluar, AppTheme.danger, Icons.north_east_rounded)),
          ]),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 20), child: EmptyView('Tidak ada mutasi untuk filter ini.'))
          else
            SoftCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (int i = 0; i < shown.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 66),
                  _rowTile(shown[i]),
                ],
              ]),
            ),
          const SizedBox(height: 16),
        ],
      ],
      ),
    );
  }

  Widget _totalCard(String label, int value, Color color, IconData icon) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
          boxShadow: AppTheme.softShadow,
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(angka(value),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
            ]),
          ),
        ]),
      );

  Widget _rowTile(_Row r) {
    final m = r.move;
    final masuk = m.tipe == 'masuk' || (m.tipe == 'opname' && m.qty >= 0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(children: [
        MoveAvatar(m.tipe),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              MoveTipeChip(m.tipe),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  [tanggalID(m.tanggal), if (m.ukuran != null && m.ukuran!.isNotEmpty) 'uk ${m.ukuran}'].where((e) => e.isNotEmpty).join(' · '),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.muted),
                ),
              ),
            ]),
            const SizedBox(height: 3),
            Row(children: [
              const Icon(Icons.storefront_outlined, size: 12, color: AppTheme.faint),
              const SizedBox(width: 4),
              Flexible(
                child: Text(_selected?.toko ?? 'Tanpa toko',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.muted, fontWeight: FontWeight.w600)),
              ),
              if (m.keterangan != null && m.keterangan!.isNotEmpty) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text('· ${m.keterangan!}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.faint)),
                ),
              ],
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${masuk ? '+' : '-'}${angka(m.qty.abs())}',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: masuk ? AppTheme.success : AppTheme.danger)),
            Text('saldo ${angka(r.saldo)}', style: const TextStyle(fontSize: 10.5, color: AppTheme.muted)),
          ],
        ),
      ]),
    );
  }
}
