// Beranda: header sapaan + avatar profil (logout di sini), KPI responsive,
// aksi cepat, mutasi terbaru, dan stok menipis.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../auth.dart';
import '../models.dart';
import '../ui.dart';
import '../config.dart';
import 'penerimaan_screen.dart';
import 'transfer_screen.dart';
import 'opname_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<(List<Product>, List<StockMove>)> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(List<Product>, List<StockMove>)> _load() async {
    final results = await Future.wait([api.products(), api.moves()]);
    return (results[0] as List<Product>, results[1] as List<StockMove>);
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final nama = (user?.nama?.trim().isNotEmpty ?? false) ? user!.nama! : (user?.email ?? 'Admin');
    return Column(children: [
      ModernHeader(
        title: 'Halo, ${nama.split(' ').first} 👋',
        subtitle: 'Ringkasan stok gudang kamu hari ini',
        trailing: _avatarButton(context, nama),
      ),
      Expanded(
        child: FutureBuilder<(List<Product>, List<StockMove>)>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Loading();
            if (snap.hasError) return ErrorView('${snap.error}', onRetry: _reload);
            final (products, moves) = snap.data!;
            final totalUnit = products.fold<int>(0, (s, p) => s + p.stok);
            final nilai = products.fold<double>(0, (s, p) => s + p.hargaBeli * p.stok);
            final menipis = products.where((p) => p.stockState == 'menipis').length;
            final habis = products.where((p) => p.stockState == 'habis').length;
            final low = products.where((p) => p.stockState != 'aman').toList();
            final recent = moves.take(8).toList();

            return RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [
                  // ── KPI: adaptif ke lebar layar (2 kolom HP kecil, lebih di layar lebar) ──
                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 240,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 118,
                    ),
                    children: [
                      StatCard(label: 'Total Produk', value: angka(products.length), icon: Icons.checkroom_rounded, color: AppTheme.primary),
                      StatCard(label: 'Total Unit', value: angka(totalUnit), icon: Icons.inventory_2_rounded, color: AppTheme.info),
                      StatCard(label: 'Nilai Inventori', value: rupiahRingkas(nilai), icon: Icons.payments_rounded, color: AppTheme.success),
                      StatCard(
                        label: 'Perlu Perhatian',
                        value: '${menipis + habis}',
                        icon: Icons.warning_amber_rounded,
                        color: AppTheme.warning,
                        sub: '$menipis menipis · $habis habis',
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SectionHeader('Aksi Cepat', icon: Icons.bolt_rounded, color: AppTheme.warning),
                  const SizedBox(height: 10),
                  Row(children: [
                    _quick(context, Icons.download_rounded, AppTheme.success, 'Penerimaan', const PenerimaanScreen()),
                    const SizedBox(width: 10),
                    _quick(context, Icons.swap_horiz_rounded, AppTheme.info, 'Transfer', const TransferScreen()),
                    const SizedBox(width: 10),
                    _quick(context, Icons.fact_check_rounded, AppTheme.warning, 'Opname', const OpnameScreen()),
                  ]),
                  const SizedBox(height: 22),
                  SectionHeader('Mutasi Stok Terbaru', icon: Icons.history_rounded),
                  const SizedBox(height: 10),
                  if (recent.isEmpty)
                    _emptyCard('Belum ada mutasi stok.')
                  else
                    SoftCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(children: [
                        for (int i = 0; i < recent.length; i++) ...[
                          if (i > 0) const Divider(height: 1, indent: 66),
                          _moveTile(recent[i]),
                        ],
                      ]),
                    ),
                  const SizedBox(height: 22),
                  SectionHeader('Stok Menipis / Habis', icon: Icons.error_outline_rounded, color: AppTheme.danger),
                  const SizedBox(height: 10),
                  if (low.isEmpty)
                    _emptyCard('Semua stok aman. 👍')
                  else
                    SoftCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(children: [
                        for (int i = 0; i < low.length; i++) ...[
                          if (i > 0) const Divider(height: 1, indent: 16),
                          _lowTile(low[i]),
                        ],
                      ]),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ]);
  }

  // ── Avatar → bottom sheet profil + logout ──
  Widget _avatarButton(BuildContext context, String nama) {
    return GestureDetector(
      onTap: () => _openProfile(context),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(nama.trim().isEmpty ? '?' : nama.trim()[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
      ),
    );
  }

  void _openProfile(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 42, height: 5,
              decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(height: 18),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(gradient: AppTheme.brandGradient, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text((user?.nama ?? user?.email ?? '?').trim()[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 26)),
            ),
            const SizedBox(height: 12),
            Text(user?.nama ?? user?.email ?? '-',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.ink)),
            const SizedBox(height: 3),
            Text(user?.email ?? '', style: const TextStyle(fontSize: 13, color: AppTheme.muted)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(user?.role ?? (user?.isAdmin == true ? 'Admin' : 'Pengelola Stok'),
                  style: const TextStyle(color: AppTheme.primaryDark, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (dctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Keluar dari aplikasi?'),
                    content: const Text('Kamu perlu login lagi setelah keluar.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Batal')),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.danger, minimumSize: const Size(100, 44)),
                        onPressed: () => Navigator.pop(dctx, true),
                        child: const Text('Keluar'),
                      ),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  await context.read<AuthProvider>().logout();
                }
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Keluar'),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _quick(BuildContext context, IconData icon, Color color, String label, Widget page) {
    return Expanded(
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(height: 7),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.ink)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _emptyCard(String msg) => SoftCard(
      padding: const EdgeInsets.all(22),
      child: Center(child: Text(msg, style: const TextStyle(color: AppTheme.muted))));

  Widget _moveTile(StockMove m) {
    final arah = m.tipe == 'transfer'
        ? '${m.gudang ?? '-'} → ${m.gudangTujuan ?? '-'}'
        : (m.gudang ?? m.refNo ?? '');
    final keluar = m.tipe == 'keluar';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        MoveAvatar(m.tipe),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(namaPendek(m.item ?? m.sku ?? '-'),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 2),
            Text(
              [
                tanggalID(m.tanggal),
                if (m.warna != null && m.warna!.isNotEmpty) m.warna!,
                if (m.ukuran != null && m.ukuran!.isNotEmpty) 'uk ${m.ukuran}',
                arah,
              ].where((e) => e.isNotEmpty).join(' · '),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: AppTheme.muted),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        Text('${keluar ? '-' : '+'}${angka(m.qty)}',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: keluar ? AppTheme.danger : AppTheme.success)),
      ]),
    );
  }

  Widget _lowTile(Product p) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(namaPendek(p.nama), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 2),
              Text(
                  '${p.sku}${p.warna != null && p.warna!.isNotEmpty ? ' · ${p.warna}' : ''} · min ${p.stokMin} · ${p.gudang ?? '-'}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          Text('${p.stok}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(width: 10),
          StockBadge(p.stockState),
        ]),
      );
}
