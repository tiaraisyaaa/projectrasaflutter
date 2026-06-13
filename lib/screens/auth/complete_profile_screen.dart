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

  static const Color primaryBlue = Color(0xFF2F73AD);
  static const Color darkBlue = Color(0xFF245E91);
  static const Color softBlue = Color(0xFFBFE7E8);
  static const Color verySoftBlue = Color(0xFFF7FCFF);

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.initialName);
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
          MaterialPageRoute(builder: (_) => const ElderlyDashboardScreen()),
          (route) => false,
        );
      } else if (role == 'keluarga') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const FamilyDashboardScreen()),
          (route) => false,
        );
      } else {
        _showMessage('Role tidak dikenali');
      }
    } else {
      _showMessage(result['message']?.toString() ?? 'Gagal menyimpan profil');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/icon/logo.png',
      width: 165,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return const Column(
          children: [
            Icon(Icons.person_add_alt_1, size: 72, color: Color(0xFF2F73AD)),
            SizedBox(height: 8),
            Text(
              'RASA',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2F73AD),
                letterSpacing: 2,
              ),
            ),
            Text(
              'Real-time Asisten Siaga Aktivitas Lansia',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 8),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            boxShadow: [
              BoxShadow(
                color: primaryBlue.withOpacity(0.20),
                blurRadius: 9,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: primaryBlue, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: darkBlue, width: 1.6),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Daftar Sebagai'),
        const SizedBox(height: 8),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            boxShadow: [
              BoxShadow(
                color: primaryBlue.withOpacity(0.20),
                blurRadius: 9,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedRole,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.black,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: primaryBlue, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: darkBlue, width: 1.6),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'keluarga', child: Text('Keluarga')),
              DropdownMenuItem(value: 'lansia', child: Text('Lansia')),
            ],
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                _selectedRole = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: 220,
      height: 58,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primaryBlue.withOpacity(0.55),
          elevation: 4,
          shadowColor: primaryBlue.withOpacity(0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Simpan dan Masuk',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }

  Widget _buildInfoText() {
    return const Text(
      'Lengkapi data diri untuk menyelesaikan pendaftaran akun RASA.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        color: Colors.black54,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [softBlue, verySoftBlue],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLogo(),

                    const SizedBox(height: 18),

                    _buildInfoText(),

                    const SizedBox(height: 28),

                    _buildTextField(
                      controller: _nameController,
                      label: 'Nama',
                      keyboardType: TextInputType.name,
                      textInputAction: TextInputAction.next,
                    ),

                    const SizedBox(height: 18),

                    _buildTextField(
                      controller: _phoneController,
                      label: 'Nomor HP',
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                    ),

                    const SizedBox(height: 18),

                    _buildRoleDropdown(),

                    const SizedBox(height: 34),

                    _buildSubmitButton(),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
