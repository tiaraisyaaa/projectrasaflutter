// import 'dart:convert';
// import 'package:http/http.dart' as http;

// class GeocodingServiceOSM {
//   Future<String> getStreetName(double lat, double lng) async {
//     try {
//       final url =
//           'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1';

//       final response = await http.get(
//         Uri.parse(url),
//         headers: {'User-Agent': 'RasaApp/1.0'},
//       );

//       if (response.statusCode != 200) return 'Alamat tidak tersedia';

//       final data = jsonDecode(response.body);

//       final displayName = data['display_name'];
//       return displayName ?? 'Alamat tidak ditemukan';
//     } catch (e) {
//       return 'Gagal mengambil alamat';
//     }
//   }
// }