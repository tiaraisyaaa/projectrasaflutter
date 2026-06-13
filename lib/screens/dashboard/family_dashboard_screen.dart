import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/activity_service.dart';
import '../../services/alert_service.dart';
import '../../services/connection_service.dart';
import '../../services/environment_service.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/location_service.dart';
import '../../services/storage_service.dart';
import '../../services/weather_service.dart';
import '../auth/login_screen.dart';
import '../connection/connected_elderlies_screen.dart';
import '../connection/incoming_connections_screen.dart';
import '../notification/notification_history_screen.dart';
import '../profile/family_profile_screen.dart';

class FamilyDashboardScreen extends StatefulWidget {
  const FamilyDashboardScreen({super.key});

  @override
  State<FamilyDashboardScreen> createState() => _FamilyDashboardScreenState();
}

class _FamilyDashboardScreenState extends State<FamilyDashboardScreen> {
  final FirebaseAuthService _firebaseAuthService = FirebaseAuthService();
  final StorageService _storageService = StorageService();
  final ConnectionService _connectionService = ConnectionService();
  final ActivityService _activityService = ActivityService();
  final AlertService _alertService = AlertService();
  final LocationService _locationService = LocationService();
  final EnvironmentService _environmentService = EnvironmentService();
  final WeatherService _weatherService = WeatherService();

  bool _isLoading = true;
  bool _isCheckingAlert = false;

  List<Map<String, dynamic>> _elderlyActivityItems = [];

  Timer? _refreshTimer;
  Timer? _alertTimer;

  final Set<String> _shownAlertIds = {};

  static const Color primaryBlue = Color(0xFF2F73AD);
  static const Color deepBlue = Color(0xFF1D5F94);
  static const Color softBlue = Color(0xFFBFE7E8);
  static const Color verySoftBlue = Color(0xFFF7FCFF);
  static const Color cardWhite = Colors.white;
  static const Color darkText = Color(0xFF20232A);
  static const Color mutedText = Color(0xFF777777);

  @override
  void initState() {
    super.initState();

    _loadShownAlerts();
    _loadDashboardData();

    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadDashboardData(showLoading: false);
    });

    _alertTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkEmergencyAlerts();
    });
  }

  String _formatWibTime(String rawTime) {
    if (rawTime == '-' || rawTime.isEmpty) return '-';

    try {
      final dateTime = DateTime.parse(rawTime).toLocal();
      return DateFormat('dd MMM yyyy, HH:mm').format(dateTime);
    } catch (e) {
      return rawTime;
    }
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  String _formatNumber(dynamic value, {int fractionDigits = 1}) {
    final number = _toDouble(value);

    if (number == null) return '-';

    return number.toStringAsFixed(fractionDigits);
  }

  Future<void> _loadShownAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('shown_alert_ids') ?? [];
    _shownAlertIds.addAll(ids);
  }

  Future<void> _saveShownAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('shown_alert_ids', _shownAlertIds.toList());
  }

  Future<void> _loadDashboardData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    final connectedResult = await _connectionService.getConnectedElderlies();

    if (!mounted) return;

    if (connectedResult['success'] != true) {
      setState(() {
        _isLoading = false;
      });

      _showMessage(connectedResult['message'] ?? 'Gagal memuat data lansia');
      return;
    }

    final List<dynamic> elderlies = connectedResult['data'] ?? [];
    final List<Map<String, dynamic>> items = [];

    for (final elderly in elderlies) {
      final elderlyId = _getElderlyId(elderly);

      Map<String, dynamic>? latestActivity;
      Map<String, dynamic>? latestLocation;
      Map<String, dynamic>? latestEnvironment;

      if (elderlyId.isNotEmpty) {
        final activityResult = await _activityService.getLatestActivity(
          elderlyId: elderlyId,
        );

        if (activityResult['success'] == true &&
            activityResult['data'] != null) {
          latestActivity = Map<String, dynamic>.from(activityResult['data']);
        }

        final locationResult = await _locationService.getLatestLocation(
          elderlyId,
        );

        if (locationResult != null) {
          latestLocation = Map<String, dynamic>.from(locationResult);

          final lat = _toDouble(latestLocation['latitude']);
          final lng = _toDouble(latestLocation['longitude']);

          if (lat != null && lng != null) {
            final address = await _locationService.getAddressFromCoordinate(
              lat,
              lng,
            );

            latestLocation['address'] = address;
          }
        }

        latestEnvironment = await _environmentService.getLatestEnvironment(
          elderlyId,
        );

        // AQI tidak disimpan di database. Jadi untuk menampilkan angka AQI asli,
        // dashboard mengambil AQI terbaru langsung dari OpenWeatherMap berdasarkan
        // lokasi terakhir lansia, lalu menempelkannya ke data environment yang
        // sudah ada dari database.
        final lat = _toDouble(latestLocation?['latitude']);
        final lng = _toDouble(latestLocation?['longitude']);

        if (lat != null && lng != null) {
          final liveWeather = await _weatherService.getWeather(lat, lng);

          if (liveWeather != null) {
            latestEnvironment ??= <String, dynamic>{};
            latestEnvironment['aqi'] = liveWeather['aqi'];
            latestEnvironment['aqiSource'] = liveWeather['aqiSource'];
            latestEnvironment['aqiCategory'] = liveWeather['aqiCategory'];

            // Jangan merusak data dari database. Ini hanya fallback jika data
            // air_quality/risk_level dari database belum tersedia.
            latestEnvironment['air_quality'] ??= liveWeather['airQuality'];
            latestEnvironment['risk_level'] ??= liveWeather['riskLevel'];
            latestEnvironment['temperature'] ??= liveWeather['temperature'];
            latestEnvironment['humidity'] ??= liveWeather['humidity'];
          }
        }
      }

      items.add({
        'elderly': elderly,
        'latestActivity': latestActivity,
        'latestLocation': latestLocation,
        'latestEnvironment': latestEnvironment,
      });
    }

    if (!mounted) return;

    setState(() {
      _elderlyActivityItems = items;
      _isLoading = false;
    });

    await _checkEmergencyAlerts();
  }

  List<BoxShadow> get _softShadow {
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.07),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ];
  }

  Widget _buildMiniInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.12)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: mutedText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatEnvironmentText(dynamic value) {
    if (value == null) return '-';

    final text = value.toString().trim();

    if (text.isEmpty || text.toLowerCase() == 'null') return '-';

    final cleaned = text.replaceAll('_', ' ').replaceAll('-', ' ');
    final words = cleaned.split(RegExp(r'\s+'));

    return words
        .where((word) => word.isNotEmpty)
        .map((word) {
          if (word.length == 1) return word.toUpperCase();
          return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
        })
        .join(' ');
  }

  int? _normalizeAqi(dynamic value) {
    if (value == null) return null;

    int? parsed;

    if (value is num) {
      parsed = value.toInt();
    } else {
      parsed = int.tryParse(value.toString().trim());
    }

    if (parsed == null) return null;

    if (parsed < 0 || parsed > 500) return null;

    return parsed;
  }

  String _normalizeEnvironmentKey(dynamic value) {
    if (value == null) return '';

    return value
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _getAqiDisplayText(Map<String, dynamic> latestEnvironment) {
    final candidates = [
      latestEnvironment['aqi'],
      latestEnvironment['AQI'],
      latestEnvironment['air_aqi'],
      latestEnvironment['airAqi'],
    ];

    for (final value in candidates) {
      final aqi = _normalizeAqi(value);
      if (aqi != null) return aqi.toString();
    }

    // Tidak tampilkan range lagi. Kalau angka AQI asli belum berhasil didapat
    // dari OpenWeatherMap atau belum dikirim backend, tampilkan strip.
    return '-';
  }

  String _getEnvironmentStatus(Map<String, dynamic> latestEnvironment) {
    final airQuality =
        latestEnvironment['air_quality'] ??
        latestEnvironment['airQuality'] ??
        latestEnvironment['air_quality_status'] ??
        latestEnvironment['airQualityStatus'];

    final formattedAirQuality = _formatEnvironmentText(airQuality);
    if (formattedAirQuality != '-') return formattedAirQuality;

    final explicitStatus =
        latestEnvironment['air_status'] ??
        latestEnvironment['airStatus'] ??
        latestEnvironment['status'] ??
        latestEnvironment['environment_status'] ??
        latestEnvironment['environmentStatus'];

    final formattedExplicitStatus = _formatEnvironmentText(explicitStatus);
    if (formattedExplicitStatus != '-') return formattedExplicitStatus;

    return '-';
  }

  String _getEnvironmentRiskLevel(
    Map<String, dynamic> latestEnvironment,
    String status,
  ) {
    final explicitRisk =
        latestEnvironment['risk_level'] ??
        latestEnvironment['riskLevel'] ??
        latestEnvironment['risk'] ??
        latestEnvironment['level'];

    final formattedExplicitRisk = _formatEnvironmentText(explicitRisk);
    if (formattedExplicitRisk != '-') {
      return formattedExplicitRisk;
    }

    final statusKey = _normalizeEnvironmentKey(status);

    if (statusKey == 'baik') return 'Normal';
    if (statusKey == 'sedang') return 'Waspada';
    if (statusKey == 'buruk') return 'Waspada';

    return '-';
  }

  Color _getEnvironmentColor({
    required String status,
    required String riskLevel,
  }) {
    final text = '$status $riskLevel'.toLowerCase();

    if (text.contains('darurat') || text.contains('buruk')) {
      return Colors.red;
    }

    if (text.contains('waspada') || text.contains('sedang')) {
      return Colors.orange;
    }

    if (text.contains('normal') || text.contains('baik')) {
      return Colors.green;
    }

    return primaryBlue;
  }

  IconData _getEnvironmentIcon({
    required String status,
    required String riskLevel,
  }) {
    final text = '$status $riskLevel'.toLowerCase();

    if (text.contains('darurat') || text.contains('buruk')) {
      return Icons.warning_amber_rounded;
    }

    if (text.contains('waspada') || text.contains('sedang')) {
      return Icons.air;
    }

    return Icons.eco_outlined;
  }

  Widget _buildEnvironmentDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: verySoftBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentCard(Map<String, dynamic>? latestEnvironment) {
    if (latestEnvironment == null) {
      return Container(
        padding: const EdgeInsets.all(22),
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.circular(24),
          boxShadow: _softShadow,
        ),
        child: const Column(
          children: [
            Icon(Icons.cloud_off_outlined, size: 52, color: mutedText),
            SizedBox(height: 12),
            Text(
              'Data environment belum tersedia',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700, color: darkText),
            ),
          ],
        ),
      );
    }

    final temperature = _formatNumber(
      latestEnvironment['temperature'],
      fractionDigits: 1,
    );

    final humidity = _formatNumber(
      latestEnvironment['humidity'],
      fractionDigits: 0,
    );

    final aqiText = _getAqiDisplayText(latestEnvironment);
    final statusText = _getEnvironmentStatus(latestEnvironment);
    final riskText = _getEnvironmentRiskLevel(latestEnvironment, statusText);

    final environmentColor = _getEnvironmentColor(
      status: statusText,
      riskLevel: riskText,
    );

    final environmentIcon = _getEnvironmentIcon(
      status: statusText,
      riskLevel: riskText,
    );

    final mainStatus = statusText == '-'
        ? 'KUALITAS UDARA BELUM TERSEDIA'
        : statusText.toUpperCase();

    return Container(
      padding: const EdgeInsets.all(22),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: environmentColor.withOpacity(0.12)),
        boxShadow: _softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: environmentColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(environmentIcon, size: 32, color: environmentColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kualitas Udara & Lingkungan',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: darkText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Data kualitas udara, suhu, kelembapan, dan tingkat risiko',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: environmentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                mainStatus,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: environmentColor,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _buildMiniInfoCard(
                icon: Icons.air,
                label: 'AQI',
                value: aqiText,
                color: environmentColor,
              ),
              const SizedBox(width: 10),
              _buildMiniInfoCard(
                icon: Icons.shield_outlined,
                label: 'Risk Level',
                value: riskText,
                color: environmentColor,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildMiniInfoCard(
                icon: Icons.thermostat,
                label: 'Temperature',
                value: '$temperature Â°C',
                color: Colors.deepOrange,
              ),
              const SizedBox(width: 10),
              _buildMiniInfoCard(
                icon: Icons.water_drop_outlined,
                label: 'Humidity',
                value: '$humidity %',
                color: Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildEnvironmentDetailRow(
            icon: Icons.fact_check_outlined,
            label: 'Status Udara',
            value: statusText,
            color: environmentColor,
          ),
          // const SizedBox(height: 10),
          // _buildEnvironmentDetailRow(
          //   icon: Icons.info_outline,
          //   label: 'Sumber AQI',
          //   value: aqiText == '-' ? 'Belum tersedia' : 'OpenWeatherMap',
          //   color: primaryBlue,
          // ),
        ],
      ),
    );
  }

  bool _isEmergencyAlert(dynamic alert) {
    final riskLevel = _getAlertRiskLevel(alert).toLowerCase();
    final alertType = _getAlertType(alert).toLowerCase();

    return riskLevel == 'darurat' ||
        alertType == 'fall_detected' ||
        alertType == 'indikasi_jatuh';
  }

  DateTime? _parseAlertTime(dynamic alert) {
    final rawTime = _getAlertCreatedAt(alert);

    if (rawTime == '-' || rawTime.isEmpty) {
      return null;
    }

    try {
      return DateTime.parse(rawTime).toLocal();
    } catch (e) {
      debugPrint('Gagal parse waktu alert: $e');
      return null;
    }
  }

  bool _isFreshAlert(dynamic alert) {
    final alertTime = _parseAlertTime(alert);

    if (alertTime == null) {
      return false;
    }

    final now = DateTime.now();

    if (alertTime.isAfter(now.add(const Duration(minutes: 1)))) {
      return false;
    }

    return now.difference(alertTime) <= const Duration(minutes: 5);
  }

  Future<void> _checkEmergencyAlerts() async {
    if (_isCheckingAlert) return;
    if (_elderlyActivityItems.isEmpty) return;

    _isCheckingAlert = true;

    try {
      for (final item in _elderlyActivityItems) {
        final elderly = item['elderly'];
        final elderlyId = _getElderlyId(elderly);

        if (elderlyId.isEmpty) continue;

        final result = await _alertService.getElderlyAlerts(
          elderlyId: elderlyId,
        );

        if (!mounted) {
          _isCheckingAlert = false;
          return;
        }

        if (result['success'] != true) continue;

        final List<dynamic> alerts = result['data'] ?? [];

        final emergencyAlerts = alerts.where((alert) {
          return _isEmergencyAlert(alert);
        }).toList();

        if (emergencyAlerts.isEmpty) continue;

        emergencyAlerts.sort((a, b) {
          final timeA = _parseAlertTime(a);
          final timeB = _parseAlertTime(b);

          if (timeA == null && timeB == null) return 0;
          if (timeA == null) return 1;
          if (timeB == null) return -1;

          return timeB.compareTo(timeA);
        });

        final latestAlert = emergencyAlerts.first;
        final latestAlertId = _getAlertId(latestAlert);

        if (latestAlertId.isEmpty) continue;
        if (_shownAlertIds.contains(latestAlertId)) continue;

        if (!_isFreshAlert(latestAlert)) {
          continue;
        }

        _shownAlertIds.add(latestAlertId);
        await _saveShownAlerts();

        await _showEmergencyAlertDialog(
          elderlyName: _getElderlyName(elderly),
          elderlyEmail: _getElderlyEmail(elderly),
          message: _getAlertMessage(latestAlert),
          riskLevel: _getAlertRiskLevel(latestAlert),
          createdAt: _formatWibTime(_getAlertCreatedAt(latestAlert)),
        );
      }
    } catch (e) {
      debugPrint('Gagal cek alert: $e');
    }

    _isCheckingAlert = false;
  }

  String _getElderlyId(dynamic item) {
    if (item is! Map) return '';

    if (item['elderly'] != null && item['elderly'] is Map) {
      return item['elderly']['id']?.toString() ??
          item['elderly']['elderly_id']?.toString() ??
          item['elderly']['elderlyId']?.toString() ??
          item['elderly']['user_id']?.toString() ??
          item['elderly']['userId']?.toString() ??
          '';
    }

    return item['elderly_id']?.toString() ??
        item['elderlyId']?.toString() ??
        item['elderlyID']?.toString() ??
        item['user_id']?.toString() ??
        item['userId']?.toString() ??
        item['id']?.toString() ??
        '';
  }

  String _getElderlyName(dynamic item) {
    if (item is! Map) return 'Nama tidak tersedia';

    if (item['elderly'] != null && item['elderly'] is Map) {
      return item['elderly']['name']?.toString() ?? 'Nama tidak tersedia';
    }

    return item['elderly_name']?.toString() ??
        item['elderlyName']?.toString() ??
        item['name']?.toString() ??
        'Nama tidak tersedia';
  }

  String _getElderlyEmail(dynamic item) {
    if (item is! Map) return 'Email tidak tersedia';

    if (item['elderly'] != null && item['elderly'] is Map) {
      return item['elderly']['email']?.toString() ?? 'Email tidak tersedia';
    }

    return item['elderly_email']?.toString() ??
        item['elderlyEmail']?.toString() ??
        item['email']?.toString() ??
        'Email tidak tersedia';
  }

  String _getActivityStatus(Map<String, dynamic>? activity) {
    if (activity == null) {
      return 'Belum ada data';
    }

    return activity['activityStatus']?.toString() ??
        activity['activity_status']?.toString() ??
        'Belum ada data';
  }

  String _getRiskLevel(Map<String, dynamic>? activity) {
    if (activity == null) {
      return '-';
    }

    return activity['riskLevel']?.toString() ??
        activity['risk_level']?.toString() ??
        '-';
  }

  String _getUpdatedAt(Map<String, dynamic>? activity) {
    if (activity == null) {
      return '-';
    }

    final rawTime =
        activity['createdAt']?.toString() ??
        activity['created_at']?.toString() ??
        '-';

    return _formatWibTime(rawTime);
  }

  String _getAlertId(dynamic alert) {
    if (alert is! Map) return '';

    return alert['id']?.toString() ??
        alert['alert_id']?.toString() ??
        alert['alertId']?.toString() ??
        '';
  }

  String _getAlertType(dynamic alert) {
    if (alert is! Map) return '';

    return alert['alertType']?.toString() ??
        alert['alert_type']?.toString() ??
        '';
  }

  String _getAlertRiskLevel(dynamic alert) {
    if (alert is! Map) return '';

    return alert['riskLevel']?.toString() ??
        alert['risk_level']?.toString() ??
        '';
  }

  String _getAlertMessage(dynamic alert) {
    if (alert is! Map) return 'Terdeteksi indikasi jatuh pada lansia';

    return alert['message']?.toString() ??
        'Terdeteksi indikasi jatuh pada lansia';
  }

  String _getAlertCreatedAt(dynamic alert) {
    if (alert is! Map) return '-';

    return alert['createdAt']?.toString() ??
        alert['created_at']?.toString() ??
        '-';
  }

  String _formatStatusText(String status) {
    if (status == 'aktif') {
      return 'Normal';
    }

    if (status == 'tidak_aktif') {
      return 'Tidak Aktif';
    }

    if (status == 'indikasi_jatuh') {
      return 'Indikasi Jatuh';
    }

    return status;
  }

  Color _getRiskColor(String riskLevel) {
    if (riskLevel == 'darurat') {
      return Colors.red;
    }

    if (riskLevel == 'waspada') {
      return Colors.orange;
    }

    return primaryBlue;
  }

  IconData _getRiskIcon(String riskLevel) {
    if (riskLevel == 'darurat') {
      return Icons.warning_amber_rounded;
    }

    if (riskLevel == 'waspada') {
      return Icons.info_outline;
    }

    return Icons.check_circle_outline;
  }

  Future<void> _showEmergencyAlertDialog({
    required String elderlyName,
    required String elderlyEmail,
    required String message,
    required String riskLevel,
    required String createdAt,
  }) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Peringatan Darurat',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              Text('Lansia: $elderlyName'),
              const SizedBox(height: 4),
              Text('Email: $elderlyEmail'),
              const SizedBox(height: 4),
              Text('Risk Level: $riskLevel'),
              const SizedBox(height: 4),
              Text('Waktu: $createdAt'),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusBadge({
    required String text,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestActivityCard(Map<String, dynamic> item) {
    final elderly = item['elderly'];
    final Map<String, dynamic>? latestActivity = item['latestActivity'];
    final Map<String, dynamic>? latestLocation = item['latestLocation'];
    final Map<String, dynamic>? latestEnvironment = item['latestEnvironment'];

    final elderlyName = _getElderlyName(elderly);
    final elderlyEmail = _getElderlyEmail(elderly);
    final status = _getActivityStatus(latestActivity);
    final riskLevel = _getRiskLevel(latestActivity);
    final updatedAt = _getUpdatedAt(latestActivity);
    final riskColor = _getRiskColor(riskLevel);

    final address = latestLocation?['address'] ?? 'Lokasi belum tersedia';
    final latitude = _toDouble(latestLocation?['latitude']);
    final longitude = _toDouble(latestLocation?['longitude']);

    final activityCard = Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: riskColor.withOpacity(0.14)),
        boxShadow: _softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getRiskIcon(riskLevel),
                  color: riskColor,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      elderlyName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: darkText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      elderlyEmail,
                      style: const TextStyle(color: mutedText, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildStatusBadge(
            text: _formatStatusText(status),
            color: riskColor,
            icon: _getRiskIcon(riskLevel),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: verySoftBlue,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: primaryBlue),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Risk Level',
                        style: TextStyle(
                          color: mutedText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      riskLevel,
                      style: TextStyle(
                        color: riskColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.access_time, color: primaryBlue),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Update terakhir',
                        style: TextStyle(
                          color: mutedText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        updatedAt,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: darkText,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
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

    final environmentCard = _buildEnvironmentCard(latestEnvironment);

    final locationCard = Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: softBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on, color: primaryBlue),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Lokasi Terbaru',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: darkText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: verySoftBlue,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Alamat: $address',
              style: const TextStyle(
                color: darkText,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (latitude != null && longitude != null)
            SizedBox(
              height: 190,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(latitude, longitude),
                    initialZoom: 16,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.projectrasa',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(latitude, longitude),
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
            )
          else
            const Text(
              'Koordinat belum tersedia',
              style: TextStyle(color: mutedText),
            ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [activityCard, environmentCard, locationCard],
    );
  }

  Future<void> _logout(BuildContext context) async {
    _refreshTimer?.cancel();
    _alertTimer?.cancel();

    await _firebaseAuthService.logout();
    await _storageService.clearSession();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _openIncomingConnections(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const IncomingConnectionsScreen()),
    ).then((_) {
      _loadDashboardData();
    });
  }

  void _openConnectedElderlies(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConnectedElderliesScreen()),
    ).then((_) {
      _loadDashboardData();
    });
  }

  void _openNotificationHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationHistoryScreen()),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _alertTimer?.cancel();
    super.dispose();
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
              Icons.family_restroom,
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
                  'Dashboard Keluarga',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Pantau aktivitas, lingkungan, dan lokasi lansia secara real-time.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
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

  Widget _buildSectionTitle() {
    return Row(
      children: [
        Container(
          width: 5,
          height: 24,
          decoration: BoxDecoration(
            color: primaryBlue,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Aktivitas Terakhir',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: darkText,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyElderlyCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _softShadow,
      ),
      child: const Column(
        children: [
          Icon(Icons.person_off_outlined, size: 62, color: primaryBlue),
          SizedBox(height: 12),
          Text(
            'Belum ada lansia terhubung',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: darkText,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Terima permintaan dari lansia terlebih dahulu.',
            textAlign: TextAlign.center,
            style: TextStyle(color: mutedText),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: verySoftBlue,
      appBar: AppBar(
        title: const Text('Dashboard Keluarga'),
        backgroundColor: softBlue,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Riwayat Notifikasi',
            onPressed: () {
              _openNotificationHistory(context);
            },
            icon: const Icon(Icons.notifications_none),
          ),
          IconButton(
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FamilyProfilScreen()),
              );
            },
            icon: const Icon(Icons.person),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: primaryBlue,
          onRefresh: () => _loadDashboardData(),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 26),
              _buildSectionTitle(),
              const SizedBox(height: 14),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: primaryBlue),
                  ),
                )
              else if (_elderlyActivityItems.isEmpty)
                _buildEmptyElderlyCard()
              else
                ..._elderlyActivityItems.map(_buildLatestActivityCard),
            ],
          ),
        ),
      ),
    );
  }
}

