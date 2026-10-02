import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jmm_employee_app/core/app_config.dart';
import 'package:jmm_employee_app/core/maps_config.dart';
import 'package:jmm_employee_app/services/places_service.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final ResponseBody Function(RequestOptions o) handler;
  final List<RequestOptions> seen = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    seen.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, [int status = 200]) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {Headers.contentTypeHeader: ['application/json']});

Map<String, dynamic> _error(int code, String status, String message) => {
      'error': {'code': code, 'status': status, 'message': message}
    };

const _suggestions = {
  'suggestions': [
    {
      'placePrediction': {
        'placeId': 'ChIJabc',
        'text': {'text': 'Andheri East, Mumbai, Maharashtra, India'}
      }
    },
    {
      'queryPrediction': {
        'text': {'text': 'andheri hotels'}
      }
    },
  ]
};

void main() {
  setUp(() => RemoteKeys.placesKey = null);

  test('autocomplete: Places API (New) request shape and response parsing', () async {
    final a = _Adapter((o) => _json(_suggestions));
    final service = PlacesService(dio: Dio()..httpClientAdapter = a);

    final out = await service.autocomplete('andheri');

    expect(out, hasLength(1)); // the free-text "query prediction" has no place to pin, so it is skipped
    expect(out.first.placeId, 'ChIJabc');
    expect(out.first.description, 'Andheri East, Mumbai, Maharashtra, India');
    final req = a.seen.single;
    expect(req.uri.toString(), 'https://places.googleapis.com/v1/places:autocomplete');
    expect(req.method, 'POST');
    expect(req.headers['X-Goog-Api-Key'], googlePlacesApiKey);
    expect((req.data as Map)['includedRegionCodes'], ['in']);
  });

  test('autocomplete: ignores input shorter than 3 characters', () async {
    final a = _Adapter((o) => _json(_suggestions));
    expect(await PlacesService(dio: Dio()..httpClientAdapter = a).autocomplete('an'), isEmpty);
    expect(a.seen, isEmpty);
  });

  test('one session token across a search, cleared once a place is picked', () async {
    final a = _Adapter((o) => o.uri.path.contains('autocomplete')
        ? _json(_suggestions)
        : _json({'location': {'latitude': 19.1136, 'longitude': 72.8697}, 'formattedAddress': 'Andheri East'}));
    final service = PlacesService(dio: Dio()..httpClientAdapter = a);

    await service.autocomplete('andh');
    await service.autocomplete('andhe');
    final loc = await service.placeDetails('ChIJabc');
    await service.autocomplete('andheri');

    final t1 = (a.seen[0].data as Map)['sessionToken'];
    final t2 = (a.seen[1].data as Map)['sessionToken'];
    final t3 = (a.seen[3].data as Map)['sessionToken'];
    expect(t1, isNotNull);
    expect(t2, t1); // same session while typing
    expect(a.seen[2].queryParameters['sessionToken'], t1); // details closes that session
    expect(t3, isNot(t1)); // next search = new session
    expect(loc!.lat, 19.1136);
    expect(loc.lng, 72.8697);
    expect(loc.address, 'Andheri East');
    expect(a.seen[2].headers['X-Goog-FieldMask'], 'location,formattedAddress');
  });

  test('portal key is used when set', () async {
    RemoteKeys.placesKey = 'AIzaPortalKeyForTesting000000000000000';
    final a = _Adapter((o) => _json(_suggestions));
    await PlacesService(dio: Dio()..httpClientAdapter = a).autocomplete('andheri');
    expect(a.seen.single.headers['X-Goog-Api-Key'], 'AIzaPortalKeyForTesting000000000000000');
  });

  test('a rejected portal key falls back to the built-in key (search keeps working)', () async {
    RemoteKeys.placesKey = 'AIzaMistypedPortalKey0000000000000000';
    final a = _Adapter((o) => o.headers['X-Goog-Api-Key'] == googlePlacesApiKey
        ? _json(_suggestions)
        : _json(_error(403, 'PERMISSION_DENIED', 'API key not valid'), 403));

    final out = await PlacesService(dio: Dio()..httpClientAdapter = a).autocomplete('andheri');

    expect(out, hasLength(1));
    expect(a.seen.map((r) => r.headers['X-Goog-Api-Key']).toList(), ['AIzaMistypedPortalKey0000000000000000', googlePlacesApiKey]);
  });

  test('an error that is not about the key is not retried and surfaces the real reason', () async {
    RemoteKeys.placesKey = 'AIzaPortalKeyForTesting000000000000000';
    final a = _Adapter((o) => _json(_error(400, 'INVALID_ARGUMENT', 'bad input'), 400));

    await expectLater(
      PlacesService(dio: Dio()..httpClientAdapter = a).autocomplete('andheri'),
      throwsA(isA<PlacesApiException>().having((e) => e.status, 'status', 'INVALID_ARGUMENT')),
    );
    expect(a.seen, hasLength(1));
  });

  test('both keys rejected -> a clear PERMISSION_DENIED error', () async {
    final a = _Adapter((o) => _json(_error(403, 'PERMISSION_DENIED', 'Places API (New) has not been used in project'), 403));
    await expectLater(
      PlacesService(dio: Dio()..httpClientAdapter = a).autocomplete('andheri'),
      throwsA(isA<PlacesApiException>().having((e) => e.isKeyProblem, 'isKeyProblem', true)),
    );
  });

  test('reverseGeocode returns the address, or null on any failure', () async {
    final ok = _Adapter((o) => _json({
          'status': 'OK',
          'results': [
            {'formatted_address': 'Sakinaka, Mumbai'}
          ]
        }));
    expect(await PlacesService(dio: Dio()..httpClientAdapter = ok).reverseGeocode(19.1, 72.8), 'Sakinaka, Mumbai');

    final denied = _Adapter((o) => _json({'status': 'REQUEST_DENIED', 'error_message': 'nope'}));
    expect(await PlacesService(dio: Dio()..httpClientAdapter = denied).reverseGeocode(19.1, 72.8), isNull);
  });
}
