// Layar Monitoring & Prestasi — pengawasan produksi (WIP, progres berjalan,
// stok per tukang potong) + kinerja produksi (penjahit, cutter, checker).
// Backend sudah men-scope data sesuai peran (tukang lihat miliknya; checker/
// superadmin lihat semua). Nav-tab, tanpa AppBar.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../auth.dart';
import '../models.dart';
import '../ui.dart';
import '../config.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

// Definisi stage WIP: key backend + label + warna + ikon.
class _WipStage {
  final String key;
  final String label;
  final Color color;
  final IconData icon;
  const _WipStage(this.key, this.label, this.color, this.icon);
}

const List<_WipStage> _wipStages = [
  _WipStage('stok_mentah', 'Stok Mentah', AppTheme.primary, Icons.inventory_2_outlined),
  _WipStage('dijahit', 'Sedang Dijahit', AppTheme.warning, Icons.content_cut_rounded),
  _WipStage('nunggu_cek', 'Nunggu Dicek', AppTheme.info, Icons.hourglass_bottom_rounded),
  _WipStage('rework', 'Perbaikan', AppTheme.danger, Icons.build_outlined),
  _WipStage('kurang', 'Kurang', AppTheme.danger, Icons.report_gmailerrorred_outlined),
  _WipStage('selesai', 'Selesai / Lolos QC', AppTheme.success, Icons.verified_outlined),
];

const List<String> _bulanNama = [
  'Semua', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

class _MonitoringScreenState extends State<MonitoringScreen> {
  bool _loading = true;
  String? _error;
  Monitoring? _mon;
  Prestasi? _prestasi;

  // Filter periode prestasi.
  late int _tahun;
  int? _bulan; // null = semua bulan

  bool _prestasiLoading = false;

  @override
  void initState() {
    super.initState();
    _tahun = DateTime.now().year;
    _bulan = null;
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        api.monitoring(),
        api.prestasi(tahun: _tahun, bulan: _bulan),
      ]);
      if (!mounted) return;
      setState(() {
        _mon = results[0] as Monitoring;
        _prestasi = results[1] as Prestasi;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Terjadi kesalahan: $e';
        _loading = false;
      });
    }
  }

  // Muat ulang prestasi saja (dipakai saat filter periode berubah).
  Future<void> _loadPrestasi() async {
    setState(() => _prestasiLoading = true);
    try {
      final p = await api.prestasi(tahun: _tahun, bulan: _bulan);
      if (!mounted) return;
      setState(() {
        _prestasi = p;
        _prestasiLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _prestasiLoading = false);
      toast(context, e.message, error: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _prestasiLoading = false);
      toast(context, 'Gagal memuat prestasi: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          ModernHeader(
            title: 'Monitoring & Prestasi',
            subtitle: auth.user?.nama,
            trailing: const Icon(Icons.insights_rounded, color: Colors.white, size: 26),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Loading(label: 'Memuat monitoring…');
    if (_error != null) return ErrorView(_error!, onRetry: _loadAll);

    final mon = _mon!;
    final prestasi = _prestasi;

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _loadAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // 1) WIP
          SectionHeader('Barang Dalam Proses (WIP)',
              icon: Icons.donut_large_rounded, color: AppTheme.primary),
          const SizedBox(height: 12),
          _buildWipGrid(mon),
          const SizedBox(height: 24),

          // 1b) Dashboard jumlah reject (barang ditolak QC)
          SectionHeader('Barang Ditolak',
              icon: Icons.thumb_down_outlined, color: AppTheme.danger),
          const SizedBox(height: 12),
          _buildRejectDashboard(prestasi),
          const SizedBox(height: 24),

          // 1c) Riwayat penolakan (rework) — ditolak sekarang + histori tiap ronde
          SectionHeader('Riwayat Penolakan (Rework)',
              icon: Icons.history_toggle_off_rounded, color: AppTheme.danger),
          const SizedBox(height: 12),
          _buildPenolakan(mon),
          const SizedBox(height: 24),

          // 2) Progres berjalan
          SectionHeader('Progres Berjalan',
              icon: Icons.play_circle_outline_rounded, color: AppTheme.warning),
          const SizedBox(height: 12),
          _buildAktif(mon),
          const SizedBox(height: 24),

          // 3) Stok per tukang potong
          SectionHeader('Stok per Tukang Potong',
              icon: Icons.content_cut_rounded, color: AppTheme.info),
          const SizedBox(height: 12),
          _buildPerCutter(mon),
          const SizedBox(height: 24),

          // 4) Kinerja produksi + filter
          SectionHeader(
            'Kinerja Produksi — ${prestasi?.periode ?? '-'}',
            icon: Icons.emoji_events_outlined,
            color: AppTheme.success,
            trailing: _prestasiLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          _buildPeriodeFilter(),
          const SizedBox(height: 16),

          _subHeader('Prestasi Penjahit', Icons.person_outline_rounded),
          const SizedBox(height: 8),
          _buildPrestasiPenjahit(prestasi),
          const SizedBox(height: 20),

          _subHeader('Produktivitas Tukang Potong', Icons.straighten_rounded),
          const SizedBox(height: 8),
          _buildPrestasiCutter(prestasi),
          const SizedBox(height: 20),

          _subHeader('Aktivitas Checker', Icons.fact_check_outlined),
          const SizedBox(height: 8),
          _buildPrestasiChecker(prestasi),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─────────────────────── Sub-header kecil ───────────────────────
  Widget _subHeader(String title, IconData icon) => Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.muted),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.ink)),
        ],
      );

  Widget _emptyLine(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(msg, style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
      );

  // ─────────────────────── 1) WIP grid ───────────────────────
  Widget _buildWipGrid(Monitoring mon) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: _wipStages.map((s) {
        final n = mon.wip[s.key] ?? 0;
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showWipDetail(s, mon),
          child: StatCard(
            label: s.label,
            value: '$n pcs',
            icon: s.icon,
            color: s.color,
            sub: '${s.label}  ›  ketuk',
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────── 1b) Dashboard jumlah reject ───────────────────
  Widget _buildRejectDashboard(Prestasi? p) {
    final penjahit = p?.rows ?? const <PrestasiPenjahit>[];
    final checker = p?.checker ?? const <PrestasiChecker>[];
    final totalReject = penjahit.fold<int>(0, (s, r) => s + r.reject);
    // Penjahit dengan reject terbanyak (buat sorot penyebab).
    final penyumbang = penjahit.where((r) => r.reject > 0).toList()
      ..sort((a, b) => b.reject.compareTo(a.reject));

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.report_gmailerrorred_rounded,
                    color: AppTheme.danger, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${angka(totalReject)} pcs',
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.danger)),
                    const Text('Total barang ditolak (periode ini)',
                        style: TextStyle(fontSize: 12.5, color: AppTheme.muted)),
                  ],
                ),
              ),
            ],
          ),
          if (penyumbang.isNotEmpty) ...[
            const Divider(height: 22, color: AppTheme.border),
            const Text('Ditolak per penjahit',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: penyumbang
                  .map((r) => _miniPill('${r.penjahit ?? '-'}  ×${r.reject}', AppTheme.danger))
                  .toList(),
            ),
          ],
          if (checker.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Diperiksa oleh ${checker.length} checker · '
              '${angka(checker.fold<int>(0, (s, c) => s + c.acc))} lolos',
              style: const TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────── 1c) Riwayat penolakan (rework) ───────────────────
  Widget _buildPenolakan(Monitoring mon) {
    if (mon.penolakan.isEmpty) {
      return const EmptyView('Belum ada jahitan yang pernah ditolak 👍', icon: Icons.thumb_up_alt_outlined);
    }
    return Column(children: mon.penolakan.map(_penolakanCard).toList());
  }

  Widget _penolakanCard(PenolakanRow p) {
    final tuntas = p.ditolakSekarang <= 0;
    final sub = [
      if ((p.produk ?? '').isNotEmpty) p.produk!,
      if ((p.potonganNo ?? '').isNotEmpty) '#${p.potonganNo}',
    ].join('  ·  ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.penjahit ?? '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                      if (sub.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (tuntas ? AppTheme.success : AppTheme.danger).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(tuntas ? 'Tuntas ✓' : 'Ditolak sekarang ${angka(p.ditolakSekarang)}',
                      style: TextStyle(
                          color: tuntas ? AppTheme.success : AppTheme.danger,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(children: [
              _miniPill('${p.nDitolak}× ditolak', AppTheme.muted),
              const SizedBox(width: 8),
              _miniPill('total −${p.totalDitolak}', AppTheme.danger),
            ]),
            const SizedBox(height: 12),
            const Text('Riwayat ditolak',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.muted)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: p.riwayat
                  .map((h) => _miniPill('${tanggalID(h.tanggal)}  ·  −${h.jumlah}', AppTheme.danger))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showWipDetail(_WipStage stage, Monitoring mon) {
    final rows = mon.wipDetail[stage.key] ?? const <WipDetailRow>[];
    final total = mon.wip[stage.key] ?? 0;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (ctx, scrollCtrl) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: stage.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(stage.icon, color: stage.color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(stage.label,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.ink)),
                            Text('$total pcs',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: stage.color)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 20, color: AppTheme.border),
                Expanded(
                  child: rows.isEmpty
                      ? const EmptyView('Tidak ada item', icon: Icons.inbox_outlined)
                      : ListView.separated(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                          itemCount: rows.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 16, color: AppTheme.border),
                          itemBuilder: (_, i) => _wipDetailRow(rows[i], stage.color),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _wipDetailRow(WipDetailRow r, Color color) {
    // "{label} · {produk} · {warna} · {ukuran}" — bagian kosong dilewati.
    final parts = <String>[
      if ((r.label ?? '').isNotEmpty) r.label!,
      if ((r.produk ?? '').isNotEmpty) r.produk!,
      if ((r.warna ?? '').isNotEmpty) r.warna!,
      if ((r.ukuran ?? '').isNotEmpty) r.ukuran!,
    ];
    final desc = parts.isEmpty ? '—' : parts.join('  ·  ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 5),
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(desc,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.ink)),
              if ((r.gudang ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('Gudang: ${r.gudang}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text('${r.pcs} pcs',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }

  // ─────────────────────── 2) Progres berjalan ───────────────────────
  Widget _buildAktif(Monitoring mon) {
    if (mon.aktif.isEmpty) {
      return const EmptyView('Tidak ada progres berjalan', icon: Icons.hourglass_empty_rounded);
    }
    return Column(
      children: mon.aktif.map(_aktifCard).toList(),
    );
  }

  Widget _aktifCard(JahitRequest j) {
    // Untuk status rework, jumlah yang relevan adalah qty perbaikan (hasil reject
    // dari checking), bukan total pcs seluruh request.
    final reworkTotal = j.rework.fold<int>(0, (s, rw) => s + rw.qty);
    final isRework = j.status == 'rework' && reworkTotal > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(j.penjahit ?? '(tanpa penjahit)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                      if ((j.cutter ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('Potong: ${j.cutter}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _statusChip(j.status),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      if ((j.produk ?? '').isNotEmpty) j.produk!,
                      if ((j.potonganNo ?? '').isNotEmpty) '#${j.potonganNo}',
                    ].join('  ·  '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.ink),
                  ),
                ),
                const SizedBox(width: 10),
                _miniPill(
                  isRework
                      ? 'Perbaikan ${angka(reworkTotal)} pcs'
                      : 'Roll ${j.nRoll} / ${j.pcs} pcs',
                  isRework ? AppTheme.danger : AppTheme.info,
                ),
              ],
            ),
            if (j.status == 'rework' && j.rework.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: j.rework.map((rw) {
                  final t = [
                    if ((rw.warna ?? '').isNotEmpty) rw.warna!,
                    if ((rw.ukuran ?? '').isNotEmpty) rw.ukuran!,
                  ].join('  ·  ');
                  return _miniPill('${t.isEmpty ? 'item' : t}  ×${rw.qty}', AppTheme.danger);
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final label = jahitStatusLabel[status] ?? status;
    final color = switch (status) {
      'pending' => AppTheme.muted,
      'acc' => AppTheme.info,
      'reject' => AppTheme.danger,
      'selesai' => AppTheme.warning,
      'rework' => AppTheme.danger,
      'done' => AppTheme.success,
      _ => AppTheme.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _miniPill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  // ─────────────────────── 3) Stok per tukang potong ───────────────────────
  Widget _buildPerCutter(Monitoring mon) {
    if (mon.perCutter.isEmpty) {
      return const EmptyView('Belum ada stok potongan', icon: Icons.content_cut_rounded);
    }
    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
      child: Column(
        children: [
          for (int i = 0; i < mon.perCutter.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppTheme.border),
            _perCutterRow(mon.perCutter[i]),
          ],
        ],
      ),
    );
  }

  Widget _perCutterRow(PerCutterRow r) {
    final sub = [
      if ((r.produk ?? '').isNotEmpty) r.produk!,
      if ((r.warna ?? '').isNotEmpty) r.warna!,
      if ((r.ukuran ?? '').isNotEmpty) r.ukuran!,
    ].join('  ·  ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.tukang ?? '-',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.ink)),
                if (sub.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(sub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${r.totalPcs} pcs',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.ink)),
              const SizedBox(height: 3),
              _miniPill('avail ${r.availablePcs}', AppTheme.success),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────── 4) Filter periode ───────────────────────
  Widget _buildPeriodeFilter() {
    final now = DateTime.now().year;
    final tahunOpsi = [now, now - 1, now - 2];
    return Row(
      children: [
        Expanded(
          child: _dropdownBox<int>(
            label: 'Tahun',
            value: _tahun,
            items: tahunOpsi
                .map((t) => DropdownMenuItem(value: t, child: Text('$t')))
                .toList(),
            onChanged: (v) {
              if (v == null || v == _tahun) return;
              setState(() => _tahun = v);
              _loadPrestasi();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _dropdownBox<int>(
            label: 'Bulan',
            value: _bulan ?? 0, // 0 = Semua
            items: [
              for (int i = 0; i < _bulanNama.length; i++)
                DropdownMenuItem(value: i, child: Text(_bulanNama[i])),
            ],
            onChanged: (v) {
              if (v == null) return;
              final nb = v == 0 ? null : v;
              if (nb == _bulan) return;
              setState(() => _bulan = nb);
              _loadPrestasi();
            },
          ),
        ),
      ],
    );
  }

  Widget _dropdownBox<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.muted)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.soft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              borderRadius: BorderRadius.circular(14),
              icon: const Icon(Icons.expand_more_rounded, color: AppTheme.muted),
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.ink),
              dropdownColor: AppTheme.surface,
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────── 4a) Prestasi penjahit ───────────────────────
  Widget _buildPrestasiPenjahit(Prestasi? p) {
    final rows = p?.rows ?? const <PrestasiPenjahit>[];
    if (rows.isEmpty) return _emptyLine('Belum ada data');
    return Column(children: rows.map(_penjahitCard).toList());
  }

  Widget _penjahitCard(PrestasiPenjahit r) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.penjahit ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                ),
                const SizedBox(width: 10),
                _persenPill(r.persenAcc),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _miniPill('Ajuan ${r.nRequest}', AppTheme.info),
                _miniPill('Acc ${r.acc}', AppTheme.success),
                _miniPill('Tolak ${r.reject}', AppTheme.danger),
                _miniPill('Kurang ${r.kurang}', r.kurang > 0 ? AppTheme.danger : AppTheme.muted),
                _miniPill('${r.total} / ${r.target}', AppTheme.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _persenPill(double persen) {
    final color = persen >= 90
        ? AppTheme.success
        : (persen >= 70 ? AppTheme.warning : AppTheme.danger);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('${persen.toStringAsFixed(persen % 1 == 0 ? 0 : 1)}%',
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }

  // ─────────────────────── 4b) Prestasi cutter ───────────────────────
  Widget _buildPrestasiCutter(Prestasi? p) {
    final rows = p?.cutter ?? const <PrestasiCutter>[];
    if (rows.isEmpty) return _emptyLine('Belum ada data');
    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppTheme.border),
            _cutterRow(rows[i]),
          ],
        ],
      ),
    );
  }

  Widget _cutterRow(PrestasiCutter r) {
    final sub = [
      if ((r.produk ?? '').isNotEmpty) r.produk!,
      if ((r.warna ?? '').isNotEmpty) r.warna!,
      if ((r.ukuran ?? '').isNotEmpty) r.ukuran!,
    ].join('  ·  ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.tukang ?? '-',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.ink)),
                if (sub.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(sub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text('${r.totalPcs} pcs',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.ink)),
        ],
      ),
    );
  }

  // ─────────────────────── 4c) Prestasi checker ───────────────────────
  Widget _buildPrestasiChecker(Prestasi? p) {
    final rows = p?.checker ?? const <PrestasiChecker>[];
    if (rows.isEmpty) return _emptyLine('Belum ada data');
    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppTheme.border),
            _checkerRow(rows[i]),
          ],
        ],
      ),
    );
  }

  Widget _checkerRow(PrestasiChecker r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(r.checker ?? '-',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.ink)),
          ),
          const SizedBox(width: 10),
          Wrap(
            spacing: 8,
            children: [
              _miniPill('Sesi ${r.nSesi}', AppTheme.info),
              _miniPill('Acc ${r.acc}', AppTheme.success),
              _miniPill('Tolak ${r.reject}', AppTheme.danger),
            ],
          ),
        ],
      ),
    );
  }
}
