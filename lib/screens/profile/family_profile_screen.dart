import 'package:flutter/material.dart';

import '../../services/storage_service.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/connection_service.dart';
import '../auth/login_screen.dart';

class FamilyProfilScreen extends StatefulWidget {
  const FamilyProfilScreen({super.key});

  @override
  State<FamilyProfilScreen> createState() => _FamilyProfileScreenState();
}

class _FamilyProfileScreenState extends State<FamilyProfilScreen> {
  final StorageService _storageService = StorageService();
  final FirebaseAuthService _authService = FirebaseAuthService();
  final ConnectionService _connectionService = ConnectionService();

  String? _name;
  String? _email;
  String? _role;

  bool _isLoadingConnections = true;
  List<dynamic> _incomingRequests = [];
  List<dynamic> _connectedElderlies = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadFamilyConnectionData();
  }

  Future<void> _loadProfile() async {
    final name = await _storageService.getName();
    final email = await _storageService.getEmail();
    final role = await _storageService.getRole();

    if (!mounted) return;

    setState(() {
      _name = name;
      _email = email;
      _role = role;
    });
  }

  Future<void> _loadFamilyConnectionData() async {
    setState(() {
      _isLoadingConnections = true;
    });

    final incomingResult = await _connectionService.getIncomingConnections();
    final connectedResult = await _connectionService.getConnectedElderlies();

    if (!mounted) return;

    setState(() {
      _isLoadingConnections = false;

      if (incomingResult['success'] == true) {
        _incomingRequests = incomingResult['data'] ?? [];
      } else {
        _incomingRequests = [];
      }

      if (connectedResult['success'] == true) {
        _connectedElderlies = connectedResult['data'] ?? [];
      } else {
        _connectedElderlies = [];
      }
    });

    debugPrint('INCOMING REQUESTS: $_incomingRequests');
    debugPrint('CONNECTED ELDERLIES: $_connectedElderlies');
  }

  String _getConnectionId(dynamic item) {
    return item['connection_id']?.toString() ??
        item['connectionId']?.toString() ??
        item['id']?.toString() ??
        '';
  }

  String _getElderlyName(dynamic item) {
    if (item['elderly'] != null) {
      return item['elderly']['name']?.toString() ?? 'Nama tidak tersedia';
    }

    return item['elderly_name']?.toString() ??
        item['elderlyName']?.toString() ??
        item['name']?.toString() ??
        'Nama tidak tersedia';
  }

  String _getElderlyEmail(dynamic item) {
    if (item['elderly'] != null) {
      return item['elderly']['email']?.toString() ?? 'Email tidak tersedia';
    }

    return item['elderly_email']?.toString() ??
        item['elderlyEmail']?.toString() ??
        item['email']?.toString() ??
        'Email tidak tersedia';
  }

  Future<void> _respondIncomingRequest({
    required String connectionId,
    required String status,
  }) async {
    if (connectionId.isEmpty) {
      _showMessage('ID koneksi tidak ditemukan');
      return;
    }

    final result = await _connectionService.updateConnectionStatus(
      connectionId: connectionId,
      status: status,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      _showMessage(
        status == 'accepted'
            ? 'Permintaan berhasil diterima'
            : 'Permintaan berhasil ditolak',
      );

      await _loadFamilyConnectionData();
    } else {
      _showMessage(result['message'] ?? 'Gagal memproses permintaan');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Konfirmasi Logout'),
          content: const Text('Apakah Anda yakin ingin logout dari akun ini?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await _authService.logout();
    await _storageService.clearSession();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _buildProfileInfo() {
    final initial = (_name != null && _name!.isNotEmpty)
        ? _name!.substring(0, 1).toUpperCase()
        : '?';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.teal.shade100,
          child: Text(
            initial,
            style: const TextStyle(
              fontSize: 40,
              color: Colors.teal,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Nama:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(_name ?? '-'),
        const SizedBox(height: 12),
        const Text(
          'Email:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(_email ?? '-'),
        const SizedBox(height: 12),
        const Text(
          'Role:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(_role ?? '-'),
      ],
    );
  }

  Widget _buildEmptyConnectionCard() {
    return Container(
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
          Icon(
            Icons.group_off_outlined,
            size: 60,
            color: Colors.teal,
          ),
          SizedBox(height: 12),
          Text(
            'Belum ada lansia terhubung & belum ada permintaan terhubung',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Data lansia akan muncul setelah ada permintaan yang diterima.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingRequestCard(dynamic request) {
    final connectionId = _getConnectionId(request);
    final name = _getElderlyName(request);
    final email = _getElderlyEmail(request);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
              Icon(Icons.inbox, color: Colors.teal),
              SizedBox(width: 8),
              Text(
                'Permintaan Terhubung',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _respondIncomingRequest(
                      connectionId: connectionId,
                      status: 'rejected',
                    );
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Tolak'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _respondIncomingRequest(
                      connectionId: connectionId,
                      status: 'accepted',
                    );
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Terima'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedElderlyCard(dynamic elderly) {
    final name = _getElderlyName(elderly);
    final email = _getElderlyEmail(elderly);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.teal.shade100,
            child: const Icon(
              Icons.elderly,
              color: Colors.teal,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionSection() {
    if (_isLoadingConnections) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: Colors.teal),
        ),
      );
    }

    if (_incomingRequests.isEmpty && _connectedElderlies.isEmpty) {
      return _buildEmptyConnectionCard();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_incomingRequests.isNotEmpty) ...[
          const Text(
            'Permintaan Masuk',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ..._incomingRequests.map(_buildIncomingRequestCard),
          const SizedBox(height: 18),
        ],
        if (_connectedElderlies.isNotEmpty) ...[
          const Text(
            'Lansia Terhubung',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ..._connectedElderlies.map(_buildConnectedElderlyCard),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F8),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _name == null
            ? const Center(child: CircularProgressIndicator(color: Colors.teal))
            : RefreshIndicator(
                onRefresh: _loadFamilyConnectionData,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildProfileInfo(),
                    const SizedBox(height: 28),
                    _buildConnectionSection(),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
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