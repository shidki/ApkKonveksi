// Kerangka utama setelah login. Menu (bottom navigation) MUNCUL SESUAI PERAN
// user: tukang potong → Potong, tukang jahit → Jahit, checking → Checking +
// Monitoring. Tab "Akun" selalu ada (profil + logout). Data di tiap layar
// otomatis ke-scope oleh backend berdasarkan akun yang login.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../auth.dart';
import '../config.dart';
import '../ui.dart';
import '../update.dart';
import '../services/alarm_notif.dart';
import 'potong_screen.dart';
import 'jahit_screen.dart';
import 'checking_screen.dart';
import 'monitoring_screen.dart';
import 'notif_bell.dart';

class _Tab {
  final String label;
  final IconData icon;
  final Widget screen;
  final String kind; // buat map notif link → tab
  const _Tab(this.label, this.icon, this.screen, this.kind);
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Minta izin notifikasi (Android 13+ / iOS) begitu masuk beranda.
    WidgetsBinding.instance.addPostFrameCallback((_) => NotifAlarm.requestPermission());
    // Poller foreground: pas app kebuka, app sendiri cek notif & bunyiin alarm
    // (reliable di Android & iOS, gak gantung service background).
    NotifAlarm.startForegroundPoll();
    // Cek update sekali saat masuk beranda (Android saja; iOS auto-skip).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final info = await checkForUpdate();
      if (info != null && mounted) showUpdateDialog(context, info);
    });
  }

  @override
  void dispose() {
    NotifAlarm.stopForegroundPoll();
    super.dispose();
  }

  // Pindah ke tab yang relevan dari link notif (mis. /product-management/jahit → tab Jahit).
  void _openLink(String? link, List<_Tab> tabs) {
    if (link == null || link.isEmpty) return;
    String? kind;
    if (link.contains('jahit')) {
      kind = 'jahit';
    } else if (link.contains('potongan')) {
      kind = 'potongan';
    } else if (link.contains('checking')) {
      kind = 'checking';
    } else if (link.contains('monitoring')) {
      kind = 'monitoring';
    }
    if (kind == null) return;
    final idx = tabs.indexWhere((t) => t.kind == kind);
    if (idx >= 0) setState(() => _index = idx);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tabs = <_Tab>[];
    if (auth.can('pm.potongan.view') || auth.can('pm.bahan_masuk.view')) {
      tabs.add(const _Tab('Potong', Icons.content_cut_rounded, PotongScreen(), 'potongan'));
    }
    if (auth.can('pm.jahit.view')) {
      tabs.add(const _Tab('Jahit', Icons.checkroom_rounded, JahitScreen(), 'jahit'));
    }
    if (auth.can('pm.checking.view')) {
      tabs.add(const _Tab('Checking', Icons.fact_check_rounded, CheckingScreen(), 'checking'));
    }
    if (auth.can('pm.monitoring.view')) {
      tabs.add(const _Tab('Monitoring', Icons.insights_rounded, MonitoringScreen(), 'monitoring'));
    }
    tabs.add(const _Tab('Akun', Icons.person_rounded, _AkunScreen(), 'akun'));

    if (_index >= tabs.length) _index = 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(children: [
          IndexedStack(index: _index, children: tabs.map((t) => t.screen).toList()),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 6,
            child: NotifBell(onOpenLink: (link) => _openLink(link, tabs)),
          ),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          backgroundColor: AppTheme.surface,
          indicatorColor: AppTheme.primary.withValues(alpha: 0.14),
          destinations: [
            for (final t in tabs)
              NavigationDestination(
                icon: Icon(t.icon, color: AppTheme.faint),
                selectedIcon: Icon(t.icon, color: AppTheme.primary),
                label: t.label,
              ),
          ],
        ),
      ),
    );
  }
}

/// Tab Akun — profil user + tombol logout.
class _AkunScreen extends StatelessWidget {
  const _AkunScreen();
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final u = auth.user;
    final peran = <String>[
      if (auth.can('pm.potongan.view') || auth.can('pm.bahan_masuk.view')) 'Tukang Potong',
      if (auth.can('pm.jahit.view')) 'Tukang Jahit',
      if (auth.can('pm.checking.view')) 'Checking / QC',
      if (auth.can('pm.monitoring.view')) 'Monitoring',
    ];
    return Scaffold(
      body: Column(children: [
        const ModernHeader(title: 'Akun', subtitle: 'Profil & keluar'),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            SoftCard(
              child: Row(children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(gradient: AppTheme.brandGradient, borderRadius: BorderRadius.circular(16)),
                  alignment: Alignment.center,
                  child: Text((u?.nama ?? u?.email ?? 'U').substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u?.nama ?? 'User',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                    const SizedBox(height: 2),
                    Text(u?.email ?? '', style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
                    if (u?.role != null) ...[
                      const SizedBox(height: 2),
                      Text('Role: ${u!.role}', style: const TextStyle(color: AppTheme.faint, fontSize: 12)),
                    ],
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            if (peran.isNotEmpty) ...[
              const SectionHeader('Akses Kamu', icon: Icons.badge_outlined),
              const SizedBox(height: 8),
              SoftCard(
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final p in peran)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(p, style: const TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.w700, fontSize: 12.5)),
                    ),
                ]),
              ),
              const SizedBox(height: 18),
            ],
            const SectionHeader('Alarm & Notifikasi', icon: Icons.notifications_active_outlined),
            const SizedBox(height: 8),
            const _AlarmTestCard(),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () async {
                final authP = context.read<AuthProvider>();
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Keluar?'),
                    content: const Text('Kamu akan logout dari aplikasi.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Keluar')),
                    ],
                  ),
                );
                if (ok == true) await authP.logout();
              },
              icon: const Icon(Icons.logout_rounded, color: AppTheme.danger),
              label: const Text('Keluar', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.border), minimumSize: const Size.fromHeight(50)),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Kartu tes alarm + status izin notifikasi (di layar Akun).
class _AlarmTestCard extends StatefulWidget {
  const _AlarmTestCard();
  @override
  State<_AlarmTestCard> createState() => _AlarmTestCardState();
}

class _AlarmTestCardState extends State<_AlarmTestCard> {
  bool _playing = false;
  bool _busy = false;
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final e = await NotifAlarm.notifEnabled();
    if (mounted) setState(() => _enabled = e);
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    await NotifAlarm.testStart();
    await _check();
    if (mounted) setState(() { _playing = true; _busy = false; });
  }

  Future<void> _stop() async {
    await NotifAlarm.testStop();
    if (mounted) setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_enabled == false) ...[
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: AppTheme.danger.withValues(alpha: 0.35)),
              ),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.warning_amber_rounded, size: 17, color: AppTheme.danger),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Izin notifikasi MATI — alarm gak bakal bunyi. Buka Setelan HP > Aplikasi > Apk Produksi > Notifikasi, nyalain.',
                    style: TextStyle(fontSize: 12.5, color: AppTheme.danger, fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
          ],
          const Text('Tes apakah alarm bunyi di HP ini (langsung, tanpa nunggu notif dari server).',
              style: TextStyle(fontSize: 12.5, color: AppTheme.muted)),
          const SizedBox(height: 12),
          _playing
              ? FilledButton.icon(
                  onPressed: _stop,
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Stop Alarm'),
                )
              : FilledButton.icon(
                  onPressed: _busy ? null : _start,
                  icon: _busy
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : const Icon(Icons.notifications_active_rounded),
                  label: const Text('Tes Bunyi Alarm'),
                ),
          const SizedBox(height: 10),
          const Text(
            'Kalau tes ini BUNYI tapi notif produksi nggak: pastikan sudah login, '
            'matikan "optimasi baterai" buat app ini, & app tetap jalan di background. '
            'Kalau tes ini pun GAK bunyi: izin notif belum ON / volume alarm HP 0.',
            style: TextStyle(fontSize: 11.5, color: AppTheme.faint),
          ),
        ],
      ),
    );
  }
}
