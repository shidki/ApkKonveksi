// Produksi — POTONG (peran: tukang potong).
// Root tab-screen dengan 3 tab: Potongan, Bahan Masuk, Kartu Roll.
// Konsumsi backend produksi konveksi (production_router.py) via global `api`.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../auth.dart';
import '../models.dart';
import '../ui.dart';
import '../config.dart';

// ═══════════════════════════════════════════════════════════════════
// ROOT
// ═══════════════════════════════════════════════════════════════════
class PotongScreen extends StatelessWidget {
  const PotongScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return Scaffold(
      body: Column(
        children: [
          ModernHeader(title: 'Produksi — Potong', subtitle: auth.user?.nama),
          Expanded(
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  Container(
                    color: AppTheme.surface,
                    child: const TabBar(
                      labelColor: AppTheme.primary,
                      unselectedLabelColor: AppTheme.muted,
                      indicatorColor: AppTheme.primary,
                      indicatorWeight: 2.4,
                      labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
                      tabs: [
                        Tab(text: 'Potongan'),
                        Tab(text: 'Bahan Masuk'),
                        Tab(text: 'Kartu Roll'),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  const Expanded(
                    child: TabBarView(
                      children: [
                        _PotonganTab(),
                        _BahanMasukTab(),
                        _KartuRollTab(),
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

// small status pill for roll status
Widget _rollStatusPill(String status) {
  final (Color c, String label) = switch (status) {
    'available' => (AppTheme.success, 'Tersedia'),
    'dialokasi' => (AppTheme.info, 'Dialokasi'),
    'selesai' => (AppTheme.warning, 'Selesai'),
    'dicek' => (AppTheme.faint, 'Dicek'),
    _ => (AppTheme.muted, status),
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
  );
}

Widget _statChip(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: AppTheme.soft, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
      child: Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.ink)),
    );

Widget _reqChip(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
    );

// Alert ringkasan request jahit ke sebuah potongan (perlu ACC / diproses / ditolak).
List<Widget> _reqBadges(Potongan p) => [
      if (p.reqPending > 0) _reqChip('⏳ ${p.reqPending} perlu ACC', AppTheme.warning),
      if (p.reqDiproses > 0) _reqChip('✓ ${p.reqDiproses} diproses', AppTheme.info),
      if (p.reqReject > 0) _reqChip('✕ ${p.reqReject} ditolak', AppTheme.danger),
    ];

// ═══════════════════════════════════════════════════════════════════
// TAB 1 — POTONGAN
// ═══════════════════════════════════════════════════════════════════
class _PotonganTab extends StatefulWidget {
  const _PotonganTab();
  @override
  State<_PotonganTab> createState() => _PotonganTabState();
}

class _PotonganTabState extends State<_PotonganTab> {
  bool _loading = true;
  String? _error;
  List<Potongan> _items = [];

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
      final data = await api.potongan();
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

  Future<void> _openForm() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const _PotonganFormPage()),
    );
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final canCreate = auth.can('pm.potongan.create');
    return Scaffold(
      backgroundColor: AppTheme.bg,
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _openForm,
              icon: const Icon(Icons.content_cut_rounded),
              label: const Text('Potongan Baru'),
            )
          : null,
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Loading();
    if (_error != null) return ErrorView(_error!, onRetry: _load);
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: const [SizedBox(height: 120), EmptyView('Belum ada potongan.', icon: Icons.content_cut_outlined)]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _card(_items[i]),
      ),
    );
  }

  Widget _card(Potongan p) => SoftCard(
        onTap: () async {
          final changed = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => _PotonganDetailPage(id: p.id)),
          );
          if (changed == true) _load();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(p.no ?? 'Potongan #${p.id}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.ink)),
                ),
                Text(tanggalID(p.tanggal), style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
              ],
            ),
            const SizedBox(height: 4),
            Text(p.produk ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, color: AppTheme.ink, fontWeight: FontWeight.w600)),
            if (p.tukang != null && p.tukang!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(p.tukang!, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
            ],
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _statChip('Roll ${angka(p.rollAvailable)}/${angka(p.totalRoll)}'),
              _statChip('Sisa pcs ${angka(p.pcsAvailable)}/${angka(p.totalPcs)}'),
            ]),
            ..._rollProgress(p),
            if (p.reqPending > 0 || p.reqDiproses > 0 || p.reqReject > 0) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: _reqBadges(p)),
            ],
          ],
        ),
      );
}

// Ringkasan progres roll pada sebuah potongan: berapa selesai & berapa perlu
// perbaikan. Roll berstatus 'dicek' = selesai lolos QC; 'selesai' = tuntas dijahit.
List<Widget> _rollProgress(Potongan p) {
  if (p.rolls.isEmpty && p.reqReject <= 0) return const [];
  final selesai = p.rolls.where((r) => r.status == 'dicek' || r.status == 'selesai').length;
  final perbaikan = p.reqReject;
  final chips = <Widget>[
    if (p.rolls.isNotEmpty) _reqChip('✔ $selesai/${p.totalRoll} roll selesai', AppTheme.success),
    if (perbaikan > 0) _reqChip('🔧 $perbaikan perlu perbaikan', AppTheme.warning),
  ];
  if (chips.isEmpty) return const [];
  return [
    const SizedBox(height: 8),
    Wrap(spacing: 8, runSpacing: 8, children: chips),
  ];
}

// ═══════════════════════════════════════════════════════════════════
// TAB 2 — BAHAN MASUK
// ═══════════════════════════════════════════════════════════════════
class _BahanMasukTab extends StatefulWidget {
  const _BahanMasukTab();
  @override
  State<_BahanMasukTab> createState() => _BahanMasukTabState();
}

class _BahanMasukTabState extends State<_BahanMasukTab> {
  bool _loading = true;
  String? _error;
  List<BahanMasuk> _items = [];

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
      final data = await api.bahanMasuk();
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

  Future<void> _openForm() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const _BahanMasukFormPage()),
    );
    if (ok == true) _load();
  }

  Future<void> _delete(BahanMasuk b) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus bahan masuk?'),
        content: Text('Catatan tanggal ${tanggalID(b.tanggal)}${b.tukang != null ? ' — ${b.tukang}' : ''} akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger, minimumSize: const Size(88, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await api.deleteBahanMasuk(b.id);
      if (mounted) toast(context, 'Bahan masuk dihapus.');
      _load();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final canCreate = auth.can('pm.bahan_masuk.create');
    return Scaffold(
      backgroundColor: AppTheme.bg,
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _openForm,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Catat Bahan Masuk'),
            )
          : null,
      body: _body(canDelete: auth.can('pm.bahan_masuk.delete')),
    );
  }

  Widget _body({required bool canDelete}) {
    if (_loading) return const Loading();
    if (_error != null) return ErrorView(_error!, onRetry: _load);
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: const [SizedBox(height: 120), EmptyView('Belum ada bahan masuk.', icon: Icons.inventory_2_outlined)]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _card(_items[i], canDelete),
      ),
    );
  }

  Widget _card(BahanMasuk b, bool canDelete) => SoftCard(
        onTap: canDelete ? null : () {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tanggalID(b.tanggal),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.ink)),
                    if (b.tukang != null && b.tukang!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(b.tukang!, style: const TextStyle(fontSize: 12.5, color: AppTheme.muted)),
                    ],
                  ]),
                ),
                if (canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.faint),
                    onPressed: () => _delete(b),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (b.items.isEmpty)
              const Text('Tidak ada item.', style: TextStyle(fontSize: 12.5, color: AppTheme.faint))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: b.items
                    .map((it) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('${it.warna ?? it.nama ?? '-'}: ${angka(it.jumlahRoll)}',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.primaryDark)),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 10),
            Text('Total ${angka(b.totalRoll)} roll',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink)),
          ],
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════
// TAB 3 — KARTU ROLL
// ═══════════════════════════════════════════════════════════════════
class _KartuRollTab extends StatefulWidget {
  const _KartuRollTab();
  @override
  State<_KartuRollTab> createState() => _KartuRollTabState();
}

class _KartuRollTabState extends State<_KartuRollTab> {
  bool _loading = true;
  String? _error;
  List<KartuRoll> _items = [];

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
      final data = await api.kartuRoll();
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
    if (_loading) return const Loading();
    if (_error != null) return ErrorView(_error!, onRetry: _load);
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: const [SizedBox(height: 120), EmptyView('Belum ada kartu roll.', icon: Icons.style_outlined)]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
            ),
            child: Row(children: const [
              Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.info),
              SizedBox(width: 8),
              Expanded(child: Text('masuk − kepakai potong = sisa', style: TextStyle(fontSize: 12.5, color: AppTheme.info, fontWeight: FontWeight.w600))),
            ]),
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < _items.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _card(_items[i]),
          ],
        ],
      ),
    );
  }

  Widget _card(KartuRoll k) {
    final habis = k.sisa <= 0;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(k.warna, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.ink)),
                if (k.tukang != null && k.tukang!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(k.tukang!, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
                ],
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _rollStat('Masuk', k.masuk, AppTheme.success),
            _rollStat('Keluar', k.keluar, AppTheme.danger),
            _rollStat('Sisa', k.sisa, habis ? AppTheme.danger : AppTheme.ink, bold: true),
          ]),
        ],
      ),
    );
  }

  Widget _rollStat(String label, int value, Color color, {bool bold = false}) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppTheme.muted)),
          const SizedBox(height: 2),
          Text(angka(value),
              style: TextStyle(fontSize: bold ? 20 : 17, fontWeight: bold ? FontWeight.w800 : FontWeight.w700, color: color)),
        ]),
      );
}

// ═══════════════════════════════════════════════════════════════════
// FORM — CATAT BAHAN MASUK
// ═══════════════════════════════════════════════════════════════════
class _BahanRow {
  final TextEditingController warna = TextEditingController();
  final TextEditingController jumlah = TextEditingController();
}

class _BahanMasukFormPage extends StatefulWidget {
  const _BahanMasukFormPage();
  @override
  State<_BahanMasukFormPage> createState() => _BahanMasukFormPageState();
}

class _BahanMasukFormPageState extends State<_BahanMasukFormPage> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<Tukang> _tukang = [];
  int? _tukangId;
  DateTime _tanggal = DateTime.now();
  final TextEditingController _catatan = TextEditingController();
  final List<_BahanRow> _rows = [_BahanRow()];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _catatan.dispose();
    for (final r in _rows) {
      r.warna.dispose();
      r.jumlah.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await api.tukang(peran: 'potong');
      if (!mounted) return;
      setState(() {
        _tukang = list;
        if (list.length == 1) _tukangId = list.first.id;
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

  void _addRow() => setState(() => _rows.add(_BahanRow()));

  void _removeRow(int i) {
    if (_rows.length == 1) return;
    final r = _rows.removeAt(i);
    r.warna.dispose();
    r.jumlah.dispose();
    setState(() {});
  }

  Future<void> _submit() async {
    if (_tukangId == null) {
      toast(context, 'Pilih tukang potong dulu.', error: true);
      return;
    }
    final items = <Map<String, dynamic>>[];
    for (final r in _rows) {
      final warna = r.warna.text.trim();
      final jml = int.tryParse(r.jumlah.text.trim()) ?? 0;
      if (warna.isEmpty || jml <= 0) continue;
      items.add({'warna': warna, 'nama': warna, 'jumlah_roll': jml});
    }
    if (items.isEmpty) {
      toast(context, 'Isi minimal 1 baris dengan warna & jumlah > 0.', error: true);
      return;
    }
    final body = {
      'tanggal': DateFormat('yyyy-MM-dd').format(_tanggal),
      'tukang_id': _tukangId,
      'catatan': _catatan.text.trim().isEmpty ? null : _catatan.text.trim(),
      'items': items,
    };
    setState(() => _saving = true);
    try {
      await api.createBahanMasuk(body);
      if (!mounted) return;
      toast(context, 'Bahan masuk dicatat.');
      Navigator.pop(context, true);
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
        title: const Text('Catat Bahan Masuk'),
        flexibleSpace: const DecoratedBox(decoration: BoxDecoration(gradient: AppTheme.brandGradient)),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Loading();
    if (_error != null) return ErrorView(_error!, onRetry: _load);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      children: [
        SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader('Informasi', icon: Icons.info_outline_rounded),
            const SizedBox(height: 18),
            LabeledField('Tukang Potong *', _tukangSelector()),
            LabeledField('Tanggal', _dateSelector()),
            LabeledField('Catatan',
                TextField(controller: _catatan, maxLines: 2, decoration: const InputDecoration(hintText: 'Opsional'))),
          ]),
        ),
        const SizedBox(height: 18),
        SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader('Bahan (per warna)', icon: Icons.palette_outlined, color: AppTheme.info),
            const SizedBox(height: 8),
            for (int i = 0; i < _rows.length; i++) _bahanRow(i),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _addRow,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Tambah Baris'),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Icon(Icons.check_rounded),
          label: const Text('Simpan Bahan Masuk'),
        ),
      ],
    );
  }

  Widget _bahanRow(int i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _rows[i].warna,
              decoration: const InputDecoration(hintText: 'Warna', isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _rows[i].jumlah,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Roll', isDense: true),
            ),
          ),
          IconButton(
            icon: Icon(Icons.remove_circle_outline_rounded,
                size: 22, color: _rows.length == 1 ? AppTheme.faint.withValues(alpha: 0.4) : AppTheme.danger),
            onPressed: _rows.length == 1 ? null : () => _removeRow(i),
          ),
        ]),
      );

  Widget _tukangSelector() => DropdownButtonFormField<int>(
        initialValue: _tukangId,
        isExpanded: true,
        borderRadius: BorderRadius.circular(14),
        decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline_rounded)),
        hint: const Text('Pilih tukang potong', style: TextStyle(color: AppTheme.faint)),
        items: _tukang.map((t) => DropdownMenuItem(value: t.id, child: Text(t.nama, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (v) => setState(() => _tukangId = v),
      );

  Widget _dateSelector() => TapField(
        value: DateFormat('d MMM yyyy', 'id_ID').format(_tanggal),
        hint: '',
        leadingIcon: Icons.calendar_today_rounded,
        trailingIcon: Icons.edit_calendar_outlined,
        onTap: () async {
          final d = await showDatePicker(
              context: context, initialDate: _tanggal, firstDate: DateTime(2020), lastDate: DateTime(2100));
          if (d != null) setState(() => _tanggal = d);
        },
      );
}

// ═══════════════════════════════════════════════════════════════════
// FORM — BUAT POTONGAN
// ═══════════════════════════════════════════════════════════════════
class _SizeInput {
  final String ukuran;
  final bool readonly; // true bila dari variant produk
  final TextEditingController pcs = TextEditingController();
  final TextEditingController yard = TextEditingController();
  final TextEditingController ukuranCtl;
  _SizeInput({required this.ukuran, this.readonly = false}) : ukuranCtl = TextEditingController(text: ukuran);
  void dispose() {
    pcs.dispose();
    yard.dispose();
    ukuranCtl.dispose();
  }
}

class _RollInput {
  String? warna;
  final List<_SizeInput> sizes;
  _RollInput({required this.sizes});
  void dispose() {
    for (final s in sizes) {
      s.dispose();
    }
  }
}

class _PotonganFormPage extends StatefulWidget {
  const _PotonganFormPage();
  @override
  State<_PotonganFormPage> createState() => _PotonganFormPageState();
}

class _PotonganFormPageState extends State<_PotonganFormPage> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<Tukang> _tukang = [];
  List<ProductLite> _products = [];
  int? _tukangId;
  ProductLite? _product;
  DateTime _tanggal = DateTime.now();

  List<KartuRoll> _kartu = [];
  bool _loadingKartu = false;

  final List<_RollInput> _rolls = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final r in _rolls) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([api.tukang(peran: 'potong'), api.products()]);
      if (!mounted) return;
      setState(() {
        _tukang = results[0] as List<Tukang>;
        _products = results[1] as List<ProductLite>;
        if (_tukang.length == 1) _tukangId = _tukang.first.id;
        _loading = false;
      });
      _maybeLoadKartu();
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

  Future<void> _maybeLoadKartu() async {
    if (_tukangId == null) return;
    setState(() => _loadingKartu = true);
    try {
      final data = await api.kartuRoll(tukangId: _tukangId);
      if (!mounted) return;
      setState(() {
        _kartu = data;
        _loadingKartu = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _kartu = [];
        _loadingKartu = false;
      });
    }
  }

  List<_SizeInput> _seedSizes() {
    final p = _product;
    if (p == null || p.variants.isEmpty) {
      return [_SizeInput(ukuran: '', readonly: false)];
    }
    return p.variants.map((v) => _SizeInput(ukuran: v.ukuran, readonly: true)).toList();
  }

  void _onProductChanged(ProductLite? p) {
    setState(() {
      _product = p;
      for (final r in _rolls) {
        r.dispose();
      }
      _rolls.clear();
      if (p != null) _rolls.add(_RollInput(sizes: _seedSizes()));
    });
  }

  void _addRoll() {
    if (_product == null) {
      toast(context, 'Pilih produk dulu.', error: true);
      return;
    }
    setState(() => _rolls.add(_RollInput(sizes: _seedSizes())));
  }

  void _removeRoll(int i) {
    final r = _rolls.removeAt(i);
    r.dispose();
    setState(() {});
  }

  Future<void> _submit() async {
    if (_tukangId == null) {
      toast(context, 'Pilih tukang potong dulu.', error: true);
      return;
    }
    if (_product == null) {
      toast(context, 'Pilih produk dulu.', error: true);
      return;
    }
    if (_rolls.isEmpty) {
      toast(context, 'Tambah minimal 1 roll.', error: true);
      return;
    }
    final rollsBody = <Map<String, dynamic>>[];
    for (int i = 0; i < _rolls.length; i++) {
      final r = _rolls[i];
      if (r.warna == null || r.warna!.isEmpty) {
        toast(context, 'Roll #${i + 1}: pilih warna dulu.', error: true);
        return;
      }
      final sizes = <Map<String, dynamic>>[];
      bool anyPcs = false;
      for (final s in r.sizes) {
        final uk = (s.readonly ? s.ukuran : s.ukuranCtl.text.trim());
        final pcs = int.tryParse(s.pcs.text.trim()) ?? 0;
        final yard = num.tryParse(s.yard.text.trim().replaceAll(',', '.')) ?? 0;
        if (uk.isEmpty && pcs <= 0) continue;
        if (pcs > 0) anyPcs = true;
        sizes.add({'ukuran': uk, 'pcs_potong': pcs, 'yard': yard});
      }
      if (!anyPcs) {
        toast(context, 'Roll #${i + 1}: isi minimal 1 ukuran dengan pcs > 0.', error: true);
        return;
      }
      rollsBody.add({'no_roll': i + 1, 'warna': r.warna, 'sizes': sizes});
    }
    final body = {
      'tanggal': DateFormat('yyyy-MM-dd').format(_tanggal),
      'tukang_id': _tukangId,
      'product_id': _product!.id,
      'catatan': null,
      'rolls': rollsBody,
    };
    setState(() => _saving = true);
    try {
      await api.createPotongan(body);
      if (!mounted) return;
      toast(context, 'Potongan dibuat.');
      Navigator.pop(context, true);
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
        title: const Text('Buat Potongan'),
        flexibleSpace: const DecoratedBox(decoration: BoxDecoration(gradient: AppTheme.brandGradient)),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Loading();
    if (_error != null) return ErrorView(_error!, onRetry: _load);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      children: [
        SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader('Informasi', icon: Icons.info_outline_rounded),
            const SizedBox(height: 18),
            LabeledField('Tukang Potong *', _tukangSelector()),
            LabeledField('Produk *', _productSelector()),
            LabeledField('Tanggal', _dateSelector()),
          ]),
        ),
        const SizedBox(height: 18),
        if (_product == null)
          const SoftCard(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(child: Text('Pilih produk dulu untuk mengisi roll.', style: TextStyle(color: AppTheme.muted))),
            ),
          )
        else ...[
          for (int i = 0; i < _rolls.length; i++) ...[
            _rollCard(i),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: _addRoll,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Tambah Roll'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Icon(Icons.check_rounded),
            label: const Text('Simpan Potongan'),
          ),
        ],
      ],
    );
  }

  Widget _rollCard(int i) {
    final r = _rolls[i];
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Text('Roll #${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryDark, fontSize: 13)),
          ),
          const Spacer(),
          if (_rolls.length > 1)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.danger),
              onPressed: () => _removeRoll(i),
            ),
        ]),
        const SizedBox(height: 12),
        _warnaSelector(r),
        const SizedBox(height: 14),
        Row(children: const [
          Expanded(flex: 3, child: Text('Ukuran', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.muted))),
          SizedBox(width: 8),
          Expanded(flex: 2, child: Text('Pcs', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.muted))),
          SizedBox(width: 8),
          Expanded(flex: 2, child: Text('Yard', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.muted))),
        ]),
        const SizedBox(height: 6),
        for (final s in r.sizes) _sizeRow(s),
      ]),
    );
  }

  Widget _sizeRow(_SizeInput s) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(
            flex: 3,
            child: s.readonly
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                    decoration: BoxDecoration(color: AppTheme.soft, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
                    child: Text(s.ukuran.isEmpty ? '-' : s.ukuran,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.ink)),
                  )
                : TextField(
                    controller: s.ukuranCtl,
                    decoration: const InputDecoration(hintText: 'Ukuran', isDense: true),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: s.pcs,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: '0', isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: s.yard,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: '0', isDense: true),
            ),
          ),
        ]),
      );

  Widget _warnaSelector(_RollInput r) {
    if (_loadingKartu) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Loading());
    }
    if (_kartu.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
        child: const Text('Tidak ada stok roll untuk tukang ini. Catat bahan masuk dulu.',
            style: TextStyle(fontSize: 12.5, color: AppTheme.warning, fontWeight: FontWeight.w600)),
      );
    }
    // ensure current value still valid
    final warnaList = _kartu.map((k) => k.warna).toList();
    final current = (r.warna != null && warnaList.contains(r.warna)) ? r.warna : null;
    return DropdownButtonFormField<String>(
      initialValue: current,
      isExpanded: true,
      borderRadius: BorderRadius.circular(14),
      decoration: const InputDecoration(prefixIcon: Icon(Icons.palette_outlined)),
      hint: const Text('Pilih warna', style: TextStyle(color: AppTheme.faint)),
      items: _kartu
          .map((k) => DropdownMenuItem(value: k.warna, child: Text('${k.warna} · sisa ${angka(k.sisa)}', overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: (v) => setState(() => r.warna = v),
    );
  }

  Widget _tukangSelector() => DropdownButtonFormField<int>(
        initialValue: _tukangId,
        isExpanded: true,
        borderRadius: BorderRadius.circular(14),
        decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline_rounded)),
        hint: const Text('Pilih tukang potong', style: TextStyle(color: AppTheme.faint)),
        items: _tukang.map((t) => DropdownMenuItem(value: t.id, child: Text(t.nama, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (v) {
          setState(() => _tukangId = v);
          _maybeLoadKartu();
        },
      );

  Widget _productSelector() => DropdownButtonFormField<int>(
        initialValue: _product?.id,
        isExpanded: true,
        borderRadius: BorderRadius.circular(14),
        decoration: const InputDecoration(prefixIcon: Icon(Icons.checkroom_rounded)),
        hint: const Text('Pilih produk', style: TextStyle(color: AppTheme.faint)),
        items: _products
            .map((p) => DropdownMenuItem(value: p.id, child: Text('${p.nama} (${p.sku})', overflow: TextOverflow.ellipsis)))
            .toList(),
        onChanged: (v) => _onProductChanged(v == null ? null : _products.firstWhere((p) => p.id == v)),
      );

  Widget _dateSelector() => TapField(
        value: DateFormat('d MMM yyyy', 'id_ID').format(_tanggal),
        hint: '',
        leadingIcon: Icons.calendar_today_rounded,
        trailingIcon: Icons.edit_calendar_outlined,
        onTap: () async {
          final d = await showDatePicker(
              context: context, initialDate: _tanggal, firstDate: DateTime(2020), lastDate: DateTime(2100));
          if (d != null) setState(() => _tanggal = d);
        },
      );
}

// ═══════════════════════════════════════════════════════════════════
// DETAIL — POTONGAN
// ═══════════════════════════════════════════════════════════════════
class _PotonganDetailPage extends StatefulWidget {
  final int id;
  const _PotonganDetailPage({required this.id});
  @override
  State<_PotonganDetailPage> createState() => _PotonganDetailPageState();
}

class _PotonganDetailPageState extends State<_PotonganDetailPage> {
  bool _loading = true;
  String? _error;
  Potongan? _p;
  List<JahitRequest> _requests = [];
  bool _dirty = false; // apakah ada perubahan → beritahu list

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
        api.potonganDetail(widget.id),
        api.jahitRequests(potonganId: widget.id),
      ]);
      if (!mounted) return;
      setState(() {
        _p = results[0] as Potongan;
        _requests = results[1] as List<JahitRequest>;
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

  Future<void> _accDialog(JahitRequest req) async {
    final p = _p;
    if (p == null) return;
    final available = p.rolls.where((r) => r.status == 'available').toList();
    if (available.isEmpty) {
      toast(context, 'Tidak ada roll tersedia untuk dialokasi.', error: true);
      return;
    }
    final selected = <int>{};
    final ids = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ACC + Alokasi Roll',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.ink)),
              const SizedBox(height: 4),
              Text('Pilih roll tersedia untuk dialokasikan ke ${req.penjahit ?? 'penjahit'}.',
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.muted)),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: available.map((roll) {
                      final checked = selected.contains(roll.id);
                      final sizeLabel = roll.sizes.map((s) => '${s.ukuran}:${s.pcsPotong}').join(', ');
                      return CheckboxListTile(
                        value: checked,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: AppTheme.primary,
                        title: Text('Roll #${roll.noRoll}${roll.warna != null ? ' · ${roll.warna}' : ''}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        subtitle: Text('${roll.pcs} pcs${sizeLabel.isEmpty ? '' : ' — $sizeLabel'}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
                        onChanged: (v) => setSheet(() {
                          if (v == true) {
                            selected.add(roll.id);
                          } else {
                            selected.remove(roll.id);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: selected.isEmpty ? null : () => Navigator.pop(ctx, selected.toList()),
                icon: const Icon(Icons.check_rounded),
                label: Text('ACC ${selected.length} roll'),
              ),
            ]),
          ),
        ),
      ),
    );
    if (ids == null || ids.isEmpty) return;
    try {
      await api.accJahit(req.id, ids);
      _dirty = true;
      if (mounted) toast(context, 'Ajuan di-ACC, roll dialokasi.');
      _load();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> _rejectDialog(JahitRequest req) async {
    final ctl = TextEditingController();
    final alasan = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tolak ajuan jahit'),
        content: TextField(
          controller: ctl,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Alasan (opsional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger, minimumSize: const Size(88, 44)),
            onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (alasan == null) return; // dibatalkan
    try {
      await api.rejectJahit(req.id, alasan.isEmpty ? null : alasan);
      _dirty = true;
      if (mounted) toast(context, 'Ajuan ditolak.');
      _load();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        appBar: AppBar(
          title: Text(_p?.no ?? 'Detail Potongan'),
          flexibleSpace: const DecoratedBox(decoration: BoxDecoration(gradient: AppTheme.brandGradient)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context, _dirty),
          ),
        ),
        body: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Loading();
    if (_error != null) return ErrorView(_error!, onRetry: _load);
    final p = _p;
    if (p == null) return const EmptyView('Potongan tidak ditemukan.');
    final auth = context.read<AuthProvider>();
    final canUpdate = auth.can('pm.potongan.update');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          _headerCard(p),
          const SizedBox(height: 18),
          SectionHeader('Roll & Breakdown', icon: Icons.grid_view_rounded),
          const SizedBox(height: 10),
          if (p.rolls.isEmpty)
            const SoftCard(child: Center(child: Padding(padding: EdgeInsets.all(10), child: Text('Belum ada roll.', style: TextStyle(color: AppTheme.muted)))))
          else
            for (final roll in p.rolls) ...[
              _rollCard(roll),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 12),
          SectionHeader('Ajuan Jahit', icon: Icons.send_rounded, color: AppTheme.info),
          const SizedBox(height: 10),
          if (_requests.isEmpty)
            const SoftCard(child: Center(child: Padding(padding: EdgeInsets.all(10), child: Text('Belum ada ajuan jahit.', style: TextStyle(color: AppTheme.muted)))))
          else
            for (final req in _requests) ...[
              _requestCard(req, canUpdate),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _headerCard(Potongan p) => SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.produk ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.ink)),
          const SizedBox(height: 4),
          Wrap(spacing: 8, runSpacing: 4, children: [
            if (p.sku != null && p.sku!.isNotEmpty) Text('SKU ${p.sku}', style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
            Text(tanggalID(p.tanggal), style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
            if (p.tukang != null && p.tukang!.isNotEmpty) Text('· ${p.tukang}', style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _statChip('Roll ${angka(p.rollAvailable)}/${angka(p.totalRoll)}'),
            _statChip('Sisa pcs ${angka(p.pcsAvailable)}/${angka(p.totalPcs)}'),
          ]),
        ]),
      );

  Widget _rollCard(PotonganRoll roll) => SoftCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('#${roll.noRoll}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.ink)),
            const SizedBox(width: 8),
            if (roll.warna != null && roll.warna!.isNotEmpty)
              Text(roll.warna!, style: const TextStyle(fontSize: 13, color: AppTheme.muted, fontWeight: FontWeight.w600)),
            const Spacer(),
            _rollStatusPill(roll.status),
          ]),
          const SizedBox(height: 10),
          if (roll.sizes.isEmpty)
            const Text('Tidak ada breakdown.', style: TextStyle(fontSize: 12, color: AppTheme.faint))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: roll.sizes
                  .map((s) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: AppTheme.soft, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
                        child: Text('${s.ukuran}: ${angka(s.pcsPotong)}',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.ink)),
                      ))
                  .toList(),
            ),
        ]),
      );

  Widget _requestCard(JahitRequest req, bool canUpdate) {
    final label = jahitStatusLabel[req.status] ?? req.status;
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(req.penjahit ?? 'Penjahit #${req.tukangId}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppTheme.ink)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: AppTheme.info.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.info)),
          ),
        ]),
        const SizedBox(height: 6),
        Text('${angka(req.nRoll)} roll · ${angka(req.pcs)} pcs', style: const TextStyle(fontSize: 12.5, color: AppTheme.muted)),
        if (req.alasanReject != null && req.alasanReject!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Alasan: ${req.alasanReject}', style: const TextStyle(fontSize: 12, color: AppTheme.danger)),
        ],
        if (req.status == 'pending' && canUpdate) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _accDialog(req),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('ACC + alokasi'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _rejectDialog(req),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Tolak'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.danger,
                  side: const BorderSide(color: AppTheme.danger),
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}
