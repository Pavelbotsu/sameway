import 'package:flutter_test/flutter_test.dart';
import 'package:sameway/core/api_client.dart';

void main() {
  String? check(String host, {bool store = true, bool insecure = false}) =>
      storeBuildProblem(storeBuild: store, host: host, insecure: insecure);

  test('ordinary builds are never blocked, whatever the host', () {
    expect(check('ibuprofen-dolly-prison.ngrok-free.dev', store: false), isNull);
    expect(check('10.0.2.2:4040', store: false, insecure: true), isNull);
  });

  test('store builds refuse test backends', () {
    expect(check('ibuprofen-dolly-prison.ngrok-free.dev'), contains('ngrok'));
    expect(check('10.0.2.2:4040'), contains('local'));
    expect(check('localhost:4040'), contains('local'));
    expect(check('127.0.0.1:4040'), contains('local'));
    expect(check(''), contains('empty'));
    expect(check('api.sameway.pl', insecure: true), contains('http'));
  });

  test('store build against a real https host is fine', () {
    expect(check('api.sameway.pl'), isNull);
  });

  test('this test run (no defines) is not a store build', () {
    expect(kStoreBuild, isFalse);
    expect(storeBuildProblem(), isNull);
  });
}
