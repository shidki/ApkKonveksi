// Form tambah/edit produk. Meniru web: stok dikelola per UKURAN (varian).
// SKU boleh dikosongkan → backend auto-generate (prefix dari kategori).
import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../ui.dart';
import '../config.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product; // null = tambah baru
  const ProductFormScreen({this.product, super.key});
  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sku = TextEditingController();
  final _nama = TextEditingController();
  final _warna = TextEditingController();
  final _satuan = TextEditingController(text: 'pcs');
  final _hargaBeli = TextEditingController(text: '0');
  final _hargaJual = TextEditingController(text: '0');
  final _stokMin = TextEditingController(text: '0');
  final _stokTunggal = TextEditingController(text: '0'); // dipakai kalau TANPA varian
  final _catatan = TextEditingController();

  int? _kategoriId;
  int? _gudangId;
  int? _tokoId;
  String _status = 'aktif';
  bool _pakaiVarian = true;
  final List<({TextEditingController uk, TextEditingController st})> _variants = [];

  bool _loadingRefs = true;
  bool _saving = false;
  String? _refError;
  List<Category> _categories = [];
  List<Warehouse> _warehouses = [];
  List<Toko> _tokos = [];

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    _prefill();
    _loadRefs();
  }

  void _prefill() {
    final p = widget.product;
    if (p == null) {
      _addVariant();
      return;
    }
    _sku.text = p.sku;
    _nama.text = p.nama;
    _warna.text = p.warna ?? '';
    _satuan.text = p.satuan;
    _hargaBeli.text = _fmt(p.hargaBeli);
    _hargaJual.text = _fmt(p.hargaJual);
    _stokMin.text = '${p.stokMin}';
    _stokTunggal.text = '${p.stok}';
    _kategoriId = p.kategoriId;
    _gudangId = p.gudangId;
    _tokoId = p.tokoId;
    _status = p.status;
    _pakaiVarian = p.pakaiVarian;
    if (p.pakaiVarian) {
      for (final v in p.variants) {
        _variants.add((uk: TextEditingController(text: v.ukuran), st: TextEditingController(text: '${v.stok}')));
      }
    } else {
      _addVariant();
    }
  }

  String _fmt(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

  Future<void> _loadRefs() async {
    try {
      final results = await Future.wait([api.categories(tipe: 'produk'), api.warehouses(), api.tokos()]);
      setState(() {
        _categories = results[0] as List<Category>;
        _warehouses = results[1] as List<Warehouse>;
        _tokos = results[2] as List<Toko>;
        _loadingRefs = false;
      });
    } catch (e) {
      setState(() {
        _refError = '$e';
        _loadingRefs = false;
      });
    }
  }

  void _addVariant() =>
      _variants.add((uk: TextEditingController(), st: TextEditingController(text: '0')));

  @override
  void dispose() {
    for (final c in [_sku, _nama, _warna, _satuan, _hargaBeli, _hargaJual, _stokMin, _stokTunggal, _catatan]) {
      c.dispose();
    }
    for (final v in _variants) {
      v.uk.dispose();
      v.st.dispose();
    }
    super.dispose();
  }

  int get _totalVarian =>
      _variants.fold(0, (s, v) => s + (int.tryParse(v.st.text.trim()) ?? 0));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // Susun varian (buang baris ukuran kosong).
    final variants = <Variant>[];
    if (_pakaiVarian) {
      for (final v in _variants) {
        final uk = v.uk.text.trim();
        if (uk.isEmpty) continue;
        variants.add(Variant(ukuran: uk, stok: int.tryParse(v.st.text.trim()) ?? 0));
      }
      if (variants.isEmpty) {
        toast(context, 'Isi minimal satu ukuran, atau matikan "Pakai ukuran".', error: true);
        return;
      }
    }

    final body = <String, dynamic>{
      'sku': _sku.text.trim().isEmpty ? null : _sku.text.trim(),
      'nama': _nama.text.trim(),
      'kategori_id': _kategoriId,
      'warna': _warna.text.trim().isEmpty ? null : _warna.text.trim(),
      'satuan': _satuan.text.trim().isEmpty ? 'pcs' : _satuan.text.trim(),
      'harga_beli': double.tryParse(_hargaBeli.text.trim()) ?? 0,
      'harga_jual': double.tryParse(_hargaJual.text.trim()) ?? 0,
      'stok': _pakaiVarian ? variants.fold(0, (s, v) => s + v.stok) : (int.tryParse(_stokTunggal.text.trim()) ?? 0),
      'stok_min': int.tryParse(_stokMin.text.trim()) ?? 0,
      'gudang_id': _gudangId,
      'toko_id': _tokoId,
      'variants': variants.map((v) => v.toJson()).toList(),
      'status': _status,
      'catatan': _catatan.text.trim().isEmpty ? null : _catatan.text.trim(),
    };

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await api.updateProduct(widget.product!.id, body);
      } else {
        await api.createProduct(body);
      }
      if (mounted) {
        toast(context, _isEdit ? 'Produk diperbarui' : 'Produk ditambahkan');
        Navigator.pop(context, true);
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
        title: Text(_isEdit ? 'Edit Produk' : 'Tambah Produk'),
        flexibleSpace: const DecoratedBox(decoration: BoxDecoration(gradient: AppTheme.brandGradient)),
      ),
      body: _loadingRefs
          ? const Loading()
          : _refError != null
              ? ErrorView(_refError!, onRetry: () {
                  setState(() {
                    _loadingRefs = true;
                    _refError = null;
                  });
                  _loadRefs();
                })
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      // ── Info produk ──
                      SoftCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionHeader('Informasi Produk', icon: Icons.info_outline_rounded),
                            const SizedBox(height: 18),
                            LabeledField('Nama Produk *',
                                TextFormField(
                                  controller: _nama,
                                  decoration: const InputDecoration(hintText: 'mis. Kaos Polos Cotton Combed'),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                                )),
                            LabeledField('SKU (kosongkan = otomatis)',
                                TextFormField(
                                  controller: _sku,
                                  decoration: const InputDecoration(hintText: 'Otomatis dari kategori kalau kosong'),
                                )),
                            LabeledField('Kategori', _dropdownKategori()),
                            Row(children: [
                              Expanded(
                                  child: LabeledField('Warna',
                                      TextFormField(controller: _warna, decoration: const InputDecoration(hintText: 'Hitam, Putih')))),
                              const SizedBox(width: 12),
                              Expanded(child: LabeledField('Satuan', TextFormField(controller: _satuan))),
                            ]),
                            LabeledField('Status', _dropdownStatus()),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // ── Harga & gudang ──
                      SoftCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionHeader('Harga & Penyimpanan', icon: Icons.sell_outlined, color: AppTheme.success),
                            const SizedBox(height: 18),
                            Row(children: [
                              Expanded(
                                  child: LabeledField('Harga Beli',
                                      TextFormField(controller: _hargaBeli, keyboardType: TextInputType.number, decoration: const InputDecoration(prefixText: 'Rp ')))),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: LabeledField('Harga Jual',
                                      TextFormField(controller: _hargaJual, keyboardType: TextInputType.number, decoration: const InputDecoration(prefixText: 'Rp ')))),
                            ]),
                            Row(children: [
                              Expanded(child: LabeledField('Gudang', _dropdownGudang())),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: LabeledField('Stok Minimum',
                                      TextFormField(controller: _stokMin, keyboardType: TextInputType.number))),
                            ]),
                            LabeledField('Toko (opsional)', _dropdownToko()),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // ── Stok / varian ──
                      SoftCard(child: _variantSection()),
                      const SizedBox(height: 14),
                      // ── Catatan ──
                      SoftCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionHeader('Catatan', icon: Icons.notes_rounded, color: AppTheme.muted),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _catatan,
                              maxLines: 3,
                              decoration: const InputDecoration(hintText: 'Opsional'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : const Icon(Icons.save_rounded),
                        label: Text(_isEdit ? 'Simpan Perubahan' : 'Simpan Produk'),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
    );
  }

  Widget _dropdownKategori() => DropdownButtonFormField<int?>(
        initialValue: _kategoriId,
        isExpanded: true,
        borderRadius: BorderRadius.circular(14),
        hint: const Text('Pilih kategori', style: TextStyle(color: AppTheme.faint)),
        items: [
          const DropdownMenuItem(value: null, child: Text('— Tanpa kategori —')),
          ..._categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nama, overflow: TextOverflow.ellipsis))),
        ],
        onChanged: (v) => setState(() => _kategoriId = v),
      );

  Widget _dropdownGudang() => DropdownButtonFormField<int?>(
        initialValue: _gudangId,
        isExpanded: true,
        borderRadius: BorderRadius.circular(14),
        hint: const Text('Pilih gudang', style: TextStyle(color: AppTheme.faint)),
        items: [
          const DropdownMenuItem(value: null, child: Text('— Tanpa gudang —')),
          ..._warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.nama, overflow: TextOverflow.ellipsis))),
        ],
        onChanged: (v) => setState(() => _gudangId = v),
      );

  Widget _dropdownToko() => DropdownButtonFormField<int?>(
        initialValue: _tokoId,
        isExpanded: true,
        borderRadius: BorderRadius.circular(14),
        items: [
          const DropdownMenuItem(value: null, child: Text('— Tidak terkait toko —')),
          ..._tokos.map((t) => DropdownMenuItem(value: t.id, child: Text(t.namaToko, overflow: TextOverflow.ellipsis))),
        ],
        onChanged: (v) => setState(() => _tokoId = v),
      );

  Widget _dropdownStatus() => DropdownButtonFormField<String>(
        initialValue: _status,
        isExpanded: true,
        borderRadius: BorderRadius.circular(14),
        items: const [
          DropdownMenuItem(value: 'aktif', child: Text('Aktif')),
          DropdownMenuItem(value: 'nonaktif', child: Text('Nonaktif')),
        ],
        onChanged: (v) => setState(() => _status = v ?? 'aktif'),
      );

  Widget _variantSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SectionHeader('Stok per Ukuran', icon: Icons.straighten_rounded, color: AppTheme.info)),
            Switch(
              value: _pakaiVarian,
              activeThumbColor: Colors.white,
              activeTrackColor: AppTheme.primary,
              onChanged: (v) => setState(() {
                _pakaiVarian = v;
                if (v && _variants.isEmpty) _addVariant();
              }),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _pakaiVarian
              ? 'Tiap ukuran punya stok sendiri. Total stok = jumlah semua ukuran.'
              : 'Produk tanpa ukuran — pakai satu angka stok.',
          style: const TextStyle(color: AppTheme.muted, fontSize: 12.5),
        ),
        const SizedBox(height: 16),
        if (!_pakaiVarian)
          LabeledField('Stok',
              TextFormField(controller: _stokTunggal, keyboardType: TextInputType.number))
        else ...[
          for (int i = 0; i < _variants.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _variants[i].uk,
                      decoration: const InputDecoration(labelText: 'Ukuran', hintText: 'S / M / 32'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _variants[i].st,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Stok'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline_rounded,
                        color: _variants.length == 1 ? AppTheme.faint : AppTheme.danger),
                    onPressed: _variants.length == 1
                        ? null
                        : () => setState(() {
                              _variants[i].uk.dispose();
                              _variants[i].st.dispose();
                              _variants.removeAt(i);
                            }),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => setState(_addVariant),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Tambah ukuran'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 16)),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.inventory_2_rounded, size: 18, color: AppTheme.primaryDark),
              const SizedBox(width: 8),
              const Text('Total stok', style: TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${angka(_totalVarian)} pcs',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryDark, fontSize: 15)),
            ]),
          ),
        ],
      ],
    );
  }
}
