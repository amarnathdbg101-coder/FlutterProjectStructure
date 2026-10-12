import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final String? address;
  final String? city;
  final String? pincode;
  final String googleMapsUrl;
  final String? error;

  LocationResult({
    required this.latitude,
    required this.longitude,
    this.address,
    this.city,
    this.pincode,
    required this.googleMapsUrl,
    this.error,
  });

  factory LocationResult.failure(String errorMessage) {
    return LocationResult(
      latitude: 0.0,
      longitude: 0.0,
      googleMapsUrl: '',
      error: errorMessage,
    );
  }

  bool get isSuccess => error == null && latitude != 0.0 && longitude != 0.0;
}

class LocationService {
  /// Fetches real device hardware GPS coordinates with high accuracy.
  /// Falls back gracefully with descriptive error messages.
  static Future<LocationResult> getCurrentLiveLocation() async {
    try {
      // 1. Check if hardware location service is turned ON
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult.failure(
          'Location services (GPS) are turned off on your device. Please turn ON GPS in your phone settings.',
        );
      }

      // 2. Check and request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult.failure(
            'Location permission was denied. Please allow location access to capture your shop GPS.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult.failure(
          'Location permissions are permanently denied. Please enable them in your device App Settings.',
        );
      }

      // 3. Query hardware GPS fix (with fallback to lastKnownPosition on timeout)
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (e) {
        debugPrint('[LocationService] High accuracy GPS fix timed out, checking last known position: $e');
        position = await Geolocator.getLastKnownPosition();
        if (position == null) {
          try {
            position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 8),
              ),
            );
          } catch (_) {}
        }
      }

      if (position == null) {
        return LocationResult.failure(
          'Unable to acquire GPS fix. Please ensure location/GPS is active and try again.',
        );
      }

      final lat = position.latitude;
      final lng = position.longitude;
      final mapsUrl = 'https://www.google.com/maps?q=$lat,$lng';

      // 4. Reverse geocode coordinates to discover real local street, city, and pincode
      String? resolvedCity;
      String? resolvedPincode;
      String? resolvedAddress;

      try {
        final dio = Dio();
        final res = await dio.get(
          'https://nominatim.openstreetmap.org/reverse',
          queryParameters: {
            'lat': lat,
            'lon': lng,
            'format': 'json',
            'accept-language': 'en',
          },
          options: Options(
            headers: {'User-Agent': 'ShopSilo-Merchant-OS/1.0'},
            sendTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 4),
          ),
        );

        if (res.data != null && res.data is Map) {
          final addr = res.data['address'];
          if (addr is Map) {
            resolvedCity = (addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'] ?? addr['state_district'])?.toString();
            resolvedPincode = addr['postcode']?.toString();
            final road = (addr['road'] ?? addr['suburb'] ?? addr['neighbourhood'])?.toString();
            if (road != null && road.isNotEmpty) {
              resolvedAddress = road;
            }
          }
        }
      } catch (e) {
        debugPrint('[LocationService] Reverse geocoding non-critical warning: $e');
      }

      return LocationResult(
        latitude: lat,
        longitude: lng,
        address: resolvedAddress,
        city: resolvedCity,
        pincode: resolvedPincode,
        googleMapsUrl: mapsUrl,
      );
    } catch (e) {
      debugPrint('[LocationService] Live GPS fetch error: $e');
      return LocationResult.failure('Failed to fetch GPS location: $e');
    }
  }

  /// Extracts exact coordinates from any Google Maps URL or text
  static Map<String, double>? extractCoordinatesFromMapsUrl(String text) {
    if (text.trim().isEmpty) return null;
    final trimmed = text.trim();

    // Query parameter formats: q=28.5828,77.3110 or loc:28.5828,77.3110
    final qRegExp = RegExp(r'(?:q=|loc:)([-+]?\d+\.\d+)[,\+]([-+]?\d+\.\d+)');
    final matchQ = qRegExp.firstMatch(trimmed);
    if (matchQ != null) {
      final lat = double.tryParse(matchQ.group(1) ?? '');
      final lng = double.tryParse(matchQ.group(2) ?? '');
      if (lat != null && lng != null) return {'latitude': lat, 'longitude': lng};
    }

    // Centered coordinates: @28.5828,77.3110
    final atRegExp = RegExp(r'@([-+]?\d+\.\d+),([-+]?\d+\.\d+)');
    final matchAt = atRegExp.firstMatch(trimmed);
    if (matchAt != null) {
      final lat = double.tryParse(matchAt.group(1) ?? '');
      final lng = double.tryParse(matchAt.group(2) ?? '');
      if (lat != null && lng != null) return {'latitude': lat, 'longitude': lng};
    }

    // Direct decimal pairs: 28.5828, 77.3110
    final directRegExp = RegExp(r'([-+]?\d+\.\d+)\s*,\s*([-+]?\d+\.\d+)');
    final matchDirect = directRegExp.firstMatch(trimmed);
    if (matchDirect != null) {
      final lat = double.tryParse(matchDirect.group(1) ?? '');
      final lng = double.tryParse(matchDirect.group(2) ?? '');
      if (lat != null && lng != null) return {'latitude': lat, 'longitude': lng};
    }

    return null;
  }
}
