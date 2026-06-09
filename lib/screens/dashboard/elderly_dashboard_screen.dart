import 'dart:async';
import 'dart:math';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

import '../../services/activity_service.dart';
import '../../services/alert_service.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/storage_service.dart';
// import '../../services/firebase_location_service.dart';
import '../../services/location_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/environment_service.dart';
import '../../services/weather_service.dart';
import '../../config/api_config.dart';


import '../auth/login_screen.dart';
import '../connection/connected_families_screen.dart';
import '../connection/send_connection_request_screen.dart';

import '../profile/elderly_profile_screen.dart';

class ElderlyDashboardScreen extends StatefulWidget {
  const ElderlyDashboardScreen({super.key});

  @override
  State<ElderlyDashboardScreen> createState() => _ElderlyDashboardScreenState();
}

class _ElderlyDashboardScreenState extends State<ElderlyDashboardScreen> {
  final FirebaseAuthService _firebaseAuthService = FirebaseAuthService();
  final StorageService _storageService = StorageService();
  final ActivityService _activityService = ActivityService();
  final AlertService _alertService = AlertService();
  final LocationService _locationService = LocationService();
  final GeocodingService _geocodingService = GeocodingService();
  final EnvironmentService _environmentService = EnvironmentService();
  final WeatherService _weatherService = WeatherService();
Map<String, dynamic>? _latestWeather;
bool _isLoadingWeather = false;

  Map<String, dynamic>? _latestEnvironment;
bool _isLoadingEnvironment = false;
String _environmentStatus = 'Data lingkungan belum diperbarui';

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  double _xAxis = 0;
  double _yAxis = 0;
  double _zAxis = 0;
  double _accelerationValue = 0;

  String _activityStatus = 'memulai_monitoring';
  String _riskLevel = 'normal';

  String? _lastSentStatus;
  DateTime? _lastSentAt;
  DateTime? _lastEmergencySentAt;
  DateTime? _lastAlertSentAt;

  DateTime? _impactDetectedAt;
  DateTime? _restAfterImpactStartedAt;
  DateTime? _fallLockUntil;

  bool _isSending = false;
  bool _isSendingAlert = false;

  // Lokasi
  double? _currentLatitude;
  double? _currentLongitude;
  double? _currentAccuracy;
  bool _isUpdatingLocation = false;
  String _locationStatus = 'Lokasi belum diperbarui';
  String _streetName = '-';

  static const double impactThreshold = 35.0;
  static const double restMinAcceleration = 8.0;
  static const double restMaxAcceleration = 12.0;
  static const int requiredRestAfterImpactSeconds = 2;
  static const int fallConfirmationWindowSeconds = 5;
  static const int fallStatusLockSeconds = 120;
  static const int normalActivityPostIntervalSeconds = 120;
  static const int emergencyPostCooldownSeconds = 120;
  static const int alertCooldownSeconds = 120;

@override
void initState() {
  super.initState();
  _startSensorMonitoring();
  _updateCurrentLocation();
}

  void _startSensorMonitoring() {
    _accelerometerSubscription = accelerometerEventStream().listen(
      (AccelerometerEvent event) {
        _handleAccelerometerEvent(event);
      },
      onError: (error) {
        _showMessage('Gagal membaca sensor: $error');
      },
    );
  }

  void _handleAccelerometerEvent(AccelerometerEvent event) {
    final now = DateTime.now();

    final double x = event.x;
    final double y = event.y;
    final double z = event.z;
    final double acceleration = sqrt((x * x) + (y * y) + (z * z));

    _xAxis = x;
    _yAxis = y;
    _zAxis = z;
    _accelerationValue = acceleration;

    if (_fallLockUntil != null && now.isBefore(_fallLockUntil!)) return;
    if (_fallLockUntil != null && now.isAfter(_fallLockUntil!)) {
      _fallLockUntil = null;
      _impactDetectedAt = null;
      _restAfterImpactStartedAt = null;
    }

    if (acceleration >= impactThreshold) {
      _impactDetectedAt = now;
      _restAfterImpactStartedAt = null;
      debugPrint('Hentakan besar terdeteksi: $acceleration');
      return;
    }

    if (_impactDetectedAt != null) {
      final int secondsAfterImpact =
          now.difference(_impactDetectedAt!).inSeconds;
      final bool stillInConfirmationWindow =
          secondsAfterImpact <= fallConfirmationWindowSeconds;
      final bool phoneLooksResting =
          acceleration >= restMinAcceleration &&
          acceleration <= restMaxAcceleration;

      if (!stillInConfirmationWindow) {
        _impactDetectedAt = null;
        _restAfterImpactStartedAt = null;
        _setActiveStatus();
        return;
      }

      if (phoneLooksResting) {
        _restAfterImpactStartedAt ??= now;
        final int restDuration =
            now.difference(_restAfterImpactStartedAt!).inSeconds;
        if (restDuration >= requiredRestAfterImpactSeconds) {
          _setFallStatus();
          return;
        }
      } else {
        _restAfterImpactStartedAt = null;
      }
      return;
    }

    _setActiveStatus();
  }

  void _setFallStatus() {
    final now = DateTime.now();
    setState(() {
      _activityStatus = 'indikasi_jatuh';
      _riskLevel = 'darurat';
      _fallLockUntil = now.add(const Duration(seconds: fallStatusLockSeconds));
      _impactDetectedAt = null;
      _restAfterImpactStartedAt = null;
    });

    _maybeSendActivity(forceEmergency: true);
    _sendFallAlert();
  }

  void _setActiveStatus() {
    if (_activityStatus == 'aktif' && _riskLevel == 'normal') {
      _maybeSendActivity();
      return;
    }
    setState(() {
      _activityStatus = 'aktif';
      _riskLevel = 'normal';
    });
    _maybeSendActivity();
  }

  String _getRiskLevelFromStatus(String status) {
    if (status == 'indikasi_jatuh') return 'darurat';
    if (status == 'tidak_aktif') return 'waspada';
    return 'normal';
  }

  Future<void> _maybeSendActivity({bool forceEmergency = false}) async {
    if (_isSending) return;

    final now = DateTime.now();
    final String statusToSend = _activityStatus;
    final String riskLevelToSend = _getRiskLevelFromStatus(statusToSend);

    final bool isEmergency = statusToSend == 'indikasi_jatuh';
    final bool statusChanged = _lastSentStatus != statusToSend;
    final bool intervalReached = _lastSentAt == null ||
        now.difference(_lastSentAt!).inSeconds >=
            normalActivityPostIntervalSeconds;

    if (isEmergency) {
      final bool emergencyCooldownReached = _lastEmergencySentAt == null ||
          now.difference(_lastEmergencySentAt!).inSeconds >=
              emergencyPostCooldownSeconds;
      if (!emergencyCooldownReached) return;
    }

    if (!forceEmergency && !statusChanged && !intervalReached) return;

    _isSending = true;

    final result = await _activityService.createActivity(
      xAxis: double.parse(_xAxis.toStringAsFixed(2)),
      yAxis: double.parse(_yAxis.toStringAsFixed(2)),
      zAxis: double.parse(_zAxis.toStringAsFixed(2)),
      accelerationValue: double.parse(_accelerationValue.toStringAsFixed(2)),
      activityStatus: statusToSend,
      riskLevel: riskLevelToSend,
    );

    _isSending = false;

    if (!mounted) return;

    if (result['success'] == true) {
      _lastSentStatus = statusToSend;
      _lastSentAt = now;

      if (isEmergency) _lastEmergencySentAt = now;

      debugPrint('Aktivitas terkirim: $statusToSend | risk: $riskLevelToSend');
    } else {
      debugPrint('Gagal kirim aktivitas: ${result['message']}');
    }
  }

//  Future<void> _sendFallAlert() async {
//   if (_isSendingAlert) return;

//   final now = DateTime.now();

//   final bool alertCooldownReached = _lastAlertSentAt == null ||
//       now.difference(_lastAlertSentAt!).inSeconds >= alertCooldownSeconds;

//   if (!alertCooldownReached) {
//     debugPrint('Alert jatuh tidak dikirim karena masih cooldown');
//     return;
//   }

//   _isSendingAlert = true;

//   try {
//     final String? elderlyId = await _storageService.getUserId();

//     if (elderlyId == null || elderlyId.isEmpty) {
//       throw Exception('User ID tidak ditemukan. Silakan login ulang.');
//     }

//     final data = await _locationService.saveCurrentLocation();

//     _currentLatitude = data['latitude'];
//     _currentLongitude = data['longitude'];
//     _currentAccuracy = data['accuracy'];
//     _streetName = data['address'] ?? 'Alamat tidak ditemukan';

//     final result = await _alertService.createAlert(
//       alertType: 'fall_detected',
//       message: 'Terdeteksi indikasi jatuh pada lansia',
//       riskLevel: 'darurat',
//       latitude: _currentLatitude ?? 0,
//       longitude: _currentLongitude ?? 0,
//     );

//     if (!mounted) return;

//     if (result['success'] == true) {
//       _lastAlertSentAt = now;
//       debugPrint('Alert jatuh terkirim');
//     } else {
//       debugPrint('Gagal kirim alert: ${result['message']}');
//     }
//   } catch (e) {
//     debugPrint('Gagal kirim alert jatuh: $e');
//   }

//   _isSendingAlert = false;
// }
  

  Future<void> _sendFallAlert() async {
  if (_isSendingAlert) return;

  final now = DateTime.now();

  final bool alertCooldownReached = _lastAlertSentAt == null ||
      now.difference(_lastAlertSentAt!).inSeconds >= alertCooldownSeconds;

  if (!alertCooldownReached) {
    debugPrint('Alert jatuh tidak dikirim karena masih cooldown');
    return;
  }

  _isSendingAlert = true;

  try {
    final String? elderlyId = await _storageService.getUserId();

    if (elderlyId == null || elderlyId.isEmpty) {
      throw Exception('User ID tidak ditemukan. Silakan login ulang.');
    }

    final data = await _locationService.saveCurrentLocation();

    _currentLatitude = data['latitude'];
    _currentLongitude = data['longitude'];
    _currentAccuracy = data['accuracy'];
    _streetName = data['address'] ?? 'Alamat tidak ditemukan';

    final result = await _alertService.createAlert(
      alertType: 'fall_detected',
      message: 'Terdeteksi indikasi jatuh pada lansia',
      riskLevel: 'darurat',
      latitude: _currentLatitude ?? 0,
      longitude: _currentLongitude ?? 0,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      _lastAlertSentAt = now;
      debugPrint('Alert jatuh terkirim');
    } else {
      debugPrint('Gagal kirim alert: ${result['message']}');
    }
  } catch (e) {
    debugPrint('Gagal kirim alert jatuh: $e');
  }

  _isSendingAlert = false;
}
  

Future<void> _updateCurrentLocation() async {
  if (_isUpdatingLocation) return;

  setState(() {
    _isUpdatingLocation = true;
    _locationStatus = 'Mengambil lokasi...';
  });

  try {
    final String? elderlyId = await _storageService.getUserId();

    if (elderlyId == null || elderlyId.isEmpty) {
      throw Exception('User ID tidak ditemukan. Silakan login ulang.');
    }

    final data = await _locationService.saveCurrentLocation();

    if (!mounted) return;

    setState(() {
      _currentLatitude = data['latitude'];
      _currentLongitude = data['longitude'];
      _currentAccuracy = data['accuracy'];
      _streetName = data['address'] ?? 'Alamat tidak ditemukan';
      _locationStatus = 'Lokasi berhasil diperbarui';
      _isUpdatingLocation = false;
    });

    // Panggil async di luar setState
    await _loadLatestWeather();
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _locationStatus = 'Gagal mengambil lokasi';
      _isUpdatingLocation = false;
    });

    debugPrint('Gagal update lokasi: $e');
  }
}

Future<void> _loadLatestEnvironment() async {
  if (_isLoadingEnvironment) return;

  setState(() {
    _isLoadingEnvironment = true;
    _environmentStatus = 'Mengambil data lingkungan...';
  });

  try {
    final String? elderlyId = await _storageService.getUserId();

    if (elderlyId == null || elderlyId.isEmpty) {
      throw Exception('User ID tidak ditemukan.');
    }

    final result = await _environmentService.getLatestEnvironment(elderlyId);

    if (!mounted) return;

    setState(() {
      _latestEnvironment = result;
      _environmentStatus = result == null
          ? 'Data lingkungan belum tersedia'
          : 'Data lingkungan berhasil diperbarui';
      _isLoadingEnvironment = false;
    });
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _environmentStatus = 'Gagal mengambil data lingkungan';
      _isLoadingEnvironment = false;
    });

    debugPrint('Gagal mengambil data lingkungan: $e');
  }
}



Future<void> _loadLatestWeather() async {
  if (_currentLatitude == null || _currentLongitude == null) return;
  if (_isLoadingWeather) return;

  setState(() {
    _isLoadingWeather = true;
  });

  try {
    final weather = await _weatherService.getWeather(
      _currentLatitude!,
      _currentLongitude!,
    );

    if (weather == null) {
      throw Exception('Data cuaca tidak tersedia.');
    }

    final result = await _environmentService.createEnvironmentRecord(
      temperature: double.parse(weather['temperature'].toString()),
      humidity: double.parse(weather['humidity'].toString()),
      airQuality: 'baik',
      riskLevel: 'normal',
      latitude: _currentLatitude!,
      longitude: _currentLongitude!,
    );

    if (result['success'] != true) {
      throw Exception(result['message']);
    }

    if (!mounted) return;

    setState(() {
      _latestWeather = weather;
    });
  } catch (e) {
    debugPrint('Gagal mengambil atau menyimpan cuaca: $e');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gagal menyimpan cuaca: $e'),
      ),
    );
  } finally {
    if (mounted) {
      setState(() {
        _isLoadingWeather = false;
      });
    }
  }
}

  void _logout(BuildContext context) async {
    await _accelerometerSubscription?.cancel();
    await _firebaseAuthService.logout();
    await _storageService.clearSession();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _openSendConnectionRequest(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SendConnectionRequestScreen()),
    );
  }

  void _openConnectedFamilies(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConnectedFamiliesScreen()),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Color _getStatusColor() {
  if (_activityStatus == 'indikasi_jatuh') {
    return Colors.red;
  }

  if (_activityStatus == 'memulai_monitoring') {
    return Colors.orange;
  }

  return Colors.teal;
}

IconData _getStatusIcon() {
  if (_activityStatus == 'indikasi_jatuh') {
    return Icons.warning_amber_rounded;
  }

  if (_activityStatus == 'memulai_monitoring') {
    return Icons.hourglass_top;
  }

  return Icons.sensors;
}

String _getStatusText() {
  if (_activityStatus == 'indikasi_jatuh') {
    return 'Indikasi Jatuh';
  }

  if (_activityStatus == 'memulai_monitoring') {
    return 'Memulai Monitoring';
  }

  if (_activityStatus == 'aktif') {
    return 'Normal';
  }

  if (_activityStatus == 'tidak_aktif') {
    return 'Tidak Aktif';
  }

  return _activityStatus;
}

String _getStatusDescription() {
  if (_activityStatus == 'indikasi_jatuh') {
    return 'Sistem mendeteksi pola hentakan besar dan posisi diam setelahnya.';
  }

  if (_activityStatus == 'memulai_monitoring') {
    return 'Sensor sedang mulai membaca gerakan.';
  }

  return 'Sensor berjalan otomatis dan aktivitas terpantau.';
}

  Widget mapWidget(double lat, double lng) {
  if (lat == 0 && lng == 0) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text('Peta belum tersedia'),
    );
  }

  return ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: SizedBox(
      height: 220,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(lat, lng),
          initialZoom: 16,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.projectrasa',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(lat, lng),
                width: 48,
                height: 48,
                child: const Icon(
                  Icons.location_pin,
                  size: 44,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    final Color statusColor = _getStatusColor();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F8),
      appBar: AppBar(
        title: const Text('Dashboard Lansia'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [

            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ElderlyProfileScreen()),
                );
              },
              icon: const Icon(Icons.person),
            ),
            // jika ada tombol logout utama di dashboard, bisa dihapus karena logout ada di profile
          ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(_getStatusIcon(), size: 78, color: statusColor),
                    const SizedBox(height: 16),
                    Text(
                      _getStatusText(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Risk Level: $_riskLevel',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _getStatusDescription(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Lokasi terbaru
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.teal),
                        SizedBox(width: 8),
                        Text(
                          'Lokasi Terkini',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(_locationStatus),
                    const SizedBox(height: 8),
                    // Text('Latitude: ${_currentLatitude?.toStringAsFixed(6) ?? '-'}'),
                    // Text('Longitude: ${_currentLongitude?.toStringAsFixed(6) ?? '-'}'),
                    // Text('Akurasi: ${_currentAccuracy?.toStringAsFixed(2) ?? '-'} meter'),
                    const SizedBox(height: 8),
                    Text('Alamat: $_streetName'),
                    const SizedBox(height: 12),
                    mapWidget(
                        _currentLatitude ?? 0, _currentLongitude ?? 0),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isUpdatingLocation ? null : _updateCurrentLocation,
                        icon: _isUpdatingLocation
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location),
                        label: Text(
                          _isUpdatingLocation ? 'Mengambil lokasi...' : 'Update Lokasi',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.teal,
                          side: const BorderSide(color: Colors.teal),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),


const SizedBox(height: 24),
if (_latestWeather != null)
  Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.cloud, color: Colors.teal),
            SizedBox(width: 8),
            Text(
              'Cuaca Saat Ini',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Suhu: ${_latestWeather?['temperature'] ?? '-'} °C'),
Text('Kelembapan: ${_latestWeather?['humidity'] ?? '-'} %'),
Text('Kecepatan Angin: ${_latestWeather?['windspeed'] ?? '-'} km/h'),
Text('Arah Angin: ${_latestWeather?['winddirection'] ?? '-'}°'),
      ],
    ),
  ),

              ElevatedButton.icon(
                onPressed: () {
                  _openSendConnectionRequest(context);
                },
                icon: const Icon(Icons.group_add),
                label: const Text(
                  'Hubungkan Keluarga',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () {
                  _openConnectedFamilies(context);
                },
                icon: const Icon(Icons.family_restroom),
                label: const Text(
                  'Keluarga Terhubung',
                  style: TextStyle(fontSize: 16),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal,
                  side: const BorderSide(color: Colors.teal),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    
  
  }
  @override
void dispose() {
  _accelerometerSubscription?.cancel();
  super.dispose();
}
}