# Apk Stock — Aplikasi Android Manajemen Stock

Aplikasi Android (Flutter) untuk manajemen stock konveksi. Nyambung ke backend
FastAPI yang **sama** dengan web `shid-konten` (folder `../shid-konten/backend`).
Login **khusus akun pengelola stock** (punya permission `product_management`
atau admin) lewat endpoint `POST /api/auth/apk/login`.

## Fitur / Menu
- **Dashboard** — KPI (total produk, unit, nilai inventori, perlu perhatian), mutasi stok terbaru, daftar stok menipis/habis.
- **Produk** — CRUD lengkap, stok **per ukuran** (varian), sama seperti web.
- **Penerimaan Stok** — catat barang masuk (stok bertambah per ukuran).
- **Transfer Gudang** — pindah stok antar gudang.
- **Opname** — sesuaikan stok sistem ke hasil hitung fisik (selisih otomatis).
- **Kartu Stok** — riwayat mutasi 1 produk + saldo berjalan.
- **Laporan Stok** — daftar produk + filter gudang/kategori + ringkasan nilai.

## Cara menjalankan (dev)

1. **Jalankan backend** dulu (dari folder shid-konten/backend):
   ```bash
   cd ../shid-konten/backend
   .venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
   ```
   Catatan: `--host 0.0.0.0` biar bisa diakses dari emulator/HP.

2. **Set alamat backend** di `lib/config.dart` → `Config.baseHost`:
   - Emulator Android → `http://10.0.2.2:8000` (default, sudah diisi)
   - HP fisik (1 WiFi) → `http://<IP-LAPTOP>:8000` (cek IP: `ipconfig getifaddr en0`)

3. **Run app**:
   ```bash
   flutter pub get
   flutter run          # ke emulator/HP yang tersambung
   ```

4. **Login** pakai akun yang punya akses stock (permission `product_management`).
   Kalau akun nggak punya akses → ditolak "Akun ini tidak punya akses ke aplikasi stock".

## Build APK
```bash
flutter build apk --release
# hasil: build/app/outputs/flutter-apk/app-release.apk
```

## Struktur kode (`lib/`)
- `config.dart` — alamat backend + tema warna (teal, samain sama web).
- `models.dart` — model data (Product, Variant, StockMove, dll) sesuai JSON backend.
- `api.dart` — semua panggilan HTTP ke backend.
- `auth.dart` — state login + simpan token (shared_preferences).
- `ui.dart` — helper format uang/tanggal + widget kecil.
- `screens/` — tiap layar (login, home shell, dashboard, produk, transaksi, laporan).

## Catatan keamanan
Token masih sederhana (`user-<id>`, belum JWT) — ikut backend. Untuk produksi
sebaiknya backend pindah ke JWT + expiry; app ini tinggal ganti cara simpan token.
`usesCleartextTraffic=true` di AndroidManifest hanya buat dev (HTTP localhost);
kalau backend sudah HTTPS, sebaiknya dimatikan.
