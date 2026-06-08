// import 'dart:convert';
// import 'package:http/http.dart' as http;

// class GeocodingService {
//   final String apiKey = 'b81e8686c3785c5dcd0b0a0015e3160a';

//   Future<String> getStreetName(double lat, double lng) async {
//     final url =
//         'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey';

//     try {
//       print('Geocoding request: $url');

//       final response = await http.get(Uri.parse(url));

//       print('Geocoding response: ${response.statusCode} ${response.body}');

//       if (response.statusCode != 200) {
//         return 'Alamat tidak tersedia';
//       }

//       final data = jsonDecode(response.body);

//       final status = data['status'];
//       final errorMessage = data['error_message'];

//       if (status != 'OK') {
//         print('Geocoding status error: $status');
//         print('Geocoding error message: $errorMessage');

//         if (status == 'REQUEST_DENIED') {
//           return 'Geocoding API ditolak. Cek API key.';
//         }

//         if (status == 'ZERO_RESULTS') {
//           return 'Alamat tidak ditemukan';
//         }

//         return 'Alamat tidak tersedia';
//       }

//       if (data['results'] != null && data['results'].isNotEmpty) {
//         return data['results'][0]['formatted_address'] ??
//             'Alamat tidak ditemukan';
//       }

//       return 'Alamat tidak ditemukan';
//     } catch (e) {
//       print('Geocoding exception: $e');
//       return 'Gagal mengambil alamat';
//     }
//   }
// }

import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingService {
  Future<String> getStreetName(double lat, double lng) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?format=json'
      '&lat=$lat'
      '&lon=$lng'
      '&zoom=18'
      '&addressdetails=1',
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'RASA-Flutter-App/1.0',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        return 'Alamat tidak tersedia';
      }

      final data = jsonDecode(response.body);

      final displayName = data['display_name'];

      if (displayName == null || displayName.toString().isEmpty) {
        return 'Alamat tidak ditemukan';
      }

      return displayName.toString();
    } catch (e) {
      return 'Gagal mengambil alamat';
    }
  }
}