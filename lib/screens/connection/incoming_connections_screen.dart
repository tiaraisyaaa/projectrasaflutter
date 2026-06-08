import 'package:flutter/material.dart';

import '../../services/connection_service.dart';

class IncomingConnectionsScreen extends StatefulWidget {
  const IncomingConnectionsScreen({super.key});

  @override
  State<IncomingConnectionsScreen> createState() =>
      _IncomingConnectionsScreenState();
}

class _IncomingConnectionsScreenState extends State<IncomingConnectionsScreen> {
  final ConnectionService _connectionService = ConnectionService();

  bool _isLoading = true;
  bool _isUpdating = false;
  List<dynamic> _connections = [];

  @override
  void initState() {
    super.initState();
    _loadIncomingConnections();
  }

  Future<void> _loadIncomingConnections() async {
    setState(() {
      _isLoading = true;
    });

    final result = await _connectionService.getIncomingConnections();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      setState(() {
        _connections = result['data'] ?? [];
      });

      debugPrint('Incoming connections: $_connections');
    } else {
      _showMessage(result['message']);
    }
  }

  Future<void> _updateStatus({
    required String connectionId,
    required String status,
  }) async {
    if (connectionId.isEmpty) {
      _showMessage('ID koneksi tidak ditemukan dari response API');
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    debugPrint('Update connection id: $connectionId');
    debugPrint('Update status: $status');

    final result = await _connectionService.updateConnectionStatus(
      connectionId: connectionId,
      status: status,
    );

    if (!mounted) return;

    setState(() {
      _isUpdating = false;
    });

    _showMessage(result['message']);

    if (result['success'] == true) {
      await _loadIncomingConnections();
    }
  }

  String _getConnectionId(dynamic connection) {
    return connection['id']?.toString() ??
        connection['connection_id']?.toString() ??
        connection['connectionId']?.toString() ??
        connection['ConnectionId']?.toString() ??
        connection['connection']?['id']?.toString() ??
        connection['connection']?['connection_id']?.toString() ??
        connection['connection']?['connectionId']?.toString() ??
        '';
  }

  String _getElderlyName(dynamic connection) {
    if (connection['elderly'] != null) {
      return connection['elderly']['name']?.toString() ?? 'Nama tidak tersedia';
    }

    return connection['elderly_name']?.toString() ??
        connection['elderlyName']?.toString() ??
        connection['name']?.toString() ??
        'Nama tidak tersedia';
  }

  String _getElderlyEmail(dynamic connection) {
    if (connection['elderly'] != null) {
      return connection['elderly']['email']?.toString() ??
          'Email tidak tersedia';
    }

    return connection['elderly_email']?.toString() ??
        connection['elderlyEmail']?.toString() ??
        connection['email']?.toString() ??
        'Email tidak tersedia';
  }

  String _getStatus(dynamic connection) {
    return connection['status']?.toString() ?? 'pending';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Widget _buildConnectionCard(dynamic connection) {
    final connectionId = _getConnectionId(connection);
    final elderlyName = _getElderlyName(connection);
    final elderlyEmail = _getElderlyEmail(connection);
    final status = _getStatus(connection);

    debugPrint('Connection item: $connection');
    debugPrint('Connection ID terbaca: $connectionId');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.elderly,
            color: Colors.teal,
            size: 42,
          ),

          const SizedBox(height: 10),

          Text(
            elderlyName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            elderlyEmail,
            style: const TextStyle(
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Status: $status',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isUpdating
                      ? null
                      : () {
                          _updateStatus(
                            connectionId: connectionId,
                            status: 'accepted',
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Terima'),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: OutlinedButton(
                  onPressed: _isUpdating
                      ? null
                      : () {
                          _updateStatus(
                            connectionId: connectionId,
                            status: 'rejected',
                          );
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Tolak'),
                ),
              ),
            ],
          ),

          if (_isUpdating) ...[
            const SizedBox(height: 12),
            const Center(
              child: CircularProgressIndicator(
                color: Colors.teal,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F8),
      appBar: AppBar(
        title: const Text('Permintaan Masuk'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.teal,
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadIncomingConnections,
                child: _connections.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(24),
                        children: const [
                          SizedBox(height: 160),
                          Icon(
                            Icons.inbox_outlined,
                            size: 70,
                            color: Colors.teal,
                          ),
                          SizedBox(height: 16),
                          Center(
                            child: Text(
                              'Belum ada permintaan masuk',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          Center(
                            child: Text(
                              'Permintaan dari lansia akan tampil di sini.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: _connections.length,
                        itemBuilder: (context, index) {
                          return _buildConnectionCard(_connections[index]);
                        },
                      ),
              ),
      ),
    );
  }
}