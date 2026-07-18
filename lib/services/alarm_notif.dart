// Notifikasi ALARM (Android) + service background yang polling notif backend,
// dengan dukungan NADA CUSTOM (MP3 upload dari web).
//
// Cara kerja:
//   • Foreground service polling GET /notif tiap ~20 detik pakai token tersimpan.
//   • Tiap poll juga sinkron nada alarm: GET /settings/alarm-sound → kalau ada file
//     custom & versinya beda, di-download ke storage app.
//   • Begitu ada notif BARU:
//       - Kalau ada nada custom → muter file itu LOOPING (audioplayers, stream ALARM)
//         + tampil notifikasi + tombol "🔕 Matikan".
//       - Kalau nggak ada custom → notifikasi INSISTENT (suara alarm bawaan HP, getar
//         berulang sampai notif di-swipe).
//   • Alarm berhenti kalau: tekan "Matikan", tap notif, atau otomatis setelah 60 detik.
//
// ANDROID only. Backend: endpoint /notif & /settings/alarm-sound sudah ada.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

const String _alarmChannelId = 'produksi_alarm'; // pakai suara bawaan (insistent)
const String _alarmSilentChannelId = 'produksi_alarm_silent'; // custom sound (kita muter sendiri)
const String _serviceChannelId = 'produksi_service';
const int _serviceNotifId = 8888;
const int _alarmNotifId = 9999;
const String _kLastNotifId = 'last_notif_id';
const String _kToken = 'auth_token';
const String _kSoundVer = 'alarm_sound_version';
const String _kSoundPath = 'alarm_sound_path';
const String _stopActionId = 'stop_alarm';

final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();

// Dipakai HANYA di isolate service (background).
AudioPlayer? _alarmPlayer;
Timer? _autoStopTimer;

Future<void> _initPlugin() async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  await _fln.initialize(
    const InitializationSettings(android: androidInit, iOS: iosInit),
    onDidReceiveNotificationResponse: _onNotifTap,
    onDidReceiveBackgroundNotificationResponse: _onNotifBgTap,
  );
  final android =
      _fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  // Channel ALARM bawaan (suara HP + getar).
  await android?.createNotificationChannel(const AndroidNotificationChannel(
    _alarmChannelId,
    'Alarm Produksi',
    description: 'Notifikasi penting produksi — bunyi alarm & getar sampai dimatikan.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    audioAttributesUsage: AudioAttributesUsage.alarm,
  ));
  // Channel ALARM custom — TANPA suara channel (kita muter MP3 sendiri), tetap getar.
  await android?.createNotificationChannel(const AndroidNotificationChannel(
    _alarmSilentChannelId,
    'Alarm Produksi (nada custom)',
    description: 'Notifikasi produksi dengan nada custom.',
    importance: Importance.max,
    playSound: false,
    enableVibration: true,
  ));
  // Channel SERVICE — notif kecil "app lagi mantau".
  await android?.createNotificationChannel(const AndroidNotificationChannel(
    _serviceChannelId,
    'Layanan Produksi',
    description: 'Menjaga app tetap memantau notifikasi di background.',
    importance: Importance.low,
  ));
}

class NotifAlarm {
  static Future<void> init() async {
    await _initPlugin();
    await FlutterBackgroundService().configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        autoStartOnBoot: false,
        notificationChannelId: _serviceChannelId,
        initialNotificationTitle: 'Produksi memantau',
        initialNotificationContent: 'Notifikasi baru bakal muncul sebagai alarm.',
        foregroundServiceNotificationId: _serviceNotifId,
        // WAJIB Android 14: foreground service harus punya tipe.
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _iosStub,
        onBackground: _iosStub,
      ),
    );
  }

  static Future<void> requestPermission() async {
    final android =
        _fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    final ios =
        _fln.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Cek izin notifikasi aktif (Android 13+). Kalau MATI, alarm gak bakal bunyi.
  static Future<bool> notifEnabled() async {
    final android =
        _fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return (await android?.areNotificationsEnabled()) ?? true;
  }

  static AudioPlayer? _testPlayer;

  /// Bunyiin alarm langsung buat ngetes (dari layar Akun). Nggak nunggu notif backend.
  static Future<void> testStart() async {
    await requestPermission();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kToken);
    if (token != null) {
      try {
        await _syncAlarmSound(token, prefs);
      } catch (_) {}
    }
    final path = prefs.getString(_kSoundPath);
    final hasCustom = path != null && File(path).existsSync();
    await _showNotif('🔔 Tes Alarm Produksi',
        'Kalau kedengeran bunyi/getar, alarm aktif. Tekan Stop / Matikan.',
        silent: hasCustom);
    if (hasCustom) {
      try {
        _testPlayer ??= AudioPlayer();
        await _testPlayer!.setReleaseMode(ReleaseMode.loop);
        await _testPlayer!.setAudioContext(AudioContext(
          android: const AudioContextAndroid(
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ));
        await _testPlayer!.stop();
        await _testPlayer!.play(DeviceFileSource(path), volume: 1.0);
      } catch (_) {}
    }
  }

  static Future<void> testStop() async {
    try {
      await _testPlayer?.stop();
    } catch (_) {}
    try {
      await _fln.cancel(_alarmNotifId);
    } catch (_) {}
    FlutterBackgroundService().invoke('stopAlarm'); // kalau service lagi muter juga
  }

  static Future<void> start() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastNotifId); // re-baseline: notif lama gak ikut bunyi
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await service.startService();
    }
  }

  static Future<void> stop() async {
    stopForegroundPoll();
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('stopService');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastNotifId);
  }

  static Timer? _fgTimer;

  /// Poller FOREGROUND: pas app kebuka, app SENDIRI cek notif & bunyiin alarm tiap
  /// 15 detik. Reliable di Android & iOS (gak gantung ke service background yang
  /// bisa di-kill baterai / gak jalan di iOS). Dipanggil dari beranda.
  static void startForegroundPoll() {
    _fgTimer?.cancel();
    _pollAlarms();
    _fgTimer = Timer.periodic(const Duration(seconds: 15), (_) => _pollAlarms());
  }

  static void stopForegroundPoll() {
    _fgTimer?.cancel();
    _fgTimer = null;
  }
}

@pragma('vm:entry-point')
Future<bool> _iosStub(ServiceInstance service) async => true;

// Tap notif di FOREGROUND → matiin alarm (player isolate ini + service).
@pragma('vm:entry-point')
void _onNotifTap(NotificationResponse resp) {
  _stopAlarm();
  FlutterBackgroundService().invoke('stopAlarm');
}

// Tap notif / tombol "Matikan" saat app di BACKGROUND / mati → matiin alarm.
@pragma('vm:entry-point')
void _onNotifBgTap(NotificationResponse resp) {
  FlutterBackgroundService().invoke('stopAlarm');
}

/// Entry-point service background (isolate terpisah).
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  await _initPlugin();

  service.on('stopService').listen((_) async {
    await _stopAlarm();
    service.stopSelf();
  });
  service.on('stopAlarm').listen((_) => _stopAlarm());

  Timer.periodic(const Duration(seconds: 20), (timer) => _pollAlarms());
}

// Satu putaran cek notif → bunyiin alarm kalau ada yang baru. Dipakai DUA jalur:
//   1) service background (Android) — jalan walau app ketutup.
//   2) poller foreground (Android & iOS) — pas app kebuka (checker/penjahit lagi
//      nungguin). Share _kLastNotifId biar gak dobel-bunyi.
Future<void> _pollAlarms() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString(_kToken);
  if (token == null) return; // logout → diam
  await _syncAlarmSound(token, prefs); // pastikan nada custom terbaru
  try {
    final res = await http.get(
      Uri.parse('${Config.pmBase}/notif'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (data['items'] as List?) ?? const [];
    if (items.isEmpty) return;

    var maxIdAll = 0;
    Map? newest;
    for (final e in items) {
      final m = e as Map;
      final id = (m['id'] as num?)?.toInt() ?? 0;
      if (id > maxIdAll) {
        maxIdAll = id;
        newest = m;
      }
    }

    // Poll pertama → cuma catat baseline, jangan bunyiin notif lama.
    if (!prefs.containsKey(_kLastNotifId)) {
      await prefs.setInt(_kLastNotifId, maxIdAll);
      return;
    }

    final lastId = prefs.getInt(_kLastNotifId) ?? 0;
    if (maxIdAll <= lastId) return; // nggak ada yang baru

    // Ada notif baru → bunyiin buat yang terbaru. JANGAN cek 'dibaca': id > lastId
    // berarti belum pernah dialarmkan, walau user keburu buka bell & ke-mark dibaca.
    final n = newest;
    await prefs.setInt(_kLastNotifId, maxIdAll);
    if (n != null) {
      await _fireAlarm(
        n['judul']?.toString() ?? 'Notifikasi Produksi',
        n['pesan']?.toString() ?? '',
        prefs,
      );
    }
  } catch (_) {
    // diam; coba lagi ronde berikut
  }
}

// Sinkron nada alarm custom dari backend ke storage app.
Future<void> _syncAlarmSound(String token, SharedPreferences prefs) async {
  try {
    final res = await http.get(
      Uri.parse('${Config.pmBase}/settings/alarm-sound'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return;
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final hasCustom = j['has_custom'] == true;
    final version = (j['version'] as num?)?.toInt() ?? 0;

    if (!hasCustom) {
      await prefs.remove(_kSoundPath);
      await prefs.setInt(_kSoundVer, 0);
      return;
    }
    final curPath = prefs.getString(_kSoundPath);
    if (prefs.getInt(_kSoundVer) == version && curPath != null && File(curPath).existsSync()) {
      return; // sudah terbaru
    }
    final fres = await http.get(
      Uri.parse('${Config.pmBase}/settings/alarm-sound/file'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 30));
    if (fres.statusCode != 200 || fres.bodyBytes.isEmpty) return;

    final name = j['name']?.toString() ?? 'alarm.mp3';
    var ext = '.mp3';
    final dot = name.lastIndexOf('.');
    if (dot >= 0 && dot < name.length - 1) ext = name.substring(dot).toLowerCase();
    final dir = await getApplicationSupportDirectory();
    final path = '${dir.path}/alarm_custom$ext';
    await File(path).writeAsBytes(fres.bodyBytes, flush: true);
    await prefs.setString(_kSoundPath, path);
    await prefs.setInt(_kSoundVer, version);
  } catch (_) {
    // diam
  }
}

Future<void> _fireAlarm(String title, String body, SharedPreferences prefs) async {
  final path = prefs.getString(_kSoundPath);
  if (path != null && File(path).existsSync()) {
    try {
      await _playCustom(path);
      await _showNotif(title, body, silent: true);
      return;
    } catch (_) {
      // gagal muter custom → jatuh ke alarm bawaan
    }
  }
  await _showNotif(title, body, silent: false);
}

Future<void> _playCustom(String path) async {
  _autoStopTimer?.cancel();
  _alarmPlayer ??= AudioPlayer();
  final p = _alarmPlayer!;
  await p.setReleaseMode(ReleaseMode.loop);
  try {
    await p.setAudioContext(AudioContext(
      android: const AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: true,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.alarm, // keluar di stream ALARM (keras walau silent mode)
        audioFocus: AndroidAudioFocus.gain,
      ),
    ));
  } catch (_) {}
  await p.stop();
  await p.play(DeviceFileSource(path), volume: 1.0);
  // Pengaman: berhenti otomatis setelah 60 detik biar gak bunyi selamanya.
  _autoStopTimer = Timer(const Duration(seconds: 60), () => _stopAlarm());
}

Future<void> _stopAlarm() async {
  _autoStopTimer?.cancel();
  _autoStopTimer = null;
  try {
    await _alarmPlayer?.stop();
  } catch (_) {}
  try {
    await _fln.cancel(_alarmNotifId);
  } catch (_) {}
}

Future<void> _showNotif(String title, String body, {required bool silent}) async {
  final actions = <AndroidNotificationAction>[
    const AndroidNotificationAction(_stopActionId, '🔕 Matikan', cancelNotification: true),
  ];
  final details = AndroidNotificationDetails(
    silent ? _alarmSilentChannelId : _alarmChannelId,
    silent ? 'Alarm Produksi (nada custom)' : 'Alarm Produksi',
    channelDescription: 'Notifikasi penting produksi.',
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
    fullScreenIntent: true,
    playSound: !silent, // custom → suara dari audioplayers, bukan channel
    enableVibration: true,
    audioAttributesUsage: AudioAttributesUsage.alarm,
    vibrationPattern: Int64List.fromList([0, 800, 500, 800, 500, 800]),
    // Non-custom: FLAG_INSISTENT (0x4) → suara/getar ulang sampai di-swipe.
    additionalFlags: silent ? null : Int32List.fromList([4]),
    // Non-custom: auto hilang (dan berhenti) setelah 60 detik.
    timeoutAfter: silent ? null : 60000,
    ongoing: silent, // custom → tetap ada selama muter, sampai "Matikan"
    ticker: title,
    styleInformation: BigTextStyleInformation(body),
    actions: actions,
  );
  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    interruptionLevel: InterruptionLevel.timeSensitive,
  );
  await _fln.show(_alarmNotifId, title, body, NotificationDetails(android: details, iOS: iosDetails));
}
