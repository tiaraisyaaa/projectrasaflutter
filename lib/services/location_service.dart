import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import 'storage_service.dart';

class LocationService {
  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('GPS belum aktif');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw Exception('Izin lokasi ditolak');
    }

    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<String> getAddressFromCoordinate(double lat, double lng) async {
    try {
      final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1';
      final response = await http.get(Uri.parse(url), headers: {'User-Agent':'RasaApp/1.0'});
      if (response.statusCode != 200) return 'Alamat tidak tersedia';
      final data = jsonDecode(response.body);
      return data['display_name'] ?? 'Alamat tidak ditemukan';
    } catch (e) {
      return 'Gagal mengambil alamat';
    }
  }

  Future<Map<String, dynamic>> saveCurrentLocation() async {
    final pos = await getCurrentPosition();
    final address = await getAddressFromCoordinate(pos.latitude, pos.longitude);

    return {
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'accuracy': pos.accuracy,
      'address': address
    };
  }

   Future<Map<String, dynamic>?> getLatestLocation(String elderlyId) async {
  final token = await StorageService().getToken();
  if (token == null || token.isEmpty) return null;

  final url = Uri.parse('${ApiConfig.baseUrl}/api/elderlies/$elderlyId/locations/latest');

  try {
    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200 || response.body.isEmpty) return null;

    final data = jsonDecode(response.body);

    // pastikan map yang dikembalikan sesuai struktur Flutter
    return data['location'] ?? data['data'] ?? data;
  } catch (e) {
    print('Error getLatestLocation: $e');
    return null;
  }
}
}