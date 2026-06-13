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
  static const Color pageBackground = Color(0xFFF1FAFF);
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

  Widget _buildCircleBackButton() {
    return Material(
      color: Colors.white.withOpacity(0.92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _isSaving
            ? null
            : () {
                Navigator.pop(context);
              },
        child: const Padding(
          padding: EdgeInsets.all(11),
          child: Icon(Icons.arrow_back_rounded, color: primaryBlue, size: 24),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 42),
      decoration: const BoxDecoration(
        color: softBlue,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(80),
          bottomRight: Radius.circular(80),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              children: [
                _buildCircleBackButton(),
                const Spacer(),
                Image.asset(
                  'assets/icon/logo.png',
                  width: 74,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Text(
                      'RASA',
                      style: TextStyle(
                        color: primaryBlue,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    );
                  },
                ),
                const Spacer(),
                const SizedBox(width: 46),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryBlue.withOpacity(0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.edit_note_rounded,
                size: 58,
                color: primaryBlue,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Edit Profile',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                height: 1.1,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Perbarui nama akun RASA Anda',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
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
        TextField(
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
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            prefixIcon: Icon(icon, color: primaryBlue),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      setState(() {
                        controller.clear();
                      });
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.black38,
                    ),
                  ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: primaryBlue, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: darkBlue, width: 1.8),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onChanged: (_) {
            setState(() {});
          },
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
        TextFormField(
          initialValue: value,
          readOnly: true,
          style: const TextStyle(
            fontSize: 16,
            color: darkText,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF5FAFD),
            prefixIcon: Icon(icon, color: Colors.grey),
            suffixIcon: const Icon(
              Icons.lock_outline_rounded,
              color: Colors.black26,
              size: 20,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: primaryBlue.withOpacity(0.45),
                width: 1.1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: primaryBlue.withOpacity(0.45),
                width: 1.1,
              ),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryBlue.withOpacity(0.25)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: primaryBlue, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Email dan role tidak dapat diubah dari halaman ini.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
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
          elevation: 5,
          shadowColor: primaryBlue.withOpacity(0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: _isSaving
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
                  Icon(Icons.save_outlined, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Simpan Perubahan',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Transform.translate(
      offset: const Offset(0, -28),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildEditableField(
              controller: _nameController,
              label: 'Nama',
              icon: Icons.person_outline_rounded,
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 20),
            _buildReadonlyField(
              label: 'Email',
              value: _email ?? '-',
              icon: Icons.email_outlined,
            ),
            const SizedBox(height: 20),
            _buildReadonlyField(
              label: 'Role',
              value: _formatRole(_role),
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 20),
            _buildInfoNote(),
            const SizedBox(height: 26),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      resizeToAvoidBottomInset: true,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryBlue))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildHeader(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    child: _buildFormCard(),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
    );
  }
}
