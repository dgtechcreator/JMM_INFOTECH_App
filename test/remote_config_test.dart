import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jmm_employee_app/core/api_client.dart';
import 'package:jmm_employee_app/core/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A fake HTTP transport: [handler] decides, per request, whether a "server" answers or the connection fails.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);
  final ResponseBody Function(RequestOptions o) handler;
  final List<String> hosts = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    hosts.add(options.uri.host);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(String body, [int status = 200]) =>
    ResponseBody.fromString(body, status, headers: {Headers.contentTypeHeader: ['application/json']});

DioException _down(RequestOptions o) => DioException.connectionError(requestOptions: o, reason: 'server down');

const _primary = 'portal.jmmportal.com'; // ApiConfig's built-in address
const _backup = 'backup.example.com';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiConfig.resetForTest();
  });

  group('ApiConfig', () {
    test('accepts only https addresses; strips trailing slashes', () {
      expect(ApiConfig.isAcceptable('https://portal.example.com'), isTrue);
      expect(ApiConfig.isAcceptable('http://portal.example.com'), isFalse);
      expect(ApiConfig.isAcceptable(''), isFalse);
      expect(ApiConfig.isAcceptable(null), isFalse);
      expect(ApiConfig.normalize(' https://portal.example.com/// '), 'https://portal.example.com');
    });

    test('candidates: current first, then backups, then built-in, no duplicates', () async {
      await ApiConfig.setFallbacks(['https://$_backup', 'http://insecure.example.com', 'https://$_backup/']);
      await ApiConfig.setActive('https://new.example.com');
      expect(ApiConfig.candidates, ['https://new.example.com', 'https://$_backup', 'https://$_primary']);
    });

    test('setActive with the built-in address clears the override', () async {
      await ApiConfig.setActive('https://new.example.com');
      expect(ApiConfig.baseUrl, 'https://new.example.com');
      await ApiConfig.setActive(ApiConfig.compiledBaseUrl);
      expect(ApiConfig.baseUrl, ApiConfig.compiledBaseUrl);
    });

    test('override and backups survive a restart (loadPersisted)', () async {
      await ApiConfig.setFallbacks(['https://$_backup']);
      await ApiConfig.setActive('https://new.example.com');
      ApiConfig.resetForTest(); // "app restarted": memory is gone, preferences remain
      expect(ApiConfig.baseUrl, ApiConfig.compiledBaseUrl);
      await ApiConfig.loadPersisted();
      expect(ApiConfig.baseUrl, 'https://new.example.com');
      expect(ApiConfig.fallbacks, ['https://$_backup']);
    });
  });

  group('ApiClient failover', () {
    test('primary unreachable -> retried on the backup, which becomes the active address', () async {
      await ApiConfig.setFallbacks(['https://$_backup']);
      final adapter = _FakeAdapter((o) => o.uri.host == _backup ? _json('{"ok":1}') : throw _down(o));
      ApiClient.instance.useAdapter(adapter);

      final res = await ApiClient.instance.get('/EmployeeApp/Ping');

      expect(res.statusCode, 200);
      expect(adapter.hosts, [_primary, _backup]);
      expect(ApiConfig.baseUrl, 'https://$_backup');

      // the next call goes straight to the address that worked
      adapter.hosts.clear();
      await ApiClient.instance.get('/EmployeeApp/Ping');
      expect(adapter.hosts, [_backup]);
    });

    test('a POST with a form body is re-sent intact on the backup', () async {
      await ApiConfig.setFallbacks(['https://$_backup']);
      String? bodyOnBackup;
      final adapter = _FakeAdapter((o) {
        if (o.uri.host != _backup) throw _down(o);
        bodyOnBackup = o.data is FormData ? (o.data as FormData).fields.map((f) => '${f.key}=${f.value}').join('&') : null;
        return _json('{"ok":1}');
      });
      ApiClient.instance.useAdapter(adapter);

      final res = await ApiClient.instance.post('/EmployeeApp/Login', data: {'username': 'a', 'password': 'b'});

      expect(res.statusCode, 200);
      expect(bodyOnBackup, 'username=a&password=b');
    });

    test('a server that answers with an error is NOT failed over', () async {
      await ApiConfig.setFallbacks(['https://$_backup']);
      final adapter = _FakeAdapter((o) => _json('{"message":"boom"}', 500));
      ApiClient.instance.useAdapter(adapter);

      await expectLater(ApiClient.instance.get('/EmployeeApp/Ping'), throwsA(isA<DioException>()));
      expect(adapter.hosts, [_primary]);
      expect(ApiConfig.baseUrl, ApiConfig.compiledBaseUrl);
    });

    test('every address down -> the original connection error surfaces, address unchanged', () async {
      await ApiConfig.setFallbacks(['https://$_backup']);
      final adapter = _FakeAdapter((o) => throw _down(o));
      ApiClient.instance.useAdapter(adapter);

      await expectLater(
        ApiClient.instance.get('/EmployeeApp/Ping'),
        throwsA(isA<DioException>().having((e) => e.type, 'type', DioExceptionType.connectionError)),
      );
      expect(adapter.hosts, [_primary, _backup]);
      expect(ApiConfig.baseUrl, ApiConfig.compiledBaseUrl);
    });
  });

  group('AppConfigController', () {
    AppConfig cfg({String base = '', List<String> fallbacks = const [], int min = 0, bool maintenance = false}) =>
        AppConfig(apiBaseUrl: base, fallbackUrls: fallbacks, minVersionCode: min, maintenanceEnabled: maintenance);

    test('adopts a new server address that answers', () async {
      final asked = <String>[];
      final c = AppConfigController(fetcher: (url) async {
        asked.add(url);
        return cfg(base: 'https://new.example.com');
      });
      await c.refresh();
      expect(ApiConfig.baseUrl, 'https://new.example.com');
      expect(asked, ['https://$_primary', 'https://new.example.com']); // asked the old one, then verified the new one
    });

    test('ignores a new address that does not answer (phones are never stranded)', () async {
      final c = AppConfigController(fetcher: (url) async => url.contains(_primary) ? cfg(base: 'https://typo.example.com') : null);
      await c.refresh();
      expect(ApiConfig.baseUrl, ApiConfig.compiledBaseUrl);
      expect(c.config, isNotNull); // the rest of the settings still apply
    });

    test('never switches to a non-https address', () async {
      final c = AppConfigController(fetcher: (url) async => cfg(base: 'http://plain.example.com'));
      await c.refresh();
      expect(ApiConfig.baseUrl, ApiConfig.compiledBaseUrl);
    });

    test('stores backup addresses (https only)', () async {
      final c = AppConfigController(fetcher: (url) async => cfg(fallbacks: ['https://$_backup', 'http://bad.example.com']));
      await c.refresh();
      expect(ApiConfig.fallbacks, ['https://$_backup']);
    });

    test('when the main address is down but a backup answers, the backup is used', () async {
      await ApiConfig.setFallbacks(['https://$_backup']);
      final c = AppConfigController(fetcher: (url) async => url.contains(_backup) ? cfg(base: 'https://$_primary') : null);
      await c.refresh();
      // the portal says "use the main address", but it did not answer the verification, so stay on the working backup
      expect(ApiConfig.baseUrl, 'https://$_backup');
    });

    test('forceUpdate compares the installed version code with the minimum', () async {
      Future<bool> blockedWithMin(int min) async {
        final c = AppConfigController(fetcher: (u) async => cfg(min: min))..currentVersionCode = 2;
        await c.refresh();
        return c.forceUpdate;
      }

      expect(await blockedWithMin(0), isFalse); // 0 = nobody blocked
      expect(await blockedWithMin(2), isFalse); // equal -> allowed
      expect(await blockedWithMin(5), isTrue); // lower than the minimum -> blocked
    });

    test('maintenance is live-only: shown from a fresh answer, never restored from the cache', () async {
      final live = AppConfigController(fetcher: (u) async => cfg(maintenance: true));
      await live.refresh();
      expect(live.maintenance, isTrue);

      final afterRestart = AppConfigController(); // no network: only the cache
      await afterRestart.init();
      expect(afterRestart.config, isNotNull); // settings were cached...
      expect(afterRestart.maintenance, isFalse); // ...but the maintenance block was not
    });

    test('nobody answers -> no crash, nothing blocked, previous settings kept', () async {
      final c = AppConfigController(fetcher: (u) async => null);
      await c.refresh();
      expect(c.config, isNull);
      expect(c.maintenance, isFalse);
      expect(c.forceUpdate, isFalse);
      expect(ApiConfig.baseUrl, ApiConfig.compiledBaseUrl);
    });
  });
}
