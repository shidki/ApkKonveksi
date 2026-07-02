// Smoke test dasar untuk Apk Stock.
import 'package:flutter_test/flutter_test.dart';
import 'package:apk_stock/config.dart';

void main() {
  test('Konfigurasi backend & tema termuat', () {
    expect(Config.apiBase, contains('/api'));
    expect(AppTheme.build(), isNotNull);
  });
}
