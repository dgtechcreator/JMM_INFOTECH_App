import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Google Play "Prominent Disclosure and Consent" for background location: before the OS permission
/// prompt appears, the app must show its own dialog stating that location is collected (including while
/// the app is closed or not in use), why, and let the user decline. Without this, an app that declares
/// ACCESS_BACKGROUND_LOCATION is rejected at review. Acceptance is remembered so it is shown once; a
/// decline is not remembered, so the user is asked again the next time they start a trip.
class LocationDisclosure {
  static const _acceptedKey = 'location_disclosure_accepted';

  static Future<bool> isAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_acceptedKey) == true;
  }

  static Future<bool> ensureAccepted(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_acceptedKey) == true) return true;
    if (!context.mounted) return false;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.location_on_outlined, size: 32),
        title: const Text('Location access'),
        content: const SingleChildScrollView(
          child: Text(
            'JMM InfoTech collects your location data to record your field-visit trips and to show your '
            'trip route to your admin.\n\n'
            'While a trip is in progress, location is collected in the background — even when the app is '
            'closed or not in use — so the route stays complete. Tracking starts only when you tap Start '
            'Trip and stops when you end the trip.\n\n'
            'Your location is also checked when you punch in or out, to confirm you are at an approved '
            'office location.\n\n'
            'On the next screen, please choose "Allow all the time" for trip tracking to work.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No thanks')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Accept')),
        ],
      ),
    );

    if (accepted == true) {
      await prefs.setBool(_acceptedKey, true);
      return true;
    }
    return false;
  }
}
