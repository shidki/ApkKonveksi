// Kerangka utama setelah login: TANPA sidebar/drawer — pakai bottom navigation
// floating modern (4 tab) + tombol aksi "+" di tengah buat transaksi stok
// (Penerimaan / Transfer / Opname dibuka sebagai halaman penuh).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../auth.dart';
import '../config.dart';
import 'dashboard_screen.dart';
import 'products_screen.dart';
import 'penerimaan_screen.dart';
import 'transfer_screen.dart';
import 'opname_screen.dart';
import 'kartu_stok_screen.dart';
import 'laporan_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = <Widget>[
    DashboardScreen(),
    ProductsScreen(),
    KartuStokScreen(),
    LaporanScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // tombol "+" cuma muncul kalau boleh bikin minimal satu jenis transaksi
    final canAct = auth.can('pm.penerimaan.create') ||
        auth.can('pm.transfer.create') ||
        auth.can('pm.opname.create');
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        extendBody: true, // konten bisa lewat di belakang nav floating
        body: IndexedStack(index: _index, children: _pages),
        bottomNavigationBar: _FloatingNav(
          index: _index,
          showAction: canAct,
          onTap: (i) => setState(() => _index = i),
          onAction: () => _openActionSheet(context),
        ),
      ),
    );
  }

  /// Bottom sheet transaksi stok — pengganti menu Penerimaan/Transfer/Opname.
  void _openActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42, height: 5,
                  decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Transaksi Stok',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink)),
              const SizedBox(height: 4),
              const Text('Pilih jenis transaksi yang mau dicatat.',
                  style: TextStyle(fontSize: 13, color: AppTheme.muted)),
              const SizedBox(height: 18),
              // tiap transaksi cuma muncul kalau role boleh membuatnya
              if (context.read<AuthProvider>().can('pm.penerimaan.create')) ...[
                _actionTile(ctx, Icons.download_rounded, AppTheme.success, 'Penerimaan Stok',
                    'Catat barang masuk, stok bertambah', const PenerimaanScreen()),
                const SizedBox(height: 10),
              ],
              if (context.read<AuthProvider>().can('pm.transfer.create')) ...[
                _actionTile(ctx, Icons.swap_horiz_rounded, AppTheme.info, 'Transfer Gudang',
                    'Pindahkan stok antar gudang', const TransferScreen()),
                const SizedBox(height: 10),
              ],
              if (context.read<AuthProvider>().can('pm.opname.create'))
                _actionTile(ctx, Icons.fact_check_rounded, AppTheme.warning, 'Stok Opname',
                    'Sesuaikan stok sistem dengan fisik', const OpnameScreen()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionTile(BuildContext ctx, IconData icon, Color color, String title, String sub, Widget page) {
    return Material(
      color: AppTheme.soft,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.pop(ctx);
          Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.ink)),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.faint),
          ]),
        ),
      ),
    );
  }
}

/// Bottom navigation floating: kartu putih membulat + tombol "+" gradient di tengah.
class _FloatingNav extends StatelessWidget {
  final int index;
  final bool showAction;
  final ValueChanged<int> onTap;
  final VoidCallback onAction;
  const _FloatingNav({required this.index, required this.showAction, required this.onTap, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(children: [
          _item(0, Icons.home_rounded, Icons.home_outlined, 'Beranda'),
          _item(1, Icons.checkroom_rounded, Icons.checkroom_outlined, 'Produk'),
          // ── Tombol aksi tengah (cuma kalau boleh transaksi) ──
          Expanded(
            child: Center(
              child: showAction
                  ? GestureDetector(
                      onTap: onAction,
                      child: Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          gradient: AppTheme.brandGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.4),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
                      ),
                    )
                  : const SizedBox(width: 52),
            ),
          ),
          _item(2, Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'Riwayat'),
          _item(3, Icons.assessment_rounded, Icons.assessment_outlined, 'Laporan'),
        ]),
      ),
    );
  }

  Widget _item(int i, IconData active, IconData inactive, String label) {
    final sel = index == i;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(i),
        borderRadius: BorderRadius.circular(22),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(sel ? active : inactive, size: 24, color: sel ? AppTheme.primary : AppTheme.faint),
          const SizedBox(height: 3),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                color: sel ? AppTheme.primary : AppTheme.faint,
              )),
        ]),
      ),
    );
  }
}
