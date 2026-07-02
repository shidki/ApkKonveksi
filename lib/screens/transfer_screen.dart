// Transfer Gudang = pindahkan stok dari gudang asal ke gudang tujuan.
// Produk difilter per gudang asal. Backend kurangi stok asal & tambah di tujuan
// (bikin baris produk baru di tujuan kalau belum ada).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api.dart';
import '../models.dart';
import '../ui.dart';
import '../config.dart';
import 'pickers.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});
  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _qty = TextEditingController();
  final _petugas = TextEditingController();

  List<Product> _products = [];
  List<Warehouse> _warehouses = [];
  int? _asalId;
  int? _tujuanId;
  Product? _selected;
  String? _ukuran;
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

  void _reloadMoves() => setState(() => _movesFuture = api.moves(tipe: 'transfer'));

  List<Product> get _produkAsal =>
      _asalId == null ? [] : _products.where((p) => p.gudangId == _asalId).toList();

  Future<void> _chooseProduct() async {
    if (_asalId == null) {
      toast(context, 'Pilih gudang asal dulu.', error: true);
      return;
    }
    final list = _produkAsal;
    if (list.isEmpty) {
      toast(context, 'Tidak ada produk di gudang asal ini.', error: true);
      return;
    }
    final p = await pickProduct(context, list, title: 'Produk di gudang asal');
    if (p == null) return;
    setState(() {
      _selected = p;
      _ukuran = null;
    });
  }

  Future<void> _submit() async {
    if (_asalId == null || _tujuanId == null) {
      toast(context, 'Pilih gudang asal & tujuan.', error: true);
      return;
    }
    if (_asalId == _tujuanId) {
      toast(context, 'Gudang tujuan harus beda dari asal.', error: true);
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
      'tipe': 'transfer',
      'product_id': _selected!.id,
      'ukuran': _ukuran,
      'qty': qty,
      'gudang_id': _asalId,
      'gudang_tujuan_id': _tujuanId,
      'petugas': _petugas.text.trim().isEmpty ? null : _petugas.text.trim(),
    };
    setState(() => _saving = true);
    try {
      await api.createMove(body);
      if (mounted) {
        toast(context, 'Transfer berhasil.');
        setState(() {
          _selected = null;
          _ukuran = null;
          _qty.clear();
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
      if (mounted) toast(context, 'Transfer dibatalkan.');
      await _loadRefs();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Gudang'),
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
              SectionHeader('Transfer Antar Gudang', icon: Icons.swap_horiz_rounded, color: AppTheme.info),
              const SizedBox(height: 18),
              // ── Asal → Tujuan ──
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(child: LabeledField('Gudang Asal *', _gudangDropdown(_asalId, (v) {
                  setState(() {
                    _asalId = v;
                    _selected = null;
                    _ukuran = null;
                  });
                }))),
                Padding(
                  padding: const EdgeInsets.only(bottom: 22, left: 4, right: 4),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: AppTheme.info.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.arrow_forward_rounded, color: AppTheme.info, size: 18),
                  ),
                ),
                Expanded(child: LabeledField('Gudang Tujuan *', _gudangDropdown(_tujuanId, (v) => setState(() => _tujuanId = v)))),
              ]),
              LabeledField('Produk *',
                  TapField(
                    value: _selected?.nama,
                    hint: 'Ketuk untuk pilih produk',
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
                        TextFormField(controller: _qty, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '0', prefixIcon: Icon(Icons.tag_rounded))))),
                const SizedBox(width: 12),
                Expanded(child: LabeledField('Tanggal', _dateSelector())),
              ]),
              LabeledField('Petugas',
                  TextFormField(controller: _petugas, decoration: const InputDecoration(hintText: 'Opsional', prefixIcon: Icon(Icons.person_outline)))),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Icon(Icons.swap_horiz_rounded),
                label: const Text('Proses Transfer'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        SectionHeader('Transfer Terakhir', icon: Icons.history_rounded),
        const SizedBox(height: 10),
        _movesList(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _gudangDropdown(int? value, ValueChanged<int?> onChanged) => DropdownButtonFormField<int?>(
        initialValue: value,
        isExpanded: true,
        borderRadius: BorderRadius.circular(14),
        hint: const Text('Pilih', style: TextStyle(color: AppTheme.faint)),
        items: _warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.nama, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: onChanged,
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

  Widget _movesList() => FutureBuilder<List<StockMove>>(
        future: _movesFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(padding: EdgeInsets.all(20), child: Loading());
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return SoftCard(padding: const EdgeInsets.all(20), child: const Center(child: Text('Belum ada transfer.', style: TextStyle(color: AppTheme.muted))));
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
          const MoveAvatar('transfer'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.item ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 2),
              Text('${m.gudang ?? '-'} → ${m.gudangTujuan ?? '-'}${m.ukuran != null && m.ukuran!.isNotEmpty ? ' · uk ${m.ukuran}' : ''}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.muted)),
            ]),
          ),
          Text(angka(m.qty), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.info)),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.faint),
            onPressed: () => _deleteMove(m),
          ),
        ]),
      );
}
