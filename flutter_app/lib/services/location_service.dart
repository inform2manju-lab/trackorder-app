import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:sqflite/sqflite.dart';
import 'package:workmanager/workmanager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api_service.dart';

const _taskName = 'syncLocation';

// Called by WorkManager in the background
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == _taskName) {
      await LocationService._syncOfflineQueue();
    }
    return true;
  });
}

class LocationService {
  static StreamSubscription<Position>? _positionStream;
  static Database? _db;

  static Future<void> init() async {
    _db = await openDatabase('location_queue.db', version: 1, onCreate: (db, _) {
      db.execute('''CREATE TABLE IF NOT EXISTS location_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        latitude REAL, longitude REAL, accuracy REAL,
        battery_level INTEGER, recorded_at TEXT, synced INTEGER DEFAULT 0
      )''');
    });

    Workmanager().initialize(callbackDispatcher);
    Workmanager().registerPeriodicTask(
      _taskName, _taskName,
      frequency: const Duration(minutes: 15),
    );
  }

  static Future<bool> requestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
           permission == LocationPermission.always;
  }

  static void startTracking() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,  // update every 50 meters
      ),
    ).listen((Position pos) async {
      await _saveToQueue(pos);
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity != ConnectivityResult.none) {
        await _syncOfflineQueue();
      }
    });
  }

  static void stopTracking() {
    _positionStream?.cancel();
  }

  static Future<void> _saveToQueue(Position pos) async {
    await _db?.insert('location_queue', {
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'accuracy': pos.accuracy,
      'recorded_at': DateTime.now().toIso8601String(),
      'synced': 0,
    });
  }

  static Future<void> _syncOfflineQueue() async {
    final db = _db ?? await openDatabase('location_queue.db');
    final pending = await db.query('location_queue', where: 'synced = 0', limit: 100);

    if (pending.isEmpty) return;

    try {
      await ApiService.logLocationBatch(pending.map((r) => {
        'latitude': r['latitude'],
        'longitude': r['longitude'],
        'accuracy': r['accuracy'],
        'battery_level': r['battery_level'],
      }).toList());

      // Mark as synced
      final ids = pending.map((r) => r['id']).join(',');
      await db.rawUpdate('UPDATE location_queue SET synced = 1 WHERE id IN ($ids)');
    } catch (_) {
      // Will retry on next sync
    }
  }

  static Future<Position> getCurrentPosition() async {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}
