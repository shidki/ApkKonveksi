// Helper UI bersama: format angka/uang/tanggal + widget modern yang dipakai
// di banyak layar (kartu lembut, header seksi, stat card, badge, empty state).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'config.dart';

final _rp = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final _num = NumberFormat.decimalPattern('id_ID');

String rupiah(num v) => _rp.format(v);
String angka(num v) => _num.format(v);

/// Rupiah ringkas: 1,2jt / 950rb (buat KPI biar gak kepanjangan).
String rupiahRingkas(num v) {
  if (v.abs() >= 1000000000) return 'Rp ${(v / 1000000000).toStringAsFixed(1)}M';
  if (v.abs() >= 1000000) return 'Rp ${(v / 1000000).toStringAsFixed(1)}jt';
  if (v.abs() >= 1000) return 'Rp ${(v / 1000).toStringAsFixed(0)}rb';
  return rupiah(v);
}

/// Nama produk ringkas buat list: ambil beberapa kata pertama saja.
/// Info penting lain (warna, ukuran) ditampilkan terpisah di subtitle/chip.
String namaPendek(String nama, {int kata = 3}) {
  final parts = nama.trim().split(RegExp(r'\s+'));
  if (parts.length <= kata) return nama.trim();
  return '${parts.take(kata).join(' ')}…';
}

String tanggalID(String iso) {
  try {
    return DateFormat('d MMM yyyy', 'id_ID').format(DateTime.parse(iso));
  } catch (_) {
    return iso;
  }
}

/// Snackbar pesan singkat (sukses/error) dengan ikon.
void toast(BuildContext ctx, String msg, {bool error = false}) {
  ScaffoldMessenger.of(ctx)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline,
            color: error ? const Color(0xFFFCA5A5) : const Color(0xFF6EE7B7), size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: AppTheme.ink,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
}

/// Kartu putih dengan sudut membulat + bayangan lembut (pengganti Card polos).
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  const SoftCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: BoxDecoration(
        color: color ?? AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return content;
  }
}

/// Judul seksi: ikon dalam chip + teks + aksi opsional di kanan.
class SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? color;
  final Widget? trailing;
  const SectionHeader(this.title, {required this.icon, this.color, this.trailing, super.key});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: c),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.ink)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Kartu statistik/KPI dengan ikon berwarna.
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? sub;
  const StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.sub,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.ink, height: 1.1)),
          const SizedBox(height: 2),
          Text(sub ?? label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.muted, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class Loading extends StatelessWidget {
  final String? label;
  const Loading({this.label, super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              height: 34,
              width: 34,
              child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.primary),
            ),
            if (label != null) ...[
              const SizedBox(height: 14),
              Text(label!, style: const TextStyle(color: AppTheme.muted)),
            ],
          ],
        ),
      );
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorView(this.message, {this.onRetry, super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_off_rounded, size: 40, color: AppTheme.danger),
              ),
              const SizedBox(height: 16),
              const Text('Gagal memuat data',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.ink)),
              const SizedBox(height: 6),
              Text(message,
                  textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
              if (onRetry != null) ...[
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba lagi'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(160, 46)),
                ),
              ],
            ],
          ),
        ),
      );
}

class EmptyView extends StatelessWidget {
  final String message;
  final IconData icon;
  const EmptyView(this.message, {this.icon = Icons.inbox_outlined, super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppTheme.soft, shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: AppTheme.faint),
            ),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.muted, fontSize: 14)),
          ]),
        ),
      );
}

/// Badge status stok (aman/menipis/habis) dengan titik indikator.
class StockBadge extends StatelessWidget {
  final String state;
  const StockBadge(this.state, {super.key});
  @override
  Widget build(BuildContext context) {
    final (Color c, String label) = switch (state) {
      'habis' => (AppTheme.danger, 'Habis'),
      'menipis' => (AppTheme.warning, 'Menipis'),
      _ => (AppTheme.success, 'Aman'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Warna + label + ikon berdasarkan tipe mutasi.
({Color color, String label, IconData icon}) moveMeta(String tipe) => switch (tipe) {
      'masuk' => (color: AppTheme.success, label: 'Masuk', icon: Icons.south_west_rounded),
      'keluar' => (color: AppTheme.danger, label: 'Keluar', icon: Icons.north_east_rounded),
      'transfer' => (color: AppTheme.info, label: 'Transfer', icon: Icons.swap_horiz_rounded),
      'opname' => (color: AppTheme.warning, label: 'Opname', icon: Icons.fact_check_outlined),
      _ => (color: AppTheme.muted, label: tipe, icon: Icons.circle),
    };

/// Chip warna berdasarkan tipe mutasi.
class MoveTipeChip extends StatelessWidget {
  final String tipe;
  const MoveTipeChip(this.tipe, {super.key});
  @override
  Widget build(BuildContext context) {
    final m = moveMeta(tipe);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: m.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(m.icon, size: 12, color: m.color),
        const SizedBox(width: 5),
        Text(m.label, style: TextStyle(color: m.color, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Avatar bulat berisi ikon lingkaran berwarna (buat leading list mutasi).
class MoveAvatar extends StatelessWidget {
  final String tipe;
  const MoveAvatar(this.tipe, {super.key});
  @override
  Widget build(BuildContext context) {
    final m = moveMeta(tipe);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: m.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Icon(m.icon, size: 19, color: m.color),
    );
  }
}

/// Label + field untuk form (jarak konsisten).
class LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const LabeledField(this.label, this.child, {super.key});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
          const SizedBox(height: 7),
          child,
          const SizedBox(height: 16),
        ],
      );
}

/// Header halaman modern: gradient, sudut bawah membulat, judul besar +
/// subtitle + widget kanan opsional. Dipakai semua tab (pengganti AppBar).
class ModernHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const ModernHeader({required this.title, this.subtitle, this.trailing, super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, top + 16, 20, 22),
      decoration: const BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
            ],
          ]),
        ),
        ?trailing,
      ]),
    );
  }
}

/// Field "ketuk untuk pilih" (produk/ukuran/tanggal) bergaya seragam.
class TapField extends StatelessWidget {
  final String? value;
  final String hint;
  final IconData trailingIcon;
  final IconData? leadingIcon;
  final VoidCallback onTap;
  const TapField({
    required this.value,
    required this.hint,
    required this.onTap,
    this.trailingIcon = Icons.expand_more_rounded,
    this.leadingIcon,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    final filled = value != null && value!.isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(
            color: AppTheme.soft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 18, color: AppTheme.muted),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                filled ? value! : hint,
                style: TextStyle(
                    color: filled ? AppTheme.ink : AppTheme.faint,
                    fontWeight: filled ? FontWeight.w600 : FontWeight.w400),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(trailingIcon, size: 20, color: AppTheme.muted),
          ]),
        ),
      ),
    );
  }
}
