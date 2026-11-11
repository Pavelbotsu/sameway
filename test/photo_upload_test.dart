import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sameway/core/api_client.dart';
import 'package:sameway/core/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'jwt': 'tok'}));

  test('profile photo goes to the backend as multipart', () async {
    final dir = await Directory.systemTemp.createTemp('photo');
    final file = File('${dir.path}/me.jpg')..writeAsBytesSync([0xFF, 0xD8, 1, 2, 3]);
    late http.BaseRequest seen;
    final res = await http.runWithClient(
      () => ApiClient(TokenStorage())
          .uploadFile('/auth/profile/photo', field: 'photo', filePath: file.path),
      () => MockClient((req) async {
        seen = req;
        return http.Response('{"photo_url":"/photos/abc.jpg"}', 200);
      }),
    );
    expect(res['photo_url'], '/photos/abc.jpg');
    expect(seen.url.path, '/auth/profile/photo');
    expect(seen.headers['Authorization'], 'Bearer tok');
    expect(seen.headers['content-type'], startsWith('multipart/form-data'));
    await dir.delete(recursive: true);
  });

  test('server-relative photo URLs get the API host', () {
    expect(resolvePhotoUrl('/photos/a.jpg'), '$kApiBase/photos/a.jpg');
    expect(resolvePhotoUrl('https://x.example/a.jpg'), 'https://x.example/a.jpg');
  });
}
