// Penerimaan Stok = barang MASUK. Catat mutasi tipe "masuk" → stok nambah
// (per ukuran kalau produk pakai varian). Bawahnya daftar penerimaan terakhir.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api.dart';
import '../models.dart';
import '../ui.dart';
import '../config.dart';
import 'pickers.dart';

class PenerimaanScreen extends StatefulWidget {
  const PenerimaanScreen({super.key});
  @override
  State<PenerimaanScreen> createState() => _PenerimaanScreenState();
}

class _PenerimaanScreenState extends State<PenerimaanScreen> {
  final _qty = TextEditingController();
  final _petugas = TextEditingController();
  final _ket = TextEditingController();

  List<Product> _products = [];
  List<Warehouse> _warehouses = [];
  Product? _selected;
  String? _ukuran;
  int? _gudangId;
  DateTime _tanggal = DateTime.now();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  Future<List<StockMove>>? _movesFuture;

  @override
  void initState() {
    super.initState();
    _loadRefs();
  }

  @override
  void dispose() {
    _qty.dispose();
    _petugas.dispose();
    _ket.dispose();
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
      _reloadMoves();
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _reloadMoves() => setState(() => _movesFuture = api.moves(tipe: 'masuk'));

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
      _ukuran = null;
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
    final qty = int.tryParse(_qty.text.trim()) ?? 0;
    if (qty <= 0) {
      toast(context, 'Jumlah harus lebih dari 0.', error: true);
      return;
    }
    if (_selected!.pakaiVarian && (_ukuran == null || _ukuran!.isEmpty)) {
      toast(context, 'Produk ini pakai ukuran — pilih ukuran dulu.', error: true);
      return;
    }
    final body = {
      'tanggal': DateFormat('yyyy-MM-dd').format(_tanggal),
      'tipe': 'masuk',
      'product_id': _selected!.id,
      'ukuran': _ukuran,
      'qty': qty,
      'gudang_id': _gudangId,
      'petugas': _petugas.text.trim().isEmpty ? null : _petugas.text.trim(),
      'keterangan': _ket.text.trim().isEmpty ? null : _ket.text.trim(),
    };
    setState(() => _saving = true);
    try {
      await api.createMove(body);
      if (mounted) {
        toast(context, 'Penerimaan dicatat, stok bertambah.');
        setState(() {
          _selected = null;
          _ukuran = null;
          _qty.clear();
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

  Future<void> _deleteMove(StockMove m) async {
    try {
      await api.deleteMove(m.id);
      if (mounted) toast(context, 'Penerimaan dibatalkan, stok dikembalikan.');
      await _loadRefs();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Penerimaan Stok'),
        flexibleSpace: const DecoratedBox(decoration: BoxDecoration(gradient: AppTheme.brandGradient)),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Loading();
    if (_error != null) return ErrorView(_error!, onRetry: _loadRefs);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      children: [
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader('Catat Barang Masuk', icon: Icons.download_rounded, color: AppTheme.success),
              const SizedBox(height: 18),
              LabeledField('Gudang *', _gudangSelector()),
              LabeledField('Produk *',
                  TapField(
                    value: _selected?.nama,
                    hint: _gudangId == null ? 'Pilih gudang dulu' : 'Ketuk untuk pilih produk',
                    leadingIcon: Icons.checkroom_rounded,
                    onTap: _chooseProduct,
                  )),
              if (_selected != null && _selected!.pakaiVarian)
                LabeledField('Ukuran *',
                    TapField(
                      value: _ukuran,
                      hint: 'Pilih ukuran',
                      leadingIcon: Icons.straighten_rounded,
                      onTap: () async {
                        final u = await pickUkuran(context, _selected!);
                        if (u != null) setState(() => _ukuran = u);
                      },
                    )),
              Row(children: [
                Expanded(
                    child: LabeledField('Jumlah *',
                        TextFormField(
                          controller: _qty,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: '0', prefixIcon: Icon(Icons.add_box_outlined)),
                        ))),
                const SizedBox(width: 12),
                Expanded(child: LabeledField('Tanggal', _dateSelector())),
              ]),
              LabeledField('Petugas',
                  TextFormField(controller: _petugas, decoration: const InputDecoration(hintText: 'Opsional', prefixIcon: Icon(Icons.person_outline)))),
              LabeledField('Keterangan',
                  TextFormField(controller: _ket, maxLines: 2, decoration: const InputDecoration(hintText: 'Opsional'))),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Icon(Icons.check_rounded),
                label: const Text('Catat Penerimaan'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        SectionHeader('Penerimaan Terakhir', icon: Icons.history_rounded),
        const SizedBox(height: 10),
        _movesList(),
        const SizedBox(height: 8),
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
          _selected = null; // gudang ganti → produk direset
          _ukuran = null;
        }),
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

  Widget _movesList() => FutureBuilder<List<StockMove>>(
        future: _movesFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(padding: EdgeInsets.all(20), child: Loading());
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return SoftCard(padding: const EdgeInsets.all(20), child: const Center(child: Text('Belum ada penerimaan.', style: TextStyle(color: AppTheme.muted))));
          }
          return SoftCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (int i = 0; i < items.take(30).length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 66),
                _moveTile(items[i]),
              ],
            ]),
          );
        },
      );

  Widget _moveTile(StockMove m) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(children: [
          const MoveAvatar('masuk'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.item ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 2),
              Text(
                  [m.refNo ?? '', tanggalID(m.tanggal), if (m.ukuran != null && m.ukuran!.isNotEmpty) 'uk ${m.ukuran}']
                      .where((e) => e.isNotEmpty).join(' · '),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.muted)),
            ]),
          ),
          Text('+${angka(m.qty)}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.success, fontSize: 14)),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.faint),
            onPressed: () => _deleteMove(m),
          ),
        ]),
      );
}
