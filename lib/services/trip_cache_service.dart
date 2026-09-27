import 'package:sqflite/sqflite.dart';

/// Local on-device cache for trip location pings — the whole point of the 2026-09-27 battery-friendly
/// rework: geolocator's distance-filtered stream (see TripTrackingService) only fires a new reading every
/// ~20m of actual movement, and each reading is written here immediately (fast, no network call, no
/// battery cost beyond the GPS fix itself) rather than posted to the server one at a time. A periodic
/// timer flushes everything cached for the active trip in one batch call roughly every 20 minutes, which
/// is what actually saves battery and avoids hammering the server — dozens of individual small pings
/// become one request.
class CachedPing {
  CachedPing({this.id, required this.tripId, required this.lat, required this.lng, required this.capturedOn});

  final int? id;
  final int tripId;
  final double lat;
  final double lng;
  final DateTime capturedOn;

  factory CachedPing.fromMap(Map<String, dynamic> m) => CachedPing(
        id: m['id'] as int?,
        tripId: m['tripId'] as int,
        lat: m['lat'] as double,
        lng: m['lng'] as double,
        capturedOn: DateTime.parse(m['capturedOn'] as String),
      );
}

class TripCacheService {
  static Database? _db;

  // Opening the same on-disk sqlite file from both the UI isolate and the background-service isolate is
  // safe — sqflite/SQLite itself serializes access at the native layer — but each isolate needs its own
  // `Database` handle (a Dart object can't cross isolates), hence the per-isolate cache here rather than
  // a single static instance shared everywhere.
  static Future<Database> _database() async {
    if (_db != null) return _db!;
    final dbDir = await getDatabasesPath();
    final path = '$dbDir/trip_ping_cache.db';
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cached_pings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tripId INTEGER NOT NULL,
            lat REAL NOT NULL,
            lng REAL NOT NULL,
            capturedOn TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  static Future<void> addPing(int tripId, double lat, double lng, DateTime capturedOn) async {
    final db = await _database();
    await db.insert('cached_pings', {
      'tripId': tripId,
      'lat': lat,
      'lng': lng,
      'capturedOn': capturedOn.toIso8601String(),
    });
  }

  static Future<List<CachedPing>> getPending(int tripId) async {
    final db = await _database();
    final rows = await db.query('cached_pings', where: 'tripId = ?', whereArgs: [tripId], orderBy: 'capturedOn ASC');
    return rows.map(CachedPing.fromMap).toList();
  }

  static Future<void> clearSynced(int tripId, List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await _database();
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.delete('cached_pings', where: 'tripId = ? AND id IN ($placeholders)', whereArgs: [tripId, ...ids]);
  }

  static Future<void> clearAllForTrip(int tripId) async {
    final db = await _database();
    await db.delete('cached_pings', where: 'tripId = ?', whereArgs: [tripId]);
  }
}
