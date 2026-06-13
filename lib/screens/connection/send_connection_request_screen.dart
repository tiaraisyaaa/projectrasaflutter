import 'package:flutter/material.dart';

import '../../services/connection_service.dart';
import '../../services/storage_service.dart';

class SendConnectionRequestScreen extends StatefulWidget {
  const SendConnectionRequestScreen({super.key});

  @override
  State<SendConnectionRequestScreen> createState() =>
      _SendConnectionRequestScreenState();
}

class _SendConnectionRequestScreenState
    extends State<SendConnectionRequestScreen> {
  final ConnectionService _connectionService = ConnectionService();
  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = false;

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
        color: Colors.black.withOpacity(0.08),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ];
  }

  Future<void> _sendRequest() async {
    final familyEmail = _emailController.text.trim();

    if (familyEmail.isEmpty) {
      _showMessage('Email keluarga wajib diisi');
      return;
    }

    if (!familyEmail.contains('@')) {
      _showMessage('Format email tidak valid');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await _connectionService.sendConnectionRequest(
      familyEmail: familyEmail,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      await StorageService().savePendingFamilyRequest(
        familyEmail: _emailController.text.trim(),
      );

      _showMessage(result['message']?.toString() ?? 'Permintaan berhasil dikirim');

      Navigator.pop(context);
    } else {
      _showMessage(result['message']?.toString() ?? 'Gagal mengirim permintaan');
    }
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

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
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
              Icons.group_add_rounded,
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
                  'Hubungkan Keluarga',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Kirim permintaan koneksi ke akun keluarga agar mereka dapat memantau kondisi Anda.',
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

  Widget _buildFormCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(26),
        boxShadow: _softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mark_email_read_outlined,
                size: 48,
                color: primaryBlue,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Center(
            child: Text(
              'Kirim Permintaan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w900,
                color: darkText,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Masukkan email akun keluarga yang ingin dihubungkan dengan akun lansia.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: mutedText,
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            'Email Keluarga',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: darkText,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) {
              if (!_isLoading) {
                _sendRequest();
              }
            },
            style: const TextStyle(
              fontSize: 16,
              color: darkText,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: 'keluarga@gmail.com',
              filled: true,
              fillColor: const Color(0xFFF7FCFF),
              prefixIcon: const Icon(
                Icons.email_outlined,
                color: primaryBlue,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: primaryBlue.withOpacity(0.35),
                  width: 1.2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: primaryBlue,
                  width: 1.8,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Colors.red,
                  width: 1.3,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: primaryBlue.withOpacity(0.15),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: primaryBlue,
                  size: 22,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pastikan email yang dimasukkan sudah terdaftar sebagai akun keluarga di aplikasi RASA.',
                    style: TextStyle(
                      color: mutedText,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: primaryBlue.withOpacity(0.55),
                elevation: 4,
                shadowColor: primaryBlue.withOpacity(0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 23,
                      height: 23,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_rounded, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Kirim Permintaan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
            ),
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
        title: const Text(
          'Hubungkan Keluarga',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: softBlue,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 24),
              _buildFormCard(),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}