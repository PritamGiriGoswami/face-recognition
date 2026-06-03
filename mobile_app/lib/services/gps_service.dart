import 'package:geolocator/geolocator.dart';

class GpsService {
  GpsService._privateConstructor();
  static final GpsService _instance = GpsService._privateConstructor();
  factory GpsService() => _instance;

  // Ensure location services are enabled and permissions granted.
  Future<bool> _ensurePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  // Get a single current position.
  Future<Position?> getCurrentPosition() async {
    if (!await _ensurePermission()) return null;
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  // Continuous stream of position updates.
  Stream<Position> get positionStream async* {
    if (!await _ensurePermission()) return;
    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10,
      ),
    );
  }
}
