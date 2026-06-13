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

  static const Color primaryBlue = Color(0xFF2F73AD);
  static const Color deepBlue = Color(0xFF1D5F94);
  static const Color softBlue = Color(0xFFBFE7E8);
  static const Color verySoftBlue = Color(0xFFF7FCFF);
  static const Color cardWhite = Colors.white;
  static const Color darkText = Color(0xFF20232A);
  static const Color mutedText = Color(0xFF777777);
  static const Color successGreen = Color(0xFF2E7D62);

  List<BoxShadow> get _softShadow {
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.08),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ];
  }

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
      _showMessage(result['message']?.toString() ?? 'Gagal memuat data');
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

  String _formatStatus(String status) {
    if (status.toLowerCase() == 'connected' ||
        status.toLowerCase() == 'accepted') {
      return 'Terhubung';
    }

    if (status.toLowerCase() == 'pending') {
      return 'Menunggu';
    }

    if (status.toLowerCase() == 'rejected') {
      return 'Ditolak';
    }

    return status;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
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
              border: Border.all(
                color: Colors.white.withOpacity(0.35),
              ),
            ),
            child: const Icon(
              Icons.family_restroom_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keluarga Terhubung',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Daftar akun keluarga yang sudah terhubung dengan lansia.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoLine({
    required IconData icon,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 19,
          color: mutedText,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              color: mutedText,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFamilyCard(dynamic family) {
    final name = _getFamilyName(family);
    final email = _getFamilyEmail(family);
    final phone = _getFamilyPhone(family);
    final status = _getStatus(family);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.family_restroom_rounded,
              color: primaryBlue,
              size: 38,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                    color: darkText,
                  ),
                ),
                const SizedBox(height: 10),
                _buildInfoLine(
                  icon: Icons.email_outlined,
                  value: email,
                ),
                const SizedBox(height: 7),
                _buildInfoLine(
                  icon: Icons.phone_outlined,
                  value: phone,
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: successGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _formatStatus(status),
                    style: const TextStyle(
                      color: successGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
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

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 34),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(26),
        boxShadow: _softShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.group_off_outlined,
              size: 46,
              color: primaryBlue,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Belum ada keluarga terhubung',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: darkText,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Keluarga yang sudah menerima permintaan akan tampil di halaman ini.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: mutedText,
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: primaryBlue,
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    return RefreshIndicator(
      color: primaryBlue,
      onRefresh: _loadConnectedFamilies,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 24),
          if (_families.isEmpty)
            _buildEmptyState()
          else ...[
            Text(
              '${_families.length} keluarga terhubung',
              style: const TextStyle(
                fontSize: 18,
                color: darkText,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            ..._families.map(_buildFamilyCard),
          ],
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: verySoftBlue,
      appBar: AppBar(
        title: const Text(
          'Keluarga Terhubung',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: softBlue,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: _buildContent(),
      ),
    );
  }
}