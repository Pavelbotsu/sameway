import 'package:flutter_test/flutter_test.dart';
import 'package:sameway/core/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemStore implements SecretStore {
  final Map<String, String> data = {};
  bool broken = false;

  void _check() {
    if (broken) throw Exception('keystore unavailable');
  }

  @override
  Future<String?> read(String key) async {
    _check();
    return data[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _check();
    data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _check();
    data.remove(key);
  }
}

void main() {
  late _MemStore store;
  setUp(() => store = _MemStore());

  test('save keeps the token out of SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    final s = TokenStorage(secure: store);
    await s.save(token: 't1', role: 'driver', userId: 'u1');

    final p = await SharedPreferences.getInstance();
    expect(p.getString('jwt'), isNull);
    expect(p.getString('role'), 'driver');
    expect(store.data['jwt'], 't1');
    expect(await s.getToken(), 't1');
  });

  test('a token from an old install is migrated on first read', () async {
    SharedPreferences.setMockInitialValues({'jwt': 'old'});
    final s = TokenStorage(secure: store);

    expect(await s.getToken(), 'old');
    final p = await SharedPreferences.getInstance();
    expect(p.getString('jwt'), isNull);
    expect(store.data['jwt'], 'old');
    expect(await s.getToken(), 'old');
  });

  test('a broken secret store falls back to prefs instead of logging out',
      () async {
    SharedPreferences.setMockInitialValues({'jwt': 'old'});
    store.broken = true;
    final s = TokenStorage(secure: store);

    expect(await s.getToken(), 'old');
    await s.save(token: 'new', role: 'passenger', userId: 'u1');
    final p = await SharedPreferences.getInstance();
    expect(p.getString('jwt'), 'new');
    expect(await s.getToken(), 'new');

    // Once the store works again the fallback copy moves over.
    store.broken = false;
    expect(await s.getToken(), 'new');
    expect(p.getString('jwt'), isNull);
    expect(store.data['jwt'], 'new');
  });

  test('clear removes both copies', () async {
    SharedPreferences.setMockInitialValues({'jwt': 'a'});
    store.data['jwt'] = 'b';
    final s = TokenStorage(secure: store);

    await s.clear();
    expect(await s.getToken(), isNull);
    expect(store.data, isEmpty);
  });
}
