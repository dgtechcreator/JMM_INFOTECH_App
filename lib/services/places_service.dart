import 'package:dio/dio.dart';

import '../core/maps_config.dart';

class PlacePrediction {
  PlacePrediction({required this.placeId, required this.description});
  factory PlacePrediction.fromJson(Map<String, dynamic> j) =>
      PlacePrediction(placeId: j['place_id'] as String, description: j['description'] as String? ?? '');
  final String placeId;
  final String description;
}

class PlaceLocation {
  PlaceLocation({required this.lat, required this.lng, required this.address});
  final double lat;
  final double lng;
  final String address;
}

/// Thrown when Google's Places/Geocoding REST APIs return a non-OK status (e.g. REQUEST_DENIED for
/// a misconfigured/restricted API key, OVER_QUERY_LIMIT, INVALID_REQUEST). Previously these were
/// swallowed and the caller just saw an empty result — which looked identical to "no matches" and
/// made a bad API key indistinguishable from a real empty search. Surfacing it lets the UI show the
/// actual reason instead of a dropdown that silently never appears.
class PlacesApiException implements Exception {
  PlacesApiException(this.status, this.errorMessage);
  final String status;
  final String? errorMessage;
  @override
  String toString() => errorMessage ?? status;
}

/// Thin wrapper around Google's Places Autocomplete + Place Details REST APIs, used by the
/// destination-search box on the Assign Visit screen (and anywhere else a map needs "search then pin").
/// Uses a bare Dio instance, not ApiClient.instance — that one is scoped to the JMM backend's baseUrl
/// and auth token, neither of which apply to Google's API.
class PlacesService {
  final _dio = Dio();

  Future<List<PlacePrediction>> autocomplete(String input) async {
    if (input.trim().length < 3) return [];
    final res = await _dio.get('https://maps.googleapis.com/maps/api/place/autocomplete/json', queryParameters: {
      'input': input,
      'key': googlePlacesApiKey,
      // India-only for now (this ERP's field-visit assignments are all domestic) — without this, a
      // short/generic query can autocomplete to a same-named place in another country entirely (this is
      // exactly how "Seawood" resolved to Lee's Summit, Missouri instead of anywhere in India).
      'components': 'country:in',
    });
    final data = res.data as Map<String, dynamic>;
    final status = data['status'] as String? ?? 'UNKNOWN_ERROR';
    if (status == 'ZERO_RESULTS') return [];
    if (status != 'OK') throw PlacesApiException(status, data['error_message'] as String?);
    return (data['predictions'] as List).cast<Map<String, dynamic>>().map(PlacePrediction.fromJson).toList();
  }

  Future<PlaceLocation?> placeDetails(String placeId) async {
    final res = await _dio.get('https://maps.googleapis.com/maps/api/place/details/json', queryParameters: {
      'place_id': placeId,
      'fields': 'geometry,formatted_address',
      'key': googlePlacesApiKey,
    });
    final data = res.data as Map<String, dynamic>;
    final status = data['status'] as String? ?? 'UNKNOWN_ERROR';
    if (status != 'OK') throw PlacesApiException(status, data['error_message'] as String?);
    final result = data['result'] as Map<String, dynamic>;
    final location = (result['geometry'] as Map<String, dynamic>)['location'] as Map<String, dynamic>;
    return PlaceLocation(
      lat: (location['lat'] as num).toDouble(),
      lng: (location['lng'] as num).toDouble(),
      address: result['formatted_address'] as String? ?? '',
    );
  }

  /// Best-effort address lookup for a lat/lng the user picked by tapping the map directly (rather than
  /// searching) — mirrors the web admin map's reverse-geocode-on-click behavior.
  Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final res = await _dio.get('https://maps.googleapis.com/maps/api/geocode/json', queryParameters: {
        'latlng': '$lat,$lng',
        'key': googlePlacesApiKey,
      });
      final data = res.data as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;
      final results = data['results'] as List;
      if (results.isEmpty) return null;
      return (results.first as Map<String, dynamic>)['formatted_address'] as String?;
    } catch (_) {
      return null;
    }
  }
}
