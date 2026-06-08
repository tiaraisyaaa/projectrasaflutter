import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../services/activity_service.dart';
import '../../services/alert_service.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/storage_service.dart';
import '../auth/login_screen.dart';
import '../connection/connected_families_screen.dart';
import '../connection/send_connection_request_screen.dart';

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

  // Dibuat lebih berat supaya HP tidak mudah dianggap jatuh.
  // Kalau masih terlalu sensitif, naikkan ke 40.
  // Kalau terlalu susah terdeteksi, turunkan ke 30.
  static const double impactThreshold = 35.0;

  // Setelah benturan besar, HP harus relatif diam.
  // HP diam biasanya accelerationValue sekitar 9.8 karena gravitasi.
  static const double restMinAcceleration = 8.0;
  static const double restMaxAcceleration = 12.0;

  // Jatuh baru valid kalau setelah benturan HP relatif diam selama 2 detik.
  static const int requiredRestAfterImpactSeconds = 2;

  // Setelah benturan, sistem hanya menunggu beberapa detik untuk konfirmasi.
  static const int fallConfirmationWindowSeconds = 5;

  // Kalau jatuh terdeteksi, status ditahan 2 menit supaya tidak langsung normal.
  static const int fallStatusLockSeconds = 120;

  // Supaya aktivitas normal tidak terlalu sering masuk database.
  static const int normalActivityPostIntervalSeconds = 120;

  // Supaya data darurat tidak spam.
  static const int emergencyPostCooldownSeconds = 120;

  // Supaya alert jatuh tidak spam.
  static const int alertCooldownSeconds = 120;

  @override
  void initState() {
    super.initState();
    _startSensorMonitoring();
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

    // Kalau status jatuh sedang dikunci, jangan langsung balik normal.
    if (_fallLockUntil != null && now.isBefore(_fallLockUntil!)) {
      return;
    }

    // Kalau waktu lock jatuh sudah selesai, bersihkan lock.
    if (_fallLockUntil != null && now.isAfter(_fallLockUntil!)) {
      _fallLockUntil = null;
      _impactDetectedAt = null;
      _restAfterImpactStartedAt = null;
    }

    // Tahap 1: deteksi hentakan besar.
    if (acceleration >= impactThreshold) {
      _impactDetectedAt = now;
      _restAfterImpactStartedAt = null;

      debugPrint('Hentakan besar terdeteksi: $acceleration');
      return;
    }

    // Tahap 2: setelah hentakan, cek apakah HP relatif diam.
    if (_impactDetectedAt != null) {
      final int secondsAfterImpact =
          now.difference(_impactDetectedAt!).inSeconds;

      final bool stillInConfirmationWindow =
          secondsAfterImpact <= fallConfirmationWindowSeconds;

      final bool phoneLooksResting = acceleration >= restMinAcceleration &&
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

      // Selama masa konfirmasi, jangan langsung ubah status.
      return;
    }

    _setActiveStatus();
  }

  void _setFallStatus() {
    final now = DateTime.now();

    setState(() {
      _activityStatus = 'indikasi_jatuh';
      _riskLevel = 'darurat';
      _fallLockUntil = now.add(
        const Duration(seconds: fallStatusLockSeconds),
      );
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
    if (status == 'indikasi_jatuh') {
      return 'darurat';
    }

    if (status == 'tidak_aktif') {
      return 'waspada';
    }

    return 'normal';
  }

  Future<void> _maybeSendActivity({
    bool forceEmergency = false,
  }) async {
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

      if (!emergencyCooldownReached) {
        return;
      }
    }

    if (!forceEmergency && !statusChanged && !intervalReached) {
      return;
    }

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

      if (isEmergency) {
        _lastEmergencySentAt = now;
      }

      debugPrint('Aktivitas terkirim: $statusToSend | risk: $riskLevelToSend');
    } else {
      debugPrint('Gagal kirim aktivitas: ${result['message']}');
    }
  }

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

    final result = await _alertService.createAlert(
      alertType: 'fall_detected',
      message: 'Terdeteksi indikasi jatuh pada lansia',
      riskLevel: 'darurat',
      latitude: 0,
      longitude: 0,
    );

    _isSendingAlert = false;

    if (!mounted) return;

    if (result['success'] == true) {
      _lastAlertSentAt = now;
      debugPrint('Alert jatuh terkirim');
    } else {
      debugPrint('Gagal kirim alert: ${result['message']}');
    }
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

  Future<void> _logout(BuildContext context) async {
    await _accelerometerSubscription?.cancel();
    await _firebaseAuthService.logout();
    await _storageService.clearSession();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  void _openSendConnectionRequest(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SendConnectionRequestScreen(),
      ),
    );
  }

  void _openConnectedFamilies(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ConnectedFamiliesScreen(),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    super.dispose();
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
              _logout(context);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      _getStatusIcon(),
                      size: 78,
                      color: statusColor,
                    ),
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
}