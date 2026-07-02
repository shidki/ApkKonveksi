// Stok Opname = sesuaikan stok sistem ke hasil hitung fisik.
// Per ukuran: masukkan jumlah fisik, selisih dihitung live. Backend catat
// mutasi "opname" per baris yang selisihnya ≠ 0 dan set stok = fisik.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api.dart';
import '../models.dart';
import '../ui.dart';
import '../config.dart';
import 'pickers.dart';

class OpnameScreen extends StatefulWidget {
  const OpnameScreen({super.key});
  @override
  State<OpnameScreen> createState() => _OpnameScreenState();
}

class _OpnameRow {
  final String? ukuran;
  final int sistem;
  final TextEditingController fisik;
  _OpnameRow(this.ukuran, this.sistem) : fisik = TextEditingController(text: '$sistem');
}

class _OpnameScreenState extends State<OpnameScreen> {
  final _petugas = TextEditingController();
  final _ket = TextEditingController();

  List<Product> _products = [];
  List<Warehouse> _warehouses = [];
  Product? _selected;
  int? _gudangId;
  DateTime _tanggal = DateTime.now();
  final List<_OpnameRow> _rows = [];

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRefs();
  }

  @override
  void dispose() {
    _petugas.dispose();
    _ket.dispose();
    for (final r in _rows) {
      r.fisik.dispose();
    }
    super.dispose();
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

  void _buildRows(Product p) {
    for (final r in _rows) {
      r.fisik.dispose();
    }
    _rows.clear();
    if (p.pakaiVarian) {
      for (final v in p.variants) {
        _rows.add(_OpnameRow(v.ukuran, v.stok));
      }
    } else {
      _rows.add(_OpnameRow(null, p.stok));
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
    setState(() {
      _selected = p;
      _buildRows(p);
    });
  }

  Future<void> _submit() async {
    if (_gudangId == null) {
      toast(context, 'Pilih gudang dulu.', error: true);
      return;
    }
    if (_selected == null) {
      toast(context, 'Pilih produk dulu.', error: true);
      return;
    }
    final lines = _rows
        .map((r) => {'ukuran': r.ukuran, 'fisik': int.tryParse(r.fisik.text.trim()) ?? 0})
        .toList();
    final body = {
      'product_id': _selected!.id,
      'gudang_id': _gudangId,
      'tanggal': DateFormat('yyyy-MM-dd').format(_tanggal),
      'petugas': _petugas.text.trim().isEmpty ? null : _petugas.text.trim(),
      'keterangan': _ket.text.trim().isEmpty ? null : _ket.text.trim(),
      'lines': lines,
    };
    setState(() => _saving = true);
    try {
      final created = await api.opname(body);
      if (mounted) {
        toast(context, created == 0 ? 'Stok sudah cocok, tidak ada penyesuaian.' : 'Opname selesai: $created penyesuaian.');
        setState(() {
          _selected = null;
          _rows.clear();
          _ket.clear();
        });
        await _loadRefs();
      }
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok Opname'),
        flexibleSpace: const DecoratedBox(decoration: BoxDecoration(gradient: AppTheme.brandGradient)),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Loading();
    if (_error != null) return ErrorView(_error!, onRetry: _loadRefs);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader('Stok Opname', icon: Icons.fact_check_rounded, color: AppTheme.warning),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.only(left: 2),
                child: Text('Hitung fisik lalu sesuaikan stok sistem.',
                    style: TextStyle(color: AppTheme.muted, fontSize: 12.5)),
              ),
              const SizedBox(height: 18),
              LabeledField('Gudang *', _gudangSelector()),
              LabeledField('Produk *',
                  TapField(
                    value: _selected?.nama,
                    hint: _gudangId == null ? 'Pilih gudang dulu' : 'Ketuk untuk pilih produk',
                    leadingIcon: Icons.checkroom_rounded,
                    onTap: _chooseProduct,
                  )),
              LabeledField('Tanggal', _dateSelector()),
              if (_selected != null) ...[
                _opnameTable(),
                const SizedBox(height: 18),
              ],
              LabeledField('Petugas',
                  TextFormField(controller: _petugas, decoration: const InputDecoration(hintText: 'Opsional', prefixIcon: Icon(Icons.person_outline)))),
              LabeledField('Keterangan',
                  TextFormField(controller: _ket, maxLines: 2, decoration: const InputDecoration(hintText: 'Opsional'))),
              FilledButton.icon(
                onPressed: (_saving || _selected == null) ? null : _submit,
                icon: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Icon(Icons.save_rounded),
                label: const Text('Simpan Opname'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _gudangSelector() => DropdownButtonFormField<int?>(
        initialValue: _gudangId,
        isExpanded: true,
        borderRadius: BorderRadius.circular(14),
        decoration: const InputDecoration(prefixIcon: Icon(Icons.warehouse_outlined)),
        hint: const Text('Pilih gudang dulu', style: TextStyle(color: AppTheme.faint)),
        items: _warehouses
            .map((w) => DropdownMenuItem(value: w.id, child: Text(w.nama, overflow: TextOverflow.ellipsis)))
            .toList(),
        onChanged: (v) => setState(() {
          _gudangId = v;
          _selected = null; // gudang ganti → produk & tabel direset
          _rows.clear();
        }),
      );

  Widget _dateSelector() => TapField(
        value: DateFormat('d MMM yyyy', 'id_ID').format(_tanggal),
        hint: '',
        leadingIcon: Icons.calendar_today_rounded,
        trailingIcon: Icons.edit_calendar_outlined,
        onTap: () async {
          final d = await showDatePicker(context: context, initialDate: _tanggal, firstDate: DateTime(2020), lastDate: DateTime(2100));
          if (d != null) setState(() => _tanggal = d);
        },
      );

  Widget _opnameTable() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(color: AppTheme.soft),
            child: const Row(children: [
              Expanded(flex: 3, child: Text('Ukuran', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.muted))),
              Expanded(flex: 2, child: Text('Sistem', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.muted))),
              Expanded(flex: 3, child: Text('Fisik', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.muted))),
              Expanded(flex: 2, child: Text('Selisih', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.muted))),
            ]),
          ),
          for (int i = 0; i < _rows.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _opnameRowTile(_rows[i]),
          ],
        ],
      ),
    );
  }

  Widget _opnameRowTile(_OpnameRow r) {
    final fisik = int.tryParse(r.fisik.text.trim()) ?? 0;
    final selisih = fisik - r.sistem;
    final color = selisih == 0 ? AppTheme.muted : (selisih > 0 ? AppTheme.success : AppTheme.danger);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        Expanded(flex: 3, child: Text(r.ukuran ?? '(tanpa ukuran)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        Expanded(flex: 2, child: Text('${r.sistem}', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.muted))),
        Expanded(
          flex: 3,
          child: TextField(
            controller: r.fisik,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8)),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(selisih > 0 ? '+$selisih' : '$selisih',
              textAlign: TextAlign.center, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}
