import 'package:geolocator/geolocator.dart';

/// Best-effort GPS fetch for punch in/out — mirrors the web Quick Punch card's own approach
/// (Views/Shared/_EmployeeProfileTabs.cshtml's punchAction()): try to get a location, but never block
/// the punch itself if permission is denied or unavailable. Returns null lat/lng on any failure.
class LocationHelper {
  static Future<(double?, double?)> tryGetLatLng() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return (null, null);
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        return (null, null);
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 6)),
      );
      return (pos.latitude, pos.longitude);
    } catch (_) {
      return (null, null);
    }
  }
}
