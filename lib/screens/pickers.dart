// Pemilih produk berbentuk bottom sheet dengan pencarian — dipakai bersama
// oleh layar Penerimaan, Transfer, Opname, dan Kartu Stok.
import 'package:flutter/material.dart';
import '../models.dart';
import '../ui.dart';
import '../config.dart';

Widget _grabber() => Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 4),
        width: 42,
        height: 5,
        decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(3)),
      ),
    );

Future<Product?> pickProduct(BuildContext context, List<Product> products, {String? title}) {
  return showModalBottomSheet<Product>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => _ProductPicker(products: products, title: title ?? 'Pilih Produk'),
  );
}

class _ProductPicker extends StatefulWidget {
  final List<Product> products;
  final String title;
  const _ProductPicker({required this.products, required this.title});
  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final items = widget.products
        .where((p) => q.isEmpty || p.nama.toLowerCase().contains(q) || p.sku.toLowerCase().contains(q))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        builder: (ctx, scroll) => Column(
          children: [
            _grabber(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(children: [
                Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.ink)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded, color: AppTheme.muted),
                  visualDensity: VisualDensity.compact,
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Cari nama / SKU…', prefixIcon: Icon(Icons.search_rounded)),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const EmptyView('Produk tidak ditemukan.')
                  : ListView.separated(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                      itemCount: items.length,
                      separatorBuilder: (_, i) => const SizedBox(height: 6),
                      itemBuilder: (c, i) {
                        final p = items[i];
                        return Material(
                          color: AppTheme.soft,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.pop(ctx, p),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(namaPendek(p.nama), maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text(
                                        [
                                          p.sku,
                                          if (p.warna != null && p.warna!.isNotEmpty) p.warna!,
                                          'stok ${p.stok}',
                                        ].join(' · '),
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
                                  ]),
                                ),
                                const SizedBox(width: 8),
                                StockBadge(p.stockState),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pilih ukuran dari varian produk.
Future<String?> pickUkuran(BuildContext context, Product p) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _grabber(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Pilih Ukuran', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.ink)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final v in p.variants)
                  Material(
                    color: AppTheme.soft,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(ctx, v.ukuran),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(v.ukuran, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.ink)),
                          const SizedBox(height: 2),
                          Text('stok ${v.stok}', style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
                        ]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
