// Auto-update di luar Play Store.
//
// Cara kerja:
//   1. App cek file JSON di server cPanel (Config.updateManifestUrl).
//   2. Bandingkan build number di JSON dengan versi terpasang.
//   3. Kalau lebih baru → dialog update; user tekan "Update" → APK di-download
//      lalu Android installer kebuka (user cukup tekan "Install" sekali).
//
// Format update.json yang diharapkan:
//   {
//     "version": "1.0.1",          // nama versi (buat ditampilkan)
//     "build":   2,                 // versionCode — dipakai buat bandingin
//     "url":     "https://.../apkstock.apk",
//     "notes":   "Apa yang berubah di versi ini.",
//     "mandatory": false            // true = user tak bisa tutup dialog
//   }
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'config.dart';

class UpdateInfo {
  final String version;
  final int build;
  final String url;
  final String notes;
  final bool mandatory;

  UpdateInfo({
    required this.version,
    required this.build,
    required this.url,
    required this.notes,
    required this.mandatory,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> j) => UpdateInfo(
        version: (j['version'] ?? '').toString(),
        build: int.tryParse('${j['build']}') ?? 0,
        url: (j['url'] ?? '').toString(),
        notes: (j['notes'] ?? '').toString(),
        mandatory: j['mandatory'] == true,
      );
}

/// Cek server; kembalikan info kalau ada versi lebih baru, selain itu null.
/// Aman dipanggil di startup — semua error ditelan (return null).
Future<UpdateInfo?> checkForUpdate() async {
  if (!Platform.isAndroid) return null; // ota_update hanya untuk Android
  try {
    final res = await http
        .get(Uri.parse(Config.updateManifestUrl))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;

    final info = UpdateInfo.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    if (info.url.isEmpty) return null;

    final pkg = await PackageInfo.fromPlatform();
    final current = int.tryParse(pkg.buildNumber) ?? 0;
    return info.build > current ? info : null;
  } catch (_) {
    return null; // offline / URL salah / JSON rusak → jangan ganggu user
  }
}

/// Tampilkan dialog update.
Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: !info.mandatory,
    builder: (_) => _UpdateDialog(info: info),
  );
}

class _UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  const _UpdateDialog({required this.info});
  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  StreamSubscription<OtaEvent>? _sub;
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _startUpdate() {
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });
    try {
      _sub = OtaUpdate()
          .execute(widget.info.url, destinationFilename: 'apkstock-update.apk')
          .listen((OtaEvent event) {
        if (!mounted) return;
        switch (event.status) {
          case OtaStatus.DOWNLOADING:
            setState(() => _progress = (double.tryParse(event.value ?? '0') ?? 0) / 100);
            break;
          case OtaStatus.INSTALLING:
            // Installer Android kebuka — dialog boleh ditutup.
            if (mounted) Navigator.of(context).maybePop();
            break;
          case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
            _showError('Izin "Install aplikasi tak dikenal" belum diberikan. '
                'Aktifkan lewat pengaturan HP lalu coba lagi.');
            break;
          case OtaStatus.DOWNLOAD_ERROR:
          case OtaStatus.INTERNAL_ERROR:
          case OtaStatus.CHECKSUM_ERROR:
          case OtaStatus.ALREADY_RUNNING_ERROR:
            _showError('Gagal mengunduh update. Coba lagi nanti.');
            break;
          default:
            break;
        }
      }, onError: (_) => _showError('Gagal mengunduh update. Coba lagi nanti.'));
    } catch (_) {
      _showError('Gagal memulai update.');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() {
      _downloading = false;
      _error = msg;
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    return PopScope(
      canPop: !info.mandatory && !_downloading,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 26),
        backgroundColor: AppTheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [_hero(info), _body(info)],
        ),
      ),
    );
  }

  /// Bagian atas: panel gradient dengan ikon melayang + badge versi.
  Widget _hero(UpdateInfo info) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
      decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.4),
            ),
            child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          const Text('Update Tersedia',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('Versi ${info.version}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// Bagian bawah: catatan rilis, progress/error, dan tombol aksi.
  Widget _body(UpdateInfo info) {
    final notes = info.notes
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notes.isNotEmpty) ...[
            Row(children: const [
              Icon(Icons.auto_awesome_rounded, size: 16, color: AppTheme.primary),
              SizedBox(width: 6),
              Text('Yang baru',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.ink)),
            ]),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.soft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final n in notes)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 6, right: 9),
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                                color: AppTheme.primary, shape: BoxShape.circle),
                          ),
                          Expanded(
                            child: Text(n,
                                style: const TextStyle(
                                    color: AppTheme.muted, fontSize: 13, height: 1.35)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (_downloading) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Mengunduh…',
                    style: TextStyle(
                        color: AppTheme.ink, fontSize: 12.5, fontWeight: FontWeight.w700)),
                Text('${(_progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        color: AppTheme.primary, fontSize: 12.5, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: _progress == 0 ? null : _progress,
                minHeight: 8,
                backgroundColor: AppTheme.soft,
                valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!,
                      style: const TextStyle(color: AppTheme.danger, fontSize: 12.5, height: 1.3)),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 22),
          _actions(info),
        ],
      ),
    );
  }

  Widget _actions(UpdateInfo info) {
    final label = _error != null ? 'Coba Lagi' : 'Update Sekarang';
    final button = _GradientButton(
      label: _downloading ? 'Mengunduh…' : label,
      enabled: !_downloading,
      onTap: _startUpdate,
    );
    if (info.mandatory || _downloading) return button;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Nanti'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: button),
      ],
    );
  }
}

/// Tombol utama dengan gradient brand + glow lembut.
class _GradientButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _GradientButton({required this.label, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppTheme.brandGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? onTap : null,
            child: Container(
              height: 52,
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!enabled) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: 0.2)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
