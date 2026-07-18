// Produksi — Checking / QC. Layar untuk role CHECKING: memeriksa hasil jahitan
// (status 'selesai'), mencatat ACC / REJECT per ukuran, dan menyetok barang jadi
// ke gudang. Dua tab: "Antrian QC" (jahitan siap dicek) & "Riwayat" (checking milik
// checker ini; superadmin melihat semua & bisa membatalkan).
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../auth.dart';
import '../models.dart';
import '../ui.dart';
import '../config.dart';

class CheckingScreen extends StatefulWidget {
  const CheckingScreen({super.key});
  @override
  State<CheckingScreen> createState() => _CheckingScreenState();
}

class _CheckingScreenState extends State<CheckingScreen> {
  final _antrianKey = GlobalKey<_AntrianTabState>();
  final _riwayatKey = GlobalKey<_RiwayatTabState>();

  void _reloadAll() {
    _antrianKey.currentState?.reload();
    _riwayatKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: Column(
        children: [
          ModernHeader(
            title: 'Produksi — Checking / QC',
            subtitle: auth.user?.nama ?? auth.user?.email,
          ),
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Container(
                    color: AppTheme.surface,
                    child: const TabBar(
                      labelColor: AppTheme.primary,
                      unselectedLabelColor: AppTheme.muted,
                      indicatorColor: AppTheme.primary,
                      indicatorWeight: 3,
                      labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      tabs: [
                        Tab(text: 'Antrian QC'),
                        Tab(text: 'Riwayat'),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _AntrianTab(key: _antrianKey, onDone: _reloadAll),
                        _RiwayatTab(key: _riwayatKey),
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

// ─────────────────────────── TAB 1 — ANTRIAN QC ───────────────────────────
class _AntrianTab extends StatefulWidget {
  final VoidCallback onDone;
  const _AntrianTab({super.key, required this.onDone});
  @override
  State<_AntrianTab> createState() => _AntrianTabState();
}

class _AntrianTabState extends State<_AntrianTab> with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  String? _error;
  List<JahitRequest> _items = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await api.checkingAntrian();
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

  Future<void> _periksa(JahitRequest req) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _QcPage(request: req)),
    );
    if (ok == true) {
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Loading(label: 'Memuat antrian…');
    if (_error != null) return ErrorView(_error!, onRetry: reload);
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: reload,
      child: _items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                EmptyView('Belum ada jahitan yang siap dicek.', icon: Icons.checklist_rtl_rounded),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _antrianCard(_items[i]),
            ),
    );
  }

  Widget _antrianCard(JahitRequest r) {
    final judul = [r.potonganNo, r.produk].where((e) => e != null && e.isNotEmpty).join(' · ');
    return SoftCard(
      onTap: () => _periksa(r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.content_cut_rounded, color: AppTheme.info, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.penjahit ?? 'Penjahit -',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.ink),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      judul.isEmpty ? '-' : judul,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.muted),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Roll ${r.nRoll} / ${angka(r.pcs)} pcs',
                      style: const TextStyle(fontSize: 12, color: AppTheme.faint, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _tarik(r),
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: const Text('Tarik'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () => _periksa(r),
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: const Text('Periksa'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _tarik(JahitRequest r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tarik ke penjahit?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: Text(
          'Jahitan ${r.penjahit ?? ''} balik ke status "Dikerjakan" biar penjahit bisa lengkapi/perbaiki lalu kirim ulang. '
          'Dipakai kalau data belum lengkap / penjahit kepencet "Kirim".',
          style: const TextStyle(fontSize: 13.5, color: AppTheme.ink),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, Tarik')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await api.batalSelesaiJahit(r.id);
      if (!mounted) return;
      toast(context, 'Ditarik balik — penjahit bisa isi ulang.');
      reload();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }
}

// ─────────────────────────── _QcPage — form pemeriksaan ───────────────────────────
class _QcPage extends StatefulWidget {
  final JahitRequest request;
  const _QcPage({required this.request});
  @override
  State<_QcPage> createState() => _QcPageState();
}

class _QcPageState extends State<_QcPage> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<Warehouse> _warehouses = [];
  List<Tukang> _checkers = [];
  int? _gudangId;
  int? _checkerId;

  // Controller ACC & TOLAK dikunci berdasarkan rollSizeId.
  // ACC dihitung otomatis dari (dijahit − tolak) dan tidak bisa diedit manual.
  final Map<int, TextEditingController> _accCtrls = {};
  final Map<int, TextEditingController> _rejectCtrls = {};
  // rollSizeId → jumlah yang diperiksa sesi ini (dasar hitung ACC otomatis).
  // Pemeriksaan biasa → = dijahit. Pemeriksaan REVISI → = jumlah revisi + kurang.
  final Map<int, int> _dijahitById = {};
  // "noRoll|ukuran" → qty revisi (reject dari checking sebelumnya).
  final Map<String, int> _reworkByKey = {};

  // Backend mengirim acc kumulatif per ukuran (paling akurat untuk re-check).
  bool get _hasAccData => widget.request.rolls.any((r) => r.sizes.any((s) => s.accSoFar > 0));

  // Ini pemeriksaan ulang (revisi/kurang) kalau ada yang sudah di-acc sebelumnya
  // atau request bawa data rework.
  bool get _isRevisi => _hasAccData || widget.request.rework.isNotEmpty;

  String _reworkKey(int? rollNo, String? ukuran) =>
      '${rollNo ?? ''}|${(ukuran ?? '').trim().toLowerCase()}';

  // Jumlah yang perlu diperiksa untuk sebuah ukuran pada sesi ini.
  int _perluCek(PotonganRoll roll, RollSize s) {
    // Paling akurat: total dijahit − yang sudah di-acc kumulatif.
    if (_hasAccData) return math.max(0, s.qtyJahit - s.accSoFar);
    if (!_isRevisi) return s.qtyJahit;
    // Fallback (backend belum kirim acc): revisi (reject) + sisa kurang.
    final revisi = _reworkByKey[_reworkKey(roll.noRoll, s.ukuran)] ?? 0;
    final kurang = math.max(0, s.pcsPotong - s.qtyJahit);
    return revisi + kurang;
  }

  // Ukuran yang ditampilkan pada sebuah roll (revisi → hanya yang perlu dicek).
  List<RollSize> _shownSizes(PotonganRoll roll) =>
      roll.sizes.where((s) => _accCtrls.containsKey(s.id)).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _accCtrls.values) {
      c.dispose();
    }
    for (final c in _rejectCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        api.warehouses(),
        api.tukang(peran: 'checking'),
      ]);
      final ws = results[0] as List<Warehouse>;
      final cs = results[1] as List<Tukang>;

      // Peta revisi (reject dari checking sebelumnya) per ukuran.
      for (final rw in widget.request.rework) {
        _reworkByKey[_reworkKey(rw.rollNo, rw.ukuran)] = rw.qty;
      }

      // Siapkan controller per ukuran (default ACC = jumlah dicek, TOLAK = 0).
      // ACC otomatis = dicek − tolak; checker cuma isi jumlah yang ditolak.
      // Pemeriksaan REVISI → hanya ukuran yang perlu dicek ulang yang ditampilkan.
      for (final roll in widget.request.rolls) {
        for (final s in roll.sizes) {
          final base = _perluCek(roll, s);
          if (_isRevisi && base <= 0) continue; // sudah acc / tuntas → sembunyikan
          _dijahitById[s.id] = base;
          _accCtrls.putIfAbsent(s.id, () => TextEditingController(text: '$base'));
          _rejectCtrls.putIfAbsent(s.id, () {
            final c = TextEditingController(text: '0');
            c.addListener(() => _syncAcc(s.id));
            return c;
          });
        }
      }

      if (!mounted) return;
      setState(() {
        _warehouses = ws;
        _checkers = cs;
        _gudangId = ws.length == 1 ? ws.first.id : null;
        _checkerId = cs.length == 1 ? cs.first.id : null;
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

  // Saat jumlah TOLAK diubah, ACC otomatis = dijahit − tolak (min 0, max dijahit).
  void _syncAcc(int rollSizeId) {
    final dijahit = _dijahitById[rollSizeId] ?? 0;
    var tolak = _pInt(_rejectCtrls[rollSizeId]);
    if (tolak < 0) tolak = 0;
    if (tolak > dijahit) tolak = dijahit;
    final acc = math.max(0, dijahit - tolak);
    _accCtrls[rollSizeId]?.text = '$acc';
    if (mounted) setState(() {});
  }

  int _pInt(TextEditingController? c) => c == null ? 0 : (int.tryParse(c.text.trim()) ?? 0);

  int get _totalDipotong {
    var t = 0;
    for (final r in widget.request.rolls) {
      for (final s in r.sizes) {
        t += s.pcsPotong;
      }
    }
    return t;
  }

  int get _totalDijahit {
    var t = 0;
    for (final r in widget.request.rolls) {
      for (final s in r.sizes) {
        t += s.qtyJahit;
      }
    }
    return t;
  }

  int get _totalKurang {
    var t = 0;
    for (final r in widget.request.rolls) {
      for (final s in r.sizes) {
        t += math.max(0, s.pcsPotong - s.qtyJahit);
      }
    }
    return t;
  }

  int get _totalAcc {
    var t = 0;
    for (final c in _accCtrls.values) {
      t += math.max(0, _pInt(c));
    }
    return t;
  }

  int get _totalReject {
    var t = 0;
    _rejectCtrls.forEach((id, c) {
      final dijahit = _dijahitById[id] ?? 0;
      t += math.min(dijahit, math.max(0, _pInt(c)));
    });
    return t;
  }

  Future<void> _submit() async {
    if (_totalAcc > 0 && _gudangId == null) {
      toast(context, 'Pilih gudang tujuan dulu untuk stok barang jadi.', error: true);
      return;
    }
    final items = <Map<String, dynamic>>[];
    for (final roll in widget.request.rolls) {
      for (final s in roll.sizes) {
        // Hanya ukuran yang diperiksa sesi ini (pada revisi: yang perlu dicek ulang).
        if (!_accCtrls.containsKey(s.id)) continue;
        final base = _dijahitById[s.id] ?? s.qtyJahit;
        // TOLAK dibatasi maksimal jumlah yang dicek; ACC = dicek − tolak.
        final tolak = math.min(base, math.max(0, _pInt(_rejectCtrls[s.id])));
        final acc = math.max(0, base - tolak);
        items.add({
          'roll_size_id': s.id,
          'qty_acc': acc,
          'qty_reject': tolak,
          'gudang_id': _gudangId,
        });
      }
    }
    if (items.isEmpty) {
      toast(context, 'Tidak ada item untuk dicek.', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await api.createChecking({
        'jahit_request_id': widget.request.id,
        'checker_id': _checkerId,
        'items': items,
      });
      if (!mounted) return;
      toast(context, 'Checking tersimpan.');
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Checking — ${widget.request.penjahit ?? '-'}'),
        flexibleSpace: const DecoratedBox(decoration: BoxDecoration(gradient: AppTheme.brandGradient)),
      ),
      body: _body(),
      bottomNavigationBar: (_loading || _error != null) ? null : _footer(),
    );
  }

  Widget _body() {
    if (_loading) return const Loading(label: 'Menyiapkan pemeriksaan…');
    if (_error != null) return ErrorView(_error!, onRetry: _load);
    final r = widget.request;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // Info request
        SoftCard(
          color: AppTheme.soft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [r.potonganNo, r.produk].where((e) => e != null && e.isNotEmpty).join(' · ').ifEmptyDash(),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.ink),
              ),
              const SizedBox(height: 4),
              Text(
                'Penjahit: ${r.penjahit ?? '-'} · ${r.nRoll} roll · ${angka(r.pcs)} pcs',
                style: const TextStyle(fontSize: 12.5, color: AppTheme.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Gudang tujuan + Checker
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader('Tujuan & Checker', icon: Icons.warehouse_outlined),
              const SizedBox(height: 16),
              LabeledField('Gudang tujuan (stok jadi)', _gudangSelector()),
              LabeledField('Checker', _checkerSelector()),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_isRevisi) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.warning.withValues(alpha: 0.35)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.build_rounded, size: 17, color: AppTheme.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pemeriksaan REVISI — cuma item hasil perbaikan/kurang (${angka(_totalPerluCek)} pcs) '
                  'yang perlu dicek. Yang sudah lolos sebelumnya tidak ditampilkan.',
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.warning, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        SectionHeader(_isRevisi ? 'Periksa Revisi per Ukuran' : 'Periksa per Ukuran',
            icon: Icons.rule_folder_outlined, color: AppTheme.info),
        const SizedBox(height: 10),
        for (final roll in r.rolls)
          if (_shownSizes(roll).isNotEmpty) _rollCard(roll),
      ],
    );
  }

  int get _totalPerluCek => _dijahitById.values.fold(0, (s, v) => s + v);

  Widget _gudangSelector() => DropdownButtonFormField<int?>(
        initialValue: _gudangId,
        isExpanded: true,
        borderRadius: BorderRadius.circular(14),
        decoration: const InputDecoration(prefixIcon: Icon(Icons.warehouse_outlined)),
        hint: const Text('Pilih gudang', style: TextStyle(color: AppTheme.faint)),
        items: _warehouses
            .map((w) => DropdownMenuItem<int?>(value: w.id, child: Text(w.nama, overflow: TextOverflow.ellipsis)))
            .toList(),
        onChanged: (v) => setState(() => _gudangId = v),
      );

  Widget _checkerSelector() {
    // Tidak ada tukang checking (checker biasa cek kerjaannya sendiri).
    if (_checkers.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: AppTheme.soft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Row(children: [
          Icon(Icons.person_pin_circle_outlined, size: 18, color: AppTheme.muted),
          SizedBox(width: 10),
          Text('Kamu (otomatis)', style: TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w600)),
        ]),
      );
    }
    // Tepat satu checker → auto-pilih & nonaktif.
    if (_checkers.length == 1) {
      final only = _checkers.first;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: AppTheme.soft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(children: [
          const Icon(Icons.person_outline, size: 18, color: AppTheme.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(only.nama,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w600)),
          ),
        ]),
      );
    }
    // Banyak checker → pilih.
    return DropdownButtonFormField<int?>(
      initialValue: _checkerId,
      isExpanded: true,
      borderRadius: BorderRadius.circular(14),
      decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline)),
      hint: const Text('Pilih checker', style: TextStyle(color: AppTheme.faint)),
      items: _checkers
          .map((t) => DropdownMenuItem<int?>(value: t.id, child: Text(t.nama, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: (v) => setState(() => _checkerId = v),
    );
  }

  Widget _rollCard(PotonganRoll roll) {
    final warna = roll.warna != null && roll.warna!.isNotEmpty ? ' · ${roll.warna}' : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Roll #${roll.noRoll}$warna',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.primaryDark)),
              ),
            ]),
            const SizedBox(height: 12),
            for (final s in _shownSizes(roll)) ...[
              _sizeRow(roll, s),
              if (s != _shownSizes(roll).last) const Divider(height: 22),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sizeRow(PotonganRoll roll, RollSize s) {
    final kurang = math.max(0, s.pcsPotong - s.qtyJahit);
    // Revisi = jumlah yang sudah pernah ditolak (kumulatif); backend kirim via reject_so_far.
    // Fallback ke peta rework (status 'rework') kalau reject_so_far belum ada.
    final revisi = s.rejectSoFar > 0 ? s.rejectSoFar : (_reworkByKey[_reworkKey(roll.noRoll, s.ukuran)] ?? 0);
    // Sesi revisi: pisahkan berapa dari "perlu dicek" itu revisi vs kurang.
    final pending = _dijahitById[s.id] ?? 0;
    final revisiPart = math.min(pending, revisi);
    final kurangPart = pending - revisiPart;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.soft, borderRadius: BorderRadius.circular(7)),
              child: Text(s.ukuran.isEmpty ? '-' : s.ukuran,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.ink)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                spacing: 10,
                runSpacing: 2,
                children: _isRevisi
                    ? [
                        _miniStat('Perlu dicek', '$pending', AppTheme.warning),
                        if (revisiPart > 0) _miniStat('Revisi', '$revisiPart', AppTheme.danger),
                        if (kurangPart > 0) _miniStat('Kurang', '$kurangPart', AppTheme.warning),
                      ]
                    : [
                        _miniStat('Dipotong', '${s.pcsPotong}', AppTheme.muted),
                        _miniStat('Dijahit', '${s.qtyJahit}', AppTheme.info),
                        _miniStat('Kurang', '$kurang', kurang > 0 ? AppTheme.danger : AppTheme.faint),
                      ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _numField('ACC (otomatis)', _accCtrls[s.id], AppTheme.success, enabled: false)),
          const SizedBox(width: 12),
          Expanded(child: _numField('TOLAK', _rejectCtrls[s.id], AppTheme.danger)),
        ]),
      ],
    );
  }

  Widget _miniStat(String label, String value, Color color) => RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: AppTheme.muted),
          children: [
            TextSpan(text: '$label '),
            TextSpan(text: value, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      );

  Widget _numField(String label, TextEditingController? c, Color color, {bool enabled = true}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 6),
          TextField(
            controller: c,
            enabled: enabled,
            readOnly: !enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: '0',
              isDense: true,
              filled: true,
              fillColor: enabled ? null : color.withValues(alpha: 0.06),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: color.withValues(alpha: 0.35)),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: color.withValues(alpha: 0.20)),
              ),
            ),
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
          ),
        ],
      );

  Widget _footer() {
    final kurang = _totalKurang;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: const Border(top: BorderSide(color: AppTheme.border)),
          boxShadow: AppTheme.softShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _isRevisi
                  ? [
                      _chip('Perlu dicek', _totalPerluCek, AppTheme.warning),
                      _chip('Acc', _totalAcc, AppTheme.success),
                      _chip('Tolak', _totalReject, AppTheme.danger),
                    ]
                  : [
                      _chip('Dipotong', _totalDipotong, AppTheme.muted),
                      _chip('Dijahit', _totalDijahit, AppTheme.info),
                      _chip('Kurang', kurang, kurang > 0 ? AppTheme.danger : AppTheme.faint),
                      _chip('Acc', _totalAcc, AppTheme.success),
                      _chip('Tolak', _totalReject, AppTheme.danger),
                    ],
            ),
            if (!_isRevisi && kurang > 0) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.danger.withValues(alpha: 0.30)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, size: 18, color: AppTheme.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Penjahit kurang jahit $kurang pcs dari $_totalDipotong dipotong — tercatat di prestasi.',
                      style: const TextStyle(fontSize: 12, color: AppTheme.danger, fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Icon(Icons.check_rounded),
              label: const Text('Simpan Checking'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, int value, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$label ', style: const TextStyle(fontSize: 11.5, color: AppTheme.muted)),
          Text(angka(value), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        ]),
      );
}

// ─────────────────────────── TAB 2 — RIWAYAT ───────────────────────────
class _RiwayatTab extends StatefulWidget {
  const _RiwayatTab({super.key});
  @override
  State<_RiwayatTab> createState() => _RiwayatTabState();
}

class _RiwayatTabState extends State<_RiwayatTab> with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  String? _error;
  List<CheckingHistoryRow> _items = [];

  @override
  bool get wantKeepAlive => true;

  bool get _superadmin {
    final u = context.read<AuthProvider>().user;
    return u?.isAdmin == true || (u?.permissions.contains('*') ?? false);
  }

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await api.checkingHistory();
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

  Future<void> _confirmDelete(CheckingHistoryRow row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan checking?'),
        content: Text(
            'Batalkan checking ${row.no ?? '#${row.id}'}? Stok jadi ditarik balik & request balik ke antrian.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ya, batalkan'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.deleteChecking(row.id);
      if (mounted) toast(context, 'Checking dibatalkan.');
      await reload();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    }
  }

  Future<void> _openDetail(CheckingHistoryRow row) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _CheckingDetailPage(id: row.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Loading(label: 'Memuat riwayat…');
    if (_error != null) return ErrorView(_error!, onRetry: reload);
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: reload,
      child: _items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                EmptyView('Belum ada riwayat checking.', icon: Icons.history_rounded),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _historyCard(_items[i]),
            ),
    );
  }

  Widget _historyCard(CheckingHistoryRow r) {
    return SoftCard(
      onTap: () => _openDetail(r),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(r.no ?? '#${r.id}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.ink)),
                  const SizedBox(width: 8),
                  Text(tanggalID(r.tanggal), style: const TextStyle(fontSize: 12, color: AppTheme.faint)),
                ]),
                const SizedBox(height: 4),
                Text(
                  'Penjahit: ${r.penjahit ?? '-'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.muted),
                ),
                Text(
                  'Checker: ${r.checker ?? '-'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.muted),
                ),
                const SizedBox(height: 6),
                Wrap(spacing: 8, children: [
                  _tag('ACC ${angka(r.acc)}', AppTheme.success),
                  _tag('TOLAK ${angka(r.reject)}', AppTheme.danger),
                ]),
              ],
            ),
          ),
          if (_superadmin)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.faint),
              tooltip: 'Batalkan checking',
              onPressed: () => _confirmDelete(r),
            )
          else
            const Icon(Icons.chevron_right_rounded, color: AppTheme.faint),
        ],
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
      );
}

// ─────────────────────────── _CheckingDetailPage ───────────────────────────
class _CheckingDetailPage extends StatefulWidget {
  final int id;
  const _CheckingDetailPage({required this.id});
  @override
  State<_CheckingDetailPage> createState() => _CheckingDetailPageState();
}

class _CheckingDetailPageState extends State<_CheckingDetailPage> {
  bool _loading = true;
  String? _error;
  CheckingDetail? _d;

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
      final d = await api.checkingDetail(widget.id);
      if (!mounted) return;
      setState(() {
        _d = d;
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_d?.no ?? 'Detail Checking'),
        flexibleSpace: const DecoratedBox(decoration: BoxDecoration(gradient: AppTheme.brandGradient)),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Loading();
    if (_error != null) return ErrorView(_error!, onRetry: _load);
    final d = _d!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      children: [
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [d.potonganNo, d.produk].where((e) => e != null && e.isNotEmpty).join(' · ').ifEmptyDash(),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.ink),
              ),
              const SizedBox(height: 8),
              _infoRow(Icons.calendar_today_rounded, 'Tanggal', tanggalID(d.tanggal)),
              _infoRow(Icons.person_outline, 'Penjahit', d.penjahit ?? '-'),
              _infoRow(Icons.fact_check_outlined, 'Checker', d.checker ?? '-'),
              if (d.catatan != null && d.catatan!.isNotEmpty)
                _infoRow(Icons.notes_rounded, 'Catatan', d.catatan!),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionHeader('Rincian Item', icon: Icons.list_alt_rounded, color: AppTheme.info),
        const SizedBox(height: 10),
        SoftCard(
          padding: const EdgeInsets.all(10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _table(d),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 15, color: AppTheme.faint),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontSize: 13, color: AppTheme.muted)),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, color: AppTheme.ink, fontWeight: FontWeight.w600)),
          ),
        ]),
      );

  Widget _table(CheckingDetail d) {
    final headStyle = const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.muted);
    const cellStyle = TextStyle(fontSize: 12.5, color: AppTheme.ink);

    TableRow header() => TableRow(
          decoration: const BoxDecoration(color: AppTheme.soft),
          children: [
            _cell(Text('Roll', style: headStyle)),
            _cell(Text('Ukuran', style: headStyle)),
            _cell(Text('Dipotong', style: headStyle), right: true),
            _cell(Text('Dijahit', style: headStyle), right: true),
            _cell(Text('Kurang', style: headStyle), right: true),
            _cell(Text('Acc', style: headStyle), right: true),
            _cell(Text('Tolak', style: headStyle), right: true),
            _cell(Text('Gudang', style: headStyle)),
          ],
        );

    TableRow itemRow(CheckingItemDetail it) => TableRow(
          children: [
            _cell(Text(it.rollNo != null ? '#${it.rollNo}' : '-', style: cellStyle)),
            _cell(Text(it.ukuran ?? '-', style: cellStyle)),
            _cell(Text('${it.dipotong}', style: cellStyle), right: true),
            _cell(Text('${it.dijahit}', style: cellStyle), right: true),
            _cell(
                Text('${it.kurang}',
                    style: cellStyle.copyWith(
                        color: it.kurang > 0 ? AppTheme.danger : AppTheme.ink,
                        fontWeight: it.kurang > 0 ? FontWeight.w700 : FontWeight.w400)),
                right: true),
            _cell(Text('${it.acc}', style: cellStyle.copyWith(color: AppTheme.success, fontWeight: FontWeight.w700)),
                right: true),
            _cell(Text('${it.reject}', style: cellStyle.copyWith(color: AppTheme.danger, fontWeight: FontWeight.w700)),
                right: true),
            _cell(Text(it.gudang ?? '-', style: cellStyle)),
          ],
        );

    TableRow totalRow() {
      final ts = const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppTheme.ink);
      return TableRow(
        decoration: const BoxDecoration(
          color: AppTheme.soft,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        children: [
          _cell(Text('TOTAL', style: ts)),
          _cell(const SizedBox()),
          _cell(Text('${d.totalDipotong}', style: ts), right: true),
          _cell(Text('${d.totalDijahit}', style: ts), right: true),
          _cell(Text('${d.totalKurang}', style: ts.copyWith(color: d.totalKurang > 0 ? AppTheme.danger : AppTheme.ink)),
              right: true),
          _cell(Text('${d.totalAcc}', style: ts.copyWith(color: AppTheme.success)), right: true),
          _cell(Text('${d.totalReject}', style: ts.copyWith(color: AppTheme.danger)), right: true),
          _cell(const SizedBox()),
        ],
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 640),
      child: Table(
        border: TableBorder(horizontalInside: BorderSide(color: AppTheme.border.withValues(alpha: 0.7))),
        columnWidths: const {
          0: FixedColumnWidth(52),
          1: FixedColumnWidth(72),
          2: FixedColumnWidth(78),
          3: FixedColumnWidth(70),
          4: FixedColumnWidth(70),
          5: FixedColumnWidth(58),
          6: FixedColumnWidth(64),
          7: FixedColumnWidth(120),
        },
        children: [
          header(),
          ...d.items.map(itemRow),
          totalRow(),
        ],
      ),
    );
  }

  Widget _cell(Widget child, {bool right = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        child: Align(alignment: right ? Alignment.centerRight : Alignment.centerLeft, child: child),
      );
}

extension _StrDash on String {
  String ifEmptyDash() => trim().isEmpty ? '-' : this;
}
