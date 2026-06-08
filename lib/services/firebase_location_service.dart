// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:geocoding/geocoding.dart';
// // import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
// import 'package:geolocator/geolocator.dart';

// class FirebaseLocationService {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;

//   Future<Position> getCurrentPosition() async {
//     final serviceEnabled = await Geolocator.isLocationServiceEnabled();

//     if (!serviceEnabled) {
//       throw Exception('GPS belum aktif.');
//     }

//     LocationPermission permission = await Geolocator.checkPermission();

//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//     }

//     if (permission == LocationPermission.denied) {
//       throw Exception('Izin lokasi ditolak.');
//     }

//     if (permission == LocationPermission.deniedForever) {
//       throw Exception('Izin lokasi ditolak permanen.');
//     }

//     return Geolocator.getCurrentPosition(
//       desiredAccuracy: LocationAccuracy.high,
//     );
//   }

//   Future<String> getAddressFromCoordinate(double lat, double lng) async {
//     try {
//       final placemarks = await placemarkFromCoordinates(lat, lng);

//       if (placemarks.isEmpty) {
//         return 'Alamat tidak ditemukan';
//       }

//       final p = placemarks.first;

//       final parts = [
//         p.street,
//         p.subLocality,
//         p.locality,
//         p.subAdministrativeArea,
//         p.administrativeArea,
//       ].where((e) => e != null && e.trim().isNotEmpty).join(', ');

//       return parts.isEmpty ? 'Alamat tidak ditemukan' : parts;
//     } catch (e) {
//       return 'Alamat tidak ditemukan';
//     }
//   }

//   Future<Position> saveCurrentLocation({
//     required String elderlyId,
//   }) async {
//     final position = await getCurrentPosition();

//     final address = await getAddressFromCoordinate(
//       position.latitude,
//       position.longitude,
//     );

//     // final geoPoint = GeoFirePoint(
//     //   GeoPoint(position.latitude, position.longitude),
//     // );

//     await _firestore.collection('locations').doc(elderlyId).set({
//   'elderlyId': elderlyId,
//   'latitude': position.latitude,
//   'longitude': position.longitude,
//   'accuracy': position.accuracy,
//   'address': address,
//   'geoPoint': GeoPoint(position.latitude, position.longitude),
//   'updatedAt': FieldValue.serverTimestamp(),
// }, SetOptions(merge: true));

//     return position;
//   }

//   Stream<DocumentSnapshot<Map<String, dynamic>>> watchLocation(
//     String elderlyId,
//   ) {
//     return _firestore.collection('locations').doc(elderlyId).snapshots();
//   }
// }