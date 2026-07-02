// Detail produk (hanya lihat) + riwayat mutasi produk tersebut.
// Dibuka dari list di menu Produk.
import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../ui.dart';
import '../config.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  const ProductDetailScreen({required this.product, super.key});
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Future<List<StockMove>> _moves;

  @override
  void initState() {
    super.initState();
    _moves = _load();
  }

  Future<List<StockMove>> _load() async {
    final all = await api.moves(search: widget.product.sku);
    final mine = all.where((m) => m.sku == widget.product.sku).toList()
      ..sort((a, b) {
        final c = b.tanggal.compareTo(a.tanggal); // terbaru di atas
        return c != 0 ? c : b.id.compareTo(a.id);
      });
    return mine;
  }

  Future<void> _reload() async {
    setState(() => _moves = _load());
    await _moves;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Produk'),
        flexibleSpace: const DecoratedBox(decoration: BoxDecoration(gradient: AppTheme.brandGradient)),
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _reload,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
          children: [
            // ── Header produk (gradient) ──
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
                    Text(p.nama,
                        maxLines: 3, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 5),
                    Text(p.sku,
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                  ]),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(angka(p.stok),
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
                  Text('stok · ${p.satuan}',
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.85))),
                  const SizedBox(height: 6),
                  StockBadge(p.stockState),
                ]),
              ]),
            ),
            const SizedBox(height: 14),
            // ── Info lengkap ──
            SoftCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SectionHeader('Informasi', icon: Icons.info_outline_rounded),
                const SizedBox(height: 10),
                _info('Warna', p.warna),
                _info('Kategori', p.kategori),
                _info('Gudang', p.gudang),
                _info('Toko', p.toko),
                _info('Harga Beli', rupiah(p.hargaBeli)),
                _info('Harga Jual', rupiah(p.hargaJual)),
                _info('Stok Minimum', '${p.stokMin} ${p.satuan}'),
                _info('Status', p.status == 'aktif' ? 'Aktif' : 'Nonaktif'),
                if (p.catatan != null && p.catatan!.isNotEmpty) _info('Catatan', p.catatan),
              ]),
            ),
            if (p.pakaiVarian) ...[
              const SizedBox(height: 14),
              SoftCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SectionHeader('Stok per Ukuran', icon: Icons.straighten_rounded, color: AppTheme.info),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: p.variants
                        .map((v) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                  color: AppTheme.soft,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.border)),
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Text(v.ukuran,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.ink)),
                                const SizedBox(height: 1),
                                Text('${v.stok} ${p.satuan}',
                                    style: const TextStyle(fontSize: 10.5, color: AppTheme.muted)),
                              ]),
                            ))
                        .toList(),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 20),
            SectionHeader('Riwayat Produk', icon: Icons.history_rounded),
            const SizedBox(height: 10),
            FutureBuilder<List<StockMove>>(
              future: _moves,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(padding: EdgeInsets.all(24), child: Loading());
                }
                if (snap.hasError) {
                  return SoftCard(
                      padding: const EdgeInsets.all(18),
                      child: Center(
                          child: Text('Gagal memuat riwayat.',
                              style: const TextStyle(color: AppTheme.muted))));
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return const EmptyView('Belum ada mutasi untuk produk ini.');
                }
                return SoftCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(children: [
                    for (int i = 0; i < items.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 66),
                      _moveTile(items[i]),
                    ],
                  ]),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, String? value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 110,
              child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppTheme.muted))),
          Expanded(
            child: Text((value == null || value.isEmpty) ? '-' : value,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.ink)),
          ),
        ]),
      );

  Widget _moveTile(StockMove m) {
    final masuk = m.tipe == 'masuk' || (m.tipe == 'opname' && m.qty >= 0);
    final arah = m.tipe == 'transfer'
        ? '${m.gudang ?? '-'} → ${m.gudangTujuan ?? '-'}'
        : (m.gudang ?? '');
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
                child: Text(tanggalID(m.tanggal),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.muted)),
              ),
            ]),
            const SizedBox(height: 3),
            Text(
              [
                if (m.ukuran != null && m.ukuran!.isNotEmpty) 'uk ${m.ukuran}',
                arah,
                if (m.keterangan != null && m.keterangan!.isNotEmpty) m.keterangan!,
              ].where((e) => e.isNotEmpty).join(' · '),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: AppTheme.faint),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        Text('${masuk ? '+' : '-'}${angka(m.qty.abs())}',
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 14, color: masuk ? AppTheme.success : AppTheme.danger)),
      ]),
    );
  }
}
