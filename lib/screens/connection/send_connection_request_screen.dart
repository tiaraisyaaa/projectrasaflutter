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
      _showMessage(result['message']);

      Navigator.pop(context);
    } else {
      _showMessage(result['message']);
    }
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
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F8),
      appBar: AppBar(
        title: const Text('Hubungkan Keluarga'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
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
                const Center(
                  child: Icon(
                    Icons.group_add,
                    size: 64,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 16),

                const Center(
                  child: Text(
                    'Kirim Permintaan',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                const Center(
                  child: Text(
                    'Masukkan email akun keluarga yang ingin dihubungkan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Keluarga',
                    hintText: 'keluarga@gmail.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _isLoading ? 'Mengirim...' : 'Kirim Permintaan',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}