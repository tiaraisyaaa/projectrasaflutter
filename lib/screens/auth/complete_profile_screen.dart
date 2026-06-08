import 'package:flutter/material.dart';

import '../../services/auth_api_service.dart';
import '../dashboard/elderly_dashboard_screen.dart';
import '../dashboard/family_dashboard_screen.dart';

class CompleteProfileScreen extends StatefulWidget {
  final String firebaseIdToken;
  final String initialName;

  const CompleteProfileScreen({
    super.key,
    required this.firebaseIdToken,
    required this.initialName,
  });

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final AuthApiService _authApiService = AuthApiService();

  late final TextEditingController _nameController;
  final TextEditingController _phoneController = TextEditingController();

  String _selectedRole = 'keluarga';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.initialName,
    );
  }

  Future<void> _submitProfile() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      _showMessage('Nama wajib diisi');
      return;
    }

    if (phone.isEmpty) {
      _showMessage('Nomor HP wajib diisi');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await _authApiService.registerFirebaseUser(
      idToken: widget.firebaseIdToken,
      name: name,
      phone: phone,
      role: _selectedRole,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      final user = result['user'];
      final role = user['role'];

      if (role == 'lansia') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const ElderlyDashboardScreen(),
          ),
          (route) => false,
        );
      } else if (role == 'keluarga') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const FamilyDashboardScreen(),
          ),
          (route) => false,
        );
      } else {
        _showMessage('Role tidak dikenali');
      }
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
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F8),
      appBar: AppBar(
        title: const Text('Lengkapi Profil'),
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
                    Icons.person_add_alt_1,
                    size: 64,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Lengkapi Data Diri',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Isi data ini untuk menyelesaikan pendaftaran.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Nomor HP',
                    hintText: '08123456789',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: InputDecoration(
                    labelText: 'Daftar sebagai',
                    prefixIcon: const Icon(Icons.group_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'keluarga',
                      child: Text('Keluarga'),
                    ),
                    DropdownMenuItem(
                      value: 'lansia',
                      child: Text('Lansia'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _selectedRole = value;
                    });
                  },
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _isLoading ? 'Menyimpan...' : 'Simpan dan Masuk',
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