import 'package:flutter_test/flutter_test.dart';
import 'package:sameway/core/legal.dart';

void main() {
  test('legal pages open in the app language when it exists', () {
    expect(legalUrlFor('https://x/legal/terms', 'pl'), 'https://x/legal/terms?lang=pl');
    expect(legalUrlFor('https://x/legal/terms', 'uk'), 'https://x/legal/terms?lang=uk');
    // de/fr/es/it have no translation yet: English.
    expect(legalUrlFor('https://x/legal/privacy', 'de'), 'https://x/legal/privacy?lang=en');
  });

  test('terms version matches the backend (models.CurrentTermsVersion)', () {
    expect(kTermsVersion, 2);
  });
}
