// Apk Stock — aplikasi Android manajemen stock (konveksi).
// Nyambung ke backend FastAPI shid-konten. Login khusus admin stock.
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'auth.dart';
import 'config.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null); // format tanggal/uang Indonesia
  final auth = AuthProvider();
  await auth.boot(); // pulihkan sesi dari token tersimpan (kalau ada)
  runApp(ChangeNotifierProvider.value(value: auth, child: const ApkStockApp()));
}

class ApkStockApp extends StatelessWidget {
  const ApkStockApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Apk Stock',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const _Gate(),
    );
  }
}

/// Gerbang: kalau sudah login → Home, kalau belum → Login.
class _Gate extends StatelessWidget {
  const _Gate();
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.booting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return auth.isLoggedIn ? const HomeShell() : const LoginScreen();
  }
}
