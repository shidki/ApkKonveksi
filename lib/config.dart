// Konfigurasi global aplikasi Apk Stock.
//
// Aplikasi ini nyambung ke backend FastAPI yang SAMA dengan web shid-konten
// (folder backend/app). Endpoint yang dipakai:
//   POST /api/auth/apk/login   → login khusus admin stock
//   POST /api/auth/logout      → logout
//   GET  /api/auth/me          → refresh profil
//   /api/product-management/*  → semua data stock (produk, mutasi, dll)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Config {
  // ── ALAMAT BACKEND ──────────────────────────────────────────────
  // GANTI sesuai tempat backend jalan:
  //   • Emulator Android  → http://10.0.2.2:8000   (10.0.2.2 = localhost laptop)
  //   • HP fisik (1 wifi) → http://<IP-LAPTOP>:8000 (mis. http://192.168.1.10:8000)
  //   • Server online     → https://domain-kamu.com
  //
  // Cara lihat IP laptop: `ipconfig getifaddr en0` (Mac) / `ipconfig` (Windows).
  // HP fisik → pakai IP laptop di WiFi yang sama. (Emulator: ganti ke http://10.0.2.2:8000)
  static const String baseHost = 'http://10.101.10.0:8000';

  static const String apiBase = '$baseHost/api';
  static const String authBase = '$apiBase/auth';
  static const String pmBase = '$apiBase/product-management';

  // Permission yang wajib dimiliki akun buat bisa login di sini
  // (harus sama dengan APK_PERM di backend routes_auth.py).
  static const String requiredPerm = 'product_management';
}

/// Palet & tema aplikasi — desain modern, lembut, konsisten.
class AppTheme {
  // ── Warna brand ──
  static const Color primary = Color(0xFF0D9488); // teal-600
  static const Color primaryDark = Color(0xFF0F766E); // teal-700
  static const Color primaryLight = Color(0xFF14B8A6); // teal-500

  // ── Netral / permukaan ──
  static const Color bg = Color(0xFFF6F8FB); // latar utama (abu sangat muda)
  static const Color surface = Colors.white;
  static const Color soft = Color(0xFFF1F5F9); // slate-100
  static const Color border = Color(0xFFE9EEF4);
  static const Color ink = Color(0xFF0F172A); // teks utama
  static const Color muted = Color(0xFF64748B); // teks sekunder
  static const Color faint = Color(0xFF94A3B8); // teks lemah

  // ── Aksen status ──
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF16A34A);
  static const Color info = Color(0xFF2563EB);

  // ── Gradien brand (dipakai header, login, tombol utama) ──
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)],
  );

  // ── Bayangan lembut untuk kartu ──
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.05),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];

  static ThemeData build() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      surface: surface,
      brightness: Brightness.light,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      useMaterial3: true,
      fontFamily: 'Roboto',
      splashColor: primary.withValues(alpha: 0.08),
      highlightColor: primary.withValues(alpha: 0.04),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: ink, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: ink, fontWeight: FontWeight.w700),
        bodyMedium: TextStyle(color: ink),
        bodySmall: TextStyle(color: muted),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: soft,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: const TextStyle(color: faint, fontSize: 14),
        labelStyle: const TextStyle(color: muted, fontSize: 14),
        prefixIconColor: muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: danger, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primary.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryDark,
          side: const BorderSide(color: border),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryDark),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: border),
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}
