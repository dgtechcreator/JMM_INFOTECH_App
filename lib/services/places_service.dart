import 'dart:math';

import 'package:dio/dio.dart';

import '../core/app_config.dart';
import '../core/maps_config.dart';

class PlacePrediction {
  PlacePrediction({required this.placeId, required this.description});
  final String placeId;
  final String description;
}

class PlaceLocation {
  PlaceLocation({required this.lat, required this.lng, required this.address});
  final double lat;
  final double lng;
  final String address;
}

/// Thrown when Google's Places/Geocoding REST APIs refuse a request (e.g. PERMISSION_DENIED for a key that is
/// not enabled for the API or is app-restricted, RESOURCE_EXHAUSTED for quota, INVALID_ARGUMENT). These used to
/// be swallowed and the caller just saw an empty result — indistinguishable from "no matches". Surfacing it lets
/// the UI show the real reason instead of a dropdown that silently never appears.
class PlacesApiException implements Exception {
  PlacesApiException(this.status, this.errorMessage);
  final String status;
  final String? errorMessage;
  bool get isKeyProblem => status == 'PERMISSION_DENIED' || status == 'REQUEST_DENIED' || status == 'UNAUTHENTICATED';
  @override
  String toString() => errorMessage ?? status;
}

/// Thin wrapper around Google's Places API (New) autocomplete + place details, and the Geocoding API, used by
/// the destination-search box on the Assign Visit screen (and anywhere a map needs "search then pin").
///
/// Moved from the legacy Places endpoints (maps/api/place/...) to Places API (New) on 2026-10-02: Google no
/// longer lets newly created Cloud projects enable the legacy one.
///
/// The API key comes from the portal (Mobile App Settings -> "Search & address API key", delivered through
/// [RemoteKeys]) with the key built into the app as fallback — if Google rejects the portal key for a
/// key-related reason, the request is retried once with the built-in key, so a mistyped portal value can't
/// kill search. Uses a bare Dio, not ApiClient.instance: that one is scoped to the JMM backend's base URL and
/// auth token, neither of which apply to Google.
class PlacesService {
  PlacesService({Dio? dio}) : _dio = dio ?? Dio();
  final Dio _dio;

  // One token per search session (typing -> pick a result) lets Google bill the whole session as one unit.
  String? _sessionToken;

  static String _newSessionToken() {
    final r = Random.secure();
    String hex(int n) => List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-${(8 + r.nextInt(4)).toRadixString(16)}${hex(3)}-${hex(12)}';
  }

  static String? get _remoteKey => (RemoteKeys.placesKey?.isNotEmpty ?? false) ? RemoteKeys.placesKey : null;

  /// Runs [call] with the portal key, falling back to the built-in key when Google rejects the portal key.
  Future<T> _withKey<T>(Future<T> Function(String key) call) async {
    final remote = _remoteKey;
    if (remote == null || remote == googlePlacesApiKey) return call(googlePlacesApiKey);
    try {
      return await call(remote);
    } on PlacesApiException catch (e) {
      if (!e.isKeyProblem) rethrow;
      return call(googlePlacesApiKey);
    }
  }

  PlacesApiException _toException(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      return PlacesApiException('${err['status'] ?? 'UNKNOWN_ERROR'}', err['message'] as String?);
    }
    return PlacesApiException('UNKNOWN_ERROR', e.message);
  }

  Future<List<PlacePrediction>> autocomplete(String input) {
    if (input.trim().length < 3) return Future.value([]);
    _sessionToken ??= _newSessionToken();
    return _withKey((key) async {
      try {
        final res = await _dio.post(
          'https://places.googleapis.com/v1/places:autocomplete',
          data: {
            'input': input,
            // India-only for now (this ERP's field-visit assignments are all domestic) — without this, a
            // short/generic query can autocomplete to a same-named place in another country entirely (this is
            // exactly how "Seawood" resolved to Lee's Summit, Missouri instead of anywhere in India).
            'includedRegionCodes': ['in'],
            'sessionToken': _sessionToken,
          },
          options: Options(headers: {'X-Goog-Api-Key': key, 'Content-Type': 'application/json'}),
        );
        final suggestions = (res.data is Map ? (res.data as Map)['suggestions'] : null) as List? ?? const [];
        final out = <PlacePrediction>[];
        for (final s in suggestions) {
          final p = (s as Map)['placePrediction'];
          if (p is! Map) continue; // query predictions have no place to pin
          final id = p['placeId'] as String?;
          final text = (p['text'] is Map ? (p['text'] as Map)['text'] : null) as String?;
          if (id != null) out.add(PlacePrediction(placeId: id, description: text ?? ''));
        }
        return out;
      } on DioException catch (e) {
        throw _toException(e);
      }
    });
  }

  Future<PlaceLocation?> placeDetails(String placeId) {
    final token = _sessionToken;
    _sessionToken = null; // the session ends when a result is picked
    return _withKey((key) async {
      try {
        final res = await _dio.get(
          'https://places.googleapis.com/v1/places/$placeId',
          queryParameters: {'sessionToken': ?token},
          options: Options(headers: {'X-Goog-Api-Key': key, 'X-Goog-FieldMask': 'location,formattedAddress'}),
        );
        final data = res.data as Map<String, dynamic>;
        final location = data['location'] as Map<String, dynamic>?;
        if (location == null) return null;
        return PlaceLocation(
          lat: (location['latitude'] as num).toDouble(),
          lng: (location['longitude'] as num).toDouble(),
          address: data['formattedAddress'] as String? ?? '',
        );
      } on DioException catch (e) {
        throw _toException(e);
      }
    });
  }

  /// Best-effort address lookup for a lat/lng the user picked by tapping the map directly (rather than
  /// searching) — mirrors the web admin map's reverse-geocode-on-click behavior.
  Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      return await _withKey((key) async {
        final res = await _dio.get('https://maps.googleapis.com/maps/api/geocode/json', queryParameters: {
          'latlng': '$lat,$lng',
          'key': key,
        });
        final data = res.data as Map<String, dynamic>;
        final status = data['status'] as String?;
        if (status == 'REQUEST_DENIED') throw PlacesApiException(status!, data['error_message'] as String?);
        if (status != 'OK') return null;
        final results = data['results'] as List;
        if (results.isEmpty) return null;
        return (results.first as Map<String, dynamic>)['formatted_address'] as String?;
      });
    } catch (_) {
      return null;
    }
  }
}
