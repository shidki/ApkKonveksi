// Layar TUKANG JAHIT (penjahit) — produksi jahit.
//
// Dua tab:
//   1) "Stok Mentah" — daftar potongan yang masih ada roll available; penjahit
//      bisa buka detail lalu request untuk dijahit.
//   2) "Jahitan Saya" — daftar request jahit milik penjahit ini (scoped backend);
//      untuk request status 'acc'/'rework' bisa mengisi progress jahitan.
//
// Data di-scope backend berdasarkan token (Bearer user-<id>). Stok mentah TIDAK
// di-scope (semua penjahit bisa browse). File ini self-contained.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../auth.dart';
import '../models.dart';
import '../ui.dart';
import '../config.dart';

class JahitScreen extends StatelessWidget {
  const JahitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: Column(
        children: [
          ModernHeader(title: 'Produksi — Jahit', subtitle: auth.user?.nama),
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Material(
                    color: AppTheme.surface,
                    child: const TabBar(
                      labelColor: AppTheme.primary,
                      unselectedLabelColor: AppTheme.muted,
                      indicatorColor: AppTheme.primary,
                      indicatorWeight: 2.5,
                      labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      tabs: [
                        Tab(text: 'Stok Mentah'),
                        Tab(text: 'Jahitan Saya'),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppTheme.border),
                  const Expanded(
                    child: TabBarView(
                      children: [
                        _StokMentahTab(),
                        _JahitanSayaTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── helper: status chip jahit ───────────────────────
Color _jahitStatusColor(String status) {
  switch (status) {
    case 'pending':
      return AppTheme.warning;
    case 'acc':
      return AppTheme.info;
    case 'reject':
      return AppTheme.danger;
    case 'selesai':
      return AppTheme.info;
    case 'rework':
      return AppTheme.warning;
    case 'done':
      return AppTheme.success;
    default:
      return AppTheme.muted;
  }
}

class _JahitStatusChip extends StatelessWidget {
  final String status;
  const _JahitStatusChip(this.status);
  @override
  Widget build(BuildContext context) {
    final c = _jahitStatusColor(status);
    final label = jahitStatusLabel[status] ?? status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }
}

// Sisa jahitan yang belum diselesaikan (dipotong − dijahit) untuk sebuah request.
int _kurangTotal(JahitRequest r) => r.rolls.fold<int>(
      0,
      (s, roll) => s + roll.sizes.fold<int>(0, (t, sz) => t + math.max(0, sz.pcsPotong - sz.qtyJahit)),
    );

// Total pcs yang harus diperbaiki (hasil reject dari checking).
int _perbaikanTotal(JahitRequest r) => r.rework.fold<int>(0, (s, rw) => s + rw.qty);

// Rekap angka sebuah request (dipotong/dijahit/acc/ditolak/kurang) buat detail
// di kartu list & halaman isi. Acc = dijahit − ditolak per ukuran.
({int dipotong, int dijahit, int acc, int reject, int kurang}) _reqTotals(JahitRequest r) {
  final rw = <String, int>{};
  for (final x in r.rework) {
    rw['${x.rollNo ?? ''}|${(x.ukuran ?? '').trim().toLowerCase()}'] = x.qty;
  }
  var dipotong = 0, dijahit = 0, acc = 0, reject = 0, kurang = 0;
  for (final roll in r.rolls) {
    for (final s in roll.sizes) {
      final p = rw['${roll.noRoll}|${s.ukuran.trim().toLowerCase()}'] ?? 0;
      dipotong += s.pcsPotong;
      dijahit += s.qtyJahit;
      acc += math.max(0, s.qtyJahit - p);
      reject += p;
      kurang += math.max(0, s.pcsPotong - s.qtyJahit);
    }
  }
  return (dipotong: dipotong, dijahit: dijahit, acc: acc, reject: reject, kurang: kurang);
}

// Chip kecil "label angka" buat menampilkan rincian per ukuran / per request.
Widget _detailChip(String label, int value, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(7)),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 11, color: AppTheme.muted),
          children: [
            TextSpan(text: '$label '),
            TextSpan(text: angka(value), style: TextStyle(fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );

// ═══════════════════════ TAB 1 — STOK MENTAH ═══════════════════════
class _StokMentahTab extends StatefulWidget {
  const _StokMentahTab();
  @override
  State<_StokMentahTab> createState() => _StokMentahTabState();
}

class _StokMentahTabState extends State<_StokMentahTab> with AutomaticKeepAliveClientMixin {
  List<Potongan> _items = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

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
      final data = await api.jahitStokMentah();
      if (!mounted) return;
      setState(() {
        _items = data;
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
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Loading(label: 'Memuat stok mentah…');
    if (_error != null) return ErrorView(_error!, onRetry: _load);
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _load,
      child: _items.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 80),
                EmptyView('Belum ada stok mentah tersedia.', icon: Icons.content_cut_rounded),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _card(_items[i]),
            ),
    );
  }

  Widget _card(Potongan p) {
    return SoftCard(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _StokMentahDetailPage(id: p.id)),
        );
        if (mounted) _load();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.inventory_2_outlined, size: 20, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.no ?? 'Potongan #${p.id}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.ink)),
                    const SizedBox(height: 2),
                    Text(p.produk ?? '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppTheme.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.faint),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.cut_rounded, size: 14, color: AppTheme.faint),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Pemotong: ${p.tukang ?? '-'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: AppTheme.muted)),
              ),
              Text(tanggalID(p.tanggal), style: const TextStyle(fontSize: 12, color: AppTheme.faint)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _pill('Sisa roll ${angka(p.rollAvailable)}', AppTheme.info, Icons.layers_rounded),
              const SizedBox(width: 8),
              _pill('Sisa pcs ${angka(p.pcsAvailable)}', AppTheme.success, Icons.checkroom_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color c, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );
}

// ─────────────────── Detail stok mentah (dipush) ───────────────────
class _StokMentahDetailPage extends StatefulWidget {
  final int id;
  const _StokMentahDetailPage({required this.id});
  @override
  State<_StokMentahDetailPage> createState() => _StokMentahDetailPageState();
}

class _StokMentahDetailPageState extends State<_StokMentahDetailPage> {
  Potongan? _p;
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
      final data = await api.jahitStokMentahDetail(widget.id);
      if (!mounted) return;
      setState(() {
        _p = data;
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
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final p = _p;
    return Scaffold(
      appBar: AppBar(
        title: Text(p?.no ?? 'Detail Stok Mentah'),
        flexibleSpace: const DecoratedBox(decoration: BoxDecoration(gradient: AppTheme.brandGradient)),
      ),
      floatingActionButton: (p != null && auth.can('pm.jahit.create'))
          ? FloatingActionButton.extended(
              onPressed: () => _openRequestDialog(p),
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('Ajukan Jahit'),
            )
          : null,
      body: _body(auth),
    );
  }

  Widget _body(AuthProvider auth) {
    if (_loading) return const Loading();
    if (_error != null) return ErrorView(_error!, onRetry: _load);
    final p = _p!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(p.produk ?? '-', icon: Icons.inventory_2_outlined),
              const SizedBox(height: 14),
              _kv('No Potongan', p.no ?? '#${p.id}'),
              _kv('Pemotong', p.tukang ?? '-'),
              _kv('Tanggal', tanggalID(p.tanggal)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _statBox('Roll tersedia', '${angka(p.rollAvailable)} / ${angka(p.totalRoll)}', AppTheme.info)),
                const SizedBox(width: 10),
                Expanded(child: _statBox('Pcs tersedia', '${angka(p.pcsAvailable)} / ${angka(p.totalPcs)}', AppTheme.success)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionHeader('Roll (${p.rolls.length})', icon: Icons.layers_rounded, color: AppTheme.info),
        const SizedBox(height: 10),
        ...p.rolls.map(_rollCard),
      ],
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(k, style: const TextStyle(fontSize: 13, color: AppTheme.muted)),
            ),
            Expanded(
              child: Text(v, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.ink)),
            ),
          ],
        ),
      );

  Widget _statBox(String label, String value, Color c) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppTheme.muted)),
        ]),
      );

  Widget _rollCard(PotonganRoll r) {
    final available = r.status == 'available';
    final baseColor = available ? AppTheme.ink : AppTheme.faint;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        color: available ? AppTheme.surface : AppTheme.soft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('#${r.noRoll}',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: baseColor)),
                if (r.warna != null && r.warna!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(r.warna!, style: TextStyle(fontSize: 13, color: baseColor.withValues(alpha: 0.8))),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: (available ? AppTheme.success : AppTheme.muted).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    available ? 'tersedia' : r.status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: available ? AppTheme.success : AppTheme.muted,
                    ),
                  ),
                ),
              ],
            ),
            if (r.sizes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: r.sizes
                    .map((s) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.soft,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Text('${s.ukuran}: ${angka(s.pcsPotong)}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: baseColor)),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openRequestDialog(Potongan p) async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => _RequestJahitDialog(potonganId: p.id),
    );
    if (done == true && mounted) {
      Navigator.of(context).pop(); // kembali; parent akan reload
    }
  }
}

// ─────────────────── Dialog: Request Jahit ───────────────────
class _RequestJahitDialog extends StatefulWidget {
  final int potonganId;
  const _RequestJahitDialog({required this.potonganId});
  @override
  State<_RequestJahitDialog> createState() => _RequestJahitDialogState();
}

class _RequestJahitDialogState extends State<_RequestJahitDialog> {
  final _catatan = TextEditingController();
  List<Tukang> _penjahit = [];
  int? _tukangId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPenjahit();
  }

  @override
  void dispose() {
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _loadPenjahit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await api.tukang(peran: 'jahit');
      if (!mounted) return;
      setState(() {
        _penjahit = list;
        _tukangId = list.length == 1 ? list.first.id : null;
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
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_tukangId == null) {
      toast(context, 'Pilih penjahit dulu.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await api.createJahitRequest({
        'potongan_id': widget.potonganId,
        'tukang_id': _tukangId,
        'catatan': _catatan.text.trim().isEmpty ? null : _catatan.text.trim(),
      });
      if (!mounted) return;
      toast(context, 'Pengajuan jahit dikirim.');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Ajukan Jahit', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      content: SizedBox(
        width: 360,
        child: _content(),
      ),
      actions: _loading || _error != null
          ? [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Tutup'))]
          : [
              TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: const Text('Batal')),
              FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
                child: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : const Text('Kirim'),
              ),
            ],
    );
  }

  Widget _content() {
    if (_loading) return const Padding(padding: EdgeInsets.all(24), child: Loading());
    if (_error != null) return ErrorView(_error!, onRetry: _loadPenjahit);
    if (_penjahit.isEmpty) {
      return const EmptyView('Belum ada penjahit terdaftar.', icon: Icons.person_off_outlined);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledField(
          'Penjahit *',
          DropdownButtonFormField<int>(
            initialValue: _tukangId,
            isExpanded: true,
            borderRadius: BorderRadius.circular(14),
            hint: const Text('Pilih penjahit', style: TextStyle(color: AppTheme.faint)),
            items: _penjahit
                .map((t) => DropdownMenuItem(value: t.id, child: Text(t.nama, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: _saving ? null : (v) => setState(() => _tukangId = v),
          ),
        ),
        LabeledField(
          'Catatan',
          TextFormField(
            controller: _catatan,
            enabled: !_saving,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'Opsional'),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════ TAB 2 — JAHITAN SAYA ═══════════════════════
class _JahitanSayaTab extends StatefulWidget {
  const _JahitanSayaTab();
  @override
  State<_JahitanSayaTab> createState() => _JahitanSayaTabState();
}

class _JahitanSayaTabState extends State<_JahitanSayaTab> with AutomaticKeepAliveClientMixin {
  List<JahitRequest> _items = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

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
      final data = await api.jahitRequests();
      if (!mounted) return;
      setState(() {
        _items = data;
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
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Loading(label: 'Memuat jahitan…');
    if (_error != null) return ErrorView(_error!, onRetry: _load);
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _load,
      child: _items.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 80),
                EmptyView('Belum ada jahitan.', icon: Icons.checkroom_rounded),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _card(_items[i]),
            ),
    );
  }

  Widget _card(JahitRequest r) {
    final auth = context.read<AuthProvider>();
    final canFill = (r.status == 'acc' || r.status == 'rework') && auth.can('pm.jahit.update');
    final isRework = r.status == 'rework';
    final kurang = _kurangTotal(r);
    final perbaikan = _perbaikanTotal(r);
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.penjahit ?? 'Penjahit',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.ink)),
                    const SizedBox(height: 2),
                    Text('${r.potonganNo ?? '#${r.potonganId}'} · ${r.produk ?? '-'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: AppTheme.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _JahitStatusChip(r.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.layers_rounded, size: 14, color: AppTheme.faint),
            const SizedBox(width: 6),
            Text('Roll ${angka(r.nRoll)} / ${angka(r.pcs)} pcs',
                style: const TextStyle(fontSize: 12.5, color: AppTheme.muted, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(tanggalID(r.tanggal), style: const TextStyle(fontSize: 12, color: AppTheme.faint)),
          ]),
          // Ringkasan sisa jahitan yang kurang & jumlah perbaikan (reject checking).
          if ((r.status == 'acc' && kurang > 0) || perbaikan > 0) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (r.status == 'acc' && kurang > 0)
                _infoPill('Kurang jahit ${angka(kurang)} pcs', AppTheme.warning, Icons.pending_actions_rounded),
              if (perbaikan > 0)
                _infoPill('Perbaikan ${angka(perbaikan)} pcs', AppTheme.danger, Icons.build_rounded),
            ]),
          ],
          // Detail angka biar penjahit langsung tahu kondisinya dari list.
          if (canFill) ...[
            const SizedBox(height: 10),
            Builder(builder: (_) {
              final t = _reqTotals(r);
              return Wrap(spacing: 6, runSpacing: 6, children: [
                _detailChip('Dijahit', t.dijahit, AppTheme.info),
                if (isRework) _detailChip('Acc', t.acc, AppTheme.success),
                if (isRework) _detailChip('Ditolak', t.reject, AppTheme.danger),
                if (isRework && t.reject > 0) _detailChip('Perlu diperbaiki', t.reject, AppTheme.danger),
                _detailChip('Kurang', t.kurang, t.kurang > 0 ? AppTheme.warning : AppTheme.faint),
              ]);
            }),
          ],
          if (r.status == 'reject' && r.alasanReject != null && r.alasanReject!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline_rounded, size: 15, color: AppTheme.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Ditolak: ${r.alasanReject}',
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.danger)),
                ),
              ]),
            ),
          ],
          if (canFill) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () async {
                final saved = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => _ProgressPage(request: r)),
                );
                if (saved == true && mounted) _load();
              },
              style: isRework
                  ? FilledButton.styleFrom(backgroundColor: AppTheme.danger)
                  : null,
              icon: Icon(isRework ? Icons.build_rounded : Icons.edit_note_rounded),
              // Dua mode: "Isi Perbaikan" (rework) vs "Isi Jahitan" (lengkapi yang kurang).
              label: Text(isRework ? 'Isi Perbaikan' : 'Isi Jahitan'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoPill(String text, Color c, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );
}

// ─────────────────── Halaman isi progress jahitan (dipush) ───────────────────
class _ProgressPage extends StatefulWidget {
  final JahitRequest request;
  const _ProgressPage({required this.request});
  @override
  State<_ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<_ProgressPage> {
  // Mode ISI JAHITAN → nilai = total dijahit (prefill qtyJahit).
  final Map<int, TextEditingController> _controllers = {};
  // Mode ISI PERBAIKAN → dua input terpisah per ukuran:
  //   _revisiCtrls = jumlah revisi (perbaikan reject), _kurangCtrls = melengkapi kurang.
  final Map<int, TextEditingController> _revisiCtrls = {};
  final Map<int, TextEditingController> _kurangCtrls = {};
  // rollSizeId → batas maksimum input.
  final Map<int, int> _maxByRollSize = {};
  // Data per ukuran (buat detail & hitung).
  final Map<int, int> _pcsById = {}; // dipotong
  final Map<int, int> _dijahitById = {}; // sudah dijahit
  final Map<int, int> _perbaikanById = {}; // reject checking (perlu diperbaiki)
  final Map<int, int> _kurangById = {}; // dipotong − dijahit
  // "noRoll|ukuran" → qty yang harus diperbaiki (dari reject checking)
  final Map<String, int> _reworkByKey = {};
  bool _saving = false;

  bool get _isRework => widget.request.status == 'rework';

  String _reworkKey(int? rollNo, String? ukuran) =>
      '${rollNo ?? ''}|${(ukuran ?? '').trim().toLowerCase()}';

  // di-ACC = dijahit − ditolak (yang lolos QC).
  int _accById(int id) => math.max(0, (_dijahitById[id] ?? 0) - (_perbaikanById[id] ?? 0));

  @override
  void initState() {
    super.initState();
    for (final rw in widget.request.rework) {
      _reworkByKey[_reworkKey(rw.rollNo, rw.ukuran)] = rw.qty;
    }
    for (final roll in widget.request.rolls) {
      for (final s in roll.sizes) {
        final perbaikan = _reworkByKey[_reworkKey(roll.noRoll, s.ukuran)] ?? 0;
        final kurang = math.max(0, s.pcsPotong - s.qtyJahit);
        _pcsById[s.id] = s.pcsPotong;
        _dijahitById[s.id] = s.qtyJahit;
        _perbaikanById[s.id] = perbaikan;
        _kurangById[s.id] = kurang;

        if (_isRework) {
          // Dua input terpisah: revisi (reject) & kurang. Ukuran tanpa keduanya = tuntas.
          if (perbaikan > 0) {
            final c = TextEditingController();
            c.addListener(() => setState(() {}));
            _revisiCtrls[s.id] = c;
          }
          if (kurang > 0) {
            final c = TextEditingController();
            c.addListener(() => setState(() {}));
            _kurangCtrls[s.id] = c;
          }
        } else {
          final c = TextEditingController(text: s.qtyJahit.toString());
          c.addListener(() => setState(() {}));
          _controllers[s.id] = c;
          _maxByRollSize[s.id] = s.pcsPotong;
        }
      }
    }
  }

  int _ctrlVal(TextEditingController? c) => int.tryParse(c?.text.trim() ?? '') ?? 0;

  // Total input aktif (buat enable tombol Kirim).
  int get _totalJahit {
    if (_isRework) {
      var t = 0;
      for (final c in _revisiCtrls.values) {
        t += _ctrlVal(c);
      }
      for (final c in _kurangCtrls.values) {
        t += _ctrlVal(c);
      }
      return t;
    }
    return _controllers.values.fold(0, (sum, c) => sum + _ctrlVal(c));
  }

  @override
  void dispose() {
    for (final c in [..._controllers.values, ..._revisiCtrls.values, ..._kurangCtrls.values]) {
      c.dispose();
    }
    super.dispose();
  }

  List<Map<String, dynamic>>? _collectLines() {
    final lines = <Map<String, dynamic>>[];
    for (final roll in widget.request.rolls) {
      for (final s in roll.sizes) {
        final id = s.id;
        final ctrl = _controllers[id];
        if (_isRework) {
          final perbaikan = _perbaikanById[id] ?? 0;
          final kurang = _kurangById[id] ?? 0;
          final dijahit = _dijahitById[id] ?? 0;
          final revisiDone = _ctrlVal(_revisiCtrls[id]);
          final kurangDone = _ctrlVal(_kurangCtrls[id]);
          if (revisiDone < 0 || kurangDone < 0) {
            toast(context, 'Jumlah tidak boleh minus.', error: true);
            return null;
          }
          if (revisiDone > perbaikan) {
            toast(context, 'Ukuran ${s.ukuran}: revisi ($revisiDone) melebihi yang perlu diperbaiki ($perbaikan).',
                error: true);
            return null;
          }
          if (kurangDone > kurang) {
            toast(context, 'Ukuran ${s.ukuran}: kurang ($kurangDone) melebihi sisa yang kurang ($kurang).',
                error: true);
            return null;
          }
          lines.add({
            'roll_size_id': id,
            'qty_jahit': dijahit + kurangDone, // melengkapi yang kurang menambah jumlah dijahit
            'qty_perbaikan': revisiDone,
          });
        } else {
          final qty = int.tryParse(ctrl?.text.trim() ?? '') ?? 0;
          final max = _maxByRollSize[id] ?? 0;
          if (qty < 0) {
            toast(context, 'Jumlah tidak boleh minus.', error: true);
            return null;
          }
          if (qty > max) {
            toast(context, 'Ukuran ${s.ukuran}: dijahit ($qty) melebihi dipotong ($max).', error: true);
            return null;
          }
          lines.add({'roll_size_id': id, 'qty_jahit': qty});
        }
      }
    }
    return lines;
  }

  Future<void> _save(bool selesai) async {
    final lines = _collectLines();
    if (lines == null) return;

    // Untuk "Selesai → Checking": wajib ada isi + konfirmasi agar tidak
    // terkirim tak sengaja (mis. user cuma niat simpan draft).
    if (selesai) {
      if (_totalJahit <= 0) {
        toast(context,
            _isRework ? 'Isi jumlah perbaikan dulu sebelum kirim ulang.' : 'Isi jumlah dijahit dulu sebelum kirim ke Checking.',
            error: true);
        return;
      }
      final ok = await _confirmSelesai(_totalJahit);
      if (ok != true || !mounted) return;
    }

    setState(() => _saving = true);
    try {
      await api.jahitProgress(widget.request.id, lines, selesai);
      if (!mounted) return;
      toast(context, selesai ? 'Jahitan selesai — dikirim ke Checking.' : 'Tersimpan sementara.');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool?> _confirmSelesai(int total) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(_isRework ? 'Kirim ulang ke Checking?' : 'Kirim ke Checking?',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          content: Text(
            _isRework
                ? '$total pcs hasil perbaikan akan dikirim ulang ke Checking untuk dicek lagi.'
                : 'Total $total pcs akan dikirim ke Checking dan status jahitan jadi "Selesai". '
                    'Jahitan tidak bisa diubah lagi kecuali dikembalikan oleh tukang potong.',
            style: const TextStyle(fontSize: 13.5, color: AppTheme.ink),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
              child: const Text('Ya, Kirim'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isRework ? 'Isi Perbaikan' : 'Isi Jahitan'),
        flexibleSpace: const DecoratedBox(decoration: BoxDecoration(gradient: AppTheme.brandGradient)),
      ),
      bottomNavigationBar: Padding(
        // Naik di atas keyboard supaya tombol tidak ketutupan saat isi angka.
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving ? null : () => _save(false),
                icon: const Icon(Icons.save_outlined, size: 20),
                label: const Text('Simpan Sementara'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: (_saving || _totalJahit <= 0) ? null : () => _save(true),
                icon: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : const Icon(Icons.check_circle_outline_rounded, size: 20),
                label: Text(_isRework ? 'Kirim Perbaikan' : 'Selesai → Checking'),
              ),
            ),
          ]),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          SoftCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SectionHeader(r.produk ?? '-', icon: Icons.checkroom_rounded),
              const SizedBox(height: 10),
              Text('${r.potonganNo ?? '#${r.potonganId}'} · Roll ${angka(r.nRoll)} / ${angka(r.pcs)} pcs',
                  style: const TextStyle(fontSize: 13, color: AppTheme.muted)),
            ]),
          ),
          const SizedBox(height: 16),
          _modeBanner(),
          if (!r.rolls.any((roll) => roll.sizes.isNotEmpty))
            const EmptyView('Tidak ada ukuran untuk diisi.', icon: Icons.straighten_rounded)
          else
            ...r.rolls.map(_rollSection),
        ],
      ),
    );
  }

  // Banner penjelas mode: perbaikan (rework) vs lengkapi yang kurang.
  Widget _modeBanner() {
    final r = widget.request;
    final Color c;
    final IconData icon;
    final String text;
    if (_isRework) {
      final total = _perbaikanTotal(r);
      c = AppTheme.danger;
      icon = Icons.build_rounded;
      text = 'Mode Perbaikan — perbaiki ${angka(total)} pcs yang ditolak checking, lalu kirim ulang.';
    } else {
      final kurang = _kurangTotal(r);
      c = AppTheme.warning;
      icon = Icons.pending_actions_rounded;
      text = kurang > 0
          ? 'Lengkapi jahitan yang masih kurang ${angka(kurang)} pcs. Isi tidak boleh melebihi jumlah dipotong.'
          : 'Isi jumlah yang sudah dijahit. Tidak boleh melebihi jumlah dipotong.';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withValues(alpha: 0.30)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 17, color: c),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: c, fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }

  Widget _rollSection(PotonganRoll roll) {
    if (roll.sizes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Roll #${roll.noRoll}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.ink)),
              if (roll.warna != null && roll.warna!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(roll.warna!, style: const TextStyle(fontSize: 13, color: AppTheme.muted)),
              ],
            ]),
            const SizedBox(height: 12),
            ...roll.sizes.map((s) => _sizeRow(roll, s)),
          ],
        ),
      ),
    );
  }

  // Field input berwarna biar penjahit gampang bedain fungsinya.
  Widget _workField({
    required TextEditingController? c,
    required String label,
    required int max,
    required Color color,
    required IconData icon,
  }) =>
      TextFormField(
        controller: c,
        enabled: !_saving,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w800, color: color),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
          floatingLabelStyle: TextStyle(color: color, fontWeight: FontWeight.w800),
          hintText: '0',
          helperText: 'maks $max',
          helperStyle: const TextStyle(fontSize: 10.5, color: AppTheme.faint),
          isDense: true,
          filled: true,
          fillColor: color.withValues(alpha: 0.06),
          prefixIcon: Icon(icon, size: 16, color: color),
          prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 0),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: color.withValues(alpha: 0.40)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: color, width: 1.6),
          ),
        ),
      );

  Widget _sizeRow(PotonganRoll roll, RollSize s) {
    final id = s.id;
    final dipotong = _pcsById[id] ?? s.pcsPotong;
    final dijahit = _dijahitById[id] ?? s.qtyJahit;
    final perbaikan = _perbaikanById[id] ?? 0;
    final kurang = _kurangById[id] ?? math.max(0, dipotong - dijahit);
    final acc = _accById(id);
    final tuntas = _isRework && perbaikan == 0 && kurang == 0; // ukuran ini sudah beres

    // Widget input: mode perbaikan bisa 2 field (revisi + kurang); mode biasa 1.
    final inputs = <Widget>[];
    if (_isRework) {
      if (perbaikan > 0) {
        inputs.add(_workField(
          c: _revisiCtrls[id], label: 'Revisi', max: perbaikan,
          color: AppTheme.danger, icon: Icons.build_rounded,
        ));
      }
      if (kurang > 0) {
        inputs.add(_workField(
          c: _kurangCtrls[id], label: 'Kurang', max: kurang,
          color: AppTheme.warning, icon: Icons.add_circle_outline_rounded,
        ));
      }
    } else {
      inputs.add(_workField(
        c: _controllers[id], label: 'Dijahit', max: dipotong,
        color: AppTheme.primary, icon: Icons.checkroom_rounded,
      ));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Detail di ATAS dulu biar gampang dibaca, baru ukuran + input.
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.soft, borderRadius: BorderRadius.circular(7)),
              child: Text(s.ukuran.isEmpty ? '-' : s.ukuran,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.ink)),
            ),
            const Spacer(),
            if (tuntas)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle_rounded, size: 15, color: AppTheme.success),
                  SizedBox(width: 5),
                  Text('Tuntas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.success)),
                ]),
              ),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _detailChip('Dipotong', dipotong, AppTheme.muted),
              _detailChip('Dijahit', dijahit, AppTheme.info),
              if (_isRework) _detailChip('Acc', acc, AppTheme.success),
              if (_isRework) _detailChip('Ditolak', perbaikan, AppTheme.danger),
              _detailChip('Kurang', kurang, kurang > 0 ? AppTheme.warning : AppTheme.faint),
            ],
          ),
          if (inputs.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < inputs.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: inputs[i]),
                ],
                // Kalau cuma 1 input, kasih ruang kosong biar tidak melar penuh.
                if (inputs.length == 1) const Spacer(),
              ],
            ),
          ],
          if (s != roll.sizes.last) const Divider(height: 26),
        ],
      ),
    );
  }
}
