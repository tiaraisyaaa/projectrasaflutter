import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'activity_service.dart';
import 'alert_service.dart';
import 'location_service.dart';
import 'storage_service.dart';

class BackgroundSensorService {
  static bool _isConfigured = false;

  static const String notificationChannelId = 'rasa_sensor_service';
  static const int foregroundServiceNotificationId = 888;

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    if (_isConfigured) return;

    final service = FlutterBackgroundService();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
  settings: initializationSettings,
);
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'RASA Sensor Service',
      description: 'Notifikasi untuk pemantauan aktivitas lansia',
      importance: Importance.low,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'RASA Aktif',
        initialNotificationContent: 'Memantau aktivitas lansia',
        foregroundServiceNotificationId: foregroundServiceNotificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );

    _isConfigured = true;
  }

  static Future<void> start() async {
    await initialize();

    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();

    if (!isRunning) {
      await service.startService();
    }

    service.invoke('start_monitoring');
  }

  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();

    if (isRunning) {
      service.invoke('stopService');
    }
  }

  static Stream<Map<String, dynamic>?> get activityUpdates {
    return FlutterBackgroundService().on('activity_update');
  }
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final ActivityService activityService = ActivityService();
  final AlertService alertService = AlertService();
  final LocationService locationService = LocationService();
  final StorageService storageService = StorageService();

  StreamSubscription<AccelerometerEvent>? accelerometerSubscription;
  Timer? heartbeatTimer;

  double xAxis = 0;
  double yAxis = 0;
  double zAxis = 0;
  double accelerationValue = 0;

  String activityStatus = 'memulai_monitoring';
  String riskLevel = 'normal';

  String? lastSentStatus;
  DateTime? lastSentAt;
  DateTime? lastEmergencySentAt;
  DateTime? lastAlertSentAt;

  DateTime? impactDetectedAt;
  DateTime? restAfterImpactStartedAt;
  DateTime? fallLockUntil;
  DateTime? lastUiUpdateAt;

  bool isSending = false;
  bool isSendingAlert = false;

  const double impactThreshold = 35.0;
  const double restMinAcceleration = 8.0;
  const double restMaxAcceleration = 12.0;
  const int requiredRestAfterImpactSeconds = 2;
  const int fallConfirmationWindowSeconds = 5;
  const int fallStatusLockSeconds = 120;
  const int normalActivityPostIntervalSeconds = 120;
  const int emergencyPostCooldownSeconds = 120;
  const int alertCooldownSeconds = 120;

  String getRiskLevelFromStatus(String status) {
    if (status == 'indikasi_jatuh') return 'darurat';
    if (status == 'tidak_aktif') return 'waspada';
    return 'normal';
  }

  void sendActivityUpdate({bool force = false}) {
    final now = DateTime.now();

    if (!force &&
        lastUiUpdateAt != null &&
        now.difference(lastUiUpdateAt!).inSeconds < 1) {
      return;
    }

    lastUiUpdateAt = now;

    service.invoke(
      'activity_update',
      {
        'xAxis': double.parse(xAxis.toStringAsFixed(2)),
        'yAxis': double.parse(yAxis.toStringAsFixed(2)),
        'zAxis': double.parse(zAxis.toStringAsFixed(2)),
        'accelerationValue': double.parse(accelerationValue.toStringAsFixed(2)),
        'activityStatus': activityStatus,
        'riskLevel': riskLevel,
        'updatedAt': now.toIso8601String(),
      },
    );
  }

  Future<void> maybeSendActivity({bool forceEmergency = false}) async {
    if (isSending) return;

    final now = DateTime.now();
    final String statusToSend = activityStatus;
    final String riskLevelToSend = getRiskLevelFromStatus(statusToSend);

    final bool isEmergency = statusToSend == 'indikasi_jatuh';
    final bool statusChanged = lastSentStatus != statusToSend;
    final bool intervalReached = lastSentAt == null ||
        now.difference(lastSentAt!).inSeconds >=
            normalActivityPostIntervalSeconds;

    if (isEmergency) {
      final bool emergencyCooldownReached = lastEmergencySentAt == null ||
          now.difference(lastEmergencySentAt!).inSeconds >=
              emergencyPostCooldownSeconds;

      if (!emergencyCooldownReached) return;
    }

    if (!forceEmergency && !statusChanged && !intervalReached) return;

    isSending = true;

    try {
      final result = await activityService.createActivity(
        xAxis: double.parse(xAxis.toStringAsFixed(2)),
        yAxis: double.parse(yAxis.toStringAsFixed(2)),
        zAxis: double.parse(zAxis.toStringAsFixed(2)),
        accelerationValue: double.parse(accelerationValue.toStringAsFixed(2)),
        activityStatus: statusToSend,
        riskLevel: riskLevelToSend,
      );

      if (result['success'] == true) {
        lastSentStatus = statusToSend;
        lastSentAt = now;

        if (isEmergency) {
          lastEmergencySentAt = now;
        }

        print('BACKGROUND ACTIVITY TERKIRIM: $statusToSend');
      } else {
        print('BACKGROUND GAGAL KIRIM ACTIVITY: ${result['message']}');
      }
    } catch (e) {
      print('BACKGROUND ERROR KIRIM ACTIVITY: $e');
    }

    isSending = false;
  }

  double? toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  Future<void> sendFallAlert() async {
  if (isSendingAlert) {
    print('BACKGROUND ALERT TIDAK DIKIRIM: sedang mengirim alert lain');
    return;
  }

  final now = DateTime.now();

  final bool alertCooldownReached = lastAlertSentAt == null ||
      now.difference(lastAlertSentAt!).inSeconds >= alertCooldownSeconds;

  if (!alertCooldownReached) {
    print('BACKGROUND ALERT TIDAK DIKIRIM: masih cooldown');
    return;
  }

  isSendingAlert = true;

  try {
    double latitude = 0;
    double longitude = 0;

    print('BACKGROUND MULAI PROSES ALERT JATUH');

    try {
      final locationResult = await locationService
          .saveCurrentLocation()
          .timeout(const Duration(seconds: 5));

      final locationData =
          locationResult['location'] ?? locationResult['data'] ?? locationResult;

      if (locationData is Map) {
        latitude = toDouble(locationData['latitude']) ?? 0;
        longitude = toDouble(locationData['longitude']) ?? 0;
      }

      print('BACKGROUND LOKASI ALERT: $latitude, $longitude');
    } catch (e) {
      print(
        'BACKGROUND LOKASI ALERT GAGAL/TIMEOUT, ALERT TETAP DIKIRIM: $e',
      );
    }

    print('BACKGROUND MULAI KIRIM ALERT JATUH');

    final result = await alertService.createAlert(
      alertType: 'fall_detected',
      message: 'Terdeteksi indikasi jatuh pada lansia',
      riskLevel: 'darurat',
      latitude: latitude,
      longitude: longitude,
    );

    if (result['success'] == true) {
      lastAlertSentAt = now;
      print('BACKGROUND ALERT JATUH TERKIRIM');
    } else {
      print('BACKGROUND GAGAL KIRIM ALERT: ${result['message']}');
    }
  } catch (e) {
    print('BACKGROUND ERROR KIRIM ALERT JATUH: $e');
  }

  isSendingAlert = false;
}

  void setFallStatus() {
    final now = DateTime.now();

    activityStatus = 'indikasi_jatuh';
    riskLevel = 'darurat';
    fallLockUntil = now.add(const Duration(seconds: fallStatusLockSeconds));
    impactDetectedAt = null;
    restAfterImpactStartedAt = null;

    sendActivityUpdate(force: true);
    maybeSendActivity(forceEmergency: true);
    sendFallAlert();

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'RASA: Indikasi Jatuh',
        content: 'Sistem mendeteksi kemungkinan jatuh pada lansia',
      );
    }
  }

  void setActiveStatus() {
    if (activityStatus == 'aktif' && riskLevel == 'normal') {
      maybeSendActivity();
      sendActivityUpdate();
      return;
    }

    activityStatus = 'aktif';
    riskLevel = 'normal';

    sendActivityUpdate(force: true);
    maybeSendActivity();

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'RASA Aktif',
        content: 'Sensor aktivitas lansia sedang berjalan',
      );
    }
  }

  void handleAccelerometerEvent(AccelerometerEvent event) {
    final now = DateTime.now();

    final double x = event.x;
    final double y = event.y;
    final double z = event.z;
    final double acceleration = sqrt((x * x) + (y * y) + (z * z));

    xAxis = x;
    yAxis = y;
    zAxis = z;
    accelerationValue = acceleration;

    if (fallLockUntil != null && now.isBefore(fallLockUntil!)) {
      sendActivityUpdate();
      return;
    }

    if (fallLockUntil != null && now.isAfter(fallLockUntil!)) {
      fallLockUntil = null;
      impactDetectedAt = null;
      restAfterImpactStartedAt = null;
    }

    if (acceleration >= impactThreshold) {
      impactDetectedAt = now;
      restAfterImpactStartedAt = null;
      print('BACKGROUND HENTAKAN BESAR: $acceleration');
      sendActivityUpdate(force: true);
      return;
    }

    if (impactDetectedAt != null) {
      final int secondsAfterImpact =
          now.difference(impactDetectedAt!).inSeconds;

      final bool stillInConfirmationWindow =
          secondsAfterImpact <= fallConfirmationWindowSeconds;

      final bool phoneLooksResting =
          acceleration >= restMinAcceleration &&
          acceleration <= restMaxAcceleration;

      if (!stillInConfirmationWindow) {
        impactDetectedAt = null;
        restAfterImpactStartedAt = null;
        setActiveStatus();
        return;
      }

      if (phoneLooksResting) {
        restAfterImpactStartedAt ??= now;

        final int restDuration =
            now.difference(restAfterImpactStartedAt!).inSeconds;

        if (restDuration >= requiredRestAfterImpactSeconds) {
          setFallStatus();
          return;
        }
      } else {
        restAfterImpactStartedAt = null;
      }

      sendActivityUpdate();
      return;
    }

    setActiveStatus();
  }

  Future<void> startMonitoring() async {
    if (accelerometerSubscription != null) return;

    if (service is AndroidServiceInstance) {
      await service.setAsForegroundService();

      service.setForegroundNotificationInfo(
        title: 'RASA Aktif',
        content: 'Sensor aktivitas lansia sedang berjalan',
      );
    }

    activityStatus = 'memulai_monitoring';
    riskLevel = 'normal';
    sendActivityUpdate(force: true);

    accelerometerSubscription = accelerometerEventStream().listen(
      handleAccelerometerEvent,
      onError: (error) {
        print('BACKGROUND SENSOR ERROR: $error');
      },
    );

    heartbeatTimer?.cancel();
    heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      sendActivityUpdate(force: true);

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'RASA Aktif',
          content: 'Sensor aktivitas lansia sedang berjalan',
        );
      }
    });

    print('BACKGROUND SENSOR MONITORING DIMULAI');
  }

  Future<void> stopMonitoring() async {
    await accelerometerSubscription?.cancel();
    accelerometerSubscription = null;

    heartbeatTimer?.cancel();
    heartbeatTimer = null;

    print('BACKGROUND SENSOR MONITORING DIHENTIKAN');
  }

  service.on('start_monitoring').listen((event) {
    startMonitoring();
  });

  service.on('stop_monitoring').listen((event) {
    stopMonitoring();
  });

  service.on('stopService').listen((event) async {
    await stopMonitoring();
    service.stopSelf();
  });

  startMonitoring();
}