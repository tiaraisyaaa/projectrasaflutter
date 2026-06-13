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
  static const Color cardBlue = Color(0xFFEAF7FF);
  static const Color darkText = Color(0xFF20232A);
  static const Color mutedText = Color(0xFF6F7F86);

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
      width: 158,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return const Column(
          children: [
            Icon(Icons.person_add_alt_1_rounded, size: 72, color: primaryBlue),
            SizedBox(height: 8),
            Text(
              'RASA',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: primaryBlue,
                letterSpacing: 2,
              ),
            ),
            Text(
              'Real-time Asisten Siaga Aktivitas Lansia',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: darkText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeaderText() {
    return const Column(
      children: [
        Text(
          'Lengkapi Profil',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: darkText,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Lengkapi data diri untuk menyelesaikan\npendaftaran akun RASA.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.35,
            color: mutedText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w800,
          color: darkText,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          style: const TextStyle(
            fontSize: 15,
            color: darkText,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: verySoftBlue,
            prefixIcon: Icon(
              icon,
              color: primaryBlue,
              size: 21,
            ),
            hintText: hintText,
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w500,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: primaryBlue.withOpacity(0.14),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: primaryBlue,
                width: 1.4,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 1.4,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final bool isSelected = _selectedRole == value;

    return Expanded(
      child: InkWell(
        onTap: _isLoading
            ? null
            : () {
                setState(() {
                  _selectedRole = value;
                });
              },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? cardBlue : verySoftBlue,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? primaryBlue
                  : primaryBlue.withOpacity(0.14),
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? primaryBlue.withOpacity(0.12)
                      : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? primaryBlue : mutedText,
                  size: 27,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? primaryBlue : darkText,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: mutedText,
                  fontSize: 11.5,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Daftar Sebagai'),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildRoleOption(
              value: 'keluarga',
              title: 'Keluarga',
              subtitle: 'Memantau lansia',
              icon: Icons.family_restroom_rounded,
            ),
            const SizedBox(width: 12),
            _buildRoleOption(
              value: 'lansia',
              title: 'Lansia',
              subtitle: 'Dipantau keluarga',
              icon: Icons.elderly_rounded,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primaryBlue.withOpacity(0.55),
          elevation: 0,
          shadowColor: primaryBlue.withOpacity(0.30),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.72)),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.12),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeaderText(),

          const SizedBox(height: 24),

          _buildTextField(
            controller: _nameController,
            label: 'Nama',
            icon: Icons.person_outline_rounded,
            hintText: 'Masukkan nama lengkap',
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
          ),

          const SizedBox(height: 16),

          _buildTextField(
            controller: _phoneController,
            label: 'Nomor HP',
            icon: Icons.phone_outlined,
            hintText: 'Masukkan nomor HP',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
          ),

          const SizedBox(height: 18),

          _buildRoleSelector(),

          const SizedBox(height: 26),

          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildBackgroundDecor() {
    return Stack(
      children: [
        Positioned(
          top: -70,
          right: -60,
          child: Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.32),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          top: 120,
          left: -80,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          bottom: -90,
          right: -70,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: softBlue.withOpacity(0.50),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [softBlue, verySoftBlue],
              ),
            ),
          ),
          _buildBackgroundDecor(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 20,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLogo(),

                      const SizedBox(height: 22),

                      _buildProfileCard(),

                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}