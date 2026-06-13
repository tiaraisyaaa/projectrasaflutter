import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/background_sensor_service.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/storage_service.dart';
import '../../services/location_service.dart';
import '../../services/environment_service.dart';
import '../../services/weather_service.dart';
import '../../services/geocoding_service.dart';

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
  final LocationService _locationService = LocationService();
  final EnvironmentService _environmentService = EnvironmentService();
  final WeatherService _weatherService = WeatherService();
  final GeocodingService _geocodingService = GeocodingService();

  StreamSubscription<Map<String, dynamic>?>? _activityUpdateSubscription;

  Map<String, dynamic>? _latestWeather;
  bool _isLoadingWeather = false;
  bool _isStartingBackgroundService = false;

  double _xAxis = 0;
  double _yAxis = 0;
  double _zAxis = 0;
  double _accelerationValue = 0;

  String _activityStatus = 'memulai_monitoring';
  String _riskLevel = 'normal';
  String _backgroundServiceStatus = 'Menyiapkan sensor background...';

  double? _currentLatitude;
  double? _currentLongitude;
  double? _currentAccuracy;
  bool _isUpdatingLocation = false;
  String _locationStatus = 'Lokasi belum diperbarui';
  String _streetName = '-';

  static const Color primaryBlue = Color(0xFF2F73AD);
  static const Color deepBlue = Color(0xFF1D5F94);
  static const Color softBlue = Color(0xFFBFE7E8);
  static const Color verySoftBlue = Color(0xFFF7FCFF);
  static const Color cardWhite = Colors.white;
  static const Color darkText = Color(0xFF20232A);
  static const Color mutedText = Color(0xFF777777);

  List<BoxShadow> get _softShadow {
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.07),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _listenBackgroundActivityUpdates();
    _startBackgroundSensorService();
    _updateCurrentLocation();
    _loadLatestWeather();
  }

  Future<void> _startBackgroundSensorService() async {
    if (_isStartingBackgroundService) return;

    setState(() {
      _isStartingBackgroundService = true;
      _backgroundServiceStatus = 'Menyalakan sensor background...';
    });

    try {
      await BackgroundSensorService.initialize();
      await BackgroundSensorService.start();

      if (!mounted) return;

      setState(() {
        _backgroundServiceStatus = 'Sensor background aktif';
        _isStartingBackgroundService = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _backgroundServiceStatus = 'Gagal menyalakan sensor background';
        _isStartingBackgroundService = false;
      });

      _showMessage('Gagal menyalakan sensor background: $e');
    }
  }

  void _listenBackgroundActivityUpdates() {
    _activityUpdateSubscription =
        BackgroundSensorService.activityUpdates.listen((event) {
      if (event == null || !mounted) return;

      setState(() {
        _xAxis = _toDouble(event['xAxis']);
        _yAxis = _toDouble(event['yAxis']);
        _zAxis = _toDouble(event['zAxis']);
        _accelerationValue = _toDouble(event['accelerationValue']);
        _activityStatus =
            event['activityStatus']?.toString() ?? _activityStatus;
        _riskLevel = event['riskLevel']?.toString() ?? _riskLevel;
        _backgroundServiceStatus = 'Sensor background aktif';
      });
    });
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
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
      final locationData = data['location'] ?? data['data'] ?? data;

      final double? latitude = locationData['latitude'] != null
          ? double.tryParse(locationData['latitude'].toString())
          : null;

      final double? longitude = locationData['longitude'] != null
          ? double.tryParse(locationData['longitude'].toString())
          : null;

      final double? accuracy = locationData['accuracy'] != null
          ? (locationData['accuracy'] as num).toDouble()
          : null;

      String streetName = '-';

      if (latitude != null && longitude != null) {
        streetName = await _geocodingService.getStreetName(latitude, longitude);
      }

      if (!mounted) return;

      setState(() {
        _currentLatitude = latitude;
        _currentLongitude = longitude;
        _currentAccuracy = accuracy;
        _streetName = streetName;
        _locationStatus = (latitude != null && longitude != null)
            ? 'Lokasi berhasil diperbarui'
            : 'Gagal mengambil koordinat';
        _isUpdatingLocation = false;
      });

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

  Future<void> _loadLatestWeather() async {
    if (_currentLatitude == null || _currentLongitude == null) return;
    if (_isLoadingWeather) return;

    setState(() => _isLoadingWeather = true);

    try {
      final weather = await _weatherService.getWeather(
        _currentLatitude!,
        _currentLongitude!,
      );

      if (weather == null) {
        throw Exception('Data kualitas udara tidak tersedia.');
      }

      final result = await _environmentService.createEnvironmentRecord(
        temperature: double.parse(weather['temperature'].toString()),
        humidity: double.parse(weather['humidity'].toString()),
        airQuality: weather['airQuality'].toString(),
        riskLevel: weather['riskLevel'].toString(),
        latitude: _currentLatitude!,
        longitude: _currentLongitude!,
      );

      if (result['success'] != true) {
        debugPrint('POST environment gagal: ${result['message']}');
      }

      final latestEnv = await _environmentService.getLatestEnvironmentForSelf();

      if (!mounted) return;

      setState(() {
        _latestWeather = latestEnv ?? weather;
      });
    } catch (e) {
      debugPrint('Gagal mengambil atau menyimpan data environment: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan data environment: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingWeather = false);
      }
    }
  }

  void _logout(BuildContext context) async {
    await _activityUpdateSubscription?.cancel();
    await BackgroundSensorService.stop();

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

    return primaryBlue;
  }

  IconData _getStatusIcon() {
    if (_activityStatus == 'indikasi_jatuh') {
      return Icons.warning_amber_rounded;
    }

    if (_activityStatus == 'memulai_monitoring') {
      return Icons.hourglass_top_rounded;
    }

    return Icons.sensors_rounded;
  }

  String _getStatusText() {
    if (_activityStatus == 'indikasi_jatuh') {
      return 'Indikasi Jatuh';
    }

    if (_activityStatus == 'memulai_monitoring') {
      return 'Memulai';
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
      return 'Sistem mendeteksi kemungkinan jatuh. Keluarga akan menerima peringatan.';
    }

    if (_activityStatus == 'memulai_monitoring') {
      return 'Sensor sedang mulai membaca gerakan.';
    }

    return 'Sensor berjalan baik dan aktivitas terpantau melalui background service.';
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  String _getAirQualityText() {
    final raw = _latestWeather?['airQuality']?.toString();

    if (raw == null || raw.isEmpty) {
      return _isLoadingWeather ? 'Memuat...' : 'Belum Tersedia';
    }

    return _capitalize(raw);
  }

  String _getEnvironmentRiskText() {
    final raw = _latestWeather?['riskLevel']?.toString();

    if (raw == null || raw.isEmpty) {
      return '-';
    }

    return _capitalize(raw);
  }

  String _getAqiText() {
    final aqi = _latestWeather?['aqi'];

    if (aqi == null) return '-';

    return aqi.toString();
  }

  String _getAqiCategoryText() {
    final category = _latestWeather?['aqiCategory']?.toString();

    if (category == null || category.isEmpty) return '-';

    return category;
  }

  Color _getAirQualityColor() {
    final quality = _latestWeather?['airQuality']?.toString();

    if (quality == 'baik') {
      return Colors.green;
    }

    if (quality == 'sedang') {
      return Colors.orange;
    }

    if (quality == 'buruk') {
      return Colors.red;
    }

    return primaryBlue;
  }

  IconData _getAirQualityIcon() {
    final quality = _latestWeather?['airQuality']?.toString();

    if (quality == 'baik') {
      return Icons.eco_rounded;
    }

    if (quality == 'sedang') {
      return Icons.air_rounded;
    }

    if (quality == 'buruk') {
      return Icons.masks_rounded;
    }

    return Icons.cloud_rounded;
  }

  String _getAirQualityDescription() {
    if (_latestWeather == null) {
      return _isLoadingWeather
          ? 'Sistem sedang mengambil data kualitas udara terbaru.'
          : 'Data kualitas udara belum tersedia.';
    }

    return 'AQI ${_getAqiText()} termasuk kategori ${_getAqiCategoryText().toLowerCase()}.';
  }

  Widget mapWidget(double lat, double lng) {
    if (lat == 0 && lng == 0) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F8F8),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text(
          'Peta belum tersedia',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: mutedText,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
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

  Widget _buildBigIconCircle({
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 48,
        color: color,
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryBlue, deepBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.24),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.35)),
            ),
            child: const Icon(
              Icons.accessibility_new_rounded,
              size: 42,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard Lansia',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Pantau aktivitas, kualitas udara, dan lokasi dengan mudah.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard() {
    final Color statusColor = _getStatusColor();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: statusColor.withOpacity(0.10)),
        boxShadow: _softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildBigIconCircle(
            icon: _getStatusIcon(),
            color: statusColor,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStatusText(),
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 19,
                      color: darkText,
                      fontWeight: FontWeight.w700,
                    ),
                    children: [
                      const TextSpan(text: 'Risiko: '),
                      TextSpan(
                        text: _capitalize(_riskLevel),
                        style: TextStyle(color: statusColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _backgroundServiceStatus,
                  style: const TextStyle(
                    fontSize: 14,
                    color: mutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 1,
                  color: Colors.grey.withOpacity(0.22),
                ),
                // const SizedBox(height: 12),
                // Text(
                //   _getStatusDescription(),
                //   style: const TextStyle(
                //     fontSize: 16,
                //     height: 1.35,
                //     color: darkText,
                //     fontWeight: FontWeight.w500,
                //   ),
                // ),
                // const SizedBox(height: 10),
                // Text(
                //   'Akselerasi: ${_accelerationValue.toStringAsFixed(2)} | '
                //   'X: ${_xAxis.toStringAsFixed(2)}, '
                //   'Y: ${_yAxis.toStringAsFixed(2)}, '
                //   'Z: ${_zAxis.toStringAsFixed(2)}',
                //   style: const TextStyle(
                //     fontSize: 12,
                //     color: mutedText,
                //     fontWeight: FontWeight.w600,
                //   ),
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAirQualityCard() {
    final Color qualityColor = _getAirQualityColor();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: qualityColor.withOpacity(0.10)),
        boxShadow: _softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (_isLoadingWeather && _latestWeather == null)
            Container(
              width: 86,
              height: 86,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: qualityColor.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(color: primaryBlue),
            )
          else
            _buildBigIconCircle(
              icon: _getAirQualityIcon(),
              color: qualityColor,
            ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getAirQualityText(),
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: qualityColor,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: qualityColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'AQI ${_getAqiText()}',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: qualityColor,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 18,
                      color: darkText,
                      fontWeight: FontWeight.w700,
                    ),
                    children: [
                      const TextSpan(text: 'Risiko: '),
                      TextSpan(
                        text: _getEnvironmentRiskText(),
                        style: TextStyle(color: qualityColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 1,
                  color: Colors.grey.withOpacity(0.22),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: qualityColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getAirQualityDescription(),
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.35,
                          color: darkText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    final latitude = _currentLatitude != null
        ? double.tryParse(_currentLatitude.toString())
        : null;

    final longitude = _currentLongitude != null
        ? double.tryParse(_currentLongitude.toString())
        : null;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(26),
        boxShadow: _softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: primaryBlue,
                  size: 38,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Lokasi Terkini',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: darkText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _locationStatus,
            style: const TextStyle(
              fontSize: 17,
              color: darkText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: verySoftBlue,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: primaryBlue.withOpacity(0.08)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.home_rounded,
                  color: primaryBlue,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _streetName,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.35,
                      color: darkText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (latitude != null && longitude != null)
            mapWidget(latitude, longitude)
          else
            Container(
              height: 180,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F8F8),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'Peta belum tersedia',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: mutedText,
                ),
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isUpdatingLocation ? null : _updateCurrentLocation,
              icon: _isUpdatingLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.my_location_rounded),
              label: Text(
                _isUpdatingLocation ? 'Mengambil lokasi...' : 'Update Lokasi',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionButtons() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () {
            _openSendConnectionRequest(context);
          },
          icon: const Icon(Icons.group_add_rounded),
          label: const Text(
            'Hubungkan Keluarga',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () {
            _openConnectedFamilies(context);
          },
          icon: const Icon(Icons.family_restroom_rounded),
          label: const Text(
            'Keluarga Terhubung',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryBlue,
            side: const BorderSide(color: primaryBlue),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: verySoftBlue,
      appBar: AppBar(
        title: const Text(
          'Dashboard Lansia',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: softBlue,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Profil',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ElderlyProfileScreen(),
                ),
              );
            },
            icon: const Icon(Icons.person),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: primaryBlue,
          onRefresh: () async {
            await _startBackgroundSensorService();
            await _updateCurrentLocation();
            await _loadLatestWeather();
          },
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 24),
              _buildActivityCard(),
              const SizedBox(height: 24),
              _buildAirQualityCard(),
              const SizedBox(height: 24),
              _buildLocationCard(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _activityUpdateSubscription?.cancel();
    super.dispose();
  }
}