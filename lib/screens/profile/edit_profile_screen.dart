import 'package:flutter/material.dart';

import '../../services/storage_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final StorageService _storageService = StorageService();
  final TextEditingController _nameController = TextEditingController();

  String? _email;
  String? _role;
  bool _isLoading = true;
  bool _isSaving = false;

  static const Color primaryBlue = Color(0xFF2F73AD);
  static const Color darkBlue = Color(0xFF245E91);
  static const Color softBlue = Color(0xFFBFE7E8);
  static const Color verySoftBlue = Color(0xFFF7FCFF);
  static const Color darkText = Color(0xFF3F3F3F);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final name = await _storageService.getName();
    final email = await _storageService.getEmail();
    final role = await _storageService.getRole();

    if (!mounted) return;

    setState(() {
      _nameController.text = name ?? '';
      _email = email;
      _role = role;
      _isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      _showMessage('Nama tidak boleh kosong');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    await _storageService.updateName(name);

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    _showMessage('Profile berhasil diperbarui');

    Navigator.pop(context, true);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatRole(String? role) {
    if (role == null || role.isEmpty) return '-';

    if (role.toLowerCase() == 'lansia') {
      return 'Lansia';
    }

    if (role.toLowerCase() == 'keluarga') {
      return 'Keluarga';
    }

    return role;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/icon/logo.png',
      width: 150,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return const Column(
          children: [
            Icon(Icons.person_outline, size: 70, color: primaryBlue),
            SizedBox(height: 8),
            Text(
              'RASA',
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w900,
                color: primaryBlue,
                letterSpacing: 2,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBackButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.white.withOpacity(0.85),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            Navigator.pop(context);
          },
          child: const Padding(
            padding: EdgeInsets.all(10),
            child: Icon(Icons.arrow_back_rounded, color: primaryBlue, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return const Column(
      children: [
        Text(
          'Edit Profile',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Perbarui nama akun RASA Anda.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.black54,
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
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildEditableField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 8),
        Container(
          height: 58,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: primaryBlue.withOpacity(0.20),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!_isSaving) {
                _saveProfile();
              }
            },
            style: const TextStyle(
              fontSize: 16,
              color: darkText,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Icon(icon, color: primaryBlue),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primaryBlue, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: darkBlue, width: 1.7),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadonlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 8),
        Container(
          height: 58,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.90),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: primaryBlue.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            initialValue: value,
            readOnly: true,
            style: const TextStyle(
              fontSize: 16,
              color: darkText,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.90),
              prefixIcon: Icon(icon, color: Colors.grey),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: primaryBlue.withOpacity(0.55),
                  width: 1.1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: primaryBlue.withOpacity(0.55),
                  width: 1.1,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveProfile,
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
        child: _isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.4,
                ),
              )
            : const Text(
                'Simpan Perubahan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildEditableField(
            controller: _nameController,
            label: 'Nama',
            icon: Icons.person_outline,
            keyboardType: TextInputType.name,
          ),
          const SizedBox(height: 18),
          _buildReadonlyField(
            label: 'Email',
            value: _email ?? '-',
            icon: Icons.email_outlined,
          ),
          const SizedBox(height: 18),
          _buildReadonlyField(
            label: 'Role',
            value: _formatRole(_role),
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 28),
          _buildSaveButton(),
        ],
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
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: primaryBlue),
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 20,
                  ),
                  child: Column(
                    children: [
                      _buildBackButton(),
                      const SizedBox(height: 6),
                      _buildLogo(),
                      const SizedBox(height: 14),
                      _buildTitle(),
                      const SizedBox(height: 28),
                      _buildFormCard(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
