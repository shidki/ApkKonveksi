// Lonceng notifikasi in-app. Polling unread tiap 30 dtk, tap → bottom sheet
// daftar notif. Tap item → tandai dibaca + (opsional) buka tab terkait via
// callback onOpenLink. Dipasang sebagai overlay di HomeShell (muncul di semua tab).
import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import '../config.dart';
import '../models.dart';
import '../ui.dart';

const _tipeIcon = {
  'jahit_request': Icons.content_cut_rounded,
  'acc': Icons.check_circle_rounded,
  'reject': Icons.cancel_rounded,
  'selesai': Icons.checkroom_rounded,
  'checking': Icons.celebration_rounded,
  'rework': Icons.replay_rounded,
  'tarik': Icons.undo_rounded,
};

String _timeAgo(String iso) {
  if (iso.isEmpty) return '';
  try {
    var s = iso;
    if (!s.endsWith('Z') && !s.contains('+')) s = '${s}Z';
    final d = DateTime.parse(s).toLocal();
    final sec = DateTime.now().difference(d).inSeconds;
    if (sec < 60) return 'baru saja';
    if (sec < 3600) return '${sec ~/ 60} mnt lalu';
    if (sec < 86400) return '${sec ~/ 3600} jam lalu';
    return '${sec ~/ 86400} hr lalu';
  } catch (_) {
    return '';
  }
}

class NotifBell extends StatefulWidget {
  final void Function(String? link)? onOpenLink;
  const NotifBell({this.onOpenLink, super.key});
  @override
  State<NotifBell> createState() => _NotifBellState();
}

class _NotifBellState extends State<NotifBell> {
  int _unread = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final n = await api.notifUnread();
      if (mounted) setState(() => _unread = n);
    } catch (_) {/* diam */}
  }

  Future<void> _open() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotifSheet(onOpenLink: widget.onOpenLink),
    );
    _poll(); // refresh badge setelah sheet ditutup
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: _open,
          tooltip: 'Notifikasi',
          icon: const Icon(Icons.notifications_rounded, color: Colors.white, size: 26),
        ),
        if (_unread > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: BoxDecoration(
                color: AppTheme.danger,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                _unread > 99 ? '99+' : '$_unread',
                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800, height: 1),
              ),
            ),
          ),
      ],
    );
  }
}

class _NotifSheet extends StatefulWidget {
  final void Function(String? link)? onOpenLink;
  const _NotifSheet({this.onOpenLink});
  @override
  State<_NotifSheet> createState() => _NotifSheetState();
}

class _NotifSheetState extends State<_NotifSheet> {
  bool _loading = true;
  List<Notif> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await api.notif();
      if (mounted) setState(() { _items = r.items; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _tap(Notif n) async {
    if (!n.dibaca) {
      try { await api.notifRead(n.id); } catch (_) {}
    }
    if (!mounted) return;
    Navigator.pop(context);
    widget.onOpenLink?.call(n.link);
  }

  Future<void> _readAll() async {
    try { await api.notifReadAll(); } catch (_) {}
    if (!mounted) return;
    setState(() => _items = _items.map((n) => Notif(
          id: n.id, judul: n.judul, pesan: n.pesan, tipe: n.tipe, link: n.link,
          refId: n.refId, dibaca: true, createdAt: n.createdAt)).toList());
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _items.any((n) => !n.dibaca);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scroll) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
              child: Row(children: [
                const Text('Notifikasi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                const Spacer(),
                if (hasUnread)
                  TextButton(onPressed: _readAll, child: const Text('Tandai semua dibaca', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
              ]),
            ),
            Expanded(
              child: _loading
                  ? const Loading(label: 'Memuat notifikasi…')
                  : _items.isEmpty
                      ? ListView(children: const [SizedBox(height: 80), EmptyView('Belum ada notifikasi.', icon: Icons.notifications_none_rounded)])
                      : ListView.separated(
                          controller: scroll,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                          itemCount: _items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _notifTile(_items[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notifTile(Notif n) {
    final ic = _tipeIcon[n.tipe ?? ''] ?? Icons.notifications_rounded;
    return SoftCard(
      onTap: () => _tap(n),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: (n.dibaca ? AppTheme.muted : AppTheme.primary).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(ic, size: 20, color: n.dibaca ? AppTheme.muted : AppTheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n.judul, style: TextStyle(fontSize: 14, fontWeight: n.dibaca ? FontWeight.w600 : FontWeight.w800, color: AppTheme.ink)),
            if (n.pesan != null && n.pesan!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(n.pesan!, style: const TextStyle(fontSize: 12.5, color: AppTheme.muted, height: 1.35)),
            ],
            const SizedBox(height: 4),
            Text(_timeAgo(n.createdAt), style: const TextStyle(fontSize: 11, color: AppTheme.faint, fontWeight: FontWeight.w600)),
          ]),
        ),
        if (!n.dibaca) ...[
          const SizedBox(width: 6),
          Container(width: 9, height: 9, margin: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle)),
        ],
      ]),
    );
  }
}
