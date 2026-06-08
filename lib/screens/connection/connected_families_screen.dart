import 'package:flutter/material.dart';

import '../../services/connection_service.dart';

class ConnectedFamiliesScreen extends StatefulWidget {
  const ConnectedFamiliesScreen({super.key});

  @override
  State<ConnectedFamiliesScreen> createState() =>
      _ConnectedFamiliesScreenState();
}

class _ConnectedFamiliesScreenState extends State<ConnectedFamiliesScreen> {
  final ConnectionService _connectionService = ConnectionService();

  bool _isLoading = true;
  List<dynamic> _families = [];

  @override
  void initState() {
    super.initState();
    _loadConnectedFamilies();
  }

  Future<void> _loadConnectedFamilies() async {
    setState(() {
      _isLoading = true;
    });

    final result = await _connectionService.getConnectedFamilies();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      setState(() {
        _families = result['data'] ?? [];
      });

      debugPrint('Connected families: $_families');
    } else {
      _showMessage(result['message']);
    }
  }

  String _getFamilyName(dynamic item) {
    if (item['family'] != null) {
      return item['family']['name']?.toString() ?? 'Nama tidak tersedia';
    }

    return item['family_name']?.toString() ??
        item['familyName']?.toString() ??
        item['name']?.toString() ??
        'Nama tidak tersedia';
  }

  String _getFamilyEmail(dynamic item) {
    if (item['family'] != null) {
      return item['family']['email']?.toString() ?? 'Email tidak tersedia';
    }

    return item['family_email']?.toString() ??
        item['familyEmail']?.toString() ??
        item['email']?.toString() ??
        'Email tidak tersedia';
  }

  String _getFamilyPhone(dynamic item) {
    if (item['family'] != null) {
      return item['family']['phone']?.toString() ?? '-';
    }

    return item['family_phone']?.toString() ??
        item['familyPhone']?.toString() ??
        item['phone']?.toString() ??
        '-';
  }

  String _getStatus(dynamic item) {
    return item['status']?.toString() ?? 'connected';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Widget _buildFamilyCard(dynamic family) {
    final name = _getFamilyName(family);
    final email = _getFamilyEmail(family);
    final phone = _getFamilyPhone(family);
    final status = _getStatus(family);

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 26,
            backgroundColor: Color(0xFFE0F2F1),
            child: Icon(
              Icons.family_restroom,
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
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  phone,
                  style: const TextStyle(
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      color: Colors.teal,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F8),
      appBar: AppBar(
        title: const Text('Keluarga Terhubung'),
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
                onRefresh: _loadConnectedFamilies,
                child: _families.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(24),
                        children: const [
                          SizedBox(height: 160),
                          Icon(
                            Icons.group_off_outlined,
                            size: 70,
                            color: Colors.teal,
                          ),
                          SizedBox(height: 16),
                          Center(
                            child: Text(
                              'Belum ada keluarga terhubung',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          Center(
                            child: Text(
                              'Keluarga yang sudah menerima permintaan akan tampil di sini.',
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
                        itemCount: _families.length,
                        itemBuilder: (context, index) {
                          return _buildFamilyCard(_families[index]);
                        },
                      ),
              ),
      ),
    );
  }
}