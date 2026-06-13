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

  bool _isLoading = true;
  bool _isCheckingAlert = false;

  List<Map<String, dynamic>> _elderlyActivityItems = [];

  Timer? _refreshTimer;
  Timer? _alertTimer;

  final Set<String> _shownAlertIds = {};

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

  Widget _buildEnvironmentCard(Map<String, dynamic>? latestEnvironment) {
    if (latestEnvironment == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.only(bottom: 24),
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
        child: const Text(
          'Data environment belum tersedia',
          textAlign: TextAlign.center,
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

    final airQuality =
        latestEnvironment['air_quality']?.toString() ??
        latestEnvironment['airQuality']?.toString() ??
        '-';

    final riskLevel =
        latestEnvironment['risk_level']?.toString() ??
        latestEnvironment['riskLevel']?.toString() ??
        '-';

    Color qualityColor;
    IconData qualityIcon;

    switch (airQuality.toLowerCase()) {
      case 'baik':
        qualityColor = Colors.green;
        qualityIcon = Icons.eco;
        break;
      case 'sedang':
        qualityColor = Colors.orange;
        qualityIcon = Icons.air;
        break;
      case 'buruk':
        qualityColor = Colors.red;
        qualityIcon = Icons.masks;
        break;
      default:
        qualityColor = Colors.teal;
        qualityIcon = Icons.cloud;
    }

    final riskText = riskLevel.isNotEmpty && riskLevel != '-'
        ? '${riskLevel[0].toUpperCase()}${riskLevel.substring(1)}'
        : '-';

    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 24),
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
          Icon(qualityIcon, size: 78, color: qualityColor),
          const SizedBox(height: 16),
          Text(
            airQuality.toUpperCase(),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: qualityColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Temperature: $temperature °C',
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),
          Text(
            'Humidity: $humidity %',
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),
          Text(
            'Risk Level: $riskText',
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),
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

    return Colors.teal;
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: riskColor.withOpacity(0.18)),
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
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: riskColor.withOpacity(0.12),
                child: Icon(_getRiskIcon(riskLevel), color: riskColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      elderlyName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      elderlyEmail,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Status: ${_formatStatusText(status)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: riskColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Risk Level: $riskLevel',
            style: const TextStyle(color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            'Update terakhir: $updatedAt',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
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
                'Lokasi Terbaru',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Alamat: $address'),
          const SizedBox(height: 12),
          if (latitude != null && longitude != null)
            SizedBox(
              height: 180,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
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
              style: TextStyle(color: Colors.black54),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F8),
      appBar: AppBar(
        title: const Text('Dashboard Keluarga'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
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
                MaterialPageRoute(builder: (_) => const FamilyProfilScreen()),
              );
            },
            icon: const Icon(Icons.person),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadDashboardData(),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
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
                child: const Column(
                  children: [
                    Icon(Icons.family_restroom, size: 70, color: Colors.teal),
                    SizedBox(height: 14),
                    Text(
                      'Dashboard Keluarga',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Pantau aktivitas terakhir lansia yang sudah terhubung.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Aktivitas Terakhir',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: Colors.teal),
                  ),
                )
              else if (_elderlyActivityItems.isEmpty)
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.person_off_outlined,
                        size: 60,
                        color: Colors.teal,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Belum ada lansia terhubung',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Terima permintaan dari lansia terlebih dahulu.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                )
              else
                ..._elderlyActivityItems.map(_buildLatestActivityCard),
            ],
          ),
        ),
      ),
    );
  }
}
