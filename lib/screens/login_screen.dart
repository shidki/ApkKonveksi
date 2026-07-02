// Layar login — pakai endpoint /api/auth/apk/login.
// Backend nolak (403) akun yang bukan pengelola stock, pesannya ditampilkan.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../auth.dart';
import '../config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().login(_email.text, _pass.text);
      // sukses → _Gate otomatis pindah ke Home
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Gagal terhubung ke server. Cek koneksi & alamat backend.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // ── Logo ──
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: const Icon(Icons.inventory_2_rounded, size: 46, color: Colors.white),
                  ),
                  const SizedBox(height: 18),
                  const Text('Apk Stock',
                      style: TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3)),
                  const SizedBox(height: 4),
                  Text('Manajemen Stok Konveksi',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14)),
                  const SizedBox(height: 30),
                  // ── Kartu form ──
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Selamat datang 👋',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                          const SizedBox(height: 4),
                          const Text('Masuk pakai akun pengelola stok kamu.',
                              style: TextStyle(color: AppTheme.muted, fontSize: 13)),
                          const SizedBox(height: 22),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                                labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Email wajib diisi' : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _pass,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? 'Password wajib diisi' : null,
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: AppTheme.danger.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.danger.withValues(alpha: 0.2))),
                              child: Row(children: [
                                const Icon(Icons.error_outline, color: AppTheme.danger, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(_error!,
                                        style: const TextStyle(color: AppTheme.danger, fontSize: 13))),
                              ]),
                            ),
                          ],
                          const SizedBox(height: 22),
                          FilledButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                : const Text('Masuk'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.dns_outlined, size: 13, color: Colors.white.withValues(alpha: 0.6)),
                    const SizedBox(width: 6),
                    Text(Config.baseHost.replaceAll(RegExp(r'https?://'), ''),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
                  ]),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
