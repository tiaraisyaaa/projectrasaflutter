import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/alert_service.dart';
import '../../services/connection_service.dart';

class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  State<NotificationHistoryScreen> createState() =>
      _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  final ConnectionService _connectionService = ConnectionService();
  final AlertService _alertService = AlertService();

  bool _isLoading = true;
  String? _errorMessage;

  final List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _notifications.clear();
    });

    try {
      final connectedResult = await _connectionService.getConnectedElderlies();

      if (!mounted) return;

      if (connectedResult['success'] != true) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              connectedResult['message'] ?? 'Gagal mengambil data lansia';
        });
        return;
      }

      final List<dynamic> elderlies = _normalizeList(connectedResult['data']);
      final List<Map<String, dynamic>> tempNotifications = [];

      for (final elderly in elderlies) {
        final elderlyId = _getElderlyId(elderly);

        if (elderlyId.isEmpty) continue;

        final alertResult = await _alertService.getElderlyAlerts(
          elderlyId: elderlyId,
        );

        if (alertResult['success'] == true) {
          final List<dynamic> alerts = _normalizeList(alertResult['data']);

          for (final alert in alerts) {
            tempNotifications.add({
              'elderlyName': _getElderlyName(elderly),
              'elderlyEmail': _getElderlyEmail(elderly),
              'alert': alert,
            });
          }
        }
      }

      tempNotifications.sort((a, b) {
        final timeA = _getAlertDateTime(a['alert']);
        final timeB = _getAlertDateTime(b['alert']);

        if (timeA == null && timeB == null) return 0;
        if (timeA == null) return 1;
        if (timeB == null) return -1;

        return timeB.compareTo(timeA);
      });

      if (!mounted) return;

      setState(() {
        _notifications.addAll(tempNotifications);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal mengambil riwayat notifikasi: $e';
      });
    }
  }

  List<dynamic> _normalizeList(dynamic data) {
    if (data is List) return data;

    if (data is Map) {
      final possibleList =
          data['data'] ??
          data['alerts'] ??
          data['notifications'] ??
          data['items'];

      if (possibleList is List) return possibleList;
    }

    return [];
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
    if (item is! Map) return 'Lansia';

    if (item['elderly'] != null && item['elderly'] is Map) {
      return item['elderly']['name']?.toString() ?? 'Lansia';
    }

    return item['elderly_name']?.toString() ??
        item['elderlyName']?.toString() ??
        item['name']?.toString() ??
        'Lansia';
  }

  String _getElderlyEmail(dynamic item) {
    if (item is! Map) return '-';

    if (item['elderly'] != null && item['elderly'] is Map) {
      return item['elderly']['email']?.toString() ?? '-';
    }

    return item['elderly_email']?.toString() ??
        item['elderlyEmail']?.toString() ??
        item['email']?.toString() ??
        '-';
  }

  String _getAlertId(dynamic alert) {
    if (alert is! Map) return '';

    return alert['id']?.toString() ??
        alert['alert_id']?.toString() ??
        alert['alertId']?.toString() ??
        '';
  }

  DateTime? _getAlertDateTime(dynamic alert) {
    if (alert is! Map) return null;

    final rawTime =
        alert['created_at'] ??
        alert['createdAt'] ??
        alert['timestamp'] ??
        alert['time'] ??
        alert['date'];

    if (rawTime == null) return null;

    return DateTime.tryParse(rawTime.toString());
  }

  String _formatAlertTime(dynamic alert) {
    final dateTime = _getAlertDateTime(alert);

    if (dateTime == null) return '-';

    return DateFormat('dd MMM yyyy, HH:mm').format(dateTime.toLocal());
  }

  String _getAlertMessage(dynamic alert) {
    if (alert is! Map) return 'Notifikasi darurat';

    return alert['message']?.toString() ??
        alert['alert_message']?.toString() ??
        alert['alertMessage']?.toString() ??
        'Notifikasi darurat';
  }

  String _getAlertType(dynamic alert) {
    if (alert is! Map) return '-';

    return alert['alert_type']?.toString() ??
        alert['alertType']?.toString() ??
        alert['type']?.toString() ??
        '-';
  }

  String _getRiskLevel(dynamic alert) {
    if (alert is! Map) return '-';

    return alert['risk_level']?.toString() ??
        alert['riskLevel']?.toString() ??
        alert['level']?.toString() ??
        '-';
  }

  String _getLatitude(dynamic alert) {
    if (alert is! Map) return '-';

    return alert['latitude']?.toString() ?? alert['lat']?.toString() ?? '-';
  }

  String _getLongitude(dynamic alert) {
    if (alert is! Map) return '-';

    return alert['longitude']?.toString() ??
        alert['lng']?.toString() ??
        alert['lon']?.toString() ??
        '-';
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'darurat':
      case 'tinggi':
      case 'high':
        return Colors.red;
      case 'waspada':
      case 'sedang':
      case 'medium':
        return Colors.orange;
      case 'normal':
      case 'rendah':
      case 'low':
        return Colors.green;
      default:
        return Colors.teal;
    }
  }

  IconData _getRiskIcon(String riskLevel, String alertType) {
    final type = alertType.toLowerCase();

    if (type.contains('fall') || type.contains('jatuh')) {
      return Icons.warning_amber_rounded;
    }

    switch (riskLevel.toLowerCase()) {
      case 'darurat':
      case 'tinggi':
      case 'high':
        return Icons.warning_amber_rounded;
      case 'waspada':
      case 'sedang':
      case 'medium':
        return Icons.info_outline;
      default:
        return Icons.notifications_none;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F8),
      appBar: AppBar(
        title: const Text('Riwayat Notifikasi'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadNotifications,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.teal))
            : _errorMessage != null
            ? _buildErrorState()
            : _notifications.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
                onRefresh: _loadNotifications,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    return _buildNotificationCard(_notifications[index]);
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 56),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Terjadi kesalahan',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadNotifications,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              color: Colors.black38,
              size: 64,
            ),
            SizedBox(height: 12),
            Text(
              'Belum ada riwayat notifikasi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Notifikasi dari lansia terhubung akan muncul di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> item) {
    final alert = item['alert'];
    final riskLevel = _getRiskLevel(alert);
    final alertType = _getAlertType(alert);
    final riskColor = _getRiskColor(riskLevel);
    final alertId = _getAlertId(alert);

    final latitude = _getLatitude(alert);
    final longitude = _getLongitude(alert);
    final hasLocation = latitude != '-' && longitude != '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: riskColor.withOpacity(0.12),
            child: Icon(_getRiskIcon(riskLevel, alertType), color: riskColor),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getAlertMessage(alert),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Lansia: ${item['elderlyName']}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 2),

                Text(
                  item['elderlyEmail']?.toString() ?? '-',
                  style: const TextStyle(color: Colors.black54),
                ),

                const SizedBox(height: 10),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChip(
                      Icons.category_outlined,
                      alertType,
                      Colors.blueGrey,
                    ),
                    _buildChip(Icons.shield_outlined, riskLevel, riskColor),
                    _buildChip(
                      Icons.access_time,
                      _formatAlertTime(alert),
                      Colors.teal,
                    ),
                  ],
                ),

                if (hasLocation) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F8F8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: Colors.teal,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lokasi: $latitude, $longitude',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (alertId.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'ID Alert: $alertId',
                    style: const TextStyle(fontSize: 11, color: Colors.black38),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label.isEmpty ? '-' : label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
