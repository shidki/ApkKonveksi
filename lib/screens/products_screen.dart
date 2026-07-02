// Daftar produk — HANYA LIHAT (tanpa tambah/edit/hapus).
// Cari + filter by gudang & toko. Stok ditampilkan per ukuran.
import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../ui.dart';
import '../config.dart';
import 'product_detail_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  List<Product> _all = [];
  List<Warehouse> _warehouses = [];
  List<Toko> _tokos = [];
  int? _gudangId;
  int? _tokoId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        api.products(search: _search.isEmpty ? null : _search),
        api.warehouses(),
        api.tokos(),
      ]);
      setState(() {
        _all = results[0] as List<Product>;
        _warehouses = results[1] as List<Warehouse>;
        _tokos = results[2] as List<Toko>;
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
        if (_tokoId != null && p.tokoId != _tokoId) return false;
        return true;
      }).toList();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const ModernHeader(title: 'Produk', subtitle: 'Lihat produk & stok per ukuran'),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Cari nama / SKU produk…',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _search.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _searchCtrl.clear();
                      _search = '';
                      _load();
                    }),
          ),
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() => _search = v),
          onSubmitted: (_) => _load(),
        ),
      ),
      // ── Filter gudang & toko ──
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Row(children: [
          Expanded(
            child: DropdownButtonFormField<int?>(
              initialValue: _gudangId,
              isExpanded: true,
              borderRadius: BorderRadius.circular(14),
              decoration: const InputDecoration(
                  labelText: 'Gudang', prefixIcon: Icon(Icons.warehouse_outlined)),
              items: [
                const DropdownMenuItem(value: null, child: Text('Semua')),
                ..._warehouses.map((w) =>
                    DropdownMenuItem(value: w.id, child: Text(w.nama, overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) => setState(() => _gudangId = v),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<int?>(
              initialValue: _tokoId,
              isExpanded: true,
              borderRadius: BorderRadius.circular(14),
              decoration: const InputDecoration(
                  labelText: 'Toko', prefixIcon: Icon(Icons.storefront_outlined)),
              items: [
                const DropdownMenuItem(value: null, child: Text('Semua')),
                ..._tokos.map((t) =>
                    DropdownMenuItem(value: t.id, child: Text(t.namaToko, overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) => setState(() => _tokoId = v),
            ),
          ),
        ]),
      ),
      Expanded(child: _body()),
    ]);
  }

  Widget _body() {
    if (_loading) return const Loading();
    if (_error != null) return ErrorView(_error!, onRetry: _load);
    final items = _filtered;
    if (items.isEmpty) {
      return EmptyView(
          _search.isEmpty && _gudangId == null && _tokoId == null
              ? 'Belum ada produk.'
              : 'Produk tidak ditemukan untuk filter ini.',
          icon: Icons.checkroom_rounded);
    }
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
        itemCount: items.length,
        separatorBuilder: (_, i) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) => _card(items[i]),
      ),
    );
  }

  Widget _card(Product p) {
    final st = p.stockState;
    final accent = st == 'habis' ? AppTheme.danger : (st == 'menipis' ? AppTheme.warning : AppTheme.primary);
    return SoftCard(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.checkroom_rounded, color: accent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(namaPendek(p.nama),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: AppTheme.ink)),
                      const SizedBox(height: 3),
                      Text(
                        [p.sku, if (p.warna != null && p.warna!.isNotEmpty) p.warna!, if (p.kategori != null) p.kategori!].join(' · '),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                StockBadge(st),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: AppTheme.faint, size: 20),
              ],
            ),
          ),
          if (p.pakaiVarian)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: p.variants
                    .map((v) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                              color: AppTheme.soft,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.border)),
                          child: Text.rich(TextSpan(children: [
                            TextSpan(text: '${v.ukuran} ', style: const TextStyle(fontSize: 11.5, color: AppTheme.muted)),
                            TextSpan(text: '${v.stok}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.ink)),
                          ])),
                        ))
                    .toList(),
              ),
            ),
          // ── Footer info: gudang · toko · harga · stok ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: const BoxDecoration(
              color: AppTheme.soft,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Row(children: [
              const Icon(Icons.warehouse_outlined, size: 15, color: AppTheme.muted),
              const SizedBox(width: 5),
              Flexible(
                child: Text(p.gudang ?? '-',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.storefront_outlined, size: 15, color: AppTheme.muted),
              const SizedBox(width: 5),
              Flexible(
                child: Text(p.toko ?? '-',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
              ),
              const Spacer(),
              Text(rupiah(p.hargaJual),
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.primaryDark, fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              Text('${angka(p.stok)} ${p.satuan}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.ink)),
            ]),
          ),
        ],
      ),
    );
  }
}
