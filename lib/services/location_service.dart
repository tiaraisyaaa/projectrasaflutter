// import 'package:geolocator/geolocator.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import '../config/api_config.dart';
// import 'storage_service.dart';

// class LocationService {
//   Future<Position> getCurrentPosition() async {
//     final serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) throw Exception('GPS belum aktif');

//     LocationPermission permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
//     if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
//       throw Exception('Izin lokasi ditolak');
//     }

//     return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
//   }

//   Future<String> getAddressFromCoordinate(double lat, double lng) async {
//     try {
//       final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1';
//       final response = await http.get(Uri.parse(url), headers: {'User-Agent':'RasaApp/1.0'});
//       if (response.statusCode != 200) return 'Alamat tidak tersedia';
//       final data = jsonDecode(response.body);
//       return data['display_name'] ?? 'Alamat tidak ditemukan';
//     } catch (e) {
//       return 'Gagal mengambil alamat';
//     }
//   }

//   Future<Map<String, dynamic>> saveCurrentLocation() async {
//     final pos = await getCurrentPosition();
//     final address = await getAddressFromCoordinate(pos.latitude, pos.longitude);

//     return {
//       'latitude': pos.latitude,
//       'longitude': pos.longitude,
//       'accuracy': pos.accuracy,
//       'address': address
//     };
//   }

//    Future<Map<String, dynamic>?> getLatestLocation(String elderlyId) async {
//   final token = await StorageService().getToken();
//   if (token == null || token.isEmpty) return null;

//   final url = Uri.parse('${ApiConfig.baseUrl}/api/elderlies/$elderlyId/locations/latest');

//   try {
//     final response = await http.get(
//       url,
//       headers: {
//         'Accept': 'application/json',
//         'Authorization': 'Bearer $token',
//       },
//     );

//     if (response.statusCode != 200 || response.body.isEmpty) return null;

//     final data = jsonDecode(response.body);

//     // pastikan map yang dikembalikan sesuai struktur Flutter
//     return data['location'] ?? data['data'] ?? data;
//   } catch (e) {
//     print('Error getLatestLocation: $e');
//     return null;
//   }
// }
// }




import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import 'storage_service.dart';

class LocationService {
  final StorageService _storageService = StorageService();

  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception('GPS belum aktif');
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Izin lokasi ditolak');
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<String> getAddressFromCoordinate(double lat, double lng) async {
    try {
      final url =
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'RasaApp/1.0',
        },
      );

      if (response.statusCode != 200) {
        return 'Alamat tidak tersedia';
      }

      final data = jsonDecode(response.body);
      return data['display_name'] ?? 'Alamat tidak ditemukan';
    } catch (e) {
      return 'Gagal mengambil alamat';
    }
  }

  // Future<Map<String, dynamic>> saveCurrentLocation() async {
  //   final token = await _storageService.getToken();

  //   if (token == null || token.isEmpty) {
  //     return {
  //       'success': false,
  //       'message': 'Token tidak ditemukan. Silakan login ulang.',
  //       'data': null,
  //     };
  //   }

  //   final pos = await getCurrentPosition();
  //   final address = await getAddressFromCoordinate(
  //     pos.latitude,
  //     pos.longitude,
  //   );

  //   final body = {
  //     'latitude': pos.latitude,
  //     'longitude': pos.longitude,
  //     'accuracy': pos.accuracy,
  //     'address': address,
  //   };

  //   final url = Uri.parse(ApiConfig.createLocation);

  //   print('POST LOCATION URL: $url');
  //   print('POST LOCATION BODY: ${jsonEncode(body)}');

  //   try {
  //     final response = await http.post(
  //       url,
  //       headers: {
  //         'Content-Type': 'application/json',
  //         'Accept': 'application/json',
  //         'Authorization': 'Bearer $token',
  //       },
  //       body: jsonEncode(body),
  //     );

  //     print('POST LOCATION STATUS: ${response.statusCode}');
  //     print('POST LOCATION RESPONSE: ${response.body}');

  //     if (response.statusCode == 200 || response.statusCode == 201) {
  //       final decoded = response.body.isNotEmpty
  //           ? jsonDecode(response.body)
  //           : {};

  //       return {
  //         'success': true,
  //         'message': decoded['message'] ?? 'Lokasi berhasil disimpan',
  //         'data': decoded['location'] ?? decoded['data'] ?? decoded,
  //       };
  //     }

  //     return {
  //       'success': false,
  //       'message': 'Gagal menyimpan lokasi. Status: ${response.statusCode}',
  //       'data': response.body,
  //     };
  //   } catch (e) {
  //     print('Error saveCurrentLocation: $e');

  //     return {
  //       'success': false,
  //       'message': 'Gagal menghubungi server: $e',
  //       'data': null,
  //     };
  //   }
  // }

// Future<Map<String, dynamic>> saveCurrentLocation() async {
//   final token = await _storageService.getToken();

//   if (token == null || token.isEmpty) {
//     return {
//       'success': false,
//       'message': 'Token tidak ditemukan. Silakan login ulang.',
//       'data': null,
//     };
//   }

//   // Ambil posisi device
//   final pos = await getCurrentPosition();
//   final address = await getAddressFromCoordinate(pos.latitude, pos.longitude);
//   final elderlyId = await _storageService.getUserId();
//   final body = {
//     'latitude': pos.latitude,
//     'longitude': pos.longitude,
//     'accuracy': pos.accuracy,
//     'address': address,
//   };

//   final url = Uri.parse(ApiConfig.createLocation);

//   print('POST LOCATION URL: $url');
//   print('POST LOCATION BODY: ${jsonEncode(body)}');

//   try {
//     final response = await http.post(
//       url,
//       headers: {
//         'Content-Type': 'application/json',
//         'Accept': 'application/json',
//         'Authorization': 'Bearer $token',
//       },
//       body: jsonEncode(body),
//     );

//     print('POST LOCATION STATUS: ${response.statusCode}');
//     print('POST LOCATION RESPONSE: ${response.body}');

//     final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};

//     // fallback: pakai data device jika backend tidak mengembalikan location
//     final dataMap = decoded['location'] ?? decoded['data'] ?? {
//       'latitude': pos.latitude,
//       'longitude': pos.longitude,
//       'accuracy': pos.accuracy,
//       'address': address,
//     };

//     return {
//       'success': response.statusCode == 200 || response.statusCode == 201,
//       'message': decoded['message'] ?? 'Lokasi berhasil disimpan',
//       'data': dataMap,
//     };
//   } catch (e) {
//     print('Error saveCurrentLocation: $e');

//     return {
//       'success': false,
//       'message': 'Gagal menghubungi server: $e',
//       'data': {
        
//         'elderly_id': elderlyId,
//         'latitude': pos.latitude,
//         'longitude': pos.longitude,
//         'accuracy': pos.accuracy,
//         'address': address,
//       },
//     };
//   }
// }





Future<Map<String, dynamic>> saveCurrentLocation() async {
  final token = await _storageService.getToken();
  final elderlyId = await _storageService.getUserId();

  if (token == null || token.isEmpty || elderlyId == null || elderlyId.isEmpty) {
    return {
      'success': false,
      'message': 'Token atau User ID tidak ditemukan. Silakan login ulang.',
      'data': null,
    };
  }

  final pos = await getCurrentPosition();
  final address = await getAddressFromCoordinate(pos.latitude, pos.longitude);

  final body = {
    'elderly_id': elderlyId,          // <- wajib dikirim ke backend
    'latitude': pos.latitude,
    'longitude': pos.longitude,
    'accuracy': pos.accuracy,
    'address': address,
  };

  final url = Uri.parse(ApiConfig.createLocation);

  print('POST LOCATION URL: $url');
  print('POST LOCATION BODY: ${jsonEncode(body)}');

  try {
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    print('POST LOCATION STATUS: ${response.statusCode}');
    print('POST LOCATION RESPONSE: ${response.body}');

    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};

    final dataMap = decoded['location'] ?? decoded['data'] ?? body;

    return {
      'success': response.statusCode == 200 || response.statusCode == 201,
      'message': decoded['message'] ?? 'Lokasi berhasil disimpan',
      'data': dataMap,
    };
  } catch (e) {
    print('Error saveCurrentLocation: $e');

    return {
      'success': false,
      'message': 'Gagal menghubungi server: $e',
      'data': body,
    };
  }
}






  Future<Map<String, dynamic>?> getLatestLocation(String elderlyId) async {
    final token = await _storageService.getToken();

    if (token == null || token.isEmpty) {
      print('GET LOCATION gagal: token kosong');
      return null;
    }

    final url = Uri.parse(ApiConfig.latestLocation(elderlyId));

    print('GET LOCATION URL: $url');

    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('GET LOCATION STATUS: ${response.statusCode}');
      print('GET LOCATION RESPONSE: ${response.body}');

      if (response.statusCode != 200 || response.body.isEmpty) {
        return null;
      }

      final decoded = jsonDecode(response.body);

      dynamic location;

      if (decoded is Map<String, dynamic>) {
        location = decoded['location'] ??
            decoded['data']?['location'] ??
            decoded['data'] ??
            decoded;
      } else if (decoded is List && decoded.isNotEmpty) {
        location = decoded.first;
      }

      if (location == null) {
        return null;
      }

      final locationMap = Map<String, dynamic>.from(location);

      return {
        'id': locationMap['id'],
        'elderly_id': locationMap['elderly_id'] ?? locationMap['elderlyId'],
        'latitude': locationMap['latitude'] ?? locationMap['lat'],
        'longitude': locationMap['longitude'] ?? locationMap['lng'],
        'accuracy': locationMap['accuracy'],
        'address': locationMap['address'],
        'created_at': locationMap['created_at'] ?? locationMap['createdAt'],
      };
    } catch (e) {
      print('Error getLatestLocation: $e');
      return null;
    }
  }
}