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
    });
    final data = res.data as Map<String, dynamic>;
    if (data['status'] != 'OK') return [];
    return (data['predictions'] as List).cast<Map<String, dynamic>>().map(PlacePrediction.fromJson).toList();
  }

  Future<PlaceLocation?> placeDetails(String placeId) async {
    final res = await _dio.get('https://maps.googleapis.com/maps/api/place/details/json', queryParameters: {
      'place_id': placeId,
      'fields': 'geometry,formatted_address',
      'key': googlePlacesApiKey,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['status'] != 'OK') return null;
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
